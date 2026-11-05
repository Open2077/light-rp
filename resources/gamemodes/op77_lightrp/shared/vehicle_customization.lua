-- Register future categories here; each needs a server validator and UI editor
-- (docs/vehicle-customization.md, "Adding a category").
LightRpVehicleCustomization = {
    categories = {
        { id = "paint", label = "Body paint", description = "Primary and secondary colors", icon = "palette" },
        { id = "lights", label = "Lights", description = "Headlight and lamp tint", icon = "lightbulb" },
        { id = "trim", label = "Trim", description = "Factory variants of this model", icon = "car" },
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
    support = {
        bandit = { lights = false },
        apollo = { lights = false },
    },
    unsupported = {
        paint = "This model has no custom paint layer.",
        lights = "This model's lights cannot be tinted.",
        trim = "No factory trim is offered for this model.",
    },
    -- The engine stores one hue for the lights: a grey has no hue and would read as red.
    -- Colours below this HSV saturation (0..1) are refused.
    lightsMinSaturation = 0.25,
    sessionMs = 300000, previewIntervalMs = 200,
    workshops = {
        { id = "auto_studio_1", name = "Auto Studio // Bay 01", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1034.573364, y = -1702.693726, z = 11.015274 } },
        { id = "auto_studio_2", name = "Auto Studio // Bay 02", bucket = 0, interactRadius = 3, storeRadius = 6,
          position = { x = -1025.970703, y = -1709.572754, z = 11.015274 } },
    },
    camera = { radius = 6.5, height = 2.1, targetHeight = 0.7, fov = 55, degreesPerSecond = 10, blendMs = 400 },
}
