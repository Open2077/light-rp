local now,owner,handler,thread=0,"op77_lightrp",nil,nil
local handlers,stored={},{}
local s={available=true,captureEnabled=true,voiceActivation=true,voiceActivationThreshold=.3,inputDevice="mic",outputDevice="headset",inputLevel=.4}
local key="MOUSE4"
Open77={time={monotonic=function()return now end},kvp={get=function(k,f)if stored[k]==nil then return f end;return stored[k]end},voice={
 status=function()return s end,setMicrophoneTest=function(on)s.microphoneTest=on;return true end,
 setVoiceActivation=function(on,t)s.voiceActivation=on;s.voiceActivationThreshold=t;return true end,
 setTransmitting=function(on)s.transmitting=on;return true end}}
exports=function(name,fn)assert(name=="voiceSetup");handler=fn end
GetInvokingResource=function()return owner end
GetCurrentResourceName=function()return "open77_pause" end
CreateThread=function(fn)thread=coroutine.create(fn)end
Wait=function()coroutine.yield()end
AddEventHandler=function(e,fn)handlers[e]=fn end
dofile("../../system/open77_pause/client/voice_setup.lua")
local fail=false
Open77VoiceSetup.install({key=function()return key end,
 devices=function()return {input={{id="mic",name="Microphone"}},output={{id="headset",name="Headphones"}}}end,
 persist=function(k,v)if fail then return false,"disk_full" end;stored[k]=v;return true end,
 set=function(name,value)
  if name=="VoiceActivation" then s.voiceActivation=value==1 end
  if fail then return false,"disk_full" end
  if name=="PushToTalkKey" then key=value end
  return true
 end})
local v=assert(handler("begin"));assert(v.activation and not s.voiceActivation and not s.transmitting,"local setup suspends VAD without losing the desired mode")
assert(v.key=="MOUSE4" and v.level==.4 and not v.configured)
owner="other";assert(not handler("begin"));assert(handler("end") and not s.voiceActivation,"another consumer cannot close this setup")
owner="op77_lightrp"
assert(not handler("set",{name="InputVolume",value=201}));assert(not handler("set",{name="VoiceActivation",value=.5}));assert(not handler("set",{name="MicrophoneTest",value=1}))
assert(handler("set",{name="PushToTalkKey",value="MOUSE5"}).key=="MOUSE5")
assert(handler("test",true).testing and not s.voiceActivation,"loopback never enables VAD")
fail=true;assert(not handler("set",{name="VoiceActivation",value=1}));assert(not s.voiceActivation,"a failed save must not leak live VAD during setup")
assert(not handler("complete"));fail=false
assert(handler("end") and not s.microphoneTest and s.voiceActivation,"closing restores the saved mode and stops loopback")
handler("begin");handler("test",true)
assert(coroutine.resume(thread));now=4;assert(coroutine.resume(thread));assert(not s.microphoneTest and s.voiceActivation,"lost UI heartbeat ends loopback")
handler("begin");handler("test",true);handlers.onClientResourceStop("op77_lightrp");assert(not s.microphoneTest and s.voiceActivation)
handler("begin");handler("set",{name="VoiceActivation",value=0});handler("complete")
assert(stored['voice.setupComplete'] and not s.voiceActivation and not s.microphoneTest)
assert(handler("begin").configured,"completion persists in the pause resource namespace")
handlers.onClientResourceStop("open77_pause");assert(not s.microphoneTest)
print("PASS: shared preference owner, mouse binding, real meter, mode restore, local-only VAD suspension, malformed values, owner isolation, save failure, heartbeat and resource-stop cleanup")
