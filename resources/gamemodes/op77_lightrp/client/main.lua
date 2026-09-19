-- Client entry: create the surface, start the HUD sampler, bind the menu key.
local Config = LightRpConfig

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    if not LightRpUi.create() then return end
    LightRpHud.start()

    local key = Config.keys.menu
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function()
        LightRpUi.toggleMenu()
    end)
    if ok then
        LightRpUi.log("menu bound to %s", tostring(effective))
    else
        LightRpUi.log("menu key mapping failed: %s", tostring(effective))
    end
end)

-- The menu also opens from the chat: /menu.
RegisterNetEvent("open77:lightrp:menu", function() LightRpUi.setMenuOpen(true) end)
