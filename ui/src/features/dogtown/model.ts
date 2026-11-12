import type { RageMenuItem } from "@/design/components";

/* Dogtown, the open PvP zone (server/modules/dogtown.lua, state key `dogtown`).
   The server decides everything; the page shows the banner on entry, the tile while
   inside or combat-tagged (the stake warning, the escort countdown, a bounty), and
   the rules and the record in F1 → Dogtown. Every number comes from the server's
   config (server/config/dogtown.lua) through `rules`. */

export interface DogtownStats { kills: number; deaths: number; looted: number; bestStreak: number }
export interface DogtownTopRow { rank: number; name: string; kills: number; deaths: number; looted: number }
export interface DogtownRules {
  /** "bag": the loss drops where the victim fell; "transfer": straight to the killer. */
  mode: "bag" | "transfer";
  /** The loss: `share` of the funds (pocket cash + bank), at least `min`, at most `max`, never more than carried. */
  share: number; min: number; max: number;
  /** The killer's server bonus (a fraction of the loss), capped per account and day. */
  bonus: number; bonusDailyCap: number;
  /** The bag is the killer's crew's this long. */
  reserveSeconds: number;
  tagSeconds: number; pairCooldownMinutes: number;
  /** Funds (pocket cash + bank) needed to fight; the grace before an escort out. */
  stake: number; graceSeconds: number;
  /** Anti-gank: a crew this big in the zone takes `gankFactor` of the loss; a bigger victim crew adds `underdogBonus`. */
  gankCrew: number; gankFactor: number; underdogBonus: number;
  bountyStreak: number; bountyPerKill: number; bountyMax: number;
  /** Entry protection: this long out of the PvP grant after walking in (0 = off). */
  protectionSeconds: number;
}
export interface DogtownStake {
  required: number; cash: number; missing: number;
  /** Inside without the stake: warned, escorted out when evictInMs (at the push) runs out. */
  short: boolean; evictInMs: number;
}
export interface DogtownState {
  enabled: boolean; label: string;
  /** In the city bucket, playing, inside the walls. */
  inside: boolean;
  /** Combat-tagged: attackable even outside until the tag runs out (tagEndsInMs at the push). */
  tagged: boolean; tagEndsInMs: number;
  /** PvP actually granted (a combat scope holds the player). */
  armed: boolean;
  /** Entry protection running: nobody can hurt this player, nor they anyone (protectedInMs at the push). */
  protected: boolean; protectedInMs: number;
  stake: DogtownStake;
  /** Credited kills in a row; a bounty (pin on everyone's map) from rules.bountyStreak. */
  streak: number; bounty: boolean; bountyReward: number;
  /** Bounties running in the zone right now. */
  bounties: number;
  /** Server bonus this player's account earned today (kills and bounties). */
  bonusToday: number;
  rules: DogtownRules;
  mine: { week: DogtownStats; total: DogtownStats };
  /** This week's top killers. */
  top: DogtownTopRow[]; week: number;
}

const num = (v: unknown, d = 0) => (typeof v === "number" && Number.isFinite(v) ? v : d);
const stats = (s: Partial<DogtownStats> | undefined): DogtownStats =>
  ({ kills: num(s?.kills), deaths: num(s?.deaths), looted: num(s?.looted), bestStreak: num(s?.bestStreak) });

/** The wire hands an empty Lua table as `{}`: arrays and numbers are read defensively. */
export function normalizeDogtown(raw: Partial<DogtownState> | undefined): DogtownState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r: Partial<DogtownRules> = raw.rules ?? {};
  const s: Partial<DogtownStake> = raw.stake ?? {};
  return {
    enabled: raw.enabled === true, label: typeof raw.label === "string" ? raw.label : "Dogtown",
    inside: raw.inside === true, tagged: raw.tagged === true, tagEndsInMs: num(raw.tagEndsInMs), armed: raw.armed === true,
    protected: raw.protected === true, protectedInMs: num(raw.protectedInMs),
    stake: { required: num(s.required, num(r.stake)), cash: num(s.cash), missing: num(s.missing), short: s.short === true, evictInMs: num(s.evictInMs) },
    streak: num(raw.streak), bounty: raw.bounty === true, bountyReward: num(raw.bountyReward), bounties: num(raw.bounties), bonusToday: num(raw.bonusToday),
    rules: { mode: r.mode === "transfer" ? "transfer" : "bag", share: num(r.share), min: num(r.min), max: num(r.max),
      bonus: num(r.bonus), bonusDailyCap: num(r.bonusDailyCap), reserveSeconds: num(r.reserveSeconds),
      tagSeconds: num(r.tagSeconds, 20), pairCooldownMinutes: num(r.pairCooldownMinutes),
      stake: num(r.stake), graceSeconds: num(r.graceSeconds),
      gankCrew: num(r.gankCrew), gankFactor: num(r.gankFactor, 1), underdogBonus: num(r.underdogBonus),
      bountyStreak: num(r.bountyStreak), bountyPerKill: num(r.bountyPerKill), bountyMax: num(r.bountyMax),
      protectionSeconds: num(r.protectionSeconds) },
    mine: { week: stats(raw.mine?.week), total: stats(raw.mine?.total) },
    top: Array.isArray(raw.top) ? raw.top.map((row, i) => ({ rank: num(row?.rank, i + 1), name: String(row?.name ?? "?"),
      kills: num(row?.kills), deaths: num(row?.deaths), looted: num(row?.looted) })) : [],
    week: num(raw.week),
  };
}

/** What a death costs this pocket (before anti-gank): the share, at least the minimum,
    at most the cap, never more than carried (server/modules/dogtown.lua lossAmount). */
export function cashAtRisk(cash: number, rules: DogtownRules): number {
  if (cash <= 0) return 0;
  let amount = Math.floor(cash * rules.share);
  if (rules.min > 0) amount = Math.max(amount, rules.min);
  if (rules.max > 0) amount = Math.min(amount, rules.max);
  return Math.max(0, Math.min(amount, cash));
}

/** Funds (cash + bank) still needed to fight (0 = carrying the stake). */
export function stakeMissing(cash: number, rules: DogtownRules): number { return Math.max(0, rules.stake - Math.max(0, cash)); }

export function percent(share: number): string { return `${Math.round(share * 100)}%`; }

/** `fmt` formats eddies (bridge/money formatMoney with the server currency). */
export type Fmt = (amount: number) => string;

export function lootRule(rules: DogtownRules, fmt: Fmt): string {
  const bonus = rules.bonus > 0 ? `, with a ${percent(rules.bonus)} server bonus for the killer` : "";
  const where = rules.mode === "bag"
    ? `drops in a sealed bag where they fell${bonus}. The killer's crew has it for ${rules.reserveSeconds} s, then anyone can pick it up`
    : `goes straight to the killer${bonus}`;
  return `A killed player loses ${percent(rules.share)} of their money, cash and bank together (at least ${fmt(rules.min)}, at most ${fmt(rules.max)}, never more than they have): it ${where}. The pocket pays first, then the bank.`;
}

export function stakeRule(rules: DogtownRules, fmt: Fmt): string {
  return `You need ${fmt(rules.stake)} (cash + bank) to fight in Dogtown; no need to withdraw. Under it you can't shoot or be shot there, and after ${rules.graceSeconds} s inside you are taken to the nearest exit.`;
}

/** 120 -> "2:00". */
export function clock(seconds: number): string {
  const s = Math.max(0, Math.ceil(seconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function record(s: DogtownStats): string { return `K ${s.kills} · D ${s.deaths}`; }
function plural(n: number, word: string): string { return `${n} ${word}${n === 1 ? "" : "s"}`; }

export interface DogtownMenuNode { title: string; subtitle?: string; tag: string; items: RageMenuItem[] }

/* F1 → Dogtown: the rules, the player's record (this week, overall), this week's top killers. */
export function dogtownMenu(raw: Partial<DogtownState> | undefined, fmt: Fmt): { item: RageMenuItem; nodes: Record<string, DogtownMenuNode> } | undefined {
  const d = normalizeDogtown(raw);
  if (!d) return undefined;
  const r = d.rules;
  const item: RageMenuItem = { id: "dogtown", type: "submenu", target: "dogtown", text: "Dogtown", icon: "crosshair", danger: d.inside || d.bounty,
    meta: !d.enabled ? "CLOSED" : d.bounty ? "BOUNTY ON YOU" : d.inside ? "YOU ARE IN" : `${d.mine.week.kills} KILL${d.mine.week.kills === 1 ? "" : "S"}`,
    description: "The open PvP zone past the Dogtown walls: the rules, your record and this week's top killers." };
  const items: RageMenuItem[] = [
    { label: "THE RULES" },
    { id: "dogtown-law", type: "item", text: "No law past the walls", icon: "triangle-alert", meta: d.enabled ? "PVP ON" : "CLOSED", danger: d.enabled,
      description: d.enabled
        ? `Inside Dogtown anyone carrying the stake can shoot anyone else carrying it; crewmates never hurt each other. A hit given or taken tags you for ${r.tagSeconds} s: stepping out does not end the fight until it runs out. Safe zones, missions and activities keep their own rules.`
        : "Staff closed the zone for now: Dogtown follows the city's rules (no PvP)." },
    ...(r.protectionSeconds > 0 ? [{ id: "dogtown-protection", type: "item" as const, text: "Entry protection", icon: "shield",
      meta: d.protected ? "ON YOU" : clock(r.protectionSeconds),
      description: `Walking in gives you ${clock(r.protectionSeconds)} of safety: nobody can hurt you and you can't hurt anyone, so nobody camps the gates. It counts down even if you step back out, and comes back on a later entry after a minute away or a death, never during a fight.` }] : []),
    { id: "dogtown-stake", type: "item", text: "The stake", icon: "wallet", meta: `${fmt(r.stake)} CASH`, danger: d.stake.short, description: stakeRule(r, fmt) },
    { id: "dogtown-cash", type: "item", text: "Cash on a death", icon: "banknote", meta: `${percent(r.share)} · ${fmt(r.min)}–${fmt(r.max)}`, description: lootRule(r, fmt) },
    { id: "dogtown-bonus", type: "item", text: "Kill bonus", icon: "coins", meta: `+${percent(r.bonus)}`,
      description: `The server adds ${percent(r.bonus)} of the loss on top for the killer. Bonuses from kills and bounties are capped at ${fmt(r.bonusDailyCap)} a day per account (all its characters): ${fmt(d.bonusToday)} earned today.` },
    { id: "dogtown-crews", type: "item", text: "Crews", icon: "users", meta: `${r.gankCrew}+ = ${percent(r.gankFactor)}`,
      description: `Crewmates can't hurt each other in Dogtown. A crew with ${r.gankCrew} or more members in the zone takes only ${percent(r.gankFactor)} of the normal loss from its victims; taking down a member of a bigger crew adds ${percent(r.underdogBonus)} to the bonus.` },
    { id: "dogtown-bounty", type: "item", text: "Bounty", icon: "crosshair", meta: `${r.bountyStreak} IN A ROW`, danger: d.bounties > 0,
      description: `${r.bountyStreak} kills in a row without dying puts you on everyone's map until you die, leave the zone or log out. Your killer gets ${fmt(r.bountyPerKill)} per kill of your streak, up to ${fmt(r.bountyMax)}.${d.bounties > 0 ? ` ${d.bounties} ${d.bounties === 1 ? "bounty" : "bounties"} running now.` : ""}` },
    { id: "dogtown-fair", type: "item", text: "Fair play", icon: "shield-alert",
      description: `Nothing counts between two characters of one account or between crewmates, nor for the same killer on the same victim within ${r.pairCooldownMinutes} minutes: no kill, no loss, no bonus. Logging out while tagged drops your loss where you stand. A killed player respawns outside, at the hospital.` },
    { separator: true }, { label: "YOUR RECORD" },
  ];
  if (d.streak > 0) items.push({ id: "dogtown-streak", type: "item", text: d.bounty ? "Bounty on you" : "Current streak", icon: "flame", danger: d.bounty,
    meta: `${d.streak} IN A ROW`,
    description: d.bounty ? `You are on everyone's map: whoever takes you down gets ${fmt(d.bountyReward)}.` : `${plural(Math.max(0, r.bountyStreak - d.streak), "more kill")} without dying and you get a bounty on your head.` });
  items.push(
    { id: "dogtown-week", type: "item", text: "This week", icon: "timer", meta: record(d.mine.week), description: `${fmt(d.mine.week.looted)} looted this week · best streak ${d.mine.week.bestStreak}.` },
    { id: "dogtown-total", type: "item", text: "Overall", icon: "swords", meta: record(d.mine.total),
      description: `${fmt(d.mine.total.looted)} looted in Dogtown so far · best streak ${d.mine.total.bestStreak}. Kills only: Dogtown gives no reputation.` },
    { separator: true }, { label: "TOP KILLERS THIS WEEK" },
  );
  if (d.top.length === 0) items.push({ id: "dogtown-top-none", type: "item", text: "No kill yet this week", icon: "crown", disabled: true });
  for (const row of d.top) items.push({ id: `dogtown-top:${row.rank}`, type: "item", text: `${row.rank}. ${row.name}`, icon: row.rank === 1 ? "crown" : "crosshair",
    meta: `${row.kills} KILL${row.kills === 1 ? "" : "S"}`, description: `${plural(row.deaths, "death")} · ${fmt(row.looted)} looted this week.` });
  return { item, nodes: { dogtown: { title: "DOGTOWN", subtitle: d.enabled ? "OPEN PVP ZONE" : "ZONE CLOSED", tag: "DOGTOWN", items } } };
}
