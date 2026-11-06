/* Parkour: the shapes the server sends (server/modules/parkour.lua) and the course
   contract the editor builds. Mirror of shared/parkour.lua (limits, validation): change both. */

export type Difficulty = "easy" | "medium" | "hard" | "extreme";
export const DIFFICULTIES: Difficulty[] = ["easy", "medium", "hard", "extreme"];
export const DIFFICULTY_LABEL: Record<Difficulty, string> = { easy: "Easy", medium: "Medium", hard: "Hard", extreme: "Extreme" };

export const LIMITS = { checkpoints: 50, name: 40, description: 200, minRouteM: 15, minGapM: 2, maxRouteM: 20000,
  radius: { default: 3, min: 1, max: 12 }, timeLimitMax: 60 };

export interface Point { x: number; y: number; z: number }
export interface Orb extends Point { radius: number }
export interface StartOrb extends Orb { heading: number }

/** A course as the editor holds it (and the server stores it). */
export interface Course {
  id: string; revision: number; status: "published" | "draft";
  name: string; description: string; difficulty: Difficulty;
  start?: StartOrb; checkpoints: Orb[]; finish?: Orb;
  timeLimit: number; floorZ?: number;
  // read-only, from the server
  length?: number; authorName?: string; attempts?: number; finishes?: number; runners?: number;
  record?: { timeMs: number; name: string };
}

/** A course on the card / the browser (server M.browser cardOf). */
export interface CourseCard {
  id: string; name: string; description: string; difficulty: Difficulty; checkpoints: number; length: number; timeLimit: number;
  fallLine?: boolean; author?: string; finishes: number; attempts: number; runners: number;
  record?: { timeMs: number; name: string }; best?: { timeMs: number; rank?: number; runs?: number };
  distance?: number; start: Point;
}
export interface ParkourDialogPayload {
  kind: "parkour"; courses: CourseCard[]; selected?: string; here?: string; running?: string; staff?: boolean;
  keys?: { restart: string; checkpoint: string };
}
export interface BoardRow { rank: number; name: string; timeMs: number; splits: string; runs: number; at: number; me?: boolean }
export interface BoardPayload {
  kind: "board"; course: string; revision?: number; page?: number; pages?: number; total?: number; shown?: number;
  rows?: BoardRow[]; checkpoints?: number; error?: string;
  best?: { timeMs: number; rank?: number; runs?: number; splits: string };
  record?: { timeMs: number; name: string; splits: string };
}

/** A run as the server describes it (kind "run"). */
export interface RunCourse {
  id: string; name: string; difficulty: Difficulty; revision: number; test?: boolean;
  start: StartOrb; checkpoints: Orb[]; finish: Orb; timeLimit: number; floorZ?: number; length: number;
}
export type ParkourEvent =
  | { kind: "run"; phase: string; course: RunCourse; attempt: number; best?: { timeMs: number; splits: string };
      record?: { timeMs: number; name: string; splits: string }; music?: { file: string; volume: number };
      resume?: boolean; elapsedMs?: number; checkpoint?: number }
  | { kind: "countdown"; goInMs: number; attempt: number }
  | { kind: "go"; attempt: number }
  | { kind: "cp"; index: number; total: number; elapsedMs: number; bestMs?: number; recordMs?: number; attempt: number }
  | { kind: "finish"; timeMs: number; splits: string; attempt: number }
  | ParkourResult
  | { kind: "dnf"; reason: string; text?: string; attempt: number; checkpoint: number; checkpoints: number }
  | { kind: "respawn"; reason: string; checkpoint: number }
  | { kind: "ended"; reason?: string }
  // the client's compass: where the next point lies from the camera (degrees, + = left), how far and how high
  | { kind: "bearing"; hide?: boolean; label?: string; angle?: number; distance?: number; rise?: number }
  | BoardPayload;
export interface ParkourResult {
  kind: "result"; timeMs: number; splits: string; attempt: number; test?: boolean; checkpoints: number; course: string; name: string;
  improved?: boolean; rank?: number; total?: number; previous?: { timeMs: number }; record?: { timeMs: number; name: string };
  recordBroken?: boolean; top?: Array<{ rank: number; name: string; timeMs: number; me?: boolean }>; error?: string;
}

// ---------------------------------------------------------------------------
// Formatting

/** 1:02.345, or 12.345 under a minute. */
export function formatTime(ms: number | undefined | null, decimals = 3): string {
  if (ms == null || !Number.isFinite(ms)) return "--:--";
  const t = Math.max(0, Math.floor(ms));
  const m = Math.floor(t / 60000), s = Math.floor(t / 1000) % 60;
  const frac = decimals === 3 ? String(t % 1000).padStart(3, "0") : String(Math.floor((t % 1000) / 10)).padStart(2, "0");
  return m > 0 ? `${m}:${String(s).padStart(2, "0")}.${frac}` : `${s}.${frac}`;
}
/** +1.234 / -0.420 (seconds), the sign always shown. */
export function formatDelta(ms: number): string {
  const sign = ms < 0 ? "-" : "+";
  const t = Math.abs(Math.round(ms));
  const s = Math.floor(t / 1000), f = String(t % 1000).padStart(3, "0");
  if (s >= 60) return `${sign}${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}.${f}`;
  return `${sign}${s}.${f}`;
}
export function decodeSplits(text: string | undefined | null): number[] {
  if (!text) return [];
  return text.split(",").map((v) => Number(v)).filter((v) => Number.isFinite(v));
}
export function formatLength(m: number | undefined): string {
  if (!m || !Number.isFinite(m)) return "—";
  return m >= 1000 ? `${(m / 1000).toFixed(2)} KM` : `${Math.round(m)} M`;
}

// ---------------------------------------------------------------------------
// Editor helpers

export const distance = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
export const round = (v: number, step = 0.01) => Math.round(v / step) * step;

export function route(c: Course): Orb[] {
  const list: Orb[] = [];
  if (c.start) list.push(c.start);
  list.push(...c.checkpoints);
  if (c.finish) list.push(c.finish);
  return list;
}
export function routeLength(c: Course): number {
  const r = route(c);
  let total = 0;
  for (let i = 1; i < r.length; i += 1) total += distance(r[i - 1]!, r[i]!);
  return total;
}

/** Why the server would refuse this course (the first reasons), [] when it is fine. */
export function problems(c: Course): string[] {
  const out: string[] = [];
  const name = c.name.trim();
  if (name.length < 3 || name.length > LIMITS.name) out.push(`Give the course a name (3 to ${LIMITS.name} characters).`);
  if (!c.start) out.push("Place the start.");
  if (!c.finish) out.push("Place the finish.");
  if (c.checkpoints.length > LIMITS.checkpoints) out.push(`At most ${LIMITS.checkpoints} checkpoints.`);
  for (const orb of route(c)) {
    if (orb.radius < LIMITS.radius.min || orb.radius > LIMITS.radius.max) { out.push(`Every radius is ${LIMITS.radius.min} to ${LIMITS.radius.max} m.`); break; }
  }
  if (c.start && c.finish) {
    const r = route(c);
    for (let i = 1; i < r.length; i += 1) {
      if (distance(r[i - 1]!, r[i]!) < LIMITS.minGapM) {
        const a = i - 1 === 0 ? "The start" : `Checkpoint ${i - 1}`;
        const b = i === r.length - 1 ? "the finish" : `checkpoint ${i}`;
        out.push(`${a} and ${b} are closer than ${LIMITS.minGapM} m.`); break;
      }
    }
    const length = routeLength(c);
    if (length < LIMITS.minRouteM) out.push(`The route is ${Math.round(length)} m long: ${LIMITS.minRouteM} m at least.`);
    if (length > LIMITS.maxRouteM) out.push(`The route is ${Math.round(length)} m long: ${LIMITS.maxRouteM} m at most.`);
    if (c.floorZ != null && c.floorZ >= c.start.z - 0.5) out.push("The fall line must be below the start.");
  }
  if (c.timeLimit < 0 || c.timeLimit > LIMITS.timeLimitMax) out.push(`The time limit is 0 (none) to ${LIMITS.timeLimitMax} minutes.`);
  return out;
}

export function fresh(at: { position: Point; heading: number }): Course {
  return { id: "", revision: 0, status: "published", name: "New course", description: "", difficulty: "medium",
    start: { ...roundPoint(at.position), radius: LIMITS.radius.default, heading: Math.round(at.heading) },
    checkpoints: [], finish: undefined, timeLimit: 0 };
}
export const roundPoint = (p: Point): Point => ({ x: round(p.x), y: round(p.y), z: round(p.z) });
export const clone = <T,>(v: T): T => JSON.parse(JSON.stringify(v)) as T;

export function normalizeCourse(raw: Partial<Course> & { id?: string }): Course {
  const orb = (o: Partial<Orb> | undefined): Orb | undefined => o && Number.isFinite(o.x) && Number.isFinite(o.y) && Number.isFinite(o.z)
    ? { x: Number(o.x), y: Number(o.y), z: Number(o.z), radius: Number(o.radius) || LIMITS.radius.default } : undefined;
  const start = orb(raw.start);
  return {
    id: raw.id ?? "", revision: Number(raw.revision) || 0, status: raw.status === "draft" ? "draft" : "published",
    name: String(raw.name ?? ""), description: String(raw.description ?? ""),
    difficulty: DIFFICULTIES.includes(raw.difficulty as Difficulty) ? raw.difficulty as Difficulty : "medium",
    start: start ? { ...start, heading: Number((raw.start as StartOrb | undefined)?.heading) || 0 } : undefined,
    checkpoints: Array.isArray(raw.checkpoints) ? raw.checkpoints.map((c) => orb(c)).filter((c): c is Orb => !!c) : [],
    finish: orb(raw.finish), timeLimit: Number(raw.timeLimit) || 0,
    floorZ: raw.floorZ != null && Number.isFinite(Number(raw.floorZ)) ? Number(raw.floorZ) : undefined,
    length: raw.length, authorName: raw.authorName, attempts: raw.attempts, finishes: raw.finishes, runners: raw.runners, record: raw.record,
  };
}

/** What the server stores of a course (identity aside). */
export function wire(c: Course) {
  return { id: c.id || undefined, name: c.name.trim(), description: c.description.trim(), difficulty: c.difficulty,
    start: c.start, checkpoints: c.checkpoints, finish: c.finish, timeLimit: c.timeLimit, floorZ: c.floorZ };
}
