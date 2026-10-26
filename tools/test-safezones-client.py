"""Exercise the actual Lua client bridge, preview batches and focus lifecycle."""
from pathlib import Path
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
clock=0;threads={};net={};events={};keys={};outgoing={};messages={};inputs={};draws={};clears=0;actionClaims={};walk={}
LightRpConfig={movement={modes={{id="run",label="RUN"},{id="walk",label="WALK",speed=1.5},{id="slow",label="SLOW",speed=.9}}}}
LightRpEvents={page={ready="ready",notice="notice"}}
LightRpUi={characterReady=true,creationActive=false,actionFocus=false,
 send=function(name,p) messages[#messages+1]={name=name,p=p} end,
 setSupportInput=function(mode) inputs[#inputs+1]=mode end,
 setMenuOpen=function() end,log=function() end}
character={alive=true,attached=true,position={x=0,y=0,z=0}}
Open77={character={state=function() return character end},debugDraw={
 set=function(k,b) draws[#draws+1]=b;return true end,
 clear=function()clears=clears+1 end},input={setActionBlocked=function(action,blocked) actionClaims[action]=blocked;return true end},
 movement={setWalkMode=function(enabled,speed) walk={enabled=enabled,speed=speed};return true end}}
function RegisterNetEvent(name,fn) net[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function GetCurrentResourceName() return "op77_lightrp" end
function GetGameTimer() return clock end
function TriggerServerEvent(name,p) outgoing[#outgoing+1]={p=p,at=clock} end
function RegisterKeyMapping(id,label,key,fn) keys[key]=fn;return true,key end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=clock} end
function Wait(ms) return coroutine.yield(ms) end
function tick(ms)
 local target=clock+ms
 while true do
  local nextTime=nil
  for _,t in ipairs(threads) do
   if coroutine.status(t.co)~="dead" and t.wake<=target and (not nextTime or t.wake<nextTime) then nextTime=t.wake end
  end
  if not nextTime then clock=target;return end
  clock=nextTime
  for _,t in ipairs(threads) do if coroutine.status(t.co)~="dead" and t.wake<=clock then
   local ok,delay=coroutine.resume(t.co);assert(ok,delay);t.wake=clock+(delay or 0)
  end end
 end
end
page={handlers={}}
function page:on(name,fn) self.handlers[name]=fn end
function receive(p) net["op77_lightrp:safezones"](p) end
function fromPage(p) page.handlers["lightrp:ui:safezones"](p) end
''')
lua.execute((root / 'resources/gamemodes/op77_lightrp/client/core/movement.lua').read_text())
lua.execute((root / 'resources/gamemodes/op77_lightrp/client/core/safezones.lua').read_text())
lua.execute('''
LightRpSafezones.bind(page);LightRpSafezones.start()
page.handlers.ready();tick(1)
assert(outgoing[1].p.operation=="snapshot" and type(outgoing[1].p.request)=="string")
receive({kind="snapshot",generation=2,ready=true,zones={}})
local count=#messages
receive({kind="snapshot",generation=1,ready=true,zones={}})
assert(#messages==count,"older snapshots must be ignored")
receive({kind="open"});assert(LightRpSafezones.active and inputs[#inputs]=="menu")
fromPage({operation="input",mode="form"});assert(inputs[#inputs]=="form")
zone={shape="box",center={x=0,y=0,z=0},length=20,width=10,heading=90,minZ=0,maxZ=5}
local geometry=LightRpSafezones.geometry(zone)
assert(#geometry.lines==16 and #geometry.triangles==8 and geometry.ttl<1)
assert(math.abs(geometry.lines[1].a.x-5)<1e-8 and math.abs(geometry.lines[1].a.y+10)<1e-8,"rotated box preview")
assert(not LightRpSafezones.geometry({shape="circle",center={x=0,y=0,z=0},radius=0/0,minZ=0,maxZ=5}))
assert(not LightRpSafezones.geometry({shape="box",minZ=5,maxZ=0}))
fromPage({operation="preview",zone=zone});tick(100)
assert(#draws>0,"active drafts draw actual debug batches")
keys.F9();assert(LightRpSafezones.mode=="world" and inputs[#inputs]=="closed")
keys.F10();assert(messages[#messages].p.kind=="captureKey")
fromPage({operation="list"});fromPage({operation="capture"});tick(500)
assert(outgoing[#outgoing].at-outgoing[#outgoing-1].at>=180,"all request paths share the throttle")
assert(outgoing[#outgoing].p.request~=outgoing[#outgoing-1].p.request)
character.alive=false;tick(100)
assert(not LightRpSafezones.active and LightRpSafezones.draft==nil and inputs[#inputs]=="closed")
assert(messages[#messages].p.kind=="invalidate" and clears>0)
character.alive=true;receive({kind="open"});fromPage({operation="preview",zone=zone})
receive({kind="invalidate",error="ACL revoked"})
assert(not LightRpSafezones.active and LightRpSafezones.draft==nil)
receive({kind="open"});events.onClientResourceStop("op77_lightrp")
assert(not LightRpSafezones.active and inputs[#inputs]=="closed")
receive({kind="presence",ready=true,zone={id="safe",label="Safe",blockRun=true,blockShoot=true}})
assert(actionClaims.Sprint and actionClaims.Attack and walk.enabled and walk.speed==1.5,"zone claims prevent sprint/shoot and cap normal running at walk speed")
assert(LightRpMovement.index==1,"restriction does not replace the selected movement preference")
LightRpMovement.cycle();LightRpMovement.cycle();assert(walk.speed==.9,"a slower walk preference is preserved")
LightRpMovement.cycle();assert(walk.speed==1.5,"movement hotkey cannot bypass the zone walk cap")
receive({kind="presence",ready=true})
assert(actionClaims.Sprint==false and actionClaims.Attack==false and not walk.enabled and LightRpMovement.index==1,"exit releases only own claims and restores run preference")
LightRpMovement.apply(3)
receive({kind="presence",ready=true,zone={id="safe",label="Safe",blockRun=true,blockShoot=false}})
assert(actionClaims.Sprint and actionClaims.Attack==false and walk.speed==.9,"shoot/run settings are independent")
character.alive=false;tick(100)
assert(actionClaims.Sprint==false and walk.speed==.9,"death releases safezone restriction without dropping chosen slow mode")
character.alive=true;tick(100);assert(actionClaims.Sprint)
receive({kind="snapshot",generation=3,ready=false,zones={}})
assert(actionClaims.Sprint==false,"unavailable policy immediately releases stale client claims")
character.position.z=90
local slice=LightRpSafezones.geometry({shape="circle",center={x=0,y=0,z=0},radius=10,fullHeight=true,minZ=0,maxZ=0})
assert(slice and slice.lines[1].a.z==80 and slice.lines[1].b.z==110,"full-height draft renders a finite slice around author altitude")
receive({kind="presence",ready=true,zone={id="safe",label="Safe",blockRun=true,blockShoot=true}})
events.onClientResourceStop("op77_lightrp")
assert(actionClaims.Sprint==false and actionClaims.Attack==false,"resource stop releases input claims")
''')
print('PASS: client readiness, requests, 3D preview/full-height slice, inspector/world, independent run/shoot claims, walk preference, death/exit/stop cleanup')
