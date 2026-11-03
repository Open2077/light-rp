-- Light Roleplay framework configuration. Shared with clients: no secrets here.
LightRpConfig = {
    serverName = "Open//77 Official Roleplay",

    welcome = {
        enabled = true,
        title = "Welcome to Night City",
        text = "Light RP server. F1 opens your player menu, /help lists the commands.",
        -- The first-spawn briefing (page WelcomeModal): the OK button unlocks after
        -- this many seconds so the player actually reads it. Shown once per account.
        readSeconds = 15,
    },
    rules = {
        "1. Stay in character: plain chat is in-character (IC), /ooc for out-of-character talk.",
        "2. No kills without a roleplay reason, no fleeing mid-scene (no RDM/VDM).",
        "3. Respect the other players: no harassment, no metagaming.",
        "4. One vehicle at a time; park it before returning it with /dv.",
        "5. A problem? /report <message> alerts the staff.",
    },

    -- The player menu key (RageUI-style list menu). Rebindable in Pause > Settings
    -- > Key bindings. New id on purpose: the old F5 terminal binding is forgotten.
    keys = {
        animations = { id = "lightrp.animations", name = "Light RP: animations", key = "F3" },
        animationStop = { id = "lightrp.animations.stop", name = "Light RP: stop animation", key = "X" },
        menu = { id = "lightrp.playermenu", name = "Light RP: player menu", key = "F1" },
        interact = { id = "lightrp.interact", name = "Light RP: interact", key = "E" },
        lock = { id = "lightrp.vehiclelock", name = "Light RP: lock / unlock vehicle", key = "L" },
        walk = { id = "lightrp.walkmode", name = "Light RP: walk mode (cycle)", key = "F4" },
        inventory = { id = "lightrp.inventory", name = "Light RP: inventory", key = "I" },
        hotbar = { id = "lightrp.hotbar", name = "Light RP: show quick slots (hold)", key = "TAB" },
        weaponWheel = { id = "lightrp.weaponwheel", name = "Light RP: weapon wheel (hold)", key = "TAB" },
        raidReady = { id = "lightrp.raid.ready", name = "Light RP: raid ready check", key = "Y" },
        -- Answer the newest crew invite while the HUD prompt shows it (the raid's
        -- ready check keeps Y while it runs).
        crewAccept = { id = "lightrp.crew.accept", name = "Light RP: accept crew invite", key = "Y" },
        crewDecline = { id = "lightrp.crew.decline", name = "Light RP: decline crew invite", key = "N" },
        -- Leave whatever queue the queue panel shows (activities, mission boards). U: free
        -- in Light RP, its providers and the base game outside menus, same key on AZERTY.
        queueLeave = { id = "lightrp.queue.leave", name = "Light RP: leave queue", key = "U" },
    },

    -- Inventories (shared/items.lua holds the item templates). Weights in kg.
    inventory = {
        player = { slots = 30, weight = 40.0 },
        trunk = { slots = 20, weight = 80.0, range = 4.5 },      -- the closest vehicle you can open
        stash = { slots = 40, weight = 250.0, range = 3.5, interactRadius = 2.0,
            marker = { shape = "cylinder", radius = 0.7, height = 0.5, color = { r = 255, g = 204, b = 0, a = 140 }, maxDistance = 25.0, groundOffset = 0.05 } },
        drop = { slots = 20, weight = 200.0, radius = 2.0, ttlMinutes = 10,
            marker = { shape = "cylinder", radius = 0.45, height = 0.25, color = { r = 255, g = 204, b = 0, a = 120 }, maxDistance = 20.0, groundOffset = 0.03 } },
        giveRange = 3.0,
        -- Granted once when a new character's inventory is created; existing inventories are kept.
        starting = { { name = "water", count = 5 }, { name = "burrito", count = 5 } },
        -- Persistent stashes in the world (pick positions with /pos).
        stashes = {
            -- { id = "citycenter", name = "Storage // City Center", position = { x = 0, y = 0, z = 0 }, slots = 40, weight = 250 },
        },
    },

    -- Free camera (player menu or its key): the view leaves the character and
    -- flies around it; the body stays where it is, complete and in third person.
    -- On foot only. Every key below is rebindable in Pause > Settings > Key bindings;
    -- forward/back/strafe_* follow the keyboard layout (WASD, ZQSD on AZERTY).
    freecam = {
        enabled = true,
        radius = 25.0,       -- metres the lens may travel from the character (3..100)
        below = 0.5,         -- metres under the character's feet, so nobody films through floors
        leash = 4.0,         -- the camera closes if the character is moved further than this
        speed = 4.0, minSpeed = 0.5, maxSpeed = 15.0, -- metres per second; the wheel changes it
        boost = 3.0, precision = 0.25,                -- multipliers of the boost / precision keys
        sensitivity = 0.12,  -- degrees per mouse count at a 60 degree lens
        fov = { default = 60, min = 20, max = 100 },  -- precision key + wheel zooms
        smoothing = { move = 9.0, look = 18.0, zoom = 8.0 }, -- higher is snappier, lower floats more
        blendMs = 450,       -- glide out of / back into the player's own view
        entry = { back = 3.2, up = 1.9, pitch = -8 }, -- first shot when coming from first person
        keys = {
            toggle = { id = "lightrp.freecam", name = "Light RP: free camera", key = "F5" },
            forward = { id = "lightrp.freecam.forward", name = "Free camera: forward", key = "forward" },
            back = { id = "lightrp.freecam.back", name = "Free camera: back", key = "back" },
            left = { id = "lightrp.freecam.left", name = "Free camera: left", key = "strafe_left" },
            right = { id = "lightrp.freecam.right", name = "Free camera: right", key = "strafe_right" },
            up = { id = "lightrp.freecam.up", name = "Free camera: up", key = "SPACE" },
            down = { id = "lightrp.freecam.down", name = "Free camera: down", key = "C" },
            boost = { id = "lightrp.freecam.boost", name = "Free camera: fast", key = "SHIFT" },
            slow = { id = "lightrp.freecam.slow", name = "Free camera: precise / zoom with the wheel", key = "CTRL" },
            reset = { id = "lightrp.freecam.reset", name = "Free camera: back behind the character", key = "R" },
            hints = { id = "lightrp.freecam.hints", name = "Free camera: show / hide the key reminder", key = "H" },
            exit = { id = "lightrp.freecam.exit", name = "Free camera: leave", key = "BACKSPACE" },
        },
    },

    -- Walk modes cycled by the walk key: run (platform default), walk, slow walk.
    -- `speed` is metres per second for Open77.movement.setWalkMode (0.5..2.5);
    -- no speed means the request is released and the player runs normally.
    movement = {
        modes = {
            { id = "run",  label = "RUN" },
            { id = "walk", label = "WALK", speed = 1.5 },
            { id = "slow", label = "SLOW WALK", speed = 0.9 },
        },
    },

    -- Wardrobe points: a 3D marker on the ground, E opens the wardrobe UI of
    -- the platform for an active character. Add a spot per changing room; pick
    -- positions with /pos. Rule of the server: no /wardrobe for players.
    wardrobes = {
        enabled = true,
        key = "E",
        prompt = "Change outfit",
        interactRadius = 2.0,
        marker = {
            shape = "cylinder", radius = 0.9, height = 0.65,
            color = { r = 255, g = 204, b = 0, a = 160 },
            maxDistance = 30.0, groundOffset = 0.05,
        },
        blip = { icon = "shirt", sprite = "clothes", title = "Wardrobe", description = "Change your outfit and manage your saved looks." },
        -- A fitting room is private: from these shared buckets (the city is 0) the player
        -- changes in bucket privateBucketBase + their id, and comes back on closing.
        privateBucketBase = 710000,
        sharedBuckets = { 620000 }, -- the first day's arrival hall (LightRpTutorialConfig.lobby.bucket)
        spots = {
            -- The arrival hall's boutique, back corner (lobby map, shop interior; tutorial step "dress").
            { id = "lobby_fitting", name = "Fitting room // Arrival Hall", position = { x = 6780.0, y = 2427.0, z = 400.03 },
              bucket = 620000, noBlip = true },
            { id = "citycenter", name = "Wardrobe // City Center",  position = { x = -629.602417, y = -391.612671, z = 8.186066 } },
            { id = "north",      name = "Wardrobe // Northside",    position = { x = -787.005127, y = 765.159668, z = 22.459297 } },
            { id = "hospital",   name = "Wardrobe // Hospital",     position = { x = -1419.849854, y = 1264.845093, z = 23.070534 } },
            { id = "lab",        name = "Wardrobe // Lab district", position = { x = 1617.371826, y = -783.505493, z = 49.979195 } },
            -- The game's clothing stores (cyberpunk2077-map.com, category CLOTHING), placed
            -- roughly: map pixels -> world through a fit on the five gun stores (2-18 m),
            -- z from the 3D map's street network. To be moved onto each shop's counter in game.
            { id = "clothing_176", name = "Clothing Store // City Center", position = { x = -1896.40, y = 39.24, z = 14.53 } }, -- site marker 176, z from the nearest road (none within 30 m)
            { id = "clothing_179", name = "Clothing Store // Heywood 1", position = { x = -1583.147827, y = -274.218903, z = -4.055000 } }, -- site marker 179, moved onto the shop in game
            { id = "clothing_185", name = "Clothing Store // Heywood 2", position = { x = -2427.479492, y = -669.060669, z = 7.306526 } }, -- site marker 185, moved onto the shop in game
            { id = "clothing_202", name = "Clothing Store // Pacifica", position = { x = -2467.025879, y = -2534.797607, z = 17.349373 } }, -- site marker 202, moved onto the shop in game
            { id = "clothing_206", name = "Clothing Store // Badlands", position = { x = 1209.411865, y = -568.905518, z = 32.995987 } }, -- site marker 206, moved onto the shop in game
            { id = "clothing_193", name = "Clothing Store // Santo Domingo 1", position = { x = -1015.802185, y = -1559.615234, z = 25.700897 } }, -- site marker 193, moved onto the shop in game
            { id = "clothing_210", name = "Clothing Store // Santo Domingo 2", position = { x = 252.429825, y = -1473.184082, z = 9.500000 } }, -- site marker 210, moved onto the shop in game
            { id = "clothing_134", name = "Clothing Store // Watson 1", position = { x = -1892.363403, y = 2493.874023, z = 18.647926 } }, -- site marker 134, moved onto the shop in game
            { id = "clothing_171", name = "Clothing Store // Watson 2", position = { x = -1120.799194, y = 1754.370972, z = 33.791740 } }, -- site marker 171, moved onto the shop in game
            { id = "clothing_794", name = "Clothing Store // Watson 3", position = { x = -1527.275513, y = 1691.166260, z = 18.701965 } }, -- site marker 794, moved onto the shop in game
            { id = "clothing_148", name = "Clothing Store // Westbrook 1", position = { x = -645.631348, y = 1185.507202, z = 28.607452 } }, -- site marker 148, moved onto the shop in game
            { id = "clothing_159", name = "Clothing Store // Westbrook 2", position = { x = -219.67, y = -42.74, z = 7.00 } }, -- site marker 159, z from the nearest road (none within 30 m)
        },
    },

    -- Places shown on the maps only (no marker, no prompt): the game's bars and clubs,
    -- with the native sprite on the game map and a drawn pin on the 3D map
    -- (client/core/map_places.lua). Positions from cyberpunk2077-map.com (BAR markers,
    -- fitted on the gun stores, z from the 3D map's streets); a bar takes a venue's name
    -- when the site's named place is within 60 m.
    mapPlaces = {
        enabled = true,
        kinds = {
            bar = { sprite = "bar", title = "Bar", mapIcon = "bar", category = "nightlife", color = "#FF3FB4", description = "Drinks, music and the night crowd." },
            club = { sprite = "bar", title = "Club", mapIcon = "club", category = "nightlife", color = "#FF3FB4", description = "A club: dancefloor, VIP rooms, private shows." },
        },
        places = {
            { id = "bar_188", kind = "bar", name = "El Coyote Cojo", district = "Heywood", position = { x = -1251.26, y = -968.78, z = 11.89 } }, -- site BAR 188, named after "El Coyote Cojo" 44 m away
            { id = "bar_963", kind = "bar", name = "Afterlife", district = "Watson", position = { x = -1455.58, y = 1030.10, z = 22.56 } }, -- site BAR 963, named after "Afterlife" 38 m away
            { id = "bar_167", kind = "bar", name = "Ho-Oh", district = "Watson", position = { x = -1037.37, y = 1347.92, z = 5.17 } }, -- site BAR 167, named after "Ho-Oh" 31 m away
            { id = "bar_163", kind = "bar", name = "Riot", district = "Watson", position = { x = -1648.58, y = 1017.30, z = 23.40 } }, -- site BAR 163, named after "Riot" 23 m away
            { id = "club_1015", kind = "club", name = "Clouds", district = "Westbrook", position = { x = -655.16, y = 800.01, z = 34.56 } }, -- site LANDMARK 1015
            { id = "bar_208", kind = "bar", name = "Bar // Badlands", district = "Badlands", position = { x = 1605.84, y = -801.34, z = 49.64 } }, -- site BAR 208
            { id = "bar_967", kind = "bar", name = "Bar // City Center 1", district = "City Center", position = { x = -1950.18, y = -11.69, z = 8.65 } }, -- site BAR 967
            { id = "bar_966", kind = "bar", name = "Bar // City Center 2", district = "City Center", position = { x = -1615.74, y = 373.57, z = 8.14 } }, -- site BAR 966
            { id = "bar_181", kind = "bar", name = "Bar // City Center 3", district = "City Center", position = { x = -1495.60, y = -370.88, z = 19.80 } }, -- site BAR 181
            { id = "bar_803", kind = "bar", name = "Bar // Heywood 1", district = "Heywood", position = { x = -1538.38, y = -1080.26, z = 32.35 } }, -- site BAR 803
            { id = "bar_965", kind = "bar", name = "Bar // Heywood 2", district = "Heywood", position = { x = -792.09, y = -119.44, z = 7.61 } }, -- site BAR 965
            { id = "bar_189", kind = "bar", name = "Bar // Santo Domingo", district = "Santo Domingo", position = { x = -724.22, y = -968.04, z = 7.80 } }, -- site BAR 189
            { id = "bar_136", kind = "bar", name = "Bar // Watson 1", district = "Watson", position = { x = -1727.87, y = 2203.50, z = 18.00 } }, -- site BAR 136
            { id = "bar_170", kind = "bar", name = "Bar // Watson 2", district = "Watson", position = { x = -1178.05, y = 1572.26, z = 22.14 } }, -- site BAR 170
            { id = "bar_160", kind = "bar", name = "Bar // Westbrook 1", district = "Westbrook", position = { x = -248.22, y = -75.67, z = 1.31 } }, -- site BAR 160
            { id = "bar_964", kind = "bar", name = "Bar // Westbrook 2", district = "Westbrook", position = { x = -93.47, y = 203.55, z = 14.44 } }, -- site BAR 964
        },
    },

    -- Jobs and gangs (catalogue in shared/jobs.lua). Paychecks go to the bank.
    jobs = {
        paycheckMinutes = 30, -- 0 disables paychecks
        -- Job centers: a clerk (crowd NPC, AI off), a marker, E opens the desk.
        -- `jobs` lists what that desk offers; applying starts at grade 0.
        centers = {
            {
                id = "citycenter", name = "Job Center // City Center",
                position = { x = -645.578979, y = -412.519470, z = 8.196312 }, heading = 56.899963,
                jobs = { "sanitation", "scrapper", "delivery" },
            },
        },
        centerPrompt = "Job center",
        centerRadius = 2.0,
        centerMarker = { shape = "cylinder", radius = 0.9, height = 0.65, color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 30.0, groundOffset = 0.05 },
        centerBlip = { icon = "briefcase-business", sprite = "tech", title = "Job Center", description = "Find work: sanitation, scrap recovery and rooftop AC cleaning." },
    },

    -- Vehicle keys: L locks or unlocks the vehicle you sit in or the closest one
    -- within `range`, if your character holds a key for it. A locked vehicle
    -- blocks entry and trunk access for everyone until a key holder unlocks it.
    -- (Not `keys`: that table holds the key bindings above.)
    vehicleKeys = {
        range = 8.0,
        -- The horn is the platform's network-synchronised one, so everyone
        -- around hears the same thing: one "bip" to lock, "bip bip" to unlock.
        horn = { bipMs = 110, gapMs = 170, lock = 1, unlock = 2 }, -- counts; 0 disables
    },

    -- Fuel. Every network vehicle carries a tank in its state bag (`fuel` litres,
    -- `fuelMax` capacity), burned by the server from the replicated speed while
    -- the engine runs. Empty tank = engine cut and throttle locked until someone
    -- refuels: at a gas station pump (E next to the pump, car parked within
    -- pumpRange) or with a jerrycan from the inventory. Tanks by catalog category.
    fuel = {
        enabled = true,
        tickMs = 1000,
        -- Game rates, not spec-sheet ones: a 55 L tank lasts about 45 min of
        -- city driving (~60 km/h) and about 1h30 of idling.
        litresPerHundredKm = 110.0,  -- burned by distance while moving (1 L every ~55 s at 60 km/h)
        idleLitresPerMinute = 0.6,   -- burned by time while the engine idles
        multiplier = 1.0,            -- scales both rates (staff: /lightrp.fuelrate)
        tanks = { default = 60, Street = 55, Utility = 90, Sport = 65, Bikes = 30 }, -- litres, by vehicles.catalog category
        reserve = 0.15,              -- fraction: HUD turns amber and the driver is warned once
        rentalTank = { min = 0.35, max = 0.75 }, -- rentals are delivered with a partial tank
        pricePerLitre = 4,           -- eddies, whole litres only at the pump (≈ 260 €$/h behind the wheel)
        pumpRange = 7.0,             -- metres between the pump point and the vehicle
        parkedSpeed = 0.25,
        clusterRadius = 35.0,       -- maximum separation within one station
        clusterHeight = 4.0,        -- do not merge stations on different floors
        litresPerSecond = 1.2,
        minimumFillMs = 5000,
        approachTimeoutMs = 45000,
        vehicleUseRange = 3.8,
        animation = { profile = "barlean", clip = "stand_bar_lean0__2h_on_bar__01__tapping__01" },
        jerrycan = { litres = 20, deposit = 25, range = 4.0 }, -- item `jerrycan`; the can comes back empty and refills at any pump
        prompt = "Refuel",
        interactRadius = 2.5,
        marker = false, -- interact with the real pumps, no forest of ground rings
        blip = { icon = "fuel", sprite = "tech", title = "Fuel station", description = "Engine off. Refuel on foot; jerrycans available." },
        -- Standing points immediately in front of the real world pumps.
        -- Nearby points automatically share one centred station map blip.
        stations = {
            { id = "pump01", name = "Fuel station", position = { x = -595.785522, y = -722.328979, z = 8.715637 } },
            { id = "pump02", name = "Fuel station", position = { x = -588.274170, y = -721.420044, z = 8.718803 } },
            { id = "pump03", name = "Fuel station", position = { x = -588.936157, y = -717.189331, z = 8.717735 } },
            { id = "pump04", name = "Fuel station", position = { x = -596.575928, y = -718.674561, z = 8.715202 } },
            { id = "pump05", name = "Fuel station", position = { x = -597.285767, y = -713.731201, z = 8.715065 } },
            { id = "pump06", name = "Fuel station", position = { x = -589.784546, y = -712.189575, z = 8.719681 } },
            { id = "pump07", name = "Fuel station", position = { x = -590.538818, y = -708.434448, z = 8.739944 } },
            { id = "pump08", name = "Fuel station", position = { x = -597.938599, y = -710.005127, z = 8.740982 } },
            { id = "pump09", name = "Fuel station", position = { x = -598.561096, y = -704.878418, z = 8.719795 } },
            { id = "pump10", name = "Fuel station", position = { x = -591.512207, y = -703.419617, z = 8.714996 } },
            { id = "pump11", name = "Fuel station", position = { x = -591.772949, y = -699.219849, z = 8.719849 } },
            { id = "pump12", name = "Fuel station", position = { x = -599.259888, y = -700.860901, z = 8.716759 } },
        },
    },

    vehicleContext = {
        enabled = true,
        range = 4.5,             -- trunk, hood, storage, engine and lights
        remoteRange = 8.0,       -- key fob lock / horn / information
        stationarySpeed = 0.5,  -- m/s: park before operating trunk/hood or engine
        cooldownMs = 300,
        hornCooldownMs = 2500,
        hornDurationMs = 450,
        -- Only trunk (bit 4 = 16) and hood (bit 5 = 32) are offered. Bikes
        -- have neither; other models default to both (48). No cabin doors/windows.
        -- Example override: ["Vehicle.custom"] = { doors = 16 } -- trunk only
        models = {},
    },

    spawn = {
        arrival = { name = "city", label = "City Center West", position = { x = -667.14, y = -382.61, z = 9.16 }, heading = 90.0 },
        -- Where the first day's guide leaves the newcomer in Night City, at its end or
        -- skipped (and where a character saved inside the arrival hall wakes up): a
        -- Westbrook esplanade about 115 m from the starter studio's door. The studio is
        -- still given; its door is on the map. Unset: the guide takes them into it.
        afterTutorial = { name = "after_tutorial", label = "Night City", position = { x = -756.581, y = 777.257, z = 22.454 }, heading = 52.6 },
        hospital = { name = "hospital", label = "Hospital", position = { x = -1355.739746, y = 1737.886597, z = 18.200012 }, heading = 0.0 },
        health = 1.0,          -- fraction of the maximum, as the life primitives expect
        graceMs = 4000,
        respawnDelayMs = 10000,
        restoreLastPosition = true,
        joinRetryMs = 250,
        joinTimeoutMs = 30000,
    },

    locations = {
        { name = "city",     label = "City Center West",    position = { x = -667.14, y = -382.61, z = 9.16 },     heading = 90.0 },
        { name = "hospital", label = "Hospital",             position = { x = -1355.739746, y = 1737.886597, z = 18.200012 }, heading = 0.0 },
        { name = "stoop",    label = "King Stoop",           position = { x = -410.22, y = 722.73, z = 115.0 },    heading = 0.0 },
        { name = "north",    label = "North Promenade",      position = { x = -469.47, y = 930.99, z = 56.45 },    heading = 0.0 },
        { name = "dealer",   label = "Westbrook Dealership", position = { x = -1442.2, y = 127.4, z = 18.0 },      heading = 0.0 },
        { name = "coast",    label = "South-west Coast",     position = { x = -1716.38, y = -2421.28, z = 62.59 }, heading = 0.0 },
        { name = "lab",      label = "Laboratory",           position = { x = 1669.75, y = -739.12, z = 49.86 },   heading = 180.0 },
    },

    chat = {
        requireCharacterForIc = true,
        icRange = 20.0,
        whisperRange = 4.0,
        shoutRange = 45.0,
        meRange = 20.0,
        colors = {
            ic = { 238, 244, 248 }, whisper = { 170, 170, 190 }, shout = { 255, 205, 120 },
            me = { 194, 162, 218 }, ["do"] = { 150, 200, 255 }, ooc = { 140, 150, 160 },
            system = { 255, 204, 0 }, staff = { 255, 46, 60 }, ["try"] = { 255, 215, 0 },
        },
    },

    -- Hunger and thirst: percent, ticking down while in the world. Barebone: no
    -- consumables yet; staff /lightrp.heal refills them. The HUD shows both.
    needs = {
        enabled = true,
        tickMs = 60000,
        foodPerTick = 0.6,   -- ~2h45 from 100 to 0
        drinkPerTick = 0.9,  -- ~1h50 from 100 to 0
        warnAt = 20,
        starveDamagePerTick = 3, -- health lost per tick at 0
    },

    voice = {
        -- Metres per range, applied through open77_voice when the player switches.
        ranges = { whisper = 4, normal = 15, shout = 40 },
        default = "normal",
    },

    vehicles = {
        enabled = true,
        maxPerPlayer = 1,
        cooldownMs = 10000,
        removeOnDisconnect = true,
        spawnOffset = { x = 3.0, y = 0.0, z = 0.25 },
        catalog = {
            { key = "hella",    label = "Archer Hella",        category = "Street",  record = "Vehicle.v_standard2_archer_hella_player" },
            { key = "bandit",   label = "Archer Bandit",       category = "Street",  record = "Vehicle.v_standard2_archer_bandit_player" },
            { key = "quartz",   label = "Archer Quartz",       category = "Street",  record = "Vehicle.v_standard2_archer_quartz_player" },
            { key = "cortes",   label = "Villefort Cortes",    category = "Street",  record = "Vehicle.v_standard2_villefort_cortes_player" },
            { key = "colby",    label = "Thorton Colby",       category = "Street",  record = "Vehicle.v_standard2_thorton_colby_player" },
            { key = "galena",   label = "Thorton Galena",      category = "Street",  record = "Vehicle.v_standard2_thorton_galena_player" },
            { key = "maimai",   label = "Makigai MaiMai",      category = "Street",  record = "Vehicle.v_standard2_makigai_maimai_player" },
            { key = "hozuki",   label = "Mizutani Hozuki",     category = "Street",  record = "Vehicle.v_standard2_mizutani_hozuki_player" },
            { key = "thrax",    label = "Chevalier Thrax",     category = "Street",  record = "Vehicle.v_standard2_chevalier_thrax_player" },
            { key = "supron",   label = "Mahir Supron",        category = "Utility", record = "Vehicle.v_standard25_mahir_supron_player" },
            { key = "columbus", label = "Villefort Columbus",  category = "Utility", record = "Vehicle.v_standard25_villefort_columbus_player" },
            { key = "merrimac", label = "Thorton Merrimac",    category = "Utility", record = "Vehicle.v_standard25_thorton_merrimac_player" },
            { key = "semimaru", label = "Yaiba Semimaru",      category = "Sport",   record = "Vehicle.v_sport1_yaiba_semimaru_player" },
            { key = "kusanagi", label = "Yaiba Kusanagi",      category = "Bikes",   record = "Vehicle.v_sportbike1_yaiba_kusanagi_player" },
            { key = "apollo",   label = "Brennan Apollo",      category = "Bikes",   record = "Vehicle.v_sportbike3_brennan_apollo_player" },
            { key = "type66",   label = "Quadra Type-66",      category = "Sport",   record = "Vehicle.v_sport2_quadra_type66_player",     staffOnly = true },
            { key = "shion",    label = "Mizutani Shion",      category = "Sport",   record = "Vehicle.v_sport2_mizutani_shion_player",    staffOnly = true },
            { key = "caliburn", label = "Rayfield Caliburn",   category = "Sport",   record = "Vehicle.v_sport1_rayfield_caliburn_player", staffOnly = true },
        },
    },

    names = { minLength = 2, maxLength = 24, allowAccents = true },

    -- Vehicle rental desks: an NPC, a native 3D marker, E to talk. Each desk
    -- has its own stock (keys from vehicles.catalog) and prices. One rental per
    -- player, returned at any desk or taken back after durationMinutes.
    -- `parking` is where the car appears: pick it with /pos standing on the spot.
    rentals = {
        enabled = true,
        key = "E",
        interactRadius = 2.0,      -- metres: E works inside this
        marker = {
            shape = "cylinder", radius = 0.9, height = 0.65,
            color = { r = 255, g = 204, b = 0, a = 160 },
            maxDistance = 30.0, groundOffset = 0.05,
        }, -- translucent wall fading upwards; visual size is separate from interactRadius
        durationMinutes = 30,
        blip = { icon = "key-round", sprite = "Zzz01_CarForPurchaseVariant", title = "Rent-a-Ride", description = "Rent a car by the half hour. Return it at any desk." },
        -- Crowd civilians (docs/generated/npc-records-2.31.csv, category civilian,
        -- risk candidate, reaction preset NoReaction: they neither flee nor
        -- panic). One is picked at random per desk; the list is tried until the
        -- platform accepts a record. The native AI is switched off on top.
        npcPool = {
            { record = "Character.mws_hey_07_zetatech_executive" },  -- corporate suit, male
            { record = "Character.sts_hey_rey_06_receptionist" },    -- corporate, female
            { record = "Character.kab_victim_male_rich_corpo" },     -- arasaka corpo, male
            { record = "Character.mws_thenerves_crowd_01" },         -- rich, male
            { record = "Character.mws_thenerves_driver_02" },        -- lowlife, male
            { record = "Character.ma_std_rcr_slacker_01" },          -- workout, male
            { record = "Character.ma_std_rcr_slacker_02" },          -- youngster, male
            { record = "Character.mws_thenerves_driver_01" },        -- youngster, female
        },
        spots = {
            {
                id = "citycenter", name = "Rent-a-Ride // City Center",
                position = { x = -654.821594, y = -383.462616, z = 8.189293 }, heading = 90.0,
                parking = { position = { x = -654.762451, y = -389.363800, z = 7.991211 }, heading = 143.600037 },
                -- Entry-level wheels only: what a newcomer can afford by the half hour.
                stock = {
                    { key = "maimai", price = 50 },  -- Makigai MaiMai, the city's tin can
                    { key = "galena", price = 80 },  -- Thorton Galena, old economy hatch
                    { key = "colby",  price = 100 }, -- Thorton Colby, worn pickup
                    { key = "apollo", price = 60 },  -- Brennan Apollo, cheap dirt bike
                },
            },
        },
    },

    -- Money: one wallet per active character (cash + bank account XXX-XXX).
    -- Whole eddies only. Jobs, shops and rent will move money through
    -- LightRP.money.*; the ATM page will raise the money.* actions.
    economy = {
        currency = "€$",
        startingCash = 250,
        startingBank = 1500,
        maxTransaction = 1000000000,
        payRange = 6.0,          -- metres: /pay hands cash to someone next to you
        transferFee = 0,         -- flat fee per bank transfer, on top of the amount
        historyLength = 10,      -- ledger lines kept in memory and shown on the page
    },

    -- Character creation and slots. The body and the face are made in the native
    -- creator (open77_appearance) at the first join; the wizard collects the rest.
    characters = {
        arrivalScene = {
            autoStart = true,
            -- Ground under the seat. Camera offsets use X right / Y forward.
            position = { x = -1529.316650, y = 982.267017, z = 23.607117 },
            heading = 0.0,
            approachOffset = { x = 0, y = 1.1, z = 0 }, -- streamed arrival on the pavement
            bench = false, -- existing planter bench in the city, do not duplicate it
            benchOffset = { x = 0, y = -0.12, z = 0 },
            benchYawOffset = 180,
            bucketBase = 610000,
            music = "assets/audio/cloudy-day.mp3",
            musicVolume = 0.12,
            shots = {
                arrival = { x = -1.5, y = 3.6, z = 0.40, aimX = 0, aimZ = 1.20, fov = 48 },
                identity = { x = -1.1, y = 3.1, z = 0.42, aimX = 0, aimZ = 1.10, fov = 49 },
                background = { x = 1.9, y = 3.8, z = 0.65, aimX = -0.30, aimZ = 1.12, fov = 51 },
                appearance = { x = -0.75, y = 2.35, z = 0.98, aimX = 0.13, aimZ = 1.27, fov = 39 },
                review = { x = -2.4, y = 4.15, z = 0.42, aimX = 0.42, aimZ = 1.15, fov = 48 },
            },
        },
        maxSlots = 3,
        currentYear = 2077,   -- Night City's calendar, for the birth date
        minAge = 18,
        maxAge = 90,
        origins = {
            { key = "night_city", label = "Night City" },
            { key = "badlands",   label = "Badlands" },
            { key = "ncus",      label = "NUSA" },
            { key = "europe",    label = "Europe" },
            { key = "asia",      label = "Asia" },
            { key = "latam",     label = "Latin America" },
            { key = "africa",    label = "Africa" },
            { key = "orbit",     label = "Orbit" },
        },
    },
    tryChancePercent = 50,

    -- Who the UI treats as staff: any of these ACL permissions.
    staffPermissions = { "command.lightrp.status", "command.admin", "command.adminfull" },

    -- How often the server pushes its light state (online count) to every client.
    statePushMs = 15000,
}
