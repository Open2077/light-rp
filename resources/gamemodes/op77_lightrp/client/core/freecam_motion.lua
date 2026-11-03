-- One step of a flying camera, shared by the free camera (client/core/freecam.lua)
-- and the free view of a table (client/core/board_games.lua): mouse look with
-- a narrower lens turning slower, the wheel for speed (or the lens with the
-- precision key), movement along the look direction that builds up and dies
-- down, then a leash: a sphere around a centre and a floor.
--
--   Motion.fly(s, input, dt, settings, bound) -> distance from the centre
--   s:        {position, velocity, yaw, pitch, fov, lookYaw, lookPitch, lookFov, speed}
--   input:    {dx, dy, dw (mouse counts / wheel notches), down = function(name)}
--             names: forward back left right up down boost slow
--   settings: the shape of LightRpConfig.freecam (sensitivity, fov, smoothing,
--             minSpeed, maxSpeed, boost, precision)
--   bound:    {x, y, z (centre), radius, floor (lowest lens height)}
-- About 300 VM instructions: cheap enough for every frame of the 176 client.
local Motion = {}
LightRpFreecamMotion = Motion

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function length(x, y, z) return math.sqrt(x * x + y * y + z * z) end
-- Frame-rate independent approach: `rate` is how fast the gap closes, per second.
local function ease(rate, dt) return 1 - math.exp(-rate * dt) end
Motion.clamp, Motion.length, Motion.ease = clamp, length, ease

-- Yaw / pitch (degrees) looking along a direction, in the camera API's convention.
function Motion.angles(fx, fy, fz)
    local l = length(fx, fy, fz)
    if l < 1e-6 then return 0, 0 end
    return math.deg(math.atan(-fx / l, fy / l)), clamp(math.deg(math.asin(clamp(fz / l, -1, 1))), -85, 85)
end

function Motion.fly(s, input, dt, settings, bound)
    local down = input.down
    local limits, smooth = settings.fov or {}, settings.smoothing or {}
    -- Look: a narrow lens turns slower, so a zoomed shot stays steerable.
    local sensitivity = (settings.sensitivity or 0.12) * clamp(s.fov / 60, 0.3, 1.4)
    s.yaw = s.yaw - clamp(input.dx or 0, -600, 600) * sensitivity
    s.pitch = clamp(s.pitch - clamp(input.dy or 0, -600, 600) * sensitivity, -85, 85)
    local dw = input.dw or 0
    if dw ~= 0 then
        if down("slow") then s.fov = clamp(s.fov - dw * 3, limits.min or 20, limits.max or 100)
        else s.speed = clamp(s.speed * 1.15 ^ clamp(dw, -8, 8), settings.minSpeed or 0.5, settings.maxSpeed or 15) end
    end
    local look = ease(smooth.look or 18, dt)
    s.lookYaw = s.lookYaw + (s.yaw - s.lookYaw) * look
    s.lookPitch = s.lookPitch + (s.pitch - s.lookPitch) * look
    s.lookFov = s.lookFov + (s.fov - s.lookFov) * ease(smooth.zoom or 8, dt)

    -- Move along the drawn direction; speed builds up and dies down.
    local yaw, pitch = math.rad(s.lookYaw), math.rad(s.lookPitch)
    local fx, fy, fz = -math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)
    local forward = (down("forward") and 1 or 0) - (down("back") and 1 or 0)
    local side = (down("right") and 1 or 0) - (down("left") and 1 or 0)
    local up = (down("up") and 1 or 0) - (down("down") and 1 or 0)
    local wx, wy, wz = fx * forward + math.cos(yaw) * side, fy * forward + math.sin(yaw) * side, fz * forward + up
    local pace = s.speed * (down("boost") and (settings.boost or 3) or (down("slow") and (settings.precision or 0.25) or 1))
        / math.max(1, length(wx, wy, wz))
    local v, glide = s.velocity, ease(smooth.move or 9, dt)
    v.x, v.y, v.z = v.x + (wx * pace - v.x) * glide, v.y + (wy * pace - v.y) * glide, v.z + (wz * pace - v.z) * glide
    local nx, ny, nz = s.position.x + v.x * dt, s.position.y + v.y * dt, s.position.z + v.z * dt

    -- The leash: a sphere around the centre, and a floor.
    if nz < bound.floor then nz = bound.floor; if v.z < 0 then v.z = 0 end end
    local ox, oy, oz = nx - bound.x, ny - bound.y, nz - bound.z
    local distance = length(ox, oy, oz)
    if distance > bound.radius then
        local scale = bound.radius / distance
        nx, ny, nz = bound.x + ox * scale, bound.y + oy * scale, bound.z + oz * scale
        -- Slide along the limit instead of bouncing: drop the outward speed.
        local out = (v.x * ox + v.y * oy + v.z * oz) / distance
        if out > 0 then v.x, v.y, v.z = v.x - ox / distance * out, v.y - oy / distance * out, v.z - oz / distance * out end
        distance = bound.radius
        -- The sphere may reach below the floor: the floor wins.
        if nz < bound.floor then nz = bound.floor end
    end
    s.position = { x = nx, y = ny, z = nz }
    return distance
end
