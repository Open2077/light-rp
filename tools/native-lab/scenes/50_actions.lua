-- Lab scenes for client/native/actions.lua (the action bar) and client/native/weapon_wheel.lua
-- (the weapon wheel). The payloads are the shapes the cores send: client/core/actions.lua's
-- normalized definition on actionStart, its result on actionFinish; client/core/weapon_wheel.lua's
-- open / latch / commit / cancel on "lightrp:ui:weaponwheel"; client/core/armament.lua's state and
-- responses on "lightrp:ui:armament".
--
-- The lab has no page: the action clock starts at once (no "ready" from the relay), the keys the
-- page would relay are played with LightRpNativeActions.input, and the wheel's pointer, mouse
-- buttons and mouse wheel are faked over Open77.input as the medical scene fakes its pointer.
-- Every scene leaves its final state up; the wheel scenes close the wheel first.
local E = LightRpEvents
local A = LightRpNativeActions
local WW = LightRpNativeWeaponWheel
local WHEEL, ARMAMENT = "lightrp:ui:weaponwheel", "lightrp:ui:armament"

-- ---------------------------------------------------------------------------------------
-- the action bar
local serial = 0
local function action(lab, kind, extra)
    serial = serial + 1
    local d = { id = "lab:" .. serial, kind = kind, label = "Prepare the equipment", description = "Keep everything steady. You're nearly there.",
        icon = "wrench", style = "bar", key = "E", cancellable = true, release = "reset", durationMs = 5000, steps = {}, maxMistakes = 0 }
    for k, v in pairs(extra or {}) do d[k] = v end
    if d.timeoutMs == nil then
        local budget = d.durationMs + 400
        if kind == "timing" then budget = 400; for _, s in ipairs(d.steps) do budget = budget + s.durationMs + 450 end end
        d.timeoutMs = kind == "hold" and math.max(15000, d.durationMs * 3 + 400) or budget + 1500
    end
    lab.page(E.page.actionStart, d)
    return d
end
local function key(d, kind, name) A.input({ id = d.id, kind = kind, key = name }) end
local function view() local r = A.current(); return r and r.clock.view end
--- Waits until the timing cursor reaches `at` (0..1 of the track) on the current step.
local function waitCursor(lab, at)
    for _ = 1, 400 do
        local v = view()
        if not v or v.result then return false end
        if v.phase == "running" and v.progress >= at then return true end
        lab.wait(0)
    end
    return false
end
local function step(zoneStart, zoneWidth, durationMs, name)
    return { key = name or "E", durationMs = durationMs or 2600, zoneStart = zoneStart, zoneWidth = zoneWidth or 0.24 }
end

HudLab.scene("action-progress", function(lab)
    -- the minimal bar (a plain progress action: eating, refuelling): runs to "Action complete"
    action(lab, "progress", { label = "Eating a burrito", description = "Wrapped in foil, still warm.", durationMs = 3500, icon = "sandwich" })
    lab.wait(5600)
    -- the ring card of the same action (style "ring"), left running
    action(lab, "progress", { label = "Refuelling", description = "Jerrycan · 10 L into the tank.", style = "ring", icon = "fuel", durationMs = 8000 })
end)

HudLab.scene("action-hold", function(lab)
    local d = action(lab, "hold", { label = "Secure the connection", description = "Keep E pressed. Release to reset your progress.", style = "ring", durationMs = 3000 })
    lab.wait(900)            -- "Hold to continue"
    key(d, "down", "E")      -- "Keep holding", the key cap lit
    lab.wait(1400)
    key(d, "up", "E")        -- "Released — hold to restart", back to 0 %
    lab.wait(1400)
    key(d, "down", "E")
    lab.wait(1500)           -- left half way, still held
end)

HudLab.scene("action-timing", function(lab)
    -- three steps, one miss allowed: in the zone (Perfect timing), too early, in the zone again
    local d = action(lab, "timing", { label = "Calibrate the relay", description = "Stop the cursor inside the highlighted area.", icon = "zap",
        steps = { step(0.36, 0.24, 2600, "E"), step(0.50, 0.16, 2000, "R"), step(0.42, 0.12, 1800, "E") }, maxMistakes = 1 })
    lab.wait(900)                                             -- the zone, the cursor moving
    if waitCursor(lab, 0.36 + 0.12) then key(d, "down", "E"); key(d, "up", "E") end
    lab.wait(700)                                             -- feedback, then step 2 (key R)
    if waitCursor(lab, 0.2) then key(d, "down", "R"); key(d, "up", "R") end -- too early: 1 / 1 misses
    lab.wait(700)
    if waitCursor(lab, 0.42 + 0.05) then key(d, "down", "E"); key(d, "up", "E") end -- success: 2 / 3 hits
end)

HudLab.scene("action-result", function(lab)
    -- success: a short ring progress
    action(lab, "progress", { label = "Patch the wound", description = "Bandage applied.", style = "ring", icon = "bandage", durationMs = 1200 })
    lab.wait(3200)
    -- cancel: Escape on a hold
    local d = action(lab, "hold", { label = "Pick the lock", description = "Hold E.", icon = "key-round" })
    lab.wait(1200)
    key(d, "escape")
    lab.wait(2000)
    -- fail: pressed before the zone, no miss allowed
    d = action(lab, "timing", { label = "Hotwire the van", description = "Stop the cursor inside the highlighted area.", icon = "zap",
        steps = { step(0.6, 0.16, 2000, "E") } })
    lab.wait(700)
    key(d, "down", "E"); key(d, "up", "E")
    lab.wait(2000)
    -- an outcome Lua decided (the owner resource stopped): shown, left up
    d = action(lab, "progress", { label = "Prepare the equipment", durationMs = 10000 })
    lab.wait(1500)
    lab.page(E.page.actionFinish, { id = d.id, status = "cancelled", reason = "owner_stopped", elapsedMs = 1500, hits = 0, mistakes = 0, score = 0 })
end)

-- ---------------------------------------------------------------------------------------
-- the weapon wheel
local function weapon(id, label, class, rounds, extra)
    local w = { slot = 1, instanceId = id, name = label:lower():gsub("%W", "_"), label = label, class = class, rounds = rounds,
        ammoLabel = "Pistol ammo", image = "img/items/weapon_ar_raygun_supreme_9000.png" }
    for k, v in pairs(extra or {}) do w[k] = v end
    return w
end
local ARSENAL = {
    weapon("3f2a9c41-unity", "Unity", "pistol", 42, { hand = "right", image = "img/items/weapon_amnesty.png" }),
    weapon("7b1e0d55-saratoga", "Saratoga", "smg", 120, { ammoLabel = "SMG ammo", image = "img/items/weapon_agaou.png" }),
    weapon("c94d2e10-carnage", "Carnage", "shotgun", 0, { ammoLabel = "Shells", image = "img/items/weapon_alabai.png" }),
    weapon("e0aa4b72-ajax", "Ajax", "rifle", 210, { ammoLabel = "Rifle ammo", image = "img/items/weapon_ambition.png" }),
    weapon("kit:1", "Kit Copperhead", "rifle", nil, { kit = true, image = "img/items/weapon_amstaff.png" }),
}
local function armament(extra)
    local s = { ready = true, busy = false, revision = 7, right = { instanceId = "3f2a9c41-unity", name = "unity", label = "Unity", record = "Items.Preset_Unity_Default", nativeSlot = 1 },
        holstered = false, arsenal = ARSENAL, ammo = { pistol = { remaining = 42, label = "Pistol ammo" } } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
local function close(lab)
    if WW.current().phase ~= "closed" then lab.page(WHEEL, { kind = "cancel", reason = "lab" }); lab.wait(350) end
end

--- Plays the pointer, the mouse buttons and the wheel the module reads. Returns the controls,
--- or nil when Open77.input cannot be replaced here (then use the real mouse).
local function fakeInput(lab)
    local input = Open77.input
    local real = { pointer = input.pointer, isDown = input.isDown, axis = input.axis }
    local fake = { x = 0.5, y = 0.5, left = false, right = false, wheel = 0 }
    local ok = pcall(function()
        input.pointer = function() return fake.x, fake.y, "overlay" end
        input.isDown = function(control)
            local c = tostring(control):lower()
            if c == "mouse1" then return fake.left end
            if c == "mouse2" then return fake.right end
            return real.isDown(control)
        end
        input.axis = function(name)
            if tostring(name):lower() == "mousewheel" then return fake.wheel end
            return real.axis(name)
        end
    end)
    if not ok or input.pointer == real.pointer then
        lab.log("weapon wheel: Open77.input is read-only here: aim with the real mouse")
        return nil
    end
    function fake.restore() input.pointer, input.isDown, input.axis = real.pointer, real.isDown, real.axis end
    --- Moves the pointer by (dx, dy) page pixels over `ms`, a frame at a time.
    function fake.move(dx, dy, ms)
        local steps = math.max(1, math.floor((ms or 200) / 16))
        for _ = 1, steps do
            fake.x, fake.y = fake.x + dx / steps / 1920, fake.y + dy / steps / 1080
            lab.wait(16)
        end
    end
    --- Aims the virtual stick at slot `i` (0-based) of `n`: back through the centre, then out.
    function fake.aim(i, n, ms)
        local a = math.rad(-90 + i * 360 / n)
        fake.move(math.cos(a) * 160, math.sin(a) * 160, ms or 260)
    end
    function fake.click(button)
        fake[button] = true; lab.wait(120); fake[button] = false; lab.wait(60)
    end
    return fake
end

HudLab.scene("wheel-open", function(lab)
    close(lab)
    lab.page(ARMAMENT, { kind = "state", state = armament() })
    lab.page(WHEEL, { kind = "open", key = "TAB" })  -- holster on top, five weapons, the Unity in hand (aimed)
    lab.wait(2500)
    lab.page(ARMAMENT, { kind = "state", state = armament({ holstered = true }) }) -- HOLSTERED, the steel marker
    lab.wait(1500)
    lab.page(ARMAMENT, { kind = "state", state = armament({ busy = true }) })     -- SYNCHRONIZING blinks
    lab.wait(1800)
    lab.page(WHEEL, { kind = "latch", key = "TAB" })                               -- the tap hints: CLICK / TAB EQUIP
    lab.wait(1500)
    close(lab)
    -- empty pockets: the holster slot and five empty ones (it still opens: the fists go down)
    lab.page(ARMAMENT, { kind = "state", state = armament({ right = false, arsenal = {} }) })
    lab.page(WHEEL, { kind = "open", key = "TAB" })
end)

HudLab.scene("wheel-hover", function(lab)
    close(lab)
    lab.page(ARMAMENT, { kind = "state", state = armament() })
    local fake = fakeInput(lab)
    lab.page(WHEEL, { kind = "open", key = "TAB" })
    if not fake then return end
    lab.wait(500)                       -- past the centring grace
    local n = #WW.current().slots       -- 6: holster + 5 weapons
    fake.aim(2, n, 300)                 -- the Saratoga: the slot pops, the hub kicks, the needle
    lab.wait(900)
    fake.move(-160 * math.cos(math.rad(-90 + 2 * 360 / n)), -160 * math.sin(math.rad(-90 + 2 * 360 / n)), 200)
    fake.aim(3, n, 300)                 -- the Carnage: NO AMMO, red rounds
    lab.wait(900)
    fake.wheel = fake.wheel - 1         -- the mouse wheel towards the player: the next slot
    lab.wait(700)
    fake.wheel = fake.wheel - 1
    lab.wait(700)
    fake.wheel = fake.wheel + 1         -- and back
    lab.wait(900)
    fake.restore()                      -- left open on the hovered slot
end)

HudLab.scene("wheel-pick", function(lab)
    close(lab)
    lab.page(ARMAMENT, { kind = "state", state = armament() })
    local fake = fakeInput(lab)
    -- the pick goes to the server: answered here, the lab has none
    local realTrigger, sent = TriggerServerEvent, nil
    TriggerServerEvent = function(name, payload) sent = { name = name, payload = payload }; return true end
    local ok, why = pcall(function()
        lab.page(WHEEL, { kind = "open", key = "TAB" })
        lab.wait(500)
        -- slots: 0 holster, 1 Unity (in hand), 2 Saratoga, 3 Carnage, 4 Ajax, 5 the kit
        local n = #WW.current().slots
        if fake then fake.aim(2, n, 300) else WW.aimAt(2) end -- the Saratoga
        lab.wait(700)
        -- a left click: the wheel locks the slot, IN HAND, the select request
        if fake then fake.click("left") else lab.page(WHEEL, { kind = "commit", reason = "lab" }) end
        lab.wait(300)
        if sent then lab.log(("select %s rev %s"):format(tostring(sent.payload.instanceId), tostring(sent.payload.baseRevision))) end
        local pending = WW.current().pending
        local held = armament({ right = { instanceId = "7b1e0d55-saratoga", name = "saratoga", label = "Saratoga", record = "Items.Preset_Saratoga_Default", nativeSlot = 1 }, revision = 8 })
        held.arsenal = {}
        for i, w in ipairs(ARSENAL) do
            local copy = {}
            for k, v in pairs(w) do copy[k] = v end
            copy.hand = copy.instanceId == "7b1e0d55-saratoga" and "right" or nil
            held.arsenal[i] = copy
        end
        if pending then lab.page(ARMAMENT, { kind = "response", request = pending.request, ok = true, data = { state = held } }) end
        lab.wait(2600)
        -- the holster slot, committed by the key's release (weapon_wheel.lua sends commit)
        lab.page(WHEEL, { kind = "open", key = "TAB" })
        lab.wait(500)
        if fake then fake.aim(0, n, 300) else WW.aimAt(0) end
        lab.wait(600)
        lab.page(WHEEL, { kind = "commit", reason = "release" })  -- HOLSTERED
        lab.wait(2600)
        -- a refusal right after the choice replaces the confirmation: NOT EQUIPPED
        lab.page(WHEEL, { kind = "open", key = "TAB" })
        lab.wait(500)
        if fake then fake.aim(4, n, 300) else WW.aimAt(4) end
        lab.wait(600)
        lab.page(WHEEL, { kind = "commit", reason = "release" })
        lab.wait(500)
        pending = WW.current().pending
        if pending then lab.page(ARMAMENT, { kind = "response", request = pending.request, ok = false, error = "Your equipment changed. Refresh before retrying." }) end
    end)
    TriggerServerEvent = realTrigger
    if fake then fake.restore() end
    if not ok then error(why, 0) end
end)
