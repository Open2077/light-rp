-- What the racer sees of the next checkpoint: a native marker (raised chevron for a
-- car, landing ring and arrow on foot, Freeroam's proven shapes), and on op77_map3d a
-- pinned blip plus, in a car, the GPS route. Purely visual: the server alone accepts
-- crossings, from its own positions. Also the editor's preview of a draft course.
local Config = RaceConfig

RaceMarkers = {}
local M = RaceMarkers

local YELLOW = { r = 255, g = 204, b = 0, a = 220 }
local WHITE = { r = 240, g = 243, b = 246, a = 220 }

local handles = {}          -- running checkpoint markers
local signature, retryAt = nil, 0
local blipId, waypointSet, previousWaypoint = nil, false, nil
local previewHandles = {}

local function log(level, text)
    if Open77.log and Open77.log[level] then Open77.log[level]("[race] " .. tostring(text)) end
end

-- op77_map3d exports: synchronous, raise when the map is not running. Returns
-- whether the call ran, then the export's own result.
local function map(method, ...)
    local ok, result = pcall(function(...)
        local resource = exports[Config.map.resource]
        return resource[method](resource, ...)
    end, ...)
    return ok, result
end
M.map = map

local function removeMarkers()
    for _, handle in ipairs(handles) do Open77.markers.remove(handle) end
    handles = {}
end

-- Marker definitions for one target. Returns a list of option tables.
function M.definitions(point, onFoot, finish, distance)
    local p = point.position
    local color = finish and WHITE or YELLOW
    if onFoot then
        local radius = tonumber(point.radius) or 3.0
        return {
            { position = { x = p.x, y = p.y, z = p.z + 0.08 }, shape = "cylinder", radius = radius, height = 0.35,
                maxDistance = distance, color = color },
            { position = { x = p.x, y = p.y, z = p.z + 2.0 }, shape = finish and "diamond" or "arrow", radius = 0.65,
                height = 1.25, maxDistance = distance, color = color },
        }
    end
    local visual = Config.visuals.checkpointMarker or {}
    return {
        { position = { x = p.x, y = p.y, z = p.z + (tonumber(visual.lift) or 3.0) }, shape = "chevron",
            radius = tonumber(visual.radius) or 2.5, height = tonumber(visual.height) or 3.5,
            rotation = { x = 0, y = 0, z = tonumber(point.heading) or 0 },
            maxDistance = distance, color = color },
    }
end

local function syncBlip(next, onFoot)
    local options = {
        position = { x = next.position.x, y = next.position.y, z = next.position.z },
        icon = next.finish and "flag" or "target",
        color = next.finish and Config.map.finishColor or Config.map.color,
        label = next.finish and "Finish" or ("Checkpoint %d"):format(next.index or 0),
        category = Config.map.category,
        edge = true, pulse = true, routable = not onFoot,
    }
    if blipId ~= nil then
        local ran, updated = map("updateBlip", blipId, options)
        if ran and updated == true then return end
        map("removeBlip", blipId)
        blipId = nil
    end
    local ran, id = map("addBlip", options)
    if ran and id ~= nil then blipId = id end
end

local function syncRoute(next, onFoot)
    if onFoot or Config.map.routeVehicles == false then return end
    if not waypointSet then
        local ran, current = map("getWaypoint")
        previousWaypoint = ran and type(current) == "table" and { x = current.x, y = current.y, z = current.z } or nil
    end
    local ran, set = map("setWaypoint", { x = next.position.x, y = next.position.y, z = next.position.z })
    if ran and set ~= false then waypointSet = true end
end

function M.clear()
    removeMarkers()
    signature, retryAt = nil, 0
    if blipId ~= nil then map("removeBlip", blipId) end
    blipId = nil
    if waypointSet then
        -- Give the player their own waypoint back.
        if type(previousWaypoint) == "table" and previousWaypoint.x then map("setWaypoint", previousWaypoint)
        else map("clearWaypoint") end
    end
    waypointSet, previousWaypoint = false, nil
end

-- state: the race payload (op77_race:state), or nil.
function M.sync(state)
    local next = state and state.next
    local guided = state and (state.state == "loading" or state.state == "countdown" or state.state == "racing")
    if Config.visuals.enabled == false or not guided or type(next) ~= "table" or type(next.position) ~= "table" then
        M.clear()
        return
    end
    local onFoot = state.course and state.course.onFoot == true
    local p = next.position
    local key = table.concat({ tostring(state.instance), tostring(state.run), tostring(state.lap), tostring(next.index),
        tostring(next.finish), tostring(onFoot), tostring(p.x), tostring(p.y), tostring(p.z) }, ":")
    if key == signature then
        for _, handle in ipairs(handles) do
            local snapshot = Open77.markers.get(handle)
            if snapshot == nil or snapshot.failed then
                log("warn", "checkpoint marker lost: " .. tostring(snapshot and snapshot.error or "marker_not_found"))
                removeMarkers()
                signature, retryAt = nil, Open77.time.monotonic() + 2.0
                break
            end
        end
        if signature ~= nil then return end
    end
    if Open77.time.monotonic() < retryAt then return end
    removeMarkers()
    local distance = Config.visuals.checkpointViewDistance or 180.0
    for _, options in ipairs(M.definitions(next, onFoot, next.finish == true, distance)) do
        local handle, reason = Open77.markers.create(options)
        if handle == nil then
            log("warn", "checkpoint marker unavailable: " .. tostring(reason))
            removeMarkers()
            retryAt = Open77.time.monotonic() + 1.0
            return
        end
        handles[#handles + 1] = handle
    end
    signature = key
    syncBlip(next, onFoot)
    syncRoute(next, onFoot)
end

-- ---------------------------------------------------------------- editor --

function M.clearPreview()
    for _, handle in ipairs(previewHandles) do Open77.markers.remove(handle) end
    previewHandles = {}
end

-- Start (diamond), grid slots (arrows) and the latest checkpoints, within budget.
function M.preview(draft)
    M.clearPreview()
    if type(draft) ~= "table" then return end
    local budget = Config.editor.previewMarkers or 24
    local distance = Config.visuals.checkpointViewDistance or 180.0
    local onFoot = draft.vehicle == "on_foot"
    local function add(options)
        if #previewHandles >= budget then return end
        local handle = Open77.markers.create(options)
        if handle then previewHandles[#previewHandles + 1] = handle end
    end
    if type(draft.start) == "table" and type(draft.start.position) == "table" then
        local p = draft.start.position
        add({ position = { x = p.x, y = p.y, z = p.z + 2.0 }, shape = "diamond", radius = 0.8, height = 1.4,
            maxDistance = distance, color = WHITE })
    end
    for _, slot in ipairs(draft.grid or {}) do
        local p = slot.position
        add({ position = { x = p.x, y = p.y, z = p.z + 1.5 }, shape = "arrow", radius = 0.6, height = 1.0,
            rotation = { x = 0, y = 0, z = tonumber(slot.heading) or 0 }, maxDistance = distance,
            color = { r = 63, g = 224, b = 208, a = 200 } })
    end
    local checkpoints = draft.checkpoints or {}
    local first = math.max(1, #checkpoints - (budget - #previewHandles) + 1)
    for index = first, #checkpoints do
        local point = checkpoints[index]
        point.radius = point.radius or draft.checkpointRadius
        for _, options in ipairs(M.definitions(point, onFoot, index == #checkpoints, distance)) do add(options) end
    end
end
