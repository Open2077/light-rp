-- Performance stages and engine sounds beyond the 15 dealer models: the generated per-record
-- catalogue (server/config/vehicle_stage_catalogue.lua, Open77 scripts/vehicle-kit/stages/
-- make_stages.py) prices the stages of every vanilla player car and bike the stage pack stages,
-- so the Auto Studio stops greying Performance on them; the engine sounds come from the server
-- (listEngineSounds), which knows them once the stage pack registers every staged record.
-- Two non-dealer models on the real economy + garage + customization modules: the staff
-- Quadra Type-66 (catalogue key type66) and a Yaiba Kusanagi trim (Vehicle..._player_02,
-- a test-only catalogue entry), plus the Hella (curated prices win) and an unstaged model.
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
local function noop() end
local tick, uid = 1000, 0
local owner = {identifier="stage-catalogue-test",key="default",status="active"}
local walletRow = {account_number="AAA-SC",owner_name="Test",cash=50000,bank=1000000}
local owned, messages, actions, threads, points, commits, logs = {}, {}, {}, {}, {}, {}, {}
local dialog
local function clone(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local encoded,enc={},0
json={encode=function(v)enc=enc+1;encoded[tostring(enc)]=clone(v);return tostring(enc)end,
 decode=function(v)if v=="{}"then return{}end;return clone(assert(encoded[v]))end}
LightRpGarages.defaultGarage="citycenter"
LightRpGarages.garages={{id="citycenter",name="Garage",position={x=0,y=0,z=0},parking={{position={x=10,y=0,z=0}}}}}
local Db = {ready=true,schema=noop,query=function() return {} end}
function Db.read(query)
    if query:find("SELECT account_number, owner_name",1,true) then return true,{walletRow} end
    if query:find("lightrp_inventories",1,true) or query:find("lightrp_cash_migrations",1,true) then return true,{} end
    if query:find("UUID",1,true) then uid=uid+1;return true,{{id=string.format("00000000-0000-0000-0000-%012d",uid)}} end
    local values={};for _,row in pairs(owned) do values[#values+1]=clone(row) end;return true,values
end
function Db.single(query) if query:find("SELECT account_number, owner_name",1,true) then return walletRow end end
function Db.run(query,v)
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
    if bank then walletRow.bank=bank.values[1]end
    assert(Db.run(write.query,write.values));commits[#commits+1]=kind
    return true
end
LightRP={db=Db,module=function(name,t) LightRP[name]=t;return t end,
    characters={switching={},get=function() return owner end,displayName=function() return "Test" end},
    vehicles={byKey={}},inventory={},keys={lock=function()return true end,give=function()return true end},notice=noop,result=noop,state=noop,stateProvider=noop,eachModule=noop,command=noop,
    log=function(f,...) local ok,s=pcall(string.format,f,...);logs[#logs+1]=ok and s or tostring(f) end,
    nowMs=function() return tick end,action=function(name,fn) actions[name]=fn end,
    nearInteraction=function(_,point) return point.bucket==0 end,
    interaction=function(id,p) points[id]=p end,
    dialog=function(_,kind,p) assert(kind=="garage");dialog=p end}

-- The models under test. The Kusanagi trim and the unstaged model are test-only catalogue entries.
local HELLA="Vehicle.v_standard2_archer_hella_player"
local TYPE66="Vehicle.v_sport2_quadra_type66_player"
local KUSANAGI02="Vehicle.v_sportbike1_yaiba_kusanagi_player_02"
local UNSTAGED="Vehicle.v_standard2_archer_hella_police"
table.insert(LightRpConfig.vehicles.catalog,{key="kusanagi02",label="Yaiba Kusanagi (trim)",category="Bikes",record=KUSANAGI02})
table.insert(LightRpConfig.vehicles.catalog,{key="unstaged",label="Not staged",category="Sport",record=UNSTAGED})
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end

-- The manifest loads the generated catalogue before the studio module.
local manifest=assert(io.open("open77.lua","rb")):read("a")
local pricingAt=manifest:find('server/config/vehicle_customization.lua',1,true)
local catalogueAt=manifest:find('server/config/vehicle_stage_catalogue.lua',1,true)
local studioAt=manifest:find('server/modules/vehicle_customization.lua',1,true)
assert(pricingAt and catalogueAt and studioAt and pricingAt<catalogueAt and catalogueAt<studioAt,"the stage catalogue loads before the studio")
local catalogueText=assert(io.open("server/config/vehicle_stage_catalogue.lua","rb")):read("a")
assert(catalogueText:sub(1,3)~="\239\187\191","a Lua file without BOM")
dofile("server/config/vehicle_stage_catalogue.lua")
local SC=assert(LightRpVehicleStageCatalogue,"the generated stage catalogue")
local STAGED=SC.models

-- Names: a trim or variant suffix survives every stage and sound suffix (baseRecord).
for _,record in ipairs({KUSANAGI02,"Vehicle.v_sport2_quadra_type66_nomad_player_03","Vehicle.v_sport2_mizutani_shion_nomad_player_missiles",
    "Vehicle.v_standard3_makigai_tanishi_player_mr_hands","Vehicle.q000_hym_player_car"}) do
    -- quest variants (Vehicle.q<digits>_*) are out of the pack (owner, 2026-11-07); their names still parse
    assert(STAGED[record] or record:match("^Vehicle%.q%d+_"),"staged: "..record)
    assert(not (STAGED[record] and record:match("^Vehicle%.q%d+_")),"a quest variant is not staged: "..record)
    assert(LightRpConfig.baseRecord(record)==record,"a base record is its own base: "..record)
    for _,suffix in ipairs({"_o77s1","_o77s3","_o77a1","_o77a13","_o77s2a3","_o77s3a16"})do
        assert(LightRpConfig.baseRecord(record..suffix)==record,"baseRecord("..record..suffix..")")
    end
end

-- Natives -------------------------------------------------------------------------------
local world,vid,events,rpc,bags={},100,{},{},{}
local calls={respawnAs=0,soundRespawns=0,setEngineSound=0,listEngineSounds=0}
local packs={lightrp_vehicle_stages="running"}
GetResourceState=function(name) return packs[name] or "missing" end
GetCurrentResourceName=function() return "op77_lightrp" end
-- The sounds the stage pack registers: SC.sounds.car car sounds, then SC.sounds.bike bike sounds.
local SOUNDS={}
for k=1,SC.sounds.car+SC.sounds.bike do
    SOUNDS[k]={id=("s%02d"):format(k),label="Sound "..k,class=k<=SC.sounds.car and "car" or "bike",k=k}
end
local function plain(record) return (tostring(record):gsub("(_o77s%d+)a%d+$","%1"):gsub("_o77a%d+$","")) end
local function base(record) return LightRpConfig.baseRecord(record) end
local function soundOf(record)
    local k=tostring(record):match("_o77s%d+a(%d+)$") or tostring(record):match("_o77a(%d+)$")
    for _,s in ipairs(SOUNDS)do if s.k==tonumber(k) then return s.id end end
end
local function soundK(id) for _,s in ipairs(SOUNDS)do if s.id==id then return s.k end end end
local function withSound(record,id)
    local r=plain(record);if id==nil then return r end
    return r:match("_o77s%d+$") and r.."a"..soundK(id) or r.."_o77a"..soundK(id)
end
-- A record exists when TweakXL created it: a catalogued base, or a stage/sound record of a staged base.
local function known(record)
    local b,catalogued=base(record),false
    for _,v in ipairs(LightRpConfig.vehicles.catalog)do if v.record==b then catalogued=true end end
    if record==b then return catalogued end
    return catalogued and STAGED[b]~=nil and plain(record):match("_o77s[1-3]$")~=nil or (STAGED[b]~=nil and plain(record)==b)
end
-- The server's engine-sound catalogue (VehicleEngineSoundCatalogue.For): the sounds of the
-- record's class that cover its base record, i.e. every staged record.
local function soundsFor(record)
    local entry=STAGED[base(record)];if not entry then return {} end
    local out={};for _,s in ipairs(SOUNDS)do if s.class==entry.class then out[#out+1]={id=s.id,label=s.label,class=s.class} end end
    return out
end
Open77={players={getLifeState=function() return {phase="alive"} end,position=function()return{x=0,y=0,z=0,bucket=0}end},
    vehicles={getPlayerSeat=function() return nil end},
    state={entity=function(_,id) return {set=function(_,k,v) bags[id]=bags[id] or {};bags[id][k]=v end,get=function(_,k) return (bags[id] or {})[k] end} end},
    -- The stage resource (lightrp_vehicle_stages, stageRecord export): every staged record, the sound kept.
    exports={callSync=function(resource,method,record,stage)
        if packs[resource]~="running" then error("resource_not_running:"..resource) end
        assert(resource=="lightrp_vehicle_stages" and method=="stageRecord")
        local b=base(record);if not STAGED[b] then return nil,"unknown_record" end
        if stage==0 then return b end;return b.."_o77s"..stage end}}
local V=Open77.vehicles
V.all=function()local out={};for _,v in pairs(world)do out[#out+1]=v end;return out end
V.get=function(id)return world[id]end
V.create=function(p)
    if not known(p.record) then return nil,"invalid_record" end
    vid=vid+1;world[vid]={id=vid,record=p.record,position=p.position,bucket=p.bucket,health=.8,speed=0,occupants={},
    paint={applied=false},appearance=p.appearance or "",visual={parts={},rev=0}};return vid end
V.getProperties=function(id)
    local v=world[id];if not v then return nil end
    return {version=1,record=v.record,health=v.health,paint=clone(v.paint),appearance=v.appearance,visual=clone(v.visual),engineSound=soundOf(v.record)}
end
local PROPS={version=1,record=1,health=1,paint=1,appearance=1,visual=1,engineSound=1}
V.setProperties=function(id,p)
    for k in pairs(p)do if not PROPS[k] then return false,"unsupported_property:"..k end end
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if p.record~=nil and p.record~=v.record then return false,"record_mismatch" end
    if p.record~=nil and p.engineSound~=nil and soundOf(p.record)~=p.engineSound then return false,"engine_sound_mismatch" end
    if p.paint then v.paint=clone(p.paint) end;v.health=p.health or v.health
    if p.visual~=nil then v.visual={parts={},rev=(v.visual.rev or 0)+1} end
    if p.engineSound~=nil or p.record==nil then
        local record=withSound(v.record,p.engineSound)
        if record~=v.record then calls.soundRespawns=calls.soundRespawns+1;v.record=record end
    end
    return true end
V.setEngine=function()return true end
V.setEngineHold=function(id,on)local v=world[id];if not v then return false,"vehicle_not_found" end;v.engineHold=on==true;return true end
V.setLights=function()return true end
V.isLocked=function()return false end
-- Phase 1 natives the garage restores on close (paint, lights, trim): no change in this file.
V.setPaint=function(id,p)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint={applied=true,primary=p.primary,secondary=p.secondary};return true end
V.resetPaint=function(id)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint={applied=false};return true end
V.setLightsHue=function(id,hue)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint.lightsHue=hue;return true end
V.clearLightsHue=function(id)return V.setLightsHue(id,nil)end
V.getLightsHue=function(id)local v=world[id];return v and v.paint.lightsHue end
V.getAppearance=function(id)local v=world[id];return v and (v.appearance or "") end
V.setAppearance=function(id,name)local v=world[id];v.appearance=name or "";return true end
V.remove=function(id)world[id]=nil;for _,fn in ipairs(events.onVehicleRemoved or{})do fn(tostring(id),"test")end;return true end
V.getVisual=function(id)local v=world[id];if not v then return nil,"vehicle_not_found" end;return clone(v.visual)end
V.respawnAs=function(id,record)
    local v=world[id];if not v then return nil,"vehicle_not_found" end
    if not known(record) then return nil,"invalid_record" end
    calls.respawnAs=calls.respawnAs+1;v.record=record;v.engineHold=false;return id end
V.listEngineSounds=function(id) calls.listEngineSounds=calls.listEngineSounds+1
    local v=world[id];if not v then return nil,"vehicle_not_found" end;return soundsFor(v.record) end
V.setEngineSound=function(id,sound) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.setEngineSound=calls.setEngineSound+1
    if sound~=nil then
        local fits=false;for _,s in ipairs(soundsFor(v.record))do if s.id==sound then fits=true end end
        if not fits then return false,"engine_sound_not_for_class" end
    end
    local record=withSound(v.record,sound)
    if record~=v.record then calls.soundRespawns=calls.soundRespawns+1;v.record=record;v.engineHold=false end
    return true end
V.getEngineSound=function(id) local v=world[id];return v and soundOf(v.record) end
RegisterNetEvent=function(name,fn)rpc[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=function(name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end

dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
-- The generated catalogue: every catalogued model is staged (the test-only unstaged one
-- excepted), prices are valid amounts, and the dealer models' proposed prices are the curated ones.
assert(SC.maxStage==3 and SC.sounds.car==12 and SC.sounds.bike==4,"3 stages, 12 car sounds, 4 bike sounds")
local count,dealers=0,0
for record,entry in pairs(STAGED)do
    count=count+1
    assert(record:match("^Vehicle%.[%w_]+$") and record:find("_player",1,true),"a vanilla player record: "..record)
    assert(entry.class=="car" or entry.class=="bike","class of "..record)
    assert(#entry.prices==SC.maxStage,"one price per stage: "..record)
    for stage=1,SC.maxStage do assert(LightRP.money.validAmount(entry.prices[stage]),"price of "..record) end
    if entry.dealer then dealers=dealers+1 end
end
assert(count==86 and dealers==15,("%d staged records, %d dealer models"):format(count,dealers))
assert(STAGED["Vehicle.q000_hym_player_car"]==nil and STAGED["Vehicle.q304_songbird_escape_player"]==nil,"no quest variant")
for _,v in ipairs(LightRpConfig.vehicles.catalog)do
    if v.key~="unstaged" then assert(STAGED[v.record],"every catalogued model is staged: "..v.key) end
end
assert(STAGED[TYPE66].class=="car" and not STAGED[TYPE66].dealer and STAGED[KUSANAGI02].class=="bike" and not STAGED[KUSANAGI02].dealer)
-- Owner decision (2026-11-07): an extended model at 2x its vanilla price, each stage capped at the
-- dearest dealer stage of its class (Semimaru 25,000 / 37,500 / 50,000; Kusanagi 20,000 / 30,000 / 40,000).
local function prices(record,want)
    local got=STAGED[record].prices
    assert(got[1]==want[1] and got[2]==want[2] and got[3]==want[3],
        ("%s: %s / %s / %s"):format(record,tostring(got[1]),tostring(got[2]),tostring(got[3])))
end
prices(TYPE66,{9000,13000,17500})
prices(KUSANAGI02,{15000,22500,30000})
prices("Vehicle.v_sport1_rayfield_aerondight_player",{25000,37500,50000})
prices("Vehicle.v_sport1_yaiba_semimaru_player",{25000,37500,50000})
prices("Vehicle.v_sportbike1_yaiba_kusanagi_player",{20000,30000,40000})
local CAP={car={25000,37500,50000},bike={20000,30000,40000}}
for record,entry in pairs(STAGED)do
    for stage=1,3 do assert(entry.prices[stage]<=CAP[entry.class][stage],"over the dealer cap: "..record) end
end

dofile("server/modules/garages.lua")
local M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
local P,C=LightRpCustomizationPricing,LightRpVehicleCustomization
dofile("server/modules/vehicle_customization.lua")
local Custom=LightRP.vehicleCustomization
local NET="op77_lightrp:customization"
assert(P.performance.type66==nil and P.performance.kusanagi02==nil,"no curated price for the models under test")
for key,list in pairs(P.performance)do
    local record=LightRP.vehicles.byKey[key].record
    for stage=1,3 do assert(STAGED[record].prices[stage]==list[stage],"the curated "..key.." prices are the generated proposal") end
end

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
    local m={};for k,v in pairs(raw)do m[k]=v end;m.categories={}
    for i,text in ipairs(raw.categoriesJson)do m.categories[i]=json.decode(text) end
    return m
end
local function issue(operation,fields,pay)
    request=request+1;tick=tick+300
    local p={session=session,request=request,operation=operation,pay=pay}
    for k,v in pairs(fields)do p[k]=v end
    source=1;rpc[NET](p);return messages[#messages]
end
local function close() source=1;rpc[NET]({session=session,operation="close"}) end
local function saved(rowId) return json.decode(owned[rowId].properties) end
local function category(m,id) for _,c in ipairs(m.categories)do if c.id==id then return c end end end
local function stageOffer(m,record,prices)
    local perf=category(m,"performance")
    assert(perf and perf.available,"performance offered: "..tostring(perf and perf.reason))
    assert(#perf.options.stages==4 and perf.options.removal==P.performanceRemoval)
    for stage=1,3 do
        local s=perf.options.stages[stage+1]
        assert(s.stage==stage and s.available and s.record==record.."_o77s"..stage and s.price==prices[stage],
            ("stage %d of %s: %s at %s"):format(stage,record,tostring(s.record),tostring(s.price)))
    end
    return perf
end
assert(Custom.extraCategoriesStored==true,"the garage stores the engine sound")

-- 1. The Type-66 (staff key, no curated price): stages at the generated prices, 12 car sounds.
local ok,type66=G.grant(1,"type66");assert(ok,type66)
local car=retrieve(type66);local m=open(type66)
stageOffer(m,TYPE66,STAGED[TYPE66].prices)
local sound=category(m,"engineSound")
assert(sound.available and #sound.options.sounds==SC.sounds.car and sound.options.sounds[1].id=="s01","the 12 car sounds")
local bank=M.get(1).bank
local r=issue("save",{category="performance",stage=2},"bank");assert(r.ok,r.text)
assert(world[car].record==TYPE66.."_o77s2" and M.get(1).bank==bank-STAGED[TYPE66].prices[1]-STAGED[TYPE66].prices[2]
    and commits[#commits]=="vehicle_stage","an upgrade pays the generated stage 1 and 2 prices")
assert(saved(type66).lightrp.stage==2 and r.confirmed.stage==2)
bank=M.get(1).bank
r=issue("save",{category="engineSound",sound="s03"},"bank");assert(r.ok,r.text)
assert(world[car].record==TYPE66.."_o77s2a3" and M.get(1).bank==bank-P.engineSound and commits[#commits]=="vehicle_engine_sound","a sound keeps the stage")
r=issue("save",{category="engineSound",sound="s13"},"bank");assert(not r.ok,"a bike sound on a car")
close()
tick=tick+C.stages.cooldownMs;m=open(type66);bank=M.get(1).bank
assert(category(m,"performance").options.current==2)
r=issue("save",{category="performance",stage=3},"bank");assert(r.ok,r.text)
assert(world[car].record==TYPE66.."_o77s3a3" and M.get(1).bank==bank-STAGED[TYPE66].prices[3],"stage 3 pays its own price, the sound stays")
close();store(type66)
car=retrieve(type66);assert(world[car].record==TYPE66.."_o77s3a3","parked and retrieved on its stage and sound")
close();store(type66)

-- 2. The Kusanagi trim (_player_02, a bike): stages at the generated prices, the 4 bike sounds.
local kusanagi
ok,kusanagi=G.grant(1,"kusanagi02");assert(ok,kusanagi)
car=retrieve(kusanagi);m=open(kusanagi)
stageOffer(m,KUSANAGI02,STAGED[KUSANAGI02].prices)
sound=category(m,"engineSound")
assert(sound.available and #sound.options.sounds==SC.sounds.bike and sound.options.sounds[1].id==("s%02d"):format(SC.sounds.car+1),"the 4 bike sounds")
bank=M.get(1).bank
r=issue("save",{category="performance",stage=1},"bank");assert(r.ok,r.text)
assert(world[car].record==KUSANAGI02.."_o77s1" and M.get(1).bank==bank-STAGED[KUSANAGI02].prices[1],"stage 1 of the trim, the trim suffix kept")
r=issue("save",{category="engineSound",sound="s01"},"bank");assert(not r.ok,"a car sound on a bike")
bank=M.get(1).bank
r=issue("save",{category="engineSound",sound="s14"},"bank");assert(r.ok,r.text)
assert(world[car].record==KUSANAGI02.."_o77s1a14" and M.get(1).bank==bank-P.engineSound)
close();store(kusanagi)

-- 3. The Hella keeps its curated prices (P.performance wins over the generated catalogue).
local hella
ok,hella=G.grant(1,"hella");assert(ok,hella)
car=retrieve(hella);m=open(hella)
stageOffer(m,HELLA,P.performance.hella)
assert(#category(m,"engineSound").options.sounds==SC.sounds.car)
close();store(hella)

-- 4. A model the pack does not stage stays greyed, with its reasons.
local unstaged
ok,unstaged=G.grant(1,"unstaged");assert(ok,unstaged)
car=retrieve(unstaged);m=open(unstaged)
assert(not category(m,"performance").available and category(m,"performance").reason==C.unsupported.performance,"no stage, no price")
assert(not category(m,"engineSound").available and category(m,"engineSound").reason==C.unsupported.engineSound,"no sound for it")
r=issue("save",{category="performance",stage=1},"bank");assert(not r.ok)
close()

print(("vehicle stage catalogue: %d staged records (%d dealer), generated prices on the Type-66 and a Kusanagi trim (stages, sum, sound kept), 12/4 sounds by class, curated Hella prices, an unstaged model greyed, names round-trip passed"):format(count,dealers))
return true
