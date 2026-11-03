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
        -- Surveyed by the owner in game, 2026-11-03. Heading 232.6 = The Crossing's axis
        -- (the arrival heading 52.6, + 180 to face the plaza): the sculpture's square plinth
        -- sits parallel to the parking (owner: "il est pas droit"). Fine-tune live with
        -- `/lightrp.halloffame model 7 4.5 <degrees>`.
        position = { x = -774.802, y = 784.568, z = 22.297 },
        heading = 232.6,
        bucket = 0,
        -- The prop: an alias of the props catalogue (base client/src/api/Props.cpp
        -- kModelAliases; an alias gets an Open77 mesh host, a raw depot path gets none).
        -- `model` is the default; its scale and yaw come from its row of `models` below
        -- unless `scale` / `yaw` are set here. The staff try the rows live in game:
        --   /lightrp.halloffame model                        the numbered list (* = in use)
        --   /lightrp.halloffame model <n|alias> [scale|-] [rotate]   swap now ("-": the row's scale)
        --   /lightrp.halloffame model reset                  back to this default
        -- A swap is saved in the resource's kvp store (data/, kept over restarts) and wins
        -- over `model` at start until `model reset`. `where` prints the line to paste here.
        -- The owner's pick, 2026-11-03: model 7 of the list below at scale 4.5 (6.9 m tall,
        -- plinth 2.6 m square). Its collider stays at scale 1 until the client scales prop
        -- colliders (base branch fix/prop-collision-scale).
        model = "decor.sculpture.arasaka",
        scale = 4.5,                  -- optional (with `yaw`): override the row of `model`
        collision = true,     -- ALT + click picks physical hits only (a row may say otherwise)
        -- The candidates, best guess first. `yaw` turns the mesh so its front looks where
        -- the board faces (degrees, counter-clockwise from above): 0 for a mesh whose
        -- front is its +Y, -90 for -X, 90 for +X, 180 for -Y; `rotate` in the command
        -- adds to it. Sizes and fronts are measured from the 2.31 meshes (WolvenKit
        -- serialize, per-submesh vertex bounds, 2026-11-03); none is validated in game.
        -- `collision = false`: the mesh host has no collider (prop-hosts.json), so ALT +
        -- click cannot hit it; E still opens the panel. `height`: the mesh's height in
        -- metres at scale 1 (the trophy icon floats just above it); `width` x `depth`: its
        -- footprint at scale 1 (the E prompt reaches all around it).
        models = {
            -- The game's arcade cabinet (its screen sets are Roach Race, Quadra, Panzer):
            -- a "high scores" machine. 0.65 x 0.82 x 1.87 m; front +Y (control panel and
            -- glass on the +Y side); collider.
            { model = "electronics.arcade", scale = 1.0, yaw = 0, height = 1.87, width = 0.65, depth = 0.82, label = "Arcade cabinet" },
            -- Kitsch jukebox, lit: 1.67 x 1.12 x 2.53 m; front +Y (glass and lights); collider.
            { model = "electronics.jukebox", scale = 1.0, yaw = 0, height = 2.53, width = 1.67, depth = 1.12, label = "Jukebox" },
            -- A flat screen in a heavy frame: 1.38 x 0.97 m at scale 1 (2.76 x 1.95 m here),
            -- 3 cm thick and symmetric, so the picture side is NOT measured (rotate 180 if
            -- it shows its back); collider.
            { model = "electronics.tv.neokitsch.16x9", scale = 2.0, yaw = 0, height = 0.97, label = "Framed screen" },
            -- The stand-up television with its housing (today's picture with a body and a
            -- back): 1.26 x 0.85 m at scale 1 (3.2 x 2.1 m here); front +Y; collider.
            { model = "electronics.tv.16x9", scale = 2.5, yaw = 0, height = 0.85, label = "TV with housing" },
            -- The big wall display: 1.92 x 1.01 m face at scale 1 (2.9 x 1.5 m here);
            -- front +Y; NO collider.
            { model = "electronics.tv.large", scale = 1.5, yaw = 0, height = 1.01, collision = false, label = "Big wall display" },
            -- A big lit vending machine with a screen: 1.79 x 1.16 x 2.32 m; front +Y; collider.
            { model = "electronics.vending_machine", scale = 1.0, yaw = 0, height = 2.32, width = 1.79, depth = 1.16, label = "Vending machine" },
            -- A monument rather than a board: Arasaka's lobby sculpture, lit base,
            -- 0.57 x 0.57 x 1.54 m at scale 1 (2.3 m tall here); round; collider.
            { model = "decor.sculpture.arasaka", scale = 1.5, yaw = 0, height = 1.54, width = 0.57, depth = 0.57, label = "Sculpture" },
            -- A framed painting standing on the ground: 1.2 x 1.67 m, 5 cm thick (1.6 x
            -- 2.2 m here); its back is flat at X 0, so the picture faces -X; NO collider.
            { model = "decor.painting", scale = 1.3, yaw = -90, height = 1.67, collision = false, label = "Painting" },
            -- Until 2026-11-03: the bare 16:9 TV panel, a black slab (nothing plays on it).
            { model = "electronics.tv.screen.16x9", scale = 2.5, yaw = 0, label = "Bare screen (before)" },
        },
        streamingRadius = 150,
        -- The E point: `distance` metres in front of the board (0: its centre, the owner's
        -- call 2026-11-03, so the E prompt sits on the object). The prompt shows within the
        -- larger of `radius` and the footprint's half diagonal x scale + `reach`, so E works
        -- from every side of a big prop (sculpture at 4.5: 1.81 + 1.4 = 3.2 m). No floor
        -- marker; a `marker = { shape = "cylinder", ... }` here would draw one again.
        interact = { distance = 0, radius = 2.6, reach = 1.4, label = "Hall of Fame", prompt = "Open the Hall of Fame" },
        -- Its icon: floating `lift` metres above the prop (its row's `height` x scale, or
        -- `height` here for a model without one, never above `maxHeight` so it stays in view
        -- up close), with the distance (open77_icons), and a pin on the map. `blip = false`: none.
        blip = { icon = "trophy", title = "Hall of Fame", description = "The best players of the city. Walk up and press E.",
            mapCategory = "service", mapColor = "#FFCC00", height = 2.0, lift = 0.4, maxHeight = 4.0 },
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

    -- Who is on no board at all: the built-in ones and every board another module
    -- registers (registerBoard), filtered once after the providers, before the
    -- ranking (the others close ranks). An excluded viewer gets no "YOU #N" either.
    -- Ids are the ones the boards' rows carry: the account is the player's Open77
    -- account id (GetPlayerIdentifier, the `userId` of an acl.jsonc principal), a
    -- character is "<account>#<characterKey>" (characterKey "default" for the first).
    -- Every change shows at the next rebuild (the command triggers one).
    exclude = {
        -- Staff accounts (Light RP's staff test: LightRpConfig.staffPermissions in the
        -- ACL, server/modules/staff.lua), every character of theirs. The ACL only
        -- answers for a player online (a resource cannot read acl.jsonc), so each staff
        -- account seen online is remembered (the resource's kvp store, data/: kept over
        -- restarts) and stays off the boards offline. A remembered account seen online
        -- without the rights any more is forgotten. LIMIT: a staff never seen online
        -- since this shipped is unknown: list them in staffAccounts.
        staff = true,
        -- Staff accounts known before they are seen: their acl.jsonc `userId`.
        staffAccounts = {},
        -- Test characters / accounts. `/lightrp.halloffame exclude | include | excluded`
        -- keeps a list of its own beside these two (same kvp store).
        tests = true,
        characters = {},    -- "<account>#<characterKey>"
        accounts = {},      -- "<account>": every character of the account
    },

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
