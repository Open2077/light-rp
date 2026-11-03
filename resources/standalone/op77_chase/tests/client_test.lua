-- op77_chase client: the view (server payloads -> Light RP's activity HUD shape, within
-- its documented limits so nothing gets cut), the transitions (banner / result), the
-- feed split, and client/main.lua against stubbed exports: ActivityHud calls and their
-- pcall'd fallback to notifications, the hudFeed flag, op77_map3d (runner's dot hidden
-- from the cops, extraction blip + GPS saved and restored, sighting blip, re-apply when
-- the map reloads), cleanup on idle and on stop.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test client_test.lua
dofile("client/view.lua")
local V = ChaseView

-- ---------------------------------------------------------------- the HUD contract (op77_lightrp README)
local PHASES = { lobby = true, countdown = true, running = true, ended = true }
local TONES = { accent = true, danger = true, info = true, success = true }
local function str(v, max, what)
    assert(v == nil or (type(v) == "string" and #v > 0 and #v <= max), ("%s: %q longer than %d"):format(what, tostring(v), max))
end
local function list(v, max, what)
    if v == nil then return {} end
    assert(type(v) == "table" and #v >= 1 and #v <= max, what .. ": 1.." .. max .. " entries")
    return v
end
local function checkHud(h)
    assert(type(h) == "table" and PHASES[h.phase], "phase")
    str(h.activity, 48, "activity"); str(h.title, 48, "title"); str(h.subtitle, 80, "subtitle"); str(h.objective, 120, "objective")
    if h.timer then assert(type(h.timer.remainingMs) == "number" and h.timer.remainingMs >= 0); str(h.timer.label, 16, "timer label") end
    if h.countdown then assert(type(h.countdown) == "number" and h.countdown > 10 and h.countdown <= 60000, "countdown in ms") end
    for _, s in ipairs(list(h.stats, 4, "stats")) do str(s.label, 24, "stat label"); str(s.value, 24, "stat value") end
    for _, p in ipairs(list(h.progress, 3, "progress")) do
        assert(type(p.value) == "number" and p.value >= 0 and p.value <= 1 and TONES[p.tone], "progress value/tone")
        str(p.label, 24, "progress label"); str(p.id, 32, "progress id")
    end
    local teams = list(h.teams, 4, "teams")
    for _, t in ipairs(teams) do str(t.name, 24, "team") end
    if h.scoreboard then
        local cols = list(h.scoreboard.columns, 4, "columns")
        for _, c in ipairs(cols) do str(c, 16, "column") end
        local selfCount = 0
        for _, r in ipairs(list(h.scoreboard.rows, 16, "rows")) do
            str(r.name, 32, "row name")
            assert(#r.values == #cols, "a value per column")
            for _, v in ipairs(r.values) do str(v, 16, "cell") end
            if r.self then selfCount = selfCount + 1 end
            assert(r.team == nil or teams[r.team], "row team index")
        end
        assert(selfCount <= 1)
    end
    for _, hint in ipairs(list(h.hints, 4, "hints")) do str(hint.key, 12, "hint key"); str(hint.label, 32, "hint label") end
    return h
end
local function checkBeat(b)
    if b.kind == "banner" then
        str(b.payload.title, 40, "banner title"); str(b.payload.text, 120, "banner text")
        assert(TONES[b.payload.tone] and b.payload.durationMs >= 800 and b.payload.durationMs <= 10000)
    elseif b.kind == "result" then
        str(b.payload.title, 40, "result title"); str(b.payload.subtitle, 80, "result subtitle")
        for _, l in ipairs(list(b.payload.lines, 6, "lines")) do str(l.label, 24, "line label"); str(l.value, 24, "line value") end
    else
        error("unexpected beat " .. tostring(b.kind))
    end
    return b
end
local function findStat(h, label) for _, s in ipairs(h.stats or {}) do if s.label == label then return s.value end end end
local function findProgress(h, id) for _, p in ipairs(h.progress or {}) do if p.id == id then return p end end end
local function kinds(beats) local s = {} for _, b in ipairs(beats) do checkBeat(b); s[#s + 1] = b.kind .. ":" .. tostring(b.payload.title) end return table.concat(s, ",") end

-- ---------------------------------------------------------------- 1v1
do
    local base = { activity = "chase.1v1", matchId = 5, mode = "vehicle", role = "cop", opponentName = "Judy", round = 1, roundCount = 2,
        scoreSelf = 0, scoreOpponent = 0, bustDistance = 15, escapeDistance = 150 }
    local function with(t) local p = {} for k, v in pairs(base) do p[k] = v end for k, v in pairs(t) do p[k] = v end return p end
    assert(V.hud({ state = "idle" }) == nil and V.hud(nil) == nil)
    local h = checkHud(V.hud(with({ state = "placing" })))
    assert(h.title == "NCPD Chase" and h.phase == "countdown" and h.subtitle == "Round 1/2 - vs Judy" and findStat(h, "Role") == "COP")
    h = checkHud(V.hud(with({ state = "countdown", remainingMs = 7000, boarding = { metres = 3 } })))
    assert(h.countdown == 7000 and h.timer.label == "Start" and h.objective:find("3 m away"))
    h = checkHud(V.hud(with({ state = "countdown", remainingMs = 7000 })))
    assert(h.objective == "You hunt. Stay within 15 m to make the arrest.")
    h = checkHud(V.hud(with({ state = "active", remainingMs = 140000, copReleased = true, bustMeter = 0.6, bustClosing = true })))
    assert(h.phase == "running" and h.timer.remainingMs == 140000 and findProgress(h, "bust").label == "Arrest" and findProgress(h, "bust").tone == "accent")
    assert(h.objective == "Arrest in progress - stay on him" and findStat(h, "Gap") == nil, "the cop never sees the gap")
    h = checkHud(V.hud(with({ state = "active", role = "runner", remainingMs = 1000, copReleased = true, separation = 42.4, escapeProgress = 0.3,
        escapeFilling = true, overtime = true })))
    assert(findStat(h, "Gap") == "42 m" and findProgress(h, "escape").tone == "success" and h.timer.label == "Overtime" and h.timer.remainingMs == 0)
    h = checkHud(V.hud(with({ state = "active", stalledMs = 2100, copReleased = true })))
    assert(h.objective == "Crash - engine stalled 3s")
    h = checkHud(V.hud(with({ state = "intermission", remainingMs = 8000, outcome = "runner_busted", won = true, nextRound = 2 })))
    assert(h.objective:find("^Busted%.") and h.objective:find("Round 2"))
    h = checkHud(V.hud(with({ state = "resolved", remainingMs = 9000, matchResult = "win", outcome = "runner_escaped", won = true, decider = true })))
    assert(h.phase == "ended" and h.subtitle:find("^Decider") and h.objective:find("Match won"))

    local beats = V.beats(with({ state = "placing" }), with({ state = "countdown", remainingMs = 10000 }))
    assert(kinds(beats) == "banner:Round 1/2")
    assert(kinds(V.beats(with({ state = "countdown" }), with({ state = "active" }))) == "banner:GO")
    assert(kinds(V.beats(with({ state = "active" }), with({ state = "active" }))) == "", "nothing while it runs")
    beats = V.beats(with({ state = "active" }), with({ state = "intermission", outcome = "runner_escaped", won = false }))
    assert(kinds(beats) == "banner:Round lost" and beats[1].payload.tone == "danger" and beats[1].payload.text == "He got away.")
    beats = V.beats(with({ state = "active" }), with({ state = "resolved", matchResult = "loss", outcome = "runner_busted", won = false, scoreSelf = 1, scoreOpponent = 2 }))
    assert(kinds(beats) == "result:Match lost" and beats[1].payload.placement == 2 and beats[1].payload.lines[1].value == "1 - 2")
    beats = V.beats(nil, with({ state = "resolved", matchResult = "void" }))
    assert(beats[1].payload.title == "Called off" and beats[1].payload.placement == nil and beats[1].payload.lines == nil)
    assert(#V.beats(with({ state = "resolved", matchResult = "win" }), with({ state = "resolved", matchResult = "win" })) == 0, "the result once")
    print("PASS view 1v1")
end

-- ---------------------------------------------------------------- Most Wanted
do
    local board = {
        { id = 2, name = "Panam", points = 70, runnerMs = 0, arrests = 1, assists = 0, placement = 1 },
        { id = 1, name = "V", points = 52, runnerMs = 37200, arrests = 0, assists = 0, placement = 2, self = true, runner = true },
        { id = 3, name = "A rather long player name over thirty-two", points = 40, runnerMs = 0, arrests = 0, assists = 1, placement = 3, left = true },
    }
    local base = { activity = "chase.wanted", matchId = 9, mode = "vehicle", role = "runner", round = 1, roundCount = 3, runnerName = "V",
        points = 52, scoreboard = board }
    local function with(t) local p = {} for k, v in pairs(base) do p[k] = v end for k, v in pairs(t) do p[k] = v end return p end

    local h = checkHud(V.hud(with({ state = "placing" })))
    assert(h.title == "Most Wanted" and h.subtitle == "Round 1/3 - YOU RUN" and h.teams[1].self and not h.teams[2].self)
    assert(h.scoreboard.columns[1] == "Pts" and h.scoreboard.rows[2].self and h.scoreboard.rows[2].values[2] == "0:38")
    assert(h.scoreboard.rows[2].team == 1 and h.scoreboard.rows[1].team == 2, "the runner's row on the Runner side")
    h = checkHud(V.hud(with({ state = "countdown", remainingMs = 9500, headStartMs = 10000 })))
    assert(h.countdown == 9500 and h.objective:find("10s head start"))
    -- The runner, running: heat, cops near, nearest, points; bust / shake / heat bars.
    h = checkHud(V.hud(with({ state = "active", remainingMs = 120000, heat = 3, heatCount = 5, heatProgress = 0.4, copsNearby = 2, nearestCop = 33,
        bustMeter = 0.25, bustClosing = true, escapeProgress = nil, extractionDistance = 640, extraction = { x = 1, y = 2, z = 3 } })))
    assert(findStat(h, "Heat") == "3/5" and findStat(h, "Cops near") == "2" and findStat(h, "Nearest") == "33 m" and findStat(h, "Points") == "52")
    assert(findProgress(h, "bust").label == "Being cuffed" and findProgress(h, "bust").tone == "danger" and findProgress(h, "heat").value == 0.4)
    assert(h.objective == "You are being cuffed - MOVE!")
    h = checkHud(V.hud(with({ state = "active", remainingMs = 120000, heat = 4, heatCount = 5, extractionDistance = 640, extraction = { x = 1, y = 2 },
        escapeProgress = 0.5 })))
    assert(h.objective == "Extraction 640 m away - get there to win" and findProgress(h, "shake").tone == "success" and findProgress(h, "bust") == nil)
    -- A held cop, then a released one: coarse distance, sighting, extraction.
    local cop = { role = "cop", runnerName = "V", scoreboard = board }
    h = checkHud(V.hud(with({ state = "active", role = "cop", remainingMs = 150000, heat = 1, heatCount = 5, released = false, heldMs = 6200 })))
    assert(h.subtitle == "Round 1/3 - runner V" and h.objective == "Hold - dispatch releases you in 7s" and findStat(h, "Runner") == "?")
    assert(findStat(h, "Cops near") == nil, "the cops never see the runner's own readout")
    h = checkHud(V.hud(with({ state = "active", role = "cop", remainingMs = 150000, heat = 2, heatCount = 5, released = true, targetDistance = 250,
        sighting = { x = 1, y = 2, z = 0, radius = 120, ageMs = 4000 } })))
    assert(findStat(h, "Runner") == "~250 m" and h.objective == "Last sighting 4s ago - 120 m circle on your map")
    h = checkHud(V.hud(with({ state = "active", role = "cop", remainingMs = 1, released = true, bustMeter = 0.9, bustClosing = true })))
    assert(findProgress(h, "bust").label == "Arrest" and h.objective == "Arrest in progress - stay on him")
    h = checkHud(V.hud(with({ state = "active", role = "cop", released = true, respawning = true, remainingMs = 5 })))
    assert(h.objective == "Back in service in a moment")
    h = checkHud(V.hud(with({ state = "intermission", role = "cop", remainingMs = 8000, lastRound = { outcome = "runner_busted" }, gained = 70,
        nextIsYou = true })))
    assert(h.objective == "Busted - Suspect in custody. +70, you run next" and h.teams == nil)
    h = checkHud(V.hud(with({ state = "resolved", remainingMs = 9000, placement = 2, total = 3 })))
    assert(h.phase == "ended" and h.objective == "Final: #2 of 3 with 52 points")
    h = checkHud(V.hud(with({ state = "resolved", void = true, reason = "Stopped by staff. Nothing counts." })))
    assert(h.objective == "Stopped by staff. Nothing counts.")
    -- 16 rows at most.
    local many = {}
    for i = 1, 20 do many[i] = { name = "P" .. i, points = i, runnerMs = 0, arrests = 0, assists = 0 } end
    h = checkHud(V.hud(with({ state = "intermission", scoreboard = many, lastRound = { outcome = "time_expired" } })))
    assert(#h.scoreboard.rows == 16)

    -- Transitions.
    assert(kinds(V.beats(with({ state = "placing" }), with({ state = "countdown" }))) == "banner:Round 1/3")
    local b = V.beats(with({ state = "placing", role = "cop" }), with({ state = "countdown", role = "cop" }))
    assert(b[1].payload.text == "NCPD - the runner is V")
    assert(V.beats(with({ state = "countdown", role = "cop" }), with({ state = "active", role = "cop" }))[1].payload.text == "Hold for dispatch")
    b = V.beats(with({ state = "active", role = "cop", released = false, heat = 1 }), with({ state = "active", role = "cop", released = true, heat = 2 }))
    assert(kinds(b) == "banner:Dispatch,banner:Heat 2" and b[2].payload.tone == "danger")
    b = V.beats(with({ state = "active" }), with({ state = "intermission", lastRound = { outcome = "time_expired" }, gained = 205, wasRunner = true }))
    assert(kinds(b) == "banner:Survived" and b[1].payload.text == "You outlasted the NCPD. +205" and b[1].payload.tone == "success")
    b = V.beats(with({ state = "active", role = "cop" }), with({ state = "intermission", role = "cop", lastRound = { outcome = "time_expired" } }))
    assert(b[1].payload.tone == "danger", "the unit lost that one")
    b = V.beats(with({ state = "intermission" }), with({ state = "resolved", placement = 2, total = 3 }))
    assert(kinds(b) == "result:Most Wanted" and b[1].payload.placement == 2 and b[1].payload.subtitle == "#2 of 3")
    assert(b[1].payload.lines[1].value == "52" and b[1].payload.lines[2].value == "0:38")
    b = V.beats(nil, with({ state = "resolved", void = true, reason = "Light RP restarted. Nothing counts." }))
    assert(b[1].payload.title == "Called off" and b[1].payload.placement == nil)
    -- A new match with the same round number is a new countdown.
    b = V.beats(with({ state = "countdown", matchId = 1 }), with({ state = "countdown", matchId = 2 }))
    assert(#b == 1)
    print("PASS view Most Wanted")
end

-- ---------------------------------------------------------------- NCPD Escape (police = "ncpd")
do
    local base = { activity = "chase.pve", matchId = 21, mode = "vehicle", role = "runner", police = "ncpd", runners = 1,
        difficulty = "hard", difficultyLabel = "Hard", ceiling = 4 }
    local function with(t) local p = {} for k, v in pairs(base) do p[k] = v end for k, v in pairs(t) do p[k] = v end return p end

    assert(V.stars(0, 0) == "-" and V.stars(2, 4) == "★★☆☆" and V.stars(5, 5) == "★★★★★" and V.stars(9, 2) == "★★★★★", "stars")
    assert(#V.stars(5, 5) <= 24, "a stat value fits")
    local h = checkHud(V.hud(with({ state = "placing" })))
    assert(h.title == "NCPD Escape" and h.subtitle == "Solo - Hard" and h.objective == "Moving to the escape area" and h.teams == nil)
    h = checkHud(V.hud(with({ state = "countdown", remainingMs = 9000, headStartMs = 6000 })))
    assert(h.countdown == 9000 and h.objective:find("6s head start") and h.objective:find("up to 4 stars"), "countdown: head start, ceiling")
    -- The head start: no star yet, the next one counted down, no meter.
    h = checkHud(V.hud(with({ state = "active", remainingMs = 160000, stars = 0, headStartMs = 4200, nextStarMs = 4200, bustMeter = 0,
        extractionInMs = 50000 })))
    assert(findStat(h, "Wanted") == "☆☆☆☆" and findStat(h, "Next star") == "5s" and h.timer.label == "Time" and h.timer.remainingMs == 160000)
    assert(h.progress == nil and h.objective == "Head start - the NCPD is on you in 5s", "no meter in the head start")
    -- Two stars, armed, the extraction up, a close call: four stats, the meter at 0.
    h = checkHud(V.hud(with({ state = "active", remainingMs = 90000, stars = 2, nextStarMs = 30000, bustArmed = true, bustMeter = 0,
        extractionDistance = 640, extraction = { x = 1, y = 2, z = 3 }, closeCalls = 1 })))
    assert(#h.stats == 4 and findStat(h, "Wanted") == "★★☆☆" and findStat(h, "Next star") == "30s" and findStat(h, "Extraction") == "640 m"
        and findStat(h, "Close calls") == "1")
    assert(findProgress(h, "bust").value == 0 and findProgress(h, "bust").tone == "danger", "the bust meter is on screen once armed")
    assert(h.objective == "Extraction 640 m away - get there to escape")
    -- Max heat, stopped: the meter fills, the HUD says why.
    h = checkHud(V.hud(with({ state = "active", remainingMs = 60000, stars = 4, bustArmed = true, bustMeter = 0.5, bustWhy = "stopped",
        extractionInMs = 2000 })))
    assert(findStat(h, "Heat") == "MAX" and findStat(h, "Next star") == nil and findProgress(h, "bust").label == "Being cuffed"
        and findProgress(h, "bust").value == 0.5 and h.objective == "You stopped - MOVE or you are cuffed!")
    h = checkHud(V.hud(with({ state = "active", remainingMs = 60000, stars = 3, bustArmed = true, bustMeter = 0.2, bustWhy = "out_of_car" })))
    assert(h.objective == "Out of the car - get back in one or you are cuffed!")
    h = checkHud(V.hud(with({ state = "active", remainingMs = 60000, stars = 1, bustArmed = true, bustMeter = 1.7, policeBlocked = true })))
    assert(findProgress(h, "bust").value == 1 and h.objective == "Your game refused the NCPD - no police this run. Keep moving.")
    h = checkHud(V.hud(with({ state = "active", remainingMs = 60000, stars = 1, boarding = { metres = 4 } })))
    assert(h.objective:find("4 m"), "his car first")
    -- A crew: runners only on the board, with their stars.
    h = checkHud(V.hud(with({ state = "active", runners = 2, remainingMs = 60000, stars = 2, scoreboard = {
        { id = 1, name = "V", runner = true, self = true, stars = 2 },
        { id = 2, name = "Judy", runner = true, outcome = "busted", seconds = 75, stars = 2 },
        { id = -1, name = "[BOT] Reyes", cop = true } } })))
    assert(h.subtitle == "Crew of 2 - Hard" and h.scoreboard.columns[2] == "Heat" and #h.scoreboard.rows == 2)
    assert(h.scoreboard.rows[1].values[1] == "Running" and h.scoreboard.rows[1].values[2] == "2★" and h.scoreboard.rows[2].values[1] == "Busted"
        and h.scoreboard.rows[2].values[3] == "1:15")
    -- Resolved.
    h = checkHud(V.hud(with({ state = "resolved", remainingMs = 7000, outcome = "escaped", how = "extraction", won = true, seconds = 98,
        stars = 4, reputation = 36 })))
    assert(h.phase == "ended" and h.objective == "Escaped - You made the extraction." and findStat(h, "Heat") == "★★★★"
        and findStat(h, "Reputation") == "+36" and findStat(h, "Time") == "1:38")
    h = checkHud(V.hud(with({ state = "resolved", void = true, reason = "Your game refused the NCPD. Called off, nothing counts." })))
    assert(h.objective:find("refused"))

    -- Transitions: GO, a star banner per rise, the result with the heat.
    local b = V.beats(with({ state = "placing" }), with({ state = "countdown", remainingMs = 10000 }))
    assert(kinds(b) == "banner:NCPD Escape")
    b = V.beats(with({ state = "countdown" }), with({ state = "active", stars = 0 }))
    assert(kinds(b) == "banner:GO" and b[1].payload.text == "Keep moving!")
    b = V.beats(with({ state = "active", stars = 0 }), with({ state = "active", stars = 2 }))
    assert(kinds(b) == "banner:★★" and b[1].payload.text == "The NCPD is on you" and b[1].payload.tone == "danger")
    b = V.beats(with({ state = "active", stars = 2 }), with({ state = "active", stars = 3 }))
    assert(b[1].payload.text == "The NCPD steps it up")
    assert(#V.beats(with({ state = "active", stars = 3 }), with({ state = "active", stars = 3 })) == 0, "nothing while the heat holds")
    b = V.beats(with({ state = "active", stars = 3 }), with({ state = "resolved", outcome = "busted", how = "arrest", won = false, seconds = 70,
        stars = 3, reputation = 12 }))
    assert(kinds(b) == "result:Busted" and b[1].payload.placement == nil and b[1].payload.lines[2].label == "Heat"
        and b[1].payload.lines[2].value == "★★★" and b[1].payload.lines[3].value == "+12")
    b = V.beats(with({ state = "active" }), with({ state = "resolved", outcome = "escaped", how = "clock", won = true, seconds = 180, stars = 5,
        reputation = 60 }))
    assert(kinds(b) == "result:Escaped" and b[1].payload.placement == 1 and b[1].payload.subtitle == "You outlasted the NCPD.")
    -- The bot cops (police = "bots") keep their own view.
    h = checkHud(V.hud({ activity = "chase.pve", matchId = 22, state = "active", role = "runner", police = "bots", runners = 1, cops = 3,
        remainingMs = 60000, heat = 1, heatCount = 3, copsNearby = 0 }))
    assert(h.subtitle == "Solo - 3 NCPD units" and findStat(h, "Cops near") == "0")
    print("PASS view NCPD Escape")
end

-- ---------------------------------------------------------------- queues, feed split, key
do
    assert(V.queue(nil) == nil and V.queue({ queued = false }) == nil)
    assert(V.queue({ activity = "chase.wanted", queued = true, busy = true }) == nil, "busy elsewhere: leave the HUD alone")
    local h = checkHud(V.queue({ activity = "chase.wanted", queued = true, position = 2, total = 2, min = 3, max = 8, mode = "foot" }))
    assert(h.phase == "lobby" and h.subtitle == "Queued 2/2 - runner on foot" and h.objective:find("Waiting for 1 more") and h.timer == nil)
    h = checkHud(V.queue({ activity = "chase.wanted", queued = true, position = 1, total = 4, min = 3, max = 8, countdownMs = 31000 }))
    assert(h.timer.remainingMs == 31000 and h.timer.label == "Start" and h.objective:find("Starting soon"))
    h = checkHud(V.queue({ activity = "chase.wanted", queued = true, joining = true, round = 2, roundCount = 4 }))
    assert(h.subtitle == "Match on - round 2/4")
    h = checkHud(V.queue({ activity = "chase.1v1", queued = true, position = 1, total = 1, mode = "vehicle" }))
    assert(h.title == "NCPD Chase" and h.subtitle == "Queued 1/1 - by car")
    h = checkHud(V.queue({ activity = "chase.pve", queued = true, mode = "foot", difficulty = "critical", difficultyLabel = "Critical" }))
    assert(h.title == "NCPD Escape" and h.subtitle == "Getting ready - on foot - Critical" and h.objective:find("/escape leave"))
    h = checkHud(V.queue({ activity = "chase.pve", queued = true, mode = "vehicle", crew = 3, crewQueued = 2, difficultyLabel = "Hard" }))
    assert(findStat(h, "Crew") == "2/3" and h.subtitle:find("Hard$"))

    local long = "Round 1/3 - YOU ARE THE RUNNER. 10s head start. Survive 2:45 or reach the extraction when it shows up. Your car is beside you: driver door on its LEFT."
    local lines = V.split(long, 96)
    assert(#lines >= 2)
    for _, l in ipairs(lines) do assert(#l <= 96 and #l > 0) end
    assert(table.concat(lines, " ") == long, "nothing lost, nothing added")
    assert(#V.split("short", 96) == 1 and #V.split("", 96) == 0)
    local words = V.split(string.rep("abcdefghij ", 30), 40)
    for _, l in ipairs(words) do assert(#l <= 40) end
    local huge = V.split(string.rep("x", 200), 96)
    assert(#huge == 3 and #huge[1] == 96)
    assert(V.key({ b = 1, a = { 2, 3 } }) == V.key({ a = { 2, 3 }, b = 1 }) and V.key({ a = 1 }) ~= V.key({ a = 2 }))
    assert(V.clock(65000) == "1:05" and V.clock(nil) == "0:00" and V.clock(400) == "0:01")
    print("PASS queues, feed split")
end

-- ---------------------------------------------------------------- client/main.lua
do
    local env = { net = {}, handlers = {}, server = {}, hud = {}, notes = {}, map = {}, state = {}, threads = 0 }
    env.state.op77_lightrp, env.state.op77_map3d, env.state.open77_notifications = "running", "running", "running"
    local hudOk, waypoint = true, { x = 9, y = 9, z = 0 }
    local noticeOk = nil -- nil: no Notice export (an older Light RP); true/false: what it answers
    env.notices = {}
    local function rec(list, ...) list[#list + 1] = table.pack(...) end
    _G.GetResourceState = function(name) return env.state[name] or "missing" end
    _G.GetCurrentResourceName = function() return "op77_chase" end
    _G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
    _G.AddEventHandler = function(name, fn) env.handlers[name] = env.handlers[name] or {}; table.insert(env.handlers[name], fn) end
    _G.TriggerServerEvent = function(name, ...) rec(env.server, name, ...) end
    _G.CreateThread = function(fn) env.threads = env.threads + 1; fn() end
    _G.Wait = function() end
    _G.exports = setmetatable({}, { __index = function(_, name)
        if name == "op77_lightrp" then
            local core = {
                ActivityHudShow = function(_, hud) rec(env.hud, "show", hud); if hudOk then return true end return false, "ui_unavailable" end,
                ActivityHudPush = function(_, kind, payload) rec(env.hud, "push", kind, payload); return hudOk end,
                ActivityHudClear = function() rec(env.hud, "clear"); return true end,
            }
            if noticeOk ~= nil then
                core.Notice = function(_, def) rec(env.notices, def); if noticeOk then return true end return false, "ui_unavailable" end
            end
            return core
        elseif name == "op77_map3d" then
            return {
                setPlayerDotsHidden = function(_, hidden, ids) rec(env.map, "dots", hidden, ids); return true end,
                addBlip = function(_, def) rec(env.map, "add", def); return "op77_chase:" .. def.id end,
                removeBlip = function(_, id) rec(env.map, "remove", id); return true end,
                getWaypoint = function() return waypoint end,
                setWaypoint = function(_, p) rec(env.map, "wp", p); waypoint = p; return true end,
                clearWaypoint = function() rec(env.map, "wpclear"); waypoint = nil; return true end,
            }
        elseif name == "open77_notifications" then
            return { show = function(_, def) rec(env.notes, def); return { ok = true } end }
        end
        error("no such resource " .. tostring(name))
    end })
    local function fire(name, ...) for _, fn in ipairs(env.handlers[name] or {}) do fn(...) end end
    local function last(list, tag) for i = #list, 1, -1 do if tag == nil or list[i][1] == tag then return list[i] end end end
    local function count(list, tag) local n = 0 for _, e in ipairs(list) do if e[1] == tag then n = n + 1 end end return n end
    dofile("client/main.lua")
    local S = ChaseClient

    -- Queued: a lobby HUD (once per change), the feed flag goes to the server.
    env.net["op77_chase:queue"]({ activity = "chase.wanted", queued = true, position = 1, total = 1, min = 3, max = 8 })
    assert(last(env.hud, "show")[2].phase == "lobby" and last(env.server)[1] == "op77_chase:hudFeed" and last(env.server)[2] == true)
    env.net["op77_chase:queue"]({ activity = "chase.wanted", queued = true, position = 1, total = 1, min = 3, max = 8 })
    assert(count(env.hud, "show") == 1 and #env.server == 1, "the same lobby is not re-sent")
    env.net["op77_chase:queue"]({ activity = "chase.wanted", queued = true, busy = true })
    assert(last(env.hud)[1] == "clear" and last(env.server)[2] == false, "busy elsewhere: our HUD goes")

    -- A cop's match: HUD, beats, the runner's dot hidden, the sighting on the map.
    local p = { activity = "chase.wanted", matchId = 3, state = "countdown", role = "cop", round = 1, roundCount = 3, runnerName = "V",
        remainingMs = 9000, hideDots = { 7 }, scoreboard = {} }
    env.net["op77_chase:hud"](p)
    assert(last(env.hud, "show")[2].countdown == 9000 and last(env.hud, "push")[2] == "banner")
    local dots = last(env.map, "dots")
    assert(dots[2] == true and dots[3][1] == 7)
    env.net["op77_chase:hud"]({ activity = "chase.wanted", matchId = 3, state = "active", role = "cop", round = 1, roundCount = 3, remainingMs = 150000,
        hideDots = { 7 }, released = true, heat = 1, heatCount = 5, sighting = { x = 10, y = 20, z = 0, radius = 160, ageMs = 0 } })
    assert(count(env.map, "dots") == 1, "the same hide is not re-sent")
    local add = last(env.map, "add")
    assert(add[2].id == "sighting" and add[2].position.x == 10 and add[2].label == "Last sighting (160 m)")
    assert(count(env.map, "wp") == 0, "a cop's GPS is his own")
    -- Feed: long lines split into the HUD's feed.
    env.net["op77_chase:feed"]({ text = string.rep("Dispatch says hello. ", 8), tone = "info", title = "Most Wanted" })
    assert(last(env.hud, "push")[2] == "feed" and #last(env.hud, "push")[3].text <= 96 and #env.notes == 0)
    -- The map reloads: everything applied again.
    fire("op77_map3d:ready")
    assert(count(env.map, "dots") == 2 and last(env.map, "add")[2].id == "sighting")
    -- Idle: dots back, blips gone, HUD cleared, feed off.
    env.net["op77_chase:hud"]({ state = "idle", activity = "chase.wanted" })
    assert(last(env.map, "dots")[2] == false and last(env.map, "remove")[2] == "op77_chase:sighting")
    assert(last(env.hud)[1] == "clear" and last(env.server)[2] == false and S.match == nil)

    -- A runner's match: the extraction is a blip and his GPS, his own waypoint comes back.
    waypoint = { x = 9, y = 9, z = 0 }
    local runner = { activity = "chase.wanted", matchId = 4, state = "active", role = "runner", round = 2, roundCount = 3, remainingMs = 60000,
        heat = 4, heatCount = 5, extraction = { x = 500, y = 600, z = 10 }, extractionDistance = 700 }
    env.net["op77_chase:hud"](runner)
    assert(last(env.map, "add")[2].id == "extraction" and last(env.map, "wp")[2].x == 500 and S.waypoint.x == 9)
    assert(last(env.map, "dots")[2] == false or count(env.map, "dots") == 3, "a runner hides nobody")
    env.net["op77_chase:hud"](runner)
    assert(count(env.map, "wp") == 1, "set once")
    env.net["op77_chase:hud"]({ activity = "chase.wanted", matchId = 4, state = "intermission", role = "runner", round = 2, roundCount = 3,
        remainingMs = 9000, lastRound = { outcome = "runner_extracted" }, wasRunner = true, gained = 176 })
    assert(last(env.map, "remove")[2] == "op77_chase:extraction" and waypoint.x == 9, "his own waypoint back")
    local banner = last(env.hud, "push")
    assert(banner[2] == "banner" and banner[3].title == "Extracted")
    -- He set his own waypoint meanwhile: left alone.
    env.net["op77_chase:hud"](runner)
    waypoint = { x = -1, y = -1, z = 0 }
    env.net["op77_chase:hud"]({ state = "idle" })
    assert(waypoint.x == -1, "a waypoint the player set himself stays")

    -- No activity HUD (an older Light RP): nothing drawn, the server keeps notifying, a
    -- feed line that still arrives becomes a notification.
    hudOk = false
    env.server = {}
    env.net["op77_chase:hud"]({ activity = "chase.1v1", matchId = 8, state = "countdown", role = "runner", round = 1, roundCount = 2, remainingMs = 5000 })
    assert(S.shown == false and (#env.server == 0 or last(env.server)[2] == false))
    S.shown = true -- the HUD went away after a show
    env.net["op77_chase:feed"]({ text = "GO.", tone = "danger", title = "NCPD Chase" })
    local note = env.notes[#env.notes][1]
    assert(note.type == "warning" and note.title == "NCPD Chase" and note.message == "GO.")
    assert(#env.notices == 0, "no Notice export: the platform toast")
    -- A Light RP with the Notice export: the line lands in Light RP's notice, never both.
    noticeOk = true
    local notes = #env.notes
    env.net["op77_chase:feed"]({ text = "Round over.", tone = "success", title = "Most Wanted" })
    local lr = env.notices[#env.notices][1]
    assert(lr.kind == "success" and lr.title == "Most Wanted" and lr.body == "Round over." and lr.durationMs == 6000)
    assert(#env.notes == notes, "Light RP showed it: no open77_notifications toast on top")
    env.net["op77_chase:feed"]({ text = "Spotted.", tone = "accent" })
    lr = env.notices[#env.notices][1]
    assert(lr.kind == "info" and lr.title == "NCPD Chase", "accent maps to info, the default title")
    -- Light RP's page is not up: Notice says no, the platform toast takes it.
    noticeOk = false
    env.net["op77_chase:feed"]({ text = "Lost him.", tone = "danger", title = "NCPD Chase" })
    assert(#env.notes == notes + 1 and env.notes[#env.notes][1].message == "Lost him." and env.notes[#env.notes][1].type == "warning")
    noticeOk = nil
    -- Light RP stopped altogether: the calls are skipped, nothing throws.
    env.state.op77_lightrp = nil
    hudOk = true
    S.shown = false
    env.net["op77_chase:hud"]({ activity = "chase.1v1", matchId = 8, state = "active", role = "runner", round = 1, roundCount = 2, remainingMs = 5000 })
    assert(S.shown == false)
    env.state.op77_lightrp = "running"
    fire("onClientResourceStart", "op77_lightrp")
    assert(S.shown == true and last(env.hud, "show")[2].title == "NCPD Chase", "drawn again when Light RP is back")
    -- This resource stops mid-extraction: the runner's own waypoint is put back.
    waypoint = { x = 3, y = 3, z = 0 }
    env.net["op77_chase:hud"](runner)
    fire("onClientResourceStop", "op77_chase")
    assert(waypoint.x == 3)

    -- NCPD Escape: the police probe. While a run is on with stars, every 4th payload sends
    -- what Open77.prevention.state() says; nothing without stars, nothing for the bot cops.
    local probes, refuse = 0, false
    _G.Open77 = { prevention = { state = function()
        probes = probes + 1
        if refuse then error("permission_denied:world.prevention") end
        return { requestedLevel = 0, populationSuppressed = true, levelAcknowledged = false, scriptAttached = true }
    end } }
    env.server = {}
    local function escapeHud(t)
        local p = { activity = "chase.pve", matchId = 30, state = "active", role = "runner", police = "ncpd", runners = 1, remainingMs = 60000,
            difficultyLabel = "Standard", ceiling = 3 }
        for k, v in pairs(t) do p[k] = v end
        env.net["op77_chase:hud"](p)
    end
    escapeHud({ stars = 0, wanted = 0, headStartMs = 3000 })
    assert(count(env.server, "op77_chase:police") == 0 and probes == 0, "no star: nothing to check")
    assert(last(env.hud, "show")[2].title == "NCPD Escape", "drawn")
    for _ = 1, 5 do escapeHud({ stars = 1, wanted = 1 }) end
    assert(count(env.server, "op77_chase:police") == 2 and probes == 2, "the 1st and the 5th payload")
    local sent = last(env.server, "op77_chase:police")[2]
    assert(sent.expected == 1 and sent.requested == 0 and sent.suppressed == true and sent.acknowledged == false and sent.attached == true)
    local n = 0
    for _ in pairs(sent) do n = n + 1 end
    assert(n == 5, "a handful of values")
    escapeHud({ police = "bots", stars = nil, wanted = nil, heat = 1, heatCount = 3 })
    escapeHud({ state = "resolved", outcome = "busted", how = "arrest", stars = 1, wanted = 1 })
    assert(count(env.server, "op77_chase:police") == 2, "not for the bots, not once resolved")
    refuse = true
    for _ = 1, 5 do escapeHud({ stars = 2, wanted = 2 }) end
    assert(count(env.server, "op77_chase:police") == 2 and probes == 4, "a throwing state(): pcall'd, nothing sent")
    _G.Open77 = nil
    escapeHud({ stars = 2, wanted = 2 })
    assert(S.match and S.match.stars == 2, "no Open77.prevention: nothing breaks")
    print("PASS client main")
end

print("PASS: op77_chase client (1v1 + Most Wanted + NCPD Escape -> activity HUD within its limits, stars + bust meter, transitions, "
    .. "queues + difficulty, feed split, HUD fallback, map3d dots/blips/GPS, NCPD police probe)")
