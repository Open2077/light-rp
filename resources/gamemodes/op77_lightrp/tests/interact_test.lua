-- Run from the op77_lightrp directory with Lua 5.4: lua tests/interact_test.lua
dofile("shared/events.lua")
dofile("shared/config.lua")
local handlers, messages, logs = {}, {}, {}
local serverList, pressed, authoritativePosition
local now = 1000
RegisterNetEvent = function(name, fn) handlers[name] = fn end
local serverEvents = {}
AddEventHandler = function(name, fn) serverEvents[name] = fn end
TriggerClientEvent = function(_, _, list) serverList = list end
GetPlayers = function() return { 1 } end
Open77 = { players = { position = function() return authoritativePosition end } }
LightRP = {
    module = function(_, value) return value end,
    nowMs = function() return now end,
    eachModule = function(_, _, id) pressed = id end,
}
dofile("server/core/interact.lua")
local rental = LightRpConfig.rentals
local desk = rental.spots[1]
LightRP.interaction("rental." .. desk.id, {
    position = desk.position, radius = rental.interactRadius,
    marker = rental.marker, ring = false, blip = rental.blip,
    prompt = "Rent a vehicle", key = rental.key,
})
assert(#serverList == 1 and serverList[1].marker == rental.marker)
assert(serverList[1].ring == false and serverList[1].radius == rental.interactRadius)
local serverPress = handlers[LightRpEvents.net.interact]
source = 1
authoritativePosition = { x = 10000, y = 10000, z = 0 }
serverPress(serverList[1].id)
assert(pressed == nil, "a visual marker must not bypass server distance checks")
now = now + 1000
authoritativePosition = desk.position
serverPress(serverList[1].id)
assert(pressed == serverList[1].id)

local testBucket=0
GetPlayerRoutingBucket=function()return testBucket end
LightRP.batchInteractions(function()
    LightRP.interaction("housing.city",{position=desk.position,bucket=0})
    LightRP.interaction("housing.inside.one",{position=desk.position,bucket=1000001})
    LightRP.interaction("housing.inside.two",{position=desk.position,bucket=1000002})
end)
local function listed(id)for _,p in ipairs(serverList)do if p.id==id then return true end end;return false end
assert(listed("housing.city") and not listed("housing.inside.one"))
testBucket=1000001;LightRP.sendInteractions(1)
assert(listed("housing.inside.one") and not listed("housing.inside.two") and not listed("housing.city"),"only own bucket interior points are delivered")
testBucket=1000002;serverEvents.onPlayerBucketChange("1")
assert(listed("housing.inside.two") and not listed("housing.inside.one"),"a bucket change delivers the new bucket's points")
testBucket=0
for _,id in ipairs({"housing.city","housing.inside.one","housing.inside.two"})do LightRP.removeInteraction(id)end

local markers, anchors, blips = {}, {}, {}
local nextId, markerCreates, ringCreates = 0, 0, 0
local playerPosition = desk.position
local function api(store)
    return {
        create = function(options)
            nextId = nextId + 1
            local id = tostring(nextId)
            store[id] = options
            return id
        end,
        remove = function(id) assert(store[id]); store[id] = nil; return true end,
        update = function(id, patch)
            assert(store[id])
            for key, value in pairs(patch) do store[id][key] = value end
            return true
        end,
    }
end
Open77.markers, Open77.anchors, Open77.blips = api(markers), api(anchors), api(blips)
local nativeCreate, anchorCreate = Open77.markers.create, Open77.anchors.create
Open77.markers.create = function(options) markerCreates = markerCreates + 1; return nativeCreate(options) end
Open77.anchors.create = function(options)
    if options.render == "ring" then ringCreates = ringCreates + 1 end
    return anchorCreate(options)
end
Open77.character = { state = function() return { position = playerPosition } end }
LightRpUi = {
    page = {},
    log = function(format, ...) logs[#logs + 1] = string.format(format, ...) end,
    send = function(event, payload) messages[event] = payload end,
}
local proximity
CreateThread = function(fn) proximity = coroutine.create(fn) end
Wait = function() coroutine.yield() end
local lastPress
TriggerServerEvent = function(event, id) lastPress = { event, id } end
RegisterKeyMapping = function() return true, "E" end
local exported = {}
exports = function(name, fn) exported[name] = fn end
dofile("client/core/interact.lua")
assert(type(exported.InteractSetLocal) == "function", "InteractSetLocal export")
exports = nil -- the custom-icon cases below install their own exports table
local build = handlers[LightRpEvents.net.interactions]
build(serverList)
local point = LightRpInteract.points[1]
local marker = assert(markers[point.marker])
assert(marker.shape == "cylinder" and marker.height == rental.marker.height)
assert(marker.radius == rental.marker.radius and marker.color == rental.marker.color)
assert(marker.position.z == desk.position.z + rental.marker.groundOffset)
assert(desk.position.z == serverList[1].position.z, "do not move the interaction or map blip")
assert(marker.maxDistance == rental.marker.maxDistance and ringCreates == 0)
assert(blips[point.blip].position == desk.position)
assert(blips[point.blip].sprite == rental.blip.sprite, "keep the rental's configured vehicle icon")
assert(coroutine.resume(proximity)) -- first Wait
assert(coroutine.resume(proximity)) -- sample player position
assert(messages[LightRpEvents.page.interact].id == point.id)
assert(LightRpInteract.press() and lastPress[2] == point.id)
playerPosition = { x = desk.position.x + rental.interactRadius + 1, y = desk.position.y, z = desk.position.z }
assert(coroutine.resume(proximity))
assert(not LightRpInteract.press() and messages[LightRpEvents.page.interact].id == nil)
local createsBeforeTick = markerCreates
assert(coroutine.resume(proximity))
assert(markerCreates == createsBeforeTick, "persistent markers must not be recreated each tick")
local oldMarker, oldBlip = point.marker, point.blip
build(serverList)
assert(markers[oldMarker] == nil and blips[oldBlip] == nil, "rebuild removes old handles")
build({})
assert(next(markers) == nil and next(blips) == nil)

local markerApi = Open77.markers
playerPosition=desk.position
local passiveBlip=LightRpInteract.setLocal("tutorial.current",{
 position=desk.position,passive=true,prompt="Inspect the crate",blip={sprite="objective"}
},function()error("Alt objective must not accept E")end)
assert(passiveBlip and blips[passiveBlip],"Alt objective retains map navigation")
assert(coroutine.resume(proximity))
assert(not LightRpInteract.press() and messages[LightRpEvents.page.interact].id==nil,"Alt objective has no misleading E prompt")
LightRpInteract.setLocal("tutorial.current",nil)
assert(not blips[passiveBlip],"passive objective cleanup")
Open77.markers = nil
build(serverList)
assert(#LightRpInteract.points == 1 and ringCreates == 0, "old clients retain the interaction, not a fallback ring")
assert(logs[#logs - 1]:find("update the Open77 client", 1, true))
playerPosition = desk.position
assert(coroutine.resume(proximity))
assert(LightRpInteract.press())
Open77.markers = markerApi
Open77.markers.create = function() return nil, "marker_quota_exceeded" end
build(serverList)
assert(LightRpInteract.points[1].marker == nil and ringCreates == 0)
assert(logs[#logs - 1]:find("marker_quota_exceeded", 1, true))

build({ { id = "legacy", position = desk.position } })
assert(ringCreates == 1 and LightRpInteract.points[1].ring)
build({ { id = "hidden", position = desk.position, ring = false } })
assert(ringCreates == 1 and not LightRpInteract.points[1].ring)
build({})
assert(next(markers) == nil and next(blips) == nil)
-- Match the native resolver: reject unknown names instead of accepting every
-- sprite, which previously hid a bad food icon and its misleading car fallback.
dofile("server/config/shops.lua")
local blipCreate = Open77.blips.create
local attempts = {}
local accepted = { food = true, objective = true, [99] = true }
Open77.blips.create = function(options)
    attempts[#attempts + 1] = options.sprite
    if not accepted[options.sprite] then return nil, "unknown_sprite" end
    return blipCreate(options)
end
local function buildBlip(config)
    attempts = {}
    build({ { id = "vendor", position = desk.position, ring = false, blip = config } })
    return blips[LightRpInteract.points[1].blip]
end
local vendor = assert(buildBlip(LightRpShops.locations[1].blip))
assert(vendor.sprite == "food" and #attempts == 1, "food shop must resolve its native food icon immediately")
assert(buildBlip({ sprite = "unsupported_sprite" }).sprite == "objective")
assert(#attempts == 2 and attempts[1] == "unsupported_sprite" and attempts[2] == "objective",
    "unknown sprites fall back to a neutral icon, never a car")
assert(buildBlip({}).sprite == "objective" and #attempts == 1, "missing sprites must still get a neutral fallback")
assert(buildBlip({ sprite = 99 }).sprite == 99 and #attempts == 1, "numeric sprite IDs remain supported")
assert(buildBlip({ sprite = "objective" }).sprite == "objective" and #attempts == 1)
accepted.objective = nil
assert(buildBlip({ sprite = "objective" }) == nil and #attempts == 1, "do not retry the same failed fallback")
assert(buildBlip({ sprite = "unsupported_sprite" }) == nil and #attempts == 2)
build({})
assert(next(markers) == nil and next(blips) == nil, "blip rebuilds must clean up previous handles")
-- a job point: listed to and pressed by its job's players only
local myJob = "unemployed"
LightRP.jobs = { get = function() return { name = myJob } end }
LightRP.interaction("work.sanitation.bins", { position = desk.position, radius = 2, jobs = { "sanitation" }, prompt = "Work" })
local function listed(id) for _, e in ipairs(serverList) do if e.id == id then return true end end end
assert(not listed("work.sanitation.bins"), "no job, no point")
now = now + 1000; pressed = nil; authoritativePosition = desk.position; serverPress("work.sanitation.bins")
assert(pressed == nil, "a hidden point cannot be pressed")
myJob = "sanitation"; LightRP.sendInteractions(1); assert(listed("work.sanitation.bins"), "hired: the point shows")
now = now + 1000; serverPress("work.sanitation.bins"); assert(pressed == "work.sanitation.bins")
myJob = "unemployed"; LightRP.sendInteractions(1); assert(not listed("work.sanitation.bins"))
LightRP.removeInteraction("work.sanitation.bins"); LightRP.jobs = nil
print("PASS: rental 3D marker, interaction/range, cleanup, legacy points and food/neutral blip resolution, job-only points")

-- Service-owned custom blips must never be tracked/removed using LightRP's
-- native owner. Exercise public rebuilds and private objectives together.
local custom, customTracks, nativeTracks = {}, 0, 0
exports = { open77_icons = {} }
function exports.open77_icons:create(options)
    nextId = nextId + 1
    local id = tostring(nextId); custom[id] = options; return id
end
function exports.open77_icons:remove(id) assert(custom[id], "service ownership"); custom[id] = nil; return true end
function exports.open77_icons:track(id) assert(custom[id], "service GPS ownership"); customTracks = customTracks + 1; return true end
Open77.blips.track = function(id) assert(blips[id]); nativeTracks = nativeTracks + 1; return true end
local fuel = {x=10,y=20,z=30}
build({ { id="fuel.one", position=desk.position, ring=false,
    blip={icon="fuel",position=fuel,title="Fuel station",routable=true} } })
local fuelId=LightRpInteract.points[1].blip
assert(custom[fuelId].icon=="fuel" and custom[fuelId].color=="#FFCC00" and custom[fuelId].size==40)
assert(custom[fuelId].position==fuel and custom[fuelId].routable, "preserve centred cluster position and GPS")
assert(LightRpInteract.trackBlip(fuelId) and customTracks==1 and nativeTracks==0)
local workId=LightRpInteract.setLocal("job.current", {position=desk.position,
    blip={icon="trash-2",size=48,color="#11FF88",routable=true,title="Work order"}})
assert(custom[workId].size==48 and custom[workId].color=="#11FF88")
build({})
assert(not custom[fuelId] and custom[workId], "public refresh preserves private objective")
assert(LightRpInteract.trackBlip(workId) and customTracks==2)
LightRpInteract.setLocal("job.current",nil)
assert(next(custom)==nil, "private removal uses the service owner")
build({{id="unknown.category",position=desk.position,ring=false,blip={}}})
assert(custom[LightRpInteract.points[1].blip].icon=="map-pin", "new generic points still use custom geometry")
build({})
accepted.objective=true
function exports.open77_icons:create() return nil,"svg_client_required" end
build({{id="fallback",position=desk.position,ring=false,blip={icon="fuel",sprite="objective",routable=true}}})
local fallback=LightRpInteract.points[1].blip
assert(blips[fallback] and blips[fallback].icon==nil and blips[fallback].routable)
assert(LightRpInteract.trackBlip(fallback) and nativeTracks==1)
build({})
function exports.open77_icons:create() error("resource stopped") end
build({{id="stopped",position=desk.position,ring=false,blip={icon="fuel"}}})
assert(blips[LightRpInteract.points[1].blip], "stopped provider cannot break interaction creation")
build({})
assert(next(custom)==nil and next(blips)==nil)
print("PASS: custom icon options, grouped position, service GPS/cleanup ownership, private objectives, old-client/provider fallback")

-- The 3D city map (op77_map3d) mirrors every point that has a blip, when it runs.
local mapBlips, mapState = {}, "running"
GetResourceState = function(name) assert(name == "op77_map3d"); return mapState end
GetCurrentResourceName = function() return "op77_lightrp" end
function exports.open77_icons:create() return nil, "svg_client_required" end
exports.op77_map3d = {}
function exports.op77_map3d:addBlip(def) mapBlips["op77_lightrp:" .. def.id] = def; return "op77_lightrp:" .. def.id end
function exports.op77_map3d:removeBlip(id) assert(mapBlips[id], "removes only what it added"); mapBlips[id] = nil; return true end
dofile("client/core/map_icons.lua")
build({
    { id = "shop.gunstore_2", position = desk.position, ring = false, blip = { icon = "crosshair", sprite = "guns", color = "#FFCC00",
        title = "Rapid Fire", map = "smg", mapCategory = "weapons", mapColor = "#FF7A1A" } },
    { id = "home.unit1", position = desk.position, ring = false, blip = { icon = "house", color = "#FFCC00B3", title = "Home" } },
    { id = "mission.raid", position = desk.position, ring = false, blip = { sprite = "objective", title = "Raid" } },
    { id = "shop.247", position = desk.position, ring = false, blip = { icon = "shopping-basket", title = "24/7" } },
    { id = "talk", position = desk.position, ring = false },
})
local home, mission, shop = mapBlips["op77_lightrp:home.unit1"], mapBlips["op77_lightrp:mission.raid"], mapBlips["op77_lightrp:shop.247"]
assert(home and home.icon == "home" and home.category == "housing" and home.color == "#FFCC00" and home.label == "Home")
assert(mission and mission.icon == "mission" and mission.category == "mission")
assert(shop and shop.icon == "store" and shop.category == "service")
-- a gun store draws its weapon family, in its own category and colour (the map only)
local guns = mapBlips["op77_lightrp:shop.gunstore_2"]
assert(guns and guns.icon == LightRpMapIcons.smg and guns.icon:sub(1, 4) == "<svg" and #guns.icon < 16384, "drawn SMG icon")
assert(guns.category == "weapons" and guns.color == "#FF7A1A" and guns.label == "Rapid Fire")
for _, name in ipairs({ "pistol", "smg", "shotgun", "rifle", "sniper" }) do
    local svg = LightRpMapIcons[name]
    assert(svg and svg:find('viewBox="0 0 24 24"', 1, true) and svg:find("currentColor", 1, true), name .. " icon")
end
assert(mapBlips["op77_lightrp:talk"] == nil, "a point without a blip stays off the map")
mapBlips = {}
serverEvents["op77_map3d:ready"]()
assert(mapBlips["op77_lightrp:home.unit1"] and mapBlips["op77_lightrp:shop.247"], "a (re)started map gets every point again")
LightRpInteract.setLocal("job.current", { position = desk.position, prompt = "Drop the parcel", blip = { icon = "package", title = "Work order" } })
assert(mapBlips["op77_lightrp:job.current"].category == "job" and mapBlips["op77_lightrp:job.current"].pulse)
LightRpInteract.setLocal("job.current", nil)
assert(mapBlips["op77_lightrp:job.current"] == nil, "a finished objective leaves the map")
build({})
assert(next(mapBlips) == nil, "a new list replaces the old points on the map")
mapState = "stopped"
build({ { id = "shop.247", position = desk.position, ring = false, blip = { icon = "shopping-basket" } } })
assert(#LightRpInteract.points == 1, "no map running: interactions still work")
build({})
print("PASS: op77_map3d mirror (icons, drawn gun-store icons, categories, colour, re-sync on ready, private objectives, cleanup, map stopped)")
