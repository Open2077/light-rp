import type { RecapColumn, RecapDialogPayload, RecapRewards, RecapRow, RecapSide } from "@/bridge/protocol";

/* The end-of-match recap (server/modules/recap.lua), read once per payload. Lua sends
   an empty list as `{}` and leaves nil and zero fields out: every list becomes an
   array here, every number a finite number, a missing count reads 0. No runtime import
   from "@/": the model tests run under node --test (tests/recap-model.test.ts). */

export const COLUMNS: RecapColumn[] = ["placement", "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "bossShare",
  "share", "captures", "holdS", "roundsWon", "busts", "escapes", "points", "timeMs", "bestLapMs", "checkpoints", "score"];

/** `blank`: a missing value reads "—" (not reached, not measured), else 0. */
export interface ColumnMeta { head: string; title: string; better: "high" | "low"; blank?: boolean }
export const COLUMN_META: Record<RecapColumn, ColumnMeta> = {
  placement: { head: "POS", title: "Placement", better: "low", blank: true },
  kills: { head: "K", title: "Kills", better: "high" },
  deaths: { head: "D", title: "Deaths", better: "low" },
  assists: { head: "A", title: "Assists", better: "high" },
  damage: { head: "DMG", title: "Damage dealt", better: "high" },
  damageTaken: { head: "TAKEN", title: "Damage taken", better: "high" },
  dps: { head: "DPS", title: "Damage per second: damage dealt ÷ seconds in the match", better: "high", blank: true },
  headshots: { head: "HS", title: "Headshots", better: "high" },
  bossShare: { head: "BOSS", title: "Share of the damage dealt to the boss", better: "high" },
  share: { head: "SHARE", title: "Share of the contribution", better: "high" },
  captures: { head: "CAPS", title: "Zones captured", better: "high" },
  holdS: { head: "HOLD", title: "Time holding the zones", better: "high" },
  roundsWon: { head: "RND", title: "Rounds won", better: "high" },
  busts: { head: "BUSTS", title: "Busts made as the cop", better: "high" },
  escapes: { head: "ESC", title: "Escapes", better: "high" },
  points: { head: "PTS", title: "Points", better: "high" },
  timeMs: { head: "TIME", title: "Time", better: "low", blank: true },
  bestLapMs: { head: "LAP", title: "Best lap", better: "low", blank: true },
  checkpoints: { head: "CP", title: "Checkpoints", better: "high" },
  score: { head: "SCORE", title: "Score", better: "high" },
};

const SOURCES = ["activity", "mission", "worldboss"] as const;
const TONES = ["win", "loss", "neutral"] as const;

const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);
const finite = (value: unknown): number | undefined => (typeof value === "number" && Number.isFinite(value) ? value : undefined);
const text = (value: unknown): string | undefined => (typeof value === "string" && value.trim() !== "" ? value : undefined);
const isColumn = (value: unknown): value is RecapColumn => typeof value === "string" && (COLUMNS as string[]).includes(value);

function normalizeRow(raw: unknown): RecapRow | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r = raw as Record<string, unknown>;
  const id = finite(r.id);
  if (id === undefined || id === 0) return undefined;
  const bot = r.bot === true || id < 0;
  // a bot's "[BOT] " / "[AI] " prefix: the BOT badge says it
  const named = text(r.name);
  const name = bot && named ? named.replace(/^\s*\[(BOT|AI)\]\s*/i, "") || named : named;
  const row: RecapRow = { id, name: name ?? (bot ? "Bot" : `Player ${id}`) };
  if (bot) row.bot = true;
  const side = finite(r.side);
  if (side !== undefined) row.side = Math.floor(side);
  if (r.left === true) row.left = true;
  const outcome = text(r.outcome);
  if (outcome) row.outcome = outcome;
  for (const c of COLUMNS) {
    const v = finite(r[c]);
    if (v !== undefined) row[c] = v;
  }
  return row;
}

function normalizeRewards(raw: unknown): RecapRewards {
  if (!raw || typeof raw !== "object") return {};
  const r = raw as Record<string, unknown>;
  const out: RecapRewards = {};
  if (r.test === true) out.test = true;
  const eddies = finite(r.eddies);
  if (eddies !== undefined) out.eddies = Math.trunc(eddies);
  if (text(r.eddiesReason)) out.eddiesReason = text(r.eddiesReason);
  if (text(r.eddiesNote)) out.eddiesNote = text(r.eddiesNote);
  const reputation = finite(r.reputation);
  if (reputation !== undefined) out.reputation = Math.trunc(reputation);
  if (r.reputationCapped === true) out.reputationCapped = true;
  const t = r.tier && typeof r.tier === "object" ? (r.tier as Record<string, unknown>) : undefined;
  const tier = t ? finite(t.tier) : undefined;
  if (t && tier !== undefined) {
    out.tier = { tier: Math.trunc(tier), name: text(t.name), points: finite(t.points), next: finite(t.next), nextName: text(t.nextName), up: t.up === true || undefined };
  }
  const hof = list<unknown>(r.hof).flatMap((h) => {
    if (!h || typeof h !== "object") return [];
    const e = h as Record<string, unknown>;
    const board = text(e.board), rank = finite(e.rank);
    return board && rank !== undefined ? [{ board, rank: Math.trunc(rank), before: finite(e.before) }] : [];
  });
  if (hof.length > 0) out.hof = hof;
  return out;
}

export function normalizeRecap(raw: unknown): RecapDialogPayload | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const p = raw as Record<string, unknown>;
  if (p.kind !== "recap") return undefined;
  const rows = list<unknown>(p.rows).map(normalizeRow).filter((r): r is RecapRow => !!r);
  const seen = new Set<RecapColumn>();
  let columns = list<unknown>(p.columns).filter(isColumn).filter((c) => (seen.has(c) ? false : (seen.add(c), true)));
  if (columns.length === 0) columns = COLUMNS.filter((c) => rows.some((r) => r[c] !== undefined));
  const sides = list<unknown>(p.sides).flatMap((s): RecapSide[] => {
    if (!s || typeof s !== "object") return [];
    const e = s as Record<string, unknown>;
    const id = finite(e.id);
    return id === undefined ? [] : [{ id: Math.floor(id), label: text(e.label) ?? `Side ${id}`, score: finite(e.score) }];
  });
  const lines = list<unknown>(p.lines).flatMap((l) => {
    if (!l || typeof l !== "object") return [];
    const e = l as Record<string, unknown>;
    const label = text(e.label);
    const value = typeof e.value === "number" && Number.isFinite(e.value) ? String(e.value) : text(e.value);
    return label && value ? [{ label, value }] : [];
  });
  const res = p.result && typeof p.result === "object" ? (p.result as Record<string, unknown>) : {};
  const tone = (TONES as readonly string[]).includes(res.tone as string) ? (res.tone as RecapDialogPayload["result"]["tone"]) : "neutral";
  const mvpRaw = p.mvp && typeof p.mvp === "object" ? (p.mvp as Record<string, unknown>) : undefined;
  const mvpId = mvpRaw ? finite(mvpRaw.id) : undefined;
  const source = (SOURCES as readonly string[]).includes(p.source as string) ? (p.source as RecapDialogPayload["source"]) : "activity";
  const duration = finite(p.durationMs);
  const mode = text(p.mode) ?? "Match";
  const detail = text(p.detail);
  return {
    kind: "recap", id: text(p.id) ?? "", source, mode, modeKind: text(p.modeKind),
    detail: detail && detail.trim().toLowerCase() !== mode.trim().toLowerCase() ? detail : undefined, // "Turf War · Turf War"
    durationMs: duration !== undefined && duration > 0 ? duration : undefined,
    result: { label: text(res.label) ?? "DONE", tone, placement: finite(res.placement), of: finite(res.of) },
    test: p.test === true || undefined, unranked: p.unranked === true || undefined, you: finite(p.you) ?? 0,
    columns, sides, winnerSide: finite(p.winnerSide), rows, total: Math.max(rows.length, Math.floor(finite(p.total) ?? rows.length)), lines,
    mvp: mvpId !== undefined ? { id: mvpId, by: text(mvpRaw?.by) } : undefined,
    rewards: normalizeRewards(p.rewards), reopened: p.reopened === true || undefined,
  };
}

/* ── formats ── */

/** 754000 -> "12:34"; 3723000 -> "1:02:03". */
export function formatClock(ms: number): string {
  if (!Number.isFinite(ms)) return "—";
  const total = Math.max(0, Math.round(ms / 1000));
  const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60;
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}` : `${m}:${String(s).padStart(2, "0")}`;
}

/** 61234 -> "1:01.234" (as the activities panel). */
export function formatRaceTime(ms: number): string {
  if (!Number.isFinite(ms)) return "—";
  const total = Math.max(0, Math.round(ms));
  const minutes = Math.floor(total / 60000), seconds = Math.floor((total % 60000) / 1000), rest = total % 1000;
  return `${minutes}:${String(seconds).padStart(2, "0")}.${String(rest).padStart(3, "0")}`;
}

/** "€$ 1,250", as bridge/money.ts. */
export function formatEddies(amount: number): string {
  return `€$ ${Math.trunc(Number.isFinite(amount) ? amount : 0).toLocaleString("en-US")}`;
}

const thousands = (v: number): string => Math.round(v).toLocaleString("en-US");
const percent = (v: number): string => `${Number.isInteger(v) ? v : v.toFixed(1)}%`;

/** A race's time is its finishing time (lower is better); elsewhere a time lasted. */
export function betterOf(column: RecapColumn, modeKind?: string): "high" | "low" {
  if (column === "timeMs") return modeKind === "race" ? "low" : "high";
  return COLUMN_META[column].better;
}

/** One cell of the scoreboard, in its unit. */
export function formatCell(column: RecapColumn, row: RecapRow, modeKind?: string): string {
  const v = row[column];
  if (v === undefined) return COLUMN_META[column].blank ? "—" : "0";
  switch (column) {
    case "placement": return `#${Math.trunc(v)}`;
    case "dps": return v.toFixed(1);
    case "share": case "bossShare": return percent(v);
    case "holdS": return formatClock(v * 1000);
    case "timeMs": return modeKind === "race" ? formatRaceTime(v) : formatClock(v);
    case "bestLapMs": return formatRaceTime(v);
    default: return thousands(v);
  }
}

/* ── the scoreboard ── */

/** No column: the server's order (placement, then score, kills, share, damage). */
export interface SortState { column?: RecapColumn; reverse?: boolean }

/** A header click: the column best first, the same column again reverses it. */
export function nextSort(current: SortState, column: RecapColumn | undefined): SortState {
  if (!column) return {};
  if (current.column === column) return { column, reverse: !current.reverse };
  return { column };
}

/** Sorted rows; a row without the value always goes last; ties keep the server's order. */
export function sortRows(rows: RecapRow[], sort: SortState, modeKind?: string): RecapRow[] {
  const column = sort.column;
  if (!column) return rows.slice();
  const high = betterOf(column, modeKind) === "high";
  const sign = (high ? -1 : 1) * (sort.reverse ? -1 : 1);
  return rows.map((row, index) => ({ row, index })).sort((a, b) => {
    const x = a.row[column], y = b.row[column];
    const blank = COLUMN_META[column].blank;
    // a missing count is a zero; a missing time or placement was never reached
    const xv = x ?? (blank ? undefined : 0), yv = y ?? (blank ? undefined : 0);
    if (xv === undefined && yv === undefined) return a.index - b.index;
    if (xv === undefined) return 1;
    if (yv === undefined) return -1;
    if (xv !== yv) return (xv - yv) * sign;
    return a.index - b.index;
  }).map((e) => e.row);
}

export interface RecapGroup { key: string; side?: RecapSide; won?: boolean; rows: RecapRow[] }

/** Rows by side when the match has two sides or more (rows of no known side last). */
export function groupRows(p: RecapDialogPayload, rows: RecapRow[]): RecapGroup[] {
  if (p.sides.length < 2) return [{ key: "all", rows }];
  const groups: RecapGroup[] = p.sides.map((side) => ({ key: `side-${side.id}`, side, won: p.winnerSide === side.id || undefined, rows: [] }));
  const other: RecapGroup = { key: "other", rows: [] };
  for (const row of rows) {
    const group = groups.find((g) => g.side!.id === row.side);
    (group ?? other).rows.push(row);
  }
  return [...groups, other].filter((g) => g.rows.length > 0);
}

/** "4 PLAYERS · 2 BOTS"; "40 ON THE BOARD · TOP 32 SHOWN" when the server cut it. */
export function headcount(p: RecapDialogPayload): string {
  const bots = p.rows.filter((r) => r.bot).length;
  const players = p.rows.length - bots;
  const parts = [`${players} PLAYER${players === 1 ? "" : "S"}`];
  if (bots > 0) parts.push(`${bots} BOT${bots === 1 ? "" : "S"}`);
  if (p.total > p.rows.length) return `${p.total} ON THE BOARD · TOP ${p.rows.length} SHOWN`;
  return parts.join(" · ");
}

/** "#2 OF 6" under the result; "OF 6" under a "#2" result. */
export function resultLine(p: RecapDialogPayload): string | undefined {
  const { label, placement, of } = p.result;
  if (placement === undefined) return undefined;
  const many = of !== undefined && of > 1;
  if (label === `#${placement}`) return many ? `OF ${of}` : undefined;
  return many ? `#${placement} OF ${of}` : `#${placement}`;
}

/** The sides' score line: "MILITECH 3 - 1 ARASAKA". */
export function scoreLine(p: RecapDialogPayload): string | undefined {
  if (p.sides.length < 2) return undefined;
  const [a, b] = p.sides;
  if (!a || !b) return undefined;
  if (a.score === undefined || b.score === undefined) return `${a.label} vs ${b.label}`.toUpperCase();
  return `${a.label} ${a.score} - ${b.score} ${b.label}`.toUpperCase();
}

export function modeIcon(p: RecapDialogPayload): string {
  if (p.source === "mission") return p.modeKind === "raid" ? "shield" : "briefcase";
  if (p.source === "worldboss") return "flame";
  switch (p.modeKind) {
    case "race": return "gauge";
    case "chase": return "siren";
    case "pve": return "crosshair";
    case "event": return "users";
    default: return "swords";
  }
}

/** A row's tag beside its name: LEFT, DNF, ESCAPED, BUSTED... */
export function outcomeTag(row: RecapRow): string | undefined {
  if (row.left) return "LEFT";
  if (!row.outcome) return undefined;
  const words: Record<string, string> = { dnf: "DNF", escaped: "ESCAPED", busted: "BUSTED", caught: "CAUGHT", left: "LEFT", out: "OUT", down: "DOWN" };
  return words[row.outcome];
}

/* ── the MVP ── */

export const MVP_BY: Record<string, string> = {
  provider: "PICKED BY THE MODE", share: "LARGEST SHARE", score: "TOP SCORE", placement: "BEST PLACEMENT", kills: "MOST KILLS", damage: "MOST DAMAGE",
};

export function mvpRow(p: RecapDialogPayload): RecapRow | undefined {
  return p.mvp ? p.rows.find((r) => r.id === p.mvp!.id) : undefined;
}

/** Up to three of the MVP's numbers, from the board's columns. */
export function mvpStats(p: RecapDialogPayload, row: RecapRow, max = 3): Array<{ column: RecapColumn; head: string; value: string }> {
  return p.columns.filter((c) => c !== "placement" && row[c] !== undefined).slice(0, max)
    .map((c) => ({ column: c, head: COLUMN_META[c].head, value: formatCell(c, row, p.modeKind) }));
}

/* ── the rewards line ── */

export interface RewardLine { key: string; label: string; value: string; note?: string; tone?: "accent" | "dim" }

/** Why a match paid no eddies (activity_pay.lua, mission_pay.lua), as the player reads it. */
export const EDDIES_REASONS: Record<string, string> = {
  off: "Activity pay is off on this server.",
  unranked: "Unranked match: no pay.",
  not_paid: "This mode pays no eddies.",
  left: "You left before the end.",
  too_short: "Too short to pay.",
  no_progress: "No progress made.",
  bots: "Bots took part: no pay.",
  alone: "Pay needs another player.",
  crew: "Pay needs two crews.",
  repeat: "The same players already met for pay several times this hour.",
  none: "Nothing earned this time.",
  daily_cap: "Daily activity pay limit reached.",
  character: "You switched character: not paid.",
  not_credited: "The bank did not answer: tell the staff.",
  no_identity: "Your identity could not be read.",
  cooldown: "Repeat run: reduced pay.",
  capped: "Daily full payouts used: reduced pay.",
};
const SUCCESS_KINDS = new Set(["pvp", "pve", "full"]);

/** "(crew of 3, shared pot)" -> "crew of 3, shared pot". */
export function cleanNote(note: string | undefined): string | undefined {
  if (!note) return undefined;
  let s = note.trim();
  if (s.startsWith("(") && s.endsWith(")")) s = s.slice(1, -1).trim();
  s = s.replace(/^[·\-–\s]+/, "");
  return s === "" ? undefined : s;
}

export function rewardLines(r: RecapRewards, unranked?: boolean): RewardLine[] {
  if (r.test) return [{ key: "test", label: "TEST", value: "NO REWARDS", note: "Bot mode or a test run: nothing is recorded or paid.", tone: "dim" }];
  const out: RewardLine[] = [];
  const reason = r.eddiesReason && !SUCCESS_KINDS.has(r.eddiesReason) ? r.eddiesReason : undefined;
  if ((r.eddies ?? 0) > 0) {
    const why = reason ? EDDIES_REASONS[reason] : undefined;
    const note = [why, cleanNote(r.eddiesNote)].filter(Boolean).join(" · ") || undefined;
    out.push({ key: "eddies", label: "EDDIES", value: `+${formatEddies(r.eddies!)}`, note, tone: "accent" });
  } else if (reason) {
    out.push({ key: "eddies", label: "EDDIES", value: "NONE", note: EDDIES_REASONS[reason] ?? reason.replace(/_/g, " "), tone: "dim" });
  }
  if ((r.reputation ?? 0) > 0) out.push({ key: "rep", label: "REPUTATION", value: `+${r.reputation!.toLocaleString("en-US")} REP`, tone: "accent" });
  else if (r.reputationCapped) out.push({ key: "rep", label: "REPUTATION", value: "+0 REP", note: "Reputation limit reached for now.", tone: "dim" });
  if (r.tier) {
    const t = r.tier;
    const name = t.name ? ` · ${t.name.toUpperCase()}` : "";
    const note = t.next !== undefined
      ? `${(t.points ?? 0).toLocaleString("en-US")} / ${t.next.toLocaleString("en-US")} REP to ${t.nextName ?? "the next tier"}`
      : "Top tier reached.";
    out.push({ key: "tier", label: t.up ? "TIER UP" : "TIER", value: `TIER ${t.tier}${name}`, note, tone: t.up ? "accent" : undefined });
  }
  for (const h of r.hof ?? []) {
    const moved = h.before === undefined ? "New on the board." : h.before > h.rank ? `Up from #${h.before}.` : `Down from #${h.before}.`;
    out.push({ key: `hof-${h.board}`, label: "HALL OF FAME", value: `${h.board.toUpperCase()} #${h.rank}`, note: moved,
      tone: h.before === undefined || h.before > h.rank ? "accent" : "dim" });
  }
  if (out.length === 0) out.push({ key: "none", label: "REWARDS", value: "NONE", note: unranked ? "Unranked match: no pay." : "Nothing was paid for this one.", tone: "dim" });
  return out;
}
