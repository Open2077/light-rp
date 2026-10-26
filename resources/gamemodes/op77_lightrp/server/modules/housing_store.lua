-- Durable housing records. Retired contracts keep their storage and exterior
-- recovery point; deleting a dwelling never deletes a character's belongings.
local Db, C = LightRP.db, LightRpHousing
local Store = { templates = {}, properties = {}, contracts = {}, loaded = false, nextId = 1 }
LightRP.housingStore = Store

-- Template ids are slugs (lightrp-starter-kabuki-studio) as well as UUIDs: VARCHAR,
-- never CHAR(36), which the server's MySQL driver reads back as a GUID and refuses
-- for anything that is not one (the whole housing load then failed).
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_housing_templates (
 id VARCHAR(64) NOT NULL PRIMARY KEY, definition MEDIUMTEXT NOT NULL,
 revision INT NOT NULL DEFAULT 1, deleted TINYINT NOT NULL DEFAULT 0,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_housing_properties (
 id INT NOT NULL PRIMARY KEY, definition MEDIUMTEXT NOT NULL,
 contract_id CHAR(36) NULL, revision INT NOT NULL DEFAULT 1,
 deleted TINYINT NOT NULL DEFAULT 0,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_housing_contracts (
 id CHAR(36) NOT NULL PRIMARY KEY, property_id INT NOT NULL,
 identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
 definition MEDIUMTEXT NOT NULL, ended_at BIGINT NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX housing_owner (identifier, character_key), INDEX housing_property (property_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_housing_audit (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
 actor VARCHAR(128) NOT NULL, action VARCHAR(48) NOT NULL,
 target VARCHAR(64) NOT NULL, detail VARCHAR(500) NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

function Store.clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Store.clone(v) end
    return result
end
function Store.integer(value, low, high)
    local n = tonumber(value)
    return n and n == n and n % 1 == 0 and n >= low and n <= high and n or nil
end
function Store.text(value, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    local length=utf8.len(value)
    return length and length > 0 and length <= max and not value:find("%c") and value or nil
end
function Store.point(value)
    if type(value) ~= "table" then return nil end
    for _, k in ipairs({ "x", "y", "z" }) do
        local n = value[k]
        if type(n) ~= "number" or n ~= n or math.abs(n) > 100000 then return nil end
    end
    local heading = tonumber(value.heading) or 0
    if heading ~= heading or math.abs(heading) == math.huge then return nil end
    return { x = value.x, y = value.y, z = value.z, heading = heading % 360 }
end
function Store.distance(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function Store.uuid()
    local ok, rows = Db.read("SELECT UUID() AS id")
    return ok and rows[1] and rows[1].id or nil
end
function Store.identity(player)
    local c = LightRP.characters.get(player)
    if not c or c.status ~= "active" or not c.identifier then return nil end
    return c
end
function Store.owns(contract, character)
    return contract and character and contract.identifier == character.identifier and contract.character_key == character.key or false
end
function Store.active(contract)
    return contract and contract.ended_at == 0 and (contract.data.mode ~= "rent" or contract.data.expires > GetUnixTime()) or false
end
function Store.templateReady(template)
    if not template or template.deleted then return false end
    local points = template.data.points
    return points and Store.point(points.spawn) ~= nil and Store.point(points.exit) ~= nil and Store.point(points.stash) ~= nil
end
function Store.audit(actor, action, target, detail)
    detail=tostring(detail or "")
    local boundary=utf8.offset(detail,501)
    if boundary then detail=detail:sub(1,boundary-1) end
    return { query = "INSERT INTO lightrp_housing_audit (actor,action,target,detail) VALUES (?,?,?,?)",
        values = { tostring(actor or "system"), action, tostring(target), detail } }
end
function Store.propertyWrite(row, insert)
    if insert then
        return { query = "INSERT INTO lightrp_housing_properties (id,definition,contract_id,revision,deleted) VALUES (?,?,NULLIF(?,''),?,?)",
            values = { row.id, json.encode(row.data), row.contract_id or "", row.revision, row.deleted and 1 or 0 } }
    end
    return { query = "UPDATE lightrp_housing_properties SET definition=?,contract_id=NULLIF(?,''),revision=?,deleted=? WHERE id=?",
        values = { json.encode(row.data), row.contract_id or "", row.revision, row.deleted and 1 or 0, row.id } }
end
function Store.templateWrite(row, insert)
    if insert then
        return { query = "INSERT INTO lightrp_housing_templates (id,definition,revision,deleted) VALUES (?,?,?,?)",
            values = { row.id, json.encode(row.data), row.revision, row.deleted and 1 or 0 } }
    end
    return { query = "UPDATE lightrp_housing_templates SET definition=?,revision=?,deleted=? WHERE id=?",
        values = { json.encode(row.data), row.revision, row.deleted and 1 or 0, row.id } }
end
function Store.contractWrite(row, insert)
    if insert then
        return { query = "INSERT INTO lightrp_housing_contracts (id,property_id,identifier,character_key,definition,ended_at) VALUES (?,?,?,?,?,?)",
            values = { row.id, row.property_id, row.identifier, row.character_key, json.encode(row.data), row.ended_at } }
    end
    return { query = "UPDATE lightrp_housing_contracts SET definition=?,ended_at=? WHERE id=?",
        values = { json.encode(row.data), row.ended_at, row.id } }
end

local function readAll(tableName)
    local rows, offset = {}, 0
    while true do
        local ok, batch = Db.read("SELECT * FROM " .. tableName .. " ORDER BY id LIMIT 500 OFFSET " .. offset)
        if not ok then return nil end
        for _, row in ipairs(batch) do rows[#rows+1] = row end
        if #batch < 500 then return rows end
        offset = offset + #batch
    end
end
local function decode(row)
    local ok, data = pcall(json.decode, row.definition)
    if not ok or type(data) ~= "table" then error("Invalid housing record " .. tostring(row.id)) end
    row.data, row.definition = data, nil
    if row.revision then row.revision = assert(Store.integer(row.revision,1,2147483647)) end
    if row.deleted ~= nil then row.deleted = tonumber(row.deleted) == 1 end
    return row
end
-- Tables created before template ids became VARCHAR (see the schema above).
local function migrate()
    local column = Db.single([[SELECT DATA_TYPE AS t FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_housing_templates' AND COLUMN_NAME = 'id']])
    if column and tostring(column.t):lower() == "char" then
        if Db.run("ALTER TABLE lightrp_housing_templates MODIFY id VARCHAR(64) NOT NULL") then
            LightRP.log("migrated: lightrp_housing_templates.id is VARCHAR(64)")
        end
    end
end
function Store.load()
    Store.loaded = false
    migrate()
    local templates, properties, contracts = {}, {}, {}
    local a, b, c = readAll("lightrp_housing_templates"), readAll("lightrp_housing_properties"), readAll("lightrp_housing_contracts")
    if not a or not b or not c then return false, "Housing storage could not be read." end
    local ok, why = pcall(function()
        for _, row in ipairs(a) do
            decode(row)
            assert(Store.text(row.data.label,80) and type(row.data.points)=="table", "Invalid template")
            assert(Store.integer(row.data.slots,1,200) and Store.integer(row.data.weight,1,10000), "Invalid storage")
            for _, point in pairs(row.data.points) do assert(Store.point(point),"Invalid interior point") end
            templates[row.id] = row
        end
        local nextId = 1
        for _, row in ipairs(b) do
            decode(row); row.id = assert(Store.integer(row.id,1,C.maxProperties * 10000))
            assert(Store.text(row.data.label,80) and Store.point(row.data.entrance), "Invalid property")
            assert(type(row.data.enabled)=="boolean" and (row.data.kind=="apartment" or row.data.kind=="house"),"Invalid dwelling status")
            assert(templates[row.data.templateId], "Missing interior template")
            assert(Store.integer(row.data.price,0,1000000000) and Store.integer(row.data.rent,0,1000000000)
                and Store.integer(row.data.rentDays,1,90), "Invalid housing price")
            properties[row.id] = row; nextId = math.max(nextId,row.id+1)
        end
        for _, row in ipairs(c) do
            decode(row); row.property_id = tonumber(row.property_id); row.ended_at = tonumber(row.ended_at)
            assert(properties[row.property_id] and Store.integer(row.ended_at,0,9007199254740991) and Store.text(row.identifier,128)
                and Store.text(row.character_key,64), "Invalid housing owner")
            assert(row.data.mode=="rent" or row.data.mode=="purchase" or row.data.mode=="assigned", "Invalid housing contract")
            assert(row.data.mode~="rent" or Store.integer(row.data.expires,1,9007199254740991), "Invalid rental expiry")
            assert(Store.point(row.data.entrance) and type(row.data.keys)=="table", "Invalid housing recovery record")
            assert(Store.text(row.data.label,80) and Store.integer(row.data.slots,1,200) and Store.integer(row.data.weight,1,10000)
                and Store.integer(row.data.paid,0,1000000000) and type(row.data.locked)=="boolean", "Invalid tenancy storage or payment")
            for _,key in ipairs(row.data.keys) do
                assert(Store.text(key.identifier,128) and Store.text(key.key,64) and Store.text(key.name,96), "Invalid spare key")
            end
            if row.ended_at==0 then assert(properties[row.property_id].contract_id==row.id,"Orphan active tenancy") end
            contracts[row.id] = row
        end
        for _, row in pairs(properties) do
            if row.contract_id and row.contract_id~="" then
                local contract=contracts[row.contract_id]
                assert(contract and contract.property_id==row.id and contract.ended_at==0, "Invalid active tenancy")
            else row.contract_id=nil end
        end
        Store.templates, Store.properties, Store.contracts, Store.nextId = templates, properties, contracts, nextId
    end)
    if not ok then return false, tostring(why) end
    Store.loaded = true
    return true
end
