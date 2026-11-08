# Staff events (anim modes)

Staff launch world events wherever they want and chain them into event nights:
**/admin > Events**, or `/lightrp.event` in chat. Everything runs on the world
boss engine (`server/modules/world_bosses.lua`): open world (instance 0), zone HUD,
contribution-based shares (damage and kills validated by the server), enemy leash,
reinforcements at 66% and 33% of the boss's health, map pin and end notice.

Files: `server/modules/staff_events.lua` (the logic, the desk, the command),
`server/config/staff_events.lua` (settings), `ui/src/features/support/EventsTools.tsx`
(the desk pages), tests `tests/staff_events_test.lua` and
`ui/tests/staff-events.browser.cjs`.

## The three types

| Type | What spawns | Settings (`server/config/staff_events.lua`) |
|---|---|---|
| **Cyberpsycho** | A single cyberpsycho (one of the 16 *Psycho Squad* records in `shared/mission_defs.lua`, or random), health ×12, *assault* behavior: it hunts anyone who enters its zone. The displayed name ("Static", "Red Line"…) is drawn from `psycho.names` if the staff member does not give one. | `psycho` |
| **Gang attack** | A gang leader (health ×15) who holds the point, their squad on an 8 m ring, and two reinforcement waves that arrive from the edge of the zone (0.8 × the radius). Seven gangs: 6th Street, Valentinos, Tyger Claws, Maelstrom, Voodoo Boys, Wraiths, Militech. | `gang.crews` |
| **World boss** | A world boss from the catalog (the missions tagged *World boss* in `/lightrp.missions`), at its original place with its decor, or moved. | — |

A **moved** world boss (here, on a player, at a spot) takes a compact layout,
because the decor written for its original place means nothing elsewhere: the boss on the
point, its other starting groups on a 9 m ring, its reinforcements at the edge of the zone,
patrols become *defend* and routes are cleared. It keeps its catalog
ID, so its iconic drops if it is paid. The staff can rename it.

## Where

- **Its own place** (world boss only): the original zone and decor;
- **Here**: a circle around the staff member, refused if they are in an instance;
- **On a player**: around the player's position at launch, refused if they are in
  an instance (mission, activity, interior);
- **Saved spot**: a named point saved in advance (`lightrp_event_spots`, 80 at
  most). Set it up in noclip, save it, reuse it.

The zone radius (25 to 150 m, 50 by default) and the duration (5 to 60 min, 15 by default;
for a world boss, 0 keeps its original duration) are set at launch. The announced place
name comes from the *Place name* field, else from the spot name, else from the district the client
sends (`Open77.world.district()`, a label that is never checked), else "Night City".

## Levels

| Level | Health | Damage | Count |
|---|---|---|---|
| Normal | ×1 | ×1 | ×1 |
| Hard | ×1.6 | ×1.25 | ×1.5 |
| Brutal | ×2.5 | ×1.6 | ×2 |

They apply on top of the event: the cyberpsycho's health, the health and damage of
a gang's enemies, the first difficulty and the guard count of a world boss (the boss
stays alone, a group never goes above 12).

## Paid or for fun

- **Unpaid** (the default, permission `command.lightrp.events`): nothing is paid or counted.
  No money, no reputation, nothing for dailies, titles, contracts or
  iconic drops (`onWorldBossFinished` / `onWorldEventEnded` do not fire). The notices and
  the HUD say "staff event: no pay, just the glory", the recap shows the reason
  `staff_event`.
- **Paid** (permission `command.worldboss.start` as well): exactly one world boss. Pool
  `LightRpEconomy.worldBosses`, daily cap `dailyPaid` shared with random world
  bosses, reputation, hooks.

**Silent**: no notice to the city and no map pin; players stumble upon it. A
silent event is never the "headliner" of the events board.

## Several at once

The world boss engine holds up to `LightRpWorldBosses.maxLive` events at
once (4), the random world boss included. The random one only spawns when no event
is out. The same catalog world boss cannot be out twice at the same time.
Each zone has its own HUD (the tag: WORLD BOSS, CYBERPSYCHO, GANG ATTACK). A staff event
built from scratch (cyberpsycho, gang) does not restart the random clock;
a catalog world boss does.

## Event nights

Rounds announced to the whole city: 30 s before the first, a 60 s break between two,
a summary at the end ("3 of 5 fight(s) won"). Only one at a time.

| Night | How it runs |
|---|---|
| **Psycho Night** | One cyberpsycho per round, at a different spot each time (shuffled), harder and harder. With two or more spots, the last round releases two at the same time. |
| **Boss Rush** | The catalog world bosses one after the other, each at its own place. |
| **Gang War** | A single round: N gangs (2 to `maxLive`) hit N spots at the same time. N saved spots are needed. |
| **Siege** | Gang after gang at the same place, harder and harder; a cyberpsycho leads the last one. |

The level starts at the one chosen and goes up over the rounds (except Gang War and Boss Rush).
A round that cannot spawn (engine full) is retried six times at 10 s intervals,
then skipped. *Stop the night* stops the rounds; the *call off* option also ends the
events still out, without pay.

## The desk: /admin > Events

- **Live now**: the events that are out (boss, place, health, fighters, time left, who
  launched it, paid or not). On an event: *Go to the event* (at the edge of the zone),
  *End it as a win* (paid: shares as for a kill, world boss permission required),
  *Call it off* (nobody is paid).
- **Launch an event**: the configurator (type, boss / cyberpsycho / gang, where, player or
  spot, level, duration, radius, pay, silent), a summary of what will happen and what is
  blocking, then *Review and launch*: place name, boss name, note, confirmation.
- **Event nights**: the choice of night, rounds (or gangs), place, starting
  level, pay; the state of the night in progress.
- **Saved spots**: save your position, go to a spot, launch at a spot, delete.
- **Random world bosses** (world boss permission): turn the random boss off or back on until the
  next restart, and *Next random boss now*.

Every action is written to `lightrp_staff_audit` before it runs, under the page's
mutation key: a replayed request returns the first answer, with no second
launch. Actions: `eventLaunch`, `eventStop`, `eventWin`, `eventGoto`, `eventNight`,
`eventNightStop`, `eventSpotSave`, `eventSpotDelete`, `eventRandom`, `eventNext`.

## /lightrp.event

For speed from chat; always here, unpaid, announced:

```text
/lightrp.event psycho [psycho_id|random] [normal|hard|brutal]
/lightrp.event gang [sixthstreet|valentinos|...|random] [level]
/lightrp.event boss <title> [here] [level]       (without here: at its own spot)
/lightrp.event night <psycho_night|boss_rush|gang_war|siege> [rounds] [here]
/lightrp.event stopnight
/lightrp.event stop [all]                         (all: the random ones too)
/lightrp.event list
```

`/worldboss.list` and `/worldboss.stop [win] [all]` also see every event.

## Permissions

| Permission | Access |
|---|---|
| `command.lightrp.events` | Events desk, unpaid events, spots, unpaid nights (moderator / operator through `command.lightrp.*`) |
| `command.worldboss.start` | In addition: paid events and nights, winning a paid event, random world bosses (operator through `command.worldboss.*`) |
| `command.lightrp.event` | The `/lightrp.event` command (through `command.lightrp.*`) |

## To validate in game

Tested outside the game (`tests/staff_events_test.lua`, `ui/tests/staff-events.browser.cjs`).
Not yet seen in game:

- a "here" cyberpsycho and an "on a player" gang appear in the right place,
  projected onto the navmesh, and hunt;
- a world boss moved into the city, reinforcements included;
- two events at once, each with its own HUD;
- a two-round Psycho Night, with its announcements.
