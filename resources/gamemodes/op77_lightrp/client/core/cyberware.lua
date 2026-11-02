-- Cyberware on the client: the Mantis Blades key. The server (server/modules/cyberware.lua)
-- checks the implant, draws or sheathes the blades and makes the armament step aside; Dash
-- (Ctrl), Ground Slam (G) and the Sandevistan (X) are bound by their platform resources.
-- B is the holster key (the vanilla one, blocked while the inventory owns weapon
-- selection): it puts away whatever is in the hands, and with empty hands draws the
-- Mantis Blades of a player who has them (server/modules/cyberware.lua).
local KEY = { id = "lightrp.cyberware.blades", name = "Light RP: holster / Mantis Blades", key = "B" }

CreateThread(function()
    local ok, effective = RegisterKeyMapping(KEY.id, KEY.name, KEY.key, function()
        if LightRpUi and (LightRpUi.menuOpen or LightRpUi.promptActive) then return end
        TriggerServerEvent("op77_lightrp:cyberware:blades")
    end)
    if not ok then print("[lightrp] Mantis Blades key mapping failed: " .. tostring(effective)) end
end)
