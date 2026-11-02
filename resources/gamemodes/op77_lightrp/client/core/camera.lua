-- Third-person camera styles and the cinematic display, ported from Freeroam
-- (resources/gamemodes/freeroam/client/camera.lua; /camchange and /cinematic
-- are server commands in server/modules/camera.lua that ask this client).
--
-- LightRP's default is the dynamic shoulder camera: over-the-shoulder framing,
-- a tighter aim framing, and a wider lens when running and sprinting (the
-- engine's "shoulder" preset, see wiki/third-person-camera.md). The session
-- starts in third person, once; F7 is the player's from then on.
-- A /camchange choice is remembered on this machine (Open77.kvp, per server).
local E = LightRpEvents
local Camera = { cinematic = false }
LightRpCamera = Camera

local STYLES = { "classic", "shoulder", "centered" }
local DEFAULT = "shoulder"
local KEY_STYLE, KEY_SIDE = "camera:style", "camera:shoulder"
local USAGE = "/camchange [classic|shoulder|centered|left|right|shake|reset]"

local function notice(body, kind)
    LightRpUi.send(E.page.notice, { kind = kind or "info", title = "Camera", body = body, durationMs = 4000 })
end
local function stored(key, fallback)
    if type(Open77.kvp) ~= "table" then return fallback end
    local ok, value = pcall(Open77.kvp.get, key, fallback)
    return ok and value ~= nil and value or fallback
end
local function store(key, value)
    if type(Open77.kvp) ~= "table" then return end
    if value == nil then pcall(Open77.kvp.delete, key) else pcall(Open77.kvp.set, key, value) end
end
local function supported() return Open77.camera and type(Open77.camera.configureThirdPerson) == "function" end

-- "none" = the player released the style (/camchange reset): the engine's own framing.
local style = stored(KEY_STYLE, DEFAULT)
local shoulder = stored(KEY_SIDE, "right")
local applied = false

local function apply()
    if style == "none" or not supported() then return false end
    local ok, why = Open77.camera.configureThirdPerson({ style = style, shoulder = shoulder, transition = 0.35 })
    applied = ok == true
    return ok, why
end

-- The default is claimed once the character is in the world (scripted cameras
-- of the creator and the tutorial own the view before that anyway), and the
-- session starts in third person.
local started = false
CreateThread(function()
    while not started or (not applied and style ~= "none") do
        if LightRpUi.characterReady then
            if not applied and style ~= "none" and supported() then apply() end
            if not started and Open77.perspective and type(Open77.perspective.set) == "function" then
                local ok, done = pcall(Open77.perspective.set, "third")
                started = ok and done == true
            end
        end
        Wait(2000)
    end
end)

local function change(request)
    if not supported() then return notice("Camera styles need an updated Open77 client.", "error") end
    local api = Open77.camera
    local name = tostring(request or ""):lower()
    if name == "reset" then
        local ok, why = api.resetThirdPerson()
        if not ok then return notice(tostring(why), "error") end
        style, applied = "none", false
        store(KEY_STYLE, "none")
        return notice("Camera style released: the game's own framing. /camchange shoulder brings it back.")
    end
    if name == "shake" then
        if not applied then return notice("Select a camera style first: /camchange shoulder", "error") end
        local ok, why = api.shakeThirdPerson({ duration = 0.65, frequency = 8, amplitude = { x = 0.03, y = 0.015, z = 0.02 } })
        if not ok then notice(tostring(why), "error") end
        return
    end
    if name == "left" or name == "right" then
        if not applied then return notice("Select a camera style first: /camchange shoulder", "error") end
        local ok, why = api.configureThirdPerson({ shoulder = name })
        if not ok then return notice(tostring(why), "error") end
        shoulder = name
        store(KEY_SIDE, name)
        return notice("Camera on the " .. name .. " shoulder.")
    end
    local nextStyle
    if name == "" then
        local index = 0
        for i, value in ipairs(STYLES) do if value == style then index = i end end
        nextStyle = STYLES[index % #STYLES + 1]
    else
        for _, value in ipairs(STYLES) do if value == name then nextStyle = value end end
    end
    if not nextStyle then return notice(USAGE, "error") end
    local previous = style
    style = nextStyle
    local ok, why = apply()
    if not ok then style = previous; return notice(tostring(why), "error") end
    store(KEY_STYLE, style)
    -- choosing a style is asking to see it: third person
    local tps, reason = Open77.perspective.set("third")
    if not tps then notice("Style " .. style .. " saved; third person refused (" .. tostring(reason) .. ").", "error")
    else notice("Third-person camera: " .. style .. ". /camchange cycles, /camchange reset releases it.") end
end

local function cinematic(request)
    if not Open77.hud or type(Open77.hud.setCinematic) ~= "function" then
        return notice("Cinematic mode needs an updated Open77 client.", "error")
    end
    local enabled = not Camera.cinematic
    if request == "on" then enabled = true elseif request == "off" then enabled = false end
    local ok, why = Open77.hud.setCinematic(enabled)
    if not ok then return notice(tostring(why), "error") end
    Camera.cinematic = enabled
    -- no toast over a clean capture
    if not enabled then notice("Cinematic mode off.") end
end

-- Other LightRP screens borrow the same cinematic claim (this resource holds one):
-- when they let it go, the player's own /cinematic comes back.
function Camera.restoreCinematic()
    if Camera.cinematic and Open77.hud and Open77.hud.setCinematic then return Open77.hud.setCinematic(true) end
    return Open77.hud.setCinematic(false)
end
function Camera.state() return { style = style, shoulder = shoulder, applied = applied, cinematic = Camera.cinematic } end

RegisterNetEvent(E.net.cameraChange, change)
RegisterNetEvent(E.net.cameraCinematic, cinematic)
