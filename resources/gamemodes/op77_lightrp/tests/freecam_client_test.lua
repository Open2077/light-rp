-- Free camera: lifecycle, flight, the radius leash, the floor, pauses and every way out.
dofile("shared/events.lua");dofile("shared/config.lua")
local E=LightRpEvents.page
local settings=LightRpConfig.freecam
local now,threads,events,mappings,callbacks=0,{}, {}, {}, {}
local held,cam,supported,destroyed,deactivated=false,nil,true,0,0
local captured,inVehicle,failBlock=false,false,false
local pressed,axes,blocks={}, {mouseDeltaX=0,mouseDeltaY=0,mouseWheel=0},{}
local character={alive=true,attached=true,position={x=10,y=20,z=5}}
local view={position={x=10,y=20,z=6.6},forward={x=0,y=1,z=0},fov=80}
local state,notices,menuClosed={active=false},{},0
local function step(n) for _=1,n or 1 do now=now+16
    for _,thread in ipairs(threads) do if coroutine.status(thread)~="dead" then local ok,why=coroutine.resume(thread);assert(ok,why) end end end end
GetGameTimer=function() return now end
GetCurrentResourceName=function() return "op77_lightrp" end
AddEventHandler=function(name,fn) events[name]=fn end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
RegisterKeyMapping=function(id,_,key,fn) mappings[id]={key=key,fn=fn};return true,key end
LightRpUi={ready=true,characterReady=true,creationActive=false,dialogs={},log=function() end,
    setMenuOpen=function(open) if not open then menuClosed=menuClosed+1 end end,
    send=function(name,payload) if name==E.freecam then state=payload elseif name==E.notice then notices[#notices+1]=payload.body end;return true end}
Open77={camera={},players={},input={},character={state=function() return character end},session={isMenuOpen=function() return false end}}
local C,P,I=Open77.camera,Open77.players,Open77.input
function C.view() return view end
function C.create(options) cam={position=options.position,rotation=options.rotation,fov=options.fov,thirdPersonBody=options.thirdPersonBody};return 1 end
function C.destroy() cam=nil;held=false;destroyed=destroyed+1;return true end
function C.cameras() return {held=held,activeCamera=held and 1 or 0,cameras=cam and {{id=1,thirdPersonBody=supported and cam.thirdPersonBody}} or {}} end
function C.activate() held=true;return true,{await=function() return true end} end
function C.deactivate() held=false;deactivated=deactivated+1;return true,{await=function() return true end} end
function C.setTransform(_,pose) cam.position,cam.rotation,cam.fov=pose.position,pose.rotation,pose.fov;return true end
function P.isInVehicle() return inVehicle end
function P.resetControls() error("the walk mode shares these blocks: release them by name") end
for _,name in ipairs({"freezePosition","freezeRotation","allowJump","allowAim","allowShoot","allowWeapons","allowInteraction","allowDodge"}) do
    P[name]=function(value)
        if failBlock and name=="allowJump" and value==false then return false,"block_failed" end
        local blocking=(name:sub(1,6)=="freeze")==value
        blocks[name]=blocking or nil;return true
    end
end
function I.isCaptured() return captured end
function I.keyFor(id) return mappings[id] and mappings[id].key end
function I.axis(name) return axes[name] end
function I.isDown(key) return pressed[key] or false end
dofile("client/core/freecam.lua")
local F=LightRpFreecam
F.bind({on=function(_,name,fn) callbacks[name]=fn end})
local function key(name) return mappings[settings.keys[name].id] end
local function off() return not F.isActive() and state.active==false and not next(blocks) and not held end
local function distance() local p,c=cam.position,character.position;return math.sqrt((p.x-c.x)^2+(p.y-c.y)^2+(p.z-c.z-1)^2) end

-- Every key is a mapping the player can rebind; the menu learns the toggle key.
for name,binding in pairs(settings.keys) do assert(mappings[binding.id] and mappings[binding.id].key==binding.key,name) end
assert(F.key()==settings.keys.toggle.key)

-- The key opens it: complete body, the character blocked, the page told.
key("toggle").fn();step(2)
assert(F.isActive() and state.active and state.phase=="active" and cam.thirdPersonBody==true and menuClosed==1)
assert(blocks.freezePosition and blocks.freezeRotation and blocks.allowJump and blocks.allowWeapons and blocks.allowInteraction)
assert(state.radius==settings.radius and state.hints==true and state.keys.toggle=="F5" and state.keys.forward=="forward")
-- From first person the first shot is behind and above the character.
assert(cam.position.y<character.position.y and cam.position.z>character.position.z+1)

-- Flying eases in, moves the lens and never the character.
local startY=cam.position.y
pressed.forward=true;step();local first=cam.position.y-startY;step(30);local cruising=cam.position.y
step();local last=cam.position.y-cruising
assert(first>0 and last>first*2,"speed builds up instead of starting at full pace")
pressed.forward=false;step();assert(cam.position.y>cruising+last*.3,"and dies down instead of stopping dead")
assert(character.position.x==10 and character.position.y==20)

-- Chat or the player menu: the shot holds still and forgets the mouse.
step(40);captured=true;local held_y,heldYaw=cam.position.y,cam.rotation.yaw
pressed.forward=true;axes.mouseDeltaX=900;step(5)
assert(cam.position.y==held_y and cam.rotation.yaw==heldYaw and state.paused==true)
key("exit").fn();assert(F.isActive(),"the exit key belongs to the menu while it is open")
captured=false;pressed.forward=false;step(3);assert(cam.rotation.yaw==heldYaw and state.paused==false)

-- Mouse look is smoothed towards its target; the wheel sets speed, precision + wheel the lens.
axes.mouseDeltaX=1000;step();local turned=(heldYaw-cam.rotation.yaw)%360
assert(turned>0 and turned<100*settings.sensitivity*1.5,"the first frame covers part of the turn");step(60)
axes.mouseWheel=1;step(10);assert(math.abs(state.speed-settings.speed*1.15)<.06,"one notch, one step of speed")
pressed.CTRL=true;axes.mouseWheel=3;step(80);pressed.CTRL=false
assert(math.abs(cam.fov-(settings.fov.default-6))<.2,"zoom glides to its target")

-- The leash: a long push ends on the sphere, sliding, never beyond it.
key("reset").fn();step(2);pressed.back=true;pressed.SHIFT=true;step(1500)
assert(distance()<=settings.radius+.001 and distance()>settings.radius-.5 and state.distance<=settings.radius)
pressed.back=false;pressed.SHIFT=false
-- The floor: no filming from under the ground.
pressed.C=true;step(1500);pressed.C=false
assert(cam.position.z>=character.position.z-settings.below-.001)

-- Reset comes back behind the character; hints toggle and are remembered.
key("reset").fn();step();assert(distance()<5)
key("hints").fn();assert(state.hints==false)

-- Leaving glides back to the player's view and frees the character.
key("exit").fn();assert(off() and deactivated==1);step();assert(destroyed==1)
now=now+400;key("toggle").fn();step(2);assert(state.active and state.hints==false,"the hidden reminder stays hidden")
-- Already in third person: the shot starts exactly where the view is.
now=now+400;key("toggle").fn();step();assert(off())
view.position={x=10,y=16.5,z=7};now=now+400;callbacks[E.freecam]({operation="toggle"});step(2)
assert(F.isActive() and cam.position.y<=16.5 and cam.position.y>16.4,"the player menu opens it too, with no jump")

-- Everything that ends it, each leaving nothing behind.
character.alive=false;step();assert(off());character.alive=true
local function open() now=now+400;assert(F.start());step(2);assert(F.isActive()) end
open();inVehicle=true;step();assert(off());inVehicle=false
open();LightRpUi.dialogs.shop=true;step();assert(off());LightRpUi.dialogs.shop=false
open();character.position={x=30,y=20,z=5};step();assert(off(),"a teleport closes it");character.position={x=10,y=20,z=5};view.position={x=10,y=20,z=6.6}
open();held=false;step();assert(off(),"a view taken away is noticed")
open();events.onClientResourceStop("op77_lightrp");assert(off())

-- Refusals are told to the player and leave nothing behind.
local function refused(pattern) local n=#notices;now=now+400;local ok=F.start();assert(not ok and off() and #notices==n+1 and notices[#notices]:find(pattern),notices[#notices]) end
inVehicle=true;refused("vehicle");inVehicle=false
LightRpUi.dialogs.inventory=true;refused("Finish");LightRpUi.dialogs.inventory=false
held=true;now=now+400;assert(not F.start() and not F.isActive() and not next(blocks) and notices[#notices]:find("already in use"),"a view held by the tutorial or the creator is never taken");held=false
supported=false;refused("Update");supported=true
failBlock=true;refused("block_failed");failBlock=false
settings.enabled=false;refused("disabled");settings.enabled=true
print("PASS: free camera keys, body, eased flight, pause, zoom, leash, floor, reset, exits and refusals")
