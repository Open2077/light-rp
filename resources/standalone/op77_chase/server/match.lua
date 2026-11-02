-- op77_chase match lifecycle: from "two queued players" to "both handed back to Light RP".
--
--   placing -> countdown -> active -> (intermission -> placing -> ...) -> resolved -> closed
--
-- Everything is driven by Chase.tick(now) at ChaseConfig.tickHz: deadlines, not timers, so
-- the whole flow runs in tests/match_test.lua against a fake world (ChaseWorld) and a
-- fake Light RP (ChaseCore). The only asynchronous step is a placement, which reports
-- back through Chase.onPlaced.
--
-- Ported from Pursuit (match.lua), with the Light RP changes:
--   * admission is activityEnter (no lobby bucket, no ready circle);
--   * players are moved with Open77.players.teleport (no kill -> respawn); a player who
--     went down is respawned on his next mark, and in place before going home;
--   * the return is activityLeave: Light RP brings the player back to where he was;
--   * match buckets live in ChaseConfig.buckets (4300000+).
Chase = { matches = {}, playerMatch = {}, bucketOwner = {}, pairings = {}, nextId = nil }
local FINAL = { opponent_left = true }

local function cfg() return ChaseConfig end
local function log(fmt, ...) print(("[op77_chase] " .. fmt):format(...)) end

-- The rules a match plays by: its mode's column plus the general numbers.
function Chase.rulesFor(mode)
    local c = cfg()
    local column = c.rules[mode] or c.rules.vehicle
    local t = {}
    for k, v in pairs(column) do t[k] = v end
    t.tickMs = math.floor(1000 / math.max(1, c.tickHz or 5))
    t.timeoutWinner = c.match.timeoutWinner
    t.copDownEndsRound = c.match.copDownEndsRound
    t.positionStaleResetMs = c.match.positionStaleResetMs
    return t
end

local function forward(heading)
    local r = math.rad(heading or 0.0)
    return { x = -math.sin(r), y = math.cos(r) }
end
local function right(heading)
    local r = math.rad(heading or 0.0)
    return { x = math.cos(r), y = math.sin(r) }
end

-- Where a mark's car goes: beside the player (door clearance), on the surveyed rest z.
function Chase.carMark(point)
    local v = cfg().vehicles
    local offset = point.vehicleOffset or {}
    local fwd = offset.forward or v.spawnOffset.forward
    local lat = offset.lateral or v.spawnOffset.lateral
    local up = offset.up or v.spawnOffset.up
    local f, r = forward(point.heading), right(point.heading)
    local z = point.vehicleRestZ and (point.vehicleRestZ + (v.restClearanceMetres or 0.10)) or (point.position.z + up)
    return {
        position = { x = point.position.x + f.x * fwd + r.x * lat, y = point.position.y + f.y * fwd + r.y * lat, z = z },
        yaw = point.vehicleYaw or point.heading or 0.0,
    }
end

-- The player's mark, lifted (authored z values are position reads, under the floor).
local function lifted(point)
    local lift = tonumber(cfg().match.spawnLiftMetres) or 0.0
    return {
        position = { x = point.position.x, y = point.position.y, z = point.position.z + lift },
        heading = point.playerYaw or point.heading or 0.0,
    }
end

function Chase.spawnPair(match, index)
    local list = match.mode == "foot" and cfg().match.footSpawns or cfg().match.vehicleSpawns
    if type(list) ~= "table" or #list == 0 then return nil end
    return list[((match.id + (index or 1) - 2) % #list) + 1]
end

local function allocateBucket()
    local b = cfg().buckets
    for bucket = b.from, b.to do
        if Chase.bucketOwner[bucket] == nil then return bucket end
    end
    return nil
end

local function member(match, id)
    for _, m in ipairs(match.members) do if m.id == id then return m end end
    return nil
end
Chase.member = member

local function opponent(match, id)
    for _, m in ipairs(match.members) do if m.id ~= id then return m end end
    return nil
end

local function roleId(match, role)
    for _, m in ipairs(match.members) do if match.roles[m.id] == role then return m.id end end
    return nil
end

function Chase.roundCount(match)
    local total = math.max(1, math.floor(tonumber(cfg().match.roundsPerMatch) or 1))
    if match.deciderAdded then total = total + 1 end
    return total
end

local function present(m) return not m.gone and not m.released end

local function allPresent(match)
    if #match.members < cfg().match.size then return false end
    for _, m in ipairs(match.members) do if m.gone then return false end end
    return true
end

local function pairKey(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

-- ---------------------------------------------------------------- HUD

local function displayName(match, id)
    local m = member(match, id)
    return m and m.name or ChaseWorld.name(id)
end

local function hudPayload(match, id, now, extra)
    local m = member(match, id)
    local other = opponent(match, id)
    local t = match.rules
    local round = match.chase
    local role = match.roles[id]
    local payload = {
        matchId = match.id, state = match.state, mode = match.mode, role = role,
        opponentName = other and displayName(match, other.id) or nil,
        round = match.round, roundCount = Chase.roundCount(match),
        decider = (match.deciderAdded and match.round >= Chase.roundCount(match)) or nil,
        scoreSelf = match.score[id] or 0, scoreOpponent = other and (match.score[other.id] or 0) or 0,
        bustDistance = t.bustDistance, escapeDistance = t.escapeDistance, timeoutWinner = t.timeoutWinner,
    }
    if match.state == "countdown" then
        payload.remainingMs = math.max(0, (match.countdownEndsAtMs or now) - now)
    elseif match.state == "active" and round then
        payload.remainingMs = math.max(0, (round.endsAtMs or now) - now)
        payload.copReleased = round.copReleased
        payload.overtime = round.overtime or nil
        if round.copReleased then
            payload.bustMeter = round.bustMeter or 0.0
            payload.bustClosing = round.bustClosing or nil
            payload.bustContact = round.bustContact or nil
        end
        payload.escapeProgress = ChaseRules.escapeProgress(round)
        payload.escapeFilling = payload.escapeProgress ~= nil and round.escapeFilling or nil
        payload.stalledMs = role and ChaseRules.stallRemaining(round, role, now) or nil
        -- Live separation for the RUNNER only: a cop with a live distance can find him by feel.
        if role == "runner" then payload.separation = round.separation end
    elseif match.state == "intermission" then
        payload.remainingMs = math.max(0, (match.intermissionEndsAtMs or now) - now)
    end
    if m and m.boarding and (match.state == "countdown" or match.state == "active") then
        payload.boarding = m.boarding
    end
    if extra then for k, v in pairs(extra) do payload[k] = v end end
    return payload
end

local function pushAll(match, now, extra)
    for _, m in ipairs(match.members) do
        if present(m) then
            local more = extra
            if type(extra) == "function" then more = extra(m.id) end
            ChaseWorld.hud(m.id, hudPayload(match, m.id, now, more))
        end
    end
    match.lastHudMs = now
end
Chase.hudPayload = hudPayload

local function notifyAll(match, kind, text, ms)
    for _, m in ipairs(match.members) do
        if present(m) then ChaseWorld.notify(m.id, kind, text, ms) end
    end
end

-- ---------------------------------------------------------------- cars

local function removeCars(match)
    for role, car in pairs(match.cars or {}) do
        if car.id then ChaseWorld.removeCar(car.id) end
        match.cars[role] = nil
    end
end

local function createCars(match)
    removeCars(match)
    match.cars = {}
    if match.mode ~= "vehicle" or match.spawn == nil then return end
    for _, role in ipairs({ "runner", "cop" }) do
        local driver = roleId(match, role)
        local point = match.spawn[role]
        if driver and point then
            local id, recordOrReason = ChaseWorld.createCar(cfg().vehicles[role], Chase.carMark(point), match.bucket)
            if id then
                match.cars[role] = { id = id, record = recordOrReason, driver = driver }
            else
                log("match %d: %s car failed: %s", match.id, role, tostring(recordOrReason))
            end
        end
    end
end

-- Boarding readout: "your car is N m away" until the driver sits in it.
local function refreshBoarding(match, now)
    if match.mode ~= "vehicle" then return end
    if now - (match.lastSeatCheckMs or 0) < (cfg().vehicles.seatCheckMs or 1000) then return end
    match.lastSeatCheckMs = now
    for _, m in ipairs(match.members) do
        local car = match.cars and match.cars[match.roles[m.id]]
        m.boarding = nil
        if present(m) and car and car.id then
            local seat = ChaseWorld.seat(m.id)
            if seat == nil or tostring(seat) ~= tostring(car.id) then
                local p, c = ChaseWorld.position(m.id), ChaseWorld.carPosition(car.id)
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

-- Held on the marks during a countdown; every exit path lets go.
local function freezeAll(match, frozen)
    for _, m in ipairs(match.members) do
        if present(m) and (frozen or m.frozen) then
            m.frozen = frozen or nil
            ChaseWorld.freeze(m.id, frozen)
        end
    end
end

-- ---------------------------------------------------------------- rounds

local beginRound

local function finish(match, outcome, winner, now, detail)
    if match.state == "resolved" or match.state == "closed" then return end
    freezeAll(match, false)
    match.state = "resolved"
    match.outcome, match.resolvedAtMs = outcome, now
    local champion
    if FINAL[outcome] then champion = winner
    elseif Chase.roundCount(match) > 1 then
        local best, tied = -1, false
        for _, m in ipairs(match.members) do
            local s = match.score[m.id] or 0
            if s > best then best, champion, tied = s, m.id, false elseif s == best then tied = true end
        end
        if tied then champion = nil end
    else champion = winner end
    if match.void then champion = nil end
    match.champion, match.drawn = champion, champion == nil and not match.void
    match.releaseAtMs = now + math.floor((cfg().match.scoreboardSeconds or 5) * 1000)

    -- Remember the last sides so a rematch continues the alternation.
    local ids = {}
    for _, m in ipairs(match.members) do ids[#ids + 1] = m.id end
    if #ids == 2 then
        local roles = {}
        for id, role in pairs(match.roles) do roles[id] = role end
        Chase.pairings[pairKey(ids[1], ids[2])] = { roles = roles, atMs = now }
    end

    log("match %d resolved: %s (last round %s, winner %s) champion=%s score %s detail=%s", match.id, match.void and "VOID" or "played",
        tostring(outcome), tostring(winner), tostring(champion),
        table.concat((function() local s = {} for _, m in ipairs(match.members) do s[#s + 1] = m.id .. "=" .. (match.score[m.id] or 0) end return s end)(), " "),
        tostring(detail))

    pushAll(match, now, function(id)
        local won = champion ~= nil and id == champion
        return {
            state = "resolved", outcome = outcome, won = won, void = match.void or nil,
            matchResult = match.void and "void" or (match.drawn and "draw" or (won and "win" or "loss")),
            remainingMs = math.max(0, match.releaseAtMs - now),
        }
    end)
    for _, m in ipairs(match.members) do
        if present(m) then
            local text
            if match.void then
                text = match.voidReason or "The chase was called off. Nothing counts."
            else
                local won = champion ~= nil and m.id == champion
                local mine = match.score[m.id] or 0
                local other = opponent(match, m.id)
                local theirs = other and (match.score[other.id] or 0) or 0
                text = ChaseRules.line(outcome, won)
                if Chase.roundCount(match) > 1 and not FINAL[outcome] then
                    text = ("%s  %s %d-%d."):format(text, match.drawn and "Match drawn" or (won and "Match won" or "Match lost"), mine, theirs)
                end
            end
            ChaseWorld.notify(m.id, (m.id == champion or match.drawn) and "success" or "info", text, 6000)
        end
    end
    if Chase.onFinished then
        local ok, err = pcall(Chase.onFinished, match)
        if not ok then log("match %d: result hook failed: %s", match.id, tostring(err)) end
    end
end

-- Staff stop (or any unrecoverable state): nothing counts, everyone goes home.
function Chase.abort(match, now, reason)
    if match.state == "resolved" or match.state == "closed" then return false end
    match.void, match.voidReason = true, reason
    match.roundToken = (match.roundToken or 0) + 1
    finish(match, "aborted", nil, now, reason)
    return true
end

-- A round is over: score it, then the next round, a decider, or the end of the match.
function Chase.resolveRound(match, outcome, winnerRole, now, detail)
    if match.state ~= "countdown" and match.state ~= "active" and match.state ~= "placing" and match.state ~= "intermission" then return end
    local winner = winnerRole and roleId(match, winnerRole) or nil
    if match.state == "intermission" or (match.state == "placing" and match.round > 1) then
        -- Between rounds (or while moving to the next one) only a departure can happen;
        -- the round that just ended is already scored.
        match.roundToken = (match.roundToken or 0) + 1
        return finish(match, outcome, match.forfeitWinner or winner, now, detail)
    end
    local index = match.round
    if winner ~= nil and not FINAL[outcome] then match.score[winner] = (match.score[winner] or 0) + 1 end
    if match.state == "active" then
        local roles = {}
        for id, role in pairs(match.roles) do roles[id] = role end
        match.rounds[#match.rounds + 1] = { index = index, outcome = outcome, winner = winner, winnerRole = winnerRole,
            roles = roles, durationMs = match.chase and (now - match.chase.startedAtMs) or nil, detail = detail }
        match.played = (match.played or 0) + 1
    end
    log("match %d round %d/%d: %s winner=%s (%s)", match.id, index, Chase.roundCount(match), outcome, tostring(winner), tostring(detail))

    local final = FINAL[outcome] or not allPresent(match)
    local more = (not final) and index < Chase.roundCount(match)
    if not final and not more and not match.deciderAdded and tostring(cfg().match.tieBreak) == "decider" then
        local a, b = match.members[1], match.members[2]
        if a and b and (match.score[a.id] or 0) == (match.score[b.id] or 0) then
            match.deciderAdded, more = true, true
            log("match %d level after %d rounds: decider", match.id, index)
        end
    end
    if not more then return finish(match, outcome, winner, now, detail) end

    match.state = "intermission"
    match.intermissionEndsAtMs = now + math.floor((cfg().match.intermissionSeconds or 8) * 1000)
    match.roundToken = (match.roundToken or 0) + 1
    local nextIsDecider = match.deciderAdded and (index + 1) >= Chase.roundCount(match)
    pushAll(match, now, function(id)
        return { state = "intermission", outcome = outcome, won = winner ~= nil and id == winner,
            nextRound = index + 1, nextIsDecider = nextIsDecider or nil }
    end)
    for _, m in ipairs(match.members) do
        if present(m) then
            local won = winner ~= nil and m.id == winner
            local other = opponent(match, m.id)
            local mine, theirs = match.score[m.id] or 0, other and (match.score[other.id] or 0) or 0
            ChaseWorld.notify(m.id, won and "success" or "info", nextIsDecider
                and ("%s  Level at %d-%d - DECIDER. Roles swap."):format(ChaseRules.line(outcome, won), mine, theirs)
                or ("%s  %d-%d. Roles swap for round %d."):format(ChaseRules.line(outcome, won), mine, theirs, index + 1), 6000)
        end
    end
end

local function beginCountdown(match, now)
    createCars(match)
    -- Nobody gets a jump start: both are held on their marks until GO (a freeze is also
    -- released by death, a bucket change and this resource stopping).
    freezeAll(match, true)
    match.state = "countdown"
    match.countdownEndsAtMs = now + math.floor((cfg().match.countdownSeconds or 10) * 1000)
    local prefix = Chase.roundCount(match) > 1 and ("Round %d/%d - "):format(match.round, Chase.roundCount(match)) or ""
    local headStart = match.rules.headStartSeconds or 0
    for _, m in ipairs(match.members) do
        if present(m) then
            local role = match.roles[m.id]
            local text
            if role == "runner" then
                text = headStart > 0 and ("%sYou are the RUNNER. %ds head start. Hold a %.0f m gap to escape.")
                    :format(prefix, headStart, match.rules.escapeDistance)
                    or ("%sYou are the RUNNER. Hold a %.0f m gap to escape."):format(prefix, match.rules.escapeDistance)
            else
                text = headStart > 0 and ("%sYou are the COP. Hold for %ds, then pin him down."):format(prefix, headStart)
                    or ("%sYou are the COP. Stay on him and pin him down."):format(prefix)
            end
            if match.mode == "vehicle" then text = text .. " Your car is beside you: driver door on its LEFT." end
            ChaseWorld.notify(m.id, "info", text, 8000)
        end
    end
    pushAll(match, now)
end

local function beginActive(match, now)
    freezeAll(match, false)
    match.state = "active"
    match.chase = ChaseRules.newRound(match.rules, now)
    pushAll(match, now)
    for _, m in ipairs(match.members) do
        if present(m) then
            ChaseWorld.notify(m.id, "warning", match.roles[m.id] == "cop"
                and (match.chase.copReleased and "GO. Chase him down." or "Hold your position.")
                or "GO. Lose him.", 3000)
        end
    end
    log("match %d round %d active (%s, bucket %d)", match.id, match.round, match.mode, match.bucket)
end

beginRound = function(match, index, now)
    if index > 1 then
        -- The swap: hunting and being hunted are different games, a match has both.
        for _, m in ipairs(match.members) do
            match.roles[m.id] = match.roles[m.id] == "cop" and "runner" or "cop"
        end
    end
    match.round = index
    match.chase = nil
    match.state = "placing"
    match.placeDeadlineMs = now + math.floor((cfg().match.placeTimeoutSeconds or 40) * 1000)
    match.roundToken = (match.roundToken or 0) + 1
    match.spawn = Chase.spawnPair(match, index)
    if match.spawn == nil then
        match.void, match.voidReason = true, "No chase route is configured."
        return finish(match, "aborted", nil, now, "no spawn pair")
    end
    local token = match.roundToken
    local cover = index == 1 and { title = "NCPD Chase", subtitle = match.mode == "foot" and "On foot" or "Car chase",
        zone = "Chase instance" } or nil
    for _, m in ipairs(match.members) do
        m.placed, m.placeError, m.boarding = nil, nil, nil
        if present(m) then
            local point = match.spawn[match.roles[m.id]]
            m.placing = true
            ChaseWorld.place(m.id, lifted(point), match.bucket, function(ok, why)
                m.placing = nil
                Chase.onPlaced(match.id, m.id, token, ok, why)
            end, cover)
        end
    end
    pushAll(match, now, { state = "placing" })
end

function Chase.onPlaced(matchId, id, token, ok, why)
    local match = Chase.matches[matchId]
    if match == nil or match.roundToken ~= token or match.state ~= "placing" then return end
    local m = member(match, id)
    if m == nil then return end
    m.placed, m.placeError = ok == true, why
    if not ok then log("match %d: placement of %d failed: %s", match.id, id, tostring(why)) end
end

-- ---------------------------------------------------------------- admission

-- Two queued players become a match: identities, then Light RP takes them (activityEnter),
-- then the first round. Returns the match, or nil plus who failed and why.
function Chase.admit(a, b, mode, now)
    local bucket = allocateBucket()
    if bucket == nil then return nil, nil, "Every chase instance is busy. You stay in the queue." end
    local entered = {}
    for _, id in ipairs({ a, b }) do
        local ok, why = ChaseCore.enter(id)
        if not ok then
            for _, back in ipairs(entered) do ChaseCore.leave(back, { returnPlayer = true }) end
            return nil, id, why
        end
        entered[#entered + 1] = id
    end
    return Chase.start(a, b, mode, now, bucket)
end

function Chase.start(a, b, mode, now, bucket)
    bucket = bucket or allocateBucket()
    if bucket == nil then return nil, nil, "no_bucket" end
    if Chase.nextId == nil then Chase.nextId = now + 1 end
    local id = Chase.nextId
    Chase.nextId = Chase.nextId + 1
    mode = (mode == "foot") and "foot" or "vehicle"
    local match = { id = id, bucket = bucket, mode = mode, rules = Chase.rulesFor(mode), members = {}, roles = {},
        score = {}, rounds = {}, round = 0, state = "new", createdAtMs = now, cars = {} }
    for _, pid in ipairs({ a, b }) do
        local info = ChaseCore.player(pid) or {}
        match.members[#match.members + 1] = { id = pid, name = info.name or ChaseWorld.name(pid),
            identifier = info.identifier, characterKey = info.characterKey }
        match.score[pid] = 0
        Chase.playerMatch[pid] = id
    end
    -- First sides: a rematch inside ten minutes continues the alternation, otherwise the
    -- match id decides (deterministic, so a failure is reproducible).
    local previous = Chase.pairings[pairKey(a, b)]
    if previous and (now - previous.atMs) <= 600000 and previous.roles[a] and previous.roles[b] then
        match.roles[a] = previous.roles[a] == "cop" and "runner" or "cop"
        match.roles[b] = previous.roles[b] == "cop" and "runner" or "cop"
    else
        local first = (id % 2 == 0)
        match.roles[a] = first and "cop" or "runner"
        match.roles[b] = first and "runner" or "cop"
    end
    Chase.matches[id] = match
    Chase.bucketOwner[bucket] = id
    ChaseWorld.setupBucket(bucket)
    log("match %d created: %d=%s %d=%s bucket=%d mode=%s", id, a, match.roles[a], b, match.roles[b], bucket, mode)
    beginRound(match, 1, now)
    return match
end

-- ---------------------------------------------------------------- departures

-- The player asked to quit (hub, F1, /leave): he forfeits, goes home now; the other gets
-- the result beat, then goes home.
function Chase.leaveRequest(id, now)
    local match = Chase.matches[Chase.playerMatch[id] or -1]
    if match == nil then return false end
    local m = member(match, id)
    if m == nil or m.gone or m.released then return false end
    m.leaving = true
    m.releaseAtMs = now
    if match.state ~= "resolved" then
        local other = opponent(match, id)
        match.forfeitWinner = other and other.id or nil
        match.leaver = id
        Chase.resolveRound(match, "opponent_left", other and match.roles[other.id] or nil, now, ("player %d left"):format(id))
        if match.state ~= "resolved" then finish(match, "opponent_left", match.forfeitWinner, now, "left") end
    end
    return true
end

-- Light RP already released him (disconnect, character switch...): clean up, never leave.
function Chase.dropped(id, now, reason)
    local match = Chase.matches[Chase.playerMatch[id] or -1]
    Chase.playerMatch[id] = nil
    if match == nil then return false end
    local m = member(match, id)
    if m == nil then return false end
    m.gone = true
    if match.state ~= "resolved" and match.state ~= "closed" then
        local other = opponent(match, id)
        match.forfeitWinner = (other and not other.gone) and other.id or nil
        match.leaver = id
        Chase.resolveRound(match, "opponent_left", match.forfeitWinner and match.roles[match.forfeitWinner] or nil, now,
            ("player %d dropped (%s)"):format(id, tostring(reason)))
        if match.state ~= "resolved" then finish(match, "opponent_left", match.forfeitWinner, now, "dropped") end
    end
    return true
end

-- Light RP stopped: it has already released and returned every player it owned (contract),
-- so nobody is handed back; the matches are voided and the cars go on the next tick.
function Chase.coreStopped(now)
    for _, match in pairs(Chase.matches) do
        freezeAll(match, false)
        for _, m in ipairs(match.members) do
            if present(m) then ChaseWorld.hud(m.id, { state = "idle" }) end
            m.gone = true
            if Chase.playerMatch[m.id] == match.id then Chase.playerMatch[m.id] = nil end
        end
        match.void, match.voidReason = true, "Light RP restarted. Nothing counts."
        match.roundToken = (match.roundToken or 0) + 1
        finish(match, "aborted", nil, now, "op77_lightrp stopped")
    end
end

function Chase.matchOf(id)
    local match = Chase.matches[Chase.playerMatch[id] or -1]
    return match
end

-- ---------------------------------------------------------------- release

local function close(match)
    removeCars(match)
    ChaseWorld.sweepBucket(match.bucket)
    Chase.bucketOwner[match.bucket] = nil
    for _, m in ipairs(match.members) do
        if Chase.playerMatch[m.id] == match.id then Chase.playerMatch[m.id] = nil end
    end
    match.state = "closed"
    Chase.matches[match.id] = nil
    log("match %d closed", match.id)
end

-- One member home: out of the car, alive, then activityLeave (Light RP teleports him back).
local function releaseMember(match, m, now)
    if m.gone or m.released then return end
    if now < (m.releaseAtMs or match.releaseAtMs or now) then return end
    m.exitStartedMs = m.exitStartedMs or now
    -- A placement still in flight would land him back in the match bucket after Light RP
    -- took him home: let it settle first (the teleport gives up after 30 s).
    if m.placing and now - m.exitStartedMs < 35000 then return end
    local seat = ChaseWorld.seat(m.id)
    if seat ~= nil and now - m.exitStartedMs < 3000 then
        if not m.forcedOut then m.forcedOut = true; ChaseWorld.forceOut(m.id, seat) end
        return
    end
    if ChaseWorld.alive(m.id) == false then
        if not m.respawnAskedMs then
            m.respawnAskedMs = now
            ChaseWorld.respawnInPlace(m.id, match.bucket, match.spawn and match.spawn[match.roles[m.id]])
            return
        end
        if now - m.respawnAskedMs < 10000 then return end
    end
    m.released = true
    if m.frozen then m.frozen = nil; ChaseWorld.freeze(m.id, false) end
    if Chase.playerMatch[m.id] == match.id then Chase.playerMatch[m.id] = nil end
    ChaseWorld.hud(m.id, { state = "idle" })
    ChaseCore.leave(m.id, { returnPlayer = true })
end

-- ---------------------------------------------------------------- tick

local function sampleOf(match)
    local copId, runnerId = roleId(match, "cop"), roleId(match, "runner")
    local sample = {
        copDown = copId ~= nil and ChaseWorld.alive(copId) == false,
        runnerDown = runnerId ~= nil and ChaseWorld.alive(runnerId) == false,
    }
    if copId == nil or runnerId == nil then return sample end
    local cop, runner = ChaseWorld.position(copId), ChaseWorld.position(runnerId)
    if cop == nil or runner == nil then return sample end
    -- Mid-transfer one of them still reports the old dimension: no distance across buckets.
    if (cop.bucket ~= nil and cop.bucket ~= match.bucket) or (runner.bucket ~= nil and runner.bucket ~= match.bucket) then return sample end
    local dx, dy, dz = cop.x - runner.x, cop.y - runner.y, (cop.z or 0) - (runner.z or 0)
    sample.sep = math.sqrt(dx * dx + dy * dy + dz * dz)
    sample.copPos, sample.runnerPos = cop, runner
    return sample
end

local function tickActive(match, now)
    refreshBoarding(match, now)
    local outcome, events = ChaseRules.step(match.chase, match.rules, now, sampleOf(match))
    local copId, runnerId = roleId(match, "cop"), roleId(match, "runner")
    for _, e in ipairs(events or {}) do
        if e.kind == "released" then
            if copId then ChaseWorld.notify(copId, "warning", "Released. Go.", 4000) end
            if runnerId then ChaseWorld.notify(runnerId, "warning", "The cop is moving.", 4000) end
        elseif e.kind == "escape_started" then
            if runnerId then ChaseWorld.notify(runnerId, "warning", ("You're past %.0f m - keep the gap for %.0f s to escape.")
                :format(match.rules.escapeDistance, match.rules.escapeGraceSeconds or 0), 4000) end
            if copId then ChaseWorld.notify(copId, "warning", ("He's past %.0f m - close the gap or lose him.")
                :format(match.rules.escapeDistance), 4000) end
        elseif e.kind == "overtime" then
            notifyAll(match, "warning", "Overtime - the attempt in play decides it.", 4000)
        elseif e.kind == "crash" then
            local id = roleId(match, e.role)
            if id then ChaseWorld.notify(id, "warning", ("Crash! Engine stalled - %.0fs."):format(match.rules.crashStallSeconds or 0), 3000) end
        end
    end
    if outcome then
        return Chase.resolveRound(match, outcome.outcome, outcome.winner, now, outcome.detail)
    end
    if now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
end

function Chase.tickMatch(match, now)
    local state = match.state
    if state == "placing" then
        local done, failed = true, nil
        for _, m in ipairs(match.members) do
            if present(m) then
                if m.placed == false then failed = m
                elseif m.placed ~= true then done = false end
            end
        end
        if failed or (not done and now >= match.placeDeadlineMs) then
            -- Nobody's fault we can prove: the match is void (no rating, no reputation).
            match.void, match.voidReason = true, "The chase area did not load. Nothing counts."
            local why = failed and ("placement of %d failed: %s"):format(failed.id, tostring(failed.placeError)) or "placement timed out"
            return finish(match, "aborted", nil, now, why)
        end
        if done then beginCountdown(match, now) end
    elseif state == "countdown" then
        refreshBoarding(match, now)
        if now >= match.countdownEndsAtMs then beginActive(match, now)
        elseif now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
    elseif state == "active" then
        tickActive(match, now)
    elseif state == "intermission" then
        if now >= match.intermissionEndsAtMs then beginRound(match, match.round + 1, now) end
    elseif state == "resolved" then
        local pending = false
        for _, m in ipairs(match.members) do
            releaseMember(match, m, now)
            if not m.gone and not m.released then pending = true end
        end
        if not pending then close(match) end
    end
end

function Chase.tick(now)
    local ids = {}
    for id in pairs(Chase.matches) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local match = Chase.matches[id]
        if match then
            local ok, err = pcall(Chase.tickMatch, match, now)
            if not ok then log("match %d tick error: %s", id, tostring(err)) end
        end
    end
end

-- The resource is stopping: Light RP returns the players itself (contract); remove the cars.
function Chase.shutdown()
    for _, match in pairs(Chase.matches) do
        freezeAll(match, false)
        removeCars(match)
    end
end

-- For the hub: idle / lobby / running, with counters.
function Chase.status(queued)
    local running, players = 0, 0
    for _, match in pairs(Chase.matches) do
        if match.state ~= "closed" then
            running = running + 1
            for _, m in ipairs(match.members) do if present(m) then players = players + 1 end end
        end
    end
    local free = allocateBucket() ~= nil
    local phase = running > 0 and "running" or (queued > 0 and "lobby" or "idle")
    local parts = {}
    if queued > 0 then parts[#parts + 1] = ("%d waiting"):format(queued) end
    if running > 0 then parts[#parts + 1] = ("%d chase%s on"):format(running, running > 1 and "s" or "") end
    return { phase = phase, players = players, queued = queued, joinable = free,
        detail = #parts > 0 and table.concat(parts, " · ") or "Cop vs runner, 1v1. Queue and keep playing." }
end
