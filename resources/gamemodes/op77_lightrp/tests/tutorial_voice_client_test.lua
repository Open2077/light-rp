local calls,sent,pages,threads,events={},{},{},{},{}
local snapshot={available=true,inputDevice="mic",level=0,testing=false,key="MOUSE4"}
LightRpEvents={page={tutorial="page"},net={tutorial="control"}}
LightRpUi={send=function(_,v)pages[#pages+1]=v end}
Open77={voice={setup=function(op,value)
 calls[#calls+1]={op=op,value=value}
 if op=="end" or op=="complete" then snapshot.testing=false;return true end
 if op=="test" then snapshot.testing=value end
 local copy={};for k,v in pairs(snapshot)do copy[k]=v end;return copy
end},exports={call=function()return {await=function()return {cycleKey="F8"}end}end}}
TriggerServerEvent=function(_,v)sent[#sent+1]=v end
GetCurrentResourceName=function()return "op77_lightrp" end
AddEventHandler=function(e,fn)events[e]=fn end
CreateThread=function(fn)threads[#threads+1]=coroutine.create(fn)end
Wait=function()coroutine.yield()end
dofile("client/core/tutorial_voice.lua")
local V=LightRpTutorialVoice
local function tick()for _,t in ipairs(threads)do local ok,why=coroutine.resume(t);assert(ok,why)end end
local function enter(rev)V.sync({active=true,step="voice",key="char",revision=rev or 5});V.handle({action="begin"})end
enter();assert(pages[#pages].voice.rangeKey=="F8")
V.handle({action="complete"});assert(#sent==0,"no silent sound-check completion")
V.handle({action="test",value=true});snapshot.level=.4;tick();tick();tick()
assert(pages[#pages].voice.signalDetected)
V.handle({action="set",name="InputDevice",value="new-mic"})
assert(not pages[#pages].voice.signalDetected,"changing input requires new signal")
snapshot.inputDevice="new-mic";tick();tick()
V.handle({action="complete"});assert(sent[#sent].operation=="voice-done" and sent[#sent].revision==5 and not snapshot.testing)
enter(6);V.handle({action="skip"});assert(sent[#sent].operation=="voice-skip")
enter(7);V.handle({action="configured"});assert(sent[#sent].operation=="voice-configured")
enter();V.handle({action="test",value=true});V.sync({active=false});assert(not snapshot.testing)
enter();V.handle({action="test",value=true});events.onClientResourceStop("op77_lightrp");assert(not snapshot.testing)
Open77.voice.setup=nil;enter();assert(pages[#pages].voiceError:find("Update your Open77 client",1,true))
V.handle({action="skip"});assert(sent[#sent].operation=="voice-skip","older clients can still skip")
print("PASS: voice controller, genuine signal gating, device reset, skip/configured, cleanup and older-client fallback")
