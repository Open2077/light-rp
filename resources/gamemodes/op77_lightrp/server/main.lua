-- Arrival and death: where a character wakes up. The placement follows the
-- platform's life discipline (kill(script) + respawn in one tick), so streaming,
-- buckets and replication all agree on one position.
local Config = LightRpConfig
local Spawn = LightRP.module("spawn", {})

local joinSpawns = {} -- playerId -> "waiting" | "pending" | "complete"
-- Placed this session by one of the paths below. Until then the platform still holds
-- the pre-spawn position (the lobby, around 0, 3.6, 0): sampling it would save it as
-- the character's position (measured 2026-11-06, a reconnect before placement).
local placed = {}
function Spawn.placed(playerId) return placed[playerId] == true end
-- The pre-spawn body stands at the world origin, under the street (z 0; the ground of the
-- Westbrook blocks around it is ~7.6 m up): a body within a few metres of it was never placed.
local PRE_SPAWN, PRE_SPAWN_RADIUS = { x = 0, y = 3.6, z = 0 }, 5
local function atPreSpawn(position)
    if type(position) ~= "table" then return true end
    local dx, dy, dz = (position.x or 0) - PRE_SPAWN.x, (position.y or 0) - PRE_SPAWN.y, (position.z or 0) - PRE_SPAWN.z
    return dx * dx + dy * dy + dz * dz <= PRE_SPAWN_RADIUS * PRE_SPAWN_RADIUS
end

local function readinessHeld(playerId)
    if type(Open77.ready) ~= "table" or type(Open77.ready.isReady) ~= "function" then return false end
    return not Open77.ready.isReady(playerId)
end

-- `bucket`: where the point is (the arrival hall has its own); nil keeps the
-- player's bucket.
local function placeAt(playerId, position, heading, weapon, bucket)
    local life = Open77.players.getLifeState(playerId)
    if life == nil then return false, "player_not_found" end
    if life.phase == "alive" or life.phase == "recovering" then
        local ok, reason = Open77.players.kill(playerId, { cause = "script", weapon = weapon or "lightrp:place" })
        if not ok then return false, reason end
    elseif life.phase ~= "dead" then
        return false, "transition_in_progress"
    end
    local ok, reason = Open77.players.respawn(playerId, {
        position = position, heading = heading or 0, bucket = bucket or life.bucket or 0,
        health = Config.spawn.health, graceMs = Config.spawn.graceMs,
    })
    if ok then placed[playerId] = true end
    return ok, reason
end
-- A point several players are sent to (the hall's arrival, the square after the hall) is
-- spread over a disc of `radius` metres, never its exact centre: nobody lands inside
-- another body. The ground there is flat; z is kept.
function Spawn.scatter(position, radius, rand)
    radius = tonumber(radius) or 0
    if type(position) ~= "table" or radius <= 0 then return position end
    rand = rand or math.random
    local angle = rand() * 2 * math.pi
    local r = radius * math.sqrt(0.12 + 0.88 * rand())
    return { x = position.x + math.cos(angle) * r, y = position.y + math.sin(angle) * r, z = position.z }
end

-- For the modules that move a character themselves (the first day guide).
-- A loading cover hides the move; the client lifts it once the body stands on
-- the point (server/modules/zone_loading.lua).
local PLACE_TITLES = { arrival_hall = "Arrival Hall", tutorial_practice = "Practice Area", city = "City Center West" }
function Spawn.place(playerId, point, weapon)
    local position = Spawn.scatter(point.position, point.scatter)
    local cover = LightRP.zoneLoading and LightRP.zoneLoading.cover(playerId, {
        title = point.label or PLACE_TITLES[point.name] or "Night City",
        subtitle = (point.bucket or 0) ~= 0 and "First day" or "Shared city", target = position })
    local ok, reason = placeAt(playerId, position, point.heading, weapon or "lightrp:place", point.bucket)
    if not ok and LightRP.zoneLoading then LightRP.zoneLoading.release(playerId, cover) end
    return ok, reason
end

local function joinPoint(playerId)
    -- The first day guide owns the arrival hall: a hall step wakes up there, and
    -- nobody else is left inside it.
    local guided = LightRP.tutorial and LightRP.tutorial.spawnPoint(playerId)
    if guided then return guided end
    local medical = LightRP.medical and LightRP.medical.spawnPoint(playerId)
    if medical then return medical end
    -- Logged out at home: wake up inside it.
    local home = LightRP.housing and LightRP.housing.spawnPoint and LightRP.housing.spawnPoint(playerId)
    if home then return home end
    local c = LightRP.characters.get(playerId)
    if Config.spawn.restoreLastPosition and c and c.position then
        return { name = "saved", position = c.position, heading = c.heading or 0 }
    end
    return Config.spawn.arrival
end

local function applyJoinSpawn(playerId)
    if joinSpawns[playerId] ~= nil then return end
    if readinessHeld(playerId) then
        joinSpawns[playerId] = "waiting"
        LightRP.log("join spawn for %d deferred: readiness gate is closed", playerId)
        return
    end
    joinSpawns[playerId] = "pending"
    local startedAt = LightRP.nowMs()
    local retryMs = math.max(50, tonumber(Config.spawn.joinRetryMs) or 250)
    local timeoutMs = math.max(retryMs, tonumber(Config.spawn.joinTimeoutMs) or 30000)
    local function attempt()
        if joinSpawns[playerId] ~= "pending" then return end
        local point = joinPoint(playerId)
        local position = Spawn.scatter(point.position, point.scatter)
        local ok, reason = placeAt(playerId, position, point.heading, "lightrp:join_spawn", point.bucket)
        if ok then
            joinSpawns[playerId] = "complete"
            if point.home then LightRP.housing.arrived(playerId, point) end
            LightRP.log("player %d (%s) placed at %s (%.2f, %.2f, %.2f)", playerId, LightRP.characters.displayName(playerId),
                point.name or "?", position.x, position.y, position.z)
            return
        end
        if (reason == "player_not_found" or reason == "transition_in_progress") and LightRP.nowMs() - startedAt < timeoutMs then
            SetTimeout(retryMs, attempt)
            return
        end
        joinSpawns[playerId] = nil
        LightRP.log("join spawn for %d rejected: %s", playerId, tostring(reason))
    end
    attempt()
end

-- Medical recovery reuses this scheduler so a reconnect cannot trigger a
-- second join placement after restoring a saved unconscious character.
function Spawn.restoreMedical(playerId)
    if joinSpawns[playerId] == "pending" then return true end
    joinSpawns[playerId] = nil
    applyJoinSpawn(playerId)
    return true
end

function Spawn.onGameplayReady(playerId)
    -- A draft character is not placed: the wizard covers the world and the
    -- arrival happens on character.finish (onCharacterActivated).
    if LightRP.characters.isRegistered(playerId) then applyJoinSpawn(playerId) end
    if Config.welcome.enabled then
        LightRP.notice(playerId, { kind = "info", title = Config.welcome.title, body = Config.welcome.text, durationMs = 12000 })
        LightRP.chat.system(playerId, Config.welcome.text)
    end
end

function Spawn.onReady(playerId)
    if joinSpawns[playerId] ~= "waiting" or not LightRP.characters.isRegistered(playerId) then return end
    joinSpawns[playerId] = nil
    applyJoinSpawn(playerId)
end

-- A resource restart (LightRP.adoptConnectedPlayers) leaves everyone where they stand: a
-- body away from the pre-spawn point was placed before the restart. One still at it was not
-- (a join placement the restart cut short); one mid-respawn is marked once it recovers.
function Spawn.onAdopted(playerId)
    local life = Open77.players.getLifeState(playerId)
    if life == nil or (life.phase ~= "alive" and life.phase ~= "recovering" and life.phase ~= "dead") then return end
    if atPreSpawn(Open77.players.position(playerId)) then return end
    placed[playerId] = true
end

function Spawn.onLifeState(playerId, phase)
    -- Every respawn and revive ends in `recovering` once the client applied it, at the point a
    -- module chose: the hospital below, the clinic (medical.lua), a mission arena, a staff
    -- revive. All of them place the player, not only placeAt.
    if phase == "recovering" then placed[playerId] = true end
    if phase ~= "dead" or readinessHeld(playerId) then return end
    if LightRP.medical and LightRP.medical.handlesDeath(playerId) then return end
    -- a mission respawns its own operators (in its arena, or at the point when it ends)
    if LightRP.missions and LightRP.missions.handlesDeath and LightRP.missions.handlesDeath(playerId) then return end
    -- ... and so does an activity (server/modules/activities.lua)
    if LightRP.activities and LightRP.activities.owns(playerId) then return end
    SetTimeout(Config.spawn.respawnDelayMs, function()
        if LightRP.missions and LightRP.missions.handlesDeath and LightRP.missions.handlesDeath(playerId) then return end
        if LightRP.activities and LightRP.activities.owns(playerId) then return end
        local current = Open77.players.getLifeState(playerId)
        if current == nil or current.phase ~= "dead" then return end
        -- During a hall step of the first day guide: back at the hall's door.
        local guided = LightRP.tutorial and LightRP.tutorial.deathPoint(playerId)
        local point = guided or Config.spawn.hospital
        local ok, reason = Open77.players.respawn(playerId, {
            position = point.position, heading = point.heading or 0,
            bucket = point.bucket or current.bucket or 0, health = Config.spawn.health, graceMs = Config.spawn.graceMs,
        })
        if ok and guided then
            LightRP.notice(playerId, { kind = "info", title = "Arrival Hall", body = "Nothing is lost here. You are back at the door of the hall.", durationMs = 8000 })
        elseif ok then
            LightRP.notice(playerId, { kind = "warning", title = "Hospital", body = "You wake up at the hospital. The bill went to your insurance.", durationMs = 10000 })
        else
            LightRP.log("hospital respawn for %d rejected: %s", playerId, tostring(reason))
        end
    end)
end

-- A character just finished the wizard: they start at the arrival point, whatever
-- position the draft may have sampled while they were being built.
function Spawn.onCharacterActivated(playerId)
    local point = LightRP.tutorial and LightRP.tutorial.spawnPoint(playerId) or Config.spawn.arrival
    local ok, reason = placeAt(playerId, point.position, point.heading, "lightrp:character_activated", point.bucket)
    if not ok then
        LightRP.log("arrival placement for %d after creation rejected: %s", playerId, tostring(reason))
        return
    end
    LightRP.chat.system(playerId, Config.welcome.text)
end

-- Another slot took over: go where that character was, or to the arrival point
-- when it is new. The appearance package reloads the body on its side.
function Spawn.onCharacterSwitched(playerId, character)
    if character == nil or character.status ~= "active" then return end
    local point = LightRP.tutorial and LightRP.tutorial.spawnPoint(playerId)
        or (LightRP.medical and LightRP.medical.spawnPoint(playerId))
        or (character.position and { name = "saved", position = character.position, heading = character.heading or 0 }) or Config.spawn.arrival
    local ok, reason = placeAt(playerId, point.position, point.heading, "lightrp:character_switch", point.bucket or 0)
    if not ok then LightRP.log("placement for %d after switch rejected: %s", playerId, tostring(reason)) end
end

function Spawn.onDisconnected(playerId)
    joinSpawns[playerId] = nil
    placed[playerId] = nil
end

LightRP.log("%s framework ready: %d location(s), %d vehicle(s) in the catalogue, chat range %.0f m",
    Config.serverName, #Config.locations, #Config.vehicles.catalog, Config.chat.icRange)
