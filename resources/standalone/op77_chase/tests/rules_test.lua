-- op77_chase rules: the arrest and escape gauges, the clock, overtime, blackouts, crashes.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test rules_test.lua
dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/match.lua") -- only for Chase.rulesFor (the merged rules column)
local R = ChaseRules

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- A runner standing at x, a cop at x + gap, both on the y = 0 line.
local function sample(gap, copX, runnerX)
    runnerX = runnerX or 0.0
    copX = copX or (runnerX + gap)
    return { sep = math.abs(copX - runnerX), copPos = { x = copX, y = 0, z = 0 }, runnerPos = { x = runnerX, y = 0, z = 0 } }
end

-- Steps every tickMs with a sample function; returns the outcome (or nil) and the time.
local function run(round, t, from, to, fn)
    local now = from
    while now <= to do
        local outcome, events = R.step(round, t, now, fn(now))
        if outcome then return outcome, now, events end
        now = now + t.tickMs
    end
    return nil, now
end

-- ── merged rules ──
do
    local t = Chase.rulesFor("vehicle")
    assert(t.tickMs == 200 and t.timeoutWinner == "cop" and t.copDownEndsRound == true and t.bustDistance == 15.0)
    local f = Chase.rulesFor("foot")
    assert(f.bustDistance == 8.0 and f.headStartSeconds == 5.0)
    assert(Chase.rulesFor("nonsense").bustDistance == 15.0, "unknown mode falls back to vehicle")
    print("PASS merged rules")
end

-- ── head start: cop held, meters empty, then released with an event ──
do
    local t = Chase.rulesFor("foot")
    local round = R.newRound(t, 0)
    assert(round.copReleased == false and round.copReleaseAtMs == 5000)
    -- Contact during the head start never fills anything.
    local outcome = run(round, t, 0, 4800, function() return sample(1.0) end)
    assert(outcome == nil and round.bustMeter == 0.0 and round.escapeMeter == 0.0)
    local _, events = R.step(round, t, 5000, sample(50.0))
    assert(round.copReleased and #events == 1 and events[1].kind == "released")
    assert(round.escapeArmedAtMs == 5000 + 8000, "escape arms escapeArmSeconds after release")
    -- No head start (vehicle): released at once, armed from the start.
    local v = Chase.rulesFor("vehicle")
    local r2 = R.newRound(v, 1000)
    assert(r2.copReleased and r2.escapeArmedAtMs == 1000 + 15000 and r2.endsAtMs == 1000 + 180000)
    print("PASS head start")
end

-- ── bust: fills on a stopped runner within range, faster in the core ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    -- Both stopped, 10 m apart (outside the core, inside bustDistance 15): about 5 s * slower factor.
    local outcome, at = run(round, t, 0, 20000, function() return sample(10.0) end)
    assert(outcome and outcome.outcome == "runner_busted" and outcome.winner == "cop", "stopped runner in range is busted")
    -- The first sample has no pace baseline (span < 400 ms): filling starts once speeds are known.
    assert(at > 3000 and at < 6000, "busted in about bustFillSeconds, got " .. at)
    local core = R.newRound(t, 0)
    local _, atCore = run(core, t, 0, 20000, function() return sample(2.0) end)
    assert(atCore < at, "the core distance fills faster")
    print("PASS bust fill (" .. at .. " ms at 10 m, " .. atCore .. " ms at 2 m)")
end

-- ── bust: a moving runner is never cuffed; the meter drains slowly in contact ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    -- Fill for 2 s with both stopped.
    run(round, t, 0, 2000, function() return sample(10.0) end)
    local filled = round.bustMeter
    assert(filled > 0.1 and round.bustClosing and round.bustContact)
    -- Now the runner drives at 20 m/s (72 km/h), the cop follows 10 m behind. The windowed
    -- speed needs a moment to rise above the gate, so watch the peak, then the drain.
    local peak = filled
    local outcome = run(round, t, 2200, 10000, function(now)
        peak = math.max(peak, round.bustMeter)
        local x = (now - 2200) / 1000 * 20.0
        return sample(nil, x + 10.0, x)
    end)
    assert(outcome == nil, "a runner above bustRunnerMaxSpeedKph cannot be busted")
    assert(round.bustContact and not round.bustClosing)
    assert(round.bustMeter < peak - 0.1 and round.bustMeter > 0.0, "contact drains slowly (bustContactDrainSeconds)")
    -- Out of range it drains at the normal rate, to zero.
    run(round, t, 6200, 20000, function() return sample(40.0) end)
    assert(round.bustMeter == 0.0 and not round.bustContact)
    print("PASS bust drain")
end

-- ── bust: a cop flying past (above bustCopMaxSpeedKph) does not fill ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    local outcome = run(round, t, 0, 3000, function(now)
        local copX = -10.0 + (now / 1000) * 15.0 -- 54 km/h, passes the stopped runner
        return sample(nil, copX, 0.0)
    end)
    assert(outcome == nil and round.bustMeter == 0.0)
    print("PASS cop speed gate")
end

-- ── escape: not before it is armed, then a window that fills over the grace ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    -- Far away from the start: the escape is not armed for 15 s.
    local outcome = run(round, t, 0, 14800, function() return sample(150.0) end)
    assert(outcome == nil and round.escapeMeter == 0.0 and R.escapeProgress(round) == nil)
    local _, events = R.step(round, t, 15000, sample(150.0))
    assert(round.escapeFilling and #events == 1 and events[1].kind == "escape_started")
    local escaped, at = run(round, t, 15200, 40000, function() return sample(150.0) end)
    assert(escaped and escaped.outcome == "runner_escaped" and escaped.winner == "runner")
    assert(at >= 15000 + 18000 - 400 and at <= 15000 + 18000 + 400, "escape after escapeGraceSeconds, got " .. at)
    print("PASS escape window (" .. at .. " ms)")
end

-- ── escape: pulled back under the distance, the meter drains (faster than it filled) ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    round.escapeArmedAtMs = 0
    run(round, t, 0, 9000, function() return sample(120.0) end)
    local half = R.escapeProgress(round)
    assert(half and near(half, 0.5, 0.03), "half the window after 9 s, got " .. tostring(half))
    run(round, t, 9200, 11000, function() return sample(60.0) end)
    local after = R.escapeProgress(round)
    assert(after and near(after, half - 2 / 6, 0.03) and not round.escapeFilling, "drains at 1/6 per second")
    run(round, t, 11200, 13000, function() return sample(60.0) end)
    assert(R.escapeProgress(round) == nil, "empty meter leaves the screen")
    print("PASS escape drain")
end

-- ── the clock: timeout to the cop; an attempt at the buzzer plays out as overtime ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0, 10)
    local outcome = run(round, t, 0, 20000, function() return sample(50.0) end)
    assert(outcome and outcome.outcome == "runner_timed_out" and outcome.winner == "cop")

    local ot = R.newRound(t, 0, 10)
    ot.escapeArmedAtMs = 0
    -- Escape attempt starts at 5 s and is still running at 10 s: overtime, then escape.
    local o2, at, ev = run(ot, t, 0, 60000, function(now) return sample(now >= 5000 and 150.0 or 50.0) end)
    assert(ot.overtime == true, "overtime flagged")
    assert(o2 and o2.outcome == "runner_escaped" and at > 10000, "the attempt in play decides it")

    -- Overtime broken (cop closes back in): the round goes to the clock.
    local br = R.newRound(t, 0, 10)
    br.escapeArmedAtMs = 0
    local o3 = run(br, t, 0, 60000, function(now) return sample(now >= 5000 and now < 11000 and 150.0 or 50.0) end)
    assert(br.overtime and o3 and o3.outcome == "runner_timed_out" and o3.detail == "overtime attempt broken")

    -- timeoutWinner = runner turns the same clock into a runner win.
    local alt = {}
    for k, v in pairs(t) do alt[k] = v end
    alt.timeoutWinner = "runner"
    local r4 = R.newRound(alt, 0, 5)
    local o4 = run(r4, alt, 0, 20000, function() return sample(50.0) end)
    assert(o4 and o4.outcome == "time_expired" and o4.winner == "runner")
    print("PASS clock and overtime")
end

-- ── somebody down ──
do
    local t = Chase.rulesFor("foot")
    local round = R.newRound(t, 0)
    local o = R.step(round, t, 200, { runnerDown = true })
    assert(o.outcome == "runner_down" and o.winner == "cop")
    local o2 = R.step(R.newRound(t, 0), t, 200, { copDown = true })
    assert(o2.outcome == "cop_down" and o2.winner == "runner")
    local lenient = {}
    for k, v in pairs(t) do lenient[k] = v end
    lenient.copDownEndsRound = false
    assert(R.step(R.newRound(lenient, 0), lenient, 200, { copDown = true }) == nil)
    print("PASS down")
end

-- ── a blackout freezes the meters, a long one drains them ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    run(round, t, 0, 2400, function() return sample(10.0) end)
    local before = round.bustMeter
    assert(before > 0.0)
    run(round, t, 2600, 5400, function() return {} end)
    assert(round.bustMeter == before, "short blackout freezes")
    assert(round.separation == nil)
    run(round, t, 5600, 30000, function() return {} end)
    assert(round.bustMeter == 0.0, "long blackout drains")
    -- A huge gap between two evaluations counts at most three ticks.
    local r2 = R.newRound(t, 0)
    r2.escapeArmedAtMs = 0
    R.step(r2, t, 0, sample(150.0))
    R.step(r2, t, 60000, sample(150.0))
    assert(r2.escapeMeter <= (3 * t.tickMs) / 18000 + 1e-9, "elapsed is clamped")
    print("PASS blackout")
end

-- ── a crash stalls the car: a stalled runner is pinned, a stalled cop cannot arrest ──
do
    local t = Chase.rulesFor("vehicle")
    local round = R.newRound(t, 0)
    local crashAt
    -- Runner at 25 m/s (90 km/h) until 3 s, then dead stop (into a wall). Cop 12 m behind
    -- at the same speed, then stopped too.
    local outcome = run(round, t, 0, 20000, function(now)
        local x = math.min(now, 3000) / 1000 * 25.0
        local s = sample(nil, x - 12.0, x)
        return s
    end)
    for _, role in ipairs({ "runner", "cop" }) do
        local p = round.pace[role]
        if p and p.stalledUntilMs then crashAt = crashAt or p.stalledUntilMs end
    end
    assert(crashAt ~= nil, "a collapse from 90 km/h to 0 stalls")
    assert(outcome and outcome.outcome == "runner_busted", "both stopped in range ends in a bust")
    -- Foot rules never stall.
    local f = Chase.rulesFor("foot")
    local fr = R.newRound(f, 0)
    fr.pace.runner = { samples = {}, speeds = { { t = 0, kph = 90 } }, speedKph = 0 }
    assert(R.crashCheck(fr, f, "runner", 100) == false)
    print("PASS crash stall")
end

-- ── wording ──
do
    assert(R.line("runner_busted", true) == "Busted." and R.line("runner_busted", false) == "You were busted.")
    assert(R.line("whatever", true) == "You win." and R.line("whatever", false) == "Round over.")
    print("PASS lines")
end

print("PASS: op77_chase rules (head start, bust fill/drain/speed gates/core, escape arm/window/drain, clock, overtime, down, blackout, crash)")
