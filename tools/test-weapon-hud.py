"""Read-only weapon HUD snapshots, lifecycle and stock HUD hide claims."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp'
lua=LuaRuntime()
lua.execute('''
clock=1000;sequence=0;events={};threads={};messages={};hidden={};hideAttempts={}
state={ready=true,busy=false,inventoryId="player:test",generation=1,
 right={instanceId="right-uuid",label="Lexington",record="lex"},left={instanceId="left-uuid",label="Nue",record="nue"}}
body={alive=true,attached=true}
LightRpArmamentClient={state=function()return state end}
Open77={character={state=function()return body end},weapons={snapshot=function()sequence=sequence+1;return sequence end}}
function AddEventHandler(n,f)events[n]=f end
function GetGameTimer()return clock end
function row(id,slot,record,mag,cap,reserve,reloading,drawn)
 events["open77:weapons:state"](id,slot,record,"hash:"..record,"true",drawn==false and "false"or "true","false","Ammo.Pistol","pistol",90,reserve,mag,cap,reloading and "true"or "false")
end
function done(id,accepted)events["open77:weapons:completed"](id,"snapshot",accepted or "true")end
''')
lua.execute((root/'client/core/weapon_hud.lua').read_text())
lua.execute('''
local H=LightRpWeaponHud
assert(not H.sample().active and sequence==1)
row(1,1,"lex",21,21,59,false);assert(not H.sample().active,"partial snapshots never publish")
row(1,4,"nue",10,10,59,true);done(1)
local v=H.sample();assert(v.active and #v.hands==2 and v.reserve==59,"one shared reserve, not 118")
assert(v.hands[1].magazine==21 and v.hands[2].reloading)
clock=1200;H.sample();assert(sequence==2)
row(2,1,"lex",-1,-1,-1,false);row(2,4,"nue",-1,-1,-1,false);done(2)
v=H.sample();assert(v.active and v.hands[1].magazine==nil and v.reserve==nil,"unknown is never zero")
clock=1400;H.sample();row(3,1,"lex",0,21,20,false,false);row(3,4,"nue",0,10,20,false,false);done(3)
assert(not H.sample().active,"holstered weapons hide the panel")
clock=1600;H.sample();state.generation=2;done(4);assert(not H.sample().active,"old body completion ignored")
clock=1800;H.sample();row(5,1,"lex",0,21,20,false);row(5,4,"nue",10,10,20,false);done(5)
v=H.sample();assert(v.active and v.hands[1].magazine==0,"known empty magazine remains zero")
clock=2900;assert(not H.sample().active,"stale counts disappear")
body.alive=false;assert(not H.sample().active)
body.alive=true;state.busy=true;assert(not H.sample().active)
state.busy=false;state.right=nil;assert(not H.sample().active)
-- Load the actual main HUD and verify failed native hide claims are retried.
LightRpConfig={voice={default="normal",ranges={normal=15}}};LightRpEvents={page={hud="hud"}}
LightRpUi={send=function(n,v)messages[#messages+1]=v end}
Open77.stats={get=function()return{health={value=100,max=100},stamina={value=100,max=100},armor=0}end}
Open77.hud={setVisible=function(component,value)
 hideAttempts[component]=(hideAttempts[component]or 0)+1
 if component=="weapon"and hideAttempts[component]==1 then return false,"host_not_ready"end
 hidden[component]=value;return true
end}
function CreateThread(f)threads[#threads+1]=coroutine.create(f)end
function Wait(ms)coroutine.yield(ms)end
''')
lua.execute((root/'client/core/hud.lua').read_text())
lua.execute('''
LightRpHud.start();assert(coroutine.resume(threads[1]));assert(not LightRpHud.hidden)
assert(coroutine.resume(threads[1]));assert(LightRpHud.hidden and hidden.weapon==false)
assert(hideAttempts.weapon==2 and hideAttempts.health==1 and hidden.crosshair==nil)
''')
print('PASS: complete dual snapshots, shared reserve, unknown/empty/reloading, holster/death/busy/stale-body cleanup, native weapon hide retry')
