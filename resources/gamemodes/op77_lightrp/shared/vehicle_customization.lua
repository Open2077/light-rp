-- Register future categories here; each needs a server validator and UI editor
-- (docs/vehicle-customization.md, "Adding a category").
LightRpVehicleCustomization = {
    -- Page order. `soon` = shown greyed with "Coming soon" (no native yet).
    categories = {
        { id = "paint", label = "Body paint", description = "Primary and secondary colors", icon = "palette" },
        { id = "livery", label = "Livery", description = "Factory two-tone schemes", icon = "spray" },
        { id = "rims", label = "Rims", description = "Aftermarket wheels and finish", icon = "rims" },
        { id = "body", label = "Body kit", description = "Wings, lips, skirts, roof and bars", icon = "body" },
        { id = "neon", label = "Neon", description = "Under-chassis lights", icon = "neon" },
        { id = "lights", label = "Lights", description = "Headlight and lamp tint", icon = "lightbulb" },
        { id = "trim", label = "Trim", description = "Factory variants of this model", icon = "car" },
        { id = "plate", label = "Plate", description = "Registration number", icon = "plate" },
        { id = "windows", label = "Windows", description = "Side and rear window tint", icon = "windows" },
        { id = "performance", label = "Performance", description = "Engine stages 1 to 3", icon = "performance" },
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
    -- Window tint: three levels of the native (Open77.vehicles.setWindowTint, 1 to 3) on
    -- the side and rear glass; the windshield always stays clear. Labels PROVISIONAL.
    windows = {
        -- CLOSED until the tinted glass renders in game: the switch works on every glass
        -- component, but ArchiveXL leaves the pack's materials unresolved, so the glass
        -- shows as factory (base docs/research/vehicles-api.md, "W1 - teinte en jeu").
        -- While false the category is greyed with `unsupported.windowsSoon` and refused.
        enabled = false,
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
    -- one change per vehicle per `cooldownMs`.
    stages = { resource = "lightrp_vehicle_stages", max = 3, cooldownMs = 600000,
        labels = { [0] = "Stock", "Stage 1", "Stage 2", "Stage 3" } },
    -- The engine stores one hue for the lights: a grey has no hue and would read as red.
    -- Colours below this HSV saturation (0..1) are refused.
    lightsMinSaturation = 0.25,
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
        presetMs = 700,
        presets = {
            default = { angle = 35, radius = 6.5, height = 2.1, targetHeight = 0.7, orbit = true },
            rims = { angle = 15, radius = 4.2, height = 0.75, targetHeight = 0.35, orbit = false },
            neon = { angle = 35, radius = 6, height = 0.45, targetHeight = 0, orbit = true },
            lights = { angle = 90, radius = 5.5, height = 1.1, targetHeight = 0.6, orbit = false },
            plate = { angle = -90, radius = 4.2, height = 1, targetHeight = 0.5, orbit = false },
            body = { angle = -55, radius = 6.5, height = 2.4, targetHeight = 0.8, orbit = true },
            windows = { angle = 20, radius = 5.8, height = 1.5, targetHeight = 0.95, orbit = true },
        } },
}
