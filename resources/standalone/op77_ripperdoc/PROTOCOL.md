# op77_ripperdoc — page contract

The page (`web/`, built from `ripperdoc-ui`) talks to `client/main.lua` through the WebUI bridge.

## Lua → page

| Event | Payload | Meaning |
|---|---|---|
| `rd:open` | `OpenPayload` (below) | Show the interface: boot sequence, then the full body. |
| `rd:close` | `{}` | Hide it at once (the scene ended, the server closed it). |

```ts
interface OpenPayload {
  body?: "male" | "female";                       // which paperdoll (videos, overlays)
  clinic?: { name: string; doctor: string; tagline?: string };
  wallet?: number;                                // eurodollars shown and spent by the preview
  capacity?: { max: number };                     // cyberware capacity
  installed?: Record<string, string[]>;           // section id -> catalogue ids (src/data.ts)
  patient?: { name?: string; id?: string };
}
```

Every field is optional: a missing one falls back to the demo payload (`DEMO` in `src/data.ts`).
Section ids: `frontal_cortex`, `ocular`, `arms`, `skeleton`, `nervous`, `integumentary`,
`operating_system`, `face`, `hands`, `circulatory`, `immune`, `legs`.

## Page → Lua

| Event | Payload | Lua does |
|---|---|---|
| `ui:ready` | — | Replays a pending `rd:open`. |
| `rd:close` | `{}` | The patient left (Esc on the full body): focus back to the game, `op77_ripperdoc:closed` to the server. |
| `rd:sound` | `{ name }` | Plays `web/media/sfx/<name>.mp3` with Play2DSound (one handle per slot). |
| `rd:action` | `{ op: "install" \| "remove", section, item, replace }` | Preview only: logged. The installation system will validate and apply it. |

## Server exports

```lua
exports.op77_ripperdoc:open(playerId, payload)   -- true | nil, reason
exports.op77_ripperdoc:close(playerId)           -- true
exports.op77_ripperdoc:isOpen(playerId)          -- boolean
AddEventHandler("op77_ripperdoc:closed", function(playerId) end)  -- the patient closed it
```

Console (restricted): `ripperdoc.open <playerId> [male|female]`, `ripperdoc.close <playerId>`.
