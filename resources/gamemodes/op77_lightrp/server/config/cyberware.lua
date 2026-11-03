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
--   berserk   Berserk (key X): a timed layer of armor and health regeneration (Open77.players.setArmor,
--             Open77.stats.setRegenRate), server timer, cooldown
--   pain      Pain Editor: health regeneration for a few seconds when a hit leaves the body under a
--             threshold (open77:playerDamaged), once a minute
--   second_heart  Second Heart: a downed player (medical) gets back up by himself (Open77.players.revive)
--   optics    Kiroshi optics: ALT + click a player or an NPC, Scan (and Mark for crew on the
--             Clairvoyant): server-checked range, answer as a notice; the mark is an op77_map3d blip
--             plus an arrow marker for the crew
-- server/modules/cyberware_active.lua runs berserk / pain / second_heart / optics.
--
-- Paid in eurodollars only (bank). Economy (2026-10-30, mission/raid rewards ignored on purpose,
-- they are not balanced yet): a working player earns about €$ 2,000-3,000 an hour (deliveries
-- 80-900 a run, rooftop maintenance 260 per 5-8 min, paychecks 40-150 per 30 min); cars cost
-- 4,000-60,000. An entry implant is ~3 h of work, a high-end one ~10 h, a legendary one 25 h or
-- more. A family is one native slot (arms, legs, dash, operating system...), so another model of
-- it replaces the one installed; the one taken out goes to the character's implant storage.
--
-- Capacity (docs/economy-balance.md, section 13): every implant costs `capacity` points and the
-- body holds `capacity.byTier[reputation tier]` of them (rank II 10, III 14, IV 18, V 22, V+ 26).
-- The best implant of every family adds up to far more than 26: a build is a choice (tank,
-- mobility, support, brawler). A character already over it keeps what is fitted but fits nothing
-- more until under it (logged on load).
--
-- Storage: an implant bought is the character's for good. Taking it out (fittingFee) puts it in
-- storage; fitting it again from storage costs fittingFee, not the price. Buying includes the
-- fitting; a family mate it replaces goes to storage for free. No resale, no trade.
--
-- `tier` is the implant's rank, 1-6 (6 shows as V+). Street cred (the reputation tiers of
-- server/config/missions.lua, earned in PvE only) opens the ranks: `gating.byRank` maps a rank
-- to the reputation tier it needs, an item's own `repTier` overrides it. The server refuses
-- the install below it (removal always works, an implant already fitted stays active, the
-- staff command `lightrp.cyberware give` ignores it). docs/pve-progression.md.
LightRpCyberwareConfig = {
    enabled = true,
    gating = { enabled = true, byRank = { [1] = 1, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5 } },
    -- Implants inside a PvP activity (ranked arena, races, chases, turf PvP): true keeps them
    -- (today's behaviour); false suspends the session grants (dash, overdrive, slam) and the
    -- passive stats while the player is in a non-PvE activity. Durable legs / arms stay.
    -- An owner decision (docs/pve-progression.md, section 8).
    activeInPvp = true,
    -- One surgery without a purchase: fitting an implant from storage, or taking one out to
    -- storage. Buying a new implant includes its fitting. (Was a 250 removal fee that destroyed
    -- the implant, until 2026-11-03.)
    fittingFee = 50,
    removalFee = 50,           -- = fittingFee; kept for older pages and guide placeholders
    capacity = {
        enabled = true,
        -- reputation tier (server/config/missions.lua: Street, Merc, Operator, Edgerunner,
        -- Legend) -> capacity points: the tier that opens rank II, III, IV, V, V+
        byTier = { 10, 14, 18, 22, 26 },
        -- without a readable reputation (no missions module): the top one, a limit that locks
        -- nobody out
        fallback = 26,
    },
    payFrom = "bank",          -- clinics charge the bank account
    seatedOnly = true,         -- operations only while lying on a ripperdoc chair
    keys = {
        blades = { id = "lightrp.cyberware.blades", name = "Light RP: Mantis Blades (draw / sheathe)", key = "B" },
        -- Berserk shares the operating system with the Sandevistans (one of them fitted), so X
        -- is free for it. Also the animation stop key: stopping an emote with X while a Berserk
        -- is fitted triggers it too.
        berserk = { id = "lightrp.cyberware.berserk", name = "Light RP: Berserk", key = "X" },
    },
    -- Kiroshi optics (ALT + click): server-checked ranges and timings.
    optics = {
        -- ALT + click reaches what the camera ray hits (open77_contextmenu: 12 m); the server
        -- allows a margin for movement.
        scanRange = 25,          -- metres, scanner to target, same routing bucket
        scanCooldownMs = 2000,
        markRange = 25,
        markUpdateMs = 500,      -- how often the crew's blip and arrow follow the target
        markColor = "#FF3B3B",
    },
    -- Defaults of the platform actions (RegisterKeyMapping, rebindable in Pause > Settings > Key
    -- bindings). Not Z: it is "forward" on AZERTY keyboards.
    dashKey = "ctrl", slamKey = "g", overdriveKey = "x",

    -- `family`: one native slot -- another model of the family replaces the one installed.
    -- `section`/`icon`: how the clinic shows it (ripperdoc-ui sections, game cyberware icons).
    -- `capacity`: the points it takes (above). Sandevistans and Berserks share the family "os".
    items = {
        -- Eyes (the clinic's Ocular System) ----------------------------------------------
        { id = "kiroshi_optics", name = "Kiroshi Optics", section = "ocular", family = "optics",
          kind = "optics", rarity = "uncommon", tier = 2, price = 7000, capacity = 1,
          maker = "Kiroshi", icon = "cw_eyes_kiroshioptics", scan = true,
          effect = "ALT + click a player or an NPC, then Scan: name, crew and bounty.",
          lore = "Every face in the city comes with a caption now.", stats = { { "Scan", "ALT + click" }, { "Reads", "Name, crew, bounty" } } },
        { id = "kiroshi_clairvoyant", name = "Kiroshi Clairvoyant", section = "ocular", family = "optics",
          kind = "optics", rarity = "epic", tier = 4, price = 22000, capacity = 3,
          maker = "Kiroshi", icon = "cw_eyes_3eye", scan = true, mark = { durationMs = 10000, cooldownMs = 30000 },
          effect = "Scan, and Mark for crew: your whole crew sees the target for 10 s, on the map and above its head.",
          lore = "Paints a target on someone. Your friends bring the brushes.", stats = { { "Scan", "ALT + click" }, { "Mark", "10 s, crew" }, { "Cooldown", "30 s" } } },
        -- Legs ---------------------------------------------------------------------------
        { id = "reinforced_tendons", name = "Reinforced Tendons", section = "legs", family = "legs_tendons",
          kind = "legs", grade = "training", rarity = "uncommon", tier = 2, price = 9500, capacity = 3,
          maker = "Militech", icon = "cw_legs_boostedtendons",
          effect = "Double jump. A second jump in the air costs 15 stamina.",
          lore = "Springs where your ankles used to be.", stats = { { "Jumps", "2" }, { "Stamina / jump", "15" }, { "Cooldown", "0.8 s" } } },
        { id = "reinforced_tendons_mk2", name = "Reinforced Tendons Mk.2", section = "legs", family = "legs_tendons",
          kind = "legs", grade = "athlete", rarity = "epic", tier = 4, price = 24000, capacity = 4, maker = "Militech", icon = "cw_legs_speed_iconic",
          effect = "Double jump, lighter and faster to recover.",
          lore = "Athlete-grade actuators. The second floor is the new first floor.", stats = { { "Jumps", "2" }, { "Stamina / jump", "8" }, { "Cooldown", "0.5 s" } } },
        { id = "fortified_ankles", name = "Fortified Ankles", section = "legs", family = "legs_ankles",
          kind = "passive", rarity = "rare", tier = 3, price = 11000, capacity = 2,
          maker = "Arasaka", icon = "cw_legs_fortifiedankles", passive = { noFallDamage = true },
          effect = "No fall damage.", lore = "Built to land on roofs.", stats = { { "Fall damage", "None" } } },
        -- Arms (one implant: Gorilla Arms or Mantis Blades) --------------------------------
        { id = "gorilla_arms", name = "Gorilla Arms", section = "arms", family = "arms",
          kind = "arms", grade = "training", rarity = "rare", tier = 3, price = 15000, capacity = 3,
          maker = "Militech", icon = "cw_arms_strongarms",
          effect = "Hydraulic fists: hold to charge a punch that throws people back. Non-lethal.",
          lore = "Hydraulic knuckles and a temper to match.", stats = { { "Punch", "15" }, { "Charged", "35" }, { "Knockback", "3.5 m" } } },
        { id = "gorilla_arms_mk2", name = "Gorilla Arms Mk.2", section = "arms", family = "arms",
          kind = "arms", grade = "industrial", rarity = "epic", tier = 4, price = 36000, capacity = 5, maker = "Militech", icon = "cwf_armscyberwareshared3",
          effect = "Industrial fists: heavier punches, lethal charged hits.",
          lore = "Rated for demolition work. Nobody asks which kind.", stats = { { "Punch", "25" }, { "Charged", "60" }, { "Knockback", "4.5 m" } } },
        { id = "mantis_blades", name = "Mantis Blades", section = "arms", family = "arms",
          kind = "blades", record = "Items.MantisBlades", rarity = "epic", tier = 4, price = 28000, capacity = 5,
          maker = "Arasaka", icon = "cw_arms_mantisblades",
          effect = "Forearm blades. Press B to draw or sheathe them (your weapons step aside).",
          lore = "Two arcs of monomolecular steel folded under the skin.", stats = { { "Weapon", "Arm blades" }, { "Key", "B" } } },
        { id = "mantis_blades_electric", name = "Electric Mantis Blades", section = "arms", family = "arms",
          kind = "blades", record = "Items.AdvancedMantisBladesElectricLegendaryPlusPlus", rarity = "legendary", tier = 5,
          price = 62000, capacity = 6,
          maker = "Arasaka", icon = "cwf_electricdamageedge",
          effect = "Mantis Blades with an electric edge.",
          lore = "The edge sings. Then it bites.", stats = { { "Weapon", "Arm blades" }, { "Damage", "Electric" }, { "Key", "B" } } },
        -- Nervous system -------------------------------------------------------------------
        { id = "neofiber", name = "Neofiber Actuators", section = "nervous", family = "dash",
          kind = "dash", preset = "basic", rarity = "rare", tier = 3, price = 13000, capacity = 3,
          maker = "Biotechnica", icon = "cw_nervoussystem_neofibre",
          effect = "Dash and air dash: hold a direction and tap Ctrl. One charge.",
          lore = "Fast-twitch fibres woven into every nerve.", stats = { { "Charges", "1" }, { "Stamina", "20" }, { "Recharge", "2.5 s" } } },
        { id = "neofiber_mk2", name = "Neofiber Actuators Mk.2", section = "nervous", family = "dash",
          kind = "dash", preset = "advanced", rarity = "epic", tier = 4, price = 30000, capacity = 4, maker = "Biotechnica", icon = "cw_nervoussystem_synapticaccelerator",
          effect = "Dash and air dash with three charges, cheaper and faster.",
          lore = "Your reflexes, overclocked and unpaid.", stats = { { "Charges", "3" }, { "Stamina", "10" }, { "Recharge", "1.5 s" } } },
        { id = "pain_editor", name = "Pain Editor", section = "nervous", family = "pain_editor",
          kind = "pain", rarity = "rare", tier = 3, price = 12000, capacity = 3,
          maker = "Biotechnica", icon = "cw_skeleton_paineditor",
          pain = { threshold = 0.30, regen = 4, durationMs = 6000, cooldownMs = 60000 },
          effect = "A hit that leaves you under 30% health starts a repair: +4 health / s for 6 s. Once a minute.",
          lore = "Files the pain under 'later'. Later never comes.", stats = { { "Trigger", "Under 30% health" }, { "Repair", "+4 / s, 6 s" }, { "Cooldown", "60 s" } } },
        -- Operating system (one: a Sandevistan or a Berserk) --------------------------------
        { id = "sandevistan_mk1", name = "Sandevistan Mk.1", section = "operating_system", family = "os",
          kind = "overdrive", preset = "street", rarity = "epic", tier = 4, price = 26000, capacity = 5,
          maker = "Zetatech", icon = "cw_system_sandevistanc1",
          effect = "Reflex overdrive for 10 s: you move, swing and reload faster (press X).",
          lore = "The entry ticket to a faster you. The city keeps its own time.", stats = { { "Duration", "10 s" }, { "Cooldown", "13 s" }, { "Stamina", "25" } } },
        { id = "sandevistan_mk3", name = "Sandevistan Mk.3", section = "operating_system", family = "os",
          kind = "overdrive", preset = "combat", rarity = "legendary", tier = 5, price = 64000, capacity = 7, maker = "Dynalar", icon = "cw_system_sandevistanc3",
          effect = "Combat overdrive: a heavier boost, two charges.",
          lore = "What the edgerunners swear by.", stats = { { "Duration", "8 s" }, { "Charges", "2" }, { "Stamina", "40" } } },
        { id = "berserk_mk1", name = "Berserk Mk.1", section = "operating_system", family = "os",
          kind = "berserk", rarity = "epic", tier = 4, price = 26000, capacity = 5,
          maker = "Moore Tech", icon = "cw_system_berserkc1",
          berserk = { durationMs = 8000, armor = 80, regen = 4, cooldownMs = 30000 },
          effect = "Press X: 8 s of +80 armor and +4 health / s. Cooldown 30 s. The extra armor goes first and does not stay.",
          lore = "Pain becomes a rumour. Bullets become a suggestion.", stats = { { "Duration", "8 s" }, { "Armor", "+80" }, { "Regen", "+4 / s" }, { "Cooldown", "30 s" } } },
        { id = "berserk_mk3", name = "Berserk Mk.3", section = "operating_system", family = "os",
          kind = "berserk", rarity = "legendary", tier = 5, price = 64000, capacity = 7,
          maker = "Moore Tech", icon = "cw_system_berserkc3",
          berserk = { durationMs = 10000, armor = 150, regen = 6, cooldownMs = 30000 },
          effect = "Press X: 10 s of +150 armor and +6 health / s. Cooldown 30 s.",
          lore = "The model the fixers rent out to people they never want to see again.", stats = { { "Duration", "10 s" }, { "Armor", "+150" }, { "Regen", "+6 / s" }, { "Cooldown", "30 s" } } },
        -- Skeleton -------------------------------------------------------------------------
        { id = "impact_frame", name = "Kinetic Impact Frame", section = "skeleton", family = "slam",
          kind = "slam", rarity = "epic", tier = 4, price = 18000, capacity = 4,
          maker = "Kang Tao", icon = "cw_skeleton_shockabsorber",
          effect = "Ground Slam: in the air, press G to crash down and throw people around you. Non-lethal.",
          lore = "A frame that turns a fall into a weapon.", stats = { { "Damage", "35" }, { "Radius", "4 m" }, { "Cooldown", "5 s" } } },
        { id = "titanium_bones", name = "Titanium Bones", section = "skeleton", family = "bones",
          kind = "passive", rarity = "uncommon", tier = 2, price = 7500, capacity = 2,
          maker = "Biotechnica", icon = "cw_skeleton_titaniuminfusedbones", passive = { healthMax = 25 },
          effect = "+25 max health.", lore = "Your skeleton, but tested at the factory.", stats = { { "Max health", "+25" } } },
        { id = "epimorphic_skeleton", name = "Epimorphic Skeleton", section = "skeleton", family = "bones",
          kind = "passive", rarity = "epic", tier = 4, price = 24000, capacity = 4,
          maker = "Arasaka", icon = "cw_skeleton_endoskeleton", passive = { healthMax = 60 },
          effect = "+60 max health.", lore = "A frame that grows back stronger every time it breaks.", stats = { { "Max health", "+60" } } },
        -- Integumentary --------------------------------------------------------------------
        { id = "subdermal_armor", name = "Subdermal Armor", section = "integumentary", family = "armor",
          kind = "passive", rarity = "uncommon", tier = 2, price = 6500, capacity = 2,
          maker = "Militech", icon = "cw_integumentary_subdermalarmorcommon", passive = { armor = 30 },
          effect = "+30 armor.", lore = "Weave plates under the skin. Bruises less, feels less.", stats = { { "Armor", "+30" } } },
        { id = "subdermal_armor_mk2", name = "Subdermal Armor Mk.2", section = "integumentary", family = "armor",
          kind = "passive", rarity = "epic", tier = 4, price = 16000, capacity = 4,
          maker = "Militech", icon = "cw_integumentary_subdermalarmor_iconic", passive = { armor = 60 },
          effect = "+60 armor.", lore = "Military-grade weave. Still legal, mostly.", stats = { { "Armor", "+60" } } },
        -- Circulatory system ---------------------------------------------------------------
        { id = "biomonitor", name = "Biomonitor", section = "circulatory", family = "biomonitor",
          kind = "passive", rarity = "rare", tier = 3, price = 9000, capacity = 3,
          maker = "Biotechnica", icon = "cw_circulatory_healthmonitor", passive = { healthRegen = 1.5 },
          effect = "Your health regenerates slowly (+1.5 / s).", lore = "Reads your vitals so you do not have to.", stats = { { "Health regen", "+1.5 / s" } } },
        { id = "iron_lungs", name = "Iron Lungs", section = "circulatory", family = "lungs",
          kind = "passive", rarity = "uncommon", tier = 2, price = 6000, capacity = 2,
          maker = "Zetatech", icon = "cw_circulatory_ironlungs", passive = { staminaMax = 40 },
          effect = "+40 max stamina.", lore = "Breathe smog, exhale results.", stats = { { "Max stamina", "+40" } } },
        { id = "adrenaline_booster", name = "Adrenaline Booster", section = "circulatory", family = "pump",
          kind = "passive", rarity = "rare", tier = 3, price = 8500, capacity = 2,
          maker = "Militech", icon = "cw_circulatory_bloodpump", passive = { staminaRegen = 8 },
          effect = "Stamina comes back faster (+8 / s).", lore = "A pressure cannon for your veins.", stats = { { "Stamina regen", "+8 / s" } } },
        -- Rank V: reputation tier IV (Edgerunner) -----------------------------------------
        { id = "iron_lungs_mk2", name = "Iron Lungs Mk.2", section = "circulatory", family = "lungs",
          kind = "passive", rarity = "legendary", tier = 5, price = 34000, capacity = 3,
          maker = "Zetatech", icon = "cw_circulatory_ironlungs", passive = { staminaMax = 80 },
          effect = "+80 max stamina.", lore = "Sealed alveoli rated for vacuum work. Night City air is easy.", stats = { { "Max stamina", "+80" } } },
        { id = "adrenaline_booster_mk2", name = "Adrenaline Booster Mk.2", section = "circulatory", family = "pump",
          kind = "passive", rarity = "legendary", tier = 5, price = 36000, capacity = 3,
          maker = "Militech", icon = "cw_circulatory_staminaregenbooster", passive = { staminaRegen = 15 },
          effect = "Stamina comes back much faster (+15 / s).", lore = "Combat-grade pump. Your pulse is now a setting.", stats = { { "Stamina regen", "+15 / s" } } },
        { id = "bioplastic_blood_vessels", name = "Bioplastic Blood Vessels", section = "circulatory", family = "biomonitor",
          kind = "passive", rarity = "legendary", tier = 5, price = 42000, capacity = 5,
          maker = "Biotechnica", icon = "cw_circulatory_enhancedbloodvessels", passive = { healthRegen = 3 },
          effect = "Your health regenerates (+3 / s).", lore = "Self-sealing veins. Wounds close before the bleeding starts.", stats = { { "Health regen", "+3 / s" } } },
        { id = "second_heart", name = "Second Heart", section = "circulatory", family = "heart",
          kind = "second_heart", rarity = "legendary", tier = 5, price = 55000, capacity = 6,
          maker = "Biotechnica", icon = "cw_circulatory_secondheart",
          secondHeart = { cooldownMs = 3600000, delayMs = 5000, health = 0.4, graceMs = 4000 },
          effect = "Downed in the city, you get back up by yourself after 5 s. Once an hour. Off in Dogtown and in ranked activities.",
          lore = "A spare pump on standby. It only wakes up when the first one quits.", stats = { { "Self-revive", "5 s" }, { "Health", "40%" }, { "Cooldown", "1 h" } } },
        -- Rank V+: reputation tier V (Legend) ---------------------------------------------
        { id = "neofiber_mk3", name = "Neofiber Actuators Mk.3", section = "nervous", family = "dash",
          kind = "dash", preset = "apex", rarity = "legendary", tier = 6, price = 85000, capacity = 6,
          maker = "Biotechnica", icon = "cw_nervoussystem_improvedreaction",
          effect = "Dash and air dash: three charges, almost free, back in a second.",
          lore = "Prototype fibres. The paperwork says they do not exist.", stats = { { "Charges", "3" }, { "Stamina", "5" }, { "Recharge", "1 s" } } },
        { id = "aegis_dermal_plating", name = "Aegis Dermal Plating", section = "integumentary", family = "armor",
          kind = "passive", rarity = "legendary", tier = 6, price = 90000, capacity = 7,
          maker = "Arasaka", icon = "cw_integumentary_metalcoveredskin", passive = { armor = 100 },
          effect = "+100 armor.", lore = "Corporate bodyguard plating. Bullets leave a bill, not a hole.", stats = { { "Armor", "+100" } } },
        { id = "rara_avis", name = "Rara Avis", section = "skeleton", family = "bones",
          kind = "passive", rarity = "legendary", tier = 6, price = 95000, capacity = 7,
          maker = "Kang Tao", icon = "cw_skeleton_nanotechplates", passive = { healthMax = 100 },
          effect = "+100 max health.", lore = "Nanotech lattice bones. One in a thousand bodies takes the graft.", stats = { { "Max health", "+100" } } },
        { id = "zetatech_apogee", name = "Zetatech Apogee", section = "operating_system", family = "os",
          kind = "overdrive", preset = "apex", rarity = "legendary", tier = 6, price = 120000, capacity = 8,
          maker = "Zetatech", icon = "cw_system_sandevistanc4",
          effect = "Apex overdrive: 11 s of heavy reflex boost, two charges, back in 22 s (press X).",
          lore = "The last Sandevistan before the military kept the rest.", stats = { { "Duration", "11 s" }, { "Charges", "2" }, { "Cooldown", "22 s" }, { "Stamina", "30" } } },
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
        apex = { staminaCost = 5, cooldownMs = 300, maxCharges = 3, chargeRegenMs = 1000 }, -- rank V+
    },
    overdrivePresets = {
        street = { tier = "reflex", durationMs = 10000, cooldownMs = 13000, maxCharges = 1, chargeRegenMs = 23000, staminaCost = 25 },
        combat = { tier = "reflex_heavy", durationMs = 8000, cooldownMs = 25000, maxCharges = 2, chargeRegenMs = 45000, staminaCost = 40 },
        apex = { tier = "reflex_heavy", durationMs = 11000, cooldownMs = 22000, maxCharges = 2, chargeRegenMs = 40000, staminaCost = 30 }, -- rank V+
    },
    slam = { damage = 35, knockbackMeters = 1.5, staminaCost = 20, cooldownMs = 5000, radius = 4 },

    -- Iconic implants (server/modules/cyberware_iconics.lua): never sold, never resold, never
    -- traded. They drop, server side, for each eligible participant of a source: a roll at
    -- `chance`, and a pity counter per character and source (`pity` runs without one: the next
    -- is guaranteed). A character who already owns every item of a source is not rolled. The
    -- drop lands in the character's implant storage; fitting it costs fittingFee and its
    -- capacity, like any stored implant. Announced to the city and logged.
    --   worldBoss        a world boss defeated (server/modules/world_bosses.lua, Nightwolf's):
    --                    every participant the payout counts eligible
    --   chimeraCritical  the Chimera raid won on Critical (server/modules/mission_chimera.lua):
    --                    every operator of the run (a staff test run never drops)
    iconics = {
        enabled = true,
        sources = {
            worldBoss = { label = "World bosses", items = { "feral_biomonitor" }, chance = 0.08, pity = 12 },
            chimeraCritical = { label = "Chimera raid (Critical)", items = { "chimera_plating" }, chance = 0.12, pity = 8,
                difficulty = "critical", point = "chimera_raid" },
        },
        items = {
            { id = "chimera_plating", name = "Chimera Plating", section = "integumentary", family = "armor",
              kind = "passive", rarity = "iconic", tier = 6, price = 0, capacity = 7,
              maker = "Militech", icon = "cw_integumentary_neuroactivearmor_capacitors", passive = { armor = 110, healthRegen = 1 },
              effect = "+110 armor and +1 health / s. Iconic: only the Chimera, on Critical, gives it up.",
              lore = "Peeled off a combat chassis that took a whole crew to drop. It still remembers how to stand.",
              stats = { { "Armor", "+110" }, { "Health regen", "+1 / s" } } },
            { id = "feral_biomonitor", name = "Feral Biomonitor", section = "circulatory", family = "biomonitor",
              kind = "passive", rarity = "iconic", tier = 5, price = 0, capacity = 6,
              maker = "Unknown", icon = "cw_circulatory_microgenerator", passive = { healthRegen = 3.5, healthMax = 20 },
              effect = "+3.5 health / s and +20 max health. Iconic: torn from the city's world bosses.",
              lore = "Wired for a body that refused to die. Now it refuses on your behalf.",
              stats = { { "Health regen", "+3.5 / s" }, { "Max health", "+20" } } },
        },
    },
}

-- Every implant by id (the shop and the iconics), for the guide's placeholders
-- ({cfg:cyberware.byId.berserk_mk1.berserk.armor}). Read only: the module keeps its own index.
LightRpCyberwareConfig.byId = {}
for _, list in ipairs({ LightRpCyberwareConfig.items, LightRpCyberwareConfig.iconics.items }) do
    for _, item in ipairs(list) do LightRpCyberwareConfig.byId[item.id] = item end
end
