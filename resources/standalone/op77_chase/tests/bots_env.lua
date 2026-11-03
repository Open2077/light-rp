-- Shared fake server for tests/bots_test.lua and tests/pve_test.lua: the whole resource
-- (every server file, bots.lua included) against a fake Light RP (exports + host-wide
-- events, activityBots included), a fake ChaseWorld, fake Open77 NPC / vehicle-AI natives
-- that record every call, a MySQL that records any touch, and a small scheduler: every
-- CreateThread is a coroutine, Wait(ms) yields, H.run(seconds) advances the clock.
local H = {}
local env

local function rec(list, name, ...)
    list[#list + 1] = { name = name, args = table.pack(...) }
end

function H.fresh()
    env = {
        clock = 100000, threads = {}, threadSeq = 0,
        handlers = {}, net = {}, commands = {}, events = {}, calls = {}, registered = {},
        owner = {}, blocked = {}, enterFail = {}, left = {}, identity = {},
        pos = {}, alive = {}, seats = {}, connected = {}, frozen = {}, placements = {}, placeResult = {},
        cars = {}, carSeq = 0, removedCars = {}, swept = {}, respawned = {}, forced = {},
        hud = {}, hudLog = {}, qhud = {}, notes = {}, replies = {},
        npcs = {}, npcSeq = 500, removedNpcs = {}, npcRefuse = {}, ai = {}, tasks = {}, taskSeq = 0,
        aiState = {}, db = {}, botsEnabled = false,
        -- NCPD Escape: the fake PreventionService ({ level, maxLevel } per player), every
        -- wanted call, a refusal per player, the population per bucket, this resource's KVP.
        wanted = {}, wantedLog = {}, wantedRefuse = {}, population = {}, populationRefuse = nil, depopulated = {}, kvp = {},
        tierRefuse = {},
    }
    for id = 1, 12 do
        env.identity[id] = { name = "Player" .. id, identifier = "license:p" .. id, characterKey = 1 }
    end
    H.env = env
    return env
end

local function natives()
    local npcs = {
        ai = { tasks = 0, frozen = 1, native = 2 },
        damage = { mortal = 0, immortal = 1, invulnerable = 2 },
        channels = { movement = 1 },
        create = function(def)
            rec(env.ai, "npcs.create", def)
            local refused = env.npcRefuse[def.record] or env.npcRefuse["*"]
            if refused then return nil, refused end
            env.npcSeq = env.npcSeq + 1
            env.npcs[env.npcSeq] = { def = def, pos = { x = def.position.x, y = def.position.y, z = def.position.z }, bucket = def.bucket, alive = true }
            return env.npcSeq
        end,
        remove = function(id)
            rec(env.ai, "npcs.remove", id)
            env.npcs[id] = nil
            env.removedNpcs[#env.removedNpcs + 1] = id
            return true
        end,
        presence = function(id)
            local n = env.npcs[id]
            if not n then return nil end
            return { x = n.pos.x, y = n.pos.y, z = n.pos.z, bucket = n.bucket, alive = n.alive, owned = true, resource = "op77_chase" }
        end,
        get = function(id)
            local n = env.npcs[id]
            if not n then return nil end
            return { id = id, position = n.pos, bucket = n.bucket, alive = n.alive }
        end,
        all = function()
            local rows = {}
            for id, n in pairs(env.npcs) do rows[#rows + 1] = { id = id, bucket = n.bucket, resource = "op77_chase", owned = true } end
            return rows
        end,
        tasks = {
            moveTo = function(...) rec(env.ai, "npcs.tasks.moveTo", ...); env.taskSeq = env.taskSeq + 1; return env.taskSeq end,
            flee = function(...) rec(env.ai, "npcs.tasks.flee", ...); env.taskSeq = env.taskSeq + 1; return env.taskSeq end,
            clear = function(...) rec(env.ai, "npcs.tasks.clear", ...); return true end,
            get = function(_, task) if env.tasks[task] == "done" then return nil end return { status = "running" } end,
            setDriverAbility = function(...) rec(env.ai, "npcs.tasks.setDriverAbility", ...); return true end,
        },
    }
    local ai = {
        attachDriver = function(car, opts)
            rec(env.ai, "vehicles.ai.attachDriver", car, opts)
            if env.attachRefuse then return nil, env.attachRefuse end
            return { status = "idle" }
        end,
        chase = function(...) rec(env.ai, "vehicles.ai.chase", ...); return true end,
        followRoute = function(...)
            rec(env.ai, "vehicles.ai.followRoute", ...)
            if env.routeRefuse then return nil, env.routeRefuse end
            return true
        end,
        joinTraffic = function(...) rec(env.ai, "vehicles.ai.joinTraffic", ...); return true end,
        driveTo = function(...) rec(env.ai, "vehicles.ai.driveTo", ...); return true end,
        stop = function(...) rec(env.ai, "vehicles.ai.stop", ...); return true end,
        removeDriver = function(...) rec(env.ai, "vehicles.ai.removeDriver", ...); return true end,
        state = function(car) return env.aiState[car] or { status = "running" } end,
    }
    return npcs, ai
end

function H.stubs()
    local npcs, ai = natives()
    _G.Open77 = {
        exports = {
            callSync = function(resource, name, ...)
                assert(resource == "op77_lightrp", "only Light RP's exports")
                local a = table.pack(...)
                env.calls[#env.calls + 1] = { name = name, args = a }
                local id = a[1]
                if name == "activityRegister" then env.registered[a[1].id] = a[1]; return true end
                if name == "activityBots" then
                    if env.noBotsExport then error("no such export activityBots") end
                    return env.botsEnabled == true
                end
                -- env.tierRefuse[id] = { [difficulty] = reason }: Light RP's reputation tier gate.
                local tier = env.tierRefuse and env.tierRefuse[id]
                local wantedDifficulty = type(a[3]) == "table" and a[3].difficulty or nil
                if name == "activityCheck" then
                    if env.blocked[id] then return false, env.blocked[id] end
                    if env.owner[id] then return false, "You are already in an activity." end
                    if tier and wantedDifficulty and tier[wantedDifficulty] then return false, tier[wantedDifficulty] end
                    return true
                end
                if name == "activityEnter" then
                    assert(type(id) == "number" and id > 0, "a bot never reaches Light RP")
                    if env.blocked[id] then return false, env.blocked[id] end
                    if env.enterFail[id] then return false, env.enterFail[id] end
                    if tier and wantedDifficulty and tier[wantedDifficulty] then return false, tier[wantedDifficulty] end
                    env.owner[id] = a[2]
                    return true
                end
                if name == "activityLeave" then
                    assert(type(id) == "number" and id > 0, "a bot never reaches Light RP")
                    if env.owner[id] ~= a[2] then return false, "not_owner" end
                    env.owner[id] = nil
                    env.left[#env.left + 1] = { id = id, activity = a[2], opts = a[3], at = env.clock }
                    return true
                end
                if name == "activityOwner" then return env.owner[id] end
                if name == "activityPlayer" then return env.identity[id] end
                error("unexpected export " .. tostring(name))
            end,
        },
        time = { unix = function() return 86400 * 20000 + 3600 end, monotonic = function() return env.clock / 1000 end },
        npcs = npcs,
        vehicles = { ai = ai, all = function() return {} end, remove = function() return true end },
    }
    _G.CreateThread = function(fn)
        env.threadSeq = env.threadSeq + 1
        env.threads[#env.threads + 1] = { co = coroutine.create(fn), wake = env.clock, seq = env.threadSeq }
    end
    _G.Wait = function(ms) coroutine.yield(ms or 0) end
    _G.AddEventHandler = function(name, fn)
        env.handlers[name] = env.handlers[name] or {}
        table.insert(env.handlers[name], fn)
    end
    _G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
    _G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
    _G.TriggerClientEvent = function(_, target) assert(type(target) == "number" and target > 0, "never a broadcast") end
    _G.RegisterCommand = function(name, fn, restricted) env.commands[name] = { fn = fn, restricted = restricted } end
    _G.GetCurrentResourceName = function() return "op77_chase" end
    _G.GetPlayers = function() return {} end
    -- Any touch of the database is recorded (bot matches and NCPD Escape must never write).
    _G.MySQL = setmetatable({}, { __index = function(_, k)
        env.db[#env.db + 1] = tostring(k)
        return setmetatable({}, { __index = function(_, k2)
            env.db[#env.db + 1] = tostring(k) .. "." .. tostring(k2)
            return function() return nil end
        end })
    end })

    ChaseWorld = {
        hudFeed = {},
        now = function() return env.clock end,
        position = function(id)
            assert(type(id) == "number" and id > 0, "a bot never reaches the player world")
            local p = env.pos[id]
            if type(p) == "function" then return p(env.clock) end
            return p
        end,
        alive = function(id)
            assert(id > 0, "a bot never reaches the player world")
            if env.alive[id] == nil then return true end
            return env.alive[id]
        end,
        name = function(id) assert(id > 0, "bot name from ChaseBots"); return "#" .. id end,
        connected = function(id) return env.connected[id] ~= false end,
        setupBucket = function() end,
        depopulate = function(bucket) env.depopulated[#env.depopulated + 1] = bucket; env.population[bucket] = nil end,
        populate = function(bucket, opts)
            if env.populationRefuse then return false, env.populationRefuse end
            env.population[bucket] = opts
            return true
        end,
        setWanted = function(id, level)
            assert(type(id) == "number" and id > 0, "a bot has no wanted level")
            env.wantedLog[#env.wantedLog + 1] = { id = id, op = "set", level = level, at = env.clock }
            if env.wantedRefuse[id] then return false, env.wantedRefuse[id] end
            local w = env.wanted[id] or { level = 0, maxLevel = 5 }
            w.level = math.min(level, w.maxLevel)
            env.wanted[id] = w
            return true, { level = w.level, requested = level, maxLevel = w.maxLevel }
        end,
        setMaxWanted = function(id, level)
            assert(type(id) == "number" and id > 0, "a bot has no wanted level")
            env.wantedLog[#env.wantedLog + 1] = { id = id, op = "max", level = level, at = env.clock }
            if env.wantedRefuse[id] then return false, env.wantedRefuse[id] end
            local w = env.wanted[id] or { level = 0, maxLevel = 5 }
            w.maxLevel = level
            w.level = math.min(w.level, level)
            env.wanted[id] = w
            return true, { level = w.level, maxLevel = level }
        end,
        getWanted = function(id) local w = env.wanted[id] or { level = 0, maxLevel = 5 }; return { level = w.level, maxLevel = w.maxLevel, enabled = true } end,
        identifier = function(id) return env.identity[id] and env.identity[id].identifier or nil end,
        kvpSet = function(key, value) env.kvp[key] = value; return true end,
        kvpDelete = function(key) local had = env.kvp[key] ~= nil; env.kvp[key] = nil; return had end,
        kvpFind = function(prefix)
            local rows = {}
            for k, v in pairs(env.kvp) do if k:sub(1, #prefix) == prefix then rows[#rows + 1] = { key = k, value = v } end end
            table.sort(rows, function(a, b) return a.key < b.key end)
            return rows
        end,
        place = function(id, point, bucket, done, cover)
            assert(id > 0, "a bot is placed by ChaseBots")
            env.placements[#env.placements + 1] = { id = id, point = point, bucket = bucket, cover = cover }
            local r = env.placeResult[id]
            if r == "pending" then return end
            if r then done(false, r) else
                env.alive[id] = true
                env.pos[id] = env.pos[id] or { x = point.position.x, y = point.position.y, z = point.position.z }
                done(true)
            end
        end,
        freeze = function(id, frozen) assert(id > 0, "a bot is held by ChaseBots"); env.frozen[id] = frozen; return true end,
        respawnInPlace = function(id) env.respawned[#env.respawned + 1] = id; env.alive[id] = true; return true end,
        createCar = function(spec, mark, bucket)
            env.carSeq = env.carSeq + 1
            env.cars[env.carSeq] = { spec = spec, mark = mark, bucket = bucket }
            return env.carSeq, spec.record
        end,
        removeCar = function(id) env.cars[id] = nil; env.removedCars[#env.removedCars + 1] = id; return true end,
        sweepBucket = function(bucket) env.swept[#env.swept + 1] = bucket; return 0 end,
        carPosition = function(id) local c = env.cars[id]; return c and (c.pos or c.mark.position) end,
        seat = function(id) assert(id > 0, "a bot has no seat lookup"); return env.seats[id] end,
        forceOut = function(id) env.forced[#env.forced + 1] = id; env.seats[id] = nil; return true end,
        hud = function(id, payload)
            assert(id > 0, "never a HUD for a bot")
            env.hud[id] = payload
            env.hudLog[#env.hudLog + 1] = { id = id, payload = payload }
        end,
        queueHud = function(id, payload) assert(id > 0, "never a HUD for a bot"); env.qhud[id] = payload end,
        notify = function(id, kind, message, ms, title)
            assert(id > 0, "never a notification for a bot")
            env.notes[#env.notes + 1] = { id = id, kind = kind, message = message, title = title }
        end,
        announce = function(text, opts) env.events[#env.events + 1] = { name = "op77_lightrp:announce", args = table.pack(text, opts) } end,
        reply = function(source, raw, ok, text) env.replies[#env.replies + 1] = { source = source, ok = ok, text = text } end,
    }
end

local FILES = {
    "shared/config.lua", "server/rules.lua", "server/elo.lua", "server/queue.lua", "server/core.lua", "server/bots.lua",
    "server/match.lua", "server/ranked.lua", "server/wanted_rules.lua", "server/wanted_lobby.lua", "server/wanted.lua",
    "server/escape_rules.lua", "server/police.lua", "server/pve.lua", "server/main.lua", "server/wanted_main.lua", "server/pve_main.lua",
}

-- opts = { botsEnabled, noBotsExport, botFill = { [activityId] = true }, before = function(env) end
-- (after the stubs, before the files), after = function(env) end (after the config, before
-- the other files: config overrides) }
function H.load(opts)
    opts = opts or {}
    H.fresh()
    H.stubs()
    env.botsEnabled = opts.botsEnabled == true
    env.noBotsExport = opts.noBotsExport
    if opts.before then opts.before(env) end
    ChaseQueue, Chase, ChaseCore, ChaseRanked, ChaseMain, ChaseBots = nil, nil, nil, nil, nil, nil
    WantedRules, ChaseWantedLobby, ChaseWanted, ChaseWantedMain, ChasePve, ChasePveMain = nil, nil, nil, nil, nil, nil
    ChaseEscapeRules, ChasePolice = nil, nil
    for i, f in ipairs(FILES) do
        dofile(f)
        if i == 1 then
            for aid, on in pairs(opts.botFill or {}) do ChaseConfig.bots.fill[aid] = on end
            if opts.after then opts.after(env) end
        end
    end
    H.run(0.2) -- the registrations
    return env
end

-- The wanted level the server holds for a player (the fake PreventionService).
function H.wanted(id) return env.wanted[id] or { level = 0, maxLevel = 5 } end

-- Advance the clock by `seconds`, resuming every thread whose Wait is over, in order.
function H.run(seconds)
    local target = env.clock + math.floor(seconds * 1000)
    while true do
        local best
        for _, t in ipairs(env.threads) do
            if t.wake <= target and (best == nil or t.wake < best.wake or (t.wake == best.wake and t.seq < best.seq)) then best = t end
        end
        if best == nil then break end
        if best.wake > env.clock then env.clock = best.wake end
        local ok, ms = coroutine.resume(best.co)
        if not ok then error(debug.traceback(best.co, tostring(ms)), 0) end
        if coroutine.status(best.co) == "dead" then
            for i, t in ipairs(env.threads) do if t == best then table.remove(env.threads, i) break end end
        else
            best.wake = env.clock + math.max(1, ms or 0)
        end
    end
    env.clock = target
end

function H.runUntil(done, seconds, what)
    local limit = env.clock + seconds * 1000
    while not done() do
        assert(env.clock < limit, (what or "condition") .. " not reached in time")
        H.run(0.2)
    end
end

function H.fire(name, ...)
    for _, fn in ipairs(env.handlers[name] or {}) do fn(...) end
end

function H.command(name, source, args)
    _G.source = source
    env.commands[name].fn(source, args or {}, name)
end

function H.events(name)
    local list = {}
    for _, e in ipairs(env.events) do if e.name == name then list[#list + 1] = e end end
    return list
end

function H.results(id, activity)
    local out = {}
    for _, e in ipairs(H.events("op77_lightrp:activity:result")) do
        if (id == nil or e.args[1] == id) and (activity == nil or e.args[2] == activity) then out[#out + 1] = e end
    end
    return out
end

function H.aiCalls(name, filter)
    local out = {}
    for _, c in ipairs(env.ai) do
        if c.name == name and (filter == nil or filter(c.args)) then out[#out + 1] = c end
    end
    return out
end

function H.noted(id, pattern)
    for _, n in ipairs(env.notes) do if n.id == id and n.message:find(pattern) then return true end end
    return false
end

function H.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function H.left(id, activity)
    for _, l in ipairs(env.left) do if l.id == id and (activity == nil or l.activity == activity) then return l end end
    return nil
end

-- The car a bot drives (nil before it is mounted).
function H.botCar(botId)
    local bot = ChaseBots.bots[botId]
    return bot and bot.carId
end

function H.moveCar(carId, pos)
    assert(env.cars[carId], "no car " .. tostring(carId))
    env.cars[carId].pos = { x = pos.x, y = pos.y, z = pos.z or 0 }
end

function H.offset(p, dx, dy)
    return { x = p.x + (dx or 0), y = p.y + (dy or 0), z = p.z or 0 }
end

return H
