-- LightRP.adoptConnectedPlayers (server/core/persistence.lua): a start with players already in
-- the world (the host restarting a resource its runtime error stopped) adopts them as if they had
-- just joined, then replays their page and in-world hooks, every module but `spawn` (no one moves).
-- No game, no database.
dofile("shared/config.lua")
dofile("shared/events.lua")
local noop = function() end
Open77 = { time = { monotonic = function() return 1 end } }
RegisterNetEvent, AddEventHandler, RegisterCommand = noop, noop, noop
GetCurrentResourceName = function() return "op77_lightrp" end
local players = {}
GetPlayers = function() return players end
GetPlayerName = function(id) return "Player" .. tostring(id) end
TriggerClientEvent = function() return true end
print = function() end
local waits = 0
Wait = function() waits = waits + 1 end
dofile("server/core/framework.lua")

local calls = {}
local function hook(module, name) return function(id) calls[#calls + 1] = module .. "." .. name .. ":" .. tostring(id) end end
LightRP.module("spawn", { onConnected = hook("spawn", "onConnected"), onReady = hook("spawn", "onReady"), onGameplayReady = hook("spawn", "onGameplayReady"), onUiReady = hook("spawn", "onUiReady") })
LightRP.module("characters", { onConnected = hook("characters", "onConnected") })
LightRP.module("armament", { onReady = hook("armament", "onReady") })
LightRP.module("maneki", { onGameplayReady = hook("maneki", "onGameplayReady"), onUiReady = hook("maneki", "onUiReady") })

-- persistence.lua defines the function next to its database thread; the thread itself does nothing here
Db = nil
CreateThread = noop
MySQL = nil
LightRP.db = LightRP.db or {}
dofile("server/core/persistence.lua")
assert(type(LightRP.adoptConnectedPlayers) == "function")

-- a normal boot: nobody to adopt
LightRP.adoptConnectedPlayers()
assert(#calls == 0, "no player, no hook")

players = { "3", "7" }
LightRP.adoptConnectedPlayers()
local seen = {}
for _, c in ipairs(calls) do seen[c] = (seen[c] or 0) + 1 end
for _, id in ipairs({ 3, 7 }) do
    assert(seen["characters.onConnected:" .. id] == 1, "the character loads for " .. id)
    assert(seen["spawn.onConnected:" .. id] == 1, "onConnected reaches every module (it only resets state)")
    assert(seen["armament.onReady:" .. id] == 1, "in-world hooks replayed for " .. id)
    assert(seen["maneki.onGameplayReady:" .. id] == 1 and seen["maneki.onUiReady:" .. id] == 1, "page hooks replayed for " .. id)
    assert(not seen["spawn.onReady:" .. id] and not seen["spawn.onGameplayReady:" .. id] and not seen["spawn.onUiReady:" .. id],
        "spawn is left out: nobody is moved")
end
assert(waits > 0, "the second pass waits for the characters to load")
print("PASS: connected players adopted on a restart (character first, then page and in-world hooks; spawn left out)")
