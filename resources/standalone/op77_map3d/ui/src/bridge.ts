// The page side of the Open77 WebUI bridge (wiki/webui.md): Open77.on / Open77.emit.
// Outside the game (vite dev server) a small mock drives the page so the map can be
// developed and screenshotted in a browser.

type Handler = (payload: any) => void;
interface Open77Bridge {
  on(name: string, handler: Handler): () => void;
  emit(name: string, payload?: unknown): void;
}
declare global {
  interface Window { Open77?: Open77Bridge }
}

const local = new Map<string, Set<Handler>>();
export const inGame = typeof window.Open77?.on === "function";

export function on(name: string, handler: Handler): () => void {
  if (inGame) return window.Open77!.on(name, handler);
  let set = local.get(name);
  if (!set) local.set(name, (set = new Set()));
  set.add(handler);
  return () => set!.delete(handler);
}

export function emit(name: string, payload: unknown = {}): void {
  if (inGame) {
    try { window.Open77!.emit(name, payload); } catch { /* the page outlives a stopping resource */ }
    return;
  }
  mockEmit(name, payload);
}

/** Dev only: what Lua would send to the page. */
export function dispatchLocal(name: string, payload: unknown): void {
  for (const h of local.get(name) ?? []) h(payload);
}

let mockEmit: (name: string, payload: unknown) => void = () => {};
export function setMockEmit(fn: (name: string, payload: unknown) => void): void { mockEmit = fn; }
