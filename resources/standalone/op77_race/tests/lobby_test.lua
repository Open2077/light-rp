-- Light RP's activity lobby (join options v2): matches the core forms (options.match) race
-- in a heat of their own with exactly their players, never the public heat; AI racers
-- from options.fill, once per match, within the grid budget; a ranked match raced and
-- recorded like a heat of our queue; options.ranked == false writes no best time and
-- flags the result; staff bot mode unchanged; the time trial and the race vs AI ignore
-- fill and match.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 8 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(41)
H.load(H.SERVER)
local E, L, Config = RaceEngine, RaceLobby, RaceConfig
local grid, foot, pve = RaceActivity.byKey.grid, RaceActivity.byKey.foot, RaceActivity.byKey.pve
Config.bots.stuckSeconds = 600 -- the AI racers stay in while the players take their time

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function join(id, activityId, options) H.fire("op77_lightrp:activity:join", id, activityId, options or {}) end
-- The options every player of a core match receives (same id, same players, same fill).
local function matchOptions(id, players, opts)
    opts = opts or {}
    local ranked = opts.ranked == true
    return {
        ranked = ranked, fill = opts.fill,
        match = { id = id, friendly = opts.friendly ~= false and not ranked, ranked = ranked, players = players },
    }
end
local function results(id)
    local found = {}
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == id then found[#found + 1] = event.args[3] end
    end
    return found
end
local function lastResult(id) local list = results(id); return list[#list] end
local function toGo(inst)
    H.advance(Config.engine.loadSeconds[inst.mode] * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.eq(inst.phase, "active", "GO")
end
local function driveAll(id)
    local guard = 0
    while racer(id) and racer(id).state == "racing" and guard < 200 do
        local inst = instance(id)
        local cp = inst.course.checkpoints[racer(id).nextCheckpoint].position
        H.drive(id, cp.x, cp.y, cp.z)
        H.advance(600)
        guard = guard + 1
    end
end
-- Everyone out of races, queues and matches, instances closed.
local function clear()
    for id = 1, 8 do
        local r = racer(id)
        if r then H.fire("op77_lightrp:activity:leaveRequest", id, r.activityId)
        elseif L.queuedIn(id) then H.fire("op77_lightrp:activity:leaveRequest", id, "race." .. L.queuedIn(id)) end
    end
    local guard = 0
    while (H.count(E.racers) > 0 or H.count(E.instances) > 0) and guard < 200 do H.advance(250); guard = guard + 1 end
    H.eq(H.count(E.racers), 0, "everyone out")
    H.eq(H.count(E.instances), 0, "instances closed")
    for id = 1, 8 do H.eq(L.queuedIn(id), nil, "nothing queued") end
    H.eq(H.count(L.matches), 0, "no match gathering")
    H.eq(H.count(H.npcs), 0, "no AI body left"); H.eq(H.count(H.vehicles), 0, "no car left")
    H.advance(400)
end

H.test("bot fill is declared for the street and rooftop races only, and only when their AI can drive", function()
    H.eq(H.core.registered["race.grid"].botFill, true)
    H.eq(H.core.registered["race.foot"].botFill, true)
    H.eq(H.core.registered["race.pve"].botFill, nil, "the race vs AI has its AI built in")
    H.eq(H.core.registered["race.trial"].botFill, nil, "solo")
    -- runners that cannot run: the rooftop race offers no bot fill, the street race still does
    local moveTo, patrol = Open77.npcs.tasks.moveTo, Open77.npcs.tasks.patrol
    Open77.npcs.tasks.moveTo, Open77.npcs.tasks.patrol = nil, nil
    H.eq(RaceActivity.registration(foot).botFill, nil)
    H.eq(RaceActivity.registration(grid).botFill, true)
    Open77.npcs.tasks.moveTo, Open77.npcs.tasks.patrol = moveTo, patrol
    -- no vehicle AI: no street bot fill
    local ai = Open77.vehicles.ai
    Open77.vehicles.ai = nil
    H.eq(RaceActivity.registration(grid).botFill, nil)
    Open77.vehicles.ai = ai
end)

local friendly
H.test("a friendly match races in a heat of its own; the public heat and strangers never mix in", function()
    join(3, "race.grid", { ranked = true })
    join(4, "race.grid", { ranked = true })
    H.advance(200)
    H.ok(L.windowRemainingMs("grid"), "the public heat is forming")
    local options = matchOptions("match:1", { 1, 2 })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    friendly = instance(1)
    H.ok(friendly and instance(2) == friendly, "started at once, both in")
    H.eq(#friendly.members, 2); H.eq(friendly.match, "match:1"); H.eq(friendly.friendly, true)
    H.eq(RaceBots.count(friendly), 0, "no AI racer in a friendly without fill")
    H.ok(H.noticeFor(1, "Friendly match: unranked"))
    H.eq(L.queuedIn(3), "grid"); H.eq(L.queuedIn(4), "grid"); H.eq(instance(3), nil)
    -- a stranger joining the street race goes to the public queue, not into the match
    join(5, "race.grid", { ranked = true })
    H.eq(L.queuedIn(5), "grid"); H.eq(instance(5), nil)
    H.advance(grid.joinSeconds * 1000 + 1000)
    local public = instance(3)
    H.ok(public and public ~= friendly and instance(4) == public and instance(5) == public, "the public heat")
    H.eq(#public.members, 3); H.eq(public.match, nil)
    H.eq(#friendly.members, 2, "nobody joined the match")
    H.ok(friendly.bucket ~= public.bucket, "two buckets")
    local state = H.lastClient("op77_race:state", 1).args[1]
    H.eq(state.unranked, true); H.eq(state.friendly, true); H.eq(state.match, true)
    state = H.lastClient("op77_race:state", 3).args[1]
    H.eq(state.unranked, nil); H.eq(state.friendly, nil); H.eq(state.match, nil)
end)

H.test("the friendly match's results: unranked, no reputation, not a test", function()
    H.eq(friendly.phase, "active", "the match went on while the public heat formed")
    driveAll(1)
    driveAll(2)
    local first, second = lastResult(1), lastResult(2)
    H.ok(first and second, "a result each")
    H.eq(first.placement, 1); H.eq(second.placement, 2)
    H.eq(first.unranked, true); H.eq(second.unranked, true)
    H.eq(first.test, nil, "not a staff test")
    H.eq(first.reputation, 0); H.eq(second.reputation, 0)
    H.eq(first.stats.bots, nil)
    H.eq(H.files["records.json"], nil, "no best time written")
    clear()
end)

H.test("a bot-filled match: options.fill AI racers once per match, not once per player", function()
    local options = matchOptions("match:2", { 1, 2 }, { friendly = false, fill = { enemies = 3 } })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and instance(2) == inst and inst.match == "match:2")
    H.eq(inst.friendly, nil)
    H.eq(#inst.bots, 3, "three AI racers")
    H.ok(H.noticeFor(1, "Unranked: 3 AI drivers on the grid"))
    for index, bot in ipairs(inst.bots) do
        H.eq(H.vehicles[bot.vehicleId].bucket, inst.bucket, "in the match's bucket")
        H.eq(bot.slotIndex, 2 + index, "behind the players")
    end
    toGo(inst)
    for _, bot in ipairs(inst.bots) do H.eq(bot.state, "racing"); H.ok(H.ai[bot.vehicleId].route, "driving") end
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.grid")
    local result = lastResult(1)
    H.ok(result, "a result at the forfeit")
    H.eq(result.unranked, true); H.eq(result.test, nil); H.eq(result.reputation, 0)
    H.eq(result.stats.bots, 3)
    clear()
end)

H.test("AI racers are capped to the match budget and the course; a rooftop match gets runners", function()
    local options = matchOptions("match:3", { 1, 2 }, { friendly = false, fill = { enemies = 7 } })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.eq(#inst.bots, Config.matches.fillTo.grid - 2, "within matches.fillTo")
    clear()
    options = matchOptions("match:3b", { 3 }, { friendly = false, fill = { enemies = 2 } })
    join(3, "race.foot", options)
    inst = instance(3)
    H.ok(inst and inst.mode == "foot" and inst.match == "match:3b")
    H.eq(#inst.bots, 2, "two AI runners")
    for _, bot in ipairs(inst.bots) do H.eq(bot.kind, "foot"); H.ok(H.npcs[bot.npcId], "a body") end
    clear()
end)

H.test("a server without AI: the bot-filled match races without them and says so", function()
    local ai = Open77.vehicles.ai
    Open77.vehicles.ai = nil
    RaceBots.resetWarnings()
    local options = matchOptions("match:4", { 1, 2 }, { friendly = false, fill = { enemies = 2 } })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and #inst.members == 2, "the players race")
    H.eq(RaceBots.count(inst), 0)
    H.ok(H.noticeFor(1, "No AI racer is available"))
    Open77.vehicles.ai = ai
    clear()
end)

H.test("a member who never comes: the match starts after gatherSeconds with whoever made it", function()
    join(1, "race.foot", matchOptions("match:5", { 1, 6 }))
    H.eq(instance(1), nil, "waiting for player 6")
    H.eq(L.queuedIn(1), "foot")
    H.eq(L.size("foot"), 1)
    H.advance(Config.matches.gatherSeconds * 1000 - 600)
    H.eq(instance(1), nil)
    H.advance(1000)
    local inst = instance(1)
    H.ok(inst and inst.match == "match:5", "started")
    H.eq(#inst.members, 1); H.eq(instance(6), nil)
    -- player 6's join arriving after the start: refused, never a lone heat
    join(6, "race.foot", matchOptions("match:5", { 1, 6 }))
    H.advance(Config.matches.gatherSeconds * 1000 + 500)
    H.eq(instance(6), nil); H.eq(L.queuedIn(6), nil)
    H.ok(H.noticeFor(6, "already started without you"))
    H.ok(#H.coreCalls("activityLeave", 6) >= 1, "Light RP no longer lists them as queued")
    clear()
end)

H.test("a match member leaving the gathering is no longer waited for", function()
    local options = matchOptions("match:6", { 1, 2, 3 })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    H.eq(instance(1), nil, "player 3 still expected")
    -- Light RP's queue panel: the match on its way (two of three here, joining).
    local q = L.queueOf(RaceActivity.byKey.grid)
    H.eq(#q.lobbies, 1); H.eq(#q.lobbies[1].players, 2); H.eq(q.lobbies[1].need, 3); H.eq(q.lobbies[1].joining, true)
    H.fire("op77_lightrp:activity:leaveRequest", 2, "race.grid")
    H.eq(L.queuedIn(2), nil)
    H.advance(300)
    H.eq(instance(1), nil, "still waiting for player 3")
    join(3, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and instance(3) == inst and instance(2) == nil, "player 3 completes it")
    clear()
end)

H.test("a player queued in the public heat who is matched leaves the queue for the match", function()
    join(1, "race.grid", { ranked = true })
    H.eq(L.queuedIn(1), "grid")
    local options = matchOptions("match:7", { 1, 2 }, { friendly = false, fill = { enemies = 1 } })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and inst.match == "match:7" and instance(2) == inst)
    H.eq(#L.queues.grid.members, 0, "out of the public queue")
    H.eq(#inst.bots, 1)
    clear()
end)

H.test("a ranked match: its own heat, humans only, raced and recorded like a heat of our queue", function()
    -- a fill on a ranked match is ignored: ranked is humans only
    local options = matchOptions("match:8", { 1, 2 }, { ranked = true, fill = { enemies = 3 } })
    H.eq(options.match.friendly, false)
    join(3, "race.grid", { ranked = true })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and instance(2) == inst and inst.match == "match:8", "started at once")
    H.eq(#inst.members, 2); H.eq(RaceBots.count(inst), 0, "no AI racer")
    H.eq(L.queuedIn(3), "grid", "the public queue stays apart")
    H.ok(H.noticeFor(1, "Ranked match"))
    H.eq(racer(1).unranked, nil); H.eq(racer(2).unranked, nil)
    toGo(inst)
    driveAll(1)
    driveAll(2)
    local first, second = lastResult(1), lastResult(2)
    H.eq(first.unranked, nil, "ranked"); H.eq(first.test, nil)
    H.eq(first.placement, 1); H.eq(first.won, true)
    H.eq(first.reputation, Config.rewards.heatFinish + Config.rewards.placement[1], "a heat's reputation")
    H.eq(second.reputation, Config.rewards.heatFinish + Config.rewards.placement[2])
    H.eq(first.stats.racers, 2); H.eq(first.stats.mode, "grid"); H.eq(first.stats.bots, nil)
    H.eq(H.lastClient("op77_race:state", 1).args[1].unranked, nil)
    -- a street or rooftop heat never writes best times (only the time trial and the
    -- race vs AI do): the ranked match writes exactly what a queue heat writes
    H.eq(H.files["records.json"], nil)
    clear()
end)

H.test("options.ranked == false: no best time on the time trial's board; ranked, it is written", function()
    join(7, "race.trial", { course = "street-circuit", ranked = false })
    local inst = instance(7)
    toGo(inst)
    driveAll(7)
    local result = lastResult(7)
    H.ok(result and result.placement == 1, "finished")
    H.eq(result.unranked, true); H.eq(result.reputation, 0)
    H.eq(result.stats.personalBest, nil); H.eq(result.stats.courseRecord, nil)
    H.eq(H.files["records.json"], nil, "nothing written")
    H.eq(H.lastClient("op77_race:state", 7).args[1].unranked, true)
    clear()
    join(7, "race.trial", { course = "street-circuit", ranked = true })
    inst = instance(7)
    toGo(inst)
    driveAll(7)
    result = lastResult(7)
    H.eq(result.unranked, nil); H.ok(result.reputation > 0)
    H.eq(result.stats.personalBest, true)
    local file = H.files["records.json"]
    H.ok(file and file.courses["street-circuit"], "the board is written")
    H.eq(file.courses["street-circuit"].entries[1].key, "license:7/char1")
    clear()
end)

H.test("options.ranked == false: no best vs AI either; the result says unranked", function()
    join(8, "race.pve", { course = "shion-sprint", ranked = false })
    local inst = instance(8)
    toGo(inst)
    H.advance(61000)
    driveAll(8)
    local result = lastResult(8)
    H.ok(result and result.placement == 1, "finished first")
    H.eq(result.unranked, true); H.eq(result.reputation, 0); H.eq(result.test, nil)
    H.eq(H.files["records.json"].courses[RaceRecords.vsAiBoard("shion-sprint")], nil, "no best vs AI")
    clear()
end)

H.test("the race vs AI and the time trial ignore fill and match", function()
    local stray = { id = "match:9", friendly = true, players = { 4, 5 } }
    join(4, "race.pve", { course = "shion-sprint", fill = { allies = 2, enemies = 3 }, match = stray })
    local inst = instance(4)
    H.ok(inst and inst.mode == "pve" and inst.match == nil)
    H.eq(#inst.bots, math.min(RaceCourses.capacity(inst.course, pve.maxPlayers), Config.pve.fillTo) - 1, "pve.fillTo as always")
    H.eq(racer(4).unranked, nil)
    join(5, "race.trial", { course = "street-circuit", match = stray, fill = { enemies = 3 } })
    local trial = instance(5)
    H.ok(trial and trial.mode == "trial" and trial.match == nil and trial.bots == nil, "solo, no AI")
    clear()
end)

H.test("staff bot mode is unchanged: a lone player's public heat is a bot-filled test; matches keep their own fill", function()
    H.fire("op77_lightrp:activity:bots", true)
    -- a friendly match is not filled by the staff switch
    local options = matchOptions("match:10", { 1, 2 })
    join(1, "race.grid", options)
    join(2, "race.grid", options)
    local inst = instance(1)
    H.ok(inst and inst.match == "match:10")
    H.eq(RaceBots.count(inst), 0, "no staff bots in a match")
    -- the staff path: one player opens the public heat, bots fill it to bots.fillTo
    join(3, "race.grid", { ranked = false })
    H.advance(200)
    H.ok(L.windowRemainingMs("grid"), "one player is enough")
    H.ok(H.noticeFor(3, "Bot mode: bots fill the grid"))
    H.advance(grid.joinSeconds * 1000 + 500)
    local test = instance(3)
    H.ok(test and test ~= inst and test.match == nil)
    H.eq(#test.bots, Config.bots.fillTo.grid - 1, "filled to bots.fillTo")
    H.ok(H.noticeFor(3, "Bot mode: 3 bots on the grid"))
    toGo(test)
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.grid")
    local result = lastResult(3)
    H.eq(result.test, true, "a staff test, as before")
    H.eq(result.reputation, 0)
    H.fire("op77_lightrp:activity:bots", false)
    clear()
    H.eq(foot.minPlayers, 2, "the rooftop race's minimum is untouched")
end)

H.done("lobby_test")
