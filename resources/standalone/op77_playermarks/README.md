# op77_playermarks

A nameplate in the Light RP design floats over every other player's head: a chamfered near-black chip with a yellow accent bar, the player's name in Chakra Petch capitals and three voice bars. While that player talks on voice, the bars light up yellow and move with their level, the chip warms and the pin pulses. A player tells people from the city's NPCs at a glance.

- **Starts:** on its own (add `"op77_playermarks"` to `resources.load`)
- **Needs:** nothing; it honours [op77_map3d](../op77_map3d/)'s hidden players when that resource runs (a chase runner gets no dot)
- **Runs on:** client (the dots and a transparent HUD page)

## How it works

Every `refreshMs` the client reads the players within `radius` (`Open77.players.nearby`, yourself excluded) and keeps one entity anchor (`Open77.anchors`) on each streamed body, `height` metres over its origin, with the name the platform lists for the player. The plugin projects the anchors every frame and pushes their screen positions to the page, which only writes transforms. Every `talkMs` the client reads `Open77.voice.talkers()` and sends the page only the changes (talking, level rounded to 0.05).

The plate shrinks with distance and fades out over the last fifth of `radius`. There is no occlusion: a plate shows through walls inside `radius`, like the map's player blips.

## Settings

`shared/config.lua` (`PlayerMarksConfig`): `enabled`, `radius` (35 m), `max` (24 dots; the plugin allows 32 anchors per resource), `height` (1.92 m), `nameMax` (24), `refreshMs`, `talkMs`, `talkThreshold` and the page's distance scale. op77_lightrp's own talking dot (client/core/talkers.lua) stays off while this resource runs.

## Tests

`tests/marks_test.lua` runs the client script against a stubbed host (players around, anchors, talkers, op77_map3d): run it from this folder with any Lua 5.4.
