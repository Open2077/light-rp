-- Crews in the public queue (a join with options.squad and no options.match: the panel). One
-- join per member, from the core. A crew gets a place for all who can come or stays out whole,
-- plays on one side of a team game unless it is the whole lobby, and a crew changing or ending
-- leaves the queue and the match correct. Run: lua tests/crew_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
local A, E, L = GamesActivity, GamesEngine, GamesLobby
local core = H.core

for id = 1, 24 do H.addPlayer(id) end
H.advance(200)

local function squad(id, leader, members) return { id = id, leader = leader, members = members } end
local function crewJoin(activityId, crew, options)
    for _, id in ipairs(crew.members) do
        local o = { ranked = true, squad = crew }
        for key, value in pairs(options or {}) do o[key] = value end
        H.panelJoin(id, activityId, o)
    end
end
local function finish(match)
    E.cancel(match)
    H.settle(1000)
    H.noneInBuckets()
end

H.test("a crew of the queue plays on one side, the others against it", function()
    local crew = squad("crew:1", 1, { 1, 2, 3 })
    H.panelJoin(4, "games.tdm", { ranked = true })
    crewJoin("games.tdm", crew)
    H.panelJoin(5, "games.tdm", { ranked = true })
    H.panelJoin(6, "games.tdm", { ranked = true })
    local match = H.untilPhase(1, "countdown")
    local side = match.players[1].side
    H.eq(match.players[2].side, side, "together")
    H.eq(match.players[3].side, side, "together")
    for _, id in ipairs({ 4, 5, 6 }) do H.ok(match.players[id].side ~= side, id .. " against them") end
    finish(match)
end)

H.test("two crews: one side each, whatever the order", function()
    crewJoin("games.ctf", squad("crew:a", 1, { 1, 2 }))
    crewJoin("games.ctf", squad("crew:b", 3, { 3, 4, 5 }))
    local match = H.untilPhase(1, "countdown")
    H.eq(match.players[1].side, match.players[2].side)
    H.eq(match.players[3].side, match.players[4].side)
    H.eq(match.players[3].side, match.players[5].side)
    H.ok(match.players[1].side ~= match.players[3].side, "against each other")
    finish(match)
end)

H.test("a crew that is the whole lobby is split by the deal: it still plays", function()
    crewJoin("games.control", squad("crew:2", 1, { 1, 2, 3, 4 }))
    local match = H.untilPhase(1, "countdown")
    local count = { 0, 0 }
    for id = 1, 4 do count[match.players[id].side] = count[match.players[id].side] + 1 end
    H.eq(count[1], 2, "two against two")
    H.eq(count[2], 2)
    finish(match)
end)

H.test("the crew's opponent falls away at the launch: the crew plays, split", function()
    local crew = squad("crew:3", 1, { 1, 2 })
    crewJoin("games.tdm", crew)
    H.panelJoin(3, "games.tdm", { ranked = true })
    H.advance(300)
    core.eligible[3] = "You must be alive and on your feet."
    local match = H.untilPhase(1, "countdown")
    core.eligible[3] = nil
    H.ok(match.players[1].side ~= match.players[2].side, "no one-sided match refused for nothing")
    H.eq(match.players[3], nil)
    finish(match)
end)

H.test("a game without teams takes the crew as it comes", function()
    crewJoin("games.redlight", squad("crew:4", 1, { 1, 2, 3 }))
    local match = H.untilPhase(1, "countdown")
    for id = 1, 3 do H.ok(match.players[id], id .. " in") ; H.eq(match.players[id].side, nil) end
    finish(match)
end)

H.test("a lobby without room for the whole crew: the whole crew stays out, each told", function()
    local def = A.definition("games.gungame")
    for id = 1, def.maxPlayers - 2 do H.panelJoin(id, "games.gungame", { ranked = true }) end
    local crew = squad("crew:5", 20, { 20, 21, 22 })
    crewJoin("games.gungame", crew)
    H.eq(L.queuedIn(20), nil, "the leader stays out")
    H.eq(L.queuedIn(21), nil)
    H.eq(L.queuedIn(22), nil)
    H.ok(H.noticeFor(20, "no room for your whole crew"), "the leader hears why")
    H.ok(H.noticeFor(22, "no room for your whole crew"), "each member too")
    H.eq(#L.queues[def.id].members, def.maxPlayers - 2, "the lobby is what it was")
    for id = 1, def.maxPlayers - 2 do H.fire("op77_lightrp:activity:leaveRequest", id, def.id) end
    H.advance(200)
end)

H.test("a member who cannot come keeps no place: the others fit", function()
    local def = A.definition("games.gungame")
    for id = 1, def.maxPlayers - 2 do H.panelJoin(id, "games.gungame", { ranked = true }) end
    core.eligible[22] = "You are on a mission. Finish or leave it first."
    local crew = squad("crew:6", 20, { 20, 21, 22 })
    H.panelJoin(20, "games.gungame", { ranked = true, squad = crew })
    H.panelJoin(21, "games.gungame", { ranked = true, squad = crew })
    core.eligible[22] = nil
    H.ok(L.queuedIn(20) and L.queuedIn(21), "two places, two who come")
    H.eq(#L.queues[def.id].members, def.maxPlayers, "the lobby is full now")
    local members = {}
    for i, id in ipairs(L.queues[def.id].members) do members[i] = id end
    for _, id in ipairs(members) do H.fire("op77_lightrp:activity:leaveRequest", id, def.id) end
    H.advance(200)
end)

H.test("a full lobby still answers a player alone as before", function()
    local def = A.definition("games.gungame")
    for id = 1, def.maxPlayers do H.panelJoin(id, "games.gungame", { ranked = true }) end
    H.panelJoin(20, "games.gungame", { ranked = true })
    H.eq(L.queuedIn(20), nil)
    H.ok(H.noticeFor(20, "This lobby is full"), "the same sentence")
    local match = H.untilPhase(1, "countdown")
    finish(match)
end)

H.test("a crew's squad is only believed about the player it came with", function()
    H.panelJoin(1, "games.tdm", { ranked = true, squad = squad("crew:7", 2, { 2, 3 }) })
    H.eq(L.squads[1], nil, "not a member of it")
    H.panelJoin(4, "games.tdm", { ranked = true, squad = squad("crew:7", 4, { 4 }) })
    H.eq(L.squads[4], nil, "a crew of one is no crew")
    H.panelJoin(5, "games.tdm", { ranked = true, squad = "junk" })
    H.panelJoin(6, "games.tdm", { ranked = true, squad = { id = "x", members = { "a", {}, -1 } } })
    H.eq(L.squads[5], nil)
    H.eq(L.squads[6], nil)
    for _, id in ipairs({ 1, 4, 5, 6 }) do H.fire("op77_lightrp:activity:leaveRequest", id, "games.tdm") end
    H.advance(200)
    H.eq(next(L.squads), nil, "nothing kept")
end)

H.test("a member leaves the queue: the others stay on one side, the game starts", function()
    crewJoin("games.tdm", squad("crew:8", 1, { 1, 2, 3 }))
    H.panelJoin(4, "games.tdm", { ranked = true })
    H.advance(300)
    H.fire("op77_lightrp:activity:leaveRequest", 3, "games.tdm")
    H.eq(L.squads[3], nil, "forgotten")
    local match = H.untilPhase(1, "countdown")
    H.eq(match.players[3], nil)
    H.eq(match.players[1].side, match.players[2].side)
    H.ok(match.players[4].side ~= match.players[1].side)
    H.eq(next(L.squads), nil, "the launch forgets them")
    finish(match)
end)

H.test("a member disconnects in the queue: forgotten with it", function()
    crewJoin("games.tdm", squad("crew:9", 1, { 1, 7 }))
    H.panelJoin(2, "games.tdm", { ranked = true })
    H.advance(300)
    H.removePlayer(7)
    local match = H.untilPhase(1, "countdown")
    H.eq(L.squads[7], nil)
    H.eq(match.players[7], nil)
    H.addPlayer(7)
    finish(match)
end)

H.test("a member leaves mid-game, ending a crew of two: the game goes on, sides unchanged", function()
    crewJoin("games.tdm", squad("crew:10", 1, { 1, 2 }))
    H.panelJoin(3, "games.tdm", { ranked = true })
    H.panelJoin(4, "games.tdm", { ranked = true })
    local match = H.untilPhase(1, "running")
    local side = match.players[1].side
    H.eq(match.players[2].side, side)
    -- the core tells us nothing of a crew changing: the match holds no crew to go stale
    H.fire("op77_lightrp:activity:leaveRequest", 2, "games.tdm")
    H.advance(500)
    H.eq(E.matchOf(2), nil, "out")
    H.eq(E.matchOf(1), match, "the game goes on")
    H.eq(match.phase, "running")
    H.eq(match.players[1].side, side, "the leader keeps the side")
    H.ok(match.players[3].side ~= side and match.players[4].side ~= side)
    H.ok(core.owner[1] == "games.tdm", "still the core's to bring back")
    finish(match)
end)

H.done("crew_test")
