-- Titan Assault client (client/core/titan_mission.lua): the arrival report (loading screen gone, body in the arena
-- for two seconds, repeated until the server's view says so), no relay of the pilot's own shots (the Titan resource reports
-- its blows and the server prices them), the legacy relay of a hostile's hit on a pilot, the ground probe (the Titan
-- resource's Static and Terrain trace; empty without it) and the page's state without the relay filter.
dofile("shared/events.lua")
local E = LightRpEvents
local clock, threads, net, events = { ms = 0 }, {}, {}, {}
local function step(n)
    for _ = 1, n or 1 do
        clock.ms = clock.ms + 16
        for _, thread in ipairs(threads) do
            if coroutine.status(thread) ~= "dead" then local ok, why = coroutine.resume(thread); assert(ok, why) end
        end
    end
end
local function seconds(s) step(math.ceil(s * 1000 / 16)) end
GetCurrentResourceName = function() return "op77_lightrp" end
AddEventHandler = function(name, fn) events[name] = fn end
RegisterNetEvent = function(name, fn) net[name] = fn end
local toServer = {}
TriggerServerEvent = function(name, ...) toServer[#toServer + 1] = { name = name, args = table.pack(...) } end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
local page = {}
LightRpUi = { log = function() end, send = function(name, payload) page[#page + 1] = { name = name, payload = payload }; return true end }
local loading, body = true, { alive = true, attached = true, position = { x = 390, y = -2400, z = 182 } }
local grounds, groundLog = {}, {}
local markers, markerSeq, markerRefuse = {}, 0, false
Open77 = {
    markers = {
        create = function(options)
            if markerRefuse then return nil, "marker_limit" end
            markerSeq = markerSeq + 1
            local id = tostring(markerSeq)
            markers[id] = options
            return id
        end,
        update = function(id, patch)
            if not markers[id] then return false, "unknown_marker" end
            for k, v in pairs(patch) do markers[id][k] = v end
            return true
        end,
        remove = function(id) markers[id] = nil; return true end,
    },
    time = { monotonic = function() return clock.ms / 1000 end },
    screen = { isLoading = function() return loading end },
    character = { state = function() return body end },
}
exports = { op77_lightrp_titans = { ground = function(_, points, reach)
    groundLog[#groundLog + 1] = { points = points, reach = reach }
    return grounds.answer(points, reach)
end } }
dofile("client/core/titan_mission.lua")
local function count(name) local n = 0 for _, e in ipairs(toServer) do if e.name == name then n = n + 1 end end return n end
local function send(p) net[E.net.titan](p) end
local function lastPage() return page[#page] and page[#page].payload end

-- the server's state is the page's, without the relay filter
send({ phase = "wave", arrived = true, enemyIds = { "101", "102" }, wave = 2, waves = 10 })
assert(page[#page].name == E.page.titan and lastPage().wave == 2 and lastPage().enemyIds == nil, "the page does not get the relay filter")

-- arrival: nothing while the loading screen is up or the body is far away; two seconds in the arena, then a report, repeated
send({ phase = "arrive", arrived = false, arena = { x = 390, y = -2400, z = 182 }, enemyIds = {} })
seconds(3)
assert(count(E.net.titanArrived) == 0, "loading: nothing reported")
loading = false
body.position = { x = 390 + 200, y = -2400, z = 182 }
seconds(3)
assert(count(E.net.titanArrived) == 0, "far from the arena: nothing reported")
body.position = { x = 395, y = -2397, z = 182 }
seconds(1.5)
assert(count(E.net.titanArrived) == 0, "not before two seconds in the arena")
seconds(1)
assert(count(E.net.titanArrived) == 1, "reported once the body stood there two seconds")
seconds(2.1)
assert(count(E.net.titanArrived) == 2, "and again until the server accepts")
body.alive = false
seconds(5)
assert(count(E.net.titanArrived) == 2, "a dead body reports nothing")
body.alive = true
send({ phase = "arrive", arrived = true, enemyIds = {} })
local reported = count(E.net.titanArrived)
seconds(5)
assert(count(E.net.titanArrived) == reported, "accepted: no more reports")

-- the pilot's own shots are not relayed from here any more: the Titan resource reports each blow its weapons land, the server
-- prices it. Neither the platform's hit event nor the removed net event is wired.
send({ phase = "wave", arrived = true, enemyIds = { "101", 102 } })
assert(events["open77:npcHit"] == nil, "the shot relay is gone: no listener for the platform's hit event")
assert(E.net.titanHit == nil, "and the net event it carried is gone")
for _, e in ipairs(toServer) do assert(e.name ~= "op77_lightrp:titan:hit", "nothing is sent on the removed event") end

-- a hostile this client simulates hit a pilot: relayed for the run's hostiles only
events["open77:npcPlayerHit"]("7", "101", "4", "12.5")
assert(count(E.net.titanNpcHit) == 1 and toServer[#toServer].args[1] == "7" and toServer[#toServer].args[2] == "101" and toServer[#toServer].args[4] == "12.5")
events["open77:npcPlayerHit"]("7", "55", "4", "12.5")
assert(count(E.net.titanNpcHit) == 1, "not a hostile of the run")

-- the ground probe: the Titan resource's trace, Static and Terrain, a few points a frame
local points = { { x = 1, y = 1, z = 180 }, { x = 2, y = 2, z = 180 }, { x = 3, y = 3, z = 180 }, { x = 4, y = 4, z = 180 },
    { x = 5, y = 5, z = 180 }, { x = 6, y = 6, z = 180 } }
local field = {
    [1] = { static = false, terrain = 181.1 },  -- open ground
    [2] = { static = 180.4, terrain = 180 },    -- a slab flush with the ground: on the slab
    [3] = { static = 186, terrain = 180 },      -- a tree, a boulder: refused
    [4] = { static = false, terrain = false },  -- nothing under it
    [5] = { static = 181.5, terrain = false },  -- the city: no terrain, the static ground
    [6] = { static = 170, terrain = 180 },      -- something buried: the terrain
}
grounds.answer = function(chunk)
    local out = {}
    for i, p in ipairs(chunk) do out[i] = field[p.x] or { static = false, terrain = 181 } end
    return out
end
net[E.net.titanProbe]({ id = 9, points = points })
seconds(1)
assert(count(E.net.titanGround) == 1)
local ground = toServer[#toServer]
assert(ground.args[1] == 9, "answers its request")
assert(table.concat(ground.args[2], ",") == "1,2,5,6", "standing room: 1, 2, 5 and 6 (3 is a tree, 4 has no ground)")
local want = { 181.1, 180.4, 181.5, 180 }
for i, z in ipairs(want) do assert(math.abs(ground.args[3][i] - z) < 1e-9, "the ground height of answer " .. i) end
assert(groundLog[1].reach == 40 and #groundLog[1].points == 4 and #groundLog[2].points == 2, "40 m up and down, four points a frame")
-- more points than the server may ask for are not probed
local many = {}
for i = 1, 40 do many[i] = { x = 1, y = 1, z = 180 } end
local before, asked = #groundLog, 0
net[E.net.titanProbe]({ id = 10, points = many })
seconds(3)
for i = before + 1, #groundLog do asked = asked + #groundLog[i].points end
assert(asked == 32, "at most 32 points")
assert(#toServer > 0 and toServer[#toServer].name == E.net.titanGround and toServer[#toServer].args[1] == 10 and #toServer[#toServer].args[2] == 32)
-- bad payloads are ignored
local sentBefore = #toServer
net[E.net.titanProbe]("nothing"); net[E.net.titanProbe]({ id = 11 })
seconds(1)
assert(#toServer == sentBefore)
-- no Titan controller here, or no Titan resource at all: an empty answer, so the server's failure count moves on
grounds.answer = function() return nil, "controller_unavailable" end
net[E.net.titanProbe]({ id = 12, points = points })
seconds(1)
local none = toServer[#toServer]
assert(none.name == E.net.titanGround and none.args[1] == 12 and #none.args[2] == 0 and #none.args[3] == 0, "an empty answer without the controller")
grounds.answer = function() error("No such export ground in resource op77_lightrp_titans") end
net[E.net.titanProbe]({ id = 13, points = points })
seconds(1)
none = toServer[#toServer]
assert(none.name == E.net.titanGround and none.args[1] == 13 and #none.args[2] == 0, "an empty answer without the resource")

-- the last hostiles: an arrow above each listed one, following the lists, gone when no longer listed
local function arrows()
    local n = 0
    for _ in pairs(markers) do n = n + 1 end
    return n
end
net[E.net.titanMarks]({ { id = "101", x = 10, y = 20, z = 30 }, { id = "102", x = 40, y = 50, z = 60 } })
assert(arrows() == 2, "two arrows")
local first = markers["1"]
assert(first.shape == "arrow" and first.position.x == 10 and first.position.z > 30 and first.maxDistance == 500, "an arrow above the hostile")
assert(first.color.r == 255 and first.color.g < 100, "red")
net[E.net.titanMarks]({ { id = "101", x = 15, y = 20, z = 30 } })
assert(arrows() == 1 and markers["1"] and markers["1"].position.x == 15, "it follows its hostile; the unlisted one goes")
assert(markerSeq == 2, "the same arrow is moved, not made again")
net[E.net.titanMarks]({ { id = "103", x = "junk" }, "nothing", { x = 1, y = 2, z = 3 } })
assert(arrows() == 0, "malformed entries mark nothing, and the unlisted arrow goes")
net[E.net.titanMarks]("nothing")
markerRefuse = true
net[E.net.titanMarks]({ { id = "104", x = 1, y = 2, z = 3 } })
assert(arrows() == 0, "a refused arrow is no arrow")
markerRefuse = false
local many = {}
for i = 1, 40 do many[i] = { id = tostring(200 + i), x = i, y = 0, z = 0 } end
net[E.net.titanMarks](many)
assert(arrows() == 16, "at most sixteen arrows")
net[E.net.titanMarks]({})
assert(arrows() == 0, "an empty list takes them down")
net[E.net.titanMarks]({ { id = "105", x = 1, y = 2, z = 3 } })
assert(arrows() == 1)

-- the end clears everything: no relay, the page is told
send({ phase = "ended", result = "victory" })
assert(lastPage().phase == "ended" and lastPage().result == "victory")
assert(arrows() == 0, "the end takes the arrows down")
local relayed = count(E.net.titanNpcHit)
events["open77:npcPlayerHit"]("7", "101", "4", "12.5")
assert(count(E.net.titanNpcHit) == relayed, "nothing is relayed after the end")

-- the server is asked for the state when the resource starts
local hello = count(E.net.titanHello)
events["onClientResourceStart"]("someone_else")
assert(count(E.net.titanHello) == hello)
events["onClientResourceStart"]("op77_lightrp")
assert(count(E.net.titanHello) == hello + 1)

print("PASS: Titan Assault client: page state, arrival report (loading, distance, two seconds, repeat until accepted), no relay of the pilot's own shots, hostile-on-pilot relay, ground probe (terrain, flush slab, tree refused, city, bounded, empty without the Titan trace), the last hostiles' arrows, end")
