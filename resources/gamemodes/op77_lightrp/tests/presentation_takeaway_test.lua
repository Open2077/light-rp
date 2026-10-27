-- open77_appearance's take-away and applyLook (server/presentation.lua), with
-- the real catalogue and a fake database: the offer, what a save makes
-- takeable, pieces checked against what is really worn, once per save,
-- tampered requests, the host's answer, and dressing from a stored look.
local root = "../../system/open77_appearance/server/"
local function noop() end
local net, handlers, exported, toClient, events, threads = {}, {}, {}, {}, {}, {}
json = { encode = function() return "{}" end, decode = function() return {} end }
MySQL = { update = { await = function() return 1 end }, single = { await = function() return nil end } }
-- Threads run until their first Wait; pump() moves every live one a few turns
-- (the server's watchdog loops forever, so nothing runs to completion alone).
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); assert(ok, err) end
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
local function pump()
    for _ = 1, 4 do
        for _, co in ipairs(threads) do
            if coroutine.status(co) == "suspended" then local ok, err = coroutine.resume(co); assert(ok, err) end
        end
    end
end
function exports(name, fn) exported[name] = fn end
function RegisterNetEvent(name, fn) net[name] = fn end
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
function TriggerClientEvent(name, player, ...) toClient[#toClient + 1] = { name = name, player = player, args = { ... } } end
function TriggerEvent(name, ...) events[#events + 1] = { name = name, args = { ... } }; for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
RegisterCommand = noop
function GetPlayerIdentifier() return "00000000-0000-4000-8000-000000000001" end
local clock = 100000
function GetGameTimer() clock = clock + 1000; return clock end
function GetResourceState() return "stopped" end
GetCurrentResourceName = function() return "open77_appearance" end
Open77 = { players = { observers = function() return {} end, isInScope = function() return true end },
    resource = { generation = function() return 1 end } }
dofile(root .. "catalog.lua"); dofile(root .. "presentation.lua")
local P = Presentation

local function last(name) for i = #toClient, 1, -1 do if toClient[i].name == name then return toClient[i] end end end
local function lastEvent(name) for i = #events, 1, -1 do if events[i].name == name then return events[i] end end end
local function call(name, ...) source = 1; local result = net[name](...); pump(); return result end

P.families[1], P.characters[1], P.epochs[1] = "male", "default", 1
P.records[1] = { equipment = { Head = false, Face = "Items.Cop_01_Set_Glasses", InnerChest = false, OuterChest = false, Legs = false,
    Feet = false, Outfit = false, UnderwearTop = false, UnderwearBottom = "Items.Underwear_Basic_01_Bottom" }, wardrobe = { outfits = {} } }

-- Not offered: no take-away flag, requests are ignored.
call("open77:presentation:uiRequest")
assert(last("open77:presentation:uiState").args[1].takeAway == false)
call("open77:presentation:takeAway", { mode = "pieces", pieces = { { slot = "Face" } } })
assert(not lastEvent("open77:presentation:takeAway"), "no offer, no items")

-- Offered: open, but nothing is takeable before a save.
assert(exported.setTakeAway(1, true))
toClient = {}; call("open77:presentation:uiRequest")
assert(last("open77:presentation:uiState").args[1].takeAway == true)
call("open77:presentation:takeAway", { mode = "outfit" })
assert(last("open77:presentation:takeAwayResult").args[1] == false, "save first")

-- Save boots: the visit added Feet; Face was already worn.
call("open77:presentation:commit", "r1", { expectedRevision = 0, characterKey = "default", equipment = { Feet = "Items.Boots" } })
assert(last("open77:presentation:commitResult").args[2] == true, "commit accepted")
call("open77:presentation:takeAway", { mode = "pieces", pieces = {
    { slot = "Feet", label = "Combat boots", icon = "icons/m/0123456789abcdef.webp" },
    { slot = "Face", label = "Glasses" }, { slot = "Head", label = "Not worn" },
    { slot = "Legs", label = "Evil\1", icon = "https://example.invalid/x.webp" } } })
local granted = lastEvent("open77:presentation:takeAway")
assert(granted and granted.args[1] == 1)
local look = granted.args[2]
assert(look.mode == "pieces" and #look.pieces == 1, "only what this visit added and is really worn")
assert(look.pieces[1].slot == "Feet" and look.pieces[1].record == "Items.Boots" and look.pieces[1].label == "Combat boots")
assert(look.pieces[1].icon == "icons/m/0123456789abcdef.webp" and look.family == "male")
events = {}
call("open77:presentation:takeAway", { mode = "pieces", pieces = { { slot = "Feet" } } })
assert(not lastEvent("open77:presentation:takeAway") and last("open77:presentation:takeAwayResult").args[1] == false, "once per save")

-- A full bag: the host refuses, the player may retry, as a whole outfit.
assert(exported.takeAwayResult(1, false, "Your bag is full."))
assert(last("open77:presentation:takeAwayResult").args[2] == "Your bag is full.")
call("open77:presentation:takeAway", { mode = "outfit", name = "Street\2 kit", pieces = { { slot = "Feet", icon = "../../evil.webp" } } })
look = lastEvent("open77:presentation:takeAway").args[2]
assert(look.mode == "outfit" and #look.pieces == 2 and look.name == "Street kit", "the whole look, name cleaned")
assert(look.pieces[1].slot == "Face" and look.pieces[2].slot == "Feet" and look.pieces[2].icon == nil, "bad icon dropped")
assert(exported.takeAwayResult(1, true, "In your bag."))
assert(last("open77:presentation:takeAwayResult").args[1] == true)

-- An active outfit is what shows: its pieces win over the clothes underneath.
call("open77:presentation:commit", "r2", { expectedRevision = 1, characterKey = "default",
    wardrobe = { active = 2, outfits = { [2] = { Head = "Items.Balaclava", Face = false } } } })
assert(last("open77:presentation:commitResult").args[2] == true)
call("open77:presentation:takeAway", { mode = "outfit" })
look = lastEvent("open77:presentation:takeAway").args[2]
local slots = {}; for _, p in ipairs(look.pieces) do slots[p.slot] = p.record end
assert(slots.Head == "Items.Balaclava" and slots.Face == nil and slots.Feet == "Items.Boots", "outfit over clothes, hidden slot left out")

-- applyLook: dressing from a stored look, the overlay switched off.
local ok = exported.applyLook(1, { Head = "Items.Avg_10_Int_Netrunner_Head", Feet = false, Outfit = false }, "t1")
assert(ok, "queued"); pump()
local applied = lastEvent("open77:presentation:lookApplied")
assert(applied.args[1] == 1 and applied.args[2] == "t1" and applied.args[3] == true)
assert(P.records[1].equipment.Head == "Items.Avg_10_Int_Netrunner_Head" and P.records[1].equipment.Feet == false)
assert(P.records[1].wardrobe.active == nil, "the clothes show")
assert(last("open77:equipment:self").args[1].Head == "Items.Avg_10_Int_Netrunner_Head", "the owner sees it")
local refused, why = exported.applyLook(1, { Feet = "Items.Q301_Corpo_WA_Boots" }, "t2")
assert(not refused and why == "invalid_equipment", "a garment for another body is refused")
assert(not exported.applyLook(1, { UnderwearBottom = false }, "t3"), "underwear is not a take-away slot")
assert(not exported.applyLook(1, {}, "t4"))

-- Leaving the fitting room ends the offer.
assert(exported.setTakeAway(1, false))
toClient = {}; call("open77:presentation:uiRequest")
assert(last("open77:presentation:uiState").args[1].takeAway == false)
print("PASS: take-away offer, save first, only new and really worn pieces, once per save, retry after a refusal, outfit over clothes, tampered labels/icons/slots, applyLook (dress, overlay off, other body refused)")
