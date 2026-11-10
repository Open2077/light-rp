-- The Light RP chat on NativeUI (ui/chat.rml). client/main.lua keeps its logic (commands,
-- the history owner, suggestions from the server, exports) and talks to this module with
-- the page API it always used: chat:send(name, payload), chat:on(name, fn),
-- chat:setFocus(keyboard, cursor). Events raised: chat:ready, chat:submit {text},
-- chat:close, chat:requestSuggestions, chat:focusLost (the keyboard went to a page).
-- The look and the behaviour are the former WebUI page's (ui/chat.rcss): a fixed-height
-- log pinned to its newest line, plates that hide after a while, a panel while typing.
ChatUi = {}
local N = ChatUi

local MAX_MESSAGES = 48
local MAX_LENGTH = 4096
-- Closed, the whole chat hides this long after the last activity (a message's `duration`
-- can keep it longer), and this long after it is closed.
local IDLE_MS = 10000
local IDLE_AFTER_CLOSE_MS = 6000
-- More lines than this in one frame (history replay, a burst) arrive without animation.
local BURST_ANIMATED = 3
local PAGE_ROWS = 7 -- PageUp / PageDown: about 0.8 of the log
local KINDS = { message = true, system = true, announce = true, warning = true, error = true, action = true, join = true, leave = true }
-- Design system palette. A channel tag is drawn only when the sender named one:
-- roleplay speech carries the character's name, nothing else.
local CHANNELS = {
    global = { label = "GLOBAL", color = "#FFCC00" },
    ["local"] = { label = "LOCAL", color = "#8A8F9C" },
    squad = { label = "SQUAD", color = "#35D07F" },
    whisper = { label = "WHISPER", color = "#7FA7B8" },
    ooc = { label = "OOC", color = "#8A8F9C" },
    admin = { label = "ADMIN", color = "#FF2E3C" },
}
local ACCENT = "#FFCC00"
N.IDLE_MS, N.IDLE_AFTER_CLOSE_MS = IDLE_MS, IDLE_AFTER_CLOSE_MS

local function bounded(v, max) return tostring(v == nil and "" or v):sub(1, max or MAX_LENGTH) end
-- Text safe inside RML: markup escaped, control characters flattened, and no "{{" / "}}"
-- left for a data binding to evaluate (the document has no data model today; a player's
-- "{{" must stay inert even if it gets one).
local function esc(s)
    local text = tostring(s or ""):gsub("[%c]", " "):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    text = text:gsub("{{", "{ {"):gsub("{{", "{ {"):gsub("}}", "} }"):gsub("}}", "} }")
    return text
end
N.escape = esc
local function token(v, fallback)
    local t = bounded(v, 24):lower():gsub("[^a-z0-9_-]", "")
    return t ~= "" and t or fallback
end
local function rgb(v, fallback)
    if type(v) ~= "table" or #v < 3 then return fallback end
    local function c(i)
        local n = tonumber(v[i]) or 0
        if n ~= n then n = 0 end
        return math.max(0, math.min(255, math.floor(n + 0.5)))
    end
    return ("#%02X%02X%02X"):format(c(1), c(2), c(3))
end

--- A message table (the chat API's: text/args/author/type/channel/color/segments/...) normalised.
function N.normalize(raw, templates)
    if type(raw) == "string" then raw = { text = raw } end
    if type(raw) ~= "table" then return nil end
    local args = type(raw.args) == "table" and raw.args or {}
    local author = raw.author
    if author == nil then author = #args > 1 and args[1] or "" end
    author = bounded(author, 96)
    local text = raw.text
    if text == nil then text = raw.message end
    if text == nil then
        if #args > 1 then
            local rest = {}
            for i = 2, #args do rest[#rest + 1] = tostring(args[i]) end
            text = table.concat(rest, " ")
        else
            text = args[1]
        end
    end
    text = bounded(text, MAX_LENGTH)
    if raw.templateId and templates and templates[tostring(raw.templateId)] then
        text = templates[tostring(raw.templateId)]:gsub("{(%d+)}", function(i)
            local value = args[tonumber(i) + 1]
            return bounded(value == nil and "" or value, 1024)
        end)
    end
    local kind = token(raw.kind or raw.type, "message")
    if kind == "player" or kind == "default" then kind = "message" end
    if kind == "announcement" then kind = "announce" end
    if not KINDS[kind] then kind = "message" end
    -- Roleplay emotes arrive as plain lines whose author starts with "* " (/me, /do, /try).
    if kind == "message" and author:match("^%*%s+%S") then kind = "emote" end
    local explicit = type(raw.channel) == "string" and CHANNELS[raw.channel] ~= nil
    local channel = explicit and raw.channel or (kind == "warning" and "admin" or "global")
    return {
        author = author, text = text, kind = kind, channel = channel, explicitChannel = explicit,
        channelColor = CHANNELS[channel].color, color = rgb(raw.color, CHANNELS[channel].color),
        playerId = bounded(raw.playerId, 20), role = token(raw.role, ""),
        -- the client sandbox has no local clock: a time is shown when the sender gave one
        time = (raw.time ~= nil and tostring(raw.time) ~= "") and bounded(raw.time, 16) or nil,
        segments = type(raw.segments) == "table" and raw.segments or {},
        mention = raw.mention == true or raw.mentioned == true, title = bounded(raw.title, 96),
        duration = tonumber(raw.duration),
    }
end

local function textRml(m)
    if #m.segments > 0 then
        local out = {}
        for i = 1, math.min(32, #m.segments) do
            local s = m.segments[i]
            if type(s) == "table" then
                local style = s.color and (' style="color: %s;"'):format(rgb(s.color, ACCENT)) or ""
                out[#out + 1] = ('<span class="seg%s"%s>%s</span>'):format(s.bold and " bold" or "", style, esc(bounded(s.text, 1024)))
            end
        end
        return ('<span class="text">%s</span>'):format(table.concat(out))
    end
    return ('<span class="text">%s</span>'):format(esc(m.text))
end

-- a tag with the design system's slanted right edge (--clip-tag)
local function tagRml(class, label, color)
    local style = color and (' style="color: %s;"'):format(color) or ""
    return ('<span class="tg %s"><span class="tg-t"%s>%s</span><path class="tg-s" view-box="0 0 8 14" preserve-aspect="none" d="M0 0L8 0L0 14Z"/></span>')
        :format(class, style, esc(label))
end

-- ---- one line or two ---------------------------------------------------------------------
-- The page laid a line out with flex-wrap: the words follow the name when they fit, else
-- they go under it. RmlUi's flex-wrap inside a shrink-to-fit plate measures the plate one
-- line high and draws the wrapped words over the next line, so the choice is made here,
-- from the text widths (dp, measured in game: Chakra Petch 15 dp 6.6 per character, 13 dp
-- bold 6.9, Share Tech Mono 10 dp with its letter spacing 6.6).
local LINE = 515           -- the plate's inner width (560 - padding), with some margin
local function textLength(m)
    if #m.segments == 0 then return utf8.len(m.text) or #m.text end
    local length = 0
    for i = 1, math.min(32, #m.segments) do
        local s = m.segments[i]
        if type(s) == "table" then
            local t = bounded(s.text, 1024)
            length = length + (utf8.len(t) or #t)
        end
    end
    return length
end
local function chars(s) return utf8.len(s) or #s end
--- The width (dp) of what precedes the words (tags, id, name) and of the words.
function N.widths(m)
    local head = 0
    local function add(w) head = head + w + 8 end
    if m.kind == "system" or m.kind == "error" or m.kind == "warning" then
        local label = m.author ~= "" and m.author or "System"
        add(chars(label) * 6.6 + 13)
    elseif m.kind == "message" then
        if m.explicitChannel then add(chars(CHANNELS[m.channel].label) * 6.6 + 13) end
        if m.playerId:match("^%d+$") then add((#m.playerId + 1) * 6) end
        if m.mention then add(25) end
        if m.author ~= "" then add(chars(m.author) * 6.9 + 5 + (m.role ~= "" and (chars(m.role) * 6.2 + 5) or 0)) end
    end
    return head, textLength(m) * 6.6
end
--- Whether the words go under the name (the page's wrapped line).
function N.stacked(m)
    if m.kind ~= "message" and m.kind ~= "system" and m.kind ~= "error" and m.kind ~= "warning" then return false end
    local head, text = N.widths(m)
    return head > 0 and head + text > LINE
end

local PLATE = '<div class="pl pl-a"></div><div class="pl pl-b"></div><path class="pl-c" view-box="0 0 6 6" d="M0 0L6 0L0 6Z"/>'

--- The inside of a row (.msg): its body with the plate, the colour edge and the content.
function N.rowRml(m)
    local time = m.time and ('<span class="time">%s</span>'):format(esc(m.time)) or ""
    -- a line that names you carries the accent on its edge
    local edge = ('<div class="edge" style="background-color: %s;"></div>'):format(m.mention and ACCENT or m.color)
    local sheen = ('<div class="sheen" style="decorator: linear-gradient(100deg, %s00 20%%, %s42 50%%, %s00 80%%);"></div>'):format(m.color, m.color, m.color)
    local content
    if m.kind == "announce" then
        content = ('<div class="ann-head"><div class="ann-dot"></div><span class="ann-title">%s</span>%s</div>%s')
            :format(esc(m.title ~= "" and m.title or "Server announcement"), time, textRml(m))
    elseif m.kind == "system" or m.kind == "error" or m.kind == "warning" then
        local label = m.author ~= "" and m.author or (m.kind == "error" and "Error" or (m.kind == "warning" and "Warning" or "System"))
        local head = time .. tagRml("tg-kind", label, m.color)
        content = N.stacked(m) and ('<div class="head">%s</div>%s'):format(head, textRml(m)) or (head .. textRml(m))
    elseif m.kind == "join" or m.kind == "leave" then
        local what = m.kind == "join" and "connected" or "disconnected"
        local extra = m.text ~= "" and (" · " .. m.text) or ""
        content = ('%s<div class="presence-dot"></div><span class="presence"><span class="presence-name">%s</span> %s%s</span>')
            :format(time, esc(m.author ~= "" and m.author or "Player"), what, esc(extra))
    elseif m.kind == "action" or m.kind == "emote" then
        local name = m.kind == "emote" and m.author:gsub("^%*%s+", "") or (m.author ~= "" and m.author or "Player")
        content = ('%s<span class="action" style="color: %s;">* <span class="action-name">%s</span> %s</span>')
            :format(time, m.color, esc(name), esc(m.text))
    else
        local parts = { time }
        if m.explicitChannel then parts[#parts + 1] = tagRml("tg-channel", CHANNELS[m.channel].label, m.channelColor) end
        if m.playerId:match("^%d+$") then parts[#parts + 1] = ('<span class="pid">#%s</span>'):format(m.playerId) end
        if m.mention then parts[#parts + 1] = tagRml("tg-ping", "@") end
        if m.author ~= "" then
            local role = m.role ~= "" and ('<span class="role">%s</span>'):format(esc(m.role)) or ""
            parts[#parts + 1] = ('<span class="author" style="color: %s;">%s%s<span class="colon">:</span></span>'):format(m.color, esc(m.author), role)
        end
        if N.stacked(m) then
            content = ('<div class="head">%s</div>%s'):format(table.concat(parts), textRml(m))
        else
            parts[#parts + 1] = textRml(m)
            content = table.concat(parts)
        end
    end
    local ring = m.mention and '<div class="ring"></div>' or ""
    return ('<div class="body%s">%s%s%s%s%s</div>'):format(N.stacked(m) and " stack" or "", PLATE, edge, content, sheen, ring)
end

--- How tall the row will be, roughly: 1, 2 or 3 (and more) lines. Its height opens from 0
--- to that (ui/chat.rcss, row-open-N) so the lines above slide up instead of jumping.
function N.lines(m)
    if m.kind == "announce" then return 3 end
    local head, text = N.widths(m)
    if m.kind == "action" or m.kind == "emote" then text = text + (chars(m.author) + 3) * 6.6 end
    if N.stacked(m) then return text <= LINE and 2 or 3 end
    if head + text <= LINE then return 1 end
    return text <= LINE * 2 and 2 or 3
end

function N.rowClasses(m, animated)
    local classes = "msg k-" .. m.kind .. (m.mention and " mention" or "")
    if animated then classes = classes .. " new h" .. N.lines(m) end
    return classes
end

local function paramsText(item)
    local out = {}
    -- an empty Lua table is no parameter list; only a sequence lists parameters
    local list = type(item.parameters) == "table" and item.parameters or {}
    for p = 1, math.min(8, #list) do
        local param = list[p]
        local name = bounded(type(param) == "table" and param.name or param, 40)
        out[#out + 1] = (type(param) == "table" and param.optional) and ("[" .. name .. "]") or ("<" .. name .. ">")
    end
    return out
end

--- The command index: up to 7 rows "01 /command <params> help".
function N.suggestionsRml(visible, selected)
    local out = {}
    for i, item in ipairs(visible) do
        local params = {}
        for _, text in ipairs(paramsText(item)) do params[#params + 1] = ('<span class="sg-param">%s</span>'):format(esc(text)) end
        out[#out + 1] = ('<div id="sg-%d" class="sg%s"><span class="sg-idx">%02d</span><div class="sg-syntax"><span class="sg-cmd">%s</span>%s</div><span class="sg-help">%s</span></div>')
            :format(i, i == selected and " sel" or "", i, esc(item.command), table.concat(params), esc(bounded(item.help, 240)))
    end
    return table.concat(out)
end

--- The suggestions a line asks for: commands starting with its first word, shortest first.
function N.matches(suggestions, value)
    local query = tostring(value or ""):match("^%s*(.-)%s*$"):lower()
    if query:sub(1, 1) ~= "/" then return {} end
    local command = query:match("^(%S*)")
    local list = {}
    for key, item in pairs(suggestions) do
        if key:sub(1, #command) == command then list[#list + 1] = item end
    end
    table.sort(list, function(a, b)
        if #a.command ~= #b.command then return #a.command < #b.command end
        return a.command < b.command
    end)
    local visible = {}
    for i = 1, math.min(7, #list) do visible[i] = list[i] end
    return visible
end

local function timer() return type(GetGameTimer) == "function" and GetGameTimer() or 0 end

--- The chat surface with the page API client/main.lua uses.
function N.create()
    if type(Open77) ~= "table" or type(Open77.ui) ~= "table" or type(Open77.ui.create) ~= "function" then
        return nil, "nativeui_unavailable"
    end
    if type(Open77.ui.loadFont) == "function" then
        local ok, done, why = pcall(Open77.ui.loadFont, "ui/fonts/share-tech-mono-400.ttf", "Share Tech Mono", false)
        if not ok or not done then print("[open77_chat] font not loaded: " .. tostring(ok and why or done)) end
    end
    -- The HUD lab (tools/native-lab) sets Op77UiLab before this script loads: the document
    -- is then drawn on its layer (above the pre-game shell). Absent, nothing changes.
    local lab = type(Op77UiLab) == "table" and Op77UiLab or nil
    local ui, why = Open77.ui.create({ document = "ui/chat.rml", layer = lab and lab.layer or "hud", zIndex = 30, visible = true })
    if not ui then return nil, why end
    -- op77_loadscreen's zone cover is a WebUI page, below every NativeUI document: the chat
    -- page sat under it, so the document steps aside while it is up (no-op without it).
    if type(AddEventHandler) == "function" and not lab then
        AddEventHandler("op77_loadscreen:state", function(active)
            if active == true then ui:hide() else ui:show() end
        end)
    end
    -- DOM listeners, kept by name so that the lab can replay an input without the lease
    local listeners = {}
    local function listen(kind, selector, fn)
        if fn == nil then
            fn, selector = selector, ""
            ui:on(kind, fn)
        else
            ui:on(kind, selector, fn)
        end
        listeners[kind .. "|" .. selector] = fn
    end
    -- lab only: shorter idle delays, to show the auto-hide within a scene
    local function idleMs() return lab and tonumber(lab.chatIdleMs) or IDLE_MS end
    local function idleAfterCloseMs() return lab and tonumber(lab.chatIdleAfterCloseMs) or IDLE_AFTER_CLOSE_MS end

    local page = { handlers = {} }
    local rows = {}            -- { serial }
    local suggestions = {}     -- lower command -> { command, help, parameters }
    local templates = {}
    local history, historyIndex = {}, 1
    local open = false
    local value = ""
    local visible, selected = {}, 1
    local alive = true
    local openedAt = nil       -- when the composer took the keyboard (the opening key's character follows)
    -- follow the newest line: always when closed, when open until the reader pages up
    local following, unread, viewIndex = true, 0, 0
    local idle, idleDeadline, idleArmed = true, 0, false
    local burstAt, burst = nil, 0
    local sendToken = 0

    local function emit(name, payload)
        local fn = page.handlers[name]
        if fn then fn(payload or {}) end
    end

    -- ---- auto-hide --------------------------------------------------------------------------
    local function setIdle(v)
        if idle == v then return end
        idle = v
        ui:class("#chat", "idle", v)
    end
    local function wake(delay)
        setIdle(#rows == 0)
        if open then return end
        idleDeadline = math.max(idleDeadline, timer() + delay)
        if idleArmed then return end
        idleArmed = true
        CreateThread(function()
            while alive do
                if open or idleDeadline == 0 then break end
                local left = idleDeadline - timer()
                if left <= 0 then setIdle(true) break end
                Wait(left)
            end
            idleArmed = false
        end)
    end
    local function updateEmpty()
        ui:class("#root", "empty", #rows == 0)
        if #rows == 0 and not open then setIdle(true) end
    end

    -- ---- pinning: the newest line is always fully in view -----------------------------------
    local function updateUnread(count)
        unread = math.max(0, count)
        ui:text("#unread", tostring(unread))
        ui:class("#latest", "on", open and unread > 0)
    end
    -- Closed, the list hangs from the bottom edge of the log (RCSS). Open, the log scrolls:
    -- bring the newest row in, again on the next frames (the layout follows a class change
    -- or a row's opening height by a frame or two).
    local function pin(frames)
        local last = rows[#rows]
        if not last or not open then return end
        ui:scrollTo(last.serial, false)
        CreateThread(function()
            for _ = 1, frames or 2 do
                Wait(0)
                if not alive or not open or not following or rows[#rows] ~= last then return end
                ui:scrollTo(last.serial, false)
            end
        end)
    end
    local function scrollToLatest()
        following, viewIndex = true, #rows
        pin(2)
        updateUnread(0)
    end
    local function pageBy(step)
        if #rows == 0 then return end
        if following then viewIndex = #rows end
        viewIndex = math.max(1, math.min(#rows, viewIndex + step))
        if viewIndex >= #rows then scrollToLatest() return end
        following = false
        ui:scrollTo(rows[viewIndex].serial, false)
    end

    -- ---- messages ------------------------------------------------------------------------------
    local function addMessage(raw)
        local m = N.normalize(raw, templates)
        if not m or (m.text == "" and #m.segments == 0) then return end
        local at = timer()
        if at ~= burstAt then burstAt, burst = at, 0 end
        burst = burst + 1
        local animated = burst <= BURST_ANIMATED
        local serial = ui:create("#list", { tag = "div", class = N.rowClasses(m, animated), rml = N.rowRml(m) })
        local row = { serial = serial }
        rows[#rows + 1] = row
        while #rows > MAX_MESSAGES do
            local old = table.remove(rows, 1)
            ui:remove(old.serial)
            if not following then viewIndex = math.max(1, viewIndex - 1) end
        end
        updateEmpty()
        if animated then
            CreateThread(function()
                Wait(1700)
                if alive then ui:class(serial, "new", false) end
            end)
        end
        if open then
            if following then viewIndex = #rows; pin(animated and 14 or 2)
            else updateUnread(unread + 1) end
        end
        wake(math.max(idleMs(), m.duration or 0))
    end

    -- ---- command index -------------------------------------------------------------------------
    local function renderSuggestions()
        visible = N.matches(suggestions, value)
        selected = math.max(1, math.min(selected, math.max(1, #visible)))
        local any = #visible > 0
        ui:rml("#suggestion-list", any and N.suggestionsRml(visible, selected) or "")
        ui:class("#root", "has-suggestions", any)
    end
    local function updateComposer()
        ui:text("#chars", #value .. "/256")
        ui:class("#chars", "long", #value >= 160)
        ui:class("#chars", "near", #value >= 232)
        ui:class("#send", "disabled", not value:match("%S"))
    end
    local function setValue(text)
        value = text
        ui:value("#input", text)
        updateComposer()
        renderSuggestions()
    end
    local function complete()
        local item = visible[selected]
        if not item then return false end
        local suffix = value:match("^%s*/%S*(.*)$") or ""
        selected = 1
        setValue(item.command .. (suffix:match("%S") and suffix or " "))
        return true
    end

    -- ---- open / close ----------------------------------------------------------------------------
    local function setOpen(v)
        open = v == true
        ui:class("#root", "open", open)
        following, viewIndex = true, #rows
        if open then
            idleDeadline = 0
            setIdle(false)
            openedAt = timer()
            ui:focusElement("#input")
            updateEmpty()
            -- the class change lays the log out again over the next frames: keep pinning
            pin(30)
            emit("chat:requestSuggestions", {})
        else
            ui:blurElement("#input")
            selected = 1
            updateUnread(0)
            setValue("")
            updateEmpty()
            wake(idleAfterCloseMs())
        end
    end

    local function submit()
        local text = value:match("^%s*(.-)%s*$")
        if text == "" then emit("chat:close", {}) return end
        history[#history + 1] = text
        if #history > 50 then table.remove(history, 1) end
        historyIndex = #history + 1
        sendToken = sendToken + 1
        local at = sendToken
        ui:class("#root", "transmitting", false)
        CreateThread(function()
            Wait(0)
            if alive and at == sendToken then ui:class("#root", "transmitting", true) end
        end)
        emit("chat:submit", { text = text })
    end

    local function ready()
        -- a (re)loaded document is empty: main.lua replays its history on chat:ready
        rows, open, value, visible, selected = {}, false, "", {}, 1
        following, unread, viewIndex = true, 0, 0
        idle, idleDeadline = true, 0
        updateComposer()
        updateEmpty()
        emit("chat:ready", {})
    end
    ui:onEvent("loaded", ready)
    ui:onEvent("reloaded", ready)
    ui:onEvent("focus", function(kind, detail)
        -- a WebUI page took the keyboard: the composer cannot stay open behind it
        if kind == "blur" and open and type(detail) == "table" and detail.reason == "taken" then emit("chat:focusLost", {}) end
    end)
    ui:onEvent("error", function(name, detail)
        local message = tostring(detail and detail.message)
        print("[open77_chat] ui " .. tostring(name) .. ": " .. message)
        if name == "focus" and open then emit("chat:focusLost", {}) end
    end)

    listen("change", "#input", function(e)
        if not open then return end
        value = tostring(e.value or "")
        -- the key that opened the chat (T) is still typed: its character reaches the
        -- composer that just took the keyboard. A single character in the first moments is it.
        if openedAt and #value == 1 and timer() - openedAt < 150 then
            openedAt = nil
            setValue("")
            return
        end
        openedAt = nil
        selected = 1
        updateComposer()
        renderSuggestions()
    end)
    listen("keydown", function(e)
        if not open then return end
        local key = tostring(e.key or ""):lower()
        if e.value ~= nil then value = tostring(e.value) end
        if key == "escape" then emit("chat:close", {})
        elseif key == "enter" or key == "return" or key == "numpadenter" then submit()
        elseif key == "tab" then
            if #visible > 0 then complete() end
            ui:focusElement("#input")
        elseif key == "up" then
            if #visible > 0 then selected = (selected - 2) % #visible + 1; renderSuggestions()
            elseif #history > 0 then historyIndex = math.max(1, historyIndex - 1); setValue(history[historyIndex] or "") end
        elseif key == "down" then
            if #visible > 0 then selected = selected % #visible + 1; renderSuggestions()
            elseif #history > 0 then historyIndex = math.min(#history + 1, historyIndex + 1); setValue(history[historyIndex] or "") end
        elseif key == "pageup" or key == "prior" or key == "page_up" then pageBy(-PAGE_ROWS)
        elseif key == "pagedown" or key == "next" or key == "page_down" then pageBy(PAGE_ROWS)
        end
    end)

    local function addSuggestion(item)
        if type(item) ~= "table" or not item.command or item.command == "" then return end
        local command = tostring(item.command)
        if command:sub(1, 1) ~= "/" then command = "/" .. command end
        suggestions[command:lower()] = { command = command, help = item.help, parameters = item.parameters }
    end

    function page.on(_, name, fn) page.handlers[name] = fn end
    -- The composer takes the keyboard only: the cursor stays with the game, so HUDs that
    -- step aside under cursor interfaces stay on screen.
    function page.setFocus(_, keyboard, cursor)
        if keyboard or cursor then ui:focus({ keyboard = true, cursor = cursor == true }) else ui:blur() end
        return true
    end
    function page.send(_, name, p)
        p = type(p) == "table" and p or {}
        if name == "chat:open" then setOpen(true)
        elseif name == "chat:close" then setOpen(false)
        elseif name == "chat:state" then
            local enabled = p.enabled ~= false
            ui:class("#chat", "disabled", not enabled)
            if not enabled then setOpen(false) end
        elseif name == "chat:addMessage" then addMessage(p)
        elseif name == "chat:clear" then
            for _, row in ipairs(rows) do ui:remove(row.serial) end
            rows = {}
            following, viewIndex = true, 0
            updateUnread(0)
            updateEmpty()
        elseif name == "chat:clearSuggestions" then suggestions = {}; selected = 1; renderSuggestions()
        elseif name == "chat:addTemplate" then if p.id then templates[tostring(p.id)] = bounded(p.template) end
        elseif name == "chat:addSuggestion" then addSuggestion(p); renderSuggestions()
        elseif name == "chat:addSuggestions" then
            for _, item in ipairs(type(p.suggestions) == "table" and p.suggestions or {}) do addSuggestion(item) end
            renderSuggestions()
        elseif name == "chat:removeSuggestion" then
            local command = tostring(p.command or "")
            if command:sub(1, 1) ~= "/" then command = "/" .. command end
            suggestions[command:lower()] = nil
            renderSuggestions()
        end
    end
    if lab then
        -- lab only: replay a DOM event (the pre-game shell keeps the keyboard and the mouse)
        function page.labInput(_, kind, selector, e)
            local fn = listeners[kind .. "|" .. (selector or "")]
            if fn then fn(e or {}) end
        end
        -- lab only: put a line in the composer as if it had been typed
        function page.labType(_, text) openedAt = nil; selected = 1; setValue(tostring(text or "")) end
    end
    function page.destroy() alive = false; pcall(ui.destroy, ui) end
    return page
end
