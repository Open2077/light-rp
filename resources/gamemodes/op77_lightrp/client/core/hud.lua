-- HUD sampling: vitals, vehicle, voice and the clock, read on the client and
-- pushed to the page ten times a second. The stock readouts they replace are
-- hidden once the first sample is in.
local Config = LightRpConfig
local E = LightRpEvents
local Hud = { ready = false, voiceRange = Config.voice.default, hidden = false }
LightRpHud = Hud

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

local function sampleVehicle()
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

local function hideVanillaReadouts()
    if Hud.hidden or type(Open77.hud) ~= "table" or type(Open77.hud.setVisible) ~= "function" then return end
    for _, component in ipairs({ "health", "stamina", "speedometer" }) do pcall(Open77.hud.setVisible, component, false) end
    Hud.hidden = true
end

function Hud.start()
    CreateThread(function()
        while true do
            sampleStats()
            sampleVehicle()
            sampleVoice()
            sampleClock()
            if view.ready then hideVanillaReadouts() end
            LightRpUi.send(E.page.hud, view)
            Wait(100)
        end
    end)
end
