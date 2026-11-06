-- Staff ghost mode, this client's side (server/modules/staff_ghost.lua):
-- - the ghost list: their map dots go (op77_map3d), their nameplates too (client/core/pvp_marks.lua
--   adds them to what op77_playermarks hides; op77_playermarks also skips a player whose dot is hidden);
-- - our own ghost state: the platform noclip, run as the operator (/admin.self.noclip on|off), so
--   the host's ACL still decides it.
local E = LightRpEvents
local Ghost = { ids = {}, dots = nil }
LightRpStaffGhost = Ghost

local MAP = "op77_map3d"

local function running(name) return type(GetResourceState) ~= "function" or GetResourceState(name) == "running" end

local function call(name, method, ...)
    if not running(name) then return nil end
    local args = table.pack(...)
    local ok, value = pcall(function()
        local target = exports[name]
        return target[method](target, table.unpack(args, 1, args.n))
    end)
    if ok then return value end
    return nil
end

-- The map dots, change-gated.
function Ghost.applyDots()
    local key = table.concat(Ghost.ids, ",")
    if key == Ghost.dots then return end
    if key ~= "" then call(MAP, "setPlayerDotsHidden", true, Ghost.ids)
    else call(MAP, "setPlayerDotsHidden", false) end
    Ghost.dots = running(MAP) and key or nil
end

RegisterNetEvent(E.net.staffGhosts, function(list)
    if type(list) ~= "table" then return end
    local clean = {}
    for _, id in ipairs(list) do
        if tonumber(id) then clean[#clean + 1] = tonumber(id) end
    end
    Ghost.ids = clean
    Ghost.applyDots()
    if LightRpPvpMarks then LightRpPvpMarks.ghosts = clean; LightRpPvpMarks.apply() end
end)

RegisterNetEvent(E.net.staffGhost, function(state)
    if type(state) ~= "table" then return end
    TriggerServerEvent("open77:command:execute", "admin.self.noclip", state.on == true and "on" or "off")
end)

-- op77_map3d (re)started: it forgot our choice.
AddEventHandler("onClientResourceStart", function(name)
    if name == MAP then Ghost.dots = nil; Ghost.applyDots() end
end)
