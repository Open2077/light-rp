-- op77_turf client: what a fighter sees. No page of its own: the war is drawn by Light
-- RP's shared activity HUD (op77_lightrp client exports ActivityHudShow / Push /
-- Clear), fed from the server's state; when that HUD is missing (older Light RP) the
-- server falls back to notifications. The world-space zone markers (a ring on the
-- ground and a beacon above, in the holder's colour, the Light RP accent when
-- contested) and the op77_map3d zone blips are this resource's own.
-- Purely visual: the server alone decides captures, from its own positions.
local C = TurfConfig
local H = TurfHud

local state = { shared = nil, personal = nil, board = nil, site = nil, queued = nil }
local hud = { shown = false, signature = nil, at = -math.huge, missing = false, refused = nil }
local zones = {}     -- zone id -> { handles = { ring, beacon }, key }
local retryAt = {}   -- zone id -> monotonic seconds before the next marker attempt
local blips = {}     -- zone id -> { id, key }
local kitKey = C.keys.kit.key

local function log(level, text)
    if Open77.log and Open77.log[level] then Open77.log[level]("[turf] " .. tostring(text)) end
end

local function now() return Open77.time.monotonic() end

-- ---------------------------------------------------------------- Light RP HUD

-- A client export of op77_lightrp: ran (false when the export or the resource is
-- missing), then the export's own results.
local function core(method, ...)
    return pcall(function(...)
        local resource = exports[C.core]
        return resource[method](resource, ...)
    end, ...)
end

local function missing(reason)
    if hud.missing then return end
    hud.missing = true
    log("warn", "Light RP's activity HUD is unavailable (" .. tostring(reason) .. "): notifications instead")
    TriggerServerEvent("op77_turf:hudless")
end

local function show(model, force)
    if hud.missing then return end
    local signature = H.signature(model)
    local t = now()
    -- Same picture: re-sent every 5 s only, to keep the HUD's clock in step.
    if not force and signature == hud.signature and t - hud.at < 5.0 then return end
    local ran, ok, why = core("ActivityHudShow", model)
    if not ran then missing(ok) return end
    if ok == false and why ~= hud.refused then
        hud.refused = why
        log("warn", "activity HUD refused the turf war: " .. tostring(why))
    end
    hud.shown, hud.signature, hud.at = true, signature, t
end

local function clearHud()
    if hud.shown and not hud.missing then core("ActivityHudClear") end
    hud.shown, hud.signature, hud.at, hud.refused = false, nil, -math.huge, nil
end

local function push(kind, payload)
    if hud.missing or type(payload) ~= "table" then return end
    if kind == "result" then
        payload = H.result(payload)
    else
        payload = { title = payload.title, text = payload.text, tone = payload.tone, durationMs = payload.durationMs }
    end
    local ran, err = core("ActivityHudPush", kind, payload)
    if not ran then missing(err) end
end

-- ---------------------------------------------------------------- zone markers

local palette = { neutral = C.markers.neutral, contested = C.markers.contested }

local function hex(color)
    return ("#%02X%02X%02X"):format(color.r or 0, color.g or 0, color.b or 0)
end

-- op77_map3d exports: synchronous, raise when the map is not running.
local function map(method, ...)
    return pcall(function(...)
        local resource = exports[C.map.resource]
        return resource[method](resource, ...)
    end, ...)
end

local function removeZones()
    for _, z in pairs(zones) do
        for _, handle in ipairs(z.handles) do pcall(Open77.markers.remove, handle) end
    end
    zones, retryAt = {}, {}
    for _, b in pairs(blips) do map("removeBlip", b.id) end
    blips = {}
end

local function createMarkers(def, color)
    local handles = {}
    local distance = C.markers.maxDistance or 220
    local ring, why = Open77.markers.create({ position = { x = def.x, y = def.y, z = def.z + 0.05 }, shape = "cylinder",
        radius = def.radius, height = C.markers.ringHeight or 1.2, color = color, maxDistance = distance })
    if ring == nil then return nil, why end
    handles[1] = ring
    local beacon, reason = Open77.markers.create({ position = { x = def.x, y = def.y, z = def.z + (C.markers.beaconLift or 4.0) },
        shape = "diamond", radius = 0.7, height = C.markers.beaconHeight or 2.0, color = color, maxDistance = distance })
    if beacon then handles[2] = beacon else log("warn", "zone beacon unavailable: " .. tostring(reason)) end
    return handles
end

local function syncBlip(def, zone, color, key)
    local options = { position = { x = def.x, y = def.y, z = def.z }, icon = "flag", color = hex(color),
        label = ("Turf %s · %s"):format(def.id, def.label), description = "Turf War zone",
        category = C.map.category, edge = true, pulse = zone.contested == true }
    local b = blips[def.id]
    if b and b.key == key then return end
    if b then
        local ran, updated = map("updateBlip", b.id, options)
        if ran and updated == true then b.key = key return end
        map("removeBlip", b.id)
        blips[def.id] = nil
    end
    options.id = "turf_" .. tostring(def.id)
    local ran, id = map("addBlip", options)
    if ran and id ~= nil then blips[def.id] = { id = id, key = key } end
end

-- Markers follow the zones' holders; colours change only when a holder does (never
-- animated per frame: a colour rebuilds the native entity).
local function syncZones()
    local site, shared = state.site, state.shared
    if site == nil or shared == nil then return end
    local defs = {}
    for _, def in ipairs(site.zones or {}) do defs[def.id] = def end
    local t = now()
    for _, zone in ipairs(shared.zones or {}) do
        local def = defs[zone.id]
        if def then
            local color, key = H.zoneColor(zone, shared, palette)
            local z = zones[zone.id]
            if z == nil then
                if t >= (retryAt[zone.id] or 0) then
                    local handles, why = createMarkers(def, color)
                    if handles then
                        zones[zone.id], retryAt[zone.id] = { handles = handles, key = key }, nil
                    else
                        retryAt[zone.id] = t + 2.0
                        log("warn", "zone marker unavailable: " .. tostring(why))
                    end
                end
            elseif z.key ~= key then
                for _, handle in ipairs(z.handles) do pcall(Open77.markers.update, handle, { color = color }) end
                z.key = key
            end
            syncBlip(def, zone, color, key .. (zone.contested and ":c" or ""))
        end
    end
end

-- ---------------------------------------------------------------- render

local function render(force)
    if state.shared then
        show(H.war(state.shared, state.personal, state.board, { kits = C.kits, kitKey = kitKey }), force)
        syncZones()
    elseif state.queued and state.queued.lobbyMs then
        show(H.lobby(state.queued, { kits = C.kits, kitKey = kitKey }), force)
    elseif hud.shown then
        clearHud()
    end
end

RegisterNetEvent("op77_turf:state", function(shared, personal)
    if type(shared) == "table" then
        state.shared, state.personal, state.queued = shared, type(personal) == "table" and personal or {}, nil
    elseif type(personal) == "table" and personal.queued then
        if state.shared then return end -- in a war: the queue view never replaces it
        state.queued = personal
    end
    render(false)
end)

RegisterNetEvent("op77_turf:board", function(rows)
    if type(rows) ~= "table" then return end
    state.board = rows
    if state.shared then render(false) end
end)

RegisterNetEvent("op77_turf:site", function(payload)
    if type(payload) ~= "table" then return end
    if state.site == nil or state.site.warId ~= payload.warId then removeZones() end
    state.site = payload
    state.queued = nil
    syncZones()
end)

RegisterNetEvent("op77_turf:push", function(kind, payload)
    if kind == "feed" or kind == "banner" or kind == "result" then push(kind, payload) end
end)

RegisterNetEvent("op77_turf:clear", function()
    clearHud()
    -- The server's fallback flag lives with each war entry: try (and report) again next time.
    hud.missing = false
    removeZones()
    state = { shared = nil, personal = nil, board = nil, site = nil, queued = nil }
end)

-- ---------------------------------------------------------------- keys

local function refreshKey()
    local ok, key = pcall(Open77.input.keyFor, C.keys.kit.id)
    kitKey = ok and type(key) == "string" and key ~= "" and key or C.keys.kit.key
    if state.shared or state.queued then render(true) end
end

do
    local binding = C.keys.kit
    local ok, effective = RegisterKeyMapping(binding.id, binding.name, binding.key, function()
        if state.shared or state.queued then TriggerServerEvent("op77_turf:kit", "next") end
    end)
    if not ok then log("error", ("key mapping %s refused: %s"):format(binding.id, tostring(effective))) end
    refreshKey()
end

AddEventHandler("open77:keybinds:changed", refreshKey)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    clearHud()
    for _, b in pairs(blips) do map("removeBlip", b.id) end -- markers are cleaned up by the runtime
end)

-- The server re-sends what this client should show (a reload, a late start).
CreateThread(function()
    Wait(1500)
    TriggerServerEvent("op77_turf:ready")
end)
