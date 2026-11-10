-- op77_actionbubble: the NativeUI document's driver (client/view.lua) against a recording
-- ui handle: what a bubble is made of, its entrance on the first frame its anchor is on
-- screen, what a frame writes (and that a steady frame writes nothing), stacking, the side,
-- the typing, updates, the exit, menus holding the cursor.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test view_test.lua
local clock, frame, cursor, serial = 100, {}, false, 0
local cmds, rects, watched = {}, {}, {}
local function rec(...) cmds[#cmds + 1] = { ... } end
local ui = {}
function ui:create(parent, spec) serial = serial + 1; local id = "@" .. serial; rec("create", id, parent, spec); return id end
function ui:remove(sel) rec("remove", sel) end
function ui:style(sel, prop, value) rec("style", sel, prop, value) end
function ui:class(sel, name, on) rec("class", sel, name, on) end
function ui:text(sel, text) rec("text", sel, text) end
function ui:rml(sel, rml) rec("rml", sel, rml) end
function ui:animate(sel, spec) rec("animate", sel, spec) end
function ui:keyframes(sel, spec) rec("keyframes", sel, spec) end
function ui:stop(sel) rec("stop", sel) end
function ui:watch(sel) watched[sel] = true end
function ui:unwatch(sel) watched[sel] = nil end
function ui:rect(sel) return watched[sel] and rects[sel] or nil end
function ui:batch(fn) fn() end
function ui:state() return { width = 1920, height = 1080 } end

_G.Open77 = {
    time = { monotonic = function() return clock end },
    anchors = { frame = function() return frame end },
    input = { isCaptured = function() return cursor, cursor end },
}
dofile("client/view.lua")
local V = ActionBubbleView
V.attach(ui)

local function find(kind, sel, name)
    local out = {}
    for _, c in ipairs(cmds) do
        if c[1] == kind and (sel == nil or c[2] == sel) and (name == nil or c[3] == name) then out[#out + 1] = c end
    end
    return out
end
local function reset() cmds = {} end
local function step(dt) clock = clock + (dt or 0.016); return V.frame() end

-- every icon is path data NativeUI reads (no <circle>, no <rect>)
for name, d in pairs(V.ICONS) do
    assert(d:sub(1, 1) == "M" and not d:find("[<>]") and not d:find("nan"), name .. ": " .. d)
end
assert(V.ICONS.key:find("^M4 15a4 4 0 1 0 8 0a4 4 0 1 0 %-8 0z"), V.ICONS.key)
assert(V.ICONS.lock:find("^M6 11h12a1 1 0 0 1 1 1v8a1 1 0 0 1 %-1 1h%-12a1 1 0 0 1 %-1 %-1v%-8a1 1 0 0 1 1 %-1z"), V.ICONS.lock)

assert(V.frame() == false, "no bubble: nothing to do")

-- a bubble: its elements, out of the tree until its anchor is on screen
V:send("ab:add", { id = "l:1", text = "Opens the trunk", accent = "#2EE6E0", icon = "trunk", asterisks = true,
    side = "auto", duration = 4, remaining = 4, maxDistance = 25, anchor = "9", group = "vehicle:50" })
local s = V.bubbles["l:1"]
assert(s and s.el and s.rig and s.body and s.face and s.tbar and s.sheen)
local root = find("create", s.el)[1][4]
assert(root.class == "ab has-asterisks" and root.style.display == "none", root.class)
local text
for _, c in ipairs(find("create")) do if c[4].class == "ab-text" then text = c[4].rml end end
assert(text:find('<path class="ab-icon"', 1, true) and text:find("stroke: #2EE6E0", 1, true), "the icon in the accent colour")
assert(find("create", s.sizer)[1][4].rml == "Opens the trunk" and find("create", s.type)[1][4].rml == "", "sized by the line, typed later")
-- the glass: chamfer decorators scaled like a dp, the slabs' opacities in their colours
local face = find("create", s.face)[1][4].rml
assert(face:find("fx(chamfer-solid 9.00 0 0 0 #09090cd6), fx(chamfer 9.00 1.00 0.001 0 #2EE6E0ff)", 1, true), face)
local body = find("create", s.body)[1][4].rml
assert(body:find("#2EE6E02e", 1, true) and body:find("#2EE6E04d", 1, true) and body:find("#2EE6E080", 1, true), body)
-- player text reaches RML escaped, braces included ("{{" would open a data binding)
assert(V.esc('a{{b}}<i>&"') == "a&#x7B;&#x7B;b&#x7D;&#x7D;&lt;i&gt;&amp;&quot;")
assert(#find("keyframes", s.float) == 2, "the float: bob and sway, started once")

-- anchor not projected yet: nothing shown, no entrance
reset()
assert(step() == true and #find("class", s.el, "is-in") == 0 and not s.entered)

-- on screen: shown, entered, placed
reset()
frame = { { id = "9", projected = true, onScreen = true, x = 0.5, y = 0.5, distance = 4 } }
rects[s.face] = { x = 0, y = 0, width = 199, height = 35 }
step()
assert(s.entered and find("class", s.el, "is-shown")[1][4] == true and find("class", s.el, "is-in")[1][4] == true)
assert(find("style", s.el, "display")[1][4] == "block")
assert(s.w == 200 and s.h == 35, "measured: " .. s.w .. " x " .. s.h)
assert(find("style", s.el, "transform")[1][4] == "translate(960.0dp, 540.0dp)")
assert(find("style", s.pin, "transform")[1][4] == "scale(1.000)")
assert(#find("keyframes", s.ring) == 2, "the ring pulses")
-- the card attaches 50 right and 62 up, centred on its height
assert(find("style", s.rig, "transform")[1][4] == "translate(50.0dp, -79.5dp) scale(1.000)", find("style", s.rig, "transform")[1][4])
assert(find("style", s.dot, "transform")[1][4] == "translate(50.0dp, -62.0dp)")
assert(find("style", s.lb, "transform")[1][4] == "translate(22.0dp, -62.0dp) scaleX(0.2800)")
assert(find("style", s.la, "transform")[1][4] == "rotate(-70.46deg) scaleX(0.6579)", find("style", s.la, "transform")[1][4])
assert(find("style", s.body, "transform")[1][4] == "rotateY(-16.0deg) rotateX(7.0deg)")
-- the duration bar: 4 s left, 0.75 s of entrance
local timer = find("animate", s.tbar)[1][3]
assert(timer.duration == 3.25 and timer.delay == 0.75 and timer.to.scaleX == 0 and timer.easing == "linear")
assert(find("animate", s.sheen)[1][3].delay == 0.62)

-- the 140 ms show fade
reset(); for _ = 1, 10 do step() end
local fadeIn = find("style", s.wrap, "opacity")
assert(fadeIn[#fadeIn][4] == "1.00", "shown: " .. tostring(fadeIn[#fadeIn] and fadeIn[#fadeIn][4]))
-- a steady frame writes nothing
reset(); step()
assert(#cmds == 0, "steady: " .. #cmds .. " commands")
-- the camera turns: the anchor moves, the card turns with it; nothing else
reset()
frame[1].x = 0.6
step()
assert(#cmds == 2 and find("style", s.el, "transform")[1] and find("style", s.body, "transform")[1], #cmds)

-- the glitch steps, then the typing (from 560 ms), then the entrance is over
reset(); clock = s.enteredAt + 0.65; V.frame()
assert(find("class", s.face, "g1")[1][4] == true)
local typing = find("rml", s.type)
assert(#typing >= 1 and typing[1][3]:find('<span class="ab-sc" style="color: #2EE6E0d9;">', 1, true), "glitch characters in the accent")
reset(); clock = s.enteredAt + 0.80; V.frame()
assert(find("class", s.face, "g1")[1][4] == false and find("class", s.face, "g2")[1][4] == true)
reset(); clock = s.enteredAt + 1.2; V.frame()
local typed = find("rml", s.type)
assert(find("class", s.face, "g2")[1][4] == false and typed[#typed][3] == "Opens the trunk", "typed out")
reset(); clock = s.enteredAt + 1.6; V.frame()
assert(find("class", s.el, "is-in")[1][4] == false, "a later change of side does not replay the entrance")

-- a second bubble on the same target stacks above the first
V:send("ab:add", { id = "l:2", text = "Closes it", accent = "#FFCC00", asterisks = false, side = "auto",
    duration = 0, remaining = 0, maxDistance = 25, anchor = "9", group = "vehicle:50" })
local s2 = V.bubbles["l:2"]
assert(find("create", s2.el)[1][4].class == "ab is-infinite")
rects[s2.face] = { x = 0, y = 0, width = 99, height = 35 }
reset(); step()
-- 8 above the top of the first (62 + 17.5), centred on its own height: -(79.5 + 8 + 17.5) - 17.5
assert(find("style", s2.rig, "transform")[1][4] == "translate(50.0dp, -122.5dp) scale(1.000)", find("style", s2.rig, "transform")[1][4])
-- a taller card on top clears the one under it: three lines (60 high) sit 8 above the second
V:send("ab:add", { id = "l:3", text = "x", accent = "#FFCC00", asterisks = false, side = "auto",
    duration = 0, remaining = 0, maxDistance = 25, anchor = "9", group = "vehicle:50" })
local s3 = V.bubbles["l:3"]
rects[s3.face] = { x = 0, y = 0, width = 99, height = 60 }
reset(); step()
-- second card's top: 105 + 17.5 = 122.5; this one's middle 122.5 + 8 + 30 = 160.5, its top 190.5
assert(find("style", s3.rig, "transform")[1][4] == "translate(50.0dp, -190.5dp) scale(1.000)", find("style", s3.rig, "transform")[1][4])
V:send("ab:remove", { id = "l:3", instant = true })
assert(#find("animate", s2.tbar) == 0, "no duration: no bar")

-- far right of the screen: the card goes to the left of the pin; far away: smaller, fading
reset()
frame[1].x, frame[1].distance = 0.9, 21.875
step()
assert(find("class", s.el, "is-left")[1][4] == true)
assert(find("style", s.pin, "transform")[1][4] == "scale(0.750)" and find("style", s.wrap, "opacity")[1][4] == "0.50")
assert(find("style", s.rig, "transform")[1][4]:find("^translate%(%-37%.5dp, "), find("style", s.rig, "transform")[1][4])
-- past its distance: hidden, then out of the tree
reset()
frame[1].distance = 26
step()
assert(find("class", s.el, "is-shown")[1][4] == false and #find("style", s.el, "display") == 0)
reset(); step(0.25)
assert(find("style", s.el, "display")[1][4] == "none")
frame[1].x, frame[1].distance = 0.5, 4
step()

-- an update: new text types in at once, the bar starts over; a new accent rebuilds the bubble
reset()
V:send("ab:update", { id = "l:1", text = "Closes the trunk", accent = "#2EE6E0", icon = "trunk", asterisks = true,
    side = "auto", duration = 3, remaining = 3, maxDistance = 25, anchor = "9", group = "vehicle:50" })
assert(find("rml", s.sizer)[1][3] == "Closes the trunk" and find("animate", s.tbar)[1][3].duration == 3)
assert(#find("create") == 0, "same look: the elements stay")
local before = s.el
reset()
V:send("ab:update", { id = "l:1", text = "Closes the trunk", accent = "#FF3340", icon = "trunk", asterisks = true,
    side = "auto", duration = 3, remaining = 3, maxDistance = 25, anchor = "9", group = "vehicle:50" })
assert(find("remove", before)[1] and s.el ~= before and find("create", s.el)[1][4].class:find("is%-on"), "rebuilt as it stands, no entrance")

-- a menu takes the cursor: the layer goes, the bubbles with it
reset(); cursor = true; step(0.2)
assert(find("class", "#bubbles", "is-off")[1][4] == true and find("class", s2.el, "is-shown")[1][4] == false)
cursor = false; step(0.2)

-- the anchor goes (body not streamed): hidden; comes back under another id
reset()
V:send("ab:anchor", { id = "l:2", anchor = false })
step()
assert(find("class", s2.el, "is-shown")[1][4] == false)

-- the exit: classes, then the elements go 720 ms later; an instant removal goes at once
reset()
V:send("ab:remove", { id = "l:1" })
assert(find("class", s.el, "is-out")[1][4] == true and find("stop", s.ring)[1] and V.bubbles["l:1"] ~= nil)
step(0.5); assert(V.bubbles["l:1"] ~= nil)
reset(); step(0.3)
assert(V.bubbles["l:1"] == nil and find("remove", s.el)[1] and watched[s.face] == nil)
reset()
V:send("ab:remove", { id = "l:2", instant = true })
assert(V.bubbles["l:2"] == nil and find("remove", s2.el)[1])
assert(V.frame() == false)

print("view_test: ok")
