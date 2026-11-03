-- Staff mission editor: storage of the authored missions and the editor protocol
-- (page <-> client <-> here, net event op77_lightrp:missioneditor, the same
-- request/response shape as the safezone editor). Published missions run through
-- server/modules/mission_engine.lua; this module only stores and validates.
--
-- ACL: command.lightrp.missions (staff roles already hold command.lightrp.*).
-- /lightrp.missions opens the editor.
local D, Db = LightRpMissionDefs, LightRP.db
local Engine = LightRP.missionEngine
local Editor = LightRP.module("missionEditor", { records = {}, ready = false })
local NET = "op77_lightrp:missioneditor"
local PERMISSION = "command.lightrp.missions"

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_defs (
 id VARCHAR(64) NOT NULL PRIMARY KEY, definition MEDIUMTEXT NOT NULL,
 revision INT NOT NULL, deleted TINYINT NOT NULL DEFAULT 0, author VARCHAR(128) NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local lastRequest, done = {}, {}   -- done[actor][mutation] = result (idempotent retries)
local function now() return Open77.time.monotonic() end

function Editor.allowed(player)
    if not player or player <= 0 or type(Open77.acl) ~= "table" or type(Open77.acl.isAllowed) ~= "function" then return false end
    local ok, value = pcall(Open77.acl.isAllowed, player, PERMISSION)
    return ok and value == true
end
local function actor(player)
    local a = GetPlayerIdentifier(player)
    if type(a) ~= "string" or #a == 0 or #a > 128 then return nil end
    return a
end

function Editor.list()
    local list = {}
    for _, d in pairs(Editor.records) do if not d.deleted then list[#list + 1] = D.clone(d) end end
    table.sort(list, function(a, b) return a.title == b.title and a.id < b.id or a.title < b.title end)
    return list
end

function Editor.load()
    local ok, rows = Db.read("SELECT id,definition,revision,deleted FROM lightrp_mission_defs")
    if not ok then return false, "Mission storage is unavailable." end
    local records, count = {}, 0
    for _, row in ipairs(rows) do
        local decoded, data = pcall(json.decode, row.definition)
        local def, why
        if decoded then def, why = D.validate(data) end
        if not def or def.id ~= row.id then
            LightRP.log("mission editor: stored mission %s ignored (%s)", tostring(row.id), tostring(why or "id mismatch"))
        else
            def.revision, def.deleted = tonumber(row.revision) or 1, tonumber(row.deleted) == 1
            records[def.id] = def
            if not def.deleted then count = count + 1 end
        end
    end
    Editor.records, Editor.ready = records, true
    for _, def in pairs(records) do if not def.deleted then Engine.publish(def) end end
    LightRP.log("mission editor: %d authored mission(s) loaded", count)
    return true
end
function Editor.onDatabaseReady()
    local ok, why = Editor.load()
    if not ok then LightRP.log("mission editor: %s", tostring(why)) end
end

local function persist(player, def, baseRevision, deleted)
    local old = Editor.records[def.id]
    def.revision = (old and old.revision or 0) + 1
    local stored = D.clone(def)
    stored.revision, stored.deleted = nil, nil
    local ok, result
    if old then
        ok, result = Db.run("UPDATE lightrp_mission_defs SET definition=?,revision=?,deleted=?,author=? WHERE id=? AND revision=?",
            { json.encode(stored), def.revision, deleted and 1 or 0, actor(player), def.id, baseRevision })
        local affected = type(result) == "table" and (result.affectedRows or result.changedRows) or result
        if ok and tonumber(affected) == 0 then return nil, "This mission changed meanwhile. Refresh before publishing." end
    else
        ok = Db.run("INSERT INTO lightrp_mission_defs (id,definition,revision,deleted,author) VALUES (?,?,?,0,?)",
            { def.id, json.encode(stored), def.revision, actor(player) })
    end
    if not ok then return nil, "Mission storage refused the change. Nothing was published." end
    def.deleted = deleted
    Editor.records[def.id] = def
    return def
end

local function publish(player, p)
    if not Editor.ready or not Db.ready then return nil, "Mission storage is unavailable. Nothing was published." end
    local def, why = D.validate(p.mission)
    if not def then return nil, why end
    local old = def.id and Editor.records[def.id]
    if def.id and (not old or old.deleted) then return nil, "This mission no longer exists. Refresh the list." end
    if old and old.revision ~= p.baseRevision then return nil, "This mission changed meanwhile. Refresh before publishing." end
    if not old then
        local count = 0
        for _, d in pairs(Editor.records) do if not d.deleted then count = count + 1 end end
        if count >= D.MAX_MISSIONS then return nil, "The server mission limit has been reached." end
        local ok, rows = Db.read("SELECT UUID() AS id")
        if not ok or not rows[1] or type(rows[1].id) ~= "string" then return nil, "Could not allocate a mission ID." end
        def.id = rows[1].id
    end
    local saved, err = persist(player, def, p.baseRevision, false)
    if not saved then return nil, err end
    Engine.publish(saved)
    LightRP.log("mission editor: %s published %s (%s, revision %d)", GetPlayerName(player) or tostring(player), saved.title, saved.id, saved.revision)
    return { mission = D.clone(saved) }
end

local function remove(player, p)
    if not Editor.ready or not Db.ready then return nil, "Mission storage is unavailable." end
    local old = type(p.id) == "string" and Editor.records[p.id]
    if not old or old.deleted then return nil, "This mission no longer exists." end
    if old.revision ~= p.baseRevision then return nil, "This mission changed meanwhile. Refresh first." end
    local def = D.clone(old)
    local saved, err = persist(player, def, p.baseRevision, true)
    if not saved then return nil, err end
    Engine.withdraw(saved.id)
    LightRP.log("mission editor: %s deleted %s (%s)", GetPlayerName(player) or tostring(player), saved.title, saved.id)
    return { id = saved.id }
end

local function test(player, p)
    local def = type(p.id) == "string" and Editor.records[p.id]
    if not def or def.deleted then return nil, "Publish the mission before testing it." end
    if not def.enabled then return nil, "Enable the mission before testing it." end
    local difficulty = type(p.difficulty) == "string" and p.difficulty or "standard"
    local ok, why = LightRP.missions.launchNow(def.id, difficulty, { player })
    if not ok then return nil, why end
    return { launched = true }
end

-- A plain net event stops at 1024 JSON values (kMaximumEventValues) and a refused one
-- says nothing to anybody: the list (whole definitions) went past it with a third
-- mission, and publishing "never answered" (2026-11-02). Past 900 values, latent
-- (262 144 values). Counted generously: every key and every value.
local LATENT_VALUES, LATENT_RATE = 900, 512 * 1024
local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 16 then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1) end
    return n
end
Editor.countValues = countValues
local function reply(player, response)
    local count = countValues(response)
    if count > LATENT_VALUES and type(TriggerLatentClientEvent) == "function" then
        local id, why = TriggerLatentClientEvent(NET, player, LATENT_RATE, response)
        if id then LightRP.log("mission editor: reply of %d values sent as a latent event", count); return end
        LightRP.log("mission editor: latent reply refused (%s, %d values)", tostring(why), count)
    end
    local ok, why = TriggerClientEvent(NET, player, response)
    if ok == false then LightRP.log("mission editor: reply refused (%s, %d values)", tostring(why), count) end
end

local function dispatch(player, p)
    if not Editor.allowed(player) then return nil, "Mission editor permission denied." end
    local op = p.operation
    if op == "list" then
        local fixers = {}
        for i, c in ipairs(type(LightRpFixers) == "table" and LightRpFixers.contacts or {}) do fixers[i] = { id = c.id, name = c.name } end
        -- the answer only says how many; every mission follows in its own event (a whole
        -- list in one reply passed the 1024-value cap with the third mission, 2026-11-02)
        local list = Editor.list()
        local stream = p.request
        CreateThread(function()
            for i, def in ipairs(list) do
                Wait(30)
                reply(player, { kind = "mission", stream = stream, index = i, total = #list, mission = def })
            end
            Wait(30)
            reply(player, { kind = "listed", stream = stream, total = #list })
        end)
        return { ready = Editor.ready and Db.ready, fixers = fixers, total = #list, streamed = true }
    end
    if op == "save" or op == "delete" then
        local a = actor(player)
        local key = type(p.mutation) == "string" and #p.mutation >= 8 and #p.mutation <= 96 and p.mutation or nil
        if not a or not key then return nil, "Invalid publication request." end
        done[a] = done[a] or {}
        if done[a][key] then return done[a][key] end
        local result, err
        if op == "save" then result, err = publish(player, p) else result, err = remove(player, p) end
        if result then done[a][key] = result end
        return result, err
    end
    if op == "test" then return test(player, p) end
    return nil, "Unknown mission editor operation."
end

RegisterNetEvent(NET, function(p)
    local player = tonumber(source)
    if not player or player <= 0 or type(p) ~= "table" or type(p.request) ~= "string" or #p.request < 1 or #p.request > 96
        or type(p.operation) ~= "string" then return end
    local at = now()
    if lastRequest[player] and at - lastRequest[player] < 0.15 then
        TriggerClientEvent(NET, player, { kind = "response", request = p.request, ok = false, error = "Please wait before the next request." })
        return
    end
    lastRequest[player] = at
    local ok, data, err = pcall(dispatch, player, p)
    if not ok then LightRP.log("mission editor request failed: %s", tostring(data)); data, err = nil, "The server could not complete this request." end
    reply(player, { kind = "response", request = p.request, ok = data ~= nil, data = data, error = err })
end)

LightRP.command("lightrp.missions", { restricted = true, usage = "/lightrp.missions (open the mission editor)" }, function(player)
    if not Editor.allowed(player) then return false, "Mission editor permission denied." end
    TriggerClientEvent(NET, player, { kind = "open" })
    return true, "Mission editor opened."
end)

AddEventHandler("onPlayerDisconnected", function(raw) local player = tonumber(raw); if player then lastRequest[player] = nil end end)
