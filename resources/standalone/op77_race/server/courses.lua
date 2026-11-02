-- Course catalogue: the built-in courses (server/builtin_courses.lua) plus the ones the
-- staff saves with the editor (data/courses/<id>.json through Open77.io). Coordinates
-- never come from a browser: the editor captures them from server positions and this
-- module validates every course, built-in or file, before it enters the catalogue.
local Config = RaceConfig
local Limits = Config.editor
local S = RaceShared

RaceCourses = {}
local C = RaceCourses

local courses = {}
local storage = { ready = false, error = nil }
local DIRECTORY = "courses"
local SCHEMA = 2
local sequence = 0

local function log(text) print("[race:courses] " .. tostring(text)) end

local function integer(value)
    local number = S.finite(value)
    if number == nil or number % 1 ~= 0 then return nil end
    return number
end

local function text(value, maximum)
    if type(value) ~= "string" then value = "" end
    value = value:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value > maximum then value = value:sub(1, maximum) end
    return value
end

local function heading(value)
    local h = (S.finite(value) or 0.0) % 360.0
    if h < 0.0 then h = h + 360.0 end
    return h
end

local function position(value)
    if type(value) ~= "table" then return nil end
    local x, y, z = S.finite(value.x), S.finite(value.y), S.finite(value.z)
    if x == nil or y == nil or z == nil then return nil end
    if math.abs(x) > 100000.0 or math.abs(y) > 100000.0 or math.abs(z) > 100000.0 then return nil end
    return { x = x, y = y, z = z }
end

function C.vehicle(id)
    id = tostring(id or "")
    for _, definition in ipairs(Config.engine.vehicles) do
        if definition.id == id then return definition end
    end
    return nil
end

function C.vehicles()
    local list = {}
    for _, definition in ipairs(Config.engine.vehicles) do list[#list + 1] = { id = definition.id, label = definition.label } end
    return list
end

function C.validId(value)
    return type(value) == "string" and #value >= 1 and #value <= 64 and value:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function normalizeGrid(value, required)
    if value == nil then
        if required then return nil, "grid_missing" end
        return {}
    end
    if type(value) ~= "table" then return nil, "grid_expected" end
    if required and #value < Limits.minimumGridSlots then return nil, "not_enough_grid_slots" end
    local grid = {}
    for index, slot in ipairs(value) do
        if type(slot) ~= "table" then return nil, "invalid_grid_slot" end
        local p = position(slot.position)
        if p == nil then return nil, "invalid_grid_position" end
        for previous = 1, #grid do
            if S.distance(p, grid[previous].position) < Limits.minimumGridSpacing then return nil, "grid_slots_overlap" end
        end
        grid[index] = { position = p, heading = heading(slot.heading) }
    end
    return grid
end

-- A clean course, or nil and a reason. Vehicle courses need surveyed grid slots.
function C.normalize(input, metadata)
    if type(input) ~= "table" then return nil, "course_expected" end
    metadata = metadata or {}
    local name = text(input.name, Limits.maximumNameBytes)
    if #name < 3 then return nil, "name_too_short" end
    local courseType = tostring(input.type or "circuit"):lower()
    if courseType ~= "circuit" and courseType ~= "sprint" then return nil, "invalid_type" end
    local laps = integer(input.laps) or 1
    if courseType == "sprint" then laps = 1 end
    if laps < Limits.minimumLaps or laps > Limits.maximumLaps then return nil, "invalid_laps" end
    local radius = S.finite(input.checkpointRadius) or Config.engine.checkpointRadius
    if radius < Limits.minimumRadius or radius > Limits.maximumRadius then return nil, "invalid_checkpoint_radius" end
    local vehicleId = input.vehicle
    if vehicleId == nil or vehicleId == "" then vehicleId = Config.engine.vehicle.default end
    local vehicle = C.vehicle(vehicleId)
    if vehicle == nil then return nil, "invalid_vehicle" end
    local start = type(input.start) == "table" and input.start or nil
    local startPosition = start and position(start.position)
    if startPosition == nil then return nil, "start_missing" end
    local grid, gridReason = normalizeGrid(input.grid, vehicle.id ~= "on_foot")
    if grid == nil then return nil, gridReason end
    if vehicle.id == "on_foot" then grid = {} end
    if type(input.checkpoints) ~= "table" then return nil, "checkpoints_expected" end
    local count = #input.checkpoints
    local minimum = courseType == "sprint" and Limits.minimumCheckpoints or math.max(2, Limits.minimumCheckpoints)
    if count < minimum then return nil, "not_enough_checkpoints" end
    if count > Limits.maximumCheckpoints then return nil, "too_many_checkpoints" end
    local checkpoints = {}
    for index, checkpoint in ipairs(input.checkpoints) do
        if type(checkpoint) ~= "table" then return nil, "invalid_checkpoint" end
        local p = position(checkpoint.position)
        if p == nil then return nil, "invalid_checkpoint_position" end
        local own = checkpoint.radius ~= nil and S.finite(checkpoint.radius) or nil
        if own ~= nil and (own < Limits.minimumRadius or own > Limits.maximumRadius) then
            return nil, "invalid_checkpoint_radius"
        end
        checkpoints[index] = {
            id = ("cp_%03d"):format(index),
            position = p,
            heading = heading(checkpoint.heading),
            radius = own,
        }
    end
    return {
        id = metadata.id or input.id,
        name = name,
        description = text(input.description, Limits.maximumDescriptionBytes),
        type = courseType,
        laps = laps,
        checkpointRadius = radius,
        vehicle = vehicle.id,
        start = { position = startPosition, heading = heading(start.heading) },
        grid = grid,
        checkpoints = checkpoints,
        builtin = metadata.builtin == true,
        authorId = metadata.authorId,
        authorName = metadata.authorName,
        revision = integer(metadata.revision or input.revision) or 1,
    }
end

function C.capacity(course, maximum)
    if course == nil then return 0 end
    maximum = maximum or 8
    if S.onFoot(course) then return maximum end
    return math.min(maximum, #(course.grid or {}))
end

function C.summary(course)
    local vehicle = C.vehicle(course.vehicle) or {}
    return {
        id = course.id,
        name = course.name,
        description = course.description,
        type = course.type,
        laps = course.laps,
        onFoot = S.onFoot(course),
        vehicle = course.vehicle,
        vehicleLabel = vehicle.label,
        checkpointCount = #course.checkpoints,
        gridCount = #(course.grid or {}),
        metres = S.routeMetres(course) * course.laps,
        builtin = course.builtin == true,
        revision = course.revision,
    }
end

-- The stored course. Callers must not modify it; get() returns a copy.
function C.raw(id) return courses[tostring(id or "")] end
function C.get(id)
    local course = courses[tostring(id or "")]
    return course and S.clone(course) or nil
end

local function sortedIds(filter)
    local ids = {}
    for id, course in pairs(courses) do
        if filter == nil or filter(course) then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        local ca, cb = courses[a], courses[b]
        if ca.builtin ~= cb.builtin then return ca.builtin end
        if ca.name:lower() ~= cb.name:lower() then return ca.name:lower() < cb.name:lower() end
        return a < b
    end)
    return ids
end

-- Which courses an activity mode can run: the trial runs every course, a street race
-- needs a vehicle course with at least two surveyed slots, a rooftop race an on-foot one.
function C.eligible(course, mode)
    if course == nil then return false end
    if mode == "trial" then return true end
    if mode == "foot" then return S.onFoot(course) end
    if mode == "grid" then return not S.onFoot(course) and #(course.grid or {}) >= 2 end
    return false
end

function C.ids(mode)
    return sortedIds(mode and function(course) return C.eligible(course, mode) end or nil)
end

function C.list(mode)
    local list = {}
    for _, id in ipairs(C.ids(mode)) do list[#list + 1] = C.summary(courses[id]) end
    return list
end

-- A course for the next heat: random among the eligible ones, avoiding an immediate
-- repeat when there is a choice.
function C.pick(mode, avoidId, random)
    local ids = C.ids(mode)
    if #ids == 0 then return nil end
    if #ids > 1 and avoidId ~= nil then
        for index = #ids, 1, -1 do if ids[index] == avoidId then table.remove(ids, index) end end
    end
    random = random or math.random
    return C.get(ids[random(#ids)])
end

function C.storageState() return { ready = storage.ready, error = storage.error } end

local function newId(name, playerId)
    local slug = tostring(name or "course"):lower():gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if slug == "" then slug = "course" end
    slug = slug:sub(1, 36)
    local id
    repeat
        sequence = sequence + 1
        local suffix = ("-%d-%d"):format(playerId or 0, sequence)
        id = slug:sub(1, 64 - #suffix) .. suffix
    until courses[id] == nil
    return id
end

local function persist(course)
    local payload = S.clone(course)
    payload.schemaVersion = SCHEMA
    payload.builtin = nil
    local ok, reason = Open77.io.writeJson(("%s/%s.json"):format(DIRECTORY, course.id), payload)
    if not ok then
        storage.ready, storage.error = false, tostring(reason or "write_failed")
        return false, storage.error
    end
    storage.ready, storage.error = true, nil
    return true
end

-- Saves an editor draft (a new course, or a new revision of a saved one). Built-in
-- courses are read-only: a draft loaded from one is saved as a copy.
function C.save(playerId, draft, authorName, authorId)
    if type(draft) ~= "table" then return nil, "course_expected" end
    local existing = C.validId(draft.id) and courses[draft.id] or nil
    if existing and existing.builtin then existing = nil end
    local id = existing and existing.id or newId(draft.name, playerId)
    local course, reason = C.normalize(draft, {
        id = id,
        authorId = existing and existing.authorId or authorId,
        authorName = existing and existing.authorName or authorName,
        revision = existing and (existing.revision + 1) or 1,
    })
    if course == nil then return nil, reason end
    local ok, why = persist(course)
    if not ok then return nil, "storage_write_failed:" .. tostring(why) end
    courses[id] = course
    return S.clone(course)
end

function C.remove(id)
    id = tostring(id or "")
    local course = courses[id]
    if course == nil then return false, "course_not_found" end
    if course.builtin then return false, "builtin_readonly" end
    local ok, reason = Open77.io.remove(("%s/%s.json"):format(DIRECTORY, id))
    if not ok and reason ~= "not_found" then return false, "storage_delete_failed:" .. tostring(reason) end
    courses[id] = nil
    return true
end

function C.load()
    courses = {}
    local builtins = 0
    for _, input in ipairs(RaceBuiltinCourses or {}) do
        local course, reason = C.normalize(input, { id = input.id, builtin = true, revision = input.revision })
        if course and C.validId(course.id) then
            courses[course.id] = course
            builtins = builtins + 1
        else
            log(("built-in course %s rejected: %s"):format(tostring(input.id), tostring(reason or "invalid_id")))
        end
    end
    local loaded = 0
    local made, makeReason = Open77.io.makeDirectory(DIRECTORY)
    local entries, listReason = nil, nil
    if made then entries, listReason = Open77.io.list(DIRECTORY) end
    if not made or entries == nil then
        storage.ready, storage.error = false, tostring(makeReason or listReason or "unavailable")
        log("course storage unavailable (built-ins only): " .. storage.error)
    else
        for _, entry in ipairs(entries) do
            local fileId = entry.type == "file" and type(entry.name) == "string" and entry.name:match("^([a-z0-9][a-z0-9_-]*)%.json$") or nil
            if C.validId(fileId) and courses[fileId] == nil then
                local input, readReason = Open77.io.readJson(("%s/%s"):format(DIRECTORY, entry.name))
                if input == nil then
                    log(("course file %s unreadable: %s"):format(entry.name, tostring(readReason)))
                elseif input.schemaVersion ~= SCHEMA then
                    log(("course file %s rejected: unsupported schema"):format(entry.name))
                else
                    local course, invalid = C.normalize(input, { id = fileId, authorId = input.authorId,
                        authorName = input.authorName, revision = input.revision })
                    if course then courses[fileId] = course; loaded = loaded + 1
                    else log(("course file %s rejected: %s"):format(entry.name, tostring(invalid))) end
                end
            elseif fileId and courses[fileId] and courses[fileId].builtin then
                log(("course file %s ignored: it would shadow a built-in course"):format(entry.name))
            end
        end
        storage.ready, storage.error = true, nil
    end
    log(("%d built-in and %d saved course(s)"):format(builtins, loaded))
    return builtins + loaded
end
