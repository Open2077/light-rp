-- Light Roleplay configuration. Shared with clients: no secrets here.
LightRpConfig = {
    serverName = "Open//77 Official Roleplay",

    -- What a player reads when they arrive, and what /rules prints.
    welcome = {
        enabled = true,
        title = "Bienvenue à Night City",
        text = "Serveur Light RP. Tapez /register Prénom Nom pour créer votre personnage, /help pour les commandes.",
    },
    rules = {
        "1. Restez dans votre personnage : le chat normal est RP (IC), /ooc pour le hors-jeu.",
        "2. Pas de kill sans raison RP, pas de fuite en cours de scène (RDM/VDM interdits).",
        "3. Respectez les autres joueurs : pas de harcèlement, pas de méta-gaming.",
        "4. Un véhicule à la fois, garez-le avant de le rendre avec /dv.",
        "5. Un problème ? /report <message> prévient le staff.",
    },

    -- Where players arrive and where they wake up. Coordinates are world metres.
    spawn = {
        -- First arrival (no saved position yet).
        arrival = { name = "city", label = "City Center ouest", position = { x = -667.14, y = -382.61, z = 9.16 }, heading = 90.0 },
        -- After death: the hospital.
        hospital = { name = "hospital", label = "Hôpital", position = { x = -1441.0, y = 1269.0, z = 123.0 }, heading = 0.0 },
        health = 100,
        graceMs = 4000,           -- spawn protection after a placement
        respawnDelayMs = 10000,   -- time on the ground before waking up at the hospital
        restoreLastPosition = true,
        joinRetryMs = 250,
        joinTimeoutMs = 30000,
    },

    -- Named places for the staff /lightrp.tp command.
    locations = {
        { name = "city",     label = "City Center ouest",   position = { x = -667.14, y = -382.61, z = 9.16 },     heading = 90.0 },
        { name = "hospital", label = "Hôpital",             position = { x = -1441.0, y = 1269.0, z = 123.0 },    heading = 0.0 },
        { name = "stoop",    label = "King Stoop",          position = { x = -410.22, y = 722.73, z = 115.0 },    heading = 0.0 },
        { name = "north",    label = "Promenade nord",      position = { x = -469.47, y = 930.99, z = 56.45 },    heading = 0.0 },
        { name = "dealer",   label = "Concession Westbrook", position = { x = -1442.2, y = 127.4, z = 18.0 },     heading = 0.0 },
        { name = "coast",    label = "Côte sud-ouest",      position = { x = -1716.38, y = -2421.28, z = 62.59 }, heading = 0.0 },
        { name = "lab",      label = "Laboratoire",         position = { x = 1669.75, y = -739.12, z = 49.86 },   heading = 180.0 },
    },

    -- Chat: normal text is in-character and travels by distance.
    chat = {
        requireCharacterForIc = true,  -- /register before speaking IC; /ooc always works
        icRange = 20.0,
        whisperRange = 4.0,
        shoutRange = 45.0,
        meRange = 20.0,
        colors = {
            ic = { 238, 244, 248 },
            whisper = { 170, 170, 190 },
            shout = { 255, 205, 120 },
            me = { 194, 162, 218 },
            ["do"] = { 150, 200, 255 },
            ooc = { 140, 150, 160 },
            system = { 0, 229, 255 },
            staff = { 255, 120, 120 },
            ["try"] = { 255, 215, 0 },
        },
    },

    -- One civilian vehicle per player, from this list only.
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
            -- Sport cars are listed but flagged: only staff may call them until an economy exists.
            { key = "type66",   label = "Quadra Type-66",      category = "Sport",   record = "Vehicle.v_sport2_quadra_type66_player",      staffOnly = true },
            { key = "shion",    label = "Mizutani Shion",      category = "Sport",   record = "Vehicle.v_sport2_mizutani_shion_player",     staffOnly = true },
            { key = "caliburn", label = "Rayfield Caliburn",   category = "Sport",   record = "Vehicle.v_sport1_rayfield_caliburn_player",  staffOnly = true },
        },
    },

    -- Character names: what /register accepts.
    names = {
        minLength = 2,
        maxLength = 24,
        pattern = "^[%a%-' ]+$",   -- letters, hyphen, apostrophe, space (Lua %a is ASCII-only; accents are allowed below)
        allowAccents = true,
    },

    -- /try succeeds this often (percent).
    tryChancePercent = 50,
}
