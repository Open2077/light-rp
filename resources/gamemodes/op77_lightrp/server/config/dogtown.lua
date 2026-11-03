-- Dogtown, the open PvP danger zone (server/modules/dogtown.lua). Server only:
-- nothing here is downloaded.
--
-- Inside Dogtown, in the shared city (routing bucket 0), anyone can kill anyone.
-- Outside, nothing changes: Light RP's global PvP stays off (the platform default),
-- safe zones stay safe, activities and missions keep their own buckets and rules.
-- A player who deals or takes PvP damage here is combat-tagged: stepping out does
-- not end the fight until the tag runs out. A kill drops part of the victim's cash
-- (never the bank) as a bag anyone can pick up. PvP gives stats only: no reputation.
LightRpDogtown = {
    -- The zone's switch at start. Staff toggle it with /lightrp.dogtown on|off (not
    -- persisted: a restart comes back to this value).
    enabled = true,
    label = "Dogtown",
    -- The shared city. Activities, missions (the Chimera raid included, though it runs in
    -- the Dogtown arena), dwellings and the arrival hall all have their own buckets.
    bucket = 0,

    -- Dogtown inside its walls, as a planar polygon (x, y in game metres; full height:
    -- rooftops and the stadium bowl count). Concave is fine, up to 512 vertices.
    --
    -- Derived on 2026-11-03 from the outline of the 21,882 building volumes of the
    -- `ep1_dogtown` district in the 3D map data (resources/standalone/op77_map3d/web/data:
    -- 20 m cells, closed, holes filled, simplified to 30 vertices at 30 m), cross-checked
    -- with Cordon's district reports (the old `pacifica` grid, -2050..-1150 x
    -- -2450..-1950, is in Dogtown) and the Chimera arena (-2044, -2406). It hugs the
    -- outside of the walls and buildings, so it is a little generous: walk the walls with
    -- /lightrp.dogtown survey and replace it. Every point below is UNSURVEYED.
    polygon = {
        { x = -2550.0, y = -2726.6 }, -- survey in game
        { x = -2410.0, y = -2846.6 }, -- survey in game
        { x = -2450.0, y = -3006.6 }, -- survey in game
        { x = -2410.0, y = -3146.6 }, -- survey in game
        { x = -1930.0, y = -3066.6 }, -- survey in game
        { x = -1910.0, y = -3006.6 }, -- survey in game
        { x = -1690.0, y = -2946.6 }, -- survey in game
        { x = -1510.0, y = -2866.6 }, -- survey in game
        { x = -1510.0, y = -2806.6 }, -- survey in game
        { x = -1370.0, y = -2766.6 }, -- survey in game
        { x = -1250.0, y = -2586.6 }, -- survey in game
        { x = -1290.0, y = -2366.6 }, -- survey in game
        { x = -1050.0, y = -2246.6 }, -- survey in game (stadium, south-east)
        { x = -1010.0, y = -2146.6 }, -- survey in game (stadium, east)
        { x = -1050.0, y = -1886.6 }, -- survey in game (stadium, north-east)
        { x = -1150.0, y = -1806.6 }, -- survey in game (stadium, north)
        { x = -1390.0, y = -1786.6 }, -- survey in game (stadium, north-west)
        { x = -1550.0, y = -1906.6 }, -- survey in game
        { x = -1570.0, y = -2026.6 }, -- survey in game
        { x = -1830.0, y = -2086.6 }, -- survey in game
        { x = -1930.0, y = -2206.6 }, -- survey in game
        { x = -2030.0, y = -2206.6 }, -- survey in game
        { x = -2070.0, y = -2286.6 }, -- survey in game
        { x = -2150.0, y = -2286.6 }, -- survey in game
        { x = -2230.0, y = -2426.6 }, -- survey in game
        { x = -2350.0, y = -2466.6 }, -- survey in game
        { x = -2350.0, y = -2546.6 }, -- survey in game
        { x = -2430.0, y = -2566.6 }, -- survey in game
        { x = -2430.0, y = -2626.6 }, -- survey in game
        { x = -2530.0, y = -2666.6 }, -- survey in game
    },
    -- Where the map pins go (game map and op77_map3d): the polygon's centroid.
    blip = {
        position = { x = -1754.6, y = -2490.6, z = 40.0 }, -- survey in game
        title = "Dogtown · PvP zone",
        description = "No law past the walls: anyone can kill you there, and take part of the cash you carry. Your bank is safe.",
        sprite = "Zzz13_DogtownGateVariant", fallbackSprite = "HazardWarningVariant",
        color = "#FF2E3C",
    },
    -- The zone itself on op77_map3d's city map (M) and minimap: the polygon above as a
    -- translucent red area with diagonal danger hatching, a border and a label (follows
    -- /lightrp.dogtown survey apply|reset and on|off). The game's own map only gets the
    -- gate sprite of `blip`: the platform draws no polygon there. false = no area.
    area = {
        label = "DOGTOWN · DANGER ZONE",
        -- Clear of the map's DOGTOWN and PACIFICA names; ignored when it falls outside the
        -- polygon (a surveyed one): the label then goes near the middle of the zone.
        labelPosition = { x = -1420.0, y = -2560.0 },
        fill = "#FF2E3C", fillOpacity = 0.22,
        stroke = "#FF2E3C", strokeWidth = 2.5, -- pixels
        pattern = "hatch",                     -- "hatch" or "solid"
        minimap = true,
        pulse = false,
    },

    -- Presence: how often everyone is placed in or out (ms), and how old a position may
    -- be before it stops counting (an unknown position keeps the last answer).
    sweepMs = 500,
    positionMaxAgeMs = 2500,

    -- Dealing or taking PvP damage tags both players for this long; a tagged player
    -- stays attackable outside the walls until it runs out (each hit renews it).
    combatTagMs = 20000,

    -- Cash taken on a kill: `share` of the victim's pocket cash, at most `max`; nothing
    -- when the victim carries less than `minCash`. The bank is never touched.
    --   mode "bag":      the cash drops in a bag where the victim fell, anyone picks it
    --                    up (the inventory's ground pile: session-only, gone after the
    --                    drop TTL, LightRpConfig.inventory.drop.ttlMinutes).
    --   mode "transfer": straight into the killer's pocket.
    -- A bag that cannot be made falls back to the transfer.
    loot = {
        mode = "bag",
        share = 0.10,
        max = 500,
        minCash = 100,
        -- Anti-farm. The same killer on the same victim (characters, in that direction)
        -- within this long takes nothing and scores no kill; the victim's death counts.
        pairCooldownMs = 10 * 60000,
        -- Two characters of one account, or two members of one crew (LightRP.parties):
        -- false = no cash and no kill credit between them.
        lootSameAccount = false,
        lootCrewmates = false,
        bagLabel = "Cash bag",
        bagMarker = { shape = "cylinder", radius = 0.5, height = 0.3, color = { r = 255, g = 46, b = 60, a = 150 }, maxDistance = 25.0, groundOffset = 0.03 },
        -- A busy inventory (another transaction in flight) is retried this many times.
        retries = 10, retryMs = 300,
    },

    -- PvP stats (kills, deaths, eddies picked up from Dogtown cash bags or transfers):
    -- per character, lifetime and per week (UTC, Monday 00:00). The leaderboard is
    -- this week's top killers.
    stats = { leaderboardSize = 5, refreshMs = 60000 },

    -- PvP grants: Light RP keeps global friendly fire off and gives the players who
    -- qualify a combat scope (Open77.combat.createScope) in the city bucket. A scope
    -- holds at most 32 players and a resource at most 8 scopes: past 32 players the
    -- roster is split by position (west to east), and two players of different
    -- groups cannot hurt each other. `maxScopes` caps how many this module uses.
    maxScopes = 8,
    -- Every grant is rebuilt at least this often (a respawn can silently drop a
    -- player from a scope on the host side).
    refreshScopesMs = 10000,
    -- Chat line on entering, at most once per player in this window (the page shows
    -- the banner every time).
    entryChatMs = 120000,

    -- Passages: an "E" point outside a gate that brings you inside, and its twin inside
    -- that takes you out. Light RP needs them when the gates stay shut (a client save on
    -- which Phantom Liberty never started keeps Dogtown sealed: see the README). Leaving
    -- through a passage is refused while combat-tagged. Empty until surveyed in game:
    --   /lightrp.dogtown survey passage   (stand at each end, it prints the line)
    -- { id = "north_gate", label = "Dogtown checkpoint",
    --   outside = { x = 0, y = 0, z = 0, heading = 0 }, inside = { x = 0, y = 0, z = 0, heading = 0 } },
    passages = {},
    passageRadius = 2.0,
    passageMarker = { shape = "cylinder", radius = 0.9, height = 0.6, color = { r = 255, g = 46, b = 60, a = 140 }, maxDistance = 30, groundOffset = 0.05 },

    -- Staff survey: the engine district each client reports when it crosses a border is
    -- compared with the polygon and every disagreement is logged (never granted from).
    logDistrictMismatch = true,
}
