-- Run from the op77_lightrp directory with Lua 5.4: lua tests/interact_test.lua
dofile("shared/events.lua")
dofile("shared/config.lua")
local handlers, messages, logs = {}, {}, {}
local serverList, pressed, authoritativePosition
local now = 1000
RegisterNetEvent = function(name, fn) handlers[name] = fn end
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
dofile("client/core/interact.lua")
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
print("PASS: rental 3D marker, server payload/range, prompt/E, cleanup, missing API, failure and legacy points")
