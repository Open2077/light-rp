-- Areas: polygons drawn on the 3D map and the minimap (a danger zone, a turf, a no-go
-- zone): a translucent fill (solid or with diagonal danger hatching), a border and a
-- label, draped over the ground, the roads and the buildings (ui/src/areas.ts).
-- Checked the same way on both sides.
--   { id = "dogtown", points = { { x, y }, ... } (world metres, 3 to MAX_POINTS),
--     fill = "#FF2E3C", fillOpacity = 0.22, stroke = "#FF2E3C", strokeWidth = 2 (px),
--     pattern = "hatch" | "solid", label = "DOGTOWN", labelPosition = { x, y[, z] },
--     map = true, minimap = true, pulse = false }
-- A point is { x = .., y = .. } or { x, y }. The fill defaults to the theme's danger red,
-- the stroke to the fill.
Map3DArea = {}
local A = Map3DArea

-- An export argument holds at most 1024 values (every key and value counts: a point is 6),
-- so 160 points is what a definition can carry with its other fields.
A.MAX_POINTS = 160
-- The map draws this many at a time (ui/src/areas.ts MAX_AREAS); a resource keeps no more.
A.MAX_PER_OWNER = 16
A.DEFAULT_COLOR = "#FF2E3C"
-- World coordinates beyond this are not Night City.
local LIMIT = 100000

local function finite(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge or math.abs(v) > LIMIT then return nil end
    return v
end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

-- "#rgb" or "#rrggbb" -> "#RRGGBB"; nil for anything else.
local function color(v)
    if type(v) ~= "string" then return nil end
    if v:match("^#%x%x%x%x%x%x$") then return v:upper() end
    local r, g, b = v:match("^#(%x)(%x)(%x)$")
    if r then return ("#" .. r .. r .. g .. g .. b .. b):upper() end
    return nil
end

local function point(p)
    if type(p) ~= "table" then return nil end
    local x, y = finite(p.x or p[1]), finite(p.y or p[2])
    if not x or not y then return nil end
    return { x = round1(x), y = round1(y) }
end

-- A clean copy of def, or nil and the reason.
function A.normalize(def)
    if type(def) ~= "table" then return nil, "definition must be a table" end
    local raw = def.points
    if type(raw) ~= "table" then return nil, "points { {x, y}, ... } required" end
    local n = #raw
    if n < 3 then return nil, "an area needs at least 3 points" end
    if n > A.MAX_POINTS then return nil, "an area has at most " .. A.MAX_POINTS .. " points" end
    local points, twice = {}, 0
    for i = 1, n do
        local p = point(raw[i])
        if not p then return nil, "point " .. i .. " is not a finite {x, y}" end
        points[i] = p
    end
    for i = 1, n do
        local a, b = points[i], points[i % n + 1]
        twice = twice + a.x * b.y - b.x * a.y
    end
    if math.abs(twice) < 2 then return nil, "the points enclose no area" end
    local fill = A.DEFAULT_COLOR
    if def.fill ~= nil then
        fill = color(def.fill)
        if not fill then return nil, "fill must be a #rrggbb colour" end
    end
    local stroke = fill
    if def.stroke ~= nil then
        stroke = color(def.stroke)
        if not stroke then return nil, "stroke must be a #rrggbb colour" end
    end
    local pattern = def.pattern
    if pattern == nil then pattern = "hatch" end
    if pattern ~= "hatch" and pattern ~= "solid" then return nil, "pattern must be \"hatch\" or \"solid\"" end
    local label = nil
    if def.label ~= nil and def.label ~= false then
        if type(def.label) ~= "string" then return nil, "label must be a string" end
        label = def.label:sub(1, 64)
        if label == "" then label = nil end
    end
    local labelPosition = nil
    if def.labelPosition ~= nil and def.labelPosition ~= false then
        local lp = def.labelPosition
        local x, y = type(lp) == "table" and finite(lp.x or lp[1]), type(lp) == "table" and finite(lp.y or lp[2])
        if not x or not y then return nil, "labelPosition must be a finite {x, y[, z]}" end
        local z = finite(lp.z or lp[3])
        labelPosition = { x = round1(x), y = round1(y), z = z and round1(z) or nil }
    end
    return {
        points = points,
        fill = fill,
        fillOpacity = clamp(finite(def.fillOpacity) or 0.22, 0, 1),
        stroke = stroke,
        strokeWidth = clamp(finite(def.strokeWidth) or 2, 0, 8),
        pattern = pattern,
        label = label,
        labelPosition = labelPosition,
        map = def.map ~= false,
        minimap = def.minimap ~= false,
        pulse = def.pulse == true,
    }
end

-- The fields of patch merged into area (only the ones given); nil and a reason if invalid.
-- label = false and labelPosition = false clear them; points replace the outline.
function A.patch(area, patch)
    if type(patch) ~= "table" then return nil, "patch must be a table" end
    local merged = {}
    for k, v in pairs(area) do merged[k] = v end
    -- a new fill colour carries the stroke along unless the area had its own
    if patch.fill ~= nil and patch.stroke == nil and area.stroke == area.fill then merged.stroke = nil end
    for k, v in pairs(patch) do merged[k] = v end
    return A.normalize(merged)
end

-- What the page gets: the outline as a flat { x1, y1, x2, y2, ... } (4 values a point in a
-- page event instead of 6) and the label point flattened.
function A.page(id, area)
    local pts = {}
    for i, p in ipairs(area.points) do pts[i * 2 - 1] = p.x; pts[i * 2] = p.y end
    local lp = area.labelPosition
    return {
        id = id, pts = pts,
        fill = area.fill, fillOpacity = area.fillOpacity, stroke = area.stroke, strokeWidth = area.strokeWidth,
        pattern = area.pattern, label = area.label, lx = lp and lp.x, ly = lp and lp.y, lz = lp and lp.z,
        map = area.map, minimap = area.minimap, pulse = area.pulse,
    }
end

-- A copy for getArea (points copied: the caller cannot reach into the registry).
function A.copy(id, area)
    local out = { id = id }
    for k, v in pairs(area) do if k ~= "owner" and k ~= "seq" then out[k] = v end end
    local points = {}
    for i, p in ipairs(area.points) do points[i] = { x = p.x, y = p.y } end
    out.points = points
    if area.labelPosition then out.labelPosition = { x = area.labelPosition.x, y = area.labelPosition.y, z = area.labelPosition.z } end
    return out
end

-- Planar even-odd test, the same rule the page draws with.
function A.contains(area, x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    local pts, inside = area.points, false
    local j = #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then inside = not inside end
        j = i
    end
    return inside
end
