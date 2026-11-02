from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/client/core'
lua=LuaRuntime()
lua.execute('''
claims={};net={};events={};sent={};out={};threads={};clock=0
Open77={input={setActionBlocked=function(action,b) claims[action]=b;return true end}}
LightRpEvents={page={ready="ready"}}
LightRpUi={send=function(n,p)sent[#sent+1]=p end}
function RegisterNetEvent(n,f)net[n]=f end
function AddEventHandler(n,f)events[n]=f end
function GetGameTimer()return clock end
function GetCurrentResourceName()return "op77_lightrp" end
function TriggerServerEvent(n,p)out[#out+1]=p;return true end
function CreateThread(f)threads[#threads+1]=f end
function Wait(ms)clock=clock+ms end
page={handlers={}}
function page:on(n,f)self.handlers[n]=f end
''')
for name in ['control_claims.lua','armament.lua']:lua.execute((root/name).read_text())
lua.execute('''
LightRpArmamentClient.bind(page)
assert(claims.WeaponWheel and claims.NextWeapon, "inventory owns native weapon selection immediately")
LightRpControlClaims.set("safezones","WeaponWheel",true)
LightRpControlClaims.set("safezones","WeaponWheel",false)
assert(claims.WeaponWheel and claims.NextWeapon, "leaving a zone cannot restore the native wheel")
page.handlers.ready();assert(#threads==1);threads[1]();assert(out[1].operation=="state")
local receive=net["op77_lightrp:armament"]
receive({kind="state",state={busy=true,ready=false,right={instanceId="serial"}}})
assert(claims.Attack and claims.Reload)
LightRpControlClaims.set("safezones","Attack",true)
receive({kind="state",state={busy=false,ready=true,right={instanceId="serial"}}})
assert(claims.Attack and not claims.Reload)
LightRpControlClaims.set("safezones","Attack",false);assert(not claims.Attack)
receive({kind="state",state={ready=false,right={instanceId="serial"}}});assert(claims.Attack)
-- a mission kit (or drawn blades): the armament stands aside; a "not ready" state after a death
-- must not gate the kit's fire, and the kit's two weapons switch natively
receive({kind="state",state={ready=false,busy=false,standAside=true,right={instanceId="serial"}}})
assert(not claims.Attack and not claims.Reload and not claims.WeaponWheel and not claims.NextWeapon, "standing aside: no gate")
receive({kind="state",state={ready=false,right={instanceId="serial"}}});assert(claims.Attack and claims.WeaponWheel, "back from the mission: gated again")
events.onClientResourceStop("op77_lightrp");assert(not claims.Attack and not claims.WeaponWheel and not claims.NextWeapon)
for i=1,33 do page.handlers["lightrp:ui:armament"]({operation="sync",request="r"..i}) end
assert(sent[#sent].ok==false and sent[#sent].request=="r33")
''')
print('PASS: armament bridge caching, queue bound, independent safezone/equipment input claims, standing aside for a mission kit')
