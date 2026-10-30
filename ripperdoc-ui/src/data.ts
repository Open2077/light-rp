/* Sections of the body, their slots and the demo catalogue. The installation system comes
   later: today the page shows this catalogue, the server only says who sits in the chair. */

export type Body = "male" | "female";
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary";

export interface SectionDef {
  id: string;
  label: string;
  code: string;            // short system code drawn in the HUD
  side: "left" | "right";
  slots: number;           // slots the clinic can fill
  locked: number;          // extra slots shown locked (capacity / licence)
  anchor: Record<Body, { x: number; y: number }>;  // fraction of the body loop frame
  still?: boolean;         // a full-body system overlay exists (media/still/<body>_<id>.webp)
  blurb: string;
}

export interface Cyberware {
  id: string;
  name: string;
  section: string;
  icon: string;            // media/icon/<icon>.webp
  rarity: Rarity;
  tier: number;            // 1..5
  capacity: number;        // capacity points
  price: number;           // eurodollars
  maker: string;
  effect: string;
  lore: string;
  stats: { label: string; value: string }[];
}

const a = (mx: number, my: number, fx: number, fy: number) => ({ male: { x: mx, y: my }, female: { x: fx, y: fy } });

export const SECTIONS: SectionDef[] = [
  { id: "frontal_cortex", label: "Frontal Cortex", code: "FC-01", side: "left", slots: 3, locked: 1, anchor: a(0.5, 0.05, 0.53, 0.055),
    blurb: "Memory, processing and the quiet voice that decides first." },
  { id: "ocular", label: "Ocular System", code: "OC-02", side: "left", slots: 1, locked: 0, anchor: a(0.5, 0.093, 0.53, 0.097),
    blurb: "Optics, zoom, threat tagging and low-light vision." },
  { id: "arms", label: "Arms", code: "AR-03", side: "left", slots: 1, locked: 0, anchor: a(0.24, 0.33, 0.29, 0.36),
    blurb: "Forearm housings: blades, wires, launchers, raw strength." },
  { id: "skeleton", label: "Skeleton", code: "SK-04", side: "left", slots: 2, locked: 1, anchor: a(0.44, 0.27, 0.47, 0.28), still: true,
    blurb: "Load-bearing frame, marrow and the plating bolted onto it." },
  { id: "nervous", label: "Nervous System", code: "NS-05", side: "left", slots: 3, locked: 0, anchor: a(0.5, 0.36, 0.53, 0.37), still: true,
    blurb: "Reflexes, reaction windows and signal speed." },
  { id: "integumentary", label: "Integumentary", code: "IN-06", side: "left", slots: 3, locked: 0, anchor: a(0.34, 0.22, 0.38, 0.22), still: true,
    blurb: "Skin, subdermal armor and everything that stops a round." },
  { id: "operating_system", label: "Operating System", code: "OS-07", side: "right", slots: 1, locked: 0, anchor: a(0.5, 0.155, 0.53, 0.155),
    blurb: "Sandevistan, Berserk or a cyberdeck: the one chip that runs the rest." },
  { id: "face", label: "Face", code: "FA-08", side: "right", slots: 1, locked: 0, anchor: a(0.5, 0.115, 0.53, 0.12),
    blurb: "Jaw, mask and subdermal face plating." },
  { id: "hands", label: "Hands", code: "HA-09", side: "right", slots: 2, locked: 1, anchor: a(0.9, 0.465, 0.83, 0.475),
    blurb: "Grip, smart link and the tremor you will never have again." },
  { id: "circulatory", label: "Circulatory System", code: "CS-10", side: "right", slots: 3, locked: 1, anchor: a(0.54, 0.245, 0.56, 0.25), still: true,
    blurb: "Heart, blood and the pumps that keep it moving under fire." },
  { id: "immune", label: "Immune System", code: "IM-11", side: "right", slots: 2, locked: 0, anchor: a(0.5, 0.315, 0.53, 0.33), still: true,
    blurb: "Toxin filters, pain editors and shock countermeasures." },
  { id: "legs", label: "Legs", code: "LG-12", side: "right", slots: 1, locked: 0, anchor: a(0.36, 0.69, 0.44, 0.66),
    blurb: "Tendons, ankles and the jump that clears the second floor." },
];

export const SECTION = Object.fromEntries(SECTIONS.map((s) => [s.id, s])) as Record<string, SectionDef>;

const c = (id: string, name: string, section: string, icon: string, rarity: Rarity, tier: number, capacity: number,
  price: number, maker: string, effect: string, lore: string, stats: [string, string][]): Cyberware =>
  ({ id, name, section, icon, rarity, tier, capacity, price, maker, effect, lore, stats: stats.map(([label, value]) => ({ label, value })) });

export const CATALOGUE: Cyberware[] = [
  // Frontal cortex
  c("ram_upgrade", "RAM Upgrade", "frontal_cortex", "cw_frontalcortex_memoryboost", "uncommon", 2, 4, 6500, "Zetatech",
    "+2 RAM for quickhacks.", "Cheap, reliable and the first thing every netrunner buys.", [["RAM", "+2"], ["Latency", "-4%"]]),
  c("mechatronic_core", "Mechatronic Core", "frontal_cortex", "cw_frontalcortex_roboticcore", "rare", 3, 6, 14200, "Kang Tao",
    "+15% damage against drones, mechs and turrets.", "Pattern libraries for machines that do not bleed.", [["Damage vs machines", "+15%"]]),
  c("ex_disk", "Ex-Disk", "frontal_cortex", "cw_frontalcortex_braincapacitybooster", "epic", 4, 8, 23800, "Biotechnica",
    "+4 max RAM, faster RAM recovery.", "External cortical storage. Do not let anyone read it.", [["Max RAM", "+4"], ["RAM recovery", "+12%"]]),
  c("self_ice", "Self-ICE", "frontal_cortex", "cw_frontalcortex_antivirus", "rare", 3, 5, 12500, "Arasaka",
    "Blocks the first enemy quickhack, then recharges.", "A firewall with teeth, burned into the cortex.", [["Cooldown", "45 s"]]),
  c("camillo_ram", "Camillo RAM Manager", "frontal_cortex", "cw_frontalcortex_memoryreplenishment", "legendary", 5, 10, 41000, "Zetatech",
    "Restores RAM when it runs out, once per minute.", "Black-market firmware. The warranty is a phone number that never answers.", [["RAM restored", "20%"], ["Cooldown", "60 s"]]),
  // Ocular
  c("kiroshi_cockatrice", "Kiroshi \"Cockatrice\" Optics", "ocular", "cw_eyes_kiroshioptics", "legendary", 5, 6, 38500, "Kiroshi",
    "+20% crit chance, threat tagging, 6x zoom.", "Gold-ringed irises. Everyone knows what you paid.", [["Crit chance", "+20%"], ["Zoom", "6x"]]),
  c("kiroshi_clairvoyant", "Kiroshi \"Clairvoyant\" Optics", "ocular", "cw_eyes_3eye", "epic", 4, 5, 21000, "Kiroshi",
    "Highlights explosives and traps through walls.", "Sees the wire before the wire sees you.", [["Scan range", "+30 m"]]),
  c("kiroshi_basic", "Kiroshi Optics Mk.1", "ocular", "cw_eyes_2eye", "common", 1, 2, 3200, "Kiroshi",
    "Basic scanning and 2x zoom.", "Street standard. Every second face in Watson wears them.", [["Zoom", "2x"]]),
  // Arms
  c("mantis_blades", "Mantis Blades", "arms", "cw_arms_mantisblades", "epic", 4, 12, 32000, "Arasaka",
    "Forearm blades with a leap attack.", "Two arcs of monomolecular steel folded under the skin.", [["Damage", "88-112"], ["Attacks/s", "1.9"]]),
  c("gorilla_arms", "Gorilla Arms", "arms", "cw_arms_strongarms", "rare", 3, 10, 24500, "Militech",
    "Brutal fists that rip doors off their frames.", "Hydraulic knuckles and a temper to match.", [["Damage", "64-80"], ["Stun", "+25%"]]),
  c("monowire", "Monowire", "arms", "cw_arms_nanowires", "legendary", 5, 12, 46000, "Kang Tao",
    "A whip of mono-filament that cuts through cover.", "Thin enough to split a molecule. Mind your fingers.", [["Damage", "70-95"], ["Reach", "6 m"]]),
  c("projectile_launcher", "Projectile Launch System", "arms", "cw_arms_projectilelauncher", "rare", 3, 11, 26000, "Militech",
    "Wrist-mounted micro-missiles.", "A rocket in your forearm. What could go wrong.", [["Damage", "220"], ["Charges", "3"]]),
  // Skeleton
  c("titanium_bones", "Titanium Bones", "skeleton", "cw_skeleton_titaniuminfusedbones", "uncommon", 2, 5, 7800, "Biotechnica",
    "+20% carry capacity and fall resistance.", "Your skeleton, but tested at the factory.", [["Carry capacity", "+20%"]]),
  c("dense_marrow", "Dense Marrow", "skeleton", "cw_skeleton_densemarrow", "rare", 3, 6, 13900, "Biotechnica",
    "+15% melee damage, lower stamina cost.", "Heavier bones, heavier hits.", [["Melee damage", "+15%"]]),
  c("epimorphic_skeleton", "Epimorphic Skeleton", "skeleton", "cw_skeleton_endoskeleton", "epic", 4, 9, 28800, "Arasaka",
    "+30% max health.", "A frame that grows back stronger every time it breaks.", [["Max health", "+30%"]]),
  c("bionic_joints", "Bionic Joints", "skeleton", "cw_skeleton_jointlock", "common", 1, 3, 2900, "Dynalar",
    "Steadier stance while aiming.", "Locking joints for a rock-solid aim.", [["Sway", "-25%"]]),
  // Nervous
  c("kerenzikov", "Kerenzikov", "nervous", "cw_nervoussystem_kerenzikov", "rare", 3, 6, 16000, "Militech",
    "Slows time when you aim while dodging or sliding.", "Half a second that lasts a lifetime.", [["Time dilation", "80%"], ["Duration", "1.5 s"]]),
  c("synaptic_accelerator", "Synaptic Accelerator", "nervous", "cw_nervoussystem_synapticaccelerator", "uncommon", 2, 4, 7200, "Zetatech",
    "Slows time when an enemy spots you.", "Your brain flinches before you do.", [["Time dilation", "50%"]]),
  c("reflex_tuner", "Reflex Tuner", "nervous", "cw_nervoussystem_reflexrecorder", "epic", 4, 7, 22500, "Kang Tao",
    "Slows time when health drops low.", "When it matters, everything slows down.", [["Trigger", "< 25% HP"]]),
  c("neofiber", "Neofiber", "nervous", "cw_nervoussystem_neofibre", "rare", 3, 5, 12800, "Biotechnica",
    "+10% evasion.", "Fast-twitch fibres woven into every nerve.", [["Evasion", "+10%"]]),
  // Integumentary
  c("subdermal_armor", "Subdermal Armor", "integumentary", "cw_integumentary_subdermalarmorcommon", "uncommon", 2, 5, 8400, "Militech",
    "+60 armor.", "Weave plates under the skin. Bruises less, feels less.", [["Armor", "+60"]]),
  c("optical_camo", "Optical Camo", "integumentary", "cw_integumentary_opticalcamo", "epic", 4, 9, 30500, "Arasaka",
    "Active camouflage for 8 seconds.", "You are there. Nobody can prove it.", [["Duration", "8 s"], ["Cooldown", "45 s"]]),
  c("fireproof_coating", "Fireproof Coating", "integumentary", "cw_integumentary_fireproofskin", "rare", 3, 4, 11200, "Biotechnica",
    "Immunity to burning.", "A ceramic film that laughs at incendiaries.", [["Burn", "Immune"]]),
  c("grounding_plating", "Grounding Plating", "integumentary", "cw_integumentary_groundingplating", "uncommon", 2, 3, 6100, "Militech",
    "Immunity to shock.", "Lightning has to find someone else.", [["Shock", "Immune"]]),
  // Operating system
  c("sandevistan_c1", "Sandevistan Mk.1", "operating_system", "cw_system_sandevistanc1", "uncommon", 2, 14, 18500, "Zetatech",
    "Slows time to 50% for 8 seconds.", "The entry ticket to a slower world.", [["Time scale", "50%"], ["Duration", "8 s"]]),
  c("sandevistan_c3", "Sandevistan Mk.3", "operating_system", "cw_system_sandevistanc3", "epic", 4, 18, 52000, "Dynalar",
    "Slows time to 25% for 10 seconds, +15% crit.", "What the edgerunners swear by.", [["Time scale", "25%"], ["Duration", "10 s"]]),
  c("berserk_c2", "Berserk Mk.2", "operating_system", "cw_system_berserkc2", "rare", 3, 16, 31500, "Militech",
    "+30% melee damage and armor while active.", "Pain becomes a rumour.", [["Melee", "+30%"], ["Armor", "+30%"]]),
  c("paraline_deck", "Militech Paraline", "operating_system", "cw_system_militechcyberdeck", "rare", 3, 15, 27000, "Militech",
    "Cyberdeck: 6 RAM, 4 quickhack slots.", "Corporate-grade deck with a corporate-grade kill switch.", [["RAM", "6"], ["Slots", "4"]]),
  c("netwatch_netdriver", "Netwatch Netdriver", "operating_system", "cw_system_netwatchnetdrivercyberdeck", "legendary", 5, 20, 68000, "NetWatch",
    "Cyberdeck: 9 RAM, quickhacks spread to nearby targets.", "Nobody sells these. Someone sold this one.", [["RAM", "9"], ["Slots", "6"]]),
  // Face
  c("face_plating", "Subdermal Face Plating", "face", "cw_facemask", "rare", 3, 4, 9800, "Biotechnica",
    "+25 armor, resistance to head trauma.", "A jaw that stops bullets and lies.", [["Armor", "+25"]]),
  // Hands
  c("smart_link", "Smart Link", "hands", "cw_hands_smartlink", "uncommon", 2, 3, 5600, "Kang Tao",
    "Unlocks smart weapon tracking.", "Your palm talks to the gun. The gun listens.", [["Smart lock", "Enabled"]]),
  c("ballistic_coprocessor", "Ballistic Coprocessor", "hands", "cw_hands_recoil", "rare", 3, 4, 10400, "Militech",
    "Ricochets show their path, -15% recoil.", "Trajectory maths at the speed of a flinch.", [["Recoil", "-15%"]]),
  c("power_grip", "Power Grip", "hands", "cw_hands_powergrip", "common", 1, 2, 2400, "Dynalar",
    "+10% melee damage with blunt weapons.", "Grip strength rated for hydraulic presses.", [["Blunt damage", "+10%"]]),
  c("shock_n_awe", "Shock-N-Awe", "hands", "cw_hands_electricexplosion", "epic", 4, 6, 19800, "Arasaka",
    "Releases an electric burst when you are hit.", "Touch me. I dare you.", [["Shock damage", "150"]]),
  // Circulatory
  c("biomonitor", "Biomonitor", "circulatory", "cw_circulatory_healthmonitor", "uncommon", 2, 3, 6800, "Biotechnica",
    "Auto-heals 60% when health drops below 15%.", "Reads your vitals so you do not have to.", [["Heal", "60%"], ["Cooldown", "120 s"]]),
  c("tyrosine_injector", "Tyrosine Injector", "circulatory", "cw_circulatory_tyrosineinjector", "uncommon", 2, 3, 5200, "Zetatech",
    "Breach Protocol lasts twice as long.", "Enhances intracellular transduction.", [["Breach time", "+100%"]]),
  c("feedback_circuit", "Feedback Circuit", "circulatory", "cw_circulatory_dischargeconnector", "legendary", 5, 7, 21000, "Kang Tao",
    "Restores 10% health after a fully charged shot.", "Additional circuitry that links your body and cyberware with weapons and devices.", [["Heal", "10%"]]),
  c("second_heart", "Second Heart", "circulatory", "cw_circulatory_secondheart", "legendary", 5, 10, 54000, "Biotechnica",
    "Revives you once with full health.", "Spare parts for the one part you cannot spare.", [["Revive", "100% HP"], ["Cooldown", "6 min"]]),
  c("blood_pump", "Blood Pump", "circulatory", "cw_circulatory_bloodpump", "rare", 3, 5, 14500, "Militech",
    "Instantly restores 50% health on use.", "A pressure cannon for your veins.", [["Heal", "50%"]]),
  // Immune
  c("pain_editor", "Pain Editor", "immune", "cw_immunesystem_painreductor", "epic", 4, 7, 24000, "Arasaka",
    "-10% damage taken.", "Pain is a signal. This one edits the signal.", [["Damage taken", "-10%"]]),
  c("detoxifier", "Detoxifier", "immune", "cw_immunesystem_toxincleanser", "uncommon", 2, 3, 6300, "Biotechnica",
    "Immunity to poison.", "Your liver, but with a filter.", [["Poison", "Immune"]]),
  c("shock_absorber", "Inductor", "immune", "cw_immunesystem_electroshockmechanism", "rare", 3, 5, 12100, "Militech",
    "Converts incoming shock into health.", "Lightning tastes like breakfast.", [["Shock to HP", "35%"]]),
  // Legs
  c("reinforced_tendons", "Reinforced Tendons", "legs", "cw_legs_boostedtendons", "uncommon", 2, 6, 9900, "Militech",
    "Double jump.", "Springs where your ankles used to be.", [["Jump", "Double"]]),
  c("lynx_paws", "Lynx Paws", "legs", "cw_legs_catpaws", "rare", 3, 5, 11800, "Kang Tao",
    "Silent movement.", "Footsteps nobody hears.", [["Noise", "-100%"]]),
  c("fortified_ankles", "Fortified Ankles", "legs", "cw_legs_fortifiedankles", "epic", 4, 7, 22800, "Arasaka",
    "Charged jump: hold to leap higher.", "Built to land on roofs.", [["Jump height", "+60%"]]),
];

export const CYBERWARE = Object.fromEntries(CATALOGUE.map((x) => [x.id, x])) as Record<string, Cyberware>;

export interface Clinic { name: string; doctor: string; tagline?: string }

export interface OpenPayload {
  body?: Body;
  clinic?: Clinic;
  wallet?: number;
  capacity?: { max: number };
  installed?: Record<string, string[]>;
  patient?: { name?: string; id?: string };
}

export const DEMO: Required<OpenPayload> = {
  body: "male",
  clinic: { name: "Viktor's Clinic", doctor: "Viktor Vektor", tagline: "Licensed // Watson // Kabuki" },
  wallet: 48250,
  capacity: { max: 90 },
  installed: {
    frontal_cortex: ["ram_upgrade"], operating_system: ["sandevistan_c1"], ocular: ["kiroshi_basic"],
    hands: ["smart_link"], circulatory: ["biomonitor", "tyrosine_injector"], integumentary: ["subdermal_armor"],
    skeleton: ["titanium_bones"],
  },
  patient: { name: "Alex Morgan", id: "NC-0715-3381" },
};

export const RARITY_LABEL: Record<Rarity, string> = {
  common: "Common", uncommon: "Uncommon", rare: "Rare", epic: "Epic", legendary: "Legendary",
};

export const roman = (n: number): string => ["", "I", "II", "III", "IV", "V"][n] ?? String(n);

export const eddies = (n: number): string => n.toLocaleString("en-US").replace(/,/g, " ");
