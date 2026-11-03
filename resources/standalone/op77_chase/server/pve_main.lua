-- op77_chase NCPD Escape wiring: its own activity (chase.pve, PvE with Light RP's
-- difficulties), a short gathering queue, the contract events for that id, the /escape
-- commands, the police report of the clients and the tick. The lifecycle lives in
-- server/pve.lua; the police are the game's own NCPD (server/police.lua), or the bot cops
-- of server/bots.lua when config.pve.police = "bots". No staff switch needed.
--
-- The queue only gathers a group: a player alone starts gatherSeconds after his join; a
-- crew (Light RP squad: every member's join carries the same options.squad) starts once
-- every member is queued and ready, or squadWaitSeconds after its first join with whoever
-- is ready. A group never shares a match with strangers; with crews = "solo" every member
-- of a crew gets his own instance (started together).
local PC = ChaseConfig.pve
local W = ChaseWorld
local P = ChasePve
local E = ChaseEscapeRules
local Pol = ChasePolice
local AID = PC.activity.id

local function log(fmt, ...) print(("[op77_chase] escape " .. fmt):format(...)) end
local function validId(id)
    id = tonumber(id)
    if id == nil or id <= 0 or id % 1 ~= 0 then return nil end
    return math.tointeger(id)
end
local function notify(id, kind, text, ms) W.notify(id, kind, text, ms, "NCPD Escape") end
local function squadOf(value) return ChaseWantedLobby.squad(value) end

local Q = { entries = {} }

local function indexOf(id)
    for i, e in ipairs(Q.entries) do if e.id == id then return i, e end end
    return nil
end

local function removeEntry(id)
    local i = indexOf(id)
    if i then table.remove(Q.entries, i) return true end
    return false
end

-- ---------------------------------------------------------------- registration

local function publishStatus(force)
    ChaseCore.status(P.status(#Q.entries), force, AID)
end

local function register()
    local a = PC.activity
    local ok, why = ChaseCore.register({ id = a.id, resource = GetCurrentResourceName(), label = a.label, kind = a.kind,
        description = a.description, minPlayers = a.minPlayers, maxPlayers = a.maxPlayers, caps = a.caps, modes = a.modes,
        pve = a.pve, difficulties = a.difficulties })
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

-- ---------------------------------------------------------------- queue

local noticeAt = {}

local function modeLabel(mode)
    if mode == "foot" then return "on foot" elseif mode == "vehicle" then return "by car" end
    return "by car"
end

-- A difficulty id of config.pve.difficulties, or nil.
local DIFF_ALIASES = { std = "standard", normal = "standard", easy = "standard", hardcore = "critical", crit = "critical",
    maxtac = "critical" }
local function difficultyOf(value)
    if type(value) ~= "string" then return nil end
    value = value:lower()
    value = DIFF_ALIASES[value] or value
    return (PC.difficulties or {})[value] and value or nil
end

local function difficultyLabel(id)
    local _, d = E.difficulty(id)
    return d.label or id
end

-- The crew members of an entry already queued (him included).
local function crewQueued(entry)
    if not entry.squad then return 1, 1 end
    local n = 0
    for _, e in ipairs(Q.entries) do if e.squad and e.squad.id == entry.squad.id then n = n + 1 end end
    return n, #entry.squad.members
end

local function pushQueue()
    for _, e in ipairs(Q.entries) do
        local queued, crew = crewQueued(e)
        W.queueHud(e.id, { activity = AID, queued = true, mode = e.mode, crew = e.squad and crew or nil,
            crewQueued = e.squad and queued or nil, busy = e.notReadySince ~= nil or nil,
            difficulty = e.difficulty, difficultyLabel = e.difficulty and difficultyLabel(e.difficulty) or nil })
    end
end

local function dequeue(id, text)
    if not removeEntry(id) then return false end
    W.queueHud(id, { activity = AID, queued = false })
    if text then notify(id, "info", text, 5000) end
    pushQueue()
    publishStatus()
    return true
end

local function claims(id)
    return indexOf(id) ~= nil or P.matchOf(id) ~= nil
end

local USAGE = "usage: /escape [car|foot] [standard|hard|critical] | leave | status"

-- `checked`: Light RP already ran activityCheck (the hub join, its difficulty included).
-- `squad`: his crew. `difficulty`: Light RP's options.difficulty, or the /escape word.
local function enqueue(id, mode, checked, squad, difficulty)
    if P.matchOf(id) then return false, "You are already in NCPD Escape." end
    if ChaseMain and ChaseMain.claims(id) then return false, "You are in the NCPD Chase queue. /chase leave first." end
    if ChaseWantedMain and ChaseWantedMain.claims(id) then return false, "You are queued for Most Wanted. /wanted leave first." end
    local requested = mode
    mode = WantedRules.normalizeMode(mode)
    if requested ~= nil and requested ~= "" and mode == nil then return false, USAGE end
    if difficulty ~= nil and difficultyOf(difficulty) == nil then return false, USAGE end
    difficulty = difficultyOf(difficulty)
    if indexOf(id) then return true, "NCPD Escape is getting ready." end
    if not checked then
        local ok, why = ChaseCore.check(id, AID, difficulty and { difficulty = difficulty } or nil)
        if not ok then return false, why end
    end
    local entry = { id = id, mode = mode, since = W.now(), squad = squadOf(squad), difficulty = difficulty }
    Q.entries[#Q.entries + 1] = entry
    pushQueue()
    publishStatus()
    local text = ("NCPD Escape (%s, %s): starting in a moment%s. /escape leave to cancel."):format(modeLabel(mode or PC.defaultMode),
        difficultyLabel(difficulty or PC.defaultDifficulty), entry.squad and " - with your crew" or "")
    notify(id, "info", text, 6000)
    return true, text
end

local function ready(id)
    if not W.connected(id) then return false, "disconnected" end
    return ChaseCore.check(id, AID)
end

-- Readiness of every entry: notices, and the ones failing it for too long are dropped.
local function readiness(now)
    local dropAfterMs = (PC.queue.notReadyDropSeconds or 120) * 1000
    local isReady = {}
    for i = #Q.entries, 1, -1 do
        local e = Q.entries[i]
        local ok, why = ready(e.id)
        if ok then
            e.notReadySince = nil
            isReady[e.id] = true
        else
            e.notReadySince = e.notReadySince or now
            if now - e.notReadySince >= dropAfterMs then
                table.remove(Q.entries, i)
                W.queueHud(e.id, { activity = AID, queued = false })
                notify(e.id, "info", ("You left NCPD Escape: %s"):format(tostring(why)), 6000)
            elseif now - (noticeAt[e.id] or -math.huge) >= (PC.queue.notReadyNoticeSeconds or 30) * 1000 then
                noticeAt[e.id] = now
                notify(e.id, "warning", ("NCPD Escape is waiting for you, but you can't go yet: %s"):format(tostring(why)), 6000)
            end
        end
    end
    return isReady
end

-- The groups that start now, in queue order: { entries, squad }.
local function groupsToStart(now, isReady)
    local gatherMs = (PC.queue.gatherSeconds or 2) * 1000
    local waitMs = (PC.queue.squadWaitSeconds or 10) * 1000
    local out, seen = {}, {}
    for _, e in ipairs(Q.entries) do
        if not seen[e.id] then
            local group = { entries = {}, squad = e.squad }
            for _, o in ipairs(Q.entries) do
                if o.id == e.id or (e.squad and o.squad and o.squad.id == e.squad.id) then
                    group.entries[#group.entries + 1] = o
                    seen[o.id] = true
                end
            end
            local since, readyList = math.huge, {}
            for _, o in ipairs(group.entries) do
                since = math.min(since, o.since)
                if isReady[o.id] then readyList[#readyList + 1] = o end
            end
            local go = false
            if group.squad then
                local queued = {}
                for _, o in ipairs(group.entries) do queued[o.id] = true end
                local all = #readyList == #group.entries
                for _, memberId in ipairs(group.squad.members) do if not queued[memberId] then all = false end end
                go = #readyList > 0 and ((all and now - since >= gatherMs) or now - since >= waitMs)
            else
                go = #readyList > 0 and now - since >= gatherMs
            end
            if go then
                while #readyList > (PC.maxRunners or 4) do table.remove(readyList) end
                group.ready = readyList
                out[#out + 1] = group
            end
        end
    end
    return out
end

-- The mode of a group: the crew leader's choice, else the first one who chose, else the default.
local function groupMode(group)
    local leader = group.squad and group.squad.leader
    for _, e in ipairs(group.ready) do if e.id == leader and e.mode then return e.mode end end
    for _, e in ipairs(group.ready) do if e.mode then return e.mode end end
    return PC.defaultMode or "vehicle"
end

-- Its difficulty, the same way (Light RP hands every crew member the leader's pick).
local function groupDifficulty(group)
    local leader = group.squad and group.squad.leader
    for _, e in ipairs(group.ready) do if e.id == leader and e.difficulty then return e.difficulty end end
    for _, e in ipairs(group.ready) do if e.difficulty then return e.difficulty end end
    return PC.defaultDifficulty or "standard"
end

-- The matches a group starts: one (crews = "together"), or one per member ("solo").
local function admitGroup(group, now)
    local ids, squads = {}, {}
    for _, e in ipairs(group.ready) do ids[#ids + 1] = e.id; squads[e.id] = e.squad end
    local mode, difficulty = groupMode(group), groupDifficulty(group)
    if PC.crews ~= "solo" or #ids <= 1 then
        local match, why, refused = P.admit(ids, mode, now, { squads = squads, difficulty = difficulty })
        return ids, { { match = match, why = why, refused = refused, ids = ids } }
    end
    local out = {}
    for _, id in ipairs(ids) do
        local match, why, refused = P.admit({ id }, mode, now, { squads = squads, difficulty = difficulty })
        out[#out + 1] = { match = match, why = why, refused = refused, ids = { id } }
    end
    return ids, out
end

local function lobbyTick(now)
    local changed = false
    for i = #Q.entries, 1, -1 do
        local e = Q.entries[i]
        if now - e.since >= (PC.queue.timeoutSeconds or 900) * 1000 then
            table.remove(Q.entries, i)
            W.queueHud(e.id, { activity = AID, queued = false })
            notify(e.id, "info", "NCPD Escape could not start in time. Join again from the Crossing or with /escape.", 6000)
            changed = true
        end
    end
    if #Q.entries == 0 then return changed end
    local before = #Q.entries
    local isReady = readiness(now)
    changed = changed or #Q.entries ~= before
    for _, group in ipairs(groupsToStart(now, isReady)) do
        local _, starts = admitGroup(group, now)
        for _, s in ipairs(starts) do
            local match, why, refused, ids = s.match, s.why, s.refused, s.ids
            if why == "busy" then
                log("every NCPD Escape instance is busy; %d player(s) wait", #ids)
            else
                changed = true
                local refusedIds = {}
                for _, r in ipairs(refused or {}) do
                    refusedIds[r.id] = true
                    notify(r.id, "warning", ("You could not join NCPD Escape: %s"):format(tostring(r.why)), 6000)
                end
                for _, id in ipairs(ids) do
                    local entered = match ~= nil and P.matchOf(id) == match
                    if entered or refusedIds[id] or match == nil then
                        removeEntry(id)
                        W.queueHud(id, { activity = AID, queued = false })
                        noticeAt[id] = nil
                        if match == nil and not refusedIds[id] then
                            notify(id, "warning", ("NCPD Escape could not start: %s"):format(tostring(why)), 6000)
                        end
                    end
                end
            end
        end
    end
    if changed or #Q.entries > 0 then pushQueue() end
    return changed
end

-- ---------------------------------------------------------------- lifecycle events

AddEventHandler("onResourceStart", function(name)
    if name == ChaseCore.resource then
        CreateThread(function() Wait(2000); register() end)
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        P.shutdown()
    elseif name == ChaseCore.resource then
        P.coreStopped(W.now())
        for _, e in ipairs(Q.entries) do W.queueHud(e.id, { activity = AID, queued = false }) end
        Q.entries = {}
    end
end)

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    local mode = type(options) == "table" and options.mode or nil
    local squad = type(options) == "table" and options.squad or nil
    local difficulty = type(options) == "table" and difficultyOf(options.difficulty) or nil
    local ok, text = enqueue(id, mode, true, squad, difficulty)
    if not ok then notify(id, "warning", text, 5000) end
end)

-- What the runner's game did with the wanted level (client/main.lua, from
-- Open77.prevention.state()): a handful of numbers and flags, never trusted for anything
-- but a warning.
RegisterNetEvent("op77_chase:police", function(report)
    local id = validId(source)
    if id == nil or type(report) ~= "table" then return end
    P.policeReport(id, {
        expected = tonumber(report.expected), requested = tonumber(report.requested),
        suppressed = report.suppressed == true, acknowledged = report.acknowledged == true, attached = report.attached ~= false,
    }, W.now())
end)

-- A wanted runner who leaves the instance he was raised in (home, a staff teleport): his
-- stars come down. Bucket 0's own dispatch is never touched.
AddEventHandler("onPlayerBucketChange", function(playerId, bucket)
    local id = validId(playerId)
    if id == nil then return end
    Pol.bucketChanged(id, tonumber(bucket))
end)

-- A restart or a reload while an escape was on: the previous run could not lower its
-- runners' stars (the runtime refuses it while stopping); its ledger says who.
CreateThread(function()
    Wait(1500)
    local ok, err = pcall(Pol.sweep)
    if not ok then log("police sweep failed: %s", tostring(err)) end
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    if dequeue(id, "You left NCPD Escape.") then return end
    if P.leaveRequest(id, W.now()) then notify(id, "info", "You left NCPD Escape.", 5000) end
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = validId(playerId)
    if id == nil or activityId ~= AID then return end
    dequeue(id)
    P.dropped(id, W.now(), reason)
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
    if P.matchOf(id) or Pol.isRaised(id) then P.dropped(id, W.now(), "disconnected") end
end)

-- ---------------------------------------------------------------- commands

local function describe(id)
    local match = P.matchOf(id)
    if match then
        local m = P.member(match, id)
        local against = match.police == "bots" and ("%d cop(s)"):format(match.copCount) or "the NCPD"
        return ("NCPD Escape %d (%s): %s, %d runner(s) against %s%s."):format(match.id, difficultyLabel(match.difficulty), match.state,
            #match.members - match.copCount, against,
            m and m.outcome and (", you " .. (m.outcome == "escaped" and "escaped" or m.outcome)) or "")
    end
    if indexOf(id) then return "NCPD Escape is getting ready for you." end
    return "You are not in NCPD Escape. /escape to start (by car), /escape foot on foot, add hard or critical for more heat"
        .. " - alone or with your crew."
end

-- /escape [car|foot] [standard|hard|critical] | leave | status
RegisterCommand("escape", function(source, args, raw)
    local id = validId(source)
    if id == nil then W.reply(source, raw, false, "In game only.") return end
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "leave" or sub == "quit" or sub == "cancel" then
        if dequeue(id) then ChaseCore.unqueue(id, AID); W.reply(id, raw, true, "You left NCPD Escape.") return end
        if P.leaveRequest(id, W.now()) then publishStatus(); W.reply(id, raw, true, "You left NCPD Escape.") return end
        W.reply(id, raw, false, "You are not in NCPD Escape.")
    elseif sub == "status" then
        W.reply(id, raw, true, describe(id))
    else
        local mode, difficulty
        for i = 1, #(args or {}) do
            local word = tostring(args[i]):lower()
            if word ~= "" and word ~= "join" and word ~= "start" then
                if WantedRules.normalizeMode(word) and mode == nil then mode = word
                elseif difficultyOf(word) and difficulty == nil then difficulty = word
                else W.reply(id, raw, false, USAGE) return end
            end
        end
        local ok, text = enqueue(id, mode, false, nil, difficulty)
        W.reply(id, raw, ok, text)
    end
end, false)

-- Staff (ACL command.chase.pve.status / command.chase.pve.stop).
RegisterCommand("chase.pve.status", function(source, _, raw)
    local lines = { ("escape queue %d, instances %d-%d, police %s, crews %s"):format(#Q.entries, PC.buckets.from, PC.buckets.to,
        P.policeMode(), tostring(PC.crews)) }
    for i, e in ipairs(Q.entries) do
        lines[#lines + 1] = ("  q%d: %d (%s, %s)%s"):format(i, e.id, tostring(e.mode), tostring(e.difficulty),
            e.squad and (" crew " .. e.squad.id) or "")
    end
    for _, match in pairs(P.matches) do
        local who = {}
        for _, m in ipairs(match.members) do
            local extra = ""
            if m.run then extra = ("(%d* bust %.2f%s)"):format(m.run.stars, m.run.bustMeter or 0, m.policeBlocked and " BLOCKED" or "") end
            who[#who + 1] = ("%d=%s%s%s%s"):format(m.id, m.role, m.bot and "(bot)" or "",
                m.outcome and ("(" .. m.outcome .. ")") or (m.gone and "(gone)" or (m.released and "(home)" or "")), extra)
        end
        lines[#lines + 1] = ("  match %d %s %s %s %s bucket %d %s"):format(match.id, match.police, tostring(match.difficulty), match.mode,
            match.state, match.bucket, table.concat(who, " "))
    end
    -- The levels this resource raised, beside what the server really holds (getWanted) and
    -- what the runner's game last reported.
    local raised = {}
    for id, r in pairs(Pol.raised) do
        local held = W.getWanted(id)
        local rep = Pol.reports[id]
        raised[#raised + 1] = ("%d=%d/%d server %s game %s"):format(id, math.max(0, r.stars or 0), math.max(0, r.ceiling or 0),
            held and ("%s/%s"):format(tostring(held.level), tostring(held.maxLevel)) or "?",
            rep and ("%s%s"):format(tostring(rep.requested), rep.suppressed and " suppressed" or "") or "?")
    end
    table.sort(raised)
    if #raised > 0 then lines[#lines + 1] = "  wanted: " .. table.concat(raised, ", ") end
    W.reply(validId(source) or 0, raw, true, table.concat(lines, "\n"))
end, true)

RegisterCommand("chase.pve.stop", function(source, args, raw)
    local matchId = tonumber(args and args[1])
    local match = matchId and P.matches[matchId]
    if not match then W.reply(validId(source) or 0, raw, false, "usage: chase.pve.stop <matchId> (see chase.pve.status)") return end
    P.abort(match, W.now(), "Stopped by staff. Nothing counts.")
    publishStatus()
    W.reply(validId(source) or 0, raw, true, ("escape %d stopped"):format(match.id))
end, true)

-- ---------------------------------------------------------------- tick

CreateThread(function()
    local tickMs = math.floor(1000 / math.max(1, ChaseConfig.tickHz or 5))
    local lastLobby, lastStatus = 0, 0
    while true do
        Wait(tickMs)
        local now = W.now()
        P.tick(now)
        if now - lastLobby >= 1000 then
            lastLobby = now
            local ok, err = pcall(lobbyTick, now)
            if not ok then log("queue error: %s", tostring(err)) end
        end
        if now - lastStatus >= 1000 then
            lastStatus = now
            publishStatus()
        end
    end
end)

-- For server/main.lua and server/wanted_main.lua (one chase activity at a time), and tests.
ChasePveMain = { claims = claims, dequeue = dequeue, queue = Q, lobbyTick = lobbyTick, enqueue = enqueue, difficultyOf = difficultyOf }

log("loaded (%s, police %s, crews %s, up to %d runners, buckets %d-%d)", AID, P.policeMode(), tostring(PC.crews),
    PC.maxRunners or 4, PC.buckets.from, PC.buckets.to)
