-- The parkour run HUD on NativeUI (was the head-up part of
-- ui/src/features/parkour/ParkourHud.tsx): the clock, the references, the checkpoint pips,
-- the bearing, the delta flash, the splits, 3-2-1-GO and the keys. client/core/parkour.lua
-- relays the server's events on E.page.parkour and plays the sounds; the page keeps the
-- course music (music.ts) and the result / DNF cards, which take the cursor.
local N = LightRpNative
local E = LightRpEvents

local P = {}
LightRpNativeParkour = P

local GO_MS, FLASH_MS = 1100, 2600
local DIFFICULTY = { easy = "Easy", medium = "Medium", hard = "Hard", extreme = "Extreme" }

local doc
local run            -- the page's RunState
local flash, flashFlip = nil, false
local goAt           -- GO stays up a moment after the start
local bearing        -- the last bearing event while it shows
local countFlip, lastCount = false, nil

-- ---- pure helpers (the page's model.ts) ------------------------------------------------
--- 1:02.345, or 12.345 under a minute (two decimals for the running clock).
local function formatTime(ms, decimals)
    if type(ms) ~= "number" or ms ~= ms or ms == math.huge or ms == -math.huge then return "--:--" end
    local t = math.max(0, math.floor(ms))
    local m, s = t // 60000, (t // 1000) % 60
    local frac = decimals == 2 and ("%02d"):format((t % 1000) // 10) or ("%03d"):format(t % 1000)
    if m > 0 then return ("%d:%02d.%s"):format(m, s, frac) end
    return ("%d.%s"):format(s, frac)
end
--- +1.234 / -0.420 (seconds), the sign always shown.
local function formatDelta(ms)
    local sign = ms < 0 and "-" or "+"
    local t = math.floor(math.abs(ms) + 0.5)
    local s, f = t // 1000, ("%03d"):format(t % 1000)
    if s >= 60 then return ("%s%d:%02d.%s"):format(sign, s // 60, s % 60, f) end
    return ("%s%d.%s"):format(sign, s, f)
end
local function decodeSplits(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for part in text:gmatch("[^,]+") do
        local v = tonumber(part)
        if v and v == v then out[#out + 1] = v end
    end
    return out
end
P.formatTime, P.formatDelta, P.decodeSplits = formatTime, formatDelta, decodeSplits

-- data-for arrays never shrink (RmlUi reads the rows it drops for a frame): spare rows are `off`.
local high = {}
local function pad(key, list, blank)
    local n = math.max(high[key] or 0, #list)
    high[key] = n
    for i = 1, #list do list[i].off = false end
    for i = #list + 1, n do
        local row = { off = true }
        for k, v in pairs(blank) do row[k] = v end
        list[i] = row
    end
    return list
end

local function model()
    return {
        on = false, quiet = false, finished = false, name = "", sub = "", clock = "0.00", cpPassed = 0, cpTotal = 0,
        hasBest = false, bestText = "", hasRecord = false, recordText = "", noRef = false,
        deltaOn = false, deltaGood = false, deltaLabel = "", deltaText = "",
        pipsOn = false, pips = {}, finishDone = false,
        bearingOn = false, bearingFinish = false, bearingAngle = 0, bearingLabel = "", bearingDist = "", riseOn = false, riseUp = false, riseText = "",
        flashOn = false, flashA = false, flashGood = false, flashBad = false, flashInfo = false, flashText = "",
        splitsOn = false, splitsTitle = "SPLITS", splits = {},
        countOn = false, countA = false, countGo = false, countText = "", goOn = false, bannerOn = false, keysOn = false,
    }
end

local function quiet()
    -- The result card (the page) owns the cursor once the run is over: the clock stays above it.
    return N.shell.hidden and not (run and run.phase == "finished")
end

local function clockText(now)
    local ms = 0
    if run.phase == "finished" then
        ms = run.finishMs or (run.goAt and (run.finishedAt or now) - run.goAt or 0)
    elseif run.phase == "running" and run.goAt then
        ms = now - run.goAt
    end
    return formatTime(ms, 2)
end

local function render()
    if not doc then return end
    if not run then
        N.patch(doc, "run", { on = false, flashOn = false, goOn = false, countOn = false, bannerOn = false, keysOn = false, splitsOn = false, bearingOn = false })
        return
    end
    local now = N.now()
    local course = run.course
    local total, passed = #course.checkpoints, #run.splits
    local last = run.splits[passed]
    local finished, running = run.phase == "finished", run.phase == "running"
    local values = {
        on = true, quiet = quiet(), finished = finished,
        name = tostring(course.name or ""),
        sub = (DIFFICULTY[course.difficulty] or "Medium") .. (course.test and " · STAFF TEST" or "") .. " · RUN " .. tostring(math.tointeger(tonumber(run.attempt) or 0) or run.attempt or ""),
        clock = clockText(now), cpPassed = math.min(passed, total), cpTotal = total,
        hasBest = run.best ~= nil, bestText = run.best and formatTime(run.best.timeMs) or "",
        hasRecord = run.record ~= nil,
        recordText = run.record and (formatTime(run.record.timeMs) .. " · " .. tostring(run.record.name or "")) or "",
        noRef = run.best == nil and run.record == nil,
        pipsOn = total > 0, finishDone = finished and run.dnf == nil,
        bannerOn = run.phase == "loading", keysOn = not finished,
    }
    values.deltaOn = last ~= nil and last.delta ~= nil and running
    if values.deltaOn then
        values.deltaGood = last.delta <= 0
        values.deltaLabel = ("%s @ CP%d"):format(last.against, last.index)
        values.deltaText = formatDelta(last.delta)
    end
    local byIndex, pips = {}, {}
    for _, s in ipairs(run.splits) do byIndex[s.index] = s end
    for i = 1, total do
        local s = byIndex[i]
        pips[i] = { done = s ~= nil, good = s ~= nil and s.delta ~= nil and s.delta <= 0, bad = s ~= nil and s.delta ~= nil and s.delta > 0,
            next = s == nil and i - 1 == passed and running }
    end
    values.pips = pad("pips", pips, { done = false, good = false, bad = false, next = false })
    -- the splits: the last seven
    local rows = {}
    for i = math.max(1, passed - 6), passed do
        local s = run.splits[i]
        rows[#rows + 1] = { index = s.index, time = formatTime(s.elapsed), hasDelta = s.delta ~= nil,
            delta = s.delta and formatDelta(s.delta) or "", good = s.delta ~= nil and s.delta <= 0 }
    end
    values.splits = pad("splits", rows, { index = 0, time = "", hasDelta = false, delta = "", good = false })
    values.splitsOn = passed > 0 and not finished
    local target = run.best and run.best.timeMs or run.record and run.record.timeMs
    values.splitsTitle = "SPLITS" .. (target and (" · VS " .. (run.best and "PB" or "RECORD")) or "")
    -- the bearing
    local b = not finished and bearing or nil
    values.bearingOn = b ~= nil
    if b then
        local rise = tonumber(b.rise) or 0
        values.bearingFinish = b.label == "FINISH"
        values.bearingAngle = -(tonumber(b.angle) or 0)
        values.bearingLabel = tostring(b.label or "")
        values.bearingDist = ("%d m"):format(math.max(0, math.floor(tonumber(b.distance) or 0)))
        values.riseOn = math.abs(rise) >= 2
        values.riseUp = rise > 0
        values.riseText = ("%d m"):format(math.floor(math.abs(rise)))
    end
    N.patch(doc, "run", values)
end

local function setFlash(text, tone)
    flash = { at = N.now() }
    flashFlip = not flashFlip
    N.patch(doc, "run", { flashOn = true, flashA = flashFlip, flashText = text,
        flashGood = tone == "good", flashBad = tone == "bad", flashInfo = tone == "info" })
end
local function clearFlash()
    flash = nil
    N.patch(doc, "run", { flashOn = false })
end

--- The clock, the countdown digits and the timed pieces. Returns the thread's sleep.
local function tick()
    if not doc or not run then return 200 end
    local now = N.now()
    local values, wait = { clock = clockText(now) }, 100
    if run.phase == "running" then wait = 16 end
    if run.phase == "countdown" and run.countdownEnd then
        local left = math.ceil((run.countdownEnd - now) / 1000)
        local text = left > 0 and tostring(left) or "GO"
        if text ~= lastCount then countFlip = not countFlip; lastCount = text end
        values.countOn, values.countText, values.countGo, values.countA = true, text, left <= 0, countFlip
        wait = math.min(wait, 50)
    else
        values.countOn = false
        lastCount = nil
    end
    if goAt and (now - goAt >= GO_MS or run.phase ~= "running") then goAt = nil end
    values.goOn = goAt ~= nil
    if flash and now - flash.at >= FLASH_MS then flash = nil; values.flashOn = false end
    N.patch(doc, "run", values)
    return wait
end

local function onEvent(e)
    if type(e) ~= "table" then return end
    local kind, now = e.kind, N.now()
    if kind == "bearing" then
        bearing = not e.hide and e or nil
        if run then render() end
        return
    elseif kind == "run" then
        if type(e.course) ~= "table" then return end
        if type(e.course.checkpoints) ~= "table" then e.course.checkpoints = {} end
        local elapsed = type(e.elapsedMs) == "number" and e.elapsedMs or nil
        run = {
            course = e.course, attempt = e.attempt,
            phase = (e.resume and e.phase == "running") and "running" or e.phase == "finished" and "finished" or "loading",
            best = type(e.best) == "table" and { timeMs = e.best.timeMs, splits = decodeSplits(e.best.splits) } or nil,
            record = type(e.record) == "table" and { timeMs = e.record.timeMs, name = e.record.name, splits = decodeSplits(e.record.splits) } or nil,
            splits = {}, goAt = elapsed and now - elapsed or nil,
        }
        bearing, goAt = nil, nil
        clearFlash()
    elseif kind == "ended" then
        run, bearing, goAt = nil, nil, nil
        clearFlash()
    elseif not run then
        return
    elseif kind == "countdown" then
        run.phase, run.countdownEnd = "countdown", now + (tonumber(e.goInMs) or 0)
        run.splits, run.finishMs, run.result, run.dnf, run.goAt, run.finishedAt = {}, nil, nil, nil, nil, nil
    elseif kind == "go" then
        run.phase, run.goAt, run.countdownEnd = "running", now, nil
        goAt = now
    elseif kind == "cp" then
        local against = e.bestMs ~= nil and "PB" or e.recordMs ~= nil and "REC" or nil
        local ref = e.bestMs or e.recordMs
        local split = { index = e.index, elapsed = e.elapsedMs, delta = ref ~= nil and e.elapsedMs - ref or nil, against = against }
        if split.delta ~= nil then setFlash(against .. " " .. formatDelta(split.delta), split.delta <= 0 and "good" or "bad") end
        run.goAt = now - (tonumber(e.elapsedMs) or 0)
        local kept = {}
        for _, s in ipairs(run.splits) do if s.index ~= e.index then kept[#kept + 1] = s end end
        kept[#kept + 1] = split
        run.splits = kept
    elseif kind == "finish" then
        run.phase, run.finishMs, run.finishedAt = "finished", e.timeMs, now
    elseif kind == "result" then
        if run.attempt == e.attempt then run.finishMs = e.timeMs end
    elseif kind == "dnf" then
        run.phase, run.finishedAt = "finished", now
        run.dnf = { reason = e.reason, text = e.text, checkpoint = e.checkpoint }
    elseif kind == "respawn" then
        setFlash(e.reason == "fell" and "FELL · BACK TO THE LAST CHECKPOINT" or e.reason == "died" and "DOWN · BACK TO THE LAST CHECKPOINT"
            or "BACK TO THE LAST CHECKPOINT", "info")
    else
        return -- "board" and the rest belong to the page's dialogs
    end
    render()
    tick()
end

N.onStart(function()
    doc = N.create({ document = "ui/native/parkour.rml", zIndex = 30, models = { run = model() } })
    if not doc then return end
    render()
    CreateThread(function()
        while true do
            local ok, wait = pcall(tick)
            if not ok then N.log("parkour tick failed: " .. tostring(wait)); wait = 500 end
            Wait(wait or 200)
        end
    end)
end)
N.onShell(function() if run then N.patch(doc, "run", { quiet = quiet() }) end end)
N.on(E.page.parkour, onEvent)
