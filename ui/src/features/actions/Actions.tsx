import { useEffect } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { matchesToggleKey } from "@/features/inventory/model";

/* The action bar's input relay. The bar itself (progress / hold / timing) is drawn on
   NativeUI by client/native/actions.lua, which also runs the clock and decides the outcome.
   The page stays the input sink: client/core/actions.lua gives it the keyboard
   (LightRpUi.claimActionFocus) while an action runs. This component renders nothing: it
   acknowledges the start (actionStarted, the proof client/core/actions.lua waits for) and
   forwards the raw key events of the running action, nothing else:
     { id, kind: "ready" }                 listening: the native clock starts
     { id, kind: "down" | "up", key }      one of the action's keys (no repeats)
     { id, kind: "escape" }                Escape (no repeats)
     { id, kind: "blur" }                  the page lost the focus */

interface ActionStart { id: string; kind: "progress" | "hold" | "timing"; key: string; steps?: { key: string }[] }
interface ActionEnd { id: string }
export interface ActionInput { id: string; kind: "ready" | "down" | "up" | "escape" | "blur"; key?: string }

/** The keys an action listens to: its own and every timing step's. */
export function actionKeys(d: ActionStart): string[] {
  const keys = new Set<string>();
  if (d.kind !== "progress" && typeof d.key === "string") keys.add(d.key);
  if (d.kind === "timing" && Array.isArray(d.steps)) for (const s of d.steps) if (typeof s?.key === "string") keys.add(s.key);
  return [...keys];
}

export function Actions() {
  useEffect(() => {
    let active: ActionStart | null = null;
    let keys: string[] = [];
    const send = (p: Omit<ActionInput, "id">) => { if (active) emit(PAGE_EVENTS.actionInput, { id: active.id, ...p }); };
    const offStart = on<ActionStart>(PAGE_EVENTS.actionStart, (d) => {
      if (!d?.id || !["progress", "hold", "timing"].includes(d.kind)) return;
      active = d; keys = actionKeys(d);
      useStore.getState().setActivityActive(true);
      emit(PAGE_EVENTS.actionStarted, { id: d.id });
      send({ kind: "ready" });
    });
    const offFinish = on<ActionEnd>(PAGE_EVENTS.actionFinish, (r) => {
      if (!active || r?.id !== active.id) return;
      active = null; keys = [];
      useStore.getState().setActivityActive(false);
    });
    const down = (e: KeyboardEvent) => {
      if (!active) return;
      if (e.key === "Escape" || e.code === "Escape") {
        e.preventDefault(); e.stopPropagation();
        if (!e.repeat) send({ kind: "escape" });
        return;
      }
      const key = keys.find((k) => matchesToggleKey(e, k));
      if (!key) return;
      e.preventDefault(); e.stopPropagation();
      if (!e.repeat) send({ kind: "down", key });
    };
    const up = (e: KeyboardEvent) => {
      if (!active) return;
      const key = keys.find((k) => matchesToggleKey(e, k));
      if (!key) return;
      e.preventDefault(); e.stopPropagation();
      send({ kind: "up", key });
    };
    const blur = () => send({ kind: "blur" });
    const visibility = () => { if (document.hidden) blur(); };
    window.addEventListener("keydown", down); window.addEventListener("keyup", up); window.addEventListener("blur", blur);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      offStart(); offFinish();
      window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); window.removeEventListener("blur", blur);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);
  return null;
}
