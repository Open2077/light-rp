-- op77_chase Most Wanted rules and lobby (pure): heat, waves, the unit arrest (several
-- cops cuff faster, assists), takedown credit, clock and overtime, extraction, shakes,
-- blackouts, dispatch fuzz, extraction draw, roadblock spot, points, standings; the
-- lobby's countdown, full start, mode vote, readiness, drop-ins, requeue and expiry.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test wanted_rules_test.lua
dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/wanted_rules.lua")
dofile("server/wanted_lobby.lua")
local R, L = WantedRules, ChaseWantedLobby

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function P(x, y, z) return { x = x, y = y or 0, z = z or 0 } end

-- Step every tickMs from `from` to `to`; fn(now) -> sample. Returns outcome, time, all events.
local function run(round, t, from, to, fn)
    local now, all = from, {}
    while now <= to do
        local outcome, events = R.step(round, t, now, fn(now))
        for _, e in ipairs(events or {}) do e.at = now; all[#all + 1] = e end
        if outcome then return outcome, now, all end
        now = now + t.tickMs
    end
    return nil, now, all
end

local function cops(list)
    local out = {}
    for id, spec in pairs(list) do
        out[id] = { pos = spec.pos, down = spec.down, released = spec.released ~= false }
    end
    return out
end

local function count(events, kind)
    local n = 0
    for _, e in ipairs(events) do if e.kind == kind then n = n + 1 end end
    return n
end

-- ── merged rules, heat, waves ──
do
    local t = R.rulesFor("vehicle")
    assert(t.mode == "vehicle" and t.bustDistance == 15.0 and t.headStartSeconds == 10 and t.durationSeconds == 165 and t.tickMs == 200)
    local f = R.rulesFor("foot")
    assert(f.mode == "foot" and f.bustDistance == 8.0 and f.headStartSeconds == 15 and #f.heat == 5)
    assert(R.rulesFor("nonsense").mode == "vehicle")
    assert(R.normalizeMode("CAR") == "vehicle" and R.normalizeMode("on_foot") == "foot" and R.normalizeMode("boat") == nil and R.normalizeMode(nil) == nil)

    local heat = t.heat
    assert(R.heatAt(heat, 0) == 1 and R.heatAt(heat, 29999) == 1 and R.heatAt(heat, 30000) == 2 and R.heatAt(heat, 999999) == 5)
    assert(near(R.heatProgress(heat, 15000), 0.5) and R.heatProgress(heat, 200000) == 1.0)

    local plan = R.wavePlan({ 11, 12, 13, 14 }, heat, 10000)
    assert(plan[11] == 10000 and plan[12] == 10000 and plan[13] == 30000 and plan[14] == 30000, "half after the head start, the rest at heat 2")
    plan = R.wavePlan({ 11 }, heat, 10000)
    assert(plan[11] == 10000, "a lone cop goes with the first wave")
    plan = R.wavePlan({ 1, 2, 3, 4, 5, 6, 7 }, heat, 15000)
    local first, second = 0, 0
    for _, at in pairs(plan) do if at == 15000 then first = first + 1 elseif at == 30000 then second = second + 1 end end
    assert(first == 4 and second == 3, "7 cops: 4 then 3")
    plan = R.wavePlan({ 1, 2 }, { { atSeconds = 0 } }, 5000)
    assert(plan[1] == 5000 and plan[2] == 5000, "no release share: everyone after the head start")
    print("PASS heat and waves")
end

-- ── the unit arrest ──
do
    local t = R.rulesFor("vehicle")
    -- A stopped runner at the origin; `n` stopped cops 10 m away; the meter's fill time.
    local function bustTime(n)
        local round = R.newRound(t, 0)
        local list = {}
        for i = 1, n do
            local a = (i - 1) * 0.5
            list[10 + i] = { pos = P(10 * math.cos(a), 10 * math.sin(a)) }
        end
        local outcome, at = run(round, t, 0, 30000, function() return { runnerPos = P(0, 0), cops = cops(list) } end)
        return outcome, at, round
    end
    local o1, t1 = bustTime(1)
    local o2, t2 = bustTime(2)
    local o3, t3 = bustTime(3)
    assert(o1 and o1.outcome == "runner_busted" and o1.winner == "cops" and o1.arrestBy == 11 and #o1.assists == 0)
    assert(t1 > 4000 and t1 < 5500, "one cop at 10 m: about 4.5 s (+ the speed window)")
    assert(t2 < t1 and t3 < t2, "more cops closing = faster cuffs")
    assert(o3.arrestBy == 11 and #o3.assists == 2 and o3.assists[1] == 12 and o3.assists[2] == 13, "the others assist")
    local _, t7 = bustTime(7)
    local _, t5 = bustTime(5)
    assert(t7 == t5, "the unit factor is capped (maxCopFactor)")

    -- A held cop (not released) never arrests; the runner survives the clock.
    local round = R.newRound(t, 0, { durationSeconds = 5 })
    local outcome = run(round, t, 0, 10000, function()
        return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(5, 0), released = false } }) }
    end)
    assert(outcome.outcome == "time_expired" and outcome.winner == "runner")
    assert(round.bustMeter == 0 and round.copsNearby == 0)

    -- A moving runner is not pinned: no arrest even with a cop on him.
    round = R.newRound(t, 0, { durationSeconds = 6 })
    outcome = run(round, t, 0, 10000, function(now)
        local x = now / 1000 * 15 -- 54 km/h
        return { runnerPos = P(x, 0), cops = cops({ [11] = { pos = P(x + 8, 0) } }) }
    end)
    assert(outcome.outcome == "time_expired" and round.bustContact == true and round.bustClosing == false, "in contact, not closing")

    -- Overtime: an arrest closing at the buzzer plays out.
    round = R.newRound(t, 0, { durationSeconds = 2 })
    local events
    outcome, _, events = run(round, t, 0, 20000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(10, 0) } }) } end)
    assert(outcome.outcome == "runner_busted" and count(events, "overtime") == 1 and round.overtime == true)

    -- The assist window: a cop who was closing a moment ago still assists...
    local function assistRun(windowSeconds)
        local tw = {}
        for k, v in pairs(t) do tw[k] = v end
        tw.assistWindowSeconds = windowSeconds
        local r = R.newRound(tw, 0)
        return run(r, tw, 0, 30000, function(now)
            local second = now < 1000 and P(-10, 0) or P(-80, 0)
            return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(5, 0) }, [12] = { pos = second } }) }
        end)
    end
    outcome = assistRun(6)
    assert(outcome.outcome == "runner_busted" and outcome.arrestBy == 11 and #outcome.assists == 1 and outcome.assists[1] == 12,
        "closing 2-3 s before the cuffs: an assist")
    -- ...not one who left longer ago than the window (and is beyond assistMetres).
    outcome = assistRun(1)
    assert(outcome.outcome == "runner_busted" and #outcome.assists == 0, "outside the window: no assist")
    print("PASS unit arrest")
end

-- ── takedown, extraction, shakes, blackouts, heat events ──
do
    local t = R.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    local outcome = R.step(round, t, 0, { runnerPos = P(0, 0), runnerDown = true, cops = cops({ [11] = { pos = P(20, 0) }, [12] = { pos = P(300, 0) } }) })
    assert(outcome.outcome == "runner_down" and outcome.takedownBy == 11)
    round = R.newRound(t, 0)
    outcome = R.step(round, t, 0, { runnerPos = P(0, 0), runnerDown = true, cops = cops({ [11] = { pos = P(100, 0) } }) })
    assert(outcome.outcome == "runner_down" and outcome.takedownBy == nil, "nobody close: no credit")

    round = R.newRound(t, 0)
    round.extraction = { position = P(100, 0, 0), radius = 15, zTolerance = 8 }
    assert(R.step(round, t, 0, { runnerPos = P(90, 0, 20), cops = {} }) == nil, "above it (20 m): not there")
    outcome = R.step(round, t, 200, { runnerPos = P(90, 0, 3), cops = {} })
    assert(outcome.outcome == "runner_extracted" and outcome.winner == "runner")

    -- Shake: every released cop beyond 150 m for 12 s; then re-armed only by a cop closing in.
    round = R.newRound(t, 0)
    local copX = 200
    local _, _, events = run(round, t, 0, 30000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(copX, 0) } }) } end)
    assert(count(events, "shake") == 1 and count(events, "shake_started") == 1 and round.shakes == 1 and round.shakeArmed == false,
        "one shake, not one every 12 s")
    copX = 100
    R.step(round, t, 30200, { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(copX, 0) } }) })
    assert(round.shakeArmed == true, "a cop back within 150 m re-arms it")
    copX = 200
    _, _, events = run(round, t, 30400, 50000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(copX, 0) } }) } end)
    assert(round.shakes == 2)
    -- An unreadable released cop is not a far cop.
    round = R.newRound(t, 0)
    _, _, events = run(round, t, 0, 20000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(400, 0) }, [12] = {} }) } end)
    assert(count(events, "shake_started") == 0 and round.shakes == 0)
    -- A downed cop counts for nothing (neither near nor unknown).
    round = R.newRound(t, 0)
    _, _, events = run(round, t, 0, 13000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(400, 0) }, [12] = { down = true } }) } end)
    assert(round.shakes == 1)

    -- The runner unreadable: nothing decided, meters frozen, drained after the stale delay.
    round = R.newRound(t, 0)
    run(round, t, 0, 3000, function() return { runnerPos = P(0, 0), cops = cops({ [11] = { pos = P(10, 0) } }) } end)
    local meter = round.bustMeter
    assert(meter > 0.3)
    assert(R.step(round, t, 3200, { cops = cops({ [11] = { pos = P(10, 0) } }) }) == nil)
    assert(round.bustMeter == meter, "frozen at first")
    run(round, t, 3400, 9000, function() return { cops = cops({ [11] = { pos = P(10, 0) } }) } end)
    assert(round.bustMeter < meter and round.bustClosing == false, "drained after positionStaleResetMs")

    -- Heat levels fire once each, with their line.
    round = R.newRound(t, 0)
    _, _, events = run(round, t, 0, 130000, function() return { runnerPos = P(0, 0), cops = {} } end)
    assert(count(events, "heat") == 4 and events[1].level == 2 and events[1].text == "Backup is rolling out." and round.heat == 5)
    print("PASS takedown, extraction, shakes, blackouts, heat")
end

-- ── dispatch fuzz, extraction draw, roadblocks ──
do
    local seq, i = { 0.25, 0.9, 0.5, 0.1, 0.99, 0.0 }, 0
    local function rand() i = i % #seq + 1; return seq[i] end
    for _ = 1, 20 do
        local p = R.fuzz(P(100, 100, 7), 120, rand)
        assert(R.planar(p, P(100, 100)) <= 120 * 0.6 + 1e-9 and p.z == 7, "the runner is always inside the circle")
    end
    local pts = { { position = P(100, 0) }, { position = P(500, 0) }, { position = P(900, 0) }, { position = P(2000, 0) } }
    assert(R.pickExtraction(pts, P(0, 0), { 450, 1300 }, function() return 0 end).position.x == 500)
    assert(R.pickExtraction(pts, P(0, 0), { 450, 1300 }, function() return 0.99 end).position.x == 900)
    local far = R.pickExtraction({ { position = P(100, 0) }, { position = P(2000, 0) } }, P(0, 0), { 450, 1300 }, function() return 0 end)
    assert(far.position.x == 2000, "too close is worse than too far")
    assert(R.pickExtraction({}, P(0, 0), { 1, 2 }, rand) == nil and R.pickExtraction(pts, nil, { 1, 2 }, rand) == nil)
    assert(#ChaseConfig.wanted.extractionPoints >= 40, "the race checkpoints of both car courses")

    local rb = ChaseConfig.wanted.roadblock
    local east = { { x = 0, y = 0, z = 10 }, { x = 20, y = 0, z = 10.5 } }
    local centre, heading = R.roadblockSpot(east, rb)
    assert(near(centre.x, 86) and near(centre.y, 0) and centre.z == 10.5 and near(heading, -90))
    local fwd = R.forward(heading)
    assert(near(fwd.x, 1) and near(fwd.y, 0, 1e-9), "heading in the forward() convention")
    local marks = R.roadblockMarks(centre, heading, rb)
    assert(#marks == 2 and near(marks[1].position.x, 86) and near(math.abs(marks[1].position.y), 1.8) and near(marks[1].position.y, -marks[2].position.y))
    assert(near(marks[1].yaw, 0), "across the road")
    local c2, why = R.roadblockSpot({ { x = 0, y = 0, z = 0 }, { x = 20, y = 0, z = 2 } }, rb)
    assert(c2 == nil and why:find("grade"), "10 % grade: no guess at the altitude")
    assert(R.roadblockSpot({ { x = 0, y = 0, z = 0 }, { x = 5, y = 0, z = 0 } }, rb) == nil, "too slow for a heading")
    assert(R.roadblockSpot({ { x = 0, y = 0, z = 0 } }, rb) == nil and R.roadblockSpot(nil, rb) == nil)
    print("PASS dispatch, extraction draw, roadblocks")
end

-- ── points and standings ──
do
    local match = { stats = {} }
    local g = R.score(match, { runnerId = 1, copIds = { 2, 3, 4 }, outcome = "runner_busted", survivedMs = 42500, shakes = 1,
        arrestBy = 2, assists = { 3 } })
    assert(g[1] == 42 + 15 and g[2] == 60 + 10 and g[3] == 30 + 10 and g[4] == 10)
    local s1 = match.stats[1]
    assert(s1.runnerRounds == 1 and s1.runnerMs == 42500 and s1.busted == 1 and s1.shakes == 1 and match.stats[2].arrests == 1
        and match.stats[3].assists == 1 and match.stats[4].copRounds == 1)
    g = R.score(match, { runnerId = 2, copIds = { 1, 3, 4 }, outcome = "time_expired", survivedMs = 165000, shakes = 0 })
    assert(g[2] == 165 + 40 and g[1] == nil and match.stats[2].survivals == 1)
    g = R.score(match, { runnerId = 3, copIds = { 1, 2, 4 }, outcome = "runner_extracted", survivedMs = 100000 })
    assert(g[3] == 100 + 80 and match.stats[3].extractions == 1)
    g = R.score(match, { runnerId = 4, copIds = { 1, 2, 3 }, outcome = "runner_down", survivedMs = 30000, takedownBy = 1 })
    assert(g[4] == 30 and g[1] == 40 + 10 and g[2] == 10 and match.stats[1].takedowns == 1)
    assert(next(R.score(match, { runnerId = 1, copIds = { 2 }, outcome = "runner_left", survivedMs = 9000 })) == nil, "a runner who left: nothing")
    local rows = R.standings(match, { 1, 2, 3, 4 })
    -- 1: 57 + 50 = 107; 2: 70 + 205 + 10 = 285; 3: 40 + 180 = 220; 4: 10 + 30 = 40
    assert(rows[1].id == 2 and rows[1].points == 285 and rows[2].id == 3 and rows[3].id == 1 and rows[4].id == 4)
    assert(rows[1].placement == 1 and rows[4].placement == 4)
    local tie = { stats = { [5] = { points = 10, runnerMs = 1000, arrests = 0 }, [6] = { points = 10, runnerMs = 1000, arrests = 2 },
        [7] = { points = 10, runnerMs = 900, arrests = 9 } } }
    rows = R.standings(tie, { 5, 6, 7 })
    assert(rows[1].id == 6 and rows[1].placement == 1 and rows[2].id == 5 and rows[2].placement == 1 and rows[3].id == 7 and rows[3].placement == 3,
        "same points and runner time share a place; arrests only order the rows")
    assert(R.coarseDistance(30) == 50 and R.coarseDistance(112) == 100 and R.coarseDistance(137) == 125 and R.coarseDistance(430) == 450
        and R.coarseDistance(1234) == 1200 and R.coarseDistance(5000) == 1500 and R.coarseDistance(nil) == nil)
    local line, title = R.line("runner_busted", "runner")
    assert(line == "You were cuffed." and title == "Busted" and R.line("time_expired", "cop") == "He outlasted the unit.")
    assert(select(2, R.line("weird", "cop")) == "Called off")
    print("PASS points and standings")
end

-- ── the lobby ──
do
    local ready = {}
    local function isReady(id) if ready[id] == false then return false, "busy" end return true end
    local opts = { min = 3, max = 5, countdownMs = 45000, dropAfterMs = 120000, defaultMode = "vehicle" }
    L.reset()
    assert(L.add(1, "foot", 0) == 1 and L.add(2, "car", 0) == 2 and select(2, L.add(1, nil, 0)) == "already_queued")
    assert(L.poll(1000, isReady, opts) == nil and L.countdownEndsAtMs == nil, "two players: no countdown")
    L.add(3, nil, 1000)
    assert(L.poll(2000, isReady, opts) == nil and L.countdownEndsAtMs == 47000 and L.countdownStarted == true, "the minimum starts the countdown")
    L.countdownStarted = nil
    assert(L.poll(46000, isReady, opts) == nil and not L.countdownStarted, "still counting, no second start")
    local start = L.poll(47000, isReady, opts)
    assert(start and #start.ids == 3 and start.ids[1] == 1 and start.mode == "vehicle" and start.modes[1] == "foot", "a tie: the default mode")
    assert(L.size() == 0 and L.countdownEndsAtMs == nil)

    -- Full: no countdown wait; the vote picks foot.
    for id = 11, 15 do L.add(id, id <= 13 and "foot" or "vehicle", 0) end
    start = L.poll(100, isReady, opts)
    assert(start and #start.ids == 5 and start.mode == "foot", "full lobby starts at once, majority foot")

    -- Back under the minimum: the countdown stops.
    L.reset()
    for id = 21, 23 do L.add(id, nil, 0) end
    L.poll(0, isReady, opts)
    assert(L.countdownEndsAtMs ~= nil)
    L.remove(22)
    L.poll(1000, isReady, opts)
    assert(L.countdownEndsAtMs == nil)

    -- Not ready (in another activity): not counted, told, then dropped.
    L.reset()
    for id = 31, 33 do L.add(id, nil, 0) end
    ready[32] = false
    local s, notReady, dropped = L.poll(0, isReady, opts)
    assert(s == nil and #notReady == 1 and notReady[1].id == 32 and notReady[1].reason == "busy" and L.countdownEndsAtMs == nil)
    s, notReady, dropped = L.poll(120000, isReady, opts)
    assert(#dropped == 1 and dropped[1].id == 32 and not L.has(32) and L.size() == 2)
    ready[32] = nil

    -- Drop-ins take the head of the queue; requeueFront puts players back first.
    local ids = L.take(0, isReady, 1, 120000)
    assert(#ids == 1 and ids[1] == 31 and L.size() == 1 and L.position(33) == 1)
    L.requeueFront({ 41, 42 }, { [41] = "foot" }, 5)
    assert(L.position(41) == 1 and L.position(42) == 2 and L.position(33) == 3 and L.entries[1].mode == "foot")
    assert(#L.take(0, isReady, 0) == 0)
    -- Expiry.
    local gone = L.expire(900000, 900000)
    assert(#gone == 1 and gone[1] == 33 and L.size() == 2, "only the oldest entry has waited 15 minutes")
    assert(L.mode({ { mode = "foot" }, { mode = "foot" }, { mode = "vehicle" } }) == "foot" and L.mode({}, "foot") == "foot")
    print("PASS lobby")
end

print("PASS: op77_chase Most Wanted rules (heat, waves, unit arrest, assists, takedown, overtime, extraction, shakes, blackouts, dispatch, roadblocks, points, standings) and lobby (countdown, full start, vote, readiness, drop-ins, requeue, expiry)")
