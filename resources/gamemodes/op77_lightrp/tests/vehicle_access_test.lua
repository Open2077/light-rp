-- Isolated integration tests: real keys/inventory modules, no server or game.
-- The vehicle fake mirrors SetLockedForAll / LockedFor in the platform:
-- canonical lock plus per-player overrides; All clears every override.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("shared/items.lua")
local noop = function() end
local characters = {
    [1] = { identifier = "owner", key = "default", status = "active" },
    [2] = { identifier = "visitor", key = "default", status = "active" },
}
local positions = {
    [1] = { x = 0, y = 0, z = 0, bucket = 0 },
    [2] = { x = 0, y = 0, z = 0, bucket = 0 },
}
local vehicles = {
    [10] = { id = 10, bucket = 0, position = { x = 1, y = 0, z = 0 }, locked = false, overrides = {} },
    [11] = { id = 11, bucket = 7, position = { x = 0, y = 0, z = 0 }, locked = false, overrides = {} },
}
local seats, playerBags, dialogs, packets, notices, handlers = {}, {}, {}, {}, {}, {}
local modules, hooks, failLock = {}, 0, false
json = { encode = function() return "{}" end }
Open77 = {
    players = { position = function(id) return positions[id] end },
    state = { player = function(id)
        playerBags[id] = playerBags[id] or {}
        return { set = function(_, key, value) playerBags[id][key] = value end }
    end },
    vehicles = {
        get = function(id) return vehicles[id] end,
        getPlayerSeat = function(id) return seats[id] end,
        isLocked = function(id) return vehicles[id] and vehicles[id].locked end,
        setLockedForAll = function(id, locked)
            if failLock then return false, "lock_refused" end
            vehicles[id].locked, vehicles[id].overrides = locked, {}
            return true
        end,
        setLocked = function(id, locked) vehicles[id].locked = locked; return true end,
        setLockedForPlayer = function(id, player, locked) vehicles[id].overrides[player] = locked; return true end,
        clearLockedForPlayer = function(id, player) vehicles[id].overrides[player] = nil; return true end,
        closest = function(anchor, options)
            assert(type(anchor) == "number", "use a player anchor to scope proximity to their bucket")
            local p, best, distance = positions[anchor], nil, options.radius
            for _, v in pairs(vehicles) do
                local d = math.sqrt((p.x - v.position.x)^2 + (p.y - v.position.y)^2 + (p.z - v.position.z)^2)
                if p.bucket == v.bucket and d <= distance then best, distance = v, d end
            end
            return best
        end,
    },
}
LightRP = {
    db = { schema = noop, ready = false }, command = noop, action = noop, log = noop,
    nowMs = function() return 1000 end,
    characters = { get = function(id) return characters[id] end, displayName = function(id) return "Character " .. id end },
    module = function(name, value) LightRP[name] = value; modules[#modules + 1] = value; return value end,
    eachModule = function(hook, ...)
        if hook == "onVehicleLockChanged" then hooks = hooks + 1 end
        for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end
    end,
    dialog = function(id, kind, payload) assert(kind == "inventory"); dialogs[id] = payload end,
    notice = function(id, payload) notices[id] = payload end,
}
AddEventHandler = function(event, fn)
    handlers[event] = handlers[event] or {}; table.insert(handlers[event], fn)
end
RegisterNetEvent, CreateThread = noop, noop
GetPlayers = function() return { 1, 2 } end
GetPlayerName = function(id) return characters[id] and "Player " .. id end
TriggerClientEvent = function(event, player, payload)
    assert(event == LightRpEvents.net.inventory)
    packets[player] = packets[player] or {}; table.insert(packets[player], payload)
end
dofile("server/modules/keys.lua")
dofile("server/modules/inventory.lua")
local Keys, Inv = LightRP.keys, LightRP.inventory
local function lockedFor(id, player)
    local v = vehicles[id]
    if v.overrides[player] ~= nil then return v.overrides[player] end
    return v.locked
end
local function denied(reason, fn, ...)
    local ok, actual = fn(...)
    assert(ok == false and actual == reason, "expected " .. reason .. ", got " .. tostring(ok) .. "/" .. tostring(actual))
end
local function latestRight(player)
    local list = packets[player] or {}
    local last = list[#list]
    return last and last.inventories[#last.inventories]
end
local function totalWater()
    return Inv.count(Inv.playerId(1), "water") + Inv.count(Inv.playerId(2), "water") + Inv.count("trunk:10", "water")
end
for id, c in pairs(characters) do Inv.onCharacterLoaded(id, c) end
assert(Keys.give(10, 1, { owner = true, label = "Test car" }))
assert(Keys.lock(10, true, 1))
assert(lockedFor(10, 1) and lockedFor(10, 2), "lock includes the owner")
assert(Keys.has(10, 1) and playerBags[1].vehicleKeys["10"] == "Test car")
Keys.onCharacterLoaded(1)
assert(lockedFor(10, 1), "reconnecting must not reopen a locked car")
characters[1].key = "second"
Keys.onCharacterSwitched(1)
assert(not Keys.has(10, 1) and next(playerBags[1].vehicleKeys) == nil)
characters[1].key = "default"
Keys.onCharacterSwitched(1)
assert(Keys.has(10, 1) and lockedFor(10, 1), "returning to the owner character only restores keys")
assert(Keys.give(10, 2))
assert(lockedFor(10, 2), "sharing keys is not an unlock")
assert(Keys.take(10, 2))
denied("no_key", Keys.toggle, 2, 10)

assert(Inv.open(1) and dialogs[1].right.kind == "ground")
assert(notices[1].title == "Trunk locked")
assert(Inv.open(2) and dialogs[2].right.kind == "ground")
denied("locked", Inv.open, 1, "trunk:10")
denied("locked", Inv.move, 1, Inv.playerId(1), 1, "trunk:10", 1, 1)
assert(totalWater() == 10, "locked deposit preserves all items")

-- Unlock must clear *both* true and false stale per-player overrides.
vehicles[10].overrides[2] = true
local ok, locked = Keys.toggle(1, "10")
assert(ok and locked == false and not lockedFor(10, 1) and not lockedFor(10, 2))
assert(next(vehicles[10].overrides) == nil)
for _, id in ipairs({ 1, 2 }) do
    assert(Inv.open(id) and dialogs[id].right.id == "trunk:10", "unlocked trunk is shared, not key-only")
end
assert(Inv.move(1, Inv.playerId(1), 1, "trunk:10", 1, 2))
assert(Inv.move(2, "trunk:10", 1, Inv.playerId(2), 1, 1))
assert(totalWater() == 10 and Inv.count("trunk:10", "water") == 1)

vehicles[10].overrides[1] = false
ok, locked = Keys.toggle(1, 10)
assert(ok and locked and lockedFor(10, 1) and lockedFor(10, 2))
assert(next(vehicles[10].overrides) == nil, "locking must never reapply holders' exceptions")
assert(next(Inv.get("trunk:10").viewers) == nil, "all viewers are unsubscribed immediately")
for _, id in ipairs({ 1, 2 }) do
    assert(latestRight(id).kind == "ground", "open trunk panel is replaced without closing pockets")
    denied("locked", Inv.move, id, "trunk:10", 1, Inv.playerId(id), 1, 1)
    denied("locked", Inv.move, id, Inv.playerId(id), 1, "trunk:10", 1, 1)
end
assert(totalWater() == 10, "in-flight deposits and withdrawals cannot change items after locking")
local packetCount = #packets[1]
assert(Inv.addItem("trunk:10", "burrito", 1))
assert(#packets[1] == packetCount, "former viewers never receive or reopen a locked trunk")

assert(Keys.lock(10, false))
assert(Inv.open(1, "trunk:10") and dialogs[1].right.id == "trunk:10")
-- If the native lock API refuses, do not announce success or revoke the trunk.
local beforeHooks = hooks
failLock = true
denied("lock_refused", Keys.toggle, 1, 10)
assert(hooks == beforeHooks and not lockedFor(10, 1) and Inv.get("trunk:10").viewers[1])
failLock = false

-- Proximity is bucket-aware, even when the player is marked as an occupant.
positions[1].bucket = 7
seats[1] = { vehicleId = 10 }
denied("too_far", Keys.toggle, 1, 10)
denied("too_far", Inv.open, 1, "trunk:10")
denied("too_far", Inv.move, 1, "trunk:10", 1, Inv.playerId(1), 1, 1)
seats[1] = nil
assert(Inv.open(1) and dialogs[1].right.id == "trunk:11", "nearby cars in another bucket cannot mask the right trunk")
positions[1].bucket, positions[1].x = 0, 100
denied("too_far", Keys.toggle, 1, 10)
denied("too_far", Inv.open, 1, "trunk:10")
denied("too_far", Inv.move, 1, Inv.playerId(1), 1, "trunk:10", 1, 1)
positions[1].x = 0

-- External lock changes are also revalidated on every mutation / publication.
assert(Inv.open(1, "trunk:10"))
vehicles[10].locked = true
denied("locked", Inv.move, 1, "trunk:10", 1, Inv.playerId(1), 1, 1)
assert(Inv.addItem("trunk:10", "burrito", 1))
assert(latestRight(1).kind == "ground" and not Inv.get("trunk:10").viewers[1])
assert(Keys.lock(10, false) and Inv.open(1, "trunk:10"))
positions[1].bucket = 7
Inv.push(1)
assert(latestRight(1).kind == "ground" and not Inv.get("trunk:10").viewers[1])
positions[1].bucket = 0

-- Cleanup cannot unlock a car or preserve a trunk after its vehicle disappears.
assert(Keys.lock(10, true))
assert(Keys.clear(10) and not Keys.has(10, 1) and lockedFor(10, 1))
assert(Keys.lock(10, false) and Inv.open(1, "trunk:10"))
vehicles[10] = nil
for _, fn in ipairs(handlers.onVehicleRemoved) do fn(10) end
assert(Inv.get("trunk:10") == nil and latestRight(1).kind == "ground")
denied("unknown_vehicle", Keys.toggle, 1, 10)
print("PASS: real owner locks; shared keys/reconnects; stale overrides; two-viewer trunk revocation; late transfers; item conservation; bucket/range guards; failure and removal")
