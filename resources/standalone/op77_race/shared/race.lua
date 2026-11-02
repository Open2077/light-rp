-- Pure helpers shared by the server engine, the client and the tests: checkpoint
-- geometry, starting grids, time formatting and the live ranking order.
RaceShared = {}
local S = RaceShared

function S.onFoot(course)
    return type(course) == "table" and course.vehicle == "on_foot"
end

function S.finite(value)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

function S.clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[S.clone(key, seen)] = S.clone(child, seen) end
    return copy
end

function S.distance(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return math.huge end
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Intersection of the travelled segment with the checkpoint cylinder (Freeroam's
-- authoritative test, unchanged). Testing only the endpoint would accept a road on
-- another level and miss a fast downhill pass between two server samples.
function S.crossed(previous, current, target, radius, height, maxSegment)
    local dx, dy, dz = current.x - target.x, current.y - target.y, current.z - target.z
    if dx * dx + dy * dy <= radius * radius and math.abs(dz) <= height then return true end
    if previous == nil or previous.bucket ~= current.bucket then return false end
    local vx, vy, vz = current.x - previous.x, current.y - previous.y, current.z - previous.z
    if vx * vx + vy * vy + vz * vz > maxSegment * maxSegment then return false end
    local px, py, pz = previous.x - target.x, previous.y - target.y, previous.z - target.z
    local enter, leave = 0.0, 1.0
    local a = vx * vx + vy * vy
    local c = px * px + py * py - radius * radius
    if a < 0.000001 then
        if c > 0 then return false end
    else
        local b = 2 * (px * vx + py * vy)
        local discriminant = b * b - 4 * a * c
        if discriminant < 0 then return false end
        local root = math.sqrt(discriminant)
        enter = math.max(enter, (-b - root) / (2 * a))
        leave = math.min(leave, (-b + root) / (2 * a))
    end
    if math.abs(vz) < 0.000001 then
        if math.abs(pz) > height then return false end
    else
        local low, high = (-height - pz) / vz, (height - pz) / vz
        enter = math.max(enter, math.min(low, high))
        leave = math.min(leave, math.max(low, high))
    end
    return enter <= leave
end

-- Runners line up one behind the other, behind the captured start.
-- REDengine yaw 0 faces +Y.
function S.footSlot(start, index, spacing)
    local heading = start.heading or 0.0
    local yaw = math.rad(heading)
    local backward = (index - 1) * (spacing or 2.0)
    return {
        position = {
            x = start.position.x + math.sin(yaw) * backward,
            y = start.position.y - math.cos(yaw) * backward,
            z = start.position.z,
        },
        heading = heading,
    }
end

-- The authored slot when there is one; otherwise lanes behind the start mark.
function S.gridSlot(course, index, memberCount, grid, footSpacing)
    if S.onFoot(course) then return S.footSlot(course.start, index, footSpacing) end
    local authored = type(course.grid) == "table" and course.grid[index] or nil
    if authored ~= nil then
        return { position = S.clone(authored.position), heading = authored.heading or course.start.heading or 0.0 }
    end
    grid = grid or { lanes = 2, laneSpacing = 3.25, rowSpacing = 5.5 }
    local lanes = math.max(1, math.floor(grid.lanes))
    local lane = (index - 1) % lanes
    local row = math.floor((index - 1) / lanes)
    local centered = lane - (math.min(lanes, math.max(1, memberCount or 1)) - 1) * 0.5
    local radians = math.rad(course.start.heading or 0.0)
    local forwardX, forwardY = -math.sin(radians), math.cos(radians)
    local rightX, rightY = math.cos(radians), math.sin(radians)
    local backward = row * grid.rowSpacing
    return {
        position = {
            x = course.start.position.x - forwardX * backward + rightX * centered * grid.laneSpacing,
            y = course.start.position.y - forwardY * backward + rightY * centered * grid.laneSpacing,
            z = course.start.position.z,
        },
        heading = course.start.heading or 0.0,
    }
end

-- 83456 -> "1:23.456"; 3723004 -> "1:02:03.004".
function S.formatTime(ms)
    ms = math.floor(tonumber(ms) or 0)
    if ms < 0 then ms = 0 end
    local hours = ms // 3600000
    local minutes = (ms // 60000) % 60
    local seconds = (ms // 1000) % 60
    local millis = ms % 1000
    if hours > 0 then return ("%d:%02d:%02d.%03d"):format(hours, minutes, seconds, millis) end
    return ("%d:%02d.%03d"):format(minutes, seconds, millis)
end

-- Course length along its checkpoints (one lap), metres.
function S.routeMetres(course)
    local metres, previous = 0, course.start and course.start.position
    for _, checkpoint in ipairs(course.checkpoints or {}) do
        local p = checkpoint.position
        if previous then metres = metres + math.sqrt((p.x - previous.x) ^ 2 + (p.y - previous.y) ^ 2) end
        previous = p
    end
    return math.floor(metres)
end

-- Live order: finished (by finish place) > racing (by progress, then distance to the
-- next checkpoint) > on the grid > out (DNF / left), then grid order.
local CATEGORY = { finished = 4, racing = 3, countdown = 2, loading = 2, dnf = 1, left = 1 }
function S.rankRows(rows)
    table.sort(rows, function(a, b)
        local ca, cb = CATEGORY[a.state] or 0, CATEGORY[b.state] or 0
        if ca ~= cb then return ca > cb end
        if a.finishPlace ~= b.finishPlace then
            if a.finishPlace == nil then return false end
            if b.finishPlace == nil then return true end
            return a.finishPlace < b.finishPlace
        end
        if (a.progress or 0) ~= (b.progress or 0) then return (a.progress or 0) > (b.progress or 0) end
        local da, db = a.distance or math.huge, b.distance or math.huge
        if da ~= db then return da < db end
        return (a.grid or 0) < (b.grid or 0)
    end)
    for rank, row in ipairs(rows) do row.rank = rank end
    return rows
end
