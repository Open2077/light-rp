-- Staff ghost mode: server/modules/staff_ghost.lua (hide, list, read-back, command) and the
-- clients' side (client/core/staff_ghost.lua noclip + map dots, client/core/pvp_marks.lua plates).
dofile("shared/events.lua")
local E = LightRpEvents

-- ── server ──
local names = { [1] = "Staff", [2] = "Player" }
local visible, refuse, sent, threads, commands, logs = {}, {}, {}, {}, {}, {}
LightRP = {
    module = function(name, t) LightRP[name] = t; return t end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    command = function(name, options, fn) commands[name] = { options = options, fn = fn } end,
}
Open77 = { players = {
    isVisible = function(id) return visible[id] ~= false end,
    setVisible = function(id, on)
        if refuse[id] then return false, "refused" end
        visible[id] = on; return true
    end,
} }
GetPlayerName = function(id) return names[id] end
GetCurrentResourceName = function() return "op77_lightrp" end
local stopHandler
AddEventHandler = function(name, fn) if name == "onResourceStop" then stopHandler = fn end end
TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() end
dofile("server/modules/staff_ghost.lua")
local G = LightRP.staffGhost
assert(G and #threads == 1, "a module with its read-back thread")
local cmd = commands["lightrp.ghost"]
assert(cmd and cmd.options.restricted == true, "a restricted command (staff hold command.lightrp.*)")

local function last(name, target)
    for i = #sent, 1, -1 do
        local s = sent[i]
        if s.name == name and (target == nil or s.target == target) then return s end
    end
end

local ok, text = cmd.fn(1, {})
assert(ok == true and text:find("ON"), "no argument toggles on: " .. tostring(text))
assert(visible[1] == false, "the body is hidden")
assert(table.concat(last(E.net.staffGhosts, -1).payload, ",") == "1", "everyone gets the ghost list")
assert(last(E.net.staffGhost, 1).payload.on == true, "the ghost's client turns noclip on")
assert(G.isGhost(1) and not G.isGhost(2))

-- the platform dropped the hide (a death, a bucket change): the read-back asks again
visible[1] = true
assert(G.tick() == false and visible[1] == false, "hidden again, the list unchanged")

-- a refused hide is reported and retried, the ghost stays on
refuse[2] = true
ok, text = cmd.fn(2, { "on" })
assert(ok == true and text:find("could not be hidden"), tostring(text))
assert(table.concat(last(E.net.staffGhosts, -1).payload, ",") == "1,2")
refuse[2] = nil
G.tick()
assert(visible[2] == false, "the retry hid it")

-- off: shown again, out of the list, noclip off
ok, text = cmd.fn(1, { "off" })
assert(ok == true and text:find("OFF") and visible[1] == true)
assert(table.concat(last(E.net.staffGhosts, -1).payload, ",") == "2")
assert(last(E.net.staffGhost, 1).payload.on == false)
assert(select(1, cmd.fn(1, { "maybe" })) == false, "a bad word: usage")
assert(select(1, cmd.fn(0, {})) == false, "not from the console")

-- a page coming up gets the list; a ghost who leaves is dropped
G.onUiReady(7)
assert(table.concat(last(E.net.staffGhosts, 7).payload, ",") == "2")
names[2] = nil
assert(G.tick() == true and #last(E.net.staffGhosts, -1).payload == 0, "a ghost gone is out of the list")

-- the resource stops: nobody stays invisible
names[2] = "Player"; cmd.fn(2, { "on" })
assert(visible[2] == false)
stopHandler("op77_lightrp")
assert(visible[2] == true, "shown on stop")

-- ── client ──
local net, executed, dots, plates = {}, {}, {}, {}
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function() end
TriggerServerEvent = function(...) executed[#executed + 1] = { ... } end
GetResourceState = function() return "running" end
exports = {
    op77_map3d = { setPlayerDotsHidden = function(_, on, ids) dots[#dots + 1] = { on = on, ids = ids } return true end },
    op77_playermarks = { setHidden = function(_, on, ids) plates[#plates + 1] = { on = on, ids = ids } return true end },
}
Open77 = { players = { localId = function() return 5 end } }
dofile("client/core/pvp_marks.lua")
dofile("client/core/staff_ghost.lua")

net[E.net.staffGhosts]({ 1, 3 })
assert(dots[#dots].on == true and table.concat(dots[#dots].ids, ",") == "1,3", "the ghosts' map dots go")
assert(plates[#plates].on == true and table.concat(plates[#plates].ids, ",") == "1,3", "their nameplates go")
net[E.net.pvpPlayers]({ 4 })
assert(table.concat(plates[#plates].ids, ",") == "4,1,3", "PvP and ghosts together")
net[E.net.pvpPlayers]({ 5 })
assert(plates[#plates].on == true and plates[#plates].ids == nil, "in a fight myself: every plate, ghosts included")
net[E.net.pvpPlayers]({})
net[E.net.staffGhosts]({})
assert(dots[#dots].on == false and plates[#plates].on == false, "no ghost, no fight: everything back")

net[E.net.staffGhost]({ on = true })
assert(executed[#executed][1] == "open77:command:execute" and executed[#executed][2] == "admin.self.noclip" and executed[#executed][3] == "on",
    "the ghost's own client runs the platform noclip as the operator")
net[E.net.staffGhost]({ on = false })
assert(executed[#executed][3] == "off")

print("PASS: ghost mode hides the body (read back), lists the ghosts to every client (no plate, no map dot), toggles noclip through the ACL, shows on stop")
