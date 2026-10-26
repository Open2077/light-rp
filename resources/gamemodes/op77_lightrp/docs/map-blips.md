# Custom map icons and categories

LightRP depends on the standalone `open77_icons >=1.0.0` resource. Install it
under `resources/standalone/open77_icons` and include it in `resources.load`.
LightRP's dependency starts it automatically. The client must support SVG blips;
the locally installed development client does. No server binary change is needed.

All LightRP point-of-interest blips use Lucide outline icons in the server's
yellow accent (`#FFCC00`, size 40). Active work orders use size 48. Icons are
native: the same geometry appears on the map, its category index and minimap.

| Activity | Icon |
| --- | --- |
| Wardrobe | `shirt` |
| Rent-a-Ride | `key-round` |
| Public garage | `warehouse` |
| Vehicle dealership | `car-front` |
| Food / everyday shop | `shopping-basket` |
| Fuel station | `fuel` |
| Job Center | `briefcase-business` |
| Sanitation work | `trash-2` |
| Scrap recovery work | `recycle` |
| AC maintenance work | `fan` |
| Rooftop service access / exit | `arrow-up-down` |
| Job delivery / return to depot | `warehouse` |
| New point with no icon specified | `map-pin` |

Define `blip.icon` in the point's config; `blip.color` and `blip.size` optionally
override the defaults. Server registration copies these fields into the public
interaction list. Adding icons does not change positions, NPCs, prices, routes
or proximity checks. Nearby fuel pumps still share **one centred station blip**.

`client/core/interact.lua` routes creation, removal and GPS tracking through
the icon service. Its handles belong to the service, so call
`LightRpInteract.trackBlip(id)` instead of `Open77.blips.track(id)`. Public list
rebuilds remove old public handles but leave the current private job objective
alone. Objective replacement/cancellation removes its service-owned handle.
Service generation cleanup removes all remaining LightRP handles on stop/reload.

If the SVG API/provider is unavailable or its budget refuses an icon, a logged
native fallback preserves the location and interaction. Native fallbacks retain
their own ownership for cleanup/GPS. Unknown native sprites fall back to a
neutral objective, not a car. The package's 64-per-caller and 4096-polygon service
budgets still apply; do not turn the twelve fuel pumps into twelve map icons.

## Grouping

Wardrobe and rental points use `wardrobes.blip.title` and `rentals.blip.title`
from `shared/config.lua` as their shared map category names: **Wardrobe** and
**Rent-a-Ride**. Keep the branch/district in each spot's `name`; it is retained
in the interaction label and prepended to the blip description.

The updated Open77 client groups resource blips by exact title. Select a category,
then use Left/Right or its inline arrows to browse the locations without placing
a GPS waypoint. Adding another rental spot automatically joins Rent-a-Ride;
there is currently only one live rental desk. Four wardrobe points share one row.

No positions, interaction distances, rental stock, prices or NPC definitions
were changed for grouping.

Regression check from the resource directory:

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -Test map_blip_groups_test.lua
```

This exercises the actual server registration modules with a second mock-only
rental branch, without changing live data or spawning NPCs.

`interact_test.lua` covers custom fields, grouped coordinates, service-owned
GPS and cleanup, private objective preservation and native fallbacks.
`job_runs_client_test.lua` covers the job/kind icon selection and GPS lifecycle.

## Local validation — 2026-09-23

Fuel stations are passive points of interest (`routable=false`), not automatic
GPS destinations. Opening M or browsing their legend row must never create a
route. Players can still place a waypoint manually; private job objectives
continue to use their explicit tracking lifecycle. `refueling_test.lua`
asserts the passive flag along with station grouping and the custom fuel icon.

All 73 gamemode Lua sources parse. Eight affected suites pass: interactions,
map groups, client/server job runs, refueling, shops, garages and dealerships.
The actual server registrations preserve their icon fields; mocks additionally
assert correct service ownership for GPS/removal and old-client fallback.

Local server restarted with the icon dependency, client reconnected and world
entry confirmed. All seven public categories render the intended yellow SVGs
in the native map index (eight rows including Player). Wardrobe shows 1/4 and
Fuel station appears once. No custom-icon refusal/fallback or Lua error in the
session. Evidence in the platform repository:
`artifacts/lightrp-custom-icons-map.png`. Player position and character data were
not changed for this test. The gameplay client and local server remain running.
