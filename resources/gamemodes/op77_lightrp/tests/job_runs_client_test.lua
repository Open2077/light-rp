dofile("shared/events.lua")
local net, events, sends, markers, tracks, clock = {}, {}, {}, 0, 0, 10
local point, press, options, done, cancels
cancels = 0
RegisterNetEvent = function(n, f) net[n] = f end
AddEventHandler = function(n, f) events[n] = f end
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerServerEvent = function(n, p) sends[#sends+1] = { n, p } end
-- the native waypoint: what setWaypoint put there, nil when none
local waypoint, cleared = nil, 0
Open77 = { time = { monotonic = function() return clock end }, blips = { track = function() tracks = tracks + 1; return true end,
        setWaypoint = function(p) tracks = tracks + 1; waypoint = { x = p.x, y = p.y, z = p.z }; return true end,
        waypoint = function() return waypoint end, clearWaypoint = function() waypoint = nil; cleared = cleared + 1; return true, true end },
    input = { keyFor = function() return "F3" end }, character = { state = function() return { position = { x = 4, y = 6, z = 3 } } end } }
LightRpUi = { log = function() end, send = function(name, payload) LightRpUi.sent = { name = name, payload = payload } end }
-- the live readout thread: captured, stepped by hand below
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
LightRpConfig = { keys = { menu = { id = "lightrp.menu", key = "F1" } } }
LightRpInteract = { trackBlip = Open77.blips.track, setLocal = function(_, p, callback)
    point, press = p, callback
    if p then
        markers = markers + 1
        assert(type(p.marker.color) == "table" and p.marker.color.r == 255, "native markers require RGBA table, not CSS string")
        return "blip" .. markers
    end
end }
LightRpActions = { progress = function(o, cb) options, done = o, cb; return "action" end,
    cancel = function() cancels = cancels + 1; done({ status = "cancelled" }); return true end }
dofile("client/core/job_runs.lua")
local E = LightRpEvents.net
local state = { active = true, job = "sanitation", id = "run", index = 1, objective = { kind = "work", position = { x = 1, y = 2, z = 3 }, radius = 2.6, label = "Collect" } }
net[E.state]({ jobRun = state }); assert(point.prompt == "Collect" and tracks == 1 and markers == 1)
assert(point.blip.icon == "trash-2" and not point.blip.routable and point.blip.size == 48, "the pin marks, the waypoint routes")
assert(waypoint and waypoint.x == 1 and waypoint.y == 2, "GPS waypoint on the stop")
-- the tracker learns the distance to the stop (ground plane) and the menu key
for _ = 1, 2 do coroutine.resume(threads[1]) end
assert(LightRpUi.sent.name == LightRpEvents.page.jobRun and LightRpUi.sent.payload.distance == 5 and LightRpUi.sent.payload.menuKey == "F3")
assert(LightRpUi.sent.payload.gps == true, "the tracker knows the route is on")
-- the waypoint vanished (cleared, lost): put back, at most every 3 s
waypoint = nil; clock = clock + 5; coroutine.resume(threads[1]); assert(waypoint and LightRpUi.sent.payload.gps == true, "GPS restored")
-- a waypoint of the player's own elsewhere is left alone, the tracker says so
waypoint = { x = 500, y = 500, z = 0 }; clock = clock + 5; coroutine.resume(threads[1])
assert(waypoint.x == 500 and LightRpUi.sent.payload.gps == false)
net[E.jobGps](); assert(waypoint.x == 1, "GPS to my next stop takes it back")
press(); assert(sends[#sends][1] == E.jobBegin and sends[#sends][2].index == 1)
local count = #sends; press(); assert(#sends == count, "debounced")
clock = clock + 2; LightRpUi.promptActive = true; press(); assert(#sends == count); LightRpUi.promptActive = false
net[E.jobWork]({ token = "token", durationMs = 5000, label = "Collect", icon = "trash-2" })
assert(options.durationMs == 5000 and options.cancellable)
state.working = true; net[E.state]({ jobRun = state }); assert(markers == 1, "work state does not churn markers/GPS")
done({ status = "success" }); assert(sends[#sends][1] == E.jobFinish and sends[#sends][2].token == "token")
net[E.jobWork]({ token = "next", durationMs = 5000, label = "Collect" }); count = #sends
net[E.jobWork]({ cancel = true }); assert(cancels == 1 and #sends == count, "server cancellation cannot complete a task")
state.index = 2; state.working = false; net[E.state]({ jobRun = state }); assert(markers == 2)
local before = tracks; net[E.jobGps](); assert(tracks == before + 1)
net[E.state]({ jobRun = { active = false } }); assert(point == nil and waypoint == nil and cleared >= 1, "run over: its waypoint goes")
net[E.jobWork]({ token = "late", durationMs = 1000 }); assert(#sends == count)
net[E.state]({ jobRun = state }); events.onClientResourceStop("op77_lightrp"); assert(point == nil)
for i, example in ipairs({
    { "scrapper", "work", "recycle" }, { "ac_cleaner", "work", "fan" },
    { "ac_cleaner", "lift", "arrow-up-down" }, { "sanitation", "return", "warehouse" },
    { "scrapper", "return", "warehouse" }, { "ac_cleaner", "return", "warehouse" },
    { "delivery", "pickup", "package" }, { "delivery", "dropoff", "house" },
}) do
    state.id = "icon-test-" .. i; state.job = example[1]; state.objective.kind = example[2]
    net[E.state]({jobRun=state})
    assert(point.blip.icon == example[3] and waypoint ~= nil, "job/kind selects custom icon without losing GPS")
end
net[E.state]({jobRun={active=false}})
print("PASS: private objective lifecycle, native RGBA marker contract, GPS waypoint (set, restored, player waypoint kept, cleared at the end), E debounce/menu guard, action callbacks, cancelled/late work, cleanup")
