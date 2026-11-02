# op77_chase — NCPD Chase and Most Wanted

Two Light RP activities (kind `chase`), queued from the hub or a command, each match in its
own routing bucket:

- **`chase.1v1` — NCPD Chase**: cop against runner, 1v1, by car or on foot. Two rounds with
  roles swapped, a decider when level, an Elo ladder. The rules are the Pursuit gamemode's
  (`base/resources/gamemodes/pursuit`), ported onto Light RP's activity contract.
- **`chase.wanted` — Most Wanted**: one runner against 2–7 cops (3–8 players), heat that rises
  with time, roadblocks, a late extraction point. Everyone runs once; points and a final ranking.

Both draw in **Light RP's own activity HUD** (`exports.op77_lightrp:ActivityHudShow / Push /
Clear`, Light RP's design): this resource ships no page. Every call is pcall'd; without the
HUD the server keeps sending notifications (the client tells it which with `op77_chase:hudFeed`).

## How a 1v1 chase runs

1. A player queues from the hub (Light RP raises `op77_lightrp:activity:join`, with an optional
   `options.mode = "car" | "foot"`) or with `/chase [car|foot]`. He keeps playing in the city
   while he waits.
2. When two compatible players are queued, both are re-checked (`activityCheck`) and taken
   over (`activityEnter`). A refusal hands back the one who already entered and keeps the other
   at the head of the queue.
3. The match gets its own routing bucket (4300000–4300099), no ambient population. Both players
   are teleported onto their marks (a downed player is respawned there instead), then held
   (`setFrozen`) through a 10 s countdown. In car mode the two match cars are created now, in
   the match bucket, beside each player.
4. The round: the cop fills the arrest meter by staying within `bustDistance` of a runner who
   is (nearly) stopped; the runner escapes by holding a 100 m gap for 18 s (after an arming
   delay). The clock belongs to the cop; an attempt running at the buzzer plays out as overtime.
   A crash stalls the car for 3 s. Downed runner = cop wins; downed cop = runner wins.
5. Intermission, roles swap, round 2; a decider if level.
6. Result: one `op77_lightrp:activity:result` per connected player (placement, rounds won,
   stats, reputation; no cash, no items) and an Elo per character.
7. After 5 s on the scoreboard each player is taken out of his car, respawned if down, and
   released with `activityLeave(..., { returnPlayer = true })`. The cars are removed, the bucket
   swept and freed.

Leaving (`leaveRequest`, `/chase leave`) is a forfeit: rated as a loss once a round has been
played, no reputation. `dropped` (Light RP already released the player) never calls
`activityLeave`. A placement that fails or times out voids the match: nothing counts, no
result is sent.

## How Most Wanted runs

1. **Lobby.** Players queue from the hub (`options.mode = "car" | "foot"`: the runner's mode,
   majority vote, car on a tie) or with `/wanted [car|foot]` and keep playing. Once the minimum
   (3; 2 in staff test mode) is ready a 45 s countdown starts, announced server-wide
   (`op77_lightrp:announce`, at most every 5 min); a full lobby (8) starts at once. A queued
   player Light RP refuses for the moment (another activity) is not counted, told every 30 s,
   dropped after 2 min. One chase queue at a time: queued for one, refused by the other.
2. **A round.** Bucket 4300100–4300199. The runner stands by his car (or on his mark, on foot)
   at the route's start, the cops by their NCPD cars on a start grid 250-330 m away (two routes,
   alternating). 10 s countdown, everyone held. GO: the runner goes; the cops are released by
   **waves** — half after the head start (10 s by car, 15 s on foot), the rest at heat 2.
3. **Heat** (5 levels, at 0/30/60/95/125 s): dispatch sightings get tighter and more frequent
   (a fuzzed circle on the cops' map, 30 s/160 m down to 8 s/50 m; 4 s/25 m while a cop has eyes
   on him), the arrest radius widens and fills faster; **roadblocks** from heat 3 (car mode:
   two locked, immortal NCPD cars 66 m ahead at his altitude, never on a measured grade over
   6 %, never within 12 m of a player, 40 s each, two at most); the **extraction point** at
   heat 4 (a race checkpoint 450–1300 m away, 200–500 m on foot), shown to the runner with a
   GPS route and to the cops 20 s later.
4. **Ends** — arrest: the 1v1 meter, widened to a unit (every extra cop closing at once adds
   +50 % fill rate, capped at ×2.5; the nearest gets the arrest, cops closing in the last 6 s or
   within 30 m the assist); takedown: runner down (credit to a cop within 40 m); the runner
   survives 2:45 or reaches the extraction. A **shake** (no released cop within 150 m for 12 s)
   earns him points once per approach. A downed cop is back at the line-up 5 s later with a new
   car.
5. **Rotation.** Next runner, until everyone has run once. Late joiners are taken at the next
   round (`activityEnter` then) and get their turn at the end (8 rounds at most).
6. **Points**: runner 1/s free, +40 survived, +80 extracted, +15 per shake; arrest +60, assist
   +30, takedown +40, +10 to every cop when the unit wins. Ranking by points, then time as
   runner (equal points and time share a place).
7. **Results**: one `op77_lightrp:activity:result` per player still there (placement, points,
   won, stats, reputation 40/30/25/15 by place when the match had 3+ players, for 6 matches per character
   per day; no cash, no items). 10 s scoreboard, then out of the car and `activityLeave(...,
   { returnPlayer = true })`; cars and roadblocks removed, bucket swept.

Leaving mid-match: an immediate result (last place, no reputation), home at once; the match
goes on while two players remain (a runner who leaves ends his round unscored). `dropped`:
no result, no `activityLeave`. A match with no round played is void.

## The HUD and the map

`client/view.lua` turns the server's payloads into the activity HUD: title, round and roles,
timer, countdown, objective line, stats (heat, cops near and nearest cop for the runner, a
banded distance to the runner for the cops, points), bars (arrest, shake, heat), Runner/NCPD
sides and the round scoreboard (points, time as runner, arrests, assists); round starts, GO,
dispatch, heat and round results as banners, the final ranking as a result card. Server
messages go to the HUD's feed, split to its line length.

With `op77_map3d` (optional): the runner's dot is hidden from the cops for the whole match
(`setPlayerDotsHidden`, 1v1 and Most Wanted, `config.minimap.hideRunnerFromCops`), the
extraction and the last sighting are blips, the runner's GPS goes to the extraction and his own
waypoint comes back after; everything is re-applied when the map reloads and dropped when
this resource stops.

## Commands

| Command | Who | |
|---|---|---|
| `/chase [car\|foot]` | everyone | queue for the 1v1 (car by default) |
| `/chase leave` | everyone | leave the queue, or forfeit the chase |
| `/chase status` / `top` / `rank` | everyone | where you are, the ladder, your rating |
| `/wanted [car\|foot]` | everyone | queue for Most Wanted |
| `/wanted leave` / `status` | everyone | leave the queue or the match / where you are |
| `chase.status` | staff (`command.chase.status`) | 1v1 queue and matches |
| `chase.force <a> <b> [car\|foot]` | staff (`command.chase.force`) | start a 1v1 now |
| `chase.stop <matchId>` | staff (`command.chase.stop`) | void a 1v1, everyone goes home |
| `chase.wanted.status` | staff (`command.chase.wanted.status`) | Most Wanted lobby and matches |
| `chase.wanted.force <id> <id> [...] [car\|foot]` | staff (`command.chase.wanted.force`) | start Most Wanted now (2–8 players) |
| `chase.wanted.stop <matchId>` | staff (`command.chase.wanted.stop`) | void it, everyone goes home |
| `chase.wanted.test [on\|off]` | staff (`command.chase.wanted.test`) | 2 players are enough (never any reputation) |

## Database

Two tables, created on first use in Light RP's database: `op77_chase_ratings` (one row per
character, `identifier#characterKey`) and `op77_chase_matches` (one row per rated match). All
reads and writes happen on this resource's own threads. Without a database the ratings live
in memory for the run and the replies say so. Most Wanted stores nothing (its daily
reputation cap is in memory).

## Files

`shared/config.lua` every tuning number (`ChaseConfig.wanted` for Most Wanted) ·
`server/rules.lua` 1v1 round rules (pure) · `server/elo.lua` (pure) · `server/queue.lua`
(pure) · `server/core.lua` the activity contract (both ids) · `server/world.lua` every native ·
`server/match.lua` 1v1 lifecycle · `server/ranked.lua` Elo, results, reputation ·
`server/wanted_rules.lua` Most Wanted rules (pure) · `server/wanted_lobby.lua` (pure) ·
`server/wanted.lua` Most Wanted lifecycle · `server/main.lua`, `server/wanted_main.lua` wiring ·
`client/view.lua` payload → activity HUD (pure) · `client/main.lua` HUD, feed, map.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test rules_test.lua
# also: adapter_test.lua, queue_elo_test.lua, match_test.lua,
#       wanted_rules_test.lua, wanted_test.lua, client_test.lua
```
