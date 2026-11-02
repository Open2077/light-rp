import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import type { Wire } from "./model";

export const mutationKey = () => `mission:${Date.now().toString(36)}:${Math.random().toString(36).slice(2, 12)}`;
export class MissionRequestTimeout extends Error {}

/* Every editor event, with large ones joined back: the client sends an event past 900
   values as JSON text parts (client/core/mission_editor.lua sendParts), each part an
   event { kind: "parts", id, part, parts, text }. */
const pending = new Map<string, string[]>();
const listeners = new Set<(event: Wire) => void>();
let attached = false;
export function onEditor(handler: (event: Wire) => void): () => void {
  listeners.add(handler);
  if (!attached) {
    attached = true;
    on<Wire>(PAGE_EVENTS.missionEditor, event => {
      let whole: Wire | undefined = event;
      if (event.kind === "parts" && typeof event.id === "string" && typeof event.part === "number" && typeof event.parts === "number") {
        const list = pending.get(event.id) ?? [];
        list[event.part - 1] = event.text ?? "";
        pending.set(event.id, list);
        if (list.filter(p => p !== undefined).length < event.parts) return;
        pending.delete(event.id);
        try { whole = JSON.parse(list.join("")) as Wire; } catch { whole = undefined; }
        if (!whole) return;
      }
      for (const fn of [...listeners]) fn(whole);
    });
  }
  return () => { listeners.delete(handler); };
}
let queue = Promise.resolve();
/** One request at a time to the client (captures) or the server (list, save, delete, test). */
export function request<T>(operation: string, payload: Record<string, unknown> = {}): Promise<T> {
  const task = queue.then(() => new Promise<T>((resolve, reject) => {
    const request = mutationKey();
    const stop = onEditor(reply => {
      if (reply.kind !== "response" || reply.request !== request) return;
      clearTimeout(timer); stop();
      if (reply.ok) resolve(reply.data as T);
      else reject(new Error(reply.error || "The request was refused."));
    });
    const timer = window.setTimeout(() => { stop(); reject(new MissionRequestTimeout("The server has not answered. Your draft is kept; retry to check the saved result.")); }, 12000);
    emit(PAGE_EVENTS.missionEditor, { ...payload, operation, request });
  }));
  queue = task.then(() => undefined, () => undefined).then(() => new Promise(resolve => setTimeout(resolve, 200)));
  return task;
}
