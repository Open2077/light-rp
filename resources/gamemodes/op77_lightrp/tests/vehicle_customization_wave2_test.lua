-- Auto Studio wave 2 (PLAN-vehicle-custom-wave2.md): neon animation, lamp colors, engine
-- sound, stickers and tag on the real economy + inventory + garage + customization modules.
-- The native mock follows the wave 2 shared contract: set*/get* per category (no getTag),
-- listEngineSounds / listStickers / getDecalBudget (livery included, 12 at most), the five
-- getProperties keys (LIGHTRP_WAVE2_KEYS=visual keeps them in `visual`, else at the top
-- level), an engine sound riding on the record (Vehicle.<base>_o77a<k>, _o77s<n>a<k>) and a
-- rebuild (respawnAs) that drops it.
-- The full flow needs Garage.registerCustomizationCategory, the garage's category registry;
-- without it the categories must stay greyed. LIGHTRP_GARAGES=<path> runs this file against
-- another garages.lua (the registry patch, before it is merged).
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
dofile("server/config/vehicle_kit.lua");dofile("server/config/vehicle_kit_trims.lua")
local WHERE=os.getenv("LIGHTRP_WAVE2_KEYS")=="visual" and "visual" or "top"
local GARAGES=os.getenv("LIGHTRP_GARAGES") or "server/modules/garages.lua"
local function noop() end
local tick, uid = 1000, 0
local failDb = false
local owner = {identifier="wave2-test",key="default",status="active"}
local walletRow = {account_number="AAA-W2",owner_name="Test",cash=50000,bank=1000000}
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
    if failDb then return false,"database_error" end
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
for _,v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key]=v end
local function logged(text) for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end end

-- Natives (phase 1 + 2, as in vehicle_customization_kit_test.lua) ------------------------
local HELLA="Vehicle.v_standard2_archer_hella_player"
local world,vid,events,rpc,bags={},100,{},{},{}
local calls={respawnAs=0,soundRespawns=0,hold=0,engineOff=0,w2=0}
local server2=false -- the wave 2 natives and getProperties keys exist on this "build"
local stickerRefusal
local packs={lightrp_vehicle_stages="running"}
GetResourceState=function(name) return packs[name] or "missing" end
GetCurrentResourceName=function() return "op77_lightrp" end
-- Records: Vehicle.<base>, _o77s<n> (stage), _o77a<k> / _o77s<n>a<k> (engine sound k).
local SOUNDS={{id="s01",label="Inline-six, rough",class="car",k=1},{id="s02",label="V8, deep",class="car",k=2},{id="s03",label="Electric whine",class="car",k=3}}
local function plain(record) return (tostring(record):gsub("(_o77s%d+)a%d+$","%1"):gsub("_o77a%d+$","")) end
local function base(record) return (plain(record):gsub("_o77s%d+$","")) end
local function soundOf(record)
    local k=tostring(record):match("_o77s%d+a(%d+)$") or tostring(record):match("_o77a(%d+)$")
    for _,s in ipairs(SOUNDS)do if s.k==tonumber(k) then return s.id end end
end
local function soundK(id) for _,s in ipairs(SOUNDS)do if s.id==id then return s.k end end end
local function withSound(record,id)
    local r=plain(record);if id==nil then return r end
    return r:match("_o77s%d+$") and r.."a"..soundK(id) or r.."_o77a"..soundK(id)
end
local function known(record)
    local b,ok=base(record),false
    for _,v in ipairs(LightRpConfig.vehicles.catalog)do if v.record==b then ok=true end end
    local r=plain(record)
    return ok and (r==b or r:match("_o77s[1-3]$")~=nil)
end
local profiles={[HELLA]={{id="hella_tt_1",main={r=200,g=20,b=20},sec={r=10,g=10,b=10},appearances={"a"},hasPattern=false},
    {id="hella_tt_2",appearances={"b"},hasPattern=true}}}
local LIVERY_DECALS={hella_tt_1=0,hella_tt_2=9}
local STICKERS={
    {id="st.hella.valentinos_01",label="Valentinos I",group="Valentinos",model=HELLA,decals=1},
    {id="st.hella.valentinos_02",label="Valentinos II",group="Valentinos",model=HELLA,decals=2},
    {id="st.hella.tygers_01",label="Tyger Claws",group="Tyger Claws",model=HELLA,decals=1},
    {id="st.hella.dealer_01",label="Dealer stripe",group="Dealer",model=HELLA,decals=3}}
local function stickerDecals(list) local n=0
    for _,id in ipairs(list or {})do for _,s in ipairs(STICKERS)do if s.id==id then n=n+s.decals end end end;return n end
local function decalsOf(v) return (LIVERY_DECALS[v.visual.profile or ""] or 0)+stickerDecals(v.w2.stickers) end
local function rgb(v)if type(v)=="table"then return {r=v.r or v[1],g=v.g or v[2],b=v.b or v[3]} end;return{r=tonumber(v:sub(2,3),16),g=tonumber(v:sub(4,5),16),b=tonumber(v:sub(6,7),16)}end
local function view(v,rev)
    local x=v.visual;local out={profile=x.profile,neon=clone(x.neon),parts=clone(x.parts),wheels=clone(x.wheels),tint=x.tint}
    if rev then out.rev=x.rev end;return out
end
local function bump(v) v.visual.rev=(v.visual.rev or 0)+1 end
local function profileOk(record,profile) for _,p in ipairs(profiles[base(record)] or {})do if p.id==profile then return true end end end
local function neonOf(spec) return {enabled=spec.enabled~=false,color=rgb(spec.color),intensity=spec.intensity or 600,radius=spec.radius or 3,layout="auto"} end
local W2={"neonAnimation","lightColors","stickers","tag"} -- the engine sound is read from the record
local W2KEY={neonAnimation=1,lightColors=1,engineSound=1,stickers=1,tag=1}
local PROPS={version=1,record=1,health=1,paint=1,appearance=1,visual=1}
local soundOn -- below, with the wave 2 natives
Open77={players={getLifeState=function() return {phase="alive"} end,position=function()return{x=0,y=0,z=0,bucket=0}end},
    vehicles={getPlayerSeat=function() return nil end},
    state={entity=function(_,id) return {set=function(_,k,v) bags[id]=bags[id] or {};bags[id][k]=v end,get=function(_,k) return (bags[id] or {})[k] end} end},
    exports={callSync=function(resource,method,record,stage)
        if packs[resource]~="running" then error("resource_not_running:"..resource) end
        assert(resource=="lightrp_vehicle_stages" and method=="stageRecord")
        local b=base(record);if not known(b) then return nil,"unknown_record" end
        if stage==0 then return b end;return b.."_o77s"..stage end}}
local V=Open77.vehicles
V.all=function()local out={};for _,v in pairs(world)do out[#out+1]=v end;return out end
V.get=function(id)return world[id]end
V.create=function(p)
    if not known(p.record) then return nil,"invalid_record" end
    vid=vid+1;world[vid]={id=vid,record=p.record,position=p.position,bucket=p.bucket,health=.8,speed=0,occupants={},
    paint={applied=false},appearance=p.appearance or "",visual={parts={},rev=0},w2={}};return vid end
V.getProperties=function(id)
    local v=world[id];if not v then return nil end
    local p={version=1,record=v.record,health=v.health,paint=clone(v.paint),appearance=v.appearance,visual=view(v)}
    if server2 then
        local into=WHERE=="visual" and p.visual or p
        for _,k in ipairs(W2)do into[k]=clone(v.w2[k]) end
        into.engineSound=soundOf(v.record)
    end
    return p
end
V.setProperties=function(id,p)
    for k in pairs(p)do if not PROPS[k] and not (server2 and WHERE=="top" and W2KEY[k]) then return false,"unsupported_property:"..k end end
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if p.record~=nil and p.record~=v.record then return false,"record_mismatch" end
    -- As the platform does: a record named beside an engine sound must carry that sound
    -- (engine_sound_mismatch); without a record the sound is applied like setEngineSound.
    if server2 and p.record~=nil then
        local from=WHERE=="visual" and p.visual or p
        if type(from)=="table" and from.engineSound~=nil and soundOf(p.record)~=from.engineSound then return false,"engine_sound_mismatch" end
    end
    local visual
    if p.visual~=nil then -- complete: an absent field means none
        local x=p.visual
        if x.profile~=nil and not profileOk(v.record,x.profile) then return false,"invalid_profile" end
        visual={profile=x.profile,neon=x.neon and neonOf(x.neon),parts={},tint=x.tint~=0 and x.tint or nil,rev=(v.visual.rev or 0)+1}
    end
    if p.paint then v.paint=clone(p.paint) end;v.health=p.health or v.health
    if (p.appearance or "")~=(v.appearance or "") then v.appearance=p.appearance or "" end
    if visual then v.visual=visual end
    if server2 then -- in `visual`, complete like it; at the top level, an absent key keeps the car's
        local from=WHERE=="visual" and p.visual or p
        if from~=nil then
            for _,k in ipairs(W2)do if WHERE=="visual" or from[k]~=nil then v.w2[k]=clone(from[k]) end end
            if WHERE=="visual" or from.engineSound~=nil then
                local ok,why=soundOn(v,from.engineSound);if not ok then return false,why end
            end
        end
    end
    return true end
V.setEngine=function(id,on)local v=world[id];if v and on==false then v.engineHold=false;calls.engineOff=calls.engineOff+1 end;return true end
V.setEngineHold=function(id,on)local v=world[id];if not v then return false,"vehicle_not_found" end;v.engineHold=on==true;calls.hold=calls.hold+1;return true end
V.isLocked=function()return false end
V.setPaint=function(id,p)local v=world[id];if not v then return false,"vehicle_not_found" end
    v.paint={applied=true,primary=rgb(p.primary),secondary=rgb(p.secondary),lightsHue=v.paint.lightsHue};v.visual.profile=nil;return true end
V.resetPaint=function(id)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint={applied=false};v.visual.profile=nil;return true end
V.setLightsHue=function(id,hue)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint.lightsHue=hue;return true end
V.setHeadlightColor=function(id)local v=world[id];v.paint.lightsHue=.5;return true end
V.clearLightsHue=function(id)return V.setLightsHue(id,nil)end
V.getLightsHue=function(id)local v=world[id];return v and v.paint.lightsHue end
V.getAppearance=function(id)local v=world[id];return v and (v.appearance or "") end
V.setAppearance=function(id,name)local v=world[id];v.appearance=name or "";return true end
V.remove=function(id)world[id]=nil;for _,fn in ipairs(events.onVehicleRemoved or{})do fn(tostring(id),"test")end;return true end
V.listParts=function() return {} end -- no kit parts in this file: rims and body stay greyed
V.listPaintProfiles=function(x) local record=type(x)=="string" and x or (world[x] and world[x].record);return clone(profiles[base(record or "")] or {}) end
V.getVisual=function(id)local v=world[id];if not v then return nil,"vehicle_not_found" end;return view(v,true)end
V.setPaintProfile=function(id,profile)
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if profile~=nil and not profileOk(v.record,profile) then return false,"invalid_profile" end
    if server2 and (LIVERY_DECALS[profile or ""] or 0)+stickerDecals(v.w2.stickers)>12 then return false,"decal_budget_exceeded" end
    v.visual.profile=profile;bump(v);return true end
V.setNeon=function(id,spec)local v=world[id];if not v then return false,"vehicle_not_found" end;v.visual.neon=neonOf(spec);bump(v);return true end
V.clearNeon=function(id)local v=world[id];v.visual.neon=nil;bump(v);return true end
-- The rebuild of a stage keeps the car but not what rides on its record.
V.respawnAs=function(id,record)
    local v=world[id];if not v then return nil,"vehicle_not_found" end
    if not known(record) then return nil,"invalid_record" end
    calls.respawnAs=calls.respawnAs+1;v.record=record;v.engineHold=false;return id end

-- Wave 2 natives, as the shared contract states them (refusal names: those of the natives
-- branch, vc/wave2-natives).
local function redOrBlue(c) if c==nil then return nil end;c=rgb(c)
    if c.r>=180 and c.g<=90 and c.b<=110 then return "red" end
    if c.b>=180 and c.r<=90 and c.g<=170 then return "blue" end end
function soundOn(v,sound) -- an engine sound rides on the record: rebuilt like a stage
    if sound~=nil and not soundK(sound) then return false,"unknown_engine_sound" end
    local record=withSound(v.record,sound)
    if record~=v.record then calls.soundRespawns=calls.soundRespawns+1;v.record=record;v.engineHold=false end
    return true end
local MODES={pulse=1,breathe=1,strobe=1,chase=1,rainbow=1,speed=1,brake=1}
local GROUPS={brake=1,reverse=1,blinkers=1,interior=1}
local WAVE2={}
function WAVE2.setNeonAnimation(id,a) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.w2=calls.w2+1
    if a==nil then v.w2.neonAnimation=nil;return true end
    if not MODES[a.mode] then return false,"invalid_mode" end
    if type(a.periodMs)~="number" or a.periodMs<250 or a.periodMs>10000 then return false,"invalid_period" end
    if a.mode=="strobe" and a.periodMs<333 then return false,"strobe_too_fast" end
    local neon=v.visual.neon and v.visual.neon.color
    if (a.mode=="strobe" and redOrBlue(neon)) or (a.mode=="chase" and redOrBlue(neon) and redOrBlue(a.color2) and redOrBlue(neon)~=redOrBlue(a.color2)) then
        return false,"emergency_look:neonAnimation" end
    v.w2.neonAnimation={mode=a.mode,periodMs=a.periodMs,color2=a.color2 and rgb(a.color2)};return true end
function WAVE2.getNeonAnimation(id) local v=world[id];return v and clone(v.w2.neonAnimation) end
function WAVE2.setLightColors(id,l) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.w2=calls.w2+1
    if l==nil then v.w2.lightColors=nil;return true end
    local out,any={},false
    for group,c in pairs(l)do if not GROUPS[group] then return false,"unknown_group" end;out[group]=rgb(c);any=true end
    if redOrBlue(out.blinkers) or redOrBlue(out.brake)=="blue" then return false,redOrBlue(out.blinkers) and "emergency_look:blinkers" or "emergency_look:brake" end
    v.w2.lightColors=any and out or nil;return true end
function WAVE2.getLightColors(id) local v=world[id];return v and clone(v.w2.lightColors) end
function WAVE2.listEngineSounds(id) if not world[id] then return nil,"vehicle_not_found" end
    local out={};for _,s in ipairs(SOUNDS)do out[#out+1]={id=s.id,label=s.label,class=s.class} end;return out end
function WAVE2.setEngineSound(id,sound) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.w2=calls.w2+1;return soundOn(v,sound) end
function WAVE2.getEngineSound(id) local v=world[id];return v and soundOf(v.record) end
function WAVE2.listStickers(id) local v=world[id];if not v then return nil,"vehicle_not_found" end
    local out={};for _,s in ipairs(STICKERS)do if s.model==base(v.record) then out[#out+1]={id=s.id,label=s.label,group=s.group,decals=s.decals} end end;return out end
function WAVE2.setStickers(id,list) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.w2=calls.w2+1
    if stickerRefusal then return false,stickerRefusal end
    for _,sid in ipairs(list or {})do local fits;for _,s in ipairs(STICKERS)do if s.id==sid and s.model==base(v.record) then fits=true end end
        if not fits then return false,"unknown_sticker" end end
    if (LIVERY_DECALS[v.visual.profile or ""] or 0)+stickerDecals(list)>12 then return false,"decal_budget_exceeded" end
    v.w2.stickers=list and #list>0 and clone(list) or nil;return true end
function WAVE2.getStickers(id) local v=world[id];return v and clone(v.w2.stickers) end
function WAVE2.getDecalBudget(id) local v=world[id];if not v then return nil,"vehicle_not_found" end;return decalsOf(v),12 end
function WAVE2.setTag(id,t) local v=world[id];if not v then return false,"vehicle_not_found" end
    calls.w2=calls.w2+1
    if t==nil then v.w2.tag=nil;return true end
    if type(t.text)~="string" or #t.text==0 or #t.text>12 then return false,"invalid_tag" end
    v.w2.tag={text=t.text,font=t.font,color=rgb(t.color),spot=t.spot};return true end
local function wave2(on) server2=on;for name,fn in pairs(WAVE2)do V[name]=on and fn or nil end end

RegisterNetEvent=function(name,fn)rpc[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=function(name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end

dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
local before=#threads;dofile(GARAGES);local garageWorker=threads[before+1]
local M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
local P,C=LightRpCustomizationPricing,LightRpVehicleCustomization
local REGISTRY=type(G.registerCustomizationCategory)=="function"
dofile("server/modules/vehicle_customization.lua")
local Custom=LightRP.vehicleCustomization
local NET="op77_lightrp:customization"
local EXTRA={"neonAnimation","lightColors","stickers","tag","engineSound"}
for _,id in ipairs(EXTRA)do assert(LightRP.money.validAmount(P[id]),"a provisional price for "..id) end

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
local session,request,maxCategoryValues
local function countValues(v)if type(v)~="table"then return 1 end;local n=1;for _,x in pairs(v)do n=n+countValues(x)end;return n end
-- The client's net event reader drops an event deeper than 8 levels or over 1024 values.
local function shape(v,depth) depth=depth or 1
    if type(v)~="table" then return 1,depth end
    local nodes,deepest=1,depth
    for _,x in pairs(v)do local n,d=shape(x,depth+1);nodes=nodes+n;if d>deepest then deepest=d end end
    return nodes,deepest end
local function fitsClient(p,label) local nodes,depth=shape(p);nodes=nodes+1
    assert(depth<=8 and nodes<=1024,("%s exceeds the client event reader: depth %d (max 8), %d values (max 1024)"):format(label,depth,nodes)) end
local function open(rowId)
    assert(Custom.open(1,rowId,"citycenter"));local raw=messages[#messages];session,request=raw.session,0
    fitsClient(raw,"the studio open message")
    local m={};for k,v in pairs(raw)do m[k]=v end;m.categories={}
    for i,text in ipairs(raw.categoriesJson)do
        m.categories[i]=json.decode(text)
        local values=countValues(m.categories[i])
        assert(values<=1000,("category %s is %d JSON values, over the client's cap"):format(tostring(m.categories[i].id),values))
        maxCategoryValues=math.max(maxCategoryValues or 0,values)
    end;return m
end
local function issue(operation,fields,pay)
    request=request+1;tick=tick+300
    local p={session=session,request=request,operation=operation,pay=pay}
    for k,v in pairs(fields)do p[k]=v end
    source=1;rpc[NET](p);local r=messages[#messages];fitsClient(r,"a studio response");return r
end
local function close() source=1;rpc[NET]({session=session,operation="close"}) end
local function saved(rowId) return json.decode(owned[rowId].properties) end
-- a stored wave 2 field, wherever getProperties keeps it
local function stored(rowId,key) local p=saved(rowId);return (type(p.visual)=="table" and p.visual[key]) or p[key] end
local function category(m,id) for _,c in ipairs(m.categories)do if c.id==id then return c end end end
local function autosave() local saver=coroutine.create(garageWorker);for _=1,9 do assert(coroutine.resume(saver));tick=tick+2000 end end
local function reboot(noRegistry)
    world={};events={};threads={};LightRP.inventory=nil
    dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
    local at=#threads;dofile(GARAGES);garageWorker=threads[at+1]
    M,G=LightRP.money,LightRP.garage
    LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
    if noRegistry then G.registerCustomizationCategory=nil end
    dofile("server/modules/vehicle_customization.lua");Custom=LightRP.vehicleCustomization
end
local function same(a,b)
    if type(a)~="table" or type(b)~="table" then return a==b end
    for k,v in pairs(a)do if not same(v,b[k]) then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true end

-- 1. A server build without the wave 2 natives: greyed with their reason, the tag not even
-- listed, a forged request refused before any native.
local ok,hella=G.grant(1,"hella");assert(ok)
local car=retrieve(hella)
local m=open(hella)
for _,id in ipairs({"neonAnimation","lightColors","stickers","engineSound"})do
    local c=category(m,id);assert(c and not c.available and c.reason==C.unsupported.native,id.." greyed without its native")
end
assert(category(m,"tag")==nil,"no tag row without setTag")
assert(category(m,"neonAnimation").parent=="neon" and category(m,"lightColors").parent=="lights","sub-panels name their parent")
local r=issue("preview",{category="neonAnimation",mode="pulse",speed="medium"})
assert(not r.ok and r.text==C.unsupported.native and calls.w2==0)
r=issue("save",{category="tag",text="HELLO",font="marker",color="#FFCC00",spot="hood"},"bank")
assert(not r.ok and r.text=="This customization is not offered for this vehicle.")
close();store(hella)

-- 2. Natives present, garage without the category registry: greyed, never applied (an
-- autosave there would keep a preview, and a purchase would not be stored).
wave2(true)
reboot(true)
assert(logged("this garage has no category registry"),"the missing registry is logged")
car=retrieve(hella);m=open(hella)
for _,id in ipairs(EXTRA)do
    local c=category(m,id);assert(c and not c.available and c.reason==C.unsupported.garage,id.." greyed without the garage registry")
end
r=issue("preview",{category="engineSound",sound="s02"})
assert(not r.ok and r.text==C.unsupported.garage and calls.w2==0 and calls.soundRespawns==0)
close();store(hella)
if not REGISTRY then
    print("customization wave 2: greying without natives and without the garage registry passed")
    print("SKIP customization wave 2 full flow: "..GARAGES.." has no Garage.registerCustomizationCategory (apply the registry patch, or run with LIGHTRP_GARAGES)")
    return false
end

-- 3. The registry: each category registers once, in page order, with its ledger kind.
reboot()
assert(Custom.extraCategoriesStored==true)
car=retrieve(hella);m=open(hella)
for _,id in ipairs(EXTRA)do assert(category(m,id).available,id.." offered") end
for _,id in ipairs(EXTRA)do assert(m.prices[id]==P[id],"the server quotes "..id) end
local anim,lamps,sound,stickers,tag=category(m,"neonAnimation"),category(m,"lightColors"),category(m,"engineSound"),category(m,"stickers"),category(m,"tag")
assert(#anim.options.modes==7 and anim.options.speeds[2].id=="medium" and anim.options.speeds[2].periodMs==nil,"modes and speed ids, never a period")
assert(#lamps.options.groups==4 and lamps.options.groups[1].safety and lamps.options.groups[3].refuse[1]=="red")
assert(#sound.options.sounds==3 and sound.options.sounds[2].label=="V8, deep" and sound.options.respawns and sound.options.preview)
assert(#stickers.options.stickers==4 and stickers.options.stickers[4].decals==3 and same(stickers.options.budget,{base=0,maximum=12}))
assert(#tag.options.fonts>=1 and #tag.options.spots>=1 and tag.options.maxLength==C.tag.maxLength)
assert(m.confirmed.engineSound=="" and #m.confirmed.stickers==0 and m.confirmed.neonAnimation==nil)
local bank=M.get(1).bank

-- 4. Neon animation: it runs on a neon, never reads as an emergency light, and a preview
-- is never stored.
r=issue("preview",{category="neonAnimation",mode="pulse",speed="medium"})
assert(not r.ok and r.text=="Choose a neon color first: the animation runs on it.")
r=issue("preview",{category="neon",color="#FF1E3C",intensity="medium"});assert(r.ok,r.text)
r=issue("preview",{category="neonAnimation",mode="strobe",speed="fast"})
assert(not r.ok and r.text:find("strobe reads as an emergency light",1,true) and world[car].w2.neonAnimation==nil,"a red strobe")
r=issue("preview",{category="neonAnimation",mode="chase",speed="slow",color2="#2F6BFF"})
assert(not r.ok and r.text:find("Red and blue together",1,true),"a red and blue chase")
r=issue("preview",{category="neonAnimation",mode="chase",speed="slow",color2="#FFB000"});assert(r.ok,r.text)
assert(same(world[car].w2.neonAnimation,{mode="chase",periodMs=2400,color2={r=255,g=176,b=0}}),"the period comes from the speed step")
r=issue("preview",{category="neonAnimation",mode="pulse",speed="medium",periodMs=50});assert(r.ok and world[car].w2.neonAnimation.periodMs==1200,"a client period is ignored")
r=issue("save",{category="neonAnimation",mode="pulse",speed="medium"},"bank")
assert(not r.ok and r.text=="Buy a neon kit first: the animation runs on it." and M.get(1).bank==bank)
autosave()
assert(stored(hella,"neonAnimation")==nil and (saved(hella).visual or {}).neon==nil,"previews are not autosaved")
r=issue("save",{category="neon",color="#3CFF6E",intensity="medium"},"bank");assert(r.ok,r.text);bank=M.get(1).bank
autosave()
assert(stored(hella,"neonAnimation")==nil,"buying the neon does not store the animation preview")
r=issue("save",{category="neonAnimation",mode="pulse",speed="medium"},"bank");assert(r.ok,r.text)
assert(M.get(1).bank==bank-P.neonAnimation and commits[#commits]=="vehicle_neon_anim","paid and receipted")
assert(stored(hella,"neonAnimation").mode=="pulse" and stored(hella,"neonAnimation").periodMs==1200,"stored with the purchase")
assert(r.confirmed.neonAnimation.mode=="pulse" and r.confirmed.neonAnimation.speed=="medium")
bank=M.get(1).bank
r=issue("save",{category="neonAnimation",mode="pulse",speed="medium"},"bank")
assert(not r.ok and r.text=="Choose a different animation before purchasing." and M.get(1).bank==bank,"an unchanged animation is not sold")
r=issue("save",{category="neonAnimation",mode="strobe",speed="slow"},"bank");assert(r.ok,r.text);bank=M.get(1).bank
r=issue("preview",{category="neon",color="#FF1E3C",intensity="medium"})
assert(not r.ok and r.text:find("With your neon animation",1,true),"a red neon under a bought strobe")
r=issue("preview",{category="neonAnimation",stock=true});assert(r.ok and world[car].w2.neonAnimation==nil,"back to static, as a preview")
close()
assert(world[car].w2.neonAnimation.mode=="strobe","closing puts the bought animation back")
assert(stored(hella,"neonAnimation").mode=="strobe")

-- 5. Lamp colors: safety groups stay visible and never read as an emergency vehicle.
m=open(hella)
r=issue("preview",{category="lightColors",lamps={brake="#2F6BFF"}});assert(not r.ok and r.text=="Brake lights cannot be blue: it reads as an emergency vehicle.")
r=issue("preview",{category="lightColors",lamps={blinkers="#FF1E3C"}});assert(not r.ok and r.text=="Blinkers cannot be red: it reads as an emergency vehicle.")
r=issue("preview",{category="lightColors",lamps={brake="#300000"}});assert(not r.ok and r.text=="Brake lights must stay visible: choose a brighter color.")
r=issue("preview",{category="lightColors",lamps={horn="#FFFFFF"}});assert(not r.ok and r.text=="This lamp cannot be recolored.")
r=issue("preview",{category="lightColors",lamps={}});assert(not r.ok and r.text=="Choose at least one lamp color, or Factory lamps.")
assert(world[car].w2.lightColors==nil,"nothing reached the car")
r=issue("preview",{category="lightColors",lamps={reverse="#00E5FF",interior="#FF2BD6"}});assert(r.ok,r.text)
assert(same(world[car].w2.lightColors,{reverse={r=0,g=229,b=255},interior={r=255,g=43,b=214}}),"the native takes {r,g,b} per group")
autosave();assert(stored(hella,"lightColors")==nil,"a lamp preview is not autosaved")
r=issue("save",{category="paint",primary="#101010",secondary="#202020"},"bank");assert(r.ok,r.text)
assert(stored(hella,"lightColors")==nil,"another category's purchase keeps the lamp preview out")
bank=M.get(1).bank
r=issue("save",{category="lightColors",lamps={reverse="#00E5FF",interior="#FF2BD6"}},"bank");assert(r.ok,r.text)
assert(M.get(1).bank==bank-P.lightColors and commits[#commits]=="vehicle_lamps")
assert(same(stored(hella,"lightColors"),{reverse={r=0,g=229,b=255},interior={r=255,g=43,b=214}}))
assert(r.confirmed.lightColors.reverse=="#00E5FF" and r.confirmed.lightColors.brake==nil)
bank=M.get(1).bank
r=issue("save",{category="lightColors",lamps={interior="#FF2BD6",reverse="#00E5FF"}},"bank")
assert(not r.ok and r.text=="Choose different lamp colors before purchasing." and M.get(1).bank==bank)
-- a refused write puts the bought lamps back and charges nothing
failDb=true
r=issue("save",{category="lightColors",lamps={reverse="#FFE45C"}},"bank")
failDb=false
assert(not r.ok and M.get(1).bank==bank and world[car].w2.lightColors.reverse.g==229 and world[car].w2.lightColors.interior,"a failed purchase is rolled back")
close()

-- 6. Engine sound: a rebuild per change, one per cooldown, heard with the engine held,
-- and kept through a stage.
m=open(hella)
r=issue("preview",{category="engineSound",sound="s02"});assert(r.ok,r.text)
assert(world[car].record==HELLA.."_o77a2" and calls.soundRespawns==1,"the car is rebuilt on its sound record")
assert(world[car].engineHold==true and calls.hold==1,"the empty car keeps running so the note is heard")
r=issue("preview",{category="engineSound",sound="s03"})
assert(not r.ok and r.text:find("still being rebuilt",1,true) and world[car].record==HELLA.."_o77a2","one rebuild per cooldown")
tick=tick+C.engineSound.previewCooldownMs
r=issue("preview",{category="engineSound",sound="s99"});assert(not r.ok and r.text=="This engine sound does not fit this vehicle.")
autosave();assert(stored(hella,"engineSound")==nil,"a sound preview is not autosaved")
close()
assert(world[car].record==HELLA and calls.soundRespawns==2,"closing rebuilds the car on its bought sound")
assert(world[car].engineHold==false and calls.engineOff>=1,"and stops the held engine")
m=open(hella);bank=M.get(1).bank
C.engineSound.preview=false
r=issue("preview",{category="engineSound",sound="s01"});assert(not r.ok and r.text:find("no preview",1,true))
C.engineSound.preview=true
tick=tick+C.engineSound.previewCooldownMs
r=issue("save",{category="engineSound",sound="s02"},"bank");assert(r.ok,r.text)
assert(r.text=="Engine sound fitted and saved to your vehicle." and M.get(1).bank==bank-P.engineSound and commits[#commits]=="vehicle_engine_sound")
assert(stored(hella,"engineSound")=="s02" and r.confirmed.engineSound=="s02" and world[car].record==HELLA.."_o77a2")
tick=tick+C.engineSound.previewCooldownMs
r=issue("save",{category="engineSound",sound="s02"},"bank");assert(not r.ok and r.text=="This engine sound is already fitted.")
local respawns,rebuilt=calls.respawnAs,calls.soundRespawns
r=issue("save",{category="performance",stage=1},"bank");assert(r.ok,r.text)
assert(calls.respawnAs==respawns+1 and world[car].record==HELLA.."_o77s1a2","a stage keeps the bought sound (put back after the rebuild)")
close()
assert(world[car].record==HELLA.."_o77s1a2" and calls.respawnAs==respawns+1 and calls.soundRespawns==rebuilt+1,"closing does not rebuild a car on its stage and sound")

-- 7. Stickers: per sticker added, within the decal budget the livery leaves.
m=open(hella);bank=M.get(1).bank
local V1,V2,TY,DE="st.hella.valentinos_01","st.hella.valentinos_02","st.hella.tygers_01","st.hella.dealer_01"
r=issue("preview",{category="stickers",stickers={V1,V1}});assert(not r.ok and r.text=="Each sticker goes on once.")
r=issue("preview",{category="stickers",stickers={"st.colby.6th_street"}});assert(not r.ok and r.text=="This sticker does not fit this vehicle.")
r=issue("preview",{category="stickers",stickers={a=V1}});assert(not r.ok and r.text=="Choose your stickers.")
r=issue("preview",{category="stickers",stickers={V1,V2}});assert(r.ok,r.text)
assert(same(world[car].w2.stickers,{V1,V2}) and same(r.budget,{base=0,maximum=12}),"the budget left by the livery")
autosave();assert(stored(hella,"stickers")==nil,"a sticker preview is not autosaved")
r=issue("save",{category="stickers",stickers={V1,V2}},"bank");assert(r.ok,r.text)
assert(M.get(1).bank==bank-2*P.stickers and commits[#commits]=="vehicle_stickers","two stickers added, two paid");bank=M.get(1).bank
r=issue("save",{category="stickers",stickers={V1,V2,TY}},"bank");assert(r.ok and M.get(1).bank==bank-P.stickers,"one added");bank=M.get(1).bank
r=issue("save",{category="stickers",stickers={V1}},"bank");assert(r.ok and M.get(1).bank==bank-P.stickers,"removing only costs one");bank=M.get(1).bank
r=issue("save",{category="stickers",stickers={V1}},"bank");assert(not r.ok and r.text=="Change at least one sticker before purchasing.")
stickerRefusal="decal_budget_exceeded"
r=issue("preview",{category="stickers",stickers={V1,TY}});assert(not r.ok and r.text:find("Too many decals on this vehicle",1,true),"the native's budget refusal, in words")
stickerRefusal="emergency_look:stickers"
r=issue("preview",{category="stickers",stickers={V1,TY}});assert(not r.ok and r.text=="This color reads as an emergency light: choose another.","a suffixed reason is read by its name")
stickerRefusal="glue_dry"
r=issue("preview",{category="stickers",stickers={V1,TY}});assert(not r.ok and r.text=="These stickers were refused (glue_dry)","an unknown refusal keeps its reason")
stickerRefusal=nil
r=issue("preview",{category="livery",profile="hella_tt_2"});assert(r.ok,r.text)
assert(same(r.budget,{base=9,maximum=12}),"a livery preview changes the budget left")
r=issue("preview",{category="stickers",stickers={V1,DE}})
assert(not r.ok and r.text=="Too many decals: 13 of 12 with this livery. Remove a sticker.","13 decals refused before the native")
r=issue("preview",{category="stickers",stickers={V1,V2}});assert(r.ok,r.text)
r=issue("save",{category="stickers",stickers={V1,V2}},"bank")
assert(not r.ok and r.text=="Apply or undo your livery preview first: stickers share its decal budget.")
r=issue("save",{category="livery",profile="hella_tt_2"},"bank")
assert(not r.ok and r.text=="Apply or undo your sticker preview first: stickers share the livery's decal budget.")
r=issue("preview",{category="stickers",stickers={V1}});assert(r.ok,r.text)
r=issue("save",{category="livery",profile="hella_tt_2"},"bank");assert(r.ok,r.text);bank=M.get(1).bank
r=issue("save",{category="stickers",stickers={V1,V2}},"bank");assert(r.ok and M.get(1).bank==bank-P.stickers,r.text)
autosave()
assert(same(stored(hella,"stickers"),{V1,V2}) and saved(hella).visual.profile=="hella_tt_2" and world[car].visual.profile=="hella_tt_2")
close()

-- 8. Tag (W2.5): the plate's word lists, a short charset, and no getTag (read back from
-- getProperties).
assert(V.getTag==nil)
m=open(hella);bank=M.get(1).bank
local function paint(text,extra) local f={category="tag",text=text,font="marker",color="#FFCC00",spot="door_left"};for k,v in pairs(extra or {})do f[k]=v end;return issue("preview",f) end
r=paint("NCPD");assert(not r.ok and r.text=="This tag is reserved for city services.")
r=paint("F.U.C.K");assert(not r.ok and r.text=="This tag is not allowed.","the banned words, through punctuation")
r=paint("way too long a tag");assert(not r.ok and r.text:find("characters",1,true))
r=paint("h\195\169llo");assert(not r.ok and r.text:find("characters",1,true),"outside the charset")
r=paint("Night Owl",{font="comic"});assert(not r.ok and r.text=="Choose a font.")
r=paint("Night Owl",{spot="roof"});assert(not r.ok and r.text=="Choose where to paint it.")
assert(world[car].w2.tag==nil)
r=paint("  Night   Owl ");assert(r.ok,r.text)
assert(same(world[car].w2.tag,{text="Night Owl",font="marker",color={r=255,g=204,b=0},spot="door_left"}),"spaces folded, color as {r,g,b}")
r=issue("save",{category="tag",text="Night Owl",font="marker",color="#FFCC00",spot="door_left"},"bank");assert(r.ok,r.text)
assert(M.get(1).bank==bank-P.tag and commits[#commits]=="vehicle_tag" and stored(hella,"tag").text=="Night Owl")
assert(r.confirmed.tag.color=="#FFCC00" and r.confirmed.tag.spot=="door_left")
r=issue("save",{category="tag",text="Night Owl",font="marker",color="#FFCC00",spot="door_left"},"bank")
assert(not r.ok and r.text=="This vehicle already wears that tag.")
close()
local setTag=V.setTag;V.setTag=nil;m=open(hella);assert(category(m,"tag")==nil,"the tag row needs setTag");close();V.setTag=setTag

-- 9. Park, restart, retrieve: every bought choice comes back on the car and on the page.
local function wears(id)
    local v=world[id]
    assert(v.record==HELLA.."_o77s1a2","stage 1 with engine sound 2: "..v.record)
    assert(v.w2.neonAnimation.mode=="strobe" and v.w2.lightColors.interior.b==214 and same(v.w2.stickers,{V1,V2}) and v.w2.tag.text=="Night Owl")
    assert(v.visual.profile=="hella_tt_2" and v.visual.neon and v.engineHold~=true)
end
store(hella);reboot()
car=retrieve(hella);wears(car)
m=open(hella)
assert(m.confirmed.engineSound=="s02" and same(m.confirmed.stickers,{V1,V2}) and m.confirmed.neonAnimation.mode=="strobe" and m.confirmed.neonAnimation.speed=="slow")
assert(m.confirmed.lightColors.interior=="#FF2BD6" and m.confirmed.tag.text=="Night Owl")
assert(same(category(m,"stickers").options.budget,{base=9,maximum=12}),"the bought stickers are not counted twice")
close()

-- 10. A server build without the wave 2 natives (a rollback): the car is delivered without
-- them, the row keeps them, and a later build puts them back.
store(hella);wave2(false);reboot()
car=retrieve(hella)
assert(world[car].record==HELLA.."_o77s1" and logged("keeps studio choices this server build cannot put on it dormant"),"delivered on its stage, the rest kept")
autosave()
assert(stored(hella,"engineSound")=="s02" and same(stored(hella,"stickers"),{V1,V2}) and stored(hella,"tag").text=="Night Owl","an autosave keeps them")
m=open(hella)
assert(category(m,"engineSound").reason==C.unsupported.native and category(m,"tag")==nil)
r=issue("save",{category="lights",color="#00E5FF"},"bank");assert(r.ok,r.text)
assert(stored(hella,"engineSound")=="s02" and stored(hella,"neonAnimation").mode=="strobe","another purchase keeps them")
close();store(hella);wave2(true);reboot()
car=retrieve(hella);wears(car)
close()

-- 11. A full sticker catalogue still fits the client's caps.
local full={};for i=1,60 do full[i]={id=("st.hella.crew_%02d"):format(i),label=("Crew sticker %02d, long label"):format(i),group=("Crew %d"):format(i%6),model=HELLA,decals=1+i%3} end
local saveStickers=STICKERS;STICKERS=full
m=open(hella);assert(#category(m,"stickers").options.stickers==60)
close();STICKERS=saveStickers

print(("customization wave 2 (%s keys): greying, neon animation, lamp colors, engine sound (rebuild, cooldown, engine hold, stage), stickers (budget, livery guard, per-sticker price), tag, previews never stored, park+restart+retrieve, a build without the natives passed; largest category %d JSON values"):format(WHERE,maxCategoryValues))
return true
