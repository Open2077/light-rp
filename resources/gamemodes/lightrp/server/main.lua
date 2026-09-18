-- Light Roleplay: arrival, death, vehicles and the staff commands.
--
-- Placement follows the platform's life discipline: a player is moved through
-- kill(script) + respawn(position) so streaming, buckets and replication all
-- see one canonical position (see freeroam for the original transaction).
local Config = LightRpConfig
local nowMs = LightRp.nowMs
local log = LightRp.log
local reply = LightRp.reply

local joinSpawns = {}     -- playerId -> "waiting" | "pending" | "complete"
local readyDetail = {}    -- playerId -> detail string from onPlayerReady
local garages = {}        -- playerId -> { vehicleId, ... }
local vehicleOwners = {}  -- vehicleId -> playerId
local lastVehicleMs = {}  -- playerId -> cooldown stamp

local locationsByName = {}
for _, location in ipairs(Config.locations) do
    locationsByName[string.lower(location.name)] = location
end

local vehiclesByKey = {}
for _, vehicle in ipairs(Config.vehicles.catalog) do
    vehiclesByKey[string.lower(vehicle.key)] = vehicle
end

local function notify(playerId, title, message, kind, durationMs)
    pcall(function()
        Open77.notifications.send(playerId, {
            type = kind or "info",
            title = title,
            message = message,
            durationMs = durationMs or 8000,
        })
    end)
end
LightRp.notify = notify

-- ---------------------------------------------------------------------------
-- Placement

local function readinessHeld(playerId)
    if type(Open77.ready) ~= "table" or type(Open77.ready.isReady) ~= "function" then return false end
    return not Open77.ready.isReady(playerId)
end

-- Kill + respawn in the same tick: the client only sees the fade.
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
        position = position,
        heading = heading or 0,
        bucket = life.bucket or 0,
        health = Config.spawn.health,
        graceMs = Config.spawn.graceMs,
    })
end

local function respawnAt(playerId, point)
    local life = Open77.players.getLifeState(playerId)
    if life == nil then return false, "player_not_found" end
    if life.phase ~= "dead" then return false, "invalid_state" end
    return Open77.players.respawn(playerId, {
        position = point.position,
        heading = point.heading or 0,
        bucket = life.bucket or 0,
        health = Config.spawn.health,
        graceMs = Config.spawn.graceMs,
    })
end

-- Where a joining player goes: their saved position when they have one, the
-- arrival point otherwise.
local function joinPoint(playerId)
    local character = LightRp.characters[playerId]
    if Config.spawn.restoreLastPosition and character and character.position then
        return { name = "saved", position = character.position, heading = character.heading or 0 }
    end
    return Config.spawn.arrival
end

local function applyJoinSpawn(playerId)
    if joinSpawns[playerId] ~= nil then return end
    if readinessHeld(playerId) then
        joinSpawns[playerId] = "waiting"
        log("join spawn for %d deferred: readiness gate is closed", playerId)
        return
    end
    joinSpawns[playerId] = "pending"
    local startedAt = nowMs()
    local retryMs = math.max(50, tonumber(Config.spawn.joinRetryMs) or 250)
    local timeoutMs = math.max(retryMs, tonumber(Config.spawn.joinTimeoutMs) or 30000)
    local function attempt()
        if joinSpawns[playerId] ~= "pending" then return end
        local point = joinPoint(playerId)
        local ok, reason = placeAt(playerId, point.position, point.heading, "lightrp:join_spawn")
        if ok then
            joinSpawns[playerId] = "complete"
            log("player %d (%s) placed at %s (%.2f, %.2f, %.2f)", playerId, LightRp.displayName(playerId),
                point.name or "?", point.position.x, point.position.y, point.position.z)
            return
        end
        if (reason == "player_not_found" or reason == "transition_in_progress") and nowMs() - startedAt < timeoutMs then
            SetTimeout(retryMs, attempt)
            return
        end
        joinSpawns[playerId] = nil
        log("join spawn for %d rejected: %s", playerId, tostring(reason))
    end
    attempt()
end

local function gameplayReady()
    local playerId = tonumber(source)
    if playerId == nil or playerId <= 0 then return end
    applyJoinSpawn(playerId)
    if Config.welcome.enabled then
        notify(playerId, Config.welcome.title, Config.welcome.text, "info", 12000)
        LightRp.system(playerId, Config.welcome.text)
        if not LightRp.isRegistered(playerId) then
            LightRp.system(playerId, "Créez votre personnage : /register Prénom Nom")
        end
    end
end

-- The protected shell raises this once the world and the player's body exist.
RegisterNetEvent("open77:session:gameplayReady", gameplayReady)

AddEventHandler("onPlayerReady", function(playerIdStr, detail)
    local playerId = tonumber(playerIdStr)
    if playerId == nil or playerId <= 0 then return end
    readyDetail[playerId] = type(detail) == "string" and detail or ""
    if joinSpawns[playerId] ~= "waiting" then return end
    joinSpawns[playerId] = nil
    applyJoinSpawn(playerId)
end)

-- Death: the character wakes up at the hospital after a moment on the ground.
AddEventHandler("onPlayerLifeStateChanged", function(playerIdStr, _, phase)
    if phase ~= "dead" then return end
    local playerId = tonumber(playerIdStr)
    if playerId == nil or readinessHeld(playerId) then return end
    SetTimeout(Config.spawn.respawnDelayMs, function()
        local current = Open77.players.getLifeState(playerId)
        if current == nil or current.phase ~= "dead" then return end
        local ok, reason = respawnAt(playerId, Config.spawn.hospital)
        if ok then
            notify(playerId, "Hôpital", "Vous vous réveillez à l'hôpital. Les soins ont été facturés à votre assurance.", "warning", 10000)
        else
            log("hospital respawn for %d rejected: %s", playerId, tostring(reason))
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Vehicles: one per player, from the catalogue.

local function removeGarage(playerId)
    local garage = garages[playerId]
    if garage == nil then return 0 end
    local removed = 0
    for _, id in ipairs(garage) do
        vehicleOwners[id] = nil
        if Open77.vehicles.remove(id) then removed = removed + 1 end
    end
    garages[playerId] = nil
    return removed
end

local function spawnVehicle(playerId, entry)
    local position = Open77.players.position(playerId)
    if position == nil then return nil, "position_unknown" end
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return nil, "not_alive" end
    local offset = Config.vehicles.spawnOffset
    local id, reason = Open77.vehicles.create({
        record = entry.record,
        position = { x = position.x + offset.x, y = position.y + offset.y, z = position.z + offset.z },
        yaw = 0,
        bucket = position.bucket or 0,
    })
    if id == nil then return nil, reason end
    local garage = garages[playerId] or {}
    garages[playerId] = garage
    garage[#garage + 1] = id
    vehicleOwners[id] = playerId
    local maximum = math.max(1, math.floor(tonumber(Config.vehicles.maxPerPlayer) or 1))
    while #garage > maximum do
        local oldest = table.remove(garage, 1)
        vehicleOwners[oldest] = nil
        Open77.vehicles.remove(oldest)
    end
    return id
end

local function requestVehicle(source, args, raw, allowStaffOnly)
    if not Config.vehicles.enabled then return reply(source, raw, false, "Les véhicules sont désactivés.") end
    local key = string.lower(args[1] or "")
    local entry = vehiclesByKey[key]
    if entry == nil then return reply(source, raw, false, "Modèle inconnu. /cars pour la liste.") end
    if entry.staffOnly and not allowStaffOnly then
        return reply(source, raw, false, "Ce modèle est réservé : demandez au staff.")
    end
    local last = lastVehicleMs[source]
    if last and nowMs() - last < Config.vehicles.cooldownMs then
        return reply(source, raw, false, string.format("Patientez %d s avant un nouveau véhicule.",
            math.ceil((Config.vehicles.cooldownMs - (nowMs() - last)) / 1000)))
    end
    local id, reason = spawnVehicle(source, entry)
    if id == nil then return reply(source, raw, false, "Véhicule refusé : " .. tostring(reason)) end
    lastVehicleMs[source] = nowMs()
    reply(source, raw, true, entry.label .. " livré à côté de vous.")
end

RegisterCommand("car", function(source, args, raw) requestVehicle(source, args, raw, false) end, false)

RegisterCommand("dv", function(source, _, raw)
    local removed = removeGarage(source)
    reply(source, raw, true, removed > 0 and "Véhicule rendu." or "Vous n'avez aucun véhicule.")
end, false)

RegisterCommand("cars", function(source, _, raw)
    local byCategory = {}
    for _, entry in ipairs(Config.vehicles.catalog) do
        if not entry.staffOnly then
            byCategory[entry.category] = byCategory[entry.category] or {}
            table.insert(byCategory[entry.category], entry.key)
        end
    end
    for category, keys in pairs(byCategory) do
        table.sort(keys)
        LightRp.system(source, category .. " : " .. table.concat(keys, ", "))
    end
    reply(source, raw, true, "/car <modèle> pour en appeler un.")
end, false)

-- ---------------------------------------------------------------------------
-- Staff commands (restricted: the caller needs command.lightrp.<name> in the ACL)

local function parseTarget(source, value)
    if value == nil or value == "" or value == "me" then return source end
    local id = tonumber(value)
    if id == nil or GetPlayerName(id) == nil then return nil end
    return id
end

local function parseDestination(args, from)
    local first = args[from]
    if first == nil then return nil end
    local named = locationsByName[string.lower(first)]
    if named then return named.position, named.heading or 0, named.label end
    local x, y, z = tonumber(first), tonumber(args[from + 1]), tonumber(args[from + 2])
    if x == nil or y == nil or z == nil then return nil end
    return { x = x, y = y, z = z }, 0, string.format("%.1f, %.1f, %.1f", x, y, z)
end

-- Move a player, alive or dead, to a position.
local function moveTo(playerId, position, heading, callback)
    local life = Open77.players.getLifeState(playerId)
    if life == nil then return callback(false, "player_not_found") end
    if life.phase == "dead" then
        return callback(Open77.players.respawn(playerId, {
            position = position, heading = heading or 0, bucket = life.bucket or 0,
            health = Config.spawn.health, graceMs = Config.spawn.graceMs,
        }))
    end
    CreateThread(function()
        local promise, reason = Open77.players.teleport(playerId, position, { heading = heading or 0, dismount = true })
        if promise == nil then return callback(false, reason) end
        local placed, why = promise:await()
        callback(placed ~= nil and placed ~= false, why)
    end)
end

RegisterCommand("lightrp.tp", function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil then return reply(source, raw, false, "usage: /lightrp.tp <id|me> <lieu | x y z>") end
    local position, heading, label = parseDestination(args, 2)
    if position == nil then
        local names = {}
        for _, location in ipairs(Config.locations) do names[#names + 1] = location.name end
        return reply(source, raw, false, "Lieux : " .. table.concat(names, ", ") .. " (ou x y z)")
    end
    moveTo(target, position, heading, function(ok, reason)
        reply(source, raw, ok, ok and (LightRp.displayName(target) .. " → " .. label) or ("Téléportation refusée : " .. tostring(reason)))
    end)
end, true)

RegisterCommand("lightrp.bring", function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil or target == source then return reply(source, raw, false, "usage: /lightrp.bring <id>") end
    local here = Open77.players.position(source)
    if here == nil then return reply(source, raw, false, "Votre position est inconnue.") end
    moveTo(target, { x = here.x + 1.5, y = here.y, z = here.z }, 0, function(ok, reason)
        reply(source, raw, ok, ok and (LightRp.displayName(target) .. " amené.") or ("Refusé : " .. tostring(reason)))
    end)
end, true)

RegisterCommand("lightrp.goto", function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil or target == source then return reply(source, raw, false, "usage: /lightrp.goto <id>") end
    local there = Open77.players.position(target)
    if there == nil then return reply(source, raw, false, "Position de la cible inconnue.") end
    moveTo(source, { x = there.x + 1.5, y = there.y, z = there.z }, 0, function(ok, reason)
        reply(source, raw, ok, ok and ("Vous êtes auprès de " .. LightRp.displayName(target)) or ("Refusé : " .. tostring(reason)))
    end)
end, true)

RegisterCommand("lightrp.heal", function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil then return reply(source, raw, false, "usage: /lightrp.heal <id|me>") end
    local life = Open77.players.getLifeState(target)
    if life and life.phase ~= "alive" then
        local ok, reason = Open77.players.revive(target, {})
        return reply(source, raw, ok, ok and (LightRp.displayName(target) .. " réanimé.") or ("Refusé : " .. tostring(reason)))
    end
    local ok, reason = Open77.players.heal(target, 10000)
    reply(source, raw, ok, ok and (LightRp.displayName(target) .. " soigné.") or ("Refusé : " .. tostring(reason)))
end, true)

RegisterCommand("lightrp.announce", function(source, args, raw)
    local text = LightRp.joinArgs(args)
    if text == "" then return reply(source, raw, false, "usage: /lightrp.announce <message>") end
    LightRp.broadcast("STAFF", text, Config.chat.colors.staff)
    pcall(function()
        Open77.notifications.broadcast({ type = "warning", title = "Annonce du staff", message = text, durationMs = 12000 })
    end)
    reply(source, raw, true, "Annonce envoyée.")
end, true)

RegisterCommand("lightrp.setname", function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil or args[2] == nil or args[3] == nil then
        return reply(source, raw, false, "usage: /lightrp.setname <id> <Prénom> <Nom>")
    end
    local ok, reason = LightRp.register(target, args[2], args[3])
    if not ok then return reply(source, raw, false, "Nom refusé : " .. tostring(reason)) end
    LightRp.system(target, "Le staff a renommé votre personnage : " .. LightRp.displayName(target))
    reply(source, raw, true, "Personnage renommé : " .. LightRp.displayName(target))
end, true)

RegisterCommand("lightrp.car", function(source, args, raw) requestVehicle(source, args, raw, true) end, true)

RegisterCommand("lightrp.status", function(source, _, raw)
    local players = GetPlayers()
    local registered, vehicles = 0, 0
    for _, id in ipairs(players) do if LightRp.isRegistered(id) then registered = registered + 1 end end
    for _ in pairs(vehicleOwners) do vehicles = vehicles + 1 end
    reply(source, raw, true, string.format("%s: %d joueurs (%d personnages enregistrés), %d véhicules, base de données %s.",
        Config.serverName, #players, registered, vehicles, LightRp.hasDatabase() and "active" or "absente"))
end, true)

-- ---------------------------------------------------------------------------
-- Cleanup

AddEventHandler("onPlayerDisconnected", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if playerId == nil then return end
    joinSpawns[playerId] = nil
    readyDetail[playerId] = nil
    lastVehicleMs[playerId] = nil
    if Config.vehicles.removeOnDisconnect then removeGarage(playerId) end
end)

log("%s ready: %d locations, %d vehicles in the catalogue, chat range %.0f m",
    Config.serverName, #Config.locations, #Config.vehicles.catalog, Config.chat.icRange)
