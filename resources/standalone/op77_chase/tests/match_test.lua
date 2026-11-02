-- op77_chase match flow, end to end against a fake world and a fake Light RP: the real
-- server/main.lua wiring (contract events, queue, tick loop), the real ChaseCore adapter,
-- match.lua and ranked.lua (no database: ratings in memory).
--   hub join -> queue -> activityCheck -> activityEnter -> placing -> countdown (cars,
--   freeze) -> active -> bust / escape -> intermission -> role swap -> decider -> result
--   -> scoreboard -> out of the car -> activityLeave(returnPlayer) -> cars removed.
-- Plus: admission failure, forfeit (leaveRequest), dropped, placement failure (void),
-- staff stop, a dead player going home, not-ready players, /chase commands, shutdown.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test match_test.lua
local STOP = {}
local env

local function fresh()
    env = {
        clock = 100000, budget = nil, deferThreads = true, threads = {},
        handlers = {}, commands = {}, events = {}, calls = {},
        -- fake Light RP
        owner = {}, blocked = {}, enterFail = {}, left = {}, identity = {},
        -- fake world
        pos = {}, alive = {}, seats = {}, connected = {}, frozen = {}, placements = {}, placeResult = {},
        cars = {}, carSeq = 0, removedCars = {}, swept = {}, respawned = {}, forced = {},
        hud = {}, qhud = {}, notes = {}, replies = {},
    }
    for id = 1, 9 do
        env.identity[id] = { name = "Player" .. id, identifier = "license:p" .. id, characterKey = 1 }
    end
end

local function stubs()
    _G.Open77 = {
        exports = {
            callSync = function(resource, name, ...)
                assert(resource == "op77_lightrp", "only Light RP's exports")
                local a = table.pack(...)
                env.calls[#env.calls + 1] = { name = name, args = a }
                local id = a[1]
                if name == "activityRegister" then env.registered = a[1]; return true end
                if name == "activityCheck" then
                    if env.blocked[id] then return false, env.blocked[id] end
                    if env.owner[id] then return false, "You are already in an activity." end
                    return true
                end
                if name == "activityEnter" then
                    if env.blocked[id] then return false, env.blocked[id] end
                    if env.enterFail[id] then return false, env.enterFail[id] end
                    env.owner[id] = a[2]
                    return true
                end
                if name == "activityLeave" then
                    if env.owner[id] ~= a[2] then return false, "not_owner" end
                    env.owner[id] = nil
                    env.left[#env.left + 1] = { id = id, opts = a[3], at = env.clock }
                    return true
                end
                if name == "activityOwner" then return env.owner[id] end
                if name == "activityPlayer" then return env.owner[id] and env.identity[id] or env.identity[id] end
                error("unexpected export " .. tostring(name))
            end,
        },
        time = { unix = function() return 86400 * 20000 + 3600 end, monotonic = function() return env.clock / 1000 end },
    }
    _G.CreateThread = function(fn) if env.deferThreads then env.threads[#env.threads + 1] = fn else fn() end end
    _G.Wait = function(ms)
        env.clock = env.clock + (ms or 0)
        if env.budget then
            env.budget = env.budget - 1
            if env.budget < 0 then error(STOP) end
        end
    end
    _G.AddEventHandler = function(name, fn) env.handlers[name] = fn end
    _G.RegisterNetEvent = function(name, fn) env.net = env.net or {}; env.net[name] = fn end
    _G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
    _G.RegisterCommand = function(name, fn, restricted) env.commands[name] = { fn = fn, restricted = restricted } end
    _G.GetCurrentResourceName = function() return "op77_chase" end
    _G.MySQL = nil

    ChaseWorld = {
        hudFeed = {},
        now = function() return env.clock end,
        position = function(id) return env.pos[id] end,
        alive = function(id) if env.alive[id] == nil then return true end return env.alive[id] end,
        name = function(id) return "#" .. id end,
        connected = function(id) return env.connected[id] ~= false end,
        setupBucket = function() end,
        place = function(id, point, bucket, done, cover)
            env.placements[#env.placements + 1] = { id = id, point = point, bucket = bucket, cover = cover, done = done }
            local r = env.placeResult[id]
            if r == "pending" then return end
            if r then done(false, r) else env.alive[id] = true; done(true) end
        end,
        freeze = function(id, frozen) env.frozen[id] = frozen; return true end,
        respawnInPlace = function(id) env.respawned[#env.respawned + 1] = id; env.alive[id] = true; return true end,
        createCar = function(spec, mark, bucket)
            env.carSeq = env.carSeq + 1
            env.cars[env.carSeq] = { spec = spec, mark = mark, bucket = bucket }
            return env.carSeq, spec.record
        end,
        removeCar = function(id) env.cars[id] = nil; env.removedCars[#env.removedCars + 1] = id; return true end,
        sweepBucket = function(bucket) env.swept[#env.swept + 1] = bucket; return 0 end,
        carPosition = function(id) local c = env.cars[id]; return c and c.mark.position end,
        seat = function(id) return env.seats[id] end,
        forceOut = function(id) env.forced[#env.forced + 1] = id; env.seats[id] = nil; return true end,
        hud = function(id, payload) env.hud[id] = payload end,
        queueHud = function(id, payload) env.qhud[id] = payload end,
        notify = function(id, kind, message) env.notes[#env.notes + 1] = { id = id, kind = kind, message = message } end,
        reply = function(source, raw, ok, text) env.replies[#env.replies + 1] = { source = source, ok = ok, text = text } end,
    }
end

local function load()
    fresh()
    stubs()
    ChaseQueue, Chase, ChaseCore, ChaseRanked = nil, nil, nil, nil
    dofile("shared/config.lua")
    dofile("server/rules.lua")
    dofile("server/elo.lua")
    dofile("server/queue.lua")
    dofile("server/core.lua")
    dofile("server/match.lua")
    dofile("server/ranked.lua")
    dofile("server/main.lua")
    -- main.lua started two threads: registration, then the tick loop.
    assert(#env.threads == 2, "registration + tick threads")
    env.register, env.loop = env.threads[1], env.threads[2]
    env.threads = {}
    env.register()
    env.deferThreads = false -- from now on (ranked results) threads run inline
end

-- Run the real tick loop for `seconds` of game time.
local function run(seconds)
    env.budget = math.floor(seconds * 1000 / 200)
    local ok, err = pcall(env.loop)
    env.budget = nil
    if ok or err ~= STOP then error(err, 0) end
end

-- Run the loop a tick at a time until `done()` (at most `seconds`).
local function runUntil(done, seconds)
    local limit = env.clock + seconds * 1000
    while not done() do
        assert(env.clock < limit, "condition not reached in time")
        run(0.2)
    end
end

local function events(name)
    local list = {}
    for _, e in ipairs(env.events) do if e.name == name then list[#list + 1] = e end end
    return list
end
local function lastStatus() local l = events("op77_lightrp:activity:status"); return l[#l] and l[#l].args[2] end
local function calls(name, id)
    local n = 0
    for _, c in ipairs(env.calls) do if c.name == name and (id == nil or c.args[1] == id) then n = n + 1 end end
    return n
end
local function noted(id, pattern)
    for _, n in ipairs(env.notes) do if n.id == id and n.message:find(pattern) then return true end end
    return false
end
local function countCars() local n = 0 for _ in pairs(env.cars) do n = n + 1 end return n end
local function only(match)
    local m
    for _, x in pairs(Chase.matches) do assert(m == nil, "one match"); m = x end
    return m or match
end
local function roleOf(match, role) for id, r in pairs(match.roles) do if r == role then return id end end end

-- Stationary cop and runner `gap` metres apart, in the match bucket.
local function gap(match, metres)
    local cop, runner = roleOf(match, "cop"), roleOf(match, "runner")
    env.pos[runner] = { x = 0, y = 0, z = 0, bucket = match.bucket }
    env.pos[cop] = { x = metres, y = 0, z = 0, bucket = match.bucket }
end

local function join(id, options) env.handlers["op77_lightrp:activity:join"](id, "chase.1v1", options) end

-- ════════════════════════════════════════════════════════════════ the full match
do
    load()
    assert(env.registered.id == "chase.1v1" and env.registered.resource == "op77_chase" and env.registered.kind == "chase")
    assert(env.registered.minPlayers == 2 and env.registered.maxPlayers == 2 and env.registered.caps.vehicles == false)
    assert(lastStatus().phase == "idle" and lastStatus().joinable == true)

    -- Two players join from the hub (Light RP already checked them).
    join(1, { mode = "car" })
    assert(env.qhud[1].queued == true and env.qhud[1].position == 1 and env.qhud[1].mode == "vehicle")
    assert(lastStatus().phase == "lobby" and lastStatus().queued == 1)
    join(1, { mode = "car" })
    assert(#ChaseQueue.entries == 1, "a second join does not queue twice")
    join(2)
    assert(calls("activityCheck") == 0, "a hub join is not re-checked at the door")
    assert(calls("activityEnter") == 0, "queued players are not owned yet")

    -- Pairing: re-check, activityEnter both, match in the chase bucket range.
    run(1.0)
    local match = only()
    assert(match.mode == "vehicle" and match.bucket == 4300000)
    assert(env.owner[1] == "chase.1v1" and env.owner[2] == "chase.1v1")
    assert(calls("activityCheck", 1) >= 1 and calls("activityCheck", 2) >= 1)
    assert(env.qhud[1].queued == false and env.qhud[2].queued == false)
    assert(#env.placements == 2 and env.placements[1].bucket == 4300000 and env.placements[1].cover ~= nil, "round 1 is covered")
    assert(match.state == "countdown", "both placed -> countdown")
    assert(lastStatus().phase == "running" and lastStatus().players == 2)
    -- Countdown: two cars in the match bucket, both players held.
    assert(countCars() == 2)
    for _, car in pairs(env.cars) do assert(car.bucket == 4300000) end
    assert(env.frozen[1] == true and env.frozen[2] == true)
    local cop1, runner1 = roleOf(match, "cop"), roleOf(match, "runner")
    assert(cop1 and runner1 and cop1 ~= runner1)
    assert(env.hud[cop1].state == "countdown" and env.hud[cop1].role == "cop" and env.hud[runner1].role == "runner")
    assert(env.hud[cop1].activity == "chase.1v1", "the client knows which chase it draws")
    assert(env.hud[cop1].hideDots and env.hud[cop1].hideDots[1] == runner1 and env.hud[runner1].hideDots == nil,
        "the cop's minimap hides the runner; the runner's hides nobody")
    assert(noted(runner1, "RUNNER") and noted(cop1, "COP"))

    -- Round 1: GO, a stopped runner 10 m from the cop is busted in ~4 s.
    run(10.2)
    assert(match.state == "active" and env.frozen[1] == false and env.frozen[2] == false, "released at GO")
    gap(match, 10.0)
    run(2.0)
    assert(env.hud[runner1].separation ~= nil and env.hud[cop1].separation == nil, "only the runner sees the gap")
    assert(env.hud[cop1].bustMeter > 0 and env.hud[cop1].bustClosing == true)
    run(4.0)
    assert(match.state == "intermission", "busted -> intermission")
    assert(match.score[cop1] == 1 and match.score[runner1] == 0 and match.rounds[1].outcome == "runner_busted")
    assert(env.hud[cop1].state == "intermission" and env.hud[cop1].won == true and env.hud[cop1].nextRound == 2)
    assert(noted(runner1, "Roles swap"))

    -- Round 2: roles swap; new cars (the old ones removed); the new cop (runner1) busts.
    local oldCars = {}
    for id in pairs(env.cars) do oldCars[#oldCars + 1] = id end
    run(8.4)
    assert(match.round == 2 and match.roles[cop1] == "runner" and match.roles[runner1] == "cop", "roles swapped")
    assert(match.state == "countdown" and #env.placements == 4 and env.placements[3].cover == nil, "no cover after round 1")
    for _, id in ipairs(oldCars) do assert(env.cars[id] == nil, "round 1 cars removed") end
    assert(countCars() == 2)
    run(10.2)
    assert(match.state == "active")
    gap(match, 10.0)
    run(6.0)
    assert(match.score[cop1] == 1 and match.score[runner1] == 1 and match.rounds[2].outcome == "runner_busted")
    assert(match.deciderAdded == true and match.state == "intermission", "level after two rounds: decider")
    assert(env.hud[cop1].nextIsDecider == true)

    -- Decider: roles swap back; runner1 runs again and holds a 150 m gap until he escapes.
    run(8.4 + 10.2)
    assert(match.round == 3 and match.roles[runner1] == "runner" and match.state == "active")
    assert(env.hud[cop1].decider == true and env.hud[cop1].roundCount == 3)
    gap(match, 150.0)
    env.seats[runner1] = 99 -- sitting in a car when the match ends
    local started = env.clock
    runUntil(function() return match.state ~= "active" end, 40.0)
    assert(env.clock - started > 25000, "an escape takes the arm delay plus the grace")
    assert(match.state == "resolved" and match.champion == runner1 and match.score[runner1] == 2)
    assert(match.rounds[3].outcome == "runner_escaped")
    assert(env.hud[runner1].state == "resolved" and env.hud[runner1].matchResult == "win" and env.hud[cop1].matchResult == "loss")

    -- Results (host-wide event), Elo in memory.
    local results = events("op77_lightrp:activity:result")
    assert(#results == 2)
    local byId = {}
    for _, e in ipairs(results) do assert(e.args[2] == "chase.1v1"); byId[e.args[1]] = e.args[3] end
    local w, l = byId[runner1], byId[cop1]
    assert(w.won == true and w.placement == 1 and w.score == 2 and w.reputation == 30)
    assert(l.won == false and l.placement == 2 and l.score == 1 and l.reputation == 10)
    assert(w.stats.busts == 1 and w.stats.escapes == 1 and w.stats.copRounds == 1 and w.stats.runnerRounds == 2 and w.stats.mode == "vehicle")
    assert(l.stats.busts == 1 and l.stats.escapes == 0 and l.stats.copRounds == 2)
    assert(w.stats.elo == 1020 and w.stats.eloDelta == 20 and l.stats.elo == 980 and l.stats.eloDelta == -20)
    assert(w.stats.timeMs > 0 and w.cash == nil and w.items == nil, "no cash, no items")
    assert(ChaseRanked.ratings["license:p" .. runner1 .. "#1"].rating == 1020)
    assert(#env.left == 0, "the scoreboard stays on screen first")

    -- Home: out of the car, then activityLeave(returnPlayer = true); cars gone; bucket freed.
    run(5.2)
    assert(env.forced[1] == runner1)
    run(1.0)
    assert(#env.left == 2 and env.left[1].opts.returnPlayer == true and env.left[2].opts.returnPlayer == true)
    assert(env.owner[1] == nil and env.owner[2] == nil)
    assert(env.hud[1].state == "idle" and env.hud[2].state == "idle")
    assert(countCars() == 0 and env.swept[#env.swept] == 4300000)
    assert(next(Chase.matches) == nil and Chase.bucketOwner[4300000] == nil and Chase.playerMatch[1] == nil)
    run(1.2)
    assert(lastStatus().phase == "idle")

    -- A rematch inside ten minutes continues the alternation.
    join(1); join(2)
    run(1.2)
    local again = only()
    assert(again.roles[cop1] == "runner" and again.roles[runner1] == "cop", "cop1 ended as cop: he starts the rematch as the runner")
    print("PASS full match (queue, enter, place, freeze, cars, bust, swap, escape, decider, results, Elo, leave, cleanup, rematch)")
end

-- ════════════════════════════════════════════════════════════════ admission failure
do
    load()
    env.enterFail[2] = "You are in a mission."
    join(1); join(2)
    run(1.0)
    assert(next(Chase.matches) == nil)
    assert(env.owner[1] == nil and #env.left == 1 and env.left[1].id == 1, "the one who entered is handed back")
    assert(noted(2, "could not start: You are in a mission."))
    assert(ChaseQueue.position(1) == 1 and ChaseQueue.position(2) == nil, "the other keeps his place")
    print("PASS admission failure")
end

-- ════════════════════════════════════════════════════════════════ forfeit (leaveRequest)
do
    load()
    join(1); join(2)
    run(1.0 + 10.4)
    local match = only()
    assert(match.state == "active")
    gap(match, 50.0)
    run(1.0)
    env.handlers["op77_lightrp:activity:leaveRequest"](1, "chase.1v1")
    assert(match.state == "resolved" and match.champion == 2 and match.leaver == 1)
    run(0.4)
    assert(#env.left == 1 and env.left[1].id == 1, "the leaver goes home at once")
    run(5.2)
    assert(#env.left == 2 and env.left[2].id == 2, "the other after the scoreboard")
    local results = events("op77_lightrp:activity:result")
    local byId = {}
    for _, e in ipairs(results) do byId[e.args[1]] = e.args[3] end
    assert(byId[1].reputation == 0 and byId[1].won == false and byId[1].stats.forfeit == true)
    assert(byId[2].reputation == 15 and byId[2].won == true, "forfeit win")
    assert(byId[1].stats.eloDelta < 0, "an abandonment is rated as a loss")
    print("PASS forfeit")
end

-- ════════════════════════════════════════════════════════════════ forfeit before any round played
do
    load()
    join(1); join(2)
    run(1.0)
    assert(only().state == "countdown")
    env.handlers["op77_lightrp:activity:leaveRequest"](2, "chase.1v1")
    run(6.0)
    local results = events("op77_lightrp:activity:result")
    for _, e in ipairs(results) do
        assert(e.args[3].reputation == 0 and e.args[3].stats.elo == nil, "nothing played: not rated, no reputation")
    end
    assert(#env.left == 2 and env.frozen[1] == false and env.frozen[2] == false, "a countdown freeze is released")
    print("PASS unplayed forfeit")
end

-- ════════════════════════════════════════════════════════════════ dropped (Light RP released him)
do
    load()
    join(1); join(2)
    run(1.0 + 10.4)
    local match = only()
    gap(match, 50.0)
    env.owner[2] = nil -- Light RP already released ownership
    env.handlers["op77_lightrp:activity:dropped"](2, "chase.1v1", "disconnected")
    assert(match.state == "resolved" and match.champion == 1)
    run(6.0)
    assert(#env.left == 1 and env.left[1].id == 1, "never activityLeave for a dropped player")
    assert(calls("activityLeave", 2) == 0)
    local results = events("op77_lightrp:activity:result")
    assert(#results == 1 and results[1].args[1] == 1, "no result for the dropped player")
    assert(countCars() == 0 and next(Chase.matches) == nil)
    print("PASS dropped")
end

-- ════════════════════════════════════════════════════════════════ placement failure = void
do
    load()
    env.placeResult[2] = "settle_superseded"
    join(1); join(2)
    run(1.0)
    local match
    for _, m in pairs(Chase.matches) do match = m end
    assert(match and match.void and match.state == "resolved")
    assert(env.hud[1].matchResult == "void")
    assert(#events("op77_lightrp:activity:result") == 0, "void: no result")
    run(6.0)
    assert(#env.left == 2 and countCars() == 0)
    -- Timeout variant: a placement that never reports.
    load()
    env.placeResult[1] = "pending"
    join(1); join(2)
    run(1.0)
    local pending = only()
    assert(pending.state == "placing")
    run(41.0)
    assert(pending.void and pending.state == "resolved")
    run(6.0)
    assert(calls("activityLeave", 2) == 1 and calls("activityLeave", 1) == 0, "an in-flight placement settles before going home")
    env.placements[1].done(false, "timeout")
    run(1.0)
    assert(calls("activityLeave", 1) == 1)
    print("PASS placement failure (void)")
end

-- ════════════════════════════════════════════════════════════════ a dead player goes home alive
do
    load()
    join(1); join(2)
    run(1.0 + 10.4)
    local match = only()
    gap(match, 50.0)
    local runner = roleOf(match, "runner")
    env.alive[runner] = false
    run(0.4)
    assert(match.rounds[1].outcome == "runner_down" and match.state == "intermission")
    -- Round 2 placement respawns him (the fake place marks him alive); kill him again at the end.
    run(8.4 + 10.2)
    assert(match.state == "active")
    gap(match, 50.0)
    local cop = roleOf(match, "cop")
    env.alive[cop] = false
    run(0.4)
    assert(match.state == "resolved")
    runUntil(function() return #env.respawned > 0 end, 6.0)
    assert(env.respawned[1] == cop and calls("activityLeave", cop) == 0, "respawned in place before going home")
    run(0.2)
    assert(calls("activityLeave", cop) == 1 and calls("activityLeave", roleOf(match, "runner")) == 1)
    print("PASS dead player respawned before activityLeave")
end

-- ════════════════════════════════════════════════════════════════ staff stop, shutdown
do
    load()
    assert(env.commands["chase.stop"].restricted == true and env.commands["chase.force"].restricted == true
        and env.commands["chase.status"].restricted == true and env.commands["chase"].restricted == false)
    env.commands["chase.force"].fn(0, { "3", "4", "foot" }, "chase.force 3 4 foot")
    local match = only()
    assert(match.mode == "foot" and env.owner[3] == "chase.1v1" and env.owner[4] == "chase.1v1")
    run(1.0)
    assert(countCars() == 0, "no cars on foot")
    env.commands["chase.stop"].fn(0, { tostring(match.id) }, "chase.stop")
    assert(match.void and match.state == "resolved")
    run(6.0)
    assert(#env.left == 2 and next(Chase.matches) == nil)

    -- Resource stop: cars removed and holds released (Light RP returns the players).
    join(1); join(2)
    run(1.0)
    assert(countCars() == 2 and env.frozen[1] == true)
    env.handlers["onResourceStop"]("op77_chase")
    assert(countCars() == 0 and env.frozen[1] == false and env.frozen[2] == false)

    -- Light RP stops: it already returned everyone; void, never activityLeave, cars gone.
    load()
    join(1); join(2); join(3)
    run(1.0)
    assert(countCars() == 2 and ChaseQueue.position(3) == 1)
    env.owner = {}
    env.handlers["onResourceStop"]("op77_lightrp")
    assert(env.frozen[1] == false and env.hud[1].state == "idle" and env.qhud[3].queued == false and ChaseQueue.size() == 0)
    run(1.0)
    assert(countCars() == 0 and next(Chase.matches) == nil and calls("activityLeave") == 0)
    assert(#events("op77_lightrp:activity:result") == 0)
    -- ... and when it is back, the activity is registered again.
    local before = calls("activityRegister")
    env.handlers["onResourceStart"]("op77_lightrp")
    assert(calls("activityRegister") == before + 1)
    print("PASS staff stop, shutdown, Light RP restart")
end

-- ════════════════════════════════════════════════════════════════ queue: /chase, not ready, leave
do
    load()
    local chase = env.commands["chase"].fn
    env.blocked[5] = "You are driving."
    chase(5, {}, "/chase")
    assert(env.replies[#env.replies].ok == false and env.replies[#env.replies].text == "You are driving.", "/chase checks at the door")
    env.blocked[5] = nil
    chase(5, { "foot" }, "/chase foot")
    assert(env.replies[#env.replies].ok == true and ChaseQueue.position(5) == 1)
    chase(5, { "status" }, "/chase status")
    assert(env.replies[#env.replies].text:find("on foot"))
    chase(5, { "boat" }, "/chase boat")
    assert(env.replies[#env.replies].ok == false)
    chase(5, { "leave" }, "/chase leave")
    assert(ChaseQueue.position(5) == nil and env.qhud[5].queued == false)

    -- Hub leaveRequest for a queued (not owned) player: dequeue.
    join(6)
    env.handlers["op77_lightrp:activity:leaveRequest"](6, "chase.1v1")
    assert(ChaseQueue.size() == 0)
    -- Another activity's events are ignored.
    env.handlers["op77_lightrp:activity:join"](6, "arena.ffa", {})
    assert(ChaseQueue.size() == 0)
    env.handlers["op77_lightrp:activity:join"]("nonsense", "chase.1v1", {})
    assert(ChaseQueue.size() == 0)

    -- Not ready at pairing: told (rate-limited), skipped, dropped after two minutes.
    join(7); join(8)
    env.blocked[7] = "You are in a mission."
    run(1.0)
    assert(next(Chase.matches) == nil and noted(7, "can't go yet: You are in a mission."))
    local notices = 0
    for _, n in ipairs(env.notes) do if n.id == 7 and n.message:find("can't go yet") then notices = notices + 1 end end
    run(10.0)
    local after = 0
    for _, n in ipairs(env.notes) do if n.id == 7 and n.message:find("can't go yet") then after = after + 1 end end
    assert(after == notices, "notices are rate-limited")
    run(115.0)
    assert(ChaseQueue.position(7) == nil and noted(7, "You left the chase queue"), "dropped after notReadyDropSeconds")
    assert(ChaseQueue.position(8) == 1)

    -- A queued player who switches character or disconnects leaves the queue.
    env.handlers["op77_lightrp:characterChanged"](8)
    assert(ChaseQueue.size() == 0)
    join(9)
    _G.source = 9
    env.handlers["playerDropped"]("quit")
    _G.source = nil
    assert(ChaseQueue.size() == 0)
    print("PASS queue commands and eligibility")
end

print("PASS: op77_chase match flow (contract, queue, rounds, swap, decider, results, Elo, forfeit, dropped, void, respawn, staff, shutdown)")
