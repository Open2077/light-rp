-- The fitting room (open77_wardrobe_ui) tells this client when it shows or
-- hides; the server keeps a private bucket for the player meanwhile
-- (server/modules/wardrobe.lua) and needs both moments.
local E = LightRpEvents

AddEventHandler("open77:wardrobe:visibility", function(visible)
    if LightRpInteract then LightRpInteract.setHidden(visible == true) end
    TriggerServerEvent(E.net.wardrobe, visible == true)
end)
