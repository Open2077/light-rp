-- The Hall of Fame (server/modules/halloffame.lua): a board at The Crossing, the
-- arrival hub (server/config/activities.lua), that opens the best players of the
-- city in the Light RP page. Server only: nothing here is downloaded.
LightRpHallOfFame = {
    enabled = true,
    title = "Hall of Fame",

    -- The board: a real prop (server side, everyone sees the same one) plus an E
    -- point in front of it. ALT + click on the prop and E both open the panel; the E
    -- point works even if the prop asset turns out wrong in game.
    board = {
        -- Metres from the hub's center along its heading (forward) and to its right,
        -- as the hub's terminals (activities.lua `hub.terminals`): about 4 m to the
        -- left of the activities terminal (forward 5.0, right 0.0).
        offset = { forward = 6.0, right = -4.0, up = 0.0 }, -- survey in game
        -- `/lightrp.halloffame place` prints these two once surveyed; they replace
        -- the offset. Without a heading the screen faces the arrival point.
        -- position = { x = -763.777, y = 777.723, z = 22.454 }, -- survey in game
        -- heading = 266.3, -- survey in game
        bucket = 0,
        -- A prop alias of the props catalogue (base client/src/api/Props.cpp
        -- kModelAliases). `electronics.tv.screen.16x9` is the game's bare 16:9 TV
        -- panel (1.16 x 0.66 m at scale 1, its picture faces the prop's +Y, a static
        -- collider in its host): open77_media spawns it server side, up to 39x, as its
        -- cinema screens. Not validated at this size and place: survey in game, and
        -- swap for `electronics.tv.large` (a 1.92 x 1.01 m wall display, no collider:
        -- ALT + click needs a collider to hit) if it reads wrong.
        model = "electronics.tv.screen.16x9", -- survey in game
        scale = 2.5,          -- about 2.9 x 1.65 m, its lower edge ~0.2 m above the ground
        collision = true,     -- ALT + click picks physical hits only
        streamingRadius = 150,
        -- The E point: this far in front of the screen, toward the people looking at it.
        interact = { distance = 1.8, radius = 1.6, label = "Hall of Fame", prompt = "Open the Hall of Fame",
            marker = { shape = "cylinder", radius = 0.7, height = 0.5,
                color = { r = 255, g = 204, b = 0, a = 140 }, maxDistance = 30, groundOffset = 0.05 } },
        -- An ALT + click opens the panel up to this far from the board (the client's
        -- context menu reaches 8 m), plus a little slack for the server's position feed.
        clickRange = 10.0,
        -- `/lightrp.halloffame place`: the board goes this far behind the staff, who
        -- stands in front of its screen, facing where the screen should face.
        staffSetback = 0.8,
        -- Retries while the world is not ready at start.
        spawnRetryMs = 10000, spawnRetries = 30,
    },

    -- The boards are computed on the server and cached: every refreshMs, and on a
    -- player's REFRESH at most once per playerRefreshMs (never faster than floorMs for
    -- the whole server). Opening the panel never queries the database, unless the
    -- boards are older than refreshMs. A table that did not answer (not created yet
    -- at start) is read again after retryMs.
    cache = { refreshMs = 5 * 60000, playerRefreshMs = 30000, floorMs = 10000, firstRefreshMs = 15000,
        retryMs = 30000, databaseDelayMs = 5000 },
    size = 10,          -- rows per board
    overviewSize = 3,   -- rows per board on the OVERVIEW tab (the podiums)
    overviewMax = 12,   -- boards on the OVERVIEW tab

    -- The richest characters (cash + bank). The owner wants it on.
    showWealth = true,
    -- Show the bank / cash split under each fortune (off: the total only).
    showWealthSplit = false,
    -- Characters scanned for the wealth board, richest bank first.
    wealthScanLimit = 2000,
    -- Street-cred tier beside the reputation (from the missions' tiers).
    showTier = true,

    -- Which activity results count where (server/modules/activities.lua stats).
    -- An activity missing from every list counts as PvP, or PvE when its id ends in
    -- ".pve"; races rank by best time on their current course.
    activities = {
        pvp = { "arena.ffa", "arena.blade", "arena.duel", "arena.teams", "chase.1v1", "chase.wanted", "turf.war",
            "race.trial", "race.grid", "race.foot" },
        races = { "race.trial", "race.grid", "race.foot" },
        pve = { "arena.pve", "race.pve", "chase.pve", "turf.pve" },
        -- Used when the provider is not running (its own label otherwise).
        labels = { ["race.trial"] = "Time Trial", ["race.grid"] = "Street Race", ["race.foot"] = "Rooftop Race" },
    },

    -- Mission clears (server/modules/missions.lua): by the point's type, and the
    -- difficulties from the hardest. Points no longer in the city keep their type here.
    missions = {
        heistTypes = { HEIST = true },
        raidTypes = { RAID = true },
        knownTypes = { chimera_raid = "RAID", sector04_blackout = "HEIST" },
        difficulties = { { id = "critical", short = "CRIT" }, { id = "hard", short = "HARD" }, { id = "standard", short = "STD" } },
    },
}
