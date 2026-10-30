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

export function onOpen(handler: (payload: OpenPayload) => void): void {
  window.Open77?.on("rd:open", (raw) => handler((raw ?? {}) as OpenPayload));
}

export function onClose(handler: () => void): void {
  window.Open77?.on("rd:close", () => handler());
}

export function emit(name: "rd:close" | "rd:sound" | "rd:action", payload: unknown = {}): void {
  try { window.Open77?.emit(name, payload); } catch (err) { console.error("[ripperdoc] emit", name, err); }
}

export function ready(): void { window.Open77?.ready(); }
