-- Dogtown, the PvP zone (server/modules/dogtown.lua decides everything): the map
-- pins (the game map's sprite and a skull on the 3D map, op77_map3d) and the
-- engine's district for the staff survey. Nothing here grants or refuses damage.
--
-- The banner, the HUD tile and the stats live in the page (ui/src/features/dogtown,
-- state key `dogtown`).
local NET, REPORT = "op77_lightrp:dogtown", "op77_lightrp:dogtown:report"
local Dogtown = { config = nil, blip = nil }
LightRpDogtownClient = Dogtown -- (LightRpDogtown is the server config, never downloaded)

local function log(format, ...) if LightRpUi and LightRpUi.log then LightRpUi.log(format, ...) end end

local function mapCall(method, ...)
    if type(GetResourceState) ~= "function" or exports == nil or GetResourceState("op77_map3d") ~= "running" then return false end
    return pcall(function(...) return exports.op77_map3d[method](exports.op77_map3d, ...) end, ...)
end

local function mapDef(c)
    local b = c.blip
    return { id = "lightrp.dogtown", position = b.position, icon = "skull", color = b.color or "#FF2E3C",
        label = b.title or "Dogtown", description = b.description, category = "mission", edge = false }
end

local function clear()
    if Dogtown.blip and type(Open77.blips) == "table" and type(Open77.blips.remove) == "function" then pcall(Open77.blips.remove, Dogtown.blip) end
    Dogtown.blip = nil
    mapCall("removeBlip", "lightrp.dogtown")
end

-- The game map's own Dogtown gate sprite, else the hazard sign; and the 3D map pin.
function Dogtown.build()
    clear()
    local c = Dogtown.config
    if not c or c.enabled == false or type(c.blip) ~= "table" or type(c.blip.position) ~= "table" then return end
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
    mapCall("addBlip", mapDef(c))
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
        if ok and type(state) == "table" and state.attached == true then Dogtown.build() end
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

AddEventHandler("op77_map3d:ready", function()
    if Dogtown.config and Dogtown.config.enabled ~= false and Dogtown.config.blip then mapCall("addBlip", mapDef(Dogtown.config)) end
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
