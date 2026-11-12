-- What a finished mission or fixer gig pays (rules: server/config/economy.lua
-- `missions`, rationale: docs/economy-balance.md). missions.lua calls settle()
-- when an instance ends in success and announce() when it launches.
--
--   payout  a difficulty's `payout` (a gig's own) is each operator's share at the
--           difficulty's minimum crew, capped at maxSharePerMinute x its minutes
--   authored  an editor mission or gig (its difficulties carry `enemies`, see
--           shared/mission_defs.lua M.point) is also capped at authored.maxShare of
--           its difficulty, then scaled by enemies / authored.fullPayEnemies (at most
--           1); its reputation takes the same scale (Pay.contentScale)
--   pot    past the minimum the pot grows as crew^crewExponent and is split:
--           share = payout * (crew / min) ^ (crewExponent - 1), never above payout
--   repeat  each mission point pays in full ONCE per UTC day PER DIFFICULTY (owner
--           2026-11-12, the "GTA Online" pass): Standard, Hard and Critical of one
--           mission are three separate full payouts, and there is no cap on how many
--           different missions (or difficulties) pay in full in a day. The same
--           mission at the same difficulty again that day pays repeatShare of the
--           share. Counted per account (capScope "account", every character
--           together) or per character (capScope "character").
--   reputation  per character, mission point AND difficulty (owner decisions
--           2026-11-04 and 2026-11-12): a character granted a difficulty's full
--           reputation gets reputationRepeatShare of it at that same difficulty for
--           reputationCooldownMinutes. missions.lua asks Pay.reputation, then adds it.
--
--   LightRP.missionPay.cap(payout, d)              -> payout after the ceilings (what the board shows)
--   LightRP.missionPay.contentScale(d)             -> 0..1: an authored difficulty's size (1 otherwise)
--   LightRP.missionPay.share(payout, crew, min)    -> per-head share (pure)
--   LightRP.missionPay.status(id, pointId, diffId) -> "full" | "repeat", info
--   LightRP.missionPay.paidToday(id, pointId, diffId) -> bool from the cache only (the board; no SQL)
--   LightRP.missionPay.quote(id, pointId, share, diffId) -> amount, state, info (records nothing)
--   LightRP.missionPay.settle(inst, point, d)      -> { [id] = { amount, share, crew, state, detail } }; pays
--   LightRP.missionPay.announce(inst, point, d)    -> one notice per operator: what success will pay
--   LightRP.missionPay.reputationStatus(id, pointId, diffId)     -> "full" | "cooldown", info
--   LightRP.missionPay.reputationQuote(id, pointId, rep, diffId) -> amount, state, info (records nothing)
--   LightRP.missionPay.reputation(id, pointId, rep, diffId)      -> amount, state, detail; a full grant starts the window
local C = (LightRpEconomy and LightRpEconomy.missions) or {}
local Db = LightRP.db
local Pay = LightRP.module("missionPay", {})

-- One row per full payout: (scope, UTC day, mission point, difficulty). The old
-- per-point cooldown and daily count tables (lightrp_mission_payout_cooldowns,
-- lightrp_mission_payout_daily) are no longer read.
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_full_pays (
    scope_key VARCHAR(200) NOT NULL, day_index INT NOT NULL, point_id VARCHAR(64) NOT NULL, difficulty VARCHAR(32) NOT NULL,
    PRIMARY KEY (scope_key, day_index, point_id, difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
-- Reputation windows per character, point and difficulty (was per point:
-- lightrp_mission_rep_cooldowns, no longer read).
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_rep_windows (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, point_id VARCHAR(64) NOT NULL, difficulty VARCHAR(32) NOT NULL,
    until_unix BIGINT NOT NULL,
    PRIMARY KEY (identifier, character_key, point_id, difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local days = {}      -- scope key -> { day, synced, paid = { ["point|difficulty"] = true } }
local windows = {}   -- "identifier#key" -> { synced, points = { ["point|difficulty"] = untilUnix } }

local function unix()
    if Open77 and Open77.time and type(Open77.time.unix) == "function" then return math.floor(Open77.time.unix()) end
    if type(GetUnixTime) == "function" then return math.floor(GetUnixTime()) end
    return os.time()
end
local function today() return math.floor(unix() / 86400) end
local function round(n) return math.floor(n + 0.5) end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$ " .. tostring(n)) end
local function number(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n then return fallback end
    return n
end

local function owner(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if c and c.status == "active" and c.identifier then return { identifier = tostring(c.identifier), key = tostring(c.key or "default") } end
end
local function characterKey(who) return who.identifier .. "#" .. who.key end
local function scopeKey(who) return C.capScope == "character" and characterKey(who) or who.identifier end
-- a difficulty id (a gig or an old caller without one: "*", one slot per point)
local function diffOf(difficultyId)
    local s = difficultyId ~= nil and tostring(difficultyId) or ""
    return s ~= "" and s:sub(1, 32) or "*"
end
local function slot(pointId, difficultyId) return tostring(pointId) .. "|" .. diffOf(difficultyId) end
local function repeatShare() return math.max(0, math.min(1, number(C.repeatShare, 0))) end

-- ---------------------------------------------------------------------------
-- Pure rules

local function authored(d) return type(d) == "table" and type(d.enemies) == "number" and type(C.authored) == "table" end

function Pay.contentScale(d)
    if not authored(d) then return 1 end
    local full = number(type(C.authored.fullPayEnemies) == "table" and C.authored.fullPayEnemies[d.id], 0)
    if full <= 0 then return 1 end
    return math.max(0, math.min(1, d.enemies / full))
end

-- The ceilings alone (per minute, authored maxShare): applying it twice changes nothing.
local function ceiling(payout, d)
    payout = math.max(0, math.floor(number(payout, 0)))
    local perMinute, minutes = number(C.maxSharePerMinute, 0), number(d and d.minutes, 0)
    if perMinute > 0 and minutes > 0 then payout = math.min(payout, math.floor(perMinute * minutes)) end
    if authored(d) then
        local most = number(type(C.authored.maxShare) == "table" and C.authored.maxShare[d.id], 0)
        if most > 0 then payout = math.min(payout, math.floor(most)) end
    end
    return payout
end

function Pay.cap(payout, d)
    return round(ceiling(payout, d) * Pay.contentScale(d))
end

function Pay.share(payout, crew, min)
    payout = math.max(0, math.floor(number(payout, 0)))
    crew, min = math.max(1, math.floor(number(crew, 1))), math.max(1, math.floor(number(min, 1)))
    if crew <= min then return payout end
    local exponent = math.max(0, math.min(1, number(C.crewExponent, 1)))
    return math.min(payout, round(payout * (crew / min) ^ (exponent - 1)))
end

-- ---------------------------------------------------------------------------
-- Full payouts of the day: a write-through cache, loaded once per scope and day.

local function dayOf(who)
    local k, day = scopeKey(who), today()
    local entry = days[k]
    if not entry or entry.day ~= day then entry = { day = day, synced = false, paid = {} }; days[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local rows = Db.query("SELECT point_id, difficulty FROM lightrp_mission_full_pays WHERE scope_key = ? AND day_index = ?", { k, day }) or {}
        for _, row in ipairs(rows) do entry.paid[tostring(row.point_id) .. "|" .. tostring(row.difficulty)] = true end
    end
    return entry
end

local function record(who, pointId, difficultyId)
    local entry = dayOf(who)
    entry.paid[slot(pointId, difficultyId)] = true
    if Db.ready then
        Db.run("INSERT IGNORE INTO lightrp_mission_full_pays (scope_key, day_index, point_id, difficulty) VALUES (?, ?, ?, ?)",
            { scopeKey(who), entry.day, tostring(pointId), diffOf(difficultyId) })
    end
end

function Pay.status(id, pointId, difficultyId)
    local who = owner(id)
    if not who then return "full", {} end
    if dayOf(who).paid[slot(pointId, difficultyId)] then
        return "repeat", { resetSeconds = (today() + 1) * 86400 - unix() }
    end
    return "full", {}
end

-- The board's "paid today" tag: the cache only (no SQL on a view; a scope not read
-- yet answers false until its first status, settle or the character's load).
function Pay.paidToday(id, pointId, difficultyId)
    local who = owner(id)
    if not who then return false end
    local entry = days[scopeKey(who)]
    return entry ~= nil and entry.day == today() and entry.paid[slot(pointId, difficultyId)] == true
end

function Pay.quote(id, pointId, share, difficultyId)
    local state, info = Pay.status(id, pointId, difficultyId)
    if state == "full" then return share, state, info end
    return round(share * repeatShare()), state, info
end

local function untilReset(info)
    local s = math.max(60, math.floor(number(info and info.resetSeconds, 0)))
    local h, mn = s // 3600, (s % 3600) // 60
    return h > 0 and string.format("%d h %02d", h, mn) or string.format("%d min", mn)
end

-- The words a notice adds after the amount ("" for a full share at the minimum crew).
local function detail(state, info, crew, min, share)
    if state == "repeat" then
        return string.format(" (%d%% of %s: this mission already paid you in full at this difficulty today. Try another difficulty or mission, full pay here again in %s)",
            round(repeatShare() * 100), money(share), untilReset(info))
    elseif crew > min then
        return string.format(" (crew of %d, shared pot)", crew)
    end
    return ""
end
Pay.detail = detail

-- ---------------------------------------------------------------------------
-- Reputation: per character, point and difficulty, on its own window

local function repShare() return math.max(0, math.min(1, number(C.reputationRepeatShare, 1))) end
local function repMinutes() return math.max(0, number(C.reputationCooldownMinutes, 0)) end
local function repRule() return repShare() < 1 and repMinutes() > 0 end

local function windowsOf(who)
    local k = characterKey(who)
    local entry = windows[k]
    if not entry then entry = { synced = false, points = {} }; windows[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local rows = Db.query("SELECT point_id, difficulty, until_unix FROM lightrp_mission_rep_windows WHERE identifier = ? AND character_key = ? AND until_unix > ?",
            { who.identifier, who.key, unix() }) or {}
        for _, row in ipairs(rows) do
            local key = tostring(row.point_id) .. "|" .. tostring(row.difficulty)
            entry.points[key] = math.max(entry.points[key] or 0, tonumber(row.until_unix) or 0)
        end
    end
    return entry.points
end

local function startWindow(who, pointId, difficultyId, minutes)
    local untilUnix = unix() + math.floor(number(minutes, 0) * 60)
    if untilUnix <= unix() then return end
    windowsOf(who)[slot(pointId, difficultyId)] = untilUnix
    if Db.ready then
        Db.run("INSERT INTO lightrp_mission_rep_windows (identifier, character_key, point_id, difficulty, until_unix) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE until_unix = VALUES(until_unix)",
            { who.identifier, who.key, tostring(pointId), diffOf(difficultyId), untilUnix })
    end
end

function Pay.reputationStatus(id, pointId, difficultyId)
    if not repRule() then return "full", {} end
    local who = owner(id)
    if not who then return "full", {} end
    local untilUnix = windowsOf(who)[slot(pointId, difficultyId)]
    local now = unix()
    if untilUnix and untilUnix > now then return "cooldown", { seconds = untilUnix - now } end
    return "full", {}
end

function Pay.reputationQuote(id, pointId, rep, difficultyId)
    rep = math.max(0, math.floor(number(rep, 0)))
    local state, info = Pay.reputationStatus(id, pointId, difficultyId)
    if state == "full" or rep <= 0 then return rep, state, info end
    return round(rep * repShare()), state, info
end

-- The words a notice adds after "+N reputation" ("" for the full reputation).
local function reputationDetail(state, info, full)
    if state ~= "cooldown" then return "" end
    return string.format(" (%d%% of %d: this difficulty gave you its full reputation less than %d min ago, full reputation again in %d min)",
        round(repShare() * 100), full, math.floor(repMinutes()), math.max(1, math.ceil((info.seconds or 0) / 60)))
end

-- What a completion grants this character at the point and difficulty (missions.lua
-- adds it with Missions.addReputation): amount, state, the notice's words. A full
-- grant starts the window; a reduced one does not extend it.
function Pay.reputation(id, pointId, rep, difficultyId)
    local full = math.max(0, math.floor(number(rep, 0)))
    local amount, state, info = Pay.reputationQuote(id, pointId, full, difficultyId)
    local who = owner(id)
    if state == "full" and amount > 0 and who and repRule() then startWindow(who, pointId, difficultyId, repMinutes()) end
    return amount, state, reputationDetail(state, info, full)
end

-- The board reads Pay.paidToday from the cache: read the day's rows when a
-- character comes in (a thread: the read is SQL).
local function prime(playerId)
    CreateThread(function()
        local who = owner(playerId)
        if who then dayOf(who) end
    end)
end
function Pay.onCharacterActivated(playerId) prime(playerId) end
function Pay.onCharacterSwitched(playerId) prime(playerId) end

-- ---------------------------------------------------------------------------
-- Settlement and the launch notice

local function parts(inst, point, d)
    -- a gig's payout was quoted with Pay.cap at the offer (fixers.lua): only the
    -- ceilings again, never the content scale twice
    local base = inst.gig and inst.gig.payout and ceiling(inst.gig.payout, d) or Pay.cap(d.payout, d)
    local crew = #inst.members
    return base, crew, Pay.share(base, crew, d.min)
end

function Pay.settle(inst, point, d)
    local out = {}
    if inst.test then return out end
    local base, crew, share = parts(inst, point, d)
    local kind = inst.gig and "gig" or "mission"
    local note = inst.gig and ("Gig: " .. point.title .. " (" .. (inst.gig.fixerName or "fixer") .. ")")
        or ("Mission: " .. point.title .. " (" .. d.label .. ")")
    for _, id in ipairs(inst.members) do
        local amount, state, info = Pay.quote(id, point.id, share, d.id)
        local paid = amount <= 0
        if amount > 0 and LightRP.money then
            local ok = LightRP.money.addBank(id, amount, kind, state == "full" and note or (note .. " · " .. state))
            paid = ok == true
        end
        local who = owner(id)
        if paid and amount > 0 and state == "full" and who then record(who, point.id, d.id) end
        out[id] = { amount = paid and amount or 0, share = share, crew = crew, state = state,
            detail = paid and detail(state, info, crew, d.min, share) or " (the bank did not answer: tell the staff, nothing was paid)" }
        if not paid then LightRP.log("missionPay: %s payout of %d to %s failed", inst.id or "?", amount, tostring(id)) end
    end
    if inst.gig then
        inst.gig.paid = {}
        for id, r in pairs(out) do inst.gig.paid[id] = r.amount end
    end
    LightRP.log("missionPay: %s %s (%s) payout %d at min %d, crew %d -> share %d", inst.id or "?", point.title, d.label, base, d.min or 1, crew, share)
    return out
end

function Pay.announce(inst, point, d)
    if inst.test then return end
    local _, crew, share = parts(inst, point, d)
    if share <= 0 then return end
    local members = {}
    for i, id in ipairs(inst.members) do members[i] = id end
    -- the first read of a character's cooldowns is a SQL query: off the launch path
    CreateThread(function()
        for _, id in ipairs(members) do
            local amount, state, info = Pay.quote(id, point.id, share, d.id)
            local repState, repInfo = Pay.reputationStatus(id, point.id, d.id)
            local repNote = repState == "cooldown" and string.format(" Reputation: %d%% of it, this difficulty gave you its full reputation less than %d min ago (full again in %d min).",
                round(repShare() * 100), math.floor(repMinutes()), math.max(1, math.ceil((repInfo.seconds or 0) / 60))) or ""
            LightRP.notice(id, { kind = (state == "full" and repState == "full") and "money" or "warning", title = "PAYOUT", durationMs = 10000,
                body = string.format("If you finish: %s to your account%s.%s", money(amount), detail(state, info, crew, d.min, share), repNote) })
        end
    end)
end

local authoredMax = type(C.authored) == "table" and type(C.authored.maxShare) == "table" and C.authored.maxShare or {}
LightRP.log("missionPay ready: crew exponent %.2f, full pay once a day per mission and difficulty per %s (no daily cap), %d%% on a repeat, ceiling %s/min, authored %s/%s/%s, reputation %d%% for %d min per mission and difficulty",
    number(C.crewExponent, 1),
    C.capScope == "character" and "character" or "account", round(repeatShare() * 100), tostring(C.maxSharePerMinute or "none"),
    tostring(authoredMax.standard or "-"), tostring(authoredMax.hard or "-"), tostring(authoredMax.critical or "-"),
    round(repShare() * 100), math.floor(repMinutes()))
