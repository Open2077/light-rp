# op77_race

Races for Light RP, provided as activities of the Light RP activity contract
(`op77_lightrp`). The engine is Freeroam's race engine, ported and cut loose from
Freeroam:

| Activity | Id | Players | What |
|---|---|---|---|
| Time Trial | `race.trial` | 1 | Solo against the clock on any course; best times per course |
| Street Race | `race.grid` | 2-8 | A grid of identical loaner cars |
| Rooftop Race | `race.foot` | 2-8 | On foot across the rooftops |

## How it works

- **Admission.** Races are joined from Light RP's Activities panel (`/race` opens it):
  the hub sends `op77_lightrp:activity:join`. The time trial registers its courses as
  join choices (`modes`, at most 8, `modeKey = "course"`, registered again when a
  course is saved or deleted), handed back as `options.course`. Our own entry points
  (`/timetrial`, `/race.join`) call `activityCheck` first. A time trial starts at once. Street and rooftop races queue: once the minimum is waiting, a
  join window opens (30 s / 25 s, 5 s when full), then every queued player is checked
  again and the race starts with as many as the course takes.
- **Entering.** `activityEnter` for each racer (the core captures the return point and
  puts the RP weapons aside), then the racer moves into the instance's routing bucket
  (`4200000-4299999`, one per instance, several instances at once). Drivers are seated
  in a loaner car created in that bucket and held on the grid by the replicated frozen
  flag; runners are teleported to the line and frozen until GO. God mode is on for the
  race and restored after.
- **Nothing is handed out.** No Athlete legs, Dash, Overdrive, implant or weapon. Cars
  are loaners, never a personal vehicle, removed at the end.
- **Checkpoints** are validated on the server only (100 ms tick, swept cylinder test,
  4 m height tolerance, in order). Drivers who die are out (revived, then returned);
  runners who die are revived at their last checkpoint with the clock running.
- **Results** go to the core through `op77_lightrp:activity:result`: placement, score,
  `won`, `stats` (`mode`, `courseId`, `courseRevision`, `vehicle`, `finished`, `timeMs`,
  `bestLapMs`, `laps`, `checkpoints`, `racers`, `personalBest`, `courseRecord`,
  `dnfReason`) and a proposed `reputation`. Never cash, never items. A finisher's result
  leaves at the line; the others' when the race resolves. A time trial reports finished
  runs only. Placement reputation needs at least two starters.
- **Return.** `activityLeave(returnPlayer)`; the core sends the player back and restores
  health and RP weapons. If the core is gone (stopped, or `activityLeave` refused), we
  teleport the racer to where they stood before entering. When the core restarts, the
  activities are registered again.
- **Status** (`op77_lightrp:activity:status`) is sent on change only.

## Player side

| | |
|---|---|
| `/race` | Opens Light RP's Activities panel, where the three races are listed and joined |
| `/timetrial [course]` | Start a time trial |
| `/race.join trial\|street\|rooftop [course]` | Join |
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
| Queued (street, rooftop) | Lobby: queue size, `STARTS IN` once the grid forms, *Leave queue*. Sent by the server (`op77_race:queue`) on change only; the player keeps roaming |
| Loading, countdown | `GET READY`, then the countdown to GO (sound as before) |
| Racing | Count-up clock, checkpoint, lap and course bar; time trial: personal best and record; heat: position, best lap and the live ranking (checkpoints, finish times, `OUT`) |
| Pulses | GO, `LAP n/N` / `FINAL LAP` and `FINISH` banners; each checkpoint's split in the feed |
| Results | `BACK IN` count-down, then the result card once per run: placement (or `DNF`), time, best lap, previous best, record, board rank |
| Course editor | Checkpoints, grid, start and laps, the last message, the editor keys |

Hints follow the live key bindings: `HOME` restart (time trial), `END` last checkpoint
(on foot), `/race.leave` to quit. If Light RP is down or still loading its page, the
client retries every second and shows the HUD again once it answers.

## Staff

- `/race.editor open [courseId|--foot]` opens a course editor session (a copy for a
  built-in course). Then `UP` captures the start, `INSERT` a checkpoint, `RIGHT` a grid
  slot, `DOWN` undoes the last checkpoint (all rebindable, inert without a session), or
  `/race.editor start|cp|grid|undo|undogrid|name <text>|laps <n>|type circuit|sprint|radius <m>|vehicle <id>|vehicles|save|close|list|delete <id>`.
  Points come from the server's position (the car's when driving), in bucket 0.
- `/race.force street|rooftop` starts a queued race now, even below its minimum.

## Integration

- Load list: `op77_race` after `op77_lightrp` (and `op77_map3d`, `op77_loadscreen`,
  both optional). Hard dependency: `open77_notifications` only.
- ACL: `command.race.editor` and `command.race.force` for staff.
- Data (operator state, git-ignored): `data/courses/<id>.json` (saved courses),
  `data/records.json` (time trial best times, per course revision).
- Built-in courses: `server/builtin_courses.lua` (Street Circuit, Shion Sprint,
  Rooftop Run, from Freeroam's authored courses).
- Configuration: `shared/config.lua`.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test trial_flow_test.lua
```

`race_shared_test`, `courses_records_test`, `activity_test`, `trial_flow_test`,
`heat_flow_test`, `editor_test`, `client_test`. They run against a fake runtime and a
stub of the contract (`tests/harness.lua`), not the game.
