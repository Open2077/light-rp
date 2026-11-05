-- Free camera: the view leaves the character and flies around it, so a player
-- can watch a scene from another angle while their own body stays in the shot.
-- The body is always the complete third-person one (thirdPersonBody), whatever
-- perspective the player came from, and it does not move: this is a camera,
-- not a noclip. The lens stays inside Config.freecam.radius metres of the
-- character, never under its feet by more than `below`.
--
-- Opened from the player menu (F1) or with its own key; every key is a
-- RegisterKeyMapping, rebindable in Pause > Settings > Key bindings. The page
-- draws the reminder bar at the bottom of the screen from the effective keys.
local Config, E, Ui = LightRpConfig, LightRpEvents.page, LightRpUi
local C, P, I = Open77.camera, Open77.players, Open77.input
local settings = Config.freecam or { enabled = false }
local Freecam = {}
LightRpFreecam = Freecam

local session          -- nil while the player looks through their own eyes
local lastToggle = -1000
local hints = true     -- the reminder bar; remembered between two uses

-- What the character may not do while the player is looking elsewhere. Each
-- block is released by name: resetControls would also drop the walk mode.
local BLOCKS = {
    { "freezePosition", true }, { "freezeRotation", true }, { "allowJump", false }, { "allowAim", false },
    { "allowShoot", false }, { "allowWeapons", false }, { "allowInteraction", false }, { "allowDodge", false },
}
local REFUSALS = {
    disabled = "The free camera is disabled on this server.",
    not_ready = "Your character is not ready yet.",
    busy = "Finish what you are doing first.",
    vehicle = "Step out of the vehicle first.",
    camera_busy = "The camera is already in use.",
    updated_client_required = "Update your game client to use the free camera.",
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function length(x, y, z) return math.sqrt(x * x + y * y + z * z) end

local function keys()
    local result = {}
    for name, key in pairs(settings.keys or {}) do result[name] = I.keyFor(key.id) or key.key end
    return result
end
function Freecam.key()
    local key = settings.keys and settings.keys.toggle
    return key and (I.keyFor(key.id) or key.key) or nil
end
function Freecam.isActive() return session ~= nil end
-- The effective keys (rebindable mappings), also flying the tables' free view.
Freecam.keys = keys

local function publish()
    local s = session
    Ui.send(E.freecam, s and {
        active = true, phase = s.phase, paused = s.paused == true, hints = hints, keys = s.keys,
        radius = s.radius, distance = math.floor((s.distance or 0) * 10 + 0.5) / 10,
        speed = math.floor(s.speed * 10 + 0.5) / 10, fov = math.floor(s.fov + 0.5),
    } or { active = false })
end
local function notice(reason)
    local token = tostring(reason or "unknown"):match("[^\r\n]*"):sub(1, 80)
    Ui.send(E.notice, { kind = "error", title = "Free camera", durationMs = 5000,
        body = REFUSALS[token] or ("The free camera is unavailable (" .. token .. ").") })
end

local function busy()
    if LightRpSafezones and LightRpSafezones.active then return true end
    if LightRpMissionEditor and LightRpMissionEditor.active then return true end
    if LightRpMapEditor and LightRpMapEditor.active then return true end
    if Ui.promptActive or Ui.actionFocus or Ui.supportMode or Ui.creationActive or not Ui.characterReady then return true end
    for _, open in pairs(Ui.dialogs) do if open then return true end end
    return (LightRpConsumables and LightRpConsumables.isActive())
        or (LightRpRefueling and LightRpRefueling.isActive())
        or (LightRpItemWork and LightRpItemWork.isActive())
        or (LightRpActions and LightRpActions.isActive())
        or (LightRpTutorial and LightRpTutorial.cinematic and LightRpTutorial.cinematic()) or false
end

local function stop(reason, cut)
    local s = session
    if not s then return true end
    session = nil
    for _, block in ipairs(s.blocks) do pcall(P[block[1]], not block[2]) end
    if s.camera then
        local registry = C.cameras()
        local live = s.phase == "active" and registry and registry.held and registry.activeCamera == s.camera
        local released, returning
        if live and not cut then released, returning = C.deactivate({ blendMs = settings.blendMs or 0 }) end
        if released and returning then
            -- The definition lives until the view is back in the player's eyes.
            local camera = s.camera
            CreateThread(function() pcall(function() returning:await() end); C.destroy(camera) end)
        else
            C.destroy(s.camera)
        end
    end
    lastToggle = GetGameTimer()
    Ui.log("free camera off (%s)", tostring(reason))
    publish()
    return true
end

-- Behind and above the character, looking where the player was looking.
local function homeShot(s, character)
    local p, f = character.position, s.forward
    local entry = settings.entry or {}
    s.position = { x = p.x - f.x * (entry.back or 3.2), y = p.y - f.y * (entry.back or 3.2), z = p.z + (entry.up or 1.9) }
    s.yaw = math.deg(math.atan(-f.x, f.y))
    s.pitch = entry.pitch or -8
    s.velocity = { x = 0, y = 0, z = 0 }
    s.fov = s.homeFov
end

local function start()
    if session then return false, "already_active" end
    if settings.enabled == false or type(settings.keys) ~= "table" then return false, "disabled" end
    if not Ui.ready then return false, "not_ready" end
    Ui.setMenuOpen(false)
    if LightRpAnimations then LightRpAnimations.close() end
    if busy() then return false, "busy" end
    local character = Open77.character.state()
    if not character or not character.attached or not character.alive then return false, "not_ready" end
    -- nil is "could not be read" (a missing permission, a body still loading), not "mounted".
    local mounted, unread = P.isInVehicle()
    if mounted == true then return false, "vehicle" end
    if mounted == nil then return false, unread or "not_ready" end
    local registry, view = C.cameras(), C.view()
    if registry and registry.held then return false, "camera_busy" end
    if not view then return false, "camera_busy" end

    local limits = settings.fov or {}
    local planar = length(view.forward.x, view.forward.y, 0)
    local s = { phase = "preparing", keys = keys(), blocks = {}, anchor = character.position,
        radius = clamp(settings.radius or 25, 3, 100),
        speed = clamp(settings.speed or 4, settings.minSpeed or 0.5, settings.maxSpeed or 15),
        forward = planar > 0.01 and { x = view.forward.x / planar, y = view.forward.y / planar } or { x = 0, y = 1 },
        homeFov = clamp(limits.default or view.fov or 60, limits.min or 20, limits.max or 100) }
    homeShot(s, character)
    -- Already in third person: start exactly where the view is, so detaching
    -- shows no jump at all. From first person the lens is inside the head.
    local eye = view.position
    if eye and length(eye.x - character.position.x, eye.y - character.position.y, eye.z - character.position.z - 1.6) > 1.2 then
        s.position = { x = eye.x, y = eye.y, z = eye.z }
        s.pitch = clamp(math.deg(math.asin(clamp(view.forward.z, -1, 1))), -85, 85)
    end
    s.lookYaw, s.lookPitch, s.lookFov = s.yaw, s.pitch, s.fov

    local reason
    s.camera, reason = C.create({ position = s.position, rotation = { yaw = s.yaw % 360, pitch = s.pitch }, fov = s.fov, thirdPersonBody = true })
    if not s.camera then return false, reason end
    -- An older client ignores the option: never show a headless body.
    local supported = false
    for _, item in ipairs((C.cameras() or {}).cameras or {}) do
        if item.id == s.camera and item.thirdPersonBody == true then supported = true end
    end
    if not supported then C.destroy(s.camera); return false, "updated_client_required" end

    session = s
    for _, block in ipairs(BLOCKS) do
        local ok, why = P[block[1]](block[2])
        if not ok then stop(why, true); return false, why end
        s.blocks[#s.blocks + 1] = block
    end
    publish()
    CreateThread(function()
        local worked, failure = pcall(function()
            -- A perspective change may still be settling: retry that named
            -- refusal only, never take a view held by someone else.
            local deadline, ok, pending = GetGameTimer() + 2500, false, nil
            repeat
                if session ~= s then return end
                ok, pending = C.activate(s.camera, { blendMs = settings.blendMs or 0 })
                if ok or pending ~= "camera_unavailable" then break end
                Wait(50)
            until GetGameTimer() >= deadline
            if not ok then stop(pending, true); notice(pending); return end
            if pending then
                local _, why = pending:await()
                if session ~= s then return end
                if why then stop(why, true); notice(why); return end
            end
            if session ~= s then return end
            s.phase = "active"
            s.mouseX, s.mouseY, s.wheel = I.axis("mouseDeltaX") or 0, I.axis("mouseDeltaY") or 0, I.axis("mouseWheel") or 0
            s.clock = GetGameTimer()
            publish()
        end)
        if not worked and session == s then stop("script_error", true); notice(failure) end
    end)
    Ui.log("free camera on, %d m around the character", s.radius)
    return true
end

local function update(s)
    local character = Open77.character.state()
    if not character or not character.alive or not character.attached then return stop("player_unavailable", true) end
    if P.isInVehicle() == true then return stop("vehicle") end
    if busy() then return stop("busy") end
    local p = character.position
    -- A teleport or a shove: the scene the player was framing is gone.
    if length(p.x - s.anchor.x, p.y - s.anchor.y, p.z - s.anchor.z) > (settings.leash or 4) then return stop("moved") end
    if s.phase ~= "active" then return end
    local registry = C.cameras()
    if not registry or not registry.held or registry.activeCamera ~= s.camera then return stop("camera_released", true) end

    local now = GetGameTimer()
    local dt = clamp((now - s.clock) / 1000, 0, 0.05)
    s.clock = now
    local x, y, w = I.axis("mouseDeltaX") or s.mouseX, I.axis("mouseDeltaY") or s.mouseY, I.axis("mouseWheel") or s.wheel
    local dx, dy, dw = x - s.mouseX, y - s.mouseY, w - s.wheel
    s.mouseX, s.mouseY, s.wheel = x, y, w
    -- Chat, pause or the player menu own the keys: hold the shot still and
    -- forget what the mouse did meanwhile.
    local paused = I.isCaptured() == true or Open77.session.isMenuOpen() == true
    if paused ~= s.paused then s.paused = paused; s.velocity = { x = 0, y = 0, z = 0 }; publish() end
    if paused then return end

    s.keys = keys()
    local function down(name) return s.keys[name] ~= nil and I.isDown(s.keys[name]) == true end
    -- The flight itself is shared with the tables' free view (client/core/freecam_motion.lua);
    -- the leash: a sphere around the chest, and a floor just under the feet.
    local distance = LightRpFreecamMotion.fly(s, { dx = dx, dy = dy, dw = dw, down = down }, dt, settings,
        { x = p.x, y = p.y, z = p.z + 1, radius = s.radius, floor = p.z - (settings.below or 0.5) })
    s.distance = distance
    local ok, why = C.setTransform(s.camera, { position = s.position, rotation = { yaw = s.lookYaw % 360, pitch = s.lookPitch }, fov = s.lookFov })
    if not ok then stop(why, true); notice(why) end
end

function Freecam.start()
    local ok, why = start()
    if not ok and why ~= "already_active" then notice(why) end
    return ok, why
end
function Freecam.stop(reason) return stop(reason or "closed") end
function Freecam.toggle()
    if GetGameTimer() - lastToggle < 300 then return end
    lastToggle = GetGameTimer()
    if session then stop("key") else Freecam.start() end
end
-- Back behind the character, as on entry.
function Freecam.reset()
    local s = session
    if not s or s.phase ~= "active" or s.paused then return end
    local character = Open77.character.state()
    if not character then return end
    homeShot(s, character)
end
function Freecam.toggleHints()
    if not session or session.paused then return end
    hints = not hints
    publish()
end

function Freecam.bind(page)
    page:on(E.freecam, function(payload)
        if type(payload) ~= "table" then return end
        if payload.operation == "toggle" then Freecam.toggle()
        elseif payload.operation == "stop" then stop("page") end
    end)
    local pressed = { toggle = Freecam.toggle, exit = function() if session and not session.paused then stop("key") end end,
        reset = Freecam.reset, hints = Freecam.toggleHints }
    -- Movement keys are polled while flying; they are mappings all the same so
    -- the player rebinds them like any other key.
    for name, key in pairs(settings.keys or {}) do
        local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, pressed[name] or function() end)
        if not ok then Ui.log("free camera key %s refused: %s", name, tostring(effective)) end
    end
end

AddEventHandler("open77:keybinds:changed", function()
    if session then session.keys = keys(); publish() end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then stop("resource_stopped", true) end
end)
CreateThread(function()
    local published = 0
    while true do
        Wait(session and 0 or 200)
        local s = session
        if s then
            local ok, why = pcall(update, s)
            if not ok then stop("script_error", true); notice(why) end
            if session == s and GetGameTimer() - published >= 120 then published = GetGameTimer(); publish() end
        end
    end
end)
