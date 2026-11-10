-- The voice HUD's model, digits, presets and document updates (client/ui.lua) against a
-- recording fake of Open77.ui. Run with Lua 5.4 from the resource folder:
--   lua tests/ui.test.lua
local threads, clock = {}, 0
function GetGameTimer() return clock end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
local function step()
    local current = threads; threads = {}
    for _, co in ipairs(current) do
        assert(coroutine.resume(co))
        if coroutine.status(co) ~= "dead" then threads[#threads + 1] = co end
    end
end

local merges, sets, animations, events = {}, {}, {}, {}
local rml, sheets, classes, styles = {}, {}, {}, {}
local shown, created, fonts = nil, nil, {}
local screen = { width = 1920, height = 1080 }
local doc = {}
function doc:onEvent(name, fn) events[name] = fn end
function doc:merge(_, values) merges[#merges + 1] = values end
function doc:set(_, key, value) sets[key] = value end
function doc:animate(sel, spec) animations[#animations + 1] = { sel, spec } end
function doc:rml(sel, text) rml[sel] = text end
function doc:stylesheet(name, text) sheets[name] = text end
function doc:class(sel, name, on) classes[sel .. "." .. name] = on end
function doc:style(sel, spec) styles[sel] = spec end
function doc:state() return screen end
function doc:show() shown = true end
function doc:hide() shown = false end
function doc:destroy() end
Open77 = { ui = {
    create = function(options)
        assert(options.document == "ui/voice.rml" and options.layer == "hud")
        created, shown = options, options.visible
        return doc
    end,
    loadFont = function(_, family) fonts[#fonts + 1] = family; return true end,
} }

dofile("client/ui.lua")
local V = OpenVoiceHud

-- ---- the model -------------------------------------------------------------------------
local modes = {
    { name = "whisper", label = "Whisper", distance = 3, color = "#22D8E2" },
    { name = "normal", label = "Normal", distance = 20, color = "#22D8E2" },
    { name = "shout", label = "Shout", distance = 40, color = "#22D8E2" },
}
local base = { visible = true, configured = true, available = true, captureEnabled = true,
    mode = "Normal", modeName = "normal", distance = 20, key = "f11", state = "detected", inputLevel = 0.5,
    modeIndex = 2, modeCount = 3, modes = modes, color = "#22D8E2", activation = "vad", activeTalkers = 0, error = "" }
local m = V.model(base)
assert(m.state == "detected" and m.stateLabel == "SIGNAL" and m.lit == 7 and m.label == "NORMAL" and m.key == "F11")
assert(m.color == "#FFCC00", "the Light RP palette replaces the server colour of the three known presets")
assert(m.multi and m.shown and not m.off and not m.hasError and m.distance == "20")
assert(V.model({ state = "muted", inputLevel = 1 }).lit == 0 and V.model({ state = "muted" }).off, "muted meter is dark")
assert(V.model({ state = "muted" }).stateLabel == "MUTED" and V.model({ state = "idle" }).stateLabel == "OPEN")
assert(V.model({ state = "talking" }).stateLabel == "TRANSMIT" and V.model({}).stateLabel == "VOICE OFF")
assert(V.model({ configured = false, inputLevel = 1 }).state == "offline")
assert(V.model({ configured = true, available = true, captureEnabled = true, transmitting = true }).state == "talking")
assert(V.model({ configured = true, available = true, captureEnabled = false }).state == "muted")
assert(V.model({ state = "talking", inputLevel = 1 }).lit == 14)
assert(V.model({ modeName = "radio", color = "#ff00AA" }).color == "#ff00AA", "unknown presets keep the server colour")
assert(V.model({ modeName = "radio", color = "red; x" }).color == "#FFCC00")
assert(V.model({ modeName = "WHISPER" }).color == "#7FB4D6" and V.model({ modeName = "shout" }).color == "#FF3FB4")
assert(V.formatDistance(3) == "3" and V.formatDistance(2.5) == "2.5" and V.formatDistance(1000) == "1000" and V.formatDistance(-4) == "0")
assert(V.model({ error = ("x"):rep(200) }).error:len() == 80 and V.model({ error = "e" }).hasError)
assert(#V.model({ mode = ("W"):rep(40) }).label == 24)
assert(not V.model({ modes = { modes[1] } }).multi and not V.model({ modes = {} }).multi, "one preset: the reach is written out")
assert(V.model({ visible = false }).shown == false)
assert(V.narrow(1920, 1080) == 0 and V.narrow(1440, 1080) == 1 and V.narrow(1280, 1024) == 2 and V.narrow(nil, 0) == 0)

-- ---- seven segments ----------------------------------------------------------------------
local function count(text, what) return select(2, text:gsub(what, "")) end
local d = V.digits("20")
assert(d.width == 60, "two digits: the page's 60 x 44 box")
assert(count(d.on, "Z") == 5 + 6 and count(d.off, "Z") == 2 + 1, "2 lights 5 segments, 0 lights 6")
d = V.digits("3")
assert(d.width == 60 and count(d.on, "Z") == 5 and count(d.off, "Z") == 7 + 2, "one digit keeps a blank cell before it")
d = V.digits("2.5")
assert(d.width == 60 and count(d.on, "Z") == 5 + 5 + 1, "the decimal point belongs to the digit before it")
assert(V.digits("1000").width == 120)
assert(d.on:sub(1, 1) == "M" and not d.on:find("nan", 1, true))
-- segment a of a digit in the second cell: (3.7, 2.5) slanted by x - 0.09 y + 3.96, moved by 30
assert(V.digits("7").on:find("M37.44 2.50", 1, true) or V.digits("7").on:find("M37.43 2.50", 1, true), V.digits("7").on:sub(1, 40))
local digitsRml = V.digitsRml(V.digits("8"))
assert(digitsRml:find('class="seg-on"', 1, true) and digitsRml:find('view-box="0 0 60 44"', 1, true) and digitsRml:find("width: 60dp", 1, true))
assert(V.digitsRml(V.digits("88")):find("seg-off", 1, true) == nil, "nothing unlit, no ghost path")

-- ---- presets -----------------------------------------------------------------------------------
local list, key = V.ranges(modes)
assert(#list == 3 and list[1].label == "WHISPER" and list[1].metres == "3M" and list[1].color == "#7FB4D6" and list[3].color == "#FF3FB4")
local _, key2 = V.ranges(modes)
assert(key == key2)
local custom = V.ranges({ { name = "Radio<b>", label = "A very long label", distance = 2.5, color = "#00ff00" }, "junk", { name = "x", distance = 0 } })
assert(#custom == 2 and custom[1].label == "A VERY LONG " and custom[1].metres == "2.5M" and custom[1].color == "#00ff00" and custom[2].metres == "")
assert(#V.ranges(nil) == 0 and #V.ranges({ 1, 2 }) == 0)
local tags = V.rangesRml(V.ranges({ { name = "a", label = "<i>&", distance = 5 } }))
assert(tags:find("&lt;I&gt;&amp;", 1, true) and tags:find('id="rg-1"', 1, true) and tags:find('class="rg-m">5M', 1, true))
local sheet = V.rangesSheet(list)
assert(sheet:find("#rg-1.on { color: #7FB4D6; background-color: #7FB4D624; }", 1, true) and sheet:find("#rg-3 .rg-sel { background-color: #FF3FB4; }", 1, true))
assert(V.modeSheet("#7FB4D6"):find("#dist-unit { color: #7FB4D6; }", 1, true) and V.modeSheet("x"):find("#FFCC00", 1, true))

-- ---- the surface ----------------------------------------------------------------------------------
local page = assert(V.create({ visible = false }))
assert(created.visible == false and shown == false, "created hidden when main.lua starts blocked")
assert(fonts[1] == "Share Tech Mono")
assert(created.models.voice.shown == false and created.models.voice.changing == false and created.models.voice.narrow == 0)
for k in pairs(V.model(base)) do assert(created.models.voice[k] ~= nil, "every merged name exists in the model: " .. k) end
local ready = 0
page:on("open-voice:ready", function() ready = ready + 1 end)
events.loaded()
assert(ready == 1, "loaded calls the ready handler")
page:show()
assert(shown == true)

-- the first payload sends everything, an identical one nothing
page:send("open-voice:update", base)
assert(#merges == 1 and merges[1].label == "NORMAL" and merges[1].lit == 7 and merges[1].shown == true)
assert(rml["#ranges"]:find('id="rg-3"', 1, true) and sheets.ranges and sheets.mode:find("#FFCC00", 1, true))
assert(classes["#rg-2.on"] == true and rml["#dist7"]:find("seg-on", 1, true) and styles["#dist7"].width == "60dp")
rml, sheets = {}, {}
page:send("open-voice:update", base)
assert(#merges == 1 and next(rml) == nil and next(sheets) == nil, "unchanged payload, no update")
local louder = {}
for k, v in pairs(base) do louder[k] = v end
louder.inputLevel = 0.6
page:send("open-voice:update", louder)
assert(#merges == 2 and merges[2].lit == 8 and merges[2].label == nil, "only the changed values")
assert(#animations == 0 and sets.changing == nil, "the first reach does not animate")

-- a new reach: tags, colour layer, digits, and the 340 ms change
local whisper = {}
for k, v in pairs(base) do whisper[k] = v end
whisper.mode, whisper.modeName, whisper.distance, whisper.modeIndex = "Whisper", "whisper", 3, 1
page:send("open-voice:update", whisper)
assert(merges[3].label == "WHISPER" and merges[3].distance == "3" and merges[3].color == "#7FB4D6")
assert(classes["#rg-2.on"] == false and classes["#rg-1.on"] == true and sheets.mode:find("#7FB4D6", 1, true) and rml["#dist7"])
assert(rml["#ranges"] == nil, "the same presets are not rebuilt")
assert(#animations == 1 and animations[1][1] == "#rg-1 .rg-sel" and animations[1][2].to["background-color"] == "#7FB4D6")
assert(sets.changing == false)
step(); step(); assert(sets.changing == true, "one frame without the class restarts the animation")
step(); assert(sets.changing == false)

-- narrow screens: the document's size is read with an update, every 2 s at most
assert(sets.narrow == 0 and #threads == 0, "no thread is left running")
screen = { width = 1280, height = 1024 }
whisper.error = "RATE"
page:send("open-voice:update", whisper)
assert(sets.narrow == 0, "not before 2 s")
assert(merges[#merges].error == "RATE" and merges[#merges].hasError == true)
clock = 2500

-- an error, then hide() / show() from main.lua reach the document
whisper.error = "RATE_LIMITED"
page:send("open-voice:update", whisper)
assert(sets.narrow == 2)
assert(merges[#merges].error == "RATE_LIMITED" and merges[#merges].hasError == nil, "only the text changed")
page:hide(); assert(shown == false)
page:show(); assert(shown == true)

-- a reloaded document gets everything again
merges, rml, sheets = {}, {}, {}
events.reloaded()
assert(ready == 2)
page:send("open-voice:update", whisper)
assert(merges[1].state == "detected" and rml["#ranges"] and rml["#dist7"] and sheets.mode and classes["#rg-1.on"] == true)
page:send("garbage", {}); page:send("open-voice:update", nil)
page:destroy()

-- without NativeUI: no surface, a reason
Open77.ui = nil
local none, why = V.create()
assert(none == nil and why == "nativeui_unavailable")
print("open-voice ui: model, palette, seven segments, presets, layers, minimal updates, reach change, narrow, reload PASS")
