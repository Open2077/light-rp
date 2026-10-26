from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime()
root=Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/client/core'
lua.execute('''
claims={};net={};events={};sent={};outgoing={}
Open77={input={setActionBlocked=function(a,b)claims[a]=b;return true end}}
LightRpEvents={page={ready="ready"}};LightRpUi={send=function(n,p)sent[#sent+1]=p end}
function RegisterNetEvent(n,f)net[n]=f end
function AddEventHandler(n,f)events[n]=f end
function GetGameTimer()return 1000 end
function GetCurrentResourceName()return "op77_lightrp"end
function TriggerServerEvent(n,p)outgoing[#outgoing+1]=p;return true end
page={handlers={}};function page:on(n,f)self.handlers[n]=f end
''')
for file in ['control_claims.lua','grenades.lua']:lua.execute((root/file).read_text())
lua.execute('''
LightRpGrenadesClient.bind(page);assert(claims.SwitchItem and claims.Grenade)
local receive=net["op77_lightrp:grenades"]
receive({kind="state",state={ready=true,busy=false,selected="grenade_frag",count=3}})
assert(claims.SwitchItem and not claims.Grenade)
LightRpControlClaims.set("safezones","Grenade",true)
receive({kind="state",state={ready=true,busy=false,selected="grenade_frag",count=2}})
assert(claims.Grenade,"ready grenade cannot release a safezone restriction")
LightRpControlClaims.set("safezones","Grenade",false);assert(not claims.Grenade)
receive({kind="state",state={ready=true,busy=false,selected="grenade_frag",count=0}});assert(claims.Grenade)
page.handlers["lightrp:ui:grenades"]({operation="unequip",record="Items.Arbitrary",count=999})
assert(outgoing[1].operation=="unequip"and outgoing[1].record==nil and outgoing[1].count==nil)
events.onClientResourceStop("op77_lightrp");assert(not claims.Grenade and not claims.SwitchItem)
''')
print('PASS: grenade input ownership, stock/readiness, safezone OR, release and reference-only bridge')
