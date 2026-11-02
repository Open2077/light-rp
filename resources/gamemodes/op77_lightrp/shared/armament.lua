-- Public item descriptions. Native grants and ammunition decisions stay server-side.
-- Rounds are inventory items: one item = one round, of one ammunition type. An
-- equipped firearm's native ammo is a projection of the rounds of its type in the
-- character's pockets; every observed shot removes a round from the inventory.
--
-- Native pools (measured, open77_cordon config, 2.31/2.5): pistols, revolvers AND
-- SMGs fire Ammo.HandgunAmmo; assault rifles, LMGs AND precision rifles fire
-- Ammo.RifleAmmo (an Achilles reports the Defender's pool, not the sniper's);
-- shotguns Ammo.ShotgunAmmo; sniper rifles Ammo.SniperRifleAmmo. An RP ammunition
-- type is one native pool, so two weapons of one type always share it.
LightRpArmament = {
    -- at most this many rounds are projected into the native pool at once (the rest
    -- stay in the pockets and top the pool up); also the bound of the legacy stock
    maxAmmo = 600, boxRounds = 30,
    ammo = {
        -- the key `pistol` and the item `ammo_pistol` predate the other types:
        -- characters already hold them, so they keep their names
        pistol = { item = "ammo_pistol", label = "Handgun rounds", native = "Ammo.HandgunAmmo" },
        rifle = { item = "ammo_rifle", label = "Rifle rounds", native = "Ammo.RifleAmmo" },
        shotgun = { item = "ammo_shotgun", label = "Shotgun shells", native = "Ammo.ShotgunAmmo" },
        sniper = { item = "ammo_sniper", label = "Sniper rounds", native = "Ammo.SniperRifleAmmo" },
    },
    -- class: what the weapon is; only handguns (pistols, revolvers) may go in the
    -- left hand, everything else is two-handed and holds the right hand alone
    weapons = {},
    boxes = {},
}

local WEAPONS = {
    -- id, record, label, class, ammo, weight, description
    { "weapon_lexington", "Items.Preset_Lexington_Default", "Militech Lexington", "pistol", "pistol", 1.3, "A reliable 9 mm service pistol." },
    { "weapon_unity", "Items.Preset_Unity_Default", "Unity", "pistol", "pistol", 1.4, "A compact, accurate semi-automatic pistol." },
    { "weapon_nue", "Items.Preset_Nue_Default", "Tsunami Nue", "pistol", "pistol", 1.7, "A heavy pistol with a punch." },
    { "weapon_overture", "Items.Preset_Overture_Default", "Malorian Arms Overture", "revolver", "pistol", 1.9, "A six-shot revolver." },
    { "weapon_dr_5_nova", "Items.Preset_Nova_Default", "DR5 Nova", "revolver", "pistol", 1.8, "A fast-firing revolver." },
    { "weapon_m221_saratoga", "Items.Preset_Saratoga_Default", "M221 Saratoga", "smg", "pistol", 2.6, "A high-rate submachine gun." },
    { "weapon_ds1_pulsar", "Items.Preset_Pulsar_Default", "DS1 Pulsar", "smg", "pistol", 2.4, "A light, fast submachine gun." },
    { "weapon_tki_20_shingen", "Items.Preset_Shingen_Default", "Arasaka TKI-20 Shingen", "smg", "pistol", 2.8, "A smart submachine gun." },
    { "weapon_crusher", "Items.Preset_Crusher_Default", "Budget Arms Crusher", "shotgun", "shotgun", 3.4, "A slam-fire pump shotgun." },
    { "weapon_l_69_zhuo", "Items.Preset_Zhuo_Default", "Kang Tao L-69 Zhuo", "shotgun", "shotgun", 3.6, "A smart shotgun." },
    { "weapon_m2038_tactician", "Items.Preset_Tactician_Default", "Militech M2038 Tactician", "shotgun", "shotgun", 3.8, "A double-barrel tactical shotgun." },
    { "weapon_carnage", "Items.Preset_Carnage_Default", "Budget Arms Carnage", "shotgun", "shotgun", 4.2, "A heavy, devastating shotgun." },
    { "weapon_d5_copperhead", "Items.Preset_Copperhead_Default", "Darra D5 Copperhead", "rifle", "rifle", 3.6, "A dependable assault rifle." },
    { "weapon_m251s_ajax", "Items.Preset_Ajax_Default", "Militech M251s Ajax", "rifle", "rifle", 3.9, "A hard-hitting assault rifle." },
    { "weapon_kyubi", "Items.Preset_Kyubi_Default", "Kyubi", "rifle", "rifle", 3.4, "A burst-fire assault rifle." },
    { "weapon_d5_sidewinder", "Items.Preset_Sidewinder_Default", "Darra D5 Sidewinder", "rifle", "rifle", 3.7, "A smart assault rifle." },
    { "weapon_hjsh_18_masamune", "Items.Preset_Masamune_Default", "Arasaka HJSH-18 Masamune", "rifle", "rifle", 3.5, "A precise assault rifle." },
    { "weapon_m2067_defender", "Items.Preset_Defender_Default", "Militech M2067 Defender", "lmg", "rifle", 8.5, "A light machine gun. Rifle ammunition." },
    { "weapon_kolac", "Items.Preset_Kolac_Default", "Kolac", "precision", "rifle", 4.0, "A precision rifle. Rifle ammunition." },
    { "weapon_m_179e_achilles", "Items.Preset_Achilles_Default", "M-179e Achilles", "precision", "rifle", 4.4, "A tech precision rifle. Rifle ammunition." },
    { "weapon_spt32_grad", "Items.Preset_Grad_Default", "SPT32 Grad", "sniper", "sniper", 5.8, "A bolt-action sniper rifle." },
    { "weapon_nekomata", "Items.Preset_Nekomata_Default", "Tsunami Nekomata", "sniper", "sniper", 6.2, "A tech sniper rifle." },
}
for _, w in ipairs(WEAPONS) do
    local id, record, label, class, ammo, weight, description = w[1], w[2], w[3], w[4], w[5], w[6], w[7]
    LightRpArmament.weapons[id] = { record = record, label = label, class = class, ammo = ammo,
        dual = class == "pistol" or class == "revolver" }
    LightRpItems[id] = { image = "img/items/" .. id .. ".png", label = label,
        description = description .. " Serialized: equip it from your inventory; it loads "
            .. LightRpArmament.ammo[ammo].label:lower() .. " from your pockets.",
        weight = weight, stack = 1, icon = "crosshair", category = "weapon" }
end

local BOXES = {
    -- id, ammunition type, rounds, label, box weight
    { "ammo_pistol_box", "pistol", 30, "Handgun ammunition · 30", .4 },
    { "ammo_rifle_box", "rifle", 30, "Rifle ammunition · 30", .6 },
    { "ammo_shotgun_box", "shotgun", 12, "Shotgun shells · 12", .6 },
    { "ammo_sniper_box", "sniper", 10, "Sniper ammunition · 10", .5 },
}
for _, b in ipairs(BOXES) do
    local id, kind, rounds, label, weight = b[1], b[2], b[3], b[4], b[5]
    local spec = LightRpArmament.ammo[kind]
    LightRpArmament.boxes[id] = { ammo = kind, rounds = rounds }
    LightRpItems[id] = { label = label, description = string.format("A sealed box of %d %s. Unpack it to put them in your pockets.", rounds, spec.label:lower()),
        weight = weight, stack = 10, icon = "package", category = "ammo" }
end
local LOOSE = {
    pistol = { weight = .01, uses = "pistols, revolvers and submachine guns" },
    rifle = { weight = .015, uses = "assault rifles, light machine guns and precision rifles" },
    shotgun = { weight = .04, uses = "shotguns" },
    sniper = { weight = .05, uses = "sniper rifles" },
}
for kind, spec in pairs(LightRpArmament.ammo) do
    LightRpItems[spec.item] = { label = spec.label,
        description = "Loose " .. spec.label:lower() .. " for " .. LOOSE[kind].uses .. ". An equipped weapon loads from the rounds in your pockets; every shot spends one.",
        weight = LOOSE[kind].weight, stack = 250, icon = "package", category = "ammo" }
end
