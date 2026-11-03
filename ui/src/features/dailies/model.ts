import type {
  DailiesDialogPayload, DailiesState, DailyCard, DailySlot, TitleEntry, TitleRarity, TitlesState,
} from "@/bridge/protocol";

/* Dailies and titles (server/modules/dailies.lua D.view, titles.lua T.view),
   read once per push. Lua sends an empty list as `{}` and leaves nil fields out:
   every list becomes an array here, every number a finite number. No runtime import
   from "@/": the model tests run under node --test (tests/dailies-model.test.ts). */

const SLOTS: DailySlot[] = ["street", "action", "shift", "crew", "weekly"];
const RARITIES: TitleRarity[] = ["common", "rare", "epic", "legendary", "live"];

export const SLOT_META: Record<DailySlot, { label: string; icon: string }> = {
  street: { label: "STREET", icon: "map-pin" },
  action: { label: "ACTION", icon: "crosshair" },
  shift: { label: "SHIFT", icon: "briefcase" },
  crew: { label: "CREW", icon: "users" },
  weekly: { label: "WEEKLY", icon: "calendar" },
};
export const RARITY_LABEL: Record<TitleRarity, string> = { common: "COMMON", rare: "RARE", epic: "EPIC", legendary: "LEGENDARY", live: "LIVE" };

const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? (value as T[]) : []);
const num = (value: unknown, fallback = 0): number => (typeof value === "number" && Number.isFinite(value) ? value : fallback);
const text = (value: unknown): string | undefined => (typeof value === "string" && value !== "" ? value : undefined);
const optNum = (value: unknown): number | undefined => (typeof value === "number" && Number.isFinite(value) ? Math.max(0, value) : undefined);
const record = (value: unknown): Record<string, unknown> => (value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {});
const isSlot = (value: unknown): value is DailySlot => typeof value === "string" && (SLOTS as string[]).includes(value);

function normalizeCard(raw: unknown): DailyCard | undefined {
  const c = record(raw);
  const id = text(c.id), title = text(c.title);
  if (!id || !title || !isSlot(c.slot)) return undefined;
  return {
    slot: c.slot, id, title, fixer: text(c.fixer) ?? "", fixerName: text(c.fixerName) ?? text(c.fixer) ?? "A fixer",
    brief: text(c.brief) ?? "", goal: text(c.goal) ?? "", value: Math.max(0, num(c.value)), target: Math.max(1, num(c.target, 1)),
    unit: c.unit === "m" || c.unit === "s" ? c.unit : undefined, done: c.done === true, claimed: c.claimed === true,
    reward: Math.max(0, Math.floor(num(c.reward))), swappable: c.swappable === true || undefined, needsCrew: c.needsCrew === true || undefined,
    crewLocked: c.crewLocked === true || undefined, social: c.social === true || undefined,
  };
}

export function normalizeDailies(raw: unknown): DailiesState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const d = raw as Record<string, unknown>;
  const budget = record(d.budget);
  const cards = list<unknown>(d.list).map(normalizeCard).filter((c): c is DailyCard => !!c)
    .sort((a, b) => SLOTS.indexOf(a.slot) - SLOTS.indexOf(b.slot));
  const older = list<unknown>(d.older).map(record)
    .map((o) => ({ id: text(o.id) ?? "", title: text(o.title) ?? "", reward: Math.max(0, Math.floor(num(o.reward))) }))
    .filter((o) => o.id !== "" && o.title !== "");
  return {
    enabled: d.enabled !== false, ready: d.ready === true, day: optNum(d.day), resetInMs: optNum(d.resetInMs), weekResetInMs: optNum(d.weekResetInMs),
    streak: Math.max(0, Math.floor(num(d.streak))), swapsLeft: Math.max(0, Math.floor(num(d.swapsLeft))),
    budget: { used: Math.max(0, num(budget.used)), max: Math.max(0, num(budget.max)) }, list: cards, older,
  };
}

export function normalizeDailiesDialog(raw: unknown): DailiesDialogPayload {
  return { kind: "dailies", tab: record(raw).tab === "titles" ? "titles" : "today" };
}

/* ── Contracts ── */

/** 640 -> "640 m", 1500 -> "1.5 km", 3000 -> "3 km"; seconds -> "1:05"; a count as is. */
export function formatAmount(value: number, unit?: "m" | "s"): string {
  const v = Math.max(0, Number.isFinite(value) ? value : 0);
  if (unit === "m") return v >= 1000 ? `${Number((v / 1000).toFixed(1))} km` : `${Math.floor(v)} m`;
  if (unit === "s") { const s = Math.floor(v); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; }
  return String(Math.floor(v));
}

/** The progress line: "DONE", "NOT YET" (a one-shot contract), or "1.2 km / 3 km". */
export function progressLabel(card: DailyCard): string {
  if (card.done) return "DONE";
  if (card.target <= 1 && !card.unit) return "NOT YET";
  return `${formatAmount(card.value, card.unit)} / ${formatAmount(card.target, card.unit)}`;
}
export const progressRatio = (card: DailyCard): number => (card.done ? 1 : Math.max(0, Math.min(1, card.value / Math.max(1, card.target))));

/** Would this claim go past today's budget? (the weekly is outside it; max 0 = no cap) */
export function overBudget(card: DailyCard, budget: DailiesState["budget"]): boolean {
  return card.slot !== "weekly" && budget.max > 0 && budget.used + card.reward > budget.max;
}

/** locked: a crew daily with no crewmate online, not started: shown as a placeholder. */
export type CardState = "claimed" | "claimable" | "budget" | "locked" | "crew" | "progress";
export function cardState(card: DailyCard, budget: DailiesState["budget"]): CardState {
  if (card.claimed) return "claimed";
  if (card.done) return overBudget(card, budget) ? "budget" : "claimable";
  if (card.crewLocked) return "locked";
  if (card.needsCrew) return "crew";
  return "progress";
}

/** Finished and unpaid, today's and yesterday's together (the F1 count). */
export function toClaim(d: DailiesState | undefined): number {
  if (!d?.enabled || !d.ready) return 0;
  return d.list.filter((c) => cardState(c, d.budget) === "claimable").length + d.older.length;
}

/** F1 > Dailies and the terminal's Dailies tab: what waits, else how far today's list is. */
export function menuMeta(d: DailiesState | undefined): string | undefined {
  if (!d) return undefined;
  if (!d.enabled) return "PAUSED";
  if (!d.ready) return undefined;
  const claim = toClaim(d);
  if (claim > 0) return `${claim} TO CLAIM`;
  const daily = d.list.filter((c) => c.slot !== "weekly");
  return `${daily.filter((c) => c.claimed).length}/${daily.length} PAID`;
}

/** "06:12:40" under a day, "3D 04H" above. */
export function countdown(ms: number): string {
  const s = Math.max(0, Math.ceil(ms / 1000));
  if (s >= 86400) return `${Math.floor(s / 86400)}D ${String(Math.floor((s % 86400) / 3600)).padStart(2, "0")}H`;
  return [Math.floor(s / 3600), Math.floor((s % 3600) / 60), s % 60].map((n) => String(n).padStart(2, "0")).join(":");
}

/** "MO" for Mama Okoro, "SV" for Silas "Ledger" Varga: the avatar of a fixer's message. */
export function initials(name: string): string {
  const words = name.split(/\s+/).filter((w) => w !== "" && !/^["'“]/.test(w));
  if (words.length === 0) return "?";
  const first = words[0]!.charAt(0), last = words.length > 1 ? words[words.length - 1]!.charAt(0) : "";
  return (first + last).toUpperCase();
}

export function streakLine(streak: number): string {
  return streak <= 0 ? "NONE YET" : `${streak} DAY${streak === 1 ? "" : "S"}`;
}

/* ── Titles ── */

function normalizeTitle(raw: unknown): TitleEntry | undefined {
  const t = record(raw);
  const id = text(t.id), label = text(t.label);
  if (!id || !label) return undefined;
  const count = optNum(t.count);
  return {
    id, label, rarity: (RARITIES as string[]).includes(t.rarity as string) ? (t.rarity as TitleRarity) : "common",
    group: text(t.group) ?? "other", how: text(t.how) ?? "", earned: t.earned === true || undefined, live: t.live === true || undefined,
    value: count !== undefined ? Math.min(count, optNum(t.value) ?? 0) : undefined, count, expiresInMs: optNum(t.expiresInMs),
  };
}

export function normalizeTitles(raw: unknown): TitlesState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const t = raw as Record<string, unknown>;
  const entries = list<unknown>(t.list).map(normalizeTitle).filter((e): e is TitleEntry => !!e);
  const groups = list<unknown>(t.groups).map(record).map((g) => ({ id: text(g.id) ?? "", label: text(g.label) ?? "" })).filter((g) => g.id !== "");
  const owns = (id: string | undefined) => (id && entries.some((e) => e.id === id) ? id : undefined);
  return { enabled: t.enabled !== false, shown: owns(text(t.shown)), chosen: owns(text(t.chosen)), groups, list: entries };
}

export interface TitleSection { id: string; label: string; items: TitleEntry[]; earned: number }
/** The groups in the server's order, empty ones left out; an unknown group lands under OTHER. */
export function titleSections(t: TitlesState): TitleSection[] {
  const known = new Set(t.groups.map((g) => g.id));
  const sections = [...t.groups, { id: "other", label: "Other" }].map((g) => {
    const items = t.list.filter((e) => (g.id === "other" ? !known.has(e.group) : e.group === g.id));
    return { id: g.id, label: g.label || g.id, items, earned: items.filter((e) => e.earned).length };
  });
  return sections.filter((s) => s.items.length > 0);
}

export type TitleStatus = "shown" | "hidden" | "earned" | "live" | "locked";
/** shown: others read it; hidden: chosen but not shown now (a rank-1 title lost); live: a rank-1 title not held. */
export function titleStatus(entry: TitleEntry, t: TitlesState): TitleStatus {
  if (entry.id === t.shown) return "shown";
  if (entry.id === t.chosen) return "hidden";
  if (entry.earned) return "earned";
  return entry.live ? "live" : "locked";
}

export const shownTitle = (t: TitlesState | undefined): TitleEntry | undefined => (t?.shown ? t.list.find((e) => e.id === t.shown) : undefined);
export const earnedCount = (t: TitlesState): number => t.list.filter((e) => e.earned).length;

/** Why the chosen title is not shown, if it is not. */
export function hiddenNote(t: TitlesState): string | undefined {
  if (!t.chosen || t.shown === t.chosen) return undefined;
  const e = t.list.find((x) => x.id === t.chosen);
  if (!e) return undefined;
  return e.live ? `${e.label} shows again the moment you retake rank 1.` : `${e.label} has run out. Pick another one.`;
}

/** "ENDS IN 2D 04H", "ENDS IN 3H 20M", "ENDS IN 12M". */
export function expiryLabel(ms: number): string {
  const m = Math.max(1, Math.ceil(ms / 60000));
  if (m >= 1440) return `ENDS IN ${Math.floor(m / 1440)}D ${String(Math.floor((m % 1440) / 60)).padStart(2, "0")}H`;
  if (m >= 60) return `ENDS IN ${Math.floor(m / 60)}H ${String(m % 60).padStart(2, "0")}M`;
  return `ENDS IN ${m}M`;
}
