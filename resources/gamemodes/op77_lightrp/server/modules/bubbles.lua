-- Roleplay action bubbles (the standalone op77_actionbubble): /me and /do
-- show over the character, and the vehicle actions (lock, unlock, trunk)
-- show over the vehicle, to the players around. Without the resource running
-- nothing happens: the chat line is still sent.
--
--   LightRP.bubbles.act(playerId, "Opens the trunk", { vehicle = vehicleId, icon = "trunk" })
local Bubbles = LightRP.module("bubbles", {})

local RANGE = 20.0

function Bubbles.show(def)
    local ok, id, why = pcall(function() return exports.op77_actionbubble:show(def) end)
    if not ok or not id then return nil, ok and why or "actionbubble_unavailable" end
    return id
end

--- An action by a character: on the character (or `opts.vehicle` / `opts.position`),
--- seen by the players within `opts.range`. No name on it: it stays in character.
function Bubbles.act(playerId, text, opts)
    opts = opts or {}
    local def = {
        text = text, kind = opts.kind or "action", icon = opts.icon, duration = opts.duration or 5,
        network = { range = opts.range or RANGE },
    }
    if opts.vehicle then def.vehicle = opts.vehicle
    elseif opts.position then def.position = opts.position
    else def.player = playerId end
    return Bubbles.show(def)
end

-- The L key (and the vehicle menu) locked or unlocked a car.
function Bubbles.onVehicleLockChanged(vehicleId, locked, byPlayerId)
    if not byPlayerId then return end
    Bubbles.act(byPlayerId, locked and "Locks the vehicle" or "Unlocks the vehicle",
        { vehicle = vehicleId, icon = locked and "lock" or "unlock", duration = 3.5 })
end
