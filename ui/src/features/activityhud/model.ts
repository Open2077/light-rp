/* The shared in-match activity HUD (client/core/activity_hud.lua): what the page
   receives, already validated and clamped by the Lua side. The page still reads it
   defensively: Lua serialises an empty table as `{}`, so every list is checked. */

export type ActivityPhase = "lobby" | "countdown" | "running" | "ended";
export type ActivityTone = "accent" | "danger" | "info" | "success";

export interface ActivityTimer { remainingMs: number; label?: string; countUp?: boolean }
export interface ActivityStat { label: string; value: string }
export interface ActivityProgress { id: string; label?: string; value: number; tone?: ActivityTone }
export interface ActivityTeam { name: string; color?: string; score?: string; self?: boolean }
export interface ActivityRow { name: string; values?: string[]; self?: boolean; team?: number }
export interface ActivityScoreboard { columns?: string[]; rows: ActivityRow[] }
export interface ActivityHint { key: string; label: string }

export interface ActivityHudState {
  activity?: string;
  title: string;
  subtitle?: string;
  phase: ActivityPhase;
  timer?: ActivityTimer;
  countdown?: number;
  objective?: string;
  stats?: ActivityStat[];
  progress?: ActivityProgress[];
  teams?: ActivityTeam[];
  scoreboard?: ActivityScoreboard;
  hints?: ActivityHint[];
}

export interface ActivityFeedItem { text: string; tone?: ActivityTone }
export interface ActivityBanner { title?: string; text?: string; tone?: ActivityTone; durationMs: number }
export interface ActivityResult { title?: string; placement?: number | string; subtitle?: string; lines?: ActivityStat[]; durationMs: number }

export type ActivityHudMessage =
  | { op: "show"; hud: ActivityHudState }
  | { op: "push"; kind: "feed"; item: ActivityFeedItem }
  | { op: "push"; kind: "banner"; item: ActivityBanner }
  | { op: "push"; kind: "result"; item: ActivityResult }
  | { op: "clear"; reason?: string };

const PHASES: ReadonlySet<string> = new Set(["lobby", "countdown", "running", "ended"]);
const arr = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);
const str = (value: unknown): string | undefined => (typeof value === "string" && value.length > 0 ? value : undefined);
const num = (value: unknown): number | undefined => (typeof value === "number" && Number.isFinite(value) ? value : undefined);

/** The HUD as the components read it: lists always arrays (possibly empty). */
export interface ActivityHudView extends Omit<ActivityHudState, "stats" | "progress" | "teams" | "hints" | "scoreboard"> {
  stats: ActivityStat[];
  progress: ActivityProgress[];
  teams: ActivityTeam[];
  hints: ActivityHint[];
  scoreboard?: { columns: string[]; rows: ActivityRow[] };
}

export function normalizeHud(raw: unknown): ActivityHudView | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const h = raw as Partial<ActivityHudState>;
  const board = h.scoreboard && typeof h.scoreboard === "object" ? h.scoreboard : undefined;
  const rows = arr<ActivityRow>(board?.rows).filter((r) => r && typeof r.name === "string")
    .map((r) => ({ ...r, values: arr<string>(r.values) }));
  const timer = h.timer && num(h.timer.remainingMs) != null ? h.timer : undefined;
  return {
    activity: str(h.activity),
    title: str(h.title) ?? "Activity",
    subtitle: str(h.subtitle),
    phase: PHASES.has(h.phase as string) ? (h.phase as ActivityPhase) : "running",
    timer,
    countdown: num(h.countdown),
    objective: str(h.objective),
    stats: arr<ActivityStat>(h.stats).filter((s) => s && typeof s.label === "string"),
    progress: arr<ActivityProgress>(h.progress).filter((p) => p && num(p.value) != null),
    teams: arr<ActivityTeam>(h.teams).filter((t) => t && typeof t.name === "string"),
    hints: arr<ActivityHint>(h.hints).filter((x) => x && typeof x.key === "string" && typeof x.label === "string"),
    scoreboard: rows.length > 0 ? { columns: arr<string>(board?.columns), rows } : undefined,
  };
}

export function normalizeResult(raw: ActivityResult): ActivityResult {
  return { ...raw, lines: arr<ActivityStat>(raw.lines).filter((l) => l && typeof l.label === "string") };
}

const pad = (n: number, width = 2) => String(n).padStart(width, "0");

/** A count-down: m:ss (h:mm:ss past the hour). */
export function formatRemaining(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60;
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/** A count-up: m:ss.cc, to the hundredth (races are decided there). */
export function formatElapsed(ms: number): string {
  const v = Math.max(0, Math.floor(ms));
  const h = Math.floor(v / 3600000), m = Math.floor(v / 60000) % 60, s = Math.floor(v / 1000) % 60, cs = Math.floor((v % 1000) / 10);
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}.${pad(cs)}` : `${m}:${pad(s)}.${pad(cs)}`;
}

/** Where the clock stands `elapsed` ms after the snapshot. A count-up only moves while
    the activity runs (a finished time stays put); a count-down always runs out. */
export function clockValue(timer: ActivityTimer, phase: ActivityPhase, elapsed: number): number {
  if (timer.countUp) return phase === "running" ? timer.remainingMs + elapsed : timer.remainingMs;
  return Math.max(0, timer.remainingMs - elapsed);
}

/** 1 -> ST, 2 -> ND, 3 -> RD, 11..13 -> TH. */
export function ordinalSuffix(n: number): string {
  const v = n % 100;
  if (v >= 11 && v <= 13) return "TH";
  return ["TH", "ST", "ND", "RD"][n % 10] ?? "TH";
}

/** At most `max` rows, the player's own always among them: the top of the table, a
    gap, then the rows around the player. */
export function windowRows(rows: ActivityRow[], max: number): Array<ActivityRow & { rank: number } | null> {
  const ranked = rows.map((r, i) => ({ ...r, rank: i + 1 }));
  if (ranked.length <= max) return ranked;
  const self = ranked.findIndex((r) => r.self);
  if (self < 0 || self < max) return ranked.slice(0, max);
  const tail = 2; // the player and the one ahead
  const head = Math.max(1, max - tail - 1);
  return [...ranked.slice(0, head), null, ...ranked.slice(Math.max(head, self - 1), self + 1)];
}

/** A team colour from the Lua side: a hex value, or one of the signal tones. */
export function teamColor(color: string | undefined): string | undefined {
  if (!color) return undefined;
  if (/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(color)) return color;
  return TONE_VAR[color as ActivityTone];
}

export const TONE_VAR: Record<ActivityTone, string> = {
  accent: "var(--accent)",
  danger: "var(--o77-red)",
  info: "var(--o77-steel)",
  success: "var(--o77-green)",
};
