-- Control: rules lifted from the source mode, on the engine. The zone logic is pure and tested
-- on plain tables first; then whole matches.
-- Run: lua tests/control_test.lua
local H = dofile("tests/harness.lua")

H.damages = {}
Open77.players.damage = function(id, amount, options)
    H.damages[#H.damages + 1] = { id = id, amount = amount, options = options }
    return true
end

H.loadServer()
H.advance(200)
local E, G = GamesEngine, GamesControl
local R = G.rules
local AJAX = H.hash("Items.Preset_Ajax_Default")
local MAP = H.mapsOf("control")[1]

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

-- Two even teams, running. Red are a's, blue are b's.
local function live(n)
    local ids = players(n)
    local teams = { {}, {} }
    for index, id in ipairs(ids) do table.insert(teams[index % 2 == 1 and 1 or 2], id) end
    H.matchJoin("games.control", ids, { teams = teams })
    return H.untilPhase(ids[1], "running"), teams[1], teams[2]
end

local function onPoint(id) H.move(id, MAP.point.x + 1, MAP.point.y, MAP.point.z) end
local function away(id) H.move(id, MAP.centre.x + 25, MAP.centre.y, MAP.centre.z) end

local function lastResults()
    local byId = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    return byId
end

local function zoneWith(red, blue, owner)
    local zone = G.newZone({ x = 0, y = 0, z = 0 })
    zone.owner = owner or 0
    local bodies = {}
    for index = 1, red do bodies[#bodies + 1] = { id = index, side = 1, at = { x = 0, y = 0, z = 0 } } end
    for index = 1, blue do bodies[#bodies + 1] = { id = 100 + index, side = 2, at = { x = 1, y = 0, z = 0 } } end
    G.count(zone, bodies)
    return zone
end

local function run(zone, seconds)
    local result
    for _ = 1, math.floor(seconds * 10 + 0.5) do
        local step = G.capture(zone, 0.1)
        result = result or step
    end
    return result
end

H.test("the point is a cylinder: radius 8, 4 m up, 1.5 m down", function()
    local pos = { x = 0, y = 0, z = 10 }
    H.eq(G.inside(pos, { x = 8, y = 0, z = 10 }), true)
    H.eq(G.inside(pos, { x = 8.1, y = 0, z = 10 }), false)
    H.eq(G.inside(pos, { x = 0, y = 0, z = 14 }), true, "up to 4 above")
    H.eq(G.inside(pos, { x = 0, y = 0, z = 14.1 }), false)
    H.eq(G.inside(pos, { x = 0, y = 0, z = 8.5 }), true, "1.5 below")
    H.eq(G.inside(pos, { x = 0, y = 0, z = 8.4 }), false)
end)

H.test("the count: who stands there, contested, the holder", function()
    H.eq(zoneWith(2, 0).holder, 1)
    H.eq(zoneWith(0, 3).holder, 2)
    local both = zoneWith(1, 1)
    H.eq(both.contested, true)
    H.eq(both.holder, nil)
    H.eq(#both.on[1], 1)
    H.eq(zoneWith(0, 0).contested, false)
end)

H.test("the capture: 5 s alone, more bodies faster, capped at twice", function()
    local one = zoneWith(1, 0)
    H.eq(run(one, 4.8), nil)
    H.eq(one.owner, 0)
    H.eq(run(one, 0.3), "taken")
    H.eq(one.owner, 1)
    H.eq(one.progress, 0)
    H.eq(one.capturer, 0)
    local two = zoneWith(2, 0)
    H.eq(run(two, 3.5), "taken", "x1.5")
    local three = zoneWith(3, 0)
    H.eq(run(three, 2.6), "taken", "x2")
    local eight = zoneWith(8, 0)
    H.eq(run(eight, 2.4), nil, "still x2")
end)

H.test("contested freezes, empty fades, the owner undoes, the other side's progress goes first", function()
    local zone = zoneWith(1, 0)
    run(zone, 2.5)
    H.ok(math.abs(zone.progress - 0.5) < 0.01)
    local frozen = zone.progress
    G.count(zone, { { id = 1, side = 1, at = zone.pos }, { id = 2, side = 2, at = zone.pos } })
    run(zone, 3)
    H.eq(zone.progress, frozen, "contested")
    G.count(zone, {})
    run(zone, 1)
    H.ok(math.abs(zone.progress - 0.3) < 0.01, "fades")
    H.eq(zone.capturer, 1)
    G.count(zone, { { id = 2, side = 2, at = zone.pos } })
    run(zone, 1)
    H.ok(math.abs(zone.progress - 0.1) < 0.01, "undone before blue starts")
    H.eq(zone.capturer, 1)
    run(zone, 0.6)
    H.eq(zone.capturer, 2, "then blue's")
    H.ok(zone.progress > 0)

    local owned = zoneWith(0, 1, 1)
    run(owned, 1)
    H.eq(owned.capturer, 2)
    G.count(owned, { { id = 1, side = 1, at = owned.pos } })
    H.eq(G.capture(owned, 0.1), "held", "the owner banks and undoes")
    run(owned, 1.2)
    H.eq(owned.progress, 0)
    H.eq(owned.capturer, 0)
end)

H.test("the leader is read on the raw score", function()
    H.eq(G.leader({ 10.2, 10.1 }), 1)
    H.eq(G.leader({ 3, 4 }), 2)
    H.eq(G.leader({ 7, 7 }), nil)
end)

H.test("overtime: only with the trailing team on the point, 30 s past the bell at most", function()
    local zone = G.newZone({ x = 0, y = 0, z = 0 })
    zone.count = { 0, 1 }
    local c = { score = { 10, 5 }, zone = zone }
    H.eq(G.overtime(c, 10000, 8000), nil, "not yet")
    H.eq(G.overtime(c, 10000, 9500), 10500)
    H.eq(c.overtimeUntil, 40000)
    H.eq(G.overtime(c, 10500, 39500), 40000, "the cap")
    H.eq(G.overtime(c, 40000, 39900), 40000, "stays")
    zone.count = { 1, 0 }
    H.eq(G.overtime(c, 10000, 9500), nil, "the leader alone on it: no overtime")
    zone.count = { 2, 2 }
    H.eq(G.overtime(c, 10000, 9500), 10500, "contested counts")
    c.score = { 7, 7 }
    H.eq(G.overtime(c, 10000, 9500), nil, "level: nobody trails")
end)

H.test("the spawn circles: 12 m, never reaching the point, none when too small", function()
    local guards = G.guards(MAP)
    H.eq(guards[1].radius, 12)
    H.eq(guards[2].radius, 12)
    H.eq(guards[1].pos, MAP.redSpawn)
    local near = { redSpawn = { x = 0, y = 0, z = 0 }, blueSpawn = { x = 18, y = 0, z = 0 }, point = { x = 16, y = 0, z = 0 } }
    local tight = G.guards(near)
    H.eq(tight[1].radius, 5, "16 - 8 - 3")
    H.eq(tight[2].radius, 0, "under 4: none")
end)

H.test("camping: a grace of 2 s, then a sting a second, gone on leaving", function()
    local guard = { pos = { x = 0, y = 0, z = 0 }, radius = 12 }
    local state = {}
    local at = { x = 1, y = 0, z = 0 }
    H.eq(G.camped(state, guard, at, 1000), false)
    H.eq(state.inSpawn, 1000)
    H.eq(G.camped(state, guard, at, 2900), false)
    H.eq(G.camped(state, guard, at, 3000), true)
    H.eq(G.camped(state, guard, at, 3500), false)
    H.eq(G.camped(state, guard, at, 4000), true)
    H.eq(G.camped(state, guard, { x = 20, y = 0, z = 0 }, 4100), false)
    H.eq(state.inSpawn, nil)
    H.eq(G.camped(state, guard, nil, 4200), false, "dead or unreadable: no sting")
    H.eq(G.camped(state, { pos = guard.pos, radius = 0 }, at, 9000), false, "no circle")
end)

H.test("the map: one, its points placed, its play area covers them", function()
    H.eq(#H.mapsOf("control"), 1)
    H.eq(MAP.id, "kang-tao")
    H.ok(MAP.point and MAP.redSpawn and MAP.blueSpawn, "points")
    H.eq(#MAP.spawns, 2)
    for _, spot in ipairs({ MAP.redSpawn, MAP.blueSpawn, MAP.point }) do
        H.ok(E.distance(spot, MAP.centre) + 15 <= MAP.radius + 0.001, "covered")
    end
    local def = H.ok(H.core.registered["games.control"], "registered")
    H.eq(def.kind, "pvp")
    H.eq(#def.modes, 1)
    H.eq(def.modes[1].id, "kang-tao")
end)

H.test("each team starts on its spawn, armed; live: alone on the point, taken, then banked", function()
    local match, a, b = live(2)
    H.ok(E.flat(H.players[a[1]], MAP.redSpawn) <= 3.01, "red's spawn")
    H.ok(E.flat(H.players[b[1]], MAP.blueSpawn) <= 3.01, "blue's spawn")
    H.eq(H.weapons[a[1]][1], "Items.Preset_Ajax_Default")
    onPoint(a[1])
    H.settle(4000)
    H.eq(match.control.zone.owner, 0, "not yet")
    H.settle(1500)
    H.eq(match.control.zone.owner, 1, "taken")
    H.eq(match.players[a[1]].ctl.takes, 1)
    H.settle(3000)
    local score = match.control.score[1]
    H.ok(score >= 2 and score <= 4, "banked about 3 s, got " .. score)
    H.eq(match.control.score[2], 0)
    onPoint(b[1])
    H.settle(1000)
    local frozen = match.control.score[1]
    H.settle(1000)
    H.eq(match.control.score[1], frozen, "contested: nothing banked")
    away(a[1])
    away(b[1])
    H.settle(1000)
    H.eq(match.control.score[1], frozen, "nobody there: nothing banked")
    H.eq(match.control.zone.owner, 1, "still theirs")
    E.cancel(match)
    H.settle(500)
end)

H.test("the HUD and the world: seconds, the objective, a ring and a pin, only for the match", function()
    local mark = #H.clientEvents
    local match, a, b = live(2)
    onPoint(a[1])
    H.settle(2600)
    local view = H.lastClient("op77_games:hud", a[1]).args[1]
    H.eq(view.objective, "Capturing: stay on the point")
    H.eq(view.progress[1].id, "capture")
    H.eq(view.teams[1].self, true)
    H.eq(view.world.markers.point.shape, "ring")
    H.eq(view.world.markers.point.radius, 8)
    H.eq(view.world.markers.point.color.b, 255, "white: nobody's")
    H.eq(view.world.blips.point.title, "The point")
    H.eq(H.lastClient("op77_games:hud", b[1]).args[1].objective, "Stop the capture")
    H.settle(3200)
    view = H.lastClient("op77_games:hud", b[1]).args[1]
    H.eq(view.world.markers.point.color.r, 255)
    H.eq(view.world.markers.point.color.b, 70, "red's now")
    H.eq(view.objective, "Take the point back")
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].objective, "Hold the point")
    for index = mark + 1, #H.clientEvents do
        local event = H.clientEvents[index]
        if event.name == "op77_games:hud" then H.ok(event.target == a[1] or event.target == b[1], "nobody else") end
    end
    E.cancel(match)
    H.settle(500)
end)

H.test("first to 180 wins at once", function()
    local match, a, b = live(2)
    match.control.zone.owner = 1
    match.control.score[1] = R.target - 0.5
    onPoint(a[1])
    H.settle(1200)
    H.eq(match.phase, "ended")
    H.eq(match.reason, "target")
    local results = lastResults()
    H.eq(results[a[1]].won, true)
    H.eq(results[a[1]].placement, 1)
    H.eq(results[b[1]].won, false)
    H.eq(results[a[1]].recap.winnerSide, 1)
    H.eq(results[a[1]].recap.sides[1].score, math.floor(match.control.score[1]))
    H.eq(results[a[1]].recap.rows[1].id, a[1])
    H.ok(results[a[1]].recap.rows[1].holdS >= 0)
    H.eq(results[a[1]].unranked, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the clock: the leader wins, a tie is a draw", function()
    local match, a, b = live(2)
    match.control.score = { 3, 40 }
    match.endsAt = E.now() + 300
    H.settle(600)
    H.eq(match.reason, "time")
    H.eq(lastResults()[b[1]].won, true)
    H.eq(lastResults()[a[1]].won, false)
    H.settle(7000)
    match, a = live(2)
    match.endsAt = E.now() + 300
    H.settle(600)
    H.eq(match.reason, "time")
    H.eq(lastResults()[a[1]].won, false)
    H.eq(lastResults()[a[1]].recap.winnerSide, nil)
    H.eq(lastResults()[a[1]].recap.lines[1].value, "Draw")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("overtime in a match: held open while they stand there, shut when they leave", function()
    local match, a, b = live(2)
    match.control.score = { 50, 10 }
    onPoint(b[1])
    match.endsAt = E.now() + 1500
    H.settle(3000)
    H.eq(match.phase, "running", "the trailing team holds the clock open")
    H.eq(match.control.overtime, true)
    H.settle(300)
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].timer.label, "OVERTIME")
    away(b[1])
    H.settle(1300)
    H.eq(match.phase, "ended", "off the point: over")
    H.eq(match.reason, "time")
    H.eq(lastResults()[a[1]].won, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("overtime stops at 30 s even on the point", function()
    local match, _, b = live(2)
    match.control.score = { 50, 10 }
    onPoint(b[1])
    local bell = E.now() + 500
    match.endsAt = bell
    H.settle(29000)
    H.eq(match.phase, "running")
    H.settle(2000)
    H.eq(match.phase, "ended")
    H.eq(match.control.overtimeUntil, bell + 30000, "the cap")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the enemy spawn: a sting after the grace, no shots from it, your own is safe", function()
    local match, a, b = live(2)
    H.settle(300)
    local spawn = MAP.blueSpawn
    H.move(a[1], spawn.x + 1, spawn.y, spawn.z)
    H.settle(1500)
    H.eq(#H.damages, 0, "the grace")
    H.eq(H.hit(a[1], b[1], AJAX), false, "nobody shoots from inside the enemy spawn")
    H.settle(1000)
    H.eq(#H.damages, 1)
    H.eq(H.damages[1].id, a[1])
    H.eq(H.damages[1].amount, 20)
    H.eq(H.damages[1].options.attacker, nil, "nobody's kill")
    H.settle(2000)
    H.eq(#H.damages, 3, "a sting a second")
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].objective, "Leave the enemy spawn")
    away(a[1])
    H.settle(1500)
    H.eq(#H.damages, 3, "out")
    H.eq(H.hit(a[1], b[1], AJAX), true, "shoots again")
    H.move(b[1], spawn.x, spawn.y, spawn.z)
    H.settle(3000)
    H.eq(#H.damages, 3, "your own spawn is safe")
    E.cancel(match)
    H.settle(500)
end)

H.test("dead, unreadable, or landing: a body counts for nothing", function()
    local match, a, b = live(2)
    onPoint(a[1])
    H.settle(1000)
    H.eq(match.control.zone.count[1], 1)
    H.players[a[1]].fresh = false
    H.settle(300)
    H.eq(match.control.zone.count[1], 0, "unreadable")
    H.players[a[1]].fresh = true
    H.settle(300)
    H.eq(match.control.zone.count[1], 1)
    H.eq(match.players[a[1]].ctl.onPoint, true)
    H.eq(H.hit(b[1], a[1], AJAX), true)
    H.die(a[1], b[1])
    H.settle(200)
    H.eq(match.control.zone.count[1], 0, "dead")
    E.cancel(match)
    H.settle(500)
end)

H.test("a kill on the point is worth more on the board; a short team comes back faster", function()
    local match, a, b = live(3)
    onPoint(b[1])
    H.settle(300)
    H.eq(H.hit(a[1], b[1], AJAX), true)
    H.die(b[1], a[1])
    H.settle(100)
    H.eq(match.players[a[1]].ctl.pointKills, 1, "the victim stood on it")
    H.eq(match.players[b[1]].ctl.onPoint, false)
    H.ok(match.players[b[1]].respawnAt - E.now() <= 4000, "a man down: a second less, got " .. (match.players[b[1]].respawnAt - E.now()))
    H.die(a[1], b[1])
    H.settle(100)
    H.ok(match.players[a[1]].respawnAt - E.now() > 4000, "the bigger team waits the full 5 s")
    E.cancel(match)
    H.settle(500)
end)

H.test("leaving mid-match: a holder gone stops banking; the last of a side forfeits", function()
    local match, a, b = live(3)
    onPoint(a[1])
    onPoint(a[2])
    H.settle(4000)
    H.eq(match.control.zone.owner, 1)
    H.fire("op77_lightrp:activity:leaveRequest", a[1], "games.control")
    H.eq(match.phase, "running")
    H.fire("onPlayerDisconnected", a[2])
    H.removePlayer(a[2])
    H.eq(match.reason, "forfeit")
    local results = lastResults()
    H.eq(results[b[1]].won, true, "the side left wins whatever the score")
    H.eq(results[a[1]].won, false)
    H.eq(results[a[1]].recap.winnerSide, 2)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("everybody leaves: abandoned, nobody wins, the match closes", function()
    local match, a, b = live(2)
    match.control.score = { 9, 2 }
    H.fire("onPlayerDisconnected", a[1])
    H.removePlayer(a[1])
    H.fire("op77_lightrp:activity:leaveRequest", b[1], "games.control")
    H.eq(match.phase, "ended")
    H.settle(7000)
    H.eq(match.closed, true)
    H.noneInBuckets()
end)

H.test("a hostile client: no event of its own, a stranger's ready gets nothing", function()
    for name in pairs(H.netHandlers) do
        H.ok(not name:find("control"), "this mode takes nothing from a client: " .. name)
    end
    H.ok(H.netHandlers["op77_games:ready"], "only the engine's ready reaches it")
    local match, a = live(2)
    H.addPlayer(900)
    H.eq(E.matchOf(900), nil)
    H.fireNet("op77_games:ready", 900)
    H.eq(#H.clientNamed("op77_games:hud", 900), 0)
    H.move(900, MAP.point.x, MAP.point.y, MAP.point.z)
    H.settle(1000)
    H.eq(match.control.zone.count[1] + match.control.zone.count[2], 0, "a stranger on the point is nobody")
    H.fireNet("op77_games:ready", a[1])
    H.eq(H.lastClient("op77_games:hud", a[1]).args[1].activity, "games.control")
    H.removePlayer(900)
    E.cancel(match)
    H.settle(500)
end)

H.done("control_test")
