-- An authored mission on this client (server/modules/mission_engine.lua runs it): the
-- checkpoints, and the relay of the NPC hits this client owns. The perimeter is not drawn
-- (only the editor shows it); the objective, the waves and the out-of-zone countdown are
-- drawn by the page from the missionQueue state.
local NET = "op77_lightrp:missionrun"
local Run = { state = nil, markers = {} }
LightRpMissionRun = Run
local drawKey = "lightrp:missions:perimeter"

local function clearMarkers()
    for _, handle in pairs(Run.markers) do pcall(Open77.markers.remove, handle) end
    Run.markers = {}
end
local function clear()
    Run.state = nil
    clearMarkers()
    if Open77.debugDraw and Open77.debugDraw.clear then pcall(Open77.debugDraw.clear, drawKey) end
end

local function placeCheckpoints(state)
    clearMarkers()
    if not Open77.markers or type(Open77.markers.create) ~= "function" then return end
    for _, c in ipairs(state.checkpoints or {}) do
        if not c.reached then
            local ok, handle = pcall(Open77.markers.create, { position = c.position, shape = "cylinder", radius = math.min(50, c.radius),
                height = 2.5, color = c.required and { r = 34, g = 216, b = 226, a = 110 } or { r = 242, g = 243, b = 245, a = 80 },
                style = "objective", maxDistance = 500 })
            if ok and handle then Run.markers[c.id] = handle end
        end
    end
end

RegisterNetEvent(NET, function(payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "end" then
        if not Run.state or Run.state.instance == payload.instance then clear() end
        return
    end
    if payload.kind == "state" then
        Run.state = payload
        placeCheckpoints(payload)
    end
end)

CreateThread(function() TriggerServerEvent(NET, { kind = "hello" }) end)

-- A mission or world boss NPC whose simulation this client owns hit a player: the server
-- checks it and applies it to the canonical health (the NPCs opt into
-- authoritativePlayerHits, so the engine itself no longer drains the native health). Sent
-- outside a mission run too: a world boss fights in the city, and only NPCs that opted in
-- raise this event; the server ties each hit to its mission or world boss.
AddEventHandler("open77:npcPlayerHit", function(victim, npc, epoch, amount)
    TriggerServerEvent(NET .. ":npcHit", victim, npc, epoch, amount)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
