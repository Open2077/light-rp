-- op77_race public configuration. This file is sent to clients: no secrets and no
-- authority decisions belong here (the server re-validates everything it reads from it).

RaceConfig = {
    -- The gamemode that owns players, return points and rewards (the activity contract).
    core = "op77_lightrp",

    -- One instance = one routing bucket, inside the range Light RP gave the races.
    bucketBase = 4200000,
    bucketCount = 100000,

    -- The three activities this resource provides. `key` is internal, `id` is the
    -- contract's namespaced id. caps: nothing from the RP world comes along (no RP
    -- weapons, no RP items, needs frozen, no personal vehicles).
    activities = {
        {
            key = "trial", id = "race.trial", mode = "trial", kind = "race",
            label = "Time Trial",
            description = "Solo against the clock. Loaner car or on foot, best times on the board.",
            minPlayers = 1, maxPlayers = 1,
        },
        {
            key = "grid", id = "race.grid", mode = "grid", kind = "race",
            label = "Street Race",
            description = "Two to eight drivers on a starting grid, identical loaner cars.",
            minPlayers = 2, maxPlayers = 8,
            -- queued: a heat that waits for its players (join window, re-check at launch)
            queued = true,
            -- Once the minimum is queued, the join window stays open this long (new
            -- arrivals do not restart it); a full grid starts after fullSeconds.
            joinSeconds = 30, fullSeconds = 5,
        },
        {
            key = "foot", id = "race.foot", mode = "foot", kind = "race",
            label = "Rooftop Race",
            description = "Two to eight runners across the rooftops. No implants handed out.",
            minPlayers = 2, maxPlayers = 8,
            queued = true,
            joinSeconds = 25, fullSeconds = 5,
        },
        {
            -- Public, no staff switch: solo or with a crew, AI drivers fill the rest of
            -- the grid (`pve` below). The course is chosen like the time trial's.
            key = "pve", id = "race.pve", mode = "pve", kind = "race",
            label = "Street Race vs AI",
            description = "Solo or with your crew against AI drivers on a full grid. Pick the course.",
            minPlayers = 1, maxPlayers = 8,
        },
    },
    caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },

    engine = {
        -- Minimum loading window after the grid is set (the car streams in, the
        -- runner settles); early readiness does not shorten it.
        loadSeconds = { trial = 4, grid = 15, foot = 4, pve = 15 },
        loadAfterRestartSeconds = 2,
        -- A racer still not ready after this is classified DNF and sent back.
        readyTimeoutSeconds = 60,
        countdownSeconds = 3,
        durationSeconds = 1200,
        -- Once the winner finishes, the others have this long to cross the line.
        finishGraceSeconds = 30,
        resultsSeconds = { trial = 15, grid = 12, foot = 12, pve = 12 },
        checkpointRadius = 7.0,
        -- Do not accept a parallel street on a bridge above the course.
        checkpointZTolerance = 4.0,
        checkpointDebounceMs = 500,
        maxSegmentMetres = 80.0,
        tickMs = 100,
        seatPollMs = 500,
        holdCheckMs = 500,
        rankingPushMs = 1000,
        footStartSpacing = 2.0,
        teleportTimeoutMs = 30000,
        -- Fallback lanes when a vehicle course has fewer authored slots than racers
        -- (never used by the shipped courses: each has eight surveyed slots).
        startGrid = { lanes = 2, laneSpacing = 3.25, rowSpacing = 5.5 },
        vehicle = {
            default = "archer_hella",
            driverSeat = "seat_front_left",
            -- Placed on the final mark once materialized, unless the driver is
            -- already mounted (Freeroam's proven settle pass).
            settleAfterMs = 1200,
            settleMaxDriftMetres = 3.0,
            -- ForcedExit needs a short native window before the car is removed.
            exitSettleMs = 1500,
            primaryColor = { r = 24, g = 24, b = 24 },
            secondaryColor = { r = 255, g = 204, b = 0 },
        },
        -- Stable ids stored in course data. A record never comes from a course file
        -- or a browser: the server resolves the id through this allow-list.
        vehicles = {
            { id = "on_foot", label = "On foot" },
            { id = "archer_hella", label = "Archer Hella EC-D i360", record = "Vehicle.v_standard2_archer_hella_player" },
            { id = "quadra_turbo_r", label = "Quadra Turbo-R V-Tech", record = "Vehicle.v_sport1_quadra_turbo_r_player" },
            { id = "quadra_type66_avenger", label = "Quadra Type-66 Avenger", record = "Vehicle.v_sport2_quadra_type66_avenger_player" },
            { id = "rayfield_caliburn", label = "Rayfield Caliburn", record = "Vehicle.v_sport1_rayfield_caliburn_player" },
            { id = "herrera_outlaw", label = "Herrera Outlaw GTS", record = "Vehicle.v_sport1_herrera_outlaw_player" },
            { id = "mizutani_shion", label = "Mizutani Shion MZ2", record = "Vehicle.v_sport2_mizutani_shion_player" },
            { id = "porsche_911", label = "Porsche 911 II Turbo", record = "Vehicle.v_sport2_porsche_911turbo_player" },
            { id = "archer_quartz_nomad", label = "Archer Quartz Sidewinder", record = "Vehicle.v_standard2_archer_quartz_nomad_player" },
        },
    },

    -- Reputation proposed to Light RP with each result; the core clamps it per result
    -- and caps it per account per day. Never cash, never items.
    rewards = {
        trialFinish = 5, personalBest = 5, courseRecord = 10,
        heatFinish = 10,
        -- Placement bonus (1st, 2nd, 3rd), only when at least two racers started.
        placement = { 20, 10, 5 },
    },

    -- Best times of the time trial (data/records.json), per course revision.
    records = { keep = 20, show = 5 },

    -- Crews (the core's options.squad = { id, leader, members } on join): a crew races in
    -- one instance, on adjacent slots, and is never split across two. Its members join one
    -- by one; a launch waits up to gatherSeconds for the ones still on their way.
    crews = { gatherSeconds = 5 },

    -- Street Race vs AI (race.pve): AI drivers (the bots below) fill the grid behind the
    -- player or the crew. Results are recorded by the core like any activity, for less
    -- reputation than racing players, and never on a course too short to mean anything.
    -- Its times stay off the time trial's board: a separate best vs AI per course.
    pve = {
        fillTo = 6,                -- racers in total (players + AI), within the course's grid
        rewards = { finish = 6, placement = { 12, 6, 3 } }, -- about 60% of a street race
        minimumMetres = 1500,      -- course length (all laps) below which no reputation is proposed
        minimumSeconds = 60,       -- finish time below which no reputation is proposed
    },

    -- Staff bot mode (op77_lightrp `/lightrp.bots on|off`, off at every start): a street
    -- or rooftop race opens its grid with ONE player and NPC bots fill the empty places.
    -- A race with bots records nothing: no best time, and its results go to the core
    -- flagged `test` (no stats, no reputation). The time trial is solo and never gets bots.
    bots = {
        -- Racers on the line in total (players + bots), capped by the course's capacity.
        fillTo = { grid = 4, foot = 4 },
        -- Join window once one player is queued in bot mode; nil keeps the activity's own.
        joinSeconds = { grid = nil, foot = nil },
        -- Shown in the ranking and the result card in front of the bot's callsign.
        namePrefix = "[BOT] ",
        callsigns = { "Ash", "Bolt", "Cinder", "Dagger", "Ember", "Flint", "Grit", "Husk",
            "Iron", "Jolt", "Kite", "Lash", "Mote", "Nail", "Onyx", "Pike" },
        -- Crowd civilians that neither flee nor panic (Light RP's rental desk pool), tried in
        -- order until the platform accepts one. Invulnerable, no combat, no perception.
        driverRecords = {
            "Character.mws_thenerves_driver_02", "Character.mws_thenerves_driver_01",
            "Character.ma_std_rcr_slacker_02", "Character.mws_thenerves_crowd_01",
        },
        runnerRecords = {
            "Character.ma_std_rcr_slacker_01", "Character.ma_std_rcr_slacker_02",
            "Character.mws_thenerves_driver_01", "Character.mws_thenerves_crowd_01",
        },
        npcStreamingRadius = 300.0,
        -- The countdown waits this long past the loading window for bots still being set
        -- up; the ones still not ready are dropped from the grid.
        readyWaitSeconds = 8,
        -- No checkpoint for this long: the bot is given its route again; after maxRetasks
        -- re-tasks without progress it is out (DNF). The clock pauses while the platform
        -- has nobody near enough to simulate it (the leader far ahead of every player).
        stuckSeconds = 20,
        maxRetasks = 2,
        -- Same checkpoint rules as the players; a bonus here widens the bots' cylinders.
        checkpointRadiusBonus = 0.0,
        car = {
            -- Open77.vehicles.ai: normal | cautious | aggressive (clears traffic on its path).
            behavior = "aggressive",
            speed = 30.0,              -- m/s ceiling, 0.5..55 (30 = 108 km/h)
            arrivalRadius = 8.0,       -- m, 1..20: a route point counts as reached inside this
            routePoints = 24,          -- checkpoints handed per followRoute (the native takes 64)
            routeRefill = 3,           -- a new stretch is handed when this few points remain
            attachRetryMs = 1000,
            -- Bots cars look different from the players' loaners.
            primaryColor = { r = 200, g = 200, b = 205 },
            secondaryColor = { r = 200, g = 20, b = 40 },
            -- After the line: roll on this far at this speed, then stop, clear of the finish.
            runOutMetres = 60.0,
            cooldownSpeed = 8.0,
        },
        foot = {
            speed = "sprint",          -- walk | run | sprint (Open77.npcs.tasks.moveTo)
            acceptanceRadius = 1.0,
            runOutMetres = 6.0,
        },
    },

    editor = {
        sessionMinutes = 30,
        worldBucket = 0,
        vehicleSpawnDistance = 4.5,
        vehicleSpawnLiftMetres = 0.35,
        minimumCheckpoints = 1,
        maximumCheckpoints = 96,
        minimumLaps = 1, maximumLaps = 20,
        minimumRadius = 2.0, maximumRadius = 30.0,
        maximumNameBytes = 64,
        maximumDescriptionBytes = 240,
        minimumGridSlots = 1,
        minimumGridSpacing = 2.75,
        -- Editor preview markers drawn at once (start + grid + the latest checkpoints).
        previewMarkers = 24,
    },

    visuals = {
        enabled = true,
        checkpointViewDistance = 180.0,
        checkpointMarker = { radius = 2.5, height = 3.5, lift = 3.0 },
    },

    -- op77_map3d (the minimap / GPS Light RP runs instead of the vanilla one).
    map = {
        resource = "op77_map3d",
        category = "default",
        color = "#FFCC00",
        finishColor = "#FFFFFF",
        -- Vehicle races get a road route to the next checkpoint; on foot, only a pin.
        routeVehicles = true,
    },

    presentation = {
        gridReadySfx = "ui_menu_onpress",
        countdownSfx = "sq024_race_countdown_start",
        countdownTickSfx = "ui_menu_onpress",
        countdownGoSfx = "ui_jingle_quest_new",
        goSfx = "sq024_race_start_fireworks",
        checkpointSfx = "ui_menu_onpress",
        lapSfx = "ui_jingle_quest_update",
        finishSfx = "ui_jingle_quest_success",
        -- One visual-only shell per accepted crossing, to the race bucket only, at
        -- most one per instance per minIntervalMs (client effect quota).
        checkpointFirework = { enabled = true, effect = "race.firework.burst", height = 12.0, range = 180.0, minIntervalMs = 1500 },
        -- One-shots with an explicit duration (a nil duration never expires and
        -- holds a client effect-quota slot for the session).
        startVfx = {
            { effect = "race.flare.smoke", lateral = -5.5, forward = 2.0, z = 0.20, duration = 8.0 },
            { effect = "race.flare.smoke", lateral = 5.5, forward = 2.0, z = 0.20, duration = 8.0 },
            { effect = "race.firework.burst", lateral = 0.0, forward = 5.0, z = 6.0, duration = 7.5 },
        },
    },

    -- Where a racer is sent when Light RP cannot take them back (core stopped or
    -- activityLeave refused) and no point was captured: The Crossing lobby.
    fallbackPoint = { x = -756.581, y = 777.257, z = 22.454, heading = 52.6, bucket = 0 },

    -- Rebindable in Pause > Settings > Key bindings. Taken elsewhere in the Light RP
    -- load list: TAB, F1-F5, F9-F11, Alt, N, E, I, L, X, Y, H, G, R, C, M (Light RP),
    -- F6/F7 (open77_remote_camera), F8 (voice range), DELETE (mission editor),
    -- PAGEUP/PAGEDOWN (op77_map3d zoom fallback). These stay clear of all of them.
    keys = {
        respawn = { id = "op77_race.respawn", name = "Race: back to the last checkpoint (on foot)", key = "END" },
        restart = { id = "op77_race.restart", name = "Race: restart the time trial", key = "HOME" },
    },
    -- Course editor (staff: ACL command.race.editor opens the session; the keys do
    -- nothing without one). The rest is /race.editor <action>.
    editorKeys = {
        start = { id = "op77_race.editor.start", name = "Race editor: capture the start", key = "UP" },
        checkpoint = { id = "op77_race.editor.checkpoint", name = "Race editor: add a checkpoint", key = "INSERT" },
        grid = { id = "op77_race.editor.grid", name = "Race editor: add a grid slot", key = "RIGHT" },
        undo = { id = "op77_race.editor.undo", name = "Race editor: undo the last checkpoint", key = "DOWN" },
    },


    debug = false,
}
