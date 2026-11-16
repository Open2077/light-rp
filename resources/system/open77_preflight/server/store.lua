-- Who accepted the rules, and which version of them.
--
-- Kept in the resource's key/value store (Open77.kvp: one JSON file under this
-- resource's data folder, no permission needed), so it survives restarts. One key per
-- player would stop at the store's 4,096 entries; instead the accepted ids of the
-- CURRENT rules version are packed into 256 buckets by the first two hex digits of the
-- id, which holds about 30,000 players inside the store's 1 MiB. Changing
-- rules.version drops every bucket: everybody is asked again.

PreflightStore = {}

local kvp = Open77.kvp
local version = "1"
-- Acceptances the store refused to keep (quota): remembered until the resource restarts.
local volatile = {}
local warned = false

local function compact(userId)
    local id = tostring(userId or ""):lower():gsub("[^0-9a-f]", "")
    if #id ~= 32 then return nil end
    return id
end

local function bucketKey(id)
    return "rules:" .. version .. ":" .. id:sub(1, 2)
end

-- Sets the rules version in force. A different one than last time forgets every acceptance.
function PreflightStore.setVersion(value)
    version = tostring(value or "1"):gsub("[^%w%._%-]", "_"):sub(1, 32)
    if version == "" then version = "1" end
    local previous = kvp.get("rules:version")
    if previous ~= version then
        local removed = kvp.clear("rules:")
        kvp.set("rules:version", version)
        volatile = {}
        if previous ~= nil then
            print(("rules version %s -> %s: %s stored acceptance bucket(s) cleared, everybody is asked again")
                :format(tostring(previous), version, tostring(removed)))
        end
    end
    return version
end

function PreflightStore.version() return version end

function PreflightStore.accepted(userId)
    local id = compact(userId)
    if not id then return false end
    if volatile[id] then return true end
    local bucket = kvp.get(bucketKey(id), "")
    return type(bucket) == "string" and bucket:find(id .. ";", 1, true) ~= nil
end

function PreflightStore.accept(userId)
    local id = compact(userId)
    if not id then return false end
    if PreflightStore.accepted(userId) then return true end
    local key = bucketKey(id)
    local bucket = kvp.get(key, "")
    if type(bucket) ~= "string" then bucket = "" end
    local ok, reason = kvp.set(key, bucket .. id .. ";")
    if not ok then
        volatile[id] = true
        if not warned then
            warned = true
            print("rules acceptance could not be stored (" .. tostring(reason) ..
                "); it is remembered until this resource restarts")
        end
    end
    return true
end

-- Forgets one player's acceptance, or everybody's when userId is nil. Returns how many were forgotten.
function PreflightStore.reset(userId)
    if userId == nil then
        volatile = {}
        local removed = kvp.clear("rules:" .. version .. ":")
        return type(removed) == "number" and removed or 0
    end
    local id = compact(userId)
    if not id then return 0 end
    local had = PreflightStore.accepted(userId)
    volatile[id] = nil
    local key = bucketKey(id)
    local bucket = kvp.get(key, "")
    if type(bucket) == "string" and bucket ~= "" then
        local start, finish = bucket:find(id .. ";", 1, true)
        if start then kvp.set(key, bucket:sub(1, start - 1) .. bucket:sub(finish + 1)) end
    end
    return had and 1 or 0
end

-- A small setting that outlives restarts (the live maintenance switch, live announcements).
function PreflightStore.get(key, default) return kvp.get("state:" .. key, default) end
function PreflightStore.set(key, value)
    if value == nil then return kvp.delete("state:" .. key) end
    return kvp.set("state:" .. key, value)
end
