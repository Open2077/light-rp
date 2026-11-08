# op77_playermarks

A nameplate in the Light RP design floats over every other player's head: a chamfered near-black chip with a yellow accent bar, the player's name in Chakra Petch capitals and three voice bars. While that player talks on voice, the bars light up yellow and move with their level, the chip warms and the pin pulses. A player tells people from the city's NPCs at a glance.

- **Starts:** on its own (add `"op77_playermarks"` to `resources.load`)
- **Needs:** nothing; it honours [op77_map3d](../op77_map3d/)'s hidden players when that resource runs (a chase runner gets no plate)
- **Runs on:** client (the plugin's native plates, or a transparent HUD page on older clients)

## How it works

**Native drawer (clients with `Open77.nameplates.style`).** At start the client hands the plugin the Light RP look as a theme (`Open77.nameplates.style`, values taken from `web/app.css` and `shared/config.lua`) and turns its drawer on (`render(true)`); no page is created. The plugin draws every plate itself in the frame that presents it: glued to the body on a fast turn, hidden behind walls (occlusion), lowered for a crouching player, the voice bars fed by the voice levels it reads itself. Every `refreshMs` (and at once when `setHidden`/`setNames` is called) the client sets each player's label (`[id] Name`) or hides the plate (`Open77.nameplates.set`), one call per player per change. `open77:worldReady` asks for the theme and the drawer again (a world exit drops the render request); stopping the resource releases both.

**Page (older clients).** Every `refreshMs` the client reads the players within `radius` (`Open77.players.nearby`, yourself excluded) and keeps one entity anchor (`Open77.anchors`) on each streamed body, `height` metres over its origin, with the name the platform lists for the player. The plugin projects the anchors every frame and pushes their screen positions to the page, which only writes transforms. Every `talkMs` the client reads `Open77.voice.talkers()` and sends the page only the changes (talking, level rounded to 0.05). There is no occlusion on the page: a plate shows through walls inside `radius`.

Both shrink the plate with distance and fade it out over the last quarter of `radius`.

Exports (unchanged, for both drawers): `setHidden(on[, ids])` hides every plate or some players' (op77_lightrp in PvP and for staff ghosts, op77_games' Prop Hunt), per caller; `arePlatesHidden(id)`; `setNames({ [id] = name })` shows the characters' names (op77_lightrp). `open77_nameplates`, the platform's own plates, is not in Light RP's load lists; should it run anyway, this resource asks it to stand down (`setEnabled(false)`) while it runs, so there is only ever one set of plates.

## Settings

`shared/config.lua` (`PlayerMarksConfig`): `enabled`, `native` (use the native drawer when the client has it; `false` keeps the page everywhere), `radius` (35 m), `max` (24 plates on the page; the plugin allows 32 anchors per resource), `height` (1.92 m), `nameMax` (24), `refreshMs`, `talkMs`, `talkThreshold` (page only) and the distance scale. op77_lightrp's own talking dot (client/core/talkers.lua) stays off while this resource runs.

## Tests

`tests/marks_test.lua` (the page) and `tests/native_test.lua` (the native drawer) run the client script against a stubbed host: run them from this folder with any Lua 5.4.
