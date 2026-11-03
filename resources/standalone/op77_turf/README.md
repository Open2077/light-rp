# op77_turf: Turf War and Gang Sweep

Two Light RP activities from one resource:

- **`turf.war`** (kind `pvp`), Turf War, described first below;
- **`turf.pve`** (kind `event`), Gang Sweep, its public PvE variant (see "Gang Sweep" below).

Turf War is an instanced king of the hill between the
two gangs with the most players in the queue, fought in a copy of a real district. Each war runs in its own routing
bucket (4400000-4400099, inside our range 4400000-4499999). Light RP takes the fighters in
(`activityEnter`) and brings them back where they were (`activityLeave`).

Nothing of the RP world comes in: no RP weapons, no items, no needs, no cars. There is
no cash and nothing persists, except reputation (through Light RP's `result` event) and the
weekly gang influence table.

## Play

- **Queue**: from The Crossing (hub `join`, with a site choice) or `/turf join [site]`.
  Players keep playing while queued. Once 6 are queued (2 with `/turf.testing on`), a
  45 s lobby counts down (10 s when 24 are queued), then everyone who can go is pulled in.
- **Sides**: side 1 is the gang with the most players in the queue, side 2 the gang with the next most.
  Everyone else (other gangs, no gang) signs on with the smaller side as a **mercenary**. The
  sides never differ by more than one player. A gang's surplus waits in the queue and comes in as
  reinforcements while the war runs, until 3 min before the end. Gangs come from
  `activityPlayer(id).gang`; a player with no gang is unaffiliated. When a single gang queues
  alone, it splits for a training war. A Light RP crew is never split (see "Crews").
- **Zones**: 3 per site. Standing in a zone captures it: 15 s for one attacker, x1.5 with two,
  x2 with three or more. A zone with both sides inside is frozen (contested). An attacker first
  winds back the enemy's half-capture. An empty zone's progress fades.
- **Score**: 1 point per held zone per second, +20 per capture, +3 per kill. The first side to
  900 wins. Otherwise, after 11 min, the higher score wins, then the side holding more zones,
  else it is a draw.
- **Life**: a fighter respawns after 6 s at the held zone nearest to where he fell (if it is
  uncontested and the enemy is not capturing it), else at his side's spawn. A fresh spawn has
  3 s of protection, broken by firing. A fighter who stays out of bounds for 8 s goes back to his spawn.
- **Kits** (engine-native, nothing persists): ASSAULT, BREACHER, MARKSMAN, GUNNER, TECH.
  `K` (rebindable, "Turf War: next kit") or `/turf kit <id>` picks the kit. It is swapped at
  once during the countdown or within 6 s of a spawn, otherwise it takes effect from the next life.
- **End**: the result card shows kills/deaths, captures, time on the zones, reputation, your
  gang's influence and who holds the city this week. Everyone goes home 10 s later.
- **Leaving**: `/turf leave` or the hub's leave is a forfeit for that player (a result with no
  reputation). His side plays on, and a side that empties loses by forfeit.

## Crews

Light RP passes `options.squad = { id, leader, members }` on a join; a crew leader's join
queues every member, each with the same `options.squad`. A crew is one unit:

- **Turf War**: the whole crew goes to the side of the gang most of it belongs to (its other
  members fight as mercenaries). The balance may bench a solo player, never part of a crew;
  a crew that does not fit waits whole. A crew member who joins while his crew fights goes to
  his crew's side, whatever the balance, as long as the war has room. A war made of one crew
  only cannot be fought (a crew is never split for a training war).
- **Gang Sweep**: the crew goes in together (see below).

## Bot mode (staff)

Light RP's staff switch (`/lightrp.bots on|off`, op77_lightrp) turns on **staff bot mode**. This
resource reads it with `activityBots()` after every successful `activityRegister`, and follows
the host-wide event `op77_lightrp:activity:bots(enabled)` (an `AddEventHandler`, never a network
event). While it is on:

- **One fighter is enough.** The lobby opens with one queued player (`/turf.start [site]` too).
  Sides are not balanced against each other: bots even them. A side that nobody of a gang
  holds wears a rival gang's colours (the first of `bots.gangOrder` the other side does not hold).
- **The enemy side is filled with that gang's NPC bots**, and the humans' side gets bot
  teammates (`bots.allies`, needs `Open77.npcs.setAttitude`). Each side is filled up to
  `max(bots.perSide, the larger side's humans)`, at most `bots.maxPerSide` per side and
  `bots.maxBots` in total (teammates are trimmed first). One human: you + 2 bots against 3.
  A human who joins late takes a bot's place on his side.
- **Bots fight with the engine's combat AI**: `aiMode` native, one relationship group per side
  (`op77_turf_<warId>_<side>`, the two set hostile), a per-fighter attitude row (friendly to
  their own side's humans, hostile to the others). The server never scripts movement over a
  fight: it only gives objectives as movement-channel tasks (`tasks.guard` on their zone,
  `tasks.moveTo` towards one), at most one new destination per bot every 6 s and never within
  5 s of a hit that named it. Half of a side's bots push to the enemy's zones, the others guard.
- **Bots count like fighters**: zone presence from their canonical positions
  (`Open77.npcs.presence`, else `get`), captures, kills and deaths on the scoreboard, a respawn
  after the war's 6 s delay. A respawn is a rebuild: the corpse goes after 1.2 s, a fresh body
  is created at the deadline. Bodies are created one at a time (400 ms apart), never in the
  first 5 s after the resource starts, and only in the war's bucket.
- **Damage both ways** (a managed NPC's engine damage is never applied by the platform): the
  client forwards the engine's `open77:npcHit` / `open77:npcAttackedMe` / `open77:npcCrossfire`
  reports, and the server checks them (war running, opposite sides, both up, 150 m, spawn
  protection), clamps them to 34 per hit, bounds them (90 per second per victim) and applies
  them: `Open77.npcs.applyDamage` on a bot, `Open77.players.damage` on a fighter. A fighter's
  death within 10 s of a bot's hit is that bot's kill. Bots are created with
  `behavior.hitPricing = "resource"`, so the platform never prices the same hit too.
- **The HUD** shows the bots on the scoreboard as `[BOT] <name>`, and the side counts include
  them.
- **Nothing counts.** Results go out with `test = true` (the core records none anyway while
  the switch is on), and a war with bots never writes `op77_turf_influence` / `op77_turf_wars`.
  The end card says "not counted (bot war)".
- **Cleanup**: bots are removed when the war ends, when its last human leaves (the war is then
  void), when the core stops and when this resource stops. Bodies a previous run left behind
  (a hot reload) are removed before the first war.

Bot mode off starts no new bot war; a running one keeps its bots until it ends. Without the NPC
API on the build (`Open77.npcs.create` / `remove`), bot mode changes nothing and the log says so.

## Gang Sweep (`turf.pve`)

A public PvE variant, open to every player **without** the staff switch, solo or with a crew:
the humans take a district's zones from the NPC gang holding it. It is registered only when the
platform can make NPCs (`world.npcs`, `Open77.npcs.create`).

- **Join** from The Crossing (`turf.pve`, with a site choice) or `/turf sweep [site]`. A crew's
  members line up together: the sweep starts once every online member is in, or 8 s after the
  first one. A solo player goes in after 1 s. A crew member who joins while his crew's sweep runs
  goes straight in (until 2 min before the end).
- **The holders**: `pve.holders` names each site's gang (Kabuki: Tyger Claws, Badlands: Animals,
  Afterlife: Valentinos; a crew of that gang meets the next of `bots.gangOrder`). They start
  with every zone, standing in them: 3 gangers for one human, +2 per extra human, at most 10.
  A third of them push, the others guard their zone. Same engine AI, tasks, hits and respawns
  as in bot mode.
- **Score**: first to 600, 8 min limit. The holders' zones score at half rate
  (`pve.holderZoneRate`): three zones left untouched reach the target in about 400 s.
- **Up to 2 sweeps at once** (`pve.maxSweeps`, the NPC budget), each in its own bucket, beside
  the turf war. More line-ups wait for a slot; the HUD says so.
- **Results are recorded by the core as usual**, on `turf.pve`, with the war's reputation times
  `pve.reputationScale` (0.6: win 18, draw 11, loss 7, +1 per capture or kill, bonus up to 6).
  To stop farming, nothing is earned unless the sweep lasted 4 min (`pve.rewards.minWarSeconds`),
  the fighter played 3 min, and he captured a zone or eliminated a ganger. **No weekly influence.**
  (While staff bot mode is on, the core drops every result, Gang Sweep included.)
- The HUD title is **GANG SWEEP**; the line-up shows the crew gathering or the wait for a slot.

## Activity lobby (Light RP join options v2)

Both definitions carry `botFill = true` only when bots work on the build (`turf.war`: NPC
create/remove; `turf.pve`: also `setAttitude`, which allies need). `turf.pve` declares
`pve = true` and `difficulties = { "standard", "hard", "critical" }`.

- **Difficulty** (`turf.pve`, `options.difficulty` + `options.scaling`, one per sweep: the first
  join's). Applies to the NPC gang only. Standard / Hard / Critical: gang 3 / 5 / 6 for one human
  (3 x enemies, rounded, +2 per extra human before the multiplier, never above `pve.maxBots` 10),
  health 100 / 150 / 225, a ganger's hit x1 / x1.25 / x1.6 (and the victim's per-second ceiling),
  objective profile `pve.ai.standard` / `veteran` (veteran: half of them push instead of a third,
  new orders every 4 s instead of 6, 3 s combat quiet instead of 5, guard leash +6 m instead of +3).
  The engine's own combat AI (accuracy) has no native on this build. HUD: `GANG SWEEP · HARD`.
- **Allied bots** (`turf.pve`, `options.fill.allies`): push the zones with the crew, friendly to
  every crew member and to each other, no difficulty multiplier. The largest asked by the group,
  applied once, capped to the free seats (8 minus the crew) and to `pve.maxBodies` (14) minus the
  gang. A crew member arriving late takes an ally's seat back. Results stay ranked (PvE).
- **Core matches** (`turf.war`, `options.match`): a war of its own for exactly `match.players`,
  `match.teams` -> sides 1 / 2, `match.bots` per side (else `options.fill` spread over the smaller
  side), capped by `bots.maxPerSide` 6 and `bots.maxBots` 10 (teammates trimmed first). It starts
  when everyone is in, or after `match.gatherSeconds` (15 s); a missing player's seat goes to a
  bot when the match has bots, and he takes it back if he arrives. Strangers never join; the public
  queue waits. **One war at a time**: refused, every player told why, while a public war is queued,
  in its lobby or on, staff scheduled one, or another match holds the slot.
- **Unranked** (`options.ranked = false`, a friendly match, any bots in a match): no influence (not
  even a history row), no reputation, results carry `unranked = true`, HUD/notices say FRIENDLY or
  UNRANKED. A ranked match without bots counts like a public war. Staff bot mode is unchanged
  (results `test = true`).

## HUD (Light RP's design system)

This resource has no page of its own. The client drives Light RP's shared activity HUD through
the `op77_lightrp` **client** exports `ActivityHudShow(hud)`, `ActivityHudPush(kind, payload)`
and `ActivityHudClear()`, always inside `pcall`:

- **phase**: lobby, countdown or running, then ended.
- **timer**: the time left, the countdown, or "home in" at the end.
- **objective**: who you fight for, plus down, out-of-bounds and protection states.
- **stats**: K/D, captures, time on the zones, kit. At the end they show the top 4 gangs of the week.
- **progress**: one bar per zone, with tone success (ours), danger (theirs), accent (contested) or info (neutral).
- **teams**: the two sides with their colours and scores.
- **scoreboard**: up to 16 rows, the player always included.
- **hints**: the kit key.

Feed, banners and the result card go through `ActivityHudPush`. A full HUD is re-sent only
when its content changes (otherwise every 5 s to resync the clock).

If the export is missing (older core), the client reports `op77_turf:hudless` and the server
sends banners and the result as notices instead.

Every message to a player (`TurfWorld.notify`) is **Light RP's own notice**, through its server
export `notice(playerId, { kind, title, body, durationMs })`: same page, same design as the core's.
Only without Light RP (or with a core older than that export) does it fall back to
`open77_notifications`. What Light RP already says is not repeated: no "queued" notice on a join
(the core answers the panel's join, its queue panel shows the line, `/turf join` and
`/turf sweep` reply in chat), none when a match's group gathers (MATCH FOUND + the panel), none
on a `leaveRequest` (the core's answer to the leave).

The zone markers are this resource's own: a ring and a diamond beacon per zone, in the
holder's colour, Light RP yellow `#FFCC00` when contested. So are the op77_map3d blips.

## Staff

| Command | ACL |
|---|---|
| `/turf.schedule <site\|auto> <minutes>` / `cancel`: announced (`op77_lightrp:announce`) at once and at 10/5/2/1 min and 30 s; the lobby opens at the time | `command.turf.schedule` |
| `/turf.start [site]`: close the lobby now with whoever is queued | `command.turf.start` |
| `/turf.stop [all]`: void the war (nothing counts), close the lobby, cancel the schedule; `all` also calls off every Gang Sweep and its line-up | `command.turf.stop` |
| `/turf.testing on\|off`: 2 players start a war, 2 accounts make it count | `command.turf.testing` |
| `/turf.survey [label]`: your position and heading in config syntax | `command.turf.survey` |
| `/turf.status`: queue, lobby, war, zones, fighters, bots, bot mode, sweeps and their line-up, influence | `command.turf.status` |

No new staff command: bot mode is Light RP's `/lightrp.bots`. The player command `/turf` gains
`sweep [site]` (no ACL).

Sites: `kabuki` (Kabuki Market) and `badlands` (Badlands Compound) are offered in the hub.
`afterlife` is staff only (interiors never walked in a war). **Every position is marked
`-- survey in game`.** Walk them with `/turf.survey` before opening the activity.

## Weekly gang influence

The influence is kept in Light RP's database under this resource's prefix. The tables are
created on first use and written only from this resource's threads:

- `op77_turf_influence (week_index, gang)`: points, wars, wins, captures. Upserts are additive.
- `op77_turf_wars`: one row per war (site, gangs, scores, winner, fighters, duration, counted).

Weeks start on Monday at 00:00 UTC.

A war counts when it lasts at least 3 min with at least 4 distinct accounts (2 in testing mode).
A counted war is worth: win 10, draw 5, loss 2, plus 1 per capture made by the gang's own
members, up to 10. Mercenaries earn no influence for anyone.

Synchronous exports (memory only, never the database):

```lua
local list, week = exports.op77_turf:influence(6) -- { { gang, label, color, points, wars, wins, captures }, ... }
local points, rank = exports.op77_turf:influenceOf("valentinos")
```

Without a database, the table lives in memory for the run, and `/turf influence` says so.

## Integration (main session)

- **Load list**: `resources.load` += `op77_turf`, after `op77_lightrp`, `op77_map3d` and `op77_loadscreen`.
  Dependencies are `open77_notifications` and `open77_weapons`. There is no hard dependency on
  `op77_lightrp`: if the core stops, the war is voided, and the resource registers again on
  `op77_lightrp:activity:ready` or on the core's start.
- **ACL**: the six `command.turf.*` entries above, for staff. Nothing new for bot mode or Gang Sweep.
- **Activities**: `turf.pve` (Gang Sweep) is a second activity id of this resource; list it
  wherever the hub or a configuration names activities. Its results arrive on `turf.pve`.
- **Permissions** added: `world.npcs` (the bots) and `players.stats.apply`
  (`Open77.players.damage`, a bot's hit on a fighter).
- **Light RP (`LightRpActivities.buckets`)**: add `{ 4400000, 4499999 }`.

## Natives

Most natives are used by the running distribution: player life, respawn, teleport, freeze,
position and get; `Open77.combat.setTeam` and `onDamage`; `Open77.weapons.*`; markers;
`RegisterKeyMapping`; `SetRoutingBucket*`; `Open77.exports.callSync`.

**`Open77.combat.createScope` / `removeScope` (`combat.scope.control`) are documented in the
base wiki (since op77.63), but no resource in the running distribution uses them.** Light RP's
global PvP is off, so these scopes are what make war damage possible.

The bots use `Open77.npcs.create` (`record` for `Character.*` records, `template` for aliases,
`loadout.combat = { group, acquirePlayers }`, `behavior.hitPricing`), `remove`, `presence`
(else `get`), `all`, `applyDamage`, `applyCrossfireDamage` (when present), `setAttitude`,
`setRelationship`, `tasks.guard` / `moveTo` / `clear` on `channels.movement`, the platform
events `onNpcDied` / `onNpcDamaged` / `onNpcRemoved`, the client events `open77:npcHit` /
`npcAttackedMe` / `npcCrossfire`, and `Open77.players.damage`. Each one is looked up and called
under `pcall`, logged once when missing, and degrades: no `setAttitude` means no bot teammates,
a refused combat loadout means bodies without a group, no `presence` falls back to `get`.
**None of them has been tested in game in this resource.** The gang records of `sixth_street`
and `animals` are unproven; a record no client can build is replaced by the next one after 30 s
without a simulating client.

## Tests

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll C:\Games\cyberm\light-rp\lua54.dll -Test rules_test.lua
```

The other test files are `adapter_test.lua`, `war_test.lua` (the full flows, against a fake
Light RP through the real `server/main.lua`), `influence_test.lua`, `hud_test.lua`,
`bots_test.lua` (staff bot mode), `pve_test.lua` (Gang Sweep and crews) and `lobby_test.lua`
(join options v2: difficulties, allies, core matches, refusals, unranked). The last three share
`tests/bot_host.lua`, a fake Light RP, world and `Open77.npcs`.
