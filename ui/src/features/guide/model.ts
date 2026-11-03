import { create } from "zustand";
import type { ActivitiesTab, GuideDialogPayload, GuideTopicSummary } from "@/bridge/protocol";
import type { TalkMessage } from "./talk";

/* Johnny's FAQ (server/modules/guide.lua, content in server/config/guide.lua).
   The dialog carries the index; then, on the `guide` page event, come the player's
   own key names, the search index (in parts) and each topic the page asks for (in
   parts). Every message names the content revision: a new revision drops the cache.
   Lua sends an empty list as {}: every list goes through arr(). */

export type GuideActionType = "gps" | "activities" | "jobguide" | "housing" | "support" | "animations" | "tutorial" | "briefing";
export interface GuideAction { type: GuideActionType; label?: string; target?: string; tab?: ActivitiesTab }
export interface GuideQuestion { id: string; q: string; a: string[]; say?: string; follow: string[]; actions: GuideAction[] }
export interface GuideTopicMeta { id: string; title: string; icon?: string; blurb?: string; say?: string }
/** [question id, topic id, question, tags] */
export type GuideSearchRow = [string, string, string, string];

export interface GuideMessage {
  revision?: string;
  effectiveKeys?: Record<string, string>;
  search?: GuideSearchRow[];
  topic?: GuideTopicMeta;
  questions?: GuideQuestion[];
  part?: number;
  parts?: number;
  missing?: string;
  /** The dialogue's nodes (features/guide/talk.ts). */
  talk?: TalkMessage;
}

export function arr<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

export function normalizeIndex(d: GuideDialogPayload): GuideDialogPayload {
  return {
    ...d, greeting: arr<string>(d.greeting).filter((l) => typeof l === "string"),
    topics: arr<GuideTopicSummary>(d.topics).filter((t) => t && typeof t.id === "string"),
    keys: d.keys && typeof d.keys === "object" && !Array.isArray(d.keys) ? d.keys : {},
  };
}

function normalizeQuestion(q: GuideQuestion): GuideQuestion | undefined {
  if (!q || typeof q.id !== "string" || typeof q.q !== "string") return undefined;
  return {
    id: q.id, q: q.q, say: typeof q.say === "string" ? q.say : undefined,
    a: arr<string>(q.a).filter((l) => typeof l === "string"),
    follow: arr<string>(q.follow).filter((f) => typeof f === "string"),
    actions: arr<GuideAction>(q.actions).filter((a) => a && typeof a.type === "string"),
  };
}

/** The topic a question id belongs to: ids are "<topic>.<question>". */
export function topicOf(id: string): string {
  const dot = id.indexOf(".");
  return dot > 0 ? id.slice(0, dot) : id;
}

/* ---------- the feed: what arrived for the current revision ---------- */

export interface GuideTopicCache { meta: GuideTopicMeta; parts: Array<GuideQuestion[] | undefined>; total: number }

interface GuideFeed {
  revision?: string;
  keys: Record<string, string>;
  search: Record<string, GuideSearchRow>;
  searchParts: number[];
  searchTotal: number;
  topics: Record<string, GuideTopicCache>;
  missing: Record<string, true>;
  /** Keep the cache when `revision` is the one it holds, else start over. */
  ensure(revision: string): void;
  receive(message: GuideMessage): void;
}

export const useGuideFeed = create<GuideFeed>((set, get) => ({
  keys: {}, search: {}, searchParts: [], searchTotal: 0, topics: {}, missing: {},
  ensure: (revision) => {
    if (get().revision !== revision) set({ revision, search: {}, searchParts: [], searchTotal: 0, topics: {}, missing: {} });
  },
  receive: (m) => {
    if (!m || typeof m !== "object") return;
    if (m.effectiveKeys && typeof m.effectiveKeys === "object" && !Array.isArray(m.effectiveKeys)) set({ keys: { ...get().keys, ...m.effectiveKeys } });
    if (typeof m.revision !== "string") return;
    get().ensure(m.revision);
    const part = typeof m.part === "number" && m.part >= 1 ? m.part : 1;
    const parts = typeof m.parts === "number" && m.parts >= 1 ? m.parts : 1;
    if (Array.isArray(m.search) || (m.search && typeof m.search === "object")) {
      const search = { ...get().search };
      for (const row of arr<GuideSearchRow>(m.search)) if (Array.isArray(row) && typeof row[0] === "string") search[row[0]] = row;
      set({ search, searchParts: [...new Set([...get().searchParts, part])], searchTotal: parts });
    }
    if (m.topic && typeof m.topic.id === "string") {
      const prior = get().topics[m.topic.id];
      const list = prior && prior.total === parts ? [...prior.parts] : new Array<GuideQuestion[] | undefined>(parts).fill(undefined);
      list[part - 1] = arr<GuideQuestion>(m.questions).map(normalizeQuestion).filter((q): q is GuideQuestion => !!q);
      const missing = { ...get().missing };
      delete missing[m.topic.id];
      set({ topics: { ...get().topics, [m.topic.id]: { meta: m.topic, parts: list, total: parts } }, missing });
    }
    if (typeof m.missing === "string") set({ missing: { ...get().missing, [m.missing]: true } });
  },
}));

/** The questions of a topic once every part arrived, else undefined. */
export function topicQuestions(cache?: GuideTopicCache): GuideQuestion[] | undefined {
  if (!cache || cache.parts.some((p) => !p)) return undefined;
  return cache.parts.flatMap((p) => p ?? []);
}

/* ---------- search ---------- */

export interface GuideHit { id: string; topicId: string; q: string; topicTitle: string; score: number }

function fold(text: string): string {
  return text.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[`*{}]/g, " ");
}

/** Every word of the query must appear in the question, its tags or its topic's title. */
export function searchGuide(query: string, rows: GuideSearchRow[], titles: Record<string, string>, limit = 40): GuideHit[] {
  const words = fold(query).split(/[^a-z0-9€$/.]+/).filter((w) => w.length > 0);
  if (words.length === 0) return [];
  const hits: GuideHit[] = [];
  for (const [id, topicId, q, tags] of rows) {
    const title = titles[topicId] ?? topicId;
    const fq = fold(q), ft = fold(tags || ""), fTitle = fold(title);
    let score = 0, ok = true;
    for (const w of words) {
      const inQ = fq.includes(w), inTags = ft.includes(w), inTitle = fTitle.includes(w);
      if (!inQ && !inTags && !inTitle) { ok = false; break; }
      score += (inQ ? 3 : 0) + (inTags ? 2 : 0) + (inTitle ? 1 : 0) + (new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&")}`).test(fq) ? 2 : 0);
    }
    if (ok) hits.push({ id, topicId, q, topicTitle: title, score });
  }
  return hits.sort((a, b) => b.score - a.score || a.q.length - b.q.length).slice(0, limit);
}

/* ---------- answer text: blocks and inline markup ---------- */

export type GuideBlock =
  | { kind: "p"; text: string }
  | { kind: "bullets"; items: string[] }
  | { kind: "steps"; items: string[] }
  | { kind: "tip"; text: string };

/** Lines → blocks: "- " bullets, "1. " steps, "> " a tip, anything else a paragraph. */
export function toBlocks(lines: string[]): GuideBlock[] {
  const out: GuideBlock[] = [];
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (line.trim() === "") continue;
    const last = out[out.length - 1];
    const bullet = /^\s*[-•]\s+(.*)$/.exec(line);
    const step = /^\s*\d+[.)]\s+(.*)$/.exec(line);
    const tip = /^\s*>\s?(.*)$/.exec(line);
    if (bullet) { if (last?.kind === "bullets") last.items.push(bullet[1]!); else out.push({ kind: "bullets", items: [bullet[1]!] }); }
    else if (step) { if (last?.kind === "steps") last.items.push(step[1]!); else out.push({ kind: "steps", items: [step[1]!] }); }
    else if (tip) out.push({ kind: "tip", text: tip[1]! });
    else out.push({ kind: "p", text: line });
  }
  return out;
}

export type GuideInline =
  | { kind: "text"; text: string }
  | { kind: "code"; text: string }
  | { kind: "bold"; parts: GuideInline[] }
  | { kind: "key"; name: string };

/** `code`, **bold** (may hold the others) and {key:name} (the player's binding). */
export function parseInline(text: string): GuideInline[] {
  const out: GuideInline[] = [];
  const re = /`([^`]+)`|\*\*(.+?)\*\*|\{key:([A-Za-z0-9_]+)\}/g;
  let at = 0;
  for (let m = re.exec(text); m; m = re.exec(text)) {
    if (m.index > at) out.push({ kind: "text", text: text.slice(at, m.index) });
    if (m[1] !== undefined) out.push({ kind: "code", text: m[1] });
    else if (m[2] !== undefined) out.push({ kind: "bold", parts: parseInline(m[2]) });
    else out.push({ kind: "key", name: m[3]! });
    at = m.index + m[0].length;
  }
  if (at < text.length) out.push({ kind: "text", text: text.slice(at) });
  return out;
}

/** The same text without markup, keys spelled with the player's binding. */
export function plainText(text: string, keys: Record<string, string>): string {
  return text.replace(/\{key:([A-Za-z0-9_]+)\}/g, (_, name: string) => keys[name] ?? name.toUpperCase()).replace(/\*\*|`/g, "");
}
