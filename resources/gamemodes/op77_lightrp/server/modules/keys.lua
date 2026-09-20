-- Vehicle keys authorise an explicit lock/unlock, never automatic entry.
-- A locked vehicle is locked for everyone, including its owner and key holders.
--
-- Keys are bound to a character (identifier + slot), not to a session id: a
-- holder who reconnects or switches slot gets the right keys back, not a bypass.
-- Replication: the vehicle's state bag carries `keys` ({ label, holders, owner })
-- and the player's bag carries `vehicleKeys` ({ [vehicleId] = label }), which is
-- what the client reads to know it may press L next to a car.
--
--   LightRP.keys.give(vehicleId, playerId, { label = "Archer Hella", owner = true })
--   LightRP.keys.take(vehicleId, playerId)      LightRP.keys.clear(vehicleId)
--   LightRP.keys.has(vehicleId, playerId)       LightRP.keys.holders(vehicleId)
--   LightRP.keys.lock(vehicleId, locked)        -- same lock for everyone
--   LightRP.keys.toggle(playerId, vehicleId)    -- what the L key does, validated
--   hook onVehicleLockChanged(vehicleId, locked, byPlayerId)
local Config = LightRpConfig.vehicleKeys
local Keys = LightRP.module("keys", {})

local ledger = {}      -- vehicleId -> { label, owner = identity|nil, holders = { [identity] = { at, label } } }
Keys.ledger = ledger

local function identityOf(playerId)
    local c = LightRP.characters.get(playerId)
    if c == nil or c.identifier == nil or c.status ~= "active" then return nil end
    return c.identifier .. "#" .. (c.key or "default")
end

local function vehicleBag(vehicleId)
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return nil end
    local ok, bag = pcall(Open77.state.entity, "vehicle", vehicleId)
    return ok and bag or nil
end

local function playerBag(playerId)
    if type(Open77.state) ~= "table" or type(Open77.state.player) ~= "function" then return nil end
    local ok, bag = pcall(Open77.state.player, playerId)
    return ok and bag or nil
end

local function publishVehicle(vehicleId)
    local bag = vehicleBag(vehicleId)
    if bag == nil then return end
    local entry = ledger[vehicleId]
    if entry == nil then pcall(bag.set, bag, "keys", nil) return end
    local holders = {}
    for identity in pairs(entry.holders) do holders[#holders + 1] = identity end
    table.sort(holders)
    pcall(bag.set, bag, "keys", { label = entry.label, owner = entry.owner, holders = holders })
end

local function publishPlayer(playerId)
    local bag = playerBag(playerId)
    if bag == nil then return end
    local identity = identityOf(playerId)
    local mine = {}
    if identity then
        for vehicleId, entry in pairs(ledger) do
            if entry.holders[identity] then mine[tostring(vehicleId)] = entry.label or "Vehicle" end
        end
    end
    pcall(bag.set, bag, "vehicleKeys", mine)
end

-- Scrub any old automatic-entry exception without changing the vehicle's lock.
local function clearException(vehicleId, playerId)
    if type(Open77.vehicles.clearLockedForPlayer) == "function" then
        return Open77.vehicles.clearLockedForPlayer(vehicleId, playerId)
    end
    return Open77.vehicles.setLockedForPlayer(vehicleId, playerId, nil)
end

local function clearAllExceptions(vehicleId)
    for _, id in ipairs(GetPlayers()) do pcall(clearException, vehicleId, id) end
end

function Keys.has(vehicleId, playerId)
    local entry, identity = ledger[vehicleId], identityOf(playerId)
    return entry ~= nil and identity ~= nil and entry.holders[identity] ~= nil
end

function Keys.holders(vehicleId)
    local entry = ledger[vehicleId]
    if entry == nil then return {} end
    local list = {}
    for identity, meta in pairs(entry.holders) do list[#list + 1] = { identity = identity, at = meta.at } end
    return list
end

function Keys.give(vehicleId, playerId, options)
    options = options or {}
    if Open77.vehicles.get(vehicleId) == nil then return false, "unknown_vehicle" end
    local identity = identityOf(playerId)
    if identity == nil then return false, "no_character" end
    local entry = ledger[vehicleId] or { holders = {} }
    ledger[vehicleId] = entry
    entry.label = options.label or entry.label or "Vehicle"
    if options.owner then entry.owner = identity end
    entry.holders[identity] = { at = LightRP.nowMs(), playerId = playerId }
    clearException(vehicleId, playerId)
    publishVehicle(vehicleId)
    publishPlayer(playerId)
    LightRP.log("keys: %s now holds the keys of vehicle %s (%s)", LightRP.characters.displayName(playerId), tostring(vehicleId), entry.label)
    return true
end

function Keys.take(vehicleId, playerId)
    local entry, identity = ledger[vehicleId], identityOf(playerId)
    if entry == nil or identity == nil or entry.holders[identity] == nil then return false, "no_key" end
    entry.holders[identity] = nil
    if entry.owner == identity then entry.owner = nil end
    clearException(vehicleId, playerId)
    if next(entry.holders) == nil then ledger[vehicleId] = nil end
    publishVehicle(vehicleId)
    publishPlayer(playerId)
    return true
end

function Keys.clear(vehicleId)
    if ledger[vehicleId] == nil then return false, "no_keys" end
    ledger[vehicleId] = nil
    if Open77.vehicles.get(vehicleId) then clearAllExceptions(vehicleId) end
    publishVehicle(vehicleId)
    for _, id in ipairs(GetPlayers()) do publishPlayer(id) end
    return true
end

-- Both directions clear overrides: clients must all receive the same state.
function Keys.lock(vehicleId, locked, byPlayerId)
    if Open77.vehicles.get(vehicleId) == nil then return false, "unknown_vehicle" end
    if type(locked) ~= "boolean" then return false, "invalid_lock" end
    local ok, reason = Open77.vehicles.setLockedForAll(vehicleId, locked)
    if not ok then return false, reason or "lock_refused" end
    LightRP.eachModule("onVehicleLockChanged", vehicleId, locked == true, byPlayerId)
    return true
end

-- "bip" on lock, "bip bip" on unlock, through the synchronised horn so every
-- client in range hears the same pattern at the same moment.
function Keys.beep(vehicleId, locked)
    local horn = Config.horn
    if type(horn) ~= "table" or type(Open77.vehicles.triggerHorn) ~= "function" then return end
    local count = locked and (horn.lock or 1) or (horn.unlock or 2)
    if count <= 0 then return end
    CreateThread(function()
        for i = 1, count do
            if Open77.vehicles.get(vehicleId) == nil then return end
            pcall(Open77.vehicles.triggerHorn, vehicleId, horn.bipMs or 110)
            if i < count then Wait((horn.bipMs or 110) + (horn.gapMs or 170)) end
        end
    end)
end

local function distanceTo(p, v, vehicleId)
    local vp = v and (v.position or (type(Open77.vehicles.getPosition) == "function" and Open77.vehicles.getPosition(vehicleId)))
    if p == nil or vp == nil then return nil end
    local dx, dy, dz = p.x - vp.x, p.y - vp.y, p.z - vp.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The L key: validated here, never trusted from the client.
function Keys.toggle(playerId, vehicleId)
    vehicleId = tonumber(vehicleId) or vehicleId
    local vehicle = vehicleId and Open77.vehicles.get(vehicleId)
    if vehicle == nil then return false, "unknown_vehicle" end
    if not Keys.has(vehicleId, playerId) then return false, "no_key" end
    local position = Open77.players.position(playerId)
    if position == nil or position.bucket ~= vehicle.bucket then return false, "too_far" end
    local seat = Open77.vehicles.getPlayerSeat(playerId)
    local inside = seat ~= nil and tostring(seat.vehicleId) == tostring(vehicleId)
    if not inside then
        local distance = distanceTo(position, vehicle, vehicleId)
        if distance == nil or distance > (Config.range or 8.0) then return false, "too_far" end
    end
    local locked = Open77.vehicles.isLocked(vehicleId) == true
    local ok, reason = Keys.lock(vehicleId, not locked, playerId)
    if not ok then return false, reason end
    Keys.beep(vehicleId, not locked)
    return true, not locked
end

-- ---------------------------------------------------------------------------
-- Hooks, network, commands

function Keys.onCharacterLoaded(playerId)
    for vehicleId in pairs(ledger) do pcall(clearException, vehicleId, playerId) end
    publishPlayer(playerId)
end

function Keys.onCharacterSwitched(playerId) Keys.onCharacterLoaded(playerId) end

AddEventHandler("onVehicleRemoved", function(id)
    local vehicleId = tonumber(id) or id
    if ledger[vehicleId] == nil then return end
    ledger[vehicleId] = nil
    for _, playerId in ipairs(GetPlayers()) do publishPlayer(playerId) end
end)

local REASONS = {
    unknown_vehicle = "No vehicle there.", no_key = "You have no key for this vehicle.", too_far = "Too far from the vehicle.",
    no_character = "Finish your character first.", lock_refused = "The lock did not answer.",
}
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end
Keys.explain = explain

local lastToggle = {}
RegisterNetEvent(LightRpEvents.net.keysToggle, function(vehicleId)
    local playerId = source
    local now = LightRP.nowMs()
    if lastToggle[playerId] and now - lastToggle[playerId] < 350 then return end
    lastToggle[playerId] = now
    local ok, result = Keys.toggle(playerId, vehicleId)
    if not ok then return LightRP.result(playerId, false, explain(result), "keys.toggle") end
    local entry = ledger[tonumber(vehicleId) or vehicleId]
    LightRP.notice(playerId, { kind = "info", title = entry and entry.label or "Vehicle", body = result and "Locked." or "Unlocked.", durationMs = 2500 })
end)

LightRP.action("keys.toggle", function(playerId, payload)
    local ok, result = Keys.toggle(playerId, payload.vehicle)
    LightRP.result(playerId, ok, ok and (result and "Vehicle locked." or "Vehicle unlocked.") or explain(result), "keys.toggle")
end)

function Keys.onDisconnected(playerId) lastToggle[playerId] = nil end

-- Staff: hand or take keys by vehicle id.
LightRP.command("lightrp.givekeys", { restricted = true, usage = "/lightrp.givekeys <id|me> <vehicleId> [label]" }, function(source, args)
    local target = (args[1] == nil or args[1] == "me") and source or tonumber(args[1])
    local vehicleId = tonumber(args[2])
    if target == nil or GetPlayerName(target) == nil or vehicleId == nil then return false end
    local label = LightRP.joinArgs(args, 3)
    local ok, reason = Keys.give(vehicleId, target, { label = label ~= "" and label or nil })
    return ok, ok and string.format("Keys of vehicle %d given to %s.", vehicleId, LightRP.characters.displayName(target)) or explain(reason)
end)

LightRP.command("lightrp.takekeys", { restricted = true, usage = "/lightrp.takekeys <id|me> <vehicleId>" }, function(source, args)
    local target = (args[1] == nil or args[1] == "me") and source or tonumber(args[1])
    local vehicleId = tonumber(args[2])
    if target == nil or GetPlayerName(target) == nil or vehicleId == nil then return false end
    local ok, reason = Keys.take(vehicleId, target)
    return ok, ok and "Keys taken." or explain(reason)
end)
