# op77_scenes — LightRP edition of open77_scenes

RP scenes synced on world furniture. The first one: lying down on a ripperdoc chair
(72 surgical chairs across Night City), with the enter, pose and exit animations from
the prologue. Every player in the bucket sees the same thing, including those who arrive
mid-scene.

## What differs from `open77_scenes` (platform)

- **LightRP "E" prompt**: each free chair nearby becomes a local point of
  `op77_lightrp` (client export `InteractSetLocal`). It is the same keycap as shops,
  garages and counters, and the same key (`lightrp.interact`). A press fires the client event
  `op77_scenes:choice`, then the `op77_scenes:start` intent on the server. The server
  checks everything again: distance, free chair, player alive, on foot.
- `/scene` and `/standup` are staff-only (no out-of-RP commands for players).
- Names changed so it can sit next to the platform version in the `resources/` folder:
  - events `op77_scenes:*`;
  - convars `op77_scenes_reach`, `op77_scenes_prompt_radius`, `op77_scenes_turn_before_end_ms`;
  - keys `op77_scenes_stand` (H, stand up) and `op77_scenes_pose` (G, change pose).
- `auto_start true`, dependencies `open77_animations` and `op77_lightrp`.

**Do not load `open77_scenes` at the same time**: both would claim the same chairs.

The server side (`shared/`, `server/`) is identical to `open77_scenes`, apart from these
renames. A fix made upstream (open77-base `resources/system/open77_scenes`) has to be carried
over here by hand.

## Player

Near a free chair: keycap **E "Lie down"**. Once lying down, **H** to stand up and
**G** to change pose; both keys can be rebound in the settings. The prompt
disappears during the scene and when another player is in the chair.

## Required client

An Open77 client with the `ripperdoc` profile and `Open77Scenes.archive` in `archive/pc/mod`.
Both ship with the client from op77.169 onward.

## Tests

```powershell
pwsh resources/standalone/op77_scenes/tests/run-lua.ps1 -Test all.lua
```

They run the real server side against `tests/fakes.lua`, through the server's `lua54.dll`.

## Console (restricted)

`scenes.status`, `scenes.near <pid>`, `scenes.start <pid> <spot>`, `scenes.stand <pid>`,
`scenes.idle <pid>`, `scenes.tune <kind> <x> <y> <z> <yaw>`. Author guide and research: in
open77-base, `wiki/scenes.md` and `docs/research/rp-scenes.md`.
