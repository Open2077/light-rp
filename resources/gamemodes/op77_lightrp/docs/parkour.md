# Parkour

Courses built by the staff: a start orb, 0 to 50 checkpoints, a finish orb. A runner goes
from the start to the finish through every checkpoint, in order, against the clock. Every
course has its own full leaderboard, with each runner's splits.

| Piece | Where |
|---|---|
| Contract (limits, validation, orb geometry, time format) | `shared/parkour.lua` (`LightRpParkour`), mirrored by `ui/src/features/parkour/model.ts` |
| Storage, start points, runs, leaderboards, Activities panel, staff editor protocol | `server/modules/parkour.lua` |
| Points (ring + light column), hold, bearing, keys, sounds, GPS | `client/core/parkour.lua` |
| Staff editor: relay, captures, 3D preview, build mode | `client/core/parkour_editor.lua` |
| Run HUD, countdown, result / DNF cards, music | `ui/src/features/parkour/ParkourHud.tsx`, `music.ts` |
| F1 > Parkour (course list, card, leaderboard) | `ui/src/features/parkour/ParkourBrowser.tsx` |
| Staff editor (RageMenu + build bar) | `ui/src/features/parkour/ParkourEditor.tsx` |
| Music | `ui/public/audio/parkour-rooftop-momentum.webm` (Opus, from "Rooftop Momentum") |
| Tests | `tests/parkour_test.lua` (server), `tests/parkour_client_test.lua` (client) |
| Mock | `?parkour=hud|count|go|result|record|dnf|browser|editor[&build=1]&registered=1` |

## What a player sees

- **The points: simple and still.** Each point is a ring standing across the line, sized
  to its trigger (what you see is what counts: you run through it), and a thin light
  column fading into the sky to find it from far away.
  - colours: the checkpoint to reach in gold, the finish in green, a start in cyan (its
    ring standing on the ground, facing the course);
  - a crossed checkpoint simply goes, with a burst and a sound, and the next one appears.
  - **Never update a marker after creating it.** An update while it is still loading
    restarts its spawn (client `Markers.cpp`, `stage != Ready`). A first animated version
    (#130: rising gates, turning diamonds, sliding chevrons, 20 updates a second) made
    the points vanish and come back all the time.
  - Budget: markers are 64 per resource, shared with every LightRP point. The interaction
    markers only exist near the player (`interact.lua` streamMarker, #132). The parkour
    leaves 10 free and logs any shortfall or refusal.
- **Starts.** The 3 nearest published starts within 160 m are drawn. The map shows a blip
  per course (category `parkour`, routable). At the start, **E** opens the course card
  (never offered during a run).
- **F1 > Parkour** (or `/parkour`) lists every course:
  - sorting: nearest, most run, A–Z;
  - for each course: its record, your best, its length and checkpoints;
  - the selected course: description, author, stats, and the **whole leaderboard**, in pages
    of 50. A row opens its splits against the record. Your own row is pinned when it is off
    the page.
  - **START RUN** works from anywhere. The activity core captures where you stood and brings
    you back there at the end. **GPS** routes to the start.
- **The Activities panel** lists *Parkour* (kind race), with up to 8 courses as join
  choices (the most finished first).
- **A run:**
  - **Start.** You are placed on the start, facing the course, held for 3-2-1, then GO.
    - The server freezes the runner. This needs `players.life.freeze` in the manifest;
      without it the freeze was refused (`permission_denied`) and runners walked during
      the countdown until 2026-11-06.
    - The client also holds its own body (`Open77.character.setFrozen`).
    - Both are applied again every 200 ms and released at GO.
    - A runner who still walks off the start is put back.
    - God mode is on, and the core puts the RP weapons aside and freezes the needs.
  - **GO** stays on screen about a second after the start.
  - **The bearing**, under the checkpoint pips:
    - an arrow turned toward the next point from the camera, so an off-screen checkpoint is
      found at once;
    - its name (CP n or FINISH), the distance, and the climb or drop (above 2 m).
  - **The HUD:**
    - a big clock and the checkpoint count;
    - your personal best and the record, and a pip per checkpoint (green ahead, red behind);
    - a delta flash at each checkpoint, against your personal best (else the record);
    - the splits on the right.
  - **Keys** (rebindable): **HOME** restarts, **END** returns to the last checkpoint with the
    clock running, **DELETE** (or `/parkour.leave`) leaves. F1 stays the player menu.
  - **Finish.** The result card shows the time, NEW PERSONAL BEST or COURSE RECORD, your
    rank out of all runners, each split against your previous best, and the top 5. It takes the
    cursor: **RUN AGAIN**, **LEADERBOARD**, **LEAVE** buttons (Enter / Escape). After 25 s you are sent back. A new record is announced to the city.
  - **DNF** in these cases: the time limit; a sample faster than 42 m/s (a vehicle); a jump
    of more than 45 m outside our own teleports.
  - **Death** sends you back to the last checkpoint, clock running.
  - **Fall line** (optional, rooftop courses): drop below it and you go back to the last
    checkpoint, clock running.
- **Music.** "Rooftop Momentum" plays from the page (WebUI audio) at **5 %** from the
  countdown. It loops through restarts and fades out when the run ends.

## Timing (server only)

The server samples each runner's position every 50 ms. It tests the segment between two
samples against the next orb's sphere: the body centre (feet + 1 m) against the orb centre
(the placed point + 1 m), radius = the orb's radius. The crossing time is interpolated
along the segment, so a split does not depend on the sample rate. The checkpoints count in
order; several crossed in one segment all count. The client never reports a crossing.

## Leaderboards

- `lightrp_parkour_times` keeps each character's **best** time per course revision, with its
  splits (`"ms,ms,..."`), the number of finishes and the date.
- The first 500 of each board are cached in memory. A rank beyond them is read from SQL.
- **Revisions.** Moving, adding or removing an orb, changing a radius or the fall line is a
  new revision, so a fresh board starts. Renaming, the description, the difficulty and the
  time limit keep the board. Staff can also reset a board. Old times stay in the database.
- Every finished run is also reported to the activity core
  (`stats.courseId/courseRevision/timeMs`): stats and the Hall of Fame. No pay: `parkour.run`
  is not in `LightRpEconomy.activities`.

## Staff editor

ACL `command.lightrp.parkour` (staff hold `command.lightrp.*`). Open it with
`/lightrp.parkour`.

**The menu** (RageMenu, the keyboard of /admin and the mission editor):
- **New course here.** The start goes at your feet, facing where you face.
- **Course fields:** name, description, difficulty (a label only).
- **Start orb and finish orb:** at my feet (F11), where I aim (F10), radius, the start's
  facing.
- **Checkpoints:** add at my feet / where I aim, the new checkpoints' radius. For each
  checkpoint: move it, radius, move it earlier or later, insert one before it, remove it.
- **Rules:** time limit (0 = none; every run still stops at 30 min), fall line on or off,
  its height, "2 m under my feet".
- **Actions:**
  - **Test run:** the draft as it is now, recorded nowhere.
  - **Publish / Save:** the start orb goes live.
  - **Save as a draft:** hidden from players.
  - **Go to the start.**
  - **Reset the leaderboard.**
  - **Delete.**

**Build mode** (F9):

| Key | Action |
|---|---|
| Aim | A ghost of the tool's orb follows the crosshair. The draft is drawn in debug lines: every orb's trigger sphere, the route, the fall line in red. |
| LEFT CLICK | Place: add a checkpoint, move the start or the finish. With the Move tool: pick up an orb, then drop it. |
| RIGHT CLICK | Open the aimed orb in the menu. |
| DELETE | Remove the aimed checkpoint. |
| UP / DOWN | Change the tool. |
| LEFT / RIGHT | Turn the start's facing. |
| F9 | Back to the menu. |

Attack, melee and grenades are blocked while building.

**Validation** (server, the same in the page):
- a name of 3 to 40 characters;
- radius 1 to 12 m;
- 50 checkpoints at most;
- consecutive orbs at least 2 m apart;
- a route of 15 m to 20 km;
- a fall line below the start.

## Wire

| Event | Direction | Payload |
|---|---|---|
| `op77_lightrp:parkour` | server -> client | `courses`, `run`, `countdown`, `go`, `cp`, `finish`, `result`, `dnf`, `respawn`, `ended`, `board`, `close` |
| `op77_lightrp:parkour:key` | client -> server | `{ op = "restart" \| "checkpoint" \| "leave" }` |
| `op77_lightrp:parkour:editor` | both ways | request / response: `list`, `save`, `status`, `delete`, `reset`, `test`, `goto` (idempotent per `mutation`) |
| `lightrp:ui:parkour` | Lua -> page | the server events above. The page sends `{ op = "leave" \| "restart" }` |
| `lightrp:ui:parkoureditor` | page <-> Lua | `preview`, `input`, `capture`, `close`, anything else forwarded to the server |

Page actions: `parkour.open`, `parkour.board`, `parkour.start`, and `parkour.gps` (handled
in the client).
