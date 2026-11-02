-- Fitting rooms: a private bucket from shared places, the way back, homes left
-- alone, a wardrobe that never opened, and what counts as dressed.
dofile("shared/config.lua")
dofile("shared/events.lua")
local noop = function() end
local threads, points, netHandlers, events, timers = {}, {}, {}, {}, {}
local buckets, environment, opened, results, logs = {}, {}, {}, {}, {}
local life = "alive"
Open77 = {
    players = { getLifeState = function() return { phase = life } end },
    environment = {
        getState = function(bucket) return { hour = 22, minute = 5, second = 0, rate = 1, timeFrozen = false, weather = "24h_weather_rain", weatherFrozen = true, bucket = bucket } end,
        setTime = function(h, m, s, bucket) environment[bucket] = (environment[bucket] or 0) + 1; return true end,
        setTimeRate = function() return true end, setTimeFrozen = function() return true end,
        setWeather = function() return true end, setWeatherFrozen = function() return true end,
        clearBucket = function(bucket) environment[bucket] = nil end,
    },
}
LightRP = {
    characters = { get = function() return { status = "active" } end },
    module = function(name, value) LightRP[name] = value; return value end,
    interaction = function(id, value) points[id] = value end,
    action = noop, log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end,
    result = function(player, ok, text) results[#results + 1] = text end,
}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
SetTimeout = function(ms, fn) timers[#timers + 1] = fn end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
TriggerClientEvent = function(name, player) if name == "open77:wardrobe_ui:open" then opened[#opened + 1] = player end end
GetPlayerRoutingBucket = function(player) return buckets[player] or 0 end
SetPlayerRoutingBucket = function(player, bucket) buckets[player] = bucket; return true end
GetPlayersInBucket = function(bucket) local out = {} for p, b in pairs(buckets) do if b == bucket then out[#out + 1] = p end end return out end
GetCurrentResourceName = function() return "op77_lightrp" end

dofile("server/modules/wardrobe.lua")
threads[1]()
local W = LightRP.wardrobe
local C = LightRpConfig.wardrobes
local function client(player, visible) source = player; netHandlers[LightRpEvents.net.wardrobe](visible) end

-- The hall's fitting room: only in the hall, off the city map.
local hall = points["wardrobe.lobby_fitting"]
assert(hall and hall.bucket == 620000 and hall.blip == nil, "the hall's fitting room lives in the hall")
assert(points["wardrobe.citycenter"].blip ~= nil, "city wardrobes keep their map point")

-- In the city: a private bucket with the city's time and weather, back on closing.
W.onInteract(3, "wardrobe.citycenter")
assert(opened[1] == 3 and buckets[3] == C.privateBucketBase + 3 and W.inRoom(3), "the city changes in private")
assert(environment[C.privateBucketBase + 3], "the fitting room copies the world's time and weather")
client(3, true)
client(3, false)
assert(buckets[3] == 0 and not W.inRoom(3) and environment[C.privateBucketBase + 3] == nil, "closing returns to the city")

-- In the arrival hall: back to the hall, not to the city.
buckets[4] = 620000
W.onInteract(4, "wardrobe.lobby_fitting")
assert(buckets[4] == C.privateBucketBase + 4, "the hall changes in private too")
client(4, true); client(4, false)
assert(buckets[4] == 620000, "closing returns to the hall")

-- At home (any other bucket): private already, nothing moves.
buckets[5] = 1000042
assert(W.open(5, true) and buckets[5] == 1000042 and not W.inRoom(5), "a home's wardrobe opens in place")

-- The client never opened it (in a vehicle, loading): the timer brings the player back.
local before = #timers
W.onInteract(6, "wardrobe.citycenter")
assert(buckets[6] == C.privateBucketBase + 6 and #timers == before + 1)
timers[#timers]()
assert(buckets[6] == 0 and not W.inRoom(6), "a wardrobe that never opened does not strand the player")
-- Opened in time: the timer leaves the player where they are.
W.onInteract(7, "wardrobe.citycenter"); client(7, true); timers[#timers]()
assert(W.inRoom(7) and buckets[7] == C.privateBucketBase + 7, "an open fitting room stays")

-- Moved away meanwhile (an admin, a teleport): only our own room is undone.
buckets[7] = 0; W.onInteract(8, "wardrobe.citycenter"); buckets[8] = 555
client(8, false)
assert(buckets[8] == 555, "a player moved elsewhere is not pulled back")

-- Someone else in the private bucket (should never happen): refused, nobody moves.
buckets[9], buckets[99] = 0, C.privateBucketBase + 9
W.onInteract(9, "wardrobe.citycenter")
assert(buckets[9] == 0 and results[#results]:find("not ready"), "an occupied fitting room is refused")
buckets[99] = nil

-- Disconnects and character switches clear the room.
W.onInteract(10, "wardrobe.citycenter"); W.onDisconnected(10)
assert(not W.inRoom(10), "a disconnect forgets the room")
W.onInteract(11, "wardrobe.citycenter"); W.onCharacterLoaded(11)
assert(buckets[11] == 0 and not W.inRoom(11), "a character switch returns the player")

-- Not alive: refused before any move.
life = "dead"; W.onInteract(12, "wardrobe.citycenter"); life = "alive"
assert(buckets[12] == nil and not W.inRoom(12), "the dead do not change")

-- Dressed: a top and a bottom, from the equipment or the active saved outfit.
local function shown(equipment, active, outfit) return { equipment = equipment, wardrobe = { active = active, outfits = { ["1"] = outfit or {} } } } end
assert(not W.dressed(shown({ UnderwearBottom = "x", InnerChest = false, Legs = false })), "underwear is not dressed")
assert(not W.dressed(shown({ InnerChest = "shirt" })), "a top alone is not dressed")
assert(W.dressed(shown({ InnerChest = "shirt", Legs = "jeans" })), "a top and trousers")
assert(W.dressed(shown({ Outfit = "suit" })), "a full outfit")
assert(W.dressed(shown({}, 1, { OuterChest = "jacket", Legs = "pants" })), "the active saved outfit counts")
assert(not W.dressed(shown({ InnerChest = "shirt", Legs = "jeans" }, 1, { InnerChest = false, Legs = false })), "an active outfit hiding them does not")

-- A saved look reaches the first day's guide.
local seen
LightRP.tutorial = { onDressed = function(player, dressed) seen = { player, dressed } end }
events["open77:presentation:committed"](13, shown({ InnerChest = "shirt", Legs = "jeans" }))
assert(seen and seen[1] == 13 and seen[2] == true, "the guide hears of the saved look")

print("PASS: private fitting rooms from the city and the hall, homes in place, stuck/moved/occupied/disconnect cases, dressed rule, guide relay")
