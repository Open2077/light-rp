from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/client/core'
lua=LuaRuntime()
lua.execute('''
clock=1000;net={};keys={};threads={};sent={};requests={}
LightRpEvents={page={ready="ready"}};LightRpConfig={keys={hotbar={id="show",name="Show hotbar",key="TAB"}}}
LightRpUi={characterReady=true,dialogs={},send=function(n,p)sent[#sent+1]=p end,log=function()end}
body={alive=true,attached=true};Open77={character={state=function()return body end}}
function GetGameTimer()return clock end
function RegisterNetEvent(n,f)net[n]=f end
function TriggerServerEvent(n,p)requests[#requests+1]=p;return true end
function RegisterKeyMapping(k)keys[k.id]=k;assert(k.consume==true);return true,k.key end
function CreateThread(f)threads[#threads+1]=coroutine.create(f)end
function Wait(ms)coroutine.yield(ms)end
page={handlers={}};function page:on(n,f)self.handlers[n]=f end
''')
lua.execute((root/'hotbar.lua').read_text())
lua.execute('''
LightRpHotbar.bind(page)
net["op77_lightrp:hotbar"]({kind="state",state={ready=true,inventoryId="inv:1",revision=7,items={{slot=1,name="water",count=2}}}})
keys.show.onPressed();assert(sent[#sent].visible==true and sent[#sent].slotKeys[1]=="1")
keys.show.onReleased();assert(not sent[#sent].visible)
keys["lightrp.hotbar.slot1"].onPressed()
assert(requests[#requests].slot==1 and requests[#requests].inventoryId=="inv:1"and requests[#requests].revision==7)
assert(sent[#sent].kind=="activate")
clock=4000;assert(coroutine.resume(threads[1]));assert(not sent[#sent].visible)
local before=#requests
LightRpUi.dialogs.inventory=true;keys["lightrp.hotbar.slot2"].onPressed();keys.show.onPressed();assert(#requests==before)
LightRpUi.dialogs.inventory=false;LightRpUi.creationActive=true;keys["lightrp.hotbar.slot3"].onPressed();assert(#requests==before)
LightRpUi.creationActive=false;body.alive=false;keys["lightrp.hotbar.slot4"].onPressed();assert(#requests==before)
body.alive=true;LightRpActions={isActive=function()return true end};keys["lightrp.hotbar.slot5"].onPressed();assert(#requests==before)
LightRpActions=nil;LightRpUi.supportMode="menu";clock=4400;keys["lightrp.hotbar.slot1"].onPressed();assert(#requests==before)
LightRpUi.supportMode="form";keys.show.onPressed();assert(#requests==before)
LightRpUi.supportMode=nil;clock=4500;keys["lightrp.hotbar.slot5"].onPressed();assert(requests[#requests].slot==5)
''')
print('PASS: Tab hold/release, five consumed/rebindable shortcuts, snapshot references, flash expiry, UI/action/death gates')
