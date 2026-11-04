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
--   repeat  a character paid in full at a mission point waits cooldownMinutes
--           before that point pays them in full again; an account (or character,
--           capScope) gets dailyFullPayouts full payouts per UTC day. Meanwhile a
--           completion pays repeatShare of the share.
--   reputation  the same rule per point (owner decision 2026-11-04): a character
--           granted a point's full reputation gets reputationRepeatShare of it there
--           for reputationCooldownMinutes (its own window; the daily cap does not
--           touch reputation). missions.lua asks Pay.reputation, then adds it.
--
--   LightRP.missionPay.cap(payout, d)              -> payout after the ceilings (what the board shows)
--   LightRP.missionPay.contentScale(d)             -> 0..1: an authored difficulty's size (1 otherwise)
--   LightRP.missionPay.share(payout, crew, min)    -> per-head share (pure)
--   LightRP.missionPay.status(id, pointId)         -> "full" | "cooldown" | "capped", info
--   LightRP.missionPay.quote(id, pointId, share)   -> amount, state, info (records nothing)
--   LightRP.missionPay.settle(inst, point, d)      -> { [id] = { amount, share, crew, state, detail } }; pays
--   LightRP.missionPay.announce(inst, point, d)    -> one notice per operator: what success will pay
--   LightRP.missionPay.reputationStatus(id, pointId)     -> "full" | "cooldown", info
--   LightRP.missionPay.reputationQuote(id, pointId, rep) -> amount, state, info (records nothing)
--   LightRP.missionPay.reputation(id, pointId, rep)      -> amount, state, detail; a full grant starts the window
local C = (LightRpEconomy and LightRpEconomy.missions) or {}
local Db = LightRP.db
local Pay = LightRP.module("missionPay", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_payout_cooldowns (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, point_id VARCHAR(64) NOT NULL,
    until_unix BIGINT NOT NULL,
    PRIMARY KEY (identifier, character_key, point_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_rep_cooldowns (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, point_id VARCHAR(64) NOT NULL,
    until_unix BIGINT NOT NULL,
    PRIMARY KEY (identifier, character_key, point_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_payout_daily (
    scope_key VARCHAR(200) NOT NULL, day_index INT NOT NULL, full_payouts INT NOT NULL DEFAULT 0,
    PRIMARY KEY (scope_key, day_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

-- Per character and mission point: when the point pays (money) or grants
-- (reputation) in full again. byCharacter: "identifier#key" -> { synced = bool, points = { [pointId] = untilUnix } }
local MONEY = { table = "lightrp_mission_payout_cooldowns", byCharacter = {} }
local REPUTATION = { table = "lightrp_mission_rep_cooldowns", byCharacter = {} }
local daily = {}     -- scope key -> { day, count, synced }

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
-- Cooldowns and the daily cap: write-through caches, loaded once from SQL.

local function cooldownsOf(who, store)
    store = store or MONEY
    local k = characterKey(who)
    local entry = store.byCharacter[k]
    if not entry then entry = { synced = false, points = {} }; store.byCharacter[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local rows = Db.query("SELECT point_id, until_unix FROM " .. store.table .. " WHERE identifier = ? AND character_key = ? AND until_unix > ?",
            { who.identifier, who.key, unix() }) or {}
        for _, row in ipairs(rows) do
            local untilUnix = tonumber(row.until_unix) or 0
            entry.points[row.point_id] = math.max(entry.points[row.point_id] or 0, untilUnix)
        end
    end
    return entry.points
end

-- Starts the point's window for this character (nothing for 0 minutes).
local function startWindow(who, pointId, store, minutes)
    local untilUnix = unix() + math.floor(number(minutes, 0) * 60)
    if untilUnix <= unix() then return end
    cooldownsOf(who, store)[pointId] = untilUnix
    if Db.ready then
        Db.run("INSERT INTO " .. store.table .. " (identifier, character_key, point_id, until_unix) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE until_unix = VALUES(until_unix)",
            { who.identifier, who.key, pointId, untilUnix })
    end
end

local function dailyOf(who)
    local k, day = scopeKey(who), today()
    local entry = daily[k]
    if not entry or entry.day ~= day then entry = { day = day, count = 0, synced = false }; daily[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local row = Db.single("SELECT full_payouts FROM lightrp_mission_payout_daily WHERE scope_key = ? AND day_index = ?", { k, day })
        entry.count = math.max(entry.count, row and tonumber(row.full_payouts) or 0)
    end
    return entry
end

local function record(who, pointId)
    startWindow(who, pointId, MONEY, C.cooldownMinutes)
    local entry = dailyOf(who)
    entry.count = entry.count + 1
    if Db.ready then
        Db.run("INSERT INTO lightrp_mission_payout_daily (scope_key, day_index, full_payouts) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE full_payouts = GREATEST(full_payouts, VALUES(full_payouts))",
            { scopeKey(who), entry.day, entry.count })
    end
end

function Pay.status(id, pointId)
    local who = owner(id)
    if not who then return "full", {} end
    local untilUnix = cooldownsOf(who)[pointId]
    local now = unix()
    if untilUnix and untilUnix > now then return "cooldown", { seconds = untilUnix - now } end
    local cap = math.floor(number(C.dailyFullPayouts, 0))
    if cap > 0 then
        local used = dailyOf(who).count
        if used >= cap then return "capped", { used = used, cap = cap } end
    end
    return "full", {}
end

function Pay.quote(id, pointId, share)
    local state, info = Pay.status(id, pointId)
    if state == "full" then return share, state, info end
    return round(share * math.max(0, math.min(1, number(C.repeatShare, 0)))), state, info
end

-- The words a notice adds after the amount ("" for a full share at the minimum crew).
local function detail(state, info, crew, min, share)
    local percent = round(math.max(0, math.min(1, number(C.repeatShare, 0))) * 100)
    if state == "cooldown" then
        return string.format(" (%d%% of %s: this job paid you in full less than %d min ago, full pay again in %d min)",
            percent, money(share), math.floor(number(C.cooldownMinutes, 0)), math.max(1, math.ceil((info.seconds or 0) / 60)))
    elseif state == "capped" then
        return string.format(" (%d%% of %s: %d full payouts today already, the count resets at 00:00 UTC)", percent, money(share), info.used or 0)
    elseif crew > min then
        return string.format(" (crew of %d, shared pot)", crew)
    end
    return ""
end
Pay.detail = detail

-- ---------------------------------------------------------------------------
-- Reputation: the same repeat rule per mission point, on its own window

local function repShare() return math.max(0, math.min(1, number(C.reputationRepeatShare, 1))) end
local function repMinutes() return math.max(0, number(C.reputationCooldownMinutes, 0)) end
local function repRule() return repShare() < 1 and repMinutes() > 0 end

function Pay.reputationStatus(id, pointId)
    if not repRule() then return "full", {} end
    local who = owner(id)
    if not who then return "full", {} end
    local untilUnix = cooldownsOf(who, REPUTATION)[pointId]
    local now = unix()
    if untilUnix and untilUnix > now then return "cooldown", { seconds = untilUnix - now } end
    return "full", {}
end

function Pay.reputationQuote(id, pointId, rep)
    rep = math.max(0, math.floor(number(rep, 0)))
    local state, info = Pay.reputationStatus(id, pointId)
    if state == "full" or rep <= 0 then return rep, state, info end
    return round(rep * repShare()), state, info
end

-- The words a notice adds after "+N reputation" ("" for the full reputation).
local function reputationDetail(state, info, full)
    if state ~= "cooldown" then return "" end
    return string.format(" (%d%% of %d: this job gave you its full reputation less than %d min ago, full reputation again in %d min)",
        round(repShare() * 100), full, math.floor(repMinutes()), math.max(1, math.ceil((info.seconds or 0) / 60)))
end

-- What a completion grants this character at the point (missions.lua adds it with
-- Missions.addReputation): amount, state, the notice's words. A full grant starts the
-- point's window; a reduced one does not extend it (like the money).
function Pay.reputation(id, pointId, rep)
    local full = math.max(0, math.floor(number(rep, 0)))
    local amount, state, info = Pay.reputationQuote(id, pointId, full)
    local who = owner(id)
    if state == "full" and amount > 0 and who and repRule() then startWindow(who, pointId, REPUTATION, repMinutes()) end
    return amount, state, reputationDetail(state, info, full)
end

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
        local amount, state, info = Pay.quote(id, point.id, share)
        local paid = amount <= 0
        if amount > 0 and LightRP.money then
            local ok = LightRP.money.addBank(id, amount, kind, state == "full" and note or (note .. " · " .. state))
            paid = ok == true
        end
        local who = owner(id)
        if paid and amount > 0 and state == "full" and who then record(who, point.id) end
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
            local amount, state, info = Pay.quote(id, point.id, share)
            local repState, repInfo = Pay.reputationStatus(id, point.id)
            local repNote = repState == "cooldown" and string.format(" Reputation: %d%% of it, this job gave you its full reputation less than %d min ago (full again in %d min).",
                round(repShare() * 100), math.floor(repMinutes()), math.max(1, math.ceil((repInfo.seconds or 0) / 60))) or ""
            LightRP.notice(id, { kind = (state == "full" and repState == "full") and "money" or "warning", title = "PAYOUT", durationMs = 10000,
                body = string.format("If you finish: %s to your account%s.%s", money(amount), detail(state, info, crew, d.min, share), repNote) })
        end
    end)
end

local authoredMax = type(C.authored) == "table" and type(C.authored.maxShare) == "table" and C.authored.maxShare or {}
LightRP.log("missionPay ready: crew exponent %.2f, %d min cooldown per point, %d full payouts a day per %s, %d%% beyond, ceiling %s/min, authored %s/%s/%s, reputation %d%% for %d min per point",
    number(C.crewExponent, 1), math.floor(number(C.cooldownMinutes, 0)), math.floor(number(C.dailyFullPayouts, 0)),
    C.capScope == "character" and "character" or "account", round(number(C.repeatShare, 0) * 100), tostring(C.maxSharePerMinute or "none"),
    tostring(authoredMax.standard or "-"), tostring(authoredMax.hard or "-"), tostring(authoredMax.critical or "-"),
    round(repShare() * 100), math.floor(repMinutes()))
