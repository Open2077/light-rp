-- Crews (options.squad = { id, leader, members } from the core, one join per member):
-- in a queued heat a crew races in one instance on adjacent slots, waits whole when it
-- does not fit beside the others, and holds the launch while a member is on the way
-- (crews.gatherSeconds at most); a crew joining the race vs AI starts together, on the
-- leader's course, or without the late member once the wait is over.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 8 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(31)
H.load(H.SERVER)
local E, L, A, Config = RaceEngine, RaceLobby, RaceActivity, RaceConfig
local grid, pve = A.byKey.grid, A.byKey.pve
local gatherMs = Config.crews.gatherSeconds * 1000

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function squad(id, leader, members) return { squad = { id = id, leader = leader, members = members } } end
local function join(id, activityId, options) H.fire("op77_lightrp:activity:join", id, activityId, options or {}) end
local function membersOf(inst)
    local set = {}
    for _, id in ipairs(inst.members) do set[id] = true end
    return set
end
-- Everyone out of races and queues, instances closed.
local function clear()
    for id = 1, 8 do
        local r = racer(id)
        if r then H.fire("op77_lightrp:activity:leaveRequest", id, r.activityId)
        elseif L.queuedIn(id) then H.fire("op77_lightrp:activity:leaveRequest", id, "race." .. L.queuedIn(id)) end
    end
    local guard = 0
    while (H.count(E.racers) > 0 or H.count(E.instances) > 0) and guard < 200 do H.advance(250); guard = guard + 1 end
    H.eq(H.count(E.racers), 0, "everyone out")
    for id = 1, 8 do H.eq(L.queuedIn(id), nil, "queue empty") end
    H.advance(400)
end

H.test("the squad a join comes with", function()
    local s = L.squadOf(squad("c1", 1, { 1, 2 }), 1)
    H.ok(s and s.id == "c1" and #s.expected == 2 and s.leader == 1)
    s = L.squadOf(squad("c1", 1, { { id = 1 }, { id = 2 }, { playerId = 3 } }), 2)
    H.ok(s and #s.expected == 3, "members as tables")
    H.eq(L.squadOf(squad("c1", 1, { 1 }), 1), nil, "a crew of one is no crew")
    H.eq(L.squadOf(squad("c1", 1, { 1, 2 }), 5), nil, "not a member")
    H.eq(L.squadOf({}, 1), nil); H.eq(L.squadOf(nil, 1), nil)
end)

H.test("street race: a crew takes adjacent slots in one instance; the solo racer behind waits", function()
    grid.maxPlayers = 3
    join(3, "race.grid")
    join(1, "race.grid", squad("A", 1, { 1, 2 }))
    join(4, "race.grid")
    join(2, "race.grid", squad("A", 1, { 1, 2 }))
    H.advance(grid.fullSeconds * 1000 + 1000)
    local inst = instance(1)
    H.ok(inst and instance(2) == inst, "the crew together")
    local set = membersOf(inst)
    H.ok(set[3] and not set[4], "the first solo racer with them, the next one waits")
    H.eq(#inst.members, 3)
    H.eq(math.abs(racer(1).slotIndex - racer(2).slotIndex), 1, "side by side on the grid")
    H.eq(L.queuedIn(4), "grid")
    clear()
end)

H.test("a crew that does not fit beside the others waits whole, then races together", function()
    join(5, "race.grid")
    join(6, "race.grid")
    join(7, "race.grid", squad("B", 8, { 7, 8 }))
    join(8, "race.grid", squad("B", 8, { 7, 8 }))
    H.advance(grid.fullSeconds * 1000 + 1000)
    local first = instance(5)
    H.ok(first and instance(6) == first, "the two solo racers go")
    H.eq(instance(7), nil); H.eq(instance(8), nil)
    H.eq(L.queuedIn(7), "grid"); H.eq(L.queuedIn(8), "grid")
    H.advance(grid.joinSeconds * 1000 + 1000)
    local second = instance(7)
    H.ok(second and second ~= first and instance(8) == second, "the crew's own heat, together")
    grid.maxPlayers = 8
    clear()
end)

H.test("the launch waits for a crew member on the way", function()
    join(1, "race.grid")
    join(3, "race.grid")
    H.advance(500)
    local remaining = L.windowRemainingMs("grid")
    H.ok(remaining, "the window is open")
    H.advance(remaining - 1000)
    join(2, "race.grid", squad("C", 2, { 2, 4 }))
    H.advance(1500)
    H.eq(instance(1), nil, "held for player 4")
    H.ok(L.gathering(L.queues.grid, E.nowMs()))
    join(4, "race.grid", squad("C", 2, { 2, 4 }))
    H.advance(300)
    local inst = instance(1)
    H.ok(inst and instance(2) == inst and instance(4) == inst and instance(3) == inst, "everyone, crew complete")
    H.eq(math.abs(racer(2).slotIndex - racer(4).slotIndex), 1, "side by side")
    clear()
end)

H.test("a member who never comes holds the launch for gatherSeconds only", function()
    join(5, "race.grid")
    join(6, "race.grid")
    H.advance(500)
    H.advance(L.windowRemainingMs("grid") - 1000)
    join(7, "race.grid", squad("D", 7, { 7, 8 }))
    H.advance(gatherMs - 1000)
    H.eq(instance(7), nil, "still waiting for player 8")
    H.advance(1500)
    local inst = instance(7)
    H.ok(inst and instance(5) == inst and instance(6) == inst, "launched without the late one")
    H.eq(instance(8), nil)
    clear()
end)

H.test("race vs AI: a crew starts together on the leader's course, AI behind them", function()
    join(1, "race.pve", { course = "street-circuit", squad = { id = "P", leader = 2, members = { 1, 2 } } })
    H.eq(instance(1), nil, "waits for the crew")
    H.ok(H.noticeFor(1, "Waiting for your crew"))
    H.eq(L.queuedIn(1), "pve"); H.eq(L.size("pve"), 1)
    join(2, "race.pve", { course = "shion-sprint", squad = { id = "P", leader = 2, members = { 1, 2 } } })
    local inst = instance(1)
    H.ok(inst and instance(2) == inst, "together")
    H.eq(inst.course.id, "shion-sprint", "the leader's choice")
    H.eq(L.size("pve"), 0)
    local capacity = RaceCourses.capacity(inst.course, pve.maxPlayers)
    H.eq(#inst.bots, math.min(capacity, Config.pve.fillTo) - 2, "AI fills the rest")
    H.eq(racer(1).slotIndex + racer(2).slotIndex, 3, "the front of the grid")
    clear()
end)

H.test("race vs AI: a member who never comes is left behind after gatherSeconds", function()
    join(3, "race.pve", { course = "shion-sprint", squad = { id = "Q", leader = 3, members = { 3, 4 } } })
    H.advance(1000)
    -- Light RP's queue panel: one of two, starting when the gather wait is over.
    local q = L.queueOf(pve)
    H.eq(#q.lobbies, 1); H.eq(q.lobbies[1].players[1], 3); H.eq(q.lobbies[1].need, 2)
    H.eq(q.lobbies[1].startsInMs, gatherMs - 1000)
    H.advance(gatherMs - 1500)
    H.eq(instance(3), nil)
    H.advance(1000)
    local inst = instance(3)
    H.ok(inst, "started without player 4")
    H.eq(#inst.members, 1); H.ok(#inst.bots >= 1)
    H.eq(L.queuedIn(4), nil)
    clear()
end)

H.test("a crew member leaving the gathering is no longer waited for", function()
    join(5, "race.pve", { course = "shion-sprint", squad = { id = "R", leader = 5, members = { 5, 6, 7 } } })
    join(6, "race.pve", { squad = { id = "R", leader = 5, members = { 5, 6, 7 } } })
    H.eq(instance(5), nil, "player 7 still expected")
    H.fire("op77_lightrp:activity:leaveRequest", 6, "race.pve")
    H.eq(L.queuedIn(6), nil)
    H.advance(gatherMs + 500)
    local inst = instance(5)
    H.ok(inst and instance(6) == nil, "player 5 goes; player 6 left")
    clear()
end)

H.done("crew_test")
