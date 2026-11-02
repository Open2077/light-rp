-- op77_chase rules: one round of a chase, evaluated tick by tick. Pure Lua (no native),
-- so tests/rules_test.lua drives it with made-up positions and clocks.
--
-- Ported from Pursuit's `tickActive` (base resources/gamemodes/pursuit/server/match.lua),
-- whose comments argue every rule. The short version:
--   * the BUST is a meter: it fills while the cop is within bustDistance, the runner is
--     (nearly) stopped and the cop is not flying past; it drains outside the radius;
--   * the ESCAPE is a window: past escapeDistance an escape meter fills over
--     escapeGraceSeconds and drains (faster) when the cop pulls the gap back;
--   * the clock is the cop's: time out without an escape = round to the cop, unless an
--     attempt is running at the buzzer (overtime);
--   * never judge one sample: an unreadable position freezes the meters, and only a
--     long blackout drains them.
--
--   ChaseRules.newRound(t, now)            -> round record (meters, clocks)
--   ChaseRules.step(round, t, now, sample) -> outcome | nil, events
--       sample = { sep = metres|nil, copPos, runnerPos, copDown, runnerDown }
--       outcome = { outcome = "runner_busted"|..., winner = "cop"|"runner", detail }
--       events  = list of { kind = "released"|"escape_started"|"overtime"|"crash", role? }
ChaseRules = {}
local R = ChaseRules

local SPEED_WINDOW_MS = 1000
local SPEED_MIN_SPAN_MS = 400
local CRASH_LOOKBACK_MS = 1500
local ESCAPE_NOTIFY_REARM_MS = 10000

R.DEFAULTS = { tickMs = 200, positionStaleResetMs = 3000, timeoutWinner = "cop", copDownEndsRound = true }

-- A round record. `t` is the rules column of the match's mode, merged with the general
-- numbers (tickMs, timeoutWinner, copDownEndsRound, positionStaleResetMs).
function R.newRound(t, now, durationSeconds)
    local round = {
        startedAtMs = now,
        endsAtMs = now + math.floor((durationSeconds or t.durationSeconds or 180) * 1000),
        copReleaseAtMs = now + math.floor((t.headStartSeconds or 0) * 1000),
        copReleased = false,
        escapeMeter = 0.0, escapeFilling = false,
        bustMeter = 0.0, bustClosing = false, bustContact = false,
        lastEvalMs = now,
        pace = {},
    }
    if (t.headStartSeconds or 0) <= 0 then
        round.copReleased = true
        round.escapeArmedAtMs = now + math.floor((t.escapeArmSeconds or 0) * 1000)
    end
    return round
end

-- ---------------------------------------------------------------- pace

-- One position sample for a role; refreshes its windowed speed (km/h) or nil when the
-- baseline is too short to trust (nil means "do not fill", never "stopped").
function R.pacePush(round, role, pos, now)
    local p = round.pace[role]
    if p == nil then p = { samples = {}, speeds = {} }; round.pace[role] = p end
    local s = p.samples
    s[#s + 1] = { t = now, x = pos.x, y = pos.y, z = pos.z or 0 }
    while #s > 1 and (now - s[1].t) > (SPEED_WINDOW_MS + 200) do table.remove(s, 1) end
    local oldest = s[1]
    local span = now - oldest.t
    if span >= SPEED_MIN_SPAN_MS then
        local dx, dy, dz = pos.x - oldest.x, pos.y - oldest.y, (pos.z or 0) - oldest.z
        p.speedKph = (math.sqrt(dx * dx + dy * dy + dz * dz) / (span / 1000.0)) * 3.6
        local v = p.speeds
        v[#v + 1] = { t = now, kph = p.speedKph }
        while #v > 1 and (now - v[1].t) > CRASH_LOOKBACK_MS do table.remove(v, 1) end
    else
        p.speedKph = nil
    end
    return p
end

-- A windowed speed that collapses from a real pace to almost nothing is bodywork: the
-- engine stalls for crashStallSeconds (a stalled runner counts as pinned, a stalled cop
-- cannot arrest). Returns true when this sample started a stall.
function R.crashCheck(round, t, role, now)
    local stallMs = (tonumber(t.crashStallSeconds) or 0) * 1000
    if stallMs <= 0 then return false end
    local p = round.pace[role]
    if p == nil or p.speedKph == nil then return false end
    if p.stalledUntilMs ~= nil and now < p.stalledUntilMs then return false end
    local peak
    for _, entry in ipairs(p.speeds) do
        if peak == nil or entry.kph > peak then peak = entry.kph end
    end
    if peak == nil then return false end
    if peak >= (tonumber(t.crashMinSpeedKph) or 45.0) and (peak - p.speedKph) >= (tonumber(t.crashDropKph) or 40.0) then
        p.stalledUntilMs = now + stallMs
        p.speeds = {}
        return true
    end
    return false
end

function R.stalled(round, role, now)
    local p = round.pace[role]
    return p ~= nil and p.stalledUntilMs ~= nil and now < p.stalledUntilMs
end

function R.stallRemaining(round, role, now)
    local p = round.pace[role]
    if p == nil or p.stalledUntilMs == nil then return nil end
    local left = p.stalledUntilMs - now
    return left > 0 and left or nil
end

-- 0..1, or nil while no escape attempt runs (the bar leaves the screen between attempts).
function R.escapeProgress(round)
    local meter = round.escapeMeter or 0.0
    if meter <= 0.0 then return nil end
    return meter > 1.0 and 1.0 or meter
end

-- ---------------------------------------------------------------- the step

local function drain(value, elapsedMs, seconds)
    local v = (value or 0.0) - ((elapsedMs / 1000.0) / math.max(0.001, seconds))
    return v > 0.0 and v or 0.0
end

function R.step(round, t, now, sample)
    local events = {}
    local tickMs = t.tickMs or R.DEFAULTS.tickMs
    local elapsed = now - (round.lastEvalMs or now)
    if elapsed > tickMs * 3 then elapsed = tickMs * 3 end
    if elapsed < 0 then elapsed = 0 end
    round.lastEvalMs = now

    -- The head start ends: the hunt begins, from empty meters.
    if not round.copReleased and round.copReleaseAtMs ~= nil and now >= round.copReleaseAtMs then
        round.copReleased = true
        round.escapeMeter, round.escapeFilling, round.bustMeter = 0.0, false, 0.0
        round.escapeArmedAtMs = now + math.floor((t.escapeArmSeconds or 0) * 1000)
        events[#events + 1] = { kind = "released" }
    end

    -- The clock. An attempt underway at the buzzer plays out as overtime.
    if round.endsAtMs ~= nil and now >= round.endsAtMs then
        if round.escapeFilling or round.bustClosing then
            if not round.overtime then
                round.overtime = true
                events[#events + 1] = { kind = "overtime" }
            end
        else
            local winner = (t.timeoutWinner or R.DEFAULTS.timeoutWinner) == "runner" and "runner" or "cop"
            return { outcome = winner == "runner" and "time_expired" or "runner_timed_out", winner = winner,
                detail = round.overtime and "overtime attempt broken" or "duration reached" }, events
        end
    end

    sample = sample or {}
    if sample.runnerDown then
        return { outcome = "runner_down", winner = "cop", detail = "runner down" }, events
    end
    local copDownEnds = t.copDownEndsRound
    if copDownEnds == nil then copDownEnds = R.DEFAULTS.copDownEndsRound end
    if copDownEnds and sample.copDown then
        return { outcome = "cop_down", winner = "runner", detail = "cop down" }, events
    end

    local sep = sample.sep
    round.separation = sep
    if sep ~= nil then
        if sample.copPos then R.pacePush(round, "cop", sample.copPos, now) end
        if sample.runnerPos then R.pacePush(round, "runner", sample.runnerPos, now) end
        for _, role in ipairs({ "cop", "runner" }) do
            if R.crashCheck(round, t, role, now) then events[#events + 1] = { kind = "crash", role = role } end
        end
    end

    if sep == nil then
        -- Cannot tell: freeze; after a long blackout, let both meters drain.
        round.unknownSinceMs = round.unknownSinceMs or now
        if (now - round.unknownSinceMs) >= (t.positionStaleResetMs or R.DEFAULTS.positionStaleResetMs) then
            round.escapeMeter = drain(round.escapeMeter, elapsed, t.escapeDrainSeconds or 6.0)
            round.bustMeter = drain(round.bustMeter, elapsed, t.bustDrainSeconds or 5.0)
            round.escapeFilling, round.bustClosing, round.bustContact = false, false, false
        end
        return nil, events
    end
    round.unknownSinceMs = nil

    if not round.copReleased then
        round.escapeMeter, round.escapeFilling = 0.0, false
        round.bustMeter, round.bustClosing, round.bustContact = 0.0, false, false
        return nil, events
    end

    -- Escape window.
    local armed = round.escapeArmedAtMs == nil or now >= round.escapeArmedAtMs
    local graceMs = (t.escapeGraceSeconds or 0) * 1000
    if sep >= t.escapeDistance and armed then
        if graceMs <= 0 then
            return { outcome = "runner_escaped", winner = "runner", detail = ("%.0fm"):format(sep) }, events
        end
        local was = round.escapeMeter or 0.0
        round.escapeMeter = was + (elapsed / graceMs)
        round.escapeFilling = true
        if was <= 0.0 and (round.escapeNotifiedAtMs == nil or (now - round.escapeNotifiedAtMs) >= ESCAPE_NOTIFY_REARM_MS) then
            round.escapeNotifiedAtMs = now
            events[#events + 1] = { kind = "escape_started" }
        end
        if round.escapeMeter >= 1.0 then
            round.escapeMeter = 1.0
            return { outcome = "runner_escaped", winner = "runner", detail = ("%.0fm held"):format(sep) }, events
        end
    else
        round.escapeMeter = drain(round.escapeMeter, elapsed, t.escapeDrainSeconds or 6.0)
        round.escapeFilling = false
    end

    -- Bust meter.
    local fillSeconds = t.bustFillSeconds or 5.0
    local drainSeconds = t.bustDrainSeconds or (fillSeconds * 1.6)
    local contactDrainSeconds = t.bustContactDrainSeconds or drainSeconds
    local contact = sep <= t.bustDistance
    local runnerPace, copPace = round.pace.runner, round.pace.cop
    local runnerPinned = R.stalled(round, "runner", now) or
        (runnerPace ~= nil and runnerPace.speedKph ~= nil and runnerPace.speedKph <= (tonumber(t.bustRunnerMaxSpeedKph) or math.huge))
    local copPresent = (not R.stalled(round, "cop", now)) and
        (copPace ~= nil and copPace.speedKph ~= nil and copPace.speedKph <= (tonumber(t.bustCopMaxSpeedKph) or math.huge))
    local closing = contact and runnerPinned and copPresent
    round.bustContact, round.bustClosing = contact, closing

    local meter = round.bustMeter or 0.0
    if closing then
        local factor = 1.0
        local core, coreFactor = t.bustCoreDistance, t.bustCoreFactor or 1.0
        if core ~= nil and coreFactor > 1.0 and t.bustDistance > core then
            if sep <= core then factor = coreFactor
            else factor = coreFactor + (1.0 - coreFactor) * ((sep - core) / (t.bustDistance - core)) end
        end
        meter = meter + ((elapsed / 1000.0) * factor / math.max(0.001, fillSeconds))
        if meter >= 1.0 then
            round.bustMeter = 1.0
            return { outcome = "runner_busted", winner = "cop", detail = ("%.1fm, meter full"):format(sep) }, events
        end
    else
        meter = drain(meter, elapsed, contact and contactDrainSeconds or drainSeconds)
    end
    round.bustMeter = meter
    return nil, events
end

-- Player-facing wording for a round outcome, from one side.
R.LINES = {
    runner_escaped   = { won = "You lost him.", lost = "He got away." },
    runner_busted    = { won = "Busted.", lost = "You were busted." },
    runner_down      = { won = "Target down.", lost = "You went down." },
    cop_down         = { won = "The cop is down.", lost = "You went down." },
    time_expired     = { won = "You survived the clock.", lost = "Out of time." },
    runner_timed_out = { won = "Time's up - you never lost him.", lost = "Time's up - you never shook him." },
    opponent_left    = { won = "Your opponent left.", lost = "You left the chase." },
}

function R.line(outcome, won)
    local lines = R.LINES[outcome]
    if lines == nil then return won and "You win." or "Round over." end
    return won and lines.won or lines.lost
end
