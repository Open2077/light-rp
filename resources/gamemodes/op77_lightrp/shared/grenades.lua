-- Verified counted quick-slot inventory items.
LightRpGrenades = { items = {} }
LightRpGrenades.items.grenade_incendiary = {record="Items.GrenadeIncendiaryRegular",label="CHAR Incendiary Grenade"}
LightRpGrenades.items.grenade_emp = {record="Items.GrenadeEMPRegular",label="EMP Grenade"}
LightRpGrenades.items.grenade_frag = {record="Items.GrenadeFragRegular",label="F-GX Frag Grenade"}
LightRpGrenades.items.grenade_cutting = {record="Items.GrenadeCuttingRegular",label="GASH Antipersonnel Grenade"}
LightRpGrenades.items.grenade_biohazard = {record="Items.GrenadeBiohazardRegular",label="MOLODETS BioHaz Grenade"}
LightRpGrenades.items.grenade_ozobs_nose = {record="Items.GrenadeOzobsNose",label="Ozob's Nose"}
LightRpGrenades.items.grenade_recon = {record="Items.GrenadeReconRegular",label="Recon Grenade"}
LightRpGrenades.items.grenade_smoke = {record="Items.GrenadeSmokeRegular",label="Smoke Grenade"}
LightRpGrenades.items.grenade_flashbang = {record="Items.GrenadeFlashRegular",label="X-22 Flashbang Grenade"}
for name, spec in pairs(LightRpGrenades.items) do
 LightRpItems[name] = {label=spec.label,description="A counted grenade. Use it from your inventory to select it for throwing.",weight=.4,stack=10,icon="package",category="grenade",image="img/items/"..name..".png"}
end
