# Voice range preview

F11 changes the voice mode in `open-voice`. Each change **confirmed by the
server** shows a yellow 3D circle on the ground for three seconds, only
to the player concerned. It follows their position and uses the exact radius of the mode:
whisper 3 m, normal 20 m, shout 40 m.

The distances are set in `resources/system/open-voice/server/config.lua`.
`LightRpConfig.voice.ranges` is an old HUD setting, **not** the
source of the F11 ranges. The circle uses the server's answer directly.
The color and duration are at the top of `open-voice/client/range_preview.lua`.

The native renderer `Open77.anchors.create({ render = "ring", ... })` projects
vertices defined in world space and samples the terrain/obstacles. It does not
create a CEF surface or a mesh entity. Large ranges can extend beyond
the field of view; obstacles can hide part of the circle.
This renderer is limited to a 50 m radius: beyond that, a diagnostic is logged,
without blocking voice or showing a circle of misleading size.

One handle and one temporary task: quick changes reuse
the circle and restart its timer. The task stops when it expires, on death,
when the character disappears, or when the voice HUD is hidden. The resource
lifecycle also cleans up the anchors on disconnect/stop.
The first sync, duplicates and refused requests do not show it.

## Validation — 22 September 2026

Real Lua tests, with deterministic doubles of the native APIs:

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -Test voice_range_test.lua
pwsh -NoProfile -File tests/run-lua.ps1 -Test voice_hud_test.lua
```

Results: radius, following, quick changes, expiry not extended by
duplicates, refused requests, NaN/infinity, death, loss of the character, renderer
errors, independence from UI blocks, and resource stop/restart all validated.

Local in-game validation on `127.0.0.1:11828`: world entry confirmed by a
finished bootstrap and a living character; real F11, 3/20/40 m circles, following
while walking, gone after three seconds. Local screenshots in
`.open77/voice-range-{whisper,normal,shout,follow,expired}.png` at the LightRP root.
No new circle-failure diagnostic and no Lua error in the log.
The test covers the visual feedback; no audio codec/routing change
and no new multiplayer mic/network validation are claimed.
