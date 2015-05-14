# NW.js-specific initialisation
if process?
  gui = require 'nw.gui'; crypto = require 'crypto'; fs = require 'fs'; nomnom = require 'nomnom'
  path = require 'path'; {spawn} = require 'child_process'; proxy = require './proxy'

  segmOverlap = (a, b, c, d) -> a < d && c < b # Do the two segments ab and cd overlap?

  rectOverlap = (r0, r1) -> ( # A rectangle is {x,y,width,height}.  Do the two overlap?
    segmOverlap(r0.x, r0.x + r0.width,  r1.x, r1.x + r1.width) &&
    segmOverlap(r0.y, r0.y + r0.height, r1.y, r1.y + r1.height)
  )

  segmFit = (a, b, A, B) -> # Nudge and/or squeeze "ab" as necessary so it fits into "AB".
    if b - a > B - A then [A, B] else if a < A then [A, A + b - a] else if b > B then [B - b + a, B] else [a, b]

  rectFit = (r, R) -> # like segmFit but for for rectangles
    [x, x1] = segmFit r.x, r.x + r.width,  R.x, R.x + R.width
    [y, y1] = segmFit r.y, r.y + r.height, R.y, R.y + R.height
    {x, y, width: x1 - x, height: y1 - y}

  restoreWindow = (w, r) -> # w: NWJS window, r: rectangle
    # Find a screen that overlaps with "r" and fit "w" inside it:
    for scr in gui.Screen.screens when rectOverlap scr.work_area, r
      r = rectFit r, scr.work_area
      w.moveTo r.x, r.y; w.resizeTo r.width, r.height
      process.nextTick ->
        w.dx = w.x      - r.x
        w.dy = w.y      - r.y
        w.dw = w.width  - r.width
        w.dh = w.height - r.height
        return
      break
    return

  D.nwjs = true; D.mac = process.platform == 'darwin'; D.floating = !!opener
  if D.mac then process.env.DYALOG_IDE_INTERPRETER_EXE ||= path.resolve process.cwd(), '../Dyalog/mapl'
  process.chdir process.env.PWD || process.env.HOME || '.' # see https://github.com/nwjs/nw.js/issues/648
  D.process = process; gui.Screen.Init(); nww = gui.Window.get()

  urlParams = {}
  for kv in (location + '').replace(/^[^\?]*($|\?)/, '').split '&'
    [_, k, v] = /^([^=]*)=?(.*)$/.exec kv; urlParams[unescape k || ''] = unescape v || ''

  do -> # restore window state:
    if D.floating
      opener.D.floatingWindows.push nww
      restoreWindow nww,
        x:      +urlParams.x
        y:      +urlParams.y
        width:  +urlParams.width
        height: +urlParams.height
    else
      D.floatingWindows = []; D.floatOnTop = 0
      nww.on 'focus', -> (for x in D.floatingWindows then x.setAlwaysOnTop !!D.floatOnTop); return
      nww.on 'blur',  -> (for x in D.floatingWindows then x.setAlwaysOnTop false         ); return
      if localStorage.pos then try
        pos = JSON.parse localStorage.pos
        restoreWindow nww, x: pos[0], y: pos[1], width: pos[2], height: pos[3]
    return
  nww.show(); nww.focus() # focus() is needed for the Mac

  # To "throttle" a function is to make it execute no more often than once every X milliseconds.
  throttle = (f) -> tid = null; -> tid ?= setTimeout (-> f(); tid = null; return), 500; return

  saveWindowState = throttle ->
    posStr = JSON.stringify [
      nww.x      - (nww.dx || 0)
      nww.y      - (nww.dy || 0)
      nww.width  - (nww.dw || 0)
      nww.height - (nww.dh || 0)
    ]
    if D.floating
      (fw = opener.D.floatingWindows).splice fw.indexOf(nww), 1
      if +urlParams.tracer || urlParams.token == '1'
        if +urlParams.tracer then localStorage.posTracer = posStr else localStorage.posEditor = posStr
    else
      localStorage.pos = posStr
    return
  nww.on 'move',   saveWindowState
  nww.on 'resize', saveWindowState

  nww.on 'close', ->
    if D.forceClose
      process.nextTick -> nww.close true; return
    else
      window.onbeforeunload?(); if !D.floating then process.nextTick -> nww.close true; return
    return

  $ ->
    cmenu = null # context menu on right-click, lazily initialized
    $ document
      .on 'keydown', '*', 'f12', -> nww.showDevTools(); false
      .on 'contextmenu', (e) ->
        if !cmenu
          cmenu = new gui.Menu
          ['Cut', 'Copy', 'Paste'].forEach (x) ->
            cmenu.append new gui.MenuItem label: x, click: (-> document.execCommand x; return); return
        cmenu.popup e.clientX, e.clientY
        false
    return

  D.readFile = fs.readFile # needed for presentation mode

  # external editors (available only under nwjs)
  tmpDir = process.env.TMPDIR || process.env.TMP || process.env.TEMP || '/tmp'
  if editorExe = process.env.DYALOG_IDE_EDITOR || process.env.EDITOR
    D.openInExternalEditor = (text, line, callback) ->
      tmpFile = path.join tmpDir, "#{crypto.randomBytes(8).toString 'hex'}.dyalog"
      callback0 = callback
      callback = (args...) -> fs.unlink tmpFile, -> callback0 args... # make sure to delete file before calling callback
      fs.writeFile tmpFile, text, {mode: 0o600}, (err) ->
        if err then callback err; return
        child = spawn editorExe, [tmpFile], cwd: tmpDir, env: $.extend {}, process.env,
          DYALOG_IDE_FILE: tmpFile
          DYALOG_IDE_LINE_NUMBER: 1 + line
        child.on 'error', callback
        child.on 'exit', (c, s) ->
          if c || s then callback('Editor exited with ' + if c then 'code ' + c else 'signal ' + s); return
          fs.readFile tmpFile, 'utf8', callback; return
        return
      return

  D.createSocket = ->
    class LocalSocket # imitate socket.io's API
      emit: (a...) -> @other.onevent data: a
      onevent: ({data}) -> (for f in @[data[0]] or [] then f data[1..]...); return
      on: (e, f) -> (@[e] ?= []).push f; @
    socket = new LocalSocket; socket1 = new LocalSocket; socket.other = socket1; socket1.other = socket
    proxy.Proxy() socket1
    socket

  {execPath} = process; if D.mac then execPath = execPath.replace /(\/Contents\/).*$/, '$1MacOS/node-webkit'
  D.rideConnect    = -> spawn execPath, ['--no-spawn'], detached: true, stdio: ['ignore', 'ignore', 'ignore']; return
  D.rideNewSession = -> spawn execPath, ['-s'        ], detached: true, stdio: ['ignore', 'ignore', 'ignore']; return

  D.quit = -> gui.Window.get().close(); return
  D.clipboardCopy = (s) -> gui.Clipboard.get().set s; return
  D.opts = nomnom.options(
    connect: abbr: 'c', flag: true, metavar: 'HOST[:PORT]'
    listen:  abbr: 'l', flag: true
    spawn:   abbr: 's', flag: true, default: !/^win/i.test process.platform
  ).parse gui.App.argv

  # Debugging utilities
  $ document
    .on 'keydown', '*', 'ctrl+shift+f12', -> foo.bar # cause a crash
    .on 'keydown', '*', 'ctrl+f12', ->
      lw = open ''
      lw.document.write '''
        <html>
          <head>
            <title>Proxy Log</title>
            <style>body{font-family:monospace;white-space:pre}</style>
            <script></script>
          </head>
          <body></body>
        </html>
      '''
      wr = (s) ->
        if !lw || lw.closed || !lw.document || !lw.document.createTextNode
          i = proxy.log.listeners.indexOf wr
          if i >= 0 then proxy.log.listeners.splice i, 1; lw = null
        else
          b = lw.document.body
          atEnd = b.scrollTop == b.scrollHeight - b.clientHeight
          b.appendChild lw.document.createTextNode s
          if atEnd then b.scrollTop = b.scrollHeight - b.clientHeight
        return
      wr proxy.log.get().join ''; proxy.log.listeners.push wr
      false

  # Error handling
  if !D.floating
    htmlChars = '&': '&amp;', '<': '&lt;', '>': '&gt;'
    htmlEsc = (s) -> s.replace /./g, (x) -> htmlChars[x] || x
    process.on 'uncaughtException', (e) ->
      if window then window.lastError = e
      info = """
        IDE: #{JSON.stringify D.versionInfo}
        Interpreter: #{JSON.stringify(D.remoteIdentification || null)}
        localStorage: #{JSON.stringify localStorage}
        \n#{e.stack}\n
        Proxy log:
        #{proxy.log.get().join ''}
      """
      excuses = '''
        Oops... it broke!
        Congratulations, you found a ... THE bug.
        Users-Developers 1:0
        According to our developers this is impossible.
        This bug was caused by cosmic radiation randomly flipping bits.
        You don't find bugs.  Bugs find you.
      '''.split '\n'
      document.write """
        <html>
          <head><title>Error</title></head>
          <body>
            <h3>#{excuses[Math.floor excuses.length * Math.random()]}</h3>
            <h3 style=font-family:apl,monospace>
              <a href="mailto:support@dyalog.com?subject=#{escape 'RIDE crash'}&body=#{escape '\n\n' + info}">support@dyalog.com</a>
            </h3>
            <textarea autofocus style=width:100%;height:90% nowrap>#{htmlEsc info}</textarea>
          </body>
        <html>
      """
      false

  D.open = (url, opts) -> opts.icon = 'D.png'; opts.toolbar ?= false; !!gui.Window.open url, opts
  D.openExternal = gui.Shell.openExternal

  if D.mac && !D.floating # Mac menu
    groups = {} # group name -> array of MenuItem-s

    render = (x) ->
      if !x then return
      if x[''] == '-' then return new gui.MenuItem type: 'separator'
      h = # arguments to MenuItem's constructor
        label: x[''].replace /_/g, ''
        key: if (i = x[''].indexOf '_') >= 0 then x[i + 1] # this doesn't work on the Mac but let's keep it anyway in case we use native menus elsewhere
        type: if x.group || x.checkBoxPref then 'checkbox' else 'normal'
      if x.key && x.action && !x.dontBindKey then $(document).on 'keydown', '*', x.key, -> x.action(); false
      if x.group
        h.checked = !!x.checked
        h.click = ->
          groups[x.group].forEach (sibling) -> sibling.checked = sibling == mi; return
          x.action?(); return
      else if x.checkBoxPref
        h.checked = !!x.checkBoxPref(); h.click = -> x.action? mi.checked; return
        x.checkBoxPref (v) -> mi.checked = !!v; return
      else
        h.click = -> x.action?(); return
      if x.items then h.submenu = new gui.Menu; for y in x.items then h.submenu.append render y
      mi = new gui.MenuItem h
      if x.group then (groups[x.group] ?= []).push mi
      mi

    D.installMenu = (m) ->
      mb = new gui.Menu type: 'menubar'
      mb.createMacBuiltin 'Dyalog'
      mb.items[0].submenu.removeAt 0 # remove built-in "About Dyalog" that doesn't do anything useful
      # For "Special Characters..." and "Start Dictation...": see https://github.com/nwjs/nw.js/issues/2812
      # I discovered that if I remove "Copy" they go away, but then Cmd+C stops working.
      for x, ix in m
        if x[''].replace(/_/, '') in ['Edit', 'Help'] then x[''] += ' ' # a hack to get rid of Help>Search
        ourMenu = render x
        if ix
          theirMenu = null; for y in mb.items when y.label == ourMenu.label.replace(/\ $/, '') then theirMenu = y; break
        else
          theirMenu = mb.items[0]
        if theirMenu # try to merge new menu with existing menu
          ourMenu.submenu.append new gui.MenuItem type: 'separator'
          while theirMenu.submenu.items.length
            y = theirMenu.submenu.items[0]; theirMenu.submenu.remove y
            ourMenu.submenu.append y
          mb.remove theirMenu
        mb.insert ourMenu, ix
      nww.menu = mb
      return
