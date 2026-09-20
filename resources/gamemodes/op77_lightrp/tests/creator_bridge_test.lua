-- Native mirror handoff/focus exercised through the real Lua UI bridge.
dofile("shared/events.lua")
local callbacks, net, events, threads, sent = {}, {}, {}, {}, {}
local nativeOpen, requestAccepted, focused = false, true, false
local voiceBlocked
TriggerEvent = function(name, reason, value)
    assert(name == "open-voice:setHudBlocked" and reason == "op77_lightrp:onboarding")
    voiceBlocked = value
end
GetCurrentResourceName = function() return "op77_lightrp" end
Open77 = { appearance = { isOpen = function() return nativeOpen end } }
WebUI = { create = function()
    return { on = function(_, name, fn) callbacks[name] = fn end,
        send = function(_, name, value) sent[#sent + 1] = { name = name, value = value }; return true end,
        setConsumedKeys = function() return true end,
        setFocus = function(_, keyboard) focused = keyboard; return true end }
end }
TriggerServerEvent = function() return requestAccepted, "test refusal" end
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
dofile("client/core/ui.lua")
local E, U = LightRpEvents, LightRpUi
assert(U.create())
assert(voiceBlocked, "voice is hidden before the initial character state")
callbacks[E.page.ready]()
net[E.net.state]({ character = { status = "draft" } })
local function tick() local ok, error = coroutine.resume(threads[1]); assert(ok, error) end
local function lastEditor()
    for i = #sent, 1, -1 do if sent[i].name == E.page.characterEditor then return sent[i].value end end
end
tick() -- reach the first Wait
U.setPromptFocus(true)
assert(focused)
U.setMenuOpen(true)
assert(not U.menuOpen and focused, "F1 cannot steal creation focus")
callbacks[E.page.action]({ type = "character.appearance.open", family = "female" })
assert(not focused and lastEditor().active)
assert(voiceBlocked, "native editor handoff must not reveal voice HUD")
U.setPromptFocus(true)
assert(not focused, "do not steal focus from native mirror")
nativeOpen = true; tick()
nativeOpen = false; tick()
assert(not lastEditor().active)
U.setPromptFocus(true); assert(focused)
callbacks[E.page.action]({ type = "character.appearance.open" })
events["open77:appearance:cancelled"](); tick()
assert(not lastEditor().active, "fast cancellation also resumes")
callbacks[E.page.action]({ type = "character.appearance.open" })
for _ = 1, 60 do tick() end
assert(not lastEditor().active and lastEditor().error:find("did not open"))
requestAccepted = false
callbacks[E.page.action]({ type = "character.appearance.open" })
assert(not lastEditor().active and lastEditor().error:find("test refusal"))
nativeOpen = true; tick()
assert(lastEditor().active, "automatic native editor also hides creation UI")
voiceBlocked = false
events.onClientResourceStart("open-voice")
assert(voiceBlocked, "late voice start/restart re-applies onboarding block")
net[E.net.state]({ character = { status = "active", welcomePending = true } })
assert(voiceBlocked, "welcome briefing is still onboarding")
net[E.net.state]({ needs = { food = 90 } })
assert(voiceBlocked, "unrelated patches cannot reveal voice")
net[E.net.state]({ character = { status = "active", welcomePending = false } })
assert(not voiceBlocked, "voice returns when entering gameplay")
net[E.net.state]({ character = { status = "draft" } })
assert(voiceBlocked, "creating another character hides voice again")
events.onClientResourceStop("op77_lightrp")
assert(not voiceBlocked, "gamemode stop releases its own suppression")
print("PASS: native editor lifecycle, focus, F1, voice suppression through loading/creation/welcome, restart, gameplay and cleanup")
