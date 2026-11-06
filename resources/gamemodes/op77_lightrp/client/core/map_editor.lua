-- Staff map editor, client half (/lightrp.maps, server/modules/game_maps.lua): the mission
-- editor's session on a game map. The same crosshair, keys, input modes and weapon block
-- (client/core/mission_editor.lua newSession); this file only says what a map looks like. The
-- page sends a map's `layers`, read from the game's schema, so a new game needs nothing here:
--   layers  { { key, kind = "point" | "list", label, color } }     area  { centre, radius }
-- A map is flat: map[key] is a point, or a list of points. build.tool is "point:<key>",
-- "list:<key>", "radius" or "move"; build.color is the tool's colour.
local Base = LightRpMissionEditor
local D = Base.draw
local layers, area = {}, nil

local Editor = Base.session({
    name = "map editor", title = "Map editor", net = "op77_lightrp:mapeditor", page = "lightrp:ui:mapeditor",
    claim = "mapeditor", drawKey = "lightrp:maps:draft", ghostKey = "lightrp:maps:ghost", draftKey = "map",
    busy = "Finish your current activity before editing maps.",
    closed = "Map editor closed because your character is unavailable.",
    onPreview = function(p)
        layers = type(p.layers) == "table" and p.layers or {}
        area = type(p.area) == "table" and p.area or nil
    end,
})
LightRpMapEditor = Editor

local WHITE = "#ffffffff"

-- Every placed point, each loop of the crosshair: a table only for the one that wins.
function Editor.hovered(m, p)
    if type(m) ~= "table" or not p then return nil end
    local best, bestD, bestLayer, bestIndex
    local function consider(layer, index, q)
        if D.point(q) then
            local d = D.dist(p, q)
            if d <= D.HOVER_RADIUS and (not bestD or d < bestD) then best, bestD, bestLayer, bestIndex = q, d, layer, index end
        end
    end
    for _, layer in ipairs(layers) do
        if layer.kind == "point" then consider(layer, nil, m[layer.key])
        else
            for i, q in ipairs(type(m[layer.key]) == "table" and m[layer.key] or {}) do consider(layer, i, q) end
        end
    end
    if not best then return nil end
    return { type = bestIndex and "list" or "point", key = bestLayer.key, index = bestIndex,
        label = bestIndex and (bestLayer.label .. " " .. bestIndex) or bestLayer.label,
        position = { x = best.x, y = best.y, z = best.z } }
end

local function radiusOf(m)
    if not area then return nil end
    local centre, radius = m[area.centre], tonumber(m[area.radius])
    if not D.point(centre) or not radius or radius <= 0 then return nil end
    return centre, radius
end

-- debugDraw.set refuses a whole batch past 512 lines, and a full mark costs 16: a pillar, a circle
-- and, with a facing, an arrow. Past the cap every shape goes in cheapest first, the focused point
-- then the nearest ones first at each step, and the page hears what was left out.
local MAX_LINES, RING_SEGMENTS, LEAN_SEGMENTS = 512, 64, 32
local PILLAR, ARROW, CIRCLE = 1, 3, 12
local CELL = 25 -- metres walked before the nearest points are worked out again
local tight = false

local function viewer()
    local state = Open77.character.state()
    return state and D.point(state.position) and state.position or nil
end

local function spotsOf(m, focus, yield)
    local spots = {}
    local function add(q, id, color, height)
        local hot = focus == id
        if D.point(q) then spots[#spots + 1] = { at = q, color = hot and WHITE or color, height = height, hot = hot } end
    end
    for _, layer in ipairs(layers) do
        if layer.kind == "point" then add(m[layer.key], "point:" .. layer.key, layer.color, 3)
        else
            for i, q in ipairs(type(m[layer.key]) == "table" and m[layer.key] or {}) do
                add(q, "list:" .. layer.key .. ":" .. i, layer.color, 2)
            end
        end
        yield()
    end
    return spots
end

local function costOf(spot) return PILLAR + CIRCLE + (spot.at.heading ~= nil and ARROW or 0) end

-- Sets spot.pillar, .arrow and .circle. Returns the ring's segments and rings, and the counts.
local function fit(spots, ring)
    local left, cost = MAX_LINES, ring and 2 * RING_SEGMENTS or 0
    for _, spot in ipairs(spots) do cost = cost + costOf(spot) end
    if cost <= left then
        for _, spot in ipairs(spots) do spot.pillar, spot.arrow, spot.circle = true, spot.at.heading ~= nil, true end
        return ring and RING_SEGMENTS, 2, #spots, #spots, false
    end
    local from = viewer()
    for _, spot in ipairs(spots) do spot.away = from and D.dist(from, spot.at) or 0 end
    table.sort(spots, function(a, b)
        if a.hot ~= b.hot then return a.hot end
        return a.away < b.away
    end)
    local shown, full = 0, 0
    for _, spot in ipairs(spots) do
        if left < PILLAR then break end
        spot.pillar, left, shown = true, left - PILLAR, shown + 1
    end
    local segments
    if ring and left >= LEAN_SEGMENTS then segments, left = LEAN_SEGMENTS, left - LEAN_SEGMENTS end
    for _, spot in ipairs(spots) do
        if spot.pillar and spot.at.heading ~= nil and left >= ARROW then spot.arrow, left = true, left - ARROW end
    end
    for _, spot in ipairs(spots) do
        if spot.pillar and left >= CIRCLE then spot.circle, left = true, left - CIRCLE end
        if spot.pillar and spot.circle and (spot.arrow or spot.at.heading == nil) then full = full + 1 end
    end
    return segments, 1, shown, full, true
end

function Editor.geometry(m, focus, _, yield)
    if type(m) ~= "table" then return nil end
    yield = yield or function() end
    local batch = { lines = {}, triangles = {}, ttl = 1.5, maxDistance = 1000 }
    local spots = spotsOf(m, focus, yield)
    local centre, radius = radiusOf(m)
    local segments, rings, shown, full, over = fit(spots, centre ~= nil)
    for i, spot in ipairs(spots) do
        if i % 6 == 0 then yield() end
        if spot.pillar then D.pillar(batch, spot.at, spot.height, spot.color) end
        if spot.circle then D.circle(batch, spot.at, 0.8, spot.at.z + 0.05, spot.color, 12) end
        if spot.arrow then D.arrow(batch, spot.at, spot.at.heading, 1.2, spot.color) end
    end
    yield()
    if centre and segments then
        local color = focus == "radius" and WHITE or "#ffcc00ed"
        D.circle(batch, centre, radius, centre.z + 0.2, color, segments)
        if rings == 2 then
            yield()
            D.circle(batch, centre, radius, centre.z + 4, color, segments)
        end
    end
    if over or tight then Editor.send({ kind = "drawing", total = #spots, shown = shown, full = full }) end
    tight = over
    return batch
end

function Editor.geometryKey()
    local at = tight and viewer()
    return at and (math.floor(at.x / CELL) .. ":" .. math.floor(at.y / CELL)) or ""
end

-- What the current tool would create, where the crosshair points.
function Editor.ghost(build, p, m)
    if not build or not p then return nil end
    local color = type(build.color) == "string" and build.color or WHITE
    local batch = { lines = {}, triangles = {}, ttl = 0.2, maxDistance = 400 }
    if build.tool == "radius" then
        local centre = m and radiusOf(m)
        if not centre and area and m then centre = m[area.centre] end
        if D.point(centre) then
            local r = math.sqrt((p.x - centre.x) ^ 2 + (p.y - centre.y) ^ 2)
            D.circle(batch, centre, r, p.z + 0.2, color, 48)
            D.line(batch, { x = centre.x, y = centre.y, z = p.z + 0.2 }, { x = p.x, y = p.y, z = p.z + 0.2 }, color)
        end
    elseif build.tool == "move" then
        D.circle(batch, p, 0.5, p.z + 0.05, color, 12)
        if build.carrying then D.pillar(batch, p, 3, color) end
    else
        local state = Open77.character.state()
        local heading = tonumber(build.heading) or (state and state.position and D.facing(p, state.position)) or 0
        D.pillar(batch, p, 3, color)
        D.circle(batch, p, 0.8, p.z + 0.05, color, 12)
        D.arrow(batch, p, heading, 1.4, color)
    end
    return batch
end
