/* The authored mission, as shared/mission_defs.lua validates it. The server is
   the authority: `invalid` only catches what the menu can explain early. */
export interface Point { x: number; y: number; z: number }
export interface Start extends Point { heading: number }
export type MissionType = "eliminate" | "waves";
export type Trigger = "start" | "checkpoint" | "wave";
export type Shape = "circle" | "box" | "poly";
export interface Perimeter {
  shape: Shape; center: Point; radius: number; length: number; width: number; heading: number;
  points: Point[]; minZ: number; maxZ: number; fullHeight: boolean;
}
export type Behavior = "assault" | "defend" | "patrol" | "wander" | "ambush";
export interface Spawn {
  id: string; label: string; position: Point; heading: number; enemy: string; count: number; trigger: Trigger;
  behavior: Behavior; radius: number; alertRange: number; spread: number; route: Point[];
}
/** The settings every spawn point placed in build mode starts with. */
export interface Brush { enemy: string; count: number; trigger: Trigger; behavior: Behavior; radius: number; alertRange: number; spread: number; checkpointRadius: number }
export const BRUSH: Brush = { enemy: "militech", count: 3, trigger: "start", behavior: "assault", radius: 12, alertRange: 25, spread: 2, checkpointRadius: 5 };
export const BEHAVIORS: Behavior[] = ["assault", "defend", "patrol", "wander", "ambush"];
export const BEHAVIOR_LABEL: Record<Behavior, string> = { assault: "Assault", defend: "Defend the area", patrol: "Patrol a route", wander: "Wander", ambush: "Ambush" };
export const BEHAVIOR_HELP: Record<Behavior, string> = {
  assault: "Rush the nearest operator as soon as they spawn.",
  defend: "Hold the area around the spawn point and fight from it. Area radius = how far they roam.",
  patrol: "Walk the patrol route (spawn point, then its patrol points, in a loop) until alerted.",
  wander: "Drift inside the area until alerted.",
  ambush: "Stand still and silent, blind to everything, until an operator comes within the alert range or one of them is shot.",
};
/** Build mode tools, in the Up/Down order. */
export type Tool = "spawn" | "checkpoint" | "start" | "perimeter" | "radius" | "patrol" | "move" | "board";
export const TOOLS: Tool[] = ["spawn", "checkpoint", "start", "perimeter", "radius", "patrol", "move", "board"];
export const TOOL_LABEL: Record<Tool, string> = { spawn: "Enemy spawn", checkpoint: "Checkpoint", start: "Squad start", perimeter: "Perimeter",
  radius: "Perimeter size", patrol: "Patrol route", move: "Move", board: "Mission board" };
/** What the crosshair points at (client/core/mission_editor.lua hovered()). */
export interface Ref { type: "spawn" | "checkpoint" | "start" | "board" | "vertex" | "centre" | "route"; id?: string; index?: number; label?: string }
export interface Checkpoint { id: string; label: string; position: Point; radius: number; required: boolean; spawns: string[] }
export interface Wave { delaySeconds: number; spawns: string[] }
export interface Difficulty {
  id: "standard" | "hard" | "critical"; label: string; blurb: string; payout: number; minutes: number; min: number; max: number;
  enemyHealth: number; enemyDamage: number; enemyCount: number;
}
/** A fixer gig (server/modules/fixers.lua): no board, the fixers text it to players. */
export interface Fixer { enabled: boolean; contact: string; brief: string }
export interface FixerContact { id: string; name: string }
export interface Mission {
  id: string; revision: number; title: string; description: string; location: string; type: MissionType; enabled: boolean; fixer: Fixer;
  point: Point; starts: Start[]; perimeter: Perimeter; outOfBounds: { graceSeconds: number };
  respawn: { seconds: number; lives: number }; spawns: Spawn[]; checkpoints: Checkpoint[]; waves: Wave[]; difficulties: Difficulty[];
}
export interface Capture { position: Point; heading: number }
export interface Listing { missions?: Mission[]; ready?: boolean; fixers?: FixerContact[] }
export interface Wire { kind: "open" | "response" | "invalidate" | "editor" | "captureKey" | "hover" | "build"; request?: string; ok?: boolean; data?: unknown; error?: string; mode?: string }

export const TYPES: MissionType[] = ["eliminate", "waves"];
export const TYPE_LABEL: Record<MissionType, string> = { eliminate: "Elimination", waves: "Survival (waves)" };
export const TRIGGERS: Trigger[] = ["start", "checkpoint", "wave"];
export const TRIGGER_LABEL: Record<Trigger, string> = { start: "At mission start", checkpoint: "Woken by a checkpoint", wave: "In a wave" };
export const SHAPES: Shape[] = ["circle", "box", "poly"];
export const SHAPE_LABEL: Record<Shape, string> = { circle: "Cylinder", box: "Oriented box", poly: "Polygon" };
/* Mirror of LightRpMissionDefs.ENEMIES (labels only: the server picks the character). */
export const ENEMIES = [
  { id: "militech", label: "Militech trooper" },
  { id: "militech_shotgun", label: "Militech breacher" },
  { id: "valentinos", label: "Valentinos gunner" },
  { id: "tygerclaws", label: "Tyger Claws gunner" },
  { id: "maelstrom", label: "Maelstrom ganger" },
] as const;
export const enemyLabel = (id: string) => ENEMIES.find(e => e.id === id)?.label ?? id;
export const DIFFICULTIES: Difficulty[] = [
  { id: "standard", label: "Standard", blurb: "The contract as written.", payout: 8000, minutes: 15, min: 1, max: 4, enemyHealth: 1, enemyDamage: 1, enemyCount: 1 },
  { id: "hard", label: "Hard", blurb: "More of them, and they hit harder.", payout: 15000, minutes: 15, min: 1, max: 4, enemyHealth: 1.5, enemyDamage: 1.25, enemyCount: 1.5 },
  { id: "critical", label: "Critical", blurb: "Bring your best kit and a full squad.", payout: 30000, minutes: 20, min: 2, max: 4, enemyHealth: 2.25, enemyDamage: 1.6, enemyCount: 2 },
];
export const LIMITS = { spawns: 48, checkpoints: 16, waves: 20, starts: 8, vertices: 32, count: 12, route: 8 };

export const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? value : []) as T[];
let idSeq = 0;
export const newId = (prefix: string, taken: string[]) => {
  for (;;) { const id = `${prefix}${(Date.now() % 100000).toString(36)}${(idSeq++).toString(36)}`; if (!taken.includes(id)) return id; }
};

export function fresh(c: Capture): Mission {
  const p = c.position;
  return {
    id: "", revision: 0, title: "New mission", description: "", location: "", type: "eliminate", enabled: true,
    fixer: { enabled: false, contact: "any", brief: "" },
    point: { ...p }, starts: [{ ...p, heading: c.heading }],
    perimeter: { shape: "circle", center: { ...p }, radius: 40, length: 60, width: 40, heading: 0, points: [], minZ: p.z - 10, maxZ: p.z + 30, fullHeight: false },
    outOfBounds: { graceSeconds: 10 }, respawn: { seconds: 10, lives: 3 },
    spawns: [], checkpoints: [], waves: [], difficulties: clone(DIFFICULTIES),
  };
}

/** Lua sends empty arrays as {} and omits unused geometry fields. */
export function normalizeMission(m: Mission): Mission {
  const z = (m.perimeter ?? {}) as Partial<Perimeter>;
  const byId = new Map(list<Difficulty>(m.difficulties).map(d => [d.id, d]));
  return {
    ...m, description: m.description ?? "", location: m.location ?? "",
    fixer: { enabled: m.fixer?.enabled === true, contact: m.fixer?.contact || "any", brief: m.fixer?.brief ?? "" },
    starts: list(m.starts), spawns: list<Spawn>(m.spawns).map(s => ({ ...s, behavior: s.behavior ?? "assault", radius: s.radius ?? 12,
      alertRange: s.alertRange ?? 25, spread: s.spread ?? 2, route: list<Point>(s.route) })),
    checkpoints: list<Checkpoint>(m.checkpoints).map(c => ({ ...c, spawns: list<string>(c.spawns) })),
    waves: list<Wave>(m.waves).map(w => ({ ...w, spawns: list<string>(w.spawns) })),
    perimeter: { shape: z.shape ?? "circle", center: z.center ?? { ...m.point }, radius: z.radius ?? 40, length: z.length ?? 60, width: z.width ?? 40,
      heading: z.heading ?? 0, points: list<Point>(z.points), minZ: z.minZ ?? m.point.z - 10, maxZ: z.maxZ ?? m.point.z + 30, fullHeight: z.fullHeight ?? false },
    outOfBounds: { graceSeconds: m.outOfBounds?.graceSeconds ?? 10 },
    respawn: { seconds: m.respawn?.seconds ?? 10, lives: m.respawn?.lives ?? 3 },
    difficulties: DIFFICULTIES.map(d => ({ ...d, ...(byId.get(d.id) ?? {}) })),
  };
}

/** The 2D/3D containment of shared/mission_defs.lua M.inside. */
export function inside(z: Perimeter, p: Point): boolean {
  if (!z.fullHeight && (p.z < z.minZ || p.z > z.maxZ)) return false;
  if (z.shape === "circle") return Math.hypot(p.x - z.center.x, p.y - z.center.y) <= z.radius;
  if (z.shape === "box") {
    const a = -z.heading * Math.PI / 180, dx = p.x - z.center.x, dy = p.y - z.center.y;
    const x = dx * Math.cos(a) - dy * Math.sin(a), y = dx * Math.sin(a) + dy * Math.cos(a);
    return Math.abs(x) <= z.length / 2 && Math.abs(y) <= z.width / 2;
  }
  let hit = false;
  for (let i = 0, n = z.points.length; i < n; i++) {
    const a = z.points[i]!, b = z.points[(i + 1) % n]!;
    if ((a.y > p.y) !== (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) hit = !hit;
  }
  return hit;
}

/** Everything that would stop publication, in the order the menu shows it. */
export function problems(m: Mission): string[] {
  const out: string[] = [];
  const z = m.perimeter;
  if (!m.title.trim() || m.title.trim().length > 60) out.push("Title: 1–60 characters.");
  if (m.fixer.brief.trim().length > 240) out.push("Fixer brief: 240 characters at most.");
  if (z.shape === "poly" && z.points.length < 3) out.push("Perimeter: place at least 3 polygon vertices.");
  if (z.shape === "circle" && (z.radius < 0.5 || z.radius > 250)) out.push("Perimeter: radius 0.5–250 m.");
  if (z.shape === "box" && [z.length, z.width].some(v => v < 0.5 || v > 500)) out.push("Perimeter: box sides 0.5–500 m.");
  if (!z.fullHeight && (z.maxZ - z.minZ < 0.1 || z.maxZ - z.minZ > 200)) out.push("Perimeter: height 0.1–200 m.");
  const shapeOk = z.shape !== "poly" || z.points.length >= 3;
  if (!m.starts.length) out.push("Place at least one squad start.");
  if (shapeOk) m.starts.forEach((s, i) => { if (!inside(z, s)) out.push(`Start ${i + 1} is outside the perimeter.`); });
  if (shapeOk) m.checkpoints.forEach(c => { if (!inside(z, c.position)) out.push(`${c.label} is outside the perimeter.`); });
  const used = new Set<string>();
  m.checkpoints.forEach(c => c.spawns.forEach(id => used.add(id)));
  if (m.type === "waves") {
    if (!m.waves.length) out.push("Add at least one wave.");
    m.waves.forEach((w, i) => { if (!w.spawns.length) out.push(`Wave ${i + 1} has no spawn point.`); w.spawns.forEach(id => used.add(id)); });
  }
  m.spawns.forEach(s => {
    if (m.type === "eliminate" && s.trigger === "wave") out.push(`${s.label}: waves only exist in Survival missions.`);
    else if (s.trigger !== "start" && !used.has(s.id)) out.push(`${s.label} ${s.trigger === "wave" ? "is in no wave" : "is woken by no checkpoint"}.`);
    if (s.behavior === "patrol" && !s.route.length) out.push(`${s.label}: a patrol needs at least one patrol point (Patrol route tool).`);
  });
  if (m.type === "eliminate" && !m.spawns.length) out.push("Place at least one enemy spawn point.");
  m.difficulties.forEach(d => { if (d.min > d.max) out.push(`${d.label}: min squad above max.`); });
  return out;
}
