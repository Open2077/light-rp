-- Shared fake host for tests/bots_test.lua and tests/pve_test.lua: a fake Light RP
-- (activity exports, activityBots, events), a fake world (TurfWorld replaced) and a fake
-- Open77.npcs (bodies, presence, damage, attitudes, relationships, tasks), then the real
-- server wiring (server/main.lua). Returns a table of handles and helpers.
local T = { logs = {} }
T.realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    T.logs[#T.logs + 1] = table.concat(parts, " ")
end

-- ---------------------------------------------------------------- host
local host = { handlers = {}, net = {}, commands = {}, exports = {}, threads = {}, damage = nil, offDamage = {} }
local core = { registered = {}, registerCount = 0, owned = {}, busy = {}, players = {}, enters = {}, leaves = {},
    results = {}, statuses = {}, announces = {}, bots = false, botsCalls = 0 }
T.host, T.core = host, core

-- ---------------------------------------------------------------- fake Open77.npcs
-- 64-bit ids, as the platform hands them: keyed by their text on our side.
local npc = { bodies = {}, nextId = math.tointeger(8070450532247928833), created = {}, removed = {}, applied = {},
    attitudes = {}, relations = {}, tasks = {}, refuse = {}, deaths = {}, presenceCalls = 0 }
T.npc = npc

local function body(id) return npc.bodies[tostring(id)] end
T.body = body

_G.Open77 = {
    exports = {
        callSync = function(resource, name, ...)
            assert(resource == "op77_lightrp")
            local a = { ... }
            if name == "activityRegister" then
                core.registered[a[1].id] = a[1]; core.registerCount = core.registerCount + 1
                return true
            elseif name == "activityBots" then
                core.botsCalls = core.botsCalls + 1
                return core.bots
            elseif name == "activityCheck" then
                local id = a[1]
                if core.busy[id] then return false, core.busy[id] end
                if core.owned[id] and core.owned[id] ~= a[2] then return false, "You are busy elsewhere." end
                return true
            elseif name == "activityEnter" then
                local id = a[1]
                if core.owned[id] then return false, "Already in an activity." end
                core.owned[id] = a[2]; core.enters[#core.enters + 1] = { id = id, activity = a[2] }
                return true
            elseif name == "activityLeave" then
                local id = a[1]
                if core.owned[id] ~= a[2] then return false, "That player is not in this activity." end
                core.owned[id] = nil; core.leaves[#core.leaves + 1] = { id = id, activity = a[2], opts = a[3] }
                return true
            elseif name == "activityOwner" then return core.owned[a[1]]
            elseif name == "activityPlayer" then return core.players[a[1]] end
            error("unknown export " .. tostring(name))
        end,
    },
    time = { monotonic = function() return 0 end },
    combat = {
        onDamage = function(fn) host.damage = fn; return fn end,
        offDamage = function(fn) host.offDamage[#host.offDamage + 1] = fn; return true end,
    },
    players = {
        damage = function(id, amount, opts)
            T.playerDamage[#T.playerDamage + 1] = { id = id, amount = amount, attacker = opts and opts.attacker, cause = opts and opts.cause }
            return true
        end,
    },
    npcs = {
        ai = { native = 2, scripted = 1 },
        damage = { mortal = 0, invulnerable = 1 },
        channels = { movement = 1 },
        create = function(def)
            local name = def.record or def.template
            if npc.refuse[name] then return nil, npc.refuse[name] end
            local id = npc.nextId
            npc.nextId = npc.nextId + 1
            npc.bodies[tostring(id)] = { id = id, def = def, pos = { x = def.position.x, y = def.position.y, z = def.position.z },
                bucket = def.bucket, alive = true, health = def.health, authority = 1 }
            npc.created[#npc.created + 1] = { id = id, def = def }
            return id
        end,
        remove = function(id)
            npc.bodies[tostring(id)] = nil
            npc.removed[#npc.removed + 1] = id
            return true
        end,
        presence = function(id)
            npc.presenceCalls = npc.presenceCalls + 1
            local b = body(id)
            if not b then return nil, "npc_not_found" end
            return { x = b.pos.x, y = b.pos.y, z = b.pos.z, bucket = b.bucket, alive = b.alive, authorityPlayerId = b.authority }
        end,
        get = function(id)
            local b = body(id)
            if not b then return nil, "npc_not_found" end
            return { id = b.id, position = b.pos, bucket = b.bucket, health = b.health }
        end,
        all = function()
            local list = {}
            for _, b in pairs(npc.bodies) do list[#list + 1] = { id = b.id, resource = b.resource or "op77_turf" } end
            return list
        end,
        applyDamage = function(id, amount, tag, cause)
            local b = body(id)
            if not b or not b.alive then return false, "npc_not_found" end
            npc.applied[#npc.applied + 1] = { id = id, amount = amount, tag = tag, cause = cause }
            b.health = b.health - amount
            if b.health <= 0 then
                b.alive = false
                npc.deaths[#npc.deaths + 1] = { id = id, tag = tag, cause = cause }
            end
            return true
        end,
        setAttitude = function(id, attitude, opts)
            npc.attitudes[#npc.attitudes + 1] = { id = id, attitude = attitude, towards = opts and opts.towards }
            return true
        end,
        setRelationship = function(a, b, attitude)
            npc.relations[#npc.relations + 1] = { a = a, b = b, attitude = attitude }
            return true
        end,
        tasks = {
            guard = function(id, point, radius, opts)
                npc.tasks[#npc.tasks + 1] = { id = id, kind = "guard", point = point, radius = radius }
                return "t" .. #npc.tasks
            end,
            moveTo = function(id, point, opts)
                npc.tasks[#npc.tasks + 1] = { id = id, kind = "moveTo", point = point, opts = opts }
                return "t" .. #npc.tasks
            end,
            clear = function(id, channel, reason)
                npc.tasks[#npc.tasks + 1] = { id = id, kind = "clear", channel = channel, reason = reason }
                return true
            end,
        },
    },
}
T.playerDamage = {}

_G.TriggerEvent = function(name, ...)
    local a = table.pack(...)
    if name == "op77_lightrp:activity:result" then core.results[#core.results + 1] = { id = a[1], activity = a[2], result = a[3] }
    elseif name == "op77_lightrp:activity:status" then core.statuses[#core.statuses + 1] = { activity = a[1], status = a[2] }
    elseif name == "op77_lightrp:announce" then core.announces[#core.announces + 1] = a[1] end
end
_G.TriggerClientEvent = function() end
_G.AddEventHandler = function(name, fn) host.handlers[name] = host.handlers[name] or {}; table.insert(host.handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) host.net[name] = fn end
_G.RegisterCommand = function(name, fn, restricted) host.commands[name] = { fn = fn, restricted = restricted } end
_G.exports = function(name, fn) host.exports[name] = fn end
_G.CreateThread = function(fn) host.threads[#host.threads + 1] = fn end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_turf" end
_G.GetPlayers = function() return {} end

dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/core.lua")
dofile("server/world.lua")
dofile("server/bots.lua")
dofile("server/influence.lua")
dofile("server/war.lua")
dofile("client/hud.lua")

-- Influence writes are counted (a bot war or a sweep must never make one).
T.influenceRecords = 0
local realRecord = TurfInfluence.record
TurfInfluence.record = function(...)
    T.influenceRecords = T.influenceRecords + 1
    return realRecord(...)
end

-- ---------------------------------------------------------------- fake world
local clock = 1000000
local pl, teams, frozen, equips, respawns, sites, pushes, notes, pending, cleared = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
T.pl, T.teams, T.frozen, T.equips, T.respawns, T.sites, T.pushes, T.notes, T.cleared = pl, teams, frozen, equips, respawns,
    sites, pushes, notes, cleared
T.states = {}

local W = TurfWorld
W.now = function() return clock end
W.unix = function() return 1793577600 + clock // 1000 end
W.position = function(id)
    assert(math.type(id) == "integer" and id > 0, "a player native was handed a non-player id: " .. tostring(id))
    local p = pl[id]
    if not p or not p.connected or not p.pos then return nil end
    return { x = p.pos.x, y = p.pos.y, z = p.pos.z, bucket = p.pos.bucket }
end
W.phase = function(id)
    assert(math.type(id) == "integer" and id > 0, "a player native was handed a non-player id: " .. tostring(id))
    return pl[id] and pl[id].phase or nil
end
W.name = function(id)
    assert(math.type(id) == "integer" and id > 0, "a player native was handed a non-player id: " .. tostring(id))
    return "P" .. id
end
W.connected = function(id) return pl[id] ~= nil and pl[id].connected == true end
W.setupBucket = function() end
W.place = function(id, point, bucket, done) pending[#pending + 1] = { id = id, point = point, bucket = bucket, done = done } end
W.teleport = function(id, point, bucket) pl[id].pos = { x = point.x, y = point.y, z = point.z, bucket = bucket } end
W.respawn = function(id, point, bucket)
    if not W.isDown(pl[id].phase) then return false, "not_dead" end
    respawns[#respawns + 1] = { id = id, point = point, at = clock }
    pl[id].phase = "alive"
    pl[id].pos = { x = point.x, y = point.y, z = point.z, bucket = bucket }
    return true
end
W.respawnInPlace = function(id, bucket) return W.respawn(id, pl[id].pos, bucket) end
W.freeze = function(id, v) frozen[id] = v; return true end
W.setTeam = function(id, team)
    assert(math.type(id) == "integer" and id > 0, "setTeam on a non-player id: " .. tostring(id))
    teams[id] = team; return true
end
W.createScope = function() return "scope" end
W.removeScope = function() return true end
W.equip = function(id, kit) equips[#equips + 1] = { id = id, kit = kit.id, at = clock } end
W.clearKit = function() return true end
W.state = function(id, shared, personal) T.states[id] = { shared = shared, personal = personal } end
W.board = function(id, rows) T.boards = T.boards or {}; T.boards[id] = rows end
W.site = function(id, payload) sites[id] = payload end
W.push = function(id, kind, payload) pushes[#pushes + 1] = { id = id, kind = kind, payload = payload } end
W.clear = function(id) cleared[id] = (cleared[id] or 0) + 1 end
W.notify = function(id, kind, message) notes[#notes + 1] = { id = id, kind = kind, message = message } end
W.reply = function(source, raw, ok, text) T.lastReply = { ok = ok, text = text } end
W.pose = function(id) return W.position(id), 90 end

dofile("server/main.lua")

-- ---------------------------------------------------------------- helpers
T.CFG, T.R, T.B, T.H = TurfConfig, TurfRules, TurfBots, TurfHud

function T.now() return clock end
function T.setClock(v) clock = v end

function T.fire(name, src, ...)
    _G.source = src
    for _, h in ipairs(host.handlers[name] or {}) do h(...) end
    _G.source = nil
end
function T.net(name, src, ...) _G.source = src; host.net[name](...); _G.source = nil end
function T.command(name, src, args) _G.source = src; host.commands[name].fn(src, args or {}, name); _G.source = nil end

-- Platform deaths raised by applyDamage are delivered on the next tick, like the host.
local function drainDeaths()
    local list = npc.deaths
    npc.deaths = {}
    for _, d in ipairs(list) do T.fire("onNpcDied", nil, d.id, d.tag, d.cause) end
end
T.drainDeaths = drainDeaths

-- The tick thread: Turf.tick at 4 Hz, the hub statuses once a second (both activities
-- while the fake core knows them).
local lastStatusAt = clock
function T.advance(ms)
    local target = clock + ms
    while clock < target do
        clock = math.min(target, clock + 250)
        drainDeaths()
        Turf.tick(clock)
        if clock - lastStatusAt >= 1000 then
            lastStatusAt = clock
            TurfCore.status(Turf.status(clock), false, nil, clock)
            if core.registered["turf.pve"] then TurfCore.status(Turf.pveStatus(clock), false, "turf.pve", clock) end
        end
    end
end

function T.flush(fail)
    local list = pending
    pending = {}
    for _, p in ipairs(list) do
        if fail and fail[p.id] then p.done(false, "teleport_failed")
        else
            pl[p.id].pos = { x = p.point.x, y = p.point.y, z = p.point.z, bucket = p.bucket }
            if W.isDown(pl[p.id].phase) then pl[p.id].phase = "alive" end
            p.done(true)
        end
    end
end

local GANGS = { valentinos = "Valentinos", maelstrom = "Maelstrom", tyger_claws = "Tyger Claws", animals = "Animals",
    voodoo_boys = "Voodoo Boys" }
function T.addPlayer(id, gang)
    pl[id] = { pos = { x = -756.6, y = 777.3, z = 22.5, bucket = 0 }, phase = "alive", connected = true }
    core.players[id] = { name = "P" .. id, identifier = "license:" .. id, characterKey = "c" .. id,
        gang = gang and { id = gang, label = GANGS[gang], grade = 1 } or nil }
end
function T.at(id, x, y, z, bucket) pl[id].pos = { x = x, y = y, z = z, bucket = bucket } end

function T.statusOf(activity)
    for i = #core.statuses, 1, -1 do
        if core.statuses[i].activity == activity then return core.statuses[i].status end
    end
end
function T.resultOf(id, from)
    for i = #core.results, from or 1, -1 do if core.results[i].id == id then return core.results[i] end end
end
function T.pushed(id, kind, pattern, from)
    for i = from or 1, #pushes do
        local p = pushes[i]
        if p.id == id and p.kind == kind and (pattern == nil or tostring(p.payload.title or p.payload.text):find(pattern)) then return p end
    end
end
function T.noted(id, pattern, from)
    for i = from or 1, #notes do if notes[i].id == id and notes[i].message:find(pattern) then return notes[i] end end
end
function T.logged(pattern, from)
    for i = from or 1, #T.logs do if T.logs[i]:find(pattern) then return T.logs[i] end end
end

-- The live bodies of a war's bots on a side (bots with a body).
function T.bodiesOf(war, side)
    local list = {}
    for _, b in ipairs(war.bots or {}) do
        if b.npcId ~= nil and (side == nil or b.side == side) then list[#list + 1] = b end
    end
    return list
end
function T.liveBodies()
    local n = 0
    for _ in pairs(npc.bodies) do n = n + 1 end
    return n
end
-- A bot's body stands here (the platform's canonical position).
function T.botAt(bot, x, y, z)
    local b = body(bot.npcId)
    b.pos = { x = x, y = y, z = z }
end
function T.endsWith(list, pattern)
    for _, v in ipairs(list) do if tostring(v):find(pattern) then return true end end
    return false
end

function T.run(name, main, summary)
    local ok, err = xpcall(main, debug.traceback)
    if not ok then
        T.realPrint(table.concat(T.logs, "\n", math.max(1, #T.logs - 50)))
        error(err, 0)
    end
    T.realPrint(("PASS %s: %s"):format(name, summary))
end

return T
