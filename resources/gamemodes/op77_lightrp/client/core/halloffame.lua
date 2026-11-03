-- The Hall of Fame board at The Crossing (server/modules/halloffame.lua): ALT + click
-- on its prop opens the `halloffame` dialog of the Light RP page. The E point in
-- front of it needs nothing here (client/core/interact.lua draws it); this file only
-- knows which server prop is the board, and asks the server to open the panel.
local E = LightRpEvents
local resource = GetCurrentResourceName()
local board = { prop = nil } -- the server prop id (a decimal string), once the server says

RegisterNetEvent(E.net.hallOfFameBoard, function(info)
    if type(info) ~= "table" then return end
    board.prop = type(info.prop) == "string" and info.prop or nil
end)

local function eligible(ctx)
    if GetInvokingResource() ~= "open77_contextmenu" or board.prop == nil then return false end
    if not LightRpUi.characterReady or LightRpUi.actionFocus or LightRpUi.menuOpen then return false end
    for _, open in pairs(LightRpUi.dialogs or {}) do if open then return false end end
    return type(ctx) == "table" and type(ctx.target) == "table" and ctx.target.kind == "prop"
        and ctx.target.propId == board.prop
end
exports("hallOfFameAvailable", eligible)
exports("hallOfFameSelect", function(ctx)
    if not eligible(ctx) then return false end
    local ok, why = TriggerServerEvent(E.net.action, { type = "halloffame.open", from = "board", tab = "overview" })
    if not ok then LightRpUi.log("hall of fame request failed: %s", tostring(why)) end
    return ok == true
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= resource and name ~= "open77_contextmenu" then return end
    -- a restarted script asks again which prop the board is
    if name == resource then TriggerServerEvent(E.net.hallOfFameHello) end
    local pending, why = Open77.exports.call("open77_contextmenu", "registerProps", {
        id = "halloffame.open", label = "Hall of Fame", icon = "info", networked = true, distance = 8,
        group = "The Crossing", canInteract = "hallOfFameAvailable", onSelect = "hallOfFameSelect",
    })
    if pending then local token; token, why = pending:await(); if token then return end end
    LightRpUi.log("hall of fame context unavailable: %s (E at the board still opens it)", tostring(why))
end)
