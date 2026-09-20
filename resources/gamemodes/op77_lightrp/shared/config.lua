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
        menu = { id = "lightrp.playermenu", name = "Light RP: player menu", key = "F1" },
        interact = { id = "lightrp.interact", name = "Light RP: interact", key = "E" },
        lock = { id = "lightrp.vehiclelock", name = "Light RP: lock / unlock vehicle", key = "L" },
        walk = { id = "lightrp.walkmode", name = "Light RP: walk mode (cycle)", key = "A" },
        inventory = { id = "lightrp.inventory", name = "Light RP: inventory", key = "I" },
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
        blip = { sprite = "clothes", title = "Wardrobe", description = "Change your outfit and manage your saved looks." },
        spots = {
            { id = "citycenter", name = "Wardrobe // City Center",  position = { x = -629.602417, y = -391.612671, z = 8.186066 } },
            { id = "north",      name = "Wardrobe // Northside",    position = { x = -787.005127, y = 765.159668, z = 22.459297 } },
            { id = "hospital",   name = "Wardrobe // Hospital",     position = { x = -1419.849854, y = 1264.845093, z = 23.070534 } },
            { id = "lab",        name = "Wardrobe // Lab district", position = { x = 1617.371826, y = -783.505493, z = 49.979195 } },
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
                jobs = { "sanitation", "delivery", "mechanic", "taxi", "trauma" },
            },
        },
        centerPrompt = "Job center",
        centerRadius = 2.0,
        centerMarker = { shape = "cylinder", radius = 0.9, height = 0.65, color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 30.0, groundOffset = 0.05 },
        centerBlip = { sprite = "tech", title = "Job Center", description = "Find work: sanitation, courier, mechanic, taxi, medic." },
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
        hospital = { name = "hospital", label = "Hospital", position = { x = -1441.0, y = 1269.0, z = 123.0 }, heading = 0.0 },
        health = 1.0,          -- fraction of the maximum, as the life primitives expect
        graceMs = 4000,
        respawnDelayMs = 10000,
        restoreLastPosition = true,
        joinRetryMs = 250,
        joinTimeoutMs = 30000,
    },

    locations = {
        { name = "city",     label = "City Center West",    position = { x = -667.14, y = -382.61, z = 9.16 },     heading = 90.0 },
        { name = "hospital", label = "Hospital",             position = { x = -1441.0, y = 1269.0, z = 123.0 },    heading = 0.0 },
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
        blip = { sprite = "Zzz01_CarForPurchaseVariant", title = "Rent-a-Ride", description = "Rent a car by the half hour. Return it at any desk." },
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
