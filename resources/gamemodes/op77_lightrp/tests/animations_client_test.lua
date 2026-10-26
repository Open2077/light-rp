dofile("shared/events.lua")
local manifest = assert(io.open("open77.lua", "r")); local manifestText = manifest:read("*a"); manifest:close()
assert(manifestText:find('"network.client"', 1, true), "local identity/state API requires network.client permission")
local E = LightRpEvents.page
local hooks, handlers, mappings, sent, threads, calls = {}, {}, {}, {}, {}, {}
local focused, activeTask, canonical, delayRequest, serviceError = false, false, nil, false, nil
local clock = 1000
local voiceBlocked = false
TriggerEvent = function(name, _, value) if name == "open-voice:setHudBlocked" then voiceBlocked = value end end
GetCurrentResourceName = function() return "op77_lightrp" end
GetGameTimer = function() return clock end
RegisterNetEvent = function(n, fn) hooks[n] = fn end
AddEventHandler = function(n, fn) hooks[n] = fn end
RegisterKeyMapping = function(id, _, _, fn) mappings[id] = fn; return true end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
LightRpConfig = { keys = { animations = { id = "animations", key = "F3" }, animationStop = { id = "stop", key = "X" } } }
LightRpActions = { isActive = function() return activeTask end }
LightRpConsumables = { isActive = function() return activeTask end }
local surface = { on = function(_, n, fn) handlers[n] = fn end,
    setFocus = function(_, value) focused = value; return true end, setConsumedKeys = function() return true end }
LightRpUi = { page = surface, ready = true, characterReady = true, dialogs = {},
    log = function() end,
    send = function(n, p) sent[#sent + 1] = { name = n, payload = p } end,
    setMenuOpen = function(value) LightRpUi.menuOpen = value end }
local profiles = {}
for i = 1, 9 do profiles[i] = { id = "p" .. i, label = "Profile " .. i, clips = { "one", "two" }, clip = "one" } end
local function resolved(value, why) return { await = function() return value, why end } end
local persisted, jsonValues, jsonId = {}, {}, 0
Open77 = { kvp = { get = function(key) return persisted[key] end, set = function(key, value) persisted[key] = value; return true end },
    json = { encode = function(value) jsonId = jsonId + 1; local text = tostring(jsonId); jsonValues[text] = value; return text end,
        decode = function(text) return jsonValues[text] end },
    network = { status = function() return { playerId = 1 } end, identity = function() return { userId = "test-user" } end }, input = { keyFor = function() end }, animations = {
    list = function() return resolved(not serviceError and profiles, serviceError) end,
    state = function() return resolved(canonical) end,
    request = function(id, options)
        calls[#calls + 1] = { id = id, options = options, focused = focused }
        return { await = function()
            if delayRequest then coroutine.yield() end
            canonical = { active = true, playbackId = "accepted", steps = {{ profile = id, clip = options.clip }}, step = 0 }
            return canonical
        end }
    end,
    cancel = function() calls[#calls + 1] = { cancel = true }; canonical = nil; return resolved(true) end,
} }
dofile("client/core/animations.lua")
LightRpAnimations.bind(surface)
local function run(index) assert(coroutine.resume(threads[index])) end
local function all() for i = 1, #threads do if coroutine.status(threads[i]) == "suspended" then run(i) end end end
local function action(payload) handlers[E.animationsAction](payload) end
local function state() for i = #sent, 1, -1 do if sent[i].name == E.animationsState then return sent[i].payload end end end
LightRpAnimations.open(); assert(focused and state().open and voiceBlocked); all()
assert(state().loaded)
action({ action = "preferences", preferences = { favorites = { "p1:two" }, recent = {}, slots = { "p1:two", "", "", "" }, layout = "list" } })
LightRpAnimations.close(); LightRpAnimations.open(); all()
local restored
for _, event in ipairs(sent) do if event.name == E.animationsPreferences then restored = event.payload end end
assert(restored.preferences.favorites[1] == "p1:two" and restored.preferences.slots[1] == "p1:two", "native preferences survive page reload")
action({ action = "preferences", preferences = { favorites = { {} }, recent = {}, slots = {}, layout = "list" } })
assert(jsonId == 1, "invalid preferences cannot overwrite storage")
local batches = 0
for _, event in ipairs(sent) do if event.name == E.animationsCatalog then
    batches = batches + 1; assert(#event.payload.profiles <= 4 and event.payload.total == 3)
end end
assert(batches == 6, "catalogue must be batched")
action({ action = "play", profile = "p1", clip = "forged", loop = true }); all(); assert(#calls == 0)
action({ action = "play", profile = "p1", clip = "two", loop = false, durationMs = 1 }); all(); assert(#calls == 0)
action({ action = "play", profile = "p1", clip = "two", loop = false, durationMs = 5000 }); all()
assert(#calls == 1 and not calls[1].focused and calls[1].options.clip == "two", "release UI before requesting native animation")
assert(not focused and not state().open and state().current.playbackId == "accepted")
assert(not voiceBlocked, "voice HUD returns when the panel closes")
hooks.onAnimationPlaybackFailed(2, "accepted", "wrong player"); assert(state().current)
hooks.onAnimationPlaybackFailed(1, "old", "stale"); assert(state().current)
activeTask = true; mappings.stop(); assert(#calls == 1, "stop key cannot cancel consumption")
LightRpAnimations.open(); assert(not focused, "cannot interrupt a job")
activeTask = false; mappings.stop(); all(); assert(#calls == 2 and calls[2].cancel and not state().current)
delayRequest = true
LightRpAnimations.open(); all()
action({ action = "play", profile = "p2", clip = "one", loop = true }); run(#threads)
local pending = #threads
mappings.stop(); run(#threads); run(pending)
assert(not state().current and not state().busy, "stale accept must not revive cancelled UI playback")
delayRequest = false
LightRpUi.dialogs.inventory = true; LightRpAnimations.open(); assert(not focused)
LightRpUi.dialogs.inventory = false; LightRpUi.characterReady = false; LightRpAnimations.open(); assert(not focused)
LightRpUi.characterReady = true; LightRpAnimations.open(); all(); assert(focused)
LightRpUi.promptActive = true; LightRpAnimations.close(); assert(focused, "closing cannot release another UI's focus")
LightRpUi.promptActive = false; focused = false
serviceError = "resource_stopped"; LightRpAnimations.open(); all(); assert(state().message:find("unavailable"))
serviceError = nil; action({ action = "refresh" }); all(); assert(state().message == "")
hooks.onPlayerAnimationChanged(1, { active = true, playbackId = "remote", steps = {} }); assert(state().current)
hooks.onPlayerAnimationChanged(1, { active = false }); assert(not state().current)
hooks.onClientResourceStop("op77_lightrp"); assert(not focused)
print("PASS: batched catalogue, validated variants/duration, native focus handoff, canonical state, stale replies, cancellation, protected actions, readiness, resource cleanup")
