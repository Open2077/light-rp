-- Eddies for activity results (server/modules/activity_pay.lua, owner requirement of
-- 2026-11-03, docs/economy-balance.md): amounts, real-player scaling, the no-pay
-- cases, the repeat and daily caps. Real economy config; the core, SQL and natives stubbed.
dofile("server/config/economy.lua")
local noop = function() end
local now, unix = 50000000, 1800000000
local notices, logs, threads, credits, sql = {}, {}, {}, {}, {}
local chars, owned, buckets, crews = {}, {}, {}, {}
for i, name in ipairs({ "alice", "bob", "carol", "dave", "erin", "frank", "gina", "hank" }) do
    chars[i] = { identifier = name, key = "default", status = "active" }
    buckets[i] = 4100001
end
local Db = { ready = false, schema = noop,
    single = function(q, p) sql[#sql + 1] = { q = q, p = p }; return { paid = 0 } end,
    run = function(q, p) sql[#sql + 1] = { q = q, p = p }; return true end }
LightRP = { db = Db, nowMs = function() return now end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    notice = function(id, n) notices[#notices + 1] = { id = id, kind = n.kind, title = n.title, body = n.body } end,
    module = function(name, value) LightRP[name] = value; return value end,
    characters = { get = function(id) return chars[tonumber(id)] end },
    parties = { of = function(id) local c = crews[tonumber(id)]; return c and { id = c, leader = id, members = {} } or nil end },
    activities = { owned = owned, registry = { ["arena.ffa"] = { label = "Combat Zone" }, ["chase.pve"] = { label = "NCPD Escape" } } },
    money = { format = function(n) return "€$ " .. n end,
        addBank = function(id, amount, kind, note, counterparty)
            credits[#credits + 1] = { id = id, amount = amount, kind = kind, note = note, counterparty = counterparty }
            return true
        end },
}
Open77 = { time = { unix = function() return unix end }, players = { position = function() return nil end } }
GetPlayerRoutingBucket = function(id) return buckets[tonumber(id)] end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
dofile("server/modules/activity_pay.lua")
local Pay, C = LightRP.activityPay, LightRpEconomy.activities
assert(#threads == 1, "one roster sampler thread")
threads = {}
assert(C.enabled and C.pvp.perMinute == 70 and C.pvp.dailyCap == 12000 and C.pve.dailyCap == 6000)
assert(C.pvp.ledger == "activity_pvp" and C.pve.ledger == "activity_pve")

local function flush() local list = threads; threads = {}; for _, fn in ipairs(list) do fn() end end
local function enter(pid, activity, minutesAgo)
    local e = { activity = activity, enteredAt = now - (minutesAgo or 20) * 60000,
        identity = { name = chars[pid].identifier, identifier = chars[pid].identifier, characterKey = "default" } }
    owned[pid] = e
    return e
end
local function clear() for k in pairs(owned) do owned[k] = nil end; for k in pairs(crews) do crews[k] = nil end end
local function nextDay() unix = unix + 86400; now = now + 2 * 3600000 end
-- pays one result through the hook; returns the credited amount (nil = nothing)
local function pay(pid, r, raw)
    credits = {}
    Pay.onResult(pid, owned[pid], r, raw)
    flush()
    return credits[1] and credits[1].amount or nil
end
local function why(pid, r, raw) local amount, reason = Pay.quote(pid, owned[pid], r, raw); return amount == nil and reason or amount end
local function ffa(kills, minutes, extra)
    local s = { kills = kills, deaths = 2, assists = 0, durationMs = minutes * 60000 }
    for k, v in pairs(extra or {}) do s[k] = v end
    return { stats = s }
end

-- ── PvP, placement mode: a full lobby of 4 real players, 10 minutes ──
for pid = 1, 4 do enter(pid, "arena.ffa") end
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == 875, "70 x 10 x (0.75 + 0.5)")
assert(credits[1].kind == "activity_pvp" and credits[1].counterparty == "Combat Zone")
assert(credits[1].note == "Combat Zone · #1 of 4 · 10 min")
assert(notices[#notices].kind == "money" and notices[#notices].body == "+€$ 875 — Combat Zone · #1 of 4 · 10 min")
assert(pay(2, { placement = 2 }, ffa(5, 10)) == 758, "second of four: result 2/3")
assert(pay(4, { placement = 4 }, ffa(1, 10)) == 525, "last: participation only")
-- the minutes are capped at the mode's maxSeconds (15 min), the core's own clock caps the provider's
enter(3, "arena.ffa", 40)
assert(why(3, { placement = 3 }, ffa(2, 30)) == math.floor(70 * 15 * (0.75 + 0.5 / 3) + 0.5))
enter(3, "arena.ffa", 4)
assert(why(3, { placement = 3 }, ffa(2, 30)) == math.floor(70 * 4 * (0.75 + 0.5 / 3) + 0.5), "never more than the core saw")
-- a provider's player count is never trusted
assert(why(3, { placement = 3 }, ffa(2, 4, { players = 16 })) == math.floor(70 * 4 * (0.75 + 0.5 / 3) + 0.5))

-- ── real players scale it; a match alone pays nothing ──
nextDay(); clear()
enter(1, "arena.ffa"); enter(2, "arena.ffa")
buckets[3] = 4100002; enter(3, "arena.ffa") -- another instance of the same activity
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == 438, "2 real players of 4: half")
assert(why(3, { placement = 1, won = true }, ffa(9, 10)) == "alone", "alone in its bucket")
buckets[3] = 4100001
-- a peer seen long before this match does not count
clear(); now = now + 3600000
enter(5, "arena.ffa"); enter(6, "arena.ffa"); Pay.sample()
owned[6] = nil; now = now + 30 * 60000
enter(5, "arena.ffa", 12)
assert(why(5, { placement = 1, won = true }, ffa(3, 10)) == "alone", "seen 30 minutes before a 10-minute match")

-- ── crews: all real players in one crew earn nothing; two crews are fine ──
nextDay(); clear()
for pid = 1, 4 do enter(pid, "arena.ffa"); crews[pid] = 7 end
assert(why(1, { placement = 1, won = true }, ffa(9, 10)) == "crew")
crews[3], crews[4] = 8, 8
assert(why(1, { placement = 1, won = true }, ffa(9, 10)) == 875)

-- ── the no-pay cases ──
nextDay(); clear()
for pid = 1, 4 do enter(pid, "arena.ffa") end
assert(why(1, { placement = 1, won = true }, { unranked = true, stats = { kills = 9, durationMs = 600000 } }) == "unranked")
assert(why(1, { placement = 1, won = true }, ffa(9, 10, { quit = true })) == "left")
assert(why(1, { placement = 4 }, ffa(0, 10)) == "no_progress", "AFK: no kill, no assist")
assert(why(1, { placement = 4 }, ffa(0, 10, { assists = 2 })) == 525, "an assist is progress")
assert(why(1, { placement = 1, won = true }, ffa(3, 1.5)) == "too_short", "under the mode's 2 minutes")
assert(why(1, { placement = 1, won = true }, ffa(3, 10, { bots = 2 })) == "bots")
enter(1, "race.editor")
assert(why(1, { placement = 1, won = true }, ffa(3, 10)) == "not_paid", "a mode not listed")
-- a team match: the winning side's AFK member earns nothing
clear()
for pid = 1, 4 do enter(pid, "arena.teams") end
assert(why(1, { placement = 1, won = true }, { stats = { kills = 0, deaths = 3, roundsWon = 2, durationMs = 600000 } }) == "no_progress")
assert(why(2, { placement = 1, won = true }, { stats = { kills = 4, deaths = 1, roundsWon = 2, durationMs = 600000 } }) == 875)
assert(why(3, { placement = 2 }, { stats = { kills = 2, deaths = 4, roundsWon = 1, durationMs = 600000 } }) == 525)
-- wanted: `bots = true`
clear()
for pid = 1, 4 do enter(pid, "chase.wanted") end
assert(why(1, { placement = 1, won = true }, { stats = { points = 40, bots = true } }) == "bots")
-- races: a leaver's DNF pays nothing; a DNF who raced keeps the participation share
clear()
for pid = 1, 4 do enter(pid, "race.grid", 6) end
assert(why(1, {}, { stats = { finished = false, checkpoints = 4, dnfReason = "left" } }) == "left")
assert(why(2, {}, { stats = { finished = false, checkpoints = 0, dnfReason = "timeout" } }) == "no_progress")
assert(why(3, {}, { stats = { finished = false, checkpoints = 5, dnfReason = "timeout" } }) == math.floor(70 * 6 * 0.75 + 0.5), "core clock")
assert(why(4, { placement = 1, won = true }, { stats = { finished = true, checkpoints = 9, timeMs = 300000, racers = 6, bots = 2 } }) == "bots")
assert(why(4, { placement = 1, won = true }, { stats = { finished = true, checkpoints = 9, timeMs = 300000, racers = 4 } }) == 438)

-- ── duel / chase 1v1: a forfeit ──
nextDay(); clear()
enter(1, "chase.1v1"); enter(2, "chase.1v1")
assert(why(2, { placement = 2 }, { stats = { roundsWon = 1, timeMs = 300000, forfeit = true } }) == "left")
assert(why(1, { placement = 1, won = true }, { stats = { roundsWon = 1, timeMs = 300000, forfeit = true } }) == math.floor(70 * 5 * 0.75 + 0.5),
    "the one left standing keeps the participation share")
assert(pay(1, { placement = 1, won = true }, { stats = { roundsWon = 1, timeMs = 300000, forfeit = true } }) == 263)
assert(credits[1].note:find("opponent left"))
now = now + 6 * 60000 -- a result counts the time since the previous one
assert(why(1, { placement = 1, won = true }, { stats = { roundsWon = 2, busts = 1, escapes = 1, timeMs = 300000 } }) == 438)
assert(why(2, { placement = 1 }, { stats = { roundsWon = 1, roundsLost = 1, timeMs = 300000 } }) == 350, "a draw: result 0.5")

-- ── the same set of players: 3 paid duels an hour, then nothing for an hour ──
nextDay(); clear()
enter(1, "arena.duel"); enter(2, "arena.duel")
local duel = { stats = { kills = 3, deaths = 1, roundsWon = 2, durationMs = 300000 } }
for i = 1, 3 do assert(pay(1, { placement = 1, won = true }, duel) == 438, "paid duel " .. i); now = now + 5 * 60000 end
notices = {}
assert(pay(1, { placement = 1, won = true }, duel) == nil and notices[1].body:find("same players"), "the fourth in the hour")
assert(logs[#logs]:find("%(repeat%)"))
assert(pay(2, { placement = 2 }, { stats = { kills = 1, roundsWon = 1, durationMs = 300000 } }) == 263, "each account has its own count")
now = now + 3600000
enter(1, "arena.duel"); enter(2, "arena.duel")
assert(pay(1, { placement = 1, won = true }, duel) == 438, "an hour later")

-- ── a time trial: solo, half rate, a personal best is the bonus ──
nextDay(); clear()
enter(1, "race.trial", 10)
assert(why(1, { placement = 1, won = true }, { stats = { finished = true, timeMs = 180000, personalBest = true } }) == 131)
assert(why(1, { placement = 1, won = true }, { stats = { finished = true, timeMs = 180000 } }) == 79)
assert(why(1, {}, { stats = { finished = false, checkpoints = 6 } }) == "no_progress", "a trial pays a finish")

-- ── PvE: by difficulty, a loss pays half, bots are the opponents ──
nextDay(); clear()
enter(1, "arena.pve")
assert(pay(1, { placement = 1, won = true }, { stats = { kills = 6, durationMs = 600000, players = 1, bots = 5 } }) == 400)
assert(credits[1].kind == "activity_pve" and credits[1].note:find("standard"))
now = now + 11 * 60000
assert(why(1, { placement = 2 }, { stats = { kills = 2, durationMs = 600000, bots = 5 } }) == 200)
assert(why(1, { placement = 2 }, { stats = { kills = 0, durationMs = 600000, bots = 5 } }) == "no_progress")
enter(2, "chase.pve")
assert(pay(2, { placement = 1, won = true }, { stats = { outcome = "escaped", seconds = 300, shakes = 0 } }) == 250, "hard 50 x 5, an escape is progress")
assert(credits[1].note == "NCPD Escape · won · hard · 5 min")
now = now + 6 * 60000
assert(why(2, { placement = 2 }, { stats = { outcome = "arrest", seconds = 300, shakes = 0 } }) == "no_progress")
assert(why(2, { placement = 2 }, { stats = { outcome = "left", seconds = 300, shakes = 2, forfeit = true } }) == "left")
enter(3, "turf.pve")
assert(why(3, { placement = 1, won = true }, { difficulty = "critical", stats = { captures = 2, kills = 3, holdSeconds = 200, durationMs = 480000, bots = 7 } }) == 480,
    "a result naming its difficulty: critical 60 x 8")
assert(why(3, { placement = 1, won = true }, { difficulty = "nightmare", stats = { captures = 2, durationMs = 480000 } }) == 400, "unknown: the mode's own")
owned[3].difficulty = "standard"
assert(why(3, { placement = 1, won = true }, { difficulty = "critical", stats = { captures = 2, durationMs = 480000 } }) == 320,
    "the entry's difficulty (picked when joining) comes first: standard 40 x 8")
owned[3].difficulty = nil
-- PvE is never scaled by players nor stopped by crews or the repeat cap
crews[3] = 9
for i = 1, 6 do assert(why(3, { placement = 1, won = true }, { stats = { captures = 1, durationMs = 480000 } }) == 400) end

-- ── daily cap per account and kind, told once; the next day starts over ──
nextDay(); clear()
local e = enter(1, "arena.ffa")
local detail = { players = 4, minutes = 10, score = 1 }
notices = {}
assert(Pay.settle(1, e, { placement = 1, won = true }, 5000, "pvp", detail) == 5000)
assert(Pay.settle(1, e, { placement = 1, won = true }, 5000, "pvp", detail) == 5000)
assert(Pay.settle(1, e, { placement = 1, won = true }, 5000, "pvp", detail) == 2000, "what is left under 12,000")
assert(Pay.settle(1, e, { placement = 1, won = true }, 500, "pvp", detail) == 0)
assert(Pay.settle(1, e, { placement = 1, won = true }, 500, "pvp", detail) == 0)
local told = 0
for _, n in ipairs(notices) do if n.body:find("Daily PvP pay reached") then told = told + 1 end end
assert(told == 1, "told once")
assert(Pay.paidToday("alice", "pvp") == 12000 and Pay.paidToday("alice", "pve") == 0, "per kind")
assert(Pay.settle(1, enter(1, "arena.pve"), { won = true }, 400, "pve", { difficulty = "standard", minutes = 10 }) == 400)
nextDay()
assert(Pay.settle(1, e, { placement = 1, won = true }, 500, "pvp", detail) == 500 and Pay.paidToday("alice", "pvp") == 500)
-- the cap is the account's: kept in SQL, read once a day, written through
Db.ready = true; sql = {}; nextDay()
assert(Pay.settle(1, e, { placement = 1, won = true }, 300, "pvp", detail) == 300)
assert(sql[1].q:find("SELECT paid FROM lightrp_activity_pay_daily") and sql[1].p[1] == "alice" and sql[1].p[3] == "pvp")
assert(sql[2].q:find("ON DUPLICATE KEY UPDATE paid = GREATEST") and sql[2].p[4] == 300)
Pay.settle(1, e, { placement = 1, won = true }, 300, "pvp", detail)
assert(#sql == 3 and not sql[3].q:find("SELECT"), "read once")
Db.ready = false

-- ── a character switched meanwhile is not paid; the switch off pays nobody ──
nextDay(); clear()
for pid = 1, 4 do enter(pid, "arena.ffa") end
chars[1].key = "second"
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == nil)
chars[1].key = "default"
C.enabled = false
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == nil)
C.enabled = true
enter(1, "arena.ffa")
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == 875)

-- ── what each result paid, or why not, for the end-of-match recap (recap.lua) ──
local reported = {}
LightRP.recap = { reward = function(id, where, fields) reported[#reported + 1] = { id = id, where = where, f = fields } end }
nextDay(); clear()
for pid = 1, 4 do enter(pid, "arena.ffa") end
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == 875)
assert(#reported == 1 and reported[1].id == 1 and reported[1].where == "arena.ffa")
assert(reported[1].f.eddies == 875 and reported[1].f.eddiesReason == "pvp" and reported[1].f.eddiesNote == "#1 of 4 · 10 min")
assert(pay(2, { placement = 2 }, ffa(5, 10, { quit = true })) == nil)
assert(#reported == 2 and reported[2].f.eddies == 0 and reported[2].f.eddiesReason == "left")
local unranked = ffa(9, 10); unranked.unranked = true
assert(pay(3, { placement = 1, won = true }, unranked) == nil)
assert(reported[3].f.eddies == 0 and reported[3].f.eddiesReason == "unranked")
chars[4].key = "second"
assert(pay(4, { placement = 3 }, ffa(2, 10)) == nil)
assert(reported[4].f.eddies == 0 and reported[4].f.eddiesReason == "character", "settled for nobody")
chars[4].key = "default"
C.enabled = false
assert(pay(1, { placement = 1, won = true }, ffa(9, 10)) == nil)
assert(reported[5].f.eddies == 0 and reported[5].f.eddiesReason == "off")
C.enabled = true
LightRP.recap = nil

-- ── the core's hook: after the unranked drop (bot mode, test, friendly, PvP bots), before the record ──
local f = assert(io.open("server/modules/activities.lua", "rb")); local src = f:read("*a"); f:close()
local drop = src:find("local why = unrankedWhy(e, result)", 1, true)
local hook = src:find("pcall(LightRP.activityPay.onResult, id, e, r, result)", 1, true)
local rec = src:find("CreateThread(function() record(id, e, r) end)", 1, true)
assert(drop and hook and rec and drop < hook and hook < rec, "one line where a result is accepted")
local m = assert(io.open("open77.lua", "rb")); local manifest = m:read("*a"); m:close()
assert(manifest:find("server/modules/activities.lua", 1, true) < manifest:find("server/modules/activity_pay.lua", 1, true))

print("activity_pay_test: amounts (placement, result bonus, minutes caps), real-player scaling, crews, unranked / bots / leavers / AFK / too short, forfeit, repeat cap, trial, PvE by difficulty, daily caps and SQL, character switch, recap reports, hook placement passed")
