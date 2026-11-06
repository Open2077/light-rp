-- Test harness for op77_games: a fake Open77 server runtime (players, life, buckets, weapons,
-- combat scopes, clock), a coroutine scheduler for CreateThread / Wait / SetTimeout, event
-- buses, and a stub of op77_lightrp's side of the activity contract. Modelled on
-- op77_race/tests/harness.lua. Run from the resource root: lua tests/x.lua
local H = {}

-- ---------------------------------------------------------------- clock + threads --

H.clock = 0
local threads, timers = {}, {}

function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wakeAt = H.clock } end
function Wait(ms)
    assert(coroutine.isyieldable(), "Wait called outside a thread")
    coroutine.yield(math.max(0, ms or 0))
end
function SetTimeout(ms, fn) timers[#timers + 1] = { at = H.clock + (ms or 0), fn = fn } end

local function runReady()
    local progressed = true
    while progressed do
        progressed = false
        for index = #threads, 1, -1 do
            local t = threads[index]
            if t and t.wakeAt <= H.clock then
                local ok, delay = coroutine.resume(t.co)
                if not ok then error("thread failed: " .. tostring(delay) .. "\n" .. debug.traceback(t.co)) end
                if coroutine.status(t.co) == "dead" then table.remove(threads, index)
                else t.wakeAt = H.clock + math.max(1, delay or 0) end
                progressed = true
            end
        end
        for index = #timers, 1, -1 do
            local timer = timers[index]
            if timer and timer.at <= H.clock then
                table.remove(timers, index)
                CreateThread(timer.fn)
                progressed = true
            end
        end
    end
end
H.runReady = runReady

function H.advance(ms, step)
    step = step or 50
    local target = H.clock + ms
    runReady()
    while H.clock < target do
        H.clock = math.min(target, H.clock + step)
        runReady()
    end
end

-- ---------------------------------------------------------------- logs --

H.logs = {}
local realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    H.logs[#H.logs + 1] = table.concat(parts, " ")
end
H.print = realPrint
function H.logged(pattern)
    for _, line in ipairs(H.logs) do if line:find(pattern) then return true end end
    return false
end

-- ---------------------------------------------------------------- events --

H.handlers, H.netHandlers = {}, {}
H.events, H.clientEvents = {}, {}

function AddEventHandler(name, fn)
    H.handlers[name] = H.handlers[name] or {}
    table.insert(H.handlers[name], fn)
end
function RegisterNetEvent(name, fn) if fn then H.netHandlers[name] = fn end end
function TriggerEvent(name, ...)
    H.events[#H.events + 1] = { name = name, args = table.pack(...) }
    return true
end
function TriggerClientEvent(name, target, ...)
    H.clientEvents[#H.clientEvents + 1] = { name = name, target = target, args = table.pack(...) }
    return true
end
function TriggerServerEvent(name, ...)
    H.clientEvents[#H.clientEvents + 1] = { name = name, server = true, args = table.pack(...) }
    return true
end
function GetCurrentResourceName() return "op77_games" end

function H.fire(name, ...)
    for _, fn in ipairs(H.handlers[name] or {}) do fn(...) end
    runReady()
end
function H.fireNet(name, playerId, ...)
    local fn = assert(H.netHandlers[name], "no net handler " .. name)
    source = playerId
    fn(...)
    source = nil
    runReady()
end
function H.eventsNamed(name)
    local found = {}
    for _, event in ipairs(H.events) do if event.name == name then found[#found + 1] = event end end
    return found
end
function H.clientNamed(name, target)
    local found = {}
    for _, event in ipairs(H.clientEvents) do
        if event.name == name and (target == nil or event.target == target) then found[#found + 1] = event end
    end
    return found
end
function H.lastClient(name, target)
    local found = H.clientNamed(name, target)
    return found[#found]
end

-- ---------------------------------------------------------------- players --

H.players = {}
H.teleports, H.respawns, H.kills = {}, {}, {}
H.teleportFails = false

local CITY = { x = 100, y = 200, z = 10 }

function H.addPlayer(id, name)
    H.players[id] = { name = name or ("P" .. id), x = CITY.x + id, y = CITY.y, z = CITY.z, bucket = 0, life = "alive",
        frozen = false, health = 100, ageMs = 0, fresh = true, ping = nil }
    return H.players[id]
end
function H.removePlayer(id) H.players[id] = nil end
function H.move(id, x, y, z)
    local p = H.players[id]
    p.x, p.y, p.z = x or p.x, y or p.y, z or p.z
end

local function checked(id)
    if math.type(id) ~= "integer" or id < 1 then error("id must be positive (uncatchable in the real runtime)") end
    return H.players[id]
end

Open77 = {
    time = { monotonic = function() return H.clock / 1000 end },
    log = { warn = function() end },
    players = {
        name = function(id) local p = checked(id); return p and p.name or nil end,
        position = function(id)
            local p = checked(id)
            if not p or not p.fresh then return nil end
            return { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
        end,
        positions = function()
            local out = {}
            for id, p in pairs(H.players) do
                if p.fresh then out[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket } end
            end
            return out
        end,
        get = function(id)
            local p = checked(id)
            if not p then return nil, "player_not_found" end
            return { playerId = id, bucket = p.bucket, fresh = p.fresh, ageMs = p.ageMs, ready = true,
                position = p.fresh and { x = p.x, y = p.y, z = p.z } or nil }
        end,
        ping = function(id)
            local p = checked(id)
            if not p then return nil, "player_not_found" end
            if p.ping == nil then return nil, "ping_unavailable" end
            return p.ping
        end,
        getHealth = function(id) local p = checked(id); return p and { health = p.health, maxHealth = 100 } or nil end,
        setHealth = function(id, value) local p = checked(id); if p then p.health = value end return true end,
        setFrozen = function(id, value)
            local p = checked(id)
            if not p or p.life ~= "alive" then return false, "transition_in_progress" end
            p.frozen = value == true
            return true
        end,
        getLifeState = function(id)
            local p = checked(id)
            return p and { phase = p.life, bucket = p.bucket } or nil
        end,
        kill = function(id, opts)
            local p = checked(id)
            if not p then return false, "no_player" end
            H.kills[#H.kills + 1] = { id = id, opts = opts }
            p.life, p.frozen = "dead", false
            return true
        end,
        respawn = function(id, opts)
            local p = checked(id)
            if not p or p.life ~= "dead" then return false, "invalid_state" end
            H.respawns[#H.respawns + 1] = { id = id, opts = opts }
            p.life, p.x, p.y, p.z = "alive", opts.position.x, opts.position.y, opts.position.z
            p.bucket = opts.bucket or 0 -- the runtime's default: a respawn without one leaves the match
            p.frozen = false
            -- H.respawnDelayMs: true comes first, the body stands later, as on the platform
            if H.respawnDelayMs then
                p.life = "respawnpending"
                local delay = H.respawnDelayMs
                CreateThread(function()
                    Wait(delay)
                    if p.life == "respawnpending" then p.life = "alive" end
                end)
            end
            return true
        end,
        teleport = function(id, position, opts)
            local p = checked(id)
            if not p then return nil, "no_player" end
            opts = opts or {}
            H.teleports[#H.teleports + 1] = { id = id, position = position, opts = opts, at = #H.coreLog }
            if H.teleportRefused then return nil, "player_not_ready" end
            -- The move runs whether or not anybody awaits it.
            local outcome
            CreateThread(function()
                Wait(200)
                if H.teleportFails then outcome = { nil, "settle_timeout" } return end
                if opts.bucket ~= nil and opts.bucket ~= p.bucket then p.frozen = false end
                p.x, p.y, p.z = position.x, position.y, position.z
                if opts.bucket ~= nil then p.bucket = opts.bucket end
                outcome = { { x = p.x, y = p.y, z = p.z, state = "settled" } }
            end)
            return { await = function()
                while outcome == nil do Wait(50) end
                return outcome[1], outcome[2]
            end }
        end,
    },
}
H.coreLog = {}

function SetPlayerRoutingBucket(id, bucket)
    local p = H.players[id]
    if p then p.bucket = bucket end
    H.forcedBuckets = (H.forcedBuckets or 0) + 1
    return true
end
function SetRoutingBucketPopulationEnabled(bucket, enabled) H.population = { bucket, enabled } return true end
function SetRoutingBucketEntityLockdownMode(bucket, mode) H.lockdown = { bucket, mode } return true end

-- Kill, as the platform reports it: one or both events, in any order.
function H.die(id, killer)
    local p = H.players[id]
    p.life = "dead"
    p.frozen = false
    H.fire("open77:playerDied", id, killer and { killer = killer } or "{}")
    if killer then H.fire("open77:playerKilled", id, killer) end
end

-- ---------------------------------------------------------------- weapons --

H.weapons = {}      -- playerId -> { [slot] = record }
H.weaponLog = {}
H.weaponRequests = {}
H.autoWeapons = true
local requestSeq = 0

function H.hash(record) return ("0x00%08x"):format(#record * 7919 + record:byte(-9)) end

local function request(operation, playerId, extra)
    requestSeq = requestSeq + 1
    local entry = { id = "req" .. requestSeq, operation = operation, playerId = playerId }
    for key, value in pairs(extra or {}) do entry[key] = value end
    H.weaponLog[#H.weaponLog + 1] = entry
    H.weaponRequests[#H.weaponRequests + 1] = entry
    return entry.id
end

function H.completeWeapons()
    local list = H.weaponRequests
    H.weaponRequests = {}
    for _, entry in ipairs(list) do
        local result = entry.operation == "assign" and { tweakDbId = H.hash(entry.record) } or {}
        H.fire("open77:weapons:completed", entry.playerId, entry.id, entry.operation, true, nil, result)
    end
    H.answerKits()
end

Open77.weapons = {
    assign = function(id, record, slot, options)
        H.weapons[id] = H.weapons[id] or {}
        H.weapons[id][slot] = record
        return request("assign", id, { record = record, slot = slot, options = options })
    end,
    remove = function(id, slot)
        if H.weapons[id] then H.weapons[id][slot] = nil end
        return request("remove", id, { slot = slot })
    end,
    clear = function(id)
        H.weapons[id] = nil
        return request("clear", id)
    end,
    holster = function(id) return request("holster", id) end,
    setAmmo = function(id, slot, amounts) return request("setAmmo", id, { slot = slot, amounts = amounts }) end,
    setActive = function(id, slot) return request("setActive", id, { slot = slot }) end,
}

function H.weaponCount(id)
    local n = 0
    for _ in pairs(H.weapons[id] or {}) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------- combat --

H.scopes, H.teams, H.arbiters = {}, {}, {}
H.scopeRefusal = nil
H.scopesCreated = {}
local scopeSeq = 0

Open77.combat = {
    createScope = function(def)
        H.scopesCreated[#H.scopesCreated + 1] = def
        if H.scopeRefusal then return nil, H.scopeRefusal end
        if #def.players < 2 or #def.players > 32 then return nil, "invalid_scope" end
        local mine = 0
        for _ in pairs(H.scopes) do mine = mine + 1 end
        if mine >= 8 then return nil, "scope_limit" end
        local seen = {}
        for _, id in ipairs(def.players) do
            local p = H.players[id]
            if seen[id] or not p or p.bucket ~= def.bucket or p.life ~= "alive" then return nil, "player_unavailable" end
            for _, scope in pairs(H.scopes) do
                if scope.set[id] then return nil, "player_scoped" end
            end
            seen[id] = true
        end
        scopeSeq = scopeSeq + 1
        local id = "scope" .. scopeSeq
        H.scopes[id] = { bucket = def.bucket, players = def.players, set = seen }
        return id
    end,
    removeScope = function(id)
        if not H.scopes[id] then return nil, "scope_unavailable" end
        H.scopes[id] = nil
        return true
    end,
    setTeam = function(id, team) H.teams[id] = team return true end,
    onDamage = function(fn) H.arbiters[#H.arbiters + 1] = fn return fn end,
}

function H.scopeCount()
    local n = 0
    for _ in pairs(H.scopes) do n = n + 1 end
    return n
end

-- A hit through the arbiters: true when nothing refused it.
function H.hit(attacker, victim, weapon, extra)
    local event = { victim = victim, attacker = attacker, amount = 20, attackKind = "ranged", bodyPart = "torso", weaponTdbId = weapon }
    for key, value in pairs(extra or {}) do event[key] = value end
    for _, fn in ipairs(H.arbiters) do
        if fn(event) == false then return false end
    end
    return true
end

H.screens = {}
Open77.effects = {
    screen = function(id, name, options) H.screens[#H.screens + 1] = { id = id, name = name, options = options } return true end,
}

-- ---------------------------------------------------------------- core stub --

-- The core's own rules and import data: a game test plays what the core would deliver. Nothing
-- at runtime reads across resources; only these tests do.
local CORE_DIR = "../../gamemodes/op77_lightrp/server/"
dofile(CORE_DIR .. "config/game_maps_seed.lua")
dofile(CORE_DIR .. "modules/game_map_rules.lua")
dofile(CORE_DIR .. "config/missions.lua") -- the kits a game may name
local Rules = LightRpGameMapRules
H.seedData = LightRpGameMapSeed

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = deepCopy(item) end
    return out
end
H.deepCopy = deepCopy

-- The core's temporary kits: what it holds (the real work is proved by the core's own
-- tests/activity_kits_test.lua). A hand lands in the slots at once; its report waits for
-- H.completeWeapons, as the requests do, and for the body to stand, as the core's hand does.
-- H.kitFails[id]: that delivery ends "failed".
H.kits, H.kitReports, H.kitFails = {}, {}, {}
local handSeq = 0

local function kitResolved(kit)
    if kit == nil then return LightRpRaid.loadouts[1] end
    if type(kit) == "table" then return kit end
    for _, entry in ipairs(LightRpRaid.loadouts) do
        if entry.id == kit then return entry end
    end
    return nil
end

function H.kitReport(id, entry, state)
    local weapons = {}
    for slot, record in ipairs({ entry.kit.primary, entry.kit.secondary }) do
        weapons[slot] = { slot = slot, tweakDbId = H.hash(record) }
    end
    H.fire("op77_lightrp:activity:kit", id, entry.activity, { hand = entry.hand, kit = entry.kit.id, state = state,
        weapons = state == "failed" and {} or weapons })
end

function H.answerKits()
    local list = H.kitReports
    H.kitReports = {}
    for _, open in ipairs(list) do
        local entry = H.kits[open.id]
        local body = H.players[open.id]
        if entry and entry.hand == open.hand then
            if body and body.life ~= "alive" and not H.kitFails[open.id] then H.kitReports[#H.kitReports + 1] = open
            else H.kitReport(open.id, entry, H.kitFails[open.id] and "failed" or "armed") end
        end
    end
end

-- Every way out of the core ends here.
function H.kitGone(id)
    if H.kits[id] then H.weapons[id] = nil end
    H.kits[id] = nil
end

-- A stand-in for op77_lightrp's side of the contract.
H.core = {
    registered = {}, owner = {}, returns = {}, pending = {},
    schemas = {}, refuseSchema = false,
    mapsReady = true,     -- false: the core answers ready = false (starting, or no database)
    maps = {},            -- game -> { { id, name, revision, enabled, ...fields } }
    mapFetches = 0,
    eligible = {},        -- playerId -> reason: refused
    enterRefused = {},    -- playerId -> reason: activityEnter refused only
    refuseRegister = false, leaveFails = false,
}
local core = H.core

function H.resetMaps()
    core.maps = {}
    for game, list in pairs(H.seedData) do
        core.maps[game] = {}
        for index, raw in ipairs(list) do
            local map = deepCopy(raw)
            map.revision = 1
            core.maps[game][index] = map
        end
    end
end
H.resetMaps()

-- The enabled maps of a game, by name, as the core's index keeps them: valid under the schema
-- the provider gave, 8 at most.
local function playable(game)
    local entry = core.schemas[game]
    local list = {}
    for _, raw in ipairs(core.maps[game] or {}) do
        if raw.enabled then
            local map = Rules.sanitize(entry.schema, raw)
            if map and #Rules.problems(entry.schema, map) == 0 then list[#list + 1] = raw end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- What a game test reads: the maps the provider holds, with its derived fields.
function H.mapsOf(key) return GamesActivity.definition("games." .. key).maps end
function H.mapOf(key, id)
    for _, map in ipairs(H.mapsOf(key)) do if map.id == id then return map end end
    error("no map " .. id .. " in " .. key)
end
-- The import data as it stands (a fixture for a mode of a test's own).
function H.seedOf(key)
    local list = {}
    for _, raw in ipairs(H.seedData["games." .. key]) do
        if raw.enabled then list[#list + 1] = deepCopy(raw) end
    end
    return list
end
-- Staff changed a game: the signal the core raises, nothing more.
function H.signalMaps(game)
    H.fire("op77_lightrp:gamemaps:changed", game)
end

local function note(name, ...) H.coreLog[#H.coreLog + 1] = { name = name, args = table.pack(...) } end
H.notices = {}

H.coreExports = {
    activityRegister = function(_, def)
        note("activityRegister", def)
        if core.refuseRegister then return false, "core_not_ready" end
        core.registered[def.id] = def
        return true
    end,
    activityCheck = function(_, id, activityId)
        note("activityCheck", id, activityId)
        if core.eligible[id] then return false, core.eligible[id] end
        if core.owner[id] then return false, "You are already in an activity." end
        return true
    end,
    activityEnter = function(_, id, activityId)
        note("activityEnter", id, activityId)
        local verdict = core.eligible[id] or core.enterRefused[id]
        if verdict then return false, verdict end
        local p = H.players[id]
        core.owner[id] = activityId
        core.pending[id] = nil
        core.returns[id] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
        return true
    end,
    activityLeave = function(_, id, activityId, opts)
        note("activityLeave", id, activityId, opts)
        if core.leaveFails then return false, "refused" end
        if core.owner[id] ~= activityId then
            if core.pending[id] == activityId then core.pending[id] = nil return true end
            return false, "not_owner"
        end
        core.owner[id] = nil
        H.kitGone(id)
        if opts == nil or opts.returnPlayer ~= false then H.coreReturn(id) end
        return true
    end,
    activityOwner = function(_, id) return core.owner[id] end,
    activityKit = function(_, id, activityId, kit, opts)
        note("activityKit", id, activityId, kit, opts)
        if core.owner[id] ~= activityId then return false, "That player is not in this activity." end
        local resolved = kitResolved(kit)
        if resolved == nil then return false, "That kit does not exist." end
        handSeq = handSeq + 1
        H.kits[id] = { hand = handSeq, activity = activityId, kit = resolved, opts = opts }
        H.weapons[id] = { [1] = resolved.primary, [2] = resolved.secondary }
        H.kitReports[#H.kitReports + 1] = { id = id, hand = handSeq }
        return true, handSeq
    end,
    activityKitTake = function(_, id, activityId, opts)
        note("activityKitTake", id, activityId, opts)
        if core.owner[id] ~= activityId then return false, "That player is not in this activity." end
        local entry = H.kits[id]
        if entry == nil or (type(opts) == "table" and opts.hand ~= nil and opts.hand ~= entry.hand) then return false, "stale" end
        H.kitGone(id)
        return true
    end,
    gameMapSchema = function(_, def)
        note("gameMapSchema", def.id)
        if core.refuseSchema then return false, "core_not_ready" end
        local schema, why = Rules.schema(def.schema)
        if not schema then return false, why end
        core.schemas[def.id] = { id = def.id, label = def.label, schema = schema }
        return true
    end,
    gameMapIndex = function(_, game)
        note("gameMapIndex", game)
        if not core.mapsReady or not core.schemas[game] then return { ready = false } end
        local rows = {}
        for index, raw in ipairs(playable(game)) do
            if index > Rules.MAX_ENABLED then break end
            rows[index] = { id = raw.id, revision = raw.revision }
        end
        return { ready = true, maps = rows }
    end,
    gameMap = function(_, game, id)
        core.mapFetches = core.mapFetches + 1
        for _, raw in ipairs(playable(game)) do
            if raw.id == id then
                local map = Rules.sanitize(core.schemas[game].schema, raw)
                map.id, map.enabled = raw.id, nil
                return map
            end
        end
        return nil
    end,
    activityBots = function() return false end,
    activityPlayer = function(_, id)
        local p = H.players[id]
        if not p then return nil end
        return { name = p.name, identifier = "license:" .. id, characterKey = "char1" }
    end,
    notice = function(_, id, def) H.notices[#H.notices + 1] = { id = id, def = def } return true end,
}
exports = { op77_lightrp = H.coreExports }

function H.coreReturn(id)
    local back, p = core.returns[id], H.players[id]
    if back and p then
        if p.life ~= "alive" then p.life = "alive" end
        p.x, p.y, p.z, p.bucket = back.x, back.y, back.z, back.bucket
    end
end

function H.coreCalls(name, id)
    local found = {}
    for _, c in ipairs(H.coreLog) do
        if c.name == name and (id == nil or c.args[1] == id) then found[#found + 1] = c end
    end
    return found
end

function H.noticeFor(id, pattern)
    for _, n in ipairs(H.notices) do
        if n.id == id and (pattern == nil or tostring(n.def.body):find(pattern)) then return n end
    end
    return nil
end

H.coreGone = setmetatable({}, { __index = function() error("op77_lightrp is not running") end })

-- The core stops cleanly: it moves its players back and tells the provider, then the host
-- raises onResourceStop.
function H.coreStop()
    for id, activityId in pairs(core.owner) do
        H.kitGone(id)
        H.coreReturn(id)
        H.fire("op77_lightrp:activity:dropped", id, activityId, "core_stopped")
    end
    core.owner = {}
    core.registered = {}
    H.fire("onResourceStop", "op77_lightrp")
    exports.op77_lightrp = H.coreGone
end

-- The core dies with no word: its exports raise, its owners are lost, players stay put.
function H.coreCrash()
    H.kits = {}
    core.owner = {}
    core.registered = {}
    exports.op77_lightrp = H.coreGone
end

function H.coreStart()
    exports.op77_lightrp = H.coreExports
    H.fire("onResourceStart", "op77_lightrp")
    H.fire("op77_lightrp:activity:ready")
end

-- This resource stops: its handlers run, then the core returns what it held for us.
function H.providerStop()
    H.fire("onResourceStop", "op77_games")
    for id, activityId in pairs(core.owner) do
        core.owner[id] = nil
        H.kitGone(id)
        H.coreReturn(id)
    end
    core.registered = {}
end

-- ---------------------------------------------------------------- loading --

-- The manifest is the load list: a script missing from it fails here too.
function H.scripts(kind)
    local list = {}
    for line in io.lines("open77.lua") do
        local path = line:match("^" .. kind .. '%s+"([^"]+)"')
        if path then list[#list + 1] = path end
    end
    return list
end

function H.loadServer()
    for _, kind in ipairs({ "shared_script", "server_script" }) do
        for _, file in ipairs(H.scripts(kind)) do dofile(file) end
    end
    H.fire("onResourceStart", "op77_games")
    runReady()
end

-- A new VM after a stop: its handlers replace the old one's.
function H.reload()
    H.handlers, H.netHandlers, H.arbiters = {}, {}, {}
    H.loadServer()
end

-- ---------------------------------------------------------------- helpers --

-- Every player of `ids` joins one Light RP match. `options` adds to each join.
local matchSeq = 0
function H.matchJoin(activityId, ids, options)
    matchSeq = matchSeq + 1
    options = options or {}
    local players = table.move(ids, 1, #ids, 1, {})
    for _, id in ipairs(ids) do
        core.pending[id] = activityId
        local join = { ranked = false, map = options.map, from = options.from, match = { id = options.id or ("match:" .. matchSeq), ranked = false, friendly = true,
            players = players, teams = options.teams } }
        H.fire("op77_lightrp:activity:join", id, activityId, join)
    end
end

-- A join from the panel: no options.match.
function H.panelJoin(id, activityId, options)
    core.pending[id] = activityId
    H.fire("op77_lightrp:activity:join", id, activityId, options or { ranked = true })
end

-- Until the match of this player reaches this phase, weapons answered as they go.
function H.untilPhase(id, phase, limitMs)
    local spent = 0
    while spent <= (limitMs or 60000) do
        local match = GamesEngine.matchOf(id)
        if match and match.phase == phase then return match end
        H.advance(100)
        if H.autoWeapons then H.completeWeapons() end
        spent = spent + 100
    end
    error("never reached phase " .. phase)
end

-- Lets the tick run with nothing else going on.
function H.settle(ms)
    local spent = 0
    while spent < ms do
        H.advance(100)
        if H.autoWeapons then H.completeWeapons() end
        spent = spent + 100
    end
end

function H.inGamesBucket(id)
    local b = H.players[id] and H.players[id].bucket
    return b ~= nil and b >= 4500000 and b <= 4599999
end

function H.noneInBuckets()
    for id in pairs(H.players) do
        if H.inGamesBucket(id) then error(("player %d stranded in bucket %d"):format(id, H.players[id].bucket), 2) end
    end
    return true
end

-- ---------------------------------------------------------------- asserts --

function H.eq(actual, expected, message)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(message or "assertion", tostring(expected), tostring(actual)), 2)
    end
end
function H.ok(value, message)
    if not value then error((message or "assertion failed"), 2) end
    return value
end

local passed = 0
function H.test(name, fn)
    fn()
    passed = passed + 1
    realPrint("  ok  " .. name)
end
function H.done(name) realPrint(("%s: %d passed"):format(name, passed)) end

return H
