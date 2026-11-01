import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import type { Wire } from "./model";

export const mutationKey = () => `mission:${Date.now().toString(36)}:${Math.random().toString(36).slice(2, 12)}`;
export class MissionRequestTimeout extends Error {}
let queue = Promise.resolve();
/** One request at a time to the client (captures) or the server (list, save, delete, test). */
export function request<T>(operation: string, payload: Record<string, unknown> = {}): Promise<T> {
  const task = queue.then(() => new Promise<T>((resolve, reject) => {
    const request = mutationKey();
    const stop = on<Wire>(PAGE_EVENTS.missionEditor, reply => {
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
