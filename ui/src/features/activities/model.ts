import type { ActivitiesState, ActivityDifficulty, ActivityEntry, ActivityFriendly, ActivityFriendlyPlayer, ActivityKind, ActivityQueued, ActivityStats } from "@/bridge/protocol";

/* Lua sends an empty list as `{}`: every list of the `activities` state becomes an
   array here, once, in the store (state/store.ts applyState). */
const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);

function normalizeFriendly(raw: ActivityFriendly | false | undefined): ActivityFriendly | false {
  if (!raw || typeof raw !== "object") return false;
  const teams = raw.teams === undefined ? undefined : list<unknown>(raw.teams).map((t) => list<ActivityFriendlyPlayer>(t));
  return {
    ...raw,
    bench: list(raw.bench),
    teams,
    // a team shape's bots per team, as long as the teams (a missing one: 0)
    teamBots: teams ? teams.map((_, i) => Number(list<number>(raw.teamBots)[i] ?? 0)) : undefined,
    players: raw.players === undefined ? (teams ? undefined : []) : list(raw.players),
  };
}

export function normalizeActivities(raw: ActivitiesState | undefined): ActivitiesState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  return {
    ...raw,
    list: list<ActivityEntry>(raw.list).map((a) => ({ ...a, modes: list(a.modes), top: list(a.top), difficulties: list<ActivityDifficulty>(a.difficulties) })),
    nearby: list(raw.nearby),
    contracts: list(raw.contracts),
    current: raw.current || false,
    queued: raw.queued || false,
    friendly: normalizeFriendly(raw.friendly),
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

/* ── The lobby: bots, the ranked search, friendly crew matches ── */

/** PvP "Play with bots": the activity takes them, and the picked mode does not opt out. */
export function botsAllowed(a: ActivityEntry, mode: string | undefined): boolean {
  if (!a.lobby?.bots) return false;
  return !mode || a.modes.find((m) => m.id === mode)?.botFill !== false;
}

/** PvE "Fill empty slots with bots": the allied bots beside a crew of `crewSize`. */
export function alliesFor(a: ActivityEntry, crewSize: number): number {
  if (!a.lobby?.allies) return 0;
  return Math.max(0, (a.lobby.seats ?? a.maxPlayers) - Math.max(1, crewSize));
}

/** A join's options: the mode, the PvE difficulty, the bots choice (the server reads "true"). */
export function joinOptions(a: ActivityEntry, mode: string | undefined, difficulty: string | undefined, bots: boolean): Record<string, string> | undefined {
  const options: Record<string, string> = {};
  if (mode) options[a.modeKey || "mode"] = mode;
  if (difficulty) options.difficulty = difficulty;
  if (bots && (a.pve ? !!a.lobby?.allies : botsAllowed(a, mode))) options.bots = "true";
  return Object.keys(options).length > 0 ? options : undefined;
}

/** What a join counts for, in one line under the join button. */
export function rankedLine(a: ActivityEntry, mode: string | undefined, bots: boolean, crewSize: number): string {
  if (a.pve) {
    const n = bots ? alliesFor(a, crewSize) : 0;
    return n > 0 ? `${n} allied bot${n === 1 ? "" : "s"} fight beside you · reputation and pay as usual` : "PvE · reputation and pay";
  }
  if (bots && botsAllowed(a, mode)) return "UNRANKED · bots fill the places · no wins, ranking, Hall of Fame or pay";
  if (a.lobby?.queue) return a.lobby.brackets ? "RANKED · humans only · players near your cyberware rank first" : "RANKED · humans only";
  return "RANKED · humans only";
}

/** The join button: what pressing it does. */
export function joinLabel(a: ActivityEntry, mode: string | undefined, bots: boolean, queued: boolean, withCrew: boolean): string {
  if (queued) return "SWITCH TO THIS ONE";
  const crew = withCrew ? " WITH THE CREW" : "";
  if (!a.pve && bots && botsAllowed(a, mode)) return `PLAY WITH BOTS${crew}`;
  if (!a.pve && a.lobby?.queue) return `FIND A RANKED MATCH${crew}`;
  return withCrew ? "JOIN WITH THE CREW" : "JOIN";
}

/** The status strip's title for a join waiting. */
export function queuedTitle(q: ActivityQueued): string {
  const label = q.label.toUpperCase() + (q.mode ? ` ${q.mode.toUpperCase()}` : "");
  if (q.match) return q.friendly ? `FRIENDLY · JOINING ${label}` : q.ranked === false ? `BOT MATCH · JOINING ${label}` : `MATCH FOUND · JOINING ${label}`;
  if (q.search) return `SEARCHING · RANKED ${label}`;
  return `WAITING FOR ${label}`;
}

/** "3/4 PLAYERS": searchers that fit with you now, out of the players a match needs. */
export function searchCount(q: ActivityQueued): string {
  const s = q.search;
  if (!s || s.needed == null) return "";
  return `${Math.min(s.found ?? 0, s.needed)}/${s.needed} PLAYERS`;
}

/** The ranked search's reach: near your cyberware rank first, then everyone. */
export function searchScope(q: ActivityQueued): "NEAR YOUR RANK" | "ALL RANKS" | undefined {
  const s = q.search;
  if (!s?.scope) return undefined;
  return s.scope === "all" ? "ALL RANKS" : "NEAR YOUR RANK";
}

/** The bot fill offer (unranked) is open: its timer at the push has run out, for the one who decides. */
export function fillDue(q: ActivityQueued, sincePushMs: number): boolean {
  return q.lead !== false && !q.match && q.fillInMs != null && q.fillInMs - sincePushMs <= 0;
}

export const teamLetter = (index: number): string => String.fromCharCode(65 + index);

/** A column of the friendly set-up: a team (or the players of a free-for-all), then the bench. */
export interface FriendlyColumn { key: string; title: string; team: number; players: ActivityFriendlyPlayer[]; bots: number; size?: number }
export function friendlyColumns(f: ActivityFriendly): FriendlyColumn[] {
  const cols: FriendlyColumn[] = [];
  if (f.teams) {
    f.teams.forEach((players, i) => cols.push({ key: `team${i}`, title: `TEAM ${teamLetter(i)}`, team: i + 1, players,
      bots: f.bots ? f.teamBots?.[i] ?? 0 : 0, size: f.shape === "teams" && f.size > 0 ? f.size : undefined }));
  } else {
    cols.push({ key: "players", title: "PLAYING", team: 1, players: f.players ?? [], bots: f.bots ? f.enemies ?? 0 : 0 });
  }
  cols.push({ key: "bench", title: "BENCH", team: 0, players: f.bench, bots: 0 });
  return cols;
}

/** ← / → from column `col`: the team the player lands in (0: the bench), or undefined at an edge. */
export function moveTarget(cols: FriendlyColumn[], col: number, step: number): number | undefined {
  const next = cols[col + step];
  return next ? next.team : undefined;
}
