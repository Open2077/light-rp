# op77_chase — NCPD Chase, Most Wanted and NCPD Escape

Three Light RP activities (kind `chase`), queued from the hub or a command, each match in its
own routing bucket:

- **`chase.1v1` — NCPD Chase**: cop against runner, 1v1, by car or on foot. Two rounds with
  roles swapped, a decider when level, an Elo ladder. The rules are the Pursuit gamemode's
  (`base/resources/gamemodes/pursuit`), ported onto Light RP's activity contract.
- **`chase.wanted` — Most Wanted**: one runner against 2–7 cops (3–8 players), heat that rises
  with time, roadblocks, a late extraction point. Everyone runs once; points and a final ranking.
- **`chase.pve` — NCPD Escape**: public PvE, no staff switch. One player or a crew (1–4
  runners, each in his own car or on foot) against **the game's own NCPD**: the server raises
  each runner's wanted level, stars climbing with the clock up to the difficulty's ceiling
  (Standard 3, Hard 4, Critical 5). Stop and you are busted; reach the extraction or outlast the
  clock. Results and reputation as usual (less than PvP, × the difficulty), no rating.

The 1v1 and Most Wanted are **real players only**: they register `botFill = false` with Light
RP, and staff bot mode no longer fills them unless `config.bots.fill` says so. Light RP
**crews** (`options.squad`) are kept together in all three.

All three draw in **Light RP's own activity HUD** (`exports.op77_lightrp:ActivityHudShow / Push /
Clear`, Light RP's design): this resource ships no page. Every call is pcall'd; without the
HUD the server keeps sending notifications (the client tells it which with `op77_chase:hudFeed`).

Those notifications are Light RP's own notice too: the server sends them through
`exports.op77_lightrp:notice(playerId, { kind, title, body, durationMs })` and the client (a
feed line with no HUD to land in) through `exports.op77_lightrp:Notice`. `open77_notifications`
is only the fallback when Light RP cannot show it (stopped, an older build, its page not up).
Light RP already answers a join or a leave from the hub and shows the queue in its queue panel,
so this resource adds no "queued for…", "you left…" or "you left Most Wanted, the match goes
on" notice on top; the `/chase`, `/wanted` and `/escape` commands still reply in chat, and the
staff bot-mode sentence (not on the panel) is still sent.

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
2. **A round.** Bucket 4300100–4300199. The cops stand by their NCPD cars on a start grid (two
   routes, alternating). By car the runner's car stands at the front of that grid (the course's
   checkpoint 1, ~27 m ahead of the first cop car: `routes[*].runnerCar`); on foot he stands on
   his mark 250-330 m down the road. 10 s countdown, everyone held. GO: by car the runner and
   every cop leave together (no head start, heat 1 releases the whole NCPD — owner, 2026-11-04:
   the runner used to be out of sight before the cops moved); on foot the cops are released
   when his 15 s head start ends.
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

## How NCPD Escape runs

1. **Queue.** From the hub (`options.mode = "vehicle" | "foot"`, `options.difficulty =
   "standard" | "hard" | "critical"`, plus `options.squad` for a crew) or with
   `/escape [car|foot] [standard|hard|critical]` (any order; `normal`, `hardcore`, `maxtac` work
   too). The difficulty goes to `activityCheck` / `activityEnter` as `{ difficulty }`: Light RP
   gates it by reputation tier and its sentence is the refusal. A solo join starts 2 s later; a
   crew starts once every member has joined (or after 10 s with whoever is there, 4 at most), in
   the leader's mode and difficulty (Light RP may refuse a member that difficulty). One chase
   activity at a time.
2. **The start.** Bucket 4300200–4300299, on one of Most Wanted's routes, each runner beside
   his own car (on foot: side by side). The instance gets **crowd, traffic and police**
   (`world.setPopulation(bucket, { crowd = 0.5, traffic = 1.0, police = true })`, emptied again
   after). 10 s countdown, everyone held.
3. **GO and the heat.** A head start (6 s by car, 8 s on foot), then the runner's wanted level
   follows the clock (`config.pve.difficulties[*].heat`, seconds after the head start):

   | Difficulty | Stars | Bust meter | Extraction | Clock |
   |---|---|---|---|---|
   | Standard | 1 → 2 at +30 s → 3 at +75 s | 5 s | at 40 s | 2:30 |
   | Hard | 2 → 3 at +30 s → 4 at +75 s | 4 s | at 55 s | 2:45 |
   | Critical | 2 → 3 at +25 s → 4 at +55 s → 5 at +95 s | 3 s | at 70 s | 3:00 |

   The ceiling (`setMaxWanted`) is sent first, then the level (`setWanted`), and the level is
   sent again every 15 s (the engine may drop it). The police are the runner's own game's: the
   server cannot see them, so it owns the outcome.
4. **Each runner's own end.**
   - **BUSTED** by the **bust meter**: it fills while he is stopped (under 10 km/h by car, 5 km/h
     on foot, measured over a 1 s window) or, by car, out of every car (under 35 km/h without a
     seat: faster means a car the server cannot see), over the difficulty's bust time; it drains
     in 2.5 s once he moves. It arms with the first star, and by car once he has sat in his car
     (or 15 s after GO). A meter past 60 % that drains back is a **close call**. An unreadable
     position freezes it; 3 s of blackout empties it. **Downed** = busted at once.
   - **ESCAPED**: inside the extraction (15 m by car, 7 m on foot; 450–1300 m away by car,
     200–500 m on foot, with a GPS route), or still free when the clock runs out.
   - Either way his stars go back to **0 and the ceiling to 5** at once. The others play on;
     the match ends when no runner is left, after an 8 s scoreboard, home through
     `activityLeave(..., { returnPlayer = true })`.
5. **Results**, one per runner at his own end: placement 1 escaped / 2 busted, `won`,
   `difficulty`, stats (outcome, how, seconds, stars reached, close calls as `shakes`, police,
   policeBlocked, crew) and the end-of-match **recap** board (the runners; lines: police and
   difficulty, stars reached, result and how, time — one line per runner for a crew).
   Reputation **18 escaped / 6 busted** at Standard, × 2 at Hard (36 / 12), × 10/3 at Critical
   (60 / 20) — Light RP's PvE rewards 30 / 60 / 100 × 0.6. Nothing for a round under 60 s,
   nothing for a leaver, only the first 8 paid rounds of a character per day (in memory). No
   rating, no database.

Leaving after GO: an immediate result (placement 2, `forfeit`, no reputation), home at once.
Leaving before GO with nobody left, a placement failure or `chase.pve.stop`: void, nothing
counts. `dropped`: no result, no `activityLeave`. **Every one of these clears the wanted
level** (below).

**Bot cops instead** (`config.pve.police = "bots"`, off by default): the previous NCPD Escape
— NCPD bot cars, `1 + 2 × runners` (8 at most), Most Wanted's waves and unit arrest, a shake
escapes; no wanted level, no population. It needs working bot drivers ("Bot drivers" below).

## NCPD Escape and the wanted level

Natives (server): `Open77.players.setWanted`, `setMaxWanted`, `getWanted` (`players.wanted`,
`players.wanted.read`); the population through `Open77.world.setPopulation`
(`world.population`). The client reads `Open77.prevention.state()` (`world.prevention`, never
a write). `Open77.world.setPreventionEnabled` is **never called**: bucket 0's dispatch is
never touched (and the chase buckets, above 65535, could not be addressed by it anyway).

**Always back to 0 / 5.** The level and the ceiling are cleared on a bust, an escape, a leave,
a drop, a disconnect, a bucket change away from the instance (`onPlayerBucketChange`), Light
RP stopping, a staff stop, the match closing, and the player going home. Each raise is
written to this resource's KVP (`escape.wanted.<id>` = identifier); a clear that succeeds
deletes it. **A resource stop or reload cannot clear**: the runtime refuses every call once
the resource is stopping (`resource_stopping`). The ledger keeps those players, and the next
start (1.5 s after it) clears every one still connected under the same identifier (an id now
used by someone else, or a player who left, only loses his entry; the server forgets a
disconnected player's level anyway). Until a platform fix (the prevention service releasing a
stopped resource's levels, or Light RP clearing the level when a PvE activity releases its
players), a runner may keep his stars for the few seconds of a reload.

**The platform gap.** Wanted level and police are per client (one PreventionSystem in each
game) and not replicated; the server's PreventionService pushes the level to the player's
client (`open77_prevention`, deployed with Light RP). On 2.31 builds up to now the client
**refuses every raise while population suppression is active**, and Open77 turns
suppression on at start: `client/src/api/Prevention.cpp:47`,
`if (aLevel > 0 && Population::IsSuppressionActive()) return Status::PopulationSuppressed;`.
The fix is to check `&& !Population::PoliceAllowed()` too (the bucket's `police = true`
allows it): a client DLL rebuild. Until it ships the server cannot know whether police came,
so the client probes `Open77.prevention.state()` every ~2 s while it has stars and sends
`op77_chase:police` (`expected`, `requested`, `suppressed`, `acknowledged`, `attached`: five
values). A level still refused after 6 s is logged, shown on the HUD ("Your game refused the
NCPD") and either tolerated (`config.pve.onPoliceBlocked = "warn"`, the default: the run goes
on, the bust and the clock still apply) or called off (`"void"`, nothing counts). The staff
status line shows both sides: `wanted: <id>=<ours>/<ceiling> server <L>/<M> game <requested>
suppressed BLOCKED`.

**Traffic and population** are per client too: each game populates its own world from the
bucket's settings, so two runners in one instance do not see the same cars or the same cops.

## Bot mode (staff)

Light RP's staff switch `/lightrp.bots on|off` (host-wide event `op77_lightrp:activity:bots`,
read again through the `activityBots()` export after every registration; off at start).

**The 1v1 and Most Wanted are real players only by default.** `config.bots.fill` (`chase.1v1`,
`chase.wanted`: `false`) decides; each registration declares it to Light RP as **`botFill`**
(top level: Light RP's lobby offers bots only where it is `true`) and as `caps.botFill` (the
hub's toggle). NCPD Escape always declares `false` (no player slot for a bot: the police are
the game's). With bot mode on and the fill off, a queued player gets "Bot mode is on, but
NCPD Chase / Most Wanted is real players only: you wait for other players." and nothing
starts with bots. With a fill turned on (it needs working bot drivers, below), the
behaviour is the one described here. While bot mode is on Light RP records no result at all;
this resource still posts them, marked `test = true` with no reputation, and never writes
`op77_chase_ratings` / `op77_chase_matches` for a match with a bot.

- **1v1.** A player who has waited 2 s in the `/chase` queue with no human opponent (and whose
  crew is not on its way) gets a bot. By car the match uses a course start grid (runner at the
  front, cop ~43 m back): the bot cop drives an NCPD car after the player
  (`vehicles.ai.chase`), the bot runner drives the course (`followRoute`), then the traffic
  (`driveWander`). On foot the bot cop runs after the player (`npcs.tasks.moveTo`), the bot
  runner flees (`npcs.tasks.flee`). A bot runner pinned within the bust radius for 4 s (3 s on
  foot) gives up and stops, so the arrest meter fills as against a cornered player. Arrest and
  escape are measured on the bot's server-side position (its car through `vehicles.get`, its
  body through `npcs.presence`). Two rounds with the roles swapped, as usual; the player's
  first role alternates from one bot match to the next.
- **Most Wanted.** One queued player is enough: a 5 s lobby countdown (never announced), then
  the match is filled with bots up to 3 players. Everyone runs once, bots included. Bot cops
  chase the runner once their wave is released; a bot runner drives the route, then heads for
  the extraction once it shows up. Dispatch, roadblocks and the extraction work as in a human
  match. The match ends when no human is left.
- **Switching off** starts no new bot match and admits no drop-in into one; a running match
  plays out.
- **Names.** Bots are `[BOT] <name>` in the HUD and the scoreboard. The hidden map
  dots (`op77_map3d`) only ever list players: nothing is hidden from a bot, and a bot runner's
  "dot" is never sent.
- **Cleanup.** Bots and their cars live in the match bucket and go at the match end, when the
  player leaves or drops, and when this resource or Light RP stops. The previous run's orphans
  are swept at start, and no NPC is created in the first 5 s.
- **Natives** (`world.npcs`, `world.vehicles`, declared in `open77.lua`): every call is guarded,
  a refusal is logged once. If no body can be seated the car drives itself (driverless
  `attachDriver`); if a bot cannot be set up at all the match is called off, nothing counts.
- A bot cop more than 300 m from its runner for 5 s is dispatched again, 120–220 m behind him
  on his own trail (no AI drives beyond ~350 m of a player).

`chase.bots` lists the switch and every live bot (1v1, Most Wanted, NCPD Escape).

## Bot drivers

On the client builds up to now **no bot car drives after a player or along a route**: the
client log shows `vehicle.ai malformed_request fields=16` for every `vehicles.ai.chase`,
`followRoute` and `driveTo` order. The request is a `|`-joined line of 17 fields and the
traffic pattern field is empty for everything but `joinTraffic`; REDscript's
`StrSplit(request, "|")` drops empty fields by default (`includeEmpty = false`), so the line
splits into 16 and `Open77ApplyDriving` rejects it. The fix is one argument in
`base/client/redscript/Open77VehicleDriving.reds` (the poll loop, `fields = StrSplit(request,
"|");`, ~line 1508): `StrSplit(request, "|", true)`. REDscript only, no DLL rebuild, but the
client script has to ship. `joinTraffic` is not affected (its pattern field is filled); the
race AI and every other `chase` / `followRoute` / `driveTo` caller are.

## Crews

Light RP passes a crew as `options.squad = { id, leader, members }` on each member's join.

- **1v1**: two members of one crew in the queue face each other (the first one's mode). A crew
  member is not paired with a stranger for 10 s while another member of his crew has not
  queued yet.
- **Most Wanted**: a crew is kept whole in one match. The lobby holds it (up to 10 s,
  `wanted.lobby.squadHoldSeconds`) while a member is missing or not ready, and splits it only
  when it is bigger than the seats left. In a round its cops line up side by side and roll out
  in the same wave.
- **NCPD Escape**: `config.pve.crews = "together"` (the default): one instance, each runner
  chased by his own NCPD (his own wanted level; police and traffic are per client anyway); or
  `"solo"`: each member in his own instance, started together.

## The HUD and the map

`client/view.lua` turns the server's payloads into the activity HUD: title, round and roles,
timer, countdown, objective line, stats (heat, cops near and nearest cop for the runner, a
banded distance to the runner for the cops, points), bars (arrest, shake, heat), Runner/NCPD
sides and the round scoreboard (points, time as runner, arrests, assists); round starts, GO,
dispatch, heat and round results as banners, the final ranking as a result card. Server
messages go to the HUD's feed, split to its line length. NCPD Escape draws "Solo" or "Crew of
N" with the difficulty, the wanted level as stars (★ held, ☆ still to come up to the
ceiling), the next star or MAX, the extraction distance, close calls, the clock, the **bust
meter** (visible once armed; "MOVE" / "get back in a car" when it fills), a star banner each
time the heat rises, and a scoreboard of the runners (status, heat, time); each runner gets
his own result card (time, heat, reputation) when his round ends. With `police = "bots"`:
the unit count, heat / cops near / nearest cop, the arrest, shake and heat bars and the
`[BOT]` cops.

With `op77_map3d` (optional): the runner's dot is hidden from the cops for the whole match
(`setPlayerDotsHidden`, 1v1 and Most Wanted, `config.minimap.hideRunnerFromCops`; players
only, so never for a bot runner, and never in NCPD Escape, where every cop is a bot), the
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
| `/escape [car\|foot] [standard\|hard\|critical]` | everyone | start NCPD Escape (solo; a crew joins from the hub) |
| `/escape leave` / `status` | everyone | leave the queue or the escape / where you are |
| `chase.status` | staff (`command.chase.status`) | 1v1 queue and matches |
| `chase.force <a> <b> [car\|foot]` | staff (`command.chase.force`) | start a 1v1 now |
| `chase.stop <matchId>` | staff (`command.chase.stop`) | void a 1v1, everyone goes home |
| `chase.wanted.status` | staff (`command.chase.wanted.status`) | Most Wanted lobby and matches |
| `chase.wanted.force <id> <id> [...] [car\|foot]` | staff (`command.chase.wanted.force`) | start Most Wanted now (2–8 players) |
| `chase.wanted.stop <matchId>` | staff (`command.chase.wanted.stop`) | void it, everyone goes home |
| `chase.wanted.test [on\|off]` | staff (`command.chase.wanted.test`) | 2 players are enough (never any reputation) |
| `chase.pve.status` | staff (`command.chase.pve.status`) | NCPD Escape queue and matches, each runner's stars, bust meter and wanted level (ours, the server's, his game's) |
| `chase.pve.stop <matchId>` | staff (`command.chase.pve.stop`) | void an escape, everyone goes home |
| `chase.bots` | staff (`command.chase.bots`) | bot mode and every live bot |
| `/lightrp.bots on\|off` | staff (Light RP's own) | bot mode (fills the 1v1 / Most Wanted only where `config.bots.fill` allows) |

## Database

Two tables, created on first use in Light RP's database: `op77_chase_ratings` (one row per
character, `identifier#characterKey`) and `op77_chase_matches` (one row per rated match). All
reads and writes happen on this resource's own threads. Without a database the ratings live
in memory for the run and the replies say so. Most Wanted and NCPD Escape store nothing
(their daily reputation caps are in memory), and a match with a bot is never written.

## Files

`shared/config.lua` every tuning number (`ChaseConfig.wanted` for Most Wanted) ·
`server/rules.lua` 1v1 round rules (pure) · `server/elo.lua` (pure) · `server/queue.lua`
(pure) · `server/core.lua` the activity contract (both ids) · `server/world.lua` every native ·
`server/match.lua` 1v1 lifecycle · `server/ranked.lua` Elo, results, reputation ·
`server/wanted_rules.lua` Most Wanted rules (pure) · `server/wanted_lobby.lua` (pure) ·
`server/wanted.lua` Most Wanted lifecycle · `server/bots.lua` bots (NPC drivers, orders,
positions; a bot id never reaches a player native) · `server/escape_rules.lua` NCPD Escape
heat, bust meter, extraction, clock (pure) · `server/police.lua` the wanted level, its KVP
ledger and the client's reports · `server/pve.lua` NCPD Escape lifecycle · `server/recap.lua`
the board each result carries for Light RP's end-of-match recap ·
`server/main.lua`, `server/wanted_main.lua`, `server/pve_main.lua` wiring ·
`client/view.lua` payload → activity HUD (pure) · `client/main.lua` HUD, feed, map.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test rules_test.lua
# also: adapter_test.lua, queue_elo_test.lua, match_test.lua,
#       wanted_rules_test.lua, wanted_test.lua, client_test.lua,
#       bots_test.lua (bot mode, crews), pve_test.lua (NCPD Escape)
```

`bots_test.lua` and `pve_test.lua` load the whole resource through `tests/bots_env.lua`: a fake
Light RP (with `activityBots` and the tier gate), fake `npcs` / `vehicles.ai` natives that record
every call, a fake world (wanted level, population, KVP) that fails the test if a bot id ever
reaches a player native, and a recorder that fails it on any database touch.
