dofile("shared/events.lua");dofile("shared/vehicle_customization.lua")
local threads, net, events, listeners, sent, requests, transforms = {},{},{},{},{},{},{}
local now, frozen, focused, active, nextId, dead, removed, refuse, foreign, moved = 0,false,false,nil,0,false,false,false,false,false
local registry = {}
local cinematic,failCinematic=false,false
local ordinaryHudClaim=true -- a separate pre-existing HUD restriction
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
 hud={setCinematic=function(enabled,height) if enabled and failCinematic then return false,"cinematic_unavailable_on_this_host"end;if enabled then assert(height==.01)end;cinematic=enabled;return true end},
 character={state=function()return{alive=not dead,attached=true}end,setFrozen=function(v)frozen=v;return true end},
 vehicles={get=function(id)if removed then return nil end;return{id=id,position={x=moved and 20 or 0,y=0,z=0},yaw=0,speed=0,occupants={}}end},
 camera={cameras=function()return{held=foreign or active~=nil,activeCamera=active}end,
 create=function(p)nextId=nextId+1;registry[nextId]=p;return nextId end,
 activate=function(id)if refuse then return false,"camera_unavailable"end;active=id;return true end,
 destroy=function(id)registry[id]=nil;if active==id then active=nil end;return true end,
 setTransform=function(id,p)assert(registry[id]);transforms[#transforms+1]=p;return true end}
}
-- The client only relays: any vehicle mutation from this side is a test failure. It may
-- read what its own game renders (customizationAvailable), nothing else.
local READ_ONLY={customizationAvailable=true}
setmetatable(Open77.vehicles,{__index=function(_,k) if READ_ONLY[k] then return nil end;error("client-side vehicle native called: "..tostring(k)) end})
dofile("client/core/vehicle_customization.lua")
local Custom=LightRpVehicleCustomizationClient
Custom.bind({on=function(_,n,fn)listeners[n]=fn end})
local function tick()
 now=now+100
 for _,co in ipairs(threads)do if coroutine.status(co)~="dead"then local ok,why=coroutine.resume(co);assert(ok,why)end end
end
-- The server sends the category tree as JSON text (too deep for a net event); json.decode
-- here hands back the table the server encoded.
local wire={}
json={decode=function(s) return assert(wire[s],"not JSON") end}
local function open(token)
 wire.categories={{id="paint",available=true},{id="lights",available=false,reason="unsupported"},{id="trim",available=true,options={{id="a",label="A"}}}}
 net["op77_lightrp:customization"]({kind="open",session=token or "session",vehicle={vehicleId=1,model="hella",lightsHue=.5},
  categoriesJson="categories",prices={paint=2500,lights=500,trim=2500}});tick()
end
local function page(command)
 command.session=command.session or "session";listeners["lightrp:ui:customization"](command)
end
open();assert(Custom.isActive() and frozen and focused and active and cinematic)
local opened;for i=#sent,1,-1 do if sent[i].kind=="open" then opened=sent[i];break end end
assert(opened and opened.categories[2].available==false and opened.categories[3].options[1].id=="a" and opened.prices.lights==500,"category availability and trims reach the page untouched")
assert(opened.categoriesJson==nil,"the page gets the decoded tree, not the JSON text")
tick();local a=transforms[#transforms];tick();local b=transforms[#transforms];assert(a.position.x~=b.position.x,"camera orbits over time")
page({operation="camera",command="rotate",enabled=false});tick();a=transforms[#transforms];tick();b=transforms[#transforms];assert(a.position.x==b.position.x)
page({operation="camera",command="right"});tick();assert(transforms[#transforms].position.x~=b.position.x)
for _=1,40 do page({operation="camera",command="zoomIn"})end;tick();local p=transforms[#transforms].position;assert(math.abs(math.sqrt(p.x*p.x+p.y*p.y)-4)<.001,"zoom bounded")
local count=#requests;page({operation="save",session="forged"});assert(#requests==count)
page({operation="preview",request=1,category="paint",primary="#000000"});assert(requests[#requests].operation=="preview")
-- Lights and trim requests reach the server unchanged: the client names no native.
page({operation="preview",request=2,category="lights",color="#00D8FF"})
assert(requests[#requests].category=="lights" and requests[#requests].color=="#00D8FF" and requests[#requests].request==2)
page({operation="save",request=3,category="lights",stock=true,pay="bank"})
assert(requests[#requests].operation=="save" and requests[#requests].stock==true and requests[#requests].pay=="bank")
page({operation="preview",request=4,category="trim",trim="some_variant"})
assert(requests[#requests].category=="trim" and requests[#requests].trim=="some_variant")
count=#requests;page({operation="preview",session="forged",category="lights",color="#FF0000"});page({operation="save",session="forged",category="trim",trim="x"})
assert(#requests==count,"another session's lights/trim requests are dropped")
page({operation="close"});assert(not Custom.isActive() and not frozen and not focused and not active and next(registry)==nil and not cinematic and ordinaryHudClaim)
failCinematic=true;open();assert(not Custom.isActive() and not frozen and not focused and not cinematic and next(registry)==nil,"cinematic failure releases all presentation state");failCinematic=false
foreign=true;open();assert(not Custom.isActive() and requests[#requests].operation=="close","never steal another camera");foreign=false
refuse=true;open();assert(not Custom.isActive() and not frozen and next(registry)==nil,"activation failure cleans definitions and freeze");refuse=false
open();dead=true;tick();assert(not Custom.isActive() and not frozen and not active and not cinematic);dead=false
open();removed=true;tick();assert(not Custom.isActive());removed=false
open();moved=true;tick();assert(not Custom.isActive());moved=false
open();net["op77_lightrp:customization"]({kind="closed",session="stale"});assert(Custom.isActive(),"old session cannot close current camera")
events.onClientResourceStop("op77_lightrp");assert(not Custom.isActive() and not frozen and next(registry)==nil and not cinematic)
print("customization client: orbit, pause, controls, bounded zoom, session correlation, lights/trim relay without natives, refusal, death, removal and resource cleanup passed")
-- Phase 2: what this game can show, per-category framing, the stage respawn and skipped parts.
local Studio=LightRpVehicleCustomization
local look={twintone=false,rev=3,appliedRev=3,skipped={}}
rawset(Open77.vehicles,"customizationAvailable",function(id) assert(id==1);return look end)
local states={lightrp_vk_rims="running",lightrp_vk_body="stopped"}
GetResourceState=function(name) return states[name] or "missing" end
Open77.data={vehicle=function(record) if record:find("_o77s2",1,true) then return nil,"record_unknown" end;return {record=record} end}
local function lastSent(kind) for i=#sent,1,-1 do if sent[i].kind==kind then return sent[i] end end end
local function find(list,id) for _,c in ipairs(list)do if c.id==id then return c end end end
net["op77_lightrp:customization"]({kind="open",session="session",vehicle={vehicleId=1,model="hella"},categories={
  {id="rims",available=true,pack="lightrp_vk_rims"},{id="body",available=true,pack="lightrp_vk_body"},{id="livery",available=true},
  {id="performance",available=true,options={current=0,stages={{stage=0,record="Vehicle.base",available=true},{stage=1,record="Vehicle.base_o77s1",available=true},
   {stage=2,record="Vehicle.base_o77s2",available=true},{stage=3,available=false}}}}}});tick()
opened=lastSent("open")
assert(find(opened.categories,"rims").available and find(opened.categories,"body").reason==Studio.unsupported.clientPack,"a parts pack this game has not loaded is greyed")
assert(find(opened.categories,"livery").reason==Studio.unsupported.clientLivery,"no two-tone component in this game")
local stages=find(opened.categories,"performance").options.stages
assert(find(opened.categories,"performance").available and stages[2].available and stages[3].missing and stages[3].available==false,"a stage record TweakXL did not create is greyed")
-- Framing: the rims preset eases in, then holds (no orbit).
page({operation="camera",command="preset",category="rims"})
assert(lastSent("camera").rotating==false)
for _=1,10 do tick() end
local rimsShot=Studio.camera.presets.rims
p=transforms[#transforms].position
assert(math.abs(math.sqrt(p.x*p.x+p.y*p.y)-rimsShot.radius)<.001 and math.abs(p.z-rimsShot.height)<.001,"rims framing reached")
assert(math.abs(p.x-math.cos(math.rad(rimsShot.angle))*rimsShot.radius)<.001,"angle relative to the car's heading")
tick();assert(transforms[#transforms].position.x==p.x,"no orbit on the rims framing")
page({operation="camera",command="preset",category="neon"});for _=1,10 do tick() end
assert(lastSent("camera").rotating==true and math.abs(transforms[#transforms].position.z-Studio.camera.presets.neon.height)<.001)
-- A stage purchase rebuilds the car: the studio survives the respawn, not a real removal.
page({operation="save",request=9,category="performance",stage=1,pay="bank"});assert(requests[#requests].category=="performance")
removed=true;tick();tick();assert(Custom.isActive(),"the car vanishing during a stage respawn keeps the studio")
removed=false;moved=true;tick();assert(Custom.isActive(),"the rebuilt car may settle elsewhere");tick();assert(Custom.isActive())
moved=false;now=now+9000;tick();assert(not Custom.isActive(),"after the grace, a car that moves closes the studio as before")
-- Skipped parts: a warning once this game has applied the change.
open()
look.skipped={"attach:rims.fl:model_not_registered"};look.appliedRev=2
net["op77_lightrp:customization"]({kind="response",session="session",ok=true,category="rims",request=1})
for _=1,20 do tick() end;assert(lastSent("warning")==nil,"no warning before the game applied the change")
look.appliedRev=3;for _=1,10 do tick() end
assert(lastSent("warning").text==Studio.warnings.model_not_registered and lastSent("warning").category=="rims")
local warnings=0;for _,m in ipairs(sent)do if m.kind=="warning" then warnings=warnings+1 end end
look.skipped={"attach:op77_lightrp:wing_gt:slot_absent","attach:rims.fl:model_not_registered"}
net["op77_lightrp:customization"]({kind="response",session="session",ok=true,category="body",request=2});for _=1,20 do tick() end
assert(lastSent("warning").text==Studio.warnings.slot_absent and lastSent("warning").category=="body","body parts warn by their own key")
local after=0;for _,m in ipairs(sent)do if m.kind=="warning" then after=after+1 end end;assert(after==warnings+1,"one warning per change")
page({operation="close"})
print("customization client phase 2: pack/livery/stage greying from this game, eased framing presets, stage respawn grace, skipped-part warnings passed")

