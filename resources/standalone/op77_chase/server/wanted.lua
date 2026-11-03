-- op77_chase Most Wanted lifecycle: from "a lobby of players" to "everyone handed back to
-- Light RP", one runner turn per player.
--
--   placing -> countdown -> active -> intermission -> placing -> ... -> resolved -> closed
--
-- Like the 1v1 (server/match.lua), everything is driven by ChaseWanted.tick(now): only
-- placements are asynchronous (ChaseWanted.onPlaced). Natives go through ChaseWorld,
-- the activity contract through ChaseCore (activity id chase.wanted), the rules through
-- WantedRules, so tests/wanted_test.lua runs the whole flow against fakes.
--
-- A round: by car the runner stands by his car at the front of the cops' start grid and
-- the whole NCPD leaves with him at GO (on foot he starts ~300 m down the road with a
-- head start, and the cops are released when it ends). Dispatch sightings,
-- heat levels, roadblocks and a late extraction point make the round; it ends on an
-- arrest, a takedown, the clock or the extraction. Then the next runner, until everyone
-- has run once (drop-ins join at the next round and get their turn at the end).
--
-- Crews (Light RP squads): the lobby never splits one (wanted_lobby.lua), and the cops of
-- a crew line up side by side and roll out in the same wave (crewOrder).
--
-- Staff bot mode (server/bots.lua): one queued player is enough, bots fill the match up to
-- ChaseConfig.bots.wanted.players and take their turn as runner like everyone else. A bot
-- cop chases the runner once dispatch releases it (and is dispatched again on the road
-- behind the runner when it falls far back); a bot runner drives the course, heads for the
-- extraction once it shows up, and gives up when the unit pins it. Nothing is recorded
-- (results are marked test, no reputation) and the bots go with the match.
ChaseWanted = { matches = {}, playerMatch = {}, bucketOwner = {}, nextId = nil, testMode = false, daily = {} }
local M = ChaseWanted
local R = WantedRules
local HOLD = { kind = "hold" }

local function isBot(id) return ChaseBots ~= nil and ChaseBots.isBot(id) end
local function squadId(s) if type(s) == "table" then return s.id end return s end

local function cfg() return ChaseConfig.wanted end
local function aid() return cfg().activity.id end
local function log(fmt, ...) print(("[op77_chase] wanted " .. fmt):format(...)) end
local function W() return ChaseWorld end

local function notify(id, kind, text, ms) W().notify(id, kind, text, ms, "Most Wanted") end

-- Deterministic per match, so a failure is reproducible (and tests can predict it).
local function random(match)
    match.seed = (match.seed * 1103515245 + 12345) % 2147483648
    return match.seed / 2147483648
end

-- ---------------------------------------------------------------- members

local function member(match, id)
    for _, m in ipairs(match.members) do if m.id == id then return m end end
    return nil
end
M.member = member

local function present(m) return not m.gone and not m.released and not m.leaving end

local function presentList(match)
    local list = {}
    for _, m in ipairs(match.members) do if present(m) then list[#list + 1] = m end end
    return list
end
local function presentCount(match) return #presentList(match) end

local function humanCount(match)
    local n = 0
    for _, m in ipairs(match.members) do if present(m) and not m.bot then n = n + 1 end end
    return n
end

-- Members of one crew next to each other (first appearance keeps its place): side by
-- side on the grid and in the same dispatch wave.
local function crewOrder(list)
    local out, seen = {}, {}
    for i, m in ipairs(list) do
        if not seen[i] then
            seen[i] = true
            out[#out + 1] = m
            if m.squad ~= nil then
                for j = i + 1, #list do
                    if not seen[j] and list[j].squad == m.squad then
                        seen[j] = true
                        out[#out + 1] = list[j]
                    end
                end
            end
        end
    end
    return out
end
M.crewOrder = crewOrder

local function name(match, id)
    local m = member(match, id)
    return m and m.name or W().name(id)
end

function M.minPlayers()
    -- Staff bot mode, where config.bots.fill allows it (off by default: real players only).
    if ChaseBots and ChaseBots.fills(cfg().activity.id) then return 1 end
    return M.testMode and math.max(2, cfg().testMinPlayers or 2) or math.max(2, cfg().minPlayers or 3)
end

-- ---------------------------------------------------------------- marks

local function routeFor(match, round)
    local routes = cfg().routes
    return routes[((match.id + round - 2) % #routes) + 1]
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
    if match.roles[m.id] == "runner" and match.mode == "foot" then return onMark(m.point) end
    return besideMark(m.point)
end

-- ---------------------------------------------------------------- cars and roadblocks

local function removeCar(match, id)
    local car = match.cars[id]
    if car and car.id then W().removeCar(car.id) end
    match.cars[id] = nil
end

local function removeCars(match)
    for id in pairs(match.cars) do removeCar(match, id) end
end

local function createCar(match, id)
    local m = member(match, id)
    if not m or not m.point then return end
    local role = match.roles[id]
    if role == "runner" and match.mode == "foot" then return end
    removeCar(match, id)
    local mark = carMark(m.point)
    local carId, recordOrReason = W().createCar(cfg().vehicles[role], mark, match.bucket)
    if carId then
        match.cars[id] = { id = carId, record = recordOrReason }
        if m.bot then ChaseBots.mount(id, carId, mark.yaw) end
    else log("match %d: %s car for %d failed: %s", match.id, tostring(role), id, tostring(recordOrReason)) end
end

local function clearBlocks(match)
    for _, block in ipairs(match.blocks) do
        for _, carId in ipairs(block.cars) do W().removeCar(carId) end
    end
    match.blocks = {}
end

local function expireBlocks(match, now)
    for i = #match.blocks, 1, -1 do
        local block = match.blocks[i]
        if now >= block.expiresAtMs then
            for _, carId in ipairs(block.cars) do W().removeCar(carId) end
            table.remove(match.blocks, i)
        end
    end
end

-- Boarding readout: "your car is N m away" until the driver sits in it.
local function refreshBoarding(match, now)
    if now - (match.lastSeatCheckMs or 0) < (ChaseConfig.vehicles.seatCheckMs or 1000) then return end
    match.lastSeatCheckMs = now
    for _, m in ipairs(match.members) do
        local car = match.cars[m.id]
        m.boarding = nil
        if present(m) and car and car.id and not m.respawning then
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

-- ---------------------------------------------------------------- HUD

local function scoreboard(match, selfId)
    local ids = {}
    for _, m in ipairs(match.members) do if not m.gone then ids[#ids + 1] = m.id end end
    local rows = {}
    for _, row in ipairs(R.standings(match, ids)) do
        local s = row.stats
        rows[#rows + 1] = { id = row.id, name = name(match, row.id), points = s.points, runnerMs = s.runnerMs,
            arrests = s.arrests, assists = s.assists, placement = row.placement, self = row.id == selfId or nil,
            runner = row.id == match.runnerId or nil, left = (member(match, row.id) or {}).leaving or nil }
        if #rows >= 16 then break end
    end
    return rows
end

local function roundCount(match)
    return math.min(cfg().maxRounds or 8, #match.order + #match.pending)
end
M.roundCount = roundCount

local function hudPayload(match, id, now, extra)
    local m = member(match, id)
    local role = match.roles[id]
    local round = match.chase
    local s = R.stats(match, id)
    local p = {
        activity = aid(), matchId = match.id, state = match.state, mode = match.mode, role = role,
        round = match.round, roundCount = roundCount(match),
        runnerName = match.runnerId and name(match, match.runnerId) or nil,
        points = s.points, scoreboard = scoreboard(match, id),
    }
    if match.state == "countdown" then
        p.remainingMs = math.max(0, (match.countdownEndsAtMs or now) - now)
        p.headStartMs = math.floor((match.rules.headStartSeconds or 0) * 1000)
    elseif match.state == "active" and round then
        local heat = match.rules.heat
        p.remainingMs = math.max(0, round.endsAtMs - now)
        p.overtime = round.overtime or nil
        p.heat, p.heatCount = round.heat, #heat
        p.heatProgress = R.heatProgress(heat, now - round.startedAtMs)
        p.bustMeter = round.bustMeter or 0.0
        p.bustClosing = round.bustClosing or nil
        p.bustContact = round.bustContact or nil
        p.closing = round.closing or 0
        p.escapeProgress = (round.escapeMeter or 0) > 0 and math.min(1.0, round.escapeMeter) or nil
        p.stalledMs = ChaseRules.stallRemaining(round, role == "runner" and "runner" or id, now)
        if role == "runner" then
            p.copsNearby = round.copsNearby or 0
            p.nearestCop = round.nearest and math.floor(round.nearest + 0.5) or nil
            p.spotted = match.lastTimedScanAtMs ~= nil and (now - match.lastTimedScanAtMs) < 3000 or nil
            if match.extraction then
                p.extraction = match.extraction.position
                p.extractionRadius = match.extraction.radius
                local rp = W().position(id)
                if rp then p.extractionDistance = math.floor(R.planar(rp, match.extraction.position) + 0.5) end
            end
        else
            local releaseAt = match.releaseAt[id]
            p.released = match.copReleased[id] == true
            if not p.released and releaseAt then p.heldMs = math.max(0, releaseAt - now) end
            p.targetDistance = R.coarseDistance(round.copDistance[id])
            if match.sighting then
                p.sighting = { x = match.sighting.position.x, y = match.sighting.position.y, z = match.sighting.position.z,
                    radius = match.sighting.radius, ageMs = now - match.sighting.atMs }
            end
            if match.extraction and match.extractionCopAtMs and now >= match.extractionCopAtMs then
                p.extraction = match.extraction.position
                p.extractionRadius = match.extraction.radius
            end
            p.respawning = m and m.respawning or nil
        end
    elseif match.state == "intermission" then
        p.remainingMs = math.max(0, (match.intermissionEndsAtMs or now) - now)
    elseif match.state == "resolved" then
        p.remainingMs = math.max(0, (match.releaseAtMs or now) - now)
        p.void = match.void or nil
    end
    if m and m.boarding and (match.state == "countdown" or match.state == "active") then p.boarding = m.boarding end
    if role == "cop" and match.runnerId and match.runnerId > 0 and (ChaseConfig.minimap or {}).hideRunnerFromCops ~= false then
        p.hideDots = { match.runnerId }
    end
    if extra then
        local more = type(extra) == "function" and extra(id) or extra
        for k, v in pairs(more or {}) do p[k] = v end
    end
    return p
end
M.hudPayload = hudPayload

local function pushAll(match, now, extra)
    for _, m in ipairs(match.members) do
        if present(m) then W().hud(m.id, hudPayload(match, m.id, now, extra)) end
    end
    match.lastHudMs = now
end

local function notifyRole(match, role, kind, text, ms)
    for _, m in ipairs(match.members) do
        if present(m) and match.roles[m.id] == role then notify(m.id, kind, text, ms) end
    end
end

local function notifyAll(match, kind, text, ms)
    for _, m in ipairs(match.members) do if present(m) then notify(m.id, kind, text, ms) end end
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

function M.reputation(match, m, placement)
    local rep = cfg().reputation
    if match.void or (match.played or 0) == 0 or match.hasBots then return 0 end
    if m.leaving or m.forfeit then return rep.leaver or 0 end
    if (match.peakPlayers or 0) < (rep.minPlayers or 3) then return 0 end
    local day = dayOf()
    if M.dailyDay ~= day then M.daily, M.dailyDay = {}, day end -- yesterday's counts go
    local key = ("%d|%s"):format(day, characterId(m))
    local count = (M.daily[key] or 0) + 1
    M.daily[key] = count
    if count > (rep.perDay or 6) then return 0 end
    return (rep.byPlacement or {})[placement] or rep.other or 0
end

local function resultFor(match, m, placement)
    local s = R.stats(match, m.id)
    return {
        placement = placement,
        score = s.points,
        won = placement == 1 and not m.forfeit,
        stats = { mode = match.mode, rounds = match.played or 0, points = s.points, runnerMs = s.runnerMs,
            runnerRounds = s.runnerRounds, copRounds = s.copRounds, arrests = s.arrests, assists = s.assists,
            takedowns = s.takedowns, extractions = s.extractions, survivals = s.survivals, shakes = s.shakes,
            busted = s.busted, players = match.peakPlayers, forfeit = m.forfeit or nil, bots = match.hasBots or nil },
        reputation = M.reputation(match, m, placement),
        -- With bots (staff bot mode) Light RP never records it, even if bot mode went off meanwhile.
        test = match.hasBots or nil,
        recap = ChaseRecap and ChaseRecap.safe("wanted", match) or nil, -- Light RP's end-of-match recap (recap.lua)
    }
end

-- ---------------------------------------------------------------- the match

local beginRound, finish

local function nextTurn(match)
    local turn = match.turn
    while turn <= #match.order do
        local m = member(match, match.order[turn])
        if m and present(m) then return match.order[turn], turn end
        turn = turn + 1
    end
    return nil
end

local function hasMore(match)
    if presentCount(match) + #match.pending < 2 then return false end
    if humanCount(match) + #match.pending == 0 then return false end
    if nextTurn(match) then return true end
    return #match.pending > 0 and #match.order < (cfg().maxRounds or 8)
end

finish = function(match, now, reason)
    if match.state == "resolved" or match.state == "closed" then return end
    freezeAll(match, false)
    clearBlocks(match)
    match.chase = nil
    match.state = "resolved"
    match.resolvedAtMs = now
    match.releaseAtMs = now + math.floor((cfg().match.scoreboardSeconds or 10) * 1000)
    if (match.played or 0) == 0 then match.void = true end
    -- Pending drop-ins never got in: back to the queue.
    for _, pending in ipairs(match.pending) do
        if M.onBounce then M.onBounce(pending.id, "The Most Wanted match you were joining is over.") end
    end
    match.pending = {}
    local ranked = {}
    for _, m in ipairs(presentList(match)) do ranked[#ranked + 1] = m.id end
    match.standings = R.standings(match, ranked)
    log("match %d resolved (%s)%s after %d round(s): %s", match.id, tostring(reason), match.void and " VOID" or "",
        match.played or 0, table.concat((function()
            local parts = {}
            for _, row in ipairs(match.standings) do parts[#parts + 1] = ("%d=%d"):format(row.id, row.points) end
            return parts
        end)(), " "))
    local placements = {}
    for _, row in ipairs(match.standings) do placements[row.id] = row.placement end
    if not match.void then
        for _, row in ipairs(match.standings) do
            local m = member(match, row.id)
            if not m.bot then ChaseCore.result(row.id, resultFor(match, m, row.placement), aid()) end
        end
    end
    pushAll(match, now, function(id)
        return { state = "resolved", placement = placements[id], total = #match.standings, void = match.void or nil,
            reason = match.voidReason }
    end)
    for _, m in ipairs(presentList(match)) do
        if match.void then
            notify(m.id, "info", match.voidReason or "Most Wanted was called off. Nothing counts.", 6000)
        else
            local s = R.stats(match, m.id)
            notify(m.id, placements[m.id] == 1 and "success" or "info",
                ("Most Wanted over: #%d of %d with %d points."):format(placements[m.id] or 0, #match.standings, s.points), 6000)
        end
    end
end

function M.abort(match, now, reason)
    if match.state == "resolved" or match.state == "closed" then return false end
    match.void, match.voidReason = true, reason
    match.token = (match.token or 0) + 1
    finish(match, now, reason)
    return true
end

local function admitPending(match, now)
    local list = match.pending
    match.pending = {}
    for _, entry in ipairs(list) do
        local id = entry.id
        if #match.order >= (cfg().maxRounds or 8) or presentCount(match) >= (cfg().maxPlayers or 8) then
            if M.onBounce then M.onBounce(id, "That Most Wanted match filled up. You stay in the queue.") end
        else
            local ok, why = ChaseCore.enter(id, aid())
            if ok then
                local info = ChaseCore.player(id) or {}
                match.members[#match.members + 1] = { id = id, name = info.name or W().name(id),
                    identifier = info.identifier, characterKey = info.characterKey, joinedRound = match.round + 1, squad = entry.squad }
                match.order[#match.order + 1] = id
                M.playerMatch[id] = match.id
                R.stats(match, id)
                log("match %d: %d joined for round %d", match.id, id, match.round + 1)
            else
                notify(id, "warning", ("You could not join Most Wanted: %s"):format(tostring(why)), 6000)
                if M.onRefused then M.onRefused(id) end
            end
        end
    end
end

beginRound = function(match, now)
    admitPending(match, now)
    if presentCount(match) < 2 or humanCount(match) == 0 then return finish(match, now, "not enough players") end
    local runnerId, turn = nextTurn(match)
    if runnerId == nil then return finish(match, now, "rotation complete") end
    match.turn = turn
    match.round = match.round + 1
    match.runnerId = runnerId
    match.chase = nil
    match.state = "placing"
    match.placeDeadlineMs = now + math.floor((cfg().match.placeTimeoutSeconds or 40) * 1000)
    match.token = (match.token or 0) + 1
    removeCars(match)
    clearBlocks(match)
    match.route = routeFor(match, match.round)
    match.roles, match.releaseAt, match.copReleased = {}, {}, {}
    match.sighting, match.lastScanAtMs, match.lastTimedScanAtMs = nil, nil, nil
    match.extraction, match.extractionCopAtMs, match.extractionCopsTold, match.extractionMissed = nil, nil, nil, nil
    match.nextBlockAtMs = nil
    match.trail = {}
    local players = crewOrder(presentList(match))
    match.peakPlayers = math.max(match.peakPlayers or 0, #players)
    local slot = 0
    local token = match.token
    for _, m in ipairs(players) do
        m.placed, m.placeError, m.boarding, m.downSinceMs, m.respawning = nil, nil, nil, nil, nil
        if m.id == runnerId then
            match.roles[m.id] = "runner"
            -- By car he starts at the front of the cops' grid and they leave together.
            m.point = (match.mode ~= "foot" and match.route.runnerCar) or match.route.runner
        else
            slot = slot + 1
            match.roles[m.id] = "cop"
            -- From the front of the grid (slot 8 is the front): by car the first cop is
            -- the closest to the runner, ~27 m behind him, however few cops there are.
            m.point = match.route.cops[math.max(1, #match.route.cops - slot + 1)]
        end
        if m.bot then
            ChaseBots.assign(m.id, match.roles[m.id], (match.roles[m.id] == "runner" and match.mode == "foot") and "foot" or "vehicle")
        end
        local cover = nil
        if not m.covered then
            m.covered = true
            cover = { title = "Most Wanted", subtitle = match.mode == "foot" and "Runner on foot" or "Car chase", zone = "Chase instance" }
        end
        m.placing = true
        W().place(m.id, markFor(match, m), match.bucket, function(ok, why)
            m.placing = nil
            M.onPlaced(match.id, m.id, token, ok, why)
        end, cover)
    end
    log("match %d round %d/%d: runner %d, %d cop(s), route %s", match.id, match.round, roundCount(match), runnerId, slot,
        match.route.name)
    pushAll(match, now, { state = "placing" })
end

function M.onPlaced(matchId, id, token, ok, why)
    local match = M.matches[matchId]
    if match == nil or match.token ~= token or match.state ~= "placing" then return end
    local m = member(match, id)
    if m == nil then return end
    m.placed, m.placeError = ok == true, why
    if not ok then log("match %d: placement of %d failed: %s", match.id, id, tostring(why)) end
end

local function beginCountdown(match, now)
    for _, m in ipairs(presentList(match)) do createCar(match, m.id) end
    freezeAll(match, true)
    match.state = "countdown"
    match.countdownEndsAtMs = now + math.floor((cfg().match.countdownSeconds or 10) * 1000)
    local runnerName = name(match, match.runnerId)
    local headStart = match.rules.headStartSeconds or 0
    for _, m in ipairs(presentList(match)) do
        local text
        if match.roles[m.id] == "runner" then
            local lead = headStart > 0 and ("%ds head start."):format(headStart)
                or "The NCPD is right behind you and leaves with you."
            text = ("Round %d/%d - YOU ARE THE RUNNER. %s Survive %s or reach the extraction when it shows up.")
                :format(match.round, roundCount(match), lead, ("%d:%02d"):format(match.rules.durationSeconds // 60,
                    match.rules.durationSeconds % 60))
            if match.mode == "vehicle" then text = text .. " Your car is beside you: driver door on its LEFT." end
        else
            text = ("Round %d/%d - NCPD. The runner is %s. %s, then box him in: several cops cuff faster.")
                :format(match.round, roundCount(match), runnerName,
                    headStart > 0 and "Wait for dispatch" or "He is in front of the grid: go at GO")
            text = text .. " Your car is beside you: driver door on its LEFT."
        end
        notify(m.id, "info", text, 8000)
    end
    pushAll(match, now)
end

local function copIds(match)
    local list = {}
    for _, m in ipairs(crewOrder(presentList(match))) do
        if match.roles[m.id] == "cop" then list[#list + 1] = m.id end
    end
    return list
end

local function beginActive(match, now)
    match.state = "active"
    match.chase = R.newRound(match.rules, now)
    local headStartMs = math.floor((match.rules.headStartSeconds or 0) * 1000)
    local plan = R.wavePlan(copIds(match), match.rules.heat, headStartMs)
    for id, at in pairs(plan) do match.releaseAt[id] = now + at end
    local runner = member(match, match.runnerId)
    if runner then freeze(runner, false) end
    notify(match.runnerId, "warning", "GO. Lose them.", 3000)
    for id, at in pairs(plan) do
        -- Released at GO (no head start): the release itself says "you're up".
        if at > 0 then notify(id, "warning", ("Hold - dispatch releases you in %ds."):format(math.ceil(at / 1000)), 3000) end
    end
    pushAll(match, now)
    log("match %d round %d active (%s, bucket %d)", match.id, match.round, match.mode, match.bucket)
end

function M.resolveRound(match, outcome, now)
    if match.state ~= "active" and match.state ~= "placing" and match.state ~= "countdown" then return end
    local round = match.chase
    local record = {
        index = match.round, runnerId = match.runnerId, copIds = copIds(match), outcome = outcome.outcome,
        arrestBy = outcome.arrestBy, assists = outcome.assists, takedownBy = outcome.takedownBy,
        survivedMs = round and math.max(0, math.min(now, round.endsAtMs) - round.startedAtMs) or 0,
        shakes = round and round.shakes or 0, detail = outcome.detail,
    }
    if outcome.outcome == "time_expired" and round then record.survivedMs = round.endsAtMs - round.startedAtMs end
    record.gained = R.score(match, record)
    match.rounds[#match.rounds + 1] = record
    if outcome.outcome ~= "runner_left" then match.played = (match.played or 0) + 1 end
    match.lastRound = record
    log("match %d round %d: %s (runner %d, %.0fs) %s", match.id, match.round, tostring(outcome.outcome), match.runnerId,
        record.survivedMs / 1000, tostring(outcome.detail))
    clearBlocks(match)
    freezeAll(match, false)
    match.chase = nil
    match.turn = match.turn + 1
    local summary = { outcome = record.outcome, runnerName = name(match, record.runnerId), survivedMs = record.survivedMs,
        arrestByName = record.arrestBy and name(match, record.arrestBy) or nil,
        takedownByName = record.takedownBy and name(match, record.takedownBy) or nil, shakes = record.shakes }
    match.lastSummary = summary
    if not hasMore(match) then return finish(match, now, "rotation complete") end
    match.state = "intermission"
    match.intermissionEndsAtMs = now + math.floor((cfg().match.intermissionSeconds or 10) * 1000)
    local nextId = nextTurn(match)
    local nextName = nextId and name(match, nextId) or "a new player"
    pushAll(match, now, function(id)
        return { state = "intermission", lastRound = summary, gained = record.gained[id] or 0,
            wasRunner = id == record.runnerId or nil, nextRunnerName = nextName, nextIsYou = id == nextId or nil }
    end)
    for _, m in ipairs(presentList(match)) do
        local role = m.id == record.runnerId and "runner" or "cop"
        local line, title = R.line(record.outcome, role)
        local gained = record.gained[m.id] or 0
        notify(m.id, gained > 0 and "success" or "info", ("%s - %s +%d. Next runner: %s."):format(title, line, gained,
            m.id == nextId and "YOU" or nextName), 6000)
    end
end

-- ---------------------------------------------------------------- admission

local function allocateBucket()
    local b = cfg().buckets
    for bucket = b.from, b.to do
        if M.bucketOwner[bucket] == nil then return bucket end
    end
    return nil
end
M.allocateBucket = allocateBucket

-- A lobby becomes a match: Light RP takes each player (activityEnter). Those refused are
-- reported; if fewer than the minimum entered, the ones who did are handed back.
-- Returns match | nil, reason, refused = { { id, why } }.
-- opts = { min, squads = { [id] = squadId }, fill = total with bots (staff bot mode) }.
function M.admit(ids, mode, now, opts)
    opts = opts or {}
    local bucket = allocateBucket()
    if bucket == nil then return nil, "busy", {} end
    local entered, refused = {}, {}
    for _, id in ipairs(ids) do
        local ok, why = ChaseCore.enter(id, aid())
        if ok then entered[#entered + 1] = id else refused[#refused + 1] = { id = id, why = why } end
    end
    if #entered == 0 or #entered < (opts.min or M.minPlayers()) then
        for _, id in ipairs(entered) do ChaseCore.leave(id, { returnPlayer = true }, aid()) end
        return nil, "short", refused, entered
    end
    return M.start(entered, mode, now, bucket, opts), nil, refused
end

function M.start(ids, mode, now, bucket, opts)
    opts = opts or {}
    bucket = bucket or allocateBucket()
    if bucket == nil then return nil end
    -- Staff bot mode: bots fill up to opts.fill (they are members like the players).
    local bots = 0
    if ChaseBots and (opts.fill or 0) > #ids then
        local list = {}
        for _, pid in ipairs(ids) do list[#list + 1] = pid end
        for _ = #ids + 1, math.min(opts.fill, cfg().maxPlayers or 8) do
            list[#list + 1] = ChaseBots.create({ bucket = bucket, admission = ids[1], owner = aid() })
            bots = bots + 1
        end
        ids = list
    end
    if M.nextId == nil then M.nextId = now + 1 end
    local id = M.nextId
    M.nextId = M.nextId + 1
    mode = mode == "foot" and "foot" or "vehicle"
    local match = { id = id, bucket = bucket, mode = mode, rules = R.rulesFor(mode), members = {}, order = {}, pending = {},
        roles = {}, releaseAt = {}, copReleased = {}, stats = {}, rounds = {}, cars = {}, blocks = {},
        round = 0, turn = 1, played = 0, state = "new", createdAtMs = now, seed = (id % 2147483647) + 1 }
    for _, pid in ipairs(ids) do
        local info = ChaseCore.player(pid) or {}
        local bot = isBot(pid) or nil
        match.members[#match.members + 1] = { id = pid, name = info.name or W().name(pid),
            identifier = (not bot) and info.identifier or nil, characterKey = (not bot) and info.characterKey or nil,
            joinedRound = 1, bot = bot, squad = squadId(opts.squads and opts.squads[pid]) }
        match.order[#match.order + 1] = pid
        R.stats(match, pid)
        if bot then match.hasBots = true else M.playerMatch[pid] = id end
    end
    M.matches[id] = match
    M.bucketOwner[bucket] = id
    W().setupBucket(bucket)
    log("match %d created: %d players%s, %s, bucket %d", id, #ids, bots > 0 and (" (%d bots)"):format(bots) or "", mode, bucket)
    beginRound(match, now)
    return match
end

-- Drop-ins: a running match with a free seat and a free runner turn takes queued players
-- at its next round.
function M.dropInSeats(match)
    if match.state == "resolved" or match.state == "closed" or match.state == "new" then return 0 end
    -- A bot match takes players only while bot mode is on (nothing is recorded in it).
    if match.hasBots and not (ChaseBots and ChaseBots.fills(cfg().activity.id)) then return 0 end
    local seats = (cfg().maxPlayers or 8) - presentCount(match) - #match.pending
    local turns = (cfg().maxRounds or 8) - #match.order - #match.pending
    return math.max(0, math.min(seats, turns))
end

function M.offer(match, id, squad)
    match.pending[#match.pending + 1] = { id = id, squad = squadId(squad) }
    M.playerMatch[id] = nil
end

function M.pendingMatch(id)
    for _, match in pairs(M.matches) do
        for _, entry in ipairs(match.pending) do if entry.id == id then return match end end
    end
    return nil
end

function M.cancelPending(id)
    for _, match in pairs(M.matches) do
        for i, entry in ipairs(match.pending) do
            if entry.id == id then table.remove(match.pending, i); return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------- departures

local function onDeparture(match, id, now, why)
    removeCar(match, id)
    if match.state == "resolved" or match.state == "closed" or match.state == "new" then return end
    if presentCount(match) < 2 or humanCount(match) == 0 then return finish(match, now, why) end
    if id ~= match.runnerId then return end
    if match.state == "active" then
        return M.resolveRound(match, { outcome = "runner_left", detail = why }, now)
    end
    if match.state == "placing" or match.state == "countdown" then
        -- The round never started: the next runner takes it.
        freezeAll(match, false)
        match.round = match.round - 1
        match.turn = match.turn + 1
        return beginRound(match, now)
    end
end

-- The player asked to quit (hub, /wanted leave): he goes home now, the match goes on.
function M.leaveRequest(id, now)
    if M.cancelPending(id) then return true end
    local match = M.matches[M.playerMatch[id] or -1]
    if match == nil then return false end
    local m = member(match, id)
    if m == nil or m.gone or m.released or m.leaving then return false end
    if match.state ~= "resolved" and not match.void and (match.played or 0) > 0 then
        -- His result now, as the last of the table, no reputation.
        m.forfeit = true
        local count = 0
        for _, other in ipairs(match.members) do if not other.gone then count = count + 1 end end
        ChaseCore.result(id, resultFor(match, m, count), aid())
    end
    m.leaving = true
    m.releaseAtMs = now
    freeze(m, false)
    onDeparture(match, id, now, ("player %d left"):format(id))
    return true
end

-- Light RP already released him: clean up, never activityLeave, no result.
function M.dropped(id, now, reason)
    if M.cancelPending(id) then return true end
    local match = M.matches[M.playerMatch[id] or -1]
    M.playerMatch[id] = nil
    if match == nil then return false end
    local m = member(match, id)
    if m == nil then return false end
    m.gone = true
    onDeparture(match, id, now, ("player %d dropped (%s)"):format(id, tostring(reason)))
    return true
end

function M.coreStopped(now)
    for _, match in pairs(M.matches) do
        freezeAll(match, false)
        for _, m in ipairs(match.members) do
            if present(m) or m.leaving then W().hud(m.id, { state = "idle", activity = aid() }) end
            m.gone = true
            if M.playerMatch[m.id] == match.id then M.playerMatch[m.id] = nil end
        end
        match.pending = {}
        if match.state ~= "resolved" and match.state ~= "closed" then
            match.void, match.voidReason = true, "Light RP restarted. Nothing counts."
            match.token = (match.token or 0) + 1
            finish(match, now, "op77_lightrp stopped")
        end
        -- Everyone is gone: the next tick closes the match (cars, bucket).
    end
end

function M.matchOf(id) return M.matches[M.playerMatch[id] or -1] end

-- ---------------------------------------------------------------- release

local function close(match)
    removeCars(match)
    clearBlocks(match)
    for _, m in ipairs(match.members) do
        if m.bot then ChaseBots.remove(m.id) end
    end
    W().sweepBucket(match.bucket)
    M.bucketOwner[match.bucket] = nil
    for _, m in ipairs(match.members) do
        if M.playerMatch[m.id] == match.id then M.playerMatch[m.id] = nil end
    end
    match.state = "closed"
    M.matches[match.id] = nil
    log("match %d closed", match.id)
end

-- One member home: out of the car, alive, then activityLeave (Light RP takes him back).
local function releaseMember(match, m, now)
    if m.gone or m.released then return end
    if not m.leaving and match.state ~= "resolved" then return end
    if m.bot then
        -- A bot goes with the scoreboard, or at once when no player is left to see it.
        if humanCount(match) > 0 and now < (match.releaseAtMs or now) then return end
        m.released = true
        removeCar(match, m.id)
        ChaseBots.remove(m.id)
        return
    end
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
    if M.playerMatch[m.id] == match.id then M.playerMatch[m.id] = nil end
    W().hud(m.id, { state = "idle", activity = aid() })
    ChaseCore.leave(m.id, { returnPlayer = true }, aid())
end

-- ---------------------------------------------------------------- active round

local function sampleOf(match)
    local sample = { cops = {} }
    local runnerId = match.runnerId
    sample.runnerDown = W().alive(runnerId) == false
    local rp = W().position(runnerId)
    if rp and (rp.bucket == nil or rp.bucket == match.bucket) then sample.runnerPos = rp end
    for _, m in ipairs(presentList(match)) do
        if match.roles[m.id] == "cop" then
            local p = W().position(m.id)
            if p and p.bucket ~= nil and p.bucket ~= match.bucket then p = nil end
            sample.cops[m.id] = { pos = (not m.respawning) and p or nil, down = m.respawning or W().alive(m.id) == false,
                released = match.copReleased[m.id] == true }
        end
    end
    return sample
end

-- A downed cop is back at the line-up after copRespawnSeconds, with a new car.
local function copLife(match, m, now)
    if m.respawning then return end
    if W().alive(m.id) ~= false then m.downSinceMs = nil return end
    m.downSinceMs = m.downSinceMs or now
    if now - m.downSinceMs < (cfg().match.copRespawnSeconds or 5) * 1000 then return end
    m.respawning, m.placing = true, true
    removeCar(match, m.id)
    local token = match.token
    W().place(m.id, besideMark(m.point), match.bucket, function(ok, why)
        m.placing = nil
        if M.matches[match.id] ~= match or match.token ~= token or not present(m) then return end
        m.respawning, m.downSinceMs = nil, nil
        if ok then
            createCar(match, m.id)
            notify(m.id, "info", "Back in service. Your car is beside you.", 4000)
        else
            log("match %d: cop %d respawn failed: %s", match.id, m.id, tostring(why))
        end
    end)
end

local function levelAllows(match, field)
    local round = match.chase
    for i = 1, round.heat do
        if (match.rules.heat[i] or {})[field] then return true end
    end
    return false
end

local function anyReleased(match)
    for _ in pairs(match.copReleased) do return true end
    return false
end

-- Dispatch: a vague circle around the runner every few seconds (tighter with heat), a
-- tight one when a cop has eyes on him.
local function scanTick(match, now, sample)
    if not anyReleased(match) or sample.runnerPos == nil then return end
    local round, t = match.chase, match.rules
    local _, def = R.heatAt(t.heat, now - round.startedAtMs)
    local eyes = round.nearest ~= nil and round.nearest <= (t.eyesOnMetres or 60)
    local scanner = cfg().scanner or {}
    local interval = (eyes and scanner.eyesOnSeconds or def.scan or 20) * 1000
    if match.lastScanAtMs ~= nil and now - match.lastScanAtMs < interval then return end
    local radius = eyes and (scanner.eyesOnRadius or 25) or (def.scanRadius or 120)
    match.sighting = { position = R.fuzz(sample.runnerPos, radius, function() return random(match) end), radius = radius,
        atMs = now, eyes = eyes }
    match.lastScanAtMs = now
    if not eyes then
        match.lastTimedScanAtMs = now
        notifyRole(match, "cop", "info", ("Dispatch: suspect sighted - %d m circle on your map."):format(radius), 3000)
    end
end

local function extractionTick(match, now, sample)
    local x = cfg().extraction
    if match.extraction == nil and not match.extractionMissed and sample.runnerPos and levelAllows(match, "extraction") then
        local point = R.pickExtraction(cfg().extractionPoints, sample.runnerPos, x.band[match.mode] or { 400, 1200 },
            function() return random(match) end)
        if point then
            match.extraction = { position = { x = point.position.x, y = point.position.y, z = point.position.z },
                radius = x.radius[match.mode] or 15, zTolerance = x.zTolerance or 8 }
            match.chase.extraction = match.extraction
            match.extractionCopAtMs = now + (x.copDelaySeconds or 20) * 1000
            local d = R.planar(sample.runnerPos, point.position)
            notify(match.runnerId, "warning", ("Extraction point on your map, %d m away. Get there."):format(math.floor(d + 0.5)), 6000)
            log("match %d round %d: extraction at %.1f,%.1f (%.0fm)", match.id, match.round, point.position.x, point.position.y, d)
        else
            match.extractionMissed = true
        end
    end
    if match.extraction and not match.extractionCopsTold and now >= (match.extractionCopAtMs or math.huge) then
        match.extractionCopsTold = true
        notifyRole(match, "cop", "warning", "Dispatch: we know where he's heading - extraction on your map. Cut him off.", 6000)
    end
end

local function roadblockTick(match, now, sample)
    local rb = cfg().roadblock or {}
    if not rb.enabled or match.mode ~= "vehicle" or not levelAllows(match, "roadblocks") then return end
    if now < (match.nextBlockAtMs or 0) or #match.blocks >= (rb.maxAlive or 2) or sample.runnerPos == nil then return end
    local pace = match.chase.pace.runner
    local centre, heading = R.roadblockSpot(pace and pace.samples, rb)
    if centre == nil then match.nextBlockAtMs = now + 2000 return end
    for _, m in ipairs(presentList(match)) do
        local p = W().position(m.id)
        if p and R.planar(p, centre) < (rb.clearMetres or 12) then match.nextBlockAtMs = now + 2000 return end
    end
    local spec = { record = rb.record, fallbackRecord = rb.fallbackRecord, lightsOn = true, sirenOn = true,
        locked = true, immortal = true, engineOff = true }
    local block = { cars = {}, expiresAtMs = now + (rb.lifetimeSeconds or 40) * 1000, centre = centre }
    for _, mark in ipairs(R.roadblockMarks(centre, heading, rb)) do
        local carId, why = W().createCar(spec, mark, match.bucket)
        if carId then block.cars[#block.cars + 1] = carId
        else log("match %d roadblock car failed: %s", match.id, tostring(why)) end
    end
    match.nextBlockAtMs = now + (rb.everySeconds or 40) * 1000
    if #block.cars == 0 then return end
    match.blocks[#match.blocks + 1] = block
    log("match %d roadblock: %d car(s) at %.1f,%.1f,%.1f heading %.0f", match.id, #block.cars, centre.x, centre.y, centre.z, heading)
    notify(match.runnerId, "warning", "NCPD roadblock ahead!", 4000)
    notifyRole(match, "cop", "info", "Roadblock deployed ahead of the suspect.", 3000)
end

-- ---------------------------------------------------------------- bots

local function targetOf(m)
    return m.bot and { bot = m.id } or { player = m.id }
end

-- The nearest cop (released or not) to a point: { member, distance }.
local function nearestCop(match, pos)
    local best, bestD
    if pos == nil then return nil end
    for _, m in ipairs(presentList(match)) do
        if match.roles[m.id] == "cop" then
            local p = W().position(m.id)
            if p then
                local d = R.planar(p, pos)
                if bestD == nil or d < bestD then best, bestD = m, d end
            end
        end
    end
    return best, bestD
end

-- What each bot does this tick (see the header): held outside the active phase, and
-- while dispatch holds it (cops) or the countdown holds it (runner).
local function steerBots(match, now)
    local runner = member(match, match.runnerId)
    local active = match.state == "active" and match.chase ~= nil and runner ~= nil and present(runner)
    for _, m in ipairs(match.members) do
        if m.bot and present(m) then
            local order = HOLD
            if active then
                if m.id == match.runnerId then
                    -- On foot it runs from the nearest cop; at the wheel it drives the course
                    -- (the threat would only restart the route each time the nearest cop changes).
                    local cop = match.mode == "foot" and nearestCop(match, W().position(m.id)) or nil
                    if ChaseBots.yieldCheck(m.id, match.chase.nearest, match.rules.bustDistance or 15, now) then
                        order = { kind = "yield" }
                    elseif match.extraction then
                        order = { kind = "goto", position = match.extraction.position }
                    else
                        order = { kind = "flee", from = cop and targetOf(cop) or nil, route = match.route and match.route.course or nil,
                            routeKey = match.round }
                    end
                elseif match.copReleased[m.id] and not m.respawning then
                    order = { kind = "chase", target = targetOf(runner) }
                end
            end
            ChaseBots.steer(m.id, order)
        end
    end
end

-- A bot cop fallen far behind (no AI drives beyond 350 m of a player) is dispatched again
-- on the road the runner took, 120-220 m behind him.
local function redispatchTick(match, now, sample)
    if sample.runnerPos == nil then return end
    ChaseBots.trailPush(match.trail, sample.runnerPos, now)
    for _, m in ipairs(presentList(match)) do
        if m.bot and match.roles[m.id] == "cop" and match.copReleased[m.id] and not m.respawning then
            local p = W().position(m.id)
            local d = p and R.planar(p, sample.runnerPos) or nil
            if ChaseBots.wantsRedispatch(m.id, d, now) then
                local spot = ChaseBots.trailPick(match.trail, sample.runnerPos)
                if spot then
                    m.point = spot
                    removeCar(match, m.id)
                    createCar(match, m.id)
                    log("match %d: bot cop %d dispatched again %.0f m from the runner", match.id, m.id, R.planar(spot.position, sample.runnerPos))
                end
            end
        end
    end
end

local function brokenBot(match)
    for _, m in ipairs(match.members) do
        if m.bot and present(m) and ChaseBots.broken(m.id) then return m end
    end
    return nil
end

local function tickActive(match, now)
    refreshBoarding(match, now)
    local round = match.chase
    for id, at in pairs(match.releaseAt) do
        local m = member(match, id)
        if m and present(m) and not match.copReleased[id] and now >= at then
            match.copReleased[id] = true
            freeze(m, false)
            notify(id, "warning", "Dispatch: you're up. GO.", 3000)
        end
    end
    for _, m in ipairs(presentList(match)) do
        if match.roles[m.id] == "cop" then copLife(match, m, now) end
    end
    local sample = sampleOf(match)
    local outcome, events = R.step(round, match.rules, now, sample)
    for _, e in ipairs(events or {}) do
        if e.kind == "heat" then
            notifyAll(match, "warning", ("HEAT %d%s"):format(e.level, e.text and (" - " .. e.text) or ""), 4000)
        elseif e.kind == "crash" then
            local id = e.id == "runner" and match.runnerId or e.id
            notify(id, "warning", ("Crash! Engine stalled - %.0fs."):format(match.rules.crashStallSeconds or 0), 3000)
        elseif e.kind == "shake_started" then
            notify(match.runnerId, "info", ("No cop within %.0f m - keep it up to shake them."):format(match.rules.escapeDistance), 3000)
        elseif e.kind == "shake" then
            notify(match.runnerId, "success", ("You shook them! +%d."):format(cfg().points.shake or 0), 4000)
            notifyRole(match, "cop", "warning", "Suspect lost - check dispatch and close in again.", 4000)
        elseif e.kind == "overtime" then
            notifyAll(match, "warning", "Overtime - the arrest in progress decides it.", 4000)
        end
    end
    if outcome then return M.resolveRound(match, outcome, now) end
    if match.hasBots and ChaseBots then redispatchTick(match, now, sample) end
    scanTick(match, now, sample)
    extractionTick(match, now, sample)
    roadblockTick(match, now, sample)
    expireBlocks(match, now)
    if now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
end

function M.tickMatch(match, now)
    for _, m in ipairs(match.members) do releaseMember(match, m, now) end
    if match.hasBots and ChaseBots and match.state ~= "resolved" and match.state ~= "closed" then
        local broken = brokenBot(match)
        if broken then
            log("match %d: bot %d broken (%s)", match.id, broken.id, tostring(select(2, ChaseBots.broken(broken.id))))
            return M.abort(match, now, "A bot could not be set up. Nothing counts.")
        end
        steerBots(match, now)
    end
    local state = match.state
    if state == "placing" then
        local done, runnerFailed = true, false
        for _, m in ipairs(presentList(match)) do
            if m.placed == false or (m.placed ~= true and now >= match.placeDeadlineMs) then
                notify(m.id, "warning", "The chase area did not load for you. You are taken back.", 6000)
                log("match %d: %d dropped at placement (%s)", match.id, m.id, tostring(m.placeError or "timeout"))
                m.leaving, m.releaseAtMs = true, now
                if m.id == match.runnerId then runnerFailed = true end
            elseif m.placed ~= true then
                done = false
            end
        end
        if presentCount(match) < 2 then return finish(match, now, "placement") end
        if runnerFailed then
            match.round = match.round - 1
            match.turn = match.turn + 1
            return beginRound(match, now)
        end
        if done then beginCountdown(match, now) end
    elseif state == "countdown" then
        refreshBoarding(match, now)
        if now >= match.countdownEndsAtMs then beginActive(match, now)
        elseif now - (match.lastHudMs or 0) >= (cfg().match.hudPushMs or 500) then pushAll(match, now) end
    elseif state == "active" then
        tickActive(match, now)
    elseif state == "intermission" then
        if now >= match.intermissionEndsAtMs then beginRound(match, now)
        elseif now - (match.lastHudMs or 0) >= 1000 then
            pushAll(match, now, function(id)
                return { lastRound = match.lastSummary, gained = (match.lastRound and match.lastRound.gained[id]) or 0,
                    wasRunner = match.lastRound and id == match.lastRound.runnerId or nil,
                    nextRunnerName = (function() local n = nextTurn(match); return n and name(match, n) or nil end)(),
                    nextIsYou = nextTurn(match) == id or nil }
            end)
        end
    elseif state == "resolved" then
        local pending = false
        for _, m in ipairs(match.members) do
            if not m.gone and not m.released then pending = true end
        end
        if not pending then close(match) end
    end
end

function M.tick(now)
    local ids = {}
    for id in pairs(M.matches) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local match = M.matches[id]
        if match then
            local ok, err = pcall(M.tickMatch, match, now)
            if not ok then log("match %d tick error: %s", id, tostring(err)) end
        end
    end
end

function M.shutdown()
    for _, match in pairs(M.matches) do
        freezeAll(match, false)
        removeCars(match)
        clearBlocks(match)
        for _, m in ipairs(match.members) do
            if m.bot and ChaseBots then ChaseBots.remove(m.id) end
        end
    end
end

-- For the hub: idle / lobby / running, with counters.
function M.status(queued, countdownMs)
    local running, players, seats, roundText = 0, 0, 0, nil
    for _, match in pairs(M.matches) do
        if match.state ~= "closed" then
            running = running + 1
            players = players + humanCount(match)
            seats = seats + M.dropInSeats(match)
            roundText = ("round %d/%d"):format(match.round, roundCount(match))
        end
    end
    local phase = running > 0 and "running" or (queued > 0 and "lobby" or "idle")
    local parts = {}
    if queued > 0 then
        -- In 10 s steps: the status is only sent when it changes.
        parts[#parts + 1] = countdownMs and ("%d waiting - starts in ~%ds"):format(queued, math.max(10, math.ceil(countdownMs / 10000) * 10))
            or ("%d waiting (%d needed)"):format(queued, M.minPlayers())
    end
    if running > 0 then
        parts[#parts + 1] = ("on, %s%s"):format(roundText or "", seats > 0 and " - join for the next round" or "")
    end
    return { phase = phase, players = players, queued = queued, joinable = seats > 0 or allocateBucket() ~= nil,
        detail = #parts > 0 and table.concat(parts, " - ")
            or ("1 runner vs the NCPD, %d-%d players. Everyone runs once."):format(M.minPlayers(), cfg().maxPlayers) }
end
