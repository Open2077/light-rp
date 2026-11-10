-- The action bar on NativeUI (was ui/src/features/actions/Actions.tsx, actions.css and
-- model.ts): the progress / hold / timing actions of client/core/actions.lua (eating,
-- refuelling, the jerrycan, a job's skill check...).
--
-- Input. The WebUI page stays the input sink: actions.lua claims it with
-- LightRpUi.claimActionFocus (the keyboard, its consumed keys, movement kept when the action
-- allows it). The page's headless relay (ui/src/features/actions/Actions.tsx) acknowledges the
-- start (actionStarted, as before) and forwards the raw key events of the running action on
-- "lightrp:ui:activity:input":
--   { id, kind = "ready" }               the page is listening: the clock starts
--   { id, kind = "down" | "up", key }    one of the action's keys ("E", "R", "SPACE"), no repeats
--   { id, kind = "escape" }              Escape (not repeated)
--   { id, kind = "blur" }                the page lost the focus
-- The decisions are made here, on the clock that draws the bar (the page's ActionClock,
-- model.ts, ported line for line): what the player sees is what is judged.
--
-- Outcome. The result the page emitted (actionResult) goes to LightRpActions.report
-- (client/core/actions.lua), which applies every check it applied to the page's report, then
-- finishes (callback / export / lightrp:action:finished) and sends actionFinish. This module
-- receives actionFinish too: an outcome Lua decided (owner stopped, ui timeout, the F1 menu)
-- is shown without being reported back, as the page did.
local N = LightRpNative
local E = LightRpEvents

local M = {}
LightRpNativeActions = M

local INPUT = "lightrp:ui:activity:input"
local READY_MS, FEEDBACK_MS, RESULT_MS = 400, 450, 1400
local MAX_STEPS = 12 -- client/core/actions.lua accepts 1..12 timing steps

-- ---- the clock (model.ts) ----------------------------------------------------------------
local Clock = {}
M.Clock = Clock

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function round(x) return math.floor(x + 0.5) end -- Math.round

--- A clock for definition `d`, created at `now`. `live` false: drawn ("Get ready") but frozen
--- until Clock.start (the page's relay said it listens).
function Clock.new(d, now, live)
    local first = d.kind == "timing" and d.steps[1] and d.steps[1].durationMs or d.durationMs
    local c = { d = d, scores = {}, heldAt = nil, feedbackUntil = 0, live = false,
        view = { phase = "ready", progress = 0, remainingMs = first, step = 0, held = false, hits = 0, mistakes = 0, feedback = "Get ready" } }
    c.started, c.readyAt, c.roundAt = now, now + READY_MS, now + READY_MS
    if live ~= false then c.live = true end
    return c
end
function Clock.start(c, now)
    if c.live then return end
    c.live, c.started, c.readyAt, c.roundAt = true, now, now + READY_MS, now + READY_MS
end
function Clock.finish(c, status, reason, now)
    local v = c.view
    if v.result then return v.result end
    v.phase, v.held = "done", false
    local score = 0
    if #c.scores > 0 then
        local sum = 0
        for i = 1, #c.scores do sum = sum + c.scores[i] end
        score = round(sum / #c.d.steps)
    end
    v.result = { id = c.d.id, status = status, reason = reason, elapsedMs = math.max(0, round(now - c.started)),
        hits = v.hits, mistakes = v.mistakes, score = score }
    if status == "success" and c.d.kind ~= "timing" then v.progress = 1 end
    return v.result
end
local function judge(c, hit, quality, message, now)
    local v = c.view
    if hit then v.hits = v.hits + 1; c.scores[#c.scores + 1] = quality else v.mistakes = v.mistakes + 1 end
    v.feedback = message
    if v.mistakes > c.d.maxMistakes then Clock.finish(c, "failed", message == "Too early" and "too_early" or "missed", now)
    elseif v.step + 1 >= #c.d.steps then Clock.finish(c, "success", "completed", now)
    else v.phase = "feedback"; c.feedbackUntil = now + FEEDBACK_MS end
end
function Clock.tick(c, now)
    local d, v = c.d, c.view
    if v.result or not c.live then return v end
    if now - c.started >= d.timeoutMs then Clock.finish(c, "failed", "timeout", now); return v end
    if now < c.readyAt then return v end
    if v.phase == "feedback" then
        if now < c.feedbackUntil then return v end
        v.step = v.step + 1; v.progress = 0; c.roundAt = now
    end
    v.phase = "running"
    if d.kind == "timing" then
        local s = d.steps[v.step + 1]
        v.progress = clamp((now - c.roundAt) / s.durationMs, 0, 1)
        v.remainingMs = math.max(0, s.durationMs - (now - c.roundAt))
        if v.progress >= 1 then judge(c, false, 0, "Too late", now) end
    else
        local elapsed
        if d.kind == "hold" then elapsed = c.heldAt == nil and 0 or now - c.heldAt else elapsed = now - c.readyAt end
        v.progress = clamp(elapsed / d.durationMs, 0, 1)
        v.remainingMs = math.max(0, d.durationMs - elapsed)
        if v.progress >= 1 then Clock.finish(c, "success", "completed", now) end
    end
    return v
end
function Clock.press(c, now)
    Clock.tick(c, now)
    local d, v = c.d, c.view
    if v.phase ~= "running" then return end
    if d.kind == "hold" then
        if c.heldAt == nil then c.heldAt = now end
        v.held = true
        return
    end
    if d.kind ~= "timing" then return end
    local s, position = d.steps[v.step + 1], v.progress
    local hit = position >= s.zoneStart and position <= s.zoneStart + s.zoneWidth
    local quality = hit and math.max(1, 100 - math.abs(position - s.zoneStart - s.zoneWidth / 2) / (s.zoneWidth / 2) * 50) or 0
    local message = hit and (quality >= 90 and "Perfect timing" or "Good timing") or (position < s.zoneStart and "Too early" or "Too late")
    judge(c, hit, quality, message, now)
end
function Clock.release(c, now)
    Clock.tick(c, now)
    if c.d.kind ~= "hold" or c.view.result or c.heldAt == nil then return end
    c.heldAt = nil; c.view.held = false
    if c.d.release == "cancel" then Clock.finish(c, "cancelled", "released", now)
    else
        c.view.progress = 0; c.view.remainingMs = c.d.durationMs
        c.view.feedback = "Released — hold to restart"
    end
end

-- ---- the view (Actions.tsx) ----------------------------------------------------------------
local REASONS = { completed = "You're all set.", cancelled = "You stopped the action.", released = "The key was released.",
    too_early = "Pressed before the target zone.", missed = "The target zone was missed.", timeout = "Time ran out.",
    focus_lost = "Focus was lost. Try again when ready.", interrupted = "Another screen needs your attention.",
    dead = "Your character cannot continue.", owner_stopped = "The activity is no longer available.", ui_timeout = "The interface did not respond." }
local function resultTitle(r)
    return r.status == "success" and "Action complete" or r.status == "cancelled" and "Action cancelled" or "Action failed"
end
local function prettyKey(key) return key == "SPACE" and "Space" or tostring(key or "E") end
local function icon(name) return N.icon(name) end

local function emptySteps()
    local rows = {}
    for i = 1, MAX_STEPS do rows[i] = { on = false, done = false, current = false } end
    return rows
end

--- Every value the document binds, for definition `d` and clock view `v` (pure).
function M.view(d, v)
    local result = v.result
    local timing = d.kind == "timing"
    local ring = d.style == "ring" and not timing
    local minimal = d.kind == "progress" and not ring
    local step = d.steps[v.step + 1]
    local reason = result and (REASONS[result.reason] or "The action was stopped.") or ""
    local instruction
    if v.phase == "ready" then instruction = "Get ready"
    elseif timing then instruction = v.phase == "feedback" and v.feedback or "Press in the yellow zone"
    elseif d.kind == "hold" then
        instruction = v.held and "Keep holding" or (v.feedback:sub(1, 8) == "Released" and v.feedback or "Hold to continue")
    else instruction = "In progress" end
    local footer = instruction
    if result then
        if timing and result.status == "success" then
            footer = ("%d / %d hits · %d%% precision"):format(result.hits, #d.steps, result.score)
        else
            footer = result.status == "success" and "Completed" or "No action completed"
        end
    end
    local steps = emptySteps()
    for i = 1, math.min(#d.steps, MAX_STEPS) do
        local row = steps[i]
        row.on = true
        row.done = i - 1 < v.hits + v.mistakes
        row.current = not row.done and i - 1 == v.step
    end
    local zoneLeft, zoneWidth = "0%", "0%"
    if timing and step then zoneLeft, zoneWidth = ("%.2f%%"):format(step.zoneStart * 100), ("%.2f%%"):format(step.zoneWidth * 100) end
    return {
        on = true,
        minimal = minimal, ring = ring, timing = timing, wide = timing, narrow = ring,
        status = result and result.status or "",
        held = v.held == true, feedback = v.phase == "feedback",
        hasResult = result ~= nil,
        label = d.label, description = d.description,
        resultTitle = result and resultTitle(result) or "",
        title = result and resultTitle(result) or d.label,
        detail = result and reason or d.description,
        secs = ("%d"):format(math.ceil(v.remainingMs / 1000)),
        pct = ("%d"):format(math.floor(v.progress * 100)),
        eyebrow = timing and "Precision action" or d.kind == "hold" and "Hold action" or "Activity",
        stepNo = ("%d"):format(math.min(v.step + 1, #d.steps)), stepCount = ("%d"):format(#d.steps),
        trim = v.progress,
        icon = icon(result and (result.status == "success" and "check" or "x") or d.icon),
        showPct = not result and not timing and not ring,
        fill = ("%.2f%%"):format(v.progress * 100),
        zoneLeft = zoneLeft, zoneWidth = zoneWidth,
        cursor = ("%.3f%%"):format(v.progress * 100),
        showKey = not result and d.kind ~= "progress",
        keyText = prettyKey(timing and (step and step.key or "E") or d.key),
        instruction = footer,
        showSteps = not result and timing, steps = steps,
        showTime = not result and not timing,
        cancellable = d.cancellable == true,
        cancelText = d.cancellable and "Cancel" or "Stay with the action",
        showMisses = timing and (d.maxMistakes or 0) > 0,
        misses = ("%d / %d misses allowed"):format(v.mistakes, d.maxMistakes or 0),
        showStop = not result and d.cancellable == true,
    }
end
M.REASONS, M.resultTitle = REASONS, resultTitle

local function model()
    local values = M.view({ id = "", kind = "progress", label = "", description = "", icon = "wrench", style = "bar", key = "E",
        cancellable = true, release = "reset", durationMs = 1, timeoutMs = 1, steps = {}, maxMistakes = 0 },
        { phase = "ready", progress = 0, remainingMs = 0, step = 0, held = false, hits = 0, mistakes = 0, feedback = "" })
    values.on, values.flip = false, 1
    return values
end

-- ---- the run -----------------------------------------------------------------------------
local doc
local run           -- { d, clock, pressed, sent, resultAt }
local flip = 1
local looping = false

local function valid(d)
    if type(d) ~= "table" or type(d.id) ~= "string" or d.id == "" then return false end
    if d.kind ~= "progress" and d.kind ~= "hold" and d.kind ~= "timing" then return false end
    if type(d.steps) ~= "table" then return false end
    if d.kind == "timing" and #d.steps < 1 then return false end
    if type(d.durationMs) ~= "number" or type(d.timeoutMs) ~= "number" then return false end
    return true
end

local function render()
    if not doc then return end
    if not run then N.patch(doc, "act", { on = false }); return end
    local values = M.view(run.d, run.clock.view)
    values.flip = flip
    N.patch(doc, "act", values)
end

--- The page's `blocked` / `dead`: a dialog or the F1 menu, a character that is not playing,
--- no health left.
local function interruption()
    local ui = LightRpUi
    if type(ui) == "table" then
        if ui.menuOpen == true then return "interrupted" end
        for _, open in pairs(ui.dialogs or {}) do if open then return "interrupted" end end
    end
    local c = N.state.character
    if type(c) == "table" and (c.welcomePending == true or (c.status ~= nil and c.status ~= "active")) then return "interrupted" end
    local hud = N.hud
    if type(hud) == "table" and hud.ready == true and type(hud.health) == "table" and (tonumber(hud.health.value) or 1) <= 0 then return "dead" end
    return nil
end
M.interruption = interruption

--- The decided result, once: to client/core/actions.lua (it validates as it validated the page).
local function report(r)
    if r.sent then return end
    r.sent = true
    local result = r.clock.view.result
    local copy = {}
    for k, v in pairs(result) do copy[k] = v end
    local actions = LightRpActions
    if type(actions) == "table" and type(actions.report) == "function" then
        local ok, why = pcall(actions.report, copy)
        if not ok then N.log("action report failed: " .. tostring(why)) end
    end
end

local function loop()
    looping = true
    while run do
        local r = run
        local now = N.now()
        local v = r.clock.view
        if not v.result then
            local why = interruption()
            if why then Clock.finish(r.clock, "cancelled", why, now) else Clock.tick(r.clock, now) end
            if v.result then
                r.resultAt = now
                render()
                report(r) -- may finish and chain the job's next action (a new run)
            end
        end
        if run == r then
            if v.result and now - (r.resultAt or now) >= RESULT_MS then
                run = nil
            end
            render()
        end
        Wait(0)
    end
    looping = false
end

local function start(d)
    if not valid(d) then return end
    flip = flip == 1 and 2 or 1
    -- the clock waits for the page's "ready" (the input sink listens); the lab has no page
    local live = not (LightRpUi and LightRpUi.page)
    run = { d = d, clock = Clock.new(d, N.now(), live), pressed = nil, sent = false }
    render()
    if not looping then CreateThread(loop) end
end

local function onFinish(r)
    if not run or type(r) ~= "table" or r.id ~= run.d.id then return end
    local cur = run
    if cur.clock.view.result then return end
    -- an outcome Lua decided: shown, never echoed back
    cur.sent = true
    local status = (r.status == "success" or r.status == "failed" or r.status == "cancelled") and r.status or "cancelled"
    Clock.finish(cur.clock, status, type(r.reason) == "string" and r.reason or "interrupted", N.now())
    cur.resultAt = N.now()
    render()
end

--- One relayed input of the page ({ id, kind, key }).
function M.input(p)
    if type(p) ~= "table" or not run or p.id ~= run.d.id then return end
    local r, c, d = run, run.clock, run.d
    local now = N.now()
    if p.kind == "ready" then Clock.start(c, now); return end
    if c.view.result then
        if p.kind == "up" and p.key == r.pressed then r.pressed = nil end
        return
    end
    if p.kind == "escape" then
        if d.cancellable then Clock.finish(c, "cancelled", "cancelled", now) end
    elseif p.kind == "blur" then
        r.pressed = nil
        Clock.finish(c, "cancelled", "focus_lost", now)
    elseif p.kind == "down" then
        if d.kind == "progress" then return end
        local key = d.kind == "timing" and (d.steps[c.view.step + 1] or {}).key or d.key
        if not key or p.key ~= key or r.pressed ~= nil then return end
        r.pressed = p.key
        Clock.press(c, now)
    elseif p.kind == "up" then
        if r.pressed == nil or p.key ~= r.pressed then return end
        r.pressed = nil
        Clock.release(c, now)
    end
    if c.view.result and not r.resultAt then r.resultAt = now end
    render()
    if c.view.result then report(r) end
end

--- The running action, for the lab and the tests.
function M.current() return run end

N.on(E.page.actionStart, start)
N.on(E.page.actionFinish, onFinish)

N.onStart(function()
    doc = N.create({ document = "ui/native/actions.rml", zIndex = 48, models = { act = model() } })
    render()
end)

-- the page's relay: bound once the page exists (client/core/ui.lua creates it after the scripts load)
CreateThread(function()
    while not (LightRpUi and LightRpUi.page) do Wait(500) end
    local ok, why = pcall(LightRpUi.page.on, LightRpUi.page, INPUT, M.input)
    if not ok then N.log("action input relay not bound: " .. tostring(why)) end
end)
