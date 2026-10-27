-- After a purchase (server/modules/dealerships.lua): a private blip on the new
-- vehicle's delivery bay, or on the garage holding it, with the GPS route set to
-- it. It goes once the character gets there, or after `EXPIRES_MS`.
local E = LightRpEvents
local ARRIVED = { vehicle = 6.0, garage = 12.0 }
local EXPIRES_MS = 30 * 60000
local current

local function clear()
    if current then LightRpInteract.setLocal("vehicle.gps", nil); current = nil end
end

RegisterNetEvent(E.net.vehicleGps, function(p)
    clear()
    if type(p) ~= "table" or type(p.position) ~= "table" or type(p.position.x) ~= "number" then return end
    local garage = p.garage == true
    local blip = LightRpInteract.setLocal("vehicle.gps", {
        position = p.position, passive = true,
        blip = { icon = garage and "warehouse" or "car-front", sprite = "objective", size = 44, routable = true,
            title = type(p.title) == "string" and p.title or "Your vehicle",
            description = type(p.description) == "string" and p.description or nil },
    })
    if not blip then return end
    current = { position = p.position, radius = garage and ARRIVED.garage or ARRIVED.vehicle, expires = GetGameTimer() + EXPIRES_MS }
    LightRpInteract.trackBlip(blip)
end)

CreateThread(function()
    while true do
        Wait(1000)
        local gps = current
        if gps then
            if GetGameTimer() > gps.expires then clear()
            elseif type(Open77.character) == "table" and type(Open77.character.state) == "function" then
                local ok, state = pcall(Open77.character.state)
                local p = ok and type(state) == "table" and state.position
                if p then
                    local dx, dy, dz = p.x - gps.position.x, p.y - gps.position.y, p.z - gps.position.z
                    if dx * dx + dy * dy + dz * dz < gps.radius * gps.radius then clear() end
                end
            end
        end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
