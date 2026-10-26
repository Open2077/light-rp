-- The starter studio: every character who finishes the first day guide is
-- given a unit of the same interior (LightRpHousing.starter), behind one shared
-- street door, each unit in its own bucket like any dwelling. The units are
-- ordinary housing rows flagged `starter` with an "assigned" contract: keys,
-- lock, storage, wardrobe, release and /housingadmin all work as for the rest.
local H, S, Db, C = LightRP.housing, LightRP.housingStore, LightRP.db, LightRpHousing
local cfg = C.starter
local Starter = LightRP.module("housingStarter", {})
H.starter = Starter

local function enabled() return cfg ~= nil and cfg.enabled == true end

-- The interior is written once; afterwards the administrators' captures win.
function Starter.onDatabaseReady()
    if not enabled() or not S.loaded then return end
    local t = S.templates[cfg.templateId]
    if t and not t.deleted then return end
    local points = {}
    for name, p in pairs(cfg.points) do points[name] = S.point(p) end
    local row = { id = cfg.templateId, revision = t and t.revision + 1 or 1, deleted = false,
        data = { label = cfg.label, slots = cfg.slots, weight = cfg.weight, points = points } }
    if not Db.transaction({ S.templateWrite(row, t == nil), S.audit("system", "housing.starter.template", row.id, cfg.label) }) then
        LightRP.log("housing: the starter studio template could not be saved")
        return
    end
    S.templates[row.id] = row
    H.refreshPoints()
    LightRP.log("housing: starter studio template \"%s\" created", cfg.label)
end

-- The character's current starter unit, if any.
function Starter.home(c)
    if not c then return nil end
    for _, lease in pairs(S.contracts) do
        if S.active(lease) and S.owns(lease, c) then
            local row = S.properties[lease.property_id]
            if row and not row.deleted and row.data.starter and row.contract_id == lease.id then return row, lease end
        end
    end
end

-- Gives the character a unit (a vacant one first) unless they hold one already.
function Starter.grant(player)
    if not enabled() then return nil, "Starter homes are disabled." end
    if not H.available() then return nil, "Housing storage is unavailable." end
    local c = S.identity(player)
    if not c then return nil, "Load an active character first." end
    local owned = Starter.home(c)
    if owned then return owned end
    local t = S.templates[cfg.templateId]
    if not S.templateReady(t) then return nil, "The starter studio is not set up." end
    return H.withWrite({ player }, function()
        local unit, count = nil, 0
        for _, row in pairs(S.properties) do
            if row.data.starter and not row.deleted then
                count = count + 1
                if not row.contract_id and row.data.enabled and row.data.templateId == t.id and (not unit or row.id < unit.id) then unit = row end
            end
        end
        local insert = unit == nil
        if insert then
            if count >= (cfg.maxUnits or 4000) then return nil, "No starter studio is left. Ask the staff." end
            local id = S.nextId
            unit = { id = id, revision = 0, deleted = false, data = { label = string.format("%s %04d", cfg.label, id),
                kind = "apartment", templateId = t.id, price = 0, rent = 0, rentDays = C.rentDays, enabled = true,
                entrance = S.point(cfg.entrance), starter = true } }
        end
        local leaseId = S.uuid()
        if not leaseId or LightRP.characters.get(player) ~= c then return nil, "Your studio could not be prepared. Please retry." end
        local lease = { id = leaseId, property_id = unit.id, identifier = c.identifier, character_key = c.key, ended_at = 0,
            data = { mode = "assigned", name = LightRP.characters.displayName(player), paid = 0, started = math.floor(GetUnixTime()),
                keys = {}, locked = true, label = unit.data.label, entrance = S.clone(unit.data.entrance),
                slots = t.data.slots, weight = t.data.weight, starter = true } }
        local updated = S.clone(unit)
        updated.contract_id, updated.revision = leaseId, unit.revision + 1
        local writes = { S.propertyWrite(updated, insert), S.contractWrite(lease, true),
            S.audit(GetPlayerIdentifier(player), "housing.starter", unit.id, c.identifier .. "#" .. c.key) }
        if not Db.transaction(writes) then return nil, "Your studio could not be saved. Nothing changed." end
        if insert then S.nextId = unit.id + 1 end
        S.properties[unit.id], S.contracts[leaseId] = updated, lease
        H.refreshPoints()
        LightRP.inventory.refreshHousingAccess()
        H.syncHomes()
        LightRP.log("housing: %s received %s", LightRP.characters.displayName(player), unit.data.label)
        return updated
    end)
end

-- Gives the studio and takes the character inside it.
function Starter.moveIn(player)
    local row, why = Starter.grant(player)
    if not row then return nil, why end
    return H.moveIn(player, row)
end
