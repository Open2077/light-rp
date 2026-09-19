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
    },

    -- Vehicle keys: L locks or unlocks the vehicle you sit in or the closest one
    -- within `range`, if your character holds a key for it. A locked vehicle
    -- stays open for its key holders (per-player lock exceptions).
    -- (Not `keys`: that table holds the key bindings above.)
    vehicleKeys = {
        range = 8.0,
        -- The horn is the platform's network-synchronised one, so everyone
        -- around hears the same thing: one "bip" to lock, "bip bip" to unlock.
        horn = { bipMs = 110, gapMs = 170, lock = 1, unlock = 2 }, -- counts; 0 disables
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
            { key = "semimaru", label = "Yaiba Semimaru",      category = "Bikes",   record = "Vehicle.v_sport1_yaiba_semimaru_player" },
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
        blip = { sprite = "Zzz01_CarForPurchaseVariant", title = "Vehicle rental", description = "Rent a car by the half hour. Return it at any desk." },
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
                stock = {
                    { key = "maimai",   price = 60 },
                    { key = "hella",    price = 120 },
                    { key = "cortes",   price = 140 },
                    { key = "semimaru", price = 90 },
                    { key = "supron",   price = 180 },
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
