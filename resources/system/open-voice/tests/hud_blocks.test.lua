-- The HUD visibility rules of client/main.lua (setHudVisible, setHudBlocked), isolated from
-- native voice, game and network. Run with Lua 5.4 from the resource folder:
--   lua tests/hud_blocks.test.lua
local handlers, threads, exportsMap, callbacks, payloads = {}, {}, {}, {}, {}
local shown, creates, destroyed = false, 0, 0
local function noop() end
Open77 = {
    time = { monotonic = function() return 10 end },
    voice = { status = function() return { available = true, captureEnabled = true } end },
    json = { encode = function(value) return tostring(value.visible) end },
}
-- the HUD surface (client/ui.lua on NativeUI) speaks the page API main.lua uses
OpenVoiceHud = { create = function(options)
    creates = creates + 1; shown = options.visible
    return { on = function(_, name, fn) callbacks[name] = fn end,
        send = function(_, _, payload) payloads[#payloads + 1] = payload end,
        show = function() shown = true end, hide = function() shown = false end,
        destroy = function() destroyed = destroyed + 1 end }
end }
RegisterNetEvent = noop
AddEventHandler = function(name, fn) handlers[name] = fn end
GetCurrentResourceName = function() return "open-voice" end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
exports = function(name, fn) exportsMap[name] = fn end
dofile("client/range_preview.lua")
dofile("client/main.lua")
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
assert(not shown, "blocking hides the document immediately")
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
assert(exportsMap.getState().visible == true and type(exportsMap.getModes()) == "table")
handlers.onClientResourceStop("open-voice")
assert(destroyed == 1, "the document is destroyed with the resource")

-- without NativeUI the resource logs one line and keeps running without a HUD
local printed = {}
local output = print
print = function(text) printed[#printed + 1] = tostring(text) end
OpenVoiceHud = { create = function() return nil, "nativeui_unavailable" end }
handlers.onClientResourceStart("open-voice")
print = output
assert(#printed == 1 and printed[1]:find("nativeui_unavailable", 1, true), "one line")
exportsMap.setHudVisible(false); exportsMap.setHudVisible(true); block("x", true); block("x", false)
print("PASS: voice HUD initial hide, immediate document removal, independent blockers, preference preservation, stale fade, no NativeUI")
