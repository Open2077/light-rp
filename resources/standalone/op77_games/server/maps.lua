-- The maps of every game. They live in op77_lightrp (table lightrp_game_maps); staff make them
-- in game with /lightrp.maps (docs/map-editor.md there). This file holds this VM's copy.
--
-- Each mode declares its `schema` next to its rules: the one statement of what a map needs. It
-- goes to the core, one game per call, and the core validates every save against it:
--   points   { { key, label, color, hidden } }         one named position each
--   lists    { { key, label, color, min, max } }       a named list of positions
--   numbers  { { key, label, min, max, default, unit, integer, hidden } }
--   choices  { { key, label, about, options = { { id, label } } } }   ticked ids; none: all
--   area     { centre, radius, flat, holds = { keys } }   the play area and what must stay in it
--   apart    { { a, b, metres } }                      two points or lists kept this far apart
-- `hidden` is stored and kept but is no tool: the rules do not read it.
--
-- Delivery is a signal then a pull, never a net event. The core raises gamemaps:changed; we ask
-- gameMapIndex for the ids and revisions and gameMap for each one we do not hold. One map per
-- export call: a call carries 48 KiB at most, a game's eight maps can be more. An answer that
-- is not `ready` (a core that is starting, or has no database) changes nothing: we keep what
-- we hold, and the core signals when it can answer.
--
-- A sync builds new tables and swaps def.maps. Nothing here ever edits a map already handed
-- out: a running match holds its own map (match.map) until it ends, whatever staff do.
local A = GamesActivity

GamesMapStore = {}
local M = GamesMapStore

local cache = {} -- def.id -> { [map id] = { revision, map } }

local function log(text) print("[games:maps] " .. tostring(text)) end

local function placed(p)
    return type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" and type(p.z) == "number"
end

-- The core validated this map. Reading it again costs little and keeps a stale or broken answer
-- out of a match: a mode reads these fields with no second thought.
function M.accept(def, map)
    if type(map) ~= "table" or type(map.id) ~= "string" or type(map.name) ~= "string" then return false, "not a map" end
    local schema = def.schema
    for _, point in ipairs(schema.points or {}) do
        if not point.hidden and not placed(map[point.key]) then return false, "no " .. point.key end
    end
    for _, list in ipairs(schema.lists or {}) do
        local spots = map[list.key]
        if spots == nil then spots = {} end
        if type(spots) ~= "table" or #spots < (list.min or 0) then return false, "too few " .. list.key end
        for _, spot in ipairs(spots) do
            if not placed(spot) then return false, "a bad point in " .. list.key end
        end
    end
    return true
end

-- A delivered map, ready to play: the mode's own derived fields, on our copy.
local function prepared(def, map)
    local ok, why = M.accept(def, map)
    if not ok then return nil, why end
    if def.prepare then
        local done, err = pcall(def.prepare, map)
        if not done then return nil, tostring(err) end
    end
    return map
end

-- The schemas, one call per game. False when the core did not take them all.
function M.offer()
    local all = true
    for _, def in ipairs(A.list) do
        if def.schema then
            local ok, reason = A.call("gameMapSchema", { resource = GetCurrentResourceName(), id = def.id,
                label = def.label, schema = def.schema })
            if ok ~= true then
                all = false
                log(("schema of %s refused: %s"):format(def.id, tostring(reason)))
            end
        end
    end
    return all
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for index, map in ipairs(a) do
        if map ~= b[index] then return false end
    end
    return true
end

-- One game. Returns ok, changed. ok false: an answer failed halfway, nothing changed, try again.
function M.sync(def)
    if not def.schema then return true, false end
    local index = A.call("gameMapIndex", def.id)
    if type(index) ~= "table" then return false, false end
    if index.ready ~= true then return true, false end
    local held, nextCache, maps = cache[def.id] or {}, {}, {}
    for _, row in ipairs(type(index.maps) == "table" and index.maps or {}) do
        local entry = held[row.id]
        if entry == nil or entry.revision ~= row.revision then
            local map = A.call("gameMap", def.id, row.id)
            if type(map) ~= "table" then return false, false end
            local ready, why = prepared(def, map)
            if ready then
                entry = { revision = row.revision, map = ready }
            else
                entry = nil
                log(("%s: map %s left out: %s"):format(def.id, tostring(row.id), tostring(why)))
            end
        end
        if entry then
            nextCache[row.id] = entry
            maps[#maps + 1] = entry.map
        end
    end
    cache[def.id] = nextCache
    if sameList(maps, def.maps) then return true, false end
    def.maps = maps
    return true, true
end

-- Every game. False when one has to be tried again.
function M.syncAll()
    local all = true
    for _, def in ipairs(A.list) do
        if not (M.sync(def)) then all = false end
    end
    return all
end
