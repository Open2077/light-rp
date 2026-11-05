-- HUD sampling: vitals, vehicle, voice and the clock, read on the client and
-- pushed to the page ten times a second. The stock readouts they replace are
-- hidden once the first sample is in. While the player pilots a Titan
-- (op77_lightrp_titans) the sample also carries its hull, shield, weapon, abilities
-- and core, for the page to show in place of the player's own gauges; BT's weapon is
-- shown by op77_weaponhud's hologram when that runs, by the page's own dial otherwise.
local Config = LightRpConfig
local E = LightRpEvents
local Hud = { ready = false, voiceRange = Config.voice.default, hidden = false, externalSpeedometer = false, externalWeaponHud = false, titanActive = false }
LightRpHud = Hud

-- op77_speedometer (standalone, the holographic speedometer) draws the vehicle readout
-- while it runs: the page's vehicle cluster then stands down. It announces itself with
-- op77_speedometer:state and answers op77_speedometer:query (sent from Hud.start).
AddEventHandler("op77_speedometer:state", function(state)
    Hud.externalSpeedometer = type(state) == "table" and state.active == true
end)
-- op77_weaponhud (standalone, the holographic weapon HUD at the bottom left) likewise: the
-- page's weapon readout stands down while it runs. It is lifted above the grenade chip,
-- which sits in the same corner, and shows the RP names of the weapons (raid kit,
-- character arms) rather than the game's. A piloted Titan's weapon is handed to it too
-- (setExternal, below); externalSent is what it holds of ours ("" = nothing, nil = unknown:
-- it started, stopped or was switched, so the next sample sends whatever is wanted again).
local externalSent = nil
AddEventHandler("op77_weaponhud:state", function(state)
    Hud.externalWeaponHud = type(state) == "table" and state.active == true
    externalSent = nil
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == "op77_speedometer" then Hud.externalSpeedometer = false end
    if name == "op77_weaponhud" then Hud.externalWeaponHud = false; externalSent = nil end
end)

local GRENADE_CHIP_LIFT = 30 -- the chip spans y 922-940 above the gauges (CSS px of 1080)
local weaponHudSent = { inset = -1, labels = nil }
local function weaponLabels()
    local map, keys = {}, {}
    local raid = LightRpRaidClient and LightRpRaidClient.state
    if raid and type(raid.kit) == "table" then
        for record, label in pairs(raid.kit) do if type(label) == "string" then map[record] = label end end
    end
    local arms = LightRpArmamentClient and LightRpArmamentClient.state and LightRpArmamentClient.state()
    if type(arms) == "table" then
        for _, hand in ipairs({ arms.right, arms.left }) do
            if type(hand) == "table" and type(hand.record) == "string" and type(hand.label) == "string" then map[hand.record] = hand.label end
        end
    end
    for record, label in pairs(map) do keys[#keys + 1] = record .. "=" .. label end
    table.sort(keys)
    return map, table.concat(keys, ";")
end
local function syncWeaponHud()
    local chip = LightRpGrenadesClient and LightRpGrenadesClient.chipShown and LightRpGrenadesClient.chipShown() or false
    local inset = chip and GRENADE_CHIP_LIFT or 0
    if inset ~= weaponHudSent.inset then
        weaponHudSent.inset = inset
        TriggerEvent("op77_weaponhud:inset", GetCurrentResourceName(), inset)
    end
    local map, key = weaponLabels()
    if key ~= weaponHudSent.labels then
        weaponHudSent.labels = key
        TriggerEvent("op77_weaponhud:labels", GetCurrentResourceName(), map)
    end
end

-- The holographic weapon HUD's top edge (page px from the bottom of the screen) while a
-- weapon is out, 0 otherwise: the page keeps that much of the bottom-left stack free so
-- the crew frame and the safe-zone chip sit above the hologram, not across it. Its
-- layout (bottom, offsetY, scale) is read from op77_weaponhud every few seconds.
local HOLOGRAM_HEIGHT, HOLOGRAM_HEAD = 210, 14 -- the display's box at scale 1; corner marks and glow above it
local hologramLayout, hologramReadAt = nil, -math.huge

-- Whether op77_weaponhud's hologram is up right now. Asked of op77_weaponhud itself: it
-- shows for any weapon in hand, while LightRpWeaponHud.sample() only knows Light RP's
-- armament and kit weapons, so with another weapon (an AJAX from the admin menu, 2026-11-04)
-- the crew frame stayed across the hologram. The page's own sample is the fallback, taken
-- only then (it asks the game for a weapon snapshot of its own).
local function hologramShown()
    local ok, shown = pcall(function() return exports.op77_weaponhud:isShown() end)
    if ok and type(shown) == "boolean" then return shown end
    local own = LightRpWeaponHud and LightRpWeaponHud.sample() or nil
    return type(own) == "table" and own.active == true
end
local function hologramTop()
    local t = GetGameTimer and GetGameTimer() or 0
    if t - hologramReadAt > 3000 then
        hologramReadAt = t
        local ok, cfg = pcall(function() return exports.op77_weaponhud:getConfig() end)
        hologramLayout = ok and type(cfg) == "table" and type(cfg.layout) == "table" and cfg.layout or hologramLayout
    end
    local l = hologramLayout or {}
    local bottom = (tonumber(l.bottom) or 142) - (tonumber(l.offsetY) or 0)
    local scale = tonumber(l.scale) or 0.6
    return math.floor(bottom + math.max(0, weaponHudSent.inset) + HOLOGRAM_HEIGHT * scale + HOLOGRAM_HEAD + 0.5)
end

local function number(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil or parsed ~= parsed then return fallback end
    return parsed
end

-- The Titan the player pilots (op77_lightrp_titans, Titan Assault): its client export hudState answers the state its HUD module
-- built (fields: that resource's ui/hud_panel.js), or nil on foot and without the resource. The view then carries `titan` (BT's
-- hull and shield, for the health and armor gauges), `weapon` (BT's, `titan = true`: the page's own dial, only while
-- op77_weaponhud is not there to show it) and `titanKit` (the abilities the class may use and the burst core, for the ability
-- bar the page puts where the quick items sit). Hud.titanActive tells the hotbar, which stands down meanwhile. Without a state
-- the view is the player's own, as it always was.
local TITANS = "op77_lightrp_titans"

local function titanState()
    if type(GetResourceState) == "function" and GetResourceState(TITANS) ~= "running" then return nil end
    local ok, state = pcall(function() return exports.op77_lightrp_titans:hudState() end)
    if ok and type(state) == "table" then return state end
    return nil
end

local function text(value)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

-- The stand-by class (before a pick) is labelled with the Titan's own name: the chip then names it once.
local function titanSummary(t)
    local h = type(t.hull) == "table" and t.hull or nil
    local name = h and text(h.name) or "BT-7274"
    local className = text(t.className)
    if className == name then className = nil end
    local summary = { name = name, className = className, held = t.held == true }
    if h then
        local hull = { value = number(h.hull, 0), max = math.max(1, number(h.segments, 1) * number(h.segment, 1)), low = h.low == true }
        local doomed = number(h.doomed, nil)
        if doomed then hull.doomed, hull.doomedText = math.min(1, math.max(0, doomed)), text(h.doomedText) end
        summary.hull = hull
        local shield = number(h.shield, nil)
        if shield then summary.shield = math.floor(math.min(1, math.max(0, shield)) * 1000 + 0.5) / 10 end
        summary.flash = number(h.flash, nil)
    end
    return summary
end

-- BT's weapon in the shape of the player's own weapon readout: one right hand, no reserve; a melee weapon has no magazine.
local function titanWeapon(w)
    if type(w) ~= "table" then return nil end
    local hand = { hand = "right", label = text(w.name) or "WEAPON", reloading = w.reload ~= nil }
    if w.melee == true then
        hand.melee = true
    else
        hand.magazine, hand.capacity = number(w.ammo, nil), number(w.capacity, nil)
    end
    return { active = true, titan = true, hands = { hand } }
end

-- BT's weapon for op77_weaponhud (exports.op77_weaponhud:setExternal): the guns read TITAN on the class badge and their kind
-- as the type; a melee weapon carries the class the page's melee label reads (BLADE, BLUNT) and says what it is as the type.
-- The weapon's id is the Titan's own (controller/open77_titan_hud.lua: xo16, pred, rail, sword, fist). `boost` makes the
-- readout glow while a core burns (Burst, Sword, Berserker); Northstar's flight strike boosts no weapon.
local TITAN_WEAPONS = {
    xo16 = { type = "RIFLE" }, pred = { type = "CANNON" }, rail = { type = "CHARGE RIFLE" },
    sword = { type = "SWORD", class = "BLADE" }, fist = { type = "FISTS", class = "BLUNT" },
}
local function titanExternal(w, core)
    if type(w) ~= "table" then return nil end
    local id = text(w.id)
    local spec = id and TITAN_WEAPONS[id] or {}
    local melee = w.melee == true
    local state = {
        key = "titan:" .. (id or text(w.name) or "weapon"), name = text(w.name) or "WEAPON", type = spec.type,
        class = melee and (spec.class or "BLADE") or "TITAN", melee = melee, reloading = w.reload ~= nil,
    }
    if not melee then state.magazine, state.capacity = number(w.ammo, nil), number(w.capacity, nil) end
    if type(core) == "table" and core.state == "active" and core.ability ~= "flight" then state.boost = true end
    return state
end

local EXTERNAL_RETRY_MS = 2000
local externalRetryAt = -math.huge

-- Hands BT's weapon (nil: none) to op77_weaponhud, only when what it holds differs from what is wanted. True while
-- op77_weaponhud is in charge of the weapon readout (running, and it took the call), so the page's own dial stays down; false
-- without it, or while it refuses (an older build without the export is asked again every EXTERNAL_RETRY_MS only).
local function feedExternalWeapon(state)
    if not Hud.externalWeaponHud then return false end
    if type(GetResourceState) == "function" and GetResourceState("op77_weaponhud") ~= "running" then return false end
    local sig = ""
    if state then
        sig = table.concat({ state.key, state.name, state.class, state.type or "", tostring(state.melee), state.magazine or "",
            state.capacity or "", tostring(state.reloading), tostring(state.boost == true) }, "|")
    end
    if sig == externalSent then return true end
    local t = GetGameTimer and GetGameTimer() or 0
    if t < externalRetryAt then return false end
    local ok, accepted = pcall(function() return exports.op77_weaponhud:setExternal(state) end)
    if ok and accepted == true then
        externalSent = sig
        return true
    end
    externalRetryAt = t + EXTERNAL_RETRY_MS
    return false
end

-- The nine abilities a class can lock (the Titan resource's T.classAbilities). A cell of anything else (the broadsword's SPIN on
-- the reload key: melee is never locked) is the weapon's own and always shown.
local LOCKABLE = { missiles = true, vortex = true, smoke = true, dash = true, jets = true, sentry = true, flight = true,
    designator = true, core = true }

-- The cells of the abilities the class may use (every one when the state names no class), and the core when the class has it.
local function titanKit(t)
    local allowed = type(t.allowed) == "table" and t.allowed or nil
    local kit = { abilities = {} }
    if type(t.abilities) == "table" then
        for _, cell in ipairs(t.abilities) do
            if type(cell) == "table" and type(cell.id) == "string" and (allowed == nil or allowed[cell.id] == true or not LOCKABLE[cell.id]) then
                kit.abilities[#kit.abilities + 1] = {
                    id = cell.id, name = text(cell.name), key = text(cell.key), state = text(cell.state),
                    fill = number(cell.fill, nil), count = number(cell.count, nil), left = number(cell.left, nil), tone = text(cell.tone),
                }
            end
        end
    end
    local core = type(t.core) == "table" and t.core or nil
    if core and (allowed == nil or allowed.core == true) then
        kit.core = { share = number(core.share, 0), state = text(core.state), key = text(core.key), need = number(core.need, nil),
            name = text(core.name), ability = text(core.ability) }
    end
    return kit
end

local view = {
    ready = false,
    health = { value = 100, max = 100 },
    stamina = { value = 100, max = 100 },
    armor = 0,
    vehicle = { active = false },
    voice = { state = "idle", level = 0, range = Config.voice.default },
    clock = "--:--",
    walk = nil, -- { mode, label, speed, index, count } once the player touched the walk key (client/core/movement.lua)
}

local function sampleStats()
    if type(Open77.stats) ~= "table" or type(Open77.stats.get) ~= "function" then return end
    local ok, state = pcall(Open77.stats.get)
    if not ok or type(state) ~= "table" then return end
    local health = type(state.health) == "table" and state.health or {}
    local stamina = type(state.stamina) == "table" and state.stamina or {}
    view.health = { value = math.max(0, number(health.value or health.current, 0)), max = math.max(1, number(health.maximum or health.max, 100)) }
    view.stamina = { value = math.max(0, number(stamina.value or stamina.current, 0)), max = math.max(1, number(stamina.maximum or stamina.max, 100)) }
    view.armor = math.max(0, number(state.armor, 0))
    view.ready = true
end

-- Server-owned tank on the vehicle's state bag (server/modules/fuel.lua).
local function sampleFuel(vehicleId)
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return nil end
    local ok, bag = pcall(Open77.state.entity, "vehicle", vehicleId)
    if not ok or bag == nil then return nil end
    local okLitres, litres = pcall(function() return bag:get("fuel") end)
    if not okLitres or type(litres) ~= "number" then return nil end
    local okMax, capacity = pcall(function() return bag:get("fuelMax") end)
    capacity = (okMax and type(capacity) == "number" and capacity > 0) and capacity or 60
    local fraction = math.max(0, math.min(1, litres / capacity))
    local reserve = (Config.fuel and Config.fuel.reserve) or 0.15
    return { litres = litres, capacity = capacity, fraction = fraction, low = fraction <= reserve, empty = litres <= 0 }
end

local function sampleVehicle()
    if Hud.externalSpeedometer then view.vehicle = { active = false } return end
    if type(Open77.vehicles) ~= "table" or type(Open77.vehicles.getPlayerSeat) ~= "function" or type(Open77.vehicles.get) ~= "function" then
        view.vehicle = { active = false }
        return
    end
    local seatOk, seat = pcall(Open77.vehicles.getPlayerSeat)
    if not seatOk or type(seat) ~= "table" or seat.vehicleId == nil then view.vehicle = { active = false } return end
    local vehicleOk, vehicle = pcall(Open77.vehicles.get, seat.vehicleId)
    if not vehicleOk or type(vehicle) ~= "table" then view.vehicle = { active = false } return end
    local record = tostring(vehicle.record or "")
    local label = record:gsub("^Vehicle%.v_%w+_", ""):gsub("_player$", ""):gsub("_", " "):upper()
    for _, entry in ipairs(Config.vehicles.catalog) do if entry.record == record then label = entry.label:upper() end end
    local gear = math.floor(number(vehicle.gear, 0))
    local reversing = vehicle.reversing == true or gear < 0
    view.vehicle = {
        active = true,
        label = label,
        speedKph = math.abs(number(vehicle.speed, 0)) * 3.6,
        gear = reversing and "R" or (gear == 0 and "N" or tostring(gear)),
        health = math.max(0, math.min(1, number(vehicle.health, 1))),
        fuel = sampleFuel(seat.vehicleId),
    }
end

local function sampleVoice()
    if type(Open77.voice) ~= "table" then return end
    local state = "idle"
    local level = 0
    if type(Open77.voice.isMuted) == "function" then
        local ok, muted = pcall(Open77.voice.isMuted)
        if ok and muted == true then state = "muted" end
    end
    if state ~= "muted" and type(Open77.voice.isTransmitting) == "function" then
        local ok, transmitting = pcall(Open77.voice.isTransmitting)
        if ok and transmitting == true then state = "talking" end
    end
    if type(Open77.voice.inputLevel) == "function" then
        local ok, value = pcall(Open77.voice.inputLevel)
        if ok then level = math.max(0, math.min(1, number(value, 0))) end
    end
    view.voice = { state = state, level = level, range = Hud.voiceRange }
end

local function sampleClock()
    if type(Open77.world) == "table" and type(Open77.world.getTime) == "function" then
        local ok, time = pcall(Open77.world.getTime)
        if ok and type(time) == "table" then
            view.clock = string.format("%02d:%02d", number(time.hour or time.hours, 0), number(time.minute or time.minutes, 0))
            return
        end
    end
    -- No world clock API on this build: wall clock in-game style.
    view.clock = os and os.date and os.date("%H:%M") or "--:--"
end

-- Lays the Titan over the view while the player pilots one (after the player's own weapon was sampled, which BT's replaces), and
-- takes it away the loop it is gone. BT's weapon goes to op77_weaponhud while it runs (the view's `weapon` then stays what the
-- sampler made of it: down, with the hologram's top edge); without it, to the page's own dial.
local function sampleTitan()
    local t = titanState()
    Hud.titanActive = t ~= nil
    if not t then
        view.titan, view.titanKit = nil, nil
        if view.weapon and view.weapon.titan then view.weapon = nil end
        feedExternalWeapon(nil)
        return
    end
    view.titan = titanSummary(t)
    if not feedExternalWeapon(titanExternal(t.weapon, t.core)) then
        view.weapon = titanWeapon(t.weapon) or { active = false }
    end
    view.titanKit = titanKit(t)
end

-- Player choice from the HUD's range buttons (or a key), applied to the voice
-- package when it exposes the call, remembered for the readout either way.
function Hud.setVoiceRange(range)
    local metres = Config.voice.ranges[range]
    if metres == nil then return end
    Hud.voiceRange = range
    if type(Open77.voice) == "table" and type(Open77.voice.setProximityDistance) == "function" then
        pcall(Open77.voice.setProximityDistance, metres)
    end
end

function Hud.setWalk(walk) view.walk = walk end

local hiddenReadouts = {}
local function hideVanillaReadouts()
    if Hud.hidden or type(Open77.hud) ~= "table" or type(Open77.hud.setVisible) ~= "function" then return end
    local allHidden = true
    for _, component in ipairs({ "health", "stamina", "speedometer", "weapon" }) do
        if not hiddenReadouts[component] then
            local called, accepted = pcall(Open77.hud.setVisible, component, false)
            hiddenReadouts[component] = called and accepted == true
        end
        allHidden = allHidden and hiddenReadouts[component]
    end
    Hud.hidden = allHidden
end

-- A scene that hid the whole vanilla HUD (raid intro, tutorial, creator) gives it back
-- with setVisible("all", true), which also brings back what this gamemode keeps hidden
-- (and the 3D map's native minimap): hide those again right away.
function Hud.restoreVanilla()
    if type(Open77.hud) ~= "table" or type(Open77.hud.setVisible) ~= "function" then return end
    pcall(Open77.hud.setVisible, "all", true)
    hiddenReadouts = {}
    Hud.hidden = false
    hideVanillaReadouts()
    TriggerEvent("op77:hud:vanillaRestored")
end

function Hud.start()
    TriggerEvent("op77_speedometer:query")
    TriggerEvent("op77_weaponhud:query")
    CreateThread(function()
        while true do
            sampleStats()
            sampleVehicle()
            sampleVoice()
            sampleClock()
            if Hud.externalWeaponHud then
                syncWeaponHud()
                view.weapon = { active = false, externalTop = hologramShown() and hologramTop() or 0 }
            elseif LightRpWeaponHud then
                view.weapon = LightRpWeaponHud.sample()
                weaponHudSent.inset, weaponHudSent.labels = -1, nil
            end
            sampleTitan()
            if view.ready then hideVanillaReadouts() end
            LightRpUi.send(E.page.hud, view)
            Wait(100)
        end
    end)
end
