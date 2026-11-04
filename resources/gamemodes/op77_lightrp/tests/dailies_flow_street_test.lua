-- Dailies fed by the street-side producers. tests/dailies_test.lua covers the
-- rotation, claims and the contracts the sampler feeds; here every contract is
-- driven through the module that raises its hook, loaded for real:
--   economy.lua      money.deposit / withdraw / transfer / pay, LightRP.money.addBank,
--                    /lightrp.givemoney                       -> onMoneyChanged, onMoneySent
--   inventory.lua    inventory.use / inventory.give, /lightrp.giveitem
--   consumables.lua  the timed consumption (ready / finish net events) -> onItemUsed, onItemGiven
--   refueling.lua    fuel.buy at a pump, a jerrycan through inventory.use, the
--                    fuel ready / finish net events            -> onRefuelled
--   fuel.lua         its own consumption tick, /lightrp.refuel -> onFuelLow, onFuelEmpty
--   housing.lua      enter / leave through its handlers (the homes Housewarming reads)
-- Only the host is stubbed: Open77.*, the CFX-style globals, json, the LightRP core
-- and the SQL driver. The staff command `give` hands each contract out; progress is
-- read from the `dailies` state the page gets. LightRP.dailies.sample is the
-- dailies module's own producer (seats, last drivers) and is the only dailies
-- function called directly.
math.randomseed(77)
local noop = function() end
local function clone(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = clone(x) end
    return t
end

-- json: a deterministic Lua-literal codec (sorted keys: inventory.lua compares encodings).
local function ser(v)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta < tb end
            return a < b
        end)
        local parts = {}
        for _, k in ipairs(keys) do
            local key = type(k) == "number" and ("[" .. tostring(k) .. "]") or ("[" .. string.format("%q", tostring(k)) .. "]")
            parts[#parts + 1] = key .. "=" .. ser(v[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v) end
    return tostring(v)
end
_G.json = {
    encode = ser,
    decode = function(s)
        if type(s) ~= "string" then error("json.decode expects a string") end
        local f = load("return " .. s, "=json", "t", {})
        if not f then error("invalid json") end
        return f()
    end,
}

dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("shared/consumables.lua"); dofile("shared/fuel.lua")
dofile("server/config/dailies.lua"); dofile("server/config/housing.lua")
local E = LightRpEvents.net

-- ---------------------------------------------------------------------------
-- The host

local clock, unixNow = 1000000, 0
local online, chars, pos, seats, anims, veh, bags, jobs, crews = {}, {}, {}, {}, {}, {}, {}, {}, {}
local messages, netEvents, events = {}, {}, {}
local loops, tag = {}, nil
local function tick(ms) clock = clock + ms end

-- Threads start at once (to their first Wait); the loops started while a module
-- loads are kept under its name and advanced one iteration at a time with step().
_G.CreateThread = function(fn)
    local co = coroutine.create(fn)
    if tag then loops[tag] = loops[tag] or {}; table.insert(loops[tag], co) end
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
end
_G.Wait = function() coroutine.yield() end
local function step(name)
    for _, co in ipairs(loops[name] or {}) do
        if coroutine.status(co) == "suspended" then
            local ok, err = coroutine.resume(co)
            assert(ok, err)
        end
    end
end

_G.GetPlayers = function()
    local t = {}
    for id in pairs(online) do t[#t + 1] = id end
    table.sort(t)
    for i, id in ipairs(t) do t[i] = tostring(id) end
    return t
end
_G.GetPlayerName = function(id) id = tonumber(id); return id and online[id] and chars[id] and chars[id].name or nil end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.GetUnixTime = function() return unixNow end
_G.GetPlayerRoutingBucket = function(id) local p = pos[tonumber(id)]; return p and p.bucket or 0 end
_G.SetPlayerRoutingBucket = function(id, b) pos[tonumber(id)].bucket = b end
_G.GetPlayersInBucket = function(b)
    local t = {}
    for id in pairs(online) do if pos[id] and pos[id].bucket == b then t[#t + 1] = id end end
    return t
end
_G.TriggerClientEvent = function(name, player, data) messages[#messages + 1] = { event = name, player = player, data = data } end
_G.RegisterNetEvent = function(name, fn) netEvents[name] = fn end
_G.AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end

-- SQL: the rows the modules read back are modelled, other writes are accepted.
local sql = { wallets = {}, inventories = {}, migrations = {}, ledger = {}, dailies = {}, meta = {},
    templates = {}, properties = {}, contracts = {} }
local function write(q, p)
    if q:find("INSERT INTO lightrp_inventories", 1, true) then
        sql.inventories[p[1]] = { items = p[6], slots = p[4], max_weight = p[5] }
    elseif q:find("INSERT INTO lightrp_cash_migrations", 1, true) then
        sql.migrations[p[1]] = { account_number = p[1] }
    elseif q:find("INSERT INTO lightrp_wallets", 1, true) then
        sql.wallets[p[1]] = { account_number = p[1], identifier = p[2], character_key = p[3], owner_name = p[4], cash = p[5], bank = p[6] }
    elseif q:find("SET cash = 0", 1, true) then sql.wallets[p[1]].cash = 0
    elseif q:find("SET bank = bank + ?", 1, true) then sql.wallets[p[2]].bank = sql.wallets[p[2]].bank + p[1]
    elseif q:find("SET bank = ?", 1, true) then sql.wallets[p[2]].bank = p[1]
    elseif q:find("SET owner_name", 1, true) then sql.wallets[p[2]].owner_name = p[1]
    elseif q:find("INSERT INTO lightrp_transactions", 1, true) then sql.ledger[#sql.ledger + 1] = clone(p)
    elseif q:find("INSERT INTO lightrp_dailies_meta", 1, true) then
        sql.meta[p[1]] = { streak = p[2], last_day = p[3], claimed = p[4], counts = p[5] }
    elseif q:find("INSERT INTO lightrp_dailies ", 1, true) then
        sql.dailies[p[1] .. "|" .. p[2]] = { period = p[2], state = p[3] }
    elseif q:find("DELETE FROM lightrp_dailies ", 1, true) then
        for i = 2, #p do sql.dailies[p[1] .. "|" .. p[i]] = nil end
    end
end
local Db = { ready = true, schema = noop }
function Db.run(q, p) write(q, p or {}); return true, 1 end
function Db.transaction(list) for _, w in ipairs(list) do write(w.query, w.values or {}) end return true end
function Db.read(q, p)
    p = p or {}
    if q:find("FROM lightrp_inventories", 1, true) then
        local r = sql.inventories[p[1]]; return true, r and { clone(r) } or {}
    elseif q:find("FROM lightrp_cash_migrations", 1, true) then
        local r = sql.migrations[p[1]]; return true, r and { clone(r) } or {}
    elseif q:find("FROM lightrp_wallets WHERE identifier", 1, true) then
        for _, w in pairs(sql.wallets) do
            if w.identifier == p[1] and w.character_key == p[2] then return true, { clone(w) } end
        end
        return true, {}
    elseif q:find("FROM lightrp_wallets WHERE account_number", 1, true) then
        local w = sql.wallets[p[1]]; return true, w and { clone(w) } or {}
    elseif q:find("FROM lightrp_transactions", 1, true) then return true, {}
    elseif q:find("FROM lightrp_dailies_meta", 1, true) then
        local m = sql.meta[p[1]]; return true, m and { clone(m) } or {}
    elseif q:find("FROM lightrp_dailies ", 1, true) then
        local out = {}
        for i = 2, #p do local r = sql.dailies[p[1] .. "|" .. p[i]]; if r then out[#out + 1] = clone(r) end end
        return true, out
    elseif q:find("FROM lightrp_housing_templates", 1, true) then return true, clone(sql.templates)
    elseif q:find("FROM lightrp_housing_properties", 1, true) then return true, clone(sql.properties)
    elseif q:find("FROM lightrp_housing_contracts", 1, true) then return true, clone(sql.contracts)
    elseif q:find("information_schema", 1, true) or q:find("FROM lightrp_vehicle_fuel", 1, true) then return true, {}
    end
    error("unmodelled read: " .. q)
end
function Db.single(q, p) local ok, rows = Db.read(q, p); return ok and rows[1] or nil end
function Db.query(q, p) local ok, rows = Db.read(q, p); return ok and rows or {} end

-- The LightRP core (server/core/framework.lua): modules in load order, hooks pcall'ed.
local logs, notices, results, states, dialogs = {}, {}, {}, {}, {}
local modules, actions, commands, providers = {}, {}, {}, {}
local byKey = {}
for _, entry in ipairs(LightRpConfig.vehicles.catalog) do byKey[entry.key] = entry end
_G.LightRP = {
    db = Db,
    nowMs = function() return clock end,
    log = function(fmt, ...)
        local ok, text = pcall(string.format, tostring(fmt), ...)
        logs[#logs + 1] = ok and text or tostring(fmt)
    end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = def; return def end,
    eachModule = function(hook, ...)
        for _, m in ipairs(modules) do
            local fn = m[hook]
            if type(fn) == "function" then
                local ok, err = pcall(fn, ...)
                if not ok then LightRP.log("module %s.%s failed: %s", m.name, hook, tostring(err)) end
            end
        end
    end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function(id, keys) states[#states + 1] = { id = id, keys = keys } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, kind = n.kind, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function(id, kind, payload) dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
    interaction = noop, removeInteraction = noop, sendInteractions = noop,
    batchInteractions = function(fn) fn() end,
    joinArgs = function(args, from)
        local count = args.n or #args
        from = from or 1
        if count < from then return "" end
        return (table.concat(args, " ", from, count)):gsub("^%s+", ""):gsub("%s+$", "")
    end,
    characters = {
        get = function(id) id = tonumber(id); return id and online[id] and chars[id] or nil end,
        displayName = function(id) id = tonumber(id); return chars[id] and chars[id].name or ("P" .. tostring(id)) end,
        switching = {},
    },
    jobs = { get = function(id) return { name = jobs[id] or "unemployed", grade = 0 } end },
    parties = { of = function(id) return crews[id] end },
    staff = { allowed = function() return false end },
    admin = { handlers = {} },
    vehicles = { byKey = byKey },
}

local playbacks = 0
_G.Open77 = {
    time = { unix = function() return unixNow end },
    players = {
        position = function(id)
            id = tonumber(id)
            local p = id and online[id] and pos[id]
            return p and { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } or nil
        end,
        positions = function()
            local out = {}
            for id in pairs(online) do
                local p = pos[id]
                if p then out[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } end
            end
            return out
        end,
        getLifeState = function(id) return online[tonumber(id)] and { phase = "alive" } or nil end,
        teleport = function(id, point, opts)
            return { await = function()
                pos[id] = { x = point.x, y = point.y, z = point.z, bucket = opts.bucket or 0 }
                return { success = true }
            end }
        end,
    },
    vehicles = {
        flags = { engineOn = 1, destroyed = 16 },
        get = function(v) local s = veh[tonumber(v)]; return s and clone(s) or nil end,
        all = function()
            local out = {}
            for _, s in pairs(veh) do out[#out + 1] = clone(s) end
            table.sort(out, function(a, b) return a.id < b.id end)
            return out
        end,
        getPlayerSeat = function(id)
            local s = seats[tonumber(id)]
            return s and { vehicleId = s.vehicleId, seat = s.seat } or nil
        end,
        getDriver = function(v)
            for id, s in pairs(seats) do
                if s.vehicleId == v and s.seat == "seat_front_left" and online[id] then return id end
            end
            return 0
        end,
        isEngineOn = function(v) local s = veh[v]; return s ~= nil and (s.flags & 1) ~= 0 end,
        isDrivable = function(v) local s = veh[v]; return s ~= nil and s.drivable ~= false end,
        -- an undrivable car (fuel.lua cut) also loses its engine and stops
        setDrivable = function(v, on)
            local s = veh[v]
            if s then s.drivable = on; if not on then s.flags = s.flags & ~1; s.speed = 0 end end
            return true
        end,
        setEngine = function(v, on) local s = veh[v]; if s then s.flags = on and (s.flags | 1) or (s.flags & ~1) end return true end,
        closest = function(player, opts)
            local p = pos[tonumber(player)]
            if not p then return nil end
            local best, bestD
            for id, s in pairs(veh) do
                if (s.bucket or 0) == (p.bucket or 0) then
                    local d = math.sqrt((s.x - p.x) ^ 2 + (s.y - p.y) ^ 2 + (s.z - p.z) ^ 2)
                    if d <= ((opts and opts.radius) or 10) and (not bestD or d < bestD) then best, bestD = id, d end
                end
            end
            return best and { id = best } or nil
        end,
        getHealth = function() return 1000 end,
    },
    animations = {
        current = function(id) return anims[tonumber(id)] end,
        play = function(id, profile)
            playbacks = playbacks + 1
            anims[id] = { active = true, playbackId = playbacks, profile = profile }
            return anims[id]
        end,
        playAt = function(id, profile) return Open77.animations.play(id, profile) end,
        stop = function(id, playbackId)
            local a = anims[id]
            if a and a.playbackId == playbackId then anims[id] = nil end
        end,
    },
    props = { create = function() return "prop" end, attach = function() return true end, remove = noop },
    state = { entity = function(_, id)
        bags[id] = bags[id] or {}
        local b = bags[id]
        return { get = function(_, k) return b[k] end, set = function(_, k, v) b[k] = v; return true end }
    end },
}

local function loadModule(path, name) tag = name; dofile(path); tag = nil end
loadModule("server/modules/inventory.lua", "inventory")
loadModule("server/modules/economy.lua", "economy")
loadModule("server/modules/consumables.lua", "consumables")
loadModule("server/modules/fuel.lua", "fuel")
loadModule("server/modules/refueling.lua", "refueling")
loadModule("server/modules/housing_store.lua", "housing_store")
loadModule("server/modules/housing.lua", "housing")
loadModule("server/modules/dailies.lua", "dailies")
step("refueling") -- the pumps register after the module's first Wait

-- One home: the owner is acc1 (Kaito), acc4 (Dex) holds a spare key, unlocked door.
local ENTRANCE = { x = -700.0, y = 880.0, z = 32.0, heading = 0 }
local SPAWN = { x = 1000.0, y = 2000.0, z = 100.0, heading = 0 }
sql.templates[1] = { id = "tpl-loft", revision = 1, deleted = 0, definition = json.encode({ label = "Loft", slots = 40, weight = 150,
    points = { spawn = SPAWN, exit = { x = 1000.5, y = 2000.0, z = 100.0, heading = 0 }, stash = { x = 1003.0, y = 2000.0, z = 100.0, heading = 0 } } }) }
sql.properties[1] = { id = 1, revision = 1, deleted = 0, contract_id = "lease-1", definition = json.encode({ label = "Home one",
    templateId = "tpl-loft", kind = "apartment", price = 50000, rent = 1000, rentDays = 7, enabled = true, entrance = ENTRANCE }) }
sql.contracts[1] = { id = "lease-1", property_id = 1, identifier = "acc1", character_key = "default", ended_at = 0,
    definition = json.encode({ mode = "purchase", entrance = ENTRANCE, label = "Home one", slots = 40, weight = 150, paid = 50000,
        locked = false, keys = { { identifier = "acc4", key = "default", name = "Dex" } } }) }
LightRP.eachModule("onDatabaseReady")
assert(LightRP.housing.available(), "housing loaded from the database")
local HOME_BUCKET = LightRpHousing.bucketBase + 1

local D = LightRP.dailies
local PUMP = LightRpConfig.fuel.stations[1]
local P = PUMP.position

-- ---------------------------------------------------------------------------
-- Helpers: players, the page state, staff tools

local function at(id, x, y, z, bucket) pos[id] = { x = x, y = y, z = z or 0, bucket = bucket or 0 } end
local function join(id, account, name, opts)
    opts = opts or {}
    chars[id] = { status = "active", identifier = account, key = opts.key or "default", name = name,
        playtimeMs = 360000000, joinedAtMs = clock }
    online[id] = true
    pos[id] = opts.at or { x = 0, y = 0, z = 0, bucket = 0 }
    LightRP.eachModule("onCharacterLoaded", id, chars[id])
    assert(LightRP.inventory.player(id) and LightRP.money.get(id), name .. ": inventory and wallet loaded")
end
local function leave(id) online[id] = nil; LightRP.eachModule("onDisconnected", id) end
local D0 = 20395 -- Monday 2025-11-03
local function goDay(d) unixNow = d * 86400 + 10 * 3600 end
local function staff(...) return commands["lightrp.dailies"](0, { ... }) end
local function give(id, contractId) local ok, text = staff("give", tostring(id), contractId); assert(ok, text) end
local function card(id, contractId)
    for _, c in ipairs(providers.dailies(id).list or {}) do if c.id == contractId then return c end end
    error("no " .. contractId .. " card for " .. tostring(id))
end
local function isDone(id, contractId) return card(id, contractId).done == true end
local function value(id, contractId) return card(id, contractId).value end
local function noticed(id, title, pattern)
    for i = #notices, 1, -1 do
        local n = notices[i]
        if n.id == id and (not title or n.title == title) and (not pattern or (n.body or ""):find(pattern, 1, true)) then return true end
    end
    return false
end
local function lastResult(id)
    for i = #results, 1, -1 do if results[i].id == id then return results[i] end end
end
local function lastNotice(id)
    for i = #notices, 1, -1 do if notices[i].id == id then return notices[i].title .. ": " .. tostring(notices[i].body) end end
    return "-"
end
local function stock(id, item, n)
    local ok, text = commands["lightrp.giveitem"](0, { tostring(id), item, tostring(n or 1) })
    assert(ok, text)
end
local function slotOf(id, name)
    local inv = LightRP.inventory.player(id)
    for s = 1, inv.slots do local it = inv.items[s]; if it and it.name == name then return s end end
end
local function lastMessage(event, player, phase, from)
    for i = #messages, from or 1, -1 do
        local m = messages[i]
        if m.event == event and m.player == player and (not phase or m.data.phase == phase) then return m.data end
    end
end
local function net(name, player, data) _G.source = player; netEvents[name](data) end

-- inventory.use on food or a drink: the timed consumption, as the client plays it.
local function beginUse(id, name)
    local slot = assert(slotOf(id, name), name .. " in the pocket of " .. id)
    local mark = #messages
    actions["inventory.use"](id, { slot = slot })
    local prep = lastMessage(E.consume, id, "prepare", mark + 1)
    assert(prep, "use refused: " .. tostring(lastResult(id) and lastResult(id).text))
    net(E.consumeReady, id, { token = prep.token })
    local play = assert(lastMessage(E.consume, id, "play", mark + 1), "the consume animation did not start")
    return { id = id, token = prep.token, durationMs = play.durationMs }
end
local function finishUse(u)
    local mark = #messages
    net(E.consumeFinish, u.id, { token = u.token, status = "success" })
    local done = assert(lastMessage(E.consume, u.id, "finished", mark + 1), "no finish")
    assert(done.ok == true, "the item was not consumed: " .. lastNotice(u.id))
end
local function use(id, name) local u = beginUse(id, name); tick(u.durationMs); finishUse(u) end
-- Two citizens finishing within `gapMs` of each other.
local function together(a, b, name, gapMs)
    local ua, ub = beginUse(a, name), beginUse(b, name)
    tick(math.max(ua.durationMs, ub.durationMs)); finishUse(ua)
    tick(gapMs or 1000); finishUse(ub)
end
-- inventory.give: one unit to the closest citizen within reach.
local function hand(from, item, to)
    local slot = assert(slotOf(from, item), item .. " in the pocket of " .. from)
    actions["inventory.give"](from, { slot = slot, count = 1 })
    local r = lastResult(from)
    assert(r and r.ok, "hand-over refused: " .. tostring(r and r.text))
    assert(r.text:find("handed to " .. chars[to].name .. ".", 1, true), "handed to the wrong citizen: " .. r.text)
end

-- Money through economy.lua's own actions.
local function money(id) return providers.money(id) end
local function bank(id) return money(id).bank.balance end
local function transfer(from, to, amount)
    actions["money.transfer"](from, { to = money(to).bank.number, amount = amount })
    local r = lastResult(from); assert(r.ok, r.text)
end
local function payCash(from, to, amount)
    actions["money.pay"](from, { target = to, amount = amount })
    local r = lastResult(from); assert(r.ok, r.text)
end

-- Vehicles, fuel.lua's tick, refueling.lua's sessions.
local function car(id, key, x, y, z)
    veh[id] = { id = id, record = byKey[key].record, x = x, y = y, z = z or 0, bucket = 0, speed = 0, flags = 0 }
end
local function moveCar(id, x, y, z) local v = veh[id]; v.x, v.y, v.z = x, y, z or v.z end
local function staffRefuel(v, litres)
    local ok, text = commands["lightrp.refuel"](0, { tostring(v), tostring(litres) })
    assert(ok, text)
end
local function litres(v) return LightRP.fuel.info(v).litres end
local function drive(id, v)
    seats[id] = { vehicleId = v, seat = "seat_front_left" }
    veh[v].flags, veh[v].speed = veh[v].flags | 1, 30
    at(id, veh[v].x, veh[v].y, veh[v].z)
end
local function park(id, v)
    seats[id] = nil
    veh[v].flags, veh[v].speed = veh[v].flags & ~1, 0
end
local function fuelTicks(n) for _ = 1, n do tick(1000); step("fuel") end end
-- fuel.buy at pump01, walk to the car, fill, as the page and the client do.
-- midway(): run halfway through the pump animation (a sample, somebody moving).
local function fill(id, v, amount, pay, midway)
    local mark = #messages
    actions["fuel.buy"](id, { spot = PUMP.id, vehicle = v, litres = amount, pay = pay or "bank" })
    local prep = lastMessage(E.fuel, id, "prepare", mark + 1)
    assert(prep, "pump refused: " .. tostring(lastResult(id) and lastResult(id).text))
    net(E.fuelReady, id, { token = prep.token })
    assert(lastMessage(E.fuel, id, "approach", mark + 1), "no approach phase")
    net(E.fuelReady, id, { token = prep.token })
    local play = assert(lastMessage(E.fuel, id, "play", mark + 1), "the pump did not start: " .. lastNotice(id))
    if midway then
        local half = math.floor(play.durationMs / 2)
        tick(half); midway(); tick(play.durationMs - half)
    else
        tick(play.durationMs)
    end
    net(E.fuelFinish, id, { token = prep.token, status = "success" })
    local fin = assert(lastMessage(E.fuel, id, "finished", mark + 1))
    assert(fin.ok == true, "the fill did not settle: " .. lastNotice(id))
end
-- A jerrycan used from the inventory into the closest parked car.
local function pour(id)
    local mark = #messages
    actions["inventory.use"](id, { slot = assert(slotOf(id, "jerrycan"), "a full jerrycan on " .. id) })
    local prep = lastMessage(E.fuel, id, "prepare", mark + 1)
    assert(prep, "pour refused: " .. lastNotice(id))
    net(E.fuelReady, id, { token = prep.token })
    local play = assert(lastMessage(E.fuel, id, "play", mark + 1), "the pour did not start: " .. lastNotice(id))
    tick(play.durationMs)
    net(E.fuelFinish, id, { token = prep.token, status = "success" })
    local fin = assert(lastMessage(E.fuel, id, "finished", mark + 1))
    assert(fin.ok == true, "the pour did not settle: " .. lastNotice(id))
end

goDay(D0)
join(1, "acc1", "Kaito")
join(2, "acc2", "Rosa")
join(3, "acc3", "Vivi")
join(4, "acc4", "Dex")

-- ---------------------------------------------------------------------------
-- Ledger's Lucky Number: the bank balance ends in 777 after a real payment.

give(1, "lucky_number")
assert(bank(1) == 1500 and money(1).cash == 250, "a new wallet")
assert(not commands["lightrp.givemoney"](0, { "1", "cash", "1000" }), "a staff grant needs a reason (economy-balance.md section 16)")
assert(commands["lightrp.givemoney"](0, { "1", "cash", "1000", "test", "grant" }))
-- economy.lua move() (deposit / withdraw) raises onMoneyChanged for the cash wallet
-- only: the bank side is silent, so ignoreKinds' deposit/withdraw never come into play.
actions["money.deposit"](1, { amount = 277 })
assert(lastResult(1).ok and bank(1) == 1777, "deposit to 1777")
assert(not isDone(1, "lucky_number"), "a deposit is not a payment")
actions["money.withdraw"](1, { amount = 1000 })
assert(lastResult(1).ok and bank(1) == 777, "withdraw to 777")
assert(not isDone(1, "lucky_number"), "a withdrawal is not a payment")
transfer(2, 1, 1000)
assert(bank(1) == 1777 and not isDone(1, "lucky_number"), "a transfer received is not a payment")
transfer(1, 2, 1000)
assert(bank(1) == 777 and not isDone(1, "lucky_number"), "a transfer sent is not a payment")
payCash(1, 2, 196)
assert(money(1).cash == 1777 and not isDone(1, "lucky_number"), "the cash wallet does not count")
assert(LightRP.money.addBank(1, 80, "salary", "Paycheck", "Job Center"))
assert(bank(1) == 857 and not isDone(1, "lucky_number"), "a wage that lands on 857")
car(10, "cortes", P.x + 3, P.y, P.z); staffRefuel(10, 30)
at(1, P.x + 1, P.y, P.z)
fill(1, 10, 20, "bank")
assert(bank(1) == 777 and isDone(1, "lucky_number"), "a fill-up paid from the bank lands on 777")
moveCar(10, P.x + 300, P.y, P.z)
-- A transfer that fails is refunded (economy.lua:525: a bank event of delta 0, kind
-- "refund"); landing back on 777 that way is not a payment. The receiving account is
-- offline and the SQL driver refuses its credit.
give(2, "lucky_number")
join(6, "acc6", "Jun"); local offlineAccount = money(6).bank.number; leave(6)
actions["money.withdraw"](2, { amount = (bank(2) - 777) % 1000 })
assert(lastResult(2).ok and bank(2) % 1000 == 777 and not isDone(2, "lucky_number"), "Rosa's bank on 777, silently")
local landing = bank(2)
local realRun = Db.run
Db.run = function(q, p)
    if q:find("SET bank = bank + ?", 1, true) then return false end
    return realRun(q, p)
end
actions["money.transfer"](2, { to = offlineAccount, amount = 10 })
Db.run = realRun
assert(lastResult(2).ok == false and bank(2) == landing, "the transfer failed and was refunded")
assert(not isDone(2, "lucky_number"), "a refund that lands on 777 is not a payment")
assert(LightRP.money.addBank(2, 1000, "salary", "Paycheck", "Job Center"))
assert(isDone(2, "lucky_number"), "a wage onto 777 still is")

-- ---------------------------------------------------------------------------
-- Nobody Eats Alone: two accounts finish a meal within 8 s and 15 m.

for id = 1, 4 do stock(id, "burrito", 5) end
goDay(D0 + 1)
for id = 1, 4 do give(id, "eat_together") end
at(1, 100, 0, 0); at(2, 105, 0, 0)
together(1, 2, "burrito", 3000)
assert(isDone(1, "eat_together") and isDone(2, "eat_together"), "two citizens eat together")
tick(20000)
at(3, 200, 0, 0); at(4, 216, 0, 0)
together(3, 4, "burrito", 1000)
assert(not isDone(3, "eat_together") and not isDone(4, "eat_together"), "16 m apart is not together")
tick(20000)
at(4, 205, 0, 0)
together(3, 4, "burrito", 9000)
assert(not isDone(3, "eat_together") and not isDone(4, "eat_together"), "9 s apart is not at the same time")
-- your own alt is not company
goDay(D0 + 2)
join(5, "acc1", "Kaito Alt", { key = "alt", at = { x = 300, y = 0, z = 0, bucket = 0 } })
give(1, "eat_together")
at(1, 304, 0, 0)
together(5, 1, "burrito", 2000)
assert(not isDone(1, "eat_together") and not isDone(5, "eat_together"), "the same account twice is not company")
tick(20000)
give(3, "eat_together"); at(3, 307, 0, 0)
together(1, 3, "burrito", 2000)
assert(isDone(1, "eat_together") and isDone(3, "eat_together"), "somebody of another account")
leave(5)
-- the same partner twice in one ISO week
goDay(D0 + 3)
for _, id in ipairs({ 1, 2, 4 }) do give(id, "eat_together") end
at(1, 400, 0, 0); at(2, 404, 0, 0); at(4, 408, 0, 0)
tick(20000)
together(1, 2, "burrito", 2000)
assert(not isDone(1, "eat_together") and not isDone(2, "eat_together"), "the same pair twice in a week")
assert(noticed(1, "DAILIES", "somebody new"), "told why")
tick(20000)
together(2, 4, "burrito", 2000)
assert(isDone(2, "eat_together") and isDone(4, "eat_together"), "somebody new the same day")
goDay(D0 + 7)
give(1, "eat_together"); give(2, "eat_together")
-- a soda feeds a little (food 5) but it is drunk from a can: not a meal
stock(1, "soda", 1); stock(2, "soda", 1)
tick(20000)
together(1, 2, "soda", 1000)
assert(not isDone(1, "eat_together") and not isDone(2, "eat_together"), "two sodas are not a meal")
tick(20000)
together(1, 2, "burrito", 2000)
assert(isDone(1, "eat_together") and isDone(2, "eat_together"), "a new week, the same friend again")

-- ---------------------------------------------------------------------------
-- Housewarming: a key holder hands a drink to a guest in the same home, the guest
-- drinks it there.

goDay(D0 + 8)
for _, id in ipairs({ 1, 3, 4 }) do give(id, "housewarming") end
local function enter(id, dx)
    local r, why = LightRP.admin.handlers.housing(id, { action = "enter", id = 1 })
    assert(r, "enter refused: " .. tostring(why))
    assert(LightRP.housing.sessions[id] and LightRP.housing.sessions[id].phase == "inside" and pos[id].bucket == HOME_BUCKET, "inside")
    at(id, SPAWN.x + (dx or 0), SPAWN.y, SPAWN.z, HOME_BUCKET)
end
local function exit(id)
    LightRP.housing.onInteract(id, "housing.exit.1")
    assert(LightRP.housing.sessions[id] == nil and pos[id].bucket == 0, "back in the street")
end
-- handed over in the street at the door: neither of them is in the home
at(1, ENTRANCE.x, ENTRANCE.y, ENTRANCE.z); at(2, ENTRANCE.x + 1, ENTRANCE.y, ENTRANCE.z)
at(3, ENTRANCE.x + 10, ENTRANCE.y, ENTRANCE.z); at(4, ENTRANCE.x + 12, ENTRANCE.y, ENTRANCE.z)
hand(1, "water", 2)
enter(1, 0); enter(2, 1)
use(2, "water")
assert(not isDone(1, "housewarming"), "a drink handed over in the street does not count")
-- an apple waters a little (drink 5) but it is eaten: not a drink
stock(1, "apple", 1)
hand(1, "apple", 2)
use(2, "apple")
assert(not isDone(1, "housewarming"), "an apple is not a drink")
-- the owner, inside
hand(1, "water", 2)
use(2, "water")
assert(isDone(1, "housewarming"), "the owner hands a guest a drink at home, the guest drinks it there")
-- a visitor without a key
at(3, ENTRANCE.x + 1, ENTRANCE.y, ENTRANCE.z); enter(3, 1.5)
hand(3, "water", 2)
use(2, "water")
assert(not isDone(3, "housewarming"), "not a key holder")
-- the spare key holder's guest walks out before drinking
at(4, ENTRANCE.x, ENTRANCE.y + 1, ENTRANCE.z); enter(4, 2.5)
hand(4, "water", 3)
exit(3)
use(3, "water")
assert(not isDone(4, "housewarming"), "drunk in the street, after leaving")
-- out and straight back in, no sampler pass in between: the gift went with the visit
enter(3, 1.5)
hand(4, "water", 3)
exit(3); enter(3, 1.5)
use(3, "water")
assert(not isDone(4, "housewarming"), "the gift went when the guest left")
hand(4, "water", 3)
use(3, "water")
assert(isDone(4, "housewarming"), "a spare key holder is a host too")
for _, id in ipairs({ 1, 2, 3, 4 }) do exit(id) end

-- ---------------------------------------------------------------------------
-- Bar Crawl: crewmates drinking together at 3 bars in 3 districts.

goDay(D0 + 9)
local function bar(id)
    for _, place in ipairs(LightRpConfig.mapPlaces.places) do if place.id == id then return place end end
    error("no bar " .. id)
end
local crew = { id = "crew1", leader = 1, members = { 1, 2 } }
crews[1], crews[2] = crew, crew
for _, id in ipairs({ 1, 2, 3 }) do give(id, "bar_crawl"); stock(id, "water", 8) end
local afterlife, hooh, coyote, center = bar("bar_963"), bar("bar_167"), bar("bar_188"), bar("bar_967")
assert(afterlife.district == "Watson" and hooh.district == "Watson" and coyote.district == "Heywood" and center.district == "City Center")
local function drinkAt(place, a, b, item)
    at(a, place.position.x, place.position.y, place.position.z)
    at(b, place.position.x + 2, place.position.y, place.position.z)
    together(a, b, item or "water", 1000)
end
at(1, afterlife.position.x + 40, afterlife.position.y, afterlife.position.z)
at(2, afterlife.position.x + 42, afterlife.position.y, afterlife.position.z)
together(1, 2, "water", 1000)
assert(value(1, "bar_crawl") == 0 and value(2, "bar_crawl") == 0, "40 m from the bar is not at the bar")
drinkAt(afterlife, 1, 3)
assert(value(1, "bar_crawl") == 0 and value(3, "bar_crawl") == 0, "not crewmates")
tick(601000) -- those drinks are no longer "together" with anything
stock(1, "apple", 1); stock(2, "apple", 1)
drinkAt(afterlife, 1, 2, "apple")
assert(value(1, "bar_crawl") == 0 and value(2, "bar_crawl") == 0, "an apple at the bar is not a drink")
drinkAt(afterlife, 1, 2)
assert(value(1, "bar_crawl") == 1 and value(2, "bar_crawl") == 1, "the first bar")
tick(300000); drinkAt(hooh, 1, 2)
assert(value(1, "bar_crawl") == 1, "a second Watson bar is the same district")
tick(300000); drinkAt(coyote, 2, 1)
assert(value(1, "bar_crawl") == 2 and value(2, "bar_crawl") == 2 and not isDone(1, "bar_crawl"), "two districts")
tick(300000); drinkAt(center, 1, 2)
assert(isDone(1, "bar_crawl") and isDone(2, "bar_crawl"), "three bars in three districts within the hour")
crews[1], crews[2] = nil, nil

-- ---------------------------------------------------------------------------
-- Fare Paid, the payment: after a 1.2 km ride (the sampler), at least 6 from the
-- passenger within 3 minutes, through a bank transfer or cash in hand.

local function ride(driver, passenger)
    seats[driver] = { vehicleId = 50, seat = "seat_front_left" }
    seats[passenger] = { vehicleId = 50, seat = "seat_back_right" }
    at(driver, 1000, -3000, 0); at(passenger, 1001, -3000, 0)
    tick(5000); D.sample(5)
    for _ = 1, 14 do
        pos[driver].x, pos[passenger].x = pos[driver].x + 90, pos[passenger].x + 90
        tick(5000); D.sample(5)
    end
    seats[passenger] = nil
    tick(5000); D.sample(5)
    seats[driver] = nil
end
goDay(D0 + 10)
jobs[1] = "taxi"
give(1, "fare_paid")
ride(1, 2)
transfer(2, 1, 5)
assert(not isDone(1, "fare_paid"), "5 does not cover the fuel")
at(3, pos[1].x + 2, pos[1].y, 0)
transfer(3, 1, 50); payCash(3, 1, 50)
assert(not isDone(1, "fare_paid"), "paid by somebody who was not in the car")
transfer(2, 1, 6)
assert(isDone(1, "fare_paid"), "the passenger pays the fare by transfer")
goDay(D0 + 11)
give(1, "fare_paid")
ride(1, 4)
tick(181000); payCash(4, 1, 6)
assert(not isDone(1, "fare_paid"), "more than 3 minutes after the ride")
ride(1, 4)
payCash(4, 1, 5)
assert(not isDone(1, "fare_paid"), "5 in cash is still too little")
payCash(4, 1, 6)
assert(isDone(1, "fare_paid"), "the passenger pays the fare in cash")
jobs[1] = nil

-- ---------------------------------------------------------------------------
-- Running on Fumes: a pump fill from under 10 % to at least 50 %.

goDay(D0 + 12)
give(3, "running_on_fumes")
car(60, "cortes", P.x + 3, P.y, P.z) -- Street: 55 L
car(61, "apollo", P.x + 300, P.y, P.z) -- Bikes: 30 L
at(3, P.x + 1, P.y, P.z)
staffRefuel(60, 6); fill(3, 60, 25)
assert(litres(60) == 31 and not isDone(3, "running_on_fumes"), "6/55 L is above 10 %")
staffRefuel(60, 5); fill(3, 60, 20)
assert(litres(60) == 25 and not isDone(3, "running_on_fumes"), "25/55 L is under 50 %")
moveCar(60, P.x + 300, P.y + 10, P.z)
moveCar(61, P.x + 3, P.y, P.z); staffRefuel(61, 2)
stock(3, "jerrycan", 1); pour(3)
assert(litres(61) == 22 and not isDone(3, "running_on_fumes"), "2 -> 22/30 L with a jerrycan does not count")
moveCar(61, P.x + 300, P.y, P.z)
moveCar(60, P.x + 3, P.y, P.z); staffRefuel(60, 5); fill(3, 60, 23)
assert(litres(60) == 28 and isDone(3, "running_on_fumes"), "5 -> 28/55 L at the pump")
moveCar(60, P.x + 300, P.y + 10, P.z)

-- ---------------------------------------------------------------------------
-- Roadside Assistance: a jerrycan into a stranger's car that crossed its reserve
-- or ran dry (fuel.lua's tick raises the call).

local RC, RM = { x = 300, y = 300, z = 0 }, { x = 400, y = 300, z = 0 }
car(70, "cortes", RC.x, RC.y, RC.z) -- Rosa's
car(71, "cortes", RM.x, RM.y, RM.z) -- Kaito's own
jobs[1] = "mechanic"
goDay(D0 + 14)
give(1, "roadside")
staffRefuel(70, 27)
at(1, RC.x + 2, RC.y, RC.z)
stock(1, "jerrycan", 1); pour(1)
assert(litres(70) == 47 and not isDone(1, "roadside"), "a car nobody called about")
staffRefuel(70, 8.3)
drive(2, 70); fuelTicks(2)
assert(noticed(1, "Mama Okoro", "on its reserve"), "the mechanic on shift hears the call")
park(2, 70); at(2, RC.x - 3, RC.y, RC.z)
stock(1, "jerrycan", 1); pour(1)
assert(isDone(1, "roadside"), "a stranger's car on its reserve")
goDay(D0 + 15)
give(1, "roadside")
staffRefuel(71, 0.1)
drive(1, 71); fuelTicks(3)
assert(LightRP.fuel.isEmpty(71), "Kaito's own car ran dry")
park(1, 71); at(1, RM.x + 2, RM.y, RM.z)
stock(1, "jerrycan", 1); pour(1)
assert(not isDone(1, "roadside"), "your own car is not a call")
-- Car 70 driven to its reserve again. A car driven after a fill re-arms its reserve
-- warning only by burning above 20 % (fuel.lua:288), hence the first tick at 30 L.
local function reserveCall(driver)
    staffRefuel(70, 30); drive(driver, 70); fuelTicks(1)
    staffRefuel(70, 8.3); fuelTicks(2)
    park(driver, 70); at(driver, RC.x - 3, RC.y, RC.z)
    at(1, RC.x + 2, RC.y, RC.z)
end
reserveCall(2)
stock(1, "jerrycan", 1); pour(1)
assert(not isDone(1, "roadside"), "Rosa again in the same ISO week")
assert(noticed(1, "DAILIES", "somebody new"), "told why")
reserveCall(3)
tick(31 * 60000)
stock(1, "jerrycan", 1); pour(1)
assert(not isDone(1, "roadside"), "Vivi's call is older than 30 minutes")
staffRefuel(70, 0.1)
drive(4, 70); fuelTicks(3)
assert(LightRP.fuel.isEmpty(70), "the car ran dry under Dex")
assert(noticed(1, "Mama Okoro", "is dry"), "the dry call reaches the mechanic")
park(4, 70); at(4, RC.x - 3, RC.y, RC.z)
stock(1, "jerrycan", 1); pour(1)
assert(isDone(1, "roadside"), "a stranger's dry car")

-- ---------------------------------------------------------------------------
-- Pit Crew: fill at the pump a car another account drove last, they stay within
-- 15 m, then they pay at least ceil(litres x price) within 3 minutes.

goDay(D0 + 16)
give(1, "pit_crew")
car(80, "cortes", P.x + 3, P.y, P.z)
staffRefuel(80, 10)
at(1, P.x + 1, P.y, P.z) -- the mechanic waits at the pump
drive(2, 80); veh[80].speed = 0
tick(5000); D.sample(5) -- Rosa drove it last
park(2, 80)
at(2, P.x + 4, P.y + 3, P.z)
local owed = math.ceil(20 * LightRpConfig.fuel.pricePerLitre)
local sample = function() D.sample(5) end -- a sample halfway through a fill
fill(1, 80, 20)
tick(181000); transfer(2, 1, owed)
assert(not isDone(1, "pit_crew"), "unpaid within 3 minutes")
fill(1, 80, 20, "bank", sample)
transfer(2, 1, owed - 1)
assert(not isDone(1, "pit_crew"), "paid less than the fuel")
transfer(3, 1, owed)
assert(not isDone(1, "pit_crew"), "paid by somebody else")
payCash(2, 1, owed)
assert(isDone(1, "pit_crew"), "the customer pays the fuel in cash")
-- Day two, same ISO week: Rosa is a used partner, so the customers change.
goDay(D0 + 17)
give(1, "pit_crew")
moveCar(80, P.x + 300, P.y + 20, P.z)
join(5, "acc1", "Kaito Alt", { key = "alt", at = { x = P.x + 5, y = P.y, z = P.z, bucket = 0 } })
car(81, "cortes", P.x + 3, P.y, P.z); staffRefuel(81, 10)
drive(5, 81); veh[81].speed = 0
tick(5000); D.sample(5) -- Kaito's other character drove it last
park(5, 81); at(5, P.x + 4, P.y + 3, P.z); at(1, P.x + 1, P.y, P.z)
fill(1, 81, 20)
payCash(5, 1, owed)
assert(not isDone(1, "pit_crew"), "a car of your own account")
leave(5)
moveCar(81, P.x + 300, P.y + 30, P.z)
moveCar(80, P.x + 3, P.y, P.z); staffRefuel(80, 10)
drive(3, 80); veh[80].speed = 0
tick(5000); D.sample(5) -- Vivi drove it last
park(3, 80)
at(1, P.x + 1, P.y, P.z); at(3, P.x + 21, P.y, P.z)
fill(1, 80, 20)
at(3, P.x + 4, P.y + 3, P.z)
payCash(3, 1, owed)
assert(not isDone(1, "pit_crew"), "the customer was 20 m away during the fill")
-- 21 m away at a sample in the middle of the fill, back for its end
fill(1, 80, 20, "bank", function()
    at(3, P.x + 21, P.y, P.z); D.sample(5)
    at(3, P.x + 4, P.y + 3, P.z)
end)
transfer(3, 1, owed)
assert(not isDone(1, "pit_crew"), "the customer walked off during the fill")
fill(1, 80, 20, "bank", sample)
transfer(3, 1, owed)
assert(isDone(1, "pit_crew"), "the customer pays the fuel by transfer")
jobs[1] = nil

-- ---------------------------------------------------------------------------
-- Walk of Shame (weekly, 2 steps): your car runs dry 1 km or more from the fuel
-- station, then your jerrycan goes into that same car.

goDay(D0 + 21)
give(4, "walk_of_shame")
car(91, "cortes", P.x + 300, P.y, P.z)
staffRefuel(91, 0.1)
drive(4, 91); fuelTicks(3)
assert(LightRP.fuel.isEmpty(91) and value(4, "walk_of_shame") == 0, "dry 300 m from the pumps is too early")
park(4, 91); at(4, P.x + 302, P.y, P.z)
stock(4, "jerrycan", 1); pour(4)
assert(not isDone(4, "walk_of_shame") and value(4, "walk_of_shame") == 0, "the can alone does nothing")
car(90, "cortes", 600, 600, 0)
staffRefuel(90, 0.1)
drive(4, 90); fuelTicks(3)
assert(LightRP.fuel.isEmpty(90) and value(4, "walk_of_shame") == 1, "dry far from the pumps: step one")
park(4, 90)
car(92, "cortes", 610, 600, 0); staffRefuel(92, 10)
at(4, 612, 600, 0)
stock(4, "jerrycan", 1); pour(4)
assert(litres(92) == 30 and value(4, "walk_of_shame") == 1 and not isDone(4, "walk_of_shame"), "a can into another car")
at(4, 602, 600, 0)
stock(4, "jerrycan", 1); pour(4)
assert(isDone(4, "walk_of_shame") and value(4, "walk_of_shame") == 2, "the can into the car that ran dry")

-- ---------------------------------------------------------------------------
-- No hook, check or settlement failed along the way.

for _, line in ipairs(logs) do
    assert(not line:find("failed", 1, true), "logged: " .. line)
end

print("dailies_flow_street_test: ok")
