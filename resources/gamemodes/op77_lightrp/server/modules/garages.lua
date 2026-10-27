-- Durable ownership is separate from a live network entity. SQL never stores a
-- runtime vehicle ID; it stores where the vehicle is: `stored` (at garage_id),
-- `out` (in the world) or `impound`. A vehicle still `out` when the server starts
-- was left outside at a restart: it goes to the impound, as does a vehicle that
-- disappears from the world (destroyed, deleted, lost to a bug). An owner can send
-- theirs there from any garage (stolen, lost, stuck), and recovers it at any
-- public garage for the impound fee (server/config/garages.lua `impound`).
local C, Db, E = LightRpGarages, LightRP.db, LightRpEvents
local Garage = LightRP.module("garage", {})
local rows, live, places, sessions, ownerBusy = {}, {}, {}, {}, {}
local loaded, loading, sequence = false, false, 0
local send, snapshot
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_owned_vehicles (
    id CHAR(36) NOT NULL PRIMARY KEY,
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
    model VARCHAR(48) NOT NULL, record VARCHAR(192) NOT NULL,
    garage_id VARCHAR(48) NOT NULL, properties MEDIUMTEXT NOT NULL,
    grant_key VARCHAR(128) NOT NULL UNIQUE,
    state VARCHAR(16) NOT NULL DEFAULT 'stored',
    impound_reason VARCHAR(24) NULL, impound_fee INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX owner_character (identifier, character_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function identity(id)
    local c = LightRP.characters.get(id)
    if not c or c.status ~= "active" or not c.identifier then return nil end
    return c.identifier .. "#" .. c.key, c
end
local function owner(row) return row.identifier .. "#" .. row.character_key end
local function distance(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
local function supported()
    return type(Open77.vehicles.getProperties) == "function" and type(Open77.vehicles.setProperties) == "function"
end
local function available()
    if not C.enabled then return false, "Garages are closed." end
    if not Db.ready or not loaded then return false, "Vehicle storage is unavailable. Your ownership records are safe; try again shortly." end
    if not supported() then return false, "This server needs the vehicle-properties API. Contact the server owner." end
    return true
end
local function guard(id, place)
    local ok, why = available()
    if not ok then return false, why end
    if not identity(id) then return false, "Finish loading your character first." end
    if (LightRP.characters.switching or {})[id] then return false, "Your character is changing. Please wait." end
    local life, p = Open77.players.getLifeState(id), Open77.players.position(id)
    if not life or life.phase ~= "alive" then return false, "You cannot use the garage right now." end
    if not place or not p or (p.bucket or 0) ~= place.bucket or distance(p, place.position) > C.interactRadius + 0.75 then
        return false, "Walk up to the public garage marker."
    end
    if Open77.vehicles.getPlayerSeat(id) then return false, "Park nearby and step out of the vehicle first." end
    return true
end
function Garage.isBusy(id)
    local key = identity(id)
    return key and ownerBusy[key] ~= nil or false
end
function Garage.ownedId(vehicleId)
    local row = live[tonumber(vehicleId)]
    return row and row.id
end
local function label(row)
    local entry = LightRP.vehicles.byKey[row.model]
    return entry and entry.label or row.model
end
local function capture(row)
    if not row.vehicleId then return end
    local props = Open77.vehicles.getProperties(row.vehicleId)
    if type(props) == "table" then
        row.props = props
        row.dirty = true
        row.revision = (row.revision or 0) + 1
    end
end
local function persist(row)
    local rev = row.revision
    local encoded = json.encode(row.props)
    if not encoded then return false, "Could not encode vehicle properties." end
    -- No nil in a parameter list: the database bridge refuses a list with a hole.
    local ok = Db.run("UPDATE lightrp_owned_vehicles SET garage_id = ?, properties = ?, state = ?, impound_reason = NULLIF(?, ''), impound_fee = ? WHERE id = ?",
        { row.garage_id, encoded, row.state or "stored", row.impound_reason or "", row.impound_fee or 0, row.id })
    if ok and rev == row.revision then row.dirty = false end
    return ok, ok and nil or "Vehicle storage could not be saved. No second vehicle will be created."
end
local function forgetLive(row)
    if row.vehicleId then live[row.vehicleId] = nil end
    row.vehicleId = nil
end

-- The impound ---------------------------------------------------------------
local IMPOUND = C.impound or {}
local REASONS = {
    restart = "Left outside at a server restart",
    lost = "Found missing from the streets",
    requested = "Sent by its owner",
    staff = "Towed by the city",
}
local function feeFor(reason)
    return math.max(0, math.floor(tonumber((IMPOUND.fees or {})[reason]) or 0))
end
local function money(amount)
    return LightRP.money and LightRP.money.format and LightRP.money.format(amount) or ("€$" .. tostring(amount))
end
local function ownerOnline(row)
    for _, id in ipairs(GetPlayers()) do
        if identity(tonumber(id) or id) == owner(row) then return tonumber(id) or id end
    end
end
-- Tell the owner (when connected) once per impound where to recover it.
local function tellImpounded(row, playerId)
    playerId = playerId or ownerOnline(row)
    if not playerId or row.notified then return end
    row.notified = true
    local fee = row.impound_fee or 0
    pcall(LightRP.notice, playerId, { kind = "warning", title = IMPOUND.name or "Impound", durationMs = 12000,
        body = string.format("%s is at the impound (%s). Recover it at any public garage%s.", label(row),
            string.lower(REASONS[row.impound_reason] or "towed"), fee > 0 and (" for " .. money(fee)) or ", free of charge") })
end
local function impound(row, reason)
    row.state, row.impound_reason, row.impound_fee = "impound", reason, feeFor(reason)
    row.dirty, row.notified = true, nil
end
-- Owned vehicles carry their ownership id in the vehicle's state bag, so a
-- resource restart can find and remove those left in the world.
local function tag(vehicleId, rowId)
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return end
    pcall(function() Open77.state.entity("vehicle", vehicleId):set("lightrpOwned", rowId) end)
end
local function taggedOwner(vehicleId)
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return nil end
    local ok, value = pcall(function() return Open77.state.entity("vehicle", vehicleId):get("lightrpOwned") end)
    return ok and value or nil
end
local function migrate()
    for _, column in ipairs({ { "state", "VARCHAR(16) NOT NULL DEFAULT 'stored'" }, { "impound_reason", "VARCHAR(24) NULL" },
                              { "impound_fee", "INT NOT NULL DEFAULT 0" } }) do
        local present = Db.single(string.format([[SELECT COUNT(*) AS n FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_owned_vehicles' AND COLUMN_NAME = '%s']], column[1]))
        if present and tonumber(present.n) == 0 then
            Db.run(string.format("ALTER TABLE lightrp_owned_vehicles ADD COLUMN %s %s", column[1], column[2]))
            LightRP.log("migrated: lightrp_owned_vehicles.%s added", column[1])
        end
    end
end

function Garage.onDatabaseReady()
    -- The worker below retries this too: one load at a time (SQL calls yield).
    if loaded or loading or not C.enabled then return end
    loading = true
    migrate()
    local ok, stored = Db.read("SELECT * FROM lightrp_owned_vehicles")
    if not ok then loading = false; LightRP.log("garage: ownership load failed; garage stays closed") return end
    for _, row in ipairs(stored) do
        local valid, props = pcall(json.decode, row.properties)
        row.props = valid and type(props) == "table" and props or nil
        if not row.props then
            row.invalid = true
            LightRP.log("garage: invalid properties for %s; quarantined, not overwritten", row.id)
        end
        if not places[row.garage_id] then
            row.garage_id, row.dirty = C.defaultGarage, true
        end
        row.state = row.state or "stored"
        row.impound_fee = tonumber(row.impound_fee) or 0
        rows[row.id] = row
    end
    -- A resource restart leaves the old entities in the world: remove them, never
    -- a second copy of a car.
    local swept = 0
    local listed, all = pcall(Open77.vehicles.all)
    for _, v in ipairs(listed and type(all) == "table" and all or {}) do
        local rowId = v.id and taggedOwner(v.id)
        if rowId and rows[rowId] and not live[v.id] then
            if Open77.vehicles.remove(v.id) then swept = swept + 1 end
        end
    end
    -- Left outside at the restart: to the impound.
    local towed = 0
    for _, row in pairs(rows) do
        if row.state == "out" and not row.invalid then
            impound(row, "restart"); towed = towed + 1
            persist(row)
        end
    end
    loaded, loading = true, false
    LightRP.log("garage: %d ownership record(s) loaded, %d left outside towed to the impound (%d removed from the world)", #stored, towed, swept)
end

-- Grant only from trusted server code / a restricted staff command. A caller's
-- stable grantKey makes retried dealership/job deliveries idempotent.
local function createOwnership(playerId, model, garageId, grantKey, payment)
    local ok, why = available()
    if not ok then return false, why end
    local who, c = identity(playerId)
    local entry = type(model) == "string" and LightRP.vehicles.byKey[model:lower()]
    local place = places[garageId or C.defaultGarage]
    if not who then return false, "No active character." end
    if ownerBusy[who] or (LightRP.characters.switching or {})[playerId] then return false, "Another garage operation is running." end
    if not entry or not place then return false, "Unknown vehicle model or garage." end
    if grantKey ~= nil and (type(grantKey) ~= "string" or #grantKey < 1 or #grantKey > 128) then return false, "Invalid grant key." end
    local count = 0
    for _, row in pairs(rows) do
        if grantKey and row.grant_key == grantKey then
            if owner(row) == who and row.model == entry.key then return true, row.id end
            return false, "This grant key already belongs to another delivery."
        end
        if owner(row) == who then count = count + 1 end
    end
    if count >= C.maxOwned then return false, "This character has reached the personal vehicle limit." end
    local operation = {}; ownerBusy[who] = operation
    local ran, granted, result = pcall(function()
        local read, result = Db.read("SELECT UUID() AS id")
        if not read or not result[1] then return false, "The database did not issue a vehicle ID." end
        local row = { id = result[1].id, identifier = c.identifier, character_key = c.key,
            model = entry.key, record = entry.record, garage_id = place.id, props = {}, grant_key = grantKey or result[1].id,
            state = "stored", impound_fee = 0 }
        local query = [[INSERT INTO lightrp_owned_vehicles
            (id, identifier, character_key, model, record, garage_id, properties, grant_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?)]]
        local values = { row.id, row.identifier, row.character_key, row.model, row.record, row.garage_id, "{}", row.grant_key }
        local saved, failure
        if payment then
            if identity(playerId) ~= who then return false, "Your character changed before payment." end
            if payment.validate then
                local allowed, message = payment.validate()
                if not allowed then return false, message end
            end
            -- Reuse the economy's locked, disconnect-safe transaction primitive:
            -- wallet, ownership INSERT and ledger entry commit together.
            saved, failure = LightRP.money.exchange(playerId, payment.method, -payment.amount,
                { query = query, values = values }, function() rows[row.id] = row end,
                "vehicle_purchase", "Vehicle " .. row.id .. ": " .. entry.label, payment.vendor or "Dealership")
        else saved = Db.run(query, values) end
        if not saved then return false, payment and LightRP.money.explain(failure) or "The ownership could not be saved. Nothing was granted." end
        rows[row.id] = row
        if identity(playerId) == who and not (payment and payment.silent) then
            pcall(LightRP.notice, playerId, { kind = "success", title = "Personal vehicle",
                body = entry.label .. " is waiting at " .. place.name .. ".", durationMs = 9000 })
        end
        return true, row.id
    end)
    if ownerBusy[who] == operation then ownerBusy[who] = nil end
    if not ran then LightRP.log("garage grant failed: %s", tostring(granted)); return false, "Garage operation failed. Check the server log." end
    return granted, result
end
function Garage.grant(playerId, model, garageId, grantKey)
    return createOwnership(playerId, model, garageId, grantKey)
end
-- Trusted server API only: callers own pricing and interaction policy. Never
-- forward a browser payload as payment; dealership.lua supplies a fixed quote.
function Garage.purchase(playerId, model, garageId, grantKey, payment)
    if type(payment) ~= "table" or not LightRP.money.validAmount(payment.amount)
        or (payment.method ~= "cash" and payment.method ~= "bank") then return false, "Invalid payment." end
    return createOwnership(playerId, model, garageId, grantKey, payment)
end
function Garage.location(id)
    local place = places[id]
    return place and { id = place.id, name = place.name, position = place.position }
end

local function clearSpace(place, slot)
    for _, v in ipairs(Open77.vehicles.all(place.bucket)) do
        if distance(v.position, slot.position) < C.clearance then return false end
    end
    -- Canonical players prevent spawning into someone standing on the pickup bay.
    for _, id in ipairs(GetPlayers()) do
        local p = Open77.players.position(id)
        if p and (p.bucket or 0) == place.bucket and distance(p, slot.position) < 2 then return false end
    end
    return true
end
local function canStore(playerId, row, place)
    local v = row.vehicleId and Open77.vehicles.get(row.vehicleId)
    if not v then return false, "This vehicle is already in storage." end
    if v.bucket ~= place.bucket or distance(v.position, place.position) > C.storeRadius then
        return false, "Bring your vehicle into the garage area first."
    end
    if (v.speed or 0) > C.stationarySpeed then return false, "Stop the vehicle before parking it." end
    if #(v.occupants or {}) > 0 then return false, "Everyone must leave the vehicle before it can be stored." end
    if identity(playerId) ~= owner(row) then return false, "This is not your character's vehicle." end
    return true
end

-- `check` replaces the "at the garage marker" guard for a delivery that is not
-- asked for at a garage (a dealership's bay).
local function retrieve(playerId, row, place, check)
    check = check or guard
    if row.vehicleId then return false, "This vehicle is already out. Bring it back to a garage." end
    if row.invalid then return false, "This vehicle needs a storage check by staff. It has not been deleted." end
    if row.state == "impound" then return false, "This vehicle is at the impound: recover it first." end
    if row.garage_id ~= place.id then return false, "Collect this vehicle from its listed garage." end
    local count = 0
    for _, other in pairs(rows) do if owner(other) == owner(row) and other.vehicleId then count = count + 1 end end
    if count >= C.maxOutside then return false, "Store your current personal vehicle before collecting another." end
    if place.busy then return false, "Someone is collecting a vehicle. Please wait." end
    local slot
    for _, candidate in ipairs(place.parking) do if clearSpace(place, candidate) then slot = candidate; break end end
    if not slot then return false, "The pickup bays are occupied. Clear a bay and try again." end
    place.busy = true
    local created
    local ran, ok, message = pcall(function()
        if row.dirty then
            local saved, reason = persist(row)
            if not saved then return false, reason end
        end
        local valid, reason = check(playerId, place)
        if not valid or identity(playerId) ~= owner(row) then return false, reason or "Your character changed." end
        if not clearSpace(place, slot) then return false, "The pickup bay became occupied." end
        created, reason = Open77.vehicles.create({ record = row.record, appearance = row.props.appearance,
            position = slot.position, yaw = slot.heading or 0, bucket = place.bucket,
            persistent = true, despawnWhenUnobserved = false })
        if not created then return false, "Vehicle delivery failed: " .. tostring(reason) end
        row.vehicleId, live[created] = created, row
        tag(created, row.id)
        if next(row.props) ~= nil then
            local restore = row.props
            if type(row.props.paint) == "table" and row.props.paint.applied == false then
                -- On shipped hosts, sending colour channels also enables paint,
                -- even when applied=false was saved. A fresh spawn already has
                -- its original livery: do not accidentally repaint it black.
                restore = {}; for key, value in pairs(row.props) do restore[key] = value end
                restore.paint = {}; for key, value in pairs(row.props.paint) do
                    if key ~= "primary" and key ~= "secondary" then restore.paint[key] = value end
                end
            end
            local applied, err = Open77.vehicles.setProperties(created, restore)
            if not applied then return false, "Could not restore this vehicle: " .. tostring(err) end
        end
        if LightRP.fuel then LightRP.fuel.restore(created, row.id) end
        Open77.vehicles.setEngine(created, false)
        local locked = LightRP.keys.lock(created, true)
        if not locked then return false, "Could not secure the vehicle." end
        local attached, failure = LightRP.inventory.attachPersonalTrunk(created, row.id, label(row))
        if not attached then return false, "Could not restore the trunk: " .. tostring(failure) end
        valid, reason = check(playerId, place)
        if not valid or identity(playerId) ~= owner(row) or not Open77.vehicles.get(created) then
            return false, reason or "Delivery was interrupted. Your vehicle remains owned."
        end
        local keys = LightRP.keys.give(created, playerId, { label = label(row), owner = true })
        if not keys then return false, "Could not hand over the vehicle keys." end
        capture(row)
        -- Out in the world: if the server stops before it is stored, it is towed.
        row.state = "out"
        if not persist(row) then LightRP.log("garage: %s is out but its state was not saved yet (retried)", row.id) end
        return true, label(row) .. " is parked outside. Press L to unlock it."
    end)
    place.busy = nil
    if not ran or not ok then
        if row.state == "out" then row.state, row.dirty = "stored", true end
        if created and Open77.vehicles.get(created) then
            row.removing = true
            local removed = Open77.vehicles.remove(created)
            row.removing = nil
            if not removed then
                -- Keep its live mapping when cleanup fails: NEVER offer a duplicate.
                LightRP.log("garage: delivery cleanup refused for %s / %s", row.id, tostring(created))
            else forgetLive(row) end
        elseif created then forgetLive(row) end
        if not ran then LightRP.log("garage retrieval failed: %s", tostring(ok)) end
        return false, ran and message or "Delivery failed. Contact staff if the vehicle remains outside."
    end
    return true, message
end

-- Trusted server API (dealerships.lua): drive a vehicle just bought out to a
-- delivery bay `{ name, position, heading, bucket }`, wherever the buyer stands:
-- locked, engine off, keys handed over. Refused (the vehicle stays stored at its
-- garage) when the bay is taken or the buyer already has a personal vehicle out.
-- Returns ok, text, vehicleId.
local bays = {}
local function ready(id)
    if not identity(id) then return false, "Finish loading your character first." end
    if (LightRP.characters.switching or {})[id] then return false, "Your character is changing. Please wait." end
    local life = Open77.players.getLifeState(id)
    if not life or life.phase ~= "alive" then return false, "You cannot collect a vehicle right now." end
    return true
end
function Garage.deliver(playerId, rowId, bay)
    local row, who = rows[rowId], identity(playerId)
    if not row or not who or owner(row) ~= who then return false, "This is not your character's vehicle." end
    if type(bay) ~= "table" or type(bay.position) ~= "table" then return false, "No delivery bay." end
    if ownerBusy[who] or row.busy then return false, "Another garage operation is running." end
    local place = bays[bay]
    if not place then
        place = { name = bay.name or "Delivery bay", bucket = bay.bucket or 0, position = bay.position,
            parking = { { position = bay.position, heading = bay.heading or 0 } } }
        bays[bay] = place
    end
    place.id = row.garage_id
    local op = {}; ownerBusy[who] = op; row.busy = true
    local ran, ok, message = pcall(retrieve, playerId, row, place, ready)
    row.busy = nil
    if ownerBusy[who] == op then ownerBusy[who] = nil end
    if not ran then LightRP.log("garage delivery failed: %s", tostring(ok)); return false, "Delivery failed. The vehicle remains owned." end
    return ok, message, ok and row.vehicleId or nil
end
function Garage.label(rowId) local row = rows[rowId]; return row and label(row) end
local function storeVehicle(playerId, row, place)
    local valid, reason = canStore(playerId, row, place)
    if not valid then return false, reason end
    local vehicleId = row.vehicleId
    local held, release = LightRP.inventory.preparePersonalParking(vehicleId)
    if not held then return false, "The trunk is busy or could not be saved. Try again shortly." end
    local previousGarage = row.garage_id
    local ran, ok, message = pcall(function()
        capture(row); row.garage_id, row.state, row.dirty = place.id, "stored", true
        if LightRP.fuel then LightRP.fuel.store(row.id, vehicleId) end -- tank level is not a vehicle property: kept by the fuel module
        local saved, why = persist(row)
        if not saved then return false, why end
        local allowed, failure = guard(playerId, place)
        if not allowed then return false, failure end
        allowed, failure = canStore(playerId, row, place)
        if not allowed then return false, failure end
        row.removing = true
        local removed = Open77.vehicles.remove(vehicleId)
        row.removing = nil
        if not removed then return false, "The vehicle could not be removed. It remains out." end
        forgetLive(row)
        return true, label(row) .. " has been stored at " .. place.name .. "."
    end)
    release()
    if not ran or not ok then
        -- If it was independently deleted during the write, recovery keeps the
        -- just-saved garage. Otherwise restore its previous recovery location.
        if row.vehicleId then row.garage_id, row.state, row.dirty = previousGarage, "out", true end
        if not ran then LightRP.log("garage parking failed: %s", tostring(ok)) end
        return false, ran and message or "Parking failed. Your ownership is unchanged."
    end
    return true, message
end

-- The owner sends their vehicle to the impound (stolen, lost, stuck): removed
-- from the world wherever it is, with its condition and trunk saved.
local function tow(row, reason)
    if row.state == "impound" then return false, "This vehicle is already at the impound." end
    if row.state ~= "out" and not row.vehicleId then return false, "This vehicle is in storage: collect it instead." end
    local vehicleId = row.vehicleId
    local present = vehicleId and Open77.vehicles.get(vehicleId)
    local release
    if present then
        capture(row)
        local held
        held, release = LightRP.inventory.preparePersonalParking(vehicleId)
        if not held then return false, "The trunk is busy or could not be saved. Try again shortly." end
        if LightRP.fuel then LightRP.fuel.store(row.id, vehicleId) end
    end
    local before = { state = row.state, reason = row.impound_reason, fee = row.impound_fee }
    local ran, ok, message = pcall(function()
        impound(row, reason)
        local saved, why = persist(row)
        if not saved then return false, why end
        if present and Open77.vehicles.get(vehicleId) then
            row.removing = true
            local removed = Open77.vehicles.remove(vehicleId)
            row.removing = nil
            if not removed then return false, "The vehicle could not be towed. It remains where it is." end
        end
        forgetLive(row)
        return true
    end)
    if release then release() end
    if not ran or not ok then
        if row.vehicleId then
            row.state, row.impound_reason, row.impound_fee, row.dirty = before.state, before.reason, before.fee, true
        end
        if not ran then LightRP.log("garage tow failed: %s", tostring(ok)) end
        return false, ran and message or "Towing failed. Your ownership is unchanged."
    end
    return true
end
local function sendToImpound(playerId, row, place)
    local ok, why = tow(row, "requested")
    if not ok then return false, why end
    row.notified = true
    local fee = row.impound_fee or 0
    return true, string.format("%s was towed to the impound. Recover it at any public garage%s.", label(row),
        fee > 0 and (" for " .. money(fee)) or ", free of charge")
end
-- Pay the fee at this garage: the vehicle is released into this garage, then
-- driven out to a free bay when possible.
local function recover(playerId, row, place, pay)
    if row.state ~= "impound" then return false, "This vehicle is not at the impound." end
    if row.invalid then return false, "This vehicle needs a storage check by staff. It has not been deleted." end
    local amount = row.impound_fee or 0
    local query = [[UPDATE lightrp_owned_vehicles SET state = 'stored', impound_reason = NULL, impound_fee = 0, garage_id = ?
        WHERE id = ? AND state = 'impound']]
    local values = { place.id, row.id }
    local function commit() row.state, row.impound_reason, row.impound_fee, row.garage_id = "stored", nil, 0, place.id end
    if amount > 0 then
        if pay ~= "cash" and pay ~= "bank" then return false, "Choose cash or bank to pay the impound fee." end
        local paid, failure = LightRP.money.exchange(playerId, pay, -amount, { query = query, values = values }, commit,
            "vehicle_impound", "Impound release: " .. label(row), IMPOUND.name or "Impound")
        if not paid then return false, LightRP.money.explain(failure) end
    else
        if not Db.run(query, values) then return false, "The impound could not release the vehicle. Try again shortly." end
        commit()
    end
    local released = amount > 0 and string.format("Impound fee paid (%s). ", money(amount)) or ""
    local out, text = retrieve(playerId, row, place)
    if out then return true, released .. text end
    return true, string.format("%s%s is released and stored here: %s", released, label(row), text)
end
-- Staff tow (badly parked, abandoned): /lightrp.impound <vehicle network id>.
function Garage.towLive(vehicleId, reason)
    local row = live[tonumber(vehicleId)]
    if not row then return false, "That vehicle is not a personal vehicle." end
    if row.busy then return false, "That vehicle is being saved. Try again shortly." end
    row.busy = true
    local ran, ok, why = pcall(tow, row, reason or "staff")
    row.busy = nil
    if not ran then return false, "Towing failed." end
    if not ok then return false, why end
    tellImpounded(row)
    return true, label(row) .. " was towed to the impound."
end
function Garage.state(rowId) local row = rows[rowId]; return row and row.state end

snapshot = function(playerId, session)
    local list, who = {}, identity(playerId)
    for _, row in pairs(rows) do
        if owner(row) == who then
            local v = row.vehicleId and Open77.vehicles.get(row.vehicleId)
            local entry = LightRP.vehicles.byKey[row.model]
            local parked = places[row.garage_id]
            local canPark, hint = false, nil
            if v then canPark, hint = canStore(playerId, row, session.place) end
            local status = row.state == "impound" and "impound" or (row.vehicleId or row.state == "out") and "out" or "stored"
            list[#list+1] = { id = row.id, key = row.model, label = label(row), category = entry and entry.category or "Vehicle",
                status = status, garageId = row.garage_id,
                garageName = parked and parked.name or row.garage_id, health = v and v.health or row.props and row.props.health or 1,
                canRetrieve = status == "stored" and not row.invalid and row.garage_id == session.place.id,
                canStore = canPark, canImpound = status == "out" and not row.invalid,
                canRecover = status == "impound" and not row.invalid,
                impound = status == "impound" and { reason = REASONS[row.impound_reason] or "Towed", fee = row.impound_fee or 0 } or nil,
                hint = row.invalid and "Storage record needs a staff check." or hint }
        end
    end
    table.sort(list, function(a,b) return a.label == b.label and a.id < b.id or a.label < b.label end)
    return { kind = "garage", session = session.id, nextRequest = session.nextRequest,
        spot = { id = session.place.id, name = session.place.name }, vehicles = list, maxOutside = C.maxOutside,
        impound = { name = IMPOUND.name or "Impound", fees = { requested = feeFor("requested"), lost = feeFor("lost"), restart = feeFor("restart") } } }
end
send = function(playerId, session, extra)
    if sessions[playerId] ~= session or identity(playerId) ~= session.owner then return end
    local response = extra or {}
    response.session, response.state = session.id, snapshot(playerId, session)
    TriggerClientEvent(E.net.garage, playerId, response)
end
function Garage.open(playerId, garageId)
    local place = places[garageId]
    local ok, why = guard(playerId, place)
    if not ok then return false, why end
    if Garage.isBusy(playerId) then return false, "Another garage operation is running." end
    sequence = sequence + 1
    local session = { id = "garage:" .. sequence .. ":" .. LightRP.nowMs(), place = place,
        owner = identity(playerId), nextRequest = 1, expires = LightRP.nowMs() + C.sessionMs }
    sessions[playerId] = session
    LightRP.dialog(playerId, "garage", snapshot(playerId, session))
    return true
end
function Garage.perform(playerId, payload)
    local session = sessions[playerId]
    if type(payload) ~= "table" or not session or session.id ~= payload.session then return false, "Reopen the garage." end
    if payload.type == "garage.close" then sessions[playerId] = nil; return true end
    if session.owner ~= identity(playerId) then sessions[playerId] = nil; return false, "Your character changed." end
    if session.last and payload.request == session.last.request and payload.type == session.last.action and payload.vehicle == session.last.vehicle then
        send(playerId, session, { request = payload.request, ok = session.last.ok, text = session.last.text }); return session.last.ok
    end
    if ownerBusy[session.owner] then return false, "Another garage operation is running." end
    local request = payload.request
    if type(request) ~= "number" or request ~= session.nextRequest or math.tointeger(request) == nil then
        send(playerId, session, { request = request, ok = false, text = "This request is out of date. Reopen the garage." }); return false
    end
    local valid, why = guard(playerId, session.place)
    if LightRP.nowMs() > session.expires then valid, why = false, "Garage session expired. Speak to the garage again." end
    local row = type(payload.vehicle) == "string" and rows[payload.vehicle]
    if not row or owner(row) ~= session.owner then valid, why = false, "This is not your character's vehicle." end
    if row and row.busy then valid, why = false, "This vehicle is being saved. Please try again shortly." end
    -- Only `pay` comes from the page, and only the recovery reads it.
    local handlers = {
        ["garage.retrieve"] = function(p, r, place) return retrieve(p, r, place) end,
        ["garage.store"] = function(p, r, place) return storeVehicle(p, r, place) end,
        ["garage.impound"] = function(p, r, place) return sendToImpound(p, r, place) end,
        ["garage.recover"] = recover,
    }
    local handler = handlers[payload.type]
    if not handler then valid, why = false, "Unknown garage action." end
    local op = {}; ownerBusy[session.owner] = op
    session.nextRequest = request + 1
    local ran, ok, message = true, false, why
    if valid then
        row.busy = true
        ran, ok, message = pcall(handler, playerId, row, session.place, payload.pay)
        row.busy = nil
    end
    if ownerBusy[session.owner] == op then ownerBusy[session.owner] = nil end
    if not ran then LightRP.log("garage operation failed: %s", tostring(ok)); ok, message = false, "Garage operation failed. Your vehicle remains owned." end
    session.last = { request = request, action = payload.type, vehicle = payload.vehicle, ok = ok, text = message }
    session.expires = LightRP.nowMs() + C.sessionMs
    send(playerId, session, { request = request, ok = ok, text = message })
    return ok, message
end
for _, action in ipairs({ "garage.retrieve", "garage.store", "garage.impound", "garage.recover", "garage.close" }) do
    LightRP.action(action, function(id, payload) Garage.perform(id, payload) end)
end
function Garage.onInteract(id, point)
    local name = point:match("^garage%.(.+)$")
    if name then local ok, why = Garage.open(id, name); if not ok then LightRP.result(id, false, why, "garage.open") end end
end
function Garage.onDisconnected(id) sessions[id] = nil end
function Garage.onCharacterLoaded(id)
    local session = sessions[id]
    if session then TriggerClientEvent(E.net.garage, id, { session = session.id, closed = true }) end
    sessions[id] = nil
end
function Garage.onLifeState(id, phase) if phase ~= "alive" then Garage.onCharacterLoaded(id) end end
-- In town again: the vehicles waiting at the impound since the last visit.
function Garage.onGameplayReady(id)
    local who = identity(id)
    if not who then return end
    for _, row in pairs(rows) do
        if owner(row) == who and row.state == "impound" then tellImpounded(row, id) end
    end
end
local function vanished(row, why)
    forgetLive(row)
    impound(row, "lost")
    LightRP.log("garage: %s towed to the impound after it left the world (%s)", row.id, tostring(why))
    tellImpounded(row)
end

AddEventHandler("onVehicleUpdated", function(id)
    local row = live[tonumber(id)]
    if row then capture(row) end
end)
AddEventHandler("onVehicleRemoved", function(id, reason)
    local row = live[tonumber(id)]
    if not row or row.removing then return end
    vanished(row, reason)
end)

for _, place in ipairs(C.garages) do
    assert(type(place.id) == "string" and not places[place.id] and #place.parking > 0, "Invalid public garage config")
    place.bucket = place.bucket or 0
    places[place.id] = place
    if C.enabled then LightRP.interaction("garage." .. place.id, { position = place.position, radius = C.interactRadius, bucket = place.bucket,
        label = place.name, prompt = "Open personal garage", key = "E", marker = C.marker, ring = false,
        blip = { icon = "warehouse", sprite = "Zzz01_CarForPurchaseVariant", title = "Public Garage", description = place.name .. "\nCollect or store your personal vehicles." } }) end
end
assert(places[C.defaultGarage], "Unknown default personal garage")

-- One worker: bounded/coalesced property writes, missed removal recovery and
-- automatic retry when SQL was temporarily down. Never respawn a world entity.
CreateThread(function()
    local elapsed = 0
    while true do
        Wait(2000); elapsed = elapsed + 2000
        if Db.ready and not loaded then Garage.onDatabaseReady() end
        for id, session in pairs(sessions) do
            if LightRP.nowMs() > session.expires or not guard(id, session.place) or identity(id) ~= session.owner then
                TriggerClientEvent(E.net.garage, id, { session = session.id, closed = true })
                sessions[id] = nil
            else send(id, session) end
        end
        if loaded and elapsed >= C.saveIntervalMs then
            elapsed = 0
            for _, row in pairs(rows) do
                if not row.busy and not row.invalid then
                    if row.vehicleId and not Open77.vehicles.get(row.vehicleId) then vanished(row, "missing") end
                    if row.vehicleId then capture(row) end
                    if row.dirty then row.busy = true; persist(row); row.busy = nil end
                end
            end
        end
    end
end)
LightRP.command("garage", {}, function(id)
    for _, place in pairs(places) do if guard(id, place) then return Garage.open(id, place.id) end end
    return false, "Walk to a Public Garage map marker, park nearby and step out."
end)
-- No argument: the closest personal vehicle within 8 m of the staff member.
LightRP.command("lightrp.impound", { restricted = true, usage = "/lightrp.impound [vehicle network id]" }, function(source, args)
    local vehicleId = tonumber(args[1])
    if not vehicleId then
        local here = Open77.players.position(source)
        local best = 8.0
        for id in pairs(live) do
            local v = Open77.vehicles.get(id)
            local d = v and here and (v.bucket or 0) == (here.bucket or 0) and distance(v.position, here)
            if d and d < best then vehicleId, best = id, d end
        end
        if not vehicleId then return false, "No personal vehicle within 8 m. Give its network id." end
    end
    return Garage.towLive(vehicleId, "staff")
end)
LightRP.command("lightrp.givevehicle", { restricted = true, usage = "/lightrp.givevehicle <id|me> <model> [garage]" }, function(id, args)
    local target = args[1] == "me" and id or tonumber(args[1])
    if not target or not GetPlayerName(target) or not args[2] then return false end
    local ok, result = Garage.grant(target, args[2], args[3])
    return ok, ok and ("Personal vehicle granted: " .. result) or result
end)
