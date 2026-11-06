-- Nameplates (op77_playermarks) in PvP: the server lists the players in a fight
-- (server/modules/pvp_marks.lua: Dogtown, PvP and chase activities). While the local
-- player is in it, no plate at all; otherwise the plates of those players are hidden.
-- Without op77_playermarks this does nothing.
local E = LightRpEvents
local Marks = { list = {}, ghosts = {}, applied = nil }
LightRpPvpMarks = Marks

local function localId()
    if type(Open77.players) == "table" and type(Open77.players.localId) == "function" then
        local ok, id = pcall(Open77.players.localId)
        if ok and tonumber(id) then return tonumber(id) end
    end
    local state = type(Open77.network) == "table" and type(Open77.network.status) == "function" and Open77.network.status()
    return type(state) == "table" and tonumber(state.playerId) or nil
end

local function running()
    return type(GetResourceState) ~= "function" or GetResourceState("op77_playermarks") == "running"
end

-- What to ask of op77_playermarks for `list`: "all", "none", or the ids. -> mode, ids
function Marks.decide(list, me)
    if #list == 0 then return "none" end
    for _, id in ipairs(list) do
        if me ~= nil and tonumber(id) == me then return "all" end
    end
    return "ids", list
end

-- The staff in ghost mode (client/core/staff_ghost.lua) have no plate either, whatever the fight
-- says; being a ghost oneself hides nobody else's. -> mode, ids
function Marks.withGhosts(mode, ids, ghosts)
    if mode == "all" or type(ghosts) ~= "table" or #ghosts == 0 then return mode, ids end
    local out, seen = {}, {}
    for _, id in ipairs(mode == "ids" and ids or {}) do seen[id] = true; out[#out + 1] = id end
    for _, id in ipairs(ghosts) do if not seen[id] then seen[id] = true; out[#out + 1] = id end end
    return "ids", out
end

function Marks.apply()
    if not running() then Marks.applied = nil; return false end
    local mode, ids = Marks.decide(Marks.list, localId())
    mode, ids = Marks.withGhosts(mode, ids, Marks.ghosts)
    local applied = mode == "ids" and ("ids:" .. table.concat(ids, ",")) or mode
    if applied == Marks.applied then return true end
    local ok = pcall(function()
        local target = exports.op77_playermarks
        if mode == "all" then target:setHidden(true)
        elseif mode == "ids" then target:setHidden(true, ids)
        else target:setHidden(false) end
    end)
    Marks.applied = ok and applied or nil
    return ok
end

RegisterNetEvent(E.net.pvpPlayers, function(list)
    if type(list) ~= "table" then return end
    local clean = {}
    for _, id in ipairs(list) do
        if tonumber(id) then clean[#clean + 1] = tonumber(id) end
    end
    Marks.list = clean
    Marks.apply()
end)

-- op77_playermarks (re)started: it forgot our choice.
AddEventHandler("onClientResourceStart", function(name)
    if name == "op77_playermarks" then Marks.applied = nil; Marks.apply() end
end)
