-- Client side of the ripperdoc interface: owns the WebUI surface, the input focus and the
-- interface sounds. The page contract is PROTOCOL.md.
--
-- Focus: open -> setFocus(true, true) (the patient lies on the table: keyboard and mouse to the
-- page); closed -> setFocus(false, false). The surface stays visible with a transparent body.

local page
local pageReady = false
local isOpen = false
local pending -- an open that arrived before the page was ready
-- The page answers an open within a few hundred ms (its "open" sound). One that stays
-- silent holds the keyboard and mouse with nothing on screen: every input blocked
-- (LightRP Testing, 2026-11-04). Past ANSWER_MS without a word from the page, the focus
-- goes back to the game, the interface closes and the patient gets up.
local ANSWER_MS = 4000
local openSeq, answered = 0, true
local function log(fmt, ...) print("[ripperdoc] " .. fmt:format(...)) end

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

-- page:send refuses more than 1024 values without a word; the open and the state carry
-- the whole catalogue (~1600 values). They travel as JSON text, one message when it fits
-- PART_BYTES, else in parts; web/bridge-parts.js decodes them before the page's handlers.
local PART_BYTES = 48 * 1024
local partSeq = 0
-- Open77.json.encode returned nil for the clinic's payload in game (2026-11-04 02:06, "rd:open
-- could not be encoded: nil"): a plain Lua encoder (op77_lightrp's mission editor's, proven in
-- game) does it. An empty table goes as {}; the page reads both {} and [].
local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function encodeString(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESCAPES[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end
local function encode(value, depth, out)
    local t = type(value)
    if t == "nil" then out[#out + 1] = "null"
    elseif t == "boolean" then out[#out + 1] = value and "true" or "false"
    elseif t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then out[#out + 1] = "null"
        elseif math.type(value) == "integer" then out[#out + 1] = tostring(value)
        else out[#out + 1] = string.format("%.14g", value) end
    elseif t == "string" then out[#out + 1] = encodeString(value)
    elseif t == "table" then
        if depth > 32 then error("too deep") end
        local n, count = #value, 0
        for _ in pairs(value) do count = count + 1 end
        if n > 0 and n == count then
            out[#out + 1] = "["
            for i = 1, n do
                if i > 1 then out[#out + 1] = "," end
                encode(value[i], depth + 1, out)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            for k, v in pairs(value) do
                if type(k) == "string" or type(k) == "number" then
                    if not first then out[#out + 1] = "," end
                    first = false
                    out[#out + 1] = encodeString(tostring(k))
                    out[#out + 1] = ":"
                    encode(v, depth + 1, out)
                end
            end
            out[#out + 1] = "}"
        end
    else out[#out + 1] = "null" end
    return out
end
local function encodeJson(value) return table.concat(encode(value, 0, {})) end
local function sendLarge(name, payload)
    if not page or not pageReady then return false end
    local ok, text = pcall(encodeJson, payload == nil and {} or payload)
    if not ok or type(text) ~= "string" then
        print("[ripperdoc] " .. name .. " could not be encoded: " .. tostring(text))
        return false
    end
    if #text <= PART_BYTES then page:send(name, { __json = text }) return true end
    partSeq = partSeq + 1
    local id, parts, at = name .. ":" .. partSeq, {}, 1
    while at <= #text do
        local stop = math.min(#text, at + PART_BYTES - 1)
        while stop < #text and stop > at do -- never split a UTF-8 sequence
            local b = text:byte(stop + 1)
            if b < 0x80 or b >= 0xC0 then break end
            stop = stop - 1
        end
        parts[#parts + 1] = text:sub(at, stop)
        at = stop + 1
    end
    for i, part in ipairs(parts) do page:send(name, { __part = { id = id, i = i, n = #parts, text = part } }) end
    return true
end

local close
local function open(payload)
    if not page or not pageReady then
        pending = payload or {}
        log("open queued: page %s", page and "not ready yet" or "missing")
        return
    end
    isOpen = true
    openSeq = openSeq + 1
    local seq = openSeq
    answered = false
    pcall(function() page:show() end)
    sendLarge("rd:open", payload or {})
    local ok, why = pcall(function() return page:setFocus(true, true) end)
    log("open sent (#%d), focus %s", seq, ok and "taken" or ("refused: " .. tostring(why)))
    CreateThread(function()
        Wait(ANSWER_MS)
        if isOpen and openSeq == seq and not answered then
            log("the page did not answer the open #%d in %d ms: focus released, interface closed", seq, ANSWER_MS)
            close(true)
        end
    end)
end

-- Any word from the page after an open: it is alive.
local function heard(what)
    if isOpen and not answered then
        answered = true
        log("page answered the open #%d (%s)", openSeq, tostring(what))
    end
end

close = function(notify)
    pending = nil
    if not isOpen then return end
    isOpen = false
    send("rd:close", {})
    if page then pcall(function() page:setFocus(false, false) end) end
    log("closed (%s)", notify and "by the patient or the watchdog" or "by the server")
    for _, entry in pairs(slots) do StopSound(entry.id) end
    if notify then TriggerServerEvent("op77_ripperdoc:closed") end
end

local function createPage()
    local created, why
    for _ = 1, 120 do
        created, why = Open77.webui.create({
            entry = "web/index.html", layer = "menu", zIndex = 45, width = 1920, height = 1080,
            transparent = true, visible = true, fps = 60,
        })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then print("[ripperdoc] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("ui:ready", function()
        pageReady = true
        log("page ready")
        if pending then local payload = pending pending = nil open(payload) end
    end)
    -- The patient left (Esc on the full body, or the page's close): give the game back.
    page:on("rd:close", function() heard("close"); close(true) end)
    page:on("rd:sound", function(payload)
        heard("sound")
        local name = type(payload) == "table" and type(payload.name) == "string" and payload.name or ""
        if name:match("^[%w_]+$") then playSound(name) end
    end)
    -- An install / removal: the server's clinic owner decides and answers (rd:result, rd:state).
    page:on("rd:action", function(payload)
        heard("action")
        if type(payload) ~= "table" then return end
        TriggerServerEvent("op77_ripperdoc:action", { op = payload.op, item = payload.item, replace = payload.replace })
    end)
end

RegisterNetEvent("op77_ripperdoc:open", function(payload) open(type(payload) == "table" and payload or {}) end)
-- The way out when nothing else answers: F8 console "ripperdoc.release" gives the game back.
if type(RegisterCommand) == "function" then
    RegisterCommand("ripperdoc.release", function()
        log("released from the console")
        if isOpen then close(true) elseif page then pcall(function() page:setFocus(false, false) end) end
    end, false)
end
RegisterNetEvent("op77_ripperdoc:close", function() close(false) end)
RegisterNetEvent("op77_ripperdoc:result", function(result) if isOpen then send("rd:result", type(result) == "table" and result or {}) end end)
RegisterNetEvent("op77_ripperdoc:update", function(payload) if isOpen then sendLarge("rd:state", type(payload) == "table" and payload or {}) end end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    if page then pcall(function() page:setFocus(false, false) end) end
end)

CreateThread(createPage)
