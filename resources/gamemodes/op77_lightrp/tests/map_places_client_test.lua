-- client/core/map_places.lua: the game's bars and clubs on the maps only.
dofile("shared/config.lua")
local threads, events, created, removed, mapAdds, logs = {}, {}, {}, {}, {}, {}
local attached = false
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) events[name] = fn end
GetCurrentResourceName = function() return "op77_lightrp" end
GetResourceState = function(name) assert(name == "op77_map3d"); return "running" end
exports = { op77_map3d = { addBlip = function(_, def) mapAdds[#mapAdds + 1] = def; return "op77_lightrp:" .. def.id end } }
Open77 = {
    character = { state = function() return { attached = attached } end },
    blips = { create = function(def) created[#created + 1] = def; return #created end, remove = function(id) removed[#removed + 1] = id; return true end },
}
LightRpUi = { log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end }
dofile("client/core/map_icons.lua")
dofile("client/core/map_places.lua")
local places = LightRpConfig.mapPlaces.places
assert(#places >= 10, "the bars and clubs are configured")
local loop = threads[1]
local function tick() assert(coroutine.resume(loop)) end

-- not in the world: nothing
tick(); tick()
assert(#created == 0 and #mapAdds == 0)
-- into the world: built in slices of 6 (a yield between slices)
attached = true
tick()
assert(#created == 6, "first slice: " .. #created)
for _ = 1, math.ceil(#places / 6) do tick() end -- a slice that ends on the last place yields once more before the log
assert(#created == #places and #mapAdds == #places and logs[#logs]:find(#places .. " map place", 1, true), "every place")
local byTitle = {}
local ripperdocs = 0
for _, b in ipairs(created) do
    if b.sprite == "ripperdoc" then ripperdocs = ripperdocs + 1 else byTitle[b.title] = b; assert(b.sprite == "bar") end
    assert(b.routable == true and b.active == true)
end
assert(ripperdocs == 14, "the game's 14 ripperdocs: " .. ripperdocs)
assert(byTitle.Afterlife and byTitle.Afterlife.description:find("Drinks", 1, true), "a named venue keeps its name")
assert(byTitle.Bar and byTitle.Bar.description:find("Bar // ", 1, true), "a numbered bar shows its kind, the branch in the description")
assert(byTitle.Clouds and byTitle.Clouds.description:find("club", 1, true), "the club")
local pins = {}
for _, pin in ipairs(mapAdds) do pins[pin.id] = pin end
local pin = pins["place.bar_188"]
assert(pin and pin.category == "nightlife" and pin.color == "#FF3FB4" and pin.icon:sub(1, 4) == "<svg", "3D map pin")
local doc = pins["place.ripperdoc_164"]
assert(doc and doc.category == "service" and doc.icon:sub(1, 4) == "<svg" and doc.label:find("Ripperdoc // ", 1, true) and doc.description:find("operating chair", 1, true), "a clinic's 3D map pin")
-- staying in the world: no rebuild
tick(); tick(); assert(#created == #places, "built once per entry")
-- out of the world and back: the blips are rebuilt (the old handles removed first)
attached = false; tick()
attached = true; tick(); for _ = 1, math.ceil(#places / 6) + 1 do tick() end
assert(#created == 2 * #places and #removed == #places, "rebuilt on re-entry")
-- a restarted 3D map gets the pins again
local before = #mapAdds
events["op77_map3d:ready"]()
local resend = threads[#threads]
while coroutine.status(resend) ~= "dead" do assert(coroutine.resume(resend)) end
assert(#mapAdds == before + #places, "map pins resent")
print("PASS: map places (bars, clubs and ripperdocs: native sprites, routable, named venues, 3D map pins, slices, rebuilt on world entry, map restart)")
