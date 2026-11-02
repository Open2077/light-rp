-- Missions (The Division style): mission points in the city, a board per
-- difficulty where players tag in alone or with their squad, matchmaking that
-- fills the lobby, a countdown once it is full (or when the host launches with
-- the minimum), then the mission runs in its own routing bucket.
--
-- The positions here are TEST points near the Little China public garage; the
-- real points come from the server team.
LightRpMissions = {
    enabled = true,
    -- Reputation: points earned by finishing missions, and the tier each
    -- threshold opens (tier 1 from the start).
    reputation = { tiers = { 0, 500, 1500 } },
    -- Tagging happens at the point; a squad member must be this close to it
    -- for the leader to tag them along. Wandering past `leash` untags you.
    tagRadius = 6.0,
    groupRadius = 30.0,
    leash = 60.0,
    -- Seconds between full (or the host's launch) and the start, and how
    -- often a player may tag / untag (per player).
    countdown = 15,
    hostCountdown = 10,
    tagCooldownMs = 1500,
    -- One routing bucket per running mission: base + instance number.
    bucketBase = 3000000,
    -- What a finished mission pays out in reputation, per difficulty.
    reputationGain = { standard = 100, hard = 220, critical = 450 },
    -- Squads (parties).
    -- `nearby`: the players listed to invite at a mission point; `inviteRange`:
    -- how far an invite by command reaches.
    party = { maxSize = 8, inviteSeconds = 60, nearby = 15.0, inviteRange = 300.0 },
    -- Ground marker of a mission point.
    marker = { shape = "cylinder", radius = 1.2, height = 0.7,
        color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 60, groundOffset = 0.05 },
    points = {
        {
            id = "sector04_blackout",
            title = "Sector 04 Blackout",
            type = "HEIST",
            location = "SECTOR 04 // SUBSTATION C",
            description = "Cut district power and hit the depository inside the dark window. Pick the tier, then tag in on its board.",
            position = { x = -637.6, y = -386.2, z = 8.19 },
            -- where the operators arrive in the instance (one spot each, in turn)
            start = {
                { x = -637.6, y = -386.2, z = 8.19, heading = 143.6 },
                { x = -636.4, y = -386.9, z = 8.19, heading = 143.6 },
                { x = -638.8, y = -385.5, z = 8.19, heading = 143.6 },
                { x = -635.2, y = -387.6, z = 8.19, heading = 143.6 },
            },
            difficulties = {
                { id = "standard", label = "STANDARD", blurb = "Reduced security. Grid stays half-lit.",
                  payout = 12000, minutes = 25, min = 2, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "Full security roster. Shorter dark window.",
                  payout = 22500, minutes = 30, min = 4, max = 6, tier = 2 },
                { id = "critical", label = "CRITICAL", blurb = "Corporate response team on standby. No respawns.",
                  payout = 40000, minutes = 45, min = 6, max = 8, tier = 3 },
            },
        },
        -- RAID: the Chimera (open77_chimera, Open2077/open77-base#105) in the Dogtown
        -- arena. Its script is server/modules/mission_chimera.lua.
        {
            id = "chimera_raid",
            title = "Chimera Protocol",
            type = "RAID",
            location = "DOGTOWN // THE ARENA",
            description = "Militech lost a Chimera war machine to the Barghest. It is parked in the Dogtown arena, live and angry. Get in, take it apart, get paid.",
            position = { x = -1965.756348, y = -2503.357178, z = 28.842484 },
            -- the arena: where the operators arrive (spread around it) and the boss is placed from
            arena = { x = -2044.428345, y = -2406.194336, z = -7.408905 },
            -- where the Chimera stands (faces the operators' spawn)
            boss = { x = -2046.989014, y = -2406.781006, z = -7.365234 },
            start = {
                { x = -2044.43, y = -2406.19, z = -7.41, heading = 0 },
                { x = -2043.23, y = -2406.19, z = -7.41, heading = 0 },
                { x = -2045.63, y = -2406.19, z = -7.41, heading = 0 },
                { x = -2044.43, y = -2407.39, z = -7.41, heading = 0 },
                { x = -2043.23, y = -2407.39, z = -7.41, heading = 0 },
                { x = -2045.63, y = -2407.39, z = -7.41, heading = 0 },
                { x = -2044.43, y = -2405.0, z = -7.41, heading = 0 },
                { x = -2042.03, y = -2406.19, z = -7.41, heading = 0 },
            },
            difficulties = {
                { id = "standard", label = "STANDARD", blurb = "Chimera on reduced output. Militech sends a handful of grunts.",
                  payout = 18000, minutes = 20, min = 1, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "Full combat output, heavier reinforcements, slower respawns.",
                  payout = 34000, minutes = 25, min = 2, max = 6, tier = 2 },
                { id = "critical", label = "CRITICAL", blurb = "Overclocked core and a Militech response team. No respawns.",
                  payout = 60000, minutes = 30, min = 4, max = 8, tier = 3 },
            },
        },
    },
}

-- The Chimera raid: ready check, intro, the fight and how it scales.
LightRpRaid = {
    readySeconds = 45,     -- the ready check closes after this; whoever is in the arena goes
    loadWaitSeconds = 120, -- ...but it waits (up to this long) for every operator to finish loading the arena
    loadRadius = 90,       -- metres from the arena where a client's "loaded" report is believed
    launchSeconds = 5,     -- "ENGAGING IN 5" once everyone is ready
    introSeconds = 12,     -- the cinematic (client/core/raid.lua); the boss is passive meanwhile
    victorySeconds = 10,   -- the arena stays open after the kill, then everyone goes home
    -- Per difficulty. health: Chimera's health multiplier (incoming damage is divided by it),
    -- plus `healthPerOperator` for every operator past the first; damage: its outgoing damage.
    -- respawnSeconds false = no respawn (dead operators wait for the end); lives = team respawns.
    -- waves: reinforcements at these health thresholds (percent), `adds` + `addsPerOperator` each.
    -- enrageMinutes: after this long in the fight the core overclocks (damage x enrageDamage).
    scaling = {
        standard = { health = 1.0, healthPerOperator = 0.45, damage = 0.8, respawnSeconds = 8, lives = 99,
            waves = { 75, 40 }, adds = 2, addsPerOperator = 1, enrageMinutes = 12, enrageDamage = 1.5 },
        hard = { health = 1.8, healthPerOperator = 0.6, damage = 1.1, respawnSeconds = 18, lives = 6,
            waves = { 85, 60, 35, 15 }, adds = 3, addsPerOperator = 1, enrageMinutes = 10, enrageDamage = 1.6 },
        critical = { health = 3.0, healthPerOperator = 0.75, damage = 1.5, respawnSeconds = false, lives = 0,
            waves = { 90, 70, 50, 30, 10 }, adds = 4, addsPerOperator = 2, enrageMinutes = 8, enrageDamage = 1.8 },
    },
    maxAdds = 14,          -- reinforcements alive at once, whatever the scaling says
    -- Militech reinforcements: tried in order, the first record the engine accepts is used.
    addPool = {
        { record = "Character.max_border_guards" }, { record = "Character.max_border_guards_shotgun" },
        { template = "gang_valentinos_ranged_01" }, { template = "hostile_female_ranged_lab" },
    },
    addRing = { min = 10, max = 18 }, -- metres from the boss where reinforcements drop in

    -- Scripted attacks between the machine's own (its native cadence is slow).
    -- Every interval is in seconds and shrinks in the later phases and when enraged.
    -- barrage: rockets on every standing operator (+ `extra` random spots near them),
    -- telegraphed on the ground (3D markers + the game's missile indicator, client/core/raid.lua).
    -- purge: an EMP discharge around the boss when someone hugs it.
    -- vfx: the replicated blast (game effects, same names as Open77.effects.explosion takes).
    barrage = { radius = 4.5, telegraphMs = 2200, every = { standard = 13, hard = 10, critical = 7 },
        damage = { standard = 22, hard = 35, critical = 55 }, extra = { standard = 0, hard = 1, critical = 2 }, scatter = 6,
        vfx = "base\\fx\\quest\\q114\\q114_missile_barage_explosion.effect" },
    purge = { radius = 7.5, telegraphMs = 1600, every = 12, trigger = 8,
        damage = { standard = 25, hard = 40, critical = 60 }, vfx = "cyber.emp_blast" },
    -- Game effects played in the arena for everyone (server one-shots / loops): the
    -- machine's phase changes, the overclock aura, the reinforcement drop flares, its death.
    fx = {
        phase = { "cyber.emp_blast", "sparks.burst.large" },
        enraged = "electric.emp",
        drop = "race.flare.smoke", dropSeconds = 7,
        death = { "explosion.turret", "sparks.burst.large" }, wreck = { "smoke.column.black", "fire.medium" },
    },
    pace = { armored = 1.0, exposed = 0.85, gas = 0.75, core = 0.6, enraged = 0.7 },
    -- Under 70% the Chimera stops to repair its armor and takes no damage meanwhile
    -- (open77_chimera holds it 60 s). The raid cuts that short to these seconds.
    repairSeconds = { standard = 15, hard = 25, critical = 35 },
    -- The Chimera's body shrugs off bullets: only its 17 weak points cost it health
    -- (open77_chimera), and a broken one never again. Once the legs are stripped
    -- there is little left to hit, so every confirmed hit on the body also costs it
    -- `perHit` percent of its health for the shooter's kit (a shotgun pellet is a
    -- hit), at most `perSecond` percent per operator per second, `armored` times
    -- that while its armor holds, nothing while it repairs. Divided by the health
    -- multiplier like any damage. Weak points stay the fast way.
    bodyHits = { perHit = { assault = 0.06, breacher = 0.07, marksman = 0.6, gunner = 0.045, tech = 0.35 },
        perSecond = 0.6, armored = 0.35, range = 90 },

    -- Resupply: every `every` seconds of the fight, a kit weapon whose reserve fell under
    -- `below` of its kit reserve is topped back up; each reinforcement wave tops everyone up.
    resupply = { every = 25, below = 0.5 },

    -- Picked in the ready check (default: the first one). Handed out in the arena
    -- and again on every respawn; the character's own weapons come back afterwards.
    loadouts = {
        { id = "assault", label = "ASSAULT", blurb = "Militech Ajax rifle and a Lexington sidearm. Reliable at every range.",
          primary = "Items.Preset_Ajax_Default", secondary = "Items.Preset_Lexington_Default", reserve = { 360, 120 },
          names = { "Militech Ajax", "Militech Lexington" } },
        { id = "breacher", label = "BREACHER", blurb = "Carnage shotgun and an Unity. Get close, hit its weak spots hard.",
          primary = "Items.Preset_Carnage_Default", secondary = "Items.Preset_Unity_Default", reserve = { 120, 120 },
          names = { "Budget Arms Carnage", "Constitutional Arms Unity" } },
        { id = "marksman", label = "MARKSMAN", blurb = "Grad precision rifle and a Nue. Pick the parts off from cover.",
          primary = "Items.Preset_Grad_Default", secondary = "Items.Preset_Nue_Default", reserve = { 100, 120 },
          names = { "Tsunami Grad", "Tsunami Nue" } },
        { id = "gunner", label = "GUNNER", blurb = "Defender light machine gun and a Lexington. Suppress the reinforcements.",
          primary = "Items.Preset_Defender_Default", secondary = "Items.Preset_Lexington_Default", reserve = { 400, 120 },
          names = { "Darra Polytechnic Defender", "Militech Lexington" } },
        { id = "tech", label = "TECH", blurb = "Achilles tech rifle and a Copperhead. Charged shots through its plating.",
          primary = "Items.Preset_Achilles_Default", secondary = "Items.Preset_Copperhead_Default", reserve = { 120, 300 },
          names = { "Militech Achilles", "Arasaka Copperhead" } },
    },

    -- The fight's music (client side, looped, low): Gate K9, Phantom Liberty OST.
    -- It starts with the intro cinematic. The client scales it by the game's
    -- Master and Music sliders (client/core/raid.lua): this is the level at 100/100.
    music = { file = "assets/audio/raid_ost.mp3", volume = 0.35 },
}
