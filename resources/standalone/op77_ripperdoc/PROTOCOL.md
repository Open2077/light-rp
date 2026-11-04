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
  stock?: string[];                                // the patient's implant storage: owned, not fitted
  wallet?: number;                                 // bank balance (the only currency)
  fittingFee?: number;                             // one surgery without a purchase (fit from storage, take out)
  removalFee?: number;                             // = fittingFee (older pages)
  capacity?: { used: number; total: number; over?: boolean }; // points fitted / the body's capacity
  body?: "male" | "female";
  clinic?: { name: string; doctor: string; tagline?: string };
  patient?: { name?: string; id?: string };
  reputation?: { tier: number; name?: string; points?: number; next?: number; nextName?: string };
  guide?: Guide;                                   // the clinic guide (below); absent: no guide
}                                                  // street cred: the patient's reputation tier
interface Guide {                                  // what the walkthrough explains, from the live config
  auto?: boolean;                                  // never finished or skipped: open it after the boot
  tiers: { tier: number; name: string; points: number; capacity?: number; rank: number }[]; // street cred ladder
  gains?: { label: string; points: number; tier: number; tierName?: string }[]; // per mission difficulty
  pvpGivesNone?: boolean;
  drops?: string[];                                // where iconic implants drop
  fittingFee?: number; payFrom?: "bank" | "cash";
  keys?: { label: string; key?: string }[];       // the active implants' default keys
}
interface Cyberware {
  id: string; name: string; section: string; icon: string; rarity: string; // rarity "iconic" too
  tier: number;                                    // rank 1..6, 6 shown as V+
  price: number; family?: string;                  // a family is one native slot: same family = replace
  maker: string; effect: string; lore: string; stats: { label: string; value: string }[];
  capacity?: number;                               // the points it takes
  repTier?: number; repName?: string;              // the reputation tier the rank needs
  locked?: boolean;                                // below it: the server refuses the install
  stored?: boolean;                                // in the patient's storage (also listed in `stock`)
  iconic?: boolean; dropOnly?: boolean;            // iconic: never sold; dropOnly = not owned (no button)
  source?: string;                                 // what drops an iconic ("Chimera raid (Critical)")
}
```

Capacity and storage (Light RP, 2026-11-03): an install that would pass `capacity.total` is
refused by the server; the page shows `used / total` and says it before the hold. `over` (a body
fitted before the capacity existed): nothing heavier fits until under it. An implant in `stock`
is fitted for `fittingFee`, not its price; taking one out costs `fittingFee` and puts it in
storage; a family mate replaced goes to storage for free. A `dropOnly` iconic has no button: it
drops (`source`), it is never sold.

Transport: `open` / `update` payloads past 900 values (counted with every key) or 40 KiB go as
latent events under the same name (the client host drops a plain event over 1024 JSON values
without a word). A newer payload replaces a stream to the same player still in flight.

Street cred (optional fields, Light RP `docs/pve-progression.md`): a `locked` implant shows its
reputation tier (`REP III` badge, a "Street cred" line in the needs, `LOCKED · REP III` on the
button) and cannot be installed; the server refuses it anyway. An installed implant is never
`locked`. Without `reputation` the page shows no gate. In the preview the demo catalogue's
locks come from the rank (I-II open, then one tier per rank).

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
| `rd:guide` | `{ seen: true }` | The guide was finished or skipped: relayed to the server (`op77_ripperdoc:guide`), which remembers it per character. |

## Server

```lua
exports.op77_ripperdoc:open(playerId, payload)    -- true | nil, reason
exports.op77_ripperdoc:update(playerId, payload)  -- fresh state for an open interface
exports.op77_ripperdoc:result(playerId, result)   -- answer one page action
exports.op77_ripperdoc:close(playerId)
exports.op77_ripperdoc:isOpen(playerId)
AddEventHandler("op77_ripperdoc:action", function(playerId, { op, item, replace }) end) -- the page asked
AddEventHandler("op77_ripperdoc:closed", function(playerId) end)                        -- the patient left
AddEventHandler("op77_ripperdoc:guide", function(playerId, { seen }) end)              -- guide finished / skipped
```

Console (restricted): `ripperdoc.open <playerId> [male|female]`, `ripperdoc.close <playerId>`,
`ripperdoc.action <playerId> <install|remove> <item>` (the page's request, for support).

## The guide

The page walks the patient through the clinic: the body systems and the controls, capacity, street
cred (its ladder: points, capacity and the highest implant rank of each tier), how street cred is
earned (per mission difficulty, PvE only), buying / storage / swaps, and the active implants' keys.
It opens by itself after the boot when `guide.auto` is true; the GUIDE button (top bar) or H opens it
again at any time. Finishing or skipping it sends `rd:guide { seen: true }` (only when it opened by
itself). Every number comes from `guide`; without `guide` the button is hidden.
