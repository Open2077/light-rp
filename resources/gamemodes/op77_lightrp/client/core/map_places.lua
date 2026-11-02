-- Places on the maps only (LightRpConfig.mapPlaces: the game's bars and clubs): the
-- native sprite on the game map, routable, and a drawn pin on the 3D map (op77_map3d,
-- when it runs). No marker and no prompt: there is nothing to press there.
--
-- Built when the character enters the world (leaving it clears the blips), in slices:
-- one script resume must stay short, a long loop of blip creations gets killed.
local Config = LightRpConfig.mapPlaces
local Places = { blips = {}, built = 0 }
LightRpMapPlaces = Places
local SLICE = 6

local function log(format, ...) if LightRpUi and LightRpUi.log then LightRpUi.log(format, ...) end end
local function list() return Config and Config.enabled ~= false and type(Config.places) == "table" and Config.places or {} end
local function kindOf(place) return Config.kinds[place.kind] or Config.kinds.bar end

local function mapCall(method, ...)
    if type(GetResourceState) ~= "function" or exports == nil or GetResourceState("op77_map3d") ~= "running" then return false end
    return pcall(function(...) return exports.op77_map3d[method](exports.op77_map3d, ...) end, ...)
end

local function mapDef(place)
    local kind = kindOf(place)
    return { id = "place." .. place.id, position = place.position, icon = LightRpMapIcons and LightRpMapIcons[kind.mapIcon] or "pin",
        color = kind.color, label = place.name, description = (place.district and (place.district .. " · ") or "") .. kind.description,
        category = kind.category }
end

local function clear()
    if type(Open77.blips) == "table" and type(Open77.blips.remove) == "function" then
        for _, id in ipairs(Places.blips) do pcall(Open77.blips.remove, id) end
    end
    Places.blips = {}
end

-- A named venue keeps its name as the map title; a numbered bar shows its kind, with
-- the branch in the description (the game map's own convention).
function Places.build()
    clear()
    local places = list()
    local native = type(Open77.blips) == "table" and type(Open77.blips.create) == "function"
    for i, place in ipairs(places) do
        local kind = kindOf(place)
        if native then
            local named = not tostring(place.name):find("//", 1, true)
            local ok, id, why = pcall(Open77.blips.create, { position = place.position, sprite = kind.sprite,
                title = named and place.name or kind.title, description = place.name .. "\n" .. kind.description,
                active = true, visibleThroughWalls = false, routable = true })
            if ok and id then Places.blips[#Places.blips + 1] = id
            else log("map place %s refused: %s", tostring(place.id), tostring(ok and why or id)) end
        end
        mapCall("addBlip", mapDef(place))
        if i % SLICE == 0 then Wait(0) end
    end
    Places.built = Places.built + 1
    log("%d map place(s)", #places)
end

-- A (re)started 3D map gets every place again; its blips are keyed by id.
AddEventHandler("op77_map3d:ready", function()
    CreateThread(function()
        for i, place in ipairs(list()) do
            mapCall("addBlip", mapDef(place))
            if i % SLICE == 0 then Wait(0) end
        end
    end)
end)

-- Into the world (connect, character switch, respawn after a world change): build.
CreateThread(function()
    local attached = false
    while true do
        Wait(1000)
        local ok, state = pcall(Open77.character.state)
        local now = ok and type(state) == "table" and state.attached == true
        if now and not attached then Places.build() end
        attached = now
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
