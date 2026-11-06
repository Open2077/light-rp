import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import type { Wire } from "./model";

export const mutationKey = () => `mission:${Date.now().toString(36)}:${Math.random().toString(36).slice(2, 12)}`;
export class MissionRequestTimeout extends Error {}

/* What every editor's events have in common. */
export interface EditorEvent { kind: string; request?: string; ok?: boolean; data?: unknown; error?: string; id?: string; part?: number; parts?: number; text?: string }

/* One editor's page event. Every event, with large ones joined back: the client sends an event
   past 900 values as JSON text parts (client/core/mission_editor.lua sendParts), each part an
   event { kind: "parts", id, part, parts, text }. */
export function editorChannel<W extends EditorEvent>(name: string) {
  const pending = new Map<string, string[]>();
  const listeners = new Set<(event: W) => void>();
  let attached = false;
  function onEditor(handler: (event: W) => void): () => void {
    listeners.add(handler);
    if (!attached) {
      attached = true;
      on<W>(name, event => {
        let whole: W | undefined = event;
        if (event.kind === "parts" && typeof event.id === "string" && typeof event.part === "number" && typeof event.parts === "number") {
          const list = pending.get(event.id) ?? [];
          list[event.part - 1] = event.text ?? "";
          pending.set(event.id, list);
          if (list.filter(p => p !== undefined).length < event.parts) return;
          pending.delete(event.id);
          try { whole = JSON.parse(list.join("")) as W; } catch { whole = undefined; }
          if (!whole) return;
        }
        for (const fn of [...listeners]) fn(whole);
      });
    }
    return () => { listeners.delete(handler); };
  }
  let queue = Promise.resolve();
  /** One request at a time to the client (captures) or the server. */
  function request<T>(operation: string, payload: Record<string, unknown> = {}, onSent?: (request: string) => void): Promise<T> {
    const task = queue.then(() => new Promise<T>((resolve, reject) => {
      const request = mutationKey();
      onSent?.(request);
      const stop = onEditor(reply => {
        if (reply.kind !== "response" || reply.request !== request) return;
        clearTimeout(timer); stop();
        if (reply.ok) resolve(reply.data as T);
        else reject(new Error(reply.error || "The request was refused."));
      });
      const timer = window.setTimeout(() => { stop(); reject(new MissionRequestTimeout("The server has not answered. Your draft is kept; retry to check the saved result.")); }, 12000);
      emit(name, { ...payload, operation, request });
    }));
    queue = task.then(() => undefined, () => undefined).then(() => new Promise(resolve => setTimeout(resolve, 200)));
    return task;
  }
  return { onEditor, request };
}

export const { onEditor, request } = editorChannel<Wire>(PAGE_EVENTS.missionEditor);
