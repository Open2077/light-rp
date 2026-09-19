/* Typed wrapper over the WebUI host bridge the game injects as `window.Open77`
   (`on`, `emit`, `ready`, optional `off`). In a plain browser (vite dev) there is
   no bridge: dev/mock.ts installs one so the page can be developed and screenshot
   without the game. */
import { PAGE_EVENTS, type UiAction } from "./protocol";

export interface Open77Bridge {
  on(name: string, handler: (payload: unknown) => void): void;
  off?(name: string, handler: (payload: unknown) => void): void;
  emit(name: string, payload?: unknown): void;
  ready(): void;
}

declare global {
  interface Window { Open77?: Open77Bridge; __lightrpMock?: boolean }
}

type Handler<T> = (payload: T) => void;
const listeners = new Map<string, Set<Handler<unknown>>>();
let attached = false;

function bridge(): Open77Bridge | undefined {
  return window.Open77;
}

/** Subscribe to a Lua -> page event. Returns the unsubscribe. */
export function on<T = unknown>(name: string, handler: Handler<T>): () => void {
  let set = listeners.get(name);
  if (!set) {
    set = new Set();
    listeners.set(name, set);
    bridge()?.on(name, (payload) => { for (const fn of listeners.get(name) ?? []) fn(payload); });
  }
  set.add(handler as Handler<unknown>);
  return () => { set?.delete(handler as Handler<unknown>); };
}

export function emit(name: string, payload: unknown = {}): void {
  bridge()?.emit(name, payload);
}

export function sendAction(action: UiAction): void {
  emit(PAGE_EVENTS.action, action);
}

export function requestClose(): void {
  emit(PAGE_EVENTS.close, {});
}

/** Tell the host the page is painted and listening; the client answers with the state. */
export function announceReady(): void {
  if (attached) return;
  attached = true;
  bridge()?.ready();
  emit(PAGE_EVENTS.ready, {});
}

export function hasBridge(): boolean {
  return bridge() != null && !window.__lightrpMock;
}
