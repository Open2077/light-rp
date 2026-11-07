local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- The Crossing: the activities hub on the Westbrook esplanade where newcomers
-- arrive (server/config/activities.lua). A terminal beside the arrival point
-- opens the Activities panel (with its map pin); its Contracts tab lists the
-- mission boards of the city, with a GPS route to each (the boards themselves
-- work as before). A `kind = "contracts"` terminal opens the panel on that tab, a `kind = "rooms"`
-- one the hosting menu (activity_rooms.lua). A terminal with `npc = true` has an NPC standing on
-- it instead of a floor marker: its own `host`, else the hub's. A terminal's own `blip` is its map
-- pin. It also points
-- newcomers to The Crossing once their first day ends, and gives staff a survey command.
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

-- Where The Crossing's routes lead: the activities terminal (the hub's center is the
-- arrival point, the terminal may stand away from it).
function Hub.anchor()
    for _, terminal in ipairs(H.terminals) do
        if terminal.kind == "activities" then return Hub.placeOf(terminal) end
    end
    return H.center
end

local function register()
    if not C.enabled then return end
    for index, terminal in ipairs(H.terminals) do
        local id = "activities." .. terminal.id
        local pin = terminal.blip or (terminal.kind == "activities" and H.blip) or nil
        local blip
        if pin then
            blip = { sprite = "objective", icon = "swords", title = pin.title, description = pin.description,
                mapCategory = pin.mapCategory, mapColor = pin.mapColor, map = pin.map }
        end
        -- a host NPC stands on it: no floor marker, the prompt at his chest
        local marker, promptHeight = H.marker, nil
        local host = terminal.host or H.host
        if terminal.npc and type(host) == "table" then marker, promptHeight = nil, host.promptHeight end
        Hub.points[id] = { kind = terminal.kind, index = index }
        LightRP.interaction(id, { position = Hub.placeOf(terminal), radius = H.interactRadius or 2.0, bucket = H.bucket or 0,
            label = terminal.label, prompt = terminal.prompt, key = "E", marker = marker, promptHeight = promptHeight,
            ring = false, blip = blip })
    end
end
if LightRP.batchInteractions then LightRP.batchInteractions(register) else register() end

-- ---------------------------------------------------------------------------
-- The host: an NPC standing on each `npc = true` terminal (its own `host`, else the hub's),
-- facing its heading. Spawned as
-- Johnny is (server/modules/guide.lua): records tried in order, AI off, invulnerable, no
-- combat, perception or voice, and respawned if a cleanup removes him.

Hub.hosts = {} -- terminal id -> NPC id

function Hub.spawnHost(terminal)
    local host = terminal.host or H.host
    if type(host) ~= "table" or type(Open77.npcs) ~= "table" or type(Open77.npcs.create) ~= "function" then return nil end
    local at = Hub.placeOf(terminal)
    local yaw = tonumber(terminal.heading) or tonumber(H.heading) or 0
    for _, candidate in ipairs(host.candidates or {}) do
        local definition = {
            record = candidate.record, position = { x = at.x, y = at.y, z = at.z }, yaw = yaw, bucket = H.bucket or 0,
            persistent = false, despawnWhenUnobserved = false, streamingRadius = host.streamingRadius or 150.0,
            behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
        }
        if candidate.appearance then definition.appearance = candidate.appearance end
        if type(Open77.npcs.damage) == "table" then definition.damagePolicy = Open77.npcs.damage.invulnerable or Open77.npcs.damage.immortal end
        if type(Open77.npcs.ai) == "table" then definition.aiMode = Open77.npcs.ai.tasks end
        local ok, npcId, reason = pcall(Open77.npcs.create, definition)
        if ok and npcId then
            if type(Open77.npcs.setAIEnabled) == "function" then
                local stillOk, stillErr = pcall(Open77.npcs.setAIEnabled, npcId, false)
                if not stillOk or stillErr == false then LightRP.log("activities: setAIEnabled refused: %s", tostring(stillErr)) end
            end
            LightRP.log("activities: %s spawned as NPC %s (%s, AI off) at %.2f, %.2f, %.2f heading %.1f", tostring(host.name),
                tostring(npcId), tostring(candidate.record), at.x, at.y, at.z, yaw)
            return npcId
        end
        LightRP.log("activities: %s refused (%s), trying the next record", tostring(candidate.record), tostring(ok and reason or npcId))
    end
    LightRP.log("activities: no record accepted for %s; the terminal still works", tostring(host.name))
    return nil
end

function Hub.spawnHosts()
    if not C.enabled then return end
    for _, terminal in ipairs(H.terminals) do
        if terminal.npc then
            local old = Hub.hosts[terminal.id]
            if old and type(Open77.npcs.remove) == "function" then pcall(Open77.npcs.remove, old) end
            Hub.hosts[terminal.id] = Hub.spawnHost(terminal)
        end
    end
end

CreateThread(function()
    if not C.enabled then return end
    Wait(900) -- after the platform's start-up, like Johnny and the desks
    Hub.spawnHosts()
    lightrpEvery(60000, function()
        
        for _, terminal in ipairs(H.terminals) do
            local id = Hub.hosts[terminal.id]
            if id and type(Open77.npcs.get) == "function" then
                local ok, snapshot = pcall(Open77.npcs.get, id)
                if ok and snapshot == nil then
                    LightRP.log("activities: host NPC %s is gone, respawning", tostring(id))
                    Hub.hosts[terminal.id] = Hub.spawnHost(terminal)
                end
            end
        end
    end, "activities_hub:108")
end)

function Hub.onInteract(playerId, pointId)
    local point = Hub.points[pointId]
    if not point then return end
    if point.kind == "rooms" then
        LightRP.activityRooms.open(playerId)
        return
    end
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
        gps(playerId, Hub.anchor(), H.name, "Activities: arena, races, chases, events")
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
            gps(playerId, Hub.anchor(), H.name, "Activities: arena, races, chases, events")
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
