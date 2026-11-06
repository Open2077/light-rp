# op77_games

Minigames for Light RP, as providers of its activity contract. Each match has its own routing
bucket (`4500000-4599999`). Light RP admits and returns the player, and draws everything:
`ActivityHud*`, the `notice` export, the end-of-match recap. This resource has no page, no bots
and no lobby screen. Results carry `unranked`: nothing is recorded or paid, the recap still shows.

| Activity | Kind | Maps as imported | Rules |
|---|---|---|---|
| `games.tdm` | pvp | 2 | `server/modes/tdm.lua` |
| `games.redlight` | event | 1 | `server/modes/redlight.lua` |
| `games.gungame` | pvp | 3 | `server/modes/gungame.lua` |
| `games.control` | pvp | 1 | `server/modes/control.lua` |
| `games.ctf` | pvp | 2 | `server/modes/ctf.lua` |
| `games.prophunt` | event | 8 enabled, 5 disabled | `server/modes/prophunt.lua` |

## Maps

No map lives here. Staff make them in game with `/lightrp.maps`; they are stored by `op77_lightrp`
(`lightrp_game_maps`, `docs/map-editor.md` there). This resource holds a copy, in `server/maps.lua`.

- **What a map needs** is the `schema` each mode declares next to its rules: the only statement of
  it. The core validates against it and the editor builds its tools from it. The format is at the
  top of `server/maps.lua`.
- **Delivery** is a signal then a pull, never a net event: the core raises
  `op77_lightrp:gamemaps:changed`, this resource asks `gameMapIndex` for ids and revisions and
  `gameMap` for each map it does not hold, one per call (a call carries 48 KiB at most). The game
  registers again and the rooms menu follows, with no restart.
- **A running match keeps its map.** A sync builds new tables and never edits one handed out.
- **A game with no enabled map** is not offered and is no error: it registers with
  `offered = false`, joins are refused, `E.open` answers `no_map`.
- **The core not ready** (starting, or no database) changes nothing: we keep what we hold, and it
  signals when it can answer. Either resource may start first or restart.
- `prepare(map)`, on a mode, sets fields derived from a delivered map, on this VM's copy: control
  and CTF widen their play area, prop hunt centres it on the props' spawn.

## Files

- `server/activity.lua`: every call into `op77_lightrp`
- `server/engine.lua`: **the mode contract is at its top**. Matches, phases, deaths, bounds, HUD, results, every exit
- `server/combat.lua`: one combat scope per pvp match, the damage arbiter, a mode's kit through `activityKit`
- `server/lobby.lua`: `options.match` gathering, the panel's queue, `status`
- `server/maps.lua`: this VM's copy of the maps, the schemas sent to the core
- `server/main.lua`: events and the tick
- `client/main.lua`: forwards HUD state and plays cues. Decides nothing
- `client/prophunt.lua`: a prop hunt's view, own body and keys. Asks, decides nothing
- `client/objectives.lua`: markers and map pins a mode lists in `view.world`, sent to its players only

## Add a game

1. Give the mode a `schema` (format in `server/maps.lua`): the map editor offers the game once this
   resource restarts, and staff build its maps with `/lightrp.maps`.
2. `server/modes/<mode>.lua` calling `GamesEngine.mode({...})` (a typo in a field fails at load),
   and its `server_script` line, before `server/main.lua`.
3. Its id goes in Light RP's `lobby.activities`.
4. `tests/<mode>_test.lua` on `tests/harness.lua`, which loads what `open77.lua` lists.

## A match

`placing` (activityEnter, then the move into the bucket) → `countdown` (frozen, armed, scoped) →
`running` → `ended` (results and recap go out, the result card shows) → activityLeave.

A join with `options.match` plays exactly those players, on their `teams`, after all arrive or
`lobby.gatherSeconds`. A join without one queues for the next game; the first join's `options.map`
picks the map. A running game is never joined unless its mode sets `joinInProgress`. A crew that
comes through the queue (`options.squad`, one join per member) gets a place for all who can still
come or stays out whole, and plays on one side of a team game, unless it is the whole lobby: then
the deal splits it, so it still plays.

## Every way out

`E.remove` is the only exit, so team and kit always come off first. Weapons are Light RP's temporary
mission kits (`activityKit`, `Config.kits` per game, gun game's explicit steps): the core hands them,
retries, and takes them back at every exit, a body dead at the end included. A slot is only emptied
from here when the core is gone.

| Path | What happens |
|---|---|
| A player leaves | `activityLeave` in the same tick |
| Last opponent leaves | `forfeit`: the one left wins and sees the recap. Before GO: cancelled, no board |
| All leave | `abandoned`: the leavers get a board, the match closes |
| The clock | `time`, then the normal end |
| Disconnect, core timeout | The core already released them: never `activityLeave` |
| Character change | Released in place: the sweep takes them out |
| Provider stops | Kit asked back; the core returns them. Core gone too: slots emptied, fallback teleport |
| Core stops | Every match closes; fallback 2 s later if still inside |
| Core crashes silently | Owner lost for 3 s: `activityLeave` fails, fallback teleport |
| `activityLeave` refused | Fallback teleport; if that fails too, `SetPlayerRoutingBucket` |
| A body never lands | Sent back after 25 s |
| Scope refused 15 s | Cancelled, no result |
| Anything else | Every 5 s a sweep of our buckets; after 20 s a stray is taken out |

## Red light and lag

Positions are the server's dated reading (`Open77.players.get`). Over the source's 0.4 s grace and
0.35 m tolerance: the grace grows with the ping (at most 300 ms), a reading dated before the grace
ended never counts, a reading older than 500 ms freezes the check, the first reading after such a
gap re-anchors once per red light, and two readings in a row over the line are needed. A client
that lies about its position can still cheat, as in any mode.

## Gun game, control, CTF

Gun game: each step hands its weapon alone (the knife is the last step only: a knife in an idle slot
made every client weapon snapshot fail, 2026-11-06). A hit counts with the step's verified weapon
(`damage` hook on top of the engine's gate), and a kill needs such a hit by that killer on that step. Nothing else scores: a kill
the platform reports without one costs the victim nothing either. Live setting `DASH_gungame` is on:
a dash granted at GO, taken back on every exit (`left` hook); an implant's dash is left alone.

Control and CTF have no client event: the server reads bodies. A ring and pins go through `view.world`.
A marker is local to the client it is sent to, so only the match's players ever see one.
Flags are markers: the live `CTF_FLAG_MODEL` and `CTF_POLE_MODEL` are empty.
School's team spawn lists are filtered to each team's half: most of them sit on the other base.

## Prop hunt

One hunter per 4 players, picked by the mode. The hide and the hunt are per map (45 s, 300 s).
Hunters win when every prop is found, props by lasting the clock. A found prop joins the hunters.
Only a hunter's issued weapon counts, never melee. Hunters carry `Config.kits.prophunt`, props nothing.

- **The body.** Hidden with `players.setVisible`, wearing a server prop (`open77_props` must run).
  Still solid, still shootable; collision is never touched. Read back every 2 s.
- **Health is a ledger.** A hit is refused and counted against the object. The body's health,
  maximum, regeneration, armour and clothes never change: Light RP's cyberware and needs own those.
- **Exits.** `G.release`, through the `left` hook and `results`: object deleted, body shown,
  blackout cleared, freeze dropped, client let go. A refused show is asked again 5 times. A client
  that hears nothing for 20 s lets go by itself.
- **Keys** (rebindable, the HUD shows the player's own): R next object, V next family, T whistle,
  G turn, O lock, N first or third person, Z pulse (hunter). No picker screen.
- **Maps.** The 8 imported enabled rank highest on the margin between the hunters' spawn and the
  area's edge, less twice the height between the two spawns. Imported disabled, a game offering 8
  at most: Black Sapphire, Cynosure, Drive In, Ncart H7 (hunters 5 m from the edge), School (6.5 km
  out of the city, unverified). The area is drawn around the props' spawn. A map may list the
  objects it allows (`props`); none ticked: the whole catalogue.
- **Dropped from the source:** the gizmo (F, `Open77.gizmos` is in no published build), the
  centred prop camera (Light RP holds the one camera style), roulette, vote, spectating, misses.

## Tests

From this folder: `lua tests/activity_test.lua`, `engine_test.lua`, `maps_test.lua`, `tdm_test.lua`,
`redlight_test.lua`, `gungame_test.lua`, `control_test.lua`, `ctf_test.lua`,
`objectives_test.lua`, `prophunt_test.lua`. The harness plays the maps the core would deliver: its
stub reads `op77_lightrp`'s import data through that resource's real rules, so these tests need the
repository, not only this folder; nothing at runtime does. Nothing here has been played.
