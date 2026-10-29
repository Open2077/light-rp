-- op77_speedometer configuration (server owners edit this file). A server resource can
-- also change it at runtime for everyone or one player:
--   exports.op77_speedometer:setConfig({ units = "mph", theme = { accent = "#3FE0D0" } })        -- server
--   exports.op77_speedometer:setConfig({ layout = { scale = 0.9 } }, playerId)                   -- server, one player
--   exports.op77_speedometer:setConfig({ enabled = false })                                     -- client, this player
-- Every key below can be patched; a patch is deep-merged over the current values.
SpeedoConfig = {
    -- Off: no display at all (the vehicle HUD of the gamemode, if any, comes back).
    enabled = true,

    -- "kph" or "mph". The bar's full scale is `speedMax` in the same unit.
    units = "kph",
    speedMax = { kph = 240, mph = 150 },

    -- Who sees it: the driver always, passengers only if true.
    showForPassengers = false,

    -- Hide it while another interface holds the mouse cursor (inventory, menus, the
    -- phone...). Open77.input.isCaptured(), second result.
    hideUnderMenus = true,

    -- Hide the game's own speedometer while this resource runs (ui.vanilla.hud).
    hideNativeSpeedometer = true,

    -- Show the vehicle's name above the display.
    showVehicleName = true,
    -- Records -> names; anything else is derived from the record (Vehicle.v_sport2_quadra_type66 -> QUADRA TYPE66).
    vehicleNames = {},

    -- Where it sits, in CSS pixels of a 1080-pixel-high screen (the WebUI's reference):
    -- distances from the right and bottom edges of the screen to the display's box
    -- (420 x 232 at scale 1). The default fits the band at the right edge between
    -- LightRP's work-order tracker (ends at y 766, 785 on 4:3) and its rental chip
    -- (starts at y 946), above the voice HUD (open-voice, bottom 160 px), and right of
    -- op77_map3d's holo GPS (bottom centre, 780 x 320).
    layout = {
        right = 36,
        bottom = 146,
        offsetX = 0,        -- extra shift, + = right
        offsetY = 0,        -- extra shift, + = down
        scale = 0.6,        -- 0.4 .. 1.6
        tilt = true,        -- the 3D tilt (false: flat, facing the screen)
        tiltX = 8,          -- degrees, + = the top edge leans away
        tiltY = -16,        -- degrees, - = the left side recedes (faces the screen centre)
        -- Shrink (down to minScale) rather than overlap op77_map3d's holo GPS
        -- (780 x 320 at the bottom centre) on narrow screens (4:3, 5:4).
        avoidHoloGps = true,
        minScale = 0.45,
    },

    -- Colours (#RRGGBB). accent = glow and gear, core = the hot white of lit segments,
    -- warn = redline / alarms, cool = high beams.
    theme = {
        accent = "#FFCC00",
        core = "#FFF7DA",
        gear = "#FFCC00",
        warn = "#FF3B3B",
        cool = "#7FD8FF",
        glow = 1.0,         -- 0 .. 2, bloom strength
        opacity = 1.0,      -- 0.3 .. 1
        scanlines = true,
        flicker = true,     -- occasional hologram flicker
    },

    -- Leading zeros of the speed ("063"): "dim" (ghost), "lit" (like the reference) or "off".
    leadingZeros = "dim",

    -- A light shake from `fromKph`, strongest at `fullKph` (in km/h whatever the units).
    shake = { enabled = true, fromKph = 130, fullKph = 260, amplitude = 1.6 },

    -- Indicators. Handbrake: the keys the game uses for it (physical reads, the game's
    -- own bindings are not readable). ABS: lit while braking hard above `absMinKph`.
    -- TCS: lit while the tyres slip (burnout or totalSlip above `tcsSlip`).
    handbrakeKeys = { "SPACE", "padA" },
    absBrake = 0.6,
    absMinKph = 12,
    tcsSlip = 0.35,

    -- Fuel from the vehicle's state bag (LightRP's server/modules/fuel.lua writes these).
    -- No value on the bag: no fuel gauge.
    fuel = { enabled = true, key = "fuel", maxKey = "fuelMax", defaultMax = 60, reserve = 0.15 },

    -- Condition below this (0..1) blinks the engine warning.
    damageWarn = 0.35,

    -- Sampling while in a vehicle (Hz); on foot the seat is polled 4 times a second.
    rate = 20,

    -- WebUI surface: frame rate (fixed at creation) and order. Under LightRP's page (720)
    -- and the voice HUD (760), above op77_map3d's minimap (700).
    fps = 30,
    zIndex = 710,

    -- How long the surface stays up after leaving the vehicle (exit animation).
    exitAnimationMs = 420,

    debug = false,
}
