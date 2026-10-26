-- open77_lobby_cubes: what moves in the tutorial lobby (client side, nothing is replicated).
--
-- cubes.json (written by the map's generator, tools/gen.py) lists the cubes meant to move: where each one rests in the
-- world, its size, its group (monument_inner, monument_outer, portal, avenue, metier_<job>, lieu_<place>) and its
-- motion: spin (degrees per second), bob (metres up and down) over period (seconds), orbit {centre, radius, speed in
-- degrees per second, phase, arc}. It also lists the tutorial's stops (points) for the tutorial resource to come.
--
-- Two ways of showing them:
--   'markers'  works today. Each cube of the map (they are static meshes: Lua cannot move a mesh of the world) gets a
--              halo, a translucent ring that tumbles round it, bobs and, for the monument's groups, travels along
--              the circle of cubes. Open77.markers turns on three axes and moves in place.
--   'props'    real cubes that move: one client prop per cube, moved in place with Open77.props.setTransform
--              (position and yaw: props have no pitch or roll). It needs a cube among the client's prop aliases
--              (Config.propModel): a raw .mesh path is drawn as the grey marker cylinder. With it, take the folder
--              "Cubes animés (Lua)" out of the map, or each cube is there twice.

local Config = {
    backend = 'markers',                 -- 'markers' or 'props'
    propModel = 'lobby_cube',            -- props: the alias of a 1 m white cube (scaled per cube)
    range = 330.0,                       -- metres from the lobby's centre within which the cubes exist
    perFrame = 20,                       -- how many are moved each frame, in turn (the frame budget is shared)
    maxDistance = 220,                   -- markers: hidden beyond
    color = { r = 255, g = 255, b = 255, a = 130 },
    glowColor = { r = 170, g = 230, b = 255, a = 210 },
    groups = {},                         -- e.g. { avenue = false } leaves a group still
}

local manifest, cubes = nil, {}
local alive, cursor, retryAt = false, 0, 0

local function log(text) print('[lobby_cubes] ' .. text) end

local function load()
    local text, reason = Open77.resource.readFile('cubes.json')
    if not text then log('cubes.json: ' .. tostring(reason)) return false end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' or type(data.cubes) ~= 'table' then log('cubes.json is not readable') return false end
    manifest = data
    for index, cube in ipairs(data.cubes) do
        if Config.groups[cube.group] ~= false then
            cube.seed = index * 1.618            -- so that no two move together
            cubes[#cubes + 1] = cube
        end
    end
    log(('%d cubes in %s mode'):format(#cubes, Config.backend))
    return true
end

-- Where a cube is at a time (seconds): x, y, z, and how far it has turned (degrees).
local function pose(cube, time)
    local x, y, z = cube.position.x, cube.position.y, cube.position.z
    local orbit = cube.orbit
    if orbit then
        local angle
        if orbit.arc then      -- back and forth along a part of the circle (a marker moved far from where it was made is made again)
            angle = orbit.phase + orbit.arc / 2 * math.sin(time * math.abs(orbit.speed) / orbit.arc * math.pi + cube.seed)
        else
            angle = orbit.phase + orbit.speed * time
        end
        local radians = math.rad(angle)
        x, y = orbit.centre.x + orbit.radius * math.cos(radians), orbit.centre.y + orbit.radius * math.sin(radians)
    end
    if cube.bob and cube.bob > 0 then z = z + cube.bob * math.sin(time * 2 * math.pi / (cube.period or 6) + cube.seed) end
    return x, y, z, (cube.spin or 0) * time
end

local function make(cube, time)
    local x, y, z, turned = pose(cube, time)
    if Config.backend == 'props' then
        local id, reason = Open77.props.create({ model = Config.propModel, position = { x = x, y = y, z = z }, yaw = (cube.rotation.z + turned) % 360, scale = cube.size, collision = false })
        return id, reason
    end
    -- The ring is thin and turns about its own middle: a halo round the cube.
    return Open77.markers.create({
        shape = 'ring', radius = cube.size * 0.95, height = 1.5, position = { x = x, y = y, z = z },
        rotation = { x = cube.rotation.x, y = cube.rotation.y, z = cube.rotation.z },
        color = cube.glow and Config.glowColor or Config.color, maxDistance = Config.maxDistance,
    })
end

local function move(cube, time)
    local x, y, z, turned = pose(cube, time)
    if Config.backend == 'props' then
        return Open77.props.setTransform(cube.handle, { position = { x = x, y = y, z = z }, yaw = (cube.rotation.z + turned) % 360 })
    end
    return Open77.markers.update(cube.handle, {
        position = { x = x, y = y, z = z },
        rotation = { x = (cube.rotation.x + turned * 0.6) % 360, y = (cube.rotation.y + turned * 0.35) % 360, z = (cube.rotation.z + turned) % 360 },
    })
end

local function clear()
    for _, cube in ipairs(cubes) do
        if cube.handle then
            if Config.backend == 'props' then Open77.props.remove(cube.handle) else Open77.markers.remove(cube.handle) end
            cube.handle = nil
        end
    end
    alive = false
end

local function create(time)
    local made, problem = 0, nil
    for _, cube in ipairs(cubes) do
        if not cube.handle then
            local id, reason = make(cube, time)
            if id then cube.handle = id made = made + 1 else problem = problem or tostring(reason) end
        end
    end
    alive = made > 0 or alive
    if problem then
        log('some cubes were not made: ' .. problem)
        -- The world not being there yet is tried again; a cube alias the client does not have falls back to the halos.
        if Config.backend == 'props' and made == 0 and problem ~= 'world_unavailable' then
            log('no prop "' .. Config.propModel .. '": showing the halos instead')
            Config.backend = 'markers'
        end
    end
end

if load() then
    SetTick(function()
        local time = Open77.time.monotonic()
        local x, y, z = Open77.character.position()
        local centre = manifest.origin
        local near = x ~= nil and (x - centre.x) ^ 2 + (y - centre.y) ^ 2 + (z - centre.z) ^ 2 < Config.range ^ 2
        if not near then
            if alive then clear() end
            return
        end
        if not alive then
            if time >= retryAt then retryAt = time + 2 create(time) end
            return
        end
        for _ = 1, math.min(Config.perFrame, #cubes) do
            cursor = cursor % #cubes + 1
            local cube = cubes[cursor]
            if cube.handle then move(cube, time) end
        end
    end)
end
