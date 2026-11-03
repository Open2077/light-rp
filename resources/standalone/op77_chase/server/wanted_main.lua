-- op77_chase Most Wanted wiring: its own activity (chase.wanted) next to the 1v1, its
-- lobby, the contract events for that id, the /wanted commands and the tick. The rules
-- live in wanted_rules.lua, the lifecycle in wanted.lua, the lobby in wanted_lobby.lua.
local C = ChaseConfig
local WC = ChaseConfig.wanted
local W = ChaseWorld
local L = ChaseWantedLobby
local MW = ChaseWanted
local AID = WC.activity.id

local function log(fmt, ...) print(("[op77_chase] wanted " .. fmt):format(...)) end
local function validId(id)
    id = tonumber(id)
    if id == nil or id <= 0 or id % 1 ~= 0 then return nil end
    return math.tointeger(id)
end
local function notify(id, kind, text, ms) W.notify(id, kind, text, ms, "Most Wanted") end

-- ---------------------------------------------------------------- registration

local function countdownLeft(now)
    if L.countdownEndsAtMs == nil then return nil end
    return math.max(0, L.countdownEndsAtMs - (now or W.now()))
end

local function publishStatus(force)
    ChaseCore.status(MW.status(L.size(), countdownLeft()), force, AID)
end

local function register()
    local a = WC.activity
    local ok, why = ChaseCore.register({ id = a.id, resource = GetCurrentResourceName(), label = a.label, kind = a.kind,
        description = a.description, minPlayers = a.minPlayers, maxPlayers = a.maxPlayers, caps = a.caps })
    if ok then
        log("registered %s with Light RP", a.id)
        if ChaseBots then ChaseBots.refresh() end
        publishStatus(true)
    else
        log("Light RP refused %s: %s", a.id, tostring(why))
    end
    return ok
end

CreateThread(function()
    for _ = 1, 30 do
        if register() then return end
        Wait(2000)
    end
end)

-- ---------------------------------------------------------------- lobby

local noticeAt = {}
local lastAnnounceMs = nil

local function modeLabel(mode)
    if mode == "foot" then return "runner on foot" elseif mode == "vehicle" then return "car chase" end
    return "car or foot"
end

local function pushQueue(now)
    now = now or W.now()
    local left = countdownLeft(now)
    for i, entry in ipairs(L.entries) do
        -- busy: Light RP refuses him right now (another activity): the client leaves its HUD alone.
        W.queueHud(entry.id, { activity = AID, queued = true, position = i, total = #L.entries, mode = entry.mode,
            min = MW.minPlayers(), max = WC.maxPlayers, countdownMs = left, busy = entry.notReadySince ~= nil or nil })
    end
    for _, match in pairs(MW.matches) do
        for _, pending in ipairs(match.pending) do
            W.queueHud(pending.id, { activity = AID, queued = true, joining = true, matchId = match.id,
                round = match.round, roundCount = MW.roundCount(match) })
        end
    end
end

-- Out of the lobby (or of a match's drop-in list). Returns true if he was in either.
local function dequeue(id, text)
    local was = L.remove(id)
    was = MW.cancelPending(id) or was
    if not was then return false end
    if L.size() < MW.minPlayers() then L.countdownEndsAtMs = nil end
    W.queueHud(id, { activity = AID, queued = false })
    if text then notify(id, "info", text, 5000) end
    pushQueue()
    publishStatus()
    return true
end

local function claims(id)
    return L.has(id) or MW.matchOf(id) ~= nil or MW.pendingMatch(id) ~= nil
end

local function botMode() return ChaseBots ~= nil and ChaseBots.enabled == true end

-- `checked`: Light RP already ran activityCheck (the hub join). `squad`: the crew the
-- player joined with (Light RP options.squad).
local function enqueue(id, mode, checked, squad)
    if MW.matchOf(id) then return false, "You are already in Most Wanted." end
    if MW.pendingMatch(id) then return true, "You join Most Wanted at its next round." end
    if ChaseMain and ChaseMain.claims(id) then
        return false, "You are in the NCPD Chase queue. /chase leave first."
    end
    if ChasePveMain and ChasePveMain.claims(id) then
        return false, "You are in NCPD Escape. /escape leave first."
    end
    local requested = mode
    mode = WantedRules.normalizeMode(mode)
    if requested ~= nil and requested ~= "" and mode == nil then return false, "usage: /wanted [car|foot|leave|status]" end
    local position, total = L.position(id)
    if position then return true, ("You are already queued for Most Wanted (%d/%d)."):format(position, total) end
    if not checked then
        local ok, why = ChaseCore.check(id, AID)
        if not ok then return false, why end
    end
    position, total = L.add(id, mode, W.now(), squad)
    pushQueue()
    publishStatus()
    local text = ("Queued for Most Wanted (%s) - %d/%d, %d needed. Keep playing: you are pulled in when it starts. /wanted leave to cancel.")
        :format(modeLabel(mode), position, total, MW.minPlayers())
    if botMode() then
        text = ("Queued for Most Wanted (%s) - bot mode: bots fill the match, it starts in a few seconds. /wanted leave to cancel.")
            :format(modeLabel(mode))
    end
    notify(id, "info", text, 7000)
    return true, text
end

local function ready(id)
    if not W.connected(id) then return false, "disconnected" end
    return ChaseCore.check(id, AID)
end

local function notices(now, notReady, dropped)
    for _, entry in ipairs(notReady or {}) do
        if now - (noticeAt[entry.id] or -math.huge) >= (WC.lobby.notReadyNoticeSeconds or 30) * 1000 then
            noticeAt[entry.id] = now
            notify(entry.id, "warning", ("Most Wanted is waiting for you, but you can't go yet: %s"):format(tostring(entry.reason)), 6000)
        end
    end
    for _, entry in ipairs(dropped or {}) do
        W.queueHud(entry.id, { activity = AID, queued = false })
        notify(entry.id, "info", ("You left the Most Wanted queue: %s"):format(tostring(entry.reason)), 6000)
    end
end

-- Back to the head of the lobby (a drop-in that never got in, through no fault of his).
MW.onBounce = function(id, text)
    if not W.connected(id) then return end
    L.requeueFront({ id }, nil, W.now())
    if text then notify(id, "info", text, 6000) end
end

MW.onRefused = function(id)
    W.queueHud(id, { activity = AID, queued = false })
end

local function lobbyTick(now)
    local changed = false
    for _, id in ipairs(L.expire(now, (WC.lobby.timeoutSeconds or 900) * 1000)) do
        W.queueHud(id, { activity = AID, queued = false })
        notify(id, "info", "Most Wanted did not fill in time. Queue again from the Crossing or with /wanted.", 6000)
        changed = true
    end
    local dropAfterMs = (WC.lobby.notReadyDropSeconds or 120) * 1000
    local squadHoldMs = (WC.lobby.squadHoldSeconds or 10) * 1000
    -- Staff bot mode: one ready player is enough, a short countdown, bots fill the rest.
    local bots = botMode() and (ChaseConfig.bots or {}).wanted or nil

    -- A running match with a free seat takes queued players at its next round.
    local matchIds = {}
    for id in pairs(MW.matches) do matchIds[#matchIds + 1] = id end
    table.sort(matchIds)
    for _, matchId in ipairs(matchIds) do
        local match = MW.matches[matchId]
        local seats = match and MW.dropInSeats(match) or 0
        if seats > 0 and L.size() > 0 then
            local ids, notReady, dropped, squads = L.take(now, ready, seats, dropAfterMs, squadHoldMs)
            notices(now, notReady, dropped)
            for _, id in ipairs(ids) do
                MW.offer(match, id, squads[id])
                notify(id, "success", ("A Most Wanted match is on: you join it at the next round (round %d/%d now)."):format(match.round,
                    MW.roundCount(match)), 6000)
                log("match %d: %d waits for the next round", match.id, id)
            end
            changed = changed or #ids > 0 or #dropped > 0
        end
    end

    local start, notReady, dropped = L.poll(now, ready, { min = MW.minPlayers(), max = WC.maxPlayers,
        countdownMs = ((bots and bots.countdownSeconds) or WC.lobby.countdownSeconds or 45) * 1000, dropAfterMs = dropAfterMs,
        defaultMode = WC.defaultMode, allowSolo = bots ~= nil, squadHoldMs = squadHoldMs })
    notices(now, notReady, dropped)
    changed = changed or #dropped > 0
    if L.countdownStarted then
        L.countdownStarted = nil
        changed = true
        local seconds = math.ceil((countdownLeft(now) or 0) / 1000)
        for _, entry in ipairs(L.entries) do
            notify(entry.id, "info", ("Most Wanted starts in %ds with %d players%s - more can still join."):format(seconds, L.size(),
                bots and " and bots" or ""), 6000)
        end
        local every = (WC.lobby.announceEverySeconds or 300) * 1000
        if not bots and WC.lobby.announce ~= false and (lastAnnounceMs == nil or now - lastAnnounceMs >= every) then
            lastAnnounceMs = now
            W.announce(("Most Wanted starts in %ds - %d/%d players. Join from the Crossing or with /wanted."):format(seconds,
                L.size(), WC.maxPlayers), { activity = AID, kind = "chase" })
        end
    end
    if start then
        changed = true
        local match, why, refused, entered = MW.admit(start.ids, start.mode, now,
            { squads = start.squads, fill = bots and (bots.players or 3) or nil })
        for _, r in ipairs(refused or {}) do
            W.queueHud(r.id, { activity = AID, queued = false })
            notify(r.id, "warning", ("You could not join Most Wanted: %s"):format(tostring(r.why)), 6000)
        end
        if match then
            for _, id in ipairs(start.ids) do W.queueHud(id, { activity = AID, queued = false }) end
            for _, id in ipairs(match.order) do noticeAt[id] = nil end
        elseif why == "busy" then
            log("every Most Wanted instance is busy; %d player(s) stay at the head of the lobby", #start.ids)
            L.requeueFront(start.ids, start.modes, now, start.squads)
        else
            -- Too many refused at the door: the others wait for the next countdown.
            L.requeueFront(entered or {}, start.modes, now, start.squads)
        end
    end
    if changed or L.size() > 0 then pushQueue(now) end
    return changed
end

-- ---------------------------------------------------------------- lifecycle events

AddEventHandler("onResourceStart", function(name)
    if name == ChaseCore.resource then
        CreateThread(function() Wait(1500); register() end)
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        MW.shutdown()
    elseif name == ChaseCore.resource then
        MW.coreStopped(W.now())
        for _, entry in ipairs(L.entries) do W.queueHud(entry.id, { activity = AID, queued = false }) end
        L.reset()
    end
end)

-- Host-wide events from op77_lightrp (TriggerEvent; never RegisterNetEvent'd).
AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    local mode = type(options) == "table" and options.mode or nil
    local squad = type(options) == "table" and options.squad or nil
    local ok, text = enqueue(id, mode, true, squad)
    if not ok then notify(id, "warning", text, 5000) end
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    if dequeue(id, "You left the Most Wanted queue.") then return end
    if MW.leaveRequest(id, W.now()) then notify(id, "info", "You left Most Wanted. The match goes on without you.", 5000) end
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    dequeue(id)
    MW.dropped(id, W.now(), reason)
    publishStatus()
end)

AddEventHandler("op77_lightrp:characterChanged", function(playerId)
    local id = validId(playerId)
    if id then dequeue(id) end
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id == nil then return end
    noticeAt[id] = nil
    dequeue(id)
    if MW.matchOf(id) then MW.dropped(id, W.now(), "disconnected") end
end)

-- ---------------------------------------------------------------- commands

local function describe(id)
    local match = MW.matchOf(id)
    if match then
        return ("Most Wanted %d: %s, round %d/%d, you are %s, %d points."):format(match.id, match.state, match.round,
            MW.roundCount(match), match.roles[id] == "runner" and "the RUNNER" or "NCPD", WantedRules.stats(match, id).points)
    end
    local pending = MW.pendingMatch(id)
    if pending then return ("You join Most Wanted %d at its next round."):format(pending.id) end
    local position, total, entry = L.position(id)
    if position then
        local left = countdownLeft()
        return ("Queued for Most Wanted (%s): %d/%d, %d needed%s."):format(modeLabel(entry.mode), position, total,
            MW.minPlayers(), left and (", starts in %ds"):format(math.ceil(left / 1000)) or "")
    end
    return "You are not queued for Most Wanted. /wanted to queue (car chase), /wanted foot for a runner on foot."
end

-- /wanted [car|foot|leave|status]
RegisterCommand("wanted", function(source, args, raw)
    local id = validId(source)
    if id == nil then W.reply(source, raw, false, "In game only.") return end
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "leave" or sub == "quit" or sub == "cancel" then
        if dequeue(id) then ChaseCore.unqueue(id, AID); W.reply(id, raw, true, "You left the Most Wanted queue.") return end
        if MW.leaveRequest(id, W.now()) then publishStatus(); W.reply(id, raw, true, "You left Most Wanted.") return end
        W.reply(id, raw, false, "You are not queued or in Most Wanted.")
    elseif sub == "status" then
        W.reply(id, raw, true, describe(id))
    else
        local mode = nil
        if sub ~= "" and sub ~= "join" and sub ~= "queue" then mode = sub end
        local ok, text = enqueue(id, mode, false)
        W.reply(id, raw, ok, text)
    end
end, false)

-- Staff (ACL command.chase.wanted.status / .force / .stop / .test).
RegisterCommand("chase.wanted.status", function(source, _, raw)
    local left = countdownLeft()
    local lines = { ("lobby %d (min %d%s)%s, instances %d-%d"):format(L.size(), MW.minPlayers(), MW.testMode and ", TEST" or "",
        left and (" countdown %ds"):format(math.ceil(left / 1000)) or "", WC.buckets.from, WC.buckets.to) }
    if botMode() then lines[1] = lines[1] .. ", BOT MODE" end
    for i, entry in ipairs(L.entries) do
        lines[#lines + 1] = ("  q%d: %d (%s)%s"):format(i, entry.id, tostring(entry.mode), entry.squad and (" crew " .. entry.squad.id) or "")
    end
    for _, match in pairs(MW.matches) do
        local who = {}
        for _, m in ipairs(match.members) do
            who[#who + 1] = ("%d=%s:%d%s%s"):format(m.id, tostring(match.roles[m.id] or "-"), WantedRules.stats(match, m.id).points,
                m.gone and "(gone)" or (m.released and "(home)" or (m.leaving and "(leaving)" or "")), m.bot and "(bot)" or "")
        end
        local pending = {}
        for _, p in ipairs(match.pending) do pending[#pending + 1] = tostring(p.id) end
        lines[#lines + 1] = ("  match %d %s %s round %d/%d bucket %d blocks %d %s%s"):format(match.id, match.mode, match.state,
            match.round, MW.roundCount(match), match.bucket, #match.blocks, table.concat(who, " "),
            #pending > 0 and (" pending " .. table.concat(pending, ",")) or "")
    end
    W.reply(validId(source) or 0, raw, true, table.concat(lines, "\n"))
end, true)

-- chase.wanted.force <id> <id> [<id>...] [car|foot]: start now with these players.
RegisterCommand("chase.wanted.force", function(source, args, raw)
    local caller = validId(source) or 0
    local ids, mode, seen = {}, nil, {}
    for _, arg in ipairs(args or {}) do
        local id = validId(arg)
        if id then
            if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        elseif WantedRules.normalizeMode(arg) then
            mode = WantedRules.normalizeMode(arg)
        end
    end
    if #ids < 2 or #ids > WC.maxPlayers then
        W.reply(caller, raw, false, ("usage: chase.wanted.force <playerId> <playerId> [...up to %d] [car|foot]"):format(WC.maxPlayers))
        return
    end
    for _, id in ipairs(ids) do
        if claims(id) and not L.has(id) then W.reply(caller, raw, false, ("player %d is already in Most Wanted"):format(id)) return end
        if ChaseMain and ChaseMain.claims(id) then W.reply(caller, raw, false, ("player %d is in the 1v1 chase"):format(id)) return end
        local ok, why = ChaseCore.check(id, AID)
        if not ok then W.reply(caller, raw, false, ("player %d: %s"):format(id, tostring(why))) return end
    end
    for _, id in ipairs(ids) do L.remove(id); W.queueHud(id, { activity = AID, queued = false }) end
    local match, why, refused = MW.admit(ids, mode or WC.defaultMode, W.now(), { min = 2 })
    pushQueue(); publishStatus()
    local refusedText = {}
    for _, r in ipairs(refused or {}) do refusedText[#refusedText + 1] = ("%d: %s"):format(r.id, tostring(r.why)) end
    W.reply(caller, raw, match ~= nil, match and ("match %d started (%d players)%s"):format(match.id, #match.members,
        #refusedText > 0 and (", refused " .. table.concat(refusedText, "; ")) or "")
        or ("refused (%s) %s"):format(tostring(why), table.concat(refusedText, "; ")))
end, true)

RegisterCommand("chase.wanted.stop", function(source, args, raw)
    local matchId = tonumber(args and args[1])
    local match = matchId and MW.matches[matchId]
    if not match then W.reply(validId(source) or 0, raw, false, "usage: chase.wanted.stop <matchId> (see chase.wanted.status)") return end
    MW.abort(match, W.now(), "Stopped by staff. Nothing counts.")
    publishStatus()
    W.reply(validId(source) or 0, raw, true, ("match %d stopped"):format(match.id))
end, true)

-- Test mode: 2 players are enough (1 runner, 1 cop). Never counts for reputation (the
-- reputation needs config.reputation.minPlayers players in the match).
RegisterCommand("chase.wanted.test", function(source, args, raw)
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "on" then MW.testMode = true
    elseif sub == "off" then MW.testMode = false
    elseif sub ~= "" then W.reply(validId(source) or 0, raw, false, "usage: chase.wanted.test [on|off]") return end
    if L.size() < MW.minPlayers() then L.countdownEndsAtMs = nil end
    pushQueue(); publishStatus(true)
    log("test mode %s by %s", MW.testMode and "ON" or "off", tostring(source))
    W.reply(validId(source) or 0, raw, true, ("Most Wanted test mode %s: %d players minimum."):format(MW.testMode and "ON" or "off",
        MW.minPlayers()))
end, true)

-- ---------------------------------------------------------------- tick

CreateThread(function()
    local tickMs = math.floor(1000 / math.max(1, C.tickHz or 5))
    local lastLobby, lastStatus = 0, 0
    while true do
        Wait(tickMs)
        local now = W.now()
        MW.tick(now)
        if now - lastLobby >= 1000 then
            lastLobby = now
            local ok, err = pcall(lobbyTick, now)
            if not ok then log("lobby error: %s", tostring(err)) end
        end
        if now - lastStatus >= 1000 then
            lastStatus = now
            publishStatus()
        end
    end
end)

-- For server/main.lua: one chase queue at a time.
ChaseWantedMain = { claims = claims, dequeue = dequeue }

log("loaded (%s, %d-%d players, buckets %d-%d)", AID, WC.minPlayers, WC.maxPlayers, WC.buckets.from, WC.buckets.to)
