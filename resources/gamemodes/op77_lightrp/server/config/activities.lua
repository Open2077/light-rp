-- Activities (server/modules/activities.lua) and their hub, The Crossing
-- (server/modules/activities_hub.lua). Server only: nothing here is downloaded.
--
-- Activity providers (op77_arena, op77_race, op77_chase, op77_turf...) run
-- their own instances in their own routing buckets:
--   arena 4100000-4199999 · race 4200000-4299999 · chase 4300000-4399999 · turf 4400000-4499999
-- (city 0, arrival hall 620000, tutorial practice 700000+id, fitting rooms
-- 710000+id, dwellings 1000000+id, missions 3000000+n).
LightRpActivities = {
    enabled = true,
    -- The providers' bucket ranges. Vehicles there are the activity's own: no RP
    -- fuel burns in them (server/modules/fuel.lua).
    buckets = { { 4100000, 4199999 }, { 4200000, 4299999 }, { 4300000, 4399999 }, { 4400000, 4499999 } },

    -- Eligibility: no activity within this long of taking damage.
    damageCooldownMs = 60000,
    -- A leave request (panel, /leave) the provider has not answered with
    -- activityLeave within this long: the core releases and returns the player.
    leaveTimeoutMs = 15000,
    -- A result may arrive after activityLeave, up to this long (one per entry).
    resultGraceMs = 10 * 60000,
    -- Pushes of the `activities` state after a provider status, at most this often.
    statusPushMs = 2000,
    -- A player who opened the panel keeps receiving live updates this long.
    watchMs = 5 * 60000,
    -- Players listed for a squad invite in the panel.
    nearbyRange = 15.0,
    nearbyMax = 8,

    -- Reputation granted by results: PvE activities only (`pve` below); PvP, races,
    -- chases and events record stats and leaderboards, never reputation. Capped to
    -- dailyCap per account (all its characters) per UTC day. `grantTo = "missions"`
    -- adds it to the street reputation whose tiers open the harder difficulties and
    -- cyberware (server/modules/missions.lua); nil keeps it in the activity tables.
    -- `pvpGrants = true` brings the old rule back (every kind granted, clamped to
    -- maxPerResult). docs/pve-progression.md. Eddies: server/modules/activity_pay.lua
    -- (economy.lua `activities`); never items.
    reputation = { maxPerResult = 50, dailyCap = 500, grantTo = "missions", pvpGrants = false },

    -- PvE activities (players against bots). A provider marks its activity with
    -- `pve = true` in activityRegister and lists the difficulties it really plays
    -- (`difficulties = { "standard", "hard", "critical" }`); without the flag, an id
    -- listed in `activities` here counts as PvE (`pve = false` wins over the list).
    -- The core refuses a difficulty above the reputation tier of a solo player or a
    -- crew leader (a crew member below the leader's pick plays it, and their result
    -- counts at the highest difficulty their tier opens) and hands the
    -- provider options.difficulty and options.scaling (the provider translates it
    -- into bots, health, damage and AI). Reputation per result: the difficulty's
    -- `reputation` x the activity's `weight` (a long run weighs more), the full
    -- amount for a win when the provider sends none, never more than that.
    pve = {
        difficulties = {
            { id = "standard", label = "Standard", minTier = 1, reputation = 30,
              scaling = { enemies = 1, health = 1, damage = 1, ai = "standard" } },
            { id = "hard", label = "Hard", minTier = 2, reputation = 60,
              scaling = { enemies = 1.5, health = 1.5, damage = 1.25, ai = "veteran" } },
            { id = "critical", label = "Critical", minTier = 3, reputation = 100,
              scaling = { enemies = 2, health = 2.25, damage = 1.6, ai = "veteran" } },
        },
        activities = {
            ["arena.pve"] = { weight = 1.0 }, -- Combat Zone · PvE, ~10 min rounds
            ["race.pve"] = { weight = 0.5 },  -- Street Race vs AI, 2-5 min
            ["turf.pve"] = { weight = 1.2 },  -- Gang Sweep, ~15 min
            ["chase.pve"] = { weight = 0.6 }, -- NCPD Escape, 3-6 min
        },
    },

    -- The lobby (server/modules/activities.lua, "Lobby"): bots chosen in the panel,
    -- the ranked search and friendly crew matches. RANKED = the result counts (stats,
    -- leaderboards, Hall of Fame, reputation, pay): a PvP join with humans only, and
    -- every PvE join (allied bots included). UNRANKED = a friendly crew match, any bot
    -- fill in PvP, staff bot mode: the core records nothing and pays nothing.
    lobby = {
        -- A ranked search (a PvP join without bots) offers its leader "fill the rest
        -- with bots (unranked)" after this long; they may also keep waiting.
        fillAfterMs = 120000,
        -- The core's ranked queue (activities with `queue = true` below): searchers (a
        -- crew stays whole, on one side) are matched by team size and, since cyberware
        -- stays active in ranked PvP, by the cyberware rank their street cred unlocks
        -- (server/config/cyberware.lua gating.byRank; a crew counts its highest member).
        matchmaking = {
            -- unlocked cyberware rank -> bracket (ranks 1-2 open at tier I, 6 at tier V)
            brackets = { [1] = 1, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5 },
            -- How far apart the brackets of one match may be, by the wait of its oldest
            -- searcher: one bracket or two adjacent ones first, then wider, then
            -- everyone (spread "all") -- well before the bot fill offer.
            widen = {
                { afterMs = 0, spread = 1 },
                { afterMs = 60000, spread = 2 },
                { afterMs = 80000, spread = 3 },
                { afterMs = 100000, spread = "all" },
            },
            -- A free-for-all (races, Most Wanted): once enough searchers fit, wait this
            -- long for more before starting (a full lobby starts at once).
            gatherMs = 15000,
        },
        -- Per activity (an unlisted one joins as before: ranked, no bots, no friendly):
        --   allies = true   PvE: "Fill empty slots with bots", allied bots up to
        --                   `seats` (default: the activity's maxPlayers) beside the crew.
        --   bots = true     PvP: "Play with bots" up front, and the fill offer of a
        --                   ranked search: a match the core forms, always unranked.
        --                   Both also need the provider's own `botFill = true` in
        --                   activityRegister (a mode may opt out): no declaration, no bots.
        --   friendly = true PvP: a crew leader starts a friendly inside the crew.
        --   teams, teamSize the match shape: two sides of teamSize (or one size per
        --                   mode); `teams` without teamSize splits in two halves (turf
        --                   war); neither: a free-for-all.
        --   fillTo          a free-for-all (or split) bot match: bodies to reach.
        --   queue = true    PvP: the ranked search is the core's queue (matchmaking
        --                   above); without it the provider's own queue takes it.
        --   brackets = false  that queue ignores the cyberware brackets (races).
        activities = {
            ["arena.ffa"] = { bots = true, friendly = true, fillTo = 6 },   -- drop-in: ranked = no bots
            ["arena.blade"] = { bots = true, friendly = true, fillTo = 6 }, -- drop-in
            ["arena.duel"] = { bots = true, friendly = true, queue = true, teams = 2, teamSize = 1 },
            ["arena.teams"] = { bots = true, friendly = true, queue = true, teams = 2, teamSize = { ["2v2"] = 2, ["3v3"] = 3 } },
            ["arena.pve"] = { allies = true },
            ["race.grid"] = { bots = true, friendly = true, queue = true, brackets = false, fillTo = 6 },
            ["race.foot"] = { bots = true, friendly = true, queue = true, brackets = false, fillTo = 6 },
            -- op77_chase is not listed: its modes are real players only or the game's own
            -- NCPD (owner, 2026-11-03), and it plays no core match yet. List a chase
            -- mode here once the provider takes options.match / declares botFill.
            -- ranked turf war stays the provider's own queue (a gang war, one at a time)
            ["turf.war"] = { bots = true, friendly = true, teams = 2, fillTo = 6 },
            ["turf.pve"] = { allies = true },
        },
    },

    -- Choices the Activities panel offers when joining an activity whose provider
    -- declares none (`modes` in activityRegister). The pick is handed to the
    -- provider as options[key]; "Any" sends nothing (the provider's default).
    joinChoices = {
        ["chase.1v1"] = { key = "mode", modes = { { id = "vehicle", label = "By car" }, { id = "foot", label = "On foot" } } },
    },

    -- Leaderboards: top N per activity. Races rank by best time, every other
    -- kind by wins (then best score).
    leaderboard = { size = 5, refreshMs = 60000, byTime = { race = true } },

    hub = {
        name = "The Crossing",
        -- The Westbrook esplanade where the first day guide leaves newcomers
        -- (LightRpConfig.spawn.afterTutorial), about 115 m from the Kabuki
        -- starter studio's door.
        center = { x = -756.581, y = 777.257, z = 22.454 },
        heading = 52.6,
        bucket = 0,
        interactRadius = 2.0,
        marker = { shape = "cylinder", radius = 0.9, height = 0.65,
            color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 40, groundOffset = 0.05 },
        -- Terminals around the arrival point. `offset` is in metres from the
        -- center, along its heading (forward) and to its right; `position`
        -- (absolute, from /lightrp.survey) replaces the offset once surveyed.
        -- One terminal: the panel has the Contracts tab (a `kind = "contracts"`
        -- terminal would open the same panel on that tab). `npc = true`: the `host`
        -- below stands there facing `heading`, in place of the floor marker.
        -- Surveyed by the owner in game, 2026-11-03: where he stood, facing where he
        -- looked (his client's yaw -93.5, i.e. 266.5). Moved by him the same night:
        -- yaw -119.036 (quaternion z 0.8618, w -0.5073), i.e. 240.96.
        terminals = {
            { id = "board", kind = "activities", label = "Adam Smasher",
                prompt = "Open activities & contracts", offset = { forward = 5.0, right = 0.0 },
                position = { x = -783.885, y = 787.366, z = 22.580 }, heading = 240.96, npc = true },
        },
        -- Who stands at a terminal with `npc = true` (the owner's call, 2026-11-03: "something
        -- badass"). Records tried in order (Open77.npcs.create): the boss record, the
        -- generic Smasher, then a MaxTac heavy if the boss body is refused. Like Johnny
        -- (server/modules/guide.lua): AI off, invulnerable, no combat, perception or voice.
        host = {
            name = "Adam Smasher",
            candidates = {
                { record = "Character.main_boss_adam_smasher" },
                { record = "Character.Smasher" },
                { record = "Character.maxtac_rifle_ma_elite" },
            },
            streamingRadius = 150.0,
            promptHeight = 1.4,   -- he is 2.5 m tall: the E prompt at his chest
        },
        -- The map pin (game map + op77_map3d) on the activities terminal.
        blip = { title = "Activities", description = "The Crossing · arena, races, chases, events",
            mapCategory = "mission", mapColor = "#FFCC00", map = "crossing" },
        -- The safe zone staff should draw over the esplanade (/admin > Safe zones);
        -- it cannot be seeded from here: zones are audited database records.
        safezone = { radius = 30.0, blockShoot = true, blockMelee = true, blockGrenades = true },
    },

    -- The first day ends (finished or skipped): a pointer to The Crossing.
    firstDayNotice = {
        delayMs = 8000,
        title = "THE CROSSING",
        body = "Arena, races, chases and events start at The Crossing, the esplanade where you arrived. "
            .. "Adam Smasher runs them there (on your map); the Neural-Link app Gigs & Arena works from anywhere.",
    },
}
