/* The installation timeline: seven stages, their lengths (full and reduced
   motion) and the sound cues. Lua plays the implant sounds on two shared slots
   and a new sound cuts the previous one of its slot, so the slot A cues are
   spaced past each other's length (slot B may overlap A).
     slot A: denied 1.24 s, glitch 0.55, boot 0.61, flash 2.87, calibrate 2.62, granted 1.26
     slot B: insert 5.07 s, scan 3.2, online 3.9 */
import type { UiSound } from "@/fx/sound";

export type StageId = "boot" | "flash" | "insert" | "synapse" | "calibrate" | "identity" | "online";

export interface Stage { id: StageId; name: string; start: number; dur: number }
export interface Cue { at: number; sound: UiSound }
export interface Plan {
  stages: Stage[];
  cues: Cue[];
  total: number;
  /** "ACCESS GRANTED", in ms after the identity stage starts (kept clear of calibrate). */
  grantAt: number;
  /** The synapse graph lights up this long after its stage starts (with the scan sound). */
  scanAt: number;
}

export const SOUND_MS: Partial<Record<UiSound, number>> = {
  implant_denied: 1240, implant_glitch: 550, implant_boot: 610, implant_flash: 2870, implant_calibrate: 2620, implant_granted: 1260,
  implant_insert: 5070, implant_scan: 3200, implant_online: 3900,
};

const NAMES: Record<StageId, string> = {
  boot: "Kiroshi boot",
  flash: "Firmware flash",
  insert: "Implant insertion",
  synapse: "Synaptic link",
  calibrate: "Optic calibration",
  identity: "Identity binding",
  online: "Link established",
};

const ORDER: StageId[] = ["boot", "flash", "insert", "synapse", "calibrate", "identity", "online"];
const FULL: number[] = [2000, 2800, 3000, 3000, 2000, 1500, 1500];
const REDUCED: number[] = [1200, 1800, 2000, 2000, 1600, 1400, 1000];

export const STAGE_INDEX = Object.fromEntries(ORDER.map((id, i) => [id, i])) as Record<StageId, number>;

export function buildPlan(reduced: boolean): Plan {
  const durs = reduced ? REDUCED : FULL;
  let t = 0;
  const stages = ORDER.map((id, i) => {
    const s = { id, name: NAMES[id], start: t, dur: durs[i]! };
    t += s.dur;
    return s;
  });
  const at = (id: StageId) => stages[STAGE_INDEX[id]]!;
  // scan lets most of insert ring out before it takes slot B over
  const scanAt = reduced ? 250 : 500;
  const calibrateAt = at("calibrate").start;
  const grantAt = Math.max(reduced ? 500 : 700, calibrateAt + SOUND_MS.implant_calibrate! + 50 - at("identity").start);
  const cues: Cue[] = [
    { at: at("boot").start, sound: "implant_boot" },
    { at: at("flash").start, sound: "implant_flash" },
    { at: at("insert").start, sound: "implant_insert" },
    { at: at("synapse").start + scanAt, sound: "implant_scan" },
    { at: calibrateAt, sound: "implant_calibrate" },
    { at: at("identity").start + grantAt, sound: "implant_granted" },
    { at: at("online").start, sound: "implant_online" },
  ];
  return { stages, cues, total: t, grantAt, scanAt };
}
