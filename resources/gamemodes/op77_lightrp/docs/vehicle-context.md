# Vehicle interactions (Alt + click)

Hold **Alt**, click your vehicle, then select an action. This is a Light RP
consumer of `open77_contextmenu`: the standalone targeting package stays empty.
Only characters holding the selected vehicle's keys see the RP entries. The
server checks the real sender's keys again for every request.

## Actions

- Lock or unlock. Key possession never bypasses a locked vehicle.
- Open/close the trunk and hood.
- Access the selected trunk's inventory: opens the physical trunk and the
  inventory for **that exact vehicle**, not a nearby replacement.
- Start/stop the engine while parked.
- Lights off, headlights, high beams.
- Sound a short synchronised horn pulse.
- Check model name, lock, engine, lights and overall condition.

The root has at most four Light RP entries: lock/unlock, **Trunk & hood**,
**Vehicle controls**, and status. Trunk inventory and openings live in the first
submenu; engine, lights and horn live in the second. Empty submenus are omitted.
Click Back, press Left/Backspace, or right-click to return to root. Escape or
releasing Alt closes the entire menu. Navigation keeps the same target and never
executes an action.

The 14 registered definitions are state-dependent alternatives, not 14 permanent
rows. Bikes have no trunk/hood entries. Cabin door actions, all-door commands and
window controls have been removed from both the menu and server allowlist, at the
user's request after in-game testing. Old/forged requests for those IDs are rejected.
Admin entries remain separate and retain their own ACL checks.

The trunk remains physically open after closing the inventory, until explicitly
closed. Locking immediately revokes its inventory viewers and rejects in-flight
transfers, as with the L binding. Closing an opening is allowed while locked;
opening it or accessing its inventory requires an explicit unlock first.

## Server policy

All mutations run through the owning `op77_lightrp` server resource. The client
sends only an action ID and the exact network vehicle ID; it cannot select a
native function, mask, lock state, horn duration or authority identity.

- Active, living character, keys, matching routing bucket and proximity required.
- Trunk, hood, storage and engine require a parked vehicle (default <= 0.5 m/s).
- Trunk inventory is accessed from outside, within the inventory's own range too.
- Cabin controls belong to the driver. From outside, they require a parked,
  unoccupied car. A key holder cannot remotely stop someone else's car.
- A seated driver can operate the lights while doors are locked.
- Engine controls cannot revive a destroyed/undriveable vehicle.
- Native failures are reported, never converted to success.
- General cooldown: 300 ms; independent horn cooldown: 2.5 s; horn pulse: 450 ms.
- No free repairs, deletion, forced entry, seat ejection, fuel or invented plates.

Trunk/hood changes preserve unrelated masks and flags. Open77 replicates these
states to observers and stream-in clients; no direct client-side mutation or
permanent polling thread is installed by this consumer.

## Configuration and extension

`LightRpConfig.vehicleContext` controls enablement, near/remote ranges, parked
speed, cooldowns and model opening masks. Defaults are 4.5 m for physical/cabin
actions and 8 m for lock, horn and status. Only opening bits 4 (trunk = 16) and
5 (hood = 32) are used, default 48; bikes default to zero. These are model policies,
not native capability detection: configure unusual/custom models after checking
them in game. Setting other bits does not re-enable removed cabin door actions.

```lua
-- Example for a custom car exposing only a trunk:
LightRpConfig.vehicleContext.models["Vehicle.my_custom_car"] = {
    doors = 16,
}
```

Action definitions and read-only availability live in `shared/vehicle_context.lua`.
The client registers batches of at most five on both consumer and targeting
resource startup, using stable IDs to avoid duplicates. Selections hand input
back before the inventory opens. The server allowlist and validation live in
`server/modules/vehicle_context.lua`. `LightRP.inventory.openTrunk(playerId, id)`
is the server helper for opening the exact trunk; it independently checks inventory
existence, lock, proximity and bucket before opening the physical trunk.

## Validation

From the resource directory:

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -Test vehicle_context_test.lua
pwsh -NoProfile -File tests/run-lua.ps1 -Test vehicle_access_test.lua
pwsh -NoProfile -File tests/run-lua.ps1 -Test context_submenu_test.lua
```

Tests run the actual consumer, standalone registry and server modules against
mocked native APIs. They cover all actions, registration/restart, key changes,
exact trunk selection, lock revocation, masks, malformed requests, life, range,
buckets, occupancy, moving vehicles, cooldowns, bikes/coupes and native refusal.
The standalone registry/controller test checks submenu validation, provider
isolation and leaf dispatch. `node tests/context-submenus.browser.cjs` from `ui`
checks the real WebUI in a headless browser with a simulated bridge: four-entry
root, mouse/keyboard/back, stale replies, errors, layout and reduced motion.
Set `PLAYWRIGHT_MODULE` to an installed Playwright path if needed.
They do not assert model-specific animation quality; in-game checks are left to
the user as requested.
