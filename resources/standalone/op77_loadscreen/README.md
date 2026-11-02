# op77_loadscreen

The LightRP loading screen (yellow skyline, //77 mark, segmented bar, tips, boot log),
shown in two places:

1. **Joining the server.** The manifest declares `loadscreen "web/connect.html"`. The
   Open77 shell mounts that page from this resource's verified files while the world
   streams (after the resource download, before any resource Lua runs) and feeds it
   the loading progress: an estimate, then the engine's real fill. The phases before
   it (connection, download) keep the platform's own cover: the page's files are not
   on the player's disk yet.
2. **In game.** `client/main.lua` keeps `web/index.html` alive, transparent, on the
   `modal` layer (above HUD and menus, no focus) and shows it:
   - automatically over every native loading screen of the game (long teleports,
     far respawns), with the engine's progress (`Open77.screen.loadingState`);
   - on request, around a zone change (an interior, an instance, a lift).

Starts on its own: add `"op77_loadscreen"` to `resources.load`. Only one resource of a
server may declare `loadscreen` (the client takes the first by name).

## Covering a zone change

Server, without depending on this resource (unhandled when it is not loaded):

```lua
TriggerClientEvent("op77_loadscreen:cover", playerId, {
    id = "my:1",                    -- optional; the same id refreshes the cover
    title = "Kabuki Studio",        -- DESTINATION // title
    subtitle = "Private residence",
    zone = "Residence",             -- bottom right: NIGHT CITY // zone
    target = { x = 1, y = 2, z = 3 }, -- optional: lifted once the body stands there
    timeoutMs = 30000,              -- lifted anyway after this (1000..120000)
    minVisibleMs = 2200,            -- never shorter than this (0..15000)
    expectedMs = 7000,              -- the bar's estimate until real progress arrives
})
-- ... teleport, await ...
TriggerClientEvent("op77_loadscreen:release", playerId, { id = "my:1" }) -- id nil: all
```

or `exports.op77_loadscreen:cover(playerId, opts) -> id` and
`exports.op77_loadscreen:release(playerId, id?)` on the server; on the client
`exports.op77_loadscreen:cover(opts) -> id`, `:release(id?)`, `:isActive()`.

The cover stays up while a request is open or the native loading screen is active,
then 650 ms more on a full bar. op77_lightrp uses it through
`server/modules/zone_loading.lua` (housing, missions, first day hall/city, service lift).

## Check

- `/loadscreen.test [seconds] [playerId]` (restricted, ACL `command.loadscreen.test`):
  shows the cover on yourself for N seconds without moving you.
- `pwsh -File tests/run-lua.ps1`: state machine, client wiring, server front.
- Preview in a browser: serve `web/`, open `connect.html` (simulated load) or
  `index.html?demo=1&title=Kabuki%20Studio&subtitle=Private%20residence&zone=Watson`.

Art: `web/img/skyline.webp` (recompressed from the design's 2 MB PNG) and
`web/img/logo-77.png`; fonts self-hosted in `web/fonts` (Google Fonts, OFL).
