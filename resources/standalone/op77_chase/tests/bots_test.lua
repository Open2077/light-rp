-- op77_chase staff bot mode and crews, end to end against fakes (tests/bots_env.lua): the
-- whole resource with server/bots.lua, a fake Light RP (activityBots, the bots event), fake
-- NPC / vehicle-AI natives.
--   * the switch: activityBots at every registration, the host-wide event, an older Light
--     RP without the export, Light RP stopping;
--   * a solo 1v1 by car: the player runs first (the alternation), the bot cop chases him,
--     the escape is decided on the bot car's position; roles swap, the bot runner drives
--     the course, the bust is decided on its position; result marked test, no database;
--     bots, bodies and cars removed;
--   * a solo 1v1 on foot: the player hunts first (alternation), the bot runner is a body on
--     its mark that flees him, the bust is decided on the body's position; the player drops;
--   * a leave in the countdown; bot mode off: no new bot match, a running one plays out;
--   * missing natives: the car drives itself without a body; nothing at all = called off;
--   * Most Wanted filled by bots: one player, no announce, [BOT] names, the bots' cars
--     arrest him, a bot runner drives the course, no dot to hide, the player leaves = end;
--   * the resource stopping mid-match; the yield heuristic;
--   * crews: a 1v1 crew of two faces each other, a Most Wanted lobby takes a crew whole,
--     crew cops side by side.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test bots_test.lua
local H = dofile("tests/bots_env.lua")
local env
-- chase.1v1 and chase.wanted are real players only by default (config.bots.fill, caps.botFill
-- = false); the bot-fill sections below turn it on, as a server owner would.
local FILL = { ["chase.1v1"] = true, ["chase.wanted"] = true }

local function botOf(match)
    for _, m in ipairs(match.members) do if m.bot then return m.id end end
end

local function noTraces()
    assert(H.count(ChaseBots.bots) == 0, "every bot removed")
    assert(H.count(env.npcs) == 0, "every body removed")
    assert(H.count(env.cars) == 0, "every car removed")
end

-- ---------------------------------------------------------------- the switch

env = H.load({ botsEnabled = true })
assert(env.registered["chase.1v1"] and env.registered["chase.wanted"] and env.registered["chase.pve"], "three activities")
assert(ChaseBots.enabled == true, "activityBots read after the registration")
H.fire("op77_lightrp:activity:bots", false)
assert(ChaseBots.enabled == false, "the event turns it off")
H.fire("op77_lightrp:activity:bots", true)
assert(ChaseBots.enabled == true, "and on")
H.fire("onResourceStop", "op77_lightrp")
assert(ChaseBots.enabled == false, "Light RP stopping = off")
env.botsEnabled = true
H.fire("onResourceStart", "op77_lightrp")
H.run(3)
assert(ChaseBots.enabled == true, "read again at the re-registration")

env = H.load({ noBotsExport = true })
assert(ChaseBots.enabled == false, "an older Light RP without activityBots: off, no error")
H.fire("op77_lightrp:activity:bots", true)
assert(ChaseBots.enabled == true, "the event still works")

-- ---------------------------------------------------------------- real players only (the default)

-- Bot mode on, the default config: chase.1v1 and chase.wanted say caps.botFill = false to
-- Light RP, start nothing with bots and tell the player why; NCPD Escape fills nothing either.
env = H.load({ botsEnabled = true })
for _, aid in ipairs({ "chase.1v1", "chase.wanted", "chase.pve" }) do
    assert(env.registered[aid].botFill == false and env.registered[aid].caps.botFill == false, aid .. " registers botFill = false")
end
assert(ChaseBots.enabled == true and not ChaseBots.fills("chase.1v1") and not ChaseBots.fills("chase.wanted"), "on, but no fill")
H.run(6)
H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "vehicle" })
H.run(10)
assert(Chase.matchOf(1) == nil and ChaseQueue.has(1), "no bot 1v1: he waits for a player")
assert(H.noted(1, "Bot mode is on, but NCPD Chase is real players only"), "and is told why")
H.fire("op77_lightrp:activity:join", 2, "chase.wanted", { mode = "vehicle" })
H.run(10)
assert(ChaseWanted.matchOf(2) == nil and ChaseWantedLobby.has(2) and ChaseWanted.minPlayers() >= 2, "no bot Most Wanted")
assert(H.noted(2, "Bot mode is on, but Most Wanted is real players only"), "told why")
H.fire("op77_lightrp:activity:join", 3, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(1) ~= nil end, 10, "two real players")
assert(Chase.matchOf(1) == Chase.matchOf(3) and not Chase.matchOf(1).hasBots, "a real 1v1, no bot")
assert(H.count(ChaseBots.bots) == 0, "not one bot created")

-- ---------------------------------------------------------------- 1v1 by car, the player runs first

env = H.load({ botsEnabled = true, botFill = FILL })
assert(env.registered["chase.1v1"].botFill == true and env.registered["chase.wanted"].caps.botFill == true
    and env.registered["chase.pve"].botFill == false, "config.bots.fill = true: declared to Light RP")
Chase.botFirstRole[1] = "cop" -- his last bot match started as cop: this one as runner
H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(1) ~= nil end, 6, "a bot match")
local match = Chase.matchOf(1)
local bot = botOf(match)
assert(match.hasBots and ChaseBots.isBot(bot) and bot <= -1001, "a bot member with a negative id")
assert(match.roles[1] == "runner" and match.roles[bot] == "cop", "the player runs first (alternation)")
assert(Chase.botFirstRole[1] == "runner")
assert(match.spawn.route ~= nil, "a course grid: the bot runner will have a road")
assert(env.hud[1].opponentName:sub(1, 6) == "[BOT] ", "the bot shows as [BOT]")
assert(Chase.playerMatch[bot] == nil, "a bot is nobody's player")

H.runUntil(function() return match.state == "active" end, 25, "GO")
local copCar = H.botCar(bot)
assert(copCar and env.cars[copCar], "the bot sits at the wheel of the match car")
H.runUntil(function() return ChaseBots.bots[bot].attached end, 5, "driver attached")
local attach = H.aiCalls("vehicles.ai.attachDriver")[1].args
assert(attach[1] == copCar and attach[2].npcId and attach[2].admissionPlayerId == 1, "driver body attached, the player's client simulates")
local body = env.npcs[attach[2].npcId].def
assert(body.aiMode == 1 and body.bucket == match.bucket and body.damagePolicy == 1, "frozen AI, in the match bucket, immortal")
H.runUntil(function() return #H.aiCalls("vehicles.ai.chase") > 0 end, 5, "the bot cop chases")
local chase = H.aiCalls("vehicles.ai.chase")[1].args
assert(chase[1] == copCar and chase[2].targetKind == "player" and chase[2].targetId == 1, "the bot chases the player's car")
assert(#H.aiCalls("npcs.tasks.setDriverAbility") > 0, "aggressive driver")
assert(env.hud[1].hideDots == nil, "the runner hides nothing")

-- The escape is decided on the bot car's position: the runner holds 250 m from it.
local cp = env.cars[copCar].mark.position
env.pos[1] = H.offset(cp, 250, 0)
H.runUntil(function() return #match.rounds >= 1 end, 60, "the escape")
assert(match.rounds[1].outcome == "runner_escaped" and match.rounds[1].winner == 1, "escaped from the bot")

H.runUntil(function() return match.round == 2 and match.state == "active" end, 45, "round 2")
assert(match.roles[1] == "cop" and match.roles[bot] == "runner", "roles swap")
local runCar = H.botCar(bot)
assert(runCar and runCar ~= copCar, "a new car for the bot runner")
H.runUntil(function() return #H.aiCalls("vehicles.ai.followRoute") > 0 end, 6, "the bot runner drives the course")
local route = H.aiCalls("vehicles.ai.followRoute")[1].args
assert(route[1] == runCar and #route[2].points > 0 and #route[2].points <= 64, "a course of at most 64 points")
assert(env.hud[1].hideDots == nil, "a bot runner has no dot to hide (players only)")

-- The bust is decided on the bot car's position: the cop parks 5 m from it.
env.pos[1] = H.offset(env.cars[runCar].mark.position, 5, 0)
H.runUntil(function() return match.state == "resolved" end, 30, "the bust")
assert(match.rounds[2].outcome == "runner_busted" and match.rounds[2].winner == 1, "busted on the bot's position")
local res = H.results(1, "chase.1v1")
assert(#res == 1, "one result for the player")
assert(res[1].args[3].test == true and res[1].args[3].reputation == 0 and res[1].args[3].won == true, "a test result, nothing earned")
assert(#H.results(bot) == 0, "never a result for a bot")
H.runUntil(function() return Chase.matches[match.id] == nil end, 20, "closed")
assert(H.left(1, "chase.1v1"), "the player goes home")
noTraces()
assert(#env.db == 0, "no database in a bot match")

-- ---------------------------------------------------------------- 1v1 on foot, the player hunts first

H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "foot" })
H.runUntil(function() return Chase.matchOf(1) ~= nil end, 6, "a foot bot match")
match = Chase.matchOf(1)
bot = botOf(match)
assert(match.mode == "foot" and match.roles[1] == "cop" and match.roles[bot] == "runner", "alternation: cop this time")
H.runUntil(function() return match.state == "active" end, 25, "GO on foot")
local npc = ChaseBots.bots[bot].npcId
assert(npc and env.npcs[npc].def.aiMode == 0 and env.npcs[npc].def.behavior.aiEnabled == true, "a body on its mark, tasks AI")
assert(ChaseBots.bots[bot].carId == nil and H.count(env.cars) == 0, "no car on foot")
H.runUntil(function() return #H.aiCalls("npcs.tasks.flee") > 0 end, 10, "the bot flees")
local flee = H.aiCalls("npcs.tasks.flee")[1].args
assert(flee[1] == npc and flee[2] == 1, "it flees the player")
env.pos[1] = H.offset(env.npcs[npc].pos, 2, 0)
H.runUntil(function() return #match.rounds >= 1 end, 20, "the foot bust")
assert(match.rounds[1].outcome == "runner_busted" and match.rounds[1].winner == 1, "busted on the body's position")
env.owner[1] = nil -- Light RP released him, then tells the provider
H.fire("op77_lightrp:activity:dropped", 1, "chase.1v1", "disconnected")
H.runUntil(function() return Chase.matches[match.id] == nil end, 10, "closed after the drop")
assert(not H.left(1, "chase.1v1") or H.left(1, "chase.1v1").at < env.clock - 10000, "a dropped player is never activityLeave'd")
noTraces()

-- ---------------------------------------------------------------- a leave in the countdown

env.pos[1] = nil
H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(1) ~= nil and Chase.matchOf(1).state == "countdown" end, 10, "countdown")
match = Chase.matchOf(1)
H.run(1)
H.fire("op77_lightrp:activity:leaveRequest", 1, "chase.1v1")
H.runUntil(function() return Chase.matches[match.id] == nil end, 10, "closed after the leave")
noTraces()

-- ---------------------------------------------------------------- bot mode off

H.fire("op77_lightrp:activity:join", 2, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(2) ~= nil end, 6, "a bot match for 2")
match = Chase.matchOf(2)
H.fire("op77_lightrp:activity:bots", false)
H.fire("op77_lightrp:activity:join", 3, "chase.1v1", { mode = "vehicle" })
H.run(20)
assert(Chase.matches[match.id] and match.state == "active", "the running bot match plays out")
assert(Chase.matchOf(3) == nil and ChaseQueue.has(3), "no new bot match: player 3 waits for a human")
H.fire("op77_lightrp:activity:leaveRequest", 2, "chase.1v1")
H.runUntil(function() return Chase.matches[match.id] == nil end, 10, "closed")
noTraces()
H.fire("op77_lightrp:activity:join", 4, "chase.wanted", { mode = "vehicle" })
H.run(10)
assert(ChaseWanted.matchOf(4) == nil and ChaseWantedLobby.has(4), "Most Wanted is back to its minimum")
H.fire("op77_lightrp:activity:leaveRequest", 4, "chase.wanted")
H.fire("op77_lightrp:activity:leaveRequest", 3, "chase.1v1")
assert(#env.db == 0, "no database so far")

-- ---------------------------------------------------------------- missing natives

-- No NPC natives: the car drives itself (driverless attach), the match goes on.
env = H.load({ botsEnabled = true, botFill = FILL, before = function(e) _G.Open77.npcs = nil end })
H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(1) ~= nil end, 6, "match without npcs")
match = Chase.matchOf(1)
bot = botOf(match)
H.runUntil(function() return ChaseBots.bots[bot] and ChaseBots.bots[bot].attached end, 30, "driverless attach")
assert(ChaseBots.bots[bot].driverless == true and ChaseBots.bots[bot].npcId == nil, "a car without a body")
local last = H.aiCalls("vehicles.ai.attachDriver")
assert(last[#last].args[2].npcId == nil, "attachDriver without npcId")
H.fire("op77_lightrp:activity:leaveRequest", 1, "chase.1v1")
H.runUntil(function() return Chase.matches[match.id] == nil end, 10, "closed")

-- Nothing at all (no NPC, no vehicle AI): the bot is broken, the match is called off.
env = H.load({ botsEnabled = true, botFill = FILL, before = function(e) _G.Open77.npcs = nil; _G.Open77.vehicles.ai = nil end })
H.fire("op77_lightrp:activity:join", 1, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() return Chase.matchOf(1) ~= nil end, 6, "match without natives")
match = Chase.matchOf(1)
H.runUntil(function() return match.state == "resolved" end, 30, "called off")
assert(match.void, "nothing counts")
assert(#H.results(1) == 0, "no result for a void match")
H.runUntil(function() return Chase.matches[match.id] == nil end, 15, "closed")
assert(H.left(1, "chase.1v1"), "the player goes home")
noTraces()

-- ---------------------------------------------------------------- Most Wanted filled by bots

env = H.load({ botsEnabled = true, botFill = FILL })
H.run(6) -- past the bots' settle window
H.fire("op77_lightrp:activity:join", 2, "chase.wanted", { mode = "vehicle" })
H.runUntil(function() return ChaseWanted.matchOf(2) ~= nil end, 12, "a bot Most Wanted")
local mw = ChaseWanted.matchOf(2)
assert(mw.hasBots and #mw.members == ChaseConfig.bots.wanted.players, "filled up to the bot-mode size")
assert(#H.events("op77_lightrp:announce") == 0, "a bot-mode lobby is never announced")
local bots = {}
for _, m in ipairs(mw.members) do
    if m.bot then
        bots[#bots + 1] = m.id
        assert(m.name:sub(1, 6) == "[BOT] ", "bot names carry [BOT]")
        assert(ChaseWanted.playerMatch[m.id] == nil, "a bot is nobody's player")
    end
end
assert(#bots == 2, "two bots")
H.runUntil(function() return mw.state == "active" end, 30, "round 1 GO")
assert(mw.runnerId == 2, "the player runs first")
local named = 0
for _, row in ipairs(env.hud[2].scoreboard) do if row.name:sub(1, 6) == "[BOT] " then named = named + 1 end end
assert(named == 2, "the HUD scoreboard lists the bots with [BOT]")
H.runUntil(function() return #H.aiCalls("vehicles.ai.chase", function(a) return a[2].targetId == 2 end) > 0 end, 20, "a released bot cop chases")
-- The unit arrest is decided on the bots' cars: both park next to the runner.
local rp = env.pos[2]
for _, b in ipairs(bots) do H.moveCar(H.botCar(b), H.offset(rp, 4, 0)) end
H.runUntil(function() return #mw.rounds >= 1 end, 40, "the unit arrest")
assert(mw.rounds[1].outcome == "runner_busted", "the bots arrested the player")
assert(#H.results(2) == 0, "no result before the end")
H.runUntil(function() return mw.round == 2 and mw.state == "active" end, 45, "round 2")
assert(ChaseBots.isBot(mw.runnerId), "a bot runs")
assert(env.hud[2].hideDots == nil, "a bot runner has no dot to hide")
H.runUntil(function()
    return #H.aiCalls("vehicles.ai.followRoute", function(a) return a[1] == H.botCar(mw.runnerId) end) > 0
end, 8, "the bot runner drives the course")
H.fire("op77_lightrp:activity:leaveRequest", 2, "chase.wanted")
local wres = H.results(2, "chase.wanted")
assert(#wres == 1 and wres[1].args[3].test == true and wres[1].args[3].reputation == 0, "the leaver's result: test, nothing earned")
H.runUntil(function() return ChaseWanted.matches[mw.id] == nil end, 15, "no player left: the match ends")
assert(#H.results(nil, "chase.wanted") == 1, "never a result for a bot")
noTraces()
assert(#env.db == 0, "no database in a bot Most Wanted")

-- ---------------------------------------------------------------- resource stop mid-match

H.fire("op77_lightrp:activity:join", 3, "chase.1v1", { mode = "vehicle" })
H.runUntil(function() local m = Chase.matchOf(3) return m and m.state == "active" and ChaseBots.bots[botOf(m)].attached end, 30, "attached")
assert(H.count(env.npcs) == 1 and H.count(env.cars) == 2)
H.fire("onResourceStop", "op77_chase")
assert(H.count(env.npcs) == 0 and H.count(env.cars) == 0, "bodies and cars removed on stop")
assert(ChaseBots.stopping, "nothing created once stopping")

-- ---------------------------------------------------------------- the yield heuristic

env = H.load({ botsEnabled = true, botFill = FILL })
local id = ChaseBots.create({ role = "runner", mode = "vehicle", bucket = 4300000 })
local t0 = env.clock
assert(ChaseBots.yieldCheck(id, 10, 15, t0) == false, "pinned: not yet")
assert(ChaseBots.yieldCheck(id, 10, 15, t0 + 3900) == false)
assert(ChaseBots.yieldCheck(id, 10, 15, t0 + 4000) == true, "pinned for 4 s: gives up")
assert(ChaseBots.yieldCheck(id, 25, 15, t0 + 5000) == true, "the cop backed off a little: still stopped")
assert(ChaseBots.yieldCheck(id, 31, 15, t0 + 6000) == false, "beyond 2x the radius: drives off again")
ChaseBots.remove(id)

-- ---------------------------------------------------------------- crews

-- 1v1: two of a crew face each other, the stranger who queued first waits.
env = H.load({ botsEnabled = false })
H.fire("op77_lightrp:activity:join", 5, "chase.1v1", { mode = "vehicle" })
local squad = { id = "squad:1", leader = 6, members = { 6, 7 } }
H.fire("op77_lightrp:activity:join", 6, "chase.1v1", { mode = "vehicle", squad = squad })
H.run(3)
assert(Chase.matchOf(5) == nil and Chase.matchOf(6) == nil, "6 is held for his crewmate, 5 is not paired with him")
H.fire("op77_lightrp:activity:join", 7, "chase.1v1", { mode = "vehicle", squad = squad })
H.runUntil(function() return Chase.matchOf(6) ~= nil end, 5, "the crew pair")
assert(Chase.matchOf(6) == Chase.matchOf(7) and Chase.matchOf(5) == nil, "the crew faces each other")
assert(not Chase.matchOf(6).hasBots)

-- Most Wanted lobby: a crew is taken whole, a solo player waits for room.
local L = ChaseWantedLobby
L.reset()
local now = 1000000
local crew = { id = "squad:2", leader = 21, members = { 21, 23 } }
L.add(20, "vehicle", now)
L.add(21, "vehicle", now, crew)
L.add(22, "vehicle", now)
L.add(23, "vehicle", now + 100, crew)
local function always() return true end
local start = L.poll(now + 200, always, { min = 3, max = 3, countdownMs = 45000, squadHoldMs = 10000 })
assert(start and #start.ids == 3, "a full lobby starts at once")
local ids = {}
for _, x in ipairs(start.ids) do ids[x] = true end
assert(ids[20] and ids[21] and ids[23] and not ids[22], "the crew whole, the solo player who would split it waits")
assert(start.squads[21].id == "squad:2" and start.squads[23].id == "squad:2", "the crew goes along")
L.reset()
-- A crewmate on his way: the crew is held, then goes without him.
L.add(30, "vehicle", now, { id = "squad:3", members = { 30, 31 } })
L.add(32, "vehicle", now)
start = L.poll(now + 1000, always, { min = 1, max = 8, countdownMs = 0, squadHoldMs = 10000, allowSolo = true })
start = start or L.poll(now + 1100, always, { min = 1, max = 8, countdownMs = 0, squadHoldMs = 10000, allowSolo = true })
assert(start and #start.ids == 1 and start.ids[1] == 32, "the held crew waits, the solo player goes")
start = L.poll(now + 11000, always, { min = 1, max = 8, countdownMs = 0, squadHoldMs = 10000, allowSolo = true })
start = start or L.poll(now + 11100, always, { min = 1, max = 8, countdownMs = 0, squadHoldMs = 10000, allowSolo = true })
assert(start and start.ids[1] == 30, "after the hold the crew goes with who is there")
L.reset()
-- Crew cops side by side (and in the same dispatch wave).
local order = ChaseWanted.crewOrder({ { id = 1, squad = "a" }, { id = 2 }, { id = 3, squad = "a" }, { id = 4, squad = "b" }, { id = 5, squad = "b" } })
assert(order[1].id == 1 and order[2].id == 3 and order[3].id == 2 and order[4].id == 4 and order[5].id == 5, "crews kept together")

print("PASS: op77_chase bots and crews (switch: activityBots + event + old Light RP; real players only by default (caps.botFill = false, "
    .. "told why); with config.bots.fill: solo 1v1 car runner/cop and foot cop, "
    .. "escape and bust on the bot's car/body position, alternation, test results, no DB, cleanup on end/leave/drop/stop; "
    .. "bot mode off; missing natives; Most Wanted bot fill; yield; 1v1 crew pair, Most Wanted crew lobby and order)")
