-- A local, resource-owned 3D ground ring. Audio/routing remain server-authoritative.
-- The anchor's native ring renderer samples world-space vertices and terrain:
-- no CEF surface, streamed mesh/material or dependency on mesh visualScale.
OpenVoiceRangePreview = {}
local Preview = OpenVoiceRangePreview
local duration = 3.0 -- seconds after the most recent confirmed change
local accent = "#FFCC00" -- LightRP accent
local marker, markerApi, previousMode, previousDistance
local expiresAt, generation = 0, 0
local lastWarning

local function warn(reason)
    reason = tostring(reason)
    if reason == lastWarning then return end
    lastWarning = reason
    print("[open-voice] Range preview unavailable: " .. reason .. "; voice is unaffected.")
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function position()
    if not Open77.character or type(Open77.character.state) ~= "function" then return nil end
    local ok, state = pcall(Open77.character.state)
    if not ok or type(state) ~= "table" or state.alive ~= true then return nil end
    local p = state.position
    if type(p) ~= "table" or not finite(p.x) or not finite(p.y) or not finite(p.z) then return nil end
    return { x = p.x, y = p.y, z = p.z }
end

function Preview.hide()
    generation = generation + 1
    if marker and markerApi then pcall(markerApi.remove, marker) end
    marker, markerApi = nil, nil
end

function Preview.reset()
    Preview.hide()
    previousMode, previousDistance = nil, nil
end

function Preview.confirm(mode, distance, visible)
    if type(mode) ~= "string" or not finite(distance) or distance < 0.5 or distance > 1000 then return end
    local changed = previousMode ~= nil and (mode ~= previousMode or distance ~= previousDistance)
    previousMode, previousDistance = mode, distance
    -- Initial connection/replayed state is not a range change. Never preview an
    -- optimistic keypress: this is called only after the server applies it.
    if not changed then return end
    if not visible then Preview.hide(); return end
    local p = position()
    if not p then Preview.hide(); return end
    local api = Open77.anchors
    if type(api) ~= "table" or type(api.create) ~= "function" or type(api.update) ~= "function"
        or type(api.remove) ~= "function" then
        Preview.hide()
        warn("world anchor API missing")
        return
    end
    -- Do not show a smaller, misleading ring for unsupported custom distances.
    if distance > 50 then Preview.hide(); warn("radius exceeds ground ring limit (50 m)"); return end
    local presentation = { radius = distance, accent = accent, thickness = 3, groundOffset = 0.08 }
    if marker then
        local ok, result, reason = pcall(api.update, marker, { position = p, presentation = presentation })
        if not ok or result ~= true then
            Preview.hide(); warn(ok and reason or result); return
        end
        expiresAt = Open77.time.monotonic() + duration
        return -- one marker and one worker, even when F11 is pressed repeatedly
    end
    local ok, id, reason = pcall(api.create, {
        render = "ring", position = p, presentation = presentation,
        tag = "voice-range", minDistance = 0, maxDistance = 200,
    })
    if not ok or not id then warn(ok and reason or id); return end
    marker, markerApi = id, api
    expiresAt = Open77.time.monotonic() + duration
    generation = generation + 1
    local worker = generation
    CreateThread(function()
        while marker == id and worker == generation do
            Wait(50) -- only while visible; no idle polling or WebUI surface
            if marker ~= id or worker ~= generation then return end
            if Open77.time.monotonic() >= expiresAt then Preview.hide(); return end
            local nextPosition = position()
            if not nextPosition then Preview.hide(); return end
            if nextPosition.x ~= p.x or nextPosition.y ~= p.y or nextPosition.z ~= p.z then
                local moved, result, updateReason = pcall(api.update, id, { position = nextPosition })
                if not moved or result ~= true then
                    Preview.hide(); warn(moved and updateReason or result); return
                end
                p = nextPosition
            end
        end
    end)
end
