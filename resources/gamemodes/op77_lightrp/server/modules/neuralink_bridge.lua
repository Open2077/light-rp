-- Publishes the active character to other server resources, for op77_neuralink
-- (the neural phone): its phone line belongs to a character, not to an account.
--
--   exports.op77_lightrp:characterIdentity(playerId)
--       -> { identifier, characterKey, name } for an ACTIVE character, or nil
--   TriggerEvent("op77_lightrp:characterReady", playerId, identity)    activated / loaded active
--   TriggerEvent("op77_lightrp:characterChanged", playerId, identity|nil)  switched / back to the selector
--
-- TriggerEvent is host-wide, so the phone resource receives these with
-- AddEventHandler. Nothing here knows about phones.
local Bridge = LightRP.module("neuralinkBridge", {})

local function identity(playerId)
    local c = LightRP.characters and LightRP.characters.get(playerId)
    if not c or c.status ~= "active" or not c.identifier or not c.key then return nil end
    local name = c.firstName and (c.firstName .. " " .. (c.lastName or "")) or nil
    return { identifier = c.identifier, characterKey = c.key, name = name and name:gsub("%s+$", "") or nil }
end

exports("characterIdentity", function(playerId)
    if type(playerId) ~= "number" or playerId < 1 or playerId % 1 ~= 0 then return nil end
    return identity(playerId)
end)

local function announce(playerId)
    local id = identity(playerId)
    if id then TriggerEvent("op77_lightrp:characterReady", playerId, id) end
end

function Bridge.onCharacterActivated(playerId) announce(playerId) end
function Bridge.onCharacterLoaded(playerId) announce(playerId) end
function Bridge.onCharacterSwitched(playerId)
    TriggerEvent("op77_lightrp:characterChanged", playerId, identity(playerId))
end

-- The other way: the first day's implant step waits for the installation.
-- The implant is installed while the Kiroshi sequence still plays (its stage 3
-- of 7): the guide moves on once the sequence is over, not behind it.
local SEQUENCE_REST_MS = 12000
AddEventHandler("op77_neuralink:implantChanged", function(playerId, installed)
    if installed ~= true or type(playerId) ~= "number" or not LightRP.tutorial then return end
    -- A skipped first day asked for the implant itself: no sequence plays, it leaves now.
    if LightRP.tutorial.onImplantFitted then LightRP.tutorial.onImplantFitted(playerId) end
    SetTimeout(SEQUENCE_REST_MS, function() LightRP.tutorial.onNeuralinkInstalled(playerId) end)
end)
AddEventHandler("op77_neuralink:installFailed", function(playerId, reason)
    if type(playerId) ~= "number" or not (LightRP.tutorial and LightRP.tutorial.onImplantFailed) then return end
    LightRP.tutorial.onImplantFailed(playerId, reason)
end)
