-- op77_arena: the Light RP edition of the Deathmatch engine.
--
-- Loaded after shared/config.lua, shared/kabuki.lua and shared/wire.lua (the engine,
-- kept close to upstream) and before every server script. Two things live here:
--
--   1. `LightRpArena`: the provider settings (activities, reputation, duels, Arena
--      Night). Read by server/lightrp.lua and client/hud.lua.
--   2. The engine overrides that make it a hosted activity: the city is the lobby
--      (bucket 0, never fenced, nobody placed on join), buckets in Light RP's arena
--      range 4100000-4199999, one Combat Zone, one Blade Night and one PvE Combat
--      Zone, bots only where server/lightrp.lua asks for them, the Freeroam arena
--      geometry, short Light RP-style text.
--
-- Shared: downloaded by every client. Never put anything secret here.

LightRpArena = {
    core = "op77_lightrp",
    source = "COMBAT ZONE", -- notice source line

    activities = {
        ffa = {
            id = "arena.ffa", label = "Combat Zone", kind = "pvp",
            description = "Drop-in free-for-all. Arena weapons only, respawn on death, leave any time.",
            minPlayers = 1, maxPlayers = 16,
            botFill = true,        -- the panel may offer bots (an unranked practice zone of the group's own)
        },
        blade = {
            id = "arena.blade", label = "Blade Night", kind = "pvp",
            description = "Melee free-for-all. Katanas, knives and blunts only.",
            minPlayers = 1, maxPlayers = 16,
            botFill = true,
        },
        duel = {
            id = "arena.duel", label = "Duel", kind = "pvp",
            description = "One on one, best of three. /duel <id> challenges a player near you.",
            minPlayers = 2, maxPlayers = 2,
            botFill = true,        -- a duel against a bot (unranked)
        },
        teams = {
            id = "arena.teams", label = "Team Arena", kind = "pvp",
            description = "2v2 or 3v3, best of three, elimination rounds.",
            minPlayers = 4, maxPlayers = 6,
            modes = { { id = "2v2", label = "2v2" }, { id = "3v3", label = "3v3" } },
            botFill = true,        -- bots complete the sides (unranked)
        },
        pve = {
            id = "arena.pve", label = "Combat Zone · PvE", kind = "pvp",
            description = "Players together against gang bots. Solo or with your crew, no friendly fire.",
            minPlayers = 1, maxPlayers = 6,
            pve = true,
            difficulties = { "standard", "hard", "critical" }, -- options.scaling: enemy count, health, damage, AI
            botFill = true,        -- options.fill.allies: allied bots on the players' side (still ranked)
        },
    },

    -- The PvE Combat Zone (arena.pve): open to everyone, no staff switch. The players
    -- are one side, the engine's bots the other; more players, more bots.
    pve = {
        maxPlayers = 6,            -- people per PvE round (the bots take the other seats)
        botsFirst = 3,             -- bots for the first player
        botsPerPlayer = 2,         -- more bots for every further player
        botsMax = 10,
        profile = nil,             -- engine difficulty profile; nil = DeathmatchConfig.bots.difficulty
        -- Allied bots (options.fill.allies from the Activities panel): they take the free
        -- player seats (maxPlayers - people), fight the gang bots with the players and count
        -- as players for the enemy scaling above. Never scaled by the difficulty.
        allyProfile = "standard",
        -- The difficulty (options.scaling) multiplies the enemy count, then this caps it;
        -- the instance's 16 bodies (people + allies + enemies) cap it too.
        enemiesMax = 14,
    },

    -- Matches formed by Light RP (options.match: friendly crew matches, bot-filled PvP,
    -- and ranked duel / Team Arena matches): one instance of their own each.
    lobby = {
        gatherMs = 5000,           -- every player of a match joins in one tick; after this it starts with who came
        keepMs = 120000,           -- a formed match is remembered this long (late joins are refused)
    },

    -- Crews (options.squad from Light RP): one crew, one instance, one side.
    crews = {
        gatherMs = 4000,           -- a team queue holds a crew this long for its members to arrive
    },

    duel = {
        maxDistance = 15.0,        -- metres between challenger and target
        inviteSeconds = 30,
        waitMinutes = 5,           -- the random duel queue
        repeatRewardsPerDay = 3,   -- reputation for the same pair, per server day
    },

    teams = { defaultFormat = "2v2" },

    -- Reputation sent with each result. Light RP clamps it (50 per result, daily cap).
    reputation = {
        ffa = { first = 30, second = 20, third = 15, other = 5, minHumans = 3, minRoundMs = 90000 },
        blade = { first = 30, second = 20, third = 15, other = 5, minHumans = 3, minRoundMs = 90000 },
        duel = { win = 20, loss = 5 },
        teams = { win = 25, loss = 5 },
        -- PvE: about 60 % of the PvP numbers, and only for a player who fought at
        -- least minRoundMs of the round, so a fast kill-limit round cannot be farmed.
        -- Won = the players killed more bots than the bots killed players.
        pve = { win = 18, loss = 3, minRoundMs = 120000 },
        maxPerResult = 50,
        nightMultiplier = 2,
    },

    -- Arena Night: a staff-run special Combat Zone round.
    night = {
        minutes = 60,              -- how long the special rules last
        roundSeconds = 600,
        killLimit = 40,
        announce = "core",         -- "core" (op77_lightrp:announce), "own" (notices) or "both"
        title = "ARENA NIGHT",
        text = "Arena Night is on. Join the Combat Zone from the Activities panel.",
        endText = "Arena Night is over. Thanks for fighting.",
    },

    allowBots = false,             -- outside bot mode, never fill a Light RP match with bots

    -- Player-versus-player (server/pvp.lua). Global PvP stays OFF on Light RP: each PvP
    -- instance (Combat Zone, Blade Night, Team Arena, duels) gets a combat scope over the
    -- people fighting in it. PvE needs none (its bots are NPCs).
    pvp = {
        scopesPerResource = 8,     -- platform limit per resource (never above 8): PvP instances beyond it do not open
        maxScopePlayers = 32,      -- platform limit per scope (never above 32): a PvP instance holds no more
        refreshMs = 15000,         -- a scope is rebuilt this often anyway, to heal a removal nobody saw
        retryMs = 2000,            -- a refused scope is retried this often
        tellAfterMs = 10000,       -- a refusal lasting this long is told to the instance's players
        -- Time to kill, person on person, inside PvP instances only (never host-global:
        -- that would change Dogtown and turf too). 1.0 = the platform's damage. Light RP
        -- fighters keep their armor and implants in the arena, unlike Freeroam's, so the
        -- engine's Freeroam numbers (damage 0.55, headshot 2.0) are not applied.
        damageMultiplier = 1.0,
        headshotMultiplier = 1.0,
    },

    -- Staff bot mode (/lightrp.bots on|off, op77_lightrp): one player starts what
    -- normally needs several and the engine's own bots (server/bots.lua: Cyberpunk's
    -- native combat AI, three mutually hostile gangs) fill the missing places. Nothing
    -- is recorded meanwhile: no Light RP result, no career, round or rating row.
    bots = {
        fillTarget = 6,            -- Combat Zone / Blade Night: bodies (players + bots) a round aims for
        ffa = true,                -- fill Combat Zone rounds
        blade = true,              -- fill Blade Night rounds (the gang bots keep their guns: no melee bot exists)
        teams = true,              -- complete Team Arena rosters (each side's missing slots)
        duel = true,               -- /duel bot, and the random duel queue falls back to a bot
        teamWaitMs = 0,            -- a queued team player waits this long for other people before bots complete the roster
        duelWaitMs = 0,            -- the random duel queue waits this long for a person before a bot takes the duel
        profile = nil,             -- engine difficulty profile (relaxed|standard|veteran); nil = DeathmatchConfig.bots.difficulty
        prefix = "[BOT] ",         -- the marker on every bot name: scoreboard, teams, kill feed
        inFlightMs = 20000,        -- paced bot spawns still arriving are counted this long
    },

    returnTimeoutMs = 12000,       -- waiting for a downed player to stand before the way home
    joinThrottleMs = 700,
    checkCacheMs = 1500,           -- activityCheck result reused while queued
    recentStateMs = 5000,          -- engine state pushes kept after leaving, for the HUD's last frame
}

local Config = DeathmatchConfig

-- ---------------------------------------------------------------------------
-- Hosted switches (the same seams Freeroam uses)

Config.freeroam = true             -- one FFA instance, per-entry bot consent
Config.placeOnJoin = false         -- server/main.lua patch: nobody is placed on connect

-- Light RP buckets: arena 4100000-4199999. The city (0) is the lobby.
Config.buckets.lobby = 0
Config.buckets.ffaFirst = 4100000
Config.buckets.ffaLast = 4100000
Config.buckets.arenaFirst = 4100100
Config.buckets.arenaLast = 4100199
-- Private Combat Zone / Blade Night instances, one per Light RP match (server/instances.lua
-- `Instances.open(format, ruleset, private)`): never joined by anyone outside the match.
Config.buckets.privateFirst = 4100010
Config.buckets.privateLast = 4100029

-- Only reached by engine paths this edition overrides; kept on The Crossing anyway.
Config.lobby.center = { x = -756.581, y = 777.257, z = 22.454 }
Config.lobby.heading = 52.6

Config.instances.ffaCeiling = 1
Config.instances.ffaCapacity = 16
Config.instances.ffaUnlimited = false
Config.instances.arenaCeiling = 24
Config.instances.privateCeiling = 8   -- the PvP scope budget (8 per resource) limits them too
Config.instances.adoptOnReload = false -- a reload never adopts: Light RP returns everyone
Config.instances.keepOneWarm = false
Config.formats.ffa.capacity = 16
Config.formats["1v1"].label = "Duel"
Config.formats["2v2"].label = "Team Arena 2v2"
Config.formats["3v3"].label = "Team Arena 3v3"

Config.arena.bestOf = 3
Config.arena.queue.fillWithBots = false
Config.bots.fillWithBots = false
-- Bot mode (server/lightrp.lua) fills with the engine's own add/addToArena; these two
-- keep /dm.bot fill and the bot names in step with it.
Config.bots.fillTarget = LightRpArena.bots.fillTarget
Config.bots.namePrefix = LightRpArena.bots.prefix
Config.loadout.promptOnFirstRound = false -- no picker page: /arena.weapon instead

-- Host-global combat policy is not the arena's on Light RP. Global PvP stays off (the
-- platform default) and must: a city-wide friendly fire would let anyone shoot anyone in
-- the street. PvP is opened per instance by a combat scope (server/pvp.lua), and the
-- engine's host-global multipliers below are Freeroam's: nothing applies them here.
Config.combat.friendlyFire = false

-- Career, rounds and Elo in Light RP's database, under our own prefix.
Config.career.tablePrefix = "op77_arena_"
Config.career.announceOnJoin = false      -- no arena card for every RP connection

local tunables = Config.tunables
tunables.ffaCeiling.value, tunables.ffaCeiling.max = 1, 1
tunables.ffaCeiling.description = "Light RP runs one Combat Zone."
tunables.ffaCapacity.value, tunables.ffaCapacity.max = 16, 24
tunables.arenaCeiling.value, tunables.arenaCeiling.max = 24, 48
tunables.arenaBestOf.value = 3
tunables.fillWithBots.value = false
tunables.arenaFillWithBots.value = false

-- Blade Night: the Blade FFA ruleset. No Mantis Blades: implants are Light RP's.
-- The PvE Combat Zone: a free-for-all ruleset with a bucket of its own (as Blade
-- Night), server/instances.lua `ownBucketRuleset`.
Config.pve = {
    bucket = 4100002,
    label = LightRpArena.activities.pve.label,
}

Config.blade = {
    bucket = 4100001,
    label = "Blade Night",
    default = "katana",
    weapons = {
        { key = "katana", label = "Katana", category = "Katana", record = "Items.Preset_Katana_Default" },
        { key = "errata", label = "Errata", category = "Katana", record = "Items.Preset_Katana_E3" },
        { key = "byakko", label = "Byakko", category = "Katana", record = "Items.Preset_Katana_Wakako" },
        { key = "knife", label = "Knife", category = "Knife", record = "Items.Preset_Knife_Default" },
        { key = "bluefang", label = "Blue Fang", category = "Knife", record = "Items.Preset_Neurotoxin_Knife_Iconic" },
        { key = "machete", label = "Machete", category = "Long blade", record = "Items.Preset_Machete_Default" },
        { key = "tomahawk", label = "Tomahawk", category = "Axe", record = "Items.Preset_Tomahawk_Default" },
        { key = "hammer", label = "Hammer", category = "Blunt", record = "Items.Preset_Hammer_Default" },
        { key = "bat", label = "Baseball Bat", category = "Blunt", record = "Items.Preset_Baseball_Bat_Default" },
        { key = "baton", label = "Electric Baton", category = "Blunt", record = "Items.Preset_Baton_Alpha" },
        { key = "chainsword", label = "Cut-o-Matic", category = "Chainsword", record = "Items.Preset_Chainsword_Default" },
    },
}

-- ---------------------------------------------------------------------------
-- Arena geometry: the arena the Freeroam owner captured on 2026-09-21
-- (freeroam/pvp/shared/freeroam.lua), same derivation, no invented positions.

local center = { x = 2998.928223, y = -2414.493408, z = 118.472412 }
local edge = { x = 3047.236328, y = -2282.439697, z = 124.460297 }
local dx, dy = edge.x - center.x, edge.y - center.y
DeathmatchKabuki.volumes = {
    { id = "freeroam_arena", shape = "cylinder", center = center, radius = math.sqrt(dx * dx + dy * dy) },
}
local positions = {
    { x = 3007.401367, y = -2423.930664, z = 118.324081 },
    { x = 3007.488281, y = -2401.259033, z = 124.373550 },
    { x = 2983.617676, y = -2388.931885, z = 125.373550 },
    { x = 2994.935791, y = -2400.323486, z = 124.438919 },
    { x = 2978.211670, y = -2379.203857, z = 124.385406 },
    { x = 2990.336914, y = -2366.787598, z = 122.421799 },
    { x = 2987.299805, y = -2351.030762, z = 122.426468 },
    { x = 2983.348633, y = -2359.938965, z = 118.414841 },
    { x = 2978.224365, y = -2383.057373, z = 118.461868 },
    { x = 2960.343506, y = -2383.238281, z = 119.381134 },
    { x = 2959.277100, y = -2396.604980, z = 118.469955 },
    { x = 2958.379639, y = -2405.053711, z = 120.409180 },
    { x = 2962.617920, y = -2365.191162, z = 118.457489 },
    { x = 3037.262207, y = -2396.562012, z = 118.316330 },
    { x = 3058.307373, y = -2407.259277, z = 118.436737 },
    { x = 3030.920898, y = -2426.716797, z = 118.461639 },
    { x = 2987.544434, y = -2446.254883, z = 118.706406 },
}
local marks = {}
for index, position in ipairs(positions) do
    marks[index] = { position = position,
        heading = math.deg(math.atan(position.x - center.x, center.y - position.y)) % 360 }
end
DeathmatchKabuki.spawns.ffa = marks
local teamA, teamB = { marks[10], marks[11], marks[12] }, { marks[14], marks[15], marks[16] }
for _, format in ipairs({ "ffa", "1v1", "2v2", "3v3" }) do
    DeathmatchKabuki.formats[format].volumes = { "freeroam_arena" }
    Config.zones[format].volumes = { "freeroam_arena" }
    Config.zones[format].label = "the arena"
    if format ~= "ffa" then
        local count = tonumber(format:sub(1, 1))
        local teams = { a = {}, b = {} }
        for index = 1, count do teams.a[index], teams.b[index] = teamA[index], teamB[index] end
        DeathmatchKabuki.teams[format] = teams
    end
end
DeathmatchKabuki.set("ffa").limit = #marks

-- ---------------------------------------------------------------------------
-- Player-facing text: short, English, Light RP's voice.

Config.strings.title = "COMBAT ZONE"
local notice = Config.strings.notice
local function say(key, title, body) notice[key] = { title = title, body = body } end
say("joined", "IN THE FIGHT", "You are in. Good hunting.")
say("notReady", "HOLD ON", "Your character is not ready yet.")
say("instancesFull", "FULL", "The arena is full. Try again shortly.")
say("leftMatch", "LEFT THE ARENA", "Heading back to where you were.")
say("placementFailed", "PLACEMENT FAILED", "The arena could not place you. Try again.")
say("roundStart", "FIGHT", "Go.")
say("roundWeapon", "THIS ROUND", "%s for everyone.")
say("roundOver", "ROUND OVER", "%s takes the round.")
say("roundDraw", "DRAW", "No clear winner.")
say("roundWon", "VICTORY", "Top of the board.")
say("nextRound", "NEXT ROUND", "Starts in %d s.")
say("queued", "QUEUED", "Position %d for %s.")
say("queueLeft", "QUEUE", "You left the queue.")
say("queueMatched", "MATCH FOUND", "%s. Moving you now.")
say("buyWindow", "PICK YOUR KIT", "%d s. /arena.kit lists the kits.")
say("eliminated", "ELIMINATED", "Wait for the round to end.")
say("teamWon", "ROUND WON", "%d - %d.")
say("teamLost", "ROUND LOST", "%d - %d.")
say("sidesSwapped", "SIDES SWAPPED", "You switched sides.")
say("matchWon", "MATCH WON", "Heading back to the city.")
say("matchLost", "MATCH LOST", "Heading back to the city.")
say("boundsWarn", "OUT OF BOUNDS", "Back to %s. %d s.")
say("boundsReturned", "OUT OF BOUNDS", "You were put back inside the arena.")
say("lobbyReturned", "OUT OF BOUNDS", "You were sent back.")
say("loadoutFailed", "LOADOUT", "Your arena weapon could not be equipped.")
say("loadoutUnverified", "LOADOUT", "Weapon not verified yet. Your shots stay blocked.")
say("resupplied", "RESUPPLIED", "Ammo restored.")
say("gunsApplied", "LOADOUT", "%s. In your hands now.")
say("gunsNextSpawn", "LOADOUT", "%s. You get it on your next respawn.")
say("gunsReady", "LOADOUT", "%s. You will carry it in the arena.")
say("gunsArenaOnly", "LOADOUT", "%s is your Combat Zone weapon. Team matches use kits.")
say("gunsUnknown", "LOADOUT", "No weapon called \"%s\". /arena.weapon list shows them.")
say("gunsEqualizer", "LOADOUT", "Same weapon for everyone this round.")
say("careerWelcome", "ARENA RECORD", "%d kills, %d deaths (%.2f K/D) over %d rounds.")
say("protectionOn", "SPAWN SHIELD", "%d s of protection.")
say("protectionBroken", "SHIELD DOWN", "You fired. Protection dropped.")
say("pvpUnavailable", "NO PVP", "Player damage is unavailable here right now. /arena.leave to go back.")
Config.strings.hud.killLimit = "FIRST TO %d"
Config.strings.error.notInInstance = "You are not in the arena."
