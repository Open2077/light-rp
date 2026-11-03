-- Daily and weekly contracts (server/modules/dailies.lua), the host stubbed: the
-- rotation (deterministic, never twice in a row, each contract back within a
-- cycle, sources skipped, frozen once settled), shift draws per job, the day and
-- week resets, every contract's server check (and what does not count), claims
-- (budget, grace, streak, failure rollback, titles), the swap, the staff verbs,
-- the database round trip and the page state's size.
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
local online, pos, seats, anims, health = {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(online) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.Open77 = {
    time = { unix = function() return unixNow end },
    players = {
        position = function(id) local p = pos[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } end,
        positions = function() local out = {} for id, p in pairs(pos) do if online[id] then out[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0 } end end return out end,
    },
    vehicles = { getPlayerSeat = function(id) return seats[id] end, getHealth = function(v) return health[v] end },
    animations = { current = function(id) return anims[id] end },
}

local chars, jobs, crews = {}, {}, {}
local modules, actions, commands, providers = {}, {}, {}, {}
local notices, results, dialogs, states, paid, awards = {}, {}, {}, {}, {}, {}
local payFails = false
local dbRows, dbMeta, dbFail = {}, {}, false
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
        get = function(id) return chars[id] end,
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
_G.LightRpFixers = { enabled = true }
_G.LightRpDelivery = {}
_G.LightRpJobRuns = { routes = { ac_cleaner = { steps = { { kind = "inspect" } } } } }
_G.LightRpActivities = { hub = { center = { x = 0, y = 0, z = 0 } } }
_G.LightRpItems = { burrito = { use = { food = 35 } }, beer = { use = { drink = 20 } }, water = { use = { drink = 30 } } }
_G.LightRpConfig = { mapPlaces = { places = {
    { id = "bar_a", kind = "bar", district = "Watson", position = { x = 1000, y = 0, z = 0 } },
    { id = "bar_d", kind = "bar", district = "Watson", position = { x = 1100, y = 0, z = 0 } },
    { id = "bar_b", kind = "bar", district = "Heywood", position = { x = 2000, y = 0, z = 0 } },
    { id = "bar_c", kind = "bar", district = "Pacifica", position = { x = 3000, y = 0, z = 0 } },
    { id = "shop", kind = "shop", district = "Pacifica", position = { x = 3010, y = 0, z = 0 } },
} } }

dofile("server/config/dailies.lua")
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
local function view(id) return providers.dailies(id) end
local function card(id, contractId)
    for _, c in ipairs(view(id).list or {}) do if c.id == contractId then return c end end
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
local function values(v)
    if type(v) ~= "table" then return 1 end
    local n = 0
    for _, x in pairs(v) do n = n + values(x) end
    return n
end
local function moveAll(dx, ids) for _, id in ipairs(ids) do pos[id].x = pos[id].x + dx end end
local function tick(ms) clock = clock + ms end

-- ── basics: FNV-1a, UTC day, Monday weeks ──
assert(D.hash("a") == 0xe40c292c, "FNV-1a")
assert(D.day() == D0 and D.week() == W0, "day and week from server time")
assert(D.weekOf(D0 - 1) == W0 - 1 and D.weekOf(D0 + 6) == W0 and D.weekOf(D0 + 7) == W0 + 1, "weeks start on Monday")

-- ── the rotation ──
local function idOf(def) return def and def.id or "-" end
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
        -- every contract once per aligned cycle of n days
        if d % n == n - 1 and d - n + 1 >= D0 - 400 then
            local set = {}
            for k = d - n + 1, d do set[D.dayDraw(k)[slot].id] = true end
            local count = 0
            for _ in pairs(set) do count = count + 1 end
            assert(count == n, slot .. " cycle holds every contract once")
        end
    end
    assert(idOf(D.dayDraw(D0)[slot]) == idOf(D.dayDraw(D0)[slot]), "deterministic")
end
local lastWeekly
for w = W0 - 60, W0 + 60 do
    local def = D.weekDraw(w)
    assert(def and def.slot == "weekly" and def.id ~= lastWeekly, "weekly never twice in a row")
    lastWeekly = def.id
end
-- a missing source is never drawn (op77_chase stopped: no NCPD Escape)
LightRP.activities.registry["chase.pve"] = nil
for d = D0, D0 + 60 do
    local dd = D.dayDraw(d)
    assert(dd.action.id ~= "lose_them" and dd.crew.id ~= "nobody_left_behind", "chase.pve contracts skipped")
end
LightRP.activities.registry["chase.pve"] = {}
-- shift: the job's own order; a job without contracts gets a street one, not the city's
for d = D0, D0 + 30 do
    local a, b = D.shiftDraw(d, "delivery"), D.shiftDraw(d - 1, "delivery")
    assert((a.id == "still_hot" or a.id == "fragile") and a.id ~= b.id, "courier shift alternates")
    local s = D.shiftDraw(d, "sanitation")
    assert(s.id == "full_truck" or s.id == "full_round", "sanitation shift")
    assert(D.shiftDraw(d, "trauma").id == "on_call" and D.shiftDraw(d, "unemployed").id == "clock_in", "single-contract jobs")
    local cop = D.shiftDraw(d, "ncpd")
    assert(cop.slot == "street" and cop.id ~= D.dayDraw(d).street.id, "NCPD gets another street contract")
end
-- frozen once the server settled: a source stopping later changes nothing today
clock = 130000
local frozen = D.dayDraw(D0).action.id
LightRP.activities.registry["race.trial"], LightRP.activities.registry["chase.pve"], LightRP.activities.registry["arena.pve"] = nil, nil, nil
LightRP.missions = nil
assert(D.dayDraw(D0).action.id == frozen, "today's draw is frozen")
LightRP.missions = { point = function(id) return { id = id } end }
LightRP.activities.registry = { ["chase.pve"] = {}, ["race.trial"] = {}, ["arena.pve"] = {}, ["arena.duel"] = {}, ["chase.wanted"] = {} }

-- ── the page state ──
join(1, "acc1", "Kaito")
join(2, "acc2", "Rosa", { playtimeMs = 3600000, at = { x = 5, y = 0, z = 0, bucket = 0 } })
local v = view(1)
assert(v.enabled and v.ready and v.day == D0 and #v.list == 5, "five cards")
local slots = {}
for _, c in ipairs(v.list) do slots[c.slot] = c end
assert(slots.street and slots.action and slots.shift and slots.crew and slots.weekly, "one per slot")
assert(slots.shift.id == "clock_in", "unemployed: Clock In")
assert(slots.street.reward == 250 and slots.action.reward == 400 and slots.shift.reward == 250 and slots.crew.reward == 300 and slots.weekly.reward == 3000)
assert(slots.crew.needsCrew == true and slots.street.swappable == true and slots.crew.swappable == nil and slots.weekly.swappable == nil)
assert(v.resetInMs == (86400 - 3600) * 1000 and v.weekResetInMs == (7 * 86400 - 3600) * 1000, "countdowns")
assert(v.budget.used == 0 and v.budget.max == 1200 and v.swapsLeft == 1 and v.streak == 0)
assert(values(v) < 300, "dailies state stays small: " .. values(v))
actions["dailies.open"](1, { tab = "titles" })
assert(dialogs[#dialogs].kind == "dailies" and dialogs[#dialogs].payload.tab == "titles", "F1 opens the panel on a tab")
actions["dailies.open"](1, { tab = "x" })
assert(dialogs[#dialogs].payload.tab == "today")

-- ── finding the day a contract is drawn ──
local cursor = D0 + 1
local function dayWith(slot, contractId, job)
    for d = cursor, cursor + 500 do
        local hit
        if slot == "weekly" then hit = idOf(D.weekDraw(D.weekOf(d))) == contractId
        elseif slot == "shift" then hit = idOf(D.shiftDraw(d, job)) == contractId
        else hit = idOf(D.dayDraw(d)[slot]) == contractId end
        if hit then cursor = d + 1; goDay(d); return d end
    end
    error("never drawn: " .. contractId)
end
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
    tick(600000)
    D.sample(5) -- re-anchor the positions
end
local function crewUp(...) local c = { id = "crew1", leader = 1, members = { ... } }; for _, id in ipairs(c.members) do crews[id] = c end end

-- ── Street ──
reset(); dayWith("street", "lucky_number")
D.onMoneyChanged(1, "cash", 10, 1777, "x"); assert(not isDone(1, "lucky_number"), "cash does not count")
D.onMoneyChanged(1, "bank", 10, 1778, "x"); assert(not isDone(1, "lucky_number"))
D.onMoneyChanged(1, "bank", 10, 21777, "x"); assert(isDone(1, "lucky_number"), "bank ending in 777")
assert(noticed(1, "CONTRACT COMPLETE", "Daily Contracts"))

reset(); dayWith("street", "eat_together")
pos[2] = { x = 30, y = 0, z = 0, bucket = 0 }
D.onItemUsed(1, "burrito"); D.onItemUsed(2, "burrito")
assert(not isDone(1, "eat_together"), "too far apart")
tick(130000); pos[2] = { x = 5, y = 0, z = 0, bucket = 0 }
D.onItemUsed(2, "burrito"); assert(not isDone(2, "eat_together"), "meals more than 2 minutes apart")
D.onItemUsed(1, "water"); assert(not isDone(1, "eat_together"), "a drink is not a meal")
tick(30000); D.onItemUsed(1, "burrito")
assert(isDone(1, "eat_together") and isDone(2, "eat_together"), "two citizens eat together")

reset(); dayWith("street", "housewarming")
LightRP.housing.sessions = { [1] = { property = "p1", contract = "lease1" }, [2] = { property = "p1", preview = true } }
sample(40); assert(card(1, "housewarming").value == 0, "a visitor previewing does not count")
LightRP.housing.sessions[2] = { property = "p1" }
sample(35); assert(not isDone(1, "housewarming") and card(1, "housewarming").value == 175)
sample(1); assert(isDone(1, "housewarming"), "3 minutes with a guest")

reset(); dayWith("street", "running_on_fumes")
D.onRefuelled(1, { kind = "pour", vehicle = 3, litres = 30, before = 2, capacity = 50 }); assert(not isDone(1, "running_on_fumes"), "a jerrycan does not count")
D.onRefuelled(1, { kind = "vehicle", vehicle = 3, litres = 30, before = 6, capacity = 50 }); assert(not isDone(1, "running_on_fumes"), "12 % is not under 10 %")
D.onRefuelled(1, { kind = "vehicle", vehicle = 3, litres = 15, before = 4, capacity = 50 }); assert(not isDone(1, "running_on_fumes"), "38 % is not 50 %")
D.onRefuelled(1, { kind = "vehicle", vehicle = 3, litres = 30, before = 4, capacity = 50 }); assert(isDone(1, "running_on_fumes"))

reset(); dayWith("street", "ride_along")
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
online[3], seats[3] = nil, nil
seats[2] = { vehicleId = 7, seat = "seat_front_right" }
sample(15, 5, function() moveAll(60, { 1, 2 }) end)
assert(isDone(1, "ride_along") and isDone(2, "ride_along"), "1.5 km together")

reset(); dayWith("street", "street_performer")
anims[1] = { playbackId = 11 }
sample(3); assert(card(1, "street_performer").value == 10, "the first sample starts the clock")
pos[2] = { x = 40, y = 0, z = 0, bucket = 0 }
sample(1); assert(card(1, "street_performer").value == 0, "the audience walked off: start over")
pos[2] = { x = 5, y = 0, z = 0, bucket = 0 }
sample(1); anims[1] = { playbackId = 12 }
sample(1); assert(card(1, "street_performer").value == 0, "another animation starts over")
pos[1] = { x = 500, y = 0, z = 0, bucket = 0 }; pos[2] = { x = 505, y = 0, z = 0, bucket = 0 }
sample(3); assert(card(1, "street_performer").value == 0, "only at The Crossing")
pos[1] = { x = 0, y = 0, z = 0, bucket = 0 }; pos[2] = { x = 5, y = 0, z = 0, bucket = 0 }
sample(12); assert(not isDone(1, "street_performer"))
sample(1); assert(isDone(1, "street_performer"), "a full minute with an audience")

reset(); dayWith("street", "the_tour")
chars[2].playtimeMs, chars[2].joinedAtMs = 100 * 3600000, clock
sample(5, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 0, "a veteran is not a newcomer")
chars[2].playtimeMs, chars[2].joinedAtMs = 3600000, clock
sample(19, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 950 and not isDone(1, "the_tour"))
sample(1, 5, function() moveAll(50, { 1, 2 }) end)
assert(isDone(1, "the_tour"), "1 km with a newcomer")
assert(noticed(2, "Mama Okoro", "showed you around"), "the newcomer hears about it")
-- the same newcomer never counts twice
reset(); dayWith("street", "the_tour")
chars[2].joinedAtMs = clock
sample(25, 5, function() moveAll(50, { 1, 2 }) end)
assert(card(1, "the_tour").value == 0, "already toured")
chars[2].playtimeMs = 360000000

-- ── Action ──
reset(); dayWith("action", "before_overclock")
local chimera = { id = "chimera_raid" }
D.onMissionFinished({ members = { 1 }, report = { enraged = true } }, chimera, { id = "hard" }, true)
D.onMissionFinished({ members = { 1 }, test = true, report = { enraged = false } }, chimera, { id = "hard" }, true)
D.onMissionFinished({ members = { 1 }, report = { enraged = false } }, chimera, { id = "hard" }, false)
D.onMissionFinished({ members = { 1 }, report = { enraged = false } }, { id = "sector04_blackout" }, { id = "hard" }, true)
assert(not isDone(1, "before_overclock"))
D.onMissionFinished({ members = { 1 }, report = { enraged = false } }, chimera, { id = "standard" }, true)
assert(isDone(1, "before_overclock"))

local function result(id, activity, stats, verdict, extra)
    local entry = { activity = activity, ranked = extra and extra.ranked, enteredAt = extra and extra.enteredAt }
    local raw = { stats = stats, won = extra and extra.won, unranked = extra and extra.unranked }
    D.onActivityResult(id, entry, { won = extra and extra.won }, raw, verdict or { amount = 100 })
end
-- an NCPD Escape result as op77_chase sends it (pve.lua resultFor), police = "ncpd"
local function escape(how, stars, more)
    local s = { mode = "vehicle", outcome = (how == "clock" or how == "extraction") and "escaped" or (how == "left" and "left" or "busted"),
        how = how, seconds = 120, shakes = 0, runners = 1, police = "ncpd", difficulty = "standard", stars = stars }
    for k, v in pairs(more or {}) do s[k] = v end
    return s
end
reset(); dayWith("action", "lose_them")
result(1, "chase.pve", escape("clock", 3))
result(1, "chase.pve", escape("extraction", 2))
result(1, "chase.pve", escape("arrest", 3))
result(1, "chase.pve", escape("extraction", 3), { kind = "too_short" })
result(1, "chase.pve", escape("extraction", 3), nil, { ranked = false })
result(1, "chase.pve", escape("extraction", 3), nil, { unranked = true })
result(1, "chase.pve", escape("extraction", 4, { policeBlocked = true }))
result(1, "chase.pve", escape("extraction", 4, { police = "bots" }))
result(1, "chase.pve", escape("extraction", 3, { police = false }))
result(1, "chase.pve", { outcome = "escaped", how = "shake", stars = 3 })
result(1, "race.pve", escape("extraction", 3))
assert(not isDone(1, "lose_them"), "only a paid, ranked extraction at 3 stars against the real NCPD")
result(1, "chase.pve", escape("extraction", 4, { difficulty = "hard" }))
assert(isDone(1, "lose_them"))
reset(); dayWith("action", "lose_them")
result(1, "chase.pve", escape("extraction", 3))
assert(isDone(1, "lose_them"), "the Standard ceiling held to the extraction")

reset(); dayWith("action", "run_it_back")
result(1, "race.trial", { finished = true, timeMs = 60000, courseId = "c1" })
result(1, "race.trial", { finished = true, timeMs = 59500, courseId = "c1" })
result(1, "race.trial", { finished = true, timeMs = 50000, courseId = "c2" })
result(1, "race.trial", { finished = false, timeMs = 40000, courseId = "c1" })
result(1, "race.trial", { finished = true, timeMs = 40000, courseId = "c1" }, nil, { unranked = true })
assert(not isDone(1, "run_it_back"), "1 s faster on the same course")
result(1, "race.trial", { finished = true, timeMs = 58900, courseId = "c1" })
assert(isDone(1, "run_it_back"))

reset(); dayWith("action", "billable_hours")
D.onMissionFinished({ members = { 1 }, startedAt = clock - 6 * 60000 }, { id = "any" }, { minutes = 10 }, true)
D.onMissionFinished({ members = { 1 }, startedAt = clock - 60000, test = true }, { id = "any" }, { minutes = 10 }, true)
assert(not isDone(1, "billable_hours"))
D.onMissionFinished({ members = { 1 }, startedAt = clock - 5 * 60000 }, { id = "any" }, { minutes = 10 }, true)
assert(isDone(1, "billable_hours"), "half the clock left")

reset(); dayWith("action", "answer_phone")
D.onMissionFinished({ members = { 1 } }, { id = "board" }, { id = "standard" }, true)
D.onMissionFinished({ members = { 1 }, gig = true }, { id = "gig" }, { id = "standard" }, false)
assert(not isDone(1, "answer_phone"))
D.onMissionFinished({ members = { 1 }, gig = true }, { id = "gig" }, { id = "standard" }, true)
assert(isDone(1, "answer_phone"))

reset(); dayWith("action", "five_streak")
result(1, "arena.pve", { bestStreak = 4 })
result(1, "arena.pve", { bestStreak = 9 }, { kind = "no_progress" })
result(1, "arena.ffa", { bestStreak = 9 })
assert(not isDone(1, "five_streak"))
result(1, "arena.pve", { bestStreak = 5 })
assert(isDone(1, "five_streak"))

-- ── Shift ──
reset(); jobs[1] = "sanitation"; dayWith("shift", "full_truck", "sanitation")
D.onJobWorkCompleted(1, "sanitation", "sell", { count = 19, total = 500 })
D.onJobWorkCompleted(1, "sanitation", "collect", { count = 25 })
assert(not isDone(1, "full_truck"))
D.onJobWorkCompleted(1, "sanitation", "sell", { count = 20, total = 600 })
assert(isDone(1, "full_truck"))

reset(); jobs[1] = "scrapper"; dayWith("shift", "full_round", "scrapper")
D.onJobWorkCompleted(1, "scrapper", "collect", { point = "salvage_south" })
D.onJobWorkCompleted(1, "scrapper", "sell", { point = "buyer", count = 5 })
assert(not isDone(1, "full_round"), "both sites first")
tick(31 * 60000)
D.onJobWorkCompleted(1, "scrapper", "collect", { point = "salvage_north" })
D.onJobWorkCompleted(1, "scrapper", "sell", { point = "buyer", count = 5 })
assert(not isDone(1, "full_round"), "inside 30 minutes")
D.onJobWorkCompleted(1, "scrapper", "collect", { point = "salvage_south" })
tick(60000)
D.onJobWorkCompleted(1, "scrapper", "sell", { point = "buyer", count = 5 })
assert(isDone(1, "full_round"))

reset(); jobs[1] = "delivery"; dayWith("shift", "still_hot", "delivery")
local run = { id = "r1", job = "delivery", route = { distanceKm = 2 } }
D.onJobRunStarted(1, run); tick(6 * 60000 + 1000); D.onJobRunCompleted(1, run)
assert(not isDone(1, "still_hot"), "3 + 1.5 x 2 = 6 minutes")
run = { id = "r2", job = "delivery", route = { distanceKm = 2 } }
D.onJobRunStarted(1, run); tick(5 * 60000)
D.onJobRunCompleted(1, { id = "r3", job = "delivery", route = { distanceKm = 2 } })
assert(not isDone(1, "still_hot"), "the run that started")
D.onJobRunCompleted(1, run)
assert(isDone(1, "still_hot"))

reset(); jobs[1] = "delivery"; dayWith("shift", "fragile", "delivery")
seats[1] = { vehicleId = 9, seat = "seat_front_left" }; health[9] = 1000
run = { id = "f1", job = "delivery", route = { distanceKm = 1 } }
D.onJobRunStarted(1, run); sample(2); health[9] = 930; sample(1); health[9] = 990
D.onJobRunCompleted(1, run)
assert(not isDone(1, "fragile"), "7 % lost on the way")
run = { id = "f2", job = "delivery", route = { distanceKm = 1 } }
health[9] = 1000; D.onJobRunStarted(1, run); sample(2)
seats[1] = { vehicleId = 10, seat = "seat_front_left" }; health[10] = 1000; sample(1)
D.onJobRunCompleted(1, run)
assert(not isDone(1, "fragile"), "one car for the whole run")
run = { id = "f3", job = "delivery", route = { distanceKm = 1 } }
D.onJobRunStarted(1, run); sample(3); health[10] = 960
D.onJobRunCompleted(1, run)
assert(isDone(1, "fragile"), "4 % is fine")

reset(); jobs[1] = "ac_cleaner"; dayWith("shift", "heat_wave", "ac_cleaner")
run = { id = "h1", job = "ac_cleaner" }
D.onJobRunStarted(1, run); tick(5 * 60000 + 1); D.onJobRunCompleted(1, run)
assert(not isDone(1, "heat_wave"))
run = { id = "h2", job = "ac_cleaner" }
D.onJobRunStarted(1, run); tick(4 * 60000); D.onJobRunCompleted(1, run)
assert(isDone(1, "heat_wave"))

reset(); jobs[1] = "trauma"; dayWith("shift", "on_call", "trauma")
join(3, "acc1", "Kaito alt"); D.onPatientStabilized(1, 3); online[3] = nil
assert(not isDone(1, "on_call"), "your own alt is not a patient")
D.onPatientStabilized(1, 2)
assert(isDone(1, "on_call"))

reset(); jobs[1] = "taxi"; dayWith("shift", "fare_paid", "taxi")
seats[1] = { vehicleId = 5, seat = "seat_front_left" }; seats[2] = { vehicleId = 5, seat = "seat_back_right" }
sample(20, 5, function() moveAll(90, { 1, 2 }) end) -- 1.8 km
seats[2] = nil; sample(1)
D.onMoneySent(2, 1, 50, "cash")
assert(not isDone(1, "fare_paid"), "1.8 km is not 2 km")
seats[2] = { vehicleId = 5, seat = "seat_back_right" }
sample(23, 5, function() moveAll(90, { 1, 2 }) end)
seats[2] = nil; sample(1)
D.onMoneySent(2, 1, 19, "cash"); D.onMoneySent(3, 1, 50, "transfer")
assert(not isDone(1, "fare_paid"), "at least 20, from the passenger")
D.onMoneySent(2, 1, 20, "transfer")
assert(isDone(1, "fare_paid"))

reset(); jobs[1] = "mechanic"; dayWith("shift", "roadside", "mechanic")
D.onFuelEmpty(8, 1); D.onRefuelled(1, { kind = "pour", vehicle = 8 })
assert(not isDone(1, "roadside"), "your own car")
D.onFuelEmpty(8, 2); D.onRefuelled(1, { kind = "vehicle", vehicle = 8 })
assert(not isDone(1, "roadside"), "a jerrycan, not a pump")
tick(21 * 60000); D.onRefuelled(1, { kind = "pour", vehicle = 8 })
assert(not isDone(1, "roadside"), "within 20 minutes")
D.onFuelEmpty(8, 2); tick(60000); D.onRefuelled(1, { kind = "pour", vehicle = 8 })
assert(isDone(1, "roadside"))

reset(); dayWith("shift", "clock_in", "unemployed")
D.onJobWorkCompleted(1, "unemployed", "sell", {})
assert(card(1, "clock_in").value == 0)
jobs[1] = "delivery"; D.onJobChanged(1, { name = "delivery" }, { name = "unemployed" })
local ci = card(1, "clock_in")
assert(ci and ci.value == 1 and not ci.done, "hired: Clock In stays in the shift slot")
D.onJobWorkCompleted(1, "delivery", "sell", { practice = true })
assert(not isDone(1, "clock_in"), "a practice site is not a shift")
D.onJobRunCompleted(1, { id = "c1", job = "delivery" })
assert(isDone(1, "clock_in"))

-- ── Crew ──
reset(); dayWith("crew", "convoy")
seats[1] = { vehicleId = 1, seat = "seat_front_left" }; seats[2] = { vehicleId = 2, seat = "seat_front_left" }
sample(5, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0 and card(1, "convoy").needsCrew, "not in a crew")
crewUp(1, 2)
sample(10, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1000 and card(2, "convoy").value == 1000)
pos[2].x = pos[2].x + 100; sample(1, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1000, "one missed sample is forgiven")
pos[2].x = pos[1].x; sample(1, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 1100)
pos[2].x = pos[2].x + 100; sample(2, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0, "two in a row start over")
pos[2].x = pos[1].x
seats[2] = { vehicleId = 1, seat = "seat_front_right" }
sample(3, 5, function() moveAll(100, { 1, 2 }) end)
assert(card(1, "convoy").value == 0, "your own cars, no passengers")
seats[2] = { vehicleId = 2, seat = "seat_front_left" }
sample(30, 5, function() moveAll(100, { 1, 2 }) end)
assert(isDone(1, "convoy") and isDone(2, "convoy"), "3 km side by side")

reset(); dayWith("crew", "back_to_back")
crewUp(1, 2)
result(1, "arena.pve", { kills = 1 }, nil, { won = true })
tick(121000)
result(2, "arena.pve", { kills = 3 }, nil, { won = true })
assert(not isDone(1, "back_to_back"), "the same match: within 2 minutes")
tick(1000)
result(1, "arena.pve", { kills = 0 }, nil, { won = true })
assert(not isDone(1, "back_to_back"), "at least one kill each")
result(1, "arena.pve", { kills = 2 }, nil, { won = true, unranked = true })
assert(not isDone(1, "back_to_back"), "never unranked")
result(1, "arena.pve", { kills = 2 }, nil, { won = true })
assert(isDone(1, "back_to_back") and isDone(2, "back_to_back"))

reset(); dayWith("crew", "bar_crawl")
crewUp(1, 2)
local function drinkAt(x, ...) for _, id in ipairs({ ... }) do pos[id] = { x = x, y = 0, z = 0, bucket = 0 }; D.onItemUsed(id, "beer") end end
drinkAt(1000, 1); tick(601000); drinkAt(1000, 2)
assert(card(1, "bar_crawl").value == 0, "together: within 10 minutes")
drinkAt(1000, 1)
assert(card(1, "bar_crawl").value == 1 and card(2, "bar_crawl").value == 1)
drinkAt(1100, 1, 2)
assert(card(1, "bar_crawl").value == 1, "another bar in the same district")
drinkAt(1500, 1, 2)
assert(card(1, "bar_crawl").value == 1, "not at a bar")
drinkAt(2000, 1, 2); drinkAt(3000, 1, 2)
assert(isDone(1, "bar_crawl") and isDone(2, "bar_crawl"), "three districts")

reset(); dayWith("crew", "album_cover")
crewUp(1, 2)
anims[1], anims[2] = { playbackId = 1 }, { playbackId = 2 }
pos[2] = { x = 4, y = 0, z = 0, bucket = 0 }
sample(1); sample(1); assert(not isDone(1, "album_cover"))
anims[2] = nil; sample(1); anims[2] = { playbackId = 3 }
sample(1); sample(1); assert(not isDone(1, "album_cover"), "everybody posing at once")
join(3, "acc3", "Vi", { at = { x = 3, y = 0, z = 0, bucket = 0 } }); crewUp(1, 2, 3)
sample(3); assert(not isDone(1, "album_cover"), "the whole crew there")
anims[3] = { playbackId = 4 }
sample(1); sample(2)
assert(isDone(1, "album_cover") and isDone(2, "album_cover") and isDone(3, "album_cover"), "10 s crew pic")
online[3] = nil; crews[3] = nil

reset(); dayWith("crew", "nobody_left_behind")
crewUp(1, 2)
local function crewRun(id, how, runners, entered, more)
    local m = { crew = true, runners = runners }
    for k, v in pairs(more or {}) do m[k] = v end
    result(id, "chase.pve", escape(how, 3, m), nil, { enteredAt = entered })
end
crewRun(1, "extraction", 2, clock); crewRun(2, "arrest", 2, clock)
assert(not isDone(1, "nobody_left_behind"), "everyone gets out")
tick(200000)
local run2 = clock
crewRun(1, "extraction", 2, run2); tick(110000); crewRun(2, "clock", 2, run2) -- 110 s apart: the extraction, then the clock
assert(isDone(1, "nobody_left_behind") and isDone(2, "nobody_left_behind"), "an extraction and the clock, one run")
-- three of them in the run: the first two out is not everyone
reset(); dayWith("crew", "nobody_left_behind")
join(3, "acc3", "Vi", { at = { x = 3, y = 0, z = 0, bucket = 0 } }); crewUp(1, 2, 3)
crewRun(1, "extraction", 3, clock); crewRun(2, "extraction", 3, clock)
assert(not isDone(1, "nobody_left_behind"), "the third runner is still out")
crewRun(3, "takedown", 3, clock)
assert(not isDone(1, "nobody_left_behind") and not isDone(3, "nobody_left_behind"), "the third one went down")
-- a crewmate who dropped sends nothing: never paid
reset(); dayWith("crew", "nobody_left_behind")
crewUp(1, 2, 3)
tick(1000); crewRun(1, "extraction", 3, clock); crewRun(2, "clock", 3, clock)
tick(250000)
assert(not isDone(1, "nobody_left_behind"), "the one who dropped never came out")
-- an escape from the last run does not complete this one
local run3 = clock
crewRun(1, "extraction", 2, run3 - 200000); crewRun(2, "extraction", 2, run3)
assert(not isDone(1, "nobody_left_behind"), "two different runs")
-- a game that refused its police does not count, nor the bot police
crewRun(2, "extraction", 2, run3, { policeBlocked = true })
crewRun(1, "extraction", 2, run3)
assert(not isDone(1, "nobody_left_behind"), "a runner nobody chased")
crewRun(2, "extraction", 2, run3, { police = "bots" })
assert(not isDone(1, "nobody_left_behind"), "the bot police")
crewRun(2, "clock", 2, run3)
assert(isDone(1, "nobody_left_behind") and isDone(2, "nobody_left_behind") and not isDone(3, "nobody_left_behind"),
    "the two in the run, not the crewmate who stayed home")
online[3] = nil; crews[3] = nil

-- ── Weekly ──
reset(); dayWith("weekly", "two_vs_machine")
D.onMissionFinished({ members = { 1, 2, 3 } }, chimera, { id = "hard" }, true)
D.onMissionFinished({ members = { 1, 2 } }, chimera, { id = "standard" }, true)
assert(not isDone(1, "two_vs_machine"))
D.onMissionFinished({ members = { 1, 2 } }, chimera, { id = "critical" }, true)
assert(isDone(1, "two_vs_machine") and isDone(2, "two_vs_machine"))

reset(); dayWith("weekly", "all_the_way")
result(1, "arena.duel", { roundsWon = 2, roundsLost = 0 }, nil, { won = true })
result(1, "arena.duel", { roundsWon = 1, roundsLost = 2 }, nil, { won = false })
assert(not isDone(1, "all_the_way"))
result(1, "arena.duel", { roundsWon = 2, roundsLost = 1 }, nil, { won = true })
assert(isDone(1, "all_the_way"))

reset(); dayWith("weekly", "lions_share")
D.onWorldEventEnded({ contrib = { [1] = { eligible = true, score = 50 }, [2] = { eligible = false, score = 90 } } }, false)
assert(not isDone(1, "lions_share"), "the boss went down")
D.onWorldEventEnded({ contrib = { [1] = { eligible = true, score = 50 }, [2] = { eligible = false, score = 90 } } }, true)
assert(isDone(1, "lions_share") and not isDone(2, "lions_share"), "top eligible share")

reset(); dayWith("weekly", "both_sides")
result(1, "chase.wanted", { arrests = 1 })
result(1, "chase.wanted", { arrests = 1, extractions = 1 }, { kind = "bots" })
assert(not isDone(1, "both_sides"))
result(1, "chase.wanted", { arrests = 1, survivals = 1 })
assert(isDone(1, "both_sides"))

reset(); dayWith("weekly", "good_samaritan")
join(3, "acc3", "Vi"); join(4, "acc4", "Dex"); join(5, "acc5", "Mox"); crewUp(1, 3)
D.onPatientStabilized(1, 2); D.onPatientStabilized(1, 2)
D.onPatientStabilized(1, 3)
assert(card(1, "good_samaritan").value == 1, "the same stranger once, never a crewmate")
D.onPatientStabilized(1, 4); D.onPatientStabilized(1, 5)
assert(isDone(1, "good_samaritan"))
online[3], online[4], online[5] = nil, nil, nil

-- ── claims ──
reset(); local cday = dayWith("street", "lucky_number")
assert(not claim(1, "lucky_number").ok, "not finished")
assert(not claim(1, "nope").ok and results[#results].text == "Unknown contract.")
D.onMoneyChanged(1, "bank", 1, 777)
local before = #paid
local r = claim(1, "lucky_number")
assert(r.ok and r.text == "+$250", r.text)
local p = paid[#paid]
assert(#paid == before + 1 and p.amount == 250 and p.kind == "contract" and p.note == "Ledger's Lucky Number" and p.counterparty == 'Silas "Ledger" Varga')
assert(noticed(1, "+$250"))
assert(not claim(1, "lucky_number").ok, "paid once")
v = view(1)
assert(v.budget.used == 250 and v.streak == 1)
-- budget
C.dailyBudget = 600
local act = D.active(1).action
staff("complete", "1", act.id)
r = claim(1, act.id)
assert(not r.ok and r.text:find("Daily contract budget reached", 1, true), r.text)
C.dailyBudget = 1200
assert(claim(1, act.id).ok and view(1).budget.used == 650)
-- a refused payment rolls the claim back
local crewDef = D.active(1).crew
staff("complete", "1", crewDef.id)
payFails = true
r = claim(1, crewDef.id)
assert(not r.ok and r.text:find("payment was refused", 1, true) and view(1).budget.used == 650 and not card(1, crewDef.id).claimed)
payFails = false
-- grace: yesterday's finished contract is still paid the next day, not the day after
local shiftDef = D.active(1).shift
staff("complete", "1", shiftDef.id)
goDay(cday + 1)
v = view(1)
assert(#v.older >= 2, "yesterday's unpaid contracts listed")
assert(claim(1, crewDef.id).ok, "claimed the next day")
assert(view(1).budget.used == 0, "charged to its own day")
goDay(cday + 2)
assert(not claim(1, shiftDef.id).ok, "two days later it is gone")
assert(#view(1).older == 0)
-- the streak: consecutive days with a claim
local streakAwards = function(t) local n = 0 for _, a in ipairs(awards) do if a.title == t then n = n + 1 end end return n end
assert(view(1).streak == 0, "a missed day breaks the streak")
for k = 0, 6 do
    goDay(cday + 2 + k)
    local s = D.active(1).street
    staff("complete", "1", s.id)
    assert(claim(1, s.id).ok)
    assert(view(1).streak == k + 1, "streak " .. (k + 1))
end
assert(streakAwards("streak_7") >= 1, "Seven Days Straight")
assert(streakAwards("streak_30") == 0)
goDay(cday + 10)
local s = D.active(1).street
staff("complete", "1", s.id); claim(1, s.id)
assert(view(1).streak == 1, "starts over after a gap")
-- 30 claims, and a contract three times
for k = 11, 40 do
    goDay(cday + k)
    local st = D.active(1).street
    staff("complete", "1", st.id); assert(claim(1, st.id).ok)
end
assert(streakAwards("streak_30") >= 1 and streakAwards("okoro_favourite") >= 1 and streakAwards("lucky_seven") >= 1, "contract titles")
-- weekly: outside the daily budget, claimable on Monday for last week
reset(); cursor = cday + 41
local wd = dayWith("weekly", "all_the_way")
local week = D.weekOf(wd)
goDay(week * 7 + 3, 23) -- Sunday 23:00
staff("complete", "1", "all_the_way")
goDay(week * 7 + 4) -- Monday
local listed = false
for _, o in ipairs(view(1).older) do if o.id == "all_the_way" and o.reward == 3000 then listed = true end end
assert(listed, "last week's contract listed on Monday")
local used = view(1).budget.used
r = claim(1, "all_the_way")
assert(r.ok and r.text == "+$3000" and view(1).budget.used == used, "the weekly pays outside the budget")
cursor = week * 7 + 6

-- ── the swap ──
reset(); goDay(cursor); cursor = cursor + 2
local cur = D.active(1)
r = swap(1, "crew"); assert(not r.ok, "no swap for the crew contract")
r = swap(1, "weekly"); assert(not r.ok)
r = swap(1, "street")
assert(r.ok, r.text)
local now1 = D.active(1)
assert(now1.street.id ~= cur.street.id and now1.street.slot == "street", "a new street contract")
for _, k in ipairs({ "action", "shift", "crew", "weekly" }) do assert(now1.street.id ~= now1[k].id) end
assert(view(1).swapsLeft == 0 and view(1).list[1].swappable == nil)
r = swap(1, "action"); assert(not r.ok and r.text == "You already used today's free swap.")
assert(view(2).swapsLeft == 1 and D.active(2).street.id == cur.street.id, "a swap is personal")
goDay(cursor - 1)
staff("complete", "1", D.active(1).street.id)
r = swap(1, "street"); assert(not r.ok and r.text:find("finished", 1, true), "a finished contract is claimed, not swapped")

-- ── staff ──
local okOff = staff("off"); assert(okOff and view(1).enabled == false)
assert(not claim(1, D.active(1).street.id).ok and results[#results].text == "Contracts are paused right now.")
staff("on")
local beforeReroll = D.dayDraw(D.day()).street.id
assert(staff("reroll", "street"))
local afterReroll = D.dayDraw(D.day()).street.id
assert(afterReroll ~= beforeReroll and afterReroll ~= D.dayDraw(D.day() - 1).street.id, "a reroll gives another, not yesterday's")
local ok, text = staff("status"); assert(ok and text:find("street " .. afterReroll, 1, true))
assert(staff("day", "1")); assert(D.day() == math.floor(unixNow / 86400) + 1); staff("day", "0")
assert(not staff("complete", "1", "nope"))

-- ── the database: a restart keeps progress, claims and the streak ──
LightRP.db.ready = true
reset(); local dbd = dayWith("street", "lucky_number")
D.onMoneyChanged(1, "bank", 1, 777)
assert(claim(1, "lucky_number").ok)
D.onMoneyChanged(2, "bank", 1, 1777)
local streakBefore = view(1).streak
tick(31000); D.flush()
dofile("server/modules/dailies.lua")
D = LightRP.dailies
assert(LightRP.dailies ~= nil)
LightRP.eachModule("onCharacterLoaded", 1); LightRP.eachModule("onCharacterLoaded", 2)
assert(card(1, "lucky_number").claimed and card(2, "lucky_number").done and not card(2, "lucky_number").claimed, "restored from the database")
assert(view(1).streak == streakBefore and view(1).budget.used == 250)
assert(not claim(1, "lucky_number").ok, "still paid once after a restart")
dbFail = true
D.onMoneyChanged(1, "bank", 1, 777) -- nothing new
local cnt = #paid
r = claim(2, "lucky_number")
assert(not r.ok and r.text == "The claim could not be saved. Please try again." and #paid == cnt, "no save, no pay")
dbFail = false
assert(claim(2, "lucky_number").ok)
LightRP.db.ready = false

-- ── switched off in the config: nothing moves ──
reset(); dayWith("street", "lucky_number")
D.enabled = false
D.onMoneyChanged(1, "bank", 1, 777)
D.enabled = true
assert(not isDone(1, "lucky_number"), "off means off")

-- ── the page state stays small whatever the day ──
for k = 0, 30 do goDay(D0 + k); assert(values(view(1)) < 300) end

print("dailies_test: ok")
