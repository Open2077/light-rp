-- A player who disconnects before the join placement has never left the pre-spawn
-- position (the lobby, around 0, 3.6, 0). Sampling it saved that point as the
-- character's position, and the next connection placed them there, under the map
-- (measured 2026-11-06 on a lab reconnect). Only a placed player is sampled.
dofile("shared/config.lua")
local noop = function() end
local saved
LightRP = {
    db = { ready = true, schema = noop, query = function() return {} end, single = noop, read = function() return true, {} end,
        run = function(sql, params)
            if sql:find("last_x", 1, true) then saved = { x = params[2], y = params[3], z = params[4] } end
            return true
        end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = noop, action = noop, eachModule = noop, state = noop, broadcastState = noop, command = noop,
    notice = noop, log = noop, result = noop, dialog = noop, nowMs = function() return 1000 end,
}
local threads, loaded = {}, false
CreateThread = function(fn) if loaded then threads[#threads + 1] = fn end end
local function run() while #threads > 0 do table.remove(threads, 1)() end end
SetTimeout = noop
Wait = noop
AddEventHandler = noop
TriggerEvent = noop
exports = noop
GetPlayerName = function() return "Account" end
GetPlayerIdentifier = function() return "account-1" end
GetPlayers = function() return { 1 } end
GetPlayerRoutingBucket = function() return 0 end
local where = { x = 0.0106735, y = 3.61861, z = 0 }
Open77 = {
    players = {
        position = function() return { x = where.x, y = where.y, z = where.z, bucket = 0 } end,
        getLifeState = function() return { phase = "alive" } end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 end },
}
dofile("server/modules/characters.lua")
local C = LightRP.characters
local placed = false
LightRP.spawn = { placed = function(id) return id == 1 and placed end }
loaded = true

-- Connected, never placed: nothing is sampled, the saved position is left as it was.
C.byPlayer[1] = { identifier = "account-1", key = "default", status = "active", firstName = "Alex", lastName = "Morgan" }
C.samplePosition(1)
C.onDisconnected(1)
run()
assert(saved == nil, "a disconnect before the placement saved the pre-spawn position")

-- Placed: the position is sampled and saved as before.
C.byPlayer[1] = { identifier = "account-1", key = "default", status = "active", firstName = "Alex", lastName = "Morgan" }
placed, where = true, { x = -1040.8, y = -1712.3, z = 11.3 }
C.samplePosition(1)
C.onDisconnected(1)
run()
assert(saved and saved.x == -1040.8 and saved.y == -1712.3 and saved.z == 11.3, "a placed player's position is saved")
print("PASS: only a placed player's position is sampled; a disconnect before the placement keeps the saved position")
