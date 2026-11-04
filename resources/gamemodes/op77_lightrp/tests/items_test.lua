-- Run from the resource directory. No database, network or game is used.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("shared/items.lua")
local noop = function() end
local alive, food, drink, health = true, 0, 0, 10
json = { encode = function() return "{}" end }
Open77 = { players = {
    getLifeState = function() return { phase = alive and "alive" or "dead" } end,
    heal = function(_, amount) health = math.min(100, health + amount); return true end,
} }
LightRP = {
    db = { schema = noop, ready = false }, command = noop, action = noop, log = noop, notice = noop, eachModule = noop,
    characters = { displayName = function() return "Test Character" end },
    needs = { get = function() return { food = food, drink = drink } end,
        set = function(_, f, d) food = math.min(100, f); drink = math.min(100, d) end },
    module = function(name, value) LightRP[name] = value; return value end,
}
AddEventHandler, CreateThread = noop, noop
GetPlayerName = function() return "Test" end
TriggerClientEvent = noop
dofile("server/modules/inventory.lua")
local Inv = LightRP.inventory
local character = { status = "draft", identifier = "unit-test", key = "default" }
Inv.onCharacterLoaded(1, character)
assert(Inv.player(1) == nil, "draft characters do not receive starting items")
character.status = "active"
Inv.onCharacterActivated(1, character)
local inv = Inv.player(1)
assert(#Inv.snapshot(inv).items == 2, "only water and burritos are granted at creation")
assert(Inv.count(inv.id, "water") == 5 and Inv.count(inv.id, "burrito") == 5, "five of each starting item")
inv.items[1].count = 4
Inv.onCharacterLoaded(1, character)
assert(Inv.player(1) == inv and Inv.count(inv.id, "water") == 4 and Inv.count(inv.id, "burrito") == 5,
    "loading an existing inventory does not refill starting items")
local counts, total = { food = 0, drink = 0, medical = 0 }, 0
for name, t in pairs(LightRpItems) do
    total = total + 1
    assert(type(t.label) == "string" and #t.label > 0, name)
    assert(t.weight >= 0 and (t.weight > 0 or name == "cash") and t.stack >= 1 and t.stack % 1 == 0, name)
    if t.image then
        assert(t.image == "img/items/" .. name .. ".png", name)
        for _, base in ipairs({ "../../../ui/public/", "web/" }) do
            local file = assert(io.open(base .. t.image, "rb"), "missing asset: " .. base .. t.image)
            assert(file:read(8) == "\137PNG\13\10\26\10", name .. " must be a PNG")
            file:close()
        end
    end
    if t.use and counts[t.category] ~= nil then
        counts[t.category] = counts[t.category] + 1
        assert(t.use.consume == true, name)
        inv.items = {}
        assert(Inv.addItem(inv.id, name, 2))
        local item = Inv.snapshot(inv).items[1]
        assert(item.image == t.image and item.usable and item.stack == t.stack)
        assert(item.effects.food == t.use.food and item.effects.drink == t.use.drink and item.effects.health == t.use.health)
        food, drink, health = 0, 0, 10
        alive = false
        assert(not Inv.use(1, 1) and Inv.count(inv.id, name) == 2, "dead players cannot consume " .. name)
        alive = true
        assert(Inv.use(1, 1) and Inv.count(inv.id, name) == 1, name)
        assert(food == (t.use.food or 0) and drink == (t.use.drink or 0) and health == 10 + (t.use.health or 0), name)
        assert(Inv.use(1, 1) and Inv.count(inv.id, name) == 0, name)
        assert(not Inv.use(1, 1), "empty slots do not consume")
        inv.items = {}; assert(Inv.addItem(inv.id, name, t.stack + 1))
        assert(inv.items[1].count == t.stack and inv.items[2].count == 1, name .. " stack splitting")
    end
end
assert(total == 43 and counts.food == 9 and counts.drink == 6 and counts.medical == 3) -- 43 with the three Cyberpunk TCG sealed items
assert(LightRpItems.cash.weight == 0 and LightRpItems.cash.use == nil)
for _, base in ipairs({ "../../../ui/public/", "web/" }) do
    local file = assert(io.open(base .. LightRpItems.cash.image, "rb"))
    assert(file:read(8) == "\137PNG\13\10\26\10"); file:close()
end
inv.items = { [1] = { name = "water", count = 1, metadata = { image = "https://example.invalid/track.png", effects = { health = 999 } } } }
local snap = Inv.snapshot(inv).items[1]
assert(snap.image == LightRpItems.water.image and snap.effects.health == nil, "metadata cannot replace art or effects")
for _, name in ipairs({ "water", "soda", "burrito", "synthmeat", "apple", "candy", "bandage", "medkit", "phone", "idcard" }) do assert(LightRpItems[name]) end
inv.items = {}; assert(Inv.addItem(inv.id, "firstaid", 1))
for _, heal in ipairs({ function() return false, "rejected" end, function() error("unavailable") end, false }) do
    Open77.players.heal = heal
    local ok, reason = Inv.use(1, 1)
    assert(not ok and reason == "use_failed" and Inv.count(inv.id, "firstaid") == 1, "failed heals keep the item")
end
print("PASS: starting items granted once; 40 templates; packaged illustrations; zero-weight cash; effects, death checks, consumption, stacks and metadata isolation")
