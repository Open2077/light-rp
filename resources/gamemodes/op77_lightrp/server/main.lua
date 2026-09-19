-- Arrival and death: where a character wakes up. The placement follows the
-- platform's life discipline (kill(script) + respawn in one tick), so streaming,
-- buckets and replication all agree on one position.
local Config = LightRpConfig
local Spawn = LightRP.module("spawn", {})

local joinSpawns = {} -- playerId -> "waiting" | "pending" | "complete"

local function readinessHeld(playerId)
    if type(Open77.ready) ~= "table" or type(Open77.ready.isReady) ~= "function" then return false end
    return not Open77.ready.isReady(playerId)
end

local function placeAt(playerId, position, heading, weapon)
    local life = Open77.players.getLifeState(playerId)
    if life == nil then return false, "player_not_found" end
    if life.phase == "alive" or life.phase == "recovering" then
        local ok, reason = Open77.players.kill(playerId, { cause = "script", weapon = weapon or "lightrp:place" })
        if not ok then return false, reason end
    elseif life.phase ~= "dead" then
        return false, "transition_in_progress"
    end
    return Open77.players.respawn(playerId, {
        position = position, heading = heading or 0, bucket = life.bucket or 0,
        health = Config.spawn.health, graceMs = Config.spawn.graceMs,
    })
end

local function joinPoint(playerId)
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
        local ok, reason = placeAt(playerId, point.position, point.heading, "lightrp:join_spawn")
        if ok then
            joinSpawns[playerId] = "complete"
            LightRP.log("player %d (%s) placed at %s (%.2f, %.2f, %.2f)", playerId, LightRP.characters.displayName(playerId),
                point.name or "?", point.position.x, point.position.y, point.position.z)
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

function Spawn.onGameplayReady(playerId)
    applyJoinSpawn(playerId)
    if Config.welcome.enabled then
        LightRP.notice(playerId, { kind = "info", title = Config.welcome.title, body = Config.welcome.text, durationMs = 12000 })
        LightRP.chat.system(playerId, Config.welcome.text)
    end
end

function Spawn.onReady(playerId)
    if joinSpawns[playerId] ~= "waiting" then return end
    joinSpawns[playerId] = nil
    applyJoinSpawn(playerId)
end

function Spawn.onLifeState(playerId, phase)
    if phase ~= "dead" or readinessHeld(playerId) then return end
    SetTimeout(Config.spawn.respawnDelayMs, function()
        local current = Open77.players.getLifeState(playerId)
        if current == nil or current.phase ~= "dead" then return end
        local ok, reason = Open77.players.respawn(playerId, {
            position = Config.spawn.hospital.position, heading = Config.spawn.hospital.heading or 0,
            bucket = current.bucket or 0, health = Config.spawn.health, graceMs = Config.spawn.graceMs,
        })
        if ok then
            LightRP.notice(playerId, { kind = "warning", title = "Hôpital", body = "Vous vous réveillez à l'hôpital. Les soins ont été facturés à votre assurance.", durationMs = 10000 })
        else
            LightRP.log("hospital respawn for %d rejected: %s", playerId, tostring(reason))
        end
    end)
end

function Spawn.onDisconnected(playerId)
    joinSpawns[playerId] = nil
end

LightRP.log("%s framework ready: %d location(s), %d vehicle(s) in the catalogue, chat range %.0f m",
    Config.serverName, #Config.locations, #Config.vehicles.catalog, Config.chat.icRange)
