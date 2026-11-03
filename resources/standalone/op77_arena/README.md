# op77_arena

Arena activities for Light RP, provided through the Light RP activity contract
(`op77_lightrp`). The engine is the Deathmatch PvP engine as Freeroam ships it (dist
2.50.0+op77.177). It stays close to upstream; `server/lightrp.lua` plugs it into the
contract through the seams the engine resolves at call time.

| Activity | Id | Players | What |
|---|---|---|---|
| Combat Zone | `arena.ffa` | 1-16 | Drop-in free-for-all, arena weapons, respawn on death |
| Blade Night | `arena.blade` | 1-16 | Melee free-for-all (katanas, knives, blunts) |
| Combat Zone · PvE | `arena.pve` | 1-6 | Players together against the engine's bots, no friendly fire |
| Duel | `arena.duel` | 2 | One on one, best of three |
| Team Arena | `arena.teams` | 4-6 | 2v2 or 3v3, best of three, elimination rounds |

## How it works

- **Admission.** Light RP's Activities panel sends `op77_lightrp:activity:join`. Our
  commands call `activityCheck` first. `activityEnter` runs at the first placement into
  an instance. The fight runs in the arena buckets: `4100000` Combat Zone, `4100001`
  Blade Night, `4100002` PvE, and `4100100-4100199` for duels and team matches.
- **Return.** We strip the arena weapons, stand a downed player up, then call
  `activityLeave`. Light RP brings the player back (bucket, health, RP weapons).
- **Results** go out through `op77_lightrp:activity:result`, one per FFA round and one
  per arena match. They carry a proposed reputation, never cash or items.
- **The HUD** is Light RP's shared activity HUD (`ActivityHudShow`, `ActivityHudPush`,
  `ActivityHudClear`). This resource has no page of its own.

## Player commands

| | |
|---|---|
| `/arena` | Help |
| `/arena.ffa` | Join the Combat Zone |
| `/arena.blade` | Join Blade Night |
| `/arena.pve` | Join the PvE Combat Zone |
| `/arena.queue 2v2\|3v3` | Queue for Team Arena |
| `/duel <id>` | Challenge a player within 15 m. Also `accept`, `decline`, `cancel` |
| `/duel random` | Random duel queue |
| `/duel bot` | Best-of-three duel against a bot (staff bot mode only) |
| `/arena.weapon`, `/arena.kit` | Combat Zone weapon, team kits |
| `/arena.leave` | Leave the arena, a queue or a duel request |

A command is one person's request: no crew comes along. To bring a crew, join from the
Activities panel.

## Staff

| | |
|---|---|
| `/lightrp.bots on\|off` | **Bot mode**. This command belongs to `op77_lightrp`, not to this resource |
| `/arena.night start [minutes]\|stop` | Arena Night: special Combat Zone rules, announced through Light RP |
| `/dm.*` | The engine's own staff commands (`/dm.bot`, `/dm.instances`, ...), unchanged |

This resource adds no new restricted command. `/arena.pve` and `/duel bot` are player
commands, and `/duel bot` refuses unless bot mode is on.

## Bot mode

Staff bot mode lets one person start what normally needs several. The engine's own
bots fill the missing places (`server/bots.lua`: Cyberpunk's native combat AI, no
scripted movement or targeting on top).

- **The switch** is `op77_lightrp`'s `/lightrp.bots on|off`. It is off at every server
  start. We follow it two ways:
  - the host-wide event `op77_lightrp:activity:bots (enabled)`, handled with
    `AddEventHandler` only, never as a net event;
  - `activityBots()`, read after every successful `activityRegister`, so a switch
    flipped while either resource restarted is not missed.
- **Combat Zone and Blade Night.** A round starts with one person. Bots fill it up to
  `bots.fillTarget` bodies (people plus bots, 6 by default). Spawns are paced by the
  engine: a 5 s settling delay, then one bot every 400 ms. As people join, the bot
  count shrinks at the next round start. Blade Night bots keep their guns, because no
  melee bot exists.
- **Team Arena.** A queued player is matched at once (`bots.teamWaitMs`, 0 by default).
  Bots fill each side's missing slots. A solo player in 3v3 gets 2 bot teammates
  against 3 bots.
- **Sides.** A bot never aims at its own side, human or bot. The engine is told who
  the teammates are:
  - one combat group per side (`Open77.npcs.setGroup`, `op77_arena.i<instance>.s<side>`):
    bots of one side are allies, the other side's bots stay enemies;
  - a friendly row towards each person of the bot's side
    (`Open77.npcs.setAttitude(npc, "friendly", { towards = player })`). The other
    side's people get no row and stay targets.

  The side is the arena's (`Arena.sideOf`, the answer the damage gates use). It is
  checked every `bots.combat.sideSyncMs` (1 s) and at once for a new body, so it holds
  after a respawn, across the halftime swap, and when a person changes side or leaves.
  Team Arena, duels against a bot and PvE are covered; PvE bots share one side and no
  longer shoot each other. Free-for-all bots (Combat Zone, Blade Night, Arena Night)
  state nothing. The server still refuses teammate damage (`friendly_bot`,
  `incoming_friendly_bot`, `crossfire_same_side`). `/dm.bot list` shows
  `team=<group>+<friendly rows>`.
- **Duels.** `/duel bot` starts a best of three against one bot. In bot mode, the
  random duel queue also falls back to a bot after `bots.duelWaitMs` (0 by default).
- **Marker.** Every bot name carries `[BOT] ` (`bots.prefix`) in the scoreboard, the
  team panels, the kill feed and the round winner. A round with bots shows a
  `Practice: not recorded` hint. The Activities panel adds `· bot practice, not recorded`.
- **Nothing is recorded.** While bot mode is on, and for any round or match that had a
  bot:
  - results go out with `test = true` and reputation 0, so Light RP skips them;
  - `Deathmatch.ranked.recordRound` is refused, so no `op77_arena_career`,
    `_rounds` or `_rating` row is written.
- **Switching off** starts no new bot-filled round, and spawns still on their way are
  dropped. Bots already in a round stay until that round ends. Bots already in a
  duel or team match stay until the match ends.
- **Cleanup.** Bots live only in their round's bucket. They are removed:
  - when the last person leaves the instance;
  - at round end once their round no longer needs them;
  - when a duel or team instance closes;
  - on resource stop, pending spawns first.

## Crews

Light RP passes `options.squad = { id, leader, members }`, and a crew leader's join
queues every member. A crew is never split:

- **Combat Zone, Blade Night, PvE.** There is one instance each, so the crew shares it.
  The crew is admitted only if the instance has room for all of it; otherwise it is
  refused with the number of places left.
- **Team Arena.** The crew plays on one side. The queue holds a crew for up to
  `crews.gatherMs` (4 s) while its members arrive. A crew larger than one side is
  refused with a hint: "Queue 3v3 together", or "Play the Combat Zone or PvE together".
  The rest of the queue keeps arrival order. When that order cannot fill a match, the
  biggest groups go first. In bot mode, bots complete whatever side the crew leaves short.
- **Duels.** The random queue never pairs two members of one crew.

The engine hook is `Arena.planRoster(format, queue, capacity)` in `server/arena.lua`.
`Arena.tryForm` calls it and validates the plan: every id queued, no duplicates, sides 1
or 2, no side over capacity. An invalid plan falls back to the stock rule.

## PvE Combat Zone (`arena.pve`)

The PvE Combat Zone is open to everyone, solo or with a crew. It needs no staff switch.

- The players are one side and the engine's bots the other:
  - `Open77.combat.setTeam` puts the players on team 1, so they cannot hurt each other;
  - the engine's server damage gate refuses player-on-player hits;
  - bots never target or damage each other at the server.
- The bot count scales with the players: `pve.botsFirst` (3) for the first player, plus
  `pve.botsPerPlayer` (2) for each further one, capped at `pve.botsMax` (10). Up to
  `pve.maxPlayers` (6) people.
- **Recorded normally**, at lower reputation (`reputation.pve`, about 60 % of PvP): 18
  for a win and 3 for a loss. Reputation only counts for a player who fought at least
  `minRoundMs` (2 min) of the round, so short rounds cannot be farmed. The players win
  when they killed more bots than the bots killed players. Placement is 1 for a win and
  2 for a loss, and stats include `teamKills`, `botKills`, `players` and `bots`.
- **No Elo and no rating:** `recordRound` refuses the `pve` ruleset.
- The HUD shows `Players` against `[BOT] Gangs` with kill totals, and the result card
  says `PLAYERS WIN` or `BOTS WIN`.
- Staff bot mode does not change PvE. It fills the PvP activities only.

## Player damage: one combat scope per PvP instance (`server/pvp.lua`)

Global PvP is off on Light RP, and it stays off: the platform refuses every
player-to-player hit with `friendly_fire_disabled`. Freeroam hosts this engine with
friendly fire switched on for the whole host; this edition never calls
`Open77.combat.setFriendlyFire(true)`, which would open PvP in every street. Instead,
each PvP instance (Combat Zone, Blade Night, Arena Night, duels, Team Arena) gets an
`Open77.combat.createScope` over the people fighting in its bucket, the way `op77_turf`
does for a war (permission `combat.scope.control`). Bots are NPCs and never in a scope.

- **Who is in it.** The humans attached to the instance whose life record is in its
  bucket and who are alive or recovering. A death does not drop anyone, so the scope
  survives free-for-all respawns and team-round eliminations.
- **When it changes.** Checked every 500 ms. A join, a departure, a bucket change, a
  respawn after a rebuild, or any attach/detach rebuilds it (the platform has no "add a
  player": remove, then create). Under two people the instance has no scope. Every
  `pvp.refreshMs` (15 s) it is rebuilt anyway, to heal a removal this file could not see.
- **When it goes.** At the instance's close (`Deathmatch.onInstanceClosed`, chained),
  when fewer than two people are left, and for all of them on resource stop.
- **Teams.** The platform still applies teams inside a scope. Team Arena sides and duel
  corners are `Open77.combat.setTeam` 1 and 2 from each round start, so teammates cannot
  hurt each other. A leaver and every member at dissolve go back to team 0.
- **The 8-scope budget.** The platform allows 8 scopes per resource. Every open Combat
  Zone or Blade Night instance holds a slot, and so does every match with two people or
  more. A PvP instance beyond the budget is not opened: `Deathmatch.instances.open`
  answers `nil, "pvp_scope_limit"`, logged once per streak. The joiner is told the arena
  is full, a team queue keeps waiting, and a duel "could not start". PvE never counts.
- **32 players.** A scope holds 32 people at most, so a PvP instance's capacity is
  clamped to 32. A larger roster would get the first 32 by arrival, logged once.
- **Refusals.** A creation the platform refuses is logged once per instance and reason,
  retried every `pvp.retryMs`, and, if it lasts `pvp.tellAfterMs`, told to the
  instance's players (`NO PVP`). A match never runs silently without player damage.
- **Second lock.** `main.lua`'s damage arbiter is unchanged. It still vetoes a
  cross-instance hit, a hit outside an active round, the wrong weapon in Blade Night,
  a teammate, and a spawn-shielded victim.
- **Logs.** One line per instance when its scope opens (`pvp: instance N (format)
  bucket B: PvP scope opened for K players (...)`), when it is refused or restored, and
  when it closes. `/dm.instances` and `deathmatch.status` end with the scopes in use.
- **Time to kill.** The engine's host-global multipliers (`Config.combat`: damage 0.55,
  headshot 2.0) are Freeroam's and are not applied, because they would change PvP damage
  everywhere on the host. `pvp.damageMultiplier` and `pvp.headshotMultiplier` scale
  person-on-person hits inside PvP instances only. Both are 1.0: Light RP fighters keep
  their armor and implants in the arena, so Freeroam's 0.55 would roughly double the
  time to kill. At 1.0 no damage arbiter is installed.

## Configuration (`shared/lightrp.lua`)

| Key | Default | |
|---|---|---|
| `bots.fillTarget` | 6 | Bodies (people plus bots) a bot-mode FFA round aims for |
| `bots.ffa` / `.blade` / `.teams` / `.duel` | true | Which activities bot mode fills |
| `bots.teamWaitMs` / `.duelWaitMs` | 0 | Wait for real people before bots step in |
| `bots.profile` | nil | Engine difficulty (`relaxed`, `standard`, `veteran`); nil = engine default |
| `bots.prefix` | `"[BOT] "` | Name marker |
| `pve.maxPlayers` | 6 | People per PvE round |
| `pve.botsFirst` / `.botsPerPlayer` / `.botsMax` | 3 / 2 / 10 | PvE bot scaling |
| `pve.profile` | nil | PvE bot difficulty |
| `reputation.pve` | 18 / 3, 120000 ms | Win, loss, minimum time in the round |
| `crews.gatherMs` | 4000 | Team queue wait for a crew's members |
| `allowBots` | false | Outside bot mode, never fill a match with bots |
| `pvp.scopesPerResource` | 8 | PvP instances open at once (never above the platform's 8) |
| `pvp.maxScopePlayers` | 32 | People per scope and per PvP instance (never above 32) |
| `pvp.refreshMs` | 15000 | Periodic scope rebuild |
| `pvp.retryMs` / `.tellAfterMs` | 2000 / 10000 | Retry a refused scope; tell the players after this long |
| `pvp.damageMultiplier` / `.headshotMultiplier` | 1.0 / 1.0 | Person-on-person damage inside PvP instances only |

## Engine hooks added by this edition

Kept small, and each one is a no-op unless the adapter uses it:

- `server/instances.lua`: the `pve` ruleset, a free-for-all with its own bucket, as
  Blade Night has.
- `server/arena.lua`: `Arena.planRoster`, consulted by `Arena.tryForm`.
- `server/bots.lua`: `DeathmatchBots.dropPending`. Bots seeking a target skip bots on
  their own side.
- `server/main.lua`: the side damage gate also runs for the `pve` ruleset. The upstream
  `applyCombatPolicy` (host-global friendly fire and multipliers) is removed; it was
  never called here.
- `server/ranked.lua`: `recordRound` refuses the `pve` ruleset.
- `shared/lightrp.lua`: `Config.combat.friendlyFire = false`.
- `server/pvp.lua` (loaded last) wraps `Deathmatch.instances.open` (the budget gate and
  the 32 cap), `.attach` / `.detach` (mark a rebuild), `.describe` (scopes in the
  readout) and chains `Deathmatch.onInstanceClosed` (release).

## Tests

From this folder, with Light RP's Lua 5.4 DLL:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test <file>
```

| File | Covers |
|---|---|
| `adapter_test.lua` | Admission, entry, moves, the way home, duels, results, statuses, Arena Night |
| `core_test.lua` | The contract calls (`ArenaCore`) |
| `engine_load_test.lua` | The real engine loads under the manifest; seams and hooks in place |
| `hud_test.lua` | HUD shape, limits, feed, `[BOT]` marker, PvE teams and result |
| `upstream_test.lua` | The engine's own tests from base, with this edition's geometry |
| `bots_test.lua` | Bot-mode switch (event and `activityBots`), solo FFA with bots, team fill, duel vs bot, no DB write with bots, cleanup, PvE, crews |
| `bots_engine_test.lua` | The real `Arena.tryForm` with crews and bot fill, the bad-plan fallback, duel vs bot, the PvE damage gate |
| `bot_sides_test.lua` | The real `bots.lua`: a combat group per side and friendly rows to same-side people (after the loadout), scripted targets and seek skipping teammates, rebuilt bodies, the halftime swap, a side change, a leaver, match end, free-for-all untouched, missing natives |
| `pvp_test.lua` | PvP scopes against a simulated platform: none for one person, created at two, rebuilt on join and leave, kept through a death, duel and Team Arena (teams set and cleared), PvE without a scope, the 8-slot budget, refusals, the 32 cap, removal on close and stop, the damage scale, no `setFriendlyFire` anywhere |
