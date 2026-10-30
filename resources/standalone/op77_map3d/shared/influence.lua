-- Influence zones: where the players are, for the others to find them. The server
-- groups positions into zones (occupied grid cells, merged with their neighbours) and
-- grades each by how many players it holds; the map draws them (ui/src/influence.ts).
-- Pure functions, shared so the tests run them as the server does.
Map3DInfluence = {}
local I = Map3DInfluence
-- A zone shows a crowd, never a person: whatever the configuration says, fewer players
-- than this never make a zone (a zone of one or two would follow them around the city).
I.MIN_GROUP = 3

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

--- The density level of a zone of `count` players: the last threshold it reaches.
function I.level(count, levels)
    local index = 0
    for i, l in ipairs(levels or {}) do
        if count >= (tonumber(l.min) or math.huge) then index = i end
    end
    return index
end

--- points: { { x, y, z } ... } -> zones { id, x, y, z, radius, count, level }, densest first.
function I.cluster(points, cfg)
    cfg = cfg or {}
    local cell = clamp(tonumber(cfg.cell) or 150, 20, 2000)
    local cells, order = {}, {}
    for _, p in ipairs(points) do
        local x, y = tonumber(p.x), tonumber(p.y)
        if x and y then
            local cx, cy = math.floor(x / cell), math.floor(y / cell)
            local key = cx .. ":" .. cy
            local c = cells[key]
            if not c then c = { cx = cx, cy = cy, key = key, points = {} }; cells[key] = c; order[#order + 1] = key end
            c.points[#c.points + 1] = { x = x, y = y, z = tonumber(p.z) or 0 }
        end
    end
    -- occupied cells touching each other (diagonals too) are one zone
    table.sort(order)
    local seen, zones = {}, {}
    for _, start in ipairs(order) do
        if not seen[start] then
            seen[start] = true
            local stack, members = { cells[start] }, {}
            while #stack > 0 do
                local c = table.remove(stack)
                members[#members + 1] = c
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local k = (c.cx + dx) .. ":" .. (c.cy + dy)
                        if cells[k] and not seen[k] then seen[k] = true; stack[#stack + 1] = cells[k] end
                    end
                end
            end
            local n, sx, sy, sz, densest = 0, 0, 0, 0, members[1]
            for _, c in ipairs(members) do
                for _, p in ipairs(c.points) do n = n + 1; sx = sx + p.x; sy = sy + p.y; sz = sz + p.z end
                if #c.points > #densest.points or (#c.points == #densest.points and c.key < densest.key) then densest = c end
            end
            local x, y, z = sx / n, sy / n, sz / n
            local far = 0
            for _, c in ipairs(members) do
                for _, p in ipairs(c.points) do far = math.max(far, math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)) end
            end
            -- the centre is snapped: a zone does not follow its players metre by metre
            local snap = clamp(tonumber(cfg.snap) or 25, 0, 500)
            if snap > 0 then x = math.floor(x / snap + 0.5) * snap; y = math.floor(y / snap + 0.5) * snap end
            zones[#zones + 1] = {
                id = "z" .. densest.key, x = x, y = y, z = math.floor(z * 10 + 0.5) / 10, count = n,
                radius = clamp(far + (tonumber(cfg.padding) or 70), tonumber(cfg.minRadius) or 90, tonumber(cfg.maxRadius) or 900),
            }
        end
    end
    local minPlayers = math.max(I.MIN_GROUP, math.floor(tonumber(cfg.minPlayers) or 5))
    local out = {}
    for _, z in ipairs(zones) do
        if z.count >= minPlayers then
            z.level = I.level(z.count, cfg.levels)
            z.radius = math.floor(z.radius + 0.5)
            out[#out + 1] = z
        end
    end
    table.sort(out, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.id < b.id end)
    local max = math.max(1, math.floor(tonumber(cfg.maxZones) or 24))
    while #out > max do table.remove(out) end
    return out
end

--- A short text that changes only when the zones a player sees change.
function I.signature(zones)
    local parts = {}
    for _, z in ipairs(zones) do parts[#parts + 1] = string.format("%s,%.0f,%.0f,%.0f,%d", z.id, z.x, z.y, z.radius, z.count) end
    return table.concat(parts, ";")
end
