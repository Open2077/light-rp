-- The character's own homes on the map: a private blip on each street door it
-- lives behind or holds a key to (the server's `homes` state), whatever the
-- public entrance list streams nearby. The housing menu routes the GPS to any
-- home's entrance (page action `homes.track`); the route ends at the door.
local E = LightRpEvents
local Homes = { doors = {}, gps = nil }
LightRpHomes = Homes

local HOME_COLOR = "#2EE6F5"
local ARRIVED = 15.0

local function doorKey(p) return string.format("%d:%d:%d", math.floor(p.x * 2 + 0.5), math.floor(p.y * 2 + 0.5), math.floor(p.z * 2 + 0.5)) end

local function apply(list)
    for id in pairs(Homes.doors) do LightRpInteract.setLocal(id, nil) end
    Homes.doors = {}
    -- starter studios share one street door: one blip per door
    local doors = {}
    for _, home in ipairs(list) do
        if type(home) == "table" and type(home.entrance) == "table" then
            local key = doorKey(home.entrance)
            local door = doors[key]
            if not door then doors[key] = { home = home, count = 1 } else door.count = door.count + 1 end
        end
    end
    for _, door in pairs(doors) do
        local home = door.home
        local id = "home." .. home.id
        local blip = LightRpInteract.setLocal(id, {
            position = home.entrance, passive = true,
            blip = { icon = "house", color = HOME_COLOR, size = 44, routable = true,
                title = "My home", description = home.building or home.label },
        })
        Homes.doors[id] = { blip = blip, entrance = home.entrance, homeId = home.id }
    end
end

local function clearGps()
    if Homes.gps then LightRpInteract.setLocal("home.gps", nil); Homes.gps = nil end
end

-- The route to a home's street door: its own blip when it is one of ours,
-- a temporary one otherwise (a home for sale, a friend's door).
function Homes.track(id, entrance, label)
    clearGps()
    for _, door in pairs(Homes.doors) do
        if door.homeId == tonumber(id) and door.blip then
            local ok = LightRpInteract.trackBlip(door.blip)
            if ok then Homes.gps = { entrance = door.entrance, own = true } return true end
        end
    end
    if type(entrance) ~= "table" or type(entrance.x) ~= "number" then return false end
    local blip = LightRpInteract.setLocal("home.gps", {
        position = entrance, passive = true,
        blip = { icon = "house", size = 44, routable = true, title = type(label) == "string" and label or "Home", description = "Entrance" },
    })
    if not blip then return false end
    Homes.gps = { entrance = entrance }
    return LightRpInteract.trackBlip(blip)
end

RegisterNetEvent(E.net.state, function(patch)
    if type(patch) == "table" and type(patch.homes) == "table" then apply(patch.homes) end
end)

-- At the door the temporary route has served: remove it.
CreateThread(function()
    while true do
        Wait(1000)
        local gps = Homes.gps
        if gps and not gps.own and type(Open77.character) == "table" and type(Open77.character.state) == "function" then
            local ok, state = pcall(Open77.character.state)
            local p = ok and type(state) == "table" and state.position
            if p then
                local dx, dy, dz = p.x - gps.entrance.x, p.y - gps.entrance.y, p.z - gps.entrance.z
                if dx * dx + dy * dy + dz * dz < ARRIVED * ARRIVED then clearGps() end
            end
        end
    end
end)
