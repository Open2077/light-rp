import type { ActivitiesState, ActivityDifficulty, ActivityEntry, ActivityKind, ActivityStats } from "@/bridge/protocol";

/* Lua sends an empty list as `{}`: every list of the `activities` state becomes an
   array here, once, in the store (state/store.ts applyState). */
const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);

export function normalizeActivities(raw: ActivitiesState | undefined): ActivitiesState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  return {
    ...raw,
    list: list<ActivityEntry>(raw.list).map((a) => ({ ...a, modes: list(a.modes), top: list(a.top), difficulties: list<ActivityDifficulty>(a.difficulties) })),
    nearby: list(raw.nearby),
    contracts: list(raw.contracts),
    current: raw.current || false,
    queued: raw.queued || false,
    reputation: raw.reputation ?? { today: 0, dailyCap: 0, maxPerResult: 0 },
    hub: raw.hub ?? { name: "The Crossing" },
  };
}

/** Reputation tiers as the pages write them: 1 -> "I". */
export const roman = (n: number | undefined): string => ["", "I", "II", "III", "IV", "V"][n ?? 0] ?? String(n ?? "");

/** The difficulty a PvE join sends: the picked one, else the first open one (the server checks). */
export function pickedDifficulty(a: ActivityEntry, picked: string | undefined): ActivityDifficulty | undefined {
  const list = a.difficulties ?? [];
  return list.find((d) => d.id === picked) ?? list.find((d) => !d.locked) ?? list[0];
}

/** The panel's footer: street cred tier and the PvE reputation of the day. */
export function repLine(state: ActivitiesState): string {
  const r = state.reputation;
  const cred = r.tier ? `Street cred ${roman(r.tier)}${r.tierName ? ` ${r.tierName}` : ""}${r.next != null ? ` (${r.points ?? 0}/${r.next})` : ""} · ` : "";
  return `${cred}PvE reputation today ${r.today}/${r.dailyCap} · PvP counts wins and rankings`;
}

export const KIND_ICON: Record<ActivityKind, string> = { pvp: "swords", race: "gauge", chase: "siren", event: "zap" };
export const KIND_LABEL: Record<ActivityKind, string> = { pvp: "PVP", race: "RACE", chase: "CHASE", event: "EVENT" };

/** 61234 -> "1:01.234" */
export function formatTime(ms: number | undefined): string {
  if (ms == null || !Number.isFinite(ms)) return "—";
  const total = Math.max(0, Math.round(ms));
  const minutes = Math.floor(total / 60000), seconds = Math.floor((total % 60000) / 1000), rest = total % 1000;
  return `${minutes}:${String(seconds).padStart(2, "0")}.${String(rest).padStart(3, "0")}`;
}

/** "02:15" from milliseconds. */
export function formatClock(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

/** The status line of an activity row. */
export function statusLine(a: ActivityEntry): string {
  if (!a.joinable) return a.detail || "CLOSED FOR NOW";
  if (a.phase === "running") return a.detail || `${a.players} PLAYING`;
  if (a.phase === "lobby") return a.detail || `${a.queued || a.players} IN THE LOBBY`;
  return a.detail || (a.minPlayers <= 1 ? "OPEN · SOLO OK" : "OPEN");
}

/** What the player's own line says for an activity. */
export function mineLine(a: ActivityEntry, stats: ActivityStats | undefined): string {
  if (!stats || stats.played <= 0) return "Not played yet.";
  const parts = [`${stats.played} played`, `${stats.wins} won`];
  if (a.byTime && stats.bestTimeMs != null) parts.push(`best ${formatTime(stats.bestTimeMs)}`);
  else if (stats.kills > 0 || stats.deaths > 0) parts.push(`${stats.kills} K / ${stats.deaths} D`);
  if (stats.bestPlacement != null) parts.push(`best #${stats.bestPlacement}`);
  return parts.join(" · ");
}
