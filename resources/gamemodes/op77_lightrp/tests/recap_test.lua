-- The end-of-match recap (server/modules/recap.lua, owner request 2026-11-03): the
-- ledger of an activity match (bots included), the core's own counters, DPS, the MVP,
-- the rewards the paying modules report, bot mode (TEST), unranked, the payload size
-- (plain up to ~900 values, latent above, 32 rows at most with the viewer kept), the
-- mission and world-boss paths, when it is sent, F1, and the cleanup. Host stubbed.
dofile("shared/events.lua")
local clock = 100000
local threads = {}
local function run(ms)
    clock = clock + (ms or 500)
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
local function seconds(n) for _ = 1, math.floor(n * 2) do run(500) end end
_G.CreateThread = function(fn)
    local co = coroutine.create(fn)
    threads[#threads + 1] = co
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
end
_G.Wait = function() coroutine.yield() end

local handlers, sent, latent, logs, results, states = {}, {}, {}, {}, {}, {}
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterCommand = function() end
_G.TriggerClientEvent = function(name, id, payload) sent[#sent + 1] = { name = name, id = id, payload = payload } end
_G.TriggerLatentClientEvent = function(name, id, rate, payload)
    latent[#latent + 1] = { name = name, id = id, rate = rate, payload = payload }
    return 1
end
local online, life, buckets = {}, {}, {}
for i = 1, 40 do online[i] = true end
_G.GetPlayerName = function(id) return online[tonumber(id)] and ("p" .. id) or nil end
_G.GetPlayerRoutingBucket = function(id) return buckets[tonumber(id)] or 0 end
Open77 = { players = {
    getLifeState = function(id) return { phase = life[tonumber(id)] or "alive" } end,
    position = function() return nil end,
} }

-- The framework's generous count (framework.lua countStateValues), without the byte check.
local function count(value, n)
    n = (n or 0) + 1
    if type(value) ~= "table" then return n end
    for _, item in pairs(value) do n = count(item, n + 1) end
    return n
end
local actions, providers = {}, {}
local owned, instanceOf = {}, {}
local tier = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1 }
local hof = {}
local refreshes = 0
local wb
local chars = {}
for i = 1, 40 do chars[i] = { identifier = "id" .. i, key = "default", status = "active" } end
LightRP = {
    nowMs = function() return clock end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function(id, key) states[#states + 1] = { id = id, key = key } end,
    action = function(t, fn) actions[t] = fn end,
    command = function() end,
    result = function(id, ok, text, t) results[#results + 1] = { id = id, ok = ok, text = text, action = t } end,
    stateFitsPlainEvent = function(payload)
        local n = count(payload)
        return n <= 900, n
    end,
    characters = { switching = {}, get = function(id) return chars[tonumber(id)] end,
        displayName = function(id) return "Citizen" .. id end },
    medical = { isDowned = function() return false end },
    activities = {
        registry = { ["arena.ffa"] = { label = "Combat Zone", kind = "pvp", resource = "op77_arena" },
            ["race.street"] = { label = "Street Race", kind = "race", resource = "op77_race" },
            ["arena.pve"] = { label = "Arena PvE", pve = true, resource = "op77_arena" } },
        current = function(id) return owned[id] end,
        owns = function(id) return owned[id] ~= nil or instanceOf[id] ~= nil end,
        ownsBucket = function(b) return b >= 4100000 and b < 4200000 end,
    },
    missions = {
        instanceOf = function(id) return instanceOf[id] end,
        tierInfo = function(id) local t = tier[id] or 1; return { tier = t, name = "Tier " .. t, points = t * 100, next = (t + 1) * 100, nextName = "Tier " .. (t + 1) } end,
    },
    worldBosses = { current = function() return wb end },
    hallOfFame = {
        standing = function(id) return hof[id] end,
        refreshSince = function() refreshes = refreshes + 1 end,
    },
}
dofile("server/modules/recap.lua")
local R = LightRP.recap
assert(R and R.name == "recap")
assert(LightRpEvents.net.recap == "op77_lightrp:recap")
assert(#threads == 1, "the delivery loop")

local function lastSent(id)
    for i = #sent, 1, -1 do if sent[i].id == id and sent[i].name == "op77_lightrp:recap" then return sent[i].payload end end
    for i = #latent, 1, -1 do if latent[i].id == id then return latent[i].payload end end
end
local function rowOf(payload, id) for _, row in ipairs(payload.rows) do if row.id == id then return row end end end
local function enter(id, activity, token)
    owned[id] = { token = token, activity = activity, enteredAt = clock, identity = { name = "Player" .. id } }
    R.onActivityChanged(id, activity)
    return owned[id]
end

-- ── an arena FFA round: 3 players + 2 bots from the provider, rewards as paid ──
local e1, e2, e3 = enter(1, "arena.ffa", 11), enter(2, "arena.ffa", 12), enter(3, "arena.ffa", 13)
local recap = { matchId = "arena:1:7", durationMs = 120000, detail = "Round 7",
    rows = {
        { id = 1, name = "Player1", kills = 6, deaths = 2, assists = 1, damage = 2400, damageTaken = 900, headshots = 2, score = 700, placement = 2, inMatchMs = 120000 },
        { id = 2, name = "Player2", kills = 3, deaths = 4, damage = 1200, damageTaken = 1500, score = 350, placement = 3, inMatchMs = 60000 },
        { id = 3, name = "Player3", kills = 1, deaths = 5, assists = 0, damage = 300, score = 100, placement = 5 },
        { id = -1, name = "Bot Rex", bot = true, kills = 9, deaths = 1, damage = 3600, score = 900, placement = 1 },
        { id = -2, name = "Bot Vee", bot = true, kills = 2, deaths = 3, damage = 700, score = 200, placement = 4 },
    } }
local ok, key = R.activityResult(1, e1, { placement = 2, stats = { kills = 6, deaths = 2, durationMs = 120000 }, recap = recap },
    { placement = 2, won = false, score = 700 }, false)
assert(ok and key == "arena.ffa|arena:1:7")
R.activityResult(2, e2, { placement = 3, stats = { kills = 3, deaths = 4 }, recap = recap }, { placement = 3 }, false)
R.activityResult(3, e3, { placement = 5, stats = { kills = 1, deaths = 5 }, recap = recap }, { placement = 5 }, false)
local m = R.matches[key]
assert(#m.order == 5, "players and bots, one row each")
assert(m.rows[-1].bot == true and m.rows[-2].bot == true and not m.rows[1].bot)
-- the paying modules report (activities record(): reputation; activity_pay: eddies)
assert(R.reward(1, "arena.ffa", { reputation = 12, reputationAsked = 12 }))
assert(R.reward(1, "arena.ffa", { eddies = 758, eddiesReason = "pvp", eddiesNote = "#2 of 3 · 2 min" }))
assert(R.reward(2, "arena.ffa", { reputation = 0, reputationAsked = 8 }))
assert(R.reward(2, "arena.ffa", { eddies = 0, eddiesReason = "too_short" }))
assert(not R.reward(9, "arena.ffa", { eddies = 1 }), "no result, no reward")
-- still inside the activity: nothing opens
seconds(5)
assert(lastSent(1) == nil, "never while the activity owns the player")
-- back in the city: 2 s stable, then the screen
owned[1], owned[2] = nil, nil
run(500)
assert(lastSent(1) == nil, "not before 2 s back")
seconds(2.5)
local p1 = lastSent(1)
assert(p1 and p1.kind == "recap" and p1.source == "activity" and p1.mode == "Combat Zone" and p1.detail == "Round 7")
assert(p1.durationMs == 120000 and p1.total == 5 and #p1.rows == 5)
assert(p1.result.label == "#2" and p1.result.of == 5, "placement among every ranked row, bots included")
assert(p1.rows[1].id == -1 and p1.rows[1].bot == true, "sorted by placement")
-- DPS = damage / seconds in the match (the row's own time, else the match's)
assert(rowOf(p1, 1).dps == 20, "2400 / 120 s")
assert(rowOf(p1, 2).dps == 20, "1200 / 60 s in the match")
assert(rowOf(p1, 3).dps == 2.5, "300 / 120 s: the match's duration")
assert(rowOf(p1, -1).dps == 30)
-- the MVP is the best player by score, never a bot
assert(p1.mvp.id == 1 and p1.mvp.by == "score")
assert(p1.rewards.eddies == 758 and p1.rewards.reputation == 12 and p1.rewards.eddiesNote == "#2 of 3 · 2 min")
assert(p1.rewards.tier.tier == 1 and p1.rewards.tier.up == nil)
local cols = table.concat(p1.columns, ",")
assert(cols == "placement,kills,deaths,assists,damage,damageTaken,dps,headshots,score", cols)
assert(rowOf(p1, 3).assists == nil, "zero values stay out of the payload")
local p2 = lastSent(2)
assert(p2.rewards.eddies == 0 and p2.rewards.eddiesReason == "too_short" and p2.rewards.reputationCapped == true)
assert(p2.you == 2 and p2.result.label == "#3")
assert(lastSent(3) == nil, "player 3 is still in the arena")
-- F1: the state names the last match; recap.open sends it again
assert(providers.recap(1).last.id == key and providers.recap(1).last.result == "#2")
assert(providers.recap(9) == false)
local before = #sent
actions["recap.open"](1, { type = "recap.open" })
assert(#sent == before + 1 and sent[#sent].payload.reopened == true and sent[#sent].payload.id == key)
actions["recap.open"](9, { type = "recap.open" })
assert(results[#results].ok == false and results[#results].action == "recap.open")
assert(p1.reopened == nil, "the stored copy is untouched")

-- ── the core's counters: no scoreboard from the provider ──
local e4 = enter(4, "arena.pve", 21)
-- (victim, attacker, amount, kind, weapon, bodyPart, remaining, max, lethal)
handlers["open77:playerDamaged"](5, 4, 40, "ranged", "Items.Preset_Lexington", "head", 60, 100, false)
handlers["open77:playerDamaged"](5, 4, 25, "ranged", "Items.Preset_Lexington", "torso", 35, 100, false)
handlers["open77:playerDamaged"](4, 5, 30, "ranged", "Items.Preset_Lexington", "torso", 70, 100, false)
handlers["open77:playerDamaged"](4, nil, 10, "status", "lightrp:hunger", "torso", 60, 100, false) -- a placement, not combat
handlers["onNpcDamaged"](900, "player:4", 120, 30)
handlers["onNpcDamaged"](901, "npc:900", 50, 30) -- not a player
handlers["onNpcDied"](900, "player:4", "shot")
R.onLifeState(4, "dying"); R.onLifeState(4, "dead"); R.onLifeState(4, "respawnpending"); R.onLifeState(4, "alive")
R.onLifeState(4, "dead"); R.onLifeState(4, "alive")
seconds(1)
R.activityResult(4, e4, { placement = 1, stats = { durationMs = 90000 } }, { placement = 1, won = true }, false)
owned[4] = nil
seconds(1)
assert(lastSent(4) == nil, "the rewards are not reported yet")
seconds(6)
local p4 = lastSent(4)
assert(p4, "sent after the reward wait at most")
local own = p4.rows[1]
assert(#p4.rows == 1 and own.id == 4 and own.name == "Player4")
assert(own.damage == 185 and own.headshots == 1 and own.kills == 1 and own.deaths == 2, "40+25+120 dealt, one head hit, one NPC down, two falls")
assert(own.damageTaken == 30, "hunger is not combat")
assert(own.dps == math.floor(185 / 90 * 10 + 0.5) / 10)
assert(p4.result.label == "WIN" and p4.mvp.id == 4)
assert(p4.rewards.eddies == nil and p4.rewards.test == nil)

-- ── bot mode / a test result: scoreboard marked TEST, no rewards ──
local e6 = enter(6, "arena.ffa", 31)
R.activityResult(6, e6, { placement = 1, test = true, stats = { kills = 4, deaths = 0 },
    recap = { matchId = "arena:2:1", rows = { { id = 6, kills = 4, damage = 800 }, { id = -5, bot = true, name = "Bot", kills = 0, deaths = 4 } } } },
    { placement = 1, won = true }, true)
owned[6] = nil
seconds(2.5)
local p6 = lastSent(6)
assert(p6 and p6.test == true and p6.rewards.test == true and p6.rewards.eddies == nil and p6.rewards.tier == nil, "no reward wait, no rewards")
assert(#p6.rows == 2 and rowOf(p6, -5).bot == true)
-- unranked (the lobby's per-instance flag)
local e7 = enter(7, "arena.ffa", 32)
R.activityResult(7, e7, { placement = 1, unranked = true, stats = { kills = 2 } }, { placement = 1, won = true }, false)
R.reward(7, "arena.ffa", { reputation = 5 }); R.reward(7, "arena.ffa", { eddies = 0, eddiesReason = "unranked" })
owned[7] = nil
seconds(2.5)
assert(lastSent(7).unranked == true and lastSent(7).rewards.eddiesReason == "unranked")
local e8 = enter(8, "arena.ffa", 33)
R.activityResult(8, e8, { placement = 1, ranked = false }, { placement = 1 }, false)
assert(R.matches[R.pending[8].key].players[8].unranked == true, "ranked = false is unranked too")

-- ── payload size: 16 rows plain, 32 rows latent, 40 rows cut to 32 with the viewer kept ──
local function bigRecap(n, matchId)
    local rows = {}
    for i = 1, n do
        local id = i <= 20 and (i + 10) or -i
        rows[i] = { id = id, name = "Racer number " .. i, bot = id < 0, side = (i % 2) + 1, kills = 30 + i, deaths = 10 + i, assists = 5 + i,
            damage = 10000 + i, damageTaken = 9000 + i, headshots = 3 + i, score = 5000 - i, placement = i, inMatchMs = 600000 }
    end
    return { matchId = matchId, durationMs = 600000, sides = { { id = 1, label = "Militech", score = 40 }, { id = 2, label = "Arasaka", score = 38 } },
        winnerSide = 1, rows = rows }
end
local function payloadFor(n, viewer, matchId)
    local e = enter(viewer, "arena.ffa", 100 + n)
    R.activityResult(viewer, e, { placement = 1, recap = bigRecap(n, matchId) }, { placement = 1, won = true }, true)
    owned[viewer] = nil
    return R.payload(R.matches["arena.ffa|" .. matchId], viewer, {})
end
local small = payloadFor(16, 11, "big:16")
local fits, values = LightRP.stateFitsPlainEvent(small)
assert(fits and values < 700, "16 rows: " .. values .. " values")
local full = payloadFor(32, 12, "big:32")
assert(#full.rows == 32)
local fit32, values32 = LightRP.stateFitsPlainEvent(full)
assert(not fit32 and values32 > 900, "32 full rows go latent: " .. values32 .. " values")
-- 39 bots ahead of the viewer: its row takes the 32nd place
local crowd = { matchId = "big:crowd", rows = {} }
for i = 1, 39 do crowd.rows[i] = { id = -i, bot = true, name = "Bot " .. i, kills = 40 - i, placement = i } end
crowd.rows[40] = { id = 20, name = "Last", kills = 0, deaths = 9, placement = 40 }
local e20 = enter(20, "arena.ffa", 140)
R.activityResult(20, e20, { placement = 40, recap = crowd }, { placement = 40 }, true)
owned[20] = nil
local cut = R.payload(R.matches["arena.ffa|big:crowd"], 20, {})
assert(#cut.rows == 32 and cut.total == 40)
assert(cut.rows[32].id == 20 and cut.rows[31].id == -31, "the viewer's row is kept when the board is cut")
assert(cut.result.label == "#40" and cut.result.of == 40)
local cut2 = payloadFor(40, 12, "big:40b")
assert(cut2.rows[32].id ~= 12 and rowOf(cut2, 12), "already in the top 32: nothing replaced")
-- the transport: plain when it fits, latent when not
local plainBefore, latentBefore = #sent, #latent
assert(R.send(30, small))
assert(#sent == plainBefore + 1 and #latent == latentBefore)
local okLatent, _, how = R.send(30, full)
assert(okLatent and how == "latent" and #latent == latentBefore + 1 and latent[#latent].name == "op77_lightrp:recap")
assert(full.sides[1].label == "Militech" and full.winnerSide == 1)
assert(full.result.label == "WIN", "a side's win")
-- an arena match's sides: a loss and a draw
local loss = R.payload(R.matches["arena.ffa|big:32"], 13, {})
assert(loss.result.label == "LOSS", loss.result.label)

-- ── the final scoreboard alone (a race's resolve, host-wide event) ──
local e21 = enter(21, "race.street", 41)
R.activityResult(21, e21, { placement = 1, stats = { timeMs = 185000, bestLapMs = 61000, matchId = "race:5" } }, { placement = 1, won = true }, false)
_G.GetInvokingResource = function() return "op77_race" end
handlers["op77_lightrp:activity:recap"]("race.street", { matchId = "race:5", lines = { { label = "Course", value = "Watson loop" } },
    rows = { { id = 21, name = "Player21", placement = 1, timeMs = 185000, bestLapMs = 61000 }, { id = -1, bot = true, name = "AI", placement = 2, outcome = "dnf" } } })
local race = R.matches["race.street|race:5"]
assert(#race.order == 2 and race.lines[1].value == "Watson loop" and race.rows[-1].outcome == "dnf")
_G.GetInvokingResource = function() return "op77_turf" end
assert(not R.activityRecap("race.street", { matchId = "race:5", lines = { { label = "X", value = "Y" } } }), "another resource's activity")
assert(race.lines[1].label == "Course")
_G.GetInvokingResource = nil
local pr = R.payload(race, 21, {})
assert(pr.result.label == "WIN" and table.concat(pr.columns, ",") == "placement,timeMs,bestLapMs", table.concat(pr.columns, ","))
assert(rowOf(pr, -1).outcome == "dnf")
-- a drawn chase: both first, nobody won -- DRAW for both, not a loss
local drawn = { matchId = "chase:3@1", detail = "Chase 1v1", rows = {
    { id = 24, name = "Player24", placement = 1, roundsWon = 1 }, { id = 25, name = "Player25", placement = 1, roundsWon = 1 } } }
local e24, e25 = enter(24, "chase.1v1", 71), enter(25, "chase.1v1", 72)
R.activityResult(24, e24, { placement = 1, won = false, recap = drawn }, { placement = 1 }, false)
R.activityResult(25, e25, { placement = 1, won = false, recap = drawn }, { placement = 1 }, false)
local d24 = R.payload(R.matches["chase.1v1|chase:3@1"], 24, {})
local d25 = R.payload(R.matches["chase.1v1|chase:3@1"], 25, {})
assert(d24.result.label == "DRAW" and d24.result.tone == "neutral" and d25.result.label == "DRAW", d24.result.label)

-- ── a mission: the crew, the run's lines, the raid's share, home before the screen ──
local inst = { id = "m-7", point = "heist.docks", members = { 1, 2 }, startedAt = clock, test = false,
    run = { def = { type = "waves", waves = { {}, {}, {} }, checkpoints = { { id = "a" }, { id = "b" } }, respawn = { lives = 3 } },
        waveIndex = 3, reached = { a = true }, kills = 17, lives = 1 } }
instanceOf[1], instanceOf[2] = inst, inst
hof[1] = { ["missions.completed"] = { rank = 9, value = 3, title = "Missions completed" }, ["pvp.wins"] = { rank = 4, value = 10, title = "PvP wins" } }
handlers["onNpcDamaged"](950, "player:1", 300, 0)
handlers["onNpcDied"](950, "player:1", "shot")
handlers["onNpcDamaged"](951, "player:2", 100, 0)
assert(R.credit(1, "bossDamage", 6.5) and R.credit(2, "bossDamage", 3.5))
assert(not R.credit(9, "bossDamage", 1), "outside any session")
seconds(30)
local mkey = R.missionEnded(inst, true, nil, { title = "Dockside Heist", type = "RAID" }, { id = "hard", label = "Hard" })
assert(mkey == "mission|m-7")
-- missions.lua pays and grants after it, then sends them home
tier[1] = 2
hof[1] = { ["missions.completed"] = { rank = 6, value = 4, title = "Missions completed" }, ["pvp.wins"] = { rank = 4, value = 10, title = "PvP wins" } }
R.reward(1, mkey, { eddies = 4200, eddiesNote = " (crew of 2)", reputation = 30 })
R.reward(2, mkey, { eddies = 2100, eddiesReason = "cooldown", reputation = 30 })
instanceOf[1], instanceOf[2] = nil, nil
seconds(5)
assert(lastSent(1).id ~= mkey, "not before missions.lua brought them back")
assert(R.home(1) and R.home(2))
seconds(2.5)
local pm = lastSent(1)
assert(pm.id == mkey and pm.source == "mission" and pm.mode == "Dockside Heist" and pm.modeKind == "raid" and pm.detail == "RAID · Hard")
assert(pm.result.label == "COMPLETE" and pm.durationMs >= 30000)
assert(rowOf(pm, 1).damage == 300 and rowOf(pm, 1).kills == 1 and rowOf(pm, 2).damage == 100)
assert(rowOf(pm, 1).bossShare == 65 and rowOf(pm, 2).bossShare == 35, "the raid's priced hits")
local lines = {}
for _, l in ipairs(pm.lines) do lines[l.label] = l.value end
assert(lines.Waves == "3 / 3" and lines.Objectives == "1 / 2" and lines["Hostiles down"] == "17" and lines["Team respawns left"] == "1 / 3" and lines.Crew == "2 operators")
assert(pm.rewards.eddies == 4200 and pm.rewards.reputation == 30 and pm.rewards.tier.up == true)
assert(pm.rewards.hof and #pm.rewards.hof == 1 and pm.rewards.hof[1].board == "Missions completed" and pm.rewards.hof[1].before == 9 and pm.rewards.hof[1].rank == 6)
assert(refreshes >= 1)
assert(lastSent(2).rewards.eddiesReason == "cooldown")
assert(R.sessions[mkey] == nil, "the mission's counters are gone")
-- a failed test run: no rewards, the reason as a line
local inst2 = { id = "m-8", members = { 3 }, startedAt = clock, test = true }
owned[3] = nil
R.missionEnded(inst2, false, "Squad wiped.", { title = "Test Run" }, {})
R.home(3)
seconds(2.5)
local pf = lastSent(3)
assert(pf.result.label == "FAILED" and pf.test == true and pf.rewards.eddies == nil)
assert(pf.lines[#pf.lines].value == "Squad wiped.")

-- ── a world boss: shares, pay, 4 s after its end ──
wb = { id = 3, phase = "fight", inZone = { [1] = true, [2] = true, [5] = true }, def = { title = "Adam Smasher" }, bossLabel = "Smasher",
    location = "Arasaka Waterfront", startedAt = clock }
handlers["open77:playerDamaged"](5, nil, 80, "melee", "Items.Boss", "torso", 20, 100, false) -- the boss hit player 5
R.onLifeState(5, "dead"); R.onLifeState(5, "alive")
seconds(60)
wb.contrib = {
    [1] = { name = "Player1", damage = 5000, bossDamage = 4000, kills = 3, score = 6000, share = 60, firstAt = clock - 50000 },
    [2] = { name = "Player2", damage = 2000, bossDamage = 1000, kills = 1, score = 3600, share = 36, firstAt = clock - 40000 },
    [5] = { name = "Player5", damage = 200, bossDamage = 0, kills = 0, score = 400, share = 4, firstAt = clock - 30000 },
}
wb.results = { [1] = { pay = 30000, eligible = true }, [2] = { pay = 18000, eligible = true }, [5] = { pay = 0, eligible = false } }
wb.need = 8.3
wb.phase = "cleanup"
local wkey = R.worldBossEnded(wb, true, nil, 25)
assert(wkey == "worldboss|3")
seconds(5)
assert(lastSent(5) == nil or lastSent(5).id ~= wkey, "4 s after the end, then 2 s settled")
seconds(1.5)
local pw = lastSent(5)
assert(pw.id == wkey and pw.result.label == "BOSS DOWN" and pw.result.tone == "neutral")
assert(rowOf(pw, 5).damageTaken == 80 and rowOf(pw, 5).deaths == 1 and rowOf(pw, 5).share == 4)
assert(pw.rewards.eddies == 0 and pw.rewards.eddiesReason == "share")
local pw1 = lastSent(1)
assert(pw1.id == wkey and pw1.result.tone == "win" and pw1.rewards.eddies == 30000 and pw1.rewards.reputation == 25)
assert(rowOf(pw1, 1).bossShare == 80 and rowOf(pw1, 2).bossShare == 20)
assert(rowOf(pw1, 1).dps == 100, "5000 over 50 s in the fight")
assert(pw1.mvp.id == 1 and pw1.mvp.by == "share")
local wl = {}
for _, l in ipairs(pw1.lines) do wl[l.label] = l.value end
assert(wl.Boss == "Smasher" and wl.Fighters == "3" and wl["Share needed"] == "8.3 %")

-- ── never over a death screen, a downed body, an activity bucket, a switching character ──
local e9 = enter(9, "arena.ffa", 51)
R.activityResult(9, e9, { placement = 1, test = true }, { placement = 1 }, true)
owned[9] = nil
life[9] = "dead"
seconds(4)
assert(lastSent(9) == nil, "dead")
life[9] = nil; buckets[9] = 4100003
seconds(4)
assert(lastSent(9) == nil, "still in an activity's bucket")
buckets[9] = 2001 -- an interior: fine
LightRP.characters.switching[9] = true
seconds(4)
assert(lastSent(9) == nil, "switching character")
LightRP.characters.switching[9] = nil
seconds(2.5)
assert(lastSent(9) ~= nil)
-- never back in time: kept for F1, nothing pops up later
local e10 = enter(10, "arena.ffa", 52)
R.activityResult(10, e10, { placement = 1, test = true }, { placement = 1 }, true)
seconds(R.config.deliverTimeoutMs / 1000 + 2)
assert(lastSent(10) == nil and R.pending[10] == nil and R.last[10] ~= nil)
owned[10] = nil
seconds(4)
assert(lastSent(10) == nil, "no late popup")

-- ── cleanup: a disconnect forgets the player; old matches go; a reload starts empty ──
local e11 = enter(11, "arena.ffa", 61)
handlers["open77:playerDamaged"](12, 11, 10, "ranged", "x", "torso", 90, 100, false)
R.activityResult(11, e11, { placement = 1, test = true }, { placement = 1 }, true)
R.onDisconnected(11)
assert(R.pending[11] == nil and R.last[11] == nil)
for _, list in pairs(R.sessions) do assert(list[11] == nil, "its counters go") end
assert(not R.open(11))
R.onCharacterSwitched(1)
assert(R.last[1] == nil, "another character: another history")
seconds(R.config.matchTtlMs / 1000 + 5)
local left = 0
for _ in pairs(R.matches) do left = left + 1 end
assert(left == 0, "old matches are forgotten (" .. left .. " left)")
-- a resource reload: memory only, nothing stale
dofile("server/modules/recap.lua")
assert(LightRP.recap ~= R and next(LightRP.recap.last) == nil and next(LightRP.recap.matches) == nil)
-- ── the hooks sit where the results are accepted and the rewards paid ──
local function source(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local acts = source("server/modules/activities.lua")
local hear = acts:find("pcall(LightRP.recap.activityResult, id, e, result, r, A.botsEnabled or result.test == true)", 1, true)
local drop = acts:find("-- unranked (a friendly, a bot match or fill, staff testing)", 1, true) -- the unranked drop (lobby)
local granted = acts:find("pcall(LightRP.recap.reward, id, e.activity, { reputation = granted, reputationAsked = r.reputation })", 1, true)
assert(hear and drop and hear < drop and granted, "every accepted result, test ones included; the reputation as granted")
local missions = source("server/modules/missions.lua")
local ended = missions:find("pcall(LightRP.recap.missionEnded, inst, success, why, point, d)", 1, true)
local settle = missions:find("payouts = LightRP.missionPay.settle(inst, point, d)", 1, true)
local paid = missions:find('pcall(LightRP.recap.reward, id, "mission|" .. tostring(inst.id)', 1, true)
local _, homes = missions:gsub("pcall%(LightRP%.recap%.home, id%)", "")
assert(ended and settle and paid and ended < settle and settle < paid and homes == 2, "before the pay, then each payout, then home")
assert(source("server/modules/world_bosses.lua"):find("pcall(LightRP.recap.worldBossEnded, ev, success, why, ev.noPay and 0 or C.reputation)", 1, true))
assert(source("server/modules/mission_chimera.lua"):find('pcall(LightRP.recap.credit, id, "bossDamage", dealt)', 1, true))
assert(source("server/modules/activity_pay.lua"):find("LightRP.recap.reward, id, entry.activity", 1, true))
local manifest = source("open77.lua")
assert(manifest:find('server_script "server/modules/recap.lua"', 1, true) and manifest:find('client_script "client/core/recap.lua"', 1, true))

for _, line in ipairs(logs) do assert(not line:find("failed"), line) end
print("recap_test: ok")
