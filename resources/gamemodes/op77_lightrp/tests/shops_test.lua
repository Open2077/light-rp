-- Real shops + inventory + economy, with a deterministic SQL/native boundary.
-- No live game, money, NPC or database is touched.
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/events.lua")
local noop = function() end
local threads, actions, events, messages, points, encoded = {}, {}, {}, {}, {}, {}
local tick, failDb, yieldDb, transactions = 1000, false, false, 0
local near, alive, active, bucket = true, true, true, 0
local databaseWallet = { account_number = "AAA-BBB", owner_name = "Test", cash = 2000, bank = 5000 }
local lastDialog, npcDefinition, lastQueries
json = { encode = function(value) local key = "json" .. tostring(#encoded + 1); encoded[#encoded + 1] = value; encoded[key] = value; return key end, decode = function(key) return encoded[key] end }
local db = { ready = true, schema = noop, query = function() return {} end, run = function() return true, 1 end,
    read = function(query)
        if query:find("SELECT account_number, owner_name", 1, true) then return true, { databaseWallet } end
        return true, {}
    end,
    single = function(query)
        if query:find("SELECT account_number, owner_name", 1, true) then return databaseWallet end
    end,
    transaction = function(queries)
        if queries[1].query:find("lightrp_cash_migrations",1,true) then databaseWallet.cash=0; return true end
        transactions = transactions + 1; lastQueries = queries
        assert((#queries==2 or #queries==3) and queries[#queries-1].query:find("lightrp_inventories") and queries[#queries].query:find("lightrp_transactions"))
        assert(type(encoded[queries[#queries-1].values[6]]) == "table", "full inventory is staged")
        if yieldDb then coroutine.yield("sql") end
        if failDb then return false, "database_error" end
        return true
    end,
}
LightRP = { db = db, module = function(name, value) LightRP[name] = value; return value end,
    command = noop, log = noop, state = noop, stateProvider = noop, notice = noop, result = noop,
    eachModule = noop, nowMs = function() return tick end,
    characters = { switching = {}, get = function() return { identifier = "test", key = "default", status = active and "active" or "draft" } end, displayName = function() return "Test" end },
    action = function(name, fn) actions[name] = fn end,
    interaction = function(id, def) points[id] = def end, removeInteraction = function(id) points[id] = nil end,
    nearInteraction = function() return near end,
    dialog = function(_, kind, payload) assert(kind == "shop"); lastDialog = payload end,
}
Open77 = {
    players = { position = function() return { x = 0, y = 0, z = 0, bucket = bucket } end,
        getLifeState = function() return { phase = alive and "alive" or "dead" } end, positions = function() return {} end },
    vehicles = {}, npcs = { create = function(def) npcDefinition = def; return 42 end, setAIEnabled = noop, ai = { tasks = 1 }, damage = { invulnerable = 2 } },
}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
GetPlayers = function() return { 1 } end
GetPlayerName = function() return "Test" end
AddEventHandler = function(name, fn) events[name] = fn end
TriggerClientEvent = function(event, id, payload) messages[#messages + 1] = { event = event, id = id, payload = payload } end
dofile("server/modules/inventory.lua")
dofile("server/modules/economy.lua")
local Money, Inv = LightRP.money, LightRP.inventory
Inv.onCharacterLoaded(1, LightRP.characters.get(1))
Money.onCharacterLoaded(1, LightRP.characters.get(1))
dofile("server/config/shops.lua")
-- Another NPC references the SAME template. One live change must update both.
local second = {}; for k, v in pairs(LightRpShops.locations[1]) do second[k] = v end
second.id = "second_food"
-- the street market and its twin only: the gun store has its own test (gunshop_test.lua)
LightRpShops.locations = { LightRpShops.locations[1], second }
local start = #threads + 1
dofile("server/modules/shops.lua")
threads[start]()
local Shops = LightRP.shops
assert(npcDefinition.position.x == -667.559082 and npcDefinition.position.z == 9.193733 and npcDefinition.yaw == -125.597023)
assert(points["shop.citycenter_food"] and points["shop.second_food"])
assert(points["shop.citycenter_food"].blip.icon=="shopping-basket" and points["shop.second_food"].blip.icon=="shopping-basket")
assert(Shops.open(1, "citycenter_food"))
assert(lastDialog.kind == "shop" and #lastDialog.items == 15 and lastDialog.inventory.maxWeight > 0)
local session, request, revision = lastDialog.session, 1, lastDialog.revision
local function checkout(extra)
    local p = { session = session, request = request, revision = revision, mode = "buy", pay = "cash", lines = { { name = "water", count = 2 } } }
    for k, v in pairs(extra or {}) do p[k] = v end
    local ok, reason = Shops.checkout(1, p)
    local response = messages[#messages].payload
    if response.state then request, revision = response.state.nextRequest, response.state.revision end
    return ok, reason, response, p
end
local inv, wallet = Inv.player(1), Money.get(1)
local waterBefore = Inv.count(inv.id, "water")
local ok, reason, reply, sent = checkout({ price = 0, total = -900, target = 2 })
assert(ok and wallet.cash == 1984 and Inv.count(inv.id, "water") == waterBefore + 2, "server prices, source wallet, delivery")
assert(wallet.history[1].kind == "shop_buy" and lastQueries[#lastQueries].values[4] == -16)
local committed = transactions
assert(Shops.checkout(1, sent))
assert(transactions == committed and wallet.cash == 1984, "replayed request never charges twice")
ok = checkout({ mode = "sell", pay = "bank", lines = { { name = "water", count = 2 } } })
assert(ok and wallet.bank == 5004 and Inv.count(inv.id, "water") == waterBefore)

local cashBefore, inventoryBefore = wallet.cash, inv.items
failDb = true
ok, reason = checkout()
assert(not ok and reason == "database_error" and wallet.cash == cashBefore and inv.items == inventoryBefore, "SQL failure changes neither cache")
failDb = false
for _, override in ipairs({
    { lines = { { name = "water", count = -1 } } }, { lines = { { name = "water", count = 1.5 } } },
    { lines = { { name = "water", count = math.huge } } }, { lines = { { name = "water", count = 0 / 0 } } },
    { lines = { { name = "water", count = 21 } } }, { lines = {} }, { lines = "water" },
    { lines = { { name = "water", count = 1 }, { name = "water", count = 1 } } },
    { lines = { [2] = { name = "water", count = 1 } } }, { lines = { { name = "medkit", count = 1 } } },
    { mode = "steal" }, { pay = "crypto" },
}) do assert(not checkout(override), "malformed cart refused") end
assert(wallet.cash == cashBefore and Inv.count(inv.id, "water") == waterBefore)
local cashItem; for _, item in pairs(inv.items) do if item.name=="cash" then cashItem=item end end
cashItem.count = 1
ok, reason = checkout(); assert(not ok and reason == "insufficient_funds")
cashItem.count = cashBefore
local weight = inv.maxWeight; inv.maxWeight = Inv.weightOf(inv)
ok, reason = checkout(); assert(not ok and reason == "too_heavy"); inv.maxWeight = weight
local saved = inv.items; inv.items = {}; local slots = inv.slots; inv.slots = 1
inv.items[1] = { name = "phone", count = 1 }
ok, reason = checkout({pay="bank"}); assert(not ok and reason == "no_room")
inv.items = { [1] = { name = "water", count = 8, metadata = { label = "Special water" } } }
ok, reason = checkout({ mode = "sell" }); assert(not ok and reason == "not_enough", "custom metadata never sold")
inv.items, inv.slots = saved, slots

-- Live template edits refresh both NPCs and invalidate old quotes.
assert(Shops.setTemplate("street_food", { label = "Updated market", payments = { "cash", "bank" }, items = { { name = "water", buy = 9, sell = 3 } } }))
ok, reason = checkout(); assert(not ok and reason == "stale_catalogue")
assert(Shops.open(1, "second_food")); assert(lastDialog.items[1].buy == 9 and #lastDialog.items == 1 and lastDialog.shop.label == "Updated market")
session, request, revision = lastDialog.session, 1, lastDialog.revision
assert(not Shops.setTemplate("broken", { label = "Bad", items = { { name = "water", buy = 2, sell = 3 } } }))

-- While SQL yields, both the wallet and every mutation entry point are locked.
yieldDb = true
local co = coroutine.create(function() checkout() end)
assert(coroutine.resume(co)); assert(coroutine.status(co) == "suspended")
assert(inv.busy and wallet.busy and Shops.isBusy(1))
assert(not Inv.addItem(inv.id, "water", 1)); assert(not Inv.removeItem(inv.id, "water", 1))
assert(not Inv.use(1, 1)); assert(not Inv.drop(1, 1, 1)); assert(not Inv.move(1, inv.id, 1, inv.id, 2, 1)); assert(not Inv.give(1, 1, 1))
assert(not Money.removeCash(1, 1)); assert(not Shops.open(1, "citycenter_food"))
assert(coroutine.resume(co)); assert(coroutine.status(co) == "dead" and not inv.busy and not wallet.busy)
yieldDb = false

-- Whole basket: a bad second line must not deliver the first.
assert(Shops.setTemplate("street_food", LightRpShops.templates.street_food))
assert(Shops.open(1, "citycenter_food")); session, request, revision = lastDialog.session, 1, lastDialog.revision
local countBefore = Inv.count(inv.id, "water"); cashBefore = wallet.cash
inv.maxWeight = Inv.weightOf(inv) + 0.6
ok = checkout({ lines = { { name = "water", count = 1 }, { name = "burrito", count = 20 } } })
assert(not ok and Inv.count(inv.id, "water") == countBefore and wallet.cash == cashBefore)
inv.maxWeight = weight
near = false; assert(not checkout()); near = true
assert(not Shops.open(1, "missing"))
bucket = 1; assert(not Shops.open(1, "citycenter_food")); bucket = 0
alive = false; assert(not Shops.open(1, "citycenter_food")); alive = true
active = false; assert(not Shops.open(1, "citycenter_food")); active = true
db.ready = false
local realWallet = Money.get; Money.get = function() return nil end
local opened, why = Shops.open(1, "citycenter_food")
assert(not opened and why:find("database"), "an active character without a database-backed wallet gets the actual service error")
Money.get = realWallet; db.ready = true
LightRP.characters.switching[1] = true; assert(not Shops.open(1, "citycenter_food")); LightRP.characters.switching[1] = nil
assert(Shops.open(1, "citycenter_food")); session, request, revision = lastDialog.session, 1, lastDialog.revision
tick = tick + LightRpShops.sessionMs + 1; assert(not checkout(), "expired session refused")
assert(Shops.open(1, "citycenter_food")); session, request, revision = lastDialog.session, 1, lastDialog.revision
Shops.onDisconnected(1); assert(not checkout(), "disconnect clears session")
-- Disconnect in flight: never persist the pre-trade inventory over the commit.
assert(Shops.open(1, "citycenter_food")); session, request, revision = lastDialog.session, 1, lastDialog.revision
yieldDb = true
local detached = coroutine.create(function() checkout() end)
assert(coroutine.resume(detached)); assert(inv.busy and wallet.busy)
Shops.onDisconnected(1); Money.onDisconnected(1); Inv.onDisconnected(1)
assert(Inv.get(inv.id) == inv, "pending inventory must not be written or evicted yet")
assert(coroutine.resume(detached)); assert(coroutine.status(detached) == "dead")
assert(Inv.get(inv.id) == nil and not wallet.busy, "settled disconnected cache is released")
print("PASS: actual shop/inventory/economy; shared/live templates; exact NPC pose; atomic buy/sell/ledger; SQL rollback; replay; locks; limits/metadata/capacity; source/life/bucket/range/session guards")
