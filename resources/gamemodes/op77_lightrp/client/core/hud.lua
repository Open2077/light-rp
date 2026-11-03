-- HUD sampling: vitals, vehicle, voice and the clock, read on the client and
-- pushed to the page ten times a second. The stock readouts they replace are
-- hidden once the first sample is in.
local Config = LightRpConfig
local E = LightRpEvents
local Hud = { ready = false, voiceRange = Config.voice.default, hidden = false, externalSpeedometer = false, externalWeaponHud = false }
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
-- character arms) rather than the game's.
AddEventHandler("op77_weaponhud:state", function(state)
    Hud.externalWeaponHud = type(state) == "table" and state.active == true
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == "op77_speedometer" then Hud.externalSpeedometer = false end
    if name == "op77_weaponhud" then Hud.externalWeaponHud = false end
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
-- the crew frame stayed across the hologram. The page's own sample is the fallback.
local function hologramShown(own)
    local ok, shown = pcall(function() return exports.op77_weaponhud:isShown() end)
    if ok and type(shown) == "boolean" then return shown end
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
                local own = LightRpWeaponHud and LightRpWeaponHud.sample() or nil
                view.weapon = { active = false, externalTop = hologramShown(own) and hologramTop() or 0 }
            elseif LightRpWeaponHud then
                view.weapon = LightRpWeaponHud.sample()
                weaponHudSent.inset, weaponHudSent.labels = -1, nil
            end
            if view.ready then hideVanillaReadouts() end
            LightRpUi.send(E.page.hud, view)
            Wait(100)
        end
    end)
end
