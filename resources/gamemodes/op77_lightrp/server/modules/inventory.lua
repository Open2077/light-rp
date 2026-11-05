-- Inventories, the ox_inventory way: slot grids with a weight cap, stacks of
-- identical items, and every move validated here. Kinds:
--   player:<identifier>#<slot>  persistent, one per character, loaded with it
--   trunk:<vehicleId>           session-only, opened next to a vehicle you can open
--   drop:<n>                    session-only, a pile on the ground with a pick-up point
--   stash:<id>                  persistent, a config point in the world
-- The page shows two inventories (left = the player's, right = the secondary)
-- and asks; the server answers with fresh snapshots to everyone watching.
--
--   LightRP.inventory.addItem(invId, name, count, metadata) / removeItem(invId, name, count)
--   LightRP.inventory.count(invId, name)   LightRP.inventory.playerId(playerId) -> invId
--   LightRP.inventory.onUse(name, fn(playerId, item, template) -> false (refused) | "keep", text? (not consumed) | other (consumed))
--   hook onItemUsed(playerId, name, item)
local Config = LightRpConfig.inventory
local Items = LightRpItems
local Db = LightRP.db
local Inv = LightRP.module("inventory", {})

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_inventories (
        id          VARCHAR(96)  NOT NULL PRIMARY KEY,
        kind        VARCHAR(16)  NOT NULL,
        label       VARCHAR(64)  NOT NULL DEFAULT '',
        slots       INT          NOT NULL,
        max_weight  DOUBLE       NOT NULL,
        items       MEDIUMTEXT   NOT NULL,
        updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
]])

local registry = {}     -- id -> inventory
local personalTrunks = {} -- runtime vehicleId -> durable personal:<ownership UUID>
local playerInv = {}    -- playerId -> inventory id
local secondary = {}    -- playerId -> inventory id currently open on the right (or "ground")
local useHandlers = {}  -- item name -> fn
local dropSequence = 0
local canAccess
Inv.registry = registry

-- Server Lua exposes the FiveM-style global `json` (Open77.json is the client namespace).
local json = (type(Open77) == "table" and type(Open77.json) == "table") and Open77.json or json

-- ---------------------------------------------------------------------------
-- Helpers

local function template(name) return Items[name] end

local function metaEqual(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    return json.encode(a) == json.encode(b)
end

local function itemWeight(item)
    local t = template(item.name)
    return (t and t.weight or 0) * (item.count or 0)
end

function Inv.weightOf(inv)
    local total = 0
    for _, item in pairs(inv.items) do total = total + itemWeight(item) end
    return total
end

local function stackMax(name)
    local t = template(name)
    return math.max(1, math.floor(tonumber(t and t.stack) or 1))
end

local function firstFreeSlot(inv)
    for slot = 1, inv.slots do if inv.items[slot] == nil then return slot end end
    return nil
end

-- Item art comes from the template. The only per-item exception is a garment's
-- own icon, from the fitting room's shared icon library (clothing / outfit items).
local function metadataImage(item)
    local image = type(item.metadata) == "table" and item.metadata.image
    if type(image) == "string" and #image <= 80 and image:match("^open77://open77_wardrobe_ui/web/icons/[mf]/%x+%.webp$") then return image end
end

local function snapshotItem(slot, item)
    local t = template(item.name) or {}
    local action = LightRpConsumableProfiles and LightRpConsumableProfiles[t.consumeAction]
    return {
        slot = slot, name = item.name, count = item.count, metadata = item.metadata,
        label = item.name=="jerrycan" and string.format("Jerrycan · %.1f L",tonumber((item.metadata or {}).fuelLitres) or 20) or item.metadata and item.metadata.label or t.label or item.name, description = t.description,
        weight = t.weight or 0, icon = t.icon or "package", category = t.category, usable = item.name=="jerrycan" or t.use ~= nil or useHandlers[item.name] ~= nil,
        stack = stackMax(item.name),
        image = metadataImage(item) or t.image,
        effects = t.use and { food = t.use.food, drink = t.use.drink, health = t.use.health } or nil,
        useAction = action and { label = action.label, durationMs = action.durationMs, icon = action.icon } or nil,
    }
end

function Inv.snapshot(inv)
    local items = {}
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item then items[#items + 1] = snapshotItem(slot, item) end
    end
    return { id = inv.id, kind = inv.kind, label = inv.label, slots = inv.slots, maxWeight = inv.maxWeight, weight = Inv.weightOf(inv), items = items }
end

local function persist(inv)
    if not inv.persistent then return true end
    if not Db.ready then return false end
    return Db.run([[INSERT INTO lightrp_inventories (id, kind, label, slots, max_weight, items) VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE items = VALUES(items), slots = VALUES(slots), max_weight = VALUES(max_weight), label = VALUES(label)]],
        { inv.id, inv.kind, inv.label or "", inv.slots, inv.maxWeight, json.encode(inv.items) or "{}" })
end

-- Everyone looking at this inventory gets the new snapshot.
local function publish(inv)
    local snap = Inv.snapshot(inv)
    if LightRP.hotbar then LightRP.hotbar.inventoryChanged(inv, snap) end
    for viewer in pairs(inv.viewers) do
        if GetPlayerName(viewer) == nil then inv.viewers[viewer] = nil
        elseif not canAccess(viewer, inv) then
            inv.viewers[viewer] = nil
            if secondary[viewer] == inv.id then Inv.push(viewer) end
        else TriggerClientEvent(LightRpEvents.net.inventory, viewer, { inventories = { snap } }) end
    end
end

local function changed(inv)
    inv.revision = (inv.revision or 0) + 1
    persist(inv)
    publish(inv)
    if inv.kind == "drop" and next(inv.items) == nil then Inv.removeDrop(inv) end
end

local function decodeItems(text)
    local ok, value = pcall(json.decode, text or "{}")
    local items = {}
    if ok and type(value) == "table" then
        for k, v in pairs(value) do
            local slot = tonumber(k)
            if slot and type(v) == "table" and template(v.name) and (tonumber(v.count) or 0) > 0 then
                items[math.floor(slot)] = { name = v.name, count = math.floor(tonumber(v.count)), metadata = v.metadata }
            end
        end
    end
    return items
end

-- ---------------------------------------------------------------------------
-- Registry

local function register(inv)
    inv.items = inv.items or {}
    inv.viewers = inv.viewers or {}
    registry[inv.id] = inv
    return inv
end

local function loadPersistent(id, kind, label, slots, maxWeight, onCreate)
    if registry[id] then return registry[id] end
    local inv = { id = id, kind = kind, label = label, slots = slots, maxWeight = maxWeight, persistent = true, items = {} }
    local row
    if Db.ready then
        local ok, rows = Db.read("SELECT items, slots, max_weight FROM lightrp_inventories WHERE id = ?", { id })
        if not ok then return nil, "database_error" end
        row = rows[1]
    end
    if row then
        local ok, value = pcall(json.decode, row.items)
        if not ok or type(value) ~= "table" then return nil, "invalid_inventory_data" end
        inv.items = decodeItems(row.items)
        -- Migration can grant a recovery slot when every normal slot is full.
        inv.slots = math.max(slots, tonumber(row.slots) or slots)
    else
        if onCreate then onCreate(inv) end
        if Db.ready and not persist(inv) then return nil, "database_error" end
    end
    return register(inv)
end

function Inv.get(id) return registry[id] end

-- Housing supplies a server-only access predicate. It runs again on EVERY
-- transfer, including after a key is revoked, rent expires or a bucket changes.
function Inv.openHousingStash(playerId, id, label, slots, weight, accessGuard)
    if not Db.ready or type(accessGuard) ~= "function" or not accessGuard(playerId, false) then
        return false, "forbidden"
    end
    local inv, reason = loadPersistent("housing:" .. id, "housing", label, slots, weight)
    if not inv then return false, reason end
    inv.accessGuard = accessGuard
    return Inv.open(playerId, inv.id)
end

function Inv.refreshHousingAccess()
    for _, inv in pairs(registry) do
        if inv.kind == "housing" then publish(inv) end
    end
end

function Inv.player(playerId)
    local id = playerInv[playerId]
    return id and registry[id] or nil
end

function Inv.playerId(playerId) return playerInv[playerId] end

local function releaseBusy(inv)
    inv.busy = nil
    if inv.kind ~= "player" or registry[inv.id] ~= inv then return end
    for _, id in pairs(playerInv) do if id == inv.id then return end end
    -- A disconnected character can leave while an awaited write is in flight.
    -- The write is now settled; the detached cache can be unloaded safely.
    registry[inv.id] = nil
end

local function trunkOf(vehicleId)
    local id = personalTrunks[tonumber(vehicleId)] or ("trunk:" .. tostring(vehicleId))
    if registry[id] then return registry[id] end
    local vehicle = Open77.vehicles.get(vehicleId)
    if vehicle == nil then return nil end
    local label = "Trunk"
    for _, entry in ipairs(LightRpConfig.vehicles.catalog) do if entry.record == LightRpConfig.baseRecord(vehicle.record) then label = entry.label end end
    return register({ id = id, kind = "trunk", label = label, slots = Config.trunk.slots, maxWeight = Config.trunk.weight, vehicleId = vehicleId })
end

-- Personal trunks use the ownership UUID, not the network ID which changes on
-- every retrieval/restart. Rentals and staff-spawned cars stay session-only.
function Inv.attachPersonalTrunk(vehicleId, ownershipId, label)
    local id = "personal:" .. ownershipId
    local inv = registry[id]
    if inv and inv.busy then return false, "busy" end
    if not inv then
        local ok, rows = Db.read("SELECT items FROM lightrp_inventories WHERE id = ?", { id })
        if not ok then return false, "database_error" end
        if rows[1] then
            local valid, value = pcall(json.decode, rows[1].items)
            if not valid or type(value) ~= "table" then return false, "invalid_stored_inventory" end
        end
        inv = register({ id = id, kind = "trunk", label = label, slots = Config.trunk.slots,
            maxWeight = Config.trunk.weight, persistent = true, items = rows[1] and decodeItems(rows[1].items) or {} })
    end
    if not Open77.vehicles.get(vehicleId) then return false, "vehicle_gone" end
    inv.vehicleId, inv.parking = vehicleId, nil
    personalTrunks[vehicleId] = id
    return true
end

function Inv.preparePersonalParking(vehicleId)
    local id = personalTrunks[vehicleId]
    local inv = id and registry[id]
    if not inv or inv.busy or inv.parking then return false end
    inv.busy, inv.parking = true, true
    local ok = persist(inv)
    if not ok then inv.busy, inv.parking = nil, nil; return false end
    return true, function() inv.busy, inv.parking = nil, nil end
end

local function stashOf(spot)
    return loadPersistent("stash:" .. spot.id, "stash", spot.name, spot.slots or Config.stash.slots, spot.weight or Config.stash.weight)
end

-- ---------------------------------------------------------------------------
-- Drops: a pile on the ground with a pick-up point

-- `opts` (Inv.dropCash): label, prompt, marker; `sealed` piles take nothing in and
-- are never merged; `ledger` names the cash they give away (see commitDrafts).
local function newDrop(position, opts)
    opts = opts or {}
    dropSequence = dropSequence + 1
    local id = "drop:" .. dropSequence
    local label = opts.label or "Dropped items"
    local inv = register({ id = id, kind = "drop", label = label, slots = Config.drop.slots, maxWeight = Config.drop.weight,
        position = { x = position.x, y = position.y, z = position.z }, bucket = position.bucket or 0, createdAt = LightRP.nowMs(),
        sealed = opts.sealed == true or nil, ledger = opts.ledger, reserve = type(opts.reserve) == "table" and opts.reserve or nil })
    LightRP.interaction(id, {
        position = inv.position, radius = Config.drop.radius or 2.0, label = label, prompt = opts.prompt or "Pick up", key = "E", promptHeight = 0.6,
        marker = opts.marker or Config.drop.marker, ring = false, bucket = inv.bucket,
    })
    return inv
end

function Inv.removeDrop(inv)
    if inv == nil or inv.kind ~= "drop" then return end
    registry[inv.id] = nil
    LightRP.removeInteraction(inv.id)
    for viewer in pairs(inv.viewers) do
        if secondary[viewer] == inv.id then secondary[viewer] = "ground"; Inv.push(viewer) end
    end
end

local function nearestDrop(position, radius)
    local best, bestDistance
    for _, inv in pairs(registry) do
        if inv.kind == "drop" and not inv.sealed and (inv.bucket or 0) == (position.bucket or 0) then
            local dx, dy, dz = position.x - inv.position.x, position.y - inv.position.y, position.z - inv.position.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d <= radius and (bestDistance == nil or d < bestDistance) then best, bestDistance = inv, d end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Access: who may touch what, decided here on every request

local function distanceTo(playerId, position)
    local p = Open77.players.position(playerId)
    if p == nil or position == nil then return math.huge end
    local dx, dy, dz = p.x - position.x, p.y - position.y, p.z - position.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

canAccess = function(playerId, inv)
    if inv == nil then return false, "unknown_inventory" end
    if inv.id == playerInv[playerId] then return true end
    if inv.kind == "housing" then
        if type(inv.accessGuard) ~= "function" or not inv.accessGuard(playerId, false) then return false, "forbidden" end
        return true
    end
    if inv.kind == "trunk" then
        if inv.parking then return false, "busy" end
        if not inv.vehicleId then return false, "vehicle_gone" end
        local vehicle = Open77.vehicles.get(inv.vehicleId)
        if vehicle == nil then return false, "vehicle_gone" end
        local playerPosition = Open77.players.position(playerId)
        if playerPosition == nil or playerPosition.bucket ~= vehicle.bucket then return false, "too_far" end
        local position = vehicle.position or (Open77.vehicles.getPosition and Open77.vehicles.getPosition(inv.vehicleId))
        if position == nil then return false, "vehicle_gone" end
        if distanceTo(playerId, position) > (Config.trunk.range or 4.5) then return false, "too_far" end
        -- Keys permit unlocking, not bypassing a locked trunk. Fail closed if
        -- the platform cannot supply its lock state.
        if Open77.vehicles.isLocked(inv.vehicleId) ~= false then return false, "locked" end
        return true
    end
    if inv.kind == "drop" then
        local p = Open77.players.position(playerId)
        if not p or (p.bucket or 0) ~= (inv.bucket or 0) then return false, "too_far" end
        if distanceTo(playerId, inv.position) > (Config.drop.radius or 2.0) + 1.5 then return false, "too_far" end
        -- A reserved pile (a Dogtown cash bag: the killer's crew first) until its time is up.
        local r = inv.reserve
        if r and (tonumber(r.untilMs) or 0) > LightRP.nowMs() and type(r.allows) == "function" then
            local called, allowed = pcall(r.allows, playerId)
            if not called or not allowed then return false, "reserved" end
        end
        return true
    end
    if inv.kind == "stash" then
        local spot = inv.spot
        local p = Open77.players.position(playerId)
        if spot and (not p or (p.bucket or 0) ~= (spot.bucket or 0)) then return false, "too_far" end
        if spot and distanceTo(playerId, spot.position) > (Config.stash.range or 3.5) then return false, "too_far" end
        return true
    end
    return false, "forbidden"
end

-- ---------------------------------------------------------------------------
-- Mutations. All return ok, reason.

local function place(inv, name, count, metadata, preferredSlot)
    local max = stackMax(name)
    local remaining = count
    if preferredSlot then
        local target = inv.items[preferredSlot]
        if target == nil then
            local put = math.min(remaining, max)
            inv.items[preferredSlot] = { name = name, count = put, metadata = metadata }
            remaining = remaining - put
        elseif target.name == name and metaEqual(target.metadata, metadata) and target.count < max then
            local put = math.min(remaining, max - target.count)
            target.count = target.count + put
            remaining = remaining - put
        end
    end
    -- Top up existing stacks first, then open slots.
    if remaining > 0 and max > 1 then
        for slot = 1, inv.slots do
            local item = inv.items[slot]
            if remaining > 0 and item and item.name == name and metaEqual(item.metadata, metadata) and item.count < max then
                local put = math.min(remaining, max - item.count)
                item.count = item.count + put
                remaining = remaining - put
            end
        end
    end
    while remaining > 0 do
        local slot = firstFreeSlot(inv)
        if slot == nil then break end
        local put = math.min(remaining, max)
        inv.items[slot] = { name = name, count = put, metadata = metadata }
        remaining = remaining - put
    end
    return count - remaining
end

-- Stacks `count` of an item into an inventory or a detached draft (top up, then
-- free slots); returns how many fit. Check Inv.canHold first for all-or-nothing.
Inv.place = place

function Inv.canHold(inv, name, count, metadata)
    local t = template(name)
    if t == nil then return false, "unknown_item" end
    if t.weight > 0 and Inv.weightOf(inv) + t.weight * count > inv.maxWeight + 1e-6 then return false, "too_heavy" end
    -- Room: stacks that can still grow plus free slots.
    local max, room = stackMax(name), 0
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item == nil then room = room + max
        elseif item.name == name and metaEqual(item.metadata, metadata) then room = room + (max - item.count) end
        if room >= count then return true end
    end
    return false, "no_room"
end

-- Detached drafts: SQL commits before any authoritative cache is changed.
local function copyMetadata(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copyMetadata(child) end
    return result
end

function Inv.draft(inv)
    local draft = { slots = inv.slots, maxWeight = inv.maxWeight, items = {} }
    for slot, item in pairs(inv.items) do
        draft.items[slot] = { name = item.name, count = item.count, metadata = copyMetadata(item.metadata) }
    end
    return draft
end

function Inv.cashOf(inv)
    local total = 0
    for _, item in pairs(inv.items) do if item.name == "cash" then total = total + item.count end end
    return total
end

function Inv.adjustCash(draft, delta)
    if not math.tointeger(delta) or math.abs(delta) > 9007199254740991 then return false, "invalid_amount" end
    local after = Inv.cashOf(draft) + delta
    if after < 0 then return false, "insufficient_funds" end
    if after > 9007199254740991 then return false, "invalid_amount" end
    if delta > 0 then
        local ok, reason = Inv.canHold(draft, "cash", delta)
        if not ok then return false, reason end
        place(draft, "cash", delta)
    elseif delta < 0 then
        local remaining = -delta
        for slot = draft.slots, 1, -1 do
            local item = draft.items[slot]
            if item and item.name == "cash" and remaining > 0 then
                local take = math.min(remaining, item.count)
                item.count, remaining = item.count - take, remaining - take
                if item.count == 0 then draft.items[slot] = nil end
            end
        end
    end
    return true
end

function Inv.writeDraft(inv, draft)
    return { query = [[INSERT INTO lightrp_inventories (id, kind, label, slots, max_weight, items) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE items = VALUES(items), slots = VALUES(slots), max_weight = VALUES(max_weight), label = VALUES(label)]],
        values = { inv.id, inv.kind, inv.label or "", draft.slots, draft.maxWeight, json.encode(draft.items) } }
end

function Inv.applyDraft(inv, draft)
    inv.items, inv.slots = draft.items, draft.slots
    inv.revision = (inv.revision or 0) + 1
end

function Inv.publishCommitted(inv)
    local ok, err = pcall(publish, inv)
    if not ok then LightRP.log("inventory committed; notification failed: %s", tostring(err)) end
    if inv.kind == "drop" and next(inv.items) == nil then Inv.removeDrop(inv) end
end
Inv.releaseBusy = releaseBusy

local function commitDrafts(changes, extraQueries, afterCommit)
    local writes, receipts = {}, {}
    if LightRP.armament and LightRP.armament.prepare then
        local ok, reason, queries, committed = LightRP.armament.prepare(changes)
        if not ok then return false, reason end
        for _, query in ipairs(queries or {}) do writes[#writes + 1] = query end
        if committed then receipts[#receipts + 1] = committed end
    end
    for _, query in ipairs(extraQueries or {}) do writes[#writes + 1] = query end
    -- A pile that names its cash (a Dogtown cash bag) labels the ledger line of whoever
    -- takes cash out of it; a draft's own `ledger` labels its owner's line.
    local tag
    for _, change in ipairs(changes) do
        if change[1].ledger and Inv.cashOf(change[2]) < Inv.cashOf(change[1]) then tag = change[1].ledger end
    end
    for _, change in ipairs(changes) do
        local inv, draft = change[1], change[2]
        if inv.persistent then writes[#writes + 1] = Inv.writeDraft(inv, draft) end
        if LightRP.money and LightRP.money.inventoryReceipt then
            local query, commit, reason = LightRP.money.inventoryReceipt(inv, Inv.cashOf(draft), draft.ledger or tag)
            if reason then return false, reason end
            -- a silent movement (a casino stake or payout) answers a commit without a line
            if query then writes[#writes + 1] = query end
            if commit then receipts[#receipts + 1] = commit end
        end
    end
    if #writes > 0 then
        if not Db.ready then
            if LightRP.money or LightRP.armament or #(extraQueries or {}) > 0 then return false, "database_unavailable" end
        else
            local ok, reason = Db.transaction(writes)
            if not ok then return false, reason end
        end
    end
    for _, change in ipairs(changes) do Inv.applyDraft(change[1], change[2]) end
    for _, commit in ipairs(receipts) do commit() end
    if afterCommit then afterCommit() end
    for _, change in ipairs(changes) do Inv.publishCommitted(change[1]) end
    return true
end

Inv.commitDrafts = commitDrafts

-- Cash APIs use the same inventory lock as drag/drop, shops and consumption.
function Inv.prepareCash(playerId, delta)
    local inv = Inv.player(playerId)
    if not inv then return nil, "no_inventory" end
    if inv.busy then return nil, "busy" end
    local draft = Inv.draft(inv)
    local ok, reason = Inv.adjustCash(draft, delta)
    if not ok then return nil, reason end
    inv.busy = true
    return { inventory = inv, draft = draft, write = Inv.writeDraft(inv, draft) }
end

-- `labels` (optional): { from = ledger label, to = ledger label } (economy.lua,
-- Money.inventoryReceipt) instead of the plain "Physical cash moved" lines.
function Inv.transferCash(playerId, targetId, amount, labels)
    local from, to = Inv.player(playerId), Inv.player(targetId)
    if not from or not to then return false, "no_inventory" end
    if from == to or not math.tointeger(amount) or amount <= 0 then return false, "invalid_amount" end
    if from.busy or to.busy then return false, "busy" end
    local a, b = Inv.draft(from), Inv.draft(to)
    local ok, reason = Inv.adjustCash(a, -amount)
    if not ok then return false, reason end
    ok, reason = Inv.adjustCash(b, amount)
    if not ok then return false, reason end
    if type(labels) == "table" then a.ledger, b.ledger = labels.from, labels.to end
    from.busy, to.busy = true, true
    local called, saved, failure = pcall(commitDrafts, { { from, a }, { to, b } })
    releaseBusy(from); releaseBusy(to)
    return called and saved == true, called and failure or "database_error"
end

-- Part of a player's pocket cash dropped as a sealed pile at `position` (Dogtown: the
-- cash a killed player loses). The pile takes nothing in, is never merged with a
-- nearby one, and expires like any drop. opts: label, prompt, marker, ledger (the
-- label of the lines of whoever picks it up), ownerLedger (the player's own line),
-- mint (eddies the SERVER adds to the pile on top of `amount`, paid by nobody: the
-- Dogtown killer's bonus; the caller logs and caps it, the picker's ledger line
-- carries it), reserve ({ untilMs, allows(playerId) }: nobody else may open or take
-- from the pile before untilMs). Returns true, pile or false, reason.
function Inv.dropCash(playerId, amount, position, opts)
    opts = opts or {}
    local inv = Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    if not math.tointeger(amount) or amount <= 0 then return false, "invalid_amount" end
    local mint = opts.mint or 0
    if not math.tointeger(mint) or mint < 0 then return false, "invalid_amount" end
    if type(position) ~= "table" or not tonumber(position.x) or not tonumber(position.y) or not tonumber(position.z) then return false, "position_unknown" end
    if inv.busy then return false, "busy" end
    local a = Inv.draft(inv)
    local ok, reason = Inv.adjustCash(a, -amount)
    if not ok then return false, reason end
    local pile = newDrop(position, { label = opts.label, prompt = opts.prompt, marker = opts.marker, sealed = true, ledger = opts.ledger, reserve = opts.reserve })
    local b = Inv.draft(pile)
    ok, reason = Inv.adjustCash(b, amount + mint)
    if not ok then Inv.removeDrop(pile); return false, reason end
    a.ledger = opts.ownerLedger
    inv.busy, pile.busy = true, true
    local called, saved, failure = pcall(commitDrafts, { { inv, a }, { pile, b } })
    releaseBusy(inv); releaseBusy(pile)
    if not called or not saved then
        Inv.removeDrop(pile)
        return false, called and failure or "database_error"
    end
    return true, pile
end

function Inv.addItem(invId, name, count, metadata, slot)
    local inv = registry[invId]
    if inv == nil then return false, "unknown_inventory" end
    count = math.tointeger(tonumber(count) or 1)
    if not count or count <= 0 or count > 1000000000 then return false, "invalid_count" end
    if name == "cash" then metadata = nil end
    if slot and (not math.tointeger(slot) or slot < 1 or slot > inv.slots) then return false, "invalid_slot" end
    local ok, reason = Inv.canHold(inv, name, count, metadata)
    if not ok then return false, reason end
    local draft = Inv.draft(inv)
    place(draft, name, count, metadata, slot)
    return commitDrafts({ { inv, draft } })
end

-- Several items at once, all or nothing: { { name, count, metadata }, ... }.
function Inv.addItems(invId, list)
    local inv = registry[invId]
    if inv == nil then return false, "unknown_inventory" end
    if type(list) ~= "table" or #list == 0 then return false, "invalid_count" end
    local draft = Inv.draft(inv)
    for _, entry in ipairs(list) do
        local count = math.tointeger(tonumber(entry.count) or 1)
        if type(entry.name) ~= "string" or not template(entry.name) or entry.name == "cash" or not count or count <= 0 then return false, "invalid_count" end
        local ok, reason = Inv.canHold(draft, entry.name, count, entry.metadata)
        if not ok then return false, reason end
        place(draft, entry.name, count, entry.metadata)
    end
    return commitDrafts({ { inv, draft } })
end

function Inv.count(invId, name)
    local inv = registry[invId]
    if inv == nil then return 0 end
    local total = 0
    for _, item in pairs(inv.items) do if item.name == name then total = total + item.count end end
    return total
end

function Inv.removeItem(invId, name, count)
    local inv = registry[invId]
    if inv == nil then return false, "unknown_inventory" end
    count = math.tointeger(tonumber(count) or 1)
    if not count or count <= 0 or count > 1000000000 then return false, "invalid_count" end
    if Inv.count(invId, name) < count then return false, "not_enough" end
    local draft = Inv.draft(inv)
    for slot = draft.slots, 1, -1 do
        local item = draft.items[slot]
        if count > 0 and item and item.name == name then
            local take = math.min(count, item.count)
            item.count = item.count - take
            count = count - take
            if item.count <= 0 then draft.items[slot] = nil end
        end
    end
    return commitDrafts({ { inv, draft } })
end

-- Would the bag still hold `list` once one unit leaves `freeSlot`? (a garment
-- swapped for the one worn: the worn ones come back as the used one leaves).
function Inv.canSwap(invId, freeSlot, list)
    local inv = registry[invId]
    if inv == nil then return false, "unknown_inventory" end
    local draft = Inv.draft(inv)
    local item = freeSlot and draft.items[freeSlot]
    if item then item.count = item.count - 1; if item.count <= 0 then draft.items[freeSlot] = nil end end
    for _, entry in ipairs(list or {}) do
        local ok, reason = Inv.canHold(draft, entry.name, entry.count or 1, entry.metadata)
        if not ok then return false, reason end
        place(draft, entry.name, entry.count or 1, entry.metadata)
    end
    return true
end

-- One unit of the first `name` stack whose metadata passes `match` (a garment by record).
function Inv.removeMatching(invId, name, match)
    local inv = registry[invId]
    if inv == nil then return false, "unknown_inventory" end
    local draft = Inv.draft(inv)
    for slot = draft.slots, 1, -1 do
        local item = draft.items[slot]
        if item and item.name == name and match(item.metadata or {}) then
            item.count = item.count - 1
            if item.count <= 0 then draft.items[slot] = nil end
            return commitDrafts({ { inv, draft } })
        end
    end
    return false, "not_enough"
end

local function takeFromSlot(inv, slot, count)
    local item = inv.items[slot]
    if item == nil then return nil end
    local taken = { name = item.name, count = math.min(count, item.count), metadata = item.metadata }
    item.count = item.count - taken.count
    if item.count <= 0 then inv.items[slot] = nil end
    return taken
end

-- A drag: from one slot to another, in the same inventory or across the two open ones.
function Inv.move(playerId, fromId, fromSlot, toId, toSlot, count)
    local from, to = registry[fromId], registry[toId]
    local ok, reason = canAccess(playerId, from)
    if not ok then return false, reason end
    ok, reason = canAccess(playerId, to)
    if not ok then return false, reason end
    if from ~= to and to.accessGuard and not to.accessGuard(playerId, true) then return false, "forbidden" end
    if from ~= to and to.sealed then return false, "sealed" end
    fromSlot, toSlot = math.floor(tonumber(fromSlot) or 0), math.floor(tonumber(toSlot) or 0)
    if fromSlot < 1 or fromSlot > from.slots or toSlot < 1 or toSlot > to.slots then return false, "invalid_slot" end
    if from == to and fromSlot == toSlot then return true end
    local fromLive, toLive = from, to
    from = Inv.draft(fromLive)
    to = fromLive == toLive and from or Inv.draft(toLive)
    local source = from.items[fromSlot]
    if source == nil then return false, "empty_slot" end
    count = math.tointeger(tonumber(count) or source.count)
    if not count or count <= 0 or count > source.count then return false, "invalid_count" end
    local target = to.items[toSlot]
    local max = stackMax(source.name)

    if target ~= nil and (target.name ~= source.name or not metaEqual(target.metadata, source.metadata)) then
        -- Taking from an archived housing chest may not swap an item back in.
        if fromLive ~= toLive and fromLive.accessGuard and not fromLive.accessGuard(playerId, true) then return false, "forbidden" end
        if fromLive ~= toLive and fromLive.sealed then return false, "sealed" end
        -- Swap, whole stacks only.
        if count ~= source.count then return false, "swap_needs_whole_stack" end
        if from ~= to then
            local fromWeight = Inv.weightOf(from) - itemWeight(source) + itemWeight(target)
            local toWeight = Inv.weightOf(to) - itemWeight(target) + itemWeight(source)
            if fromWeight > from.maxWeight + 1e-6 or toWeight > to.maxWeight + 1e-6 then return false, "too_heavy" end
        end
        from.items[fromSlot], to.items[toSlot] = target, source
    else
        local room = target and (max - target.count) or max
        if room <= 0 then return false, "stack_full" end
        local moving = math.min(count, room)
        if from ~= to then
            local t = template(source.name)
            if t.weight > 0 and Inv.weightOf(to) + t.weight * moving > to.maxWeight + 1e-6 then return false, "too_heavy" end
        end
        local taken = takeFromSlot(from, fromSlot, moving)
        if target then target.count = target.count + taken.count
        else to.items[toSlot] = taken end
    end
    local changes = { { fromLive, from } }
    if toLive ~= fromLive then changes[#changes + 1] = { toLive, to } end
    return commitDrafts(changes)
end

local function applyUse(playerId, slot, expected)
    local inv = Inv.player(playerId)
    if inv == nil then return false, "no_inventory" end
    local item = inv.items[math.floor(tonumber(slot) or 0)]
    if item == nil then return false, "empty_slot" end
    if expected and (inv ~= expected.inventory or item ~= expected.item or item.name ~= expected.name or item.count < 1) then
        return false, "item_changed"
    end
    local t = template(item.name)
    local handler = useHandlers[item.name]
    if t == nil or (t.use == nil and handler == nil) then return false, "not_usable" end
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return false, "not_alive" end
    local consume, text = t.use and t.use.consume ~= false, nil
    if handler then
        local ok, result
        ok, result, text = pcall(handler, playerId, item, t)
        if not ok then LightRP.log("use handler for %s failed: %s", item.name, tostring(result)) return false, "use_failed" end
        if result == false then return false, "use_refused" end
        if t.use == nil then consume = result ~= "keep" end
    end
    if t.use then
        -- Do not consume a medical item when the native rejects the heal (or
        -- the API is unavailable). Apply this before any other template effect.
        if t.use.health then
            if type(Open77.players.heal) ~= "function" then return false, "use_failed" end
            local ok, applied, reason = pcall(Open77.players.heal, playerId, t.use.health)
            if not ok or applied ~= true then
                LightRP.log("heal for %s refused: %s", item.name, tostring(reason or applied))
                return false, "use_failed"
            end
        end
        if (t.use.food or t.use.drink) and LightRP.needs then
            local needs = LightRP.needs.get(playerId)
            LightRP.needs.set(playerId, needs.food + (t.use.food or 0), needs.drink + (t.use.drink or 0))
        end
        if t.use.notice then LightRP.notice(playerId, { kind = "item", title = t.label, body = t.use.notice, durationMs = 4000 }) end
    end
    if consume then
        item.count = item.count - 1
        if item.count <= 0 then inv.items[math.floor(tonumber(slot))] = nil end
        changed(inv)
    end
    LightRP.eachModule("onItemUsed", playerId, item.name, item)
    -- A kept item sends no snapshot: the third value tells the caller to answer.
    return true, type(text) == "string" and text or t.label, not consume
end

function Inv.use(playerId, slot)
    if LightRP.activities and not LightRP.activities.allows(playerId, "rpItems") then return false, "activity" end
    local inv = Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    slot = math.floor(tonumber(slot) or 0)
    local item = inv.items[slot]
    if not item then return false, "empty_slot" end
    local t = template(item.name)
    if LightRP.consumables and LightRP.consumables.isActive(playerId) then return false, "busy" end
    if LightRP.refueling and LightRP.refueling.isActive(playerId) then return false, "busy" end
    if item.name == "jerrycan" and LightRP.refueling then
        local ok, why = LightRP.refueling.beginCan(playerId, inv, slot, item)
        if not ok then LightRP.notice(playerId, {kind="info",title="Jerrycan",body=why,durationMs=4500}) end
        return ok, ok and "Jerrycan" or "use_refused"
    end
    if t and t.consumeAction then
        if not LightRP.consumables then return false, "use_failed" end -- never silently use instantly
        return LightRP.consumables.begin(playerId, inv, slot, item, t)
    end
    return applyUse(playerId, slot)
end

-- Only the server consumption ticket can commit. Re-read the exact inventory
-- and stack under the ordinary inventory lock: moving/selling it cannot grant
-- free effects, and another character can never spend this character's item.
function Inv.completeUse(playerId, ticket)
    if not LightRP.consumables or not LightRP.consumables.canCommit(playerId, ticket) then return false, "use_refused" end
    return applyUse(playerId, ticket.slot, ticket)
end

function Inv.onUse(name, fn) useHandlers[name] = fn end

-- A timed refuel ticket swaps a can in a draft, including a partially full can.
-- Paid fills persist the can AND wallet in one transaction, never remove an
-- empty can first and hope the payment/add succeeds later.
function Inv.completeFuelCan(player, a)
    if not LightRP.refueling.canCommit(player,a) then return false,"The action is no longer valid." end
    local inv=Inv.player(player)
    if not inv or inv.busy or not Db.ready then return false,"Inventory or database unavailable. Nothing was charged." end
    local draft={slots=inv.slots,maxWeight=inv.maxWeight,items={}}
    for slot,item in pairs(inv.items) do draft.items[slot]={name=item.name,count=item.count,metadata=item.metadata} end
    if a.kind == "can" and a.pay == "cash" then
        local ok, reason = Inv.adjustCash(draft, -a.price)
        if not ok then return false, reason end
        draft.cashDelta = -a.price
    end
    if a.item then
        if inv~=a.inventory or inv.items[a.slot]~=a.item then return false,"The can changed." end
        local item=draft.items[a.slot]; item.count=item.count-1
        if item.count==0 then draft.items[a.slot]=nil end
    end
    local name=a.kind=="pour" and a.remaining<0.05 and "jerrycan_empty" or "jerrycan"
    local metadata=a.kind=="pour" and a.remaining>=0.05 and {fuelLitres=math.floor(a.remaining*10+0.5)/10} or nil
    local fits=Inv.canHold(draft,name,1,metadata)
    if not fits then return false,"Make room for the jerrycan in your inventory." end
    place(draft,name,1,metadata,a.slot)
    local write={query=[[INSERT INTO lightrp_inventories (id,kind,label,slots,max_weight,items) VALUES (?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE items=VALUES(items)]],values={inv.id,inv.kind,inv.label or "",inv.slots,inv.maxWeight,json.encode(draft.items)}}
    local function commit() inv.items=draft.items; inv.revision=(inv.revision or 0)+1 end
    inv.busy=true
    local added=0
    local called,ok,why=pcall(function()
        if a.kind=="can" then
            return LightRP.money.exchange(player,a.pay,-a.price,write,commit,"fuel_can","Jerrycan refill",a.pump.name,draft)
        end
        added=LightRP.fuel.add(a.vehicle,a.litres)
        if math.abs(added-a.litres)>0.05 then return false,"Could not fill the tank." end
        local saved,reason=Db.transaction({write})
        if saved then commit() end
        return saved,reason
    end)
    if (not called or not ok) and added>0 then
        local info=LightRP.fuel.info(a.vehicle)
        if info then LightRP.fuel.set(a.vehicle,math.max(0,info.litres-added)) end
    end
    releaseBusy(inv)
    if not called then LightRP.log("fuel can settlement failed: %s",tostring(ok)) end
    if called and ok then
        local published,err=pcall(publish,inv)
        if not published then LightRP.log("fuel can committed; notification failed: %s",tostring(err)) end
        return true
    end
    return false,why or "The can could not be filled. Nothing was charged."
end

-- Shops only accept plain items. Unique/custom metadata is never silently sold
-- at a commodity price (and is never lost while preparing a checkout).
function Inv.plainCount(inv, name)
    local count = 0
    for _, item in pairs(inv.items) do
        if item.name == name and (item.metadata == nil or (type(item.metadata) == "table" and next(item.metadata) == nil)) then
            count = count + item.count
        end
    end
    return count
end

-- Prepare the complete recipe before checking weight/slots. Input is removed
-- only in a detached draft; a failed output or SQL write never eats materials.
local function recipeDraft(inv, inputs, outputs)
    if type(inputs) ~= "table" or type(outputs) ~= "table" or #outputs == 0 then return nil, "invalid_recipe" end
    local draft = Inv.draft(inv)
    for _, line in ipairs(inputs) do
        if not template(line.name) or line.name == "cash" or not math.tointeger(line.count) or line.count <= 0 then return nil, "invalid_recipe" end
        if Inv.plainCount(draft, line.name) < line.count then return nil, "not_enough" end
        local remaining = line.count
        for slot = draft.slots, 1, -1 do
            local item = draft.items[slot]
            if item and item.name == line.name and (item.metadata == nil or (type(item.metadata) == "table" and next(item.metadata) == nil)) and remaining > 0 then
                local take = math.min(remaining, item.count)
                remaining, item.count = remaining - take, item.count - take
                if item.count == 0 then draft.items[slot] = nil end
            end
        end
    end
    for _, line in ipairs(outputs) do
        if not template(line.name) or line.name == "cash" or not math.tointeger(line.count) or line.count <= 0 then return nil, "invalid_recipe" end
        local ok, reason = Inv.canHold(draft, line.name, line.count)
        if not ok then return nil, reason end
        place(draft, line.name, line.count)
    end
    return draft
end
function Inv.canProduce(inv, inputs, outputs)
    if not inv then return false, "no_inventory" end
    local draft, reason = recipeDraft(inv, inputs, outputs)
    return draft ~= nil, reason
end
function Inv.produce(playerId, inputs, outputs)
    if not Db.ready then return false, "database_unavailable" end
    local inv = Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    local draft, reason = recipeDraft(inv, inputs, outputs)
    if not draft then return false, reason end
    return commitDrafts({ { inv, draft } })
end

function Inv.trade(playerId, mode, lines, wallet, total, shopName)
    local inv = Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    if inv.busy then return false, "busy" end
    if mode ~= "buy" and mode ~= "sell" then return false, "invalid_mode" end
    local draft = { slots = inv.slots, maxWeight = inv.maxWeight, items = {} }
    for slot, item in pairs(inv.items) do
        draft.items[slot] = { name = item.name, count = item.count, metadata = item.metadata }
    end
    if wallet == "cash" and mode == "buy" then
        local ok, reason = Inv.adjustCash(draft, -total)
        if not ok then return false, reason end
        draft.cashDelta = -total
    end
    for _, line in ipairs(lines) do
        if line.name == "cash" or not template(line.name) or type(line.count) ~= "number" or not math.tointeger(line.count) or line.count <= 0 then return false, "invalid_count" end
        if mode == "buy" then
            local ok, reason = Inv.canHold(draft, line.name, line.count)
            if not ok then return false, reason end
            place(draft, line.name, line.count)
        else
            if Inv.plainCount(draft, line.name) < line.count then return false, "not_enough" end
            local remaining = line.count
            for slot = draft.slots, 1, -1 do
                local item = draft.items[slot]
                if remaining > 0 and item and item.name == line.name and (item.metadata == nil or (type(item.metadata) == "table" and next(item.metadata) == nil)) then
                    local take = math.min(remaining, item.count)
                    remaining, item.count = remaining - take, item.count - take
                    if item.count == 0 then draft.items[slot] = nil end
                end
            end
        end
    end
    -- A bought firearm gets its server serial here, registered in the same
    -- transaction as the delivery (armament_store); the shop never sends one.
    local armed, minted
    for _, line in ipairs(lines) do if LightRpArmament and LightRpArmament.weapons[line.name] then armed = true end end
    if armed then
        if not (LightRP.armament and LightRP.armament.prepare) then return false, "transaction_unavailable" end
        local prepared, reason, queries, committed = LightRP.armament.prepare({ { inv, draft } })
        if not prepared then LightRP.log("shop firearm refused: %s", tostring(reason)); return false, "firearm_refused" end
        draft.extraWrites, minted = queries or {}, committed
    end
    local note = {}
    for _, line in ipairs(lines) do note[#note + 1] = line.count .. "x " .. line.name end
    local write = { query = [[INSERT INTO lightrp_inventories (id, kind, label, slots, max_weight, items) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE items = VALUES(items), slots = VALUES(slots), max_weight = VALUES(max_weight), label = VALUES(label)]],
        values = { inv.id, inv.kind, inv.label or "", inv.slots, inv.maxWeight, json.encode(draft.items) } }
    if draft.extraWrites and #draft.extraWrites > 0 then
        write = { write }
        for _, query in ipairs(draft.extraWrites) do write[#write + 1] = query end
    end
    inv.busy = true
    local called, ok, reason = pcall(LightRP.money.exchange, playerId, wallet, mode == "buy" and -total or total, write,
        function() inv.items = draft.items; inv.revision = (inv.revision or 0) + 1; if minted then minted() end end,
        "shop_" .. mode, table.concat(note, ", "):sub(1, 160), shopName, draft)
    releaseBusy(inv)
    if not called then LightRP.log("shop settlement error: %s", tostring(ok)); return false, "database_error" end
    if not ok then return false, reason end
    local published, failure = pcall(publish, inv)
    if not published then LightRP.log("committed checkout: inventory notification failed: %s", tostring(failure)) end
    return true
end

-- Drop on the ground: into the pile at your feet, or a new one.
function Inv.drop(playerId, slot, count)
    if LightRP.activities and not LightRP.activities.allows(playerId, "rpItems") then return false, "activity" end
    local inv = Inv.player(playerId)
    if inv == nil then return false, "no_inventory" end
    slot = math.floor(tonumber(slot) or 0)
    local item = inv.items[slot]
    if item == nil then return false, "empty_slot" end
    count = math.tointeger(tonumber(count) or item.count)
    if not count or count <= 0 or count > item.count then return false, "invalid_count" end
    local position = Open77.players.position(playerId)
    if position == nil then return false, "position_unknown" end
    local pile = nearestDrop(position, Config.drop.radius or 2.0) or newDrop(position)
    if pile.busy then return false, "busy" end
    local ok, reason = Inv.canHold(pile, item.name, count, item.metadata)
    if not ok then return false, reason end
    local a, b = Inv.draft(inv), Inv.draft(pile)
    local taken = takeFromSlot(a, slot, count)
    place(b, taken.name, taken.count, taken.metadata)
    pile.busy = true
    local called, saved, failure = pcall(commitDrafts, { { inv, a }, { pile, b } })
    releaseBusy(pile)
    if not called or not saved then
        if next(pile.items) == nil then Inv.removeDrop(pile) end
        return false, called and failure or "database_error"
    end
    return true, pile
end

-- Hand to the closest player within reach.
function Inv.give(playerId, slot, count)
    if LightRP.activities and not LightRP.activities.allows(playerId, "rpItems") then return false, "activity" end
    local inv = Inv.player(playerId)
    if inv == nil then return false, "no_inventory" end
    slot = math.floor(tonumber(slot) or 0)
    local item = inv.items[slot]
    if item == nil then return false, "empty_slot" end
    count = math.tointeger(tonumber(count) or item.count)
    if not count or count <= 0 or count > item.count then return false, "invalid_count" end
    local here = Open77.players.position(playerId)
    if here == nil then return false, "position_unknown" end
    local target, best
    for id, p in pairs(Open77.players.positions() or {}) do
        id = tonumber(id)
        if id and id ~= playerId and (p.bucket or 0) == (here.bucket or 0) and playerInv[id] then
            local dx, dy, dz = p.x - here.x, p.y - here.y, p.z - here.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d <= (Config.giveRange or 3.0) and (best == nil or d < best) then target, best = id, d end
        end
    end
    if target == nil then return false, "nobody_near" end
    local other = Inv.player(target)
    if other.busy then return false, "busy" end
    local ok, reason = Inv.canHold(other, item.name, count, item.metadata)
    if not ok then return false, reason == "too_heavy" and "target_too_heavy" or "target_no_room" end
    other.busy = true
    local a, b = Inv.draft(inv), Inv.draft(other)
    local taken = takeFromSlot(a, slot, count)
    place(b, taken.name, taken.count, taken.metadata)
    local applied, saved, failure = pcall(commitDrafts, { { inv, a }, { other, b } })
    releaseBusy(other)
    if not applied or not saved then return false, applied and failure or "database_error" end
    local t = template(taken.name)
    LightRP.notice(target, { kind = "item", title = "Received", body = string.format("%dx %s from %s", taken.count, t and t.label or taken.name, LightRP.characters.displayName(playerId)), durationMs = 6000 })
    LightRP.eachModule("onItemGiven", playerId, target, taken.name, taken.count) -- dailies (Housewarming)
    return true, { target = target, name = taken.name, count = taken.count, label = t and t.label or taken.name }
end

-- ---------------------------------------------------------------------------
-- Open / close: what the page shows

local function secondaryFor(playerId)
    local id = secondary[playerId]
    if id == nil or id == "ground" then return { kind = "ground", id = "ground", label = "Drop", slots = Config.drop.slots, maxWeight = Config.drop.weight, weight = 0, items = {} } end
    local inv = registry[id]
    if inv == nil or not canAccess(playerId, inv) then
        if inv then inv.viewers[playerId] = nil end
        secondary[playerId] = "ground"
        return secondaryFor(playerId)
    end
    return Inv.snapshot(inv)
end

function Inv.push(playerId)
    local inv = Inv.player(playerId)
    if inv == nil then return end
    TriggerClientEvent(LightRpEvents.net.inventory, playerId, { inventories = { Inv.snapshot(inv), secondaryFor(playerId) } })
end

-- Revoke every open trunk immediately, before another drag can be submitted.
-- The player's pockets remain open; subsequent requests are still revalidated.
function Inv.onVehicleLockChanged(vehicleId, locked)
    if not locked then return end
    local trunk = registry[personalTrunks[tonumber(vehicleId)] or ("trunk:" .. tostring(vehicleId))]
    if trunk == nil then return end
    for viewer in pairs(trunk.viewers) do
        trunk.viewers[viewer] = nil
        if secondary[viewer] == trunk.id then
            secondary[viewer] = "ground"
            Inv.push(viewer)
            LightRP.notice(viewer, { kind = "info", title = "Trunk closed", body = "The vehicle has been locked." })
        end
    end
end

local function stopWatching(playerId)
    for _, inv in pairs(registry) do inv.viewers[playerId] = nil end
end

-- Pick the secondary: the one asked for, else the nearest openable vehicle, else the nearest pile.
local function pickSecondary(playerId, wanted)
    if wanted and registry[wanted] and canAccess(playerId, registry[wanted]) then return wanted end
    local position = Open77.players.position(playerId)
    if position == nil then return "ground" end
    local trunkReason
    if type(Open77.vehicles.closest) == "function" then
        -- A player anchor scopes the search to their routing bucket.
        local ok, entry = pcall(Open77.vehicles.closest, playerId, { radius = Config.trunk.range or 4.5 })
        local vehicleId = ok and type(entry) == "table" and (entry.id or entry.vehicleId) or nil
        if vehicleId then
            local trunk = trunkOf(vehicleId)
            if trunk then
                local allowed, reason = canAccess(playerId, trunk)
                if allowed then return trunk.id end
                trunkReason = reason
            end
        end
    end
    local pile = nearestDrop(position, Config.drop.radius or 2.0)
    if pile then return pile.id end
    return "ground", trunkReason
end

function Inv.open(playerId, wanted)
    local inv = Inv.player(playerId)
    if inv == nil then return false, "no_inventory" end
    if wanted and wanted ~= "ground" then
        local allowed, reason = canAccess(playerId, registry[wanted])
        if not allowed then return false, reason end
    end
    stopWatching(playerId)
    local selected, reason = pickSecondary(playerId, wanted)
    secondary[playerId] = selected
    inv.viewers[playerId] = true
    local other = registry[secondary[playerId]]
    if other then other.viewers[playerId] = true end
    LightRP.dialog(playerId, "inventory", { left = Inv.snapshot(inv), right = secondaryFor(playerId) })
    -- the Worn column: what the character wears right now (server/modules/clothing.lua)
    if LightRP.clothing and LightRP.clothing.pushWorn then LightRP.clothing.pushWorn(playerId) end
    LightRP.eachModule("onInventoryOpened", playerId)
    if reason == "locked" then
        LightRP.notice(playerId, { kind = "info", title = "Trunk locked", body = "Unlock the vehicle before opening its trunk." })
    end
    return true
end

function Inv.close(playerId)
    stopWatching(playerId)
    secondary[playerId] = nil
end

-- Explicit target from the vehicle menu, never substitute the nearest car.
function Inv.openTrunk(playerId, vehicleId)
    if Inv.player(playerId) == nil then return false, "no_inventory" end
    local trunk = trunkOf(vehicleId)
    local allowed, reason = canAccess(playerId, trunk)
    if not allowed then return false, reason end
    local opened, failure = Open77.vehicles.openDoor(vehicleId, "trunk")
    if not opened then return false, failure or "trunk_unavailable" end
    if LightRP.bubbles then LightRP.bubbles.act(playerId, "Opens the trunk", { vehicle = vehicleId, icon = "trunk", duration = 4 }) end
    return Inv.open(playerId, trunk.id)
end

-- Dragging onto the empty "Drop" panel makes a pile; onto a pile, fills it.
local function moveToGround(playerId, fromSlot, count)
    local ok, result = Inv.drop(playerId, fromSlot, count)
    if not ok then return false, result end
    secondary[playerId] = result.id
    result.viewers[playerId] = true
    Inv.push(playerId)
    return true
end

-- ---------------------------------------------------------------------------
-- Lifecycle

function Inv.onCharacterLoaded(playerId, c)
    stopWatching(playerId)
    secondary[playerId] = nil
    playerInv[playerId] = nil
    if c == nil or c.status ~= "active" or c.identifier == nil then return end
    local id = "player:" .. c.identifier .. "#" .. (c.key or "default")
    while registry[id] and registry[id].busy do Wait(10) end
    local inv = loadPersistent(id, "player", LightRP.characters.displayName(playerId), Config.player.slots, Config.player.weight, function(fresh)
        for _, start in ipairs(Config.starting or {}) do
            if template(start.name) then place(fresh, start.name, start.count or 1, start.metadata) end
        end
    end)
    if not inv then
        LightRP.log("inventory for %d unavailable; keeping stored contents untouched", playerId)
        return
    end
    inv.label = LightRP.characters.displayName(playerId)
    inv.playerId = playerId
    inv.cashReady = false
    playerInv[playerId] = id
end

function Inv.onCharacterActivated(playerId, c) Inv.onCharacterLoaded(playerId, c) end

function Inv.onDisconnected(playerId)
    stopWatching(playerId)
    local id = playerInv[playerId]
    playerInv[playerId] = nil
    secondary[playerId] = nil
    -- A checkout owns persistence until it settles. Writing the old snapshot
    -- here would undo a committed transaction when a player disconnects mid-buy.
    if id and registry[id] and not registry[id].busy then persist(registry[id]); registry[id] = nil end
end

function Inv.onDatabaseReady()
    for _, id in ipairs(GetPlayers()) do
        local c = LightRP.characters.get(id)
        if c and c.status == "active" then Inv.onCharacterLoaded(id, c) end
    end
end

AddEventHandler("onVehicleRemoved", function(id)
    local durableId = personalTrunks[tonumber(id)]
    local trunk = registry[durableId or ("trunk:" .. tostring(id))]
    personalTrunks[tonumber(id)] = nil
    if trunk == nil then return end
    if durableId then
        -- Existing mutations hold this cache across awaited writes. Keep it for
        -- the next retrieval; every change is persisted under its stable ID.
        trunk.vehicleId = nil
    else registry[trunk.id] = nil end
    for viewer in pairs(trunk.viewers) do
        if secondary[viewer] == trunk.id then secondary[viewer] = "ground"; Inv.push(viewer) end
    end
    trunk.viewers = {}
end)

-- Stashes from config: interaction points that open them on the right.
local stashSpots = {}
CreateThread(function()
    Wait(600)
    for _, spot in ipairs(Config.stashes or {}) do
        stashSpots["stash." .. spot.id] = spot
        LightRP.interaction("stash." .. spot.id, {
            position = spot.position, radius = Config.stash.interactRadius or 2.0, label = spot.name, prompt = "Open", key = "E", promptHeight = spot.promptHeight or 1.0,
            marker = spot.marker or Config.stash.marker, ring = false, bucket = spot.bucket or 0,
        })
    end
    if #(Config.stashes or {}) > 0 then LightRP.log("inventory: %d stash(es) placed", #Config.stashes) end
end)

function Inv.onInteract(playerId, id)
    local spot = stashSpots[id]
    if spot then
        local stash = stashOf(spot)
        if not stash then LightRP.result(playerId, false, "Storage unavailable. Your items have not changed.", "inventory.open"); return end
        stash.spot = spot
        Inv.open(playerId, stash.id)
        return
    end
    if registry[id] and registry[id].kind == "drop" then
        local ok, reason = Inv.open(playerId, id)
        if not ok and reason == "reserved" then LightRP.result(playerId, false, Inv.explain(reason), "inventory.open") end
    end
end

-- Piles that nobody touched for a while go away.
CreateThread(function()
    while true do
        Wait(30000)
        local now = LightRP.nowMs()
        local ttl = (Config.drop.ttlMinutes or 10) * 60000
        for _, inv in pairs(registry) do
            if inv.kind == "drop" and not inv.busy and now - (inv.touchedAt or inv.createdAt or now) > ttl and next(inv.viewers) == nil then Inv.removeDrop(inv) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Actions and commands

local REASONS = {
    unknown_inventory = "That inventory is gone.", too_far = "Too far away.", locked = "The vehicle is locked.", vehicle_gone = "The vehicle is gone.",
    invalid_slot = "Invalid slot.", empty_slot = "Nothing there.", invalid_count = "Invalid amount.", swap_needs_whole_stack = "Move the whole stack to swap.",
    stack_full = "That stack is full.", too_heavy = "Too heavy to carry.", no_room = "No room.", not_usable = "You cannot use that.", not_alive = "Not right now.",
    nobody_near = "Nobody close enough to hand it to.", target_too_heavy = "They cannot carry that.", target_no_room = "They have no room.",
    no_inventory = "Finish your character first.", unknown_item = "Unknown item.", not_enough = "Not enough of that.", use_refused = "That did nothing.",
    position_unknown = "Your position is unknown.", forbidden = "You cannot open that.",
    use_failed = "This item could not be used. It has not been consumed.",
    trunk_unavailable = "The trunk could not be opened.",
    busy = "Your inventory is busy. Wait for the current operation to finish.",
    activity = "Your RP items stay put away during this activity.",
    sealed = "Nothing can be put in there.",
    reserved = "Reserved for the killer's crew for a few more seconds.",
}
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end
Inv.explain = explain

local function touched(id) local inv = registry[id]; if inv then inv.touchedAt = LightRP.nowMs() end end

LightRP.action("inventory.open", function(playerId, payload)
    local ok, reason = Inv.open(playerId, payload.target)
    LightRP.log("inventory.open by %d: %s (secondary %s)", playerId, ok and "ok" or tostring(reason), tostring(secondary[playerId]))
    if not ok then LightRP.result(playerId, false, explain(reason), "inventory.open") end
end)

-- Staff: open the inventory without the key (diagnostics).
LightRP.command("lightrp.inv", { restricted = true }, function(source)
    local ok, reason = Inv.open(source)
    return ok, ok and "Inventory opened." or explain(reason)
end)

LightRP.action("inventory.close", function(playerId) Inv.close(playerId) end)

LightRP.action("inventory.move", function(playerId, payload)
    local from, to = payload.from or {}, payload.to or {}
    if to.inventory == "ground" then
        -- Ground drops always come from the player's pockets. Never interpret a
        -- trunk/stash slot as a player slot with the same number.
        if from.inventory ~= playerInv[playerId] then
            LightRP.result(playerId, false, "Only items in your pockets can be dropped on the ground.", "inventory.move")
            return
        end
        local ok, reason = moveToGround(playerId, from.slot, payload.count)
        if not ok then LightRP.result(playerId, false, explain(reason), "inventory.move") end
        return
    end
    local ok, reason = Inv.move(playerId, from.inventory, from.slot, to.inventory, to.slot, payload.count)
    if not ok then LightRP.result(playerId, false, explain(reason), "inventory.move") else touched(from.inventory); touched(to.inventory) end
end)

LightRP.action("inventory.use", function(playerId, payload)
    local ok, result, kept = Inv.use(playerId, payload.slot)
    if not ok then LightRP.result(playerId, false, explain(result), "inventory.use")
    elseif kept then LightRP.result(playerId, true, result, "inventory.use") end
end)

LightRP.action("inventory.drop", function(playerId, payload)
    local ok, result = moveToGround(playerId, payload.slot, payload.count)
    if not ok then LightRP.result(playerId, false, explain(result), "inventory.drop") end
end)

LightRP.action("inventory.give", function(playerId, payload)
    local ok, result = Inv.give(playerId, payload.slot, payload.count)
    LightRP.result(playerId, ok, ok and string.format("%dx %s handed to %s.", result.count, result.label, LightRP.characters.displayName(result.target)) or explain(result), "inventory.give")
end)

LightRP.command("lightrp.giveitem", { restricted = true, usage = "/lightrp.giveitem <id|me> <item> [count]" }, function(source, args)
    local target = (args[1] == nil or args[1] == "me") and source or tonumber(args[1])
    if target == nil or GetPlayerName(target) == nil or args[2] == nil then return false end
    local id = playerInv[target]
    if id == nil then return false, explain("no_inventory") end
    local ok, reason = Inv.addItem(id, string.lower(args[2]), tonumber(args[3]) or 1)
    return ok, ok and string.format("%s x%d given to %s.", args[2], tonumber(args[3]) or 1, LightRP.characters.displayName(target)) or explain(reason)
end)

LightRP.command("lightrp.items", { restricted = true }, function()
    local names = {}
    for name in pairs(Items) do names[#names + 1] = name end
    table.sort(names)
    return true, table.concat(names, ", ")
end)

-- Hold inventory locks across yielding database/native calls too. A checkout
-- cannot interleave with use, transfers, drops, staff grants or a second trade.
local function serialise(fn, inventories)
    return function(...)
        local locked, seen = {}, {}
        for _, inv in pairs(inventories(...)) do
            if inv and not seen[inv] then
                if inv.busy then return false, "busy" end
                seen[inv] = true; locked[#locked + 1] = inv
            end
        end
        for _, inv in ipairs(locked) do inv.busy = true end
        local result = table.pack(pcall(fn, ...))
        for _, inv in ipairs(locked) do releaseBusy(inv) end
        if not result[1] then error(result[2]) end
        return table.unpack(result, 2, result.n)
    end
end
for _, method in ipairs({ "addItem", "removeItem" }) do
    Inv[method] = serialise(Inv[method], function(id) return { registry[id] } end)
end
for _, method in ipairs({ "use", "completeUse", "drop", "give", "produce" }) do
    Inv[method] = serialise(Inv[method], function(playerId) return { Inv.player(playerId) } end)
end
Inv.move = serialise(Inv.move, function(_, fromId, _, toId) return { registry[fromId], registry[toId] } end)

-- Custom item transactions share the exact lock used by drag/drop and use.
Inv.transaction = serialise(function(playerId, fn)
    local inv = Inv.player(playerId)
    if not inv then return false, "no_inventory" end
    return fn(inv)
end, function(playerId) return { Inv.player(playerId) } end)

LightRP.log("inventory ready: %d item template(s)", (function() local n = 0 for _ in pairs(Items) do n = n + 1 end return n end)())
