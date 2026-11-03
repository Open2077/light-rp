-- Nameplates in PvP: server/modules/pvp_marks.lua (who is in a fight) and
-- client/core/pvp_marks.lua (what op77_playermarks is asked to hide).
dofile("shared/events.lua")
local E = LightRpEvents

-- ── server ──
local players, sent, threads = { "1", "2", "3", "4", "5" }, {}, {}
local inDogtown, owned = { [2] = true }, { [3] = { activity = "arena.duel" }, [4] = { activity = "race.grid" }, [5] = { activity = "chase.wanted" } }
LightRP = {
    modules = {},
    module = function(name, t) LightRP[name] = t; return t end,
    log = function() end,
    dogtown = { inZone = function(id) return inDogtown[id] == true end },
    activities = {
        current = function(id) return owned[id] end,
        registry = { ["arena.duel"] = { kind = "pvp" }, ["race.grid"] = { kind = "race" }, ["chase.wanted"] = { kind = "chase" } },
    },
}
GetPlayers = function() return players end
TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() end
dofile("server/modules/pvp_marks.lua")
local PM = LightRP.pvpMarks
assert(PM and #threads == 1, "a module with one ticking thread")

assert(PM.tick() == true, "the first list goes out")
local last = sent[#sent]
assert(last.name == E.net.pvpPlayers and last.target == -1)
assert(table.concat(last.payload, ",") == "2,3,5", "Dogtown, a PvP and a chase activity; not the race, not the idle: " .. table.concat(last.payload, ","))
assert(PM.tick() == false and #sent == 1, "no change: nothing sent")
inDogtown[2] = nil; owned[3] = nil
assert(PM.tick() == true and table.concat(sent[#sent].payload, ",") == "5", "left the fights")
PM.onUiReady(4)
assert(sent[#sent].target == 4 and table.concat(sent[#sent].payload, ",") == "5", "a page coming up gets the list")
-- no Dogtown, no activities module: nobody
LightRP.dogtown, LightRP.activities = nil, nil
assert(PM.tick() == true and #sent[#sent].payload == 0)

-- ── client ──
local net, handlers, calls, running, me = {}, {}, {}, true, 3
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
GetResourceState = function(name) return (name == "op77_playermarks" and running) and "running" or "missing" end
Open77 = { players = { localId = function() return me end } }
exports = { op77_playermarks = { setHidden = function(_, on, ids) calls[#calls + 1] = { on = on, ids = ids and table.concat(ids, ",") }; return true end } }
dofile("client/core/pvp_marks.lua")
local M = LightRpPvpMarks

net[E.net.pvpPlayers]({ 2, 5 })
assert(#calls == 1 and calls[1].on == true and calls[1].ids == "2,5", "the fighters' plates hidden")
net[E.net.pvpPlayers]({ 2, 5 })
assert(#calls == 1, "the same list: no call")
net[E.net.pvpPlayers]({ 2, 3 })
assert(#calls == 2 and calls[2].on == true and calls[2].ids == nil, "I am in a fight: every plate hidden")
net[E.net.pvpPlayers]({})
assert(#calls == 3 and calls[3].on == false, "nobody in a fight: plates back")
net[E.net.pvpPlayers]("junk")
assert(#calls == 3, "a malformed list is ignored")
-- op77_playermarks absent: no call; restarted: the choice is applied again
running = false
net[E.net.pvpPlayers]({ 7 })
assert(#calls == 3)
running = true
handlers.onClientResourceStart("op77_playermarks")
assert(#calls == 4 and calls[4].ids == "7", "re-applied after op77_playermarks started")
assert(M.decide({}, 3) == "none" and M.decide({ 3 }, 3) == "all" and select(1, M.decide({ 4 }, 3)) == "ids")

print("pvp_marks_test: ok")
