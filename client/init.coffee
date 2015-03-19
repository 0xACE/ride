require 'codemirror/addon/dialog/dialog'
require 'codemirror/addon/search/searchcursor'
require 'codemirror/addon/scroll/annotatescrollbar'
require 'codemirror/addon/search/matchesonscrollbar'
require 'codemirror/addon/hint/show-hint'
require 'codemirror/addon/edit/matchbrackets'
require 'codemirror/addon/edit/closebrackets'
connect = require './connect'
Editor = require './editor'
about = require './about'
require '../jquery.layout'
ide = require './ide'
require './util'
prefs = require './prefs'

$ ->
  if D.nwjs
    zM = 11 # zoom level magnitude limit
    $ document
      .on 'keydown', '*', 'ctrl+=', D.zoomIn    = -> prefs.zoom Math.min  zM, prefs.zoom() + 1; false
      .on 'keydown', '*', 'ctrl+-', D.zoomOut   = -> prefs.zoom Math.max -zM, prefs.zoom() - 1; false
      .on 'keydown', '*', 'ctrl+0', D.resetZoom = -> prefs.zoom 0; false
      .on 'keydown', '*', 'ctrl+shift+=', D.zoomIn

  urlParams = {}
  for kv in (location + '').replace(/^[^\?]*($|\?)/, '').split '&'
    [_, k, v] = /^([^=]*)=?(.*)$/.exec kv; urlParams[unescape(k or '')] = unescape(v or '')
  if opener && (win = urlParams.win)? # are we running in a floating editor window?
    wins = D.wins = opener.D.wins
    $('body').addClass('floating-window').html('<div class="ui-layout-center"></div>').layout
      defaults: enableCursorHotkey: 0
      center: onresize: -> ed?.updateSize(); return
      fxName: ''
    $('title').text wins[win].name
    ed0 = wins[win]; ed = wins[win] = Editor $('.ui-layout-center'), ed0.getOpts()
    ed.setState ed0.getState(); ed.updateSize(); ed.focus(); ed0 = null
    window.onbeforeunload = ->
      fwis = prefs.floatingWindowInfos()
      fwis[win] = x: window.screenX, y: window.screenY, width: $(window).width(), height: $(window).height()
      prefs.floatingWindowInfos fwis; ed.saveAndClose(); return
  else
    D.socket = (D.createSocket || io)()
    D.quit ?= close
    o = D.opts || {} # handle command line arguments
    if o.listen
      cp = connect(); cp.listen o._[0]
    else if o.connect
      cp = connect(); cp.connect o._[0]
    else if o.spawn
      ideInstance = ide()
      D.socket
        .on '*connected', ({host, port}) -> ideInstance.setHostAndPort host, port; return
        .emit '*spawn'
    else
      connect()

  $ document
    .on 'keydown', '*', 'ctrl+0',       -> D.zoomIn();    false
    .on 'keydown', '*', 'shift+f1',     -> about(); false
    .on 'keydown', '*', 'ctrl+tab ctrl+shift+tab', (e) ->
      a = []; i = -1; for _, w of D.wins then (if w.hasFocus() then i = a.length); a.push w
      j = if i < 0 then 0 else if e.shiftKey then (i + a.length - 1) % a.length else (i + 1) % a.length
      $("#wintab#{a[j].id} a").click(); a[j].focus(); false

  # CSS class to indicate theme
  if !prefs.theme() then prefs.theme do ->
    # Detect platform
    #   https://nodejs.org/api/process.html#process_process_platform
    #   https://stackoverflow.com/questions/19877924/what-is-the-list-of-possible-values-for-navigator-platform-as-of-today
    p = (D.process ? navigator).platform
    if /^(darwin|mac|ipad|iphone|ipod)/i.test p then 'cupertino'
    else if /^(linux|x11|android)/i.test p then 'freedom'
    else 'redmond'
  $('body').addClass "theme-#{prefs.theme()}"

  # CSS class to indicate platform (NW.js-only)
  if D.process
    if D.process.platform == 'darwin' then $('body').addClass 'platform-mac'
    else if /^win/i.test D.process.platform then $('body').addClass 'platform-windows'

  # CSS class for focused window
  $(window).on 'focus blur', (e) -> $('body').toggleClass 'window-focused', window.focused = e.type == 'focus'
  window.focused = true
  return
