dofile("shared/events.lua")
local events, hooks, threads, sent, cancellations = {}, {}, {}, {}, {}
local time, hp, progress, progressCallback, actionSequence = 0, 100, nil, nil, 0
GetGameTimer = function() return time end
GetCurrentResourceName = function() return "op77_lightrp" end
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) hooks[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = coroutine.yield
Open77 = { stats = { get = function() return { health = { value = hp } } end },
    animations = { cancel = function(id) cancellations[#cancellations + 1] = id end } }
TriggerServerEvent = function(name, data) sent[#sent + 1] = { name = name, data = data }; return true end
LightRpUi = { ready = true, characterReady = true, dialogs = {}, send = function(name)
    if name == LightRpEvents.page.dialogClose then LightRpUi.dialogs.inventory = false; LightRpUi.promptActive = false end
end }
LightRpActions = { isActive = function() return progress ~= nil end,
    progress = function(options, fn) progress, progressCallback = options, fn; actionSequence = actionSequence + 1; return actionSequence end,
    cancel = function() progress = nil; if progressCallback then progressCallback({ status = "cancelled" }) end end }
dofile("client/core/consumables.lua")
local E = LightRpEvents.net
local function step(index) assert(coroutine.resume(threads[index])) end
local function prepare(token)
    LightRpUi.dialogs.inventory, LightRpUi.promptActive = true, true
    events[E.consume]({ phase = "prepare", token = token }); step(#threads)
    assert(sent[#sent].name == E.consumeReady and not LightRpUi.dialogs.inventory)
end
local function play(token)
    events[E.consume]({ phase = "play", token = token, playbackId = "play:" .. token,
        label = "Drinking", itemLabel = "Water", icon = "droplet", durationMs = 6500 })
    step(#threads); step(#threads)
end
prepare("a"); play("a")
assert(progress.durationMs == 6500 and progress.cancellable and not progress.allowMovement)
assert(progress.description:find("Water"))
progressCallback({ status = "success" }); progress = nil
assert(sent[#sent].data.status == "success" and #cancellations == 0, "success waits for authoritative commit before stopping animation")
events[E.consume]({ phase = "finished", token = "stale" }); assert(LightRpConsumables.isActive())
events[E.consume]({ phase = "finished", token = "a", ok = true }); assert(not LightRpConsumables.isActive())
prepare("b"); play("b"); progressCallback({ status = "cancelled" })
assert(sent[#sent].data.status == "cancelled" and cancellations[#cancellations] == "play:b")
events[E.consume]({ phase = "finished", token = "b" })
prepare("c"); play("c"); hooks.onAnimationPlaybackFailed(1, "play:c", "unavailable")
assert(not LightRpConsumables.isActive() and progress == nil and sent[#sent].data.status == "cancelled")
prepare("d"); play("d"); hp = 80; step(1); step(1)
assert(not LightRpConsumables.isActive() and cancellations[#cancellations] == "play:d", "taking damage cancels")
prepare("e"); play("e"); hooks.onClientResourceStop("op77_lightrp")
assert(not LightRpConsumables.isActive() and progress == nil and cancellations[#cancellations] == "play:e")
prepare("f"); events[E.consume]({ phase = "play", token = "f", playbackId = "play:f", durationMs = 6500 })
step(#threads); events[E.consume]({ phase = "finished", token = "f" }); step(#threads)
assert(progress == nil, "late mount must not start a cancelled action")
print("PASS: focus handoff, timed UI, server commit ordering, stale events, exact-ID cancellation, native failure, damage, resource stop and late playback")
