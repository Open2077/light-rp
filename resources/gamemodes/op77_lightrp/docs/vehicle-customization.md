# Vehicle customization / Auto Studio

Paint landed from `feat/vehicle-customization` (`3fa7f22`); lights, trim and the
per-model support table come from `vc/a-lightrp-phase1` (campaign plan
`PLAN-vehicle-custom.md`, phase 1). The API mapping below was checked with the
Open77 Devkit MCP for **2.50.0+op77.156**, including the `vehicle-paint` and
`cameras` guides and each native card (`setHeadlightColor`, `setLightsHue`,
`clearLightsHue`, `getLightsHue`, `setAppearance`, `getAppearance`,
`getProperties`, `setProperties`).

## Player flow

Two world access points use **E**, in bucket 0:

- Auto Studio // Bay 01: `(-1034.573364, -1702.693726, 11.015274)`.
- Auto Studio // Bay 02: `(-1025.970703, -1709.572754, 11.015274)`.

Park your owned vehicle within 6 m of a point, step out, and approach its marker.
The server selects the nearest vehicle owned by the active character; the same
stationary/empty, proximity and persistence rules apply. The first bay carries
the shared Auto Studio map marker. Locations are in the shared customization config.

The garage shortcut is also available:

Retrieve an owned vehicle at a Public Garage, leave it stationary in the garage
area, step out and reopen the garage. Select the car and choose **Customize
vehicle**. All occupants must be out. Rentals, staff-spawned cars and other
characters' vehicles are not eligible.

Auto Studio uses the existing yellow/black design tokens and shared buttons.
The original full-height left panel groups the vehicle header, category rows,
paint controls and payment footer. Components use circular color swatches,
underlined channel/payment selectors, a single HEX field and a restrained outlined
apply button. The actual game vehicle remains visible to the right, with camera
controls at the bottom of the remaining viewport.
### Categories

The server sends the category rows for the vehicle being edited (see
[Per-model availability](#per-model-availability)). Each category keeps its own
draft; the car shows every current preview at once, and **Apply** pays for the
selected category only. Every valid change previews automatically: presets and
pickers immediately, HEX edits after a short typing delay. Rapid clicks coalesce
to the latest selection while a native request is pending. There is no Preview
button.

| Category | Editor | Natives (server) | Price |
| --- | --- | --- | --- |
| Body paint | Primary / Secondary, 12 presets, picker, HEX, **Factory finish** | `setPaint`, `resetPaint` | **2,500 €$** (owner, 2026-11-05) |
| Lights | 12 saturated presets, picker, HEX, **Factory lights** | `setHeadlightColor`, `clearLightsHue` (restore: `setLightsHue`) | **500 €$**, provisional |
| Trim | **Factory trim** + the variants curated for the model | `setAppearance` (`getAppearance` to skip restatements) | **2,500 €$**, provisional |

- **Body paint.** Pure black is a real color, distinct from **Factory finish**.
  Both channels are one job. Resetting a custom finish to factory paint is a paint job.
- **Lights.** The engine stores **one hue** (0..1) for the car's own lights, in the
  same visual template as the paint (`paint.lightsHue`): `#800000` and `#FF0000`
  light the car identically, and a grey has no hue (the native would read it as
  red). The page flags and never previews a colour under 25 % HSV saturation
  (`lightsMinSaturation` in `shared/vehicle_customization.lua`); the server refuses
  it too. Equality is the hue the engine actually stored (read back with
  `getLightsHue`), so the same hue at another brightness is refused as unchanged.
  **Factory lights** clears the tint (record colour) and is a lights job.
- **Trim.** An entity appearance variant from the model's curated list in
  `shared/vehicle_customization.lua` `trims[catalogKey]`. The server accepts only
  an id listed for **that vehicle's** catalogue key and applies the name from the
  table, never a client string. **Factory trim** goes back to the record's own
  variant (`setAppearance(id, nil)`) and is a trim job. A model without entries
  does not show the category. The list ships **empty**: the lead fills it after the
  in-game measurements (plan E0.1); the commented example shows the shape.

Previews are free. Purchases are paid from Cash or Bank at the server quote of the
category. The server-only `server/config/vehicle_customization.lua` owns the
tariffs; **lights and trim are marked `-- PROVISIONAL: owner to confirm`**. The page
displays the quote and available balances; insufficient funds and an unchanged
selection disable purchase. No payment is sent automatically or retried on a timeout.

The camera automatically orbits the stationary car. Pause/resume, step left or
right and zoom are local presentation controls. Camera radius is limited to
4–10 m; default radius 6.5 m, height 2.1 m, 55-degree FOV and 10 degrees/second.
These values live in `shared/vehicle_customization.lua`.

Escape, Close, death, removal, movement, character changes, leaving the garage/workshop,
a five-minute expiry or disconnect release the session and restore the most
recently saved look of **every** category (paint, lights hue, trim). Saving before
closing keeps what was bought; previews of other categories are dropped. A save already
committing when the client leaves is allowed to finish for the original owned
vehicle. Its server response is not routed to a replacement session.

## Persistence and failure behavior

There is no second vehicle database and no new schema. The garage owns the
lease, current network ID, durable ownership UUID and the last confirmed look.
Every purchase passes the canonical `getProperties` snapshot to
`LightRP.money.exchange`: wallet/inventory cash debit, the existing
`lightrp_owned_vehicles.properties` UPDATE and the ledger receipt (`vehicle_paint`,
`vehicle_lights` or `vehicle_trim`) commit in **one SQL transaction** before success
is acknowledged. Client prices are ignored. Duplicate request replay and a
confirmed-value equality check per category prevent double charges. A failed
transaction leaves both the original money and the confirmed look.
The garage service accepts only trusted payment tables; public RPC payment methods
are restricted to cash/bank and the session's server-issued quote. Retrieval
already creates the car with the saved `appearance` and calls `setProperties` on
it, including confirmed paint, lights hue, damage and health. Network IDs are never
persisted.

### The confirmed-property mask

The lease (`row.edit` in `server/modules/garages.lua`) keeps two looks: `saved`,
what the SQL row holds, and `shown`, what the car wears. The `OWNS` table maps each
category to the `getProperties()` fields it owns:

| Category | Fields |
| --- | --- |
| `paint` | `paint.applied`, `paint.primary`, `paint.secondary` |
| `lights` | `paint.lightsHue` |
| `trim` | `appearance` |

Authoritative previews are visible to other viewers. While a lease is open, every
property capture (periodic autosave, removal recovery, close, disconnect) replaces
**all** owned fields with the confirmed ones, and a purchase replaces all of them
**except the category being bought**: buying paint while a lights preview is on
screen persists the new paint and the confirmed tint. Thus an autosave, reconnect,
hard crash or another category's purchase cannot make a preview durable. Close
restores the whole confirmed look; the appearance is only rewritten when it
differs, so closing after a paint or lights preview never reschedules the trim.
A failed preview or purchase returns only its own category to the confirmed value
(other previews stay). If native restoration fails, the lease stays locked and the
garage worker retries rather than saving the preview. DB errors or insufficient
funds restore the confirmed value and never acknowledge a successful purchase.
Damage is captured independently; customization never repairs the vehicle.

### Per-model availability

`shared/vehicle_customization.lua` carries two tables keyed by the Light RP
catalogue key (`LightRpConfig.vehicles.catalog`, e.g. `hella`, `kusanagi`). Both
ship **empty**; the lead fills them from in-game measurements.

- `support = { [catalogKey] = { paint = true|false, lights = true|false } }`.
  A model or category absent from the table is **allowed** (no regression).
  `false` sends the row greyed with `unsupported[category]` as its short reason,
  and the server refuses any request for it. To be replaced by the platform's
  per-record flags in phase 2.
- `trims = { [catalogKey] = { { id = "appearance_name", label = "..." }, ... } }`.
  No entry (or an empty list) hides the Trim row. A row whose model left the
  catalogue still opens with paint and lights.

All mutations validate the source player, current active character, life state,
bucket, garage proximity, ownership, stationary/empty vehicle and session token.
Each session accepts ordered requests and replays only the previous response;
client-supplied native names, model changes, unknown categories, categories not
offered or not supported for the model, and trim ids outside the model's list are
refused. Preview traffic is limited to one accepted new preview per 200 ms, all
categories together; the UI
spaces queued previews by 230 ms. Payment requests remain serialized and are not
blocked just because an immediately preceding preview completed quickly. Garage
operations and character switching wait for the active customization lease.

The camera refuses an already-held view, freezes only this resource's local
player claim, and destroys its own camera on refusal, interruption or stop.
It does not teleport the vehicle/player or change routing buckets. Scripted
cameras have no native collision avoidance: use open pickup bays and survey
configured garage locations in-game.

## Clean presentation

The existing freecam uses the same `Open77.camera` definition/view/cleanup API.
Auto Studio additionally uses the documented `Open77.hud.setCinematic(true, 0.01)`
claim (`ui.vanilla.hud`, available since op77.78): native HUD/minimap, nonfocused
resource interfaces (voice, chat history, watermark) and world labels are masked.
The minimum 1% bars preserve the original full-height menu framing. The focused
workshop WebUI remains usable. Releasing with `setCinematic(false)` preserves
ordinary HUD hide claims and claims belonging to other resources.

Because the workshop and the RP HUD share one WebUI, a session-correlated
`customizationActive` store flag separately hides the gameplay-interface wrapper
(HUD, notices, prompts and other page overlays), without unmounting those features
or losing their state. It starts when the camera prepares and ends on close,
refusal, death, movement, removal or resource stop. Stale close events cannot
unhide the HUD beneath a newer workshop session. Payment feedback stays visible
inside the workshop.

## Native capability map

All mutation APIs below are **server-side**. Runtime paint replication covers
current viewers, late joins and streaming back in. RGB appearance on screen
still depends on the selected record having a compatible native paint component;
the API does not provide a reliable per-record compatibility flag.

| Category | Native APIs | Properties / constraints | Status |
| --- | --- | --- | --- |
| Body paint | `Open77.vehicles.setPaint`, `resetPaint`, `getPaint` | Primary/secondary RGB, separate applied flag; `world.vehicles` | Implemented |
| Durable restoration | `Open77.vehicles.getProperties`, `setProperties` | Complete version-1 canonical properties; no positions/network IDs | Implemented through garage |
| Light tint | `setHeadlightColor`, `clearLightsHue`, `setLightsHue`, `getLightsHue` | One hue in 0..1, not RGB brightness or underglow; `paint.lightsHue` | Implemented (Lights) |
| Authored appearance | `getAppearance`, `setAppearance` | Named per-model variants; `world.vehicles.appearance` for a change (a restatement needs none); the server does not validate names and the catalogue does not enumerate them, hence the curated `trims` list | Implemented (Trim), list empty until measured |
| Performance ceilings | `getPerformance`, `setPerformance`, `clearPerformance` | `topSpeedKph` 0..1000; `accelerationScale` >0 and <=1; `taperKph` 3..200; caps, not engine upgrades | Mapped, not exposed |
| Repairs | `repair`, `repairBodyCell`, `repairGlass`, `repairLight`, `repairTire` | Existing damage scopes; separate gameplay/economy decision | Mapped, not exposed |
| Unsupported engine features | `Open77.vehicles.unsupportedProperties` (table) | No wheel/rim slots, numbered mod kits, window tint, neon, xenon palette, plate text, turbo/brake/suspension upgrades or indexed liveries | No native counterpart |

Client camera APIs: `Open77.camera.create`, `activate`, `setTransform`,
`cameras`, `destroy` (`camera.script`). Vehicle observation uses
`Open77.vehicles.get` (`vehicles.read`). Local freeze uses
`Open77.character.setFrozen` (`player.freeze`). The client only relays page
requests; every vehicle write is server-side. The trim category added
`world.vehicles.appearance` to the `op77_lightrp` manifest (with a comment); all
other natives were already covered by `world.vehicles`.

## Adding a category

1. Register its ID/label/description in `shared/vehicle_customization.lua`, and
   its price in `server/config/vehicle_customization.lua` (the module refuses to
   load without a valid price for every registered category).
2. Add a strict validator in `server/modules/vehicle_customization.lua`
   (`validators`), returning a trusted change `{ category = id, ... }`; extend
   `offer` if availability depends on the model. Never dispatch a native named by
   the client.
3. In `server/modules/garages.lua`: add the fields it owns to `OWNS` (the
   confirmed-property mask), its apply step to `applyChange`, its restore to
   `applyLook`, its unchanged check to `Garage.customize` and its ledger kind
   (VARCHAR 24) to `RECEIPTS`.
4. Add its editor in `ui/src/features/customization/VehicleCustomization.tsx`
   (`KNOWN`, `keyOf`, `validOf`, `payload`, `draftsOf`, `TEXT`, `ICONS`) and send
   its confirmed value in `Garage.customizationState`. Unknown editor IDs remain
   disabled; no speculative categories appear to players.
5. Reuse the single owned-vehicle lock and SQL properties row. Add checks for
   preview autosave isolation, close/disconnect rollback, a purchase of another
   category during its preview, removal or disconnect during SQL and retrieval
   after restart (`tests/vehicle_customization_categories_test.lua` is the model).

## Verification

- `python3 tools/test-vehicle-customization.py` (needs `lupa`; without a global
  install: `uv run --no-project --with lupa python tools/test-vehicle-customization.py`):
  real garage, inventory, customization RPC and camera scripts against
  deterministic SQL/native boundaries.
  Covers ownership and character isolation, black-vs-stock paint, preview autosave
  exclusion, cancellation, failed writes, delayed close, removal during SQL,
  parking/retrieval, restart, RPC replay/validation, orbit/pause/zoom and cleanup.
  The payment suite loads the real economy and inventory modules to check atomic
  cash/bank purchase, server pricing, unchanged-paint protection, insufficient funds,
  transaction failure, duplicate requests and disconnect while SQL is pending.
  `tests/vehicle_customization_categories_test.lua` covers lights (free preview on
  the replicated car, autosave/close never persist it, paid save, replay, same-hue
  and grey refusal, SQL/native failure, factory lights, disconnect during commit),
  trim (allowlist: another model's id, unknown id, raw record name or table never
  reach `setAppearance`; paid save; one appearance change to restore, none when
  unchanged), mixed sessions (lights preview + paint purchase, trim preview +
  lights purchase), park + restart + retrieve, `support = false` and models
  without entries or outside the catalogue. The client test checks that lights and
  trim requests are relayed unchanged without any client vehicle native.
- `npm run build --prefix ui`.
- `PLAYWRIGHT_MODULE=/path/to/playwright CHROMIUM_PATH=/path/to/chrome node ui/tests/customization.browser.cjs`:
  automatic/coalesced palette and HEX previews, quoted bank purchase, balance updates,
  unchanged-paint/insufficient-cash guards, stale acknowledgement/error feedback, camera requests,
  Escape and 1920x1080, 1280x720, 800x600 layouts; lights presets, grey refusal,
  per-category drafts and purchase, factory lights, trim options and factory trim,
  a greyed unsupported category with its reason, three-category layouts; screenshots
  in ignored `ui/artifacts/vehicle-customization-*.png`. Without `PLAYWRIGHT_MODULE`
  and `CHROMIUM_PATH` it needs `playwright` resolvable and Edge (`channel: msedge`).
- MCP validation has the same pre-existing 47 errors and one warning as the base
  project (stale catalogue coverage and existing modules); no errors reference
  the added customization scripts or their permissions.

Still requires a real game-client pass for model-specific paint coverage and
camera clearance around the configured public garage, plus a second viewer to
observe the preview and confirmed repaint across streaming. For lights and trim
(two clients, plan phase 1 "done when"):

1. Client A previews a light tint, then a trim: client B sees each on the same car.
2. Client A closes (Escape): both clients see the confirmed tint and trim again.
3. Client A buys a tint and a trim; B sees them; the wallet and ledger show
   `vehicle_lights` / `vehicle_trim` at the quoted price.
4. Park, restart the server, retrieve: same tint and trim on both clients (also after
   B streams the car out and back in, beyond 35 m).
5. Preview a tint, buy paint, close: the paint stays, the tint returns to confirmed.
6. Read the server log for `setAppearance` refusals (`permission_denied:world.vehicles.appearance`
   means the manifest change did not reach the server).

Fill `trims` and `support` from these measurements (which appearance names each
catalogue model really defines, which models render paint and lights).
