-- A disconnect (or a character switch) inside a mission or activity instance must
-- not save the instance's coordinates as the character's position: the sampled
-- position is what save() writes to last_x/y/z on the way out.
dofile("shared/config.lua")
dofile("server/config/missions.lua")
dofile("server/config/activities.lua")
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
-- The modules' background loops (sampling, upkeep) never run here; only the
-- threads started after loading do, by run().
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
local bucket = 0
GetPlayerRoutingBucket = function() return bucket end
local where = { x = 100, y = 200, z = 30 }
Open77 = {
    players = {
        position = function() return { x = where.x, y = where.y, z = where.z, bucket = bucket } end,
        getLifeState = function() return { phase = "alive" } end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 end },
}
dofile("server/modules/characters.lua")
local C = LightRP.characters
C.byPlayer[1] = { identifier = "account-1", key = "default", status = "active", firstName = "Alex", lastName = "Morgan" }

-- A mission instance: the operator stands in the mission's arena, its own bucket.
local instance = { point = "sector04_blackout" }
local missionPoint = LightRpMissions.points[1]
LightRP.missions = {
    handlesDeath = function(id) return instance ~= nil end,
    handlesLoadout = function() return false end,
    instanceOf = function() return instance end,
    point = function(id) return id == missionPoint.id and missionPoint or nil end,
}
instance.point = missionPoint.id
bucket, where = 3000001, { x = 5000, y = -5000, z = 400 }

dofile("server/modules/activities.lua")
local A = LightRP.activities
loaded = true

C.samplePosition(1)
C.onDisconnected(1)
run()
assert(saved, "the disconnect saved a position")
assert(saved.x ~= 5000 and saved.y ~= -5000, "a disconnect inside a mission instance saves the instance coordinates")
assert(saved.x == missionPoint.position.x and saved.y == missionPoint.position.y,
    "the mission operator comes back at the mission point, where the mission sends them home")

-- An activity of a provider: the return point captured on entry is what is saved.
instance = nil
C.byPlayer[1] = { identifier = "account-1", key = "default", status = "active", firstName = "Alex", lastName = "Morgan" }
LightRP.characters = C
bucket, where = 0, { x = -756, y = 777, z = 22 }
assert(A.register({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp" }))
assert(A.enter(1, "arena.ffa"))
bucket, where = 4100001, { x = 9000, y = 9000, z = 90 }
C.samplePosition(1)
saved = nil
C.onDisconnected(1)
run()
assert(saved and saved.x == -756 and saved.y == 777 and saved.z == 22,
    "a disconnect inside an activity saves the return point, never the instance")
print("PASS: a disconnect inside a mission or activity instance saves the mission point or the return point, never the instance coordinates")
