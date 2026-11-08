-- Spawn.placed (server/main.lua) gates the position sampling (characters.samplePosition): an
-- unplaced player still stands at the pre-spawn point. It used to be set by the spawn module's
-- own placements only, so after a resource restart (LightRP.adoptConnectedPlayers leaves spawn
-- out) or a hospital / clinic respawn nobody's position was saved for the rest of the session.
-- Real framework + persistence adoption + spawn module; no game, no database.
dofile("shared/config.lua")
dofile("shared/events.lua")
local noop = function() end
local say = print
print = noop
local CITY, STREET, PRE = { x = -667.14, y = -382.61, z = 9.16 }, { x = -1040.8, y = -1712.3, z = 11.3 }, { x = 0.0106735, y = 3.61861, z = 0 }
local positions = { [3] = CITY, [5] = STREET, [7] = PRE, [9] = STREET }
local phases = { [3] = "alive", [5] = "respawnpending", [7] = "dead", [9] = "dead" }
local respawns, pending = {}, nil
Open77 = {
    time = { monotonic = function() return 1 end },
    players = {
        getLifeState = function(id) return phases[id] and { phase = phases[id], bucket = 0 } end,
        position = function(id) return positions[id] end,
        respawn = function(id, options) respawns[#respawns + 1] = { id = id, position = options.position }; return true end,
        kill = function() return true end,
    },
}
RegisterNetEvent, AddEventHandler, RegisterCommand = noop, noop, noop
GetCurrentResourceName = function() return "op77_lightrp" end
local players = {}
GetPlayers = function() return players end
GetPlayerName = function(id) return "Player" .. tostring(id) end
TriggerClientEvent = function() return true end
Wait = noop
SetTimeout = function(_, fn) pending = fn end
dofile("server/core/framework.lua")
Db, CreateThread, MySQL = nil, noop, nil
LightRP.db = LightRP.db or {}
dofile("server/core/persistence.lua")
dofile("server/main.lua")
local Spawn = LightRP.spawn
for _, id in ipairs({ 3, 5, 7, 9 }) do assert(not Spawn.placed(id), "nobody is placed before the adoption") end

-- The restart adopts everyone present.
players = { "3", "5", "7", "9" }
LightRP.adoptConnectedPlayers()
assert(Spawn.placed(3), "alive in the city at the restart: placed, the position is saved again")
assert(Spawn.placed(9), "downed in the street at the restart: placed (the body lies at a real position)")
assert(not Spawn.placed(7), "still at the pre-spawn point: never placed, its position is not saved")
assert(not Spawn.placed(5), "mid-respawn: not yet")

-- Any respawn / revive the client applied (the clinic, a mission, a staff revive) places the player.
LightRP.eachModule("onLifeState", 5, "recovering", 12)
assert(Spawn.placed(5), "a respawn applied by the client places the player")

-- The hospital respawn of the death handler, then the platform's `recovering`.
LightRP.eachModule("onLifeState", 7, "dead", 4)
assert(pending, "the hospital respawn is scheduled"); pending()
assert(#respawns == 1 and respawns[1].id == 7 and respawns[1].position == LightRpConfig.spawn.hospital.position, "respawned at the hospital")
phases[7], positions[7] = "recovering", LightRpConfig.spawn.hospital.position
LightRP.eachModule("onLifeState", 7, "recovering", 5)
assert(Spawn.placed(7), "the hospital respawn places the player")

-- A disconnect forgets it (a reconnect starts at the pre-spawn point again).
Spawn.onDisconnected(3)
assert(not Spawn.placed(3), "a disconnect clears the mark")
say("PASS: a restart marks the adopted players placed (never one at the pre-spawn point); every respawn path (hospital, clinic, missions) places the player")
