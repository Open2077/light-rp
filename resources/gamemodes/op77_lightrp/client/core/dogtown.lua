-- Dogtown, the PvP zone (server/modules/dogtown.lua decides everything): the map
-- pins (the game map's sprite and a skull on the 3D map, op77_map3d), the zone itself
-- drawn on the 3D map and its minimap (op77_map3d areas: the server's polygon, red,
-- hatched, labelled) and the engine's district for the staff survey. Nothing here grants
-- or refuses damage.
--
-- The banner, the HUD tile and the stats live in the page (ui/src/features/dogtown,
-- state key `dogtown`).
local NET, REPORT = "op77_lightrp:dogtown", "op77_lightrp:dogtown:report"
local Dogtown = { config = nil, blip = nil, mapBlip = nil }
local MAP_ID = "lightrp.dogtown" -- the 3D map pin and area (op77_map3d namespaces it: "op77_lightrp:lightrp.dogtown")
LightRpDogtownClient = Dogtown -- (LightRpDogtown is the server config, never downloaded)

local function log(format, ...) if LightRpUi and LightRpUi.log then LightRpUi.log(format, ...) end end

local function mapCall(method, ...)
    if type(GetResourceState) ~= "function" or exports == nil or GetResourceState("op77_map3d") ~= "running" then return false end
    return pcall(function(...) return exports.op77_map3d[method](exports.op77_map3d, ...) end, ...)
end

local function mapDef(c)
    local b = c.blip
    return { id = MAP_ID, position = b.position, icon = "skull", color = b.color or "#FF2E3C",
        label = b.title or "Dogtown", description = b.description, category = "mission", edge = false }
end

-- The zone as an op77_map3d area: the server's outline (flat x1, y1, x2, y2, ...) and look.
local function areaDef(c)
    local o, a = c.outline, c.area
    if type(o) ~= "table" or #o < 6 or type(a) ~= "table" then return nil end
    local points = {}
    for i = 1, #o - 1, 2 do points[#points + 1] = { x = o[i], y = o[i + 1] } end
    return { id = MAP_ID, points = points, fill = a.fill, fillOpacity = a.fillOpacity, stroke = a.stroke, strokeWidth = a.strokeWidth,
        pattern = a.pattern, label = a.label, labelPosition = a.labelPosition, map = a.map ~= false, minimap = a.minimap ~= false, pulse = a.pulse == true }
end

-- The 3D map's pin and area: added or replaced (same ids), or removed when the zone has
-- none. The ids op77_map3d returns are namespaced to this resource.
local function mapPin(c)
    if c and type(c.blip) == "table" and type(c.blip.position) == "table" then
        local ok, id = mapCall("addBlip", mapDef(c))
        if ok and id then Dogtown.mapBlip = id end
    else
        mapCall("removeBlip", Dogtown.mapBlip or (GetCurrentResourceName() .. ":" .. MAP_ID))
        Dogtown.mapBlip = nil
    end
end

local function mapArea(c)
    local def = c and areaDef(c)
    if def then
        local ok, id, why = mapCall("addArea", def)
        if ok and not id then log("dogtown map area refused: %s", tostring(why)) end
    else
        mapCall("removeArea", MAP_ID)
    end
end

local function clear()
    if Dogtown.blip and type(Open77.blips) == "table" and type(Open77.blips.remove) == "function" then pcall(Open77.blips.remove, Dogtown.blip) end
    Dogtown.blip = nil
    mapPin(nil)
    mapArea(nil)
end

-- The game map's own Dogtown gate sprite, else the hazard sign (the native map takes no
-- polygon); the 3D map's skull pin and the zone drawn on it and on its minimap.
function Dogtown.build()
    local c = Dogtown.config
    if not c or c.enabled == false then clear(); return end
    if Dogtown.blip and type(Open77.blips) == "table" and type(Open77.blips.remove) == "function" then pcall(Open77.blips.remove, Dogtown.blip) end
    Dogtown.blip = nil
    mapArea(c)
    mapPin(c)
    if type(c.blip) ~= "table" or type(c.blip.position) ~= "table" then return end
    local b = c.blip
    if type(Open77.blips) == "table" and type(Open77.blips.create) == "function" then
        for _, sprite in ipairs({ b.sprite, b.fallbackSprite }) do
            if type(sprite) == "string" and sprite ~= "" then
                local ok, id, why = pcall(Open77.blips.create, { position = b.position, sprite = sprite, title = b.title or "Dogtown",
                    description = b.description, active = true, visibleThroughWalls = false, routable = true })
                if ok and id then Dogtown.blip = id; break end
                log("dogtown blip sprite %s refused: %s", tostring(sprite), tostring(ok and why or id))
            end
        end
    end
end

local function place()
    local ok, here, why = pcall(Open77.world.district)
    if ok and type(here) == "table" then return here end
    return nil, ok and why or here
end

RegisterNetEvent(NET, function(message)
    if type(message) ~= "table" then return end
    if message.kind == "config" then
        Dogtown.config = message
        local ok, state = pcall(Open77.character.state)
        -- switched off: everything goes at once, in the world or not
        if message.enabled == false or (ok and type(state) == "table" and state.attached == true) then Dogtown.build() end
    elseif message.kind == "probe" then
        local here = place() or {}
        TriggerServerEvent(REPORT, { kind = "probe", token = message.token, district = here.district or "", subDistrict = here.subDistrict or "" })
    end
end)

-- A border the engine saw: the server compares it with the polygon (survey aid).
AddEventHandler("open77:districtChanged", function(here)
    if type(here) ~= "table" then return end
    TriggerServerEvent(REPORT, { kind = "district", district = tostring(here.district or ""), subDistrict = tostring(here.subDistrict or "") })
end)

-- op77_map3d (re)started: its pins and areas are gone, add ours again.
AddEventHandler("op77_map3d:ready", function()
    local c = Dogtown.config
    if c and c.enabled ~= false then mapArea(c); mapPin(c) end
end)

-- Into the world (connect, character switch, respawn): ask for the config, build.
CreateThread(function()
    TriggerServerEvent(REPORT, { kind = "hello" })
    local attached = false
    while true do
        Wait(1000)
        local ok, state = pcall(Open77.character.state)
        local now = ok and type(state) == "table" and state.attached == true
        if now and not attached then
            if Dogtown.config then Dogtown.build() else TriggerServerEvent(REPORT, { kind = "hello" }) end
        end
        attached = now
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
