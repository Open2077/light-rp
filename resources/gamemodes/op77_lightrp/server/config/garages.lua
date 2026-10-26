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
