-- HUD lab scenes of op77_weaponhud: the adapter (client/ui.lua) is fed exactly what
-- client/main.lua sends (weapon:config / show / data / hide / inset). No session: no
-- weapon is read, every payload is written here. Each scene starts from the default
-- config with no lift, and leaves its last state on screen.
local W = WeaponHud
local page, ready = nil, false

local function send(name, payload) page:send(name, payload) end
local function config(patch) send("weapon:config", W.pageConfig(W.merge(WeaponHudConfig, patch or {}))) end

-- The surface, once; every scene then starts from the defaults.
local function reset(lab)
    if not page then
        local created, why = WeaponHudUi.create({ zIndex = WeaponHudConfig.zIndex })
        if not created then error("no NativeUI document: " .. tostring(why)) end
        page = created
        page:on("weapon:ready", function() ready = true end)
    end
    for _ = 1, 100 do
        if ready then break end
        lab.wait(50)
    end
    if not ready then error("the document did not load") end
    config()
    send("weapon:inset", { px = 0 })
end

local LEXINGTON = { key = "1:0xAA", name = "LEXINGTON", type = "HANDGUN", class = "POWER", melee = false, capacity = 21 }
local COPPERHEAD = { key = "2:0xBB", name = "COPPERHEAD", type = "RIFLE", class = "TECH", melee = false, capacity = 30 }
local KATANA = { key = "3:0xCC", name = "SATORI", type = "KATANA", class = "BLADE", melee = true }

local function show(weapon, instant) send("weapon:show", W.merge(weapon, { instant = instant or nil })) end
-- what publish() builds from a snapshot row
local function data(weapon, magazine, reserve, extra)
    local d = {
        magazine = magazine, capacity = weapon.capacity, reserve = reserve, reloading = false, shots = 0, reloaded = false,
        low = W.low(magazine, weapon.capacity, W.pageConfig(WeaponHudConfig)), empty = magazine == 0,
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    send("weapon:data", d)
end
local MELEE = { melee = true, shots = 0, reloaded = false, low = false, empty = false }

-- drawn: the unfold with its self-test (888, every cell), then a full magazine
HudLab.scene("wh-full", function(lab)
    reset(lab)
    send("weapon:hide", {})
    lab.wait(500)
    show(LEXINGTON)
    data(LEXINGTON, 21, 120)
    lab.wait(1600)
end)

-- shots: one round every 160 ms (cells emptying, digits flicker, kick, ejected cells), then a burst of three
HudLab.scene("wh-shots", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 21, 120)
    lab.wait(500)
    local magazine = 21
    for _ = 1, 8 do
        magazine = magazine - 1
        data(LEXINGTON, magazine, 120, { shots = 1 })
        lab.wait(160)
    end
    lab.wait(400)
    magazine = magazine - 3
    data(LEXINGTON, magazine, 120, { shots = 3 })
    lab.wait(600)
end)

HudLab.scene("wh-low", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 5, 120, { shots = 0 })
    lab.wait(400)
    data(LEXINGTON, 4, 120, { shots = 1 })
    lab.wait(800)
end)

-- empty with a reserve: red pulse, RELOAD blinking
HudLab.scene("wh-empty", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 1, 120)
    lab.wait(400)
    data(LEXINGTON, 0, 120, { shots = 1 })
    lab.wait(2000)
end)

-- empty without a reserve: NO AMMO, the reserve in red
HudLab.scene("wh-noammo", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 0, 0)
    lab.wait(1500)
end)

-- reloading: the cool sweep along the cells, the running progress line (left on screen)
HudLab.scene("wh-reloading", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 0, 120)
    lab.wait(600)
    for _ = 1, 20 do
        data(LEXINGTON, 0, 120, { reloading = true })
        lab.wait(100)
    end
end)

-- the reload ends: the count rolls up, the cells refill in a sweep
HudLab.scene("wh-reloaded", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 3, 120)
    lab.wait(400)
    for _ = 1, 12 do
        data(LEXINGTON, 3, 120, { reloading = true })
        lab.wait(100)
    end
    data(LEXINGTON, 21, 102, { reloaded = true })
    lab.wait(1200)
end)

-- a second weapon: a new unfold (self-test), a TECH badge, 30 cells
HudLab.scene("wh-switch", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 18, 120)
    lab.wait(1000)
    show(COPPERHEAD)
    data(COPPERHEAD, 30, 240)
    lab.wait(1600)
end)

HudLab.scene("wh-melee", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 18, 120)
    lab.wait(700)
    show(KATANA)
    send("weapon:data", MELEE)
    lab.wait(3000)
end)

-- a long name against a SMART badge and a long type; the left hand's magazine; a big magazine (3 rounds per cell)
HudLab.scene("wh-longname", function(lab)
    reset(lab)
    local weapon = { key = "1:0xDD", name = "MILITECH M-179E ACHILLES PROTOTYPE", type = "DOUBLE BARREL", class = "SMART", melee = false, capacity = 100 }
    show(weapon, true)
    data(weapon, 64, 999, { left = { magazine = 8, capacity = 10 } })
    lab.wait(1000)
end)

-- the grenade chip lifts the HUD by 30 dp (0.3 s), as LightRP asks
HudLab.scene("wh-inset", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 18, 120)
    lab.wait(1000)
    send("weapon:inset", { px = 30 })
    lab.wait(1000)
end)

-- a themed variant: every accent part in #3FE0D0 (bloom, cells, name, corners)
HudLab.scene("wh-theme", function(lab)
    reset(lab)
    config({ theme = { accent = "#3FE0D0" } })
    show(LEXINGTON, true)
    data(LEXINGTON, 18, 120)
    lab.wait(1000)
end)

-- layout variants: full size and flat; lit leading zeros, no scanlines
HudLab.scene("wh-layout", function(lab)
    reset(lab)
    config({ layout = { scale = 1.0, tilt = false, left = 80, bottom = 200 }, theme = { scanlines = false }, leadingZeros = "lit" })
    show(LEXINGTON, true)
    data(LEXINGTON, 7, 120)
    lab.wait(1000)
end)

-- holstered: folds into a line, nothing left on screen
HudLab.scene("wh-hidden", function(lab)
    reset(lab)
    show(LEXINGTON, true)
    data(LEXINGTON, 18, 120)
    lab.wait(1000)
    send("weapon:hide", {})
    lab.wait(800)
end)

-- drawn again: the unfold from nothing
HudLab.scene("wh-shown", function(lab)
    reset(lab)
    send("weapon:hide", {})
    lab.wait(600)
    show(LEXINGTON)
    data(LEXINGTON, 18, 120)
    lab.wait(1600)
end)
