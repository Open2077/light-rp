-- HUD lab scenes of op77_speedometer: the adapter (client/ui.lua) is fed exactly what
-- client/main.lua sends (speedo:config / data / show / hide), 20 samples a second. No
-- session: no vehicle is read, every sample is written here. Each scene starts from the
-- default config, and leaves its last state on screen.
local S = Speedo
local page, ready = nil, false
local units = "kph"

local function send(name, payload) page:send(name, payload) end
local function config(patch)
    local merged = S.merge(SpeedoConfig, patch or {})
    units = merged.units == "mph" and "mph" or "kph"
    send("speedo:config", S.pageConfig(merged))
end

-- The surface, once; every scene then starts from the defaults.
local function reset(lab)
    if not page then
        local created, why = SpeedoUi.create({ zIndex = SpeedoConfig.zIndex, fps = SpeedoConfig.fps })
        if not created then error("no NativeUI document: " .. tostring(why)) end
        page = created
        page:on("speedo:ready", function() ready = true end)
    end
    for _ = 1, 100 do
        if ready then break end
        lab.wait(50)
    end
    if not ready then error("the document did not load") end
    config()
end

-- what Speedo.sample builds from a vehicle; `kph` and a few overrides are enough here
local function sample(kph, gear, rpm, extra)
    local d = {
        speed = units == "mph" and kph / 1.609344 or kph, kph = kph, gear = gear, rpm = rpm,
        handbrake = false, abs = false, tcs = false, lights = 1, engine = true, health = 0.92, damaged = false,
        tires = 0, brokenLights = 0, reversing = gear == "R",
        fuel = { fraction = 0.62, low = false, empty = false },
    }
    for k, v in pairs(extra or {}) do
        if v == "none" then d[k] = nil else d[k] = v end
    end
    return d
end
local function data(...) send("speedo:data", sample(...)) end
local function show(first, instant)
    send("speedo:data", first)
    send("speedo:show", { name = "QUADRA TYPE66", instant = instant or nil })
end
-- 20 samples a second for `ms`: fn(seconds since the start) -> kph, gear, rpm, extra
local function drive(lab, ms, fn)
    for i = 0, math.floor(ms / 50) do
        data(fn(i * 0.05))
        lab.wait(50)
    end
end

local TOP = { 0, 45, 85, 125, 165, 205, 999 } -- the speed at which each gear ends
local function gearFor(kph, gear)
    while gear < 6 and kph > TOP[gear + 1] do gear = gear + 1 end
    while gear > 1 and kph < TOP[gear] - 8 do gear = gear - 1 end
    local low, high = TOP[gear], math.min(TOP[gear + 1], 260)
    return gear, 0.25 + 0.75 * math.min(1, math.max(0, (kph - low) / (high - low)))
end

-- sat down: the unfold with its self-test (888, the strip sweeps, every tag), then idling on the handbrake
HudLab.scene("sp-idle", function(lab)
    reset(lab)
    send("speedo:hide", {})
    lab.wait(600)
    show(sample(0, "N", 0.12, { handbrake = true }))
    drive(lab, 2000, function() return 0, "N", 0.12, { handbrake = true } end)
end)

-- engine off, standing still: the whole projection dims
HudLab.scene("sp-engine-off", function(lab)
    reset(lab)
    show(sample(0, "N", 0, { engine = false, lights = 0, handbrake = true }), true)
    drive(lab, 1200, function() return 0, "N", 0, { engine = false, lights = 0, handbrake = true } end)
end)

-- 0 to 170 km/h through five gears: the digits follow, the strip rises and falls, each gear pops
HudLab.scene("sp-accelerate", function(lab)
    reset(lab)
    show(sample(0, "1", 0.25), true)
    local gear = 1
    drive(lab, 5000, function(t)
        local kph = math.min(170, t * 36)
        local rpm
        gear, rpm = gearFor(kph, gear)
        return kph, tostring(gear), rpm, { tcs = t < 0.6 }
    end)
end)

-- cruising at 90 in fourth, high beams (the cool colour)
HudLab.scene("sp-cruise", function(lab)
    reset(lab)
    show(sample(90, "4", 0.45, { lights = 2 }), true)
    drive(lab, 2000, function(t) return 90 + math.sin(t * 2) * 1.5, "4", 0.45 + math.sin(t * 2) * 0.02, { lights = 2 } end)
end)

-- hard braking from 140: ABS blinks, the gears come down
HudLab.scene("sp-brake", function(lab)
    reset(lab)
    show(sample(140, "5", 0.6), true)
    drive(lab, 800, function() return 140, "5", 0.6 end)
    local gear = 5
    drive(lab, 2600, function(t)
        local kph = math.max(20, 140 - t * 50)
        local rpm
        gear, rpm = gearFor(kph, gear)
        return kph, tostring(gear), rpm * 0.7, { abs = kph > 22 }
    end)
end)

HudLab.scene("sp-reverse", function(lab)
    reset(lab)
    show(sample(0, "N", 0.15), true)
    drive(lab, 600, function() return 0, "N", 0.15 end)
    drive(lab, 2000, function(t) return math.min(14, t * 10), "R", 0.3 + math.min(0.2, t * 0.1) end)
end)

-- flat out past the scale: the redline blinks, the digits and the bar turn red, the display shakes
HudLab.scene("sp-redline", function(lab)
    reset(lab)
    show(sample(200, "6", 0.8), true)
    drive(lab, 3500, function(t) return math.min(262, 200 + t * 30), "6", math.min(1.02, 0.8 + t * 0.1) end)
end)

-- warnings: low fuel, wrecked engine, two flat tyres, broken lights, wheels slipping
HudLab.scene("sp-warnings", function(lab)
    reset(lab)
    local extra = { fuel = { fraction = 0.1, low = true, empty = false }, health = 0.2, damaged = true, tires = 2, brokenLights = 1, tcs = true }
    show(sample(48, "2", 0.7, extra), true)
    drive(lab, 2500, function() return 48, "2", 0.7, extra end)
end)

-- out of fuel: the gauge blinks red
HudLab.scene("sp-fuel-empty", function(lab)
    reset(lab)
    local extra = { fuel = { fraction = 0, low = true, empty = true }, engine = false }
    show(sample(6, "N", 0, extra), true)
    drive(lab, 2500, function() return 6, "N", 0, extra end)
end)

-- a vehicle without a fuel value: the fuel gauge fades; full tank and condition beside it are in sp-cruise
HudLab.scene("sp-no-fuel", function(lab)
    reset(lab)
    show(sample(63, "3", 0.55, { fuel = "none", health = 1 }), true)
    drive(lab, 1500, function() return 63, "3", 0.55, { fuel = "none", health = 1 } end)
end)

-- miles: the unit, the scale (150) and its ticks every 10
HudLab.scene("sp-mph", function(lab)
    reset(lab)
    config({ units = "mph" })
    show(sample(90, "4", 0.45), true)
    drive(lab, 1500, function() return 90, "4", 0.45 end)
end)

-- a themed variant: every accent part in #3FE0D0 (the gear keeps its own colour)
HudLab.scene("sp-theme", function(lab)
    reset(lab)
    config({ theme = { accent = "#3FE0D0" } })
    show(sample(63, "3", 0.55, { handbrake = true }), true)
    drive(lab, 1500, function() return 63, "3", 0.55, { handbrake = true } end)
end)

-- a layout variant: full size, a stronger tilt, moved up and left; no name, lit leading zeros
HudLab.scene("sp-layout", function(lab)
    reset(lab)
    config({ layout = { scale = 1.0, tiltX = 14, tiltY = -30, offsetX = -80, offsetY = -120 }, showVehicleName = false, leadingZeros = "lit" })
    show(sample(63, "3", 0.55), true)
    drive(lab, 1500, function() return 63, "3", 0.55 end)
end)

-- flat: no tilt, no scanlines, no glow
HudLab.scene("sp-flat", function(lab)
    reset(lab)
    config({ layout = { tilt = false, scale = 1.0 }, theme = { scanlines = false, glow = 0 } })
    show(sample(63, "3", 0.55), true)
    drive(lab, 1500, function() return 63, "3", 0.55 end)
end)

-- got out: folds into a line, nothing left on screen
HudLab.scene("sp-hidden", function(lab)
    reset(lab)
    show(sample(30, "2", 0.4), true)
    drive(lab, 1000, function() return 30, "2", 0.4 end)
    send("speedo:hide", {})
    lab.wait(800)
end)

-- sat down again: the unfold from nothing, the numbers rising from zero
HudLab.scene("sp-shown", function(lab)
    reset(lab)
    send("speedo:hide", {})
    lab.wait(600)
    show(sample(63, "3", 0.55))
    drive(lab, 2000, function() return 63, "3", 0.55 end)
end)
