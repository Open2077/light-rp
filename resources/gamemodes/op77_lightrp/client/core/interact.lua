-- Proximity interactions on the client. For every point the server sends:
--   * a small ground ring drawn natively by the plugin (Open77.anchors,
--     render = "ring"), only reported within a few metres so it appears as you
--     walk up;
--   * an optional vanilla map blip (Open77.blips) so the point is on the map;
--   * one shared page anchor ("interact") that the HUD page turns into a keycap
--     and a few words, moved onto the nearest point in range.
-- E sends that point's id to the server, which re-checks the distance itself.
local E = LightRpEvents
local Config = LightRpConfig
local Interact = { points = {}, near = nil, promptAnchor = nil }
LightRpInteract = Interact

local RING_ACCENT = "#FFCC00B3"
local sendPrompt

local function log(format, ...) LightRpUi.log(format, ...) end

local function anchorsAvailable()
    return type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
end

local function blipsAvailable()
    return type(Open77.blips) == "table" and type(Open77.blips.create) == "function"
end

local function clear()
    for _, point in ipairs(Interact.points) do
        if point.ring and anchorsAvailable() then pcall(Open77.anchors.remove, point.ring) end
        if point.blip and blipsAvailable() then pcall(Open77.blips.remove, point.blip) end
    end
    Interact.points = {}
    if Interact.near then Interact.near = nil; sendPrompt(nil) end
end

-- The shared prompt anchor follows the nearest point; the page draws the words.
function sendPrompt(point)
    if Interact.promptAnchor and anchorsAvailable() then
        if point then
            Open77.anchors.update(Interact.promptAnchor, {
                position = { x = point.position.x, y = point.position.y, z = point.position.z + (point.promptHeight or 1.1) }, visible = true,
            })
        else
            Open77.anchors.update(Interact.promptAnchor, { visible = false })
        end
    end
    LightRpUi.send(E.page.interact, point and { id = point.id, prompt = point.prompt or "Interact", key = point.key or "E" } or {})
end

local function ensurePromptAnchor()
    if Interact.promptAnchor or not anchorsAvailable() or LightRpUi.page == nil then return end
    local id, err = Open77.anchors.create({
        page = LightRpUi.page, position = { x = 0, y = 0, z = 0 }, tag = "interact", maxDistance = 12.0, visible = false,
    })
    if id then Interact.promptAnchor = id else log("prompt anchor refused: %s", tostring(err)) end
end

local function createBlip(point)
    if not blipsAvailable() or type(point.blip) ~= "table" then return nil end
    for _, sprite in ipairs({ point.blip.sprite, "vehicle", "objective" }) do
        if sprite then
            local id = Open77.blips.create({
                position = point.position, sprite = sprite,
                title = point.blip.title or point.label or "Point of interest",
                description = point.blip.description or point.prompt or "",
                active = true, visibleThroughWalls = false,
            })
            if id then return id end
        end
    end
    log("blip refused for %s", tostring(point.id))
    return nil
end

local function build(list)
    clear()
    ensurePromptAnchor()
    for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.position) == "table" then
            local ring = type(entry.ring) == "table" and entry.ring or {}
            local point = {
                id = entry.id, position = entry.position, radius = tonumber(entry.radius) or 2.5,
                label = entry.label, prompt = entry.prompt, key = entry.key or "E",
                promptHeight = tonumber(entry.promptHeight) or 1.1, blip = entry.blip,
            }
            if anchorsAvailable() then
                local id, err = Open77.anchors.create({
                    position = point.position, maxDistance = tonumber(ring.maxDistance) or 8.0, render = "ring",
                    presentation = { accent = ring.accent or RING_ACCENT, radius = tonumber(ring.radius) or 0.9, thickness = tonumber(ring.thickness) or 2.0, groundOffset = 0.05 },
                })
                if id then point.ring = id else log("ring anchor refused for %s: %s", tostring(point.id), tostring(err)) end
            end
            point.blip = createBlip(point) -- nil when the point asks for none
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
    Interact.near = point
    sendPrompt(point)
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
