-- Game maps: the checks, pure (no platform, no storage). The format of a schema is at the top
-- of op77_games/server/maps.lua; a game declares it next to its rules and this file only reads it.
--   R.schema(raw)          a provider's schema, cleaned          -> schema | nil, reason
--   R.sanitize(schema, x)  hostile input to a map, or a refusal  -> map | nil, reason
--   R.problems(schema, m)  what stops a map being enabled        -> list of sentences (empty: ok)
-- sanitize takes any draft: unfinished is fine, malformed is not. Only problems() stands between
-- a draft and players. Mirrored for the menu in ui/src/features/mapeditor/model.ts `problems`.
LightRpGameMapRules = { MAX_ENABLED = 8, MAX_MAPS = 32, MAX_NAME = 32, LIMIT = 100000 }
local R = LightRpGameMapRules

local RESERVED = { id = true, name = true, game = true, enabled = true, revision = true, deleted = true, problems = true }

local function finite(n, limit)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and (limit == nil or math.abs(n) <= limit)
end
local function key(value)
    return type(value) == "string" and #value <= 24 and value:match("^%a%w*$") ~= nil and not RESERVED[value]
end
local function label(value, fallback, max)
    if type(value) ~= "string" then return fallback end
    local text = value:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return fallback end
    return text:sub(1, max or 48)
end
local function color(value)
    return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") and value or "#ffffff"
end
-- A real list: keys 1..n, nothing else.
local function list(value)
    if type(value) ~= "table" then return nil end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    if count ~= #value then return nil end
    return value
end

function R.schema(raw)
    if type(raw) ~= "table" then return nil, "The schema must be a table." end
    local out, seen = { points = {}, lists = {}, numbers = {}, choices = {}, apart = {} }, {}
    local function claim(name)
        if not key(name) then return false end
        if seen[name] then return false end
        seen[name] = true
        return true
    end
    for _, p in ipairs(type(raw.points) == "table" and raw.points or {}) do
        if type(p) ~= "table" or not claim(p.key) or #out.points >= 16 then return nil, "A schema point is invalid." end
        out.points[#out.points + 1] = { key = p.key, label = label(p.label, p.key), color = color(p.color), hidden = p.hidden == true or nil }
    end
    for _, l in ipairs(type(raw.lists) == "table" and raw.lists or {}) do
        if type(l) ~= "table" or not claim(l.key) or #out.lists >= 8 then return nil, "A schema list is invalid." end
        local least, most = math.tointeger(l.min or 0), math.tointeger(l.max)
        if not least or not most or least < 0 or most < 1 or most > 64 or least > most then return nil, "A schema list has bad limits." end
        out.lists[#out.lists + 1] = { key = l.key, label = label(l.label, l.key), color = color(l.color), min = least, max = most }
    end
    for _, n in ipairs(type(raw.numbers) == "table" and raw.numbers or {}) do
        if type(n) ~= "table" or not claim(n.key) or #out.numbers >= 16 then return nil, "A schema number is invalid." end
        if not finite(n.min) or not finite(n.max) or not finite(n.default) or n.min > n.max or n.default < n.min or n.default > n.max then
            return nil, "A schema number has bad limits."
        end
        out.numbers[#out.numbers + 1] = { key = n.key, label = label(n.label, n.key), min = n.min, max = n.max, default = n.default,
            unit = label(n.unit, "", 8), integer = n.integer == true or nil, hidden = n.hidden == true or nil }
    end
    for _, c in ipairs(type(raw.choices) == "table" and raw.choices or {}) do
        if type(c) ~= "table" or not claim(c.key) or #out.choices >= 4 or type(c.options) ~= "table" or #c.options > 256 then
            return nil, "A schema choice is invalid."
        end
        local options = {}
        for i, o in ipairs(c.options) do
            if type(o) ~= "table" or type(o.id) ~= "string" or #o.id == 0 or #o.id > 64 then return nil, "A schema option is invalid." end
            options[i] = { id = o.id, label = label(o.label, o.id) }
        end
        out.choices[#out.choices + 1] = { key = c.key, label = label(c.label, c.key), about = label(c.about, "", 120), options = options }
    end
    if raw.area ~= nil then
        local a = raw.area
        if type(a) ~= "table" or not seen[a.centre] or not seen[a.radius] then return nil, "The schema's area is invalid." end
        local holds = {}
        for i, name in ipairs(type(a.holds) == "table" and a.holds or {}) do
            if not seen[name] then return nil, "The schema's area holds an unknown key." end
            holds[i] = name
        end
        out.area = { centre = a.centre, radius = a.radius, flat = a.flat == true or nil, holds = holds }
    end
    for _, gap in ipairs(type(raw.apart) == "table" and raw.apart or {}) do
        if type(gap) ~= "table" or not seen[gap.a] or not seen[gap.b] or not finite(gap.metres) or gap.metres <= 0 or #out.apart >= 8 then
            return nil, "A schema gap is invalid."
        end
        out.apart[#out.apart + 1] = { a = gap.a, b = gap.b, metres = gap.metres }
    end
    return out
end

local function position(value)
    if type(value) ~= "table" or not finite(value.x, R.LIMIT) or not finite(value.y, R.LIMIT) or not finite(value.z, R.LIMIT) then return nil end
    local out = { x = value.x, y = value.y, z = value.z }
    if value.heading ~= nil then
        if not finite(value.heading, 36000) then return nil end
        out.heading = value.heading
    end
    return out
end

-- A clean map, with every number set. An unplaced point stays nil; junk is refused, not repaired.
function R.sanitize(schema, input)
    if type(input) ~= "table" then return nil, "The map is invalid." end
    if type(input.name) ~= "string" then return nil, "Give the map a name." end
    local name = input.name:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > R.MAX_NAME then return nil, ("A map name is 1 to %d characters."):format(R.MAX_NAME) end
    local map = { name = name, enabled = input.enabled == true }
    for _, p in ipairs(schema.points) do
        local value = input[p.key]
        if value ~= nil then
            local at = position(value)
            if not at then return nil, p.label .. " is not a position." end
            map[p.key] = at
        end
    end
    for _, l in ipairs(schema.lists) do
        local value = input[l.key]
        if value ~= nil then
            local items = list(value)
            if not items then return nil, l.label .. " is not a list." end
            if #items > l.max then return nil, ("%s: %d at most."):format(l.label, l.max) end
            local spots = {}
            for i, item in ipairs(items) do
                local at = position(item)
                if not at then return nil, ("%s %d is not a position."):format(l.label, i) end
                spots[i] = at
            end
            map[l.key] = spots
        else
            map[l.key] = {}
        end
    end
    for _, n in ipairs(schema.numbers) do
        local value = input[n.key]
        if value == nil then value = n.default end
        if not finite(value) or value < n.min or value > n.max then
            return nil, ("%s must be between %s and %s."):format(n.label, n.min, n.max)
        end
        if n.integer and math.tointeger(value) == nil then return nil, n.label .. " must be a whole number." end
        map[n.key] = n.integer and math.tointeger(value) or value
    end
    for _, c in ipairs(schema.choices) do
        local value = input[c.key]
        local picked = {}
        if value ~= nil then
            local items = list(value)
            if not items or #items > #c.options then return nil, c.label .. " is not a list." end
            local known, taken = {}, {}
            for _, o in ipairs(c.options) do known[o.id] = true end
            for _, item in ipairs(items) do
                if type(item) ~= "string" or not known[item] then return nil, c.label .. ": unknown option." end
                if not taken[item] then
                    taken[item] = true
                    picked[#picked + 1] = item
                end
            end
        end
        map[c.key] = picked
    end
    return map
end

local function spotsOf(schema, map, name)
    for _, p in ipairs(schema.points) do
        if p.key == name then return map[name] and { { map[name], p.label } } or {} end
    end
    for _, l in ipairs(schema.lists) do
        if l.key == name then
            local out = {}
            for i, spot in ipairs(map[name] or {}) do out[i] = { spot, ("%s %d"):format(l.label, i) } end
            return out
        end
    end
    return {}
end

local function gap(a, b, flat)
    local dx, dy, dz = a.x - b.x, a.y - b.y, flat and 0 or a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function R.problems(schema, map)
    local out = {}
    for _, p in ipairs(schema.points) do
        if not p.hidden and map[p.key] == nil then out[#out + 1] = ("Place %s."):format(p.label) end
    end
    for _, l in ipairs(schema.lists) do
        local have = #(map[l.key] or {})
        if have < l.min then out[#out + 1] = ("%s: at least %d, %d placed."):format(l.label, l.min, have) end
    end
    local area = schema.area
    if area then
        local centre, radius = map[area.centre], map[area.radius]
        if centre and radius then
            for _, name in ipairs(area.holds) do
                for _, spot in ipairs(spotsOf(schema, map, name)) do
                    if gap(spot[1], centre, area.flat) > radius then out[#out + 1] = spot[2] .. " is outside the play area." end
                end
            end
        end
    end
    for _, pair in ipairs(schema.apart) do
        local reported = false
        for _, a in ipairs(spotsOf(schema, map, pair.a)) do
            for _, b in ipairs(spotsOf(schema, map, pair.b)) do
                if not reported and gap(a[1], b[1], true) < pair.metres then
                    reported = true
                    out[#out + 1] = ("%s and %s must be %s m apart."):format(a[2], b[2], pair.metres)
                end
            end
        end
    end
    return out
end

-- A slug for a new map: what a room and a join carry.
function R.slug(name)
    local text = tostring(name):lower():gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if text == "" then text = "map" end
    return text:sub(1, 40)
end
