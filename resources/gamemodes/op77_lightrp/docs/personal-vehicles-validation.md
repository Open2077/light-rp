# Personal vehicles validation — 2026-09-22

## Automated

- Production TypeScript + Vite build passes.
- Garage model tests: 2 pass.
- `vehicles.browser.cjs`: dealership and garage rendered at 1920×1080, 1280×720
  and 800×600, real packaged photos loaded, no JS exceptions, card clipping
  prevented, confirmation/single-flight/receipt/wrong-session/close tested.
- Lua module suites pass: garages, dealerships, creator bridge, shops,
  characters, vehicle access, vehicle context, job runs, map blip groups.
- Garage suite includes health/trunk recovery, SQL failure, occupied bays,
  occupants/movement, identity change, failed native spawn/remove, replay,
  removal recovery and reboot. Final stock-paint compatibility adapter is covered.
- Dealership suite uses the actual economy, garage and dealership modules:
  atomic transaction shape, insufficient funds, client price tampering, quote
  change, stale requests, duplicate/concurrent purchase, DB failure, cancellation
  before payment, disconnect during commit, closed/dead/different-character visits.

## Real client / local MySQL server

Temporarily used the existing private `server.local.jsonc` profile on
`127.0.0.1:11828`, then restored normal `server.jsonc`. Current native appearance
and pristine gameplay bootstrap completed; `char.state` confirmed alive gameplay.

Verified through the actual WebUI/native pipeline:

1. E at City Motors opens the 15-car catalogue with the character's real balances.
2. A 4,000-eddie MaiMai purchase is refused in the page with insufficient funds.
3. Temporary test credit, explicit purchase confirmation, SQL ownership INSERT and
   receipt succeed; wallet returns to its original balance after the purchase.
4. Garage shows the owned car, delivers a canonical network vehicle and gives keys.
5. Explicit storage removes the world entity; retrieving restores it under a new ID.
6. `admin.veh.remove` returns ownership to storage; the car can be collected again.
7. Server process restart while the car is out loads one SQL ownership into storage,
   without spawning an entity; reconnecting and retrieving succeeds.
8. Removed the QA ownership and its empty personal trunk after stopping the test
   server. Retained the test credit/purchase audit entries; no player money deleted.
9. Returned the player to its original area, closed the test game and restored the
   normal server profile with final built assets.

Ignored evidence: `.open77/garage-test.out.log`, `garage-reboot.out.log`,
`garage-final.out.log`, `ui/artifacts/dealer-ingame.png`, `dealer-receipt.png`,
`garage-ingame.png`, `garage-delivery.png`, `garage-reboot-recovered.png`.

Limits: one real client and one model. All catalogue models, actual two-player
races and nonempty trunk transfers were not all exercised in-game. Trunk content
and concurrency were tested with the real Lua modules and deterministic mocks.
The final stock-paint adapter was tested at the Lua boundary, not visually rerun.
Pickup clearance detects networked vehicles/players, not arbitrary static props.
No CDN publication, engine binary changes, Git commit or push were performed.
