-- =============================================================================
-- op77_scenes -- client/main.lua
-- =============================================================================
-- Presentation only: the server's short list of nearby scene spots becomes
-- LightRP "E" points -- the same keycap prompt as the shops, garages and desks,
-- drawn by op77_lightrp's HUD page (export InteractSetLocal) -- a press becomes
-- the minimum intent (a spot id), and while the server says a scene runs two
-- rebindable keys ask to get up or to change pose. The playback itself -- device,
-- camera, other players' view -- belongs to the platform's RP animation service.
-- No setmetatable here: the client Lua sandbox has none.
-- =============================================================================

local RESOURCE = GetCurrentResourceName()
local STAND_KEY = "op77_scenes_stand"
local POSE_KEY = "op77_scenes_pose"

local state = { generation = nil, spots = {}, live = {}, active = false, running = true, dirty = false, scene = nil,
    endedAt = -math.huge }

local function lightrp(name, ...)
    local promise, reason = Open77.exports.call("op77_lightrp", name, ...)
    if not promise then return nil, reason end
    return promise:await()
end

local function notify(text)
    if Open77.hud and Open77.hud.notify then
        pcall(Open77.hud.notify, text, { replace = true })
    else
        print("[scenes] " .. text)
    end
end

local function keyName(id, fallback)
    local ok, key = pcall(function() return Open77.input.keyFor and Open77.input.keyFor(id) end)
    return ok and key or fallback
end

local function accept(payload)
    if type(payload) ~= "table" then return false end
    if state.generation ~= nil and payload.generation ~= state.generation then
        if type(payload.generation) == "number" and type(state.generation) == "number" and payload.generation < state.generation then
            return false
        end
        state.spots, state.active, state.dirty = {}, false, true
    end
    state.generation = payload.generation
    return true
end

local REFUSALS = {
    spot_taken = "Someone is already there.",
    too_far = "Too far away.",
    already_in_scene = "You are already in a scene.",
    not_in_scene = "You are not in a scene.",
    scene_busy = "Wait a moment.",
    actor_busy = "Finish what you are doing first.",
    player_in_vehicle = "Not from a vehicle.",
    player_not_alive = "Not now.",
    no_spot = "Nothing to use here.",
    unknown_spot = "This place is not available.",
}

RegisterNetEvent("op77_scenes:refused", function(payload)
    if not accept(payload) then return end
    local reason = tostring(payload.reason)
    -- A get-up key pressed as the scene ended another way (an animation card's Stop, a step):
    -- nothing to say.
    if reason == "not_in_scene" and Open77.time.monotonic() - state.endedAt < 3 then return end
    notify(REFUSALS[reason] or ("Refused: " .. reason))
end)

RegisterNetEvent("op77_scenes:state", function(payload)
    if not accept(payload) then return end
    local was = state.active
    state.active, state.scene = payload.active == true, payload.active == true and payload or nil
    if state.active then
        state.spots, state.dirty = {}, true
        if not was then
            local idles = type(payload.idles) == "table" and #payload.idles or 1
            local text = ("Press %s to get up"):format(tostring(keyName(STAND_KEY, "H")))
            if idles > 1 then text = text .. (", %s to change pose"):format(tostring(keyName(POSE_KEY, "G"))) end
            notify(text)
        end
    elseif was then
        state.dirty, state.endedAt = true, Open77.time.monotonic()
        local reason = payload.reason
        if reason ~= nil and reason ~= "stood" and reason ~= "cancelled" and reason ~= "moved" then
            notify("Scene ended: " .. tostring(reason))
        end
    end
end)

RegisterNetEvent("op77_scenes:spots", function(payload)
    if not accept(payload) then return end
    local spots = {}
    for _, spot in ipairs(type(payload.spots) == "table" and payload.spots or {}) do
        if type(spot) == "table" and type(spot.id) == "string" and type(spot.position) == "table" then spots[spot.id] = spot end
    end
    state.spots, state.dirty = spots, true
end)

-- ---------------------------------------------------------------------------
-- Spots -> prompts
-- ---------------------------------------------------------------------------
local PROMPT_REACH = 2.5

local function signature(spot)
    local p = spot.position
    return table.concat({ spot.id, tostring(p.x), tostring(p.y), tostring(p.z), tostring(spot.label) }, "|")
end

-- op77_lightrp lifts its local prompts 0.7 m above the point: the spot position is already
-- the card height above the seat, so the point goes back down by that much.
local LIGHTRP_PROMPT_HEIGHT = 0.7

local function pointId(spot) return "scene." .. spot.id end

local function setPoint(spot)
    local p = spot.position
    return lightrp("InteractSetLocal", pointId(spot), {
        position = { x = p.x, y = p.y, z = p.z - LIGHTRP_PROMPT_HEIGHT },
        radius = PROMPT_REACH + 0.5, prompt = spot.label or "Use",
    }, "op77_scenes:choice", { owner = RESOURCE, spot = spot.id })
end

local function removePoint(id) return lightrp("InteractSetLocal", "scene." .. id, nil) end

local function sync()
    if not state.dirty then return end
    if state.retryAt and Open77.time.monotonic() < state.retryAt then return end
    state.dirty, state.retryAt = false, nil
    local wanted = state.active and {} or state.spots
    for id, entry in pairs(state.live) do
        local spot = wanted[id]
        if spot == nil or signature(spot) ~= entry.signature then
            state.live[id] = nil
            removePoint(id)
        end
    end
    for id, spot in pairs(wanted) do
        if state.live[id] == nil then
            local ok, reason = setPoint(spot)
            if ok then
                state.live[id] = { signature = signature(spot) }
            else
                -- op77_lightrp not running yet (or restarting): try again in a moment.
                state.dirty, state.retryAt = true, Open77.time.monotonic() + 2
                print(("[scenes] E point for %s refused: %s"):format(id, tostring(reason)))
            end
        end
    end
end

-- Fired by op77_lightrp on this client when its E key is pressed on one of our points.
AddEventHandler("op77_scenes:choice", function(payload)
    if type(payload) ~= "table" or payload.owner ~= RESOURCE or type(payload.spot) ~= "string" then return end
    if state.active then return end
    TriggerServerEvent("op77_scenes:start", payload.spot)
end)

-- op77_lightrp restarted: its local points went with its VM, put ours back.
AddEventHandler("onClientResourceStart", function(name)
    if name ~= "op77_lightrp" or name == RESOURCE then return end
    state.live, state.dirty = {}, true
end)

-- ---------------------------------------------------------------------------
-- Keys (rebindable from Pause -> Settings -> KEY BINDINGS). Not X: the animation cards of the
-- gamemodes (Freeroam, LightRP) bind X to "Stop", which ends the playback at once, without the
-- get-up (live, 2026-10-30).
-- ---------------------------------------------------------------------------
pcall(Open77.input.registerKeyMapping, {
    id = STAND_KEY, name = "Get up (scene)", key = "H",
    onPressed = function() if state.active then TriggerServerEvent("op77_scenes:stand") end end,
})
pcall(Open77.input.registerKeyMapping, {
    id = POSE_KEY, name = "Change pose (scene)", key = "G",
    onPressed = function() if state.active then TriggerServerEvent("op77_scenes:idle") end end,
})

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
AddEventHandler("onClientResourceStop", function(name)
    if name ~= RESOURCE then return end
    state.running = false
    for id in pairs(state.live) do
        pcall(Open77.exports.call, "op77_lightrp", "InteractSetLocal", "scene." .. id, nil)
    end
    state.live = {}
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent("op77_scenes:sync")
    while state.running do
        local ok, err = pcall(sync)
        if not ok then print("[scenes] prompt sync raised: " .. tostring(err)) end
        Wait(250)
    end
end)
