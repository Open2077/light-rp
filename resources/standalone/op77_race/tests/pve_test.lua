-- Street Race vs AI (race.pve), open to every player without the staff switch: the
-- course chosen like the trial's, AI drivers filling the grid at once, a real result
-- (no test flag) with the lower vs-AI reputation, nothing below the minimum time or
-- length, the separate vs-AI best kept off the time trial's board, and a refusal
-- when the server cannot put AI on the grid.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 3 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(23)
H.load(H.SERVER)
local E, L, A, Config = RaceEngine, RaceLobby, RaceActivity, RaceConfig
local pve = A.byKey.pve
Config.bots.stuckSeconds = 600 -- the AI drivers stay in the race while the player takes their time

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function resultsFor(id)
    local found = {}
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == id then found[#found + 1] = event.args[3] end
    end
    return found
end
local function stepPlayer(id)
    local inst, r = instance(id), racer(id)
    local cp = inst.course.checkpoints[r.nextCheckpoint].position
    H.drive(id, cp.x, cp.y, cp.z)
    H.advance(600)
end
local function toGo(inst)
    H.advance(Config.engine.loadSeconds.pve * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.eq(inst.phase, "active")
end
local function toClosed(id)
    local guard = 0
    while racer(id) ~= nil and guard < 800 do H.advance(250); guard = guard + 1 end
    H.eq(racer(id), nil, "the race closed")
end
-- One race vs AI for player 1: waits `waitMs` after GO, then drives every checkpoint.
local function race(course, waitMs)
    H.fire("op77_lightrp:activity:join", 1, "race.pve", { course = course })
    local inst = instance(1)
    H.ok(inst, "started at once")
    toGo(inst)
    if waitMs and waitMs > 0 then H.advance(waitMs) end
    while racer(1).state == "racing" do stepPlayer(1) end
    local results = resultsFor(1)
    local result = results[#results]
    toClosed(1)
    return inst, result
end

H.test("registered as its own activity: one player, the courses as choices", function()
    local def = H.core.registered["race.pve"]
    H.ok(def, "race.pve registered")
    H.eq(def.label, "Street Race vs AI"); H.eq(def.minPlayers, 1)
    H.eq(def.modeKey, "course")
    local ids = {}
    for _, mode in ipairs(def.modes or {}) do ids[mode.id] = true end
    H.ok(ids["street-circuit"] and ids["shion-sprint"], "the street courses")
    H.ok(not ids["rooftop-run"], "never a foot course")
    H.eq(A.bots, false, "staff bot mode is off")
    H.eq(L.minimum(pve), 1)
end)

local first
H.test("a player alone starts at once on the chosen course; AI drivers fill the grid", function()
    H.fire("op77_lightrp:activity:join", 1, "race.pve", { course = "shion-sprint" })
    local inst = instance(1)
    H.ok(inst and inst.mode == "pve", "a race vs AI")
    H.eq(inst.course.id, "shion-sprint")
    local capacity = RaceCourses.capacity(inst.course, pve.maxPlayers)
    H.eq(#inst.bots, math.min(capacity, Config.pve.fillTo) - 1, "filled to pve.fillTo")
    H.ok(H.noticeFor(1, "AI drivers on the grid"))
    for _, bot in ipairs(inst.bots) do
        H.ok(H.vehicles[bot.vehicleId].bucket == inst.bucket and H.npcs[bot.npcId].bucket == inst.bucket, "in the race bucket")
        H.ok(bot.name:find("^%[BOT%] "))
    end
    local state = H.lastClient("op77_race:state", 1).args[1]
    H.eq(state.mode, "pve"); H.eq(state.bots, #inst.bots)
    toGo(inst)
    for _, bot in ipairs(inst.bots) do H.ok(H.ai[bot.vehicleId].route, "driving") end
    H.advance(61000)
    while racer(1).state == "racing" do stepPlayer(1) end
    H.eq(racer(1).finishPlace, 1)
    first = resultsFor(1)[1]
    H.ok(first, "a result")
    toClosed(1)
    H.eq(H.count(H.npcs), 0); H.eq(H.count(H.vehicles), 0)
end)

H.test("the result is a real one: no test flag, the vs-AI reputation", function()
    H.eq(first.test, nil, "recorded by the core")
    H.eq(first.stats.vsAi, true); H.eq(first.stats.mode, "pve")
    H.ok(first.stats.bots >= 1)
    H.eq(first.placement, 1); H.eq(first.won, true)
    H.eq(first.reputation, Config.pve.rewards.finish + Config.pve.rewards.placement[1])
    H.ok(first.reputation < Config.rewards.heatFinish + Config.rewards.placement[1], "less than against players")
end)

H.test("the vs-AI best is kept apart from the time trial's board", function()
    local file = H.files["records.json"]
    H.ok(file, "written")
    local board = file.courses[RaceRecords.vsAiBoard("shion-sprint")]
    H.ok(board and board.entries[1].timeMs == first.stats.timeMs, "vs-AI best stored")
    H.eq(file.courses["shion-sprint"], nil, "not on the time trial's board")
    H.eq(RaceRecords.best("shion-sprint", board.revision, "license:1/char1"), nil)
    -- the next race shows it as the best to beat
    H.fire("op77_lightrp:activity:join", 1, "race.pve", {})
    local inst = instance(1)
    H.eq(inst.course.id, "shion-sprint", "the course chosen last")
    H.eq(H.lastClient("op77_race:state", 1).args[1].personalBestMs, first.stats.timeMs)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.pve")
    toClosed(1)
end)

H.test("too quick to count: recorded, but no reputation", function()
    local _, result = race("shion-sprint", 0)
    H.ok(result.stats.timeMs < Config.pve.minimumSeconds * 1000, "under the minimum time")
    H.eq(result.test, nil); H.eq(result.reputation, 0)
end)

H.test("a course shorter than the minimum length pays nothing", function()
    local minimum = Config.pve.minimumMetres
    Config.pve.minimumMetres = 1e9
    local _, result = race("street-circuit", 61000)
    H.eq(result.placement, 1); H.eq(result.reputation, 0)
    Config.pve.minimumMetres = minimum
    -- the built-in street courses are long enough
    for _, id in ipairs({ "street-circuit", "shion-sprint" }) do
        local course = RaceCourses.get(id)
        H.ok(RaceShared.routeMetres(course) * course.laps >= minimum, id .. " is long enough")
    end
end)

H.test("a foot course is refused; /race.join pve <course> works", function()
    H.fire("op77_lightrp:activity:join", 2, "race.pve", { course = "rooftop-run" })
    H.eq(instance(2), nil)
    H.ok(H.noticeFor(2, "cannot be raced against AI"))
    H.command("race.join", 2, { "pve", "street-circuit" })
    local inst = instance(2)
    H.ok(inst and inst.mode == "pve" and inst.course.id == "street-circuit")
    H.fire("op77_lightrp:activity:leaveRequest", 2, "race.pve")
    toClosed(2)
end)

H.test("no AI on this server: a player alone is told so, nothing starts", function()
    local ai = Open77.vehicles.ai
    Open77.vehicles.ai = nil
    RaceBots.resetWarnings()
    H.fire("op77_lightrp:activity:join", 3, "race.pve", { course = "shion-sprint" })
    H.eq(instance(3), nil)
    H.ok(H.noticeFor(3, "No AI driver is available"))
    Open77.vehicles.ai = ai
end)

H.test("staff bot mode does not turn a race vs AI into a test", function()
    H.fire("op77_lightrp:activity:bots", true)
    local inst, result = race("shion-sprint", 61000)
    H.eq(inst.mode, "pve")
    H.eq(result.test, nil)
    H.ok(result.reputation > 0)
    H.fire("op77_lightrp:activity:bots", false)
end)

H.done("pve_test")
