-- Eddies for activity results. Rules: server/config/economy.lua `activities`;
-- rationale and pacing: docs/economy-balance.md. activities.lua hands every accepted
-- result here in one line, after it has dropped staff bot mode and `test` results.
--
--   PvP ranked  perMinute x the mode's rate x minutes played (up to its maxSeconds)
--               x real players / the mode's full lobby (1 at most)
--               x (participation + resultBonus x result). result: 1 for a win or the
--               first place, down to 0 for the last place (placement modes), 0.5 for
--               a draw, 0 for a loss; a time trial's is a personal best or a record.
--   PvE         perMinute[difficulty] x minutes played; a loss pays lossShare of it.
--
-- Nothing for: an unranked result (`result.unranked`), a PvP match with bots, a match
-- whose real players are all one crew, a player who quit or forfeited (the one left
-- standing when the other forfeits keeps the participation share), less than the
-- mode's minSeconds, no progress (none of the mode's `progress` stats: an AFK player
-- has no kill, no checkpoint, no capture), a mode not listed. The same set of
-- accounts is paid at most repeatPerHour[set size] times an hour (PvP), and each
-- account at most dailyCap per UTC day and kind, all its characters together.
--
-- Real players are what the server itself sees: the players the core owns in the same
-- activity and routing bucket, sampled every few seconds and at the result, counted by
-- account. Never a number a provider or a client reports.
--
--   LightRP.activityPay.onResult(id, entry, r, raw)   the hook; never yields
--   LightRP.activityPay.quote(id, entry, r, raw)      -> amount, kind, detail | nil, reason
--   LightRP.activityPay.settle(...)                   credits a quote (thread)
--   LightRP.activityPay.sample()                      one roster pass
--   LightRP.activityPay.paidToday(identifier, kind)
local E = LightRpEconomy or {}
local C = E.activities or {}
local Db = LightRP.db
local Pay = LightRP.module("activityPay", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_activity_pay_daily (
    identifier VARCHAR(128) NOT NULL, day_index INT NOT NULL, kind VARCHAR(8) NOT NULL, paid INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, day_index, kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local together = {}                              -- identifier -> { key, peers = { [identifier] = { at, id } } }
local repeats = {}                               -- identifier -> { [set] = { ms, ... } }
local daily = {}                                 -- identifier#kind -> { day, paid, synced, told }
local since = setmetatable({}, { __mode = "k" }) -- entry -> ms of its previous result
local DIFFICULTIES = { standard = true, hard = true, critical = true }
local LEFT = { left = true, dropped = true, disconnect = true, quit = true } -- race dnfReason of a leaver
local HOUR = 3600000

local function now() return LightRP.nowMs() end
local function unix()
    if Open77 and Open77.time and type(Open77.time.unix) == "function" then return math.floor(Open77.time.unix()) end
    if type(GetUnixTime) == "function" then return math.floor(GetUnixTime()) end
    return os.time()
end
local function today() return math.floor(unix() / 86400) end
local function number(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return n
end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$ " .. tostring(n)) end
local function bucketOf(id)
    if type(GetPlayerRoutingBucket) == "function" then return tonumber(GetPlayerRoutingBucket(id)) or 0 end
    local p = Open77.players.position(id)
    return p and tonumber(p.bucket) or 0
end

-- ---------------------------------------------------------------------------
-- Who played together: the core's owned players, by activity and bucket.

function Pay.sample()
    local A = LightRP.activities
    if not (A and A.owned) then return end
    local groups, t = {}, now()
    for playerId, e in pairs(A.owned) do
        local who = e.identity
        if who and who.identifier and e.activity then
            local key = e.activity .. "@" .. bucketOf(playerId)
            local group = groups[key] or {}
            groups[key] = group
            group[#group + 1] = { identifier = who.identifier, id = playerId }
        end
    end
    for key, members in pairs(groups) do
        for _, m in ipairs(members) do
            local rec = together[m.identifier]
            if not rec or rec.key ~= key then rec = { key = key, peers = {} }; together[m.identifier] = rec end
            for _, other in ipairs(members) do rec.peers[other.identifier] = { at = t, id = other.id } end
            for other, seen in pairs(rec.peers) do
                if t - seen.at > HOUR then rec.peers[other] = nil end
            end
        end
    end
end

-- The accounts seen in this player's match during the last `windowMs`, themself included.
local function roster(identifier, playerId, windowMs)
    local rec, out, t = together[identifier], {}, now()
    if rec then
        for other, seen in pairs(rec.peers) do
            if t - seen.at <= windowMs then out[other] = seen.id end
        end
    end
    out[identifier] = playerId
    return out
end

local function crewOf(identifier, playerId)
    local P = LightRP.parties
    local crew = playerId and P and type(P.of) == "function" and P.of(playerId) or nil
    return crew and crew.id ~= nil and ("crew:" .. tostring(crew.id)) or ("solo:" .. identifier)
end

local function setOf(list)
    local ids = {}
    for identifier in pairs(list) do ids[#ids + 1] = identifier end
    table.sort(ids)
    return table.concat(ids, "|"), #ids
end

local function repeatCount(identifier, set, t)
    local log = repeats[identifier] and repeats[identifier][set]
    if not log then return 0 end
    local kept = {}
    for _, at in ipairs(log) do if t - at < HOUR then kept[#kept + 1] = at end end
    repeats[identifier][set] = kept
    return #kept
end

-- ---------------------------------------------------------------------------
-- The amount.

-- Any one of the mode's progress stats reached (a `true` threshold wants that flag);
-- `wonCounts` modes also take a win (a solo outcome nobody wins while AFK).
local function progressed(mode, r, s)
    local need = mode.progress
    if not need then return true end
    if mode.wonCounts and r.won then return true end
    for key, minimum in pairs(need) do
        if minimum == true then
            if s[key] == true then return true end
        elseif number(s[key], 0) >= number(minimum, 1) then
            return true
        end
    end
    return false
end

-- What this result played: the provider's own measure when it gives one, never more
-- than the core saw the player inside since the entry (or its previous result).
local function playedMs(entry, s, t)
    local start = math.max(number(entry.enteredAt, t), since[entry] or 0)
    local core = math.max(0, math.min(number(entry.leftAt, t), t) - start)
    local provider = number(s.durationMs, nil) or number(s.timeMs, nil)
    if provider == nil and number(s.seconds, nil) then provider = s.seconds * 1000 end
    if provider and provider >= 0 then return math.min(provider, core) end
    return core
end

local function resultScore(mode, r, s, players)
    if mode.record then return (s.personalBest or s.courseRecord) and 1 or 0 end
    if mode.placement and r.placement then
        if players <= 1 then return r.won and 1 or 0 end
        return math.max(0, math.min(1, (players - r.placement) / (players - 1)))
    end
    if r.won then return 1 end
    if r.placement == 1 then return 0.5 end -- a draw
    return 0
end

local function hadBots(s) return s.bots == true or number(s.bots, 0) > 0 or s.vsAi == true end

-- amount, kind, detail  or  nil, reason
function Pay.quote(id, entry, r, raw)
    raw = type(raw) == "table" and raw or {}
    r = type(r) == "table" and r or {}
    local who = entry and entry.identity
    if not who or not who.identifier then return nil, "no_identity" end
    if raw.unranked == true then return nil, "unranked" end
    local s, t = type(raw.stats) == "table" and raw.stats or {}, now()
    local pve = C.pve and C.pve.modes and C.pve.modes[entry.activity]
    local pvp = not pve and C.pvp and C.pvp.modes and C.pvp.modes[entry.activity]
    local mode = pve or pvp
    if not mode then return nil, "not_paid" end
    local forfeitWin = false
    if s.quit or LEFT[s.dnfReason] then return nil, "left" end
    if s.forfeit then
        if pve or not r.won then return nil, "left" end
        forfeitWin = true
    end
    local played = playedMs(entry, s, t)
    if played < number(mode.minSeconds, 60) * 1000 then return nil, "too_short" end
    if not progressed(mode, r, s) then return nil, "no_progress" end
    local minutes = math.min(played, number(mode.maxSeconds, 600) * 1000) / 60000
    if pve then
        local difficulty = raw.difficulty or s.difficulty
        if not DIFFICULTIES[difficulty] then difficulty = mode.difficulty end
        if not DIFFICULTIES[difficulty] then difficulty = "standard" end
        local rates = C.pve.perMinute
        local rate = number(type(rates) == "table" and rates[difficulty] or rates, 0)
        local amount = math.floor(rate * minutes * (r.won and 1 or number(C.pve.lossShare, 0.5)) + 0.5)
        return amount, "pve", { difficulty = difficulty, minutes = minutes, won = r.won }
    end
    if hadBots(s) then return nil, "bots" end
    Pay.sample()
    local list = roster(who.identifier, id, played + 60000)
    local set, players = setOf(list)
    local full = math.max(1, math.floor(number(mode.players, 2)))
    if full >= 2 and players < 2 then return nil, "alone" end
    if players >= 2 then
        local crews, seen = 0, {}
        for identifier, playerId in pairs(list) do
            local k = crewOf(identifier, playerId)
            if not seen[k] then seen[k] = true; crews = crews + 1 end
        end
        if crews < 2 then return nil, "crew" end
    end
    local limits = C.pvp.repeatPerHour
    local limit = type(limits) == "table" and number(limits[players], nil) or nil
    if limit and repeatCount(who.identifier, set, t) >= limit then return nil, "repeat" end
    local factor = math.min(1, players / full)
    local score = forfeitWin and 0 or resultScore(mode, r, s, players)
    local multiplier = number(C.pvp.participation, 0.75) + number(C.pvp.resultBonus, 0.5) * score
    local amount = math.floor(number(C.pvp.perMinute, 0) * number(mode.rate, 1) * minutes * factor * multiplier + 0.5)
    return amount, "pvp", { players = players, full = full, minutes = minutes, score = score, set = set, forfeit = forfeitWin }
end

-- ---------------------------------------------------------------------------
-- Daily cap per account and kind: a write-through cache, read once from SQL.

local function dailyOf(identifier, kind)
    local k, day = identifier .. "#" .. kind, today()
    local d = daily[k]
    if not d or d.day ~= day then d = { day = day, paid = 0, synced = false }; daily[k] = d end
    if not d.synced and Db.ready then
        d.synced = true
        local row = Db.single("SELECT paid FROM lightrp_activity_pay_daily WHERE identifier = ? AND day_index = ? AND kind = ?", { identifier, day, kind })
        d.paid = math.max(d.paid, row and tonumber(row.paid) or 0)
    end
    return d
end
function Pay.paidToday(identifier, kind) return dailyOf(identifier, kind).paid end

local function labelOf(activityId)
    local A = LightRP.activities
    local def = A and A.registry and A.registry[activityId]
    return def and def.label or tostring(activityId)
end

local function reasonText(r, detail, kind)
    local parts = {}
    if detail.forfeit then parts[#parts + 1] = "opponent left"
    elseif kind == "pvp" and r.placement and (detail.players or 0) > 2 then parts[#parts + 1] = string.format("#%d of %d", r.placement, detail.players)
    elseif r.won then parts[#parts + 1] = "won"
    else parts[#parts + 1] = kind == "pve" and "lost" or "played" end
    if kind == "pve" then parts[#parts + 1] = detail.difficulty end
    parts[#parts + 1] = string.format("%d min", math.max(1, math.floor(detail.minutes + 0.5)))
    return table.concat(parts, " · ")
end

local function sameCharacter(id, who)
    local c = LightRP.characters and LightRP.characters.get(id)
    return c ~= nil and c.status == "active" and c.identifier == who.identifier and (who.characterKey == nil or c.key == who.characterKey)
end

-- Credits a quoted amount within the day's cap. Returns what was paid.
function Pay.settle(id, entry, r, amount, kind, detail)
    local who = entry.identity
    local cfg = C[kind] or {}
    local d = dailyOf(who.identifier, kind)
    local cap = math.floor(number(cfg.dailyCap, 0))
    if cap > 0 then amount = math.max(0, math.min(amount, cap - d.paid)) end
    if amount <= 0 then
        if cap > 0 and d.paid >= cap and not d.told then
            d.told = true
            pcall(LightRP.notice, id, { kind = "info", title = "ACTIVITY PAY", durationMs = 7000,
                body = string.format("Daily %s pay reached (%s). Results still count for stats, rankings and reputation.",
                    kind == "pvp" and "PvP" or "PvE", money(cap)) })
        end
        return 0
    end
    if not sameCharacter(id, who) then return 0 end
    local label = labelOf(entry.activity)
    local note = label .. " · " .. reasonText(r, detail, kind)
    local ok = LightRP.money and LightRP.money.addBank(id, amount, cfg.ledger or ("activity_" .. kind), note, label)
    if not ok then LightRP.log("activity pay: %d for %s not credited", amount, who.identifier) return 0 end
    d.paid = d.paid + amount
    if Db.ready then
        Db.run("INSERT INTO lightrp_activity_pay_daily (identifier, day_index, kind, paid) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE paid = GREATEST(paid, VALUES(paid))",
            { who.identifier, d.day, kind, d.paid })
    end
    if detail.set then
        repeats[who.identifier] = repeats[who.identifier] or {}
        local log = repeats[who.identifier][detail.set] or {}
        log[#log + 1] = now()
        repeats[who.identifier][detail.set] = log
    end
    pcall(LightRP.notice, id, { kind = "money", title = "ACTIVITY PAY", durationMs = 7000,
        body = string.format("+%s — %s", money(amount), note) })
    LightRP.log("activity pay: +%d %s to %s (%s)", amount, kind, who.identifier, note)
    return amount
end

function Pay.onResult(id, entry, r, raw)
    if not C.enabled or type(entry) ~= "table" then return end
    local amount, kind, detail = Pay.quote(id, entry, r, raw)
    since[entry] = now()
    if not amount then
        if kind == "repeat" then
            pcall(LightRP.notice, id, { kind = "info", title = "ACTIVITY PAY", durationMs = 7000,
                body = "No pay this time: the same players already met for pay several times this hour. Results still count." })
        end
        LightRP.log("activity pay: nothing for %s in %s (%s)", tostring(id), tostring(entry.activity), tostring(kind))
        return
    end
    if amount <= 0 then return end
    CreateThread(function()
        local ok, err = pcall(Pay.settle, id, entry, r or {}, amount, kind, detail)
        if not ok then LightRP.log("activity pay: settle failed: %s", tostring(err)) end
    end)
end

CreateThread(function()
    while true do
        Wait(math.max(1, number(C.sampleSeconds, 10)) * 1000)
        local ok, err = pcall(Pay.sample)
        if not ok then LightRP.log("activity pay: roster sample failed: %s", tostring(err)) end
    end
end)
