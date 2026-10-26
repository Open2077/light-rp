-- Actual garage + inventory modules, deterministic DB/native boundaries.
local function noop() end
local function clone(t) if type(t) ~= "table" then return t end local c = {}; for k,v in pairs(t) do c[k]=clone(v) end return c end
local encoded, enc = {}, 0
json = { encode = function(t) enc=enc+1; encoded[tostring(enc)]=clone(t); return tostring(enc) end,
    decode = function(s) if s == "{}" then return {} end assert(encoded[s], "invalid JSON"); return clone(encoded[s]) end }
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("server/config/garages.lua")
local C = LightRpGarages
C.garages = { { id="citycenter", name="Central", position={x=0,y=0,z=0}, parking={ {position={x=10,y=0,z=0}}, {position={x=20,y=0,z=0}} } },
    { id="other", name="Other", position={x=100,y=0,z=0}, parking={ {position={x=110,y=0,z=0}} } } }
local threads, handlers, actions, points, messages = {}, {}, {}, {}, {}
local dbRows, inventories, world, uid, nextVehicle = {}, {}, {}, 0, 100
local tick, failDb, failCreate, failApply, failRemove = 1000, false, false, false, false
local intercept, lastDialog
local chars = { [1]={identifier="alice",key="default",status="active"}, [2]={identifier="bob",key="default",status="active"} }
local positions = { [1]={x=0,y=0,z=0,bucket=0}, [2]={x=0,y=1,z=0,bucket=0} }
local lives = { [1]="alive", [2]="alive" }
local seats = {}
local function event(name, ...) for _,fn in ipairs(handlers[name] or {}) do fn(...) end end
local Db = {ready=true, schema=noop}
function Db.read(sql, p)
    if failDb then return false,"database_error" end
    if sql:find("UUID",1,true) then uid=uid+1; return true,{{id=string.format("00000000-0000-0000-0000-%012d",uid)}} end
    if sql:find("lightrp_inventories",1,true) then return true,inventories[p[1]] and {{items=inventories[p[1]]}} or {} end
    local result={}; for _,row in pairs(dbRows) do result[#result+1]=clone(row) end; return true,result
end
function Db.run(sql,p)
    if intercept then local fn=intercept; intercept=nil; fn() end
    if failDb then return false,"database_error" end
    if sql:find("INSERT INTO lightrp_owned_vehicles",1,true) then
        for _,r in pairs(dbRows) do if r.grant_key==p[8] then return false end end
        dbRows[p[1]]={id=p[1],identifier=p[2],character_key=p[3],model=p[4],record=p[5],garage_id=p[6],properties=p[7],grant_key=p[8]}
    elseif sql:find("UPDATE lightrp_owned_vehicles",1,true) then
        dbRows[p[3]].garage_id,dbRows[p[3]].properties=p[1],p[2]
    elseif sql:find("INSERT INTO lightrp_inventories",1,true) then inventories[p[1]]=p[6] end
    return true,1
end
Db.single=function(sql,p) local ok,r=Db.read(sql,p); return ok and r[1] end
Db.transaction=function(queries)
    if failDb then return false,"database_error" end
    for _,q in ipairs(queries) do assert(Db.run(q.query,q.values)) end
    return true
end
LightRP={ db=Db, module=function(name,t) LightRP[name]=t;return t end, command=noop,log=noop,state=noop,stateProvider=noop,notice=noop,result=noop,
    nowMs=function() return tick end, eachModule=noop,
    characters={switching={}, get=function(id) return chars[id] end, displayName=function(id) return chars[id] and chars[id].identifier or "gone" end},
    vehicles={byKey={}}, action=function(name,fn) actions[name]=fn end,
    interaction=function(id,d) points[id]=d end,removeInteraction=noop,
    dialog=function(_,kind,p) assert(kind=="garage");lastDialog=p end,
    keys={lock=function(id,value) world[id].locked=value;return true end,give=function() return true end},
}
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end
Open77={players={position=function(id) return positions[id] end,getLifeState=function(id) return lives[id] and {phase=lives[id]} end},vehicles={}}
local V=Open77.vehicles
V.get=function(id) return world[id] end
V.all=function(bucket) local a={};for _,v in pairs(world) do if not bucket or v.bucket==bucket then a[#a+1]=v end end;return a end
V.getPlayerSeat=function(id) return seats[id] end
V.create=function(d)
    if failCreate then return nil,"spawn_failed" end
    nextVehicle=nextVehicle+1;world[nextVehicle]={id=nextVehicle,record=d.record,position=clone(d.position),bucket=d.bucket,health=1,speed=0,occupants={},persistent=d.persistent}
    return nextVehicle
end
V.getProperties=function(id) local v=world[id];if v then return {record=v.record,health=v.health,paint=v.paint} end end
V.setProperties=function(id,p)
    if failApply then return false,"bad_props" end
    assert(not (p.paint and p.paint.applied==false and (p.paint.primary or p.paint.secondary)),"stock livery must not submit custom colour channels")
    world[id].health=p.health or 1;world[id].paint=p.paint;return true
end
V.setEngine=function() return true end
V.isLocked=function(id) return world[id] and world[id].locked or false end
V.remove=function(id) if failRemove then return false end;world[id]=nil;event("onVehicleRemoved",tostring(id),"admin_cleanup");return true end
CreateThread=function(fn) threads[#threads+1]=fn end
Wait=function() coroutine.yield() end
GetPlayers=function() local t={};for id in pairs(chars) do t[#t+1]=id end;return t end
GetPlayerName=function(id) return chars[id] and chars[id].identifier end
AddEventHandler=function(name,fn) handlers[name]=handlers[name] or {};table.insert(handlers[name],fn) end
TriggerClientEvent=function(name,id,p) messages[#messages+1]={name=name,id=id,payload=p} end
dofile("server/modules/inventory.lua")
dofile("server/modules/garages.lua")
local G, Inv = LightRP.garage, LightRP.inventory
G.onDatabaseReady()
assert(points["garage.citycenter"] and points["garage.other"])
assert(points["garage.citycenter"].blip.icon=="warehouse" and points["garage.other"].blip.icon=="warehouse")
local ok, first=G.grant(1,"hella",nil,"test-delivery")
assert(ok and first and dbRows[first],"durable grant")
local _,again=G.grant(1,"hella",nil,"test-delivery");assert(again==first,"idempotent delivery")
assert(not G.grant(2,"hella",nil,"test-delivery"),"grant key cannot cross owners")
local _, second=G.grant(1,"apollo")
local _, bob=G.grant(2,"galena")
local function open(id,place) assert(G.open(id or 1,place or "citycenter"));return lastDialog end
local function perform(kind,owned,id,override)
    id=id or 1
    local p={type="garage."..kind,session=lastDialog.session,request=lastDialog.nextRequest,vehicle=owned}
    for k,v in pairs(override or {}) do p[k]=v end
    local ok,reason=G.perform(id,p)
    local m=messages[#messages];if m and m.payload.state then lastDialog=m.payload.state end
    return ok,reason,p
end
open();assert(#lastDialog.vehicles==2)
assert(not perform("retrieve",bob),"other player's UUID refused")
assert(not perform("retrieve",first,1,{request=999}),"out of order refused")
open(); local success,_,sent=perform("retrieve",first);assert(success)
local id=nextVehicle;assert(world[id].persistent and world[id].locked and G.ownedId(id)==first)
assert(G.perform(1,sent) and nextVehicle==id,"replay never spawns twice")
assert(not perform("retrieve",second),"one personal car outside")
world[id].health=.43;world[id].paint={applied=false,primary={r=0,g=0,b=0},secondary={r=0,g=0,b=0}};event("onVehicleUpdated",tostring(id))
assert(Inv.addItem("personal:"..first,"water",3))
world[id].occupants={{playerId=2}};assert(not perform("store",first),"passengers protected");world[id].occupants={}
world[id].speed=9;assert(not perform("store",first),"moving car protected");world[id].speed=0
world[id].position.x=60;assert(not perform("store",first),"remote recall refused");world[id].position.x=10
failDb=true;assert(not perform("store",first) and world[id],"DB failure retains live car");failDb=false
assert(perform("store",first) and not world[id],"park after save")
assert(perform("retrieve",first));id=nextVehicle
assert(world[id].health==.43 and Inv.count("personal:"..first,"water")==3,"condition and stable trunk restored")
assert(world[id].paint.applied==false,"stock livery retained on retrieval")
V.remove(id);open();assert(lastDialog.vehicles[1].status=="stored" or lastDialog.vehicles[2].status=="stored")
failDb=true;assert(not perform("retrieve",first),"recovery write must succeed first");failDb=false
assert(perform("retrieve",first));id=nextVehicle
assert(Inv.count("personal:"..first,"water")==3,"forced delete keeps trunk")
failRemove=true;assert(not perform("store",first) and world[id]);assert(not perform("retrieve",first));failRemove=false
assert(perform("store",first))
failCreate=true;assert(not perform("retrieve",first));failCreate=false
failApply=true;assert(not perform("retrieve",first) and not world[nextVehicle]);failApply=false
-- A second player cannot use a bay already occupied by a canonical vehicle.
world[800]={id=800,bucket=0,position={x=10,y=0,z=0}}
world[801]={id=801,bucket=0,position={x=20,y=0,z=0}}
assert(not perform("retrieve",first),"blocked parking")
world[800],world[801]=nil,nil
positions[1].bucket=1;assert(not perform("retrieve",first));positions[1].bucket=0
lives[1]="dead";assert(not G.open(1,"citycenter"));lives[1]="alive"
seats[1]={vehicleId=900};assert(not G.open(1,"citycenter"));seats[1]=nil
open();chars[1].key="slot2";assert(not perform("retrieve",first),"character isolation");chars[1].key="default"
-- A change during an awaited persistence write cannot deliver to the next slot.
open();assert(perform("retrieve",first));id=nextVehicle;V.remove(id);open()
intercept=function() chars[1].key="slot2" end
assert(not perform("retrieve",first),"identity rechecked after yield");chars[1].key="default"
-- Missing removal events are detected by the bounded maintenance worker.
open();assert(perform("retrieve",first));id=nextVehicle;world[id]=nil
local worker=coroutine.create(threads[#threads]);for _=1,10 do assert(coroutine.resume(worker));tick=tick+2000 end
open();assert(perform("retrieve",first));id=nextVehicle
-- Reboot: fresh registry/handlers, same SQL ownership and trunk snapshots.
world={};handlers={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");Inv=LightRP.inventory
dofile("server/modules/garages.lua");G=LightRP.garage;G.onDatabaseReady()
open();assert(#lastDialog.vehicles==2);for _,v in ipairs(lastDialog.vehicles) do assert(v.status=="stored") end
assert(perform("retrieve",first));assert(world[nextVehicle].health==.43)
assert(Inv.count("personal:"..first,"water")==3,"trunk survives reboot and new network ID")
print("garages_test: ownership, replay, storage, recovery, reboot, trunk, identity and failure checks passed")
