-- Voice calls: direct and group, ringing, a native "phone" voice channel per
-- call, blue holocall eyes while connected, mute, adding participants, and the
-- call history of everyone involved.
--
-- One call = { id, group, channel, startedAt, participants = { [lineId] = p } }
-- p = { lineId, number, name, playerId, state = "ringing"|"connected"|"left",
--       muted, caller, joinedAt, outcome, ring, ringTimer }
-- A line is in at most one call at a time (lineCall).
local C, Lines = NeuralConfig, Neural.lines
local Calls = {}
Neural.calls = Calls

local calls, lineCall = {}, {}
local nextId = 1

local function log(...) Neural.log(...) end

local function connectedCount(call)
    local n = 0
    for _, p in pairs(call.participants) do if p.state == "connected" then n = n + 1 end end
    return n
end

local function ringingCount(call)
    local n = 0
    for _, p in pairs(call.participants) do if p.state == "ringing" then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------------------
-- What each participant's page sees

function Calls.stateFor(playerId)
    local s = Lines.session(playerId)
    if not s then return nil end
    local call = calls[lineCall[s.line.id]]
    if not call then return nil end
    local me = call.participants[s.line.id]
    if not me or me.state == "left" then return nil end
    local phase
    if me.state == "ringing" then phase = "incoming"
    elseif connectedCount(call) >= 2 then phase = "active"
    else phase = "outgoing" end
    local list = {}
    for lineId, p in pairs(call.participants) do
        if p.state ~= "left" or lineId == s.line.id then
            list[#list + 1] = {
                lineId = tostring(lineId), number = p.number, name = Lines.nameFor(playerId, p.number),
                state = p.state, muted = p.muted == true, isMe = lineId == s.line.id,
                playerId = p.playerId,
            }
        end
    end
    table.sort(list, function(a, b) if a.isMe ~= b.isMe then return a.isMe end return a.name:lower() < b.name:lower() end)
    local participantsLimit = C.limits.callParticipants
    local active = 0
    for _, p in pairs(call.participants) do if p.state ~= "left" then active = active + 1 end end
    return {
        id = call.id, phase = phase, startedAt = call.startedAt, muted = me.muted == true,
        group = call.group, participants = list,
        canAdd = me.state == "connected" and active < participantsLimit,
    }
end

local function broadcast(call)
    for _, p in pairs(call.participants) do
        if p.playerId and Lines.session(p.playerId) and lineCall[p.lineId] == call.id then
            Neural.push(p.playerId, "nl:call", Calls.stateFor(p.playerId))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Ringing: a networked 3D chime that follows the callee

local function stopRing(p)
    if p.ring then
        pcall(StopSound, p.ring)
        pcall(DestroySound, p.ring)
        p.ring = nil
    end
end

local function startRing(p)
    stopRing(p)
    local s = Lines.session(p.playerId)
    if not s then return end
    local settings = s.line.settings
    if settings.dnd or settings.ringtone == "silent" then return end
    local tone = C.ringtones[settings.ringtone] or C.ringtones.aurora
    local position = Open77.players.position(p.playerId)
    if not position then return end
    local id, why = Play3DSound(tone.file, { x = position.x, y = position.y, z = position.z }, {
        network = true, bucket = position.bucket or GetPlayerRoutingBucket(p.playerId) or 0,
        loop = true, duration = tone.duration, volume = math.max(0.05, settings.volume or 0.8),
        minDistance = C.calls.ring.minDistance, maxDistance = C.calls.ring.maxDistance,
    })
    if not id then log("ringtone failed for player %d: %s", p.playerId, tostring(why)) return end
    p.ring = id
end

-- Keeps every ringtone on its callee while they walk.
CreateThread(function()
    while true do
        Wait(400)
        for _, call in pairs(calls) do
            for _, p in pairs(call.participants) do
                if p.ring and p.playerId then
                    local position = Open77.players.position(p.playerId)
                    if position then pcall(SetSoundPosition, p.ring, { x = position.x, y = position.y, z = position.z }) end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Voice channel and holocall eyes

local function ensureChannel(call)
    if call.channel then return true end
    local channel, why = Open77.voice.createChannel({
        name = "Neural-Link " .. call.id, mode = "phone", persistent = false, effect = C.calls.effect,
    })
    if not channel then log("voice channel failed for call %d: %s", call.id, tostring(why)) return false end
    call.channel = channel.id
    return true
end

local function joinVoice(call, p)
    if not ensureChannel(call) or not p.playerId then return end
    local ok, why = Open77.voice.addPlayer(call.channel, p.playerId, { canSpeak = not p.muted, canListen = true })
    if not ok then log("voice join failed (call %d, player %d): %s", call.id, p.playerId, tostring(why)) end
    p.inVoice = true
    Neural.refreshEyes(p.playerId)
end

local function leaveVoice(call, p)
    if call.channel and p.playerId then pcall(Open77.voice.removePlayer, call.channel, p.playerId) end
    p.inVoice = false
    if p.playerId then Neural.refreshEyes(p.playerId) end
end

-- Is this player talking in a call right now (for the holocall eyes)?
function Calls.isConnected(playerId)
    local s = Lines.session(playerId)
    local call = s and calls[lineCall[s.line.id]]
    local p = call and call.participants[s.line.id]
    return p ~= nil and p.state == "connected" and p.inVoice == true
end

-- ---------------------------------------------------------------------------
-- Ending

local function duration(call, p)
    if not p.joinedAt then return 0 end
    return math.max(0, (Neural.nowMs() - p.joinedAt) / 1000)
end

-- The history line of one participant, written once, when they leave the call.
local function record(call, p)
    if p.recorded then return end
    p.recorded = true
    local label = call.group and call.group.title or nil
    local peer = ""
    if not call.group then
        for id, other in pairs(call.participants) do if id ~= p.lineId then peer = other.number end end
    end
    local direction = p.caller and "out" or "in"
    local status
    if p.joinedAt then
        status = "answered"
    elseif p.caller then
        status = (p.outcome == "declined" or p.outcome == "busy") and p.outcome or "unavailable"
    else
        status = p.outcome == "declined" and "declined" or "missed"
    end
    Lines.logCall(p.lineId, peer, direction, status, p.joinedAt and duration(call, p) or 0, label)
end

local function finish(call, reason)
    if call.finished then return end
    call.finished = true
    for _, p in pairs(call.participants) do
        stopRing(p)
        if p.ringTimer then p.ringTimer = nil end
        if p.state == "ringing" then p.outcome = p.outcome or "missed" end
        if p.caller and not p.joinedAt and reason == "declined" then p.outcome = "declined" end
        -- someone who already left was told when they left: no second end card
        local stillIn = p.state ~= "left"
        if stillIn then
            leaveVoice(call, p)
            record(call, p)
            p.state = "left"
        end
        if lineCall[p.lineId] == call.id then lineCall[p.lineId] = nil end
        if stillIn and p.playerId and Lines.session(p.playerId) then
            Neural.push(p.playerId, "nl:call", nil)
            local other
            for id, o in pairs(call.participants) do if id ~= p.lineId then other = other or o end end
            Neural.push(p.playerId, "nl:callEnded", {
                reason = p.endReason or reason,
                number = call.group and nil or (other and other.number),
                name = call.group and call.group.title or (other and Lines.nameFor(p.playerId, other.number)),
                duration = p.joinedAt and math.floor(duration(call, p)) or 0,
            })
            if p.outcome == "missed" and not p.caller then
                Neural.notifyMissedCall(p.playerId, call)
            end
        end
    end
    if call.channel then pcall(Open77.voice.removeChannel, call.channel) end
    calls[call.id] = nil
end

-- A participant leaves (hang up, decline, drop); the call ends when it no longer makes sense.
local function leave(call, lineId, outcome, endReason)
    local p = call.participants[lineId]
    if not p or p.state == "left" then return end
    stopRing(p)
    if p.state == "connected" then leaveVoice(call, p) end
    p.outcome = p.outcome or outcome
    p.endReason = endReason
    p.state = "left"
    record(call, p)
    if lineCall[lineId] == call.id then lineCall[lineId] = nil end
    if p.playerId and Lines.session(p.playerId) then
        Neural.push(p.playerId, "nl:call", nil)
        local other
        for id, o in pairs(call.participants) do if id ~= lineId then other = other or o end end
        Neural.push(p.playerId, "nl:callEnded", {
            reason = endReason or "hangup",
            number = call.group and nil or (other and other.number),
            name = call.group and call.group.title or (other and Lines.nameFor(p.playerId, other.number)),
            duration = p.joinedAt and math.floor(duration(call, p)) or 0,
        })
        if p.outcome == "missed" and not p.caller then Neural.notifyMissedCall(p.playerId, call) end
    end
    local connected, ringing = connectedCount(call), ringingCount(call)
    if connected + ringing < 2 or (connected < 2 and not call.startedAt and ringing == 0) or connected == 0 then
        -- the caller alone, or nobody left talking: everyone else gets the right end reason
        local reason = "hangup"
        if not call.startedAt then
            if outcome == "declined" then reason = "declined" else reason = "no_answer" end
        end
        finish(call, reason)
    else
        broadcast(call)
    end
end

-- ---------------------------------------------------------------------------
-- Ringing participants

local function ring(call, line, caller)
    local pid = Lines.playerOfLine(line.id)
    local p = { lineId = line.id, number = line.number, name = line.name, playerId = pid, state = "ringing", muted = false }
    call.participants[line.id] = p
    lineCall[line.id] = call.id
    startRing(p)
    local token = {}
    p.ringTimer = token
    SetTimeout(C.calls.ringSeconds * 1000, function()
        if calls[call.id] == call and p.ringTimer == token and p.state == "ringing" then
            leave(call, line.id, "missed", "missed")
            if not call.finished then broadcast(call) end
        end
    end)
end

local function newCall(group)
    local call = { id = nextId, group = group, participants = {}, createdAt = Neural.nowMs() }
    nextId = nextId + 1
    calls[call.id] = call
    return call
end

local function addCaller(call, s)
    call.participants[s.line.id] = { lineId = s.line.id, number = s.line.number, name = s.line.name,
        playerId = s.playerId, state = "connected", muted = false, caller = true }
    lineCall[s.line.id] = call.id
end

-- Can this line be rung right now? Logs the refusal on both sides when it cannot.
local function reachable(s, line, label)
    local pid = Lines.playerOfLine(line.id)
    if not pid or not Lines.isInstalled(pid) then return false, "unavailable" end
    if lineCall[line.id] then
        Lines.logCall(line.id, s.line.number, "in", "missed", 0, label)
        local busy = Lines.session(pid)
        if busy then Neural.notifyMissedCall(pid, { group = label and { title = label } or nil }, s.line.number) end
        return false, "busy"
    end
    return true
end

function Calls.dial(playerId, args)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    if lineCall[s.line.id] then return nil, "in_call" end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    if args.number == s.line.number then return nil, "self" end
    if not Neural.allow(playerId, "dial") then return nil, "rate_limited" end
    local line, err = Lines.lineByNumber(args.number)
    if line == nil then return nil, err end
    if not line then return nil, "unknown_number" end
    local ok, why = reachable(s, line)
    if not ok then
        Lines.logCall(s.line.id, line.number, "out", why, 0)
        return nil, why
    end
    local call = newCall(nil)
    addCaller(call, s)
    ring(call, line, s)
    broadcast(call)
    return {}
end

function Calls.dialGroup(playerId, args)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    if lineCall[s.line.id] then return nil, "in_call" end
    if not Neural.allow(playerId, "dial") then return nil, "rate_limited" end
    local ids, thread = Neural.messages.groupLines(playerId, args.threadId)
    if not ids then return nil, thread end
    local lines = Lines.linesByIds(ids)
    local group = { threadId = thread.id, title = thread.title or "Group" }
    local call = newCall(group)
    addCaller(call, s)
    local rung = 0
    for _, id in ipairs(ids) do
        if id ~= s.line.id and lines[id] and rung < C.limits.callParticipants - 1 then
            if reachable(s, lines[id], group.title) then
                ring(call, lines[id], s)
                rung = rung + 1
            end
        end
    end
    if rung == 0 then
        calls[call.id] = nil
        lineCall[s.line.id] = nil
        Lines.logCall(s.line.id, "", "out", "unavailable", 0, group.title)
        return nil, "unavailable"
    end
    broadcast(call)
    return {}
end

local function myCall(playerId)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    local call = calls[lineCall[s.line.id]]
    if not call then return nil, "no_call" end
    return call, s
end

function Calls.accept(playerId)
    local call, s = myCall(playerId)
    if not call then return nil, s end
    local p = call.participants[s.line.id]
    if p.state ~= "ringing" then return nil, "no_call" end
    stopRing(p)
    p.ringTimer = nil
    p.state = "connected"
    p.playerId = playerId
    local now = Neural.nowMs()
    p.joinedAt = now
    if not call.startedAt then call.startedAt = now end
    for _, other in pairs(call.participants) do
        if other.state == "connected" then
            other.joinedAt = other.joinedAt or now
            joinVoice(call, other)
        end
    end
    broadcast(call)
    return {}
end

function Calls.decline(playerId)
    local call, s = myCall(playerId)
    if not call then return nil, s end
    local p = call.participants[s.line.id]
    if p.state ~= "ringing" then return nil, "no_call" end
    leave(call, s.line.id, "declined", "declined")
    return {}
end

function Calls.hangup(playerId)
    local call, s = myCall(playerId)
    if not call then return nil, s end
    local p = call.participants[s.line.id]
    if p.state == "ringing" then
        leave(call, s.line.id, "declined", "declined")
    elseif p.caller and not call.startedAt then
        -- the caller gives up before anyone answered: everybody still ringing missed it
        p.endReason = "hangup"
        finish(call, "missed")
    else
        leave(call, s.line.id, nil, "hangup")
    end
    return {}
end

function Calls.mute(playerId, args)
    local call, s = myCall(playerId)
    if not call then return nil, s end
    local p = call.participants[s.line.id]
    p.muted = args.muted == true
    if call.channel and p.state == "connected" then
        pcall(Open77.voice.setChannelPlayerPermissions, call.channel, playerId, { canSpeak = not p.muted, canListen = true })
    end
    broadcast(call)
    return {}
end

function Calls.add(playerId, args)
    local call, s = myCall(playerId)
    if not call then return nil, s end
    if call.participants[s.line.id].state ~= "connected" then return nil, "no_call" end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    local active = 0
    for _, p in pairs(call.participants) do if p.state ~= "left" then active = active + 1 end end
    if active >= C.limits.callParticipants then return nil, "group_full" end
    local line, err = Lines.lineByNumber(args.number)
    if line == nil then return nil, err end
    if not line then return nil, "unknown_number" end
    if call.participants[line.id] and call.participants[line.id].state ~= "left" then return nil, "already_member" end
    local ok, why = reachable(s, line, call.group and call.group.title)
    if not ok then return nil, why end
    ring(call, line, s)
    broadcast(call)
    return {}
end

-- Test harness (restricted command): an offline line rings a player's line.
-- The caller has no player, so it never joins the voice channel.
function Calls.inject(fromLine, toLine)
    if lineCall[toLine.id] then return nil, "busy" end
    if not Lines.playerOfLine(toLine.id) then return nil, "unavailable" end
    local call = newCall(nil)
    call.participants[fromLine.id] = { lineId = fromLine.id, number = fromLine.number, name = fromLine.name,
        playerId = nil, state = "connected", muted = false, caller = true }
    lineCall[fromLine.id] = call.id
    ring(call, toLine, nil)
    broadcast(call)
    return call.id
end

-- The player's line goes away (disconnect, character switch, replaced): drop them.
function Calls.onDetach(playerId)
    local s = Lines.session(playerId)
    if not s then return end
    local call = calls[lineCall[s.line.id]]
    if not call then return end
    local p = call.participants[s.line.id]
    if p.caller and not call.startedAt then
        finish(call, "dropped")
    else
        leave(call, s.line.id, p.state == "ringing" and "missed" or nil, "dropped")
    end
end

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, call in pairs(calls) do
        for _, p in pairs(call.participants) do
            stopRing(p)
            if p.state == "connected" then leaveVoice(call, p) end
        end
    end
end)
