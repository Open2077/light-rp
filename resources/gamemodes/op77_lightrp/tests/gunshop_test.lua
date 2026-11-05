-- The gun store: real shops + inventory + economy + armament serial registry,
-- with a deterministic SQL boundary. A bought firearm must arrive with its server
-- serial, registered in the SAME transaction as the payment and the delivery.
-- No live game, money, NPC or database is touched.
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/events.lua")
dofile("shared/armament.lua")
local noop = function() end
local threads, actions, messages, points, encoded = {}, {}, {}, {}, {}
local tick, failDb, uuid = 1000, false, 0
local databaseWallet = { account_number = "AAA-BBB", owner_name = "Test", cash = 2000, bank = 5000 }
local serials, lastQueries, npcDefinition, lastDialog = {}, nil, nil, nil
gunsmiths = {}
json = { encode = function(value) local key = "json" .. tostring(#encoded + 1); encoded[#encoded + 1] = value; encoded[key] = value; return key end,
    decode = function(key) return encoded[key] end }
local function find(queries, text) local n = 0; for _, q in ipairs(queries) do if q.query:find(text, 1, true) then n = n + 1 end end; return n end
local db = { ready = true, schema = noop, query = function() return {} end, run = function() return true, 1 end,
    read = function(query, values)
        if query:find("SELECT account_number, owner_name", 1, true) then return true, { databaseWallet } end
        if query:find("SELECT UUID", 1, true) then uuid = uuid + 1; return true, { { id = string.format("serial-%08d", uuid) } } end
        if query:find("FROM lightrp_weapon_instances", 1, true) then
            local row = serials[values[1]]
            return true, row and { { inventory_id = row.inventory_id, item_name = row.item_name, retired = row.retired } } or {}
        end
        return true, {}
    end,
    single = function(query) if query:find("SELECT account_number, owner_name", 1, true) then return databaseWallet end end,
    transaction = function(queries)
        if queries[1].query:find("lightrp_cash_migrations", 1, true) then databaseWallet.cash = 0; return true end
        lastQueries = queries
        if failDb then return false, "database_error" end
        -- the serial rows commit with everything else, or not at all
        local staged = {}; for k, v in pairs(serials) do staged[k] = v end
        local affected = 0
        for _, q in ipairs(queries) do
            if q.query:find("INSERT INTO lightrp_weapon_instances ", 1, true) then
                assert(not staged[q.values[1]], "a serial is minted once")
                staged[q.values[1]] = { inventory_id = q.values[2], item_name = q.values[3], retired = 0 }; affected = 1
            elseif q.query:find("UPDATE lightrp_weapon_instances", 1, true) then
                local row = staged[q.values[3]]
                affected = row and row.inventory_id == q.values[4] and row.retired == 0 and 1 or 0
                if affected == 1 then staged[q.values[3]] = { inventory_id = q.values[1], item_name = row.item_name, retired = q.values[2] } end
            elseif q.query:find("INSERT INTO lightrp_weapon_instance_audit", 1, true) then
                if affected ~= 1 then return false, "owner_conflict" end
            end
        end
        serials = staged
        return true
    end,
}
LightRP = { db = db, module = function(name, value) LightRP[name] = LightRP[name] or value; return LightRP[name] end,
    command = noop, log = noop, state = noop, stateProvider = noop, notice = noop, result = noop,
    eachModule = noop, nowMs = function() return tick end,
    characters = { switching = {}, get = function() return { identifier = "test", key = "default", status = "active" } end, displayName = function() return "Test" end },
    action = function(name, fn) actions[name] = fn end,
    interaction = function(id, def) points[id] = def end, removeInteraction = function(id) points[id] = nil end,
    nearInteraction = function() return true end,
    dialog = function(_, kind, payload) assert(kind == "shop"); lastDialog = payload end,
}
Open77 = {
    players = { position = function() return { x = 0, y = 0, z = 0, bucket = 0 } end,
        getLifeState = function() return { phase = "alive" } end, positions = function() return {} end },
    vehicles = {}, npcs = { create = function(def) if def.record == "Character.std_rcr_gunsmith_01" then gunsmiths[#gunsmiths + 1] = def; npcDefinition = gunsmiths[1] end; return 42 + #gunsmiths end,
        setAIEnabled = noop, ai = { tasks = 1 }, damage = { invulnerable = 2 } },
}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
GetPlayers = function() return { 1 } end
GetPlayerName = function() return "Test" end
AddEventHandler = noop
TriggerClientEvent = function(event, id, payload) messages[#messages + 1] = { event = event, id = id, payload = payload } end
dofile("server/modules/inventory.lua")
dofile("server/modules/economy.lua")
local Money, Inv = LightRP.money, LightRP.inventory
Inv.onCharacterLoaded(1, LightRP.characters.get(1))
Money.onCharacterLoaded(1, LightRP.characters.get(1))
dofile("server/modules/armament_store.lua")
dofile("server/config/shops.lua")
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
do local old = { weapon_lexington = 1200, weapon_unity = 1400, weapon_nue = 1800, weapon_overture = 2500, weapon_dr_5_nova = 2800,
        weapon_ds1_pulsar = 2600, weapon_m221_saratoga = 3000, weapon_tki_20_shingen = 4200,
        weapon_crusher = 2800, weapon_m2038_tactician = 3400, weapon_carnage = 3900, weapon_l_69_zhuo = 4600,
        weapon_d5_copperhead = 4200, weapon_m251s_ajax = 4800, weapon_kyubi = 5200, weapon_hjsh_18_masamune = 5600,
        weapon_d5_sidewinder = 6400, weapon_m2067_defender = 8500, weapon_kolac = 5200, weapon_m_179e_achilles = 6800,
        weapon_spt32_grad = 8500, weapon_nekomata = 10500,
        ammo_pistol_box = { 75, 20 }, ammo_shotgun_box = { 90, 22 }, ammo_rifle_box = { 110, 27 }, ammo_sniper_box = { 150, 37 } }
    for _, t in pairs(LightRpShops.templates) do for _, item in ipairs(t.items or {}) do
        local o = old[item.name]
        if type(o) == "table" then item.buy, item.sell = o[1], o[2] elseif o then item.buy = o end
    end end end
local start = #threads + 1
dofile("server/modules/shops.lua")
threads[start]()
local Shops = LightRP.shops

-- the vendor, exactly where it was asked for, with the native gun-store blip
assert(npcDefinition and npcDefinition.position.x == -907.380127 and npcDefinition.position.y == -708.114380
    and npcDefinition.position.z == 8.237724 and npcDefinition.yaw == -32.427353, "gun store vendor pose")
local point = assert(points["shop.gunstore_1"], "gun store interaction")
assert(point.blip.sprite == "guns" and point.blip.icon == "crosshair" and point.label == "Gun Store")

-- five stores, one weapon family each, every listed item a real template
local STORES = {
    { id = "gunstore_1", label = "Night City Arms", items = 6, x = -907.380127, yaw = -32.427353, family = { pistol = true, revolver = true }, ammo = "ammo_pistol_box" },
    { id = "gunstore_2", label = "Rapid Fire", items = 4, x = -1450.029297, yaw = 176.755157, family = { smg = true }, ammo = "ammo_pistol_box" },
    { id = "gunstore_3", label = "Twelve Gauge", items = 5, x = -455.554413, yaw = -133.095093, family = { shotgun = true }, ammo = "ammo_shotgun_box" },
    { id = "gunstore_4", label = "Frontline Surplus", items = 7, x = -1773.528687, yaw = -126.174515, family = { rifle = true, lmg = true }, ammo = "ammo_rifle_box" },
    { id = "gunstore_5", label = "Long Shot", items = 6, x = 1675.635498, yaw = -8.282229, family = { precision = true, sniper = true }, ammo = "ammo_sniper_box" },
}
assert(#gunsmiths == #STORES, "one gunsmith per store")
for i, store in ipairs(STORES) do
    assert(gunsmiths[i].position.x == store.x and gunsmiths[i].yaw == store.yaw, store.id .. " pose")
    assert(points["shop." .. store.id] and points["shop." .. store.id].blip.sprite == "guns", store.id .. " blip")
    assert(Shops.open(1, store.id))
    assert(lastDialog.shop.label == store.label and #lastDialog.items == store.items, store.id .. " catalogue")
    local ammoSold = false
    for _, offer in ipairs(lastDialog.items) do
        local spec = LightRpArmament.weapons[offer.name]
        if spec then
            assert(store.family[spec.class], store.id .. " sells only its family: " .. offer.name)
            assert(not offer.sell, "never bought back: " .. offer.name)
            -- each store sells the ammunition its guns fire
            local fed = false
            for _, other in ipairs(lastDialog.items) do
                local box = LightRpArmament.boxes[other.name]
                if box and box.ammo == spec.ammo then fed = true end
            end
            assert(fed, store.id .. " sells ammunition for " .. offer.name)
        elseif offer.name == store.ammo then ammoSold = true end
    end
    assert(ammoSold, store.id .. " ammunition")
end
-- the native pools: SMGs fire handgun rounds, precision rifles rifle rounds (measured)
assert(LightRpArmament.weapons.weapon_m221_saratoga.ammo == "pistol" and LightRpArmament.weapons.weapon_kolac.ammo == "rifle")
assert(LightRpArmament.weapons.weapon_spt32_grad.ammo == "sniper" and LightRpArmament.weapons.weapon_crusher.ammo == "shotgun")
assert(LightRpArmament.weapons.weapon_overture.dual and not LightRpArmament.weapons.weapon_m221_saratoga.dual, "only handguns pair")

assert(Shops.open(1, "gunstore_1"))
local offered = {}; for _, o in ipairs(lastDialog.items) do offered[o.name] = o end
assert(offered.weapon_lexington.buy == 1200 and offered.weapon_nue.buy == 1800 and offered.weapon_overture.buy == 2500)
assert(not offered.weapon_lexington.sell and not offered.weapon_overture.sell, "firearms are never bought back")
assert(offered.ammo_pistol_box.buy == 75 and offered.ammo_pistol_box.sell == 20)
assert(offered.weapon_overture.label == "Malorian Arms Overture" and offered.weapon_overture.image == "img/items/weapon_overture.png")
assert(LightRpArmament.weapons.weapon_overture.ammo == "pistol", "the revolver feeds from the pistol stock")

local session, request, revision = lastDialog.session, 1, lastDialog.revision
local function checkout(mode, pay, lines)
    local ok, reason = Shops.checkout(1, { session = session, request = request, revision = revision, mode = mode, pay = pay, lines = lines })
    local response = messages[#messages].payload
    if response.state then request, revision = response.state.nextRequest, response.state.revision end
    return ok, reason
end
local inv, wallet = Inv.player(1), Money.get(1)
local function weapons(name)
    local list = {}
    for _, item in pairs(inv.items) do if item.name == name then list[#list + 1] = item end end
    return list
end

-- cash: one pistol, its serial minted and registered with the payment
local cash = wallet.cash
local ok, reason = checkout("buy", "cash", { { name = "weapon_lexington", count = 1 } })
assert(ok, "cash pistol purchase: " .. tostring(reason))
assert(wallet.cash == cash - 1200)
local lex = weapons("weapon_lexington")
assert(#lex == 1 and lex[1].count == 1 and type(lex[1].metadata) == "table", "delivered with metadata")
local serial = lex[1].metadata.instanceId
assert(serial and serials[serial] and serials[serial].inventory_id == inv.id and serials[serial].item_name == "weapon_lexington", "serial registered to the buyer")
assert(find(lastQueries, "lightrp_inventories") == 1 and find(lastQueries, "INSERT INTO lightrp_weapon_instances ") == 1
    and find(lastQueries, "lightrp_weapon_instance_audit") == 1 and find(lastQueries, "lightrp_transactions") == 1, "one transaction")
assert(LightRP.armament.serialOwners[serial] == inv.id, "owner cache updated after the commit")

-- bank: the revolver, plus two pistols in one basket, each with its own serial
local bank = wallet.bank
ok, reason = checkout("buy", "bank", { { name = "weapon_overture", count = 1 } })
assert(ok and wallet.bank == bank - 2500, "bank revolver purchase: " .. tostring(reason))
local rev = weapons("weapon_overture")
assert(#rev == 1 and serials[rev[1].metadata.instanceId].item_name == "weapon_overture")
ok, reason = checkout("buy", "bank", { { name = "weapon_nue", count = 2 } })
assert(not ok and reason == "insufficient_funds" and #weapons("weapon_nue") == 0)
databaseWallet.bank = nil
wallet.bank = wallet.bank + 5000
ok, reason = checkout("buy", "bank", { { name = "weapon_nue", count = 2 }, { name = "ammo_pistol_box", count = 3 } })
assert(ok, "basket with two pistols: " .. tostring(reason))
local nue = weapons("weapon_nue")
assert(#nue == 2 and nue[1].metadata.instanceId ~= nue[2].metadata.instanceId, "two serials")
assert(Inv.count(inv.id, "ammo_pistol_box") == 3)
for _, item in pairs(inv.items) do
    if item.name == "ammo_pistol_box" then assert(item.metadata == nil or next(item.metadata) == nil, "ammo stays a plain stack") end
end

-- a failed commit mints nothing, charges nothing, delivers nothing
local before, cashBefore, mintedBefore = inv.items, wallet.cash, uuid
local registered = 0; for _ in pairs(serials) do registered = registered + 1 end
failDb = true
ok, reason = checkout("buy", "cash", { { name = "weapon_lexington", count = 1 } })
failDb = false
local after = 0; for _ in pairs(serials) do after = after + 1 end
assert(not ok and inv.items == before and wallet.cash == cashBefore and after == registered, "SQL failure is atomic")

-- a rifle and its rounds at the surplus store
assert(Shops.open(1, "gunstore_4")); session, request, revision = lastDialog.session, 1, lastDialog.revision
wallet.bank = wallet.bank + 20000
ok, reason = checkout("buy", "bank", { { name = "weapon_m251s_ajax", count = 1 }, { name = "ammo_rifle_box", count = 2 } })
assert(ok, "rifle purchase: " .. tostring(reason))
local ajax = weapons("weapon_m251s_ajax")
assert(#ajax == 1 and serials[ajax[1].metadata.instanceId].item_name == "weapon_m251s_ajax" and Inv.count(inv.id, "ammo_rifle_box") == 2)
assert(Shops.open(1, "gunstore_1")); session, request, revision = lastDialog.session, 1, lastDialog.revision

-- the shop never takes a firearm back
ok, reason = checkout("sell", "cash", { { name = "weapon_lexington", count = 1 } })
assert(not ok and reason == "unavailable_item" and #weapons("weapon_lexington") == 1)
ok = checkout("sell", "cash", { { name = "ammo_pistol_box", count = 1 } })
assert(ok and Inv.count(inv.id, "ammo_pistol_box") == 2)

-- the bought firearms stay valid for every later inventory commit (no "no valid serial")
assert(Inv.addItem(inv.id, "water", 1), "inventory still commits after a firearm purchase")
local ok2, why = LightRP.armament.prepare({ { inv, Inv.draft(inv) } })
assert(ok2, "registered serials verify: " .. tostring(why))
print("PASS: gun stores (five stores, one weapon family each with its ammunition, vendor poses + guns blips, catalogue, cash/bank firearm purchases with serials in the same transaction, two serials per basket, plain ammo, atomic SQL failure, no firearm buy-back, later commits verify)")
