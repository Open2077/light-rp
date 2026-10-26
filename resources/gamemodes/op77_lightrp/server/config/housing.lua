-- Server-owned policy. Prices/points are authored in /housingadmin and stored in
-- MySQL; no restart or Lua editing is needed to create a template or a dwelling.
LightRpHousing = {
    enabled = true,
    permission = "command.lightrp.housing",
    bucketBase = 1000000, -- one stable bucket per dwelling; never a player's ID
    maxProperties = 1000,
    maxOwned = 5,
    maxGuests = 16,
    maxKeys = 12,
    pageSize = 10, -- bounded replies under the platform's 48 KiB event limit
    visibleEntrances = 32, -- closest building entrances on the map
    entranceRefreshDistance = 100,
    interactRadius = 2.5,
    stashRadius = 3.0,
    maxInteriorRadius = 200,
    defaultSlots = 40,
    defaultWeight = 150,
    resaleFraction = 0.5,
    rentDays = 7,
    maxRentAheadDays = 365,
    transitionTimeoutMs = 30000, -- native streaming settle budget (1000–30000)
    -- Logged out at home: the resident wakes up inside on the next join.
    wakeUpAtHome = true,

    -- The studio every newcomer receives at the end of the first day guide
    -- (server/modules/housing_starter.lua). One unit per character, all behind
    -- the same street door, each in its own bucket. The interior is the map
    -- resource `kabuki_appart1`, which the server must load. The template is
    -- written once from here; afterwards /housingadmin edits win (capture the
    -- storage and wardrobe again there to move them).
    starter = {
        enabled = true,
        templateId = "lightrp-starter-kabuki-studio",
        label = "Kabuki Studio",       -- the template; units are "Kabuki Studio 0001"…
        building = "Kabuki Studios",    -- the street door's label
        entrance = { x = -717.848206, y = 886.100220, z = 32.667023, heading = 0 },
        points = {
            spawn = { x = -747.960205, y = 914.351318, z = -11.999992, heading = 0 },
            exit = { x = -747.960205, y = 914.351318, z = -11.999992, heading = 0 },
            stash = { x = -744.8, y = 919.1, z = -11.99, heading = 0 },     -- living room
            wardrobe = { x = -751.3, y = 919.1, z = -11.99, heading = 0 },  -- bedroom
        },
        slots = 30, weight = 100,
        maxUnits = 4000, -- not counted in maxProperties
    },
}
