# op77_ripperdoc — page contract

The page (`web/`, built from `ripperdoc-ui`) talks to `client/main.lua` through the WebUI bridge.
On LightRP the clinic's owner is `op77_lightrp` (server/modules/ripperdoc.lua + cyberware.lua).

## Lua → page

| Event | Payload | Meaning |
|---|---|---|
| `rd:open` | `OpenPayload` (below) | Show the interface: boot sequence, then the full body. |
| `rd:state` | `OpenPayload` | Fresh state after an operation (installed, bank). |
| `rd:result` | `{ ok, message, op, item }` | The answer to the page's last `rd:action`. |
| `rd:close` | `{}` | Hide it at once (the scene ended, the server closed it). |

```ts
interface OpenPayload {
  live?: boolean;                                  // true: the server runs every operation
  catalogue?: Cyberware[];                         // the clinic's stock (server-owned prices)
  installed?: Record<string, string[]>;           // section id -> catalogue ids
  wallet?: number;                                 // bank balance (the only currency)
  removalFee?: number;
  body?: "male" | "female";
  clinic?: { name: string; doctor: string; tagline?: string };
  patient?: { name?: string; id?: string };
}
interface Cyberware {
  id: string; name: string; section: string; icon: string; rarity: string; tier: number;
  price: number; family?: string;                  // a family is one native slot: same family = replace
  maker: string; effect: string; lore: string; stats: { label: string; value: string }[];
}
```

Without `live` (console `ripperdoc.open`, browser preview) the page runs its demo catalogue and
simulates the operations itself. Section ids: `frontal_cortex`, `ocular`, `arms`, `skeleton`,
`nervous`, `integumentary`, `operating_system`, `face`, `hands`, `circulatory`, `immune`, `legs`.

## Page → Lua

| Event | Payload | Lua does |
|---|---|---|
| `ui:ready` | — | Replays a pending `rd:open`. |
| `rd:close` | `{}` | The patient left (Esc on the full body): focus back to the game, `op77_ripperdoc:closed` to the server. |
| `rd:sound` | `{ name }` | Plays `web/media/sfx/<name>.mp3` with Play2DSound (one handle per slot). |
| `rd:action` | `{ op: "install" \| "remove", item }` | Relayed to the server (`op77_ripperdoc:action`), answered by `rd:result` then `rd:state`. |

## Server

```lua
exports.op77_ripperdoc:open(playerId, payload)    -- true | nil, reason
exports.op77_ripperdoc:update(playerId, payload)  -- fresh state for an open interface
exports.op77_ripperdoc:result(playerId, result)   -- answer one page action
exports.op77_ripperdoc:close(playerId)
exports.op77_ripperdoc:isOpen(playerId)
AddEventHandler("op77_ripperdoc:action", function(playerId, { op, item, replace }) end) -- the page asked
AddEventHandler("op77_ripperdoc:closed", function(playerId) end)                        -- the patient left
```

Console (restricted): `ripperdoc.open <playerId> [male|female]`, `ripperdoc.close <playerId>`,
`ripperdoc.action <playerId> <install|remove> <item>` (the page's request, for support).
