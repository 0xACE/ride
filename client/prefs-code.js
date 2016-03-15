'use strict'
this.tabTitle='Code'
var prefs=require('./prefs'),on=CodeMirror.on
var h={} // various input elements
this.init=function($e){
  $e[0].innerHTML=
    '<div>'+
      '<p><label><input id=code-ai   type=checkbox>A<u>u</u>to-indent</label> <label><input id=code-sw  size=1> spaces</label>'+
      '<p><label><input id=code-aim  type=checkbox>in <u>m</u>ethods:</label> <label><input id=code-swm size=1> spaces</label>'+
      '<p><label><input id=code-icom type=checkbox><u>I</u>ndent lines that contain only a comment</label>'+
      '<p><label><input id=code-io   type=checkbox>I<u>n</u>dent content when an editor is opened</label>'+
      '<p><label><input id=code-mb   type=checkbox><u>H</u>ighlight matching brackets: <tt>()[]{}</tt></label></p>'+
      '<p><label><input id=code-acbr type=checkbox>Au<u>t</u>o-close brackets</label>'+
      '<p><label><input id=code-acbl type=checkbox>Auto-c<u>l</u>ose blocks: <tt>:If :For ...</tt></label>'+
         '<label><u>w</u>ith <select id=code-acbe><option value=0>:EndIf,:EndFor,...<option value=1>just :End</select></label>'+
      '<p><label><input id=code-ac   type=checkbox>Autocom<u>p</u>letion</label> <label>a<u>f</u>ter <input id=code-acd size=5>ms</label>'+
      '<p><label><input id=code-fold type=checkbox>Co<u>d</u>e folding (outlining)</label>'+
      '<p><label><input id=code-vt   type=checkbox>Show <u>v</u>alue tips</label>'+
      '<p><label><input id=code-sqt  type=checkbox>Show tips for s<u>q</u>uiggles</label>'+
    '</div>'
  $('[id^=code-]',$e).each(function(){h[this.id.replace(/^code-/,'')]=this})
  $(h.ai).add(h.aim)
    .change(function(x){h.sw.disabled=h.aim.disabled=!h.ai.checked;h.swm.disabled=!h.ai.checked||!h.aim.checked})
  on(h.acbl,'change',function(){h.acbe.disabled=!this.checked})
  on(h.ac  ,'change',function(){h.acd .disabled=!this.checked})
  ;[h.sw,h.swm,h.acd].forEach(function(x){on(x,'change',function(){$(this).select()})})
}
this.load=function(){
  var sw =prefs.indent       ();h.ai .checked=sw >=0;h.sw .value=sw <0&&4||sw
  var swm=prefs.indentMethods();h.aim.checked=swm>=0;h.swm.value=swm<0&&2||swm
  h.icom.checked=!!prefs.indentComments     ()
  h.io  .checked=!!prefs.indentOnOpen       ()
  h.mb  .checked=!!prefs.matchBrackets      ()
  h.acbr.checked=!!prefs.autoCloseBrackets  ()
  h.acbl.checked=!!prefs.autoCloseBlocks    ()
  h.acbe.value  =  prefs.autoCloseBlocksEnd ()
  h.ac  .checked=!!prefs.autocompletion     ()
  h.acd .value  =  prefs.autocompletionDelay()
  h.fold.checked=!!prefs.fold               ()
  h.vt  .checked=!!prefs.valueTips          ()
  h.sqt .checked=!!prefs.squiggleTips       ()
  $(h.ai).add(h.acbl).add(h.ac).change()
}
this.save=function(){
  prefs.indent             (h.ai .checked?(+h.sw .value||0):-1)
  prefs.indentMethods      (h.aim.checked?(+h.swm.value||0):-1)
  prefs.indentComments     (h.icom.checked)
  prefs.indentOnOpen       (h.io  .checked)
  prefs.matchBrackets      (h.mb  .checked)
  prefs.autoCloseBrackets  (h.acbr.checked)
  prefs.autoCloseBlocks    (h.acbl.checked)
  prefs.autoCloseBlocksEnd (h.acbe.value)
  prefs.autocompletion     (h.ac  .checked)
  prefs.autocompletionDelay(h.acd .value)
  prefs.fold               (h.fold.checked)
  prefs.valueTips          (h.vt  .checked)
  prefs.squiggleTips       (h.sqt .checked)
}
this.validate=function(){
  if(h.ai .checked&&!isInt(h.sw .value,0))return{msg:'Auto-indent must be a non-negative integer.'           ,h:h.ai}
  if(h.aim.checked&&!isInt(h.swm.value,0))return{msg:'Auto-indent in methods must be a non-negative integer.',h:h.aim}
  if(h.ac .checked&&!isInt(h.acd.value,1))return{msg:'Autocompletion delay must be a positive integer.'      ,h:h.acd}
}
function isInt(x,minX){x=+x;return x===(x|0)&&x>=minX}
