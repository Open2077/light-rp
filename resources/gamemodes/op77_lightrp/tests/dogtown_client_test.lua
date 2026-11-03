-- client/core/dogtown.lua: the map pins and the district probe of the staff survey.
local threads, events, net, toServer, created, removed, mapAdds, mapRemoves, logs = {}, {}, {}, {}, {}, {}, {}, {}, {}
local attached, district, refuseSprite = false, { district = "Dogtown", subDistrict = "" }, nil
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn); assert(coroutine.resume(threads[#threads])) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) events[name] = fn end
RegisterNetEvent = function(name, fn) net[name] = fn end
TriggerServerEvent = function(name, payload) toServer[#toServer + 1] = { name = name, payload = payload } end
GetCurrentResourceName = function() return "op77_lightrp" end
GetResourceState = function() return "running" end
exports = { op77_map3d = {
    addBlip = function(_, def) mapAdds[#mapAdds + 1] = def; return def.id end,
    removeBlip = function(_, id) mapRemoves[#mapRemoves + 1] = id; return true end,
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
local config = { kind = "config", enabled = true, label = "Dogtown", blip = { position = { x = -1754.6, y = -2490.6, z = 40 },
    title = "Dogtown · PvP zone", description = "No law.", sprite = "Zzz13_DogtownGateVariant", fallbackSprite = "HazardWarningVariant", color = "#FF2E3C" } }
-- Config before the world: kept, nothing drawn yet.
net[NET](config)
assert(#created == 0 and #mapAdds == 0)
-- Into the world: the game map's gate sprite and the 3D map skull.
attached = true; tick()
assert(#created == 1 and created[1].sprite == "Zzz13_DogtownGateVariant" and created[1].routable == true and created[1].title == "Dogtown · PvP zone")
assert(#mapAdds == 1 and mapAdds[1].icon == "skull" and mapAdds[1].color == "#FF2E3C" and mapAdds[1].id == "lightrp.dogtown")
tick(); assert(#created == 1, "built once per entry")
-- A build without the gate sprite falls back to the hazard sign.
refuseSprite = "Zzz13_DogtownGateVariant"
net[NET](config)
assert(#removed == 1 and created[#created].sprite == "HazardWarningVariant" and logs[#logs]:find("refused", 1, true))
-- The zone switched off: the pins go away.
net[NET]({ kind = "config", enabled = false, label = "Dogtown", blip = config.blip })
assert(#removed == 2 and mapRemoves[#mapRemoves] == "lightrp.dogtown")
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
print("PASS: Dogtown client (config at start, gate sprite + hazard fallback, 3D map skull, switched off, district probe, border report)")
