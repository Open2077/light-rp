-- Daily and weekly contracts: three daily contracts (Street, Action, Shift), a
-- crew contract and a weekly one, told by the city's fixers. Content and rules:
-- docs/dailies-titles.md; numbers: server/config/dailies.lua.
--
-- Everything is checked here, server side, from hooks other modules already raise
-- (or one-line hooks added for this) and from samples of positions, seats and
-- animations the server reads itself. The page only shows the state and asks to
-- claim or swap; it never reports progress.
--
-- Public:
--   LightRP.dailies.claim(playerId, contractId)  -> ok, text
--   LightRP.dailies.swap(playerId, slot)          -> ok, text
--   LightRP.dailies.active(playerId)              -> { [slot] = def }
--   LightRP.dailies.day() / .week()               -> current UTC day / week numbers
-- Hooks used: onMoneyChanged, onMoneySent, onItemUsed, onRefuelled, onFuelEmpty,
--   onActivityResult, onMissionFinished, onWorldEventEnded, onPatientStabilized,
--   onJobWorkCompleted, onJobRunStarted, onJobRunCompleted, onJobChanged.
local C, Db = LightRpDailies, LightRP.db
local D = LightRP.module("dailies", {})

local SLOTS = { "street", "action", "shift", "crew", "weekly" }
local DAILY = { street = true, action = true, shift = true }

local defs, bySlot = {}, { street = {}, action = {}, shift = {}, crew = {}, weekly = {} }
for _, def in ipairs(C.contracts) do
    defs[def.id] = def
    if bySlot[def.slot] then table.insert(bySlot[def.slot], def) end
end
D.defs = defs

D.enabled = C.enabled ~= false
local startedAt = LightRP.nowMs()
local dayOffset = 0          -- staff: a simulated day change (/lightrp.dailies day)
local salts = {}             -- staff rerolls: [slot .. period] = n
local recs = {}              -- identifier -> { [periodKey] = rec }
local metas = {}             -- identifier -> { streak, lastDay, claimed, counts = {}, toured = {} }
local scratch = {}           -- identifier -> { [periodKey .. ":" .. contractId] = table } (session only)
local loading = {}           -- identifier -> true while the database read runs
local busy = {}              -- identifier -> true while a claim settles
local pushAt = {}            -- playerId -> true: state to send on the next flush
local lastPos = {}           -- playerId -> { x, y, z, bucket }
local draws = {}             -- [day] = { street, action, crew } frozen once the server settled

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_dailies (
    identifier VARCHAR(128) NOT NULL, period VARCHAR(12) NOT NULL,
    state TEXT NOT NULL, revision INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, period)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_dailies_meta (
    identifier VARCHAR(128) NOT NULL PRIMARY KEY, streak INT NOT NULL DEFAULT 0,
    last_day INT NOT NULL DEFAULT -1, claimed INT NOT NULL DEFAULT 0, counts TEXT NULL,
    revision INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

-- ---------------------------------------------------------------------------
-- Time: UTC days, weeks from Monday (1970-01-01 was a Thursday).

local function now() return LightRP.nowMs() end
local function unix()
    local fn = (Open77 and Open77.time and Open77.time.unix) or GetUnixTime
    if type(fn) == "function" then
        local ok, value = pcall(fn)
        if ok and tonumber(value) then return math.floor(tonumber(value)) + dayOffset * 86400 end
    end
    return dayOffset * 86400
end
local function today() return math.floor(unix() / 86400) end
local function weekOf(day) return math.floor((day + 3) / 7) end
local function weekEnd(week) return week * 7 + 3 end -- the week's last day (Sunday)
D.day = today
D.week = function() return weekOf(today()) end
D.weekOf = weekOf
local function dayKey(day) return "d" .. day end
local function weekKey(week) return "w" .. week end
local function resetInMs() local u = unix(); return (86400 - u % 86400) * 1000 end
local function weekResetInMs() local u = unix(); return ((weekEnd(weekOf(today())) + 1) * 86400 - u) * 1000 end

-- FNV-1a: the same day draws the same contracts on every server start.
local function hash(text)
    local h = 2166136261
    for i = 1, #text do h = ((h ~ text:byte(i)) * 16777619) & 0xffffffff end
    return h
end
D.hash = hash

-- ---------------------------------------------------------------------------
-- Who, where, which job

local function accountOf(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if c and c.status == "active" and c.identifier then return c.identifier, c end
end
local function jobOf(id)
    local j = LightRP.jobs and LightRP.jobs.get(id)
    return j and j.name or "unemployed"
end
local function players()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and id > 0 then list[#list + 1] = id end
    end
    return list
end
local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function positionOf(id)
    if type(id) ~= "number" or id < 1 then return nil end
    local ok, p = pcall(Open77.players.position, id)
    return ok and type(p) == "table" and p or nil
end
local function crewOf(id) return LightRP.parties and LightRP.parties.of and LightRP.parties.of(id) or nil end
-- Crewmates on other accounts (never the player's own alt).
local function crewmates(id)
    local p, mine = crewOf(id), accountOf(id)
    local list = {}
    if not p or not mine then return list end
    for _, other in ipairs(p.members or {}) do
        local theirs = other ~= id and accountOf(other)
        if theirs and theirs ~= mine then list[#list + 1] = other end
    end
    return list
end
D.crewmates = crewmates
local function hub()
    local H = type(LightRpActivities) == "table" and LightRpActivities.hub
    return H and H.center
end
local function atHub(p)
    local center = hub()
    return center and p and (p.bucket or 0) == 0 and dist(p, center) <= (C.hubRadius or 40)
end
local function money(n) return LightRP.money and LightRP.money.format and LightRP.money.format(n) or ("€$ " .. tostring(n)) end
local function fixerName(def) local f = C.fixers[def.fixer]; return f and f.name or def.fixer end

-- ---------------------------------------------------------------------------
-- Sources: a contract whose system is missing is never drawn.

local function activity(activityId)
    return function()
        local A = LightRP.activities
        return A ~= nil and type(A.registry) == "table" and A.registry[activityId] ~= nil
    end
end
local function missionPoint(pointId)
    return function()
        local M = LightRP.missions
        return M ~= nil and type(M.point) == "function" and M.point(pointId) ~= nil
    end
end
local function has(path)
    return function()
        local v = _G
        for part in path:gmatch("[^.]+") do v = type(v) == "table" and v[part] or nil end
        return v ~= nil and v ~= false
    end
end
local function always() return true end
local function bars()
    local P = type(LightRpConfig) == "table" and LightRpConfig.mapPlaces
    local list = {}
    for _, place in ipairs(P and P.enabled ~= false and P.places or {}) do
        if place.kind == "bar" and place.position then list[#list + 1] = place end
    end
    return list
end
local function worldBosses()
    local W = LightRP.worldBosses
    if not W or type(W.catalogue) ~= "function" then return false end
    local ok, list = pcall(W.catalogue)
    return ok and type(list) == "table" and #list > 0
end
local Sources = {
    lucky_number = has("LightRP.money"),
    eat_together = has("LightRP.inventory"),
    housewarming = function() local H = LightRP.housing; return H ~= nil and type(H.available) == "function" and H.available() == true end,
    running_on_fumes = has("LightRP.refueling"),
    ride_along = has("Open77.vehicles.getPlayerSeat"),
    street_performer = has("Open77.animations.current"),
    the_tour = always,
    before_overclock = missionPoint("chimera_raid"),
    lose_them = activity("chase.pve"),
    run_it_back = activity("race.trial"),
    billable_hours = has("LightRP.missions"),
    answer_phone = function() return type(LightRpFixers) == "table" and LightRpFixers.enabled ~= false and LightRP.missions ~= nil end,
    five_streak = activity("arena.pve"),
    full_truck = has("LightRP.jobWork"),
    full_round = has("LightRP.jobWork"),
    still_hot = has("LightRpDelivery"),
    fragile = function() return type(LightRpDelivery) == "table" and type(Open77.vehicles) == "table" and type(Open77.vehicles.getHealth) == "function" end,
    heat_wave = function() local R = type(LightRpJobRuns) == "table" and LightRpJobRuns.routes.ac_cleaner; return R ~= nil and #(R.steps or {}) > 0 end,
    on_call = has("LightRP.medical"),
    fare_paid = has("Open77.vehicles.getPlayerSeat"),
    roadside = has("LightRP.refueling"),
    clock_in = always,
    convoy = has("Open77.vehicles.getPlayerSeat"),
    back_to_back = activity("arena.pve"),
    bar_crawl = function() return #bars() >= 3 end,
    album_cover = has("Open77.animations.current"),
    nobody_left_behind = activity("chase.pve"),
    two_vs_machine = missionPoint("chimera_raid"),
    all_the_way = activity("arena.duel"),
    lions_share = worldBosses,
    both_sides = activity("chase.wanted"),
    good_samaritan = has("LightRP.medical"),
}
D.sources = Sources
local function available(def)
    local check = Sources[def.id]
    if not check then return false end
    local ok, yes = pcall(check)
    return ok and yes == true
end
D.available = available

-- ---------------------------------------------------------------------------
-- The draws

local function pick(list, seed, exclude)
    local cands = {}
    for _, def in ipairs(list) do
        if available(def) and not (exclude and exclude[def.id]) then cands[#cands + 1] = def end
    end
    if #cands == 0 then return nil end
    return cands[hash(seed) % #cands + 1]
end
local function seedOf(slot, period) return slot .. ":" .. period .. ":" .. (salts[slot .. period] or 0) end
local function rawDraw(slot, period) return pick(bySlot[slot], seedOf(slot, period)) end
-- Never the same contract as the period before in the same slot.
local function drawSlot(slot, period)
    local before = rawDraw(slot, period - 1)
    return pick(bySlot[slot], seedOf(slot, period), before and { [before.id] = true } or nil)
end
-- The shared contracts of a day. Frozen once the server has settled (providers
-- register in the first seconds), so a resource stopping later never changes
-- what the city is doing today.
local function dayDraw(day)
    local cached = draws[day]
    if cached then return cached end
    local d = { street = drawSlot("street", day), action = drawSlot("action", day), crew = drawSlot("crew", day) }
    if now() - startedAt >= 120000 then draws[day] = d end
    return d
end
local function weekDraw(week)
    local key = "w" .. week
    local cached = draws[key]
    if cached then return cached.weekly end
    local d = { weekly = drawSlot("weekly", week) }
    if now() - startedAt >= 120000 then draws[key] = d end
    return d.weekly
end
-- Shift: the same for everyone in a job; a job without contracts (NCPD) gets a
-- Street contract other than the city's one.
local function shiftDraw(day, job)
    local list = {}
    for _, def in ipairs(bySlot.shift) do
        for _, j in ipairs(def.jobs or {}) do if j == job then list[#list + 1] = def break end end
    end
    local salt = (salts["shift" .. day] or 0)
    local chosen = pick(list, "shift:" .. job .. ":" .. day .. ":" .. salt)
    if chosen then return chosen end
    local street = dayDraw(day).street
    return pick(bySlot.street, "shift-street:" .. job .. ":" .. day .. ":" .. salt, street and { [street.id] = true } or nil)
end
D.dayDraw, D.weekDraw, D.shiftDraw = dayDraw, weekDraw, shiftDraw

-- ---------------------------------------------------------------------------
-- Records: one per account and period ("d20395", "w2914").

local function newRec(key) return { key = key, list = {}, swaps = 0, budget = 0, slots = {}, dirtyAt = nil } end
local function recOf(identifier, key)
    local mine = recs[identifier]
    if not mine then mine = {}; recs[identifier] = mine end
    local rec = mine[key]
    if not rec then rec = newRec(key); mine[key] = rec end
    return rec
end
local function metaOf(identifier)
    local m = metas[identifier]
    if not m then m = { streak = 0, lastDay = -1, claimed = 0, counts = {}, toured = {} }; metas[identifier] = m end
    return m
end
local function scratchOf(identifier, key, contractId)
    local mine = scratch[identifier]
    if not mine then mine = {}; scratch[identifier] = mine end
    local k = key .. ":" .. contractId
    local s = mine[k]
    if not s then s = {}; mine[k] = s end
    return s
end
local function encode(value)
    local ok, text = pcall(json.encode, value)
    return ok and type(text) == "string" and text or "{}"
end
local function decode(text)
    if type(text) ~= "string" or text == "" then return nil end
    local ok, value = pcall(json.decode, text)
    return ok and type(value) == "table" and value or nil
end
local function saveRec(identifier, rec)
    rec.dirtyAt = nil
    if not Db.ready then return true end
    local state = { list = rec.list, swaps = rec.swaps, budget = rec.budget, slots = rec.slots, shift = rec.shift }
    local ok = Db.run([[INSERT INTO lightrp_dailies (identifier, period, state) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE state = VALUES(state), revision = revision + 1]], { identifier, rec.key, encode(state) })
    return ok == true
end
local function saveMeta(identifier)
    if not Db.ready then return true end
    local m = metaOf(identifier)
    local ok = Db.run([[INSERT INTO lightrp_dailies_meta (identifier, streak, last_day, claimed, counts) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE streak = VALUES(streak), last_day = VALUES(last_day), claimed = VALUES(claimed),
        counts = VALUES(counts), revision = revision + 1]],
        { identifier, m.streak, m.lastDay, m.claimed, encode({ counts = m.counts, toured = m.toured }) })
    return ok == true
end
local function touch(rec) rec.dirtyAt = rec.dirtyAt or now() end

-- Merge what the database holds into what this session already counted: the
-- larger progress, any finish, any claim.
local function merge(rec, state)
    if type(state) ~= "table" then return end
    for id, saved in pairs(type(state.list) == "table" and state.list or {}) do
        if defs[id] and type(saved) == "table" then
            local e = rec.list[id]
            if not e then rec.list[id] = saved
            else
                e.v = math.max(tonumber(e.v) or 0, tonumber(saved.v) or 0)
                e.done = e.done or saved.done
                e.claimed = e.claimed or saved.claimed
                if type(saved.data) == "table" and not e.data then e.data = saved.data end
            end
        end
    end
    rec.swaps = math.max(rec.swaps, tonumber(state.swaps) or 0)
    rec.budget = math.max(rec.budget, tonumber(state.budget) or 0)
    for slot, id in pairs(type(state.slots) == "table" and state.slots or {}) do
        if defs[id] and not rec.slots[slot] then rec.slots[slot] = id end
    end
    if type(state.shift) == "table" and defs[state.shift.id] and not rec.shift then rec.shift = state.shift end
end

local function load(identifier)
    if loading[identifier] or not Db.ready then return end
    loading[identifier] = true
    local day = today()
    local week = weekOf(day)
    local keys = { dayKey(day), dayKey(day - 1), weekKey(week), weekKey(week - 1) }
    local ok, rows = Db.read("SELECT period, state FROM lightrp_dailies WHERE identifier = ? AND period IN (?, ?, ?, ?)",
        { identifier, keys[1], keys[2], keys[3], keys[4] })
    if ok then for _, row in ipairs(rows) do merge(recOf(identifier, tostring(row.period)), decode(row.state)) end end
    local okMeta, metaRows = Db.read("SELECT streak, last_day, claimed, counts FROM lightrp_dailies_meta WHERE identifier = ?", { identifier })
    if okMeta and metaRows[1] then
        local m, row = metaOf(identifier), metaRows[1]
        m.streak = math.max(m.streak, tonumber(row.streak) or 0)
        m.lastDay = math.max(m.lastDay, tonumber(row.last_day) or -1)
        m.claimed = math.max(m.claimed, tonumber(row.claimed) or 0)
        local extra = decode(row.counts) or {}
        for k, n in pairs(type(extra.counts) == "table" and extra.counts or {}) do m.counts[k] = math.max(m.counts[k] or 0, tonumber(n) or 0) end
        for k, v in pairs(type(extra.toured) == "table" and extra.toured or {}) do m.toured[k] = v end
    end
    loading[identifier] = nil
end

-- ---------------------------------------------------------------------------
-- What a player has today

-- { street = def, action = def, shift = def, crew = def, weekly = def }, the
-- day's record and the week's record.
local function activeFor(id)
    local identifier = accountOf(id)
    if not identifier then return nil end
    local day = today()
    local rec, wrec = recOf(identifier, dayKey(day)), recOf(identifier, weekKey(weekOf(day)))
    local shared = dayDraw(day)
    local job = jobOf(id)
    local pickShift = rec.shift
    local doneShift = pickShift and rec.list[pickShift.id] and rec.list[pickShift.id].done
    if not pickShift or not defs[pickShift.id] or (pickShift.job ~= job and pickShift.id ~= "clock_in" and not doneShift) then
        local def = shiftDraw(day, job)
        pickShift = def and { id = def.id, job = job } or nil
        rec.shift = pickShift
        if pickShift then touch(rec) end
    end
    local out = {
        street = defs[rec.slots.street or ""] or shared.street,
        action = defs[rec.slots.action or ""] or shared.action,
        shift = defs[rec.slots.shift or ""] or (pickShift and defs[pickShift.id]),
        crew = shared.crew,
        weekly = weekDraw(weekOf(day)),
    }
    return out, rec, wrec, identifier
end
D.active = function(id) return (activeFor(id)) end

local function push(id) pushAt[id] = true end
local function pushNow(id) pushAt[id] = nil; LightRP.state(id, { "dailies" }) end

-- A contract's progress for a player, when it is one of theirs today and not done.
local function contextOf(id, contractId)
    local active, rec, wrec, identifier = activeFor(id)
    if not active then return nil end
    for _, slot in ipairs(SLOTS) do
        local def = active[slot]
        if def and def.id == contractId then
            local r = slot == "weekly" and wrec or rec
            local e = r.list[def.id]
            if not e then e = { v = 0 }; r.list[def.id] = e end
            if e.done then return nil end
            return { id = id, account = identifier, def = def, slot = slot, rec = r, entry = e,
                scratch = scratchOf(identifier, r.key, def.id) }
        end
    end
end

local function finish(ctx)
    local e, def = ctx.entry, ctx.def
    if e.done then return end
    e.v, e.done = def.target or 1, true
    touch(ctx.rec)
    saveRec(ctx.account, ctx.rec)
    LightRP.notice(ctx.id, { kind = "contract", title = "CONTRACT COMPLETE", durationMs = 9000,
        body = string.format("%s · %s. Claim %s in F1 > Contracts.", def.title, fixerName(def), money(C.rewards[ctx.slot] or 0)) })
    LightRP.log("dailies: %s completed %s", ctx.account, def.id)
    pushNow(ctx.id)
    LightRP.eachModule("onContractCompleted", ctx.id, def.id, ctx.slot)
end
local function setValue(ctx, value)
    local target = ctx.def.target or 1
    value = math.max(0, math.min(target, tonumber(value) or 0))
    if value >= target then return finish(ctx) end
    if math.floor(value) ~= math.floor(tonumber(ctx.entry.v) or 0) then push(ctx.id) end
    if value ~= ctx.entry.v then ctx.entry.v = value; touch(ctx.rec) end
end
local function addValue(ctx, delta)
    if not delta or delta <= 0 then return end
    setValue(ctx, (tonumber(ctx.entry.v) or 0) + delta)
end
-- Apply fn to a player's contract if it is theirs and still open.
local function with(id, contractId, fn)
    if not D.enabled then return end
    local ctx = contextOf(id, contractId)
    if ctx then fn(ctx) end
end
D.with = with
D.finish = function(id, contractId) with(id, contractId, finish) end

-- ---------------------------------------------------------------------------
-- The checks. K[id][event] = function(ctx, ...) for events raised to one player;
-- K[id].sample = function(ctx, t) for the samples.

local K = {}
D.checks = K
local function itemUse(name)
    local t = type(LightRpItems) == "table" and LightRpItems[name]
    return t and t.use or nil
end

K.lucky_number = { money = function(ctx, wallet, _, balance)
    if wallet ~= "bank" then return end
    local n = math.floor(tonumber(balance) or -1)
    if n >= 0 and n % 1000 == 777 then finish(ctx) end
end }

K.running_on_fumes = { refuel = function(ctx, info)
    if info.kind ~= "vehicle" or not info.capacity or info.capacity <= 0 then return end
    if info.before / info.capacity < ctx.def.below and (info.before + info.litres) / info.capacity >= ctx.def.upTo then finish(ctx) end
end }

local emptyCars = {} -- vehicleId -> { at, account }
K.roadside = { refuel = function(ctx, info)
    if info.kind ~= "pour" then return end
    local e = emptyCars[tostring(info.vehicle)]
    if e and e.account ~= ctx.account and now() - e.at <= ctx.def.minutes * 60000 then finish(ctx) end
end }

K.lose_them = { activity = function(ctx, entry, _, raw, verdict)
    local s = type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {}
    if entry.activity == "chase.pve" and verdict.eligible and s.outcome == "escaped" and s.how == "shake" then finish(ctx) end
end }

K.run_it_back = { activity = function(ctx, entry, _, raw)
    local s = type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {}
    local ms, course = tonumber(s.timeMs), s.courseId and tostring(s.courseId)
    if entry.activity ~= "race.trial" or s.finished ~= true or not ms or ms <= 0 or not course then return end
    ctx.entry.data = ctx.entry.data or {}
    local first = tonumber(ctx.entry.data[course])
    if not first then ctx.entry.data[course] = ms; touch(ctx.rec); push(ctx.id); return end
    if ms <= first - ctx.def.marginMs then finish(ctx) end
end }

K.five_streak = { activity = function(ctx, entry, _, raw, verdict)
    local s = type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {}
    if entry.activity == "arena.pve" and verdict.eligible and (tonumber(s.bestStreak) or 0) >= ctx.def.streak then finish(ctx) end
end }

K.all_the_way = { activity = function(ctx, entry, r, raw, verdict)
    local s = type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {}
    local won, lost = tonumber(s.roundsWon) or 0, tonumber(s.roundsLost) or 0
    if entry.activity == "arena.duel" and verdict.eligible and (r and r.won or raw.won) and lost >= 1 and lost == won - 1 then finish(ctx) end
end }

K.both_sides = { activity = function(ctx, entry, _, raw, verdict)
    local s = type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {}
    if entry.activity == "chase.wanted" and verdict.eligible and (tonumber(s.arrests) or 0) >= 1
        and ((tonumber(s.extractions) or 0) >= 1 or (tonumber(s.survivals) or 0) >= 1) then finish(ctx) end
end }

local function chimera(point) return point and point.id == "chimera_raid" end
K.before_overclock = { mission = function(ctx, inst, point, _, success)
    if success and not inst.test and chimera(point) and type(inst.report) == "table" and inst.report.enraged == false then finish(ctx) end
end }
K.billable_hours = { mission = function(ctx, inst, _, d, success, _, at)
    local limit = d and tonumber(d.minutes) and d.minutes * 60000
    if success and not inst.test and limit and inst.startedAt and at - inst.startedAt <= limit / 2 then finish(ctx) end
end }
K.answer_phone = { mission = function(ctx, inst, _, _, success)
    if success and not inst.test and inst.gig then finish(ctx) end
end }
K.two_vs_machine = { mission = function(ctx, inst, point, d, success)
    if success and not inst.test and chimera(point) and d and (d.id == "hard" or d.id == "critical") and #(inst.members or {}) == 2 then finish(ctx) end
end }

K.on_call = { stabilize = function(ctx, patient)
    local theirs = accountOf(patient)
    if theirs and theirs ~= ctx.account and jobOf(ctx.id) == "trauma" then finish(ctx) end
end }
K.good_samaritan = { stabilize = function(ctx, patient)
    local theirs = accountOf(patient)
    if not theirs or theirs == ctx.account then return end
    for _, mate in ipairs(crewmates(ctx.id)) do if mate == patient then return end end
    ctx.entry.data = ctx.entry.data or {}
    if ctx.entry.data[theirs] then return end
    ctx.entry.data[theirs] = true
    local n = 0
    for _ in pairs(ctx.entry.data) do n = n + 1 end
    setValue(ctx, n)
    if not ctx.entry.done then saveRec(ctx.account, ctx.rec) end
end }

K.full_truck = { work = function(ctx, job, kind, info)
    if kind == "sell" and (job == "sanitation" or job == "scrapper") and type(info) == "table" and (tonumber(info.count) or 0) >= ctx.def.count then finish(ctx) end
end }
K.full_round = { work = function(ctx, job, kind, info)
    local wanted = ctx.def.points[job]
    if not wanted or type(info) ~= "table" then return end
    local s, t = ctx.scratch, now()
    s.at = s.at or {}
    if kind == "collect" then
        s.at[info.point] = t
        local n = 0
        for _, p in ipairs(wanted) do if s.at[p] and t - s.at[p] <= ctx.def.minutes * 60000 then n = n + 1 end end
        if n >= #wanted then push(ctx.id) end
    elseif kind == "sell" then
        local earliest = t
        for _, p in ipairs(wanted) do
            if not s.at[p] then return end
            earliest = math.min(earliest, s.at[p])
        end
        if t - earliest <= ctx.def.minutes * 60000 then finish(ctx) end
    end
end }
K.clock_in = {
    jobChanged = function(ctx, job)
        local name = type(job) == "table" and job.name or job
        if name and name ~= "unemployed" and (tonumber(ctx.entry.v) or 0) < 1 then setValue(ctx, 1); saveRec(ctx.account, ctx.rec) end
    end,
    work = function(ctx, job, _, info)
        if (tonumber(ctx.entry.v) or 0) >= 1 and job ~= "unemployed" and not (type(info) == "table" and info.practice) then finish(ctx) end
    end,
    runDone = function(ctx) if (tonumber(ctx.entry.v) or 0) >= 1 then finish(ctx) end end,
}
K.still_hot = {
    runStart = function(ctx, run) if run.job == "delivery" then ctx.scratch.run, ctx.scratch.at = run.id, now() end end,
    runDone = function(ctx, run)
        local s = ctx.scratch
        if run.job ~= "delivery" or s.run ~= run.id then return end
        local km = tonumber(run.route and run.route.distanceKm) or 0
        if now() - s.at <= (ctx.def.baseMinutes + ctx.def.perKmMinutes * km) * 60000 then finish(ctx) end
    end,
}
K.heat_wave = {
    runStart = function(ctx, run) if run.job == "ac_cleaner" then ctx.scratch.run, ctx.scratch.at = run.id, now() end end,
    runDone = function(ctx, run)
        if run.job == "ac_cleaner" and ctx.scratch.run == run.id and now() - ctx.scratch.at <= ctx.def.minutes * 60000 then finish(ctx) end
    end,
}
local function healthOf(vehicleId)
    local ok, h = pcall(Open77.vehicles.getHealth, vehicleId)
    return ok and tonumber(h) or nil
end
K.fragile = {
    runStart = function(ctx, run)
        if run.job ~= "delivery" then return end
        local s = ctx.scratch
        s.run, s.vehicle, s.start, s.min, s.broken = run.id, nil, nil, nil, nil
    end,
    sample = function(ctx, t)
        local s = ctx.scratch
        if not s.run then return end
        local seat = t.seatOf(ctx.id)
        if not seat or seat.seat ~= "seat_front_left" then return end
        local h = healthOf(seat.vehicleId)
        if not h then return end
        if not s.vehicle then s.vehicle, s.start, s.min = seat.vehicleId, h, h
        elseif s.vehicle ~= seat.vehicleId then s.broken = true
        else s.min = math.min(s.min, h) end
    end,
    runDone = function(ctx, run)
        local s = ctx.scratch
        if s.run ~= run.id then return end
        s.run = nil
        if s.broken or not s.vehicle or not s.start or s.start <= 0 then return end
        local h = healthOf(s.vehicle)
        local low = math.min(s.min or s.start, h or s.min or s.start)
        if low >= s.start * (1 - ctx.def.maxLoss) then finish(ctx) end
    end,
}

-- Samples: t.moved[id] is how far the player went since the last sample (0
-- after a teleport or a bucket change), t.seatOf / t.animOf read once per tick.
K.ride_along = { sample = function(ctx, t)
    local seat = t.seatOf(ctx.id)
    if not seat then return end
    for _, other in ipairs(t.occupants(seat.vehicleId)) do
        local theirs = other ~= ctx.id and accountOf(other)
        if theirs and theirs ~= ctx.account then return addValue(ctx, t.moved[ctx.id]) end
    end
end }
K.street_performer = { sample = function(ctx, t)
    local s, p, a = ctx.scratch, t.pos[ctx.id], t.animOf(ctx.id)
    local audience = false
    if a and atHub(p) then
        for other, q in pairs(t.pos) do
            local theirs = other ~= ctx.id and accountOf(other)
            if theirs and theirs ~= ctx.account and (q.bucket or 0) == 0 and dist(p, q) <= ctx.def.audience then audience = true break end
        end
    end
    if not audience then
        if s.playback then s.playback = nil; setValue(ctx, 0) end
        return
    end
    if s.playback ~= a.playbackId then s.playback = a.playbackId; setValue(ctx, 0); return end
    addValue(ctx, t.dt)
end }
local function playedHours(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if not c then return math.huge end
    local ms = (tonumber(c.playtimeMs) or 0) + math.max(0, now() - (tonumber(c.joinedAtMs) or now()))
    return ms / 3600000
end
K.the_tour = { sample = function(ctx, t)
    local p = t.pos[ctx.id]
    if not p or (t.moved[ctx.id] or 0) <= 0 then return end
    local m = metaOf(ctx.account)
    for other, q in pairs(t.pos) do
        local theirs = other ~= ctx.id and accountOf(other)
        if theirs and theirs ~= ctx.account and not m.toured[theirs] and (q.bucket or 0) == (p.bucket or 0)
            and dist(p, q) <= ctx.def.range and (t.moved[other] or 0) > 0.5 and playedHours(other) < ctx.def.newcomerHours then
            ctx.scratch.newcomers = ctx.scratch.newcomers or {}
            ctx.scratch.newcomers[theirs] = other
            addValue(ctx, t.moved[ctx.id])
            if ctx.entry.done then
                for account, newcomer in pairs(ctx.scratch.newcomers) do
                    m.toured[account] = true
                    if accountOf(newcomer) == account then
                        LightRP.notice(newcomer, { kind = "message", title = "Mama Okoro", durationMs = 9000,
                            body = "Somebody showed you around today. Pay it forward, choom." })
                    end
                end
                saveMeta(ctx.account)
            end
            return
        end
    end
end }
K.housewarming = { sample = function(ctx, t)
    local H, S = LightRP.housing, LightRP.housingStore
    local s = H and H.sessions and H.sessions[ctx.id]
    if not s or s.preview or not s.property or not S or not S.contracts then return end
    local lease = S.contracts[s.contract]
    if not lease then return end
    for other, os in pairs(H.sessions) do
        local theirs = other ~= ctx.id and accountOf(other)
        if theirs and theirs ~= ctx.account and os.property == s.property and not os.preview
            and (H.hasKey(ctx.id, lease) or H.hasKey(other, lease)) then
            return addValue(ctx, t.dt)
        end
    end
end }
K.convoy = { sample = function(ctx, t)
    local seat, p, s = t.seatOf(ctx.id), t.pos[ctx.id], ctx.scratch
    local ok = false
    if seat and seat.seat == "seat_front_left" and p then
        for _, mate in ipairs(crewmates(ctx.id)) do
            local theirs, q = t.seatOf(mate), t.pos[mate]
            if theirs and theirs.seat == "seat_front_left" and theirs.vehicleId ~= seat.vehicleId and q and dist(p, q) <= ctx.def.range then ok = true break end
        end
    end
    if ok then s.miss = nil; return addValue(ctx, t.moved[ctx.id]) end
    -- one missed sample is forgiven (a corner, a red light); two start over
    if (tonumber(ctx.entry.v) or 0) > 0 then
        if s.miss then s.miss = nil; setValue(ctx, 0) else s.miss = true end
    end
end }
K.album_cover = { sample = function(ctx, t)
    local p, s = t.pos[ctx.id], ctx.scratch
    local posing = t.animOf(ctx.id) and atHub(p)
    local with = false
    if posing then
        for _, mate in ipairs(crewmates(ctx.id)) do
            local q = t.pos[mate]
            if q and dist(p, q) <= ctx.def.range and t.animOf(mate) then with = true
            elseif q and dist(p, q) <= ctx.def.range then with = false break end
        end
    end
    if not with then s.since = nil; return end
    s.since = s.since or t.now
    if t.now - s.since >= ctx.def.seconds * 1000 then finish(ctx) end
end }
K.fare_paid = {
    sample = function(ctx, t)
        local s = ctx.scratch
        s.rides, s.owed = s.rides or {}, s.owed or {}
        local seat = jobOf(ctx.id) == "taxi" and t.seatOf(ctx.id)
        local inside = {}
        if seat and seat.seat == "seat_front_left" then
            for _, other in ipairs(t.occupants(seat.vehicleId)) do
                local theirs = other ~= ctx.id and accountOf(other)
                if theirs and theirs ~= ctx.account then
                    inside[other] = true
                    s.rides[other] = (s.rides[other] or 0) + (t.moved[ctx.id] or 0)
                end
            end
        end
        for other, metres in pairs(s.rides) do
            if not inside[other] then
                if metres >= ctx.def.metres then s.owed[other] = t.now end
                s.rides[other] = nil
            end
        end
    end,
    moneyReceived = function(ctx, from, amount)
        local s = ctx.scratch
        local at = s.owed and s.owed[from]
        if at and now() - at <= ctx.def.windowSeconds * 1000 and (tonumber(amount) or 0) >= ctx.def.fare then finish(ctx) end
    end,
}

-- ---------------------------------------------------------------------------
-- Events raised to one player: every open contract of theirs that listens.

local function emit(id, event, ...)
    if not D.enabled then return end
    local active, rec, wrec, identifier = activeFor(id)
    if not active then return end
    for _, slot in ipairs(SLOTS) do
        local def = active[slot]
        local handler = def and K[def.id] and K[def.id][event]
        if handler then
            local r = slot == "weekly" and wrec or rec
            local e = r.list[def.id]
            if not e then e = { v = 0 }; r.list[def.id] = e end
            if not e.done then
                local ok, err = pcall(handler, { id = id, account = identifier, def = def, slot = slot, rec = r, entry = e,
                    scratch = scratchOf(identifier, r.key, def.id) }, ...)
                if not ok then LightRP.log("dailies: %s.%s failed: %s", def.id, event, tostring(err)) end
            end
        end
    end
end
D.emit = emit

-- ---------------------------------------------------------------------------
-- Hooks

function D.onMoneyChanged(id, wallet, delta, balance, kind) emit(id, "money", wallet, delta, balance, kind) end
-- economy.lua: a bank transfer or cash handed over between two online players.
function D.onMoneySent(from, to, amount, channel)
    if type(to) == "number" then emit(to, "moneyReceived", from, amount, channel) end
end

local meals, drinks = {}, {} -- recent { id, account, at, p, bar }
local function prune(list, ms)
    local t = now()
    for i = #list, 1, -1 do if t - list[i].at > ms then table.remove(list, i) end end
end
local function nearestBar(p)
    local best, bestD
    for _, b in ipairs(bars()) do
        local d = dist(p, b.position)
        if d <= (defs.bar_crawl.range or 25) and (not bestD or d < bestD) then best, bestD = b, d end
    end
    return best
end
local function crawl(id, bar)
    with(id, "bar_crawl", function(ctx)
        local s, t = ctx.scratch, now()
        s.visits = s.visits or {}
        s.visits[bar.id] = { at = t, district = bar.district or bar.id }
        local districts, n = {}, 0
        for barId, v in pairs(s.visits) do
            if t - v.at > ctx.def.minutes * 60000 then s.visits[barId] = nil
            elseif not districts[v.district] then districts[v.district] = true; n = n + 1 end
        end
        setValue(ctx, n)
    end)
end
function D.onItemUsed(id, name)
    if not D.enabled then return end
    local use, account = itemUse(name), accountOf(id)
    if not use or not account then return end
    local p = positionOf(id)
    if not p then return end
    local t = now()
    if (tonumber(use.food) or 0) > 0 and defs.eat_together then
        local def = defs.eat_together
        prune(meals, def.windowSeconds * 1000)
        for _, m in ipairs(meals) do
            if m.account ~= account and accountOf(m.id) == m.account and (m.p.bucket or 0) == (p.bucket or 0) and dist(m.p, p) <= def.range then
                with(id, "eat_together", finish)
                with(m.id, "eat_together", finish)
            end
        end
        meals[#meals + 1] = { id = id, account = account, at = t, p = p }
    end
    if (tonumber(use.drink) or 0) > 0 and defs.bar_crawl and (p.bucket or 0) == 0 then
        local bar = nearestBar(p)
        if bar then
            prune(drinks, defs.bar_crawl.togetherSeconds * 1000)
            local mates = {}
            for _, mate in ipairs(crewmates(id)) do mates[mate] = true end
            local together = false
            for _, d in ipairs(drinks) do
                if mates[d.id] and d.bar == bar.id and accountOf(d.id) == d.account then together = true; crawl(d.id, bar) end
            end
            if together then crawl(id, bar) end
            drinks[#drinks + 1] = { id = id, account = account, at = t, p = p, bar = bar.id }
        end
    end
end

-- refueling.lua: kind "vehicle" (pump), "pour" (jerrycan into a car), "can" (filling a can).
function D.onRefuelled(id, info) if type(info) == "table" then emit(id, "refuel", info) end end
function D.onFuelEmpty(vehicleId, driver)
    local account = type(driver) == "number" and accountOf(driver)
    if account then emptyCars[tostring(vehicleId)] = { at = now(), account = account } end
end

-- activity_pay.lua: verdict = { amount, kind, detail }; amount ~= nil = paid-eligible.
local crewArena, crewChase = {}, {} -- crew id -> recent results
local function crewResult(store, id, record, windowMs)
    local p = crewOf(id)
    if not p then return nil end
    local list = store[p.id] or {}
    store[p.id] = list
    local t = now()
    for i = #list, 1, -1 do if t - list[i].at > windowMs or list[i].account == record.account then table.remove(list, i) end end
    record.at = t
    list[#list + 1] = record
    return list
end
function D.onActivityResult(id, entry, r, raw, verdict)
    if not D.enabled or type(entry) ~= "table" then return end
    verdict = type(verdict) == "table" and verdict or {}
    verdict.eligible = verdict.amount ~= nil
    raw = type(raw) == "table" and raw or {}
    emit(id, "activity", entry, r or {}, raw, verdict)
    local s, account = type(raw.stats) == "table" and raw.stats or {}, accountOf(id)
    if not account then return end
    local won = (r and r.won) or raw.won
    if entry.activity == "arena.pve" and won and verdict.eligible and (tonumber(s.kills) or 0) >= 1 and defs.back_to_back then
        local list = crewResult(crewArena, id, { id = id, account = account }, defs.back_to_back.windowSeconds * 1000)
        if list and #list >= 2 then for _, x in ipairs(list) do with(x.id, "back_to_back", finish) end end
    end
    if entry.activity == "chase.pve" and s.crew and defs.nobody_left_behind then
        local escaped = s.outcome == "escaped" and verdict.eligible
        local list = crewResult(crewChase, id, { id = id, account = account, escaped = escaped }, defs.nobody_left_behind.windowSeconds * 1000)
        if list and #list >= 2 then
            local all = true
            for _, x in ipairs(list) do all = all and x.escaped end
            if all then for _, x in ipairs(list) do with(x.id, "nobody_left_behind", finish) end end
        end
    end
end

-- missions.lua finish(): after the payouts, inst.members still listed.
function D.onMissionFinished(inst, point, d, success, why, payouts)
    if not D.enabled or type(inst) ~= "table" then return end
    local at = now()
    for _, id in ipairs(inst.members or {}) do emit(id, "mission", inst, point, d, success, why, at, payouts and payouts[id]) end
end

-- world_bosses.lua finish(): the top eligible contributor of a boss that went down.
function D.onWorldEventEnded(ev, success)
    if not D.enabled or not success or type(ev) ~= "table" then return end
    local top, best = nil, -1
    for id, c in pairs(ev.contrib or {}) do
        if c.eligible and (tonumber(c.score) or 0) > best then top, best = id, tonumber(c.score) or 0 end
    end
    if top then with(top, "lions_share", finish) end
end

function D.onPatientStabilized(actor, patient) if actor then emit(actor, "stabilize", patient) end end
function D.onJobWorkCompleted(id, job, kind, info) emit(id, "work", job, kind, info) end
function D.onJobRunStarted(id, run) if type(run) == "table" then emit(id, "runStart", run) end end
function D.onJobRunCompleted(id, run) if type(run) == "table" then emit(id, "runDone", run) end end
function D.onJobChanged(id, job, previous) emit(id, "jobChanged", job, previous) end

function D.onCharacterLoaded(id)
    local identifier = accountOf(id)
    if identifier then CreateThread(function() load(identifier); push(id) end) end
end
D.onCharacterActivated = D.onCharacterLoaded
function D.onUiReady(id) push(id) end
function D.onDisconnected(id)
    pushAt[id], lastPos[id] = nil, nil
end
function D.onDatabaseReady()
    for _, id in ipairs(players()) do D.onCharacterLoaded(id) end
end

-- ---------------------------------------------------------------------------
-- Claim and swap

local function findClaimable(identifier, contractId)
    local def = defs[contractId]
    if not def then return nil end
    local day = today()
    local keys
    if def.slot == "weekly" then
        local week = weekOf(day)
        keys = { weekKey(week) }
        if day - weekEnd(week - 1) <= (C.claimGraceDays or 1) then keys[2] = weekKey(week - 1) end
    else
        keys = {}
        for back = 0, (C.claimGraceDays or 1) do keys[#keys + 1] = dayKey(day - back) end
    end
    for _, key in ipairs(keys) do
        local rec = recs[identifier] and recs[identifier][key]
        local e = rec and rec.list[contractId]
        if e and e.done and not e.claimed then return def, rec, e end
    end
    return def
end

local function awardTitles(id, identifier, def)
    local T, rules = LightRP.titles, C.titleRules or {}
    if not T or type(T.award) ~= "function" then return end
    local m = metaOf(identifier)
    for _, rule in ipairs(rules.streaks or {}) do if m.streak >= rule.days then T.award(id, rule.title) end end
    for _, rule in ipairs(rules.claims or {}) do if m.claimed >= rule.count then T.award(id, rule.title) end end
    local rep = (rules.repeats or {})[def.id]
    if rep and (m.counts[def.id] or 0) >= rep.count then T.award(id, rep.title) end
end

function D.claim(id, contractId)
    if not D.enabled then return false, "Contracts are paused right now." end
    local identifier = accountOf(id)
    if not identifier then return false, "Load your character first." end
    if busy[identifier] then return false, "Your last claim is still being paid." end
    local def, rec, e = findClaimable(identifier, tostring(contractId or ""))
    if not def then return false, "Unknown contract." end
    if not rec then return false, "This contract is not finished yet, or it was already paid." end
    local reward = math.floor(tonumber(C.rewards[def.slot]) or 0)
    if reward <= 0 then return false, "This contract pays nothing." end
    if def.slot ~= "weekly" and rec.budget + reward > (C.dailyBudget or math.huge) then
        return false, string.format("Daily contract budget reached (%s per day). It resets at 00:00 UTC.", money(C.dailyBudget))
    end
    busy[identifier] = true
    e.claimed = true
    rec.budget = rec.budget + (def.slot ~= "weekly" and reward or 0)
    if not saveRec(identifier, rec) then
        e.claimed = false
        rec.budget = rec.budget - (def.slot ~= "weekly" and reward or 0)
        busy[identifier] = nil
        return false, "The claim could not be saved. Please try again."
    end
    local paid, why = LightRP.money.addBank(id, reward, "contract", def.title, fixerName(def))
    if not paid then
        e.claimed = false
        rec.budget = rec.budget - (def.slot ~= "weekly" and reward or 0)
        saveRec(identifier, rec)
        busy[identifier] = nil
        pushNow(id)
        return false, "The payment was refused (" .. tostring(why) .. "). Try again in a moment."
    end
    -- streak: consecutive UTC days with a claimed daily or crew contract (the contract's own day)
    local m = metaOf(identifier)
    if def.slot ~= "weekly" then
        local day = tonumber(rec.key:match("^d(%-?%d+)$"))
        if day and day > m.lastDay then
            m.streak = (m.lastDay == day - 1) and (m.streak + 1) or 1
            m.lastDay = day
        end
    end
    m.claimed = m.claimed + 1
    m.counts[def.id] = (m.counts[def.id] or 0) + 1
    saveMeta(identifier)
    busy[identifier] = nil
    LightRP.notice(id, { kind = "money", title = "+" .. money(reward), durationMs = 7000,
        body = string.format("%s · paid by %s.", def.title, fixerName(def)) })
    LightRP.log("dailies: %s claimed %s (%d)", identifier, def.id, reward)
    awardTitles(id, identifier, def)
    pushNow(id)
    return true, "+" .. money(reward)
end

function D.swap(id, slot)
    if not D.enabled then return false, "Contracts are paused right now." end
    if not DAILY[slot] then return false, "Only Street, Action and Shift contracts can be swapped." end
    local active, rec, _, identifier = activeFor(id)
    if not active then return false, "Load your character first." end
    if rec.swaps >= (C.swapsPerDay or 1) then return false, "You already used today's free swap." end
    local current = active[slot]
    local e = current and rec.list[current.id]
    if e and e.done then return false, "This contract is finished: claim it instead." end
    local exclude = {}
    for _, s in ipairs(SLOTS) do if active[s] then exclude[active[s].id] = true end end
    local pool = bySlot[slot]
    if slot == "shift" then
        pool = {}
        local job = jobOf(id)
        for _, def in ipairs(bySlot.shift) do
            for _, j in ipairs(def.jobs or {}) do if j == job then pool[#pool + 1] = def break end end
        end
        if current and current.slot == "street" or #pool <= 1 then
            for _, def in ipairs(bySlot.street) do pool[#pool + 1] = def end
        end
    end
    local def = pick(pool, "swap:" .. identifier .. ":" .. slot .. ":" .. today(), exclude)
    if not def then return false, "There is no other contract to offer today." end
    if current then rec.list[current.id] = nil end
    rec.slots[slot] = def.id
    rec.swaps = rec.swaps + 1
    saveRec(identifier, rec)
    pushNow(id)
    return true, string.format("New contract: %s.", def.title)
end

-- ---------------------------------------------------------------------------
-- The page state ("dailies"): about 80 values.

local function card(def, slot, rec, crewReady)
    local e = rec.list[def.id] or {}
    return { slot = slot, id = def.id, title = def.title, fixer = def.fixer, fixerName = fixerName(def), brief = def.brief,
        goal = def.goal, value = math.floor((tonumber(e.v) or 0) * 10 + 0.5) / 10, target = def.target or 1, unit = def.unit,
        done = e.done == true, claimed = e.claimed == true, reward = C.rewards[slot] or 0,
        swappable = DAILY[slot] and not e.done and rec.swaps < (C.swapsPerDay or 1) or nil,
        needsCrew = slot == "crew" and not crewReady or nil }
end
function D.view(id)
    if not D.enabled then return { enabled = false } end
    local active, rec, wrec, identifier = activeFor(id)
    if not active then return { enabled = true, ready = false } end
    local list, crewReady = {}, #crewmates(id) > 0
    for _, slot in ipairs(SLOTS) do
        local def = active[slot]
        if def then list[#list + 1] = card(def, slot, slot == "weekly" and wrec or rec, crewReady) end
    end
    -- finished and unpaid from yesterday (or last week, on Monday)
    local older, day = {}, today()
    for back = 1, (C.claimGraceDays or 1) do
        local r = recs[identifier] and recs[identifier][dayKey(day - back)]
        for cid, e in pairs(r and r.list or {}) do
            if e.done and not e.claimed and defs[cid] then
                older[#older + 1] = { id = cid, title = defs[cid].title, reward = C.rewards[defs[cid].slot] or 0 }
            end
        end
    end
    local lastWeek = recs[identifier] and recs[identifier][weekKey(weekOf(day) - 1)]
    if lastWeek and day - weekEnd(weekOf(day) - 1) <= (C.claimGraceDays or 1) then
        for cid, e in pairs(lastWeek.list) do
            if e.done and not e.claimed and defs[cid] then older[#older + 1] = { id = cid, title = defs[cid].title, reward = C.rewards.weekly or 0 } end
        end
    end
    table.sort(older, function(a, b) return a.id < b.id end)
    local m = metaOf(identifier)
    return { enabled = true, ready = true, day = day, resetInMs = resetInMs(), weekResetInMs = weekResetInMs(),
        streak = (m.lastDay >= day - 1) and m.streak or 0, swapsLeft = math.max(0, (C.swapsPerDay or 1) - rec.swaps),
        budget = { used = rec.budget, max = C.dailyBudget }, list = list, older = older }
end
LightRP.stateProvider("dailies", D.view)

LightRP.action("dailies.claim", function(id, payload)
    local ok, text = D.claim(id, type(payload) == "table" and payload.id)
    LightRP.result(id, ok, text, "dailies.claim")
end)
LightRP.action("dailies.swap", function(id, payload)
    local ok, text = D.swap(id, type(payload) == "table" and tostring(payload.slot or "") or "")
    LightRP.result(id, ok, text, "dailies.swap")
end)
LightRP.action("dailies.open", function(id, payload)
    pushNow(id)
    if LightRP.titles and LightRP.titles.push then LightRP.titles.push(id) end
    local tab = type(payload) == "table" and payload.tab == "titles" and "titles" or "today"
    LightRP.dialog(id, "dailies", { tab = tab })
end)

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.dailies on|off|status|reroll <slot>|day <offset>|complete <player> <contract>

LightRP.command("lightrp.dailies", { restricted = true, usage = "/lightrp.dailies on|off|status|reroll <street|action|shift|crew|weekly>|day <offset>|complete <playerId> <contractId>" }, function(_, args)
    local verb = args[1]
    if verb == "on" or verb == "off" then
        D.enabled = verb == "on"
        for _, id in ipairs(players()) do push(id) end
        return true, "Contracts " .. (D.enabled and "on." or "off.")
    elseif verb == "reroll" then
        local slot = args[2]
        if not bySlot[slot] then return false end
        local day = today()
        local period = slot == "weekly" and weekOf(day) or day
        salts[slot .. period] = (salts[slot .. period] or 0) + 1
        draws[day], draws["w" .. weekOf(day)] = nil, nil
        for _, id in ipairs(players()) do push(id) end
        return true, "Redrawn: " .. slot .. "."
    elseif verb == "day" then
        dayOffset = math.floor(tonumber(args[2]) or 0)
        for _, id in ipairs(players()) do push(id) end
        return true, string.format("Simulated day offset %d (day %d, week %d).", dayOffset, today(), weekOf(today()))
    elseif verb == "complete" then
        local target, cid = tonumber(args[2]), args[3]
        if not target or not defs[cid or ""] then return false end
        local ctx = contextOf(target, cid)
        if not ctx then return false, "That contract is not open for this player today." end
        finish(ctx)
        return true, "Completed " .. cid .. " for " .. target .. "."
    elseif verb == "status" or verb == nil then
        local day = today()
        local d = dayDraw(day)
        local w = weekDraw(weekOf(day))
        return true, string.format("Contracts %s · day %d (offset %d) · street %s · action %s · crew %s · weekly %s",
            D.enabled and "on" or "off", day, dayOffset, d.street and d.street.id or "-", d.action and d.action.id or "-",
            d.crew and d.crew.id or "-", w and w.id or "-")
    end
    return false
end)

-- ---------------------------------------------------------------------------
-- The sampler and the flushes

local function snapshot(dt)
    local t = { now = now(), dt = dt, moved = {}, seats = {}, anims = {}, byVehicle = nil }
    local ok, all = pcall(Open77.players.positions)
    t.pos = ok and type(all) == "table" and all or {}
    for id, p in pairs(t.pos) do
        local last = lastPos[id]
        local moved = 0
        if last and (last.bucket or 0) == (p.bucket or 0) then
            local d = dist(last, p)
            if d <= (C.maxSpeed or 70) * dt then moved = d end
        end
        t.moved[id] = moved
        lastPos[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
    end
    function t.seatOf(id)
        local s = t.seats[id]
        if s == nil then
            local fn = Open77.vehicles and Open77.vehicles.getPlayerSeat
            local called, seat = false, nil
            if type(fn) == "function" then called, seat = pcall(fn, id) end
            s = called and type(seat) == "table" and seat.vehicleId and seat or false
            t.seats[id] = s
        end
        return s or nil
    end
    function t.animOf(id)
        local a = t.anims[id]
        if a == nil then
            local fn = Open77.animations and Open77.animations.current
            local called, cur = false, nil
            if type(fn) == "function" then called, cur = pcall(fn, id) end
            a = called and type(cur) == "table" and cur.playbackId and cur or false
            t.anims[id] = a
        end
        return a or nil
    end
    function t.occupants(vehicleId)
        if not t.byVehicle then
            t.byVehicle = {}
            for id in pairs(t.pos) do
                local seat = t.seatOf(id)
                if seat then
                    local k = tostring(seat.vehicleId)
                    t.byVehicle[k] = t.byVehicle[k] or {}
                    table.insert(t.byVehicle[k], id)
                end
            end
        end
        return t.byVehicle[tostring(vehicleId)] or {}
    end
    return t
end
D.snapshot = snapshot

function D.sample(dt)
    if not D.enabled then return end
    local t = snapshot(dt or C.sampleSeconds or 5)
    for _, id in ipairs(players()) do
        local active, rec, wrec, identifier = activeFor(id)
        if active then
            for _, slot in ipairs(SLOTS) do
                local def = active[slot]
                local fn = def and K[def.id] and K[def.id].sample
                if fn then
                    local r = slot == "weekly" and wrec or rec
                    local e = r.list[def.id]
                    if not e then e = { v = 0 }; r.list[def.id] = e end
                    if not e.done then
                        local ok, err = pcall(fn, { id = id, account = identifier, def = def, slot = slot, rec = r, entry = e,
                            scratch = scratchOf(identifier, r.key, def.id) }, t)
                        if not ok then LightRP.log("dailies: %s sample failed: %s", def.id, tostring(err)) end
                    end
                end
            end
        end
    end
end

function D.flush()
    for id in pairs(pushAt) do pushAt[id] = nil; LightRP.state(id, { "dailies" }) end
    local t = now()
    for identifier, mine in pairs(recs) do
        for _, rec in pairs(mine) do
            if rec.dirtyAt and t - rec.dirtyAt >= (C.saveSeconds or 30) * 1000 then saveRec(identifier, rec) end
        end
    end
end

-- Old periods leave memory (the database keeps them).
local function forget()
    local day = today()
    local keep = { [dayKey(day)] = true, [dayKey(day - 1)] = true, [weekKey(weekOf(day))] = true, [weekKey(weekOf(day) - 1)] = true }
    for identifier, mine in pairs(recs) do
        for key, rec in pairs(mine) do
            if not keep[key] then
                if rec.dirtyAt then saveRec(identifier, rec) end
                mine[key] = nil
                if scratch[identifier] then
                    for k in pairs(scratch[identifier]) do if k:sub(1, #key + 1) == key .. ":" then scratch[identifier][k] = nil end end
                end
            end
        end
    end
    for k in pairs(draws) do if type(k) == "number" and k < day - 2 then draws[k] = nil end end
end
D.forget = forget

CreateThread(function()
    local lastSample, lastForget, lastDay = now(), now(), today()
    while true do
        Wait(1000)
        local t = now()
        local ok, err = pcall(D.flush)
        if not ok then LightRP.log("dailies: flush failed: %s", tostring(err)) end
        if t - lastSample >= (C.sampleSeconds or 5) * 1000 then
            local dt = (t - lastSample) / 1000
            lastSample = t
            ok, err = pcall(D.sample, dt)
            if not ok then LightRP.log("dailies: sample failed: %s", tostring(err)) end
        end
        if today() ~= lastDay then
            lastDay = today()
            for _, id in ipairs(players()) do push(id) end
        end
        if t - lastForget >= 600000 then lastForget = t; pcall(forget) end
    end
end)
