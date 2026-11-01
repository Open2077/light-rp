-- An authored mission on this client (server/modules/mission_engine.lua runs it):
-- the perimeter's walls and the checkpoints. The objective, the waves and the
-- out-of-zone countdown are drawn by the page from the missionQueue state.
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

-- The perimeter: thin red walls with a faint fill. Built once per mission state (one
-- resume must stay short), re-sent every half second with a TTL that covers the gap.
CreateThread(function()
    TriggerServerEvent(NET, { kind = "hello" })
    local built, batch = nil, nil
    while true do
        Wait(500)
        local state = Run.state
        if not state then built, batch = nil, nil
        elseif state ~= built and state.perimeter and LightRpMissionEditor and LightRpMissionEditor.walls then
            built = state
            -- the editor's light wall builder, yielding between segments (one resume must stay short)
            batch = { lines = {}, triangles = {}, ttl = 1.2, maxDistance = 400 }
            LightRpMissionEditor.walls(batch, state.perimeter, "#ff3b3bb0", false, function() Wait(0) end)
            Wait(0)
        end
        if batch and Run.state and Open77.debugDraw then pcall(Open77.debugDraw.set, drawKey, batch) end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
