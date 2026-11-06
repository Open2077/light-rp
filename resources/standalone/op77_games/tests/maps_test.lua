-- Where a game's maps come from: the schemas, the one-time import data read through the core's
-- rules, the delivery in every start order, a change reaching the rooms, a running match keeping
-- its map, a game with none. Run: lua tests/maps_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
local A, E, L = GamesActivity, GamesEngine, GamesLobby
local Maps = GamesMapStore
local R = LightRpGameMapRules
local core = H.core
local GAMES = { "games.tdm", "games.redlight", "games.gungame", "games.control", "games.ctf", "games.prophunt" }

for id = 1, 24 do H.addPlayer(id) end
H.advance(200)

local function def(id) return A.definition(id) end
local function modeIds(game)
    local out = {}
    for i, m in ipairs(core.registered[game] and core.registered[game].modes or {}) do out[i] = m.id end
    return table.concat(out, ",")
end
local function find(game, id)
    for _, raw in ipairs(core.maps[game]) do if raw.id == id then return raw end end
    error("no " .. id)
end
local function change(game, id, patch)
    local raw = find(game, id)
    for key, value in pairs(patch) do raw[key] = value end
    raw.revision = raw.revision + 1
end
local nextId = 100
local function live(activityId, n)
    local ids = {}
    for _ = 1, n do
        nextId = nextId + 1
        H.addPlayer(nextId)
        ids[#ids + 1] = nextId
    end
    H.matchJoin(activityId, ids, {})
    return H.untilPhase(ids[1], "running"), ids
end
local function finish(match)
    E.cancel(match)
    H.settle(1000)
end

H.test("nothing hardcoded is left", function()
    H.ok(not io.open("shared/maps/tdm.lua"), "no shared/maps")
    H.ok(not io.open("tools/gen_maps.py"), "no generator")
    local manifest = io.open("open77.lua"):read("a")
    H.ok(not manifest:find("shared/maps", 1, true), "no manifest line")
    H.ok(manifest:find('server_script "server/maps.lua"', 1, true), "the store is loaded")
    H.eq(GamesMaps, nil, "no global map list")
end)

H.test("every game declares a schema the core accepts, next to its rules", function()
    for _, game in ipairs(GAMES) do
        H.ok(def(game).schema, game .. " has a schema")
        local clean, why = R.schema(def(game).schema)
        H.ok(clean, game .. ": " .. tostring(why))
    end
end)

H.test("a schema says what its mode reads", function()
    local function keys(game)
        local out = {}
        local s = def(game).schema
        for _, p in ipairs(s.points or {}) do if not p.hidden then out[p.key] = "point" end end
        for _, l in ipairs(s.lists or {}) do out[l.key] = l.min end
        for _, n in ipairs(s.numbers or {}) do if not n.hidden then out[n.key] = "number" end end
        return out
    end
    local tdm = keys("games.tdm")
    H.eq(tdm.centre, "point"); H.eq(tdm.spawns, 2); H.eq(tdm.radius, "number")
    local red = keys("games.redlight")
    H.eq(red.finish, "point"); H.eq(red.spawns, 1); H.eq(red.timeLimit, "number")
    H.eq(red.centre, nil, "no play area in red light"); H.eq(red.radius, nil)
    local control = keys("games.control")
    H.ok(control.point and control.redSpawn and control.blueSpawn and control.centre, "control's points")
    local ctf = keys("games.ctf")
    H.ok(ctf.redBase and ctf.blueBase and ctf.centre, "ctf's points")
    H.eq(ctf.redSpawns, 0, "team spots are optional"); H.eq(ctf.blueSpawns, 0)
    local hunt = keys("games.prophunt")
    H.ok(hunt.propsSpawn and hunt.huntersSpawn and hunt.hideSeconds and hunt.roundSeconds, "prop hunt's")
    H.eq(hunt.centre, nil, "its area is around the props' spawn")
    H.eq(def("games.prophunt").schema.choices[1].key, "props")
    H.eq(#def("games.prophunt").schema.choices[1].options, #GamesProphunt.catalog, "the whole catalogue")
end)

H.test("every imported map passes its game's rules, no stored coordinate lost", function()
    local count, enabled = 0, 0
    for _, game in ipairs(GAMES) do
        local schema = assert(R.schema(def(game).schema))
        local on = 0
        for _, raw in ipairs(H.seedData[game]) do
            count = count + 1
            local map, why = R.sanitize(schema, raw)
            H.ok(map, game .. " " .. raw.id .. ": " .. tostring(why))
            local issues = R.problems(schema, map)
            H.eq(#issues, 0, game .. " " .. raw.id .. ": " .. tostring(issues[1]))
            -- every position stored in the import data is in the sanitized map, by value
            local kept = {}
            local function note(p) kept[("%.3f,%.3f,%.3f"):format(p.x, p.y, p.z)] = true end
            for _, value in pairs(map) do
                if type(value) == "table" then
                    if value.x then note(value) else for _, p in ipairs(value) do if type(p) == "table" then note(p) end end end
                end
            end
            for key, value in pairs(raw) do
                if type(value) == "table" then
                    for _, p in ipairs(value.x and { value } or value) do
                        H.ok(kept[("%.3f,%.3f,%.3f"):format(p.x, p.y, p.z)], game .. " " .. raw.id .. ": lost a point of " .. key)
                    end
                end
            end
            if raw.enabled then on = on + 1; enabled = enabled + 1 end
        end
        H.ok(on <= R.MAX_ENABLED, game .. ": 8 enabled at most")
    end
    H.eq(count, 22)
    H.eq(enabled, 17)
end)

H.test("the five spare prop hunt maps arrive disabled", function()
    local spare = {}
    for _, raw in ipairs(H.seedData["games.prophunt"]) do if not raw.enabled then spare[#spare + 1] = raw.name end end
    table.sort(spare)
    H.eq(table.concat(spare, ","), "Black Sapphire,Cynosure,Drive In,Ncart H7,School")
end)

H.test("a map fits one export call; the biggest schema too", function()
    local function nodes(value)
        if type(value) ~= "table" then return 1 end
        local n = 1
        for _, item in pairs(value) do n = n + 1 + nodes(item) end
        return n
    end
    local most = 0
    for _, game in ipairs(GAMES) do
        H.ok(nodes(def(game).schema) < 4096, game .. " schema")
        for _, raw in ipairs(H.seedData[game]) do most = math.max(most, nodes(raw)) end
    end
    H.ok(most < 4096, "the platform's node limit")
    local full = { }
    for i = 1, 32 do full[i] = { x = 1.5, y = 2.5, z = 3.5, heading = 90.5 } end
    H.ok(nodes({ a = full, b = full, c = full }) < 4096, "three full lists")
end)

H.test("delivered: the provider's own copy, with its derived fields", function()
    H.eq(#H.mapsOf("tdm"), 2)
    local control = H.mapsOf("control")[1]
    H.ok(control.radius >= R.schema(def("games.control").schema).numbers[1].min, "a radius")
    H.eq(#control.spawns, 2, "control's engine fallback")
    local ctf = H.mapOf("ctf", "school")
    H.eq(#ctf.spawns, 2)
    local hunt = H.mapsOf("prophunt")[1]
    H.eq(hunt.centre, hunt.propsSpawn, "the area around the props' spawn")
    H.ok(Maps.accept(def("games.tdm"), H.mapsOf("tdm")[1]))
end)

H.test("a changed map reaches the rooms with no restart, one game only", function()
    local registers = #H.coreCalls("activityRegister")
    local fetches = core.mapFetches
    change("games.tdm", "watson-docks", { name = "Docks at dusk" })
    H.signalMaps("games.tdm")
    H.eq(H.mapOf("tdm", "watson-docks").name, "Docks at dusk")
    H.eq(core.registered["games.tdm"].modes[1].label, "Docks at dusk", "the choice follows")
    H.eq(#H.coreCalls("activityRegister"), registers + 1, "only that game registers again")
    H.eq(core.mapFetches, fetches + 1, "only the changed map is fetched")
    change("games.tdm", "watson-docks", { name = "Watson Docks" })
    H.signalMaps("games.tdm")
end)

H.test("an unchanged signal registers nothing; a foreign one is ignored", function()
    local registers = #H.coreCalls("activityRegister")
    H.signalMaps("games.tdm")
    H.signalMaps("race.grid")
    H.signalMaps(nil)
    H.eq(#H.coreCalls("activityRegister"), registers)
end)

H.test("a new map appears, a disabled one goes", function()
    local copy = H.deepCopy(find("games.tdm", "watson-docks"))
    copy.id, copy.name, copy.revision = "annex", "Annex", 1
    table.insert(core.maps["games.tdm"], copy)
    H.signalMaps("games.tdm")
    H.eq(modeIds("games.tdm"), "annex,grand-imperial-mall,watson-docks")
    change("games.tdm", "annex", { enabled = false })
    H.signalMaps("games.tdm")
    H.eq(modeIds("games.tdm"), "grand-imperial-mall,watson-docks")
end)

H.test("a running match keeps its map; the next one plays the new", function()
    local match, ids = live("games.gungame", 2)
    local before = match.map
    local name, spawns, radius = before.name, #before.spawns, before.radius
    change("games." .. "gungame", before.id, { name = "Rebuilt", radius = 300 })
    H.signalMaps("games.gungame")
    H.eq(match.map, before, "the same table")
    H.eq(match.map.name, name)
    H.eq(match.map.radius, radius)
    H.eq(#match.map.spawns, spawns)
    H.ok(H.mapOf("gungame", before.id).name == "Rebuilt", "the store moved on")
    -- disabled and gone: the match does not care
    change("games.gungame", before.id, { enabled = false })
    H.signalMaps("games.gungame")
    H.settle(2000)
    H.eq(E.matchOf(ids[1]), match, "still playing")
    H.eq(match.map.name, name)
    finish(match)
    H.eq(E.matchOf(ids[1]), nil, "ended normally")
    H.noneInBuckets()
    change("games.gungame", before.id, { enabled = true, name = name, radius = radius })
    H.signalMaps("games.gungame")
end)

H.test("a map delivered broken is left out, the others stay", function()
    local realGet = H.coreExports.gameMap
    H.coreExports.gameMap = function(self, game, id)
        local map = realGet(self, game, id)
        if id == "hotel" then map.spawns = nil; map.centre = nil end
        return map
    end
    change("games.gungame", "hotel", {})
    H.signalMaps("games.gungame")
    H.coreExports.gameMap = realGet
    H.ok(H.logged("map hotel left out"), "said in the log")
    H.ok(not modeIds("games.gungame"):find("hotel", 1, true), "not offered")
    H.ok(modeIds("games.gungame"):find("jig%-jig%-street"), "the rest is")
    change("games.gungame", "hotel", {})
    H.signalMaps("games.gungame")
    H.ok(modeIds("games.gungame"):find("hotel", 1, true), "back once it reads")
end)

H.test("one missing point or one short list is enough to leave a map out", function()
    local realGet = H.coreExports.gameMap
    for _, field in ipairs({ "centre", "spawns" }) do
        H.coreExports.gameMap = function(self, game, id)
            local map = realGet(self, game, id)
            if id == "hotel" then map[field] = nil end
            return map
        end
        change("games.gungame", "hotel", {})
        H.signalMaps("games.gungame")
        H.ok(not modeIds("games.gungame"):find("hotel", 1, true), "no " .. field)
    end
    H.coreExports.gameMap = realGet
    change("games.gungame", "hotel", {})
    H.signalMaps("games.gungame")
    H.ok(modeIds("games.gungame"):find("hotel", 1, true), "back")
end)

H.test("a pull that fails halfway changes nothing and is tried again", function()
    local realGet = H.coreExports.gameMap
    H.coreExports.gameMap = function() error("a bad moment") end
    local maps = H.mapsOf("redlight")
    change("games.redlight", "rocket-ramp", { name = "Ramp" })
    H.signalMaps("games.redlight")
    H.eq(H.mapsOf("redlight"), maps, "the same list")
    H.eq(A.registered, false, "the retry is armed")
    H.coreExports.gameMap = realGet
    H.advance(500)
    H.eq(A.registered, true)
    H.eq(H.mapOf("redlight", "rocket-ramp").name, "Ramp")
    change("games.redlight", "rocket-ramp", { name = "Rocket Ramp" })
    H.signalMaps("games.redlight")
end)

H.test("eight at most: the index and the registration both hold it", function()
    local list = core.maps["games.prophunt"]
    local saved = {}
    for i, raw in ipairs(list) do saved[i] = raw.enabled; raw.enabled = true; raw.revision = raw.revision + 1 end
    H.signalMaps("games.prophunt")
    H.eq(#core.registered["games.prophunt"].modes, 8)
    def("games.prophunt").maps = H.deepCopy(H.seedOf("prophunt"))
    table.insert(def("games.prophunt").maps, { id = "ninth", name = "Ninth" })
    H.eq(#A.registration(def("games.prophunt")).modes, 8, "the ninth is not offered")
    for i, raw in ipairs(list) do raw.enabled = saved[i]; raw.revision = raw.revision + 1 end
    H.signalMaps("games.prophunt")
    H.eq(#core.registered["games.prophunt"].modes, 8)
end)

H.test("a game with no enabled map: not offered, no error, back when one returns", function()
    local errors = #H.logs
    change("games.control", "kang-tao", { enabled = false })
    H.signalMaps("games.control")
    local reg = core.registered["games.control"]
    H.eq(reg.offered, false, "not offered")
    H.eq(#reg.modes, 0)
    H.eq(#H.mapsOf("control"), 0)
    H.eq(L.statusOf(def("games.control"), E.now()).joinable, false)
    H.panelJoin(1, "games.control", {})
    H.advance(300)
    H.eq(E.matchOf(1), nil)
    H.ok(H.noticeFor(1, "no map"), "told")
    H.eq(core.pending[1], nil, "released")
    local _, why = E.open(def("games.control"), { 2, 3 }, {})
    H.eq(why, "no_map")
    for index = errors + 1, #H.logs do H.ok(not H.logs[index]:find("failed"), H.logs[index]) end
    change("games.control", "kang-tao", { enabled = true })
    H.signalMaps("games.control")
    H.eq(core.registered["games.control"].offered, true)
    H.eq(modeIds("games.control"), "kang-tao")
end)

H.test("a queue on a map's last moments: the launch says so and holds nobody", function()
    H.panelJoin(4, "games.control", {})
    H.panelJoin(5, "games.control", {})
    H.advance(300)
    H.eq(L.queuedIn(4), "games.control")
    change("games.control", "kang-tao", { enabled = false })
    H.signalMaps("games.control")
    H.advance(20000)
    H.eq(E.matchOf(4), nil)
    H.ok(H.noticeFor(4, "no map"), "told")
    H.eq(core.pending[4], nil)
    change("games.control", "kang-tao", { enabled = true })
    H.signalMaps("games.control")
end)

H.test("the core answers not ready (no database): we keep what we hold", function()
    local maps = H.mapsOf("tdm")
    core.mapsReady = false
    H.fire("op77_lightrp:activity:ready")
    H.advance(500)
    H.eq(A.registered, true, "no error")
    H.eq(H.mapsOf("tdm"), maps, "the same maps")
    H.eq(#core.registered["games.tdm"].modes, 2, "still offered")
    core.mapsReady = true
    H.signalMaps(nil)
end)

H.test("the core restarts: schemas, maps and choices again", function()
    H.coreStop()
    H.fire("onResourceStop", "op77_lightrp")
    H.eq(A.registered, false)
    core.schemas = {}
    H.advance(500)
    H.coreStart()
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.eq(A.registered, true)
    for _, game in ipairs(GAMES) do H.ok(core.schemas[game], game .. " schema again") end
    H.eq(modeIds("games.tdm"), "grand-imperial-mall,watson-docks")
end)

H.test("the core restarts with its database late: nothing offered is lost, the signal completes it", function()
    H.coreStop()
    H.fire("onResourceStop", "op77_lightrp")
    core.schemas = {}
    core.mapsReady = false
    H.coreStart()
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.eq(A.registered, true, "registered on what it holds")
    H.eq(modeIds("games.tdm"), "grand-imperial-mall,watson-docks")
    change("games.tdm", "watson-docks", { name = "Watson Docks 2" })
    core.mapsReady = true
    H.signalMaps(nil)
    H.eq(H.mapOf("tdm", "watson-docks").name, "Watson Docks 2", "the core's truth once it can answer")
    change("games.tdm", "watson-docks", { name = "Watson Docks" })
    H.signalMaps("games.tdm")
end)

H.test("a schema refused is offered again, and nothing registers before it", function()
    local registers = #H.coreCalls("activityRegister")
    core.refuseSchema = true
    H.fire("op77_lightrp:activity:ready")
    H.advance(500)
    H.eq(A.registered, false)
    H.eq(#H.coreCalls("activityRegister"), registers, "schemas first")
    core.refuseSchema = false
    H.advance(3500)
    H.eq(A.registered, true)
end)

-- This one last: new VMs from here on.
H.test("the provider starts after the core: it pulls for itself", function()
    H.providerStop()
    H.reload()
    A, E = GamesActivity, GamesEngine
    H.advance(300)
    H.eq(A.registered, true)
    H.eq(#H.mapsOf("tdm"), 2, "maps at once")
    H.eq(modeIds("games.tdm"), "grand-imperial-mall,watson-docks")
end)

H.test("the provider starts before the core: no map, no error, then everything", function()
    H.providerStop()
    H.coreStop()
    core.schemas = {}
    H.reload()
    A, E = GamesActivity, GamesEngine
    H.advance(4000)
    H.eq(A.registered, false)
    H.eq(#H.mapsOf("tdm"), 0, "nothing yet")
    H.coreStart()
    H.fire("op77_lightrp:activity:ready")
    H.advance(500)
    H.eq(A.registered, true)
    for _, game in ipairs(GAMES) do H.ok(#A.definition(game).maps > 0, game .. " filled") end
end)

H.test("the core's first answer is empty (import still running): the signal fills it", function()
    H.providerStop()
    H.coreStop()
    core.schemas = {}
    local stored = core.maps
    core.maps = {}
    H.reload()
    A, E = GamesActivity, GamesEngine
    H.coreStart()
    H.fire("op77_lightrp:activity:ready")
    H.advance(500)
    H.eq(A.registered, true)
    H.eq(core.registered["games.tdm"].offered, false, "not offered yet, no error")
    core.maps = stored
    H.signalMaps(nil)
    H.eq(core.registered["games.tdm"].offered, true, "offered")
    H.eq(modeIds("games.tdm"), "grand-imperial-mall,watson-docks")
end)

H.done("maps_test")
