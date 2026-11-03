-- op77_race server: wires the contract (core events), the client (net events), the
-- commands and the ticks to the engine, the lobby and the editor.
local Config = RaceConfig
local Engine = Config.engine
local A = RaceActivity
local E = RaceEngine
local L = RaceLobby
local Ed = RaceEditor

local function log(text) print("[race] " .. tostring(text)) end

-- Open77.players.* throws (uncatchably) on an id below 1: every id from outside is
-- checked here first.
local function playerIdOf(value)
    local id = math.tointeger(tonumber(value))
    if id == nil or id < 1 then return nil end
    return id
end

-- ---------------------------------------------------------------- output --

local function notice(playerId, kind, title, text)
    if playerIdOf(playerId) == nil or Open77.players.name(playerId) == nil then return end
    if Open77.notifications and Open77.notifications.send then
        Open77.notifications.send(playerId, {
            type = kind or "info", title = title or "Race", message = text or "", durationMs = 4000,
        })
    end
end

local function output(source, raw, success, text)
    log(text)
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", success == true, text)
    end
end

-- The races are joined from Light RP's Activities panel; the core's status of each
-- activity is refreshed when a queue or an instance changes.
local statusDirty = true

local function changed()
    statusDirty = true
end

-- Queued players keep playing in the RP world; their lobby (queue size, the grid's
-- countdown) is drawn by Light RP's activity HUD from this event, sent on change only.
local queueShown = {} -- playerId -> digest of what they were last sent

local function pushQueues(now)
    local seen = {}
    for _, def in ipairs(Config.activities) do
        local q = L.queues[def.key]
        if def.queued and q then
            local window = L.windowRemainingMs(def.key, now)
            local bots = L.botsHere(def)
            for _, playerId in ipairs(q.members) do
                seen[playerId] = true
                local digest = ("%s|%d|%s|%s"):format(def.key, #q.members, tostring(q.windowEndsAt), tostring(bots))
                if queueShown[playerId] ~= digest then
                    queueShown[playerId] = digest
                    TriggerClientEvent("op77_race:queue", playerId, {
                        activity = def.id, label = def.label, mode = def.mode, queued = #q.members,
                        minPlayers = L.minimum(def), maxPlayers = def.maxPlayers, windowMs = window,
                        bots = bots or nil,
                    })
                end
            end
        end
    end
    for playerId in pairs(queueShown) do
        if not seen[playerId] then
            queueShown[playerId] = nil
            if Open77.players.name(playerId) ~= nil then TriggerClientEvent("op77_race:queue", playerId, false) end
        end
    end
end

E.hooks.push = function(playerId, payload) TriggerClientEvent("op77_race:state", playerId, payload) end
E.hooks.clear = function(playerId) TriggerClientEvent("op77_race:clear", playerId) end
E.hooks.notice = notice
E.hooks.pulse = function(playerId, payload) TriggerClientEvent("op77_race:pulse", playerId, payload) end
E.hooks.changed = changed
E.hooks.cover = function(playerId, screen)
    -- Handled by op77_loadscreen when it runs; an unhandled event otherwise.
    TriggerClientEvent("op77_loadscreen:cover", playerId, {
        id = "op77_race", title = screen.title, subtitle = screen.subtitle, zone = screen.zone,
        target = screen.target, timeoutMs = 20000, expectedMs = 5000,
    })
end
E.hooks.uncover = function(playerId)
    TriggerClientEvent("op77_loadscreen:release", playerId, { id = "op77_race" })
end
L.hooks.notice = notice
L.hooks.changed = changed
Ed.hooks.push = function(playerId, state) TriggerClientEvent("op77_race:editor", playerId, state or false) end
Ed.hooks.notice = notice

-- ---------------------------------------------------------------- status --

local function statusFor(def, now)
    local running, players = E.count(def.mode)
    local queued = L.size(def.key)
    local courses = #RaceCourses.ids(def.mode)
    local phase, detail = "idle", nil
    if running > 0 then phase = "running" elseif queued > 0 then phase = "lobby" end
    if def.mode == "trial" then
        detail = running > 0 and ("%d on the clock"):format(players) or ("%d courses"):format(courses)
    elseif def.mode == "pve" then
        detail = running > 0 and ("%d racing the AI"):format(players)
            or queued > 0 and "Crew gathering" or ("%d courses"):format(courses)
    elseif L.windowRemainingMs(def.key, now) ~= nil then
        detail = "Grid forming"
    elseif queued > 0 then
        detail = ("%d of %d waiting"):format(queued, L.minimum(def))
    elseif running > 0 then
        detail = "Race in progress"
    else
        detail = ("%d courses"):format(courses)
    end
    return { phase = phase, players = players, queued = queued, joinable = courses > 0, detail = detail,
        queue = def.mode ~= "trial" and L.queueOf(def, now) or nil }
end

local function pushStatus(force)
    if not A.registered then return end
    local now = E.nowMs()
    for _, def in ipairs(Config.activities) do A.status(def.id, statusFor(def, now), force, now) end
end

-- ---------------------------------------------------------------- joining --

-- Our own entry points (commands, op77_race:join) check eligibility first; the core's join
-- event arrives already checked.
local function joinChecked(playerId, def, options)
    if def == nil then return false, "Unknown race." end
    if not A.registered then return false, "Races are not available right now." end
    if E.busy(playerId) then return false, "You are already in a race." end
    if Ed.sessions[playerId] then return false, "Close the course editor first." end
    local ok, why = A.check(playerId, def.id)
    if not ok then return false, why end
    return L.join(playerId, def, options)
end

local function joinAndReport(playerId, def, options)
    local ok, why = joinChecked(playerId, def, options)
    if not ok then notice(playerId, "error", def and def.label or "Race", why) end
    changed()
    return ok, why
end

local function leave(playerId, reason)
    if E.leave(playerId, reason or "left") then return true, "You left the race." end
    local key = L.queuedIn(playerId)
    if L.leave(playerId) then
        -- joined from Light RP's panel, the hub still lists him as queued: clear it there
        -- too (activityLeave on a queued-only player; never on an owned one)
        local def = key and A.byKey[key]
        if def and A.owner(playerId) == nil then A.call("activityLeave", playerId, def.id, { returnPlayer = false }) end
        return true, "You left the queue."
    end
    return false, "You are not in a race or a queue."
end

-- ---------------------------------------------------------------- contract --

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    local def = A.definition(activityId)
    if Ed.sessions[id] then return notice(id, "error", def.label, "Close the course editor first.") end
    local ok, why = L.join(id, def, options)
    if not ok then notice(id, "error", def.label, why) end
    changed()
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    if E.leave(id, "left") then return end
    L.leave(id)
    -- Owned but no longer ours (a race that already ended): release anyway.
    if A.owner(id) == activityId then A.leave(id, activityId, { returnPlayer = true }) end
end)

-- Staff bot mode (/lightrp.bots on|off in op77_lightrp). Read again after every
-- successful registration (activityBots()), since this may fire while we are down.
-- Off: no new race is filled with bots; one already running finishes with its bots.
AddEventHandler("op77_lightrp:activity:bots", function(enabled)
    if A.setBots(enabled == true, "event") then changed() end
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    E.dropped(id, reason)
    L.leave(id)
    changed()
end)

local function registerNow()
    if A.register() then pushStatus(true) end
end

-- The time trial's courses are join choices in the Activities panel: a saved or
-- deleted course registers again (the core replaces the definition, keeps its status).
local function coursesChanged()
    changed()
    if A.registered then registerNow() end
end

-- Registration retries every 3 s until the core accepts, and again whenever the core
-- restarts (it forgets its providers). One path, so a restart never registers twice.
local nextRegisterAt = 0
CreateThread(function()
    while true do
        if not A.registered and E.nowMs() >= nextRegisterAt then
            registerNow()
            if not A.registered then nextRegisterAt = E.nowMs() + 3000 end
        end
        Wait(500)
    end
end)

AddEventHandler("onResourceStart", function(name)
    if name == Config.core then
        A.registered = false
        nextRegisterAt = E.nowMs() + 500
    elseif name == GetCurrentResourceName() then
        log(("ready: %d course(s), buckets %d-%d"):format(#RaceCourses.ids(), Config.bucketBase,
            Config.bucketBase + Config.bucketCount - 1))
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == Config.core then
        -- Nobody can take the racers back: end every race and send them to where they
        -- stood before entering. The queues go too (admission needs the core).
        log("core stopped: closing every race")
        A.registered = false
        -- The core starts again with bot mode off; registration reads it back.
        A.setBots(false, "core_stopped")
        A.forgetStatus()
        E.stopAll({ fallback = true, reason = "core_stopped" })
        L.clear()
        changed()
    elseif name == GetCurrentResourceName() then
        -- No thread survives: cars out and protections off now; the core returns
        -- the players of a stopping provider.
        E.shutdown()
    end
end)

-- ---------------------------------------------------------------- players --

AddEventHandler("onPlayerLifeStateChanged", function(value)
    local id = playerIdOf(value)
    if id then E.onLifeState(id) end
end)

AddEventHandler("onPlayerDisconnected", function(value)
    local id = playerIdOf(value)
    if id == nil then return end
    E.disconnect(id)
    L.forget(id)
    Ed.forget(id)
    queueShown[id] = nil
    changed()
end)

-- ---------------------------------------------------------------- client --

local lastRequest = {}
local function throttled(playerId, ms)
    local now = E.nowMs()
    if now - (lastRequest[playerId] or -math.huge) < (ms or 300) then return true end
    lastRequest[playerId] = now
    return false
end

RegisterNetEvent("op77_race:ready", function()
    local id = playerIdOf(source)
    if id == nil then return end
    E.push(id)
    if Ed.sessions[id] then Ed.push(id) end
    queueShown[id] = nil -- the next tick sends the queue again
end)

-- Kept for scripts and binds: the same join as the Activities panel and the commands.
RegisterNetEvent("op77_race:join", function(payload)
    local id = playerIdOf(source)
    if id == nil or type(payload) ~= "table" or throttled(id) then return end
    local def = A.byKey[tostring(payload.activity or "")]
    if def == nil then return end
    local course = type(payload.course) == "string" and payload.course:sub(1, 64) or nil
    joinAndReport(id, def, { course = course })
end)

RegisterNetEvent("op77_race:leave", function()
    local id = playerIdOf(source)
    if id == nil or throttled(id) then return end
    local _, text = leave(id, "left")
    notice(id, "info", "Race", text)
    changed()
end)

RegisterNetEvent("op77_race:restart", function()
    local id = playerIdOf(source)
    if id == nil or throttled(id, 1000) then return end
    local ok = E.restart(id)
    if not ok then notice(id, "error", "Time Trial", "You cannot restart right now.") end
end)

RegisterNetEvent("op77_race:respawn", function()
    local id = playerIdOf(source)
    if id == nil or throttled(id, 500) then return end
    local ok, reason = E.respawnAtCheckpoint(id)
    if not ok and reason ~= "pending" and reason ~= "not_available" then
        notice(id, "error", "Rooftop Race", "You cannot go back to the checkpoint right now.")
    end
end)

RegisterNetEvent("op77_race:editorAction", function(payload)
    local id = playerIdOf(source)
    if id == nil or type(payload) ~= "table" or Ed.sessions[id] == nil or throttled(id, 250) then return end
    local action = tostring(payload.action or "")
    if action ~= "start" and action ~= "checkpoint" and action ~= "grid" and action ~= "undo" then return end
    local ok, message = Ed.action(id, action, nil, payload.heading)
    if not ok then notice(id, "error", "Race editor", Ed.message(message)) end
end)

-- ---------------------------------------------------------------- commands --

local MODES = { trial = "trial", timetrial = "trial", grid = "grid", street = "grid", foot = "foot", rooftop = "foot",
    pve = "pve", ai = "pve", vsai = "pve" }

-- /race opens Light RP's Activities panel, where every race is listed and joined.
RegisterCommand("race", function(source)
    local id = playerIdOf(source)
    if id == nil then return output(source, "race", false, "race must be used in-game") end
    TriggerClientEvent("op77_race:activities", id)
end, false)

RegisterCommand("timetrial", function(source, args, raw)
    local id = playerIdOf(source)
    if id == nil then return output(source, raw, false, "timetrial must be used in-game") end
    local ok, why = joinAndReport(id, A.byKey.trial, { course = args[1] })
    output(source, raw, ok, ok and "Time trial starting" or tostring(why))
end, false)

RegisterCommand("race.join", function(source, args, raw)
    local id = playerIdOf(source)
    if id == nil then return output(source, raw, false, "race.join must be used in-game") end
    local def = A.byKey[MODES[tostring(args[1] or "trial"):lower()] or ""]
    if def == nil then return output(source, raw, false, "usage: /race.join trial|street|rooftop|pve [course]") end
    local ok, why = joinAndReport(id, def, { course = args[2] })
    output(source, raw, ok, ok and ("Joined " .. def.label) or tostring(why))
end, false)

RegisterCommand("race.leave", function(source, _, raw)
    local id = playerIdOf(source)
    if id == nil then return output(source, raw, false, "race.leave must be used in-game") end
    local ok, text = leave(id, "left")
    changed()
    output(source, raw, ok, text)
end, false)

RegisterCommand("race.restart", function(source, _, raw)
    local id = playerIdOf(source)
    if id == nil then return output(source, raw, false, "race.restart must be used in-game") end
    local ok = E.restart(id)
    output(source, raw, ok, ok and "Restarting" or "Nothing to restart")
end, false)

RegisterCommand("race.status", function(source, _, raw)
    local now = E.nowMs()
    local lines = { ("core %s: %s, bot mode %s"):format(Config.core, A.registered and "registered" or "not registered",
        A.bots and "ON" or "off") }
    for _, def in ipairs(Config.activities) do
        local s = statusFor(def, now)
        lines[#lines + 1] = ("%s: %s, %d racing, %d queued (%s)"):format(def.id, s.phase, s.players, s.queued, s.detail)
    end
    output(source, raw, true, table.concat(lines, " | "))
end, false)

-- Staff: course editor. /race.editor open [courseId|--foot] | start | cp | grid | undo |
-- undogrid | name <text> | laps <n> | type circuit|sprint | radius <m> | vehicle <id> |
-- vehicles | save | close | list | delete <courseId>
RegisterCommand("race.editor", function(source, args, raw)
    local id = playerIdOf(source)
    local action = tostring(args[1] or "open"):lower()
    if action == "list" then
        local names = {}
        for _, summary in ipairs(RaceCourses.list()) do
            names[#names + 1] = ("%s (%s%s)"):format(summary.id, summary.onFoot and "foot" or summary.vehicle,
                summary.builtin and ", built-in" or "")
        end
        return output(source, raw, true, table.concat(names, ", "))
    elseif action == "vehicles" then
        local names = {}
        for _, vehicle in ipairs(RaceCourses.vehicles()) do names[#names + 1] = vehicle.id end
        return output(source, raw, true, table.concat(names, ", "))
    elseif action == "delete" then
        local ok, reason = RaceCourses.remove(args[2])
        if ok then coursesChanged() end
        return output(source, raw, ok, ok and "Course deleted" or Ed.message(reason))
    end
    if id == nil then return output(source, raw, false, "race.editor " .. action .. " must be used in-game") end
    if action == "open" then
        if E.busy(id) or L.queuedIn(id) then return output(source, raw, false, "Leave the race or its queue first") end
        local ok, reason = Ed.open(id, args[2])
        return output(source, raw, ok, ok and "Race editor open" or Ed.message(reason))
    elseif action == "close" then
        local ok = Ed.close(id)
        return output(source, raw, ok, ok and "Race editor closed" or "No editor open")
    end
    local value = args[2]
    if action == "name" then value = raw:match("^%S+%s+%S+%s+(.+)$") end
    local ok, message = Ed.action(id, action, value, nil)
    if ok and action == "save" then coursesChanged() end
    output(source, raw, ok, ok and message or Ed.message(message))
end, true)

-- Staff: start a queued street or rooftop race now, even below its minimum.
RegisterCommand("race.force", function(source, args, raw)
    local def = A.byKey[MODES[tostring(args[1] or "grid"):lower()] or ""]
    if def == nil or not def.queued then return output(source, raw, false, "usage: /race.force street|rooftop") end
    if L.size(def.key) == 0 then return output(source, raw, false, "Nobody is queued") end
    local ok, reason = L.launch(def, E.nowMs(), true)
    output(source, raw, ok, ok and (def.label .. " started") or tostring(reason))
end, true)

-- ---------------------------------------------------------------- ticks --

RaceCourses.load()
RaceRecords.load()

CreateThread(function()
    local lastStatusAt = 0
    while true do
        Wait(Engine.tickMs or 100)
        local now = E.nowMs()
        local ok, err = pcall(E.tick, now)
        if not ok then log("engine tick failed: " .. tostring(err)) end
        ok, err = pcall(L.tick, now)
        if not ok then log("lobby tick failed: " .. tostring(err)) end
        ok, err = pcall(pushQueues, now)
        if not ok then log("queue push failed: " .. tostring(err)) end
        if statusDirty or now - lastStatusAt >= 2000 then
            statusDirty, lastStatusAt = false, now
            pushStatus(false)
        end
    end
end)
