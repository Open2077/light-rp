-- Lab scenes of client/native/notices.lua, announce.lua, safezone_tile.lua and
-- guide_pointer.lua. Each scene first clears what the others of this file left.
--
-- What the framework would provide and the lab does not, stubbed here (all of it is looked
-- up at run time by the modules, so a stub defined after them works):
--   * the safe-zone tile reads LightRpSafezones.presenceZone() and Open77.character.state():
--     the scene replaces LightRpSafezoneTile.current (the tile's own "am I in a zone") and
--     gives LightRpSafezoneGeometry.RULES the rules the hint lists;
--   * the guide pointer projects the objective with Open77.camera.project: without a world
--     the scene answers for it while the "in view" part plays.
local E = LightRpEvents
local PAGE_ANNOUNCE = "lightrp:ui:announce"

-- ---- clearing -------------------------------------------------------------------------
local zone = nil -- what the safe-zone scene says the player stands in
local projection = nil -- what the guide scene says the objective projects to
local realProject = nil

local function clearNotices(lab)
    local notices = LightRpNativeNotices
    if not notices then return end
    notices.setLeft(nil)
    notices.suppress("arrival-tour", false)
    -- the module has no "clear": six one-millisecond notices push the old ones out and expire at once
    if notices.count() > 0 then
        for _ = 1, 6 do notices.push({ kind = "info", source = "LAB", durationMs = 1 }) end
        lab.wait(450)
    end
end

local function clearAnnounce(lab)
    for _, speaker in ipairs({ 7, 12 }) do lab.page(PAGE_ANNOUNCE, { kind = "end", speaker = speaker }) end
    lab.page(E.page.arrivalTour, false)
end

local function clearGuide(lab)
    projection = nil
    if realProject ~= nil and type(Open77.camera) == "table" then pcall(function() Open77.camera.project = realProject or nil end) end
    lab.page(E.page.tutorialGuide, { hide = true })
    lab.state({ tutorial = { active = false } })
end

local function clearZone(lab)
    zone = nil
    local tile = LightRpSafezoneTile
    if tile and tile.ready then tile.sent = nil; pcall(tile.sync, true) end
end

local function clearAll(lab)
    lab.dialog("inventory", false)
    lab.menu(false)
    clearNotices(lab)
    clearAnnounce(lab)
    clearGuide(lab)
    clearZone(lab)
    lab.wait(300)
end

-- =======================================================================================
-- notices
-- =======================================================================================
-- One of each kind, staggered: the wipe-in, the stack growing from the middle, the seventh
-- pushing the oldest out. The last six stay for 30 s.
HudLab.scene("notices-kinds", function(lab)
    clearAll(lab)
    local kinds = {
        { kind = "info", title = "Server restart", body = "The city restarts at 04:00. Park your vehicle before then." },
        { kind = "success", title = "Vehicle stored", body = "Your Quadra Turbo-R is back in the Megabuilding H10 garage." },
        { kind = "warning", title = "Fuel low", body = "12 % left. The nearest station is 400 m away." },
        { kind = "error", title = "Not enough eddies", body = "You need €$ 1,250 more to rent this vehicle." },
        { kind = "police", title = "10-31 in progress", body = "Armed robbery reported at 2nd Amendment, Kabuki. Units respond." },
        { kind = "money", title = "Paycheck", body = "+ €$ 240 from Night City Medical.", source = "BANK" },
        { kind = "item", title = "Item received", body = "2 x MaxDoc Mk.1 added to your backpack." },
        { kind = "message", title = "Viktor Vektor", body = "Come by the clinic when you can. I have something for you." },
        { kind = "contract", title = "Gig offered", body = "Regina Jones: a courier run to Japantown, €$ 900." },
        { kind = "staff", title = "Staff message", body = "A moderator is looking at your report. Stay where you are." },
    }
    for _, notice in ipairs(kinds) do
        notice.durationMs = 30000
        lab.page(E.page.notice, notice)
        lab.wait(450)
    end
    -- no title, no body, the kind's own tag as the source, a short life: the bar and the wipe-out
    lab.wait(600)
    lab.page(E.page.notice, { kind = "info", body = "A notice without a title, gone in three seconds.", durationMs = 3000 })
    lab.wait(3600)
end)

-- Action results: ok, denied, and the dailies.claim exception (nothing but its money notice).
HudLab.scene("notices-result", function(lab)
    clearAll(lab)
    lab.page(E.page.result, { ok = true, text = "Vehicle rented for 30 minutes.", action = "rental.rent" })
    lab.wait(700)
    lab.page(E.page.result, { ok = false, text = "You are too far from the desk.", action = "rental.rent" })
    lab.wait(700)
    -- dailies.lua sends the money notice itself; the successful result must add nothing
    lab.page(E.page.notice, { kind = "money", title = "Contract complete", body = "+ €$ 1,500", source = "FIXER", durationMs = 12000 })
    lab.page(E.page.result, { ok = true, text = "Reward claimed.", action = "dailies.claim" })
    lab.wait(700)
    lab.log("notices-result: three cards expected (OK, DENIED, money), " .. tostring(LightRpNativeNotices and LightRpNativeNotices.count()) .. " in the lane with what was left")
    -- a failed claim does show
    lab.page(E.page.result, { ok = false, text = "This contract is not finished yet.", action = "dailies.claim" })
    lab.wait(500)
end)

-- The lane right of the crew frame (the crew document's call), then back on the safe margin.
HudLab.scene("notices-lane-left", function(lab)
    clearAll(lab)
    lab.page(E.page.notice, { kind = "message", title = "Crew", body = "Jackie joined your crew.", durationMs = 20000 })
    lab.page(E.page.notice, { kind = "info", title = "Lane", body = "Now at the safe margin (32).", durationMs = 20000 })
    lab.wait(1500)
    LightRpNativeNotices.setLeft(284)
    lab.page(E.page.notice, { kind = "info", title = "Lane", body = "Stepped right of the crew frame (284).", durationMs = 20000 })
    lab.wait(3000)
    LightRpNativeNotices.setLeft(nil)
    lab.page(E.page.notice, { kind = "info", title = "Lane", body = "Back at the safe margin.", durationMs = 20000 })
    lab.wait(500)
end)

-- =======================================================================================
-- announcements
-- =======================================================================================
-- Somebody else on air within 150 m: the signal opens, follows a voice for ~6 s (syllables,
-- a silence in the middle), then our own cast (ON AIR / YOU / listeners), then both end.
HudLab.scene("announce-halo", function(lab)
    clearAll(lab)
    lab.page(PAGE_ANNOUNCE, { kind = "cast", speaker = 7, name = "Nightwolf", mode = "radius", radius = 150, self = false, audience = 14 })
    lab.wait(900) -- on air, not talking yet: the idle trace
    local t = 0
    while t < 6000 do
        local s = t / 1000
        local talking = not (s > 2.6 and s < 3.4) -- a breath
        local level = talking and math.max(0.05, math.min(1, 0.45 + 0.35 * math.sin(s * 9.0) + 0.2 * math.sin(s * 23.0 + 1.3))) or 0
        lab.page(PAGE_ANNOUNCE, { kind = "level", speaker = 7, level = math.floor(level * 1000 + 0.5) / 1000, talking = talking })
        lab.wait(50)
        t = t + 50
    end
    lab.page(PAGE_ANNOUNCE, { kind = "level", speaker = 7, level = 0, talking = false })
    lab.wait(600)
    -- the speaker's own: server-wide
    lab.page(PAGE_ANNOUNCE, { kind = "end", speaker = 7 })
    lab.page(PAGE_ANNOUNCE, { kind = "cast", speaker = 12, name = "Lab Runner", mode = "server", self = true, audience = 86 })
    t = 0
    while t < 2500 do
        local s = t / 1000
        lab.page(PAGE_ANNOUNCE, { kind = "level", speaker = 12, level = 0.5 + 0.4 * math.sin(s * 11.0), talking = true })
        lab.wait(50)
        t = t + 50
    end
    lab.page(PAGE_ANNOUNCE, { kind = "end", speaker = 12 })
    lab.wait(1500) -- it retracts
end)

-- The staff broadcast: tears in, the text typed out, signed, the bar draining 8 s, collapses
-- out; a second, unsigned one queues behind it and stays its 4 s.
HudLab.scene("announce-staff", function(lab)
    clearAll(lab)
    lab.page(E.page.staffAnnounce, { title = "Server event", from = "Nightwolf", durationMs = 8000,
        text = "Street race tonight at 21:00, start line at the Afterlife car park. €$ 25,000 to the winner, repairs are on the house." })
    lab.page(E.page.staffAnnounce, { text = "Restart in five minutes.", durationMs = 4000 })
    lab.wait(8000 + 520 + 1800) -- the first one's whole life, then the second one settled
end)

-- The arrival tour's caption: bars, the title wiped in, the contacts one by one, the time
-- bar; the HUD and the notices step aside. It plays 9 s and leaves on the "false".
HudLab.scene("announce-tour", function(lab)
    clearAll(lab)
    lab.page(E.page.notice, { kind = "info", title = "Tour", body = "This notice hides while the tour plays and comes back after.", durationMs = 20000 })
    lab.wait(800)
    lab.page(E.page.arrivalTour, { title = "THE CROSSING", subtitle = "The central square. Everything starts here.", skip = "SPACE", durationMs = 9000,
        lines = { "Job center: find work, get paid every hour", "Rental desk: your first ride", "Johnny: every question you have" } })
    lab.wait(9000)
    lab.page(E.page.arrivalTour, false)
    lab.wait(900)
end)

-- =======================================================================================
-- the safe-zone tile
-- =======================================================================================
HudLab.scene("safezone-tile", function(lab)
    clearAll(lab)
    local tile = LightRpSafezoneTile
    if not (tile and tile.sync) then
        lab.log("safezone-tile: client/native/safezone_tile.lua is not loaded (its client_script line is not in open77.lua yet)")
        return
    end
    -- the rules of shared/safezones.lua the hint reads (key, default)
    LightRpSafezoneGeometry = LightRpSafezoneGeometry or { RULES = {
        { key = "blockShoot", default = true }, { key = "blockRun", default = false }, { key = "blockJump", default = false },
        { key = "blockMelee", default = true }, { key = "blockGrenades", default = true }, { key = "blockConsumables", default = false },
        { key = "blockReload", default = false }, { key = "blockWeaponWheel", default = false },
    } }
    tile.current = function() return zone end
    local function settle(instant) tile.sent = nil; tile.sync(instant) end

    -- entering a plain zone: the tile pops, "SAFE ZONE" decodes, the default rules type, it folds back
    zone = { id = "crossing", label = "The Crossing" }
    settle(false)
    lab.log("safezone-tile: hint = " .. tile.hint(zone))
    lab.wait(220 + 2600 + 600)
    -- leaving: amber "LEAVING SAFE ZONE", then the tile goes
    zone = nil
    settle(false)
    lab.wait(1500 + 300 + 320 + 500)
    -- a zone with every extra rule: three parts and "+N"
    zone = { id = "hospital", label = "Night City Medical", blockRun = true, blockJump = true, blockConsumables = true, blockReload = true, blockWeaponWheel = true }
    settle(false)
    lab.log("safezone-tile: hint = " .. tile.hint(zone))
    lab.wait(220 + 2600 + 600)
    -- under a dialog it steps aside with the HUD, and comes back resting
    lab.dialog("shop", true)
    lab.wait(900)
    lab.dialog("shop", false)
    lab.wait(400)
    -- left on screen: the resting tile
end)

-- =======================================================================================
-- the guide pointer
-- =======================================================================================
HudLab.scene("guide-pointer", function(lab)
    clearAll(lab)
    lab.state({ tutorial = { active = true, status = "active", key = "lab", step = "jobcenter", title = "Find work",
        objective = { position = { x = -1450.0, y = 1220.0, z = 24.0 }, label = "Job center", radius = 1.5, kind = "talk" } } })
    -- the objective on screen: the lab answers for the camera
    local camera = Open77.camera
    local stubbed = false
    if type(camera) == "table" then
        if realProject == nil then realProject = camera.project or false end
        stubbed = pcall(function() camera.project = function() return projection end end) and camera.project ~= realProject
    end
    if not stubbed then lab.log("guide-pointer: Open77.camera.project cannot be replaced here: the in-view waypoint shows only with a real world; the edge arrow follows") end
    local function way(distance, angle, rise) lab.page(E.page.tutorialGuide, { label = "Job center", distance = distance, angle = angle, rise = rise }) end

    -- in view: the waypoint drifts across the screen as the camera would turn, the distance counts down
    for i = 0, 40 do
        projection = { x = 0.34 + 0.008 * i, y = 0.46 - 0.002 * i, onScreen = true, depth = 1 }
        way(180 - i * 2, 0, i < 20 and 12 or 0) -- "▲ 12 m" for the first half
        lab.wait(60)
    end
    lab.wait(900)
    -- far: kilometres, a way down
    projection = { x = 0.62, y = 0.3, onScreen = true, depth = 1 }
    way(1240, 0, -8)
    lab.wait(1500)
    way(640, 0, -8) -- back under the anchor's 1000 m: the waypoint again
    lab.wait(1500)
    -- off screen: the arrow on the ring, left, right, behind; the distance with the rise
    projection = { x = -0.4, y = 0.5, onScreen = false, depth = 1 }
    for _, step in ipairs({ { 60, 0 }, { 90, 0 }, { 135, 6 }, { -60, 6 }, { -90, 0 }, { -135, -4 }, { 180, -4 } }) do
        way(96, step[1], step[2])
        lab.wait(1100)
    end
    -- within 4 m: nothing, the objective's own prompt takes over
    way(3, 0, 0)
    lab.wait(1200)
    -- left on screen: the arrow, the objective behind on the left (fed again: silent for 3.5 s, it would go)
    for _ = 1, 6 do
        way(42, 150, 5)
        lab.wait(500)
    end
    lab.log("guide-pointer: the feed stops here; the pointer goes by itself after 3.5 s")
end)
