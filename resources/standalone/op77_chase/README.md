# op77_chase — NCPD Chase

A Light RP activity (`chase.1v1`): cop against runner, 1v1, by car or on foot. Two rounds
with roles swapped, a decider when level. The rules are the Pursuit gamemode's
(`base/resources/gamemodes/pursuit`), ported onto Light RP's activity contract.

## How a chase runs

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

## Commands

| Command | Who | |
|---|---|---|
| `/chase [car\|foot]` | everyone | queue (car by default) |
| `/chase leave` | everyone | leave the queue, or forfeit the chase |
| `/chase status` / `top` / `rank` | everyone | where you are, the ladder, your rating |
| `chase.status` | staff (`command.chase.status`) | queue and matches |
| `chase.force <a> <b> [car\|foot]` | staff (`command.chase.force`) | start a match now |
| `chase.stop <matchId>` | staff (`command.chase.stop`) | void a match, everyone goes home |

## Database

Two tables, created on first use in Light RP's database: `op77_chase_ratings` (one row per
character, `identifier#characterKey`) and `op77_chase_matches` (one row per rated match). All
reads and writes happen on this resource's own threads. Without a database the ratings live
in memory for the run and the replies say so.

## Files

`shared/config.lua` every tuning number · `server/rules.lua` the round rules (pure) ·
`server/elo.lua` (pure) · `server/queue.lua` (pure) · `server/core.lua` the activity contract ·
`server/world.lua` every native · `server/match.lua` the lifecycle · `server/ranked.lua` Elo,
results, reputation · `server/main.lua` wiring. Overlay: `op77_chase_hud`.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test rules_test.lua
# also: adapter_test.lua, queue_elo_test.lua, match_test.lua
```
