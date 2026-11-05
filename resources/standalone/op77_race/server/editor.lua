-- Course editor, staff only. A session opens through the restricted command
-- /race.editor (ACL command.race.editor); the editor keys and the other actions only
-- work for a player who holds an open session, so the session is the authorization.
-- Points are captured from the server's own position (or the driven car's), in the
-- open world (bucket 0), never from coordinates a client sends. Only the facing comes
-- from the client, and it is clamped.
local Config = RaceConfig
local Limits = Config.editor
local S = RaceShared

RaceEditor = {}
local Ed = RaceEditor

local sessions = {}   -- playerId -> { draft, expiresAt }
Ed.sessions = sessions

local noop = function() end
Ed.hooks = {
    push = noop,     -- (playerId, state | nil) editor preview for the client
    notice = noop,   -- (playerId, kind, title, text)
}

local function nowMs() return math.floor(Open77.time.monotonic() * 1000) end
local function log(text) print("[race:editor] " .. tostring(text)) end

local MESSAGES = {
    name_too_short = "The name needs at least 3 characters.",
    invalid_type = "Type is circuit or sprint.",
    invalid_parkour = "Parkour is on or off.",
    parkour_on_foot = "A parkour course is on foot.",
    invalid_laps = ("Laps go from %d to %d."):format(Limits.minimumLaps, Limits.maximumLaps),
    invalid_checkpoint_radius = ("The radius goes from %.0f to %.0f m."):format(Limits.minimumRadius, Limits.maximumRadius),
    invalid_vehicle = "Unknown vehicle. /race.editor vehicles lists them.",
    start_missing = "Capture the start first.",
    grid_missing = "A vehicle course needs grid slots.",
    not_enough_grid_slots = "A vehicle course needs grid slots.",
    grid_slots_overlap = ("Grid slots must be %.2f m apart."):format(Limits.minimumGridSpacing),
    not_enough_checkpoints = "Not enough checkpoints.",
    too_many_checkpoints = ("At most %d checkpoints."):format(Limits.maximumCheckpoints),
    position_unavailable = "Your position is unavailable.",
    editor_world_required = "The editor works in the open world only.",
    course_not_found = "No such course.",
    builtin_readonly = "Built-in courses cannot be deleted.",
}
function Ed.message(reason)
    local key = tostring(reason or ""):match("^([%w_]+)")
    return MESSAGES[key] or tostring(reason)
end

local function blank(foot)
    return {
        name = foot and "New rooftop course" or "New street course",
        description = "",
        type = "circuit",
        laps = 1,
        checkpointRadius = foot and 3.0 or Config.engine.checkpointRadius,
        vehicle = foot and "on_foot" or Config.engine.vehicle.default,
        grid = {},
        checkpoints = {},
    }
end

local function headingOf(value)
    local h = S.finite(value)
    if h == nil then return 0.0 end
    h = h % 360.0
    if h < 0.0 then h = h + 360.0 end
    return h
end

-- In a car, the car's own position (the grid mark); otherwise the player's.
function Ed.capture(playerId, heading)
    local p = Open77.players.position(playerId)
    if p == nil then return nil, "position_unavailable" end
    if p.bucket ~= (Limits.worldBucket or 0) then return nil, "editor_world_required" end
    local point = { x = p.x, y = p.y, z = p.z }
    local seat = RaceEngine.vehicleCall("getPlayerSeat", playerId)
    if type(seat) == "table" and seat.vehicleId ~= nil then
        local vehicle = RaceEngine.vehicleCall("get", seat.vehicleId)
        if type(vehicle) == "table" and S.finite(vehicle.x) and S.finite(vehicle.y) and S.finite(vehicle.z) then
            point = { x = vehicle.x, y = vehicle.y, z = vehicle.z }
        end
    end
    return { position = point, heading = headingOf(heading) }
end

function Ed.session(playerId)
    local session = sessions[playerId]
    if session == nil then return nil end
    if nowMs() > session.expiresAt then
        sessions[playerId] = nil
        Ed.hooks.push(playerId, nil)
        return nil
    end
    session.expiresAt = nowMs() + Limits.sessionMinutes * 60000
    return session
end

local function state(session, message)
    return {
        draft = S.clone(session.draft),
        vehicles = RaceCourses.vehicles(),
        message = message,
    }
end

function Ed.push(playerId, message)
    local session = sessions[playerId]
    Ed.hooks.push(playerId, session and state(session, message) or nil)
end

-- Opens a session: a blank course, or a copy of an existing one (a saved course keeps
-- its id and becomes a new revision; a built-in is saved as a new course).
function Ed.open(playerId, from)
    local draft
    if from == "--foot" then
        draft = blank(true)
    elseif from == "--parkour" then
        draft = blank(true)
        draft.name, draft.parkour = "New parkour course", true
    elseif type(from) == "string" and from ~= "" then
        local course = RaceCourses.get(from)
        if course == nil then return false, "course_not_found" end
        if course.builtin then
            course.id, course.builtin, course.revision = nil, false, nil
            course.name = ("Copy of %s"):format(course.name):sub(1, Limits.maximumNameBytes)
        end
        draft = course
    else
        draft = blank(false)
    end
    sessions[playerId] = { draft = draft, expiresAt = nowMs() + Limits.sessionMinutes * 60000 }
    Ed.push(playerId, "Editor open.")
    return true
end

function Ed.close(playerId)
    if sessions[playerId] == nil then return false end
    sessions[playerId] = nil
    Ed.hooks.push(playerId, nil)
    return true
end

-- One editor action. Returns true and a short message, or false and a reason.
function Ed.action(playerId, action, value, heading)
    local session = Ed.session(playerId)
    if session == nil then return false, "no_session" end
    local draft = session.draft
    local foot = S.onFoot(draft)
    local message

    if action == "start" or action == "cp" or action == "checkpoint" or action == "grid" then
        local point, reason = Ed.capture(playerId, heading)
        if point == nil then return false, reason end
        if action == "start" then
            draft.start = point
            message = "Start captured."
        elseif action == "grid" then
            if foot then return false, "On foot, runners line up behind the start." end
            for _, slot in ipairs(draft.grid) do
                if S.distance(slot.position, point.position) < Limits.minimumGridSpacing then return false, "grid_slots_overlap" end
            end
            if #draft.grid >= 8 then return false, "Eight grid slots at most." end
            draft.grid[#draft.grid + 1] = point
            message = ("Grid slot %d captured."):format(#draft.grid)
        else
            if #draft.checkpoints >= Limits.maximumCheckpoints then return false, "too_many_checkpoints" end
            draft.checkpoints[#draft.checkpoints + 1] = point
            message = ("Checkpoint %d captured."):format(#draft.checkpoints)
        end
    elseif action == "undo" then
        if #draft.checkpoints == 0 then return false, "No checkpoint to remove." end
        table.remove(draft.checkpoints)
        message = ("Checkpoint removed (%d left)."):format(#draft.checkpoints)
    elseif action == "undogrid" then
        if #draft.grid == 0 then return false, "No grid slot to remove." end
        table.remove(draft.grid)
        message = ("Grid slot removed (%d left)."):format(#draft.grid)
    elseif action == "name" then
        local name = tostring(value or ""):gsub("[%c]", " "):sub(1, Limits.maximumNameBytes)
        if #name < 3 then return false, "name_too_short" end
        draft.name = name
        message = "Name set."
    elseif action == "laps" then
        local laps = math.tointeger(tonumber(value))
        if laps == nil or laps < Limits.minimumLaps or laps > Limits.maximumLaps then return false, "invalid_laps" end
        draft.laps = laps
        message = ("Laps: %d."):format(laps)
    elseif action == "type" then
        local kind = tostring(value or ""):lower()
        if kind ~= "circuit" and kind ~= "sprint" then return false, "invalid_type" end
        draft.type = kind
        if kind == "sprint" then draft.laps = 1 end
        message = "Type: " .. kind .. "."
    elseif action == "parkour" then
        local switch = tostring(value or ""):lower()
        if switch ~= "on" and switch ~= "off" then return false, "invalid_parkour" end
        if switch == "on" and not foot then return false, "parkour_on_foot" end
        draft.parkour = switch == "on" or nil
        message = "Parkour course: " .. switch .. "."
    elseif action == "radius" then
        local radius = S.finite(value)
        if radius == nil or radius < Limits.minimumRadius or radius > Limits.maximumRadius then return false, "invalid_checkpoint_radius" end
        draft.checkpointRadius = radius
        message = ("Checkpoint radius: %.1f m."):format(radius)
    elseif action == "vehicle" then
        local vehicle = RaceCourses.vehicle(value)
        if vehicle == nil then return false, "invalid_vehicle" end
        if (vehicle.id == "on_foot") ~= foot then
            return false, "A course stays on foot or in a car. Open a new one to switch."
        end
        draft.vehicle = vehicle.id
        message = "Vehicle: " .. vehicle.label .. "."
    elseif action == "save" then
        local name = Open77.players.name(playerId) or "Staff"
        local saved, reason = RaceCourses.save(playerId, draft, name, nil)
        if saved == nil then return false, reason end
        session.draft = saved
        log(("player %d saved course %s revision %d"):format(playerId, saved.id, saved.revision))
        message = ("Saved as %s (revision %d)."):format(saved.id, saved.revision)
    else
        return false, "unknown_action"
    end
    Ed.push(playerId, message)
    return true, message
end

function Ed.forget(playerId) sessions[playerId] = nil end
