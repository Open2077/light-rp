-- HUD lab scenes of open77_contextmenu: the TargetEye and the column driven through
-- ContextMenuUi (client/ui.lua) with what client/main.lua sends. No session here: no
-- targets, no providers, and the pre-game shell keeps the cursor and the keyboard, so the
-- lease is not asked; hover, keys and clicks are replayed with page:labInput.
local page, ready = nil, false
local epoch = 0
local APPEARANCE = (type(ContextMenuConfig) == "table" and ContextMenuConfig.appearance)
    or { accentColor = "#FFCC00", scale = 1.0, showGroups = false }

local function surface(lab)
    if not page then
        local why
        page, why = ContextMenuUi.create({ appearance = APPEARANCE })
        if not page then error("context menu surface: " .. tostring(why)) end
        page:on("context:ready", function() ready = true end)
        page:on("context:pick", function(p) lab.log(("context:pick %.3f %.3f"):format(p.x, p.y)) end)
        page:on("context:select", function(p) lab.log("context:select " .. tostring(p.token)) end)
        page:on("context:cancel", function() lab.log("context:cancel") end)
        page:on("context:blur", function(reason) lab.log("context:blur " .. tostring(reason)) end)
    end
    for _ = 1, 60 do
        if ready then break end
        lab.wait(50)
    end
    if not ready then lab.log("context menu: the document never reported loaded") end
    return page
end
local function send(name, payload) page:send(name, payload or {}) end
-- every scene starts from a closed menu, then opens as main.lua's open() does
local function open(lab, appearance, key)
    surface(lab)
    send("context:close")
    page:hide()
    lab.wait(120)
    epoch = epoch + 1
    send("context:open", { epoch = epoch, key = key or "ALT", appearance = appearance or APPEARANCE })
    page:show()
end
-- a click at (x, y): main.lua answers context:loading at once, then the menu
local function pick(lab, x, y, wait)
    epoch = epoch + 1
    send("context:loading", { epoch = epoch, x = x, y = y })
    lab.wait(wait or 900)
end
local function key(name) page:labInput("keydown", "", { key = name }) end
local function hover(index) page:labInput("mouseover", ".row", { id = "r" .. index }) end

local PLAYER_ACTIONS = {
    { token = "t-id", label = "Show ID", icon = "person", description = "Show your identity card to this player.", group = "Social" },
    { token = "t-give", label = "Give money", icon = "interact", description = "Hand over cash.", group = "Social" },
    { token = "t-info", label = "Inspect", icon = "info", group = "Social" },
    { token = "t-cuff", label = "Handcuff", icon = "lock", description = "Police only. The player must be standing still.", group = "Police" },
    { token = "t-gps", label = "Share position", icon = "location", group = "Police" },
    { token = "t-repair", label = "Treat wounds", icon = "tool", group = "Medic" },
    { token = "t-carry", label = "Put in vehicle", icon = "vehicle", group = "Police" },
    { token = "t-kick", label = "Kick from the server", icon = "interact", danger = true, description = "Staff action, logged.", group = "Staff" },
    { token = "t-long", label = "A label far too long for the column to hold on one line", icon = "info", group = "Staff" },
}
local VEHICLE_ACTIONS = {
    { token = "v-lock", label = "Lock doors", icon = "lock", description = "Lock or unlock every door." },
    { token = "v-trunk", label = "Open trunk", icon = "vehicle", description = "Open the trunk.", submenu = { id = "lightrp/cargo", label = "Trunk & hood", icon = "vehicle" } },
    { token = "v-hood", label = "Open hood", icon = "tool", description = "Lift the hood.", submenu = { id = "lightrp/cargo", label = "Trunk & hood", icon = "vehicle" } },
    { token = "v-store", label = "Store in garage", icon = "location", submenu = { id = "lightrp/garage", label = "Garage", icon = "location" } },
    { token = "v-impound", label = "Impound", icon = "lock", danger = true, description = "Police only.", submenu = { id = "lightrp/garage", label = "Garage", icon = "location" } },
    { token = "v-info", label = "Registration", icon = "info" },
}

HudLab.scene("ctx-eye-scan", function(lab)
    open(lab)
    lab.wait(900)                       -- the eye alone, at the centre (where the lease puts the pointer)
    -- the eye follows the pointer until a pick
    local points = { { 1100, 420 }, { 900, 380 }, { 760, 460 }, { 640, 400 } }
    for _, point in ipairs(points) do
        page:labInput("mousemove", "#hit", { mouse_x = point[1], mouse_y = point[2] })
        lab.wait(300)
    end
    lab.wait(500)
    pick(lab, 0.33, 0.37, 0)            -- SCANNING: "Looking…" and the spinner, left on screen
end)

HudLab.scene("ctx-no-target", function(lab)
    open(lab)
    lab.wait(500)
    pick(lab, 0.5, 0.45)
    send("context:empty", { epoch = epoch, message = "Entity picking is unavailable on this client build." })   -- NO TARGET, red eye
    lab.wait(2500)
    pick(lab, 0.62, 0.5)
    send("context:menu", { epoch = epoch, target = { kind = "world", networked = false }, distance = 14.2, actions = {} })   -- WORLD, "No actions"
end)

HudLab.scene("ctx-player", function(lab)
    open(lab)
    lab.wait(400)
    pick(lab, 0.4, 0.3)
    -- PLAYER  ID 007 // 3.2M, a column of actions with every icon and a danger row
    send("context:menu", { epoch = epoch, target = { kind = "player", playerId = 7, networked = true }, distance = 3.2, actions = PLAYER_ACTIONS })
    lab.wait(1400)
    hover(1)                             -- hover: accent row, its description under the list
    lab.wait(1100)
    hover(4)
    lab.wait(1100)
    key("end")                           -- keyboard: the long label, ellipsis
    lab.wait(900)
    key("up")                            -- the danger row highlighted (red)
end)

HudLab.scene("ctx-busy-failed", function(lab)
    open(lab)
    lab.wait(300)
    pick(lab, 0.4, 0.3, 600)
    send("context:menu", { epoch = epoch, target = { kind = "player", playerId = 7, networked = true }, distance = 3.2, actions = PLAYER_ACTIONS })
    lab.wait(900)
    hover(4)
    lab.wait(700)
    -- a row is chosen: the others wait, dimmed (the menu has no other "disabled" row), it spins
    page:labInput("click", ".row", { id = "r4" })
    send("context:busy", { epoch = epoch, token = "t-cuff" })
    lab.wait(2200)
    -- main.lua refuses it: the status line, the reason, and the info glyph on the failed row
    send("context:error", { epoch = epoch, message = "This action is no longer available." })
end)

HudLab.scene("ctx-folders", function(lab)
    open(lab)
    lab.wait(300)
    pick(lab, 0.55, 0.42, 600)
    -- VEHICLE  #0042 // 12M: two folders fold four of the six rows
    send("context:menu", { epoch = epoch, target = { kind = "vehicle", vehicleId = "18446744073709550042", networked = true }, distance = 12.4, actions = VEHICLE_ACTIONS })
    lab.wait(1300)
    key("down"); lab.wait(450)
    key("down"); lab.wait(700)           -- on the "Trunk & hood" folder
    key("right")                         -- opened: Back, its two rows, the "BACK · ESC CLOSE" legend
    lab.wait(1400)
    key("down"); lab.wait(900)
    key("left")                          -- back: the folder keeps the highlight
    lab.wait(1200)
    key("down"); lab.wait(400)
    key("enter")                         -- the Garage folder, with a danger row; left open
end)

HudLab.scene("ctx-npc", function(lab)
    open(lab)
    lab.wait(300)
    pick(lab, 0.3, 0.55, 600)
    -- an NPC is named after its record; the column flips to the left near the right edge
    send("context:menu", { epoch = epoch, target = { kind = "npc", npcId = "9007199254741234", record = "Character.judy_alvarez_default", networked = false },
        distance = 1.4, actions = { { token = "n-talk", label = "Talk", icon = "person" }, { token = "n-trade", label = "Trade", icon = "interact", description = "Open the vendor." } } })
    lab.wait(2200)
    pick(lab, 0.93, 0.9, 500)
    send("context:menu", { epoch = epoch, target = { kind = "prop", propId = "5512", networked = false }, title = "Roulette", distance = 2,
        actions = { { token = "r#spin", label = "Spin", icon = "interact" }, { token = "r#red", label = "Red", icon = "info" }, { token = "r#black", label = "Black", icon = "info" } } })
    lab.wait(2200)
    pick(lab, 0.5, 0.2, 500)
    send("context:menu", { epoch = epoch, target = { kind = "player", isLocalPlayer = true, playerId = 7 }, distance = 0.4,
        actions = { { token = "s-anim", label = "Animations", icon = "person" } } })   -- YOU
end)

HudLab.scene("ctx-appearance", function(lab)
    -- another accent, the largest scale, group headings and another key
    open(lab, { accentColor = "#3FE0D0", scale = 1.5, showGroups = true }, "F")
    lab.wait(700)
    pick(lab, 0.35, 0.25, 800)
    send("context:menu", { epoch = epoch, target = { kind = "player", playerId = 142, networked = true }, distance = 27, actions = PLAYER_ACTIONS })
    lab.wait(1500)
    hover(2)
    lab.wait(2200)
    -- and the smallest scale, default accent
    open(lab, { accentColor = "#FFCC00", scale = 0.75, showGroups = false })
    pick(lab, 0.35, 0.25, 500)
    send("context:menu", { epoch = epoch, target = { kind = "door", networked = false }, distance = 1.1, actions = VEHICLE_ACTIONS })
end)

HudLab.scene("ctx-clear", function(lab)
    surface(lab)
    send("context:close")
    page:hide()
end)
