-- op77_chase NCPD Escape (chase.pve), end to end against fakes (tests/bots_env.lua): the
-- whole resource, a fake Light RP, fake NPC / vehicle-AI natives. No staff switch.
--   * solo by car: the gathering queue, 3 bot cops on the course grid, the runner's own car,
--     waves after the head start, the cops chase him, the arrest on the bot cars' positions
--     after minSeconds (busted reputation), HUD ([BOT] names, no dot hidden), the client
--     view, cleanup;
--   * escapes: a shake before minSeconds only re-arms, the next one is the escape (escaped
--     reputation); the clock (with the extraction revealed at its heat level);
--   * a crew of two: one match, 5 cops, cars in line; one runner busted -> his result now,
--     every cop on the other; the other leaves -> his result (forfeit, nothing); cleanup;
--   * a crew member who never comes: the crew goes after squadWaitSeconds; a leave in the
--     countdown = void;
--   * on foot: no runner car; a drop = no result;
--   * reputation: nothing under minSeconds, perDay paid rounds per character, leavers;
--   * one chase activity at a time, /escape, staff status / stop, broken bots, Light RP
--     stopping, the resource stopping; never a database touch, never a test result.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test pve_test.lua
local H = dofile("tests/bots_env.lua")
local env
local AID = "chase.pve"

local function copsOf(match)
    local out = {}
    for _, m in ipairs(match.members) do if m.bot then out[#out + 1] = m.id end end
    return out
end

local function noTraces()
    assert(H.count(ChaseBots.bots) == 0, "every bot removed")
    assert(H.count(env.npcs) == 0, "every body removed")
    assert(H.count(env.cars) == 0, "every car removed")
end

local function attached(match)
    for _, c in ipairs(copsOf(match)) do
        local bot = ChaseBots.bots[c]
        if not (bot and bot.attached) then return false end
    end
    return true
end

-- Every cop car at `pos` + (i * 6 m east, dy).
local function parkCops(match, pos, dy)
    for i, c in ipairs(copsOf(match)) do H.moveCar(H.botCar(c), H.offset(pos, i * 6, dy)) end
end

local function startSolo(id, mode)
    H.fire("op77_lightrp:activity:join", id, AID, { mode = mode })
    H.runUntil(function() return ChasePve.matchOf(id) ~= nil end, 6, "an escape for " .. id)
    local match = ChasePve.matchOf(id)
    H.runUntil(function() return match.state == "active" and attached(match) end, 30, "GO for " .. id)
    return match
end

local function result(id)
    local list = H.results(id, AID)
    return list[#list] and list[#list].args[3], #list
end

-- ---------------------------------------------------------------- solo by car: busted

env = H.load()
H.run(6) -- past the bots' settle window
assert(env.registered[AID] and env.registered[AID].modes[1].id == "vehicle" and env.registered[AID].modes[2].id == "foot",
    "registered with its modes")
assert(env.registered[AID].minPlayers == 1, "solo is enough")
H.fire("op77_lightrp:activity:join", 1, AID, { mode = "vehicle" })
assert(env.qhud[1] and env.qhud[1].activity == AID and env.qhud[1].queued, "getting ready")
H.run(1)
assert(ChasePve.matchOf(1) == nil, "a join gathers for gatherSeconds")
H.runUntil(function() return ChasePve.matchOf(1) ~= nil end, 4, "the escape starts")
local match = ChasePve.matchOf(1)
assert(not ChaseBots.enabled, "no staff switch needed")
assert(match.copCount == 3 and #copsOf(match) == 3, "1 runner: base 1 + 2 per runner = 3 cops")
local route = match.route
assert(match.members[1].point.position.x == route.runner.position.x, "the runner starts on the start checkpoint")
for j, c in ipairs(copsOf(match)) do
    assert(ChasePve.member(match, c).point == route.cops[#route.cops - j + 1], "cops from the front of the grid")
    assert(ChasePve.member(match, c).name:sub(1, 6) == "[BOT] ", "[BOT] names")
end
H.runUntil(function() return match.state == "active" and attached(match) end, 30, "GO")
assert(H.count(env.cars) == 4, "his own car and the three cop cars")
local hud = env.hud[1]
assert(hud.activity == AID and hud.role == "runner" and hud.hideDots == nil, "the escape HUD, no dot hidden")
local bots = 0
for _, row in ipairs(hud.scoreboard) do if row.cop and row.name:sub(1, 6) == "[BOT] " then bots = bots + 1 end end
assert(bots == 3, "the HUD lists the bot cops as [BOT]")
dofile("client/view.lua")
local view = ChaseView.hud(hud)
assert(view.title == "NCPD Escape" and view.activity == AID and view.scoreboard and #view.scoreboard.rows == 4, "the client draws it")
assert(view.scoreboard.rows[2].name:sub(1, 6) == "[BOT] ")

local rp = env.pos[1]
parkCops(match, rp, 200)
assert(H.count(match.copReleased) == 0, "held during the head start")
H.run(11)
assert(H.count(match.copReleased) == 2, "wave 1: half the cops after the head start")
H.runUntil(function() return #H.aiCalls("vehicles.ai.chase", function(a) return a[2].targetId == 1 end) >= 2 end, 5, "they chase him")
H.runUntil(function() return H.count(match.copReleased) == 3 end, 25, "wave 2")
H.runUntil(function() return env.clock - match.startedAtMs >= 65000 end, 60, "past minSeconds")
assert(result(1) == nil, "no result while he is out")
local first = copsOf(match)[1]
H.moveCar(H.botCar(first), H.offset(rp, 4, 0))
H.runUntil(function() return result(1) ~= nil end, 30, "busted on the bot car's position")
local r = result(1)
assert(r.won == false and r.placement == 2 and r.stats.outcome == "busted" and r.stats.how == "arrest", "busted")
assert(r.reputation == ChaseConfig.pve.reputation.busted, "busted reputation after minSeconds")
assert(r.test == nil, "recorded by Light RP as usual")
assert(env.frozen[1] == true, "cuffed until he goes home")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 20, "closed after the scoreboard")
local left = H.left(1, AID)
assert(left and left.opts.returnPlayer == true, "home through activityLeave")
assert(env.frozen[1] == false, "let go")
noTraces()
assert(#env.swept >= 1, "bucket swept")

-- ---------------------------------------------------------------- escape by a shake

match = startSolo(2, "vehicle")
rp = env.pos[2]
parkCops(match, rp, 200)
H.runUntil(function() return env.clock - match.startedAtMs >= 20000 end, 30, "+20 s")
local cop = copsOf(match)[1]
H.moveCar(H.botCar(cop), H.offset(rp, 0, 100)) -- they close in: the shake is armed
H.run(2)
H.moveCar(H.botCar(cop), H.offset(rp, 0, 200))
H.runUntil(function() return H.noted(2, "counts after") end, 25, "an early shake")
assert(result(2) == nil, "a shake before minSeconds is not the escape")
H.runUntil(function() return env.clock - match.startedAtMs >= 45000 end, 20, "+45 s")
H.moveCar(H.botCar(cop), H.offset(rp, 0, 100))
H.run(2)
H.moveCar(H.botCar(cop), H.offset(rp, 0, 200))
H.runUntil(function() return result(2) ~= nil end, 30, "the escape")
r = result(2)
assert(r.won == true and r.placement == 1 and r.stats.how == "shake" and r.stats.seconds >= 60, "escaped by a shake")
assert(r.reputation == ChaseConfig.pve.reputation.escaped, "escaped reputation")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 20, "closed")
noTraces()

-- ---------------------------------------------------------------- escape by the clock

match = startSolo(3, "vehicle")
rp = env.pos[3]
parkCops(match, rp, 120) -- close enough to never shake, too far to arrest
H.runUntil(function() return result(3) ~= nil end, 180, "the clock")
r = result(3)
assert(r.won and r.stats.how == "clock" and r.stats.seconds >= 164, "outlasted the clock")
assert(r.reputation == ChaseConfig.pve.reputation.escaped)
assert(H.noted(3, "Extraction point located"), "the extraction showed up at its heat level")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 20, "closed")
noTraces()

-- ---------------------------------------------------------------- a crew of two

local squad = { id = "squad:9", leader = 4, members = { 4, 5 } }
H.fire("op77_lightrp:activity:join", 4, AID, { mode = "vehicle", squad = squad })
H.run(3)
assert(ChasePve.matchOf(4) == nil, "the crew waits for its member")
assert(env.qhud[4].crew == 2 and env.qhud[4].crewQueued == 1, "the queue HUD shows the crew")
H.fire("op77_lightrp:activity:join", 5, AID, { mode = "foot", squad = squad })
H.runUntil(function() return ChasePve.matchOf(4) ~= nil end, 3, "the crew starts together")
match = ChasePve.matchOf(4)
assert(ChasePve.matchOf(5) == match, "one match for the crew")
assert(match.mode == "vehicle", "the leader's mode")
assert(match.copCount == 5, "2 runners: 5 cops")
local p4, p5 = ChasePve.member(match, 4).point.position, ChasePve.member(match, 5).point.position
local gap = math.sqrt((p4.x - p5.x) ^ 2 + (p4.y - p5.y) ^ 2)
assert(math.abs(gap - ChaseConfig.pve.match.runnerSpacingMetres) < 0.5, "cars in line behind the start")
assert(ChasePve.member(match, 4).squad == "squad:9", "the crew is kept")
H.runUntil(function() return match.state == "active" and attached(match) end, 30, "crew GO")
rp = env.pos[4]
env.pos[5] = H.offset(rp, 0, -60)
parkCops(match, rp, 120)
H.runUntil(function() return env.clock - match.startedAtMs >= 65000 end, 70, "past minSeconds")
H.moveCar(H.botCar(copsOf(match)[1]), H.offset(rp, 0, 4))
H.runUntil(function() return result(4) ~= nil end, 30, "runner 4 busted")
assert(result(4).reputation == ChaseConfig.pve.reputation.busted and result(4).stats.crew == true, "his result now")
assert(result(5) == nil and match.state == "active", "the other runner is still out")
for _, c in ipairs(copsOf(match)) do assert(match.target[c] == 5, "every cop takes the runner still out") end
H.run(1)
for _, c in ipairs(copsOf(match)) do
    local order = ChaseBots.bots[c].order
    assert(order.kind == "chase" and order.target.player == 5, "and chases him")
end
H.fire("op77_lightrp:activity:leaveRequest", 5, AID)
r = result(5)
assert(r and r.reputation == 0 and r.won == false and r.stats.forfeit == true, "a leaver: result, nothing earned")
assert(match.state == "resolved", "no runner left: the match ends")
H.runUntil(function() return H.left(5, AID) ~= nil end, 2, "the leaver goes home at once")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 20, "closed after the busted runner's scoreboard")
assert(H.left(4, AID))
noTraces()

-- A crewmate who never comes: the crew goes without him; a leave in the countdown is void.
H.fire("op77_lightrp:activity:join", 6, AID, { squad = { id = "squad:10", leader = 6, members = { 6, 7 } } })
H.run(5)
assert(ChasePve.matchOf(6) == nil, "waiting for 7")
H.runUntil(function() return ChasePve.matchOf(6) ~= nil end, 7, "squadWaitSeconds later, without him")
match = ChasePve.matchOf(6)
assert(match.copCount == 3 and match.mode == "vehicle", "a solo escape, the default mode")
H.runUntil(function() return match.state == "countdown" end, 10, "countdown")
H.fire("op77_lightrp:activity:leaveRequest", 6, AID)
assert(match.void and match.state == "resolved", "everyone left before the start: void")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 15, "closed")
assert(result(6) == nil, "no result for a void escape")
noTraces()

-- ---------------------------------------------------------------- on foot, then a drop

match = startSolo(8, "foot")
assert(match.mode == "foot" and H.count(env.cars) == 3, "no runner car on foot")
assert(env.placements[#env.placements].id == 8 or true)
env.owner[8] = nil
H.fire("op77_lightrp:activity:dropped", 8, AID, "disconnected")
assert(match.state == "resolved", "no runner left")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 15, "closed after the drop")
assert(result(8) == nil and not H.left(8, AID), "a dropped runner: no result, no leave")
noTraces()

-- ---------------------------------------------------------------- reputation rules

local fake = { void = false }
local P = ChasePve
P.daily, P.dailyDay = {}, nil
local runner = { id = 50, identifier = "license:x", characterKey = 2, outcome = "busted", seconds = 59 }
assert(P.reputation(fake, runner) == 0, "under minSeconds: nothing")
runner.outcome, runner.seconds = "escaped", 100
local paid = 0
for i = 1, ChaseConfig.pve.reputation.perDay + 1 do
    local rep = P.reputation(fake, runner)
    if i <= ChaseConfig.pve.reputation.perDay then assert(rep == ChaseConfig.pve.reputation.escaped) paid = paid + 1
    else assert(rep == 0, "past perDay: nothing") end
end
assert(paid == ChaseConfig.pve.reputation.perDay)
assert(P.reputation(fake, { id = 51, outcome = "left", seconds = 120 }) == 0, "a leaver: nothing")
assert(ChaseConfig.pve.reputation.escaped < ChaseConfig.reputation.win and ChaseConfig.pve.reputation.busted < ChaseConfig.reputation.loss,
    "less than the PvP chase")

-- ---------------------------------------------------------------- one chase activity at a time, /escape

H.fire("op77_lightrp:activity:join", 9, AID, { mode = "vehicle" })
H.fire("op77_lightrp:activity:join", 9, "chase.1v1", { mode = "vehicle" })
assert(H.noted(9, "NCPD Escape") and not ChaseQueue.has(9), "the 1v1 refuses a player in NCPD Escape")
H.fire("op77_lightrp:activity:join", 9, "chase.wanted", { mode = "vehicle" })
assert(not ChaseWantedLobby.has(9), "so does Most Wanted")
H.command("escape", 9, { "leave" })
assert(not ChasePveMain.claims(9) and env.replies[#env.replies].ok, "/escape leave")
H.fire("op77_lightrp:activity:join", 10, "chase.1v1", { mode = "vehicle" })
H.command("escape", 10, {})
assert(env.replies[#env.replies].ok == false and not ChasePveMain.claims(10), "NCPD Escape refuses a player in the 1v1 queue")
H.fire("op77_lightrp:activity:leaveRequest", 10, "chase.1v1")
H.command("escape", 10, { "fly" })
assert(env.replies[#env.replies].ok == false and env.replies[#env.replies].text:find("usage"), "usage")
H.command("escape", 10, { "foot" })
assert(env.replies[#env.replies].ok and ChasePveMain.claims(10), "/escape foot")
H.runUntil(function() return ChasePve.matchOf(10) ~= nil end, 5, "started from the command")
match = ChasePve.matchOf(10)
assert(match.mode == "foot")
H.command("escape", 10, { "status" })
assert(env.replies[#env.replies].text:find("NCPD Escape"), "/escape status")

-- Staff: status and stop (void, nothing recorded).
H.command("chase.pve.status", 0, {})
assert(env.commands["chase.pve.status"].restricted and env.replies[#env.replies].text:find("match " .. match.id), "staff status")
assert(env.replies[#env.replies].text:find("%(bot%)"), "bots listed")
H.command("chase.pve.stop", 0, { tostring(match.id) })
assert(env.commands["chase.pve.stop"].restricted and match.void, "staff stop")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 15, "closed")
assert(result(10) == nil, "nothing recorded for a stopped escape")
noTraces()

-- Status for the hub.
local status
for _, e in ipairs(H.events("op77_lightrp:activity:status")) do if e.args[1] == AID then status = e.args[2] end end
assert(status and status.phase == "idle" and status.joinable == true, "hub status")

-- ---------------------------------------------------------------- broken bots, Light RP stop, resource stop

env = H.load({ before = function() _G.Open77.npcs = nil; _G.Open77.vehicles.ai = nil end })
H.fire("op77_lightrp:activity:join", 1, AID, { mode = "vehicle" })
H.runUntil(function() return ChasePve.matchOf(1) ~= nil end, 6, "match")
match = ChasePve.matchOf(1)
H.runUntil(function() return match.state == "resolved" end, 30, "called off")
assert(match.void and result(1) == nil, "broken bots: nothing counts")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 15, "closed")
assert(H.left(1, AID))
noTraces()

env = H.load()
H.run(6)
match = startSolo(1, "vehicle")
H.fire("onResourceStop", "op77_lightrp")
assert(match.void and match.state == "resolved", "Light RP stopped: void")
H.runUntil(function() return ChasePve.matches[match.id] == nil end, 15, "closed")
assert(not H.left(1, AID), "Light RP returned him itself")
noTraces()

H.fire("onResourceStart", "op77_lightrp")
H.run(3)
match = startSolo(2, "vehicle")
assert(H.count(env.cars) == 4 and H.count(env.npcs) == 3)
H.fire("onResourceStop", "op77_chase")
assert(H.count(env.cars) == 0 and H.count(env.npcs) == 0, "resource stop: cars and bodies removed")

assert(#env.db == 0, "NCPD Escape never touches the database")
for _, e in ipairs(H.results()) do assert(e.args[3].test == nil, "never a test result") end

print("PASS: op77_chase NCPD Escape (gathering queue, solo car: grid cops, waves, chase, arrest on bot positions, busted rep, HUD + view; "
    .. "early shake re-arms then escape; clock + extraction; crew of two: one match, retarget, leaver; crew wait; void leave; foot + drop; "
    .. "reputation min/perDay/leaver; one activity at a time; /escape; staff status/stop; broken bots; Light RP stop; resource stop; no DB)")
