-- Recurring sinks (server/modules/economy_sinks.lua, docs/economy-balance.md):
-- bank then cash and never below zero, who is exempt (first day, activities,
-- missions, newcomers), the hospital bill after "Give up" (medical.lua) and the
-- fee of a city fitting room (wardrobe.lua). No database, no server.
dofile("server/config/economy.lua")
local E = LightRpEconomy
local noop = function() end
local clock = 36000000
local chars, wallets, ledger, notices = {}, {}, {}, {}
local tutorialActive, activityOwned, missionDeath = {}, {}, {}
local function char(id, minutes)
    chars[id] = { status = "active", identifier = "acc-" .. id, key = "default", playtimeMs = (minutes or 600) * 60000, joinedAtMs = clock }
end
local function take(walletName)
    return function(id, n, kind, note, counterparty)
        local w = wallets[id]
        if not w or n <= 0 or w[walletName] < n then return false, "insufficient_funds" end
        w[walletName] = w[walletName] - n
        ledger[#ledger + 1] = { id = id, wallet = walletName, amount = n, kind = kind, note = note, counterparty = counterparty }
        return true
    end
end
local function lastNotice(id) for i = #notices, 1, -1 do if notices[i].id == id then return notices[i] end end end
LightRP = {
    nowMs = function() return clock end, log = noop,
    module = function(name, def) LightRP[name] = def; return def end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body, kind = n.kind } end,
    characters = { get = function(id) return chars[id] end, displayName = function(id) return "P" .. id end },
    tutorial = { isActive = function(id) return tutorialActive[id] == true end },
    activities = { owns = function(id) return activityOwned[id] == true end },
    missions = { handlesDeath = function(id) return missionDeath[id] == true end },
    money = { get = function(id) return wallets[id] end, format = function(n) return "€$ " .. tostring(n) end,
        removeBank = take("bank"), removeCash = take("cash") },
}
dofile("server/modules/economy_sinks.lua")
local S = LightRP.sinks

-- ── collect: bank first, then cash; all or nothing unless partial; never below zero ──
char(1); wallets[1] = { bank = 200, cash = 150 }
local paid, fromBank, fromCash = S.collect(1, 300, "test", "Test", "Someone", false)
assert(paid == 300 and fromBank == 200 and fromCash == 100 and wallets[1].bank == 0 and wallets[1].cash == 50, "bank first, then cash")
assert(ledger[1].kind == "test" and ledger[1].counterparty == "Someone" and ledger[2].wallet == "cash", "both legs on the ledger")
paid = S.collect(1, 300, "test", "Test", "Someone", false)
assert(paid == 0 and wallets[1].cash == 50 and #ledger == 2, "not enough: nothing taken")
paid, fromBank, fromCash = S.collect(1, 300, "test", "Test", "Someone", true)
assert(paid == 50 and fromBank == 0 and fromCash == 50 and wallets[1].bank == 0 and wallets[1].cash == 0, "partial takes what is there")
assert(S.collect(1, 300, "test", "Test", "Someone", true) == 0 and wallets[1].bank == 0 and wallets[1].cash == 0, "an empty wallet stays at zero")
assert(S.collect(1, -5, "test") == 0 and S.collect(99, 10, "test") == 0, "no negative amounts, no wallet no charge")

-- ── who pays the hospital ──
char(2); wallets[2] = { bank = 5000, cash = 0 }
assert(S.hospitalBill(2) == E.hospital.bill and E.hospital.bill > 0, "a settled character pays the bill")
assert(select(2, S.hospitalBill(77)) == "no_character", "no character, no bill")
tutorialActive[2] = true; assert(select(2, S.hospitalBill(2)) == "first_day", "the first day is free"); tutorialActive[2] = nil
activityOwned[2] = true; assert(select(2, S.hospitalBill(2)) == "activity", "activities never bill"); activityOwned[2] = nil
missionDeath[2] = true; assert(select(2, S.hospitalBill(2)) == "mission", "missions never bill"); missionDeath[2] = nil
char(3, 30); wallets[3] = { bank = 5000, cash = 0 }
assert(select(2, S.hospitalBill(3)) == "grace", "a newcomer is treated on the city")
clock = clock + (E.hospital.graceMinutes - 30 + 1) * 60000
assert(S.hospitalBill(3) == E.hospital.bill, "the session counts towards the grace period")
chars[4] = { status = "active", playtimeMs = 0 } -- no session start known: playtime alone
wallets[4] = nil
assert(select(2, S.hospitalBill(4)) == "grace", "no playtime yet")
chars[4].playtimeMs = 600 * 60000
assert(select(2, S.hospitalBill(4)) == "no_wallet", "no wallet loaded, no bill")
local savedBill = E.hospital.bill
E.hospital.bill = 0; assert(select(2, S.hospitalBill(2)) == "free", "a bill of 0 disables it"); E.hospital.bill = savedBill

-- ── chargeHospital: the whole bill, what is there, or nothing; a notice either way ──
local before = #ledger
assert(S.chargeHospital(2) == E.hospital.bill and wallets[2].bank == 5000 - E.hospital.bill, "the bill comes from the bank")
assert(ledger[#ledger].kind == "hospital" and ledger[#ledger].counterparty == E.hospital.counterparty and #ledger == before + 1)
assert(lastNotice(2).title == "Hospital" and lastNotice(2).body:find("€$ " .. E.hospital.bill, 1, true) and lastNotice(2).body:find("from the bank", 1, true))
char(5); wallets[5] = { bank = 100, cash = 50 }
assert(S.chargeHospital(5) == 150 and wallets[5].bank == 0 and wallets[5].cash == 0, "short: what is there, never below zero")
assert(lastNotice(5).body:find("written off", 1, true), "the rest is written off")
assert(S.chargeHospital(5) == 0 and wallets[5].bank == 0 and lastNotice(5).body:find("nothing to pay with", 1, true), "an empty wallet owes nothing")
char(6, 10); wallets[6] = { bank = 5000, cash = 0 }
assert(S.chargeHospital(6) == 0 and wallets[6].bank == 5000 and lastNotice(6).body:find("Newcomers", 1, true), "a newcomer is told it was free")
tutorialActive[7] = true; char(7); wallets[7] = { bank = 5000, cash = 0 }; local quiet = #notices
assert(S.chargeHospital(7) == 0 and wallets[7].bank == 5000 and #notices == quiet, "the first day: free and silent"); tutorialActive[7] = nil

-- ── fitting room fee ──
assert(S.fittingPrice() == E.fitting.fee and E.fitting.fee > 0)
char(8); wallets[8] = { bank = 0, cash = 70 }
missionDeath[8] = true
assert(S.fittingFee(8) == E.fitting.fee, "a mission's death rule does not apply to clothes")
missionDeath[8] = nil
assert(S.chargeFitting(8) == E.fitting.fee and wallets[8].cash == 70 - E.fitting.fee and ledger[#ledger].kind == "fitting", "paid in cash when the bank is empty")
assert(lastNotice(8).body:find("in cash", 1, true), "the notice says how it was paid")
assert(S.chargeFitting(8) == 0 and wallets[8].cash == 70 - E.fitting.fee and lastNotice(8).body:find("On the house", 1, true), "cannot cover it: waived, nothing taken")
char(9, 5); wallets[9] = { bank = 5000, cash = 0 }
assert(select(2, S.fittingFee(9)) == "grace" and S.chargeFitting(9) == 0 and wallets[9].bank == 5000, "newcomers dress for free")

-- ── medical.lua: "Give up" bills once, the page shows the bill ──
local netHandlers, pushes, respawns, lifePhase = {}, {}, {}, {}
local unixNow = 2000000000
CreateThread = function(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err) end end
Wait = function() coroutine.yield() end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
AddEventHandler = noop
GetPlayers = function() return { "21", "22", "23" } end
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerClientEvent = function(_, player, payload) if type(payload) == "table" and payload.kind == "state" then pushes[player] = payload.state end end
json = { encode = function() return "{}" end, decode = function() return {} end }
Open77 = {
    time = { unix = function() return unixNow end },
    players = {
        getLifeState = function(id) return { phase = lifePhase[id] or "alive" } end,
        get = function() return nil end,
        respawn = function(id, opts) respawns[#respawns + 1] = { id = id, position = opts.position }; lifePhase[id] = "alive"; return true end,
    },
    combat = { onDamage = function() return 1 end, offDamage = noop },
    ready = { isReady = function() return false end },
}
local invs = { [21] = { id = "inv:21", items = {} }, [22] = { id = "inv:22", items = {} }, [23] = { id = "inv:23", items = {} } }
local refuseTransfer = false
LightRP.db = { schema = noop, read = function() return true, {} end, transaction = function() return true end }
LightRP.inventory = { player = function(id) return invs[id] end, onUse = noop }
LightRpItems = {}
LightRpConfig = { spawn = { hospital = { name = "hospital", position = { x = 1, y = 2, z = 3 }, heading = 0 }, health = 100, graceMs = 5000 } }
dofile("shared/medical.lua")
dofile("server/modules/medical_store.lua")
dofile("server/modules/medical.lua")
local M = LightRP.medical
local NET = "op77_lightrp:medical"
local function down(id)
    lifePhase[id] = "dead"
    M.subjects[id] = { inventory = invs[id], character = chars[id],
        record = { status = "downed", since = unixNow - 600, revision = 1, token = "death-" .. id, position = { x = 0, y = 0, z = 0 }, bucket = 0 } }
end
local function giveUp(id) clock = clock + 1000; source = id; netHandlers[NET]({ operation = "giveup" }) end
char(21); wallets[21] = { bank = 1000, cash = 0 }
char(22, 20); wallets[22] = { bank = 1000, cash = 0 }
char(23); wallets[23] = { bank = 1000, cash = 0 }
down(21); down(22); down(23)
assert(M.view(21).bill == E.hospital.bill and M.view(22).bill == 0, "the page shows the bill; a newcomer sees none")
assert(M.view(99).bill == 0, "nobody downed, nothing to show")
giveUp(21)
assert(#respawns == 1 and respawns[1].id == 21 and wallets[21].bank == 1000 - E.hospital.bill, "the transfer bills the clinic's fee")
assert(pushes[21] and pushes[21].phase == "hospital", "the page hears of the transfer")
giveUp(21)
assert(#respawns == 1 and wallets[21].bank == 1000 - E.hospital.bill, "a repeated request neither transfers nor bills again")
giveUp(22)
assert(#respawns == 2 and wallets[22].bank == 1000 and lastNotice(22).body:find("Newcomers", 1, true), "newcomers wake up for free")
-- A refused respawn: no transfer, no bill.
Open77.players.respawn = function() return false, "busy" end
giveUp(23)
assert(#respawns == 2 and wallets[23].bank == 1000, "a refused transfer bills nothing")

-- ── wardrobe.lua: a city fitting room charges once per visit that saves a look ──
dofile("shared/config.lua")
dofile("shared/events.lua")
local points, opened, buckets = {}, {}, {}
CreateThread = function(fn) fn() end
Wait = noop
SetTimeout = noop
AddEventHandler = function(name, fn) netHandlers[name] = fn end
TriggerClientEvent = function(name, player) if name == "open77:wardrobe_ui:open" then opened[#opened + 1] = player end end
GetPlayerRoutingBucket = function(player) return buckets[player] or 0 end
SetPlayerRoutingBucket = function(player, bucket) buckets[player] = bucket; return true end
GetPlayersInBucket = function() return {} end
Open77 = { players = { getLifeState = function() return { phase = "alive" } end },
    environment = { getState = function() return { hour = 12, minute = 0, second = 0, rate = 1, timeFrozen = false, weather = "x", weatherFrozen = false } end,
        setTime = function() return true end, setTimeRate = function() return true end, setTimeFrozen = function() return true end,
        setWeather = function() return true end, setWeatherFrozen = function() return true end, clearBucket = noop } }
LightRP.interaction = function(id, value) points[id] = value end
LightRP.action, LightRP.result, LightRP.inventory, LightRP.tutorial = noop, noop, nil, nil
dofile("server/modules/wardrobe.lua")
local W = LightRP.wardrobe
local price = "€$ " .. E.fitting.fee
assert(points["wardrobe.citycenter"].prompt:find(price, 1, true) and points["wardrobe.citycenter"].blip.description:find(price, 1, true), "a city room shows its fee")
assert(not points["wardrobe.lobby_fitting"].prompt:find(price, 1, true), "the arrival hall's room is free")
local function visit(player, spot, save, times)
    W.onInteract(player, spot)
    source = player; netHandlers[LightRpEvents.net.wardrobe](true)
    for _ = 1, (save and (times or 1) or 0) do netHandlers["open77:presentation:committed"](player, {}) end
    source = player; netHandlers[LightRpEvents.net.wardrobe](false)
end
char(31); wallets[31] = { bank = 1000, cash = 0 }
visit(31, "wardrobe.citycenter", true, 3)
assert(wallets[31].bank == 1000 - E.fitting.fee, "three saves in one visit: one fee")
visit(31, "wardrobe.citycenter", false)
assert(wallets[31].bank == 1000 - E.fitting.fee, "a visit without a saved look is free")
visit(31, "wardrobe.citycenter", true)
assert(wallets[31].bank == 1000 - 2 * E.fitting.fee, "the next visit pays again")
buckets[31] = 620000; visit(31, "wardrobe.lobby_fitting", true); buckets[31] = 0
assert(wallets[31].bank == 1000 - 2 * E.fitting.fee, "the arrival hall is free")
buckets[31] = 1000042; assert(W.open(31, true)); netHandlers["open77:presentation:committed"](31, {}); buckets[31] = 0
assert(wallets[31].bank == 1000 - 2 * E.fitting.fee, "a home wardrobe is free")
assert(W.open(31, false)); netHandlers["open77:presentation:committed"](31, {})
assert(wallets[31].bank == 1000 - 2 * E.fitting.fee, "a wardrobe opened in place (creation wizard, staff) is free")

print("PASS: sinks collect bank then cash and never below zero; exemptions (first day, activity, mission, newcomer, no wallet, disabled); hospital bill after Give up, once, page bill, refused transfer free; fitting fee once per city visit with a saved look, hall/home/in-place free, prompt price")
