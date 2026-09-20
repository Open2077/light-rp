local C, Config = LightRpVehicleContext, LightRpConfig.vehicleContext
local resource = GetCurrentResourceName()

local function selection(context)
    if GetInvokingResource() ~= "open77_contextmenu" or not Config.enabled then return end
    if not LightRpUi.characterReady or LightRpUi.actionFocus or LightRpUi.menuOpen then return end
    for _, open in pairs(LightRpUi.dialogs or {}) do if open then return end end
    if type(context) ~= "table" or type(context.target) ~= "table" or type(context.action) ~= "table" then return end
    local t, data = context.target, context.action.data
    if t.kind ~= "vehicle" or type(t.vehicleId) ~= "number" or type(data) ~= "table" then return end
    local action = C.byId[data.action]
    if not action then return end
    local bag = Open77.state.localPlayer()
    local keys = bag and bag:get("vehicleKeys")
    if type(keys) ~= "table" or keys[tostring(t.vehicleId)] == nil then return end
    local v = Open77.vehicles.get(t.vehicleId)
    if not v then return end
    local seat = Open77.vehicles.getPlayerSeat()
    local inside = seat ~= nil and seat.vehicleId == t.vehicleId
    if action.cabin and inside and seat.seat ~= "seat_front_left" and seat.seat ~= -1 then return end
    if action.cabin and not inside and (next(v.occupants or {}) ~= nil or (v.speed or 0) > Config.stationarySpeed) then return end
    if not C.available(action, v, inside) then return end
    return action, t.vehicleId
end

exports("vehicleContextAvailable", function(context) return selection(context) ~= nil end)
exports("vehicleContextSelect", function(context)
    local action, vehicleId = selection(context)
    if not action then return false end
    local ok, reason = TriggerServerEvent(LightRpEvents.net.action, {
        type = "vehicle.context", vehicle = vehicleId, action = action.id,
    })
    if not ok then LightRpUi.send(LightRpEvents.page.result, { ok = false, text = "Vehicle request failed: " .. tostring(reason), action = "vehicle.context" }) end
    return ok == true
end)

local function register()
    if not Config.enabled then return end
    local definitions = {}
    for order, action in ipairs(C.actions) do
        definitions[#definitions + 1] = {
            id = "vehicle." .. action.id, label = action.label, icon = action.icon,
            types = { "vehicle" }, networked = true,
            distance = action.remote and Config.remoteRange or Config.range,
            group = "Vehicle", order = order, submenu = action.submenu,
            canInteract = "vehicleContextAvailable", onSelect = "vehicleContextSelect", data = { action = action.id },
        }
    end
    -- Keep each cross-resource registration under the client's VM budget.
    for first = 1, #definitions, 5 do
        local batch = {}
        for i = first, math.min(first + 4, #definitions) do batch[#batch + 1] = definitions[i] end
        local pending, reason = Open77.exports.call("open77_contextmenu", "registerMany", batch)
        local tokens
        if pending then tokens, reason = pending:await() end
        if not tokens then
            local clear = Open77.exports.call("open77_contextmenu", "clear")
            if clear then clear:await() end
            LightRpUi.log("vehicle context registration failed: %s", tostring(reason))
            return
        end
    end
    LightRpUi.log("vehicle context ready: %d key-filtered actions", #definitions)
end
AddEventHandler("onClientResourceStart", function(name)
    if name == resource or name == "open77_contextmenu" then register() end
end)
