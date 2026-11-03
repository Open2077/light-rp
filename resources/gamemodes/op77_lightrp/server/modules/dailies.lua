-- Daily and weekly contracts: three daily contracts (Street, Action, Shift), a
-- crew contract and a weekly one, told by the city's fixers. Content and rules:
-- docs/dailies-titles.md; numbers: server/config/dailies.lua.
--
-- Everything is checked here, server side, from hooks other modules already raise
-- (or one-line hooks added for this) and from samples of positions, seats and
-- animations the server reads itself. The page only shows the state and asks to
-- claim or swap; it never reports progress.
--
-- The player sees them as "Dailies" (F1 > Dailies, the terminal's Dailies tab):
-- "Contracts" is the mission boards' name. Ids and code keep "contracts".
--
-- Who gets what: Street, Action, Crew and the weekly come from the day's (week's)
-- draw, Shift from the job's own order. A contract that needs other players
-- (`social`) is given to a player only while enough accounts are online
-- (C.social.minAccounts), otherwise the slot's solo draw; the choice is locked in
-- the player's record, and an untouched social contract goes back to the solo one
-- if the city empties. A partner pays a social contract once a week at most.
--
-- Public:
--   LightRP.dailies.claim(playerId, contractId)  -> ok, text
--   LightRP.dailies.swap(playerId, slot)          -> ok, text
--   LightRP.dailies.active(playerId)              -> { [slot] = def }
--   LightRP.dailies.give(playerId, contractId)    -> ok, text (staff: in today's set)
--   LightRP.dailies.status(playerId)              -> text (staff)
--   LightRP.dailies.reset(playerId)               -> ok, text (staff)
--   LightRP.dailies.day() / .week()               -> current UTC day / week numbers
-- Hooks used: onMoneyChanged, onMoneySent, onItemUsed, onItemGiven, onRefuelled,
--   onFuelEmpty, onActivityResult, onMissionFinished, onWorldEventEnded,
--   onPatientStabilized, onJobWorkCompleted, onJobRunStep, onJobRunStarted,
--   onJobRunCompleted.
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
-- The fuel station's pumps (shared/config.lua fuel.stations): one station today.
local function pumps()
    local F = type(LightRpConfig) == "table" and LightRpConfig.fuel
    return F and F.enabled ~= false and type(F.stations) == "table" and F.stations or {}
end
local function pumpDistance(p)
    local best = math.huge
    for _, s in ipairs(pumps()) do
        if s.position then best = math.min(best, dist(p, s.position)) end
    end
    return best
end
D.pumpDistance = pumpDistance
local function fuelPrice()
    local F = type(LightRpConfig) == "table" and LightRpConfig.fuel
    return tonumber(F and F.pricePerLitre) or 4
end
-- The catalogue category of a vehicle (shared/config.lua vehicles.catalog: Street, Sport, Bikes...).
local function categoryOf(vehicleId)
    local ok, snap = pcall(Open77.vehicles.get, vehicleId)
    local record = ok and type(snap) == "table" and snap.record
    if not record then return nil end
    for _, entry in pairs(LightRP.vehicles and LightRP.vehicles.byKey or {}) do
        if entry.record == record then return entry.category end
    end
end
D.categoryOf = categoryOf
local function hasBikes()
    for _, entry in pairs(LightRP.vehicles and LightRP.vehicles.byKey or {}) do
        if entry.category == "Bikes" then return true end
    end
    return false
end
local function workSteps()
    local R = type(LightRpJobRuns) == "table" and LightRpJobRuns.routes and LightRpJobRuns.routes.ac_cleaner
    local n = 0
    for _, step in ipairs(R and R.steps or {}) do if step.kind == "work" then n = n + 1 end end
    return n
end
local Sources = {
    lucky_number = has("LightRP.money"),
    eat_together = has("LightRP.inventory"),
    housewarming = function()
        local H = LightRP.housing
        return LightRP.inventory ~= nil and H ~= nil and type(H.available) == "function" and H.available() == true
    end,
    running_on_fumes = has("LightRP.refueling"),
    ride_along = has("Open77.vehicles.getPlayerSeat"),
    street_performer = has("Open77.animations.current"),
    the_tour = always,
    nightcap = function() return LightRP.activities ~= nil and #bars() > 0 end,
    clean_invoice = missionPoint("chimera_raid"),
    lose_them = activity("chase.pve"),
    leg_day = activity("chase.pve"),
    five_streak = activity("arena.pve"),
    support_act = activity("arena.pve"),
    full_truck = has("LightRP.jobWork"),
    full_round = has("LightRP.jobWork"),
    two_wheels = function() return type(LightRpDelivery) == "table" and type(Open77.vehicles.get) == "function" and hasBikes() end,
    fragile = function() return type(LightRpDelivery) == "table" and type(Open77.vehicles) == "table" and type(Open77.vehicles.getHealth) == "function" end,
    water_break = function() return workSteps() >= 2 end, -- a first and a last unit
    on_call = has("LightRP.medical"),
    fare_paid = has("Open77.vehicles.getPlayerSeat"),
    roadside = has("LightRP.refueling"),
    pit_crew = function() return LightRP.refueling ~= nil and #pumps() > 0 end,
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
    one_man_army = missionPoint("chimera_raid"),
    walk_of_shame = function() return LightRP.refueling ~= nil and #pumps() > 0 end,
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
-- Who can do what right now: a social contract needs a crowd, a dispatch one
-- (Roadside) a car that actually needs help.

local social = C.social or {}
local function onlineAccounts()
    local seen, n = {}, 0
    for _, id in ipairs(players()) do
        local a = accountOf(id)
        if a and not seen[a] then seen[a] = true; n = n + 1 end
    end
    return n
end
local function crowded() return onlineAccounts() >= (tonumber(social.minAccounts) or 4) end
D.onlineAccounts, D.crowded = onlineAccounts, crowded

-- Roadside calls (fuel.lua onFuelLow / onFuelEmpty): vehicle -> { vehicle, account, driver, at, dry }.
-- A call ends when the car is refuelled (pump or can), or after `minutes`.
local calls = {}
D.calls = calls
local function liveCalls(exceptAccount)
    local t, n = now(), 0
    local ttl = ((defs.roadside and defs.roadside.minutes) or 30) * 60000
    for k, c in pairs(calls) do
        if t - c.at > ttl then calls[k] = nil
        elseif c.account ~= exceptAccount then n = n + 1 end
    end
    return n
end
local function doable(def, account)
    if not def then return false end
    if def.social and not crowded() then return false end
    if def.dispatch and liveCalls(account) == 0 then return false end
    return true
end
D.doable = doable

-- ---------------------------------------------------------------------------
-- The draws

local function candidates(list, exclude)
    local cands = {}
    for _, def in ipairs(list) do
        if available(def) and not (exclude and exclude[def.id]) then cands[#cands + 1] = def end
    end
    return cands
end
-- One contract for one player (the swap).
local function pick(list, seed, exclude)
    local cands = candidates(list, exclude)
    if #cands == 0 then return nil end
    return cands[hash(seed) % #cands + 1]
end
-- A permutation of the candidates drawn from the seed (Fisher-Yates on FNV-1a).
local function permutation(cands, seed)
    local perm = {}
    for i, def in ipairs(cands) do perm[i] = def end
    for i = #perm, 2, -1 do
        local j = hash(seed .. ":" .. i) % i + 1
        perm[i], perm[j] = perm[j], perm[i]
    end
    return perm
end
-- A slot's order: every available contract once per cycle of n periods (n = the
-- candidates), shuffled per cycle; a cycle never opens with the contract the one
-- before closed on. So a contract never comes twice in a row, and each comes back
-- within 2n - 1 periods (a Street contract at least every 13 days).
local function cycleAt(cands, name, period)
    local n = #cands
    if n == 0 then return nil end
    period = math.tointeger(period) or math.floor(period)
    if n <= 2 then return cands[period % n + 1] end
    local cycle = period // n
    local perm = permutation(cands, name .. ":" .. cycle)
    local pos = period - cycle * n + 1
    if pos <= 2 then
        local before = permutation(cands, name .. ":" .. (cycle - 1))
        if perm[1] == before[n] then perm[1], perm[2] = perm[2], perm[1] end
    end
    return perm[pos]
end
D.cycleAt = cycleAt
-- The order's contract, or after a staff reroll (salt) another one that is
-- neither the order's nor the period before's.
local function ordered(cands, name, period, salt)
    local def = cycleAt(cands, name, period)
    if (salt or 0) <= 0 or #cands < 3 then return def end
    local before = cycleAt(cands, name, period - 1)
    local others = {}
    for _, d in ipairs(cands) do if d ~= def and d ~= before then others[#others + 1] = d end end
    return others[hash(name .. ":" .. period .. ":" .. salt) % #others + 1]
end
local function drawSlot(slot, period) return ordered(candidates(bySlot[slot]), slot, period, salts[slot .. period]) end
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
-- The slot's solo order: what stands in for a social contract on a quiet server.
-- Its own cycle (every solo contract once per cycle), skipping `exclude`.
local function soloDraw(slot, period, exclude)
    local cands = {}
    for _, def in ipairs(candidates(bySlot[slot])) do if not def.social then cands[#cands + 1] = def end end
    for ahead = 0, #cands do
        local def = ordered(cands, slot .. ":solo", period + ahead, salts[slot .. period])
        if def and not (exclude and exclude[def.id]) then return def end
    end
    return nil
end
local function jobContracts(job)
    local list = {}
    for _, def in ipairs(bySlot.shift) do
        for _, j in ipairs(def.jobs or {}) do if j == job then list[#list + 1] = def break end end
    end
    return candidates(list)
end
-- Shift: the same for everyone in a job, in the job's own order. A job with one
-- contract gets it every other day; nil = a Street day (a job without contracts,
-- NCPD or none, gets one every day): activeFor hands out a solo Street contract
-- other than the player's own.
local function shiftDraw(day, job)
    local list = jobContracts(job)
    if #list == 0 then return nil end
    if #list == 1 then return day % 2 == 0 and list[1] or nil end
    return ordered(list, "shift:" .. job, day, salts["shift" .. day] or 0)
end
D.dayDraw, D.weekDraw, D.shiftDraw, D.soloDraw = dayDraw, weekDraw, shiftDraw, soloDraw

-- ---------------------------------------------------------------------------
-- Records: one per account and period ("d20395", "w2914").

-- slots: what a swap put in a slot; locks: what the player was handed (kept while it
-- stays doable, or once started); given: staff overrides (/lightrp.dailies give).
local function newRec(key) return { key = key, list = {}, swaps = 0, budget = 0, slots = {}, locks = {}, given = {}, dirtyAt = nil } end
local function recOf(identifier, key)
    local mine = recs[identifier]
    if not mine then mine = {}; recs[identifier] = mine end
    local rec = mine[key]
    if not rec then rec = newRec(key); mine[key] = rec end
    return rec
end
-- partners[contractId][account] = the ISO week that account last completed it with this one.
local function metaOf(identifier)
    local m = metas[identifier]
    if not m then m = { streak = 0, lastDay = -1, claimed = 0, counts = {}, toured = {}, partners = {} }; metas[identifier] = m end
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
    local state = { list = rec.list, swaps = rec.swaps, budget = rec.budget, slots = rec.slots, locks = rec.locks,
        given = rec.given, shiftJob = rec.shiftJob }
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
        { identifier, m.streak, m.lastDay, m.claimed, encode({ counts = m.counts, toured = m.toured, partners = m.partners }) })
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
    for _, field in ipairs({ "slots", "locks", "given" }) do
        for slot, id in pairs(type(state[field]) == "table" and state[field] or {}) do
            if defs[id] and not rec[field][slot] then rec[field][slot] = id end
        end
    end
    if type(state.shiftJob) == "string" and not rec.shiftJob then rec.shiftJob = state.shiftJob end
    -- before locks: { shift = { id, job } }
    if type(state.shift) == "table" and defs[state.shift.id] and not rec.locks.shift then
        rec.locks.shift, rec.shiftJob = state.shift.id, rec.shiftJob or state.shift.job
    end
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
        local week = weekOf(day)
        for cid, seen in pairs(type(extra.partners) == "table" and extra.partners or {}) do
            if defs[cid] and type(seen) == "table" then
                m.partners[cid] = m.partners[cid] or {}
                for account, w in pairs(seen) do
                    w = tonumber(w)
                    if w and w >= week and (m.partners[cid][account] or -1) < w then m.partners[cid][account] = w end
                end
            end
        end
    end
    loading[identifier] = nil
end

-- ---------------------------------------------------------------------------
-- What a player has today

-- { street = def, action = def, shift = def, crew = def, weekly = def }, the
-- day's record and the week's record.
-- Started: progress, a finish, a claim or a first step kept in data.
local function touched(rec, contractId)
    local e = rec.list[contractId]
    return e ~= nil and (e.done == true or e.claimed == true or (tonumber(e.v) or 0) > 0 or e.data ~= nil)
end
D.touched = touched
-- One slot of one player. A staff `give` wins; a started contract is kept; an
-- untouched one is kept while it stays doable (no flip-flop when the crowd moves
-- around the threshold), unless `urgent` (a live Roadside call) says otherwise.
-- Otherwise the slot's own contract if doable, else the solo stand-in.
local function choose(rec, slot, preferred, fallback, account, urgent)
    local given = defs[rec.given[slot] or ""]
    if given then return given end
    local locked = defs[rec.locks[slot] or ""]
    if locked and touched(rec, locked.id) then return locked end
    if locked and doable(locked, account) and not (urgent and preferred and preferred ~= locked) then return locked end
    local def = (preferred and doable(preferred, account)) and preferred or fallback
    local id = def and def.id or nil
    if id ~= rec.locks[slot] then rec.locks[slot] = id; touch(rec) end
    return def
end

-- { street = def, action = def, shift = def, crew = def, weekly = def }, the
-- day's record and the week's record.
local function activeFor(id)
    local identifier = accountOf(id)
    if not identifier then return nil end
    local day = today()
    local week = weekOf(day)
    local rec, wrec = recOf(identifier, dayKey(day)), recOf(identifier, weekKey(week))
    local shared = dayDraw(day)
    local out = {}
    for _, slot in ipairs({ "street", "action" }) do
        out[slot] = choose(rec, slot, defs[rec.slots[slot] or ""] or shared[slot], soloDraw(slot, day), identifier)
    end
    -- Shift: a job change before the shift contract is finished hands out the new job's.
    local job = jobOf(id)
    local lockedShift = rec.locks.shift
    if rec.shiftJob ~= job then
        if lockedShift and not (rec.list[lockedShift] and rec.list[lockedShift].done) and not rec.given.shift then
            rec.locks.shift, rec.slots.shift = nil, nil
        end
        rec.shiftJob = job
        touch(rec)
    end
    local list, preferred, urgent = jobContracts(job), nil, false
    for _, def in ipairs(list) do -- a live Roadside call comes first
        if def.dispatch and doable(def, identifier) then preferred, urgent = def, true break end
    end
    if not preferred then
        preferred = defs[rec.slots.shift or ""] or shiftDraw(day, job)
        if preferred and not doable(preferred, identifier) then
            local other
            for _, def in ipairs(list) do
                if def ~= preferred and not def.dispatch and doable(def, identifier) then other = def break end
            end
            preferred = other
        end
    end
    -- the stand-in: a solo Street contract the street slot can never hold today
    local exclude = {}
    for _, def in pairs({ mine = out.street, city = shared.street, solo = soloDraw("street", day) }) do exclude[def.id] = true end
    out.shift = choose(rec, "shift", preferred, soloDraw("street", day + 3, exclude), identifier, urgent)
    -- Crew: the day's, for everyone (the page shows it locked without a crewmate online).
    out.crew = defs[rec.given.crew or ""] or shared.crew
    out.weekly = choose(wrec, "weekly", weekDraw(week), soloDraw("weekly", week), identifier)
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

-- The partner rule: a social contract completed with the same other account once
-- per ISO week at most (C.social.partnerOncePerWeek).
local function freshPartner(ctx, account)
    if not account or account == ctx.account then return false end
    if social.partnerOncePerWeek == false then return true end
    local seen = metaOf(ctx.account).partners[ctx.def.id]
    return not (seen and seen[account] == weekOf(today()))
end
D.freshPartner = function(identifier, contractId, account)
    return freshPartner({ account = identifier, def = defs[contractId] or { id = contractId } }, account)
end

-- partners: the other accounts that made it happen (nil for a solo contract). The
-- first one not already used this week for this contract is recorded; none = no
-- finish, and the player is told once.
local function finish(ctx, partners)
    local e, def = ctx.entry, ctx.def
    if e.done then return true end
    if partners then
        local pick
        for _, account in ipairs(partners) do if freshPartner(ctx, account) then pick = account break end end
        if not pick then
            if not ctx.scratch.toldPartner then
                ctx.scratch.toldPartner = true
                LightRP.notice(ctx.id, { kind = "warning", title = "DAILIES", durationMs = 8000,
                    body = string.format("%s · already done with this citizen this week. It takes somebody new.", def.title) })
            end
            return false
        end
        local m = metaOf(ctx.account)
        m.partners[def.id] = m.partners[def.id] or {}
        m.partners[def.id][pick] = weekOf(today())
        saveMeta(ctx.account)
    end
    e.v, e.done = def.target or 1, true
    touch(ctx.rec)
    saveRec(ctx.account, ctx.rec)
    LightRP.notice(ctx.id, { kind = "contract", title = "DAILY COMPLETE", durationMs = 9000,
        body = string.format("%s · %s. Claim %s in F1 > Dailies.", def.title, fixerName(def), money(C.rewards[ctx.slot] or 0)) })
    LightRP.log("dailies: %s completed %s", ctx.account, def.id)
    pushNow(ctx.id)
    LightRP.eachModule("onContractCompleted", ctx.id, def.id, ctx.slot)
    return true
end
local function setValue(ctx, value, partners)
    local target = ctx.def.target or 1
    value = math.max(0, math.min(target, tonumber(value) or 0))
    if value >= target then
        if finish(ctx, partners) then return end
        value = target - 0.1 -- a used partner: the bar waits at the end for somebody new
    end
    if math.floor(value) ~= math.floor(tonumber(ctx.entry.v) or 0) then push(ctx.id) end
    if value ~= ctx.entry.v then ctx.entry.v = value; touch(ctx.rec) end
end
local function addValue(ctx, delta, partners)
    if not delta or delta <= 0 then return end
    setValue(ctx, (tonumber(ctx.entry.v) or 0) + delta, partners)
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
-- Eating or drinking, from what the player does (shared/consumables.lua consumeAction:
-- a bottle or a can is a drink, a meal or a snack is food), not from the stats: a soda
-- feeds a little and an apple waters a little. No action: the bigger of the two stats.
local DRINKS, MEALS = { bottle = true, can = true }, { meal = true, snack = true }
local function consumeKind(name)
    local t = type(LightRpItems) == "table" and LightRpItems[name]
    local use = t and t.use
    if not use then return nil end
    if t.consumeAction then return (DRINKS[t.consumeAction] and "drink") or (MEALS[t.consumeAction] and "meal") or nil end
    local food, drink = tonumber(use.food) or 0, tonumber(use.drink) or 0
    if drink > food then return "drink" elseif food > 0 then return "meal" end
    return nil
end
D.consumeKind = consumeKind

local function statsOf(raw) return type(raw) == "table" and type(raw.stats) == "table" and raw.stats or {} end
local function won(r, raw) return (type(r) == "table" and r.won == true) or (type(raw) == "table" and raw.won == true) end

-- economy.lua onMoneyChanged: the kinds that only move the player's own money do not count.
K.lucky_number = { money = function(ctx, wallet, delta, balance, kind)
    if wallet ~= "bank" or (tonumber(delta) or 0) == 0 then return end
    for _, k in ipairs(ctx.def.ignoreKinds or {}) do if k == kind then return end end
    local n = math.floor(tonumber(balance) or -1)
    if n >= 0 and n % 1000 == 777 then finish(ctx) end
end }

-- refueling.lua onRefuelled: kind "vehicle" is the pump.
K.running_on_fumes = { refuel = function(ctx, info)
    if info.kind ~= "vehicle" or not info.capacity or info.capacity <= 0 then return end
    if info.before / info.capacity < ctx.def.below and (info.before + info.litres) / info.capacity >= ctx.def.upTo then finish(ctx) end
end }

-- A jerrycan ("pour") into a car on a live call (fuel.lua onFuelLow / onFuelEmpty) that is not yours.
K.roadside = { refuel = function(ctx, info)
    if info.kind ~= "pour" then return end
    local c = calls[tostring(info.vehicle)]
    if c and c.account ~= ctx.account and now() - c.at <= ctx.def.minutes * 60000 then finish(ctx, { c.account }) end
end }

-- The car's last driver (the sampler) stands within range while the mechanic fills it
-- at the pump, then pays at least litres x the pump price. "While": every sample of the
-- fill (refueling.lua's duration: litres / litresPerSecond, at least minimumFillMs) had
-- them within range, and so does the end of it.
local lastDriver = {} -- vehicle -> { id, account, at }
local function fillMs(litres)
    local F = type(LightRpConfig) == "table" and LightRpConfig.fuel or {}
    return math.max(tonumber(F.minimumFillMs) or 5000, math.ceil(litres / (tonumber(F.litresPerSecond) or 1.2) * 1000))
end
K.pit_crew = {
    sample = function(ctx, t)
        local p, apart = t.pos[ctx.id], ctx.scratch.apart or {}
        ctx.scratch.apart = apart
        for other, q in pairs(t.pos) do
            local theirs = other ~= ctx.id and accountOf(other)
            if theirs and (not p or (q.bucket or 0) ~= (p.bucket or 0) or dist(p, q) > ctx.def.range) then apart[theirs] = now() end
        end
    end,
    refuel = function(ctx, info)
        if info.kind ~= "vehicle" or (tonumber(info.litres) or 0) <= 0 then return end
        local d = lastDriver[tostring(info.vehicle)]
        if not d or d.account == ctx.account or accountOf(d.id) ~= d.account then return end
        local me, them = positionOf(ctx.id), positionOf(d.id)
        if not me or not them or (me.bucket or 0) ~= (them.bucket or 0) or dist(me, them) > ctx.def.range then return end
        local away = ctx.scratch.apart and ctx.scratch.apart[d.account]
        if away and away > now() - fillMs(info.litres) then return end
        ctx.scratch.owed = ctx.scratch.owed or {}
        ctx.scratch.owed[d.id] = { at = now(), account = d.account, amount = math.ceil(info.litres * fuelPrice()) }
        push(ctx.id)
    end,
    moneyReceived = function(ctx, from, amount)
        local o = ctx.scratch.owed and ctx.scratch.owed[from]
        if o and accountOf(from) == o.account and now() - o.at <= ctx.def.windowSeconds * 1000 and (tonumber(amount) or 0) >= o.amount then
            if finish(ctx, { o.account }) then ctx.scratch.owed = nil end
        end
    end,
}

-- Your own car ran dry far from the pump (step 1), then your jerrycan brings it back (step 2).
K.walk_of_shame = {
    dry = function(ctx, vehicle, p)
        if not p or (p.bucket or 0) ~= 0 or pumpDistance(p) < ctx.def.minMetres then return end
        ctx.entry.data = { vehicle = vehicle }
        setValue(ctx, 1)
        saveRec(ctx.account, ctx.rec)
    end,
    refuel = function(ctx, info)
        local d = ctx.entry.data
        if info.kind == "pour" and type(d) == "table" and d.vehicle == tostring(info.vehicle) then finish(ctx) end
    end,
}

-- NCPD Escape (op77_chase) against the game's own NCPD: those cops live in each runner's
-- game and the server never sees them lost, so an escape is the extraction or the clock.
-- A run whose game refused the police (policeBlocked) or the bot police never counts.
local function realNcpd(s) return s.police == "ncpd" and not s.policeBlocked end
D.realNcpd = realNcpd
-- An escape that counts. The extraction opens 40 s after GO on Standard (op77_chase
-- shared/config.lua extractionAtSeconds) and lies 450 m away at the nearest by car, so a
-- real extraction can land before activity pay's 60 s floor: unpaid (too_short), it still
-- counts here. The clock always runs past the floor.
local function escaped(s, verdict)
    if not realNcpd(s) or s.outcome ~= "escaped" then return false end
    return verdict.eligible or (verdict.kind == "too_short" and s.how == "extraction")
end
D.escaped = escaped

-- stats.stars = the most stars the runner had (they only climb): 3+ at the extraction
-- is the Standard ceiling held to the end, or any Hard / Critical extraction.
K.lose_them = { activity = function(ctx, entry, _, raw, verdict)
    local s = statsOf(raw)
    if entry.activity == "chase.pve" and escaped(s, verdict) and s.how == "extraction"
        and (tonumber(s.stars) or 0) >= (ctx.def.minStars or 3) then finish(ctx) end
end }

-- stats.mode is the match's mode, "vehicle" or "foot" (op77_chase pve.lua resultFor).
K.leg_day = { activity = function(ctx, entry, _, raw, verdict)
    local s = statsOf(raw)
    if entry.activity == "chase.pve" and escaped(s, verdict) and s.mode == "foot" then finish(ctx) end
end }

K.five_streak = { activity = function(ctx, entry, _, raw, verdict)
    local s = statsOf(raw)
    if entry.activity == "arena.pve" and verdict.eligible and (tonumber(s.bestStreak) or 0) >= ctx.def.streak then finish(ctx) end
end }

-- An assist (op77_arena scoring.lua): 30 % of a bot's health from you, the kill from
-- somebody else (a crewmate or an allied bot from the Activities panel).
K.support_act = { activity = function(ctx, entry, r, raw, verdict)
    local s = statsOf(raw)
    local assists, kills = tonumber(s.assists) or 0, tonumber(s.kills) or 0
    if entry.activity == "arena.pve" and verdict.eligible and won(r, raw) and assists >= 1 and assists > kills then finish(ctx) end
end }

-- Any paid win (activity_pay.lua), then a drink at a bar (onItemUsed) before the clock runs out.
-- A win against something: PvE, or PvP with another player in it. A solo time trial
-- "wins" by finishing (op77_race engine.lua sendResult), and that is not a win.
local function beatSomebody(r, raw, verdict)
    if not won(r, raw) then return false end
    if verdict.kind == "pve" then return true end
    local detail = type(verdict.detail) == "table" and verdict.detail or {}
    return (tonumber(detail.players) or 0) >= 2
end
K.nightcap = {
    activity = function(ctx, _, r, raw, verdict)
        if verdict.eligible and beatSomebody(r, raw, verdict) then ctx.scratch.wonAt = now(); push(ctx.id) end
    end,
    consume = function(ctx, _, _, bar, kind)
        local at = ctx.scratch.wonAt
        if kind == "drink" and at and now() - at <= ctx.def.minutes * 60000 and bar then finish(ctx) end
    end,
}

K.all_the_way = { activity = function(ctx, entry, r, raw, verdict)
    local s = statsOf(raw)
    local roundsWon, lost = tonumber(s.roundsWon) or 0, tonumber(s.roundsLost) or 0
    if entry.activity == "arena.duel" and verdict.eligible and won(r, raw) and lost >= 1 and lost == roundsWon - 1 then finish(ctx) end
end }

K.both_sides = { activity = function(ctx, entry, _, raw, verdict)
    local s = statsOf(raw)
    if entry.activity == "chase.wanted" and verdict.eligible and (tonumber(s.arrests) or 0) >= 1
        and ((tonumber(s.extractions) or 0) >= 1 or (tonumber(s.survivals) or 0) >= 1) then finish(ctx) end
end }

-- mission_chimera.lua onEnd: inst.report = { enraged, downs, operators } (operators: at the fight's start).
local function chimera(point) return point and point.id == "chimera_raid" end
local function report(inst) return type(inst.report) == "table" and inst.report or {} end
K.clean_invoice = { mission = function(ctx, inst, point, _, success)
    if success and not inst.test and chimera(point) and tonumber(report(inst).downs) == 0 then finish(ctx) end
end }
K.one_man_army = { mission = function(ctx, inst, point, _, success)
    if success and not inst.test and chimera(point) and tonumber(report(inst).operators) == 1 and #(inst.members or {}) == 1 then finish(ctx) end
end }
K.two_vs_machine = { mission = function(ctx, inst, point, d, success)
    if not (success and not inst.test and chimera(point) and d and d.id == "hard" and tonumber(report(inst).operators) == 2
        and #(inst.members or {}) == 2) then return end
    local other
    for _, member in ipairs(inst.members) do
        local theirs = accountOf(member)
        if theirs and theirs ~= ctx.account then other = theirs end
    end
    if other then finish(ctx, { other }) end
end }

-- medical.lua onPatientStabilized: the patient is a downed player.
-- Never a crewmate (the owner's call, 2026-11-03): a real emergency, as for Good Samaritan.
K.on_call = { stabilize = function(ctx, patient)
    local theirs = accountOf(patient)
    if not theirs or theirs == ctx.account or jobOf(ctx.id) ~= "trauma" then return end
    for _, mate in ipairs(crewmates(ctx.id)) do if mate == patient then return end end
    finish(ctx, { theirs })
end }
-- three different accounts in the week, never a crewmate: the partner rule is built in
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
-- Both collection sites, then the buyer, with no sale in between (the sites are kept
-- in the entry: a reconnect does not lose the round). Progress: one step per site.
K.full_round = { work = function(ctx, job, kind, info)
    local wanted = ctx.def.points[job]
    if not wanted or type(info) ~= "table" or info.practice then return end
    local e = ctx.entry
    if kind == "collect" then
        local mine = false
        for _, p in ipairs(wanted) do if p == info.point then mine = true end end
        if not mine then return end
        e.data = type(e.data) == "table" and e.data or {}
        if e.data[info.point] then return end
        e.data[info.point] = true
        local n = 0
        for _, p in ipairs(wanted) do if e.data[p] then n = n + 1 end end
        setValue(ctx, n)
        saveRec(ctx.account, ctx.rec)
    elseif kind == "sell" then
        local all = type(e.data) == "table"
        for _, p in ipairs(wanted) do all = all and e.data[p] == true end
        if all then return finish(ctx) end
        if e.data then e.data = nil; setValue(ctx, 0); saveRec(ctx.account, ctx.rec) end
    end
end }
-- A courier run (job_runs.lua) where every driving sample is a Bikes-category vehicle
-- (shared/config.lua vehicles.catalog). On foot between the stops is fine.
local function drives(id, seat)
    if seat.seat == "seat_front_left" then return true end
    local ok, driver = pcall(Open77.vehicles.getDriver, seat.vehicleId)
    return ok and driver == id
end
K.two_wheels = {
    runStart = function(ctx, run)
        if run.job ~= "delivery" then return end
        local s = ctx.scratch
        s.run, s.bike, s.car = run.id, nil, nil
    end,
    sample = function(ctx, t)
        local s = ctx.scratch
        if not s.run then return end
        local seat = t.seatOf(ctx.id)
        if not seat or not drives(ctx.id, seat) then return end
        if categoryOf(seat.vehicleId) == "Bikes" then s.bike = true else s.car = true end
    end,
    runDone = function(ctx, run)
        local s = ctx.scratch
        if s.run ~= run.id then return end
        s.run = nil
        if s.bike and not s.car then finish(ctx) end
    end,
}
-- The AC route (server/config/job_runs.lua): a drink (onItemUsed) after the first work
-- step is done and before the last one is (both on the roof), then the route finished.
local function workIndexes(run)
    local first, last
    for i, step in ipairs(run.route and run.route.steps or {}) do
        if step.kind == "work" then first = first or i; last = i end
    end
    return first, last
end
K.water_break = {
    runStart = function(ctx, run)
        if run.job ~= "ac_cleaner" then return end
        local s = ctx.scratch
        s.run, s.open, s.drank = run.id, false, false
    end,
    runStep = function(ctx, run)
        local s = ctx.scratch
        if s.run ~= run.id then return end
        local first, last = workIndexes(run)
        if run.index == first then s.open = true elseif run.index == last then s.open = false end
    end,
    consume = function(ctx, _, _, _, kind)
        local s = ctx.scratch
        if s.run and s.open and kind == "drink" then s.drank = true; push(ctx.id) end
    end,
    runDone = function(ctx, run)
        local s = ctx.scratch
        if s.run ~= run.id then return end
        s.run = nil
        if s.drank then finish(ctx) end
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
        if not seat or not drives(ctx.id, seat) then return end
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
    local partners = {}
    for _, other in ipairs(t.occupants(seat.vehicleId)) do
        local theirs = other ~= ctx.id and accountOf(other)
        if theirs and freshPartner(ctx, theirs) then partners[#partners + 1] = theirs end
    end
    if #partners > 0 then addValue(ctx, t.moved[ctx.id], partners) end
end }
K.street_performer = { sample = function(ctx, t)
    local s, p, a = ctx.scratch, t.pos[ctx.id], t.animOf(ctx.id)
    local audience = {}
    if a and atHub(p) then
        for other, q in pairs(t.pos) do
            local theirs = other ~= ctx.id and accountOf(other)
            if theirs and freshPartner(ctx, theirs) and (q.bucket or 0) == 0 and dist(p, q) <= ctx.def.audience then audience[#audience + 1] = theirs end
        end
    end
    if #audience == 0 then
        if s.playback then s.playback = nil; setValue(ctx, 0) end
        return
    end
    if s.playback ~= a.playbackId then s.playback = a.playbackId; setValue(ctx, 0); return end
    addValue(ctx, t.dt, audience)
end }
-- A newcomer: a character still in its first `graceMinutes` of play, the window the
-- city itself treats as new (economy.lua: free hospital and fitting room).
local function newcomerMinutes()
    local E = type(LightRpEconomy) == "table" and LightRpEconomy.hospital
    return tonumber(E and E.graceMinutes) or 120
end
local function playedMinutes(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if not c then return math.huge end
    local ms = (tonumber(c.playtimeMs) or 0) + math.max(0, now() - (tonumber(c.joinedAtMs) or now()))
    return ms / 60000
end
K.the_tour = { sample = function(ctx, t)
    local p = t.pos[ctx.id]
    if not p or (t.moved[ctx.id] or 0) <= 0 then return end
    local m = metaOf(ctx.account)
    for other, q in pairs(t.pos) do
        local theirs = other ~= ctx.id and accountOf(other)
        if theirs and freshPartner(ctx, theirs) and not m.toured[theirs] and (q.bucket or 0) == (p.bucket or 0)
            and dist(p, q) <= ctx.def.range and (t.moved[other] or 0) > 0.5 and playedMinutes(other) < newcomerMinutes() then
            ctx.scratch.newcomers = ctx.scratch.newcomers or {}
            ctx.scratch.newcomers[theirs] = other
            addValue(ctx, t.moved[ctx.id], { theirs })
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
-- Housewarming: the key holder hands a drink (inventory.lua onItemGiven) to a guest in
-- the same home; the guest drinking THAT item (onItemUsed) there completes it. The
-- gift is dropped when the guest leaves the home (checked by the sampler).
local gifts = {} -- guest player id -> { { host, hostAccount, item, property } }
D.gifts = gifts
local function homeOf(id)
    local H = LightRP.housing
    local s = H and H.sessions and H.sessions[id]
    if not s or s.preview or not s.property then return nil end
    return s
end
local function holdsKey(id, s)
    local H, S = LightRP.housing, LightRP.housingStore
    local lease = S and S.contracts and S.contracts[s.contract]
    return lease ~= nil and type(H.hasKey) == "function" and H.hasKey(id, lease) == true
end
K.housewarming = { sample = function(ctx)
    for guest, list in pairs(gifts) do
        local gs = homeOf(guest)
        for i = #list, 1, -1 do
            if list[i].host == ctx.id and (not gs or gs.property ~= list[i].property) then table.remove(list, i) end
        end
        if #list == 0 then gifts[guest] = nil end
    end
end }
K.convoy = { sample = function(ctx, t)
    local seat, p, s = t.seatOf(ctx.id), t.pos[ctx.id], ctx.scratch
    local partners = {}
    if seat and seat.seat == "seat_front_left" and p then
        for _, mate in ipairs(crewmates(ctx.id)) do
            local theirs, q = t.seatOf(mate), t.pos[mate]
            if theirs and theirs.seat == "seat_front_left" and theirs.vehicleId ~= seat.vehicleId and q and dist(p, q) <= ctx.def.range
                and freshPartner(ctx, accountOf(mate)) then partners[#partners + 1] = accountOf(mate) end
        end
    end
    if #partners > 0 then s.miss = nil; return addValue(ctx, t.moved[ctx.id], partners) end
    -- one missed sample is forgiven (a corner, a red light); two start over
    if (tonumber(ctx.entry.v) or 0) > 0 then
        if s.miss then s.miss = nil; setValue(ctx, 0) else s.miss = true end
    end
end }
K.album_cover = { sample = function(ctx, t)
    local p, s = t.pos[ctx.id], ctx.scratch
    local posing = t.animOf(ctx.id) and atHub(p)
    local partners = {}
    if posing then
        for _, mate in ipairs(crewmates(ctx.id)) do
            local q = t.pos[mate]
            if q and dist(p, q) <= ctx.def.range then
                if not t.animOf(mate) then partners = {} break end -- somebody in the frame is not posing
                partners[#partners + 1] = accountOf(mate)
            end
        end
    end
    local fresh = false
    for _, a in ipairs(partners) do fresh = fresh or freshPartner(ctx, a) end
    if not fresh then s.since = nil; return end
    s.since = s.since or t.now
    if t.now - s.since >= ctx.def.seconds * 1000 then finish(ctx, partners) end
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
                if theirs and freshPartner(ctx, theirs) then
                    inside[other] = true
                    s.rides[other] = (s.rides[other] or 0) + (t.moved[ctx.id] or 0)
                end
            end
        end
        for other, metres in pairs(s.rides) do
            if not inside[other] then
                if metres >= ctx.def.metres then s.owed[other] = { at = t.now, account = accountOf(other) }; push(ctx.id) end
                s.rides[other] = nil
            end
        end
    end,
    moneyReceived = function(ctx, from, amount)
        local o = ctx.scratch.owed and ctx.scratch.owed[from]
        if o and accountOf(from) == o.account and now() - o.at <= ctx.def.windowSeconds * 1000 and (tonumber(amount) or 0) >= ctx.def.fare then
            finish(ctx, { o.account })
        end
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
local function nearestBar(p, range)
    if not p or (p.bucket or 0) ~= 0 then return nil end
    local best, bestD
    for _, b in ipairs(bars()) do
        local d = dist(p, b.position)
        if d <= (range or 25) and (not bestD or d < bestD) then best, bestD = b, d end
    end
    return best
end
local function crawl(id, bar, mateAccount)
    with(id, "bar_crawl", function(ctx)
        if not freshPartner(ctx, mateAccount) then return end
        local s, t = ctx.scratch, now()
        s.visits = s.visits or {}
        s.visits[bar.id] = { at = t, district = bar.district or bar.id }
        local districts, n = {}, 0
        for barId, v in pairs(s.visits) do
            if t - v.at > ctx.def.minutes * 60000 then s.visits[barId] = nil
            elseif not districts[v.district] then districts[v.district] = true; n = n + 1 end
        end
        setValue(ctx, n, { mateAccount })
    end)
end
-- inventory.lua Inv.use (consumables.lua calls it when the animation ends).
function D.onItemUsed(id, name)
    if not D.enabled then return end
    local use, account = itemUse(name), accountOf(id)
    if not use or not account then return end
    local p = positionOf(id)
    if not p then return end
    local t, kind = now(), consumeKind(name)
    if kind == "meal" and defs.eat_together then
        local def = defs.eat_together
        prune(meals, def.windowSeconds * 1000)
        for _, m in ipairs(meals) do
            if m.account ~= account and accountOf(m.id) == m.account and (m.p.bucket or 0) == (p.bucket or 0) and dist(m.p, p) <= def.range then
                with(id, "eat_together", function(ctx) finish(ctx, { m.account }) end)
                with(m.id, "eat_together", function(ctx) finish(ctx, { account }) end)
            end
        end
        meals[#meals + 1] = { id = id, account = account, at = t, p = p }
    end
    local bar = nearestBar(p, defs.bar_crawl and defs.bar_crawl.range)
    if kind == "drink" and defs.bar_crawl and bar then
        prune(drinks, defs.bar_crawl.togetherSeconds * 1000)
        local mates = {}
        for _, mate in ipairs(crewmates(id)) do mates[mate] = true end
        for _, d in ipairs(drinks) do
            if mates[d.id] and d.bar == bar.id and accountOf(d.id) == d.account then
                crawl(d.id, bar, account)
                crawl(id, bar, d.account)
            end
        end
        drinks[#drinks + 1] = { id = id, account = account, at = t, p = p, bar = bar.id }
    end
    -- the guest drinks the host's gift in the host's home, in the same visit (housing.lua
    -- makes a new session on every entry: out and back in drops the gift)
    if kind == "drink" and gifts[id] then
        local home = homeOf(id)
        for i = #gifts[id], 1, -1 do
            local g = gifts[id][i]
            if g.item == name and home and home == g.session and home.property == g.property and accountOf(g.host) == g.hostAccount then
                table.remove(gifts[id], i)
                with(g.host, "housewarming", function(ctx) finish(ctx, { account }) end)
            end
        end
        if #gifts[id] == 0 then gifts[id] = nil end
    end
    emit(id, "consume", use, p, defs.nightcap and nearestBar(p, defs.nightcap.range), kind)
end

-- inventory.lua Inv.give: a drink handed over by a key holder to a guest in the same home.
function D.onItemGiven(from, to, name)
    if not D.enabled or type(to) ~= "number" then return end
    if consumeKind(name) ~= "drink" then return end
    local mine, theirs = homeOf(from), homeOf(to)
    if not mine or not theirs or mine.property ~= theirs.property or not holdsKey(from, mine) then return end
    with(from, "housewarming", function(ctx)
        local guest = accountOf(to)
        if not guest or not freshPartner(ctx, guest) then return end
        gifts[to] = gifts[to] or {}
        table.insert(gifts[to], { host = from, hostAccount = ctx.account, item = name, property = mine.property, session = theirs })
        push(from)
    end)
end

-- refueling.lua: kind "vehicle" (pump), "pour" (jerrycan into a car), "can" (filling a can).
-- A refuelled car is no longer a Roadside call (after Roadside had its look).
function D.onRefuelled(id, info)
    if type(info) ~= "table" then return end
    emit(id, "refuel", info)
    if (info.kind == "vehicle" or info.kind == "pour") and info.vehicle ~= nil then calls[tostring(info.vehicle)] = nil end
end
-- fuel.lua: the tank crossed its reserve (onFuelLow) or hit zero (onFuelEmpty). Either
-- opens a Roadside call; untouched mechanics on shift get it at once (activeFor).
local function call(vehicleId, driver, dry)
    local account = type(driver) == "number" and accountOf(driver)
    if not account then return end
    local key = tostring(vehicleId)
    local fresh = calls[key] == nil
    calls[key] = { vehicle = key, account = account, driver = driver, at = (calls[key] and calls[key].at) or now(), dry = dry or nil }
    if not fresh or not defs.roadside then return end
    local p = positionOf(driver)
    for _, id in ipairs(players()) do
        if id ~= driver and accountOf(id) ~= account and jobOf(id) == "mechanic" then
            local active = activeFor(id)
            if active and active.shift == defs.roadside then
                local q = positionOf(id)
                local km = p and q and (p.bucket or 0) == (q.bucket or 0) and string.format(" %.1f km from you.", dist(p, q) / 1000) or "."
                LightRP.notice(id, { kind = "message", title = fixerName(defs.roadside), durationMs = 9000,
                    body = "Roadside call: a citizen's car is " .. (dry and "dry" or "on its reserve") .. km })
                push(id)
            end
        end
    end
end
function D.onFuelLow(vehicleId, driver) call(vehicleId, driver, false) end
function D.onFuelEmpty(vehicleId, driver)
    call(vehicleId, driver, true)
    if type(driver) == "number" then emit(driver, "dry", tostring(vehicleId), positionOf(driver)) end
end

-- activity_pay.lua: verdict = { amount, kind, detail }; amount ~= nil = paid-eligible
-- (the result qualifies for pay; the day's pay cap does not void a contract). Without an
-- amount, kind is why (too_short, left, bots, repeat...).
local crewArena, crewChase = {}, {} -- crew id -> recent results
-- The instance a result came from: providers report before they release the player
-- (activities.lua), so the routing bucket is still the match's (as activity_pay's roster).
local function bucketOf(id)
    if type(GetPlayerRoutingBucket) == "function" then
        local ok, b = pcall(GetPlayerRoutingBucket, id)
        if ok and tonumber(b) then return tonumber(b) end
    end
    local p = positionOf(id)
    return p and tonumber(p.bucket) or 0
end
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
    -- ranked or PvE only: activities.lua never forwards an unranked result (a
    -- friendly, a bot match or fill, staff testing); this guard keeps it that way
    if entry.ranked == false or (type(raw) == "table" and (raw.unranked == true or raw.test == true)) or (type(r) == "table" and r.unranked == true) then return end
    verdict = type(verdict) == "table" and verdict or {}
    verdict.eligible = verdict.amount ~= nil
    raw = type(raw) == "table" and raw or {}
    emit(id, "activity", entry, r or {}, raw, verdict)
    local s, account = type(raw.stats) == "table" and raw.stats or {}, accountOf(id)
    if not account then return end
    -- the crew's results of the SAME match: the same instance (routing bucket), entered
    -- together (activities.lua enteredAt). Two matches started side by side are two runs.
    local function sameRun(list, mine, seconds)
        local run = {}
        for _, x in ipairs(list or {}) do
            if x.bucket == mine.bucket and (not x.entered or not mine.entered or math.abs(x.entered - mine.entered) <= seconds * 1000) then
                run[#run + 1] = x
            end
        end
        return run
    end
    local function others(run, me)
        local list = {}
        for _, x in ipairs(run) do if x.account ~= me then list[#list + 1] = x.account end end
        return list
    end
    if entry.activity == "arena.pve" and won(r, raw) and verdict.eligible and (tonumber(s.kills) or 0) >= 1 and defs.back_to_back then
        local def = defs.back_to_back
        local mine = { id = id, account = account, entered = tonumber(entry.enteredAt), bucket = bucketOf(id) }
        local run = sameRun(crewResult(crewArena, id, mine, def.windowSeconds * 1000), mine, def.sameRunSeconds)
        if #run >= 2 then
            for _, x in ipairs(run) do with(x.id, "back_to_back", function(ctx) finish(ctx, others(run, x.account)) end) end
        end
    end
    -- crews = "together" (op77_chase): the crew shares one instance, each member's result
    -- comes when HIS round ends, and stats.runners is how many of them started. The last
    -- one decides; a crewmate who dropped sends no result, so nobody is paid.
    if entry.activity == "chase.pve" and s.crew and defs.nobody_left_behind then
        local def = defs.nobody_left_behind
        local mine = { id = id, account = account, escaped = escaped(s, verdict),
            entered = tonumber(entry.enteredAt), bucket = bucketOf(id) }
        local run = sameRun(crewResult(crewChase, id, mine, def.windowSeconds * 1000), mine, def.sameRunSeconds)
        if #run >= math.max(2, math.floor(tonumber(s.runners) or 0)) then
            local all = true
            for _, x in ipairs(run) do all = all and x.escaped end
            if all then
                for _, x in ipairs(run) do with(x.id, "nobody_left_behind", function(ctx) finish(ctx, others(run, x.account)) end) end
            end
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
function D.onJobRunStep(id, run, step) if type(run) == "table" then emit(id, "runStep", run, step) end end
function D.onJobRunCompleted(id, run) if type(run) == "table" then emit(id, "runDone", run) end end
-- jobs.lua: a new job hands out its own Shift contract (activeFor); show it.
function D.onJobChanged(id) push(id) end

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
    if not D.enabled then return false, "Dailies are paused right now." end
    local identifier = accountOf(id)
    if not identifier then return false, "Load your character first." end
    if busy[identifier] then return false, "Your last claim is still being paid." end
    local def, rec, e = findClaimable(identifier, tostring(contractId or ""))
    if not def then return false, "Unknown daily." end
    if not rec then return false, "This daily is not finished yet, or it was already paid." end
    local reward = math.floor(tonumber(C.rewards[def.slot]) or 0)
    if reward <= 0 then return false, "This daily pays nothing." end
    if def.slot ~= "weekly" and rec.budget + reward > (C.dailyBudget or math.huge) then
        return false, string.format("Dailies budget reached (%s per day). It resets at 00:00 UTC.", money(C.dailyBudget))
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
    if not D.enabled then return false, "Dailies are paused right now." end
    if not DAILY[slot] then return false, "Only Street, Action and Shift dailies can be swapped." end
    local active, rec, _, identifier = activeFor(id)
    if not active then return false, "Load your character first." end
    if rec.given[slot] then return false, "Staff set this daily for a test: it cannot be swapped." end
    if rec.swaps >= (C.swapsPerDay or 1) then return false, "You already used today's free swap." end
    local current = active[slot]
    local e = current and rec.list[current.id]
    if e and e.done then return false, "This daily is finished: claim it instead." end
    -- never a contract already in the set, nor one that cannot be done right now
    local exclude = {}
    for _, s in ipairs(SLOTS) do if active[s] then exclude[active[s].id] = true end end
    local function addPool(pool, list) for _, def in ipairs(list) do if doable(def, identifier) then pool[#pool + 1] = def end end end
    local pool = {}
    if slot == "shift" then
        local mine = jobContracts(jobOf(id))
        addPool(pool, mine)
        if (current and current.slot == "street") or #pool <= 1 then addPool(pool, bySlot.street) end
    else
        addPool(pool, bySlot[slot])
    end
    local def = pick(pool, "swap:" .. identifier .. ":" .. slot .. ":" .. today(), exclude)
    if not def then return false, "There is no other daily to offer today." end
    if current then rec.list[current.id] = nil end
    rec.slots[slot], rec.locks[slot] = def.id, def.id
    rec.swaps = rec.swaps + 1
    saveRec(identifier, rec)
    pushNow(id)
    return true, string.format("New daily: %s.", def.title)
end

-- ---------------------------------------------------------------------------
-- The page state ("dailies"): about 80 values.

-- crewLocked: the Crew card without a crewmate online and nothing started: the page
-- shows a locked placeholder (form a crew) instead of a contract nobody can do.
local function card(def, slot, rec, crewReady)
    local e = rec.list[def.id] or {}
    local crewLocked = slot == "crew" and not crewReady and not touched(rec, def.id)
    return { slot = slot, id = def.id, title = def.title, fixer = def.fixer, fixerName = fixerName(def), brief = def.brief,
        goal = def.goal, value = math.floor((tonumber(e.v) or 0) * 10 + 0.5) / 10, target = def.target or 1, unit = def.unit,
        done = e.done == true, claimed = e.claimed == true, reward = C.rewards[slot] or 0,
        swappable = DAILY[slot] and not e.done and rec.swaps < (C.swapsPerDay or 1) and not rec.given[slot] or nil,
        needsCrew = slot == "crew" and not crewReady or nil, crewLocked = crewLocked or nil,
        social = (def.social or slot == "crew") or nil }
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
-- The activities terminal's Dailies tab: the same state, no dialog of its own.
LightRP.action("dailies.refresh", function(id) pushNow(id) end)

-- ---------------------------------------------------------------------------
-- Staff tools

-- Put a contract in a player's set today (or this week): its slot, progress from zero.
-- Overrides the draw, the job, the crowd and the Roadside call (the checks still apply).
function D.give(id, contractId)
    local def = defs[tostring(contractId or "")]
    if not def then return false, "Unknown daily: " .. tostring(contractId) .. "." end
    local active, rec, wrec, identifier = activeFor(id)
    if not active then return false, "That player has no active character." end
    local r = def.slot == "weekly" and wrec or rec
    local current = active[def.slot]
    if current and current.id ~= def.id and r.list[current.id] and not r.list[current.id].done then r.list[current.id] = nil end
    r.given[def.slot] = def.id
    r.list[def.id] = { v = 0 }
    if scratch[identifier] then scratch[identifier][r.key .. ":" .. def.id] = nil end
    saveRec(identifier, r)
    pushNow(id)
    return true, string.format("Gave %s (%s) to %s.", def.id, def.slot, tostring(id))
end
function D.status(id)
    local active, rec, wrec, identifier = activeFor(id)
    if not active then return "No active character for " .. tostring(id) .. "." end
    local parts = { string.format("%s (%s) · day %d · %d accounts online%s", tostring(id), identifier, today(), onlineAccounts(),
        crowded() and " (social on)" or " (social off)") }
    for _, slot in ipairs(SLOTS) do
        local def = active[slot]
        if def then
            local r = slot == "weekly" and wrec or rec
            local e = r.list[def.id] or {}
            parts[#parts + 1] = string.format("%s=%s %s/%s%s%s%s", slot, def.id, string.format("%g", math.floor((tonumber(e.v) or 0) * 10 + 0.5) / 10),
                tostring(def.target or 1), e.done and " done" or "", e.claimed and " claimed" or "", r.given[slot] and " (given)" or "")
        end
    end
    parts[#parts + 1] = string.format("swaps %d · budget %d/%s · calls %d", rec.swaps, rec.budget, tostring(C.dailyBudget), liveCalls(identifier))
    return table.concat(parts, " · ")
end
-- Today's and this week's records, the session scratch and the partner weeks; the
-- streak, claim counts and titles stay (they are history).
function D.reset(id)
    local identifier = accountOf(id)
    if not identifier then return false, "That player has no active character." end
    local day = today()
    local keys = { dayKey(day), weekKey(weekOf(day)) }
    for _, key in ipairs(keys) do
        if recs[identifier] then recs[identifier][key] = nil end
    end
    scratch[identifier] = nil
    local m = metaOf(identifier)
    m.partners = {}
    saveMeta(identifier)
    if Db.ready then
        Db.run("DELETE FROM lightrp_dailies WHERE identifier = ? AND period IN (?, ?)", { identifier, keys[1], keys[2] })
    end
    for guest, list in pairs(gifts) do
        for i = #list, 1, -1 do if list[i].host == id then table.remove(list, i) end end
        if #list == 0 then gifts[guest] = nil end
    end
    pushNow(id)
    return true, "Reset today's and this week's dailies for " .. tostring(id) .. "."
end

-- /lightrp.dailies on|off|status [player]|give <player> <contract>|reset <player>|
--   reroll <slot>|day <offset>|complete <player> <contract>
LightRP.command("lightrp.dailies", { restricted = true, usage = "/lightrp.dailies on|off|status [playerId]|give <playerId> <contractId>|reset <playerId>|reroll <street|action|shift|crew|weekly>|day <offset>|complete <playerId> <contractId>" }, function(_, args)
    local verb = args[1]
    if verb == "on" or verb == "off" then
        D.enabled = verb == "on"
        for _, id in ipairs(players()) do push(id) end
        return true, "Dailies " .. (D.enabled and "on." or "off.")
    elseif verb == "give" then
        local target = tonumber(args[2])
        if not target then return false end
        return D.give(target, args[3])
    elseif verb == "reset" then
        local target = tonumber(args[2])
        if not target then return false end
        return D.reset(target)
    elseif verb == "status" and tonumber(args[2]) then
        return true, D.status(tonumber(args[2]))
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
        if not ctx then return false, "That daily is not open for this player today." end
        finish(ctx)
        return true, "Completed " .. cid .. " for " .. target .. "."
    elseif verb == "status" or verb == nil then
        local day = today()
        local d = dayDraw(day)
        local w = weekDraw(weekOf(day))
        return true, string.format("Dailies %s · day %d (offset %d) · street %s · action %s · crew %s · weekly %s · %d accounts online",
            D.enabled and "on" or "off", day, dayOffset, d.street and d.street.id or "-", d.action and d.action.id or "-",
            d.crew and d.crew.id or "-", w and w.id or "-", onlineAccounts())
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
    -- who drove what last (Pit Crew's customer), kept 30 minutes
    if defs.pit_crew then
        for id in pairs(t.pos) do
            local seat = t.seatOf(id)
            local account = seat and seat.seat == "seat_front_left" and accountOf(id)
            if account then lastDriver[tostring(seat.vehicleId)] = { id = id, account = account, at = t.now } end
        end
        for k, d in pairs(lastDriver) do if t.now - d.at > 1800000 then lastDriver[k] = nil end end
    end
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
