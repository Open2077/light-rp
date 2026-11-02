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

    -- Reputation granted by results. Clamped to [0, maxPerResult] per result and
    -- to dailyCap per account (all its characters) per UTC day. `grantTo =
    -- "missions"` also adds it to the street reputation shown with the mission
    -- tiers (server/modules/missions.lua); nil keeps it in the activity tables.
    -- Activities never pay cash or items.
    reputation = { maxPerResult = 50, dailyCap = 250, grantTo = "missions" },

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
        -- terminal would open the same panel on that tab).
        terminals = {
            { id = "board", kind = "activities", label = "The Crossing",
                prompt = "Open activities & contracts", offset = { forward = 5.0, right = 0.0 } }, -- survey in game
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
            .. "Its terminal is on your map; the Neural-Link app Gigs & Arena works from anywhere.",
    },
}
