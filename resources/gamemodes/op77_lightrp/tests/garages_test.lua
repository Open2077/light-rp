-- Actual garage + inventory modules, deterministic DB/native boundaries.
local function noop() end
local function clone(t) if type(t) ~= "table" then return t end local c = {}; for k,v in pairs(t) do c[k]=clone(v) end return c end
local encoded, enc = {}, 0
json = { encode = function(t) enc=enc+1; encoded[tostring(enc)]=clone(t); return tostring(enc) end,
    decode = function(s) if s == "{}" then return {} end assert(encoded[s], "invalid JSON"); return clone(encoded[s]) end }
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("server/config/garages.lua")
assert(LightRpGarages.impound.fees.destroyed==1500 and LightRpGarages.impound.fees.lost==600)
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
LightRpGarages.impound.fees={ restart = 0, destroyed = 400, lost = 150, requested = 250, staff = 500 }
local C = LightRpGarages
C.defaultGarage = "citycenter" -- this test's own garage
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
    elseif sql:find("SET state = 'stored'",1,true) then
        local r=dbRows[p[2]]; if not r or r.state~="impound" then return true,0 end
        r.state,r.impound_reason,r.impound_fee,r.garage_id="stored",nil,0,p[1]
    elseif sql:find("SET garage_id = ?, properties = ? WHERE id = ?",1,true) then
        for i=1,3 do assert(p[i]~=nil,"no nil in a parameter list (the bridge refuses holes)") end
        local r=dbRows[p[3]]; r.garage_id,r.properties=p[1],p[2]
    elseif sql:find("SET properties = ? WHERE id = ?",1,true) then
        for i=1,2 do assert(p[i]~=nil,"no nil in a parameter list (the bridge refuses holes)") end
        dbRows[p[2]].properties=p[1]
    elseif sql:find("UPDATE lightrp_owned_vehicles",1,true) then
        for i=1,6 do assert(p[i]~=nil,"no nil in a parameter list (the bridge refuses holes)") end
        local r=dbRows[p[6]]; r.garage_id,r.properties,r.state,r.impound_reason,r.impound_fee=p[1],p[2],p[3],p[4]~="" and p[4] or nil,p[5]
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
local wallets={ [1]={cash=100,bank=5000}, [2]={cash=0,bank=0} }
local notices={}
LightRP.notice=function(id,n) notices[#notices+1]={id=id,body=n.body} end
LightRP.money={format=function(n) return "€$"..n end,explain=function(r) return "Denied: "..tostring(r) end,
    exchange=function(id,wallet,delta,write,commit)
        if wallets[id][wallet]+delta<0 then return false,"insufficient_funds" end
        if not Db.transaction({write}) then return false,"database_error" end
        wallets[id][wallet]=wallets[id][wallet]+delta; commit(); return true end}
Open77={players={position=function(id) return positions[id] end,getLifeState=function(id) return lives[id] and {phase=lives[id]} end},vehicles={},
    state={entity=function(_,id) local v=world[id] or {};v.bag=v.bag or {}
        return {set=function(_,k,value) v.bag[k]=value;return true end,get=function(_,k) return v.bag[k] end} end}}
local V=Open77.vehicles
V.get=function(id) return world[id] end
V.all=function(bucket) local a={};for _,v in pairs(world) do if not bucket or v.bucket==bucket then a[#a+1]=v end end;return a end
V.getPlayerSeat=function(id) return seats[id] end
V.create=function(d)
    if failCreate then return nil,"spawn_failed" end
    nextVehicle=nextVehicle+1;world[nextVehicle]={id=nextVehicle,record=d.record,position=clone(d.position),bucket=d.bucket,health=1,speed=0,occupants={},persistent=d.persistent}
    return nextVehicle
end
V.getProperties=function(id) local v=world[id];if v then return {record=v.record,health=v.health,paint=v.paint,drivable=v.drivable,engineHold=v.engineHold} end end
V.setProperties=function(id,p)
    if failApply then return false,"bad_props" end
    assert(not (p.paint and p.paint.applied==false and (p.paint.primary or p.paint.secondary)),"stock livery must not submit custom colour channels")
    lastSetProperties=p;world[id].health=p.health or 1;world[id].paint=p.paint;return true
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
-- Out of service is not part of the car (lab, 2026-11-06): a Hella parked once while its
-- tank was dry stored drivable=false and came back undrivable on every delivery.
world[id].drivable=false;world[id].engineHold=true;event("onVehicleUpdated",tostring(id))
assert(perform("store",first) and not world[id])
local parked=json.decode(dbRows[first].properties)
assert(parked.drivable==nil and parked.engineHold==nil,"runtime controls are never stored")
local legacy=json.decode(dbRows[first].properties);legacy.drivable=false;legacy.engineHold=true
dbRows[first].properties=json.encode(legacy) -- a row stored by an older build
lastSetProperties=nil;assert(perform("retrieve",first));id=nextVehicle
assert(lastSetProperties and lastSetProperties.drivable==nil and lastSetProperties.engineHold==nil,"nor restored from an older row")
assert(world[id].health==.43,"the rest of the condition still comes back")
V.remove(id);open()
local function entry(rowId) for _,v in ipairs(lastDialog.vehicles) do if v.id==rowId then return v end end end
assert(entry(first).status=="impound" and entry(first).impound.fee==LightRpGarages.impound.fees.lost,"a vehicle gone from the world is towed")
assert(notices[#notices].id==1 and notices[#notices].body:find("impound"),"the owner is told")
assert(not perform("retrieve",first),"an impounded vehicle is recovered, not retrieved")
assert(not perform("recover",first),"a fee needs a payment method")
failDb=true;assert(not perform("recover",first,1,{pay="bank"}) and wallets[1].bank==5000,"failed release never charges");failDb=false
assert(perform("recover",first,1,{pay="bank"}),"fee paid at the garage");id=nextVehicle
assert(wallets[1].bank==5000-LightRpGarages.impound.fees.lost and world[id] and dbRows[first].state=="out","released and driven out")
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
-- the release write first, then the delivery's own write switches the character
intercept=function() intercept=function() chars[1].key="slot2" end end
local before=nextVehicle
assert(perform("recover",first,1,{pay="bank"}) and nextVehicle==before,"identity rechecked after yield: released, not delivered")
chars[1].key="default";open();assert(entry(first).status=="stored")
-- Missing removal events are detected by the bounded maintenance worker.
open();assert(perform("retrieve",first));id=nextVehicle;world[id]=nil
local worker=coroutine.create(threads[#threads]);for _=1,10 do assert(coroutine.resume(worker));tick=tick+2000 end
open();assert(entry(first).status=="impound","the worker tows a lost vehicle")
wallets[1].cash=0;assert(not perform("recover",first,1,{pay="cash"}),"insufficient funds");wallets[1].cash=100
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle
-- The owner sends it to the impound from a garage: towed from wherever it is,
-- even far away and occupied, trunk and condition kept.
world[id].position={x=5000,y=0,z=0};world[id].occupants={{playerId=2}};world[id].health=.6
assert(not perform("impound",second),"a stored vehicle is collected, not towed")
assert(perform("impound",first) and not world[id] and dbRows[first].state=="impound","towed and removed from the world")
assert(entry(first).impound.fee==LightRpGarages.impound.fees.requested and Inv.count("personal:"..first,"water")==3)
assert(not perform("impound",first),"already at the impound")
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle;assert(world[id].health==.6,"condition kept through the impound")
-- Staff tow: /lightrp.impound <vehicle id>.
assert(not G.towLive(99999),"only personal vehicles");assert(G.towLive(id) and not world[id] and dbRows[first].state=="impound")
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle
-- Destroyed (owner decision 6): a wreck, whoever wrecked it, pays the insurance excess
-- (400) and comes back repaired; gone with no sign of a wreck it is "lost" (150, above).
assert(LightRpGarages.impound.fees.destroyed==400 and LightRpGarages.impound.fees.lost==150)
world[id].position={x=10,y=0,z=0};world[id].occupants={};world[id].speed=0
world[id].destroyed=true;world[id].health=0;event("onVehicleDamageChanged",tostring(id))
open();assert(entry(first).wrecked and lastDialog.impound.fees.destroyed==400,"the page knows it is a wreck")
assert(not perform("store",first),"a wreck cannot be parked")
world[id]=nil;event("onVehicleRemoved",tostring(id),"cleanup") -- cleaned up before any autosave
open();assert(entry(first).status=="impound" and entry(first).impound.fee==400 and entry(first).impound.reason:find("insurance"),"destroyed: 400")
local bankBefore=wallets[1].bank
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle
assert(wallets[1].bank==bankBefore-400 and world[id].health==1 and not world[id].destroyed,"the insurance repairs the wreck")
-- Only the flags bit says so, and the owner sends it: the excess (400), not the tow (250).
world[id].flags=4;world[id].position={x=5000,y=0,z=0}
assert(perform("impound",first) and entry(first).impound.fee==400,"the owner's tow of a wreck is the insurance excess")
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle
-- Health 0 captured by an update, then removed: still a wreck without the live record.
world[id].health=0;event("onVehicleUpdated",tostring(id));V.remove(id)
open();assert(entry(first).impound.fee==400,"captured health 0 is a wreck")
assert(perform("recover",first,1,{pay="bank"}));id=nextVehicle;assert(world[id].health==1)
-- The insurance keeps the shape of the stored damage and zeroes it.
local props={health=0,drivable=false,damage={body={.5,1,0},glass=7,lights=3,tires=15,detachedParts=2,destroyed=true,exploded=true}}
G.insuranceRepair(props)
assert(props.health==1 and props.drivable==true and #props.damage.body==3 and props.damage.body[2]==0 and props.damage.glass==0
    and props.damage.tires==0 and props.damage.detachedParts==0 and props.damage.destroyed==false and props.damage.exploded==false)
world[id].health=.6;assert(perform("impound",first) and perform("recover",first,1,{pay="bank"}));id=nextVehicle -- the condition the restart checks below expect
-- Resource restart: fresh registry/handlers, same SQL; the car left outside is
-- still in the world with its tag: removed, and towed (free).
assert(dbRows[first].state=="out" and world[id].bag.lightrpOwned==first)
handlers={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");Inv=LightRP.inventory
dofile("server/modules/garages.lua");G=LightRP.garage;G.onDatabaseReady()
assert(not world[id],"no second copy of the car in the world")
open();assert(#lastDialog.vehicles==2 and entry(first).status=="impound" and entry(second).status=="stored")
assert(entry(first).impound.fee==LightRpGarages.impound.fees.restart and dbRows[first].state=="impound","left outside at a restart: impound")
local bank=wallets[1].bank
assert(perform("recover",first),"a restart costs nothing");assert(wallets[1].bank==bank and world[nextVehicle].health==.6)
assert(Inv.count("personal:"..first,"water")==3,"trunk survives the restart and a new network ID")
-- Process reboot: the world is empty, the vehicle still marked out is towed.
world={};handlers={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");Inv=LightRP.inventory
dofile("server/modules/garages.lua");G=LightRP.garage;G.onDatabaseReady()
notices={};G.onGameplayReady(1);assert(#notices==1 and notices[1].body:find("free of charge"),"told once on joining")
G.onGameplayReady(1);assert(#notices==1,"not twice")
open();assert(entry(first).status=="impound" and perform("recover",first))
-- A wreck left outside at a restart is destroyed (400), not the free restart.
id=nextVehicle;world[id].health=0;event("onVehicleUpdated",tostring(id))
local saver=coroutine.create(threads[#threads]);for _=1,10 do assert(coroutine.resume(saver));tick=tick+2000 end
world={};handlers={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");Inv=LightRP.inventory
dofile("server/modules/garages.lua");G=LightRP.garage;G.onDatabaseReady()
open();assert(entry(first).status=="impound" and entry(first).impound.fee==400,"a wreck at the restart pays the excess")
assert(perform("recover",first,1,{pay="bank"}) and world[nextVehicle].health==1,"and comes back repaired")
print("garages_test: ownership, replay, storage, recovery, impound (restart, lost, requested, staff, fees, notices, no duplicates), trunk, identity and failure checks passed")

-- Customization starts from the recovered vehicle, out in the world.
open();assert(entry(first).status=="out","the recovered vehicle is out")

-- Customization uses the same durable garage, with previews excluded from saves.
local testWallet={cash=100000,bank=100000}
LightRP.money={format=function(n) return "€$"..n end,validAmount=function(n) return type(n)=="number" and n>0 and n%1==0 and n end,
 get=function()return testWallet end,explain=function(e)return e end,
 exchange=function(_,method,delta,write,commit)
  if testWallet[method]+delta<0 then return false,"insufficient_funds" end
  local ok=Db.transaction({write});if not ok then return false,"database_error" end
  testWallet[method]=testWallet[method]+delta;commit();return true
 end}

local function rgb(value)
    if type(value)=="table" then return clone(value) end
    return {r=tonumber(value:sub(2,3),16),g=tonumber(value:sub(4,5),16),b=tonumber(value:sub(6,7),16)}
end
local failPaint=false
V.setPaint=function(vehicle,paint)
    if failPaint then return false,"paint_refused" end
    local v=world[vehicle];if not v then return false,"vehicle_not_found" end
    v.paint={applied=true,primary=rgb(paint.primary),secondary=rgb(paint.secondary),lightsHue=v.paint and v.paint.lightsHue}
    event("onVehicleUpdated",tostring(vehicle));return true
end
V.resetPaint=function(vehicle)
    local v=world[vehicle];if not v or failPaint then return false end
    v.paint={applied=false};event("onVehicleUpdated",tostring(vehicle));return true
end
V.setLightsHue=function(vehicle,hue)
    local v=world[vehicle];if not v then return false end
    v.paint=v.paint or {applied=false};v.paint.lightsHue=hue;return true
end
V.getAppearance=function(vehicle) local v=world[vehicle];return v and (v.appearance or "") end
V.setAppearance=function(vehicle,name) local v=world[vehicle];if not v then return false,"vehicle_not_found" end;v.appearance=name;return true end
local ownedVehicle=nextVehicle
local ownedHealth=world[ownedVehicle].health -- customization never repairs
assert(not G.beginCustomization(2,first,"stolen","citycenter"),"other owner rejected")
world[ownedVehicle].occupants={{playerId=2}};assert(not G.beginCustomization(1,first,"occupied","citycenter"));world[ownedVehicle].occupants={}
world[ownedVehicle].paint.lightsHue=.55
local edit=assert(G.beginCustomization(1,first,"paint:test","citycenter"))
assert(G.isBusy(1) and edit.id==first)
assert(not G.open(1,"citycenter"),"edit locks parking and character switching")
local yellow={applied=true,primary="#FFCC00",secondary="#101820"}
local black={applied=true,primary="#000000",secondary="#000000"}
assert(G.customizePaint(1,"paint:test",yellow,false))
assert(world[ownedVehicle].paint.primary.r==255 and world[ownedVehicle].health==ownedHealth)
-- A full autosave interval while previewing must keep factory paint durable.
local editWorker=coroutine.create(threads[#threads]);for _=1,10 do assert(coroutine.resume(editWorker));tick=tick+2000 end
assert(not json.decode(dbRows[first].properties).paint.applied,"autosave never saves preview")
assert(G.endCustomization(1,"paint:test") and not world[ownedVehicle].paint.applied)
assert(not G.isBusy(1),"cleanup releases garage lock")
assert(world[ownedVehicle].paint.lightsHue==.55,"factory preview reset preserves existing light tint")
assert(G.beginCustomization(1,first,"paint:black","citycenter"))
assert(G.customizePaint(1,"paint:black",black,true,{method="bank",amount=1000}))
assert(json.decode(dbRows[first].properties).paint.applied and json.decode(dbRows[first].properties).paint.primary.r==0,"black is real saved paint")
assert(G.customizePaint(1,"paint:black",yellow,false))
assert(G.endCustomization(1,"paint:black"))
assert(world[ownedVehicle].paint.applied and world[ownedVehicle].paint.primary.r==0,"cancel restores last saved paint")
open();assert(perform("store",first));assert(perform("retrieve",first));ownedVehicle=nextVehicle
assert(world[ownedVehicle].paint.applied and world[ownedVehicle].paint.primary.r==0 and world[ownedVehicle].health==ownedHealth,"retrieve restores exact color without repairing")
assert(world[ownedVehicle].paint.lightsHue==.55,"light tint survives paint save and retrieval")
assert(G.beginCustomization(1,first,"paint:dbfail","citycenter"))
failDb=true;assert(not G.customizePaint(1,"paint:dbfail",yellow,true,{method="bank",amount=1000}));failDb=false
assert(world[ownedVehicle].paint.primary.r==0 and json.decode(dbRows[first].properties).paint.primary.r==0,"failed save rolls back preview")
failPaint=true;assert(not G.customizePaint(1,"paint:dbfail",yellow,false));assert(not G.endCustomization(1,"paint:dbfail"));failPaint=false
assert(G.isBusy(1),"failed rollback keeps lease to protect persistence")
assert(G.endCustomization(1,"paint:dbfail"))
-- Close/disconnect during SQL cannot race the save acknowledgement or free a preview.
assert(G.beginCustomization(1,first,"paint:disconnect","citycenter"))
intercept=function() assert(not G.endCustomization(1,"paint:disconnect")) end
assert(G.customizePaint(1,"paint:disconnect",yellow,true,{method="bank",amount=1000}))
assert(not G.isBusy(1) and world[ownedVehicle].paint.primary.r==255)
-- Removal during SQL still stores the newly confirmed paint for the next spawn.
assert(G.beginCustomization(1,first,"paint:removed","citycenter"))
intercept=function() V.remove(ownedVehicle) end
assert(G.customizePaint(1,"paint:removed",black,true,{method="bank",amount=1000}));G.endCustomization(1,"paint:removed")
-- A vanished vehicle goes to the impound (not back to its garage): recover it there.
open();assert(entry(first).status=="impound" and perform("recover",first,1,{pay="bank"}));ownedVehicle=nextVehicle
assert(world[ownedVehicle].paint.primary.r==0,"removal during save cannot overwrite confirmed color")
-- Restart with real persisted properties and a new runtime ID.
world={};handlers={};threads={}
dofile("server/modules/garages.lua");G=LightRP.garage;G.onDatabaseReady()
open();assert(entry(first).status=="impound" and perform("recover",first,1,{pay="bank"}),"out at the restart: impound");ownedVehicle=nextVehicle
assert(world[ownedVehicle].paint.applied and world[ownedVehicle].paint.primary.r==0,"paint survives process restart")

-- Exercise the public RPC: source-bound identity, sequencing, validation and replay.
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
RegisterNetEvent=function(name,fn) handlers[name]={fn} end
source=1
dofile("server/modules/vehicle_customization.lua")
local Custom=LightRP.vehicleCustomization
assert(Custom.open(1,first,"citycenter"))
local opened=messages[#messages].payload
local rpc=handlers["op77_lightrp:customization"][1]
local req={session=opened.session,request=1,operation="save",pay="bank",category="paint",primary="#FFCC00",secondary="#000000"}
source=2;rpc(req);assert(world[ownedVehicle].paint.primary.r==0,"forged source cannot change paint")
source=1;rpc(req);assert(messages[#messages].payload.ok and world[ownedVehicle].paint.primary.r==255)
local durable=dbRows[first].properties;rpc(req);assert(dbRows[first].properties==durable,"duplicate save is not repeated")
tick=tick+250;rpc({session=opened.session,request=2,operation="save",pay="bank",category="paint",primary="invalid",secondary="#000000"})
assert(messages[#messages].payload.ok==false and dbRows[first].properties==durable,"invalid RGB refused")
tick=tick+250;rpc({session=opened.session,request=3,operation="save",category="performance",primary="#000000",secondary="#000000"})
assert(messages[#messages].payload.ok==false,"future categories have no implicit native access")
tick=tick+250;rpc({session=opened.session,request=4,operation="preview",category="paint",primary="#000000",secondary="#000000"})
assert(world[ownedVehicle].paint.primary.r==0)
Custom.onDisconnected(1);assert(world[ownedVehicle].paint.primary.r==255 and not G.isBusy(1),"disconnect discards only unsaved preview")
assert(Custom.open(1,first,"citycenter"));positions[1].bucket=7
Custom.onLifeState(1,"dead");positions[1].bucket=0;assert(not G.isBusy(1))
print("customization: previews, autosave exclusion, black paint, parking/reboot, DB rollback, delayed cleanup, removal races and authenticated RPC passed")

assert(points["customization.auto_studio_1"] and points["customization.auto_studio_2"],"both requested workshop points registered")
local workshop=LightRpVehicleCustomization.workshops[1]
assert(not G.customizationCandidate(1,workshop.id),"remote workshop interaction refused")
positions[1]=clone(workshop.position);positions[1].bucket=0
world[ownedVehicle].position=clone(workshop.position)
Custom.onInteract(1,"customization.auto_studio_1")
assert(G.isBusy(1) and messages[#messages].payload.kind=="open","workshop opens nearest owned vehicle")
Custom.onDisconnected(1);assert(not G.isBusy(1))
positions[1]=clone(LightRpVehicleCustomization.workshops[2].position);positions[1].bucket=0
world[ownedVehicle].position=clone(positions[1])
Custom.onInteract(1,"customization.auto_studio_2");assert(G.isBusy(1));Custom.onDisconnected(1)
print("customization workshops: exact configured points, proximity and nearest-owned access passed")
