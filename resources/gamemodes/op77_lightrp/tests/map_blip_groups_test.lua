-- Exercise the real server point registration, without NPCs, DB or a game.
dofile("shared/config.lua")
local noop = function() end
local threads, points = {}, {}
Open77 = {}
LightRP = {
    db = { schema = noop }, vehicles = { byKey = {} },
    module = function(name, value) LightRP[name] = value; return value end,
    interaction = function(id, value) points[id] = value end,
    action = noop, command = noop, stateProvider = noop, log = noop,
}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop

-- A second desk proves new branches inherit the category without sharing a name.
local extra = {}
for key, value in pairs(LightRpConfig.rentals.spots[1]) do extra[key] = value end
extra.id, extra.name = "test_branch", "Rent-a-Ride // Test district"
table.insert(LightRpConfig.rentals.spots, extra)
dofile("server/modules/wardrobe.lua")
threads[1]()
local rentalStartup = #threads + 1
dofile("server/modules/rental.lua")
threads[rentalStartup]() -- never run the expiration loop

for _, category in ipairs({
    { config = LightRpConfig.wardrobes, prefix = "wardrobe.", title = "Wardrobe" },
    { config = LightRpConfig.rentals, prefix = "rental.", title = "Rent-a-Ride" },
}) do
    for _, spot in ipairs(category.config.spots) do
        local point = assert(points[category.prefix .. spot.id])
        assert(point.label == spot.name, "interaction keeps its branch name")
        assert(point.blip.title == category.title, "map title is shared by every branch")
        assert(point.blip.sprite == category.config.blip.sprite, "category icon is preserved")
        assert(point.blip.icon == category.config.blip.icon and point.blip.icon ~= nil, "custom SVG survives server serialization")
        assert(point.blip.description:find(spot.name, 1, true), "description identifies the branch")
        assert(point.position == spot.position, "map grouping cannot move the interaction")
    end
end
print("PASS: Wardrobe and Rent-a-Ride map categories, branch descriptions and unchanged interactions")
