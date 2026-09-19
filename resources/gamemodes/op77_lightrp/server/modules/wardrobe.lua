-- Wardrobe points: places in the city where a player changes clothes. Each
-- point is a proximity interaction (3D marker, E prompt, map blip) that opens
-- the platform's wardrobe UI for an active character, the same screen the
-- creation wizard opens. No command is involved: /wardrobe is staff-only.
local Config = LightRpConfig.wardrobes
local Wardrobe = LightRP.module("wardrobe", {})

local spots = {} -- interaction id -> spot

local function interactionId(spot) return "wardrobe." .. spot.id end

function Wardrobe.open(playerId)
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return false, "no_character" end
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return false, "not_alive" end
    TriggerClientEvent("open77:wardrobe_ui:open", playerId)
    return true
end

CreateThread(function()
    if not Config or not Config.enabled then return end
    Wait(500)
    for _, entry in ipairs(Config.spots or {}) do
        local spot = {}
        for k, v in pairs(entry) do spot[k] = v end
        spots[interactionId(spot)] = spot
        LightRP.interaction(interactionId(spot), {
            position = spot.position, radius = Config.interactRadius or 2.0,
            label = spot.name, prompt = Config.prompt or "Change outfit", key = Config.key or "E", promptHeight = spot.promptHeight or 1.1,
            marker = spot.marker or Config.marker, ring = false,
            blip = Config.blip and { sprite = Config.blip.sprite, title = spot.name, description = Config.blip.description } or nil,
        })
    end
    LightRP.log("wardrobe: %d point(s) placed", #(Config.spots or {}))
end)

function Wardrobe.onInteract(playerId, id)
    local spot = spots[id]
    if spot == nil then return end
    local ok, reason = Wardrobe.open(playerId)
    if not ok then
        LightRP.result(playerId, false, reason == "no_character" and "Finish your character first." or "Not right now.", "wardrobe.open")
    end
end

-- The wizard's "Wardrobe" button lands here too (client-local action rerouted).
LightRP.action("character.wardrobe.open", function(playerId)
    local ok, reason = Wardrobe.open(playerId)
    if not ok then LightRP.result(playerId, false, reason == "no_character" and "Finish your character first." or "Not right now.", "character.wardrobe.open") end
end)
