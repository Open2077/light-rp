-- Isolated rental contract tests: no game, database or player money.
dofile("shared/config.lua")
local noop = function() end
local threads, actions, providers = {}, {}, {}
local near, alive, failSpawn, activeCharacter = true, true, false, true
local cash, bank, creates, removes, now = 250, 1500, 0, 0, 1000
local result, opened, spawned
local byKey = {}
for _, entry in ipairs(LightRpConfig.vehicles.catalog) do byKey[entry.key] = entry end
assert(byKey.semimaru.category == "Sport")
byKey.hella.image = "img/vehicles/catalogue.jpg"
-- The desk's stock is the test's own: the contract is checked against known keys and prices, whatever the live desk sells.
LightRpConfig.rentals.spots[1].stock = { { key = "maimai", price = 50 }, { key = "hella", price = 120, image = "img/vehicles/agency.jpg" },
    { key = "galena", price = 80 }, { key = "colby", price = 100 }, { key = "apollo", price = 60 } }
Open77 = {
    players = { getLifeState = function() return { phase = alive and "alive" or "dead" } end,
        position = function() return { bucket = 42 } end },
    vehicles = { create = function(definition) creates = creates + 1; spawned = definition; if failSpawn then return nil, "refused" end; return 77 end,
        remove = function(id) assert(id == 77); removes = removes + 1 end },
}
LightRP = {
    db = { schema = noop, ready = false }, command = noop, log = noop, notice = noop, state = noop, interaction = noop,
    module = function(name, value) LightRP[name] = value; return value end,
    action = function(name, fn) actions[name] = fn end,
    stateProvider = function(name, fn) providers[name] = fn end,
    result = function(_, ok, text, action) result = { ok = ok, text = text, action = action } end,
    dialog = function(_, kind, payload) opened = payload; assert(kind == "rental") end,
    nearInteraction = function() return near end, nowMs = function() return now end,
    characters = { get = function() return { status = activeCharacter and "active" or "draft", identifier = "test", key = "default" } end,
        displayName = function() return "Test" end },
    vehicles = { byKey = byKey }, keys = { give = noop, lock = noop },
    money = {
        get = function() return {} end, format = tostring, explain = tostring,
        removeCash = function(_, amount) if cash < amount then return false, "insufficient_funds" end; cash = cash - amount; return true end,
        removeBank = function(_, amount) if bank < amount then return false, "insufficient_funds" end; bank = bank - amount; return true end,
        addCash = function(_, amount) cash = cash + amount end,
        addBank = function(_, amount) bank = bank + amount end,
    },
}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
GetPlayerName = function() return "Test" end
dofile("server/modules/rental.lua")
threads[1]() -- create the desk, but never start the expiration loop
local Rental = LightRP.rental
Rental.onInteract(1, "rental.citycenter")
assert(#opened.spot.stock == 5 and opened.spot.durationMinutes == 60)
assert(opened.spot.stock[2].image == "img/vehicles/agency.jpg", "agency image overrides catalogue")
local ok, reason = Rental.rent(1, "wrong", "maimai", "cash")
assert(not ok and reason == "unknown_desk")
near = false
ok, reason = Rental.rent(1, "citycenter", "maimai", "cash")
assert(not ok and reason == "too_far" and creates == 0 and cash == 250)
near, alive = true, false
ok, reason = Rental.rent(1, "citycenter", "maimai", "cash")
assert(not ok and reason == "not_alive" and creates == 0)
alive, activeCharacter = true, false
ok, reason = Rental.rent(1, "citycenter", "maimai", "cash")
assert(not ok and reason == "no_character")
activeCharacter = true
ok, reason = Rental.rent(1, "citycenter", "caliburn", "cash")
assert(not ok and reason == "not_in_stock")
cash = 10
ok, reason = Rental.rent(1, "citycenter", "maimai", "cash")
assert(not ok and reason == "insufficient_funds" and creates == 0)
cash, failSpawn = 250, true
ok, reason = Rental.rent(1, "citycenter", "maimai", "cash")
assert(not ok and reason == "vehicle_refused" and cash == 250 and not Rental.get(1), "delivery failure refunds exactly")
failSpawn = false
actions["rental.rent"](1, { spot = "citycenter", key = "hella", pay = "bank", price = 0, durationMinutes = 999 })
assert(result.ok and bank == 1380 and cash == 250, "browser cannot override price")
assert(spawned.record == byKey.hella.record and spawned.bucket == 42)
local current = providers.rental(1).active
assert(current.image == "img/vehicles/agency.jpg" and current.remainingMs == 3600000 and current.paidWith == "bank")
assert(current.extendPrice == 60 and current.extendMinutes == 30 and current.extensionsLeft == 4 and current.warnMs == 600000,
    "an extension is priced pro rata: 120 per hour -> 60 for 30 min")
now = now + 5000
assert(providers.rental(1).active.remainingMs == 3595000)

-- Extending: +30 min for 60 (bank by default), at most maxExtensions, anywhere.
assert(actions["rental.extend"], "the desk's Extend button")
actions["rental.extend"](1, { pay = "bank" })
assert(result.ok and bank == 1320 and providers.rental(1).active.remainingMs == 3595000 + 1800000, "paid and extended")
actions["rental.extend"](1, { pay = "cash" })
assert(result.ok and cash == 190 and providers.rental(1).active.extensionsLeft == 2)
cash = 0
local before = providers.rental(1).active.remainingMs
actions["rental.extend"](1, { pay = "cash" })
assert(not result.ok and providers.rental(1).active.remainingMs == before, "no money, no time")
cash = 250
actions["rental.extend"](1, { pay = "bank" }); actions["rental.extend"](1, { pay = "bank" })
assert(result.ok and providers.rental(1).active.extensionsLeft == 0)
local bankBefore = bank
actions["rental.extend"](1, { pay = "bank" })
assert(not result.ok and result.text:find("cannot be extended") and bank == bankBefore, "at most maxExtensions")
local attempts, bankNow = creates, bank
ok, reason = Rental.rent(1, "citycenter", "maimai", "bank")
assert(not ok and reason == "already_renting" and bank == bankNow and creates == attempts)
actions["rental.return"](1)
assert(result.ok and removes == 1 and not Rental.get(1) and bank == bankNow, "return removes car without refund")
assert(not Rental.giveBack(1), "return is not repeated")
assert(Rental.rent(1, "citycenter", "maimai", "cash"))
Rental.onDisconnected(1)
assert(not Rental.get(1) and removes == 2)
print("PASS: rental images, stock, authoritative price/duration, extensions (pro rata, bank/cash, max 4), proximity, life/character, funds, refunds, duplicate booking, return and disconnect")
