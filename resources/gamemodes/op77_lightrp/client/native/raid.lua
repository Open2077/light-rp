-- The raid on NativeUI (ui/native/raid.rml), the page's RaidHud.tsx: the ready check, the
-- launch countdown, the intro's letterbox and title card, the strip under the boss's bar,
-- the target lock, announcements, the respawn timer and the result.
--
-- client/core/raid.lua relays every raid state to the page (E.page.raid): each payload is
-- the whole state, timers count down here from it. Rules kept from the page:
--   * "ended" clears everything; with a result, MISSION COMPLETE / FAILED stays 6 s
--   * a payload with `intro` starts the cinematic clock; the cinematic lasts while the
--     phase is "intro", or until the clock runs out (unless the fight already started).
--     Its beats are fractions of its duration, the same numbers as the camera cuts (CUT in
--     client/core/raid.lua). Meanwhile the rest of the HUD steps aside (N.cover)
--   * a payload with `announce` shows a banner for 4.2 s
--   * while this operator picks a kit in the ready check the document holds the keyboard
--     (not the cursor): 1-N pick a kit, Enter or the ready key say ready, as the page did.
--     The page also answered clicks on the kits and on READY; this one is keys only.
local N = LightRpNative
local E = LightRpEvents
local R = {}
LightRpNativeRaid = R

local BEATS = { closeLow = 0.18, closeHigh = 0.27, wake = 0.36, orbit = 0.40, roar = 0.86, out = 0.93 }
local CUTS = { BEATS.closeLow, BEATS.closeHigh, BEATS.orbit, 0.72 }
local TELEMETRY = { "MILITECH TAC-NET // UPLINK ESTABLISHED", "TARGET    MT-CHIMERA 0005-C", "STATUS    DORMANT", "SECTOR    DOGTOWN // THE ARENA" }
local SCAN = { { "ARMOR", "HEAVY PLATING" }, { "WEAPONS", "MINIGUN · MISSILE POD" }, { "CORE", "SHIELDED" } }
local PHASES = { armored = "ARMORED", exposed = "EXPOSED", gas = "GAS", core = "CORE" }
local KIT_ICON = { assault = "crosshair", breacher = "flame", marksman = "eye", gunner = "zap", tech = "radio" }
local READY_SECONDS = 45   -- the ready check's bar is full at 45 s
local INTRO_MS = 11000
local BANNER_MS = 4200
local RESULT_MS = 6000
R.KIT_ICON = KIT_ICON

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
local function two(v) return ("%02d"):format(math.max(0, math.floor(tonumber(v) or 0))) end
local function clock(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    return two(seconds // 60) .. ":" .. two(seconds % 60)
end

-- The page revealed a line with a clip stepped over its width (steps(n, end)); in a
-- monospace face that is the first k/n of its characters.
local charsOf = {}
local function typed(text, ms, total, steps)
    if ms >= total then return text end
    if ms <= 0 then return "" end
    local list = charsOf[text]
    if not list then
        list = {}
        for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do list[#list + 1] = char end
        charsOf[text] = list
    end
    return table.concat(list, "", 1, math.floor(#list * math.floor(ms / total * steps) / steps))
end

--- The kit rows of a ready check (shared with the authored missions' kit choice).
function R.kitRows(kits, picked)
    local rows = {}
    for i, k in ipairs(type(kits) == "table" and kits or {}) do
        rows[i] = { key = digits(i), icon = icon(KIT_ICON[k.id] or "crosshair"), label = tostring(k.label or ""), blurb = tostring(k.blurb or ""), picked = picked ~= nil and picked == k.id }
    end
    return rows
end

--- The intro at fraction `t` of its `introMs`.
function R.intro(t, introMs)
    local B = BEATS
    local m = { introOn = true, introOut = t >= B.out, introJolt = t >= B.wake and t < B.wake + 0.05 }
    m.cutOn = false
    for _, cut in ipairs(CUTS) do
        if t >= cut and t < cut + 0.012 then m.cutOn = true end
    end
    m.flashOn = t >= B.wake and t < B.wake + 0.06
    m.flashSoftOn = t >= B.roar and t < B.roar + 0.05
    -- the uplink's lines, one more every 3.5 % of the intro, each typed in .25 s (6 steps)
    m.teleOn = t < B.closeLow
    for i = 1, 4 do
        m["tele" .. i] = m.teleOn and typed(TELEMETRY[i], (t - (i - 1) * 0.035) * introMs, 250, 6) or ""
    end
    m.warnOn = t < B.wake
    -- the scan reads the machine between the first close-up and the wake-up
    local confirmed = t >= B.wake
    local span = B.wake - B.closeLow
    local scan = math.min(100, math.floor((t - B.closeLow) / span * 100 + 0.5))
    m.scanOn = t >= B.closeLow and t < B.wake + 0.04
    m.scanConfirmed = confirmed
    m.scanHead = confirmed and "THREAT CONFIRMED" or "ANALYSING"
    m.scanPct = confirmed and "" or (digits(math.max(0, scan)) .. "%")
    for i = 1, 3 do
        local threshold = 20 + (i - 1) * 28
        local k, v = "", ""
        if m.scanOn and scan >= threshold then
            local since = (t - (B.closeLow + (threshold - 0.5) / 100 * span)) * introMs
            k, v = typed(SCAN[i][1], since, 300, 8), typed(SCAN[i][2], since, 300, 8)
        end
        m["s" .. i .. "k"], m["s" .. i .. "v"] = k, v
    end
    m.cardOn = t > B.orbit + 0.02 and t < B.out + 0.04
    return m
end

--- The document's values for a raid state, `elapsed` ms after it came, for player `me`.
--- Second result: the ms until one of its countdowns shows another second (nil: none runs).
function R.view(raid, me, elapsed)
    local m, wait = {}, nil
    local function left(ms)
        ms = tonumber(ms)
        if ms == nil then return nil end
        local remaining = ms - elapsed
        if remaining > 0 then wait = math.min(wait or 1000, (remaining - 1) % 1000 + 1) end
        return math.max(0, math.ceil(remaining / 1000))
    end
    local phase = raid.phase
    local boss = type(raid.boss) == "table" and raid.boss or nil
    local operators = type(raid.operators) == "table" and raid.operators or {}
    local difficulty = tostring(raid.difficulty or "")

    -- the title card
    m.title, m.difficulty = tostring(raid.title or ""), difficulty
    m.chipHard, m.chipCritical = raid.difficultyId == "hard", raid.difficultyId == "critical"
    m.threat4, m.threat5 = m.chipHard or m.chipCritical, m.chipCritical
    local count = type(raid.intro) == "table" and tonumber(raid.intro.operators) or (#operators > 0 and #operators or 1)
    m.operators = digits(count) .. " OPERATOR" .. (count > 1 and "S" or "")

    if phase == "ready" then
        local kits = type(raid.loadouts) == "table" and raid.loadouts or {}
        local rows, ready, mine = {}, 0, nil
        for i, o in ipairs(operators) do
            if o.ready then ready = ready + 1 end
            local isMe = me ~= nil and o.id == me
            if isMe then mine = o end
            rows[i] = {
                name = tostring(o.name or "") .. (isMe and " · YOU" or ""),
                ready = o.ready == true, loading = not o.ready and o.loaded == false,
                state = o.ready and "READY" or (o.loaded == false and "LOADING" or "STANDING BY"),
                icon = icon(o.ready and "check" or "loader"),
            }
        end
        local seconds = left(raid.readyEndsInMs) or 0
        local mineReady = mine ~= nil and mine.ready == true
        -- ready only once this client finished loading the arena (the server refuses before)
        local loading = raid.loaded == false
        m.readyOn, m.choosing = true, not mineReady and #kits > 0
        m.timerPct = math.floor(math.min(100, seconds / READY_SECONDS * 100) * 100 + 0.5) / 100
        m.timerText = two(seconds) .. "s"
        m.ops, m.hasKits, m.kits = rows, #kits > 0, R.kitRows(kits, raid.loadout)
        m.mineReady, m.loading = mineReady, loading
        m.footLoading, m.footPick = not mineReady and loading, not mineReady and not loading
        m.readyCount = digits(ready) .. "/" .. digits(#operators)
        m.kitMax = digits(#kits > 0 and #kits or 5)
        m.goLabel, m.readyKey = loading and "LOADING" or "READY", tostring(raid.readyKey or "Y")
    elseif phase == "launch" then
        local seconds = left(raid.launchInMs)
        m.launchOn, m.launchNum = true, seconds and digits(seconds) or ""
    elseif phase == "placing" then
        m.placingOn = true
    end

    if (phase == "fight" or phase == "victory" or phase == "wipe") and boss then
        local lives = tonumber(raid.lives) or 0
        m.bossOn = true
        m.bossPhase = PHASES[boss.phase] or tostring(boss.phase or "")
        m.bossEnraged = boss.enraged and true or false
        m.bossShielded = boss.repairing and true or false
        m.bossShield = "SHIELDED" .. (tonumber(boss.repairInMs) and (" " .. digits(math.ceil(boss.repairInMs / 1000)) .. "s") or "")
        m.bossAdds = digits(raid.adds) .. " HOSTILES"
        m.bossLives = lives < 0 and "RESPAWNS ∞" or (lives == 0 and "NO RESPAWNS" or (digits(lives) .. " RESPAWN" .. (lives > 1 and "S" or "")))
        m.bossClock = clock(raid.fightSeconds)
        local enrageIn = left(raid.enrageInMs)
        m.overclockOn = enrageIn ~= nil and not m.bossEnraged
        m.overclock, m.overclockHot = "OVERCLOCK " .. clock(enrageIn or 0), enrageIn ~= nil and enrageIn <= 60
        local name = type(boss.targetName) == "string" and boss.targetName or ""
        m.lockedOn = boss.target ~= nil and boss.target ~= me and name ~= ""
        m.locked = "LOCKED ON " .. name
    end
    if phase == "fight" then
        m.targetOn = boss ~= nil and boss.target ~= nil and me ~= nil and boss.target == me
        if raid.respawnInMs ~= nil then m.respawnOn, m.respawnNum = true, digits(left(raid.respawnInMs) or 0) end
        m.outOn = raid.out and true or false
    elseif phase == "victory" then
        m.resultOn, m.resultVictory, m.resultText = true, true, "CHIMERA DOWN"
        m.resultHasSmall, m.resultSmall = true, clock(raid.fightSeconds) .. " · " .. difficulty
    elseif phase == "wipe" then
        m.resultOn, m.resultFailed, m.resultText = true, true, "CREW WIPED"
        m.resultHasSmall, m.resultSmall = true, "The Chimera holds the arena"
    end
    return m, wait
end

-- Every bound name with what it shows when nothing is going on.
local function model()
    return {
        ready = false, hidden = true, quiet = false,
        icSiren = icon("siren"), icFlame = icon("flame"), icShield = icon("shield"), icUsers = icon("users"),
        icHeart = icon("heart-pulse"), icTimer = icon("timer"), icAlert = icon("triangle-alert"),
        introOn = false, introOut = false, introJolt = false, cutOn = false, flashOn = false, flashSoftOn = false,
        teleOn = false, tele1 = "", tele2 = "", tele3 = "", tele4 = "", warnOn = false,
        scanOn = false, scanConfirmed = false, scanHead = "ANALYSING", scanPct = "",
        s1k = "", s1v = "", s2k = "", s2v = "", s3k = "", s3v = "",
        cardOn = false, chipHard = false, chipCritical = false, threat4 = false, threat5 = false, operators = "",
        title = "", difficulty = "",
        readyOn = false, choosing = false, timerPct = 0, timerText = "", ops = {}, hasKits = false, kits = {},
        mineReady = false, loading = false, footLoading = false, footPick = false, readyCount = "", kitMax = "5",
        goLabel = "READY", readyKey = "Y",
        launchOn = false, launchNum = "", launchA = false, launchB = false, placingOn = false,
        bossOn = false, bossPhase = "", bossEnraged = false, bossShielded = false, bossShield = "", bossAdds = "",
        bossLives = "", bossClock = "", overclockOn = false, overclock = "", overclockHot = false, lockedOn = false, locked = "",
        targetOn = false, respawnOn = false, respawnNum = "", outOn = false,
        bannerA = false, bannerB = false, bannerTitle = "", bannerBody = "", bannerDanger = false, bannerSuccess = false, bannerInfo = false,
        resultOn = false, resultVictory = false, resultFailed = false, resultText = "", resultHasSmall = false, resultSmall = "",
    }
end

local doc
local raid, received = nil, 0
local introAt, introMs = nil, INTRO_MS
local banner, bannerSeq, bannerFlip = nil, 0, false
local result, resultSeq = nil, 0
local launchShown, launchFlip = nil, false
local covering = false
local picker = nil              -- while this operator chooses: { kits = { id... }, loadout, loading, readyKey }
local focused, focusTried = false, -10000
local ticking, epoch = false, 0
local refresh

local function me()
    local character = N.state.character
    return type(character) == "table" and tonumber(character.playerId) or nil
end
-- During the cinematic the raid covers the HUD (N.cover hides every shell): this document
-- then only steps aside for what really owns the screen.
local function screenTaken()
    local ui = LightRpUi
    if ui and ui.menuOpen == true then return true end
    for _, open in pairs(ui and ui.dialogs or {}) do
        if open then return true end
    end
    if LightRpNativeLab and LightRpNativeLab.ignoreCapture then return false end -- the HUD lab (tools/native-lab)
    if type(Open77.input) == "table" and type(Open77.input.isCaptured) == "function" then
        local ok, _, cursor = pcall(Open77.input.isCaptured)
        if ok and cursor == true then return true end
    end
    return false
end

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

local lastKey = 0
local function onKey(event)
    if not picker or type(event) ~= "table" then return end
    local key = tostring(event.key or ""):lower()
    local n = tonumber(key:match("^%d$") or key:match("^numpad(%d)$") or key:match("^num(%d)$"))
    local now = N.now()
    if n and n >= 1 and n <= #picker.kits then
        if picker.kits[n] ~= picker.loadout then act({ type = "raid.loadout", id = picker.kits[n] }) end
    elseif not picker.loading and (key == "enter" or key == "return" or key == picker.readyKey) then
        if now - lastKey < 400 then return end -- a held key repeats
        lastKey = now
        act({ type = "raid.ready" })
    end
end

-- Draws the raid; returns the ms until something on screen changes by itself.
local function render()
    if not doc then return nil end
    local now = N.now()
    local m, wait, cinematic = model(), nil, false
    picker = nil
    if raid then
        local elapsed = now - received
        local t = introAt and (now - introAt) / introMs or 2
        cinematic = raid.phase == "intro" or (t < 1 and raid.phase ~= "fight")
        local values, countdown = R.view(raid, me(), elapsed)
        for key, value in pairs(values) do m[key] = value end
        wait = countdown
        if cinematic then
            for key, value in pairs(R.intro(t, introMs)) do m[key] = value end
            if t < 1.02 then wait = 40 end
        end
        -- the launch number replays its entrance on every second
        if m.launchOn then
            if m.launchNum ~= launchShown then launchShown, launchFlip = m.launchNum, not launchFlip end
            m.launchA, m.launchB = launchFlip, not launchFlip
        else
            launchShown = nil
        end
        if banner then
            m.bannerA, m.bannerB = banner.flip, not banner.flip
            m.bannerTitle, m.bannerBody = banner.title, banner.body
            m.bannerDanger, m.bannerSuccess, m.bannerInfo = banner.tone == "danger", banner.tone == "success", banner.tone == "info"
        end
        if m.choosing then
            local kits = {}
            for i, k in ipairs(raid.loadouts) do kits[i] = k.id end
            picker = { kits = kits, loadout = raid.loadout, loading = raid.loaded == false, readyKey = tostring(raid.readyKey or "Y"):lower() }
        end
    elseif result then
        m.resultOn, m.resultVictory, m.resultFailed = true, result == "victory", result ~= "victory"
        m.resultText = result == "victory" and "MISSION COMPLETE" or "MISSION FAILED"
    end

    local shell = N.shell
    m.ready = shell.ready
    if cinematic then m.hidden, m.quiet = screenTaken(), false
    else m.hidden, m.quiet = shell.hidden, shell.quiet end
    m.ops = hold("ops", m.ops, { name = "", ready = false, loading = false, state = "", icon = "M0 0" })
    m.kits = hold("kits", m.kits, { key = "", icon = "M0 0", label = "", blurb = "", picked = false })
    N.patch(doc, "raid", m)

    local shown = m.ready and not m.hidden and not m.quiet
    syncFocus(shown and picker ~= nil)
    if cinematic ~= covering then
        covering = cinematic
        N.cover("raid", cinematic)
        if N.refreshShell then N.refreshShell() end
    end
    if not shown and not cinematic then return nil end
    return wait and math.max(40, wait + (wait == 40 and 0 or 15)) or nil
end

refresh = function()
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
    doc = N.create({ document = "ui/native/raid.rml", zIndex = 31, models = { raid = model() } })
    if not doc then return end
    doc:on("keydown", onKey)
    doc:onEvent("focus", function(kind) if kind == "blur" then focused = false end end)
    doc:onEvent("error", function(kind, detail)
        if kind == "focus" then focused = false; return end
        N.log("ui/native/raid.rml " .. tostring(kind) .. ": " .. tostring(detail and detail.message))
    end)
    refresh()
end)
N.onShell(function() refresh() end)
N.onState("character", function() if ticking then render() else refresh() end end)

N.on(E.page.raid, function(payload)
    if type(payload) ~= "table" or not payload.phase then return end
    if payload.phase == "ended" then
        raid, introAt, banner = nil, nil, nil
        if payload.result then
            result, resultSeq = payload.result, resultSeq + 1
            local mine = resultSeq
            CreateThread(function()
                Wait(RESULT_MS)
                if mine == resultSeq then result = nil; refresh() end
            end)
        end
        refresh()
        return
    end
    result, resultSeq = nil, resultSeq + 1
    raid, received = payload, N.now()
    if type(payload.intro) == "table" then
        introAt, introMs = received, tonumber(payload.intro.durationMs) or INTRO_MS
    end
    if type(payload.announce) == "table" then
        bannerSeq, bannerFlip = bannerSeq + 1, not bannerFlip
        banner = { title = tostring(payload.announce.title or ""), body = tostring(payload.announce.body or ""), tone = payload.announce.tone, flip = bannerFlip }
        local mine = bannerSeq
        CreateThread(function()
            Wait(BANNER_MS)
            if mine == bannerSeq and banner then banner = nil; refresh() end
        end)
    end
    refresh()
end)
