-- Proximity interactions on the client: for every point the server sends, a
-- ground ring and an "E" prompt drawn natively by the plugin (Open77.anchors,
-- render = "ring" / "card": frame-tight, no page involved). The local position
-- is sampled ten times a second; the prompt of the nearest point in range is
-- the only one visible, and E sends that point's id to the server, which
-- re-checks the distance itself.
local E = LightRpEvents
local Config = LightRpConfig
local Interact = { points = {}, near = nil, ready = false }
LightRpInteract = Interact

local RING = { accent = "#FFCC00B3", radius = 2.5, thickness = 2.0, groundOffset = 0.05 }
local CARD = { color = "#F2F3F5", accent = "#FFCC00", background = "#0A0A0CF0", progress = -1, showDistance = true }

local function log(format, ...) LightRpUi.log(format, ...) end

local function anchorsAvailable()
    return type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
end

local function clear()
    if anchorsAvailable() then
        for _, point in ipairs(Interact.points) do
            if point.ring then pcall(Open77.anchors.remove, point.ring) end
            if point.card then pcall(Open77.anchors.remove, point.card) end
        end
    end
    Interact.points = {}
    Interact.near = nil
end

local function cardPresentation(point)
    return { label = point.prompt or "Interact", sublabel = point.label, key = point.key or "E",
        color = CARD.color, accent = CARD.accent, background = CARD.background, progress = CARD.progress, showDistance = CARD.showDistance }
end

local function build(list)
    clear()
    for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.position) == "table" then
            local point = { id = entry.id, position = entry.position, radius = tonumber(entry.radius) or 2.5, label = entry.label, prompt = entry.prompt, key = entry.key or "E" }
            if anchorsAvailable() then
                local ring, ringErr = Open77.anchors.create({
                    position = point.position, maxDistance = 60.0, render = "ring",
                    presentation = { accent = RING.accent, radius = point.radius, thickness = RING.thickness, groundOffset = RING.groundOffset },
                })
                if ring then point.ring = ring else log("ring anchor refused for %s: %s", tostring(point.id), tostring(ringErr)) end
                local card, cardErr = Open77.anchors.create({
                    position = { x = point.position.x, y = point.position.y, z = point.position.z + (tonumber(entry.promptHeight) or 2.0) },
                    maxDistance = 14.0, render = "card", visible = false,
                    presentation = cardPresentation(point),
                })
                if card then point.card = card else log("card anchor refused for %s: %s", tostring(point.id), tostring(cardErr)) end
            end
            Interact.points[#Interact.points + 1] = point
        end
    end
    log("%d interaction point(s)", #Interact.points)
end

RegisterNetEvent(E.net.interactions, function(list)
    if type(list) ~= "table" then return end
    build(list)
end)

local function localPosition()
    if type(Open77.character) ~= "table" or type(Open77.character.state) ~= "function" then return nil end
    local ok, state = pcall(Open77.character.state)
    if not ok or type(state) ~= "table" or type(state.position) ~= "table" then return nil end
    return state.position
end

local function setNear(point)
    if Interact.near == point then return end
    if Interact.near and Interact.near.card then pcall(Open77.anchors.update, Interact.near.card, { visible = false }) end
    Interact.near = point
    if point and point.card then pcall(Open77.anchors.update, point.card, { visible = true }) end
end

CreateThread(function()
    while true do
        Wait(100)
        if #Interact.points > 0 then
            local p = localPosition()
            if p == nil then
                setNear(nil)
            else
                local best, bestDistance
                for _, point in ipairs(Interact.points) do
                    local dx, dy, dz = p.x - point.position.x, p.y - point.position.y, p.z - point.position.z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if distance <= point.radius and (bestDistance == nil or distance < bestDistance) then best, bestDistance = point, distance end
                end
                setNear(best)
            end
        end
    end
end)

function Interact.press()
    local point = Interact.near
    if point == nil then return false end
    TriggerServerEvent(E.net.interact, point.id)
    return true
end

function Interact.bind()
    local key = Config.keys.interact
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Interact.press() end)
    if ok then log("interact bound to %s", tostring(effective)) else log("interact key mapping failed: %s", tostring(effective)) end
end
