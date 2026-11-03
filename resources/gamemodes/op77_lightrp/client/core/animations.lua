-- Dedicated RP browser; the platform remains the sole animation authority.
-- No local-only playback, native camera override or invented catalogue entries.
local Ui, E = LightRpUi, LightRpEvents.page
local Anim = {}
LightRpAnimations = Anim
local page, running, opened = nil, true, false
local catalog, byId, current = {}, {}, nil
local loaded, loading, busy = false, false, false
local serial, revision, catalogRevision = 0, 0, 0
local message, lastToggle = "", -1000
local keys = LightRpConfig.keys
local preferenceKey, preferencesAvailable = nil, false
local function preferenceIdentity()
    local identity = Open77.network.identity()
    local user = identity and identity.userId
    if type(user) ~= "string" or #user > 100 or not user:match("^[%w%-]+$") then return nil end
    return "animations.v1." .. user:lower()
end
local function normalizePreferences(value)
    if type(value) ~= "table" then return nil end
    local result = { favorites = {}, recent = {}, slots = {}, layout = value.layout == "list" and "list" or "grid" }
    for name, limit in pairs({ favorites = 100, recent = 24, slots = 4 }) do
        local values = value[name]
        if type(values) ~= "table" or #values > limit then return nil end
        for _, key in ipairs(values) do
            if type(key) ~= "string" or #key > 300 then return nil end
            result[name][#result[name] + 1] = key
        end
    end
    return result
end
local function loadPreferences()
    preferenceKey, preferencesAvailable = preferenceIdentity(), false
    local value, why
    if preferenceKey then value, why = Open77.kvp.get(preferenceKey) else why = "identity_unavailable" end
    local decoded = value and Open77.json.decode(value)
    local preferences = decoded and normalizePreferences(decoded)
    if value and not preferences then why = why or "invalid_preferences" end
    if why then Ui.log("animation preferences unavailable: %s", tostring(why)) end
    preferencesAvailable = why == nil
    Ui.send(E.animationsPreferences, { preferences = preferences or { favorites = {}, recent = {}, slots = {}, layout = "grid" },
        available = preferencesAvailable, message = why and "Preferences could not be restored. Changes will last for this session only." or "" })
end
local function savePreferences(payload)
    if not preferencesAvailable or preferenceKey ~= preferenceIdentity() then return end
    local preferences = normalizePreferences(payload.preferences)
    if not preferences then return end
    local encoded = Open77.json.encode(preferences)
    if type(encoded) ~= "string" or #encoded > 45000 then return end
    local ok = Open77.kvp.set(preferenceKey, encoded)
    if not ok then
        Ui.send(E.animationsPreferences, { available = false, message = "Your changes could not be saved on this device. They remain available for this session." })
    end
end
local errors = {
    player_not_ready = "Wait until your character has finished loading.",
    player_not_alive = "You must be alive to play an animation.",
    player_in_vehicle = "Exit your vehicle first.",
    animation_owned = "Finish your current action first.",
    interrupted = "Stand still and put your weapon away, then try again.",
    timeout = "The animation did not start in time. Please try again.",
    unknown_profile = "This animation is not available on this server.",
    invalid_clip = "This variant is not available.",
    resource_stopped = "The animation service is unavailable. Try refreshing.",
}
local function taskActive()
    return (LightRpConsumables and LightRpConsumables.isActive())
        or (LightRpRefueling and LightRpRefueling.isActive())
        or (LightRpItemWork and LightRpItemWork.isActive())
        or (LightRpActions and LightRpActions.isActive())
end
local function available()
    if not Ui.ready or not Ui.characterReady or Ui.creationActive or taskActive()
        or Ui.promptActive or Ui.actionFocus then return false end
    for _, value in pairs(Ui.dialogs) do if value then return false end end
    return true
end
local function localPlayer()
    local state = Open77.network.status()
    return state and tonumber(state.playerId)
end
local function send()
    if not running then return end
    Ui.send(E.animationsState, { open = opened, busy = busy, loaded = loaded, loading = loading,
        current = not taskActive() and current or false, message = message,
        toggleKey = Open77.input.keyFor(keys.animations.id) or keys.animations.key,
        stopKey = Open77.input.keyFor(keys.animationStop.id) or keys.animationStop.key })
end
function Anim.close()
    if not opened then return end
    opened = false
    lastToggle = GetGameTimer()
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:animations", false)
    if page and not Ui.menuOpen and not Ui.promptActive and not Ui.actionFocus then
        page:setFocus(false, false)
        page:setConsumedKeys({})
    end
    send()
end
local function report(reason)
    local diagnostic = tostring(reason or "unknown_error"):match("[^\r\n]*"):sub(1, 160)
    message = errors[reason] or ("Animation unavailable: " .. diagnostic)
    send()
    Ui.send(E.notice, { kind = "error", title = "Animations", body = message, durationMs = 6000 })
end
local function await(pending, err)
    if not pending then return nil, err or "resource_stopped" end
    return pending:await()
end
local function sendCatalog()
    catalogRevision = catalogRevision + 1
    -- The bridge caps messages at 1024 nodes. Keep revisions atomic in the UI.
    local total = math.max(1, math.ceil(#catalog / 4))
    for batch = 1, total do
        local profiles = {}
        for i = (batch - 1) * 4 + 1, math.min(batch * 4, #catalog) do
            local p = catalog[i]
            profiles[#profiles + 1] = { id = p.id, label = p.label, category = p.category,
                clip = p.clip, clips = p.clips, clipPrefix = p.clipPrefix, prop = p.prop,
                placement = p.placement, kind = p.kind, mode = p.mode, locomotion = p.locomotion, arms = p.arms }
        end
        Ui.send(E.animationsCatalog, { revision = catalogRevision, total = total, batch = batch, profiles = profiles })
    end
end
local function refresh()
    if loading then return end
    loading = true; send()
    CreateThread(function()
        local values, err = await(Open77.animations.list())
        if not running then return end
        loading = false
        if type(values) ~= "table" then report(err); return end
        catalog, byId, loaded, message = values, {}, true, ""
        for _, p in ipairs(catalog) do byId[p.id] = p end
        sendCatalog()
        local observed = revision
        local state = await(Open77.animations.state())
        if not running then return end
        if observed == revision then current = state end
        send()
    end)
end
function Anim.open()
    if not page or not available() then return end
    Ui.setMenuOpen(false)
    page:setConsumedKeys({})
    local focused, why = page:setFocus(true, true)
    if not focused then report(why); return end
    opened, message = true, ""
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:animations", true)
    lastToggle = GetGameTimer()
    loadPreferences()
    send()
    refresh()
end
local function stop()
    if LightRpRefueling and LightRpRefueling.isActive() then LightRpRefueling.cancel(); return end
    -- X must not cancel an inventory consumable or a job's server-owned action.
    if taskActive() or not Ui.characterReady or (not busy and not (current and current.active)) then return end
    serial, revision = serial + 1, revision + 1
    busy, current, message = false, nil, ""
    local request = serial
    send()
    CreateThread(function()
        -- No ID also abandons pending starts; stale Promise replies cannot revive them.
        local ok, err = await(Open77.animations.cancel())
        if running and request == serial and not ok then report(err) end
    end)
end
local function play(payload)
    if busy or not available() or Ui.menuOpen then return end
    local profile = type(payload.profile) == "string" and byId[payload.profile]
    if not profile then report("unknown_profile"); return end
    local valid = false
    for _, clip in ipairs(profile.clips or {}) do if clip == payload.clip then valid = true; break end end
    if not valid then report("invalid_clip"); return end
    if type(payload.loop) ~= "boolean" then return end
    local duration = tonumber(payload.durationMs)
    if not payload.loop and duration ~= 5000 and duration ~= 10000 and duration ~= 30000 then return end
    local options = { clip = payload.clip, loop = payload.loop }
    if not payload.loop then options.durationMs = duration end
    serial = serial + 1
    local request = serial
    busy, message = true, ""
    Anim.close() -- release pointer before native temporary third-person presentation
    send()
    CreateThread(function()
        if not running or request ~= serial then return end
        local value, err = await(Open77.animations.request(profile.id, options))
        if not running or request ~= serial then return end
        busy = false
        if not value then report(err); return end
        local observed = revision
        local state = await(Open77.animations.state())
        if not running or request ~= serial then return end
        if observed == revision then current = state end
        send()
    end)
end
-- whether an emote is playing: the stop key (X) is shared with Berserk, which stays quiet
-- while an emote runs so X only stops the emote
function Anim.playing() return current ~= nil end
function Anim.bind(surface)
    page = surface
    page:on(E.animationsAction, function(payload)
        if type(payload) ~= "table" then return end
        if payload.action == "open" then Anim.open()
        elseif payload.action == "close" then Anim.close()
        elseif payload.action == "stop" then stop()
        elseif payload.action == "play" then play(payload)
        elseif payload.action == "refresh" and opened then refresh() end
        if payload.action == "preferences" then savePreferences(payload) end
    end)
    RegisterKeyMapping(keys.animations.id, keys.animations.name, keys.animations.key, function()
        if GetGameTimer() - lastToggle < 300 then return end
        if opened then Anim.close() else Anim.open() end
    end)
    RegisterKeyMapping(keys.animationStop.id, keys.animationStop.name, keys.animationStop.key, stop)
end
RegisterNetEvent("open77_animations:menu", function() Anim.open() end)
AddEventHandler("onPlayerAnimationChanged", function(player, state)
    if tonumber(player) ~= localPlayer() or type(state) ~= "table" then return end
    revision = revision + 1
    current = state.active and state or nil
    send()
end)
AddEventHandler("onAnimationPlaybackFailed", function(player, id, reason)
    if tonumber(player) ~= localPlayer() or taskActive() then return end
    if not busy and (not current or current.playbackId ~= id) then return end
    if current and current.playbackId ~= id then return end
    revision = revision + 1
    current = nil
    report(reason)
end)
AddEventHandler("open77:keybinds:changed", function() if page then send() end end)
AddEventHandler("onClientResourceStart", function(name)
    if name == "open-voice" then TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:animations", opened) end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then
        Anim.close(); running, page = false, nil; serial = serial + 1
    elseif name == "open77_animations" then
        serial, revision = serial + 1, revision + 1
        busy, loading, loaded, current = false, false, false, nil
        report("resource_stopped")
    end
end)
