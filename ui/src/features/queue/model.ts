import type { QueueState } from "@/bridge/protocol";
import type { RageMenuItem } from "@/design/components";

/* The queue panel (server/modules/activity_queue.lua), read once per push. The server
   pushes when the queue changes only: the wait counts up and the start counts down
   here, from the push. No runtime import from "@/": the model tests run under
   node --test (tests/queue-model.test.ts). */

export type QueueView = Exclude<QueueState, false>;
export type QueueStateName = QueueView["state"];
export type QueueSource = QueueView["source"];

const STATES: readonly QueueStateName[] = ["waiting", "starting", "joining"];
const SOURCES: readonly QueueSource[] = ["core", "provider", "mission"];
const HOUR_MS = 3600000;

function whole(value: unknown, max: number): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  const n = Math.floor(value);
  return n >= 0 && n <= max ? n : undefined;
}
function text(value: unknown, max: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const s = value.replace(/[\u0000-\u001f]+/g, " ").trim();
  return s ? s.slice(0, max) : undefined;
}

/** A pushed view, or false: junk fields dropped, `max` only when it is more than `need`,
 *  a countdown only while starting. */
export function normalizeQueue(raw: unknown): QueueState {
  if (!raw || typeof raw !== "object") return false;
  const q = raw as Record<string, unknown>;
  const id = text(q.id, 64), label = text(q.label, 64);
  if (!id || !label) return false;
  const need = whole(q.need, 1000) || undefined;
  let max = whole(q.max, 1000);
  if (max !== undefined && (need === undefined || max <= need)) max = undefined;
  const startsInMs = whole(q.startsInMs, HOUR_MS);
  const state: QueueStateName = STATES.includes(q.state as QueueStateName) ? q.state as QueueStateName
    : startsInMs !== undefined ? "starting" : "waiting";
  return {
    v: 1, id, label, mode: text(q.mode, 32), count: whole(q.count, 10000), need, max,
    sinceMs: whole(q.sinceMs, 24 * HOUR_MS) ?? 0,
    startsInMs: state === "starting" ? startsInMs : undefined, state,
    crew: q.crew === true || undefined,
    source: SOURCES.includes(q.source as QueueSource) ? q.source as QueueSource : "provider",
  };
}

/** Players in the queue against the players it takes: "3 / 6", "3 / 2-8", or "3" alone. */
export function countLabel(q: QueueView): string | undefined {
  if (q.count === undefined && q.need === undefined) return undefined;
  const have = String(q.count ?? 1);
  if (q.need === undefined) return have;
  return `${have} / ${q.max !== undefined ? `${q.need}-${q.max}` : q.need}`;
}

/** How many more it takes to start (0 once the minimum is there). */
export function missing(q: QueueView): number {
  return q.need === undefined ? 0 : Math.max(0, q.need - (q.count ?? 1));
}

const pad = (n: number) => String(n).padStart(2, "0");
/** Elapsed time, floored: 0:07, 2:14, 1:02:09. */
export function clockUp(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return h > 0 ? `${h}:${pad(m)}:${pad(s % 60)}` : `${m}:${pad(s % 60)}`;
}
/** Time left, rounded up (0:01 until it is really over). */
export function clockDown(ms: number): string {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(s / 60)}:${pad(s % 60)}`;
}

/** The wait so far and the start's time left, `elapsedMs` after the push. */
export function waitedMs(q: QueueView, elapsedMs: number): number { return q.sinceMs + Math.max(0, elapsedMs); }
export function startsInMs(q: QueueView, elapsedMs: number): number | undefined {
  return q.startsInMs === undefined ? undefined : Math.max(0, q.startsInMs - Math.max(0, elapsedMs));
}

/** The panel's tag, its tone, and a note beside the count ("NEED 2 MORE"). */
export function statusOf(q: QueueView): { tag: string; note?: string; tone: "plain" | "accent" | "go" } {
  if (q.state === "joining") return { tag: "MATCH FOUND", note: "JOINING", tone: "go" };
  if (q.state === "starting") return { tag: q.source === "mission" ? "LAUNCHING" : "STARTING", tone: "accent" };
  const more = missing(q);
  return { tag: q.source === "mission" ? "TAGGED" : "QUEUED", note: more > 0 ? `NEED ${more} MORE` : undefined, tone: "plain" };
}

/** The cancel key's cap: the bound key, "U" until the client says, none once cleared. */
export function keyCap(key: string | false | undefined): string | undefined {
  if (key === false) return undefined;
  const k = typeof key === "string" ? key.trim() : "";
  return k ? k.slice(0, 12) : key === undefined ? "U" : undefined;
}

/** What leaving does, for the F1 line and the panel's hint. */
export function leaveText(q: QueueView): string {
  if (q.source === "mission") return `Untags you from ${q.label}: the crew launches without you.`;
  return q.crew ? `Takes you out of the ${q.label} queue; your crew keeps waiting.`
    : `Withdraws you from the ${q.label} queue. Queued with your crew as its leader, the crew leaves with you.`;
}

/** F1's line while queued (beside Activities): it sends what the cancel key sends. */
export const QUEUE_LEAVE_ITEM = "queue-leave";
export function queueMenuItem(q: QueueState | undefined): RageMenuItem | undefined {
  if (!q) return undefined;
  return { id: QUEUE_LEAVE_ITEM, type: "item", text: "Leave queue", icon: "x", meta: countLabel(q) ?? "WAITING",
    description: `${q.label}${q.mode ? ` · ${q.mode}` : ""}. ${leaveText(q)}` };
}

/** Whether the activity HUD's own lobby header for `activity` repeats the panel (it steps aside). */
export function repeatsPanel(q: QueueState | undefined, activity: string | undefined, phase: string | undefined): boolean {
  return !!q && phase === "lobby" && !!activity && activity === q.id;
}
