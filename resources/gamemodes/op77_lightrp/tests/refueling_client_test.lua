dofile("shared/events.lua"); dofile("shared/config.lua")
local E=LightRpEvents
local time=10000
local handlers,hooks,threads,sent,page,locals,cancels={},{},{},{},{},{},{}
local activity,callback
RegisterNetEvent=function(k,fn) handlers[k]=fn end
AddEventHandler=function(k,fn) hooks[k]=fn end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=coroutine.yield; GetGameTimer=function() return time end
GetCurrentResourceName=function() return "op77_lightrp" end
TriggerServerEvent=function(k,data) sent[#sent+1]={event=k,data=data} end
Open77={animations={cancel=function(id) cancels[#cancels+1]=id end},input={keyFor=function() return "K" end}}
LightRpUi={ready=true,characterReady=true,dialogs={},send=function(k,data)
    page[#page+1]={event=k,data=data}
    if k==E.page.dialogClose then LightRpUi.dialogs[data.kind]=false; LightRpUi.promptActive=false end
end}
LightRpInteract={setLocal=function(id,entry,fn) locals[id]=entry and {entry=entry,callback=fn} or nil end}
LightRpActions={isActive=function() return activity~=nil end,cancel=function() activity=nil end,progress=function(options,fn)
    activity=options; callback=fn; return "progress1"
end}
dofile("client/core/refueling.lua")
local function resumeLast() local ok,err=coroutine.resume(threads[#threads]); assert(ok,err) end
local function fire(p) handlers[E.net.fuel](p) end
local function setup()
    if LightRpRefueling.isActive() then fire({token="ticket",phase="finished"}) end
    time=time+10000; LightRpUi.dialogs={fuel=true}; LightRpUi.promptActive=true; sent={}; activity=nil
end
setup(); fire({token="ticket",phase="prepare"}); resumeLast()
assert(LightRpRefueling.isActive() and not LightRpUi.dialogs.fuel and sent[1].event==E.net.fuelReady,"UI releases focus before readiness")
fire({token="ticket",phase="approach",position={x=0,y=0,z=0},label="Test",expiresMs=45000})
assert(locals["fuel.current"] and page[#page].data.cancelKey=="K","on-foot approach and actual cancel binding")
locals["fuel.current"].callback(); local presses=#sent; locals["fuel.current"].callback(); assert(#sent==presses,"E debounced")
fire({token="ticket",phase="play",playbackId="anim1",durationMs=5000,litres=6,itemLabel="Test",label="Refuelling"})
assert(not locals["fuel.current"]); resumeLast(); assert(not activity,"native starts before input capture")
time=time+900; resumeLast(); assert(activity.durationMs==5000 and activity.allowMovement==false)
callback({status="success"}); assert(sent[#sent].event==E.net.fuelFinish and sent[#sent].data.status=="success")
local count=#sent; callback({status="success"}); assert(#sent==count,"one completion only")
fire({token="ticket",phase="finished"}); assert(not activity and not LightRpRefueling.isActive())
setup(); fire({token="ticket",phase="prepare"}); resumeLast(); fire({token="other",phase="prepare"})
assert(sent[#sent].data.token=="other" and sent[#sent].data.status=="cancelled","reject concurrent ticket without replacing old one")
fire({token="other",phase="finished"}); assert(LightRpRefueling.isActive(),"stale finish cannot clear current")
LightRpRefueling.cancel(); assert(sent[#sent].data.token=="ticket" and sent[#sent].data.status=="cancelled")
fire({token="ticket",phase="finished"})
setup(); fire({token="ticket",phase="prepare"}); resumeLast()
fire({token="ticket",phase="play",playbackId="anim2",durationMs=5000,litres=6,itemLabel="Test",label="Refuelling"})
resumeLast(); fire({token="ticket",phase="finished"}); time=time+900; resumeLast(); assert(not activity,"no late progress after cancellation")
setup(); fire({token="ticket",phase="prepare"}); resumeLast()
fire({token="ticket",phase="play",playbackId="anim3",durationMs=5000,litres=6,itemLabel="Test",label="Refuelling"})
hooks.onAnimationPlaybackFailed(1,"unrelated"); assert(sent[#sent].event==E.net.fuelReady)
hooks.onAnimationPlaybackFailed(1,"anim3"); assert(sent[#sent].data.status=="cancelled" and cancels[#cancels]=="anim3")
hooks.onClientResourceStop("op77_lightrp"); assert(not LightRpRefueling.isActive())
local before=#page; LightRpUi.dialogs.fuel=false; handlers[E.net.fuelSnapshot]({}); assert(#page==before,"late refresh cannot reopen a closed pump")
print("PASS fuel client: UI handoff, approach, cancel binding, progress, duplicate/stale events, native failure, cleanup")
