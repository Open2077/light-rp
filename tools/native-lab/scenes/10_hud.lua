-- The gameplay HUD (client/native/hud.lua, ui/native/hud.rml): every state of the document,
-- with the payloads the cores and the server send. Each scene starts from a clean HUD and
-- leaves its last state on screen.
local E = LightRpEvents
local HOTBAR, GRENADES = "lightrp:ui:hotbar", "lightrp:ui:grenades"

-- What the module reads besides the traffic and that the lab does not have.
LightRpInteract = LightRpInteract or { near = nil }                       -- client/core/interact.lua: the nearest point
LightRpCrew = LightRpCrew or { state = { keys = { accept = "Y", decline = "N" } } } -- client/core/crew.lua: the effective keys

local SLOT_KEYS = { "1", "2", "3", "4", "5" }
local function hotbar(items, visible)
    return { kind = "state", visible = visible ~= false, showKey = "TAB", slotKeys = SLOT_KEYS,
        state = { ready = true, inventoryId = "player:1", revision = 4, items = items } }
end
local ITEMS = {
    { slot = 1, name = "burrito", count = 3, label = "Burrito", weight = 0.4, icon = "sandwich", category = "food", usable = true, stack = 10, image = "img/items/burrito.png" },
    { slot = 2, name = "water", count = 12, label = "Water bottle", weight = 0.5, icon = "droplet", category = "drink", usable = true, stack = 20 },
    { slot = 4, name = "bandage", count = 1, label = "Bandage", weight = 0.1, icon = "bandage", category = "medical", usable = true, stack = 10, image = "img/items/bandage.png" },
    { slot = 5, name = "weapon_lexington", count = 1, label = "Lexington x-MOD2 long name", weight = 1.2, icon = "package", category = "weapon", usable = true, stack = 1 },
}
local function member(id, name, extra)
    local m = { id = id, name = name, leader = false, tier = 1 }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
local CREW = {
    member(3, "Judy Alvarez", { leader = true, title = "Night Owl", titleRarity = "epic" }),
    member(1, "Lab Runner", { you = true }),
    member(4, "Panam Palmer", { state = "down" }),
    member(5, "Jackie Welles", { state = "dead" }),
    member(6, "Goro Takemura", { busy = "mission", busyLabel = "The Heist" }),
    member(7, "Kerry Eurodyne", { busy = "lobby", title = "Legend", titleRarity = "legendary" }),
    member(8, "River Ward", { busy = "activity" }),
    member(9, "Misty Olszewski", { far = true }),
    member(10, "Viktor Vektor", { title = "Ripperdoc", titleRarity = "rare" }),
    member(11, "Rogue Amendiares", {}),
}
local RUN = { mode = "run", label = "RUN", index = 1, count = 3 }
local WALK = { mode = "walk", label = "WALK", speed = 1.5, index = 2, count = 3 }
local SLOW = { mode = "slow", label = "SLOW WALK", speed = 0.9, index = 3, count = 3 }

--- A clean HUD: full vitals, on foot, nothing in the corners, no window open.
local function reset(lab)
    lab.menu(false)
    lab.dialog("inventory", false)
    lab.setHud("health", { value = 100, max = 100 })
    lab.setHud("stamina", { value = 100, max = 100 })
    lab.setHud("armor", 0)
    lab.setHud("vehicle", { active = false })
    lab.setHud("weapon", { active = false, externalTop = 0 })
    lab.state({ needs = { food = 82, drink = 64 }, rental = {}, missionQueue = false,
        party = { you = 1, invites = {}, maxSize = 8, inviteSeconds = 60 } })
    lab.page(E.page.activityHud, { op = "clear" })
    lab.page(GRENADES, { kind = "state", state = { ready = true, busy = false, revision = 1, count = 0 } })
    lab.page(HOTBAR, hotbar({}, false))
    LightRpInteract.near = nil
    lab.page(E.page.interact, {})
    lab.wait(250)
end

-- ---- vitals --------------------------------------------------------------------------------
HudLab.scene("hud-vitals", function(lab)
    reset(lab)
    lab.hud({ health = { value = 87, max = 100 }, stamina = { value = 62, max = 100 }, armor = 35 })
    lab.state({ needs = { food = 74, drink = 58 } })
    lab.wait(600)
end)

HudLab.scene("hud-vitals-low", function(lab)
    reset(lab)
    lab.hud({ health = { value = 18, max = 100 }, stamina = { value = 8, max = 100 }, armor = 0 })
    lab.state({ needs = { food = 12, drink = 16 } })   -- "Low health · Hungry · Thirsty"
    lab.wait(600)
end)

HudLab.scene("hud-vitals-critical", function(lab)
    reset(lab)
    -- 10 % and under: the heart blinks; a four-digit armor uses the compact number
    lab.hud({ health = { value = 7, max = 100 }, stamina = { value = 100, max = 100 }, armor = 1250 })
    lab.wait(600)
end)

HudLab.scene("hud-starving", function(lab)
    reset(lab)
    lab.hud({ health = { value = 34, max = 100 } })
    lab.state({ needs = { food = 0, drink = 22, starving = "food", drainPerMinute = 2 } })
    lab.wait(1500)
    -- both at zero, close to death: the vignette is at its strongest
    lab.hud({ health = { value = 2, max = 100 } })
    lab.state({ needs = { food = 0, drink = 0, starving = "both", drainPerMinute = 2.5 } })
    lab.wait(600)
end)

HudLab.scene("hud-fed", function(lab)
    reset(lab)
    lab.hud({ health = { value = 71, max = 100 } })
    lab.state({ needs = { food = 96, drink = 91, wellFed = true, regenPerMinute = 3 } })
    lab.wait(600)
end)

HudLab.scene("hud-delta", function(lab)
    reset(lab)
    lab.hud({ health = { value = 90, max = 100 } })
    lab.wait(1700)
    lab.hud({ health = { value = 55, max = 100 } })   -- "-35" in red, the white trail behind the fill
    lab.wait(1700)
    lab.hud({ health = { value = 80, max = 100 } })   -- "+25" in green: left floating over the dial
    lab.wait(400)
end)

HudLab.scene("hud-activity-match", function(lab)
    reset(lab)
    -- needs are frozen in a match: food, water and the warning step aside
    lab.state({ needs = { food = 12, drink = 16 } })
    lab.page(E.page.activityHud, { op = "show", hud = { activity = "gungame", title = "Gun game", phase = "running" } })
    lab.wait(600)
end)

-- ---- weapon, grenade -----------------------------------------------------------------------
HudLab.scene("hud-weapon", function(lab)
    reset(lab)
    lab.setHud("weapon", { active = true, reserve = 96, hands = {
        { hand = "right", label = "Unity", magazine = 9, capacity = 12, reloading = false } } })
    lab.wait(1200)
    -- akimbo: the right hand reloads, the left one is empty
    lab.setHud("weapon", { active = true, reserve = 48, hands = {
        { hand = "right", label = "Lexington x-MOD2", magazine = 3, capacity = 21, reloading = true },
        { hand = "left", label = "Lexington x-MOD2", magazine = 0, capacity = 21, reloading = false } } })
    lab.wait(600)
end)

HudLab.scene("hud-weapon-melee", function(lab)
    reset(lab)
    -- no magazine, no reserve: dashes
    lab.setHud("weapon", { active = true, hands = { { hand = "right", label = "Katana", reloading = false } } })
    lab.wait(600)
end)

HudLab.scene("hud-weapon-external", function(lab)
    reset(lab)
    -- op77_weaponhud's hologram is up to 282 dp from the bottom: the crew frame sits above it
    lab.setHud("weapon", { active = false, externalTop = 282 })
    lab.state({ party = { you = 1, id = "crew:1", leader = 3, maxSize = 8, invites = {}, members = { CREW[1], CREW[2], CREW[6] } } })
    lab.wait(1000)
    -- with the grenade chip the hologram is 30 dp higher (client/core/hud.lua GRENADE_CHIP_LIFT)
    lab.page(GRENADES, { kind = "state", state = { ready = true, busy = false, revision = 2, selected = "grenade_frag", label = "F-GX Frag grenade", count = 3 } })
    lab.setHud("weapon", { active = false, externalTop = 312 })
    lab.wait(600)
end)

HudLab.scene("hud-grenade", function(lab)
    reset(lab)
    lab.page(GRENADES, { kind = "state", state = { ready = true, busy = false, revision = 2, selected = "grenade_frag", label = "F-GX Frag grenade", count = 3 } })
    lab.wait(600)
end)

-- ---- crew ----------------------------------------------------------------------------------
HudLab.scene("hud-crew", function(lab)
    reset(lab)
    -- ten members for eight rows: leader with a title, you, down, dead, mission, board, activity, far, "+2 MORE"
    lab.state({ party = { you = 1, id = "crew:1", leader = 3, maxSize = 12, invites = {}, members = CREW } })
    lab.wait(600)
end)

HudLab.scene("hud-crew-matchmaking", function(lab)
    reset(lab)
    lab.state({ party = { you = 1, id = "crew:1", leader = 1, maxSize = 4, invites = {}, matchmaking = true,
        members = { member(1, "Lab Runner", { leader = true, you = true }), CREW[1], CREW[9] } } })
    lab.wait(600)
end)

HudLab.scene("hud-crew-pending", function(lab)
    reset(lab)
    -- alone with invitations out
    lab.state({ party = { you = 1, id = "crew:1", leader = 1, maxSize = 4, invites = {},
        members = { member(1, "Lab Runner", { leader = true, you = true }) },
        pending = { { id = 3, name = "Judy Alvarez", expiresInMs = 52000 }, { id = 4, name = "Panam Palmer", expiresInMs = 58000 } } } })
    lab.wait(600)
end)

HudLab.scene("hud-crew-mission", function(lab)
    reset(lab)
    lab.state({ party = { you = 1, id = "crew:1", leader = 3, maxSize = 8, invites = {}, members = { CREW[1], CREW[2], CREW[3] } },
        missionQueue = { running = true, instance = "mission:7", title = "Arasaka warehouse", difficulty = "Hard", difficultyId = "hard", endsInMs = 540000, members = 5,
            squad = {
                { id = 3, name = "Judy Alvarez", citizen = "C1", host = true, health = 100, maxHealth = 100, armor = 80, state = "alive" },
                { id = 1, name = "Lab Runner", citizen = "C2", host = false, health = 24, maxHealth = 100, armor = 10, state = "alive" },
                { id = 4, name = "Panam Palmer", citizen = "C3", host = false, health = 0, maxHealth = 100, armor = 0, state = "down" },
                { id = 20, name = "Matched Stranger", citizen = "C4", host = false, health = 0, maxHealth = 100, armor = 0, state = "recovering" },
                { id = 21, name = "Another Stranger", citizen = "C5", host = false, health = 0, maxHealth = 100, armor = 0, state = "dead" },
            } } })
    lab.wait(600)
end)

HudLab.scene("hud-crew-invite", function(lab)
    reset(lab)
    -- 9 s left of 60: the seconds and the bar count down (two more invites wait in F1 > Crew)
    lab.state({ party = { you = 1, invites = {
        { party = "crew:3", from = 3, fromName = "Judy Alvarez", expiresInMs = 9000 },
        { party = "crew:8", from = 8, fromName = "River Ward", expiresInMs = 40000 },
        { party = "crew:9", from = 9, fromName = "Misty", expiresInMs = 55000 } }, maxSize = 8, inviteSeconds = 60, keys = { accept = "Y", decline = "N" } } })
    lab.wait(3000)
end)

-- ---- bottom right --------------------------------------------------------------------------
HudLab.scene("hud-rental", function(lab)
    reset(lab)
    local active = { spotId = "rental.downtown", spotName = "Downtown rentals", key = "maimai", label = "Makigai MaiMai", price = 250, paidWith = "cash",
        remainingMs = 1754000, vehicleId = 12, extendPrice = 150, extendMinutes = 30, extensionsLeft = 2, warnMs = 600000 }
    lab.state({ rental = { active = active } })
    lab.wait(2000)
    -- the last minutes: red, blinking, how to keep the car
    active.remainingMs = 185000
    lab.state({ rental = { active = active } })
    lab.wait(2000)
    -- no extension left
    active.remainingMs, active.extensionsLeft = 42000, 0
    lab.state({ rental = { active = active } })
    lab.wait(600)
end)

HudLab.scene("hud-vehicle", function(lab)
    reset(lab)
    local function drive(speed, gear, health, fuel)
        lab.setHud("vehicle", { active = true, label = "QUADRA TURBO-R V-TECH", speedKph = speed, gear = gear, health = health, fuel = fuel })
    end
    drive(0, "N", 1, { litres = 52, capacity = 60, fraction = 52 / 60, low = false, empty = false })
    lab.wait(800)
    for step = 1, 8 do
        drive(step * 24, tostring(math.min(5, 1 + step // 2)), 1 - step * 0.05, { litres = 52 - step * 3, capacity = 60, fraction = (52 - step * 3) / 60, low = false, empty = false })
        lab.wait(200)
    end
    lab.wait(600)
    -- damaged, on the reserve: the fuel gauge and its readout turn red
    drive(86, "3", 0.31, { litres = 6.4, capacity = 60, fraction = 6.4 / 60, low = true, empty = false })
    lab.wait(1500)
    -- reversing, the tank empty: the fuel side blinks
    drive(12, "R", 0.31, { litres = 0, capacity = 60, fraction = 0, low = true, empty = true })
    lab.wait(600)
end)

HudLab.scene("hud-vehicle-nofuel", function(lab)
    reset(lab)
    -- a vehicle without a tank on its state bag, faster than the dial: "--" and 30 lit cells
    lab.setHud("vehicle", { active = true, label = "ARCH NAZARE", speedKph = 262, gear = "5", health = 0.92 })
    lab.wait(600)
end)

-- ---- bottom centre -------------------------------------------------------------------------
HudLab.scene("hud-hotbar", function(lab)
    reset(lab)
    -- a picture, an icon, an empty slot, a picture, a weapon without art
    lab.page(HOTBAR, hotbar(ITEMS))
    lab.wait(1200)
    lab.page(HOTBAR, { kind = "activate", slot = 1, request = "hotbar:1000:1" })
    lab.page(HOTBAR, { kind = "response", slot = 1, request = "hotbar:1000:1", ok = true })
    lab.wait(2200)
    -- a refusal: the slot and the hint turn red (left on screen; it clears after 1.8 s)
    lab.page(HOTBAR, { kind = "activate", slot = 4, request = "hotbar:4000:2" })
    lab.page(HOTBAR, { kind = "response", slot = 4, request = "hotbar:4000:2", ok = false, text = "You are not hurt." })
    lab.wait(400)
end)

HudLab.scene("hud-walkflash", function(lab)
    reset(lab)
    lab.setHud("walk", RUN)      -- the first mode seen never flashes
    lab.wait(300)
    lab.setHud("walk", WALK)
    lab.wait(2000)
    lab.setHud("walk", SLOW)
    lab.wait(2000)
    lab.setHud("walk", RUN)      -- "FULL PACE", three cells: left on screen for 1.6 s
    lab.wait(500)
end)

-- ---- the interact prompt -------------------------------------------------------------------
--- Three metres in front of the camera; without the camera API the prompt is pinned on screen.
local function pointAhead(lab)
    local ok, view = pcall(function() return Open77.camera.view() end)
    if ok and type(view) == "table" and type(view.position) == "table" and type(view.forward) == "table" then
        local p, f = view.position, view.forward
        return { x = p.x + f.x * 3, y = p.y + f.y * 3, z = p.z + f.z * 3 - 1.1 }
    end
    lab.log("no camera view: the prompt is pinned at 55 % / 50 % of the screen")
    Open77.camera = Open77.camera or {}
    Open77.camera.project = function() return { x = 0.55, y = 0.5, depth = 3, distance = 3, onScreen = true } end
    return { x = 0, y = 0, z = 0 }
end

HudLab.scene("hud-interact", function(lab)
    reset(lab)
    LightRpInteract.near = { id = "shop.kabuki", prompt = "Open the shop", key = "E", position = pointAhead(lab), radius = 2.5 }
    lab.page(E.page.interact, { id = "shop.kabuki", prompt = "Open the shop", key = "E" })
    lab.wait(1500)
    -- another point, another key
    LightRpInteract.near = { id = "garage.1", prompt = "Store the vehicle", key = "F", position = pointAhead(lab), radius = 4 }
    lab.page(E.page.interact, { id = "garage.1", prompt = "Store the vehicle", key = "F" })
    lab.wait(600)
end)

-- ---- stepping aside ------------------------------------------------------------------------
HudLab.scene("hud-quiet", function(lab)
    reset(lab)
    lab.hud({ health = { value = 87, max = 100 }, armor = 35 })
    lab.page(HOTBAR, hotbar(ITEMS))
    lab.wait(1000)
    -- the inventory opens: the whole HUD fades out (and stays out: the next scene closes it)
    lab.dialog("inventory", true)
    lab.wait(600)
end)

-- ---- everything at once --------------------------------------------------------------------
HudLab.scene("hud-all", function(lab)
    reset(lab)
    lab.hud({ health = { value = 64, max = 100 }, stamina = { value = 48, max = 100 }, armor = 55 })
    lab.state({ needs = { food = 41, drink = 17 },
        party = { you = 1, id = "crew:1", leader = 3, maxSize = 8, inviteSeconds = 60,
            members = { CREW[1], CREW[2], CREW[3], CREW[5], CREW[8] },
            invites = { { party = "crew:8", from = 8, fromName = "River Ward", expiresInMs = 48000 } } },
        rental = { active = { spotId = "rental.downtown", spotName = "Downtown rentals", key = "maimai", label = "Makigai MaiMai", price = 250, paidWith = "bank",
            remainingMs = 372000, vehicleId = 12, extendPrice = 150, extendMinutes = 30, extensionsLeft = 1, warnMs = 600000 } } })
    lab.page(GRENADES, { kind = "state", state = { ready = true, busy = false, revision = 3, selected = "grenade_emp", label = "EMP grenade", count = 2 } })
    lab.setHud("weapon", { active = true, reserve = 84, hands = { { hand = "right", label = "Unity", magazine = 7, capacity = 12, reloading = false } } })
    lab.setHud("vehicle", { active = true, label = "MAKIGAI MAIMAI P126", speedKph = 74, gear = "3", health = 0.82,
        fuel = { litres = 23, capacity = 40, fraction = 23 / 40, low = false, empty = false } })
    lab.page(HOTBAR, hotbar(ITEMS))
    LightRpInteract.near = { id = "fuel.pump.3", prompt = "Refuel", key = "E", position = pointAhead(lab), radius = 3 }
    lab.page(E.page.interact, { id = "fuel.pump.3", prompt = "Refuel", key = "E" })
    lab.setHud("walk", WALK)
    lab.wait(400)
    lab.page(HOTBAR, { kind = "activate", slot = 2, request = "hotbar:9000:3" })
    lab.wait(400)
end)
