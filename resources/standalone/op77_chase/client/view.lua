-- op77_chase client view: what the server sends (op77_chase:hud for a match, 1v1 or Most
-- Wanted; op77_chase:queue for a queue) turned into Light RP's activity HUD
-- (exports.op77_lightrp:ActivityHudShow), and the transitions into one-off pushes
-- (ActivityHudPush "banner" / "result"). Pure Lua, no native: tests/client_test.lua.
--
--   ChaseView.hud(payload)          -> hud | nil      a match (nil when idle)
--   ChaseView.queue(payload)        -> hud | nil      a queue (nil when not queued or busy)
--   ChaseView.beats(prev, payload)  -> { { kind, payload }, ... }
--   ChaseView.split(text, max)      -> { lines }      a long message as feed lines
ChaseView = {}
local V = ChaseView

local WANTED = "chase.wanted"
V.WANTED = WANTED

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

function V.clock(ms)
    local s = math.ceil(math.max(0, num(ms) or 0) / 1000)
    return ("%d:%02d"):format(s // 60, s % 60)
end

local function secs(ms) return ("%ds"):format(math.max(0, math.ceil((num(ms) or 0) / 1000))) end
local function metres(m) m = num(m); return m and ("%d m"):format(math.floor(m + 0.5)) or "-" end

local function modeLabel(mode, wanted)
    if mode == "foot" then return wanted and "runner on foot" or "on foot" end
    if mode == "vehicle" then return wanted and "car chase" or "by car" end
    return "car or foot"
end

-- Match states -> the HUD's phases.
local PHASE = { placing = "countdown", countdown = "countdown", active = "running", intermission = "running", resolved = "ended" }

local function inMatch(p) return type(p) == "table" and p.state ~= nil and p.state ~= "idle" end
local function isWanted(p) return type(p) == "table" and p.activity == WANTED end

local function timer(remainingMs, label)
    local ms = num(remainingMs)
    if ms == nil then return nil end
    return { remainingMs = math.max(0, math.floor(ms)), label = label }
end

local function boardingText(b, active)
    if type(b) ~= "table" then return nil end
    if num(b.metres) then
        return active and ("Your car is %d m away - get in"):format(b.metres)
            or ("Your car is %d m away - driver door on its left"):format(b.metres)
    end
    return "Get in your car"
end

-- ---------------------------------------------------------------- 1v1 (chase.1v1)

V.DUEL_LINES = {
    runner_escaped   = { won = "You lost him.", lost = "He got away." },
    runner_busted    = { won = "Busted.", lost = "You were busted." },
    runner_down      = { won = "Target down.", lost = "You went down." },
    cop_down         = { won = "The cop is down.", lost = "You went down." },
    time_expired     = { won = "You survived the clock.", lost = "Out of time." },
    runner_timed_out = { won = "Time's up - you never lost him.", lost = "Time's up - you never shook him." },
    opponent_left    = { won = "Your opponent left.", lost = "You left the chase." },
}

local function duelLine(outcome, won)
    local l = V.DUEL_LINES[outcome]
    if l == nil then return won and "You win." or "Round over." end
    return won and l.won or l.lost
end

local function duelRound(p)
    if p.decider then return "Decider" end
    return ("Round %d/%d"):format(math.max(1, num(p.round) or 1), math.max(1, num(p.roundCount) or 1))
end

local function duelResultTitle(result)
    if result == "void" then return "Called off" end
    if result == "draw" then return "Draw" end
    return result == "win" and "Match won" or "Match lost"
end

local function duel(p)
    local role, state = p.role, p.state
    local runner = role == "runner"
    local score = ("%d - %d"):format(num(p.scoreSelf) or 0, num(p.scoreOpponent) or 0)
    local hud = {
        activity = p.activity or "chase.1v1", title = "NCPD Chase", phase = PHASE[state] or "running",
        subtitle = duelRound(p) .. (p.opponentName and (" - vs " .. tostring(p.opponentName)) or ""),
        stats = { { label = "Role", value = runner and "RUNNER" or (role == "cop" and "COP" or "-") }, { label = "Score", value = score } },
    }
    local left = num(p.remainingMs)
    if state == "placing" then
        hud.objective = "Moving to the chase area"
    elseif state == "countdown" then
        hud.timer, hud.countdown = timer(left, "Start"), left
        hud.objective = boardingText(p.boarding, false) or (runner
            and ("You run. Hold a %d m gap to escape."):format(math.floor(num(p.escapeDistance) or 0))
            or ("You hunt. Stay within %d m to make the arrest."):format(math.floor(num(p.bustDistance) or 0)))
    elseif state == "active" then
        hud.timer = p.overtime and { remainingMs = 0, label = "Overtime" } or timer(left, "Time")
        if runner and num(p.separation) then hud.stats[#hud.stats + 1] = { label = "Gap", value = metres(p.separation) } end
        local escape = num(p.escapeProgress)
        if escape then
            hud.progress = { { id = "escape", label = runner and "Escaping" or "He is getting away", value = escape,
                tone = runner and "success" or "danger" } }
        elseif p.copReleased and num(p.bustMeter) then
            hud.progress = { { id = "bust", label = runner and "Being arrested" or "Arrest", value = p.bustMeter,
                tone = runner and "danger" or "accent" } }
        end
        if num(p.stalledMs) then hud.objective = "Crash - engine stalled " .. secs(p.stalledMs)
        elseif p.boarding then hud.objective = boardingText(p.boarding, true)
        elseif not p.copReleased then hud.objective = role == "cop" and "Hold - the runner has a head start" or "Head start - go"
        elseif p.bustClosing then hud.objective = role == "cop" and "Arrest in progress - stay on him" or "You are being cuffed - move!"
        elseif p.bustContact then hud.objective = role == "cop" and "In range - he has to stop for the cuffs" or "He is on you - keep moving"
        else hud.objective = runner and "Get away from him" or "Catch him" end
    elseif state == "intermission" then
        hud.timer = timer(left, "Next")
        hud.objective = ("%s %s in %s - roles swap"):format(duelLine(p.outcome, p.won == true),
            p.nextIsDecider and "Decider" or ("Round %d"):format(num(p.nextRound) or 0), secs(left))
    elseif state == "resolved" then
        hud.timer = timer(left, "Back in")
        hud.objective = p.matchResult == "void" and "Nothing counts."
            or (duelResultTitle(p.matchResult) .. " - " .. duelLine(p.outcome, p.won == true))
    end
    return hud
end

-- ---------------------------------------------------------------- Most Wanted (chase.wanted)

V.WANTED_LINES = {
    runner_busted    = { title = "Busted", runner = "You were cuffed.", cop = "Suspect in custody." },
    runner_down      = { title = "Takedown", runner = "You went down.", cop = "Suspect down." },
    time_expired     = { title = "Survived", runner = "You outlasted the NCPD.", cop = "He outlasted the unit." },
    runner_extracted = { title = "Extracted", runner = "You made the extraction.", cop = "He made the extraction." },
    runner_left      = { title = "Runner gone", runner = "You left.", cop = "The runner left. No score." },
    void             = { title = "Called off", runner = "Nothing counts.", cop = "Nothing counts." },
}

local function wantedLine(outcome, wasRunner)
    local l = V.WANTED_LINES[outcome] or V.WANTED_LINES.void
    return wasRunner and l.runner or l.cop, l.title
end

-- Did my side win that round?
local function wantedWon(outcome, wasRunner)
    local runnerWins = outcome == "time_expired" or outcome == "runner_extracted"
    local copsWin = outcome == "runner_busted" or outcome == "runner_down"
    if wasRunner then return runnerWins end
    return copsWin
end

local function wantedRound(p)
    return ("Round %d/%d"):format(math.max(1, num(p.round) or 1), math.max(1, num(p.roundCount) or 1))
end

local function wantedScoreboard(p, teams)
    if type(p.scoreboard) ~= "table" then return nil end
    local rows = {}
    for _, row in ipairs(p.scoreboard) do
        if type(row) == "table" and row.name then
            local name = tostring(row.name)
            if row.left then name = name .. " (left)" end
            rows[#rows + 1] = { name = name, self = row.self == true or nil,
                values = { tostring(num(row.points) or 0), V.clock(row.runnerMs), tostring(num(row.arrests) or 0), tostring(num(row.assists) or 0) },
                team = teams and (row.runner and 1 or 2) or nil }
            if #rows >= 16 then break end
        end
    end
    if #rows == 0 then return nil end
    return { columns = { "Pts", "Run", "Arr", "Ast" }, rows = rows }
end

local function selfRow(p)
    for _, row in ipairs(type(p.scoreboard) == "table" and p.scoreboard or {}) do
        if type(row) == "table" and row.self then return row end
    end
    return nil
end

local function wantedObjective(p)
    local runner = p.role == "runner"
    if num(p.stalledMs) then return "Crash - engine stalled " .. secs(p.stalledMs) end
    if p.boarding then return boardingText(p.boarding, true) end
    if runner then
        if p.bustClosing then return "You are being cuffed - MOVE!" end
        if num(p.extractionDistance) then return ("Extraction %s away - get there to win"):format(metres(p.extractionDistance)) end
        if p.spotted then return "Dispatch has your position - change direction" end
        if num(p.escapeProgress) then return "No cop close - keep it up to shake them" end
        return "Lose them. Survive the clock."
    end
    if p.respawning then return "Back in service in a moment" end
    if p.released == false then return "Hold - dispatch releases you in " .. secs(p.heldMs) end
    if p.bustClosing then return "Arrest in progress - stay on him" end
    if p.bustContact then return "In range - pin him down" end
    if type(p.extraction) == "table" then return "He is heading for the extraction - cut him off" end
    if type(p.sighting) == "table" then
        return ("Last sighting %s ago - %d m circle on your map"):format(secs(p.sighting.ageMs), math.floor(num(p.sighting.radius) or 0))
    end
    return "Find him - dispatch will call it in"
end

local function wanted(p)
    local role, state = p.role, p.state
    local runner = role == "runner"
    local roundText = wantedRound(p)
    local hud = {
        activity = WANTED, title = "Most Wanted", phase = PHASE[state] or "running",
        subtitle = runner and (roundText .. " - YOU RUN")
            or (p.runnerName and ("%s - runner %s"):format(roundText, tostring(p.runnerName)) or roundText),
    }
    local left = num(p.remainingMs)
    local playing = state == "placing" or state == "countdown" or state == "active"
    if playing and role then
        hud.teams = { { name = "Runner", color = "danger", self = runner or nil }, { name = "NCPD", color = "info", self = (role == "cop") or nil } }
    end
    if state == "active" then
        local heat = { label = "Heat", value = ("%d/%d"):format(num(p.heat) or 1, num(p.heatCount) or 1) }
        if runner then
            hud.stats = { heat, { label = "Cops near", value = tostring(num(p.copsNearby) or 0) },
                { label = "Nearest", value = metres(p.nearestCop) }, { label = "Points", value = tostring(num(p.points) or 0) } }
        else
            hud.stats = { heat, { label = "Runner", value = num(p.targetDistance) and ("~%d m"):format(p.targetDistance) or "?" },
                { label = "Points", value = tostring(num(p.points) or 0) } }
        end
        hud.timer = p.overtime and { remainingMs = 0, label = "Overtime" } or timer(left, "Time")
        local progress = {}
        local bust = num(p.bustMeter) or 0
        if bust > 0 or p.bustClosing then
            progress[#progress + 1] = { id = "bust", label = runner and "Being cuffed" or "Arrest", value = bust,
                tone = runner and "danger" or "accent" }
        end
        if runner and num(p.escapeProgress) then
            progress[#progress + 1] = { id = "shake", label = "Shaking them", value = p.escapeProgress, tone = "success" }
        end
        if num(p.heatProgress) then
            progress[#progress + 1] = { id = "heat", label = ("Heat %d"):format(num(p.heat) or 1), value = p.heatProgress, tone = "info" }
        end
        hud.progress = #progress > 0 and progress or nil
        hud.objective = wantedObjective(p)
    else
        hud.stats = { { label = "Role", value = runner and "RUNNER" or (role == "cop" and "NCPD" or "-") },
            { label = "Points", value = tostring(num(p.points) or 0) } }
        if state == "placing" then
            hud.objective = "Moving to the chase area"
        elseif state == "countdown" then
            hud.timer, hud.countdown = timer(left, "Start"), left
            hud.objective = boardingText(p.boarding, false) or (runner
                and ("You run: %s head start. Survive or reach the extraction."):format(secs(p.headStartMs))
                or "NCPD: wait for dispatch, then box him in - several cops cuff faster.")
        elseif state == "intermission" then
            hud.timer = timer(left, "Next")
            local last = type(p.lastRound) == "table" and p.lastRound or {}
            local line, title = wantedLine(last.outcome, p.wasRunner == true)
            local nextText = p.nextIsYou and "you run next" or (p.nextRunnerName and ("next runner: " .. tostring(p.nextRunnerName)) or "next round")
            hud.objective = ("%s - %s +%d, %s"):format(title, line, num(p.gained) or 0, nextText)
        elseif state == "resolved" then
            hud.timer = timer(left, "Back in")
            hud.objective = p.void and tostring(p.reason or "Called off. Nothing counts.")
                or ("Final: #%d of %d with %d points"):format(num(p.placement) or 0, num(p.total) or 0, num(p.points) or 0)
        end
    end
    hud.scoreboard = wantedScoreboard(p, hud.teams)
    return hud
end

function V.hud(p)
    if not inMatch(p) then return nil end
    if isWanted(p) then return wanted(p) end
    return duel(p)
end

-- ---------------------------------------------------------------- queues

function V.queue(q)
    if type(q) ~= "table" or q.queued ~= true or q.busy then return nil end
    local position, total = num(q.position), num(q.total)
    if isWanted(q) then
        local hud = { activity = WANTED, title = "Most Wanted", phase = "lobby" }
        if q.joining then
            hud.subtitle = ("Match on - round %d/%d"):format(num(q.round) or 1, num(q.roundCount) or 1)
            hud.objective = "You join at the next round. Keep playing."
            return hud
        end
        local need = num(q.min) or 3
        hud.subtitle = ("Queued %d/%d - %s"):format(position or 1, total or position or 1, modeLabel(q.mode, true))
        hud.stats = { { label = "Waiting", value = tostring(total or 1) }, { label = "Needed", value = tostring(need) },
            { label = "Max", value = tostring(num(q.max) or 8) } }
        if num(q.countdownMs) then
            hud.timer = timer(q.countdownMs, "Start")
            hud.objective = "Starting soon - more players can still join. /wanted leave to cancel."
        else
            hud.objective = ("Waiting for %d more. Keep playing - /wanted leave to cancel."):format(math.max(1, need - (total or 1)))
        end
        return hud
    end
    return { activity = q.activity or "chase.1v1", title = "NCPD Chase", phase = "lobby",
        subtitle = ("Queued %d/%d - %s"):format(position or 1, total or position or 1, modeLabel(q.mode, false)),
        objective = "Waiting for an opponent. Keep playing - /chase leave to cancel." }
end

-- ---------------------------------------------------------------- transitions

local function sameRound(prev, p)
    return inMatch(prev) and prev.matchId == p.matchId and prev.round == p.round
end

function V.beats(prev, p)
    local out = {}
    if not inMatch(p) then return out end
    local wantedMode = isWanted(p)
    local runner = p.role == "runner"
    local was = sameRound(prev, p) and prev.state or nil
    local function banner(title, text, tone, ms)
        out[#out + 1] = { kind = "banner", payload = { title = title, text = text, tone = tone or "accent", durationMs = ms or 3000 } }
    end
    if p.state == "countdown" and was ~= "countdown" then
        if wantedMode then
            banner(wantedRound(p), runner and "You are the RUNNER" or ("NCPD - the runner is " .. tostring(p.runnerName or "?")), "accent", 3500)
        else
            banner(duelRound(p), runner and "You run" or "You hunt", "accent", 3500)
        end
    elseif p.state == "active" and was == "countdown" then
        if wantedMode and not runner then banner("GO", "Hold for dispatch", "accent", 1500)
        else banner("GO", runner and "Lose them!" or "Hunt him down", "accent", 1500) end
    end
    if wantedMode and p.state == "active" and was == "active" then
        if p.role == "cop" and prev.released == false and p.released == true then banner("Dispatch", "You're up - go!", "accent", 2000) end
        if (num(p.heat) or 1) > (num(prev.heat) or 1) then banner(("Heat %d"):format(p.heat), nil, "danger", 2500) end
    end
    local sameMatch = inMatch(prev) and prev.matchId == p.matchId
    if p.state == "intermission" and not (sameMatch and prev.state == "intermission") then
        if wantedMode then
            local last = type(p.lastRound) == "table" and p.lastRound or {}
            local line, title = wantedLine(last.outcome, p.wasRunner == true)
            local gained = num(p.gained) or 0
            banner(title, line .. (gained > 0 and (" +%d"):format(gained) or ""), wantedWon(last.outcome, p.wasRunner == true) and "success" or "danger", 4000)
        else
            local won = p.won == true
            banner(won and "Round won" or "Round lost", duelLine(p.outcome, won), won and "success" or "danger", 4000)
        end
    end
    if p.state == "resolved" and not (sameMatch and prev.state == "resolved") then
        if wantedMode then
            local me = selfRow(p) or {}
            local result = { title = p.void and "Called off" or "Most Wanted", durationMs = 10000 }
            if p.void then
                result.subtitle = tostring(p.reason or "Nothing counts.")
            else
                result.placement = num(p.placement)
                result.subtitle = ("#%d of %d"):format(num(p.placement) or 0, num(p.total) or 0)
                result.lines = { { label = "Points", value = tostring(num(me.points) or num(p.points) or 0) },
                    { label = "Time as runner", value = V.clock(me.runnerMs) },
                    { label = "Arrests", value = tostring(num(me.arrests) or 0) },
                    { label = "Assists", value = tostring(num(me.assists) or 0) } }
            end
            out[#out + 1] = { kind = "result", payload = result }
        else
            local r = p.matchResult
            out[#out + 1] = { kind = "result", payload = { title = duelResultTitle(r),
                placement = (r == "win" and 1) or (r == "loss" and 2) or nil,
                subtitle = r == "void" and "Nothing counts." or duelLine(p.outcome, p.won == true),
                lines = r ~= "void" and { { label = "Score", value = ("%d - %d"):format(num(p.scoreSelf) or 0, num(p.scoreOpponent) or 0) } } or nil,
                durationMs = 10000 } }
        end
    end
    return out
end

-- ---------------------------------------------------------------- feed

-- A message as feed lines of at most `max` bytes, cut after sentences, then dashes,
-- then words: the HUD's feed cuts anything longer.
function V.split(text, max)
    max = max or 96
    text = tostring(text or ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #text <= max then return #text > 0 and { text } or {} end
    local pieces = {}
    for piece in (text .. " "):gmatch("(.-[%.!?]) ") do pieces[#pieces + 1] = piece end
    local consumed = table.concat(pieces, " ")
    if #consumed < #text then
        local rest = text:sub(#consumed + 1):gsub("^ ", "")
        if #rest > 0 then pieces[#pieces + 1] = rest end
    end
    local lines, line = {}, ""
    local function flush() if #line > 0 then lines[#lines + 1] = line; line = "" end end
    local function addWord(word)
        if #line == 0 then line = word
        elseif #line + 1 + #word <= max then line = line .. " " .. word
        else flush(); line = word end
        while #line > max do lines[#lines + 1] = line:sub(1, max); line = line:sub(max + 1) end
    end
    for _, piece in ipairs(pieces) do
        if #line > 0 and #line + 1 + #piece <= max then line = line .. " " .. piece
        elseif #piece <= max then flush(); line = piece
        else
            flush()
            for word in piece:gmatch("%S+") do addWord(word) end
        end
    end
    flush()
    return lines
end

-- A stable text for a table (to tell whether a HUD changed).
function V.key(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. V.key(value[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
