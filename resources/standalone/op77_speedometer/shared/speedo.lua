-- op77_speedometer: the pure parts (no host calls), shared by the client, the server and
-- the tests: config merge and sanitizing, the surface crop, one vehicle sample -> the
-- page's payload, and when the display shows.
Speedo = {}

-- The display's flat size before scale and tilt (CSS px; web/app.css draws at this size)
-- and the margin kept around it for the glow, the tilt and the shake.
Speedo.WIDTH = 420
Speedo.HEIGHT = 232
Speedo.PAD = 48

local function clamp(v, lo, hi, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end

local function color(v, default)
    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then return v:upper() end
    return default
end

function Speedo.copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Speedo.copy(v) end
    return out
end

-- Deep merge: tables merge key by key, arrays (handbrakeKeys) and values replace.
function Speedo.merge(base, patch)
    local out = Speedo.copy(base) or {}
    if type(patch) ~= "table" then return out end
    for k, v in pairs(patch) do
        if type(v) == "table" and type(out[k]) == "table" and v[1] == nil and next(v) ~= nil then
            out[k] = Speedo.merge(out[k], v)
        else
            out[k] = Speedo.copy(v)
        end
    end
    return out
end

-- What the page gets: every value checked, so a bad patch cannot break the layout.
function Speedo.pageConfig(c)
    local l, t = c.layout or {}, c.theme or {}
    local units = c.units == "mph" and "mph" or "kph"
    local maxes = type(c.speedMax) == "table" and c.speedMax or {}
    local zeros = c.leadingZeros
    if zeros ~= "lit" and zeros ~= "off" then zeros = "dim" end
    local shake = type(c.shake) == "table" and c.shake or {}
    return {
        units = units,
        unitLabel = units == "mph" and "MPH" or "KPH",
        speedMax = clamp(maxes[units], 20, 999, units == "mph" and 150 or 240),
        showVehicleName = c.showVehicleName ~= false,
        leadingZeros = zeros,
        layout = {
            right = clamp(l.right, 0, 4000, 36),
            bottom = clamp(l.bottom, 0, 2000, 146),
            offsetX = clamp(l.offsetX, -4000, 4000, 0),
            offsetY = clamp(l.offsetY, -2000, 2000, 0),
            scale = clamp(l.scale, 0.4, 1.6, 0.6),
            tilt = l.tilt ~= false,
            tiltX = clamp(l.tiltX, -30, 30, 8),
            tiltY = clamp(l.tiltY, -40, 40, -16),
            avoidHoloGps = l.avoidHoloGps ~= false,
            minScale = clamp(l.minScale, 0.3, 1.6, 0.45),
        },
        theme = {
            accent = color(t.accent, "#FFCC00"),
            core = color(t.core, "#FFF7DA"),
            gear = color(t.gear, color(t.accent, "#FFCC00")),
            warn = color(t.warn, "#FF3B3B"),
            cool = color(t.cool, "#7FD8FF"),
            glow = clamp(t.glow, 0, 2, 1),
            opacity = clamp(t.opacity, 0.3, 1, 1),
            scanlines = t.scanlines ~= false,
            flicker = t.flicker ~= false,
        },
        shake = {
            enabled = shake.enabled ~= false,
            fromKph = clamp(shake.fromKph, 0, 999, 130),
            fullKph = clamp(shake.fullKph, 1, 999, 260),
            amplitude = clamp(shake.amplitude, 0, 6, 1.6),
        },
    }
end

-- The surface crop: only the display's rectangle (plus its margin) is composited. Anchored
-- to the bottom-right corner (negative x / y), so it needs no screen size. The page draws
-- the display at the same place from the same numbers.
function Speedo.bounds(page)
    local l = page.layout
    local right = math.max(0, l.right - l.offsetX)
    local bottom = math.max(0, l.bottom - l.offsetY)
    local w = math.ceil(Speedo.WIDTH * l.scale)
    local h = math.ceil(Speedo.HEIGHT * l.scale)
    local pad = Speedo.PAD
    local top = bottom + h + pad
    return {
        x = -math.floor(right + w + pad),
        y = -math.floor(top),
        width = math.floor(right + w + pad),
        height = math.floor(math.min(h + 2 * pad, top)),
    }
end

-- "Vehicle.v_sport2_quadra_type66_player" -> "QUADRA TYPE66"
function Speedo.vehicleName(record, names)
    record = tostring(record or "")
    if type(names) == "table" and type(names[record]) == "string" then return names[record]:upper() end
    local name = record:gsub("^Vehicle%.", ""):gsub("^v_%w+_", ""):gsub("_player$", ""):gsub("_", " ")
    return name:upper()
end

local DRIVER = { seat_front_left = true, driver = true }
function Speedo.isDriver(seat) return type(seat) == "table" and DRIVER[tostring(seat.seat)] == true end

-- Plain arithmetic (a mask may arrive as a float): bit `bit` (a power of two) of `flags`.
local function has(flags, bit) return math.floor((tonumber(flags) or 0) / bit) % 2 == 1 end
local function popcount(n)
    n = math.floor(tonumber(n) or 0)
    local c = 0
    while n > 0 do c = c + n % 2; n = n // 2 end
    return c
end

-- One vehicle snapshot (Open77.vehicles.get) -> the page's payload.
--   extra = { handbrake = bool, fuel = { litres, capacity } | nil, flags = Open77.vehicles.flags }
function Speedo.sample(vehicle, c, extra)
    extra = extra or {}
    local flagBits = extra.flags or {}
    local num = function(v, d) v = tonumber(v); if v == nil or v ~= v then return d end return v end
    local mps = math.abs(num(vehicle.speed, 0))
    local kph = mps * 3.6
    local speed = c.units == "mph" and mps * 2.236936 or kph
    local gearN = math.floor(num(vehicle.gear, 0))
    local reversing = vehicle.reversing == true or gearN < 0
    local gear = reversing and "R" or (gearN == 0 and "N" or tostring(gearN))
    local rpmMax = num(vehicle.rpmMax, 0)
    local rpm = rpmMax > 0 and math.max(0, math.min(1.08, num(vehicle.rpm, 0) / rpmMax)) or nil
    local flags = num(vehicle.flags, 0)
    local lights = has(flags, flagBits.highBeams or 128) and 2 or (has(flags, flagBits.lightsOn or 64) and 1 or 0)
    local engineOn = has(flags, flagBits.engineOn or 1)
    local health = math.max(0, math.min(1, num(vehicle.health, 1)))
    local brake = num(vehicle.brake, 0)
    local slip = num(vehicle.totalSlip, 0)
    local damage = type(vehicle.damage) == "table" and vehicle.damage or {}
    local out = {
        speed = speed,
        kph = kph,
        gear = gear,
        rpm = rpm,
        handbrake = extra.handbrake == true,
        abs = brake >= num(c.absBrake, 0.6) and kph >= num(c.absMinKph, 12) and not reversing,
        tcs = (vehicle.burnout == true or slip >= num(c.tcsSlip, 0.35)) and kph >= 3,
        lights = lights,
        engine = engineOn,
        health = health,
        damaged = health < num(c.damageWarn, 0.35) or has(flags, flagBits.destroyed or 4),
        tires = popcount(damage.tires or vehicle.tires),
        brokenLights = popcount(damage.lights or vehicle.brokenLights),
        reversing = reversing,
    }
    local f = extra.fuel
    if type(f) == "table" and tonumber(f.litres) then
        local cap = num(f.capacity, 60)
        if cap <= 0 then cap = 60 end
        local fraction = math.max(0, math.min(1, f.litres / cap))
        local reserve = num(type(c.fuel) == "table" and c.fuel.reserve, 0.15)
        out.fuel = { fraction = fraction, low = fraction <= reserve, empty = f.litres <= 0 }
    end
    return out
end

-- Shown while: enabled, seated (driver, or passengers allowed), no menu holding the
-- cursor, and no resource asked to hide it.
function Speedo.shouldShow(c, s)
    if c.enabled == false or not s.seated then return false end
    if not s.driver and c.showForPassengers ~= true then return false end
    if s.busy and c.hideUnderMenus ~= false then return false end
    if s.suppressed then return false end
    return true
end
