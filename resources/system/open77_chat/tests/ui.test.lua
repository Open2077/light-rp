-- The chat surface (client/ui.lua): message normalisation and rows, the command index, and
-- the document driven through a recording fake of Open77.ui (open/close, auto-hide, paging,
-- unread, history, completion). Run with Lua 5.4 from the resource folder:
--   lua tests/ui.test.lua
local clock, threads = 0, {}
function GetGameTimer() return clock end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), due = clock } end
function Wait(ms) coroutine.yield(ms or 0) end
local function advance(ms)
    local target = clock + ms
    while true do
        local ran = false
        local current = threads; threads = {}
        for _, thread in ipairs(current) do
            if thread.due <= target then
                clock = math.max(clock, thread.due)
                local ok, delay = coroutine.resume(thread.co)
                assert(ok, delay)
                if coroutine.status(thread.co) ~= "dead" then
                    threads[#threads + 1] = { co = thread.co, due = clock + math.max(1, delay or 0) }
                end
                ran = true
            else
                threads[#threads + 1] = thread
            end
        end
        if not ran then break end
    end
    clock = target
end

local doc = { classes = {}, texts = {}, rml = {}, values = {}, created = {}, removed = {}, scrolls = {}, listeners = {}, events = {},
    focus = nil, elementFocus = nil, serial = 0 }
local ui = {}
function ui:onEvent(kind, fn) doc.events[kind] = fn end
function ui:on(kind, sel, fn) if fn == nil then fn, sel = sel, "" end; doc.listeners[kind .. "|" .. sel] = fn end
function ui:class(sel, name, on) doc.classes[sel .. "." .. name] = on end
function ui:text(sel, text) doc.texts[sel] = text end
function ui:rml(sel, text) doc.rml[sel] = text end
function ui:value(sel, text) doc.values[sel] = text end
function ui:create(parent, spec)
    doc.serial = doc.serial + 1
    local serial = "@" .. doc.serial
    doc.created[#doc.created + 1] = { serial = serial, parent = parent, spec = spec }
    return serial
end
function ui:remove(sel) doc.removed[#doc.removed + 1] = sel end
function ui:scrollTo(sel, align) doc.scrolls[#doc.scrolls + 1] = sel end
function ui:focus(options) doc.focus = options end
function ui:blur() doc.focus = nil end
function ui:focusElement(sel) doc.elementFocus = sel end
function ui:blurElement() doc.elementFocus = nil end
function ui:destroy() doc.destroyed = true end
local function fire(kind, sel, e) return doc.listeners[kind .. "|" .. (sel or "")](e or {}) end
local fonts = {}
Open77 = { ui = {
    create = function(spec) assert(spec.document == "ui/chat.rml" and spec.layer == "hud"); return ui end,
    loadFont = function(_, family) fonts[#fonts + 1] = family; return true end,
} }

dofile("client/ui.lua")
local N = ChatUi

-- ---- normalisation and rows ----------------------------------------------------------------
local m = N.normalize({ args = { "Yuki", "hello", "there" }, color = { 255, 0, 0 } })
assert(m.author == "Yuki" and m.text == "hello there" and m.kind == "message" and m.color == "#FF0000")
local row = N.rowRml(m)
assert(row:find('class="author" style="color: #FF0000;">Yuki', 1, true) and row:find("hello there", 1, true))
assert(not row:find("GLOBAL", 1, true), "no channel tag unless the sender named one")
assert(row:find('class="pl pl-a"', 1, true) and row:find('class="edge" style="background-color: #FF0000;"', 1, true) and row:find("#FF000042", 1, true))
m = N.normalize({ text = "hi", author = "A", channel = "ooc" })
assert(m.explicitChannel and m.color == "#8A8F9C" and N.rowRml(m):find(">OOC<", 1, true))
assert(N.normalize({ text = "x" }).color == "#FFCC00", "the Light RP accent is the default colour")
m = N.normalize({ text = '<b>&"x"</b> {{y}}', author = "A<script>", playerId = "12", role = "Admin", mention = true })
row = N.rowRml(m)
assert(not row:find("<b>", 1, true) and row:find('&lt;b&gt;&amp;&quot;x&quot;&lt;/b&gt; { {y} }', 1, true), "text is escaped, no binding left")
assert(N.escape("{{{{a}}}}") == "{ { { {a} } } }" and N.escape("{x}") == "{x}")
assert(row:find("#12", 1, true) and row:find('class="role">admin', 1, true) and not row:find("<script>", 1, true))
assert(row:find("tg-ping", 1, true) and row:find('class="ring"', 1, true) and row:find('class="edge" style="background-color: #FFCC00;"', 1, true))
assert(N.rowClasses(m, true) == "msg k-message mention new h1" and N.rowClasses(m, false) == "msg k-message mention")
m = N.normalize({ type = "announcement", title = "Restart", text = "in 5 minutes", time = "20:15" })
row = N.rowRml(m)
assert(m.kind == "announce" and row:find('class="ann-title">Restart', 1, true) and row:find('class="time">20:15', 1, true))
assert(N.rowRml(N.normalize({ type = "announce", text = "x" })):find("Server announcement", 1, true))
m = N.normalize({ type = "error", author = "COMMAND", text = "nope", color = { 255, 76, 92 } })
row = N.rowRml(m)
assert(row:find("tg-kind", 1, true) and row:find('style="color: #FF4C5C;">COMMAND', 1, true))
assert(N.rowRml(N.normalize({ type = "warning", text = "x" })):find(">Warning<", 1, true) and N.normalize({ type = "warning", text = "x" }).color == "#FF2E3C")
assert(N.rowRml(N.normalize({ type = "system", text = "x" })):find(">System<", 1, true))
m = N.normalize({ type = "join", author = "Jack", text = "from Watson" })
assert(N.rowRml(m):find('<span class="presence-name">Jack</span> connected · from Watson', 1, true))
assert(N.rowRml(N.normalize({ type = "leave", text = "bye" })):find("Player</span> disconnected", 1, true))
m = N.normalize({ author = "* Judy", text = "waves", color = { 200, 100, 255 } })
assert(m.kind == "emote", "an author starting with '* ' is a roleplay emote")
assert(N.rowRml(m):find('* <span class="action-name">Judy</span> waves', 1, true))
assert(N.rowRml(N.normalize({ type = "action", author = "V", text = "nods" })):find('<span class="action-name">V</span> nods', 1, true))
m = N.normalize({ type = "weird", channel = "nope", text = "x" })
assert(m.kind == "message" and m.channel == "global" and not m.explicitChannel and m.time == nil)
m = N.normalize({ templateId = "t", args = { "a", "b" } }, { t = "{0} and {1}" })
assert(m.text == "a and b", "templates fill from the args")
m = N.normalize({ segments = { { text = "red", color = { 255, 0, 0 }, bold = true }, { text = " plain" } } })
row = N.rowRml(m)
assert(row:find('class="seg bold" style="color: #FF0000;">red', 1, true) and row:find(" plain", 1, true))
assert(N.normalize(42) == nil and N.normalize("plain").text == "plain")
assert(N.lines(N.normalize({ author = "A", text = "short" })) == 1)
assert(N.lines(N.normalize({ text = ("x"):rep(90) })) == 2 and N.lines(N.normalize({ text = ("x"):rep(300) })) == 3)
assert(N.lines(N.normalize({ type = "announce", text = "x" })) == 3)
-- a line too long to follow the name goes under it (a head row, then the words)
local long = N.normalize({ author = "Johnny Silverhand", text = ("wake up samurai "):rep(10) })
assert(N.stacked(long) and N.rowRml(long):find('<div class="body stack">', 1, true) and N.rowRml(long):find('<div class="head">', 1, true))
assert(N.lines(long) == 3 and N.lines(N.normalize({ author = "A", text = ("x"):rep(70) })) == 1)
local short = N.normalize({ author = "Kerry", role = "vip", channel = "ooc", text = "brb, phone" })
assert(not N.stacked(short) and not N.rowRml(short):find("stack", 1, true))
assert(N.stacked(N.normalize({ type = "error", author = "COMMAND", text = ("x"):rep(90) })))
assert(not N.stacked(N.normalize({ author = "* Jackie", text = ("x"):rep(200) })), "an emote wraps inside its own line")

-- ---- the command index ------------------------------------------------------------------------
local index = {
    ["/me"] = { command = "/me", help = "Act", parameters = { { name = "action" } } },
    ["/mechanic"] = { command = "/mechanic", help = "Call <one>", parameters = {} },
    ["/ooc"] = { command = "/ooc", help = "Out of character", parameters = { "text", { name = "loud", optional = true } } },
}
local found = N.matches(index, "  /ME hello")
assert(#found == 2 and found[1].command == "/me" and found[2].command == "/mechanic", "prefix of the first word, shortest first")
assert(#N.matches(index, "hello") == 0 and #N.matches(index, "/") == 3 and #N.matches(index, "/zzz") == 0)
local sg = N.suggestionsRml(N.matches(index, "/o"), 1)
assert(sg:find('id="sg-1" class="sg sel"', 1, true) and sg:find('class="sg-idx">01', 1, true))
assert(sg:find("&lt;text&gt;", 1, true) and sg:find("[loud]", 1, true) and sg:find("Out of character", 1, true))

-- ---- the surface ------------------------------------------------------------------------------
local page = assert(N.create())
assert(fonts[1] == "Share Tech Mono")
local got = {}
for _, name in ipairs({ "chat:ready", "chat:submit", "chat:close", "chat:requestSuggestions", "chat:focusLost" }) do
    page:on(name, function(payload) got[#got + 1] = { name, payload } end)
end
doc.events.loaded()
assert(got[1][1] == "chat:ready" and doc.classes["#root.empty"] == true)

-- a message wakes the chat; 10 s later it hides again
page:send("chat:addMessage", { author = "V", text = "hey" })
assert(#doc.created == 1 and doc.created[1].parent == "#list" and doc.created[1].spec.class == "msg k-message new h1")
assert(doc.classes["#chat.idle"] == false and doc.classes["#root.empty"] == false)
advance(1800)
assert(doc.classes["@1.new"] == false, "the arrival classes are removed")
advance(8000)
assert(doc.classes["#chat.idle"] == false)
advance(300)
assert(doc.classes["#chat.idle"] == true, "idle 10 s after the last line")
-- a message's duration keeps it longer
page:send("chat:addMessage", { text = "long", duration = 30000 })
advance(29000); assert(doc.classes["#chat.idle"] == false)
advance(1100); assert(doc.classes["#chat.idle"] == true)
-- empty messages are ignored; a burst arrives without animation
page:send("chat:addMessage", { text = "" })
assert(#doc.created == 2)
for i = 1, 5 do page:send("chat:addMessage", { text = "burst " .. i }) end
assert(doc.created[5].spec.class == "msg k-message new h1" and doc.created[6].spec.class == "msg k-message", "more than 3 in a frame: no animation")
advance(1)

-- open: keyboard only, the composer focused, suggestions requested, never idle
assert(page:setFocus(true, false) == true and doc.focus.keyboard == true and doc.focus.cursor == false)
page:send("chat:open", {})
assert(doc.classes["#root.open"] == true and doc.elementFocus == "#input" and got[#got][1] == "chat:requestSuggestions")
assert(doc.scrolls[#doc.scrolls] == "@7", "the newest line is brought into view")
-- the key that opened the chat is not typed
fire("change", "#input", { value = "t" })
assert(doc.values["#input"] == "")
advance(20000)
assert(doc.classes["#chat.idle"] == false, "never idle while open")
-- typing: counter and command index
page:send("chat:addSuggestions", { suggestions = { index["/me"], index["/mechanic"], { command = "ooc", help = "Out of character" } } })
fire("change", "#input", { value = "/m" })
assert(doc.texts["#chars"] == "2/256" and doc.classes["#root.has-suggestions"] == true and doc.classes["#send.disabled"] == false)
assert(doc.rml["#suggestion-list"]:find('id="sg-2"', 1, true))
fire("keydown", "", { key = "down" })
assert(doc.rml["#suggestion-list"]:find('id="sg-2" class="sg sel"', 1, true))
fire("keydown", "", { key = "tab" })
assert(doc.values["#input"] == "/mechanic ", "Tab completes the selected command")
fire("change", "#input", { value = ("x"):rep(232) })
assert(doc.classes["#chars.long"] == true and doc.classes["#chars.near"] == true and doc.classes["#root.has-suggestions"] == false)
page:send("chat:removeSuggestion", { command = "/mechanic" })
fire("change", "#input", { value = "/mec" })
assert(doc.classes["#root.has-suggestions"] == false)

-- paging up stops following: new lines count on the NEW chip
fire("keydown", "", { key = "pageup" })
assert(doc.scrolls[#doc.scrolls] == "@1")
page:send("chat:addMessage", { text = "while reading" })
assert(doc.texts["#unread"] == "1" and doc.classes["#latest.on"] == true and doc.scrolls[#doc.scrolls] == "@1", "the view does not move")
fire("keydown", "", { key = "pagedown" }); fire("keydown", "", { key = "pagedown" })
assert(doc.scrolls[#doc.scrolls] == "@8" and doc.texts["#unread"] == "0" and doc.classes["#latest.on"] == false)
page:send("chat:addMessage", { text = "following again" })
assert(doc.scrolls[#doc.scrolls] == "@9" and doc.classes["#latest.on"] == false)
advance(300)

-- submit: trimmed, kept in the history, the composer flashes; an empty line closes
fire("keydown", "", { key = "enter", value = "  hello there  " })
assert(got[#got][1] == "chat:submit" and got[#got][2].text == "hello there")
advance(1)
assert(doc.classes["#root.transmitting"] == true)
fire("keydown", "", { key = "enter", value = "   " })
assert(got[#got][1] == "chat:close")
fire("change", "#input", { value = "" })
fire("keydown", "", { key = "up" })
assert(doc.values["#input"] == "hello there", "Up recalls the last line")
fire("keydown", "", { key = "down" })
assert(doc.values["#input"] == "")
fire("keydown", "", { key = "escape" })
assert(got[#got][1] == "chat:close")
-- a page taking the keyboard is reported; our own release and an alt-tab are not
local before = #got
doc.events.focus("blur", { reason = "released" }); doc.events.focus("blur", { reason = "suspended" })
assert(#got == before)
doc.events.focus("blur", { reason = "taken", by = "op77_lightrp" })
assert(got[#got][1] == "chat:focusLost")

-- close: composer emptied, hides 6 s later
page:setFocus(false, false)
page:send("chat:close", {})
assert(doc.focus == nil and doc.classes["#root.open"] == false and doc.values["#input"] == "" and doc.elementFocus == nil)
before = #got
fire("keydown", "", { key = "enter", value = "ignored" }); fire("change", "#input", { value = "ignored" })
assert(#got == before, "a closed chat ignores the keyboard")
advance(5900); assert(doc.classes["#chat.idle"] == false)
advance(200); assert(doc.classes["#chat.idle"] == true)

-- the window keeps 48 lines; clear empties it; disabled hides it
for i = 1, 60 do page:send("chat:addMessage", { text = "line " .. i }) end
assert(#doc.removed == 9 + 60 - 48 and doc.removed[1] == "@1")
page:send("chat:clear", {})
assert(doc.classes["#root.empty"] == true and doc.classes["#chat.idle"] == true)
page:send("chat:state", { enabled = false })
assert(doc.classes["#chat.disabled"] == true)
page:send("chat:state", { enabled = true })
assert(doc.classes["#chat.disabled"] == false)
page:send("chat:addTemplate", { id = "greet", template = "{0} says {1}" })
page:send("chat:addMessage", { templateId = "greet", args = { "V", "hi" } })
assert(doc.created[#doc.created].spec.rml:find("V says hi", 1, true))
page:destroy()
assert(doc.destroyed)

Open77.ui = nil
local none, why = N.create()
assert(none == nil and why == "nativeui_unavailable")
print("chat ui: normalisation, escaping, kinds, emotes, templates, segments, command index, idle, burst, open/close, paging, unread, history, focus PASS")
