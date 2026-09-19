-- Proximity interactions. A module registers a world point once; every client
-- gets the list (a ground ring and an "E" prompt drawn natively next to it) and
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

local function clientList()
    local list = {}
    for _, id in ipairs(order) do
        local d = interactions[id]
        if d then
            list[#list + 1] = { id = id, position = d.position, radius = d.radius, label = d.label, prompt = d.prompt, key = d.key, promptHeight = d.promptHeight }
        end
    end
    return list
end

function LightRP.sendInteractions(playerId)
    TriggerClientEvent(E.net.interactions, playerId, clientList())
end

function LightRP.broadcastInteractions()
    local list = clientList()
    for _, id in ipairs(GetPlayers()) do TriggerClientEvent(E.net.interactions, id, list) end
end

function LightRP.dialog(playerId, kind, payload)
    payload = payload or {}
    payload.kind = kind
    TriggerClientEvent(E.net.dialog, playerId, payload)
end

local function within(playerId, definition, slack)
    local p = Open77.players.position(playerId)
    if p == nil then return false end
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

local Interact = LightRP.module("interact", {})
function Interact.onGameplayReady(playerId) LightRP.sendInteractions(playerId) end
function Interact.onDisconnected(playerId) lastPress[playerId] = nil end
