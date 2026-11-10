-- The gameplay HUD on NativeUI (client/native/hud.lua, ui/native/hud.rml): the model each
-- payload gives, the names the document binds, and the wiring through the host.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test native_hud.test.lua
local rml = assert(io.open("ui/native/hud.rml", "r")):read("a")
-- The client sandbox has no setmetatable / load / require / debug / os / io: removed here too.
setmetatable, getmetatable, rawget, rawset, load, require, debug, os, io = nil, nil, nil, nil, nil, nil, nil, nil, nil

-- Every row of a data-for array must carry every field the document reads of it (false, "",
-- 0: never nil): RmlUi warns "Could not get value from data variable" otherwise. The loops
-- and the fields come from the document itself.
local LOOPS = {}   -- array name -> { alias, fields }
for alias, array in rml:gmatch('data%-for="%s*([%a_][%w_]*)%s*:%s*([%a_][%w_]*)"') do
    local fields = {}
    for name in rml:gmatch("[^%w_]" .. alias .. "%.([%a_][%w_]*)") do fields[name] = true end
    LOOPS[array] = { alias = alias, fields = fields }
end
local function assertRows(values)
    for array, loop in pairs(LOOPS) do
        local rows = values[array]
        if rows ~= nil then
            assert(type(rows) == "table", array .. " is not an array")
            for index, row in ipairs(rows) do
                for name in pairs(loop.fields) do
                    assert(row[name] ~= nil, ("%s[%d].%s is nil (bound as %s.%s)"):format(array, index, name, loop.alias, name))
                end
            end
        end
    end
    return values
end
-- no binding beside data-for on the element that repeats: a removed row's own bindings are
-- evaluated once more (the warnings of the first in-game run)
for tag in rml:gmatch("<[^>]-data%-for=[^>]->") do
    assert(not tag:find("data%-class") and not tag:find("data%-style") and not tag:find("data%-attr") and not tag:find("data%-if"), "bindings on a data-for element: " .. tag)
end

local threads, clock = {}, 0
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = clock } end
function Wait(ms) coroutine.yield(ms or 0) end
function GetGameTimer() return clock end
--- Runs the threads until `ms` have passed (10 ms steps).
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

local merged, classes, styles, created = {}, {}, {}, nil
local document = {}
function document:id() return 7 end
function document:merge(_, values) assertRows(values); for k, v in pairs(values) do merged[k] = v end end
function document:onEvent() end
function document:class(selector, name, on) classes[selector .. "." .. name] = on end
function document:style(selector, property, value) styles[selector .. "." .. property] = value end
function document:state() return { width = 2560, height = 1440 } end
local projected = { x = 0.25, y = 0.5, onScreen = true, distance = 3 }
Open77 = {
    ui = { create = function(spec) created = spec; return document end, loadFont = function() return true end },
    camera = { project = function() return projected end },
    input = { isCaptured = function() return false, false end },
}
LightRpUi = { menuOpen = false }

dofile("shared/events.lua")
dofile("client/native/icons.lua")
dofile("client/native/host.lua")
dofile("client/native/hud.lua")
local N, E, H = LightRpNative, LightRpEvents, LightRpNativeHud
-- every pure builder is checked on everything the tests below make it produce
for _, name in ipairs({ "weapon", "crew", "hotbar", "walk", "defaults" }) do
    local build = H[name]
    H[name] = function(...) return assertRows(build(...)) end
end
assert(LOOPS.crewRows and LOOPS.crewOps and LOOPS.crewPending and LOOPS.wsHands and LOOPS.hbSlots and LOOPS.wfCells, "a data-for loop of hud.rml was not found")

-- ---- every name the document binds has a resting value ---------------------------------------
do
    local defaults, aliases, missing = H.defaults(), {}, {}
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
    assert(#names == 0, "bound in hud.rml but not in the model: " .. table.concat(names, ", "))
    -- the rows a data-for reads carry every field the document asks of them
    local function fields(alias)
        local set = {}
        for name in rml:gmatch("[^%w_]" .. alias .. "%.([%a_][%w_]*)") do set[name] = true end
        return set
    end
    local function has(row, alias)
        for name in pairs(fields(alias)) do assert(row[name] ~= nil, alias .. "." .. name .. " is not in the model") end
    end
    has(H.hotbar({ ready = true, visible = true, items = { { slot = 1, count = 2, label = "Burrito", icon = "sandwich" } } }, nil).hbSlots[1], "s")
    has(H.hotbar({ ready = true, visible = true, items = {} }, nil).hbSlots[2], "s")
    has(H.weapon({ active = true, hands = { { hand = "right", label = "Unity", magazine = 3, capacity = 12, reloading = false } } }).wsHands[1], "h")
    has(H.walk({ mode = "walk", label = "Walk", count = 3, index = 2 }).wfCells[1], "c")
    local crew = H.crew({ id = "p", maxSize = 4, members = { { id = 1, name = "V", leader = true } }, pending = { { id = 2, name = "Jackie" } } }, nil, 1)
    has(crew.crewRows[1], "m"); has(crew.crewPending[1], "p")
    has(H.crew(nil, { running = true, title = "Heist", squad = { { id = 1, name = "V", health = 80, maxHealth = 100, armor = 20, state = "alive" },
        { id = 2, name = "T", health = 10, maxHealth = 100, armor = 0, state = "down" } } }, 1).crewOps[1], "o")
end

-- ---- PlayerVitals ----------------------------------------------------------------------------
do
    local v = H.vitals({ health = { value = 87.6, max = 100 }, stamina = { value = 30, max = 60 }, armor = 12.4 }, { food = 55, drink = 18 })
    assert(v.hp == "88" and v.hpMax == "100" and v.hpTrim == 0.876 and not v.hpLow and not v.hpCritical and not v.hpZero)
    assert(v.ar == "12" and v.en == "50" and v.enTrim == 0.5 and v.fd == "55" and v.wt == "18" and v.wtLow and not v.fdLow)
    assert(v.warnOn and v.warnText == "Thirsty" and not v.starveOn and not v.fedOn)
    v = H.vitals({ health = { value = 20, max = 100 }, stamina = { value = 0, max = 100 }, armor = 0 }, { food = 10, drink = 5 })
    assert(v.warnText == "Low health · Hungry · Thirsty" and v.hpLow and v.arEmpty and v.arZero and v.enEmpty)
    v = H.vitals({ health = { value = 8, max = 100 }, stamina = {}, armor = 1250 }, { food = 0, drink = 40, starving = "food", drainPerMinute = 2 })
    assert(v.starveOn and not v.warnOn and v.starveTitle == "STARVING" and v.hpDrain and v.fdDrain and not v.wtDrain and v.hpCritical)
    assert(v.starveText == "−2 % health / min · ~4 min left · Eat something now", v.starveText)
    assert(v.arCompact and v.ar == "1250" and v.fdLow and not v.fdEmpty, "an empty gauge that warns is not 'empty'")
    assert(v.vignetteOpacity > 0.9 and v.vignetteOpacity <= 1)
    v = H.vitals({ health = { value = 1, max = 100 } }, { food = 0, drink = 0, starving = "both", drainPerMinute = 2.5 })
    assert(v.starveTitle == "STARVING & DEHYDRATED" and v.starveText == "−2.5 % health / min · under a minute left · Eat and drink now", v.starveText)
    v = H.vitals({ health = { value = 60, max = 100 }, stamina = { value = 1, max = 1 } }, { food = 90, drink = 90, wellFed = true, regenPerMinute = 3 })
    assert(v.fedOn and v.fedText == "Well fed · +3 HP / min" and not v.warnOn)
    v = H.vitals({ health = { value = 100, max = 100 } }, { food = 90, drink = 90, wellFed = true, regenPerMinute = 3 })
    assert(not v.fedOn, "well fed is only worth showing while health is not full")
    -- in a match the needs step aside: no warning, and the document drops the food and water dials
    v = H.vitals({ health = { value = 20, max = 100 } }, { food = 10, drink = 90, wellFed = true, regenPerMinute = 3 }, true)
    assert(v.matchOn and not v.warnOn and not v.fedOn and v.hpLow)
    assert(H.vitals({ health = { value = 20, max = 100 } }, { food = 10, drink = 90 }).matchOn == false)
end

-- ---- WeaponStatus, the hologram gap, the grenade chip -----------------------------------------
do
    local w = H.weapon({ active = true, reserve = 96, hands = {
        { hand = "right", label = "Unity", magazine = 3, capacity = 12, reloading = true },
        { hand = "left", label = "Lexington", magazine = 0, capacity = 21, reloading = false } } })
    assert(w.wsOn and w.wsReserve == "96" and w.wsReserveLabel == "SHARED RESERVE")
    assert(w.wsHands[1].side == "R" and w.wsHands[1].magazine == "03" and w.wsHands[1].capacity == "12" and w.wsHands[1].trim == 0.25 and w.wsHands[1].reloading)
    assert(w.wsHands[2].side == "L" and w.wsHands[2].empty and w.wsHands[2].zero and w.wsHands[2].magazine == "00")
    w = H.weapon({ active = true, hands = { { hand = "right", label = "Katana", reloading = false } } })
    assert(w.wsHands[1].magazine == "—" and w.wsReserve == "—" and w.wsReserveLabel == "RESERVE" and not w.wsHands[1].empty)
    assert(not H.weapon({ active = false, externalTop = 300 }).wsOn and not H.weapon({ active = true, hands = {} }).wsOn)
    -- the hologram's top at 282 dp: 139 dp are under the gap without the grenade chip, 167 with it
    assert(H.gap(0, false).gapOn == false)
    assert(H.gap(282, false).gapHeight == "143dp" and H.gap(282, true).gapHeight == "115dp" and H.gap(100, true).gapHeight == "0dp")
    assert(H.grenade({ ready = true, selected = "frag", count = 3, label = "F-GX Frag" }).grCount == "3")
    assert(not H.grenade({ ready = true, selected = "frag", count = 0 }).grOn and not H.grenade({ ready = true, count = 2 }).grOn)
end

-- ---- VehicleCluster, rental -------------------------------------------------------------------
do
    local c = H.vehicle({ active = true, label = "Quadra Turbo-R", speedKph = 119.6, gear = "3", health = 0.5,
        fuel = { litres = 7.4, capacity = 60, fraction = 0.12, low = true, empty = false } })
    assert(c.clOn and c.clSpeedText == "120" and c.clSpeed == 15 and c.clGear == "3" and c.clCond == 6 and c.clCondText == "50")
    assert(c.clFuel == 1 and c.clFuelText == "7" and c.clFuelUnit == "RESERVE" and c.clFuelLow and not c.clFuelEmpty and c.clName == "QUADRA TURBO-R")
    c = H.vehicle({ active = true, speedKph = 1400 })
    assert(c.clSpeedText == "999" and c.clSpeed == 30 and c.clFuelText == "--" and c.clFuelUnit == "LITRES" and c.clGear == "N" and c.clName == "VEHICLE" and c.clCond == 12)
    c = H.vehicle({ active = true, fuel = { litres = 0, capacity = 60, fraction = 0, low = true, empty = true } })
    assert(c.clFuelEmpty and not c.clFuelLow and c.clFuelUnit == "EMPTY" and c.clFuelText == "0")
    assert(H.vehicle({ active = false }).clOn == false)

    local r = H.rental({ active = { remainingMs = 1805000, extensionsLeft = 1 } }, 4000)
    assert(r.rentOn and r.rentClock == "30:01" and not r.rentEnding and r.rentHint == "")
    r = H.rental({ active = { remainingMs = 125000, extensionsLeft = 2, extendMinutes = 20 } }, 0)
    assert(r.rentEnding and r.rentClock == "02:05" and r.rentHint == "/extendrental · +20 min")
    r = H.rental({ active = { remainingMs = 60000, warnMs = 90000 } }, 70000)
    assert(r.rentEnding and r.rentClock == "00:00" and r.rentHint == "Return it at any desk")
    assert(not H.rental({}, 0).rentOn and not H.rental(false, 0).rentOn)
end

-- ---- CrewHud ----------------------------------------------------------------------------------
do
    local members = {}
    for i = 1, 10 do members[i] = { id = i, name = "Member " .. i, leader = i == 1 } end
    members[2].state, members[3].busy, members[4].far, members[5].title, members[5].titleRarity = "down", "lobby", true, "Night Owl", "epic"
    local c = H.crew({ id = "crew", you = 10, leader = 1, maxSize = 12, members = members, matchmaking = true, invites = {} }, false, 10)
    assert(c.crewOn and c.crewTitle == "CREW" and c.crewCount == "10/12" and c.crewExtra == "MATCHMAKING" and c.crewHasExtra)
    assert(#c.crewRows == 8 and c.crewRows[8].name == "Member 10" and c.crewRows[8].me, "over the cap your own row replaces the last one")
    assert(c.crewMore == "+2 MORE · F1 > CREW" and c.crewHasMore and #c.crewPending == 0)
    assert(c.crewRows[1].leader and not c.crewRows[1].chipOn)
    assert(c.crewRows[2].down and c.crewRows[2].chipAlert and c.crewRows[2].chipText == "DOWN")
    assert(c.crewRows[3].chipText == "BOARD" and c.crewRows[3].chipHasIcon and c.crewRows[3].chipIcon ~= "")
    assert(c.crewRows[4].far and c.crewRows[4].chipDim and c.crewRows[4].chipText == "FAR")
    assert(c.crewRows[5].hasTitle and c.crewRows[5].titleColor == "#B36BFF" and not c.crewRows[1].hasTitle)
    -- alone with invitations out
    c = H.crew({ id = "crew", you = 1, maxSize = 4, members = { members[1] }, pending = { { id = 5, name = "A" }, { id = 6, name = "B" }, { id = 7, name = "C" }, { id = 8, name = "D" } } }, nil, 1)
    assert(#c.crewRows == 1 and #c.crewPending == 3 and not c.crewHasMore and not c.crewRows[1].far)
    assert(not H.crew({ invites = {}, maxSize = 4 }, nil, 1).crewOn and not H.crew(nil, nil, 1).crewOn)
    -- a mission: operators with health and armor; a solo run leaves the frame out
    local squad = { { id = 1, name = "V", host = true, health = 20, maxHealth = 100, armor = 250, state = "alive" },
        { id = 9, name = "Stranger", host = false, health = 0, maxHealth = 100, armor = 0, state = "recovering" } }
    c = H.crew({ id = "crew", leader = 2, maxSize = 4, members = { { id = 1, name = "V" }, { id = 2, name = "T" } } }, { running = true, title = "Heist", squad = squad }, 1)
    assert(c.crewOn and c.crewTitle == "CREW" and c.crewCount == "2" and c.crewExtra == "HEIST" and #c.crewRows == 0 and #c.crewOps == 2)
    assert(c.crewOps[1].me and c.crewOps[1].low and c.crewOps[1].hp == "20.0%" and c.crewOps[1].armor == "100.0%" and not c.crewOps[1].crown and c.crewOps[1].health == "20")
    assert(c.crewOps[2].stranger and c.crewOps[2].recovering and c.crewOps[2].alertOn and c.crewOps[2].alert == "UP SOON")
    c = H.crew(nil, { running = true, title = "Heist", squad = squad }, 1)
    assert(c.crewTitle == "OPERATORS" and c.crewOps[1].crown and not c.crewOps[2].stranger)
    assert(not H.crew(nil, { running = true, title = "Solo", squad = { squad[1] } }, 1).crewOn)
    assert(not H.crew(nil, { running = false, title = "Heist" }, 1).crewOn)

    local party = { maxSize = 4, inviteSeconds = 60, keys = { accept = "Y", decline = "N" },
        invites = { { party = "p1", from = 3, fromName = "Judy Alvarez", expiresInMs = 45000 }, { party = "p2", from = 4, fromName = "Panam", expiresInMs = 50000 } } }
    local i = H.invite(party, 14200)
    assert(i.inviteOn and i.inviteFrom == "Judy Alvarez" and i.inviteMore == " +1 more in F1 > Crew." and i.inviteSecs == "31s" and i.inviteBar == "51.3%", i.inviteBar)
    i = H.invite(party, 99000, { accept = "F5" })
    assert(i.inviteSecs == "0s" and i.inviteBar == "0.0%" and i.inviteAccept == "F5" and i.inviteDecline == "N")
    assert(not H.invite({ invites = {} }, 0).inviteOn and not H.invite(nil, 0).inviteOn)
end

-- ---- Hotbar, WalkFlash, icons -----------------------------------------------------------------
do
    local state = { ready = true, visible = true, showKey = "TAB", slotKeys = { "1", "2", "3", "4", "MOUSE4" }, items = {
        { slot = 2, count = 3, label = "Burrito", icon = "sandwich", image = "img/items/burrito.png" },
        { slot = 4, count = 1, label = "Lexington", icon = "package", category = "weapon" },
        { slot = 5, count = 1, label = "Jacket", icon = "shirt", image = "https://cdn.open77.dev/assets/wardrobe/v1/icons/f/0123456789abcdef.webp" },
        { slot = 9, count = 1, label = "Pocket", icon = "box" } } }
    local h = H.hotbar(state, nil)
    assert(h.hbOn and #h.hbSlots == 5 and h.hbHint == "QUICK USE · HOLD TAB" and not h.hbHintError)
    assert(not h.hbSlots[1].filled and h.hbSlots[1].key == "1" and h.hbSlots[5].key == "MOUSE4")
    assert(h.hbSlots[2].hasImage and h.hbSlots[2].image == "/web/img/items/burrito.png" and h.hbSlots[2].count == "×3" and h.hbSlots[2].label == "Burrito")
    assert(not h.hbSlots[4].hasImage and h.hbSlots[4].icon == LightRpIcons.crosshair, "a weapon without art shows the crosshair")
    assert(not h.hbSlots[5].hasImage and h.hbSlots[5].icon == LightRpIcons.shirt and h.hbSlots[5].image:sub(1, 5) == "data:", "a CDN picture falls back to the icon")
    assert(H.itemImage({ image = "img/items/../secret.png" }) == nil and H.itemImage({ image = "open77://x/web/a.png" }) == nil)
    h = H.hotbar(state, { slot = 2, request = "r1" })
    assert(h.hbSlots[2].active and not h.hbSlots[2].error and not h.hbSlots[4].active)
    h = H.hotbar(state, { slot = 2, request = "r1", error = true, text = "You are not hungry." })
    assert(h.hbSlots[2].error and h.hbHint == "You are not hungry." and h.hbHintError)
    assert(not H.hotbar({ ready = true, visible = false, items = {} }, nil).hbOn and not H.hotbar(nil, nil).hbOn)

    local w = H.walk({ mode = "slow", label = "Slow walk", speed = 1.25, index = 3, count = 3 })
    assert(w.wfLabel == "Slow walk" and w.wfPace == "1.2 M/S" or w.wfPace == "1.3 M/S", w.wfPace)
    assert(#w.wfCells == 3 and w.wfCells[1].on and not w.wfCells[2].on and w.wfCells[3].h == "16dp")
    w = H.walk({ mode = "run", label = "Run" })
    assert(w.wfPace == "FULL PACE" and w.wfCells[3].on)

    assert(H.icon("no-such-glyph") == LightRpIcons.package and H.icon(nil) == LightRpIcons.package)
    assert(H.icon("bomb") ~= H.icon("package"))
end

-- ---- wiring: the host's traffic reaches the document --------------------------------------------
do
    -- before the documents exist the values are kept, and the document starts from them
    N.patchState({ character = { status = "active", playerId = 1 }, needs = { food = 80, drink = 15 },
        rental = { active = { remainingMs = 700000, extensionsLeft = 0 } } })
    N.page("lightrp:ui:grenades", { kind = "state", state = { ready = true, selected = "frag", count = 2, label = "Frag" } })
    N.page(E.page.hud, { ready = true, health = { value = 100, max = 100 }, stamina = { value = 50, max = 100 }, armor = 0,
        vehicle = { active = false }, weapon = { active = false, externalTop = 282 } })
    assert(created == nil)
    assert(N.start() == true and created and created.document == "ui/native/hud.rml" and created.layer == "hud")
    local initial = created.models.hud
    assert(initial.hp == "100" and initial.wt == "15" and initial.warnText == "Thirsty" and initial.grOn and initial.grCount == "2")
    assert(initial.rentOn and initial.rentClock == "11:40" and initial.gapOn and initial.gapHeight == "115dp", initial.gapHeight)
    assertRows(initial)
    for name, value in pairs(H.defaults()) do assert(initial[name] ~= nil, name .. " is missing from the created model") end

    advance(150) -- the shell: ready, nothing owns the screen
    assert(merged.ready == true and merged.hidden == false)

    -- a hit: the dial drops and the loss floats over it for 1.4 s
    N.page(E.page.hud, { ready = true, health = { value = 64, max = 100 }, stamina = { value = 50, max = 100 }, armor = 0, vehicle = { active = false } })
    assert(merged.hp == "64" and merged.hpTrim == 0.64 and merged.deltaText == "-36" and merged.deltaLoss == true and merged.deltaOn == false)
    advance(60)
    assert(merged.deltaOn == true)
    advance(1500)
    assert(merged.deltaOn == false)

    -- the rental clock counts down by itself
    assert(merged.rentClock ~= nil and merged.rentClock < "11:40", merged.rentClock)

    -- an activity's match hides the needs; its lobby and its end bring them back
    N.patchState({ needs = { food = 10, drink = 15 } })
    assert(merged.warnOn == true and merged.matchOn == false)
    N.page(E.page.activityHud, { op = "show", hud = { title = "Gun game", phase = "lobby" } })
    assert(merged.matchOn == false)
    N.page(E.page.activityHud, { op = "show", hud = { title = "Gun game", phase = "running" } })
    assert(merged.matchOn == true and merged.warnOn == false)
    N.page(E.page.activityHud, { op = "clear" })
    assert(merged.matchOn == false and merged.warnOn == true)

    -- the walk mode: silent on the first sample, a flash on a change
    local function sample(walk)
        N.page(E.page.hud, { ready = true, health = { value = 64, max = 100 }, stamina = { value = 50, max = 100 }, armor = 0, vehicle = { active = false }, walk = walk })
    end
    assert(merged.wfOn == nil)
    sample({ mode = "walk", label = "Walk", speed = 2.5, index = 2, count = 3 })
    advance(60)
    assert(merged.wfOn == true and merged.wfLabel == "Walk" and merged.wfPace == "2.5 M/S" and #merged.wfCells == 3)
    advance(1700)
    assert(merged.wfOn == false)
    sample({ mode = "walk", label = "Walk", speed = 2.5, index = 2, count = 3 })
    advance(100)
    assert(merged.wfOn == false, "the same mode does not flash again")

    -- the quick slots: state, a use, its refusal, and the slot goes dark after 1.8 s
    N.page("lightrp:ui:hotbar", { kind = "state", visible = true, showKey = "TAB", slotKeys = { "1", "2", "3", "4", "5" },
        state = { ready = true, revision = 1, items = { { slot = 1, count = 1, label = "Water", icon = "droplet" } } } })
    assert(merged.hbOn == true and merged.hbSlots[1].filled and merged.hbHint == "QUICK USE · HOLD TAB")
    N.page("lightrp:ui:hotbar", { kind = "activate", slot = 1, request = "hotbar:1" })
    assert(merged.hbSlots[1].active and not merged.hbSlots[1].error)
    N.page("lightrp:ui:hotbar", { kind = "response", slot = 1, request = "other", ok = false, text = "stale" })
    assert(not merged.hbSlots[1].error, "an answer to another request is ignored")
    N.page("lightrp:ui:hotbar", { kind = "response", slot = 1, request = "hotbar:1", ok = false, text = "Not thirsty." })
    assert(merged.hbSlots[1].error and merged.hbHint == "Not thirsty." and merged.hbHintError == true)
    advance(1900)
    assert(not merged.hbSlots[1].active and merged.hbHint == "QUICK USE · HOLD TAB" and merged.hbHintError == false)

    -- a crew invite counts down; the crew frame follows the party
    N.patchState({ party = { maxSize = 4, inviteSeconds = 60, invites = { { party = "p1", from = 3, fromName = "Judy", expiresInMs = 30000 } } } })
    assert(merged.inviteOn == true and merged.inviteSecs == "30s" and merged.inviteBar == "50.0%" and merged.crewOn == false)
    advance(2100)
    assert(merged.inviteSecs == "28s" or merged.inviteSecs == "29s", merged.inviteSecs)
    N.patchState({ party = { id = "p1", you = 1, leader = 3, maxSize = 4, invites = {}, members = { { id = 3, name = "Judy", leader = true }, { id = 1, name = "V" } } } })
    assert(merged.inviteOn == false and merged.crewOn == true and merged.crewCount == "2/4" and merged.crewRows[2].me)

    -- the interact prompt follows the nearest point on screen, and hides off screen
    LightRpInteract = { near = { id = "shop", position = { x = 1, y = 2, z = 3 } } }
    N.page(E.page.interact, { id = "shop", prompt = "Open the shop", key = "E" })
    assert(merged.iaOn == true and merged.iaText == "Open the shop" and merged.iaKey == "E")
    advance(150)
    assert(classes["#interact.is-seen"] == true and styles["#interact.transform"] == "translate(640.0px, 720.0px)", styles["#interact.transform"])
    projected = { x = 0.9, y = 0.5, onScreen = false, distance = 3 }
    advance(50)
    assert(classes["#interact.is-seen"] == false)
    projected = { x = 0.5, y = 0.5, onScreen = true, distance = 3 }
    LightRpActions = { isActive = function() return true end }
    advance(50)
    assert(classes["#interact.is-seen"] == false, "an action in progress keeps the prompt away")
    LightRpActions = nil
    advance(50)
    assert(classes["#interact.is-seen"] == true)
    N.page(E.page.interact, {})
    advance(150)
    assert(merged.iaOn == false and classes["#interact.is-seen"] == false)
end

print("native_hud.test.lua: ok")
