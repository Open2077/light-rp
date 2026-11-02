/* Lua tables have one shape for lists and maps: an EMPTY list leaves Lua as a JSON
   object `{}`, and a sparse one as `{"1":..,"2":..}`. Every field the protocol
   declares as a list is coerced back to an array at the bridge, once, so no
   reducer ever calls `.map` on an object (an empty contact list used to throw in
   `applyState` and the whole snapshot was lost). `nl:talkers` stays a map. */

const LIST_KEYS = new Set([
  "contacts", "threads", "recents", "apps", "members", "participants", "messages", "numbers",
  // rich messages (MessageMeta)
  "actions",
  // Screamsheet
  "posts", "parents", "replies", "profiles", "pings", "tags", "districts", "hot",
]);

function asArray(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) return [];
    if (entries.every(([k]) => /^\d+$/.test(k))) {
      return entries.sort((a, b) => Number(a[0]) - Number(b[0])).map(([, v]) => v);
    }
  }
  return [];
}

function walk(value: unknown, depth: number): unknown {
  if (depth > 8 || value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map((v) => walk(v, depth + 1));
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    // only objects: `replies` is also a count on every scream
    out[k] = LIST_KEYS.has(k) && v !== null && typeof v === "object" ? asArray(v).map((x) => walk(x, depth + 1)) : walk(v, depth + 1);
  }
  return out;
}

/** A call the host can actually describe; anything else means "no call". */
function isCall(value: unknown): boolean {
  return !!value && typeof value === "object" && typeof (value as { id?: unknown }).id === "number";
}

/** Request replies have the same problem (an empty `parents` or `profiles` list). */
export function normalizeReply(data: unknown): unknown {
  return walk(data, 0);
}

export function normalizeInbound(name: string, payload: unknown): unknown {
  if (name === "nl:talkers") return payload;
  // The host cannot send nil: an ended call reaches the page as `{}`. Kept as
  // a call it had no participants and every render after it threw.
  if (name === "nl:call" && !isCall(payload)) return null;
  const out = walk(payload, 0);
  if (name === "nl:state" && out && typeof out === "object" && "call" in out && !isCall((out as { call?: unknown }).call)) {
    (out as { call?: unknown }).call = null;
  }
  return out;
}
