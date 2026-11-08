-- Persistence audit (docs/vehicle-persistence-audit.md): the look of a personal vehicle is
-- decided by the server, written to lightrp_owned_vehicles.properties, tied to the owning
-- row, and put back on every path a car leaves and re-enters the world. Real garage +
-- inventory modules; deterministic SQL; a native mock that follows the server code, not a
-- wish list (each rule cites it):
--   * setPaint / resetPaint clear a TwinTone profile EVEN WHEN the paint does not change
--     (VehicleAuthorityService.cs SetPaint/ResetPaint -> Customization.PaintWritten);
--     `update` (setProperties) only when the paint really changes;
--   * a colour handed to `update` switches paintApplied on (LuaResourceRuntime.Vehicles.cs,
--     setProperties), so a factory restore must not send colour channels;
--   * setPaintProfile: restating the current profile is never re-validated (TryProfile);
--     another one must be listed for the record (base record for a stage);
--   * the open77.visual bag is published only when the choices change (Apply: SameChoices),
--     with rev + 1 (Publish); setProperties plans the visual first and commits it last.
local function noop() end
local function clone(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = clone(v) end return c end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local encoded, enc = {}, 0
json = { encode = function(t) enc = enc + 1; encoded[tostring(enc)] = clone(t); return tostring(enc) end,
    decode = function(s) if s == "{}" then return {} end assert(encoded[s], "invalid JSON"); return clone(encoded[s]) end }
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("server/config/garages.lua")
local C = LightRpGarages
C.defaultGarage = "citycenter"
C.garages = { { id = "citycenter", name = "Central", position = { x = 0, y = 0, z = 0 }, parking = { { position = { x = 10, y = 0, z = 0 } } } } }
GetCurrentResourceName = function() return "op77_lightrp" end
local NS = "op77_lightrp:"
-- The kit kinds the garage reads (server/config/vehicle_kit.lua shape, ids only).
LightRpVehicleKit = { rims = { parts = { rim_a = {}, rim_b = {} } }, body = { parts = { wing_a = {}, lip_a = {} } } }
local HELLA, GALENA = "Vehicle.v_standard2_archer_hella_player", "Vehicle.v_standard2_thorton_galena_player"
local PACK_LIVERY = "Vehicle.o77_livery_taxi_hella"

-- SQL -------------------------------------------------------------------------------
local threads, handlers, messages = {}, {}, {}
local dbRows, inventories, uid, tick = {}, {}, 0, 1000
local failDb = false
local writes = {} -- { id, kind } per properties write: "purchase" (in a payment) or "save"
local inPayment = false
local chars = { [1] = { identifier = "alice", key = "default", status = "active" }, [2] = { identifier = "bob", key = "default", status = "active" } }
local positions = { [1] = { x = 0, y = 0, z = 0, bucket = 0 }, [2] = { x = 0, y = 1, z = 0, bucket = 0 } }
local function event(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local Db = { ready = true, schema = noop }
function Db.read(sql, p)
    if failDb then return false, "database_error" end
    if sql:find("UUID", 1, true) then uid = uid + 1; return true, { { id = string.format("00000000-0000-0000-0000-%012d", uid) } } end
    if sql:find("lightrp_inventories", 1, true) then return true, inventories[p[1]] and { { items = inventories[p[1]] } } or {} end
    if sql:find("information_schema", 1, true) then return true, { { n = 1 } } end
    local result = {}; for _, row in pairs(dbRows) do result[#result + 1] = clone(row) end; return true, result
end
function Db.run(sql, p)
    if failDb then return false, "database_error" end
    if sql:find("INSERT INTO lightrp_owned_vehicles", 1, true) then
        dbRows[p[1]] = { id = p[1], identifier = p[2], character_key = p[3], model = p[4], record = p[5], garage_id = p[6], properties = p[7], grant_key = p[8], state = "stored", impound_fee = 0 }
    elseif sql:find("SET state = 'stored'", 1, true) then
        local r = dbRows[p[2]]; if not r or r.state ~= "impound" then return true, 0 end
        r.state, r.impound_reason, r.impound_fee, r.garage_id = "stored", nil, 0, p[1]
    elseif sql:find("SET garage_id = ?, properties = ? WHERE id = ?", 1, true) then
        local r = dbRows[p[3]]; r.garage_id, r.properties = p[1], p[2]; writes[#writes + 1] = { id = p[3], kind = inPayment and "purchase" or "save" }
    elseif sql:find("SET properties = ? WHERE id = ?", 1, true) then
        dbRows[p[2]].properties = p[1]; writes[#writes + 1] = { id = p[2], kind = inPayment and "purchase" or "save" }
    elseif sql:find("UPDATE lightrp_owned_vehicles", 1, true) then
        for i = 1, 6 do assert(p[i] ~= nil, "no nil in a parameter list") end
        local r = dbRows[p[6]]; r.garage_id, r.properties, r.state, r.impound_reason, r.impound_fee = p[1], p[2], p[3], p[4] ~= "" and p[4] or nil, p[5]
        writes[#writes + 1] = { id = p[6], kind = "save" }
    elseif sql:find("INSERT INTO lightrp_inventories", 1, true) then inventories[p[1]] = p[6] end
    return true, 1
end
Db.single = function(sql, p) local ok, r = Db.read(sql, p); return ok and r[1] end
Db.transaction = function(queries)
    if failDb then return false, "database_error" end
    for _, q in ipairs(queries) do assert(Db.run(q.query, q.values)) end
    return true
end
local function stored(rowId) return json.decode(dbRows[rowId].properties) end

-- Light RP --------------------------------------------------------------------------
local wallet, ledger, logs = { cash = 0, bank = 1000000 }, {}, {}
local lastDialog
LightRP = { db = Db, module = function(name, t) LightRP[name] = t; return t end, command = noop, state = noop, stateProvider = noop, result = noop,
    log = function(f, ...) local ok, s = pcall(string.format, f, ...); logs[#logs + 1] = ok and s or tostring(f) end,
    nowMs = function() return tick end, eachModule = noop, notice = noop,
    characters = { switching = {}, get = function(id) return chars[id] end, displayName = function(id) return chars[id] and chars[id].identifier or "gone" end },
    vehicles = { byKey = {} }, action = noop, interaction = noop, removeInteraction = noop,
    dialog = function(_, kind, p) assert(kind == "garage"); lastDialog = p end,
    keys = { lock = function() return true end, give = function() return true end } }
for _, v in ipairs(LightRpConfig.vehicles.catalog) do LightRP.vehicles.byKey[v.key] = v end
LightRP.money = { format = function(n) return "€$" .. n end, explain = function(e) return tostring(e) end,
    validAmount = function(n) return type(n) == "number" and n > 0 and n % 1 == 0 and n end, get = function() return wallet end,
    exchange = function(_, method, delta, write, commit, kind)
        if wallet[method] + delta < 0 then return false, "insufficient_funds" end
        inPayment = true; local ok = Db.transaction({ write }); inPayment = false
        if not ok then return false, "database_error" end
        wallet[method] = wallet[method] + delta; commit(); ledger[#ledger + 1] = kind; return true
    end }
local function logged(text) for _, line in ipairs(logs) do if line:find(text, 1, true) then return true end end end

-- Natives (server contract) ------------------------------------------------------------
local world, nextVehicle, publishes, calls = {}, 100, {}, {}
local packRunning = true
local profiles = { [HELLA] = { "hella_tt_1", "hella_tt_2", PACK_LIVERY } }
local pack = { [PACK_LIVERY] = true }
local catalogue = {
    [NS .. "rim_a"] = { kind = "rim", variants = { chrome = true, black = true }, fit = { [HELLA] = true } },
    [NS .. "rim_b"] = { kind = "rim", variants = { chrome = true }, fit = { [HELLA] = true } },
    [NS .. "wing_a"] = { kind = "part", variants = { carbon = true }, fit = { [HELLA] = true } },
    [NS .. "lip_a"] = { kind = "part", variants = { black = true }, fit = { [HELLA] = true } },
}
local failSetProperties -- nil | "visual" (a refused visual) | "all"
local function base(record) return (tostring(record):gsub("_o77s%d+$", "")) end
local function listed(record, profile)
    for _, p in ipairs(profiles[base(record)] or {}) do if p == profile and (not pack[p] or packRunning) then return true end end
    return false
end
local function rgb(v) if type(v) == "table" then return { r = v.r, g = v.g, b = v.b } end
    return { r = tonumber(v:sub(2, 3), 16), g = tonumber(v:sub(4, 5), 16), b = tonumber(v:sub(6, 7), 16) } end
local function choices(x) return { profile = x.profile, neon = clone(x.neon), parts = clone(x.parts or {}), wheels = clone(x.wheels), plate = x.plate, tint = x.tint } end
local function view(v, rev)
    local x = v.visual
    local out = { profile = x.profile, neon = clone(x.neon), wheels = clone(x.wheels), plate = x.plate, tint = x.tint }
    if next(x.parts) then out.parts = clone(x.parts) end
    if rev then out.rev = x.rev end
    return out
end
local function publish(v, nextVisual)
    if same(choices(v.visual), choices(nextVisual)) then return true end -- a restatement publishes nothing
    nextVisual.parts = nextVisual.parts or {}
    nextVisual.rev = (v.visual.rev or 0) + 1
    v.visual = nextVisual
    v.bag["open77.visual"] = clone(view(v, true))
    publishes[#publishes + 1] = { id = v.id, rev = nextVisual.rev, visual = clone(view(v)) }
    return true
end
local function paintWritten(v) if v.visual.profile ~= nil then local x = choices(v.visual); x.profile = nil; publish(v, x) end end
local function neonOf(spec) return { enabled = spec.enabled ~= false, color = rgb(spec.color), intensity = spec.intensity or 600, radius = spec.radius or 3, layout = "auto" } end
local function choose(record, id, value)
    local part = catalogue[id]
    if not part then return nil, "unknown_part" end
    if not part.fit[base(record)] then return nil, "part_not_for_model" end
    if value ~= true and not part.variants[value] then return nil, "unknown_variant" end
    return part
end
Open77 = { players = { position = function(id) return positions[id] end, getLifeState = function(id) return chars[id] and { phase = "alive" } end },
    vehicles = {}, state = { entity = function(_, id)
        local v = world[id] or { bag = {} }
        return { set = function(_, k, value) v.bag[k] = value; return true end, get = function(_, k) return v.bag[k] end } end } }
local V = Open77.vehicles
local function log(op, ...) calls[#calls + 1] = { op = op, args = { ... } } end
local function count(op, id) local n = 0; for _, c in ipairs(calls) do if c.op == op and (id == nil or c.args[1] == id) then n = n + 1 end end; return n end
V.get = function(id) return world[id] end
V.all = function(bucket) local a = {}; for _, v in pairs(world) do if not bucket or v.bucket == bucket then a[#a + 1] = v end end; return a end
V.getPlayerSeat = function() return nil end
V.create = function(d)
    log("create", d.record, d.appearance)
    if base(d.record) ~= HELLA and base(d.record) ~= GALENA then return nil, "invalid_record" end
    nextVehicle = nextVehicle + 1
    -- a fresh spawn: factory paint, black RGB channels (applied=false), no visual, no bag
    world[nextVehicle] = { id = nextVehicle, record = d.record, appearance = d.appearance or "", position = clone(d.position), bucket = d.bucket,
        health = 1, speed = 0, occupants = {}, paint = { applied = false, primary = { r = 0, g = 0, b = 0 }, secondary = { r = 0, g = 0, b = 0 } },
        visual = { parts = {}, rev = 0 }, bag = {} }
    return nextVehicle
end
V.remove = function(id) world[id] = nil; event("onVehicleRemoved", tostring(id), "test"); return true end
V.setEngine = function() return true end
V.isLocked = function() return false end
V.getProperties = function(id)
    local v = world[id]; if not v then return nil, "vehicle_not_found" end
    return { version = 1, record = v.record, appearance = v.appearance, health = v.health,
        paint = { applied = v.paint.applied, primary = clone(v.paint.primary), secondary = clone(v.paint.secondary), lightsHue = v.paint.lightsHue },
        damage = { destroyed = v.destroyed == true, exploded = false }, visual = view(v) }
end
local PROPS = { version = 1, record = 1, appearance = 1, health = 1, paint = 1, damage = 1, visual = 1 }
local VISUAL = { profile = 1, neon = 1, parts = 1, wheels = 1, plate = 1, tint = 1, rev = 1 }
local PAINT = { applied = 1, primary = 1, secondary = 1, lightsHue = 1 }
-- As LuaResourceRuntime.Vehicles.cs vehicleUnknownProperties: the alphabetically first
-- unknown key of each table, sorted; never the full list.
local function firstUnknown(t, allowed, prefix)
    local first
    for k in pairs(type(t) == "table" and t or {}) do
        if not allowed[k] and (first == nil or prefix .. k < first) then first = prefix .. k end
    end
    return first
end
V.setProperties = function(id, p, options)
    log("setProperties", id, clone(p))
    if failSetProperties == "all" or (failSetProperties == "visual" and p.visual ~= nil) then return false, "part_not_for_model" end
    -- A key this build does not know: refused by name before anything is applied, or
    -- skipped and listed (ignoreUnsupported; one per table, as the platform does).
    local unknown = {}
    unknown[#unknown + 1] = firstUnknown(p, PROPS, "")
    unknown[#unknown + 1] = firstUnknown(p.paint, PAINT, "paint.")
    unknown[#unknown + 1] = firstUnknown(p.visual, VISUAL, "visual.")
    table.sort(unknown)
    if #unknown > 0 and not (options and options.ignoreUnsupported) then return false, "unsupported_property:" .. unknown[1] end
    local skipped = #unknown > 0 and unknown or nil
    local v = world[id]; if not v then return false, "vehicle_not_found" end
    if p.record ~= nil and p.record ~= v.record then return false, "record_mismatch" end
    local complete, plan = p.version ~= nil, nil
    if p.visual ~= nil then -- planned (validated) first, committed last
        local x = p.visual
        if x.profile ~= nil and x.profile ~= v.visual.profile and not listed(v.record, x.profile) then return false, "invalid_profile" end
        plan = { profile = x.profile, neon = x.neon and neonOf(x.neon), parts = {}, wheels = clone(x.wheels), plate = x.plate, tint = x.tint }
        for pid, value in pairs(x.parts or {}) do local ok, why = choose(v.record, pid, value); if not ok then return false, why end; plan.parts[pid] = value end
        if x.wheels then local ok, why = choose(v.record, x.wheels.rim, x.wheels.variant); if not ok then return false, why end; plan.parts[x.wheels.rim] = x.wheels.variant end
    end
    local paint, before = p.paint or {}, json.encode(v.paint)
    local was = clone(v.paint)
    if paint.applied ~= nil then v.paint.applied = paint.applied end
    if paint.primary ~= nil then v.paint.primary = rgb(paint.primary); v.paint.applied = true end -- a colour is a repaint
    if paint.secondary ~= nil then v.paint.secondary = rgb(paint.secondary); v.paint.applied = true end
    if p.health ~= nil then v.health = p.health end
    if not same({ was.applied, was.primary, was.secondary }, { v.paint.applied, v.paint.primary, v.paint.secondary }) then paintWritten(v) end
    if p.appearance ~= nil then v.appearance = p.appearance end
    if paint.lightsHue ~= nil or complete then v.paint.lightsHue = paint.lightsHue end
    if plan then publish(v, plan) end
    if skipped then return true, nil, skipped end
    return true
end
V.getPaint = function(id) local v = world[id]; if v then return { applied = v.paint.applied, primary = clone(v.paint.primary), secondary = clone(v.paint.secondary) } end end
V.setPaint = function(id, p) log("setPaint", id); local v = world[id]; if not v then return false, "vehicle_not_found" end
    v.paint.applied, v.paint.primary, v.paint.secondary = true, rgb(p.primary), rgb(p.secondary); paintWritten(v); return true end
V.resetPaint = function(id) log("resetPaint", id); local v = world[id]; if not v then return false, "vehicle_not_found" end
    v.paint.applied = false; paintWritten(v); return true end -- colours kept, as ResetPaint keeps them
V.setLightsHue = function(id, hue) log("setLightsHue", id); local v = world[id]; if not v then return false end; v.paint.lightsHue = hue; return true end
V.getLightsHue = function(id) local v = world[id]; return v and v.paint.lightsHue end
V.setHeadlightColor = function(id, color) return V.setLightsHue(id, tonumber(color:sub(2, 3), 16) / 255 * 0.5 + 0.1) end
V.clearLightsHue = function(id) return V.setLightsHue(id, nil) end
V.getAppearance = function(id) local v = world[id]; return v and v.appearance end
V.setAppearance = function(id, name) log("setAppearance", id); local v = world[id]; v.appearance = name or ""; return true end
V.getVisual = function(id) local v = world[id]; if not v then return nil, "vehicle_not_found" end; return view(v, true) end
V.listPaintProfiles = function(x)
    local record = type(x) == "string" and x or (world[x] and world[x].record)
    local out = {}; for _, p in ipairs(profiles[base(record or "")] or {}) do if listed(record, p) then out[#out + 1] = { id = p } end end; return out
end
V.listParts = function(x)
    local record = type(x) == "string" and x or (world[x] and world[x].record)
    local out = {}; for id, p in pairs(catalogue) do if p.fit[base(record or "")] then out[#out + 1] = { id = id, kind = p.kind, variants = clone(p.variants) } end end
    return out
end
V.setPaintProfile = function(id, profile)
    log("setPaintProfile", id, profile)
    local v = world[id]; if not v then return false, "vehicle_not_found" end
    if profile == v.visual.profile then return true end -- a restatement is not re-validated
    if profile ~= nil and not listed(v.record, profile) then return false, "invalid_profile" end
    local x = choices(v.visual); x.profile = profile; return publish(v, x)
end
V.setNeon = function(id, spec) local v = world[id]; local x = choices(v.visual); x.neon = neonOf(spec); return publish(v, x) end
V.clearNeon = function(id) local v = world[id]; local x = choices(v.visual); x.neon = nil; return publish(v, x) end
V.setWindowTint = function(id, level) local v = world[id]; local x = choices(v.visual); x.tint = level ~= 0 and level or nil; return publish(v, x) end
V.setPlate = function(id, text) local v = world[id]; if not v then return false, "vehicle_not_found" end
    local x = choices(v.visual); x.plate = text and text ~= "" and text:upper() or nil; return publish(v, x) end
V.setWheels = function(id, w)
    local v = world[id]; local x = choices(v.visual)
    for pid in pairs(x.parts) do if catalogue[pid] and catalogue[pid].kind == "rim" then x.parts[pid] = nil end end
    x.wheels = nil
    if w then local ok, why = choose(v.record, w.rim, w.variant); if not ok then return false, why end; x.parts[w.rim] = w.variant; x.wheels = { rim = w.rim, variant = w.variant } end
    return publish(v, x)
end
V.setParts = function(id, map)
    local v = world[id]; local x = choices(v.visual)
    for pid, value in pairs(map) do
        if value == false then x.parts[pid] = nil else local ok, why = choose(v.record, pid, value); if not ok then return false, why end; x.parts[pid] = value end
    end
    return publish(v, x)
end
V.respawnAs = function(id, record) log("respawnAs", id, record); local v = world[id]; v.record = record; return id end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() coroutine.yield() end
GetPlayers = function() local t = {}; for id in pairs(chars) do t[#t + 1] = id end; return t end
GetPlayerName = function(id) return chars[id] and chars[id].identifier end
AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
TriggerClientEvent = function(name, id, p) messages[#messages + 1] = { name = name, id = id, payload = p } end

local G, worker
local function boot(keepWorld)
    if not keepWorld then world = {} end
    handlers, threads, LightRP.inventory = {}, {}, nil
    dofile("server/modules/inventory.lua")
    local at = #threads; dofile("server/modules/garages.lua"); worker = threads[at + 1]
    G = LightRP.garage
    G.setStageResolver(function(record, stage) return record .. "_o77s" .. stage end)
    G.onDatabaseReady()
end
local function autosave() local co = coroutine.create(worker); for _ = 1, 9 do assert(coroutine.resume(co)); tick = tick + 2000 end end
local function perform(kind, rowId, id, extra)
    id = id or 1
    assert(G.open(id, "citycenter"))
    local p = { type = "garage." .. kind, session = lastDialog.session, request = lastDialog.nextRequest, vehicle = rowId }
    for k, v in pairs(extra or {}) do p[k] = v end
    return G.perform(id, p)
end
local function retrieve(rowId, id) local ok, why = perform("retrieve", rowId, id); assert(ok, why); return nextVehicle end
local function store(rowId, id) local ok, why = perform("store", rowId, id); assert(ok, why) end
local function entry(rowId) G.open(1, "citycenter"); for _, v in ipairs(lastDialog.vehicles) do if v.id == rowId then return v end end end
local token = 0
local function studio(rowId, id) token = token + 1; local t = "audit:" .. token; assert(G.beginCustomization(id or 1, rowId, t, "citycenter")); return t end
local function buy(t, change, id) return G.customize(id or 1, t, change, true, { method = "bank", amount = 1000 }) end
local function preview(t, change, id) return G.customize(id or 1, t, change, false) end
local function close(t, id) return G.endCustomization(id or 1, t) end
local function since(n, id) local out = {}; for i = n + 1, #publishes do if id == nil or publishes[i].id == id then out[#out + 1] = publishes[i] end end; return out end
local function lookOf(id) local v = world[id]; return { paint = { applied = v.paint.applied, primary = v.paint.applied and clone(v.paint.primary) or nil,
    secondary = v.paint.applied and clone(v.paint.secondary) or nil, lightsHue = v.paint.lightsHue }, appearance = v.appearance, visual = choices(v.visual) } end
local function storedLook(rowId)
    local p = stored(rowId)
    local x = type(p.visual) == "table" and p.visual or {}
    return { paint = { applied = p.paint.applied, primary = p.paint.applied and clone(p.paint.primary) or nil, secondary = p.paint.applied and clone(p.paint.secondary) or nil,
        lightsHue = p.paint.lightsHue }, appearance = p.appearance or "", visual = { profile = x.profile, neon = x.neon and neonOf(x.neon), parts = clone(x.parts or {}),
        wheels = clone(x.wheels), plate = x.plate, tint = x.tint } }
end

boot()

-- 1. Buy: each category is written at once, in the payment's transaction, on the row's id ---
local _, hella = G.grant(1, "hella")
local car = retrieve(hella)
local t = studio(hella)
local function bought(change, check, label)
    local before = #writes
    assert(buy(t, change), label)
    local w = writes[#writes]
    assert(#writes == before + 1 and w.kind == "purchase" and w.id == hella, label .. ": one properties write, inside the payment, on the row id")
    assert(dbRows[hella].identifier == "alice" and dbRows[hella].character_key == "default", label .. ": the owner columns never move")
    check(stored(hella)); return stored(hella)
end
bought({ category = "paint", paint = { applied = true, primary = "#FFCC00", secondary = "#101820" } }, function(p) assert(p.paint.applied and p.paint.primary.r == 255) end, "paint")
bought({ category = "lights", color = "#00FFAA" }, function(p) assert(p.paint.lightsHue == 0.1) end, "lights")
bought({ category = "trim", appearance = "archer_hella__basic_suburban_1" }, function(p) assert(p.appearance == "archer_hella__basic_suburban_1") end, "trim")
bought({ category = "rims", rim = NS .. "rim_a", variant = "black" }, function(p) assert(p.visual.wheels.rim == NS .. "rim_a" and p.visual.parts[NS .. "rim_a"] == "black") end, "rims")
bought({ category = "body", parts = { [NS .. "wing_a"] = "carbon" } }, function(p) assert(p.visual.parts[NS .. "wing_a"] == "carbon" and p.visual.wheels) end, "body")
bought({ category = "neon", neon = { color = "#FF1E3C", intensity = 1200, radius = 3 } }, function(p) assert(p.visual.neon.intensity == 1200) end, "neon")
bought({ category = "windows", tint = 2 }, function(p) assert(p.visual.tint == 2) end, "windows")
bought({ category = "plate", plate = "ABC1234" }, function(p) assert(p.lightrp.plate == "ABC1234" and p.visual.plate == "ABC1234") end, "plate")
bought({ category = "performance", stage = 2, record = HELLA .. "_o77s2" }, function(p) assert(p.lightrp.stage == 2 and p.record == HELLA .. "_o77s2") end, "stage")
assert(world[car].record == HELLA .. "_o77s2" and count("respawnAs") == 1, "the stage is a record swap on the same car")
bought({ category = "livery", profile = "hella_tt_1" }, function(p) assert(p.visual.profile == "hella_tt_1" and p.paint.applied == false) end, "livery (on the factory paint layer)")
assert(#ledger == 10, "ten receipts")
close(t)
local confirmed = storedLook(hella)
print("audit 1: every category written at purchase, in the payment transaction, on the row id; owner columns untouched")

-- 2. Previews are never durable: autosave and another purchase keep the confirmed look --
t = studio(hella)
preview(t, { category = "neon", neon = { color = "#3CFF6E", intensity = 300, radius = 3 } })
preview(t, { category = "rims", rim = NS .. "rim_b", variant = "chrome" })
preview(t, { category = "windows", tint = 3 })
preview(t, { category = "trim", appearance = "" })
preview(t, { category = "lights", color = "#FF0000" })
preview(t, { category = "body", parts = { [NS .. "wing_a"] = false, [NS .. "lip_a"] = "black" } })
autosave()
local p = storedLook(hella)
assert(same(p.visual.neon, confirmed.visual.neon) and same(p.visual.wheels, confirmed.visual.wheels) and p.visual.tint == 2, "autosave: visual previews masked")
assert(p.appearance == confirmed.appearance and p.paint.lightsHue == confirmed.paint.lightsHue and same(p.visual.parts, confirmed.visual.parts), "autosave: trim, lights and parts masked")
assert(buy(t, { category = "windows", tint = 1 }))
p = storedLook(hella)
assert(p.visual.tint == 1 and same(p.visual.neon, confirmed.visual.neon) and same(p.visual.parts[NS .. "wing_a"], "carbon"), "another purchase persists only its own category")
close(t)
assert(world[car].visual.neon.intensity == 1200 and world[car].visual.wheels.rim == NS .. "rim_a" and world[car].visual.tint == 1, "close puts the confirmed look back")
confirmed = storedLook(hella)
print("audit 2: previews never durable (autosave, another purchase), close restores")

-- 3. Closing the studio is a no-op for viewers: no paint re-write, no livery blink ------
local n = #publishes
t = studio(hella); assert(close(t))
assert(#since(n, car) == 0, "an untouched studio session publishes nothing (no livery drop and back)")
n = #publishes
t = studio(hella); preview(t, { category = "neon", neon = { color = "#3CFF6E", intensity = 300, radius = 3 } }); assert(close(t))
local seen = since(n, car)
assert(#seen == 2, "the neon preview and its restore, nothing else")
for _, pub in ipairs(seen) do assert(pub.visual.profile == "hella_tt_1", "the livery never leaves the car while another category is restored") end
print("audit 3: a studio close re-writes nothing the car already wears (livery kept on every viewer)")

-- 4. Store, then retrieve: create on the stored record and appearance, ONE setProperties --
store(hella); assert(not world[car])
calls = {}; n = #publishes
car = retrieve(hella)
assert(calls[1].op == "create" and calls[1].args[1] == HELLA .. "_o77s2" and calls[1].args[2] == "archer_hella__basic_suburban_1", "spawned on the stage record, with its trim")
assert(calls[2].op == "setProperties" and count("setProperties") == 1 and count("respawnAs") == 0, "one setProperties right after the create, no respawn")
local restore = calls[2].args[2]
assert(restore.lightrp == nil and restore.record == HELLA .. "_o77s2", "Light RP's own fields stay out; the record is the spawned one")
assert(restore.paint.applied == false and restore.paint.primary == nil and restore.paint.secondary == nil, "a factory layer sends no colour channel (it would repaint)")
assert(#since(n, car) == 1, "one bag publish for the whole look")
assert(same(lookOf(car), confirmed), "the car wears exactly the stored look")
assert(same(world[car].bag["open77.visual"].profile, "hella_tt_1") and world[car].bag.lightrpPlate == "ABC1234", "the bag a late joiner reads holds it")
print("audit 4: store + retrieve: stage record + trim at create, one setProperties, one publish, exact look")

-- 5. Server restart with the car out: towed free, recovered with the same look -----------
boot()
assert(entry(hella).status == "impound" and entry(hella).impound.fee == 0, "out at a restart: impound, free")
assert(perform("recover", hella)); car = nextVehicle
assert(same(lookOf(car), confirmed) and world[car].record == HELLA .. "_o77s2", "the look survives the reboot")
-- Staff tow, lost (removed), destroyed (insurance): the look never moves.
assert(G.towLive(car)); assert(perform("recover", hella, 1, { pay = "bank" })); car = nextVehicle
assert(same(lookOf(car), confirmed), "staff tow keeps the look")
V.remove(car); assert(entry(hella).status == "impound")
assert(perform("recover", hella, 1, { pay = "bank" })); car = nextVehicle
assert(same(lookOf(car), confirmed), "a lost car keeps the look")
world[car].destroyed, world[car].health = true, 0; event("onVehicleDamageChanged", tostring(car)); V.remove(car)
assert(entry(hella).impound.fee == C.impound.fees.destroyed)
assert(perform("recover", hella, 1, { pay = "bank" })); car = nextVehicle
assert(same(lookOf(car), confirmed) and world[car].health == 1, "the insurance repairs the wreck and keeps its look")
print("audit 5: restart (impound, free), staff tow, lost and destroyed: same look")

-- 6. Two characters on one account; a character switch while the car is out -----------
chars[1].key = "slot2"
assert(not G.beginCustomization(1, hella, "other", "citycenter"), "the other character cannot open this car")
G.open(1, "citycenter"); assert(#lastDialog.vehicles == 0, "nor list it")
local _, slot2car = G.grant(1, "galena")
assert(dbRows[slot2car].character_key == "slot2" and dbRows[hella].character_key == "default", "ownership is per character")
autosave()
assert(same(storedLook(hella), confirmed), "the default character's car keeps its look while slot2 plays")
chars[1].key = "default"
store(hella); car = retrieve(hella)
assert(same(lookOf(car), confirmed), "back on the owning character: same look")
print("audit 6: per-character ownership; a switch never touches the other character's look")

-- 7. Failures never wipe the stored look ---------------------------------------------------
store(hella)
-- A visual this build refuses: the car comes out without it; the stored look stays.
failSetProperties = "visual"; car = retrieve(hella); failSetProperties = nil
assert(world[car].visual.profile == nil and world[car].visual.neon == nil and logged("delivered without its visual"), "delivered without its visual")
autosave(); store(hella)
assert(same(storedLook(hella).visual, confirmed.visual), "autosave and store keep the refused visual stored (dormant)")
car = retrieve(hella); assert(same(lookOf(car), confirmed), "worn again once accepted")
store(hella)
-- setProperties refused outright: no delivery, nothing written.
local before = dbRows[hella].properties
failSetProperties = "all"; assert(not perform("retrieve", hella)); failSetProperties = nil
assert(dbRows[hella].properties == before and entry(hella).status == "stored" and not world[nextVehicle], "a refused restore delivers nothing and writes nothing")
-- The database down during autosaves: retried, never a partial write.
car = retrieve(hella); world[car].health = 0.7; event("onVehicleUpdated", tostring(car))
before = dbRows[hella].properties
failDb = true; autosave(); failDb = false
assert(dbRows[hella].properties == before, "nothing written while SQL is down")
autosave(); assert(stored(hella).health == 0.7 and same(storedLook(hella).visual, confirmed.visual), "written on the next autosave, look intact")
-- A corrupt row is quarantined and never overwritten.
store(hella)
dbRows.corrupt = { id = "corrupt", identifier = "alice", character_key = "default", model = "hella", record = HELLA, garage_id = "citycenter", properties = "not json", grant_key = "c", state = "stored", impound_fee = 0 }
boot()
assert(not perform("retrieve", "corrupt") and entry("corrupt").hint:find("staff"), "a corrupt row is refused, not reset")
autosave(); assert(dbRows.corrupt.properties == "not json", "and never overwritten")
dbRows.corrupt = nil
-- The model is gone from this build (create refuses the record): nothing is lost.
before = dbRows[hella].properties
dbRows[hella].record = "Vehicle.removed_model"; boot()
assert(not perform("retrieve", hella) and dbRows[hella].properties == before, "an unknown record refuses delivery and keeps the look")
dbRows[hella].record = HELLA; boot()
-- A kit part this server no longer lists: worn without it, kept dormant, back later.
local wing = catalogue[NS .. "wing_a"]; catalogue[NS .. "wing_a"] = nil
car = retrieve(hella)
assert(world[car].visual.parts[NS .. "wing_a"] == nil and world[car].visual.profile == "hella_tt_1", "the rest of the look is worn")
autosave(); store(hella)
assert(stored(hella).visual.parts[NS .. "wing_a"] == "carbon", "the dropped part stays stored")
catalogue[NS .. "wing_a"] = wing
car = retrieve(hella); assert(same(lookOf(car), confirmed), "and comes back with its part")
print("audit 7: refused visual, refused restore, SQL down, corrupt row, unknown record, dropped part: the stored look survives")

-- 8. A transfer (no such feature yet): the look is a property of the row, not of the owner -
store(hella)
dbRows[hella].identifier = "bob"; boot()
car = retrieve(hella, 2)
assert(same(lookOf(car), confirmed) and G.plateOf(car) == "ABC1234", "the new owner gets the same car, plate included")
store(hella, 2); dbRows[hella].identifier = "alice"; boot()
print("audit 8: properties travel with the row (owner columns only)")

-- 9. A pack livery whose resource stops while the car is out ----------------------------
-- The platform keeps the choice (dormant, getVisual still reads it, a restatement passes);
-- the record no longer lists it, so it cannot be set again once cleared.
car = retrieve(hella)
t = studio(hella)
assert(buy(t, { category = "livery", profile = PACK_LIVERY }) and stored(hella).visual.profile == PACK_LIVERY)
close(t)
packRunning = false
t = studio(hella); assert(close(t) and not G.isBusy(1), "an idle close releases the lease (nothing to re-set)")
t = studio(hella)
assert(preview(t, { category = "livery", profile = "hella_tt_2" }))
close(t)
local co = coroutine.create(worker); for _ = 1, 3 do assert(coroutine.resume(co)); tick = tick + 2000 end
assert(not G.isBusy(1), "a livery that can no longer be worn never holds the lease (garage, studio, character switch)")
assert(world[car].visual.profile == nil, "the preview is gone: the car wears its factory scheme")
autosave(); assert(stored(hella).visual.profile == PACK_LIVERY, "the bought pack livery stays stored (dormant)")
assert(logged("cannot wear its livery"), "and the server says why")
store(hella); packRunning = true
car = retrieve(hella); assert(world[car].visual.profile == PACK_LIVERY, "worn again once its pack runs")
t = studio(hella); assert(buy(t, { category = "livery", profile = "hella_tt_1" })); close(t)
confirmed = storedLook(hella)
print("audit 9: a pack livery stopped mid-session goes dormant on restore; the lease always closes")

-- 10. A plate preview is never durable, not even in the platform's copy (visual.plate) -----
t = studio(hella)
assert(preview(t, { category = "plate", plate = "PRV9999" }) and world[car].visual.plate == "PRV9999")
autosave()
assert(stored(hella).lightrp.plate == "ABC1234" and stored(hella).visual.plate == "ABC1234", "autosave keeps the registered plate in both copies")
assert(buy(t, { category = "neon", neon = { color = "#9B3CFF", intensity = 300, radius = 3 } }))
assert(stored(hella).visual.plate == "ABC1234", "another purchase never stores the plate preview")
-- The server stops with the preview on the car: the restart shows only the registered plate.
boot()
n = #publishes
assert(perform("recover", hella)); car = nextVehicle
for _, pub in ipairs(since(n, car)) do assert(pub.visual.plate ~= "PRV9999", "no viewer ever sees the unpaid plate after a restart") end
assert(world[car].visual.plate == "ABC1234" and world[car].bag.lightrpPlate == "ABC1234")
-- Buying a plate moves both copies together.
t = studio(hella); assert(buy(t, { category = "plate", plate = "NEW0001" })); close(t)
assert(stored(hella).lightrp.plate == "NEW0001" and stored(hella).visual.plate == "NEW0001")
store(hella); car = retrieve(hella)
n = #publishes; assert(world[car].visual.plate == "NEW0001" and G.plateOf(car) == "NEW0001")
print("audit 10: plate previews stay out of properties.visual.plate; a purchase moves both copies")

-- 11. Properties this server build does not know (written by a newer build, then a rollback) -
-- The platform names ONE unknown key per table (the alphabetically first), so two top-level
-- keys, one in paint and one in visual exercise every branch.
local function newerBuild(props)
    props.neonAnimation = { mode = "pulse", periodMs = 1200 }      -- wave-2 keys, top level
    props.lightColors = { brake = { r = 255, g = 120, b = 0 } }
    props.paint.pearl = 0.4                                          -- inside paint
    props.visual.stickers = { "st.hella.valentinos_01" }             -- inside visual
    return props
end
local function keptAll(props)
    return props.neonAnimation.mode == "pulse" and props.lightColors.brake.g == 120 and props.paint.pearl == 0.4
        and props.visual.stickers[1] == "st.hella.valentinos_01"
end
store(hella)
local newer = newerBuild(stored(hella))
-- Painted, so restorable hands setProperties the row's own paint table: stripping
-- paint.pearl from it in place would lose it from the row.
newer.paint.applied = true
newer.paint.primary, newer.paint.secondary = { r = 20, g = 30, b = 200 }, { r = 10, g = 10, b = 10 }
dbRows[hella].properties = json.encode(newer)
boot()
calls = {}; car = retrieve(hella)
assert(count("setProperties", car) == 5, "four refusals by name, each before anything is applied, then the restore")
assert(world[car].visual.profile == "hella_tt_1" and world[car].visual.neon and world[car].visual.wheels, "the car wears everything this build knows")
assert(logged("does not know: lightColors, neonAnimation, paint.pearl, visual.stickers"), "every skipped key is logged")
autosave()
assert(keptAll(stored(hella)), "an autosave keeps every key this build skipped")
t = studio(hella); assert(buy(t, { category = "windows", tint = 3 })); close(t)
assert(keptAll(stored(hella)) and stored(hella).visual.tint == 3, "so does a purchase")
store(hella)
assert(keptAll(stored(hella)), "and parking")
-- The newer build is back: everything is sent again, in one call.
PROPS.neonAnimation, PROPS.lightColors, PAINT.pearl, VISUAL.stickers = 1, 1, 1, 1
calls = {}; car = retrieve(hella)
assert(count("setProperties", car) == 1 and keptAll(calls[2].args[2]), "a build that knows them gets them back")
PROPS.neonAnimation, PROPS.lightColors, PAINT.pearl, VISUAL.stickers = nil, nil, nil, nil
-- The whole visual refused at spawn as well: every field, known or not, stays stored.
-- (The mock's newer build above accepts the keys without holding them: seed the row again.)
store(hella)
dbRows[hella].properties = json.encode(newerBuild(stored(hella))); boot()
failSetProperties = "visual"; car = retrieve(hella); failSetProperties = nil
autosave(); store(hella)
assert(keptAll(stored(hella)) and stored(hella).visual.profile == "hella_tt_1" and stored(hella).visual.tint == 3, "a dormant visual carries every field")
newer = stored(hella); newer.neonAnimation, newer.lightColors, newer.paint.pearl, newer.visual.stickers = nil, nil, nil, nil
dbRows[hella].properties = json.encode(newer); boot()
car = retrieve(hella)
print("audit 11: keys this build does not know are skipped at spawn, never wiped by autosave, purchase or parking")

-- 12. A rollback never parks an unpaid preview livery on the row ----------------------------
-- A failed purchase restores edit.shown, whose livery may be a preview. Its pack stopped
-- meanwhile and the car no longer wears it (the platform re-validated it against the record):
-- the restore cannot put it back. It used to be parked in row.dormant, as at retrieval; the
-- next save stored it over the factory scheme and it came back for free with its pack.
t = studio(hella)
assert(buy(t, { category = "livery", profile = "" }) and stored(hella).visual.profile == nil, "the factory scheme is the bought look")
assert(preview(t, { category = "livery", profile = PACK_LIVERY }) and world[car].visual.profile == PACK_LIVERY)
packRunning = false
local dropped = choices(world[car].visual); dropped.profile = nil; publish(world[car], dropped)
failDb = true; assert(not buy(t, { category = "neon", neon = { color = "#FFB000", intensity = 600, radius = 3 } })); failDb = false
close(t); assert(not G.isBusy(1), "the lease is released")
autosave()
assert(stored(hella).visual.profile == nil, "the unpaid preview livery is never stored")
packRunning = true
store(hella); car = retrieve(hella)
assert(world[car].visual.profile == nil, "nor comes back for free once its pack runs")
print("audit 12: a rollback restores the bought look and never parks a preview livery on the row")

print("vehicle persistence audit: purchase writes, preview masking, idle close, store/retrieve, restart, impound paths, characters, failures, transfer, dormant liveries, plate previews and unknown keys passed")
