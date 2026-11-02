-- op77_chase Most Wanted rules: one round of one runner against several cops, evaluated
-- tick by tick, plus the pure helpers of the mode (heat, waves, extraction draw,
-- dispatch sightings, roadblock spot, points, standings). No native: tests drive it.
--
-- The arrest is D's 1v1 arrest meter (server/rules.lua) widened to a unit:
--   * it fills while at least one released cop is within the bust radius, slow enough
--     (bustCopMaxSpeedKph) and not stalled, and the runner is pinned (slow or stalled);
--   * every extra cop closing at the same time adds extraCopFactor to the fill rate
--     (capped at maxCopFactor): a unit boxing him in cuffs him faster;
--   * the heat widens the radius (bustScale) and speeds the fill (fillScale).
-- A SHAKE replaces the 1v1 escape: no released cop within escapeDistance for
-- escapeGraceSeconds earns the runner points; the next one only counts after a cop
-- closed back within escapeDistance. The runner WINS the round by surviving the clock or
-- by reaching the extraction point; the cops win by the arrest or a takedown (runner down).
--
--   WantedRules.rulesFor(mode)                  -> merged column
--   WantedRules.newRound(t, now, opts)          -> round
--   WantedRules.step(round, t, now, sample)     -> outcome | nil, events
--       sample = { runnerPos, runnerDown, cops = { [id] = { pos, down, released } } }
--       outcome = { outcome = "runner_busted"|"runner_down"|"time_expired"|"runner_extracted",
--                   winner = "runner"|"cops", arrestBy, assists = {ids}, takedownBy }
--       events = { kind = "heat"|"overtime"|"crash"|"shake"|"shake_started", ... }
WantedRules = {}
local R = WantedRules

local function wcfg() return ChaseConfig.wanted end

local function planar(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
local function dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
R.planar, R.dist3 = planar, dist3

function R.forward(heading)
    local r = math.rad(heading or 0.0)
    return { x = -math.sin(r), y = math.cos(r) }
end
function R.right(heading)
    local r = math.rad(heading or 0.0)
    return { x = math.cos(r), y = math.sin(r) }
end

function R.normalizeMode(mode)
    if mode == nil then return nil end
    mode = tostring(mode):lower()
    if mode == "foot" or mode == "onfoot" or mode == "on_foot" then return "foot" end
    if mode == "vehicle" or mode == "car" or mode == "cars" or mode == "drive" then return "vehicle" end
    return nil
end

-- The column of the runner's mode, merged with the general numbers.
function R.rulesFor(mode)
    local c = wcfg()
    mode = mode == "foot" and "foot" or "vehicle"
    local t = {}
    for k, v in pairs(c.rules[mode]) do t[k] = v end
    t.mode = mode
    t.tickMs = math.floor(1000 / math.max(1, ChaseConfig.tickHz or 5))
    t.durationSeconds = c.match.roundSeconds
    t.headStartSeconds = (c.headStartSeconds or {})[mode] or 10
    t.positionStaleResetMs = c.match.positionStaleResetMs
    t.heat = c.heat
    return t
end

-- ---------------------------------------------------------------- heat and waves

-- The heat level at `elapsedMs` since GO: index, definition.
function R.heatAt(heat, elapsedMs)
    local index = 1
    for i, level in ipairs(heat or {}) do
        if elapsedMs >= (level.atSeconds or 0) * 1000 then index = i end
    end
    return index, (heat or {})[index] or {}
end

-- 0..1 towards the next level (1 at the last).
function R.heatProgress(heat, elapsedMs)
    local index = R.heatAt(heat, elapsedMs)
    local here, nextLevel = heat[index], heat[index + 1]
    if not here or not nextLevel then return 1.0 end
    local from, to = (here.atSeconds or 0) * 1000, (nextLevel.atSeconds or 0) * 1000
    if to <= from then return 1.0 end
    return math.max(0.0, math.min(1.0, (elapsedMs - from) / (to - from)))
end

-- When each cop is released, in ms after GO. Cops are taken in order; the share of a
-- level counts all cops (0.5 of 7 = 4 in the first wave); wave 1 waits for the head start.
function R.wavePlan(copIds, heat, headStartMs)
    local plan, released = {}, 0
    local total = #copIds
    for _, level in ipairs(heat or {}) do
        if level.release then
            local target = math.min(total, math.max(1, math.ceil(total * level.release - 1e-9)))
            local at = math.max(headStartMs or 0, (level.atSeconds or 0) * 1000)
            while released < target do
                released = released + 1
                plan[copIds[released]] = at
            end
        end
    end
    -- Anyone left (a heat table without a full release) goes with the last wave.
    local last = headStartMs or 0
    for _, at in pairs(plan) do if at > last then last = at end end
    while released < total do
        released = released + 1
        plan[copIds[released]] = last
    end
    return plan
end

-- ---------------------------------------------------------------- the round

function R.newRound(t, now, opts)
    opts = opts or {}
    return {
        startedAtMs = now,
        endsAtMs = now + math.floor((opts.durationSeconds or t.durationSeconds or 165) * 1000),
        heat = 1,
        bustMeter = 0.0, bustClosing = false, bustContact = false, closing = 0,
        escapeMeter = 0.0, escapeFilling = false, shakeArmed = true, shakes = 0,
        lastEvalMs = now,
        pace = {}, closingAt = {}, copDistance = {},
        extraction = nil,
    }
end

local function drain(value, elapsedMs, seconds)
    local v = (value or 0.0) - ((elapsedMs / 1000.0) / math.max(0.001, seconds))
    return v > 0.0 and v or 0.0
end

local function paceKph(round, key)
    local p = round.pace[key]
    return p and p.speedKph or nil
end

function R.step(round, t, now, sample)
    local events = {}
    local elapsed = now - (round.lastEvalMs or now)
    local tickMs = t.tickMs or 200
    if elapsed > tickMs * 3 then elapsed = tickMs * 3 end
    if elapsed < 0 then elapsed = 0 end
    round.lastEvalMs = now
    sample = sample or {}

    -- Heat, by the clock.
    local level, def = R.heatAt(t.heat, now - round.startedAtMs)
    if level > (round.heat or 1) then
        round.heat = level
        events[#events + 1] = { kind = "heat", level = level, text = def.text }
    end
    local bustScale, fillScale = def.bustScale or 1.0, def.fillScale or 1.0

    -- The runner's own fate first: down, extracted.
    local runner = sample.runnerPos
    local cops = sample.cops or {}

    -- Distances of the released, standing cops (only these count for anything).
    local nearestId, nearest, nearby = nil, nil, 0
    round.copDistance = {}
    if runner then
        for id, c in pairs(cops) do
            if c.released and not c.down and c.pos then
                local d = dist3(c.pos, runner)
                round.copDistance[id] = d
                if nearest == nil or d < nearest or (d == nearest and id < nearestId) then nearest, nearestId = d, id end
                if d <= (t.nearbyMetres or 250) then nearby = nearby + 1 end
            end
        end
    end
    round.nearest, round.nearestId, round.copsNearby = nearest, nearestId, nearby

    if sample.runnerDown then
        local credit = nil
        if nearest and nearest <= (t.takedownCreditMetres or 40) then credit = nearestId end
        return { outcome = "runner_down", winner = "cops", takedownBy = credit, detail = "runner down" }, events
    end

    -- The clock: an arrest closing at the buzzer plays out as overtime.
    if now >= round.endsAtMs then
        if round.bustClosing then
            if not round.overtime then
                round.overtime = true
                events[#events + 1] = { kind = "overtime" }
            end
        else
            return { outcome = "time_expired", winner = "runner", detail = round.overtime and "overtime arrest broken" or "clock" }, events
        end
    end

    if runner == nil then
        -- Cannot tell: freeze; after a long blackout, let the meters drain.
        round.unknownSinceMs = round.unknownSinceMs or now
        if (now - round.unknownSinceMs) >= (t.positionStaleResetMs or 3000) then
            round.bustMeter = drain(round.bustMeter, elapsed, t.bustDrainSeconds or 8.0)
            round.escapeMeter = drain(round.escapeMeter, elapsed, t.escapeDrainSeconds or 6.0)
            round.bustClosing, round.bustContact, round.escapeFilling, round.closing = false, false, false, 0
        end
        return nil, events
    end
    round.unknownSinceMs = nil

    -- Extraction: inside its radius (planar), within zTolerance.
    local x = round.extraction
    if x and x.position then
        local p = x.position
        if planar(runner, p) <= (x.radius or 15) and math.abs((runner.z or 0) - (p.z or 0)) <= (x.zTolerance or 8) then
            return { outcome = "runner_extracted", winner = "runner", detail = "extraction reached" }, events
        end
    end

    -- Pace and crashes.
    ChaseRules.pacePush(round, "runner", runner, now)
    if ChaseRules.crashCheck(round, t, "runner", now) then events[#events + 1] = { kind = "crash", id = "runner" } end
    for id, c in pairs(cops) do
        if c.pos and not c.down then
            ChaseRules.pacePush(round, id, c.pos, now)
            if c.released and ChaseRules.crashCheck(round, t, id, now) then events[#events + 1] = { kind = "crash", id = id } end
        end
    end

    -- Shake: every released cop known to be beyond escapeDistance (an unreadable cop is
    -- not a far cop: nothing fills while one is unknown).
    local known = nearest ~= nil
    for _, c in pairs(cops) do if c.released and not c.down and not c.pos then known = false end end
    local graceMs = (t.escapeGraceSeconds or 12) * 1000
    if known and nearest >= (t.escapeDistance or 150) and round.shakeArmed then
        if not round.escapeFilling then events[#events + 1] = { kind = "shake_started" } end
        round.escapeMeter = (round.escapeMeter or 0.0) + (graceMs > 0 and (elapsed / graceMs) or 1.0)
        round.escapeFilling = true
        if round.escapeMeter >= 1.0 then
            round.escapeMeter, round.escapeFilling, round.shakeArmed = 0.0, false, false
            round.shakes = (round.shakes or 0) + 1
            events[#events + 1] = { kind = "shake", count = round.shakes }
        end
    else
        round.escapeMeter = drain(round.escapeMeter, elapsed, t.escapeDrainSeconds or 6.0)
        round.escapeFilling = false
        if nearest ~= nil and nearest < (t.escapeDistance or 150) then round.shakeArmed = true end
    end

    -- Arrest meter.
    local radius = (t.bustDistance or 15) * bustScale
    local core = (t.bustCoreDistance or 0) * bustScale
    local runnerPinned = ChaseRules.stalled(round, "runner", now) or
        (paceKph(round, "runner") ~= nil and paceKph(round, "runner") <= (t.bustRunnerMaxSpeedKph or math.huge))
    local contact, closingIds = false, {}
    for id, d in pairs(round.copDistance) do
        if d <= radius then
            contact = true
            local kph = paceKph(round, id)
            if runnerPinned and not ChaseRules.stalled(round, id, now) and kph ~= nil and kph <= (t.bustCopMaxSpeedKph or math.huge) then
                closingIds[#closingIds + 1] = id
                round.closingAt[id] = now
            end
        end
    end
    table.sort(closingIds)
    round.bustContact, round.bustClosing, round.closing = contact, #closingIds > 0, #closingIds
    local meter = round.bustMeter or 0.0
    if #closingIds > 0 then
        local best
        for _, id in ipairs(closingIds) do
            if best == nil or round.copDistance[id] < round.copDistance[best] then best = id end
        end
        local sep = round.copDistance[best]
        local factor, coreFactor = 1.0, t.bustCoreFactor or 1.0
        if core > 0 and coreFactor > 1.0 and radius > core then
            if sep <= core then factor = coreFactor
            else factor = coreFactor + (1.0 - coreFactor) * ((sep - core) / (radius - core)) end
        end
        local unit = math.min(t.maxCopFactor or 2.5, 1.0 + (#closingIds - 1) * (t.extraCopFactor or 0.5))
        meter = meter + ((elapsed / 1000.0) * factor * unit * fillScale / math.max(0.001, t.bustFillSeconds or 6.0))
        if meter >= 1.0 then
            round.bustMeter = 1.0
            local assists = {}
            local windowMs = (t.assistWindowSeconds or 6) * 1000
            for id, at in pairs(round.closingAt) do
                if id ~= best and cops[id] and (now - at) <= windowMs then assists[#assists + 1] = id end
            end
            for id, d in pairs(round.copDistance) do
                if id ~= best and d <= (t.assistMetres or 30) then
                    local listed = false
                    for _, a in ipairs(assists) do if a == id then listed = true end end
                    if not listed then assists[#assists + 1] = id end
                end
            end
            table.sort(assists)
            return { outcome = "runner_busted", winner = "cops", arrestBy = best, assists = assists,
                detail = ("%.1fm, %d closing"):format(sep, #closingIds) }, events
        end
    else
        meter = drain(meter, elapsed, contact and (t.bustContactDrainSeconds or 30) or (t.bustDrainSeconds or 8))
    end
    round.bustMeter = meter
    return nil, events
end

-- ---------------------------------------------------------------- dispatch, extraction, roadblocks

-- A point within `radius * spread` of `pos` (so the runner is inside the circle drawn
-- around it). `rand()` -> [0, 1).
function R.fuzz(pos, radius, rand, spread)
    local angle = rand() * math.pi * 2.0
    local r = math.sqrt(rand()) * radius * (spread or 0.6)
    return { x = pos.x + math.cos(angle) * r, y = pos.y + math.sin(angle) * r, z = pos.z or 0 }
end

-- An extraction point between band[1] and band[2] metres (planar) from `from`. Among
-- the candidates in the band one is drawn at random; with none, the point nearest to the
-- band (still at least band[1] away when possible).
function R.pickExtraction(points, from, band, rand)
    if type(points) ~= "table" or #points == 0 or from == nil then return nil end
    local low, high = band[1] or 0, band[2] or math.huge
    local inBand = {}
    for _, p in ipairs(points) do
        local d = planar(p.position, from)
        if d >= low and d <= high then inBand[#inBand + 1] = p end
    end
    if #inBand > 0 then return inBand[math.min(#inBand, math.floor(rand() * #inBand) + 1)] end
    local best, bestGap
    for _, p in ipairs(points) do
        local d = planar(p.position, from)
        local gap = d < low and (low - d) * 4 or (d - high) -- too close is worse than too far
        if best == nil or gap < bestGap then best, bestGap = p, gap end
    end
    return best
end

-- Where a roadblock goes: `distance` metres along the runner's recent heading, at his
-- altitude, or nil + reason. `samples` = the runner's pace samples (oldest first).
function R.roadblockSpot(samples, rb)
    if type(samples) ~= "table" or #samples < 2 then return nil, "no heading yet" end
    local a, b = samples[1], samples[#samples]
    local dx, dy = b.x - a.x, b.y - a.y
    local run = math.sqrt(dx * dx + dy * dy)
    if run < (rb.minMoveMetres or 8) then return nil, "runner too slow for a heading" end
    local grade = math.abs((b.z or 0) - (a.z or 0)) / run
    if grade > (rb.maxGradePercent or 6) / 100.0 then
        return nil, ("grade %.1f%% too steep to guess an altitude"):format(grade * 100)
    end
    local ux, uy = dx / run, dy / run
    local distance = rb.distanceMetres or 66
    -- heading in the forward() convention: forward = (-sin h, cos h)
    local heading = math.deg(math.atan(-ux, uy))
    return { x = b.x + ux * distance, y = b.y + uy * distance, z = b.z or 0 }, heading
end

-- The cars of a block: across the path, flank to the runner.
function R.roadblockMarks(centre, heading, rb)
    local across = R.right(heading)
    local count = math.max(1, rb.cars or 2)
    local marks = {}
    for i = 1, count do
        local offset = (i - (count + 1) / 2) * (rb.spacingMetres or 3.6)
        marks[#marks + 1] = { position = { x = centre.x + across.x * offset, y = centre.y + across.y * offset, z = centre.z },
            yaw = heading + 90.0 }
    end
    return marks
end

-- ---------------------------------------------------------------- points

local function stats(match, id)
    local s = match.stats[id]
    if s == nil then
        s = { points = 0, runnerMs = 0, runnerRounds = 0, copRounds = 0, arrests = 0, assists = 0, takedowns = 0,
            extractions = 0, survivals = 0, shakes = 0, busted = 0 }
        match.stats[id] = s
    end
    return s
end
R.stats = stats

-- Score one finished round into match.stats. `round` = { runnerId, copIds, outcome,
-- survivedMs, shakes }. Returns the points each player made this round.
function R.score(match, round)
    local p = wcfg().points
    local gained = {}
    local function add(id, n, field)
        if id == nil or n == 0 then return end
        local s = stats(match, id)
        s.points = s.points + n
        if field then s[field] = s[field] + 1 end
        gained[id] = (gained[id] or 0) + n
    end
    local runner = round.runnerId
    local o = round.outcome
    if o == "runner_left" or o == "void" then return gained end
    local rs = stats(match, runner)
    rs.runnerRounds = rs.runnerRounds + 1
    rs.runnerMs = rs.runnerMs + (round.survivedMs or 0)
    for _, id in ipairs(round.copIds or {}) do local s = stats(match, id); s.copRounds = s.copRounds + 1 end
    add(runner, math.floor((round.survivedMs or 0) / 1000) * (p.runnerPerSecond or 1))
    if (round.shakes or 0) > 0 then
        for _ = 1, round.shakes do add(runner, p.shake or 0, "shakes") end
    end
    if o == "time_expired" then add(runner, p.survived or 0, "survivals")
    elseif o == "runner_extracted" then add(runner, p.extracted or 0, "extractions")
    elseif o == "runner_busted" then
        rs.busted = rs.busted + 1
        add(round.arrestBy, p.arrest or 0, "arrests")
        for _, id in ipairs(round.assists or {}) do add(id, p.assist or 0, "assists") end
    elseif o == "runner_down" then
        rs.busted = rs.busted + 1
        add(round.takedownBy, p.takedown or 0, "takedowns")
    end
    if o == "runner_busted" or o == "runner_down" then
        for _, id in ipairs(round.copIds or {}) do add(id, p.unitWin or 0) end
    end
    return gained
end

-- Final ranking: points, then time as runner, then arrests, then the player id. Equal
-- points and runner time share a placement.
function R.standings(match, ids)
    local rows = {}
    for _, id in ipairs(ids) do
        local s = stats(match, id)
        rows[#rows + 1] = { id = id, points = s.points, runnerMs = s.runnerMs, arrests = s.arrests, stats = s }
    end
    table.sort(rows, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        if a.runnerMs ~= b.runnerMs then return a.runnerMs > b.runnerMs end
        if a.arrests ~= b.arrests then return a.arrests > b.arrests end
        return a.id < b.id
    end)
    for i, row in ipairs(rows) do
        local prev = rows[i - 1]
        if prev and prev.points == row.points and prev.runnerMs == row.runnerMs then row.placement = prev.placement
        else row.placement = i end
    end
    return rows
end

-- What the cops are told of the runner's distance: banded, never to the metre.
function R.coarseDistance(d)
    if d == nil then return nil end
    if d < 50 then return 50 end
    if d < 200 then return math.floor(d / 25 + 0.5) * 25 end
    if d < 600 then return math.floor(d / 50 + 0.5) * 50 end
    return math.min(1500, math.floor(d / 100 + 0.5) * 100)
end

R.LINES = {
    runner_busted    = { title = "Busted", runner = "You were cuffed.", cop = "Suspect in custody." },
    runner_down      = { title = "Takedown", runner = "You went down.", cop = "Suspect down." },
    time_expired     = { title = "Survived", runner = "You outlasted the NCPD.", cop = "He outlasted the unit." },
    runner_extracted = { title = "Extracted", runner = "You made the extraction.", cop = "He made the extraction." },
    runner_left      = { title = "Runner gone", runner = "You left.", cop = "The runner left. No score." },
    void             = { title = "Called off", runner = "Nothing counts.", cop = "Nothing counts." },
}

function R.line(outcome, role)
    local l = R.LINES[outcome] or R.LINES.void
    return role == "runner" and l.runner or l.cop, l.title
end
