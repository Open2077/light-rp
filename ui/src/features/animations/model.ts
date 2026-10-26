export interface AnimationProfile {
  id: string; label: string; category: string; clip: string; clips: string[];
  clipPrefix?: string; prop?: string; placement?: string;
  kind?: string; mode?: string; locomotion?: boolean; arms?: string;
}
export interface AnimationEntry {
  key: string; profile: AnimationProfile; clip: string; variant: string; index: number; walks: boolean;
}
export interface Playback {
  active: boolean; playbackId: string; step?: number; loop?: boolean; remainingMs?: number;
  steps?: Array<{ profile: string; clip: string }>;
}
export interface AnimationState {
  open: boolean; busy: boolean; loaded: boolean; loading: boolean; current: Playback | false;
  message: string; toggleKey: string; stopKey: string;
}
export interface CatalogBatch { revision: number; batch: number; total: number; profiles: AnimationProfile[] }
export interface Preferences { favorites: string[]; recent: string[]; slots: Array<string | null>; layout: "grid" | "list" }
export const categories: Record<string, string> = {
  onthemove: "On the move", postures: "Postures", gestures: "Gestures", social: "Social", dance: "Dance",
  emotions: "Emotions", relaxation: "Relaxation", seated: "Seated", consumables: "Food & drink",
  work: "Work", music: "Music", interactions: "Interactions",
};
const placements: Record<string, string> = {
  standing: "Standing", ground: "On the ground", chair: "Position by a chair", wall: "Position by a wall",
  bed: "Position by a bed", counter: "Position by a counter", barstool: "Position by a bar stool",
};
const aliases: Record<string, string> = {
  handsup: "surrender mains levees", armscrossed: "bras croises", sit: "assis sol", chair: "assis chaise",
  dance: "danser danse", drink: "boire canette", bottle: "boire bouteille", takeout: "manger nourriture",
  smoke: "fumer cigarette", phone: "telephone", call: "telephone appel", clap: "applaudir",
  lie: "allonge dormir", lean: "mur", cry: "pleurer", repair: "reparer mecanicien", wave: "saluer bonjour",
};
export const normalize = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
export function entries(profiles: AnimationProfile[]): AnimationEntry[] {
  const seen = new Set<string>();
  return profiles.flatMap(profile => profile.clips.flatMap((clip, index) => {
    const key = `${profile.id}:${clip}`;
    if (seen.has(key)) return [];
    seen.add(key);
    const suffix = profile.clipPrefix && clip.startsWith(profile.clipPrefix) ? clip.slice(profile.clipPrefix.length) : clip;
    const variant = suffix.replace(/^_+/, "").replace(/_+/g, " ").replace(/\b0+(\d+)\b/g, "$1").trim() || "Default";
    return [{ key, profile, clip, variant: variant.charAt(0).toUpperCase() + variant.slice(1), index,
      walks: profile.kind === "layer" && profile.locomotion !== false }];
  }));
}
export function matches(item: AnimationEntry, query: string) {
  const haystack = normalize(`${item.profile.label} ${item.profile.id} ${item.variant} ${item.clip} ${categories[item.profile.category] || ""} ${aliases[item.profile.id.replace(/_walk$/, "")] || ""}`);
  return normalize(query).trim().split(/\s+/).every(word => haystack.includes(word));
}
export function describe(item: AnimationEntry) {
  return item.walks ? `Walking allowed · ${item.profile.mode === "once" ? "One-shot gesture" : "Upper-body animation"}`
    : `${placements[item.profile.placement || "standing"] || "Standing"} · Moving cancels`;
}
export function readPreferences(key: string): Preferences {
  try { return parsePreferences(JSON.parse(localStorage.getItem(key) || "null")); }
  catch { return parsePreferences(null); }
}
export function parsePreferences(raw: unknown): Preferences {
  const defaults: Preferences = { favorites: [], recent: [], slots: [null, null, null, null], layout: "grid" };
    if (!raw || typeof raw !== "object") return defaults;
    const value = raw as Record<string, unknown>;
    const strings = (value: unknown, max: number) => Array.isArray(value) ? [...new Set(value.filter((x): x is string => typeof x === "string" && x.length <= 300))].slice(0, max) : [];
    const slots = Array.isArray(value.slots) ? value.slots : [];
    return { favorites: strings(value.favorites, 100), recent: strings(value.recent, 24),
      slots: defaults.slots.map((_, i) => typeof slots[i] === "string" && slots[i].length <= 300 ? slots[i] || null : null),
      layout: value.layout === "list" ? "list" : "grid" };
}
/** Reject malformed/stale batches and publish only a complete catalogue revision. */
export class CatalogAssembler {
  private revision = -1;
  private total = 0;
  private batches = new Map<number, AnimationProfile[]>();
  accept(value: CatalogBatch): AnimationProfile[] | null {
    if (!value || !Number.isInteger(value.revision) || value.revision < this.revision ||
      !Number.isInteger(value.total) || value.total < 1 || value.total > 256 ||
      !Number.isInteger(value.batch) || value.batch < 1 || value.batch > value.total ||
      !Array.isArray(value.profiles) || value.profiles.length > 4) return null;
    if (value.profiles.some(p => !p || typeof p.id !== "string" || typeof p.label !== "string" ||
      !Array.isArray(p.clips) || p.clips.some(c => typeof c !== "string"))) return null;
    if (value.revision > this.revision) {
      this.revision = value.revision; this.total = value.total; this.batches.clear();
    }
    if (this.total !== value.total || this.batches.has(value.batch)) return null;
    this.batches.set(value.batch, value.profiles);
    if (this.batches.size !== this.total) return null;
    return Array.from({ length: this.total }, (_, i) => this.batches.get(i + 1)!).flat();
  }
}
