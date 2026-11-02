-- Street race and rooftop race: queue, join window, re-check at launch, grid of
-- loaner cars, ranking, finish window, DNF, results for every starter; runners held
-- on the line, revived at their last checkpoint, sent back to it on request.
local H = dofile("tests/harness.lua")
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 4 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(7)
H.load(H.SERVER)
local E, L, Config = RaceEngine, RaceLobby, RaceConfig

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function count(map) local n = 0; for _ in pairs(map) do n = n + 1 end return n end
local function step(id)
    local inst, r = instance(id), racer(id)
    local cp = inst.course.checkpoints[r.nextCheckpoint]
    H.drive(id, cp.position.x, cp.position.y, cp.position.z)
end
local function resultFor(id)
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == id then return event.args[3], event.args[2] end
    end
end

H.test("street race: one queued player waits, the second opens the join window", function()
    H.fireNet("op77_race:join", 1, { activity = "grid" })
    H.eq(L.size("grid"), 1)
    H.advance(1000)
    H.eq(L.windowRemainingMs("grid"), nil, "no window below the minimum")
    H.ok(H.noticeFor(1, "Waiting for 1 more"))
    H.eq(H.core.owner[1], nil, "queued players are not owned yet")
    H.fireNet("op77_race:join", 2, { activity = "grid" })
    H.fireNet("op77_race:join", 3, { activity = "grid" })
    H.advance(200)
    H.ok(L.windowRemainingMs("grid") > 25000, "join window open")
    local status = H.eventsNamed("op77_lightrp:activity:status")
    local last = status[#status]
    H.ok(last.args[1] == "race.grid" and last.args[2].phase == "lobby" and last.args[2].queued == 3, "lobby status")
end)

H.test("launch: everyone re-checked; the ineligible one is told and left out", function()
    H.core.eligible[3] = "You are in a vehicle."
    H.advance(Config.activities[2].joinSeconds * 1000)
    H.core.eligible[3] = nil
    H.ok(H.noticeFor(3, "You are in a vehicle%. You left the queue%."))
    H.eq(L.size("grid"), 0)
    local inst = instance(1)
    H.ok(inst and inst == instance(2), "one instance for both")
    H.eq(racer(3), nil)
    H.eq(#inst.members, 2)
    H.ok(not RaceShared.onFoot(inst.course), "a vehicle course")
    H.eq(H.core.owner[1], "race.grid"); H.eq(H.core.owner[2], "race.grid")
    local a, b = H.vehicles[racer(1).vehicleId], H.vehicles[racer(2).vehicleId]
    H.ok(a and b and a.bucket == inst.bucket and b.bucket == inst.bucket, "two loaners in the bucket")
    H.ok(RaceShared.distance(a, b) > 2, "on different grid slots")
end)

H.test("a second street race runs at the same time in another bucket", function()
    H.fireNet("op77_race:join", 3, { activity = "grid" })
    H.fireNet("op77_race:join", 4, { activity = "grid" })
    H.advance(Config.activities[2].joinSeconds * 1000 + 500)
    H.ok(instance(3) and instance(3) ~= instance(1), "separate instance")
    H.ok(instance(3).bucket ~= instance(1).bucket, "separate bucket")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.grid")
    H.fire("op77_lightrp:activity:leaveRequest", 4, "race.grid")
    H.advance(3000)
    H.eq(racer(3), nil); H.eq(racer(4), nil)
    H.eq(H.players[3].bucket, 0)
end)

H.test("GO, live ranking, leader finishes, the finish window ends the race", function()
    H.advance(20000)
    local inst = instance(1)
    H.eq(inst.phase, "active", "racing")
    H.eq(racer(1).state, "racing"); H.eq(racer(2).state, "racing")
    for _ = 1, 3 do step(1); step(2); H.advance(600) end
    step(1); H.advance(600)
    local rows = E.rows(inst)
    H.eq(rows[1].id, 1, "player 1 leads on progress")
    while racer(1).state == "racing" do step(1); H.advance(600) end
    H.eq(racer(1).finishPlace, 1)
    local result = resultFor(1)
    H.ok(result, "the winner's result leaves at the line")
    H.eq(result.placement, 1); H.eq(result.won, true)
    H.eq(result.reputation, Config.rewards.heatFinish + Config.rewards.placement[1])
    H.eq(result.stats.racers, 2)
    H.ok(H.noticeFor(2, "seconds to cross the line"), "finish window announced")
    H.advance(Config.engine.finishGraceSeconds * 1000 + 500)
    H.eq(inst.phase, "results")
    H.eq(racer(2).state, "dnf")
    local loser = resultFor(2)
    H.ok(loser, "a result for every starter")
    H.eq(loser.placement, nil); H.eq(loser.won, false); H.eq(loser.reputation, 0)
    H.eq(loser.stats.finished, false); H.eq(loser.stats.dnfReason, "finish_window_expired")
end)

H.test("results end: both cars removed, both players returned through the core", function()
    H.advance(Config.engine.resultsSeconds.grid * 1000 + 3000)
    H.eq(racer(1), nil); H.eq(racer(2), nil)
    H.eq(count(H.vehicles), 0)
    H.eq(H.players[1].bucket, 0); H.eq(H.players[2].bucket, 0)
    H.eq(H.core.owner[1], nil); H.eq(H.core.owner[2], nil)
    H.eq(count(E.instances), 0)
end)

H.test("staff can force a street race with one player", function()
    H.fireNet("op77_race:join", 1, { activity = "grid" })
    H.command("race.force", 0, { "street" })
    H.ok(instance(1), "started below the minimum")
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.grid")
    H.advance(3000)
    H.eq(racer(1), nil)
end)

H.test("rooftop race: runners teleported into the bucket and held until GO", function()
    H.fireNet("op77_race:join", 1, { activity = "foot" })
    H.fireNet("op77_race:join", 2, { activity = "foot" })
    H.advance(Config.activities[3].joinSeconds * 1000 + 1000)
    local inst = instance(1)
    H.ok(inst and RaceShared.onFoot(inst.course), "foot course")
    H.eq(H.players[1].bucket, inst.bucket); H.eq(H.players[2].bucket, inst.bucket)
    H.ok(H.players[1].frozen and H.players[2].frozen, "held on the line")
    local tp = H.teleports[#H.teleports]
    H.eq(tp.opts.bucket, inst.bucket); H.eq(tp.opts.dismount, true)
    H.eq(count(H.vehicles), 0, "no car on foot")
    H.advance(8000)
    H.eq(inst.phase, "active")
    H.ok(not H.players[1].frozen and not H.players[2].frozen, "released at GO")
end)

H.test("a runner who dies is revived at the last checkpoint, clock running", function()
    local inst = instance(1)
    step(1); H.advance(600); step(1); H.advance(600)
    H.eq(racer(1).completed, 2)
    H.players[1].life = "dead"
    H.fire("onPlayerLifeStateChanged", "1")
    H.advance(1000)
    local respawn = H.respawns[#H.respawns]
    H.eq(respawn.id, 1)
    local cp2 = inst.course.checkpoints[2].position
    H.ok(math.abs(respawn.opts.position.x - cp2.x) < 1e-6, "at checkpoint 2")
    H.eq(respawn.opts.bucket, inst.bucket, "inside the race bucket")
    H.eq(racer(1).state, "racing"); H.eq(racer(1).completed, 2, "progress kept")
end)

H.test("back to the last checkpoint on request", function()
    local inst = instance(2)
    step(2); H.advance(600)
    H.drive(2, 0, 0, 0)
    H.advance(2100)
    H.fireNet("op77_race:respawn", 2)
    H.advance(400)
    local cp1 = inst.course.checkpoints[1].position
    H.ok(math.abs(H.players[2].x - cp1.x) < 1e-6, "teleported to checkpoint 1")
    H.eq(H.players[2].bucket, inst.bucket)
end)

H.test("a car in a foot race disqualifies", function()
    H.seats[2] = { vehicleId = 99, seat = "seat_front_left" }
    H.advance(300)
    H.eq(racer(2) and racer(2).state or "released", racer(2) and "dnf" or "released")
    H.seats[2] = nil
    H.advance(3000)
    H.eq(racer(2), nil)
    H.eq(H.players[2].bucket, 0)
end)

H.test("the last runner finishing resolves the race", function()
    while racer(1) and racer(1).state == "racing" do step(1); H.advance(600) end
    H.eq(racer(1).state, "finished")
    H.eq(instance(1).phase, "results", "nobody left racing")
    local result = resultFor(1)
    H.eq(result.placement, 1)
    H.advance(Config.engine.resultsSeconds.foot * 1000 + 3000)
    H.eq(racer(1), nil)
    H.eq(count(E.instances), 0)
end)

H.test("leaving a queue, and status back to idle", function()
    H.fireNet("op77_race:join", 4, { activity = "foot" })
    H.eq(L.size("foot"), 1)
    H.advance(400)
    H.fireNet("op77_race:leave", 4)
    H.eq(L.size("foot"), 0)
    H.advance(2500)
    local last
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:status")) do
        if event.args[1] == "race.foot" then last = event.args[2] end
    end
    H.eq(last.phase, "idle"); H.eq(last.queued, 0)
end)

H.done("heat_flow_test")
