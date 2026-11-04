/* The clinic's rules without React: what a surgery costs (eurodollars and capacity points), what
   it replaces, and why the clinic would refuse it. They mirror the server (op77_lightrp
   server/modules/cyberware.lua: Cyber.operate and fits): the server decides, the page only says
   it before the hold. Type imports only, so tests/model.test.ts runs this file under node. */
import type { Cyberware } from "./data";

/** Capacity points fitted, the body's total (street cred tier), and a body over it (fitted
    before the capacity existed: it keeps everything but fits nothing heavier). */
export interface Capacity { used: number; total: number; over?: boolean }

/** What the rules read from the session. */
export interface ClinicState {
  wallet: number;
  fittingFee: number;                   // one surgery without a purchase: fit from storage, take out
  installed: Record<string, string[]>;  // section -> implant ids
  storage: string[];                    // owned, not fitted (the payload's `stock`)
  capacity?: Capacity;                  // absent: no limit shown, none checked
  items: Record<string, Cyberware>;
}

export type Mode = "install" | "remove";

export const roman = (n: number): string => ["", "I", "II", "III", "IV", "V", "V+"][n] ?? String(n);
export const eddies = (n: number): string => n.toLocaleString("en-US").replace(/,/g, " ");

/** "III (Operator)": the street cred tier an implant needs. */
export const repLabel = (item: Cyberware): string =>
  `${roman(item.repTier ?? 0)}${item.repName ? ` (${item.repName})` : ""}`;

export const fittedIds = (s: Pick<ClinicState, "installed">): string[] => Object.values(s.installed).flat();
export const isFitted = (s: Pick<ClinicState, "installed">, id: string): boolean => fittedIds(s).includes(id);
export const isStored = (s: Pick<ClinicState, "storage">, id: string): boolean => s.storage.includes(id);

/** The capacity points an implant takes. */
export const points = (item: Cyberware | undefined): number =>
  item ? Math.max(0, Math.floor(item.capacity ?? 0)) : 0;

/** An iconic the patient does not own: it drops, it is never sold (no button). */
export const isDropOnly = (s: Pick<ClinicState, "installed" | "storage">, item: Cyberware): boolean =>
  item.iconic === true && !isFitted(s, item.id) && !isStored(s, item.id);

/** The fitted implant of the same family (one native slot): it goes to storage when this one is fitted. */
export function familyMate(s: Pick<ClinicState, "installed" | "items">, item: Cyberware): Cyberware | undefined {
  if (!item.family) return undefined;
  for (const id of fittedIds(s)) {
    const other = s.items[id];
    if (other && other.id !== item.id && other.family === item.family) return other;
  }
  return undefined;
}

/** The points fitted, counted from the body (the preview, or a payload without capacity). */
export const usedPoints = (s: Pick<ClinicState, "installed" | "items">): number =>
  fittedIds(s).reduce((n, id) => n + points(s.items[id]), 0);

/** The capacity used once `item` is fitted (its family mate out). */
export function capacityAfter(s: ClinicState, item: Cyberware): number {
  const used = s.capacity?.used ?? usedPoints(s);
  return used - points(familyMate(s, item)) + points(item);
}

/** Why the body has no room for `item`, or null (the server's fits(), same words). */
export function capacityRefusal(s: ClinicState, item: Cyberware): string | null {
  const cap = s.capacity;
  if (!cap) return null;
  const mate = familyMate(s, item);
  const after = cap.used - points(mate) + points(item);
  if (after <= cap.total) return null;
  // over capacity already: a swap that does not make it worse is allowed
  if (mate && after <= cap.used) return null;
  if (cap.used > cap.total) {
    return `Your body is over capacity (${cap.used} / ${cap.total} points): you keep what is fitted, but only a lighter swap fits until you are under it.`;
  }
  const free = Math.max(0, cap.total - cap.used + points(mate));
  return `Not enough capacity: ${item.name} takes ${points(item)} points, ${free} of your ${cap.total} are free. Take an implant out (it goes to your storage) or earn the next street cred tier.`;
}

/** What fitting it costs: the fitting fee from storage, the price otherwise (fitting included). */
export const fitPrice = (s: ClinicState, item: Cyberware): number =>
  isStored(s, item.id) ? s.fittingFee : item.price;

/** Why the clinic would refuse this surgery, or null. The server's order: already fitted, an
    iconic not owned, street cred (not for an implant already owned), capacity, then money. */
export function refusal(s: ClinicState, item: Cyberware, mode: Mode = "install"): string | null {
  if (mode === "remove") {
    if (!isFitted(s, item.id)) return "This implant is not installed.";
    if (s.wallet < s.fittingFee) return `Taking it out costs €$ ${eddies(s.fittingFee)}.`;
    return null;
  }
  if (isFitted(s, item.id)) return "Already installed.";
  const owned = isStored(s, item.id);
  if (!owned && item.iconic) return `Iconic implants are not for sale${item.source ? `: ${item.source} drops it.` : "."}`;
  if (!owned && item.locked) {
    return `Street cred too low: ${item.name} needs reputation tier ${repLabel(item)}. PvE missions, raids, gigs and PvE activities earn it.`;
  }
  const room = capacityRefusal(s, item);
  if (room) return room;
  const price = fitPrice(s, item);
  if (price > s.wallet) return `Not enough eurodollars in your bank account (€$ ${eddies(price)}).`;
  return null;
}

/** The operation done in the browser preview (the server does it in game): the family mate and
    a removed implant go to storage, a fitted one leaves it, the bank pays the price or the fee. */
export function simulate(s: ClinicState, item: Cyberware, mode: Mode): Pick<ClinicState, "installed" | "storage" | "wallet" | "capacity"> {
  const installed: Record<string, string[]> = {};
  for (const [section, ids] of Object.entries(s.installed)) installed[section] = ids.filter((id) => id !== item.id);
  let storage = s.storage.filter((id) => id !== item.id);
  let wallet = s.wallet;
  if (mode === "install") {
    const mate = familyMate(s, item);
    if (mate) {
      installed[mate.section] = (installed[mate.section] ?? []).filter((id) => id !== mate.id);
      storage = [...storage, mate.id];
    }
    installed[item.section] = [...(installed[item.section] ?? []), item.id];
    wallet -= fitPrice(s, item);
  } else {
    storage = [...storage, item.id];
    wallet -= s.fittingFee;
  }
  const next = { installed, storage, wallet, capacity: s.capacity };
  if (s.capacity) {
    const used = usedPoints({ installed, items: s.items });
    next.capacity = { used, total: s.capacity.total, over: used > s.capacity.total };
  }
  return next;
}

/** What the surgery on `item` would do, at a glance (the page's previews: capacity bar, wallet,
    card badges, the detail card's verdict). `verdict` follows refusal()'s order. */
export type Verdict = "ok" | "drop" | "rep" | "room" | "money";
export interface Projection {
  mode: Mode;
  used: number;            // points fitted now
  total?: number;          // the body's capacity (absent: no limit)
  add: number;             // points this surgery adds (install)
  freed: number;           // points it frees (the family mate replaced, or the implant taken out)
  after: number;           // points fitted after it
  over: number;            // points past the total after it (0 when it fits)
  cost: number;            // eurodollars it takes (price, or the fitting fee)
  walletAfter: number;
  verdict: Verdict;
  reason: string | null;   // refusal()'s words, null when the clinic would do it
  mate?: Cyberware;        // the family mate it replaces
}

export function project(s: ClinicState, item: Cyberware): Projection {
  const fitted = isFitted(s, item.id);
  const used = s.capacity?.used ?? usedPoints(s);
  const total = s.capacity?.total;
  if (fitted) {
    const freed = points(item);
    const reason = refusal(s, item, "remove");
    return { mode: "remove", used, total, add: 0, freed, after: used - freed, over: total === undefined ? 0 : Math.max(0, used - freed - total),
      cost: s.fittingFee, walletAfter: s.wallet - s.fittingFee, verdict: reason ? "money" : "ok", reason };
  }
  const mate = familyMate(s, item);
  const add = points(item), freed = points(mate);
  const after = used - freed + add;
  const cost = fitPrice(s, item);
  const owned = isStored(s, item.id);
  const reason = refusal(s, item, "install");
  const verdict: Verdict = !reason ? "ok"
    : !owned && item.iconic ? "drop"
    : !owned && item.locked ? "rep"
    : capacityRefusal(s, item) ? "room"
    : "money";
  return { mode: "install", used, total, add, freed, after, over: total === undefined ? 0 : Math.max(0, after - total),
    cost, walletAfter: s.wallet - cost, verdict, reason, mate };
}
