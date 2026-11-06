-- The characters' names on the nameplates (server/modules/rp_names.lua): the list
-- "id<TAB>First Last" goes to op77_playermarks (setNames), applied again when it restarts.
-- Without op77_playermarks this does nothing.
local E = LightRpEvents
local Names = { map = {} }
LightRpRpNames = Names

local function running()
    return type(GetResourceState) ~= "function" or GetResourceState("op77_playermarks") == "running"
end

function Names.parse(list)
    local map = {}
    for _, row in ipairs(type(list) == "table" and list or {}) do
        local id, name = tostring(row):match("^(%d+)\t(.+)$")
        if id and name:match("%S") then map[tonumber(id)] = name end
    end
    return map
end

function Names.apply()
    if not running() then return false end
    return pcall(function()
        local target = exports.op77_playermarks
        target:setNames(Names.map)
    end)
end

RegisterNetEvent(E.net.rpNames, function(list)
    if type(list) ~= "table" then return end
    Names.map = Names.parse(list)
    Names.apply()
end)

-- op77_playermarks (re)started: it forgot our names.
AddEventHandler("onClientResourceStart", function(name)
    if name == "op77_playermarks" then Names.apply() end
end)
