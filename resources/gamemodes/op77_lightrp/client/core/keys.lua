-- Vehicle keys on the client: the L key. The vehicle is the one the player sits
-- in, otherwise the closest one within keys.range. The player's own state bag
-- (`vehicleKeys`, written by the server) says which vehicles they hold a key
-- for; the press is sent to the server, which validates and flips the lock.
local E = LightRpEvents
local Config = LightRpConfig
local Keys = {}
LightRpKeys = Keys

local function log(format, ...) LightRpUi.log(format, ...) end

local function myKeys()
    if type(Open77.state) ~= "table" or type(Open77.state.localPlayer) ~= "function" then return {} end
    local ok, bag = pcall(Open77.state.localPlayer)
    if not ok or bag == nil then return {} end
    local ok2, value = pcall(function() return bag:get("vehicleKeys") end)
    return ok2 and type(value) == "table" and value or {}
end

local function targetVehicle()
    if type(Open77.vehicles) ~= "table" then return nil end
    if type(Open77.vehicles.getPlayerSeat) == "function" then
        local ok, seat = pcall(Open77.vehicles.getPlayerSeat)
        if ok and type(seat) == "table" and seat.vehicleId ~= nil then return seat.vehicleId end
    end
    if type(Open77.vehicles.closest) == "function" then
        local ok, entry = pcall(Open77.vehicles.closest, Config.keys.range or 8.0)
        if ok and type(entry) == "table" then return entry.id or entry.vehicleId end
    end
    return nil
end

function Keys.press()
    local vehicleId = targetVehicle()
    if vehicleId == nil then
        LightRpUi.send(E.page.result, { ok = false, text = "No vehicle nearby.", action = "keys.toggle" })
        return false
    end
    if myKeys()[tostring(vehicleId)] == nil then
        LightRpUi.send(E.page.result, { ok = false, text = "You have no key for this vehicle.", action = "keys.toggle" })
        return false
    end
    TriggerServerEvent(E.net.keysToggle, vehicleId)
    return true
end

function Keys.bind()
    local key = Config.keys.lock
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Keys.press() end)
    if ok then log("vehicle lock bound to %s", tostring(effective)) else log("vehicle lock key mapping failed: %s", tostring(effective)) end
end
