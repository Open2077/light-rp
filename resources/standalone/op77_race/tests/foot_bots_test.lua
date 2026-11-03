-- Staff bot mode in a rooftop race: NPC runners on the foot slots, sent checkpoint to
-- checkpoint with moveTo (sprint, run when refused), re-sent on every checkpoint, out
-- when stuck, walking clear of the line once finished; then a server without the NPC
-- natives: bot mode changes nothing there, said once in the log.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 3 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(5)
H.load(H.SERVER)
local E, L, A, Config = RaceEngine, RaceLobby, RaceActivity, RaceConfig
local foot = A.byKey.foot

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function near(a, b) return RaceShared.distance(a, b) < 1e-6 end
local function moves(npcId)
    local n = 0
    for _, entry in ipairs(H.npcLog) do if entry.op == "moveTo" and entry.id == npcId then n = n + 1 end end
    return n
end
local function stepNpc(inst, bot)
    local cp = inst.course.checkpoints[bot.nextCheckpoint].position
    H.placeNpc(bot.npcId, cp.x, cp.y, cp.z)
    H.advance(600)
end
local function stepPlayer(id)
    local inst, r = instance(id), racer(id)
    local cp = inst.course.checkpoints[r.nextCheckpoint].position
    H.move(id, cp.x, cp.y, cp.z)
    H.advance(600)
end
local function resultFor(id)
    local found
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == id then found = event.args[3] end
    end
    return found
end

local inst, bots
H.test("bot mode on: one runner opens the rooftop grid; NPC runners on the line, in the bucket", function()
    H.fire("op77_lightrp:activity:bots", true)
    H.fireNet("op77_race:join", 1, { activity = "foot" })
    H.advance(200)
    H.ok(L.windowRemainingMs("foot") ~= nil, "one runner is enough")
    H.advance(foot.joinSeconds * 1000 + 500)
    inst = instance(1)
    H.ok(inst and RaceShared.onFoot(inst.course), "foot course")
    bots = inst.bots
    H.eq(#bots, Config.bots.fillTo.foot - 1)
    H.eq(H.count(H.vehicles), 0, "no car on foot")
    local records = {}
    for _, record in ipairs(Config.bots.runnerRecords) do records[record] = true end
    for _, bot in ipairs(bots) do
        H.eq(bot.kind, "foot")
        local npc = H.npcs[bot.npcId]
        H.ok(npc, "a runner NPC")
        H.eq(npc.bucket, inst.bucket)
        H.eq(npc.damagePolicy, Open77.npcs.damage.invulnerable)
        H.ok(records[npc.record], "a runner record from the config")
        H.ok(near(npc, bot.slot.position), "on its foot slot")
        H.ok(RaceShared.distance(npc, H.players[1]) > 0.5, "not on the player")
        H.eq(npc.task, nil, "nothing to do before GO")
    end
end)

H.test("GO: every runner sprints for checkpoint 1", function()
    H.advance(Config.engine.loadSeconds.foot * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.eq(inst.phase, "active")
    local cp1 = inst.course.checkpoints[1].position
    for _, bot in ipairs(bots) do
        local t = H.npcs[bot.npcId].task
        H.ok(t and t.kind == "moveTo", "moveTo")
        H.ok(near(t.target, cp1), "towards checkpoint 1")
        H.eq(t.opts.speed, "sprint"); H.eq(t.opts.acceptanceRadius, Config.bots.foot.acceptanceRadius)
    end
end)

H.test("each checkpoint reached sends the runner on to the next; sprint refused falls back to run", function()
    local runner = bots[1]
    local before = moves(runner.npcId)
    stepNpc(inst, runner)
    H.eq(runner.completed, 1)
    H.eq(moves(runner.npcId), before + 1, "a new moveTo")
    H.ok(near(H.npcs[runner.npcId].task.target, inst.course.checkpoints[2].position), "towards checkpoint 2")
    -- a runtime that refuses sprint
    local original = Open77.npcs.tasks.moveTo
    Open77.npcs.tasks.moveTo = function(id, target, opts)
        if opts.speed == "sprint" then return nil, "invalid_speed" end
        return original(id, target, opts)
    end
    local second = bots[2]
    stepNpc(inst, second)
    H.eq(second.completed, 1)
    H.eq(H.npcs[second.npcId].task.opts.speed, "run", "run instead")
    Open77.npcs.tasks.moveTo = original
end)

H.test("a runner who stops moving is sent again, then out and removed", function()
    Config.bots.stuckSeconds = 4
    local stuck = bots[3]
    local npcId = stuck.npcId
    local before = moves(npcId)
    for _ = 1, 8 do stepNpc(inst, bots[1]) end -- 4.8 s
    H.eq(moves(npcId), before + 1, "sent again")
    for _ = 1, 16 do stepNpc(inst, bots[1]) end
    H.eq(stuck.state, "dnf"); H.eq(stuck.dnfReason, "stuck")
    H.eq(H.npcs[npcId], nil, "removed")
    Config.bots.stuckSeconds = 20
end)

H.test("the first runner finishes and walks clear of the line; the player's window opens", function()
    local runner = bots[1]
    while runner.state == "racing" do stepNpc(inst, runner) end
    H.eq(runner.state, "finished"); H.eq(runner.finishPlace, 1)
    local t = H.npcs[runner.npcId].task
    local finishCp = inst.course.checkpoints[#inst.course.checkpoints].position
    H.ok(t and t.kind == "moveTo" and t.opts.speed == "walk", "walks")
    H.ok(RaceShared.distance(t.target, finishCp) > 3, "clear of the line")
    H.ok(H.noticeFor(1, "seconds to cross the line"))
end)

H.test("the player finishes: a test result; results end removes every runner", function()
    while racer(1).state == "racing" do stepPlayer(1) end
    local result = resultFor(1)
    H.ok(result, "a result")
    H.eq(result.test, true); H.eq(result.reputation, 0); H.eq(result.stats.bots, 3)
    local guard = 0
    while inst.phase == "active" and guard < 400 do H.advance(250); guard = guard + 1 end
    H.eq(inst.phase, "results")
    H.advance(Config.engine.resultsSeconds.foot * 1000 + 3000)
    H.eq(H.count(E.instances), 0)
    H.eq(H.count(H.npcs), 0, "every runner removed")
    H.eq(H.files["records.json"], nil, "nothing recorded")
end)

H.test("no NPC natives: bot mode changes nothing, and the log says so once", function()
    Open77.npcs = nil
    RaceBots.resetWarnings()
    local logsBefore = #H.logs
    H.fireNet("op77_race:join", 2, { activity = "foot" })
    H.advance(1000)
    H.eq(L.windowRemainingMs("foot"), nil, "two runners needed again")
    H.eq(H.noticeFor(2, "in the queue"), nil, "the queue panel shows it: no queued notice")
    local lobby = H.lastClient("op77_race:queue", 2).args[1]
    H.eq(lobby.minPlayers, 2); H.eq(lobby.bots, nil)
    H.advance(500)
    H.fireNet("op77_race:join", 3, { activity = "foot" })
    H.advance(foot.joinSeconds * 1000 + 1000)
    local race = instance(2)
    H.ok(race and instance(3) == race, "a normal two-runner heat")
    H.eq(race.bots, nil); H.eq(race.hadBots, nil)
    local warnings = 0
    for index = logsBefore + 1, #H.logs do
        if H.logs[index]:find("rooftop bots need Open77.npcs.create", 1, true) then warnings = warnings + 1 end
    end
    H.eq(warnings, 1, "logged once")
end)

H.done("foot_bots_test")
