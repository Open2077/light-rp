-- Durable ownership is separate from a live network entity. SQL never stores a
-- runtime vehicle ID: after a process restart every owned car is parked again.
local C, Db, E = LightRpGarages, LightRP.db, LightRpEvents
local Garage = LightRP.module("garage", {})
local rows, live, places, sessions, ownerBusy = {}, {}, {}, {}, {}
local loaded, sequence = false, 0
local send, snapshot
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_owned_vehicles (
    id CHAR(36) NOT NULL PRIMARY KEY,
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
    model VARCHAR(48) NOT NULL, record VARCHAR(192) NOT NULL,
    garage_id VARCHAR(48) NOT NULL, properties MEDIUMTEXT NOT NULL,
    grant_key VARCHAR(128) NOT NULL UNIQUE,
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
    local ok = Db.run("UPDATE lightrp_owned_vehicles SET garage_id = ?, properties = ? WHERE id = ?",
        { row.garage_id, encoded, row.id })
    if ok and rev == row.revision then row.dirty = false end
    return ok, ok and nil or "Vehicle storage could not be saved. No second vehicle will be created."
end
local function forgetLive(row)
    if row.vehicleId then live[row.vehicleId] = nil end
    row.vehicleId = nil
end

function Garage.onDatabaseReady()
    if loaded or not C.enabled then return end
    local ok, stored = Db.read("SELECT * FROM lightrp_owned_vehicles")
    if not ok then LightRP.log("garage: ownership load failed; garage stays closed") return end
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
        rows[row.id] = row
    end
    loaded = true
    LightRP.log("garage: %d ownership record(s) restored to storage", #stored)
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
            model = entry.key, record = entry.record, garage_id = place.id, props = {}, grant_key = grantKey or result[1].id }
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
        if identity(playerId) == who then
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

local function retrieve(playerId, row, place)
    if row.vehicleId then return false, "This vehicle is already out. Bring it back to a garage." end
    if row.invalid then return false, "This vehicle needs a storage check by staff. It has not been deleted." end
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
        local valid, reason = guard(playerId, place)
        if not valid or identity(playerId) ~= owner(row) then return false, reason or "Your character changed." end
        if not clearSpace(place, slot) then return false, "The pickup bay became occupied." end
        created, reason = Open77.vehicles.create({ record = row.record, appearance = row.props.appearance,
            position = slot.position, yaw = slot.heading or 0, bucket = place.bucket,
            persistent = true, despawnWhenUnobserved = false })
        if not created then return false, "Vehicle delivery failed: " .. tostring(reason) end
        row.vehicleId, live[created] = created, row
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
        valid, reason = guard(playerId, place)
        if not valid or identity(playerId) ~= owner(row) or not Open77.vehicles.get(created) then
            return false, reason or "Delivery was interrupted. Your vehicle remains owned."
        end
        local keys = LightRP.keys.give(created, playerId, { label = label(row), owner = true })
        if not keys then return false, "Could not hand over the vehicle keys." end
        capture(row)
        return true, label(row) .. " is parked outside. Press L to unlock it."
    end)
    place.busy = nil
    if not ran or not ok then
        if created and Open77.vehicles.get(created) then
            if not Open77.vehicles.remove(created) then
                -- Keep its live mapping when cleanup fails: NEVER offer a duplicate.
                LightRP.log("garage: delivery cleanup refused for %s / %s", row.id, tostring(created))
            else forgetLive(row) end
        elseif created then forgetLive(row) end
        if not ran then LightRP.log("garage retrieval failed: %s", tostring(ok)) end
        return false, ran and message or "Delivery failed. Contact staff if the vehicle remains outside."
    end
    return true, message
end

local function storeVehicle(playerId, row, place)
    local valid, reason = canStore(playerId, row, place)
    if not valid then return false, reason end
    local vehicleId = row.vehicleId
    local held, release = LightRP.inventory.preparePersonalParking(vehicleId)
    if not held then return false, "The trunk is busy or could not be saved. Try again shortly." end
    local previousGarage = row.garage_id
    local ran, ok, message = pcall(function()
        capture(row); row.garage_id, row.dirty = place.id, true
        if LightRP.fuel then LightRP.fuel.store(row.id, vehicleId) end -- tank level is not a vehicle property: kept by the fuel module
        local saved, why = persist(row)
        if not saved then return false, why end
        local allowed, failure = guard(playerId, place)
        if not allowed then return false, failure end
        allowed, failure = canStore(playerId, row, place)
        if not allowed then return false, failure end
        if not Open77.vehicles.remove(vehicleId) then return false, "The vehicle could not be removed. It remains out." end
        forgetLive(row)
        return true, label(row) .. " has been stored at " .. place.name .. "."
    end)
    release()
    if not ran or not ok then
        -- If it was independently deleted during the write, recovery keeps the
        -- just-saved garage. Otherwise restore its previous recovery location.
        if row.vehicleId then row.garage_id, row.dirty = previousGarage, true end
        if not ran then LightRP.log("garage parking failed: %s", tostring(ok)) end
        return false, ran and message or "Parking failed. Your ownership is unchanged."
    end
    return true, message
end

snapshot = function(playerId, session)
    local list, who = {}, identity(playerId)
    for _, row in pairs(rows) do
        if owner(row) == who then
            local v = row.vehicleId and Open77.vehicles.get(row.vehicleId)
            local entry = LightRP.vehicles.byKey[row.model]
            local parked = places[row.garage_id]
            local canPark, hint = false, nil
            if v then canPark, hint = canStore(playerId, row, session.place) end
            list[#list+1] = { id = row.id, key = row.model, label = label(row), category = entry and entry.category or "Vehicle",
                status = row.vehicleId and "out" or "stored", garageId = row.garage_id,
                garageName = parked and parked.name or row.garage_id, health = v and v.health or row.props and row.props.health or 1,
                canRetrieve = not row.vehicleId and not row.invalid and row.garage_id == session.place.id,
                canStore = canPark, hint = row.invalid and "Storage record needs a staff check." or hint }
        end
    end
    table.sort(list, function(a,b) return a.label == b.label and a.id < b.id or a.label < b.label end)
    return { kind = "garage", session = session.id, nextRequest = session.nextRequest,
        spot = { id = session.place.id, name = session.place.name }, vehicles = list, maxOutside = C.maxOutside }
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
    if payload.type ~= "garage.retrieve" and payload.type ~= "garage.store" then valid, why = false, "Unknown garage action." end
    local op = {}; ownerBusy[session.owner] = op
    session.nextRequest = request + 1
    local ran, ok, message = true, false, why
    if valid then
        row.busy = true
        ran, ok, message = pcall(payload.type == "garage.retrieve" and retrieve or storeVehicle, playerId, row, session.place)
        row.busy = nil
    end
    if ownerBusy[session.owner] == op then ownerBusy[session.owner] = nil end
    if not ran then LightRP.log("garage operation failed: %s", tostring(ok)); ok, message = false, "Garage operation failed. Your vehicle remains owned." end
    session.last = { request = request, action = payload.type, vehicle = payload.vehicle, ok = ok, text = message }
    session.expires = LightRP.nowMs() + C.sessionMs
    send(playerId, session, { request = request, ok = ok, text = message })
    return ok, message
end
for _, action in ipairs({ "garage.retrieve", "garage.store", "garage.close" }) do
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

AddEventHandler("onVehicleUpdated", function(id)
    local row = live[tonumber(id)]
    if row then capture(row) end
end)
AddEventHandler("onVehicleRemoved", function(id, reason)
    local row = live[tonumber(id)]
    if not row then return end
    forgetLive(row); row.dirty = true
    LightRP.log("garage: %s returned to %s after removal (%s)", row.id, row.garage_id, tostring(reason))
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
                    if row.vehicleId and not Open77.vehicles.get(row.vehicleId) then forgetLive(row); row.dirty = true end
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
LightRP.command("lightrp.givevehicle", { restricted = true, usage = "/lightrp.givevehicle <id|me> <model> [garage]" }, function(id, args)
    local target = args[1] == "me" and id or tonumber(args[1])
    if not target or not GetPlayerName(target) or not args[2] then return false end
    local ok, result = Garage.grant(target, args[2], args[3])
    return ok, ok and ("Personal vehicle granted: " .. result) or result
end)
