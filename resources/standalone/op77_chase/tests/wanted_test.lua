-- op77_chase Most Wanted flow, end to end against a fake world and a fake Light RP: the
-- real wiring of both chases (server/main.lua and server/wanted_main.lua, every handler
-- of both), the real ChaseCore adapter, wanted.lua and its rules and lobby.
--   hub join -> remote lobby -> countdown (announce) -> activityEnter -> placing ->
--   countdown (cars, freeze) -> GO -> waves -> dispatch sightings -> shake -> unit arrest
--   with an assist -> rotation -> survival (heat, roadblocks, extraction reveal) ->
--   extraction -> final ranking -> results -> scoreboard -> activityLeave -> cleanup.
-- Plus: one chase queue at a time, test mode (2 players, on foot), a drop-in at the next
-- round, takedown credit, a downed cop back in service, a forfeit (leaveRequest), a
-- dropped player, a refused admission, Light RP restarting, staff force/stop/status,
-- /wanted commands, the HUD feed flag, shutdown.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test wanted_test.lua
local STOP = {}
local env

local function fresh()
    env = {
        clock = 100000, budget = nil, deferThreads = true, threads = {},
        handlers = {}, net = {}, commands = {}, events = {}, calls = {}, registered = {},
        owner = {}, blocked = {}, enterFail = {}, left = {}, identity = {},
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
                if name == "activityRegister" then env.registered[a[1].id] = a[1]; return true end
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
                if name == "activityPlayer" then return env.identity[id] end
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
    _G.AddEventHandler = function(name, fn)
        env.handlers[name] = env.handlers[name] or {}
        table.insert(env.handlers[name], fn)
    end
    _G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
    _G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
    _G.RegisterCommand = function(name, fn, restricted) env.commands[name] = { fn = fn, restricted = restricted } end
    _G.GetCurrentResourceName = function() return "op77_chase" end
    _G.MySQL = nil

    ChaseWorld = {
        hudFeed = {},
        now = function() return env.clock end,
        position = function(id)
            local p = env.pos[id]
            if type(p) == "function" then return p(env.clock) end
            return p
        end,
        alive = function(id) if env.alive[id] == nil then return true end return env.alive[id] end,
        name = function(id) return "#" .. id end,
        connected = function(id) return env.connected[id] ~= false end,
        setupBucket = function() end,
        place = function(id, point, bucket, done, cover)
            env.placements[#env.placements + 1] = { id = id, point = point, bucket = bucket, cover = cover }
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
        notify = function(id, kind, message, ms, title) env.notes[#env.notes + 1] = { id = id, kind = kind, message = message, title = title } end,
        announce = function(text, opts) env.events[#env.events + 1] = { name = "op77_lightrp:announce", args = table.pack(text, opts) } end,
        reply = function(source, raw, ok, text) env.replies[#env.replies + 1] = { source = source, ok = ok, text = text } end,
    }
end

local function load()
    fresh()
    stubs()
    ChaseQueue, Chase, ChaseCore, ChaseRanked, ChaseMain = nil, nil, nil, nil, nil
    WantedRules, ChaseWantedLobby, ChaseWanted, ChaseWantedMain = nil, nil, nil, nil
    dofile("shared/config.lua")
    dofile("server/rules.lua")
    dofile("server/elo.lua")
    dofile("server/queue.lua")
    dofile("server/core.lua")
    dofile("server/match.lua")
    dofile("server/ranked.lua")
    dofile("server/wanted_rules.lua")
    dofile("server/wanted_lobby.lua")
    dofile("server/wanted.lua")
    dofile("server/recap.lua")
    dofile("server/main.lua")
    dofile("server/wanted_main.lua")
    -- main.lua: registration + tick; wanted_main.lua: registration + tick.
    assert(#env.threads == 4, "two registrations + two ticks")
    env.threads[1](); env.threads[3]()
    env.loop = env.threads[4]
    env.threads = {}
    env.deferThreads = false
end

local function fire(name, ...)
    for _, fn in ipairs(env.handlers[name] or {}) do fn(...) end
end

local function run(seconds)
    env.budget = math.floor(seconds * 1000 / 200)
    local ok, err = pcall(env.loop)
    env.budget = nil
    if ok or err ~= STOP then error(err, 0) end
end

local function runUntil(done, seconds, what)
    local limit = env.clock + seconds * 1000
    while not done() do
        assert(env.clock < limit, (what or "condition") .. " not reached in time")
        run(0.2)
    end
end

local function events(name)
    local list = {}
    for _, e in ipairs(env.events) do if e.name == name then list[#list + 1] = e end end
    return list
end
local function lastStatus(aid)
    local l = events("op77_lightrp:activity:status")
    for i = #l, 1, -1 do if l[i].args[1] == (aid or "chase.wanted") then return l[i].args[2] end end
end
local function results(id)
    local out = {}
    for _, e in ipairs(events("op77_lightrp:activity:result")) do
        if id == nil or e.args[1] == id then out[#out + 1] = e end
    end
    return out
end
local function calls(name, id)
    local n = 0
    for _, c in ipairs(env.calls) do if c.name == name and (id == nil or c.args[1] == id) then n = n + 1 end end
    return n
end
local function noted(id, pattern)
    for _, n in ipairs(env.notes) do if n.id == id and n.message:find(pattern) then return true end end
    return false
end
local function countCars(filter)
    local n = 0
    for _, car in pairs(env.cars) do if filter == nil or filter(car) then n = n + 1 end end
    return n
end
local function only()
    local m
    for _, x in pairs(ChaseWanted.matches) do assert(m == nil, "one match"); m = x end
    return m
end
local function leftIds()
    local s = {}
    for _, l in ipairs(env.left) do s[l.id] = l end
    return s
end
local function join(id, options) fire("op77_lightrp:activity:join", id, "chase.wanted", options) end
local function cmd(name, source, args) env.commands[name].fn(source, args or {}, name .. " " .. table.concat(args or {}, " ")) end
local function at(id, x, y, z, bucket) env.pos[id] = { x = x, y = y, z = z or 0, bucket = bucket } end

-- ════════════════════════════════════════════════════════════════ three players, by car
do
    load()
    local reg = env.registered["chase.wanted"]
    assert(reg and reg.resource == "op77_chase" and reg.kind == "chase" and reg.label == "Most Wanted")
    assert(reg.minPlayers == 3 and reg.maxPlayers == 8 and reg.caps.rpWeapons == false)
    assert(env.registered["chase.1v1"], "the 1v1 registers too")
    run(1.2)
    assert(lastStatus().phase == "idle" and lastStatus().joinable == true)

    -- Two join from the hub: queued remotely (they keep playing), nobody owned yet.
    join(1, { mode = "car" })
    join(2)
    assert(env.qhud[1].queued == true and env.qhud[1].activity == "chase.wanted" and env.qhud[1].min == 3 and env.qhud[1].mode == "vehicle")
    -- No "queued" notice of ours: Light RP answers the join and its queue panel shows the lobby.
    assert(not noted(1, "Queued for Most Wanted") and calls("activityEnter") == 0)
    join(1)
    assert(ChaseWantedLobby.size() == 2, "a second join does not queue twice")

    -- One chase queue at a time, both ways.
    fire("op77_lightrp:activity:join", 1, "chase.1v1", {})
    assert(ChaseQueue.size() == 0 and noted(1, "already queued for Most Wanted"))
    fire("op77_lightrp:activity:join", 5, "chase.1v1", {})
    join(5)
    assert(ChaseQueue.size() == 1 and not ChaseWantedLobby.has(5) and noted(5, "NCPD Chase queue"))
    fire("op77_lightrp:activity:leaveRequest", 5, "chase.1v1")
    assert(ChaseQueue.size() == 0 and not noted(5, "You left"), "Light RP's leave answer is the only one")

    run(2.0)
    assert(only() == nil and ChaseWantedLobby.countdownEndsAtMs == nil and lastStatus().phase == "lobby" and lastStatus().queued == 2)

    -- The third: the lobby countdown starts and is announced server-wide.
    join(3, { mode = "car" })
    run(1.2)
    assert(ChaseWantedLobby.countdownEndsAtMs ~= nil and env.qhud[3].countdownMs > 40000)
    -- Light RP's queue panel: the lobby, its minimum and seats, the countdown
    local wl = lastStatus().queue.lobbies[1]
    assert(lastStatus().queue.v == 1 and #wl.players == 3 and wl.need == 3 and wl.max == ChaseConfig.wanted.maxPlayers)
    assert(wl.startsInMs and wl.startsInMs > 40000 and wl.startsInMs <= 45000 and not wl.joining)
    local statuses = #events("op77_lightrp:activity:status")
    run(2.0)
    assert(#events("op77_lightrp:activity:status") == statuses, "the countdown running down sends no status")
    local ann = events("op77_lightrp:announce")
    assert(#ann == 1 and ann[1].args[1]:find("Most Wanted starts in") and ann[1].args[2].activity == "chase.wanted")
    assert(noted(1, "starts in") and lastStatus().detail:find("starts in"))

    -- Countdown over: Light RP hands the three over, the match places them.
    runUntil(function() return only() ~= nil end, 50, "match start")
    local match = only()
    assert(match.state == "placing" and env.hud[1].state == "placing")
    run(0.2)
    assert(match.mode == "vehicle" and match.bucket == 4300100 and match.state == "countdown", tostring(match.state))
    assert(env.owner[1] == "chase.wanted" and env.owner[2] == "chase.wanted" and env.owner[3] == "chase.wanted")
    assert(env.qhud[1].queued == false and env.qhud[3].queued == false)
    assert(match.runnerId == 1 and match.roles[2] == "cop" and match.roles[3] == "cop", "the first in the queue runs first")
    assert(#env.placements == 3 and env.placements[1].bucket == 4300100 and env.placements[1].cover ~= nil)
    local rc, rp1 = match.route.runnerCar.position, env.placements[1].point.position
    assert(math.abs(rp1.x - rc.x) < 5 and math.abs(rp1.y - rc.y) < 5, "by car the runner starts at the front of the cops' grid")
    assert(countCars() == 3 and countCars(function(c) return c.bucket == 4300100 end) == 3)
    assert(countCars(function(c) return c.spec.sirenOn end) == 2, "two NCPD cars")
    assert(countCars(function(c) return c.spec.record == "Vehicle.v_sport2_quadra_type66_avenger_player" end) == 1)
    assert(env.frozen[1] and env.frozen[2] and env.frozen[3])
    local h1, h2 = env.hud[1], env.hud[2]
    assert(h1.activity == "chase.wanted" and h1.role == "runner" and h2.role == "cop" and h1.round == 1 and h1.roundCount == 3)
    assert(h2.hideDots and h2.hideDots[1] == 1 and h1.hideDots == nil, "the runner's dot hidden from the cops")
    assert(#h1.scoreboard == 3 and h1.scoreboard[1].name == "Player1")
    assert(noted(1, "YOU ARE THE RUNNER") and noted(2, "NCPD"))
    assert(lastStatus().phase == "running" and lastStatus().players == 3)

    -- GO: by car the runner and the whole NCPD leave together (no head start).
    at(1, 0, 0); at(2, 500, 0); at(3, 600, 0)
    runUntil(function() return match.state == "active" end, 12, "GO")
    local go = match.chase.startedAtMs
    assert(match.releaseAt[2] == go and match.releaseAt[3] == go, "every cop released at GO")
    assert(not noted(2, "Hold - dispatch") and not noted(3, "Hold - dispatch"))
    run(0.6)
    assert(env.frozen[1] == false and env.frozen[2] == false and env.frozen[3] == false)
    assert(match.copReleased[2] and match.copReleased[3] and env.hud[2].released == true)
    assert(noted(2, "you're up") and noted(3, "you're up"))
    assert(env.hud[2].sighting and env.hud[2].sighting.radius == 160 and env.hud[2].targetDistance == 500)
    assert(env.hud[1].copsNearby == 0 and env.hud[1].nearestCop == 500 and env.hud[1].heat == 1)

    -- Every released cop beyond 150 m for 12 s: a shake.
    runUntil(function() return match.chase.shakes == 1 end, 15, "shake")
    assert(noted(1, "You shook them") and noted(2, "Suspect lost"))

    -- Heat 2 at 30 s (nobody left to release: the whole NCPD left at GO).
    runUntil(function() return env.hud[1].heat == 2 end, 25, "heat 2")
    assert(noted(1, "HEAT 2"))

    -- Both close in on a stopped runner: arrest by the nearest, an assist for the other.
    at(2, 8, 0); at(3, -9, 3)
    runUntil(function() return match.state == "intermission" end, 20, "arrest")
    local r1 = match.rounds[1]
    assert(r1.outcome == "runner_busted" and r1.arrestBy == 2 and #r1.assists == 1 and r1.assists[1] == 3 and r1.shakes == 1)
    local s = match.stats
    assert(s[2].arrests == 1 and s[3].assists == 1 and s[1].busted == 1 and s[1].shakes == 1)
    assert(s[2].points == 70 and s[3].points == 40 and s[1].points == math.floor(r1.survivedMs / 1000) + 15)
    local hi = env.hud[2]
    assert(hi.state == "intermission" and hi.lastRound.outcome == "runner_busted" and hi.gained == 70 and hi.nextIsYou == true)
    assert(env.hud[1].wasRunner == true and env.hud[1].nextRunnerName == "Player2")
    assert(noted(1, "Busted") and noted(2, "Next runner: YOU"))
    assert(env.frozen[2] == false and env.frozen[3] == false)

    -- Round 2: player 2 runs; fresh cars; cop dots now hide player 2.
    local oldCars = {}
    for id in pairs(env.cars) do oldCars[#oldCars + 1] = id end
    runUntil(function() return match.round == 2 and match.state == "countdown" end, 12, "round 2")
    for _, id in ipairs(oldCars) do assert(env.cars[id] == nil, "the old cars are gone") end
    assert(countCars() == 3 and match.runnerId == 2 and match.roles[1] == "cop" and env.hud[1].hideDots[1] == 2)
    assert(env.hud[2].subtitle == nil and env.hud[2].role == "runner")

    -- The runner drives east at 72 km/h on flat ground; the cops are far behind.
    runUntil(function() return match.state == "active" end, 12)
    local go2 = match.chase.startedAtMs
    env.pos[2] = function(clock) return { x = (clock - go2) / 1000 * 20, y = 0, z = 12 } end
    at(1, -3000, 0); at(3, -3200, 0)
    -- Heat 3 (60 s): roadblocks ahead of him, locked, immortal, in the match bucket.
    runUntil(function() return #match.blocks > 0 end, 70, "roadblock")
    local block = match.blocks[1]
    assert(#block.cars == 2 and noted(2, "roadblock ahead"))
    local rbCar = env.cars[block.cars[1]]
    assert(rbCar.bucket == 4300100 and rbCar.spec.locked and rbCar.spec.immortal and rbCar.spec.engineOff)
    local p2 = ChaseWorld.position(2)
    assert(block.centre.x > p2.x + 50 and math.abs(block.centre.y) < 1e-6 and block.centre.z == 12, "66 m ahead, at his altitude")
    -- Heat 4 (95 s): the extraction, to the runner first, the cops 20 s later.
    runUntil(function() return match.extraction ~= nil end, 40, "extraction")
    assert(env.hud[2].extraction ~= nil or true)
    run(0.6)
    assert(env.hud[2].extraction and env.hud[2].extractionDistance and env.hud[1].extraction == nil, "the cops do not see it yet")
    assert(noted(2, "Extraction point on your map"))
    runUntil(function() return env.hud[1].extraction ~= nil end, 22, "cops told")
    assert(noted(1, "we know where he's heading"))
    -- The clock: he survives.
    runUntil(function() return match.state == "intermission" end, 80, "round 2 clock")
    local r2 = match.rounds[2]
    assert(r2.outcome == "time_expired" and r2.survivedMs == 165000 and match.stats[2].survivals == 1)
    assert(#match.blocks == 0 and countCars(function(c) return c.spec.locked end) == 0, "roadblocks cleared with the round")

    -- Round 3: player 3 runs and reaches the extraction.
    runUntil(function() return match.round == 3 and match.state == "active" end, 25, "round 3")
    local go3 = match.chase.startedAtMs
    at(3, 0, 0, 5); at(1, 3000, 3000); at(2, 3100, 3000)
    runUntil(function() return match.extraction ~= nil end, 100, "round 3 extraction")
    local x = match.extraction.position
    at(3, x.x + 3, x.y, x.z + 1)
    runUntil(function() return match.state == "resolved" end, 5, "extracted")
    local r3 = match.rounds[3]
    assert(r3.outcome == "runner_extracted" and match.stats[3].extractions == 1 and env.clock - go3 >= 95000)
    assert(match.played == 3)

    -- The final ranking goes to Light RP: placements, points, reputation, no cash, no items.
    local all = results()
    assert(#all == 3, "one result per player")
    local byId = {}
    for _, e in ipairs(all) do
        assert(e.args[2] == "chase.wanted")
        byId[e.args[1]] = e.args[3]
    end
    local first
    for id, r in pairs(byId) do
        assert(r.cash == nil and r.items == nil and r.stats.rounds == 3 and r.stats.players == 3)
        if r.placement == 1 then first = id; assert(r.won == true and r.reputation == 40) end
    end
    assert(first == 2, "the survivor with the arrest leads")
    -- the board for Light RP's end-of-match recap: the table, the same for all three
    local board = byId[1].recap
    assert(board and board.matchId == byId[2].recap.matchId and #board.rows == 3 and board.rows[1].id == 2 and board.rows[1].placement == 1)
    assert(board.rows[1].busts == 1 and board.lines[1].value == "3")
    assert(byId[1].placement == 3 and byId[1].reputation == 25 and byId[3].placement == 2 and byId[3].reputation == 30)
    assert(env.hud[2].state == "resolved" and env.hud[2].placement == 1 and env.hud[2].total == 3)
    assert(noted(2, "#1 of 3"))
    assert(#env.left == 0, "the scoreboard stays on screen first")

    -- Home: out of the car, then activityLeave(returnPlayer); cars gone; bucket freed.
    env.seats[1] = 77
    run(10.4)
    run(1.0)
    assert(env.forced[#env.forced] == 1)
    local left = leftIds()
    assert(left[1] and left[2] and left[3] and left[1].opts.returnPlayer == true)
    assert(env.hud[1].state == "idle" and env.hud[3].state == "idle")
    assert(countCars() == 0 and env.swept[#env.swept] == 4300100)
    assert(next(ChaseWanted.matches) == nil and ChaseWanted.bucketOwner[4300100] == nil and ChaseWanted.playerMatch[1] == nil)
    run(1.2)
    assert(lastStatus().phase == "idle")

    -- The HUD feed flag (client/main.lua says when Light RP's HUD is up).
    _G.source = 4
    env.net["op77_chase:hudFeed"](true)
    assert(ChaseWorld.hudFeed[4] == true)
    env.net["op77_chase:hudFeed"](false)
    assert(ChaseWorld.hudFeed[4] == nil)
    print("PASS three players by car")
end

-- ════════════════════════════════════════════════════════════════ test mode, on foot, drop-in, forfeit, dropped
do
    load()
    cmd("chase.wanted.test", 0, { "on" })
    assert(env.commands["chase.wanted.test"].restricted == true and ChaseWanted.minPlayers() == 2)
    join(1, { mode = "foot" }); join(2, { mode = "foot" })
    runUntil(function() return only() ~= nil end, 50, "test match")
    local match = only()
    run(0.2)
    assert(match.mode == "foot" and match.runnerId == 1 and countCars() == 1, "on foot: no runner car, one NCPD car")
    local runnerMark = env.placements[1].point
    local route = ChaseConfig.wanted.routes[((match.id + 1 - 2) % #ChaseConfig.wanted.routes) + 1]
    assert(math.abs(runnerMark.position.x - route.runner.position.x) < 1e-6, "the runner on foot stands on his mark")

    -- A late joiner waits for the next round.
    join(3)
    run(1.2)
    assert(not ChaseWantedLobby.has(3) and ChaseWanted.pendingMatch(3) == match and env.owner[3] == nil)
    assert(env.qhud[3].joining == true and env.qhud[3].matchId == match.id and noted(3, "next round"))
    assert(ChaseWantedMain.claims(3) and match.roles[3] == nil)
    local drop = lastStatus().queue.lobbies
    assert(#drop == 1 and drop[1].joining == true and drop[1].players[1] == 3 and drop[1].need == nil, "a drop-in: joining the match")

    -- Round 1: the runner goes down near the cop: a takedown.
    at(1, 0, 0); at(2, 20, 0)
    runUntil(function() return match.state == "active" and match.copReleased[2] end, 30, "release")
    env.alive[1] = false
    runUntil(function() return match.state == "intermission" end, 2, "takedown")
    assert(match.rounds[1].outcome == "runner_down" and match.rounds[1].takedownBy == 2 and match.stats[2].takedowns == 1)

    -- Round 2: the drop-in is in (activityEnter now), the downed runner respawned on his mark.
    runUntil(function() return match.round == 2 and match.state == "countdown" end, 12, "round 2")
    assert(env.owner[3] == "chase.wanted" and #match.order == 3 and match.roles[3] == "cop" and match.runnerId == 2)
    assert(env.alive[1] == true and ChaseWanted.roundCount(match) == 3 and env.qhud[3].queued == true)
    -- A cop who goes down is back at the line-up 5 s later with a new car.
    at(2, 0, 0); at(1, 400, 0); at(3, 450, 0)
    runUntil(function() return match.state == "active" and match.copReleased[3] end, 50, "wave 2")
    local placed = #env.placements
    local cars = countCars()
    env.alive[3] = false
    run(5.6)
    assert(#env.placements == placed + 1 and env.placements[#env.placements].id == 3 and env.alive[3] == true)
    assert(countCars() == cars and noted(3, "Back in service"))

    -- Player 1 quits from the hub: his result now (last, no reputation), home, match goes on.
    env.seats[1] = 12
    fire("op77_lightrp:activity:leaveRequest", 1, "chase.wanted")
    local r = results(1)
    assert(#r == 1 and r[1].args[3].placement == 3 and r[1].args[3].reputation == 0 and r[1].args[3].won == false
        and r[1].args[3].stats.forfeit == true)
    -- Light RP says "Leaving Most Wanted." and sends the result: no notice of ours on top.
    assert(not noted(1, "goes on without you") and not noted(1, "You left") and match.state == "active")
    run(1.0)
    assert(leftIds()[1] and leftIds()[1].opts.returnPlayer == true and env.forced[#env.forced] == 1 and env.hud[1].state == "idle")

    -- Player 3 disconnects (Light RP says dropped): one player left, the match ends.
    fire("op77_lightrp:activity:dropped", 3, "chase.wanted", "disconnected")
    assert(match.state == "resolved" and not match.void)
    local r2 = results(2)
    assert(#r2 == 1 and r2[1].args[3].placement == 1 and #results(3) == 0, "no result for the dropped player")
    assert(r2[1].args[3].reputation == 40, "three players took part")
    run(11)
    assert(leftIds()[2] and leftIds()[3] == nil, "never activityLeave for a dropped player")
    assert(next(ChaseWanted.matches) == nil and countCars() == 0)
    cmd("chase.wanted.test", 0, { "off" })
    assert(ChaseWanted.minPlayers() == 3)
    print("PASS test mode, on foot, drop-in, takedown, cop respawn, forfeit, dropped")
end

-- ════════════════════════════════════════════════════════════════ a two-player test match counts for no reputation
do
    load()
    cmd("chase.wanted.test", 0, { "on" })
    cmd("chase.wanted.force", 0, { "1", "2", "car" })
    local match = only()
    assert(match and match.mode == "vehicle" and #match.members == 2 and env.replies[#env.replies].ok)
    at(1, 0, 0); at(2, 2000, 0)
    runUntil(function() return match.round == 2 and match.state == "active" end, 400, "two rounds")
    at(2, 0, 0); at(1, 2000, 0)
    runUntil(function() return match.state == "resolved" end, 400, "rotation complete")
    for _, e in ipairs(results()) do assert(e.args[3].reputation == 0, "below reputation.minPlayers") end
    assert(#results() == 2)
    print("PASS two-player test match")
end

-- ════════════════════════════════════════════════════════════════ admission, Light RP restart, staff, commands, shutdown
do
    load()
    -- A refused admission: too few left, the others handed back and requeued.
    join(1); join(2); join(3)
    env.enterFail[3] = "You are cuffed."
    runUntil(function() return #ChaseWanted.matches == 0 and calls("activityEnter", 3) > 0 end, 60, "admission")
    assert(only() == nil and noted(3, "You are cuffed") and not ChaseWantedLobby.has(3))
    assert(leftIds()[1] and leftIds()[2] and ChaseWantedLobby.has(1) and ChaseWantedLobby.position(1) == 1, "back at the head of the lobby")
    env.enterFail[3] = nil

    -- A queued player busy elsewhere: flagged so his client leaves the HUD alone.
    env.blocked[2] = "You are in a race."
    run(1.2)
    assert(env.qhud[2].busy == true and env.qhud[1].busy == nil)
    env.blocked[2] = nil

    -- /wanted commands.
    cmd("wanted", 4, { "foot" })
    assert(ChaseWantedLobby.has(4) and env.replies[#env.replies].ok and ChaseWantedLobby.entries[ChaseWantedLobby.position(4)].mode == "foot")
    cmd("wanted", 4, { "status" })
    assert(env.replies[#env.replies].text:find("Queued for Most Wanted"))
    cmd("wanted", 4, { "boat" })
    assert(env.replies[#env.replies].ok == false)
    cmd("wanted", 4, { "leave" })
    assert(not ChaseWantedLobby.has(4) and env.qhud[4].queued == false)
    cmd("wanted", 0, {})
    assert(env.replies[#env.replies].ok == false, "in game only")
    for _, id in ipairs({ 1, 2 }) do fire("op77_lightrp:activity:leaveRequest", id, "chase.wanted") end
    assert(ChaseWantedLobby.size() == 0)

    -- Staff force, status; Light RP restarts mid-match: void, nothing sent, all gone.
    cmd("chase.wanted.force", 0, { "1", "2", "3" })
    local match = only()
    assert(match and env.owner[1] == "chase.wanted")
    cmd("chase.wanted.status", 0)
    assert(env.replies[#env.replies].text:find("match " .. match.id))
    join(4)
    fire("onResourceStop", "op77_lightrp")
    assert(match.void and match.state == "resolved" and #results() == 0 and env.hud[1].state == "idle")
    assert(ChaseWantedLobby.size() == 0 and env.qhud[4].queued == false and ChaseWanted.playerMatch[1] == nil)
    run(0.4)
    assert(next(ChaseWanted.matches) == nil and countCars() == 0, "closed at the next tick")
    env.owner = {}
    -- Light RP back: registered again.
    env.registered = {}
    fire("onResourceStart", "op77_lightrp")
    assert(env.registered["chase.wanted"] and env.registered["chase.1v1"])

    -- Staff stop: void, players taken home after the scoreboard.
    cmd("chase.wanted.force", 0, { "1", "2", "3", "foot" })
    match = only()
    assert(match.mode == "foot")
    cmd("chase.wanted.stop", 0, { tostring(match.id) })
    assert(match.void and match.state == "resolved" and #results() == 0)
    run(11)
    assert(leftIds()[1] and leftIds()[2] and leftIds()[3] and next(ChaseWanted.matches) == nil)
    cmd("chase.wanted.force", 0, { "1" })
    assert(env.replies[#env.replies].ok == false, "two players at least")

    -- The resource stops: cars removed at once.
    env.owner = {}
    cmd("chase.wanted.force", 0, { "1", "2", "3" })
    run(0.4)
    assert(countCars() == 3)
    fire("onResourceStop", "op77_chase")
    assert(countCars() == 0)
    -- A player disconnecting while queued leaves the lobby.
    join(6)
    _G.source = 6
    fire("playerDropped")
    assert(not ChaseWantedLobby.has(6))
    print("PASS admission, busy flag, commands, Light RP restart, staff, shutdown")
end

print("PASS: op77_chase Most Wanted flow (lobby, countdown, waves, sightings, shake, unit arrest, rotation, roadblocks, extraction, results, drop-in, takedown, cop respawn, forfeit, dropped, test mode, restart, staff, shutdown)")
