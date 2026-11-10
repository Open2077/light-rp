-- op77_playermarks: the NativeUI document's driver (client/view.lua) against a recording
-- ui handle: what a plate is made of, what a frame writes (and that a steady frame writes
-- nothing), off-screen plates, the voice bars, menus holding the cursor.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test view_test.lua
local clock, frame, cursor, serial = 1000, {}, false, 0
local cmds = {}
local function rec(...) cmds[#cmds + 1] = { ... } end
local ui = {}
function ui:create(parent, spec) serial = serial + 1; local id = "@" .. serial; rec("create", id, parent, spec); return id end
function ui:remove(sel) rec("remove", sel) end
function ui:style(sel, prop, value) rec("style", sel, prop, value) end
function ui:class(sel, name, on) rec("class", sel, name, on) end
function ui:text(sel, text) rec("text", sel, text) end
function ui:rml(sel, rml) rec("rml", sel, rml) end
function ui:keyframes(sel, spec) rec("keyframes", sel, spec) end
function ui:stop(sel) rec("stop", sel) end
function ui:batch(fn) fn() end
function ui:state() return { width = 2560, height = 1440 } end

_G.GetGameTimer = function() return clock end
_G.Open77 = {
    anchors = { frame = function() return frame end },
    input = { isCaptured = function() return cursor, cursor end },
}
dofile("client/view.lua")
local V = PlayerMarksView
V.attach(ui)

local function find(kind, sel, name)
    local out = {}
    for _, c in ipairs(cmds) do
        if c[1] == kind and (sel == nil or c[2] == sel) and (name == nil or c[3] == name) then out[#out + 1] = c end
    end
    return out
end
local function reset() cmds = {} end
local function styles(sel, prop)
    local out = {}
    for _, c in ipairs(cmds) do
        if c[1] == "style" and c[2] == sel then
            if type(c[3]) == "table" then
                if c[3][prop] ~= nil then out[#out + 1] = { "style", sel, prop, c[3][prop] } end
            elseif c[3] == prop then out[#out + 1] = c end
        end
    end
    return out
end

assert(V.upper("Zoé Müller ÷") == "ZOÉ MÜLLER ÷", V.upper("Zoé Müller ÷"))
assert(V.trimUtf8("ab\195") == "ab" and V.trimUtf8("ab\195\169") == "ab\195\169")
assert(V.frame() == false, "nobody around: nothing to do")

V:send("pm:config", { radius = 40, page = { nearScale = 1.0, farScale = 0.5, fadeFrom = 0.5 } })
V:send("pm:add", { player = "7", anchor = "100", name = "[7] Archer" })
local p = V.plates["7"]
assert(p and p.el and p.rig and #p.bars == 3 and p.label)
local made = find("create")
assert(made[1][3] == "#marks" and made[1][4].class == "pm" and made[1][4].style.display == "none", "created out of the tree")
assert(find("create", p.label)[1][4].rml == "[7] ARCHER", "capitals")
-- player text reaches RML escaped, braces included ("{{" would open a data binding)
assert(V.esc('a{{b}}<i>&"') == "a&#x7B;&#x7B;b&#x7D;&#x7D;&lt;i&gt;&amp;&quot;")

-- first frame: 2560 x 1440 is 1920 x 1080 dp; shown, placed, scaled, faded
reset()
frame = { { id = "100", projected = true, onScreen = true, x = 0.5, y = 0.25, distance = 30 } }
assert(V.frame() == true)
assert(find("style", p.el, "transform")[1][4] == "translate(960.0dp, 270.0dp)")
assert(find("style", p.rig, "transform")[1][4] == "scale(0.625)", find("style", p.rig, "transform")[1][4])
-- shown on this frame: the 160 ms show fade starts from 0, then reaches the distance fade
assert(find("style", p.rig, "opacity")[1] == nil or find("style", p.rig, "opacity")[1][4] == "0.00")
for _ = 1, 12 do clock = clock + 16; V.frame() end
local ops = find("style", p.rig, "opacity")
assert(ops[#ops][4] == "0.50", "distance fade x show: " .. tostring(ops[#ops][4]))
assert(find("style", p.el, "display")[1][4] == "block" and find("class", p.el, "is-shown")[1][4] == true)
-- the resolution was read on that frame: the plate was made again, its cuts scaled like a dp
assert(V.screen().ratio > 1.33 and find("create", p.el)[1], "rebuilt at the new scale")

-- the chamfered plates are decorators scaled like a dp (cut 6 * 1.333)
local chipRml
for _, c in ipairs(find("create")) do if c[4].class == "pm-chip" then chipRml = c[4].rml end end
assert(chipRml and chipRml:find("fx(chamfer-solid 8.00 0 0 0 #060608bd)", 1, true), tostring(chipRml))
-- a steady frame writes nothing
reset(); clock = clock + 16
V.frame()
assert(#cmds == 0, "steady: no command, got " .. #cmds)
-- the anchor moved: only the transform
reset(); clock = clock + 16
frame[1].x = 0.51
V.frame()
assert(#cmds == 1 and cmds[1][3] == "transform" and cmds[1][2] == p.el)

-- off screen: fades out over 160 ms, then leaves the tree 200 ms later
reset(); clock = clock + 16
frame[1].onScreen = false
V.frame()
assert(find("class", p.el, "is-shown")[1][4] == false)
for _ = 1, 10 do clock = clock + 16; V.frame() end
ops = find("style", p.rig, "opacity")
assert(ops[#ops][4] == "0.00", "faded out")
clock = clock + 100; V.frame()
assert(find("style", p.el, "display")[1][4] == "none")
-- back, then past the radius (the anchor is still projected): hidden again
reset(); clock = clock + 16
frame[1].onScreen = true
V.frame()
assert(find("style", p.el, "display")[1][4] == "block" and find("class", p.el, "is-shown")[1][4] == true)
reset(); clock = clock + 16
frame[1].distance = 41
V.frame()
assert(find("class", p.el, "is-shown")[1][4] == false)
frame[1].distance = 10
clock = clock + 16; V.frame()

-- talking: the class once, then the bars move with the frames; silent: back to the stubs
reset()
V:send("pm:talk", { player = "7", talking = true, level = 1 })
assert(cmds[1][1] == "class" and cmds[1][3] == "is-talking" and cmds[1][4] == true)
assert(#find("keyframes", p.pulse) == 2, "the tip pulses")
local moved = 0
for _ = 1, 30 do
    reset(); clock = clock + 16; V.frame()
    for _, c in ipairs(cmds) do
        if c[3] == "opacity" then goto continue end -- the talking plate fades in
        assert(c[1] == "style" and c[3] == "transform" and c[4]:match("^scaleY%(0%.%d+%)$") or c[4] == "scaleY(1.000)", tostring(c[4]))
        local s = tonumber(c[4]:match("%((.-)%)"))
        assert(s >= 3 / 11 - 0.001 and s <= 1.001, "between 3 px and 11 px at level 1")
        moved = moved + 1
        ::continue::
    end
end
assert(moved > 20, "the bars move")
reset()
V:send("pm:talk", { player = "7", talking = false, level = 0 })
assert(cmds[1][1] == "class" and cmds[1][4] == false and find("stop", p.pulse)[1], "the pulse stops")
local back = 0
for _, b in ipairs(p.bars) do for _, c in ipairs(find("style", b, "transform")) do assert(c[4] == nil); back = back + 1 end end
assert(back == 3, "the RCSS height again")

-- a menu takes the cursor: the layer goes, the plates with it; and comes back
reset(); clock = clock + 200; cursor = true
V.frame()
assert(find("class", "#marks", "is-off")[1][4] == true and find("class", p.el, "is-shown")[1][4] == false)
reset(); clock = clock + 200; cursor = false
V.frame()
assert(find("class", "#marks", "is-off")[1][4] == false and find("class", p.el, "is-shown")[1][4] == true)

-- renamed, removed
reset()
V:send("pm:name", { player = "7", name = "[7] zoé" })
assert(cmds[1][1] == "rml" and cmds[1][3] == "[7] ZOÉ")
reset()
V:send("pm:name", { player = "7", name = "[7] {{x}} <b>" })
assert(cmds[1][3] == "[7] &#x7B;&#x7B;X&#x7D;&#x7D; &lt;B&gt;", cmds[1][3])
reset()
V:send("pm:remove", { player = "7" })
assert(cmds[1][1] == "remove" and cmds[1][2] == p.el and V.plates["7"] == nil)
assert(V.frame() == false)

print("view_test: ok")
