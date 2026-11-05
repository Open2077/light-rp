-- Dailies (server/modules/dailies.lua), the host stubbed: the rotation (deterministic,
-- never twice in a row, each contract back within a cycle, sources skipped, frozen
-- once settled), the solo stand-ins and the social gate (a contract that needs other
-- people is never handed out on a quiet server, a started one is kept, no flip-flop),
-- the Roadside dispatch, the weekly partner rule, the crew placeholder, shift draws
-- per job, claims (budget, grace, streak, failure rollback, titles), the swap, the
-- staff tools (give / status / reset), the database round trip, the naming the player
-- sees, and the contracts the server samples itself (seats, positions, animations:
-- the sampler IS their producer, only the natives are stubbed). The contracts fed by
-- other modules are proven in tests/dailies_flow_*_test.lua with those modules loaded.
local clock = 0
local threads = {}
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end

local function ser(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", tostring(k)) .. "]")
            parts[#parts + 1] = key .. "=" .. ser(x)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v) end
    return tostring(v)
end
_G.json = { encode = ser, decode = function(s) local f = load("return " .. s); return f and f() end }

local unixNow = 0
local online, pos, seats, anims, health, records, drivers = {}, {}, {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(online) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.Open77 = {
    time = { unix = function() return unixNow end },
    players = {
        position = function(id) local p = pos[id]; return p and online[id] and { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } end,
        positions = function() local out = {} for id, p in pairs(pos) do if online[id] then out[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } end end return out end,
    },
    vehicles = {
        getPlayerSeat = function(id) return seats[id] end, getHealth = function(v) return health[v] end,
        get = function(v) return records[v] and { record = records[v] } or nil end,
        getDriver = function(v) return drivers[v] end,
    },
    animations = { current = function(id) return anims[id] end },
}

local chars, jobs, crews = {}, {}, {}
local modules, actions, commands, providers = {}, {}, {}, {}
local notices, results, dialogs, states, paid, awards = {}, {}, {}, {}, {}, {}
local payFails = false
local dbRows, dbMeta, dbFail, dbDeleted = {}, {}, false, {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def)
        def.name = name
        for i = #modules, 1, -1 do if modules[i].name == name then table.remove(modules, i) end end
        modules[#modules + 1] = def; LightRP[name] = def; return def
    end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function(id, keys) states[#states + 1] = { id = id, keys = keys } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, kind = n.kind, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function(id, kind, payload) dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
    characters = {
        get = function(id) return online[id] and chars[id] or nil end,
        displayName = function(id) return chars[id] and chars[id].name or ("P" .. id) end,
    },
    jobs = { get = function(id) return { name = jobs[id] or "unemployed", grade = 0 } end },
    parties = { of = function(id) return crews[id] end },
    money = {
        addBank = function(id, amount, kind, note, counterparty)
            if payFails then return false, "wallet_busy" end
            paid[#paid + 1] = { id = id, amount = amount, kind = kind, note = note, counterparty = counterparty }
            return true
        end,
        format = function(n) return "$" .. n end,
    },
    titles = { award = function(id, titleId) awards[#awards + 1] = { id = id, title = titleId } return true end, push = function() end },
    inventory = {}, refueling = {}, jobWork = {}, medical = {},
    vehicles = { byKey = { apollo = { record = "Vehicle.apollo", category = "Bikes" }, cortes = { record = "Vehicle.cortes", category = "Street" } } },
    housing = { available = function() return true end, sessions = {}, hasKey = function(id) return id == 1 end },
    housingStore = { contracts = { lease1 = {} } },
    missions = { point = function(id) return { id = id } end },
    activities = { registry = { ["chase.pve"] = {}, ["race.trial"] = {}, ["arena.pve"] = {}, ["arena.duel"] = {}, ["chase.wanted"] = {} } },
    worldBosses = { catalogue = function() return { { id = "boss" } } end },
    db = {
        ready = false, schema = function() end, single = function() end,
        run = function(sql, p)
            if dbFail then return false end
            if sql:find("INSERT INTO lightrp_dailies_meta", 1, true) then
                dbMeta[p[1]] = { streak = p[2], last_day = p[3], claimed = p[4], counts = p[5] }
            elseif sql:find("INSERT INTO lightrp_dailies ", 1, true) then
                dbRows[p[1] .. "|" .. p[2]] = { period = p[2], state = p[3] }
            elseif sql:find("DELETE FROM lightrp_dailies ", 1, true) then
                for i = 2, #p do dbRows[p[1] .. "|" .. p[i]] = nil; dbDeleted[#dbDeleted + 1] = p[i] end
            end
            return true
        end,
        read = function(sql, p)
            if sql:find("FROM lightrp_dailies_meta", 1, true) then local m = dbMeta[p[1]]; return true, m and { m } or {} end
            if sql:find("FROM lightrp_dailies ", 1, true) then
                local out = {}
                for i = 2, 5 do local r = dbRows[p[1] .. "|" .. p[i]]; if r then out[#out + 1] = r end end
                return true, out
            end
            return true, {}
        end,
    },
}
_G.LightRpDelivery = {}
_G.LightRpJobRuns = { routes = { ac_cleaner = { steps = { { kind = "lift" }, { kind = "work" }, { kind = "work" }, { kind = "work" }, { kind = "return" } } } } }
_G.LightRpActivities = { hub = { center = { x = 0, y = 0, z = 0 } } }
_G.LightRpEconomy = { hospital = { graceMinutes = 120 } }
_G.LightRpItems = { burrito = { use = { food = 35 } }, beer = { use = { drink = 20 } }, water = { use = { drink = 30 } },
    soda = { use = { drink = 20, food = 5 }, consumeAction = "can" }, apple = { use = { food = 12, drink = 5 }, consumeAction = "snack" } }
_G.LightRpConfig = {
    fuel = { pricePerLitre = 4, stations = { { id = "pump01", position = { x = -600, y = -700, z = 0 } } } },
    mapPlaces = { places = {
        { id = "bar_a", kind = "bar", district = "Watson", position = { x = 1000, y = 0, z = 0 } },
        { id = "bar_d", kind = "bar", district = "Watson", position = { x = 1100, y = 0, z = 0 } },
        { id = "bar_b", kind = "bar", district = "Heywood", position = { x = 2000, y = 0, z = 0 } },
        { id = "bar_c", kind = "bar", district = "Pacifica", position = { x = 3000, y = 0, z = 0 } },
        { id = "shop", kind = "shop", district = "Pacifica", position = { x = 3010, y = 0, z = 0 } },
    } },
}

dofile("server/config/dailies.lua")
assert(LightRpDailies.rewards.action == 275 and LightRpDailies.dailyBudget == 800, "shipped 2026-11-05 numbers")
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
LightRpDailies.rewards = { street = 250, action = 400, shift = 250, crew = 300, weekly = 3000 }; LightRpDailies.dailyBudget = 1200
dofile("server/modules/dailies.lua")
local D, C = LightRP.dailies, LightRpDailies

-- Monday 2025-11-03, 01:00 UTC
local D0 = 20395
local function goDay(d, hour) unixNow = d * 86400 + (hour or 1) * 3600 end
goDay(D0)
local W0 = D.weekOf(D0)

local function join(id, account, name, opts)
    opts = opts or {}
    chars[id] = { status = "active", identifier = account, key = "default", name = name, playtimeMs = opts.playtimeMs or 360000000, joinedAtMs = clock }
    online[id] = true
    pos[id] = opts.at or { x = 0, y = 0, z = 0, bucket = 0 }
    LightRP.eachModule("onCharacterLoaded", id)
end
local function leave(id) online[id] = nil; LightRP.eachModule("onDisconnected", id) end
local function view(id) return providers.dailies(id) end
local function card(id, contractId)
    for _, c in ipairs(view(id).list or {}) do if c.id == contractId then return c end end
end
local function slotCard(id, slot)
    for _, c in ipairs(view(id).list or {}) do if c.slot == slot then return c end end
end
local function isDone(id, contractId) local c = card(id, contractId); return c ~= nil and c.done == true end
local function noticed(id, title, pattern)
    for i = #notices, 1, -1 do
        local n = notices[i]
        if n.id == id and (not title or n.title == title) and (not pattern or (n.body or ""):find(pattern, 1, true)) then return true end
    end
    return false
end
local function claim(id, contractId) actions["dailies.claim"](id, { id = contractId }); return results[#results] end
local function swap(id, slot) actions["dailies.swap"](id, { slot = slot }); return results[#results] end
local function staff(...) return commands["lightrp.dailies"](0, { ... }) end
local function give(id, contractId) local ok, text = staff("give", tostring(id), contractId); assert(ok, text); return ok end
local function values(v)
    if type(v) ~= "table" then return 1 end
    local n = 0
    for _, x in pairs(v) do n = n + values(x) end
    return n
end
local function moveAll(dx, ids) for _, id in ipairs(ids) do pos[id].x = pos[id].x + dx end end
local function tick(ms) clock = clock + ms end
local function idOf(def) return def and def.id or "-" end

-- ── basics: FNV-1a, UTC day, Monday weeks ──
assert(D.hash("a") == 0xe40c292c, "FNV-1a")
assert(D.day() == D0 and D.week() == W0, "day and week from server time")
assert(D.weekOf(D0 - 1) == W0 - 1 and D.weekOf(D0 + 6) == W0 and D.weekOf(D0 + 7) == W0 + 1, "weeks start on Monday")

-- eating or drinking is what the player does (consumeAction), the stats only without one
assert(D.consumeKind("soda") == "drink" and D.consumeKind("apple") == "meal", "a soda is a drink, an apple is food")
assert(D.consumeKind("beer") == "drink" and D.consumeKind("burrito") == "meal" and D.consumeKind("nope") == nil)

-- ── the rotation ──
for _, slot in ipairs({ "street", "action", "crew" }) do
    local n = 0
    for _, def in ipairs(C.contracts) do if def.slot == slot then n = n + 1 end end
    local last, seen = nil, {}
    for d = D0 - 400, D0 + 400 do
        local def = D.dayDraw(d)[slot]
        assert(def and def.slot == slot, slot .. " drawn")
        assert(def.id ~= last, slot .. " never the same two days in a row (day " .. d .. ")")
        if seen[def.id] then assert(d - seen[def.id] <= 2 * n - 1, slot .. " " .. def.id .. " back within a cycle") end
        seen[def.id], last = d, def.id
        if d % n == n - 1 and d - n + 1 >= D0 - 400 then
            local set = {}
            for k = d - n + 1, d do set[D.dayDraw(k)[slot].id] = true end
            local count = 0
            for _ in pairs(set) do count = count + 1 end
            assert(count == n, slot .. " cycle holds every contract once")
        end
    end
end
local lastWeekly
for w = W0 - 60, W0 + 60 do
    local def = D.weekDraw(w)
    assert(def and def.slot == "weekly" and def.id ~= lastWeekly, "weekly never twice in a row")
    lastWeekly = def.id
end
-- the solo stand-ins: never a social contract, never the same two periods in a row
for _, slot in ipairs({ "street", "action", "weekly" }) do
    local last
    for d = D0 - 100, D0 + 100 do
        local def = D.soloDraw(slot, d)
        assert(def and def.slot == slot and not def.social, slot .. " solo stand-in is solo")
        assert(def.id ~= last, slot .. " solo stand-in changes every period")
        last = def.id
    end
end
-- a missing source is never drawn (op77_chase stopped: no NCPD Escape)
LightRP.activities.registry["chase.pve"] = nil
for d = D0, D0 + 60 do
    local dd = D.dayDraw(d)
    assert(dd.action.id ~= "lose_them" and dd.action.id ~= "leg_day" and dd.crew.id ~= "nobody_left_behind", "chase.pve contracts skipped")
end
LightRP.activities.registry["chase.pve"] = {}
-- shift: the job's own order; a single-contract job every other day; nil = a Street day
for d = D0, D0 + 30 do
    local a, b = D.shiftDraw(d, "delivery"), D.shiftDraw(d - 1, "delivery")
    assert((a.id == "two_wheels" or a.id == "fragile") and a.id ~= b.id, "courier shift alternates")
    local s = D.shiftDraw(d, "sanitation")
    assert(s.id == "full_truck" or s.id == "full_round", "sanitation shift")
    local m = D.shiftDraw(d, "mechanic")
    assert(m.id == "roadside" or m.id == "pit_crew", "mechanic shift")
    assert(idOf(D.shiftDraw(d, "trauma")) == (d % 2 == 0 and "on_call" or "-"), "one contract: every other day")
    assert(idOf(D.shiftDraw(d, "ac_cleaner")) == (d % 2 == 0 and "water_break" or "-"))
    assert(D.shiftDraw(d, "ncpd") == nil and D.shiftDraw(d, "unemployed") == nil, "no contracts: a Street day")
end
-- frozen once the server settled: a source stopping later changes nothing today
clock = 130000
local frozen = D.dayDraw(D0).action.id
LightRP.activities.registry["race.trial"], LightRP.activities.registry["chase.pve"], LightRP.activities.registry["arena.pve"] = nil, nil, nil
LightRP.missions = nil
assert(D.dayDraw(D0).action.id == frozen, "today's draw is frozen")
LightRP.missions = { point = function(id) return { id = id } end }
LightRP.activities.registry = { ["chase.pve"] = {}, ["race.trial"] = {}, ["arena.pve"] = {}, ["arena.duel"] = {}, ["chase.wanted"] = {} }

-- ── the page state, a quiet server ──
join(1, "acc1", "Kaito")
join(2, "acc2", "Rosa", { playtimeMs = 3600000, at = { x = 5, y = 0, z = 0, bucket = 0 } })
local v = view(1)
assert(v.enabled and v.ready and v.day == D0 and #v.list == 5, "five cards")
local slots = {}
for _, c in ipairs(v.list) do slots[c.slot] = c end
assert(slots.street and slots.action and slots.shift and slots.crew and slots.weekly, "one per slot")
assert(not slots.street.social and not slots.shift.social and not slots.weekly.social, "two accounts online: nothing that needs a crowd")
assert(D.defs[slots.shift.id].slot == "street" and slots.shift.id ~= slots.street.id, "unemployed: a Street contract, not the street slot's")
assert(slots.street.reward == 250 and slots.action.reward == 400 and slots.shift.reward == 250 and slots.crew.reward == 300 and slots.weekly.reward == 3000)
assert(slots.crew.needsCrew == true and slots.crew.crewLocked == true, "no crewmate: the crew card is locked")
assert(slots.street.swappable == true and slots.crew.swappable == nil and slots.weekly.swappable == nil)
assert(v.resetInMs == (86400 - 3600) * 1000 and v.weekResetInMs == (7 * 86400 - 3600) * 1000, "countdowns")
assert(v.budget.used == 0 and v.budget.max == 1200 and v.swapsLeft == 1 and v.streak == 0)
assert(values(v) < 320, "dailies state stays small: " .. values(v))
actions["dailies.open"](1, { tab = "titles" })
assert(dialogs[#dialogs].kind == "dailies" and dialogs[#dialogs].payload.tab == "titles", "F1 opens the panel on a tab")
actions["dailies.open"](1, { tab = "x" })
assert(dialogs[#dialogs].payload.tab == "today")
local nStates, nDialogs = #states, #dialogs
actions["dailies.refresh"](1)
assert(#states == nStates + 1 and states[#states].keys[1] == "dailies" and #dialogs == nDialogs, "the terminal tab refreshes without a dialog")

-- ── the social gate ──
local cursor = D0 + 1
local function dayWhere(fn)
    for d = cursor, cursor + 600 do
        if fn(d) then cursor = d + 1; goDay(d); return d end
    end
    error("no such day")
end
-- a day the city plays a social Street contract
local sd = dayWhere(function(d) return D.dayDraw(d).street.social == true end)
local cityStreet = D.dayDraw(sd).street
assert(slotCard(1, "street").id == D.soloDraw("street", sd).id, "quiet: the solo stand-in")
join(3, "acc3", "Vi"); join(4, "acc4", "Dex")
assert(D.crowded() and D.onlineAccounts() == 4)
assert(slotCard(1, "street").id == D.soloDraw("street", sd).id, "already handed the stand-in: it stays (no flip-flop)")
assert(slotCard(3, "street").id == cityStreet.id, "a crowd: the city's social contract")
assert(slotCard(3, "weekly") ~= nil)
leave(4)
assert(slotCard(3, "street").id == D.soloDraw("street", sd).id, "the city emptied: an untouched social contract goes")
join(4, "acc4", "Dex")
assert(slotCard(3, "street").id == D.soloDraw("street", sd).id, "and does not come back the same day")
-- a started social contract stays when the city empties
local rd = dayWhere(function(d) return D.dayDraw(d).street.id == "ride_along" end)
assert(slotCard(1, "street").id == "ride_along" and slotCard(2, "street").id == "ride_along")
seats[1] = { vehicleId = 7, seat = "seat_front_left" }; seats[2] = { vehicleId = 7, seat = "seat_front_right" }
D.sample(5); clock = clock + 5000; moveAll(60, { 1, 2 }); D.sample(5)
assert(card(1, "ride_along").value == 60)
leave(3); leave(4)
assert(slotCard(1, "street").id == "ride_along", "started: kept on a quiet server")
seats[1], seats[2] = nil, nil
-- the swap never offers what cannot be done
for k = 1, 20 do
    goDay(rd + k * 2)
    local r = swap(1, "street")
    if r.ok then assert(not D.defs[slotCard(1, "street").id].social, "quiet: the swap offers solo contracts only") end
end
cursor = rd + 50

-- ── the Roadside dispatch ──
goDay(cursor); cursor = cursor + 4
join(3, "acc3", "Vi"); join(4, "acc4", "Dex")
jobs[1] = "mechanic"
local md = D.day()
local first = slotCard(1, "shift").id
assert(first == "pit_crew", "no car in trouble: never Roadside (got " .. first .. ")")
D.onFuelLow(44, 2) -- Rosa's tank crossed its reserve
assert(slotCard(1, "shift").id == "roadside", "a live call takes an untouched mechanic")
assert(noticed(1, "Mama Okoro", "on its reserve"), "the mechanic hears about it")
D.onFuelLow(45, 1)
assert(D.doable(D.defs.roadside, "acc1") and D.doable(D.defs.roadside, "acc2"), "two calls: each one sees the other's")
D.onRefuelled(2, { kind = "vehicle", vehicle = 44, litres = 20, before = 5, capacity = 55 })
D.onRefuelled(1, { kind = "vehicle", vehicle = 45, litres = 20, before = 5, capacity = 55 })
assert(slotCard(1, "shift").id == "pit_crew", "the car got fuel elsewhere: back to the shift's contract")
D.onFuelEmpty(46, 2)
D.onRefuelled(1, { kind = "pour", vehicle = 46, litres = 20 })
assert(isDone(1, "roadside"), "a jerrycan into a stranger's dry car")
assert(slotCard(1, "shift").id == "roadside", "done: it stays in the set to be claimed")
-- your own car is not a call for you
goDay(md + 1)
D.onFuelEmpty(47, 1)
assert(slotCard(1, "shift").id ~= "roadside", "your own dry car is not a Roadside call")
D.onRefuelled(1, { kind = "pour", vehicle = 47, litres = 20 })
leave(4)
assert(not D.crowded())
D.onFuelEmpty(48, 2)
assert(slotCard(1, "shift").id ~= "roadside" and not D.defs[slotCard(1, "shift").id].social, "quiet server: the mechanic gets a solo stand-in")
D.onRefuelled(1, { kind = "pour", vehicle = 48, litres = 20 })
jobs[1] = nil; leave(3)

-- ── the partner rule ──
join(3, "acc3", "Vi"); join(4, "acc4", "Dex")
local pd = D.day() + 2
goDay(pd)
give(1, "eat_together"); give(2, "eat_together"); give(3, "eat_together")
pos[1] = { x = 0, y = 0, z = 0, bucket = 0 }; pos[2] = { x = 5, y = 0, z = 0, bucket = 0 }; pos[3] = { x = 8, y = 0, z = 0, bucket = 0 }
D.onItemUsed(1, "burrito"); tick(3000); D.onItemUsed(2, "burrito")
assert(isDone(1, "eat_together") and isDone(2, "eat_together"), "two citizens eat together")
goDay(pd + 1) -- same week
give(1, "eat_together"); give(2, "eat_together"); give(3, "eat_together")
tick(20000); D.onItemUsed(1, "burrito"); tick(2000); D.onItemUsed(2, "burrito")
assert(not isDone(1, "eat_together") and not isDone(2, "eat_together"), "the same pair twice in a week: no")
assert(noticed(1, "DAILIES", "somebody new"), "told why")
tick(20000); D.onItemUsed(1, "burrito"); tick(1000); D.onItemUsed(3, "burrito")
assert(isDone(1, "eat_together") and isDone(3, "eat_together"), "somebody new: yes")
goDay(pd + 7) -- next week
give(1, "eat_together"); give(2, "eat_together")
tick(20000); D.onItemUsed(1, "burrito"); tick(1000); D.onItemUsed(2, "burrito")
assert(isDone(1, "eat_together") and isDone(2, "eat_together"), "a new week, the same friend again")
assert(D.freshPartner("acc1", "eat_together", "acc3") and not D.freshPartner("acc1", "eat_together", "acc2"))
assert(D.freshPartner("acc1", "ride_along", "acc2"), "per contract")
leave(3); leave(4)
cursor = pd + 10

-- ── the contracts the sampler feeds ──
local function sample(n, dt, between)
    for _ = 1, n or 1 do
        tick((dt or 5) * 1000)
        if between then between() end
        D.sample(dt or 5)
    end
end
local function reset()
    for id in pairs(seats) do seats[id] = nil end
    for id in pairs(anims) do anims[id] = nil end
    for id in pairs(crews) do crews[id] = nil end
    for id in pairs(jobs) do jobs[id] = nil end
    LightRP.housing.sessions = {}
    pos[1] = { x = 0, y = 0, z = 0, bucket = 0 }
    pos[2] = { x = 5, y = 0, z = 0, bucket = 0 }
    goDay(cursor); cursor = cursor + 1
    tick(600000)
    D.sample(5) -- re-anchor the positions
end
local function crewUp(...) local c = { id = "crew1", leader = 1, members = { ... } }; for _, id in ipairs(c.members) do crews[id] = c end end

reset(); give(1, "ride_along"); give(2, "ride_along")
seats[1] = { vehicleId = 7, seat = "seat_front_left" }; seats[2] = { vehicleId = 7, seat = "seat_front_right" }
sample(10, 5, function() moveAll(60, { 1, 2 }) end)
assert(card(1, "ride_along").value == 600 and card(2, "ride_along").value == 600, "both ride")
sample(1, 5, function() moveAll(2000, { 1, 2 }) end)
assert(card(1, "ride_along").value == 600, "a teleport is not a ride")
seats[2] = nil
sample(5, 5, function() moveAll(60, { 1, 2 }) end)
assert(card(1, "ride_along").value == 600, "alone in the car")
join(3, "acc1", "Kaito alt", { at = { x = pos[1].x, y = 0, z = 0, bucket = 0 } })
seats[3] = { vehicleId = 7, seat = "seat_back_left" }
sample(5, 5, function() moveAll(60, { 1, 2, 3 }) end)
assert(card(1, "ride_along").value == 600, "your own alt is not company")
leave(3); seats[3] = nil
seats[2] = { vehicleId = 7, seat = "seat_front_right" }
sample(9, 5, function() moveAll(60, { 1, 2 }) end)
assert(not isDone(1, "ride_along") and card(1, "ride_along").value == 1140)
sample(1, 5, function() moveAll(60, { 1, 2 }) end)
assert(isDone(1, "ride_along") and isDone(2, "ride_along"), "1.2 km together (Job Center to the Crossing)")

reset(); give(1, "street_performer")
anims[1] = { playbackId = 11 }
sample(3); assert(card(1, "street_performer").value == 10, "the first sample starts the clock")
pos[2] = { x = 20, y = 0, z = 0, bucket = 0 }
sample(1); assert(card(1, "street_performer").value == 0, "the audience walked past 15 m: start over")
pos[2] = { x = 14, y = 0, z = 0, bucket = 0 }
sample(1); anims[1] = { playbackId = 12 }
sample(1); assert(card(1, "street_performer").value == 0, "another animation starts over")
pos[1] = { x = 500, y = 0, z = 0, bucket = 0 }; pos[2] = { x = 505, y = 0, z = 0, bucket = 0 }
sample(3); assert(card(1, "street_performer").value == 0, "only at The Crossing")
pos[1] = { x = 0, y = 0, z = 0, bucket = 0 }; pos[2] = { x = 14, y = 0, z = 0, bucket = 0 }
sample(12); assert(not isDone(1, "street_performer"))
sample(1); assert(isDone(1, "street_performer"), "a full minute with an audience within 15 m")

reset(); give(1, "the_tour")
chars[2].playtimeMs, chars[2].joinedAtMs = 121 * 60000, clock
sample(5, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 0, "past the first 2 hours: not a newcomer")
chars[2].playtimeMs, chars[2].joinedAtMs = 60 * 60000, clock
pos[2].x = pos[1].x + 16
sample(3, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 0, "further than 15 m: not together")
pos[2].x = pos[1].x + 10
sample(14, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 700 and not isDone(1, "the_tour"))
sample(1, 5, function() moveAll(50, { 1, 2 }) end)
assert(isDone(1, "the_tour"), "750 m with a newcomer (the Crossing to the Afterlife)")
assert(noticed(2, "Mama Okoro", "showed you around"), "the newcomer hears about it")
reset(); give(1, "the_tour")
chars[2].joinedAtMs = clock
sample(25, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 0, "the same newcomer never counts twice")
chars[2].playtimeMs = 360000000

reset(); give(1, "convoy"); give(2, "convoy")
seats[1] = { vehicleId = 1, seat = "seat_front_left" }; seats[2] = { vehicleId = 2, seat = "seat_front_left" }
sample(5, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0 and card(1, "convoy").needsCrew, "not in a crew")
crewUp(1, 2)
assert(card(1, "convoy").crewLocked == nil, "a crewmate online: unlocked")
sample(10, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1000 and card(2, "convoy").value == 1000)
pos[2].x = pos[2].x + 100; sample(1, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1000, "one missed sample is forgiven")
pos[2].x = pos[1].x + 39; sample(1, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1100, "39 m: within shouting range")
pos[2].x = pos[2].x + 100; sample(2, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0, "two in a row start over")
pos[2].x = pos[1].x
seats[2] = { vehicleId = 1, seat = "seat_front_right" }
sample(3, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0, "your own cars, no passengers")
seats[2] = { vehicleId = 2, seat = "seat_front_left" }
sample(23, 5, function() moveAll(100, { 1, 2 }) end)
assert(not isDone(1, "convoy"))
sample(1, 5, function() moveAll(100, { 1, 2 }) end)
assert(isDone(1, "convoy") and isDone(2, "convoy"), "2.4 km side by side")
-- the crew card: locked without a crewmate online, unless started
crews[1], crews[2] = nil, nil
assert(card(1, "convoy").crewLocked == nil, "started (done) cards are never hidden")

reset(); give(1, "album_cover"); give(2, "album_cover")
crewUp(1, 2)
anims[1], anims[2] = { playbackId = 1 }, { playbackId = 2 }
pos[2] = { x = 4, y = 0, z = 0, bucket = 0 }
sample(1); sample(1); assert(not isDone(1, "album_cover"))
anims[2] = nil; sample(1); anims[2] = { playbackId = 3 }
sample(1); sample(1); assert(not isDone(1, "album_cover"), "everybody posing at once")
join(3, "acc3", "Vi", { at = { x = 3, y = 0, z = 0, bucket = 0 } }); give(3, "album_cover"); crewUp(1, 2, 3)
sample(3); assert(not isDone(1, "album_cover"), "the whole crew there")
anims[3] = { playbackId = 4 }
sample(1); sample(2)
assert(isDone(1, "album_cover") and isDone(2, "album_cover") and isDone(3, "album_cover"), "10 s crew pic: three samples")
leave(3); crews[3] = nil

reset(); jobs[1] = "taxi"; give(1, "fare_paid")
seats[1] = { vehicleId = 5, seat = "seat_front_left" }; seats[2] = { vehicleId = 5, seat = "seat_back_right" }
sample(13, 5, function() moveAll(90, { 1, 2 }) end) -- 1170 m
seats[2] = nil; sample(1)
D.onMoneySent(2, 1, 50, "cash")
assert(not isDone(1, "fare_paid"), "1.17 km is not 1.2 km")
seats[2] = { vehicleId = 5, seat = "seat_back_right" }
sample(14, 5, function() moveAll(90, { 1, 2 }) end)
seats[2] = nil; sample(1)
D.onMoneySent(2, 1, 5, "cash"); D.onMoneySent(3, 1, 50, "transfer")
assert(not isDone(1, "fare_paid"), "at least 6, from the passenger")
tick(181000); D.onMoneySent(2, 1, 6, "transfer")
assert(not isDone(1, "fare_paid"), "within 3 minutes")
seats[2] = { vehicleId = 5, seat = "seat_back_right" }
sample(14, 5, function() moveAll(90, { 1, 2 }) end)
seats[2] = nil; sample(1)
D.onMoneySent(2, 1, 6, "transfer")
assert(isDone(1, "fare_paid"), "a fare that covers the fuel")

reset(); jobs[1] = "delivery"; give(1, "fragile")
seats[1] = { vehicleId = 9, seat = "seat_front_left" }; health[9] = 1000
local run = { id = "f1", job = "delivery" }
D.onJobRunStarted(1, run); sample(2); health[9] = 930; sample(1); health[9] = 990
D.onJobRunCompleted(1, run)
assert(not isDone(1, "fragile"), "7 % lost on the way")
run = { id = "f2", job = "delivery" }
health[9] = 1000; D.onJobRunStarted(1, run); sample(2)
seats[1] = { vehicleId = 10, seat = "seat_front_left" }; health[10] = 1000; sample(1)
D.onJobRunCompleted(1, run)
assert(not isDone(1, "fragile"), "one car for the whole run")
run = { id = "f3", job = "delivery" }
D.onJobRunStarted(1, run); sample(3); health[10] = 960
D.onJobRunCompleted(1, run)
assert(isDone(1, "fragile"), "4 % is fine")

-- ── claims ──
reset(); local cday = D.day()
give(1, "lucky_number")
assert(not claim(1, "lucky_number").ok, "not finished")
assert(not claim(1, "nope").ok and results[#results].text == "Unknown daily.")
D.onMoneyChanged(1, "bank", 1, 777, "shop")
assert(noticed(1, "DAILY COMPLETE", "F1 > Dailies"), "the notice says Dailies")
local before = #paid
local r = claim(1, "lucky_number")
assert(r.ok and r.text == "+$250", r.text)
local p = paid[#paid]
assert(#paid == before + 1 and p.amount == 250 and p.kind == "contract" and p.note == "Ledger's Lucky Number" and p.counterparty == 'Silas "Ledger" Varga')
assert(noticed(1, "+$250"))
assert(not claim(1, "lucky_number").ok, "paid once")
v = view(1)
assert(v.budget.used == 250 and v.streak == 1)
C.dailyBudget = 600
local act = D.active(1).action
staff("complete", "1", act.id)
r = claim(1, act.id)
assert(not r.ok and r.text:find("Dailies budget reached", 1, true), r.text)
C.dailyBudget = 1200
assert(claim(1, act.id).ok and view(1).budget.used == 650)
local crewDef = D.active(1).crew
staff("complete", "1", crewDef.id)
payFails = true
r = claim(1, crewDef.id)
assert(not r.ok and r.text:find("payment was refused", 1, true) and view(1).budget.used == 650 and not card(1, crewDef.id).claimed)
payFails = false
local shiftDef = D.active(1).shift
staff("complete", "1", shiftDef.id)
goDay(cday + 1)
v = view(1)
assert(#v.older >= 2, "yesterday's unpaid dailies listed")
assert(claim(1, crewDef.id).ok, "claimed the next day")
assert(view(1).budget.used == 0, "charged to its own day")
goDay(cday + 2)
assert(not claim(1, shiftDef.id).ok, "two days later it is gone")
assert(#view(1).older == 0)
local function countAwards(t) local n = 0 for _, a in ipairs(awards) do if a.title == t then n = n + 1 end end return n end
assert(view(1).streak == 0, "a missed day breaks the streak")
for k = 0, 6 do
    goDay(cday + 2 + k)
    local s = D.active(1).street
    staff("complete", "1", s.id)
    assert(claim(1, s.id).ok)
    assert(view(1).streak == k + 1, "streak " .. (k + 1))
end
assert(countAwards("streak_7") >= 1, "Seven Days Straight")
assert(countAwards("streak_30") == 0)
goDay(cday + 10)
local s = D.active(1).street
staff("complete", "1", s.id); claim(1, s.id)
assert(view(1).streak == 1, "starts over after a gap")
for k = 11, 40 do
    goDay(cday + k)
    local st = D.active(1).street
    staff("complete", "1", st.id); assert(claim(1, st.id).ok)
end
assert(countAwards("streak_30") >= 1 and countAwards("okoro_favourite") >= 1 and countAwards("lucky_seven") >= 1, "contract titles")
-- weekly: outside the daily budget, claimable on Monday for last week
cursor = cday + 41
goDay(cursor)
local week = D.week()
goDay(week * 7 + 3, 23) -- Sunday 23:00
give(1, "all_the_way"); staff("complete", "1", "all_the_way")
goDay(week * 7 + 4) -- Monday
local listed = false
for _, o in ipairs(view(1).older) do if o.id == "all_the_way" and o.reward == 3000 then listed = true end end
assert(listed, "last week's daily listed on Monday")
local used = view(1).budget.used
r = claim(1, "all_the_way")
assert(r.ok and r.text == "+$3000" and view(1).budget.used == used, "the weekly pays outside the budget")
cursor = week * 7 + 6

-- ── the swap ──
reset()
local cur = D.active(1)
r = swap(1, "crew"); assert(not r.ok, "no swap for the crew daily")
r = swap(1, "weekly"); assert(not r.ok)
r = swap(1, "street")
assert(r.ok and r.text:find("New daily", 1, true), r.text)
local now1 = D.active(1)
assert(now1.street.id ~= cur.street.id and now1.street.slot == "street", "a new street daily")
for _, k in ipairs({ "action", "shift", "crew", "weekly" }) do assert(now1.street.id ~= now1[k].id) end
assert(view(1).swapsLeft == 0 and slotCard(1, "street").swappable == nil)
r = swap(1, "action"); assert(not r.ok and r.text == "You already used today's free swap.")
assert(view(2).swapsLeft == 1 and D.active(2).street.id == cur.street.id, "a swap is personal")
reset()
staff("complete", "1", D.active(1).street.id)
r = swap(1, "street"); assert(not r.ok and r.text:find("finished", 1, true), "a finished daily is claimed, not swapped")

-- ── staff ──
local okOff = staff("off"); assert(okOff and view(1).enabled == false)
assert(not claim(1, D.active(1).street.id).ok and results[#results].text == "Dailies are paused right now.")
staff("on")
local beforeReroll = D.dayDraw(D.day()).street.id
assert(staff("reroll", "street"))
local afterReroll = D.dayDraw(D.day()).street.id
assert(afterReroll ~= beforeReroll and afterReroll ~= D.dayDraw(D.day() - 1).street.id, "a reroll gives another, not yesterday's")
local ok, text = staff("status"); assert(ok and text:find("street " .. afterReroll, 1, true) and text:find("accounts online", 1, true))
assert(staff("day", "1")); assert(D.day() == math.floor(unixNow / 86400) + 1); staff("day", "0")
assert(not staff("complete", "1", "nope"))
-- give: any contract in its slot, today, from zero, whatever the crowd, the job or the draw
reset()
ok, text = staff("give", "1", "pit_crew")
assert(ok and slotCard(1, "shift").id == "pit_crew", "a social mechanic contract for an unemployed player on a quiet server")
assert(slotCard(1, "shift").swappable == nil and not swap(1, "shift").ok, "a given daily is not swapped")
jobs[1] = "delivery"
assert(slotCard(1, "shift").id == "pit_crew", "kept through a job change")
jobs[1] = nil
give(1, "nobody_left_behind"); assert(slotCard(1, "crew").id == "nobody_left_behind")
give(1, "walk_of_shame"); assert(slotCard(1, "weekly").id == "walk_of_shame")
give(1, "leg_day"); assert(slotCard(1, "action").id == "leg_day")
assert(not staff("give", "1", "nope") and not staff("give", "99", "leg_day"))
-- status
ok, text = staff("status", "1")
assert(ok and text:find("shift=pit_crew 0/1 (given)", 1, true) and text:find("weekly=walk_of_shame 0/2", 1, true), text)
-- reset: today's and the week's records go, history stays
staff("complete", "1", "leg_day"); assert(isDone(1, "leg_day"))
local streakNow = view(1).streak
ok, text = staff("reset", "1")
assert(ok and not isDone(1, "leg_day") and slotCard(1, "shift").id ~= "pit_crew", "reset: back to the draw")
assert(view(1).streak == streakNow, "the streak is history")

-- ── the database: a restart keeps progress, claims, locks, gifts of staff and partner weeks ──
LightRP.db.ready = true
reset(); give(1, "lucky_number"); give(2, "lucky_number")
D.onMoneyChanged(1, "bank", 1, 777, "shop")
assert(claim(1, "lucky_number").ok)
D.onMoneyChanged(2, "bank", 1, 1777, "shop")
local streakBefore = view(1).streak
join(3, "acc3", "Vi"); join(4, "acc4", "Dex")
give(3, "eat_together"); give(4, "eat_together")
pos[3] = { x = 0, y = 0, z = 0, bucket = 0 }; pos[4] = { x = 3, y = 0, z = 0, bucket = 0 }
D.onItemUsed(3, "burrito"); D.onItemUsed(4, "burrito")
assert(isDone(3, "eat_together"))
local lockedAction = slotCard(2, "action").id
tick(31000); D.flush()
dofile("server/modules/dailies.lua")
D = LightRP.dailies
for id = 1, 4 do LightRP.eachModule("onCharacterLoaded", id) end
assert(card(1, "lucky_number").claimed and card(2, "lucky_number").done and not card(2, "lucky_number").claimed, "restored from the database")
assert(slotCard(1, "street").id == "lucky_number", "a staff give survives a restart")
assert(slotCard(2, "action").id == lockedAction, "so does what the player was handed")
assert(view(1).streak == streakBefore and view(1).budget.used == 250)
assert(not claim(1, "lucky_number").ok, "still paid once after a restart")
assert(not D.freshPartner("acc3", "eat_together", "acc4"), "partner weeks survive a restart")
dbFail = true
local cnt = #paid
r = claim(2, "lucky_number")
assert(not r.ok and r.text == "The claim could not be saved. Please try again." and #paid == cnt, "no save, no pay")
dbFail = false
assert(claim(2, "lucky_number").ok)
-- reset deletes the rows
staff("reset", "2")
assert(dbDeleted[#dbDeleted] == "w" .. D.week() and dbRows["acc2|d" .. D.day()] == nil, "reset clears the stored day and week")
LightRP.db.ready = false
leave(3); leave(4)

-- ── switched off: nothing moves ──
reset(); give(1, "lucky_number")
D.enabled = false
D.onMoneyChanged(1, "bank", 1, 777, "shop")
D.enabled = true
assert(not isDone(1, "lucky_number"), "off means off")

-- ── the page state stays small whatever the day ──
for k = 0, 30 do goDay(D0 + k); assert(values(view(1)) < 320) end

print("dailies_test: ok")
