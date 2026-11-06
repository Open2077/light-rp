# Map editor (game maps)

Staff build the maps of the `op77_games` games in game with `/lightrp.maps` (ACL `command.lightrp.maps`; the staff roles
already hold `command.lightrp.*`). No restart: an enabled map is in the rooms menu at once. Race courses keep `/race.editor`.

## Who owns what

- **`op77_games`** declares what a map needs: a `schema` per game, next to its rules (`server/modes/<game>.lua`, format at
  the top of `server/maps.lua` there). It is the single statement of it: the validation and the editor's tools read it.
- **`op77_lightrp`** owns the maps: storage, the staff protocol, validation, delivery.

| Game | Points | Lists | Numbers |
|---|---|---|---|
| Team Deathmatch, Gun Game | Play area centre | Spawn (2-32), inside the play area | Radius |
| Red Light, Green Light | Finish line | Start line spot (1-32), 5 m at least from the finish | Time limit (30-600 s) |
| Control | Control point, Red spawn, Blue spawn, Play area centre | | Radius |
| Capture the Flag | Red base, Blue base (10 m apart), Play area centre | Red spawn, Blue spawn (0-32, optional) | Radius |
| Prop Hunt | Props' spawn (the area's centre), Hunters' spawn (inside it) | | Radius, Hide time, Hunt time, Forced whistle, Whistle cooldown, Object change cooldown |

Prop Hunt also has **Objects**: the objects a map allows, ticked from the catalogue. None ticked: every object.

Control and Capture the Flag widen their play area over their points by themselves, so nothing has to stay inside it. A
map stored for Red Light keeps its `centre` and `radius`, but the game has no play area and reads neither: they are no tool.

## The editor

`/lightrp.maps` → a game → its maps. Enter opens a map. **Create a map** starts a private draft; nothing changes until it
is saved, and players see nothing until it is enabled.

The map page has the name (renaming keeps the map's id, so rooms keep working), a row per point and list, the numbers, then
**Save map**, **Map enabled**, **Duplicate map** (a new disabled draft) and **Delete map**.

### Build mode

The same crosshair as the mission editor ([mission-editor.md](mission-editor.md)): the same keys, weapons blocked, and F9
switches to the menu. The world stays playable (fly with `/noclip`). The tools are the game's schema, then **Radius** when
the game has a play area, then **Move**.

| Key | Action |
|---|---|
| **Left click** (or F10) | Place the tool's point at the crosshair; a list tool adds to its list |
| **Right click** | Select the aimed point: the menu opens on its page |
| **Delete** | Remove the aimed point |
| **↑ / ↓** | Previous / next tool |
| **← / →** | Turn the facing of the next placement by 15° (default: facing you) |
| **F11** | Place at your feet, facing your direction |
| **F9** | Back to the menu |

**Radius** sets the play area from its centre to where you click. **Move** picks a point up, then a click drops it.

Every placed point is drawn in the tool's colour for its author only, with an arrow for its facing, and the play area as a
yellow ring. The selected point and the aimed one turn white.

The keys are the mission editor's mappings, so a rebind serves both, and they still read "Mission editor" in the key
settings. One of the two editors is open at a time.

### Rules

- **A draft may be incomplete; an enabled map may not.** The menu lists what is missing (*Fix 2 issues*). Enabling, or
  saving an enabled map, is refused with the first issue. Only malformed input is refused on a draft.
- **At most 8 enabled maps per game**: the most `modes` holds. The editor refuses a ninth, drafts excepted, and says why;
  disable one first.
- **A stale save is refused, not overwritten**: *This map changed meanwhile*. Refresh and redo it.
- **Deleting is for good.** The row stays, marked deleted; the map leaves the rooms at once and never returns. Its name is
  free again, under a new id.
- **Names are unique within a game.** At most 32 maps per game, deleted ones not counted.
- **A match in progress keeps its map**, whatever is changed, disabled or deleted meanwhile.
- **A game with no enabled map is not offered**: not in the panel, not in the rooms menu. That is no error.
- A map whose game's schema grew past it stays stored and enabled, is not delivered, and is logged once.
- **A save names its game.** Ids repeat across games, so every map the server sends carries `game`, and a save of an existing
  map that does not send it back, or sends another, is refused.
- **The 3D preview holds 512 lines** (`debugDraw.set` refuses a whole batch past it). A map over that is fitted: the focused
  point then the nearest first, cheapest shapes first, and the build strip says what was simplified or left out.

## Storage

Table `lightrp_game_maps` (`id` = `<game>:<map>`, `game`, `definition` JSON, `revision`, `deleted`, `author`), with revision
checks and request keys for idempotent retries, as `lightrp_mission_defs`. Without a database nothing is saved: the menu
opens and says so, and `op77_games` keeps what it holds.

### The one-time import

`server/config/game_maps_seed.lua` holds the maps `op77_games` used to hardcode, every stored coordinate as it was, and is
only that: nothing plays from it. The import needs the database and every game's schema, whichever comes last. It is one
transaction with its mark in `lightrp_game_map_marks` (`seed-shared-maps`):

- it runs once; a failure leaves no row and no mark, and it runs again on a bounded backoff (1 s to 60 s, eight tries), then the next time staff open the menu or the core starts;
- a row that exists, deleted or not, is never touched, even if the mark is lost: staff work stays, a deleted map stays gone;
- the 5 spare Prop Hunt maps (Black Sapphire, Cynosure, Drive In, Ncart H7, School) arrive disabled;
- an enabled map failing validation arrives disabled, and is logged and kept in `LightRP.gameMaps.seedReport`. None fails today.

## Delivery

Server to server only, never a net event. A call carries 48 KiB at most, so maps travel one by one:

| | |
|---|---|
| `gameMapSchema({ resource, id, label, schema })` | `op77_games` declares a game. No database work |
| `gameMapIndex(game)` | `{ ready, maps = { { id, revision } } }`: enabled, valid, by name, 8 at most |
| `gameMap(game, id)` | One map, or nil |
| event `op77_lightrp:gamemaps:changed` (game or nil) | Pull again. It carries no map |

On a signal `op77_games` compares revisions, fetches what changed, swaps its list and registers that game again. A game with
none registers with `offered = false`, so a match still running on it keeps its owner.

Start order does not matter. `op77_games` sends its schemas and pulls each time it registers (its start, the core's start,
`op77_lightrp:activity:ready`). A core that cannot answer yet says `ready = false`, and signals once it can.

## Files

| File | Role |
|---|---|
| `server/modules/game_maps.lua` | Storage, import, protocol (`op77_lightrp:mapeditor`), `/lightrp.maps`, the provider's exports |
| `server/modules/game_map_rules.lua` | Pure checks: a schema, a map, what stops it being enabled |
| `server/config/game_maps_seed.lua` | The import data, nothing else |
| `client/core/map_editor.lua` | What a map looks like: aimed point, drawing, ghost, all from the schema |
| `client/core/mission_editor.lua` | The session it runs on: relay, input, capture, crosshair loop, keys |
| `ui/src/features/mapeditor/*` | The menu; `build.ts` = build mode actions; `model.ts` mirrors `R.problems`; mock `?registered=1&staff=1&mapeditor=1` |
| `ui/src/features/missioneditor/{api,rows,BuildStrip}*` | The shell both editors share |
| `op77_games/server/maps.lua` | The provider's copy, the schema format |

## Tests

```powershell
pwsh -File tests/run-lua.ps1 -Test map_editor_test.lua         # ACL, hostile input, stale, draft/enable, ninth, import, delete, no database
pwsh -File tests/run-lua.ps1 -Test map_editor_client_test.lua  # layers, hover, drawing, shared keys, one editor at a time
# op77_games: lua tests/maps_test.lua                           # schemas, import data, delivery orders, a running match
# ui/: bundle then run with node --test
npx esbuild tests/mapeditor-model.test.ts --bundle --platform=node --format=esm --outfile=%TEMP%/m.test.mjs; node --test %TEMP%/m.test.mjs
```
