-- The gameplay HUD on NativeUI (ui/native/hud.rml): what the page's Hud drew, from the same
-- traffic. Bottom-left the crew (and its invite), the weapon dials, the grenade chip and the
-- vitals; bottom-right the rental countdown and the vehicle cluster; bottom centre the quick
-- slots and the walk flash; and the interact prompt, pinned to the nearest point.
--
--   E.page.hud              vitals, weapon, vehicle, walk (client/core/hud.lua, 10 Hz)
--   E.page.interact         the nearest point's words and key (client/core/interact.lua)
--   E.page.activityHud      only its phase: in a match the needs dials step aside
--   "lightrp:ui:hotbar"     quick slots: state / activate / response (client/core/hotbar.lua)
--   "lightrp:ui:grenades"   the selected grenade (client/core/grenades.lua)
--   state: needs, rental, party, missionQueue, character.playerId
--
-- Every function of H that takes a payload and returns model values is pure (tests/).
local N = LightRpNative
local E = LightRpEvents

local H = {}
LightRpNativeHud = H

local MAX_ROWS = 8          -- CrewFrame.tsx useMaxRows at 1080p
local WALK_HOLD_MS = 1600      -- WalkFlash.tsx HOLD_MS
local DELTA_MS = 1400          -- PlayerVitals.tsx: the health change floats that long
local FLASH_MS = 1800          -- Hotbar.tsx: a used slot stays lit that long
local PROMPT_RANGE = 12.0      -- client/core/interact.lua: the page anchor's maxDistance
-- What sits under the hologram gap, in dp from the screen bottom (hud.rcss): the safe margin,
-- the vitals (86 dial + 2 + 15 caption), one stack gap; and the grenade chip with its gap.
local GAP_BELOW, GAP_GRENADE = 26 + 103 + 10, 18 + 10
-- An <img> needs a source even while its slot shows an icon: one transparent pixel. (A hidden
-- <path> likewise always carries a real glyph: an empty `d` is a parse warning.)
local BLANK = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

-- ---- small helpers ------------------------------------------------------------------------
local function finite(v)
    v = tonumber(v)
    if v == nil or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
local function round(v) return math.floor((finite(v) or 0) + 0.5) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
--- 0..100, as the page's `percent` (0 for a missing value or maximum).
local function percent(value, max)
    value = finite(value)
    if max == nil then max = 100 else max = finite(max) end
    if not value or not max or max <= 0 then return 0 end
    return clamp(value / max * 100, 0, 100)
end
--- A number as JavaScript prints it: 2, 2.5 (never 2.0).
local function num(v)
    v = finite(v)
    if not v then return "0" end
    if v == math.floor(v) then return ("%d"):format(v) end
    return (("%.4f"):format(v):gsub("0+$", ""))
end
local function list(value) return type(value) == "table" and value or {} end
local function text(value, fallback)
    if type(value) == "string" then return value end
    if type(value) == "number" then return num(value) end
    return fallback or ""
end
H.percent, H.num = percent, num

-- ---- icons --------------------------------------------------------------------------------
--- A page glyph by name (client/native/icons.lua), "package" for an unknown one, as Icon.tsx.
local function icon(name) return N.icon(type(name) == "string" and name or "package") end
H.icon = icon

-- ---- PlayerVitals -------------------------------------------------------------------------
local function meter(out, prefix, value, max, warn, draining)
    local pct = percent(value, max)
    local shown = tostring(round(math.max(0, finite(value) or 0)))
    out[prefix] = shown
    out[prefix .. "Trim"] = math.floor(pct * 10 + 0.5) / 1000
    out[prefix .. "Zero"] = pct <= 0
    out[prefix .. "Empty"] = pct == 0 and not warn
    out[prefix .. "Compact"] = #shown > 3
    if warn ~= nil then out[prefix .. "Low"] = warn end
    if draining ~= nil then out[prefix .. "Drain"] = draining end
    return pct
end

--- The five dials and the line over them, from a HUD sample and the "needs" state. `match`: an
--- activity runs (activity-hud.css: needs are frozen there, the food and water dials and the
--- warning only take room).
function H.vitals(hud, needs, match)
    hud = type(hud) == "table" and hud or {}
    needs = type(needs) == "table" and needs or {}
    local health = type(hud.health) == "table" and hud.health or {}
    local stamina = type(hud.stamina) == "table" and hud.stamina or {}
    local healthPct = percent(health.value, health.max)
    local lowHealth = healthPct <= 25
    local food, drink = percent(needs.food == nil and 100 or needs.food), percent(needs.drink == nil and 100 or needs.drink)
    local starving = needs.starving
    if starving ~= "food" and starving ~= "drink" and starving ~= "both" then starving = false end

    local out = {}
    meter(out, "hp", health.value, health.max, lowHealth or starving ~= false, starving ~= false)
    out.hpCritical = healthPct <= 10
    out.hpMax = tostring(round((finite(health.max) or 0) > 0 and health.max or 0))
    meter(out, "ar", hud.armor, 100)
    meter(out, "en", percent(stamina.value, stamina.max), 100)
    meter(out, "fd", food, 100, food <= 20, starving == "food" or starving == "both")
    meter(out, "wt", drink, 100, drink <= 20, starving == "drink" or starving == "both")

    out.matchOn = match == true
    out.starveOn, out.warnOn, out.fedOn = false, false, false
    out.starveTitle, out.starveText, out.warnText, out.fedText, out.vignetteOpacity = "", "", "", "", 0
    if starving then
        -- the banner stays as long as health drains, with how fast and how long is left
        local drain = finite(needs.drainPerMinute) or 0
        local left = ""
        if drain > 0 then
            local minutes = healthPct / drain
            left = minutes < 1 and "under a minute left" or ("~%d min left"):format(math.ceil(minutes))
        end
        local fix = starving == "both" and "Eat and drink now" or starving == "food" and "Eat something now" or "Drink something now"
        out.starveOn = true
        out.starveTitle = starving == "both" and "STARVING & DEHYDRATED" or starving == "food" and "STARVING" or "DEHYDRATED"
        out.starveText = (drain > 0 and ("−" .. num(drain) .. " % health / min · ") or "") .. left .. (left ~= "" and " · " or "") .. fix
        -- rgba(170, 10, 20, .18 + .22 * heat) against the sheet's .40
        local heat = math.max(0.35, 1 - healthPct / 100)
        out.vignetteOpacity = math.floor((0.18 + 0.22 * heat) / 0.40 * 1000 + 0.5) / 1000
    else
        local warnings = {}
        if lowHealth then warnings[#warnings + 1] = "Low health" end
        if food <= 20 then warnings[#warnings + 1] = "Hungry" end
        if drink <= 20 then warnings[#warnings + 1] = "Thirsty" end
        -- well fed: health comes back by itself (only worth showing while it is not full)
        local regen = (needs.wellFed and healthPct < 100) and (finite(needs.regenPerMinute) or 0) or 0
        if #warnings > 0 then
            out.warnOn, out.warnText = match ~= true, table.concat(warnings, " · ")
        elseif regen > 0 then
            out.fedOn, out.fedText = true, "Well fed · +" .. num(regen) .. " HP / min"
        end
    end
    return out
end

-- ---- WeaponStatus and the hologram gap ----------------------------------------------------
local function known(n) return type(n) == "number" and n >= 0 and n == math.floor(n) end
local function rounds(n) return known(n) and ("%02d"):format(n) or "—" end

function H.weapon(weapon)
    local out = { wsOn = false, wsHands = {}, wsReserve = "—", wsReserveLabel = "RESERVE" }
    if type(weapon) ~= "table" or weapon.active ~= true or type(weapon.hands) ~= "table" or #weapon.hands == 0 then return out end
    for _, hand in ipairs(weapon.hands) do
        if type(hand) == "table" then
            local pct = (known(hand.magazine) and known(hand.capacity) and hand.capacity > 0) and math.min(100, hand.magazine / hand.capacity * 100) or 0
            out.wsHands[#out.wsHands + 1] = {
                side = hand.hand == "right" and "R" or "L",
                label = text(hand.label),
                magazine = rounds(hand.magazine),
                capacity = rounds(hand.capacity),
                trim = math.floor(pct * 10 + 0.5) / 1000,
                zero = pct <= 0,
                empty = hand.magazine == 0,
                reloading = hand.reloading == true,
            }
        end
    end
    out.wsOn = #out.wsHands > 0
    out.wsReserve = rounds(weapon.reserve)
    out.wsReserveLabel = #out.wsHands > 1 and "SHARED RESERVE" or "RESERVE"
    return out
end

--- WeaponGap.tsx: the stack stays clear up to the hologram's top edge (`top` dp from the
--- screen bottom); what is under the gap is the vitals and, when shown, the grenade chip.
function H.gap(top, grenadeShown)
    top = finite(top) or 0
    if top <= 0 then return { gapOn = false, gapHeight = "0dp" } end
    local below = GAP_BELOW + (grenadeShown and GAP_GRENADE or 0)
    return { gapOn = true, gapHeight = ("%ddp"):format(math.max(0, math.ceil(top - below))) }
end

-- ---- GrenadeStatus ------------------------------------------------------------------------
function H.grenade(state)
    local on = type(state) == "table" and state.ready == true and state.selected ~= nil and state.selected ~= false and state.selected ~= ""
        and (finite(state.count) or 0) > 0
    if not on then return { grOn = false, grCount = "", grLabel = "" } end
    return { grOn = true, grCount = num(state.count), grLabel = text(state.label) }
end

-- ---- VehicleCluster -----------------------------------------------------------------------
function H.vehicle(vehicle)
    if type(vehicle) ~= "table" or vehicle.active ~= true then return { clOn = false } end
    local speed = math.max(0, finite(vehicle.speedKph) or 0)
    local health = clamp(finite(vehicle.health) or 1, 0, 1)
    local fuel = type(vehicle.fuel) == "table" and vehicle.fuel or nil
    local fraction = fuel and clamp(finite(fuel.fraction) or 0, 0, 1) or 0
    local state = not fuel and "none" or fuel.empty and "empty" or fuel.low and "low" or "ok"
    local readout = fuel and tostring(fuel.empty and 0 or math.max(0, round(fuel.litres))) or "--"
    return {
        clOn = true,
        clSpeed = round(clamp(speed / 240, 0, 1) * 30),     -- lit cells of 30
        clSpeedText = ("%03d"):format(math.min(999, round(speed))),
        clGear = text(vehicle.gear, "N"),
        clCond = round(health * 12),                          -- lit cells of 12
        clCondText = tostring(round(health * 100)),
        clFuel = round(fraction * 12),
        clFuelText = readout,
        clFuelCompact = #readout > 3,
        clFuelUnit = state == "empty" and "EMPTY" or state == "low" and "RESERVE" or "LITRES",
        clFuelLow = state == "low",
        clFuelEmpty = state == "empty",
        clName = text(vehicle.label, "VEHICLE"):upper(),
    }
end

-- ---- rental countdown ---------------------------------------------------------------------
--- `elapsedMs`: since the "rental" state arrived (its remainingMs is from the push).
function H.rental(rental, elapsedMs)
    local active = type(rental) == "table" and type(rental.active) == "table" and rental.active or nil
    if not active then return { rentOn = false, rentEnding = false, rentClock = "00:00", rentHint = "" } end
    local left = (finite(active.remainingMs) or 0) - (elapsedMs or 0)
    local ending = left <= (finite(active.warnMs) or 600000)
    local hint = ""
    if ending then
        hint = (finite(active.extensionsLeft) or 0) > 0 and ("/extendrental · +" .. num(active.extendMinutes or 30) .. " min") or "Return it at any desk"
    end
    return { rentOn = true, rentEnding = ending, rentClock = N.clock(left), rentHint = hint }
end

-- ---- CrewHud ------------------------------------------------------------------------------
local BUSY = {
    mission = { icon = "crosshair", label = "MISSION" },
    lobby = { icon = "timer", label = "BOARD" },
    activity = { icon = "swords", label = "ACTIVITY" },
}
local MISSION_STATE = { down = "DOWN", dead = "DEAD", recovering = "UP SOON" }
local RARITY = { rare = "#3FA9FF", epic = "#B36BFF", legendary = "#FFCC00", live = "#FF3FB4" }
local COMMON = "#C9D1DC"

local function memberRow(m, you)
    local state = m.state or "alive"
    local busy = m.busy and BUSY[m.busy] or nil
    local far = m.far == true and not you
    local row = {
        name = text(m.name), leader = m.leader == true, me = you, far = far,
        down = state == "down", dead = state == "dead",
        hasTitle = type(m.title) == "string" and m.title ~= "", title = text(m.title), titleColor = RARITY[m.titleRarity] or COMMON,
        chipOn = false, chipAlert = false, chipDim = false, chipText = "", chipHasIcon = false, chipIcon = icon("package"),
    }
    if state ~= "alive" then
        row.chipOn, row.chipAlert, row.chipText = true, true, state == "down" and "DOWN" or "DEAD"
    elseif busy then
        row.chipOn, row.chipText, row.chipHasIcon, row.chipIcon = true, busy.label, true, icon(busy.icon)
    elseif far then
        row.chipOn, row.chipDim, row.chipText, row.chipHasIcon, row.chipIcon = true, true, "FAR", true, icon("navigation")
    end
    return row
end

--- The crew frame: the "party" and "missionQueue" states and the local player's id.
function H.crew(party, queue, me)
    party = type(party) == "table" and party or nil
    local out = { crewOn = false, crewTitle = "CREW", crewExtra = "", crewHasExtra = false, crewCount = "",
        crewRows = {}, crewMore = "", crewHasMore = false, crewPending = {}, crewOps = {}, crewOpsMore = "", crewOpsHasMore = false }
    local members = party and list(party.members) or {}
    local inCrew = party ~= nil and party.id ~= nil and party.id ~= false and party.id ~= ""
    local running = type(queue) == "table" and queue.running == true and queue or nil
    local operators = running and list(running.squad) or {}
    -- a solo run (only you) leaves your own vitals alone
    local missionFrame = #operators > 1 or (#operators == 1 and operators[1].id ~= me)

    if missionFrame then
        local crewIds, crewSize = {}, 0
        if inCrew then for _, m in ipairs(members) do crewIds[m.id] = true; crewSize = crewSize + 1 end end
        local leader = inCrew and party.leader or nil
        out.crewOn = true
        out.crewTitle = crewSize > 1 and "CREW" or "OPERATORS"
        out.crewCount = tostring(#operators)
        out.crewExtra = text(running.title):upper()
        out.crewHasExtra = out.crewExtra ~= ""
        for i = 1, math.min(#operators, MAX_ROWS) do
            local m = operators[i]
            local maxHealth, health = finite(m.maxHealth) or 0, finite(m.health) or 0
            local hp = maxHealth > 0 and clamp(health / maxHealth, 0, 1) or 0
            local armor = clamp((finite(m.armor) or 0) / 100, 0, 1)
            local crown
            if leader ~= nil then crown = m.id == leader else crown = m.host == true end
            local alert = MISSION_STATE[m.state]
            out.crewOps[i] = {
                name = text(m.name), crown = crown, me = m.id == me,
                alertOn = alert ~= nil, alert = alert or "", health = num(health),
                hp = ("%.1f%%"):format(hp * 100), armor = ("%.1f%%"):format(armor * 100),
                low = m.state == "alive" and hp < 0.3, stranger = crewSize > 1 and not crewIds[m.id],
                down = m.state == "down", dead = m.state == "dead", recovering = m.state == "recovering",
            }
        end
        if #operators > #out.crewOps then
            out.crewOpsMore, out.crewOpsHasMore = ("+%d MORE"):format(#operators - #out.crewOps), true
        end
        return out
    end

    if not inCrew or #members == 0 then return out end
    local you = party.you
    if you == nil then you = me end
    local mine
    for i, m in ipairs(members) do if m.id == you then mine = i; break end end
    local shown = {}
    if #members > MAX_ROWS and mine and mine > MAX_ROWS then
        -- over the cap your own row still shows, in place of the last one
        for i = 1, MAX_ROWS - 1 do shown[i] = members[i] end
        shown[MAX_ROWS] = members[mine]
    else
        for i = 1, math.min(#members, MAX_ROWS) do shown[i] = members[i] end
    end
    out.crewOn = true
    out.crewCount = ("%d/%s"):format(#members, num(party.maxSize))
    if party.matchmaking then out.crewExtra, out.crewHasExtra = "MATCHMAKING", true end
    for i, m in ipairs(shown) do out.crewRows[i] = memberRow(m, m.id == you) end
    if #members > #shown then
        out.crewMore, out.crewHasMore = ("+%d MORE · F1 > CREW"):format(#members - #shown), true
    end
    if #members <= 1 then
        local pending = list(party.pending)
        for i = 1, math.min(#pending, 3) do out.crewPending[i] = { name = text(pending[i].name) } end
    end
    return out
end

--- The newest invite. `elapsedMs`: since this invite arrived (expiresInMs is from the push).
function H.invite(party, elapsedMs, keys)
    local invites = type(party) == "table" and list(party.invites) or {}
    local invite = invites[1]
    local out = { inviteOn = false, inviteFrom = "", inviteMore = "", inviteSecs = "", inviteBar = "0%", inviteAccept = "Y", inviteDecline = "N" }
    if type(invite) ~= "table" then return out end
    keys = type(keys) == "table" and keys or type(party.keys) == "table" and party.keys or {}
    local total = (finite(party.inviteSeconds) or 60) * 1000
    local left = math.max(0, (finite(invite.expiresInMs) or 0) - (elapsedMs or 0))
    local more = #invites - 1
    out.inviteOn = true
    out.inviteFrom = text(invite.fromName)
    out.inviteMore = more > 0 and (" +%d more in F1 > Crew."):format(more) or ""
    out.inviteSecs = ("%ds"):format(math.ceil(left / 1000))
    out.inviteBar = ("%.1f%%"):format(total > 0 and math.min(100, left / total * 100) or 0)
    out.inviteAccept, out.inviteDecline = text(keys.accept, "Y"), text(keys.decline, "N")
    return out
end

-- ---- Hotbar -------------------------------------------------------------------------------
--- ItemArt.tsx: a template's own picture (web/img/items) when it has one; the fitting room's
--- garment pictures live on the CDN, which a NativeUI document cannot load: those keep the icon.
local function itemImage(item)
    local image = item.image
    if type(image) ~= "string" then return nil end
    if image:match("^img/items/[a-z0-9][a-z0-9_%-]*%.png$") or image:match("^img/items/[a-z0-9][a-z0-9_%-]*%.webp$") then
        return "/web/" .. image
    end
    return nil
end
H.itemImage = itemImage

--- `state`: the last "state" message ({ ready, items, visible, showKey, slotKeys }); `flash`:
--- { slot, request, error, text } while a slot is lit.
function H.hotbar(state, flash)
    state = type(state) == "table" and state or {}
    local out = { hbOn = state.ready == true and state.visible == true, hbSlots = {}, hbHint = "", hbHintError = false }
    local bySlot = {}
    for _, item in pairs(list(state.items)) do
        if type(item) == "table" and item.slot ~= nil and bySlot[item.slot] == nil then bySlot[item.slot] = item end
    end
    local keys = list(state.slotKeys)
    for slot = 1, 5 do
        local item = bySlot[slot]
        local active = flash ~= nil and flash.slot == slot
        local entry = { key = text(keys[slot], tostring(slot)), filled = item ~= nil, active = active, error = active and flash.error == true,
            count = "", label = "", hasImage = false, image = BLANK, icon = icon("package") }
        if item then
            local image = itemImage(item)
            entry.count = "×" .. num(item.count)
            entry.label = text(item.label)
            entry.hasImage, entry.image = image ~= nil, image or BLANK
            entry.icon = icon(item.category == "weapon" and "crosshair" or item.icon)
        end
        out.hbSlots[slot] = entry
    end
    if flash and flash.error then
        out.hbHint, out.hbHintError = text(flash.text), true
    else
        out.hbHint = "QUICK USE · HOLD " .. text(state.showKey, "TAB")
    end
    return out
end

-- ---- WalkFlash ----------------------------------------------------------------------------
function H.walk(walk)
    local count = math.max(0, math.floor(finite(walk.count) or 3))
    local index = finite(walk.index) or 1
    -- cells fill with the pace: the first mode (run) lights them all, the last one
    local lit = math.max(1, count - index + 1)
    local cells = {}
    for i = 0, count - 1 do cells[i + 1] = { i = i, h = ("%ddp"):format(6 + i * 5), on = i < lit } end
    local speed = finite(walk.speed)
    return { wfLabel = text(walk.label), wfPace = (speed and speed ~= 0) and ("%.1f M/S"):format(speed) or "FULL PACE", wfCells = cells }
end

-- ---- InteractPrompt -----------------------------------------------------------------------
function H.prompt(payload)
    if type(payload) ~= "table" or type(payload.prompt) ~= "string" or payload.prompt == "" then return { iaOn = false } end
    return { iaOn = true, iaKey = text(payload.key, "E"), iaText = payload.prompt }
end

-- ---- the model ----------------------------------------------------------------------------
--- Every name hud.rml binds, with its resting value.
function H.defaults()
    local m = { ready = false, hidden = true, quiet = false,
        deltaOn = false, deltaLoss = false, deltaText = "",
        wfOn = false, wfLabel = "", wfPace = "", wfCells = {},
        clSpeed = 0, clSpeedText = "000", clGear = "N", clCond = 0, clCondText = "100", clFuel = 0, clFuelText = "--",
        clFuelCompact = false, clFuelUnit = "LITRES", clFuelLow = false, clFuelEmpty = false, clName = "VEHICLE",
        iaOn = false, iaKey = "E", iaText = "" }
    local parts = {
        H.vitals({ health = { value = 100, max = 100 }, stamina = { value = 100, max = 100 }, armor = 0 }, nil), H.weapon(nil), H.gap(0, false), H.grenade(nil), H.vehicle(nil), H.rental(nil, 0),
        H.crew(nil, nil, nil), H.invite(nil, 0), H.hotbar(nil, nil),
    }
    for _, part in ipairs(parts) do for k, v in pairs(part) do m[k] = v end end
    return m
end

local doc
local model = H.defaults()
H.model = model
--- Keeps the values (a document created later starts from them) and sends what changed.
local function put(values)
    for k, v in pairs(values) do model[k] = v end
    N.patch(doc, "hud", values)
end

-- A class that must leave and come back for its animation to play again (the page remounted
-- the element): off, a frame or two later on, and off again after `holdMs`.
local generations = {}
local function replay(field, holdMs)
    local generation = (generations[field] or 0) + 1
    generations[field] = generation
    put({ [field] = false })
    CreateThread(function()
        Wait(40)
        if generations[field] ~= generation then return end
        put({ [field] = true })
        Wait(holdMs)
        if generations[field] == generation then put({ [field] = false }) end
    end)
end

-- ---- the HUD sample (10 Hz) -----------------------------------------------------------------
local grenades = nil
local lastHealth = nil          -- rounded, for the change floating over the dial
local lastWalk, walkSeen = nil, false

-- The shared activity HUD's phase, as the page published it on <html data-activity-hud>:
-- anything but the lobby is a match, unless the character is away.
local activityPhase = nil
local function inMatch()
    local character = N.state.character
    local away = type(character) ~= "table" or character.status ~= "active" or (character.welcomePending and true or false)
    return activityPhase ~= nil and activityPhase ~= "lobby" and not away
end

local function onHud(hud)
    if type(hud) ~= "table" then return end
    local values = H.vitals(hud, N.state.needs, inMatch())
    local weapon = H.weapon(hud.weapon)
    for k, v in pairs(weapon) do values[k] = v end
    local gap = H.gap(type(hud.weapon) == "table" and hud.weapon.externalTop or 0, model.grOn == true)
    for k, v in pairs(gap) do values[k] = v end
    for k, v in pairs(H.vehicle(hud.vehicle)) do values[k] = v end
    put(values)

    -- the health change: only while the HUD shows (the page's meter was not mounted otherwise)
    local health = tonumber(values.hp) or 0
    if lastHealth ~= nil and health ~= lastHealth and N.shell.ready then
        local difference = health - lastHealth
        put({ deltaText = (difference > 0 and "+" or "") .. tostring(difference), deltaLoss = difference < 0 })
        replay("deltaOn", DELTA_MS)
    end
    lastHealth = health

    -- the walk mode: never on the first sample, only on a change the player made
    local walk = type(hud.walk) == "table" and hud.walk or nil
    local mode = walk and walk.mode or nil
    if not walkSeen then
        walkSeen, lastWalk = true, mode
    elseif mode ~= lastWalk then
        lastWalk = mode
        if walk then
            put(H.walk(walk))
            replay("wfOn", WALK_HOLD_MS)
        end
    end
end

-- ---- state keys ---------------------------------------------------------------------------
local rentalAt = 0
local inviteAt, inviteKey = 0, nil

local function refreshRental()
    put(H.rental(N.state.rental, N.now() - rentalAt))
end
local function refreshInvite()
    local party = N.state.party
    local invite = type(party) == "table" and type(party.invites) == "table" and party.invites[1] or nil
    local key = type(invite) == "table" and (tostring(invite.party) .. ":" .. tostring(invite.expiresInMs)) or nil
    if key ~= inviteKey then inviteKey, inviteAt = key, N.now() end
    -- the effective keys: client/core/crew.lua keeps them current when a binding changes
    local crew = LightRpCrew and LightRpCrew.state
    put(H.invite(party, N.now() - inviteAt, type(crew) == "table" and crew.keys or nil))
end
local function refreshCrew()
    local character = N.state.character
    put(H.crew(N.state.party, N.state.missionQueue, type(character) == "table" and character.playerId or nil))
end

-- ---- hotbar and grenades ------------------------------------------------------------------
local hotbar, flash, flashGeneration = nil, nil, 0
local function refreshHotbar() put(H.hotbar(hotbar, flash)) end
local function setFlash(value)
    flash = value
    flashGeneration = flashGeneration + 1
    local generation = flashGeneration
    refreshHotbar()
    CreateThread(function()
        Wait(FLASH_MS)
        if flashGeneration == generation then flash = nil; refreshHotbar() end
    end)
end
local function onHotbar(p)
    if type(p) ~= "table" then return end
    if p.kind == "state" and type(p.state) == "table" then
        hotbar = { ready = p.state.ready, items = p.state.items, visible = p.visible == true, showKey = p.showKey, slotKeys = p.slotKeys }
        refreshHotbar()
    elseif p.kind == "activate" and p.slot then
        setFlash({ slot = p.slot, request = p.request })
    elseif p.kind == "response" and p.slot and flash and p.request == flash.request then
        setFlash({ slot = p.slot, request = p.request, error = not p.ok, text = (not p.ok) and p.text or nil })
    end
end
local function onGrenades(p)
    if type(p) ~= "table" or type(p.state) ~= "table" then return end
    grenades = p.state
    put(H.grenade(grenades))
end

-- ---- the interact prompt: pinned to the nearest point, every frame ---------------------------
local prompt = nil
local function onInteract(payload)
    local values = H.prompt(payload)
    prompt = values.iaOn and values or nil
    put(values)
end

local function screenSize(cache)
    local now = N.now()
    if cache.width and now - cache.at < 2000 then return cache.width, cache.height end
    cache.at = now
    local ok, state = pcall(doc.state, doc)
    if ok and type(state) == "table" and (tonumber(state.width) or 0) > 0 and (tonumber(state.height) or 0) > 0 then
        cache.width, cache.height = tonumber(state.width), tonumber(state.height)
    end
    return cache.width or 1920, cache.height or 1080
end

local function promptThread()
    local size = { at = -10000 }
    local seen, placed = false, nil
    local function show(on)
        if on == seen then return end
        seen = on
        doc:class("#interact", "is-seen", on)
    end
    while true do
        local point = prompt and LightRpInteract and LightRpInteract.near or nil
        if not point or type(point.position) ~= "table" or N.shell.hidden then
            show(false)
            Wait(100)
        else
            local x, y, visible = 0.5, 0.56, true
            if type(Open77.camera) == "table" and type(Open77.camera.project) == "function" then
                local p = point.position
                local ok, at = pcall(Open77.camera.project, { x = p.x, y = p.y, z = p.z + (point.promptHeight or 1.1) })
                visible = ok and type(at) == "table" and at.onScreen ~= false and type(at.x) == "number" and type(at.y) == "number"
                    and (type(at.distance) ~= "number" or at.distance <= PROMPT_RANGE)
                if visible then x, y = at.x, at.y end
            end
            -- an action in progress (the page's activityActive) keeps the prompt out of the way
            if visible and LightRpActions and LightRpActions.isActive and LightRpActions.isActive() then visible = false end
            if visible then
                local width, height = screenSize(size)
                local where = ("translate(%.1fpx, %.1fpx)"):format(x * width, y * height)
                if where ~= placed then
                    placed = where
                    doc:style("#interact", "transform", where)
                end
            end
            show(visible)
            Wait(0)
        end
    end
end

-- ---- wiring -------------------------------------------------------------------------------
N.on(E.page.hud, onHud)
N.on(E.page.interact, onInteract)
N.on("lightrp:ui:hotbar", onHotbar)
N.on("lightrp:ui:grenades", onGrenades)
local function refreshVitals() if N.hud and N.hud.health then put(H.vitals(N.hud, N.state.needs, inMatch())) end end
N.on(E.page.activityHud, function(message)
    if type(message) ~= "table" then return end
    if message.op == "show" and type(message.hud) == "table" then
        activityPhase = type(message.hud.phase) == "string" and message.hud.phase or "running"
    elseif message.op == "clear" then
        activityPhase = nil
    else
        return
    end
    refreshVitals()
end)
N.onState("needs", refreshVitals)
N.onState("rental", function() rentalAt = N.now(); refreshRental() end)
N.onState("party", function() refreshCrew(); refreshInvite() end)
N.onState("missionQueue", refreshCrew)
N.onState("character", function() refreshCrew(); refreshVitals() end)
N.onShell(function(shell) put({ ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet }) end)

N.onStart(function()
    local initial = {}
    for k, v in pairs(model) do initial[k] = v end
    initial.ready, initial.hidden, initial.quiet = N.shell.ready, N.shell.hidden, N.shell.quiet
    doc = N.create({ document = "ui/native/hud.rml", zIndex = 10, models = { hud = initial } })
    if not doc then return end
    H.doc = doc
    -- the countdowns: the rental's clock and the invite's seconds and bar
    CreateThread(function()
        while true do
            if model.rentOn then refreshRental() end
            if model.inviteOn then refreshInvite() end
            Wait(250)
        end
    end)
    CreateThread(promptThread)
end)
