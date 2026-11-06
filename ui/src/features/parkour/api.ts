import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";

/* The parkour editor's wire (client/core/parkour_editor.lua): events from the client
   (`open`, `editor`, `hover`, `build`, `captureKey`, `invalidate`, `response`), large ones
   as JSON text parts { kind: "parts", id, part, parts, text } joined here. */
export interface EditorWire {
  kind: string; request?: string; ok?: boolean; data?: unknown; error?: string; mode?: string;
  id?: string; part?: number; parts?: number; text?: string; [key: string]: unknown;
}
export const mutationKey = () => `parkour:${Date.now().toString(36)}:${Math.random().toString(36).slice(2, 12)}`;
export class EditorTimeout extends Error {}

const pending = new Map<string, string[]>();
const listeners = new Set<(event: EditorWire) => void>();
let attached = false;
export function onEditor(handler: (event: EditorWire) => void): () => void {
  listeners.add(handler);
  if (!attached) {
    attached = true;
    on<EditorWire>(PAGE_EVENTS.parkourEditor, (event) => {
      let whole: EditorWire | undefined = event;
      if (event?.kind === "parts" && typeof event.id === "string" && typeof event.part === "number" && typeof event.parts === "number") {
        const list = pending.get(event.id) ?? [];
        list[event.part - 1] = event.text ?? "";
        pending.set(event.id, list);
        if (list.filter((p) => p !== undefined).length < event.parts) return;
        pending.delete(event.id);
        try { whole = JSON.parse(list.join("")) as EditorWire; } catch { whole = undefined; }
      }
      if (!whole) return;
      for (const fn of [...listeners]) fn(whole);
    });
  }
  return () => { listeners.delete(handler); };
}

let queue = Promise.resolve();
/** One request at a time, to the client (captures) or the server (list, save, test...). */
export function request<T>(operation: string, payload: Record<string, unknown> = {}): Promise<T> {
  const task = queue.then(() => new Promise<T>((resolve, reject) => {
    const id = mutationKey();
    const stop = onEditor((reply) => {
      if (reply.kind !== "response" || reply.request !== id) return;
      window.clearTimeout(timer); stop();
      if (reply.ok) resolve(reply.data as T); else reject(new Error(reply.error || "The request was refused."));
    });
    const timer = window.setTimeout(() => { stop(); reject(new EditorTimeout("The server has not answered. Your draft is kept; check the list before retrying.")); }, 12000);
    emit(PAGE_EVENTS.parkourEditor, { ...payload, operation, request: id });
  }));
  queue = task.then(() => undefined, () => undefined).then(() => new Promise((resolve) => setTimeout(resolve, 200)));
  return task;
}
export const tell = (operation: string, payload: Record<string, unknown> = {}) => emit(PAGE_EVENTS.parkourEditor, { ...payload, operation });
