# Mission editor (authored missions)

Staff build missions in game with `/lightrp.missions` (ACL `command.lightrp.missions`; the staff roles already hold
`command.lightrp.*`). A published, enabled mission gets its own board in the city and runs through the existing
mission system: board, difficulty, squads, matchmaking, the instance's routing bucket, payout, reputation and unlocks.

## Mission types

- **Elimination.** The *start* spawn points spawn when the mission begins, a few seconds after the squad lands.
  - Entering a checkpoint wakes the spawn points linked to it.
  - The mission is done once every **required** checkpoint has been reached and no enemy is left standing.
- **Survival (waves).** Waves run in order.
  - A wave starts after its delay. The first delay counts from the start; each later one counts from the moment the previous wave is cleared.
  - Checkpoints can still wake extra spawn points.
  - The mission is done when the last wave is cleared.

## Rules shared by every type

- **Perimeter.** It uses the safe-zone geometry: a cylinder, an oriented box, or a polygon of 3–32 vertices, with a floor and ceiling or full height.
  - An operator outside the perimeter gets a warning and a red countdown on the HUD.
  - If they are still outside when the out-of-zone delay ends (3–60 s), the character dies.
- **Team respawns.** A death spends one respawn from the team pool. The operator comes back at a squad start after the respawn delay.
  - With no respawn left, the operator is out.
  - If nobody is standing and nobody is coming back, the squad is wiped and the mission fails.
  - A death before the first enemy costs nothing.
  - Only the `dead`, `dying`, `respawnpending` and `revivepending` life phases count as a death. A death the platform has not reported yet is still counted in the same tick, so a perimeter kill never reads as a wipe.
  - `admin.player.tp` is a kill followed by a respawn on the platform, so it spends a team respawn. If the operator is already back on their feet when the respawn delay ends, the mission does not respawn them again.
- **Time limit.** Set per difficulty, as for every mission.
- **Difficulties.** Standard, Hard and Critical, each with its own payout, time limit and squad size.
  - The payout is what **each** operator earns when the squad is at the difficulty's minimum size (defaults 2,400 / 3,000 / 4,400 €$). A bigger squad shares a pot that grows slower than the squad, a repeat within 60 minutes of a full payout at the same board or past six full payouts in the UTC day pays a quarter, and no payout goes above 250 €$ per minute of the time limit. The rules live in `server/config/economy.lua` (`missions`) and `docs/economy-balance.md`; the operators see the expected pay at launch and the reason when it is reduced.
  - Missions saved before these defaults keep their stored payouts: open them in the editor and set the new values (the 250 €$/min ceiling bounds them meanwhile).
  - Enemy count, health and damage each have a multiplier from 0.25 to 5.
  - Hard opens once Standard has been cleared on that board, and Critical once Hard has, as on every board.

## The editor

`/lightrp.missions` → **Create a mission**. The board, a squad start and a 40 m perimeter are placed around you.

### Build mode: place with the mouse

The mission page's first row, **Build mode**, does all the placing; F9 switches between it and the menu. The world stays
playable (fly with `/noclip`). The crosshair traces the world 20 times a second:

- the element of the current tool is drawn where it would land, in the tool's colour;
- the element under the crosshair turns white, and its name shows above the crosshair.

Shooting, melee and grenades are blocked while building.

| Key | Action |
|---|---|
| **Left click** (or F10) | Place the current tool's element at the crosshair |
| **Right click** | Select the aimed element: the menu opens on its page |
| **Delete** | Remove the aimed element (its checkpoint and wave links go with it) |
| **↑ / ↓** | Previous / next tool |
| **← / →** | Turn the facing of the next placement by 15° (default: facing you) |
| **F11** | Place at your feet, facing your direction |
| **F9** | Back to the menu |

| Tool | A click… |
|---|---|
| Enemy spawn | places a squad with the **brush** settings |
| Checkpoint | places a checkpoint (brush radius); right-click it to choose the spawns it wakes |
| Squad start | adds a start (up to 8) |
| Perimeter | moves the centre (cylinder, box) or adds the next vertex (polygon; walk the outline in order) |
| Perimeter size | on the edge: circle radius; on a corner: box length and width |
| Patrol route | adds the next patrol point to the selected spawn point (right-click a spawn first) and switches it to Patrol |
| Move | on an element: picks it up; then a click drops it (a spawn's patrol route travels with it) |
| Mission board | moves the board players open in the city |

**Spawn brush** (mission page, or the spawn list) is what every new spawn point starts with:
- enemy, count and trigger;
- behaviour, area radius and alert range;
- group spread;
- the radius of new checkpoints;
- whether new elements face you.

*Use these settings as the brush* on a spawn's page copies that spawn's settings into the brush.

### Behaviours

A spawn point's squad keeps its behaviour until it is **alerted**: an operator comes within the alert range, or one
of them is hurt. The alert then spreads to the whole squad of that spawn point.

| Behaviour | Until alerted | Once alerted |
|---|---|---|
| Assault | — (alerted at once) | rushes the nearest operator |
| Defend the area | holds the area radius around the spawn point | fights from it, chasing only operators inside the area (+15 m) |
| Patrol a route | walks spawn point → patrol points, in a loop | assault |
| Wander | drifts inside the area radius | assault |
| Ambush | stands still, combat and perception off: deaf and blind | combat back on, assault |

Group spread (0–10 m) is how far the squad stands around its spawn point.

### Menu

The menu is the keyboard shell of `/admin` and the safe zones:
- ↑↓ select a row;
- Enter opens it or toggles it;
- ←→ change lists and numbers;
- Enter on a number or text row types an exact value;
- Backspace / Escape goes back.

Every element also has *Place … with the mouse* and *Place … at my feet* rows and exact X/Y/Z rows.

**Preview colours** (only the author sees them):
- yellow: perimeter;
- white: board, and the selected or aimed element;
- green: starts, with an arrow for their facing;
- red: start spawns;
- orange: checkpoint spawns;
- violet: wave spawns and patrol routes;
- cyan: checkpoint rings, with a dashed tie to the spawns each one wakes.

Spawn rings show the group spread. Defend and Wander also show their area.

**Publishing**
- *Publish mission* first lists every issue (a start outside the perimeter, a spawn that never spawns, a patrol with no point…), then saves; the board goes live at once.
- *Test now* launches the **published** version for you alone, at any difficulty, wherever you stand. A test run pays nothing and unlocks nothing; `/mission leave` ends it.
- Republishing changes the board immediately. A run in progress keeps the definition it started with.
- Deleting removes the board; runs in progress finish normally.

## Storage and limits

- **Storage.** Table `lightrp_mission_defs` (`id` UUID, `definition` JSON, `revision`, `deleted`, `author`).
  - Writes use a revision check: an outdated draft is refused.
  - Request keys make retries idempotent.
  - Without a database nothing is published.
- **Limits:**
  - 64 missions;
  - 48 spawn points;
  - 16 checkpoints;
  - 20 waves;
  - 8 starts;
  - 40 enemies alive at once per run; the rest queue up and spawn as slots free;
  - spawn points within 300 m of the perimeter centre.

## Files

| File | Role |
|---|---|
| `shared/mission_defs.lua` | Format and validation (single contract), containment, enemy catalogue |
| `server/modules/mission_editor.lua` | Storage, protocol (`op77_lightrp:missioneditor`), `/lightrp.missions` |
| `server/modules/mission_engine.lua` | Runtime: spawns, retargeting, checkpoints, waves, perimeter, respawns, wipe, HUD view |
| `server/modules/missions.lua` | `addPoint` / `removePoint` / `launchNow`, test runs, objective in `missionQueue` |
| `client/core/mission_editor.lua` | Relay, build mode (crosshair trace, ghost, aimed element, keys, weapon block), preview |
| `client/core/mission_run.lua` | In-mission perimeter walls and checkpoint markers (`op77_lightrp:missionrun`) |
| `ui/src/features/missioneditor/*` | Editor page; `build.ts` = build mode actions, `BuildHud.tsx`; mock `?registered=1&staff=1&missioneditor=1` |
| `ui/src/features/missions/MissionObjectiveHud.tsx` | Objective tracker, out-of-zone warning; mock `?registered=1&mission=1&objective=eliminate\|waves\|oob` |

## Tests

```powershell
pwsh -File tests/run-lua.ps1 -Test mission_editor_test.lua         # format, storage, protocol, both types, perimeter, respawns, wipe
pwsh -File tests/run-lua.ps1 -Test mission_editor_client_test.lua  # captures, build mode, preview, keys, run visuals
# build mode actions (ui/): bundle then run with node --test
npx esbuild tests/missioneditor-build.test.ts --bundle --platform=node --format=esm --outfile=%TEMP%/b.test.mjs; node --test %TEMP%/b.test.mjs
```
