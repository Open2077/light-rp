-- The first day's overlays on NativeUI (client/native/tutorial.lua, ui/native/tutorial.rml): the
-- model each payload gives, the names the document binds, and the wiring through the host.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test native_tutorial.test.lua
local rml = assert(io.open("ui/native/tutorial.rml", "r")):read("a")
local rcss = assert(io.open("ui/native/tutorial.rcss", "r")):read("a"):gsub("/%*.-%*/", "")
setmetatable, getmetatable, rawget, rawset, load, require, debug, os, io = nil, nil, nil, nil, nil, nil, nil, nil, nil

-- no binding beside data-for on the element that repeats
for tag in rml:gmatch("<[^>]-data%-for=[^>]->") do
    assert(not tag:find("data%-class") and not tag:find("data%-style") and not tag:find("data%-attr") and not tag:find("data%-if"), "bindings on a data-for element: " .. tag)
end
-- the RCSS traps of docs/native-hud.md
assert(rml:find('href="nui://open77/open77.rcss"', 1, true) < rml:find('href="lightrp.rcss"', 1, true), "open77.rcss is linked first")
assert(not rcss:find("[^%-]linear[;,%s]") and not rcss:find("cubic%-bezier") and not rcss:find(" ease[;,%s]") and not rcss:find("italic"), "an RmlUi tween name only")
assert(not rcss:find("%dpx"), "dp, never px")

local threads, clock = {}, 0
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = clock } end
function Wait(ms) coroutine.yield(ms or 0) end
function GetGameTimer() return clock end
local function advance(ms)
    local stop = clock + ms
    repeat
        local i = 1
        while i <= #threads do
            local t = threads[i]
            if coroutine.status(t.co) == "dead" then
                table.remove(threads, i)
            else
                if t.at <= clock then
                    local ok, wait = coroutine.resume(t.co)
                    assert(ok, wait)
                    t.at = clock + math.max(1, tonumber(wait) or 0)
                end
                i = i + 1
            end
        end
        clock = clock + 10
    until clock > stop
end

local merged, animated, created = {}, {}, {}
local document = {}
function document:id() return 9 end
function document:merge(_, values) for k, v in pairs(values) do merged[k] = v end end
function document:onEvent() end
function document:animate(selector, spec) animated[#animated + 1] = { selector = selector, spec = spec } end
function document:style() end
function document:class() end
Open77 = {
    ui = { create = function(spec) created[#created + 1] = spec; return document end, loadFont = function() return true end },
    input = { isCaptured = function() return false, false end },
}
LightRpUi = { menuOpen = false }

dofile("shared/events.lua")
dofile("client/native/icons.lua")
dofile("client/native/host.lua")
dofile("client/native/tutorial.lua")
local N, E, T = LightRpNative, LightRpEvents, LightRpNativeTutorial
local function animatedOf(selector)
    local n = 0
    for _, a in ipairs(animated) do if a.selector == selector then n = n + 1 end end
    return n
end

-- ---- every name the document binds has a resting value ---------------------------------------
do
    local defaults, aliases, missing = T.defaults(), {}, {}
    for alias in rml:gmatch('data%-for="%s*([%a_][%w_]*)%s*:') do aliases[alias] = true end
    local function check(expression)
        for name in expression:gsub("'[^']*'", ""):gmatch("[%a_][%w_%.]*") do
            local root = name:match("^[^%.]+")
            if not aliases[root] and root ~= "true" and root ~= "false" and defaults[root] == nil then missing[root] = true end
        end
    end
    for expression in rml:gmatch("{{(.-)}}") do check(expression) end
    for attribute, expression in rml:gmatch('(data%-[%a%-]+)="([^"]*)"') do
        if attribute == "data-for" then check(expression:match(":%s*(.+)$"))
        elseif attribute ~= "data-model" then check(expression) end
    end
    local names = {}
    for name in pairs(missing) do names[#names + 1] = name end
    table.sort(names)
    assert(#names == 0, "bound in tutorial.rml but not in the model: " .. table.concat(names, ", "))
    assert(defaults.size == nil and defaults.it == nil and defaults.ev == nil, "reserved model names")
    -- the rows of each loop carry every field the document reads of them
    local map = T.hallMap({ { step = "intro", label = "Hall", x = 0, y = -100, state = "done" }, { step = "bank", label = "Bank", x = 0, y = 27, state = "now" } })
    local rows = { steps = T.steps({ index = 2, total = 4 }), mapStops = map.mapStops }
    for alias, array in rml:gmatch('data%-for="%s*([%a_][%w_]*)%s*:%s*([%a_][%w_]*)"') do
        assert(rows[array] and rows[array][1], "no sample rows for " .. array)
        for name in rml:gmatch("[^%w_]" .. alias .. "%.([%a_][%w_]*)") do
            for i, row in ipairs(rows[array]) do assert(row[name] ~= nil, ("%s[%d].%s is nil"):format(array, i, name)) end
        end
    end
end

-- ---- the card --------------------------------------------------------------------------------
do
    local keys = T.keys({ menu = "F2", inventory = "B", interact = "G" })
    assert(keys.menu == "F2" and keys.quit == "F6" and keys.context == "ALT", "the defaults under the published keys")
    local c = T.card({ active = true, step = "shop", index = 4, total = 10, title = "Your first purchase", line = "Get a drink.",
        objective = { position = { x = 0, y = 0, z = 0 }, label = "Browse shop" },
        todo = { { text = "Follow the arrow to the vendor" }, { key = "interact", text = "Open the shop" }, { key = "inventory", text = "Check your bag" } } }, keys)
    assert(c.indexText == "04" and c.totalText == "10" and #c.steps == 10 and c.steps[3].done and c.steps[4].now and not c.steps[5].done)
    assert(c.hasTodo and c.r1On and not c.r1HasKey and c.r1Icon == N.icon("map-pin") and c.r2HasKey and c.r2Key == "G" and c.r3Key == "B" and not c.r4On)
    assert(c.r3Icon == N.icon("chevron-right") and c.hasLine and c.guideName == "MARA" and c.hasObjective and not c.footMenu and not c.footKbd)
    c = T.card({ active = true, step = "neuralink", title = "Your Neural-Link", todo = { { key = "F2", text = "Open your Neural-Link" } } }, keys)
    assert(c.r1Key == "F2" and c.r1Icon == N.icon("chevron-right") and c.footMenu and c.indexText == "01", "a raw key, no objective: the menu footer")
    c = T.card({ active = true, step = "inventory", hint = "Open your bag.", practiceError = "The crate is gone.", guide = "Rook" }, keys)
    assert(not c.hasTodo and c.hint == "Open your bag." and c.footKbd and c.footText == "B · INVENTORY" and c.guideName == "ROOK")
    assert(c.hasPracticeError and c.practiceError == "The crate is gone. Type /tutorial resume to retry.")
    assert(T.card({ step = "identity" }, keys).footText == "F2 · IDENTITY" and T.card({ step = "bank" }, keys).footText == "G · INTERACT")
    assert(#T.steps({ index = 30, total = 15 }) == 15 and T.steps({ index = 30, total = 15 })[15].now, "the index is kept in the run")
end

-- ---- the examples, the lesson, the way, the reveal ------------------------------------------------
do
    local keys = T.keys(nil)
    local d = T.demo("menu", 0, keys)
    assert(d.dmMenu and d.capOn and d.capText == "F1" and not d.capWide and not d.menuOpen)
    d = T.demo("menu", 3, keys)
    assert(d.menuOpen and d.menuRowPicked and not d.menuRowOn and not d.capOn)
    d = T.demo("shop", 2, keys)
    assert(d.shopItemOn and d.shopCash and not d.shopBank and d.capText == "E")
    d = T.demo("shop", 4, keys)
    assert(d.shopCash and d.shopConfirmDone and not d.shopConfirmOn)
    d = T.demo("drink", 3, keys)
    assert(d.drinkDone and d.drinkFull and d.drinkIcon == N.icon("check") and d.capText == "I")
    d = T.demo("sell", 2, keys)
    assert(d.dmAct and d.actFromOn and d.actNew and d.actPay and d.actLabel == "Done" and d.actToIcon == N.icon("landmark"))
    d = T.demo("collect", 1, keys)
    assert(not d.actFromOn and d.actRun and d.actFull and d.actLabel == "Collecting… stay still")
    assert(T.demo("inventory", 0, T.keys({ inventory = "TAB" })).capWide, "a cap of three letters is wide")
    for id, stages in pairs(T.STAGES) do assert(#stages >= 2, id) end

    local l = T.lesson("vehicle_open", "ALT")
    assert(l.lessonBack and l.lessonMenuTitle == "TRUNK & HOOD" and l.lessonAction == "Open trunk" and l.lessonTarget == N.icon("car"))
    l = T.lesson("context_prop", nil)
    assert(not l.lessonBack and l.lessonMenuTitle == "PRACTICE CRATE" and l.lessonAction == "Inspect practice crate" and l.lessonActionIcon == N.icon("info"))

    assert(T.readWay({ hide = true }) == nil and T.readWay({ label = "x" }) == nil)
    local r = T.readout(T.readWay({ label = "Bank", distance = 1240, angle = 30 }))
    assert(r.wayOn and r.wayDistance == "1.2 km" and r.wayLabel == "Bank" and r.wayTurn == "rotate(-30deg)")
    assert(T.readout(T.readWay({ distance = 42.4, angle = -90 })).wayDistance == "42 m")

    local v = T.reveal({ name = "Garage", direction = "West of the square", distance = 46, index = 6, total = 10, durationMs = 5600 }, keys)
    assert(v.revealOn and v.revealEyebrow == "NEXT STOP · 06 / 10" and v.revealDirection == "West of the square · " and v.revealDistance == "46 m" and v.keySkip == "SPACE")
    assert(T.reveal({ name = "Garage", distance = 46.0 }, keys).revealEyebrow == "NEXT STOP" and T.reveal({ distance = 46.0 }, keys).revealDistance == "46 m")

    local map = T.hallMap({ { step = "intro", x = 0, y = -101, state = "done" }, { step = "bank", label = "Bank", x = 0, y = 27.3, state = "now" },
        { step = "garage", label = "Garage", x = -33, y = 0, state = "next" }, { step = "sell", x = 30, y = -78, state = "next" } })
    -- 91 x 156.3 units: 190 dp high, 1.216 dp per unit
    assert(map.mapOn and map.mapH == "190.00dp" and #map.mapStops == 4 and map.mapStops[2].now and map.mapStops[3].next)
    assert(map.mapRoute:match("^M[%d%.]+ [%d%.]+L") and select(2, map.mapRoute:gsub("L", "")) == 3)
    assert(not T.hallMap({}).mapOn and not T.hallMap(nil).mapOn)
end

-- ---- through the host: the card, the banner, the flight ------------------------------------------
do
    N.patchState({ character = { status = "active", playerId = 1 } })
    N.page(E.page.hud, { ready = true, health = { value = 100, max = 100 } })
    assert(N.start() == true)
    local spec
    for _, s in ipairs(created) do if s.document == "ui/native/tutorial.rml" then spec = s end end
    assert(spec and spec.layer == "hud" and spec.models.fd, "the document is created")
    for name in pairs(T.defaults()) do assert(spec.models.fd[name] ~= nil, name .. " is missing from the created model") end
    advance(150)
    assert(N.shell.ready and not N.shell.hidden)

    N.page(E.page.tutorial, { phase = "idle", keys = { menu = "F1", inventory = "I", interact = "E", skip = "SPACE", way = "G", quit = "F6" } })
    local state = { active = true, available = true, key = "default", step = "shop", revision = 1, index = 7, total = 15, title = "Your first purchase", demo = "shop",
        objective = { position = { x = 0, y = 0, z = 0 }, label = "Browse shop" }, todo = { { text = "Follow the arrow" }, { key = "interact", text = "Open the shop" } } }
    N.patchState({ tutorial = state })
    assert(merged.cardOn and merged.title == "Your first purchase" and merged.r2Key == "E" and merged.demoOn and merged.dmShop and merged.capOn)
    assert(animatedOf("#fd-card") == 1 and animatedOf("#fd-task") == 1 and animatedOf("#fd-r1") == 1 and animatedOf("#fd-r2") == 1 and animatedOf("#fd-demo") == 1)
    -- the example plays its stages
    advance(950)
    assert(merged.capOn == false and merged.shopItemOn == true)
    -- the way line comes with the guide's feed and goes when it stops
    N.page(E.page.tutorialGuide, { label = "Browse shop", distance = 42, angle = 30, rise = 0 })
    assert(merged.wayOn and merged.wayDistance == "42 m" and merged.wayTurn == "rotate(-30deg)")
    N.page(E.page.tutorialGuide, { hide = true })
    assert(merged.wayOn == false)
    N.page(E.page.tutorialGuide, { label = "Browse shop", distance = 42, angle = 30 })
    advance(3800)
    assert(merged.wayOn == false, "a client that stopped talking: the line goes by itself")

    -- a new step: STEP COMPLETE with the old title, the task enters again
    local next = {}
    for k, v in pairs(state) do next[k] = v end
    next.step, next.title, next.index, next.demo, next.revision = "drink", "Take a breath", 8, "drink", 2
    N.patchState({ tutorial = next })
    assert(merged.doneTitle == "Your first purchase" and merged.title == "Take a breath" and merged.dmDrink and merged.capOn)
    assert(animatedOf("#fd-task") == 2 and animatedOf("#fd-card") == 1)
    advance(100)
    assert(merged.doneOn == true)
    advance(2700)
    assert(merged.doneOn == false)

    -- under a dialog the card steps aside (the shell), and slides in again after
    N.dialog("tutorial", true)
    assert(merged.hidden == true)
    N.dialog("tutorial", false)
    assert(merged.hidden == false and animatedOf("#fd-card") == 2)

    -- the flight: the card goes, the reveal comes with the hall map
    next = {}
    for k, v in pairs(state) do next[k] = v end
    next.step, next.title, next.revision = "bank", "Your money", 3
    next.map = { { step = "intro", label = "Hall", x = 0, y = -101, state = "done" }, { step = "bank", label = "Night City Bank", x = 0, y = 27.3, state = "now" } }
    N.patchState({ tutorial = next })
    N.page(E.page.tutorial, { phase = "reveal" })
    N.page(E.page.tutorial, { reveal = { name = "Night City Bank", direction = "North of the square", distance = 46, index = 8, total = 15, durationMs = 5600 } })
    assert(merged.revealOn and not merged.cardOn and merged.mapOn and merged.revealEyebrow == "NEXT STOP · 08 / 15" and merged.mapStops[2].label == "Night City Bank")
    assert(animatedOf("#fd-bar-top") == 1 and animatedOf("#fd-reveal-fill") == 1 and animatedOf("#fd-reveal-map") == 1)
    N.page(E.page.tutorial, { reveal = false })
    N.page(E.page.tutorial, { phase = "idle" })
    assert(not merged.revealOn and merged.cardOn and animatedOf("#fd-card") == 3)

    -- the guide ends: nothing stays
    N.patchState({ tutorial = { active = false, available = true, status = "done" } })
    assert(merged.cardOn == false and merged.revealOn == false and merged.doneOn == false and merged.wayOn == false)
end

print("native_tutorial.test.lua: ok")
