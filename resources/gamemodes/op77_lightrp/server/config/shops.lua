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
            -- Eating and drinking cost ≈ 12 €$ an hour since needs drop 4x slower (2026-11-05): kept cheap on purpose.
            items = {
                { name = "water", buy = 12, sell = 2 },
                { name = "burrito", buy = 26, sell = 5 },
                { name = "noodles", buy = 36, sell = 6 },
                { name = "dumplings", buy = 30, sell = 5 },
                { name = "pizza", buy = 24, sell = 4 },
                { name = "synthmeat", buy = 22, sell = 4 },
                { name = "onigiri", buy = 18, sell = 3 },
                { name = "apple", buy = 15, sell = 3 },
                { name = "candy", buy = 9, sell = 1 },
                { name = "proteinbar", buy = 20, sell = 3 },
                { name = "soda", buy = 15, sell = 2 },
                { name = "coffee", buy = 18, sell = 3 },
                { name = "juice", buy = 18, sell = 3 },
                { name = "energydrink", buy = 26, sell = 4 },
                { name = "electrolyte", buy = 24, sell = 4 },
                -- Revives an unconscious ally (shared/medical.lua: never yourself). Priced
                -- under the 300 hospital bill so a friend with a kit beats "Give up";
                -- not bought back.
                { name = "trauma_kit", buy = 250 },
            },
        },
        -- Gun stores, one weapon family each (shared/armament.lua). On the 3D map each
        -- store shows its family's drawn icon (blip.map, client/core/map_icons.lua) in
        -- the "Gun stores" category (op77_map3d config). Serialized firearms:
        -- each purchase mints a server serial (armament); they are never bought back,
        -- a shop takes only plain items. Each store sells the ammunition its guns fire.
        gun_store = {
            label = "Night City Arms",
            subtitle = "Pistols and revolvers. Handgun ammunition. Cash or bank.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_lexington", buy = 1800 },
                { name = "weapon_unity", buy = 2100 },
                { name = "weapon_nue", buy = 2700 },
                { name = "weapon_overture", buy = 3750 },
                { name = "weapon_dr_5_nova", buy = 4200 },
                { name = "ammo_pistol_box", buy = 110, sell = 25 },
            },
        },
        smg_store = {
            label = "Rapid Fire",
            subtitle = "Submachine guns. They fire handgun ammunition.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_ds1_pulsar", buy = 3900 },
                { name = "weapon_m221_saratoga", buy = 4500 },
                { name = "weapon_tki_20_shingen", buy = 6300 },
                { name = "ammo_pistol_box", buy = 110, sell = 25 },
            },
        },
        shotgun_store = {
            label = "Twelve Gauge",
            subtitle = "Shotguns and shells. Close quarters only.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_crusher", buy = 4200 },
                { name = "weapon_m2038_tactician", buy = 5100 },
                { name = "weapon_carnage", buy = 5850 },
                { name = "weapon_l_69_zhuo", buy = 6900 },
                { name = "ammo_shotgun_box", buy = 135, sell = 30 },
            },
        },
        rifle_store = {
            label = "Frontline Surplus",
            subtitle = "Assault rifles and a light machine gun. Rifle ammunition.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_d5_copperhead", buy = 6300 },
                { name = "weapon_m251s_ajax", buy = 7200 },
                { name = "weapon_kyubi", buy = 7800 },
                { name = "weapon_hjsh_18_masamune", buy = 8400 },
                { name = "weapon_d5_sidewinder", buy = 9600 },
                { name = "weapon_m2067_defender", buy = 12750 },
                { name = "ammo_rifle_box", buy = 165, sell = 40 },
            },
        },
        marksman_store = {
            label = "Long Shot",
            subtitle = "Precision and sniper rifles. Precision rifles fire rifle rounds.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_kolac", buy = 7800 },
                { name = "weapon_m_179e_achilles", buy = 10200 },
                { name = "weapon_spt32_grad", buy = 12750 },
                { name = "weapon_nekomata", buy = 15750 },
                { name = "ammo_rifle_box", buy = 165, sell = 40 },
                { name = "ammo_sniper_box", buy = 225, sell = 55 },
            },
        },
        -- Cyberpunk TCG sealed product (op77_tcg; server/modules/tcg.lua): the items go to the inventory and are
        -- opened from there (or from the binder's Sealed tab: F1 menu > TCG binder). Sealed product is bought back at
        -- about a third (2026-11-05: a pack is a treat, not pocket change); a display is a little cheaper than its 24
        -- boosters, and 24 boosters sold back (3,600) never reach the display's price.
        tcg_shop = {
            label = "NEON DECK",
            subtitle = "Cyberpunk TCG boosters and displays. Cash or bank. Sealed product bought back.",
            payments = { "cash", "bank" },
            items = {
                { name = "tcg_booster_wnc", buy = 400, sell = 150 },
                { name = "tcg_booster_beta", buy = 600, sell = 220 },
                { name = "tcg_display_wnc", buy = 8500, sell = 3000 },
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
        -- Eight more general stores (food, drinks, essentials), poses taken in game by the owner (2026-11-05).
        -- District names are a best guess: rename freely (the ids stay).
        {
            id = "kabuki_food", template = "street_food", name = "Corner Market / Kabuki",
            position = { x = -784.378174, y = 775.958130, z = 22.580002 },
            orientation = { x = 0.0, y = 0.0, z = 0.460838, w = -0.887484 },
            yaw = -54.882416, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "heights_food", template = "street_food", name = "Corner Market / Japantown Heights",
            position = { x = -451.384583, y = 684.071472, z = 115.009598 },
            orientation = { x = 0.0, y = 0.0, z = 0.077504, w = -0.996992 },
            yaw = -8.890225, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "littlechina_food", template = "street_food", name = "Corner Market / Little China",
            position = { x = -1437.416016, y = 1257.382080, z = 23.090004 },
            orientation = { x = 0.0, y = 0.0, z = -0.365918, w = 0.930647 },
            yaw = -42.928188, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "northside_food", template = "street_food", name = "Corner Market / Northside",
            position = { x = -1172.608521, y = 2008.028320, z = 7.815666 },
            orientation = { x = 0.0, y = 0.0, z = -0.135961, w = 0.990714 },
            yaw = -15.628435, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "coastview_food", template = "street_food", name = "Corner Market / Coastview",
            position = { x = -1926.745361, y = -1913.365112, z = 49.303032 },
            orientation = { x = 0.0, y = 0.0, z = -0.842811, w = 0.538210 },
            yaw = -114.876320, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "westcoast_food", template = "street_food", name = "Corner Market / West Coast",
            position = { x = -2414.284180, y = -830.559326, z = 13.033760 },
            orientation = { x = 0.0, y = 0.0, z = -0.887320, w = 0.461155 },
            yaw = -125.076668, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "badlands_west_food", template = "street_food", name = "Corner Market / Badlands West",
            position = { x = -1843.343872, y = -4267.918457, z = 74.024536 },
            orientation = { x = 0.0, y = 0.0, z = 0.432543, w = -0.901613 },
            yaw = -51.258141, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "badlands_east_food", template = "street_food", name = "Corner Market / Badlands East",
            position = { x = 1637.943970, y = -799.452026, z = 53.805489 },
            orientation = { x = 0.0, y = 0.0, z = 0.149819, w = 0.988714 },
            yaw = 17.232893, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
            blip = { icon = "shopping-basket", sprite = "food", description = "Food, drinks and everyday essentials. Buy and sell here." },
        },
        {
            id = "gunstore_1", template = "gun_store", name = "Gun Store",
            position = { x = -907.380127, y = -708.114380, z = 8.237724 },
            orientation = { x = 0.0, y = 0.0, z = -0.279220, w = 0.960227 },
            yaw = -32.427353, bucket = 0,
            npc = { record = "Character.std_rcr_gunsmith_01" },
            blip = { icon = "crosshair", sprite = "guns", description = "Pistols and revolvers, handgun ammunition.",
                map = "pistol", mapCategory = "weapons", mapColor = "#FF7A1A" },
        },
        {
            id = "gunstore_2", template = "smg_store", name = "Rapid Fire",
            position = { x = -1450.029297, y = 1318.018677, z = 119.064896 },
            orientation = { x = 0.0, y = 0.0, z = 0.999599, w = 0.028313 },
            yaw = 176.755157, bucket = 0,
            npc = { record = "Character.std_rcr_gunsmith_01" },
            blip = { icon = "crosshair", sprite = "guns", description = "Submachine guns, handgun ammunition.",
                map = "smg", mapCategory = "weapons", mapColor = "#FF7A1A" },
        },
        {
            id = "gunstore_3", template = "shotgun_store", name = "Twelve Gauge",
            position = { x = -455.554413, y = 1454.145996, z = 37.379311 },
            orientation = { x = 0.0, y = 0.0, z = -0.917391, w = 0.397988 },
            yaw = -133.095093, bucket = 0,
            npc = { record = "Character.std_rcr_gunsmith_01" },
            blip = { icon = "crosshair", sprite = "guns", description = "Shotguns and shells.",
                map = "shotgun", mapCategory = "weapons", mapColor = "#FF7A1A" },
        },
        {
            id = "gunstore_4", template = "rifle_store", name = "Frontline Surplus",
            position = { x = -1773.528687, y = 225.227432, z = 43.727768 },
            orientation = { x = 0.0, y = 0.0, z = -0.891697, w = 0.452633 },
            yaw = -126.174515, bucket = 0,
            npc = { record = "Character.std_rcr_gunsmith_01" },
            blip = { icon = "crosshair", sprite = "guns", description = "Assault rifles, a light machine gun, rifle ammunition.",
                map = "rifle", mapCategory = "weapons", mapColor = "#FF7A1A" },
        },
        {
            id = "gunstore_5", template = "marksman_store", name = "Long Shot",
            position = { x = 1675.635498, y = -776.981140, z = 49.825127 },
            orientation = { x = 0.0, y = 0.0, z = 0.072213, w = -0.997389 },
            yaw = -8.282229, bucket = 0,
            npc = { record = "Character.std_rcr_gunsmith_01" },
            blip = { icon = "crosshair", sprite = "guns", description = "Precision and sniper rifles, their ammunition.",
                map = "sniper", mapCategory = "weapons", mapColor = "#FF7A1A" },
        },
        -- NEON DECK, the Cyberpunk TCG shop in the Kabuki market (world resource neon_deck, NCWE project
        -- E:/Open77/Maps/TCGShop): the clerk stands behind the checkout counter, by the register, facing the
        -- customers (pose measured in game). The map pin is the mapPlaces entry tcgshop_neon_deck on the street door.
        {
            id = "tcgshop_neon_deck", template = "tcg_shop", name = "NEON DECK",
            position = { x = -814.122498, y = 933.517334, z = 12.139999 },
            orientation = { x = 0.0, y = 0.0, z = 0.061173, w = 0.998127 },
            yaw = 7.014237, bucket = 0,
            npc = { record = "Character.mws_thenerves_driver_01" },
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
