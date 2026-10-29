-- Lua 5.4: configured hospital is used by the actual death/respawn handler.
dofile("shared/config.lua")
local expected = { x = -1355.739746, y = 1737.886597, z = 18.200012 }
local function hospital(position)
    for axis, value in pairs(expected) do assert(position[axis] == value, "hospital " .. axis) end
end
hospital(LightRpConfig.spawn.hospital.position)
local found = false
for _, location in ipairs(LightRpConfig.locations) do
    if location.name == "hospital" then hospital(location.position); found = true end
end
assert(found, "staff hospital destination exists")
local pending, request
local life = { phase = "dead", bucket = 0 }
LightRP = {
    module = function(name, module) LightRP[name] = module; return module end,
    log = function() end, notice = function() end,
}
Open77 = { players = {
    getLifeState = function() return life end,
    respawn = function(playerId, options) assert(playerId == 1); request = options; return true end,
} }
SetTimeout = function(delay, callback) assert(delay == LightRpConfig.spawn.respawnDelayMs); pending = callback end
dofile("server/main.lua")
LightRP.spawn.onLifeState(1, "alive"); assert(pending == nil)
LightRP.spawn.onLifeState(1, "dead"); assert(pending); pending()
hospital(request.position)
assert(request.heading == 0 and request.bucket == 0)
assert(request.health == LightRpConfig.spawn.health and request.graceMs == LightRpConfig.spawn.graceMs)
request = nil; life.phase = "alive"; pending(); assert(request == nil, "do not respawn an already revived player")
-- A hall step of the first day guide wakes up at the hall's door, in the hall's bucket; a refusal of the kill is passed on.
local door = { name = "arrival_hall", position = { x = 1, y = 2, z = 3 }, heading = 0, bucket = 620000 }
LightRP.tutorial = { deathPoint = function() return door end, spawnPoint = function() return door end }
life = { phase = "dead", bucket = 620000 }; pending = nil
LightRP.spawn.onLifeState(1, "dead"); pending()
assert(request.position == door.position and request.bucket == 620000, "death in the hall comes back to its door")
request = nil; life = { phase = "dead", bucket = 0 }
assert(LightRP.spawn.place(1, door, "test") and request.position == door.position and request.bucket == 620000, "a placement names its bucket")
LightRP.tutorial.deathPoint = function() return nil end; pending = nil; request = nil; life = { phase = "dead", bucket = 0 }
LightRP.spawn.onLifeState(1, "dead"); pending(); hospital(request.position); assert(request.bucket == 0)
-- a death inside a mission is the mission's (it respawns its operators in its arena)
LightRP.missions = { handlesDeath = function() return true end }
pending = nil; request = nil; life = { phase = "dead", bucket = 3000002 }
LightRP.spawn.onLifeState(1, "dead"); assert(pending == nil and request == nil, "no hospital during a mission")
-- the mission ends during the delay: still not the hospital's (the mission sends them home)
LightRP.missions = { handlesDeath = function() return false end }
LightRP.spawn.onLifeState(1, "dead"); LightRP.missions.handlesDeath = function() return true end; pending(); assert(request == nil)
LightRP.missions = nil
print("PASS: hospital coordinates, staff destination, delayed death respawn, revive guard, arrival hall door, bucketed placement, mission deaths left to the mission")
