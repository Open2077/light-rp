import { create } from "zustand";
import type { ActivitiesTab } from "@/bridge/protocol";

/* Talking to Johnny (server/modules/guide_dialogue.lua, content in
   server/config/guide_dialogue.lua). The guide dialog carries the opening node;
   the next nodes come as `guide` page messages ({ talk: { revision, nodes } }),
   each answer to `guide.node` bringing a node and the nodes its choices lead to.
   A node is Johnny's lines in pages and the player's choices: a choice leads to
   another node (`to`) or acts (`act`). The page adds "Go on." while pages remain,
   "Back." and "That's all.". */

export type TalkActionType = "gps" | "activities" | "halloffame" | "faq" | "search" | "jobguide" | "housing" | "support" | "animations" | "tutorial" | "briefing";
export interface TalkAction { type: TalkActionType; target?: string; tab?: ActivitiesTab; id?: string }
export interface TalkChoice { label: string; to?: string; act?: TalkAction }
export interface TalkNode { id: string; pages: string[][]; choices: TalkChoice[] }
export interface TalkOpening { revision: string; root: string; node: TalkNode; farewell?: string }
export interface TalkMessage { revision?: string; nodes?: TalkNode[]; missing?: string }

const ACTIONS: ReadonlySet<string> = new Set<TalkActionType>(["gps", "activities", "halloffame", "faq", "search", "jobguide", "housing", "support", "animations", "tutorial", "briefing"]);

/** Lua sends an empty list as {}. (model.ts has the same; no value import from it:
    the node tests load this file as it is.) */
function arr<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function normalizeChoice(value: unknown): TalkChoice | undefined {
  const c = value as Partial<TalkChoice> | undefined;
  if (!c || typeof c.label !== "string" || c.label === "") return undefined;
  if (typeof c.to === "string" && c.to !== "") return { label: c.label, to: c.to };
  const a = c.act as Partial<TalkAction> | undefined;
  if (!a || typeof a.type !== "string" || !ACTIONS.has(a.type)) return undefined;
  if ((a.type === "gps" && typeof a.target !== "string") || (a.type === "faq" && typeof a.id !== "string")) return undefined;
  const act: TalkAction = { type: a.type };
  if (typeof a.target === "string") act.target = a.target;
  if (typeof a.tab === "string") act.tab = a.tab;
  if (typeof a.id === "string") act.id = a.id;
  return { label: c.label, act };
}

/** Lua sends an empty list as {}: every list goes through arr(). */
export function normalizeNode(value: unknown): TalkNode | undefined {
  const n = value as Partial<TalkNode> | undefined;
  if (!n || typeof n.id !== "string" || n.id === "") return undefined;
  const pages = arr<unknown>(n.pages).map((p) => arr<unknown>(p).filter((l): l is string => typeof l === "string" && l.trim() !== "")).filter((p) => p.length > 0);
  const choices = arr<unknown>(n.choices).map(normalizeChoice).filter((c): c is TalkChoice => !!c);
  return { id: n.id, pages: pages.length > 0 ? pages : [["…"]], choices };
}

export function normalizeOpening(value: unknown): TalkOpening | undefined {
  const o = value as Partial<TalkOpening> | undefined;
  if (!o || typeof o.revision !== "string" || typeof o.root !== "string") return undefined;
  const node = normalizeNode(o.node);
  if (!node || node.id !== o.root) return undefined;
  return { revision: o.revision, root: o.root, node, farewell: typeof o.farewell === "string" && o.farewell !== "" ? o.farewell : undefined };
}

/* ---------- the feed: the nodes of the current revision ---------- */

interface TalkFeed {
  revision?: string;
  nodes: Record<string, TalkNode>;
  missing: Record<string, true>;
  /** A conversation starts: keep what this revision already holds, add the opening. */
  start(opening: TalkOpening): void;
  receive(message: TalkMessage | undefined): void;
}

export const useTalkFeed = create<TalkFeed>((set, get) => ({
  nodes: {}, missing: {},
  start: (opening) => {
    const same = get().revision === opening.revision;
    set({ revision: opening.revision, nodes: { ...(same ? get().nodes : {}), [opening.node.id]: opening.node }, missing: same ? get().missing : {} });
  },
  receive: (m) => {
    if (!m || typeof m !== "object" || typeof m.revision !== "string") return;
    // another revision: the tree changed on the server (a feature switched): start over
    const fresh = get().revision !== m.revision;
    const nodes = fresh ? {} : { ...get().nodes };
    const missing = fresh ? {} : { ...get().missing };
    for (const raw of arr<unknown>(m.nodes)) {
      const node = normalizeNode(raw);
      if (node) { nodes[node.id] = node; delete missing[node.id]; }
    }
    if (typeof m.missing === "string") missing[m.missing] = true;
    set({ revision: m.revision, nodes, missing });
  },
}));

/** The nodes a node's choices lead to that the page does not hold yet. */
export function missingTargets(node: TalkNode | undefined, nodes: Record<string, TalkNode>): string[] {
  if (!node) return [];
  return [...new Set(node.choices.map((c) => c.to).filter((id): id is string => !!id && !nodes[id]))];
}

/* ---------- what the list shows ---------- */

export type TalkRowKind = "choice" | "more" | "back" | "bye";
export interface TalkRow { key: string; kind: TalkRowKind; label: string; choice?: TalkChoice }

export const TALK_LABELS = { more: "Go on.", back: "Back.", bye: "That's all." } as const;

/** The rows under a page: "Go on." while pages remain, the choices on the last one,
    then "Back." (not at the opening) and "That's all.". `offer` hides a choice the
    player cannot use (a job guide without a job). */
export function talkRows(node: TalkNode | undefined, page: number, atRoot: boolean, offer: (c: TalkChoice) => boolean = () => true): TalkRow[] {
  const rows: TalkRow[] = [];
  if (node && page < node.pages.length - 1) rows.push({ key: "more", kind: "more", label: TALK_LABELS.more });
  else if (node) node.choices.forEach((c, i) => { if (offer(c)) rows.push({ key: `${i}:${c.to ?? c.act?.type ?? ""}:${c.act?.target ?? c.act?.id ?? c.act?.tab ?? ""}`, kind: "choice", label: c.label, choice: c }); });
  if (!atRoot) rows.push({ key: "back", kind: "back", label: TALK_LABELS.back });
  rows.push({ key: "bye", kind: "bye", label: TALK_LABELS.bye });
  return rows;
}

/** A key for "already asked": the node a choice leads to, or what it does. */
export function choiceKey(c: TalkChoice): string {
  return c.to ?? `act:${c.act?.type}:${c.act?.target ?? c.act?.id ?? c.act?.tab ?? ""}`;
}

const STEP = /^\s*\d+[.)]\s+/;
/** Where a page's numbered steps start: a list cut by a page break keeps counting. */
export function stepStart(pages: string[][], page: number): number {
  const current = pages[page] ?? [];
  if (!current[0] || !STEP.test(current[0])) return 1;
  let count = 0;
  for (let p = page - 1; p >= 0; p -= 1) {
    const lines = pages[p] ?? [];
    for (let i = lines.length - 1; i >= 0; i -= 1) {
      if (!STEP.test(lines[i]!)) return count + 1;
      count += 1;
    }
  }
  return count + 1;
}
