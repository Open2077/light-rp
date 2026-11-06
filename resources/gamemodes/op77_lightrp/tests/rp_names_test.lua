-- The characters' names on the nameplates: server/modules/rp_names.lua (who has an active
-- character, sent on change) and client/core/rp_names.lua (handed to op77_playermarks).
dofile("shared/events.lua")
local E = LightRpEvents

-- ── server ──
local players, chars, sent, threads = { "1", "2", "3" }, {}, {}, {}
chars[1] = { status = "active", firstName = "Jake", lastName = "Rob" }
chars[2] = { status = "draft" }                         -- still in creation: the account's name
chars[3] = { status = "active", firstName = "Lina", lastName = "Voss" }
LightRP = {
    module = function(name, t) LightRP[name] = t; return t end,
    log = function() end,
    characters = {
        get = function(id) return chars[id] end,
        displayName = function(id) local c = chars[id]; return c and c.firstName and (c.firstName .. " " .. c.lastName) or "Account" .. id end,
    },
}
GetPlayers = function() return players end
TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() end
dofile("server/modules/rp_names.lua")
local N = LightRP.rpNames
assert(N and #threads == 1)
assert(N.tick() == true)
local last = sent[#sent]
assert(last.name == E.net.rpNames and last.target == -1)
assert(table.concat(last.payload, "|") == "1\tJake Rob|3\tLina Voss", "active characters only: " .. table.concat(last.payload, "|"))
assert(N.tick() == false and #sent == 1, "no change: nothing sent")
chars[2] = { status = "active", firstName = "New", lastName = "Comer" }
assert(N.tick() == true and #sent[#sent].payload == 3, "a character finished: sent again")
N.onUiReady(9)
assert(sent[#sent].target == 9 and #sent[#sent].payload == 3, "a page coming up gets the list")

-- ── client ──
local net, given = {}, {}
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function() end
GetResourceState = function() return "running" end
exports = { op77_playermarks = { setNames = function(_, map) given[#given + 1] = map; return true end } }
dofile("client/core/rp_names.lua")
net[E.net.rpNames]({ "1\tJake Rob", "3\tLina Voss", "junk", "4\t  " })
local map = given[#given]
assert(map[1] == "Jake Rob" and map[3] == "Lina Voss" and map[4] == nil, "parsed, junk and blanks dropped")
net[E.net.rpNames]({})
assert(next(given[#given]) == nil, "an empty list clears the names")

print("PASS: the nameplates get the characters' names (active only, on change, on page ready), handed to op77_playermarks")
