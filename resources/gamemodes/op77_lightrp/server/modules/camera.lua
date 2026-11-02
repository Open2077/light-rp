-- /camchange and /cinematic (from Freeroam): each only changes the sender's own
-- view, so the server just forwards the request to that client (client/core/camera.lua).
local E = LightRpEvents

LightRP.command("camchange", { usage = "/camchange [classic|shoulder|centered|left|right|shake|reset]" }, function(source, args)
    if not source or source <= 0 then return false, "Player command only." end
    local choice = tostring(args[1] or ""):lower()
    local choices = { [""] = true, classic = true, shoulder = true, centered = true, left = true, right = true, shake = true, reset = true }
    if (args.n or #args) > 1 or not choices[choice] then return false end
    TriggerClientEvent(E.net.cameraChange, source, choice)
end)

LightRP.command("cinematic", { usage = "/cinematic [on|off]" }, function(source, args)
    if not source or source <= 0 then return false, "Player command only." end
    local choice = tostring(args[1] or ""):lower()
    if (args.n or #args) > 1 or (choice ~= "" and choice ~= "on" and choice ~= "off") then return false end
    TriggerClientEvent(E.net.cameraCinematic, source, choice)
end)
