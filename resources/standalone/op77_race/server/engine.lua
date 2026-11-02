-- Race instances. Freeroam's single-heat engine reworked for Light RP: any number of
-- instances run at once, each in its own routing bucket (4200000+). A time trial is an
-- instance of one; a street or rooftop race an instance of up to eight.
--
-- Ported from freeroam/race/server/main.lua and kept as close as possible where it was
-- proven (vehicle hold through replicated flags, warpPlayerIntoVehicle with an exit
-- lock, forced exit before removal, swept-cylinder checkpoints, finish window). What
-- changed:
--   * admission and return go through the activity contract (server/activity.lua):
--     the core captures the return point, puts the RP weapons aside and brings the
--     player back; nothing is placed by kill -> respawn any more (runners teleport);
--   * no implant, Dash, Overdrive or weapon is handed out (no Athlete legs, no katana);
--   * loaner cars are created in the instance bucket and removed at the end;
--   * results go to the core (placement, time, proposed reputation), never cash;
--   * per-checkpoint fireworks are rate-limited per instance (client effect quota).
local Config = RaceConfig
local Engine = Config.engine
local S = RaceShared
local A = RaceActivity

RaceEngine = {}
local E = RaceEngine

local instances = {}       -- instance id -> instance
local racers = {}          -- playerId -> racer, while the player takes part
local bucketsInUse = {}
local instanceSequence = 0
local bucketCursor = -1
E.instances, E.racers = instances, racers

local noop = function() end
-- Presentation hooks, filled by server/main.lua.
E.hooks = {
    push = noop,        -- (playerId, payload)
    clear = noop,       -- (playerId) the race HUD goes away
    notice = noop,      -- (playerId, kind, title, text)
    pulse = noop,       -- (playerId, payload) go / checkpoint / lap / finish
    changed = noop,     -- () activity status may have changed
    cover = noop,       -- (playerId, screen) loading cover
    uncover = noop,     -- (playerId)
}

local function nowMs() return math.floor(Open77.time.monotonic() * 1000) end
E.nowMs = nowMs
local function log(text) print("[race] " .. tostring(text)) end
local function seconds(value, fallback) return math.floor((tonumber(value) or fallback) * 1000) end
local function perMode(value, mode, fallback)
    if type(value) == "table" then return value[mode] or fallback end
    return value or fallback
end

local function connected(playerId) return Open77.players.name(playerId) ~= nil end
local function playerName(playerId) return Open77.players.name(playerId) or ("Player " .. tostring(playerId)) end

-- Staff bot mode lives in server/bots.lua (RaceBots, loaded after this file). Until it
-- is loaded, and in a build without it, an instance simply has no bots.
local NO_BOTS = {
    fill = function() return 0 end, tick = noop, countdown = noop, go = noop, resolve = noop, cleanup = noop,
    stop = noop, shutdown = noop, readyForCountdown = function() return true end,
    racing = function() return false end, starters = function() return 0 end, count = function() return 0 end,
    rows = function() return {} end, entrant = function() return nil end,
}
local function bots() return RaceBots or NO_BOTS end

-- Everyone on the line: the players plus the bots.
local function fieldSize(inst) return #inst.members + bots().count(inst) end
E.fieldSize = fieldSize

-- ---------------------------------------------------------------- buckets --

local function allocateBucket()
    for _ = 1, Config.bucketCount do
        bucketCursor = (bucketCursor + 1) % Config.bucketCount
        local bucket = Config.bucketBase + bucketCursor
        if not bucketsInUse[bucket] then
            bucketsInUse[bucket] = true
            return bucket
        end
    end
    return nil
end

-- ---------------------------------------------------------------- vehicles --

local function vehicleCall(name, ...)
    local api = Open77 and Open77.vehicles
    if type(api) ~= "table" or type(api[name]) ~= "function" then return nil, "vehicles_api_unavailable:" .. name end
    local ok, result, reason = pcall(api[name], ...)
    if not ok then return nil, tostring(result) end
    if result == nil or result == false then return nil, reason or "rejected" end
    return result, reason
end
E.vehicleCall = vehicleCall

local function holdMask() return Open77.vehicles.flags.frozen end

local function vehicleFlags(held)
    local flags = Open77.vehicles.flags
    -- Ignition and throttle stay live under the hold: holding the accelerator across GO works.
    local base = (flags.lightsOn or 0) | (flags.engineOn or 0)
    if held then return base | holdMask() end
    return base
end
E.vehicleFlags = vehicleFlags

-- One authority for the grid hold: the replicated frozen flag, which also rejects the
-- driver's own motion reports.
local function setHeld(vehicleId, held)
    local snapshot, reason = vehicleCall("get", vehicleId)
    if type(snapshot) ~= "table" then return false, reason or "vehicle_unavailable" end
    local mask = holdMask()
    local flags = snapshot.flags or 0
    local desired = (held and (flags | mask) or (flags & ~mask)) | Open77.vehicles.flags.engineOn
    if flags ~= desired then
        local ok, updateReason = vehicleCall("update", vehicleId, { flags = desired })
        if not ok then return false, updateReason end
    end
    snapshot = vehicleCall("get", vehicleId)
    if type(snapshot) ~= "table" or ((snapshot.flags or 0) & mask) ~= (held and mask or 0) then
        return false, "grid_hold_not_applied"
    end
    return true
end
E.setHeld = setHeld

local function removeVehicle(racer, why)
    if racer == nil or racer.vehicleId == nil then return false end
    local id = racer.vehicleId
    racer.vehicleId, racer.ready = nil, false
    local ok, reason = vehicleCall("remove", id)
    if not ok then log(("vehicle %s removal failed (%s): %s"):format(tostring(id), tostring(why), tostring(reason))) end
    return ok ~= nil
end

local function seatOf(playerId)
    local seat = vehicleCall("getPlayerSeat", playerId)
    if type(seat) == "table" and seat.vehicleId ~= nil then return seat end
    return nil
end

local function forceExit(playerId, racer)
    if racer == nil or racer.vehicleId == nil then return false end
    local seat = seatOf(playerId)
    if seat == nil or tostring(seat.vehicleId) ~= tostring(racer.vehicleId) then return false end
    local ok, reason = vehicleCall("forcePlayerOutOfVehicle", playerId, racer.vehicleId)
    if not ok then log(("forced exit failed player=%d: %s"):format(playerId, tostring(reason))) end
    return ok ~= nil
end

local function assignDriver(playerId, racer)
    local ok, reason = vehicleCall("warpPlayerIntoVehicle", playerId, racer.vehicleId,
        Engine.vehicle.driverSeat, { moveBucket = true, exitLocked = true })
    if not ok then
        log(("driver assignment failed player=%d vehicle=%s: %s"):format(playerId, tostring(racer.vehicleId), tostring(reason)))
        return false, reason
    end
    racer.ready = false
    return true
end

-- Freeroam's settle pass: once materialized, put the car back on its surveyed mark,
-- unless the driver is already mounted or it has moved on its own.
local function scheduleSettle(inst, playerId, racer, vehicleId, slot, run)
    SetTimeout(math.max(0, Engine.vehicle.settleAfterMs or 1200), function()
        if instances[inst.id] ~= inst or inst.run ~= run or inst.phase ~= "loading" or racer.vehicleId ~= vehicleId then return end
        local snapshot = vehicleCall("get", vehicleId)
        if type(snapshot) ~= "table" then return end
        local seat = seatOf(playerId)
        if seat and tostring(seat.vehicleId) == tostring(vehicleId) and seat.forcedEntry ~= true and seat.entering ~= true then return end
        local drift = math.sqrt(((tonumber(snapshot.x) or slot.position.x) - slot.position.x) ^ 2 +
            ((tonumber(snapshot.y) or slot.position.y) - slot.position.y) ^ 2)
        if drift > (Engine.vehicle.settleMaxDriftMetres or 3.0) then return end
        if vehicleCall("setTransform", vehicleId, { position = S.clone(slot.position), yaw = slot.heading }) then
            -- setTransform clears the electrical flags: hold again.
            setHeld(vehicleId, true)
        end
    end)
end

-- ---------------------------------------------------------------- players --

local function protect(playerId, racer)
    if racer.previousGodMode == nil then
        local health = Open77.players.getHealth(playerId)
        if health == nil then return false end
        racer.previousGodMode = health.godMode == true
    end
    return Open77.players.setGodMode(playerId, true) == true
end

local function unprotect(playerId, racer)
    if racer.frozen then
        Open77.players.setFrozen(playerId, false)
        racer.frozen = false
    end
    if racer.previousGodMode ~= nil then
        local ok, reason = Open77.players.setGodMode(playerId, racer.previousGodMode)
        if ok then racer.previousGodMode = nil
        else log(("god mode restore failed for %d: %s"):format(playerId, tostring(reason))) end
    end
end

local function alive(playerId)
    local life = Open77.players.getLifeState(playerId)
    return life ~= nil and life.phase == "alive"
end

-- Runners are held where they stand from the moment they are placed until GO.
local function holdRunner(inst, playerId, racer)
    if not S.onFoot(inst.course) or not racer.placed then return false end
    if (inst.phase ~= "loading" and inst.phase ~= "countdown") or (racer.state ~= "loading" and racer.state ~= "countdown") then return false end
    local life = Open77.players.getLifeState(playerId)
    if not life or (life.phase ~= "alive" and life.phase ~= "recovering") then return false end
    local p = Open77.players.position(playerId)
    if not p or p.bucket ~= inst.bucket then return false end
    local ok = Open77.players.setFrozen(playerId, true) == true
    racer.frozen = racer.frozen or ok
    return ok
end

local function lastPoint(inst, racer)
    local index = racer.lastCheckpointIndex
    local checkpoint = index and inst.course.checkpoints[index]
    if checkpoint then return { position = checkpoint.position, heading = checkpoint.heading } end
    return racer.slot or inst.course.start
end

-- ---------------------------------------------------------------- payloads --

local function rows(inst)
    local now = nowMs()
    local list = {}
    for grid, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer then
            local distance
            if racer.state == "racing" and racer.nextCheckpoint then
                local checkpoint = inst.course.checkpoints[racer.nextCheckpoint]
                local p = Open77.players.position(playerId)
                if checkpoint and p and p.bucket == inst.bucket then distance = S.distance(p, checkpoint.position) end
            end
            list[#list + 1] = {
                id = playerId, name = racer.name, state = racer.state, grid = grid,
                finishPlace = racer.finishPlace, progress = racer.completed or 0,
                distance = distance and math.floor(distance) or nil,
                lap = racer.lap, timeMs = racer.timeMs, bestLapMs = racer.bestLapMs,
                ready = racer.ready == true,
                elapsedMs = racer.state == "racing" and inst.startedAt and (now - inst.startedAt) or nil,
            }
        end
    end
    for _, row in ipairs(bots().rows(inst, now)) do list[#list + 1] = row end
    return S.rankRows(list)
end
E.rows = rows

local function phaseTimes(inst, now)
    local remaining, elapsed = 0, 0
    if inst.phase == "loading" then
        remaining = math.max(0, (inst.loadEndsAt or now) - now)
    elseif inst.phase == "countdown" then
        remaining = math.max(0, inst.countdownEndsAt - now)
    elseif inst.phase == "active" then
        remaining = math.max(0, (inst.finishEndsAt or inst.endsAt) - now)
        elapsed = math.max(0, now - inst.startedAt)
    elseif inst.phase == "results" then
        remaining = math.max(0, inst.resultsEndsAt - now)
        elapsed = inst.startedAt and math.max(0, (inst.resolvedAt or now) - inst.startedAt) or 0
    end
    return remaining, elapsed
end

function E.payload(playerId, shared)
    local racer = racers[playerId]
    if racer == nil then return nil end
    local inst = instances[racer.instanceId]
    if inst == nil then return nil end
    local now = nowMs()
    local course = inst.course
    local remaining, elapsed = phaseTimes(inst, now)
    if racer.timeMs and (racer.state == "finished") then elapsed = racer.timeMs end
    local vehicle = RaceCourses.vehicle(course.vehicle) or {}
    local total = #course.checkpoints
    local payload = {
        self = playerId,
        instance = inst.id, run = inst.run, activity = inst.activityId, mode = inst.mode, label = inst.label,
        phase = inst.phase, state = racer.state,
        course = { id = course.id, name = course.name, laps = course.laps, total = total,
            onFoot = S.onFoot(course), vehicle = vehicle.label, start = course.start },
        lap = racer.lap or 1, laps = course.laps,
        checkpoint = racer.nextCheckpoint or total, completed = racer.completed or 0,
        progressTotal = total * course.laps,
        remainingMs = remaining, elapsedMs = elapsed,
        bestLapMs = racer.bestLapMs, lastLapMs = racer.lastLapMs,
        place = racer.finishPlace, timeMs = racer.timeMs,
        racers = fieldSize(inst),
        bots = bots().count(inst) > 0 and bots().count(inst) or nil,
        canRestart = inst.mode == "trial" and inst.phase ~= "loading" and not inst.restarting,
        canRespawn = S.onFoot(course) and inst.phase == "active" and racer.state == "racing",
        outcome = racer.outcome,
        result = inst.result,
        dnfReason = racer.dnfReason,
    }
    if inst.mode == "trial" and racer.key then
        local best = RaceRecords.best(course.id, course.revision, racer.key)
        local record = RaceRecords.record(course.id, course.revision)
        payload.personalBestMs = best and best.timeMs or nil
        payload.recordMs = record and record.timeMs or nil
        payload.recordName = record and record.name or nil
    elseif inst.mode == "pve" and racer.key then
        -- the separate best vs AI, never the time trial's board
        local best = RaceRecords.best(RaceRecords.vsAiBoard(course.id), course.revision, racer.key)
        payload.personalBestMs = best and best.timeMs or nil
    end
    local guided = racer.state == "loading" or racer.state == "countdown" or racer.state == "racing"
    local checkpoint = guided and racer.nextCheckpoint and course.checkpoints[racer.nextCheckpoint]
    if checkpoint then
        payload.next = {
            index = racer.nextCheckpoint, id = checkpoint.id, position = checkpoint.position, heading = checkpoint.heading,
            radius = checkpoint.radius or course.checkpointRadius or Engine.checkpointRadius,
            finish = racer.nextCheckpoint == total and (racer.lap or 1) >= course.laps,
        }
        local following = course.checkpoints[racer.nextCheckpoint + 1] or (course.laps > (racer.lap or 1) and course.checkpoints[1]) or nil
        if following and not payload.next.finish then payload.after = { position = following.position } end
    end
    if fieldSize(inst) > 1 then
        payload.rows = shared and shared.rowsJson or json.encode(rows(inst))
    end
    return payload
end

local function push(playerId, shared)
    local payload = E.payload(playerId, shared)
    if payload then E.hooks.push(playerId, payload) end
end
E.push = push

-- One ranking per instance push, shared by every member.
local function pushInstance(inst)
    local shared = nil
    if fieldSize(inst) > 1 then shared = { rowsJson = json.encode(rows(inst)) } end
    for _, playerId in ipairs(inst.members) do
        if racers[playerId] and racers[playerId].instanceId == inst.id then push(playerId, shared) end
    end
end
E.pushInstance = pushInstance

-- ---------------------------------------------------------------- results --

-- A street race filled with bots by the staff switch (a race vs AI is not a test).
local function testRace(inst) return inst.hadBots == true and inst.mode ~= "pve" end
E.testRace = testRace

-- Race vs AI: less than against players, and nothing on a course or a run too short to
-- be anything but farming.
local function pveReputation(inst, racer, starters)
    local pve = type(Config.pve) == "table" and Config.pve or {}
    local rewards = type(pve.rewards) == "table" and pve.rewards or {}
    if S.routeMetres(inst.course) * (inst.course.laps or 1) < (tonumber(pve.minimumMetres) or 0) then return 0 end
    if (racer.timeMs or 0) < (tonumber(pve.minimumSeconds) or 0) * 1000 then return 0 end
    local rep = tonumber(rewards.finish) or 0
    if starters >= 2 then rep = rep + ((rewards.placement or {})[racer.finishPlace] or 0) end
    return rep
end

local function reputationFor(inst, racer, starters)
    local rewards = Config.rewards
    if racer.state ~= "finished" or testRace(inst) then return 0 end
    if inst.mode == "pve" then return pveReputation(inst, racer, starters) end
    if inst.mode == "trial" then
        local rep = rewards.trialFinish or 0
        if racer.outcome and racer.outcome.personalBest then rep = rep + (rewards.personalBest or 0) end
        if racer.outcome and racer.outcome.courseRecord then rep = rep + (rewards.courseRecord or 0) end
        return rep
    end
    local rep = rewards.heatFinish or 0
    if starters >= 2 then rep = rep + ((rewards.placement or {})[racer.finishPlace] or 0) end
    return rep
end

-- Everyone who reached GO, bots included.
local function startersOf(inst)
    local count = 0
    for _, racer in pairs(inst.racers) do if racer.started then count = count + 1 end end
    return count + bots().starters(inst)
end

-- One result per racer who reached GO (a trial reports finished runs only). A finisher's
-- result leaves at the line (the starters are fixed at GO); the others' at resolve. A
-- racer the core already released (dropped) is not reported.
local function sendResult(inst, playerId, racer)
    if racer.resultSent or not racer.started or racer.dropped then return end
    if inst.mode == "trial" and racer.state ~= "finished" then return end
    racer.resultSent = true
    local starters = startersOf(inst)
    local finished = racer.state == "finished"
    local score = 0
    if finished then score = inst.mode == "trial" and 1 or math.max(1, starters - (racer.finishPlace or starters) + 1) end
    A.result(playerId, inst.activityId, {
        placement = finished and racer.finishPlace or nil,
        score = score,
        won = finished and racer.finishPlace == 1 and (inst.mode == "trial" or starters >= 2),
        -- A race the staff switch filled with bots is a test: the core records nothing for
        -- it, even when bot mode was switched off while it ran. A race vs AI is recorded.
        test = testRace(inst) or nil,
        stats = {
            bots = inst.hadBots and bots().starters(inst) or nil,
            vsAi = inst.mode == "pve" or nil,
            mode = inst.mode,
            courseId = inst.course.id,
            courseRevision = inst.course.revision,
            vehicle = inst.course.vehicle,
            finished = finished,
            timeMs = finished and racer.timeMs or nil,
            bestLapMs = racer.bestLapMs,
            laps = inst.course.laps,
            checkpoints = racer.completed or 0,
            racers = starters,
            personalBest = racer.outcome and racer.outcome.personalBest or nil,
            courseRecord = inst.mode ~= "pve" and racer.outcome and racer.outcome.courseRecord or nil,
            dnfReason = (not finished) and racer.dnfReason or nil,
        },
        reputation = reputationFor(inst, racer, starters),
    })
end

-- ---------------------------------------------------------------- release --

local function fallbackReturn(playerId, racer)
    local point = racer.fallback or Config.fallbackPoint
    if point == nil then return false end
    local promise, why = Open77.players.teleport(playerId, { x = point.x, y = point.y, z = point.z }, {
        heading = point.heading or 0, bucket = point.bucket or 0, fade = true, dismount = true,
        timeoutMs = Engine.teleportTimeoutMs })
    if promise then
        local placed
        placed, why = promise:await()
        if placed then return true end
    end
    log(("fallback return failed for %d: %s"):format(playerId, tostring(why)))
    return false
end

-- A dead racer is brought back inside the instance first: the core cannot move a dead body.
local function ensureAlive(inst, playerId, racer)
    for _ = 1, 20 do
        local life = Open77.players.getLifeState(playerId)
        if life == nil then return false end
        if life.phase == "alive" then return true end
        if life.phase == "dead" and not racer.respawning then
            racer.respawning = true
            local point = lastPoint(inst, racer)
            local ok, reason = Open77.players.respawn(playerId, { position = S.clone(point.position),
                heading = point.heading or 0, bucket = inst.bucket, health = 1.0 })
            if not ok then racer.respawning = false; log(("respawn failed for %d: %s"):format(playerId, tostring(reason))) end
        end
        Wait(500)
    end
    return alive(playerId)
end

local function remaining(inst)
    local count = 0
    for _, racer in pairs(racers) do if racer.instanceId == inst.id then count = count + 1 end end
    return count
end

-- The last player gone (results over, left, dropped, disconnected): the bots and their
-- cars go with the instance, before its bucket is handed out again.
local function retire(inst)
    if instances[inst.id] ~= inst or remaining(inst) > 0 then return end
    bots().cleanup(inst, "instance_closed")
    instances[inst.id] = nil
    bucketsInUse[inst.bucket] = nil
    log(("instance %s closed (bucket %d)"):format(inst.id, inst.bucket))
    E.hooks.changed()
end
E.retire = retire

local resolve -- forward

-- Every player is done (finished, out or gone). Bots are not counted here.
local function allResolved(inst)
    for _, racer in pairs(inst.racers) do
        if racer.state == "racing" or racer.state == "countdown" or racer.state == "loading" then return false end
    end
    return true
end
E.allResolved = allResolved

-- A finished player still in the instance, watching the others.
local function playerWatching(inst)
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer.state == "finished" and racers[playerId] == racer and not racer.releasing then return true end
    end
    return false
end

-- Nothing left to wait for: every player is done, and no bot is still racing in front
-- of a finished player (bots never keep a race open for nobody). Without bots this is
-- allResolved.
local function settled(inst)
    if not allResolved(inst) then return false end
    return not (bots().racing(inst) and playerWatching(inst))
end
E.settled = settled

-- Takes a racer out of the instance: car out, protections off, then back to Light RP.
--   viaCore  : activityLeave(returnPlayer) - the normal way out
--   fallback : the core is gone, teleport to the point captured before entering
--   (neither): the core already released and moved the player (dropped)
local function release(inst, playerId, racer, opts)
    if racer.releasing then return end
    racer.releasing = true
    opts = opts or { viaCore = true }
    CreateThread(function()
        local hadVehicle = racer.vehicleId ~= nil
        if hadVehicle and connected(playerId) and forceExit(playerId, racer) then
            Wait(math.max(0, Engine.vehicle.exitSettleMs or 1500))
        end
        if hadVehicle then removeVehicle(racer, opts.reason or "release") end
        if connected(playerId) then
            unprotect(playerId, racer)
            E.hooks.uncover(playerId)
            E.hooks.clear(playerId)
            if not racer.dropped and (opts.viaCore or opts.fallback) then
                ensureAlive(inst, playerId, racer)
                if opts.viaCore and not racer.dropped then
                    local ok, why = A.leave(playerId, inst.activityId, { returnPlayer = true })
                    if not ok then
                        log(("activityLeave failed for %d (%s): fallback return"):format(playerId, tostring(why)))
                        fallbackReturn(playerId, racer)
                    end
                elseif opts.fallback then
                    fallbackReturn(playerId, racer)
                end
            end
        end
        if racers[playerId] == racer then racers[playerId] = nil end
        E.hooks.changed()
        retire(inst)
    end)
end
E.release = release

local function disqualify(inst, playerId, racer, reason, text)
    if racer.state == "finished" or racer.state == "dnf" or racer.state == "left" then return end
    racer.state, racer.dnfReason = "dnf", reason
    racer.ready = false
    if text then E.hooks.notice(playerId, "error", inst.label, text) end
    log(("player %d DNF in %s: %s"):format(playerId, inst.id, tostring(reason)))
end

-- ---------------------------------------------------------------- setup --

local function resetProgress(racer)
    racer.lap, racer.nextCheckpoint, racer.completed = 1, 1, 0
    racer.lapTimes, racer.bestLapMs, racer.lastLapMs = {}, nil, nil
    racer.finishedAt, racer.finishPlace, racer.timeMs, racer.outcome = nil, nil, nil, nil
    racer.lastCheckpointAt, racer.lastCheckpointIndex, racer.lastPosition = 0, nil, nil
    racer.dnfReason, racer.started, racer.resultSent = nil, false, false
    racer.ready, racer.placed, racer.assignRetryAt = false, false, nil
end

local function setupVehicle(inst, playerId, racer, slot)
    local spec = RaceCourses.vehicle(inst.course.vehicle) or RaceCourses.vehicle(Engine.vehicle.default)
    local vehicleId, reason = vehicleCall("create", {
        record = spec.record, position = S.clone(slot.position), yaw = slot.heading, bucket = inst.bucket,
        health = 1.0, flags = vehicleFlags(true),
        primaryColor = Engine.vehicle.primaryColor, secondaryColor = Engine.vehicle.secondaryColor,
    })
    local assigned = false
    if vehicleId ~= nil then
        racer.vehicleId = vehicleId
        scheduleSettle(inst, playerId, racer, vehicleId, slot, inst.run)
        local held
        held, reason = setHeld(vehicleId, true)
        if held then assigned, reason = assignDriver(playerId, racer) end
    end
    if not assigned then
        log(("grid setup failed player=%d: %s"):format(playerId, tostring(reason)))
        disqualify(inst, playerId, racer, vehicleId == nil and "vehicle_failed" or "driver_assignment_failed",
            vehicleId == nil and "Your car could not be created." or "You could not be seated in your car.")
        release(inst, playerId, racer, { viaCore = true, reason = "grid_failed" })
        return false
    end
    return true
end

local function placeRunner(inst, playerId, racer, slot)
    local run = inst.run
    racer.placing = true
    CreateThread(function()
        local promise, why = Open77.players.teleport(playerId, S.clone(slot.position), { heading = slot.heading,
            bucket = inst.bucket, fade = true, dismount = true, timeoutMs = Engine.teleportTimeoutMs })
        local placed
        if promise then placed, why = promise:await() end
        if racers[playerId] ~= racer or inst.run ~= run or instances[inst.id] ~= inst then return end
        racer.placing = false
        if placed then
            racer.placed = true
            holdRunner(inst, playerId, racer)
        else
            log(("runner %d could not reach the start: %s"):format(playerId, tostring(why)))
            disqualify(inst, playerId, racer, "placement_failed", "The start line did not load.")
            release(inst, playerId, racer, { viaCore = true, reason = "placement_failed" })
        end
    end)
end

-- restart: a trial run again on the same line, without a loading cover.
local function setupRacer(inst, playerId, racer, index, restart)
    racer.slotIndex = index
    racer.slot = S.gridSlot(inst.course, index, #inst.members + (inst.plannedBots or 0), Engine.startGrid, Engine.footStartSpacing)
    resetProgress(racer)
    racer.state = "loading"
    protect(playerId, racer)
    if not restart then
        E.hooks.cover(playerId, { title = inst.course.name, subtitle = inst.label, zone = "Race", target = racer.slot.position })
    end
    if S.onFoot(inst.course) then placeRunner(inst, playerId, racer, racer.slot)
    else setupVehicle(inst, playerId, racer, racer.slot) end
end

local function newInstance(def, course)
    local bucket = allocateBucket()
    if bucket == nil then return nil, "no_free_bucket" end
    instanceSequence = instanceSequence + 1
    return {
        id = def.key .. ":" .. instanceSequence, key = def.key, activityId = def.id, mode = def.mode, label = def.label,
        bucket = bucket, course = course, members = {}, racers = {}, finishOrder = {},
        phase = "loading", run = 1, lastFireworkAt = -math.huge, lastRankingAt = 0, lastSeatPollAt = 0, lastHoldAt = 0,
        lastProtectAt = 0,
    }
end

local function startLoading(inst, now, loadSeconds)
    inst.phase = "loading"
    inst.loadEndsAt = now + seconds(loadSeconds, 4)
    inst.readyEndsAt = now + seconds(math.max(Engine.readyTimeoutSeconds or 60, loadSeconds or 0), 60)
    inst.countdownEndsAt, inst.startedAt, inst.endsAt, inst.finishEndsAt = nil, nil, nil, nil
    inst.resolvedAt, inst.resultsEndsAt, inst.result = nil, nil, nil
    inst.finishOrder = {}
end

-- Admits the players (activityEnter, in grid order) and builds their grid. Players the
-- core refuses are told why and skipped. Returns the instance, or nil and a reason.
-- opts.fillTo (staff bot mode): bots take the slots behind the players up to that many
-- racers in total.
function E.start(def, course, playerIds, opts)
    if type(course) ~= "table" then return nil, "course_unavailable" end
    local inst, reason = newInstance(def, course)
    if inst == nil then return nil, reason end
    for _, playerId in ipairs(playerIds) do
        if racers[playerId] == nil then
            local before = Open77.players.position(playerId)
            local info = A.player(playerId)
            local entered, why = A.enter(playerId, def.id)
            if entered then
                local racer = {
                    playerId = playerId, instanceId = inst.id, activityId = def.id,
                    name = (info and info.name) or playerName(playerId), key = A.characterKey(info),
                    fallback = before and { x = before.x, y = before.y, z = before.z, heading = before.heading or 0,
                        bucket = before.bucket or 0 } or nil,
                    state = "loading",
                }
                inst.members[#inst.members + 1] = playerId
                inst.racers[playerId] = racer
                racers[playerId] = racer
            else
                E.hooks.notice(playerId, "error", def.label, why)
            end
        end
    end
    if #inst.members == 0 then
        bucketsInUse[inst.bucket] = nil
        return nil, "nobody_admitted"
    end
    instances[inst.id] = inst
    startLoading(inst, nowMs(), perMode(Engine.loadSeconds, inst.mode, 5))
    local fillTo = type(opts) == "table" and math.tointeger(tonumber(opts.fillTo)) or nil
    inst.plannedBots = (fillTo and inst.mode ~= "trial") and math.max(0, fillTo - #inst.members) or 0
    log(("instance %s: %s, %d racer(s)%s, bucket %d"):format(inst.id, course.id, #inst.members,
        inst.plannedBots > 0 and (" + %d bot(s)"):format(inst.plannedBots) or "", inst.bucket))
    for index, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racers[playerId] == racer then setupRacer(inst, playerId, racer, index) end
    end
    if inst.plannedBots > 0 and instances[inst.id] == inst then bots().fill(inst, inst.plannedBots) end
    pushInstance(inst)
    E.hooks.changed()
    return inst
end

-- ---------------------------------------------------------------- phases --

local function ready(inst, playerId, racer)
    if S.onFoot(inst.course) then
        -- Placed, alive, in the bucket and on the line (guardHolds keeps them there; the
        -- hold itself is not required here, GO is called after the phase changed).
        if not racer.placed or not alive(playerId) then return false end
        local p = Open77.players.position(playerId)
        if not p or p.bucket ~= inst.bucket then return false end
        return S.distance(p, racer.slot.position) < 2.0
    end
    if racer.vehicleId == nil then return false end
    local seat = seatOf(playerId)
    if seat == nil or tostring(seat.vehicleId) ~= tostring(racer.vehicleId)
        or tostring(seat.seat) ~= tostring(Engine.vehicle.driverSeat) then return false, false end
    if seat.exitLocked ~= true then
        if not vehicleCall("setPlayerExitLocked", playerId, true, racer.vehicleId) then return false, true end
    end
    return seat.forcedEntry ~= true and seat.entering ~= true and seat.exiting ~= true and seat.forcedExit ~= true, true
end
E.ready = ready

local function pollReady(inst, now)
    if now - inst.lastSeatPollAt < (Engine.seatPollMs or 500) then return nil end
    inst.lastSeatPollAt = now
    local readyCount, waiting, changed = 0, 0, false
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer.state == "loading" and racers[playerId] == racer then
            local ok, assigned = ready(inst, playerId, racer)
            if ok then
                readyCount = readyCount + 1
                if not racer.ready then racer.ready, changed = true, true end
            else
                if racer.ready then changed = true end
                racer.ready = false
                waiting = waiting + 1
                -- A seat that was never reserved is reserved again (Freeroam's grid retry).
                if not S.onFoot(inst.course) and assigned == false and racer.vehicleId and now >= (racer.assignRetryAt or 0) then
                    racer.assignRetryAt = now + 1000
                    assignDriver(playerId, racer)
                end
            end
        end
    end
    return readyCount, waiting, changed
end

local function guardHolds(inst, now)
    if now - inst.lastHoldAt < (Engine.holdCheckMs or 500) then return end
    inst.lastHoldAt = now
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racers[playerId] == racer and (racer.state == "loading" or racer.state == "countdown") then
            if S.onFoot(inst.course) then
                holdRunner(inst, playerId, racer)
            elseif racer.vehicleId then
                local ok, reason = setHeld(racer.vehicleId, true)
                if not ok and racer.state == "countdown" then
                    log(("grid hold failed player=%d: %s"):format(playerId, tostring(reason)))
                    disqualify(inst, playerId, racer, "grid_hold_failed", "Your car could not be held on the grid.")
                    release(inst, playerId, racer, { viaCore = true, reason = "grid_hold_failed" })
                end
            end
        end
    end
end

local function startCountdown(inst, now)
    inst.phase = "countdown"
    inst.countdownEndsAt = now + seconds(Engine.countdownSeconds, 3)
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer.state == "loading" and racer.ready then
            racer.state = "countdown"
            E.hooks.uncover(playerId)
        end
    end
    bots().countdown(inst, now)
    log(("instance %s countdown"):format(inst.id))
    pushInstance(inst)
end

local function go(inst, now)
    inst.phase = "active"
    inst.startedAt = now
    inst.endsAt = now + seconds(Engine.durationSeconds, 1200)
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer.state == "countdown" and racers[playerId] == racer then
            local seated = ready(inst, playerId, racer)
            local released, why = false, nil
            if seated then
                if S.onFoot(inst.course) then
                    released, why = Open77.players.setFrozen(playerId, false)
                    if released then racer.frozen = false end
                else
                    released, why = setHeld(racer.vehicleId, false)
                end
            end
            if seated and released then
                racer.state, racer.started = "racing", true
                racer.lapStartedAt, racer.graceUntil = now, now
                local p = Open77.players.position(playerId)
                racer.lastPosition = p and { x = p.x, y = p.y, z = p.z, bucket = p.bucket } or nil
                E.hooks.pulse(playerId, { kind = "go", instance = inst.id, run = inst.run })
            else
                if seated then log("GO release failed: " .. tostring(why)) end
                disqualify(inst, playerId, racer, seated and "grid_release_failed" or "not_on_grid",
                    seated and "Your start could not be released." or "You were not on the grid at GO.")
                release(inst, playerId, racer, { viaCore = true, reason = "go_failed" })
            end
        end
    end
    bots().go(inst, now)
    log(("instance %s GO"):format(inst.id))
    pushInstance(inst)
end

local function firework(inst, checkpoint, now)
    local spec = Config.presentation.checkpointFirework
    if type(spec) ~= "table" or spec.enabled == false then return end
    if now - inst.lastFireworkAt < (spec.minIntervalMs or 1500) then return end
    inst.lastFireworkAt = now
    local p = checkpoint.position
    local called, played, reason = pcall(Open77.effects.play, spec.effect or "race.firework.burst", {
        position = { x = p.x, y = p.y, z = p.z + (tonumber(spec.height) or 12.0) },
        bucket = inst.bucket, range = tonumber(spec.range) or 180.0,
    })
    if not called or not played then log("checkpoint firework unavailable: " .. tostring(called and reason or played)) end
end

-- Takes a finish place (players and bots share one finish order).
local function placeFinisher(inst, id, entrant, now)
    entrant.state = "finished"
    entrant.finishedAt = now
    entrant.timeMs = now - inst.startedAt
    inst.finishOrder[#inst.finishOrder + 1] = id
    entrant.finishPlace = #inst.finishOrder
end
E.placeFinisher = placeFinisher

-- After any finish: the race resolves when nothing is left to wait for; the first
-- finisher (player or bot) opens the finish window for the others.
local function afterFinish(inst, now)
    if settled(inst) then
        resolve(inst, "finished")
    elseif #inst.finishOrder == 1 then
        inst.finishEndsAt = now + seconds(Engine.finishGraceSeconds, 30)
        for _, memberId in ipairs(inst.members) do
            local member = inst.racers[memberId]
            if member.state == "racing" and racers[memberId] == member then
                E.hooks.notice(memberId, "warning", "FINISH WINDOW",
                    ("The leader finished. %d seconds to cross the line."):format(Engine.finishGraceSeconds))
            end
        end
    end
end
E.afterFinish = afterFinish

local function finish(inst, playerId, racer, now)
    placeFinisher(inst, playerId, racer, now)
    -- The time trial's board takes time-trial runs only, never a race that had bots in
    -- it. A race vs AI keeps its own best per course (a separate board), personal only.
    if inst.mode == "trial" and racer.key and not inst.hadBots then
        racer.outcome = RaceRecords.submit(inst.course.id, inst.course.revision, racer.key, racer.name,
            racer.timeMs, inst.course.vehicle)
    elseif inst.mode == "pve" and racer.key then
        local outcome = RaceRecords.submit(RaceRecords.vsAiBoard(inst.course.id), inst.course.revision, racer.key,
            racer.name, racer.timeMs, inst.course.vehicle)
        racer.outcome = outcome and { personalBest = outcome.personalBest, previousBestMs = outcome.previousBestMs,
            rank = outcome.rank } or nil
    end
    sendResult(inst, playerId, racer)
    E.hooks.pulse(playerId, { kind = "finish", place = racer.finishPlace, timeMs = racer.timeMs, outcome = racer.outcome,
        instance = inst.id, run = inst.run })
    log(("player %d finished %s P%d in %dms"):format(playerId, inst.id, racer.finishPlace, racer.timeMs))
    afterFinish(inst, now)
end

-- The bookkeeping of one validated checkpoint, the same for a player and a bot. Returns
-- "checkpoint", "lap" or "finish" and the checkpoint index; nil when debounced.
local function advance(inst, entrant, now)
    if now - (entrant.lastCheckpointAt or 0) < Engine.checkpointDebounceMs then return nil end
    local index = entrant.nextCheckpoint
    local count = #inst.course.checkpoints
    local checkpoint = inst.course.checkpoints[index]
    if checkpoint == nil then return nil end
    entrant.lastCheckpointAt, entrant.lastCheckpointIndex = now, index
    entrant.completed = (entrant.completed or 0) + 1
    firework(inst, checkpoint, now)
    if index == count then
        local lapTime = now - (entrant.lapStartedAt or inst.startedAt)
        entrant.lastLapMs = lapTime
        entrant.lapTimes[#entrant.lapTimes + 1] = lapTime
        if entrant.bestLapMs == nil or lapTime < entrant.bestLapMs then entrant.bestLapMs = lapTime end
        if entrant.lap >= inst.course.laps then return "finish", index end
        entrant.lap, entrant.nextCheckpoint, entrant.lapStartedAt = entrant.lap + 1, 1, now
        return "lap", index
    end
    entrant.nextCheckpoint = index + 1
    return "checkpoint", index
end
E.advance = advance

local function accept(inst, playerId, racer, now)
    local kind, index = advance(inst, racer, now)
    if kind == nil then return end
    if kind == "finish" then
        finish(inst, playerId, racer, now)
    elseif kind == "lap" then
        E.hooks.pulse(playerId, { kind = "lap", lap = racer.lap, laps = inst.course.laps, lastLapMs = racer.lastLapMs })
    else
        E.hooks.pulse(playerId, { kind = "checkpoint", completed = index, total = #inst.course.checkpoints, lap = racer.lap,
            laps = inst.course.laps, splitMs = now - inst.startedAt })
    end
    if instances[inst.id] == inst then pushInstance(inst) end
end

local function evaluate(inst, playerId, racer, now)
    if racer.state ~= "racing" or racer.returning or now < (racer.graceUntil or 0) then return false end
    if S.onFoot(inst.course) and seatOf(playerId) ~= nil then
        disqualify(inst, playerId, racer, "vehicle_in_foot_race", "Vehicles are not allowed in a foot race.")
        release(inst, playerId, racer, { viaCore = true, reason = "vehicle_in_foot_race" })
        return false
    end
    local checkpoint = inst.course.checkpoints[racer.nextCheckpoint]
    if checkpoint == nil then return false end
    local p = Open77.players.position(playerId)
    if p == nil or p.bucket ~= inst.bucket then return false end
    local radius = checkpoint.radius or inst.course.checkpointRadius or Engine.checkpointRadius
    local crossed = S.crossed(racer.lastPosition, p, checkpoint.position, radius, Engine.checkpointZTolerance, Engine.maxSegmentMetres)
    racer.lastPosition = { x = p.x, y = p.y, z = p.z, bucket = p.bucket }
    if crossed then accept(inst, playerId, racer, now) end
    return crossed
end
E.evaluate = evaluate

resolve = function(inst, reason)
    if inst.phase == "results" or inst.phase == "closing" then return end
    local now = nowMs()
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racer.state == "racing" or racer.state == "countdown" or racer.state == "loading" then
            racer.state, racer.dnfReason = "dnf", reason or "timeout"
        end
    end
    bots().resolve(inst, reason or "timeout", now)
    inst.phase = "results"
    inst.resolvedAt = now
    inst.resultsEndsAt = now + seconds(perMode(Engine.resultsSeconds, inst.mode, 12), 12)
    local winnerId = inst.finishOrder[1]
    local winner = winnerId and (inst.racers[winnerId] or bots().entrant(inst, winnerId)) or nil
    inst.result = { reason = reason or "finished", winnerName = winner and winner.name or nil,
        finishers = #inst.finishOrder, racers = startersOf(inst), bots = inst.hadBots and bots().starters(inst) or nil }
    for _, playerId in ipairs(inst.members) do sendResult(inst, playerId, inst.racers[playerId]) end
    log(("instance %s resolved: %s"):format(inst.id, tostring(reason)))
    pushInstance(inst)
    E.hooks.changed()
end
E.resolve = resolve

local function close(inst)
    if inst.phase == "closing" then return end
    inst.phase = "closing"
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if racers[playerId] == racer then release(inst, playerId, racer, { viaCore = true, reason = "results_complete" }) end
    end
    retire(inst)
end
E.close = close

function E.tick(now)
    now = now or nowMs()
    for _, inst in pairs(instances) do
        local reassert = now - inst.lastProtectAt >= 1000
        if reassert then inst.lastProtectAt = now end
        if reassert and inst.phase ~= "closing" then
            for _, playerId in ipairs(inst.members) do
                local racer = inst.racers[playerId]
                if racers[playerId] == racer and not racer.releasing then protect(playerId, racer) end
            end
        end
        if inst.phase == "loading" and not inst.restarting then
            guardHolds(inst, now)
            bots().tick(inst, now)
            local readyCount, waiting, changed = pollReady(inst, now)
            if readyCount ~= nil then
                if readyCount == 0 and waiting == 0 then
                    if allResolved(inst) then
                        inst.startedAt = now
                        resolve(inst, "grid_failed")
                    end
                elseif waiting == 0 and now >= inst.loadEndsAt then
                    -- bots still being seated get a short grace, then are dropped
                    if bots().readyForCountdown(inst, now) then startCountdown(inst, now) end
                elseif now >= inst.readyEndsAt then
                    for _, playerId in ipairs(inst.members) do
                        local racer = inst.racers[playerId]
                        if racer.state == "loading" and not racer.ready and racers[playerId] == racer then
                            disqualify(inst, playerId, racer, "grid_timeout", "Your start position was not confirmed in time.")
                            release(inst, playerId, racer, { viaCore = true, reason = "grid_timeout" })
                        end
                    end
                    if readyCount > 0 then startCountdown(inst, now) else inst.startedAt = now; resolve(inst, "grid_timeout") end
                elseif changed then
                    pushInstance(inst)
                end
            end
        elseif inst.phase == "countdown" then
            guardHolds(inst, now)
            bots().tick(inst, now)
            if now >= inst.countdownEndsAt then go(inst, now) end
        elseif inst.phase == "active" then
            for _, playerId in ipairs(inst.members) do
                local racer = inst.racers[playerId]
                if racers[playerId] == racer then evaluate(inst, playerId, racer, now) end
                if inst.phase ~= "active" then break end
            end
            if inst.phase == "active" then bots().tick(inst, now) end
            if inst.phase == "active" then
                if settled(inst) then resolve(inst, "no_active_racers")
                elseif inst.finishEndsAt and now >= inst.finishEndsAt then resolve(inst, "finish_window_expired")
                elseif now >= inst.endsAt then resolve(inst, "timeout")
                elseif fieldSize(inst) > 1 and now - inst.lastRankingAt >= (Engine.rankingPushMs or 1000) then
                    inst.lastRankingAt = now
                    pushInstance(inst)
                end
            end
        elseif inst.phase == "results" then
            if now >= inst.resultsEndsAt then close(inst) end
        end
    end
end

-- ---------------------------------------------------------------- players --

function E.racer(playerId) return racers[playerId] end
function E.instanceOf(playerId)
    local racer = racers[playerId]
    return racer and instances[racer.instanceId] or nil
end
function E.busy(playerId) return racers[playerId] ~= nil end

-- The player asked to quit (hub, F1, /leave, /race.leave). Forfeit, then back to Light RP.
function E.leave(playerId, reason)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if inst == nil or racer.releasing then return false end
    if racer.state ~= "finished" then
        racer.state, racer.dnfReason = racer.started and "dnf" or "left", reason or "left"
        if racer.started and inst.mode ~= "trial" then sendResult(inst, playerId, racer) end
    end
    release(inst, playerId, racer, { viaCore = true, reason = reason or "left" })
    if inst.phase == "active" and settled(inst) then resolve(inst, "finished") end
    E.hooks.changed()
    return true
end

-- The core released the player (disconnect, character switch, provider released):
-- clean up only, never call activityLeave.
function E.dropped(playerId, reason)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if inst == nil then return false end
    racer.dropped = true
    if racer.state ~= "finished" then racer.state, racer.dnfReason = racer.started and "dnf" or "left", reason or "dropped" end
    if racer.releasing then return true end
    release(inst, playerId, racer, { reason = "dropped" })
    if inst.phase == "active" and settled(inst) then resolve(inst, "finished") end
    return true
end

-- Gone from the server: remove the car now, forget the racer.
function E.disconnect(playerId)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if racer == nil then return false end
    racer.dropped = true
    if racer.vehicleId then removeVehicle(racer, "disconnect") end
    if racer.state ~= "finished" then racer.state, racer.dnfReason = racer.started and "dnf" or "left", "disconnect" end
    racers[playerId] = nil
    if inst then
        if inst.phase == "active" and settled(inst) then resolve(inst, "finished") end
        retire(inst)
    end
    E.hooks.changed()
    return true
end

-- Time trial: a fresh run on the same course, without leaving the activity.
function E.restart(playerId)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if inst == nil or inst.mode ~= "trial" or racer.releasing or inst.restarting then return false, "not_available" end
    if inst.phase ~= "countdown" and inst.phase ~= "active" and inst.phase ~= "results" then return false, "not_available" end
    inst.restarting = true
    inst.run = inst.run + 1
    local run = inst.run
    startLoading(inst, nowMs(), Engine.loadAfterRestartSeconds or 2)
    CreateThread(function()
        if racer.vehicleId then
            if forceExit(playerId, racer) then Wait(math.max(0, Engine.vehicle.exitSettleMs or 1500)) end
            removeVehicle(racer, "restart")
        end
        if racers[playerId] ~= racer or inst.run ~= run or instances[inst.id] ~= inst then return end
        if racer.frozen then Open77.players.setFrozen(playerId, false); racer.frozen = false end
        ensureAlive(inst, playerId, racer)
        local now = nowMs()
        startLoading(inst, now, Engine.loadAfterRestartSeconds or 2)
        inst.restarting = false
        setupRacer(inst, playerId, racer, racer.slotIndex or 1, true)
        pushInstance(inst)
    end)
    pushInstance(inst)
    return true
end

-- Foot races: back to the last validated checkpoint (the start before the first one).
-- Lap, progress and clock are kept.
function E.respawnAtCheckpoint(playerId)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if inst == nil or not S.onFoot(inst.course) or inst.phase ~= "active" or racer.state ~= "racing" then return false, "not_available" end
    if racer.returning or nowMs() < (racer.nextReturnAt or 0) then return false, "pending" end
    if not alive(playerId) then return false, "not_alive" end
    local point = lastPoint(inst, racer)
    local promise, why = Open77.players.teleport(playerId, S.clone(point.position), { heading = point.heading or 0,
        fade = true, fadeOutMs = 150, fadeInMs = 150, timeoutMs = Engine.teleportTimeoutMs })
    if not promise then return false, why end
    racer.returning, racer.lastPosition, racer.nextReturnAt = true, nil, nowMs() + 2000
    CreateThread(function()
        promise:await()
        if racers[playerId] ~= racer then return end
        racer.returning, racer.lastPosition = false, nil
        racer.graceUntil = nowMs() + 500
    end)
    return true
end

-- Life changes: runners on the grid are held again (death and respawn drop a freeze);
-- a racer who dies on foot is revived at the last checkpoint, clock running; a driver
-- who dies is out (the body is revived before going back).
function E.onLifeState(playerId)
    local racer = racers[playerId]
    local inst = racer and instances[racer.instanceId]
    if inst == nil or racer.releasing then return end
    if racer.state == "loading" or racer.state == "countdown" then
        if not alive(playerId) and S.onFoot(inst.course) then
            local life = Open77.players.getLifeState(playerId)
            if life and life.phase == "dead" then
                Open77.players.respawn(playerId, { position = S.clone(racer.slot.position), heading = racer.slot.heading,
                    bucket = inst.bucket, health = 1.0 })
            end
        end
        holdRunner(inst, playerId, racer)
        return
    end
    if racer.state ~= "racing" or inst.phase ~= "active" then return end
    local life = Open77.players.getLifeState(playerId)
    if not life or life.phase ~= "dead" or racer.recovering then return end
    if not S.onFoot(inst.course) then
        disqualify(inst, playerId, racer, "died", "You were wrecked. Race over.")
        release(inst, playerId, racer, { viaCore = true, reason = "died" })
        if settled(inst) then resolve(inst, "finished") end
        return
    end
    racer.recovering = true
    SetTimeout(500, function()
        racer.recovering = false
        if racers[playerId] ~= racer or inst.phase ~= "active" or racer.state ~= "racing" then return end
        local now = Open77.players.getLifeState(playerId)
        if not now or now.phase ~= "dead" then return end
        local point = lastPoint(inst, racer)
        local ok, reason = Open77.players.respawn(playerId, { position = S.clone(point.position), heading = point.heading or 0,
            bucket = inst.bucket, health = 1.0, graceMs = 3000 })
        if ok then
            racer.lastPosition, racer.graceUntil = nil, nowMs() + 1500
            protect(playerId, racer)
            E.hooks.notice(playerId, "info", inst.label, "Back at your last checkpoint. The clock keeps running.")
        else
            log(("foot recovery failed for %d: %s"):format(playerId, tostring(reason)))
        end
    end)
end

-- Every instance ends. viaCore: send the players back through the core (normal stop);
-- fallback: the core is gone, teleport them to where they stood before entering.
function E.stopAll(opts)
    for _, inst in pairs(instances) do
        inst.phase = "closing"
        bots().cleanup(inst, opts and opts.reason or "stop_all")
        for _, playerId in ipairs(inst.members) do
            local racer = inst.racers[playerId]
            if racers[playerId] == racer and not racer.releasing then release(inst, playerId, racer, opts) end
        end
    end
end

-- Resource stop: no thread survives, so only what can be undone at once is undone. The
-- core returns the players (the contract: a stopping provider's players are released).
function E.shutdown()
    bots().shutdown()
    for playerId, racer in pairs(racers) do
        if racer.vehicleId then removeVehicle(racer, "resource_stop") end
        if connected(playerId) then unprotect(playerId, racer) end
    end
end

-- Status for the core, per activity mode: running instances and players inside.
function E.count(mode)
    local running, players = 0, 0
    for _, inst in pairs(instances) do
        if inst.mode == mode and inst.phase ~= "closing" then
            running = running + 1
            for _, playerId in ipairs(inst.members) do
                local racer = inst.racers[playerId]
                if racers[playerId] == racer then players = players + 1 end
            end
        end
    end
    return running, players
end
