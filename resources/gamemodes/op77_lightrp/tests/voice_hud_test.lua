-- Real companion HUD, isolated from native voice, game and network.
local handlers, threads, exportsMap, callbacks, payloads = {}, {}, {}, {}, {}
local shown, creates = false, 0
local function noop() end
Open77 = {
    time = { monotonic = function() return 10 end },
    voice = { status = function() return { available = true, captureEnabled = true } end },
    json = { encode = function(value) return tostring(value.visible) end },
}
WebUI = { create = function(options)
    creates = creates + 1; shown = options.visible
    return { on = function(_, name, fn) callbacks[name] = fn end,
        send = function(_, _, payload) payloads[#payloads + 1] = payload end,
        show = function() shown = true end, hide = function() shown = false end }
end }
RegisterNetEvent = noop
AddEventHandler = function(name, fn) handlers[name] = fn end
GetCurrentResourceName = function() return "open-voice" end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
exports = function(name, fn) exportsMap[name] = fn end
dofile("../../system/open-voice/client/range_preview.lua")
dofile("../../system/open-voice/client/main.lua")
local block = handlers["open-voice:setHudBlocked"]
block("onboarding", true)
handlers.onClientResourceStart("open-voice")
callbacks["open-voice:ready"]()
assert(creates == 1 and not shown and not payloads[#payloads].visible, "no startup flash")
block("other-flow", true)
block("onboarding", false)
assert(not shown, "other suppression remains")
block("other-flow", false)
assert(shown and payloads[#payloads].visible)
block("onboarding", true)
assert(not shown, "blocking hides native surface immediately")
exportsMap.setHudVisible(false)
block("onboarding", false)
assert(not shown, "do not override pre-existing visibility preference")
exportsMap.setHudVisible(true)
assert(shown)
exportsMap.setHudVisible(false)
local fade = threads[#threads]
assert(coroutine.resume(fade))
block("onboarding", true)
exportsMap.setHudVisible(true)
assert(not shown, "show request cannot bypass onboarding")
block("onboarding", false)
assert(shown)
assert(coroutine.resume(fade))
assert(shown, "stale fade cannot hide restored HUD")
print("PASS: voice HUD initial hide, immediate surface removal, independent blockers, preference preservation and stale fade")
