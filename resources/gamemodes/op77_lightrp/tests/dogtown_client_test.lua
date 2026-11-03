-- client/core/dogtown.lua: the map pins, the zone on the 3D map (op77_map3d area) and the
-- district probe of the staff survey.
local threads, events, net, toServer, created, removed, mapAdds, mapRemoves, logs = {}, {}, {}, {}, {}, {}, {}, {}, {}
local areaAdds, areaRemoves, refuseArea = {}, {}, nil
local attached, district, refuseSprite = false, { district = "Dogtown", subDistrict = "" }, nil
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn); assert(coroutine.resume(threads[#threads])) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) events[name] = fn end
RegisterNetEvent = function(name, fn) net[name] = fn end
TriggerServerEvent = function(name, payload) toServer[#toServer + 1] = { name = name, payload = payload } end
GetCurrentResourceName = function() return "op77_lightrp" end
GetResourceState = function() return "running" end
-- op77_map3d namespaces the ids it hands out to the calling resource
exports = { op77_map3d = {
    addBlip = function(_, def) mapAdds[#mapAdds + 1] = def; return "op77_lightrp:" .. def.id end,
    removeBlip = function(_, id) mapRemoves[#mapRemoves + 1] = id; return true end,
    addArea = function(_, def) if refuseArea then return nil, refuseArea end areaAdds[#areaAdds + 1] = def; return "op77_lightrp:" .. def.id end,
    removeArea = function(_, id) areaRemoves[#areaRemoves + 1] = id; return true end,
} }
Open77 = {
    character = { state = function() return { attached = attached } end },
    world = { district = function() return district end },
    blips = {
        create = function(def) if def.sprite == refuseSprite then return nil, "unknown_sprite" end created[#created + 1] = def; return #created end,
        remove = function(id) removed[#removed + 1] = id; return true end,
    },
}
LightRpUi = { log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end }
dofile("client/core/dogtown.lua")
local loop = threads[1]
local function tick() assert(coroutine.resume(loop)) end
local NET, REPORT = "op77_lightrp:dogtown", "op77_lightrp:dogtown:report"
assert(toServer[1].name == REPORT and toServer[1].payload.kind == "hello", "asks for the config at start")
local area = { label = "DOGTOWN · DANGER ZONE", labelPosition = { x = -1420, y = -2560 }, fill = "#FF2E3C", fillOpacity = 0.22,
    stroke = "#FF2E3C", strokeWidth = 2.5, pattern = "hatch", map = true, minimap = true, pulse = false }
local config = { kind = "config", enabled = true, label = "Dogtown", blip = { position = { x = -1754.6, y = -2490.6, z = 40 },
    title = "Dogtown · PvP zone", description = "No law.", sprite = "Zzz13_DogtownGateVariant", fallbackSprite = "HazardWarningVariant", color = "#FF2E3C" },
    area = area, outline = { -2550, -2726.6, -2410, -2846.6, -1250, -2586.6, -1290, -2366.6 } }
-- Config before the world: kept, nothing drawn yet.
net[NET](config)
assert(#created == 0 and #mapAdds == 0 and #areaAdds == 0)
-- Into the world: the game map's gate sprite, the 3D map skull and the zone itself.
attached = true; tick()
assert(#created == 1 and created[1].sprite == "Zzz13_DogtownGateVariant" and created[1].routable == true and created[1].title == "Dogtown · PvP zone")
assert(#mapAdds == 1 and mapAdds[1].icon == "skull" and mapAdds[1].color == "#FF2E3C" and mapAdds[1].id == "lightrp.dogtown")
local a = areaAdds[1]
assert(#areaAdds == 1 and a.id == "lightrp.dogtown" and #a.points == 4 and a.points[1].x == -2550 and a.points[1].y == -2726.6 and a.points[4].y == -2366.6,
    "the server's outline as an op77_map3d area")
assert(a.label == "DOGTOWN · DANGER ZONE" and a.fill == "#FF2E3C" and a.fillOpacity == 0.22 and a.strokeWidth == 2.5 and a.pattern == "hatch"
    and a.labelPosition.x == -1420 and a.map and a.minimap and a.pulse == false, "red, hatched, labelled, on the map and the minimap")
tick(); assert(#created == 1 and #areaAdds == 1, "built once per entry")
-- A build without the gate sprite falls back to the hazard sign.
refuseSprite = "Zzz13_DogtownGateVariant"
net[NET](config)
assert(#removed == 1 and created[#created].sprite == "HazardWarningVariant" and logs[#logs]:find("refused", 1, true))
assert(#mapRemoves == 0 and #areaRemoves == 0, "a rebuild replaces the 3D map's pin and area in place (same ids)")
-- A staff survey (apply / reset) sends a new outline: the area follows.
local surveyed = { kind = "config", enabled = true, label = "Dogtown", blip = config.blip, area = area, outline = { 0, 0, 100, 0, 0, 100 } }
net[NET](surveyed)
assert(#areaAdds == 3 and #areaAdds[3].points == 3 and areaAdds[3].points[2].x == 100 and #areaRemoves == 0)
-- The map refusing the area is logged, the pins stay.
refuseArea = "an area needs at least 3 points"
net[NET](config)
local function logged(text) for i = #logs, 1, -1 do if logs[i]:find(text, 1, true) then return true end end end
assert(logged("map area refused: an area needs at least 3 points") and #mapAdds == 4)
refuseArea = nil
-- op77_map3d restarts: the pin and the area come back.
events["op77_map3d:ready"]()
assert(#mapAdds == 5 and #areaAdds == 4 and areaAdds[4].points[1].x == -2550)
-- A config without an area (Config.area = false) takes it off the map.
net[NET]({ kind = "config", enabled = true, label = "Dogtown", blip = config.blip })
assert(areaRemoves[#areaRemoves] == "lightrp.dogtown")
-- The zone switched off: the pins and the area go away (the 3D map pin by the id the map gave).
net[NET](config)
local removedAreas, removedSprites = #areaRemoves, #removed
net[NET]({ kind = "config", enabled = false, label = "Dogtown", blip = config.blip, area = area, outline = config.outline })
assert(#removed == removedSprites + 1 and mapRemoves[#mapRemoves] == "op77_lightrp:lightrp.dogtown", "the skull is removed by its namespaced id")
assert(#areaRemoves == removedAreas + 1 and areaRemoves[#areaRemoves] == "lightrp.dogtown")
events["op77_map3d:ready"]()
assert(#areaAdds == 5, "nothing comes back while the zone is off")
-- Switched off while out of the world (loading, character menu): cleared at once too.
net[NET](config)
attached = false; tick()
local before = #areaRemoves
net[NET]({ kind = "config", enabled = false, label = "Dogtown", blip = config.blip })
assert(#areaRemoves == before + 1 and #mapRemoves >= 2, "switched off out of the world: off the map at once")
-- The survey probe answers with the engine's district.
net[NET]({ kind = "probe", token = 7 })
local reply = toServer[#toServer].payload
assert(reply.kind == "probe" and reply.token == 7 and reply.district == "Dogtown")
district = nil
net[NET]({ kind = "probe", token = 8 })
assert(toServer[#toServer].payload.token == 8 and toServer[#toServer].payload.district == "", "an unknown district answers empty")
-- A border the engine saw is reported (survey aid only).
events["open77:districtChanged"]({ district = "Pacifica", subDistrict = "WestWindEstate" })
assert(toServer[#toServer].payload.kind == "district" and toServer[#toServer].payload.district == "Pacifica")
print("PASS: Dogtown client (config at start, gate sprite + hazard fallback, 3D map skull, zone area on the 3D map + minimap, survey update, map restart, switched off, district probe, border report)")
