dofile("shared/events.lua")
local time, caller, callerGen, generation, alive = 1000, nil, 3, 1, true
local handlers, network, exportsList, pageHandlers, sent, callbacks = {}, {}, {}, {}, {}, {}
local focus, thread, running = false, nil, true
GetGameTimer = function() return time end
GetCurrentResourceName = function() return "op77_lightrp" end
GetInvokingResource = function() return caller end
GetInvokingResourceGeneration = function() return callerGen end
GetResourceState = function() return running and "running" or "stopped" end
Open77 = { resource = { generation = function(name) return name == "op77_lightrp" and generation or callerGen end },
    character = { state = function() return { alive = alive } end }, exports = { call = function(name, method, result) callbacks[#callbacks + 1] = { name, method, result }; return {} end } }
CreateThread = function(fn) thread = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterNetEvent = function(name, fn) network[name] = fn end
TriggerEvent = function() end
exports = function(name, fn) exportsList[name] = fn end
LightRpUi = { ready = true, characterReady = true, page = {}, dialogs = {},
    claimActionFocus = function(keys)
        for _, value in ipairs(keys) do
            if value ~= "ESCAPE" and value ~= "SPACE" then return false, "unsupported_consumed_key" end
        end
        focus = true; return true
    end,
    releaseActionFocus = function() focus = false end,
    send = function(name, value) sent[name] = value; return true end, log = function() end }
dofile("client/core/actions.lua")
LightRpActions.bind({ on = function(_, name, fn) pageHandlers[name] = fn end })
local A, E = LightRpActions, LightRpEvents.page
local function ack(id) pageHandlers[E.actionStarted]({ id = id }) end
local function report(id, status, reason) pageHandlers[E.actionResult]({ id = id, status = status, reason = reason, hits = 1, mistakes = 0, score = 90 }) end
local function tick() assert(coroutine.resume(thread)) end
tick()
local calls = 0
local rejected, reason = A.hold({ key = "E", allowMovement = true })
assert(not rejected and reason == "unsupported_consumed_key" and not focus)
local spaceId = assert(A.hold({ key = "SPACE", allowMovement = true })); assert(A.cancel(spaceId))
local id = assert(A.progress({ durationMs = 1000 }, function() calls = calls + 1 end))
assert(focus and A.isActive())
assert(select(2, A.hold({})) == "busy")
report(id, "success", "completed"); assert(A.isActive(), "unacknowledged completions are refused")
ack(id); report(id, "success", "completed"); assert(A.isActive(), "early completion is refused")
time = time + 1400; report("stale", "success", "completed"); assert(A.isActive())
report(id, "success", "completed"); report(id, "success", "completed")
assert(calls == 1 and not focus and not A.isActive())
assert(A.result(id).status == "success")
for _, options in ipairs({ { durationMs = -1 }, { durationMs = 0/0 }, { key = "ESCAPE" }, { label = {} }, { style = "invalid" }, { onFinish = function() end } }) do assert(not A.progress(options)) end
assert(not A.skillCheck({ steps = {} })); assert(not A.skillCheck({ steps = { "unknown" } }))
assert(not A.skillCheck({ steps = { { zoneWidth = .9 } } })); assert(not A.skillCheck({ maxMistakes = 3 }))
id = assert(A.hold({ cancellable = false })); ack(id); report(id, "cancelled", "cancelled"); assert(A.isActive()); assert(A.cancel(id))
LightRpUi.promptActive = true; assert(select(2, A.progress({})) == "ui_busy"); LightRpUi.promptActive = false
LightRpUi.characterReady = false; assert(select(2, A.progress({})) == "character_not_ready"); LightRpUi.characterReady = true
caller = "job_mechanic"
id = assert(exportsList.ActionSkillCheck({ steps = { "easy" }, onFinish = "finished" }))
ack(id); caller = "other_job"; assert(select(2, A.cancel(id)) == "not_owner"); caller = "job_mechanic"
time = time + 2000; report(id, "success", "completed")
assert(callbacks[1][1] == "job_mechanic" and callbacks[1][2] == "finished")
caller = "other_job"; assert(select(2, A.result(id)) == "not_owner"); caller = nil
id = assert(A.progress({})); time = time + 3100; tick(); assert(not focus and A.result(id).reason == "ui_timeout")
id = assert(A.hold({})); ack(id); alive = false; tick(); assert(A.result(id).reason == "dead" and not focus); alive = true
caller = "job_mechanic"; id = assert(A.progress({})); handlers.onClientResourceStop("job_mechanic"); assert(not focus and not A.isActive()); caller = nil
local nextId
id = assert(A.progress({}, function() nextId = assert(A.hold({})) end)); ack(id); time = time + 5500; report(id, "success", "completed")
assert(nextId and A.isActive() and focus, "callbacks can chain without releasing the new action's focus")
A.cancel(nextId)
-- the native bar (client/native/actions.lua) decides on the relayed keys and reports through
-- Actions.report: the checks the page's actionResult went through
id = assert(A.hold({}))
A.report({ id = id, status = "success", reason = "completed" }); assert(A.isActive(), "a report before the page's acknowledgement is refused")
ack(id); A.report({ id = id, status = "success", reason = "completed" }); assert(A.isActive(), "an early success is refused")
time = time + 5500; A.report({ id = id, status = "cancelled", reason = "made_up" }); assert(A.isActive(), "an unknown reason is refused")
A.report({ id = id, status = "success", reason = "completed", hits = 0, mistakes = 0, score = 0 })
assert(not A.isActive() and not focus and A.result(id).status == "success" and sent[E.actionFinish].id == id, "a valid report finishes once")
print("PASS actions Lua: validation, lifecycle, focus, ownership, callbacks, death, watchdog and stale completions")
