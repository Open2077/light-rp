-- The hooks the zone and flag modes needed from the engine, and client/objectives.lua: what a
-- server list becomes in the world. Run: lua tests/objectives_test.lua
local H = dofile("tests/harness.lua")

H.markers, H.blips = {}, {}
H.markerLog, H.blipLog = {}, {}
local seq = 0
local function handle() seq = seq + 1 return tostring(seq) end
Open77.markers = {
    create = function(options)
        if H.markerRefused then return nil, H.markerRefused end
        local id = handle()
        H.markers[id] = options
        H.markerLog[#H.markerLog + 1] = { "create", id }
        return id
    end,
    update = function(id, patch)
        H.markerLog[#H.markerLog + 1] = { "update", id, patch }
        return true
    end,
    remove = function(id) H.markers[id] = nil return true end,
}
Open77.blips = {
    create = function(options)
        local id = handle()
        H.blips[id] = options
        return id
    end,
    setPosition = function(id, position)
        H.blipLog[#H.blipLog + 1] = { id, position }
        return true
    end,
    remove = function(id) H.blips[id] = nil return true end,
}

-- A test mode: the engine's new doors, nothing else.
local seen = { left = {}, damage = 0 }
H.loadServer()
H.advance(200)
local E = GamesEngine
local verdict
E.mode({
    id = "games.hooks", key = "hooks", label = "Hooks", kind = "pvp", minPlayers = 2, maxPlayers = 8,
    maps = GamesMaps.tdm, pvp = true, seconds = 600,
    weapons = function(_, p) return { { record = p.id % 2 == 1 and "Items.Preset_Ajax_Default" or "Items.Preset_Nova_Default", slot = 1, reserve = 10 } } end,
    damage = function(_, event, attacker, victim)
        seen.damage = seen.damage + 1
        seen.event, seen.attacker, seen.victim = event, attacker, victim
        if verdict == "raise" then error("boom") end
        return verdict
    end,
    left = function(_, p, how) seen.left[#seen.left + 1] = { p.id, how } end,
})

local function ids(a, b)
    H.addPlayer(a)
    H.addPlayer(b)
    return { a, b }
end

H.test("weapons as a function: each body its own set", function()
    local list = ids(1, 2)
    H.matchJoin("games.hooks", list)
    local match = H.untilPhase(1, "running")
    H.eq(H.weapons[1][1], "Items.Preset_Ajax_Default")
    H.eq(H.weapons[2][1], "Items.Preset_Nova_Default")
    local ajax = H.hash("Items.Preset_Ajax_Default")
    H.eq(GamesCombat.slotOf(match.players[1], ajax), 1)
    H.eq(GamesCombat.slotOf(match.players[1], "0xdead"), nil)
    H.eq(GamesCombat.accepts(match.players[1], ajax), true)

    H.eq(H.hit(1, 2, ajax), true, "nil lets it through")
    H.eq(seen.damage, 1)
    H.eq(seen.attacker.id, 1)
    H.eq(seen.victim.id, 2)
    H.eq(seen.event.attackKind, "ranged")
    H.eq(match.players[2].lastHitBy, 1)
    match.players[2].lastHitBy = nil
    verdict = false
    H.eq(H.hit(1, 2, ajax), false, "false refuses")
    H.eq(match.players[2].lastHitBy, nil, "a refused hit is nobody's")
    verdict = "raise"
    H.eq(H.hit(1, 2, ajax), false, "a hook that raises refuses too")
    H.ok(H.logged("damage hook of games.hooks failed"), "and says so")
    verdict = nil
    H.eq(H.hit(1, 2, "0xdead"), false, "the engine's own gate comes first")
    H.eq(seen.damage, 3, "the hook never heard that one")

    H.fire("op77_lightrp:activity:leaveRequest", 1, "games.hooks")
    H.eq(seen.left[1][1], 1)
    H.eq(seen.left[1][2], "left")
    H.settle(7000)
    H.eq(seen.left[2][1], 2)
    H.eq(seen.left[2][2], "ended")
end)

H.test("left runs on a disconnect and a cancel", function()
    seen.left = {}
    local list = ids(3, 4)
    H.matchJoin("games.hooks", list)
    local match = H.untilPhase(3, "running")
    H.fire("onPlayerDisconnected", 3)
    H.removePlayer(3)
    H.eq(seen.left[1][2], "disconnect")
    H.settle(7000)
    H.eq(match.closed, true)
    H.eq(seen.left[2][2], "ended")
end)

dofile("client/objectives.lua")
GamesProphuntClient = GamesProphuntClient or { keys = function() end } -- another mode's client
dofile("client/main.lua")
local O = GamesObjectives
local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local RED = { r = 255, g = 70, b = 70, a = 200 }
local WHITE = { r = 255, g = 255, b = 255, a = 150 }
local function ring(color, x)
    return { markers = { point = { position = { x = x or 1, y = 2, z = 3 }, shape = "ring", radius = 8, height = 1, color = color } },
        blips = { point = { position = { x = x or 1, y = 2, z = 3 }, title = "The point" } } }
end

H.test("a marker and a pin once, not again for the same state", function()
    O.sync(ring(WHITE))
    H.eq(count(H.markers), 1)
    H.eq(count(H.blips), 1)
    local before = #H.markerLog
    O.sync(ring(WHITE))
    H.eq(#H.markerLog, before, "nothing to do")
    local _, options = next(H.markers)
    H.eq(options.shape, "ring")
    H.eq(options.maxDistance, 400)
    local _, blip = next(H.blips)
    H.eq(blip.title, "The point")
    H.eq(blip.sprite, "objective")
    H.eq(blip.active, true)
end)

H.test("a colour or a position changes by update, never by a new mesh", function()
    O.sync(ring(RED))
    H.eq(count(H.markers), 1)
    H.eq(H.markerLog[#H.markerLog][1], "update")
    H.eq(H.markerLog[#H.markerLog][3].color, RED)
    H.eq(H.markerLog[#H.markerLog][3].position, nil, "only what changed")
    O.sync(ring(RED, 9))
    H.eq(H.markerLog[#H.markerLog][3].position.x, 9)
    H.eq(H.blipLog[#H.blipLog][2].x, 9)
end)

H.test("what the list drops goes, nil clears everything, a refusal does not raise", function()
    O.sync({ markers = {}, blips = ring(RED).blips })
    H.eq(count(H.markers), 0)
    H.eq(count(H.blips), 1)
    O.sync(nil)
    H.eq(count(H.blips), 0)
    H.markerRefused = "world_unavailable"
    O.sync(ring(WHITE))
    H.eq(count(H.markers), 0)
    H.markerRefused = nil
    O.sync(ring(WHITE))
    H.eq(count(H.markers), 1, "the next list tries again")
    O.sync(nil)
    O.sync("junk")
end)

H.test("the HUD event: the world is split off the view, a clear takes it away", function()
    local shows = {}
    local old = exports.op77_lightrp
    exports.op77_lightrp = { ActivityHudShow = function(_, view) shows[#shows + 1] = view return true end,
        ActivityHudClear = function() return true end }
    local view = ring(WHITE)
    view = { activity = "games.control", phase = "running", world = view }
    H.fireNet("op77_games:hud", nil, view)
    H.eq(shows[1].world, nil, "ActivityHud never sees it")
    H.eq(count(H.markers), 1)
    H.fireNet("op77_games:hud", nil, { activity = "games.tdm", phase = "running" })
    H.eq(count(H.markers), 0, "a mode with no world: nothing left over")
    H.fireNet("op77_games:hud", nil, { activity = "games.control", phase = "running", world = ring(RED) })
    H.fireNet("op77_games:clear", nil)
    H.eq(count(H.markers), 0)
    H.eq(count(H.blips), 0)
    exports.op77_lightrp = old
end)

H.done("objectives_test")
