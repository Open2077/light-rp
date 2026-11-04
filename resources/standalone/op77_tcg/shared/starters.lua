-- The two official starter decks of Welcome to Night City (40 cards + 3 Legends each), lent by the shop: any
-- collector may play them at a TCG table without owning the cards. Lists: gamertagmythras.com starter decks compared.
TcgStarters = {
    { id = "embracing_power", name = "Embracing Power", subtitle = "Arasaka starter deck - Red / Green",
      legends = { "goro_takemura_hands_unclean", "saburo_arasaka_stubborn_patriarch", "yorinobu_arasaka_embracing_destruction" },
      cards = { arasaka_emergency_radioport = 2, chrome_fang = 2, corpo_security = 3, corporate_surveillance = 3, emergency_atlus = 2, field_operator = 2, goro_takemura_losing_his_way = 2, industrial_assembly = 2, mantis_blades = 3, maxtac_av = 2, minotaur = 2, over_the_edge = 2, ruthless_lowlife = 3, sandevistan = 3, satori_sword_of_saburo = 3, shattered_memories = 2, swordwise_huscle = 2 } },
    { id = "the_heist", name = "The Heist", subtitle = "Mercs starter deck - Blue / Yellow",
      legends = { "v_corporate_exile", "jackie_welles_pour_one_out_for_me", "viktor_vektor_sit_down_and_relax" },
      cards = { afterparty_at_lizzie_s = 2, delamain_cab = 3, dexter_deshawn_one_last_chance = 2, dying_night_v_s_pistol = 2, evelyn_parker_scheming_siren = 3, floor_it = 3, heywood_ripperdoc = 2, kiroshi_optics = 3, mandibular_upgrade = 3, mt0d12_flathead = 2, offduty_malfini = 2, psycho_squad = 2, reboot_optics = 2, secondhand_bombus = 2, t_bug_amateur_philosopher = 2, tetratronic_rippler = 2, zetatech_faceplate = 3 } },
}
TcgStarters.byId = {}
for _, s in ipairs(TcgStarters) do TcgStarters.byId[s.id] = s end
