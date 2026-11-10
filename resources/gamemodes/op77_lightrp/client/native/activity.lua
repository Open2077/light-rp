-- The shared in-match HUD of the activity providers on NativeUI (was
-- ui/src/features/activityhud/ActivityHud.tsx). client/core/activity_hud.lua validates and
-- sends { op = "show" | "push" | "clear" } on E.page.activityHud; this module draws it:
-- the header top centre, the match panel in the work order's slot, the feed left of the
-- minimap, the countdown, the banners and the result card in the centre.
--
-- Other HUD modules read LightRpNativeActivity.phase (nil | "lobby" | "countdown" |
-- "running" | "ended") or subscribe with LightRpNativeActivity.on(fn): the page's
-- html[data-activity-hud] (needs and the work order step aside outside the lobby).
local N = LightRpNative
local E = LightRpEvents

local A = { phase = nil, listeners = {} }
LightRpNativeActivity = A
function A.on(fn) A.listeners[#A.listeners + 1] = fn end

local FEED_MAX, FEED_MS = 5, 5200
local FEED_FADE_AT = 0.88       -- ah-life: opaque to 88 % of the life, then out
local BIG_COUNT_S = 5           -- the last seconds before GO get the big digits
local PHASE_LABEL = { lobby = "LOBBY", countdown = "STANDBY", running = "LIVE", ended = "FINISHED" }
local TONE = { accent = "#FFCC00", danger = "#FF2E3C", info = "#7FB4D6", success = "#8FE04A" }
local INK_300, INK_400 = "#565A66", "#3A3D46"
local PANEL_MAX_H = 410.4       -- max(38vh, 300px) at 1080

local doc
local hud, hudAt = nil, 0       -- the normalized view and when it arrived
local feed, banner, result = {}, nil, nil
local seq = 0
local flip = { count = false, banner = false, result = false }
local lastCount

-- ---- pure helpers (the page's model.ts) ------------------------------------------------
local function str(v) return type(v) == "string" and #v > 0 and v or nil end
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end
local function arr(v)
    local out = {}
    if type(v) == "table" then for i = 1, #v do out[#out + 1] = v[i] end end
    return out
end
local function filter(list, keep)
    local out = {}
    for i = 1, #list do if keep(list[i]) then out[#out + 1] = list[i] end end
    return out
end
-- A data-for array never shrinks: RmlUi reads the rows it is about to drop for a frame and
-- warns on every field. The lists grow to their high-water mark and the spare rows carry
-- every bound field with `off = true` (display: none).
local high = {}
local function pad(key, list, blank, least)
    local n = math.max(high[key] or 0, #list, least or 0)
    high[key] = n
    for i = 1, #list do list[i].off = false end
    for i = #list + 1, n do
        local row = { off = true }
        for k, v in pairs(blank) do row[k] = v end
        list[i] = row
    end
    return list
end
local BLANK = {
    team = { name = "", score = "", self = false, color = "#565A66" }, hint = { key = "", label = "" },
    stat = { label = "", value = "" }, bar = { label = "", hasLabel = false, pct = 0, color = "#FFCC00" },
    col = { t = "", w = 36 }, cell = { t = "", w = 36 },
    feed = { text = "", rail = "#3A3D46", hi = false, out = true }, line = { label = "", value = "" },
}
local function pad2(n) return ("%02d"):format(n) end

--- A count-down: m:ss (h:mm:ss past the hour).
local function formatRemaining(ms)
    local total = math.max(0, math.ceil(ms / 1000))
    local h, m, s = total // 3600, (total // 60) % 60, total % 60
    if h > 0 then return ("%d:%s:%s"):format(h, pad2(m), pad2(s)) end
    return ("%d:%s"):format(m, pad2(s))
end
--- A count-up: m:ss.cc, to the hundredth.
local function formatElapsed(ms)
    local v = math.max(0, math.floor(ms))
    local h, m, s, cs = v // 3600000, (v // 60000) % 60, (v // 1000) % 60, (v % 1000) // 10
    if h > 0 then return ("%d:%s:%s.%s"):format(h, pad2(m), pad2(s), pad2(cs)) end
    return ("%d:%s.%s"):format(m, pad2(s), pad2(cs))
end
local function clockValue(timer, phase, elapsed)
    if timer.countUp then return phase == "running" and timer.remainingMs + elapsed or timer.remainingMs end
    return math.max(0, timer.remainingMs - elapsed)
end
local function ordinalSuffix(n)
    local v = n % 100
    if v >= 11 and v <= 13 then return "TH" end
    return ({ [1] = "ST", [2] = "ND", [3] = "RD" })[n % 10] or "TH"
end
--- A team colour from the Lua side: a hex value or a signal tone; ink-300 otherwise.
local function teamColor(color)
    if type(color) == "string" then
        local r, g, b = color:match("^#(%x)(%x)(%x)$")
        if r then return ("#%s%s%s%s%s%s"):format(r, r, g, g, b, b) end
        if color:match("^#%x%x%x%x%x%x$") then return color end
        if TONE[color] then return TONE[color] end
    end
    return INK_300
end
--- At most `max` rows, the player's own always among them: the top, a gap, the rows around the player.
local function windowRows(rows, max)
    local ranked = {}
    for i = 1, #rows do ranked[i] = { row = rows[i], rank = i } end
    if #ranked <= max then return ranked end
    local own
    for i = 1, #ranked do if ranked[i].row.self then own = i; break end end
    local out = {}
    if not own or own <= max then
        for i = 1, max do out[i] = ranked[i] end
        return out
    end
    local head = math.max(1, max - 3)
    for i = 1, head do out[#out + 1] = ranked[i] end
    out[#out + 1] = false
    for i = math.max(head + 1, own - 1), own do out[#out + 1] = ranked[i] end
    return out
end

local function normalizeHud(raw)
    if type(raw) ~= "table" then return nil end
    local board = type(raw.scoreboard) == "table" and raw.scoreboard or nil
    local rows = filter(arr(board and board.rows), function(r) return type(r) == "table" and type(r.name) == "string" end)
    local timer = type(raw.timer) == "table" and num(raw.timer.remainingMs) and raw.timer or nil
    local phase = PHASE_LABEL[raw.phase] and raw.phase or "running"
    return {
        activity = str(raw.activity), title = str(raw.title) or "Activity", subtitle = str(raw.subtitle), phase = phase,
        timer = timer, countdown = num(raw.countdown), objective = str(raw.objective),
        stats = filter(arr(raw.stats), function(s) return type(s) == "table" and type(s.label) == "string" end),
        progress = filter(arr(raw.progress), function(p) return type(p) == "table" and num(p.value) ~= nil end),
        teams = filter(arr(raw.teams), function(t) return type(t) == "table" and type(t.name) == "string" end),
        hints = filter(arr(raw.hints), function(h) return type(h) == "table" and type(h.key) == "string" and type(h.label) == "string" end),
        scoreboard = #rows > 0 and { columns = arr(board.columns), rows = rows } or nil,
    }
end

-- A value column is as wide as its longest cell (the page's `minmax(36px, auto)` track):
-- Share Tech Mono advances 0.55 em; the head is 10 dp with 0.14 em of spacing.
local function columnWidths(columns, rows)
    local widths = {}
    for c = 1, #columns do
        local w = math.max(36, #tostring(columns[c]) * 6.9)
        for _, entry in ipairs(rows) do
            if entry then
                local cell = entry.row.values and entry.row.values[c]
                w = math.max(w, #tostring(cell == nil and "-" or cell) * 6.6)
            end
        end
        widths[c] = math.ceil(w)
    end
    return widths
end

-- ---- model -----------------------------------------------------------------------------
local function model()
    return {
        on = false, quiet = false, low1 = false, low2 = false, icCrosshair = N.icon("crosshair"),
        headOn = false, phase = "running", phaseLabel = "", title = "", subtitle = "", hasSub = false,
        middle = false, duel = false, hasTimer = false, timerUp = false, hasTimerLabel = false, timerLabel = "",
        clock = "", clockLow = false,
        t1name = "", t1score = "0", t1self = false, t1color = INK_300,
        t2name = "", t2score = "0", t2self = false, t2color = INK_300,
        chipsOn = false, teams = {}, hasObjective = false, objective = "", headHints = false, hints = {},
        countOn = false, countWait = false, countFar = false, countBig = false, countGo = false, countA = false, countText = "",
        panelOn = false, statCount = 0, stats = {}, barCount = 0, bars = {}, sepBars = false,
        boardOn = false, boardHead = false, cols = {}, rows = {}, sepBoard = false, panelHints = false, sepHints = false,
        feed = {},
        bannerOn = false, bannerA = false, bannerOut = false, bannerTone = TONE.accent, bannerAccent = true,
        bannerHasTitle = false, bannerTitle = "", bannerHasText = false, bannerText = "",
        resultOn = false, resultA = false, resultFirst = false, placeOn = false, placeWord = false, place = "", placeSuffix = "",
        resultHasTitle = false, resultTitle = "", resultHasSub = false, resultSub = "", lineCount = 0, lines = {}, resultLife = 100,
    }
end

local function away()
    local character = N.state.character
    return type(character) ~= "table" or character.status ~= "active" or (character.welcomePending and true or false)
end

local function setPhase(phase)
    if A.phase == phase then return end
    A.phase = phase
    N.activityPhase = phase
    for i = 1, #A.listeners do
        local ok, why = pcall(A.listeners[i], phase)
        if not ok then N.log("activity listener failed: " .. tostring(why)) end
    end
end

--- Everything but the ticking parts (clock, countdown, feed, banner, result life).
local function layout()
    local state = N.state
    local isAway = away()
    setPhase(hud and not isAway and hud.phase or nil)
    local values = { on = not isAway and (hud ~= nil or banner ~= nil or result ~= nil or #feed > 0) }
    local queue = type(state.queue) == "table" and state.queue or nil
    local chip = (type(state.missionQueue) == "table" and state.missionQueue.running and true or false)
        or (state.fixerGig and true or false)
    local drop = (chip and 1 or 0) + (queue and 1 or 0)
    values.low1, values.low2 = drop > 0, drop > 1

    if not hud then
        values.headOn, values.panelOn, values.countOn, values.clockLow = false, false, false, false
        N.patch(doc, "hud", values)
        return
    end
    local working = type(state.jobRun) == "table" and state.jobRun.active and true or false
    -- A lobby can wait beside a work order: the order keeps its slot, the hints move up.
    local folded = hud.phase == "lobby" and working
    -- The queue panel already shows this lobby: the provider's own header and panel step aside.
    local aside = queue ~= nil and hud.phase == "lobby" and hud.activity ~= nil and hud.activity == queue.id

    local duel = #hud.teams == 2
    values.headOn = not aside
    values.phase, values.phaseLabel = hud.phase, PHASE_LABEL[hud.phase]
    values.title, values.subtitle, values.hasSub = hud.title, hud.subtitle or "", hud.subtitle ~= nil
    values.duel, values.hasTimer = duel, hud.timer ~= nil
    values.middle = hud.timer ~= nil or duel
    values.timerUp = hud.timer ~= nil and hud.timer.countUp == true
    values.timerLabel = hud.timer and str(hud.timer.label) or ""
    values.hasTimerLabel = values.timerLabel ~= ""
    if duel then
        local a, b = hud.teams[1], hud.teams[2]
        values.t1name, values.t1score, values.t1self, values.t1color = a.name, tostring(a.score or "0"), a.self == true, teamColor(a.color)
        values.t2name, values.t2score, values.t2self, values.t2color = b.name, tostring(b.score or "0"), b.self == true, teamColor(b.color)
    end
    local chips = {}
    if not duel then
        for i, t in ipairs(hud.teams) do
            chips[i] = { name = t.name, score = tostring(t.score or "-"), self = t.self == true, color = teamColor(t.color) }
        end
    end
    values.chipsOn = #chips > 0
    values.teams = pad("teams", chips, BLANK.team)
    values.objective, values.hasObjective = hud.objective or "", hud.objective ~= nil
    local hints = {}
    for i, h in ipairs(hud.hints) do hints[i] = { key = h.key, label = h.label } end
    local hintCount = #hints
    values.headHints = folded and hintCount > 0 and not aside
    values.hints = pad("hints", hints, BLANK.hint)

    -- the panel
    local stats, bars = {}, {}
    for i, s in ipairs(hud.stats) do stats[i] = { label = s.label, value = tostring(s.value or "-") } end
    for i, p in ipairs(hud.progress) do
        local label = str(p.label)
        bars[i] = { label = label or "", hasLabel = label ~= nil, pct = N.round(N.clamp(p.value, 0, 1) * 100), color = TONE[p.tone] or TONE.accent }
    end
    local board = hud.scoreboard
    local statCount, barCount = #stats, #bars
    local panel = not folded and not aside and (statCount > 0 or barCount > 0 or board ~= nil or hintCount > 0)
    values.panelOn = panel
    values.statCount, values.barCount = statCount, barCount
    values.stats, values.bars = pad("stats", stats, BLANK.stat), pad("bars", bars, BLANK.bar)
    values.sepBars = statCount > 0
    values.boardOn = board ~= nil
    values.sepBoard = statCount > 0 or barCount > 0
    values.panelHints = hintCount > 0
    values.sepHints = statCount > 0 or barCount > 0 or board ~= nil
    local cols, rows = {}, {}
    if board then
        -- The table gets the height the stats, bars and hints leave, at 25 dp a row.
        local statRows = statCount == 3 and 1 or math.ceil(statCount / 2)
        local room = PANEL_MAX_H - (statRows > 0 and 20 + 46 * statRows or 0)
            - (barCount > 0 and 24 + 26 * barCount or 0) - (hintCount > 0 and 48 or 0) - 36
        local max = math.min(8, math.max(3, math.floor(room / 25)))
        local shown = windowRows(board.rows, max)
        local widths = columnWidths(board.columns, shown)
        local head = false
        for c, text in ipairs(board.columns) do
            cols[c] = { t = tostring(text), w = widths[c] }
            if text ~= "" then head = true end
        end
        values.boardHead = head
        for i, entry in ipairs(shown) do
            if not entry then
                rows[i] = { gap = true, rank = "", name = "", self = false, hasTeam = false, color = INK_300, cells = {} }
            else
                local r, cells = entry.row, {}
                for c = 1, #board.columns do
                    local cell = type(r.values) == "table" and r.values[c] or nil
                    cells[c] = { t = cell == nil and "-" or tostring(cell), w = widths[c] }
                end
                local team = r.team ~= nil and hud.teams[tonumber(r.team) or 0] or nil
                rows[i] = { gap = false, rank = tostring(entry.rank), name = r.name, self = r.self == true,
                    hasTeam = r.team ~= nil, color = teamColor(team and team.color), cells = cells }
            end
        end
    else
        values.boardHead = false
    end
    pad("cols", cols, BLANK.col)
    pad("rows", rows, { gap = false, rank = "", name = "", self = false, hasTeam = false, color = INK_300 })
    for _, row in ipairs(rows) do row.cells = pad("cells", row.cells or {}, BLANK.cell, #cols) end
    values.cols, values.rows = cols, rows
    N.patch(doc, "hud", values)
end

local function feedRows(now)
    local rows = {}
    for i, f in ipairs(feed) do
        rows[i] = { text = f.text, rail = TONE[f.tone] or INK_400, hi = f.tone == "accent", out = now - f.at >= FEED_MS * FEED_FADE_AT }
    end
    return pad("feed", rows, BLANK.feed)
end

local function showBanner(item)
    flip.banner = not flip.banner
    local tone = TONE[item.tone] and item.tone or "accent"
    local title, text = str(item.title), str(item.text)
    N.patch(doc, "hud", {
        bannerOn = true, bannerA = flip.banner, bannerOut = false, bannerTone = TONE[tone], bannerAccent = tone == "accent",
        bannerHasTitle = title ~= nil, bannerTitle = title or "", bannerHasText = text ~= nil, bannerText = text or "",
    })
end

local function showResult(item)
    flip.result = not flip.result
    local place = item.placement
    local numeric = type(place) == "number"
    local lines = {}
    for _, l in ipairs(filter(arr(item.lines), function(l) return type(l) == "table" and type(l.label) == "string" end)) do
        lines[#lines + 1] = { label = l.label, value = tostring(l.value or "") }
    end
    local title, sub = str(item.title), str(item.subtitle)
    N.patch(doc, "hud", {
        resultOn = true, resultA = flip.result, resultFirst = numeric and place == 1, resultLife = 100,
        placeOn = place ~= nil, placeWord = not numeric,
        place = place == nil and "" or (numeric and tostring(math.tointeger(place) or place) or tostring(place)),
        placeSuffix = numeric and ordinalSuffix(math.floor(place)) or "",
        resultHasTitle = title ~= nil, resultTitle = title or "", resultHasSub = sub ~= nil, resultSub = sub or "",
        lineCount = #lines, lines = pad("lines", lines, BLANK.line),
    })
end

--- The moving parts, from the game timer. Returns how long the thread may sleep.
local function tick()
    local now = N.now()
    local values, wait = {}, 200
    -- the clock
    if hud and hud.timer then
        local timer = hud.timer
        local value = clockValue(timer, hud.phase, now - hudAt)
        values.clock = timer.countUp and formatElapsed(value) or formatRemaining(value)
        values.clockLow = not timer.countUp and value > 0 and value <= 10000
        if timer.countUp then
            if hud.phase == "running" then wait = 33 end
        elseif value > 0 then wait = math.min(wait, 100) end
    end
    -- the countdown
    if hud and hud.phase == "countdown" and not away() then
        values.countOn = true
        if hud.countdown == nil then
            values.countWait, values.countFar, values.countBig = true, false, false
        else
            local left = hud.countdown - (now - hudAt)
            local seconds = math.ceil(left / 1000)
            local text
            if seconds > BIG_COUNT_S then
                text = formatRemaining(left)
                values.countWait, values.countFar, values.countBig = false, true, false
            else
                text = seconds > 0 and tostring(seconds) or "GO"
                values.countWait, values.countFar, values.countBig, values.countGo = false, false, true, seconds <= 0
                if text ~= lastCount then flip.count = not flip.count; values.countA = flip.count end
            end
            lastCount = text
            values.countText = text
            wait = math.min(wait, 50)
        end
    else
        values.countOn = false
        lastCount = nil
    end
    -- the feed: the oldest entry leaves after FEED_MS
    if #feed > 0 then
        local changed = false
        while feed[1] and now - feed[1].at >= FEED_MS do table.remove(feed, 1); changed = true end
        values.feed = feedRows(now)
        wait = math.min(wait, 100)
        if changed and #feed == 0 then layout() end
    end
    -- the banner
    if banner then
        local age, life = now - banner.at, banner.durationMs
        if age >= life then
            banner = nil
            values.bannerOn = false
            layout()
        else
            values.bannerOut = age >= life * FEED_FADE_AT
            wait = math.min(wait, 100)
        end
    end
    -- the result card and its life bar
    if result then
        local age, life = now - result.at, result.durationMs
        if age >= life then
            result = nil
            values.resultOn = false
            layout()
        else
            values.resultLife = math.floor((1 - age / life) * 1000 + 0.5) / 10
            wait = math.min(wait, 100)
        end
    end
    N.patch(doc, "hud", values)
    return wait
end

-- ---- the page event --------------------------------------------------------------------
local function onMessage(m)
    if type(m) ~= "table" then return end
    if m.op == "show" then
        local view = normalizeHud(m.hud)
        if view then hud, hudAt = view, N.now() end
    elseif m.op == "clear" then
        hud, feed = nil, {}
        -- The owner closing its HUD leaves the result card and the last banner their time
        -- on screen; a stop, a restart or a character change takes everything.
        if m.reason ~= "cleared" then
            banner, result = nil, nil
            N.patch(doc, "hud", { bannerOn = false, resultOn = false })
        end
        N.patch(doc, "hud", { feed = feedRows(N.now()) })
    elseif m.op == "push" and type(m.item) == "table" then
        seq = seq + 1
        if m.kind == "feed" and str(m.item.text) then
            feed[#feed + 1] = { text = m.item.text, tone = m.item.tone, at = N.now(), key = seq }
            while #feed > FEED_MAX do table.remove(feed, 1) end
        elseif m.kind == "banner" then
            local life = num(m.item.durationMs)
            banner = { at = N.now(), durationMs = life and life > 0 and life or 3000 }
            showBanner(m.item)
        elseif m.kind == "result" then
            banner = nil
            N.patch(doc, "hud", { bannerOn = false })
            local life = num(m.item.durationMs)
            result = { at = N.now(), durationMs = life and life > 0 and life or 8000 }
            showResult(m.item)
        end
    end
    layout()
    tick()
end

N.onStart(function()
    doc = N.create({ document = "ui/native/activity.rml", zIndex = 29, models = { hud = model() } })
    if not doc then return end
    N.patch(doc, "hud", { quiet = N.shell.hidden })
    layout()
    CreateThread(function()
        while true do
            local ok, wait = pcall(tick)
            if not ok then N.log("activity tick failed: " .. tostring(wait)); wait = 500 end
            Wait(wait or 200)
        end
    end)
end)

-- The page faded this HUD under the F1 menu and the dialogs; NativeUI draws above them.
N.onShell(function(shell) N.patch(doc, "hud", { quiet = shell.hidden }) end)
N.on(E.page.activityHud, onMessage)
for _, key in ipairs({ "character", "missionQueue", "fixerGig", "queue", "jobRun" }) do
    N.onState(key, function() layout() end)
end

-- for tests/
A.formatRemaining, A.formatElapsed, A.clockValue, A.ordinalSuffix = formatRemaining, formatElapsed, clockValue, ordinalSuffix
A.windowRows, A.teamColor, A.normalizeHud = windowRows, teamColor, normalizeHud
