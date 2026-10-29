-- op77_weaponhud server: runtime configuration for everyone or one player. The base
-- configuration is shared/config.lua; the patches given here for everyone are replayed
-- to players who join later (a player's own patches last for their session).
local patches = {}   -- patches for everyone, in order
local MAX_PATCHES = 64

RegisterNetEvent("op77_weaponhud:hello", function()
    local playerId = tonumber(source)
    if not playerId then return end
    for _, patch in ipairs(patches) do TriggerClientEvent("op77_weaponhud:config", playerId, patch) end
end)

-- setConfig(patch)            -> every player, now and later
-- setConfig(patch, playerId)  -> one player, this session
exports("setConfig", function(patch, playerId)
    if type(patch) ~= "table" then return false, "invalid_patch" end
    if playerId ~= nil then
        local target = tonumber(playerId)
        if not target then return false, "invalid_player" end
        TriggerClientEvent("op77_weaponhud:config", target, patch)
        return true
    end
    patches[#patches + 1] = patch
    if #patches > MAX_PATCHES then table.remove(patches, 1) end
    TriggerClientEvent("op77_weaponhud:config", -1, patch)
    return true
end)

-- Back to shared/config.lua for everyone (drops the patches given so far).
exports("resetConfig", function()
    patches = {}
    TriggerClientEvent("op77_weaponhud:config", -1, { reset = true })
    return true
end)
