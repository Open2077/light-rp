-- Game maps (server/modules/game_maps.lua): the staff protocol, storage, the one-time import and
-- the delivery to op77_games, on the real persistence layer over a fake MySQL, the real rules and
-- the real schemas of the op77_games modes. Run from the resource root.
local clock, threads = 0, {}
local function runThreads()
    local progressed = true
    while progressed do
        progressed = false
        for i = #threads, 1, -1 do
            local co = threads[i]
            if coroutine.status(co) == "dead" then table.remove(threads, i)
            else
                local ok, err = coroutine.resume(co)
                if not ok then error(err .. "\n" .. debug.traceback(co)) end
                progressed = progressed or err ~= "asleep"
            end
        end
    end
end
local function run() clock = clock + 1000; runThreads() end
_G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
-- A wait of a second or more runs on the clock (the backoff), a shorter one is a mere yield.
_G.Wait = function(ms)
    if (ms or 0) < 1000 then coroutine.yield(); return end
    local wake = clock + ms
    while clock < wake do coroutine.yield("asleep") end
end
_G.SetTimeout = function() end

-- ------------------------------------------------------------------ the fake database --
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
local blobs = {}
_G.json = {
    encode = function(value) blobs[#blobs + 1] = copy(value); return "#" .. #blobs end,
    decode = function(text) return copy(blobs[tonumber(text:sub(2))]) end,
}
local DB
local function freshDb() DB = { rows = {}, marks = {}, order = {}, calls = 0, failTransaction = false, failRead = false, failWrite = false, down = false } end
freshDb()
local function insert(params)
    local id = params[1]
    if DB.rows[id] then return 0 end
    DB.rows[id] = { id = id, game = params[2], definition = params[3], revision = params[4] or 1, deleted = 0, author = params[5] or "seed" }
    DB.order[#DB.order + 1] = id
    return 1
end
_G.MySQL = {
    update = { await = function(sql, params)
        if DB.down then error("the bridge died") end
        if sql:find("^CREATE") then return 0 end
        DB.calls = DB.calls + 1
        if DB.failWrite then error("disk full") end
        if sql:find("^INSERT INTO lightrp_game_maps") then return insert(params) end
        if sql:find("^UPDATE lightrp_game_maps") then
            DB.updates = (DB.updates or 0) + 1
            if DB.staleUpdate then return 0 end
            local row = DB.rows[params[5]]
            if row and row.revision == params[6] then
                row.definition, row.revision, row.deleted, row.author = params[1], params[2], params[3], params[4]
                return 1
            end
            return 0
        end
        return 0
    end },
    query = { await = function(sql)
        DB.calls = DB.calls + 1
        if DB.failRead then error("read failed") end
        if sql:find("FROM lightrp_game_map_marks") then
            local out = {}
            for mark in pairs(DB.marks) do out[#out + 1] = { mark = mark } end
            return out
        end
        if sql:find("FROM lightrp_game_maps") then
            local out = {}
            for _, id in ipairs(DB.order) do out[#out + 1] = copy(DB.rows[id]) end
            return out
        end
        return {}
    end },
    single = { await = function() end },
    transaction = { await = function(queries)
        DB.calls = DB.calls + 1
        DB.transactions = (DB.transactions or 0) + 1
        DB.lastTransaction = #queries
        if DB.failTransaction then return false end
        if DB.failReadAfterCommit then DB.failRead = true end
        for _, q in ipairs(queries) do
            if q.query:find("lightrp_game_map_marks") then DB.marks[q.values[1]] = true
            else insert(q.values) end
        end
        return true
    end },
}

-- ------------------------------------------------------------------ the host --
local net, sent, commands, events = {}, {}, {}, {}
local allowed = { [1] = true, [3] = true }
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.AddEventHandler = function() end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload }; return true end
_G.TriggerLatentClientEvent = function(name, target, _, payload) sent[#sent + 1] = { name = name, target = target, payload = payload, latent = true }; return #sent end
_G.TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) }; return true end
_G.GetPlayerIdentifier = function(id) return "license:" .. id end
_G.GetPlayerName = function(id) return "P" .. id end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
local invoking
_G.GetInvokingResource = function() return invoking end
local exported = {}
_G.exports = function(name, fn) exported[name] = fn; return true end
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    acl = { isAllowed = function(id, permission) return allowed[id] == true and permission == "command.lightrp.maps" end },
}

local logs, modules = {}, {}
local function boot()
    modules, logs = {}, {}
    _G.LightRP = {
        log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
        module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = def; return def end,
        eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
        command = function(name, options, fn) commands[name] = { options = options, fn = fn } end,
    }
    dofile("server/core/persistence.lua")
    dofile("client/core/state_json.lua")
    dofile("server/modules/mission_editor.lua")
    dofile("server/modules/game_map_rules.lua")
    dofile("server/config/game_maps_seed.lua")
    dofile("server/modules/game_maps.lua")
    return LightRP.gameMaps
end
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")

-- The real schemas: the mode files, with an engine that only keeps what they declare.
local SCHEMAS = {}
do
    local dir = "../../standalone/op77_games/"
    dofile(dir .. "shared/config.lua")
    local print0 = print
    _G.GamesCombat = {}
    _G.GamesEngine = { mode = function(def) SCHEMAS[def.id] = { label = def.label, schema = def.schema } end, distance = function() return 0 end, flat = function() return 0 end }
    _G.GamesActivity = {}
    for _, mode in ipairs({ "tdm", "redlight", "gungame", "control", "ctf", "prophunt" }) do dofile(dir .. "server/modes/" .. mode .. ".lua") end
    print = print0
end
local GAMES = { "games.control", "games.ctf", "games.gungame", "games.prophunt", "games.redlight", "games.tdm" }

local Maps
local function provider(only)
    invoking = "op77_games"
    for _, game in ipairs(GAMES) do
        if not only or only == game then
            local ok, why = exported.gameMapSchema({ resource = "op77_games", id = game, label = SCHEMAS[game].label, schema = SCHEMAS[game].schema })
            assert(ok == true, game .. ": " .. tostring(why))
        end
    end
    invoking = nil
end
local function start() Maps = boot(); runThreads(); return Maps end

local seq = 0
local function ask(player, operation, payload)
    clock = clock + 1000
    seq = seq + 1
    local p = payload or {}
    p.operation, p.request = operation, "r" .. seq
    if operation == "save" or operation == "enable" or operation == "delete" then p.mutation = p.mutation or ("mutation-" .. seq) end
    local before = #sent
    -- a large reply leaves as text: the table it was made from stands for what the page parses
    local encode, encoded = LightRpStateJson.encode, nil
    LightRpStateJson.encode = function(value, ...) encoded = value; return encode(value, ...) end
    source = player
    net["op77_lightrp:mapeditor"](p)
    source = nil
    runThreads()
    LightRpStateJson.encode = encode
    if encoded and encoded.request == p.request then
        for i = before + 1, #sent do if sent[i].payload.kind == "parts" then return encoded end end
    end
    for i = before + 1, #sent do
        if sent[i].payload.kind == "response" and sent[i].payload.request == p.request then return sent[i].payload end
    end
end
local function ok(response, why) assert(response and response.ok == true, tostring(why) .. ": " .. tostring(response and response.error)); return response.data end
local function refused(response, pattern, why)
    assert(response and response.ok == false, tostring(why) .. " was accepted")
    assert(not pattern or tostring(response.error):find(pattern), tostring(why) .. ": said " .. tostring(response.error))
end
local function eq(a, b, why) assert(a == b, tostring(why) .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function rowCount() local n = 0; for _ in pairs(DB.rows) do n = n + 1 end return n end
local function signals(game)
    local n = 0
    for _, e in ipairs(events) do if e.name == "op77_lightrp:gamemaps:changed" and (game == nil or e.args[1] == game) then n = n + 1 end end
    return n
end
local function enabledIn(game)
    local out = {}
    for _, row in ipairs(exported.gameMapIndex(game).maps or {}) do out[#out + 1] = row.id end
    return out
end
local function spot(x, y, z) return { x = x, y = y, z = z or 10, heading = 0 } end
local function fullTdm(name)
    return { name = name, centre = spot(0, 0), radius = 80, spawns = { spot(10, 0), spot(-10, 0) } }
end
local function mapRow(game, id)
    for _, def in pairs(Maps.records[game] or {}) do if def.id == id then return def end end
end

-- ------------------------------------------------------------------ the import --

-- the database first; the import waits for every schema, and says nothing of it
local function failed() for _, line in ipairs(logs) do if line:find("failed") then return line end end end
Maps = boot()
runThreads()
assert(LightRP.db.ready and Maps.ready, "the table reads")
provider("games.tdm")
runThreads()
eq(rowCount(), 0, "one schema is not all of them: no import")
eq(DB.transactions, nil, "no transaction before every schema")
eq(failed(), nil, "waiting is no failure")
-- an export never touches the database: the work waits for a thread
local before = DB.calls
provider()
eq(DB.calls, before, "the schema call that completes them does no database work")
eq(rowCount(), 0, "not yet")
runThreads()
eq(rowCount(), 22, "every map imported")
assert(DB.marks["seed-shared-maps"], "the mark is set")
eq(#enabledIn("games.prophunt"), 8, "prop hunt offers 8")
eq(#enabledIn("games.tdm"), 2)
eq(#enabledIn("games.redlight"), 1)
eq(#enabledIn("games.control"), 1)
eq(#enabledIn("games.ctf"), 2)
eq(#enabledIn("games.gungame"), 3)
eq(#Maps.seedReport, 0, "every enabled map passed validation")
for _, name in ipairs({ "black-sapphire", "cynosure", "drive-in", "ncart-h7", "school" }) do
    local def = mapRow("games.prophunt", name)
    assert(def and def.enabled == false, name .. " arrives disabled")
end
assert(signals(nil) > 0, "the provider is told")
for _, e in ipairs(events) do
    for i = 1, e.args.n do assert(type(e.args[i]) ~= "table", "a signal carries no map") end
end
for _, s in ipairs(sent) do assert(s.name ~= "op77_lightrp:gamemaps:changed", "never a net event") end

-- seed once: a second start reads, writes nothing
local transactions = DB.transactions
start(); provider(); runThreads()
eq(DB.transactions, transactions, "the import runs once")
eq(rowCount(), 22)

-- ------------------------------------------------------------------ the ACL --
local denied = { "games", "list", "save", "enable", "delete" }
for _, op in ipairs(denied) do
    refused(ask(2, op, { game = "games.tdm", id = "watson-docks", map = fullTdm("Nope"), baseRevision = 1 }), "permission denied", op .. " without the ACL")
end
do
    local ok1, text = commands["lightrp.maps"].fn(2)
    eq(ok1, false, "the command refuses"); assert(text:find("permission denied"))
    assert(commands["lightrp.maps"].options.restricted == true, "restricted")
    local count = #sent
    eq(commands["lightrp.maps"].fn(1), true, "staff open it")
    eq(sent[count + 1].payload.kind, "open")
    eq(sent[count + 1].name, "op77_lightrp:mapeditor")
    local acl = Open77.acl
    Open77.acl = nil
    refused(ask(1, "games"), "permission denied", "no ACL API")
    Open77.acl = { isAllowed = function() error("boom") end }
    refused(ask(1, "games"), "permission denied", "a raising ACL")
    Open77.acl = acl
    eq(rowCount(), 22, "nothing written by anyone refused")
end

-- ------------------------------------------------------------------ reads --
do
    local data = ok(ask(1, "games"), "games")
    eq(data.ready, true); eq(#data.games, 6); eq(data.maxEnabled, 8)
    eq(data.games[6].id, "games.tdm"); eq(data.games[6].enabled, 2)
    assert(data.games[6].schema.points[1].key == "centre", "the page gets the schema")
    local listed = ok(ask(1, "list", { game = "games.tdm" }), "list")
    eq(listed.total, 2); eq(listed.streamed, true)
    local maps = 0
    for _, s in ipairs(sent) do if s.payload.kind == "map" and s.target == 1 then maps = maps + 1 end end
    assert(maps >= 2, "each map in its own event")
    refused(ask(1, "list", { game = "games.nope" }), "not available", "an unknown game")
end

-- ------------------------------------------------------------------ hostile input --
do
    local count = #sent
    source = 1
    for _, junk in ipairs({ 1, "x", true, { request = 5, operation = "games" }, { request = "a", operation = 7 }, { request = string.rep("a", 97), operation = "games" }, { request = "", operation = "games" } }) do
        net["op77_lightrp:mapeditor"](junk)
    end
    source = 0
    net["op77_lightrp:mapeditor"]({ request = "a", operation = "games" })
    source = nil
    eq(#sent, count, "junk gets no answer")
    refused(ask(1, "nonsense"), "Unknown", "an unknown operation")
    local base = #DB.order
    local nan, huge = 0 / 0, 1 / 0
    local cases = {
        { "not a map", "x" }, { "no name", { centre = spot(0, 0) } }, { "an empty name", { name = "  " } },
        { "a long name", { name = string.rep("n", 33) } }, { "a name of another type", { name = 5 } },
        { "a NaN point", { name = "A", centre = { x = nan, y = 0, z = 0 } } }, { "an infinite point", { name = "A", centre = { x = huge, y = 0, z = 0 } } },
        { "a far point", { name = "A", centre = { x = 100001, y = 0, z = 0 } } }, { "a text point", { name = "A", centre = "here" } },
        { "a bad heading", { name = "A", centre = { x = 0, y = 0, z = 0, heading = nan } } },
        { "a list that is no list", { name = "A", spawns = { a = spot(0, 0) } } }, { "a junk list item", { name = "A", spawns = { 5 } } },
        { "a radius out of range", { name = "A", radius = 9 } }, { "a NaN radius", { name = "A", radius = nan } }, { "a text radius", { name = "A", radius = "80" } },
    }
    do local long = {}; for i = 1, 33 do long[i] = spot(i, 0) end; cases[#cases + 1] = { "too long a list", { name = "A", spawns = long } } end
    for _, case in ipairs(cases) do
        refused(ask(1, "save", { game = "games.tdm", map = case[2], baseRevision = 0 }), nil, case[1])
    end
    refused(ask(1, "save", { game = 5, map = fullTdm("A") }), "not available", "a game of another type")
    refused(ask(1, "save", { game = "games.tdm", map = { name = "A", id = 5 } }), "no longer exists", "an id of another type")
    refused(ask(1, "save", { game = "games.tdm", map = { name = "A", id = "ghost", game = "games.tdm" } }), "no longer exists", "an id nobody has")
    refused(ask(1, "enable", { game = "games.tdm", id = {}, enabled = true, baseRevision = 1 }), "no longer exists", "a table id")
    refused(ask(1, "delete", { game = {}, id = "watson-docks", baseRevision = 1 }), "no longer exists", "a table game")
    refused(ask(1, "save", { game = "games.prophunt", map = { name = "A", props = { "not.in.the.catalogue" } } }), "unknown option", "an object not in the catalogue")
    refused(ask(1, "save", { game = "games.prophunt", map = { name = "A", hideSeconds = 45.5 } }), "whole number", "a fraction of a second")
    do
        local bad = { game = "games.tdm", map = fullTdm("A"), baseRevision = 0, mutation = "x" }
        refused(ask(1, "save", bad), "Invalid request", "too short a request key")
    end
    eq(#DB.order, base, "nothing written")
    -- unknown fields never reach the row; control characters leave a name
    local map = fullTdm("Clean\10name")
    map.evil, map.problems, map.revision, map.deleted = "x", { "x" }, 99, true
    local saved = ok(ask(1, "save", { game = "games.tdm", map = map, baseRevision = 0 }), "extras dropped").map
    eq(saved.name, "Clean name"); eq(saved.evil, nil, "no unknown field"); eq(saved.revision, 1, "the server's revision"); eq(saved.deleted, false)
    ok(ask(1, "delete", { game = "games.tdm", id = saved.id, baseRevision = 1 }), "cleanup")
    -- the rate limit
    clock = clock + 1000
    source = 1
    net["op77_lightrp:mapeditor"]({ request = "fast1", operation = "games" })
    net["op77_lightrp:mapeditor"]({ request = "fast2", operation = "games" })
    source = nil
    runThreads()
    assert(sent[#sent].payload.request == "fast2" or sent[#sent - 1].payload.error, "too fast")
    local found = false
    for _, s in ipairs(sent) do if s.payload.request == "fast2" and s.payload.ok == false and s.payload.error:find("wait") then found = true end end
    assert(found, "the second is told to wait")
end

-- ------------------------------------------------------------------ draft versus enable --
local draftId
do
    local signalsBefore = signals("games.tdm")
    local draft = { name = "Half built", spawns = { spot(1, 1) } }
    local saved = ok(ask(1, "save", { game = "games.tdm", map = draft, baseRevision = 0 }), "a draft with holes saves").map
    draftId = saved.id
    eq(saved.enabled, false); eq(saved.id, "half-built", "a slug of the name")
    eq(#saved.problems, 2, "it says what is missing")
    assert(saved.problems[1]:find("Play area centre"), saved.problems[1])
    assert(saved.problems[2]:find("at least 2"), saved.problems[2])
    eq(#enabledIn("games.tdm"), 2, "not delivered")
    refused(ask(1, "enable", { game = "games.tdm", id = draftId, enabled = true, baseRevision = 1 }), "Play area centre", "enabling a draft")
    assert(not mapRow("games.tdm", draftId).enabled, "still off")
    refused(ask(1, "save", { game = "games.tdm", map = { id = draftId, game = "games.tdm", name = "Half built", enabled = true }, baseRevision = 1 }), "cannot be enabled", "saving a draft as enabled")
    eq(mapRow("games.tdm", draftId).revision, 1, "nothing written")
    -- a spawn outside the play area is a problem too
    local out = fullTdm("Half built"); out.id, out.game = draftId, "games.tdm"; out.spawns[2] = spot(500, 0)
    saved = ok(ask(1, "save", { game = "games.tdm", map = out, baseRevision = 1 }), "complete but wrong").map
    assert(saved.problems[1]:find("outside the play area"), tostring(saved.problems[1]))
    refused(ask(1, "enable", { game = "games.tdm", id = draftId, enabled = true, baseRevision = 2 }), "outside", "a spawn out of bounds")
    local good = fullTdm("Half built"); good.id, good.game = draftId, "games.tdm"
    saved = ok(ask(1, "save", { game = "games.tdm", map = good, baseRevision = 2 }), "fixed").map
    eq(#saved.problems, 0)
    eq(ok(ask(1, "enable", { game = "games.tdm", id = draftId, enabled = true, baseRevision = 3 }), "complete: enabled").map.enabled, true)
    eq(#enabledIn("games.tdm"), 3, "delivered")
    assert(signals("games.tdm") > signalsBefore, "signalled")
    local delivered = exported.gameMap("games.tdm", draftId)
    eq(delivered.id, draftId); eq(delivered.name, "Half built"); eq(#delivered.spawns, 2); eq(delivered.enabled, nil)
    eq(exported.gameMap("games.tdm", "ghost"), nil, "no such map")
    eq(exported.gameMap(5, {}), nil, "junk")
    -- an enabled map cannot be saved broken
    local broken = fullTdm("Half built"); broken.id, broken.game, broken.enabled, broken.centre = draftId, "games.tdm", true, nil
    refused(ask(1, "save", { game = "games.tdm", map = broken, baseRevision = 4 }), "cannot be enabled", "breaking an enabled map")
    eq(ok(ask(1, "enable", { game = "games.tdm", id = draftId, enabled = false, baseRevision = 4 }), "disable").map.enabled, false)
    eq(#enabledIn("games.tdm"), 2, "withdrawn")
    -- a red light finish on its own start line, a ctf with its bases together
    refused(ask(1, "save", { game = "games.redlight", map = { name = "Short", enabled = true, finish = spot(0, 0), spawns = { spot(1, 0) } }, baseRevision = 0 }), "apart", "no course")
    refused(ask(1, "save", { game = "games.ctf", map = { name = "Close", enabled = true, redBase = spot(0, 0), blueBase = spot(2, 0), centre = spot(1, 0) }, baseRevision = 0 }), "apart", "bases together")
    -- names are unique in a game, not across games
    refused(ask(1, "save", { game = "games.tdm", map = { name = "watson docks" }, baseRevision = 0 }), "already has a map", "the same name")
    ok(ask(1, "save", { game = "games.control", map = { name = "Watson Docks" }, baseRevision = 0 }), "another game may")
end

-- ------------------------------------------------------------------ stale saves --
do
    local row = mapRow("games.tdm", "watson-docks")
    local rev = row.revision
    local mine = fullTdm("Watson Docks"); mine.id, mine.game = "watson-docks", "games.tdm"
    local updates = DB.updates
    refused(ask(1, "save", { game = "games.tdm", map = mine, baseRevision = rev - 1 }), "changed meanwhile", "an old revision")
    refused(ask(1, "save", { game = "games.tdm", map = mine }), "changed meanwhile", "no revision")
    refused(ask(1, "save", { game = "games.tdm", map = mine, baseRevision = tostring(rev) }), "changed meanwhile", "a text revision")
    refused(ask(1, "enable", { game = "games.tdm", id = "watson-docks", enabled = false, baseRevision = rev + 5 }), "changed meanwhile", "stale enable")
    refused(ask(1, "delete", { game = "games.tdm", id = "watson-docks", baseRevision = rev + 5 }), "changed meanwhile", "stale delete")
    eq(mapRow("games.tdm", "watson-docks").revision, rev, "untouched")
    eq(DB.updates, updates, "a stale request never reaches the row: refused on what we hold")
    -- two staff: the second, on the same base, loses; the row says so even when memory agrees
    DB.staleUpdate = true
    refused(ask(1, "enable", { game = "games.tdm", id = "watson-docks", enabled = false, baseRevision = rev }), "changed meanwhile", "the row moved under us")
    DB.staleUpdate = nil
    eq(mapRow("games.tdm", "watson-docks").enabled, true, "memory follows the row")
    local a = ok(ask(1, "enable", { game = "games.tdm", id = "watson-docks", enabled = true, baseRevision = rev }), "first").map
    refused(ask(3, "enable", { game = "games.tdm", id = "watson-docks", enabled = true, baseRevision = rev }), "changed meanwhile", "second staff")
    eq(a.revision, rev + 1)
    -- a retry of the same request answers the same, once
    local key = { game = "games.tdm", id = "watson-docks", enabled = true, baseRevision = rev + 1, mutation = "same-key-1" }
    local first = ok(ask(1, "enable", { game = key.game, id = key.id, enabled = true, baseRevision = key.baseRevision, mutation = key.mutation }), "keyed")
    local second = ok(ask(1, "enable", { game = key.game, id = key.id, enabled = true, baseRevision = key.baseRevision, mutation = key.mutation }), "retried")
    eq(first.map.revision, second.map.revision, "idempotent")
    eq(mapRow("games.tdm", "watson-docks").revision, rev + 2, "one write")
    -- a write that fails changes nothing
    DB.failWrite = true
    refused(ask(1, "enable", { game = "games.tdm", id = "watson-docks", enabled = true, baseRevision = rev + 2 }), "refused the change", "disk full")
    DB.failWrite = false
    eq(mapRow("games.tdm", "watson-docks").revision, rev + 2)
end

-- ------------------------------------------------------------------ the ninth map --
do
    local game = "games.prophunt"
    local function hunt(name, enabled)
        return { name = name, enabled = enabled, propsSpawn = spot(0, 0), huntersSpawn = spot(5, 0), radius = 60 }
    end
    eq(#enabledIn(game), 8, "eight now")
    local saved = ok(ask(1, "save", { game = game, map = hunt("Ninth"), baseRevision = 0 }), "a ninth draft is fine").map
    refused(ask(1, "enable", { game = game, id = saved.id, enabled = true, baseRevision = 1 }), "already has 8 enabled maps", "enabling a ninth")
    refused(ask(1, "save", { game = game, map = hunt("Tenth", true), baseRevision = 0 }), "Disable one first", "saving a ninth enabled")
    refused(ask(1, "enable", { game = game, id = "drive-in", enabled = true, baseRevision = 1 }), "8 enabled", "a spare is a ninth too")
    eq(#enabledIn(game), 8, "still eight")
    assert(exported.gameMap(game, saved.id) == nil, "not delivered")
    -- an enabled map can still be edited at the limit
    local list = exported.gameMapIndex(game).maps
    local one = copy(mapRow(game, list[1].id))
    one.name, one.game = "Renamed", game
    local rev = one.revision
    eq(ok(ask(1, "save", { game = game, map = one, baseRevision = rev }), "renaming at eight").map.name, "Renamed", "name")
    ok(ask(1, "enable", { game = game, id = list[1].id, enabled = false, baseRevision = rev + 1 }), "make room")
    ok(ask(1, "enable", { game = game, id = saved.id, enabled = true, baseRevision = 1 }), "now it fits")
    eq(#enabledIn(game), 8)
    -- the core's limit per game on stored maps
    local n = #(function() local out = {}; for _, d in pairs(Maps.records[game]) do if not d.deleted then out[#out + 1] = d end end return out end)()
    for i = n + 1, 32 do ok(ask(1, "save", { game = game, map = hunt("Filler " .. i), baseRevision = 0 }), "filler") end
    refused(ask(1, "save", { game = game, map = hunt("One too many"), baseRevision = 0 }), "32 maps at most", "the 33rd")
end

-- ------------------------------------------------------------------ delete --
do
    local game = "games.gungame"
    local row = mapRow(game, "hotel")
    ok(ask(1, "delete", { game = game, id = "hotel", baseRevision = row.revision }), "delete")
    eq(DB.rows["games.gungame:hotel"].deleted, 1, "soft")
    assert(exported.gameMap(game, "hotel") == nil, "not delivered")
    refused(ask(1, "delete", { game = game, id = "hotel", baseRevision = row.revision + 1 }), "no longer exists", "twice")
    refused(ask(1, "enable", { game = game, id = "hotel", enabled = true, baseRevision = row.revision + 1 }), "no longer exists", "enable the deleted")
    -- its name is free, its id is not: the new map has its own
    eq(ok(ask(1, "save", { game = game, map = { name = "Hotel" }, baseRevision = 0 }), "same name").map.id, "hotel-2", "a new id")
    -- restart: still gone
    start(); provider(); runThreads()
    assert(exported.gameMap(game, "hotel") == nil, "not back after a restart")
    eq(mapRow(game, "hotel").deleted, true)
    -- even if the mark is lost, the import never touches a row: not this one, not staff's edit
    local staff = copy(mapRow("games.tdm", "watson-docks"))
    local rows = rowCount()
    DB.marks = {}
    local staffRow = DB.rows["games.tdm:watson-docks"].definition
    start(); provider(); runThreads()
    eq(rowCount(), rows, "no row added")
    eq(DB.lastTransaction, 1, "only the mark: not one row is even offered")
    eq(DB.rows["games.gungame:hotel"].deleted, 1, "a deleted map does not return")
    eq(DB.rows["games.tdm:watson-docks"].definition, staffRow, "staff work is not overwritten")
    eq(mapRow("games.tdm", "watson-docks").revision, staff.revision)
    assert(DB.marks["seed-shared-maps"], "marked again")
end

-- ------------------------------------------------------------------ a failed import --
do
    freshDb()
    DB.failTransaction = true
    start(); provider(); runThreads()
    eq(rowCount(), 0, "all of it or none")
    assert(not DB.marks["seed-shared-maps"], "no mark on failure")
    assert(not Maps.seeded, "not seeded")
    local found = false
    for _, line in ipairs(logs) do if line:find("import failed") then found = true end end
    assert(found, "said in the log")
    eq(exported.gameMapIndex("games.tdm").ready, true, "the core answers: no maps, no crash")
    eq(#exported.gameMapIndex("games.tdm").maps, 0)
    DB.failTransaction = false
    ok(ask(1, "games"), "staff look")
    runThreads()
    eq(rowCount(), 22, "it ran again")
    assert(DB.marks["seed-shared-maps"], "marked")
    eq(#enabledIn("games.prophunt"), 8)

    -- a failed mark read must not run the import blind
    DB.failRead = true
    start(); provider(); runThreads()
    eq(Maps.ready, false, "not ready")
    eq(exported.gameMapIndex("games.tdm").ready, false, "not ready for the provider either")
    refused(ask(1, "save", { game = "games.tdm", map = fullTdm("X"), baseRevision = 0 }), "unavailable", "no write without a read")
    DB.failRead = false
    local t = DB.transactions
    ok(ask(1, "games"), "staff look"); runThreads()
    eq(Maps.ready, true, "recovered")
    eq(DB.transactions, t, "already imported: not again")
end

-- ------------------------------------------------------------------ the backoff --
do
    local function advance(seconds) for _ = 1, seconds do run() end end
    local function reads() return DB.calls end

    -- a failed boot read: back with no staff, the provider told
    freshDb()
    DB.failRead = true
    start(); provider(); runThreads()
    eq(Maps.ready, false, "the read failed")
    DB.failRead = false
    local told = signals(nil)
    advance(3)
    eq(Maps.ready, true, "the retry read it")
    eq(rowCount(), 22, "and imported")
    assert(signals(nil) > told, "the provider is told, nobody opened the menu")

    -- a failed import: no mark, no seeded, then it lands alone
    freshDb()
    DB.failTransaction = true
    start(); provider(); runThreads()
    advance(3)
    assert(DB.transactions >= 2, "tried again")
    assert(not Maps.seeded and not DB.marks["seed-shared-maps"], "never marked done on a failure")
    eq(rowCount(), 0, "none of it")
    DB.failTransaction = false
    told = signals(nil)
    advance(8)
    assert(Maps.seeded and DB.marks["seed-shared-maps"], "done once it landed")
    eq(rowCount(), 22, "all of it")
    assert(signals(nil) > told, "the provider is told")

    -- the import landed, its read back failed: read again, never imported twice
    freshDb()
    DB.failReadAfterCommit = true
    start(); provider(); runThreads()
    eq(Maps.ready, false, "the read back failed")
    eq(DB.transactions, 1, "imported")
    DB.failRead, DB.failReadAfterCommit = false, false
    told = signals(nil)
    advance(3)
    eq(Maps.ready, true, "read back")
    eq(DB.transactions, 1, "not imported twice")
    assert(signals(nil) > told, "the provider is told")
    eq(#enabledIn("games.prophunt"), 8, "the maps are there")

    -- bounded: the gaps grow, then it stops and says so; staff looking starts it over
    freshDb()
    DB.failRead = true
    start(); provider(); runThreads()
    local base = reads()
    advance(1); local one = reads() - base
    assert(one > 0, "the first retry comes after a second")
    advance(1); eq(reads() - base, one, "the next is two seconds on")
    advance(600)
    local spent = reads() - base
    assert(spent <= 9 * 2 * 2, "bounded: " .. spent)
    advance(600)
    eq(reads() - base, spent, "it stopped")
    local said = false
    for _, line in ipairs(logs) do if line:find("still failing") then said = true end end
    assert(said, "said in the log")
    ok(ask(1, "games"), "staff look"); runThreads()
    assert(reads() - base > spent, "a look tries again")
    DB.failRead = false
    advance(2)
    eq(Maps.ready, true, "and the backoff with it")
end

-- ------------------------------------------------------------------ a save across games --
do
    freshDb()
    start(); provider(); runThreads()
    -- both games hold the id; this draft came from the other game's list
    local tdm = mapRow("games.tdm", "watson-docks")
    ok(ask(1, "save", { game = "games.control", map = { name = "Watson Docks" }, baseRevision = 0 }), "same id in another game")
    local control = mapRow("games.control", "watson-docks")
    local listed = ok(ask(1, "enable", { game = "games.tdm", id = "watson-docks", enabled = true, baseRevision = tdm.revision }), "a reply").map
    eq(listed.game, "games.tdm", "every map sent says its game")
    local before = DB.rows["games.control:watson-docks"].definition
    local cross = copy(listed)
    refused(ask(1, "save", { game = "games.control", map = cross, baseRevision = control.revision }), "another game", "a map of another game")
    eq(DB.rows["games.control:watson-docks"].definition, before, "nothing written")
    local untagged = copy(listed); untagged.game = nil
    refused(ask(1, "save", { game = "games.control", map = untagged, baseRevision = control.revision }), "another game", "no game at all")
    refused(ask(1, "save", { game = "games.gungame", map = cross, baseRevision = 1 }), "another game", "an id that game does not have")
    local saved = ok(ask(1, "save", { game = "games.tdm", map = cross, baseRevision = listed.revision }), "its own game").map
    eq(saved.game, "games.tdm", "and it keeps saying so")
    eq(mapRow("games.tdm", "watson-docks").game, nil, "the tag is not stored")
    eq(exported.gameMap("games.tdm", "watson-docks").game, nil, "nor delivered")
end

-- ------------------------------------------------------------------ a broken import map --
do
    freshDb()
    local data = LightRpGameMapSeed
    Maps = boot()
    LightRpGameMapSeed = copy(data)
    LightRpGameMapSeed["games.tdm"][1].centre = nil -- passes reading, fails validation
    table.insert(LightRpGameMapSeed["games.prophunt"], 1, copy(LightRpGameMapSeed["games.prophunt"][1]))
    LightRpGameMapSeed["games.prophunt"][1].id = "ninth-enabled"
    LightRpGameMapSeed["games.prophunt"][1].name = "Ninth enabled"
    runThreads(); provider(); runThreads()
    eq(rowCount(), 23, "kept, not lost")
    eq(mapRow("games.tdm", "watson-docks").enabled, false, "invalid: arrives disabled")
    eq(#Maps.seedReport, 2, "reported")
    assert(Maps.seedReport[2]:find("watson%-docks") or Maps.seedReport[1]:find("watson%-docks"), "named")
    eq(#enabledIn("games.prophunt"), 8, "never a ninth")
    -- unreadable: nothing is half imported
    freshDb()
    Maps = boot()
    LightRpGameMapSeed["games.tdm"][1].spawns = { "junk" }
    runThreads(); provider(); runThreads()
    eq(rowCount(), 0, "stopped")
    assert(not DB.marks["seed-shared-maps"], "no mark")
    LightRpGameMapSeed = data
end

-- ------------------------------------------------------------------ no database --
do
    freshDb()
    DB.down = true
    start(); provider(); runThreads()
    assert(not LightRP.db.ready, "no database")
    eq(exported.gameMapIndex("games.tdm").ready, false, "not ready")
    eq(exported.gameMap("games.tdm", "watson-docks"), nil)
    local data = ok(ask(1, "games"), "the menu still opens")
    eq(data.ready, false, "and says so")
    refused(ask(1, "save", { game = "games.tdm", map = fullTdm("X"), baseRevision = 0 }), "unavailable", "no database, no save")
    refused(ask(1, "delete", { game = "games.tdm", id = "x", baseRevision = 1 }), "unavailable", "no database, no delete")
    DB.down = false

    -- the database comes back only with a restart of the core; the provider's schemas may come first
    start()
    assert(LightRP.db.ready, "back")
    eq(rowCount(), 0, "no schema yet: no import")
    provider(); runThreads()
    eq(rowCount(), 22, "the import, from the schema's side")

    -- provider first, then database: the other order
    freshDb()
    Maps = boot()
    provider()
    runThreads()
    eq(rowCount(), 22, "the import, from the database's side")
end

-- ------------------------------------------------------------------ the provider's contract --
do
    invoking = "somebody_else"
    local ok1, why = exported.gameMapSchema({ resource = "op77_games", id = "games.tdm", schema = SCHEMAS["games.tdm"].schema })
    eq(ok1, false, "another resource cannot speak for it"); assert(why:find("calling resource"))
    ok1, why = exported.gameMapSchema({ resource = "somebody_else", id = "games.tdm", schema = SCHEMAS["games.tdm"].schema })
    eq(ok1, false, "nor take its game over"); assert(why:find("belongs to"))
    invoking = nil
    for _, junk in ipairs({ 5, {}, { id = "nodot", resource = "r", schema = {} }, { id = "a.b", schema = {} }, { id = "a.b", resource = "r", schema = 5 },
        { id = "a.b", resource = "r", schema = { points = { { key = "id" } } } },
        { id = "a.b", resource = "r", schema = { points = { { key = "a" }, { key = "a" } } } },
        { id = "a.b", resource = "r", schema = { lists = { { key = "a", min = 3, max = 2 } } } },
        { id = "a.b", resource = "r", schema = { lists = { { key = "a", max = 65 } } } },
        { id = "a.b", resource = "r", schema = { numbers = { { key = "a", min = 1, max = 2, default = 3 } } } },
        { id = "a.b", resource = "r", schema = { area = { centre = "x", radius = "y" } } },
        { id = "a.b", resource = "r", schema = { apart = { { a = "x", b = "y", metres = 1 } } } } }) do
        eq(exported.gameMapSchema(junk), false, "a bad schema")
    end
    eq(Maps.games["a.b"], nil, "none kept")
    eq(exported.gameMapIndex(5).ready, false, "junk")
    eq(exported.gameMapIndex("games.none").ready, false, "unknown")
    -- a schema that grew: the stored map stays, it is not delivered, it is said once
    local grown = copy(SCHEMAS["games.control"].schema)
    grown.points[#grown.points + 1] = { key = "extra", label = "Extra", color = "#ffffff" }
    invoking = "op77_games"
    assert(exported.gameMapSchema({ resource = "op77_games", id = "games.control", label = "Control", schema = grown }))
    invoking = nil
    eq(#exported.gameMapIndex("games.control").maps, 0, "no longer delivered")
    exported.gameMapIndex("games.control")
    local said = 0
    for _, line in ipairs(logs) do if line:find("not delivered") then said = said + 1 end end
    eq(said, 1, "said once")
    assert(mapRow("games.control", "kang-tao").enabled, "still stored as it was")
    provider("games.control")
    eq(#exported.gameMapIndex("games.control").maps, 1, "back with the old schema")
    assert(exported.gameMap("games.control", "kang-tao").redSpawn, "whole")
end

-- A reply past 900 values reaches the client as text in small plain events, on its own event: the
-- client walks nothing, encodes nothing. As a table it never reached the page (/lightrp.maps, 1,345 values).
do
    local fakeJson = _G.json
    _G.json = nil -- this file's json is a marker, not an encoder: the real text is read here
    local big = { kind = "response", request = "r", ok = true, data = {} }
    for i = 1, 400 do big.data[i] = { x = i, y = "é" .. i } end
    local before = #sent
    LightRP.missionEditor.deliver("op77_lightrp:mapeditor", 1, big)
    eq(#sent, before + 1, "one part for a reply of this size")
    local part = sent[#sent]
    eq(part.latent, nil, "not latent")
    eq(part.name, "op77_lightrp:mapeditor", "on its own event")
    eq(part.payload.kind, "parts", "text parts")
    eq(part.payload.parts, 1, "numbered")
    eq(part.payload.text, LightRpStateJson.encode(big, false), "the whole reply")
    assert(LightRP.missionEditor.countValues(part.payload) < 20, "almost nothing for the client to walk")

    -- longer than one part: every part fits the event once escaped, none starts inside a character
    big.data = {}
    for i = 1, 900 do big.data[i] = { name = "é" .. string.rep("x", 40) .. i } end
    before = #sent
    LightRP.missionEditor.deliver("op77_lightrp:mapeditor", 1, big)
    local joined, id = {}, sent[before + 1].payload.id
    for i = before + 1, #sent do
        local p = sent[i].payload
        eq(p.id, id, "one reply")
        joined[p.part] = p.text
        assert(#p.text * 2 < 48 * 1024, "under the event's limit, escaped")
        local first = p.text:byte(1)
        assert(first < 0x80 or first >= 0xC0, "a part starts on a character")
    end
    assert(#sent - before >= 2, "in parts")
    eq(table.concat(joined), LightRpStateJson.encode(big, false), "joined back")

    -- no encoder: latent, as before
    local encoder = LightRpStateJson.encode
    LightRpStateJson.encode = function() error("refused") end
    LightRP.missionEditor.deliver("op77_lightrp:mapeditor", 1, big)
    LightRpStateJson.encode = encoder
    eq(sent[#sent].latent, true, "latent when it cannot be encoded")
    _G.json = fakeJson
end

print("PASS: map editor (import once, after a failure, never over staff work, no deleted map back, ACL, hostile input, draft versus enable, stale saves, the ninth map, delete, no database, both start orders, provider contract)")
