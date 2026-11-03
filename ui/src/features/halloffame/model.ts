import type { HallOfFameBoard, HallOfFameDialogPayload, HallOfFameRow, HallOfFameTab, HallOfFameUnit } from "@/bridge/protocol";

/* The Hall of Fame payload (server/modules/halloffame.lua), read once per answer.
   Lua sends an empty list as `{}` and leaves nil fields out: every list becomes an
   array here, every number a finite number. No runtime import from "@/": the model
   tests run under node --test (tests/halloffame-model.test.ts). */

const TAB_ORDER: HallOfFameTab[] = ["overview", "pvp", "races", "pve", "missions", "wealth"];
const UNITS: HallOfFameUnit[] = ["wins", "kills", "time", "eddies", "rep", "count", "clears", "points"];

export const TAB_META: Record<HallOfFameTab, { label: string; icon: string; empty: string }> = {
  overview: { label: "OVERVIEW", icon: "crown", empty: "Nobody has made the Hall of Fame yet. The first results take the podiums." },
  pvp: { label: "PVP", icon: "swords", empty: "No PvP result yet: arena, duels, races, chases and turf war fill these boards." },
  races: { label: "RACES", icon: "gauge", empty: "No race time yet: finish a race at The Crossing to set the first one." },
  pve: { label: "PVE", icon: "crosshair", empty: "No PvE result yet: Combat Zone PvE, races vs AI and contracts fill these boards." },
  missions: { label: "MISSIONS", icon: "briefcase", empty: "No contract cleared yet: the mission boards of the city fill these boards." },
  wealth: { label: "WEALTH", icon: "wallet", empty: "Nobody has eddies on record yet." },
};

const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);
const num = (value: unknown, fallback = 0): number => (typeof value === "number" && Number.isFinite(value) ? value : fallback);
const text = (value: unknown): string | undefined => (typeof value === "string" && value !== "" ? value : undefined);
export const isTab = (value: unknown): value is HallOfFameTab => typeof value === "string" && (TAB_ORDER as string[]).includes(value);

function normalizeRow(raw: unknown): HallOfFameRow | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r = raw as Record<string, unknown>;
  const name = text(r.name);
  if (!name) return undefined;
  return { rank: Math.max(1, Math.floor(num(r.rank, 1))), name, value: num(r.value), detail: text(r.detail), you: r.you === true || undefined };
}

function normalizeBoard(raw: unknown): HallOfFameBoard | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const b = raw as Record<string, unknown>;
  const key = text(b.key), title = text(b.title);
  if (!key || !title) return undefined;
  const rows = list<unknown>(b.rows).map(normalizeRow).filter((r): r is HallOfFameRow => !!r);
  const mineRaw = b.mine && typeof b.mine === "object" ? (b.mine as Record<string, unknown>) : undefined;
  return {
    key, title, subtitle: text(b.subtitle), unit: (UNITS as string[]).includes(b.unit as string) ? (b.unit as HallOfFameUnit) : "count",
    ascending: b.ascending === true || undefined, total: Math.max(rows.length, Math.floor(num(b.total, rows.length))), rows,
    mine: mineRaw ? { rank: Math.max(1, Math.floor(num(mineRaw.rank, 1))), value: num(mineRaw.value), detail: text(mineRaw.detail) } : undefined,
  };
}

export function normalizeHallOfFame(raw: unknown): HallOfFameDialogPayload | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const p = raw as Record<string, unknown>;
  if (p.kind !== "halloffame") return undefined;
  const tabs = list<unknown>(p.tabs).filter(isTab);
  const tab = isTab(p.tab) ? p.tab : "overview";
  return {
    kind: "halloffame", title: text(p.title) ?? "HALL OF FAME", hub: text(p.hub) ?? "The Crossing", tab,
    tabs: tabs.length > 0 ? TAB_ORDER.filter((t) => tabs.includes(t)) : TAB_ORDER.filter((t) => t !== "wealth"),
    boards: list<unknown>(p.boards).map(normalizeBoard).filter((b): b is HallOfFameBoard => !!b),
    database: p.database !== false,
    updatedAgoS: typeof p.updatedAgoS === "number" && Number.isFinite(p.updatedAgoS) ? Math.max(0, p.updatedAgoS) : undefined,
    refreshInS: Math.max(0, Math.floor(num(p.refreshInS))),
    wealthBankOnly: p.wealthBankOnly === true || undefined,
  };
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

const SUFFIX: Partial<Record<HallOfFameUnit, [string, string]>> = {
  wins: ["WIN", "WINS"], kills: ["KILL", "KILLS"], clears: ["CLEAR", "CLEARS"], count: ["", ""], points: ["PT", "PTS"], rep: ["REP", "REP"],
};
/** A board value in its unit: "1:01.234", "€$ 1,250", "12 WINS", "2,450 REP". */
export function formatValue(value: number, unit: HallOfFameUnit): string {
  if (unit === "time") return formatRaceTime(value);
  if (unit === "eddies") return formatEddies(value);
  const n = Math.trunc(value).toLocaleString("en-US");
  const suffix = SUFFIX[unit];
  const word = suffix ? suffix[Math.trunc(value) === 1 ? 0 : 1] : "";
  return word ? `${n} ${word}` : n;
}

/** "UPDATED JUST NOW" / "UPDATED 3 MIN AGO" / "UPDATED 1 H AGO". */
export function updatedLine(agoS: number | undefined): string {
  if (agoS == null) return "NOT COMPUTED YET";
  if (agoS < 60) return "UPDATED JUST NOW";
  const minutes = Math.floor(agoS / 60);
  if (minutes < 60) return `UPDATED ${minutes} MIN AGO`;
  return `UPDATED ${Math.floor(minutes / 60)} H AGO`;
}

/** "#01" for the rank column. */
export const rankLabel = (rank: number): string => `#${String(rank).padStart(2, "0")}`;

/** Ties share a rank: "#03 =" when the next or the previous row has the same one. */
export function tied(rows: HallOfFameRow[], index: number): boolean {
  const r = rows[index];
  if (!r) return false;
  return (rows[index - 1]?.rank === r.rank) || (rows[index + 1]?.rank === r.rank);
}

/** The viewer's line under a board: in the top, below it, or not ranked. */
export function mineLine(board: HallOfFameBoard): string | undefined {
  if (board.rows.some((r) => r.you)) return undefined;
  if (!board.mine) return undefined;
  return `YOU ${rankLabel(board.mine.rank)} OF ${board.total} · ${formatValue(board.mine.value, board.unit)}${board.mine.detail ? ` · ${board.mine.detail}` : ""}`;
}

/** The three podium places, drawn 2-1-3; fewer rows draw fewer steps. */
export function podium(rows: HallOfFameRow[]): Array<{ row: HallOfFameRow; place: 1 | 2 | 3 }> {
  const top = rows.slice(0, 3);
  const out: Array<{ row: HallOfFameRow; place: 1 | 2 | 3 }> = [];
  if (top[1]) out.push({ row: top[1], place: 2 });
  if (top[0]) out.push({ row: top[0], place: 1 });
  if (top[2]) out.push({ row: top[2], place: 3 });
  return out;
}
