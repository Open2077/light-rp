-- Proximity interactions on the client. For every point the server sends:
--   * a persistent native 3D marker (Open77.markers) when configured, otherwise
--     a small ground ring (Open77.anchors, render = "ring") unless ring = false;
--   * an optional custom SVG map blip (open77_icons), with a native fallback;
--   * one shared page anchor ("interact") that the HUD page turns into a keycap
--     and a few words, moved onto the nearest point in range.
-- E sends that point's id to the server, which re-checks the distance itself.
local E = LightRpEvents
local Config = LightRpConfig
local Interact = { points = {}, locals = {}, near = nil, promptAnchor = nil }
LightRpInteract = Interact

local RING_ACCENT = "#FFCC00B3"
local BLIP_ACCENT, BLIP_SIZE = "#FFCC00", 40
local customBlips = {} -- native handles are owned by the icon service, not us
local sendPrompt

local function log(format, ...) LightRpUi.log(format, ...) end

local function anchorsAvailable()
    return type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
end

local function blipsAvailable()
    return type(Open77.blips) == "table" and type(Open77.blips.create) == "function"
end

local function iconCall(method, ...)
    return pcall(function(...)
        return exports.open77_icons[method](exports.open77_icons, ...)
    end, ...)
end

local function removeBlip(id)
    if customBlips[id] then
        local called, ok, reason = iconCall("remove", id)
        if not called or not ok then log("custom blip cleanup: %s", tostring(called and reason or ok)) end
        customBlips[id] = nil
    elseif blipsAvailable() then pcall(Open77.blips.remove, id) end
end

function Interact.trackBlip(id)
    if customBlips[id] then
        local called, ok, reason = iconCall("track", id)
        if not called then return false, tostring(ok) end
        return ok, reason
    end
    if not blipsAvailable() then return false, "blips_unavailable" end
    return Open77.blips.track(id)
end

-- The 3D city map (op77_map3d), when it runs, shows the same places as the game's map.
-- Its blips are keyed by point id, so sending them again (map restarted) is harmless.
local MAP_ICONS = {
    house = "home", ["shopping-basket"] = "store", shirt = "shirt", fuel = "fuel", ["key-round"] = "car",
    warehouse = "garage", ["car-front"] = "car", package = "briefcase", ["arrow-up-down"] = "briefcase",
}
local MAP_CATEGORIES = { home = "housing", store = "service", shirt = "service", fuel = "service", car = "vehicle", garage = "vehicle" }
local mapPoints = {} -- point id -> definition sent to op77_map3d

local function mapCall(method, ...)
    if type(GetResourceState) ~= "function" or exports == nil or GetResourceState("op77_map3d") ~= "running" then return false end
    return pcall(function(...) return exports.op77_map3d[method](exports.op77_map3d, ...) end, ...)
end

local function mapAdd(point)
    local b = point.blip
    local kind = tostring(point.id):match("^([%w_]+)%.")
    -- `blip.map` names a drawn icon of client/core/map_icons.lua (the gun stores' weapons);
    -- `mapCategory` / `mapColor` place and tint it on the 3D map only
    local drawn = type(b.map) == "string" and LightRpMapIcons and LightRpMapIcons[b.map] or nil
    local icon = drawn or kind == "mission" and "mission" or MAP_ICONS[b.icon] or (kind == "job" and "briefcase") or "pin"
    local tint = type(b.mapColor) == "string" and b.mapColor or b.color
    local def = {
        id = tostring(point.id), position = b.position or point.position, icon = icon,
        color = type(tint) == "string" and tint:match("^#%x%x%x%x%x%x") or nil,
        label = b.title or point.label or "Point of interest", description = b.description or point.prompt,
        category = type(b.mapCategory) == "string" and b.mapCategory
            or kind == "mission" and "mission" or kind == "job" and "job" or MAP_CATEGORIES[icon] or "default",
        pulse = kind == "job",
    }
    mapPoints[def.id] = def
    mapCall("addBlip", def)
end

local function mapRemove(id)
    id = tostring(id)
    if not mapPoints[id] then return end
    mapPoints[id] = nil
    if type(GetCurrentResourceName) == "function" then mapCall("removeBlip", GetCurrentResourceName() .. ":" .. id) end
end

AddEventHandler("op77_map3d:ready", function()
    for _, def in pairs(mapPoints) do mapCall("addBlip", def) end
end)

local function markersAvailable()
    return type(Open77.markers) == "table" and type(Open77.markers.create) == "function"
end

local function removePoint(point)
    if point.marker and markersAvailable() then pcall(Open77.markers.remove, point.marker) end
    if point.ring and anchorsAvailable() then pcall(Open77.anchors.remove, point.ring) end
    if point.blip then removeBlip(point.blip) end
    mapRemove(point.id)
    if Interact.near == point then Interact.near = nil; sendPrompt(nil) end
end

local function clear()
    for _, point in ipairs(Interact.points) do removePoint(point) end
    Interact.points = {}
    if Interact.near then Interact.near = nil; sendPrompt(nil) end
end

-- What identifies an entry's content: the revision the server gives every registration
-- (server/core/interact.lua). Hashing each entry here instead overran the client's 2 ms
-- script budget and killed the build part way (2026-11-02: no shops on the map). An
-- entry without one is never kept.
local function revisionOf(entry)
    return type(entry) == "table" and entry.id ~= nil and entry.rev ~= nil and (tostring(entry.id) .. "#" .. tostring(entry.rev)) or nil
end

-- The shared prompt anchor follows the nearest point; the page draws the words.
function sendPrompt(point)
    if Interact.promptAnchor and anchorsAvailable() then
        if point then
            Open77.anchors.update(Interact.promptAnchor, {
                position = { x = point.position.x, y = point.position.y, z = point.position.z + (point.promptHeight or 1.1) }, visible = true,
            })
        else
            Open77.anchors.update(Interact.promptAnchor, { visible = false })
        end
    end
    LightRpUi.send(E.page.interact, point and { id = point.id, prompt = point.prompt or "Interact", key = point.key or "E" } or {})
end

local function ensurePromptAnchor()
    if Interact.promptAnchor or not anchorsAvailable() or LightRpUi.page == nil then return end
    local id, err = Open77.anchors.create({
        page = LightRpUi.page, position = { x = 0, y = 0, z = 0 }, tag = "interact", maxDistance = 12.0, visible = false,
    })
    if id then Interact.promptAnchor = id else log("prompt anchor refused: %s", tostring(err)) end
end

-- The custom-icon blips share a client visual budget; once it answers
-- blip_visual_budget_exceeded every further try is a wasted cross-resource call, and
-- with dozens of points those calls overran the script budget (2026-11-02). Straight
-- to the native sprite until the next list.
local visualFull = false
local function createBlip(point)
    if type(point.blip) == "table" then mapAdd(point) end
    if not blipsAvailable() or type(point.blip) ~= "table" then return nil end
    local definition = {
        position = point.blip.position or point.position,
        sprite = point.blip.sprite or "objective",
        icon = point.blip.icon or "map-pin", size = point.blip.size or BLIP_SIZE,
        color = point.blip.color or BLIP_ACCENT,
        title = point.blip.title or point.label or "Point of interest",
        description = point.blip.description or point.prompt or "",
        active = true, visibleThroughWalls = false,
        routable = point.blip.routable == true,
    }
    if exports ~= nil and not visualFull then
        local called, custom, reason = iconCall("create", definition)
        if called and custom then customBlips[custom] = true; return custom end
        if called and reason == "blip_visual_budget_exceeded" then visualFull = true end
        log("custom blip %s refused for %s: %s; using native fallback%s",
            tostring(definition.icon), tostring(point.id), tostring(called and reason or custom),
            visualFull and " (and for the points after it)" or "")
    end
    local sprites = {}
    if point.blip.sprite then sprites[#sprites + 1] = point.blip.sprite end
    -- An unsupported/missing icon should never turn a shop into a car rental.
    if point.blip.sprite ~= "objective" then sprites[#sprites + 1] = "objective" end
    for _, sprite in ipairs(sprites) do
        -- Older clients retain useful locations; never borrow a misleading car
        -- sprite. Do not send service-only fields to the native fallback.
        local id, err = Open77.blips.create({
            position = definition.position, sprite = sprite, title = definition.title,
            description = definition.description, active = true, visibleThroughWalls = false,
            routable = definition.routable,
            color = type(Open77.blips.setColor) == "function" and definition.color or nil,
        })
        if id then return id end
        log("blip sprite %s refused for %s: %s", tostring(sprite), tostring(point.id), tostring(err))
    end
    log("blip refused for %s", tostring(point.id))
    return nil
end

local function createMarker(point, marker)
    if not markersAvailable() then
        log("3D marker unavailable for %s: update the Open77 client (world.markers API required)", tostring(point.id))
        return nil
    end
    local id, err = Open77.markers.create({
        position = { x = point.position.x, y = point.position.y, z = point.position.z + (tonumber(marker.groundOffset) or 0.05) },
        shape = marker.shape or "cylinder", radius = tonumber(marker.radius) or 0.9, height = tonumber(marker.height) or 0.65,
        color = marker.color, style = marker.style or "objective", scale = marker.scale, rotation = marker.rotation,
        minDistance = tonumber(marker.minDistance) or 0, maxDistance = tonumber(marker.maxDistance) or 30.0,
        visible = marker.visible ~= false,
    })
    if not id then log("3D marker refused for %s: %s", tostring(point.id), tostring(err)) end
    return id
end

-- Private client objectives share the same E key and proximity prompt as public
-- desks, but survive a refresh of the server's public interaction list.
function Interact.setLocal(id, entry, callback)
    local old = Interact.locals[id]
    if old then
        if Interact.near == old then Interact.near = nil; sendPrompt(nil) end
        if old.marker then pcall(Open77.markers.remove, old.marker) end
        if old.blip then removeBlip(old.blip) end
        mapRemove(id)
        Interact.locals[id] = nil
    end
    if not entry then return end
    ensurePromptAnchor()
    local point = { id = id, position = entry.position, radius = entry.radius or 2.6,
        prompt = entry.prompt, key = "E", promptHeight = 0.7, blip = entry.blip, callback = callback,
        passive = entry.passive == true }
    if entry.marker then point.marker, point.markerVisible = createMarker(point, entry.marker), entry.marker.visible ~= false end
    point.blip = createBlip(point)
    Interact.locals[id] = point
    return point.blip
end

-- Another resource's E points (op77_scenes: the ripperdoc chairs), on the same keycap
-- prompt as ours: a press fires the client event `event` with `data` (functions cannot
-- cross VMs). `entry = nil` removes the point. Ids live under "ext:", never ours.
exports("InteractSetLocal", function(id, entry, event, data)
    if type(id) ~= "string" or id == "" or #id > 160 then return false, "invalid_id" end
    id = "ext:" .. id
    if entry == nil then Interact.setLocal(id, nil); return true end
    if type(entry) ~= "table" or type(entry.position) ~= "table" or type(event) ~= "string" or event == "" then
        return false, "invalid_entry"
    end
    local p = entry.position
    if type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then return false, "invalid_position" end
    Interact.setLocal(id, {
        position = { x = p.x, y = p.y, z = p.z },
        radius = math.max(0.5, math.min(tonumber(entry.radius) or 2.6, 6.0)),
        prompt = type(entry.prompt) == "string" and entry.prompt:sub(1, 48) or "Interact",
    }, function() TriggerEvent(event, data) end)
    return true
end)

-- One point: its marker (or ground ring), its blips and its prompt entry.
local function addPoint(entry)
        if type(entry) == "table" and type(entry.position) == "table" then
            local ring = type(entry.ring) == "table" and entry.ring or {}
            local point = {
                id = entry.id, position = entry.position, radius = tonumber(entry.radius) or 2.5,
                label = entry.label, prompt = entry.prompt, key = entry.key or "E",
                promptHeight = tonumber(entry.promptHeight) or 1.1, blip = entry.blip,
            }
            if type(entry.marker) == "table" then
                point.marker, point.markerVisible = createMarker(point, entry.marker), entry.marker.visible ~= false
            elseif entry.ring ~= false and anchorsAvailable() then
                local id, err = Open77.anchors.create({
                    position = point.position, maxDistance = tonumber(ring.maxDistance) or 8.0, render = "ring",
                    presentation = { accent = ring.accent or RING_ACCENT, radius = tonumber(ring.radius) or 0.9, thickness = tonumber(ring.thickness) or 2.0, groundOffset = 0.05 },
                })
                if id then point.ring = id else log("ring anchor refused for %s: %s", tostring(point.id), tostring(err)) end
            end
            point.blip = createBlip(point) -- nil when the point asks for none
            -- Kept across lists only when everything it asked for exists: a refused
            -- marker or blip (quota, older client) is tried again with the next list.
            local complete = (type(entry.marker) ~= "table" or point.marker ~= nil)
                and (type(entry.blip) ~= "table" or point.blip ~= nil)
                and (type(entry.marker) == "table" or entry.ring == false or not anchorsAvailable() or point.ring ~= nil)
            point.signature = complete and revisionOf(entry) or nil
            Interact.points[#Interact.points + 1] = point
        end
end

-- One script resume must stay short: the client kills a handler that overruns its
-- budget, and on 2026-11-02 the 30-odd points (marker + custom blip + 3D map blip each)
-- died part way, so every shop after the wardrobes was never built. The first points
-- go at once, the rest in slices with a yield between them; a newer list stops an
-- older build still running.
--
-- Only what changed is touched: a point whose entry is identical keeps its marker,
-- blips and 3D-map pin. The whole set used to be torn down and rebuilt for every list,
-- and the server re-sent one every 2-4 s while driving (the nearest housing entrances):
-- 86 full rebuilds of 44 points in 17 min on 2026-11-02, amid the NPC churn of a
-- session that ended in an engine crash.
--
-- Every engine call (removing a stale point, creating a new one) goes through the same
-- slices: 4 per resume, the first slice at once. Points waiting for removal live in
-- Interact.retiring, so a newer list arriving mid-way never loses their handles.
local SLICE = 4
local generation = 0
Interact.retiring = {}
local function build(list)
    generation = generation + 1
    local mine = generation
    ensurePromptAnchor()
    local wanted = {}
    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.id ~= nil and wanted[entry.id] == nil then wanted[entry.id] = entry end
    end
    local kept, keptIds, removed = {}, {}, 0
    for _, point in ipairs(Interact.points) do
        local entry = point.id ~= nil and wanted[point.id] or nil
        if entry ~= nil and not keptIds[point.id] and point.signature ~= nil and point.signature == revisionOf(entry) then
            kept[#kept + 1] = point
            keptIds[point.id] = true
        else
            Interact.retiring[#Interact.retiring + 1] = point
            if Interact.near == point then Interact.near = nil; sendPrompt(nil) end
            removed = removed + 1
        end
    end
    Interact.points = kept
    -- Removed custom blips free the visual budget: worth one more custom try.
    if removed > 0 or #kept == 0 then visualFull = false end
    local pending = {}
    for _, entry in ipairs(list) do
        if type(entry) ~= "table" or entry.id == nil or not keptIds[entry.id] then
            pending[#pending + 1] = entry
            if type(entry) == "table" and entry.id ~= nil then keptIds[entry.id] = true end
        end
    end
    local added, keptCount = #pending, #kept
    local function report()
        if added > 0 or removed > 0 then
            log("%d interaction point(s) (%d kept, %d added, %d removed)", #Interact.points, keptCount, added, removed)
        end
    end
    local index = 0
    local function slice()
        local budget = SLICE
        while budget > 0 and #Interact.retiring > 0 do
            removePoint(table.remove(Interact.retiring))
            budget = budget - 1
        end
        while budget > 0 and index < #pending do
            index = index + 1
            addPoint(pending[index])
            budget = budget - 1
        end
    end
    local function done() return #Interact.retiring == 0 and index >= #pending end
    slice()
    if done() then report(); return end
    CreateThread(function()
        while not done() do
            Wait(0)
            if mine ~= generation then return end
            slice()
        end
        report()
    end)
end
Interact.build = build

local received = false
RegisterNetEvent(E.net.interactions, function(list)
    if type(list) ~= "table" then return end
    received = true
    build(list)
end)

-- The client asks for the list itself once its character is in the world, and again
-- every 5 s until one arrives. A list the server pushed before this resource was
-- running is lost, and since the server does not re-send an unchanged list, the map
-- stayed without a single shop (2026-11-02, when the shell's gameplay-ready event
-- never came). A new world entry (respawn, character switch) asks again.
CreateThread(function()
    local attached, askedAt = false, -1000000
    while true do
        Wait(1000)
        local ok, state = pcall(Open77.character.state)
        local now = ok and type(state) == "table" and state.attached == true
        if now and not attached then received = false; askedAt = -1000000 end
        attached = now
        if attached and not received and GetGameTimer() - askedAt >= 5000 then
            askedAt = GetGameTimer()
            TriggerServerEvent(E.net.interactionsRequest)
        end
    end
end)

local function localPosition()
    if type(Open77.character) ~= "table" or type(Open77.character.state) ~= "function" then return nil end
    local ok, state = pcall(Open77.character.state)
    if not ok or type(state) ~= "table" or type(state.position) ~= "table" then return nil end
    return state.position
end

local function setNear(point)
    if Interact.hidden then point = nil end -- a full-screen page (the fitting room) covers the world
    if Interact.near == point then return end
    Interact.near = point
    sendPrompt(point)
end

CreateThread(function()
    while true do
        Wait(100)
        if #Interact.points > 0 or next(Interact.locals) then
            local p = localPosition()
            if p == nil then
                setNear(nil)
            else
                local best, bestDistance
                for _, point in ipairs(Interact.points) do
                    local dx, dy, dz = p.x - point.position.x, p.y - point.position.y, p.z - point.position.z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local fueling = LightRpRefueling and LightRpRefueling.isActive()
                    local seated = point.id:match("^fuel%.") and Open77.vehicles.getPlayerSeat and Open77.vehicles.getPlayerSeat()
                    if not fueling and not seated and distance <= point.radius and (bestDistance == nil or distance < bestDistance) then best, bestDistance = point, distance end
                end
                for _, point in pairs(Interact.locals) do
                    local dx, dy, dz = p.x - point.position.x, p.y - point.position.y, p.z - point.position.z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local allowed = not (LightRpRefueling and LightRpRefueling.isActive()) or point.id=="fuel.current"
                    if allowed and not point.passive and distance <= point.radius and (bestDistance == nil or distance <= bestDistance + 0.5) then best, bestDistance = point, distance end
                end
                setNear(best)
            end
        end
    end
end)

-- Hide the prompt, markers and rings while a full-screen page is open: they
-- would float over it (the fitting room films the player standing in one).
function Interact.setHidden(hidden)
    hidden = hidden == true
    if (Interact.hidden == true) == hidden then return end
    Interact.hidden = hidden or nil
    if hidden then setNear(nil) end
    local function each(point)
        if point.marker and markersAvailable() and point.markerVisible ~= false then pcall(Open77.markers.update, point.marker, { visible = not hidden }) end
        if point.ring and anchorsAvailable() then pcall(Open77.anchors.update, point.ring, { visible = not hidden }) end
    end
    for _, point in ipairs(Interact.points) do each(point) end
    for _, point in pairs(Interact.locals) do each(point) end
end

function Interact.press()
    if Interact.hidden then return false end
    if LightRpActions and LightRpActions.isActive() then return false end
    local point = Interact.near
    if point == nil then return false end
    if point.callback then point.callback() else TriggerServerEvent(E.net.interact, point.id) end
    return true
end

function Interact.bind()
    local key = Config.keys.interact
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Interact.press() end)
    if ok then log("interact bound to %s", tostring(effective)) else log("interact key mapping failed: %s", tostring(effective)) end
end
