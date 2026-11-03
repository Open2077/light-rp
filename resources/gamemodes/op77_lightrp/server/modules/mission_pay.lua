-- What a finished mission or fixer gig pays (rules: server/config/economy.lua
-- `missions`, rationale: docs/economy-balance.md). missions.lua calls settle()
-- when an instance ends in success and announce() when it launches.
--
--   payout  a difficulty's `payout` (a gig's own) is each operator's share at the
--           difficulty's minimum crew, capped at maxSharePerMinute x its minutes
--   pot     past the minimum the pot grows as crew^crewExponent and is split:
--           share = payout * (crew / min) ^ (crewExponent - 1), never above payout
--   repeat  a character paid in full at a mission point waits cooldownMinutes
--           before that point pays them in full again; an account (or character,
--           capScope) gets dailyFullPayouts full payouts per UTC day. Meanwhile a
--           completion pays repeatShare of the share. Reputation is untouched.
--
--   LightRP.missionPay.cap(payout, d)              -> payout after the ceiling
--   LightRP.missionPay.share(payout, crew, min)    -> per-head share (pure)
--   LightRP.missionPay.status(id, pointId)         -> "full" | "cooldown" | "capped", info
--   LightRP.missionPay.quote(id, pointId, share)   -> amount, state, info (records nothing)
--   LightRP.missionPay.settle(inst, point, d)      -> { [id] = { amount, share, crew, state, detail } }; pays
--   LightRP.missionPay.announce(inst, point, d)    -> one notice per operator: what success will pay
local C = (LightRpEconomy and LightRpEconomy.missions) or {}
local Db = LightRP.db
local Pay = LightRP.module("missionPay", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_payout_cooldowns (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, point_id VARCHAR(64) NOT NULL,
    until_unix BIGINT NOT NULL,
    PRIMARY KEY (identifier, character_key, point_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_payout_daily (
    scope_key VARCHAR(200) NOT NULL, day_index INT NOT NULL, full_payouts INT NOT NULL DEFAULT 0,
    PRIMARY KEY (scope_key, day_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local cooldowns = {} -- "identifier#key" -> { synced = bool, points = { [pointId] = untilUnix } }
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

function Pay.cap(payout, d)
    payout = math.max(0, math.floor(number(payout, 0)))
    local perMinute, minutes = number(C.maxSharePerMinute, 0), number(d and d.minutes, 0)
    if perMinute > 0 and minutes > 0 then payout = math.min(payout, math.floor(perMinute * minutes)) end
    return payout
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

local function cooldownsOf(who)
    local k = characterKey(who)
    local entry = cooldowns[k]
    if not entry then entry = { synced = false, points = {} }; cooldowns[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local rows = Db.query("SELECT point_id, until_unix FROM lightrp_mission_payout_cooldowns WHERE identifier = ? AND character_key = ? AND until_unix > ?",
            { who.identifier, who.key, unix() }) or {}
        for _, row in ipairs(rows) do
            local untilUnix = tonumber(row.until_unix) or 0
            entry.points[row.point_id] = math.max(entry.points[row.point_id] or 0, untilUnix)
        end
    end
    return entry.points
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
    local untilUnix = unix() + math.floor(number(C.cooldownMinutes, 0) * 60)
    if untilUnix > unix() then
        cooldownsOf(who)[pointId] = untilUnix
        if Db.ready then
            Db.run("INSERT INTO lightrp_mission_payout_cooldowns (identifier, character_key, point_id, until_unix) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE until_unix = VALUES(until_unix)",
                { who.identifier, who.key, pointId, untilUnix })
        end
    end
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
-- Settlement and the launch notice

local function parts(inst, point, d)
    local base = Pay.cap(inst.gig and (inst.gig.payout or d.payout) or d.payout, d)
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
            LightRP.notice(id, { kind = state == "full" and "money" or "warning", title = "PAYOUT", durationMs = 10000,
                body = string.format("If you finish: %s to your account%s.", money(amount), detail(state, info, crew, d.min, share)) })
        end
    end)
end

LightRP.log("missionPay ready: crew exponent %.2f, %d min cooldown per point, %d full payouts a day per %s, %d%% beyond, ceiling %s/min",
    number(C.crewExponent, 1), math.floor(number(C.cooldownMinutes, 0)), math.floor(number(C.dailyFullPayouts, 0)),
    C.capScope == "character" and "character" or "account", round(number(C.repeatShare, 0) * 100), tostring(C.maxSharePerMinute or "none"))
