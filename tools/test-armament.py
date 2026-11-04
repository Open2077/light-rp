"""Real inventory/armament Lua with deterministic SQL and asynchronous native boundaries.
No live database, player, weapon or service is touched.
"""
from pathlib import Path
import json
import os
from lupa.lua54 import LuaRuntime, lua_type
root = Path(__file__).resolve().parents[1]
os.chdir(root / 'resources/gamemodes/op77_lightrp')
lua = LuaRuntime(unpack_returned_tuples=True)
def unpack(v):
    if lua_type(v) != 'table': return v
    return {str(k): unpack(x) for k,x in v.items()}
def pack(v):
    if isinstance(v, dict): return lua.table_from({int(k) if k.isdigit() else k:pack(x) for k,x in v.items()})
    if isinstance(v, list): return lua.table_from([pack(x) for x in v])
    return v
lua.globals().json_encode=lambda v:json.dumps(unpack(v),sort_keys=True,separators=(',',':'))
lua.globals().json_decode=lambda v:pack(json.loads(v))
lua.execute('''
dofile("shared/config.lua");dofile("shared/items.lua");dofile("shared/events.lua");dofile("shared/armament.lua")
LightRpConfig.inventory.starting={}
json={encode=json_encode,decode=json_decode}
clock=0;threads={};net={};events={};messages={};hooks={};serials={};stored={};operations={};nativeRows={};nativeOwned={};nativeReserve=0;jobs={};sequence=0;uuid=0;failSql=false;suppressNative=false
local function clone(v)if type(v)~="table" then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local noop=function()end
function CreateThread(fn)threads[#threads+1]={co=coroutine.create(fn),wake=clock}end
function Wait(ms)return coroutine.yield(ms)end
function AddEventHandler(n,f)events[n]=events[n] or {};table.insert(events[n],f)end
function RegisterNetEvent(n,f)net[n]=f end
function TriggerClientEvent(n,id,p)messages[#messages+1]={name=n,player=id,p=clone(p)}end
function GetPlayers()return {1}end
function GetPlayerName()return "Test"end
function GetCurrentResourceName()return "op77_lightrp"end
local db={ready=true,schema=noop,run=function()return true,1 end,query=function()return{}end}
function db.read(q,v)
 if q:find("SELECT UUID",1,true)then uuid=uuid+1;return true,{{id=string.format("test-serial-%08d",uuid)}}end
 if q:find("FROM lightrp_weapon_instances",1,true)then return true,serials[v[1]] and {clone(serials[v[1]])} or {}end
 if q:find("FROM lightrp_armament_operations",1,true)then local op=operations[v[1]..":"..v[2]];return true,op and {{operation=op}}or{}end
 if q:find("FROM lightrp_armament",1,true)then return true,stored[v[1]] and {clone(stored[v[1]])}or{}end
 return true,{}
end
function db.transaction(queries)
 if failSql then return false,"database_error"end
 local owners,states,ops=clone(serials),clone(stored),clone(operations)
 local affected=0
 for _,q in ipairs(queries)do
  local s,v=q.query,q.values
  if s:find("INSERT INTO lightrp_weapon_instances ",1,true)then
   if owners[v[1]]then return false,"duplicate"end
   owners[v[1]]={inventory_id=v[2],item_name=v[3],retired=0};affected=1
  elseif s:find("UPDATE lightrp_weapon_instances",1,true)then
   local row=owners[v[3]];affected=row and row.inventory_id==v[4] and row.retired==0 and 1 or 0
   if affected==1 then row.inventory_id=v[1];row.retired=v[2]end
  elseif s:find("INSERT INTO lightrp_weapon_instance_audit",1,true)then
   if affected~=1 then return false,"owner_conflict"end;affected=1
  elseif s:find("INSERT INTO lightrp_armament_operations",1,true)then
   local key=v[1]..":"..v[2];if ops[key]then return false,"duplicate_operation"end;ops[key]=v[3]
  elseif s:find("INSERT INTO lightrp_armament ",1,true)then states[v[1]]={revision=v[2],definition=v[3]}end
 end
 serials,stored,operations=owners,states,ops;return true
end
LightRP={db=db,module=function(n,d)hooks[n]=d;LightRP[n]=LightRP[n]or d;return d end,
 command=noop,action=noop,log=noop,state=noop,stateProvider=noop,notice=noop,result=noop,eachModule=noop,
 nowMs=function()return clock end,characters={switching={},get=function()return{identifier="test",key="default",status="active"}end,displayName=function()return"Test"end}}
Open77={time={monotonic=function()return clock/1000 end},players={getLifeState=function()return{phase="alive"}end,position=function()return{x=0,y=0,z=0}end},vehicles={},weapons={},combat={onDamage=function(f)return f end,offDamage=noop}}
local function snapshot()
 local out={};local total=nativeReserve
 for _,row in pairs(nativeRows)do total=total+row.magazine end
 for slot,row in pairs(nativeRows)do out[#out+1]={slot=slot,record=row.record,tweakDbId="hash:"..row.record,equipped=true,active=slot==1,ammo={total=total,reserve=nativeReserve,magazine=row.magazine,capacity=row.capacity,record="Ammo.Pistol",tweakDbId="pistol"}}end
 return out
end
for _,method in ipairs({"assign","remove","clear","holster","setAmmo","setActive","setDualWieldAllowed","requestSnapshot"})do
 Open77.weapons[method]=function(player,...)
  sequence=sequence+1;jobs[#jobs+1]={id=sequence,player=player,op=method=="requestSnapshot"and"snapshot"or method,args=table.pack(...)};return sequence
 end
end
local function complete(job)
 local a=job.args
 local accepted,reason=true,nil
 if job.op=="assign"then
  if not nativeOwned[a[1]] and a[3].addToInventory==false then accepted=false;reason="weapon_not_owned"
  else nativeOwned[a[1]]=true;nativeRows[a[2]]={record=a[1],capacity=a[1]:find("Nue")and 10 or 21,magazine=0}end
 elseif job.op=="remove"then nativeRows[a[1]]=nil
 elseif job.op=="clear"then nativeRows={};nativeReserve=0
 elseif job.op=="holster"then holsterCount=(holsterCount or 0)+1
 elseif job.op=="setAmmo"then local row=nativeRows[a[1]];assert(row);row.magazine=a[2].magazine or row.magazine;nativeReserve=a[2].reserve or nativeReserve end
 if refuseNext and job.op==refuseNext then accepted,reason=false,"weapon_not_drawn";refuseNext=nil end
 local result=job.op=="snapshot"and snapshot()or{}
 for _,fn in ipairs(events["open77:weapons:completed"]or{})do fn(job.player,job.id,job.op,accepted,reason,result)end
end
function tick(ms)
 local untilTime=clock+ms
 while clock<=untilTime do
  if not suppressNative then local pending=jobs;jobs={};for _,job in ipairs(pending)do complete(job)end end
  for _,t in ipairs(threads)do if coroutine.status(t.co)~="dead"and t.wake<=clock then local ok,delay=coroutine.resume(t.co);assert(ok,delay);t.wake=clock+(delay or 0)end end
  clock=clock+25
 end
end
function request(p)
 source=1;p.request=p.request or "request:"..tostring(clock)
 CreateThread(function()net["op77_lightrp:armament"](p)end)
 tick(700)
 for i=#messages,1,-1 do local m=messages[i];if m.p.kind=="response"and m.p.request==p.request then return m.p end end
end
dofile("server/modules/inventory.lua")
Inv=LightRP.inventory;Inv.onCharacterLoaded(1,LightRP.characters.get(1));inv=Inv.player(1)
dofile("server/modules/armament_store.lua");dofile("server/modules/armament.lua")
W=LightRP.armament
hooks.armament.onDatabaseReady();tick(200)
assert(Inv.addItem(inv.id,"weapon_lexington",1));assert(Inv.addItem(inv.id,"weapon_nue",1));assert(Inv.addItem(inv.id,"ammo_pistol_box",4))
function slotOf(name)for slot,item in pairs(inv.items)do if item.name==name then return slot,item end end end
local rightSlot,rightItem=slotOf("weapon_lexington");local leftSlot,leftItem=slotOf("weapon_nue");local boxSlot=slotOf("ammo_pistol_box")
assert(rightItem.metadata.instanceId~=leftItem.metadata.instanceId and serials[rightItem.metadata.instanceId].inventory_id==inv.id)
local draft=Inv.draft(inv);draft.items[rightSlot].metadata.instanceId="changed";assert(inv.items[rightSlot].metadata.instanceId~="changed","draft metadata isolation")
-- Failed SQL cannot consume the box or credit ammo.
failSql=true
local reply=request({operation="ammo",slot=boxSlot,baseRevision=W.view(1).revision,mutation="test:box:fail"})
assert(reply and not reply.ok,"failed transaction must return a failure");assert(Inv.count(inv.id,"ammo_pistol_box")==4 and W.view(1).ammo.pistol.remaining==0)
failSql=false
local mutation="test:box:success"
reply=request({operation="ammo",slot=boxSlot,baseRevision=W.view(1).revision,mutation=mutation})
assert(reply and reply.ok);tick(800)
assert(Inv.count(inv.id,"ammo_pistol_box")==3 and W.view(1).ammo.pistol.remaining==30)
reply=request({operation="ammo",slot=boxSlot,baseRevision=0,mutation=mutation})
assert(reply and reply.ok and Inv.count(inv.id,"ammo_pistol_box")==3,"replay cannot consume twice")
reply=request({operation="equip",hand="right",slot=rightSlot,instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:equip:right"})
assert(reply and reply.ok);tick(1800)
assert(W.view(1).ready and not W.view(1).error and W.view(1).right.instanceId==rightItem.metadata.instanceId,"native completion settles projection without an error")
assert(not Inv.removeItem(inv.id,"weapon_lexington",1),"equipped firearm cannot be removed")
local ground={id="drop:test",kind="drop",slots=5,maxWeight=100,persistent=false,items={}}
local a,b=Inv.draft(inv),Inv.draft(ground);b.items[1]=a.items[leftSlot];a.items[leftSlot]=nil
assert(not Inv.commitDrafts({{inv,a},{ground,b}}),"ephemeral firearm storage refused")
-- A projection refresh must settle spent ammo before refilling native magazines.
nativeRows[1].magazine=nativeRows[1].magazine-3
reply=request({operation="sync",baseRevision=W.view(1).revision,mutation="test:sync:spent"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).ammo.pistol.remaining==27,"sync cannot refund spent rounds")
reply=request({operation="ammo",slot=boxSlot,baseRevision=W.view(1).revision,mutation="test:box:equipped"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).ammo.pistol.remaining==57,"opening a box while equipped credits exactly thirty rounds")
reply=request({operation="ammo",slot=boxSlot,baseRevision=W.view(1).revision,mutation="test:box:dual"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).ammo.pistol.remaining==87)
reply=request({operation="equip",hand="left",slot=leftSlot,instanceId=leftItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:equip:left"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).ready and W.view(1).left and W.view(1).ammo.pistol.remaining==87,"dual never doubles the shared pool")
assert(nativeRows[1].magazine+nativeRows[4].magazine+nativeReserve==87)
assert(W.damageGate({attacker=1,victim=2,weaponTdbId="hash:"..nativeRows[1].record})==nil,"ready owned weapon damage remains allowed")
-- Inventory Use toggles the equipped pistol off without crediting ammunition.
assert(Inv.use(1,leftSlot));tick(1800)
assert(not W.view(1).left and W.view(1).right and W.view(1).ammo.pistol.remaining==87)
assert(Inv.use(1,leftSlot));tick(1800)
assert(W.view(1).right.instanceId==leftItem.metadata.instanceId and not W.view(1).left and W.view(1).ammo.pistol.remaining==87)
assert(Inv.use(1,leftSlot));tick(1800)
assert(not W.view(1).right and not W.view(1).left and W.view(1).ammo.pistol.remaining==87)
assert(Inv.use(1,rightSlot));tick(1800)
-- Rounds are inventory items: the native pool IS the pocket count of the weapon's ammunition type.
local function nativeTotal() local t=nativeReserve;for _,row in pairs(nativeRows)do t=t+row.magazine end;return t end
assert(W.view(1).right and Inv.count(inv.id,"ammo_pistol")==87 and W.view(1).ammo.pistol.item=="ammo_pistol")
assert(nativeTotal()==87,"native pool = rounds in the pockets")
-- Shots seen by the 2 s observation leave the inventory, in a transaction.
nativeRows[1].magazine=nativeRows[1].magazine-5;tick(2600)
assert(Inv.count(inv.id,"ammo_pistol")==82 and W.view(1).ready,"five shots, five rounds out of the pockets")
-- Rounds bought or received while armed reach the weapon at the next observation.
assert(Inv.addItem(inv.id,"ammo_pistol",40));tick(4500)
assert(nativeTotal()==122 and Inv.count(inv.id,"ammo_pistol")==122 and W.view(1).ready,"new rounds projected")
-- Rounds handed over or dropped while armed leave the native pool too.
assert(Inv.removeItem(inv.id,"ammo_pistol",100));tick(4500)
assert(nativeTotal()==22 and Inv.count(inv.id,"ammo_pistol")==22 and W.view(1).ready,"removed rounds unprojected")
-- An unexplained native increase (world pickup, cheat) never mints rounds: firing stops.
nativeReserve=nativeReserve+10;tick(2600)
assert(not W.view(1).ready and Inv.count(inv.id,"ammo_pistol")==22,"native increase refused")
assert(W.damageGate({attacker=1,victim=2,weaponTdbId="hash:"..nativeRows[1].record})==false,"no damage while unreconciled")
assert(W.synchronize(1));tick(1800)
assert(W.view(1).ready and nativeTotal()==22 and Inv.count(inv.id,"ammo_pistol")==22,"synchronization resets the pool to the pockets")
-- The last round: the pool empties with the pockets, and an empty weapon deals no damage.
nativeRows[1].magazine=0;nativeReserve=0;tick(2600)
assert(Inv.count(inv.id,"ammo_pistol")==0 and W.view(1).ready)
assert(W.damageGate({attacker=1,victim=2,weaponTdbId="hash:"..nativeRows[1].record})==false,"no rounds, no damage")
assert(Inv.addItem(inv.id,"ammo_pistol",60));tick(4500);assert(nativeTotal()==60)
-- An ambiguous native write must not overlap a replacement job. A forged
-- target/operation completion cannot release its quarantine.
suppressNative=true
assert(W.synchronize(1));tick(13000)
assert(W.runtime[1].quarantine and not W.view(1).ready)
assert(not W.synchronize(1))
local pending=jobs[1];assert(pending)
for _,fn in ipairs(events["open77:weapons:completed"])do fn(2,pending.id,pending.op,true,nil,{})end
assert(W.runtime[1].quarantine,"wrong target cannot settle a native job")
suppressNative=false;tick(200)
assert(not W.runtime[1].quarantine and not W.view(1).ready,"late completion requires explicit reconciliation")
assert(W.synchronize(1));tick(1800);assert(W.view(1).ready)
-- The platform's own timeout (request_timeout at 10 s) is final: no completion follows,
-- so the quarantine lifts after a short delay and a full synchronization reconciles.
suppressNative=true
assert(W.synchronize(1));tick(10000)
local stuck;for _,j in ipairs(jobs)do stuck=j end;assert(stuck,"a native job in flight")
for _,fn in ipairs(events["open77:weapons:completed"])do fn(1,stuck.id,stuck.op,false,"request_timeout",nil)end
jobs={} -- the platform forgot it: a late client answer is ignored
tick(100)
assert(W.runtime[1].quarantine and W.runtime[1].quarantine.final and not W.view(1).ready,"quarantined, known final")
suppressNative=false;tick(2500)
assert(W.runtime[1].quarantine,"not before the recovery delay")
tick(4000)
assert(not W.runtime[1].quarantine and W.view(1).ready,"lifted and resynchronized without a reconnect")
-- A client that keeps timing out: each recovery's own synchronization times out again;
-- three recoveries in two minutes, then the quarantine stays until a reconnect.
suppressNative=true
assert(W.synchronize(1))
for _=1,6 do
  tick(10000)
  local j;for _,x in ipairs(jobs)do j=x end
  if j then
    for _,fn in ipairs(events["open77:weapons:completed"])do fn(1,j.id,j.op,false,"request_timeout",nil)end
    jobs={}
  end
  tick(4000)
end
assert(W.runtime[1].quarantine and not W.runtime[1].recovering and #W.runtime[1].recoveries==3,"bounded: past three recoveries the quarantine stays")
-- (a reconnect is a new incarnation; this harness just clears it to go on)
W.runtime[1].quarantine=nil;W.runtime[1].recoveries=nil
suppressNative=false;clock=clock+200000;tick(100);assert(W.synchronize(1));tick(1800);assert(W.view(1).ready)
-- A synchronization in progress does not make the target invincible: the projected
-- firearm still hits; a refusal names its reason in the log.
assert(W.view(1).ready)
local equippedHash="hash:"..nativeRows[1].record
assert(W.synchronize(1) and W.runtime[1].busy)
assert(W.damageGate({attacker=1,victim=2,weaponTdbId=equippedHash,attackKind="ranged"})==nil,"hits during a sync")
tick(1800);assert(W.view(1).ready)
assert(W.damageGate({attacker=1,victim=2,weaponTdbId="hash:not_ours",attackKind="ranged"})==false)
local logged=false;for _,m in ipairs(messages)do if tostring(m):find("refused (not a Light RP firearm",1,true)then logged=true end end
assert(logged or next(W.refusalLoggedAt)~=nil,"the refusal is logged with its reason")
-- One refusal from the engine (the weapon not drawn yet): the synchronization tries again by
-- itself, no second press needed.
refuseNext="snapshot"
assert(W.synchronize(1));tick(300)
assert(not W.view(1).ready and W.runtime[1].syncRetries==1,"refused once: a retry is scheduled")
tick(3000)
assert(W.view(1).ready and W.runtime[1].syncRetries==nil,"the retry went through and the count reset")
-- Retiring the character prevents the previous generation from settling.
suppressNative=true;assert(W.synchronize(1));tick(100)
local old=W.runtime[1];hooks.armament.onLifeState(1,"dead");assert(not W.runtime[1])
suppressNative=false;tick(200);assert(not W.runtime[1] and old~=W.runtime[1])
hooks.armament.onLifeState(1,"alive");tick(1800);assert(W.view(1).ready)
-- A character from before rounds were items: its hidden stock moves into the pockets once.
local pocket=Inv.count(inv.id,"ammo_pistol")
W.states[inv.id].ammo=45
assert(W.synchronize(1));tick(1800)
assert(W.view(1).ready and Inv.count(inv.id,"ammo_pistol")==pocket+45 and W.states[inv.id].ammo==0,"legacy stock moved into the pockets")
assert(json.decode(stored[inv.id].definition).ammo==0,"and persisted with the inventory")
assert(nativeTotal()==pocket+45)
-- Weapon families: only handguns pair; a rifle holds the right hand alone and draws
-- rifle rounds from the pockets, never the handgun rounds.
assert(W.view(1).right and W.view(1).right.name=="weapon_lexington" and not W.view(1).left)
assert(Inv.addItem(inv.id,"weapon_m251s_ajax",1));assert(Inv.addItem(inv.id,"ammo_rifle",45))
local ajaxSlot,ajaxItem=slotOf("weapon_m251s_ajax")
local function equip(hand,slot,item,key)
 return request({operation="equip",hand=hand,slot=slot,instanceId=item.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:family:"..key})
end
reply=equip("left",leftSlot,leftItem,"pair");assert(reply and reply.ok);tick(1800)
assert(W.view(1).left and W.view(1).left.dual,"two handguns pair")
reply=equip("right",ajaxSlot,ajaxItem,"rifle-with-pistol")
assert(reply and not reply.ok and reply.error:find("both hands"),"a rifle cannot join a left-hand pistol")
reply=request({operation="unequip",hand="left",baseRevision=W.view(1).revision,mutation="test:family:unpair"});assert(reply and reply.ok);tick(1800)
local handgunRounds=Inv.count(inv.id,"ammo_pistol")
reply=equip("right",ajaxSlot,ajaxItem,"rifle");assert(reply and reply.ok);tick(1800)
assert(W.view(1).ready and W.view(1).right.ammo=="rifle" and W.view(1).right.class=="rifle")
assert(nativeTotal()==45 and W.view(1).ammo.rifle.remaining==45,"the rifle loads the rifle rounds")
reply=equip("left",leftSlot,leftItem,"pistol-with-rifle")
assert(reply and not reply.ok,"no left-hand pistol beside a rifle")
nativeRows[1].magazine=nativeRows[1].magazine-3;tick(2600)
assert(Inv.count(inv.id,"ammo_rifle")==42 and Inv.count(inv.id,"ammo_pistol")==handgunRounds,"rifle shots spend rifle rounds only")
-- a rifle box unpacks into rifle rounds
assert(Inv.addItem(inv.id,"ammo_rifle_box",1));local rifleBox=slotOf("ammo_rifle_box")
reply=request({operation="ammo",slot=rifleBox,baseRevision=W.view(1).revision,mutation="test:family:box"});assert(reply and reply.ok);tick(1800)
assert(Inv.count(inv.id,"ammo_rifle")==72 and Inv.count(inv.id,"ammo_rifle_box")==0 and nativeTotal()==72)
-- The weapon wheel: the pockets' weapons, handguns first; select draws one, or empties the hands.
local list=W.view(1).arsenal
assert(#list>=3 and list[1].class=="pistol" and list[#list].class=="rifle","handguns first, then by class")
for _,w in ipairs(list)do assert(w.instanceId and w.label and w.ammoLabel and w.rounds==Inv.count(inv.id,LightRpArmament.ammo[w.ammo].item),"rounds per type")end
reply=request({operation="select",instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:wheel:lex"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).ready and W.view(1).right.instanceId==rightItem.metadata.instanceId and not W.view(1).left and W.view(1).holstered==false,"the wheel draws the Lexington")
for _,w in ipairs(W.view(1).arsenal)do if w.instanceId==rightItem.metadata.instanceId then assert(w.hand=="right")end end
reply=request({operation="select",instanceId="not-a-serial-1",baseRevision=W.view(1).revision,mutation="test:wheel:missing"})
assert(reply and not reply.ok,"a weapon that left the pockets cannot be selected")
reply=request({operation="select",unarmed=true,baseRevision=W.view(1).revision,mutation="test:wheel:unarmed"});assert(reply and reply.ok);tick(1800)
assert(not W.view(1).right and not W.view(1).left and next(nativeRows)==nil,"unarmed: both hands empty")
-- Back in the world (reconnect, respawn): the weapon stays equipped but comes back holstered.
reply=request({operation="select",instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:wheel:again"});assert(reply and reply.ok);tick(1800)
local holstersBefore=holsterCount or 0
hooks.armament.onLifeState(1,"dead");hooks.armament.onLifeState(1,"alive");tick(1800)
assert(W.view(1).ready and W.view(1).right and W.view(1).holstered==true and (holsterCount or 0)>holstersBefore,"equipped, but holstered")
-- a pocket refresh of holstered hands stays holstered
holstersBefore=holsterCount;assert(Inv.addItem(inv.id,"ammo_pistol",5));tick(4500)
assert(W.view(1).holstered==true and holsterCount>holstersBefore,"reprojection keeps the holster")
-- a pick that lands during the periodic observe pass waits for it instead of being refused
suppressNative=true;assert(W.synchronize(1,true));assert(W.runtime[1].busy and W.runtime[1].observing)
source=1;local raced;CreateThread(function()net["op77_lightrp:armament"]({operation="select",instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:wheel:race",request="race-1"})end)
tick(100);suppressNative=false;tick(2500)
for i=#messages,1,-1 do local m=messages[i];if m.p.kind=="response"and m.p.request=="race-1"then raced=m.p;break end end
assert(raced and raced.ok,"a select during an observe pass is not refused: "..tostring(raced and raced.error))
-- selecting the holstered weapon draws it again
reply=request({operation="select",instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:wheel:draw"});assert(reply and reply.ok);tick(1800)
assert(W.view(1).holstered==false and W.view(1).right.instanceId==rightItem.metadata.instanceId)
-- A mission kit takes the native slots, then the mission ends: the RP weapon comes back
-- and the kit leaves (the stale pre-mission projection once blocked the return).
local aside=false
local drawn={}
LightRP.missions={handlesLoadout=function() return aside end,
    kitOf=function() return aside and {id="assault",primary="Items.Preset_Ajax_Default",secondary="Items.Preset_Lexington_Default",names={"Militech Ajax","Militech Lexington"}} or nil end,
    drawKit=function(player,slot) drawn[#drawn+1]={player,slot};return true end}
assert(nativeRows[1] and nativeRows[1].record==LightRpArmament.weapons[rightItem.name].record,"the RP weapon is projected")
aside=true
assert(W.synchronize(1,true));tick(200)
-- the wheel lists the kit during the mission, and a pick draws it back
local wheel=W.view(1).arsenal
assert(#wheel==2 and wheel[1].instanceId=="kit:1" and wheel[2].label=="Militech Lexington" and wheel[1].kit,"the kit in the wheel")
reply=request({operation="select",instanceId="kit:2",baseRevision=W.view(1).revision,mutation="test:kit:draw"})
assert(reply and reply.ok and drawn[#drawn][1]==1 and drawn[#drawn][2]==2,"kit slot 2 drawn back")
reply=request({operation="select",instanceId=rightItem.metadata.instanceId,baseRevision=W.view(1).revision,mutation="test:kit:rp"})
assert(reply and not reply.ok,"an RP weapon stays refused during the mission")
nativeRows={[1]={record="Items.Preset_Ajax_Default",capacity=30,magazine=30}};nativeReserve=300
aside=false
assert(#W.view(1).arsenal>=1 and not W.view(1).arsenal[1].kit,"the pockets again after it")
assert(W.synchronize(1));tick(1800)
assert(W.view(1).ready and nativeRows[1] and nativeRows[1].record==LightRpArmament.weapons[rightItem.name].record,"after the mission: the kit is gone, the RP weapon is back")
-- the same with an RP state that no longer matches the pockets: the kit still leaves
local savedRight=W.states[inv.id].right
aside=true
assert(W.synchronize(1,true));tick(200)
nativeRows={[1]={record="Items.Preset_Ajax_Default",capacity=30,magazine=30}};nativeReserve=300
W.states[inv.id].right="gone-serial-0001"
aside=false
assert(W.synchronize(1));tick(1800)
assert(not W.view(1).ready and next(nativeRows)==nil,"an invalid loadout clears the native slots")
W.states[inv.id].right=savedRight
assert(W.synchronize(1));tick(1800);assert(W.view(1).ready)
LightRP.missions=nil
local dup=Inv.draft(inv);dup.items[20]={name=rightItem.name,count=1,metadata={instanceId=rightItem.metadata.instanceId}}
assert(not Inv.commitDrafts({{inv,dup}}),"duplicate serial refused")
print("PASS: serialized grants, draft isolation, SQL rollback, atomic boxes/replay, async equip, equipped-transfer and ephemeral-storage guards, spent-ammo sync, shared dual pool, rounds as inventory items (shots, purchases, drops, increases, empty), legacy stock migration, weapon families (handgun pairs only, rifle pool apart), weapon wheel (arsenal, select, unarmed, holstered on return), timeout quarantine (lifted after a platform request_timeout, bounded) and stale completions")
''')
