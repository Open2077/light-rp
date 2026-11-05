-- Auto Studio: the stock components a kit part hides on each curated trim
-- (shared/vehicle_customization.lua `trims`), per dealer record and entity appearance.
--
-- vehicle_kit.lua is generated from fit tables measured on each record's DEFAULT (player)
-- appearance. A trim is another entity appearance with its own .app components: the
-- Archer Hella "Suburban" rims are wheel_*_01, not the player's wheel_01_*_a, so its stock
-- rims stayed visible under ours (in game 2026-11-05: skipped hide:wheel_01_bl_a:
-- component_absent). The platform resolves a fit by record only and setWheels / setParts
-- carry no hide list, so the server merges every list below into the record's `hide` when
-- it registers the kit (server/modules/vehicle_customization.lua): on any appearance, the
-- names it lacks are skipped by the client (one component_absent log line each, no
-- warning to the player).
--
-- Each entry is the complete hide list of that appearance. Measured offline from the game
-- archives (2.31 build, .app/.ent read with WolvenKit CLI 8.20, rims fitted with the
-- vehicle-kit measure-wheels fit on each appearance); checked: on every sold appearance,
-- the merged list hides only that appearance's own stock rims (never a tyre or panel).
-- Hand-maintained, not generated: a new trim needs its entry here (the kit test refuses
-- a sold trim without one). Kusanagi takes no rim (vehicle_kit.lua `excluded`).
LightRpVehicleKitTrims = {
    rims = {
        ["Vehicle.v_standard2_archer_hella_player"] = {
            archer_hella__basic_suburban_1 = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            archer_hella__basic_poor_1 = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            archer_hella__basic_poor_2 = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            archer_hella__basic_poor_3 = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            archer_hella__basic_poor_4 = { "police_wheel_01_bl_a", "police_wheel_01_br_0a", "police_wheel_01_fl_0a", "police_wheel_01_fr_0a" },
        },
        ["Vehicle.v_standard2_archer_quartz_player"] = {
            archer_quartz__basic_suburban_1 = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            archer_quartz__basic_urban_1 = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            archer_quartz__basic_poor_1 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            archer_quartz__basic_poor_2 = { "police_hella_wheel_bl", "police_hella_wheel_br", "police_hella_wheel_fl", "police_hella_wheel_fr" },
            archer_quartz__basic_poor_3 = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            archer_quartz__basic_poor_3_4 = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
        },
        ["Vehicle.v_standard2_villefort_cortes_player"] = {
            -- the front-right centre cap is named differently on this appearance
            villefort_cortes__basic_suburban_1_01 = { "wheel_01_bl_a", "wheel_01_bl_center", "wheel_01_br_a", "wheel_01_br_center",
                "wheel_01_fl_a", "wheel_01_fl_center", "wheel_01_fr_a", "wheel_01_fr_a6437" },
            villefort_cortes__basic_poor_1_01 = { "wheel_03_bl", "wheel_03_br", "wheel_03_fl", "wheel_03_fr" },
        },
        ["Vehicle.v_standard2_thorton_colby_player"] = {
            thorton_colby__basic_suburban_1 = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            thorton_colby__basic_suburban_2 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            thorton_colby__basic_urban_01 = { "wheel_bl_04", "wheel_br_04", "wheel_fl_04", "wheel_fr_04" },
            thorton_colby__basic_poor_2 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_standard2_thorton_galena_player"] = {
            thorton_galena__basic_suburban_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            thorton_galena__basic_gt_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            thorton_galena__basic_poor_01 = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            thorton_galena__basic_poor_09 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_standard2_makigai_maimai_player"] = {
            makigai_maimai__basic_suburban_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            makigai_maimai__basic_gt_01 = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            makigai_maimai__basic_poor_01 = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            makigai_maimai__basic_poor_02 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_standard2_mizutani_hozuki_player"] = {
            mizutani_hozuki__basic_urban_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_standard25_mahir_supron_player"] = {
            mahir_supron__basic_urban_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_standard25_villefort_columbus_player"] = {
            -- suburban_02's body_wheel_covers_01 is a rear fender skirt (Base slot, over the
            -- upper wheel): body, left in place.
            villefort_columbus__basic_suburban_01 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            villefort_columbus__basic_suburban_02 = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
        },
        ["Vehicle.v_sportbike3_brennan_apollo_player"] = {
            brennan_apollo_basic_player_02 = { "wheel_b_player_01", "wheel_f_player_01" },
        },
    },
    -- Body parts: per part id, then record and appearance. The generated lists already name
    -- the other trims' parts (E2, "names unknown on an entity are skipped"); only what a
    -- sold trim adds and the generated list misses is here.
    body = {
        roof_rack = {
            ["Vehicle.v_standard2_thorton_colby_player"] = {
                -- the solar-panel junk under the basket's footprint, as junk_solar on the
                -- other cars' racks; the player appearance has the factory rack instead
                thorton_colby__basic_suburban_2 = { "junk_solar" },
                thorton_colby__basic_poor_2 = { "junk_solar" },
            },
        },
    },
}
