-- op77_chase configuration: every tuning number of the NCPD Chase, and nothing else.
-- The rules and their numbers come from the Pursuit gamemode (base
-- resources/gamemodes/pursuit/shared/config.lua), which argues each one at length; the
-- comments here only say what a number does.

-- One vehicle grid: both cars on one straight, the runner ahead, the cop behind,
-- each player standing on his car's driver (left) side. Ported as is from Pursuit.
local function gridPair(spec)
    local radians = math.rad(spec.heading)
    local fx, fy = -math.sin(radians), math.cos(radians)
    local rx, ry = math.cos(radians), math.sin(radians)
    local door = spec.doorClearMetres or 2.8
    local function station(along, s)
        local carX = spec.anchor.x + fx * along
        local carY = spec.anchor.y + fy * along
        return {
            position = { x = carX - rx * door, y = carY - ry * door, z = s.markZ },
            heading = spec.heading,
            playerYaw = spec.heading - 90.0,
            vehicleOffset = { forward = 0.0, lateral = door },
            vehicleYaw = spec.heading,
            vehicleRestZ = s.restZ,
        }
    end
    return {
        name = spec.name,
        runner = station(spec.gapMetres / 2.0, spec.runner),
        cop = station(-spec.gapMetres / 2.0, spec.cop),
    }
end

ChaseConfig = {
    -- The activities this resource registers with Light RP (contract: activityRegister).
    activity = {
        id = "chase.1v1",
        label = "NCPD Chase",
        kind = "chase",
        description = "Cop against runner, 1v1, by car or on foot. Two rounds, roles swap. "
            .. "The cop fills the arrest meter by pinning the runner; the runner wins by holding a 100 m gap.",
        minPlayers = 2,
        maxPlayers = 2,
        -- Nothing from the roleplay side stays usable inside a chase.
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
    },

    -- "vehicle" or "foot": the mode a pair gets when nobody asked for one.
    defaultMode = "vehicle",

    -- Routing buckets, one per match (Light RP plan: 4300000-4399999 is the chase range).
    buckets = { from = 4300000, to = 4300099 },

    queue = {
        -- A queued player keeps playing in the city; the queue entry expires after this.
        timeoutSeconds = 900,
        -- Pairing re-checks eligibility (Light RP activityCheck). A player who keeps failing
        -- it (driving, in a mission...) is told, and dropped after this long.
        notReadyDropSeconds = 120,
        notReadyNoticeSeconds = 30,
    },

    match = {
        size = 2,
        roundsPerMatch = 2,      -- best of two, roles swapped
        tieBreak = "decider",    -- "decider" (one more round when level) or "draw"
        timeoutWinner = "cop",   -- the clock is the cop's: the runner must actually escape
        copDownEndsRound = true,
        countdownSeconds = 10,
        intermissionSeconds = 8,
        scoreboardSeconds = 5,   -- the result stays on screen before everyone goes home
        placeTimeoutSeconds = 40, -- both players must be on their marks by then, or the match is void
        spawnLiftMetres = 0.35,  -- authored z values are position reads, ~0.5 m under the floor
        positionStaleResetMs = 3000,
        -- Feeds the overlay; the rules themselves are evaluated at tickHz.
        hudPushMs = 500,
        -- Foot spawns: the Northside promenade, both directions (Pursuit, measured).
        footSpawns = {
            {
                name = "northside_promenade",
                runner = { position = { x = -469.47, y = 930.99, z = 56.45 }, heading = 35.0 },
                cop    = { position = { x = -434.30, y = 881.28, z = 63.60 }, heading = 35.0 },
            },
            {
                name = "northside_promenade_reverse",
                runner = { position = { x = -434.30, y = 881.28, z = 63.60 }, heading = -145.0 },
                cop    = { position = { x = -469.47, y = 930.99, z = 56.45 }, heading = -145.0 },
            },
        },
        -- Vehicle spawns: the Watson grid west straight (Pursuit, surveyed with cars).
        vehicleSpawns = {
            gridPair({
                name = "watson_grid_west",
                anchor = { x = -680.0, y = 1027.3 },
                heading = 75.5,
                gapMetres = 40.0,
                doorClearMetres = 2.8,
                runner = { markZ = 35.52, restZ = 36.18 },
                cop    = { markZ = 36.26, restZ = 36.62 },
            }),
        },
    },

    -- The distance columns. A match keeps the column of its mode for its whole life.
    rules = {
        foot = {
            escapeDistance = 100.0, escapeGraceSeconds = 18.0, escapeDrainSeconds = 6.0, escapeArmSeconds = 8.0,
            bustDistance = 8.0, bustCoreDistance = 3.0, bustCoreFactor = 1.6,
            bustFillSeconds = 3.0, bustDrainSeconds = 5.0, bustContactDrainSeconds = 20.0,
            bustRunnerMaxSpeedKph = 9.0, bustCopMaxSpeedKph = 30.0,
            crashStallSeconds = 0.0, crashMinSpeedKph = 45.0, crashDropKph = 40.0,
            headStartSeconds = 5.0, durationSeconds = 180,
        },
        vehicle = {
            escapeDistance = 100.0, escapeGraceSeconds = 18.0, escapeDrainSeconds = 6.0, escapeArmSeconds = 15.0,
            bustDistance = 15.0, bustCoreDistance = 6.0, bustCoreFactor = 1.6,
            bustFillSeconds = 5.0, bustDrainSeconds = 8.0, bustContactDrainSeconds = 30.0,
            bustRunnerMaxSpeedKph = 12.0, bustCopMaxSpeedKph = 30.0,
            crashStallSeconds = 3.0, crashMinSpeedKph = 45.0, crashDropKph = 40.0,
            headStartSeconds = 0.0, durationSeconds = 180,
        },
    },

    -- Match cars: created in the match bucket for the round, removed after it. Never a
    -- personal vehicle, never a key, never in the garage.
    vehicles = {
        runner = { record = "Vehicle.v_standard2_archer_hella_player", lightsOn = true, sirenOn = false },
        cop = {
            record = "Vehicle.ncpd_villefort_cortes_heat_1",
            fallbackRecord = "Vehicle.v_standard2_villefort_cortes_player",
            lightsOn = true, sirenOn = true,
        },
        spawnOffset = { forward = 0.0, lateral = 3.5, up = 0.85 },
        restClearanceMetres = 0.10,
        seatCheckMs = 1000,
    },

    -- Elo per character (Pursuit's maths). Persisted in Light RP's database when it is
    -- enabled, in memory otherwise (and said so).
    ranked = {
        enabled = true,
        startRating = 1000, spread = 400.0, baseK = 20.0, provisionalK = 40.0, provisionalMatches = 10,
        floorRating = 100, minDelta = 1,
        rateUnplayedForfeit = false, -- a forfeit before any round finished is not rated
        leaderboardSize = 10,
    },

    -- Reputation sent with each result (Light RP clamps it per result and caps it per
    -- account and day). No cash, no items.
    reputation = { win = 30, draw = 15, loss = 10, forfeitWin = 15, leaver = 0, perOpponentPerDay = 3 },

    tickHz = 5,
    debug = false,
}
