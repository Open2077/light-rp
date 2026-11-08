-- Register future categories here; each needs a server validator and UI editor
-- (docs/vehicle-customization.md, "Adding a category").
LightRpVehicleCustomization = {
    -- Page order. `soon` = shown greyed with "Coming soon" (no native yet).
    -- `parent` = a sub-panel of that category's editor (not a row of its own in the page's
    -- navigation), bought on its own. `capability` = the native the server must have for the
    -- row to be listed at all (absent: no row, not even greyed).
    -- Wave 2 (PLAN-vehicle-custom-wave2.md): neonAnimation, lightColors, engineSound, stickers,
    -- tag. Their natives are feature-detected; until they and the garage's category registry
    -- exist, the rows are greyed with their reason (tag: hidden).
    categories = {
        { id = "paint", label = "Body paint", description = "Primary and secondary colors", icon = "palette" },
        { id = "livery", label = "Livery", description = "Factory two-tone schemes", icon = "spray" },
        { id = "rims", label = "Rims", description = "Aftermarket wheels and finish", icon = "rims" },
        { id = "body", label = "Body kit", description = "Wings, lips, skirts, roof and bars", icon = "body" },
        { id = "neon", label = "Neon", description = "Under-chassis lights", icon = "neon" },
        { id = "neonAnimation", parent = "neon", label = "Animation", description = "Pulse, strobe, chase, rainbow", icon = "neon" },
        { id = "lights", label = "Lights", description = "Headlight and lamp tint", icon = "lightbulb" },
        { id = "lightColors", parent = "lights", label = "Lamp colors", description = "Brake, reverse, blinkers, interior", icon = "lightbulb" },
        { id = "trim", label = "Trim", description = "Factory variants of this model", icon = "car" },
        { id = "plate", label = "Plate", description = "Registration number", icon = "plate" },
        { id = "stickers", label = "Stickers", description = "Decals from the city's crews", icon = "sticker" },
        { id = "tag", label = "Tag", description = "Your own painted text", icon = "tag", capability = "setTag" },
        { id = "windows", label = "Windows", description = "Side and rear window tint", icon = "windows" },
        { id = "performance", label = "Performance", description = "Engine stages 1 to 3", icon = "performance" },
        { id = "engineSound", label = "Engine sound", description = "Engine and exhaust note", icon = "engine" },
    },
    -- Factory trims (entity appearance variants), per Light RP catalogue key
    -- (shared/config.lua LightRpConfig.vehicles.catalog). The server only accepts an
    -- id listed here for the vehicle's own model and applies the id from this table,
    -- never a name sent by the client. A model without entries does not show the
    -- category. Filled by the lead from in-game measurements (vehicles-api.md, E0.1).
    -- Example:
    --   trims = {
    --       hella = {
    --           { id = "appearance_name_from_the_record", label = "Street" },
    --       },
    --   },
    -- Source: the appearance lists of the 15 dealer models (base docs/generated/
    -- vehicle-components-dealer-2.50.json), one entry per distinct body (bumpers, rims,
    -- plates); colour-only siblings, the stock body, burnt/quest/character cars and
    -- gang liveries are left out. Every id below was spawned and seen in game on
    -- 2026-11-05 (lab 11850). A trim brings its own factory colours; custom paint goes
    -- on top. Labels are provisional (owner to rename). Thrax, Bandit, Merrimac and
    -- Semimaru have a single body: no trim.
    trims = {
        hella = {
            { id = "archer_hella__basic_suburban_1", label = "Suburban" },
            { id = "archer_hella__basic_poor_1", label = "Worn I" },
            { id = "archer_hella__basic_poor_2", label = "Worn II" },
            { id = "archer_hella__basic_poor_3", label = "Worn III" },
            { id = "archer_hella__basic_poor_4", label = "Worn IV" },
        },
        quartz = {
            { id = "archer_quartz__basic_suburban_1", label = "Suburban" },
            { id = "archer_quartz__basic_urban_1", label = "Urban" },
            { id = "archer_quartz__basic_poor_1", label = "Worn I" },
            { id = "archer_quartz__basic_poor_2", label = "Worn II" },
            { id = "archer_quartz__basic_poor_3", label = "Worn III" },
            { id = "archer_quartz__basic_poor_3_4", label = "Worn IV" },
        },
        cortes = {
            { id = "villefort_cortes__basic_suburban_1_01", label = "Suburban" },
            { id = "villefort_cortes__basic_poor_1_01", label = "Worn" },
        },
        colby = {
            { id = "thorton_colby__basic_suburban_1", label = "Suburban I" },
            { id = "thorton_colby__basic_suburban_2", label = "Suburban II" },
            { id = "thorton_colby__basic_urban_01", label = "Urban" },
            { id = "thorton_colby__basic_poor_2", label = "Worn" },
        },
        galena = {
            { id = "thorton_galena__basic_suburban_01", label = "Suburban" },
            { id = "thorton_galena__basic_gt_01", label = "GT" },
            { id = "thorton_galena__basic_poor_01", label = "Worn I" },
            { id = "thorton_galena__basic_poor_09", label = "Worn II" },
        },
        maimai = {
            { id = "makigai_maimai__basic_suburban_01", label = "Suburban" },
            { id = "makigai_maimai__basic_gt_01", label = "GT" },
            { id = "makigai_maimai__basic_poor_01", label = "Worn I" },
            { id = "makigai_maimai__basic_poor_02", label = "Worn II" },
        },
        hozuki = {
            { id = "mizutani_hozuki__basic_urban_01", label = "Urban" },
        },
        supron = {
            { id = "mahir_supron__basic_urban_01", label = "Urban" },
        },
        columbus = {
            { id = "villefort_columbus__basic_suburban_01", label = "Suburban I" },
            { id = "villefort_columbus__basic_suburban_02", label = "Suburban II" },
        },
        kusanagi = {
            { id = "yaiba_kusanagi_basic_asm_r250_regular", label = "R250" },
            { id = "yaiba_kusanagi_basic_asm_r250_naked", label = "R250 Naked" },
            { id = "yaiba_kusanagi_basic_player_02", label = "Street" },
        },
        apollo = {
            { id = "brennan_apollo_basic_player_02", label = "Street" },
        },
    },
    -- Per-model category support, per catalogue key: { paint = true|false, lights = true|false }.
    -- A model or category absent from this table is allowed (no regression). false greys
    -- the category in Auto Studio with `unsupported[category]` and the server refuses it.
    -- Measured (vehicles-api.md E0.1): all 15 dealer models are paintable; only the Bandit
    -- and the Apollo have `customizeLights = false`.
    -- Window tint: the tint pack covers the side and rear glass of the 13 four-wheel dealer
    -- models (base scripts/vehicle-kit/windows); the two bikes have no window to tint.
    support = {
        bandit = { lights = false },
        apollo = { lights = false, windows = false },
        kusanagi = { windows = false },
    },
    unsupported = {
        paint = "This model has no custom paint layer.",
        lights = "This model's lights cannot be tinted.",
        trim = "No factory trim is offered for this model.",
        livery = "This model has no factory two-tone scheme.",
        rims = "No rim fits this model yet.",
        body = "No body part fits this model yet.",
        neon = "Neon is not available on this server.",
        plate = "Plates are not available on this server.",
        performance = "No performance stage exists for this model.",
        windows = "This model has no window to tint.",
        native = "This server build has no support for it yet.",
        rimsPack = "The rim workshop is not installed on this server yet.",
        bodyPack = "The body shop is not installed on this server yet.",
        stagesPack = "Performance tuning is not installed on this server yet.",
        windowsPack = "Window tinting is not installed on this server yet.",
        windowsSoon = "Coming soon.",
        -- wave 2
        neonAnimation = "Neon animations are not available on this server.",
        lightColors = "This model's lamps cannot take other colors.",
        engineSound = "No other engine sound fits this model.",
        stickers = "No sticker fits this model.",
        -- the original sticker pack covers this model (server/config/vehicle_decals.lua) but
        -- this server has not started it
        stickersPack = "Stickers are not installed on this server yet.",
        tag = "Tags are not available on this server.",
        -- the natives exist but this server's garage cannot store the choice yet (it has no
        -- Garage.registerCustomizationCategory): sold, it would be lost at the next autosave
        garage = "This studio cannot store it on your vehicle yet.",
        -- Checked by the client in its own game (the server cannot see it).
        clientPack = "Your game has not loaded this workshop's parts. Reconnect to the server to download them.",
        clientStages = "Your game has not loaded the performance stages (TweakXL). Reconnect to the server.",
        clientLivery = "Your game reports no two-tone scheme on this vehicle.",
    },
    -- Shown after a rims / body preview when this game skipped a part (`skipped` of
    -- customizationAvailable): by the reason at the end of "attach:<key>:<reason>".
    warnings = {
        model_not_registered = "These parts are invisible in your game: its parts pack is missing. Reconnect to download it.",
        slot_absent = "This part has no mount point on this vehicle in your game.",
        other = "Part of this look could not be shown in your game.",
        -- window tint (`tint:<record>:<reason>`): the client found no tinted glass to switch to
        not_covered = "Your game shows no tint on this vehicle: its window tint pack is missing. Reconnect to download it.",
        -- livery (`profile:<id>:not_for_model`): this game has no such template for the model
        not_for_model = "This livery cannot be shown in your game: its livery pack is missing or out of date. Reconnect to download it.",
        -- plate (`plate:<record>:no_plate_widget`): the plate pack does not cover this model yet
        no_plate_widget = "This model keeps its factory plate: custom plates do not show on it yet.",
    },
    -- Neon: presets, the custom colour and the brightness steps (intensity 0-5000, the
    -- native's default is 600). A very dark colour lights nothing and is refused.
    neon = {
        colors = {
            { id = "cyan", label = "Cyan", color = "#00E5FF" },
            { id = "magenta", label = "Magenta", color = "#FF2BD6" },
            { id = "red", label = "Red", color = "#FF1E3C" },
            { id = "amber", label = "Amber", color = "#FFB000" },
            { id = "green", label = "Green", color = "#3CFF6E" },
            { id = "blue", label = "Blue", color = "#2F6BFF" },
            { id = "violet", label = "Violet", color = "#9B3CFF" },
            { id = "white", label = "White", color = "#F2F4FF" },
        },
        intensities = {
            { id = "low", label = "Low", value = 300 },
            { id = "medium", label = "Medium", value = 600 },
            { id = "high", label = "High", value = 1200 },
        },
        radius = 3,
        minBrightness = 0.2, -- HSV value (0..1) below which a colour lights nothing visible
    },
    -- Wave 2 colour rules (Open77.vehicles natives refuse the same looks; the studio says
    -- why before the native has to). Hues in degrees, a colour counts only when its HSV
    -- saturation reaches `minSaturation` (a pale pink is not "red").
    emergency = { red = { from = 340, to = 20 }, blue = { from = 195, to = 255 }, minSaturation = 0.35 },
    -- W2.1 Neon animation, a sub-panel of Neon (Open77.vehicles.setNeonAnimation). Each mode
    -- runs on the fitted neon colour; `color2` = the mode takes a second colour (chase).
    -- `periodMs` is the native's 250..10000 cycle; the reactive modes (speed, brake) take
    -- `reactivePeriodMs`. Strobe never runs faster than 3 Hz (`strobeMinPeriodMs`), and a
    -- chase alternating red and blue is refused (an emergency light). Labels PROVISIONAL.
    neonAnimation = {
        modes = {
            { id = "pulse", label = "Pulse", speed = true },
            { id = "breathe", label = "Breathe", speed = true },
            { id = "strobe", label = "Strobe", speed = true },
            { id = "chase", label = "Chase", speed = true, color2 = true },
            { id = "rainbow", label = "Rainbow", speed = true },
            { id = "speed", label = "Follows speed" },
            { id = "brake", label = "Flash on braking" },
        },
        speeds = {
            { id = "slow", label = "Slow", periodMs = 2400 },
            { id = "medium", label = "Medium", periodMs = 1200 },
            { id = "fast", label = "Fast", periodMs = 600 },
        },
        reactivePeriodMs = 1000,
        strobeMinPeriodMs = 333,
    },
    -- W2.2 Lamp colours, a sub-panel of Lights (Open77.vehicles.setLightColors): any subset of
    -- the groups, nil = factory. Refused (emergency look): red or blue blinkers, blue brake
    -- lights. Brake lights and blinkers must stay visible (`minBrightness`, HSV value 0..1).
    lightColors = {
        groups = {
            { id = "brake", label = "Brake lights", safety = true, refuse = { "blue" } },
            { id = "reverse", label = "Reverse lights" },
            { id = "blinkers", label = "Blinkers", safety = true, refuse = { "red", "blue" } },
            { id = "interior", label = "Interior" },
        },
        presets = { "#FF1E3C", "#FF5A1E", "#FFB000", "#FFE45C", "#F2F4FF", "#3CFF6E", "#00E5FF", "#2F6BFF", "#9B3CFF", "#FF2BD6" },
        minBrightness = 0.35,
    },
    -- W2.3 Engine sound (Open77.vehicles.listEngineSounds / setEngineSound): the choices come
    -- from the platform for this model's class. Applying one rebuilds the car on another
    -- record, like a stage (~0.4 s gone). `preview = false` sells it without a preview, like
    -- Performance. A preview waits `previewCooldownMs` after the previous one (each one is a
    -- rebuild). `listen`: the studio keeps the empty car's engine running after a preview
    -- (Open77.vehicles.setEngineHold) so the new note is heard, and stops it at the end.
    engineSound = { preview = true, previewCooldownMs = 4000, listen = true },
    -- W2.4 Stickers (Open77.vehicles.listStickers / setStickers / getDecalBudget): the stickers
    -- that fit this model, from the sticker pack. Every sticker uses `decals` of the car's
    -- decal budget, shared with the livery: 12 at most (13 crashes every client that sees the
    -- car), enforced here and by the native.
    stickers = { maxPerCar = 12 },
    -- W2.5 Tag (stretch goal, Open77.vehicles.setTag): only listed when the server has the
    -- native. Text is filtered with the plate's banned and reserved words. `fonts` and `spots`
    -- must match the ids the native accepts: PROVISIONAL until the native lands.
    tag = {
        minLength = 1, maxLength = 12, pattern = "^[A-Za-z0-9 %-%.!%?#&]+$", charset = "A-Z a-z 0-9 space - . ! ? # &",
        fonts = { { id = "marker", label = "Marker" }, { id = "block", label = "Block" }, { id = "script", label = "Script" } },
        spots = { { id = "door_left", label = "Left door" }, { id = "door_right", label = "Right door" },
            { id = "hood", label = "Hood" }, { id = "trunk", label = "Trunk" } },
        colors = { "#F2F4FF", "#111114", "#FFCC00", "#FF1E3C", "#00E5FF", "#3CFF6E", "#FF2BD6", "#9B3CFF" },
        minBrightness = 0.08,
    },
    -- Window tint: three levels of the native (Open77.vehicles.setWindowTint, 1 to 3) on
    -- the side and rear glass; the windshield always stays clear. Labels PROVISIONAL.
    windows = {
        -- Open: the tinted glass renders with an Open77 client that switches glass by
        -- resource load + refresh, and the pack revision 75b3fcbb2b6e or later, whose
        -- client.lua lets the studio see the pack (base docs/research/vehicles-api.md,
        -- "W1 résolu"). An older client shows factory glass; an older pack greys the menu.
        -- Set false to grey the category with `unsupported.windowsSoon` and refuse it.
        enabled = true,
        resource = "open77_vehicle_tint",
        levels = {
            { id = "light", label = "Light smoke", level = 1 },
            { id = "dark", label = "Dark smoke", level = 2 },
            { id = "limo", label = "Limo", level = 3 },
        },
    },
    -- Registration plate: PROVISIONAL format (owner to confirm): exactly 7 characters,
    -- capital letters and digits. Stored with the vehicle; shown in the studio, the
    -- garage and the ALT vehicle menu, and drawn on the car's plates for every player.
    plate = { minLength = 7, maxLength = 7, charset = "A-Z0-9", pattern = "^[A-Z0-9]+$" },
    -- Performance stages: the TweakXL records Vehicle.<dealer record>_o77s1..3 shipped by the
    -- `resource` (stageRecord / stageOf exports). Fitted on an empty car at the studio only;
    -- one change per vehicle per `cooldownMs`; a refused purchase (it may have rebuilt the car
    -- and rebuilt it back) waits `retryMs` before the next one.
    stages = { resource = "lightrp_vehicle_stages", max = 3, cooldownMs = 600000, retryMs = 5000,
        labels = { [0] = "Stock", "Stage 1", "Stage 2", "Stage 3" } },
    -- The engine stores one hue for the lights: a grey has no hue and would read as red.
    -- Colours below this HSV saturation (0..1) are refused.
    lightsMinSaturation = 0.25,
    -- A lamp preview (Lights, Lamp colors) switches a parked car's headlights on until the
    -- studio closes, so the colour shows by day; false keeps them as they are.
    showLamps = true,
    sessionMs = 300000, previewIntervalMs = 200,
    -- `position` is the marker the player walks to, like a public garage point: it stands
    -- 3.2 m beside the bay, never on it. Parked on the marker, a car had the marker's lit
    -- cylinder cutting through its sills (measured 2026-11-06, Hella on Bay 01). Bay centres:
    -- 01 (-1034.573, -1702.694), 02 (-1025.971, -1709.573); a car on one bay is 8.75 m from the
    -- other bay's marker, beyond storeRadius, so the studio never picks the neighbour's car.
    workshops = {
        { id = "auto_studio_1", name = "Auto Studio // Bay 01", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1031.373364, y = -1702.693726, z = 11.015274 } },
        { id = "auto_studio_2", name = "Auto Studio // Bay 02", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1029.170703, y = -1709.572754, z = 11.015274 } },
    },
    camera = { radius = 6.5, height = 2.1, targetHeight = 0.7, fov = 55, degreesPerSecond = 10, blendMs = 400,
        -- Per-category framing, eased in over `presetMs`. `angle` is relative to the car's
        -- heading: 90 = in front, -90 = behind, 0 = right side, 180 = left side.
        -- `orbit = false` stops the auto orbit (the arrows still turn it).
        -- `focus = { y, z }` frames a point of the car instead of its centre, from its real
        -- extent: y -1 = rear end .. 1 = front end, z 0 = bottom .. 1 = top; `height` is then
        -- the camera's height above that point. Turning the camera off it widens to `default`.
        presetMs = 700,
        presets = {
            default = { angle = 35, radius = 6.5, height = 2.1, targetHeight = 0.7, orbit = true },
            rims = { angle = 15, radius = 4.2, height = 0.75, targetHeight = 0.35, orbit = false },
            neon = { angle = 35, radius = 6, height = 0.45, targetHeight = 0, orbit = true },
            lights = { angle = 90, radius = 5.5, height = 1.1, targetHeight = 0.6, orbit = false },
            -- The plate hangs low on the rear bumper, under the wing: centred from 2.6 m
            -- (the whole-car framing left it below the frame, 2026-11-06).
            plate = { angle = -90, radius = 2.6, height = 0.35, focus = { y = -1, z = 0.22 }, orbit = false },
            body = { angle = -55, radius = 6.5, height = 2.4, targetHeight = 0.8, orbit = true },
            windows = { angle = 20, radius = 5.8, height = 1.5, targetHeight = 0.95, orbit = true },
            neonAnimation = { angle = 35, radius = 6, height = 0.45, targetHeight = 0, orbit = true },
            -- brake, reverse and blinkers sit at the back: a rear three-quarter view
            lightColors = { angle = -60, radius = 5.5, height = 1.2, targetHeight = 0.6, orbit = false },
            engineSound = { angle = 60, radius = 5, height = 0.9, targetHeight = 0.5, orbit = false },
            stickers = { angle = 0, radius = 6, height = 1.4, targetHeight = 0.7, orbit = true },
            tag = { angle = 0, radius = 5.5, height = 1.3, targetHeight = 0.7, orbit = true },
        } },
}
