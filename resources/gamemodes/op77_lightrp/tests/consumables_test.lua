-- Standalone authoritative consumption regression tests (real inventory module).
dofile("shared/events.lua"); dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/consumables.lua")
local noop = function() end
local time, food, drink, alive, connected, animation, failPlay = 10000, 0, 0, true, true, nil, false
local position = { x = 0, y = 0, z = 0, bucket = 0 }
local events, hooks, threads, messages, stops = {}, {}, {}, {}, {}
json = { encode = function() return "{}" end }
Open77 = { players = {
    getLifeState = function() return { phase = alive and "alive" or "dead" } end,
    position = function() return { x = position.x, y = position.y, z = position.z, bucket = position.bucket } end,
}, animations = {
    current = function() return animation end,
    play = function(_, profile, options)
        if failPlay then return nil, "vehicle" end
        animation = { active = true, playbackId = "play:" .. time, profile = profile, clip = options.clip }
        return animation
    end,
    stop = function(_, id) stops[#stops + 1] = id; if animation and animation.playbackId == id then animation = nil end end,
} }
LightRP = {
    db = { schema = noop, ready = false }, command = noop, action = noop, log = noop, notice = noop, eachModule = noop,
    nowMs = function() return time end,
    characters = { displayName = function() return "Test Character" end },
    needs = { get = function() return { food = food, drink = drink } end,
        set = function(_, f, d) food, drink = f, d end },
    module = function(name, value) LightRP[name] = value; return value end,
}
GetPlayerName = function() return connected and "Test" or nil end
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerClientEvent = function(event, player, data) messages[#messages + 1] = { event = event, player = player, data = data } end
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) hooks[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = coroutine.yield
dofile("server/modules/inventory.lua"); dofile("server/modules/consumables.lua")
local Inv, C, E = LightRP.inventory, LightRP.consumables, LightRpEvents.net
local char = { status = "active", identifier = "consume-test", key = "default" }
Inv.onCharacterActivated(1, char)
local inv = Inv.player(1)
local function send(event, data, player) source = player or 1; events[event](data) end
local function setup(name)
    C.cancel(1); connected, alive, failPlay, animation = true, true, false, nil
    position = { x = 0, y = 0, z = 0, bucket = 0 }
    food, drink, time = 0, 0, time + 20000
    inv.items = { [1] = { name = name or "water", count = 3 } }
end
local function start()
    assert(Inv.use(1, 1)); local a = messages[#messages].data
    assert(a.phase == "prepare" and inv.items[1].count == 3 and drink == 0)
    send(E.consumeReady, { token = a.token })
    return a.token
end
local function complete(token, delay)
    time = time + (delay or 20000)
    send(E.consumeFinish, { token = token, status = "success" })
end
setup(); local token = start()
assert(animation.profile == "bottle" and animation.clip:find("drink"))
assert(not Inv.use(1, 1), "double use refused")
send(E.consumeFinish, { token = token, status = "success" }, 2)
assert(inv.items[1].count == 3 and C.isActive(1), "another player cannot spend this ticket")
complete(token, 6500)
assert(inv.items[1].count == 2 and drink == 30 and not animation and not C.isActive(1))
complete(token, 1); assert(inv.items[1].count == 2 and drink == 30, "replay grants nothing")
setup(); token = start(); complete(token, 500)
assert(inv.items[1].count == 3 and drink == 0 and not C.isActive(1), "early finish keeps item")
setup(); token = start(); send(E.consumeFinish, { token = token, status = "cancelled" })
assert(inv.items[1].count == 3 and drink == 0 and not animation)
setup(); token = start(); inv.items[1] = { name = "water", count = 3 }; complete(token, 6500)
assert(inv.items[1].count == 3 and drink == 0, "replaced stack cannot be spent")
for _, mutate in ipairs({
    function() alive = false end, function() position.x = 5 end,
    function() position.bucket = 2 end, function() connected = false end,
    function() animation = nil end, function() animation = { active = true, playbackId = "other" } end,
}) do
    setup(); token = start(); mutate(); complete(token, 6500)
    assert(inv.items[1].count == 3 and drink == 0 and not C.isActive(1), "invalid world state cannot consume")
    if animation then assert(animation.playbackId == "other", "stop must not cancel replacement playback") end
end
setup(); token = start(); C.onDisconnected(1); complete(token, 6500)
assert(inv.items[1].count == 3 and not animation)
setup(); token = start(); C.onCharacterLoaded(1); complete(token, 6500)
assert(inv.items[1].count == 3 and drink == 0)
setup(); token = start(); hooks["open77:playerDamaged"]("1", "2", "10"); complete(token, 6500)
assert(inv.items[1].count == 3 and drink == 0 and not animation, "authoritative damage cancels")
setup(); failPlay = true; token = start()
assert(not C.isActive(1) and inv.items[1].count == 3)
setup(); token = start(); inv.busy = true; complete(token, 6500); inv.busy = nil
assert(inv.items[1].count == 3 and drink == 0, "inventory lock held by checkout refuses commit")
setup(); token = start(); hooks.onResourceStop("op77_lightrp")
assert(not C.isActive(1) and not animation and inv.items[1].count == 3)
setup(); token = start(); complete(token, 60000)
assert(inv.items[1].count == 3 and drink == 0, "expired ticket refuses effects")
-- Every food/drink uses an actually installed profile/clip, not its shuffle idle.
dofile("../../system/open77_animations/shared/catalog.lua")
local profiles = {}; for _, p in ipairs(RpAnimationCatalog.profiles) do profiles[p.id] = p end
local count = 0
for name, item in pairs(LightRpItems) do
    if item.category == "food" or item.category == "drink" then assert(item.consumeAction, name .. " must not be instant") end
    if item.consumeAction then
        local c = LightRpConsumableProfiles[item.consumeAction]
        local p = assert(profiles[c.profile]); local found = false
        for _, clip in ipairs(p.clips) do if clip == c.clip then found = true end end
        assert(found, c.clip)
        setup(name); token = start(); complete(token, c.durationMs)
        assert(inv.items[1].count == 2 and food == (item.use.food or 0) and drink == (item.use.drink or 0), name)
        count = count + 1
    end
end
assert(count == 16)
local currentCharacter = char
LightRP.characters.get = function() return currentCharacter end
setup(); token = start(); currentCharacter = { status = "active", key = "another" }; complete(token, 6500)
assert(inv.items[1].count == 3 and drink == 0, "character changes before inventory load must refuse effects")
print("PASS: 16 timed consumables, installed clips, server timing, replay/spam/ownership, movement/death/bucket, stack replacement, locks, cancellation and teardown")
