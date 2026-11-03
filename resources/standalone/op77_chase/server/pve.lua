-- op77_chase NCPD Escape (chase.pve): one player, or a crew, against NCPD bots. Public:
-- no staff switch, results recorded by Light RP as for any activity.
--
--   placing -> countdown -> active -> resolved -> closed
--
-- Every human is a runner: his own car in line behind the start checkpoint of one of the
-- Most Wanted courses, or on foot on it. The NCPD sends ChaseBots cops at the wheel of
-- the course's grid cars (front of the grid first), base + perRunner per runner (capped),
-- released in Most Wanted's waves once the head start is over. Each runner plays his own
-- Most Wanted round (WantedRules: the unit arrest, the heat, the shake, the extraction)
-- against every cop of the match:
--   * ESCAPED: a shake (no cop within escapeDistance for escapeGraceSeconds, after the cops
--     closed in at least once) once reputation.minSeconds have passed - an earlier shake
--     re-arms (they are still looking) - or the clock, or the extraction point;
--   * BUSTED: the arrest meter, or down.
-- His result goes to Light RP the moment his round ends (reputation from
-- config.pve.reputation: nothing for a round under minSeconds, only perDay paid rounds per
-- character and day), he goes home after the scoreboard, and the cops who hunted him take
-- the runners still out. The match ends with its last runner; the bots and every car go
-- with it. Bot cops fallen far behind are dispatched again on the road their runner took
-- (ChaseBots.wantsRedispatch / trailPick). No rating, no database.
--
-- Driven by ChasePve.tick(now) (server/pve_main.lua), deadlines not timers; the only
-- asynchronous step is a placement. tests/pve_test.lua runs it against fakes.
ChasePve = { matches = {}, playerMatch = {}, bucketOwner = {}, nextId = nil, daily = {}, dailyDay = nil }
local P = ChasePve
local R = WantedRules
local HOLD = { kind = "hold" }

local function cfg() return ChaseConfig.pve end
local function wcfg() return ChaseConfig.wanted end
local function W() return ChaseWorld end
local function aid() return cfg().activity.id end
local function log(fmt, ...) print(("[op77_chase] escape " .. fmt):format(...)) end
local function notify(id, kind, text, ms) W().notify(id, kind, text, ms, "NCPD Escape") end

-- The rules of a mode: Most Wanted's column, the overrides of config.pve.rules, the
-- NCPD Escape clock and head start.
function P.rulesFor(mode)
    local t = R.rulesFor(mode)
    for k, v in pairs((cfg().rules or {})[t.mode] or {}) do t[k] = v end
    t.durationSeconds = cfg().match.roundSeconds or t.durationSeconds
    t.headStartSeconds = (cfg().headStartSeconds or {})[t.mode] or t.headStartSeconds
    return t
end

-- Bot cops for n runners.
function P.copCount(n)
    local c = cfg().cops or {}
    return math.max(1, math.min(c.max or 8, (c.base or 1) + (c.perRunner or 2) * math.max(1, n)))
end

-- ---------------------------------------------------------------- marks

-- Runner i of n: by car in line behind the start checkpoint, towards the checkpoint before
-- it (the road he just drove), one car every runnerSpacingMetres; on foot side by side.
function P.runnerPoint(route, mode, i, n)
    local start = route.runner
    local h = start.heading or 0.0
    local s = start.position
    if mode == "foot" then
        local r = R.right(h)
        local off = (i - (n + 1) / 2) * 2.0
        return { position = { x = s.x + r.x * off, y = s.y + r.y * off, z = s.z }, heading = h }
    end
    local d = (cfg().match.runnerSpacingMetres or 9.0) * (i - 1)
    if d <= 0 then return { position = { x = s.x, y = s.y, z = s.z }, heading = h } end
    local prev = route.course and route.course[(route.runnerIndex or 2) - 1]
    if prev then
        local dx, dy, dz = prev.position.x - s.x, prev.position.y - s.y, (prev.position.z or s.z) - s.z
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1.0 then
            local k = math.min(d, len) / len
            return { position = { x = s.x + dx * k, y = s.y + dy * k, z = s.z + dz * k }, heading = h }
        end
    end
    local f = R.forward(h)
    return { position = { x = s.x - f.x * d, y = s.y - f.y * d, z = s.z }, heading = h }
end

local function carMark(point)
    return { position = { x = point.position.x, y = point.position.y, z = point.position.z + (cfg().match.carLiftMetres or 0.15) },
        yaw = point.heading or 0.0 }
end

-- On the car's driver (left) side, facing it.
local function besideMark(point)
    local r = R.right(point.heading)
    local door = cfg().match.doorClearMetres or 2.8
    return { position = { x = point.position.x - r.x * door, y = point.position.y - r.y * door,
        z = point.position.z + (cfg().match.spawnLiftMetres or 0.35) }, heading = (point.heading or 0.0) - 90.0 }
end

local function onMark(point)
    return { position = { x = point.position.x, y = point.position.y, z = point.position.z + (cfg().match.spawnLiftMetres or 0.35) },
        heading = point.heading or 0.0 }
end

local function markFor(match, m)
    if m.role == "runner" and match.mode == "foot" then return onMark(m.point) end
    return besideMark(m.point)
end

-- ---------------------------------------------------------------- members

local function member(match, id)
    for _, m in ipairs(match.members) do if m.id == id then return m end end
    return nil
end
P.member = member

local function present(m) return not m.gone and not m.released end
-- A runner still out there (round not over).
local function live(m) return m.role == "runner" and present(m) and m.outcome == nil and not m.leaving end

local function runners(match)
    local out = {}
    for _, m in ipairs(match.members) do if m.role == "runner" then out[#out + 1] = m end end
    return out
end

local function liveRunners(match)
    local out = {}
    for _, m in ipairs(match.members) do if live(m) then out[#out + 1] = m end end
    return out
end

local function cops(match)
    local out = {}
    for _, m in ipairs(match.members) do if m.role == "cop" and present(m) then out[#out + 1] = m end end
    return out
end

local function humanPresent(match)
    for _, m in ipairs(match.members) do if not m.bot and present(m) then return true end end
    return false
end

local function freeze(m, frozen)
    if frozen then
        if not m.frozen then m.frozen = true; W().freeze(m.id, true) end
    elseif m.frozen then
        m.frozen = nil
        W().freeze(m.id, false)
    end
end

local function freezeAll(match, frozen)
    for _, m in ipairs(match.members) do
        if present(m) or not frozen then freeze(m, frozen and present(m)) end
    end
end

local function random(match)
    match.seed = (match.seed * 1103515245 + 12345) % 2147483648
    return match.seed / 2147483648
end

-- ---------------------------------------------------------------- cars

local function removeCar(match, id)
    local car = match.cars[id]
    if car and car.id then W().removeCar(car.id) end
    match.cars[id] = nil
end

local function removeCars(match)
    for id in pairs(match.cars) do removeCar(match, id) end
end

local function createCar(match, m)
    if not m.point or (m.role == "runner" and match.mode == "foot") then return end
    removeCar(match, m.id)
    local mark = carMark(m.point)
    local spec = wcfg().vehicles[m.role == "runner" and "runner" or "cop"]
    local carId, recordOrReason = W().createCar(spec, mark, match.bucket)
    if carId then
        match.cars[m.id] = { id = carId, record = recordOrReason }
        if m.bot then ChaseBots.mount(m.id, carId, mark.yaw) end
    else
        log("match %d: %s car for %d failed: %s", match.id, tostring(m.role), m.id, tostring(recordOrReason))
    end
end

-- "Your car is N m away" until the runner sits in it.
local function refreshBoarding(match, now)
    if match.mode ~= "vehicle" then return end
    if now - (match.lastSeatCheckMs or 0) < (ChaseConfig.vehicles.seatCheckMs or 1000) then return end
    match.lastSeatCheckMs = now
    for _, m in ipairs(match.members) do
        local car = match.cars[m.id]
        m.boarding = nil
        if not m.bot and live(m) and car and car.id then
            local seat = W().seat(m.id)
            if seat == nil or tostring(seat) ~= tostring(car.id) then
                local p, c = W().position(m.id), W().carPosition(car.id)
                if p and c then
                    local dx, dy = p.x - c.x, p.y - c.y
                    m.boarding = { metres = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5) }
                else
                    m.boarding = { metres = nil }
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- HUD

local function scoreboard(match, selfId)
    local rows = {}
    for _, m in ipairs(runners(match)) do
        rows[#rows + 1] = { id = m.id, name = m.name, runner = true, self = m.id == selfId or nil, outcome = m.outcome,
            seconds = m.seconds, left = (m.leaving or m.gone) and m.outcome == nil or nil }
    end
    for _, m in ipairs(match.members) do
        if m.role == "cop" and not m.released and #rows < 16 then
            rows[#rows + 1] = { id = m.id, name = m.name, cop = true, released = match.copReleased[m.id] == true or nil }
        end
    end
    return rows
end

local function anyReleased(match)
    for _ in pairs(match.copReleased) do return true end
    return false
end

local function firstRelease(match)
    local first
    for _, at in pairs(match.releaseAt) do if first == nil or at < first then first = at end end
    return first
end

local function hudPayload(match, id, now, extra)
    local m = member(match, id)
    local heat = match.rules.heat
    local p = {
        activity = aid(), matchId = match.id, state = match.state, mode = match.mode, role = "runner",
        cops = #cops(match), runners = #runners(match), scoreboard = scoreboard(match, id),
    }
    if match.state == "countdown" then
        p.remainingMs = math.max(0, (match.countdownEndsAtMs or now) - now)
        p.headStartMs = math.floor((match.rules.headStartSeconds or 0) * 1000)
    elseif match.state == "active" and m and m.outcome then
        p.state, p.outcome, p.how, p.won = "resolved", m.outcome, m.how, m.outcome == "escaped"
        p.seconds, p.reputation = m.seconds, m.reputation
        p.remainingMs = math.max(0, (m.releaseAtMs or now) - now)
    elseif match.state == "active" and m and m.round then
        local round = m.round
        p.remainingMs = math.max(0, round.endsAtMs - now)
        p.overtime = round.overtime or nil
        p.heat, p.heatCount = round.heat, #heat
        p.heatProgress = R.heatProgress(heat, now - round.startedAtMs)
        p.released = anyReleased(match)
        if not p.released then
            local at = firstRelease(match)
            p.heldMs = at and math.max(0, at - now) or nil
        end
        p.copsNearby = round.copsNearby or 0
        p.nearestCop = round.nearest and math.floor(round.nearest + 0.5) or nil
        p.bustMeter = round.bustMeter or 0.0
        p.bustClosing = round.bustClosing or nil
        p.bustContact = round.bustContact or nil
        p.escapeProgress = (round.escapeMeter or 0) > 0 and math.min(1.0, round.escapeMeter) or nil
        p.escapeArmed = round.shakeArmed or nil
        local opensAt = match.startedAtMs + math.floor((cfg().reputation.minSeconds or 0) * 1000)
        if now < opensAt then p.escapeOpensMs = opensAt - now end
        p.stalledMs = ChaseRules.stallRemaining(round, "runner", now)
        if round.extraction then
            p.extraction = round.extraction.position
            p.extractionRadius = round.extraction.radius
            local rp = W().position(id)
            if rp then p.extractionDistance = math.floor(R.planar(rp, round.extraction.position) + 0.5) end
        end
    elseif match.state == "resolved" then
        p.remainingMs = math.max(0, ((m and m.releaseAtMs) or match.releaseAtMs or now) - now)
        p.void = match.void or nil
        p.reason = match.void and match.voidReason or nil
        if m then p.outcome, p.how, p.won, p.seconds, p.reputation = m.outcome, m.how, m.outcome == "escaped", m.seconds, m.reputation end
    end
    if m and m.boarding and (match.state == "countdown" or match.state == "active") then p.boarding = m.boarding end
    -- Every human is a runner and the cops are bots: no dot to hide (hideDots lists players only).
    if extra then
        local more = type(extra) == "function" and extra(id) or extra
        for k, v in pairs(more or {}) do p[k] = v end
    end
    return p
end
P.hudPayload = hudPayload

local function pushOne(match, m, now)
    if not m.bot and present(m) then W().hud(m.id, hudPayload(match, m.id, now)) end
end

local function pushAll(match, now, extra)
    for _, m in ipairs(match.members) do
        if not m.bot and present(m) then W().hud(m.id, hudPayload(match, m.id, now, extra)) end
    end
    match.lastHudMs = now
end

local function notifyRunners(match, kind, text, ms, except)
    for _, m in ipairs(liveRunners(match)) do
        if m.id ~= except then notify(m.id, kind, text, ms) end
    end
end

-- ---------------------------------------------------------------- results

local function dayOf()
    if type(Open77) == "table" and type(Open77.time) == "table" and type(Open77.time.unix) == "function" then
        local ok, unix = pcall(Open77.time.unix)
        if ok and tonumber(unix) then return math.floor(tonumber(unix) / 86400) end
    end
    return 0
end

local function characterId(m)
    if type(m.identifier) ~= "string" or m.identifier == "" then return "player:" .. tostring(m.id) end
    return m.identifier .. "#" .. tostring(m.characterKey or "default")
end

-- Reputation for one runner's round: nothing for a leaver or a round under minSeconds,
-- and only the first perDay paid rounds of a character in a day pay.
function P.reputation(match, m, day)
    local rep = cfg().reputation
    if match.void or m.outcome == "left" then return rep.leaver or 0 end
    if (m.seconds or 0) < (rep.minSeconds or 60) then return 0 end
    day = day or dayOf()
    if P.dailyDay ~= day then P.daily, P.dailyDay = {}, day end
    local key = characterId(m)
    local count = (P.daily[key] or 0) + 1
    P.daily[key] = count
    if count > (rep.perDay or 8) then return 0 end
    return m.outcome == "escaped" and (rep.escaped or 0) or (rep.busted or 0)
end

function P.resultFor(match, m)
    local escaped = m.outcome == "escaped"
    m.reputation = P.reputation(match, m)
    return {
        placement = escaped and 1 or 2,
        score = escaped and 1 or 0,
        won = escaped,
        stats = { mode = match.mode, outcome = m.outcome, how = m.how, seconds = m.seconds or 0,
            shakes = m.round and m.round.shakes or 0, cops = match.copCount, runners = #runners(match),
            crew = m.squad ~= nil or nil, forfeit = m.outcome == "left" or nil },
        reputation = m.reputation,
    }
end

-- ---------------------------------------------------------------- the runners' ends

local LINES = {
    shake      = { title = "Escaped", text = "You lost them. Clean escape." },
    clock      = { title = "Escaped", text = "You outlasted the NCPD." },
    extraction = { title = "Escaped", text = "You made the extraction." },
    arrest     = { title = "Busted", text = "You were cuffed." },
    takedown   = { title = "Busted", text = "You went down." },
    left       = { title = "Left", text = "You left NCPD Escape." },
}
P.LINES = LINES

local HOW = { runner_shook = "shake", time_expired = "clock", runner_extracted = "extraction",
    runner_busted = "arrest", runner_down = "takedown", runner_left = "left" }

local finish

-- Cops whose runner is done take the runner still out with the fewest cops on him.
local function retarget(match)
    local out = liveRunners(match)
    if #out == 0 then return end
    local load = {}
    for _, r in ipairs(out) do load[r.id] = 0 end
    for _, c in ipairs(cops(match)) do
        local t = match.target[c.id]
        if t ~= nil and load[t] ~= nil then load[t] = load[t] + 1 end
    end
    for _, c in ipairs(cops(match)) do
        local t = match.target[c.id]
        if t == nil or load[t] == nil then
            local best
            for _, r in ipairs(out) do
                if best == nil or load[r.id] < load[best.id] then best = r end
            end
            match.target[c.id] = best.id
            load[best.id] = load[best.id] + 1
        end
    end
end
P.retarget = retarget

-- One runner's round is over: his result now, the scoreboard, then home.
local function resolveRunner(match, m, outcome, now, detail)
    if m.outcome ~= nil then return end
    m.how = HOW[outcome] or "arrest"
    m.outcome = (m.how == "shake" or m.how == "clock" or m.how == "extraction") and "escaped"
        or (m.how == "left" and "left" or "busted")
    m.resolvedAtMs = now
    m.seconds = match.startedAtMs and math.max(0, math.floor((now - match.startedAtMs) / 1000)) or 0
    m.releaseAtMs = m.how == "left" and now or (now + math.floor((cfg().match.scoreboardSeconds or 8) * 1000))
    m.boarding = nil
    if m.outcome == "busted" then freeze(m, true) end -- cuffed until he goes home
    if not m.gone and not match.void then ChaseCore.result(m.id, P.resultFor(match, m), aid()) end
    log("match %d: runner %d %s (%s) after %ds, +%d rep, %s", match.id, m.id, m.outcome, m.how, m.seconds, m.reputation or 0,
        tostring(detail))
    local line = LINES[m.how] or LINES.arrest
    if m.how ~= "left" then
        notify(m.id, m.outcome == "escaped" and "success" or "info", ("%s %s"):format(line.text,
            (m.reputation or 0) > 0 and "" or ((m.seconds or 0) < (cfg().reputation.minSeconds or 60)
                and ("(Under %ds: no reputation.)"):format(cfg().reputation.minSeconds or 60) or "")), 6000)
    end
    notifyRunners(match, m.outcome == "escaped" and "success" or "warning", ("%s %s."):format(m.name,
        m.outcome == "escaped" and "got away" or (m.how == "left" and "left" or "was busted")), 4000, m.id)
    pushOne(match, m, now)
    retarget(match)
    if #liveRunners(match) == 0 then return finish(match, now, "every runner done") end
end
P.resolveRunner = resolveRunner

finish = function(match, now, why)
    if match.state == "resolved" or match.state == "closed" then return end
    freezeAll(match, false)
    local last = now
    for _, m in ipairs(runners(match)) do
        if m.outcome == "busted" and present(m) then freeze(m, true) end
        if m.releaseAtMs and m.releaseAtMs > last then last = m.releaseAtMs end
    end
    match.state = "resolved"
    match.resolvedAtMs = now
    match.releaseAtMs = match.void and (now + math.floor((cfg().match.scoreboardSeconds or 8) * 1000)) or last
    log("match %d resolved%s: %s", match.id, match.void and " (VOID)" or "", tostring(why))
    pushAll(match, now)
    if match.void then
        for _, m in ipairs(match.members) do
            if not m.bot and present(m) then notify(m.id, "info", match.voidReason or "Called off. Nothing counts.", 6000) end
        end
    end
end

function P.abort(match, now, reason)
    if match.state == "resolved" or match.state == "closed" then return false end
    match.void, match.voidReason = true, reason
    match.token = match.token + 1
    finish(match, now, reason)
    return true
end

-- ---------------------------------------------------------------- start

local function allocateBucket()
    local b = cfg().buckets
    for bucket = b.from, b.to do
        if P.bucketOwner[bucket] == nil then return bucket end
    end
    return nil
end

local function place(match, now)
    match.state = "placing"
    match.token = match.token + 1
    match.placeDeadlineMs = now + math.floor((cfg().match.placeTimeoutSeconds or 40) * 1000)
    local token = match.token
    local cover = { title = "NCPD Escape", subtitle = match.mode == "foot" and "On foot" or "By car", zone = "Escape instance" }
    for _, m in ipairs(match.members) do
        m.placed, m.placeError, m.placing = nil, nil, true
        W().place(m.id, markFor(match, m), match.bucket, function(ok, why)
            m.placing = nil
            if P.matches[match.id] ~= match or match.token ~= token or match.state ~= "placing" then return end
            m.placed, m.placeError = ok == true, why
            if not ok then log("match %d: placement of %d failed: %s", match.id, m.id, tostring(why)) end
        end, (not m.bot) and cover or nil)
    end
    pushAll(match, now, { state = "placing" })
end

-- Light RP takes the players (activityEnter), then the match starts. ids are one group
-- (a player alone, or a crew), at most maxRunners. opts = { squads = { [id] = squad } }.
-- Returns match | nil, reason, refused = { { id, why } }.
function P.admit(ids, mode, now, opts)
    if ChaseBots == nil then return nil, "no_bots", {} end
    local bucket = allocateBucket()
    if bucket == nil then return nil, "busy", {} end
    local entered, refused = {}, {}
    for _, id in ipairs(ids) do
        if #entered >= (cfg().maxRunners or 4) then break end
        local ok, why = ChaseCore.enter(id, aid())
        if ok then entered[#entered + 1] = id else refused[#refused + 1] = { id = id, why = why } end
    end
    if #entered == 0 then return nil, "refused", refused end
    return P.start(entered, mode, now, bucket, opts), nil, refused
end

function P.start(ids, mode, now, bucket, opts)
    opts = opts or {}
    bucket = bucket or allocateBucket()
    if bucket == nil then return nil end
    if P.nextId == nil then P.nextId = now + 1 end
    local id = P.nextId
    P.nextId = P.nextId + 1
    mode = mode == "foot" and "foot" or "vehicle"
    local routes = wcfg().routes
    local route = routes[(id % #routes) + 1]
    local match = { id = id, bucket = bucket, mode = mode, rules = P.rulesFor(mode), route = route, members = {}, cars = {},
        copReleased = {}, releaseAt = {}, target = {}, state = "new", createdAtMs = now, token = 0, seed = id % 2147483647 }
    for i, pid in ipairs(ids) do
        local info = ChaseCore.player(pid) or {}
        local s = opts.squads and opts.squads[pid]
        match.members[#match.members + 1] = { id = pid, name = info.name or W().name(pid), identifier = info.identifier,
            characterKey = info.characterKey, role = "runner", squad = type(s) == "table" and s.id or s,
            point = P.runnerPoint(route, mode, i, #ids) }
        P.playerMatch[pid] = id
    end
    match.copCount = math.min(P.copCount(#ids), #route.cops)
    for j = 1, match.copCount do
        -- Each cop's car is simulated by the client of the runner it starts on.
        local admission = ids[((j - 1) % #ids) + 1]
        local botId = ChaseBots.create({ role = "cop", mode = "vehicle", bucket = bucket, admission = admission, owner = aid() })
        match.members[#match.members + 1] = { id = botId, name = W().name(botId), role = "cop", bot = true,
            point = route.cops[#route.cops - j + 1] }
        match.target[botId] = admission
    end
    P.matches[id] = match
    P.bucketOwner[bucket] = id
    W().setupBucket(bucket)
    log("match %d created: %d runner(s), %d cop(s), %s, %s, bucket %d", id, #ids, match.copCount, mode, route.name or "?", bucket)
    place(match, now)
    return match
end

local function beginCountdown(match, now)
    for _, m in ipairs(match.members) do
        if present(m) then createCar(match, m) end
    end
    freezeAll(match, true)
    match.state = "countdown"
    match.countdownEndsAtMs = now + math.floor((cfg().match.countdownSeconds or 10) * 1000)
    local headStart = match.rules.headStartSeconds or 0
    for _, m in ipairs(liveRunners(match)) do
        local text = ("You are on the run: %ds head start, then %d NCPD unit%s roll out. Lose them, outlast the clock or reach the extraction.")
            :format(headStart, match.copCount, match.copCount > 1 and "s" or "")
        if match.mode == "vehicle" then text = text .. " Your car is beside you: driver door on its LEFT." end
        notify(m.id, "info", text, 8000)
    end
    pushAll(match, now)
end

local function beginActive(match, now)
    freezeAll(match, false)
    match.state = "active"
    match.startedAtMs = now
    for _, m in ipairs(liveRunners(match)) do
        m.round = R.newRound(match.rules, now)
        -- The first shake only counts once the cops have closed in on him.
        m.round.shakeArmed = false
        m.trail = {}
    end
    local ids = {}
    for _, c in ipairs(cops(match)) do ids[#ids + 1] = c.id end
    local plan = R.wavePlan(ids, match.rules.heat, math.floor((match.rules.headStartSeconds or 0) * 1000))
    for copId, at in pairs(plan) do match.releaseAt[copId] = now + at end
    retarget(match)
    notifyRunners(match, "warning", "GO. Lose them.", 3000)
    pushAll(match, now)
    log("match %d active (%s, bucket %d)", match.id, match.mode, match.bucket)
end

-- ---------------------------------------------------------------- departures

-- He asked to quit: a runner still out gets his result now (no reputation), and goes home.
function P.leaveRequest(id, now)
    local match = P.matches[P.playerMatch[id] or -1]
    if match == nil then return false end
    local m = member(match, id)
    if m == nil or m.gone or m.released or m.leaving then return false end
    if match.state == "active" and m.outcome == nil and m.round then
        resolveRunner(match, m, "runner_left", now, "left")
    elseif m.outcome == nil then
        m.outcome, m.how = "left", "left"
    end
    m.leaving = true
    m.releaseAtMs = now
    freeze(m, false)
    if match.state ~= "resolved" and match.state ~= "closed" and #liveRunners(match) == 0 then
        if match.state ~= "active" then match.void, match.voidReason = true, "Everyone left before the start. Nothing counts." end
        finish(match, now, ("player %d left"):format(id))
    end
    return true
end

-- Light RP already released him (disconnect, character switch...): no result, no leave.
function P.dropped(id, now, reason)
    local match = P.matches[P.playerMatch[id] or -1]
    P.playerMatch[id] = nil
    if match == nil then return false end
    local m = member(match, id)
    if m == nil then return false end
    m.gone = true
    if m.outcome == nil then m.outcome, m.how = "left", "left" end
    log("match %d: runner %d dropped (%s)", match.id, id, tostring(reason))
    retarget(match)
    if match.state ~= "resolved" and match.state ~= "closed" and #liveRunners(match) == 0 then
        if match.state ~= "active" then match.void, match.voidReason = true, "Called off. Nothing counts." end
        finish(match, now, ("player %d dropped"):format(id))
    end
    return true
end

-- Light RP stopped: it returned every player itself; void, and the cars and bots go.
function P.coreStopped(now)
    for _, match in pairs(P.matches) do
        freezeAll(match, false)
        for _, m in ipairs(match.members) do
            if not m.bot then
                if present(m) then W().hud(m.id, { state = "idle", activity = aid() }) end
                m.gone = true
                if P.playerMatch[m.id] == match.id then P.playerMatch[m.id] = nil end
            end
        end
        match.void, match.voidReason = true, "Light RP restarted. Nothing counts."
        match.token = match.token + 1
        finish(match, now, "op77_lightrp stopped")
    end
end

function P.matchOf(id) return P.matches[P.playerMatch[id] or -1] end

-- ---------------------------------------------------------------- release

local function close(match)
    removeCars(match)
    for _, m in ipairs(match.members) do
        if m.bot and ChaseBots then ChaseBots.remove(m.id) end
    end
    W().sweepBucket(match.bucket)
    P.bucketOwner[match.bucket] = nil
    for _, m in ipairs(match.members) do
        if P.playerMatch[m.id] == match.id then P.playerMatch[m.id] = nil end
    end
    match.state = "closed"
    P.matches[match.id] = nil
    log("match %d closed", match.id)
end

-- One member home: out of the car, alive, then activityLeave (Light RP takes him back).
-- A runner goes when his own scoreboard is over, the bots when the match is.
local function releaseMember(match, m, now)
    if m.gone or m.released then return end
    if m.bot then
        if match.state ~= "resolved" then return end
        if humanPresent(match) and now < (match.releaseAtMs or now) then return end
        m.released = true
        removeCar(match, m.id)
        ChaseBots.remove(m.id)
        return
    end
    if m.outcome == nil and not m.leaving and match.state ~= "resolved" then return end
    if now < (m.releaseAtMs or match.releaseAtMs or now) then return end
    m.exitStartedMs = m.exitStartedMs or now
    if m.placing and now - m.exitStartedMs < 35000 then return end
    local seat = W().seat(m.id)
    if seat ~= nil and now - m.exitStartedMs < 3000 then
        if not m.forcedOut then m.forcedOut = true; W().forceOut(m.id, seat) end
        return
    end
    if W().alive(m.id) == false then
        if not m.respawnAskedMs then
            m.respawnAskedMs = now
            W().respawnInPlace(m.id, match.bucket, m.point and onMark(m.point) or nil)
            return
        end
        if now - m.respawnAskedMs < 10000 then return end
    end
    m.released = true
    freeze(m, false)
    removeCar(match, m.id)
    if P.playerMatch[m.id] == match.id then P.playerMatch[m.id] = nil end
    W().hud(m.id, { state = "idle", activity = aid() })
    ChaseCore.leave(m.id, { returnPlayer = true }, aid())
end

-- ---------------------------------------------------------------- active

local function levelAllows(round, heat, field)
    for i = 1, round.heat or 1 do
        if (heat[i] or {})[field] then return true end
    end
    return false
end

local function extractionTick(match, m, pos)
    if m.round.extraction or m.extractionMissed or pos == nil then return end
    if not levelAllows(m.round, match.rules.heat, "extraction") then return end
    local x = wcfg().extraction
    local point = R.pickExtraction(wcfg().extractionPoints, pos, x.band[match.mode] or { 400, 1200 }, function() return random(match) end)
    if point == nil then m.extractionMissed = true return end
    m.round.extraction = { position = { x = point.position.x, y = point.position.y, z = point.position.z },
        radius = (x.radius or {})[match.mode] or 15, zTolerance = x.zTolerance or 8 }
    notify(m.id, "success", ("Extraction point located %.0f m away - reach it to get out."):format(R.planar(pos, point.position)), 6000)
end

-- Every bot cop: chase its runner once released, otherwise hold.
local function steerBots(match)
    for _, c in ipairs(match.members) do
        if c.bot and present(c) then
            local order = HOLD
            if match.state == "active" and match.copReleased[c.id] then
                local target = member(match, match.target[c.id] or -1)
                if target and live(target) then order = { kind = "chase", target = { player = target.id } } end
            end
            ChaseBots.steer(c.id, order)
        end
    end
end

-- A bot cop far behind its runner (no AI drives beyond 350 m of a player) comes back on the
-- road the runner took, 120-220 m behind him.
local function redispatch(match, now, positions)
    for _, c in ipairs(cops(match)) do
        local target = member(match, match.target[c.id] or -1)
        local tp = target and positions[target.id]
        if c.bot and match.copReleased[c.id] and tp and target.trail then
            local p = W().position(c.id)
            local d = p and R.planar(p, tp) or nil
            if ChaseBots.wantsRedispatch(c.id, d, now) then
                local spot = ChaseBots.trailPick(target.trail, tp)
                if spot then
                    c.point = spot
                    createCar(match, c)
                    log("match %d: bot cop %d dispatched again %.0f m behind runner %d", match.id, c.id, R.planar(spot.position, tp), target.id)
                end
            end
        end
    end
end

local function tickActive(match, now)
    refreshBoarding(match, now)
    local released = false
    for copId, at in pairs(match.releaseAt) do
        if not match.copReleased[copId] and now >= at then match.copReleased[copId] = true; released = true end
    end
    if released then
        if not match.announcedRelease then
            match.announcedRelease = true
            notifyRunners(match, "warning", "The NCPD is rolling out.", 3000)
        else
            notifyRunners(match, "warning", "Backup is rolling out.", 3000)
        end
    end
    local copSample = {}
    for _, c in ipairs(cops(match)) do
        local p = W().position(c.id)
        if p and p.bucket ~= nil and p.bucket ~= match.bucket then p = nil end
        copSample[c.id] = { pos = p, down = W().alive(c.id) == false, released = match.copReleased[c.id] == true }
    end
    local minMs = math.floor((cfg().reputation.minSeconds or 0) * 1000)
    local positions = {}
    for _, m in ipairs(liveRunners(match)) do
        local rp = W().position(m.id)
        if rp and rp.bucket ~= nil and rp.bucket ~= match.bucket then rp = nil end
        positions[m.id] = rp
        local outcome, events = R.step(m.round, match.rules, now, { runnerPos = rp, runnerDown = W().alive(m.id) == false, cops = copSample })
        for _, e in ipairs(events or {}) do
            if e.kind == "heat" and e.text then
                notify(m.id, "warning", e.text, 3000)
            elseif e.kind == "shake_started" then
                notify(m.id, "warning", ("No cop within %.0f m - keep it up %ds to lose them."):format(match.rules.escapeDistance or 150,
                    math.floor(match.rules.escapeGraceSeconds or 12)), 3000)
            elseif e.kind == "shake" then
                if now - match.startedAtMs >= minMs then
                    outcome = outcome or { outcome = "runner_shook", winner = "runner", detail = ("shake %d"):format(e.count or 1) }
                else
                    notify(m.id, "info", ("You lost them for now - the NCPD is still looking. A shake counts after %ds.")
                        :format(math.floor(minMs / 1000)), 5000)
                end
            elseif e.kind == "crash" and e.id == "runner" then
                notify(m.id, "warning", ("Crash! Engine stalled - %.0fs."):format(match.rules.crashStallSeconds or 0), 3000)
            end
        end
        if outcome then
            resolveRunner(match, m, outcome.outcome, now, outcome.detail)
            if match.state ~= "active" then return end
        else
            extractionTick(match, m, rp)
            if rp then ChaseBots.trailPush(m.trail, rp, now) end
        end
    end
    redispatch(match, now, positions)
    if now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
end

local function brokenBot(match)
    for _, m in ipairs(match.members) do
        if m.bot and present(m) and ChaseBots.broken(m.id) then return m end
    end
    return nil
end

function P.tickMatch(match, now)
    for _, m in ipairs(match.members) do releaseMember(match, m, now) end
    local state = match.state
    if state ~= "resolved" and state ~= "closed" then
        local broken = brokenBot(match)
        if broken then
            log("match %d: bot %d broken (%s)", match.id, broken.id, tostring(select(2, ChaseBots.broken(broken.id))))
            return P.abort(match, now, "The NCPD bots could not be set up. Nothing counts.")
        end
        steerBots(match)
    end
    if state == "placing" then
        local done, failed = true, nil
        for _, m in ipairs(match.members) do
            if present(m) and not m.leaving then
                if m.placed == false then failed = m
                elseif m.placed ~= true then done = false end
            end
        end
        if failed or (not done and now >= match.placeDeadlineMs) then
            local why = failed and ("placement of %d failed: %s"):format(failed.id, tostring(failed.placeError)) or "placement timed out"
            log("match %d: %s", match.id, why)
            return P.abort(match, now, "The escape area did not load. Nothing counts.")
        end
        if done then beginCountdown(match, now) end
    elseif state == "countdown" then
        refreshBoarding(match, now)
        if now >= match.countdownEndsAtMs then beginActive(match, now)
        elseif now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
    elseif state == "active" then
        tickActive(match, now)
    elseif state == "resolved" then
        local pending = false
        for _, m in ipairs(match.members) do
            if not m.gone and not m.released then pending = true end
        end
        if not pending then close(match)
        elseif now - (match.lastHudMs or 0) >= 1000 then pushAll(match, now) end
    end
end

function P.tick(now)
    local ids = {}
    for id in pairs(P.matches) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local match = P.matches[id]
        if match then
            local ok, err = pcall(P.tickMatch, match, now)
            if not ok then log("match %d tick error: %s", id, tostring(err)) end
        end
    end
end

-- The resource is stopping: Light RP returns the players itself; the cars and bots go now.
function P.shutdown()
    for _, match in pairs(P.matches) do
        freezeAll(match, false)
        removeCars(match)
        for _, m in ipairs(match.members) do
            if m.bot and ChaseBots then ChaseBots.remove(m.id) end
        end
    end
end

-- For the hub.
function P.status(queued)
    local running, players = 0, 0
    for _, match in pairs(P.matches) do
        if match.state ~= "closed" then
            running = running + 1
            for _, m in ipairs(match.members) do if not m.bot and present(m) then players = players + 1 end end
        end
    end
    local phase = running > 0 and "running" or ((queued or 0) > 0 and "lobby" or "idle")
    local parts = {}
    if (queued or 0) > 0 then parts[#parts + 1] = ("%d getting ready"):format(queued) end
    if running > 0 then parts[#parts + 1] = ("%d escape%s on"):format(running, running > 1 and "s" or "") end
    return { phase = phase, players = players, queued = queued or 0, joinable = allocateBucket() ~= nil,
        detail = #parts > 0 and table.concat(parts, " · ") or "You (and your crew) against NCPD bots. Solo or crew." }
end
