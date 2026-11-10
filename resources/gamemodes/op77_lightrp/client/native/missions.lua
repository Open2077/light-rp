-- The mission heads-up panels on NativeUI (ui/native/missions.rml), from three state keys:
--
--   missionQueue  the running mission's chip with its clock (MissionQueueHud.tsx) and, for an
--                 authored mission (server/modules/mission_engine.lua view()), the objective
--                 tracker, the out-of-zone warning, the respawn chips and the kit choice
--                 (MissionObjectiveHud.tsx)
--   fixerGig      a fixer gig taken, before it runs (FixerGigHud.tsx): who is at the meet
--                 point, the meeting clock, then the launch countdown
--   worldBoss     a world boss or a staff event on its engine (WorldBossHud.tsx): the boss's
--                 bar, the clock, your share against the minimum that pays, the result
--
-- Countdowns are relative to the push of their state key: they tick here, on the second.
-- While a kit can be chosen (the briefing, or down with canChoose) the document holds the
-- keyboard, not the cursor: 1-N pick a kit, Enter says ready during the briefing, as the
-- page did (the page also answered clicks on the kits and on READY; this one is keys only).
local N = LightRpNative
local E = LightRpEvents
local M = {}
LightRpNativeMissions = M

local KIT_ICON = { assault = "crosshair", breacher = "flame", marksman = "eye", gunner = "zap", tech = "radio" }

local icon = N.icon

-- A data-for array never shrinks: RmlUi reads the rows it removes once more and warns for
-- each binding. Rows past the real ones are blanks with gone = true (display: none).
local held = {}
local function hold(name, rows, blank)
    local n = math.max(held[name] or 0, #rows)
    held[name] = n
    for i = 1, #rows do rows[i].gone = false end
    for i = #rows + 1, n do
        local row = {}
        for key, value in pairs(blank) do row[key] = value end
        row.gone = true
        rows[i] = row
    end
    return rows
end

local function digits(v)
    v = tonumber(v) or 0
    if v == math.floor(v) and math.abs(v) < 9e15 then return ("%d"):format(v) end
    return tostring(v)
end
local function plural(n) return tonumber(n) == 1 and "" or "s" end
local function seconds(ms) return math.max(0, math.ceil(ms / 1000)) end
--- mm:ss of whole seconds.
local function clock(s) return ("%02d:%02d"):format(s // 60, s % 60) end
--- 12,500 (toLocaleString("en-US") of a whole number).
local function grouped(n)
    n = tonumber(n) or 0
    local text = ("%d"):format(math.floor(math.abs(n) + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if text:sub(1, 1) == "," then text = text:sub(2) end
    return (n < 0 and "-" or "") .. text
end
local function money(n) return "€$ " .. grouped(n) end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, tonumber(v) or 0)) end
local function percent(v) return math.floor(v * 100 + 0.5) / 100 end

-- A countdown: the whole seconds left of `ms`, `elapsed` after its push; `waits` collects
-- the ms until any of them shows another second.
local function countdown(ms, elapsed, waits)
    local remaining = ms - elapsed
    if remaining > 0 then waits.next = math.min(waits.next or 1000, (remaining - 1) % 1000 + 1) end
    return seconds(remaining)
end

--- The running mission's chip.
function M.chip(q, elapsed, waits)
    if type(q) ~= "table" or q.running ~= true then return { runOn = false } end
    return {
        runOn = true, runTitle = tostring(q.title or ""), runDifficulty = tostring(q.difficulty or ""),
        runClock = clock(countdown(tonumber(q.endsInMs) or 0, elapsed, waits)),
    }
end

--- A fixer gig's chip.
function M.gig(g, elapsed, waits)
    if type(g) ~= "table" then return { gigOn = false } end
    local crew, here, min, max = tonumber(g.crew) or 0, tonumber(g.here) or 0, tonumber(g.min) or 0, tonumber(g.max) or 0
    local launch = g.state == "countdown" and tonumber(g.launchInMs) or nil
    local missing = crew - here
    local count
    if launch then
        count = ("STARTING IN %02d"):format(countdown(launch, elapsed, waits))
    elseif missing > 0 then
        local meet = tonumber(g.meetInMs)
        count = ("AT THE MEET %s/%s · %s"):format(digits(here), digits(crew), meet and clock(countdown(meet, elapsed, waits)) or "--:--")
    else
        count = ("CREW %s/%s"):format(digits(crew), digits(max)) .. (crew < min and (" · NEED " .. digits(min - crew)) or "")
    end
    local cells = {}
    for i = 1, math.floor(max) do cells[i] = { on = i <= here, half = i > here and i <= crew } end
    return { gigOn = true, gigCountdown = launch ~= nil, gigTitle = tostring(g.title or ""), gigFixer = tostring(g.fixer or ""), gigCount = count, gigCells = hold("gigCells", cells, { on = false, half = false }) }
end

--- The world boss.
function M.boss(b, elapsed, waits)
    if type(b) ~= "table" then return { bossOn = false } end
    local health = clamp(b.bossHealth, 0, 1)
    local share = clamp(b.share, 0, 100)
    local minShare = tonumber(b.minShare) or 0
    local fight = b.phase == "fight"
    local tag = type(b.tag) == "string" and b.tag ~= "" and b.tag or nil
    local r = type(b.result) == "table" and b.result or nil
    local m = {
        bossOn = true, bossAway = not b.inZone,
        bossTag = tag or "WORLD BOSS", bossName = tostring(b.boss or ""), bossLocation = tostring(b.location or ""),
        bossHasClock = false, bossClock = "",
        bossHealth = percent(health * 100), bossHealthText = digits(math.ceil(health * 100)) .. " %",
        bossOut = not b.inZone and fight,
        bossEligible = b.eligible and true or false,
        bossShare = percent(share), bossMin = percent(clamp(minShare, 0, 100)), bossShareText = ("%.1f %%"):format(share),
        bossStats = ("%s dmg · %s kill%s"):format(grouped(b.damage), digits(b.kills), plural(b.kills)),
        bossHasResult = r ~= nil, bossPaid = false, bossResultA = "", bossResultB = "", bossResultC = "", bossHint = "",
    }
    if fight and tonumber(b.endsInMs) then
        m.bossHasClock, m.bossClock = true, clock(countdown(tonumber(b.endsInMs), elapsed, waits))
    end
    if fight then
        m.bossLine = ("Take it down · %s hostile%s · %s fighter%s in the zone"):format(digits(b.enemiesLeft), plural(b.enemiesLeft), digits(b.fighters), plural(b.fighters))
    elseif r then
        m.bossLine = r.success and ((tag or "BOSS"):gsub("^WORLD ", "") .. " DOWN") or "IT GOT AWAY"
    else
        m.bossLine = "OVER"
    end
    if r then
        local fought = ("%.1f"):format(tonumber(r.share) or 0)
        if (tonumber(r.pay) or 0) > 0 then
            m.bossPaid, m.bossResultA, m.bossResultB, m.bossResultC = true, "PAID", money(r.pay), "· " .. fought .. " % of the fight"
        elseif b.noPay then
            m.bossResultA = "STAFF EVENT · " .. fought .. " % of the fight, no pay"
        elseif r.success then
            m.bossResultA = "NO REWARD · " .. fought .. " % (under " .. digits(minShare) .. " %)"
        else
            m.bossResultA = "NOBODY PAID"
        end
    elseif b.noPay then
        m.bossHint = "Staff event: no pay, just the glory. Damage and kills still rank you."
    elseif b.eligible then
        m.bossHint = "Above " .. digits(minShare) .. " %: you share " .. money(b.reward) .. "."
    else
        m.bossHint = "Under " .. digits(minShare) .. " %: no reward. Damage and kills count."
    end
    return m
end

--- An authored mission's objective: the tracker, the warning, the chips, the kit choice.
function M.objective(q, elapsed, waits)
    local o = type(q) == "table" and q.running == true and type(q.objective) == "table" and q.objective or nil
    if not o then return { objOn = false, oobOn = false, chipOn = false, kitsOn = false } end
    local hostiles = digits(o.enemiesLeft) .. " hostile" .. plural(o.enemiesLeft) .. " left"
    local checkpoints = type(o.checkpoints) == "table" and o.checkpoints or {}
    local headline, detail
    if o.phase == "staging" then
        headline = "DEPLOYING"
        detail = tonumber(o.startsInMs) and ("Contact in " .. digits(countdown(o.startsInMs, elapsed, waits)) .. " s") or nil
    elseif o.kind == "waves" then
        local wave, waves = tonumber(o.wave) or 0, tonumber(o.waves)
        if o.phase == "intermission" then
            headline = "NEXT WAVE " .. digits(math.min(wave + 1, waves or 1)) .. " / " .. digits(waves)
            detail = tonumber(o.nextWaveInMs) and ("Incoming in " .. digits(countdown(o.nextWaveInMs, elapsed, waits)) .. " s") or hostiles
        else
            headline, detail = "WAVE " .. digits(o.wave) .. " / " .. digits(waves), hostiles
        end
    else
        local left = 0
        for _, c in ipairs(checkpoints) do
            if c.required and not c.reached then left = left + 1 end
        end
        headline = "CLEAR THE ZONE"
        detail = hostiles .. (left > 0 and (" · " .. digits(left) .. " checkpoint" .. plural(left) .. " to reach") or "")
    end

    local cells = {}
    if o.kind == "waves" and (tonumber(o.waves) or 0) > 0 then
        local wave, live = tonumber(o.wave) or 0, o.phase == "wave"
        for i = 1, math.floor(o.waves) do
            local done = i <= wave - (live and 1 or 0)
            cells[i] = { done = done, live = not done and live and i == wave }
        end
    end
    local checks = {}
    for i, c in ipairs(checkpoints) do
        checks[i] = { label = tostring(c.label or ""), reached = c.reached and true or false, optional = not c.required, icon = icon(c.reached and "check" or "map-pin") }
    end

    local m = {
        objOn = true, objWaves = o.kind == "waves", objIcon = icon(o.kind == "waves" and "shield" or "crosshair"),
        objHeadline = headline, objHasDetail = detail ~= nil, objDetail = detail or "",
        objHasCells = #cells > 0, objCells = cells, objHasChecks = #checks > 0, objChecks = checks,
        objKills = digits(o.kills), objLives = digits(o.lives),
        oobOn = false, oobNum = "", chipOn = false, chipOut = false, chipHead = "", chipText = "",
        kitsOn = false, kitsDown = false, kitsBriefing = false, kitsTitle = "", kitsHead = "", kits = {}, kitsMax = "", kitsReady = "",
    }
    if tonumber(o.outOfBoundsMs) then
        m.oobOn, m.oobNum = true, ("%02d"):format(countdown(o.outOfBoundsMs, elapsed, waits))
    end

    local kits = type(o.loadouts) == "table" and o.loadouts or {}
    local staging = o.phase == "staging"
    local squad = digits(o.readyCount or 0) .. "/" .. digits(o.squadSize or 1)
    local respawn = tonumber(o.respawnInMs) and countdown(o.respawnInMs, elapsed, waits) or nil
    -- the page drew these three at the same place; the last one wins here
    if staging and o.ready and #kits > 0 then
        m.chipOn, m.chipHead, m.chipText = true, "KIT ISSUED", "Waiting for the squad · " .. squad
    end
    if respawn then
        m.chipOn, m.chipOut, m.chipHead, m.chipText = true, false, "DOWN", "Back in " .. digits(respawn) .. " s"
    end
    if o.spectating then
        m.chipOn, m.chipOut, m.chipHead, m.chipText = true, true, "OUT", "No team respawn left. Your squad fights on."
    end

    local briefing = staging and #kits > 0 and not o.ready
    local down = respawn ~= nil and o.canChoose and #kits > 0
    if briefing or down then
        local rows = {}
        for i, k in ipairs(kits) do
            rows[i] = { key = digits(i), icon = icon(KIT_ICON[k.id] or "crosshair"), label = tostring(k.label or ""), blurb = tostring(k.blurb or ""), picked = o.loadout ~= nil and o.loadout == k.id }
        end
        m.kitsOn, m.kitsBriefing, m.kitsDown = true, briefing and true or false, not briefing
        m.kitsTitle = tostring(q.title or "")
        m.kitsHead = briefing and "BRIEFING" or "NEXT LIFE · PICK A KIT"
        m.kits, m.kitsMax, m.kitsReady = rows, digits(#kits), squad
    end
    m.objCells = hold("objCells", m.objCells, { done = false, live = false })
    m.objChecks = hold("objChecks", m.objChecks, { label = "", reached = false, optional = false, icon = "M0 0" })
    m.kits = hold("kits", m.kits, { key = "", icon = "M0 0", label = "", blurb = "", picked = false })
    return m
end

local function model()
    return {
        ready = false, hidden = true, quiet = false,
        icAlert = icon("triangle-alert"),
        runOn = false, runTitle = "", runDifficulty = "", runClock = "00:00",
        gigOn = false, gigCountdown = false, gigTitle = "", gigFixer = "", gigCount = "", gigCells = {},
        bossOn = false, bossAway = false, bossTag = "", bossName = "", bossLocation = "", bossHasClock = false, bossClock = "",
        bossHealth = 0, bossHealthText = "", bossLine = "", bossOut = false, bossEligible = false, bossShare = 0, bossMin = 0,
        bossShareText = "", bossStats = "", bossHasResult = false, bossPaid = false, bossResultA = "", bossResultB = "", bossResultC = "", bossHint = "",
        objOn = false, objWaves = false, objIcon = icon("crosshair"), objHeadline = "", objHasDetail = false, objDetail = "",
        objHasCells = false, objCells = {}, objHasChecks = false, objChecks = {}, objKills = "0", objLives = "0",
        oobOn = false, oobNum = "", chipOn = false, chipOut = false, chipHead = "", chipText = "",
        kitsOn = false, kitsDown = false, kitsBriefing = false, kitsTitle = "", kitsHead = "", kits = {}, kitsMax = "", kitsReady = "",
    }
end

local doc
local queue, queueAt = nil, 0   -- missionQueue and when it came
local gig, gigAt = nil, 0
local boss, bossAt = nil, 0
local picker = nil               -- while a kit can be chosen: { kits = { id... }, loadout, briefing }
local focused, focusTried = false, -10000
local ticking, epoch = false, 0

local function act(payload)
    local ok, reason = TriggerServerEvent(E.net.action, payload)
    if not ok and LightRpUi then
        LightRpUi.send(E.page.result, { ok = false, text = "network refused: " .. tostring(reason), action = payload.type })
    end
end

-- The keyboard while a kit is being chosen (never the cursor: the HUD stays).
local function syncFocus(want)
    if not doc then return end
    if want and not focused then
        local now = N.now()
        if now - focusTried < 2000 then return end -- a page may hold the input: ask again later
        focusTried = now
        focused = doc:focus({ keyboard = true, cursor = false }) ~= false
    elseif not want and focused then
        focused = false
        doc:blur()
    end
end

local lastReady = 0
local function onKey(event)
    if not picker or type(event) ~= "table" then return end
    local key = tostring(event.key or ""):lower()
    local n = tonumber(key:match("^%d$") or key:match("^numpad(%d)$") or key:match("^num(%d)$"))
    if n and n >= 1 and n <= #picker.kits then
        if picker.kits[n] ~= picker.loadout then act({ type = "mission.loadout", id = picker.kits[n] }) end
    elseif picker.briefing and (key == "enter" or key == "return") then
        local now = N.now()
        if now - lastReady < 400 then return end -- a held key repeats
        lastReady = now
        act({ type = "mission.ready" })
    end
end

-- Draws every panel; returns the ms until a countdown shows another second (nil: none runs).
local function render()
    if not doc then return nil end
    local now, waits = N.now(), {}
    N.patch(doc, "hud", M.chip(queue, now - queueAt, waits))
    N.patch(doc, "hud", M.gig(gig, now - gigAt, waits))
    N.patch(doc, "hud", M.boss(boss, now - bossAt, waits))
    local objective = M.objective(queue, now - queueAt, waits)
    N.patch(doc, "hud", objective)

    picker = nil
    if objective.kitsOn then
        local kits = {}
        for i, k in ipairs(queue.objective.loadouts) do kits[i] = k.id end
        picker = { kits = kits, loadout = queue.objective.loadout, briefing = objective.kitsBriefing }
    end
    local shown = N.shell.ready and not N.shell.hidden and not N.shell.quiet
    syncFocus(shown and picker ~= nil)
    if not shown or not waits.next then return nil end
    return math.max(40, waits.next + 15)
end
-- One thread at most counts; a push restarts it so the next tick falls on its own second.
local function refresh()
    local wait = render()
    epoch = epoch + 1
    ticking = wait ~= nil
    if not wait then return end
    local mine = epoch
    CreateThread(function()
        while true do
            Wait(wait)
            if mine ~= epoch then return end
            wait = render()
            if not wait then ticking = false; return end
        end
    end)
end

N.onStart(function()
    local values = model()
    values.ready, values.hidden, values.quiet = N.shell.ready, N.shell.hidden, N.shell.quiet
    doc = N.create({ document = "ui/native/missions.rml", zIndex = 30, models = { hud = values } })
    if not doc then return end
    doc:on("keydown", onKey)
    doc:onEvent("focus", function(kind) if kind == "blur" then focused = false end end)
    doc:onEvent("error", function(kind, detail)
        if kind == "focus" then focused = false; return end
        N.log("ui/native/missions.rml " .. tostring(kind) .. ": " .. tostring(detail and detail.message))
    end)
    refresh()
end)
N.onShell(function(shell)
    N.patch(doc, "hud", { ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet })
    refresh()
end)
N.onState("missionQueue", function(value)
    queue, queueAt = type(value) == "table" and value or nil, N.now()
    refresh()
end)
N.onState("fixerGig", function(value)
    gig, gigAt = type(value) == "table" and value or nil, N.now()
    refresh()
end)
N.onState("worldBoss", function(value)
    boss, bossAt = type(value) == "table" and value or nil, N.now()
    refresh()
end)
