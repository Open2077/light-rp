from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/client/core'
lua=LuaRuntime()
lua.execute('''
clock=0;claims={};net={};events={};sent={};outgoing={};threads={};focus={};cancelled={}
LightRpEvents={page={ready="ready",dialogClose="dialog-close"}}
LightRpUi={ready=true,characterReady=true,dialogs={inventory=true},promptActive=true,menuOpen=false,
 send=function(n,p)sent[#sent+1]={n=n,p=p};if n=="dialog-close"then LightRpUi.dialogs.inventory=false;LightRpUi.promptActive=false end end,
 setMenuOpen=function(b)LightRpUi.menuOpen=b end,setSupportInput=function()end,
 page={setFocus=function(self,k,c)focus[#focus+1]={keyboard=k,cursor=c}end}}
LightRpActions={isActive=function()return false end,
 progress=function(options,callback)actionOptions=options;actionCallback=callback;return"test:progress"end,
 cancel=function(id)cancelled[#cancelled+1]=id;if actionCallback then actionCallback({status="cancelled"})end end}
Open77={input={setActionBlocked=function(a,b)claims[a]=b;return true end}}
function RegisterNetEvent(n,f)net[n]=f end
function AddEventHandler(n,f)events[n]=f end
function TriggerServerEvent(n,p)outgoing[#outgoing+1]=p;return true end
function GetGameTimer()return clock end
function GetCurrentResourceName()return"op77_lightrp"end
function CreateThread(f)threads[#threads+1]={co=coroutine.create(f),at=clock}end
function Wait(ms)return coroutine.yield(ms)end
function tick(ms)
 local target=clock+ms
 while clock<=target do
  for _,t in ipairs(threads)do if coroutine.status(t.co)~="dead"and t.at<=clock then local ok,delay=coroutine.resume(t.co);assert(ok,delay);t.at=clock+(delay or 0)end end
  clock=clock+25
 end
end
page={handlers={}};function page:on(n,f)self.handlers[n]=f end
''')
for f in ['control_claims.lua','medical.lua']:lua.execute((root/f).read_text())
lua.execute('''
LightRpMedical.bind(page);page.handlers.ready();assert(outgoing[#outgoing].operation=="state")
local receive=net["op77_lightrp:medical"]
receive({kind="treatment",phase="prepare",token="kit:1",durationMs=8000,patient="Patient"});assert(LightRpMedical.isActive())
tick(100);assert(outgoing[#outgoing].operation=="ready"and outgoing[#outgoing].token=="kit:1")
receive({kind="treatment",phase="play",token="kit:1",durationMs=8000,delayMs=900,patient="Patient"});tick(1000)
assert(actionOptions.allowMovement and actionOptions.durationMs==8000 and actionOptions.cancellable)
actionCallback({status="cancelled"});assert(outgoing[#outgoing].operation=="cancel")
local before=#outgoing;receive({kind="treatment",phase="finished",token="kit:1"});assert(not LightRpMedical.isActive()and #outgoing==before,"server cleanup cannot cancel a newer action")
LightRpControlClaims.set("grenades","Grenade",true)
receive({kind="state",state={downed=true,persisted=true,remainingMs=90000,canGiveUp=false}})
assert(LightRpMedical.isDowned()and claims.Attack and claims.Grenade and claims.Movement)
assert(focus[#focus].keyboard==false and focus[#focus].cursor==true,"downed cursor preserves game voice keys")
page.handlers["lightrp:ui:medical"]({operation="giveup",health=1000,timer=0,target=99})
assert(outgoing[#outgoing].operation=="giveup"and outgoing[#outgoing].health==nil and outgoing[#outgoing].timer==nil)
receive({kind="state",state={downed=false}})
assert(not claims.Attack and not claims.Movement and claims.Grenade,"medical exit preserves other feature claims")
receive({kind="state",state={downed=true}});events.onClientResourceStop("op77_lightrp")
assert(not claims.Attack and claims.Grenade and focus[#focus].keyboard==false and focus[#focus].cursor==false)
''')
print('PASS: medical handoff/progress/cancel, server cleanup, downed cursor/voice, safe input claims and reference-only give-up bridge')
