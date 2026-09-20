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
LightRpConfig.rentals.spots[1].stock[2].image = "img/vehicles/agency.jpg"
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
assert(#opened.spot.stock == 5 and opened.spot.durationMinutes == 30)
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
assert(current.image == "img/vehicles/agency.jpg" and current.remainingMs == 1800000 and current.paidWith == "bank")
now = now + 5000
assert(providers.rental(1).active.remainingMs == 1795000)
local attempts = creates
ok, reason = Rental.rent(1, "citycenter", "maimai", "bank")
assert(not ok and reason == "already_renting" and bank == 1380 and creates == attempts)
actions["rental.return"](1)
assert(result.ok and removes == 1 and not Rental.get(1) and bank == 1380, "return removes car without refund")
assert(not Rental.giveBack(1), "return is not repeated")
assert(Rental.rent(1, "citycenter", "maimai", "cash"))
Rental.onDisconnected(1)
assert(not Rental.get(1) and removes == 2)
print("PASS: rental images, stock, authoritative price/duration, proximity, life/character, funds, refunds, duplicate booking, return and disconnect")
