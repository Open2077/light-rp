-- Pure policy shared by the menu and the authoritative server. The client only
-- uses it to hide irrelevant choices; it never authorises a vehicle mutation.
local C = { actions = {}, byId = {} }
LightRpVehicleContext = C
local Config = LightRpConfig.vehicleContext
local catalog = {}
for _, entry in ipairs(LightRpConfig.vehicles.catalog) do catalog[entry.record] = entry end

function C.profile(vehicle)
    local configured = Config.models[vehicle.record]
    if configured then return configured end
    local record = tostring(vehicle.record or ""):lower()
    local entry = catalog[vehicle.record]
    if (entry and entry.category == "Bikes") or record:find("bike", 1, true) or record:find("motorcycle", 1, true) then
        return { doors = 0 }
    end
    return { doors = 48 } -- trunk and hood only; cabin doors/windows are not exposed
end

function C.label(vehicle)
    return catalog[vehicle.record] and catalog[vehicle.record].label or "Vehicle"
end

function C.locked(v) return v.locked == true or ((v.flags or 0) & 2) ~= 0 end
function C.engineOn(v) return ((v.flags or 0) & 1) ~= 0 end
function C.lights(v)
    if ((v.flags or 0) & 128) ~= 0 then return "high" end
    return ((v.flags or 0) & 64) ~= 0 and "on" or "off"
end

local function add(id, label, kind, value, extra)
    local action = extra or {}
    action.id, action.label, action.kind, action.value = id, label, kind, value
    action.icon = action.icon or "vehicle"
    C.actions[#C.actions + 1], C.byId[id] = action, action
end
add("unlock", "Unlock vehicle", "lock", false, { icon = "lock", remote = true })
add("lock", "Lock vehicle", "lock", true, { icon = "lock", remote = true })
add("storage", "Access trunk inventory", "storage", nil, { icon = "interact", parked = true, outside = true, unlocked = true })
for _, opening in ipairs({ { 5, "trunk" }, { 6, "hood" } }) do
    local index, label = opening[1], opening[2]
    add("open_" .. index, "Open " .. label, "door", true, { door = index - 1, parked = true, unlocked = true, icon = "interact" })
    add("close_" .. index, "Close " .. label, "door", false, { door = index - 1, parked = true, icon = "interact" })
end
add("engine_on", "Start engine", "engine", true, { parked = true, cabin = true, unlocked = true, icon = "tool" })
add("engine_off", "Stop engine", "engine", false, { parked = true, cabin = true, unlocked = true, icon = "tool" })
add("lights_off", "Turn lights off", "lights", "off", { cabin = true, unlocked = true })
add("lights_on", "Turn headlights on", "lights", "on", { cabin = true, unlocked = true })
add("lights_high", "Turn high beams on", "lights", "high", { cabin = true, unlocked = true })
add("horn", "Sound horn", "horn", nil, { icon = "interact", remote = true })
add("info", "Check vehicle status", "info", nil, { icon = "info", remote = true })

local cargoMenu = { id = "cargo", label = "Trunk & hood", icon = "interact" }
local controlsMenu = { id = "controls", label = "Vehicle controls", icon = "tool" }
for _, action in ipairs(C.actions) do
    if action.kind == "storage" or action.kind == "door" then action.submenu = cargoMenu
    elseif action.kind ~= "lock" and action.kind ~= "info" then action.submenu = controlsMenu end
end

function C.available(action, v, inside)
    if not action or not v then return false end
    if action.outside and inside then return false end
    if action.unlocked and C.locked(v) and not (action.cabin and inside) then return false end
    if action.parked and (v.speed or 0) > Config.stationarySpeed then return false end
    local profile, kind = C.profile(v), action.kind
    local doors = v.doors or 0
    if kind == "lock" then return C.locked(v) ~= action.value end
    if kind == "storage" then return (profile.doors & 16) ~= 0 end
    if kind == "door" then
        local bit = 1 << action.door
        return (profile.doors & bit) ~= 0 and ((doors & bit) ~= 0) ~= action.value
    end
    if kind == "engine" then
        return ((v.flags or 0) & (4 | 8 | 1024)) == 0 and not v.destroyed and not v.exploded
            and (v.health or 0) > 0 and C.engineOn(v) ~= action.value
    end
    if kind == "lights" then return C.lights(v) ~= action.value end
    return true
end
