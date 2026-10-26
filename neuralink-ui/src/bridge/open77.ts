/* Typed wrapper over the WebUI host bridge the game injects as `window.Open77`
   (`on`, `emit`, `invoke`, `ready`, optional `off`). In a plain browser there is
   no bridge: main.tsx installs the mock (bridge/mock.ts) first. */
import type { InboundEvents, OutboundEvents, RequestArgs, RequestData, RequestOp, RequestResult, SoundName } from "./protocol";
import { normalizeInbound, normalizeReply } from "./normalize";

export interface Open77Bridge {
  on(name: string, handler: (payload: unknown) => void): void;
  off?(name: string, handler: (payload: unknown) => void): void;
  emit(name: string, payload?: unknown): void;
  invoke(name: string, payload?: unknown): Promise<unknown>;
  ready(): void;
}

declare global {
  interface Window { Open77?: Open77Bridge; __neuralinkMock?: boolean }
}

type Handler<T> = (payload: T) => void;
const listeners = new Map<string, Set<Handler<unknown>>>();

const bridge = (): Open77Bridge | undefined => window.Open77;

/** Subscribe to a Lua -> page event. One host listener per name fans out locally. */
export function on<K extends keyof InboundEvents>(name: K, handler: Handler<InboundEvents[K]>): () => void {
  let set = listeners.get(name);
  if (!set) {
    const created = new Set<Handler<unknown>>();
    listeners.set(name, created);
    set = created;
    bridge()?.on(name, (raw) => {
      const payload = normalizeInbound(name, raw);
      for (const fn of created) {
        try { fn(payload); } catch (err) { console.error(`[neuralink] handler ${name} failed`, err); }
      }
    });
  }
  set.add(handler as Handler<unknown>);
  return () => { set?.delete(handler as Handler<unknown>); };
}

export function emit<K extends keyof OutboundEvents>(name: K, payload: OutboundEvents[K]): void {
  try { bridge()?.emit(name, payload); } catch (err) { console.error(`[neuralink] emit ${name} failed`, err); }
}

export function emitSound(name: SoundName): void { emit("nl:sound", { name }); }

let readySent = false;
/** Tell the host the page is listening (`ui:ready`); Lua answers with `nl:state`. */
export function announceReady(): void {
  if (readySent) return;
  readySent = true;
  bridge()?.ready();
}

/** Error carrying the protocol slug (`unknown_number`, `busy`, ...). */
export class RequestError extends Error {
  constructor(public readonly slug: string) { super(slug); this.name = "RequestError"; }
}

/** A rejected `invoke` carries the Lua reply as its message, possibly JSON-encoded (`"busy"`, `{"error":...}`). */
function unwrapMessage(message: string): string {
  const text = message.trim();
  if (text.startsWith("\"") || text.startsWith("{")) {
    try {
      const parsed: unknown = JSON.parse(text);
      if (typeof parsed === "string") return parsed;
      if (parsed && typeof parsed === "object") return slugOf(parsed);
    } catch { /* not JSON: use as is */ }
  }
  return text;
}

function slugOf(err: unknown): string {
  if (err instanceof RequestError) return err.slug;
  if (err instanceof Error) return err.message ? unwrapMessage(err.message) : "unknown";
  if (typeof err === "string") return unwrapMessage(err);
  if (err && typeof err === "object") {
    const o = err as { reason?: unknown; error?: unknown; message?: unknown };
    for (const v of [o.reason, o.error, o.message]) if (typeof v === "string" && v) return v;
  }
  return "unknown";
}

/** `invoke("nl:request", { op, args })`. Resolves `data`, rejects `RequestError(slug)`. */
export async function request<O extends RequestOp>(op: O, args: RequestArgs<O>): Promise<RequestData<O>> {
  const b = bridge();
  if (!b?.invoke) throw new RequestError("unavailable");
  let res: unknown;
  try {
    res = await b.invoke("nl:request", { op, args });
  } catch (err) {
    throw new RequestError(slugOf(err));
  }
  const r = res as RequestResult<O> | undefined;
  if (r && typeof r === "object" && "ok" in r) {
    if (r.ok) return normalizeReply(r.data ?? {}) as RequestData<O>;
    throw new RequestError(r.reason ?? r.error ?? "unknown");
  }
  // A host that resolves the data directly: accept it as-is.
  return normalizeReply(res ?? {}) as RequestData<O>;
}

export function isMock(): boolean { return !!window.__neuralinkMock; }
