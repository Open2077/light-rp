-- Activities, client side (server/modules/activities.lua, activities_hub.lua):
-- the Neural-Link app "Gigs & Arena", which opens the Activities panel from
-- anywhere, and the GPS route to a contract board or to The Crossing.
local E = LightRpEvents
local APP = { id = "lightrp_activities", label = "Gigs & Arena", icon = "swords", color = "#FFCC00",
    event = "lightrp:activities:app", closeOnLaunch = true }
local GPS_ID = "activities.gps"
local ARRIVED, EXPIRES_MS = 8.0, 30 * 60000

-- op77_neuralink loads after Light RP, and may restart: register whenever it is up.
local function register()
    if exports == nil or type(GetResourceState) ~= "function" or GetResourceState("op77_neuralink") ~= "running" then return false end
    local called, ok = pcall(function() return exports.op77_neuralink:registerApp(APP) end)
    return called and ok == true
end

AddEventHandler(APP.event, function(id)
    if id ~= APP.id then return end
    TriggerServerEvent(E.net.action, { type = "activities.control", operation = "open", from = "neuralink" })
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= "op77_neuralink" then return end
    CreateThread(function()
        for _ = 1, 10 do
            if register() then return end
            Wait(1000)
        end
    end)
end)

CreateThread(function()
    for _ = 1, 30 do
        if register() then return end
        Wait(2000)
    end
end)

-- ---------------------------------------------------------------------------
-- GPS: a private blip with the route set, gone on arrival or after EXPIRES_MS.

local current
local function clear()
    if current then LightRpInteract.setLocal(GPS_ID, nil); current = nil end
end

RegisterNetEvent(E.net.activitiesGps, function(p)
    clear()
    if type(p) ~= "table" or type(p.position) ~= "table" or type(p.position.x) ~= "number"
        or type(p.position.y) ~= "number" or type(p.position.z) ~= "number" then return end
    local blip = LightRpInteract.setLocal(GPS_ID, {
        position = p.position, passive = true,
        blip = { icon = "map-pin", sprite = "objective", size = 44, routable = true,
            title = type(p.title) == "string" and p.title or "Destination",
            description = type(p.description) == "string" and p.description or nil },
    })
    if not blip then return end
    current = { position = p.position, expires = GetGameTimer() + EXPIRES_MS }
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
                    if dx * dx + dy * dy + dz * dz < ARRIVED * ARRIVED then clear() end
                end
            end
        end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
