-- Staff weapons (/admin > Weapons & ammo): the real inventory + the armament serial registry,
-- with a deterministic SQL boundary. A firearm given by staff must arrive with its server serial
-- (so the weapon wheel lists it) in the same transaction as its rounds; the wheel is refreshed
-- at once; ammunition lands as loose rounds of its type; an in-hand firearm is never taken.
-- No live game, money, NPC or database is touched.
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/events.lua")
dofile("shared/armament.lua")
local noop = function() end
local encoded, uuid, transactions = {}, 0, 0
local serials, notices, commands = {}, {}, {}
json = { encode = function(value) local key = "json" .. tostring(#encoded + 1); encoded[#encoded + 1] = value; encoded[key] = value; return key end,
    decode = function(key) return encoded[key] end }
local db = { ready = true, schema = noop, query = function() return {} end, run = function() return true, 1 end,
    read = function(query, values)
        if query:find("SELECT UUID", 1, true) then uuid = uuid + 1; return true, { { id = string.format("serial-%08d", uuid) } } end
        if query:find("FROM lightrp_weapon_instances", 1, true) then
            local row = serials[values[1]]
            return true, row and { { inventory_id = row.inventory_id, item_name = row.item_name, retired = row.retired } } or {}
        end
        return true, {}
    end,
    single = function() return nil end,
    transaction = function(queries)
        transactions = transactions + 1
        local staged = {}; for k, v in pairs(serials) do staged[k] = v end
        for _, q in ipairs(queries) do
            if q.query:find("INSERT INTO lightrp_weapon_instances ", 1, true) then
                staged[q.values[1]] = { inventory_id = q.values[2], item_name = q.values[3], retired = 0 }
            elseif q.query:find("UPDATE lightrp_weapon_instances", 1, true) then
                local row = staged[q.values[3]]
                if row then staged[q.values[3]] = { inventory_id = q.values[1], item_name = row.item_name, retired = q.values[2] } end
            end
        end
        serials = staged
        return true
    end,
}
LightRP = { db = db, module = function(name, value) LightRP[name] = LightRP[name] or value; return LightRP[name] end,
    command = function(name, _, fn) commands[name] = fn end, log = noop, state = noop, stateProvider = noop, result = noop,
    notice = function(id, n) notices[#notices + 1] = { id = id, n = n } end,
    eachModule = noop, nowMs = function() return 1000 end, action = noop, interaction = noop, removeInteraction = noop, dialog = noop,
    characters = { switching = {}, get = function() return { identifier = "test", key = "default", status = "active" } end, displayName = function() return "Kade" end },
}
Open77 = { players = { position = function() return { x = 0, y = 0, z = 0, bucket = 0 } end, getLifeState = function() return { phase = "alive" } end } }
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
GetPlayers = function() return { 2 } end
GetPlayerName = function(id) return (id == 2 or id == 1) and "Kade" or nil end
AddEventHandler = noop
TriggerClientEvent = noop
dofile("server/modules/inventory.lua")
local Inv = LightRP.inventory
Inv.onCharacterLoaded(2, LightRP.characters.get(2))
dofile("server/modules/armament_store.lua")
local W = LightRP.armament
-- armament.lua is not loaded: its wheel push and synchronization are observed
local pushes, syncs = {}, {}
W.push = function(id) pushes[#pushes + 1] = id end
W.synchronize = function(id, observe) syncs[#syncs + 1] = { id, observe } end
-- the wheel's list (armament.lua arsenal()): every serialized firearm, its rounds, its hand
W.view = function(id)
    local i, s, list = Inv.player(id), W.states[Inv.player(id).id] or {}, {}
    for _, item in pairs(i.items) do
        local spec = LightRpArmament.weapons[item.name]
        local serial = spec and type(item.metadata) == "table" and item.metadata.instanceId
        if serial then list[#list + 1] = { instanceId = serial, label = spec.label,
            rounds = Inv.count(i.id, LightRpArmament.ammo[spec.ammo].item), hand = s.right == serial and "right" or s.left == serial and "left" or nil } end
    end
    return { arsenal = list }
end
dofile("server/modules/armament_admin.lua")
local AW = LightRP.armamentAdmin
local inv = Inv.player(2)
local function count(name) return Inv.count(inv.id, name) end

-- names: the item id, the short name, the record, the label
assert(AW.weapon("weapon_lexington") == "weapon_lexington" and AW.weapon("lexington") == "weapon_lexington")
assert(AW.weapon("Items.Preset_Lexington_Default") == "weapon_lexington" and AW.weapon("Militech Lexington") == "weapon_lexington")
assert(AW.weapon("bazooka") == nil and AW.ammo("ammo_rifle") == "rifle" and AW.ammo("rifle") == "rifle")

-- a weapon with 60 rounds of its type: one transaction, a serial minted, the wheel refreshed
local before = transactions
local ok, text = commands["lightrp.giveweapon"](1, { "2", "lexington", "60" })
assert(ok == true and text:find("Militech Lexington", 1, true), tostring(text))
assert(transactions == before + 1, "weapon and rounds are one write")
assert(count("weapon_lexington") == 1 and count("ammo_pistol") == 60, "weapon and its rounds in the pockets")
local serial
for _, item in pairs(inv.items) do if item.name == "weapon_lexington" then serial = item.metadata and item.metadata.instanceId end end
assert(serial and serials[serial] and serials[serial].inventory_id == inv.id, "the firearm has its registered server serial")
assert(pushes[#pushes] == 2, "the weapon wheel is refreshed at once")
assert(notices[#notices].id == 2 and notices[#notices].n.body:find("weapon wheel", 1, true), "the player is told where it is")
local wheel = W.view(2).arsenal
assert(#wheel == 1 and wheel[1].instanceId == serial and wheel[1].rounds == 60, "the wheel lists it with its rounds")

-- a second one of the same model: its own serial; a rifle with no rounds
assert(commands["lightrp.giveweapon"](1, { "2", "weapon_lexington" }) == true)
assert(commands["lightrp.giveweapon"](1, { "2", "Items.Preset_Ajax_Default", "0" }) == true)
assert(count("weapon_lexington") == 2 and count("weapon_m251s_ajax") == 1 and count("ammo_rifle") == 0)
assert(#W.view(2).arsenal == 3, "every given firearm is in the wheel")

-- ammunition: one type, every type; bounds
assert(commands["lightrp.giveammo"](1, { "2", "rifle", "250" }) == true and count("ammo_rifle") == 250)
assert(commands["lightrp.giveammo"](1, { "2", "all", "30" }) == true)
assert(count("ammo_pistol") == 90 and count("ammo_rifle") == 280 and count("ammo_shotgun") == 30 and count("ammo_sniper") == 30)
assert(commands["lightrp.giveammo"](1, { "2", "rifle", "0" }) == false, "zero rounds refused")
assert(commands["lightrp.giveammo"](1, { "2", "rifle", "5000" }) == false, "too many rounds refused")
assert(commands["lightrp.giveammo"](1, { "2", "laser", "30" }) == false, "unknown type refused")
assert(commands["lightrp.giveweapon"](1, { "2", "bazooka" }) == false, "unknown weapon refused")
assert(commands["lightrp.giveweapon"](1, { "9", "lexington" }) == false, "unknown player refused")

-- a weapon in hand: rounds given load now (observe synchronization); it is never taken
W.states[inv.id] = W.states[inv.id] or { revision = 0, ammo = 0 }
W.states[inv.id].right = serial
W.runtime[2] = { player = 2, inventory = inv.id, ready = true, busy = false }
threads = {}
assert(commands["lightrp.giveammo"](1, { "2", "pistol", "30" }) == true)
for _, fn in ipairs(threads) do fn() end
assert(syncs[#syncs] and syncs[#syncs][1] == 2 and syncs[#syncs][2] == true, "a weapon in hand loads the new rounds now")
ok, text = commands["lightrp.takeweapon"](1, { "2", "lexington" })
assert(ok == true and count("weapon_lexington") == 1, "the Lexington NOT in hand is taken")
local kept = false
for _, item in pairs(inv.items) do if item.name == "weapon_lexington" and item.metadata.instanceId == serial then kept = true end end
assert(kept, "the one in hand stays")
ok, text = commands["lightrp.takeweapon"](1, { "2", "lexington" })
assert(ok == false and text:find("hand", 1, true), "only the one in hand left: refused")

-- the summary staff reads
ok, text = commands["lightrp.weapons"](1, { "2" })
assert(ok == true and text:find("Militech Lexington [right]", 1, true) and text:find("rifle 280", 1, true), tostring(text))

-- a full inventory: nothing is given, nothing refreshed
local pushed = #pushes
Inv.canHold = function() return false, "no_room" end
ok, text = commands["lightrp.giveweapon"](1, { "2", "lexington", "60" })
assert(ok == false and #pushes == pushed, "a refusal changes nothing: " .. tostring(text))
print("armament_admin_test: ok")
