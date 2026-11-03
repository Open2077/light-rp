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
        -- Nothing from the roleplay side stays usable inside a chase. `botFill`: whether
        -- staff bot mode may fill this activity's missing players with bots; registered
        -- from ChaseConfig.bots.fill[id] as botFill (top level: Light RP's lobby offers bots
        -- only where it is true) and caps.botFill (core.lua ChaseCore.caps / botFill).
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false, botFill = false },
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
        -- A crew member (Light RP squad) is not paired with a stranger for this long while
        -- his crewmates' joins are on their way: two of a crew face each other.
        squadHoldSeconds = 10,
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

-- The two courses, checkpoint by checkpoint (on the road, in driving order), and
-- their 8-car start grids (slot 8 is the front of the grid, nearest checkpoint 1).
local STREET_CIRCUIT = {
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
}
local STREET_CIRCUIT_GRID = {
    cp(342.31, -1428.671, 15.209, 238.691), cp(353.444, -1430.692, 15.198, 250.819),
    cp(360.45, -1439.564, 15.214, 229.552), cp(372.455, -1442.398, 15.21, 248.798),
    cp(381.675, -1452.954, 15.194, 230.943), cp(391.279, -1453.889, 15.207, 252.066),
    cp(398.354, -1462.537, 15.202, 230.285), cp(409.255, -1464.374, 15.202, 249.54),
}
local SHION_SPRINT = {
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
}
local SHION_SPRINT_GRID = {
    cp(-1482.446, 69.131, 8.293, 119.957), cp(-1488.736, 62.308, 8.288, 127.94),
    cp(-1498.524, 62.708, 8.299, 103.619), cp(-1504.008, 54.491, 8.296, 132.866),
    cp(-1514.551, 51.859, 8.293, 114.373), cp(-1518.843, 43.182, 8.291, 140.543),
    cp(-1530.89, 38.487, 8.298, 122.61), cp(-1535.856, 27.823, 8.291, 144.515),
}

local function concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do for _, v in ipairs(list) do out[#out + 1] = v end end
    return out
end

ChaseConfig.wanted = {
    activity = {
        id = "chase.wanted",
        label = "Most Wanted",
        kind = "chase",
        description = "One runner against the NCPD. Heat rises, backup rolls out, roadblocks go up: "
            .. "survive the clock or reach the extraction. Everyone runs once; most points wins.",
        minPlayers = 3,
        maxPlayers = 8,
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false, botFill = false },
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
        squadHoldSeconds = 10,      -- a crew waits this long for crewmates still on their way
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
            cops = STREET_CIRCUIT_GRID,
            course = STREET_CIRCUIT, runnerIndex = 8,   -- the runner's start is checkpoint 8
        },
        {
            name = "shion_sprint",
            runner = cp(-1563.726, -164.91, 8.286, 199.355),
            cops = SHION_SPRINT_GRID,
            course = SHION_SPRINT, runnerIndex = 4,     -- the runner's start is checkpoint 4
        },
    },

    -- Candidate extraction points: the checkpoints of both courses.
    extractionPoints = concat(STREET_CIRCUIT, SHION_SPRINT),
}

-- A grid slot (a car position, heading = the car's yaw) as a 1v1 mark: the player stands
-- on the car's driver (left) side, the car rests on the slot (same z as Most Wanted's
-- carMark: slot z + 0.15).
local function gridStation(slot, door)
    door = door or 2.8
    local r = math.rad(slot.heading)
    local rx, ry = math.cos(r), math.sin(r)
    return {
        position = { x = slot.position.x - rx * door, y = slot.position.y - ry * door, z = slot.position.z },
        heading = slot.heading,
        playerYaw = slot.heading - 90.0,
        vehicleOffset = { forward = 0.0, lateral = door },
        vehicleYaw = slot.heading,
        vehicleRestZ = slot.position.z + 0.05,
    }
end

-- ════════════════════════════════════════════════════════════════ Bots
-- Bot mode (staff, Light RP's /lightrp.bots on|off, never on at start): one queued
-- player is enough for a 1v1 or a Most Wanted, bots play the missing roles - only where
-- `fill` allows it. The same bots can be the NCPD of NCPD Escape (ChaseConfig.pve.police
-- = "bots"). A bot is an Open77 NPC: at the wheel of its match car (vehicles.ai: chase /
-- followRoute / joinTraffic), or on foot (npcs.tasks: moveTo / flee). Its position for
-- the rules is the server's own read of its car (vehicles.get) or body (npcs.presence).
--
-- Why everything is off: on the client build of 2026-11 a bot's driving order never
-- reaches its car. The NPC is seated (`Vehicle AI driver seat start ... status=ok`) but
-- every chase / follow / driveTo / followRoute demand is dropped by the client as
-- `vehicle.ai malformed_request fields=16` - see README.md, "Bot drivers". Turn a fill on
-- again only once a fixed client has been seen driving a bot after a player.
ChaseConfig.bots = {
    -- Bot fill per activity while staff bot mode is on. false = real players only: bot mode
    -- then starts nothing there and the player is told why. Also registered with Light RP
    -- as botFill and caps.botFill (its lobby offers bots only where botFill is true).
    fill = { ["chase.1v1"] = false, ["chase.wanted"] = false },
    namePrefix = "[BOT] ",
    names = { "Kowalski", "Reyes", "Okafor", "Lindqvist", "Tanaka", "Moreau", "Delgado", "Novak",
        "Haddad", "Brennan", "Ortiz", "Sato", "Ivanova", "Mbeki", "Castillo", "Weber" },
    -- A lone player waits this long in the 1v1 queue (a human opponent first) before a bot
    -- takes the other side.
    soloWaitSeconds = 2,
    -- Body records, tried in order when one is refused. The NCPD record is a candidate
    -- (never measured in multiplayer); the drivers are open77_traffic's proven ones.
    records = {
        cop = { "Character.arr_ncpd_constable_ranged1_lexington_ma", "Character.LowlifeMaleDriver" },
        runner = { "Character.LowlifeMaleDriver", "Character.NightlifeFemaleDriver", "Character.CitizenRichFemaleDriver" },
    },
    damagePolicy = "immortal",      -- Open77.npcs.damage.<name>
    streamingRadius = 400.0,
    -- One NPC created per spawnSpacingMs at most, never in the tick that removed one;
    -- nothing at all in the first settleMs after this resource started (the previous
    -- run's orphans are swept first).
    spawnSpacingMs = 400,
    settleMs = 5000,
    attachRetries = 5,               -- attachDriver refusals before the car drives itself (no body)
    createRetries = 3,               -- npcs.create refusals (every record) before the bot is broken
    driver = {
        ability = 0.95,              -- npcs.tasks.setDriverAbility: aggressive, 8 + 24 * ability m/s
        behavior = "aggressive",     -- clearTrafficOnPath
        stateCheckMs = 2000,         -- an idle / failed / cancelled task is given again
        taskTimeoutMs = 600000,
    },
    cop = {
        chaseDistance = 4.0,         -- vehicles.ai.chase distance (3..80)
        footSpeed = "sprint",
        footRepathMs = 1000,         -- on foot: a new moveTo at most this often...
        footRepathMetres = 3.0,      -- ...and only when the target moved this far from the last goal
        footAcceptance = 1.5,
    },
    runner = {
        -- A bot runner pinned by a cop (within the bust radius for yieldSeconds) gives up:
        -- it stops, so the arrest meter can fill exactly as against a cornered player. It
        -- drives off again if the cop backs off beyond resumeFactor x the bust radius.
        yieldSeconds = { vehicle = 4, foot = 3 },
        resumeFactor = 2.0,
        fleeDistance = 200,          -- npcs.tasks.flee distance (5..200)
        footSpeed = "sprint",
    },
    -- 1v1 car chases with a bot: the courses' start grids (the bot runner drives the course,
    -- then the traffic). The front of the grid is the runner's car, slot 4 (~43 m back)
    -- the cop's. On foot the regular footSpawns are used.
    vehicleSpawns = {
        { name = "street_circuit_grid", runner = gridStation(STREET_CIRCUIT_GRID[8]), cop = gridStation(STREET_CIRCUIT_GRID[4]),
            route = STREET_CIRCUIT },
        { name = "shion_sprint_grid", runner = gridStation(SHION_SPRINT_GRID[8]), cop = gridStation(SHION_SPRINT_GRID[4]),
            route = SHION_SPRINT },
    },
    wanted = {
        players = 3,                 -- a bot-mode Most Wanted is filled up to this many (humans + bots)
        countdownSeconds = 5,        -- lobby countdown of a bot-mode match (never announced)
    },
    -- A bot cop more than farMetres from its runner for farSeconds is dispatched again:
    -- removed, and back on a point the runner drove through, band[1]-band[2] m behind him
    -- (no AI drives beyond 350 m of a player, and the road he used is a road).
    redispatch = { farMetres = 300, farSeconds = 5, band = { 120, 220 }, cooldownSeconds = 15, trailEveryMs = 1000, trailSize = 120 },
}

-- ════════════════════════════════════════════════════════════════ NCPD Escape (PvE)
-- Public, no switch: one player, or a crew (Light RP squad), against the game's own NCPD.
-- Every human is a runner (his own car, or on foot) in an instance with vanilla traffic and
-- a crowd. During the countdown (dispatchLeadSeconds before GO) the server gives him a wanted
-- level (Open77.players.setWanted) that climbs with the clock from GO up to the difficulty's
-- ceiling, and his own game sends its police. Those
-- police (and that traffic) are LOCAL to each player's game, not replicated: in a crew,
-- every runner is chased by his own NCPD. The outcome is the server's, because the engine's
-- "lost them" cannot be read:
--   * BUSTED: he stops (slower than bust.stopKph until the bust meter fills), leaves his car
--     (by car), or goes down;
--   * ESCAPED: he reaches the extraction point or survives the clock.
-- On every exit (end, leave, disconnect, return home, resource restart) his stars go back to
-- 0 and his ceiling to 5. Results go to Light RP as usual (PvE: reputation by difficulty,
-- eddies by Light RP's activity_pay). No rating, no database.
ChaseConfig.pve = {
    activity = {
        id = "chase.pve",
        label = "NCPD Escape",
        kind = "chase",
        description = "The NCPD is after you, for real: the heat climbs with the clock. Stop and you are busted; "
            .. "reach the extraction or survive the clock. Solo or with a crew, by car or on foot.",
        minPlayers = 1,
        maxPlayers = 4,
        -- botFill: no player slot for a bot to take (the police are the game's).
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false, botFill = false },
        modes = { { id = "vehicle", label = "By car" }, { id = "foot", label = "On foot" } },
        -- PvE with difficulties: Light RP offers them, gates them by reputation tier and hands
        -- options.difficulty to the join (difficulties below).
        pve = true,
        difficulties = { "standard", "hard", "critical" },
    },
    -- Who chases the runners: "ncpd" = the game's own police, through the wanted level;
    -- "bots" = the Open77 bot cops at the wheel of NCPD cars (server/bots.lua, config `bots`
    -- below). Bots stay off: on the 2026-11 client their driving orders never reach the car
    -- (README "Bot drivers").
    police = "ncpd",
    -- A crew in NCPD Escape: "together" = one instance, every member chased by his own NCPD
    -- (each game runs its own police and its own traffic); "solo" = every member gets his
    -- own instance, all started at the same time.
    crews = "together",
    -- The client reports what its game did with the wanted level (op77_chase:police, read
    -- from Open77.prevention.state()). When the game refused it (population_suppressed: no
    -- police can come), "warn" keeps the run going and says so on the HUD and in the log;
    -- "void" calls the run off (nothing counts).
    -- owner decision 2026-11-03: "void" -- no reputation for a run no police could join
    onPoliceBlocked = "void",
    maxRunners = 4,
    buckets = { from = 4300200, to = 4300299 },
    defaultMode = "vehicle",
    defaultDifficulty = "standard",
    queue = {
        gatherSeconds = 2,          -- a join starts this long after it arrived (a crew's joins arrive together)
        squadWaitSeconds = 10,      -- a crew member waits this long for the others' joins
        timeoutSeconds = 900,
        notReadyDropSeconds = 120,
        notReadyNoticeSeconds = 30,
    },
    -- The instance's ambient population (Open77.world.setPopulation when the match is created,
    -- back to empty when it closes). police = "ncpd" only; the bot escape stays empty.
    -- crowd is a real fraction; traffic and police are switches on 2.31 (any traffic > 0 =
    -- vanilla traffic). Every client spawns its own crowd, traffic and police.
    population = { crowd = 0.5, traffic = 1.0, police = true },
    match = {
        countdownSeconds = 10,
        placeTimeoutSeconds = 40,
        scoreboardSeconds = 8,
        runnerSpacingMetres = 9.0,  -- runners line up behind the start checkpoint, one car each
        spawnLiftMetres = 0.35,
        carLiftMetres = 0.15,
        doorClearMetres = 2.8,
        hudPushMs = 500,
    },
    -- From GO to the first star. 0 since 2026-11-03 (the owner): the NCPD is called during the
    -- countdown instead (dispatchLeadSeconds), and bust.graceSeconds gives him the time to get
    -- going that the head start used to give.
    headStartSeconds = { vehicle = 0, foot = 0 },
    -- The first heat step's level is sent this long before GO: the game takes ~10 s to roll its
    -- first units (the owner, 2026-11-03: "they take like 10 sec to start to come"), so they
    -- reach him around GO instead of ~10 s after it. He is still frozen then; the run's clock
    -- and the bust start at GO. 0 = the wanted level at GO + headStartSeconds, as before.
    dispatchLeadSeconds = 8,
    -- The difficulties (Light RP's ids). heat: the stars `at` seconds after the head start;
    -- the last step is the ceiling (setMaxWanted). roundSeconds: the clock from GO (survive
    -- it = escaped). bustFillSeconds: how long stopped before the cuffs. extractionAtSeconds:
    -- the extraction point appears this long after GO.
    difficulties = {
        standard = { label = "Standard", roundSeconds = 150, bustFillSeconds = 5.0, extractionAtSeconds = 40,
            heat = { { at = 0, stars = 3 }, { at = 45, stars = 4 }, { at = 100, stars = 5 } } },
        hard = { label = "Hard", roundSeconds = 165, bustFillSeconds = 4.0, extractionAtSeconds = 55,
            heat = { { at = 0, stars = 3 }, { at = 30, stars = 4 }, { at = 70, stars = 5 } } },
        critical = { label = "Critical", roundSeconds = 180, bustFillSeconds = 3.0, extractionAtSeconds = 70,
            heat = { { at = 0, stars = 4 }, { at = 35, stars = 5 } } },
    },
    -- The wanted level is sent again every reassertSeconds while a runner is out: the engine
    -- drops its heat by itself when its police lose him, the server never learns it, and the
    -- escape is the extraction or the clock, never the engine's "lost them". The client
    -- checks its game every probeSeconds; a raise still refused after blockedAfterSeconds is
    -- "police blocked" (onPoliceBlocked).
    wanted = { reassertSeconds = 15, probeSeconds = 2, blockedAfterSeconds = 6 },
    -- The bust meter. It fills while the runner is stopped (slower than stopKph, speed
    -- windowed over 1 s of position samples) or, by car, out of every car (unless he moves
    -- faster than outOfCarMaxKph: then he sits in a car the server cannot see), over the
    -- difficulty's bustFillSeconds; it drains over drainSeconds once he moves again. It arms
    -- with the first star, and by car once he has sat in his car (or boardingGraceSeconds
    -- after GO). A meter past closeCall that drains back to 0 is a close call (stats.shakes).
    -- An unreadable position freezes the meter; staleResetMs of blackout empties it.
    bust = {
        vehicle = { stopKph = 10.0, outOfCarMaxKph = 35.0 },
        foot = { stopKph = 5.0 },
        -- After GO the meter waits this long whatever the stars: he was frozen in the countdown
        -- and needs to get in (by car) and get going.
        graceSeconds = { vehicle = 6, foot = 4 },
        drainSeconds = 2.5,
        boardingGraceSeconds = 15,
        closeCall = 0.6,
        staleResetMs = 3000,
    },
    -- Drawn among Most Wanted's extraction points, band[1]-band[2] m from the runner.
    extraction = { band = { vehicle = { 450, 1300 }, foot = { 200, 500 } }, radius = { vehicle = 15.0, foot = 7.0 }, zTolerance = 8.0 },
    -- Light RP clamps and caps it (per account and day) as for every PvE activity: the
    -- Standard figures (~60 % of the 1v1's win / loss) times the difficulty's factor, the
    -- same ratios as Light RP's own PvE rewards (30 / 60 / 100). Nothing for a leaver,
    -- nothing for a round under minSeconds, and only the first perDay paid rounds of a
    -- character in a day pay.
    reputation = { escaped = 18, busted = 6, leaver = 0, minSeconds = 60, perDay = 8,
        difficulty = { standard = 1.0, hard = 2.0, critical = 10 / 3 } },
    -- police = "bots" only: the bot cops (base + perRunner x runners, capped), Most Wanted's
    -- rules with these changes (a PvE shake is the escape, so it takes longer), the clock
    -- and the head start of the bot escape.
    bots = {
        cops = { base = 1, perRunner = 2, max = 8 },
        roundSeconds = 165,
        headStartSeconds = { vehicle = 10, foot = 15 },
        rules = {
            vehicle = { escapeGraceSeconds = 15.0 },
            foot = { escapeGraceSeconds = 15.0 },
        },
    },
}
