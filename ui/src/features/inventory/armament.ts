import { useEffect } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS, type ArmamentArgs, type ArmamentOperation, type ArmamentPending, type ArmamentState, type InventoryItem } from "@/bridge/protocol";
import { useStore } from "@/state/store";

interface ArmamentWire { kind: string; request?: string; ok?: boolean; error?: string; data?: { state?: ArmamentState }; state?: ArmamentState }
class ArmamentTimeout extends Error {}
let nextRequest = 0;
let queue = Promise.resolve();
let running = false;
const key = () => `arm:${Date.now().toString(36)}:${++nextRequest}:${Math.random().toString(36).slice(2, 9)}`;

/** Do not infer an instance from the slot or the weapon record. */
export const weaponInstance = (item?: InventoryItem): string | undefined => {
  const id = item?.metadata?.instanceId;
  return item?.category === "weapon" && typeof id === "string" && id.length > 0 && id.length <= 64 ? id : undefined;
};
export const armamentItem = (item?: InventoryItem) => item?.category === "weapon" || item?.category === "ammo";

function request(operation: ArmamentOperation, args: ArmamentArgs = {}, mutation?: string): Promise<{ state?: ArmamentState }> {
  const task = queue.then(() => new Promise<{ state?: ArmamentState }>((resolve, reject) => {
    const request = key();
    const stop = on<ArmamentWire>(PAGE_EVENTS.armament, event => {
      if (event.kind !== "response" || event.request !== request) return;
      clearTimeout(timer); stop();
      if (event.ok) resolve(event.data ?? {});
      else reject(new Error(event.error || "L'action sur l'armement a été refusée."));
    });
    const timer = window.setTimeout(() => { stop(); reject(new ArmamentTimeout("Aucune réponse. L'action peut être en cours ; vérifiez son résultat avant de recommencer.")); }, 14000);
    emit(PAGE_EVENTS.armament, { operation, request, ...args, ...(mutation ? { mutation } : {}) });
  }));
  queue = task.then(() => undefined, () => undefined).then(() => new Promise(resolve => setTimeout(resolve, 220)));
  return task;
}

export async function refreshArmament() {
  try {
    const result = await request("state");
    if (result.state) useStore.getState().setArmament(result.state);
  } catch (reason) {
    useStore.getState().setArmamentFeedback({ text: reason instanceof Error ? reason.message : "Armement indisponible.", error: true });
  }
}

async function execute(intent: ArmamentPending) {
  if (running) return;
  running = true;
  const store = useStore.getState();
  store.setArmamentPending({ ...intent, uncertain: false }); store.setArmamentFeedback(undefined);
  try {
    const result = await request(intent.operation, intent.args, intent.mutation);
    if (result.state) useStore.getState().setArmament(result.state);
    useStore.getState().setArmamentPending(undefined);
    useStore.getState().setArmamentFeedback({ text: "Demande traitée. L'équipement affiché suit l'état du serveur.", error: false });
  } catch (reason) {
    useStore.getState().setArmamentPending(reason instanceof ArmamentTimeout ? { ...intent, uncertain: true } : undefined);
    useStore.getState().setArmamentFeedback({ text: reason instanceof Error ? reason.message : "La demande a échoué.", error: true });
  } finally { running = false; }
}

export function performArmament(operation: Exclude<ArmamentOperation, "state">, args: ArmamentArgs = {}) {
  const store = useStore.getState();
  if (running || store.armamentPending || store.armament?.busy || operation !== "sync" && !store.armament
    || (operation === "equip" || operation === "holster") && !store.armament?.ready) return;
  void execute({ operation, args: { ...args, baseRevision: store.armament?.revision ?? 0 }, mutation: key(), uncertain: false });
}
export function retryArmament() {
  const pending = useStore.getState().armamentPending;
  if (pending?.uncertain) void execute(pending);
}

/** Always subscribed, even when the inventory is closed, to avoid stale cached equipment. */
export function useArmamentEvents() {
  useEffect(() => on<ArmamentWire>(PAGE_EVENTS.armament, event => {
    if (event.kind === "state" && event.state) useStore.getState().setArmament(event.state);
  }), []);
}
