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
    trims = {},
    -- Per-model category support, per catalogue key: { paint = true|false, lights = true|false }.
    -- A model or category absent from this table is allowed (no regression). false greys
    -- the category in Auto Studio with `unsupported[category]` and the server refuses it.
    -- Filled by the lead from in-game measurements. Example: support = { kusanagi = { paint = false } },
    support = {},
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
