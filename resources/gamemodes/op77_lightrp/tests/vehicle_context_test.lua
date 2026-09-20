dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/vehicle_context.lua")
local C = LightRpVehicleContext
local noop = function() end
local now, fail, effectCount, dialogCount = 10000, false, 0, 0
local vehicles, seats, characters, positions, bags, messages, actions, modules, events = {}, {}, {}, {}, {}, {}, {}, {}, {}
local function resetVehicle()
    vehicles[10] = { id = 10, resource = "op77_lightrp", record = "Vehicle.v_standard2_archer_hella_player",
        position = { x = 0, y = 0, z = 0 }, bucket = 0, speed = 0, flags = 512 | 16,
        locked = false, doors = 0, windows = 0, health = 0.75, occupants = {} }
    return vehicles[10]
end
for _, id in ipairs({ 1, 2 }) do
    characters[id] = { identifier = "test-" .. id, status = "active", key = "default" }
    positions[id] = { x = 1, y = 0, z = 0, bucket = 0 }
end
local function mutate(fn)
    if fail then return false, "native_refused" end
    fn(); effectCount = effectCount + 1; return true
end
json = { encode = function() return "{}" end }
GetCurrentResourceName = function() return "op77_lightrp" end
GetPlayers = function() return { 1, 2 } end
GetPlayerName = function(id) return characters[id] and "Test " .. id end
AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
RegisterNetEvent, CreateThread = noop, noop
TriggerClientEvent = function(_, id, payload) messages[id] = payload end
Open77 = {
    players = { position = function(id) return positions[id] end, getLifeState = function(id) return { phase = characters[id].phase or "alive" } end },
    state = { player = function(id)
        bags[id] = bags[id] or {}; return { get = function(_, key) return bags[id][key] end, set = function(_, key, value) bags[id][key] = value end }
    end },
    vehicles = {
        get = function(id) return vehicles[id] end,
        getPlayerSeat = function(id) return seats[id or 1] end,
        clearLockedForPlayer = function() return true end,
        isLocked = function(id) return vehicles[id] and vehicles[id].locked end,
        setLockedForAll = function(id, value) return mutate(function()
            local v = vehicles[id]; v.locked = value; v.flags = value and (v.flags | 2) or (v.flags & ~2)
        end) end,
        setDoorOpen = function(id, door, value) return mutate(function()
            local v, bit = vehicles[id], 1 << door; v.doors = value and (v.doors | bit) or (v.doors & ~bit)
        end) end,
        setEngine = function(id, value) return mutate(function()
            local v = vehicles[id]; v.flags = value and (v.flags | 1) or (v.flags & ~1)
        end) end,
        setLights = function(id, value) return mutate(function()
            local v = vehicles[id]; v.flags = (v.flags & ~(64 | 128)) | (value == "high" and 192 or value == "on" and 64 or 0)
        end) end,
        triggerHorn = function(_, duration) return mutate(function() assert(duration == LightRpConfig.vehicleContext.hornDurationMs) end) end,
    },
}
Open77.vehicles.openDoor = function(id, name) assert(name == "trunk"); return Open77.vehicles.setDoorOpen(id, 4, true) end
LightRP = {
    module = function(name, value) LightRP[name] = value; modules[#modules + 1] = value; return value end,
    db = { schema = noop, ready = false }, log = noop, notice = noop, command = noop,
    nowMs = function() return now end,
    characters = { get = function(id) return characters[id] end, displayName = function(id) return "Test " .. id end },
    action = function(name, fn) actions[name] = fn end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    dialog = function(_, kind, payload) assert(kind == "inventory" and payload.right.id == "trunk:10"); dialogCount = dialogCount + 1 end,
    result = noop,
}
dofile("server/modules/keys.lua")
dofile("server/modules/inventory.lua")
dofile("server/modules/vehicle_context.lua")
local V, Inv = LightRP.vehicleContext, LightRP.inventory
resetVehicle()
for id, c in pairs(characters) do Inv.onCharacterLoaded(id, c) end
assert(LightRP.keys.give(10, 1))
local function request(action, player, extra)
    now = now + 3000
    return V.perform(player or 1, extra or { vehicle = 10, action = action })
end
local function refused(fragment, action, player, extra)
    local before = effectCount
    local ok, reason = request(action, player, extra)
    assert(not ok and reason:find(fragment, 1, true), tostring(reason))
    assert(effectCount == before, "refused action cannot mutate a vehicle")
end

assert(#C.actions == 14 and #C.actions <= 32)
for _, a in ipairs(C.actions) do
    local v = resetVehicle()
    if a.kind == "lock" then v.locked = not a.value; if v.locked then v.flags = v.flags | 2 end end
    if a.kind == "door" and not a.value then v.doors = 48 end
    if a.kind == "engine" and not a.value then v.flags = v.flags | 1 end
    if a.kind == "lights" and a.value == "off" then v.flags = v.flags | 64 end
    assert(C.available(a, v, false), a.id)
    local ok, reason = request(a.id)
    assert(ok, a.id .. ": " .. tostring(reason))
    assert((v.flags & (512 | 16)) == (512 | 16), "preserve paint / invulnerability bits")
    if a.kind == "door" then assert(((v.doors & (1 << a.door)) ~= 0) == a.value) end
    if a.kind == "engine" then assert(C.engineOn(v) == a.value) end
    if a.kind == "lights" then assert(C.lights(v) == a.value) end
end
assert(dialogCount == 1 and Inv.get("trunk:10"), "context creates the exact vehicle inventory on first access")
local v = resetVehicle()
assert(request("storage"))
assert(request("lock"))
assert(messages[1].inventories[2].id == "ground", "locking from Alt also revokes an open trunk")
refused("Unlock", "storage")
refused("Unlock", "open_6")
assert(request("unlock"))
v.doors = 32
assert(request("open_5") and v.doors == 48, "opening the trunk preserves the hood bit")
assert(Inv.count(Inv.playerId(1), "water") == 5, "door actions never consume or create items")

refused("no key", "horn", 2)
assert(LightRP.keys.give(10, 2) and request("horn", 2))
assert(LightRP.keys.take(10, 2))
refused("no key", "horn", 2)
positions[1].bucket = 7; refused("Too far", "horn"); positions[1].bucket = 0
positions[1].x = 20; refused("Too far", "horn"); positions[1].x = 6
refused("Too far", "open_6"); assert(request("horn")); positions[1].x = 1
characters[1].phase = "dead"; refused("Not right now", "horn"); characters[1].phase = nil
characters[1].status = "draft"; refused("Finish", "horn"); characters[1].status = "active"
v.resource = "another_resource"; refused("not available", "horn"); v.resource = "op77_lightrp"
v.speed = 10; refused("Park", "open_6"); refused("Park", "engine_on"); v.speed = 0
v.occupants = { { playerId = 2, seat = "seat_front_left", entering = true } }
refused("Someone", "engine_on"); v.occupants = {}
seats[1] = { vehicleId = 10, seat = "seat_front_right" }; refused("Only the driver", "lights_high")
seats[1].seat = "seat_front_left"; refused("Step out", "storage")
assert(request("lock") and request("lights_on"), "driver can operate cabin controls behind locked doors")
assert(request("unlock")); seats[1] = nil
v.health = 0; refused("no longer", "engine_on"); v.health = 0.75
v.flags = v.flags | 1024; refused("no longer", "engine_on"); v.flags = v.flags & ~1024
v.doors = 0; fail = true; refused("native_refused", "open_6"); fail = false
for _, removed in ipairs({ "open_1", "close_1", "open_2", "close_2", "open_3", "close_3", "open_4", "close_4", "open_doors", "close_doors", "windows_up", "windows_down" }) do
    assert(C.byId[removed] == nil)
    refused("Invalid", removed)
end
refused("Invalid", nil, nil, { vehicle = 10, action = "repair", flags = 0 })
refused("Invalid", nil, nil, { vehicle = 10.5, action = "horn" })
assert(request("horn"))
local before = effectCount
local ok = V.perform(1, { vehicle = 10, action = "info" }); assert(not ok and effectCount == before)
now = now + 500
ok = V.perform(1, { vehicle = 10, action = "horn" }); assert(not ok and effectCount == before, "horn has its own anti-spam")
V.onDisconnected(1)
assert(V.perform(1, { vehicle = 10, action = "horn" }))

-- Real client registration validated by the actual standalone registry.
dofile("../../system/open77_contextmenu/client/registry.lua")
local registry = ContextMenuRegistry.new(function() return true end)
local callbacks, batches, sent, invoking = {}, {}, {}, "open77_contextmenu"
exports = function(name, fn) callbacks[name] = fn end
GetInvokingResource = function() return invoking end
LightRpUi = { characterReady = true, dialogs = {}, log = noop, send = noop }
Open77.state.localPlayer = function() return Open77.state.player(1) end
Open77.exports = { call = function(owner, method, batch)
    assert(owner == "open77_contextmenu")
    return { await = function()
        if method == "clear" then registry.removeOwner("op77_lightrp"); return true end
        assert(method == "registerMany" and #batch <= 5)
        batches[#batches + 1] = #batch
        return registry.registerMany("op77_lightrp", 1, batch)
    end }
end }
TriggerServerEvent = function(event, payload) sent[#sent + 1] = { event = event, payload = payload }; return true end
resetVehicle()
dofile("client/core/vehicle_context.lua")
for _, fn in ipairs(events.onClientResourceStart) do fn("op77_lightrp") end
assert(#registry.list("op77_lightrp") == 14 and #batches == 3)
for _, fn in ipairs(events.onClientResourceStart) do fn("open77_contextmenu") end
assert(#registry.list("op77_lightrp") == 14, "restart replaces registrations, no duplicates")
local function ctx(action) return { target = { kind = "vehicle", vehicleId = 10 }, action = { data = { action = action } } } end
local available, select = callbacks.vehicleContextAvailable, callbacks.vehicleContextSelect
assert(available(ctx("lock")) and not available(ctx("unlock")))
local rootCount, folders = 0, {}
for _, action in ipairs(registry.list("op77_lightrp")) do
    local definition = registry.describe("op77_lightrp", action.token).definition
    if available(ctx(definition.data.action)) then
        if definition.submenu then folders[definition.submenu.id] = true else rootCount = rootCount + 1 end
    end
end
for _ in pairs(folders) do rootCount = rootCount + 1 end
assert(rootCount == 4 and folders.cargo and folders.controls, "root has only lock, two submenus and status")
assert(select(ctx("open_6")))
assert(#sent == 1 and sent[1].event == LightRpEvents.net.action and sent[1].payload.action == "open_6" and sent[1].payload.vehicle == 10)
local key = bags[1].vehicleKeys["10"]; bags[1].vehicleKeys["10"] = nil
assert(not available(ctx("horn")) and not select(ctx("horn")) and #sent == 1)
bags[1].vehicleKeys["10"] = key
invoking = "other"; assert(not select(ctx("horn"))); invoking = "open77_contextmenu"
LightRpUi.dialogs.inventory = true; assert(not available(ctx("horn"))); LightRpUi.dialogs.inventory = false
LightRpUi.characterReady = false; assert(not available(ctx("horn"))); LightRpUi.characterReady = true
vehicles[10].record = "Vehicle.v_sportbike1_yaiba_kusanagi_player"
assert(not available(ctx("open_5")) and not available(ctx("storage")))
assert(available(ctx("horn")) and available(ctx("engine_on")))
vehicles[10].record = "Vehicle.v_sport2_quadra_type66_player"
assert(not available(ctx("open_3")) and available(ctx("open_5")), "car only exposes trunk/hood openings")
assert(not available({}) and not available(nil))
print("PASS: 14 choices in a four-entry root; removed doors/windows rejected server-side; registry + dispatch; keys/storage; masks; life/bucket/range/driver guards; throttles; bikes; restart/failure")
