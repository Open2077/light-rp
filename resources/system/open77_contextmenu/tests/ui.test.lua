-- The NativeUI surface (client/ui.lua) against a recording fake of Open77.ui.
-- Run with Lua 5.4: lua tests/ui.test.lua <resource root>   (default: the current folder)
local root = arg and arg[1] or "."
function CreateThread(fn) coroutine.wrap(fn)() end
function Wait() end

-- ---- a fake document ------------------------------------------------------------------------
local doc = { model = nil, styles = {}, classes = {}, rml = {}, sheets = {}, attrs = {}, animations = {}, keyframes = {},
    stopped = {}, shown = nil, focus = false, listeners = {}, events = {} }
local ui = {}
function ui:show() doc.shown = true end
function ui:hide() doc.shown = false end
function ui:destroy() doc.destroyed = true end
function ui:focus(options) doc.focus = true; doc.focusOptions = options; return true end
function ui:blur() doc.focus = false end
function ui:hasFocus() return doc.focus end
function ui:state() return { width = 2560, height = 1440 } end
function ui:merge(_, fields) for k, v in pairs(fields) do assert(doc.model[k] ~= nil, "unknown model name " .. k); doc.model[k] = v end end
function ui:set(_, k, v) assert(doc.model[k] ~= nil, "unknown model name " .. k); doc.model[k] = v end
function ui:style(sel, spec) doc.styles[sel] = doc.styles[sel] or {}; for k, v in pairs(spec) do doc.styles[sel][k] = v end end
function ui:class(sel, name, on) doc.classes[sel .. "." .. name] = on end
function ui:rml(sel, text) doc.rml[sel] = text end
function ui:attr(sel, name, value) doc.attrs[sel .. "@" .. name] = value end
function ui:stylesheet(name, text) doc.sheets[name] = text end
function ui:animate(sel) doc.animations[#doc.animations + 1] = sel end
function ui:keyframes(sel) doc.keyframes[#doc.keyframes + 1] = sel end
function ui:stop(sel) doc.stopped[#doc.stopped + 1] = sel end
function ui:scrollTo() end
function ui:on(kind, sel, fn) if fn == nil then fn, sel = sel, "" end; doc.listeners[kind .. "|" .. sel] = fn end
function ui:onEvent(kind, fn) doc.events[kind] = fn end
local function fire(kind, sel, e) return doc.listeners[kind .. "|" .. (sel or "")](e or {}) end
local fonts = {}

Open77 = { ui = {
    create = function(spec)
        assert(spec.document == "ui/contextmenu.rml" and spec.layer == "hud")
        doc.model = spec.models.cm
        return ui
    end,
    loadFont = function(_, family) fonts[#fonts + 1] = family; return true end,
} }

dofile(root .. "/client/ui.lua")
local M = ContextMenuUi

-- ---- pure helpers -----------------------------------------------------------------------------
assert(M.escape('<b>"A&B"</b> {{x}}') == '&lt;b&gt;&quot;A&amp;B&quot;&lt;/b&gt; { { x } }', M.escape('<b>"A&B"</b> {{x}}'))
assert(M.safeColor("#ABCDEF") == "#ABCDEF" and M.safeColor("red") == "#FFCC00", "the Light RP accent is the default")
local theme = M.theme("#ff0000")
assert(theme:find("#head .np-cut { fill: #ff0000; }", 1, true) and theme:find("#eye.available #hex { fill: #ff00001F; }", 1, true)
    and theme:find("#sheet { border-color: #ff000047; }", 1, true))
assert(M.scaleSheet(1) == "" and M.scaleSheet(1.5):find("#menu { width: 378.0dp; }", 1, true) and M.scaleSheet(1.5):find("#eye { width: 60.0dp;", 1, true))
-- the header: what was hit and how far
local d = M.describeTarget({ kind = "player", playerId = 7 }, 3.25)
assert(d.head == "PLAYER" and d.tag == "ID 007 // 3.2M", d.tag)
assert(M.describeTarget({ kind = "player", isLocalPlayer = true, playerId = 7 }).head == "YOU" and M.describeTarget({ kind = "player", isLocalPlayer = true, playerId = 7 }).tag == "")
d = M.describeTarget({ kind = "vehicle", vehicleId = "18446744073709550042" }, 42.6)
assert(d.head == "VEHICLE" and d.tag == "#0042 // 43M", d.tag)
d = M.describeTarget({ kind = "npc", npcId = 123456, record = "Character.judy_alvarez_default" })
assert(d.head == "JUDY ALVAREZ DEFAULT" and d.tag == "#3456", d.head)
assert(M.describeTarget({ kind = "sky" }).head == "SKY" and M.describeTarget({ kind = "sky" }).tag == "" and M.describeTarget(nil).head == "WORLD")
assert(M.describeTarget({ kind = "Cabinet", propId = "9" }, 0 / 0).head == "CABINET")
-- folders: one row per folder at the root, Back and the folder's rows inside
local actions = {
    { token = "a", label = "Open <door>", icon = "lock", group = "World" },
    { token = "b", label = "Open trunk", submenu = { id = "lightrp/cargo", label = "Trunk & hood", icon = "vehicle" }, group = "Vehicle" },
    { token = "c", label = "Open hood", description = "Lift it", submenu = { id = "lightrp/cargo", label = "Trunk & hood", icon = "vehicle" } },
    { token = "d", label = "Kick", danger = true, description = "Remove them", group = "Admin" },
}
local entries, folder = M.entries(actions, nil)
assert(folder == nil and #entries == 3 and entries[2].folder == "lightrp/cargo" and entries[2].label == "Trunk & hood" and entries[2].token == nil)
assert(entries[3].danger and entries[3].description == "Remove them")
local inside, shown = M.entries(actions, "lightrp/cargo")
assert(shown.label == "Trunk & hood" and #inside == 3 and inside[1].back and inside[2].token == "b" and inside[3].token == "c")
assert(select(2, M.entries(actions, "other/cargo")) == nil, "an unknown folder falls back to the root")
local rml, groups = M.rowsRml(entries, true)
assert(groups == 3 and select(2, rml:gsub('class="grp"', "")) == 3)
assert(rml:find('class="row" id="r1"', 1, true) and rml:find("Open &lt;door&gt;", 1, true) and rml:find('class="row folder" id="r2"', 1, true)
    and rml:find('class="arrow"', 1, true) and rml:find('class="row danger" id="r3"', 1, true))
assert(select(2, M.rowsRml(entries, false)) == 0 and M.rowsRml(inside, false):find('class="row back" id="r1"', 1, true))
assert(M.legendRml("rows", "ALT"):find("HOLD [ALT]", 1, true) and M.legendRml("rows", "ALT"):find("ENTER", 1, true))
assert(M.legendRml("folder", "ALT"):find("BACK", 1, true) and M.legendRml("none", "F"):find("PICK ANOTHER TARGET", 1, true) and M.legendRml("open", "<x>"):find("HOLD [&lt;x&gt;]", 1, true))
-- the eye centred on the anchor; the column to its right, flipped near the right edge, never below the screen
local p = M.place(0.25, 0.4, 1920, 1080, 1, 200)
assert(not p.flipped and p.eyeLeft == 460 and p.eyeTop == 412 and p.left == 480 + 20 + 10 and p.top == 412)
p = M.place(0.95, 0.5, 1920, 1080, 1, 200)
assert(p.flipped and p.left == 1824 - 20 - 10 - 252)
p = M.place(0.5, 0.99, 1920, 1080, 1, 400)
assert(p.top == 1080 - 400 - 8 and p.eyeTop == 1080 - 40 - 8)
p = M.place(0, 0, 2560, 1440, 1.5, 100)
assert(p.eyeLeft == 11 and p.left == 0 + 40 + 20, "a 1440p screen and the configured scale")
assert(M.menuHeight(3, 0, false, false) == 25 + 8 + 96 + 23)

-- ---- the surface ------------------------------------------------------------------------------
local page = assert(M.create({ appearance = { accentColor = "#FFCC00", scale = 1 } }))
assert(fonts[1] == "Share Tech Mono")
local got = {}
for _, name in ipairs({ "context:ready", "context:pick", "context:select", "context:cancel", "context:blur" }) do
    page:on(name, function(payload) got[#got + 1] = { name, payload } end)
end
doc.events.loaded()
assert(got[1][1] == "context:ready" and doc.shown == false and doc.sheets.accent:find("#FFCC00", 1, true) and doc.sheets.scale == "")

page:send("context:open", { epoch = 4, key = "alt", appearance = { accentColor = "#FFCC00" } })
assert(doc.shown and not doc.model.shown and doc.rml["#rows"] == "")
assert(doc.styles["#eye"].left == (1280 - 27) .. "px" and doc.styles["#eye"].top == (720 - 27) .. "px", "the lease starts at the centre")
assert(page:setFocus(true, true) and page:hasFocus() and doc.focusOptions.cursor == true)

-- the eye follows the pointer until a pick shows the column
fire("mousemove", "#hit", { mouse_x = 1000, mouse_y = 500 })
assert(doc.styles["#eye"].left == (1000 - 27) .. "px")
fire("click", "#hit", { mouse_x = 640, mouse_y = 360 })
local pick = got[#got]
assert(pick[1] == "context:pick" and pick[2].epoch == 4 and pick[2].x == 0.25 and pick[2].y == 0.25, "the event's coordinates")
page:send("context:loading", { epoch = 5, x = 0.25, y = 0.25 })
assert(doc.model.shown and doc.model.title == "SCANNING" and doc.model.status == "Looking…" and doc.model.statusLoading and doc.model.glyph == M.ICONS.scan)
assert(doc.rml["#legend"] == "<span>HOLD [ALT]</span>" and doc.keyframes[1] == "#status-spin .spin" and doc.animations[1] == "#menu")
fire("mousemove", "#hit", { mouse_x = 10, mouse_y = 10 })
assert(doc.styles["#eye"].left == (640 - 27) .. "px", "the eye stays on the pick")
assert(doc.styles["#menu"].left == math.floor(640 + 30 * 1440 / 1080 + 0.5) .. "px")
-- while the target is looked up a click does nothing
local before = #got
fire("click", "#hit", { mouse_x = 1, mouse_y = 1 })
assert(#got == before)

page:send("context:menu", { epoch = 5, target = { kind = "vehicle", vehicleId = 10 }, distance = 4, actions = actions })
assert(doc.model.available and not doc.model.statusLoading and doc.model.title == "VEHICLE" and doc.model.tag == "#10 // 4.0M" and doc.model.glyph == M.ICONS.eye)
assert(doc.rml["#rows"]:find('id="r3"', 1, true) and not doc.rml["#rows"]:find("grp", 1, true) and doc.rml["#legend"]:find("ENTER", 1, true))
assert(doc.stopped[#doc.stopped] == "#status-spin .spin" and not doc.model.hasStatus)
-- mouse hover and keyboard share one highlight; the description follows it
fire("mouseover", ".row", { id = "r3" })
assert(doc.classes["#r3.focus"] and doc.model.desc == "Remove them" and doc.model.hasDesc and not doc.model.keyboard)
fire("keydown", "", { key = "down" })
assert(doc.classes["#r1.focus"] and not doc.classes["#r3.focus"] and doc.model.desc == "" and doc.model.keyboard)
fire("keydown", "", { key = "end" }); assert(doc.classes["#r3.focus"])
fire("keydown", "", { key = "up" }); assert(doc.classes["#r2.focus"])
-- a folder opens with Right (or Enter, or a click) and never selects
before = #got
fire("keydown", "", { key = "right" })
assert(#got == before and doc.model.title == "Trunk & hood" and doc.model.submenu and doc.rml["#rows"]:find("Back", 1, true))
assert(doc.classes["#r2.focus"], "the keyboard lands on the first action, not Back")
assert(doc.rml["#legend"]:find("BACK", 1, true))
fire("keydown", "", { key = "down" })
assert(doc.model.desc == "Lift it")
fire("keydown", "", { key = "enter" })
assert(got[#got][1] == "context:select" and got[#got][2].token == "c" and got[#got][2].epoch == 5 and doc.model.busy)
-- busy: no more picks, selections or navigation until it settles
page:send("context:busy", { epoch = 5, token = "c" })
assert(doc.classes["#r3.pending"] and doc.keyframes[#doc.keyframes] == "#r3 .spin")
before = #got
fire("click", "#hit", { mouse_x = 1, mouse_y = 1 }); fire("click", ".row", { id = "r2" }); fire("keydown", "", { key = "left" }); fire("mousedown", "", { button = 1 })
assert(#got == before and doc.model.submenu, "busy ignores picks, selections, Back and the right click")
page:send("context:error", { epoch = 5, message = "This action is no longer available." })
assert(not doc.model.busy and doc.model.statusError and doc.model.status == "Action unavailable" and doc.model.blocked
    and doc.model.desc == "This action is no longer available." and doc.classes["#r3.pending"] == false and doc.attrs["#r3 .gl@d"] == M.ICONS.info)
-- back: Left, Backspace, the Back row or the right click; the folder keeps the highlight
fire("mousedown", "", { button = 1 })
assert(not doc.model.submenu and doc.model.title == "VEHICLE" and doc.classes["#r2.focus"] and #got == before)
fire("click", ".row", { id = "r2" })
assert(doc.model.submenu)
fire("click", ".row", { id = "r1" })
assert(not doc.model.submenu, "the Back row")
fire("click", ".row", { id = "r1" })
assert(got[#got][2].token == "a")
page:send("context:error", { epoch = 5 })
assert(doc.model.desc == "Try again.")
-- a stale epoch changes nothing
page:send("context:menu", { epoch = 3, actions = {} })
assert(doc.model.available)
-- a dynamic-rows provider names the target; no row at all says so
page:send("context:menu", { epoch = 5, target = { kind = "prop" }, title = "Roulette", actions = { { token = "s", label = "Spin" } } })
assert(doc.model.title == "ROULETTE")
page:send("context:menu", { epoch = 5, target = { kind = "world" }, actions = {} })
assert(not doc.model.available and doc.model.status == "No actions" and doc.model.glyph == M.ICONS.ban and doc.rml["#legend"]:find("PICK ANOTHER TARGET", 1, true))
page:send("context:empty", { epoch = 5, message = "player_not_ready" })
assert(doc.model.title == "NO TARGET" and doc.model.status == "No target" and doc.model.blocked and doc.model.desc == "player_not_ready")
-- a click outside the column picks again; right click (at the root) and Escape cancel
fire("click", "#hit", { mouse_x = 1280, mouse_y = 720 })
assert(got[#got][1] == "context:pick" and got[#got][2].x == 0.5)
fire("mousedown", "", { button = 1 }); assert(got[#got][1] == "context:cancel" and got[#got][2].epoch == 5)
fire("mousedown", "", { button = 0 }); fire("keydown", "", { key = "escape" }); assert(got[#got][1] == "context:cancel")
-- the lease taken by someone else is reported; nothing else closes the menu
doc.events.focus("blur", { reason = "taken" }); assert(got[#got][1] == "context:blur" and got[#got][2] == "taken")
doc.events.error("focus", { message = "focus_unavailable" }); assert(got[#got][2] == "focus_unavailable")

-- close hides at once, as the page did
page:setFocus(false, false)
page:send("context:close", {})
page:hide()
assert(doc.shown == false and doc.model.shown == false and doc.rml["#rows"] == "")
before = #got
fire("click", "#hit", { mouse_x = 5, mouse_y = 5 }); fire("keydown", "", { key = "escape" }); doc.events.focus("blur", { reason = "released" })
assert(#got == before, "events after close do nothing")
-- the configured appearance: group headings, another accent and scale
page:send("context:open", { epoch = 9, key = "f", appearance = { accentColor = "#00FF88", scale = 1.25, showGroups = true } })
assert(doc.sheets.accent:find("#00FF88", 1, true) and doc.sheets.scale:find("#menu { width: 315.0dp; }", 1, true))
page:send("context:loading", { epoch = 9, x = 0.5, y = 0.5 })
page:send("context:menu", { epoch = 9, target = { kind = "world" }, actions = actions })
assert(doc.rml["#rows"]:find('class="grp"', 1, true) and doc.rml["#legend"]:find("HOLD [F]", 1, true))
-- a reloaded document while open asks main.lua to close
doc.events.reloaded(); assert(got[#got][1] == "context:blur" and got[#got][2] == "reloaded")
page:destroy(); assert(doc.destroyed)

Open77.ui = nil
local none, why = M.create({})
assert(none == nil and why == "nativeui_unavailable")
print("contextmenu ui: escaping, header, folders, placement, theme, pointer, pick, rows, keyboard, busy, errors, blur and close PASS")
