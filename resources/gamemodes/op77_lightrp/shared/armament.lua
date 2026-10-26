-- Public item descriptions. Native grants and ammunition decisions stay server-side.
LightRpArmament = {
    maxAmmo = 600, boxRounds = 30,
    weapons = {
        weapon_lexington = {record="Items.Preset_Lexington_Default",label="Militech Lexington",ammo="pistol"},
        weapon_nue = {record="Items.Preset_Nue_Default",label="Tsunami Nue",ammo="pistol"},
    },
    boxes = {ammo_pistol_box={ammo="pistol",rounds=30}},
}
LightRpItems.weapon_lexington={label="Militech Lexington",description="A serialized pistol. Equip it from your inventory; ammunition is supplied separately.",weight=1.3,stack=1,icon="crosshair",category="weapon"}
LightRpItems.weapon_nue={label="Tsunami Nue",description="A heavy pistol. Equip it from your inventory; ammunition is supplied separately.",weight=1.7,stack=1,icon="crosshair",category="weapon"}
LightRpItems.ammo_pistol_box={label="Pistol ammunition · 30",description="A sealed box of 30 pistol rounds. Opening it credits this character's ammunition stock once.",weight=.4,stack=10,icon="package",category="ammo"}
