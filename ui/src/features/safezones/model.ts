export interface Point { x: number; y: number; z: number }
export type Shape = "circle" | "box" | "poly";
export interface ExtraSafezoneRules {
  blockJump: boolean; blockMelee: boolean; blockGrenades: boolean;
  blockConsumables: boolean; blockReload: boolean; blockWeaponWheel: boolean;
}
export const EXTRA_RESTRICTIONS = [
  { key: "blockJump", label: "Interdire de sauter" },
  { key: "blockMelee", label: "Interdire le corps à corps" },
  { key: "blockGrenades", label: "Interdire les grenades" },
  { key: "blockConsumables", label: "Interdire les consommables natifs" },
  { key: "blockReload", label: "Interdire de recharger" },
  { key: "blockWeaponWheel", label: "Bloquer la roue des armes" },
] as const;
export function extraRuleDefaults(value: Partial<ExtraSafezoneRules> = {}): ExtraSafezoneRules {
  return { blockJump: value.blockJump ?? false, blockMelee: value.blockMelee ?? false,
    blockGrenades: value.blockGrenades ?? false, blockConsumables: value.blockConsumables ?? false,
    blockReload: value.blockReload ?? false, blockWeaponWheel: value.blockWeaponWheel ?? false };
}
export interface Zone extends ExtraSafezoneRules {
  id: string; label: string; bucket: number; enabled: boolean; revision: number;
  shape: Shape; center: Point; radius: number; length: number; width: number;
  heading: number; minZ: number; maxZ: number; points: Point[];
  blockRun: boolean; blockShoot: boolean; fullHeight: boolean;
}
export interface Permissions { view: boolean; edit: boolean; publish: boolean; delete: boolean }
export interface Listing { zones: Zone[]; permissions: Permissions; ready: boolean }
export interface Capture { position: Point; bucket: number; session: string }
export interface Wire {
  kind: string; request?: string; ok?: boolean; error?: string; data?: unknown;
  zones?: Zone[]; ready?: boolean; generation?: number; mode?: "world" | "menu";
  zone?: { id: string; label: string; blockRun?: boolean; blockShoot?: boolean } & Partial<ExtraSafezoneRules>;
}
export const SHAPES: Shape[] = ["circle", "box", "poly"];
export const shapeName: Record<Shape, string> = { circle: "Cylindre", box: "Boîte orientée", poly: "Polygone" };
export const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
export function fresh(c: Capture): Zone {
  return { id: "", label: "Nouvelle zone", bucket: c.bucket, enabled: true, revision: 0,
    shape: "circle", center: { ...c.position }, radius: 10, length: 20, width: 12,
    heading: 0, minZ: c.position.z - 1, maxZ: c.position.z + 5, points: [],
    blockRun: false, blockShoot: true, fullHeight: false, ...extraRuleDefaults() };
}
export function normalizeZone(z: Zone): Zone {
  // Empty Lua arrays arrive as {}. Unused geometry fields may be omitted by the server.
  return { ...z, radius: z.radius ?? 10, length: z.length ?? 20, width: z.width ?? 12, heading: z.heading ?? 0,
    blockRun: z.blockRun ?? false, blockShoot: z.blockShoot ?? true, fullHeight: z.fullHeight ?? false,
    ...extraRuleDefaults(z),
    center: z.center ?? { x: 0, y: 0, z: z.minZ ?? 0 }, points: Array.isArray(z.points) ? z.points : [] };
}
export function invalid(z: Zone): string | undefined {
  if (!z.label.trim() || z.label.trim().length > 80) return "Le nom doit contenir entre 1 et 80 caractères.";
  const values = [z.center.x, z.center.y, z.center.z, z.minZ, z.maxZ,
    ...(z.shape === "circle" ? [z.radius] : z.shape === "box" ? [z.length, z.width, z.heading] : z.points.flatMap(p => [p.x, p.y, p.z]))];
  if (values.some(v => !Number.isFinite(v))) return "Complétez tous les nombres de la géométrie.";
  if (values.some(v => Math.abs(v) > 100000)) return "Les coordonnées dépassent les limites du monde.";
  if (!z.fullHeight && (z.maxZ - z.minZ < 0.1 || z.maxZ - z.minZ > 200)) return "La hauteur doit être comprise entre 0,1 et 200 m.";
  if (z.shape === "circle" && (z.radius < 0.5 || z.radius > 250)) return "Le rayon doit être compris entre 0,5 et 250 m.";
  if (z.shape === "box" && [z.length, z.width].some(v => v < 0.5 || v > 500)) return "Les dimensions doivent être comprises entre 0,5 et 500 m.";
  if (z.shape === "poly" && (z.points.length < 3 || z.points.length > 32)) return "Placez entre 3 et 32 sommets pour fermer le polygone.";
  return undefined;
}
