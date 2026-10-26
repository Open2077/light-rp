# Vehicle customization / Auto Studio

Based on `origin/main` at `3fa7f22`; branch `feat/vehicle-customization`.
The API mapping below was checked with the Open77 Devkit MCP for
**2.50.0+op77.156**, including the `vehicle-paint` and `cameras` guides and each
native card. This branch does not depend on the pending equipment/medical or
safezone PRs.

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
Body paint is the only exposed category. Select Primary or Secondary, choose a
preset or enter `#RRGGBB`; every valid change previews automatically. Pure black is a real color, distinct
from **Factory finish**. Presets and the color picker preview immediately; HEX edits preview after a
short typing delay. Rapid clicks coalesce to the latest selection while a native
request is pending. There is no Preview button.

Previews are free. **Apply paint** purchases the selected finish for **1,000 €$**
(flat price including both channels), paid from Cash or Bank. The server-only
`server/config/vehicle_customization.lua` owns this tariff. The page displays the
quote and available balances; insufficient funds and unchanged paint disable
purchase. No payment is sent automatically or retried on a timeout. Resetting an
existing custom finish to factory paint is also a paint job at this tariff.

The camera automatically orbits the stationary car. Pause/resume, step left or
right and zoom are local presentation controls. Camera radius is limited to
4–10 m; default radius 6.5 m, height 2.1 m, 55-degree FOV and 10 degrees/second.
These values live in `shared/vehicle_customization.lua`.

Escape, Close, death, removal, movement, character changes, leaving the garage/workshop,
a five-minute expiry or disconnect release the session and restore the most
recently saved finish. Saving before closing keeps that finish. A save already
committing when the client leaves is allowed to finish for the original owned
vehicle. Its server response is not routed to a replacement session.

## Persistence and failure behavior

There is no second vehicle database and no new schema. The garage owns the
lease, current network ID, durable ownership UUID and last confirmed paint.
Every purchase passes the canonical `getProperties` snapshot to
`LightRP.money.exchange`: wallet/inventory cash debit, the existing
`lightrp_owned_vehicles.properties` UPDATE and the `vehicle_paint` ledger receipt
commit in **one SQL transaction** before success is acknowledged. Client prices
are ignored. Duplicate request replay and a confirmed-paint equality check prevent
double charges. A failed transaction leaves both the original money and finish.
The garage service accepts only trusted payment tables; public RPC payment methods
are restricted to cash/bank and the session's server-issued quote. Retrieval
already calls `setProperties` on the newly spawned car, including confirmed
paint, damage, health and existing lights hue. Network IDs are never persisted.

Authoritative previews are visible to other viewers. Garage capture/periodic
saves replace preview paint with the lease's last confirmed paint. Thus an
autosave, reconnect or hard crash cannot accidentally make a preview durable.
Close restores confirmed paint. If native restoration fails, the lease stays
locked and the garage worker retries rather than saving the preview. DB errors or insufficient funds
restore the confirmed finish and never acknowledge a successful purchase.
Damage is captured independently; repainting never repairs the vehicle.

All mutations validate the source player, current active character, life state,
bucket, garage proximity, ownership, stationary/empty vehicle and session token.
Each session accepts ordered requests and replays only the previous response;
client-supplied native names, model changes or unknown categories are refused.
Preview traffic is limited to one accepted new preview per 200 ms; the UI
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
| Light tint | `setLightsHue`, `setHeadlightColor`, `clearLightsHue` | One hue in 0..1, not RGB brightness or underglow; `paint.lightsHue` | Mapped, existing hue preserved |
| Authored appearance | `getAppearance`, `setAppearance` | Named per-model variants; additional `world.vehicles.appearance` permission for changes; variants not enumerated by catalogue | Mapped, not exposed or newly permitted |
| Performance ceilings | `getPerformance`, `setPerformance`, `clearPerformance` | `topSpeedKph` 0..1000; `accelerationScale` >0 and <=1; `taperKph` 3..200; caps, not engine upgrades | Mapped, not exposed |
| Repairs | `repair`, `repairBodyCell`, `repairGlass`, `repairLight`, `repairTire` | Existing damage scopes; separate gameplay/economy decision | Mapped, not exposed |
| Unsupported engine features | `Open77.vehicles.unsupportedProperties` (table) | No wheel/rim slots, numbered mod kits, window tint, neon, xenon palette, plate text, turbo/brake/suspension upgrades or indexed liveries | No native counterpart |

Client camera APIs: `Open77.camera.create`, `activate`, `setTransform`,
`cameras`, `destroy` (`camera.script`). Vehicle observation uses
`Open77.vehicles.get` (`vehicles.read`). Local freeze uses
`Open77.character.setFrozen` (`player.freeze`). All required permissions were
already declared; this change grants no additional permissions.

## Adding a category

1. Register its ID/label/description in `shared/vehicle_customization.lua`.
2. Add a strict server validator/handler in `server/modules/vehicle_customization.lua`.
   Never dispatch a native named by the client.
3. Add its editor/selection in `ui/src/features/customization/VehicleCustomization.tsx`.
   Unknown editor IDs remain disabled; no speculative categories appear to players.
4. Extend the garage lease's confirmed-property mask and rollback operation for
   that category. Paint-only masking is intentional today: do not reuse it for
   previews of other fields until their persistence/rollback is implemented.
5. Reuse the single owned-vehicle lock and SQL properties row. Add checks for
   rollback, autosave isolation, removal during SQL and retrieval after restart.

## Verification

- `python3 tools/test-vehicle-customization.py`: real garage, inventory,
  customization RPC and camera scripts against deterministic SQL/native boundaries.
  Covers ownership and character isolation, black-vs-stock paint, preview autosave
  exclusion, cancellation, failed writes, delayed close, removal during SQL,
  parking/retrieval, restart, RPC replay/validation, orbit/pause/zoom and cleanup.
  The payment suite loads the real economy and inventory modules to check atomic
  cash/bank purchase, server pricing, unchanged-paint protection, insufficient funds,
  transaction failure, duplicate requests and disconnect while SQL is pending.
- `npm run build --prefix ui`.
- `PLAYWRIGHT_MODULE=/path/to/playwright CHROMIUM_PATH=/path/to/chrome node ui/tests/customization.browser.cjs`:
  automatic/coalesced palette and HEX previews, quoted bank purchase, balance updates,
  unchanged-paint/insufficient-cash guards, stale acknowledgement/error feedback, camera requests,
  Escape and 1920x1080, 1280x720, 800x600 layouts; screenshots in ignored
  `ui/artifacts/vehicle-customization-*.png`.
- MCP validation has the same pre-existing 47 errors and one warning as the base
  project (stale catalogue coverage and existing modules); no errors reference
  the added customization scripts or their permissions.

Still requires a real game-client pass for model-specific paint coverage and
camera clearance around the configured public garage, plus a second viewer to
observe the preview and confirmed repaint across streaming.
