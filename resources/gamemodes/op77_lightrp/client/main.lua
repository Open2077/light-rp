-- Client entry: create the surface, start the HUD sampler, bind the player menu key (F1).
local Config = LightRpConfig

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    if not LightRpUi.create() then return end
    LightRpHud.start()
    LightRpInteract.bind()
    LightRpKeys.bind()
    LightRpMovement.bind()
    LightRpInventory.bind()
    if LightRpBoardGamesClient then LightRpBoardGamesClient.start() end
    LightRpBranding.apply()
    if LightRpSafezones then LightRpSafezones.start() end
    if LightRpMissionEditor then LightRpMissionEditor.start() end
    if LightRpParkourClient then LightRpParkourClient.start() end

    local key = Config.keys.menu
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function()
        LightRpUi.toggleMenu()
    end)
    if ok then
        LightRpUi.log("player menu bound to %s", tostring(effective))
    else
        LightRpUi.log("player menu key mapping failed: %s", tostring(effective))
    end
end)
