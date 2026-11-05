-- Real economy + inventory + garage + customization, with one atomic SQL boundary.
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
local function noop() end
local tick, uid, committed, attempts = 1000, 0, 0, 0
local failDb, yieldDb, yieldRead, near, alive, seat = false, false, false, true, true, nil
local owner = {identifier="dealer-test",key="default",status="active"}
local walletRow = {account_number="AAA-BBB",owner_name="Test",cash=15000,bank=100000}
local owned, messages, actions, threads, points = {}, {}, {}, {}, {}
local dialog
local function clone(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local encoded,enc={},0
json={encode=function(v)enc=enc+1;encoded[tostring(enc)]=clone(v);return tostring(enc)end,
 decode=function(v)if v=="{}"then return{}end;return clone(assert(encoded[v]))end}
LightRpGarages.garages={{id="citycenter",name="Garage",position={x=0,y=0,z=0},parking={{position={x=10,y=0,z=0}}}}}
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
    if query:find("UPDATE lightrp_owned_vehicles",1,true)then
        local row=owned[v[#v]]
        if query:find("SET properties = ?",1,true)then row.properties=v[1]else row.garage_id,row.properties=v[1],v[2]end
        if query:find("state = ?",1,true)then row.state=v[3]end
    end
    return true,1
end
function Db.transaction(q)
    if q[1].query:find("lightrp_cash_migrations",1,true) then walletRow.cash=0;return true end
    attempts=attempts+1
    assert(#q==3,"paint + wallet/inventory + ledger are one transaction")
    local write,bank,cash
    for _,w in ipairs(q)do
        if w.query:find("UPDATE lightrp_owned_vehicles",1,true)then write=w end
        if w.query:find("UPDATE lightrp_wallets",1,true)then bank=w end
        if w.query:find("lightrp_inventories",1,true)then cash=w end
    end
    assert(write and (bank or cash) and q[3].values[3]=="vehicle_paint","no separate debit or paint write")
    if yieldDb then coroutine.yield("transaction") end
    if failDb then return false,"database_error" end
    if bank then walletRow.bank=bank.values[1]end
    assert(Db.run(write.query,write.values));committed=committed+1
    return true
end

LightRP={db=Db,module=function(name,t) LightRP[name]=t;return t end,
    characters={switching={},get=function() return owner end,displayName=function() return "Test" end},
    vehicles={byKey={}},inventory={},keys={lock=function()return true end,give=function()return true end},log=noop,notice=noop,result=noop,state=noop,stateProvider=noop,eachModule=noop,command=noop,
    nowMs=function() return tick end,action=function(name,fn) actions[name]=fn end,
    nearInteraction=function(_,point) return near and point.bucket==0 end,
    interaction=function(id,p) points[id]=p end,
    dialog=function(_,kind,p) assert(kind=="garage");dialog=p end}
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end
Open77={players={getLifeState=function() return {phase=alive and "alive" or "dead"} end},vehicles={
    getProperties=noop,setProperties=noop,getPlayerSeat=function() return seat end}}
local world,vid,events,rpc={},100,{},{}
Open77.players.position=function()return{x=0,y=0,z=0,bucket=0}end
local V=Open77.vehicles
V.all=function()local out={};for _,v in pairs(world)do out[#out+1]=v end;return out end
V.get=function(id)return world[id]end
V.create=function(p)vid=vid+1;world[vid]={id=vid,record=p.record,position=p.position,bucket=p.bucket,health=.6,speed=0,occupants={},paint={applied=false}};return vid end
V.getProperties=function(id)local v=world[id];if v then return{record=v.record,health=v.health,paint=clone(v.paint)}end end
V.setProperties=function(id,p)world[id].paint=clone(p.paint);return true end
V.setEngine=function()return true end
V.isLocked=function()return false end
local function rgb(v)if type(v)=="table"then return clone(v)end;return{r=tonumber(v:sub(2,3),16),g=tonumber(v:sub(4,5),16),b=tonumber(v:sub(6,7),16)}end
V.setPaint=function(id,p)world[id].paint={applied=true,primary=rgb(p.primary),secondary=rgb(p.secondary)};return true end
V.resetPaint=function(id)world[id].paint={applied=false};return true end
V.setLightsHue=function(id,hue)world[id].paint.lightsHue=hue;return true end
V.remove=function(id)world[id]=nil;for _,fn in ipairs(events.onVehicleRemoved or{})do fn(tostring(id),"test")end;return true end
RegisterNetEvent=function(name,fn)rpc[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=function(name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua");dofile("server/modules/garages.lua")

local M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
local ok,id=G.grant(1,"hella");assert(ok);assert(G.open(1,"citycenter"))
assert(G.perform(1,{type="garage.retrieve",session=dialog.session,request=1,vehicle=id}))
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
assert(LightRpCustomizationPricing.paint==2500)
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
LightRpCustomizationPricing.paint=1000
dofile("server/modules/vehicle_customization.lua")
local C=LightRP.vehicleCustomization
assert(C.open(1,id,"citycenter"));local session=messages[#messages].session
assert(messages[#messages].price==1000 and messages[#messages].money.bank==100000)
local request=0
local function issue(operation,color,pay,extra)
 request=request+1;tick=tick+300
 local p={session=session,request=request,operation=operation,category="paint",primary=color,secondary=color,pay=pay}
 for k,v in pairs(extra or{})do p[k]=v end
 source=1;rpc["op77_lightrp:customization"](p);return messages[#messages],p
end
local before=M.get(1).bank
issue("preview","#FFCC00");assert(M.get(1).bank==before and committed==0,"previews are free")
local reply,sent=issue("save","#FFCC00","bank",{price=1,amount=1})
assert(reply.ok and M.get(1).bank==before-1000 and committed==1,"server-priced bank purchase")
assert(json.decode(owned[id].properties).paint.primary.r==255 and world[vid].health==.6)
rpc["op77_lightrp:customization"](sent);assert(M.get(1).bank==before-1000 and committed==1,"duplicate request cannot charge twice")
reply=issue("save","#FFCC00","bank");assert(not reply.ok and committed==1,"unchanged paint cannot be charged twice")
reply=issue("save","#000000","cash");assert(reply.ok and M.get(1).cash==14000 and committed==2,"real inventory cash purchase")
local saved=owned[id].properties
failDb=true;reply=issue("save","#FFCC00","bank");failDb=false
assert(not reply.ok and M.get(1).bank==before-1000 and owned[id].properties==saved and world[vid].paint.primary.r==0,"SQL failure rolls back wallet and paint")
reply=issue("save","#FFCC00","credit");assert(not reply.ok and committed==2,"payment whitelist")
M.get(1).bank=500;walletRow.bank=500
reply=issue("save","#FFCC00","bank");assert(not reply.ok and M.get(1).bank==500 and owned[id].properties==saved,"insufficient funds cannot grant permanent paint")
-- The public request holds the actual wallet and garage through an awaited SQL transaction.
yieldDb=true
local co=coroutine.create(function()issue("save","#FFCC00","cash")end)
assert(coroutine.resume(co));assert(coroutine.status(co)=="suspended" and M.get(1).busy and G.isBusy(1))
assert(not M.removeCash(1,1),"concurrent wallet debit refused")
C.onDisconnected(1);M.onDisconnected(1)
assert(coroutine.resume(co));yieldDb=false
M.onCharacterLoaded(1,owner)
assert(committed==3 and world[vid].paint.primary.r==255 and not G.isBusy(1),"disconnect during commit keeps paid finish and releases locks")
print("customization payment: real cash/bank atomicity, server quote, replay, unchanged paint, DB failure, insufficient funds and disconnect during commit passed")
