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

/* Large messages (client/main.lua sendLarge) travel as JSON text: { __json } in one message or
   { __part: { id, i, n, text } } in several. public/bridge-parts.js used to unwrap them by patching
   Open77.on, which a frozen bridge refuses (2026-11-05): the app decodes them here. A payload the
   shim already decoded comes through unchanged. */
const partsPending: Record<string, { id: unknown; parts: string[]; got: number }> = {};
function decode(name: string, raw: unknown): { ready: boolean; value?: unknown } {
  if (!raw || typeof raw !== "object") return { ready: true, value: raw };
  const r = raw as { __json?: unknown; __part?: { id?: unknown; i?: unknown; n?: unknown; text?: unknown } };
  if (typeof r.__json === "string") return { ready: true, value: JSON.parse(r.__json) };
  const part = r.__part;
  if (!part || typeof part.text !== "string") return { ready: true, value: raw };
  const n = Number(part.n), i = Number(part.i);
  if (!(n >= 1 && n <= 512 && i >= 1 && i <= n)) return { ready: false };
  let entry = partsPending[name];
  if (!entry || entry.id !== part.id) { entry = { id: part.id, parts: new Array(n), got: 0 }; partsPending[name] = entry; }
  if (entry.parts[i - 1] === undefined) { entry.parts[i - 1] = part.text; entry.got += 1; }
  if (entry.got < n) return { ready: false };
  delete partsPending[name];
  return { ready: true, value: JSON.parse(entry.parts.join("")) };
}

/* One bridge listener per event, forwarding to the latest handler: the app remounts after a render
   error (main.tsx) and registers again, which must not stack a second listener. */
const current: Record<string, (raw: unknown) => void> = {};
function listen(name: string, handler: (raw: unknown) => void): void {
  if (!(name in current)) window.Open77?.on(name, (raw) => {
    let out: { ready: boolean; value?: unknown };
    try { out = decode(name, raw); } catch (err) { diag(`${name} did not decode: ${String(err)}`); return; }
    if (!out.ready) return;
    if (name === "rd:open") {
      const v = out.value as { catalogue?: unknown } | undefined;
      diag(`rd:open received: ${v && typeof v === "object" ? `${Object.keys(v).length} keys, catalogue ${Array.isArray(v.catalogue) ? v.catalogue.length : v.catalogue ? "object" : "none"}` : typeof v}`);
    }
    current[name]?.(out.value);
  });
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
