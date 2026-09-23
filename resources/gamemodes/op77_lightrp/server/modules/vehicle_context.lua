-- No effects are executed on the client. Every request uses the real source,
-- canonical state, key ledger, player life/character, bucket and proximity.
local C, Config = LightRpVehicleContext, LightRpConfig.vehicleContext
local Context = LightRP.module("vehicleContext", {})
local lastAction, lastHorn = {}, {}
local resource = GetCurrentResourceName()
local function distance(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2 + (a.z - b.z)^2)
end

function Context.perform(playerId, payload)
    if not Config.enabled then return false, "Vehicle interactions are disabled." end
    if type(payload) ~= "table" then return false, "Invalid vehicle request." end
    local id = type(payload.vehicle) == "number" and math.tointeger(payload.vehicle)
    local action = type(payload.action) == "string" and C.byId[payload.action]
    if not id or id < 1 or not action then return false, "Invalid vehicle request." end
    local now = LightRP.nowMs()
    if lastAction[playerId] and now - lastAction[playerId] < Config.cooldownMs then return false, "Please wait before the next vehicle action." end
    lastAction[playerId] = now
    local character = LightRP.characters.get(playerId)
    if not character or character.status ~= "active" then return false, "Finish your character first." end
    local life = Open77.players.getLifeState(playerId)
    if not life or life.phase ~= "alive" then return false, "Not right now." end
    local v = Open77.vehicles.get(id)
    if not v or v.resource ~= resource then return false, "This vehicle is not available." end
    if not LightRP.keys.has(id, playerId) then return false, "You have no key for this vehicle." end
    local position = Open77.players.position(playerId)
    if not position or position.bucket ~= v.bucket then return false, "Too far from the vehicle." end
    local seat = Open77.vehicles.getPlayerSeat(playerId)
    local inside = seat ~= nil and seat.vehicleId == id
    if not inside and distance(position, v.position) > (action.remote and Config.remoteRange or Config.range) then
        return false, "Too far from the vehicle."
    end
    if action.outside and inside then return false, "Step out to access the trunk." end
    if action.parked and v.speed > Config.stationarySpeed then return false, "Park the vehicle first." end
    if action.cabin then
        if inside and seat.seat ~= "seat_front_left" and seat.seat ~= -1 then return false, "Only the driver can use these controls." end
        -- Includes seat reservations / entering animations, not just the driver.
        for _, occupant in ipairs(v.occupants or {}) do
            if occupant.playerId ~= playerId and (occupant.seat == "seat_front_left" or not inside) then
                return false, "Someone is using this vehicle. Use the controls from the driver seat."
            end
        end
        if not inside and v.speed > Config.stationarySpeed then return false, "Park the vehicle first." end
    end
    if action.unlocked and C.locked(v) and not (action.cabin and inside) then return false, "Unlock the vehicle first." end
    if not C.available(action, v, inside) then return false, "This option is no longer available. Open the vehicle menu again." end

    local ok, reason
    local kind = action.kind
    if kind == "lock" then
        ok, reason = LightRP.keys.lock(id, action.value, playerId)
        if ok then LightRP.keys.beep(id, action.value) end
    elseif kind == "storage" then
        ok, reason = LightRP.inventory.openTrunk(playerId, id)
        if not ok then return false, LightRP.inventory.explain(reason) end
    elseif kind == "door" then
        ok, reason = Open77.vehicles.setDoorOpen(id, action.door, action.value)
    elseif kind == "engine" then
        if action.value and LightRP.fuel and LightRP.fuel.isEmpty(id) then return false, "The tank is empty. Refuel first." end
        ok, reason = Open77.vehicles.setEngine(id, action.value)
    elseif kind == "lights" then
        ok, reason = Open77.vehicles.setLights(id, action.value)
    elseif kind == "horn" then
        if lastHorn[playerId] and now - lastHorn[playerId] < Config.hornCooldownMs then return false, "Wait a moment before sounding the horn again." end
        lastHorn[playerId] = now
        ok, reason = Open77.vehicles.triggerHorn(id, math.max(100, math.min(2000, Config.hornDurationMs)))
    elseif kind == "info" then
        return true, string.format("%s · %s · Engine %s · Lights %s · Condition %d%%", C.label(v),
            C.locked(v) and "Locked" or "Unlocked", C.engineOn(v) and "on" or "off", C.lights(v), math.floor((v.health or 0) * 100 + 0.5))
    end
    if not ok then return false, "Vehicle action refused: " .. tostring(reason or "unavailable") end
    return true, action.label .. " — done."
end

LightRP.action("vehicle.context", function(playerId, payload)
    local ok, message = Context.perform(playerId, payload)
    LightRP.result(playerId, ok, message, "vehicle.context")
end)
function Context.onDisconnected(playerId) lastAction[playerId], lastHorn[playerId] = nil, nil end
