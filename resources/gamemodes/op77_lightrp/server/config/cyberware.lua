-- Cyberware sold by LightRP ripperdocs. Server-owned: prices, grades and effects never reach the
-- client except as the catalogue the clinic shows.
--
-- Only implants the platform really applies are sold (kind):
--   legs      durable legs implant (Open77.cyberware, profile double_jump): Reinforced Tendons
--   arms      durable arms implant (Open77.cyberware, profile gorilla_arms): Gorilla Arms
--   blades    Mantis Blades: the arm weapon (ArmsCW), drawn with its own key
--   dash      Dash / Air Dash session grant (Open77.dash)
--   slam      Ground Slam session grant (Open77.abilities, profile ground_slam)
--   overdrive Sandevistan-style reflex overdrive session grant (Open77.reflex)
--   passive   stats on the body: max health, health regeneration, max stamina, stamina
--             regeneration, armor, no fall damage
--
-- Paid in eurodollars only (bank). Economy (2026-10-30, mission/raid rewards ignored on purpose,
-- they are not balanced yet): a working player earns about €$ 2,000-3,000 an hour (deliveries
-- 80-900 a run, rooftop maintenance 260 per 5-8 min, paychecks 40-150 per 30 min); cars cost
-- 4,000-60,000. An entry implant is ~3 h of work, a high-end one ~10 h, a legendary one 25 h or
-- more. No limit: anything can be fitted; a family is one native slot (arms, legs, dash,
-- overdrive...), so another model of it replaces the one installed.
LightRpCyberwareConfig = {
    enabled = true,
    removalFee = 250,          -- eddies to take an implant out (nothing is refunded)
    payFrom = "bank",          -- clinics charge the bank account
    seatedOnly = true,         -- operations only while lying on a ripperdoc chair
    keys = {
        blades = { id = "lightrp.cyberware.blades", name = "Light RP: Mantis Blades (draw / sheathe)", key = "B" },
    },
    -- Defaults of the platform actions (RegisterKeyMapping, rebindable in Pause > Settings > Key
    -- bindings). Not Z: it is "forward" on AZERTY keyboards.
    dashKey = "ctrl", slamKey = "g", overdriveKey = "x",

    -- `family`: one native slot -- another model of the family replaces the one installed.
    -- `section`/`icon`: how the clinic shows it (ripperdoc-ui sections, game cyberware icons).
    items = {
        -- Legs ---------------------------------------------------------------------------
        { id = "reinforced_tendons", name = "Reinforced Tendons", section = "legs", family = "legs_tendons",
          kind = "legs", grade = "training", rarity = "uncommon", tier = 2, price = 9500,
          maker = "Militech", icon = "cw_legs_boostedtendons",
          effect = "Double jump. A second jump in the air costs 15 stamina.",
          lore = "Springs where your ankles used to be.", stats = { { "Jumps", "2" }, { "Stamina / jump", "15" }, { "Cooldown", "0.8 s" } } },
        { id = "reinforced_tendons_mk2", name = "Reinforced Tendons Mk.2", section = "legs", family = "legs_tendons",
          kind = "legs", grade = "athlete", rarity = "epic", tier = 4, price = 24000, maker = "Militech", icon = "cw_legs_speed_iconic",
          effect = "Double jump, lighter and faster to recover.",
          lore = "Athlete-grade actuators. The second floor is the new first floor.", stats = { { "Jumps", "2" }, { "Stamina / jump", "8" }, { "Cooldown", "0.5 s" } } },
        { id = "fortified_ankles", name = "Fortified Ankles", section = "legs", family = "legs_ankles",
          kind = "passive", rarity = "rare", tier = 3, price = 11000,
          maker = "Arasaka", icon = "cw_legs_fortifiedankles", passive = { noFallDamage = true },
          effect = "No fall damage.", lore = "Built to land on roofs.", stats = { { "Fall damage", "None" } } },
        -- Arms (one implant: Gorilla Arms or Mantis Blades) --------------------------------
        { id = "gorilla_arms", name = "Gorilla Arms", section = "arms", family = "arms",
          kind = "arms", grade = "training", rarity = "rare", tier = 3, price = 15000,
          maker = "Militech", icon = "cw_arms_strongarms",
          effect = "Hydraulic fists: hold to charge a punch that throws people back. Non-lethal.",
          lore = "Hydraulic knuckles and a temper to match.", stats = { { "Punch", "15" }, { "Charged", "35" }, { "Knockback", "3.5 m" } } },
        { id = "gorilla_arms_mk2", name = "Gorilla Arms Mk.2", section = "arms", family = "arms",
          kind = "arms", grade = "industrial", rarity = "epic", tier = 4, price = 36000, maker = "Militech", icon = "cwf_armscyberwareshared3",
          effect = "Industrial fists: heavier punches, lethal charged hits.",
          lore = "Rated for demolition work. Nobody asks which kind.", stats = { { "Punch", "25" }, { "Charged", "60" }, { "Knockback", "4.5 m" } } },
        { id = "mantis_blades", name = "Mantis Blades", section = "arms", family = "arms",
          kind = "blades", record = "Items.MantisBlades", rarity = "epic", tier = 4, price = 28000,
          maker = "Arasaka", icon = "cw_arms_mantisblades",
          effect = "Forearm blades. Press B to draw or sheathe them (your weapons step aside).",
          lore = "Two arcs of monomolecular steel folded under the skin.", stats = { { "Weapon", "Arm blades" }, { "Key", "B" } } },
        { id = "mantis_blades_electric", name = "Electric Mantis Blades", section = "arms", family = "arms",
          kind = "blades", record = "Items.AdvancedMantisBladesElectricLegendaryPlusPlus", rarity = "legendary", tier = 5,
          price = 62000,
          maker = "Arasaka", icon = "cwf_electricdamageedge",
          effect = "Mantis Blades with an electric edge.",
          lore = "The edge sings. Then it bites.", stats = { { "Weapon", "Arm blades" }, { "Damage", "Electric" }, { "Key", "B" } } },
        -- Nervous system -------------------------------------------------------------------
        { id = "neofiber", name = "Neofiber Actuators", section = "nervous", family = "dash",
          kind = "dash", preset = "basic", rarity = "rare", tier = 3, price = 13000,
          maker = "Biotechnica", icon = "cw_nervoussystem_neofibre",
          effect = "Dash and air dash: hold a direction and tap Ctrl. One charge.",
          lore = "Fast-twitch fibres woven into every nerve.", stats = { { "Charges", "1" }, { "Stamina", "20" }, { "Recharge", "2.5 s" } } },
        { id = "neofiber_mk2", name = "Neofiber Actuators Mk.2", section = "nervous", family = "dash",
          kind = "dash", preset = "advanced", rarity = "epic", tier = 4, price = 30000, maker = "Biotechnica", icon = "cw_nervoussystem_synapticaccelerator",
          effect = "Dash and air dash with three charges, cheaper and faster.",
          lore = "Your reflexes, overclocked and unpaid.", stats = { { "Charges", "3" }, { "Stamina", "10" }, { "Recharge", "1.5 s" } } },
        -- Operating system -----------------------------------------------------------------
        { id = "sandevistan_mk1", name = "Sandevistan Mk.1", section = "operating_system", family = "overdrive",
          kind = "overdrive", preset = "street", rarity = "epic", tier = 4, price = 26000,
          maker = "Zetatech", icon = "cw_system_sandevistanc1",
          effect = "Reflex overdrive for 10 s: you move, swing and reload faster (press X).",
          lore = "The entry ticket to a faster you. The city keeps its own time.", stats = { { "Duration", "10 s" }, { "Cooldown", "13 s" }, { "Stamina", "25" } } },
        { id = "sandevistan_mk3", name = "Sandevistan Mk.3", section = "operating_system", family = "overdrive",
          kind = "overdrive", preset = "combat", rarity = "legendary", tier = 5, price = 64000, maker = "Dynalar", icon = "cw_system_sandevistanc3",
          effect = "Combat overdrive: a heavier boost, two charges.",
          lore = "What the edgerunners swear by.", stats = { { "Duration", "8 s" }, { "Charges", "2" }, { "Stamina", "40" } } },
        -- Skeleton -------------------------------------------------------------------------
        { id = "impact_frame", name = "Kinetic Impact Frame", section = "skeleton", family = "slam",
          kind = "slam", rarity = "epic", tier = 4, price = 18000,
          maker = "Kang Tao", icon = "cw_skeleton_shockabsorber",
          effect = "Ground Slam: in the air, press G to crash down and throw people around you. Non-lethal.",
          lore = "A frame that turns a fall into a weapon.", stats = { { "Damage", "35" }, { "Radius", "4 m" }, { "Cooldown", "5 s" } } },
        { id = "titanium_bones", name = "Titanium Bones", section = "skeleton", family = "bones",
          kind = "passive", rarity = "uncommon", tier = 2, price = 7500,
          maker = "Biotechnica", icon = "cw_skeleton_titaniuminfusedbones", passive = { healthMax = 25 },
          effect = "+25 max health.", lore = "Your skeleton, but tested at the factory.", stats = { { "Max health", "+25" } } },
        { id = "epimorphic_skeleton", name = "Epimorphic Skeleton", section = "skeleton", family = "bones",
          kind = "passive", rarity = "epic", tier = 4, price = 24000,
          maker = "Arasaka", icon = "cw_skeleton_endoskeleton", passive = { healthMax = 60 },
          effect = "+60 max health.", lore = "A frame that grows back stronger every time it breaks.", stats = { { "Max health", "+60" } } },
        -- Integumentary --------------------------------------------------------------------
        { id = "subdermal_armor", name = "Subdermal Armor", section = "integumentary", family = "armor",
          kind = "passive", rarity = "uncommon", tier = 2, price = 6500,
          maker = "Militech", icon = "cw_integumentary_subdermalarmorcommon", passive = { armor = 30 },
          effect = "+30 armor.", lore = "Weave plates under the skin. Bruises less, feels less.", stats = { { "Armor", "+30" } } },
        { id = "subdermal_armor_mk2", name = "Subdermal Armor Mk.2", section = "integumentary", family = "armor",
          kind = "passive", rarity = "epic", tier = 4, price = 16000,
          maker = "Militech", icon = "cw_integumentary_subdermalarmor_iconic", passive = { armor = 60 },
          effect = "+60 armor.", lore = "Military-grade weave. Still legal, mostly.", stats = { { "Armor", "+60" } } },
        -- Circulatory system ---------------------------------------------------------------
        { id = "biomonitor", name = "Biomonitor", section = "circulatory", family = "biomonitor",
          kind = "passive", rarity = "rare", tier = 3, price = 9000,
          maker = "Biotechnica", icon = "cw_circulatory_healthmonitor", passive = { healthRegen = 1.5 },
          effect = "Your health regenerates slowly (+1.5 / s).", lore = "Reads your vitals so you do not have to.", stats = { { "Health regen", "+1.5 / s" } } },
        { id = "iron_lungs", name = "Iron Lungs", section = "circulatory", family = "lungs",
          kind = "passive", rarity = "uncommon", tier = 2, price = 6000,
          maker = "Zetatech", icon = "cw_circulatory_ironlungs", passive = { staminaMax = 40 },
          effect = "+40 max stamina.", lore = "Breathe smog, exhale results.", stats = { { "Max stamina", "+40" } } },
        { id = "adrenaline_booster", name = "Adrenaline Booster", section = "circulatory", family = "pump",
          kind = "passive", rarity = "rare", tier = 3, price = 8500,
          maker = "Militech", icon = "cw_circulatory_bloodpump", passive = { staminaRegen = 8 },
          effect = "Stamina comes back faster (+8 / s).", lore = "A pressure cannon for your veins.", stats = { { "Stamina regen", "+8 / s" } } },
    },

    -- Platform definitions (immutable once registered: bump `version` when a grade changes).
    legsDefinition = { id = "lightrp.legs", version = 1, slot = "legs", profile = "double_jump", grades = {
        { id = "training", normalDamage = 0, chargedDamage = 0, knockbackMeters = 0, cooldownMs = 800, chargeMs = 650,
          jumpStaminaCost = 15, maxAirborneMs = 10000, maxFallSpeed = 30 },
        { id = "athlete", normalDamage = 0, chargedDamage = 0, knockbackMeters = 0, cooldownMs = 500, chargeMs = 650,
          jumpStaminaCost = 8, maxAirborneMs = 10000, maxFallSpeed = 30 },
    } },
    armsDefinition = { id = "lightrp.gorilla", version = 1, slot = "arms", profile = "gorilla_arms", grades = {
        { id = "training", normalDamage = 15, chargedDamage = 35, knockbackMeters = 3.5, cooldownMs = 800, chargeMs = 650, nonlethal = true, cosmetic = false },
        { id = "industrial", normalDamage = 25, chargedDamage = 60, knockbackMeters = 4.5, cooldownMs = 1000, chargeMs = 800, nonlethal = false, cosmetic = false },
    } },
    dashPresets = {
        basic = { staminaCost = 20, cooldownMs = 700, maxCharges = 1, chargeRegenMs = 2500 },
        advanced = { staminaCost = 10, cooldownMs = 450, maxCharges = 3, chargeRegenMs = 1500 },
    },
    overdrivePresets = {
        street = { tier = "reflex", durationMs = 10000, cooldownMs = 13000, maxCharges = 1, chargeRegenMs = 23000, staminaCost = 25 },
        combat = { tier = "reflex_heavy", durationMs = 8000, cooldownMs = 25000, maxCharges = 2, chargeRegenMs = 45000, staminaCost = 40 },
    },
    slam = { damage = 35, knockbackMeters = 1.5, staminaCost = 20, cooldownMs = 5000, radius = 4 },
}
