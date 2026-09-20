# Vehicle interactions (Alt + click)

Hold **Alt**, click your vehicle, then select an action. This is a Light RP
consumer of `open77_contextmenu`: the standalone targeting package stays empty.
Only characters holding the selected vehicle's keys see the RP entries. The
server checks the real sender's keys again for every request.

## Actions

- Lock or unlock. Key possession never bypasses a locked vehicle.
- Open/close each supported door, trunk and hood.
- Open all cabin doors; close all supported doors, trunk and hood together.
- Access the selected trunk's inventory: opens the physical trunk and the
  inventory for **that exact vehicle**, not a nearby replacement.
- Raise/lower the supported windows, independently of broken-glass damage.
- Start/stop the engine while parked.
- Lights off, headlights, high beams.
- Sound a short synchronised horn pulse.
- Check model name, lock, engine, lights and overall condition.

The 26 registered definitions are alternatives, not 26 permanent rows: open/close,
lock/unlock and engine choices follow the latest replicated state. An already
selected light mode is hidden. Bikes have no door/window/trunk entries; unknown
car layouts use the conservative front-doors/trunk/hood profile. Admin actions
remain separate and retain their own ACL checks.

The trunk remains physically open after closing the inventory, until explicitly
closed. Locking immediately revokes its inventory viewers and rejects in-flight
transfers, as with the L binding. Closing an opening is allowed while locked;
opening it or accessing its inventory requires an explicit unlock first.

## Server policy

All mutations run through the owning `op77_lightrp` server resource. The client
sends only an action ID and the exact network vehicle ID; it cannot select a
native function, mask, lock state, horn duration or authority identity.

- Active, living character, keys, matching routing bucket and proximity required.
- Doors, storage and engine require a parked vehicle (default <= 0.5 m/s).
- Trunk inventory is accessed from outside, within the inventory's own range too.
- Cabin controls belong to the driver. From outside, they require a parked,
  unoccupied car. A key holder cannot remotely stop someone else's car.
- A seated driver can operate windows/lights while doors are locked.
- Engine controls cannot revive a destroyed/undriveable vehicle.
- Native failures are reported, never converted to success.
- General cooldown: 300 ms; independent horn cooldown: 2.5 s; horn pulse: 450 ms.
- No free repairs, deletion, forced entry, seat ejection, fuel or invented plates.

Door/window changes preserve unrelated masks and flags. Open77 replicates these
states to observers and stream-in clients; no direct client-side mutation or
permanent polling thread is installed by this consumer.

## Configuration and extension

`LightRpConfig.vehicleContext` controls enablement, near/remote ranges, parked
speed, cooldowns and model opening masks. Defaults are 4.5 m for physical/cabin
actions and 8 m for lock, horn and status. Six door bits represent front left,
front right, rear left, rear right, trunk and hood; four window bits represent
the first four doors. These are model policies, not native capability detection:
unusual/custom models may not animate all generic slots. Configure their masks
after checking the model in game. Do not infer rear doors from the catalogue's
generic seat count.

```lua
-- Example for a two-door car with a trunk and hood:
LightRpConfig.vehicleContext.models["Vehicle.my_custom_car"] = {
    doors = 51,   -- bits 0, 1, 4, 5
    windows = 3, -- bits 0, 1
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
```

Tests run the actual consumer, standalone registry and server modules against
mocked native APIs. They cover all actions, registration/restart, key changes,
exact trunk selection, lock revocation, masks, malformed requests, life, range,
buckets, occupancy, moving vehicles, cooldowns, bikes/coupes and native refusal.
They do not assert model-specific animation quality; in-game checks are left to
the user as requested.
