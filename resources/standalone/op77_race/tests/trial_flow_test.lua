-- Time trial end to end against the contract stub: join -> enter -> loaner car in a
-- race bucket -> countdown -> GO -> checkpoints -> finish -> result -> return. Plus
-- restart, leave request, dropped, disconnect and the core stopping mid-race.
local H = dofile("tests/harness.lua")
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
H.addPlayer(1, "Ann", LOBBY)
H.load(H.SERVER)
local E, Config = RaceEngine, RaceConfig

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function count(map) local n = 0; for _ in pairs(map) do n = n + 1 end return n end

-- Drives through every remaining checkpoint of the racer's course, one per 600 ms.
local function driveAll(id, limit)
    local inst = instance(id)
    local done = 0
    while racer(id) and racer(id).state == "racing" and (limit == nil or done < limit) do
        local cp = inst.course.checkpoints[racer(id).nextCheckpoint]
        H.drive(id, cp.position.x, cp.position.y, cp.position.z)
        H.advance(600)
        done = done + 1
    end
end

local function toGo(id)
    H.advance(5000)
    H.eq(instance(id).phase, "countdown", "countdown after the loading window")
    H.advance(3200)
    H.eq(racer(id).state, "racing", "GO")
end

H.test("registers the three activities with the core at start", function()
    H.ok(RaceActivity.registered)
    H.ok(H.core.registered["race.trial"] and H.core.registered["race.grid"] and H.core.registered["race.foot"])
    local status = H.eventsNamed("op77_lightrp:activity:status")
    H.ok(#status >= 3, "initial status for each activity")
end)

H.test("join: entered through the core, loaner car held in a race bucket", function()
    H.fire("op77_lightrp:activity:join", 1, "race.trial", { course = "street-circuit" })
    H.eq(#H.coreCalls("activityEnter", 1), 1, "activityEnter called")
    H.eq(H.core.owner[1], "race.trial")
    local inst = instance(1)
    H.ok(inst, "instance")
    H.ok(inst.bucket >= 4200000 and inst.bucket <= 4299999, "bucket in the race range")
    local create = H.vehicleLog[1]
    H.eq(create.op, "create")
    H.eq(create.spec.bucket, inst.bucket, "car created in the instance bucket")
    H.eq(create.spec.record, "Vehicle.v_sport1_rayfield_caliburn_player", "the course's loaner")
    H.ok(H.vehicles[create.id].flags & Open77.vehicles.flags.frozen ~= 0, "held on the grid")
    H.eq(H.seats[1].seat, "seat_front_left")
    H.ok(H.seats[1].exitLocked, "exit locked")
    H.eq(H.players[1].bucket, inst.bucket, "player moved with the car")
    H.ok(H.players[1].godMode, "protected")
    H.ok(H.lastClient("op77_loadscreen:cover", 1), "loading cover")
    H.ok(H.lastClient("op77_race:state", 1), "state pushed")
end)

H.test("countdown, then GO releases the hold", function()
    toGo(1)
    local vehicleId = racer(1).vehicleId
    H.eq(H.vehicles[vehicleId].flags & Open77.vehicles.flags.frozen, 0, "hold released")
    H.ok(H.lastClient("op77_race:pulse", 1).args[1].kind == "go")
    H.ok(H.lastClient("op77_loadscreen:release", 1), "cover lifted at the countdown")
end)

H.test("checkpoints in order only; a skipped one does not count", function()
    local inst = instance(1)
    local third = inst.course.checkpoints[3].position
    H.drive(1, third.x, third.y, third.z)
    H.advance(600)
    H.eq(racer(1).completed, 0, "checkpoint 3 before 1 does not count")
    driveAll(1, 2)
    H.eq(racer(1).completed, 2)
    H.eq(racer(1).nextCheckpoint, 3)
end)

H.test("finish: result to the core with time, placement and reputation; best time stored", function()
    driveAll(1)
    local r = racer(1)
    H.eq(r.state, "finished")
    local results = H.eventsNamed("op77_lightrp:activity:result")
    H.eq(#results, 1, "one result")
    local playerId, activityId, result = results[1].args[1], results[1].args[2], results[1].args[3]
    H.eq(playerId, 1); H.eq(activityId, "race.trial")
    H.eq(result.placement, 1); H.eq(result.won, true)
    H.eq(result.stats.courseId, "street-circuit")
    H.ok(result.stats.timeMs > 0 and result.stats.timeMs == r.timeMs, "time")
    H.eq(result.stats.checkpoints, 44)
    H.eq(result.stats.personalBest, true); H.eq(result.stats.courseRecord, true)
    H.eq(result.reputation, Config.rewards.trialFinish + Config.rewards.personalBest + Config.rewards.courseRecord)
    H.eq(result.cash, nil); H.eq(result.items, nil)
    H.ok(RaceRecords.best("street-circuit", instance(1).course.revision, "license:1/char1"), "best time on the board")
    H.eq(instance(1).phase, "results")
end)

H.test("after the results: car out and removed, protections off, back through the core", function()
    local vehicleId = racer(1).vehicleId
    H.advance(Config.engine.resultsSeconds.trial * 1000 + 3000)
    H.eq(racer(1), nil, "racer released")
    H.eq(H.vehicles[vehicleId], nil, "loaner removed")
    local exited = false
    for _, entry in ipairs(H.vehicleLog) do if entry.op == "exit" and entry.id == vehicleId then exited = true end end
    H.ok(exited, "forced out before removal")
    H.eq(H.players[1].godMode, false, "god mode restored")
    local leave = H.coreCalls("activityLeave", 1)
    H.eq(#leave, 1); H.eq(leave[1].args[3].returnPlayer, true)
    H.eq(H.players[1].bucket, 0, "back in the open world")
    H.eq(count(E.instances), 0, "instance closed")
    H.ok(H.lastClient("op77_race:clear", 1), "HUD cleared")
end)

H.test("restart: a fresh run and car without leaving the activity", function()
    H.fireNet("op77_race:join", 1, { activity = "trial", course = "street-circuit" })
    H.eq(#H.coreCalls("activityCheck", 1), 1, "our own entry point checks eligibility")
    toGo(1)
    driveAll(1, 5)
    local firstCar = racer(1).vehicleId
    H.advance(1100)
    H.fireNet("op77_race:restart", 1)
    H.advance(1600)
    H.eq(H.vehicles[firstCar], nil, "old car removed")
    H.eq(instance(1).run, 2)
    H.ok(racer(1).vehicleId ~= firstCar, "new car")
    H.eq(racer(1).completed, 0, "progress reset")
    H.advance(3000)
    H.advance(3200)
    H.eq(racer(1).state, "racing")
    driveAll(1)
    local results = H.eventsNamed("op77_lightrp:activity:result")
    H.eq(#results, 2, "the abandoned run sent nothing, the finished one a result")
    H.eq(#H.coreCalls("activityLeave", 1), 1, "never left the activity")
end)

H.test("leave request from the core mid-run: forfeit, no result, returned", function()
    H.fireNet("op77_race:restart", 1)
    H.advance(5000)
    H.advance(3200)
    H.eq(racer(1).state, "racing")
    driveAll(1, 3)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.trial")
    H.advance(3000)
    H.eq(racer(1), nil)
    H.eq(#H.eventsNamed("op77_lightrp:activity:result"), 2, "an unfinished trial sends no result")
    H.eq(#H.coreCalls("activityLeave", 1), 2)
    H.eq(H.players[1].bucket, 0)
    H.eq(count(H.vehicles), 0)
end)

H.test("dropped: clean up only, never activityLeave", function()
    H.fire("op77_lightrp:activity:join", 1, "race.trial", {})
    H.advance(1000)
    H.core.owner[1] = nil -- the core released the player itself
    H.fire("op77_lightrp:activity:dropped", 1, "race.trial", "character_switch")
    H.advance(3000)
    H.eq(racer(1), nil)
    H.eq(#H.coreCalls("activityLeave", 1), 2, "no new activityLeave")
    H.eq(count(H.vehicles), 0, "car removed")
    H.eq(H.players[1].godMode, false)
end)

H.test("disconnect: car removed at once, instance closed", function()
    H.fire("op77_lightrp:activity:join", 1, "race.trial", {})
    H.advance(1000)
    H.fire("onPlayerDisconnected", "1")
    H.advance(100)
    H.eq(racer(1), nil)
    H.eq(count(H.vehicles), 0)
    H.eq(count(E.instances), 0)
end)

H.test("the core stops mid-race: racers sent back by us, registered again on its return", function()
    H.addPlayer(1, "Ann", LOBBY)
    H.core.owner[1] = nil
    H.fire("op77_lightrp:activity:join", 1, "race.trial", {})
    H.advance(1000)
    H.ok(H.players[1].bucket >= 4200000)
    local before = #H.coreCalls("activityLeave", 1)
    exports.op77_lightrp = nil -- a stopped resource's exports raise
    H.fire("onResourceStop", "op77_lightrp")
    H.advance(4000)
    H.eq(racer(1), nil)
    H.eq(H.players[1].bucket, 0, "fallback return to the captured point")
    H.ok(math.abs(H.players[1].x - LOBBY.x) < 0.01, "where they stood")
    H.eq(#H.coreCalls("activityLeave", 1), before, "no activityLeave to a stopped core")
    H.ok(not RaceActivity.registered)
    local registrations = #H.coreCalls("activityRegister")
    exports.op77_lightrp = H.coreExports
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.ok(RaceActivity.registered)
    H.eq(#H.coreCalls("activityRegister"), registrations + #RaceConfig.activities)
end)

H.test("an ineligible player is told why and nothing starts", function()
    H.core.eligible[1] = "You are in a vehicle."
    H.fireNet("op77_race:join", 1, { activity = "trial" })
    H.eq(racer(1), nil)
    H.ok(H.noticeFor(1, "You are in a vehicle"), "sentence relayed")
    H.core.eligible[1] = nil
end)

H.test("a player id below 1 never reaches the runtime", function()
    H.fire("op77_lightrp:activity:join", 0, "race.trial", {})
    H.fire("op77_lightrp:activity:join", "abc", "race.trial", {})
    H.command("race", 0, {})
    H.eq(H.lastClient("op77_race:activities", 0), nil)
    H.command("timetrial", 0, {})
end)

H.test("a dead driver is out of the run and revived before going back", function()
    H.fire("op77_lightrp:activity:join", 1, "race.trial", { course = "shion-sprint" })
    toGo(1)
    H.players[1].life = "dead"
    H.fire("onPlayerLifeStateChanged", "1")
    H.advance(3500)
    H.eq(racer(1), nil)
    H.eq(H.players[1].life, "alive", "respawned before activityLeave")
    H.eq(H.players[1].bucket, 0)
end)

H.test("the Activities panel offers the trial's courses; the choice comes back as options.course", function()
    local def = H.core.registered["race.trial"]
    H.eq(def.modeKey, "course")
    H.ok(type(def.modes) == "table" and #def.modes >= 1 and #def.modes <= 8, "one to eight course choices")
    for _, mode in ipairs(def.modes) do
        local course = RaceCourses.get(mode.id)
        H.ok(course and RaceCourses.eligible(course, "trial"), mode.id .. " is a trial course")
        H.eq(mode.label, course.name)
    end
    local chosen = def.modes[#def.modes].id
    H.fire("op77_lightrp:activity:join", 1, "race.trial", { course = chosen, from = "panel" })
    H.eq(instance(1).course.id, chosen)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.trial")
    H.advance(4000)
    H.eq(racer(1), nil)
end)

H.done("trial_flow_test")
