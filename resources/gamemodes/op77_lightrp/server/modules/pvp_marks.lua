local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- Who is in a PvP fight right now: in Dogtown (inside, or tagged after leaving it) or in an
-- activity whose kind is in `KINDS` (the arena's modes and the turf war are "pvp", the
-- chases "chase"). Every client gets the list when it changes (and on its page ready);
-- client/core/pvp_marks.lua hides those players' nameplates (op77_playermarks), and every
-- nameplate while the local player is in the list: a name over a head must not point out
-- an enemy, through a wall or across the zone.
local E = LightRpEvents.net
local PM = LightRP.module("pvpMarks", {})

local KINDS = { pvp = true, chase = true }
local TICK_MS = 1000
PM.KINDS = KINDS

local current, key = {}, ""

function PM.inPvp(player)
    local D = LightRP.dogtown
    if type(D) == "table" and type(D.inZone) == "function" and D.inZone(player) then return true end
    local A = LightRP.activities
    if type(A) == "table" and type(A.current) == "function" then
        local e = A.current(player)
        local def = e and type(A.registry) == "table" and A.registry[e.activity] or nil
        if type(def) == "table" and KINDS[def.kind] then return true end
    end
    return false
end

-- The sorted list of player ids in a fight.
function PM.compute()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and PM.inPvp(id) then list[#list + 1] = id end
    end
    table.sort(list)
    return list
end

-- Sends the list to everyone when it changed. -> whether it was sent
function PM.tick()
    local list = PM.compute()
    local k = table.concat(list, ",")
    if k == key then return false end
    key, current = k, list
    TriggerClientEvent(E.pvpPlayers, -1, list)
    return true
end

function PM.current() return current end

-- A page that comes up (a join, a reconnect, a resource restart) gets the list at once.
function PM.onUiReady(playerId) TriggerClientEvent(E.pvpPlayers, playerId, current) end

CreateThread(function()
    lightrpEvery(TICK_MS, function()
        
        local ok, err = pcall(PM.tick)
        if not ok then LightRP.log("pvp marks: %s", tostring(err)) end
    end, "pvp_marks:54")
end)
