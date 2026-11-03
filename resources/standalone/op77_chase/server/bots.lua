-- op77_chase bots: NCPD cops and runners played by Open77 NPCs, for staff bot mode (Light
-- RP's /lightrp.bots, chase.1v1 and chase.wanted) and for NCPD Escape (chase.pve).
--
-- A bot is a member of a match like a player, under a negative id (<= -1001, never -1:
-- TriggerClientEvent(-1) is a broadcast). ChaseBots.install() wraps ChaseWorld and
-- ChaseCore so the match code needs no special case to read a bot:
--
--   ChaseWorld.position(bot)   its car (vehicles.get) or its body (npcs.presence): the
--                              server's own read, so the rules judge a bot exactly as a player
--   ChaseWorld.alive(bot)      the body's canonical life (bots are immortal by default)
--   ChaseWorld.place(bot, ...) on foot: a body created on the mark (paced); by car: nothing
--                              until its car exists (ChaseBots.mount)
--   ChaseWorld.freeze(bot, x)  held = no driving / walking order
--   hud / queueHud / notify    nothing (a bot has no client)
--   ChaseWorld.removeCar(car)  takes the bot driver out first (stop, removeDriver, remove)
--   ChaseCore.enter / leave / check / player / result   a bot is nobody Light RP knows:
--                              true / true / true / { name, bot } / never a result
--
-- What a bot does is an order (ChaseBots.steer), applied on this file's own tick:
--   { kind = "hold" }                                stop where it is
--   { kind = "chase", target = { player = id } | { bot = id } }
--   { kind = "flee", from = target, route = { checkpoints }, routeKey = any }
--   { kind = "goto", position = { x, y, z } }
--   { kind = "yield" }                               a cornered runner gives up (stops)
-- By car: vehicles.ai.chase / followRoute (then joinTraffic) / driveTo / stop. On foot:
-- npcs.tasks.moveTo (re-issued as the target moves; `follow` was measured broken) /
-- flee / clear. Every native is resolved and pcall'd here (ChaseBots.native): a missing
-- one is logged once and the bot degrades (a car without a body drives itself; a bot
-- that cannot be set up at all is reported broken and its match is called off).
--
-- Lessons from op77_arena kept here: never a bot id into a player native; NPC creation
-- paced (spawnSpacingMs) and never in the tick that removed one; nothing created in the
-- first settleMs after this resource started, and the previous run's orphans (our NPCs
-- and cars in the chase buckets) removed first; nothing created once stopping.
ChaseBots = {
    BASE = -1001,
    bots = {},        -- id -> bot
    byCar = {},       -- car id -> bot id (the bot at its wheel)
    jobs = {},        -- paced body creations, oldest first
    nextId = -1000,
    enabled = false,  -- staff bot mode (Light RP); NCPD Escape never needs it
    stopping = false,
    startedAtMs = nil,
    reconciled = false,
    lastSpawnMs = nil,
    lastDespawnMs = nil,
    warned = {},
    nameIndex = 0,
    jobSeq = 0,
}
local B = ChaseBots

local HOLD = { kind = "hold" }

local function cfg() return ChaseConfig.bots end
local function log(fmt, ...) print(("[op77_chase] bots " .. fmt):format(...)) end
local function clock() return ChaseWorld.now() end

local function planar(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
B.planar = planar

-- ---------------------------------------------------------------- natives

local function resolve(path)
    local node = type(Open77) == "table" and Open77 or nil
    for part in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[part]
    end
    return node
end

function B.warnOnce(key, fmt, ...)
    if B.warned[key] then return end
    B.warned[key] = true
    log(fmt, ...)
end

-- Open77.<path>(...), guarded: a missing native -> nil, "unavailable:<path>" (logged once);
-- one that raises -> nil, message (logged once per message).
function B.native(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then
        B.warnOnce("missing:" .. path, "Open77.%s is unavailable on this server: bots do without it", path)
        return nil, "unavailable:" .. path
    end
    local packed = table.pack(pcall(fn, ...))
    if not packed[1] then
        B.warnOnce("raised:" .. path .. tostring(packed[2]), "Open77.%s raised: %s", path, tostring(packed[2]))
        return nil, tostring(packed[2])
    end
    return table.unpack(packed, 2, packed.n)
end

local function unavailable(why) return type(why) == "string" and why:sub(1, 12) == "unavailable:" end

local function constant(path, fallback)
    local v = resolve(path)
    if type(v) == "number" then return v end
    return fallback
end

local function movementChannel() return constant("npcs.channels.movement", nil) end

-- ---------------------------------------------------------------- registry

-- Any id in the bot range is a bot, registered or not: a stale id never reaches a player native.
function B.isBot(id) return type(id) == "number" and id <= B.BASE end

function B.get(id) return B.bots[id] end

function B.pickName()
    local names = cfg().names or { "NCPD" }
    B.nameIndex = B.nameIndex % #names + 1
    return (cfg().namePrefix or "[BOT] ") .. tostring(names[B.nameIndex])
end

-- A new bot: { role = "cop"|"runner", mode = "vehicle"|"foot", bucket, admission = player
-- id whose client is booked to simulate its car, owner = text for the logs }.
function B.create(opts)
    opts = opts or {}
    B.nextId = math.min(B.nextId, B.BASE + 1) - 1
    local id = B.nextId
    B.bots[id] = {
        id = id, name = opts.name or B.pickName(), role = opts.role or "cop", mode = opts.mode or "vehicle",
        bucket = opts.bucket, admission = opts.admission, owner = opts.owner, held = true, order = HOLD,
        createdAtMs = clock(),
    }
    log("%d (%s) created for %s, bucket %s", id, B.bots[id].name, tostring(opts.owner), tostring(opts.bucket))
    return id, B.bots[id]
end

-- Role and body for the next placement (Most Wanted rotates roles, the 1v1 swaps them).
function B.assign(id, role, mode)
    local bot = B.bots[id]
    if not bot then return false end
    bot.role, bot.mode = role or bot.role, mode == "foot" and "foot" or "vehicle"
    return true
end

function B.broken(id)
    local bot = B.bots[id]
    return bot ~= nil and bot.broken ~= nil, bot and bot.broken
end

local function cancelJobs(id)
    for i = #B.jobs, 1, -1 do
        if B.jobs[i].botId == id then table.remove(B.jobs, i) end
    end
end

-- The body goes (the car stays: the match owns it).
local function dropBody(bot)
    if bot.carId ~= nil then
        if bot.attached then
            B.native("vehicles.ai.stop", bot.carId)
            B.native("vehicles.ai.removeDriver", bot.carId)
        end
        if B.byCar[bot.carId] == bot.id then B.byCar[bot.carId] = nil end
    end
    if bot.npcId ~= nil then
        B.native("npcs.tasks.clear", bot.npcId)
        B.native("npcs.remove", bot.npcId)
        B.lastDespawnMs = clock()
    end
    cancelJobs(bot.id)
    bot.npcId, bot.carId, bot.attached, bot.driverless, bot.ready = nil, nil, false, nil, false
    bot.issuedKey, bot.task, bot.goal, bot.repathAtMs, bot.checkedAtMs, bot.routeDone = nil, nil, nil, nil, nil, nil
end

local function enqueue(bot, kind, done)
    cancelJobs(bot.id)
    B.jobSeq = B.jobSeq + 1
    B.jobs[#B.jobs + 1] = { botId = bot.id, kind = kind, done = done, attempts = 0, seq = B.jobSeq }
end

function B.remove(id)
    local bot = B.bots[id]
    if not bot then return false end
    dropBody(bot)
    B.bots[id] = nil
    log("%d (%s) removed", id, bot.name)
    return true
end

-- Every bot of an owner (a match) at once.
function B.removeWhere(predicate)
    local ids = {}
    for id, bot in pairs(B.bots) do if predicate(bot) then ids[#ids + 1] = id end end
    for _, id in ipairs(ids) do B.remove(id) end
    return #ids
end

-- ---------------------------------------------------------------- bodies

-- On its mark: on foot a body is created there (paced, then done(true)); by car nothing
-- yet (the body comes with the car), so done(true) at once.
function B.place(id, point, bucket, done)
    local bot = B.bots[id]
    if not bot then
        if done then done(false, "bot_gone") end
        return
    end
    dropBody(bot)
    bot.bucket = bucket or bot.bucket
    local p = type(point) == "table" and point.position or nil
    bot.mark = type(p) == "table" and { x = p.x or 0, y = p.y or 0, z = p.z or 0 } or bot.mark
    bot.heading = type(point) == "table" and point.heading or bot.heading or 0
    bot.held, bot.order, bot.pinnedSinceMs, bot.yielding, bot.farSinceMs = true, HOLD, nil, nil, nil
    if B.stopping then
        if done then done(false, "stopping") end
        return
    end
    if bot.mode == "foot" then
        enqueue(bot, "foot", done)
    elseif done then
        done(true)
    end
end

-- At the wheel of a match car: a driver body is created beside it and attached (paced).
function B.mount(id, carId, heading)
    local bot = B.bots[id]
    if not bot or carId == nil or B.stopping then return false end
    if bot.carId ~= nil or bot.npcId ~= nil then dropBody(bot) end
    bot.mode = "vehicle"
    bot.carId = carId
    bot.heading = heading or bot.heading
    B.byCar[carId] = id
    enqueue(bot, "driver")
    return true
end

-- The match removes a car: its bot driver lets go and its body goes first.
function B.unmountCar(carId)
    local id = B.byCar[carId]
    local bot = id and B.bots[id]
    if bot then dropBody(bot) end
    B.byCar[carId] = nil
end

function B.hold(id, held)
    local bot = B.bots[id]
    if bot then bot.held = held == true end
    return true
end

function B.steer(id, order)
    local bot = B.bots[id]
    if not bot then return false end
    bot.order = type(order) == "table" and order or HOLD
    return true
end

function B.carPosition(carId)
    local p = ChaseWorld.carPosition(carId)
    if type(p) == "table" and type(p.x) == "number" then return p end
    return nil
end

local function npcPosition(npcId)
    local p = B.native("npcs.presence", npcId)
    if type(p) == "table" and type(p.x) == "number" then return p end
    local s = B.native("npcs.get", npcId)
    if type(s) == "table" then
        if type(s.x) == "number" then return s end
        if type(s.position) == "table" and type(s.position.x) == "number" then
            return { x = s.position.x, y = s.position.y, z = s.position.z, bucket = s.bucket, alive = s.alive }
        end
    end
    return nil
end

-- { x, y, z, bucket }: the car it drives, else its body, else its mark (before it exists).
function B.position(id)
    local bot = B.bots[id]
    if not bot then return nil end
    if bot.carId ~= nil then
        local p = B.carPosition(bot.carId)
        if p then return { x = p.x, y = p.y, z = p.z, bucket = bot.bucket } end
    end
    if bot.npcId ~= nil then
        local p = npcPosition(bot.npcId)
        if p then return { x = p.x, y = p.y, z = p.z, bucket = p.bucket or bot.bucket } end
    end
    if bot.mark then return { x = bot.mark.x, y = bot.mark.y, z = bot.mark.z, bucket = bot.bucket } end
    return nil
end

function B.alive(id)
    local bot = B.bots[id]
    if not bot then return nil end
    if bot.npcId ~= nil and bot.carId == nil then
        local p = npcPosition(bot.npcId)
        if type(p) == "table" and p.alive == false then return false end
    end
    return true
end

-- ---------------------------------------------------------------- paced creation

local function admission(bot)
    local id = bot.admission
    if type(id) == "number" and id > 0 and id % 1 == 0 then return id end
    return nil
end

local function createBody(bot, position, foot)
    local list = (cfg().records or {})[bot.role] or (cfg().records or {}).cop or {}
    local lastWhy
    for i = bot.recordIndex or 1, #list do
        local npcId, why = B.native("npcs.create", {
            record = list[i], position = position, yaw = bot.heading or 0, bucket = bot.bucket,
            aiMode = foot and constant("npcs.ai.tasks", 0) or constant("npcs.ai.frozen", 1),
            damagePolicy = constant("npcs.damage." .. tostring(cfg().damagePolicy or "immortal"), 1),
            behavior = { aiEnabled = foot == true, combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
            streamingRadius = cfg().streamingRadius, despawnWhenUnobserved = false,
        })
        if npcId then
            bot.recordIndex = i
            return npcId
        end
        lastWhy = why
        log("%d: body %s refused: %s", bot.id, tostring(list[i]), tostring(why))
        if unavailable(why) then return nil, why end
        -- A refusal about the record tries the next one; anything else retries later.
        if not tostring(why):find("record") then return nil, why end
    end
    bot.recordIndex = nil
    return nil, lastWhy or "no_record"
end

local function requeue(job)
    B.jobs[#B.jobs + 1] = job
end

local function failJob(bot, job, why)
    bot.broken = tostring(why)
    log("%d (%s) broken: %s", bot.id, bot.name, bot.broken)
    if job.done then job.done(false, "bot: " .. bot.broken) end
end

local function spawnFoot(bot, job)
    local p = bot.mark
    if p == nil then return failJob(bot, job, "no_mark") end
    local npcId, why = createBody(bot, { x = p.x, y = p.y, z = p.z }, true)
    if npcId then
        bot.npcId, bot.ready, bot.issuedKey = npcId, true, nil
        log("%d on foot as npc %s", bot.id, tostring(npcId))
        if job.done then job.done(true) end
        return
    end
    job.attempts = job.attempts + 1
    if unavailable(why) or job.attempts >= (cfg().createRetries or 3) then return failJob(bot, job, why) end
    requeue(job)
end

local function spawnDriver(bot, job, t)
    if bot.carId == nil then return end
    local retries = cfg().attachRetries or 5
    if job.stage == nil then
        local p = B.carPosition(bot.carId) or bot.mark
        if p == nil then return failJob(bot, job, "no_car_position") end
        local npcId, why = createBody(bot, { x = p.x, y = p.y, z = (p.z or 0) + 1.0 }, false)
        if npcId then
            bot.npcId, job.stage, job.attempts = npcId, "attach", 0
        else
            job.attempts = job.attempts + 1
            if not unavailable(why) and job.attempts < (cfg().createRetries or 3) then return requeue(job) end
            log("%d: no driver body (%s): the car drives itself", bot.id, tostring(why))
            job.stage, job.attempts = "driverless", 0
        end
    end
    if job.stage == "attach" then
        local state, why = B.native("vehicles.ai.attachDriver", bot.carId, { npcId = bot.npcId, admissionPlayerId = admission(bot) })
        if state then
            bot.attached, bot.ready, bot.issuedKey = true, true, nil
            log("%d at the wheel of car %s (npc %s)", bot.id, tostring(bot.carId), tostring(bot.npcId))
            return
        end
        job.attempts = job.attempts + 1
        if not unavailable(why) and job.attempts < retries then return requeue(job) end
        log("%d: driver refused (%s): the car drives itself", bot.id, tostring(why))
        B.native("npcs.remove", bot.npcId)
        bot.npcId, B.lastDespawnMs = nil, t
        job.stage, job.attempts = "driverless", 0
        if unavailable(why) then return failJob(bot, job, why) end
        return requeue(job)
    end
    if job.stage == "driverless" then
        local state, why = B.native("vehicles.ai.attachDriver", bot.carId, { admissionPlayerId = admission(bot) })
        if state then
            bot.attached, bot.driverless, bot.ready, bot.issuedKey = true, true, true, nil
            log("%d drives car %s without a body", bot.id, tostring(bot.carId))
            return
        end
        job.attempts = job.attempts + 1
        if not unavailable(why) and job.attempts < retries then return requeue(job) end
        return failJob(bot, job, why)
    end
end

local function processJobs(t)
    local spacing = cfg().spawnSpacingMs or 400
    if B.lastSpawnMs and t - B.lastSpawnMs < spacing then return end
    -- Never a creation in the tick (or the spacing) after a removal.
    if B.lastDespawnMs and t - B.lastDespawnMs < spacing then return end
    while #B.jobs > 0 do
        local job = table.remove(B.jobs, 1)
        local bot = B.bots[job.botId]
        if bot and not bot.broken then
            B.lastSpawnMs = t
            if job.kind == "foot" then spawnFoot(bot, job) else spawnDriver(bot, job, t) end
            return
        end
    end
end

-- ---------------------------------------------------------------- driving

local function speed() return math.min(55, 8 + 24 * ((cfg().driver or {}).ability or 0.95)) end

-- The vehicles.ai target of a chase: a player, or another bot's car / body.
local function aiTarget(target)
    if type(target) ~= "table" then return nil end
    if target.player then return "player", target.player end
    local other = target.bot and B.bots[target.bot]
    if other then
        if other.carId ~= nil then return "vehicle", other.carId end
        if other.npcId ~= nil then return "npc", other.npcId end
    end
    return nil
end

local function targetPosition(target)
    if type(target) ~= "table" then return nil end
    if target.player then return ChaseWorld.position(target.player) end
    if target.bot then return B.position(target.bot) end
    return nil
end

local function orderKey(order)
    local kind = order.kind
    if kind == "chase" then
        local k, id = aiTarget(order.target)
        return ("chase:%s:%s"):format(tostring(k), tostring(id))
    elseif kind == "flee" then
        local k, id = aiTarget(order.from)
        return ("flee:%s:%s:%s"):format(tostring(k), tostring(id), tostring(order.routeKey))
    elseif kind == "goto" then
        local p = order.position or {}
        return ("goto:%.0f:%.0f"):format(p.x or 0, p.y or 0)
    end
    return kind
end

-- The rest of a route from where the bot is: the points after the one nearest to it (a
-- route given again after a stop must not send it back to the start).
local function routePoints(route, from)
    local all = {}
    for _, cp in ipairs(type(route) == "table" and route or {}) do
        local p = cp.position or cp
        if type(p) == "table" and type(p.x) == "number" then all[#all + 1] = { x = p.x, y = p.y, z = p.z or 0 } end
    end
    local first = 1
    if from and #all > 0 then
        local best, bestD = 1, math.huge
        for i, p in ipairs(all) do
            local d = planar(p, from)
            if d < bestD then best, bestD = i, d end
        end
        first = best + 1
    end
    local points = {}
    for i = first, #all do
        points[#points + 1] = all[i]
        if #points >= 64 then break end
    end
    return points
end

local function driverAbility(bot)
    if bot.npcId ~= nil and not bot.driverless then
        B.native("npcs.tasks.setDriverAbility", bot.npcId, (cfg().driver or {}).ability or 0.95)
    end
end

local function issueCar(bot, order)
    local d = cfg().driver or {}
    local car, timeout, behavior = bot.carId, d.taskTimeoutMs or 600000, d.behavior or "aggressive"
    local kind = order.kind
    if kind == "chase" then
        local targetKind, targetId = aiTarget(order.target)
        if targetKind == nil then return B.native("vehicles.ai.stop", car) end
        local ok, why = B.native("vehicles.ai.chase", car, { targetKind = targetKind, targetId = targetId,
            distance = (cfg().cop or {}).chaseDistance or 4.0, speed = speed(), behavior = behavior, timeoutMilliseconds = timeout })
        if ok then driverAbility(bot) end
        return ok, why
    elseif kind == "flee" then
        local points = (not bot.routeDone) and routePoints(order.route, B.position(bot.id)) or {}
        if #points > 0 then
            local ok, why = B.native("vehicles.ai.followRoute", car, { points = points, speed = speed(), behavior = behavior,
                arrivalRadius = 12, timeoutMilliseconds = timeout })
            if ok then driverAbility(bot) return ok end
            log("%d: route refused (%s): into the traffic", bot.id, tostring(why))
            bot.routeDone = true
        end
        return B.native("vehicles.ai.joinTraffic", car, { timeoutMilliseconds = timeout })
    elseif kind == "goto" then
        local ok, why = B.native("vehicles.ai.driveTo", car, { position = order.position, speed = speed(), behavior = behavior,
            arrivalRadius = 8, timeoutMilliseconds = timeout })
        if ok then driverAbility(bot) end
        return ok, why
    end
    return B.native("vehicles.ai.stop", car) -- hold, yield
end

local RESTART = { idle = true, failed = true, cancelled = true, arrived = true }

local function driveCar(bot, order, t)
    local key = orderKey(order)
    if key == bot.issuedKey then
        if order.kind == "hold" or order.kind == "yield" then return end
        if t - (bot.checkedAtMs or 0) < ((cfg().driver or {}).stateCheckMs or 2000) then return end
        bot.checkedAtMs = t
        local state, why = B.native("vehicles.ai.state", bot.carId)
        if state == nil and unavailable(why) then return end
        local status = type(state) == "table" and state.status or nil
        if state ~= nil and status == nil then return end
        if status == "detached" or state == nil then
            -- The controller is gone (driver dead or removed by the engine): a new driver.
            log("%d lost its car's controller (%s): a new driver", bot.id, tostring(status or why or "no state"))
            local carId = bot.carId
            bot.attached = false
            dropBody(bot)
            B.mount(bot.id, carId, bot.heading)
            return
        end
        if not RESTART[status] then return end
        if order.kind == "flee" and status == "arrived" then bot.routeDone = true end
    end
    bot.issuedKey, bot.checkedAtMs = key, t
    issueCar(bot, order)
end

local function clearMovement(bot)
    B.native("npcs.tasks.clear", bot.npcId, movementChannel())
    bot.task, bot.goal = nil, nil
end

local function taskRunning(bot)
    if bot.task == nil then return false end
    local state = B.native("npcs.tasks.get", bot.npcId, bot.task)
    if state == nil then return false end
    if type(state) == "table" and (state.status == "success" or state.status == "failed" or state.status == "cancelled") then return false end
    return true
end

local function moveTo(bot, position, t)
    local c = cfg().cop or {}
    clearMovement(bot)
    bot.task = B.native("npcs.tasks.moveTo", bot.npcId, { x = position.x, y = position.y, z = position.z or 0 },
        { speed = c.footSpeed or "sprint", acceptanceRadius = c.footAcceptance or 1.5, timeoutMs = 10000, priority = 10 })
    bot.goal, bot.repathAtMs = { x = position.x, y = position.y, z = position.z or 0 }, t
end

local function driveFoot(bot, order, t)
    local key = orderKey(order)
    local changed = key ~= bot.issuedKey
    local kind = order.kind
    if kind == "hold" or kind == "yield" then
        if changed then clearMovement(bot) end
    elseif kind == "chase" then
        local p = targetPosition(order.target)
        if p == nil then
            if changed then clearMovement(bot) end
        else
            local c = cfg().cop or {}
            local due = changed or t - (bot.repathAtMs or 0) >= (c.footRepathMs or 1000)
            if due and (changed or bot.goal == nil or planar(bot.goal, p) >= (c.footRepathMetres or 3.0) or not taskRunning(bot)) then
                moveTo(bot, p, t)
            end
        end
    elseif kind == "flee" then
        if changed or not taskRunning(bot) then
            local from = order.from
            local threat
            if type(from) == "table" and from.player then threat = from.player
            elseif type(from) == "table" and from.bot then
                local other = B.bots[from.bot]
                if other and other.npcId ~= nil and other.carId == nil then threat = { npcId = other.npcId }
                else threat = B.position(from.bot) end
            end
            clearMovement(bot)
            if threat ~= nil then
                local r = cfg().runner or {}
                bot.task = B.native("npcs.tasks.flee", bot.npcId, threat,
                    { distance = r.fleeDistance or 200, speed = r.footSpeed or "sprint", timeoutMs = 60000 })
            end
        end
    elseif kind == "goto" then
        if changed or not taskRunning(bot) then moveTo(bot, order.position, t) end
    end
    bot.issuedKey = key
end

local function drive(bot, t)
    if not bot.ready or bot.broken then return end
    local order = bot.held and HOLD or (bot.order or HOLD)
    if bot.carId ~= nil then
        if bot.attached then driveCar(bot, order, t) end
    elseif bot.npcId ~= nil then
        driveFoot(bot, order, t)
    end
end

-- ---------------------------------------------------------------- what the matches ask

-- A bot runner cornered by a cop gives up: true once the nearest cop has been within the
-- bust radius for yieldSeconds, false again when the cop backs off (resumeFactor x).
function B.yieldCheck(id, nearest, bustDistance, t)
    local bot = B.bots[id]
    if not bot then return false end
    local r = cfg().runner or {}
    if bot.yielding then
        if nearest == nil or nearest > bustDistance * (r.resumeFactor or 2.0) then bot.yielding, bot.pinnedSinceMs = nil, nil end
    elseif nearest ~= nil and nearest <= bustDistance then
        bot.pinnedSinceMs = bot.pinnedSinceMs or t
        if t - bot.pinnedSinceMs >= ((r.yieldSeconds or {})[bot.mode] or 4) * 1000 then bot.yielding = true end
    else
        bot.pinnedSinceMs = nil
    end
    return bot.yielding == true
end

-- Where the runner drove: a breadcrumb every trailEveryMs (when he moved).
function B.trailPush(trail, pos, t)
    if type(trail) ~= "table" or type(pos) ~= "table" or type(pos.x) ~= "number" then return end
    local r = cfg().redispatch or {}
    local last = trail[#trail]
    if last and (t - last.t < (r.trailEveryMs or 1000) or planar(last, pos) < 5.0) then return end
    trail[#trail + 1] = { x = pos.x, y = pos.y, z = pos.z or 0, t = t }
    while #trail > (r.trailSize or 120) do table.remove(trail, 1) end
end

-- The newest breadcrumb band[1]..band[2] m (planar) from `from`, facing the way he went.
function B.trailPick(trail, from, band)
    if type(trail) ~= "table" or type(from) ~= "table" then return nil end
    band = band or (cfg().redispatch or {}).band or { 120, 220 }
    for i = #trail - 1, 1, -1 do
        local p, q = trail[i], trail[i + 1]
        local d = planar(p, from)
        if d >= band[1] and d <= band[2] then
            return { position = { x = p.x, y = p.y, z = p.z }, heading = math.deg(math.atan(-(q.x - p.x), q.y - p.y)) }
        end
    end
    return nil
end

-- A bot cop far from its runner long enough (and not dispatched again lately).
function B.wantsRedispatch(id, distance, t)
    local bot = B.bots[id]
    if not bot or not bot.ready then return false end
    local r = cfg().redispatch or {}
    if distance == nil or distance <= (r.farMetres or 300) then bot.farSinceMs = nil return false end
    bot.farSinceMs = bot.farSinceMs or t
    if t - bot.farSinceMs < (r.farSeconds or 5) * 1000 then return false end
    if bot.redispatchedAtMs and t - bot.redispatchedAtMs < (r.cooldownSeconds or 15) * 1000 then return false end
    bot.redispatchedAtMs, bot.farSinceMs = t, nil
    return true
end

-- ---------------------------------------------------------------- bot mode

function B.setEnabled(on, why)
    on = on == true
    if B.enabled == on then return false end
    B.enabled = on
    log("bot mode %s (%s)", on and "ON" or "off", tostring(why))
    return true
end

-- Does staff bot mode fill this activity's missing players? Only where config.bots.fill
-- says so (registered with Light RP as caps.botFill): chase.1v1 and chase.wanted are real
-- players only, and bot mode then starts nothing there.
function B.fills(activityId)
    return B.enabled == true and (cfg().fill or {})[activityId] == true
end

-- Bot mode is on but this activity is real players only: the line a queued player reads.
function B.refusal(label)
    if B.enabled ~= true then return nil end
    return ("Bot mode is on, but %s is real players only: you wait for other players."):format(label)
end

-- After every successful activityRegister: Light RP's current value (an older Light RP
-- without the export leaves it as it is).
function B.refresh()
    local value = ChaseCore.call("activityBots")
    if value == true or value == false then B.setEnabled(value, "activityBots") end
    return B.enabled
end

-- ---------------------------------------------------------------- tick and lifetime

local RANGES = function()
    local c = ChaseConfig
    return { c.buckets, c.wanted and c.wanted.buckets, c.pve and c.pve.buckets }
end

local function chaseBucket(bucket)
    if type(bucket) ~= "number" then return false end
    for _, r in ipairs(RANGES()) do
        if type(r) == "table" and bucket >= r.from and bucket <= r.to then return true end
    end
    return false
end

local function busyBucket(bucket)
    for _, owner in ipairs({ Chase and Chase.bucketOwner, ChaseWanted and ChaseWanted.bucketOwner, ChasePve and ChasePve.bucketOwner }) do
        if type(owner) == "table" and owner[bucket] ~= nil then return true end
    end
    return false
end

-- The previous run's leftovers: our NPCs (and cars) in a chase bucket nobody uses.
function B.sweepOrphans()
    local me = GetCurrentResourceName()
    local known = {}
    for _, bot in pairs(B.bots) do if bot.npcId then known[bot.npcId] = true end end
    local removed = 0
    local npcs = B.native("npcs.all")
    for _, row in ipairs(type(npcs) == "table" and npcs or {}) do
        if type(row) == "table" and row.id ~= nil and not known[row.id] and (row.resource == me or row.owned == true)
            and chaseBucket(row.bucket) and not busyBucket(row.bucket) then
            B.native("npcs.remove", row.id)
            removed = removed + 1
        end
    end
    local cars = B.native("vehicles.all")
    for _, row in ipairs(type(cars) == "table" and cars or {}) do
        if type(row) == "table" and row.id ~= nil and tostring(row.resource) == me and chaseBucket(row.bucket) and not busyBucket(row.bucket) then
            B.native("vehicles.remove", row.id)
            removed = removed + 1
        end
    end
    if removed > 0 then
        B.lastDespawnMs = clock()
        log("removed %d leftover(s) of a previous run", removed)
    end
    return removed
end

function B.tick(t)
    if B.stopping then return end
    B.startedAtMs = B.startedAtMs or t
    if t - B.startedAtMs < (cfg().settleMs or 5000) then return end
    if not B.reconciled then
        B.reconciled = true
        B.sweepOrphans()
    end
    processJobs(t)
    local ids = {}
    for id in pairs(B.bots) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local bot = B.bots[id]
        if bot then
            local ok, err = pcall(drive, bot, t)
            if not ok then B.warnOnce("drive:" .. tostring(err), "%d: drive failed: %s", id, tostring(err)) end
        end
    end
end

function B.shutdown()
    B.stopping = true
    B.jobs = {}
    for _, bot in pairs(B.bots) do dropBody(bot) end
    B.bots, B.byCar = {}, {}
end

function B.describe()
    local lines = { ("bot mode %s, %d bot(s), %d body job(s) waiting"):format(B.enabled and "ON" or "off",
        (function() local n = 0 for _ in pairs(B.bots) do n = n + 1 end return n end)(), #B.jobs) }
    local ids = {}
    for id in pairs(B.bots) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return a > b end)
    for _, id in ipairs(ids) do
        local bot = B.bots[id]
        local p = B.position(id)
        lines[#lines + 1] = ("  %d %s %s/%s %s%s bucket %s npc %s car %s order %s%s%s"):format(id, bot.name, tostring(bot.role), tostring(bot.mode),
            tostring(bot.owner), bot.held and " held" or "", tostring(bot.bucket), tostring(bot.npcId), tostring(bot.carId),
            tostring((bot.order or HOLD).kind), p and (" at %.0f,%.0f"):format(p.x, p.y) or "", bot.broken and (" BROKEN " .. bot.broken) or "")
    end
    return lines
end

-- ---------------------------------------------------------------- the wrappers

function B.install()
    if B.installed then return end
    B.installed = true
    local W, C = ChaseWorld, ChaseCore
    local w, c = {}, {}
    for _, k in ipairs({ "position", "alive", "name", "connected", "place", "freeze", "respawnInPlace", "seat", "forceOut",
        "hud", "queueHud", "notify", "removeCar" }) do w[k] = W[k] end
    for _, k in ipairs({ "check", "enter", "leave", "owner", "unqueue", "owned", "player", "result" }) do c[k] = C[k] end
    B.originals = { world = w, core = c }

    W.position = function(id, ...) if B.isBot(id) then return B.position(id) end return w.position(id, ...) end
    W.alive = function(id, ...) if B.isBot(id) then return B.alive(id) end return w.alive(id, ...) end
    W.name = function(id, ...)
        if B.isBot(id) then
            local bot = B.bots[id]
            return bot and bot.name or ((cfg().namePrefix or "[BOT] ") .. "NCPD")
        end
        return w.name(id, ...)
    end
    W.connected = function(id, ...) if B.isBot(id) then return B.bots[id] ~= nil end return w.connected(id, ...) end
    W.place = function(id, point, bucket, done, cover)
        if B.isBot(id) then return B.place(id, point, bucket, done) end
        return w.place(id, point, bucket, done, cover)
    end
    W.freeze = function(id, frozen) if B.isBot(id) then return B.hold(id, frozen) end return w.freeze(id, frozen) end
    W.respawnInPlace = function(id, ...) if B.isBot(id) then return true end return w.respawnInPlace(id, ...) end
    W.seat = function(id, ...) if B.isBot(id) then return nil end return w.seat(id, ...) end
    W.forceOut = function(id, ...) if B.isBot(id) then return true end return w.forceOut(id, ...) end
    W.hud = function(id, ...) if B.isBot(id) then return end return w.hud(id, ...) end
    W.queueHud = function(id, ...) if B.isBot(id) then return end return w.queueHud(id, ...) end
    W.notify = function(id, ...) if B.isBot(id) then return end return w.notify(id, ...) end
    W.removeCar = function(carId, ...)
        if carId ~= nil and B.byCar[carId] ~= nil then B.unmountCar(carId) end
        return w.removeCar(carId, ...)
    end

    C.check = function(id, ...) if B.isBot(id) then return true end return c.check(id, ...) end
    C.enter = function(id, ...) if B.isBot(id) then return true end return c.enter(id, ...) end
    C.leave = function(id, ...) if B.isBot(id) then return true end return c.leave(id, ...) end
    C.owner = function(id, ...) if B.isBot(id) then return nil end return c.owner(id, ...) end
    C.unqueue = function(id, ...) if B.isBot(id) then return false end return c.unqueue(id, ...) end
    C.owned = function(id, ...) if B.isBot(id) then return false end return c.owned(id, ...) end
    C.player = function(id, ...)
        if B.isBot(id) then
            local bot = B.bots[id]
            return bot and { name = bot.name, bot = true } or nil
        end
        return c.player(id, ...)
    end
    C.result = function(id, ...) if B.isBot(id) then return end return c.result(id, ...) end
end

B.install()

AddEventHandler("op77_lightrp:activity:bots", function(enabled)
    B.setEnabled(enabled == true, "/lightrp.bots")
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        B.shutdown()
    elseif name == ChaseCore.resource then
        B.setEnabled(false, "op77_lightrp stopped")
    end
end)

CreateThread(function()
    local tickMs = math.floor(1000 / math.max(1, ChaseConfig.tickHz or 5))
    while not B.stopping do
        Wait(tickMs)
        local ok, err = pcall(B.tick, ChaseWorld.now())
        if not ok then B.warnOnce("tick:" .. tostring(err), "tick error: %s", tostring(err)) end
    end
end)
