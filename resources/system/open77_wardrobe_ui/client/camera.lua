-- The fitting room's camera: a scripted camera (camera.script) in front of the
-- character that frames what is being edited. Each category has a shot (full
-- look, head, torso, legs, feet); the page asks for one with wardrobe:focus,
-- turns around the character with wardrobe:orbit and zooms with wardrobe:zoom.
-- Every change glides there instead of cutting. The character does not move
-- while the fitting room owns input, so the shots are laid out once around the
-- position and facing read when the room opens.
WardrobeCamera = {}

-- distance: metres from the body axis; height: lens height above the feet;
-- look: aimed point above the feet; fov: degrees.
local SHOTS = {
    full  = { distance = 3.15, height = 1.10, look = 0.98, fov = 44 },
    head  = { distance = 1.05, height = 1.66, look = 1.62, fov = 32 },
    torso = { distance = 1.65, height = 1.36, look = 1.24, fov = 38 },
    legs  = { distance = 1.85, height = 0.86, look = 0.66, fov = 40 },
    feet  = { distance = 1.40, height = 0.48, look = 0.14, fov = 38 },
}
local ZOOM_MIN, ZOOM_MAX = 0.6, 1.55

local cam, live, anchor, facing = nil, false, nil, nil
local target, current, owner = nil, nil, 0

local function copy(shot, orbit)
    return { distance = shot.distance, height = shot.height, look = shot.look, fov = shot.fov, orbit = orbit, zoom = 1.0 }
end
local function lerp(a, b, k) return a + (b - a) * k end
-- Orbit 180 is the front of the character (the convention of Open77.camera.orbit).
local function angleLerp(a, b, k)
    local d = ((b - a + 540) % 360) - 180
    return a + d * k
end
local function place(shot)
    local a = math.rad(shot.orbit - 180)
    local fx, fy = facing.x, facing.y
    local dx, dy = fx * math.cos(a) - fy * math.sin(a), fx * math.sin(a) + fy * math.cos(a)
    local d = shot.distance * shot.zoom
    return { x = anchor.x + dx * d, y = anchor.y + dy * d, z = anchor.z + shot.height },
        { x = anchor.x, y = anchor.y, z = anchor.z + shot.look }
end

function WardrobeCamera.available()
    return type(Open77.camera) == "table" and type(Open77.camera.create) == "function"
        and type(Open77.camera.activate) == "function"
end
function WardrobeCamera.active() return live end

-- Puts the camera up in front of the character. Returns true once the shot is live.
function WardrobeCamera.start(orbit)
    if live then return true end
    if not WardrobeCamera.available() then return false, "unsupported" end
    local state = Open77.character.state()
    if type(state) ~= "table" or type(state.position) ~= "table" then return false, "no_character" end
    local f = type(state.forward) == "table" and state.forward or { x = 0, y = 1 }
    local length = math.sqrt(f.x * f.x + f.y * f.y)
    if length < 0.01 then f, length = { x = 0, y = 1 }, 1 end
    anchor = { x = state.position.x, y = state.position.y, z = state.position.z }
    facing = { x = f.x / length, y = f.y / length }
    target = copy(SHOTS.full, orbit or 180)
    current = copy(SHOTS.full, orbit or 180)
    local position, look = place(current)
    if not cam then
        cam = Open77.camera.create({ position = position, lookAt = look, fov = current.fov, thirdPersonBody = true })
        if not cam then return false, "create_failed" end
    end
    -- Refused while a perspective transition is in flight (opening from first
    -- person switches to third person, which takes a few seconds): retry.
    local ok, reason
    for _ = 1, 60 do
        ok, reason = Open77.camera.activate(cam, { blendMs = 650 })
        if ok or reason ~= "camera_unavailable" then break end
        Wait(100)
    end
    if not ok then return false, reason end
    live = true
    owner = owner + 1
    local token, last = owner, Open77.time.monotonic()
    CreateThread(function()
        while live and token == owner do
            Wait(0)
            local now = Open77.time.monotonic()
            local k = 1 - math.exp(-math.max(0, now - last) * 7.5)
            last = now
            current.distance = lerp(current.distance, target.distance, k)
            current.height = lerp(current.height, target.height, k)
            current.look = lerp(current.look, target.look, k)
            current.fov = lerp(current.fov, target.fov, k)
            current.orbit = angleLerp(current.orbit, target.orbit, k)
            current.zoom = lerp(current.zoom, target.zoom, k)
            local p, l = place(current)
            local moved = Open77.camera.setTransform(cam, { position = p, fov = current.fov })
            if moved == false then live = false; break end -- released (death, world exit, another owner)
            Open77.camera.lookAt(cam, l)
        end
    end)
    return true
end

function WardrobeCamera.focus(zone)
    local shot = SHOTS[zone]
    if not shot or not target then return false end
    local orbit = target.orbit
    target = copy(shot, orbit)
    return true
end
function WardrobeCamera.orbit(degrees)
    if not target then return false end
    target.orbit = degrees
    return true
end
function WardrobeCamera.zoom(delta)
    if not target then return false end
    target.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, target.zoom + (tonumber(delta) or 0) * 0.08))
    return true
end

function WardrobeCamera.stop()
    owner = owner + 1
    if live then
        live = false
        pcall(Open77.camera.deactivate, { blendMs = 450 })
    end
    if cam then pcall(Open77.camera.destroy, cam); cam = nil end
    target, current = nil, nil
end
