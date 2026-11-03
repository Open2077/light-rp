-- Public personal-vehicle garages. Server-only: positions can be changed without
-- changing the ownership/parking implementation. Add further locations here.
LightRpGarages = {
    enabled = true,
    defaultGarage = "citycenter",
    maxOwned = 30,
    maxOutside = 1,
    interactRadius = 3.0,
    storeRadius = 18.0,
    stationarySpeed = 0.75,
    clearance = 4.0,
    saveIntervalMs = 15000,
    sessionMs = 180000,
    -- The impound. A personal vehicle left outside at a server restart, or gone
    -- from the world (destroyed, deleted, lost to a bug), is towed there; an owner
    -- can send theirs from any garage (stolen, lost, stuck) and staff can tow one
    -- (/lightrp.impound <vehicle id>). It is recovered at any public garage for
    -- the fee of its reason, in whole eddies (0 = free). `lost` (destroyed, deleted)
    -- is the insurance excess; a restart stays free (docs/economy-balance.md).
    impound = {
        name = "City Impound",
        fees = { restart = 0, lost = 400, requested = 250, staff = 500 },
    },
    marker = { shape = "cylinder", radius = 1.1, height = 0.65,
        color = { r = 255, g = 204, b = 0, a = 150 }, maxDistance = 45, groundOffset = 0.05 },
    garages = {
        {
            id = "citycenter", name = "City Center // Public Garage", bucket = 0,
            -- Beside the existing rental location, with a separate pickup space.
            position = { x = -643.8, y = -383.5, z = 8.19 },
            parking = {
                { position = { x = -643.8, y = -394.0, z = 7.99 }, heading = 143.6 },
                { position = { x = -635.8, y = -394.0, z = 7.99 }, heading = 143.6 },
            },
        },
    },
}
