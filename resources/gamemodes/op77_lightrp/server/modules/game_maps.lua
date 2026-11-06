-- Game maps: storage of the maps of op77_games and the staff editor's protocol (page <-> client
-- <-> here, net event op77_lightrp:mapeditor, the same shape as the mission editor). The
-- activity provider declares what a map needs (a schema per game) and plays what it is given:
-- this module owns the rows, and the rows are the truth. docs/map-editor.md.
--
-- ACL: command.lightrp.maps (staff roles already hold command.lightrp.*). /lightrp.maps opens it.
--
-- To the provider, server side only (exports, synchronous, never yield, no DB write; a call
-- carries 48 KiB at most, so maps go one by one):
--   gameMapSchema({ resource, id, label, schema })  -> true | false, reason
--   gameMapIndex(game) -> { ready, maps = { { id, revision } } }   enabled and valid, 8 at most
--   gameMap(game, id)  -> map | nil
--   event op77_lightrp:gamemaps:changed (game | nil)  pull again. Carries no map.
--
-- The one-time import (server/config/game_maps_seed.lua) needs both the database and every
-- game's schema, whichever comes last. It is one transaction with its mark: all of it or none,
-- and no mark means it runs again, on a bounded backoff (the provider is told when it lands), then
-- each time staff look. A row that exists, deleted or not, is never touched.
local R, Db = LightRpGameMapRules, LightRP.db
local Mission = LightRP.missionEditor
local Maps = LightRP.module("gameMaps", { games = {}, records = {}, ready = false, seeded = false, seedReport = {} })
local NET, CHANGED = "op77_lightrp:mapeditor", "op77_lightrp:gamemaps:changed"
local PERMISSION = "command.lightrp.maps"
local SEED_MARK = "seed-shared-maps"
local SELF = type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp"

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_game_maps (
 id VARCHAR(128) NOT NULL PRIMARY KEY, game VARCHAR(48) NOT NULL, definition MEDIUMTEXT NOT NULL,
 revision INT NOT NULL, deleted TINYINT NOT NULL DEFAULT 0, author VARCHAR(128) NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_game_map_marks (
 mark VARCHAR(64) NOT NULL PRIMARY KEY, done_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local lastRequest, done = {}, {} -- done[actor][mutation] = result (idempotent retries)
local warned = {}                -- what was already logged about a stored map
local function now() return Open77.time.monotonic() end
local function log(fmt, ...) LightRP.log("game maps: " .. fmt, ...) end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
local function rowId(game, id) return game .. ":" .. id end

-- What another resource says it is (the host names the caller when it can).
local function foreign(resource)
    local by = type(GetInvokingResource) == "function" and GetInvokingResource() or nil
    return type(by) == "string" and by ~= "" and by ~= SELF and by ~= resource
end

-- Every map of a game, deleted ones too unless asked, by name.
local function mapsOf(game, withDeleted)
    local list = {}
    for _, def in pairs(Maps.records[game] or {}) do
        if withDeleted or not def.deleted then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return list
end

local function enabledCount(game, except)
    local count = 0
    for _, def in pairs(Maps.records[game] or {}) do
        if def.enabled and not def.deleted and def.id ~= except then count = count + 1 end
    end
    return count
end

-- A stored map under today's schema (stored before a schema change, it may not fit). nil: it does not.
local function current(game, def)
    local entry = Maps.games[game]
    if not entry then return nil, { "This game's rules are not running." } end
    local map, why = R.sanitize(entry.schema, def)
    if not map then return nil, { why } end
    return map, R.problems(entry.schema, map)
end

local function announce(game)
    local ok, err = pcall(TriggerEvent, CHANGED, game)
    if not ok then log("%s not raised: %s", CHANGED, tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Storage

local function readAll()
    local readRows, rows = Db.read("SELECT id,game,definition,revision,deleted FROM lightrp_game_maps")
    local readMark, marks = Db.read("SELECT mark FROM lightrp_game_map_marks")
    if not readRows or not readMark then return false end
    local records, count = {}, 0
    for _, row in ipairs(rows) do
        local decoded, data = pcall(json.decode, row.definition)
        if decoded and type(data) == "table" and type(row.game) == "string" and type(data.id) == "string" then
            data.revision, data.deleted = tonumber(row.revision) or 1, tonumber(row.deleted) == 1
            records[row.game] = records[row.game] or {}
            records[row.game][data.id] = data
            if not data.deleted then count = count + 1 end
        else
            log("stored map %s ignored (unreadable)", tostring(row.id))
        end
    end
    Maps.records, Maps.ready = records, true
    for _, row in ipairs(marks) do
        if row.mark == SEED_MARK then Maps.seeded = true end
    end
    log("%d map(s) loaded", count)
    return true
end

-- The import. true: it ran. false: not now (a schema to wait for, seed data to fix). nil: the
-- database refused, try again. Maps it cannot keep enabled arrive disabled, and say so.
local function seed()
    local data = LightRpGameMapSeed
    if type(data) ~= "table" then return false end
    for game in pairs(data) do
        if not Maps.games[game] then return false end -- every game's schema first
    end
    local writes, report, added = {}, {}, 0
    local games = {}
    for game in pairs(data) do games[#games + 1] = game end
    table.sort(games)
    for _, game in ipairs(games) do
        local entry = Maps.games[game]
        local enabled = enabledCount(game)
        for _, raw in ipairs(data[game]) do
            local held = Maps.records[game] and Maps.records[game][raw.id]
            if not held then -- a row of any kind is staff work, or a deletion: never touched
                local map, why = R.sanitize(entry.schema, raw)
                if not map then
                    log("import stopped: %s %s does not read (%s)", game, tostring(raw.id), tostring(why))
                    return false
                end
                map.id = raw.id
                if map.enabled then
                    local issues = R.problems(entry.schema, map)
                    if #issues > 0 or enabled >= R.MAX_ENABLED then
                        map.enabled = false
                        report[#report + 1] = ("%s %s disabled: %s"):format(game, map.id, issues[1] or "the game has 8 enabled maps")
                    else
                        enabled = enabled + 1
                    end
                end
                local text = json.encode(map)
                if type(text) ~= "string" then
                    log("import stopped: %s %s does not encode", game, map.id)
                    return false
                end
                writes[#writes + 1] = { query = "INSERT IGNORE INTO lightrp_game_maps (id,game,definition,revision,deleted,author) VALUES (?,?,?,1,0,'seed')",
                    values = { rowId(game, map.id), game, text } }
                added = added + 1
            end
        end
    end
    writes[#writes + 1] = { query = "INSERT IGNORE INTO lightrp_game_map_marks (mark) VALUES (?)", values = { SEED_MARK } }
    local ok, why = Db.transaction(writes)
    if not ok then
        log("import failed, it will run again: %s", tostring(why))
        return nil
    end
    Maps.seeded, Maps.seedReport = true, report
    for _, line in ipairs(report) do log("import: %s", line) end
    log("import done: %d map(s)", added)
    return true
end

-- Database, then import, each when it can. Everything that could unblock it calls this; it may
-- wait on the database, so never from an export.
local RETRY_SECONDS = { 1, 2, 4, 8, 16, 32, 60, 60 }
local settling, again, retries, retrying = false, false, 0, false
local function retryLater()
    if retrying then return end
    retries = retries + 1
    local seconds = RETRY_SECONDS[retries]
    if not seconds then
        log("storage still failing after %d retries: the next try is when staff open the editor", #RETRY_SECONDS)
        return
    end
    retrying = true
    CreateThread(function()
        Wait(seconds * 1000)
        retrying = false
        Maps.settle(true)
    end)
end
-- `isRetry`: the backoff's own call. Anything else that fails starts the backoff over.
function Maps.settle(isRetry)
    if settling then again = true; return end
    settling = true
    local failed = false
    local ok, err = pcall(function()
        repeat
            again, failed = false, false
            local changed = false
            if Db.ready then
                if not Maps.ready then
                    changed = readAll()
                    failed = not changed
                end
                if Maps.ready and not Maps.seeded then
                    local imported = seed()
                    if imported then
                        Maps.ready = false -- the rows on disk are the truth: read them back
                        changed = readAll()
                        failed = not changed
                    elseif imported == nil then failed = true end
                end
            end
            if changed then announce(nil) end
        until not again
    end)
    settling = false
    if not ok then log("settle failed: %s", tostring(err)) end
    if ok and not failed then retries = 0; return end
    if not isRetry and not retrying then retries = 0 end
    retryLater()
end
function Maps.onDatabaseReady() Maps.settle() end

local function persist(player, game, def, baseRevision, deleted)
    local old = Maps.records[game] and Maps.records[game][def.id]
    local revision = (old and old.revision or 0) + 1
    local stored = copy(def)
    stored.revision, stored.deleted, stored.problems = nil, nil, nil
    local text = json.encode(stored)
    if type(text) ~= "string" then return nil, "This map could not be encoded. Nothing was saved." end
    local ok, result
    if old then
        ok, result = Db.run("UPDATE lightrp_game_maps SET definition=?,revision=?,deleted=?,author=? WHERE id=? AND revision=?",
            { text, revision, deleted and 1 or 0, Mission.actor(player), rowId(game, def.id), baseRevision })
        local affected = type(result) == "table" and (result.affectedRows or result.changedRows) or result
        if ok and tonumber(affected) == 0 then return nil, "This map changed meanwhile. Refresh before saving." end
    else
        ok = Db.run("INSERT INTO lightrp_game_maps (id,game,definition,revision,deleted,author) VALUES (?,?,?,?,0,?)",
            { rowId(game, def.id), game, text, revision, Mission.actor(player) })
    end
    if not ok then return nil, "Map storage refused the change. Nothing was saved." end
    def.revision, def.deleted = revision, deleted == true
    Maps.records[game] = Maps.records[game] or {}
    Maps.records[game][def.id] = def
    return def
end

-- ---------------------------------------------------------------------------
-- The editor's writes

local function usable()
    if Maps.ready and Db.ready and not settling then return true end
    return false
end
local function unusable() return nil, "Map storage is unavailable. Nothing was saved." end

local function gameOf(p)
    local entry = type(p.game) == "string" and Maps.games[p.game]
    if not entry then return nil, "That game is not available: op77_games must be running." end
    return entry
end

-- Why this map may not go live, or nil. The one gate of an enabled map.
local function refusal(entry, map, except)
    local issues = R.problems(entry.schema, map)
    if #issues > 0 then
        return ("This map cannot be enabled. %s%s"):format(issues[1], #issues > 1 and (" (%d more.)"):format(#issues - 1) or "")
    end
    if enabledCount(entry.id, except) >= R.MAX_ENABLED then
        return ("%s already has %d enabled maps, the most the rooms menu can list. Disable one first."):format(entry.label, R.MAX_ENABLED)
    end
end

local function view(game, def)
    local out = copy(def)
    local _, issues = current(game, def)
    out.problems, out.game = issues, game
    return out
end

local function save(player, p)
    if not usable() then return unusable() end
    local entry, why = gameOf(p)
    if not entry then return nil, why end
    local game = entry.id
    local map, reason = R.sanitize(entry.schema, p.map)
    if not map then return nil, reason end
    local id = p.map.id
    if id ~= nil and id ~= "" and type(id) ~= "string" then return nil, "This map no longer exists. Refresh the list." end
    -- ids repeat across games: only the game it was listed under says which map this one is
    if type(id) == "string" and id ~= "" and p.map.game ~= game then return nil, "This map belongs to another game. Refresh the list." end
    local old = type(id) == "string" and id ~= "" and Maps.records[game] and Maps.records[game][id] or nil
    if type(id) == "string" and id ~= "" and (not old or old.deleted) then return nil, "This map no longer exists. Refresh the list." end
    if old and old.revision ~= p.baseRevision then return nil, "This map changed meanwhile. Refresh before saving." end
    for _, other in ipairs(mapsOf(game)) do
        if other.name:lower() == map.name:lower() and other.id ~= (old and old.id) then
            return nil, ("%s already has a map called %s."):format(entry.label, other.name)
        end
    end
    if not old then
        if #mapsOf(game) >= R.MAX_MAPS then return nil, ("%s keeps %d maps at most."):format(entry.label, R.MAX_MAPS) end
        local base, slug, n = R.slug(map.name), nil, 1
        slug = base
        while Maps.records[game] and Maps.records[game][slug] do -- a deleted map keeps its id
            n = n + 1
            slug = ("%s-%d"):format(base, n)
        end
        map.id = slug
    else
        map.id = old.id
    end
    if map.enabled then
        local refused = refusal(entry, map, map.id)
        if refused then return nil, refused end
    end
    local saved, err = persist(player, game, map, p.baseRevision, false)
    if not saved then return nil, err end
    announce(game)
    log("%s saved %s %s (revision %d)", GetPlayerName(player) or tostring(player), game, saved.id, saved.revision)
    return { map = view(game, saved) }
end

local function setEnabled(player, p)
    if not usable() then return unusable() end
    local entry, why = gameOf(p)
    if not entry then return nil, why end
    local game, on = entry.id, p.enabled == true
    local old = type(p.id) == "string" and Maps.records[game] and Maps.records[game][p.id] or nil
    if not old or old.deleted then return nil, "This map no longer exists. Refresh the list." end
    if old.revision ~= p.baseRevision then return nil, "This map changed meanwhile. Refresh first." end
    local def = copy(old)
    def.revision, def.deleted = nil, nil
    def.enabled = on
    if on then
        local map, reason = R.sanitize(entry.schema, def)
        if not map then return nil, reason end
        local refused = refusal(entry, map, old.id)
        if refused then return nil, refused end
    end
    local saved, err = persist(player, game, def, p.baseRevision, false)
    if not saved then return nil, err end
    announce(game)
    log("%s %s %s %s", GetPlayerName(player) or tostring(player), on and "enabled" or "disabled", game, saved.id)
    return { map = view(game, saved) }
end

local function remove(player, p)
    if not usable() then return unusable() end
    local game = type(p.game) == "string" and p.game or nil
    local old = game and type(p.id) == "string" and Maps.records[game] and Maps.records[game][p.id] or nil
    if not old or old.deleted then return nil, "This map no longer exists." end
    if old.revision ~= p.baseRevision then return nil, "This map changed meanwhile. Refresh first." end
    local def = copy(old)
    def.revision, def.deleted = nil, nil
    def.enabled = false
    local saved, err = persist(player, game, def, p.baseRevision, true)
    if not saved then return nil, err end
    announce(game)
    log("%s deleted %s %s", GetPlayerName(player) or tostring(player), game, saved.id)
    return { id = saved.id }
end

-- ---------------------------------------------------------------------------
-- The protocol

local function reply(player, response) return Mission.deliver(NET, player, response) end

local function dispatch(player, p)
    if not Mission.allowed(player, PERMISSION) then return nil, "Map editor permission denied." end
    local op = p.operation
    if op == "games" then
        CreateThread(Maps.settle) -- a failed import or load gets another try each time staff look
        local games, ids = {}, {}
        for id in pairs(Maps.games) do ids[#ids + 1] = id end
        table.sort(ids)
        for i, id in ipairs(ids) do
            local entry = Maps.games[id]
            games[i] = { id = id, label = entry.label, schema = entry.schema, total = #mapsOf(id), enabled = enabledCount(id) }
        end
        return { ready = usable(), games = games, maxEnabled = R.MAX_ENABLED, maxMaps = R.MAX_MAPS }
    end
    if op == "list" then
        local entry, why = gameOf(p)
        if not entry then return nil, why end
        -- how many, then each map in its own event, as the mission list (the cap is 1024 values)
        local list, stream, game = mapsOf(entry.id), p.request, entry.id
        CreateThread(function()
            for i, def in ipairs(list) do
                Wait(30)
                reply(player, { kind = "map", stream = stream, index = i, total = #list, map = view(game, def) })
            end
            Wait(30)
            reply(player, { kind = "listed", stream = stream, total = #list })
        end)
        return { ready = usable(), total = #list, streamed = true }
    end
    if op == "save" or op == "enable" or op == "delete" then
        local who = Mission.actor(player)
        local key = type(p.mutation) == "string" and #p.mutation >= 8 and #p.mutation <= 96 and p.mutation or nil
        if not who or not key then return nil, "Invalid request." end
        done[who] = done[who] or { count = 0, results = {} }
        local memo = done[who]
        if memo.results[key] then return memo.results[key] end
        local result, err
        if op == "save" then result, err = save(player, p)
        elseif op == "enable" then result, err = setEnabled(player, p)
        else result, err = remove(player, p) end
        if result then
            if memo.count >= 256 then memo.count, memo.results = 0, {} end
            memo.count = memo.count + 1
            memo.results[key] = result
        end
        return result, err
    end
    return nil, "Unknown map editor operation."
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
    if not ok then log("request failed: %s", tostring(data)); data, err = nil, "The server could not complete this request." end
    reply(player, { kind = "response", request = p.request, ok = data ~= nil, data = data, error = err })
end)

LightRP.command("lightrp.maps", { restricted = true, usage = "/lightrp.maps (open the game map editor)" }, function(player)
    if not Mission.allowed(player, PERMISSION) then return false, "Map editor permission denied." end
    TriggerClientEvent(NET, player, { kind = "open" })
    return true, "Map editor opened."
end)

AddEventHandler("onPlayerDisconnected", function(raw) local player = tonumber(raw); if player then lastRequest[player] = nil end end)

-- ---------------------------------------------------------------------------
-- The provider

-- Only a running provider's answer: a map that no longer fits its game's schema stays stored
-- and stays out, said once in the log.
local function playable(game, def)
    if def.deleted or not def.enabled then return nil end
    local map, issues = current(game, def)
    if map and #issues == 0 then return map end
    local key = game .. ":" .. def.id .. ":" .. def.revision
    if not warned[key] then
        warned[key] = true
        log("%s %s is enabled but not delivered: %s", game, def.id, tostring(issues[1]))
    end
    return nil
end

local function exported(name, fn)
    exports(name, function(...)
        local result = table.pack(pcall(fn, ...))
        if not result[1] then
            log("%s failed: %s", name, tostring(result[2]))
            return false, "Light RP could not process the request."
        end
        return table.unpack(result, 2, result.n)
    end)
end

function Maps.registerSchema(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or #def.id > 48 or not def.id:match("^%l[%l%d_]*%.[%l%d_%-]+$") then
        return false, "The game id must be namespaced, like games.tdm."
    end
    if type(def.resource) ~= "string" or def.resource == "" or #def.resource > 64 then return false, "The resource name is missing." end
    if foreign(def.resource) then return false, "The resource must be the calling resource." end
    local old = Maps.games[def.id]
    if old and old.resource ~= def.resource then return false, "That game belongs to " .. old.resource .. "." end
    local schema, why = R.schema(def.schema)
    if not schema then return false, why end
    Maps.games[def.id] = { id = def.id, resource = def.resource, label = type(def.label) == "string" and def.label:sub(1, 48) or def.id, schema = schema }
    CreateThread(Maps.settle) -- an export never touches the database
    return true
end

function Maps.index(game)
    if not Maps.ready or not Db.ready or type(game) ~= "string" or not Maps.games[game] then return { ready = false } end
    local maps = {}
    for _, def in ipairs(mapsOf(game)) do
        if #maps < R.MAX_ENABLED and playable(game, def) then maps[#maps + 1] = { id = def.id, revision = def.revision } end
    end
    return { ready = true, maps = maps }
end

function Maps.deliver(game, id)
    local def = type(game) == "string" and type(id) == "string" and Maps.records[game] and Maps.records[game][id] or nil
    if not def then return nil end
    local map = playable(game, def)
    if not map then return nil end
    map.id, map.enabled = def.id, nil
    return map
end

exported("gameMapSchema", Maps.registerSchema)
exported("gameMapIndex", Maps.index)
exported("gameMap", Maps.deliver)
