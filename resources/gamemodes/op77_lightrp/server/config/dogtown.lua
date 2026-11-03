-- Dogtown, the open PvP danger zone (server/modules/dogtown.lua). Server only:
-- nothing here is downloaded. The rules below are the owner's (2026-11-03); the
-- guide NPC quotes them from this file (server/config/guide.lua, Dogtown topic).
--
-- Inside Dogtown, in the shared city (routing bucket 0), anyone carrying the stake
-- (`stake.minCash` in pocket cash) can kill anyone else carrying it; crewmates never
-- hurt each other. Outside, nothing changes: Light RP's global PvP stays off (the
-- platform default), safe zones stay safe, activities and missions keep their own
-- buckets and rules. A player who deals or takes PvP damage here is combat-tagged:
-- stepping out does not end the fight until the tag runs out. A kill drops part of
-- the victim's cash (never the bank) plus a server bonus as a bag, reserved to the
-- killer's crew for a few seconds. PvP gives stats only: no reputation.
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

    -- The stake: a player must carry at least `minCash` in POCKET cash (the bank never
    -- counts) to fight here. Below it they are left out of the PvP grant (they can
    -- neither deal nor take PvP damage in the zone), warned with the amount missing,
    -- and after `graceMs` still inside and still short, sent to the nearest exit below.
    -- A player who drops under it by dying is handled the same way once revived.
    stake = {
        minCash = 1000,
        graceMs = 10000,
    },
    -- Where a player under the stake is sent: the nearest of these (planar distance),
    -- each OUTSIDE the polygon (a point inside is ignored and logged at start). A
    -- driver alone in a car is moved with the car; anyone else leaves the vehicle
    -- behind (the platform refuses to teleport a seated player otherwise). Without a
    -- usable exit the hospital (LightRpConfig.spawn.hospital) is the fallback.
    -- Survey with /lightrp.dogtown survey exit (stand on the road, facing away from
    -- Dogtown): the z values below are guesses.
    exits = {
        { id = "pacifica_west",  label = "Pacifica, west of the market", x = -1980.0, y = -2150.0, z = 40.0, heading = 0.0 },   -- survey in game
        { id = "pacifica_north", label = "Pacifica, north gate",         x = -1650.0, y = -1980.0, z = 30.0, heading = 0.0 },   -- survey in game
        { id = "stadium_north",  label = "North of the stadium",         x = -1250.0, y = -1740.0, z = 30.0, heading = 0.0 },   -- survey in game
        { id = "stadium_east",   label = "East of the stadium",          x = -960.0,  y = -2150.0, z = 30.0, heading = 270.0 }, -- survey in game
    },

    -- Cash lost on a death: `share` of the victim's pocket cash, at least `min`, at
    -- most `max`, never more than they carry. The bank is never touched.
    --   mode "bag":      the cash drops in a sealed bag where the victim fell (the
    --                    inventory's ground pile: session-only, gone after the drop
    --                    TTL, LightRpConfig.inventory.drop.ttlMinutes).
    --   mode "transfer": straight into the killer's pocket, the bonus paid beside it
    --                    (ledger kind dogtown_bonus); no reserve.
    -- A bag that cannot be made falls back to the transfer.
    loot = {
        mode = "bag",
        share = 0.10,
        min = 100,
        max = 750,
        -- The killer's bonus: new money the server adds to the bag on top of the
        -- victim's loss (never taken from anyone), `bonus` of the loss. Every bonus a
        -- killer's ACCOUNT earns (all its characters, kill bonus and bounties) is
        -- capped at `bonusDailyCap` per UTC day; nothing on a blocked pair.
        bonus = 0.25,
        bonusDailyCap = 3000,
        -- The bag is reserved to the killer and the killer's crew (crew at pickup
        -- time) for this long, then anyone can take it, the victim included. The bonus
        -- counts in the killer's cap when the bag is made, whoever ends up with it:
        -- the reserve gives the killer the first claim, after that it is Dogtown.
        reserveMs = 15000,
        -- Anti-farm. The same killer on the same victim (characters, in that direction)
        -- within this long scores NOTHING: no kill, no death, no loss, no bag, no bonus.
        pairCooldownMs = 10 * 60000,
        -- Two characters of one account, or two members of one crew (LightRP.parties):
        -- false = nothing at all between them (as the pair cooldown).
        lootSameAccount = false,
        lootCrewmates = false,
        bagLabel = "Cash bag",
        bagMarker = { shape = "cylinder", radius = 0.5, height = 0.3, color = { r = 255, g = 46, b = 60, a = 150 }, maxDistance = 25.0, groundOffset = 0.03 },
        -- A busy inventory (another transaction in flight) is retried this many times.
        retries = 10, retryMs = 300,
    },

    -- Anti-gank. A killer whose crew has `crewSize` or more members in the zone
    -- (inside, or tagged outside) costs the victim `lossFactor` of the normal loss
    -- (the bag and its bonus shrink with it). Killing a member of a bigger crew (the
    -- victim's crew in the zone outnumbers the killer's) adds `underdogBonus` to the
    -- server bonus (0.5: the bonus x 1.5), still inside the daily cap.
    antiGank = {
        crewSize = 4,
        lossFactor = 0.5,
        underdogBonus = 0.5,
    },

    -- Bounty: `streak` credited kills in the zone without dying puts the killer on
    -- everyone's 3D map (op77_map3d, a pin following them, moved every `refreshMs`)
    -- until they die, leave the zone (outside and no longer tagged) or disconnect.
    -- Whoever kills them (a credited kill) gets `perKill` x their streak in pocket
    -- cash, at most `max`, counted in the daily bonus cap.
    bounty = {
        streak = 5,
        perKill = 250,
        max = 1500,
        refreshMs = 3000,
        blip = { icon = "crosshair", color = "#FF2E3C", scale = 1.3, pulse = true, edge = true },
    },

    -- Combat log: a combat-tagged player who disconnects in the zone drops the bag of
    -- a death (same loss, no bonus for anyone) where they were last seen, reserved to
    -- their last attacker's crew. Logged.
    combatLog = true,

    -- The hospital bill (LightRpEconomy.hospital, economy_sinks.lua) is waived after a
    -- death in a Dogtown fight: the zone already took its cut in cash, and the bank
    -- stays out of Dogtown. false = the bill applies as after any death.
    waiveHospitalBill = true,

    -- PvP stats (credited kills and deaths, best streak, eddies picked up from Dogtown
    -- cash bags or transfers): per character, lifetime and per week (UTC, Monday
    -- 00:00). The F1 leaderboard is this week's top killers; the Hall of Fame at The
    -- Crossing gets two lifetime boards in its PvP tab (kills with K/D and best streak,
    -- and the best streaks). hallOfFame = false keeps Dogtown off the Hall of Fame.
    stats = { leaderboardSize = 5, refreshMs = 60000 },
    hallOfFame = true,

    -- PvP grants: Light RP keeps global friendly fire off and gives the players who
    -- qualify a combat scope (Open77.combat.createScope) in the city bucket; members of
    -- one crew share a combat team (Open77.combat.setTeam: they never hurt each other),
    -- updated when crews change; team ids are `teamBase` + the crew's number. A scope
    -- holds at most 32 players and a resource at most 8 scopes: past 32 players the
    -- roster is split by position (west to east), and two players of different
    -- groups cannot hurt each other. `maxScopes` caps how many this module uses.
    maxScopes = 8,
    teamBase = 7700000,
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
