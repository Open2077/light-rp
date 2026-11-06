-- The first day's way to the objective. client/core/tutorial.lua decides when it shows;
-- this file owns everything it places, and nothing else does (marker rules: docs/parkour.md).
--
--   * The beacon: a gold ring on the ground round the objective and a light column rising
--     from above head height, to find it from across the hall. Two native markers, the
--     parkour's shapes (ring, cylinder), created once per objective and never updated.
--   * The pointer: one page anchor over the objective (the page follows it every frame: a
--     waypoint on screen) and, sent when it changes, the bearing from the camera with the
--     distance (the page's arrow at the screen edge when the objective is out of view).
--   * The route, during the flight to a new stop: chevrons drawn on the ground (debugDraw),
--     lit as the camera passes. A drawing lives ROUTE_TTL seconds unless it is drawn again,
--     so even a missed exit cannot leave it behind.
--
-- Why it is built this way (2026-11-06, the owner: "the balls sometimes stay, appear
-- weirdly"): the previous lead moved an arrow and five spheres with markers.update every
-- frame. An update while a marker is still loading restarts its spawn (client Markers.cpp,
-- stage ~= Ready), so they blinked; the spheres' radius dipped under the API's 0.1 m
-- minimum, so creations were refused half of the time and left holes in the id list that
-- the clearing ipairs never got past: the spheres after a hole stayed in the world. The
-- flight's 40 spheres could also fill the 64 markers LightRP shares.
--
-- Rules: a marker is never updated; a hidden guide comes back only after SHOW_AFTER (no
-- churn when a state flickers); every refusal is logged; Guide.clear() is idempotent and
-- removes everything, whatever the state.
local Guide = {}
LightRpTutorialGuide = Guide

local GOLD = { r = 255, g = 204, b = 0 }
local BEACON = {
    ringMin = 0.9, ringMax = 2.6, ringAlpha = 225, ringView = 160,
    columnLift = 2.4, columnHeight = 70, columnRadius = 0.2, columnAlpha = 120, columnView = 500,
}
-- 64 markers per resource, shared with the interaction points and the parkour: the guide
-- places at most two and leaves this many to the others.
local MARKER_CAP, MARKER_RESERVE = 64, 6
local ANCHOR_TAG, ANCHOR_LIFT, ANCHOR_VIEW = "tutorial.guide", 2.2, 1000
local ROUTE_TAG, ROUTE_TTL, ROUTE_EVERY = "lightrp:tutorial:route", 1.0, 0.12
local ROUTE_MAX, ROUTE_SPACING = 40, 3.0
local SHOW_AFTER = 0.5 -- seconds the guide must be wanted before it is placed (again)
local HEALTH_EVERY, RETRY_AFTER, RETRIES = 2.0, 4.0, 3
local HEARTBEAT = 1.0 -- the pointer is sent at least this often: a page that reloads catches up
local TELEPORT = 120 -- metres between two syncs: the health of what is placed is checked at once
Guide.ANCHOR_TAG, Guide.ROUTE_TAG, Guide.MAX_MARKERS = ANCHOR_TAG, ROUTE_TAG, 2

local function now() return Open77.time.monotonic() end
local function log(...) if LightRpUi and LightRpUi.log then LightRpUi.log(...) end end
local warnedAt = {}
local function warn(key, ...)
    local t = now()
    if warnedAt[key] and t - warnedAt[key] < 30 then return end
    warnedAt[key] = t
    log(...)
end
local function markersOk() return type(Open77.markers) == "table" and type(Open77.markers.create) == "function" end
local function anchorsOk() return type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function" end
local function drawOk() return type(Open77.debugDraw) == "table" and type(Open77.debugDraw.set) == "function" end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Everything in the world, in one place.
local placed = { key = nil, markers = {}, anchor = nil, expected = 0 }
local want = { key = nil, since = 0 }
local health = { key = nil, at = 0, retries = 0, retryAt = nil, gaveUp = false }
local route = nil
local sent, sentAt, lastAt = nil, -math.huge, nil

local function removeMarkers()
    for i = #placed.markers, 1, -1 do
        if markersOk() then pcall(Open77.markers.remove, placed.markers[i]) end
        placed.markers[i] = nil
    end
end
local function removeAnchor()
    if placed.anchor and anchorsOk() then pcall(Open77.anchors.remove, placed.anchor) end
    placed.anchor = nil
end
local function clearWorld()
    removeMarkers(); removeAnchor()
    placed.key, placed.expected = nil, 0
end
Guide.clearWorld = clearWorld

local function freeSlots()
    if type(Open77.markers.list) ~= "function" then return MARKER_CAP - MARKER_RESERVE end
    local ok, list = pcall(Open77.markers.list)
    if not ok or type(list) ~= "table" then return MARKER_CAP - MARKER_RESERVE end
    return MARKER_CAP - MARKER_RESERVE - #list
end
local function placeMarker(def, what)
    local ok, id, why = pcall(Open77.markers.create, def)
    if ok and id then placed.markers[#placed.markers + 1] = id; return true end
    warn("marker:" .. what, "tutorial guide: %s marker refused: %s", what, tostring(ok and why or id))
    return false
end

-- The beacon and the anchor of one objective. The column goes first: it is what is seen from afar.
local function placeWorld(key, o)
    placed.key = key
    local p = o.position
    if markersOk() then
        local free = freeSlots()
        if free < 1 then
            warn("budget", "tutorial guide: no marker left for the beacon (%d free of %d)", free, MARKER_CAP)
        else
            placed.expected = free >= 2 and 2 or 1
            placeMarker({ shape = "cylinder", position = { x = p.x, y = p.y, z = p.z + BEACON.columnLift },
                radius = BEACON.columnRadius, height = BEACON.columnHeight,
                color = { r = GOLD.r, g = GOLD.g, b = GOLD.b, a = BEACON.columnAlpha }, maxDistance = BEACON.columnView }, "column")
            if free >= 2 then
                placeMarker({ shape = "ring", position = { x = p.x, y = p.y, z = p.z + 0.05 },
                    radius = clamp((tonumber(o.radius) or 1.5) * 0.6, BEACON.ringMin, BEACON.ringMax), height = 1,
                    color = { r = GOLD.r, g = GOLD.g, b = GOLD.b, a = BEACON.ringAlpha }, maxDistance = BEACON.ringView }, "ring")
            end
        end
    end
    if anchorsOk() and LightRpUi and LightRpUi.page ~= nil then
        local ok, id, why = pcall(Open77.anchors.create, { page = LightRpUi.page, position = { x = p.x, y = p.y, z = p.z + ANCHOR_LIFT },
            tag = ANCHOR_TAG, maxDistance = ANCHOR_VIEW, visible = true })
        if ok and id then placed.anchor = id
        else warn("anchor", "tutorial guide: anchor refused: %s", tostring(ok and why or id)) end
    end
    health.at = now()
end

-- Is everything placed still there? A marker spawned during a loading or a teleport can
-- fail (marker_streaming_timeout); a page anchor goes with a destroyed page.
local function listed(list, id)
    for _, entry in ipairs(list) do
        if type(entry) == "table" and tostring(entry.id) == tostring(id) then return entry end
    end
end
local function healthy()
    -- refused at creation (the world not ready yet): tried again like a failure
    if #placed.markers < placed.expected then return false, "refused at creation" end
    if #placed.markers > 0 and type(Open77.markers.list) == "function" then
        local ok, list = pcall(Open77.markers.list)
        if ok and type(list) == "table" then
            for _, id in ipairs(placed.markers) do
                local entry = listed(list, id)
                if not entry then return false, "marker " .. tostring(id) .. " gone" end
                if entry.failed then return false, "marker " .. tostring(id) .. " failed: " .. tostring(entry.error) end
            end
        end
    end
    if placed.anchor and type(Open77.anchors.list) == "function" then
        local ok, list = pcall(Open77.anchors.list)
        if ok and type(list) == "table" and not listed(list, placed.anchor) then return false, "anchor gone" end
    end
    return true
end

-- game yaw (degrees, counter-clockwise from +Y) of the way from a to b (as client/core/parkour.lua)
local function yawTo(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    if math.abs(dx) + math.abs(dy) < 1e-3 then return 0 end
    return math.deg(math.atan(-dx, dy))
end
local function cameraYaw()
    if type(Open77.camera) ~= "table" or type(Open77.camera.view) ~= "function" then return nil end
    local ok, v = pcall(Open77.camera.view)
    local f = ok and type(v) == "table" and v.forward
    if not f or math.abs(f.x or 0) + math.abs(f.y or 0) < 1e-3 then return nil end
    return math.deg(math.atan(-f.x, f.y))
end

-- The page's pointer: { label, distance, angle (positive: to the left), rise } or false.
local function publish(value, force)
    local t = now()
    local s = sent
    if not force and value == false and s == false then return end
    if not force and value and s and s.label == value.label and math.abs(s.angle - value.angle) < 3
        and math.abs(s.distance - value.distance) < 1 and s.rise == value.rise and t - sentAt < HEARTBEAT then return end
    sent, sentAt = value, t
    if LightRpUi and LightRpUi.send then
        LightRpUi.send(LightRpEvents.page.tutorialGuide, value and {
            label = value.label, distance = math.floor(value.distance + 0.5), angle = math.floor(value.angle + 0.5), rise = value.rise,
        } or { hide = true })
    end
end
local function pointer(o, at, yaw, label)
    local p = o.position
    local rel = ((yawTo(at, p) - (cameraYaw() or tonumber(yaw) or 0) + 540) % 360) - 180
    local rise = p.z - at.z
    return { label = tostring(label or o.label or "Objective"), distance = math.sqrt((p.x - at.x) ^ 2 + (p.y - at.y) ^ 2),
        angle = rel, rise = math.abs(rise) >= 3 and math.floor(rise + 0.5) or 0 }
end

-- ctx = { key, objective, world = beacon allowed, hud = pointer allowed, position, yaw, label }
-- or nil. Called about ten times a second by client/core/tutorial.lua.
function Guide.sync(ctx)
    local t = now()
    local o = type(ctx) == "table" and type(ctx.objective) == "table" and type(ctx.objective.position) == "table" and ctx.objective or nil
    local key = o and ctx.world and ctx.key or nil
    if key ~= want.key then want.key, want.since = key, t end
    -- hidden, or another objective: gone at once
    if placed.key and placed.key ~= key then clearWorld() end
    if key and health.key ~= key then health.key, health.retries, health.retryAt, health.gaveUp = key, 0, nil, false end
    local at = o and ctx.position
    if at and lastAt and (at.x - lastAt.x) ^ 2 + (at.y - lastAt.y) ^ 2 > TELEPORT * TELEPORT then health.at = -math.huge end
    lastAt = at
    if key and not placed.key and not health.gaveUp and t - want.since >= SHOW_AFTER
        and (not health.retryAt or t >= health.retryAt) then
        placeWorld(key, o)
    elseif key and placed.key == key and t - health.at >= HEALTH_EVERY then
        health.at = t
        local ok, why = healthy()
        if not ok then
            clearWorld()
            health.retries = health.retries + 1
            if health.retries > RETRIES then
                health.gaveUp = true
                log("tutorial guide: beacon given up for %s after %d tries (%s)", tostring(key), RETRIES, tostring(why))
            else
                health.retryAt = t + RETRY_AFTER
                log("tutorial guide: placing the beacon again (%s)", tostring(why))
            end
        end
    end
    publish(o and ctx.hud and at and pointer(o, at, ctx.yaw, ctx.label) or false)
end

-- The page reloaded: send the pointer again on the next sync.
function Guide.republish() sent, sentAt = nil, -math.huge end

-- ---------------------------------------------------------------------------
-- The route, shown during the flight to a new stop

local function ground(c, top)
    if c.settled then return end
    c.settled = true
    local world = Open77.world
    if type(world) ~= "table" or type(world.groundZ) ~= "function" then return end
    local ok, z = pcall(world.groundZ, c.x, c.y, top)
    if ok and type(z) == "number" and z >= c.low and z <= top then c.z = z + 0.1 end
end

-- from: the player's feet; to: the objective. Nothing drawn yet: routeDraw lights it.
function Guide.routeStart(from, to, options)
    Guide.routeStop()
    if not drawOk() or type(from) ~= "table" or type(to) ~= "table" then return false end
    local dx, dy = to.x - from.x, to.y - from.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 4 then return false end
    local spacing = math.max(1.5, tonumber(options and options.spacing) or ROUTE_SPACING)
    local count = math.min(tonumber(options and options.max) or ROUTE_MAX, ROUTE_MAX, math.floor((d - 2) / spacing))
    local chevrons = {}
    for i = 1, count do
        local at = i * spacing / d
        local z = from.z + (to.z - from.z) * at
        chevrons[i] = { at = at, x = from.x + dx * at, y = from.y + dy * at, z = z + 0.1, low = math.min(from.z, to.z) - 3 }
    end
    route = { ux = dx / d, uy = dy / d, to = to, top = math.max(from.z, to.z) + 2.5, chevrons = chevrons,
        lit = -1, arrived = false, drawnAt = -math.huge, drawn = false }
    return true
end

local HEAD, BODY, SPINE = "#FFF1B0FF", "#FFCC00E0", "#FFCC0055"
local function chevron(tris, c, ux, uy, color)
    local sx, sy = -uy, ux
    local half, depth, arm = 0.6, 0.55, 0.26
    local tip = { x = c.x + ux * depth * 0.5, y = c.y + uy * depth * 0.5, z = c.z }
    local tipIn = { x = tip.x - ux * arm, y = tip.y - uy * arm, z = c.z }
    for _, side in ipairs({ 1, -1 }) do
        local back = { x = c.x - ux * depth * 0.5 + sx * half * side, y = c.y - uy * depth * 0.5 + sy * half * side, z = c.z }
        local backIn = { x = back.x - ux * arm, y = back.y - uy * arm, z = c.z }
        tris[#tris + 1] = { a = tip, b = back, c = backIn, color = color }
        tris[#tris + 1] = { a = tip, b = backIn, c = tipIn, color = color }
    end
end

-- lit: how much of the route the camera has passed, 0..1.
function Guide.routeDraw(lit)
    local r = route
    if not r or not drawOk() then return end
    local t = now()
    local n = 0
    for i, c in ipairs(r.chevrons) do if lit >= c.at then n = i else break end end
    local arrived = lit >= 0.98
    local changed = n ~= r.lit or arrived ~= r.arrived
    if changed and t - r.drawnAt < ROUTE_EVERY then return end
    if not changed and t - r.drawnAt < ROUTE_TTL * 0.5 then return end
    r.lit, r.arrived, r.drawnAt = n, arrived, t
    if n == 0 and not arrived then return end
    local tris, lines = {}, {}
    for i = 1, n do
        local c = r.chevrons[i]
        ground(c, r.top)
        chevron(tris, c, r.ux, r.uy, i > n - 2 and not arrived and HEAD or BODY)
    end
    if n >= 2 then lines[#lines + 1] = { a = r.chevrons[1], b = r.chevrons[n], color = SPINE } end
    if arrived then
        local o = r.to
        local segments, radius = 24, 1.6
        for i = 0, segments - 1 do
            local a0, a1 = i / segments * math.pi * 2, (i + 1) / segments * math.pi * 2
            lines[#lines + 1] = { a = { x = o.x + math.cos(a0) * radius, y = o.y + math.sin(a0) * radius, z = o.z + 0.1 },
                b = { x = o.x + math.cos(a1) * radius, y = o.y + math.sin(a1) * radius, z = o.z + 0.1 }, color = BODY }
        end
    end
    local ok, result, why = pcall(Open77.debugDraw.set, ROUTE_TAG, { triangles = tris, lines = lines, ttl = ROUTE_TTL, maxDistance = 600, thickness = 3 })
    if ok and result then r.drawn = true
    else warn("route", "tutorial guide: route drawing refused: %s", tostring(ok and why or result)) end
end

function Guide.routeStop()
    route = nil
    if type(Open77.debugDraw) == "table" and type(Open77.debugDraw.clear) == "function" then pcall(Open77.debugDraw.clear, ROUTE_TAG) end
end

-- Everything off: the world, the route, the page's pointer. Safe to call at any time, any number of times.
function Guide.clear()
    clearWorld()
    Guide.routeStop()
    want.key, want.since = nil, 0
    health.key, health.retries, health.retryAt, health.gaveUp = nil, 0, nil, false
    lastAt = nil
    publish(false, sent ~= false)
end

-- What is placed right now (the tests read it).
function Guide.placed()
    local ids = {}
    for i, id in ipairs(placed.markers) do ids[i] = id end
    return { key = placed.key, markers = ids, anchor = placed.anchor, route = route ~= nil }
end

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    Guide.clear()
end)
