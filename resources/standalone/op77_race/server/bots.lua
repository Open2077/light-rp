-- Staff bot mode: NPC racers that fill a street or rooftop race while op77_lightrp's
-- /lightrp.bots is on, so one player can test a multiplayer race alone.
--
--   Street race: an NPC driver (Open77.npcs.create) attached to a loaner car
--     (Open77.vehicles.ai.attachDriver) on a free grid slot, held by the players'
--     replicated frozen flag until GO, then driven along the checkpoints with
--     Open77.vehicles.ai.followRoute (aggressive, configured speed ceiling), in
--     stretches of at most `routePoints` checkpoints, laps unrolled.
--   Rooftop race: an NPC runner sprinting checkpoint to checkpoint
--     (Open77.npcs.tasks.moveTo; patrol when moveTo is missing).
--
-- Bots progress on the server only, from their car's or body's canonical position and
-- with the players' swept-cylinder rule, so the live ranking, the finish order and the
-- result card include them. A bot without checkpoint progress is re-tasked, then
-- counted DNF. Bots live in the instance's routing bucket and go with it: race end,
-- last player gone, core stop, resource stop. They never send a result and never earn
-- anything; a race that had bots records nothing (RaceEngine: results flagged `test`,
-- no best time).
--
-- The reference documents a newer build than some servers run: every native is
-- resolved before use and called under pcall, a missing one is logged once, and a bot
-- degrades (a car without a body drives itself; without the AI natives, no bots).
local Config = RaceConfig
local Engine = Config.engine
local S = RaceShared
local E = RaceEngine

RaceBots = {}
local B = RaceBots

local sequence = 0
local byVehicle = {} -- tostring(vehicleId) -> bot, for the vehicle AI events
B.byVehicle = byVehicle

local function log(text) print("[race:bots] " .. tostring(text)) end
local warned = {}
local function warnOnce(key, text)
    if warned[key] then return end
    warned[key] = true
    log(text)
end
function B.resetWarnings() warned = {} end

local function settings() return type(Config.bots) == "table" and Config.bots or {} end
local function setting(name, fallback)
    local value = settings()[name]
    if value == nil then return fallback end
    return value
end
local function sub(section, name, fallback)
    local group = settings()[section]
    local value = type(group) == "table" and group[name] or nil
    if value == nil then return fallback end
    return value
end
local function clamp(value, low, high, fallback)
    local number = tonumber(value) or fallback
    if number < low then return low end
    if number > high then return high end
    return number
end

-- ---------------------------------------------------------------- natives --

local function lookup(path)
    local ok, found = pcall(function()
        local node = Open77
        for part in path:gmatch("[^.]+") do
            if type(node) ~= "table" then return nil end
            node = node[part]
        end
        return node
    end)
    if ok then return found end
    return nil
end

local function has(path) return type(lookup(path)) == "function" end
B.has = has

local function constant(path, fallback)
    local value = lookup(path)
    if type(value) == "number" then return value end
    return fallback
end

-- Open77.<path>(...) -> result, or nil and a reason. A missing native is logged once
-- (unless quiet: an optional refinement); a raise once per native and message.
local function invoke(path, quiet, ...)
    local fn = lookup(path)
    if type(fn) ~= "function" then
        if not quiet then
            warnOnce("missing:" .. path, ("Open77.%s is not available on this server: bots do without it"):format(path))
        end
        return nil, "native_unavailable"
    end
    local ok, result, reason = pcall(fn, ...)
    if not ok then
        warnOnce("raised:" .. path .. ":" .. tostring(result), ("Open77.%s raised: %s"):format(path, tostring(result)))
        return nil, tostring(result)
    end
    if result == nil or result == false then return nil, reason or "rejected" end
    return result, reason
end
local function native(path, ...) return invoke(path, false, ...) end
local function try(path, ...) return invoke(path, true, ...) end
B.native = native

-- Can this server run bots for this kind of race at all?
local function capable(foot)
    if foot then
        if not has("npcs.create") then
            warnOnce("cannot:foot", "rooftop bots need Open77.npcs.create: races start without bots")
            return false
        end
        if not has("npcs.tasks.moveTo") and not has("npcs.tasks.patrol") then
            warnOnce("cannot:foot:tasks", "rooftop bots need Open77.npcs.tasks.moveTo or patrol: races start without bots")
            return false
        end
        return true
    end
    if not has("vehicles.ai.attachDriver") or not (has("vehicles.ai.followRoute") or has("vehicles.ai.driveTo")) then
        warnOnce("cannot:car", "street bots need Open77.vehicles.ai.attachDriver and followRoute (or driveTo): races start without bots")
        return false
    end
    if not has("npcs.create") then
        warnOnce("cannot:car:npc", "Open77.npcs.create is missing: bot cars drive without a driver")
    end
    return true
end
B.capable = capable

-- ---------------------------------------------------------------- settings --

local function carSpeed() return clamp(sub("car", "speed", 30.0), 0.5, 55.0, 30.0) end
local function carBehavior()
    local value = tostring(sub("car", "behavior", "aggressive"))
    if value ~= "normal" and value ~= "cautious" and value ~= "aggressive" then return "aggressive" end
    return value
end
local function arrivalRadius() return clamp(sub("car", "arrivalRadius", 8.0), 1.0, 20.0, 8.0) end
local function stuckMs() return math.floor(clamp(setting("stuckSeconds", 20), 2, 600, 20) * 1000) end
local function maxRetasks() return math.floor(clamp(setting("maxRetasks", 2), 0, 20, 2)) end
local function routeTimeoutMs() return math.floor(clamp((Engine.durationSeconds or 1200) * 1000, 1000, 3600000, 1200000)) end

local function movementChannel() return constant("npcs.channels.movement", nil) end

-- ---------------------------------------------------------------- geometry --

-- Where a bot rolls on to after the line, clear of the finish: the circuit's first
-- checkpoint (a road the course already uses), else straight on from the last leg.
local function runOut(inst, metres)
    local course = inst.course
    local checkpoints = course.checkpoints
    local last = checkpoints[#checkpoints].position
    if course.type == "circuit" and #checkpoints > 1 then
        local first = checkpoints[1].position
        if S.distance(first, last) > 15.0 then return { x = first.x, y = first.y, z = first.z } end
    end
    local before = (#checkpoints > 1 and checkpoints[#checkpoints - 1].position) or course.start.position
    local dx, dy = last.x - before.x, last.y - before.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.5 then
        local yaw = math.rad(checkpoints[#checkpoints].heading or 0.0)
        dx, dy, length = -math.sin(yaw), math.cos(yaw), 1.0
    end
    return { x = last.x + dx / length * metres, y = last.y + dy / length * metres, z = last.z }
end

-- The checkpoints ahead of a bot, laps unrolled, at most `limit`. Returns the points,
-- how many checkpoints they cover and whether the finish is among them.
local function ahead(inst, bot, limit)
    local course = inst.course
    local count = #course.checkpoints
    local points, lap, index = {}, bot.lap or 1, bot.nextCheckpoint or 1
    while #points < limit do
        local checkpoint = course.checkpoints[index]
        if checkpoint == nil then break end
        local p = checkpoint.position
        points[#points + 1] = { x = p.x, y = p.y, z = p.z }
        if index == count then
            if lap >= course.laps then return points, #points, true end
            lap, index = lap + 1, 1
        else
            index = index + 1
        end
    end
    return points, #points, false
end

local function sidePosition(slot, metres)
    local yaw = math.rad(slot.heading or 0.0)
    -- REDengine yaw 0 faces +Y: right = (cos, sin); the driver waits on the left.
    return { x = slot.position.x - math.cos(yaw) * metres, y = slot.position.y - math.sin(yaw) * metres,
        z = slot.position.z + 0.2 }
end

-- The bot's canonical position: its car's, or its body's.
local function position(bot)
    if bot.vehicleId ~= nil then
        local snapshot = E.vehicleCall("get", bot.vehicleId)
        if type(snapshot) ~= "table" then return nil end
        local p = type(snapshot.position) == "table" and snapshot.position or snapshot
        local x, y, z = tonumber(p.x or snapshot.x), tonumber(p.y or snapshot.y), tonumber(p.z or snapshot.z)
        if x == nil or y == nil or z == nil then return nil end
        return { x = x, y = y, z = z, bucket = snapshot.bucket }
    end
    if bot.npcId ~= nil then
        local where = try("npcs.presence", bot.npcId) or try("npcs.get", bot.npcId)
        if type(where) ~= "table" then return nil end
        local x, y, z = tonumber(where.x), tonumber(where.y), tonumber(where.z)
        if x == nil or y == nil or z == nil then return nil end
        return { x = x, y = y, z = z, bucket = where.bucket }
    end
    return nil
end
B.position = position

-- Nobody near enough to simulate it: a bot far ahead of every player waits, and that
-- must not count as being stuck.
local function unsimulated(bot)
    if bot.vehicleId ~= nil then
        local state = try("vehicles.ai.state", bot.vehicleId)
        return type(state) == "table" and state.status == "waiting_for_simulator"
    end
    if bot.npcId ~= nil then
        local presence = try("npcs.presence", bot.npcId)
        return type(presence) == "table" and tonumber(presence.authorityPlayerId) == 0
    end
    return false
end

-- ---------------------------------------------------------------- bodies --

local function createNpc(inst, records, at, heading)
    if not has("npcs.create") then return nil, "native_unavailable" end
    local definition = {
        position = { x = at.x, y = at.y, z = at.z }, yaw = heading or 0.0, bucket = inst.bucket,
        aiMode = constant("npcs.ai.tasks", 0),
        -- integers from the constant tables: a string raises in CreateNpc
        damagePolicy = constant("npcs.damage.invulnerable", 2),
        behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
        streamingRadius = clamp(setting("npcStreamingRadius", 300.0), 50.0, 1000.0, 300.0),
        despawnWhenUnobserved = false, persistent = false,
    }
    local lastReason = "no_record"
    for _, record in ipairs(type(records) == "table" and records or {}) do
        definition.record = record
        local npcId, reason = native("npcs.create", definition)
        if npcId ~= nil then
            -- the instance's bucket only, even if a build ignores the field
            local snapshot = try("npcs.get", npcId)
            if type(snapshot) == "table" and snapshot.bucket ~= nil and snapshot.bucket ~= inst.bucket then
                try("npcs.setBucket", npcId, inst.bucket)
            end
            return npcId
        end
        lastReason = tostring(reason)
        if lastReason == "native_unavailable" then break end
    end
    log(("no NPC body for a bot in %s: %s"):format(inst.id, lastReason))
    return nil, lastReason
end

local function removeEntities(bot, why)
    if bot.vehicleId ~= nil then
        local id = bot.vehicleId
        byVehicle[tostring(id)] = nil
        if bot.attached then try("vehicles.ai.removeDriver", id) end
        bot.attached, bot.vehicleId = false, nil
        local ok, reason = E.vehicleCall("remove", id)
        if not ok then log(("bot %s car %s removal failed (%s): %s"):format(bot.id, tostring(id), tostring(why), tostring(reason))) end
    end
    if bot.npcId ~= nil then
        local id = bot.npcId
        bot.npcId = nil
        local ok, reason = native("npcs.remove", id)
        if not ok then log(("bot %s body %s removal failed (%s): %s"):format(bot.id, tostring(id), tostring(why), tostring(reason))) end
    end
    bot.ready = false
end

-- ---------------------------------------------------------------- tasks --

local function attach(inst, bot, now)
    if bot.attached or bot.vehicleId == nil then return bot.attached end
    bot.attachAttempts = (bot.attachAttempts or 0) + 1
    local state, reason = native("vehicles.ai.attachDriver", bot.vehicleId, bot.npcId and { npcId = bot.npcId } or nil)
    if state ~= nil then
        bot.attached = true
        try("vehicles.ai.setBehavior", bot.vehicleId, carBehavior())
        try("vehicles.ai.setSpeed", bot.vehicleId, carSpeed())
        return true
    end
    log(("bot %s: attachDriver refused (attempt %d): %s"):format(bot.id, bot.attachAttempts, tostring(reason)))
    if bot.npcId ~= nil and bot.attachAttempts >= 3 then
        -- the body is what the controller refuses: the car drives itself
        log(("bot %s drives without a body"):format(bot.id))
        native("npcs.remove", bot.npcId)
        bot.npcId, bot.driverless = nil, true
    end
    bot.nextAttachAt = now + math.floor(clamp(sub("car", "attachRetryMs", 1000), 100, 10000, 1000))
    return false
end

-- Hands the car the checkpoints ahead (followRoute), else the next one (driveTo).
local function drive(inst, bot, now)
    if bot.vehicleId == nil then return false end
    local limit = math.floor(clamp(sub("car", "routePoints", 24), 1, 63, 24))
    local points, covered, finish = ahead(inst, bot, limit)
    if #points == 0 then return false end
    local state, reason
    if has("vehicles.ai.followRoute") then
        local route = points
        if finish then
            route = S.clone(points)
            route[#route + 1] = runOut(inst, tonumber(sub("car", "runOutMetres", 60.0)) or 60.0)
        end
        state, reason = native("vehicles.ai.followRoute", bot.vehicleId, {
            points = route, loop = false, speed = carSpeed(), behavior = carBehavior(),
            arrivalRadius = arrivalRadius(), timeoutMilliseconds = routeTimeoutMs(),
        })
        if state ~= nil then
            bot.routeUntil, bot.routeRefill, bot.routeHasFinish = (bot.completed or 0) + covered,
                math.floor(clamp(sub("car", "routeRefill", 3), 0, 60, 3)), finish
        end
    end
    if state == nil and has("vehicles.ai.driveTo") then
        state, reason = native("vehicles.ai.driveTo", bot.vehicleId, {
            position = points[1], speed = carSpeed(), behavior = carBehavior(),
            arrivalRadius = arrivalRadius(), timeoutMilliseconds = routeTimeoutMs(),
        })
        if state ~= nil then
            bot.routeUntil, bot.routeRefill, bot.routeHasFinish = (bot.completed or 0) + 1, 0, covered == 1 and finish
        end
    end
    if state == nil then log(("bot %s: no route handed (%s)"):format(bot.id, tostring(reason))) end
    return state ~= nil
end

local function footOptions(speed)
    return { speed = speed, acceptanceRadius = clamp(sub("foot", "acceptanceRadius", 1.0), 0.5, 5.0, 1.0),
        timeoutMs = stuckMs(), priority = 10 }
end

-- Sends a runner to the next checkpoint (moveTo), else round the ones ahead (patrol).
local function run(inst, bot, now)
    if bot.npcId == nil then return false end
    local checkpoint = inst.course.checkpoints[bot.nextCheckpoint]
    if checkpoint == nil then return false end
    -- one movement task at a time (an NPC holds 64)
    try("npcs.tasks.clear", bot.npcId, movementChannel())
    local speed = tostring(sub("foot", "speed", "sprint"))
    local taskId, reason
    if has("npcs.tasks.moveTo") then
        local p = checkpoint.position
        taskId, reason = native("npcs.tasks.moveTo", bot.npcId, { x = p.x, y = p.y, z = p.z }, footOptions(speed))
        if taskId == nil and speed ~= "run" then
            taskId, reason = native("npcs.tasks.moveTo", bot.npcId, { x = p.x, y = p.y, z = p.z }, footOptions("run"))
        end
        if taskId ~= nil then bot.routeUntil, bot.routeRefill, bot.routeHasFinish = (bot.completed or 0) + 1, 0, false end
    end
    if taskId == nil and has("npcs.tasks.patrol") then
        local points, covered, finish = ahead(inst, bot, 64)
        taskId, reason = native("npcs.tasks.patrol", bot.npcId, points, { loop = false, speed = speed, priority = 10 })
        if taskId ~= nil then bot.routeUntil, bot.routeRefill, bot.routeHasFinish = (bot.completed or 0) + covered, 2, finish end
    end
    if taskId == nil then log(("bot %s: no run task (%s)"):format(bot.id, tostring(reason))) end
    return taskId ~= nil
end

local function task(inst, bot, now)
    if bot.kind == "car" then return drive(inst, bot, now) end
    return run(inst, bot, now)
end

-- Stops whatever the bot was doing (it stays where it is until the instance goes).
local function halt(bot)
    if bot.vehicleId ~= nil and bot.attached then try("vehicles.ai.stop", bot.vehicleId) end
    if bot.vehicleId == nil and bot.npcId ~= nil then try("npcs.tasks.clear", bot.npcId, movementChannel()) end
end

-- ---------------------------------------------------------------- setup --

local function setupCar(inst, bot, now)
    local spec = RaceCourses.vehicle(inst.course.vehicle) or RaceCourses.vehicle(Engine.vehicle.default)
    local vehicleId, reason = E.vehicleCall("create", {
        record = spec.record, position = S.clone(bot.slot.position), yaw = bot.slot.heading, bucket = inst.bucket,
        health = 1.0, flags = E.vehicleFlags(true),
        primaryColor = sub("car", "primaryColor", Engine.vehicle.primaryColor),
        secondaryColor = sub("car", "secondaryColor", Engine.vehicle.secondaryColor),
    })
    if vehicleId == nil then
        log(("bot %s: car not created: %s"):format(bot.id, tostring(reason)))
        return false
    end
    bot.vehicleId = vehicleId
    byVehicle[tostring(vehicleId)] = bot
    -- held on the grid like the players' cars until GO
    local held, why = E.setHeld(vehicleId, true)
    if not held then log(("bot %s: grid hold not confirmed: %s"):format(bot.id, tostring(why))) end
    if has("npcs.create") then
        bot.npcId = createNpc(inst, setting("driverRecords", {}), sidePosition(bot.slot, 2.5), bot.slot.heading)
    end
    bot.driverless = bot.npcId == nil
    attach(inst, bot, now)
    bot.ready = bot.attached == true
    return true
end

local function setupRunner(inst, bot)
    bot.npcId = createNpc(inst, setting("runnerRecords", {}), bot.slot.position, bot.slot.heading)
    bot.ready = bot.npcId ~= nil
    return bot.ready
end

local function callsign(index)
    local list = setting("callsigns", nil)
    if type(list) ~= "table" or #list == 0 then return "Bot " .. tostring(index) end
    return tostring(list[((index - 1) % #list) + 1])
end

-- Puts up to `count` bots on the slots behind the players. Returns how many joined.
function B.fill(inst, count)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or inst.mode == "trial" then return 0 end
    local foot = S.onFoot(inst.course)
    if not capable(foot) then return 0 end
    inst.bots, inst.botsById = inst.bots or {}, inst.botsById or {}
    local total = #inst.members + count
    local now = E.nowMs()
    local first = math.random(1, 1000)
    local prefix = tostring(setting("namePrefix", "[BOT] "))
    for i = 1, count do
        sequence = sequence + 1
        local slotIndex = #inst.members + i
        local bot = {
            id = "bot" .. sequence, bot = true, kind = foot and "foot" or "car",
            name = prefix .. callsign(first + i), slotIndex = slotIndex,
            slot = S.gridSlot(inst.course, slotIndex, total, Engine.startGrid, Engine.footStartSpacing),
            state = "loading", ready = false, started = false,
            lap = 1, nextCheckpoint = 1, completed = 0, lapTimes = {},
            lastCheckpointAt = 0, idleMs = 0, retasks = 0, attachAttempts = 0,
        }
        local ok
        if foot then ok = setupRunner(inst, bot) else ok = setupCar(inst, bot, now) end
        if ok then
            inst.bots[#inst.bots + 1] = bot
            inst.botsById[bot.id] = bot
        else
            removeEntities(bot, "setup_failed")
        end
    end
    local joined = #inst.bots
    if joined > 0 then
        inst.hadBots = true
        for _, playerId in ipairs(inst.members) do
            E.hooks.notice(playerId, "info", inst.label,
                ("Bot mode: %d bot%s on the grid. Nothing is recorded."):format(joined, joined == 1 and "" or "s"))
        end
    end
    log(("%s: %d of %d bot(s) on the grid"):format(inst.id, joined, count))
    return joined
end

-- ---------------------------------------------------------------- phases --

local function list(inst) return inst.bots or {} end

function B.count(inst) return #list(inst) end
function B.entrant(inst, id) return inst.botsById and inst.botsById[id] or nil end

function B.starters(inst)
    local n = 0
    for _, bot in ipairs(list(inst)) do if bot.started then n = n + 1 end end
    return n
end

function B.racing(inst)
    for _, bot in ipairs(list(inst)) do if bot.state == "racing" then return true end end
    return false
end

-- Every bot ready, or the grace past the loading window spent.
function B.readyForCountdown(inst, now)
    for _, bot in ipairs(list(inst)) do
        if bot.state == "loading" and not bot.ready then
            return now >= (inst.loadEndsAt or now) + math.floor(clamp(setting("readyWaitSeconds", 8), 0, 120, 8) * 1000)
        end
    end
    return true
end

-- The ready ones line up; the others leave the grid (removed, not ranked).
function B.countdown(inst, now)
    local kept = {}
    for _, bot in ipairs(list(inst)) do
        if bot.state == "loading" and bot.ready then
            bot.state = "countdown"
            kept[#kept + 1] = bot
        else
            log(("bot %s dropped from the grid of %s (not ready)"):format(bot.id, inst.id))
            removeEntities(bot, "not_ready")
            if inst.botsById then inst.botsById[bot.id] = nil end
        end
    end
    if inst.bots then inst.bots = kept end
end

-- Released with the players: hold off, route on.
function B.go(inst, now)
    for _, bot in ipairs(list(inst)) do
        if bot.state == "countdown" then
            if bot.vehicleId ~= nil then
                local released, why = E.setHeld(bot.vehicleId, false)
                if not released then log(("bot %s: grid release not confirmed: %s"):format(bot.id, tostring(why))) end
            end
            bot.state, bot.started = "racing", true
            bot.lapStartedAt, bot.lastSeenAt, bot.idleMs, bot.retasks = now, now, 0, 0
            bot.lastPosition = position(bot)
            task(inst, bot, now)
        end
    end
end

local function out(inst, bot, reason)
    bot.state, bot.dnfReason, bot.ready = "dnf", reason, false
    log(("bot %s DNF in %s: %s"):format(bot.id, inst.id, tostring(reason)))
    removeEntities(bot, reason)
end

local function finished(inst, bot, now)
    E.placeFinisher(inst, bot.id, bot, now)
    log(("bot %s finished %s P%d in %dms"):format(bot.id, inst.id, bot.finishPlace, bot.timeMs))
    if bot.vehicleId ~= nil then
        -- roll on to the run-out point, slowly, clear of the line
        if bot.routeHasFinish and has("vehicles.ai.followRoute") then
            try("vehicles.ai.setSpeed", bot.vehicleId, clamp(sub("car", "cooldownSpeed", 8.0), 0.5, 55.0, 8.0))
        else
            try("vehicles.ai.stop", bot.vehicleId)
        end
    elseif bot.npcId ~= nil then
        try("npcs.tasks.clear", bot.npcId, movementChannel())
        if has("npcs.tasks.moveTo") then
            try("npcs.tasks.moveTo", bot.npcId, runOut(inst, tonumber(sub("foot", "runOutMetres", 6.0)) or 6.0),
                { speed = "walk", acceptanceRadius = 1.0, timeoutMs = 15000 })
        end
    end
    E.afterFinish(inst, now)
    if E.instances[inst.id] == inst then E.pushInstance(inst) end
end

local function accept(inst, bot, now)
    local kind = E.advance(inst, bot, now)
    if kind == nil then return end
    bot.idleMs, bot.retasks = 0, 0
    if kind == "finish" then return finished(inst, bot, now) end
    if not bot.routeHasFinish and (bot.completed or 0) >= (bot.routeUntil or 0) - (bot.routeRefill or 0) then
        task(inst, bot, now)
    end
end

-- No progress: re-task, and after maxRetasks re-tasks, out.
local function unstick(inst, bot, now, why)
    if (bot.retasks or 0) >= maxRetasks() then return out(inst, bot, "stuck") end
    bot.retasks = (bot.retasks or 0) + 1
    log(("bot %s re-tasked in %s (%s, %d/%d) towards checkpoint %d"):format(bot.id, inst.id, tostring(why),
        bot.retasks, maxRetasks(), bot.nextCheckpoint or 0))
    if bot.vehicleId ~= nil then try("vehicles.ai.stop", bot.vehicleId) end
    bot.lastPosition = nil
    task(inst, bot, now)
end

local function evaluate(inst, bot, now)
    local elapsed = math.max(0, now - (bot.lastSeenAt or now))
    bot.lastSeenAt = now
    local checkpoint = inst.course.checkpoints[bot.nextCheckpoint]
    local p = position(bot)
    if p ~= nil and checkpoint ~= nil and (p.bucket == nil or p.bucket == inst.bucket) then
        local radius = (checkpoint.radius or inst.course.checkpointRadius or Engine.checkpointRadius)
            + (tonumber(setting("checkpointRadiusBonus", 0.0)) or 0.0)
        local crossed = S.crossed(bot.lastPosition, p, checkpoint.position, radius, Engine.checkpointZTolerance,
            Engine.maxSegmentMetres)
        bot.lastPosition = { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
        if crossed then
            accept(inst, bot, now)
            return
        end
    end
    if bot.taskFailed then
        bot.taskFailed = nil
        return unstick(inst, bot, now, "task_failed")
    end
    if bot.routeDone then
        -- the stretch ended without the checkpoints ahead being validated: hand it again
        bot.routeDone = nil
        if not bot.routeHasFinish then task(inst, bot, now) end
    end
    if now >= (bot.nextStateAt or 0) then
        bot.nextStateAt = now + 2000
        bot.paused = unsimulated(bot)
    end
    if not bot.paused then bot.idleMs = (bot.idleMs or 0) + elapsed end
    if bot.idleMs >= stuckMs() * ((bot.retasks or 0) + 1) then unstick(inst, bot, now, "no_progress") end
end

-- Every engine tick: seats and holds before GO, progress after.
function B.tick(inst, now)
    local bots = inst.bots
    if bots == nil or #bots == 0 then return end
    if inst.phase == "loading" or inst.phase == "countdown" then
        for _, bot in ipairs(bots) do
            if bot.kind == "car" and (bot.state == "loading" or bot.state == "countdown") and bot.vehicleId ~= nil then
                if not bot.attached and now >= (bot.nextAttachAt or 0) then attach(inst, bot, now) end
                bot.ready = bot.attached == true
                if now - (bot.lastHoldAt or -math.huge) >= (Engine.holdCheckMs or 500) then
                    bot.lastHoldAt = now
                    E.setHeld(bot.vehicleId, true)
                end
            end
        end
    elseif inst.phase == "active" then
        for _, bot in ipairs(bots) do
            if bot.state == "racing" then evaluate(inst, bot, now) end
            if inst.phase ~= "active" then break end
        end
    end
end

-- The race resolved: the bots still on the course are out and stop where they are.
function B.resolve(inst, reason, now)
    for _, bot in ipairs(list(inst)) do
        if bot.state == "racing" or bot.state == "countdown" or bot.state == "loading" then
            bot.state, bot.dnfReason = "dnf", reason
            halt(bot)
        end
    end
end

function B.stop(inst)
    for _, bot in ipairs(list(inst)) do halt(bot) end
end

-- Bodies and cars out (the instance closes, the core stopped, the resource stops).
function B.cleanup(inst, why)
    for _, bot in ipairs(list(inst)) do removeEntities(bot, why or "cleanup") end
end

function B.shutdown()
    for _, inst in pairs(E.instances) do B.cleanup(inst, "resource_stop") end
end

-- Ranking rows (the players' rows come from the engine). Positions are the last ones
-- the tick read: no native call here.
function B.rows(inst, now)
    local rows = {}
    for _, bot in ipairs(list(inst)) do
        local distance
        if bot.state == "racing" and bot.lastPosition then
            local checkpoint = inst.course.checkpoints[bot.nextCheckpoint]
            if checkpoint then distance = S.distance(bot.lastPosition, checkpoint.position) end
        end
        rows[#rows + 1] = {
            id = bot.id, name = bot.name, bot = true, state = bot.state, grid = bot.slotIndex,
            finishPlace = bot.finishPlace, progress = bot.completed or 0,
            distance = distance and math.floor(distance) or nil,
            lap = bot.lap, timeMs = bot.timeMs, bestLapMs = bot.bestLapMs, ready = bot.ready == true,
            elapsedMs = bot.state == "racing" and inst.startedAt and (now - inst.startedAt) or nil,
        }
    end
    return rows
end

-- ---------------------------------------------------------------- AI events --

-- arrived: a stretch ended (the next one is handed on the next tick); failed (no_route,
-- driver gone, simulator lost): re-task now. Events reach the controller's resource only.
function B.onAiEvent(event, state)
    if type(state) ~= "table" then return end
    local bot = byVehicle[tostring(state.vehicleId)]
    if bot == nil or bot.state ~= "racing" then return end
    if event == "arrived" then
        bot.routeDone = true
    elseif event == "failed" then
        bot.taskFailed = true
        log(("bot %s: driving task failed: %s"):format(bot.id, tostring(state.reason)))
    end
end

if has("vehicles.ai.on") then
    for _, event in ipairs({ "arrived", "failed" }) do
        local ok, err = pcall(Open77.vehicles.ai.on, event, function(state) B.onAiEvent(event, state) end)
        if not ok then warnOnce("on:" .. event, ("Open77.vehicles.ai.on(%s) refused: %s"):format(event, tostring(err))) end
    end
end
