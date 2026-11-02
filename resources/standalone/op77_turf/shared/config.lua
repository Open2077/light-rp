-- op77_turf: every tuning number of Turf War in one place. Shared: the client reads
-- the sites (zone markers, blips), the kits (labels) and the keys. Nothing secret here.
--
-- Positions are world metres (X east, Y north, Z up), headings engine yaw in degrees
-- (0 faces +Y). Every position below comes from an earlier survey (rp-scripts'
-- walked Kabuki Market points, the Deathmatch Kabuki survey, the owner's Freeroam
-- arena capture of 2026-09-21) and is marked `-- survey in game`: walk each one with
-- /turf.survey before trusting it.
TurfConfig = {
    activity = {
        id = "turf.war",
        label = "Turf War",
        kind = "pvp",
        description = "Gang war for a district: hold the capture zones, out-score the rival crew. "
            .. "Gangs fight under their colours, everyone else signs on as a mercenary. Weekly gang influence.",
        minPlayers = 6,
        maxPlayers = 24,
        -- Light RP's caps: nothing of the RP world comes in (own kits, no items, needs frozen, no cars).
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
    },
    core = "op77_lightrp",

    -- Routing buckets: one war at a time, a fresh bucket for each (4400000-4499999 is ours).
    buckets = { from = 4400000, to = 4400099 },

    -- Staff testing (/turf.testing on): a war starts with this many players and the
    -- reward thresholds drop to it. Never leave it on for the public.
    testing = { minPlayers = 2, minAccounts = 2 },

    queue = {
        -- A queued player who has not been admitted for this long leaves the queue
        -- (Light RP forgets an unanswered hub join after 15 min too).
        timeoutSeconds = 15 * 60,
        -- A queued player who cannot go (in a car, hurt...) is told at most this often,
        -- and dropped from the queue after this long.
        notReadyNoticeSeconds = 30,
        notReadyDropSeconds = 120,
    },

    lobby = {
        -- Once enough fighters are queued, the lobby counts down this long (more can join).
        seconds = 45,
        -- ... and only this long once the war is full.
        fullSeconds = 10,
        -- A staff-scheduled war opens its lobby this long at the start time.
        scheduledSeconds = 60,
        -- Announcements before a scheduled war (seconds before the start).
        announceAt = { 600, 300, 120, 60, 30 },
    },

    match = {
        placeTimeoutSeconds = 40, -- every fighter on his spawn within this, or he is sent home
        countdownSeconds = 10,    -- held on the spawn, kits handed out
        timeLimitSeconds = 660,   -- 11 minutes
        targetScore = 900,        -- first side to this wins
        scoreboardSeconds = 10,   -- the end card, then everyone goes home
        spawnLiftMetres = 0.2,    -- surveyed z values are feet reads
        -- Late joiners: the queue keeps feeding the smaller side while at least this
        -- much time is left.
        joinInProgress = true,
        joinCutoffSeconds = 180,
        -- The two sides may differ by this many fighters at most; a gang's surplus
        -- waits in the queue (it comes in as reinforcements when the balance allows).
        maxImbalance = 1,
        -- true: a gang's surplus may sign on with the other side as mercenaries.
        allowTurncoats = false,
    },

    -- Capture: standing inside a zone (radius, and within `height` metres of its z).
    capture = {
        seconds = 15,          -- one attacker takes an enemy (or neutral) zone in this long
        perExtraAttacker = 0.5, -- each extra attacker adds 50% speed...
        maxAttackers = 3,      -- ... up to three (x2)
        decayPerSecond = 0.05, -- an abandoned half-capture fades
        height = 3.5,
    },

    scoring = {
        pointsPerZonePerSecond = 1, -- per held zone
        captureBonus = 20,
        killPoints = 3,
    },

    life = {
        respawnSeconds = 6,
        respawnRetries = 5,
        protectionSeconds = 3, -- fresh spawns cannot be hurt (broken by shooting)
        -- Respawn at a zone the side holds (uncontested, no enemy capture running),
        -- nearest to where the fighter fell; else at the side's spawn.
        respawnAtZones = true,
        zoneSpawnOffset = 1.5,
        -- Outside the site's bounds for this long: back to the side's spawn.
        outOfBoundsSeconds = 8,
        -- A kit picked within this long after a spawn is swapped at once.
        kitSwapSeconds = 6,
    },

    -- Engine-native kits (the raid's proven records). Nothing of the character's own
    -- arsenal is used and nothing persists: Light RP gives the RP weapons back after.
    kits = {
        { id = "assault", label = "ASSAULT", blurb = "Ajax rifle + Lexington. Every range.",
          primary = "Items.Preset_Ajax_Default", secondary = "Items.Preset_Lexington_Default", reserve = { 300, 96 } },
        { id = "breacher", label = "BREACHER", blurb = "Carnage shotgun + Unity. Take the zone from inside.",
          primary = "Items.Preset_Carnage_Default", secondary = "Items.Preset_Unity_Default", reserve = { 80, 96 } },
        { id = "marksman", label = "MARKSMAN", blurb = "Grad precision rifle + Nue. Cover the zones from afar.",
          primary = "Items.Preset_Grad_Default", secondary = "Items.Preset_Nue_Default", reserve = { 60, 96 } },
        { id = "gunner", label = "GUNNER", blurb = "Defender LMG + Lexington. Hold a zone under fire.",
          primary = "Items.Preset_Defender_Default", secondary = "Items.Preset_Lexington_Default", reserve = { 300, 96 } },
        { id = "tech", label = "TECH", blurb = "Achilles tech rifle + Copperhead. Shots through cover.",
          primary = "Items.Preset_Achilles_Default", secondary = "Items.Preset_Copperhead_Default", reserve = { 100, 240 } },
    },
    defaultKit = "assault",

    rewards = {
        -- Proposed reputation (Light RP clamps it to 50 per result and caps it per day).
        win = 30, draw = 18, loss = 12,
        perCapture = 2, perKill = 1, bonusCap = 10,
        leaver = 0,
        -- No reputation and no influence unless the war lasted this long with fighters
        -- from at least this many distinct accounts; a late joiner needs this much play.
        minWarSeconds = 180,
        minAccounts = 4,
        minPlaySeconds = 120,
    },

    -- Weekly gang influence (op77_turf_influence): what a counted war is worth to the
    -- two gangs that fought it. Mercenaries earn no influence for anyone.
    influence = {
        win = 10, draw = 5, loss = 2,
        perCapture = 1, captureCap = 10,
        topSize = 6,
    },

    -- Light RP's gangs (op77_lightrp/shared/jobs.lua LightRpGangs), used when the
    -- character's gang view carries no label/colour. Keep in step with Light RP.
    gangs = {
        valentinos = { label = "Valentinos", color = "#D9A441" },
        tyger_claws = { label = "Tyger Claws", color = "#E23C7A" },
        maelstrom = { label = "Maelstrom", color = "#FF2E3C" },
        sixth_street = { label = "6th Street", color = "#3E8FD8" },
        animals = { label = "Animals", color = "#B86B2E" },
        voodoo_boys = { label = "Voodoo Boys", color = "#35D07F" },
    },
    -- A side without a gang (nobody of a second gang queued).
    freeSides = {
        { label = "Free Agents", color = "#C9CED6" },
        { label = "Mercenaries", color = "#8A8F9C" },
    },
    -- Combat teams (Open77.combat.setTeam) of the two sides: teammates never hurt each other.
    teamIds = { 4401, 4402 },

    -- NPC bots (server/bots.lua): staff bot mode (op77_lightrp `/lightrp.bots on`) fills the
    -- missing places of a turf war, and the Gang Sweep's NPC gang is made of them. They
    -- fight with the engine's own combat AI (aiMode native, relationship groups,
    -- per-player attitude); the server only sets their objectives (guard / move tasks),
    -- prices the hits and counts them on the zones and the scoreboard.
    bots = {
        -- Bot mode: each side is filled up to max(perSide, the larger side's humans).
        perSide = 3,
        -- The humans' side gets bot teammates too (1 human: you + 2 bots vs 3 bots).
        -- Needs Open77.npcs.setAttitude (a teammate must be told not to shoot you).
        allies = true,
        maxPerSide = 6,
        maxBots = 10,
        prefix = "[BOT] ",
        names = { "Rook", "Vex", "Static", "Hex", "Grit", "Nova", "Razor", "Echo", "Brick", "Jinx", "Sable", "Dagger" },
        -- A side without a gang is given the first of these its rival does not hold.
        gangOrder = { "maelstrom", "tyger_claws", "valentinos", "sixth_street", "animals", "voodoo_boys" },
        -- Gang records, tried in order, then `fallback` (proven template aliases). A record
        -- the headless server cannot check fails on the clients only: a body no client has
        -- simulated for `authorityTimeoutMs` is rebuilt with the next record.
        records = {
            maelstrom = { "Character.cpz_maelstrom_grunt1_ranged1_lexington_wa", "Character.maelstrom_grunt2_ranged2_ajax_ma" },
            valentinos = { "Character.dtn_valentinos_grunt1_ranged1_nova_ma", "Character.valentinos_grunt2_ranged2_ajax_wa" },
            tyger_claws = { "Character.dtn_tyger_claws_gangster1_ranged1_copperhead_ma", "Character.tyger_claws_biker1_ranged1_nue_wa" },
            sixth_street = { "Character.rcr_sixth_street_grunt_short_range_w_medium", "Character.sixthstreet_hooligan_ranged1_nova_ma" }, -- unproven
            animals = { "Character.animals_grunt1_ranged1_nova_mb", "Character.animals_grunt2_ranged2_pulsar_mb" },                       -- unproven
            voodoo_boys = { "Character.voodooboys_grunt1_ranged2_saratoga_ma", "Character.voodooboys_grunt1_ranged2_saratoga_wa" },
        },
        fallback = { "hostile_female_ranged_lab", "gang_valentinos_ranged_01", "gang_tygerclaws_ranged_01" },
        health = 100,
        streamingRadius = 260,
        streamingHysteresis = 40,
        spawnLiftMetres = 0.35,
        spawnRing = 2.5,           -- bodies spread on a ring around a spawn point
        spawnSpacingMs = 400,      -- one body created at a time, this far apart
        spawnSettleMs = 5000,      -- no body in the first seconds after this VM started
        corpseLingerMs = 1200,     -- a dead body stays this long (death animation), then goes
        authorityTimeoutMs = 30000,
        -- Objectives (movement channel only; the engine fights on its own).
        tasks = {
            retaskMs = 6000,        -- at most one new destination per bot this often
            combatQuietMs = 5000,   -- ... and only once no hit has named it for this long
            guardRadius = 3.0,      -- leash around a zone: its radius plus this
            arriveMetres = 8.0,     -- farther than this from its zone: moveTo first, then guard
            moveTimeoutMs = 30000,
            speed = "run",
            pushShare = 0.5,        -- share of a side's bots that push to the enemy's zones
        },
        -- Hit pricing (client reports, clamped, rate-bounded per victim and per pair).
        damage = { maxPerHit = 34, fallback = 18, perSecond = 90, pairIntervalMs = 90, maxDistance = 150 },
        creditWindowMs = 10000,    -- a death within this of a bot's hit is that bot's kill
        outOfBoundsSeconds = 8,    -- out of the site: walked back to its spawn ...
        rebuildAfterSeconds = 16,  -- ... still out after this long: rebuilt there
    },

    -- Gang Sweep (turf.pve): the public PvE variant, no staff switch. Solo or with your
    -- crew, take a district's zones from the NPC gang holding it. Results are recorded by
    -- Light RP (unless staff bot mode is on), with lower reputation than the war and no
    -- weekly influence.
    pve = {
        enabled = true,
        activity = {
            id = "turf.pve",
            label = "Gang Sweep",
            kind = "event",
            description = "Take a district from the NPC gang holding it. Solo or with your crew: "
                .. "the more you are, the more of them. Engine combat AI, reputation, no influence.",
            minPlayers = 1,
            maxPlayers = 8,            -- a full Light RP squad (party.maxSize 8)
            caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
        },
        maxSweeps = 2,             -- sweeps at once (NPC budget); more crews wait their turn
        gatherSeconds = 8,         -- a crew's members join within this, then the sweep starts
        soloGatherSeconds = 1,
        baseBots = 3,              -- 1 human: 3 gangers; +2 per extra human
        botsPerHuman = 2,
        maxBots = 10,
        pushShare = 0.34,          -- the holders mostly guard their zones
        timeLimitSeconds = 480,
        targetScore = 600,
        -- The holders start with every zone: their zone points run at this rate (3 zones
        -- held untouched reach the target in ~400 s, inside the time limit).
        holderZoneRate = 0.5,
        joinCutoffSeconds = 120,   -- a crew member may still join this long before the end
        -- Who holds each site (a crew of that gang meets the first other of bots.gangOrder).
        holders = { kabuki = "tyger_claws", badlands = "animals", afterlife = "valentinos" },
        -- Reputation: the war's amounts x this, and nothing unless the sweep lasted
        -- minWarSeconds, the fighter played minPlaySeconds and captured or eliminated someone.
        reputationScale = 0.6,
        rewards = { minWarSeconds = 240, minPlaySeconds = 180, needsAction = true },
    },

    -- The sites: a district each, 3 capture zones, two side spawns, round bounds.
    -- `spawnable = false` keeps a zone out of the respawn choice (tight interiors).
    -- `enabled = false`: staff only (/turf.schedule <id> / /turf.start <id>), never voted.
    sites = {
        {
            id = "kabuki", label = "Kabuki Market", district = "Watson",
            enabled = true,
            bounds = { center = { x = -1198.0, y = 2018.0, z = 7.9 }, radius = 92.0 }, -- survey in game
            spawns = {
                -- side 1: south, Kabuki South Gate and the south-west lane
                { label = "South Gate",
                  points = {
                    { x = -1218.127, y = 1950.171, z = 7.984, heading = 347.4 }, -- survey in game
                    { x = -1247.272, y = 1973.837, z = 7.966, heading = 330.8 }, -- survey in game
                  } },
                -- side 2: north, the north lanes under The Gallery
                { label = "North Lanes",
                  points = {
                    { x = -1212.332, y = 2082.062, z = 7.847, heading = 204.5 }, -- survey in game
                    { x = -1192.751, y = 2072.839, z = 7.816, heading = 162.5 }, -- survey in game
                  } },
            },
            zones = {
                { id = "A", label = "The Stalls", x = -1223.905, y = 1989.450, z = 7.984, radius = 6.0 },  -- survey in game
                { id = "B", label = "Market Crossing", x = -1218.649, y = 2022.934, z = 7.816, radius = 6.0 }, -- survey in game
                { id = "C", label = "Lantern Row", x = -1220.135, y = 2048.270, z = 7.817, radius = 6.0 },  -- survey in game
            },
        },
        {
            -- The owner's Freeroam arena capture (2026-09-21): 17 walked marks on several
            -- decks, PvP-proven geometry. District name to confirm in game.
            id = "badlands", label = "Badlands Compound", district = "Badlands",
            enabled = true,
            bounds = { center = { x = 2998.928, y = -2414.493, z = 118.472 }, radius = 140.0 }, -- survey in game
            spawns = {
                { label = "West Yard",
                  points = {
                    { x = 2960.344, y = -2383.238, z = 119.381, heading = 250.0 }, -- survey in game
                    { x = 2959.277, y = -2396.605, z = 118.470, heading = 260.0 }, -- survey in game
                    { x = 2958.380, y = -2405.054, z = 120.409, heading = 270.0 }, -- survey in game
                  } },
                { label = "East Yard",
                  points = {
                    { x = 3037.262, y = -2396.562, z = 118.316, heading = 80.0 }, -- survey in game
                    { x = 3058.307, y = -2407.259, z = 118.437, heading = 90.0 }, -- survey in game
                    { x = 3030.921, y = -2426.717, z = 118.462, heading = 100.0 }, -- survey in game
                  } },
            },
            zones = {
                { id = "A", label = "North Deck", x = 2990.337, y = -2366.788, z = 122.422, radius = 6.0 }, -- survey in game
                { id = "B", label = "Upper Deck", x = 2994.936, y = -2400.323, z = 124.439, radius = 6.0 }, -- survey in game
                { id = "C", label = "South Yard", x = 3007.401, y = -2423.931, z = 118.324, radius = 7.0 }, -- survey in game
            },
        },
        {
            -- The Afterlife block, Valentinos / 6th Street ground. Zone centres are the
            -- rp-scripts points (street, back room, bar floor); the back room and the
            -- bar are interiors whose doors were never checked in a war: staff only
            -- until walked with two clients.
            id = "afterlife", label = "The Afterlife", district = "Watson",
            enabled = false,
            bounds = { center = { x = -1425.0, y = 1000.0, z = 20.0 }, radius = 85.0 }, -- survey in game
            spawns = {
                { label = "Afterlife Street",
                  points = { { x = -1390.0, y = 972.0, z = 23.5, heading = 40.0 } } },  -- survey in game
                { label = "Afterlife Lot",
                  points = { { x = -1440.0, y = 1035.0, z = 22.7, heading = 200.0 } } }, -- survey in game
            },
            zones = {
                { id = "A", label = "Afterlife Street", x = -1408.0, y = 960.0, z = 23.5, radius = 6.0 },            -- survey in game
                { id = "B", label = "Back Room", x = -1419.9, y = 989.4, z = 16.6, radius = 4.5, spawnable = false }, -- survey in game
                { id = "C", label = "Bar Floor", x = -1453.0, y = 1017.0, z = 16.6, radius = 6.0, spawnable = false }, -- survey in game
            },
        },
    },

    -- Server tick: 4 Hz for deadlines, the rules step once a second.
    tickHz = 4,
    stepMs = 1000,
    hudMs = 1000,
    boardMs = 3000,

    -- Client
    keys = {
        kit = { id = "op77_turf.kit", name = "Turf War: next kit", key = "K" },
    },
    markers = {
        maxDistance = 220,
        ringHeight = 1.2,
        beaconHeight = 2.0,
        beaconLift = 4.0,
        neutral = { r = 240, g = 243, b = 246, a = 150 },
        contested = { r = 255, g = 204, b = 0, a = 220 },  -- the Light RP accent
    },
    map = { resource = "op77_map3d", category = "default" },
}
