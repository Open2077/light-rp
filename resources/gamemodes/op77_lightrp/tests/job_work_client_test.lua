dofile("shared/events.lua")
local events,handlers,sent={},{},{}
local options,done,callback,available=true,nil,nil,true
local cancelled,tracked,waits,animationStops=0,0,0,{}
CreateThread=function(fn) fn() end;Wait=function(ms) assert(ms==900);waits=waits+1 end
Open77={animations={cancel=function(id) animationStops[#animationStops+1]=id end}}
RegisterNetEvent=function(n,f) events[n]=f end;AddEventHandler=function(n,f) handlers[n]=f end
GetCurrentResourceName=function() return "op77_lightrp" end
TriggerServerEvent=function(e,p) sent[#sent+1]={e,p} end
LightRpUi={promptActive=false,menuOpen=false,log=function() end}
LightRpActions={progress=function(o,f) options,done=o,f;if available then return "action" end end,
    cancel=function() cancelled=cancelled+1;done({status="cancelled"}) end,isActive=function() return false end}
LightRpInteract={setLocal=function(_,p,f) callback=f;return p and 1 end,trackBlip=function() tracked=tracked+1 end}
dofile("client/core/job_work.lua")
local function cycle(token,playback) events[LightRpEvents.net.workCycle]({token=token,label="Collect",description="Repeats",icon="hammer",durationMs=5000,playbackId=playback}) end
cycle("one");assert(options.cancellable and options.durationMs==5000);done({status="success"})
assert(sent[#sent][2].token=="one" and sent[#sent][2].status=="success")
local previous=done;cycle("two");previous({status="success"});assert(#sent==1,"late callback ignored")
done({status="cancelled"});assert(sent[#sent][2].token=="two" and sent[#sent][2].status=="cancelled")
cycle("three");events[LightRpEvents.net.workCycle]({cancel=true});assert(cancelled==1 and #sent==2,"server cancellation does not echo a stale completion")
available=false;cycle("four");assert(sent[#sent][2].status=="cancelled","another UI stops the server loop")
events[LightRpEvents.net.workGps]({id="work.scrapper.workshop",position={x=0,y=0,z=0},label="Workshop",radius=2.6})
assert(tracked==1);callback();assert(sent[#sent][1]==LightRpEvents.net.interact and sent[#sent][2]=="work.scrapper.workshop")
handlers.onClientResourceStop("op77_lightrp")
available=true;cycle("five","work:1");assert(waits==1 and LightRpItemWork.isActive());done({status="success"})
assert(LightRpItemWork.isActive() and #animationStops==0,"animation stays active while the server commits")
cycle("six","work:1");assert(waits==1,"successive batches never remount or change camera")
handlers.onAnimationPlaybackFailed(1,"other","failed");assert(LightRpItemWork.isActive())
local sentBefore=#sent;handlers.onAnimationPlaybackFailed(1,"work:1","native_failed")
assert(#sent==sentBefore+1 and sent[#sent][2].token=="six" and not LightRpItemWork.isActive())
cycle("seven","work:2");done({status="cancelled",reason="cancelled"})
assert(animationStops[#animationStops]=="work:2" and not LightRpItemWork.isActive())
cycle("eight","work:3");handlers.onClientResourceStop("op77_lightrp")
assert(animationStops[#animationStops]=="work:3" and not LightRpItemWork.isActive())
print("PASS: automatic cycle handoff, single completion, interruption/UI refusal, native progress cancellation, stage GPS and cleanup")
