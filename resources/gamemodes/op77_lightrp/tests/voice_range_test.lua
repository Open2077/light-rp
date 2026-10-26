-- Real range preview module, deterministic native marker/clock fixtures.
local clock, serial, creates, updates, removes = 0, 0, 0, 0, 0
local markers, workers, warnings = {}, {}, {}
local state = { alive = true, position = { x = 10, y = 20, z = 30 } }
local createFailure, updateFailure
local output = print
print = function(message) warnings[#warnings + 1] = message end
Open77 = {
    time = { monotonic = function() return clock end },
    character = { state = function() return state end },
    anchors = {
        create = function(options)
            if createFailure then return nil, createFailure end
            assert(options.render == "ring" and options.page == nil)
            serial, creates = serial + 1, creates + 1
            markers[serial] = options
            return serial
        end,
        update = function(id, patch)
            if updateFailure then return false, updateFailure end
            assert(markers[id], "no stale updates")
            assert(patch.color == nil, "do not rebuild marker material while following/fading")
            updates = updates + 1
            for key, value in pairs(patch) do markers[id][key] = value end
            return true
        end,
        remove = function(id) markers[id] = nil; removes = removes + 1; return true end,
    },
}
CreateThread = function(fn)
    local co = coroutine.create(fn)
    workers[#workers + 1] = co
    assert(coroutine.resume(co))
end
Wait = function(ms) assert(ms == 50); coroutine.yield() end
local function tick(seconds)
    clock = clock + seconds
    for _, co in ipairs(workers) do
        if coroutine.status(co) ~= "dead" then assert(coroutine.resume(co)) end
    end
end
local function count() local n = 0; for _ in pairs(markers) do n = n + 1 end; return n end
local function ring(distance)
    assert(count() == 1)
    local _, value = next(markers)
    assert(value.presentation.radius == distance)
    return value
end
dofile("../../system/open-voice/client/range_preview.lua")
local preview = OpenVoiceRangePreview
preview.confirm("normal", 20, true)
preview.confirm("normal", 20, true)
assert(creates == 0 and #workers == 0, "initial and duplicate sync must not flash")
preview.confirm("shout", 40, true)
assert(ring(40).position.z == 30 and ring(40).presentation.groundOffset == 0.08)
state.position = { x = 12, y = 23, z = 31 }
tick(0.05)
assert(ring(40).position.x == 12 and ring(40).position.z == 31)
tick(1)
preview.confirm("whisper", 3, true)
assert(creates == 1 and #workers == 1, "rapid changes reuse the marker and worker")
ring(3)
tick(2)
preview.confirm("whisper", 3, true)
tick(1.01)
assert(count() == 0, "duplicate sync must not prolong the timer")
assert(removes == 1)
local sampled = updates
tick(20)
assert(updates == sampled, "no work at idle")

preview.confirm("normal", 20, false)
assert(count() == 0, "blocked HUD suppresses preview")
preview.confirm("normal", 20, true)
assert(count() == 0, "unblocking doesn't replay hidden change")
preview.confirm("whisper", 3, true)
preview.hide()
preview.confirm("shout", 40, true)
tick(0.05)
ring(40) -- cancelled previous worker must not remove the new ring
state.alive = false
tick(0.05)
assert(count() == 0, "death cleans marker")
preview.confirm("normal", 20, true)
assert(count() == 0, "no preview on a dead player")
state.alive = true
preview.confirm("whisper", 3, true)
state = nil
tick(0.05)
assert(count() == 0, "lost character/disconnect cleans marker")
state = { alive = true, position = { x = 0, y = 0, z = 0 } }
preview.confirm("normal", 20, true)
preview.confirm("invalid", 0/0, true)
preview.confirm("invalid", math.huge, true)
preview.confirm("invalid", -1, true)
ring(20)
preview.confirm("normal", 50, true)
ring(50)
preview.confirm("normal", 75, true)
assert(count() == 0 and #warnings == 1, "do not silently clamp an unsupported range")
preview.confirm("normal", 20, true)
updateFailure = "anchor_not_found"
state.position.x = 1
tick(0.05)
assert(count() == 0 and warnings[#warnings]:find("anchor_not_found", 1, true))
updateFailure = nil
createFailure = "anchor_quota_exceeded"
preview.confirm("shout", 40, true)
local warningCount = #warnings
preview.confirm("normal", 20, true)
assert(#warnings == warningCount and count() == 0, "deduplicate failures, never fail voice")
createFailure = nil
preview.confirm("whisper", 3, true)
updateFailure = "marker_not_found"
preview.confirm("normal", 20, true)
assert(count() == 0)
updateFailure = nil
preview.confirm("shout", 40, true)
preview.reset()
tick(0.05)
assert(count() == 0)
preview.confirm("normal", 20, true)
assert(count() == 0, "resource restart seeds a fresh baseline")
preview.confirm("shout", 40, true)
local anchorApi = Open77.anchors
Open77.anchors = nil
preview.confirm("whisper", 3, true)
assert(count() == 0, "losing the API still removes the old handle safely")
Open77.anchors = anchorApi
preview.reset()

-- Integration: only canonical server state triggers the preview, not requests.
local net, events, exportsMap = {}, {}, {}
Open77.voice = { status = function() return {} end }
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
TriggerEvent = function() end
TriggerServerEvent = function() return true end
GetCurrentResourceName = function() return "open-voice" end
exports = function(name, fn) exportsMap[name] = fn end
dofile("../../system/open-voice/client/main.lua")
net["open-voice:state"]({ mode = "normal", modes = {
    { name = "normal", distance = 20 }, { name = "shout", distance = 40 }, { name = "whisper", distance = 3 },
}})
assert(count() == 0)
events["open-voice:cycle"]()
assert(count() == 0, "request is not confirmation")
net["open-voice:error"]("rate_limited")
assert(count() == 0, "rejected request is not confirmation")
net["open-voice:state"]({ mode = "shout", distance = 40 })
ring(40)
net["open-voice:state"]({ mode = "shout", distance = 0/0 })
assert(exportsMap.getState().distance == 40, "invalid state cannot poison HUD/ring")
events["open-voice:setHudBlocked"]("op77_lightrp:onboarding", true)
assert(count() == 0, "UI blocker cleans up immediately")
net["open-voice:state"]({ mode = "normal", distance = 20 })
assert(count() == 0)
events["open-voice:setHudBlocked"]("op77_lightrp:onboarding", false)
net["open-voice:state"]({ mode = "whisper", distance = 3 })
ring(3)
events.onClientResourceStop("unrelated")
ring(3)
events.onClientResourceStop("open-voice")
assert(count() == 0)
tick(0.05)
print = output
print("PASS: authoritative 3D voice range, radius, movement, reuse, expiry, blockers, death, cleanup, validation and native errors")
