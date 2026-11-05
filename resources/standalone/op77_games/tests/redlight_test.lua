-- Red Light, Green Light: the lights, the shot, the finish, the clock, and lag.
-- Run: lua tests/redlight_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
H.advance(200)
local E, G = GamesEngine, GamesRedlight
local RL = G.rules
local core = H.core

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

local function live(n)
    local ids = players(n or 2)
    H.matchJoin("games.redlight", ids, {})
    return H.untilPhase(ids[1], "running"), ids
end

-- The lights, by hand: the next one now, and it holds until the test moves on.
local function light(match, name)
    local rl = match.rl
    if rl.light ~= name then
        rl.untilT = E.now()
        H.advance(150)
    end
    H.eq(rl.light, name, "the light")
    rl.untilT = E.now() + 1e7
end

local function run(id, course, metres)
    local p = H.players[id]
    H.move(id, course.start.x + course.dx * metres, course.start.y + course.dy * metres, p.z)
end

local function nudge(id, dx, dz)
    local p = H.players[id]
    H.move(id, p.x + dx, p.y, p.z + (dz or 0))
end

local function resultOf(id)
    local found
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if e.args[1] == id then found = e.args[3] end
    end
    return found
end

local function atStart(match, id)
    local course = match.rl.course
    return G.progress(course, H.players[id]) < 3
end

H.test("the lights' lengths: green 4 to 10 s, red 3 to 6 s", function()
    H.eq(G.duration("green", 0), 4)
    H.eq(G.duration("green", 1), 10)
    H.eq(G.duration("red", 0), 3)
    H.eq(G.duration("red", 1), 6)
    for _ = 1, 200 do
        local green, red = G.duration("green"), G.duration("red")
        H.ok(green >= 4 and green <= 10, "green")
        H.ok(red >= 3 and red <= 6, "red")
    end
end)

H.test("the course and the clock come from the map, one map", function()
    H.eq(#GamesMaps.redlight, 1)
    local map = GamesMaps.redlight[1]
    H.eq(map.id, "rocket-ramp")
    H.eq(map.timeLimit, 90)
    local course = G.course(map)
    H.ok(course.length > 180 and course.length < 195, "the course is about 187 m")
    H.ok(math.abs(course.dx * course.dx + course.dy * course.dy - 1) < 1e-9, "a unit direction")
    H.eq(G.progress(course, map.finish) >= course.length - 0.001, true, "the finish is at its end")
    H.eq(G.progress(course, { x = course.start.x - course.dx * 5, y = course.start.y - course.dy * 5, z = 0 }), 0, "behind the line is 0")
    local match, ids = live(1)
    H.eq(match.seconds, 90, "the map's limit")
    H.eq(match.endsAt - match.startedAt, 90000, "the clock runs from GO")
    E.cancel(match)
    H.settle(500)
    H.eq(H.players[ids[1]].bucket, 0, "home")
end)

H.test("on foot, no weapons, nobody hurts anybody, no scope", function()
    local before = H.scopeCount()
    local weapons = #H.weaponLog
    local match, ids = live(2)
    H.eq(H.scopeCount(), before, "no scope")
    H.eq(#H.weaponLog, weapons, "no weapon request at all")
    H.eq(H.hit(ids[1], ids[2], H.hash("Items.Preset_Ajax_Default")), false, "no hit lands")
    H.eq(core.registered["games.redlight"].caps.vehicles, false, "no RP vehicle")
    H.eq(core.registered["games.redlight"].caps.rpWeapons, false, "RP weapons aside")
    H.eq(H.teleports[#H.teleports].opts.dismount, true, "off any vehicle")
    E.cancel(match)
    H.settle(500)
end)

H.test("frozen on the line until GO, then green; the lights keep switching", function()
    local ids = players(1)
    H.matchJoin("games.redlight", ids, {})
    local match = H.untilPhase(ids[1], "countdown")
    H.eq(H.players[ids[1]].frozen, true, "held")
    local view = H.lastClient("op77_games:hud", ids[1]).args[1]
    H.eq(view.phase, "countdown")
    H.untilPhase(ids[1], "running")
    H.eq(H.players[ids[1]].frozen, false, "released")
    H.eq(match.rl.light, "green", "the first light")
    H.eq(H.lastClient("op77_games:cue", ids[1]).args[1], "green")
    local seen = { green = 0, red = 0 }
    local last = "green"
    for _ = 1, 700 do
        H.advance(100)
        if match.rl.light ~= last then
            last = match.rl.light
            seen[last] = seen[last] + 1
        end
        if match.phase ~= "running" then break end
    end
    H.ok(seen.red >= 4 and seen.green >= 4, "both lights, many times")
    E.cancel(match)
    H.settle(500)
end)

H.test("the HUD tells the light; the sound and the banner go with it", function()
    local match, ids = live(1)
    light(match, "red")
    H.settle(300)
    local id = ids[1]
    local view = H.lastClient("op77_games:hud", id).args[1]
    H.ok(view.objective:find("RED LIGHT"), "objective")
    H.eq(view.progress[1].tone, "danger")
    H.eq(H.lastClient("op77_games:cue", id).args[1], "red")
    local banners = {}
    for _, e in ipairs(H.clientNamed("op77_games:push", id)) do if e.args[1] == "banner" then banners[#banners + 1] = e.args[2] end end
    H.eq(banners[#banners].title, "RED LIGHT")
    H.eq(banners[#banners].tone, "danger")
    E.cancel(match)
    H.settle(500)
end)

H.test("moving on red: back to the start, not out, screen flinch, sound, feed", function()
    local match, ids = live(2)
    local id, course = ids[1], match.rl.course
    run(id, course, 50)
    H.settle(200)
    H.ok(math.abs(match.players[id].rl.progress - 50) < 0.01, "ran")
    light(match, "red")
    H.settle(600) -- past the grace, anchored
    nudge(id, 2)
    H.settle(600)
    H.ok(atStart(match, id), "back on the line")
    H.eq(H.players[id].bucket, match.bucket, "in the match")
    H.eq(match.players[id].rl.resets, 1)
    H.eq(match.players[id].rl.progress, 0, "progress lost")
    H.ok(E.matchOf(id) == match, "not out")
    H.eq(H.screens[#H.screens].id, id)
    H.eq(H.screens[#H.screens].name, "pain")
    H.eq(H.lastClient("op77_games:cue", id).args[1], "hit")
    H.eq(H.players[id].life, "alive", "no death")
    H.settle(1000)
    H.eq(match.players[id].rl.resets, 1, "one shot, the move back is not a second")
    E.cancel(match)
    H.settle(500)
end)

H.test("the grace: moving in the first 0.4 s of red costs nothing", function()
    local match, ids = live(1)
    local id = ids[1]
    light(match, "red")
    nudge(id, 5)
    H.advance(100)
    nudge(id, 5)
    H.settle(1500)
    H.eq(match.players[id].rl.resets, 0, "stopped inside the grace")
    E.cancel(match)
    H.settle(500)
end)

H.test("the tolerance: 0.35 m on the ground, 0.8 m up or down", function()
    local match, ids = live(1)
    local id = ids[1]
    light(match, "red")
    H.settle(600)
    nudge(id, 0.3)
    H.settle(500)
    H.eq(match.players[id].rl.resets, 0, "a drift")
    nudge(id, 0, 0.7)
    H.settle(500)
    H.eq(match.players[id].rl.resets, 0, "a landing")
    nudge(id, 0, 0.3)
    H.settle(500)
    H.eq(match.players[id].rl.resets, 1, "over the lift")
    E.cancel(match)
    H.settle(500)
end)

H.test("green: run all you like", function()
    local match, ids = live(1)
    local id, course = ids[1], match.rl.course
    light(match, "green")
    for metres = 10, 100, 10 do
        run(id, course, metres)
        H.advance(100)
    end
    H.eq(match.players[id].rl.resets, 0)
    H.ok(math.abs(match.players[id].rl.progress - 100) < 0.01, "the distance run")
    E.cancel(match)
    H.settle(500)
end)

H.test("finishers win, all of them, in order; the match ends when nobody runs", function()
    H.events = {}
    local match, ids = live(3)
    local course = match.rl.course
    light(match, "green")
    run(ids[2], course, course.length + 1)
    H.settle(1000)
    run(ids[1], course, course.length + 1)
    H.settle(300)
    H.eq(match.phase, "running", "one still runs")
    H.eq(match.players[ids[2]].rl.place, 1)
    H.eq(match.players[ids[1]].rl.place, 2)
    run(ids[3], course, course.length + 1)
    H.settle(300)
    H.eq(match.phase, "ended", "nobody left on the course")
    H.eq(match.reason, "decided")
    H.eq(resultOf(ids[2]).won, true)
    H.eq(resultOf(ids[1]).won, true)
    H.eq(resultOf(ids[3]).won, true)
    H.eq(resultOf(ids[2]).placement, 1)
    H.eq(resultOf(ids[1]).placement, 2)
    local recap = resultOf(ids[1]).recap
    H.eq(recap.rows[1].id, ids[2], "the first across on top")
    H.eq(recap.rows[1].outcome, "finished")
    H.ok(recap.rows[1].timeMs > 0, "a time")
    H.eq(recap.lines[1].value, "3 of 3")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a finisher walks free: red no longer watches them", function()
    local match, ids = live(2)
    local course = match.rl.course
    light(match, "green")
    run(ids[1], course, course.length + 1)
    H.settle(200)
    light(match, "red")
    H.settle(600)
    nudge(ids[1], 5)
    H.settle(500)
    H.eq(match.players[ids[1]].rl.resets, 0)
    H.eq(match.players[ids[1]].rl.finished, true)
    E.cancel(match)
    H.settle(500)
end)

H.test("the clock: whoever has not crossed is out; farther ranks higher", function()
    H.events = {}
    local match, ids = live(3)
    local course = match.rl.course
    light(match, "green")
    run(ids[1], course, course.length + 1)
    run(ids[2], course, 20)
    run(ids[3], course, 80)
    H.settle(300)
    match.endsAt = E.now()
    H.settle(200)
    H.eq(match.reason, "time")
    H.eq(resultOf(ids[1]).won, true)
    H.eq(resultOf(ids[2]).won, false)
    H.eq(resultOf(ids[3]).won, false)
    H.eq(resultOf(ids[3]).placement, 2)
    H.eq(resultOf(ids[2]).placement, 3)
    H.eq(resultOf(ids[3]).recap.rows[3].outcome, "out")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a fall: the progress goes, a respawn on the line, in the bucket", function()
    local match, ids = live(2)
    local id, course = ids[1], match.rl.course
    run(id, course, 60)
    H.settle(200)
    H.die(id)
    H.eq(match.players[id].rl.progress, 0)
    H.eq(match.players[id].rl.resets, 1)
    H.settle(2500)
    H.eq(H.players[id].life, "alive")
    H.eq(H.players[id].bucket, match.bucket, "in the match")
    H.ok(atStart(match, id), "on the line")
    E.cancel(match)
    H.settle(500)
end)

H.test("alone: the course is yours, crossing wins", function()
    H.events = {}
    local match, ids = live(1)
    light(match, "green")
    run(ids[1], match.rl.course, match.rl.course.length + 1)
    H.settle(300)
    H.eq(match.phase, "ended")
    H.eq(resultOf(ids[1]).won, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a runner who leaves does not hold the others up; all gone closes it", function()
    H.events = {}
    local match, ids = live(2)
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.redlight")
    H.eq(match.phase, "running", "an event goes on alone")
    run(ids[2], match.rl.course, match.rl.course.length + 1)
    light(match, match.rl.light)
    H.settle(300)
    H.eq(match.phase, "ended")
    H.eq(resultOf(ids[1]).won, false, "the one who left")
    H.eq(resultOf(ids[1]).stats.quit, true)
    H.settle(7000)
    H.noneInBuckets()
end)

-- ---------------------------------------------------------------- lag --

H.test("lag: the grace grows with the ping, up to its cap, never shrinks", function()
    local id = players(1)[1]
    H.eq(G.graceMs(id), 400, "no ping known: the base")
    H.players[id].ping = 150
    H.eq(G.graceMs(id), 550)
    H.players[id].ping = 5000
    H.eq(G.graceMs(id), 700, "capped")
    H.ok(RL.grace >= 0.4, "at least the source's grace")
    H.ok(RL.tolerance >= 0.35, "at least its tolerance")
end)

H.test("lag: a high ping stopping late is not shot", function()
    local match, ids = live(1)
    local id = ids[1]
    H.players[id].ping = 250
    light(match, "red")
    H.settle(300)
    nudge(id, 3) -- past the base grace (400 ms), inside this player's (650 ms)
    H.settle(100)
    nudge(id, 3)
    H.settle(1200)
    H.eq(match.players[id].rl.resets, 0, "their stop was on its way")
    E.cancel(match)
    H.settle(500)
end)

H.test("lag: a reading dated from before the grace ended never counts", function()
    local match, ids = live(1)
    local id = ids[1]
    local p = H.players[id]
    light(match, "red")
    p.ageMs = 450 -- a reading from when the light was still green, seen late
    H.settle(600)
    nudge(id, 2)
    H.settle(300)
    p.ageMs = 0
    H.settle(700)
    H.eq(match.players[id].rl.resets, 0, "anchored on its first good reading")
    nudge(id, 2)
    H.settle(400)
    H.eq(match.players[id].rl.resets, 1, "and judged from there")
    E.cancel(match)
    H.settle(500)
end)

H.test("lag: one reading over the line is not enough", function()
    local match, ids = live(1)
    local id = ids[1]
    local p = H.players[id]
    light(match, "red")
    H.settle(600)
    local x = p.x
    H.move(id, x + 3)
    H.advance(100)
    H.move(id, x)
    H.settle(1000)
    H.eq(match.players[id].rl.resets, 0, "a blip, gone at the next reading")
    E.cancel(match)
    H.settle(500)
end)

H.test("lag: a gap freezes the check, the catch-up is forgiven once per red, not twice", function()
    local match, ids = live(1)
    local id = ids[1]
    local p = H.players[id]
    light(match, "red")
    H.settle(600)
    p.fresh = false
    H.settle(1500)
    H.eq(match.players[id].rl.resets, 0, "cannot tell")
    H.move(id, p.x + 2)
    p.fresh = true
    H.settle(1000)
    H.eq(match.players[id].rl.resets, 0, "a catch-up jump is not a shot")
    p.fresh = false
    H.settle(1000)
    H.move(id, p.x + 2)
    p.fresh = true
    H.settle(1000)
    H.eq(match.players[id].rl.resets, 1, "a second gap in one red is not forgiven: no walking on red by cutting your own link")
    -- the next red forgives again
    light(match, "green")
    light(match, "red")
    H.settle(600)
    p.fresh = false
    H.settle(1000)
    H.move(id, p.x + 2)
    p.fresh = true
    H.settle(1000)
    H.eq(match.players[id].rl.resets, 1, "a new red, a new pardon")
    E.cancel(match)
    H.settle(500)
end)

H.test("a stale reading finishes nobody; a body on its way back is not judged", function()
    local match, ids = live(1)
    local id = ids[1]
    local p = H.players[id]
    light(match, "green")
    p.ageMs = 800
    run(id, match.rl.course, match.rl.course.length + 1)
    H.settle(500)
    H.eq(match.players[id].rl.finished, nil, "too old to say")
    p.ageMs = 0
    H.move(id, match.rl.course.start.x)
    H.settle(300)
    H.teleportFails = false
    local held = match.players[id]
    held.holdUntil = E.now() + 1e6
    light(match, "red")
    H.settle(600)
    nudge(id, 5)
    H.settle(600)
    H.eq(held.rl.resets, 0, "a moving body is left alone")
    held.holdUntil = 0
    E.cancel(match)
    H.settle(500)
end)

H.test("a hostile client: nothing it sends moves the game, only its body counts", function()
    local match, ids = live(1)
    local id = ids[1]
    for name in pairs(H.netHandlers) do
        H.ok(not name:find("finish") and not name:find("light"), name .. " is a game event from a client")
    end
    H.fireNet("op77_games:ready", id, { finished = true, progress = 9999 })
    H.settle(200)
    H.eq(match.players[id].rl.finished, nil, "no word of a client finishes anything")
    H.eq(match.phase, "running")
    E.cancel(match)
    H.settle(500)
end)

H.done("redlight_test")
