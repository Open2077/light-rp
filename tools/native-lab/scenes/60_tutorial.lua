-- Lab scenes of client/native/tutorial.lua (ui/native/tutorial.rml): the first day's objective
-- card (every step example, the Alt lesson, the way line, the footers), "STEP COMPLETE", the
-- flight to the next stop with the hall map, and the card stepping aside under a dialog.
-- Each scene first clears what the others left; hudlab:all plays them in order.
--
-- The guide pointer (guide_pointer.lua) reads the same state and feed: its edge arrow shows
-- beside the card when the way is fed (the in-view waypoint needs a real camera projection).
local E = LightRpEvents
local KEYS = { menu = "F1", inventory = "I", interact = "E", context = "ALT", lock = "L", skip = "SPACE", way = "G", quit = "F6" }
local MAP = {
    { step = "intro", label = "Arrival Hall", x = 0, y = -101, state = "done" }, { step = "meet", label = "Mara, your guide", x = 0, y = -14, state = "done" },
    { step = "shop", label = "Market stall", x = 24, y = -4, state = "done" }, { step = "bank", label = "Night City Bank", x = 0, y = 27.3, state = "now" },
    { step = "garage", label = "Garage · Rent-a-Ride", x = -33, y = 0, state = "next" }, { step = "station", label = "Fuel station", x = -26, y = -78, state = "next" },
    { step = "collect", label = "Job fair", x = 22, y = -63.6, state = "next" }, { step = "sell", label = "Juno, the buyer", x = 30, y = -78, state = "next" },
}
local OBJECTIVE = { position = { x = -1450.0, y = 1220.0, z = 24.0 }, radius = 2.5, kind = "talk" }

local revision = 0
-- The guide's state as server/modules/tutorial.lua sends it (shared/tutorial.lua's steps).
local function guide(lab, step, extra)
    revision = revision + 1
    local t = { active = true, available = true, status = "active", key = "default", step = step, revision = revision, index = 7, total = 15,
        guide = "Mara", where = "lobby" }
    for k, v in pairs(extra or {}) do t[k] = v end
    lab.state({ tutorial = t })
end
local function objective(label)
    return { position = OBJECTIVE.position, radius = OBJECTIVE.radius, kind = OBJECTIVE.kind, label = label }
end

local function clearAll(lab)
    lab.dialog("tutorial", false)
    lab.dialog("inventory", false)
    lab.menu(false)
    lab.page(E.page.tutorial, { phase = "idle", reveal = false, keys = KEYS })
    lab.page(E.page.tutorialGuide, { hide = true })
    lab.state({ tutorial = { active = false, available = true } })
    lab.wait(400)
end

-- the way, fed as client/core/tutorial_guide.lua does (at least once a second)
local function feedWay(lab, label, ms, from, to, distance)
    local t = 0
    while t < ms do
        local f = t / ms
        lab.page(E.page.tutorialGuide, { label = label, distance = math.floor(distance - f * 20 + 0.5), angle = math.floor(from + (to - from) * f + 0.5), rise = 0 })
        lab.wait(250)
        t = t + 250
    end
end

-- =======================================================================================
-- the card: a step with an objective, its to-do rows (key caps from the bindings), the way
-- line turning, the guide's quote, "Show me the way"
-- =======================================================================================
HudLab.scene("tutorial-card", function(lab)
    clearAll(lab)
    guide(lab, "shop", { index = 7, title = "Your first purchase", demo = "shop", objective = objective("Browse shop"),
        hint = "Walk to the shop east of the square, talk to the vendor and buy a drink.",
        todo = { { text = "Follow the arrow to the vendor" }, { key = "interact", text = "Open the shop" }, { text = "Add a drink, pick cash or bank, confirm" } },
        line = "Shops sell and buy back. Every vendor in the city works like this one. Get yourself something to drink." })
    -- the arrow swings from the left to the right, the distance counts down; then far away
    feedWay(lab, "Browse shop", 5000, 120, -60, 64)
    lab.page(E.page.tutorialGuide, { label = "A destination with a very long name that is cut with an ellipsis", distance = 1240, angle = 10, rise = 0 })
    lab.wait(1500)
    -- the client stops guiding: the line goes after 3.5 s
    lab.log("tutorial-card: the feed stops, the way line goes by itself after 3.5 s")
    lab.wait(4000)
end)

-- =======================================================================================
-- every step example of the card, one step after the other ("STEP COMPLETE" between them)
-- =======================================================================================
HudLab.scene("tutorial-steps", function(lab)
    clearAll(lab)
    local steps = {
        { "identity", { index = 5, demo = "menu", title = "A name in the city", todo = { { key = "menu", text = "Open the player menu" }, { text = "Select Identity" } },
            line = "Keep your own name out of it. Out there, you're the person on that card." } },
        -- no to-do list: the hint, and the step's key in the footer
        { "inventory", { index = 6, demo = "inventory", title = "Travel light", hint = "Close the player menu and open your inventory. Your starter bag contains food and water." } },
        { "shop", { index = 7, demo = "shop", title = "Your first purchase", objective = objective("Browse shop"),
            todo = { { text = "Follow the arrow to the vendor" }, { key = "interact", text = "Open the shop" }, { text = "Add a drink, pick cash or bank, confirm" } } } },
        { "drink", { index = 7, demo = "drink", title = "Take a breath", todo = { { key = "inventory", text = "Open your inventory" }, { text = "Use a drink and stay still until it is finished" } } } },
        { "collect", { index = 13, demo = "collect", title = "Earn it: collect", objective = objective("Supply crates"),
            todo = { { text = "Follow the arrow to the supply crates" }, { key = "interact", text = "Start collecting" }, { text = "Stay still until the crate is yours" } } } },
        { "process", { index = 13, demo = "process", title = "Earn it: process", objective = objective("Workbench"),
            todo = { { text = "Follow the arrow to the workbench" }, { key = "interact", text = "Process the crate" }, { text = "Stay still until the parts are ready" } } } },
        { "sell", { index = 13, demo = "sell", title = "Earn it: sell", objective = objective("Juno, the buyer"),
            todo = { { text = "Follow the arrow to Juno, the buyer" }, { key = "interact", text = "Sell your parts" } } } },
        -- a raw key in the list (F2), no objective: "F1 → First day guide" in the footer
        { "neuralink", { index = 2, title = "Your Neural-Link",
            todo = { { key = "F2", text = "Open your Neural-Link" }, { text = "Install the Kiroshi implant" }, { text = "Wait until it says NEURAL-LINK ONLINE" } } } },
    }
    for _, s in ipairs(steps) do
        guide(lab, s[1], s[2])
        if s[2].objective then lab.page(E.page.tutorialGuide, { label = s[2].objective.label, distance = 38, angle = -25, rise = 0 }) end
        lab.wait(5200) -- every example plays its loop at least once
    end
end)

-- =======================================================================================
-- the Alt lesson (ContextLesson), its four variants, then a practice error
-- =======================================================================================
HudLab.scene("tutorial-context", function(lab)
    clearAll(lab)
    guide(lab, "context_prop", { index = 10, kind = "context", demo = "context", title = "Alt opens the world", objective = objective("Practice crate"),
        todo = { { text = "Stand near the marked crate" }, { key = "context", text = "Keep holding it; left-click the crate" }, { text = "Click Inspect practice crate in the menu" } },
        line = "Keep Alt held while choosing. Releasing it or pressing Escape closes the menu. Objects, cars and people offer different actions." })
    lab.wait(3500)
    guide(lab, "vehicle_unlock", { index = 11, kind = "context", demo = "context", title = "Your keys, your car", objective = objective("Practice car"),
        todo = { { text = "Walk beside the marked practice car" }, { key = "context", text = "Hold and left-click the car" }, { text = "Choose Unlock vehicle" } } })
    lab.wait(3500)
    guide(lab, "vehicle_open", { index = 11, kind = "context", demo = "context", title = "Explore the submenus",
        todo = { { key = "context", text = "Hold and click the car again" }, { text = "Open Trunk & hood → Open trunk" }, { text = "Keep the car parked and stay outside" } } })
    lab.wait(3500)
    guide(lab, "vehicle_close", { index = 11, kind = "context", demo = "context", title = "Leave it as you found it",
        todo = { { key = "context", text = "Hold and click the car" }, { text = "Choose Trunk & hood → Close trunk" } },
        practiceError = "The practice car could not be placed." })
    lab.wait(3500)
end)

-- =======================================================================================
-- the flight to the next stop: bars, the place, the hall from above, the skip key, the time
-- bar running 5.6 s; the card steps aside and slides back after
-- =======================================================================================
HudLab.scene("tutorial-reveal", function(lab)
    clearAll(lab)
    guide(lab, "shop", { index = 7, title = "Your first purchase", objective = objective("Browse shop"), map = MAP,
        todo = { { text = "Follow the arrow to the vendor" }, { key = "interact", text = "Open the shop" } } })
    lab.wait(1500)
    guide(lab, "bank", { index = 8, title = "Your money", place = "Night City Bank", direction = "North of the square", objective = objective("Talk to the banker"), map = MAP,
        todo = { { text = "Follow the arrow to the bank" }, { key = "interact", text = "Talk to Idris" } } })
    lab.page(E.page.tutorial, { phase = "reveal" })
    lab.page(E.page.tutorial, { reveal = { name = "Night City Bank", direction = "North of the square", distance = 46, index = 8, total = 15, durationMs = 5600 } })
    lab.wait(5600)
    lab.page(E.page.tutorial, { reveal = false })
    lab.page(E.page.tutorial, { phase = "idle" })
    lab.wait(1500)
    -- a flight without an index nor a direction (a manual one): "NEXT STOP" alone
    lab.page(E.page.tutorial, { phase = "reveal", reveal = { name = "Night City Bank", distance = 12, durationMs = 3000 } })
    lab.wait(3000)
    lab.page(E.page.tutorial, { phase = "idle", reveal = false })
    lab.wait(800)
end)

-- =======================================================================================
-- the card under the page's dialogs: a conversation (the shell is not ready), the options
-- dialog (the "tutorial" dialog), the inventory (quiet); it slides back in after each
-- =======================================================================================
HudLab.scene("tutorial-hidden", function(lab)
    clearAll(lab)
    guide(lab, "bank", { index = 8, title = "Your money", objective = objective("Talk to the banker"),
        todo = { { text = "Follow the arrow to the bank" }, { key = "interact", text = "Talk to Idris" } } })
    lab.wait(1500)
    guide(lab, "bank", { index = 8, title = "Your money", objective = objective("Talk to the banker"), dialogue = "bank", contact = "Idris",
        lines = { "Welcome to Night City Bank." } })
    lab.dialog("tutorial", true)
    lab.wait(1500)
    lab.dialog("tutorial", false)
    guide(lab, "bank", { index = 8, title = "Your money", objective = objective("Talk to the banker"),
        todo = { { text = "Follow the arrow to the bank" }, { key = "interact", text = "Talk to Idris" } } })
    lab.wait(1500)
    lab.dialog("inventory", true)
    lab.wait(1200)
    lab.dialog("inventory", false)
    lab.wait(1500)
    -- the opening of the first day: nothing over it
    guide(lab, "intro", { index = 1, title = "Your first day" })
    lab.wait(1500)
end)

-- Left on screen (the last scene of hudlab:all): the card with the drink example and the way line.
HudLab.scene("tutorial-rest", function(lab)
    clearAll(lab)
    guide(lab, "drink", { index = 7, demo = "drink", title = "Take a breath", objective = objective("A quiet corner"),
        todo = { { key = "inventory", text = "Open your inventory" }, { text = "Use a drink and stay still until it is finished" } },
        line = "Hunger and thirst drop with time: keep an eye on them, the city won't." })
    feedWay(lab, "A quiet corner", 3000, 40, 20, 30)
end)
