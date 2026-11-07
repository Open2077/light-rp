-- Auto Studio phase 2: livery, rims, body kit, neon, plate, windows and performance on the
-- real economy + inventory + garage + customization modules. The native mock follows
-- the server contract (docs/vehicle-visual-contract.md): registerParts / listParts /
-- setParts / setWheels / getVisual / setPaintProfile / setNeon / setWindowTint / respawnAs, a complete
-- `visual` in setProperties, unknown property keys refused, repaints clear the livery.
dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua")
dofile("server/config/garages.lua"); dofile("server/config/dealerships.lua")
dofile("server/config/vehicle_kit.lua");dofile("server/config/vehicle_kit_trims.lua");dofile("server/config/vehicle_kit_player_rims.lua")
local KIT,TRIMS,PLAYER=LightRpVehicleKit,LightRpVehicleKitTrims,LightRpVehicleKitPlayerRims
-- A rim fit as generated: the dealer table's, else the player vehicles' (vehicle_kit_player_rims.lua).
local function rimSource(id,record) return KIT.rims.parts[id].fit[record] or PLAYER.fit[record] end
local function noop() end
local tick, uid = 1000, 0
local failDb, yieldDb = false, false
local owner = {identifier="kit-test",key="default",status="active"}
local walletRow = {account_number="AAA-KIT",owner_name="Test",cash=50000,bank=1000000}
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
    if yieldDb then coroutine.yield("transaction") end
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

-- Natives ---------------------------------------------------------------------------
local NS="op77_lightrp:"
local HELLA="Vehicle.v_standard2_archer_hella_player"
local world,vid,events,rpc,bags={},100,{},{},{}
local calls={registerParts=0,respawnAs=0,setPaint=0,create={}}
local catalogue,b2,b3,b4,stagesOnServer,failRespawn,attachLimit,refusePart={},true,true,true,true,nil,16,{} -- b2: per-wheel fits, b3: per-appearance fits, b4: carried parts
local packs={lightrp_vk_rims="running",lightrp_vk_body="running",lightrp_vehicle_stages="running",open77_vehicle_tint="running"}
GetResourceState=function(name) return packs[name] or "missing" end
GetCurrentResourceName=function() return "op77_lightrp" end
local function base(record) return (tostring(record):gsub("_o77s%d+$","")) end
local profiles={[HELLA]={{id="hella_tt_1",main={r=200,g=20,b=20},sec={r=10,g=10,b=10},appearances={"a"},hasPattern=false},
    {id="hella_tt_2",appearances={"b"},hasPattern=true}}}
local function known(record)
    local b,ok=base(record),false
    for _,v in ipairs(LightRpConfig.vehicles.catalog)do if v.record==b then ok=true end end
    return ok and (record==b or (stagesOnServer and record:match("_o77s[1-3]$")~=nil))
end
local function rgb(v)if type(v)=="table"then return {r=v.r or v[1],g=v.g or v[2],b=v.b or v[3]} end;return{r=tonumber(v:sub(2,3),16),g=tonumber(v:sub(4,5),16),b=tonumber(v:sub(6,7),16)}end
local function fitFor(part,record) return part.fit[record] or part.fit[base(record)] end
local function qualify(id) return id:find(":",1,true) and id or NS..id end
local function view(v,rev)
    local x=v.visual;local out={profile=x.profile,neon=clone(x.neon),parts=clone(x.parts),wheels=clone(x.wheels),tint=x.tint}
    if rev then out.rev=x.rev end;return out
end
local function bump(v) v.visual.rev=(v.visual.rev or 0)+1 end
local function choose(record,id,value)
    local part=catalogue[id]
    if not part then return nil,"unknown_part" end
    if not fitFor(part,record) then return nil,"part_not_for_model" end
    if type(value)~="string" then return nil,"variant_required" end
    if not part.variants[value] then return nil,"unknown_variant" end
    return part
end
local function profileOk(record,profile) for _,p in ipairs(profiles[base(record)] or {})do if p.id==profile then return true end end end
local function neonOf(spec) return {enabled=spec.enabled~=false,color=rgb(spec.color),intensity=spec.intensity or 600,radius=spec.radius or 3,layout="auto"} end
local ENTRY={kind=1,label=1,slot=1,carrier=1,modType=1,variants=1,fit=1}
local FIT={slot=1,carrier=1,offset=1,rotation=1,scale=1,hide=1,show=1,wheels=1}
local PROPS={version=1,record=1,health=1,paint=1,appearance=1,visual=1}
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
    calls.create[#calls.create+1]=p.record
    vid=vid+1;world[vid]={id=vid,record=p.record,position=p.position,bucket=p.bucket,health=.8,speed=0,occupants={},
    paint={applied=false},appearance=p.appearance or "",visual={parts={},rev=0}};return vid end
V.getProperties=function(id)local v=world[id];if v then return{version=1,record=v.record,health=v.health,paint=clone(v.paint),appearance=v.appearance,visual=view(v)}end end
V.setProperties=function(id,p)
    for k in pairs(p)do if not PROPS[k] then return false,"unsupported_property:"..k end end
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if p.record~=nil and p.record~=v.record then return false,"record_mismatch" end
    local visual
    if p.visual~=nil then -- complete: an absent field means none; committed last
        local x=p.visual
        if x.profile~=nil and not profileOk(v.record,x.profile) then return false,"invalid_profile" end
        if x.tint~=nil and (math.type(x.tint)~="integer" or x.tint<0 or x.tint>3) then return false,"invalid_tint" end
        visual={profile=x.profile,neon=x.neon and neonOf(x.neon),parts={},tint=x.tint~=0 and x.tint or nil,rev=(v.visual.rev or 0)+1}
        for pid,value in pairs(x.parts or {})do local ok,why=choose(v.record,pid,value);if not ok then return false,why end;visual.parts[pid]=value end
        if x.wheels then
            local ok,why=choose(v.record,x.wheels.rim,x.wheels.variant);if not ok then return false,why end
            visual.parts[x.wheels.rim]=x.wheels.variant;visual.wheels=clone(x.wheels)
        end
    end
    local repaint=p.paint and (p.paint.applied~=v.paint.applied)
    if p.paint then v.paint=clone(p.paint) end;v.health=p.health or v.health
    if (p.appearance or "")~=(v.appearance or "") then v.appearance=p.appearance or "" end
    if visual then v.visual=visual elseif repaint then v.visual.profile=nil end
    return true end
V.setEngine=function()return true end
V.isLocked=function()return false end
V.setPaint=function(id,p)calls.setPaint=calls.setPaint+1;local v=world[id];if not v then return false,"vehicle_not_found" end
    v.paint={applied=true,primary=rgb(p.primary),secondary=rgb(p.secondary),lightsHue=v.paint.lightsHue};v.visual.profile=nil;return true end
V.resetPaint=function(id)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint={applied=false};v.visual.profile=nil;return true end
V.setLightsHue=function(id,hue)local v=world[id];if not v then return false,"vehicle_not_found" end;v.paint.lightsHue=hue;return true end
V.setHeadlightColor=function(id)local v=world[id];v.paint.lightsHue=.5;return true end
V.clearLightsHue=function(id)return V.setLightsHue(id,nil)end
V.getLightsHue=function(id)local v=world[id];return v and v.paint.lightsHue end
V.getAppearance=function(id)local v=world[id];return v and (v.appearance or "") end
V.setAppearance=function(id,name)local v=world[id];v.appearance=name or "";return true end
V.remove=function(id)world[id]=nil;for _,fn in ipairs(events.onVehicleRemoved or{})do fn(tostring(id),"test")end;return true end
-- The Lua->JSON marshaller of registerParts (LuaResourceRuntime ReadLuaValue): 4096 values,
-- depth 16, else invalid_part_catalogue.
local function marshalled(v,depth,count) count=count or {n=0};depth=depth or 0
    count.n=count.n+1;if count.n>4096 or depth>16 then return false end
    if type(v)=="table" then for _,x in pairs(v)do if not marshalled(x,depth+1,count) then return false end end end
    return true,count.n end
local largestCall=0
local function slotName(s) return type(s)=="string" and #s<=64 and s:match("^[A-Za-z0-9_%-]*$")~=nil end
local APPEARANCE_FIT={offset=1,rotation=1,scale=1,wheels=1,hide=1,show=1}
V.registerParts=function(cat)
    calls.registerParts=calls.registerParts+1
    local fits,size=marshalled(cat);if not fits then return false,"invalid_part_catalogue" end
    largestCall=math.max(largestCall,size)
    local n=0
    for id,e in pairs(cat)do
        n=n+1
        if refusePart[id] then return false,"invalid_part:"..id..".variants" end
        for k in pairs(e)do if not ENTRY[k] then return false,"invalid_part:"..id.."."..k end end
        if e.carrier~=nil and (not b4 or e.kind~="part" or not slotName(e.carrier) or e.carrier=="") then return false,"invalid_part:"..id..".carrier" end
        for _,fit in pairs(e.fit)do for k,x in pairs(fit)do
            if k=="carrier" then
                if not b4 or e.kind~="part" or not (x==false or slotName(x)) then return false,"invalid_part:"..id..".fit.carrier" end
            elseif k=="appearances" and b3 then -- per-appearance overrides: no slot, 32 at most
                local count=0
                for name,o in pairs(x)do
                    count=count+1
                    if type(name)~="string" or type(o)~="table" or count>32 then return false,"invalid_part:"..id..".fit.appearances" end
                    for key in pairs(o)do
                        if not APPEARANCE_FIT[key] or (key=="wheels" and (not b2 or e.kind~="rim")) then return false,"invalid_part:"..id..".fit.appearances."..name.."."..key end
                    end
                end
            elseif not FIT[k] or (k=="wheels" and (not b2 or e.kind~="rim")) then return false,"invalid_part:"..id..".fit."..k end
        end end
    end
    assert(n==1,"one part per registerParts call (the Lua->JSON marshaller caps one call)")
    for id,e in pairs(cat)do catalogue[NS..id]=clone(e) end
    return true end
V.listParts=function(x)
    local record=type(x)=="string" and x or (world[x] and world[x].record)
    if not record then return nil,"vehicle_not_found" end
    local out={}
    for id,p in pairs(catalogue)do if fitFor(p,record) then out[#out+1]={id=id,kind=p.kind,label=p.label,slot=p.slot,variants=clone(p.variants)} end end
    table.sort(out,function(a,b)return a.id<b.id end);return out end
V.listPaintProfiles=function(x) local record=type(x)=="string" and x or (world[x] and world[x].record);return clone(profiles[base(record or "")] or {}) end
V.getVisual=function(id)local v=world[id];if not v then return nil,"vehicle_not_found" end;return view(v,true)end
V.setPaintProfile=function(id,profile)
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if profile~=nil and not profileOk(v.record,profile) then return false,"invalid_profile" end
    v.visual.profile=profile;bump(v);return true end
V.setNeon=function(id,spec)local v=world[id];if not v then return false,"vehicle_not_found" end;v.visual.neon=neonOf(spec);bump(v);return true end
V.clearNeon=function(id)local v=world[id];v.visual.neon=nil;bump(v);return true end
V.setWindowTint=function(id,level)local v=world[id];if not v then return false,"vehicle_not_found" end
    if level~=nil and (math.type(level)~="integer" or level<0 or level>3) then return false,"invalid_tint" end
    v.visual.tint=level~=0 and level or nil;bump(v);return true end
local function dropRims(v) for pid in pairs(v.visual.parts)do if catalogue[pid] and catalogue[pid].kind=="rim" then v.visual.parts[pid]=nil end end end
V.setWheels=function(id,w)
    local v=world[id];if not v then return false,"vehicle_not_found" end
    if w==nil then dropRims(v);v.visual.wheels=nil;bump(v);return true end
    local rim=qualify(w.rim);local part,why=choose(v.record,rim,w.variant);if not part then return false,why end
    if part.kind~="rim" then return false,"not_a_rim" end
    dropRims(v);v.visual.parts[rim]=w.variant;v.visual.wheels={rim=rim,variant=w.variant};bump(v);return true end
V.setParts=function(id,map)
    local v=world[id];if not v then return false,"vehicle_not_found" end
    local parts=clone(v.visual.parts)
    for pid,value in pairs(map)do
        pid=qualify(pid)
        if value==false then parts[pid]=nil
        elseif v.visual.parts[pid]~=value then local ok,why=choose(v.record,pid,value);if not ok then return false,why end;parts[pid]=value end
    end
    local count=0;for _ in pairs(parts)do count=count+1 end
    if count>attachLimit then return false,"attach_limit" end
    v.visual.parts=parts;bump(v);return true end
V.respawnAs=function(id,record)
    local v=world[id];if not v then return nil,"vehicle_not_found" end
    if failRespawn then return nil,failRespawn end
    if not known(record) then return nil,"invalid_record" end
    calls.respawnAs=calls.respawnAs+1;v.record=record;return id end
RegisterNetEvent=function(name,fn)rpc[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end;Wait=function() coroutine.yield() end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Test" end
AddEventHandler=function(name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end;TriggerClientEvent=function(_,_,p) messages[#messages+1]=p end

-- The manifest: Light RP declares exactly what a change needs, and loads the kit.
local manifest=assert(io.open("open77.lua","rb")):read("a")
assert(manifest:find('"world.vehicles"',1,true) and manifest:find('"world.vehicles.appearance"',1,true),"a change needs world.vehicles and world.vehicles.appearance")
local kitAt,garageAt=manifest:find('server/config/vehicle_kit.lua',1,true),manifest:find('server/modules/garages.lua',1,true)
assert(kitAt and garageAt and kitAt<garageAt,"the kit catalogue loads before the garage")
local trimsAt,studioAt=manifest:find('server/config/vehicle_kit_trims.lua',1,true),manifest:find('server/modules/vehicle_customization.lua',1,true)
assert(trimsAt and studioAt and kitAt<trimsAt and trimsAt<studioAt,"the trims' hide lists load before the studio registers the kit")
local playerAt=manifest:find('server/config/vehicle_kit_player_rims.lua',1,true)
assert(playerAt and kitAt<playerAt and playerAt<studioAt,"the player vehicles' rim fits load before the studio registers the kit")

-- The generated catalogue honours the registerParts contract (VehiclePartCatalogue).
-- Carried parts (contract section 5): wings and rear louvers ride the trunk lid's slot,
-- hood scoop and vents the hood's, all through the kit's one `carriers` table; a roof
-- wing rides nothing. A fit's `carrier = false` (no lid under the part on that car, from
-- the fit table's evidence.lid) keeps it on its slot.
assert(KIT.body.carriers.trunk=="trunk_a" and KIT.body.carriers.hood=="hood_a","the carrier slots, in one place")
local carrierOf
do
    local panels,groupOf={spoiler="trunk",louver="trunk",hood="hood"},{}
    for _,g in ipairs(KIT.body.groups)do for _,id in ipairs(g.parts)do groupOf[id]=g.id end end
    carrierOf=function(section,id)
        local panel=section=="body" and id~="wing_roof" and panels[groupOf[id]]
        return panel and KIT.body.carriers[panel] or nil
    end
end
local function idOk(s) return type(s)=="string" and #s<=64 and s:match("^[A-Za-z0-9_.%-]+$")~=nil end
local function vecOk(t,low,high) if t==nil then return true end;if #t~=3 then return false end;for _,x in ipairs(t)do if type(x)~="number" or x<low or x>high then return false end end;return true end
for _,section in ipairs({"rims","body"})do
    for id,e in pairs(KIT[section].parts)do
        assert(idOk(id) and type(e.label)=="string" and #e.label<=64,"part id/label: "..id)
        assert((section=="rims" and e.kind=="rim" and e.slot==nil) or (section=="body" and e.kind=="part" and e.slot=="Base"),"kind/slot: "..id)
        assert(e.carrier==carrierOf(section,id),"carrier: "..id.." rides "..tostring(e.carrier))
        local n=0;for v,model in pairs(e.variants)do n=n+1;assert(idOk(v) and model:sub(1,6+#KIT[section].pack)=="asset:"..KIT[section].pack,"variant: "..id.."."..v)end
        assert(n>=1 and n<=32,"variants: "..id)
        local fits=0
        for record,fit in pairs(e.fit)do
            fits=fits+1
            for k in pairs(fit)do assert(FIT[k] and k~="slot" and k~="show","fit key "..k.." of "..id) end
            assert(fit.carrier==nil or (e.carrier and (fit.carrier==false or slotName(fit.carrier) and fit.carrier~="")),"fit carrier: "..id.." "..record)
            assert(vecOk(fit.offset,-10,10) and vecOk(fit.rotation,-360,360) and vecOk(fit.scale,.01,10),"fit vectors: "..id.." "..record)
            assert(#(fit.hide or {})<=64,"hide list: "..id)
            for _,name in ipairs(fit.hide or {})do assert(type(name)=="string" and #name<=128) end
            if fit.wheels then
                assert(section=="rims" and #fit.wheels>=1 and #fit.wheels<=8,"wheels: "..id.." "..record)
                local seen={}
                for _,w in ipairs(fit.wheels)do
                    assert(type(w.slot)=="string" and #w.slot<=59 and w.slot:match("^[A-Za-z0-9_]+$") and not seen[w.slot],"wheel slot: "..record)
                    seen[w.slot]=true
                    assert(vecOk(w.offset,-10,10) and vecOk(w.rotation,-360,360) and vecOk(w.scale,.01,10))
                    for k in pairs(w)do assert(k=="slot" or k=="offset" or k=="rotation" or k=="scale") end
                end
            end
        end
        assert(fits>=1 and fits<=512,"fits: "..id)
    end
end
assert(#KIT.rims.order==18 and #KIT.body.groups==9,"18 rims, 9 body groups")
local rim=KIT.rims.parts.rim_classic.fit
local merrimac,apollo=rim["Vehicle.v_standard25_thorton_merrimac_player"],rim["Vehicle.v_sportbike3_brennan_apollo_player"]
assert(merrimac and #merrimac.wheels==6,"Merrimac: the middle axle is listed")
assert(apollo and #apollo.wheels==2 and apollo.wheels[1].slot=="wheel_front_rot_set","Apollo: its own wheel slots")
assert(KIT.rims.excluded["Vehicle.v_sportbike1_yaiba_kusanagi_player"] and not rim["Vehicle.v_sportbike1_yaiba_kusanagi_player"],"Kusanagi is excluded")
-- The other vanilla player vehicles (generated vehicle_kit_player_rims.lua): never a dealer
-- record, the same fit contract, `appearances` only with the platform's override keys.
local function wheelsOk(list,label)
    assert(#list>=1 and #list<=8,"wheels: "..label)
    local seen={}
    for _,w in ipairs(list)do
        assert(type(w.slot)=="string" and #w.slot<=59 and w.slot:match("^[A-Za-z0-9_]+$") and not seen[w.slot],"wheel slot: "..label)
        seen[w.slot]=true
        assert(vecOk(w.offset,-10,10) and vecOk(w.rotation,-360,360) and vecOk(w.scale,.01,10),"wheel vectors: "..label)
        for k in pairs(w)do assert(k=="slot" or k=="offset" or k=="rotation" or k=="scale","wheel key "..k..": "..label) end
    end
end
local playerFits=0
for record,fit in pairs(PLAYER.fit)do
    playerFits=playerFits+1
    assert(record:match("^Vehicle%.[%w_]+$") and record:find("player",1,true),"a vanilla player record: "..record)
    assert(rim[record]==nil and not KIT.rims.excluded[record],"never a dealer record: "..record)
    for k in pairs(fit)do assert(k=="offset" or k=="scale" or k=="wheels" or k=="hide" or k=="appearances","player fit key "..k..": "..record) end
    assert(vecOk(fit.offset,-10,10) and vecOk(fit.scale,.01,10) and #fit.hide>=1 and #fit.hide<=64,"player fit: "..record)
    for _,name in ipairs(fit.hide)do assert(type(name)=="string" and #name>0 and #name<=128,"hide name: "..record) end
    if fit.wheels then wheelsOk(fit.wheels,record) end
    local n=0
    for app,o in pairs(fit.appearances or {})do
        n=n+1
        for k in pairs(o)do assert(APPEARANCE_FIT[k],"appearance field "..k..": "..record.." "..app) end
        assert(vecOk(o.offset,-10,10) and vecOk(o.scale,.01,10) and type(o.hide)=="table" and #o.hide<=64,"appearance entry: "..app)
        if fit.wheels then assert(o.wheels and #o.wheels==#fit.wheels,"a record with a wheels list: the entry lists every wheel ("..app..")") end
        if o.wheels then wheelsOk(o.wheels,record.." "..app) end
    end
    assert(n<=32,"32 appearance entries per record at most: "..record)
end
assert(playerFits>=55,"the player vehicles are fitted ("..playerFits..")")
for record in pairs(PLAYER.excluded)do assert(not PLAYER.fit[record],"excluded and fitted: "..record) end
-- Quest variants (Vehicle.q<digits>_*) are out of the extension (owner, 2026-11-07): named nowhere.
for _,t in ipairs({PLAYER.fit,PLAYER.excluded})do
    for record in pairs(t)do assert(not record:match("^Vehicle%.q%d+_"),"a quest variant is out of the extension: "..record) end
end
assert(not PLAYER.fit["Vehicle.q000_hym_player_car"] and not PLAYER.fit["Vehicle.q304_songbird_escape_player"],"the two 2.50 quest variants take no rims")
local TYPE66,SHION="Vehicle.v_sport2_quadra_type66_player","Vehicle.v_sport2_mizutani_shion_player"
local ARCH,APOLLO_NOMAD="Vehicle.v_sportbike2_arch_player","Vehicle.v_sportbike3_brennan_apollo_nomad_player"
assert(PLAYER.fit[TYPE66] and PLAYER.fit[SHION],"the staff-only Type-66 and Shion take rims")
for _,record in ipairs({"Vehicle.v_sportbike1_yaiba_kusanagi_player_02","Vehicle.v_sportbike1_yaiba_kusanagi_tyger_player"})do
    assert(PLAYER.excluded[record] and PLAYER.excluded[record]:find("hubless",1,true),"the Kusanagi body stays without rims: "..record)
end
do -- motorcycles: one wheel per stock slot, each on the slot its stock rim binds to
    local arch,nomad=assert(PLAYER.fit[ARCH],"Arch Nemesis fitted"),assert(PLAYER.fit[APOLLO_NOMAD],"Apollo Nomad fitted")
    assert(#arch.wheels==2 and arch.wheels[1].slot=="wheel_front" and arch.wheels[2].slot=="wheel_back","Arch Nemesis: front and back wheels")
    assert(#nomad.wheels==2 and nomad.wheels[1].slot=="wheel_front_rot_set" and nomad.wheels[2].slot=="axle_back_wheel","Apollo Nomad: the dealer Apollo's wheel slots")
    assert(arch.scale[1]~=arch.scale[2] and nomad.scale[1]~=nomad.scale[2],"motorcycle rims scale along the axle to the stock width")
end
for _,group in ipairs(KIT.body.groups)do for _,id in ipairs(group.parts)do assert(KIT.body.parts[id],"group part exists: "..id) end end
do
    local body=KIT.body.parts
    assert(body.wing_street.carrier=="trunk_a" and body.wing_street.fit[HELLA].carrier==nil,"Hella: the wing rides the trunk lid")
    assert(body.wing_street.fit["Vehicle.v_standard2_archer_quartz_player"].carrier==false,"Quartz: no lid under the wing, it stays on the body")
    assert(body.louver_rear.carrier=="trunk_a" and body.louver_rear.fit["Vehicle.v_standard2_chevalier_thrax_player"].carrier==false,"louvers ride the lid, not on the Thrax's fixed glass")
    assert(body.hood_scoop.carrier=="hood_a" and body.hood_vents.carrier=="hood_a","hood parts ride the hood")
    assert(body.wing_roof.carrier==nil and body.lip_splitter.carrier==nil and body.roof_rack.carrier==nil,"roof, lip and rack ride nothing")
    for _,part in pairs(body)do if not part.carrier then for _,fit in pairs(part.fit)do assert(fit.carrier==nil) end end end
end

dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
local before=#threads;dofile("server/modules/garages.lua");local garageWorker=threads[before+1]
local M,G=LightRP.money,LightRP.garage
LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
dofile("shared/vehicle_customization.lua");dofile("server/config/vehicle_customization.lua")
local P,C=LightRpCustomizationPricing,LightRpVehicleCustomization
assert(C.windows.enabled==true,"window tint ships open: the glass renders (W1 resolved)")
-- the closed state is checked below
dofile("server/modules/vehicle_customization.lua")
local Custom=LightRP.vehicleCustomization
local NET="op77_lightrp:customization"
local kitParts=#KIT.rims.order;for _ in pairs(KIT.body.parts)do kitParts=kitParts+1 end
assert(kitParts==48 and calls.registerParts==kitParts and catalogue[NS.."rim_classic"] and catalogue[NS.."bull_bar"],"one registerParts call per kit part")
assert(#catalogue[NS.."rim_classic"].fit["Vehicle.v_standard25_thorton_merrimac_player"].wheels==6,"per-wheel fits reach the server")
assert(catalogue[NS.."wing_street"].carrier=="trunk_a" and catalogue[NS.."wing_street"].fit["Vehicle.v_standard2_archer_quartz_player"].carrier==false,"carriers reach the server")

-- Curated trims (server/config/vehicle_kit_trims.lua): every sold trim of a rim-fitted
-- model has its rim fit override in the platform's fit.appearances contract: offset,
-- rotation, scale, wheels, hide, show (never slot), 32 per record fit at most; an entry
-- replaces only the fields it gives, `wheels` the whole list.
local function has(list,name) for _,n in ipairs(list or {})do if n==name then return true end end end
local function same(a,b)
    if type(a)~="table" or type(b)~="table" then return a==b end
    for k,v in pairs(a)do if not same(v,b[k]) then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true end
local function resolve(fit,appearance) -- the platform's resolution of a record fit on an appearance
    local o=fit.appearances and fit.appearances[appearance];if not o then return fit end
    local out={};for k,v in pairs(fit)do if k~="appearances" then out[k]=v end end
    for k,v in pairs(o)do out[k]=v end;return out end
local CAR_WHEELS={{slot="wheel_front_left"},{slot="wheel_front_right"},{slot="wheel_back_left"},{slot="wheel_back_right"}}
local function wheelOf(fit,slot) for _,w in ipairs(fit.wheels or CAR_WHEELS)do if w.slot==slot then return {offset=w.offset or fit.offset,scale=w.scale or fit.scale} end end end
local recordOf={};for _,v in ipairs(LightRpConfig.vehicles.catalog)do recordOf[v.key]=v.record end
local function sold(record,app) for key,r in pairs(recordOf)do if r==record then for _,t in ipairs(C.trims[key] or {})do if t.id==app then return true end end end end end
local rimFits=KIT.rims.parts.rim_classic.fit
for key,list in pairs(C.trims)do
    local record=assert(recordOf[key],"trim model in the catalogue: "..key)
    for _,trim in ipairs(list)do
        local o=(TRIMS.rims[record] or {})[trim.id]
        if rimFits[record] then assert(type(o)=="table" and type(o.hide)=="table" and #o.hide>=2,"no rim fit override for the sold trim "..trim.id)
        else assert(o==nil,"no rim fit, no trim override: "..trim.id) end
    end
end
local overrides,resized=0,0
for record,apps in pairs(TRIMS.rims)do
    local base=assert(rimFits[record],"trim overrides name a rim-fitted record: "..record)
    local slots,all={},0;for _,w in ipairs(base.wheels or CAR_WHEELS)do slots[w.slot]=true;all=all+1 end
    local count=0
    for app,o in pairs(apps)do
        count=count+1;overrides=overrides+1
        assert(sold(record,app),"an overridden appearance is a sold trim: "..app)
        for k in pairs(o)do assert(APPEARANCE_FIT[k],"appearance field "..k.." of "..app.." (no slot inside an appearance)") end
        assert(vecOk(o.offset,-10,10) and vecOk(o.rotation,-360,360) and vecOk(o.scale,.01,10),"override vectors: "..app)
        assert(#o.hide<=64,"hide cap: "..app)
        for _,name in ipairs(o.hide)do assert(type(name)=="string" and #name>0 and #name<=128,"hide name: "..app) end
        if o.wheels then
            local seen={}
            for _,w in ipairs(o.wheels)do
                assert(slots[w.slot] and not seen[w.slot],"override wheel slot: "..app.." "..tostring(w.slot));seen[w.slot]=true
                assert(w.offset and w.scale and vecOk(w.offset,-10,10) and vecOk(w.rotation,-360,360) and vecOk(w.scale,.01,10),"every override wheel carries its own offset and scale: "..app)
                for k in pairs(w)do assert(k=="slot" or k=="offset" or k=="rotation" or k=="scale") end
            end
            assert(#o.wheels==all,"an override's wheels list names every wheel of the record: "..app)
        elseif o.offset or o.scale then
            assert(base.wheels==nil,"a record with a wheels list needs the override's own (its entries carry their own vectors): "..app)
        end
        if o.offset or o.scale or o.wheels then resized=resized+1 end
    end
    assert(count<=32,"32 appearance overrides per record fit at most: "..record)
end
assert(overrides==30 and resized==26,("30 sold trims with a rim fit, 26 refitted (%d, %d)"):format(overrides,resized))
for id,records in pairs(TRIMS.body)do
    assert(KIT.body.parts[id],"a body trim list names a kit part: "..id)
    for record,apps in pairs(records)do
        assert(KIT.body.parts[id].fit[record],"a body trim list names a fitted record: "..id.." "..record)
        for app in pairs(apps)do assert(sold(record,app),"sold trim: "..app) end
    end
end
-- Registered on a server with per-appearance fits: the record fit as generated, the
-- overrides beside it; body parts merge their trims' extra names into the record fit.
local bodyIds={};for id in pairs(KIT.body.parts)do bodyIds[#bodyIds+1]=id end
local function checkBodyHides()
    for _,id in ipairs(bodyIds)do
        for record,fit in pairs(assert(catalogue[NS..id],"registered: "..id).fit)do
            assert(fit.appearances==nil,"body parts carry no appearance overrides: "..id)
            local seen={}
            for _,n in ipairs(fit.hide or {})do assert(not seen[n],"hide names deduplicated: "..id.." "..n);seen[n]=true end
            for _,n in ipairs(KIT.body.parts[id].fit[record].hide or {})do assert(seen[n],"the default appearance's names are kept: "..id.." "..record) end
            for app,names in pairs((TRIMS.body[id] or {})[record] or {})do for _,n in ipairs(names)do assert(seen[n],id.." on "..app.." hides "..n) end end
        end
    end
    assert(catalogue[NS.."roof_rack"].fit["Vehicle.v_standard2_thorton_colby_player"]==nil,"E2b: the basket no longer fits the Colby")
end
for _,id in ipairs(KIT.rims.order)do
    local players=0
    for record,fit in pairs(catalogue[NS..id].fit)do
        local src=assert(rimSource(id,record),"a registered record is generated: "..id.." "..record)
        assert(same(fit.hide,src.hide),"the record fit keeps its own hide list: "..id.." "..record)
        assert(same(fit.appearances,TRIMS.rims[record] or src.appearances),"the trims' overrides reach the server: "..id.." "..record)
        if not KIT.rims.parts[id].fit[record] then players=players+1;assert(same(fit,PLAYER.fit[record]),"a player vehicle's fit as generated: "..record) end
    end
    assert(players==playerFits,"every rim fits every player vehicle: "..id)
end
checkBodyHides()
local COLBY="Vehicle.v_standard2_thorton_colby_player"
local dish=catalogue[NS.."rim_dish"].fit
local suburbanFit=resolve(dish[HELLA],"archer_hella__basic_suburban_1")
assert(suburbanFit.offset[1]==-0.0062 and wheelOf(suburbanFit,"wheel_back_left").offset[1]==-0.038 and wheelOf(suburbanFit,"wheel_front_right").scale[2]==0.9846,"Hella Suburban: its own rim depth and size")
assert(same(suburbanFit.hide,{"wheel_bl_01","wheel_br_01","wheel_fl_01","wheel_fr_01"}),"Hella Suburban: only its own stock rims hidden")
local stockFit=resolve(dish[HELLA],"archer_hella__basic_player_01")
assert(stockFit==dish[HELLA] and wheelOf(stockFit,"wheel_back_left").offset[1]==-0.143 and #stockFit.hide==4,"the stock body wears the record fit")
local urbanFit=resolve(dish[COLBY],"thorton_colby__basic_urban_01")
assert(urbanFit.offset[1]==0.0392 and same(urbanFit.hide,{"wheel_bl_04","wheel_br_04","wheel_fl_04","wheel_fr_04"}),"a trim within tolerance: the record fit, its own hide list")
assert(largestCall<=4096,"every registerParts call fits the marshaller")
-- The heaviest car of every record and appearance (the longest rim on every wheel, the
-- heaviest part of each body group, livery, neon, plate) still fits the visual bag:
-- VehicleCustomizationService.FitsBag, 4 KiB and 256 JSON values; an attachment is 16
-- values (17 with a carrier, `,"carrier":"<slot>"`), the rest 18, plus one per hide name.
-- Bytes over-estimated (12 per number).
local function longest(part) local n=0;for _,model in pairs(part.variants)do n=math.max(n,#model)end;return n end
local function worstBag(record,appearance)
    local bytes,values,hide=300,18,{}
    local function group(ids,rim)
        local most,count=0,0
        for _,id in ipairs(ids)do
            local part=catalogue[NS..id];local fit=part and part.fit[record] and resolve(part.fit[record],appearance)
            if fit then
                for _,n in ipairs(fit.hide or {})do if not hide[n] then hide[n]=true;bytes=bytes+#n+3;values=values+1 end end
                local b,v=0,0
                local carrier=fit.carrier;if carrier==nil then carrier=part.carrier end
                for _,w in ipairs(rim and (fit.wheels or CAR_WHEELS) or {{slot=fit.slot or part.slot}})do
                    b=b+80+#(rim and "rims."..w.slot or NS..id)+longest(part)+#w.slot+9*12;v=v+16
                    if carrier then b=b+13+#carrier;v=v+1 end
                end
                if b>most then most,count=b,v end
            end
        end
        bytes,values=bytes+most,values+count
    end
    group(KIT.rims.order,true)
    for _,g in ipairs(KIT.body.groups)do group(g.parts,false) end
    return bytes,values
end
local records={};for _,section in ipairs({"rims","body"})do for _,e in pairs(KIT[section].parts)do for record in pairs(e.fit)do records[record]=true end end end
for record in pairs(PLAYER.fit)do records[record]=true end
local function checkBags(label)
    local heaviest,heaviestValues,where=0,0,""
    for record in pairs(records)do
        local appearances={""};for app in pairs(TRIMS.rims[record] or (PLAYER.fit[record] or {}).appearances or {})do appearances[#appearances+1]=app end
        for _,app in ipairs(appearances)do
            local b,v=worstBag(record,app)
            assert(b<=4096 and v<=256,("%s %s: the fullest kit overflows the visual bag (%d bytes, %d values)"):format(record,app,b,v))
            if v>heaviestValues then heaviest,heaviestValues,where=b,v,record..(app~="" and "#"..app or "") end
        end
    end
    print(("trim fits (%s): fullest kit %d values (cap 256), <= %d bytes (cap 4096), on %s"):format(label,heaviestValues,heaviest,where))
end
checkBags("per appearance")
print(("trim fits: largest registerParts call %d values (marshaller cap 4096)"):format(largestCall))

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
    assert(type(raw.categoriesJson)=="table" and raw.categories==nil,"the category tree travels as JSON text, one per category")
    local m={};for k,v in pairs(raw)do m[k]=v end;m.categories={}
    for i,text in ipairs(raw.categoriesJson)do
        assert(type(text)=="string");m.categories[i]=json.decode(text)
        -- the client's json.decode caps one text at 1024 values (every table and leaf)
        local function count(v)if type(v)~="table"then return 1 end;local n=1;for _,x in pairs(v)do n=n+count(x)end;return n end
        local values=count(m.categories[i]);assert(values<=1000,("category %s is %d JSON values, over the client's cap"):format(tostring(m.categories[i].id),values))
        maxCategoryValues=math.max(maxCategoryValues or 0,values)
    end;return m
end
local function issue(operation,fields,pay)
    request=request+1;tick=tick+300
    local p={session=session,request=request,operation=operation,pay=pay}
    for k,v in pairs(fields)do p[k]=v end
    source=1;rpc[NET](p);return messages[#messages],p
end
local function close() source=1;rpc[NET]({session=session,operation="close"}) end
local function saved(rowId) return json.decode(owned[rowId].properties) end
local function category(m,id) for _,c in ipairs(m.categories)do if c.id==id then return c end end end
local function autosave() local saver=coroutine.create(garageWorker);for _=1,9 do assert(coroutine.resume(saver));tick=tick+2000 end end
local function reboot()
    world={};events={};threads={};catalogue={};LightRP.inventory=nil;calls.registerParts=0
    dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
    local at=#threads;dofile("server/modules/garages.lua");garageWorker=threads[at+1]
    M,G=LightRP.money,LightRP.garage
    LightRP.inventory.onCharacterLoaded(1,owner);M.onCharacterLoaded(1,owner);G.onDatabaseReady()
    dofile("server/modules/vehicle_customization.lua");Custom=LightRP.vehicleCustomization
end
local function bodyParts(v) local out={};for pid,value in pairs(world[v].visual.parts)do if catalogue[pid] and catalogue[pid].kind=="part" then out[pid]=value end end;return out end
local function count(t) local n=0;for _ in pairs(t)do n=n+1 end;return n end

-- 1. Offer: every category listed in page order, priced by the server.
local ok,hella=G.grant(1,"hella");assert(ok)
local car=retrieve(hella)
local m=open(hella)
-- The client's net event reader (scripting/src/ResourceHost.cpp, JsonReader) drops a whole
-- event deeper than 8 levels (the argument array is level 0) or over 1024 values: what the
-- studio sends must fit, or the page never opens ("dropped malformed network event payload").
local function shape(v,depth) depth=depth or 1
    if type(v)~="table" then return 1,depth end
    local nodes,deepest=1,depth
    for _,x in pairs(v)do local n,d=shape(x,depth+1);nodes=nodes+n;if d>deepest then deepest=d end end
    return nodes,deepest end
local function fitsClient(p,label) local nodes,depth=shape(p);nodes=nodes+1
    assert(depth<=8 and nodes<=1024,("%s exceeds the client event reader: depth %d (max 8), %d values (max 1024)"):format(label,depth,nodes)) end
fitsClient(messages[#messages],"the studio open message")
local order={};for _,c in ipairs(m.categories)do order[#order+1]=c.id end
assert(table.concat(order,",")=="paint,livery,rims,body,neon,neonAnimation,lights,lightColors,trim,plate,stickers,windows,performance,engineSound","page order: "..table.concat(order,","))
-- Wave 2 rows (tests/vehicle_customization_wave2_test.lua) are greyed without their natives;
-- the tag row is not listed at all without setTag.
for _,id in ipairs({"neonAnimation","lightColors","stickers","engineSound"})do assert(not category(m,id).available and category(m,id).reason,id.." greyed without its native") end
local windows=category(m,"windows")
assert(windows.available and not windows.soon and windows.pack=="open77_vehicle_tint" and #windows.options==3
    and windows.options[1].id=="light" and windows.options[3].id=="limo" and windows.options[3].level==3,"window tint offered, three levels")
for _,id in ipairs({"livery","rims","body","neon","plate","performance"})do assert(category(m,id).available,id.." offered on the Hella") end
assert(m.prices.livery==P.livery and m.prices.rims==P.rims and m.prices.neon==P.neon and m.prices.plate==P.plate and m.prices.windows==P.windows and P.windows>0)
local livery=category(m,"livery")
assert(#livery.options==2 and livery.options[1].id=="hella_tt_1" and livery.options[1].label=="Scheme 1" and livery.options[1].main=="#C81414","factory schemes from listPaintProfiles")
-- A livery a pack registered (registerPaintProfiles) follows the factory ones with its own name;
-- a registered row without a label is numbered among the factory schemes.
table.insert(profiles[HELLA],{id="Vehicle.o77_livery_taxi_hella",label="City Taxi",resource="lightrp_vk_liveries",main={r=240,g=200,b=20},hasPattern=true})
table.insert(profiles[HELLA],{id="Vehicle.o77_livery_plain_hella",resource="lightrp_vk_liveries",hasPattern=true})
close();m=open(hella);livery=category(m,"livery")
assert(#livery.options==4 and livery.options[2].label=="Scheme 2" and livery.options[3].label=="City Taxi"
    and livery.options[3].id=="Vehicle.o77_livery_taxi_hella" and livery.options[4].label=="Scheme 3","pack liveries carry their label")
table.remove(profiles[HELLA]);table.remove(profiles[HELLA]);close();m=open(hella)
local rims=category(m,"rims")
local hellaRims=0;for _,id in ipairs(KIT.rims.order)do if KIT.rims.parts[id].fit[HELLA] then hellaRims=hellaRims+1 end end
assert(hellaRims>=8 and #rims.options==hellaRims and rims.options[1].id=="rim_classic" and rims.options[1].label==KIT.rims.parts.rim_classic.label,"every rim, in catalogue order")
assert(rims.options[1].variants[1].id=="chrome" and rims.options[1].variants[1].label=="Chrome","finishes ordered and labelled")
local body=category(m,"body")
local spoiler=body.options[1]
assert(spoiler.id=="spoiler" and #spoiler.parts>=2,"the wing group offers several wings")
local second=body.options[2]
assert(second and second.id~="spoiler" and #second.parts>=1)
local perf=category(m,"performance")
assert(perf.options.current==0 and #perf.options.stages==4 and perf.options.stages[3].record==HELLA.."_o77s2" and perf.options.stages[3].price==P.performance.hella[2],"stages resolved by the stage resource")
assert(perf.options.removal==P.performanceRemoval)
assert(m.confirmed and m.confirmed.stage==0 and m.confirmed.plate=="" and m.confirmed.rim==nil and m.confirmed.windows==""
    and m.vehicle.visual==nil and m.vehicle.lightrp==nil,"confirmed view for the page")
local reply=issue("preview",{category="windows",tint=3});assert(not reply.ok and world[car].visual.tint==nil,"a raw level is refused: the page names a level id")
local bank=M.get(1).bank

-- 2. Livery: free preview on the factory paint layer, paid save, paint replaces it.
reply=issue("save",{category="paint",primary="#112233",secondary="#112233"},"bank");assert(reply.ok);bank=M.get(1).bank
reply=issue("preview",{category="livery",profile="other_scheme"});assert(not reply.ok and world[car].visual.profile==nil,"a scheme of another model is refused")
reply=issue("preview",{category="livery",profile="hella_tt_1"})
assert(reply.ok and world[car].visual.profile=="hella_tt_1" and world[car].paint.applied==false and M.get(1).bank==bank,"free livery preview on the factory layer")
autosave();assert(saved(hella).visual==nil or saved(hella).visual.profile==nil,"autosave keeps the confirmed look, never a livery preview")
failDb=true;reply=issue("save",{category="livery",profile="hella_tt_1"},"bank");failDb=false
assert(not reply.ok and world[car].visual.profile==nil and world[car].paint.applied and M.get(1).bank==bank,"DB failure rolls back the livery AND the paint it replaced")
issue("preview",{category="livery",profile="hella_tt_2"})
reply=issue("save",{category="livery",profile="hella_tt_1"},"bank")
assert(reply.ok and M.get(1).bank==bank-P.livery and commits[#commits]=="vehicle_livery" and reply.confirmed.profile=="hella_tt_1")
assert(saved(hella).visual.profile=="hella_tt_1" and saved(hella).paint.applied==false,"livery and factory layer persisted together")
reply=issue("save",{category="livery",profile="hella_tt_1"},"bank");assert(not reply.ok and M.get(1).bank==bank-P.livery,"unchanged livery refused")
reply=issue("save",{category="paint",primary="#FFCC00",secondary="#FFCC00"},"bank")
assert(reply.ok and world[car].visual.profile==nil and saved(hella).visual.profile==nil and saved(hella).paint.applied,"a paint purchase replaces the livery, on the car and in storage")
assert(reply.confirmed.profile=="")
bank=M.get(1).bank

-- 3. Rims: only offered rims and finishes, the server names the part.
local setWheels=0;local real=V.setWheels;V.setWheels=function(...)setWheels=setWheels+1;return real(...)end
for _,forged in ipairs({{rim="other_res:rim",variant="chrome"},{rim=NS.."rim_classic",variant="chrome"},{rim="rim_classic",variant="plaid"},{rim="rim_classic"}})do
    reply=issue("preview",{category="rims",rim=forged.rim,variant=forged.variant});assert(not reply.ok,"forged rim refused: "..tostring(forged.rim))
end
assert(setWheels==0,"no forged rim reaches setWheels")
reply=issue("preview",{category="rims",rim="rim_dish",variant="black"})
assert(reply.ok and world[car].visual.wheels.rim==NS.."rim_dish" and world[car].visual.wheels.variant=="black" and M.get(1).bank==bank)
autosave();assert(saved(hella).visual.wheels==nil,"autosave never persists a rim preview")
reply=issue("save",{category="rims",rim="rim_dish",variant="black"},"cash")
assert(reply.ok and M.get(1).cash==50000-P.rims and commits[#commits]=="vehicle_rims","rims bought with cash")
assert(saved(hella).visual.wheels.rim==NS.."rim_dish" and saved(hella).visual.parts[NS.."rim_dish"]=="black")
assert(reply.confirmed.rim.id=="rim_dish" and reply.confirmed.rim.variant=="black")
reply=issue("save",{category="rims",rim="rim_dish",variant="black"},"bank");assert(not reply.ok,"unchanged rims refused")
issue("preview",{category="rims",rim="rim_tech",variant=rims.options[8].variants[1].id})
failDb=true;reply=issue("save",{category="rims",rim="rim_aero",variant=rims.options[7].variants[1].id},"bank");failDb=false
assert(not reply.ok and world[car].visual.wheels.rim==NS.."rim_dish" and M.get(1).bank==bank,"DB failure: the confirmed rims come back")
V.setWheels=real

-- 4. Body kit: one part per group, the server prices each changed group.
local foreign="other_res:sticker"
catalogue[foreign]={kind="part",slot="Base",variants={x="asset:other/x"},fit={[HELLA]={}}}
world[car].visual.parts[foreign]="x" -- another resource's part: Light RP never touches it
local wingA,wingB=spoiler.parts[1],spoiler.parts[2]
reply=issue("preview",{category="body",parts={spoiler={part=wingA.id,variant=wingA.variants[1].id}}})
assert(reply.ok and world[car].visual.parts[NS..wingA.id]==wingA.variants[1].id)
reply=issue("preview",{category="body",parts={spoiler={part=wingB.id,variant=wingB.variants[1].id}}})
local held=bodyParts(car)
assert(reply.ok and held[NS..wingB.id] and held[NS..wingA.id]==nil,"two wings are mutually exclusive")
for _,forged in ipairs({{spoiler={part=second.parts[1].id,variant=second.parts[1].variants[1].id}},{nosuch={part=wingA.id,variant="carbon"}},
    {spoiler={part=wingA.id,variant="gold"}},{spoiler={part="other_res:sticker",variant="x"}},{spoiler="wing"}})do
    reply=issue("preview",{category="body",parts=forged});assert(not reply.ok and bodyParts(car)[NS..wingB.id],"forged body part refused")
end
reply=issue("preview",{category="body",parts="all"});assert(not reply.ok)
local want={[spoiler.id]={part=wingB.id,variant=wingB.variants[1].id},[second.id]={part=second.parts[1].id,variant=second.parts[1].variants[1].id}}
reply=issue("save",{category="body",parts=want},"bank")
assert(reply.ok and M.get(1).bank==bank-2*P.body and commits[#commits]=="vehicle_bodykit","two groups changed: twice the body price")
assert(saved(hella).visual.parts[NS..wingB.id] and saved(hella).visual.parts[NS..second.parts[1].id] and saved(hella).visual.parts[foreign]=="x","bought parts stored, other resources' parts kept")
assert(saved(hella).visual.wheels.rim==NS.."rim_dish","a body purchase keeps the rims")
assert(reply.confirmed.body[spoiler.id].part==wingB.id)
reply=issue("save",{category="body",parts=want},"bank");assert(not reply.ok and M.get(1).bank==bank-2*P.body,"unchanged body kit refused")
reply=issue("save",{category="body",parts={[spoiler.id]=want[spoiler.id]}},"bank")
assert(reply.ok and M.get(1).bank==bank-3*P.body and saved(hella).visual.parts[NS..second.parts[1].id]==nil,"removing one group costs one group")
attachLimit=1
reply=issue("save",{category="body",parts=want},"bank");attachLimit=16
assert(not reply.ok and reply.text=="Too many parts on this vehicle: remove one first." and M.get(1).bank==bank-3*P.body,"attach limit explained, nothing charged")
assert(world[car].visual.parts[foreign]=="x")
bank=M.get(1).bank

-- 5. Neon: presets or a custom colour, brightness steps, too dark refused.
reply=issue("preview",{category="neon",color="#101010",intensity="medium"});assert(not reply.ok and world[car].visual.neon==nil,"a colour too dark is refused")
reply=issue("preview",{category="neon",color="#00E5FF",intensity="ultra"});assert(not reply.ok,"unknown brightness refused")
reply=issue("preview",{category="neon",color="#00e5ff",intensity="medium"})
assert(reply.ok and world[car].visual.neon.color.g==229 and world[car].visual.neon.intensity==600 and world[car].visual.neon.radius==C.neon.radius)
reply=issue("save",{category="neon",color="#FF1E3C",intensity="high"},"bank")
assert(reply.ok and M.get(1).bank==bank-P.neon and commits[#commits]=="vehicle_neon")
assert(saved(hella).visual.neon.color.r==255 and saved(hella).visual.neon.intensity==1200)
assert(reply.confirmed.neon.color=="#FF1E3C" and reply.confirmed.neon.intensity=="high")
reply=issue("save",{category="neon",color="#FF1E3C",intensity="high"},"bank");assert(not reply.ok,"unchanged neon refused")
-- Mixed: a neon preview, then a rims purchase: only the rims are persisted.
issue("preview",{category="neon",color="#3CFF6E",intensity="low"})
reply=issue("save",{category="rims",stock=true},"bank")
assert(reply.ok and saved(hella).visual.wheels==nil and saved(hella).visual.neon.color.r==255,"a rims purchase never persists the neon preview")
for pid in pairs(saved(hella).visual.parts)do assert(catalogue[pid].kind~="rim","factory rims: no rim part left") end
close()
assert(world[car].visual.neon.color.r==255 and world[car].visual.wheels==nil and bodyParts(car)[NS..wingB.id],"close restores the confirmed neon and keeps purchases")
bank=M.get(1).bank

-- 5b. Window tint: three levels by id, free preview, paid save, factory glass, unchanged refused.
m=open(hella);bank=M.get(1).bank
reply=issue("preview",{category="windows",tint="mirror"});assert(not reply.ok and reply.text=="Choose a window tint.","an unknown level is refused")
reply=issue("preview",{category="windows",tint="limo"})
assert(reply.ok and world[car].visual.tint==3 and M.get(1).bank==bank and reply.confirmed.windows=="","free tint preview, nothing confirmed")
autosave();assert(saved(hella).visual.tint==nil,"autosave keeps factory glass, never a tint preview")
reply=issue("save",{category="windows",tint="dark"},"bank")
assert(reply.ok and world[car].visual.tint==2 and M.get(1).bank==bank-P.windows and commits[#commits]=="vehicle_tint","tint purchased")
assert(saved(hella).visual.tint==2 and reply.confirmed.windows=="dark","tint persisted, confirmed for the page")
reply=issue("save",{category="windows",tint="dark"},"bank");assert(not reply.ok and reply.text=="Choose a different window tint before purchasing.","unchanged tint refused")
-- A tint preview is never persisted by another purchase, and close puts the paid tint back.
issue("preview",{category="windows",tint="light"});assert(world[car].visual.tint==1)
reply=issue("save",{category="neon",color="#9B3CFF",intensity="low"},"bank")
assert(reply.ok and saved(hella).visual.tint==2 and saved(hella).visual.neon.color.r==155,"a neon purchase never persists the tint preview")
close();assert(world[car].visual.tint==2,"close restores the paid tint")
m=open(hella);assert(m.confirmed.windows=="dark")
reply=issue("save",{category="windows",stock=true},"bank");assert(reply.ok and world[car].visual.tint==nil and saved(hella).visual.tint==nil,"back to factory glass")
reply=issue("save",{category="windows",tint="limo"},"bank");assert(reply.ok and saved(hella).visual.tint==3)
reply=issue("save",{category="neon",color="#FF1E3C",intensity="high"},"bank");assert(reply.ok)
close();bank=M.get(1).bank

-- 6. Plates: provisional format, banned and reserved words, unique across owned vehicles.
local _,galena=G.grant(1,"galena")
m=open(hella)
assert(category(m,"plate").options.minLength==7 and category(m,"plate").options.charset=="A-Z0-9")
for plate,why in pairs({["AB12"]="7 characters",["AB-1234"]="7 characters",["FUCKYOU"]="not allowed",["SH1TCAR"]="not allowed",
    ["NCPD001"]="reserved",["X1488XX"]="not allowed",[""]="7 characters"})do
    reply=issue("preview",{category="plate",plate=plate});assert(not reply.ok and reply.text:find(why,1,true),"plate refused: "..plate.." -> "..tostring(reply.text))
end
reply=issue("preview",{category="plate",plate="XIABB12"});assert(reply.ok,"a digit code is not read as letters")
reply=issue("preview",{category="plate",plate=" abc 1234 "})
assert(reply.ok and reply.text=="This plate is available." and bags[car].lightrpPlate=="ABC1234","normalized, checked and shown")
reply=issue("save",{category="plate",plate="abc1234"},"bank")
assert(reply.ok and M.get(1).bank==bank-P.plate and commits[#commits]=="vehicle_plate" and saved(hella).lightrp.plate=="ABC1234")
assert(reply.confirmed.plate=="ABC1234" and G.plateOf(car)=="ABC1234")
reply=issue("save",{category="plate",plate="ABC1234"},"bank");assert(not reply.ok,"unchanged plate refused")
-- The plate is held while its purchase is in SQL.
yieldDb=true
local pending=coroutine.create(function() return issue("save",{category="plate",plate="ZZZ9999"},"bank") end)
assert(coroutine.resume(pending));assert(coroutine.status(pending)=="suspended")
assert(G.plateTaken("ZZZ9999",galena) and not G.plateTaken("ZZZ9999",hella),"a plate being bought is taken for every other vehicle")
yieldDb=false;assert(coroutine.resume(pending))
assert(saved(hella).lightrp.plate=="ZZZ9999" and not G.plateTaken("ABC1234",galena),"the old plate is free again")
close();assert(bags[car].lightrpPlate=="ZZZ9999")
store(hella);car=retrieve(galena)
m=open(galena)
reply=issue("preview",{category="plate",plate="zzz9999"});assert(not reply.ok and reply.text:find("already registered"),"plates are unique across owned vehicles")
reply=issue("save",{category="plate",plate="ABC1234"},"bank");assert(reply.ok and saved(galena).lightrp.plate=="ABC1234")
close();store(galena)
bank=M.get(1).bank

-- 7. Performance: no preview, server-resolved records, stage sums, cooldown, removal.
car=retrieve(hella);assert(bags[car].lightrpPlate=="ZZZ9999","the plate comes back on retrieve")
m=open(hella)
reply=issue("preview",{category="performance",stage=1});assert(not reply.ok and world[car].record==HELLA,"no stage preview")
reply=issue("save",{category="performance",stage=4},"bank");assert(not reply.ok)
reply=issue("save",{category="performance",stage=2,record="Vehicle.v_sport2_quadra_type66_player"},"bank")
assert(reply.ok and world[car].record==HELLA.."_o77s2" and calls.respawnAs==1,"the record comes from the stage resource, never the client")
assert(M.get(1).bank==bank-P.performance.hella[1]-P.performance.hella[2] and commits[#commits]=="vehicle_stage","an upgrade pays every stage up to the target")
assert(saved(hella).lightrp.stage==2 and reply.confirmed.stage==2)
assert(world[car].visual.neon and world[car].visual.neon.color.r==255,"respawnAs keeps the look")
reply=issue("save",{category="performance",stage=3},"bank");assert(not reply.ok and reply.text:find("tuned recently"),"one stage change per cooldown")
close();tick=tick+C.stages.cooldownMs;m=open(hella) -- a studio session lasts 5 min: reopen
failRespawn="vehicle_occupied";bank=M.get(1).bank
reply=issue("save",{category="performance",stage=3},"bank");failRespawn=nil
assert(not reply.ok and reply.text:find("step out") and M.get(1).bank==bank and world[car].record==HELLA.."_o77s2" and saved(hella).lightrp.stage==2,"an occupied car is refused, nothing charged")
reply=issue("save",{category="performance",stage=0},"bank")
assert(reply.ok and world[car].record==HELLA and M.get(1).bank==bank-P.performanceRemoval and saved(hella).lightrp.stage==0,"back to stock costs the removal fee")
close();tick=tick+C.stages.cooldownMs;m=open(hella);bank=M.get(1).bank
stagesOnServer=false
reply=issue("save",{category="performance",stage=1},"bank")
assert(not reply.ok and M.get(1).bank==bank and world[car].record==HELLA,"a stage record absent on the server is refused")
stagesOnServer=true
reply=issue("save",{category="performance",stage=1},"bank");assert(reply.ok and world[car].record==HELLA.."_o77s1")
-- Buy back a livery, the bought rims and neon stay.
reply=issue("save",{category="livery",profile="hella_tt_2"},"bank");assert(reply.ok)
reply=issue("save",{category="rims",rim="rim_blade",variant=rims.options[5].variants[1].id},"bank");assert(reply.ok)
close()

-- 8. Park, restart, retrieve: every category comes back, on the stage record.
local before=saved(hella)
store(hella);assert(not world[car])
reboot()
assert(calls.registerParts==kitParts,"the kit is registered again at start")
car=retrieve(hella)
local v=world[car]
assert(calls.create[#calls.create]==HELLA.."_o77s1" and v.record==HELLA.."_o77s1","spawned on its stage record")
assert(v.visual.profile=="hella_tt_2" and v.visual.wheels.rim==NS.."rim_blade" and v.visual.neon.intensity==1200,"livery, rims and neon restored")
assert(v.visual.tint==3,"window tint restored")
assert(v.visual.parts[NS..wingB.id] and v.visual.parts[foreign]==nil,"bought body parts restored (the stopped resource's part is not)")
assert(bags[car].lightrpPlate=="ZZZ9999" and G.plateOf(car)=="ZZZ9999","plate restored")
assert(saved(hella).lightrp.plate=="ZZZ9999" and saved(hella).lightrp.stage==1)
m=open(hella)
assert(m.confirmed.stage==1 and m.confirmed.plate=="ZZZ9999" and m.confirmed.rim.id=="rim_blade" and m.confirmed.profile=="hella_tt_2" and m.confirmed.windows=="limo")
assert(category(m,"performance").options.current==1)
close()
assert(G.open(1,"citycenter"));local listed;for _,e in ipairs(dialog.vehicles)do if e.id==hella then listed=e end end
assert(listed.plate=="ZZZ9999" and listed.stage==1,"the garage lists plate and stage")

-- 9. Dormant choices: a part the server cannot put on the car is kept, not lost.
store(hella)
refusePart.rim_blade=true;reboot();refusePart.rim_blade=nil
assert(logged("rim_blade not registered"))
car=retrieve(hella)
assert(world[car].visual.wheels==nil and world[car].visual.profile=="hella_tt_2","the car comes out without the rim it cannot wear")
autosave()
assert(saved(hella).visual.wheels.rim==NS.."rim_blade","the stored rim stays dormant through autosaves")
m=open(hella);issue("save",{category="neon",color="#2F6BFF",intensity="low"},"bank");close()
assert(saved(hella).visual.wheels.rim==NS.."rim_blade" and saved(hella).visual.neon.intensity==300,"another purchase keeps the dormant rim")
m=open(hella)
reply=issue("save",{category="rims",rim="rim_classic",variant="chrome"},"bank")
assert(reply.ok and saved(hella).visual.wheels.rim==NS.."rim_classic" and saved(hella).visual.parts[NS.."rim_blade"]==nil,"buying rims replaces the dormant rim")
close()
-- The stage records offline: the car comes out stock, the stage stays stored.
store(hella);packs.lightrp_vehicle_stages=nil;reboot()
car=retrieve(hella)
assert(world[car].record==HELLA and logged("stage records offline") and saved(hella).lightrp.stage==1,"stage kept dormant while its records are offline")
m=open(hella);assert(m.confirmed.stage==0 and saved(hella).lightrp.stage==1,"the page shows the stock car, not the dormant stage")
assert(category(m,"performance").available==false and category(m,"performance").reason==C.unsupported.stagesPack)
reply=issue("save",{category="performance",stage=2},"bank");assert(not reply.ok and reply.text==C.unsupported.stagesPack)
close();store(hella);packs.lightrp_vehicle_stages="running";reboot()
car=retrieve(hella);assert(world[car].record==HELLA.."_o77s1","the stage is worn again once its records are back")
m=open(hella);assert(m.confirmed.stage==1,"the page shows the stage the car wears again");close()

-- 10. Greying: packs, natives and models that cannot take a category.
packs.lightrp_vk_rims=nil;packs.lightrp_vk_body=nil
m=open(hella)
assert(category(m,"rims").available==false and category(m,"rims").reason==C.unsupported.rimsPack)
assert(category(m,"body").available==false and category(m,"body").reason==C.unsupported.bodyPack)
reply=issue("preview",{category="rims",rim="rim_dish",variant="black"});assert(not reply.ok and reply.text==C.unsupported.rimsPack,"the server refuses a greyed category")
close();packs.lightrp_vk_rims="running";packs.lightrp_vk_body="running"
local setNeon=V.setNeon;V.setNeon=nil
m=open(hella);assert(category(m,"neon").available==false and category(m,"neon").reason==C.unsupported.native);close()
V.setNeon=setNeon
C.windows.enabled=false
m=open(hella);assert(category(m,"windows").available==false and category(m,"windows").reason==C.unsupported.windowsSoon,"closed tint is greyed")
reply=issue("preview",{category="windows",tint="limo"});assert(not reply.ok and reply.text==C.unsupported.windowsSoon,"the server refuses a closed tint")
close();C.windows.enabled=true
local setTint=V.setWindowTint;V.setWindowTint=nil
m=open(hella);assert(category(m,"windows").available==false and category(m,"windows").reason==C.unsupported.native);close()
V.setWindowTint=setTint;packs.open77_vehicle_tint=nil
m=open(hella);assert(category(m,"windows").available==false and category(m,"windows").reason==C.unsupported.windowsPack)
reply=issue("preview",{category="windows",tint="limo"});assert(not reply.ok and reply.text==C.unsupported.windowsPack,"the server refuses tint without its pack")
close();packs.open77_vehicle_tint="running"
store(hella)
-- The mock gives the Kusanagi no paint profile, to cover the greyed livery path. In game
-- (2026-11-07, lab 11855) it has a factory scheme: the studio offers "Scheme 1" and
-- previews it. Rims, body kit and windows are greyed there too.
local _,kusanagi=G.grant(1,"kusanagi");car=retrieve(kusanagi)
m=open(kusanagi)
assert(category(m,"rims").available==false and category(m,"rims").reason==C.unsupported.rims,"Kusanagi: no rim fits")
assert(category(m,"livery").available==false and category(m,"livery").reason==C.unsupported.livery,"no factory scheme")
assert(category(m,"performance").available and category(m,"plate").available)
assert(category(m,"windows").available==false and category(m,"windows").reason==C.unsupported.windows,"a bike has no window to tint")
close();store(kusanagi)
-- The staff-only Type-66 and Shion are not dealer models: their rims come from the player
-- vehicles' table. Rims and Plate are offered (not greyed), every rim fits, and a preview
-- reaches the car.
for _,key in ipairs({"type66","shion"})do
    local _,row=G.grant(1,key);car=retrieve(row)
    m=open(row)
    local offered=category(m,"rims")
    assert(offered.available and #offered.options==#KIT.rims.order and offered.options[1].id=="rim_classic",key..": every rim offered")
    assert(category(m,"plate").available,key..": plate offered")
    reply=issue("preview",{category="rims",rim="rim_dish",variant="black"})
    assert(reply.ok and world[car].visual.wheels.rim==NS.."rim_dish",key..": a rim preview reaches the car")
    close();store(row)
end
-- A server without per-appearance fits refuses `appearances` once: every rim registers
-- with the record fit alone and every trim's hide names merged into it (the default fit
-- for every trim; the client skips the names an appearance lacks).
local logsBefore=#logs
b3=false;reboot();b3=true
assert(calls.registerParts==kitParts+1,"one refused registration, then the merged rims ("..calls.registerParts..")")
local notices=0;for i=logsBefore+1,#logs do if logs[i]:find("no per-appearance fits",1,true) then notices=notices+1 end end
assert(notices==1 and logged("fit.appearances"),"the fallback is logged once, with the server's reason")
local function checkMerged(fits,label)
    for record,fit in pairs(fits)do
        assert(fit.appearances==nil,label..": no overrides on "..record)
        local seen={};for _,n in ipairs(fit.hide or {})do assert(not seen[n],label..": deduplicated "..n);seen[n]=true end
        assert(#fit.hide<=64,label..": hide cap")
        local src=rimSource("rim_classic",record)
        for _,n in ipairs(src.hide or {})do assert(seen[n],label..": default names kept on "..record) end
        for app,o in pairs(TRIMS.rims[record] or src.appearances or {})do for _,n in ipairs(o.hide)do assert(seen[n],label..": "..app.." hides "..n) end end
    end
end
for _,id in ipairs(KIT.rims.order)do
    checkMerged(catalogue[NS..id].fit,"merged "..id)
    for record,fit in pairs(catalogue[NS..id].fit)do
        local src=rimSource(id,record)
        assert(same(fit.wheels,src.wheels) and same(fit.offset,src.offset),"merged: the default fit")
    end
end
local merged=catalogue[NS.."rim_dish"].fit[HELLA].hide
assert(#merged==16 and merged[1]=="wheel_01_bl_a" and has(merged,"wheel_bl_01") and has(merged,"police_wheel_01_fl_0a"),"Hella: player, Suburban and Worn IV rims all hidden")
assert(#KIT.rims.parts.rim_dish.fit[HELLA].hide==4 and KIT.rims.parts.rim_dish.fit[HELLA].appearances==nil,"the generated catalogue stays as measured")
checkBodyHides();checkBags("merged fallback")
-- A server without carried parts refuses `carrier` once (with its reason, by name): the
-- kit registers without any, every body part on its Base slot as before. Together with
-- the per-appearance fallback, each is taken once.
do
    local function plain(label)
        for id in pairs(KIT.body.parts)do
            local got=assert(catalogue[NS..id],label..": "..id.." registered")
            assert(got.carrier==nil,label..": no carrier on "..id)
            for record,fit in pairs(got.fit)do assert(fit.carrier==nil,label..": no carrier on "..id.." "..record) end
        end
    end
    local function notices(from,text) local n=0;for i=from,#logs do if logs[i]:find(text,1,true) then n=n+1 end end;return n end
    local from=#logs+1
    b4=false;reboot();b4=true
    assert(calls.registerParts==kitParts+1,"one refused registration, then the kit without carriers ("..calls.registerParts..")")
    assert(notices(from,"no carried parts")==1 and notices(from,"invalid_part:wing_street.carrier")==1,"the fallback is logged once, with the server's reason")
    plain("no carriers")
    assert(catalogue[NS.."rim_classic"].fit[HELLA].appearances,"rims keep their per-appearance fits")
    checkBags("no carriers")
    from=#logs+1
    b3=false;b4=false;reboot();b3=true;b4=true
    assert(calls.registerParts==kitParts+2,"one refusal per missing key, then the kit ("..calls.registerParts..")")
    assert(notices(from,"no carried parts")==1 and notices(from,"no per-appearance fits")==1)
    plain("no carriers nor overrides")
    assert(catalogue[NS.."rim_classic"].fit[HELLA].appearances==nil)
end
-- A server without per-wheel rim fits (nor per-appearance ones): rims register merged on
-- the default slots, the records that need other slots lose them.
b2=false;b3=false;reboot();b2=true;b3=true
local legacy=catalogue[NS.."rim_classic"].fit
assert(legacy[HELLA] and legacy[HELLA].wheels==nil and legacy["Vehicle.v_standard2_makigai_maimai_player"],"default-slot records keep their rims")
assert(legacy["Vehicle.v_standard25_thorton_merrimac_player"]==nil and legacy["Vehicle.v_sportbike3_brennan_apollo_player"]==nil,"Merrimac and Apollo need per-wheel fits")
assert(catalogue[NS.."wing_street"] and logged("server predates them"))
checkMerged(legacy,"legacy")
assert(#legacy[HELLA].hide==16 and has(legacy[HELLA].hide,"wheel_bl_01"),"the default-slot registration hides the trims' rims too")
-- A trim, then rims, on a server with per-appearance fits: the rim resolves to that trim's
-- own fit (its depth, size and stock rims), on the stage record too.
reboot();assert(calls.registerParts==kitParts)
local _,suburban=G.grant(1,"hella");car=retrieve(suburban)
m=open(suburban)
local TRIM="archer_hella__basic_suburban_1"
reply=issue("save",{category="trim",trim=TRIM},"bank");assert(reply.ok and world[car].appearance==TRIM,"the Suburban trim is worn")
reply=issue("save",{category="rims",rim="rim_dish",variant="black"},"bank");assert(reply.ok and world[car].visual.wheels.rim==NS.."rim_dish")
local want=TRIMS.rims[HELLA][TRIM]
for _,record in ipairs({world[car].record,HELLA.."_o77s2"})do
    local fit=resolve(fitFor(catalogue[world[car].visual.wheels.rim],record),world[car].appearance)
    assert(same(fit.hide,want.hide) and same(fit.offset,want.offset) and same(fit.wheels,want.wheels),"the Suburban wears its own rim fit ("..record..")")
end
close();store(suburban)
for i,msg in ipairs(messages)do fitsClient(msg,"studio message "..i.." ("..tostring(msg.kind)..")")end
print(("largest studio category: %d JSON values (client cap 1024)"):format(maxCategoryValues))
print("customization kit: catalogue contract, livery, rims, body exclusivity and per-group price, neon, window tint, plates (format, words, uniqueness, hold), performance stages (sum, removal, cooldown, refusals), park+restart+retrieve, dormant choices and greying passed")
