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

-- Panels: players who opened the race panel get a fresh menu when something changes.
local menuOpen = {}
local menuDirty, statusDirty = false, true

local function menuFor(playerId)
    local now = E.nowMs()
    local info = A.player(playerId)
    local key = A.characterKey(info)
    local activities = {}
    for _, def in ipairs(Config.activities) do
        local running, players = E.count(def.mode)
        activities[#activities + 1] = {
            key = def.key, id = def.id, label = def.label, description = def.description,
            minPlayers = def.minPlayers, maxPlayers = def.maxPlayers,
            queued = L.size(def.key), running = running, players = players,
            windowMs = L.windowRemainingMs(def.key, now),
            courses = #RaceCourses.ids(def.mode),
        }
    end
    local courses = {}
    for _, summary in ipairs(RaceCourses.list("trial")) do
        summary.top = RaceRecords.top(summary.id, summary.revision, Config.records.show)
        local best = key and RaceRecords.best(summary.id, summary.revision, key)
        summary.bestMs = best and best.timeMs or nil
        summary.rank = key and RaceRecords.rank(summary.id, summary.revision, key) or nil
        courses[#courses + 1] = summary
    end
    return {
        activities = activities,
        courses = courses,
        queued = L.queuedIn(playerId),
        racing = E.busy(playerId),
        available = A.registered,
    }
end

local function pushMenu(playerId)
    TriggerClientEvent("op77_race:menu", playerId, json.encode(menuFor(playerId)))
end

local function changed()
    menuDirty, statusDirty = true, true
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
    elseif L.windowRemainingMs(def.key, now) ~= nil then
        detail = "Grid forming"
    elseif queued > 0 then
        detail = ("%d of %d waiting"):format(queued, def.minPlayers)
    elseif running > 0 then
        detail = "Race in progress"
    else
        detail = ("%d courses"):format(courses)
    end
    return { phase = phase, players = players, queued = queued, joinable = courses > 0, detail = detail }
end

local function pushStatus(force)
    if not A.registered then return end
    local now = E.nowMs()
    for _, def in ipairs(Config.activities) do A.status(def.id, statusFor(def, now), force) end
end

-- ---------------------------------------------------------------- joining --

-- Our own entry points (panel, commands) check eligibility first; the core's join
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
    if L.leave(playerId) then return true, "You left the queue." end
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

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    E.dropped(id, reason)
    L.leave(id)
    changed()
end)

local function registerNow()
    if A.register() then
        pushStatus(true)
        menuDirty = true
    end
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
    menuOpen[id] = nil
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
end)

RegisterNetEvent("op77_race:openMenu", function()
    local id = playerIdOf(source)
    if id == nil or throttled(id, 200) then return end
    menuOpen[id] = true
    pushMenu(id)
end)

RegisterNetEvent("op77_race:closeMenu", function()
    local id = playerIdOf(source)
    if id then menuOpen[id] = nil end
end)

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

local MODES = { trial = "trial", timetrial = "trial", grid = "grid", street = "grid", foot = "foot", rooftop = "foot" }

RegisterCommand("race", function(source)
    local id = playerIdOf(source)
    if id == nil then return output(source, "race", false, "race must be used in-game") end
    TriggerClientEvent("op77_race:panel", id, true)
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
    if def == nil then return output(source, raw, false, "usage: /race.join trial|street|rooftop [course]") end
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
    local lines = { ("core %s: %s"):format(Config.core, A.registered and "registered" or "not registered") }
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
        if ok then changed() end
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
    if ok and action == "save" then changed() end
    output(source, raw, ok, ok and message or Ed.message(message))
end, true)

-- Staff: start a queued street or rooftop race now, even below its minimum.
RegisterCommand("race.force", function(source, args, raw)
    local def = A.byKey[MODES[tostring(args[1] or "grid"):lower()] or ""]
    if def == nil or def.mode == "trial" then return output(source, raw, false, "usage: /race.force street|rooftop") end
    if L.size(def.key) == 0 then return output(source, raw, false, "Nobody is queued") end
    local ok, reason = L.launch(def, E.nowMs(), true)
    output(source, raw, ok, ok and (def.label .. " started") or tostring(reason))
end, true)

-- ---------------------------------------------------------------- ticks --

RaceCourses.load()
RaceRecords.load()

CreateThread(function()
    local lastStatusAt, lastMenuAt = 0, 0
    while true do
        Wait(Engine.tickMs or 100)
        local now = E.nowMs()
        local ok, err = pcall(E.tick, now)
        if not ok then log("engine tick failed: " .. tostring(err)) end
        ok, err = pcall(L.tick, now)
        if not ok then log("lobby tick failed: " .. tostring(err)) end
        if statusDirty or now - lastStatusAt >= 2000 then
            statusDirty, lastStatusAt = false, now
            pushStatus(false)
        end
        if menuDirty and now - lastMenuAt >= 500 then
            menuDirty, lastMenuAt = false, now
            for playerId in pairs(menuOpen) do
                if Open77.players.name(playerId) ~= nil then pushMenu(playerId) else menuOpen[playerId] = nil end
            end
        end
    end
end)
