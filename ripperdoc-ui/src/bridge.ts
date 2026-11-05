/* The WebUI host bridge the game injects as `window.Open77` (`on`, `emit`, `ready`). In a plain
   browser (vite dev, screenshots) there is none: the page opens itself on the demo payload. */
import type { OpenPayload } from "./data";

interface Open77Bridge {
  on(name: string, handler: (payload: unknown) => void): void;
  emit(name: string, payload?: unknown): void;
  ready(): void;
}

declare global {
  interface Window { Open77?: Open77Bridge }
}

export const inGame = (): boolean => typeof window.Open77 !== "undefined";

/* One bridge listener per event, forwarding to the latest handler: the app remounts after a render
   error (main.tsx) and registers again, which must not stack a second listener. */
const current: Record<string, (raw: unknown) => void> = {};
function listen(name: string, handler: (raw: unknown) => void): void {
  if (!(name in current)) window.Open77?.on(name, (raw) => current[name]?.(raw));
  current[name] = handler;
}

export function onOpen(handler: (payload: OpenPayload) => void): void {
  listen("rd:open", (raw) => handler((raw ?? {}) as OpenPayload));
}

export function onClose(handler: () => void): void {
  listen("rd:close", () => handler());
}

export interface ActionResult { ok?: boolean; message?: string; op?: string; item?: string }

/** The server's answer to the page's last `rd:action`. */
export function onResult(handler: (result: ActionResult) => void): void {
  listen("rd:result", (raw) => handler((raw ?? {}) as ActionResult));
}

/** Fresh state after an operation (same shape as `rd:open`). */
export function onState(handler: (payload: OpenPayload) => void): void {
  listen("rd:state", (raw) => handler((raw ?? {}) as OpenPayload));
}

export function emit(name: "rd:close" | "rd:sound" | "rd:action" | "rd:guide", payload: unknown = {}): void {
  try { window.Open77?.emit(name, payload); } catch (err) { console.error("[ripperdoc] emit", name, err); }
}

export function ready(): void { window.Open77?.ready(); }

/** A line for the server log (client/main.lua relays rd:diag to op77_ripperdoc:diag). */
export function diag(text: string): void {
  try { window.Open77?.emit("rd:diag", { text: text.slice(0, 300) }); } catch { /* nothing to tell it with */ }
}
