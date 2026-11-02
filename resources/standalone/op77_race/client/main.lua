-- op77_race client: the race page (HUD, panel, results), checkpoint visuals, sounds,
-- the rebindable keys and the staff editor preview. Nothing here decides anything:
-- the server owns admission, timing and checkpoints.
local Config = RaceConfig
local P = Config.presentation or {}
local M = RaceMarkers

local page, pageReady, creating = nil, false, false
local panelOpen, wantPanel = false, false
local state, editorState, lastMenu = nil, nil, nil
local effects = {}         -- sfx / vfx handles of the current run
local countdownFor = nil   -- instance:run whose countdown sound already played

local function log(level, text)
    if Open77.log and Open77.log[level] then Open77.log[level]("[race] " .. tostring(text)) end
end

local function send(name, payload)
    if page and pageReady then pcall(page.send, page, name, payload) end
end

-- ---------------------------------------------------------------- effects --

local function remember(kind, handle)
    if handle ~= nil then effects[#effects + 1] = { kind = kind, handle = handle } end
end

local function stopEffects()
    for _, entry in ipairs(effects) do
        if entry.kind == "sfx" then pcall(Open77.sfx.stop, entry.handle) else pcall(Open77.vfx.stop, entry.handle) end
    end
    effects = {}
end

local function sfx(event, tag, duration)
    if type(event) ~= "string" or event == "" or type(Open77.sfx) ~= "table" then return end
    local handle, reason = Open77.sfx.play(event, { tag = tag, unique = true, duration = duration })
    if handle == nil then log("debug", ("sfx %s: %s"):format(event, tostring(reason))) end
    remember("sfx", handle)
end

-- One-shots around the start line, each with an explicit duration (a nil duration
-- never expires and holds a client effect-quota slot).
local function startVfx()
    local start = state and state.course and state.course.start
    if type(Open77.vfx) ~= "table" or type(start) ~= "table" or type(start.position) ~= "table" then return end
    local yaw = math.rad(tonumber(start.heading) or 0.0)
    local fx, fy = -math.sin(yaw), math.cos(yaw)
    local rx, ry = math.cos(yaw), math.sin(yaw)
    for _, def in ipairs(P.startVfx or {}) do
        local forward, lateral = tonumber(def.forward) or 0.0, tonumber(def.lateral) or 0.0
        local handle, reason = Open77.vfx.play(def.effect, {
            position = { x = start.position.x + fx * forward + rx * lateral,
                y = start.position.y + fy * forward + ry * lateral,
                z = start.position.z + (tonumber(def.z) or 0.0) },
            orientation = { x = 0.0, y = 0.0, z = math.sin(yaw * 0.5), w = math.cos(yaw * 0.5) },
            duration = tonumber(def.duration) or 5.0,
            ignoreTimeDilation = true,
        })
        if handle == nil then log("debug", ("vfx %s: %s"):format(tostring(def.effect), tostring(reason))) end
        remember("vfx", handle)
    end
end

-- ---------------------------------------------------------------- keys --

local keys = {}

local function keyFor(binding)
    local ok, key = pcall(Open77.input.keyFor, binding.id)
    return ok and key or binding.key
end

local function refreshKeys()
    for name, binding in pairs(Config.keys) do keys[name] = keyFor(binding) end
    for name, binding in pairs(Config.editorKeys) do keys["editor." .. name] = keyFor(binding) end
    send("race:keys", keys)
end

local function headingForEditor()
    local character = Open77.character.state()
    local yaw = type(character) == "table" and tonumber(character.yaw) or nil
    if type(character) == "table" and character.inVehicle == true and yaw ~= nil then return yaw % 360.0 end
    local view = Open77.camera.view()
    if type(view) ~= "table" or type(view.forward) ~= "table" then return yaw and yaw % 360.0 or 0.0 end
    local x, y = tonumber(view.forward.x), tonumber(view.forward.y)
    if x == nil or y == nil or math.abs(x) + math.abs(y) < 0.0001 then return 0.0 end
    -- REDengine yaw 0 faces +Y: forward = (-sin(yaw), cos(yaw)).
    return math.deg(math.atan(-x, y)) % 360.0
end

local function registerKeys()
    local function bind(binding, handler)
        local ok, effective = RegisterKeyMapping(binding.id, binding.name, binding.key, handler)
        if not ok then log("error", ("key mapping %s refused: %s"):format(binding.id, tostring(effective))) end
    end
    bind(Config.keys.respawn, function()
        if state and state.canRespawn then TriggerServerEvent("op77_race:respawn") end
    end)
    bind(Config.keys.restart, function()
        if state and state.canRestart then TriggerServerEvent("op77_race:restart") end
    end)
    for action, binding in pairs(Config.editorKeys) do
        bind(binding, function()
            if editorState == nil then return end
            TriggerServerEvent("op77_race:editorAction", { action = action, heading = headingForEditor() })
        end)
    end
    refreshKeys()
end

AddEventHandler("open77:keybinds:changed", refreshKeys)

-- ---------------------------------------------------------------- page --

local function visible()
    return panelOpen or state ~= nil or editorState ~= nil
end

local function syncVisibility()
    if page == nil then return end
    if visible() then pcall(page.show, page) else pcall(page.hide, page) end
end

local function setPanel(open)
    open = open == true
    if page == nil or not pageReady then wantPanel = open; return end
    panelOpen = open
    if open then
        if type(page.setConsumedKeys) == "function" then pcall(page.setConsumedKeys, page, { "escape" }) end
        syncVisibility()
        pcall(page.setFocus, page, true, true)
        send("race:panel", { open = true })
        TriggerServerEvent("op77_race:openMenu")
    else
        pcall(page.setFocus, page, false, false)
        if type(page.setConsumedKeys) == "function" then pcall(page.setConsumedKeys, page, {}) end
        send("race:panel", { open = false })
        TriggerServerEvent("op77_race:closeMenu")
        syncVisibility()
    end
end

local function createPage()
    if creating or page ~= nil then return end
    creating = true
    local options = {
        entry = "web/index.html", layer = "hud", width = 1920, height = 1080, transparent = true,
        -- Created visible (transparent, empty) so the page loads; hidden once ready
        -- while there is nothing to show.
        visible = true, fps = Config.ui.fps or 30, zIndex = Config.ui.zIndex or 730,
    }
    local created, why
    for _ = 1, 120 do
        created, why = WebUI.create(options)
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    creating = false
    if not created then log("error", "no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("race:ready", function()
        pageReady = true
        send("race:config", { labels = { trial = "Time Trial", grid = "Street Race", foot = "Rooftop Race" } })
        refreshKeys()
        if state then send("race:state", state) end
        if editorState then send("race:editor", editorState) end
        if lastMenu then send("race:menu", { json = lastMenu }) end
        syncVisibility()
        if wantPanel then wantPanel = false; setPanel(true) end
    end)
    page:on("race:close", function() setPanel(false) end)
    page:on("race:join", function(payload)
        if type(payload) ~= "table" then return end
        TriggerServerEvent("op77_race:join", { activity = payload.activity, course = payload.course })
    end)
    page:on("race:leave", function() TriggerServerEvent("op77_race:leave") end)
    page:on("race:restart", function() TriggerServerEvent("op77_race:restart") end)
    page:on("race:refresh", function() TriggerServerEvent("op77_race:openMenu") end)
end

-- ---------------------------------------------------------------- server --

RegisterNetEvent("op77_race:state", function(payload)
    if type(payload) ~= "table" then return end
    local previous = state
    state = payload
    local runKey = tostring(payload.instance) .. ":" .. tostring(payload.run)
    if previous == nil or previous.instance ~= payload.instance or previous.run ~= payload.run then stopEffects() end
    if payload.phase == "countdown" and payload.state == "countdown" and countdownFor ~= runKey then
        countdownFor = runKey
        sfx(P.countdownSfx, "op77_race_countdown", 4.0)
    end
    M.sync(payload)
    send("race:state", payload)
    syncVisibility()
end)

RegisterNetEvent("op77_race:pulse", function(payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "go" then
        sfx(P.goSfx, "op77_race_go", 4.0)
        startVfx()
    elseif payload.kind == "checkpoint" then
        sfx(P.checkpointSfx, "op77_race_checkpoint", 1.0)
    elseif payload.kind == "lap" then
        sfx(P.lapSfx, "op77_race_lap", 3.0)
    elseif payload.kind == "finish" then
        sfx(P.finishSfx, "op77_race_finish", 4.0)
    end
    send("race:pulse", payload)
end)

RegisterNetEvent("op77_race:clear", function()
    state, countdownFor = nil, nil
    M.clear()
    stopEffects()
    send("race:clear", {})
    syncVisibility()
end)

RegisterNetEvent("op77_race:menu", function(encoded)
    if type(encoded) ~= "string" then return end
    lastMenu = encoded
    send("race:menu", { json = encoded })
end)

RegisterNetEvent("op77_race:panel", function(open)
    if page == nil then CreateThread(createPage) end
    setPanel(open == true)
end)

RegisterNetEvent("op77_race:editor", function(payload)
    editorState = type(payload) == "table" and payload or nil
    M.preview(editorState and editorState.draft or nil)
    send("race:editor", editorState or { closed = true })
    syncVisibility()
end)

-- ---------------------------------------------------------------- lifecycle --

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    registerKeys()
    CreateThread(function()
        createPage()
        -- After a reconnect or a resource restart mid-race, ask for the current state.
        TriggerServerEvent("op77_race:ready")
    end)
    -- Keep the checkpoint marker alive (a lost native handle is rebuilt).
    CreateThread(function()
        while true do
            Wait(1000)
            if state ~= nil then M.sync(state) end
        end
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    M.clear()
    M.clearPreview()
    stopEffects()
end)
