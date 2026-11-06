-- The square's camera tour after the hall (client/core/arrival_tour.lua) and the spread of the
-- arrival points (server/main.lua Spawn.scatter).
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("shared/tutorial.lua")
local E = LightRpEvents
local T = LightRpTutorialConfig.arrivalTour
assert(T and T.enabled, "the tour is configured")

-- ── Spawn.scatter (server/main.lua) ──
LightRP = { module = function(name, t) LightRP[name] = t; return t end, log = function() end, eachModule = function() end }
local main = assert(loadfile("server/main.lua"))
pcall(main) -- the module table is what we need; its handlers need the host
local Spawn = LightRP.spawn
assert(Spawn and Spawn.scatter, "Spawn.scatter exists")
local c = { x = 10, y = 20, z = 5 }
assert(Spawn.scatter(c, nil) == c and Spawn.scatter(c, 0) == c, "no radius: the point itself")
local seen = {}
for i = 1, 200 do
    local p = Spawn.scatter(c, 3)
    local d = math.sqrt((p.x - c.x) ^ 2 + (p.y - c.y) ^ 2)
    assert(d <= 3.0001 and d >= 3 * math.sqrt(0.12) - 0.0001, "inside the disc, never on the centre: " .. d)
    assert(p.z == c.z, "the height is kept")
    seen[("%.1f,%.1f"):format(p.x, p.y)] = true
end
local n = 0; for _ in pairs(seen) do n = n + 1 end
assert(n > 50, "spread, not one spot")

-- ── the tour (client) ──
local t, net, threads, sent, cams, logs = 100.0, {}, {}, {}, {}, {}
local character = { alive = true, position = { x = -760, y = 790, z = 22.4 } }
local loadingNow, covered, frozen, hudAll = false, false, false, true
Open77 = {
    time = { monotonic = function() return t end },
    character = { state = function() return character end, setFrozen = function(v) frozen = v; return true end },
    screen = { isLoading = function() return loadingNow end, loadingState = function() return { active = loadingNow } end },
    hud = { setVisible = function(_, v) hudAll = v; return true end },
    input = { keyFor = function() return "SPACE" end },
    camera = {
        create = function(o) cams[#cams + 1] = { opts = o, transforms = 0 }; return #cams end,
        activate = function() return true end,
        deactivate = function() cams[#cams].deactivated = true; return true end,
        destroy = function(id) cams[id].destroyed = true end,
        setTransform = function(id) cams[id].transforms = cams[id].transforms + 1 end,
        lookAt = function() end,
    },
    players = { isInVehicle = function() return false end },
}
LightRpUi = { log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end, send = function(name, p) sent[#sent + 1] = { name = name, p = p } end, dialogs = {} }
GetResourceState = function(name) return name == "op77_loadscreen" and "running" or "missing" end
exports = { op77_loadscreen = { isActive = function() return covered end } }
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function() end
TriggerEvent = function() end
SetTimeout = function(_, fn) fn() end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() end
GetCurrentResourceName = function() return "op77_lightrp" end
dofile("client/core/arrival_tour.lua")
local Tour = LightRpArrivalTour

local center = { x = -756.581, y = 777.257, z = 22.454 }
-- the pose: starts wide and high, ends closer and lower, always around the centre
local p0 = Tour.pose(center, 0, 0)
local p1 = Tour.pose(center, 0, 1)
local function flat(p) return math.sqrt((p.x - center.x) ^ 2 + (p.y - center.y) ^ 2) end
assert(math.abs(flat(p0) - T.radius) < 0.01 and math.abs(p0.z - center.z - T.height) < 0.01)
assert(math.abs(flat(p1) - T.endRadius) < 0.01 and math.abs(p1.z - center.z - T.endHeight) < 0.01)

-- the move is still loading: nothing starts
covered = true
net[E.net.arrivalTour]({ center = center })
assert(Tour.pending() and not Tour.active())
Tour.tick(); t = t + 5; Tour.tick()
assert(not Tour.active() and #cams == 0, "the loading cover holds it")
covered = false
Tour.tick()
assert(not Tour.active(), "then it settles first")
t = t + T.settleMs / 1000 * 0.5; Tour.tick()
assert(not Tour.active(), "still settling")
loadingNow = true; Tour.tick(); loadingNow = false
t = t + T.settleMs / 1000 * 0.9; Tour.tick()
assert(not Tour.active(), "a loading screen in between starts the settling again")
t = t + T.settleMs / 1000 + 0.1; Tour.tick()
assert(Tour.active() and #cams == 1, "standing there, settled: the tour starts")
assert(frozen == true and hudAll == false, "the body held, the HUD hidden")
assert(sent[#sent].name == E.page.arrivalTour and sent[#sent].p.title == T.title and sent[#sent].p.skip == "SPACE", "the caption")
for _ = 1, 5 do t = t + 0.5; Tour.tick() end
assert(cams[1].transforms == 5, "the camera moves every step")
t = t + T.seconds; Tour.tick()
assert(not Tour.active() and cams[1].deactivated and cams[1].destroyed, "the end: back to the player")
assert(frozen == false and hudAll == true and sent[#sent].p == false, "body, HUD and caption given back")

-- skip, and a death in the middle
net[E.net.arrivalTour]({ center = center }); t = t + 1; Tour.tick(); t = t + 3; Tour.tick()
assert(Tour.active()); Tour.skip()
assert(not Tour.active() and frozen == false and sent[#sent].p == false, "the skip key")
net[E.net.arrivalTour]({ center = center }); t = t + 1; Tour.tick(); t = t + 3; Tour.tick()
assert(Tour.active()); character.alive = false; Tour.tick()
assert(not Tour.active() and frozen == false, "a death ends it")
character.alive = true

-- too far from the square (a skip from the city, a failed move): never starts, given up
character.position = { x = 0, y = 0, z = 0 }
net[E.net.arrivalTour]({ center = center })
for _ = 1, 10 do t = t + 7; Tour.tick() end
assert(not Tour.active() and not Tour.pending(), "far away: given up after waitSeconds")
assert(net[E.net.arrivalTour]({ center = { x = "a" } }) == nil and not Tour.pending(), "junk ignored")

print("PASS: arrival points spread over a disc; the square's tour waits for the cover, the loading and the settle, circles, gives everything back on end/skip/death, gives up when far")
