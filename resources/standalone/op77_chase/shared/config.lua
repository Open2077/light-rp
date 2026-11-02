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

    -- op77_map3d shows every player within 350 m on the minimap. During a chase (1v1 and
    -- Most Wanted) the client hides the runner's dot from the cops through the map's
    -- setPlayerDotsHidden export, and gives it back when the chase is over. The runner
    -- keeps the cops on his minimap (his radar); cops keep each other (team play).
    minimap = { hideRunnerFromCops = true },

    tickHz = 5,
    debug = false,
}

-- ════════════════════════════════════════════════════════════════ Most Wanted
-- One runner against N cops (2-7), everyone runs once. Positions come from the two car
-- courses authored in game with Freeroam's course editor (base
-- resources/gamemodes/freeroam/data/race/courses/new-night-city-race-2-*.json):
-- the 8-car start grid of a course is the NCPD's line-up (car positions, yaw =
-- heading), and a checkpoint ~250-330 m down the course is the runner's start. Every
-- checkpoint of both courses is a candidate extraction point (they are on the road).
local function cp(x, y, z, heading) return { position = { x = x, y = y, z = z }, heading = heading } end

ChaseConfig.wanted = {
    activity = {
        id = "chase.wanted",
        label = "Most Wanted",
        kind = "chase",
        description = "One runner against the NCPD. Heat rises, backup rolls out, roadblocks go up: "
            .. "survive the clock or reach the extraction. Everyone runs once; most points wins.",
        minPlayers = 3,
        maxPlayers = 8,
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
    },
    -- Total players (runner included). The test minimum is used only while a staff member
    -- turned test mode on (chase.wanted.test on): a 2-player match pays no reputation.
    minPlayers = 3,
    testMinPlayers = 2,
    maxPlayers = 8,
    -- Everyone gets a runner turn; drop-ins are accepted while the rotation stays under this.
    maxRounds = 8,
    buckets = { from = 4300100, to = 4300199 },
    defaultMode = "vehicle",

    lobby = {
        countdownSeconds = 45,      -- once the minimum is ready; full lobby starts at once
        timeoutSeconds = 900,
        notReadyDropSeconds = 120,
        notReadyNoticeSeconds = 30,
        announce = true,            -- op77_lightrp:announce when a lobby countdown starts
        announceEverySeconds = 300,
    },

    match = {
        countdownSeconds = 10,
        intermissionSeconds = 10,
        scoreboardSeconds = 10,
        placeTimeoutSeconds = 40,
        roundSeconds = 165,         -- survive this long and the round is the runner's
        copRespawnSeconds = 5,      -- a downed cop is back at the line-up with a new car
        spawnLiftMetres = 0.35,
        carLiftMetres = 0.15,
        doorClearMetres = 2.8,      -- each player stands on his car's driver side
        positionStaleResetMs = 3000,
        hudPushMs = 500,
    },

    -- The runner's head start: the first wave of cops is held until it ends.
    headStartSeconds = { vehicle = 10, foot = 15 },

    -- Heat, by seconds since GO. `release` = share of the cops released when the level
    -- starts (wave 1 waits for the head start). `scan` = seconds between dispatch
    -- sightings of the runner for the cops, `scanRadius` = how vague they are.
    -- `bustScale` widens the arrest radius, `fillScale` speeds the arrest meter.
    heat = {
        { atSeconds = 0,   release = 0.5, scan = 30, scanRadius = 160, bustScale = 1.00, fillScale = 1.00 },
        { atSeconds = 30,  release = 1.0, scan = 22, scanRadius = 120, bustScale = 1.00, fillScale = 1.10, text = "Backup is rolling out." },
        { atSeconds = 60,  scan = 16, scanRadius = 90,  bustScale = 1.10, fillScale = 1.20, roadblocks = true, text = "Roadblocks authorized." },
        { atSeconds = 95,  scan = 12, scanRadius = 70,  bustScale = 1.20, fillScale = 1.35, extraction = true, text = "Extraction point located." },
        { atSeconds = 125, scan = 8,  scanRadius = 50,  bustScale = 1.30, fillScale = 1.50, text = "Maximum heat." },
    },

    -- Arrest and "shake" columns, by the runner's mode (cops always drive). Several cops
    -- closing at once fill the meter faster: x(1 + extraCopFactor per extra cop), capped.
    -- A shake = no released cop within escapeDistance for escapeGraceSeconds: points for
    -- the runner, then the cops must close in again before the next one counts.
    rules = {
        vehicle = {
            bustDistance = 15.0, bustCoreDistance = 6.0, bustCoreFactor = 1.6,
            bustFillSeconds = 6.0, bustDrainSeconds = 8.0, bustContactDrainSeconds = 30.0,
            bustRunnerMaxSpeedKph = 12.0, bustCopMaxSpeedKph = 30.0,
            extraCopFactor = 0.5, maxCopFactor = 2.5,
            escapeDistance = 150.0, escapeGraceSeconds = 12.0, escapeDrainSeconds = 6.0,
            crashStallSeconds = 3.0, crashMinSpeedKph = 45.0, crashDropKph = 40.0,
            nearbyMetres = 250.0, takedownCreditMetres = 40.0, assistMetres = 30.0, assistWindowSeconds = 6.0,
            eyesOnMetres = 60.0,
        },
        foot = {
            bustDistance = 8.0, bustCoreDistance = 3.0, bustCoreFactor = 1.6,
            bustFillSeconds = 3.5, bustDrainSeconds = 5.0, bustContactDrainSeconds = 20.0,
            bustRunnerMaxSpeedKph = 9.0, bustCopMaxSpeedKph = 30.0,
            extraCopFactor = 0.5, maxCopFactor = 2.5,
            escapeDistance = 90.0, escapeGraceSeconds = 12.0, escapeDrainSeconds = 6.0,
            crashStallSeconds = 0.0, crashMinSpeedKph = 45.0, crashDropKph = 40.0,
            nearbyMetres = 150.0, takedownCreditMetres = 25.0, assistMetres = 15.0, assistWindowSeconds = 6.0,
            eyesOnMetres = 35.0,
        },
    },

    -- A cop with eyes on the runner (within eyesOnMetres) relays a tight sighting to the
    -- whole unit every eyesOnSeconds.
    scanner = { eyesOnSeconds = 4, eyesOnRadius = 25 },

    -- Revealed to the runner at the heat level that says so, to the cops copDelaySeconds
    -- later. Drawn among the points between band[1] and band[2] metres from the runner.
    extraction = {
        radius = { vehicle = 15.0, foot = 7.0 },
        zTolerance = 8.0,
        band = { vehicle = { 450, 1300 }, foot = { 200, 500 } },
        copDelaySeconds = 20,
    },

    -- Roadblocks (runner by car, from the heat level that allows them): two locked,
    -- immortal NCPD cars across the runner's path. The server has no ground query, so the
    -- block takes the runner's own altitude and is thrown only `distanceMetres` ahead
    -- (Pursuit's containment: 4 m of vertical error at a 6 % grade is 66 m), never on a
    -- measured grade above maxGradePercent, never within clearMetres of a player.
    roadblock = {
        enabled = true,
        everySeconds = 40, lifetimeSeconds = 40, maxAlive = 2,
        distanceMetres = 66.0, minMoveMetres = 8.0, maxGradePercent = 6.0, clearMetres = 12.0,
        cars = 2, spacingMetres = 3.6,
        record = "Vehicle.ncpd_villefort_cortes_heat_1",
        fallbackRecord = "Vehicle.v_standard2_villefort_cortes_player",
    },

    vehicles = {
        -- Records from Freeroam's race list (running distribution). The runner gets a muscle
        -- car against the NCPD sedans: he is alone against up to seven of them.
        runner = { record = "Vehicle.v_sport2_quadra_type66_avenger_player", fallbackRecord = "Vehicle.v_standard2_archer_hella_player",
            lightsOn = true, sirenOn = false },
        cop = {
            record = "Vehicle.ncpd_villefort_cortes_heat_1",
            fallbackRecord = "Vehicle.v_standard2_villefort_cortes_player",
            lightsOn = true, sirenOn = true,
        },
    },

    points = {
        runnerPerSecond = 1,   -- every second the runner stays free
        survived = 40,         -- the clock ran out
        extracted = 80,        -- reached the extraction
        shake = 15,            -- lost every cop for a while
        arrest = 60,           -- the cop nearest when the meter filled
        assist = 30,           -- other cops who were closing in the last seconds
        takedown = 40,         -- the runner went down: the nearest cop
        unitWin = 10,          -- every cop when the NCPD wins the round
    },

    -- By final placement; nothing below `minPlayers` humans (test matches), nothing for a
    -- leaver, and only the first `perDay` matches of a character in a day pay.
    reputation = { byPlacement = { 40, 30, 25 }, other = 15, leaver = 0, minPlayers = 3, perDay = 6 },

    routes = {
        {
            name = "street_circuit",
            runner = cp(618.703, -1245.616, 29.038, 267.119),
            cops = {
                cp(342.31, -1428.671, 15.209, 238.691), cp(353.444, -1430.692, 15.198, 250.819),
                cp(360.45, -1439.564, 15.214, 229.552), cp(372.455, -1442.398, 15.21, 248.798),
                cp(381.675, -1452.954, 15.194, 230.943), cp(391.279, -1453.889, 15.207, 252.066),
                cp(398.354, -1462.537, 15.202, 230.285), cp(409.255, -1464.374, 15.202, 249.54),
            },
        },
        {
            name = "shion_sprint",
            runner = cp(-1563.726, -164.91, 8.286, 199.355),
            cops = {
                cp(-1482.446, 69.131, 8.293, 119.957), cp(-1488.736, 62.308, 8.288, 127.94),
                cp(-1498.524, 62.708, 8.299, 103.619), cp(-1504.008, 54.491, 8.296, 132.866),
                cp(-1514.551, 51.859, 8.293, 114.373), cp(-1518.843, 43.182, 8.291, 140.543),
                cp(-1530.89, 38.487, 8.298, 122.61), cp(-1535.856, 27.823, 8.291, 144.515),
            },
        },
    },

    -- Candidate extraction points: the checkpoints of both courses.
    extractionPoints = {
        cp(431.596, -1480.319, 15.19, 235.289), cp(483.231, -1501.638, 15.178, 284.939), cp(534.403, -1440.486, 20.464, 278.79),
        cp(584.528, -1462.777, 28.049, 263.196), cp(597.576, -1451.508, 28.019, 321.464), cp(602.444, -1387.153, 28.038, 2.64),
        cp(596.643, -1310.827, 28.736, 4.353), cp(618.703, -1245.616, 29.038, 267.119), cp(679.955, -1281.052, 34.649, 240.438),
        cp(815.337, -1358.604, 45.998, 239.488), cp(879.514, -1399.979, 53.286, 232.906), cp(964.741, -1494.562, 77.723, 209.617),
        cp(974.474, -1607.908, 102.182, 172.339), cp(964.081, -1682.852, 119.493, 179.243), cp(966.718, -1772.696, 134.906, 173.572),
        cp(938.51, -1877.309, 155.283, 161.984), cp(897.142, -1973.79, 165.704, 151.053), cp(830.183, -2041.592, 169.135, 127.157),
        cp(782.909, -2104.079, 172.867, 162.101), cp(744.766, -2233.752, 172.852, 150.436), cp(687.135, -2300.641, 172.854, 132.301),
        cp(597.903, -2345.694, 172.861, 107.645), cp(505.392, -2356.074, 172.926, 94.018), cp(440.537, -2364.387, 181.174, 103.407),
        cp(373.146, -2406.578, 182.235, 140.412), cp(374.965, -2501.625, 178.101, 204.831), cp(436.406, -2630.285, 170.937, 172.555),
        cp(398.664, -2641.497, 166.287, 75.144), cp(354.364, -2583.759, 156.315, 28.509), cp(330.237, -2460.578, 135.217, 1.587),
        cp(289.965, -2447.045, 118.8, 170.284), cp(284.276, -2541.16, 106.283, 161.153), cp(245.581, -2510.462, 95.194, 358.141),
        cp(263.585, -2414.439, 89.253, 348.349), cp(236.166, -2359.884, 75.117, 111.086), cp(213.612, -2455.255, 66.865, 170.337),
        cp(177.981, -2515.587, 57.662, 102.968), cp(161.907, -2490.062, 51.927, 14.571), cp(122.559, -2461.844, 46.279, 64.059),
        cp(73.34, -2447.933, 36.406, 88.562), cp(36.232, -2446.378, 32.91, 87.194), cp(-12.543, -2443.283, 27.724, 85.382),
        cp(-62.254, -2452.004, 23.646, 122.138), cp(-86.939, -2462.586, 26, 107.66),
        cp(-1552.936, 7.3, 8.292, 143.241), cp(-1576.183, -57.816, 8.29, 171.22), cp(-1573.485, -114.218, 8.29, 183.485),
        cp(-1563.726, -164.91, 8.286, 199.355), cp(-1554.844, -211.806, 16.922, 164.007), cp(-1585.132, -285.474, 16.636, 153.332),
        cp(-1651.415, -389.997, 4.721, 148.969), cp(-1707.283, -479.96, -2.118, 146.657), cp(-1743.299, -524.973, 1.967, 136.658),
        cp(-1786.007, -566.239, 11.402, 135.077), cp(-1842.426, -628.968, 16.951, 140.469), cp(-1896.805, -769.937, 12.13, 175.62),
        cp(-1893.511, -834.465, 7.872, 197.996), cp(-1843.236, -872.345, 7.841, 205.022), cp(-1840.592, -1012.084, 8.003, 180.406),
        cp(-1845.106, -1128.242, 19.807, 177.689), cp(-1837.183, -1212.469, 20.416, 217.775), cp(-1784.005, -1232.537, 29.744, 254.04),
        cp(-1705.409, -1249.589, 46.899, 259.931), cp(-1579.991, -1257.421, 50.32, 271.632), cp(-1482.589, -1258.585, 50.374, 263.542),
        cp(-1417.161, -1254.573, 40.05, 282.622), cp(-1345.793, -1213.671, 25.322, 302.458), cp(-1255.053, -1179.335, 12.514, 289.633),
        cp(-1145.179, -1094.362, 9.742, 321.302), cp(-1065.173, -983.933, 7.961, 325.216), cp(-1004.288, -896.584, 8.387, 328.055),
        cp(-967.527, -866.871, 8.458, 289.252), cp(-899.904, -908.372, 8.121, 234.564), cp(-827.653, -975.626, 7.942, 191.057),
        cp(-862.533, -1018.91, 11.664, 108.369), cp(-895.452, -1004.536, 12.107, 71.727),
    },
}
