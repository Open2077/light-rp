-- The nameplates show the character's name, not the account's (owner, 2026-11-06): every client
-- gets the list "id<TAB>First Last" of the players with an active character when it changes
-- and when its page comes up; client/core/rp_names.lua hands it to op77_playermarks (setNames).
-- A player without a character yet (creation, a draft) keeps the account's name.
local E = LightRpEvents.net
local Names = LightRP.module("rpNames", {})

local TICK_MS = 2000
local current, key = {}, ""

function Names.compute()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        local c = id and LightRP.characters.get(id)
        if c and c.status == "active" and c.firstName then
            local name = (LightRP.characters.displayName(id) or ""):gsub("[%c]", " ")
            if name:match("%S") then list[#list + 1] = ("%d\t%s"):format(id, name:sub(1, 64)) end
        end
    end
    table.sort(list)
    return list
end

-- Sends the list to everyone when it changed. -> whether it was sent
function Names.tick()
    local list = Names.compute()
    local k = table.concat(list, "\n")
    if k == key then return false end
    key, current = k, list
    TriggerClientEvent(E.rpNames, -1, list)
    return true
end

function Names.onUiReady(playerId) TriggerClientEvent(E.rpNames, playerId, current) end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        local ok, err = pcall(Names.tick)
        if not ok then LightRP.log("rp names: %s", tostring(err)) end
    end
end)
