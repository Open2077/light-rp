import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import type { Wire } from "./model";

export const mutationKey = () => `zone:${Date.now().toString(36)}:${Math.random().toString(36).slice(2, 12)}`;
export class ZoneRequestTimeout extends Error {}
let queue = Promise.resolve();
export function request<T>(operation: string, payload: Record<string, unknown> = {}): Promise<T> {
  const task = queue.then(() => new Promise<T>((resolve, reject) => {
    const request = mutationKey();
    const stop = on<Wire>(PAGE_EVENTS.safezones, reply => {
      if (reply.kind !== "response" || reply.request !== request) return;
      clearTimeout(timer); stop();
      if (reply.ok) resolve(reply.data as T);
      else reject(new Error(reply.error || "La demande a été refusée."));
    });
    const timer = window.setTimeout(() => { stop(); reject(new ZoneRequestTimeout("Le serveur ne répond pas. Votre brouillon est conservé ; réessayez pour vérifier l'enregistrement.")); }, 12000);
    emit(PAGE_EVENTS.safezones, { ...payload, operation, request });
  }));
  queue = task.then(() => undefined, () => undefined).then(() => new Promise(resolve => setTimeout(resolve, 220)));
  return task;
}
