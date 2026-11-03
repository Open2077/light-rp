-- op77_chase world: every native the match uses, behind one table, so tests/match_test.lua
-- can replace it with a fake world. Nothing here decides a rule.
ChaseWorld = {}
local W = ChaseWorld

local ALIVE = { alive = true, recovering = true }

local function log(fmt, ...) print(("[op77_chase] " .. fmt):format(...)) end

-- A player id (a positive integer). Bots (server/bots.lua) have negative ids and are
-- answered before they get here; this is the last guard: a non-player id never reaches a
-- player native (some raise on it) nor TriggerClientEvent (-1 is everyone).
local function human(id) return type(id) == "number" and id > 0 and id % 1 == 0 end
W.human = human

function W.now() return math.floor(Open77.time.monotonic() * 1000) end

-- { x, y, z, bucket } or nil (a replicated snapshot, never judged on one sample).
function W.position(id)
    if not human(id) then return nil end
    local ok, p = pcall(Open77.players.position, id)
    if ok and type(p) == "table" and type(p.x) == "number" then return p end
    return nil
end

-- true = alive, false = down (dead, respawn/revive pending...), nil = unknown.
function W.alive(id)
    if not human(id) then return nil end
    local ok, life = pcall(Open77.players.getLifeState, id)
    if not ok or type(life) ~= "table" or life.phase == nil then return nil end
    return ALIVE[tostring(life.phase)] == true
end

function W.name(id)
    if not human(id) then return "#" .. tostring(id) end
    local ok, name = pcall(Open77.players.name, id)
    return ok and type(name) == "string" and name or ("#" .. tostring(id))
end

function W.connected(id)
    for _, other in ipairs(GetPlayers()) do
        if tonumber(other) == id then return true end
    end
    return false
end

function W.setupBucket(bucket)
    -- No ambient population, no client-authored entities leaking in.
    pcall(SetRoutingBucketPopulationEnabled, bucket, false)
    pcall(SetRoutingBucketEntityLockdownMode, bucket, "relaxed")
end

-- Back to empty (a match bucket that had a population).
function W.depopulate(bucket)
    pcall(SetRoutingBucketPopulationEnabled, bucket, false)
end

-- The ambient population of a match bucket (Open77.world.setPopulation, needs
-- world.population): crowd 0..1, traffic 0..1 (a switch on 2.31), police on/off. Every
-- client in the bucket spawns its own; nothing of it is replicated. true | false, reason.
function W.populate(bucket, opts)
    local world = type(Open77) == "table" and Open77.world or nil
    if type(world) ~= "table" or type(world.setPopulation) ~= "function" then return false, "unavailable:world.setPopulation" end
    local ok, result, reason = pcall(world.setPopulation, bucket,
        { crowd = tonumber(opts.crowd) or 0, traffic = tonumber(opts.traffic) or 0, police = opts.police == true })
    if not ok then return false, tostring(result) end
    if not result then return false, tostring(reason or "refused") end
    return true
end

-- ---------------------------------------------------------------- wanted level (NCPD Escape)

-- Open77.players.setWanted / setMaxWanted (players.wanted): pushed to that player's own
-- game, whose police are local to it. true, result | false, reason; never raises.
local function wantedCall(name, id, level)
    if not human(id) then return false, "not_a_player" end
    local api = type(Open77) == "table" and Open77.players or nil
    if type(api) ~= "table" or type(api[name]) ~= "function" then return false, "unavailable:players." .. name end
    local ok, result, reason = pcall(api[name], id, level)
    if not ok then return false, tostring(result) end
    if result == nil or result == false then return false, tostring(reason or "refused") end
    return true, result
end

function W.setWanted(id, level) return wantedCall("setWanted", id, level) end
function W.setMaxWanted(id, level) return wantedCall("setMaxWanted", id, level) end

-- What the server holds for him (players.wanted.read): { level, maxLevel, enabled } | nil.
function W.getWanted(id)
    if not human(id) then return nil end
    local api = type(Open77) == "table" and Open77.players or nil
    if type(api) ~= "table" or type(api.getWanted) ~= "function" then return nil, "unavailable:players.getWanted" end
    local ok, result, reason = pcall(api.getWanted, id)
    if not ok then return nil, tostring(result) end
    if type(result) ~= "table" then return nil, tostring(reason or "refused") end
    return result
end

-- The durable identifier (never called with a non-player id: the native throws on it).
function W.identifier(id)
    if not human(id) then return nil end
    local api = type(Open77) == "table" and Open77.players or nil
    if type(api) ~= "table" or type(api.identifier) ~= "function" then return nil end
    local ok, value = pcall(api.identifier, id)
    return ok and type(value) == "string" and value or nil
end

-- This resource's KVP (no permission): the NCPD Escape ledger of raised wanted levels.
local function kvp(name, ...)
    local api = type(Open77) == "table" and Open77.kvp or nil
    if type(api) ~= "table" or type(api[name]) ~= "function" then return nil, "unavailable:kvp." .. name end
    local ok, result, reason = pcall(api[name], ...)
    if not ok then return nil, tostring(result) end
    return result, reason
end

function W.kvpSet(key, value)
    local ok, why = kvp("set", key, value)
    return ok == true, why
end
function W.kvpDelete(key) return kvp("delete", key) == true end
function W.kvpFind(prefix, limit)
    local rows = kvp("find", prefix, limit or 256)
    return type(rows) == "table" and rows or {}
end

-- Loading cover (op77_loadscreen, optional): an id, or nil when the resource is absent.
function W.cover(id, opts)
    local ok, coverId = pcall(function() return exports.op77_loadscreen:cover(id, opts) end)
    return ok and coverId or nil
end

function W.uncover(id, coverId)
    if coverId == nil then return end
    pcall(function() exports.op77_loadscreen:release(id, coverId) end)
end

-- Put a player on a mark inside the match bucket, asynchronously: done(ok, reason).
-- A living player is teleported (dismounted first if he sits in a car); a player who
-- went down in the last round is respawned on the mark instead (teleport refuses the
-- dead, and Light RP does not respawn a player an activity owns).
function W.place(id, point, bucket, done, cover)
    if not human(id) then done(false, "not_a_player") return end
    CreateThread(function()
        local coverId = cover and W.cover(id, cover) or nil
        local ok, a, b = pcall(function()
            if W.alive(id) == false then
                local respawned, why = Open77.players.respawn(id, { position = point.position, heading = point.heading or 0, bucket = bucket })
                if not respawned then return false, tostring(why or "respawn_refused") end
                for _ = 1, 60 do
                    Wait(250)
                    if W.alive(id) then return true end
                end
                return false, "respawn_timeout"
            end
            local promise, why = Open77.players.teleport(id, point.position, {
                heading = point.heading or 0, bucket = bucket, fade = true, dismount = true, timeoutMs = 30000 })
            if not promise then return false, tostring(why or "teleport_refused") end
            local placed, failure = promise:await()
            if not placed then return false, tostring(failure or "teleport_failed") end
            return true
        end)
        W.uncover(id, coverId)
        if not ok then done(false, tostring(a)) return end
        done(a == true, b)
    end)
end

-- Hold (or release this resource's hold on) a player's body on his mark.
function W.freeze(id, frozen)
    if not human(id) then return false end
    if type(Open77.players.setFrozen) ~= "function" then return false end
    local ok, done = pcall(Open77.players.setFrozen, id, frozen == true)
    return ok and done == true
end

-- Respawn a downed player where he lies (match bucket) so Light RP can move him home.
function W.respawnInPlace(id, bucket, fallback)
    if not human(id) then return false, "not_a_player" end
    local p = W.position(id) or (fallback and fallback.position)
    if p == nil then return false, "no_position" end
    local ok, done, why = pcall(Open77.players.respawn, id, { position = { x = p.x, y = p.y, z = p.z }, heading = 0, bucket = bucket })
    if not ok then return false, tostring(done) end
    return done == true, why
end

-- ---------------------------------------------------------------- cars

local function vehicleCall(name, ...)
    local api = Open77 and Open77.vehicles
    if type(api) ~= "table" or type(api[name]) ~= "function" then return nil, "vehicles_api_unavailable:" .. name end
    local ok, result, reason = pcall(api[name], ...)
    if not ok then return nil, tostring(result) end
    if result == nil then return nil, reason or "rejected" end
    return result, reason
end

local function flagsFor(spec)
    local flags = Open77 and Open77.vehicles and Open77.vehicles.flags
    if type(flags) ~= "table" then return nil end
    local mask = spec.engineOff and 0 or (flags.engineOn or 0)
    if spec.lightsOn then mask = mask | (flags.lightsOn or 0) end
    if spec.sirenOn then mask = mask | (flags.sirenOn or 0) end
    -- Roadblock cars (Most Wanted): scenery nobody can take or shoot out of the way.
    if spec.locked then mask = mask | (flags.locked or 0) end
    if spec.immortal then mask = mask | (flags.immortal or 0) end
    return mask ~= 0 and mask or nil
end

-- A match car on its mark, in the match bucket. The cop's NCPD livery has no `_player`
-- record; when it is refused the plain chassis is used (and logged).
function W.createCar(spec, mark, bucket)
    local definition = { record = spec.record, position = mark.position, yaw = mark.yaw, bucket = bucket,
        health = 1.0, flags = flagsFor(spec) }
    local id, reason = vehicleCall("create", definition)
    local record = spec.record
    if id == nil and spec.fallbackRecord and spec.fallbackRecord ~= spec.record then
        log("car record %s refused (%s); using %s", tostring(spec.record), tostring(reason), spec.fallbackRecord)
        definition.record, record = spec.fallbackRecord, spec.fallbackRecord
        id, reason = vehicleCall("create", definition)
    end
    if id == nil then return nil, reason end
    return id, record
end

function W.removeCar(carId)
    if carId == nil then return false end
    local ok = vehicleCall("remove", carId)
    return ok ~= nil
end

-- Anything this resource still owns in a bucket (a car whose removal failed).
function W.sweepBucket(bucket)
    local all = vehicleCall("all", bucket)
    if type(all) ~= "table" then return 0 end
    local me, removed = GetCurrentResourceName(), 0
    for _, vehicle in ipairs(all) do
        if type(vehicle) == "table" and tostring(vehicle.resource) == me and (vehicle.bucket == nil or vehicle.bucket == bucket) then
            if vehicleCall("remove", vehicle.id) then removed = removed + 1 end
        end
    end
    return removed
end

function W.carPosition(carId)
    local snapshot = vehicleCall("get", carId)
    if type(snapshot) ~= "table" then return nil end
    if type(snapshot.x) == "number" then return { x = snapshot.x, y = snapshot.y, z = snapshot.z } end
    if type(snapshot.position) == "table" then return snapshot.position end
    return nil
end

-- The vehicle id the player sits in, or nil.
function W.seat(id)
    if not human(id) then return nil end
    local seat = vehicleCall("getPlayerSeat", id)
    if type(seat) == "table" and seat.vehicleId ~= nil then return seat.vehicleId end
    return nil
end

function W.forceOut(id, vehicleId)
    if not human(id) then return false end
    return vehicleCall("forcePlayerOutOfVehicle", id, vehicleId) ~= nil
end

-- ---------------------------------------------------------------- presentation

function W.hud(id, payload) if human(id) then TriggerClientEvent("op77_chase:hud", id, payload) end end
function W.queueHud(id, payload) if human(id) then TriggerClientEvent("op77_chase:queue", id, payload) end end

-- Players whose client shows Light RP's activity HUD (it says so with op77_chase:hudFeed):
-- their chase messages go to the HUD's feed instead of a notification. Everyone else
-- (an older Light RP without the HUD, a queued player in the city) gets notifications.
W.hudFeed = {}

local TONES = { info = "info", success = "success", warning = "danger", error = "danger" }

function W.notify(id, kind, message, durationMs, title)
    if not human(id) then return end
    if W.hudFeed[id] then
        TriggerClientEvent("op77_chase:feed", id, { text = message, tone = TONES[kind or "info"] or "info", title = title })
        return
    end
    if type(Open77.notifications) ~= "table" or type(Open77.notifications.send) ~= "function" then return end
    pcall(Open77.notifications.send, id, { type = kind or "info", title = title or "NCPD Chase", message = message,
        durationMs = durationMs or 5000 })
end

-- A server-wide line from Light RP (op77_lightrp:announce, host-wide event).
function W.announce(text, opts)
    TriggerEvent("op77_lightrp:announce", text, opts or {})
end

-- The answer to a chat command (same channel as Light RP's own command replies).
function W.reply(source, raw, ok, text)
    print("[op77_chase] " .. tostring(text))
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
    end
end
