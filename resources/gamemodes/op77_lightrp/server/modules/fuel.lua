-- Fuel. Cyberpunk has no fuel model, so the tank is a STATE-BAG FIELD the
-- server owns on every network vehicle: `fuel` (litres) and `fuelMax` (tank
-- size) on Open77.state.entity("vehicle", id). Every client streaming the car
-- reads both for free (the HUD gauge in client/core/hud.lua); nobody but this
-- module writes them, so a gauge a client could set is not a thing here.
--
-- Once a second the module walks the vehicle registry and burns the tank from
-- the replicated speed while the engine runs (litres/100 km moving, litres/min
-- idling, see LightRpConfig.fuel). At zero the vehicle is made undrivable (that
-- also cuts the engine) and kept that way until someone refuels: a pump at a
-- gas station (E next to the pump, page dialog "fuel") or a jerrycan used from
-- the inventory. Rentals arrive with a partial tank; owned vehicles keep their
-- level through the garage (lightrp_vehicle_fuel, keyed by the ownership id).
--
--   LightRP.fuel.info(vehicleId)              -> { litres, capacity, fraction, empty, low } | nil
--   LightRP.fuel.level(vehicleId)             -> litres | nil (nil = not seen yet, reads as full)
--   LightRP.fuel.set(vehicleId, litres)       -> litres (clamped) | nil, reason
--   LightRP.fuel.add(vehicleId, litres)       -> litres actually added
--   LightRP.fuel.seed(vehicleId, "rental"|"full"|fraction)
--   LightRP.fuel.isEmpty(vehicleId)
--   LightRP.fuel.store(ownerId, vehicleId) / LightRP.fuel.restore(vehicleId, ownerId)  (garages)
--   hooks: onFuelEmpty(vehicleId, driverId), onFuelLow(vehicleId, driverId)
local Config = LightRpConfig.fuel or {}
local Db = LightRP.db
local Fuel = LightRP.module("fuel", {})

local KEY, KEY_MAX = "fuel", "fuelMax"
local tanks = {}     -- vehicleId -> { litres, capacity, empty, warned, record }
local stored = {}    -- ownerId -> litres (owned vehicles in a garage, mirrored in SQL)
Fuel.tanks = tanks

if Config.enabled == false then
    LightRP.log("fuel: disabled by config")
    return
end

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_vehicle_fuel (
        owner_id   VARCHAR(96) NOT NULL PRIMARY KEY,
        litres     DOUBLE      NOT NULL,
        updated_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
]])

-- ---------------------------------------------------------------------------
-- Model

local function round1(value) return math.floor(value * 10.0 + 0.5) / 10.0 end

local function flagsOf()
    local names = type(Open77.vehicles.flags) == "table" and Open77.vehicles.flags or {}
    return names.engineOn or 1, names.destroyed or 0
end

-- Tank size from the catalogue category of the record (shared/config.lua).
local function capacityOf(record)
    record = LightRpConfig.baseRecord(record)
    local tanksByCategory = Config.tanks or {}
    if LightRP.vehicles and LightRP.vehicles.byKey then
        for _, entry in pairs(LightRP.vehicles.byKey) do
            if entry.record == record then
                return tonumber(tanksByCategory[entry.category]) or tonumber(tanksByCategory.default) or 60
            end
        end
    end
    return tonumber(tanksByCategory.default) or 60
end

function Fuel.labelOf(record)
    record = LightRpConfig.baseRecord(record)
    if LightRP.vehicles and LightRP.vehicles.byKey then
        for _, entry in pairs(LightRP.vehicles.byKey) do if entry.record == record then return entry.label end end
    end
    local label = record:gsub("^Vehicle%.v_%w+_", ""):gsub("_player$", ""):gsub("_", " ")
    return label:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end

local function bag(vehicleId)
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return nil end
    local ok, handle = pcall(Open77.state.entity, "vehicle", vehicleId)
    if ok then return handle end
    return nil
end

local function write(vehicleId, tank)
    local handle = bag(vehicleId)
    if handle == nil then return false end
    local ok, reason = handle:set(KEY, tank.litres)
    if not ok then LightRP.log("fuel: bag write refused for %s: %s", tostring(vehicleId), tostring(reason)) return false end
    if tank.publishedMax ~= tank.capacity then
        handle:set(KEY_MAX, tank.capacity)
        tank.publishedMax = tank.capacity
    end
    return true
end

-- Litres burned over dt seconds. A moving car burns by distance whatever the
-- engine bit says (the owner's report can lag behind the ignition); a stopped
-- car burns the idle rate only while its engine runs.
local function burn(engineOn, speedMps, dtSeconds)
    if dtSeconds <= 0 then return 0.0 end
    if type(speedMps) ~= "number" or speedMps ~= speedMps or speedMps < 0 then speedMps = 0.0 end
    local litres
    if speedMps >= 1.0 then
        litres = (speedMps * dtSeconds / 1000.0) * (Config.litresPerHundredKm or 12.0) / 100.0
    elseif engineOn then
        litres = (Config.idleLitresPerMinute or 0.08) * dtSeconds / 60.0
    else
        return 0.0
    end
    return litres * (Config.multiplier or 1.0)
end

-- The tank of a vehicle, created on first sight. A bag that already carries a
-- level (resource restart) wins over "starts full".
local function tankOf(vehicleId, snapshot)
    local tank = tanks[vehicleId]
    if tank then return tank end
    snapshot = snapshot or Open77.vehicles.get(vehicleId)
    if snapshot == nil then return nil end
    tank = { record = snapshot.record, capacity = capacityOf(snapshot.record), empty = false, warned = false }
    local handle = bag(vehicleId)
    local known = handle and handle:get(KEY)
    tank.litres = type(known) == "number" and math.max(0, math.min(tank.capacity, known)) or tank.capacity
    tank.empty = tank.litres <= 0
    tanks[vehicleId] = tank
    write(vehicleId, tank)
    return tank
end

local function driverOf(vehicleId)
    local ok, driver = pcall(Open77.vehicles.getDriver, vehicleId)
    if ok and type(driver) == "number" and driver > 0 then return driver end
    return nil
end

-- Out of fuel: throttle locked, engine off, and it stays that way (the owner's
-- report can flip the engine back on; the platform holds a server bit against
-- it for a while, so the tick re-asserts as long as the tank is dry).
local function cut(vehicleId, tank, announce)
    pcall(Open77.vehicles.setDrivable, vehicleId, false)
    if announce and not tank.empty then
        tank.empty = true
        local driver = driverOf(vehicleId)
        if driver then
            LightRP.notice(driver, { kind = "warning", title = "OUT OF FUEL", body = "The engine died. Find a jerrycan or get the car to a gas station.", durationMs = 9000 })
        end
        LightRP.log("fuel: vehicle %s (%s) ran out of fuel", tostring(vehicleId), tostring(tank.record))
        LightRP.eachModule("onFuelEmpty", vehicleId, driver)
    end
    tank.empty = true
end

local function revive(vehicleId, tank)
    if not tank.empty then return end
    tank.empty = false
    tank.warned = false
    pcall(Open77.vehicles.setDrivable, vehicleId, true)
    -- After a fill-up the driver expects the car to start: give the ignition back.
    if driverOf(vehicleId) then pcall(Open77.vehicles.setEngine, vehicleId, true) end
end

-- ---------------------------------------------------------------------------
-- Public API

function Fuel.level(vehicleId)
    local tank = tanks[vehicleId]
    return tank and tank.litres or nil
end

function Fuel.isEmpty(vehicleId)
    local tank = tanks[vehicleId]
    return tank ~= nil and tank.litres <= 0
end

function Fuel.info(vehicleId)
    local tank = tankOf(vehicleId)
    if tank == nil then return nil end
    return { litres = tank.litres, capacity = tank.capacity, fraction = tank.capacity > 0 and tank.litres / tank.capacity or 0,
        empty = tank.litres <= 0, low = tank.capacity > 0 and tank.litres / tank.capacity <= (Config.reserve or 0.15) }
end

function Fuel.set(vehicleId, litres)
    local tank = tankOf(vehicleId)
    if tank == nil then return nil, "vehicle_not_found" end
    litres = tonumber(litres)
    if litres == nil or litres ~= litres then return nil, "invalid_amount" end
    local old, exact = tank.litres, tank.exact
    tank.litres = round1(math.max(0, math.min(tank.capacity, litres)))
    tank.exact = tank.litres -- the sub-tenth accumulator of the tick restarts from a set
    if not write(vehicleId, tank) then tank.litres, tank.exact = old, exact; return nil, "state_write_failed" end
    if tank.litres <= 0 then cut(vehicleId, tank, true) else revive(vehicleId, tank) end
    return tank.litres
end

-- Adds up to `litres`, never over the brim. Returns what went in.
function Fuel.add(vehicleId, litres)
    local tank = tankOf(vehicleId)
    if tank == nil then return 0 end
    litres = math.max(0, tonumber(litres) or 0)
    local room = math.max(0, tank.capacity - tank.litres)
    local added = round1(math.min(room, litres))
    if added <= 0 then return 0 end
    local level = Fuel.set(vehicleId, tank.litres + added)
    return level and added or 0
end

-- "rental" = a random partial tank; "full"; or a fraction 0..1.
function Fuel.seed(vehicleId, how)
    local tank = tankOf(vehicleId)
    if tank == nil then return nil end
    local fraction = 1.0
    if how == "rental" then
        local range = Config.rentalTank or { min = 0.35, max = 0.75 }
        fraction = (range.min or 0.35) + math.random() * ((range.max or 0.75) - (range.min or 0.35))
    elseif type(how) == "number" then
        fraction = math.max(0, math.min(1, how))
    end
    return Fuel.set(vehicleId, tank.capacity * fraction)
end

-- Garages: the level follows the ownership record into storage and back.
function Fuel.store(ownerId, vehicleId)
    local tank = tanks[vehicleId]
    if ownerId == nil or tank == nil then return end
    stored[ownerId] = tank.litres
    if Db.ready then
        Db.run("INSERT INTO lightrp_vehicle_fuel (owner_id, litres) VALUES (?, ?) ON DUPLICATE KEY UPDATE litres = VALUES(litres)", { tostring(ownerId), tank.litres })
    end
end

function Fuel.restore(vehicleId, ownerId)
    if ownerId == nil then return end
    local litres = stored[ownerId]
    if litres == nil and Db.ready then
        local row = Db.single("SELECT litres FROM lightrp_vehicle_fuel WHERE owner_id = ?", { tostring(ownerId) })
        if row then litres = tonumber(row.litres) end
    end
    if litres ~= nil then Fuel.set(vehicleId, litres) else Fuel.seed(vehicleId, "full") end
end

-- ---------------------------------------------------------------------------
-- Consumption tick

local function tick(snapshot, dtSeconds)
    local id = snapshot.id
    local flagEngine, flagDestroyed = flagsOf()
    local flags = tonumber(snapshot.flags) or 0
    if flagDestroyed ~= 0 and (flags & flagDestroyed) ~= 0 then return end
    -- an activity's own cars (its routing bucket) run on its rules, not on RP fuel
    if LightRP.activities and LightRP.activities.ownsBucket(snapshot.bucket) then return end
    local tank = tankOf(id, snapshot)
    if tank == nil then return end
    if tank.litres <= 0 then
        -- Dry: keep the throttle locked whatever the owner's report says.
        local drivable = Open77.vehicles.isDrivable(id)
        if drivable ~= false then cut(id, tank, true) end
        return
    end
    local engineOn = (flags & flagEngine) ~= 0
    local speed = tonumber(snapshot.speed) or 0.0
    if speed >= 1.0 and not engineOn and not tank.flagNoted then
        -- Diagnostic, once per vehicle: the owner's report is moving the car
        -- with the engine bit clear. Distance burn does not depend on it.
        tank.flagNoted = true
        LightRP.log("fuel: vehicle %s moves at %.1f m/s with engine flag off (flags=%d)", tostring(id), speed, flags)
    end
    local used = burn(engineOn, speed, dtSeconds)
    if used <= 0 then return end
    local before = tank.litres
    -- Sub-tenth burns still accumulate: keep the exact value, publish the rounded one.
    tank.exact = math.max(0, (tank.exact or before) - used)
    local after = round1(tank.exact)
    if after ~= before then
        tank.litres = after
        write(id, tank)
    end
    local fraction = tank.capacity > 0 and tank.litres / tank.capacity or 0
    if tank.litres <= 0 then
        tank.exact = 0
        cut(id, tank, true)
    elseif not tank.warned and fraction <= (Config.reserve or 0.15) then
        tank.warned = true
        local driver = driverOf(id)
        if driver then
            LightRP.notice(driver, { kind = "warning", title = "LOW FUEL", body = string.format("%.0f L left in the tank. Find a gas station.", tank.litres), durationMs = 7000 })
        end
        LightRP.eachModule("onFuelLow", id, driver)
    elseif tank.warned and fraction > (Config.reserve or 0.15) + 0.05 then
        tank.warned = false
    end
end

CreateThread(function()
    local period = tonumber(Config.tickMs) or 1000
    while true do
        Wait(period)
        local ok, all = pcall(Open77.vehicles.all)
        if ok and type(all) == "table" then
            for _, snapshot in ipairs(all) do
                if type(snapshot) == "table" and snapshot.id ~= nil then
                    local ran, err = pcall(tick, snapshot, period / 1000.0)
                    if not ran then LightRP.log("fuel: tick failed for %s: %s", tostring(snapshot.id), tostring(err)) end
                end
            end
        end
    end
end)

AddEventHandler("onVehicleRemoved", function(id)
    tanks[tonumber(id) or id] = nil
end)

-- ---------------------------------------------------------------------------
-- Gas stations

-- Pump sessions and jerrycans live in refueling.lua, loaded after inventory.

-- Staff

local function pickVehicle(source, value)
    local id = tonumber(value)
    if id then return id end
    local seat = Open77.vehicles.getPlayerSeat(source)
    if type(seat) == "table" and seat.vehicleId then return seat.vehicleId end
    local ok, entry = pcall(Open77.vehicles.closest, source, { radius = 10.0 })
    if ok and type(entry) == "table" then return entry.id or entry.vehicleId end
    return nil
end

LightRP.command("lightrp.fuel", { restricted = true, usage = "/lightrp.fuel [vehicleId]" }, function(source, args)
    local id = pickVehicle(source, args[1])
    if id == nil then return false, "No vehicle: sit in one, stand next to one or give an id." end
    local info = Fuel.info(id)
    if info == nil then return false, "Unknown vehicle " .. tostring(id) end
    local snapshot = Open77.vehicles.get(id) or {}
    return true, string.format("vehicle %s: %.1f / %.0f L (%d%%)%s engine=%s speed=%.1f m/s flags=%s rate=%.0f L/100km x%.2f", tostring(id), info.litres, info.capacity,
        math.floor(info.fraction * 100 + 0.5), info.empty and " EMPTY" or (info.low and " LOW" or ""), tostring(Open77.vehicles.isEngineOn(id)),
        tonumber(snapshot.speed) or 0, tostring(snapshot.flags), Config.litresPerHundredKm or 12, Config.multiplier or 1)
end)

LightRP.command("lightrp.refuel", { restricted = true, usage = "/lightrp.refuel [vehicleId] [litres]" }, function(source, args)
    local id = pickVehicle(source, args[1])
    if id == nil then return false, "No vehicle: sit in one, stand next to one or give an id." end
    local litres = tonumber(args[2])
    local level
    if litres then level = Fuel.set(id, litres) else level = Fuel.seed(id, "full") end
    if level == nil then return false, "Unknown vehicle " .. tostring(id) end
    return true, string.format("vehicle %s: fuel set to %.1f L", tostring(id), level)
end)

LightRP.command("lightrp.fuelrate", { restricted = true, usage = "/lightrp.fuelrate <multiplier>" }, function(_, args)
    local value = tonumber(args[1])
    if value == nil or value <= 0 then return false end
    Config.multiplier = value
    return true, string.format("fuel consumption multiplier = %.2f (%.1f L/100km, %.2f L/min idle)", value, Config.litresPerHundredKm or 12, Config.idleLitresPerMinute or 0.08)
end)

LightRP.log("fuel: ready (%.0f L default tank, %.1f L/100km, %.2f L/min idle, %s/L)", tonumber((Config.tanks or {}).default) or 60,
    Config.litresPerHundredKm or 12, Config.idleLitresPerMinute or 0.08, tostring(Config.pricePerLitre or 3))
