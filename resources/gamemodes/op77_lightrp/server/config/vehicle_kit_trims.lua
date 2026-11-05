-- Auto Studio: the kit rim fit of each curated trim (shared/vehicle_customization.lua
-- `trims`), per dealer record and entity appearance, in the platform's `fit.appearances`
-- shape: rims[record] is the `appearances` table of that record's rim fit.
--
-- vehicle_kit.lua is generated from fits measured on each record's DEFAULT (player)
-- appearance. A trim is another entity appearance with its own stock rims and often its
-- own tyres: other component names (Archer Hella "Suburban": wheel_*_01, not
-- wheel_01_*_a, so its stock rims stayed visible under ours; in game 2026-11-05) and other
-- sizes (the same Hella's rim face sits 9-10 cm deeper). Each entry replaces only the
-- fields it gives (the others come from the record fit); `wheels` replaces the record's
-- whole list, so every wheel carries its own offset and scale here.
--
-- Measured offline from the game archives (2.31 build; .app/.ent/.rig/meshes read with
-- WolvenKit CLI 8.20), with the vehicle-kit measure-wheels fit run on each appearance:
-- the lip on the trim's own stock rim lip (capped by its tyre bead), the face flush with
-- its own stock rim face. A trim gets offset/scale/wheels only where one of its wheels
-- moves more than 1 cm or scales more than 3 % against the record fit; every trim gets
-- its own `hide` (its stock rims only, never a tyre or a panel).
--
-- A server without per-appearance fits refuses `appearances`: the studio then registers
-- the record fit alone with every trim's hide names merged into it (a name an appearance
-- lacks is skipped by the client), so the stock rims stay hidden and the rim keeps the
-- default fit. Hand-maintained, not generated: a new trim needs its entry here (the kit
-- test refuses a sold trim without one). Kusanagi takes no rim (vehicle_kit.lua `excluded`).
LightRpVehicleKitTrims = {
    rims = {
        ["Vehicle.v_standard2_makigai_maimai_player"] = {
            makigai_maimai__basic_gt_01 = { hide = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" } },
            makigai_maimai__basic_poor_01 = {
                offset = { 0.0401, 0, 0 },
                scale = { 0.5857, 0.5857, 0.5857 },
                hide = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            },
            makigai_maimai__basic_poor_02 = {
                offset = { -0.0248, 0, 0 },
                scale = { 0.5857, 0.5857, 0.5857 },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            makigai_maimai__basic_suburban_01 = {
                offset = { -0.0248, 0, 0 },
                scale = { 0.5857, 0.5857, 0.5857 },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
        },
        ["Vehicle.v_standard2_thorton_galena_player"] = {
            thorton_galena__basic_gt_01 = {
                offset = { -0.0873, 0, 0 },
                scale = { 0.91, 0.91, 0.91 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0873, 0, 0 }, scale = { 0.91, 0.91, 0.91 } },
                    { slot = "wheel_front_right", offset = { -0.0873, 0, 0 }, scale = { 0.91, 0.91, 0.91 } },
                    { slot = "wheel_back_left", offset = { -0.0873, 0, 0 }, scale = { 0.91, 0.91, 0.91 } },
                    { slot = "wheel_back_right", offset = { -0.0873, 0, 0 }, scale = { 0.91, 0.91, 0.91 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            thorton_galena__basic_poor_01 = {
                offset = { -0.0305, 0, 0 },
                scale = { 0.8118, 0.8118, 0.8118 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0305, 0, 0 }, scale = { 0.8118, 0.8118, 0.8118 } },
                    { slot = "wheel_front_right", offset = { -0.0205, 0, 0 }, scale = { 0.8118, 0.8118, 0.8118 } },
                    { slot = "wheel_back_left", offset = { -0.0205, 0, 0 }, scale = { 0.8118, 0.8118, 0.8118 } },
                    { slot = "wheel_back_right", offset = { -0.0205, 0, 0 }, scale = { 0.8118, 0.8118, 0.8118 } },
                },
                hide = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            },
            thorton_galena__basic_poor_09 = {
                offset = { -0.0141, 0, 0 },
                scale = { 0.8436, 0.8436, 0.8436 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0141, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_front_right", offset = { -0.0141, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_back_left", offset = { -0.0141, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_back_right", offset = { -0.0141, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            thorton_galena__basic_suburban_01 = {
                offset = { -0.0092, 0, 0 },
                scale = { 0.8436, 0.8436, 0.8436 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0092, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_front_right", offset = { -0.0092, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_back_left", offset = { -0.0092, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                    { slot = "wheel_back_right", offset = { -0.0092, 0, 0 }, scale = { 0.8436, 0.8436, 0.8436 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
        },
        ["Vehicle.v_sportbike3_brennan_apollo_player"] = {
            brennan_apollo_basic_player_02 = {
                offset = { 0.029, 0, 0 },
                scale = { 0.5, 0.7943, 0.7943 },
                wheels = {
                    { slot = "wheel_front_rot_set", offset = { 0.029, 0, 0 }, scale = { 0.5, 0.7943, 0.7943 } },
                    { slot = "axle_back_wheel", offset = { 0.0369, 0, 0 }, scale = { 0.645, 0.7486, 0.7486 } },
                },
                hide = { "wheel_b_player_01", "wheel_f_player_01" },
            },
        },
        ["Vehicle.v_standard2_archer_hella_player"] = {
            archer_hella__basic_poor_1 = {
                offset = { -0.0316, 0, 0 },
                scale = { 0.845, 0.845, 0.845 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0316, 0, 0 }, scale = { 0.845, 0.845, 0.845 } },
                    { slot = "wheel_front_right", offset = { -0.0316, 0, 0 }, scale = { 0.845, 0.845, 0.845 } },
                    { slot = "wheel_back_left", offset = { -0.0316, 0, 0 }, scale = { 0.845, 0.845, 0.845 } },
                    { slot = "wheel_back_right", offset = { -0.0316, 0, 0 }, scale = { 0.845, 0.845, 0.845 } },
                },
                hide = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            },
            archer_hella__basic_poor_2 = {
                offset = { -0.0062, 0, 0 },
                scale = { 0.9846, 0.9846, 0.9846 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_front_right", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_left", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_right", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                },
                hide = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            },
            archer_hella__basic_poor_3 = {
                offset = { -0.0062, 0, 0 },
                scale = { 0.9846, 0.9846, 0.9846 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_front_right", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_left", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_right", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                },
                hide = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            },
            archer_hella__basic_poor_4 = {
                offset = { -0.0129, 0, 0 },
                scale = { 0.9275, 0.9275, 0.9275 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0129, 0, 0 }, scale = { 0.9275, 0.9275, 0.9275 } },
                    { slot = "wheel_front_right", offset = { -0.0129, 0, 0 }, scale = { 0.9275, 0.9275, 0.9275 } },
                    { slot = "wheel_back_left", offset = { -0.0129, 0, 0 }, scale = { 0.9275, 0.9275, 0.9275 } },
                    { slot = "wheel_back_right", offset = { -0.0129, 0, 0 }, scale = { 0.9275, 0.9275, 0.9275 } },
                },
                hide = { "police_wheel_01_bl_a", "police_wheel_01_br_0a", "police_wheel_01_fl_0a", "police_wheel_01_fr_0a" },
            },
            archer_hella__basic_suburban_1 = {
                offset = { -0.0062, 0, 0 },
                scale = { 0.9846, 0.9846, 0.9846 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_front_right", offset = { -0.0062, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_left", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                    { slot = "wheel_back_right", offset = { -0.038, 0, 0 }, scale = { 0.9846, 0.9846, 0.9846 } },
                },
                hide = { "wheel_bl_01", "wheel_br_01", "wheel_fl_01", "wheel_fr_01" },
            },
        },
        ["Vehicle.v_standard2_thorton_colby_player"] = {
            thorton_colby__basic_poor_2 = {
                offset = { 0.0902, 0, 0 },
                scale = { 0.9011, 0.9011, 0.9011 },
                wheels = {
                    { slot = "wheel_front_left", offset = { 0.0902, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_front_right", offset = { 0.0902, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_left", offset = { 0.0202, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_right", offset = { 0.0202, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            thorton_colby__basic_suburban_1 = {
                offset = { 0.1025, 0, 0 },
                scale = { 0.9011, 0.9011, 0.9011 },
                wheels = {
                    { slot = "wheel_front_left", offset = { 0.1025, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_front_right", offset = { 0.1025, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_left", offset = { 0.0325, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_right", offset = { 0.0325, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                },
                hide = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            },
            thorton_colby__basic_suburban_2 = {
                offset = { 0.0902, 0, 0 },
                scale = { 0.9011, 0.9011, 0.9011 },
                wheels = {
                    { slot = "wheel_front_left", offset = { 0.0902, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_front_right", offset = { 0.0902, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_left", offset = { 0.0202, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                    { slot = "wheel_back_right", offset = { 0.0202, 0, 0 }, scale = { 0.9011, 0.9011, 0.9011 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            thorton_colby__basic_urban_01 = { hide = { "wheel_bl_04", "wheel_br_04", "wheel_fl_04", "wheel_fr_04" } },
        },
        ["Vehicle.v_standard2_archer_quartz_player"] = {
            archer_quartz__basic_poor_1 = {
                offset = { -0.0718, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0718, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0718, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0718, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0718, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            archer_quartz__basic_poor_2 = {
                offset = { -0.0646, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0646, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0646, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0646, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0646, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "police_hella_wheel_bl", "police_hella_wheel_br", "police_hella_wheel_fl", "police_hella_wheel_fr" },
            },
            archer_quartz__basic_poor_3 = {
                offset = { -0.0759, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            },
            archer_quartz__basic_poor_3_4 = {
                offset = { -0.0759, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            },
            archer_quartz__basic_suburban_1 = {
                offset = { -0.0759, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0759, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_bl_03", "wheel_br_03", "wheel_fl_03", "wheel_fr_03" },
            },
            archer_quartz__basic_urban_1 = {
                offset = { -0.0753, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { -0.0753, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { -0.0753, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { -0.0753, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { -0.0753, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_bl_02", "wheel_br_02", "wheel_fl_02", "wheel_fr_02" },
            },
        },
        ["Vehicle.v_standard2_mizutani_hozuki_player"] = {
            mizutani_hozuki__basic_urban_01 = {
                offset = { 0.0641, 0, 0 },
                scale = { 0.9789, 0.9789, 0.9789 },
                wheels = {
                    { slot = "wheel_front_left", offset = { 0.0641, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_front_right", offset = { 0.0541, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_left", offset = { 0.0541, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                    { slot = "wheel_back_right", offset = { 0.0641, 0, 0 }, scale = { 0.9789, 0.9789, 0.9789 } },
                },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
        },
        ["Vehicle.v_standard25_mahir_supron_player"] = {
            mahir_supron__basic_urban_01 = {
                offset = { -0.0307, 0, 0 },
                scale = { 0.91, 0.91, 0.91 },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
        },
        ["Vehicle.v_standard25_villefort_columbus_player"] = {
            -- suburban_02's body_wheel_covers_01 is a rear fender skirt (Base slot, over the
            -- upper wheel): body, left in place.
            villefort_columbus__basic_suburban_01 = {
                offset = { 0.0549, 0, 0 },
                scale = { 0.9661, 0.9661, 0.9661 },
                hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
            },
            villefort_columbus__basic_suburban_02 = { hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" } },
        },
        ["Vehicle.v_standard2_villefort_cortes_player"] = {
            villefort_cortes__basic_poor_1_01 = {
                offset = { -0.0248, 0, 0 },
                scale = { 0.9782, 0.9782, 0.9782 },
                hide = { "wheel_03_bl", "wheel_03_br", "wheel_03_fl", "wheel_03_fr" },
            },
            -- the front-right centre cap is named differently on this appearance
            villefort_cortes__basic_suburban_1_01 = { hide = { "wheel_01_bl_a", "wheel_01_bl_center", "wheel_01_br_a", "wheel_01_br_center", "wheel_01_fl_a", "wheel_01_fl_center", "wheel_01_fr_a", "wheel_01_fr_a6437" } },
        },
    },
    -- Body parts: names a sold trim adds to a part's hide list, per part id, record and
    -- appearance, merged into the record fit on every server (E2's generated lists already
    -- name the other trims' parts: "names unknown on an entity are skipped").
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
