dofile("shared/events.lua")
local net, events, sends, markers, tracks, clock = {}, {}, {}, 0, 0, 10
local point, press, options, done, cancels
cancels = 0
RegisterNetEvent = function(n, f) net[n] = f end
AddEventHandler = function(n, f) events[n] = f end
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerServerEvent = function(n, p) sends[#sends+1] = { n, p } end
Open77 = { time = { monotonic = function() return clock end }, blips = { track = function() tracks = tracks + 1; return true end } }
LightRpUi = { log = function() end }
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
assert(point.blip.icon == "trash-2" and point.blip.routable and point.blip.size == 48)
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
net[E.jobGps](); assert(tracks == 3)
net[E.state]({ jobRun = { active = false } }); assert(point == nil)
net[E.jobWork]({ token = "late", durationMs = 1000 }); assert(#sends == count)
net[E.state]({ jobRun = state }); events.onClientResourceStop("op77_lightrp"); assert(point == nil)
for i, example in ipairs({
    { "scrapper", "work", "recycle" }, { "ac_cleaner", "work", "fan" },
    { "ac_cleaner", "lift", "arrow-up-down" }, { "sanitation", "return", "warehouse" },
    { "scrapper", "return", "warehouse" }, { "ac_cleaner", "return", "warehouse" },
}) do
    state.id = "icon-test-" .. i; state.job = example[1]; state.objective.kind = example[2]
    net[E.state]({jobRun=state})
    assert(point.blip.icon == example[3] and point.blip.routable, "job/kind selects custom icon without losing GPS")
end
net[E.state]({jobRun={active=false}})
print("PASS: private objective lifecycle, native RGBA marker contract, GPS, E debounce/menu guard, action callbacks, cancelled/late work, cleanup")
