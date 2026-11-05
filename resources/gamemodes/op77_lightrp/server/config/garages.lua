-- Public personal-vehicle garages. Server-only: positions can be changed without
-- changing the ownership/parking implementation. Add further locations here.
LightRpGarages = {
    enabled = true,
    defaultGarage = "kabuki",
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
    -- the fee of its reason, in whole eddies (0 = free), docs/economy-balance.md:
    --   destroyed  a wreck (destroyed / exploded / health 0, whoever did it), at a
    --              restart, a removal or the owner's own tow: the insurance excess;
    --              the insurance repairs it
    --   lost       gone with no sign of a wreck (deleted, cleaned up, lost to a bug)
    --   restart    intact and left outside at a server restart: free
    impound = {
        name = "City Impound",
        fees = { restart = 0, destroyed = 1500, lost = 600, requested = 500, staff = 750 },
    },
    marker = { shape = "cylinder", radius = 1.1, height = 0.65,
        color = { r = 255, g = 204, b = 0, a = 150 }, maxDistance = 45, groundOffset = 0.05 },
    -- Thirteen public garages at the poses the owner took in game (2026-11-05). The pose is the pickup bay
    -- (where the car appears); the garage point is 4 m behind it, so the player who asks for a car is not
    -- standing on the bay (clearSpace refuses within 2 m). District names are a best guess (rename freely,
    -- the ids stay). The City Center garage was removed: its stored vehicles move to defaultGarage at load.
    garages = {
        {
            id = "kabuki", name = "Kabuki // Public Garage", bucket = 0,
            position = { x = -815.317, y = 764.399, z = 22.454 },
            parking = { { position = { x = -816.401978, y = 768.249207, z = 22.254082 }, heading = 15.743070 } },
        },
        {
            id = "littlechina", name = "Little China // Public Garage", bucket = 0,
            position = { x = -1443.545, y = 1271.485, z = 23.061 },
            parking = { { position = { x = -1446.154419, y = 1268.453247, z = 22.861061 }, heading = 139.281281 } },
        },
        {
            id = "watson_north", name = "Watson North // Public Garage", bucket = 0,
            position = { x = -1313.703, y = 1641.067, z = 18.387 },
            parking = { { position = { x = -1309.970093, y = 1639.630859, z = 18.186890 }, heading = -111.040146 } },
        },
        {
            id = "northside", name = "Northside // Public Garage", bucket = 0,
            position = { x = -927.810, y = 2691.869, z = 38.772 },
            parking = { { position = { x = -924.545044, y = 2694.179688, z = 38.572350 }, heading = -54.706291 } },
        },
        {
            id = "northoak", name = "North Oak // Public Garage", bucket = 0,
            position = { x = -17.460, y = 1653.134, z = 122.109 },
            parking = { { position = { x = -21.459885, y = 1653.193848, z = 121.908722 }, heading = 89.143707 } },
        },
        {
            id = "rancho_coronado", name = "Rancho Coronado // Public Garage", bucket = 0,
            position = { x = 721.976, y = -1021.618, z = 28.156 },
            parking = { { position = { x = 725.900696, y = -1022.388428, z = 27.955727 }, heading = -101.103615 } },
        },
        {
            id = "santo_domingo_hills", name = "Santo Domingo Hills // Public Garage", bucket = 0,
            position = { x = 372.348, y = -2393.119, z = 182.074 },
            parking = { { position = { x = 369.957062, y = -2396.325928, z = 181.873505 }, heading = 143.300446 } },
        },
        {
            id = "badlands_west", name = "Badlands West // Public Garage", bucket = 0,
            position = { x = -1797.603, y = -4238.697, z = 74.320 },
            parking = { { position = { x = -1799.820801, y = -4242.025879, z = 74.119659 }, heading = 146.327393 } },
        },
        {
            id = "badlands_east", name = "Badlands East // Public Garage", bucket = 0,
            position = { x = 1628.717, y = -698.045, z = 50.473 },
            parking = { { position = { x = 1628.324829, y = -694.064392, z = 50.272659 }, heading = 5.629462 } },
        },
        {
            id = "arroyo", name = "Arroyo // Public Garage", bucket = 0,
            position = { x = 219.889, y = -1123.356, z = 21.513 },
            parking = { { position = { x = 216.249878, y = -1121.694946, z = 21.313400 }, heading = 65.466438 } },
        },
        {
            id = "vista_del_rey", name = "Vista del Rey // Public Garage", bucket = 0,
            position = { x = -880.680, y = -1753.642, z = 9.752 },
            parking = { { position = { x = -876.752441, y = -1752.882324, z = 9.552200 }, heading = -79.048141 } },
        },
        {
            id = "coastview", name = "Coastview // Public Garage", bucket = 0,
            position = { x = -1999.895, y = -2051.531, z = 23.645 },
            parking = { { position = { x = -1998.426758, y = -2055.251465, z = 23.444946 }, heading = -158.459686 } },
        },
        {
            id = "westcoast", name = "West Coast // Public Garage", bucket = 0,
            position = { x = -2225.065, y = -1187.291, z = 12.897 },
            parking = { { position = { x = -2228.479980, y = -1185.208252, z = 12.696556 }, heading = 58.616627 } },
        },
    },
}
