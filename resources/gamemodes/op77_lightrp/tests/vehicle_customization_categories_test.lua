-- Auto Studio categories beyond paint: lights (headlight hue) and factory trim
-- (appearance variant), plus the per-model support table. Real economy + inventory +
-- garage + customization modules; deterministic SQL and native boundaries.
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
local function noop() end
local tick, uid = 1000, 0
local failDb, failLights, yieldDb = false, false, false
local owner = {identifier="studio-test",key="default",status="active"}
local walletRow = {account_number="AAA-CCC",owner_name="Test",cash=20000,bank=100000}
local owned, messages, actions, threads, points = {}, {}, {}, {}, {}
local commits = {} -- ledger kinds of committed purchases
local dialog
local function clone(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local encoded,enc={},0
json={encode=function(v)enc=enc+1;encoded[tostring(enc)]=clone(v);return tostring(enc)end,
 decode=function(v)if v=="{}"then return{}end;return clone(assert(encoded[v]))end}
LightRpGarages.defaultGarage="citycenter"
LightRpGarages.garages={{id="citycenter",name="Garage",position={x=0,y=0,z=0},parking={{position={x=10,y=0,z=0}}}}}
local Db = {ready=true,schema=noop,query=function() return {} end}
function Db.read(query)
    if failDb then return false,"database_error" end
    if query:find("SELECT account_number, owner_name",1,true) then return true,{walletRow} end
    if query:find("lightrp_inventories",1,true) or query:find("lightrp_cash_migrations",1,true) then return true,{} end
    if query:find("UUID",1,true) then uid=uid+1;return true,{{id=string.format("00000000-0000-0000-0000-%012d",uid)}} end
    local values={};for _,row in pairs(owned) do values[#values+1]=clone(row) end;return true,values
end
function Db.single(query) if query:find("SELECT account_number, owner_name",1,true) then return walletRow end end
function Db.run(query,v)
    if failDb then return false,"database_error" end
    if query:find("INSERT INTO lightrp_owned_vehicles",1,true) then
        owned[v[1]]={id=v[1],identifier=v[2],character_key=v[3],model=v[4],record=v[5],garage_id=v[6],properties=v[7],grant_key=v[8],state="stored"}
    elseif query:find("UPDATE lightrp_owned_vehicles",1,true)then
        local row=owned[v[#v]]
        if query:find("SET properties = ?",1,true)then row.properties=v[1]else row.garage_id,row.properties=v[1],v[2]end
        if query:find("state = ?",1,true)then row.state=v[3]end
    end
    return true,1
end
function Db.transaction(q)
    if q[1].query:find("lightrp_cash_migrations",1,true) then walletRow.cash=0;return true end
    local write,bank,kind
    for _,w in ipairs(q)do
        if w.query:find("UPDATE lightrp_owned_vehicles",1,true)then write=w end
        if w.query:find("UPDATE lightrp_wallets",1,true)then bank=w end
        if w.query:find("INSERT INTO lightrp_transactions",1,true)then kind=w.values[3] end
    end
    assert(write and kind,"vehicle properties and the receipt are one transaction")
    if yieldDb then coroutine.yield("transaction") end
    if failDb then return false,"database_error" end
    if bank then walletRow.bank=bank.values[1]end
    assert(Db.run(write.query,write.values));commits[#commits+1]=kind
    return true
end
LightRP={db=Db,module=function(name,t) LightRP[name]=t;return t end,
    characters={switching={},get=function() return owner end,displayName=function() return "Test" end},
    vehicles={byKey={}},inventory={},keys={lock=function()return true end,give=function()return true end},log=noop,notice=noop,result=noop,state=noop,stateProvider=noop,eachModule=noop,command=noop,
    nowMs=function() return tick end,action=function(name,fn) actions[name]=fn end,
    nearInteraction=function(_,point) return point.bucket==0 end,
    interaction=function(id,p) points[id]=p end,
    dialog=function(_,kind,p) assert(kind=="garage");dialog=p end}
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end
Open77={players={getLifeState=function() return {phase="alive"} end,position=function()return{x=0,y=0,z=0,bucket=0}end},vehicles={
    getPlayerSeat=function() return nil end}}

-- The canonical (replicated) vehicle state. A write here is what every viewer receives.
local world,vid,events,rpc={},100,{},{}
local calls={setAppearance=0,setHeadlightColor=0,setPaint=0}
local function rgb(v)if type(v)=="table"then return clone(v)end;return{r=tonumber(v:sub(2,3),16),g=tonumber(v:sub(4,5),16),b=tonumber(v:sub(6,7),16)}end
local function hueOf(hex) -- standard HSV hue, 0..1
    local c=rgb(hex);local r,g,b=c.r/255,c.g/255,c.b/255
    local high,low=math.max(r,g,b),math.min(r,g,b);local d=high-low
    if d==0 then return 0 end
    local h=high==r and ((g-b)/d)%6 or high==g and (b-r)/d+2 or (r-g)/d+4
    return h/6
end
local V=Open77.vehicles
V.all=function()local out={};for _,v in pairs(world)do out[#out+1]=v end;return out end
V.get=function(id)return world[id]end
V.create=function(p)vid=vid+1;world[vid]={id=vid,record=p.record,position=p.position,bucket=p.bucket,health=.8,speed=0,occupants={},
    paint={applied=false},appearance=p.appearance or ""};return vid end
V.getProperties=function(id)local v=world[id];if v then return{version=1,record=v.record,health=v.health,paint=clone(v.paint),appearance=v.appearance}end end
V.setProperties=function(id,p)local v=world[id];v.paint=clone(p.paint);v.health=p.health or v.health
    -- a change of variant needs world.vehicles.appearance; a restatement never does
    if (p.appearance or "")~=(v.appearance or "") then assert(V.appearanceGranted,"permission_denied:world.vehicles.appearance");v.appearance=p.appearance or "" end
    return true end
V.setEngine=function()return true end
V.isLocked=function()return false end
V.setPaint=function(id,p)calls.setPaint=calls.setPaint+1;local v=world[id];if not v then return false,"vehicle_not_found" end
    v.paint={applied=true,primary=rgb(p.primary),secondary=rgb(p.secondary),lightsHue=v.paint.lightsHue};return true end
-- resetPaint resets the whole template, lights hue included (vehicle-paint guide)
V.resetPaint=function(id)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint={applied=false};return true end
V.setLightsHue=function(id,hue)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint.lightsHue=hue;return true end
V.setHeadlightColor=function(id,color)calls.setHeadlightColor=calls.setHeadlightColor+1
    if failLights then return false,"vehicles_unavailable" end
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if color==nil then v.paint.lightsHue=nil;return true end
    v.paint.lightsHue=hueOf(color);return true end
V.clearLightsHue=function(id)return V.setLightsHue(id,nil)end
V.getLightsHue=function(id)local v=world[id];return v and v.paint.lightsHue end
V.getAppearance=function(id)local v=world[id];return v and (v.appearance or "") end
V.setAppearance=function(id,name)calls.setAppearance=calls.setAppearance+1;local v=world[id];if not v then return false,"vehicle_not_found" end
    assert(V.appearanceGranted,"permission_denied:world.vehicles.appearance");v.appearance=name or "";return true end
V.remove=function(id)world[id]=nil;for _,fn in ipairs(events.onVehicleRemoved or{})do fn(tostring(id),"test")end;return true end
RegisterNetEvent=function(name,fn)rpc[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=function(name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end

-- The manifest grants the trim native its extra permission (README: permissions).
local manifest=assert(io.open("open77.lua","rb")):read("a")
V.appearanceGranted=manifest:find('"world.vehicles.appearance"',1,true)~=nil
assert(V.appearanceGranted,"open77.lua declares world.vehicles.appearance for Auto Studio trims")

dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
local before=#threads;dofile("server/modules/garages.lua");local garageWorker=threads[before+1]
local M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
local P=LightRpCustomizationPricing
-- pinned: provisional lights/trim tariffs (owner to confirm) and the 2026-11-05 paint price
assert(P.paint==2500 and P.lights==500 and P.trim==2500)
local C=LightRpVehicleCustomization
-- shipped tables = the lead's 2026-11-05 measurements: every trim belongs to a catalogue
-- model, its id is an appearance of that model's own entity (prefix of the stock
-- appearance), ids are unique per model, and only Bandit and Apollo refuse a lights hue
local stockPrefix={hella="archer_hella__basic_",quartz="archer_quartz__basic_",cortes="villefort_cortes__basic_",
  colby="thorton_colby__basic_",galena="thorton_galena__basic_",maimai="makigai_maimai__basic_",
  hozuki="mizutani_hozuki__basic_",supron="mahir_supron__basic_",columbus="villefort_columbus__basic_",
  kusanagi="yaiba_kusanagi_basic_",apollo="brennan_apollo_basic_"}
local shippedTrims=0
for model,list in pairs(C.trims) do
  assert(LightRP.vehicles.byKey[model],"trim model is a catalogue key: "..model)
  assert(stockPrefix[model],"trim model has a measured appearance prefix: "..model)
  local seen={}
  for _,t in ipairs(list) do
    assert(t.id:sub(1,#stockPrefix[model])==stockPrefix[model],"trim id belongs to "..model..": "..t.id)
    assert(not t.id:find("burnt",1,true) and not seen[t.id] and type(t.label)=="string" and t.label~="")
    seen[t.id]=true;shippedTrims=shippedTrims+1
  end
end
assert(shippedTrims==33,"33 measured trims ship")
for model,s in pairs(C.support) do assert(LightRP.vehicles.byKey[model] and s.lights==false and s.paint==nil,model) end
assert(C.support.bandit and C.support.apollo,"Bandit and Apollo refuse lights")
local measured=0;for _ in pairs(C.support) do measured=measured+1 end
assert(measured==2,"only Bandit and Apollo carry a support override")
C.trims={hella={{id="hella_trim_a",label="Street"},{id="hella_trim_b",label="Sport"}},galena={}}
C.support={kusanagi={paint=false},quartz={lights=false}}
dofile("server/modules/vehicle_customization.lua")
local Custom=LightRP.vehicleCustomization
local NET="op77_lightrp:customization"

local function retrieve(rowId)
    assert(G.open(1,"citycenter"))
    local ok,why=G.perform(1,{type="garage.retrieve",session=dialog.session,request=dialog.nextRequest,vehicle=rowId})
    assert(ok,why);return vid
end
local function store(rowId)
    assert(G.open(1,"citycenter"))
    local ok,why=G.perform(1,{type="garage.store",session=dialog.session,request=dialog.nextRequest,vehicle=rowId})
    assert(ok,why)
end
local session,request
local function open(rowId)
    assert(Custom.open(1,rowId,"citycenter"));local raw=messages[#messages];session,request=raw.session,0
    assert(type(raw.categoriesJson)=="string" and raw.categories==nil,"the category tree travels as JSON text")
    local m={};for k,v in pairs(raw)do m[k]=v end;m.categories=json.decode(raw.categoriesJson);return m
end
local function issue(operation,fields,pay)
    request=request+1;tick=tick+300
    local p={session=session,request=request,operation=operation,pay=pay}
    for k,v in pairs(fields)do p[k]=v end
    source=1;rpc[NET](p);return messages[#messages],p
end
local function close() source=1;rpc[NET]({session=session,operation="close"}) end
local function saved(rowId) return json.decode(owned[rowId].properties) end
local function near(a,b) return a~=nil and b~=nil and math.abs(a-b)<1e-6 end
local function category(m,id) for _,c in ipairs(m.categories)do if c.id==id then return c end end end
local cyan,red,amber=hueOf("#00D8FF"),hueOf("#FF0000"),hueOf("#FFB000")

-- Hella: paint, lights and trim offered, each with its own server quote.
local ok,hella=G.grant(1,"hella");assert(ok)
local car=retrieve(hella)
world[car].paint.lightsHue=amber -- an existing tint (e.g. restored from older properties)
local m=open(hella)
assert(category(m,"paint").available and category(m,"lights").available and category(m,"trim").available)
assert(#category(m,"trim").options==2 and category(m,"trim").options[1].id=="hella_trim_a")
assert(m.prices.lights==500 and m.prices.trim==2500 and m.price==2500 and category(m,"lights").price==500)
assert(near(m.vehicle.lightsHue,amber) and m.vehicle.appearance=="" and m.vehicle.model=="hella")

-- 1. Lights preview: free, on the canonical (replicated) car, never persisted.
local bank=M.get(1).bank
local reply=issue("preview",{category="lights",color="#00D8FF"})
assert(reply.ok and near(world[car].paint.lightsHue,cyan) and M.get(1).bank==bank and #commits==0,"free lights preview on the replicated car")
assert(near(reply.confirmed.lightsHue,amber),"the page keeps the confirmed tint apart from the preview")
reply=issue("preview",{category="lights",color="#FF0000"});tick=tick-250
reply=issue("preview",{category="lights",color="#00D8FF"})
assert(not reply.ok and near(world[car].paint.lightsHue,red),"preview rate limit applies to lights")
local saver=coroutine.create(garageWorker)
for _=1,9 do assert(coroutine.resume(saver));tick=tick+2000 end
assert(near(saved(hella).paint.lightsHue,amber),"autosave keeps the confirmed tint, never the lights preview")
reply=issue("preview",{category="lights",color="#808080"})
assert(not reply.ok and reply.text:find("hue") and near(world[car].paint.lightsHue,red),"a grey has no hue: refused before any native")
close();assert(near(world[car].paint.lightsHue,amber) and not G.isBusy(1),"close restores the confirmed tint")
assert(near(saved(hella).paint.lightsHue,amber))

-- 2. Mixed session: previewing lights, then buying paint, persists the paint only.
open(hella)
issue("preview",{category="lights",color="#FF0000"})
reply=issue("save",{category="paint",primary="#FFCC00",secondary="#101820"},"bank")
assert(reply.ok and M.get(1).bank==bank-2500 and commits[#commits]=="vehicle_paint")
assert(saved(hella).paint.primary.r==255 and near(saved(hella).paint.lightsHue,amber),"a paint purchase never persists the lights preview")
assert(near(world[car].paint.lightsHue,red) and world[car].paint.primary.r==255,"the lights preview stays on screen until the studio closes")
for _=1,9 do assert(coroutine.resume(saver));tick=tick+2000 end
assert(near(saved(hella).paint.lightsHue,amber) and saved(hella).paint.primary.r==255)
close();assert(near(world[car].paint.lightsHue,amber) and world[car].paint.primary.r==255,"close keeps bought paint, drops the lights preview")
bank=M.get(1).bank

-- 3. Buying lights: server quote, ledger kind, replay, hue-only equality, DB failure.
open(hella)
reply=issue("preview",{category="lights",color="#00D8FF"})
local sent;reply,sent=issue("save",{category="lights",color="#00D8FF",price=1,amount=1},"bank")
assert(reply.ok and M.get(1).bank==bank-500 and commits[#commits]=="vehicle_lights","server-priced lights purchase")
assert(near(saved(hella).paint.lightsHue,cyan) and saved(hella).paint.primary.r==255,"lights saved, paint untouched")
assert(near(reply.confirmed.lightsHue,cyan) and reply.text:find("Light tint"))
local count=#commits;rpc[NET](sent);assert(#commits==count and M.get(1).bank==bank-500,"a replayed save is not charged twice")
reply=issue("save",{category="lights",color="#004855"},"bank") -- a third of the brightness, the same hue
assert(not reply.ok and #commits==count and M.get(1).bank==bank-500,"the engine keeps only the hue: the same hue is not sold twice")
assert(near(world[car].paint.lightsHue,cyan))
failDb=true;reply=issue("save",{category="lights",color="#FF0000"},"bank");failDb=false
assert(not reply.ok and M.get(1).bank==bank-500 and near(world[car].paint.lightsHue,cyan) and near(saved(hella).paint.lightsHue,cyan),"SQL failure rolls back money and tint")
failLights=true;reply=issue("preview",{category="lights",color="#FF0000"});failLights=false
assert(not reply.ok and near(world[car].paint.lightsHue,cyan),"a refused native leaves the confirmed tint")
reply=issue("save",{category="lights",stock=true},"cash")
assert(reply.ok and world[car].paint.lightsHue==nil and saved(hella).paint.lightsHue==nil and M.get(1).cash==20000-500 and commits[#commits]=="vehicle_lights","factory lights is a lights job")
reply=issue("save",{category="lights",stock=true},"bank");assert(not reply.ok and M.get(1).bank==bank-500,"factory lights twice is refused")
close();assert(world[car].paint.lightsHue==nil and world[car].paint.primary.r==255)
bank=M.get(1).bank

-- 4. Trim: only ids curated for this model, the applied name comes from the table.
open(hella)
local appearanceCalls=calls.setAppearance
for _,forged in ipairs({"hella_trim_c","Vehicle.v_sport1_quadra_turbo_r_player","kusanagi_trim",""}) do
    reply=issue("preview",{category="trim",trim=forged})
    assert(not reply.ok and world[car].appearance=="","trim outside the model's table refused: "..forged)
end
reply=issue("save",{category="trim",trim={id="hella_trim_a"}},"bank");assert(not reply.ok)
assert(calls.setAppearance==appearanceCalls and M.get(1).bank==bank,"no client-chosen name reaches setAppearance")
reply=issue("preview",{category="trim",trim="hella_trim_a"})
assert(reply.ok and world[car].appearance=="hella_trim_a" and M.get(1).bank==bank,"free trim preview on the replicated car")
for _=1,9 do assert(coroutine.resume(saver));tick=tick+2000 end
assert((saved(hella).appearance or "")=="","autosave keeps the confirmed trim")
reply=issue("save",{category="trim",trim="hella_trim_b"},"bank")
assert(reply.ok and world[car].appearance=="hella_trim_b" and saved(hella).appearance=="hella_trim_b" and M.get(1).bank==bank-2500 and commits[#commits]=="vehicle_trim")
assert(reply.confirmed.appearance=="hella_trim_b")
reply=issue("save",{category="trim",trim="hella_trim_b"},"bank");assert(not reply.ok and M.get(1).bank==bank-2500,"unchanged trim refused")
-- Mixed: a trim preview, then a lights purchase: only the tint is persisted.
issue("preview",{category="trim",trim="hella_trim_a"})
reply=issue("save",{category="lights",color="#FF0000"},"bank")
assert(reply.ok and near(saved(hella).paint.lightsHue,red) and saved(hella).appearance=="hella_trim_b","a lights purchase never persists the trim preview")
appearanceCalls=calls.setAppearance
close()
assert(world[car].appearance=="hella_trim_b" and near(world[car].paint.lightsHue,red) and world[car].paint.primary.r==255,"close restores the confirmed trim")
assert(calls.setAppearance==appearanceCalls+1,"one appearance change to restore it")
open(hella);issue("preview",{category="lights",color="#00D8FF"});appearanceCalls=calls.setAppearance;close()
assert(calls.setAppearance==appearanceCalls,"restoring paint/lights never restates the appearance")
-- Disconnect during a trim preview restores it too.
open(hella);issue("preview",{category="trim",trim="hella_trim_a"});Custom.onDisconnected(1)
assert(world[car].appearance=="hella_trim_b" and not G.isBusy(1))
bank=M.get(1).bank

-- 5. Park, restart, retrieve: the bought look comes back exactly.
store(hella);assert(not world[car])
local stored=saved(hella)
assert(stored.appearance=="hella_trim_b" and near(stored.paint.lightsHue,red) and stored.paint.primary.r==255)
world={};events={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua");dofile("server/modules/garages.lua")
M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("server/modules/vehicle_customization.lua");Custom=LightRP.vehicleCustomization
car=retrieve(hella)
assert(world[car].appearance=="hella_trim_b" and near(world[car].paint.lightsHue,red) and world[car].paint.primary.r==255 and world[car].paint.applied,
    "trim, tint and paint survive park + restart + retrieve")
m=open(hella);assert(m.vehicle.appearance=="hella_trim_b" and near(m.vehicle.lightsHue,red));close()
-- Disconnect while a lights purchase is in SQL: the paid tint stays, the locks are released.
open(hella);bank=M.get(1).bank;count=#commits
yieldDb=true
local pending=coroutine.create(function() issue("save",{category="lights",color="#00D8FF"},"bank") end)
assert(coroutine.resume(pending));assert(coroutine.status(pending)=="suspended" and G.isBusy(1))
Custom.onDisconnected(1);M.onDisconnected(1)
assert(coroutine.resume(pending));yieldDb=false
M.onCharacterLoaded(1,owner)
assert(#commits==count+1 and near(world[car].paint.lightsHue,cyan) and near(saved(hella).paint.lightsHue,cyan) and not G.isBusy(1),
    "disconnect during a lights commit keeps the paid tint and releases the lease")
assert(M.get(1).bank==bank-500)

-- 6. Models without entries: unknown/absent models keep paint and lights; trim hidden.
store(hella)
local _,galena=G.grant(1,"galena");car=retrieve(galena)
m=open(galena)
assert(category(m,"paint").available and category(m,"lights").available and not category(m,"trim"),"no curated trims: no trim category")
appearanceCalls=calls.setAppearance
reply=issue("preview",{category="trim",trim="hella_trim_a"});assert(not reply.ok and calls.setAppearance==appearanceCalls,"another model's trim is refused")
reply=issue("preview",{category="lights",color="#00D8FF"});assert(reply.ok and near(world[car].paint.lightsHue,cyan))
reply=issue("preview",{category="paint",primary="#FFCC00",secondary="#FFCC00"});assert(reply.ok and world[car].paint.primary.r==255)
assert(near(world[car].paint.lightsHue,cyan),"a paint preview keeps the lights preview on screen")
close();assert(world[car].paint.lightsHue==nil and not world[car].paint.applied)
store(galena)
-- A model the support table marks unsupported: greyed with a reason, refused by the server.
local _,kusanagi=G.grant(1,"kusanagi");car=retrieve(kusanagi)
m=open(kusanagi);bank=M.get(1).bank
local paintCategory=category(m,"paint")
assert(paintCategory and paintCategory.available==false and paintCategory.reason==C.unsupported.paint and category(m,"lights").available)
local paintCalls=calls.setPaint
reply=issue("save",{category="paint",primary="#FFCC00",secondary="#FFCC00"},"bank")
assert(not reply.ok and reply.text==C.unsupported.paint and calls.setPaint==paintCalls and M.get(1).bank==bank,"unsupported paint refused, nothing charged")
reply=issue("save",{category="lights",color="#00D8FF"},"bank");assert(reply.ok and M.get(1).bank==bank-500,"lights still sold on that model")
close();store(kusanagi)
local _,quartz=G.grant(1,"quartz");car=retrieve(quartz)
m=open(quartz);assert(category(m,"lights").available==false and category(m,"paint").available)
local lightCalls=calls.setHeadlightColor
reply=issue("preview",{category="lights",color="#00D8FF"});assert(not reply.ok and calls.setHeadlightColor==lightCalls)
close();store(quartz)
-- A row whose model left the catalogue still opens with paint and lights (no regression).
owned[galena].model="retired_model"
world={};events={};threads={};LightRP.inventory=nil
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua");dofile("server/modules/garages.lua")
M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("server/modules/vehicle_customization.lua");Custom=LightRP.vehicleCustomization
car=retrieve(galena);m=open(galena)
local sold={};for _,c in ipairs(m.categories)do if c.available then sold[#sold+1]=c.id end end
-- plate needs no native; every other phase-2 category is greyed with its reason on this build (no visual natives)
assert(table.concat(sold,",")=="paint,lights,plate" and not category(m,"trim"),"unknown model: paint, lights and plate, no trim")
for _,c in ipairs(m.categories)do assert(c.available or (type(c.reason)=="string" and c.reason~=""),"greyed with a reason: "..c.id)end
reply=issue("preview",{category="lights",stock=true});assert(reply.ok)
close()
print("customization categories: lights preview/autosave/close/save/replay/hue equality/DB failure, trim allowlist and restore, mixed-category masks, park+restart+retrieve, support table and unknown models passed")
