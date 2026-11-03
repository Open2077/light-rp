# op77_playermarks

A small yellow dot floats over every other player's head, so a player tells people from the city's NPCs at a glance. While that player talks on voice, radio waves ring out of the dot, faster and wider with their voice level, and the dot swells and glows.

- **Starts:** on its own (add `"op77_playermarks"` to `resources.load`)
- **Needs:** nothing; it honours [op77_map3d](../op77_map3d/)'s hidden players when that resource runs (a chase runner gets no dot)
- **Runs on:** client (the dots and a transparent HUD page)

## How it works

Every `refreshMs` the client reads the players within `radius` (`Open77.players.nearby`, yourself excluded) and keeps one entity anchor (`Open77.anchors`) on each streamed body, `height` metres over its origin. The plugin projects the anchors every frame and pushes their screen positions to the page, which only writes transforms. Every `talkMs` the client reads `Open77.voice.talkers()` and sends the page only the changes (talking, level rounded to 0.05).

The dot shrinks with distance and fades out over the last fifth of `radius`. There is no occlusion: a dot shows through walls inside `radius`, like the map's player blips.

## Settings

`shared/config.lua` (`PlayerMarksConfig`): `enabled`, `radius` (35 m), `max` (24 dots; the plugin allows 32 anchors per resource), `height` (2.12 m), `refreshMs`, `talkMs`, `talkThreshold`, `color` and the page's distance scale.

## Tests

`tests/marks_test.lua` runs the client script against a stubbed host (players around, anchors, talkers, op77_map3d): run it from this folder with any Lua 5.4.
