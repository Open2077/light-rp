-- Item templates. Shared with clients (labels, icons, weights are public); the
-- server is the only side that moves items. Every inventory slot holds
-- { name, count, metadata }; `name` is a key of this table.
--
--   label        shown on the card
--   description  tooltip
--   weight       kilograms per unit
--   stack        max units per slot (1 = never stacks)
--   icon         Lucide icon name the page knows (see ui/src/design/components/Icon.tsx)
--   image        optional local WebUI asset, e.g. img/items/water.png (not item metadata)
--   category     free tag for filters/shops (food, drink, medical, tool, document, misc)
--   use          nil = not usable; otherwise { consume = true, food = +n, drink = +n, health = +n, notice = "..." }
--                other modules can also hook a name with LightRP.inventory.onUse(name, fn)
LightRpItems = {
    cash = {
        label = "Eurodollars", description = "Physical cash: €$1 per unit. Split, give or store it. Only pocket cash can be spent.",
        weight = 0, stack = 1000000000, icon = "banknote", category = "currency",
        image = "img/items/cash.png",
    },
    water = {
        label = "Bottle of Water", description = "Still water. Night City tap, allegedly filtered.",
        weight = 0.5, stack = 10, icon = "droplet", category = "drink",
        use = { consume = true, drink = 30, notice = "You drink the water." },
    },
    soda = {
        label = "NiCola", description = "The taste of the city. Sugar, caffeine and something else.",
        weight = 0.4, stack = 10, icon = "cup-soda", category = "drink",
        use = { consume = true, drink = 20, food = 5, notice = "You drink the NiCola." },
    },
    burrito = {
        label = "Burrito", description = "Street burrito. Best not to ask what is inside.",
        weight = 0.4, stack = 10, icon = "sandwich", category = "food",
        use = { consume = true, food = 35, notice = "You eat the burrito." },
    },
    synthmeat = {
        label = "Synth-Meat Skewer", description = "Grilled, salted, entirely synthetic.",
        weight = 0.3, stack = 10, icon = "beef", category = "food",
        use = { consume = true, food = 25, notice = "You eat the skewer." },
    },
    apple = {
        label = "Apple", description = "A real one. Rare.",
        weight = 0.2, stack = 20, icon = "apple", category = "food",
        use = { consume = true, food = 12, drink = 5, notice = "You eat the apple." },
    },
    candy = {
        label = "Candy Bar", description = "Quick sugar.",
        weight = 0.1, stack = 20, icon = "candy", category = "food",
        use = { consume = true, food = 8, notice = "You eat the candy bar." },
    },
    noodles = {
        label = "Street Ramen", description = "Hot noodles, scallions and vat-grown protein. A full meal from the night market.",
        weight = 0.5, stack = 8, icon = "soup", category = "food",
        use = { consume = true, food = 40, drink = 5, notice = "You finish the ramen." },
    },
    dumplings = {
        label = "Dumpling Box", description = "Four steamed dumplings with a soy-protein filling and a little too much sauce.",
        weight = 0.35, stack = 8, icon = "sandwich", category = "food",
        use = { consume = true, food = 30, notice = "You eat the dumplings." },
    },
    pizza = {
        label = "Synth-Pepperoni Slice", description = "A generous slice of melted cheese and synthetic pepperoni, straight from the warmer.",
        weight = 0.3, stack = 10, icon = "pizza", category = "food",
        use = { consume = true, food = 28, notice = "You eat the pizza slice." },
    },
    onigiri = {
        label = "Onigiri", description = "Rice, seaweed and a savoury filling. Fresh enough for a vending machine.",
        weight = 0.15, stack = 15, icon = "sandwich", category = "food",
        use = { consume = true, food = 18, notice = "You eat the onigiri." },
    },
    proteinbar = {
        label = "Protein Ration", description = "Compressed grains and cultured protein. Made for long shifts, not fine dining.",
        weight = 0.12, stack = 20, icon = "candy", category = "food",
        use = { consume = true, food = 22, notice = "You eat the protein ration." },
    },
    coffee = {
        label = "Synth-Coffee", description = "A dark, bitter cup from the corner kiosk. The beans are optional.",
        weight = 0.3, stack = 8, icon = "coffee", category = "drink",
        use = { consume = true, drink = 18, notice = "You drink the synth-coffee." },
    },
    energydrink = {
        label = "Volt Energy", description = "A sharply sweet canned drink for another late shift. No performance boost included.",
        weight = 0.35, stack = 10, icon = "zap", category = "drink",
        use = { consume = true, drink = 22, food = 4, notice = "You drink the Volt Energy." },
    },
    electrolyte = {
        label = "Electrolyte Mix", description = "Filtered water and mineral salts in a tough reusable bottle.",
        weight = 0.5, stack = 10, icon = "droplet", category = "drink",
        use = { consume = true, drink = 40, notice = "You drink the electrolyte mix." },
    },
    juice = {
        label = "Citrus Blend", description = "Orange-flavoured fruit blend. The label makes no promises about actual oranges.",
        weight = 0.25, stack = 12, icon = "cup-soda", category = "drink",
        use = { consume = true, drink = 25, food = 6, notice = "You drink the citrus blend." },
    },
    bandage = {
        label = "Bandage", description = "Stops the bleeding, closes small wounds.",
        weight = 0.2, stack = 10, icon = "bandage", category = "medical",
        use = { consume = true, health = 25, notice = "You patch yourself up." },
    },
    medkit = {
        label = "MaxDoc", description = "Inhaler. Serious repairs, fast.",
        weight = 0.6, stack = 5, icon = "pill", category = "medical",
        use = { consume = true, health = 70, notice = "You take a hit of MaxDoc." },
    },
    firstaid = {
        label = "Field First Aid Kit", description = "Sealed dressings, disinfectant and a compact med scanner. Emergency care for a living patient, not a revival kit.",
        weight = 1.0, stack = 3, icon = "briefcase-medical", category = "medical",
        use = { consume = true, health = 45, notice = "You use the field first aid kit." },
    },
    cigarettes = {
        label = "Cigarettes", description = "A pack of twenty. Night City brand.",
        weight = 0.1, stack = 10, icon = "cigarette", category = "misc",
        use = { consume = true, notice = "You light a cigarette." },
    },
    lighter = {
        label = "Lighter", description = "Cheap plastic lighter.",
        weight = 0.05, stack = 5, icon = "flame", category = "tool",
    },
    phone = {
        label = "Phone", description = "Your holo. Calls, messages, the usual.",
        weight = 0.3, stack = 1, icon = "smartphone", category = "tool",
    },
    idcard = {
        label = "ID Card", description = "Night City citizen card.",
        weight = 0.05, stack = 1, icon = "id-card", category = "document",
    },
    watch = {
        label = "Wristwatch", description = "Analog. Still works.",
        weight = 0.1, stack = 1, icon = "watch", category = "misc",
    },
    wrench = {
        label = "Wrench", description = "Adjustable. For honest work, mostly.",
        weight = 1.2, stack = 1, icon = "wrench", category = "tool",
    },
    repairkit = {
        label = "Repair Kit", description = "Tape, clamps, a spare hose. Fixes a car enough to drive.",
        weight = 3.0, stack = 2, icon = "hammer", category = "tool",
    },
    battery = {
        label = "Power Cell", description = "Universal battery. Fits most street tech.",
        weight = 0.4, stack = 10, icon = "battery", category = "misc",
    },
    scrap = {
        label = "Scrap", description = "Recovered metal and electronics. Process four units into salvaged parts at the workshop.",
        weight = 1.0, stack = 50, icon = "box", category = "misc",
    },
    documents = {
        label = "Documents", description = "A folder of papers.",
        weight = 0.2, stack = 5, icon = "file-text", category = "document",
    },
    keycard = {
        label = "Keycard", description = "A building access card.",
        weight = 0.05, stack = 1, icon = "key-round", category = "document",
    },
    jerrycan = {
        label = "Jerrycan", description = "Use on foot beside a parked vehicle with its engine off. Pouring takes time; unused fuel stays in the can.",
        weight = 16.0, stack = 1, icon = "fuel", category = "tool",
        -- No instant effects: inventory routes this item to refueling.beginCan.
    },
    jerrycan_empty = {
        label = "Jerrycan (empty)", description = "An empty can. Any gas station pump refills it.",
        weight = 1.5, stack = 2, icon = "fuel", category = "tool",
    },
    -- The first day guide's practice activity (server/config/job_work.lua, job `tutorial`).
    practice_crate = {
        label = "Practice Crate", description = "A sealed crate from the arrival hall's job fair. Open it at the workbench.",
        weight = 3.0, stack = 5, icon = "package", category = "misc",
    },
    practice_parts = {
        label = "Practice Parts", description = "Sorted parts from a practice crate. The buyer at the job fair pays for them.",
        weight = 1.5, stack = 20, icon = "package-open", category = "material",
    },
    trashbag = {
        label = "Trash Bag", description = "Full. Heavy. Sort it at the recycling station to recover saleable materials.",
        weight = 4.0, stack = 5, icon = "package", category = "misc",
    },
    recyclables = {
        label = "Sorted Recyclables", description = "A sorted bundle recovered from waste. The recycling buyer pays for it.",
        weight = 2.0, stack = 20, icon = "package-open", category = "material",
    },
    delivery_order = {
        label = "Delivery Order", description = "A sealed bag for a customer. Keep it until the drop-off: it is not yours to eat or sell.",
        weight = 1.0, stack = 5, icon = "package", category = "misc",
    },
    -- Clothes taken away from a fitting room (server/modules/clothing.lua). Each
    -- unit carries its garment in metadata { label, record, slot, family, image };
    -- using one puts it on, or takes it off when it is already worn. Never consumed.
    clothing = {
        label = "Clothing", description = "A garment. Use it to put it on: whatever it replaces goes back in your bag.",
        weight = 0.4, stack = 1, icon = "shirt", category = "clothing",
    },
    -- A complete look { label = its name, pieces = { slot = record }, family, image }:
    -- using it changes into the whole outfit at once.
    outfit = {
        label = "Outfit", description = "A complete look, folded. Use it to change into it: the clothes it replaces go back in your bag.",
        weight = 1.2, stack = 1, icon = "shirt", category = "clothing",
    },
    salvaged_parts = {
        label = "Salvaged Parts", description = "Reusable parts recovered from scrap. Sell them at the salvage depot.",
        weight = 2.0, stack = 20, icon = "wrench", category = "material",
    },
    -- Cyberpunk TCG sealed product (resource op77_tcg; server/modules/tcg.lua). Using one opens the real thing: a
    -- booster tears open in your hands (on a table if you stand at one), a display has its shrink-wrap cut and its
    -- 24 boosters come out into this inventory. The cards go to the character's binder (F6, /binder).
    tcg_booster_wnc = {
        label = "TCG Booster · Night City", description = "A sealed Cyberpunk TCG Set Booster, Welcome to Night City: 12 cards (9 Common, 2 Uncommon and a Rare or better). Use it to tear it open; the cards go to your binder (F6).",
        weight = 0.03, stack = 48, icon = "package", category = "collectible", image = "img/items/tcg_booster_wnc.png",
    },
    tcg_booster_beta = {
        label = "TCG Booster · Beta", description = "A sealed Cyberpunk TCG Beta Edition booster: 12 cards (9 Common, 2 Uncommon and a Rare or better). Use it to tear it open; the cards go to your binder (F6).",
        weight = 0.03, stack = 48, icon = "package", category = "collectible", image = "img/items/tcg_booster_beta.png",
    },
    tcg_display_wnc = {
        label = "TCG Booster Display", description = "A shrink-wrapped display of 24 Welcome to Night City boosters. Use it to cut the wrap: the 24 boosters go to your inventory.",
        weight = 1.4, stack = 4, icon = "package", category = "collectible", image = "img/items/tcg_display_wnc.png",
    },
}

-- Existing names stay stable: saved inventories need no migration. Each template
-- has a local inventory illustration; the UI retains its icon fallback on error.
for _, name in ipairs({
    "water", "soda", "burrito", "synthmeat", "apple", "candy", "noodles", "dumplings", "pizza",
    "onigiri", "proteinbar", "coffee", "energydrink", "electrolyte", "juice", "bandage", "medkit", "firstaid",
    "cigarettes", "lighter", "phone", "idcard", "watch", "wrench", "repairkit", "battery", "scrap",
    "documents", "keycard", "jerrycan", "jerrycan_empty", "practice_crate", "practice_parts", "trashbag",
    "recyclables", "delivery_order", "salvaged_parts",
}) do
    LightRpItems[name].image = "img/items/" .. name .. ".png"
end
