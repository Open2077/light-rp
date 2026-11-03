import type { RageMenuItem } from "@/design/components";

/* Dogtown, the open PvP zone (server/modules/dogtown.lua, state key `dogtown`).
   The server decides everything; the page shows the banner on entry, the tile while
   inside or combat-tagged, and the record in F1 → Dogtown. */

export interface DogtownStats { kills: number; deaths: number; looted: number }
export interface DogtownTopRow { rank: number; name: string; kills: number; deaths: number; looted: number }
export interface DogtownRules {
  /** "bag": the cash drops where the victim fell; "transfer": straight to the killer. */
  mode: "bag" | "transfer"; share: number; max: number; minCash: number; tagSeconds: number; pairCooldownMinutes: number;
}
export interface DogtownState {
  enabled: boolean; label: string;
  /** In the city bucket, playing, inside the walls. */
  inside: boolean;
  /** Combat-tagged: attackable even outside until the tag runs out (tagEndsInMs at the push). */
  tagged: boolean; tagEndsInMs: number;
  /** PvP actually granted (a combat scope holds the player). */
  armed: boolean;
  rules: DogtownRules;
  mine: { week: DogtownStats; total: DogtownStats };
  /** This week's top killers. */
  top: DogtownTopRow[]; week: number;
}

const num = (v: unknown, d = 0) => (typeof v === "number" && Number.isFinite(v) ? v : d);
const stats = (s: Partial<DogtownStats> | undefined): DogtownStats => ({ kills: num(s?.kills), deaths: num(s?.deaths), looted: num(s?.looted) });

/** The wire hands an empty Lua table as `{}`: arrays and numbers are read defensively. */
export function normalizeDogtown(raw: Partial<DogtownState> | undefined): DogtownState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r: Partial<DogtownRules> = raw.rules ?? {};
  return {
    enabled: raw.enabled === true, label: typeof raw.label === "string" ? raw.label : "Dogtown",
    inside: raw.inside === true, tagged: raw.tagged === true, tagEndsInMs: num(raw.tagEndsInMs), armed: raw.armed === true,
    rules: { mode: r.mode === "transfer" ? "transfer" : "bag", share: num(r.share), max: num(r.max), minCash: num(r.minCash),
      tagSeconds: num(r.tagSeconds, 20), pairCooldownMinutes: num(r.pairCooldownMinutes) },
    mine: { week: stats(raw.mine?.week), total: stats(raw.mine?.total) },
    top: Array.isArray(raw.top) ? raw.top.map((row, i) => ({ rank: num(row?.rank, i + 1), name: String(row?.name ?? "?"),
      kills: num(row?.kills), deaths: num(row?.deaths), looted: num(row?.looted) })) : [],
    week: num(raw.week),
  };
}

/** What a killer would take from this pocket: the share, capped, nothing under the threshold. */
export function cashAtRisk(cash: number, rules: DogtownRules): number {
  if (cash <= 0 || cash < rules.minCash) return 0;
  const amount = Math.floor(cash * rules.share);
  return Math.max(0, Math.min(rules.max > 0 ? Math.min(amount, rules.max) : amount, cash));
}

export function percent(share: number): string { return `${Math.round(share * 100)}%`; }

/** `fmt` formats eddies (bridge/money formatMoney with the server currency). */
export type Fmt = (amount: number) => string;

export function lootRule(rules: DogtownRules, fmt: Fmt): string {
  const where = rules.mode === "bag" ? "drops in a bag where they fell: anyone can pick it up" : "goes straight to the killer";
  return `A killed player loses ${percent(rules.share)} of the cash they carry (at most ${fmt(rules.max)}, nothing under ${fmt(rules.minCash)}): it ${where}. The bank is never touched.`;
}

function record(s: DogtownStats): string { return `K ${s.kills} · D ${s.deaths}`; }

export interface DogtownMenuNode { title: string; subtitle?: string; tag: string; items: RageMenuItem[] }

/* F1 → Dogtown: the rules, the player's record (this week, overall), this week's top killers. */
export function dogtownMenu(raw: Partial<DogtownState> | undefined, fmt: Fmt): { item: RageMenuItem; nodes: Record<string, DogtownMenuNode> } | undefined {
  const d = normalizeDogtown(raw);
  if (!d) return undefined;
  const item: RageMenuItem = { id: "dogtown", type: "submenu", target: "dogtown", text: "Dogtown", icon: "crosshair", danger: d.inside,
    meta: !d.enabled ? "CLOSED" : d.inside ? "YOU ARE IN" : `${d.mine.week.kills} KILL${d.mine.week.kills === 1 ? "" : "S"}`,
    description: "The open PvP zone past the Dogtown walls: the rules, your record and this week's top killers." };
  const items: RageMenuItem[] = [
    { label: "THE RULES" },
    { id: "dogtown-law", type: "item", text: "No law past the walls", icon: "triangle-alert", meta: d.enabled ? "PVP ON" : "CLOSED", danger: d.enabled,
      description: d.enabled
        ? `Inside Dogtown anyone can shoot anyone, crews included. A hit given or taken tags you for ${d.rules.tagSeconds} s: stepping out does not end the fight until it runs out. Safe zones, missions and activities keep their own rules.`
        : "Staff closed the zone for now: Dogtown follows the city's rules (no PvP)." },
    { id: "dogtown-cash", type: "item", text: "Cash on a kill", icon: "banknote", meta: `${percent(d.rules.share)} · MAX ${fmt(d.rules.max)}`, description: lootRule(d.rules, fmt) },
    { id: "dogtown-fair", type: "item", text: "Fair play", icon: "shield-alert",
      description: `No cash and no kill between two characters of one account or between crewmates, nor for the same killer on the same victim within ${d.rules.pairCooldownMinutes} minutes. A killed player respawns outside, at the hospital.` },
    { separator: true }, { label: "YOUR RECORD" },
    { id: "dogtown-week", type: "item", text: "This week", icon: "timer", meta: record(d.mine.week), description: `${fmt(d.mine.week.looted)} looted this week.` },
    { id: "dogtown-total", type: "item", text: "Overall", icon: "swords", meta: record(d.mine.total), description: `${fmt(d.mine.total.looted)} looted in Dogtown so far. Kills only: Dogtown gives no reputation.` },
    { separator: true }, { label: "TOP KILLERS THIS WEEK" },
  ];
  if (d.top.length === 0) items.push({ id: "dogtown-top-none", type: "item", text: "No kill yet this week", icon: "crown", disabled: true });
  for (const row of d.top) items.push({ id: `dogtown-top:${row.rank}`, type: "item", text: `${row.rank}. ${row.name}`, icon: row.rank === 1 ? "crown" : "crosshair",
    meta: `${row.kills} KILL${row.kills === 1 ? "" : "S"}`, description: `${row.deaths} death${row.deaths === 1 ? "" : "s"} · ${fmt(row.looted)} looted this week.` });
  return { item, nodes: { dogtown: { title: "DOGTOWN", subtitle: d.enabled ? "OPEN PVP ZONE" : "ZONE CLOSED", tag: "DOGTOWN", items } } };
}
