dofile("shared/events.lua");dofile("shared/vehicle_customization.lua")
local threads, net, events, listeners, sent, requests, transforms = {},{},{},{},{},{},{}
local now, frozen, focused, active, nextId, dead, removed, refuse, foreign, moved = 0,false,false,nil,0,false,false,false,false,false
local registry = {}
LightRpUi={ready=true,characterReady=true,dialogs={},send=function(_,p) sent[#sent+1]=p end,log=function() end,
    setMenuOpen=function() end,setPromptFocus=function(v)focused=v end}
GetGameTimer=function()return now end
GetCurrentResourceName=function()return "op77_lightrp" end
CreateThread=function(fn)threads[#threads+1]=coroutine.create(fn)end
Wait=function()coroutine.yield()end
RegisterNetEvent=function(n,fn)net[n]=fn end
AddEventHandler=function(n,fn)events[n]=fn end
TriggerServerEvent=function(_,p)requests[#requests+1]=p;return true end
Open77={
 character={state=function()return{alive=not dead,attached=true}end,setFrozen=function(v)frozen=v;return true end},
 vehicles={get=function(id)if removed then return nil end;return{id=id,position={x=moved and 20 or 0,y=0,z=0},yaw=0,speed=0,occupants={}}end},
 camera={cameras=function()return{held=foreign or active~=nil,activeCamera=active}end,
 create=function(p)nextId=nextId+1;registry[nextId]=p;return nextId end,
 activate=function(id)if refuse then return false,"camera_unavailable"end;active=id;return true end,
 destroy=function(id)registry[id]=nil;if active==id then active=nil end;return true end,
 setTransform=function(id,p)assert(registry[id]);transforms[#transforms+1]=p;return true end}
}
dofile("client/core/vehicle_customization.lua")
local Custom=LightRpVehicleCustomizationClient
Custom.bind({on=function(_,n,fn)listeners[n]=fn end})
local function tick()
 now=now+100
 for _,co in ipairs(threads)do if coroutine.status(co)~="dead"then local ok,why=coroutine.resume(co);assert(ok,why)end end
end
local function open(token)
 net["op77_lightrp:customization"]({kind="open",session=token or "session",vehicle={vehicleId=1}});tick()
end
local function page(command)
 command.session=command.session or "session";listeners["lightrp:ui:customization"](command)
end
open();assert(Custom.isActive() and frozen and focused and active)
tick();local a=transforms[#transforms];tick();local b=transforms[#transforms];assert(a.position.x~=b.position.x,"camera orbits over time")
page({operation="camera",command="rotate",enabled=false});tick();a=transforms[#transforms];tick();b=transforms[#transforms];assert(a.position.x==b.position.x)
page({operation="camera",command="right"});tick();assert(transforms[#transforms].position.x~=b.position.x)
for _=1,40 do page({operation="camera",command="zoomIn"})end;tick();local p=transforms[#transforms].position;assert(math.abs(math.sqrt(p.x*p.x+p.y*p.y)-4)<.001,"zoom bounded")
local count=#requests;page({operation="save",session="forged"});assert(#requests==count)
page({operation="preview",request=1,category="paint",primary="#000000"});assert(requests[#requests].operation=="preview")
page({operation="close"});assert(not Custom.isActive() and not frozen and not focused and not active and next(registry)==nil)
foreign=true;open();assert(not Custom.isActive() and requests[#requests].operation=="close","never steal another camera");foreign=false
refuse=true;open();assert(not Custom.isActive() and not frozen and next(registry)==nil,"activation failure cleans definitions and freeze");refuse=false
open();dead=true;tick();assert(not Custom.isActive() and not frozen and not active);dead=false
open();removed=true;tick();assert(not Custom.isActive());removed=false
open();moved=true;tick();assert(not Custom.isActive());moved=false
open();net["op77_lightrp:customization"]({kind="closed",session="stale"});assert(Custom.isActive(),"old session cannot close current camera")
events.onClientResourceStop("op77_lightrp");assert(not Custom.isActive() and not frozen and next(registry)==nil)
print("customization client: orbit, pause, controls, bounded zoom, session correlation, refusal, death, removal and resource cleanup passed")
