-- The Crossing: the activities hub on the Westbrook esplanade where newcomers
-- arrive (server/config/activities.lua). Two terminals beside the arrival point:
-- the activities board (the Activities panel, with its map pin) and the
-- contracts board (the mission boards of the city, with a GPS route to each;
-- the mission boards themselves work as before). It also points newcomers to
-- The Crossing once their first day ends, and gives staff a survey command.
local C = LightRpActivities
local H = C.hub
local E = LightRpEvents
local A = LightRP.activities
local Hub = LightRP.module("activitiesHub", { points = {} })

-- A terminal's place: its surveyed `position`, or its offset along the hub's heading.
-- Heading: degrees about +Z, counter-clockwise seen from above, 0 facing +Y.
function Hub.placeOf(terminal)
    if type(terminal.position) == "table" then return terminal.position end
    local o = terminal.offset or {}
    local h = math.rad(tonumber(H.heading) or 0)
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = math.cos(h), math.sin(h)
    local forward, right = tonumber(o.forward) or 0, tonumber(o.right) or 0
    return { x = H.center.x + fx * forward + rx * right, y = H.center.y + fy * forward + ry * right, z = H.center.z + (tonumber(o.up) or 0) }
end

local function register()
    if not C.enabled then return end
    for index, terminal in ipairs(H.terminals) do
        local id = "activities." .. terminal.id
        local blip
        if terminal.kind == "activities" and H.blip then
            blip = { sprite = "objective", icon = "swords", title = H.blip.title, description = H.blip.description,
                mapCategory = H.blip.mapCategory, mapColor = H.blip.mapColor, map = H.blip.map }
        end
        Hub.points[id] = { kind = terminal.kind, index = index }
        LightRP.interaction(id, { position = Hub.placeOf(terminal), radius = H.interactRadius or 2.0, bucket = H.bucket or 0,
            label = terminal.label, prompt = terminal.prompt, key = "E", marker = H.marker, ring = false, blip = blip })
    end
end
if LightRP.batchInteractions then LightRP.batchInteractions(register) else register() end

function Hub.onInteract(playerId, pointId)
    local point = Hub.points[pointId]
    if not point then return end
    A.watch(playerId)
    LightRP.state(playerId, "activities")
    LightRP.dialog(playerId, "activities", { tab = point.kind == "contracts" and "contracts" or "activities" })
end

-- ---------------------------------------------------------------------------
-- Contracts: the city's mission boards (config points and published ones), never
-- the fixers' gigs (they have no board) nor a withdrawn board.

local function boardIds()
    local ids, seen = {}, {}
    local function add(id) if type(id) == "string" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    for _, point in ipairs((LightRpMissions or {}).points or {}) do add(point.id) end
    local editor = LightRP.missionEditor
    if editor and type(editor.records) == "table" then
        local published = {}
        for id in pairs(editor.records) do published[#published + 1] = id end
        table.sort(published)
        for _, id in ipairs(published) do add(id) end
    end
    return ids
end

function Hub.contracts(playerId)
    local M = LightRP.missions
    local list = {}
    if not M or type(M.point) ~= "function" then return list end
    local at = playerId and Open77.players.position(playerId)
    for _, id in ipairs(boardIds()) do
        local p = M.point(id)
        if p and not p.fixer and not p.retired and type(p.position) == "table" then
            local distance
            if at and (at.bucket or 0) == 0 then
                distance = math.floor(math.sqrt((at.x - p.position.x) ^ 2 + (at.y - p.position.y) ^ 2 + (at.z - p.position.z) ^ 2) + 0.5)
            end
            list[#list + 1] = { id = p.id, title = tostring(p.title or p.id), type = tostring(p.type or "CONTRACT"),
                location = tostring(p.location or ""), description = type(p.description) == "string" and p.description or "",
                distance = distance }
        end
    end
    table.sort(list, function(x, y)
        if x.distance and y.distance and x.distance ~= y.distance then return x.distance < y.distance end
        return x.title < y.title
    end)
    return list
end

-- The hub and the contracts ride along in the `activities` state.
A.extensions[#A.extensions + 1] = function(playerId, state)
    state.hub = { name = H.name, position = H.center }
    state.contracts = Hub.contracts(playerId)
end

local function gps(playerId, position, title, description)
    TriggerClientEvent(E.net.activitiesGps, playerId, { position = position, title = title, description = description })
end
Hub.gps = gps

-- `activities.control { operation = "gps", id }`: a route to a contract board, or
-- to The Crossing itself (id "hub").
A.operations.gps = function(playerId, payload)
    local id = type(payload.id) == "string" and payload.id or ""
    if id == "hub" then
        gps(playerId, H.center, H.name, "Activities: arena, races, chases, events")
        return true, "GPS set: " .. H.name .. "."
    end
    local M = LightRP.missions
    local p = M and type(M.point) == "function" and M.point(id)
    if not p or p.fixer or p.retired or type(p.position) ~= "table" then return false, "That contract board is gone." end
    gps(playerId, p.position, p.title or "Contract", (p.type or "CONTRACT") .. " · " .. (p.location or ""))
    return true, "GPS set: " .. tostring(p.title or "contract board") .. "."
end

-- ---------------------------------------------------------------------------
-- The first day ends (finished or skipped): where activities start.

function Hub.onTutorialDone(playerId)
    local notice = C.firstDayNotice
    if not C.enabled or not notice then return end
    SetTimeout(notice.delayMs or 8000, function()
        if not LightRP.characters.isRegistered(playerId) then return end
        LightRP.notice(playerId, { kind = "info", title = notice.title, body = notice.body, durationMs = 14000 })
        -- far from it (no city point after the guide): the route there
        local at = Open77.players.position(playerId)
        if at and (at.bucket or 0) == 0 and ((at.x - H.center.x) ^ 2 + (at.y - H.center.y) ^ 2) > 60 ^ 2 then
            gps(playerId, H.center, H.name, "Activities: arena, races, chases, events")
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Staff: where am I, in the format of server/config/activities.lua.

LightRP.command("lightrp.survey", { restricted = true, usage = "/lightrp.survey [label]" }, function(source, args)
    if not source or source <= 0 then return false, "In game only." end
    local read = type(Open77.players.get) == "function" and Open77.players.get(source) or nil
    local p = type(read) == "table" and read.position or Open77.players.position(source)
    if type(p) ~= "table" or type(p.x) ~= "number" then return false, "Your position is not available yet." end
    local heading = type(read) == "table" and tonumber(read.heading or read.yaw) or 0
    local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(source) or p.bucket or 0
    local label = LightRP.joinArgs(args)
    local line = string.format("position = { x = %.3f, y = %.3f, z = %.3f }, heading = %.1f, -- bucket %d%s",
        p.x, p.y, p.z, heading, tonumber(bucket) or 0, label ~= "" and (" · " .. label) or "")
    LightRP.log("survey by %s: %s", LightRP.characters.displayName(source), line)
    return true, line
end)
