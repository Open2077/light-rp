-- op77_race client: the race in Light RP's activity HUD (op77_lightrp's client exports
-- ActivityHudShow / Push / Clear), the checkpoint visuals, sounds, the rebindable keys
-- and the staff editor preview. Nothing here decides anything: the server owns
-- admission, timing and checkpoints. This resource has no page of its own.
local Config = RaceConfig
local P = Config.presentation or {}
local M = RaceMarkers
local S = RaceShared

local state, editorState, queueState = nil, nil, nil
local effects = {}         -- sfx / vfx handles of the current run
local countdownFor = nil   -- instance:run whose countdown sound already played
local resultFor = nil      -- instance:run whose result card was pushed
local hudShown = false     -- the activity HUD currently shows ours
local keys = {}

local LABEL = { trial = "Time Trial", grid = "Street Race", foot = "Rooftop Race", pve = "Street Race vs AI" }
-- The Activities panel lives in Light RP: /race opens it through Light RP's own
-- validated UI action (server/modules/activities.lua, `activities.control`).
local CORE_ACTION = "op77_lightrp:action"

local function log(level, text)
    if Open77.log and Open77.log[level] then Open77.log[level]("[race] " .. tostring(text)) end
end

-- ---------------------------------------------------------------- HUD bridge --

-- The core's client exports are synchronous and raise when op77_lightrp is down:
-- every call is wrapped and becomes false, reason.
local function core(name, ...)
    local ok, first, second = pcall(function(...)
        local proxy = exports[Config.core]
        return proxy[name](proxy, ...)
    end, ...)
    if not ok then return false, "core_unavailable" end
    return first, second
end

local function push(kind, item)
    local ok, why = core("ActivityHudPush", kind, item)
    if not ok then log("debug", ("activity HUD %s: %s"):format(kind, tostring(why))) end
    return ok == true
end

local function decode(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" then return nil end
    local codec = type(Open77.json) == "table" and Open77.json or (type(json) == "table" and json or nil)
    if codec == nil or type(codec.decode) ~= "function" then return nil end
    local ok, decoded = pcall(codec.decode, value)
    return ok and type(decoded) == "table" and decoded or nil
end

local time = S.formatTime -- 1:23.456, the precision results are decided at

local function plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

local function hints(list)
    local out = {}
    for _, h in ipairs(list) do if h.key then out[#out + 1] = h end end
    return out
end

-- ---------------------------------------------------------------- views --

local function subtitleOf(s)
    local course = type(s.course) == "table" and s.course or {}
    local parts = {}
    if course.name then parts[#parts + 1] = course.name end
    if not course.onFoot and course.vehicle then parts[#parts + 1] = course.vehicle end
    -- the race vs AI's difficulty; a run Light RP does not rank says so
    if s.mode == "pve" and type(s.difficulty) == "string" then
        parts[#parts + 1] = s.difficulty:sub(1, 1):upper() .. s.difficulty:sub(2)
    end
    if s.friendly then parts[#parts + 1] = "FRIENDLY" elseif s.unranked then parts[#parts + 1] = "UNRANKED" end
    return table.concat(parts, " · ")
end

-- The live ranking (two racers or more), our row marked.
local function ranking(s)
    local rows = decode(s.rows)
    if type(rows) ~= "table" or #rows < 2 then return nil end
    for _, row in ipairs(rows) do row.self = row.id == s.self end
    return rows
end

local function placeOf(s, rows)
    if s.place then return s.place end
    for _, row in ipairs(rows or {}) do if row.self then return row.rank end end
    return nil
end

local function board(s, rows)
    local total = tonumber(s.progressTotal) or 0
    local out = {}
    for _, row in ipairs(rows) do
        local outOfRace = row.state == "dnf" or row.state == "left"
        out[#out + 1] = {
            name = row.name,
            self = row.self or nil,
            values = {
                total > 0 and ("%d/%d"):format(row.progress or 0, total) or tostring(row.progress or 0),
                row.state == "finished" and time(row.timeMs) or outOfRace and "OUT" or "-",
            },
        }
    end
    return { columns = { "CP", "TIME" }, rows = out }
end

local function raceHud(s)
    local rows = ranking(s)
    local laps = tonumber(s.laps) or 1
    local view = {
        activity = s.activity, title = LABEL[s.mode] or s.label or "Race", subtitle = subtitleOf(s),
        progress = { { id = "course", label = "Course",
            value = (tonumber(s.progressTotal) or 0) > 0 and (s.completed or 0) / s.progressTotal or 0 } },
    }
    local checkpoint = { label = "Checkpoint", value = ("%d/%d"):format(s.completed or 0, s.progressTotal or 0) }
    local lap = laps > 1 and { label = "Lap", value = ("%d/%d"):format(math.min(s.lap or 1, laps), laps) } or nil
    if s.mode == "trial" then
        view.stats = { checkpoint, lap,
            { label = "Personal best", value = s.personalBestMs and time(s.personalBestMs) or "-" },
            { label = "Record", value = s.recordMs and time(s.recordMs) or "-" } }
    else
        local place = placeOf(s, rows)
        -- vs AI, a one-lap course has room for the personal best against the AI
        local fourth = laps > 1 and { label = "Best lap", value = s.bestLapMs and time(s.bestLapMs) or "-" }
            or s.mode == "pve" and { label = "Best vs AI", value = s.personalBestMs and time(s.personalBestMs) or "-" } or nil
        view.stats = { { label = "Position", value = place and ("%d/%d"):format(place, rows and #rows or s.racers or 1) or "-" },
            checkpoint, lap, fourth }
    end
    -- a list with holes would stop at the first nil
    local stats = {}
    for i = 1, 4 do if view.stats[i] then stats[#stats + 1] = view.stats[i] end end
    view.stats = stats
    if rows then view.scoreboard = board(s, rows) end
    view.hints = hints({
        s.canRestart and { key = keys.restart, label = "Restart" } or {},
        s.canRespawn and { key = keys.respawn, label = "Last checkpoint" } or {},
        { key = "/race.leave", label = "Quit" },
    })

    local phase, racer = s.phase, s.state
    if phase == "loading" then
        view.phase, view.objective = "countdown", rows and "Waiting for the grid" or "Get ready"
    elseif phase == "countdown" then
        -- 10 ms or less would read as seconds: the last instant is a plain 0
        local left = math.floor(tonumber(s.remainingMs) or 0)
        view.phase, view.countdown = "countdown", left > 10 and left or 0
    elseif phase == "active" and racer == "racing" then
        view.phase = "running"
        view.timer = { remainingMs = math.floor(tonumber(s.elapsedMs) or 0), label = "TIME", countUp = true }
        if type(s.next) == "table" and s.next.finish then view.objective = "Cross the finish line" end
    elseif phase == "active" or phase == "results" or phase == "closing" then
        view.phase = "ended"
        if racer == "finished" then
            view.timer = { remainingMs = math.floor(tonumber(s.timeMs) or 0), label = "TIME", countUp = true }
            if phase == "active" then view.objective = "Finished. Waiting for the others." end
        elseif racer == "dnf" or racer == "left" then
            view.objective = "Out of the race"
        end
        if phase == "results" then
            view.timer = { remainingMs = math.floor(tonumber(s.remainingMs) or 0), label = "BACK IN" }
        end
    else
        view.phase = "running"
    end
    return view
end

local function queueHud(q)
    local queued, minimum, maximum = tonumber(q.queued) or 1, tonumber(q.minPlayers) or 2, tonumber(q.maxPlayers) or 8
    local view = {
        activity = q.activity, title = q.label or LABEL[q.mode] or "Race", subtitle = "In the queue", phase = "lobby",
        stats = { { label = "Queued", value = ("%d/%d"):format(queued, maximum) } },
        hints = { { key = "/race.leave", label = "Leave queue" } },
    }
    if type(q.windowMs) == "number" then
        view.timer = { remainingMs = math.floor(q.windowMs), label = "STARTS IN" }
        view.objective = queued >= maximum and "Grid full"
            or q.bots and "Grid forming. Bots fill the empty slots." or "Grid forming. Others can still join."
    else
        view.objective = ("Waiting for %s"):format(plural(math.max(1, minimum - queued), "more racer"))
    end
    return view
end

local function editorHud(e)
    local d = type(e.draft) == "table" and e.draft or {}
    return {
        activity = "race.editor", title = "Course editor", subtitle = d.name or d.id or "New course", phase = "lobby",
        objective = e.message or "/race.editor save when you are done",
        stats = {
            { label = "Checkpoints", value = #(d.checkpoints or {}) },
            { label = "Grid", value = #(d.grid or {}) },
            { label = "Start", value = d.start and "Set" or "Missing" },
            { label = "Laps", value = d.laps or 1 },
        },
        hints = hints({
            { key = keys["editor.start"], label = "Start" },
            { key = keys["editor.checkpoint"], label = "Checkpoint" },
            { key = keys["editor.grid"], label = "Grid slot" },
            { key = keys["editor.undo"], label = "Undo" },
        }),
    }
end

-- One HUD at a time: the editor, else the race, else the queue.
local function render()
    local view
    if editorState then view = editorHud(editorState)
    elseif state then view = raceHud(state)
    elseif queueState then view = queueHud(queueState) end
    if view == nil then
        if hudShown then core("ActivityHudClear") end
        hudShown = false
        return true
    end
    local ok, why = core("ActivityHudShow", view)
    hudShown = ok == true
    if not hudShown then log("debug", "activity HUD: " .. tostring(why)) end
    return hudShown
end

-- The result card, once per run, when the results arrive.
local function pushResult(s)
    local finished = s.state == "finished"
    local rows = ranking(s)
    local outcome = type(s.outcome) == "table" and s.outcome or {}
    local item = { title = LABEL[s.mode] or "Race", subtitle = s.course and s.course.name or nil, lines = {} }
    local function line(label, value) if value ~= nil then item.lines[#item.lines + 1] = { label = label, value = value } end end
    if not finished then
        item.placement = "DNF"
    elseif rows then
        item.placement = s.place
    elseif outcome.courseRecord then
        item.title = "Course record"
    elseif outcome.personalBest then
        item.title = "Personal best"
    else
        item.title = "Finished"
    end
    if finished then line("Time", time(s.timeMs)) end
    if (tonumber(s.laps) or 1) > 1 and s.bestLapMs then line("Best lap", time(s.bestLapMs)) end
    if s.mode == "trial" and finished then
        if outcome.personalBest and outcome.previousBestMs then line("Previous best", time(outcome.previousBestMs))
        elseif s.personalBestMs then line("Personal best", time(s.personalBestMs)) end
        if s.recordMs then line("Record", time(s.recordMs)) end
        if outcome.rank then line("Board", "#" .. tostring(outcome.rank)) end
    elseif rows then
        line("Racers", tostring(#rows))
        if s.mode == "pve" and finished then
            if outcome.personalBest then
                line("Best vs AI", outcome.previousBestMs and ("New, was " .. time(outcome.previousBestMs)) or "New")
            elseif s.personalBestMs then
                line("Best vs AI", time(s.personalBestMs))
            end
        elseif s.mode ~= "pve" and (tonumber(s.bots) or 0) > 0 then
            line("Bots", tostring(s.bots) .. (s.match and ", unranked" or ", test race not recorded"))
        end
    end
    if s.unranked and not ((tonumber(s.bots) or 0) > 0 and s.mode ~= "pve") then
        line("Ranking", s.friendly and "Friendly, unranked" or "Unranked")
    end
    item.durationMs = math.max(4000, math.min(15000, math.floor(tonumber(s.remainingMs) or 8000)))
    push("result", item)
end

-- ---------------------------------------------------------------- effects --

local function remember(kind, handle)
    if handle ~= nil then effects[#effects + 1] = { kind = kind, handle = handle } end
end

local function stopEffects()
    for _, entry in ipairs(effects) do
        if entry.kind == "sfx" then pcall(Open77.sfx.stop, entry.handle) else pcall(Open77.vfx.stop, entry.handle) end
    end
    effects = {}
end

local function sfx(event, tag, duration)
    if type(event) ~= "string" or event == "" or type(Open77.sfx) ~= "table" then return end
    local handle, reason = Open77.sfx.play(event, { tag = tag, unique = true, duration = duration })
    if handle == nil then log("debug", ("sfx %s: %s"):format(event, tostring(reason))) end
    remember("sfx", handle)
end

-- One-shots around the start line, each with an explicit duration (a nil duration
-- never expires and holds a client effect-quota slot).
local function startVfx()
    local start = state and state.course and state.course.start
    if type(Open77.vfx) ~= "table" or type(start) ~= "table" or type(start.position) ~= "table" then return end
    local yaw = math.rad(tonumber(start.heading) or 0.0)
    local fx, fy = -math.sin(yaw), math.cos(yaw)
    local rx, ry = math.cos(yaw), math.sin(yaw)
    for _, def in ipairs(P.startVfx or {}) do
        local forward, lateral = tonumber(def.forward) or 0.0, tonumber(def.lateral) or 0.0
        local handle, reason = Open77.vfx.play(def.effect, {
            position = { x = start.position.x + fx * forward + rx * lateral,
                y = start.position.y + fy * forward + ry * lateral,
                z = start.position.z + (tonumber(def.z) or 0.0) },
            orientation = { x = 0.0, y = 0.0, z = math.sin(yaw * 0.5), w = math.cos(yaw * 0.5) },
            duration = tonumber(def.duration) or 5.0,
            ignoreTimeDilation = true,
        })
        if handle == nil then log("debug", ("vfx %s: %s"):format(tostring(def.effect), tostring(reason))) end
        remember("vfx", handle)
    end
end

-- ---------------------------------------------------------------- keys --

local function keyFor(binding)
    local ok, key = pcall(Open77.input.keyFor, binding.id)
    return ok and key or binding.key
end

local function refreshKeys()
    for name, binding in pairs(Config.keys) do keys[name] = keyFor(binding) end
    for name, binding in pairs(Config.editorKeys) do keys["editor." .. name] = keyFor(binding) end
    if state or editorState then render() end
end

local function headingForEditor()
    local character = Open77.character.state()
    local yaw = type(character) == "table" and tonumber(character.yaw) or nil
    if type(character) == "table" and character.inVehicle == true and yaw ~= nil then return yaw % 360.0 end
    local view = Open77.camera.view()
    if type(view) ~= "table" or type(view.forward) ~= "table" then return yaw and yaw % 360.0 or 0.0 end
    local x, y = tonumber(view.forward.x), tonumber(view.forward.y)
    if x == nil or y == nil or math.abs(x) + math.abs(y) < 0.0001 then return 0.0 end
    -- REDengine yaw 0 faces +Y: forward = (-sin(yaw), cos(yaw)).
    return math.deg(math.atan(-x, y)) % 360.0
end

local function registerKeys()
    local function bind(binding, handler)
        local ok, effective = RegisterKeyMapping(binding.id, binding.name, binding.key, handler)
        if not ok then log("error", ("key mapping %s refused: %s"):format(binding.id, tostring(effective))) end
    end
    bind(Config.keys.respawn, function()
        if state and state.canRespawn then TriggerServerEvent("op77_race:respawn") end
    end)
    bind(Config.keys.restart, function()
        if state and state.canRestart then TriggerServerEvent("op77_race:restart") end
    end)
    for action, binding in pairs(Config.editorKeys) do
        bind(binding, function()
            if editorState == nil then return end
            TriggerServerEvent("op77_race:editorAction", { action = action, heading = headingForEditor() })
        end)
    end
    refreshKeys()
end

AddEventHandler("open77:keybinds:changed", refreshKeys)

-- ---------------------------------------------------------------- server --

RegisterNetEvent("op77_race:state", function(payload)
    if type(payload) ~= "table" then return end
    local previous = state
    state = payload
    local runKey = tostring(payload.instance) .. ":" .. tostring(payload.run)
    if previous == nil or previous.instance ~= payload.instance or previous.run ~= payload.run then stopEffects() end
    if payload.phase == "countdown" and payload.state == "countdown" and countdownFor ~= runKey then
        countdownFor = runKey
        sfx(P.countdownSfx, "op77_race_countdown", 4.0)
    end
    M.sync(payload)
    render()
    if payload.phase == "results" and resultFor ~= runKey then
        resultFor = runKey
        pushResult(payload)
    end
end)

RegisterNetEvent("op77_race:pulse", function(payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "go" then
        sfx(P.goSfx, "op77_race_go", 4.0)
        startVfx()
        push("banner", { title = "GO", tone = "success", durationMs = 1200 })
    elseif payload.kind == "checkpoint" then
        sfx(P.checkpointSfx, "op77_race_checkpoint", 1.0)
        push("feed", { text = ("Checkpoint %d/%d  %s"):format(payload.completed or 0, payload.total or 0, time(payload.splitMs)) })
    elseif payload.kind == "lap" then
        sfx(P.lapSfx, "op77_race_lap", 3.0)
        local final = payload.lap ~= nil and payload.lap == payload.laps
        push("banner", { title = final and "FINAL LAP" or ("LAP %d/%d"):format(payload.lap or 1, payload.laps or 1),
            text = payload.lastLapMs and ("Last lap " .. time(payload.lastLapMs)) or nil, durationMs = 2200 })
    elseif payload.kind == "finish" then
        sfx(P.finishSfx, "op77_race_finish", 4.0)
        local outcome = type(payload.outcome) == "table" and payload.outcome or {}
        push("banner", { title = "FINISH", tone = "success", durationMs = 2000,
            text = outcome.courseRecord and "Course record" or outcome.personalBest and "Personal best" or time(payload.timeMs) })
    end
end)

RegisterNetEvent("op77_race:clear", function()
    state, countdownFor = nil, nil
    M.clear()
    stopEffects()
    render()
end)

-- The queue of a street or rooftop race: { activity, label, mode, queued, minPlayers,
-- maxPlayers, windowMs } while queued, false once out of it (launched or left).
RegisterNetEvent("op77_race:queue", function(payload)
    queueState = type(payload) == "table" and payload or nil
    render()
end)

-- /race: the races are joined from Light RP's Activities panel.
RegisterNetEvent("op77_race:activities", function()
    TriggerServerEvent(CORE_ACTION, { type = "activities.control", operation = "open" })
end)

RegisterNetEvent("op77_race:editor", function(payload)
    editorState = type(payload) == "table" and payload or nil
    M.preview(editorState and editorState.draft or nil)
    render()
end)

-- ---------------------------------------------------------------- lifecycle --

AddEventHandler("onClientResourceStart", function(name)
    if name == Config.core then
        -- A restarted core forgot our HUD: the watchdog below shows it again.
        hudShown = false
        return
    end
    if name ~= GetCurrentResourceName() then return end
    registerKeys()
    -- After a reconnect or a resource restart mid-race, ask for the current state.
    TriggerServerEvent("op77_race:ready")
    CreateThread(function()
        while true do
            Wait(1000)
            -- Keep the checkpoint marker alive (a lost native handle is rebuilt).
            if state ~= nil then M.sync(state) end
            -- A HUD refused while Light RP was down or still loading its page.
            if not hudShown and (state or editorState or queueState) then render() end
        end
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == Config.core then hudShown = false return end
    if name ~= GetCurrentResourceName() then return end
    -- Light RP drops the HUD of a stopped owner by itself.
    M.clear()
    M.clearPreview()
    stopEffects()
end)
