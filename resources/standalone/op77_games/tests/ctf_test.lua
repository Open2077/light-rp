-- Capture the Flag: rules lifted from the source mode, on the engine.
-- Run: lua tests/ctf_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
H.advance(200)
local E, G = GamesEngine, GamesCtf
local R = G.rules
local AJAX = H.hash("Items.Preset_Ajax_Default")

local function mapOf(id)
    return H.mapOf("ctf", id)
end
local DOCKS, SCHOOL = mapOf("watson-docks"), mapOf("school")

local nextId = 0
local function players(n)
    local ids = {}
    for _ = 1, n do
        nextId = nextId + 1
        H.addPlayer(nextId)
        ids[#ids + 1] = nextId
    end
    return ids
end

-- Two even teams on the docks, running, past every shield. Red are a's, blue are b's.
local function live(n, map)
    local ids = players(n)
    local teams = { {}, {} }
    for index, id in ipairs(ids) do table.insert(teams[index % 2 == 1 and 1 or 2], id) end
    H.matchJoin("games.ctf", ids, { teams = teams, map = map or "watson-docks" })
    local match = H.untilPhase(ids[1], "running")
    for _, p in pairs(match.players) do p.ctf.shieldUntil = nil end
    return match, teams[1], teams[2]
end

local function to(id, spot, dx) H.move(id, spot.x + (dx or 0), spot.y, spot.z) end
local function midfield(id, dy) H.move(id, DOCKS.centre.x, DOCKS.centre.y + (dy or 0), DOCKS.centre.z) end

-- Red's a takes blue's flag.
local function grab(match, id, map)
    to(id, (map or DOCKS).blueBase)
    H.settle(200)
    H.eq(match.ctf.flags[2].state, "carried", "taken")
    H.eq(match.ctf.flags[2].carrier, id)
end

local function capture(match, id)
    grab(match, id)
    to(id, DOCKS.redBase)
    H.settle(200)
end

local function shoot(killer, victim)
    H.eq(H.hit(killer, victim, AJAX), true, "the shot lands")
    H.die(victim, killer)
    H.settle(100)
end

local function lastResults()
    local byId = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    return byId
end

H.test("the activity: two maps, flags as markers, no model anywhere", function()
    local def = H.ok(H.core.registered["games.ctf"], "registered")
    H.eq(def.kind, "pvp")
    H.eq(#def.modes, 2)
    H.eq(def.modes[1].id, "school", "by name")
    H.eq(def.modes[2].id, "watson-docks")
end)

H.test("the play area always covers both bases by 15 m", function()
    H.ok(DOCKS.radius > 50, "widened from the source's 50")
    for _, map in ipairs(H.mapsOf("ctf")) do
        for _, base in ipairs({ map.redBase, map.blueBase }) do
            H.ok(E.distance(base, map.centre) + 15 <= map.radius + 0.001, map.id .. ": covered")
        end
    end
end)

H.test("a team's spawns: only the spots on its half; none: its base", function()
    H.eq(#G.teamSpots(DOCKS, 1), 0)
    H.eq(#G.teamSpots(SCHOOL, 1), 4, "red's spot beside the blue base is out")
    H.eq(#G.teamSpots(SCHOOL, 2), 1, "three of blue's sit on the red base")
    for side = 1, 2 do
        local enemy = side == 1 and SCHOOL.blueBase or SCHOOL.redBase
        for _, spot in ipairs(G.teamSpots(SCHOOL, side)) do
            H.ok(E.flat(spot, enemy) > R.flagRadius, "nobody spawns on the enemy flag")
        end
    end
end)

H.test("flag rules: reach, landing, return time", function()
    H.eq(G.within({ x = 2.4, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }, 2.5), true)
    H.eq(G.within({ x = 2.6, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }, 2.5), false)
    H.eq(G.within({ x = 0, y = 0, z = 3.1 }, { x = 0, y = 0, z = 0 }, 2.5), false, "the vertical reach")
    H.eq(G.landing(DOCKS, 2, DOCKS.centre), "dropped")
    H.eq(G.landing(DOCKS, 2, DOCKS.blueBase), "home", "on its own stand")
    H.eq(G.landing(DOCKS, 2, { x = DOCKS.centre.x + DOCKS.radius + 1, y = DOCKS.centre.y, z = DOCKS.centre.z }), "home", "out of bounds")
    H.eq(G.expired({ state = "dropped", droppedAt = 0 }, 19999), false)
    H.eq(G.expired({ state = "dropped", droppedAt = 0 }, 20000), true)
    H.eq(G.expired({ state = "base" }, 90000), false)
end)

H.test("each team starts at its base, shielded; the world shows bases and flags to the match", function()
    local ids = players(2)
    local mark = #H.clientEvents
    H.matchJoin("games.ctf", ids, { teams = { { ids[1] }, { ids[2] } }, map = "watson-docks" })
    local match = H.untilPhase(ids[1], "running")
    H.ok(E.flat(H.players[ids[1]], DOCKS.redBase) <= 3.01)
    H.ok(E.flat(H.players[ids[2]], DOCKS.blueBase) <= 3.01)
    H.eq(H.weapons[ids[1]][1], "Items.Preset_Ajax_Default")
    H.settle(300)
    local world = H.lastClient("op77_games:hud", ids[1]).args[1].world
    H.eq(world.markers.base1.shape, "ring")
    H.eq(world.markers.base1.radius, 4)
    H.eq(world.markers.flag2.shape, "diamond")
    H.eq(world.blips.flag1.title, "Red flag")
    for index = mark + 1, #H.clientEvents do
        local event = H.clientEvents[index]
        if event.name == "op77_games:hud" then H.ok(event.target == ids[1] or event.target == ids[2], "nobody else") end
    end
    E.cancel(match)
    H.settle(500)
end)

H.test("take, carry, capture with your flag home", function()
    local match, a, b = live(2)
    capture(match, a[1])
    H.eq(match.ctf.score[1], 1)
    H.eq(match.ctf.flags[2].state, "base", "back on its stand")
    H.eq(match.players[a[1]].ctf.captures, 1)
    H.eq(match.phase, "running")
    H.eq(H.lastClient("op77_games:hud", b[1]).args[1].world ~= nil, true)
    H.settle(300)
    H.eq(H.lastClient("op77_games:hud", b[1]).args[1].teams[1].score, 1)
    E.cancel(match)
    H.settle(500)
end)

H.test("your own flag on its stand is not yours to take, walking past changes nothing", function()
    local match, a, b = live(2)
    to(b[1], DOCKS.blueBase)
    H.settle(300)
    H.eq(match.ctf.flags[2].state, "base")
    midfield(a[1])
    H.settle(300)
    H.eq(match.ctf.flags[1].state, "base")
    E.cancel(match)
    H.settle(500)
end)

H.test("your flag must be home: no capture while it is carried, then one on its return", function()
    local match, a, b = live(2)
    grab(match, a[1])
    to(b[1], DOCKS.redBase)
    H.settle(200)
    H.eq(match.ctf.flags[1].carrier, b[1], "both flags out")
    midfield(b[1], 20)
    H.settle(100)
    to(a[1], DOCKS.redBase)
    H.settle(500)
    H.eq(match.ctf.score[1], 0, "no capture")
    H.eq(match.ctf.flags[2].carrier, a[1], "still carrying")
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].objective, "Your flag must be home")
    shoot(a[1], b[1])
    H.eq(match.ctf.flags[1].state, "dropped", "red's flag falls")
    H.move(a[1], H.players[b[1]].x, H.players[b[1]].y, H.players[b[1]].z)
    H.settle(200)
    H.eq(match.ctf.flags[1].state, "base", "a's touch sends it home")
    H.eq(match.players[a[1]].ctf.returns, 1)
    to(a[1], DOCKS.redBase)
    H.settle(200)
    H.eq(match.ctf.score[1], 1, "now it counts")
    E.cancel(match)
    H.settle(500)
end)

H.test("three captures win; the recap ranks who carried it", function()
    local match, a, b = live(4)
    capture(match, a[1])
    capture(match, a[1])
    H.eq(match.phase, "running")
    capture(match, a[2])
    H.eq(match.phase, "ended")
    H.eq(match.reason, "captures")
    local results = lastResults()
    H.eq(results[a[1]].won, true)
    H.eq(results[a[2]].won, true)
    H.eq(results[b[1]].won, false)
    H.eq(results[a[1]].score, 2)
    H.eq(results[a[1]].unranked, true)
    local recap = results[a[1]].recap
    H.eq(recap.winnerSide, 1)
    H.eq(recap.sides[1].score, 3)
    H.eq(recap.rows[1].id, a[1], "the most captures on top")
    H.eq(recap.rows[1].captures, 2)
    H.eq(recap.lines[1].value, "Red")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a dropped flag: at the carrier's feet on death, home after 20 s, an enemy may take it", function()
    local match, a, b = live(2)
    grab(match, a[1])
    midfield(a[1])
    H.settle(200)
    shoot(b[1], a[1])
    local flag = match.ctf.flags[2]
    H.eq(flag.state, "dropped")
    H.ok(E.flat(flag.pos, DOCKS.centre) < 1, "where it fell")
    H.settle(5500) -- a back, nobody near
    midfield(a[1], 20)
    H.settle(13000)
    H.eq(match.ctf.flags[2].state, "dropped", "not yet")
    H.settle(2500)
    H.eq(match.ctf.flags[2].state, "base", "20 s: home")
    grab(match, a[1])
    midfield(a[1])
    H.settle(200)
    shoot(b[1], a[1])
    H.settle(5500)
    midfield(a[1])
    H.settle(300)
    H.eq(match.ctf.flags[2].carrier, a[1], "picked up where it lay")
    E.cancel(match)
    H.settle(500)
end)

H.test("a carrier dying on the flag's own stand, or out of bounds, sends it home at once", function()
    local match, a, b = live(2)
    grab(match, a[1])
    shoot(b[1], a[1]) -- on the blue stand
    H.eq(match.ctf.flags[2].state, "base")
    H.settle(5500)
    grab(match, a[1])
    H.move(a[1], DOCKS.centre.x, DOCKS.centre.y + DOCKS.radius + 5, DOCKS.centre.z)
    H.settle(300)
    H.die(a[1])
    H.settle(100)
    H.eq(match.ctf.flags[2].state, "base", "dropped out of bounds: home")
    E.cancel(match)
    H.settle(500)
end)

H.test("a carrier who stays out of bounds dies by the engine's rule and the flag goes home", function()
    local match, a = live(2)
    grab(match, a[1])
    H.move(a[1], DOCKS.centre.x, DOCKS.centre.y + DOCKS.radius + 5, DOCKS.centre.z)
    H.settle(5500)
    H.ok(#H.kills > 0, "killed by the play area")
    H.fire("open77:playerDied", a[1], "{}")
    H.settle(100)
    H.eq(match.players[a[1]].deaths, 1)
    H.eq(match.ctf.flags[2].state, "base")
    E.cancel(match)
    H.settle(500)
end)

H.test("a carrier disconnecting: the flag lies where it was last seen, still counts down", function()
    local match, a = live(3)
    grab(match, a[1])
    midfield(a[1])
    H.settle(200)
    H.fire("onPlayerDisconnected", a[1])
    H.removePlayer(a[1])
    H.settle(100)
    local flag = match.ctf.flags[2]
    H.eq(flag.state, "dropped")
    H.ok(E.flat(flag.pos, DOCKS.centre) < 1, "last seen")
    H.eq(match.phase, "running")
    H.settle(20500)
    H.eq(match.ctf.flags[2].state, "base")
    E.cancel(match)
    H.settle(500)
end)

H.test("a carrier leaving out of bounds or being dropped by the core: home, nothing strands", function()
    local match, a = live(3)
    grab(match, a[1])
    H.move(a[1], DOCKS.centre.x, DOCKS.centre.y + DOCKS.radius + 5, DOCKS.centre.z)
    H.settle(200)
    H.fire("op77_lightrp:activity:leaveRequest", a[1], "games.ctf")
    H.eq(match.ctf.flags[2].state, "base", "last seen out of bounds")
    E.cancel(match)
    H.settle(500)
    match, a = live(3)
    grab(match, a[1])
    midfield(a[1])
    H.settle(200)
    H.core.owner[a[1]] = nil
    H.coreReturn(a[1])
    H.fire("op77_lightrp:activity:dropped", a[1], "games.ctf", "timeout")
    H.eq(match.ctf.flags[2].state, "dropped", "the core released them")
    E.cancel(match)
    H.settle(500)
    H.noneInBuckets()
end)

H.test("a tie at the bell plays overtime: the next capture wins", function()
    local match, a = live(2)
    match.ctf.score = { 1, 1 }
    match.endsAt = E.now() + 900
    H.settle(1500)
    H.eq(match.phase, "running")
    H.eq(match.ctf.overtime, true)
    H.ok(match.endsAt - E.now() > 85000, "90 s more")
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].timer.label, "OVERTIME")
    capture(match, a[1])
    H.eq(match.phase, "ended")
    H.eq(match.reason, "captures", "under the limit: the overtime's rule")
    H.eq(lastResults()[a[1]].won, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("still tied after the overtime: a draw; ahead at the bell: no overtime", function()
    local match, a = live(2)
    match.endsAt = E.now() + 900
    H.settle(1200)
    H.eq(match.ctf.overtime, true)
    match.endsAt = E.now() + 300
    H.settle(600)
    H.eq(match.reason, "time")
    H.eq(lastResults()[a[1]].won, false)
    H.eq(lastResults()[a[1]].recap.lines[1].value, "Draw")
    H.settle(7000)
    match, a = live(2)
    match.ctf.score = { 2, 1 }
    match.endsAt = E.now() + 900
    H.settle(1500)
    H.eq(match.phase, "ended")
    H.eq(match.ctf.overtime, nil)
    H.eq(lastResults()[a[1]].won, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the shield: 2 s from a spawn, lost on a hit dealt or a grab", function()
    local match, a, b = live(2)
    shoot(a[1], b[1])
    H.settle(5100) -- b back on its base
    H.ok(H.players[b[1]].life == "alive", "back")
    H.eq(H.hit(a[1], b[1], AJAX), false, "shielded")
    H.settle(2600)
    H.eq(H.hit(a[1], b[1], AJAX), true, "over")
    shoot(b[1], a[1])
    H.settle(5100)
    H.eq(H.hit(b[1], a[1], AJAX), false, "a is shielded")
    H.eq(H.hit(a[1], b[1], AJAX), true, "a shoots")
    H.eq(H.hit(b[1], a[1], AJAX), true, "and gave its shield up")
    H.settle(600) -- a's landing is over
    match.players[a[1]].ctf.shieldUntil = E.now() + 5000
    grab(match, a[1])
    H.eq(match.players[a[1]].ctf.shieldUntil, nil, "a grab ends it")
    E.cancel(match)
    H.settle(500)
end)

H.test("a body dying at the flag, not told yet, takes nothing; an unreadable one neither", function()
    local match, a = live(2)
    H.players[a[1]].life = "dying"
    to(a[1], DOCKS.blueBase)
    H.settle(300)
    H.eq(match.ctf.flags[2].state, "base")
    H.players[a[1]].life = "alive"
    H.players[a[1]].fresh = false
    H.settle(300)
    H.eq(match.ctf.flags[2].state, "base")
    H.players[a[1]].fresh = true
    H.settle(300)
    H.eq(match.ctf.flags[2].state, "carried")
    E.cancel(match)
    H.settle(500)
end)

H.test("School: blue never lands on the red flag", function()
    for _ = 1, 3 do
        local match, _, b = live(2, "school")
        H.ok(E.flat(H.players[b[1]], SCHOOL.redBase) > 10, "on its half")
        H.eq(match.ctf.flags[1].state, "base")
        E.cancel(match)
        H.settle(500)
    end
end)

H.test("a forfeit: the side left wins, whatever the score", function()
    local match, a, b = live(2)
    capture(match, a[1])
    H.fire("op77_lightrp:activity:leaveRequest", a[1], "games.ctf")
    H.eq(match.reason, "forfeit")
    H.eq(lastResults()[b[1]].won, true, "whatever the score")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("everybody leaves with a flag out: abandoned, closed, nobody stranded", function()
    local match, a, b = live(2)
    grab(match, a[1])
    H.fire("op77_lightrp:activity:leaveRequest", a[1], "games.ctf")
    H.fire("onPlayerDisconnected", b[1])
    H.removePlayer(b[1])
    H.eq(match.phase, "ended")
    H.settle(7000)
    H.eq(match.closed, true)
    H.noneInBuckets()
end)

H.test("a hostile client: no event of its own, a stranger on a flag is nobody", function()
    for name in pairs(H.netHandlers) do
        H.ok(not name:find("ctf"), "this mode takes nothing from a client: " .. name)
    end
    H.ok(H.netHandlers["op77_games:ready"], "only the engine's ready reaches it")
    local match, a = live(2)
    H.addPlayer(900)
    H.eq(E.matchOf(900), nil)
    H.fireNet("op77_games:ready", 900)
    H.eq(#H.clientNamed("op77_games:hud", 900), 0)
    H.move(900, DOCKS.blueBase.x, DOCKS.blueBase.y, DOCKS.blueBase.z)
    H.settle(500)
    H.eq(match.ctf.flags[2].state, "base")
    H.fireNet("op77_games:ready", a[1])
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].activity, "games.ctf")
    H.removePlayer(900)
    E.cancel(match)
    H.settle(500)
end)

H.done("ctf_test")
