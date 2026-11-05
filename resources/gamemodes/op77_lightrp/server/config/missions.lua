-- Missions (The Division style): mission points in the city, a board per
-- difficulty where a crew leader tags the crew in (a player alone is a crew of
-- one), a countdown once the crew has the minimum (or, open to matchmaking, once
-- strangers filled the lobby or the host launches), then the mission runs in its
-- own routing bucket.
--
-- The positions here are TEST points near the Little China public garage; the
-- real points come from the server team.
LightRpMissions = {
    enabled = true,
    -- Reputation ("street cred", per character): points earned by PvE only --
    -- missions, the raid, fixer gigs and PvE activities (server/config/activities.lua
    -- `pve`); PvP never grants any. Each threshold opens a tier (tier 1 from the
    -- start), and a tier opens the harder difficulties (`difficultyTiers`) and the
    -- higher cyberware ranks (server/config/cyberware.lua `gating`).
    -- docs/pve-progression.md.
    reputation = {
        tiers = { 0, 500, 1500, 4000, 10000 },
        names = { "Street", "Merc", "Operator", "Edgerunner", "Legend" },
        -- told to the player when the tier is reached
        opens = {
            [2] = "Hard difficulties and rank III cyberware are open to you.",
            [3] = "Critical difficulties and rank IV cyberware are open to you.",
            [4] = "Rank V cyberware is open to you.",
            [5] = "Rank V+ cyberware is open to you.",
        },
        -- The tier a difficulty needs, by difficulty id (a difficulty's own `minTier`
        -- wins). Editor missions carry no tier of their own and follow this too.
        difficultyTiers = { standard = 1, hard = 2, critical = 3 },
        requireTier = true,  -- a difficulty needs its tier...
        requireClear = true, -- ...and the one before it completed at the same point
        -- A crew member the leader brings into a difficulty their own tier (or clears)
        -- do not open is never refused: they play it at full difficulty and earn the
        -- reputation of the highest difficulty they have unlocked. The leader, and a
        -- solo player, are gated as above.
    },
    -- Tagging happens at the point; a crew member must be this close to it
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
    -- What a finished mission (raid and fixer gig included) pays out in
    -- reputation, per difficulty. A crew member below the difficulty (its tier, or
    -- on a board its clear ladder) gets the gain of the highest difficulty they
    -- have unlocked.
    reputationGain = { standard = 100, hard = 220, critical = 450 },
    -- Crews (server/modules/parties.lua): size, invite lifetime, the radius of the
    -- "players around you" lists, the invite range, the distance past which a
    -- member shows FAR on the crew frame, and how often the frame refreshes.
    party = { maxSize = 8, inviteSeconds = 60, nearby = 15.0, inviteRange = 300.0, farRange = 250.0, refreshMs = 2000 },
    -- Ground marker of a mission point.
    marker = { shape = "cylinder", radius = 1.2, height = 0.7,
        color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 60, groundOffset = 0.05 },
    -- `payout` (per difficulty, below) is each operator's share at the difficulty's
    -- `min` crew. A bigger crew grows the pot sub-linearly and splits it, a repeat
    -- within the cooldown or past the daily cap pays a quarter, and the share never
    -- exceeds maxSharePerMinute × minutes: server/config/economy.lua,
    -- server/modules/mission_pay.lua, docs/economy-balance.md.
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
                  payout = 3500, minutes = 25, min = 2, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "Full security roster. Shorter dark window.",
                  payout = 5000, minutes = 30, min = 4, max = 6, tier = 2 },
                { id = "critical", label = "CRITICAL", blurb = "Corporate response team on standby. No respawns.",
                  payout = 9000, minutes = 45, min = 6, max = 8, tier = 3 },
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
                  payout = 3000, minutes = 20, min = 1, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "Full combat output, heavier reinforcements, slower respawns.",
                  payout = 4500, minutes = 25, min = 2, max = 6, tier = 2 },
                { id = "critical", label = "CRITICAL", blurb = "Overclocked core and a Militech response team. No respawns.",
                  payout = 6000, minutes = 30, min = 4, max = 8, tier = 3 },
            },
        },
        -- ASSAULT: Titan Assault (op77_lightrp_titans), two to four pilots in BT-7274 Titans against ten waves
        -- in the open desert of Rattlesnake Creek (Badlands), about 130 m north of the road by the abandoned fuel
        -- station: scrub and cacti, no road, no building. Its script is server/modules/mission_titan.lua, which keeps
        -- the point off the board while the Titan resource is not running. The board stands 5 m east-south-east of
        -- the Sector 04 Blackout board (same plane, z carried over: check it in game). Titans need about 12 m
        -- between them; the four start heights were measured in game (2026-11-04) by standing on each spot.
        {
            id = "titan_assault",
            title = "Titan Assault",
            type = "ASSAULT",
            location = "BADLANDS // RATTLESNAKE CREEK",
            description = "The Barghest are rolling a whole army across the Rattlesnake Creek desert. You get a BT-7274 Titan each. Pick a class, hold the ground for ten waves.",
            position = { x = -633.3, y = -388.7, z = 8.19 },
            -- the middle of the four Titans; the pilots' client reports from within `loadRadius` of it
            arena = { x = -1121.0, y = -5450.0, z = 86.2 },
            start = {
                { x = -1108.0, y = -5450.0, z = 87.0, heading = 0 },
                { x = -1121.0, y = -5436.0, z = 85.1, heading = 0 },
                { x = -1134.0, y = -5450.0, z = 86.1, heading = 0 },
                { x = -1121.0, y = -5463.0, z = 86.6, heading = 0 },
            },
            difficulties = {
                { id = "standard", label = "STANDARD", blurb = "Ten waves from every side. Pick a Titan class, kills charge your core.",
                  payout = 3000, minutes = 25, min = 2, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "The whole army: twice the hostiles of STANDARD in every wave.",
                  payout = 4500, minutes = 25, min = 2, max = 4, tier = 2 },
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

-- Titan Assault (server/modules/mission_titan.lua): the crew arrives in BT-7274 Titans, picks a class, then
-- fights ten waves. Everything the script tunes is here; the Titan resource's side of the contract
-- (spawn / setHold / setClass / creditKill) is documented in docs/titan-assault.md.
LightRpTitanAssault = {
    -- The Titan service. A soft dependency: the point is on the board only while it runs.
    resource = "op77_lightrp_titans",
    point = "titan_assault",
    difficulty = "standard", -- the staff command's default (/titan.assault)
    loadRadius = 90,       -- metres from the arena where a client's "arrived" report is believed
    arriveSeconds = 120,   -- how long the run waits for every pilot's Titan; whoever has none by then is sent home
    spawnRetries = 5,      -- refused Titan spawns tried again (every `retryMs`) before the pilot is sent home
    applyRetries = 8,      -- the same for the class and the release of the hold
    retryMs = 2000,
    pickSeconds = 60,      -- the class picker; whoever picked nothing gets `defaultClass`
    defaultClass = "vanguard",
    countdownSeconds = 5,  -- from the classes applied to wave 1
    intermissionSeconds = 8,
    respawnSeconds = 12,   -- a pilot who went down in a wave comes back in a new Titan after this long
    respawnEarlySeconds = 3, -- ... and before the first wave (no cost)
    victorySeconds = 8,
    wipeSeconds = 6,
    -- The Titan starts with the fists only: no weapon to fire before the class is applied.
    fistsOnly = { xo16 = 0, railgun = 0, predator = 0, sword = 0, fist = 1 },

    -- Wave n with p pilots: base + perWave * (n - 1) + max(0, p - 2) * (perExtraPilot + floor(n / extraEvery)), times the
    -- difficulty's `enemyScale`; so is `maxAlive`, the hostiles alive at once (the rest comes in as others die).
    waves = { count = 10, base = 4, perWave = 2, perExtraPilot = 1, extraEvery = 3 },
    maxAlive = 16,
    enemyScale = { standard = 5, hard = 10 },
    -- The damage a Titan takes while it wears its class, as a multiple of what its controller would take (the class's `harm`, 0.1
    -- to 50), and how many times slower its shield comes back (the class's `regen`, 0.25 to 10: the controller waits 6 s after a
    -- hit, less with the armor perk, then refills the 1 000 points in 2 s). At 1 and 1 a solo pilot never went down; at 5 the
    -- shield still never let a hit through to the hull, and the owner finished STANDARD solo with several classes at 12 (owner's
    -- play, 2026-11-04): doubled the same day, now that the Titan resource accepts up to 50. Not measured: to be tuned after play.
    incoming = { standard = 24, hard = 36 },
    shieldRegen = { standard = 2.5, hard = 3 },

    -- Hostiles: the Chimera raid's reinforcement types (LightRpRaid.addPool), tried in a random order, the first
    -- record the engine accepts is used. They drop in on a ring around the pilots' centroid, at least `clear` metres from
    -- every standing pilot, on the ground a pilot's client finds (client/core/titan_mission.lua).
    pool = {
        { record = "Character.max_border_guards" }, { record = "Character.max_border_guards_shotgun" },
        { template = "gang_valentinos_ranged_01" }, { template = "hostile_female_ranged_lab" },
    },
    ring = { min = 90, max = 140, clear = 80 },
    -- The last hostiles of a wave are marked: below `below` left (alive and still to come), every pilot is sent where each
    -- living one is every `everyMs`, and their client hangs an arrow above it (client/core/titan_mission.lua).
    marks = { below = 10, everyMs = 250 },
    spawnFailures = 10,    -- batches in a row without one hostile created (every record refused) before the run is called off
    group = "op77_lightrp_titan_assault", -- a combat group of their own: the hostiles of Titan Assault runs
    spawnLift = 0.4,       -- metres above the probed ground
    -- Hostiles found under the ground: during a wave, every `everyMs` a pilot's client is asked for the ground under up to `max`
    -- living hostiles (the same probe as the spawn points); one more than `depth` metres below it is put back on it (`spawnLift`
    -- above), and logged. Their spawn points were measured right (2026-11-04), yet the owner saw one in the ground: this both
    -- fixes it and says where and when it happens. `depth` is above the 0.7 m the bodies sat under their probed point once
    -- adopted, after a 5 m walk (2026-11-04), and below the shoulder-deep one the owner saw; each wave logs the deepest it measured.
    -- One more than `above` metres over its ground, and within `still` metres of where the previous check of it found it, hangs in
    -- the air and is put down on it: a thrown body that came to rest up there (every full-power throw of 2026-11-04 ended 70 to
    -- 140 m up, alive) and stood up. A body still in flight moves between two checks. `reach`: how far above and under each
    -- hostile its client looks for the ground (the Titan resource's `ground` export allows 200). The checks go round the living
    -- hostiles, `max` at a time.
    sink = { everyMs = 3000, depth = 1.0, above = 4.0, still = 1.0, reach = 200, max = 16 },
    -- the ground probe: candidate points per hostile still to come (at most `max` per request), how long a client
    -- gets to answer, and how many empty or missing answers in a row make the wave drop on the pilots' own height
    probe = { perHostile = 2, max = 24, timeoutMs = 4000, failuresBeforeFallback = 3, heightTolerance = 40 },
    -- Core charge per kill (the controller's own values, FPC.perk.core.kill: grunt 5, rare 7, heavy 10), by what the NPC was
    -- created from. A charge is 75 points: every hostile here is a grunt (5 points), so a charge takes 15 kills. Anything not
    -- listed counts as a grunt too; the rare and heavy values are not used by this mission.
    ranks = {
        ["Character.max_border_guards"] = "grunt", ["Character.max_border_guards_shotgun"] = "grunt",
        gang_valentinos_ranged_01 = "grunt", hostile_female_ranged_lab = "grunt",
    },

    -- Hits on hostiles. They are created with hitPricing "resource": the platform prices nothing and each pilot's own Titan
    -- reports the blows its weapons land on them (the Titan resource's onTitanNpcHit, only from a piloted Titan that is not
    -- held). What a blow is comes from its attack record (`records`), never from the report's own kind: a record not listed
    -- has no price, and each listed record is priced only for the class weapon (`weapon`) or class ability (`ability`) that
    -- fires it, at `times` (1 to 10, a record's price multiple: the Berserker Core's punches pay 3 times a punch). The server
    -- prices a blow by ITS record of the pilot's class, in percent of the hostile's maximum health,
    -- within `perSecond` percent per pilot per second (a pilot's burst never exceeds it), for hostiles within `range` metres
    -- of the pilot's Titan. A death the platform reports as "native" (a missile's area attack resolved by the simulating
    -- client) counts for the pilot whose blow landed on that hostile in the last `nativeCreditSeconds`, never for the
    -- simulator. A native death with no such blow yet waits `nativeGraceSeconds` for the first blow of a pilot of the run on
    -- that hostile that passes every check a blow on a living hostile passes (the blast's own report can reach the server
    -- after the death).
    --   perHit  the class weapon's own blow: a round of the XO-16 / Predator / Railgun, the Sword's blade, the fists' punch
    --           (a punch is worth that whatever the class: melee is never locked). The XO-16 fires 12 to 17 rounds a
    --           second (the controller reports at most 20 a second on one hostile): 4 percent a round is a grunt in about
    --           two seconds of sustained fire; the Predator (15 to 20) kills in about one.
    --   blast   a hit of an explosion (a missile, a flight strike rocket, a ground pound), per class weapon: four direct
    --           ones kill a grunt
    --   other   the rest (the vortex shield's throw-back, the electric smoke, the missiles' gas)
    hits = { range = 150, perSecond = 240, nativeCreditSeconds = 5, nativeGraceSeconds = 1.5,
        perHit = { xo16 = 4, pred = 6, rail = 100, sword = 60, fist = 45 },
        blast = { xo16 = 25, pred = 25, rail = 25, sword = 25, fist = 25 },
        other = 4,
        records = {
            ["Attacks.BT7274_XO16_Hit"] = { kind = "round", weapon = "xo16" },
            ["Attacks.BT7274_Pred_Hit"] = { kind = "round", weapon = "pred" },
            ["Attacks.BT7274_Rail_1"] = { kind = "round", weapon = "rail" },
            ["Attacks.BT7274_Rail_2"] = { kind = "round", weapon = "rail" },
            ["Attacks.BT7274_Rail_3"] = { kind = "round", weapon = "rail" },
            ["Attacks.BT7274_Rail_4"] = { kind = "round", weapon = "rail" },
            ["Attacks.BT7274_Missile"] = { kind = "blast", ability = "missiles" },
            ["Attacks.BT7274_MissileBlast"] = { kind = "blast", ability = "missiles" },
            ["Attacks.BT7274_Gas"] = { kind = "other", ability = "missiles" },
            ["Attacks.BT7274_FlightRocket"] = { kind = "blast", ability = "flight" },
            ["Attacks.BT7274_FlightBlast"] = { kind = "blast", ability = "flight" },
            ["Attacks.BT7274_Pound_Mid"] = { kind = "blast", ability = "jets" },
            ["Attacks.BT7274_Pound_Edge"] = { kind = "blast", ability = "jets" },
            ["Attacks.BT7274_Fist_Blast"] = { kind = "blast", weapon = "fist" },
            ["Attacks.BT7274_Punch"] = { kind = "melee" },
            ["Attacks.BT7274_Fist"] = { kind = "melee", weapon = "fist" },
            ["Attacks.BT7274_Fist_Heavy"] = { kind = "melee", weapon = "fist" },
            ["Attacks.BT7274_Fist_Charged"] = { kind = "melee", weapon = "fist" },
            ["Attacks.BT7274_Fist_Core"] = { kind = "melee", weapon = "fist", times = 3 },
            ["Attacks.BT7274_Sword"] = { kind = "blade", weapon = "sword" },
            ["Attacks.BT7274_Sword_Charged"] = { kind = "blade", weapon = "sword" },
            ["Attacks.BT7274_Sword_Core"] = { kind = "blade", weapon = "sword" },
            ["Attacks.BT7274_ArcWave"] = { kind = "blade", weapon = "sword" },
            ["Attacks.BT7274_Smoke"] = { kind = "other", ability = "smoke" },
            ["Attacks.BT7274_Vortex"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x2"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x4"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x8"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x16"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x32"] = { kind = "other", ability = "vortex" },
            ["Attacks.BT7274_Vortex_x64"] = { kind = "other", ability = "vortex" },
        } },

    -- The five classes. `perks`: a sparse Titan loadout laid over the Titan resource's defaults; `abilities`: the
    -- abilities the engine lets this class use (a missing key is locked); `speed`: walk and run multiplier. The
    -- other fields are the picker's. `core` names the class's core for the picker only; `ultimate` is the line it shows on the
    -- card, saying what the core does; `labels` renames abilities for the picker
    -- (the Titan controller turns a fists class's vortex into the ARC FIELD and a designator class's designator into the BARRAGE).
    classes = {
        { id = "vanguard", label = "Vanguard", weapon = "xo16", weaponLabel = "XO-16", core = "Burst Core", speed = 1.0,
          ultimate = "BURST CORE · 7.5 s: unlimited ammo, the XO-16 fires 3x faster.",
          perks = { xoammo = 2, xodamage = 2, xoreload = 2 },
          abilities = { missiles = true, vortex = true, jets = true, core = true } },
        { id = "ronin", label = "Ronin", weapon = "sword", weaponLabel = "Sword", core = "Sword Core", speed = 1.2,
          ultimate = "SWORD CORE · 7.5 s: swings 3x faster, +2 m reach, the Arc Wave recharges 3x faster, one more dash.",
          perks = { airdash = 1, dashregen = 3, dashcap = 2, dashdist = 2, skate = 3, sworddamage = 2, swordspeed = 2, swordreach = 2 },
          abilities = { dash = true, smoke = true, core = true } },
        { id = "northstar", label = "Northstar", weapon = "rail", weaponLabel = "Railgun", core = "Burst Core", labels = { designator = "Barrage" },
          speed = 1.0,
          ultimate = "FLIGHT STRIKE · BT rises and fires rockets for 6 s.",
          perks = { jumpgauge = 1, jumpcharge = 2, jumpcap = 2, railcap = 2, railcharge = 2, raildamage = 2, flight = 1, designator = 1 },
          abilities = { jets = true, flight = true, designator = true, core = true } },
        { id = "legion", label = "Legion", weapon = "pred", weaponLabel = "Predator Cannon", core = "Burst Core", speed = 0.85,
          ultimate = "BURST CORE · 7.5 s: unlimited ammo, the Predator fires 3x faster.",
          perks = { sentry = 1, hull = 3, armor = 3, blastres = 3, predcap = 2, predspin = 2, preddamage = 2 },
          abilities = { sentry = true, vortex = true, smoke = true, core = true } },
        { id = "brawler", label = "Brawler", weapon = "fist", weaponLabel = "Fists", core = "Berserker Core", labels = { vortex = "Arc Field" },
          speed = 1.0,
          ultimate = "BERSERKER CORE · 7.5 s: punches hit 3x harder and send enemies flying (bosses stand), a shockwave on every punch, half the damage taken.",
          perks = { fistdamage = 2, fistarmor = 2, fiststun = 2, vortexthrow = 2 },
          abilities = { jets = true, dash = true, vortex = true, core = true } },
    },
}
