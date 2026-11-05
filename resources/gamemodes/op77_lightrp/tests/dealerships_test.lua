-- Real dealer, ownership and economy code; deterministic SQL/native boundaries.
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
do local old={maimai=4000,galena=6500,apollo=5000,hella=12000,colby=14000,quartz=19000,hozuki=24000,supron=16000,
    columbus=30000,cortes=38000,thrax=62000,bandit=52000,merrimac=46000,semimaru=100000,kusanagi=80000}
    for _,l in ipairs(LightRpDealerships.locations) do for _,s in ipairs(l.stock) do s.price=old[s.key] or s.price end end end
local function noop() end
local tick, uid, committed, attempts = 1000, 0, 0, 0
local failDb, yieldDb, yieldRead, near, alive, seat = false, false, false, true, true, nil
local owner = {identifier="dealer-test",key="default",status="active"}
local walletRow = {account_number="AAA-BBB",owner_name="Test",cash=15000,bank=100000}
local owned, messages, actions, threads, points = {}, {}, {}, {}, {}
local dialog
json = {encode=function() return "{}" end,decode=function() return {} end}
local Db = {ready=true,schema=noop,query=function() return {} end}
function Db.read(query)
    if yieldRead then coroutine.yield("uuid") end
    if failDb then return false,"database_error" end
    if query:find("SELECT account_number, owner_name",1,true) then return true,{walletRow} end
    if query:find("lightrp_inventories",1,true) or query:find("lightrp_cash_migrations",1,true) then return true,{} end
    if query:find("UUID",1,true) then uid=uid+1;return true,{{id=string.format("00000000-0000-0000-0000-%012d",uid)}} end
    local values={};for _,row in pairs(owned) do values[#values+1]=row end;return true,values
end
function Db.single(query) if query:find("SELECT account_number, owner_name",1,true) then return walletRow end end
function Db.run(query,v)
    if failDb then return false,"database_error" end
    if query:find("INSERT INTO lightrp_owned_vehicles",1,true) then
        owned[v[1]]={id=v[1],identifier=v[2],character_key=v[3],model=v[4],record=v[5],garage_id=v[6],properties=v[7],grant_key=v[8]}
    end
    return true,1
end
function Db.transaction(q)
    if q[1].query:find("lightrp_cash_migrations",1,true) then walletRow.cash=0;return true end
    attempts=attempts+1
    local bank=q[1].query:find("UPDATE lightrp_wallets",1,true)
    local ownership=bank and q[2] or q[1]
    assert(#q==3 and (bank or q[2].query:find("lightrp_inventories",1,true))
        and ownership.query:find("INSERT INTO lightrp_owned_vehicles",1,true)
        and q[3].values[3]=="vehicle_purchase","wallet + ownership + ledger must be atomic")
    if yieldDb then coroutine.yield("transaction") end
    if failDb then return false,"database_error" end
    if bank then walletRow.bank=q[1].values[1] end
    assert(Db.run(ownership.query,ownership.values));committed=committed+1
    return true
end
LightRP={db=Db,module=function(name,t) LightRP[name]=t;return t end,
    characters={switching={},get=function() return owner end,displayName=function() return "Test" end},
    vehicles={byKey={}},inventory={},keys={},log=noop,notice=noop,result=noop,state=noop,stateProvider=noop,eachModule=noop,command=noop,
    nowMs=function() return tick end,action=function(name,fn) actions[name]=fn end,
    nearInteraction=function(_,point) return near and point.bucket==0 end,
    interaction=function(id,p) points[id]=p end,
    dialog=function(_,kind,p) assert(kind=="dealership");dialog=p end}
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end
-- The world for the delivery bay: vehicles really created, keys handed over.
local world, nextVehicle, keysGiven = {}, 100, {}
Open77={players={getLifeState=function() return {phase=alive and "alive" or "dead"} end,
        position=function() return {x=0,y=0,z=0,bucket=0} end},vehicles={
    getProperties=noop,setProperties=function() return true end,getPlayerSeat=function() return seat end,setEngine=noop,
    all=function() local list={};for id,v in pairs(world) do list[#list+1]={id=id,position=v.position} end;return list end,
    create=function(def) nextVehicle=nextVehicle+1;world[nextVehicle]=def;return nextVehicle end,
    get=function(id) return world[id] end,remove=function(id) world[id]=nil;return true end}}
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=noop;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua");dofile("server/modules/garages.lua");dofile("server/modules/dealerships.lua")
LightRP.keys={lock=function() return true end,give=function(vehicleId,playerId) keysGiven[vehicleId]=playerId;return true end}
LightRP.inventory.attachPersonalTrunk=function() return true end
local function gps() for i=#messages,1,-1 do if messages[i].position and messages[i].title then return messages[i] end end end
local M,G,D=LightRP.money,LightRP.garage,LightRP.dealership
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
assert(points["garage.citycenter"] and points["dealership.ncmotors"] and not points["dealership.citycenter"], "the test dealership is gone")
assert(points["garage.citycenter"].blip.icon=="warehouse" and points["dealership.ncmotors"].blip.icon=="car-front")
assert(next(owned)==nil,"no starter vehicle")
local function open() assert(D.open(1,"ncmotors"));return dialog end
local function buy(extra)
    local p={session=dialog.session,request=dialog.nextRequest,key="maimai",pay="cash"}
    for k,v in pairs(extra or {}) do p[k]=v end
    local ok,id=D.buy(1,p)
    local message=messages[#messages];if message and message.state then dialog=message.state end
    return ok,id,p
end
open();assert(#dialog.stock==15 and dialog.garage.id=="citycenter" and dialog.delivery.name:find("Delivery bay"))
local ok,id,p=buy({price=1,total=-999,playerId=2})
assert(ok and owned[id] and owned[id].identifier==owner.identifier and M.get(1).cash==11000 and committed==1)
-- Night City Motors drives it out to the delivery bay at once, keys handed over, GPS to it.
local bay=LightRpDealerships.locations[1].delivery
local route=gps()
assert(route and not route.garage and route.position==bay.position and route.vehicle and world[route.vehicle], "driven out to the bay, GPS on it")
assert(world[route.vehicle].position==bay.position and world[route.vehicle].yaw==bay.heading and keysGiven[route.vehicle]==1)
assert(messages[#messages].text:find("Delivery bay") and messages[#messages].ok)
assert(D.buy(1,p) and committed==1,"duplicate request must not charge twice")
assert(not buy({request=999}) and committed==1,"sequence validation")
assert(not buy({key="made-up"}) and committed==1,"model whitelist")
assert(not buy({pay="credit"}) and committed==1,"payment whitelist")
assert(not buy({key="thrax"}) and M.get(1).cash==11000,"insufficient funds")
local function price(key) for _,s in ipairs(LightRpDealerships.locations[1].stock) do if s.key==key then return s.price end end end
local afterThrax=100000-price("thrax")
ok,id=buy({key="thrax",pay="bank"});assert(ok and M.get(1).bank==afterThrax and owned[id].model=="thrax")
-- A personal vehicle is already out: this one waits at the garage, and the GPS points there.
route=gps();assert(route.garage and route.position==LightRP.garage.location("citycenter").position, "stored and routed to the garage")
assert(messages[#messages].ok and messages[#messages].text:find("could not be driven out"))
local previous=LightRpDealerships.locations[1].stock[1].price
LightRpDealerships.locations[1].stock[1].price=previous+1
assert(not buy(),"changed quote refused")
LightRpDealerships.locations[1].stock[1].price=previous
near=false;assert(not buy());near=true
alive=false;assert(not buy());alive=true
seat={vehicleId=20};assert(not buy());seat=nil
owner.status="draft";assert(not D.open(1,"ncmotors"));owner.status="active"
open();tick=tick+LightRpDealerships.sessionMs+1;assert(not buy(),"expired quote");open()
failDb=true;assert(not buy() and M.get(1).cash==11000 and committed==2,"failed DB never debits");failDb=false
yieldDb=true
local co=coroutine.create(function() assert(buy()) end)
assert(coroutine.resume(co));assert(coroutine.status(co)=="suspended" and G.isBusy(1))
assert(not D.buy(1,{session=dialog.session,request=dialog.nextRequest,key="maimai",pay="cash"}),"concurrent buy refused")
assert(not M.removeCash(1,1) and not G.grant(1,"maimai"),"ownership and wallet locks held through SQL")
assert(coroutine.resume(co));yieldDb=false;assert(M.get(1).cash==7000 and committed==3)
-- After commit, failure to display a toast must not report a failed purchase.
LightRP.notice=function() error("UI disconnected") end
ok,id=buy({pay="bank"});assert(ok and owned[id] and committed==4)
LightRP.notice=noop
-- Cancel between issuing a UUID and payment: identity/visit is checked again.
yieldRead=true
co=coroutine.create(function() assert(not buy({pay="bank"})) end)
assert(coroutine.resume(co));actions["dealership.close"](1,{session=dialog.session})
yieldRead=false;assert(coroutine.resume(co));assert(committed==4 and not G.isBusy(1))
open();yieldDb=true
co=coroutine.create(function() assert(buy({pay="bank"})) end)
assert(coroutine.resume(co));D.onDisconnected(1);M.onDisconnected(1)
assert(coroutine.resume(co));yieldDb=false
M.onCharacterLoaded(1,owner);assert(committed==5 and M.get(1).bank==afterThrax-2*price("maimai"),"settled payment survives disconnect")
open();D.onLifeState(1,"dead");assert(messages[#messages].closed,"death releases UI focus through close event")
open();D.onCharacterLoaded(1);assert(messages[#messages].closed,"character swap closes old view")
local oldLimit=LightRpGarages.maxOwned;LightRpGarages.maxOwned=5
open();assert(not buy({pay="bank"}) and committed==5,"ownership cap");LightRpGarages.maxOwned=oldLimit
G.onDatabaseReady();assert(next(owned) and committed==5,"reload never purchases again")
print("PASS: dealership + real economy/garage; delivery bay (keys, GPS) and garage fallback; server pricing, atomic payment, replay, concurrency, errors, disconnect, lifecycle and no starter cars")
