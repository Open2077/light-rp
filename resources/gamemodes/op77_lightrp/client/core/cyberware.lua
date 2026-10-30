-- Cyberware on the client: the Mantis Blades key. The server (server/modules/cyberware.lua)
-- checks the implant, draws or sheathes the blades and makes the armament step aside; Dash
-- (Ctrl), Ground Slam (G) and the Sandevistan (Z) are bound by their platform resources.
local KEY = { id = "lightrp.cyberware.blades", name = "Light RP: Mantis Blades (draw / sheathe)", key = "B" }

CreateThread(function()
    local ok, effective = RegisterKeyMapping(KEY.id, KEY.name, KEY.key, function()
        if LightRpUi and (LightRpUi.menuOpen or LightRpUi.promptActive) then return end
        TriggerServerEvent("op77_lightrp:cyberware:blades")
    end)
    if not ok then print("[lightrp] Mantis Blades key mapping failed: " .. tostring(effective)) end
end)
