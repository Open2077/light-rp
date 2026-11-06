-- What a game puts in the world for this player: markers and map pins. The server lists them in
-- the HUD view (`view.world`), for the players of one match only, so nobody else ever draws them:
-- a marker is local to its client and a bucket does not filter it. Decides nothing; a marker
-- never proves a position. Loaded before client/main.lua, which calls GamesObjectives.sync.
--   world = { markers = { key = { position, shape, radius, height, color } },
--             blips = { key = { position, title } } }   nil: everything goes
GamesObjectives = {}
local O = GamesObjectives

local markers, blips = {}, {} -- key -> { id, ...what it shows }
local said = {}

local function warn(what, why)
    local line = what .. ": " .. tostring(why)
    if said[line] then return end
    said[line] = true
    if Open77.log and Open77.log.warn then Open77.log.warn("[games] " .. line) end
end

local function moved(a, b) return a.x ~= b.x or a.y ~= b.y or a.z ~= b.z end

local function sameColor(a, b) return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a end

local function syncMarker(key, want)
    if type(Open77.markers) ~= "table" then return warn("marker " .. key, "markers unavailable") end
    local known = markers[key]
    if known == nil then
        local ok, id, why = pcall(Open77.markers.create, { position = want.position, shape = want.shape, radius = want.radius,
            height = want.height, color = want.color, maxDistance = 400 })
        if ok and id then markers[key] = { id = id, position = want.position, color = want.color }
        else warn("marker " .. key, ok and why or id) end
        return
    end
    local patch = {}
    if moved(known.position, want.position) then patch.position = want.position end
    if not sameColor(known.color, want.color) then patch.color = want.color end
    if next(patch) == nil then return end
    local ok, done, why = pcall(Open77.markers.update, known.id, patch)
    if ok and done then known.position, known.color = want.position, want.color
    else warn("marker " .. key, ok and why or done) end
end

local function syncBlip(key, want)
    if type(Open77.blips) ~= "table" then return warn("blip " .. key, "blips unavailable") end
    local known = blips[key]
    if known == nil then
        local ok, id, why = pcall(Open77.blips.create, { position = want.position, sprite = "objective", title = want.title,
            active = true, visibleThroughWalls = true })
        if ok and id then blips[key] = { id = id, position = want.position }
        else warn("blip " .. key, ok and why or id) end
        return
    end
    if not moved(known.position, want.position) then return end
    local ok, done, why = pcall(Open77.blips.setPosition, known.id, want.position)
    if ok and done then known.position = want.position
    else warn("blip " .. key, ok and why or done) end
end

function O.sync(world)
    local wantMarkers = type(world) == "table" and type(world.markers) == "table" and world.markers or {}
    local wantBlips = type(world) == "table" and type(world.blips) == "table" and world.blips or {}
    for key, known in pairs(markers) do
        if wantMarkers[key] == nil then
            pcall(Open77.markers.remove, known.id)
            markers[key] = nil
        end
    end
    for key, known in pairs(blips) do
        if wantBlips[key] == nil then
            pcall(Open77.blips.remove, known.id)
            blips[key] = nil
        end
    end
    for key, want in pairs(wantMarkers) do syncMarker(key, want) end
    for key, want in pairs(wantBlips) do syncBlip(key, want) end
end
