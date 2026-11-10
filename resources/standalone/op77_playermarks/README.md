# op77_playermarks

A nameplate in the Light RP design floats over every other player's head: a chamfered near-black chip with a yellow accent bar, the player's name in Chakra Petch capitals and three voice bars. While that player talks on voice, the bars light up yellow and move with their level, the chip warms and the pin pulses. A player tells people from the city's NPCs at a glance.

- **Starts:** on its own (add `"op77_playermarks"` to `resources.load`)
- **Needs:** nothing; it honours [op77_map3d](../op77_map3d/)'s hidden players when that resource runs (a chase runner gets no plate)
- **Runs on:** client (the plugin's native plates, or a NativeUI document on a client without that drawer; no browser page since 0.3.0)

## How it works

**Native drawer (clients with `Open77.nameplates.style`).** At start the client hands the plugin the Light RP look as a theme (`Open77.nameplates.style`, values taken from `ui/playermarks.rcss` and `shared/config.lua`) and turns its drawer on (`render(true)`); no document is created. The plugin draws every plate itself in the frame that presents it: glued to the body on a fast turn, hidden behind walls (occlusion), lowered for a crouching player, the voice bars fed by the voice levels it reads itself. Every `refreshMs` (and at once when `setHidden`/`setNames` is called) the client sets each player's label (`[id] Name`) or hides the plate (`Open77.nameplates.set`), one call per player per change. `open77:worldReady` asks for the theme and the drawer again (a world exit drops the render request); stopping the resource releases both.

**NativeUI document (a client without that drawer, or `native = false`).** `ui/playermarks.rml` + `.rcss`, driven by `client/view.lua`: the same plate, value for value. Every `refreshMs` the client reads the players within `radius` (`Open77.players.nearby`, yourself excluded) and keeps one entity anchor (`Open77.anchors`, `render = "dot"`, `visible = false`: projected by the plugin, nothing drawn, no page) on each streamed body, `height` metres over its origin, and one plate element (`ui:create`). NativeUI's own anchors only follow `<scene3d>` points, so every frame the script reads the projections back (`Open77.anchors.frame()`) and moves the plates in one `ui:batch`: a `transform: translate()` per plate that moved, its scale and opacity when the distance changed, nothing when nothing changed. No layout is redone: plates are absolutely positioned, only transforms and opacity are written. A plate off screen or out of range fades (160 ms) and is then `display: none`. Every `talkMs` the client reads `Open77.voice.talkers()`; a talking plate's three bars are swung by the script (`scaleY`). There is no occlusion here: a plate shows through walls inside `radius`. NativeUI draws over every WebUI page, so the plates step aside while another interface holds the cursor (`hideUnderMenus`, `Open77.input.isCaptured()`). Without `Open77.ui` the resource logs one line and draws nothing.

Both shrink the plate with distance and fade it out over the last quarter of `radius`.

Exports (unchanged, for both drawers): `setHidden(on[, ids])` hides every plate or some players' (op77_lightrp in PvP and for staff ghosts, op77_games' Prop Hunt), per caller; `arePlatesHidden(id)`; `setNames({ [id] = name })` shows the characters' names (op77_lightrp). `open77_nameplates`, the platform's own plates, is not in Light RP's load lists; should it run anyway, this resource asks it to stand down (`setEnabled(false)`) while it runs, so there is only ever one set of plates.

## Settings

`shared/config.lua` (`PlayerMarksConfig`): `enabled`, `native` (use the native drawer when the client has it; `false` uses the NativeUI document everywhere), `radius` (35 m), `max` (24 plates in the document; the plugin allows 32 anchors per resource), `height` (1.92 m), `nameMax` (24), `refreshMs`, `talkMs`, `talkThreshold` and `hideUnderMenus` (document only) and the distance scale. op77_lightrp's own talking dot (client/core/talkers.lua) stays off while this resource runs.

## Tests

`tests/marks_test.lua` (players, anchors, exports, the document's feed), `tests/view_test.lua` (the document's driver: what a frame writes) and `tests/native_test.lua` (the native drawer and the fallbacks) run the client scripts against a stubbed host: `pwsh -NoProfile -File tests/run-lua.ps1 -Test marks_test.lua` (pass `-LuaDll` when `lua54.dll` is not four folders up).
