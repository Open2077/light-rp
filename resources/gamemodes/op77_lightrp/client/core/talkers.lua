-- Speaking indicator: a small yellow dot over a player's head while their voice
-- is heard, pulsing. Drawn natively by the plugin (Open77.anchors, render =
-- "dot", pinned to the body), fed by the voice host's talkingChanged event.
-- Off while op77_playermarks runs: its nameplates carry the voice bars.
local Talkers = { dots = {} } -- playerId -> { anchor, entity, phase }
LightRpTalkers = Talkers

local ACCENT_ON, ACCENT_DIM = "#FFCC00", "#FFCC0066"
local SCALE_ON, SCALE_DIM = 1.1, 0.75
local HEAD_OFFSET = 2.05
local MAX_DISTANCE = 45.0
local BLINK_MS = 220

local function log(format, ...) LightRpUi.log(format, ...) end

local function anchorsAvailable()
    return type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
end

local function entityOf(playerId)
    if type(Open77.players) ~= "table" or type(Open77.players.entity) ~= "function" then return nil end
    local ok, entity = pcall(Open77.players.entity, playerId)
    return ok and entity or nil
end

local function presentation(on)
    return { accent = on and ACCENT_ON or ACCENT_DIM, scale = on and SCALE_ON or SCALE_DIM }
end

-- op77_playermarks draws a nameplate over every player, with its own voice bars: no
-- second marker over the same head then.
local function platesRunning()
    return type(GetResourceState) == "function" and GetResourceState("op77_playermarks") == "running"
end

local function show(playerId)
    if Talkers.dots[playerId] or not anchorsAvailable() or platesRunning() then return end
    local entity = entityOf(playerId)
    if entity == nil then return end -- body not streamed here: nothing to draw
    local id, err = Open77.anchors.create({
        entity = entity, offset = { x = 0, y = 0, z = HEAD_OFFSET }, maxDistance = MAX_DISTANCE,
        render = "dot", presentation = presentation(true),
    })
    if id == nil then log("talker dot refused for %s: %s", tostring(playerId), tostring(err)) return end
    Talkers.dots[playerId] = { anchor = id, entity = entity, phase = true }
end

local function hide(playerId)
    local dot = Talkers.dots[playerId]
    if dot == nil then return end
    Talkers.dots[playerId] = nil
    if anchorsAvailable() then pcall(Open77.anchors.remove, dot.anchor) end
end

function Talkers.clear()
    for playerId in pairs(Talkers.dots) do hide(playerId) end
end

-- The voice host publishes this on every talk start/stop it hears.
AddEventHandler("open77:voice:talkingChanged", function(playerId, talking)
    playerId = tonumber(playerId)
    if playerId == nil or playerId <= 0 then return end
    if talking == true then show(playerId) else hide(playerId) end
end)
AddEventHandler("open77:voice:participantRemoved", function(playerId) hide(tonumber(playerId) or -1) end)
AddEventHandler("open77:voice:sessionReset", Talkers.clear)

-- The pulse: alternate the dot between bright/large and dim/small, and follow a
-- body that was re-dressed (new entity) while its owner kept talking.
CreateThread(function()
    while true do
        Wait(BLINK_MS)
        if next(Talkers.dots) ~= nil and anchorsAvailable() then
            for playerId, dot in pairs(Talkers.dots) do
                dot.phase = not dot.phase
                local entity = entityOf(playerId)
                local patch = { presentation = presentation(dot.phase) }
                if entity ~= nil and entity ~= dot.entity then dot.entity = entity; patch.entity = entity end
                local ok, err = pcall(Open77.anchors.update, dot.anchor, patch)
                if not ok or err == false then hide(playerId) end
            end
        end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then Talkers.clear() end
end)
