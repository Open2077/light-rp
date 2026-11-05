# op77_race

Races for Light RP, provided as activities of the Light RP activity contract
(`op77_lightrp`). The engine is Freeroam's race engine, ported and cut loose from
Freeroam:

| Activity | Id | Players | What |
|---|---|---|---|
| Time Trial | `race.trial` | 1 | Solo against the clock on any course; best times per course |
| Street Race | `race.grid` | 2-8 | A grid of identical loaner cars |
| Rooftop Race | `race.foot` | 2-8 | On foot across the rooftops |
| Street Race vs AI | `race.pve` | 1-8 | Solo or with a crew, AI drivers fill the grid; course chosen like the trial |
| Parkour Race | `race.parkour` | 2-8 | A rooftop race on parkour courses, double jump and dash for the race only; unranked; course chosen in the panel |

## How it works

- **Admission.** Races are joined from Light RP's Activities panel (`/race` opens it):
  the hub sends `op77_lightrp:activity:join`. The time trial and the race vs AI register
  their courses as join choices (`modes`, at most 8, `modeKey = "course"`, registered
  again when a course is saved or deleted), handed back as `options.course`. Our own
  entry points (`/timetrial`, `/race.join`) call `activityCheck` first. A time trial
  starts at once, and so does a race vs AI for a player alone. Street and rooftop races
  queue: once the minimum is waiting, a join window opens (30 s / 25 s, 5 s when full),
  then every queued player is checked again and the race starts with as many as the
  course takes.
- **Crews.** The core passes `options.squad = { id, leader, members }` with each member's
  join (one join per member). A crew races in one instance, on adjacent slots, and is
  never split across two: a crew that does not fit beside the others waits whole for
  the next heat, and a launch waits up to `crews.gatherSeconds` (5 s) for members still
  on their way. A crew joining the race vs AI starts together once every member has
  joined (or 5 s after the first), on the leader's choice of course. Only a crew bigger
  than the whole grid is cut, and the ones left out are told.
- **Matches** (street and rooftop races, `options.match` from Light RP's lobby: a
  friendly crew match, a bot-filled match, or a ranked match the core gathered). Exactly
  `match.players` race in a heat of their own (never the public queue, never joined by
  anyone else), started as soon as all are in, or `matches.gatherSeconds` (5 s) after
  the first with whoever came; a join arriving after the start is refused. AI racers =
  `options.fill` (enemies + allies: a race has no sides), once per match, within
  `matches.fillTo` (6 racers in total) and the course, through the same filling as bot
  mode; none on a server whose natives cannot drive that kind of AI, and never in a
  ranked match. Friendly or AI-filled matches are unranked; a ranked match is raced and
  recorded exactly like a heat of our queue. The registration declares `botFill = true`
  for the street and rooftop races only when their AI racers can drive here.
- **Unranked entries** (`options.ranked == false`: friendly, bot-filled, staff bot mode):
  no best time is written (time trial board, best vs AI), results carry
  `unranked = true` and no reputation, and the HUD says UNRANKED / FRIENDLY.
- **Entering.** `activityEnter` for each racer (the core captures the return point and
  puts the RP weapons aside), then the racer moves into the instance's routing bucket
  (`4200000-4299999`, one per instance, several instances at once). Drivers are seated
  in a loaner car created in that bucket and held on the grid by the replicated frozen
  flag; runners are teleported to the line and frozen until GO. God mode is on for the
  race and restored after.
- **Nothing is handed out.** No Athlete legs, Dash, Overdrive, implant or weapon. Cars
  are loaners, never a personal vehicle, removed at the end. (`race.parkour` alone lends
  two abilities for its race: see *Parkour race*.)
- **Checkpoints** are validated on the server only (100 ms tick, swept cylinder test,
  4 m height tolerance, in order). Drivers who die are out (revived, then returned);
  runners who die are revived at their last checkpoint with the clock running.
- **Results** go to the core through `op77_lightrp:activity:result`: placement, score,
  `won`, `stats` (`mode`, `courseId`, `courseRevision`, `vehicle`, `finished`, `timeMs`,
  `bestLapMs`, `laps`, `checkpoints`, `racers`, `personalBest`, `courseRecord`,
  `dnfReason`, `bots`, `vsAi`) and a proposed `reputation`. Never cash, never items. A
  finisher's result leaves at the line; the others' when the race resolves. A time trial
  reports finished runs only. Placement reputation needs at least two starters (bots
  count). A race the staff switch filled with bots is sent with `test = true` and no
  reputation (see *Bot mode*).
- **Return.** `activityLeave(returnPlayer)`; the core sends the player back and restores
  health and RP weapons. If the core is gone (stopped, or `activityLeave` refused), we
  teleport the racer to where they stood before entering. When the core restarts, the
  activities are registered again.
- **Status** (`op77_lightrp:activity:status`) is sent on change only.

## Player side

| | |
|---|---|
| `/race` | Opens Light RP's Activities panel, where the races are listed and joined |
| `/timetrial [course]` | Start a time trial |
| `/race.join trial\|street\|rooftop\|pve\|parkour [course]` | Join (`pve`, also `ai` / `vsai`: Street Race vs AI) |
| `/race.leave` | Leave the race (forfeit) or the queue |
| `/race.restart` | Time trial: go again |
| `/race.status` | Server state |
| `HOME` | Time trial: restart (rebindable) |
| `END` | Foot race: back to the last checkpoint (rebindable) |

The next checkpoint shows as a native marker (raised chevron for a car, ring and arrow
on foot) and as an edge-pinned blip on `op77_map3d`; in a car, the map3d GPS routes to
it and the player's own waypoint is given back afterwards.

Everything else on screen is Light RP's shared activity HUD (client exports
`ActivityHudShow` / `ActivityHudPush` / `ActivityHudClear` of `op77_lightrp`, see its
README); this resource has no page of its own.

| Moment | In the activity HUD |
|---|---|
| Queued (street, rooftop) | Lobby: queue size, `STARTS IN` once the grid forms (*Bots fill the empty slots* in bot mode), *Leave queue*. Sent by the server (`op77_race:queue`) on change only; the player keeps roaming |
| Loading, countdown | `GET READY`, then the countdown to GO (sound as before) |
| Racing | Count-up clock, checkpoint, lap and course bar; time trial: personal best and record; heat: position, best lap (vs AI on one lap: *Best vs AI*) and the live ranking (checkpoints, finish times, `OUT`), bots listed as `[BOT] <callsign>` |
| Pulses | GO, `LAP n/N` / `FINAL LAP` and `FINISH` banners; each checkpoint's split in the feed |
| Results | `BACK IN` count-down, then the result card once per run: placement (or `DNF`), time, best lap, previous best, record, board rank; vs AI the best vs AI; a staff bot race *Bots: n, test race not recorded* |
| Course editor | Checkpoints, grid, start and laps, the last message, the editor keys |

Hints follow the live key bindings: `HOME` restart (time trial), `END` last checkpoint
(on foot), `/race.leave` to quit. If Light RP is down or still loading its page, the
client retries every second and shows the HUD again once it answers.

## Bot mode

Staff bot mode is op77_lightrp's switch: `/lightrp.bots on|off`, off at every start. We
follow it through the host-wide event `op77_lightrp:activity:bots (enabled)`
(`AddEventHandler`, never a net event) and read it with `activityBots()` after every
successful registration, since the event may fire while we are down. A stopped core
means off.

- **One player is enough.** With bot mode on, a street or rooftop race opens its join
  window for a single queued player, and the launch fills the grid with bots up to
  `bots.fillTo` racers in total (4 by default, within the course's slots). The time
  trial is solo and never gets bots. Switching bot mode off starts no new bot race; a
  race already running finishes with its bots.
- **Street bots** are NPC drivers (`Open77.npcs.create`, invulnerable, no combat, no
  perception, in the race bucket) attached to their own loaner car
  (`Open77.vehicles.ai.attachDriver`) on the free slots behind the players. The car is
  held on the grid by the same frozen flag as the players' until GO, then drives the
  checkpoints with `vehicles.ai.followRoute` (aggressive, 30 m/s, stretches of 24
  checkpoints handed again before they run out; `driveTo` if `followRoute` is missing).
  A driver the platform refuses three times is dropped and the car drives driverless.
- **Rooftop bots** are NPC runners on the foot slots, sent checkpoint to checkpoint with
  `npcs.tasks.moveTo` (sprint, run if refused; `patrol` round the next checkpoints when
  `moveTo` is missing).
- **Same rules as the players.** Bots progress on the server only, through the same
  swept-cylinder test, radius and order (`bots.checkpointRadiusBonus` widens it, 0 by
  default). They are in the ranking, the finish banners and the result card as
  `[BOT] <callsign>`. A bot that finishes first opens the finish window for the
  players; one that finishes rolls (or walks) on past the line.
- **Stuck.** No checkpoint for `bots.stuckSeconds` (20 s): the bot is stopped and given
  its route again; after `bots.maxRetasks` (2) re-tasks without progress it is out
  (DNF) and removed. A failed driving task (`vehicles.ai.on("failed")`, `no_route`) is
  re-tasked at once. The clock pauses while nobody is near enough to simulate the bot
  (`waiting_for_simulator`, or an NPC without an authority client).
- **Nothing is recorded.** Every result of a race the switch filled with bots goes to
  the core with `test = true` and no reputation, even if bot mode was switched off
  while it ran (and the core itself records nothing while bot mode is on). No best time
  is written.
- **Removal.** Bots, their cars and drivers go when the instance closes (results end,
  last player gone, `/race.leave` of the last human, core stopped) and at once on
  `onResourceStop`. They live in the instance's routing bucket only.
- **Missing natives.** Every native is looked up, type-checked and called in `pcall`; a
  missing one is logged once. Without the natives a kind of bot needs, bot mode changes
  nothing for that race (the normal minimum applies, no bots, no lone heat).

## Street Race vs AI

`race.pve` is public: no staff switch. A player alone starts at once; a crew starts
together (see *Crews*). The course is chosen like the time trial's (the Activities
panel's choices, `/race.join pve <course>`, else the last one raced vs AI); only
vehicle courses with at least two grid slots qualify. AI drivers (the street bots
above) fill the grid up to `pve.fillTo` racers in total (6, within the course's slots).

- **Recorded.** Results are normal results (no `test` flag, `stats.vsAi = true`), so the
  core records them as usual (except while staff bot mode is on, when the core records
  nothing). Staff bot mode does not change a race vs AI.
- **Less reputation than racing players**: `pve.rewards` = 6 to finish plus 12/6/3 for
  the podium (a street race pays 10 plus 20/10/5), and none at all for a finish faster
  than `pve.minimumSeconds` (60 s) or on a course shorter than `pve.minimumMetres`
  (1500 m, all laps). The built-in Street Circuit (3460 m) and Shion Sprint (2752 m)
  qualify.
- **Its own best.** Times vs AI never reach the time trial's board: each course keeps a
  separate best vs AI (`records.json`, board `vsai:<courseId>`), shown as *Best vs AI*.
- **No AI on the server** (natives missing): a player alone is refused with a sentence;
  a crew races without AI.
- **Difficulty.** `race.pve` registers as PvE with Light RP's `standard`, `hard` and
  `critical` (`pve.difficulties`); the join's `options.scaling` sets the AI drivers, one
  difficulty per race (a crew's first join). `enemies` scales the AI share of the grid
  (`(fillTo - players) x enemies`, rounded, within the grid: solo 5 / 7 / 7, crew of four
  2 / 3 / 4); `damage` sets their top speed (`30 x (1 + (damage - 1) x 0.8)`: 30 / 36 /
  44.4 m/s); `ai` their profile (`pve.profiles`: veteran turns in earlier, arrival radius
  12 m instead of 8, and validates checkpoints 1.5 m wider). `health` has nothing to
  scale in a race (invulnerable AI, no combat).

## Parkour race

`race.parkour` is `race.foot`'s engine, rules, checkpoints, last-checkpoint key and god
mode on courses marked `parkour`. Everything else about it is in `server/parkour.lua`,
which no other race reaches.

- **Double jump** is a temporary cyberware lease (`Open77.cyberware.lease`, the `legs`
  slot), asked once the runner stands on the line, in the race's bucket: a bucket change
  ends a lease. `current` keeps the paid record throughout. The countdown waits for the
  leases, `parkour.readyWaitSeconds` (8 s) at most.
- **Dash** is a session grant of this resource (`Open77.dash.grant`), given at GO and
  never during the hold: a freeze is documented against locomotion input, not this.
- **Own implants.** A runner with durable legs gets no lease and one with another
  resource's dash (Light RP's Neofiber) no grant: their implant does the work and there
  is nothing to take back. They race with their implant's values, not the race's. The
  manifest has no `players.cyberware.manage`, so this resource cannot install or remove
  anything. If an implant's dash had lapsed when the race granted its own, Light RP's
  10 s check grants it back after the race.
- **Taken back** at the finish, on a DNF (a finisher watching has nothing left), and first
  thing in any release: leave, core drop, character switch, core stopped. A refused
  revoke or release is asked again every second until the platform shows no grant and no
  lease, and a sweep every second catches any exit that did not call it. A disconnect and
  this resource stopping are the platform's: it ends the session's grant and lease, and
  restores even after we stopped. A lease also ends by itself in 5 minutes at most.
- **Mid-race.** What the platform ended (death, the 5-minute ceiling, a bucket change) is
  lent again once the body is alive and the old lease is gone, so the double jump has a
  short gap on a race over 5 minutes.
- **Refused.** Without both definitions on this server, joins are refused with a sentence
  and the status says not joinable. A runner the platform refuses races on, retried every
  second, told once 5 s after GO.
- **Unranked for now**: every result carries `unranked` and no reputation, whatever the
  join says, no best time is written, and the recap shows as usual. Not in `economy.lua`.
- **No bots**: the panel is not offered them, staff bot mode and `options.fill` add none.
- **Courses.** The first choice in the queue (`options.course`, or a match's) sets the
  heat's course, a later different one is told; no choice rotates. A parkour course runs
  in this race only, never in the time trial or `race.foot`, whose lists do not change.
  `rooftop-parkour` is Rooftop Run's route, coordinate for coordinate.

## Staff

- `/race.editor open [courseId|--foot|--parkour]` opens a course editor session (a copy for a
  built-in course). Then `UP` captures the start, `INSERT` a checkpoint, `RIGHT` a grid
  slot, `DOWN` undoes the last checkpoint (all rebindable, inert without a session), or
  `/race.editor start|cp|grid|undo|undogrid|name <text>|laps <n>|type circuit|sprint|parkour on|off|radius <m>|vehicle <id>|vehicles|save|close|list|delete <id>`.
  Points come from the server's position (the car's when driving), in bucket 0.
- `/race.force street|rooftop|parkour` starts a queued race now, even below its minimum (filled
  with bots in bot mode).
- Bot mode itself is op77_lightrp's `/lightrp.bots on|off`; `/race.status` shows it.

## Integration

- Load list: `op77_race` after `op77_lightrp` (and `op77_map3d`, `op77_loadscreen`,
  both optional). Hard dependency: `open77_notifications` only.
- Notices: shown in Light RP's own notice (`exports.op77_lightrp:notice(playerId, { kind,
  title, body, durationMs })`); `open77_notifications` is the fallback when Light RP cannot
  show it (stopped, an older core, its page not up). Light RP answers a join from its panel
  and shows the grid filling or a crew gathering in its queue panel, so there is no "you are
  in the queue" or "waiting for your crew" notice on top; `/race.join` still replies in chat,
  and the staff bot-mode sentence, the grid countdown, refusals and in-race messages stay.
- Permissions: `world.vehicles` (loaner cars, `vehicles.ai`), `world.npcs` (bots),
  `players.dash.define|manage|read` and `players.cyberware.define|read|temporary` (parkour).
- Parkour needs `open77_cyberware`, `open77_dash` and `open77_appearance` (the character
  binding) in the load list; without them only `race.parkour` is refused.
- Activities: `race.trial`, `race.grid`, `race.foot`, `race.pve`, `race.parkour`. A server
  that loads the resource gets the race vs AI and the parkour race too.
- ACL: `command.race.editor` and `command.race.force` for staff (no new command).
- Data (operator state, git-ignored): `data/courses/<id>.json` (saved courses),
  `data/records.json` (time trial best times per course revision, and the best vs AI
  under `vsai:<courseId>`).
- Built-in courses: `server/builtin_courses.lua` (Street Circuit, Shion Sprint,
  Rooftop Run, from Freeroam's authored courses; Rooftop Parkour, Rooftop Run's route).
- Configuration: `shared/config.lua`.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test trial_flow_test.lua
```

`race_shared_test`, `courses_records_test`, `activity_test`, `trial_flow_test`,
`heat_flow_test`, `editor_test`, `client_test`, `bots_test`, `foot_bots_test`,
`pve_test`, `crew_test`, `lobby_test`, `pve_difficulty_test`, `parkour_test`. They run against a fake runtime and a stub of the contract
(`tests/harness.lua`, with fake `Open77.npcs` and `Open77.vehicles.ai` from
`H.installBotNatives()`, fake `Open77.dash` and `Open77.cyberware` from
`H.installAbilityNatives()`), not the game. Run them more than once: `pairs` order changes
from run to run.
