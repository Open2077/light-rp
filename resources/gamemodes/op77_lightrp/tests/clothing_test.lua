-- Clothes as items (server/modules/clothing.lua) on the real inventory: the
-- take-away grant (pieces, outfit, all or nothing when the bag is full), the
-- garment art, putting on / taking off a piece, changing into an outfit, and
-- the answers from open77_appearance. Run from the resource directory.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("shared/items.lua")
local noop = function() end
json = { encode = function() return "{}" end }
local handlers, notices, results, applied = {}, {}, {}, {}
local actions, providers, pushed, lastResult = {}, {}, {}, nil
local worn = { equipment = { Face = "Items.Cop_01_Set_Glasses", Feet = false, Outfit = false }, wardrobe = { active = false, outfits = {} } }
local applyAnswer = true
exports = { open77_appearance = {
    takeAwayResult = function(_, player, ok, text) results[#results + 1] = { player = player, ok = ok, text = text } end,
    visibleOutfit = function(_, player) return worn end,
    applyLook = function(_, player, equipment, token) applied[#applied + 1] = { player = player, equipment = equipment, token = token }; return applyAnswer, applyAnswer and nil or "presentation_busy" end,
} }
Open77 = { players = { getLifeState = function() return { phase = "alive" } end } }
local now = 1000
LightRP = {
    db = { schema = noop, ready = false }, command = noop, log = noop, eachModule = noop,
    action = function(name, fn) actions[name] = fn end, stateProvider = function(name, fn) providers[name] = fn end,
    state = function(player, keys) pushed[#pushed + 1] = keys[1] end,
    result = function(player, ok, text, action) lastResult = { ok = ok, text = text, action = action } end,
    notice = function(player, n) notices[#notices + 1] = { player = player, kind = n.kind, body = n.body } end,
    characters = { displayName = function() return "Test Character" end, get = function() return { bodyFamily = "male" } end },
    nowMs = function() return now end,
    module = function(name, value) LightRP[name] = value; return value end,
}
AddEventHandler = function(name, fn) local prev = handlers[name]; handlers[name] = prev and function(...) prev(...); fn(...) end or fn end
CreateThread = noop
GetPlayerName = function() return "Test" end
TriggerClientEvent = noop
dofile("server/modules/inventory.lua")
local Inv = LightRP.inventory
Inv.onCharacterActivated(1, { status = "active", identifier = "unit-test", key = "default" })
local inv = Inv.player(1)
dofile("server/modules/clothing.lua")

local function take(look) handlers["open77:presentation:takeAway"](1, look) end
local function slotOf(name) for slot, item in pairs(inv.items) do if item.name == name then return slot, item end end end
local function count(name) local n = 0; for _, item in pairs(inv.items) do if item.name == name then n = n + item.count end end; return n end

-- Separate pieces: one clothing item each, with the garment's own icon.
inv.items = {}
take({ mode = "pieces", family = "male", name = "My look", pieces = {
    { slot = "Feet", record = "Items.Boots", label = "Combat boots", icon = "icons/m/0123456789abcdef.webp" },
    { slot = "Head", record = "Items.Balaclava", label = "Balaclava" } } })
assert(results[#results].ok and count("clothing") == 2, "two pieces in the bag")
local slot, boots = slotOf("clothing")
local snap = Inv.snapshot(inv).items
local bootsSnap
for _, s in ipairs(snap) do if s.metadata and s.metadata.record == "Items.Boots" then bootsSnap = s end end
assert(bootsSnap.label == "Combat boots" and bootsSnap.image == "open77://open77_wardrobe_ui/web/icons/m/0123456789abcdef.webp", "garment name and art")
assert(bootsSnap.usable and bootsSnap.metadata.family == "male")

-- A complete outfit: one item holding every piece; its cover is the most visible one.
take({ mode = "outfit", family = "male", name = "Street", pieces = {
    { slot = "Face", record = "Items.Cop_01_Set_Glasses", label = "Glasses", icon = "icons/m/aaaaaaaaaaaaaaaa.webp" },
    { slot = "OuterChest", record = "Items.Jacket_01", label = "Jacket", icon = "icons/m/bbbbbbbbbbbbbbbb.webp" } } })
assert(results[#results].ok and count("outfit") == 1)
local _, outfit = slotOf("outfit")
assert(outfit.metadata.label == "Street" and outfit.metadata.pieces.OuterChest == "Items.Jacket_01" and outfit.metadata.pieces.Face == "Items.Cop_01_Set_Glasses")
assert(outfit.metadata.image == "open77://open77_wardrobe_ui/web/icons/m/bbbbbbbbbbbbbbbb.webp", "the jacket covers the outfit")

-- A full bag: nothing is added, the player is told, the appearance resource may retry.
local before = count("clothing")
inv.maxWeight = Inv.weightOf(inv) + 0.5
take({ mode = "pieces", family = "male", pieces = { { slot = "Legs", record = "Items.Pants_01", label = "Pants" }, { slot = "InnerChest", record = "Items.Shirt_01", label = "Shirt" } } })
assert(not results[#results].ok and results[#results].text:find("too heavy") and count("clothing") == before, "all or nothing")
inv.maxWeight = 40

-- The fitting room's art path, computed here: SHA-256 of the record.
assert(LightRP.clothing.sha256("Items.Coat_01_basic_01"):sub(1, 16) == "c9e09f7f8f770a5e", "same icon hash as build-icons.py")
assert(LightRP.clothing.sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

-- A garment is in the bag or worn, never both.
local function find(record) for s, item in pairs(inv.items) do if item.metadata and item.metadata.record == record then return s, item end end end
local function wornNow(equipment) worn = { equipment = equipment, wardrobe = { active = false, outfits = {} } } end
-- Putting the boots on (a full-body suit was worn): the boots leave the bag, the suit comes back.
wornNow({ Head = false, Face = false, InnerChest = false, OuterChest = false, Legs = false, Feet = false, Outfit = "Items.Suit_01" })
local bootsSlot = find("Items.Boots")
local usedOk, usedWhy = Inv.use(1, bootsSlot); assert(usedOk, tostring(usedWhy))
local last = applied[#applied]
assert(last.equipment.Feet == "Items.Boots" and last.equipment.Outfit == false and last.token == "lightrp")
assert(not find("Items.Boots"), "the worn boots left the bag")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(notices[#notices].kind == "success" and notices[#notices].body:find("Put on Combat boots"))
local _, suit = find("Items.Suit_01")
assert(suit and suit.metadata.slot == "Outfit" and suit.metadata.label == "Suit 01", "the suit came back to the bag")

-- Swapping the glasses in the bag for the ones worn: one in, one out.
wornNow({ Head = false, Face = "Items.Glasses_Old", InnerChest = false, OuterChest = false, Legs = false, Feet = "Items.Boots", Outfit = false })
local glasses = Inv.addItems(inv.id, { { name = "clothing", count = 1, metadata = { record = "Items.Glasses_New", slot = "Face", label = "New" } } })
assert(glasses)
now = now + 20000; assert(Inv.use(1, (find("Items.Glasses_New"))))
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(not find("Items.Glasses_New") and find("Items.Glasses_Old"), "swap: the new pair worn, the old one in the bag")

-- A refused change gives the used item back.
now = now + 20000; wornNow({ Head = false, Face = "Items.Glasses_New", InnerChest = false, OuterChest = false, Legs = false, Feet = "Items.Boots", Outfit = false })
assert(Inv.use(1, (find("Items.Glasses_Old"))))
assert(not find("Items.Glasses_Old"))
handlers["open77:presentation:lookApplied"](1, "lightrp", false, "invalid_equipment")
assert(find("Items.Glasses_Old") and not find("Items.Glasses_New"), "refused: the used pair is back, nothing came out")
assert(notices[#notices].kind == "error" and notices[#notices].body:find("do not fit"))

-- An outfit swaps the whole look: used up, every replaced piece comes back.
now = now + 20000
wornNow({ Head = "Items.Cap_01", Face = false, InnerChest = false, OuterChest = false, Legs = false, Feet = "Items.Boots", Outfit = false })
local outfitSlot = slotOf("outfit")
assert(Inv.use(1, outfitSlot))
local e = applied[#applied].equipment
assert(e.OuterChest == "Items.Jacket_01" and e.Face == "Items.Cop_01_Set_Glasses" and e.Feet == false and e.Head == false and e.Outfit == false)
assert(count("outfit") == 0, "the outfit is worn, not in the bag")
-- A second change while the first runs waits.
assert(not Inv.use(1, (find("Items.Glasses_Old"))), "one change at a time")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(find("Items.Cap_01") and find("Items.Boots"), "the cap and the boots it replaced are in the bag")
-- The appearance resource refuses at once (busy): nothing is used up.
applyAnswer = false; now = now + 20000
local n0 = count("clothing"); assert(not Inv.use(1, (find("Items.Cap_01"))) and count("clothing") == n0)
applyAnswer = true
-- Other players' answers and foreign tokens are ignored.
handlers["open77:presentation:lookApplied"](1, "other", true)

-- The outfit worn ("Street": glasses + jacket) is a layer: the Outfit slot shows it.
local ws = providers.worn(1)
assert(ws.outfit and ws.outfit.label == "Street", "the Outfit slot holds the outfit")
-- A cap over the outfit replaces only the head; nothing else changes.
now = now + 20000
assert(Inv.use(1, (find("Items.Cap_01"))))
local eo = applied[#applied].equipment
assert(eo.Head == "Items.Cap_01" and eo.OuterChest == "Items.Jacket_01" and eo.Face == "Items.Cop_01_Set_Glasses", "only the head changes")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(not find("Items.Cap_01"), "the cap is worn, not in the bag")
assert(providers.worn(1).sources.Head == "over")
-- Taking the cap off: back to the bag, the outfit's head shows again (none here).
now = now + 20000
actions["clothing.takeOff"](1, { slot = "Head" })
assert(applied[#applied].equipment.Head == false and applied[#applied].equipment.OuterChest == "Items.Jacket_01")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(find("Items.Cap_01"), "the cap is back in the bag")
-- An outfit piece can be hidden (nothing comes to the bag) and shown again.
now = now + 20000
local c0 = count("clothing")
actions["clothing.takeOff"](1, { slot = "OuterChest" })
assert(applied[#applied].equipment.OuterChest == false and count("clothing") == c0, "hidden, not duplicated")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(providers.worn(1).sources.OuterChest == "hidden")
now = now + 20000
actions["clothing.show"](1, { slot = "OuterChest" })
assert(applied[#applied].equipment.OuterChest == "Items.Jacket_01")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
-- A piece over it stays on when the outfit comes off; the outfit item returns whole.
now = now + 20000
assert(Inv.use(1, (find("Items.Cap_01")))); handlers["open77:presentation:lookApplied"](1, "lightrp", true)
-- No room in the bag for the outfit: refused before anything changes.
now = now + 20000
inv.maxWeight = Inv.weightOf(inv) + 0.1
local applies = #applied; actions["clothing.takeOff"](1, { slot = "Outfit" })
assert(#applied == applies and lastResult.ok == false, "full bag: no change")
inv.maxWeight = 40
actions["clothing.takeOff"](1, { slot = "Outfit" })
local ef = applied[#applied].equipment
assert(ef.Head == "Items.Cap_01" and ef.OuterChest == false and ef.Face == false, "the cap stays, the outfit's pieces go")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(count("outfit") == 1 and not providers.worn(1).outfit, "the outfit is back in the bag, whole")
-- The fitting room saving a look ends a layer (no item comes back: what shows is plain clothes).
now = now + 20000
assert(Inv.use(1, slotOf("outfit"))); handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(providers.worn(1).outfit)
-- the commit of our own change, announced after its answer (the order seen in game)
handlers["open77:presentation:committed"](1, {})
assert(providers.worn(1).outfit, "our own commit, arriving late, keeps the layer")
handlers["open77:presentation:committed"](1, {})
assert(not providers.worn(1).outfit and count("outfit") == 0, "layer ended by the fitting room, no free outfit")

-- Making an outfit of what is worn: nothing changes on the body, no item is made;
-- taking the Outfit slot off then folds the whole look into the bag.
now = now + 20000
wornNow({ Head = false, Face = false, InnerChest = "Items.TShirt_01", OuterChest = "Items.Jacket_01_old_01", Legs = false, Feet = "Items.Boots_12", Outfit = false })
local applies0, items0 = #applied, count("clothing") + count("outfit")
actions["clothing.makeOutfit"](1, { name = "Night run" })
assert(lastResult.ok and #applied == applies0 and count("clothing") + count("outfit") == items0, "no change, no item")
local wo = providers.worn(1)
assert(wo.outfit.label == "Night run" and wo.sources.OuterChest == "outfit" and wo.outfit.image:find("icons/m/"), "the outfit covers with the jacket")
actions["clothing.makeOutfit"](1, {}); assert(lastResult.ok == false, "one outfit at a time")
actions["clothing.takeOff"](1, { slot = "Outfit" })
local em = applied[#applied].equipment
assert(em.InnerChest == false and em.OuterChest == false and em.Feet == false, "the whole look comes off")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
local folded
for _, item in pairs(inv.items) do if item.name == "outfit" and item.metadata.label == "Night run" then folded = item end end
assert(folded and folded.metadata.pieces.OuterChest == "Items.Jacket_01_old_01" and folded.metadata.pieces.Feet == "Items.Boots_12", "folded into the bag")
now = now + 20000
wornNow({ Head = false, Face = false, InnerChest = false, OuterChest = false, Legs = false, Feet = false, Outfit = false })
actions["clothing.makeOutfit"](1, {}); assert(lastResult.ok == false, "nothing worn, nothing to make")

-- The Worn column: what shows, slot by slot, for the male art.
now = now + 20000
wornNow({ Head = false, Face = false, InnerChest = "Items.Shirt_01", OuterChest = "Items.Coat_01_basic_01", Legs = false, Feet = false, Outfit = false })
local w = providers.worn(1)
assert(w.ready and w.family == "m" and w.slots.OuterChest == "Items.Coat_01_basic_01" and w.slots.Head == false)
-- Taking the coat off: it goes in the bag with its name and art, the rest of the look stays.
local before = count("clothing")
actions["clothing.takeOff"](1, { slot = "OuterChest" })
local e2 = applied[#applied].equipment
assert(e2.OuterChest == false and e2.InnerChest == "Items.Shirt_01", "only that piece comes off")
handlers["open77:presentation:lookApplied"](1, "lightrp", true)
assert(count("clothing") == before + 1, "the garment lands in the bag once it is off")
local _, coat = find("Items.Coat_01_basic_01")
assert(coat.metadata.label == "Coat 01 Classic 01" and coat.metadata.image == "open77://open77_wardrobe_ui/web/icons/m/c9e09f7f8f770a5e.webp")
-- A refused take off: the item goes again (the garment is still worn).
now = now + 20000
wornNow({ Head = false, Face = false, InnerChest = "Items.Shirt_01", OuterChest = false, Legs = false, Feet = false, Outfit = false })
local n1 = count("clothing")
actions["clothing.takeOff"](1, { slot = "InnerChest" })
handlers["open77:presentation:lookApplied"](1, "lightrp", false)
assert(count("clothing") == n1, "refused: no free item")
-- Nothing worn there, or a forged slot: refused.
now = now + 20000
actions["clothing.takeOff"](1, { slot = "Head" }); assert(lastResult.ok == false)
actions["clothing.takeOff"](1, { slot = "UnderwearBottom" }); assert(lastResult.ok == false)
-- The appearance refuses at once: the new item is taken back.
applyAnswer = false; wornNow({ Head = false, Face = false, InnerChest = false, OuterChest = false, Legs = false, Feet = "Items.Boots_02", Outfit = false }); now = now + 20000
local n = count("clothing"); actions["clothing.takeOff"](1, { slot = "Feet" }); assert(count("clothing") == n, "refused change, no free item")
applyAnswer = true
-- The appearance resource may apply and answer inside the call (a synchronous
-- commit): the change must still be recognised (layer set, items back).
local sync = true
exports.open77_appearance.applyLook = function(_, player, equipment, token)
    applied[#applied + 1] = { player = player, equipment = equipment, token = token }
    if sync then handlers["open77:presentation:committed"](player, {}); handlers["open77:presentation:lookApplied"](player, token, true) end
    return true
end
now = now + 20000
wornNow({ Head = false, Face = false, InnerChest = "Items.TShirt_02", OuterChest = false, Legs = false, Feet = false, Outfit = false })
assert(Inv.use(1, slotOf("outfit")))
assert(providers.worn(1).outfit, "synchronous answer: the outfit is worn as a layer")
assert(find("Items.TShirt_02"), "synchronous answer: the replaced shirt is back in the bag")
now = now + 20000
actions["clothing.takeOff"](1, { slot = "Outfit" })
assert(not providers.worn(1).outfit and count("outfit") == 1, "synchronous answer: the outfit is back in the bag")
print("PASS: make an outfit of what is worn (no change, no item, folds on take off); outfit layer (Outfit slot, piece over it replaces one slot, take off shows the outfit's, hide/show, outfit off keeps pieces over it, fitting room ends it); take-away as pieces / outfit (art, labels, cover), all or nothing on a full bag; a garment is in the bag or worn (put on uses it up, the replaced piece and a covering suit come back, swaps, refusals give it back, no room = no change); outfit swap returns every replaced piece; Worn state and take off (to the bag with name and art, refusals rolled back); SHA-256 art path")
