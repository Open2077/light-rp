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
 elseif job.op=="setAmmo"then local row=nativeRows[a[1]];assert(row);row.magazine=a[2].magazine or row.magazine;nativeReserve=a[2].reserve or nativeReserve end
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
-- Retiring the character prevents the previous generation from settling.
suppressNative=true;assert(W.synchronize(1));tick(100)
local old=W.runtime[1];hooks.armament.onLifeState(1,"dead");assert(not W.runtime[1])
suppressNative=false;tick(200);assert(not W.runtime[1] and old~=W.runtime[1])
hooks.armament.onLifeState(1,"alive");tick(1800);assert(W.view(1).ready)
local dup=Inv.draft(inv);dup.items[20]={name=rightItem.name,count=1,metadata={instanceId=rightItem.metadata.instanceId}}
assert(not Inv.commitDrafts({{inv,dup}}),"duplicate serial refused")
print("PASS: serialized grants, draft isolation, SQL rollback, atomic boxes/replay, async equip, equipped-transfer and ephemeral-storage guards, spent-ammo sync, shared dual pool, timeout quarantine and stale completions")
''')
