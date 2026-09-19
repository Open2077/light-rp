-- One civilian vehicle per player, from the catalogue. Server-owned network
-- vehicles through Open77.vehicles; the page and /car share the same code path.
local Config = LightRpConfig.vehicles
local Vehicles = LightRP.module("vehicles", {})

local garages = {}       -- playerId -> { vehicleId, ... }
local owners = {}        -- vehicleId -> playerId
local lastSpawnMs = {}   -- playerId -> cooldown stamp
local byKey = {}
for _, entry in ipairs(Config.catalog) do byKey[string.lower(entry.key)] = entry end
Vehicles.byKey = byKey

function Vehicles.removeAll(playerId)
    local garage = garages[playerId]
    if garage == nil then return 0 end
    local removed = 0
    for _, id in ipairs(garage) do
        owners[id] = nil
        if Open77.vehicles.remove(id) then removed = removed + 1 end
    end
    garages[playerId] = nil
    LightRP.state(playerId, "vehicles")
    return removed
end

local function spawn(playerId, entry)
    local position = Open77.players.position(playerId)
    if position == nil then return nil, "position_unknown" end
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return nil, "not_alive" end
    local o = Config.spawnOffset
    local id, reason = Open77.vehicles.create({
        record = entry.record,
        position = { x = position.x + o.x, y = position.y + o.y, z = position.z + o.z },
        yaw = 0,
        bucket = position.bucket or 0,
    })
    if id == nil then return nil, reason end
    local garage = garages[playerId] or {}
    garages[playerId] = garage
    garage[#garage + 1] = id
    owners[id] = playerId
    local maximum = math.max(1, math.floor(tonumber(Config.maxPerPlayer) or 1))
    while #garage > maximum do
        local oldest = table.remove(garage, 1)
        owners[oldest] = nil
        Open77.vehicles.remove(oldest)
    end
    return id
end

-- Shared by /car, /lightrp.car and the menu. Returns ok, text.
function Vehicles.request(playerId, key, allowStaffOnly)
    if not Config.enabled then return false, "Les véhicules sont désactivés." end
    local entry = byKey[string.lower(tostring(key or ""))]
    if entry == nil then return false, "Modèle inconnu. /cars pour la liste." end
    if entry.staffOnly and not allowStaffOnly then return false, "Ce modèle est réservé : demandez au staff." end
    local last = lastSpawnMs[playerId]
    local now = LightRP.nowMs()
    if last and now - last < Config.cooldownMs then
        return false, string.format("Patientez %d s avant un nouveau véhicule.", math.ceil((Config.cooldownMs - (now - last)) / 1000))
    end
    local id, reason = spawn(playerId, entry)
    if id == nil then return false, "Véhicule refusé : " .. tostring(reason) end
    lastSpawnMs[playerId] = now
    LightRP.state(playerId, "vehicles")
    return true, entry.label .. " livré à côté de vous."
end

LightRP.stateProvider("vehicles", function(playerId)
    local owned = {}
    for _, id in ipairs(garages[playerId] or {}) do
        local vehicle = Open77.vehicles.get and Open77.vehicles.get(id)
        local record = vehicle and vehicle.record or ""
        local label = "VEHICLE"
        for _, entry in ipairs(Config.catalog) do if entry.record == record then label = entry.label end end
        owned[#owned + 1] = { id = id, key = record, label = label }
    end
    local catalog = {}
    for _, entry in ipairs(Config.catalog) do
        catalog[#catalog + 1] = { key = entry.key, label = entry.label, category = entry.category, staffOnly = entry.staffOnly == true }
    end
    local last = lastSpawnMs[playerId]
    return { catalog = catalog, owned = owned, cooldownUntil = last and (last + Config.cooldownMs) or nil }
end)

function Vehicles.onDisconnected(playerId)
    lastSpawnMs[playerId] = nil
    if Config.removeOnDisconnect then Vehicles.removeAll(playerId) end
end

LightRP.action("vehicle.spawn", function(playerId, payload)
    local ok, text = Vehicles.request(playerId, payload.key, LightRP.staff.isStaff(playerId))
    LightRP.result(playerId, ok, text, "vehicle.spawn")
end)

LightRP.action("vehicle.return", function(playerId)
    local removed = Vehicles.removeAll(playerId)
    LightRP.result(playerId, true, removed > 0 and "Véhicule rendu." or "Vous n'avez aucun véhicule.", "vehicle.return")
end)

LightRP.command("car", { usage = "/car <modèle>" }, function(source, args)
    if args[1] == nil then return false end
    return Vehicles.request(source, args[1], false)
end)

LightRP.command("dv", {}, function(source)
    local removed = Vehicles.removeAll(source)
    return true, removed > 0 and "Véhicule rendu." or "Vous n'avez aucun véhicule."
end)

LightRP.command("cars", {}, function(source)
    LightRP.openMenu(source, "vehicles")
    return true, "Garage ouvert (F5 → Véhicules)."
end)
