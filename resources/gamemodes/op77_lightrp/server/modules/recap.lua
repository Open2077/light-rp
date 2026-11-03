-- End-of-match recap (owner request 2026-11-03): when a PvP or PvE activity, a mission
-- or a world boss ends, each player gets a complete screen of the match once back in
-- the city -- who played (bots marked), the sides, kills, deaths, assists, damage dealt
-- and taken, DPS, headshots, placements, the mode's own lines, the MVP and what the
-- match paid them. F1 > Last match (action recap.open, /recap) shows it again.
--
-- Sources
--   activities  op77_lightrp:activity:result: activities.lua forwards every accepted
--               result here, bot-mode and `test` ones included (shown as TEST, no
--               rewards): placement / won / score / `stats`, and the optional
--               `result.recap` = the whole match (RECAP below, bots included). A
--               provider may also send the final scoreboard alone, host-wide:
--                 provider -> core  op77_lightrp:activity:recap (activityId, recap)
--   missions    missions.lua finish(): the crew, the mission engine's run (objectives,
--               waves, hostiles down, team respawns), the raid's Chimera hits.
--   world boss  world_bosses.lua finish(): each contributor's damage, boss damage,
--               kills, share and pay.
--   the core    what the platform reports server side, for players only, counted per
--               player and session (an activity entry, a mission instance, a world
--               boss event): open77:playerDamaged (damage dealt to players, damage
--               taken, headshot hits), onNpcDamaged / onNpcDied with the validated
--               "player:<id>" source (damage to NPCs, NPC kills), the life phases
--               (deaths). A provider's own number always wins over the core's.
--   rewards     reported by the modules that pay, as they pay (R.reward): activities.lua
--               record() (reputation granted), activity_pay.lua (eddies, or why none),
--               missions.lua with mission_pay.lua (payout, reputation), world_bosses.lua
--               (pay, reputation). Tier: missions.lua tierInfo. Hall of Fame: the rank on
--               each board of halloffame.lua's cache, before (session start) and after
--               (the cache is rebuilt once for the recap when older than the result,
--               never faster than its floor); only a rank that moved is shown.
--
-- RECAP (provider table, every field optional)
--   { matchId = "arena:3:12",   -- the same for every participant of one match
--     durationMs, detail = "Round 3",
--     sides = { { id = 1, label = "Players", score = 9 } }, winnerSide = 1,
--     rows = { { id = 12 (player) | -3 (bot), name, bot, side, kills, deaths, assists,
--                damage, damageTaken, headshots, score, placement, inMatchMs, timeMs,
--                bestLapMs, checkpoints, roundsWon, busts, escapes, points, captures,
--                holdS, share, bossShare, outcome, left } },
--     lines = { { label = "Rounds", value = "2 - 1" } }, columns = { "kills", ... }, mvp = <row id> }
--
-- DPS = damage dealt / seconds the participant spent in the match (from its entry, or
-- the round's start, to the end or its departure): a row's `inMatchMs`, else the match's
-- duration. Not time alive, not time spent shooting.
--
-- When it shows: the player is free again (no activity or mission owns them, not on
-- the way back), alive, not downed, out of every activity bucket, for 2 s, and the
-- rewards were reported (6 s at most). A world boss's recap waits 4 s after its end.
-- The client (client/core/recap.lua) then waits for no loading screen, a living body,
-- no creator, no other dialog. The latest match replaces the previous one (an arena's
-- drop-in rounds: the last round played). Memory only: a reload or a disconnect forgets.
local E = LightRpEvents
local R = LightRP.module("recap", {})

local CONFIG = {
    stableMs = 2000,         -- back and settled this long before the screen opens
    rewardWaitMs = 6000,     -- at most this long for the paying modules' reports
    homeWaitMs = 40000,      -- a mission's operators: at most this long for missions.lua's "back home"
    deliverTimeoutMs = 180000, -- never back in time: kept for F1 only
    worldBossDelayMs = 4000,
    matchTtlMs = 20 * 60000,
    sessionTtlMs = 30 * 60000,
    maxRows = 32,
    plainValues = 900,       -- the client drops a plain event over 1024 values (framework.lua)
    latentRate = 256 * 1024,
}
R.config = CONFIG

local COLUMNS = { "placement", "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "bossShare",
    "share", "captures", "holdS", "roundsWon", "busts", "escapes", "points", "timeMs", "bestLapMs", "checkpoints", "score" }
local NUMERIC = { placement = 1000, kills = 100000, deaths = 100000, assists = 100000, damage = 1e9, damageTaken = 1e9,
    headshots = 100000, score = 1e9, inMatchMs = 86400000, timeMs = 86400000, bestLapMs = 86400000, checkpoints = 100000,
    roundsWon = 1000, busts = 1000, escapes = 1000, points = 1e9, captures = 100000, holdS = 86400, share = 100,
    bossShare = 100, bossDamage = 1e9 }
local DECIMALS = { share = 10, bossShare = 10 }
local OUTCOMES = { escaped = true, busted = true, caught = true, dnf = true, left = true, finished = true, out = true,
    down = true, cop = true, runner = true, won = true, lost = true }
local DEATH_PHASES = { dead = true, dying = true, respawnpending = true, revivepending = true }
local LEFT = { left = true, dropped = true, disconnect = true, quit = true } -- a race's dnfReason of a leaver (activity_pay.lua)

local sessions = {} -- key -> { [playerId] = counters }
local current = {}  -- playerId -> session key
local matches = {}  -- match key -> match
local pending = {}  -- playerId -> { key, at, readySince, notBefore }
local last = {}     -- playerId -> payload already delivered (F1)
local latest = {}   -- playerId -> { [activityId] = match key } (rewards reported by activity)
local before = {}   -- playerId -> { at, tier, hof } snapshot at a session start
local downed = {}   -- playerId -> true between a fall and the next life
local soloSeq = 0
R.sessions, R.matches, R.pending, R.last = sessions, matches, pending, last

local function now() return LightRP.nowMs() end
local function pid(value)
    value = tonumber(value)
    if value and value >= 1 and value % 1 == 0 then return math.floor(value) end
    return nil
end
local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end
local function clamp(value, lo, hi)
    value = finite(value)
    if value == nil then return nil end
    return math.max(lo, math.min(hi, value))
end
local function round(value, scale) scale = scale or 1; return math.floor(value * scale + 0.5) / scale end
local function clean(value, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 0 then return nil end
    if #value > max then
        local cut = max
        while cut > 0 do
            local b = value:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        value = value:sub(1, cut)
    end
    return value
end
local function displayName(id)
    local C = LightRP.characters
    if C and type(C.displayName) == "function" then
        local ok, name = pcall(C.displayName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "Citizen " .. tostring(id)
end
local function bucketOf(id)
    if type(GetPlayerRoutingBucket) == "function" then return tonumber(GetPlayerRoutingBucket(id)) or 0 end
    local p = Open77.players.position(id)
    return p and tonumber(p.bucket) or 0
end
local function lifePhase(id)
    local ok, life = pcall(Open77.players.getLifeState, id)
    return ok and type(life) == "table" and life.phase or nil
end
local function online(id)
    if type(GetPlayerName) ~= "function" then return true end
    return GetPlayerName(id) ~= nil
end

-- ---------------------------------------------------------------------------
-- Snapshots before a match: the tier and the Hall of Fame ranks

local function tierOf(id)
    local M = LightRP.missions
    if M and type(M.tierInfo) == "function" then
        local ok, info = pcall(M.tierInfo, id)
        if ok and type(info) == "table" then return info end
    end
    return nil
end
local function standing(id)
    local H = LightRP.hallOfFame
    if H and type(H.standing) == "function" then
        local ok, list = pcall(H.standing, id)
        if ok and type(list) == "table" then return list end
    end
    return nil
end
local function snapshot(id)
    local t = tierOf(id)
    before[id] = { at = now(), tier = t and t.tier or nil, hof = standing(id) }
end
R.snapshot = snapshot

-- ---------------------------------------------------------------------------
-- Sessions: what the core counts itself, per player

local function sessionKey(id)
    local A = LightRP.activities
    local e = A and type(A.current) == "function" and A.current(id) or nil
    if e and e.token then return "activity:" .. tostring(e.token), "activity" end
    local M = LightRP.missions
    local inst = M and type(M.instanceOf) == "function" and M.instanceOf(id) or nil
    if inst and inst.id then return "mission|" .. tostring(inst.id), "mission", inst end
    local W = LightRP.worldBosses
    local ev = W and type(W.current) == "function" and W.current() or nil
    if ev and ev.phase == "fight" and type(ev.inZone) == "table" and ev.inZone[id] then return "worldboss|" .. tostring(ev.id), "worldboss" end
    return nil
end

local function counters(key, id)
    local list = sessions[key]
    if not list then list = {}; sessions[key] = list end
    local c = list[id]
    if not c then
        c = { damage = 0, damageTaken = 0, headshots = 0, kills = 0, deaths = 0, bossDamage = 0, startedAt = now(), touchedAt = now() }
        list[id] = c
        if current[id] ~= key then
            current[id] = key
            -- a session that starts here (a mission, a world boss) gets its "before"
            if not key:match("^activity:") then snapshot(id) end
        end
    end
    c.touchedAt = now()
    return c
end
-- The counters of a player's running session, created on demand; nil outside any.
local function live(id)
    id = pid(id)
    if not id then return nil end
    local key = sessionKey(id)
    if not key then return nil end
    return counters(key, id), key
end
R.live = live

-- A module credits a session counter itself (the raid's Chimera hits: bossDamage).
function R.credit(id, field, amount)
    local c = live(id)
    amount = finite(amount)
    if not c or not amount or amount <= 0 or c[field] == nil then return false end
    c[field] = c[field] + math.min(amount, 100000)
    return true
end

local function npcPlayer(source)
    return pid(tostring(source or ""):match("^player:(%d+)$"))
end

AddEventHandler("open77:playerDamaged", function(victim, attacker, amount, _, weapon, bodyPart)
    amount = finite(amount)
    if not amount or amount <= 0 then return end
    amount = math.min(amount, 100000)
    if type(weapon) == "string" and weapon:sub(1, 8) == "lightrp:" then return end -- hunger, a placement
    local v = live(victim)
    if v then v.damageTaken = v.damageTaken + amount end
    local a = pid(attacker)
    if a and a ~= pid(victim) then
        local c = live(a)
        if c then
            c.damage = c.damage + amount
            if tostring(bodyPart) == "head" then c.headshots = c.headshots + 1 end
        end
    end
end)
AddEventHandler("onNpcDamaged", function(_, source, amount)
    local id = npcPlayer(source)
    amount = finite(amount)
    if not id or not amount or amount <= 0 then return end
    local c = live(id)
    if c then c.damage = c.damage + math.min(amount, 100000) end
end)
AddEventHandler("onNpcDied", function(_, killer)
    local id = npcPlayer(killer)
    local c = id and live(id)
    if c then c.kills = c.kills + 1 end
end)
-- One death per fall: the phases after it (respawnpending...) are the same one.
function R.onLifeState(id, phase)
    id = pid(id)
    if not id then return end
    if DEATH_PHASES[phase] then
        if downed[id] then return end
        downed[id] = true
        local c = live(id)
        if c then c.deaths = c.deaths + 1 end
    elseif phase == "alive" then
        downed[id] = nil
    end
end

-- ---------------------------------------------------------------------------
-- The ledger: one match, every participant

local function sanitizeRow(raw, index)
    if type(raw) ~= "table" then return nil end
    local id = finite(raw.id)
    if id == nil or id == 0 then id = -(1000 + index) end
    id = math.floor(id)
    local row = { id = id, name = clean(raw.name, 32), bot = raw.bot == true or id < 0 or nil, side = clamp(raw.side, 0, 8),
        left = raw.left == true or nil, outcome = type(raw.outcome) == "string" and OUTCOMES[raw.outcome:lower()] and raw.outcome:lower() or nil }
    if row.side then row.side = math.floor(row.side); if row.side == 0 then row.side = nil end end
    for key, hi in pairs(NUMERIC) do
        local value = clamp(raw[key], 0, hi)
        if value ~= nil then row[key] = DECIMALS[key] and round(value, DECIMALS[key]) or math.floor(value + 0.5) end
    end
    if raw.dnf == true and not row.outcome then row.outcome = "dnf" end
    return row
end

local function newMatch(key, fields)
    local m = { key = key, rows = {}, order = {}, players = {}, lines = {}, createdAt = now(), updatedAt = now() }
    for k, v in pairs(fields or {}) do m[k] = v end
    matches[key] = m
    return m
end

local function mergeRow(m, row)
    local old = m.rows[row.id]
    if not old then
        m.rows[row.id] = row
        m.order[#m.order + 1] = row.id
        return row
    end
    for k, v in pairs(row) do
        -- a later snapshot of the same match: the newer value, never a name lost
        if v ~= nil then old[k] = v end
    end
    return old
end

local function sanitizeLines(list)
    local out = {}
    for _, line in ipairs(type(list) == "table" and list or {}) do
        if #out >= 8 then break end
        local label = type(line) == "table" and clean(line.label, 32)
        local value = type(line) == "table" and (clean(type(line.value) == "number" and tostring(line.value) or line.value, 64))
        if label and value then out[#out + 1] = { label = label, value = value } end
    end
    return out
end

-- A provider's RECAP into the match.
local function mergeRecap(m, recap)
    if type(recap) ~= "table" then return end
    local duration = clamp(recap.durationMs, 0, 86400000)
    if duration then m.durationMs = math.floor(duration) end
    m.detail = clean(recap.detail, 64) or m.detail
    if type(recap.sides) == "table" then
        local sides = {}
        for _, s in ipairs(recap.sides) do
            local id = type(s) == "table" and clamp(s.id, 1, 8)
            if id and #sides < 8 then
                sides[#sides + 1] = { id = math.floor(id), label = clean(s.label, 32) or ("Side " .. math.floor(id)), score = clamp(s.score, -1e9, 1e9) }
            end
        end
        if #sides > 0 then m.sides = sides end
    end
    local winner = clamp(recap.winnerSide, 0, 8)
    if winner then m.winnerSide = math.floor(winner) end
    if type(recap.lines) == "table" then
        local lines = sanitizeLines(recap.lines)
        if #lines > 0 then m.lines = lines end
    end
    if type(recap.columns) == "table" then
        local allowed, cols = {}, {}
        for _, c in ipairs(COLUMNS) do allowed[c] = true end
        for _, c in ipairs(recap.columns) do if allowed[c] and #cols < 9 then cols[#cols + 1] = c end end
        if #cols > 0 then m.columns = cols end
    end
    if finite(recap.mvp) then m.mvp = math.floor(finite(recap.mvp)) end
    if type(recap.rows) == "table" then
        for i, raw in ipairs(recap.rows) do
            if i > 64 then break end
            local row = sanitizeRow(raw, i)
            if row then mergeRow(m, row) end
        end
    end
    m.updatedAt = now()
end

-- The core's own counters fill what a provider left out of a player's row.
local function fillFromCounters(row, c)
    if not c then return end
    if row.damage == nil and c.damage > 0 then row.damage = math.floor(c.damage + 0.5) end
    if row.damageTaken == nil and c.damageTaken > 0 then row.damageTaken = math.floor(c.damageTaken + 0.5) end
    if row.headshots == nil and c.headshots > 0 then row.headshots = c.headshots end
    if row.kills == nil and c.kills > 0 then row.kills = c.kills end
    if row.deaths == nil and c.deaths > 0 then row.deaths = c.deaths end
end
local function resetCounters(c)
    if not c then return end
    c.damage, c.damageTaken, c.headshots, c.kills, c.deaths, c.bossDamage = 0, 0, 0, 0, 0, 0
    c.startedAt = now()
end

local function pend(id, key, notBefore)
    if not online(id) then return end
    pending[id] = { key = key, at = now(), notBefore = notBefore }
end

-- ---------------------------------------------------------------------------
-- Activities (activities.lua A.result, after its own checks)

local function activityInfo(activityId)
    local A = LightRP.activities
    local a = A and A.registry and A.registry[activityId]
    local label = a and a.label or (A and type(A.labelOf) == "function" and A.labelOf(activityId)) or tostring(activityId)
    return a, label
end

function R.activityResult(playerId, e, raw, r, test)
    local id = pid(playerId)
    if not id or type(e) ~= "table" or type(raw) ~= "table" then return false end
    r = type(r) == "table" and r or {}
    local stats = type(raw.stats) == "table" and raw.stats or {}
    local recap = type(raw.recap) == "table" and raw.recap or nil
    local a, label = activityInfo(e.activity)
    local matchId = recap and (type(recap.matchId) == "string" or type(recap.matchId) == "number") and tostring(recap.matchId)
        or ((type(stats.matchId) == "string" or type(stats.matchId) == "number") and tostring(stats.matchId)) or nil
    if not matchId then soloSeq = soloSeq + 1; matchId = "solo:" .. id .. ":" .. soloSeq end
    local key = tostring(e.activity) .. "|" .. matchId:sub(1, 64)
    local m = matches[key] or newMatch(key, { source = "activity", activityId = e.activity, label = label,
        modeKind = a and (a.pve and "pve" or a.kind) or "event", difficulty = e.difficulty, startedAt = e.enteredAt })
    mergeRecap(m, recap)
    -- the player's own row: the provider's, else built from the result's stats
    local own = sanitizeRow(stats, 0) or {}
    own.id, own.name, own.bot = id, (m.rows[id] and m.rows[id].name) or (e.identity and e.identity.name) or displayName(id), nil
    own.placement = own.placement or r.placement
    own.score = own.score or (finite(r.score) and r.score >= 0 and math.floor(r.score + 0.5)) or nil
    local quit = stats.quit == true or stats.forfeit == true or LEFT[stats.dnfReason] == true
    if quit then own.left = true end
    if own.holdS == nil and finite(stats.holdSeconds) then own.holdS = math.floor(clamp(stats.holdSeconds, 0, 86400) + 0.5) end
    if own.inMatchMs == nil then own.inMatchMs = clamp(stats.durationMs, 0, 86400000) or clamp(stats.timeMs, 0, 86400000) end
    if own.inMatchMs then own.inMatchMs = math.floor(own.inMatchMs) end
    local row = m.rows[id]
    if row then
        for k, v in pairs(own) do if row[k] == nil then row[k] = v end end
    else
        row = mergeRow(m, own)
    end
    local c = sessions["activity:" .. tostring(e.token)] and sessions["activity:" .. tostring(e.token)][id] or nil
    fillFromCounters(row, c)
    if not m.durationMs and own.inMatchMs then m.durationMs = own.inMatchMs end
    resetCounters(c)
    local info = { resultAt = now(), placement = r.placement, won = r.won == true, score = r.score,
        quit = quit, outcome = row.outcome, finished = stats.finished,
        test = test == true, unranked = raw.unranked == true or raw.ranked == false, difficulty = r.played or e.difficulty,
        rewards = {}, expect = {} }
    if not info.test then
        info.expect.reputation = true
        local Pay = LightRP.activityPay
        if Pay and type(Pay.onResult) == "function" then info.expect.eddies = true end
    end
    m.players[id] = info
    m.endedAt = now()
    latest[id] = latest[id] or {}
    latest[id][e.activity] = key
    pend(id, key)
    return true, key
end

-- The final scoreboard of a match, sent alone by its provider.
function R.activityRecap(activityId, recap)
    if type(activityId) ~= "string" or type(recap) ~= "table" then return false end
    local a = activityInfo(activityId)
    if not a then return false end
    -- a provider sends its own activities' scoreboards only (when the host names the caller)
    local by = type(GetInvokingResource) == "function" and GetInvokingResource() or nil
    if by and by ~= "" and by ~= a.resource and by ~= (type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "") then return false end
    local matchId = (type(recap.matchId) == "string" or type(recap.matchId) == "number") and tostring(recap.matchId) or nil
    if not matchId then return false end
    local m = matches[activityId .. "|" .. matchId:sub(1, 64)]
    if not m then return false end
    mergeRecap(m, recap)
    return true
end
AddEventHandler("op77_lightrp:activity:recap", function(activityId, recap)
    local ok, err = pcall(R.activityRecap, activityId, recap)
    if not ok then LightRP.log("recap: activity recap failed: %s", tostring(err)) end
end)

-- What a paying module granted (or why it did not). `where` is a match key, or an
-- activity id (the player's latest result there).
--   fields: reputation, reputationAsked, eddies, eddiesReason, eddiesNote
function R.reward(playerId, where, fields)
    local id = pid(playerId)
    if not id or type(fields) ~= "table" then return false end
    local key = where
    if latest[id] and latest[id][where] then key = latest[id][where] end
    local m = matches[key]
    local info = m and m.players[id]
    if not info then return false end
    local rw = info.rewards
    if fields.reputation ~= nil then
        rw.reputation = (rw.reputation or 0) + math.max(0, math.floor(finite(fields.reputation) or 0))
        rw.reputationAsked = math.max(rw.reputationAsked or 0, math.floor(finite(fields.reputationAsked) or 0))
        info.expect.reputation = nil
    end
    if fields.eddies ~= nil or fields.eddiesReason ~= nil then
        rw.eddies = (rw.eddies or 0) + math.max(0, math.floor(finite(fields.eddies) or 0))
        rw.eddiesReason = type(fields.eddiesReason) == "string" and fields.eddiesReason:sub(1, 24) or rw.eddiesReason
        rw.eddiesNote = clean(fields.eddiesNote, 96) or rw.eddiesNote
        info.expect.eddies = nil
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Missions (missions.lua finish, before the operators go home)

local function sessionRows(m, key, members)
    local list = sessions[key] or {}
    local seen = {}
    for _, id in ipairs(members) do seen[id] = true end
    local ids = {}
    for id in pairs(list) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not seen[id] then
            local row = mergeRow(m, { id = id, name = displayName(id), left = true })
            fillFromCounters(row, list[id])
        end
    end
end

local function shareRows(m, field, out)
    local total = 0
    for _, id in ipairs(m.order) do total = total + (m.rows[id][field] or 0) end
    if total <= 0 then return end
    for _, id in ipairs(m.order) do
        local row = m.rows[id]
        if (row[field] or 0) > 0 then row[out] = round(row[field] / total * 100, 10) end
    end
end

function R.missionEnded(inst, success, why, point, d)
    if type(inst) ~= "table" or not inst.id then return nil end
    point, d = type(point) == "table" and point or {}, type(d) == "table" and d or {}
    local key = "mission|" .. tostring(inst.id)
    local raid = point.type == "RAID"
    local label = clean(point.title, 48) or "Mission"
    local m = newMatch(key, { source = "mission", label = label, modeKind = raid and "raid" or "mission",
        detail = table.concat((function()
            local parts = {}
            if inst.gig then parts[#parts + 1] = "Gig" .. (inst.gig.fixerName and (" · " .. tostring(inst.gig.fixerName)) or "") end
            if point.type then parts[#parts + 1] = tostring(point.type) end
            if d.label then parts[#parts + 1] = tostring(d.label) end
            return parts
        end)(), " · "),
        startedAt = inst.startedAt, endedAt = now(), success = success == true, why = clean(why, 96), test = inst.test == true })
    m.durationMs = math.max(0, now() - (tonumber(inst.startedAt) or now()))
    local list = sessions[key] or {}
    local members = {}
    for i, id in ipairs(inst.members or {}) do members[i] = id end
    for _, id in ipairs(members) do
        local row = mergeRow(m, { id = id, name = displayName(id) })
        local c = list[id]
        fillFromCounters(row, c)
        if c and c.bossDamage > 0 then row.bossDamage = c.bossDamage end -- priced hits, fractions of the bar
        if c then row.inMatchMs = math.max(0, now() - math.min(c.startedAt, tonumber(inst.startedAt) or c.startedAt)) end
    end
    sessionRows(m, key, members)
    if raid then shareRows(m, "bossDamage", "bossShare") end
    -- the run's own lines (mission_engine.lua): objectives, waves, hostiles, respawns
    local run = inst.run
    local lines = {}
    if type(run) == "table" and type(run.def) == "table" then
        if type(run.def.waves) == "table" and #run.def.waves > 0 and run.def.type == "waves" then
            lines[#lines + 1] = { label = "Waves", value = string.format("%d / %d", math.min(run.waveIndex or 0, #run.def.waves), #run.def.waves) }
        end
        if type(run.def.checkpoints) == "table" and #run.def.checkpoints > 0 then
            local reached = 0
            for _, cp in ipairs(run.def.checkpoints) do if run.reached and run.reached[cp.id] then reached = reached + 1 end end
            lines[#lines + 1] = { label = "Objectives", value = string.format("%d / %d", reached, #run.def.checkpoints) }
        end
        if tonumber(run.kills) then lines[#lines + 1] = { label = "Hostiles down", value = tostring(math.floor(run.kills)) } end
        if type(run.def.respawn) == "table" and tonumber(run.def.respawn.lives) and run.def.respawn.lives > 0 then
            lines[#lines + 1] = { label = "Team respawns left", value = string.format("%d / %d", math.max(0, run.lives or 0), run.def.respawn.lives) }
        end
    end
    lines[#lines + 1] = { label = "Crew", value = string.format("%d operator%s", #members, #members == 1 and "" or "s") }
    if not success and m.why then lines[#lines + 1] = { label = "Outcome", value = m.why } end
    m.lines = sanitizeLines(lines)
    for _, id in ipairs(members) do
        -- missions.lua pays and grants right after this call: the tier and ranks before it
        snapshot(id)
        -- away until missions.lua brought them back (R.home), the rewards in the same pass
        m.players[id] = { resultAt = now(), won = success == true, outcome = success and "complete" or "failed",
            test = inst.test == true, rewards = {}, expect = {}, difficulty = d.id, away = true }
        pend(id, key)
    end
    sessions[key] = nil
    for _, id in ipairs(members) do if current[id] == key then current[id] = nil end end
    return key
end

-- missions.lua: the operator stands back in the city (teleport done, or respawned there).
function R.home(playerId)
    local id = pid(playerId)
    local p = id and pending[id]
    local m = p and matches[p.key]
    local info = m and m.players[id]
    if info then info.away = nil end
    return info ~= nil
end

-- ---------------------------------------------------------------------------
-- World bosses (world_bosses.lua finish)

function R.worldBossEnded(ev, success, why, reputation)
    if type(ev) ~= "table" or not ev.id or type(ev.def) ~= "table" then return nil end
    local key = "worldboss|" .. tostring(ev.id)
    local m = newMatch(key, { source = "worldboss", label = clean(ev.def.title, 48) or "World boss", modeKind = "worldboss",
        detail = table.concat({ tostring(ev.bossLabel or "The boss"), tostring(ev.location or "Night City") }, " · "),
        startedAt = ev.startedAt, endedAt = now(), success = success == true, why = clean(why, 96) })
    m.durationMs = math.max(0, now() - (tonumber(ev.startedAt) or now()))
    local list = sessions[key] or {}
    local ids, seen = {}, {}
    for id in pairs(ev.contrib or {}) do if pid(id) then ids[#ids + 1] = id; seen[id] = true end end
    for id in pairs(list) do if not seen[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    local bossTotal = 0
    for _, c in pairs(ev.contrib or {}) do bossTotal = bossTotal + (tonumber(c.bossDamage) or 0) end
    for _, id in ipairs(ids) do
        local c = (ev.contrib or {})[id]
        local result = ev.results and ev.results[id]
        local row = { id = id, name = (c and clean(c.name, 32)) or displayName(id) }
        if c then
            row.damage = math.floor((tonumber(c.damage) or 0) + 0.5)
            row.kills = tonumber(c.kills) or 0
            row.share = round(tonumber(c.share) or 0, 10)
            if bossTotal > 0 and (tonumber(c.bossDamage) or 0) > 0 then row.bossShare = round(c.bossDamage / bossTotal * 100, 10) end
            row.inMatchMs = math.max(1000, now() - (tonumber(c.firstAt) or tonumber(ev.startedAt) or now()))
        end
        row = mergeRow(m, row)
        local s = list[id]
        if s then
            if s.damageTaken > 0 then row.damageTaken = math.floor(s.damageTaken + 0.5) end
            if s.deaths > 0 then row.deaths = s.deaths end
            if not c then fillFromCounters(row, s); row.inMatchMs = math.max(1000, now() - s.startedAt) end
        end
        m.players[id] = { resultAt = now(), won = success == true and (result and result.eligible == true) or false,
            outcome = success and "down" or "escaped", eligible = result and result.eligible == true, rewards = {}, expect = {} }
        if result then
            local pay = math.max(0, math.floor(tonumber(result.pay) or 0))
            m.players[id].rewards.eddies = pay
            if pay > 0 then m.players[id].rewards.reputation = math.max(0, math.floor(tonumber(reputation) or 0))
            elseif success then m.players[id].rewards.eddiesReason = "share" end
        end
        pend(id, key, now() + CONFIG.worldBossDelayMs)
    end
    local fighters = 0
    for _, c in pairs(ev.contrib or {}) do if (tonumber(c.score) or 0) > 0 then fighters = fighters + 1 end end
    local lines = {}
    for _, l in ipairs({ { label = "Boss", value = tostring(ev.bossLabel or "The boss") }, { label = "Fighters", value = tostring(fighters) },
        ev.need and { label = "Share needed", value = string.format("%.1f %%", ev.need) } or false,
        (not success and m.why) and { label = "Outcome", value = m.why } or false }) do
        if l then lines[#lines + 1] = l end
    end
    m.lines = sanitizeLines(lines)
    sessions[key] = nil
    for _, id in ipairs(ids) do if current[id] == key then current[id] = nil end end
    return key
end

-- ---------------------------------------------------------------------------
-- The payload (one viewer)

local function dpsOf(row, m)
    if not row.damage or row.damage <= 0 then return nil end
    local ms = row.inMatchMs or m.durationMs
    if not ms or ms < 1000 then ms = 1000 end
    return round(row.damage / (ms / 1000), 10)
end

-- Rows in display order: placement, then score, kills, damage; the viewer kept when cut.
local function orderedRows(m, viewer)
    local list = {}
    for _, id in ipairs(m.order) do list[#list + 1] = m.rows[id] end
    table.sort(list, function(x, y)
        local px, py = x.placement or math.huge, y.placement or math.huge
        if px ~= py then return px < py end
        if (x.score or 0) ~= (y.score or 0) then return (x.score or 0) > (y.score or 0) end
        if (x.kills or 0) ~= (y.kills or 0) then return (x.kills or 0) > (y.kills or 0) end
        if (x.share or 0) ~= (y.share or 0) then return (x.share or 0) > (y.share or 0) end
        if (x.damage or 0) ~= (y.damage or 0) then return (x.damage or 0) > (y.damage or 0) end
        return x.id > y.id -- players (positive) before bots, stable
    end)
    if #list > CONFIG.maxRows then
        local keep, present, mine = {}, false, nil
        for i, row in ipairs(list) do
            if row.id == viewer then mine = row; if i <= CONFIG.maxRows then present = true end end
            if i <= CONFIG.maxRows then keep[i] = row end
        end
        if mine and not present then keep[CONFIG.maxRows] = mine end
        list = keep
    end
    return list
end

-- The MVP: the provider's, else the best player (never a bot) by the mode's measure.
local function mvpOf(m, rows)
    if m.mvp then
        for _, row in ipairs(rows) do if row.id == m.mvp then return row.id, "provider" end end
    end
    local best, by
    local function better(x, y, field, low)
        local a, b = x[field], y[field]
        if a == nil then return false end
        if b == nil then return true end
        if low then return a < b end
        return a > b
    end
    local measures = { { "share" }, { "score" }, { "placement", true }, { "kills" }, { "damage" } }
    for _, measure in ipairs(measures) do
        local field, low = measure[1], measure[2]
        local any = false
        for _, row in ipairs(rows) do if not row.bot and row[field] ~= nil and (low or row[field] > 0) then any = true end end
        if any then
            for _, row in ipairs(rows) do
                if not row.bot and row[field] ~= nil and (low or row[field] > 0) then
                    if not best or better(row, best, field, low)
                        or (row[field] == best[field] and ((row.damage or 0) > (best.damage or 0) or ((row.damage or 0) == (best.damage or 0) and (row.kills or 0) > (best.kills or 0)))) then
                        best = row
                    end
                end
            end
            by = field
            break
        end
    end
    return best and best.id or nil, by
end

local function columnsOf(m, rows)
    if m.columns then return m.columns end
    local present = {}
    for _, row in ipairs(rows) do
        for _, c in ipairs(COLUMNS) do if row[c] ~= nil and (row[c] ~= 0 or c == "kills" or c == "deaths") then present[c] = true end end
    end
    -- kills without deaths (or the reverse) still shows both
    if present.kills or present.deaths then present.kills, present.deaths = true, true end
    if present.damage then present.dps = true end
    local out = {}
    for _, c in ipairs(COLUMNS) do if present[c] then out[#out + 1] = c end end
    return out
end

local function resultOf(m, info, row, rows)
    if m.source == "mission" then
        if m.success then return { label = "COMPLETE", tone = "win" } end
        return { label = "FAILED", tone = "loss" }
    end
    if m.source == "worldboss" then
        if not m.success then return { label = "ESCAPED", tone = "loss" } end
        return { label = "BOSS DOWN", tone = info.eligible and "win" or "neutral" }
    end
    if info.quit then return { label = "LEFT", tone = "loss" } end
    local outcome = row and row.outcome
    if outcome == "dnf" then return { label = "DNF", tone = "loss" } end
    if outcome == "escaped" then return { label = "ESCAPED", tone = "win" } end
    if outcome == "busted" or outcome == "caught" then return { label = "BUSTED", tone = "loss" } end
    local players = 0 -- every placed row, the ones cut from the board too
    for _, rid in ipairs(m.order) do if m.rows[rid].placement then players = players + 1 end end
    if m.sides and #m.sides >= 2 then
        if info.won then return { label = "WIN", tone = "win" } end
        if m.winnerSide == 0 or info.placement == 1 then return { label = "DRAW", tone = "neutral" } end
        return { label = "LOSS", tone = "loss" }
    end
    if info.won then return { label = "WIN", tone = "win", placement = info.placement, of = players > 1 and players or nil } end
    if info.placement and players > 2 then return { label = "#" .. info.placement, tone = info.placement <= 3 and "neutral" or "loss", placement = info.placement, of = players } end
    if info.placement == 1 and players <= 1 then return { label = "FINISHED", tone = "win" } end
    if info.placement then return { label = "LOSS", tone = "loss", placement = info.placement, of = players > 1 and players or nil } end
    return { label = "DONE", tone = "neutral" }
end

local function hofChanges(id, snap, after)
    if type(snap) ~= "table" or type(after) ~= "table" then return nil end
    local out = {}
    local keys = {}
    for key in pairs(after) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local now2, old = after[key], snap[key]
        if type(now2) == "table" and now2.rank and (not old or old.rank ~= now2.rank) then
            out[#out + 1] = { board = clean(now2.title, 32) or key, before = old and old.rank or nil, rank = now2.rank }
        end
    end
    -- the best moves first, at most two
    table.sort(out, function(x, y)
        local dx = (x.before or 9999) - x.rank
        local dy = (y.before or 9999) - y.rank
        if dx ~= dy then return dx > dy end
        return x.board < y.board
    end)
    while #out > 2 do table.remove(out) end
    return #out > 0 and out or nil
end

function R.payload(m, id, extras)
    local info = m.players[id] or { rewards = {}, expect = {} }
    extras = extras or {}
    local rows = orderedRows(m, id)
    local mineRow
    for _, row in ipairs(rows) do if row.id == id then mineRow = row end end
    local mvp, mvpBy = mvpOf(m, rows)
    local outRows = {}
    for i, row in ipairs(rows) do
        local o = {}
        for k, v in pairs(row) do
            if k ~= "inMatchMs" and k ~= "bossDamage" and v ~= false and v ~= 0 then o[k] = v end
        end
        o.id = row.id
        if row.kills == 0 then o.kills = nil end
        o.dps = dpsOf(row, m)
        outRows[i] = o
    end
    local test = info.test == true or m.test == true
    local rewards = { test = test or nil }
    if not test then
        local rw = info.rewards
        rewards.eddies, rewards.eddiesReason, rewards.eddiesNote = rw.eddies, rw.eddiesReason, rw.eddiesNote
        rewards.reputation = rw.reputation
        if (rw.reputation or 0) == 0 and (rw.reputationAsked or 0) > 0 then rewards.reputationCapped = true end
        if extras.tier then rewards.tier = extras.tier end
        if extras.hof then rewards.hof = extras.hof end
    end
    local payload = {
        kind = "recap", id = m.key, source = m.source, mode = m.label, modeKind = m.modeKind,
        detail = m.detail ~= "" and m.detail or nil, durationMs = m.durationMs,
        result = resultOf(m, info, mineRow, rows),
        test = test or nil, unranked = info.unranked or nil,
        you = id, columns = columnsOf(m, rows), sides = m.sides, winnerSide = m.winnerSide,
        rows = outRows, total = #m.order, lines = #m.lines > 0 and m.lines or nil,
        mvp = mvp and { id = mvp, by = mvpBy } or nil, rewards = rewards,
    }
    return payload
end

-- ---------------------------------------------------------------------------
-- Delivery

local function send(id, payload)
    local fits, values = LightRP.stateFitsPlainEvent(payload)
    if fits then
        TriggerClientEvent(E.net.recap, id, payload)
        return true, values, "plain"
    end
    if type(TriggerLatentClientEvent) == "function" then
        local stream, why = TriggerLatentClientEvent(E.net.recap, id, CONFIG.latentRate, payload)
        if not stream then LightRP.log("recap: %s for player %d not sent (%s)", tostring(payload.id), id, tostring(why)) return false end
        return true, values, "latent"
    end
    LightRP.log("recap: %s for player %d too large for one event (%d values)", tostring(payload.id), id, values or -1)
    return false
end
R.send = send

-- Free (no activity or mission owns them, not on the way back), alive, out of every
-- activity bucket (the return point may be an interior's bucket, not 0).
local function ready(id)
    local A = LightRP.activities
    if A and type(A.owns) == "function" and A.owns(id) then return false end
    if lifePhase(id) ~= "alive" then return false end
    if A and type(A.ownsBucket) == "function" and A.ownsBucket(bucketOf(id)) then return false end
    local M = LightRP.medical
    if M and type(M.isDowned) == "function" and M.isDowned(id) then return false end
    local C = LightRP.characters
    local c = C and type(C.get) == "function" and C.get(id)
    if not c or c.status ~= "active" or (C.switching or {})[id] then return false end
    return true
end
R.ready = ready

local function settled(info) return next(info.expect or {}) == nil end

local function extrasFor(id, m)
    local extras = {}
    local snap = before[id]
    local t = tierOf(id)
    if t then
        extras.tier = { tier = t.tier, name = t.name, points = t.points, next = t.next, nextName = t.nextName,
            up = (snap and snap.tier and t.tier > snap.tier) or nil }
    end
    local H = LightRP.hallOfFame
    if H and snap and snap.hof and type(H.refreshSince) == "function" then
        local info = m.players[id]
        pcall(H.refreshSince, info and info.resultAt or now())
        extras.hof = hofChanges(id, snap.hof, standing(id))
    end
    return extras
end

local delivering = {}
function R.deliver(id)
    local p = pending[id]
    if not p or delivering[id] then return false end
    local m = matches[p.key]
    pending[id] = nil
    if not m then return false end
    delivering[id] = true
    local ok, err = pcall(function()
        local payload = R.payload(m, id, extrasFor(id, m))
        last[id] = payload
        if online(id) then
            local sent, values, how = send(id, payload)
            if sent then LightRP.log("recap: %s to player %d (%d rows, %s values, %s)", m.key, id, #payload.rows, tostring(values), tostring(how)) end
            LightRP.state(id, "recap")
        end
        -- the next match starts a new "before"
        snapshot(id)
    end)
    delivering[id] = nil
    if not ok then LightRP.log("recap: delivery to %d failed: %s", id, tostring(err)) end
    return ok
end

function R.tick(t)
    t = t or now()
    for id, p in pairs(pending) do
        local m = matches[p.key]
        local info = m and m.players[id]
        if not m or not info or not online(id) then
            pending[id] = nil
        elseif t - p.at > CONFIG.deliverTimeoutMs then
            -- never back in time: F1 still has it, nothing pops up later
            pending[id] = nil
            local ok, payload = pcall(R.payload, m, id, {})
            if ok then last[id] = payload; LightRP.state(id, "recap") end
        elseif ready(id) and t >= (p.notBefore or 0) and not (info.away and t - p.at < CONFIG.homeWaitMs) then
            p.readySince = p.readySince or t
            if t - p.readySince >= CONFIG.stableMs and (settled(info) or t - p.at >= CONFIG.rewardWaitMs) then
                CreateThread(function() R.deliver(id) end)
            end
        else
            p.readySince = nil
        end
    end
    -- forget old matches and sessions
    for key, m in pairs(matches) do
        if t - (m.updatedAt or m.createdAt) > CONFIG.matchTtlMs then
            local waiting = false
            for _, p in pairs(pending) do if p.key == key then waiting = true end end
            if not waiting then matches[key] = nil end
        end
    end
    for key, list in pairs(sessions) do
        for id, c in pairs(list) do if t - (c.touchedAt or 0) > CONFIG.sessionTtlMs then list[id] = nil end end
        if next(list) == nil then sessions[key] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- State, page actions, command

LightRP.stateProvider("recap", function(id)
    local p = last[id]
    if not p then return false end
    return { last = { id = p.id, mode = p.mode, result = p.result and p.result.label or nil, test = p.test } }
end)

function R.open(id)
    id = pid(id)
    local p = id and last[id]
    if not p then return false, "No match yet: finish an activity, a mission or a world boss first." end
    local copy = {}
    for k, v in pairs(p) do copy[k] = v end
    copy.reopened = true
    send(id, copy)
    return true
end

LightRP.action("recap.open", function(id)
    local ok, why = R.open(id)
    if not ok then LightRP.result(id, false, why, "recap.open") end
end)
LightRP.action("recap.close", function() end)
LightRP.command("recap", { usage = "/recap (your last match again)" }, function(source)
    if not source or source <= 0 then return false, "Players only." end
    local ok, why = R.open(source)
    if ok then return nil end
    return false, why
end)

-- ---------------------------------------------------------------------------
-- Player lifecycle

local function forget(id)
    pending[id], last[id], latest[id], before[id], current[id], downed[id] = nil, nil, nil, nil, nil, nil
    for _, list in pairs(sessions) do list[id] = nil end
end
R.forget = forget
function R.onDisconnected(id) forget(id) end
function R.onCharacterSwitched(id) forget(id) end
-- An activity entry starts a session (and its "before"); leaving keeps it for a late result.
function R.onActivityChanged(id, activityId)
    id = pid(id)
    if not id or activityId == nil then return end
    local A = LightRP.activities
    local e = A and type(A.current) == "function" and A.current(id)
    if e and e.token then counters("activity:" .. tostring(e.token), id) end
    snapshot(id)
end

CreateThread(function()
    while true do
        Wait(500)
        local ok, err = pcall(R.tick)
        if not ok then LightRP.log("recap: tick failed: %s", tostring(err)) end
    end
end)
