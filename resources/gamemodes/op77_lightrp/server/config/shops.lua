-- Server-owned shop templates. Locations reference a template ID, never a copy
-- of its catalogue. Edit here and restart the resource/server, or use
-- LightRP.shops.setTemplate(id, definition) for a live update of every linked NPC.
LightRpShops = {
    enabled = true,
    range = 2.5,
    sessionMs = 180000,
    maxLines = 12,
    maxPerItem = 20,
    templates = {
        street_food = {
            label = "Night City Market",
            subtitle = "Good food. Cold drinks. Back to the city.",
            payments = { "cash", "bank" },
            -- buy = player pays; sell = player receives. Omit either price to
            -- disable that direction. Supplies are unlimited, not fake stock.
            items = {
                { name = "chess_board", buy = 250, sell = 60 },
                { name = "checkers_board", buy = 150, sell = 35 },
                { name = "connect4_board", buy = 200, sell = 50 },
                { name = "roulette_table", buy = 800, sell = 200 },
                { name = "slot_machine", buy = 1200, sell = 300 },
                { name = "water", buy = 8, sell = 2 },
                { name = "burrito", buy = 18, sell = 5 },
                { name = "noodles", buy = 24, sell = 6 },
                { name = "dumplings", buy = 20, sell = 5 },
                { name = "pizza", buy = 16, sell = 4 },
                { name = "synthmeat", buy = 15, sell = 4 },
                { name = "onigiri", buy = 12, sell = 3 },
                { name = "apple", buy = 10, sell = 3 },
                { name = "candy", buy = 6, sell = 1 },
                { name = "proteinbar", buy = 14, sell = 3 },
                { name = "soda", buy = 10, sell = 2 },
                { name = "coffee", buy = 12, sell = 3 },
                { name = "juice", buy = 12, sell = 3 },
                { name = "energydrink", buy = 18, sell = 4 },
                { name = "electrolyte", buy = 16, sell = 4 },
            },
        },
    },
    locations = {
        {
            id = "citycenter_food", template = "street_food", name = "Corner Market / City Center",
            position = { x = -667.559082, y = -378.390808, z = 9.193733 },
            orientation = { x = 0.0, y = 0.0, z = -0.889405, w = 0.457121 },
            yaw = -125.597023, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        -- The shop of the arrival hall (first day guide, shared/tutorial.lua), in
        -- the hall's routing bucket: the newcomer's first real checkout.
        {
            id = "lobby_market", template = "street_food", name = "Market / Arrival Hall",
            position = { x = 6757.0, y = 2417.0, z = 400.03 },
            yaw = 90.0, bucket = 620000,
            npc = { record = "Character.mws_thenerves_driver_01" },
        },
    },
}
