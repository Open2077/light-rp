-- Proximity interactions. A module registers a world point once; every client
-- gets the list (a configured 3D marker or ground ring, and a WebUI "E" prompt) and
-- presses E. The server re-checks the distance from its own position feed and
-- fans the press out to the modules: `onInteract(playerId, id, definition)`.
--
--   LightRP.interaction("rental.citycenter", {
--       position = { x, y, z }, radius = 2.5, label = "Rent-a-Ride", prompt = "Rent a vehicle", key = "E",
--   })
--   LightRP.dialog(playerId, "rental", payload)   -- open a page dialog (lightrp:ui:dialog)
local E = LightRpEvents
local interactions = {}   -- id -> definition
local order = {}          -- ids in registration order (stable client list)
local batchDepth, batchDirty = 0, false

function LightRP.batchInteractions(fn)
    batchDepth = batchDepth + 1
    local result = table.pack(pcall(fn))
    batchDepth = batchDepth - 1
    if batchDepth == 0 and batchDirty then batchDirty = false; LightRP.broadcastInteractions() end
    if not result[1] then error(result[2]) end
    return table.unpack(result, 2, result.n)
end

function LightRP.interaction(id, definition)
    assert(type(id) == "string" and type(definition) == "table" and type(definition.position) == "table", "LightRP.interaction(id, { position = ... })")
    if interactions[id] == nil then order[#order + 1] = id end
    definition.id = id
    definition.radius = tonumber(definition.radius) or 2.5
    definition.key = definition.key or "E"
    interactions[id] = definition
    LightRP.broadcastInteractions()
    return definition
end

function LightRP.removeInteraction(id)
    if interactions[id] == nil then return end
    interactions[id] = nil
    for i, key in ipairs(order) do if key == id then table.remove(order, i) break end end
    LightRP.broadcastInteractions()
end

local function clientList(playerId)
    local list = {}
    local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(playerId) or 0
    local position=Open77.players.position(playerId)
    local groups,selected={},{}
    for index,id in ipairs(order) do
        local d=interactions[id]
        if d and d.streamGroup and (d.bucket==nil or d.bucket==bucket) then
            local group=groups[d.streamGroup] or {limit=math.min(32,math.max(1,math.floor(tonumber(d.streamLimit) or 32))),points={}}
            groups[d.streamGroup]=group
            local p=d.position
            local distance=position and ((position.x-p.x)^2+(position.y-p.y)^2+(position.z-p.z)^2) or index
            group.points[#group.points+1]={id=id,distance=distance,index=index}
        end
    end
    for _,group in pairs(groups) do
        table.sort(group.points,function(a,b)if a.distance==b.distance then return a.index<b.index end;return a.distance<b.distance end)
        for i=1,math.min(group.limit,#group.points)do selected[group.points[i].id]=true end
    end
    for _, id in ipairs(order) do
        local d = interactions[id]
        if d and (d.bucket == nil or d.bucket == bucket) and (not d.streamGroup or selected[id]) then
            list[#list + 1] = { id = id, position = d.position, radius = d.radius, label = d.label, prompt = d.prompt, key = d.key,
                promptHeight = d.promptHeight, marker = d.marker, ring = d.ring, blip = d.blip }
        end
    end
    return list
end

function LightRP.sendInteractions(playerId)
    TriggerClientEvent(E.net.interactions, playerId, clientList(playerId))
end

function LightRP.broadcastInteractions()
    if batchDepth > 0 then batchDirty = true; return end
    for _, id in ipairs(GetPlayers()) do TriggerClientEvent(E.net.interactions, id, clientList(id)) end
end

function LightRP.dialog(playerId, kind, payload)
    payload = payload or {}
    payload.kind = kind
    TriggerClientEvent(E.net.dialog, playerId, payload)
end

local function within(playerId, definition, slack)
    local p = Open77.players.position(playerId)
    if p == nil then return false end
    if definition.bucket ~= nil and (p.bucket or 0) ~= definition.bucket then return false end
    local dx, dy, dz = p.x - definition.position.x, p.y - definition.position.y, p.z - definition.position.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= (definition.radius + (slack or 1.5))
end
LightRP.nearInteraction = within

local lastPress = {}
RegisterNetEvent(E.net.interact, function(id)
    local playerId = source
    local definition = type(id) == "string" and interactions[id] or nil
    if definition == nil then return end
    local now = LightRP.nowMs()
    if lastPress[playerId] and now - lastPress[playerId] < 400 then return end
    lastPress[playerId] = now
    if not within(playerId, definition) then return end
    LightRP.eachModule("onInteract", playerId, id, definition)
end)

-- The list is per routing bucket: a player who changes bucket (the arrival
-- hall of the first day guide, a private scene) gets the points of the new one.
AddEventHandler("onPlayerBucketChange", function(playerId)
    playerId = tonumber(playerId)
    if playerId ~= nil and playerId > 0 then LightRP.sendInteractions(playerId) end
end)

local Interact = LightRP.module("interact", {})
function Interact.onGameplayReady(playerId) LightRP.sendInteractions(playerId) end
function Interact.onDisconnected(playerId) lastPress[playerId] = nil end
