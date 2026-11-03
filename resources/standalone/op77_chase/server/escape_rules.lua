-- op77_chase NCPD Escape rules (police = "ncpd"): one runner's run against the game's own
-- NCPD, evaluated tick by tick. Pure Lua (no native), so tests/pve_test.lua drives it with
-- made-up positions and clocks.
--
-- The police are the runner's own game's: the server cannot see them, nor learn that they
-- lost him. So the server owns the whole outcome:
--   * the HEAT is a clock: stars `at` seconds after the head start, up to the difficulty's
--     ceiling (the last step);
--   * the BUST is a meter: it fills while he is stopped (or out of every car, by car) and
--     drains when he moves; full = busted. Down = busted at once (takedown);
--   * the ESCAPE is the extraction point (it appears extractionAtSeconds after GO) or the
--     clock (roundSeconds from GO);
--   * never judge one sample: an unreadable position freezes the meter, and only a long
--     blackout empties it.
--
--   ChaseEscapeRules.difficulty(id)              -> id, its config (unknown id = default)
--   ChaseEscapeRules.starsAt(heat, headMs, ms)   -> stars due `ms` after GO
--   ChaseEscapeRules.ceiling(heat)               -> the last step's stars
--   ChaseEscapeRules.nextStarMs(heat, headMs, ms)-> ms until the next star, or nil
--   ChaseEscapeRules.newRun(mode, difficulty, now) -> run record
--   ChaseEscapeRules.step(run, now, sample)      -> outcome | nil, events
--       sample = { pos = {x,y,z}|nil, down = bool, inCar = bool|nil, boarded = bool }
--       outcome = { outcome = "runner_busted"|"runner_down"|"time_expired"|"runner_extracted", detail }
--       events = list of { kind = "heat", stars } | { kind = "bust_started" } | { kind = "close_call", count }
ChaseEscapeRules = {}
local E = ChaseEscapeRules

local SPEED_WINDOW_MS = 1000
local SPEED_MIN_SPAN_MS = 400

local function cfg() return ChaseConfig.pve end

local function planar(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
E.planar = planar

function E.difficulty(id)
    local all = cfg().difficulties or {}
    if type(id) == "string" and all[id] then return id, all[id] end
    local fallback = cfg().defaultDifficulty or "standard"
    if all[fallback] then return fallback, all[fallback] end
    for k, v in pairs(all) do return k, v end
    return "standard", { roundSeconds = 150, bustFillSeconds = 5, extractionAtSeconds = 40, heat = { { at = 0, stars = 1 } } }
end

function E.starsAt(heat, headStartMs, elapsedMs)
    if elapsedMs < (headStartMs or 0) then return 0 end
    local t = (elapsedMs - (headStartMs or 0)) / 1000.0
    local stars = 0
    for _, step in ipairs(heat or {}) do
        if t >= (step.at or 0) then stars = math.max(stars, step.stars or 0) end
    end
    return math.max(0, math.min(5, math.floor(stars)))
end

function E.ceiling(heat)
    local top = 0
    for _, step in ipairs(heat or {}) do top = math.max(top, step.stars or 0) end
    return math.max(0, math.min(5, math.floor(top)))
end

function E.nextStarMs(heat, headStartMs, elapsedMs)
    local now = E.starsAt(heat, headStartMs, elapsedMs)
    local best
    for _, step in ipairs(heat or {}) do
        if (step.stars or 0) > now then
            local at = (headStartMs or 0) + math.floor((step.at or 0) * 1000)
            if at > elapsedMs and (best == nil or at < best) then best = at end
        end
    end
    return best and (best - elapsedMs) or nil
end

function E.newRun(mode, difficulty, now)
    mode = mode == "foot" and "foot" or "vehicle"
    local id, d = E.difficulty(difficulty)
    return {
        mode = mode, difficulty = id, diff = d,
        startedAtMs = now,
        endsAtMs = now + math.floor((d.roundSeconds or 150) * 1000),
        headStartMs = math.floor(((cfg().headStartSeconds or {})[mode] or 0) * 1000),
        graceMs = math.floor((((cfg().bust or {}).graceSeconds or {})[mode] or 0) * 1000),
        extractionAtMs = now + math.floor((d.extractionAtSeconds or 40) * 1000),
        ceiling = E.ceiling(d.heat),
        stars = 0, maxStars = 0,
        bustMeter = 0.0, bustFilling = false, bustPeak = 0.0, closeCalls = 0,
        samples = {}, speedKph = nil,
        lastEvalMs = now,
    }
end

-- One position sample; the windowed speed (km/h), or nil while the window is too short to
-- trust (nil means "do not fill", never "stopped").
local function pacePush(run, pos, now)
    local s = run.samples
    s[#s + 1] = { t = now, x = pos.x, y = pos.y, z = pos.z or 0 }
    while #s > 1 and (now - s[1].t) > (SPEED_WINDOW_MS + 200) do table.remove(s, 1) end
    local oldest = s[1]
    local span = now - oldest.t
    if span >= SPEED_MIN_SPAN_MS then
        local dx, dy, dz = pos.x - oldest.x, pos.y - oldest.y, (pos.z or 0) - oldest.z
        run.speedKph = (math.sqrt(dx * dx + dy * dy + dz * dz) / (span / 1000.0)) * 3.6
    else
        run.speedKph = nil
    end
    return run.speedKph
end

-- Is the bust armed: from the first star once bust.graceSeconds have passed since GO, and by
-- car once he has sat in his car (or boardingGraceSeconds after GO).
function E.armed(run, now, boarded)
    if run.stars <= 0 then return false end
    if boarded then run.boarded = true end
    if now - run.startedAtMs < (run.graceMs or 0) then return false end
    if run.mode ~= "vehicle" then return true end
    if run.boarded then return true end
    return now - run.startedAtMs >= math.floor((cfg().bust.boardingGraceSeconds or 15) * 1000)
end

-- Why the meter fills now ("stopped" | "out_of_car"), or nil.
function E.pinned(run, speed, inCar)
    local b = cfg().bust or {}
    local col = b[run.mode] or {}
    if speed == nil then return nil end
    if run.mode == "vehicle" and inCar == false and speed <= (col.outOfCarMaxKph or 35.0) then return "out_of_car" end
    if speed <= (col.stopKph or 10.0) then return "stopped" end
    return nil
end

function E.step(run, now, sample)
    local events = {}
    local elapsed = now - (run.lastEvalMs or now)
    run.lastEvalMs = now
    local sinceGo = now - run.startedAtMs

    -- Heat: the clock decides.
    local stars = E.starsAt(run.diff.heat, run.headStartMs, sinceGo)
    if stars > run.stars then
        run.stars = stars
        if stars > run.maxStars then run.maxStars = stars end
        events[#events + 1] = { kind = "heat", stars = stars }
    end

    if sample.down then
        return { outcome = "runner_down", detail = "down" }, events
    end

    local pos = sample.pos
    if pos == nil then
        -- Freeze; a long blackout empties the meter.
        run.unknownSinceMs = run.unknownSinceMs or now
        if now - run.unknownSinceMs >= (cfg().bust.staleResetMs or 3000) then
            run.bustMeter, run.bustFilling, run.samples, run.speedKph = 0.0, false, {}, nil
        end
        run.why = nil
        if now >= run.endsAtMs then return { outcome = "time_expired", detail = "clock (position unknown)" }, events end
        return nil, events
    end
    run.unknownSinceMs = nil

    -- Extraction: inside its radius (planar), within zTolerance.
    local x = run.extraction
    if x and x.position then
        if planar(pos, x.position) <= (x.radius or 15) and math.abs((pos.z or 0) - (x.position.z or 0)) <= (x.zTolerance or 8) then
            return { outcome = "runner_extracted", detail = "extraction reached" }, events
        end
    end

    local speed = pacePush(run, pos, now)
    local b = cfg().bust or {}
    run.armed = E.armed(run, now, sample.boarded)
    local why = run.armed and E.pinned(run, speed, sample.inCar) or nil
    run.why = why
    if why then
        if not run.bustFilling then events[#events + 1] = { kind = "bust_started", why = why } end
        run.bustFilling = true
        run.bustMeter = run.bustMeter + (elapsed / 1000.0) / math.max(0.1, run.diff.bustFillSeconds or 5.0)
        if run.bustMeter > run.bustPeak then run.bustPeak = run.bustMeter end
        if run.bustMeter >= 1.0 then
            run.bustMeter = 1.0
            return { outcome = "runner_busted", detail = why }, events
        end
    else
        run.bustFilling = false
        if run.bustMeter > 0 then
            run.bustMeter = math.max(0.0, run.bustMeter - (elapsed / 1000.0) / math.max(0.1, b.drainSeconds or 2.5))
            if run.bustMeter <= 0 then
                if run.bustPeak >= (b.closeCall or 0.6) then
                    run.closeCalls = run.closeCalls + 1
                    events[#events + 1] = { kind = "close_call", count = run.closeCalls }
                end
                run.bustPeak = 0.0
            end
        end
    end

    if now >= run.endsAtMs then return { outcome = "time_expired", detail = "clock" }, events end
    return nil, events
end
