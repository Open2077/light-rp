# On-foot refuelling

## Player flow

1. Park within 7 m of a pump, switch the engine off, and get out.
2. Press **E** at a real pump. The compact side terminal lists nearby network
   vehicles, their fuel, the amount/cost/duration and cash/bank payment methods.
   The list refreshes without reopening a closed terminal.
3. Choose a vehicle and an amount. Walk beside that vehicle within 45 seconds,
   then press **E**. The service animation requests alignment toward the vehicle; the existing native
   animation service owns temporary third person and network playback.
4. Stay still for the progress action. **Escape** cancels the progress; the
   animation-stop binding (**X** by default) cancels the approach.

The server commits fuel and payment after completion, not when clicking the
terminal. An interrupted action grants nothing and charges nothing. This is
**completion-based**, not litre-by-litre billing: an interrupted fill does not
leave partial fuel in the vehicle.

## Pumps and map

`shared/config.lua -> fuel.stations` contains the twelve supplied standing
positions. It uses the existing world pumps: no duplicate pump props are spawned.
`shared/fuel.lua` sorts IDs then creates bounded, deterministic spatial groups.
Every pair in a group must be within `clusterRadius` (35 m), and within
`clusterHeight` (4 m) vertically. This prevents chains joining entire streets or
joining an overpass to the station below. One blip is placed at each group's
centroid. Each pump still has its own interaction and exclusive reservation.

All twelve current pumps form **one** group. `tech` is a supported native service
icon; the old `GasStationVariant` is not supported by the installed client.
No per-pump blips, ground rings or tall 3D markers are created.

## Jerrycans

- Buying a full can or refilling an empty one is a timed action at a pump.
- Use a full/partial can from inventory on foot beside a stopped, engine-off car.
- Only the amount that fits is poured. `metadata.fuelLitres` retains the rest;
  the inventory label displays it. A depleted can becomes `jerrycan_empty`.
- The exact inventory/slot/item is revalidated. Moving or replacing the item
  during the action cancels it. Empty-can exchange and payment use one inventory
  draft and the existing wallet/inventory SQL transaction.
- A supported `container.gas_can` server prop is attached for the action and
  removed on completion/cancellation/disconnect/resource stop. It is not a local
  fake visible only to its owner.

## Guards

The server owns ticket identity, duration, litres and cost. Repeated ready/finish
messages and another player's token cannot grant a second effect. One active
ticket per player, pump and vehicle. Checks cover character identity, life,
routing bucket, seat, driver, engine, speed, vehicle displacement, player distance,
item identity and the exact native animation playback ID. The watchdog runs every
200 ms, including during the walk-to-car phase. Damage and character/session
changes cancel. A failed vehicle state write is not charged; a failed debit rolls
back the added fuel. Database unavailability refuses new actions.

The physical tank is a runtime state bag, not a database row: its mutation and
the wallet database cannot be a crash-atomic distributed transaction. Ordinary
payment failures are compensated; an abrupt process failure during settlement is
not a guarantee of atomicity. Paid can exchanges are database-atomic.

## Presentation / validation limits

The pump uses the installed `barlean` hand-interaction workspot, not a newly
authored fuel-nozzle animation. **A moving nozzle and flexible hose are not
implemented.** Do not describe this version as having a physical nozzle prop.
Jerrycans use the installed gas-can host. Exact hand grip/nozzle alignment is not
visually certified: the current workspot is a generic hand interaction. Pump
geometry can obstruct the third-person camera when standing directly against it.

2026-09-23 validation:

- `refueling_test.lua`: clustering, actor/vehicle guards, reservations, duration,
  replay/cancel/disconnect, state-write/payment failure, atomic can checkout,
  partial pours, inventory replacement and database failure.
- `refueling_client_test.lua`: focus handoff, walking objective, actual remapped
  cancel key, delayed progress start, stale events, cancellation and cleanup.
- Existing consumables, interactions, animations, shop and voice-HUD tests pass.
- TypeScript/Vite build passes; output staged in `ui/artifacts/refuel-20260923`.
- `ui/tests/fuel.browser.cjs` passes at 1280×720, 1920×1080, 2560×1440.
  Screenshot: `ui/artifacts/fuel-browser/terminal-1080.png`.
- Local server starts without module errors and reports
  `fuel: 12 pumps grouped into 1 station blip(s)`.
- Live acceptance completed on local LightRP after permission to reconnect and
  control the game. Two timed 10 L pump fills each charged 30 and increased the
  canonical tank by exactly 10 L. Approach timeout granted/charged nothing.
- A can purchase cancelled with Escape left the wallet unchanged. A completed
  purchase charged 85 for 20 L. Pouring it into a 50/55 L Galena transferred 5 L,
  filled the tank to 55 L and left **15 L** visible in the inventory can label.
- Native `perspective.state` confirmed the roleplay-animation third-person rig
  with a drawn, ready proxy during the action, then restoration of first person
  on cancellation/completion. Fresh game startup was needed after an earlier
  repeated-reconnect session hit native self-view `attach_timeout`; no native
  lifecycle fix is claimed by this Lua change.
- The in-game map index shows a single `Fuel station`, without a twelve-place
  group counter. Evidence: Core `artifacts/refuel/station-map-live.png`,
  `can-visible-live.png`, `can-pour-live.png`, `can-partial-result-live.png`.
- Fixed a live-only empty-list issue: Lua's empty `vehicles` table arrives as an
  object, not an array. The terminal normalizes this before `.find` and `.map`;
  browser regressions cover both initial opening and live empty snapshots.
- Installed September 19 server rejects the newer optional prop attachment
  `firstPerson` field with `invalid_attachment`. Only that schema rejection is
  retried without the optional field; all other attachment failures cancel.
  Lua regressions cover the retry and fail-closed paths.
- Tests were single-client. Network animation/prop APIs are used, but a second
  observer and concurrent real players were not separately validated in-game.
- Test purchase/fill charges were refunded. The temporary vehicle was removed;
  the test can was dropped for normal timed cleanup. Existing items were kept.

Sources: `server/modules/refueling.lua`, `client/core/refueling.lua` and
`ui/src/features/fuel/`. Consumption physics remains in `server/modules/fuel.lua`.
