-- Item templates. Shared with clients (labels, icons, weights are public); the
-- server is the only side that moves items. Every inventory slot holds
-- { name, count, metadata }; `name` is a key of this table.
--
--   label        shown on the card
--   description  tooltip
--   weight       kilograms per unit
--   stack        max units per slot (1 = never stacks)
--   icon         Lucide icon name the page knows (see ui/src/design/components/Icon.tsx)
--   category     free tag for filters/shops (food, drink, medical, tool, document, misc)
--   use          nil = not usable; otherwise { consume = true, food = +n, drink = +n, health = +n, notice = "..." }
--                other modules can also hook a name with LightRP.inventory.onUse(name, fn)
LightRpItems = {
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
        label = "Scrap", description = "Bits of metal and plastic. Sells by the kilo.",
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
    trashbag = {
        label = "Trash Bag", description = "Full. Heavy. Somebody has to carry it.",
        weight = 4.0, stack = 5, icon = "package", category = "misc",
    },
}
