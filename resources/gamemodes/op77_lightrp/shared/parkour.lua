-- Parkour: the course contract shared by the server (server/modules/parkour.lua), the
-- client (client/core/parkour.lua, parkour_editor.lua) and the tests. A course is a start,
-- 0 to 50 checkpoints and a finish, each an orb with a trigger radius; the runner goes
-- from the start to the finish through every checkpoint, in order, against the clock.
--
-- Mirror of ui/src/features/parkour/model.ts (limits and validation): change both.
LightRpParkour = LightRpParkour or {}
local P = LightRpParkour

P.config = {
    activityId = "parkour.run",
    -- the orb: drawn and tested around a centre this high above the placed point (chest height)
    orbLift = 1.0,
    radius = { default = 3.0, min = 1.0, max = 12.0 },
    limits = { checkpoints = 50, name = 40, description = 200, minRouteM = 15, minGapM = 2.0, maxRouteM = 20000 },
    difficulties = { "easy", "medium", "hard", "extreme" },
    timeLimit = { default = 0, max = 60 },       -- minutes, 0 = none (a run still stops at maxRunMinutes)
    maxRunMinutes = 30,
    countdownMs = 3000,
    -- After the teleport onto the start the 3-2-1 waits for the client to say it has landed: no
    -- loading screen, the body alive, `landSettleMs` more (a far start loads the area: the countdown
    -- and the first seconds ran under the loading screen, 2026-11-06). Past `landTimeoutMs` it goes anyway.
    landSettleMs = 700,
    landTimeoutMs = 15000,
    tickMs = 50,
    -- a sample further than this from the previous one (outside our own teleports) is not a run any more
    maxStepM = 45,
    -- a server sample faster than this (m/s, horizontal) ends the run (a vehicle, a teleport)
    maxSpeed = 42,
    -- start points: a player within this of the start orb can press E
    startPromptRadius = 4.0,
    -- a course's start (its ring and beam) shows only within this many metres
    startView = 80,
    streamLimit = 24,                            -- start points listed to each client (nearest)
    boardPage = 50,                              -- leaderboard rows per page
    boardCache = 500,                            -- best times kept in memory per course
    resultHoldMs = 25000,                        -- after the finish: the card stays, then back
    restartCooldownMs = 1200,
    music = { file = "audio/parkour-rooftop-momentum.webm", volume = 0.05 },
    -- staff editor ACL (staff roles hold command.lightrp.*)
    permission = "command.lightrp.parkour",
}

local function finite(n) return type(n) == "number" and n == n and n > -1e6 and n < 1e6 end
local function round(n, step) step = step or 0.01; return math.floor(n / step + 0.5) * step end
P.round = round

local function trim(s, max)
    if type(s) ~= "string" then return nil end
    s = s:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #s > max then s = s:sub(1, max) end
    return s
end

function P.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- One point of a course, cleaned: { x, y, z, radius[, heading] } or nil, reason.
local function cleanPoint(p, label, withHeading)
    if type(p) ~= "table" or not finite(tonumber(p.x)) or not finite(tonumber(p.y)) or not finite(tonumber(p.z)) then
        return nil, label .. " is not placed."
    end
    local r = tonumber(p.radius) or P.config.radius.default
    if not finite(r) or r < P.config.radius.min or r > P.config.radius.max then
        return nil, ("%s: the radius must be %g to %g m."):format(label, P.config.radius.min, P.config.radius.max)
    end
    local out = { x = round(tonumber(p.x)), y = round(tonumber(p.y)), z = round(tonumber(p.z)), radius = round(r, 0.1) }
    if withHeading then
        local h = tonumber(p.heading) or 0
        if not finite(h) then h = 0 end
        out.heading = round(h % 360, 0.1)
    end
    return out
end

-- The route: start, every checkpoint, finish.
function P.route(course)
    local list = { course.start }
    for _, c in ipairs(course.checkpoints or {}) do list[#list + 1] = c end
    list[#list + 1] = course.finish
    return list
end

function P.length(course)
    local total, route = 0, P.route(course)
    for i = 2, #route do total = total + P.distance(route[i - 1], route[i]) end
    return total
end

-- A course from the editor (or the database), cleaned and checked: course | nil, reason.
-- Keeps id / revision / status / author fields as given (the server owns them).
function P.validate(input)
    if type(input) ~= "table" then return nil, "Invalid course." end
    local L = P.config.limits
    local name = trim(input.name, L.name)
    if not name or #name < 3 then return nil, "Give the course a name (3 to " .. L.name .. " characters)." end
    local description = trim(input.description or "", L.description) or ""
    local difficulty = "medium"
    for _, d in ipairs(P.config.difficulties) do if input.difficulty == d then difficulty = d end end
    local start, why = cleanPoint(input.start, "The start", true)
    if not start then return nil, why end
    local finish
    finish, why = cleanPoint(input.finish, "The finish", false)
    if not finish then return nil, why end
    local checkpoints = {}
    if input.checkpoints ~= nil and type(input.checkpoints) ~= "table" then return nil, "Invalid checkpoints." end
    for i, c in ipairs(input.checkpoints or {}) do
        if i > L.checkpoints then return nil, "At most " .. L.checkpoints .. " checkpoints." end
        local cp
        cp, why = cleanPoint(c, "Checkpoint " .. i, false)
        if not cp then return nil, why end
        checkpoints[#checkpoints + 1] = cp
    end
    local timeLimit = math.floor(tonumber(input.timeLimit) or P.config.timeLimit.default)
    if timeLimit < 0 or timeLimit > P.config.timeLimit.max then return nil, "The time limit must be 0 (none) to " .. P.config.timeLimit.max .. " minutes." end
    local floorZ = input.floorZ
    if floorZ ~= nil then
        floorZ = tonumber(floorZ)
        if not finite(floorZ) then return nil, "Invalid fall line." end
        floorZ = round(floorZ, 0.1)
    end
    local course = { id = input.id, revision = input.revision, status = input.status, author = input.author, authorName = input.authorName,
        name = name, description = description, difficulty = difficulty, start = start, checkpoints = checkpoints, finish = finish,
        timeLimit = timeLimit, floorZ = floorZ }
    -- a sensible route: long enough, no two consecutive orbs on top of each other
    local route = P.route(course)
    for i = 2, #route do
        if P.distance(route[i - 1], route[i]) < L.minGapM then
            local a = i - 1 == 1 and "the start" or ("checkpoint " .. (i - 2))
            local b = i == #route and "the finish" or ("checkpoint " .. (i - 1))
            return nil, ("%s and %s are closer than %g m."):format(a, b, L.minGapM)
        end
    end
    local length = P.length(course)
    if length < L.minRouteM then return nil, ("The route is %.0f m long: %d m at least."):format(length, L.minRouteM) end
    if length > L.maxRouteM then return nil, ("The route is %.0f m long: %d m at most."):format(length, L.maxRouteM) end
    if floorZ and (floorZ >= start.z - 0.5) then return nil, "The fall line must be below the start." end
    course.length = round(length, 0.1)
    return course
end

-- The geometry the leaderboard depends on: a change of it is a new revision (fresh board).
function P.routeKey(course)
    local parts = {}
    for _, p in ipairs(P.route(course)) do
        parts[#parts + 1] = ("%.2f,%.2f,%.2f,%.1f"):format(p.x, p.y, p.z, p.radius)
    end
    parts[#parts + 1] = course.floorZ and ("f%.1f"):format(course.floorZ) or "f-"
    return table.concat(parts, "|")
end

-- Where the segment a -> b first enters the sphere (centre c, radius r): 0..1, or nil.
-- a inside already: 0. Used with the body centre (feet + orbLift) against the orb centre.
function P.segmentEnters(a, b, c, r)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local fx, fy, fz = a.x - c.x, a.y - c.y, a.z - c.z
    local cc = fx * fx + fy * fy + fz * fz - r * r
    if cc <= 0 then return 0 end
    local aa = dx * dx + dy * dy + dz * dz
    if aa < 1e-9 then return nil end
    local bb = 2 * (fx * dx + fy * dy + fz * dz)
    local disc = bb * bb - 4 * aa * cc
    if disc < 0 then return nil end
    local t = (-bb - math.sqrt(disc)) / (2 * aa)
    if t >= 0 and t <= 1 then return t end
    return nil
end

-- A time as the HUD prints it: 1:02.345 (or 12.345 under a minute).
function P.formatTime(ms)
    ms = math.max(0, math.floor(tonumber(ms) or 0))
    local m, s, f = math.floor(ms / 60000), math.floor(ms / 1000) % 60, ms % 1000
    if m > 0 then return ("%d:%02d.%03d"):format(m, s, f) end
    return ("%d.%03d"):format(s, f)
end

-- Splits as stored: "1234,5678" (ms since GO at each checkpoint).
function P.encodeSplits(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = tostring(math.floor(tonumber(v) or 0)) end
    return table.concat(out, ",")
end
function P.decodeSplits(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for v in text:gmatch("[^,]+") do out[#out + 1] = math.floor(tonumber(v) or 0) end
    return out
end

-- What a client is told about a published course (start orbs, the browser list).
function P.summary(course)
    return { id = course.id, name = course.name, difficulty = course.difficulty, checkpoints = #(course.checkpoints or {}),
        length = course.length or P.length(course), revision = course.revision,
        start = { x = course.start.x, y = course.start.y, z = course.start.z, radius = course.start.radius, heading = course.start.heading } }
end
