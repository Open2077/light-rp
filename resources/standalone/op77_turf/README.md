# op77_turf: Turf War

A Light RP activity (`turf.war`, kind `pvp`). It is an instanced king of the hill between the
two gangs with the most players in the queue, fought in a copy of a real district. Each war runs in its own routing
bucket (4400000-4400099, inside our range 4400000-4499999). Light RP takes the fighters in
(`activityEnter`) and brings them back where they were (`activityLeave`).

Nothing of the RP world comes in: no RP weapons, no items, no needs, no cars. There is
no cash and nothing persists, except reputation (through Light RP's `result` event) and the
weekly gang influence table.

## Play

- **Queue**: from The Crossing (hub `join`, with a site choice) or `/turf join [site]`.
  Players keep playing while queued. Once 6 are queued (2 with `/turf.testing on`), a
  45 s lobby counts down (10 s when 24 are queued), then everyone who can go is pulled in.
- **Sides**: side 1 is the gang with the most players in the queue, side 2 the gang with the next most.
  Everyone else (other gangs, no gang) signs on with the smaller side as a **mercenary**. The
  sides never differ by more than one player. A gang's surplus waits in the queue and comes in as
  reinforcements while the war runs, until 3 min before the end. Gangs come from
  `activityPlayer(id).gang`; a player with no gang is unaffiliated. When a single crew queues
  alone, it splits for a training war.
- **Zones**: 3 per site. Standing in a zone captures it: 15 s for one attacker, x1.5 with two,
  x2 with three or more. A zone with both sides inside is frozen (contested). An attacker first
  winds back the enemy's half-capture. An empty zone's progress fades.
- **Score**: 1 point per held zone per second, +20 per capture, +3 per kill. The first side to
  900 wins. Otherwise, after 11 min, the higher score wins, then the side holding more zones,
  else it is a draw.
- **Life**: a fighter respawns after 6 s at the held zone nearest to where he fell (if it is
  uncontested and the enemy is not capturing it), else at his side's spawn. A fresh spawn has
  3 s of protection, broken by firing. A fighter who stays out of bounds for 8 s goes back to his spawn.
- **Kits** (engine-native, nothing persists): ASSAULT, BREACHER, MARKSMAN, GUNNER, TECH.
  `K` (rebindable, "Turf War: next kit") or `/turf kit <id>` picks the kit. It is swapped at
  once during the countdown or within 6 s of a spawn, otherwise it takes effect from the next life.
- **End**: the result card shows kills/deaths, captures, time on the zones, reputation, your
  gang's influence and who holds the city this week. Everyone goes home 10 s later.
- **Leaving**: `/turf leave` or the hub's leave is a forfeit for that player (a result with no
  reputation). His side plays on, and a side that empties loses by forfeit.

## HUD (Light RP's design system)

This resource has no page of its own. The client drives Light RP's shared activity HUD through
the `op77_lightrp` **client** exports `ActivityHudShow(hud)`, `ActivityHudPush(kind, payload)`
and `ActivityHudClear()`, always inside `pcall`:

- **phase**: lobby, countdown or running, then ended.
- **timer**: the time left, the countdown, or "home in" at the end.
- **objective**: who you fight for, plus down, out-of-bounds and protection states.
- **stats**: K/D, captures, time on the zones, kit. At the end they show the top 4 gangs of the week.
- **progress**: one bar per zone, with tone success (ours), danger (theirs), accent (contested) or info (neutral).
- **teams**: the two sides with their colours and scores.
- **scoreboard**: up to 16 rows, the player always included.
- **hints**: the kit key.

Feed, banners and the result card go through `ActivityHudPush`. A full HUD is re-sent only
when its content changes (otherwise every 5 s to resync the clock).

If the export is missing (older core), the client reports `op77_turf:hudless` and the server
sends banners and the result as notifications instead.

The zone markers are this resource's own: a ring and a diamond beacon per zone, in the
holder's colour, Light RP yellow `#FFCC00` when contested. So are the op77_map3d blips.

## Staff

| Command | ACL |
|---|---|
| `/turf.schedule <site\|auto> <minutes>` / `cancel`: announced (`op77_lightrp:announce`) at once and at 10/5/2/1 min and 30 s; the lobby opens at the time | `command.turf.schedule` |
| `/turf.start [site]`: close the lobby now with whoever is queued | `command.turf.start` |
| `/turf.stop`: void the war (nothing counts), close the lobby, cancel the schedule | `command.turf.stop` |
| `/turf.testing on\|off`: 2 players start a war, 2 accounts make it count | `command.turf.testing` |
| `/turf.survey [label]`: your position and heading in config syntax | `command.turf.survey` |
| `/turf.status`: queue, lobby, war, zones, fighters, influence | `command.turf.status` |

Sites: `kabuki` (Kabuki Market) and `badlands` (Badlands Compound) are offered in the hub.
`afterlife` is staff only (interiors never walked in a war). **Every position is marked
`-- survey in game`.** Walk them with `/turf.survey` before opening the activity.

## Weekly gang influence

The influence is kept in Light RP's database under this resource's prefix. The tables are
created on first use and written only from this resource's threads:

- `op77_turf_influence (week_index, gang)`: points, wars, wins, captures. Upserts are additive.
- `op77_turf_wars`: one row per war (site, gangs, scores, winner, fighters, duration, counted).

Weeks start on Monday at 00:00 UTC.

A war counts when it lasts at least 3 min with at least 4 distinct accounts (2 in testing mode).
A counted war is worth: win 10, draw 5, loss 2, plus 1 per capture made by the gang's own
members, up to 10. Mercenaries earn no influence for anyone.

Synchronous exports (memory only, never the database):

```lua
local list, week = exports.op77_turf:influence(6) -- { { gang, label, color, points, wars, wins, captures }, ... }
local points, rank = exports.op77_turf:influenceOf("valentinos")
```

Without a database, the table lives in memory for the run, and `/turf influence` says so.

## Integration (main session)

- **Load list**: `resources.load` += `op77_turf`, after `op77_lightrp`, `op77_map3d` and `op77_loadscreen`.
  Dependencies are `open77_notifications` and `open77_weapons`. There is no hard dependency on
  `op77_lightrp`: if the core stops, the war is voided, and the resource registers again on
  `op77_lightrp:activity:ready` or on the core's start.
- **ACL**: the six `command.turf.*` entries above, for staff.
- **Light RP (`LightRpActivities.buckets`)**: add `{ 4400000, 4499999 }`.

## Natives

Most natives are used by the running distribution: player life, respawn, teleport, freeze,
position and get; `Open77.combat.setTeam` and `onDamage`; `Open77.weapons.*`; markers;
`RegisterKeyMapping`; `SetRoutingBucket*`; `Open77.exports.callSync`.

**`Open77.combat.createScope` / `removeScope` (`combat.scope.control`) are documented in the
base wiki (since op77.63), but no resource in the running distribution uses them.** Light RP's
global PvP is off, so these scopes are what make war damage possible.

## Tests

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll C:\Games\cyberm\light-rp\lua54.dll -Test rules_test.lua
```

The other test files are `adapter_test.lua`, `war_test.lua` (the full flows, against a fake
Light RP through the real `server/main.lua`), `influence_test.lua` and `hud_test.lua`.
