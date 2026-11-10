-- The weapon wheel on NativeUI (was ui/src/features/weaponwheel/WeaponWheel.tsx and
-- weaponwheel.css). client/core/weapon_wheel.lua keeps everything it owned: the TAB hold
-- mapping, the tap latch, the safety loop, the sounds, the focus policy (the WebUI page takes
-- the MOUSE only, the keyboard stays with the game: the player keeps moving). It tells this
-- module, on the page's channel "lightrp:ui:weaponwheel": open { key }, latch { key },
-- commit, cancel.
--
-- Picking. This module draws the radial and reads the pointer the page holds
-- (Open77.input.pointer, as client/native/medical.lua does): the wheel opens with the cursor
-- in the screen centre (Open77.cursor.center, the software cursor hidden) and, as the page
-- did, the MOVEMENT of the pointer aims a virtual stick around that centre (a dead zone of
-- 26, a reach of 120: the aim never needs the pointer brought back). The mouse wheel cycles
-- (Open77.input.axis("mouseWheel")), a left click commits, a right click cancels.
--
-- What WeaponWheel.tsx sent on the channel now comes from here, through
-- LightRpWeaponWheel.message: hover (a sound), chosen (a sound), holster (the server holsters
-- whatever is in the hands), close { commit } (a click). A weapon pick is the armament
-- operation the page ran (performArmament("select")): { operation = "select", instanceId,
-- baseRevision, mutation, request } to op77_lightrp:armament, the response read back on
-- "lightrp:ui:armament" (a refusal within 6 s replaces the confirmation).
local N = LightRpNative

local W = {}
LightRpNativeWeaponWheel = W

local PAGE, ARMAMENT, NET = "lightrp:ui:weaponwheel", "lightrp:ui:armament", "op77_lightrp:armament"
local HALF = 340                       -- half of the drawn square, dp
local R_OUT, R_IN, R_HUB = 300, 138, 124
local MIN_SLOTS, GAP = 6, 1.4          -- degrees between two slots
local DEAD, CLAMP = 26, 120            -- virtual stick: dead zone and reach, dp
local POP = 14                         -- how far the aimed slot leaves the ring
local CLOSE_MS = 230
local REQUEST_MS, FEEDBACK_MS = 14000, 6000
local CLASS = {
    pistol = "PISTOL", revolver = "REVOLVER", smg = "SUBMACHINE GUN", shotgun = "SHOTGUN", rifle = "ASSAULT RIFLE",
    lmg = "LIGHT MACHINE GUN", precision = "PRECISION RIFLE", sniper = "SNIPER RIFLE", kit = "MISSION KIT",
}
-- An <img> needs a source even while its slot shows nothing: one transparent pixel.
local BLANK = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

-- ---- geometry (pure) -----------------------------------------------------------------------
local function rad(d) return d * math.pi / 180 end
local function at(deg, r) return math.cos(rad(deg)) * r, math.sin(rad(deg)) * r end
local function num(v)
    local s = ("%.2f"):format(v)
    if s == "-0.00" then s = "0.00" end
    return s
end
--- The ring sector from a0 to a1 (degrees, 0 = east, clockwise on screen) between r0 and r1.
function W.sector(a0, a1, r0, r1)
    local large = a1 - a0 > 180 and 1 or 0
    local x0, y0 = at(a0, r1)
    local x1, y1 = at(a1, r1)
    local x2, y2 = at(a1, r0)
    local x3, y3 = at(a0, r0)
    return ("M%s %sA%s %s 0 %d 1 %s %sL%s %sA%s %s 0 %d 0 %s %sZ"):format(num(x0), num(y0), num(r1), num(r1), large, num(x1), num(y1),
        num(x2), num(y2), num(r0), num(r0), large, num(x3), num(y3))
end
function W.arc(a0, a1, r)
    local x0, y0 = at(a0, r)
    local x1, y1 = at(a1, r)
    return ("M%s %sA%s %s 0 %d 1 %s %s"):format(num(x0), num(y0), num(r), num(r), a1 - a0 > 180 and 1 or 0, num(x1), num(y1))
end
--- 007, or --- for a value that is not a whole number.
function W.pad(n)
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge or n ~= math.floor(n) then return "---" end
    return ("%03d"):format(math.max(0, math.min(999, n)))
end
local function round(x) return math.floor(x + 0.5) end -- Math.round

-- ---- slots and texts (pure) -----------------------------------------------------------------
--- "holster" first, every pocket weapon after it, empty slots up to six.
function W.slots(armament)
    local list = { { key = "unarmed", kind = "unarmed" } }
    local arsenal = type(armament) == "table" and type(armament.arsenal) == "table" and armament.arsenal or {}
    for _, w in ipairs(arsenal) do
        if type(w) == "table" and type(w.instanceId) == "string" then list[#list + 1] = { key = w.instanceId, kind = "weapon", weapon = w } end
    end
    while #list < MIN_SLOTS do list[#list + 1] = { key = "empty:" .. #list, kind = "empty" } end
    return list
end
function W.weaponState(w, armament)
    if w.kit then return w.kitScope == "match" and "MATCH KIT" or "MISSION KIT", "accent" end
    if w.hand == "right" or w.hand == "left" then
        if type(armament) == "table" and armament.holstered then return "HOLSTERED", "steel" end
        return w.hand == "left" and "LEFT HAND" or "IN HAND", "accent"
    end
    return "IN POCKETS", "dim"
end
--- The template's own picture (web/img/items), as the hotbar shows it; nil otherwise.
function W.image(image)
    if type(image) ~= "string" then return nil end
    image = image:gsub("^/", "")
    if image:match("^img/items/[%w_%-]+%.png$") or image:match("^img/items/[%w_%-]+%.webp$") then return "/web/" .. image end
    return nil
end
local function str(v, fallback) if type(v) == "string" then return v end return fallback or "" end

--- The hub's texts for the aimed slot.
function W.hub(slot, armament)
    local out = { hubWeapon = false, hubUnarmed = false, hubEmpty = false, tag = "", name = "", showAmmo = false, ammo = "", ammoEmpty = false,
        ammoLabel = "", showChip = false, chip = "", chipTone = "accent", serial = "" }
    if slot.kind == "weapon" and slot.weapon then
        local w = slot.weapon
        local empty = type(w.rounds) == "number" and w.rounds <= 0 -- a mission kit weapon carries no pocket count: never "no ammo"
        local text, tone = W.weaponState(w, armament)
        out.hubWeapon = true
        out.tag = w.kitScope == "match" and "MATCH KIT" or CLASS[str(w.class)] or "WEAPON"
        out.name = str(w.label)
        out.showAmmo = not w.kit
        out.ammo, out.ammoEmpty = W.pad(w.rounds), empty == true
        out.ammoLabel = str(w.ammoLabel, "rounds"):upper()
        out.showChip, out.chip, out.chipTone = true, empty and "NO AMMO" or text, empty and "danger" or tone
        out.serial = w.kit and (w.kitScope == "match" and "Issued for the match" or "Issued for the mission")
            or ("SN " .. str(w.instanceId):sub(1, 8):upper())
    elseif slot.kind == "unarmed" then
        out.hubUnarmed = true
        out.tag, out.name = "HOLSTER", "Hands down"
        out.showChip, out.chip, out.chipTone = true, "PUT AWAY WHAT YOU HOLD", "accent"
        out.serial = "Guns, fists or blades · B does the same"
    else
        out.hubEmpty = true
        out.tag, out.name, out.serial = "EMPTY", "No weapon", "Gun stores sell them"
    end
    return out
end

--- One row of the slot layers (segment + item) per slot; `capacity` rows in all (never fewer
--- than a previous render: a data-for array must not shrink), the extra ones `show = false`.
function W.rows(slots, index, chosen, armament, capacity)
    local n = #slots
    local step = 360 / n
    local rMid = (R_IN + R_OUT) / 2 + 6
    local holstered = type(armament) == "table" and armament.holstered == true
    local rows = {}
    for i = 0, math.max(n, capacity) - 1 do
        local s = slots[i + 1]
        if not s then
            rows[i + 1] = { show = false, segD = "M0 0", rimD = "M0 0", innerD = "M0 0", segT = "translate(0dp, 0dp)", left = "0dp", top = "0dp",
                weapon = false, unarmed = false, empty = false, on = false, held = false, holstered = false, chosen = false,
                hasImage = false, image = BLANK, kit = false, rounds = "", roundsEmpty = false }
        else
            local c = -90 + i * step
            local on = i == index
            local dx, dy = at(c, on and POP or 0)
            local x, y = at(c, rMid + (on and POP or 0))
            local w = s.weapon
            local image = w and W.image(w.image)
            rows[i + 1] = {
                show = true,
                segD = W.sector(c - step / 2 + GAP, c + step / 2 - GAP, R_IN, R_OUT),
                rimD = W.arc(c - step / 2 + GAP + 0.6, c + step / 2 - GAP - 0.6, R_OUT - 3),
                innerD = W.arc(c - step / 2 + GAP + 0.6, c + step / 2 - GAP - 0.6, R_IN + 3),
                segT = ("translate(%sdp, %sdp)"):format(num(dx), num(dy)),
                left = ("%sdp"):format(num(HALF + x)), top = ("%sdp"):format(num(HALF + y)),
                weapon = s.kind == "weapon", unarmed = s.kind == "unarmed", empty = s.kind == "empty",
                on = on, held = w ~= nil and w.hand ~= nil, holstered = holstered, chosen = chosen == s.key,
                hasImage = image ~= nil, image = image or BLANK,
                kit = w ~= nil and w.kit == true,
                rounds = w and W.pad(w.rounds) or "",
                roundsEmpty = w ~= nil and (tonumber(w.rounds) or 0) <= 0,
            }
        end
    end
    return rows
end
--- The ticks on the outer orbit, between two slots: one path.
function W.ticks(n)
    local step, parts = 360 / n, {}
    for i = 0, n - 1 do
        local x0, y0 = at(-90 + i * step + step / 2, R_OUT + 20)
        local x1, y1 = at(-90 + i * step + step / 2, R_OUT + 32)
        parts[#parts + 1] = ("M%s %sL%s %s"):format(num(x0), num(y0), num(x1), num(y1))
    end
    return table.concat(parts)
end

--- The slot a virtual stick at `angle` (degrees, 0 = east) points at, 0-based.
function W.slotAt(angle, n)
    local step = 360 / n
    return round((angle + 90) / step) % n
end

-- ---- state ---------------------------------------------------------------------------------
local doc
local phase = "closed"     -- closed | open | closing
local slots = W.slots(nil)
local index, aim, chosen, key, latched = 0, nil, nil, "TAB", false
local armament
local capacity = 0
local kick = 1
local vec, last = { x = 0, y = 0 }, nil
local settleUntil = 0
local wheelLast, leftDown, rightDown = nil, false, false
local pending, committedAt, sequence = nil, -FEEDBACK_MS, 0
local toast, toastFlip, toastSerial = nil, 1, 0
local closeSerial = 0
local cursorStyle -- the page's cursor style before the wheel hid it
local polling = false

local function model()
    local m = W.hub(slots[1], nil)
    m.shown, m.open, m.closing, m.kick = false, false, false, 1
    m.rows, m.ticks = W.rows(slots, 0, nil, nil, 0), W.ticks(#slots)
    m.needleOn, m.needleT = false, "rotate(0deg)"
    m.sync, m.latched, m.keyText = false, false, "TAB"
    m.toastOn, m.toastFlip, m.toastError, m.toastTitle, m.toastText, m.hasToastText = false, 1, false, "", "", false
    return m
end

local function render()
    if not doc then return end
    local n = #slots
    if index > n - 1 then index = n - 1 end
    capacity = math.max(capacity, n)
    local values = W.hub(slots[index + 1] or slots[1], armament)
    values.shown, values.open, values.closing, values.kick = phase ~= "closed", phase == "open", phase == "closing", kick
    values.rows, values.ticks = W.rows(slots, index, chosen, armament, capacity), W.ticks(n)
    values.needleOn = aim ~= nil
    values.needleT = ("rotate(%sdeg)"):format(num(aim or 0))
    values.sync = type(armament) == "table" and armament.busy == true
    values.latched, values.keyText = latched, key
    values.toastOn = toast ~= nil
    values.toastFlip, values.toastError = toastFlip, toast ~= nil and toast.error == true
    values.toastTitle, values.toastText = toast and toast.title or "", toast and toast.text or ""
    values.hasToastText = toast ~= nil and toast.text ~= nil and toast.text ~= ""
    N.patch(doc, "ww", values)
end

local function say(title, text, error)
    toastSerial = toastSerial + 1
    toastFlip = toastFlip == 1 and 2 or 1
    toast = { title = title, text = text, error = error == true }
    local serial = toastSerial
    render()
    CreateThread(function()
        Wait(error and 3600 or 2200)
        if toastSerial == serial then toast = nil; render() end
    end)
end

--- What WeaponWheel.tsx emitted: to client/core/weapon_wheel.lua.
local function message(p)
    local wheel = LightRpWeaponWheel
    if type(wheel) == "table" and type(wheel.message) == "function" then
        local ok, why = pcall(wheel.message, p)
        if not ok then N.log("weapon wheel message failed: " .. tostring(why)) end
        return true
    end
    return false
end

-- ---- the cursor ----------------------------------------------------------------------------
local function page() return LightRpUi and LightRpUi.page end
local function centerCursor()
    local cursor = Open77.cursor
    if type(cursor) == "table" and type(cursor.center) == "function" then
        local ok, done = pcall(cursor.center)
        return ok and done == true
    end
    return false
end
local function hideCursor()
    local p = page()
    if not p or type(p.setCursor) ~= "function" then return end
    if cursorStyle == nil and type(p.getCursor) == "function" then
        local ok, style = pcall(p.getCursor, p)
        cursorStyle = ok and type(style) == "string" and style or "default"
    end
    pcall(p.setCursor, p, "none") -- the page's .ww had cursor: none
end
local function restoreCursor()
    local p = page()
    if cursorStyle == nil or not p or type(p.setCursor) ~= "function" then return end
    pcall(p.setCursor, p, cursorStyle)
    cursorStyle = nil
end

-- ---- picking -------------------------------------------------------------------------------
local function aimAt(i)
    local n = #slots
    if i == index or i < 0 or i >= n or slots[i + 1].kind == "empty" then return end
    index = i
    kick = kick == 1 and 2 or 1
    message({ kind = "hover" })
end
W.aimAt = function(i) aimAt(i); render() end

--- The pointer moved by (dx, dy) dp: the virtual stick (WeaponWheel.tsx `move`).
local function stick(dx, dy)
    vec.x, vec.y = vec.x + dx, vec.y + dy
    local len = math.sqrt(vec.x * vec.x + vec.y * vec.y)
    if len > CLAMP then vec.x, vec.y = vec.x * CLAMP / len, vec.y * CLAMP / len end
    if len < DEAD then return end
    local angle = math.deg(math.atan(vec.y, vec.x))
    aim = angle
    aimAt(W.slotAt(angle, #slots))
end
W.stick = function(dx, dy) stick(dx, dy); render() end

--- The mouse wheel: the next slot that holds something (dir 1 = clockwise).
local function cycle(dir)
    local n = #slots
    local i = index
    for _ = 1, n - 1 do
        i = (i + dir + n) % n
        if slots[i + 1].kind ~= "empty" then
            aimAt(i)
            aim = -90 + (360 / n) * i
            break
        end
    end
end

local function finish()
    phase = "closing"
    closeSerial = closeSerial + 1
    local serial = closeSerial
    restoreCursor()
    render()
    CreateThread(function()
        Wait(CLOSE_MS)
        if phase == "closing" and closeSerial == serial then phase = "closed"; render() end
    end)
end

local function mutationKey()
    sequence = sequence + 1
    local chars, rnd = "abcdefghijklmnopqrstuvwxyz0123456789", {}
    for i = 1, 7 do local k = math.random(1, #chars); rnd[i] = chars:sub(k, k) end
    return ("arm:%d:%d:%s"):format(N.now(), sequence, table.concat(rnd))
end

--- performArmament("select", { instanceId }): the request the page sent through client/core/armament.lua.
local function selectWeapon(instanceId)
    local request = mutationKey()
    local payload = { operation = "select", request = request, instanceId = instanceId,
        baseRevision = type(armament) == "table" and tonumber(armament.revision) or 0, mutation = mutationKey() }
    pending = { request = request, at = N.now() }
    local ok, accepted, why = pcall(TriggerServerEvent, NET, payload)
    if not ok or accepted == false then
        pending = nil
        say("NOT EQUIPPED", tostring(ok and (why or "network_refused") or accepted), true)
    end
    -- no answer: the page gave up after 14 s (the request may still complete)
    local mine = pending
    CreateThread(function()
        Wait(REQUEST_MS)
        if pending == mine then pending = nil end
    end)
end

local function commit()
    if phase ~= "open" then return end
    local slot, a = slots[index + 1], armament
    if not slot then finish(); return end
    local busy = pending ~= nil or (type(a) == "table" and a.busy == true)
    if slot.kind == "unarmed" then
        -- the server holsters whatever is in the hands, armament or not (B does the same)
        message({ kind = "holster" })
        committedAt, chosen = N.now(), slot.key
        message({ kind = "chosen", unarmed = true })
        say("HOLSTERED", "Hands free. Your loadout stays with you.")
        finish()
        return
    end
    local request
    if slot.kind == "weapon" and slot.weapon then
        local right = type(a) == "table" and type(a.right) == "table" and a.right or nil
        if not (right and right.instanceId == slot.weapon.instanceId and not a.holstered) then request = slot.weapon.instanceId end
    end
    if request and busy then say("EQUIPMENT BUSY", "Synchronizing — try again in a moment.", true)
    elseif request then
        committedAt, chosen = N.now(), slot.key
        message({ kind = "chosen", unarmed = false })
        say("IN HAND", str(slot.weapon.label))
        selectWeapon(request)
    end
    finish()
end

local onMessage -- defined below (a click closes through the core, which answers on the channel)

local function click(commitIt)
    -- the page's mousedown: weapon_wheel.lua closes (commit / cancel) and answers on the channel
    if not message({ kind = "close", commit = commitIt }) then onMessage({ kind = commitIt and "commit" or "cancel" }) end
end

local function readInput()
    local input = Open77.input
    if type(input) ~= "table" then return end
    local now = N.now()
    if type(input.pointer) == "function" then
        local ok, x, y = pcall(input.pointer)
        if ok and type(x) == "number" and type(y) == "number" then
            local px, py = x * 1920, y * 1080 -- the page's pixels
            if last == nil or now < settleUntil then
                last = { px, py }
            elseif px ~= last[1] or py ~= last[2] then
                local dx, dy = px - last[1], py - last[2]
                last = { px, py }
                stick(dx, dy)
            end
        end
    end
    if type(input.axis) == "function" then
        local ok, value = pcall(input.axis, "mouseWheel")
        if ok and type(value) == "number" then
            if wheelLast ~= nil and value ~= wheelLast then cycle(value > wheelLast and -1 or 1) end -- positive: away (up)
            wheelLast = value
        end
    end
    if type(input.isDown) == "function" then
        local okL, l = pcall(input.isDown, "mouse1")
        local okR, r = pcall(input.isDown, "mouse2")
        l, r = okL and l == true, okR and r == true
        local wasL, wasR = leftDown, rightDown
        leftDown, rightDown = l, r
        if l and not wasL then click(true) elseif r and not wasR then click(false) end
    end
end

local function poll()
    polling = true
    local centered = false
    while phase == "open" do
        -- the capture may start a frame after the focus: centre until it takes
        if not centered and N.now() < settleUntil then
            centered = centerCursor()
            if centered then last = nil end
        end
        local before = index
        local beforeAim = aim
        local ok, why = pcall(readInput)
        if not ok then N.log("weapon wheel input failed: " .. tostring(why)) end
        if phase == "open" and (index ~= before or aim ~= beforeAim) then render() end
        Wait(0)
    end
    polling = false
end

local function snapshotButtons()
    local input = Open77.input
    leftDown, rightDown, wheelLast = false, false, nil
    if type(input) ~= "table" then return end
    if type(input.isDown) == "function" then
        local okL, l = pcall(input.isDown, "mouse1")
        local okR, r = pcall(input.isDown, "mouse2")
        leftDown, rightDown = okL and l == true, okR and r == true
    end
    if type(input.axis) == "function" then
        local ok, value = pcall(input.axis, "mouseWheel")
        if ok and type(value) == "number" then wheelLast = value end
    end
end

local function animateIn()
    if not doc then return end
    pcall(function()
        doc:animate(".ww-seg-fade", { from = { opacity = 0 }, to = { opacity = 1 }, duration = 0.3, easing = "ease-out", delay = 0.06, stagger = 0.024 })
        doc:animate(".ww-item-in", { from = { opacity = 0, scale = 0.4 }, to = { opacity = 1, scale = 1 }, duration = 0.32, easing = "back-out", delay = 0.09, stagger = 0.024 })
    end)
end

local function onOpen(p)
    if armament == nil and LightRpArmamentClient and type(LightRpArmamentClient.state) == "function" then
        local ok, state = pcall(LightRpArmamentClient.state)
        if ok and type(state) == "table" then armament = state end
    end
    slots = W.slots(armament)
    local held = 0
    local right = type(armament) == "table" and type(armament.right) == "table" and armament.right.instanceId or nil
    if right then
        for i, s in ipairs(slots) do if s.key == right then held = i - 1; break end end
    end
    index, aim, chosen, latched = held, nil, nil, false
    kick = kick == 1 and 2 or 1 -- the hub card kicks in with the wheel
    key = type(p.key) == "string" and p.key ~= "" and p.key or "TAB"
    vec, last = { x = 0, y = 0 }, nil
    settleUntil = N.now() + 120
    snapshotButtons()
    phase = "open"
    closeSerial = closeSerial + 1
    hideCursor()
    render()
    animateIn()
    if not polling then CreateThread(poll) end
end

onMessage = function(p)
    if type(p) ~= "table" then return end
    if p.kind == "open" then onOpen(p)
    elseif p.kind == "latch" then latched = true; render()
    elseif p.kind == "commit" then commit()
    elseif p.kind == "cancel" then if phase == "open" then finish() end end
end
W.onMessage = onMessage

local function setArmament(state)
    if type(state) ~= "table" then return end
    if type(state.arsenal) ~= "table" then state.arsenal = {} end
    armament = state
    if phase ~= "closed" then slots = W.slots(armament) end
    render()
end

local function onArmament(p)
    if type(p) ~= "table" then return end
    if p.kind == "state" and type(p.state) == "table" then setArmament(p.state)
    elseif p.kind == "response" then
        if p.ok and type(p.data) == "table" and type(p.data.state) == "table" then setArmament(p.data.state) end
        if pending and p.request == pending.request then
            pending = nil
            -- a refusal from the server right after a choice replaces the confirmation
            if not p.ok and N.now() - committedAt < FEEDBACK_MS then
                say("NOT EQUIPPED", type(p.error) == "string" and p.error ~= "" and p.error or "The equipment request was refused.", true)
            end
        end
    end
end

--- The wheel's state, for the lab.
function W.current() return { phase = phase, index = index, aim = aim, slots = slots, latched = latched, pending = pending } end

N.on(PAGE, onMessage)
N.on(ARMAMENT, onArmament)

N.onStart(function()
    doc = N.create({ document = "ui/native/weapon_wheel.rml", zIndex = 60, models = { ww = model() } })
    render()
end)
