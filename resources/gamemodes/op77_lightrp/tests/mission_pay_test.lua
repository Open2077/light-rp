-- What a finished mission or fixer gig pays (server/modules/mission_pay.lua,
-- docs/economy-balance.md): the crew pot, the per-minute ceiling, the cooldown
-- per character and mission point, the daily cap per account, test runs, failed
-- bank calls, the launch notice, and the cooldowns surviving a restart (an
-- in-memory table stands in for SQL; nothing connects to a database).
dofile("server/config/economy.lua")
local C = LightRpEconomy.missions
local noop = function() end
local unixNow = 20000 * 86400 + 3600 -- 01:00 UTC
local chars, credits, notices, failing = {}, {}, {}, {}
local store = { cooldowns = {}, repCooldowns = {}, daily = {} }
local db = { ready = true, schema = noop }
function db.query(sql, p)
    local out = {}
    local rows = sql:find("FROM lightrp_mission_payout_cooldowns", 1, true) and store.cooldowns
        or sql:find("FROM lightrp_mission_rep_cooldowns", 1, true) and store.repCooldowns
    for _, r in pairs(rows or {}) do
        if r.identifier == p[1] and r.character_key == p[2] and r.until_unix > p[3] then out[#out + 1] = { point_id = r.point_id, until_unix = r.until_unix } end
    end
    return out
end
function db.single(sql, p)
    if sql:find("FROM lightrp_mission_payout_daily", 1, true) then
        local n = store.daily[p[1] .. "|" .. p[2]]
        return n and { full_payouts = n } or nil
    end
end
function db.run(sql, p)
    if sql:find("INSERT INTO lightrp_mission_payout_cooldowns", 1, true) then
        store.cooldowns[p[1] .. "|" .. p[2] .. "|" .. p[3]] = { identifier = p[1], character_key = p[2], point_id = p[3], until_unix = p[4] }
    elseif sql:find("INSERT INTO lightrp_mission_rep_cooldowns", 1, true) then
        store.repCooldowns[p[1] .. "|" .. p[2] .. "|" .. p[3]] = { identifier = p[1], character_key = p[2], point_id = p[3], until_unix = p[4] }
    elseif sql:find("INSERT INTO lightrp_mission_payout_daily", 1, true) then
        local k = p[1] .. "|" .. p[2]
        store.daily[k] = math.max(store.daily[k] or 0, p[3])
    end
    return true
end
Open77 = { time = { unix = function() return unixNow end } }
CreateThread = function(fn) fn() end
LightRP = {
    nowMs = function() return unixNow * 1000 end, log = noop, db = db,
    module = function(name, def) LightRP[name] = def; return def end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body, kind = n.kind } end,
    characters = { get = function(id) return chars[id] end },
    money = {
        format = function(n) return "€$ " .. tostring(n) end,
        addBank = function(id, amount, kind, note)
            if failing[id] then return false, "database_error" end
            credits[#credits + 1] = { id = id, amount = amount, kind = kind, note = note }
            return true
        end,
    },
}
dofile("server/modules/mission_pay.lua")
local Pay = LightRP.missionPay
local function char(id, account, key) chars[id] = { status = "active", identifier = account, key = key or "default" } end
local function total(id) local n = 0 for _, c in ipairs(credits) do if c.id == id then n = n + c.amount end end return n end
local function lastNotice(id) for i = #notices, 1, -1 do if notices[i].id == id then return notices[i] end end end
local function point(id) return { id = id, title = "Job " .. id } end
local standard = { id = "standard", label = "STANDARD", payout = 3000, minutes = 20, min = 1 }

-- ── the crew pot: grows with the crew, split, never above the payout ──
assert(C.crewExponent > 0 and C.crewExponent < 1)
assert(Pay.share(3000, 1, 1) == 3000 and Pay.share(3500, 2, 2) == 3500, "at the minimum crew: the full payout each")
assert(Pay.share(3500, 1, 2) == 3500, "below the minimum (a member left): never more than the payout")
assert(Pay.share(3000, 2, 1) == 2437, "a duo on a solo job: 2,437 each (docs/economy-balance.md)")
local last = 3000
for crew = 2, 8 do
    local s = Pay.share(3000, crew, 1)
    assert(s < last, "each extra operator lowers the share")
    assert(crew * s > (crew - 1) * last, "but the pot keeps growing")
    assert(crew * s < crew * 3000, "the pot grows slower than the crew")
    last = s
end
C.crewExponent = 1; assert(Pay.share(3000, 4, 1) == 3000, "exponent 1: the old rule, everyone keeps the payout")
C.crewExponent = 0; assert(Pay.share(3000, 4, 1) == 750, "exponent 0: a fixed pot split evenly")
C.crewExponent = 0.7
assert(Pay.share(-50, 2, 1) == 0 and Pay.share("x", 2, 1) == 0, "bad payouts pay nothing")

-- ── the ceiling: maxSharePerMinute x the difficulty's minutes ──
assert(Pay.cap(60000, { minutes = 30 }) == C.maxSharePerMinute * 30, "an old authored payout is capped")
assert(Pay.cap(3000, { minutes = 20 }) == 3000, "a payout under the ceiling is untouched")
assert(Pay.cap(60000, {}) == 60000, "no time limit, no ceiling")
for _, P in ipairs({ { 3500, 25 }, { 5000, 30 }, { 9000, 45 }, { 3000, 20 }, { 4500, 25 }, { 6000, 30 } }) do
    assert(Pay.cap(P[1], { minutes = P[2] }) == P[1], "the shipped missions sit under the ceiling")
end

-- ── authored missions and gigs (prod audit 2026-11-04): a band, and the content's size ──
-- The prod contracts as the editor saved them (15 / 15 / 20 min, 1 / 1 / 2 operators):
-- the band holds whatever the payout and the time limit, the per-minute guard stays.
-- The band is the editor's own defaults (owner decision 2026-11-04, §16).
local A = C.authored
assert(A.maxShare.standard == 2400 and A.maxShare.hard == 3000 and A.maxShare.critical == 4400)
local function authoredD(id, minutes, enemies) return { id = id, minutes = minutes, min = 1, enemies = enemies } end
assert(Pay.cap(8000, authoredD("standard", 15, 18)) == 2400, "WAREHOUSE standard: 8,000 saved, 2,400 paid (not 250 x 15)")
assert(Pay.cap(30000, authoredD("hard", 15, 36)) == 3000, "VAMOS hard: 30,000 saved, 3,000 paid")
assert(Pay.cap(80000, authoredD("critical", 20, 48)) == 4400, "TERMINAL B critical: 80,000 saved, 4,400 paid")
assert(Pay.cap(80000, authoredD("critical", 120, 48)) == 4400, "a 120-min clock no longer lifts the ceiling to 30,000")
assert(Pay.cap(2600, authoredD("standard", 15, 12)) == 2400 and Pay.cap(3300, authoredD("hard", 15, 18)) == 3000
    and Pay.cap(5000, authoredD("critical", 20, 24)) == 4400, "the old band (2,600 / 3,300 / 5,000) is above it now")
assert(Pay.cap(2400, authoredD("hard", 5, 30)) == 1250, "a short clock: the guard (250 x 5) still applies")
assert(Pay.cap(2000, authoredD("standard", 15, 30)) == 2000, "under the band: as saved")
-- a small contract pays its size: enemies / fullPayEnemies of its difficulty
assert(Pay.contentScale(authoredD("standard", 15, 3)) == 0.25 and Pay.cap(2400, authoredD("standard", 15, 3)) == 600, "3 enemies: a quarter")
assert(Pay.cap(3000, authoredD("hard", 15, 9)) == 1500, "hard: 9 of 18")
assert(Pay.cap(4400, authoredD("critical", 20, 6)) == 1100, "critical: 6 of 24")
assert(Pay.contentScale(authoredD("standard", 15, 40)) == 1, "a big contract: never more than the full payout")
assert(Pay.contentScale(authoredD("standard", 15, 0)) == 0 and Pay.cap(2400, authoredD("standard", 15, 0)) == 0, "no enemy, no pay")
-- Chimera and Sector 04 (no `enemies` on their difficulties) are not authored
assert(Pay.contentScale(standard) == 1 and Pay.cap(6000, { id = "critical", minutes = 30 }) == 6000, "the shipped missions keep their payouts")
-- a real editor point carries `enemies` per difficulty (shared/mission_defs.lua M.point)
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
local D = LightRpMissionDefs
for _, base in ipairs(D.DIFFICULTIES) do
    assert(A.maxShare[base.id] == base.payout, "the band is the editor's default: " .. base.id)
end
local O = { x = 100, y = 200, z = 10 }
local function spawn(id, count, trigger) return { id = id, position = { x = 110, y = 200, z = 10 }, enemy = "militech", count = count, trigger = trigger } end
local function def(t)
    local raw = { title = "Contract", description = "", location = "Kabuki", type = t.type or "eliminate", enabled = true,
        point = { x = 140, y = 200, z = 10 }, perimeter = { shape = "circle", center = O, radius = 30, minZ = 0, maxZ = 40 },
        outOfBounds = { graceSeconds = 5 }, respawn = { seconds = 4, lives = 1 }, starts = { { x = 100, y = 200, z = 10, heading = 90 } },
        spawns = t.spawns, checkpoints = t.checkpoints or {}, waves = t.waves or {}, difficulties = t.difficulties or {} }
    local v = assert(D.validate(raw)); v.id = "c"; return v
end
local tiny = D.point(def({ spawns = { spawn("a", 3, "start") } }))
assert(tiny.difficulties[1].enemies == 3 and tiny.difficulties[2].enemies == 5 and tiny.difficulties[3].enemies == 6, "3 x 1 / 1.5 / 2, rounded")
assert(Pay.cap(tiny.difficulties[1].payout, tiny.difficulties[1]) == 600, "a 3-enemy placeholder at the editor default pays 600, not 2,400")
local survival = D.point(def({ type = "waves", spawns = { spawn("w1", 2, "wave"), spawn("w2", 2, "wave") },
    waves = { { spawns = { "w1", "w2" } }, { spawns = { "w1", "w2" } }, { spawns = { "w1", "w2" } } } }))
assert(survival.difficulties[1].enemies == 12, "a wave spawn point counts in every wave it is in")
local gated = D.point(def({ spawns = { spawn("s", 2, "start"), spawn("r", 4, "checkpoint"), spawn("o", 6, "checkpoint") },
    checkpoints = { { id = "c1", position = { x = 105, y = 200, z = 10 }, radius = 3, spawns = { "r" } },
        { id = "c2", position = { x = 106, y = 200, z = 10 }, radius = 3, required = false, spawns = { "o" } } } }))
assert(gated.difficulties[1].enemies == 6, "start + required checkpoints; an optional checkpoint does not count")

-- ── settle: a duo on a solo job, then a repeat inside the cooldown ──
char(1, "acc-1"); char(2, "acc-2")
local out = Pay.settle({ id = "m1", members = { 1, 2 } }, point("chimera"), standard)
assert(out[1].amount == 2437 and out[2].amount == 2437 and total(1) == 2437 and total(2) == 2437, "each operator gets the share")
assert(out[1].state == "full" and out[1].crew == 2 and out[1].detail:find("crew of 2", 1, true), "the notice explains the shared pot")
assert(credits[1].kind == "mission" and credits[1].note:find("Job chimera", 1, true), "a mission credit on the ledger")
out = Pay.settle({ id = "m2", members = { 1 } }, point("chimera"), standard)
assert(out[1].state == "cooldown" and out[1].amount == math.floor(3000 * C.repeatShare + 0.5) and total(1) == 2437 + 750, "inside the cooldown: a quarter")
assert(out[1].detail:find("25%", 1, true) and out[1].detail:find("full pay again in 60 min", 1, true), "the notice says why and when")
assert(credits[#credits].note:find("cooldown", 1, true), "the ledger says why too")
out = Pay.settle({ id = "m3", members = { 1 } }, point("sector04"), standard)
assert(out[1].state == "full" and out[1].amount == 3000, "another mission point pays in full")
unixNow = unixNow + C.cooldownMinutes * 60 + 1
assert(Pay.status(1, "chimera") == "full", "after the cooldown: full pay again")
local quoted, state = Pay.quote(1, "chimera", 3000)
assert(quoted == 3000 and state == "full" and Pay.status(1, "chimera") == "full", "a quote records nothing")

-- ── the daily cap: per account, every character together; resets at 00:00 UTC ──
char(3, "acc-3", "first")
for n = 1, C.dailyFullPayouts do
    out = Pay.settle({ id = "d" .. n, members = { 3 } }, point("p" .. n), standard)
    assert(out[3].state == "full", "full payout " .. n)
end
out = Pay.settle({ id = "dx", members = { 3 } }, point("p-extra"), standard)
assert(out[3].state == "capped" and out[3].amount == 750 and out[3].detail:find(C.dailyFullPayouts .. " full payouts today", 1, true), "past the cap: a quarter")
char(3, "acc-3", "second")
assert(Pay.status(3, "p-new") == "capped", "the account's other character shares the cap")
char(4, "acc-4", "second")
assert(Pay.status(4, "p-new") == "full", "another account is not affected")
C.capScope = "character"
assert(Pay.status(3, "p-new") == "full", "capScope character: each character on its own")
C.capScope = "account"
unixNow = (math.floor(unixNow / 86400) + 1) * 86400 + 60
assert(Pay.status(3, "p-new") == "full", "a new UTC day: the count starts over")

-- ── fixer gigs: same rules, a gig credit, the paid map for the fixer's texts ──
char(5, "acc-5"); char(6, "acc-6")
local gig = { payout = 2400, fixerName = "Nix" }
out = Pay.settle({ id = "g1", members = { 5, 6 }, gig = gig }, point("burn"), { id = "standard", label = "Standard", payout = 9999, minutes = 15, min = 1 })
assert(out[5].amount == Pay.share(2400, 2, 1) and gig.paid[5] == out[5].amount and gig.paid[6] == out[6].amount, "the gig's own payout, shared, recorded for the texts")
assert(credits[#credits].kind == "gig" and credits[#credits].note:find("Nix", 1, true), "a gig credit names the fixer")
gig = { payout = 2400, fixerName = "Nix" }
out = Pay.settle({ id = "g2", members = { 5 }, gig = gig }, point("burn"), { id = "standard", label = "Standard", payout = 9999, minutes = 15, min = 1 })
assert(out[5].state == "cooldown" and gig.paid[5] == 600, "a gig repeated inside the cooldown pays a quarter")
gig = { payout = 40000, fixerName = "Nix" }
out = Pay.settle({ id = "g3", members = { 6 }, gig = gig }, point("legacy"), { id = "critical", label = "Critical", payout = 40000, minutes = 20, min = 1 })
assert(out[6].amount == C.maxSharePerMinute * 20, "an old authored gig is capped at the ceiling")
-- an authored gig: fixers.lua quotes Pay.cap at the offer (band + size); settling it
-- applies the ceilings again but never the size twice
char(7, "acc-7")
local smallGig = authoredD("standard", 15, 3)
gig = { payout = Pay.cap(2400, smallGig), fixerName = "Nix" }
out = Pay.settle({ id = "g4", members = { 7 }, gig = gig }, point("small"), smallGig)
assert(gig.payout == 600 and out[7].amount == 600, "a 3-enemy gig: 600 quoted, 600 paid")
gig = { payout = 9000, fixerName = "Nix" }
out = Pay.settle({ id = "g5", members = { 7 }, gig = gig }, point("big"), authoredD("hard", 30, 40))
assert(out[7].amount == 3000, "a gig quoted before the band is still held to it")

-- ── what never pays ──
local before = #credits
assert(next(Pay.settle({ id = "t1", members = { 1 }, test = true }, point("chimera"), standard)) == nil and #credits == before, "editor test runs pay nothing")
char(7, "acc-7"); failing[7] = true
out = Pay.settle({ id = "f1", members = { 7 } }, point("chimera"), standard)
assert(out[7].amount == 0 and out[7].detail:find("nothing was paid", 1, true) and #credits == before, "a failed bank call pays and claims nothing")
failing[7] = nil
assert(Pay.status(7, "chimera") == "full", "a failed payment does not start the cooldown")
out = Pay.settle({ id = "z1", members = { 99 } }, point("chimera"), standard)
assert(out[99].amount == 3000, "a member without an active character is paid but tracked nowhere")

-- ── the launch notice ──
char(8, "acc-8"); char(9, "acc-9")
Pay.settle({ id = "a0", members = { 9 } }, point("raid"), standard) -- 9 is now on cooldown at "raid"
Pay.announce({ id = "a1", members = { 8, 9 } }, point("raid"), standard)
assert(lastNotice(8).title == "PAYOUT" and lastNotice(8).body:find("€$ 2437", 1, true) and lastNotice(8).body:find("crew of 2", 1, true), "what success will pay")
assert(lastNotice(9).kind == "warning" and lastNotice(9).body:find("€$ " .. math.floor(2437 * C.repeatShare + 0.5), 1, true), "a repeat is warned before the job")
local count = #notices
Pay.announce({ id = "a2", members = { 8 }, test = true }, point("raid"), standard)
assert(#notices == count, "no payout notice for a test run")

-- ── reputation: the same repeat rule per mission point (owner decision 2026-11-04) ──
assert(C.reputationCooldownMinutes == C.cooldownMinutes and C.reputationRepeatShare == C.repeatShare, "the money's window and factor")
char(12, "acc-12")
local rep, repState, words = Pay.reputation(12, "warehouse", 100)
assert(rep == 100 and repState == "full" and words == "", "the first completion: the full reputation, nothing to say")
rep, repState, words = Pay.reputation(12, "warehouse", 100)
assert(rep == 25 and repState == "cooldown", "a repeat inside the hour: a quarter")
assert(words:find("25% of 100: this job gave you its full reputation less than 60 min ago", 1, true) and words:find("full reputation again in 60 min", 1, true), words)
assert(Pay.reputation(12, "warehouse", 220) == 55, "the factor applies to what the difficulty grants (hard 220: 55)")
assert(Pay.reputation(12, "pier", 100) == 100, "another mission point grants in full")
unixNow = unixNow + C.reputationCooldownMinutes * 60 - 30
assert(Pay.reputationStatus(12, "warehouse") == "cooldown", "a reduced grant does not extend the window")
unixNow = unixNow + 31
assert(Pay.reputationStatus(12, "warehouse") == "full", "an hour after the full grant: full again")
assert(Pay.reputationQuote(12, "warehouse", 100) == 100 and Pay.reputationStatus(12, "warehouse") == "full", "a quote records nothing")
-- its own window: past the daily money cap no money cooldown starts, the reputation one does
char(13, "acc-13")
for n = 1, C.dailyFullPayouts do Pay.settle({ id = "rc" .. n, members = { 13 } }, point("rc" .. n), standard) end
assert(Pay.settle({ id = "rcx", members = { 13 } }, point("farm"), standard)[13].state == "capped", "money: past the cap")
assert(Pay.reputation(13, "farm", 100) == 100, "the daily cap does not touch reputation")
assert(Pay.status(13, "farm") == "capped", "no money cooldown past the cap")
assert(Pay.reputation(13, "farm", 100) == 25, "but the reputation window started: the repeat is reduced")
char(14, "acc-13", "second")
assert(Pay.reputation(14, "farm", 100) == 100, "per character: the account's other character has its own window")
-- the launch notice says it before the job
char(15, "acc-15")
Pay.reputation(15, "solo", 100)
Pay.announce({ id = "ra", members = { 15 } }, point("solo"), standard)
local launch = lastNotice(15)
assert(launch.kind == "warning" and launch.body:find("€$ 3000 to your account.", 1, true)
    and launch.body:find("Reputation: 25% of it, this job gave you its full reputation less than 60 min ago", 1, true), launch.body)
C.reputationRepeatShare = 1
assert(Pay.reputation(13, "farm", 100) == 100 and Pay.reputationStatus(13, "farm") == "full", "share 1: the rule is off")
C.reputationRepeatShare = 0.25
assert(Pay.reputation(13, "none", 0) == 0 and Pay.reputationStatus(13, "none") == "full", "no reputation, no window")
assert(Pay.reputation(99, "farm", 100) == 100 and Pay.reputation(99, "farm", 100) == 100, "no active character: tracked nowhere")

-- ── cooldowns and the daily count survive a restart ──
char(10, "acc-10")
Pay.settle({ id = "r1", members = { 10 } }, point("restart"), standard)
Pay.reputation(10, "restart", 100)
dofile("server/modules/mission_pay.lua") -- a fresh module: empty caches, rows still in the store
Pay = LightRP.missionPay
assert(Pay.status(10, "restart") == "cooldown", "the cooldown is read back from SQL")
assert(Pay.reputationStatus(10, "restart") == "cooldown" and Pay.reputationStatus(10, "other") == "full", "the reputation window too")
char(11, "acc-11")
for n = 1, C.dailyFullPayouts do Pay.settle({ id = "q" .. n, members = { 11 } }, point("q" .. n), standard) end
dofile("server/modules/mission_pay.lua")
Pay = LightRP.missionPay
assert(Pay.status(11, "q-new") == "capped", "the daily count is read back from SQL")

print("PASS: mission pay (crew pot, ceiling, authored band = editor defaults, cooldown per character and point, daily cap per account / character and UTC reset, gigs, test runs, failed bank, launch notice, reputation repeat rule, persistence)")
