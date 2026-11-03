-- Staff bot mode in a street race: the switch (activityBots at registration, the bots
-- event, the core stopping), one player opening a grid that bots fill, bots held then
-- released with a route, progress and finish from the car's position, the route handed
-- again, stuck bots re-tasked then out, a bot far ahead waiting without being stuck,
-- test results and no record, and the bots going with the race.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 3 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(11)
H.core.bots = true -- the core had bot mode on before we registered
H.load(H.SERVER)
local E, L, A, Config = RaceEngine, RaceLobby, RaceActivity, RaceConfig

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function frozen(vehicleId) return (H.vehicles[vehicleId].flags & Open77.vehicles.flags.frozen) ~= 0 end
local function results(id)
    local found = {}
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if id == nil or event.args[1] == id then found[#found + 1] = event.args[3] end
    end
    return found
end
-- Puts a bot's car on its next checkpoint and lets the tick see it.
local function stepBot(inst, bot)
    local cp = inst.course.checkpoints[bot.nextCheckpoint].position
    H.placeVehicle(bot.vehicleId, cp.x, cp.y, cp.z)
    H.advance(600)
end
local function stepPlayer(id)
    local inst, r = instance(id), racer(id)
    local cp = inst.course.checkpoints[r.nextCheckpoint].position
    H.drive(id, cp.x, cp.y, cp.z)
    H.advance(600)
end

H.test("bot mode is read at registration and follows the core's event", function()
    H.ok(A.registered, "registered")
    H.ok(#H.coreCalls("activityBots") >= 1, "activityBots asked after activityRegister")
    H.eq(A.bots, true, "on from the start")
    H.fire("op77_lightrp:activity:bots", false)
    H.eq(A.bots, false)
    H.fire("op77_lightrp:activity:bots", true)
    H.eq(A.bots, true)
    -- the core stops: off; it comes back and is asked again after registering
    H.fire("onResourceStop", "op77_lightrp")
    H.eq(A.bots, false, "a stopped core means off")
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.ok(A.registered and A.bots == true, "read back after the new registration")
    H.command("race.status", 0, {})
    H.ok(H.logged("bot mode ON"), "race.status says so")
end)

local inst, bots, goAt
H.test("one player opens the street grid; bots fill it on loaner cars, held, in the bucket", function()
    H.fireNet("op77_race:join", 1, { activity = "grid" })
    H.advance(200)
    H.ok(L.windowRemainingMs("grid") ~= nil, "the window opens for one player")
    H.ok(H.noticeFor(1, "bots fill the grid"))
    local lobby = H.lastClient("op77_race:queue", 1).args[1]
    H.eq(lobby.minPlayers, 1); H.eq(lobby.bots, true)
    H.advance(Config.activities[2].joinSeconds * 1000 + 500)
    inst = instance(1)
    H.ok(inst, "started")
    bots = inst.bots
    H.eq(#inst.members, 1)
    H.eq(#bots, Config.bots.fillTo.grid - 1, "filled up to fillTo")
    H.ok(inst.hadBots)
    H.ok(H.noticeFor(1, "Bot mode: 3 bots on the grid"))
    local mine = H.vehicles[racer(1).vehicleId]
    for index, bot in ipairs(bots) do
        local car = H.vehicles[bot.vehicleId]
        H.ok(car and car.bucket == inst.bucket, "bot car in the race bucket")
        H.ok(frozen(bot.vehicleId), "held on the grid")
        H.ok(RaceShared.distance(car, mine) > 2, "on its own slot")
        H.eq(bot.slotIndex, index + 1, "the slots behind the player")
        local npc = H.npcs[bot.npcId]
        H.ok(npc and npc.bucket == inst.bucket, "driver in the race bucket")
        H.eq(npc.damagePolicy, Open77.npcs.damage.invulnerable)
        H.eq(npc.aiMode, Open77.npcs.ai.tasks)
        H.eq(npc.behavior.combatEnabled, false)
        local ai = H.ai[bot.vehicleId]
        H.ok(ai and ai.npcId == bot.npcId, "the driver is attached")
        H.eq(ai.behavior, "aggressive"); H.eq(ai.speed, Config.bots.car.speed)
        H.ok(bot.name:find("^%[BOT%] "), "marked in its name")
        H.eq(#ai.routes, 0, "no route before GO")
    end
    local state = H.lastClient("op77_race:state", 1).args[1]
    H.eq(state.racers, 4); H.eq(state.bots, 3)
    H.ok(state.rows and state.rows:find("%[BOT%] "), "bots in the ranking")
end)

H.test("GO releases the bots with a route along the checkpoints", function()
    H.advance(Config.engine.loadSeconds.grid * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.eq(inst.phase, "active")
    goAt = inst.startedAt
    for _, bot in ipairs(bots) do
        H.eq(bot.state, "racing")
        H.ok(not frozen(bot.vehicleId), "released")
        local route = H.ai[bot.vehicleId].route
        local cp1 = inst.course.checkpoints[1].position
        H.ok(route and math.abs(route.points[1].x - cp1.x) < 1e-6, "starts at checkpoint 1")
        H.eq(#route.points, math.min(Config.bots.car.routePoints, #inst.course.checkpoints), "a stretch of the course")
        H.eq(route.loop, false); H.eq(route.behavior, "aggressive"); H.eq(route.speed, Config.bots.car.speed)
    end
end)

H.test("a stuck bot is re-tasked, then out and removed; a bot far ahead waits without being stuck", function()
    Config.bots.stuckSeconds = 5
    local leader, stuck, far = bots[1], bots[2], bots[3]
    H.ai[far.vehicleId].status = "waiting_for_simulator"
    local stuckCar, stuckNpc = stuck.vehicleId, stuck.npcId
    for _ = 1, 9 do stepBot(inst, leader) end
    H.eq(#H.ai[stuckCar].routes, 2, "first re-task")
    H.ok(H.ai[stuckCar].stops >= 1, "stopped before the new route")
    for _ = 1, 9 do stepBot(inst, leader) end
    H.eq(#H.ai[stuckCar].routes, 3, "second re-task")
    for _ = 1, 9 do stepBot(inst, leader) end
    H.eq(stuck.state, "dnf"); H.eq(stuck.dnfReason, "stuck")
    H.eq(H.vehicles[stuckCar], nil, "its car is removed"); H.eq(H.npcs[stuckNpc], nil, "and its driver")
    H.eq(far.state, "racing", "waiting for a simulator is not being stuck")
    H.eq(#H.ai[far.vehicleId].routes, 1)
    -- a failed driving task is re-tasked at once
    H.aiEvent("failed", far.vehicleId, { reason = "no_route" })
    H.advance(200)
    H.eq(#H.ai[far.vehicleId].routes, 2, "re-tasked on failure")
    H.ai[far.vehicleId].status = "waiting_for_simulator"
    local row
    for _, r in ipairs(E.rows(inst)) do if r.id == stuck.id then row = r end end
    H.eq(row.state, "dnf", "still ranked, out")
end)

H.test("the route is handed again before it runs out; the bot leads and finishes first", function()
    local leader = bots[1]
    local routes = H.ai[leader.vehicleId].routes
    H.ok(#routes >= 2, "a second stretch")
    local second = routes[2].points[1]
    local expected = inst.course.checkpoints[Config.bots.car.routePoints - Config.bots.car.routeRefill + 1].position
    H.ok(math.abs(second.x - expected.x) < 1e-6, "it starts at the next checkpoint to validate")
    H.eq(E.rows(inst)[1].id, leader.id, "the bot leads the ranking")
    while leader.state == "racing" do stepBot(inst, leader) end
    H.eq(leader.state, "finished"); H.eq(leader.finishPlace, 1)
    H.ok(leader.timeMs > 0)
    local last = H.ai[leader.vehicleId].route.points
    local finishCp = inst.course.checkpoints[#inst.course.checkpoints].position
    H.ok(RaceShared.distance(last[#last], finishCp) > 10, "the last stretch rolls on past the line")
    H.eq(H.ai[leader.vehicleId].speed, Config.bots.car.cooldownSpeed, "slowly")
    H.ok(H.noticeFor(1, "seconds to cross the line"), "the leader's finish opens the window for the player")
    H.eq(#results(), 0, "a bot never sends a result")
end)

H.test("the player finishes behind it: a test result, no reputation, bots counted, no record", function()
    while racer(1).state == "racing" do stepPlayer(1) end
    H.eq(racer(1).finishPlace, 2)
    local result = results(1)[1]
    H.ok(result, "the player's result")
    H.eq(result.test, true, "flagged as a test")
    H.eq(result.reputation, 0); H.eq(result.placement, 2); H.eq(result.won, false)
    H.eq(result.stats.bots, 3); H.eq(result.stats.racers, 4)
    -- the board for Light RP's end-of-match recap, as it stands at the line
    local board = result.recap
    H.ok(board and board.matchId == "race:" .. inst.id .. "@" .. inst.startedAt, "one id for the race")
    H.eq(#board.rows, 4, "the player and the three bots")
    H.eq(board.rows[1].bot, true); H.ok(board.rows[1].id < 0, "a bot's id is negative"); H.eq(board.rows[1].placement, 1)
    H.eq(board.rows[2].id, 1); H.eq(board.rows[2].placement, 2); H.ok(board.rows[2].timeMs > 0)
    H.eq(board.rows[2].bot, nil)
    H.eq(board.lines[1].label, "Course")
    H.eq(inst.phase, "active", "a bot still racing in front of the finished player")
    H.eq(H.files["records.json"], nil, "no best time written")
end)

H.test("results end: every bot, car and driver is gone with the instance", function()
    -- the window opened at the bot's finish; part of it went by while the player drove
    local guard = 0
    while inst.phase == "active" and guard < 400 do H.advance(250); guard = guard + 1 end
    H.eq(inst.phase, "results", "the window closes the race")
    H.eq(bots[3].state, "dnf")
    -- the final board, sent once at resolve, with the bots that did not finish
    local finals = H.eventsNamed("op77_lightrp:activity:recap")
    H.eq(#finals, 1, "one final board")
    local final = finals[1].args[2]
    H.eq(finals[1].args[1], "race.grid")
    H.eq(final.matchId, "race:" .. inst.id .. "@" .. inst.startedAt)
    local dnf = 0
    for _, row in ipairs(final.rows) do if row.outcome == "dnf" then dnf = dnf + 1; H.eq(row.bot, true) end end
    H.ok(dnf >= 1, "a bot out of time is a DNF")
    H.ok(final.durationMs > 0)
    H.advance(Config.engine.resultsSeconds.grid * 1000 + 3000)
    H.eq(racer(1), nil)
    H.eq(H.count(E.instances), 0)
    H.eq(H.count(H.vehicles), 0); H.eq(H.count(H.npcs), 0); H.eq(H.count(H.ai), 0)
    H.eq(H.count(RaceBots.byVehicle), 0)
    H.eq(#results(1), 1, "one result")
    Config.bots.stuckSeconds = 20
end)

H.test("bot mode off: a lone player waits again; on then off closes the window and says why", function()
    H.fire("op77_lightrp:activity:bots", false)
    H.fireNet("op77_race:join", 2, { activity = "grid" })
    H.advance(500)
    H.eq(L.windowRemainingMs("grid"), nil, "two players needed again")
    H.ok(H.noticeFor(2, "Waiting for 1 more"))
    H.fire("op77_lightrp:activity:bots", true)
    H.advance(500)
    H.ok(L.windowRemainingMs("grid") ~= nil, "bot mode opens it")
    H.fire("op77_lightrp:activity:bots", false)
    H.advance(500)
    H.eq(L.windowRemainingMs("grid"), nil)
    H.ok(H.noticeFor(2, "Bot mode is off"))
    H.fireNet("op77_race:leave", 2)
    H.eq(L.size("grid"), 0)
end)

H.test("a running race keeps its bots when bot mode goes off; the last player leaving removes them", function()
    H.fire("op77_lightrp:activity:bots", true)
    H.advance(500) -- past the request throttle of the leave just above
    H.fireNet("op77_race:join", 2, { activity = "grid" })
    H.command("race.force", 0, { "street" })
    local race = instance(2)
    H.ok(race and #race.bots == 3, "forced, filled")
    H.fire("op77_lightrp:activity:bots", false)
    H.advance(500)
    H.eq(#race.bots, 3, "still there")
    H.fire("op77_lightrp:activity:leaveRequest", 2, "race.grid")
    H.advance(3000)
    H.eq(racer(2), nil)
    H.eq(H.count(H.npcs), 0); H.eq(H.count(H.vehicles), 0)
end)

H.test("the time trial never gets bots", function()
    H.fire("op77_lightrp:activity:bots", true)
    H.fireNet("op77_race:join", 3, { activity = "trial" })
    local trial = instance(3)
    H.ok(trial and trial.mode == "trial")
    H.eq(trial.bots, nil); H.eq(E.fieldSize(trial), 1)
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.trial")
    H.advance(3000)
end)

H.test("resource stop: bots and cars removed at once", function()
    H.fireNet("op77_race:join", 1, { activity = "grid" })
    H.command("race.force", 0, { "street" })
    H.ok(instance(1) and #instance(1).bots == 3)
    H.ok(H.count(H.npcs) == 3)
    H.fire("onResourceStop", "op77_race")
    H.eq(H.count(H.npcs), 0, "drivers removed")
    H.eq(H.count(H.vehicles), 0, "cars removed")
end)

H.done("bots_test")
