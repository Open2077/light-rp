-- Client side of the ripperdoc interface: owns the WebUI surface, the input focus and the
-- interface sounds. The page contract is PROTOCOL.md.
--
-- Focus: open -> setFocus(true, true) (the patient lies on the table: keyboard and mouse to the
-- page); closed -> setFocus(false, false). The surface stays visible with a transparent body.

local page
local pageReady = false
local isOpen = false
local pending -- an open that arrived before the page was ready

local SOUNDS = {
    open = 0.85, close = 0.8, zoom_in = 0.8, zoom_out = 0.75, hover = 0.35, press = 0.6, menu_open = 0.7,
    equip = 0.8, unequip = 0.8, install = 0.9, upgrade = 0.85, bought = 0.8, denied = 0.75, tick_up = 0.4,
    tick_down = 0.4, gauge = 0.6, glitch = 0.5, scan_tag = 0.45, scan_done = 0.7, granted = 0.85, beeps = 0.3,
}

-- ---------------------------------------------------------------------------
-- Sounds: a resource owns at most 16 handles and a finished clip keeps its handle, so each
-- slot keeps one handle and restarts it (the Neural-Link's pattern). Slots group the names
-- so a busy interface never needs more than 8.
local SLOT = {
    hover = "tick", tick_up = "tick", tick_down = "tick", scan_tag = "tick",
    press = "press", denied = "press", equip = "press", unequip = "press",
    open = "big", close = "big", menu_open = "big", granted = "big", bought = "big",
    zoom_in = "zoom", zoom_out = "zoom",
    install = "surgery", upgrade = "surgery", scan_done = "surgery",
    gauge = "gauge", glitch = "glitch", beeps = "ambient",
}
local slots = {}
local soundFailure

local function playSound(name)
    local volume = SOUNDS[name]
    if not volume then return end
    local slot = SLOT[name] or name
    local file = "web/media/sfx/" .. name .. ".mp3"
    local entry = slots[slot]
    if entry and entry.file ~= file then DestroySound(entry.id) entry = nil end
    if entry then
        local state = GetSoundState(entry.id)
        if state and state.status ~= "error" then
            StopSound(entry.id)
            SetSoundVolume(entry.id, volume)
            if PlaySound(entry.id) then return end
        end
        DestroySound(entry.id)
        entry = nil
    end
    slots[slot] = nil
    local id, why = Play2DSound(file, { volume = volume })
    if id then
        slots[slot] = { id = id, file = file }
    elseif why ~= soundFailure then
        soundFailure = why
        print("[ripperdoc] sound " .. name .. " refused: " .. tostring(why))
    end
end

-- ---------------------------------------------------------------------------
local function send(name, payload)
    if page and pageReady then page:send(name, payload == nil and {} or payload) end
end

local function open(payload)
    if not page or not pageReady then pending = payload or {} return end
    isOpen = true
    send("rd:open", payload or {})
    page:setFocus(true, true)
end

local function close(notify)
    pending = nil
    if not isOpen then return end
    isOpen = false
    send("rd:close", {})
    if page then page:setFocus(false, false) end
    for _, entry in pairs(slots) do StopSound(entry.id) end
    if notify then TriggerServerEvent("op77_ripperdoc:closed") end
end

local function createPage()
    local created, why
    for _ = 1, 120 do
        created, why = Open77.webui.create({
            entry = "web/index.html", layer = "menu", zIndex = 45,
            transparent = true, visible = true, fps = 60,
        })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then print("[ripperdoc] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("ui:ready", function()
        pageReady = true
        if pending then local payload = pending pending = nil open(payload) end
    end)
    -- The patient left (Esc on the full body, or the page's close): give the game back.
    page:on("rd:close", function() close(true) end)
    page:on("rd:sound", function(payload)
        local name = type(payload) == "table" and type(payload.name) == "string" and payload.name or ""
        if name:match("^[%w_]+$") then playSound(name) end
    end)
    -- The installation system is not wired yet: the page's actions are only logged.
    page:on("rd:action", function(payload)
        if type(payload) == "table" then
            print(("[ripperdoc] preview action %s %s/%s"):format(tostring(payload.op), tostring(payload.section), tostring(payload.item)))
        end
    end)
end

RegisterNetEvent("op77_ripperdoc:open", function(payload) open(type(payload) == "table" and payload or {}) end)
RegisterNetEvent("op77_ripperdoc:close", function() close(false) end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    if page then pcall(function() page:setFocus(false, false) end) end
end)

CreateThread(createPage)
