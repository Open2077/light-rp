# op77_actionbubble

Roleplay action bubbles: a short line such as *Opens the trunk* or *Unlocks the vehicle* pinned in the world, on a character, a vehicle, an entity or a fixed point, for a set time. A diamond pin marks the anchor, a leader line draws up to a 3D hologram card (glass slab turned toward the centre of the screen, floating), the card (one line: icon + text, no label or name) unfolds, the text resolves out of glitch characters, a bar runs down its duration, then it folds away.

- **Starts:** on its own (add `"op77_actionbubble"` to `resources.load`, before the resources that use it)
- **Needs:** nothing
- **Runs on:** server (relay) and client (bubbles, page)

## Client API (any client resource)

```lua
local id, why = exports.op77_actionbubble:show({
    text = "Opens the trunk",      -- required, 96 bytes max (cut on a character boundary)
    -- the anchor, one of (or `anchor = { type = ..., ... }`):
    player = 12,                   -- a character (follows the body); no anchor at all = yourself
    vehicle = vehicleId,           -- a vehicle (follows it)
    entity = "123456",             -- an Open77 entity id (local only, never replicated)
    position = { x = 0, y = 0, z = 0 },
    offset = { x = 0, y = 0, z = 1.55 },   -- world axes; defaults per anchor in shared/config.lua
    duration = 4,                  -- seconds (0 = until hidden; replicated ones always end)
    kind = "action",               -- action | state | speech | alert | system (label + colour)
    icon = "trunk",                -- hand key lock unlock box trunk car door eye chat alert search wrench phone cash heart gear
    author = "Alex Morgan",        -- kept with the bubble (list), not drawn: the card stays in character
    accent = "#FFCC00",            -- overrides the kind's colour
    asterisks = true,              -- *text*, on by default for `action`
    side = "auto",                 -- auto | left | right: where the card sits from the anchor
    maxDistance = 25,              -- metres from the camera (2 to 80)
    network = false,               -- see below
})
exports.op77_actionbubble:update(id, { text = "Closes the trunk", duration = 3 })  -- text kind icon author accent duration offset position
exports.op77_actionbubble:hide(id)          -- plays the exit
exports.op77_actionbubble:clear()           -- every bubble this resource owns
exports.op77_actionbubble:exists(id)
exports.op77_actionbubble:list()
exports.op77_actionbubble:me("Unlocks the vehicle", { duration = 3, icon = "unlock" })  -- on yourself, replicated
```

### Replication: `network`

| Value | Effect |
|---|---|
| `nil` / `false` | this client only |
| `true` | the server shows it to the players within `range` (20 m) of the anchor |
| `{ range = 30 }` | same, with a range (max 60 m) |

A client may only replicate a bubble on its own character, or on a vehicle or point within 12 m of it, at most 6 shows/updates per 10 s (`shared/config.lua`). Entity anchors never replicate (entity ids are local to each client). The sender shows its bubble at once; the others get it from the server under the id `c<playerId>:<n>`, and its updates and end follow. A player walking into range of a bubble still running sees it for what is left of it.

### Limits (spam and network), all in `shared/config.lua`

| | Default | |
|---|---|---|
| `range` / `maxRange` | 20 m / 60 m | a replicated bubble is sent only to the players this close to its anchor, same routing bucket |
| `maxDistance` / `maxDistanceCap` | 25 m / 80 m | drawn only this close to the camera, fading over the last quarter |
| `rate` | 6 per 10 s | shows and updates a client may relay; beyond, dropped |
| `perSender` | 3 | live relayed bubbles per player; a new one ends the oldest |
| `perTarget` | 3 | bubbles stacked on one character, vehicle or spot on a screen; a new one sends the oldest away |
| `maxBubbles` | 24 | bubbles on one screen |
| `clientReach` | 12 m | how far from the sender a client-relayed bubble may be anchored |

The relay reads every player's position once per pass (one `Open77.players.positions` call, a dated read only for players standing still), and checks for late arrivals once a second, only for bubbles with more than a second left. A bubble is one event per receiver when it starts, one per update and one when it ends.

## Server API (any server resource)

```lua
local id, why = exports.op77_actionbubble:show({
    text = "Opens the trunk", vehicle = vehicleId, duration = 4, icon = "trunk",
    network = { range = 20 },               -- default: the players around the anchor
    -- network = { targets = { 12, 15 } }   -- exactly these players
    -- network = { targets = "all" }        -- everyone
})
exports.op77_actionbubble:update(id, patch)
exports.op77_actionbubble:hide(id)
exports.op77_actionbubble:clear()
exports.op77_actionbubble:exists(id)
exports.op77_actionbubble:list()
```

Server anchors: `player`, `vehicle`, `position` (there is no "yourself" and no entity on the server). Bubbles belong to the resource that made them (another one cannot update or hide them) and end when that resource stops; bubbles on a player end when the player leaves.

Console (restricted): `actionbubble.test <playerId> <text>`.

## How it draws

One transparent HUD page (`web/`, plain HTML/CSS/JS). Each bubble is an `Open77.anchors` anchor fed to that page: the plugin projects it on every game frame and pushes the screen position (`open77:anchors`), the page only writes transforms. A body or a vehicle is followed through its entity. The local player's own body has no entity id an anchor accepts, so a bubble on yourself is a position anchor the client moves every frame. A bubble whose body is not streamed waits, unplaced, until it is (or until it ends). At most 24 bubbles per client (the platform allows 32 anchors per resource); the oldest goes first.

## Files

| File | |
|---|---|
| `shared/config.lua` | durations, distances, ranges, rate, offsets, kinds |
| `shared/bubble.lua` | validation of definitions, patches, network options |
| `server/main.lua` | the relay and the server exports |
| `client/main.lua` | bubbles, anchors, lifetimes, client exports |
| `web/` | the page |
| `tests/bubble_test.lua` | `pwsh -NoProfile -File tests/run-lua.ps1 -Test bubble_test.lua` |
