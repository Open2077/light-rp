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
local customizationPlaces = {} -- trusted workshop configuration, separate from storage garages
local edits = {} -- player -> leased owned vehicle; Auto Studio previews are never durable
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
    if LightRP.activities and not LightRP.activities.allows(id, "vehicles") then return false, "Not during an activity." end
    local life, p = Open77.players.getLifeState(id), Open77.players.position(id)
    if not life or life.phase ~= "alive" then return false, "You cannot use the garage right now." end
    if not place or not p or (p.bucket or 0) ~= place.bucket or distance(p, place.position) > (place.interactRadius or C.interactRadius) + 0.75 then
        return false, "Walk up to the garage or workshop marker."
    end
    if Open77.vehicles.getPlayerSeat(id) then return false, "Park nearby and step out of the vehicle first." end
    return true
end
function Garage.isBusy(id)
    local key = identity(id)
    return edits[id] ~= nil or (key and ownerBusy[key] ~= nil or false)
end
function Garage.ownedId(vehicleId)
    local row = live[tonumber(vehicleId)]
    return row and row.id
end
local function label(row)
    local entry = LightRP.vehicles.byKey[row.model]
    return entry and entry.label or row.model
end
-- Auto Studio (customization service below) ------------------------------------
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k,v in pairs(value) do out[k] = copy(v) end; return out
end
local function look(value) return type(value) == "string" and value or "" end -- "" = the record's own appearance
-- Kit parts are declared by the customization module under this resource's namespace
-- (server/config/vehicle_kit.lua): the category of a full part id, "rims" | "body" | nil.
local NS = (type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp") .. ":"
local function kitKind(id)
    local kit = LightRpVehicleKit
    if type(kit) ~= "table" or type(id) ~= "string" or id:sub(1, #NS) ~= NS then return nil end
    local name = id:sub(#NS + 1)
    if kit.rims and kit.rims.parts and kit.rims.parts[name] then return "rims" end
    if kit.body and kit.body.parts and kit.body.parts[name] then return "body" end
end
Garage.kitKind = kitKind
-- One field of `visual` (getProperties' open77.visual view). A car without any visual
-- state keeps no `visual` key: older servers refuse it in setProperties.
local function visualKey(to, from, key)
    local value = type(from.visual) == "table" and from.visual[key] or nil
    if value == nil and type(to.visual) ~= "table" then return end
    to.visual = type(to.visual) == "table" and to.visual or {}
    to.visual[key] = copy(value)
end
-- The kit parts of one category inside `visual.parts`; parts of other resources stay.
local function visualParts(to, from, kind)
    local source = type(from.visual) == "table" and from.visual.parts or {}
    local any = false
    for id in pairs(source) do if kitKind(id) == kind then any = true; break end end
    if not any and type(to.visual) ~= "table" then return end
    to.visual = type(to.visual) == "table" and to.visual or {}
    local parts = {}
    for id, value in pairs(to.visual.parts or {}) do if kitKind(id) ~= kind then parts[id] = value end end
    for id, value in pairs(source) do if kitKind(id) == kind then parts[id] = copy(value) end end
    to.visual.parts = parts
end
-- Light RP's own stored fields (plate, performance stage): never sent to setProperties.
local function own(to) to.lightrp = type(to.lightrp) == "table" and to.lightrp or {}; return to.lightrp end
-- The confirmed-property mask: the getProperties() fields each Auto Studio category
-- owns. While a lease is open, every write (autosave, removal, close, disconnect, the
-- purchase of ANOTHER category) takes these fields from the last confirmed state,
-- never from a preview. Paint and lights share the engine's one visual template, so
-- both live in `paint`; the trim is the entity appearance variant; livery, neon, rims,
-- body kit and window tint live in `visual`; plate and stage in Light RP's `lightrp`.
local OWNS = {
    paint = function(to, from)
        local src = from.paint or { applied = false }
        to.paint = to.paint or {}
        to.paint.applied, to.paint.primary, to.paint.secondary = src.applied, copy(src.primary), copy(src.secondary)
    end,
    lights = function(to, from)
        to.paint = to.paint or { applied = false }
        to.paint.lightsHue = from.paint and from.paint.lightsHue
    end,
    trim = function(to, from) to.appearance = from.appearance end,
    livery = function(to, from) visualKey(to, from, "profile") end,
    neon = function(to, from) visualKey(to, from, "neon") end,
    windows = function(to, from) visualKey(to, from, "tint") end,
    rims = function(to, from) visualParts(to, from, "rims"); visualKey(to, from, "wheels") end,
    body = function(to, from) visualParts(to, from, "body") end,
    plate = function(to, from) own(to).plate = type(from.lightrp) == "table" and from.lightrp.plate or nil end,
    performance = function(to, from) own(to).stage = type(from.lightrp) == "table" and from.lightrp.stage or nil end,
}
-- Generic paint replaces a TwinTone livery and a livery goes on the factory paint layer:
-- a purchase (or a rollback) of one is a purchase (or a rollback) of both.
local LINKED = { paint = { "paint", "livery" }, livery = { "livery", "paint" } }
local function linked(category) return LINKED[category] or { category } end
-- Categories stored only by Light RP: the purchased value comes from the lease, not the car.
local STORED = { plate = true, performance = true }
local function maskConfirmed(props, confirmed, except)
    local skip = {}
    for _, category in ipairs(except and linked(except) or {}) do skip[category] = true end
    for category, take in pairs(OWNS) do if not skip[category] then take(props, confirmed) end end
    return props
end
-- Stored choices this car cannot wear right now (a part dropped from the catalogue, a
-- server without visual support): kept in the row until the owner buys that category again.
local DORMANT = {
    livery = function(d) d.profile = nil end, neon = function(d) d.neon = nil end, windows = function(d) d.tint = nil end,
    rims = function(d) d.wheels = nil; for id in pairs(d.parts or {}) do if kitKind(id) == "rims" then d.parts[id] = nil end end end,
    body = function(d) for id in pairs(d.parts or {}) do if kitKind(id) == "body" then d.parts[id] = nil end end end,
}
local function wake(props, dormant)
    props.visual = type(props.visual) == "table" and props.visual or {}
    local v = props.visual
    v.parts = type(v.parts) == "table" and v.parts or {}
    for id, value in pairs(dormant.parts or {}) do if v.parts[id] == nil then v.parts[id] = copy(value) end end
    for _, key in ipairs({ "wheels", "profile", "neon", "tint" }) do
        if dormant[key] ~= nil and v[key] == nil then v[key] = copy(dormant[key]) end
    end
end
local function capture(row)
    if not row.vehicleId then return end
    local props = Open77.vehicles.getProperties(row.vehicleId)
    if type(props) == "table" then
        props = copy(props)
        props.lightrp = copy(type(row.props) == "table" and row.props.lightrp or nil)
        -- Autosaves and removal recovery keep the last confirmed look, never a preview.
        if row.edit then props = maskConfirmed(props, row.edit.saved) end
        if row.dormant then wake(props, row.dormant) end
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
    destroyed = "Wrecked, insurance excess",
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
-- A wreck: what the code can really tell (docs/economy-balance.md, fourrière). The live
-- canonical record (destroyed / exploded flags, health 0), the damage event seen while
-- it was out (row.wrecked), or the last captured properties. A removal with none of
-- those (deleted, cleaned up, lost to a bug) is "lost", the smaller fee.
local function bit(value, mask) return mask > 0 and (math.floor(value / mask) % 2) == 1 end
local function wrecked(row)
    local v = row.vehicleId and Open77.vehicles.get(row.vehicleId)
    if type(v) == "table" then
        local flags = Open77.vehicles.flags or { destroyed = 4, exploded = 8 }
        local bits = math.floor(tonumber(v.flags) or 0)
        if v.destroyed or v.exploded or bit(bits, flags.destroyed or 4) or bit(bits, flags.exploded or 8) then return true end
        if tonumber(v.health) and tonumber(v.health) <= 0 then return true end
    end
    if row.wrecked then return true end
    local p = row.props
    if type(p) ~= "table" then return false end
    if type(p.damage) == "table" and (p.damage.destroyed == true or p.damage.exploded == true) then return true end
    return tonumber(p.health) ~= nil and tonumber(p.health) <= 0
end
Garage.wrecked = wrecked
-- The insurance puts a written-off car back on its wheels: the stored properties keep
-- their shape (appearance, paint) with the damage zeroed.
local function insuranceRepair(props)
    if type(props) ~= "table" then return end
    props.health = 1
    if props.drivable ~= nil then props.drivable = true end
    local d = props.damage
    if type(d) ~= "table" then return end
    if type(d.body) == "table" then local body = {}; for i = 1, #d.body do body[i] = 0 end; d.body = body end
    for _, key in ipairs({ "glass", "lights", "tires", "detachedParts" }) do
        if type(d[key]) == "number" then d[key] = 0 elseif type(d[key]) == "table" then d[key] = {} end
    end
    d.destroyed, d.exploded = false, false
end
Garage.insuranceRepair = insuranceRepair
local function impound(row, reason)
    if reason == "destroyed" then insuranceRepair(row.props) end
    row.state, row.impound_reason, row.impound_fee = "impound", reason, feeFor(reason)
    row.dirty, row.notified, row.wrecked = true, nil, nil
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
            impound(row, wrecked(row) and "destroyed" or "restart"); towed = towed + 1
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
function Garage.closeVisit(id) sessions[id] = nil end
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
    if v.bucket ~= place.bucket or distance(v.position, place.position) > (place.storeRadius or C.storeRadius) then
        return false, "Bring your vehicle into the garage area first."
    end
    if (v.speed or 0) > C.stationarySpeed then return false, "Stop the vehicle before parking it." end
    if wrecked(row) then return false, "This vehicle is a wreck: send it to the impound, the insurance repairs it." end
    if #(v.occupants or {}) > 0 then return false, "Everyone must leave the vehicle before it can be stored." end
    if identity(playerId) ~= owner(row) then return false, "This is not your character's vehicle." end
    return true
end

-- Trusted customization service. Durable IDs and ownership stay inside the garage.
local RECEIPTS = { -- ledger kind (VARCHAR 24) and note, per category
    paint = { "vehicle_paint", "Body paint for vehicle " },
    lights = { "vehicle_lights", "Light tint for vehicle " },
    trim = { "vehicle_trim", "Factory trim for vehicle " },
    livery = { "vehicle_livery", "Livery for vehicle " },
    rims = { "vehicle_rims", "Rims for vehicle " },
    body = { "vehicle_bodykit", "Body kit for vehicle " },
    neon = { "vehicle_neon", "Neon for vehicle " },
    windows = { "vehicle_tint", "Window tint for vehicle " },
    plate = { "vehicle_plate", "Registration plate for vehicle " },
    performance = { "vehicle_stage", "Performance stage for vehicle " },
}
-- Native refusals a player can act on.
local REFUSALS = {
    vehicle_occupied = "Everyone must step out of the vehicle first.",
    attach_limit = "Too many parts on this vehicle: remove one first.",
    visual_too_large = "Too many parts on this vehicle: remove one first.",
    part_not_for_model = "This part does not fit this vehicle.",
    unknown_part = "This part is not available on this server right now.",
    invalid_profile = "This livery does not exist for this vehicle.",
    invalid_plate = "This plate cannot be shown on a vehicle.",
}
local function explain(why, fallback) return REFUSALS[why] or fallback end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
-- The registration plate on the car. The text is validated, unique and stored here;
-- `Open77.vehicles.setPlate` puts it on the car for every client (contract section 7,
-- `visual.plate`; respawnAs keeps it), and the `lightrpPlate` state bag key mirrors it
-- for Light RP's own UI. A server build without setPlate keeps the data side only.
-- Returning false fails a preview / rollback.
local function renderPlate(vehicleId, plate)
    if type(plate) ~= "string" or plate == "" then plate = nil end
    if type(Open77.state) == "table" and type(Open77.state.entity) == "function" then
        pcall(function() Open77.state.entity("vehicle", vehicleId):set("lightrpPlate", plate) end)
    end
    local setPlate = Open77.vehicles.setPlate
    if type(setPlate) ~= "function" then return true end
    local ok, why = setPlate(vehicleId, plate)
    if not ok then return false, explain(why, "The plate could not be fitted (" .. tostring(why) .. ").") end
    return true
end
-- Performance stages: record of `stage` for a row, from the stage resolver the
-- customization module registers (nil while the stage records are offline).
local stageResolver
function Garage.setStageResolver(fn) stageResolver = fn end
local function stageRecord(row, stage)
    stage = math.tointeger(tonumber(stage) or 0) or 0
    if stage <= 0 then return row.record end
    return stageResolver and stageResolver(row.record, stage) or nil
end
local function liveRecord(id)
    local v = Open77.vehicles.get(id)
    if type(v) == "table" and v.record then return v.record end
    local props = Open77.vehicles.getProperties(id)
    return type(props) == "table" and props.record or nil
end
-- Rebuilds the car on `record` (same id, same place, every look and key carried over).
local function applyStage(id, record)
    if not record or liveRecord(id) == record then return true end
    if type(Open77.vehicles.respawnAs) ~= "function" then return false, "This server build cannot fit performance stages." end
    local result, why = Open77.vehicles.respawnAs(id, record)
    if not result then return false, explain(why, "The stage could not be fitted (" .. tostring(why) .. ").") end
    if tonumber(result) ~= tonumber(id) then LightRP.log("garage: respawnAs moved %s to a new id %s", tostring(id), tostring(result)) end
    return true
end
local function neonSpec(neon)
    return { enabled = neon.enabled ~= false, color = neon.color, intensity = neon.intensity, radius = neon.radius }
end
-- Puts the visual categories (livery, neon, window tint, rims, body kit) of `state` on the car,
-- touching only what differs. Light RP's body parts only: other resources' stay.
local function applyVisual(id, state)
    local V = Open77.vehicles
    if type(V.getVisual) ~= "function" then return true end
    local want = type(state.visual) == "table" and state.visual or {}
    local have = V.getVisual(id)
    if type(have) ~= "table" then return false, "Could not read the vehicle's look." end
    local ok, why = true, nil
    if have.profile ~= want.profile then ok, why = V.setPaintProfile(id, want.profile) end
    if ok and not same(have.neon, want.neon) then
        if type(want.neon) == "table" then ok, why = V.setNeon(id, neonSpec(want.neon)) else ok, why = V.clearNeon(id) end
    end
    if ok and have.tint ~= want.tint and type(V.setWindowTint) == "function" then ok, why = V.setWindowTint(id, want.tint) end
    if ok and not same(have.wheels, want.wheels) then
        ok, why = V.setWheels(id, type(want.wheels) == "table" and { rim = want.wheels.rim, variant = want.wheels.variant } or nil)
    end
    if ok then
        local change, wanted, held = {}, want.parts or {}, have.parts or {}
        for part in pairs(held) do if kitKind(part) == "body" and wanted[part] == nil then change[part] = false end end
        for part, value in pairs(wanted) do if kitKind(part) == "body" and not same(held[part], value) then change[part] = value end end
        if next(change) then ok, why = V.setParts(id, change) end
    end
    if not ok then return false, explain(why, "The vehicle's look was refused (" .. tostring(why) .. ").") end
    return true
end
local function colorKey(value)
    if type(value) == "string" then return value:upper() end
    if type(value) == "table" then return string.format("#%02X%02X%02X", value.r, value.g, value.b) end
end
local function sameHue(a, b)
    if a == nil or b == nil then return a == b end
    local d = math.abs(a - b) % 1
    return math.min(d, 1 - d) < 0.0005
end
-- True when the car already wears `paint` (the applied bit, and the colours when applied).
local function wearsPaint(id, paint)
    local have = type(Open77.vehicles.getPaint) == "function" and Open77.vehicles.getPaint(id) or nil
    if type(have) ~= "table" or (have.applied == true) ~= (paint.applied == true) then return false end
    return not paint.applied or (colorKey(have.primary) == colorKey(paint.primary) and colorKey(have.secondary) == colorKey(paint.secondary))
end
-- `restore`: put a known look back (close, rollback), writing only what moved. The server's
-- setPaint and resetPaint clear a TwinTone livery even when the paint does not change, so a
-- blind re-paint made every viewer see the livery drop and come back, and a livery whose pack
-- stopped could then not be put back at all (invalid_profile): the lease never closed.
local function applyPaint(id, paint, restore)
    local ok, why = true, nil
    if not (restore and wearsPaint(id, paint)) then
        if paint.applied then ok, why = Open77.vehicles.setPaint(id, { primary = paint.primary, secondary = paint.secondary })
        else ok, why = Open77.vehicles.resetPaint(id) end
    end
    if not ok then return false, why or "Vehicle paint was refused." end
    if restore and type(Open77.vehicles.getLightsHue) == "function" and sameHue(Open77.vehicles.getLightsHue(id), paint.lightsHue) then
        return true
    end
    return Open77.vehicles.setLightsHue(id, paint.lightsHue)
end
-- setAppearance only when the variant really changes: a restatement would reschedule
-- the entity appearance on every viewer for nothing.
local function applyTrim(id, appearance)
    if look(appearance) == look(Open77.vehicles.getAppearance(id)) then return true end
    local ok, why = Open77.vehicles.setAppearance(id, look(appearance) ~= "" and appearance or nil)
    if not ok then return false, why or "Vehicle trim was refused." end
    return true
end
-- Puts a complete look back on the car: paint and lights hue, trim, then the visual
-- categories (a repaint clears the livery, so the livery comes after), the plate and
-- the performance stage of `row`.
local function applyLook(id, state, row)
    local ok, why = applyPaint(id, state.paint or { applied = false }, true)
    if not ok then return false, why end
    ok, why = applyTrim(id, state.appearance)
    if not ok then return false, why end
    ok, why = applyVisual(id, state)
    if not ok then return false, why end
    local stored = type(state.lightrp) == "table" and state.lightrp or {}
    ok, why = renderPlate(id, stored.plate)
    if not ok then return false, why end
    if row then return applyStage(id, stageRecord(row, stored.stage)) end
    return true
end
local function editGuard(playerId, row)
    local edit = row and row.edit
    if not edit or edit.player ~= playerId or identity(playerId) ~= owner(row) then return false, "Your vehicle session changed." end
    local ok, why = guard(playerId, edit.place)
    if not ok then return false, why end
    if row.vehicleId ~= edit.vehicleId then return false, "The vehicle is no longer outside." end
    return canStore(playerId, row, edit.place)
end
function Garage.registerCustomizationLocation(place)
    assert(type(place.id) == "string" and type(place.position) == "table" and not places[place.id]
        and not customizationPlaces[place.id], "Invalid workshop location")
    customizationPlaces[place.id] = place
end
function Garage.customizationCandidate(playerId, placeId)
    local place = customizationPlaces[placeId]
    local ok, why = guard(playerId, place)
    if not ok then return nil, why end
    local nearest, range = nil, place.storeRadius
    for _, row in pairs(rows) do
        if owner(row) == identity(playerId) and row.vehicleId then
            local v = Open77.vehicles.get(row.vehicleId)
            local d = v and v.bucket == place.bucket and distance(v.position, place.position) or math.huge
            if d <= range then nearest, range = row.id, d end
        end
    end
    return nearest, nearest and nil or "Park your personal vehicle within 6 m of the workshop point and step out."
end
function Garage.beginCustomization(playerId, ownedId, token, garageId)
    local row, place = rows[ownedId], customizationPlaces[garageId] or places[garageId]
    local ok, why = guard(playerId, place)
    if not ok then return nil, why end
    if not row or owner(row) ~= identity(playerId) then return nil, "This is not your character's vehicle." end
    if row.busy or row.edit or Garage.isBusy(playerId) then return nil, "Another vehicle operation is running." end
    ok, why = canStore(playerId, row, place)
    if not ok then return nil, why end
    local props = Open77.vehicles.getProperties(row.vehicleId)
    if not props then return nil, "Could not read vehicle properties." end
    -- saved: the confirmed look (what the SQL row holds); shown: what the car wears now.
    local saved = { paint = copy(props.paint or { applied = false }), appearance = props.appearance,
        visual = copy(props.visual), lightrp = copy(type(row.props) == "table" and row.props.lightrp or nil) or {} }
    row.edit = { player = playerId, token = token, place = place, vehicleId = row.vehicleId, saved = saved, shown = copy(saved) }
    edits[playerId] = row
    return { id = row.id, vehicleId = row.vehicleId, label = label(row), model = row.model, record = row.record,
        paint = copy(saved.paint), lightsHue = saved.paint.lightsHue, appearance = look(saved.appearance),
        visual = copy(saved.visual), lightrp = copy(saved.lightrp) }
end
function Garage.customizationValid(playerId, token)
    local row = edits[playerId]
    if not row or row.edit.token ~= token or row.edit.closeRequested then return false, "Reopen vehicle customization." end
    return editGuard(playerId, row)
end
function Garage.endCustomization(playerId, token)
    local row = edits[playerId]
    if not row or row.edit.token ~= token then return true end
    if row.busy then row.edit.closeRequested = true; return false end
    local edit = row.edit
    if Open77.vehicles.get(edit.vehicleId) then
        local ok, why = applyLook(edit.vehicleId, edit.saved, row)
        if not ok then
            -- Keep the lease so periodic cleanup retries instead of persisting a preview.
            edit.closeRequested = true
            LightRP.log("customization restore pending: %s", tostring(why)); return false
        end
    end
    row.edit, edits[playerId] = nil, nil
    capture(row)
    return true
end
local function samePaint(a,b)
    if a.applied ~= b.applied then return false end
    return not a.applied or (colorKey(a.primary) == colorKey(b.primary) and colorKey(a.secondary) == colorKey(b.secondary))
end
function Garage.customizationPaint(playerId, token)
    local row = edits[playerId]
    if row and row.edit.token == token then return copy(row.edit.saved.paint) end
end
-- The confirmed look of every category, for the page.
function Garage.customizationState(playerId, token)
    local row = edits[playerId]
    if not row or row.edit.token ~= token then return nil end
    local saved = row.edit.saved
    return { paint = copy(saved.paint), lightsHue = saved.paint.lightsHue, appearance = look(saved.appearance),
        visual = copy(saved.visual), lightrp = copy(saved.lightrp) }
end
-- Plates are unique across every owned vehicle, held ones included while a purchase
-- is being written. `plate` is already normalized (upper case).
local platesHeld = {}
function Garage.plateTaken(plate, exceptRowId)
    if type(plate) ~= "string" or plate == "" then return false end
    if platesHeld[plate] and platesHeld[plate] ~= exceptRowId then return true end
    for id, row in pairs(rows) do
        local stored = type(row.props) == "table" and type(row.props.lightrp) == "table" and row.props.lightrp.plate
        if id ~= exceptRowId and type(stored) == "string" and stored:upper() == plate then return true end
    end
    return false
end
local function plateOfRow(row)
    local stored = row and type(row.props) == "table" and type(row.props.lightrp) == "table" and row.props.lightrp.plate
    return type(stored) == "string" and stored ~= "" and stored or nil
end
-- The registration plate of a live personal vehicle (vehicle menu, staff tools), or nil.
function Garage.plateOf(vehicleId) return plateOfRow(live[tonumber(vehicleId)]) end
-- One category's change on top of what the car wears now; `edit.shown` follows.
local function applyChange(edit, change)
    local id, V = edit.vehicleId, Open77.vehicles
    local function readBack(category)
        local visual = V.getVisual(id)
        if type(visual) ~= "table" then return false, "Could not read the vehicle's look." end
        OWNS[category](edit.shown, { visual = visual })
        return true
    end
    if change.category == "paint" then
        local target = copy(change.paint); target.lightsHue = edit.shown.paint and edit.shown.paint.lightsHue
        local ok, why = applyPaint(id, target)
        if not ok then return false, why end
        OWNS.paint(edit.shown, { paint = target })
        OWNS.livery(edit.shown, {}) -- the server cleared any livery (generic paint replaces it)
    elseif change.category == "livery" then
        -- A scheme goes on the factory paint layer (lights hue kept); the profile last,
        -- since a repaint clears it.
        if change.profile ~= "" then
            local base = { applied = false, lightsHue = edit.shown.paint and edit.shown.paint.lightsHue }
            local ok, why = applyPaint(id, base)
            if not ok then return false, why end
            OWNS.paint(edit.shown, { paint = base })
        end
        local ok, why = V.setPaintProfile(id, change.profile ~= "" and change.profile or nil)
        if not ok then return false, explain(why, "The livery was refused.") end
        OWNS.livery(edit.shown, { visual = { profile = change.profile ~= "" and change.profile or nil } })
    elseif change.category == "neon" then
        local ok, why
        if change.neon then ok, why = V.setNeon(id, neonSpec(change.neon)) else ok, why = V.clearNeon(id) end
        if not ok then return false, explain(why, "The neon was refused.") end
        return readBack("neon")
    elseif change.category == "windows" then
        local ok, why = V.setWindowTint(id, change.tint or nil)
        if not ok then return false, explain(why, "The window tint was refused.") end
        return readBack("windows")
    elseif change.category == "rims" then
        local ok, why = V.setWheels(id, change.rim ~= "" and { rim = change.rim, variant = change.variant } or nil)
        if not ok then return false, explain(why, "These rims were refused.") end
        return readBack("rims")
    elseif change.category == "body" then
        local ok, why = V.setParts(id, change.parts)
        if not ok then return false, explain(why, "This body kit was refused.") end
        return readBack("body")
    elseif change.category == "plate" then
        local ok, why = renderPlate(id, change.plate)
        if not ok then return false, why or "The plate could not be fitted." end
        own(edit.shown).plate = change.plate
    elseif change.category == "performance" then
        local ok, why = applyStage(id, change.record)
        if not ok then return false, why end
        own(edit.shown).stage = change.stage
    elseif change.category == "lights" then
        local ok, why
        if change.color then ok, why = V.setHeadlightColor(id, change.color) else ok, why = V.clearLightsHue(id) end
        if not ok then return false, why or "The light tint was refused." end
        -- the engine keeps one hue: read back the value it actually stored
        OWNS.lights(edit.shown, { paint = { lightsHue = change.color and V.getLightsHue(id) or nil } })
    elseif change.category == "trim" then
        local ok, why = applyTrim(id, change.appearance)
        if not ok then return false, why end
        OWNS.trim(edit.shown, { appearance = change.appearance })
    else return false, "Unknown customization category." end
    return true
end
-- Unchanged purchases are refused per category (`saved` is the confirmed look).
local function savedVisual(saved) return type(saved.visual) == "table" and saved.visual or {} end
local function neonKey(neon)
    if type(neon) ~= "table" or neon.enabled == false then return "off" end
    local color = neon.color
    if type(color) == "table" then color = string.format("#%02X%02X%02X", color.r or 0, color.g or 0, color.b or 0) end
    return tostring(color):upper() .. "@" .. tostring(math.floor((tonumber(neon.intensity) or 600) + 0.5))
end
local UNCHANGED = {
    paint = function(change, saved) return samePaint(change.paint, saved.paint), "Choose a different finish before purchasing." end,
    lights = function(change, saved) return not change.color and saved.paint.lightsHue == nil, "Choose a different light color before purchasing." end,
    trim = function(change, saved) return look(change.appearance) == look(saved.appearance), "Choose a different trim before purchasing." end,
    livery = function(change, saved) return change.profile == (savedVisual(saved).profile or ""), "Choose a different livery before purchasing." end,
    neon = function(change, saved) return neonKey(change.neon) == neonKey(savedVisual(saved).neon), "Choose a different neon before purchasing." end,
    windows = function(change, saved) return (change.tint or nil) == savedVisual(saved).tint, "Choose a different window tint before purchasing." end,
    rims = function(change, saved)
        local held = savedVisual(saved).wheels
        if change.rim == "" then return held == nil, "These are already the factory rims." end
        return type(held) == "table" and held.rim == change.rim and (held.variant or "") == (change.variant or ""), "Choose different rims before purchasing."
    end,
    body = function(change, saved)
        local held = savedVisual(saved).parts or {}
        for part, value in pairs(change.parts) do
            if (value == false and held[part] ~= nil) or (value ~= false and not same(held[part], value)) then return false end
        end
        return true, "Change at least one body part before purchasing."
    end,
    plate = function(change, saved) return change.plate == (saved.lightrp or {}).plate, "This vehicle already wears that plate." end,
    performance = function(change, saved) return change.stage == ((saved.lightrp or {}).stage or 0), "This stage is already fitted." end,
}
-- Trusted callers only (server/modules/vehicle_customization.lua validators): `change` is
-- { category = "paint", paint = {...} } | { category = "lights", color = "#RRGGBB"|nil } |
-- { category = "trim", appearance = name|"" } | { category = "livery", profile = id|"" } |
-- { category = "neon", neon = { color, intensity, radius }|false } | { category = "windows", tint = 1..3|false } |
-- { category = "rims", rim = fullId|"", variant } | { category = "body", parts = { [fullId] = variant|false } } |
-- { category = "plate", plate = text } | { category = "performance", stage = n, record = name },
-- already validated against the shared tables; `payment` carries the server quote.
function Garage.customize(playerId, token, change, commit, payment)
    local row = edits[playerId]
    local valid, why = Garage.customizationValid(playerId, token)
    if not valid then return false, why end
    if type(change) ~= "table" or not OWNS[change.category] then return false, "Unknown customization category." end
    if row.busy or ownerBusy[owner(row)] then return false, "Vehicle save is still running." end
    local edit, key, operation, category = row.edit, owner(row), {}, change.category
    if commit then
        if not payment or (payment.method ~= "cash" and payment.method ~= "bank")
            or not LightRP.money or not LightRP.money.validAmount(payment.amount) then return false, "Choose a valid payment method." end
        local unchanged, text = UNCHANGED[category](change, edit.saved)
        if unchanged then return false, text end
        if category == "plate" and Garage.plateTaken(change.plate, row.id) then return false, "This plate is already registered to another vehicle." end
    end
    row.busy, ownerBusy[key] = true, operation
    local held
    local ran, ok, reason = pcall(function()
        local applied, failure = applyChange(edit, change)
        if not applied then return false, failure end
        if not commit then return true end
        local hue = edit.shown.paint.lightsHue
        if category == "lights" and change.color and type(hue) == "number" and sameHue(hue, edit.saved.paint.lightsHue) then
            return false, "Choose a different light color before purchasing."
        end
        local props = Open77.vehicles.getProperties(edit.vehicleId)
        if not props then return false, "Could not read the vehicle." end
        -- Only the purchased category leaves the preview: every other field is confirmed.
        props = maskConfirmed(copy(props), edit.saved, category)
        if STORED[category] then OWNS[category](props, edit.shown) end
        if row.dormant then
            local dormant = copy(row.dormant)
            for _, c in ipairs(linked(category)) do if DORMANT[c] then DORMANT[c](dormant) end end
            wake(props, dormant)
        end
        -- Save the complete canonical properties before acknowledging success.
        local encoded = json.encode(props)
        if not encoded then return false, "Could not encode vehicle properties." end
        -- A vehicle out of the impound has no garage yet: the bridge refuses nil parameters.
        local write = row.garage_id ~= nil
            and { query = "UPDATE lightrp_owned_vehicles SET garage_id = ?, properties = ? WHERE id = ?",
                  values = { row.garage_id, encoded, row.id } }
            or { query = "UPDATE lightrp_owned_vehicles SET properties = ? WHERE id = ?", values = { encoded, row.id } }
        if category == "plate" then held = change.plate; platesHeld[held] = row.id end
        local receipt = RECEIPTS[category]
        local saved, failure = LightRP.money.exchange(playerId, payment.method, -payment.amount, write,
            function()
                for _, c in ipairs(linked(category)) do
                    OWNS[c](edit.saved, props)
                    OWNS[c](row.props, props) -- removal during SQL cannot overwrite the purchase
                    if row.dormant and DORMANT[c] then DORMANT[c](row.dormant) end
                end
                row.dirty = true
            end, receipt[1], receipt[2] .. row.id, "Auto Studio")
        if not saved then return false, LightRP.money.explain(failure) end
        return true
    end)
    if held and platesHeld[held] == row.id then platesHeld[held] = nil end
    if not ran or not ok then
        -- The failed category goes back to its confirmed value; other previews stay.
        for _, c in ipairs(linked(category)) do OWNS[c](edit.shown, edit.saved) end
        local restored, failure = applyLook(edit.vehicleId, edit.shown, row)
        if not restored then edit.closeRequested = true; LightRP.log("customization rollback pending: %s", tostring(failure)) end
    end
    capture(row) -- also captures damage received during an asynchronous SQL write
    row.busy = nil
    if ownerBusy[key] == operation then ownerBusy[key] = nil end
    if edit.closeRequested then Garage.endCustomization(playerId, token) end
    return ran and ok == true, ran and reason or "Vehicle customization failed."
end
function Garage.customizePaint(playerId, token, paint, commit, payment)
    return Garage.customize(playerId, token, { category = "paint", paint = paint }, commit, payment)
end

-- The stored properties as setProperties takes them on a fresh car of `record`: no
-- `lightrp` (Light RP's own fields), the spawned record, and only the visual choices
-- this server can put on it; the others are kept dormant on the row.
local function restorable(row, record)
    local props, restore = row.props, {}
    for key, value in pairs(props) do if key ~= "lightrp" then restore[key] = value end end
    if restore.record ~= nil then restore.record = record end
    if type(props.paint) == "table" and props.paint.applied == false then
        -- On shipped hosts, sending colour channels also enables paint,
        -- even when applied=false was saved. A fresh spawn already has
        -- its original livery: do not accidentally repaint it black.
        restore.paint = {}; for key, value in pairs(props.paint) do
            if key ~= "primary" and key ~= "secondary" then restore.paint[key] = value end
        end
    end
    row.dormant = nil
    local visual = restore.visual
    if type(visual) ~= "table" then restore.visual = nil; return restore end
    local V = Open77.vehicles
    if type(V.getVisual) ~= "function" or type(V.listParts) ~= "function" then
        row.dormant, restore.visual = copy(visual), nil -- a server without visual support
        return restore
    end
    local known, dormant, keep = {}, {}, copy(visual)
    for _, part in ipairs(V.listParts(record) or {}) do known[part.id] = part end
    keep.parts = {}
    for id, value in pairs(type(visual.parts) == "table" and visual.parts or {}) do
        local part = known[id]
        if part and (value == true or (type(part.variants) == "table" and part.variants[value] ~= nil)) then keep.parts[id] = copy(value)
        else dormant.parts = dormant.parts or {}; dormant.parts[id] = copy(value) end
    end
    if type(visual.wheels) == "table" and keep.parts[visual.wheels.rim] == nil then dormant.wheels, keep.wheels = copy(visual.wheels), nil end
    if visual.profile ~= nil and type(V.listPaintProfiles) == "function" then
        local offered = false
        for _, profile in ipairs(V.listPaintProfiles(record) or {}) do if profile.id == visual.profile then offered = true end end
        if not offered then dormant.profile, keep.profile = visual.profile, nil end
    end
    if next(dormant) then
        row.dormant = dormant
        LightRP.log("garage: %s keeps visual choices this server cannot put on it dormant", row.id)
    end
    restore.visual = keep
    return restore
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
        -- A performance stage spawns its stage record; while the stage records are offline
        -- the car comes out stock and keeps its stage stored (dormant).
        local stored = type(row.props.lightrp) == "table" and row.props.lightrp or {}
        local record = stageRecord(row, stored.stage)
        if not record then
            record = row.record
            LightRP.log("garage: %s keeps stage %s dormant (stage records offline)", row.id, tostring(stored.stage))
        end
        created, reason = Open77.vehicles.create({ record = record, appearance = row.props.appearance,
            position = slot.position, yaw = slot.heading or 0, bucket = place.bucket,
            persistent = true, despawnWhenUnobserved = false })
        if not created then return false, "Vehicle delivery failed: " .. tostring(reason) end
        row.vehicleId, live[created] = created, row
        tag(created, row.id)
        local restore = restorable(row, record)
        if next(restore) ~= nil then
            local applied, err = Open77.vehicles.setProperties(created, restore)
            if not applied and restore.visual ~= nil then
                -- Never refuse a delivery over the look: the car comes out without its
                -- visual choices, which stay stored until it can wear them again.
                LightRP.log("garage: %s delivered without its visual (%s); kept dormant", row.id, tostring(err))
                row.dormant = copy(type(row.props.visual) == "table" and row.props.visual or {})
                restore.visual = nil
                applied, err = Open77.vehicles.setProperties(created, restore)
            end
            if not applied then return false, "Could not restore this vehicle: " .. tostring(err) end
        end
        renderPlate(created, stored.plate)
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
    -- The owner sending a wreck pays the insurance excess; a staff tow keeps its own fee.
    if reason == "requested" and wrecked(row) then reason = "destroyed" end
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
                wrecked = status == "out" and wrecked(row) or nil,
                canRecover = status == "impound" and not row.invalid,
                impound = status == "impound" and { reason = REASONS[row.impound_reason] or "Towed", fee = row.impound_fee or 0 } or nil,
                plate = plateOfRow(row), stage = type(row.props) == "table" and type(row.props.lightrp) == "table"
                    and math.tointeger(tonumber(row.props.lightrp.stage) or 0) or 0,
                hint = row.invalid and "Storage record needs a staff check." or hint }
        end
    end
    table.sort(list, function(a,b) return a.label == b.label and a.id < b.id or a.label < b.label end)
    return { kind = "garage", session = session.id, nextRequest = session.nextRequest,
        spot = { id = session.place.id, name = session.place.name }, vehicles = list, maxOutside = C.maxOutside,
        impound = { name = IMPOUND.name or "Impound", fees = { requested = feeFor("requested"), destroyed = feeFor("destroyed"), lost = feeFor("lost"), restart = feeFor("restart") } } }
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
    if row and (row.busy or row.edit) then valid, why = false, "This vehicle is being saved. Please try again shortly." end
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
    local reason = wrecked(row) and "destroyed" or "lost"
    forgetLive(row)
    impound(row, reason)
    LightRP.log("garage: %s towed to the impound after it left the world (%s)", row.id, tostring(why))
    tellImpounded(row)
end

AddEventHandler("onVehicleUpdated", function(id)
    local row = live[tonumber(id)]
    if row then capture(row) end
end)
-- Remember a wreck at once: the entity may be cleaned up before the next autosave.
AddEventHandler("onVehicleDamageChanged", function(id)
    local row = live[tonumber(id)]
    if row and not row.wrecked and wrecked(row) then row.wrecked = true end
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
        for id, row in pairs(edits) do
            if row.edit.closeRequested or not editGuard(id, row) then Garage.endCustomization(id, row.edit.token) end
        end
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
