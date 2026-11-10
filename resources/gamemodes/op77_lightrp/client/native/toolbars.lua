-- The passive key bars on NativeUI, bottom centre:
--   * the free camera's reminder bar (was ui/src/features/freecam/Freecam.tsx), from
--     E.page.freecam as client/core/freecam.lua publishes it (the page still sends
--     { operation = "toggle" } back from its menu entry: that part stays in the page);
--   * the Maneki-neko placement tool's bar (was ui/src/features/maneki/ManekiTool.tsx),
--     from E.page.maneki (client/core/maneki_editor.lua).
-- Display only: no focus, no input. They do not follow the shell (the page kept them
-- above its menus and the free camera's bar says "Paused while a menu is open").
local N = LightRpNative
local E = LightRpEvents

local T = {}
LightRpNativeToolbars = T

local QUIET_FADE_MS = 3500
local KEY_NAMES = { "forward", "left", "back", "right", "up", "down", "boost", "slow", "reset", "hints", "exit", "toggle" }
-- ui/src/features/freecam/keyLabels.ts. The page asked the browser for the keyboard layout
-- (WASD or ZQSD); Lua cannot: the movement aliases show both, as the page did until the
-- layout answered.
local ALIASES = { FORWARD = "W/Z", BACK = "S", STRAFE_LEFT = "A/Q", STRAFE_RIGHT = "D" }
local NAMES = { BACKSPACE = "BKSP", CONTROL = "CTRL", RETURN = "ENTER", PAGEUP = "PGUP", PAGEDOWN = "PGDN", MOUSE1 = "LMB", MOUSE2 = "RMB", MOUSE3 = "MMB" }

local doc
local wasFull, quietSince, quietToken = false, nil, 0

--- A mapped key ("forward", "CONTROL", "W") as shown on a keycap.
local function keyLabel(key)
    local raw = tostring(key == nil and "?" or key):upper()
    return ALIASES[raw] or NAMES[raw] or raw
end
T.keyLabel = keyLabel

local function keycaps(keys)
    local out = {}
    for _, name in ipairs(KEY_NAMES) do
        local text = keyLabel(type(keys) == "table" and keys[name] or nil)
        out[name] = { t = text, w = #text > 1 }
    end
    return out
end

local function freecamModel()
    return { full = false, quiet = false, faded = false, paused = false, icVideo = N.icon("video"), status = "",
        distance = "0.0", radius = 0, ratio = 0, near = false, limit = false, rangeNote = "RANGE", speed = "0.0", fov = 0, keys = keycaps(nil) }
end
local function manekiModel()
    return { active = false, icCoins = N.icon("coins"), status = "", nearby = 0, catSize = "16 CM", yaw = 0, hasMessage = false, message = "", messageError = false }
end

local function onFreecam(next)
    if not doc then return end
    local state = type(next) == "table" and next.active and next or { active = false }
    if not state.active then
        wasFull, quietSince = false, nil
        N.patch(doc, "freecam", { full = false, quiet = false, faded = false })
        return
    end
    local keys = keycaps(state.keys)
    if state.hints == false then
        wasFull = false
        if not quietSince then
            -- the small tag fades back 3.5 s after it appears
            quietSince = N.now()
            quietToken = quietToken + 1
            local token = quietToken
            N.patch(doc, "freecam", { faded = false })
            CreateThread(function()
                Wait(QUIET_FADE_MS)
                if quietToken == token and quietSince then N.patch(doc, "freecam", { faded = true }) end
            end)
        end
        N.patch(doc, "freecam", { full = false, quiet = true, keys = keys })
        return
    end
    quietSince = nil
    local radius = tonumber(state.radius) or 0
    local distance = math.min(tonumber(state.distance) or 0, radius)
    local ratio = radius > 0 and distance / radius or 0
    local range = ratio >= 0.995 and "limit" or ratio >= 0.8 and "near" or "ok"
    N.patch(doc, "freecam", {
        full = true, quiet = false, faded = false, paused = state.paused == true, keys = keys,
        status = state.phase ~= "active" and "Stepping out of your view…" or state.paused and "Paused while a menu is open" or "Your character stays where it is",
        distance = ("%.1f"):format(distance), radius = radius, ratio = N.round(ratio * 100),
        near = range == "near", limit = range == "limit", rangeNote = range == "limit" and "RANGE LIMIT" or "RANGE",
        speed = ("%.1f"):format(tonumber(state.speed) or 0), fov = tonumber(state.fov) or 0,
    })
    if not wasFull then
        wasFull = true
        -- the keys rise one after the other (freecam-key, 40 ms apart)
        pcall(doc.animate, doc, ".fc .bar-item", { from = { opacity = 0, y = 6 }, to = { opacity = 1, y = 0 }, duration = 0.4, easing = "ease", stagger = 0.04 })
    end
end

local function onManeki(next)
    if not doc then return end
    local state = type(next) == "table" and next.active and next or { active = false }
    if not state.active then N.patch(doc, "maneki", { active = false }); return end
    local scale = tonumber(state.scale)
    local size = (not scale or scale <= 1) and "16 CM" or ("×%s · %d CM"):format(tostring(math.tointeger(scale) or scale), N.round(16 * scale))
    local status
    if state.hovered then
        status = ("Aimed: %s%s. DELETE removes it."):format(tostring(state.hovered), state.hoveredFound and " (you found it)" or "")
    else
        status = state.aim and "Ready: LEFT CLICK hides a cat here." or "Aim at a floor, a shelf or a ledge within 35 m."
    end
    local message = type(state.message) == "string" and state.message ~= "" and state.message or nil
    N.patch(doc, "maneki", {
        active = true, status = status, nearby = tonumber(state.nearby) or 0, catSize = size, yaw = tonumber(state.yaw) or 0,
        hasMessage = message ~= nil, message = message or "", messageError = state.ok == false,
    })
end

N.onStart(function()
    doc = N.create({ document = "ui/native/toolbars.rml", zIndex = 805, models = { freecam = freecamModel(), maneki = manekiModel() } })
end)
N.on(E.page.freecam, onFreecam)
N.on(E.page.maneki, onManeki)
