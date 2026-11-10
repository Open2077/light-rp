-- The bubbles as a NativeUI document (ui/actionbubble.rml): what the former WebUI page's script did, in Lua.
-- Two feeds, as the page had:
--   - V.send("ab:add" | "ab:update" | "ab:anchor" | "ab:remove", payload) from
--     client/main.lua: what each bubble says and which anchor carries it (elements);
--   - V.frame(), every game frame while a bubble lives: where each anchor is on screen
--     (Open77.anchors.frame(), projected by the plugin). NativeUI anchors only follow
--     <scene3d> points, so the bubbles are placed here: one ui:batch per frame, only the
--     values that changed, transforms and opacity only (nothing is laid out again).
-- A bubble plays its entrance the first time its anchor is on screen. The entrance and the
-- exit are RCSS animations (classes is-in / is-out); the float of the card, its duration
-- bar and the sheen are native motion (ui:keyframes / ui:animate), started once; the text
-- resolving out of glitch characters is written here for the half second it lasts.
ActionBubbleView = {}
local V = ActionBubbleView

local ui, loaded = nil, false
local bubbles = {}                  -- id -> state
local list = {}                     -- states, oldest first: bubbles on one target stack upward
local byAnchor = {}                 -- anchor id -> this frame's projection
local stacks = {}                   -- group -> height stacked so far this frame
-- The screen in dp (1 dp = 1 px of a 1080-line screen): 1920 x 1080 on 16:9.
local screen = { w = 1920, h = 1080, ratio = 1 }
local suppressed, hideUnderMenus = false, true
local seq, nextBusy, nextScreen = 0, 0, 0
local warned = {}

-- The HUD lab (tools/native-lab): its driver sets Op77UiLab before this script loads. The
-- document then goes on the lab's layer (above the pre-game shell, which holds the cursor)
-- and does not step aside under a captured cursor. Absent in game: nothing changes.
local LAB = type(Op77UiLab) == "table" and Op77UiLab or nil
-- Lab hook: V.anchorSource = function() return { { id, projected, onScreen, x, y, distance }, ... } end
-- answers in place of Open77.anchors.frame() (no world in the lab, so no anchor resolves).

local fmt, floor, abs, min, max = string.format, math.floor, math.abs, math.min, math.max
local function clamp(v, a, b) return max(a, min(b, v)) end
local function now() return Open77.time.monotonic() end
local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print("[actionbubble] " .. text)
end
local function safeColor(v)
    v = tostring(v or "")
    return v:match("^#%x%x%x%x%x%x$") and v or "#FFCC00"
end
-- Text from players as RML: markup escaped, and the braces too ("{{" opens a data binding
-- in RmlUi, even in a document without a model, and the whole text is then refused). The
-- host's own ui:text escapes < > & " but not braces, so player text never goes through it.
local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["{"] = "&#x7B;", ["}"] = "&#x7D;" }
local function esc(text) return (tostring(text):gsub('[&<>"{}]', ESC)) end
V.esc = esc
-- The characters of a text (UTF-8), for the typing.
local function chars(text)
    local out = {}
    for c in tostring(text):gmatch("[\0-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
    return out
end

-- Stroke icons (24 px grid), as the page drew them; circles and rects become path data.
local function num(v) return (fmt("%.3f", v):gsub("0+$", ""):gsub("%.$", "")) end
local function circle(cx, cy, r)
    return fmt("M%s %sa%s %s 0 1 0 %s 0a%s %s 0 1 0 %s 0z", num(cx - r), num(cy), num(r), num(r), num(2 * r), num(r), num(r), num(-2 * r))
end
local function rect(x, y, w, h, rx)
    local a, ww, hh = num(rx), num(w - 2 * rx), num(h - 2 * rx)
    return fmt("M%s %sh%sa%s %s 0 0 1 %s %sv%sa%s %s 0 0 1 -%s %sh-%sa%s %s 0 0 1 -%s -%sv-%sa%s %s 0 0 1 %s -%sz",
        num(x + rx), num(y), ww, a, a, a, a, hh, a, a, a, a, ww, a, a, a, a, hh, a, a, a, a)
end
local ICONS = {
    hand = "M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 11V4.5a1.5 1.5 0 0 1 3 0V12M14 11.5V6a1.5 1.5 0 0 1 3 0v8c0 4-2.5 7-6.5 7S5 18.5 4 16l-1.6-3.6a1.4 1.4 0 0 1 2.4-1.4L8 15",
    key = circle(8, 15, 4) .. "M11 12l9-9M17 6l3 3M14 9l2 2",
    lock = rect(5, 11, 14, 10, 1) .. "M8 11V7a4 4 0 0 1 8 0v4",
    unlock = rect(5, 11, 14, 10, 1) .. "M8 11V7a4 4 0 0 1 7.5-2",
    box = "M3 7l9-4 9 4v10l-9 4-9-4zM3 7l9 4 9-4M12 11v10",
    trunk = "M3 15h18v5H3zM5 15l2-6h10l2 6M9 18h6",
    car = "M3 16v-4l2-5h14l2 5v4z" .. circle(7.5, 16.5, 1.8) .. circle(16.5, 16.5, 1.8) .. "M5 12h14",
    door = "M6 21V3h12v18M3 21h18" .. circle(14.5, 12, 0.8),
    eye = "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" .. circle(12, 12, 3),
    chat = "M4 5h16v11H9l-5 4z",
    alert = "M12 3l10 18H2zM12 10v5M12 18h.01",
    search = circle(10.5, 10.5, 6.5) .. "M15.5 15.5L21 21",
    wrench = "M14.5 6.5a4.5 4.5 0 0 0 5.6 5.6L12 20.2a2.1 2.1 0 0 1-3-3l8.1-8.1M14.5 6.5L17 4",
    phone = rect(7, 2, 10, 20, 2) .. "M11 18h2",
    cash = rect(2, 6, 20, 12, 1) .. circle(12, 12, 3),
    heart = "M12 20s-8-4.6-8-10.2A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 8 2.8C20 15.4 12 20 12 20z",
    gear = circle(12, 12, 3) .. "M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1",
}
V.ICONS = ICONS
local GLYPHS = chars("!<>-_\\/[]{}=+*^?#%&$@0123456789ABCDEFXZ")

-- ---------------------------------------------------------------------------------------
-- Building a bubble.
-- ---------------------------------------------------------------------------------------

-- The card's size before the document has measured it (ui:rect, a frame or two later).
local function estimate(s)
    local d = s.def
    local w = #s.chars * 8.4 + 25 + (ICONS[d.icon] and 20 or 0) + (d.asterisks == true and 22 or 0)
    local lines = max(1, math.ceil(w / 340))
    s.w, s.h = min(340, w) + 1, 16 + lines * 18.75
end

local function classes(s)
    return "ab" .. (s.def.asterisks == true and " has-asterisks" or "")
        .. (not ((tonumber(s.def.remaining) or 0) > 0) and " is-infinite" or "")
        .. (s.entered and " is-on" or "") .. (s.left and " is-left" or "")
end

-- A sine as nine linear stops, from a phase: the card's float starts anywhere in its cycle.
local function wave(amplitude, phase)
    local stops = {}
    for i = 0, 8 do
        stops[#stops + 1] = { offset = i / 8, value = amplitude * math.sin(phase + 2 * math.pi * i / 8), easing = "linear" }
    end
    return stops
end

-- The duration bar: full to empty over `seconds`, after `delay` (ab-timer).
local function restartTimer(s, seconds, delay, from)
    if not (seconds > 0) then return end
    s.timer = { total = from and s.timer and s.timer.total or seconds, ends = now() + delay + seconds }
    ui:animate(s.tbar, { from = { scaleX = from or 1 }, to = { scaleX = 0 }, duration = seconds, easing = "linear", delay = delay })
end

-- Text resolves left to right out of random glyphs.
local function scramble(s, delay)
    local n = #s.chars
    s.typed = { start = now() + delay, per = clamp(520 / max(1, n), 9, 24) / 1000, last = -1 }
    ui:rml(s.type, "")
end

-- A chamfered glass plate (cut top-right and bottom-left, 9 px): a fill and a 1 px line as
-- decorators, in physical pixels (scaled like a dp). The alphas fold a layer's opacity into
-- its colours: RmlUi does not multiply opacity down the tree, so nothing under the faded
-- .ab-fade sets an opacity of its own.
local function plate(fill, fillAlpha, line, lineAlpha)
    local r = screen.ratio
    return fmt("fx(chamfer-solid %.2f 0 0 0 %s%02x), fx(chamfer %.2f %.2f 0.001 0 %s%02x)",
        9 * r, fill, floor(fillAlpha * 255 + 0.5), 9 * r, r, line, floor(lineAlpha * 255 + 0.5))
end

-- The ring around the pin (ab-ring: 1.6 s ease-out, infinite, after 180 ms): grows from 0.4
-- to 1.6 and fades from 90 %, as motion keyframes on its colour (an opacity would not take
-- the distance fade).
local function ring(s, on)
    if on then
        ui:keyframes(s.ring, { channel = "scale", duration = 1.6, iterations = -1, delay = 0.18,
            stops = { { offset = 0, value = 0.4, easing = "ease-out" }, { offset = 1, value = 1.6 } } })
        ui:keyframes(s.ring, { channel = "border-color", duration = 1.6, iterations = -1, delay = 0.18,
            stops = { { offset = 0, value = s.accent .. "e6", easing = "ease-out" }, { offset = 1, value = s.accent .. "00" } } })
    else
        ui:stop(s.ring)
        ui:style(s.ring, "border-color", s.accent .. "00")
    end
end

-- One bubble's elements. Inside a ui:batch. An entered bubble (rebuilt after a resolution
-- change, a reload or a new accent) comes back as it stands, without its entrance.
local function build(s)
    local d = s.def
    local A = safeColor(d.accent)
    s.accent = A
    s.el = ui:create("#bubbles", { tag = "div", class = classes(s), style = { display = "none" } })
    s.wrap = ui:create(s.el, { tag = "div", class = "ab-fade", style = { opacity = "0" } })
    local glow3 = "background-color: " .. A .. "; box-shadow: " .. A .. " 0dp 0dp 3dp 0dp;"
    s.la = ui:create(s.wrap, { tag = "div", class = "ab-la", rml = '<div class="ab-lf ab-lf-a" style="' .. glow3 .. '"></div>' })
    s.lb = ui:create(s.wrap, { tag = "div", class = "ab-lb", rml = '<div class="ab-lf ab-lf-b" style="' .. glow3 .. '"></div>' })
    s.dot = ui:create(s.wrap, { tag = "div", class = "ab-dot", rml = '<div class="ab-dot-in" style="background-color: ' .. A .. ';"></div>' })
    s.pin = ui:create(s.wrap, { tag = "div", class = "ab-pin" })
    s.ring = ui:create(s.pin, { tag = "div", class = "ab-ring", style = { ["border-color"] = A .. "00" } })
    ui:create(s.pin, { tag = "div", class = "ab-dia", style = { ["background-color"] = A,
        ["box-shadow"] = A .. " 0dp 0dp 10dp 0dp, #000000 0dp 0dp 2dp 0dp" } })
    s.rig = ui:create(s.wrap, { tag = "div", class = "ab-rig" })
    local hold = ui:create(s.rig, { tag = "div", class = "ab-hold" })
    local card = ui:create(hold, { tag = "div", class = "ab-card" })
    s.float = ui:create(card, { tag = "div", class = "ab-float" })
    -- glass thickness: three layers behind the face, at 18 / 30 / 50 % (the page's opacities)
    local slabs = ""
    for i, op in ipairs({ 0.18, 0.3, 0.5 }) do
        slabs = slabs .. '<div class="ab-slab ab-slab-' .. i .. '" style="decorator: ' .. plate("#000000", 0.55 * op, A, op) .. ';"></div>'
    end
    s.body = ui:create(s.float, { tag = "div", class = "ab-body", rml = slabs })
    s.face = ui:create(s.body, { tag = "div", class = "ab-face",
        rml = '<div class="ab-plate" style="decorator: ' .. plate("#09090c", 0.84, A, 1) .. ';"></div>' })
    -- the tint, the scanlines and the sheen, inside the border, the bottom-left cut masked
    local fx = ui:create(s.face, { tag = "div", class = "ab-fx", style = {
        decorator = "linear-gradient(100deg, " .. A .. "24 0%, " .. A .. "00 38%), "
            .. "repeating-linear-gradient(0deg, #ffffff09 0dp, #ffffff09 1dp, #ffffff00 1dp, #ffffff00 3dp)" } })
    s.sheen = ui:create(fx, { tag = "div", class = "ab-sheen", style = {
        decorator = "linear-gradient(100deg, " .. A .. "00 0%, " .. A .. "59 50%, " .. A .. "00 100%)" } })
    -- one row: the icon, *, the text (it wraps in its own column), *
    local starStyle = "color: " .. A .. "; font-effect: glow(0dp 5dp 0dp 0dp " .. A .. ");"
    local icon = ICONS[d.icon] and ('<path class="ab-icon" view-box="0 0 24 24" d="' .. ICONS[d.icon] .. '" style="stroke: ' .. A .. ';"/>') or ""
    local text = ui:create(s.face, { tag = "div", class = "ab-text",
        rml = icon .. '<span class="ab-star ab-star-a" style="' .. starStyle .. '">*</span>' })
    local t = ui:create(text, { tag = "div", class = "ab-t" })
    -- the whole line, unseen, gives the card its size; the typing is drawn over it
    s.sizer = ui:create(t, { tag = "span", class = "ab-sizer", rml = esc(d.text) })
    s.type = ui:create(t, { tag = "div", class = "ab-type", rml = (s.entered and not s.typed) and esc(d.text) or "" })
    ui:create(text, { tag = "span", class = "ab-star ab-star-b", rml = "*", style = { color = A, ["font-effect"] = "glow(0dp 5dp 0dp 0dp " .. A .. ")" } })
    local timer = ui:create(s.face, { tag = "div", class = "ab-timer" })
    s.tbar = ui:create(timer, { tag = "div", class = "ab-tbar",
        style = { ["background-color"] = A, ["box-shadow"] = A .. " 0dp 0dp 6dp 0dp" } })
    ui:create(s.body, { tag = "div", class = "ab-corner ab-corner-tl", style = { ["border-color"] = A } })
    ui:create(s.body, { tag = "div", class = "ab-corner ab-corner-br", style = { ["border-color"] = A } })
    ui:watch(s.face)
    -- the card floats (bob 3 px, sway 2.2 degrees), even when the camera stands still
    ui:keyframes(s.float, { channel = "y", stops = wave(3 * screen.ratio, s.phase), duration = 2 * math.pi / 1.7, iterations = -1 })
    ui:keyframes(s.float, { channel = "rotateY", stops = wave(2.2, s.phase), duration = 2 * math.pi / 0.9, iterations = -1 })
    if s.entered and not s.leaving then ring(s, true) end
    if s.entered and s.timer then
        local left = s.timer.ends - now()
        if left > 0 then restartTimer(s, left, 0, clamp(left / s.timer.total, 0, 1)) else ui:style(s.tbar, "transform", "scaleX(0)") end
    end
    -- nothing written yet: the next frame sends every value
    s.sent, s.last, s.shown, s.display, s.hideAt = {}, nil, false, false, nil
    s.show, s.fade, s.op = 0, 1, 0
    s.measureAt, s.measureFast = 0, now() + 0.6
end

local function unlist(s)
    bubbles[s.id] = nil
    for i, other in ipairs(list) do if other == s then table.remove(list, i) break end end
end

local function destroy(s)
    unlist(s)
    if ui and loaded and s.el then
        ui:unwatch(s.face)
        ui:remove(s.el)
    end
end

local function rebuild(s)
    if s.el then ui:unwatch(s.face); ui:remove(s.el) end
    build(s)
end

local function rebuildAll()
    if not ui or not loaded then return end
    ui:batch(function() for _, s in ipairs(list) do rebuild(s) end end)
end

local function fill(s, def)
    local old = s.def
    local changed = old.text ~= def.text
    local restyle = safeColor(old.accent) ~= safeColor(def.accent) or (ICONS[old.icon] and old.icon) ~= (ICONS[def.icon] and def.icon)
    s.def = def
    if changed then s.chars = chars(def.text) end
    if not (ui and loaded and s.el) then return end
    local remaining = tonumber(def.remaining) or 0
    ui:batch(function()
        if restyle then
            rebuild(s)
        else
            ui:class(s.el, "has-asterisks", def.asterisks == true)
            ui:class(s.el, "is-infinite", not (remaining > 0))
            if changed then ui:rml(s.sizer, esc(def.text)) end
        end
        if changed then
            if s.entered then scramble(s, 0) else ui:rml(s.type, "") end
            s.measureAt, s.measureFast = 0, now() + 0.6
        end
        if remaining > 0 and s.entered then restartTimer(s, remaining, 0) end
    end)
end

local function enter(s)
    s.entered, s.enteredAt, s.stage = true, now(), 0
    ui:class(s.el, "is-on", true)
    ui:class(s.el, "is-in", true)
    ring(s, true)
    scramble(s, 0.56)
    local remaining = tonumber(s.def.remaining) or 0
    if remaining > 0 then restartTimer(s, remaining - 0.75 > 0.5 and remaining - 0.75 or remaining, 0.75) end
    -- the sheen: a band 30 % of the card wide, from -40 % to 120 %, 700 ms after 620 ms
    ui:style(s.sheen, { left = fmt("%.1fdp", -0.4 * s.w), width = fmt("%.1fdp", 0.3 * s.w) })
    ui:animate(s.sheen, { from = { x = 0, opacity = 1, skewX = -18 }, to = { x = 1.6 * s.w * screen.ratio, opacity = 0, skewX = -18 },
        duration = 0.7, easing = "ease-out", delay = 0.62 })
end

local function leave(s, instant)
    if s.leaving then return end
    s.leaving = true
    if instant or not s.entered or not (ui and loaded and s.el) then destroy(s) return end
    ui:batch(function()
        ui:class(s.el, "is-in", false)
        ui:class(s.el, "is-out", true)
        ring(s, false)
    end)
    s.removeAt = now() + 0.72
end

local handlers = {}
handlers["ab:add"] = function(def)
    if type(def) ~= "table" or type(def.id) ~= "string" then return end
    local old = bubbles[def.id]
    if old then destroy(old) end
    seq = seq + 1
    local s = { id = def.id, def = def, chars = chars(def.text), phase = math.random() * 6.28, entered = false, leaving = false, seq = seq, sent = {} }
    estimate(s)
    bubbles[def.id] = s
    list[#list + 1] = s
    if ui and loaded then ui:batch(function() build(s) end) end
end
handlers["ab:update"] = function(def)
    local s = type(def) == "table" and bubbles[def.id]
    if s and not s.leaving then fill(s, def) end
end
handlers["ab:anchor"] = function(msg)
    local s = type(msg) == "table" and bubbles[msg.id]
    if s then s.def.anchor = msg.anchor or false end
end
handlers["ab:remove"] = function(msg)
    local s = type(msg) == "table" and bubbles[msg.id]
    if s then leave(s, msg.instant == true) end
end

--- The feed from client/main.lua (the page's messages, same names and payloads).
function V.send(_, name, payload)
    local handler = handlers[name]
    if handler then handler(payload) end
end

-- ---------------------------------------------------------------------------------------
-- The frame.
-- ---------------------------------------------------------------------------------------

-- What the plugin projected on its last frame: { id, projected, onScreen, x, y, distance }.
local function readAnchors()
    for key in pairs(byAnchor) do byAnchor[key] = nil end
    local read = V.anchorSource
    if type(read) ~= "function" then
        local anchors = Open77.anchors
        read = type(anchors) == "table" and (type(anchors.frame) == "function" and anchors.frame or anchors.list)
    end
    if type(read) ~= "function" then return end
    local ok, frame = pcall(read)
    if not ok or type(frame) ~= "table" then return end
    for _, a in ipairs(frame) do byAnchor[tostring(a.id)] = a end
end

-- NativeUI draws over every WebUI page: while another interface holds the cursor (an
-- inventory, a menu, the phone) the bubbles step aside, as they sat under those pages before.
-- op77_loadscreen's zone cover is a WebUI page, below every NativeUI document: step aside
-- while it is up (it sends op77_loadscreen:state; nothing happens without that resource).
local loadCovered = false
if type(AddEventHandler) == "function" then
    AddEventHandler("op77_loadscreen:state", function(active) loadCovered = active == true end)
end
local function cursorTaken()
    if loadCovered and not (LAB and LAB.ignoreCapture == true) then return true end
    if not hideUnderMenus or (LAB and LAB.ignoreCapture == true) then return false end
    if type(Open77.input) ~= "table" or type(Open77.input.isCaptured) ~= "function" then return false end
    local ok, _, cursor = pcall(Open77.input.isCaptured)
    return ok and cursor == true
end

local function readScreen()
    local ok, state = pcall(ui.state, ui)
    if not ok or type(state) ~= "table" then return end
    local w, h = tonumber(state.width), tonumber(state.height)
    if not w or not h or w < 1 or h < 1 then return end
    local ratio = max(0.5, h / 1080)
    local changed = abs(ratio - screen.ratio) > 0.001
    screen.w, screen.h, screen.ratio = w / ratio, h / ratio, ratio
    if changed then rebuildAll() end
end

-- The card's laid out size (transforms do not change it), in dp.
local function measure(s, t)
    if t < s.measureAt then return end
    s.measureAt = t + (t < s.measureFast and 0.05 or 0.5)
    local ok, r = pcall(ui.rect, ui, s.face)
    if ok and type(r) == "table" and (tonumber(r.width) or 0) > 1 and (tonumber(r.height) or 0) > 1 then
        s.w, s.h = r.width / screen.ratio + 1, r.height / screen.ratio
    end
end

local function put(s, key, selector, property, value)
    if s.sent[key] == value then return end
    s.sent[key] = value
    ui:style(selector, property, value)
end

local function place(s, a, d)
    local vw = screen.w
    local x, y = a.x * vw, a.y * screen.h
    local k = clamp(8 / (d + 3), 0.75, 1.0)
    local maxD = tonumber(s.def.maxDistance) or 25
    local fade = 1 - clamp((d - maxD * 0.75) / (maxD * 0.25), 0, 1)
    local left = s.def.side == "left" or (s.def.side ~= "right" and a.x > 0.66)
    -- where the card attaches, relative to the pin; bubbles on the same target stack upward
    -- (the first card's middle 62 above the pin, each next one 8 above the top of the one
    -- under it, whatever their heights: the page stacked by the lower card's height only,
    -- so a taller card overlapped the one under it)
    local group = s.def.group or s.id
    local below = stacks[group]
    local stack = below or 0
    local reach, rise = 50 * k, below and (below + (8 + s.h / 2) * k) or 62 * k
    stacks[group] = rise + s.h / 2 * k
    s.fade = fade
    -- nothing moved since the last frame: nothing to write
    local l = s.last
    if l and l[1] == a.x and l[2] == a.y and l[3] == d and l[4] == stack and l[5] == s.w and l[6] == s.h and l[7] == vw then return end
    l = l or {}
    l[1], l[2], l[3], l[4], l[5], l[6], l[7] = a.x, a.y, d, stack, s.w, s.h, vw
    s.last = l
    -- keep the card on screen
    local cardW, cardH = s.w * k, s.h * k
    local ax, ay = x + (left and -reach or reach), y - rise
    if not left and ax + cardW > vw - 12 then ax = vw - 12 - cardW end
    if left and ax - cardW < 12 then ax = 12 + cardW end
    if ay - cardH / 2 < 10 then ay = 10 + cardH / 2 end
    local dx, dy = ax - x, ay - y
    if left ~= s.left then s.left = left; ui:class(s.el, "is-left", left) end
    put(s, "el", s.el, "transform", fmt("translate(%.1fdp, %.1fdp)", x, y))
    put(s, "pin", s.pin, "transform", fmt("scale(%.3f)", k))
    -- the leader: a diagonal, then a short run into the card's edge (two bars 100 dp long)
    local mx = dx - (left and -28 or 28) * k
    put(s, "la", s.la, "transform", fmt("rotate(%.2fdeg) scaleX(%.4f)", math.deg(math.atan(dy, mx)), math.sqrt(mx * mx + dy * dy) / 100))
    put(s, "lb", s.lb, "transform", fmt("translate(%.1fdp, %.1fdp) scaleX(%.4f)", mx, dy, (dx - mx) / 100))
    put(s, "dot", s.dot, "transform", fmt("translate(%.1fdp, %.1fdp)", dx, dy))
    -- the card: scaled, turned toward the screen centre
    put(s, "rig", s.rig, "transform", fmt("translate(%.1fdp, %.1fdp) scale(%.3f)", dx, dy - cardH / 2, k))
    local turn = (left and 16 or -16) + (a.x - 0.5) * -22
    local tilt = 7 + (a.y - 0.5) * -10
    put(s, "pose", s.body, "transform", fmt("rotateY(%.1fdeg) rotateX(%.1fdeg)", turn, tilt))
end

-- What time does to a bubble, seen or not: the glitch, the typing, the end of its entrance,
-- its removal. Returns true when the bubble is to be destroyed.
local function tick(s, t)
    if s.enteredAt and s.stage then
        -- ab-glitch: two steps of 130 ms from 640 ms (the card jumps 3 px left, 2 px right)
        local age = t - s.enteredAt
        local stage = age >= 1.5 and 4 or age >= 0.9 and 3 or age >= 0.77 and 2 or age >= 0.64 and 1 or 0
        if stage ~= s.stage then
            s.stage = stage
            if stage == 1 or stage == 2 or stage == 3 then
                ui:class(s.face, "g1", stage == 1)
                ui:class(s.face, "g2", stage == 2)
            elseif stage == 4 then
                -- the entrance is over: a later change of side must not replay it
                ui:class(s.face, "g1", false); ui:class(s.face, "g2", false)
                if not s.leaving then ui:class(s.el, "is-in", false) end
                s.stage = nil
            end
        end
    end
    local ty = s.typed
    if ty then
        local n = #s.chars
        local done = floor((t - ty.start) / ty.per)
        if done >= n then
            ui:rml(s.type, esc(s.def.text))
            s.typed = nil
        elseif done >= 0 and t - ty.last >= 0.016 then
            ty.last = t
            local noise = {}
            for i = 1, min(4, n - done) do
                noise[i] = s.chars[done + i] == " " and " " or GLYPHS[math.random(#GLYPHS)]
            end
            ui:rml(s.type, esc(table.concat(s.chars, "", 1, done))
                .. '<span class="ab-sc" style="color: ' .. s.accent .. 'd9;">' .. esc(table.concat(noise)) .. "</span>")
        end
    end
    if s.hideAt and t >= s.hideAt then
        s.hideAt, s.display = nil, false
        ui:style(s.el, "display", "none")
    end
    return s.removeAt ~= nil and t >= s.removeAt
end

local frameTime, frameDt = 0, 0
local gone = {}

-- The bubble's opacity: the distance fade times the 140 ms show fade (.ab: opacity 140 ms
-- linear), on .ab-fade; written when it moved a hundredth.
local function fades(s)
    local want = s.shown and 1 or 0
    if s.show ~= want then
        s.show = want > s.show and min(1, s.show + frameDt / 0.14) or max(0, s.show - frameDt / 0.14)
    end
    local op = floor(s.fade * s.show * 100 + 0.5) / 100
    if op ~= s.op then s.op = op; ui:style(s.wrap, "opacity", fmt("%.2f", op)) end
end

local function drawFrame()
    local t = frameTime
    for key in pairs(stacks) do stacks[key] = nil end
    for _, s in ipairs(list) do
        if s.el then
            local a = s.def.anchor and byAnchor[s.def.anchor] or nil
            local d = a and tonumber(a.distance) or 0
            local visible = a ~= nil and not suppressed and a.projected ~= false and a.onScreen ~= false
                and d <= (tonumber(s.def.maxDistance) or 25)
            if visible ~= s.shown then
                s.shown = visible
                if visible then
                    s.hideAt = nil
                    if not s.display then s.display = true; ui:style(s.el, "display", "block") end
                else
                    s.hideAt = t + 0.2 -- .ab: opacity 140 ms, then out of the tree
                end
                ui:class(s.el, "is-shown", visible)
            end
            if visible then
                if not s.entered and not s.leaving then enter(s) end
                measure(s, t)
                place(s, a, d)
            end
            if s.display then fades(s) end
            if tick(s, t) then gone[#gone + 1] = s end
        end
    end
    for i = #gone, 1, -1 do
        destroy(gone[i])
        gone[i] = nil
    end
end

--- One frame: reads the anchors, places the bubbles. Returns true while there is a bubble.
function V.frame()
    if not ui or not loaded or #list == 0 then return false end
    local t = now()
    if t >= nextBusy then
        nextBusy = t + 0.15
        local busy = cursorTaken()
        if busy ~= suppressed then
            suppressed = busy
            ui:class("#bubbles", "is-off", busy)
        end
    end
    if t >= nextScreen then
        nextScreen = t + 1
        readScreen()
    end
    readAnchors()
    frameDt = clamp(frameTime > 0 and t - frameTime or 0, 0, 0.1)
    frameTime = t
    local ok, err = pcall(ui.batch, ui, drawFrame)
    if not ok then warn("frame", "frame failed: " .. tostring(err)) end
    return true
end

-- ---------------------------------------------------------------------------------------
-- The document.
-- ---------------------------------------------------------------------------------------

--- Creates the document. Returns true, or false and a reason.
function V.start(options)
    if ui then return true end
    if type(options) == "table" and options.hideUnderMenus ~= nil then hideUnderMenus = options.hideUnderMenus ~= false end
    local created, why
    for _ = 1, 2400 do -- up to 10 min: a slow first load keeps the resource preparing for minutes (2026-11-05)
        created, why = Open77.ui.create({ document = "ui/actionbubble.rml", layer = LAB and LAB.layer or "hud", zIndex = 12, visible = true })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then return false, why end
    ui = created
    ui:onEvent("loaded", function()
        loaded = true
        readScreen()
        rebuildAll()
    end)
    ui:onEvent("reloaded", function()
        suppressed = false
        rebuildAll()
    end)
    ui:onEvent("error", function(name, detail)
        warn("ui:" .. tostring(name), "ui " .. tostring(name) .. ": " .. tostring(type(detail) == "table" and detail.message or detail))
    end)
    return true
end

function V.stop()
    if ui then pcall(ui.destroy, ui) end
    ui, loaded = nil, false
    for key in pairs(bubbles) do bubbles[key] = nil end
    for i = #list, 1, -1 do list[i] = nil end
end

-- For the offline tests.
V.bubbles = bubbles
function V.attach(handle) ui, loaded = handle, true end
function V.screen() return screen end
