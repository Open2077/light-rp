-- Lab scenes for client/native/activity.lua, parkour.lua, dogtown.lua, medical.lua and
-- toolbars.lua. The payloads are the shapes the cores send: client/core/activity_hud.lua
-- (already normalized), the server's parkour events relayed by client/core/parkour.lua,
-- the `dogtown` / `money` state keys, the medical channel (client/core/medical.lua and
-- death_cover.lua), client/core/freecam.lua and maneki_editor.lua.
--
-- Every scene starts by clearing what the scenes of this file left on screen (the flatline
-- cover reboots out first) and leaves its final state up.
local N = LightRpNative
local E = LightRpEvents
local AH, PK = E.page.activityHud, E.page.parkour
local MEDICAL = "lightrp:ui:medical"

local coverDown = false

local function clear(lab)
    lab.page(AH, { op = "clear", reason = "lab" })
    lab.page(PK, { kind = "ended" })
    lab.page(MEDICAL, { kind = "state", state = { downed = false } })
    lab.page(MEDICAL, { kind = "cover", down = false })
    lab.page(E.page.freecam, { active = false })
    lab.page(E.page.maneki, { active = false })
    lab.state({ dogtown = { enabled = false }, money = { cash = 18450, bank = 96200, currency = "€$" } })
    if coverDown then coverDown = false; lab.wait(1300) end -- the reboot (1.1 s)
    lab.wait(150)
end

-- ---------------------------------------------------------------------------------------
-- activity
local HINTS = { { key = "TAB", label = "Scores" }, { key = "F6", label = "Leave" } }
local NAMES = { "Vex", "Lab Runner", "Rogue_77", "Mako", "Jinx", "Sable", "Dex", "Nomad", "Kiroshi", "Tygr", "Halo", "Blitz" }

local function rows(count, own)
    local out = {}
    for i = 1, count do
        out[i] = { name = NAMES[i] or ("Player " .. i), values = { tostring(math.max(0, 14 - i)), tostring(i + 1), tostring((14 - i) * 100) },
            self = i == own or nil, team = 1 + (i % 2) }
    end
    return out
end

local function arena(phase, extra)
    local hud = {
        activity = "arena:tdm", title = "Team Deathmatch", subtitle = "Kabuki Market · first to 30", phase = phase,
        teams = { { name = "Tyger Claws", color = "danger", score = "12", self = true }, { name = "Maelstrom", color = "info", score = "9" } },
        hints = HINTS,
    }
    for k, v in pairs(extra or {}) do hud[k] = v end
    return { op = "show", hud = hud }
end

HudLab.scene("activity-lobby", function(lab)
    clear(lab)
    -- a lobby: header, stats, the roster, hints
    lab.page(AH, { op = "show", hud = {
        activity = "arena:tdm", title = "Team Deathmatch", subtitle = "Kabuki Market · waiting for players", phase = "lobby",
        timer = { remainingMs = 45000, label = "STARTS" },
        stats = { { label = "Players", value = "6 / 8" }, { label = "Mode", value = "TDM" } },
        scoreboard = { rows = { { name = "Vex", team = 1 }, { name = "Lab Runner", self = true, team = 1 }, { name = "Rogue_77", team = 2 }, { name = "Mako", team = 2 } } },
        teams = { { name = "Tyger Claws", color = "danger", score = "0", self = true }, { name = "Maelstrom", color = "info", score = "0" } },
        hints = HINTS,
    } })
    lab.wait(2500)
    -- beside a work order: the order keeps its slot, the hints move under the header
    lab.state({ jobRun = { active = true } })
    lab.wait(2500)
    lab.state({ jobRun = false })
    -- the queue panel and a mission chip hold the top: the header drops (52 dp, then 92 dp)
    lab.state({ fixerGig = { id = "lab" } })
    lab.wait(1500)
    lab.state({ queue = { v = 1, id = "other", label = "Street race", state = "waiting", sinceMs = 0, source = "provider" } })
    lab.wait(1500)
    lab.state({ fixerGig = false, queue = false })
end)

HudLab.scene("activity-countdown", function(lab)
    clear(lab)
    lab.page(AH, arena("countdown")) -- no countdown value yet: GET READY
    lab.wait(2000)
    lab.page(AH, arena("countdown", { countdown = 8000 })) -- STARTS IN 0:08 ... then 5 4 3 2 1 GO
    lab.wait(9200)
    lab.page(AH, arena("running", { timer = { remainingMs = 600000, label = "ROUND 1" } }))
end)

HudLab.scene("activity-running", function(lab)
    clear(lab)
    -- two teams around the clock, an objective, stats, bars, a table longer than its window
    lab.page(AH, arena("running", {
        timer = { remainingMs = 14000, label = "ROUND 2" }, -- under 10 s the clock turns red and blinks
        objective = "Hold the market stalls until the timer runs out",
        stats = { { label = "Kills", value = "7" }, { label = "Deaths", value = "3" }, { label = "Streak", value = "4" } },
        progress = { { id = "a", label = "Point A", value = 0.72, tone = "success" }, { id = "b", label = "Point B", value = 0.31, tone = "danger" } },
        scoreboard = { columns = { "K", "D", "SCORE" }, rows = rows(12, 10) },
    }))
    lab.wait(800)
    -- the feed fills up to five, the oldest leaves first
    local kills = {
        { text = "Vex took down Rogue_77", tone = "accent" }, { text = "Mako took down Jinx", tone = "danger" },
        { text = "You took down Mako", tone = "success" }, { text = "Sable captured Point A", tone = "info" },
        { text = "Dex left the match" }, { text = "Rogue_77 took down Vex", tone = "danger" }, { text = "You took down Rogue_77", tone = "success" },
    }
    for _, item in ipairs(kills) do
        lab.page(AH, { op = "push", kind = "feed", item = item })
        lab.wait(450)
    end
    lab.wait(1500)
    -- three teams: chips under the strip; a race clock counting up to the hundredth
    lab.page(AH, { op = "show", hud = {
        activity = "race:circuit", title = "Street Race", subtitle = "Watson loop · lap 2 / 3", phase = "running",
        timer = { remainingMs = 83450, label = "TIME", countUp = true },
        teams = { { name = "Alpha", color = "#ff7a1a", score = "41", self = true }, { name = "Bravo", color = "info", score = "38" }, { name = "Charlie", color = "success", score = "22" } },
        objective = "Checkpoint 7 / 12",
        stats = { { label = "Position", value = "2 / 8" }, { label = "Best lap", value = "1:02.41" } },
        progress = { { id = "lap", value = 0.58 } },
        scoreboard = { columns = { "GAP" }, rows = { { name = "Vex", values = { "-" } }, { name = "Lab Runner", values = { "+1.24" }, self = true }, { name = "Mako", values = { "+3.80" } } } },
        hints = { { key = "R", label = "Reset" } },
    } })
end)

HudLab.scene("activity-banner", function(lab)
    clear(lab)
    lab.page(AH, arena("running", { timer = { remainingMs = 240000, label = "ROUND 2" } }))
    for _, item in ipairs({
        { title = "Round 2", text = "First to 30 kills", tone = "accent", durationMs = 2500 },
        { title = "Point lost", text = "Maelstrom holds Point B", tone = "danger", durationMs = 2500 },
        { title = "Reinforcements", text = "Two players joined your team", tone = "info", durationMs = 2500 },
        { title = "Point captured", tone = "success", durationMs = 6000 }, -- stays up at the end of the scene
    }) do
        lab.page(AH, { op = "push", kind = "banner", item = item })
        lab.wait(item.durationMs < 6000 and item.durationMs + 300 or 800)
    end
end)

HudLab.scene("activity-result", function(lab)
    clear(lab)
    lab.page(AH, arena("ended", { timer = { remainingMs = 0, label = "ROUND 2" } }))
    -- a word placement, then a first place with its lines and the life bar
    lab.page(AH, { op = "push", kind = "result", item = { title = "Match lost", placement = "DNF", subtitle = "Disconnected players forfeit", durationMs = 2500 } })
    lab.wait(2800)
    lab.page(AH, { op = "push", kind = "result", item = {
        title = "Tyger Claws win", placement = 1, subtitle = "Team Deathmatch · Kabuki Market",
        lines = { { label = "Kills", value = "14" }, { label = "Deaths", value = "5" }, { label = "Score", value = "2,350" },
            { label = "Reward", value = "€$ 1,200" }, { label = "Reputation", value = "+40" } },
        durationMs = 12000,
    } })
    lab.wait(600)
    lab.page(AH, { op = "clear", reason = "cleared" }) -- the owner closes its HUD: the card keeps its time
end)

-- ---------------------------------------------------------------------------------------
-- parkour
local function course()
    local checkpoints = {}
    for i = 1, 6 do checkpoints[i] = { x = -1200 + i * 18, y = 1500 + i * 9, z = 40 + i * 3, radius = 3 } end
    return { id = "rooftop-momentum", name = "Rooftop Momentum", difficulty = "hard", revision = 4,
        start = { x = -1200, y = 1500, z = 40, radius = 3, heading = 90 }, checkpoints = checkpoints,
        finish = { x = -1070, y = 1570, z = 62, radius = 3 }, timeLimit = 0, length = 412 }
end
local function runEvent(attempt)
    return { kind = "run", phase = "loading", course = course(), attempt = attempt,
        best = { timeMs = 48320, splits = "6100,13250,21900,29480,37010,43600" },
        record = { timeMs = 44870, name = "Vex", splits = "5800,12400,20100,27300,34800,40900" },
        music = { file = "audio/parkour-rooftop-momentum.webm", volume = 0.05 } }
end

HudLab.scene("parkour-banner", function(lab)
    clear(lab)
    lab.page(PK, runEvent(1)) -- loading: the header at 0.00, ON YOUR MARK, the keys
end)

HudLab.scene("parkour-countdown", function(lab)
    clear(lab)
    lab.page(PK, runEvent(2))
    lab.wait(900)
    lab.page(PK, { kind = "countdown", goInMs = 3000, attempt = 2 })
    lab.wait(3000)
    lab.page(PK, { kind = "go", attempt = 2 }) -- GO held 1.1 s, the clock runs
    lab.wait(1500)
end)

HudLab.scene("parkour-run", function(lab)
    clear(lab)
    lab.page(PK, runEvent(3))
    lab.page(PK, { kind = "countdown", goInMs = 0, attempt = 3 })
    lab.page(PK, { kind = "go", attempt = 3 })
    local elapsed = 0
    local function bearing(label, angle, distance, rise)
        lab.page(PK, { kind = "bearing", label = label, angle = angle, distance = distance, rise = rise })
    end
    bearing("CP 1", 40, 31, 4)
    -- ahead of the personal best (green), then behind (red); the arrow turns between the points
    local splits = { { 1, 1400, 1600 }, { 2, 2900, 2700 }, { 3, 4300, 4350 } }
    for i, s in ipairs(splits) do
        lab.wait(s[2] - elapsed)
        elapsed = s[2]
        lab.page(PK, { kind = "cp", index = s[1], total = 6, elapsedMs = s[2], bestMs = s[3], recordMs = s[3] - 300, attempt = 3 })
        bearing("CP " .. (s[1] + 1), i % 2 == 0 and -70 or 110, 24 + i * 6, i == 2 and -6 or 9)
        lab.wait(250)
        bearing("CP " .. (s[1] + 1), i % 2 == 0 and -20 or 35, 18 + i * 6, i == 2 and -6 or 9)
        elapsed = elapsed + 250
    end
    lab.wait(2700) -- the delta flash goes
    lab.page(PK, { kind = "respawn", reason = "fell", checkpoint = 3 }) -- the yellow info flash
    lab.wait(1200)
    bearing("FINISH", 5, 12, 1) -- green, no rise under 2 m
end)

-- ---------------------------------------------------------------------------------------
-- dogtown (state keys `dogtown` and `money`)
local RULES = { mode = "bag", share = 0.15, min = 500, max = 7500, bonus = 0.25, bonusDailyCap = 20000, reserveSeconds = 60,
    tagSeconds = 20, pairCooldownMinutes = 10, stake = 2500, graceSeconds = 30, gankCrew = 4, gankFactor = 0.5, underdogBonus = 0.25,
    bountyStreak = 5, bountyPerKill = 400, bountyMax = 4000, protectionSeconds = 45 }
local STATS = { week = { kills = 6, deaths = 4, looted = 9200, bestStreak = 3 }, total = { kills = 41, deaths = 37, looted = 61800, bestStreak = 6 } }

local function dogtown(extra)
    local d = { enabled = true, label = "Dogtown", inside = true, tagged = false, tagEndsInMs = 0, armed = true,
        protected = false, protectedInMs = 0,
        stake = { required = 2500, cash = 18450, missing = 0, short = false, evictInMs = 0 },
        streak = 0, bounty = false, bountyReward = 0, bounties = 1, bonusToday = 1250, rules = RULES, mine = STATS,
        top = { { rank = 1, name = "Vex", kills = 19, deaths = 6, looted = 31200 } }, week = 45 }
    for k, v in pairs(extra or {}) do d[k] = v end
    return { dogtown = d }
end

HudLab.scene("dogtown-outside", function(lab)
    clear(lab)
    -- stepped out while combat-tagged: the dashed tile, the tag counting down from 20 s
    lab.state(dogtown({ inside = false, tagged = true, tagEndsInMs = 20000, streak = 2 }))
end)

HudLab.scene("dogtown-inside", function(lab)
    clear(lab)
    lab.state(dogtown()) -- "PVP ZONE · NO LAW", €$ 2,767 at risk of €$ 18,450
    lab.wait(7000)       -- the entry banner goes: the tile alone
    lab.state(dogtown({ protected = true, protectedInMs = 45000, armed = false })) -- entry protection, green
    lab.wait(2500)
    lab.state({ money = { cash = 900, bank = 96200, currency = "€$" } })
    lab.state(dogtown({ armed = false, stake = { required = 2500, cash = 900, missing = 1600, short = true, evictInMs = 30000 } })) -- no stake, accent
    lab.wait(2500)
    lab.state({ money = { cash = 64200, bank = 96200, currency = "€$" } })
    lab.state(dogtown({ tagged = true, tagEndsInMs = 20000, streak = 5, bounty = true, bountyReward = 2000 })) -- capped loss, tag, bounty
    lab.wait(2500)
    lab.state({ money = { cash = 18450, bank = 96200, currency = "€$" } })
    lab.state(dogtown({ tagged = true, tagEndsInMs = 20000, streak = 3 })) -- tag and a streak
end)

HudLab.scene("dogtown-banner", function(lab)
    clear(lab) -- outside: the next push is an entry
    lab.state(dogtown())
    lab.wait(7000) -- 6 s up, a 0.5 s fade
    -- the two other banners: entry protection, then no stake
    lab.state(dogtown({ inside = false }))
    lab.wait(200)
    lab.state(dogtown({ protected = true, protectedInMs = 45000, armed = false }))
    lab.wait(3500)
    lab.state(dogtown({ inside = false }))
    lab.wait(200)
    lab.state({ money = { cash = 900, bank = 96200, currency = "€$" } })
    lab.state(dogtown({ armed = false, stake = { required = 2500, cash = 900, missing = 1600, short = true, evictInMs = 30000 } }))
end)

-- ---------------------------------------------------------------------------------------
-- medical
local function cover(lab, down)
    coverDown = down
    lab.page(MEDICAL, { kind = "cover", down = down, revision = 12, cause = down and "damage" or nil })
end

HudLab.scene("medical-cover", function(lab)
    clear(lab)
    -- an arena death: the cover alone (FLATLINED readout), the match HUD above it
    lab.page(AH, arena("running", { timer = { remainingMs = 180000, label = "ROUND 2" } }))
    lab.wait(600)
    cover(lab, true)
    lab.wait(3500)
    cover(lab, false) -- the reboot
    lab.wait(1600)
    cover(lab, true)  -- and down again: left on screen; the next scene reboots it out
end)

-- The medical document, found by its watched button (N.docs holds every document).
local function medicalRects()
    for _, doc in ipairs(N.docs or {}) do
        local ok, snapshot = pcall(doc.state, doc)
        if ok and type(snapshot) == "table" and type(snapshot.rects) == "table"
            and (snapshot.rects["#md-ask"] or snapshot.rects["#md-confirm"] or snapshot.rects["#md-keep"]) then
            return snapshot.rects, tonumber(snapshot.width) or 0, tonumber(snapshot.height) or 0
        end
    end
    return nil
end

-- Plays the pointer the module reads (Open77.input.pointer / isDown("mouse1")) onto one of
-- its buttons: the lab has no page holding a cursor. Restores the real reads afterwards.
local function pointAt(lab, selector, click)
    local rects, width, height = medicalRects()
    local r = rects and rects[selector]
    if not r or (r.width or 0) <= 0 or width <= 0 or height <= 0 then
        lab.log("medical: no layout rect for " .. selector .. " (doc:state().rects): the button cannot be driven from the lab")
        return false
    end
    local input = Open77.input
    local realPointer, realDown = input.pointer, input.isDown
    local held = false
    local x, y = (r.x + r.width / 2) / width, (r.y + r.height / 2) / height
    local ok = pcall(function()
        input.pointer = function() return x, y, "overlay" end
        input.isDown = function(control)
            if tostring(control):lower() == "mouse1" then return held end
            return realDown(control)
        end
    end)
    if not ok or input.pointer == realPointer then
        lab.log("medical: Open77.input is read-only here: move the real cursor over the button and click")
        return false
    end
    lab.wait(700) -- hover
    if click then
        held = true
        lab.wait(250) -- pressed
        held = false
        lab.wait(250) -- released on the button: the action
    end
    input.pointer, input.isDown = realPointer, realDown
    return true
end

HudLab.scene("medical-down", function(lab)
    clear(lab)
    cover(lab, true)
    lab.wait(900)
    local function state(extra)
        local s = { downed = true, persisted = true, phase = "downed", remainingMs = 0, canGiveUp = false }
        for k, v in pairs(extra or {}) do s[k] = v end
        lab.page(MEDICAL, { kind = "state", state = s })
    end
    state({ persisted = false, remainingMs = 180000 })                   -- "Saving medical state…"
    lab.wait(1500)
    state({ remainingMs = 125000 })                                       -- "Hospital transfer unlocks in" 2:05, counting
    lab.wait(2500)
    state({ remainingMs = 121000, receiving = true })                     -- someone is stabilizing you
    lab.wait(2000)
    state({ phase = "reviving", remainingMs = 4000 })                     -- RECOVERING
    lab.wait(1800)
    state({ phase = "hospital", remainingMs = 3000 })                     -- TRANSFER
    lab.wait(1800)
    state({ remainingMs = 0, canGiveUp = true, bill = 0, error = "The hospital line is busy. Try again in a moment." }) -- an error line
    lab.wait(1800)
    state({ remainingMs = 0, canGiveUp = true, bill = 350 })              -- "Give up and go to hospital"
    lab.wait(1200)
    -- hover, press and release on the button: the confirm state, with the clinic's bill
    if pointAt(lab, "#md-ask", true) then
        lab.wait(400)
        pointAt(lab, "#md-keep", false)    -- the secondary button hovered
        pointAt(lab, "#md-confirm", false) -- the primary one; not clicked: the confirm state stays up
    end
end)

-- ---------------------------------------------------------------------------------------
-- tool bars
local FREECAM_KEYS = { toggle = "F5", forward = "forward", back = "back", left = "strafe_left", right = "strafe_right",
    up = "SPACE", down = "C", boost = "SHIFT", slow = "CTRL", reset = "R", hints = "H", exit = "BACKSPACE" }

HudLab.scene("freecam-bar", function(lab)
    clear(lab)
    local function send(extra)
        local s = { active = true, phase = "active", paused = false, hints = true, keys = FREECAM_KEYS, radius = 60, distance = 0, speed = 6, fov = 60 }
        for k, v in pairs(extra) do s[k] = v end
        lab.page(E.page.freecam, s)
    end
    send({ hints = false })               -- the reminder hidden: the small tag, fading back after 3.5 s
    lab.wait(5000)
    send({ phase = "preparing" })         -- the bar rises, the keys one after the other
    lab.wait(1500)
    for step = 0, 20 do                   -- the lens leaves the character: gauge, near (orange), limit (red)
        local distance = math.min(60, step * 3.2)
        send({ distance = math.floor(distance * 10 + 0.5) / 10, speed = step < 12 and 6 or 18, fov = step < 16 and 60 or 35 })
        lab.wait(160)
    end
    lab.wait(1500)
    send({ distance = 60, paused = true }) -- a menu is open
    lab.wait(1800)
    send({ distance = 51.4, speed = 1.5, fov = 35 }) -- left on screen: near the limit
end)

HudLab.scene("maneki-bar", function(lab)
    clear(lab)
    local function send(extra)
        local s = { active = true, scale = 1, yaw = 0, aim = false, nearby = 3 }
        for k, v in pairs(extra or {}) do s[k] = v end
        lab.page(E.page.maneki, s)
    end
    send()                                                        -- nothing aimed
    lab.wait(1800)
    send({ aim = true, yaw = 45 })                                -- ready to place
    lab.wait(1800)
    send({ aim = true, yaw = 45, nearby = 4, message = "Cat #128 hidden here.", ok = true })
    lab.wait(1800)
    send({ aim = true, yaw = 90, scale = 2.5, nearby = 4, hovered = "Cat #128", hoveredFound = true })
    lab.wait(1800)
    send({ aim = true, yaw = 90, scale = 2.5, nearby = 4, hovered = "Cat #128", message = "Too close to another cat (2 m at least).", ok = false })
end)
