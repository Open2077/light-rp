# Personal vehicles, public garages and City Motors

No vehicle is granted on registration or character creation. Characters acquire
vehicles through the dealership or a trusted staff/server grant.

## Player flow

Visit **Vehicle Dealership / City Motors** in City Center, next to Rent-a-Ride.
Press **E** at the yellow point to browse 15 models with photos, search, categories
and price sorting. Choose cash or bank, review the price and confirm. A successful
purchase is delivered to **City Center // Public Garage**, not spawned under the
player. The receipt names the collection point. Insufficient funds disable payment.

At **Public Garage**, press **E** (or `/garage` while standing at its point).
Select an owned vehicle and retrieve it into a free bay. It arrives locked with
owner keys; **L** unlocks it. To store it, stop within 18 m of the garage, have
everyone exit, open the garage and confirm storage. Storing at another configured
public garage changes its home garage. Collection is from that home garage only.

Defaults: 30 owned vehicles per character, one personal vehicle out at a time.
Rental vehicles remain separate. Ownership belongs to a character slot, not every
character on an account. Shared runtime keys are not persisted across restarts.

## Configuration

- `server/config/dealerships.lua`: catalogue, integer prices in eddies, location,
  delivery garage, enabled flag. These are starting economy prices, not game facts.
- `server/config/garages.lua`: locations, pickup bays/headings, radii, limits,
  save interval and enabled flag. Add garages with unique, stable IDs.
- `shared/config.lua` → `vehicles.catalog`: model keys and native records.
  Dealership offers cannot include `staffOnly` entries; trusted grants can.

Default point: dealership `(-640, -377, 8.19)`; garage `(-643.8, -383.5, 8.19)`.
Two pickup bays are south of the garage. Bay clearance checks canonical vehicles
and players, **not static world geometry**; survey new locations in-game.
Default points are in bucket 0; each location can set another bucket.

After changes, restart the resource/server while players are disconnected and
reconnect. The manifest uses `reload_policy "reconnect"`. UI source is in
`ui/src/features/dealership` and `ui/src/features/garage`; `npm run build` in `ui/`
updates the distributed `web/` assets. No client DLL build is needed.

## Staff and server API

```text
/lightrp.givevehicle <playerId|me> <modelKey> [garageId]
/lightrp.givevehicle me hella citycenter
```

Requires `command.lightrp.givevehicle` (covered by the existing staff
`command.lightrp.*` ACL). Creates durable ownership in storage, never a starter
grant or an immediate world entity.

These APIs are internal **server Lua** APIs within `op77_lightrp`, not client
natives or network events. Load dependent modules after `garages.lua`.

```lua
-- Rewards/staff deliveries. Optional globally unique key makes retries idempotent.
local ok, ownedIdOrError = LightRP.garage.grant(
    playerId, "hella", "citycenter", "job-reward:unique-job-instance")

-- Trusted custom dealerships: wallet + ownership + ledger commit atomically.
-- Never pass user-controlled prices/payment tables directly to this function.
local ok, ownedIdOrError = LightRP.garage.purchase(
    playerId, "hella", "citycenter", "sale:unique-purchase-id", {
        amount = 10000, method = "bank", vendor = "Custom Dealer",
        validate = function()
            -- Recheck caller-specific location/session requirements before payment.
            return true
        end,
    })

LightRP.garage.open(playerId, "citycenter") -- validates life, bucket, proximity
LightRP.dealership.open(playerId, "citycenter")
LightRP.garage.location("citycenter") -- {id, name, position} or nil
LightRP.garage.ownedId(networkVehicleId) -- durable UUID or nil
LightRP.garage.isBusy(playerId) -- character switch must wait during an operation
```

Both grant and purchase return `true, ownershipUuid` or `false, readableReason`.
An existing grant key returns its original ownership without charging again;
reusing it for another owner or model is refused. Call from yield-capable server
code (e.g. a command/action handler or `CreateThread`) after database readiness.
There is deliberately no public client-side grant API.

## Persistence and recovery

Requires configured MySQL and the server vehicle-properties API. The table
`lightrp_owned_vehicles` is created at startup. Garages fail closed if loading SQL
fails; an unavailable database is never interpreted as an empty garage.

- Ownership INSERT, wallet debit and ledger receipt are one SQL transaction.
- Network vehicle IDs are **never** persisted. On reboot cars are available in
  storage; they do not respawn into the world automatically.
- Canonical properties are captured during updates and flushed every 15 seconds,
  and before explicit parking. Health/damage are preserved, not repaired for free.
- Admin/system removal returns the car to its last garage, retaining ownership
  and the most recently captured properties. Missed removal events are checked
  by the periodic worker.
- A personal trunk is stored as `personal:<ownershipUuid>` in
  `lightrp_inventories`, rather than under its temporary network ID. The existing
  inventory write-through and access rules apply; parking locks and saves it first.
- A hard crash can lose up to the last property-save interval. Existing inventory
  mutations retain their existing persistence semantics; this is not an inventory
  transaction rewrite.
- Invalid property JSON is quarantined and logged, not overwritten or spawned.
- Removed garage IDs fall back to the configured default garage on startup.

This implementation assumes **one authoritative LightRP server per ownership
database**. Do not share the same tables between concurrently running worlds:
active-vehicle exclusion is in-process. It does not add vehicle trading, selling,
impound fees, insurance, repairs, dealership stock limits or 3D preview/test drives.

## Abuse/failure handling

Server checks the character, life state, routing bucket, proximity, payment method,
model, displayed quote and balance. Each short-lived visit has sequenced request
IDs. Duplicate confirmed requests only replay their result. In-flight operations
lock ownership and wallet; changing character is blocked while they settle.
Database failure cannot leave a purchase debit without ownership. A failed parking
write leaves the world vehicle alive. A failed cleanup retains its live mapping
so another vehicle cannot be collected. Occupied or moving cars cannot be stored.

The page shows progress, failures, purchase receipts and a delayed-confirmation
warning, and never retries a payment automatically. On death, character change,
expiry or leaving the area, the server closes the visit. A payment already committed
still belongs to its original character if the connection is lost.

## Regression checks

From the resource directory:

```powershell
pwsh -File tests/run-lua.ps1 -Test garages_test.lua
pwsh -File tests/run-lua.ps1 -Test dealerships_test.lua
pwsh -File tests/run-lua.ps1 -Test creator_bridge_test.lua
```

From `ui/`: `npm run build`,
`node --experimental-strip-types --test tests/garage-model.test.ts`, then
`node tests/vehicles.browser.cjs` with Playwright installed or
`PLAYWRIGHT_MODULE` pointing to an existing installation. The browser test renders
the built UI, exercises both dialogues at 1920×1080, 1280×720 and 800×600,
checks confirmation/acknowledgements and writes ignored `ui/artifacts` screenshots.
