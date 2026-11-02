-- Proximity interactions. A module registers a world point once; every client
-- gets the list (a configured 3D marker or ground ring, and a WebUI "E" prompt) and
-- presses E. The server re-checks the distance from its own position feed and
-- fans the press out to the modules: `onInteract(playerId, id, definition)`.
--
--   LightRP.interaction("rental.citycenter", {
--       position = { x, y, z }, radius = 2.5, label = "Rent-a-Ride", prompt = "Rent a vehicle", key = "E",
--   })
--   LightRP.dialog(playerId, "rental", payload)   -- open a page dialog (lightrp:ui:dialog)
--
-- `jobs = { "sanitation" }` keeps a point (marker, prompt, map blip, E) to the
-- players who hold one of those jobs; the list is sent again when a job changes.
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

-- Every registration gets a new revision: the client keeps a point whose revision it
-- already drew and rebuilds only the others (a cheap comparison; hashing every entry on
-- the client overran its 2 ms script budget, 2026-11-02).
local revision = 0
function LightRP.interaction(id, definition)
    assert(type(id) == "string" and type(definition) == "table" and type(definition.position) == "table", "LightRP.interaction(id, { position = ... })")
    if interactions[id] == nil then order[#order + 1] = id end
    revision = revision + 1
    definition.rev = revision
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

-- A job point is listed to, and pressed by, its job's players only.
local function allowed(playerId, d)
    if type(d.jobs) ~= "table" then return true end
    local job = LightRP.jobs and LightRP.jobs.get(playerId)
    if not job then return false end
    for _, name in ipairs(d.jobs) do if name == job.name then return true end end
    return false
end

local function clientList(playerId)
    local list = {}
    local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(playerId) or 0
    local position=Open77.players.position(playerId)
    local groups,selected={},{}
    for index,id in ipairs(order) do
        local d=interactions[id]
        if d and d.streamGroup and (d.bucket==nil or d.bucket==bucket) and allowed(playerId,d) then
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
        if d and (d.bucket == nil or d.bucket == bucket) and (not d.streamGroup or selected[id]) and allowed(playerId, d) then
            list[#list + 1] = { id = id, rev = d.rev, position = d.position, radius = d.radius, label = d.label, prompt = d.prompt, key = d.key,
                promptHeight = d.promptHeight, marker = d.marker, ring = d.ring, blip = d.blip }
        end
    end
    return list
end

-- A net event carries at most 48 KiB of JSON and a larger one is refused outright:
-- the client then keeps its previous list (on 2026-11-02, 12 more wardrobes pushed the
-- list over it and every shop registered after them vanished from the clients). A list
-- past LATENT_AT goes as a latent event instead (40 KiB frames, reassembled by the
-- client host and delivered under the same name). A newer list replaces a stream to
-- the same player that is still sending.
--
-- A list identical to the last one this player got is not sent again unless `force`:
-- the housing loop re-sends whenever the player has moved 100 m (the 32 nearest
-- entrances), and while driving that was every 2-4 s; each time the client tore down
-- and rebuilt every marker, blip and 3D-map pin (86 rebuilds in 17 min, 2026-11-02,
-- in the session that ended in an engine crash amid NPC churn).
local LATENT_AT, LATENT_RATE = 40 * 1024, 512 * 1024
-- The client also refuses a plain event of more than 1024 JSON values
-- (kMaximumEventValues, scripting/src/ResourceHost.cpp) and says nothing to the server:
-- 44 points sat just under it until a `rev` per point tipped it over (2026-11-02, every
-- list "dropped malformed network event payload", no shop on the map). A latent event
-- takes 262 144. Counted generously (every key and every value), with margin.
local LATENT_VALUES = 900
local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 12 then return 1 end
    local n = 1
    for key, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1); if type(key) == "table" then n = n + 1 end end
    return n
end
LightRP.countInteractionValues = countValues
local streams, reported, lastSent = {}, 0, {}
local function push(playerId, list, force)
    local size, encoded = 0, nil
    if type(json) == "table" and type(json.encode) == "function" then
        local ok, text = pcall(json.encode, list)
        if ok and type(text) == "string" then size, encoded = #text, text end
    end
    if encoded ~= nil and not force and lastSent[playerId] == encoded then return end
    -- Remembered only once handed to the transport: a refused list is tried again.
    lastSent[playerId] = nil
    local values = countValues(list)
    if (size > LATENT_AT or values > LATENT_VALUES) and type(TriggerLatentClientEvent) == "function" then
        if streams[playerId] and Open77.net and type(Open77.net.cancelLatent) == "function" then pcall(Open77.net.cancelLatent, streams[playerId]) end
        local id, why = TriggerLatentClientEvent(E.net.interactions, playerId, LATENT_RATE, list)
        streams[playerId] = id or nil
        if not id then LightRP.log("interactions: list for player %s not sent (%s, %d points, %d bytes)", tostring(playerId), tostring(why), #list, size)
        else
            lastSent[playerId] = encoded
            if size > reported then reported = size; LightRP.log("interactions: %d points, %d bytes, %d values: sent as a latent event", #list, size, values) end
        end
        return
    end
    local ok, why = TriggerClientEvent(E.net.interactions, playerId, list)
    if ok == false then LightRP.log("interactions: list for player %s refused (%s, %d points, %d bytes)", tostring(playerId), tostring(why), #list, size)
    else lastSent[playerId] = encoded end
end
LightRP.pushInteractions = push

-- `force`: send even an unchanged list (the client may have lost its own: a new
-- connection, a character activated).
function LightRP.sendInteractions(playerId, force)
    push(playerId, clientList(playerId), force)
end

function LightRP.broadcastInteractions()
    if batchDepth > 0 then batchDirty = true; return end
    for _, id in ipairs(GetPlayers()) do push(tonumber(id) or id, clientList(id)) end
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
-- The client's own request (client/core/interact.lua): always answered, forced, at most
-- once a second per player.
local lastAsked = {}
RegisterNetEvent(E.net.interactionsRequest, function()
    local playerId = tonumber(source)
    if playerId == nil or playerId <= 0 then return end
    local now = LightRP.nowMs()
    if lastAsked[playerId] and now - lastAsked[playerId] < 1000 then return end
    lastAsked[playerId] = now
    LightRP.sendInteractions(playerId, true)
end)
RegisterNetEvent(E.net.interact, function(id)
    local playerId = source
    local definition = type(id) == "string" and interactions[id] or nil
    if definition == nil then return end
    local now = LightRP.nowMs()
    if lastPress[playerId] and now - lastPress[playerId] < 400 then return end
    lastPress[playerId] = now
    if not within(playerId, definition) or not allowed(playerId, definition) then return end
    LightRP.eachModule("onInteract", playerId, id, definition)
end)

-- The list is per routing bucket: a player who changes bucket (the arrival
-- hall of the first day guide, a private scene) gets the points of the new one.
AddEventHandler("onPlayerBucketChange", function(playerId)
    playerId = tonumber(playerId)
    if playerId ~= nil and playerId > 0 then LightRP.sendInteractions(playerId) end
end)

local Interact = LightRP.module("interact", {})
function Interact.onGameplayReady(playerId) LightRP.sendInteractions(playerId, true) end
-- job points follow the job
function Interact.onJobChanged(playerId) LightRP.sendInteractions(playerId) end
function Interact.onCharacterActivated(playerId) LightRP.sendInteractions(playerId, true) end
function Interact.onDisconnected(playerId) lastPress[playerId] = nil; lastAsked[playerId] = nil; streams[playerId] = nil; lastSent[playerId] = nil end
