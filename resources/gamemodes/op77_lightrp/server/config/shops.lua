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
            -- Eating and drinking cost ≈ 50 €$ an hour (docs/economy-balance.md).
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
                { name = "weapon_lexington", buy = 1200 },
                { name = "weapon_unity", buy = 1400 },
                { name = "weapon_nue", buy = 1800 },
                { name = "weapon_overture", buy = 2500 },
                { name = "weapon_dr_5_nova", buy = 2800 },
                { name = "ammo_pistol_box", buy = 75, sell = 20 },
            },
        },
        smg_store = {
            label = "Rapid Fire",
            subtitle = "Submachine guns. They fire handgun ammunition.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_ds1_pulsar", buy = 2600 },
                { name = "weapon_m221_saratoga", buy = 3000 },
                { name = "weapon_tki_20_shingen", buy = 4200 },
                { name = "ammo_pistol_box", buy = 75, sell = 20 },
            },
        },
        shotgun_store = {
            label = "Twelve Gauge",
            subtitle = "Shotguns and shells. Close quarters only.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_crusher", buy = 2800 },
                { name = "weapon_m2038_tactician", buy = 3400 },
                { name = "weapon_carnage", buy = 3900 },
                { name = "weapon_l_69_zhuo", buy = 4600 },
                { name = "ammo_shotgun_box", buy = 90, sell = 22 },
            },
        },
        rifle_store = {
            label = "Frontline Surplus",
            subtitle = "Assault rifles and a light machine gun. Rifle ammunition.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_d5_copperhead", buy = 4200 },
                { name = "weapon_m251s_ajax", buy = 4800 },
                { name = "weapon_kyubi", buy = 5200 },
                { name = "weapon_hjsh_18_masamune", buy = 5600 },
                { name = "weapon_d5_sidewinder", buy = 6400 },
                { name = "weapon_m2067_defender", buy = 8500 },
                { name = "ammo_rifle_box", buy = 110, sell = 27 },
            },
        },
        marksman_store = {
            label = "Long Shot",
            subtitle = "Precision and sniper rifles. Precision rifles fire rifle rounds.",
            payments = { "cash", "bank" },
            items = {
                { name = "weapon_kolac", buy = 5200 },
                { name = "weapon_m_179e_achilles", buy = 6800 },
                { name = "weapon_spt32_grad", buy = 8500 },
                { name = "weapon_nekomata", buy = 10500 },
                { name = "ammo_rifle_box", buy = 110, sell = 27 },
                { name = "ammo_sniper_box", buy = 150, sell = 37 },
            },
        },
        -- Cyberpunk TCG sealed product (op77_tcg; server/modules/tcg.lua): the items go to the inventory and are
        -- opened from there (or from the binder's Sealed tab: F1 menu > TCG binder). Sealed product is bought back at half price;
        -- a display is a little cheaper than its 24 boosters.
        tcg_shop = {
            label = "NEON DECK",
            subtitle = "Cyberpunk TCG boosters and displays. Cash or bank. Sealed product bought back at half price.",
            payments = { "cash", "bank" },
            items = {
                { name = "tcg_booster_wnc", buy = 120, sell = 60 },
                { name = "tcg_booster_beta", buy = 180, sell = 90 },
                { name = "tcg_display_wnc", buy = 2600, sell = 1300 },
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
