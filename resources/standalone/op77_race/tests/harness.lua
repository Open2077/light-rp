-- Test harness for op77_race: a fake Open77 runtime (players, vehicles, effects, io,
-- notifications, clock), a coroutine scheduler for CreateThread / Wait / SetTimeout,
-- event buses, and a stub of the op77_lightrp activity contract. Run from the
-- resource root (tests/run-lua.ps1 sets the working directory).
local H = {}

-- ---------------------------------------------------------------- clock + threads --

H.clock = 0
local threads, timers = {}, {}

function CreateThread(fn)
    threads[#threads + 1] = { co = coroutine.create(fn), wakeAt = H.clock }
end
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

-- Advances the fake clock in steps, running every due thread and timer.
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
H.verbose = false
local realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    local line = table.concat(parts, " ")
    H.logs[#H.logs + 1] = line
    if H.verbose then realPrint(line) end
end
H.print = realPrint
function H.logged(pattern)
    for _, line in ipairs(H.logs) do if line:find(pattern) then return true end end
    return false
end

-- ---------------------------------------------------------------- json --

local function encode(value, out)
    local kind = type(value)
    if kind == "nil" then out[#out + 1] = "null"
    elseif kind == "boolean" then out[#out + 1] = tostring(value)
    elseif kind == "number" then out[#out + 1] = (math.type(value) == "integer" and tostring(value)) or string.format("%.14g", value)
    elseif kind == "string" then out[#out + 1] = '"' .. value:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
    elseif kind == "table" then
        if #value > 0 or next(value) == nil then
            out[#out + 1] = "["
            for i, child in ipairs(value) do if i > 1 then out[#out + 1] = "," end encode(child, out) end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            for key, child in pairs(value) do
                if not first then out[#out + 1] = "," end
                first = false
                encode(tostring(key), out); out[#out + 1] = ":"; encode(child, out)
            end
            out[#out + 1] = "}"
        end
    else error("cannot encode " .. kind) end
end
json = { encode = function(value) local out = {}; encode(value, out); return table.concat(out) end }

-- ---------------------------------------------------------------- events --

H.handlers, H.netHandlers, H.commands = {}, {}, {}
H.events, H.clientEvents = {}, {}

function AddEventHandler(name, fn)
    H.handlers[name] = H.handlers[name] or {}
    table.insert(H.handlers[name], fn)
end
function RegisterNetEvent(name, fn)
    if fn then H.netHandlers[name] = fn end
end
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
function RegisterCommand(name, fn, restricted) H.commands[name] = { fn = fn, restricted = restricted } end
function GetCurrentResourceName() return "op77_race" end

-- Delivers a host event to every handler (what TriggerEvent from another resource does).
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
function H.command(name, playerId, args, raw)
    local entry = assert(H.commands[name], "no command " .. name)
    args = args or {}
    args.n = #args
    entry.fn(playerId, args, raw or name)
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
H.notices = {}
function H.addPlayer(id, name, position)
    position = position or { x = 0, y = 0, z = 0 }
    H.players[id] = { name = name or ("P" .. id), x = position.x, y = position.y, z = position.z, bucket = position.bucket or 0,
        life = "alive", godMode = false, frozen = false }
    return H.players[id]
end
function H.move(id, x, y, z)
    local p = H.players[id]
    p.x, p.y, p.z = x, y, z
end

local function checked(id)
    if math.type(id) ~= "integer" or id < 1 then error("id must be positive (uncatchable in the real runtime)") end
    return H.players[id]
end

H.teleports, H.respawns, H.effects = {}, {}, {}
H.teleportFails = false

Open77 = {
    time = { monotonic = function() return H.clock / 1000 end },
    players = {
        name = function(id) local p = checked(id); return p and p.name or nil end,
        position = function(id)
            local p = checked(id)
            return p and { x = p.x, y = p.y, z = p.z, bucket = p.bucket } or nil
        end,
        getHealth = function(id) local p = checked(id); return p and { godMode = p.godMode } or nil end,
        setGodMode = function(id, value) local p = checked(id); if not p then return false, "no_player" end p.godMode = value == true; return true end,
        setFrozen = function(id, value)
            local p = checked(id)
            if not p or p.life ~= "alive" then return false, "not_alive" end
            p.frozen = value == true
            return true
        end,
        getLifeState = function(id) local p = checked(id); return p and { phase = p.life } or nil end,
        respawn = function(id, opts)
            local p = checked(id)
            if not p or p.life ~= "dead" then return false, "not_dead" end
            H.respawns[#H.respawns + 1] = { id = id, opts = opts }
            p.life, p.x, p.y, p.z = "alive", opts.position.x, opts.position.y, opts.position.z
            p.bucket = opts.bucket or p.bucket
            p.frozen = false
            return true
        end,
        teleport = function(id, position, opts)
            local p = checked(id)
            if not p then return nil, "no_player" end
            opts = opts or {}
            local record = { id = id, position = position, opts = opts }
            H.teleports[#H.teleports + 1] = record
            return { await = function()
                Wait(200)
                if H.teleportFails then return nil, "teleport_failed" end
                -- A bucket change lifts a freeze, as in the runtime.
                if opts.bucket ~= nil and opts.bucket ~= p.bucket then p.frozen = false end
                p.x, p.y, p.z = position.x, position.y, position.z
                if opts.bucket ~= nil then p.bucket = opts.bucket end
                return true
            end }
        end,
    },
    effects = { play = function(name, opts) H.effects[#H.effects + 1] = { name = name, opts = opts }; return true end },
    notifications = { send = function(id, def) H.notices[#H.notices + 1] = { id = id, def = def }; return "n" end },
}

function H.noticeFor(id, pattern)
    for _, n in ipairs(H.notices) do
        if n.id == id and (pattern == nil or tostring(n.def.message):find(pattern)) then return n end
    end
    return nil
end

-- ---------------------------------------------------------------- vehicles --

H.vehicles, H.seats, H.vehicleLog = {}, {}, {}
local vehicleSequence = 0
local flags = { frozen = 1, lightsOn = 2, engineOn = 4 }
Open77.vehicles = {
    flags = flags,
    create = function(spec)
        vehicleSequence = vehicleSequence + 1
        local id = vehicleSequence
        H.vehicles[id] = { id = id, record = spec.record, x = spec.position.x, y = spec.position.y, z = spec.position.z,
            bucket = spec.bucket, flags = spec.flags or 0 }
        H.vehicleLog[#H.vehicleLog + 1] = { op = "create", id = id, spec = spec }
        return id
    end,
    get = function(id)
        local v = H.vehicles[id]
        if not v then return nil, "vehicle_not_found" end
        return { id = v.id, x = v.x, y = v.y, z = v.z, bucket = v.bucket, flags = v.flags }
    end,
    update = function(id, patch)
        local v = H.vehicles[id]
        if not v then return nil, "vehicle_not_found" end
        if patch.flags then v.flags = patch.flags end
        return true
    end,
    remove = function(id)
        if not H.vehicles[id] then return nil, "vehicle_not_found" end
        H.vehicles[id] = nil
        if H.ai then H.ai[id] = nil end -- removing the car releases its AI controller
        H.vehicleLog[#H.vehicleLog + 1] = { op = "remove", id = id }
        return true
    end,
    warpPlayerIntoVehicle = function(playerId, vehicleId, seat, opts)
        local v, p = H.vehicles[vehicleId], H.players[playerId]
        if not v or not p then return nil, "unavailable" end
        H.seats[playerId] = { vehicleId = vehicleId, seat = seat, exitLocked = opts and opts.exitLocked == true }
        p.x, p.y, p.z = v.x, v.y, v.z
        if opts and opts.moveBucket then p.bucket = v.bucket end
        return true
    end,
    getPlayerSeat = function(playerId)
        local seat = H.seats[playerId]
        if not seat then return nil end
        return { vehicleId = seat.vehicleId, seat = seat.seat, exitLocked = seat.exitLocked }
    end,
    setPlayerExitLocked = function(playerId, locked)
        if H.seats[playerId] then H.seats[playerId].exitLocked = locked end
        return true
    end,
    forcePlayerOutOfVehicle = function(playerId, vehicleId)
        H.seats[playerId] = nil
        H.vehicleLog[#H.vehicleLog + 1] = { op = "exit", id = vehicleId, player = playerId }
        return true
    end,
    setTransform = function(id, transform)
        local v = H.vehicles[id]
        if not v then return nil, "vehicle_not_found" end
        v.x, v.y, v.z = transform.position.x, transform.position.y, transform.position.z
        v.flags = 0
        return true
    end,
}

-- Drives the player (and the car they sit in) to a point.
function H.drive(id, x, y, z)
    H.move(id, x, y, z)
    local seat = H.seats[id]
    if seat and H.vehicles[seat.vehicleId] then
        local v = H.vehicles[seat.vehicleId]
        v.x, v.y, v.z = x, y, z
    end
end

-- ---------------------------------------------------------------- bot natives --

-- NPCs and the vehicle AI (bots). Installed by the tests that use them, BEFORE H.load:
-- the AI event subscription happens when server/bots.lua loads.
H.npcs, H.ai, H.aiHandlers, H.npcLog, H.aiLog = {}, {}, {}, {}, {}
H.refuseRecords, H.refuseAttach = {}, false
function H.installBotNatives()
    local npcSequence, taskSequence = 0, 0
    local function npcLog(op, id, extra) H.npcLog[#H.npcLog + 1] = { op = op, id = id, extra = extra } end
    local function aiLog(op, id, extra) H.aiLog[#H.aiLog + 1] = { op = op, id = id, extra = extra } end
    local function task(id, kind, target, opts)
        local n = H.npcs[id]
        if not n then return nil, "npc_not_found" end
        taskSequence = taskSequence + 1
        n.task = { id = taskSequence, kind = kind, target = target, opts = opts }
        npcLog(kind, id, n.task)
        return taskSequence
    end
    Open77.npcs = {
        ai = { tasks = 0, frozen = 1, native = 2 },
        damage = { mortal = 0, immortal = 1, invulnerable = 2 },
        channels = { movement = 1, look = 2, action = 3, fullBody = 4 },
        create = function(def)
            if type(def.aiMode) ~= "number" or type(def.damagePolicy) ~= "number" then error("number expected, got string") end
            if H.refuseRecords[def.record] then return nil, "npc_record_invalid" end
            npcSequence = npcSequence + 1
            local id = 7000 + npcSequence
            H.npcs[id] = { id = id, record = def.record, x = def.position.x, y = def.position.y, z = def.position.z,
                bucket = def.bucket, aiMode = def.aiMode, damagePolicy = def.damagePolicy, behavior = def.behavior,
                simulator = 1 }
            npcLog("create", id, def)
            return id
        end,
        remove = function(id)
            if not H.npcs[id] then return false end
            H.npcs[id] = nil
            npcLog("remove", id)
            return true
        end,
        get = function(id)
            local n = H.npcs[id]
            if not n then return nil end
            return { id = id, x = n.x, y = n.y, z = n.z, bucket = n.bucket, health = 100 }
        end,
        presence = function(id)
            local n = H.npcs[id]
            if not n then return nil, "npc_not_found" end
            return { id = id, x = n.x, y = n.y, z = n.z, bucket = n.bucket, alive = true, authorityPlayerId = n.simulator }
        end,
        setBucket = function(id, bucket) if H.npcs[id] then H.npcs[id].bucket = bucket end return true end,
        tasks = {
            clear = function(id) if H.npcs[id] then H.npcs[id].task = nil; npcLog("clear", id) end return true end,
            moveTo = function(id, position, opts) return task(id, "moveTo", position, opts) end,
            patrol = function(id, points, opts) return task(id, "patrol", points, opts) end,
        },
    }
    local function controller(id) return H.ai[id] end
    Open77.vehicles.ai = {
        attachDriver = function(vehicleId, opts)
            if H.refuseAttach then return nil, "ai_attach_refused" end
            if not H.vehicles[vehicleId] then return nil, "vehicle_not_found" end
            if H.ai[vehicleId] then return nil, "ai_controller_conflict" end
            H.ai[vehicleId] = { npcId = opts and opts.npcId or nil, status = "idle", routes = {}, stops = 0 }
            aiLog("attach", vehicleId, opts)
            return { vehicleId = tostring(vehicleId), status = "idle" }
        end,
        followRoute = function(vehicleId, opts)
            local c = controller(vehicleId)
            if not c then return nil, "ai_not_attached" end
            if #opts.points < 1 or #opts.points > 64 then return nil, "invalid_points" end
            c.routes[#c.routes + 1] = opts
            c.route, c.status = opts, "running"
            aiLog("route", vehicleId, opts)
            return { vehicleId = tostring(vehicleId), status = "running" }
        end,
        driveTo = function(vehicleId, opts)
            local c = controller(vehicleId)
            if not c then return nil, "ai_not_attached" end
            c.routes[#c.routes + 1] = opts
            c.status = "running"
            aiLog("driveTo", vehicleId, opts)
            return { vehicleId = tostring(vehicleId), status = "running" }
        end,
        setBehavior = function(vehicleId, behavior)
            local c = controller(vehicleId); if not c then return nil, "ai_not_attached" end
            c.behavior = behavior; return { status = c.status }
        end,
        setSpeed = function(vehicleId, speed)
            local c = controller(vehicleId); if not c then return nil, "ai_not_attached" end
            c.speed = speed; return { status = c.status }
        end,
        state = function(vehicleId)
            local c = controller(vehicleId); if not c then return nil end
            return { vehicleId = tostring(vehicleId), status = c.status }
        end,
        stop = function(vehicleId)
            local c = controller(vehicleId); if not c then return nil, "ai_not_attached" end
            c.stops, c.status = c.stops + 1, "stopped"
            aiLog("stop", vehicleId)
            return { status = c.status }
        end,
        removeDriver = function(vehicleId)
            if not H.ai[vehicleId] then return nil, "ai_not_attached" end
            H.ai[vehicleId] = nil
            aiLog("removeDriver", vehicleId)
            return { status = "detached" }
        end,
        on = function(event, handler) H.aiHandlers[event] = handler; return true end,
    }
end

-- An AI lifecycle event for this vehicle (the state carries string ids, as the runtime's).
function H.aiEvent(event, vehicleId, extra)
    local handler = H.aiHandlers[event]
    if handler == nil then return false end
    local state = { vehicleId = tostring(vehicleId) }
    for key, value in pairs(extra or {}) do state[key] = value end
    handler(state)
    runReady()
    return true
end
-- Dash (session grants) and cyberware (durable record, temporary lease), as the guides
-- "dash" and "cyberware" describe them. Installed by the tests that use them. A lease ends
-- by itself on death, a bucket change or expiry, and is restored over `restoreMs`.
H.dash, H.durable, H.leases, H.abilityLog = {}, {}, {}, {}
H.refuse = { define = false, revoke = 0, release = 0, lease = {}, grant = {} }
H.restoreMs = 500
function H.installAbilityNatives()
    local leaseSequence = 0
    local function record(op, id, extra) H.abilityLog[#H.abilityLog + 1] = { op = op, id = id, extra = extra } end
    local function lease(id)
        local l, p = H.leases[id], H.players[id]
        if l == nil then return nil end
        if l.phase == "pending" and H.clock >= l.activeAt then l.phase = "active" end
        if l.phase ~= "restoring" and (p == nil or p.life ~= "alive" or p.bucket ~= l.bucket or H.clock >= l.expiresAt) then
            l.phase, l.restoredAt = "restoring", H.clock + H.restoreMs
        end
        if l.phase == "restoring" and H.clock >= l.restoredAt then
            H.leases[id] = nil
            return nil
        end
        return l
    end
    H.leaseOf = lease
    Open77.dash = {
        define = function(def)
            record("dash.define", nil, def)
            if H.refuse.define then return nil, "dash_unavailable" end
            return { ok = true }
        end,
        grant = function(id, definition)
            record("dash.grant", id, definition)
            local g, p = H.dash[id], H.players[id]
            if g and g.owner ~= "op77_race" then return nil, "grant_owned" end
            if H.refuse.grant[id] then return nil, "body_unavailable" end
            if not p or p.life ~= "alive" then return nil, "body_unavailable" end
            H.dash[id] = { owner = "op77_race", definition = definition, readyAt = H.clock + 200 }
            return { ok = true }
        end,
        revoke = function(id)
            record("dash.revoke", id)
            if H.refuse.revoke > 0 then
                H.refuse.revoke = H.refuse.revoke - 1
                return nil, "invalid_operation"
            end
            local g = H.dash[id]
            if g and g.owner == "op77_race" then H.dash[id] = nil end
            return { ok = true }
        end,
        current = function(id)
            record("dash.current", id)
            local g = H.dash[id]
            if g == nil then return nil end
            return { projection = { status = H.clock >= (g.readyAt or 0) and "ready" or "pending" }, ownedByCaller = g.owner == "op77_race" }
        end,
    }
    Open77.cyberware = {
        define = function(def)
            record("cyber.define", nil, def)
            if H.refuse.define then return nil, "resource_stopping" end
            return { ok = true }
        end,
        current = function(id)
            record("cyber.current", id)
            local r = H.durable[id]
            if r == false then return nil end
            return r or { revision = 1 }
        end,
        leaseState = function(id)
            record("cyber.leaseState", id)
            local l = lease(id)
            if l == nil then return nil end
            return { id = l.id, phase = l.phase, definition = l.definition, grade = l.grade }
        end,
        lease = function(id, definition, grade, options)
            record("cyber.lease", id, { definition = definition, grade = grade, options = options })
            local running = lease(id)
            if running and running.phase ~= "failed" then return nil, "lease_active" end
            if H.refuse.lease[id] then return nil, "player_unavailable" end
            local duration = options and options.durationMs or 300000
            if duration < 1000 or duration > 300000 then return nil, "invalid_options" end
            leaseSequence = leaseSequence + 1
            H.leases[id] = { id = "lease" .. leaseSequence, phase = "pending", definition = definition, grade = grade,
                bucket = H.players[id].bucket, activeAt = H.clock + 300, expiresAt = H.clock + duration }
            return { ok = true, lease = H.leases[id].id, ticket = "t" .. leaseSequence }
        end,
        releaseLease = function(id, leaseId)
            record("cyber.releaseLease", id, leaseId)
            if H.refuse.release > 0 then
                H.refuse.release = H.refuse.release - 1
                return nil, "cyberware_storage_unavailable"
            end
            local l = lease(id)
            if l == nil or l.id ~= leaseId then return nil, "invalid_operation" end
            if l.phase ~= "restoring" then l.phase, l.restoredAt = "restoring", H.clock + H.restoreMs end
            return { ok = true, ticket = "r" }
        end,
    }
end
function H.abilityCalls(op, id)
    local n = 0
    for _, entry in ipairs(H.abilityLog) do
        if entry.op == op and (id == nil or entry.id == id) then n = n + 1 end
    end
    return n
end

function H.placeVehicle(id, x, y, z) local v = H.vehicles[id]; v.x, v.y, v.z = x, y, z end
function H.placeNpc(id, x, y, z) local n = H.npcs[id]; n.x, n.y, n.z = x, y, z end
function H.count(map) local n = 0; for _ in pairs(map) do n = n + 1 end return n end

-- ---------------------------------------------------------------- io --

H.files = {}
Open77.io = {
    readJson = function(path)
        local value = H.files[path]
        if value == nil then return nil, "not_found" end
        return value
    end,
    writeJson = function(path, value) H.files[path] = value; return true end,
    makeDirectory = function() return true end,
    list = function(dir)
        local entries = {}
        for path in pairs(H.files) do
            local name = path:match("^" .. dir .. "/([^/]+)$")
            if name then entries[#entries + 1] = { name = name, type = "file" } end
        end
        return entries
    end,
    remove = function(path)
        if H.files[path] == nil then return false, "not_found" end
        H.files[path] = nil
        return true
    end,
}

-- ---------------------------------------------------------------- core stub --

-- A stand-in for op77_lightrp's side of the activity contract.
H.core = {
    registered = {}, owner = {}, returns = {}, calls = {},
    eligible = {},          -- playerId -> false, reason (true by default)
    refuseRegister = false,
    bots = false,           -- staff bot mode, as activityBots() answers it
}
local core = H.core
local function call(name, ...) core.calls[#core.calls + 1] = { name = name, args = table.pack(...) } end
H.coreExports = {
    activityRegister = function(_, def)
        call("activityRegister", def)
        if core.refuseRegister then return false, "core_not_ready" end
        core.registered[def.id] = def
        return true
    end,
    activityCheck = function(_, playerId, activityId)
        call("activityCheck", playerId, activityId)
        local verdict = core.eligible[playerId]
        if verdict then return false, verdict end
        if core.owner[playerId] then return false, "You are already in an activity." end
        return true
    end,
    activityEnter = function(_, playerId, activityId)
        call("activityEnter", playerId, activityId)
        local verdict = core.eligible[playerId]
        if verdict then return false, verdict end
        local p = H.players[playerId]
        core.owner[playerId] = activityId
        core.returns[playerId] = { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
        return true
    end,
    activityLeave = function(_, playerId, activityId, opts)
        call("activityLeave", playerId, activityId, opts)
        if core.owner[playerId] ~= activityId then return false, "not_owner" end
        core.owner[playerId] = nil
        if opts == nil or opts.returnPlayer ~= false then
            local back, p = core.returns[playerId], H.players[playerId]
            if back and p then p.x, p.y, p.z, p.bucket = back.x, back.y, back.z, back.bucket end
        end
        return true
    end,
    activityOwner = function(_, playerId) return core.owner[playerId] end,
    activityBots = function()
        call("activityBots")
        return core.bots == true
    end,
    activityPlayer = function(_, playerId)
        local p = H.players[playerId]
        if not p then return nil end
        return { name = p.name, identifier = "license:" .. playerId, characterKey = "char1" }
    end,
}
exports = { op77_lightrp = H.coreExports }

function H.coreCalls(name, playerId)
    local found = {}
    for _, c in ipairs(core.calls) do
        if c.name == name and (playerId == nil or c.args[1] == playerId) then found[#found + 1] = c end
    end
    return found
end

-- ---------------------------------------------------------------- loading --

function H.load(files)
    for _, file in ipairs(files) do dofile(file) end
    runReady()
end

H.SERVER = {
    "shared/config.lua", "shared/race.lua",
    "server/builtin_courses.lua", "server/courses.lua", "server/records.lua", "server/activity.lua",
    "server/engine.lua", "server/bots.lua", "server/parkour.lua", "server/lobby.lua", "server/editor.lua", "server/main.lua",
}

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
function H.done(name)
    realPrint(("%s: %d passed"):format(name, passed))
end

return H
