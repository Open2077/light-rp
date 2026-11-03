-- op77_chase server wiring: registration with Light RP, the queue, the contract events,
-- the commands and the tick. The rules live in rules.lua, the lifecycle in match.lua.
local C = ChaseConfig
local W = ChaseWorld
local Q = ChaseQueue

local function log(fmt, ...) print(("[op77_chase] " .. fmt):format(...)) end
local function validId(id)
    id = tonumber(id)
    if id == nil or id <= 0 or id % 1 ~= 0 then return nil end
    return math.tointeger(id)
end

-- ---------------------------------------------------------------- registration

local function publishStatus(force)
    ChaseCore.status(Chase.status(Q.size()), force)
end

local function register()
    local a = C.activity
    local ok, why = ChaseCore.register({ id = a.id, resource = GetCurrentResourceName(), label = a.label, kind = a.kind,
        description = a.description, minPlayers = a.minPlayers, maxPlayers = a.maxPlayers, caps = a.caps })
    if ok then
        log("registered %s with Light RP", a.id)
        -- Staff bot mode is Light RP's: its current value after every registration.
        if ChaseBots then ChaseBots.refresh() end
        publishStatus(true)
    else
        log("Light RP refused %s: %s", a.id, tostring(why))
    end
    return ok
end

-- Exports may not be called while this VM is still preparing: register from a thread,
-- and again whenever Light RP (re)starts (it forgets its providers when it stops).
CreateThread(function()
    for _ = 1, 30 do
        if register() then return end
        Wait(2000)
    end
end)

AddEventHandler("onResourceStart", function(name)
    if name == ChaseCore.resource then
        CreateThread(function() Wait(1000); register() end)
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        -- Light RP releases and returns our players itself; the cars go now.
        Chase.shutdown()
    elseif name == ChaseCore.resource then
        -- Light RP forgot us and returned everyone: void the matches, empty the queue.
        Chase.coreStopped(W.now())
        for _, entry in ipairs(Q.entries) do W.queueHud(entry.id, { queued = false }) end
        Q.reset()
        ChaseCore.resetStatus()
    end
end)

-- ---------------------------------------------------------------- queue

local noticeAt = {}

local function pushQueue()
    for i, entry in ipairs(Q.entries) do
        -- busy: Light RP refuses him right now (another activity): the client leaves its HUD alone.
        W.queueHud(entry.id, { activity = C.activity.id, queued = true, position = i, total = #Q.entries, mode = entry.mode,
            busy = entry.notReadySince ~= nil or nil })
    end
end

local function modeLabel(mode)
    if mode == "foot" then return "on foot" elseif mode == "vehicle" then return "by car" end
    return "car or foot"
end

local function dequeue(id, text)
    if not Q.remove(id) then return false end
    W.queueHud(id, { queued = false })
    if text then W.notify(id, "info", text, 5000) end
    pushQueue()
    publishStatus()
    return true
end

-- Queue a player. `checked`: Light RP already ran activityCheck (the hub join). `squad`:
-- his Light RP crew (options.squad), paired with him first.
local function enqueue(id, mode, checked, squad)
    if Chase.matchOf(id) then return false, "You are already in a chase." end
    -- One chase queue at a time (server/wanted_main.lua owns the Most Wanted side).
    if ChaseWantedMain and ChaseWantedMain.claims(id) then
        return false, "You are already queued for Most Wanted. /wanted leave first."
    end
    if ChasePveMain and ChasePveMain.claims(id) then
        return false, "You are already in NCPD Escape. /escape leave first."
    end
    mode = Q.normalizeMode(mode)
    local position, total = Q.position(id)
    if position then return true, ("You are already queued (%d/%d)."):format(position, total) end
    if not checked then
        local ok, why = ChaseCore.check(id)
        if not ok then return false, why end
    end
    position, total = Q.add(id, mode, W.now(), squad)
    pushQueue()
    publishStatus()
    local text = ("Queued for NCPD Chase (%s) - %d/%d. Keep playing, you will be pulled in when an opponent is found. /chase leave to cancel.")
        :format(modeLabel(mode), position, total)
    if ChaseBots and ChaseBots.fills(C.activity.id) then
        text = text .. " Bot mode: a bot takes the other side if nobody else is waiting."
    elseif ChaseBots and ChaseBots.refusal(C.activity.label) then
        text = text .. " " .. ChaseBots.refusal(C.activity.label)
    end
    W.notify(id, "info", text, 7000)
    return true, text
end

-- Staff bot mode, where config.bots.fill allows it (chase.1v1 is real players only by
-- default): the first ready player who has waited soloWaitSeconds (and whose crew is not
-- on its way) gets a bot. Human pairs always come first (tryPair).
local function tryBotMatch(now)
    if not (ChaseBots and ChaseBots.fills(C.activity.id)) then return false end
    local wait = ((C.bots or {}).soloWaitSeconds or 2) * 1000
    local holdMs = (C.queue.squadHoldSeconds or 10) * 1000
    for _, entry in ipairs(Q.entries) do
        if now - entry.since >= wait and not Q.held(entry, now, holdMs) and W.connected(entry.id) and ChaseCore.check(entry.id) then
            Q.remove(entry.id)
            local match, failedId, why = Chase.admitBot(entry.id, entry.mode or C.defaultMode, now)
            if match then
                W.queueHud(entry.id, { queued = false })
            elseif failedId == nil then
                Q.requeueFront(entry.id, entry.mode, now, entry.squad)
            else
                W.queueHud(entry.id, { queued = false })
                W.notify(entry.id, "warning", ("The chase could not start: %s"):format(tostring(why)), 6000)
            end
            pushQueue()
            return true
        end
    end
    return false
end

local function tryPair(now)
    for _, id in ipairs(Q.expire(now, (C.queue.timeoutSeconds or 900) * 1000)) do
        W.queueHud(id, { queued = false })
        W.notify(id, "info", "Nobody answered the chase queue in time. Queue again from the Crossing or with /chase.", 6000)
    end
    local pair, notReady, dropped = Q.pair(now, function(id)
        if not W.connected(id) then return false, "disconnected" end
        return ChaseCore.check(id)
    end, { dropAfterMs = (C.queue.notReadyDropSeconds or 120) * 1000, defaultMode = C.defaultMode,
        squadHoldMs = (C.queue.squadHoldSeconds or 10) * 1000 })
    for _, entry in ipairs(notReady) do
        if now - (noticeAt[entry.id] or -math.huge) >= (C.queue.notReadyNoticeSeconds or 30) * 1000 then
            noticeAt[entry.id] = now
            W.notify(entry.id, "warning", ("A chase opponent is waiting, but you can't go yet: %s"):format(tostring(entry.reason)), 6000)
        end
    end
    for _, entry in ipairs(dropped) do
        W.queueHud(entry.id, { queued = false })
        W.notify(entry.id, "info", ("You left the chase queue: %s"):format(tostring(entry.reason)), 6000)
    end
    if pair then
        local match, failedId, why = Chase.admit(pair.a, pair.b, pair.mode, now)
        if match then
            W.queueHud(pair.a, { queued = false })
            W.queueHud(pair.b, { queued = false })
        elseif failedId == nil then
            -- No free instance: both stay at the head of the queue.
            Q.requeueFront(pair.b, pair.modes[pair.b], now, pair.squads and pair.squads[pair.b])
            Q.requeueFront(pair.a, pair.modes[pair.a], now, pair.squads and pair.squads[pair.a])
        else
            W.queueHud(failedId, { queued = false })
            W.notify(failedId, "warning", ("The chase could not start: %s"):format(tostring(why)), 6000)
            local other = failedId == pair.a and pair.b or pair.a
            Q.requeueFront(other, pair.modes[other], now, pair.squads and pair.squads[other])
        end
        pushQueue()
    end
    local bot = (pair == nil) and tryBotMatch(now) or false
    if pair or bot or #notReady > 0 or #dropped > 0 then publishStatus() end
end

-- ---------------------------------------------------------------- Light RP events
-- Host-wide events raised by op77_lightrp with TriggerEvent. Never RegisterNetEvent'd:
-- a client cannot fire them.

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    local mode = type(options) == "table" and options.mode or nil
    local squad = type(options) == "table" and options.squad or nil
    local ok, text = enqueue(id, mode, true, squad)
    if not ok then W.notify(id, "warning", text, 5000) end
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    if dequeue(id, "You left the chase queue.") then return end
    Chase.leaveRequest(id, W.now())
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    dequeue(id)
    Chase.dropped(id, W.now(), reason)
    publishStatus()
end)

-- A queued player who switches character (or goes back to the selector) leaves the queue.
AddEventHandler("op77_lightrp:characterChanged", function(playerId)
    local id = validId(playerId)
    if id then dequeue(id) end
end)

-- The client says whether Light RP's activity HUD is up (client/main.lua): while it is,
-- this player's chase messages go to its feed (ChaseWorld.notify). It only ever changes
-- where this player's own messages are drawn.
RegisterNetEvent("op77_chase:hudFeed", function(on)
    local id = validId(source)
    if id == nil then return end
    W.hudFeed[id] = on == true or nil
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id == nil then return end
    noticeAt[id] = nil
    W.hudFeed[id] = nil
    dequeue(id)
    -- Light RP sends `dropped` for an owned player; this covers the order of the two.
    if Chase.matchOf(id) then Chase.dropped(id, W.now(), "disconnected") end
end)

-- ---------------------------------------------------------------- commands

local function describe(id)
    local match = Chase.matchOf(id)
    if match then
        local m = Chase.member(match, id)
        return ("Chase %d: %s, round %d/%d, you are the %s (%s)."):format(match.id, match.state, match.round,
            Chase.roundCount(match), tostring(match.roles[id]), m and m.name or "?")
    end
    local position, total, entry = Q.position(id)
    if position then return ("Queued for NCPD Chase (%s): %d/%d."):format(modeLabel(entry.mode), position, total) end
    return "You are not in the chase queue. /chase to queue (car), /chase foot for a foot chase."
end

-- /chase [car|foot|leave|status|top|rank]
RegisterCommand("chase", function(source, args, raw)
    local id = validId(source)
    if id == nil then W.reply(source, raw, false, "In game only.") return end
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "leave" or sub == "quit" or sub == "cancel" then
        if dequeue(id) then ChaseCore.unqueue(id); W.reply(id, raw, true, "You left the chase queue.") return end
        if Chase.leaveRequest(id, W.now()) then publishStatus(); W.reply(id, raw, true, "You left the chase.") return end
        W.reply(id, raw, false, "You are not queued or in a chase.")
    elseif sub == "status" then
        W.reply(id, raw, true, describe(id))
    elseif sub == "top" then
        CreateThread(function()
            local rows, saved = ChaseRanked.top()
            if #rows == 0 then W.reply(id, raw, true, "No chase ratings yet.") return end
            local parts = {}
            for i, r in ipairs(rows) do parts[#parts + 1] = ("%d. %s %d (%d-%d-%d)"):format(i, tostring(r.name), tonumber(r.rating) or 0,
                tonumber(r.wins) or 0, tonumber(r.losses) or 0, tonumber(r.draws) or 0) end
            W.reply(id, raw, true, "NCPD Chase ladder" .. (saved and "" or " (this session only)") .. ": " .. table.concat(parts, " | "))
        end)
    elseif sub == "rank" then
        CreateThread(function()
            local info = ChaseCore.player(id)
            if not info then W.reply(id, raw, false, "No active character.") return end
            local record = ChaseRanked.recordOf({ id = id, name = info.name, identifier = info.identifier, characterKey = info.characterKey })
            if not record then W.reply(id, raw, false, "No rating for this character.") return end
            W.reply(id, raw, true, ("%s: chase rating %d (peak %d) - %d played, %d won, %d busts, %d escapes.")
                :format(tostring(info.name), record.rating, record.peak or record.rating, record.matches or 0, record.wins or 0,
                    record.busts or 0, record.escapes or 0))
        end)
    else
        local mode = nil
        if sub ~= "" and sub ~= "join" and sub ~= "queue" then mode = sub end
        if mode ~= nil and Q.normalizeMode(mode) == nil then
            W.reply(id, raw, false, "usage: /chase [car|foot|leave|status|top|rank]") return
        end
        local ok, text = enqueue(id, mode, false)
        W.reply(id, raw, ok, text)
    end
end, false)

-- Staff (ACL command.chase.status / command.chase.force / command.chase.stop).
RegisterCommand("chase.status", function(source, _, raw)
    local lines = { ("queue %d, instances %d-%d"):format(Q.size(), C.buckets.from, C.buckets.to) }
    for i, entry in ipairs(Q.entries) do lines[#lines + 1] = ("  q%d: %d (%s)"):format(i, entry.id, tostring(entry.mode)) end
    for _, match in pairs(Chase.matches) do
        local who = {}
        for _, m in ipairs(match.members) do
            who[#who + 1] = ("%d=%s%s%s"):format(m.id, tostring(match.roles[m.id]), m.bot and "(bot)" or "",
                m.gone and "(gone)" or (m.released and "(home)" or ""))
        end
        lines[#lines + 1] = ("  match %d %s %s round %d/%d bucket %d score %s"):format(match.id, match.mode, match.state, match.round,
            Chase.roundCount(match), match.bucket, table.concat(who, " "))
    end
    W.reply(validId(source) or 0, raw, true, table.concat(lines, "\n"))
end, true)

RegisterCommand("chase.force", function(source, args, raw)
    local a, b = validId(args[1]), validId(args[2])
    if not a or not b or a == b then W.reply(validId(source) or 0, raw, false, "usage: chase.force <playerId> <playerId> [car|foot]") return end
    for _, id in ipairs({ a, b }) do
        local ok, why = ChaseCore.check(id)
        if not ok then W.reply(validId(source) or 0, raw, false, ("player %d: %s"):format(id, tostring(why))) return end
        Q.remove(id)
    end
    local match, failed, why = Chase.admit(a, b, Q.normalizeMode(args[3]) or C.defaultMode, W.now())
    pushQueue(); publishStatus()
    W.reply(validId(source) or 0, raw, match ~= nil, match and ("match %d started"):format(match.id)
        or ("refused (%s): %s"):format(tostring(failed), tostring(why)))
end, true)

-- Staff (ACL command.chase.bots): bot mode (switched by Light RP's /lightrp.bots) and every
-- live bot of this resource (1v1, Most Wanted, NCPD Escape).
RegisterCommand("chase.bots", function(source, _, raw)
    if not ChaseBots then W.reply(validId(source) or 0, raw, false, "bots are not loaded") return end
    W.reply(validId(source) or 0, raw, true, table.concat(ChaseBots.describe(), "\n"))
end, true)

RegisterCommand("chase.stop", function(source, args, raw)
    local matchId = tonumber(args[1])
    local match = matchId and Chase.matches[matchId]
    if not match then W.reply(validId(source) or 0, raw, false, "usage: chase.stop <matchId> (see chase.status)") return end
    Chase.abort(match, W.now(), "Stopped by staff. Nothing counts.")
    W.reply(validId(source) or 0, raw, true, ("match %d stopped"):format(match.id))
end, true)

-- ---------------------------------------------------------------- tick

CreateThread(function()
    local tickMs = math.floor(1000 / math.max(1, C.tickHz or 5))
    local lastPair, lastStatus = 0, 0
    while true do
        Wait(tickMs)
        local now = W.now()
        Chase.tick(now)
        if now - lastPair >= 1000 then
            lastPair = now
            local ok, err = pcall(tryPair, now)
            if not ok then log("pairing error: %s", tostring(err)) end
        end
        if now - lastStatus >= 1000 then
            lastStatus = now
            publishStatus()
        end
    end
end)

-- For server/wanted_main.lua: one chase queue at a time.
ChaseMain = {
    claims = function(id) return Q.has(id) or Chase.matchOf(id) ~= nil end,
    dequeue = function(id, text) return dequeue(id, text) end,
}

log("loaded (%s, buckets %d-%d)", C.activity.id, C.buckets.from, C.buckets.to)
