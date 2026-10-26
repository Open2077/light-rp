# Immersive consumables

Using a food or drink closes the inventory, starts a synchronized stationary RP
workspot, temporarily presents the character in third person, and opens the
shared LightRP action bar: a wide yellow bar without a background panel, the
action name, item name, remaining time and one Escape shortcut. It uses the same
presentation as gathering, processing, AC work and refuelling. Escape cancels.
The original camera preference is
not modified; stopping the workspot releases its temporary camera priority.

`shared/consumables.lua` defines reusable profiles and the item-to-profile map:

| Family | Duration | Playback |
| --- | --- | --- |
| Bottled drinks | 6.5 s | Bottle / drinking variant |
| Canned drinks (including coffee) | 5.5 s | Can / drinking variant |
| Meals | 8 s | Takeout / eating variant |
| Snacks | 5.5 s | Takeout / eating variant |
| Cigarettes | 12 s | Smoking variant |

These use the game's authored workspot props, not one custom mesh per inventory
illustration. Meals/snacks share a takeout box; coffee currently uses a can.
Medical items and registered utility handlers retain their existing behavior.

To add an item, give its template a `consumeAction` matching a configured profile.
Effects still come exclusively from the server's `LightRpItems[name].use`.
Never send duration, animation, item name or effects from the UI as authority.

## Lifecycle and guarantees

1. The server issues a one-use ticket bound to the player, character inventory,
   exact slot/stack and initial position. Nothing is spent.
2. The client closes inventory and waits for focus release before acknowledging.
3. The server starts the networked animation. Other players / late-streaming
   observers are handled by `open77_animations`, not a local-only clip.
4. The client displays the cancellable bar. Server elapsed time, life, distance,
   routing bucket, exact playback and exact stack are rechecked at completion.
5. Existing inventory locks serialize the final effects/removal with transfers
   and shop transactions. The ticket is claimed before any yielding calls.
6. Stop only that playback ID, which cleans up its workspot, props and camera.

Cancellation, death, movement, a replaced/removed stack, character change,
disconnect, native playback failure, UI failure or timeout apply no effects and
spend no item. Taking damage cancels client presentation too. Other inventory
operations need not be locked for the entire animation: invalidating the stack
simply makes completion fail. Existing inventory persistence semantics remain
unchanged; this is not a new cross-database transaction system.

Lua tests (from LightRP root):

```powershell
pwsh -File resources/gamemodes/op77_lightrp/tests/run-lua.ps1 -Test consumables_test.lua
pwsh -File resources/gamemodes/op77_lightrp/tests/run-lua.ps1 -Test consumables_client_test.lua
```

## Validation (2026-09-23)

The repository's `open77-testing` procedure was used against the authenticated
local server. Water rendered the bottle/drinking motion with live progress,
spent exactly one item and added hydration only on completion, then returned
from temporary TPP to FPP. Escape cancelled an eating action without spending
the burrito. A completed 8-second meal spent one burrito and added 35 food;
pre-existing F7 third person was preserved afterward. Inventory duration text
and the updated food icon were checked on the installed WebUI build.

Server/client Lua regression tests and inventory/action browser tests pass.
Two-client visual replication and the female rig were not visually checked;
the integration uses the existing networked animation service for both.
