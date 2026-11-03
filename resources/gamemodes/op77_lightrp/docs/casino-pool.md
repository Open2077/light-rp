# Pool table

A placeable 9 ft pool table (`pool_table`, kind `pool`, title "Pool") built on
the tabletop-extra plug-in contract. 8-ball for two players (1v1) or solo
practice for the table's owner. No money is involved.

```text
/lightrp.giveitem me pool_table 1
```

Use the item to place it (free mode, it stands on the floor: `floor=0`), E or
the ALT menu's *Sit* to take a seat. Backspace or *Leave table* leaves.

## Playing

Everything is played on the cloth, in free mode (the character keeps walking
and looking around):

- **Aim**: the seated player whose shot it is points the crosshair at the
  cloth. The cue turns about the cue ball towards that point, a cyan guide runs
  from the cue ball to the first ball or cushion on that line, with the ghost
  ball at the contact and a magenta line where that object ball would go.
- **Shoot**: hold the left button to charge (the cue draws back; the power
  swings from 0 to full in 1.6 s, then back down, so holding longer is not
  always harder), release to shoot. Holding ALT (or opening the menu) during a
  charge cancels it: no shot.
- **Ball in hand**: after a foul the incoming player places the cue ball: it
  follows the crosshair on the cloth (never onto another ball), a click puts
  it down, then aim and shoot as usual.

The ALT menu on the table holds the rest (`client/core/table_menu.lua`):

| Row | Who | When |
| --- | --- | --- |
| Status (*Your shot · solids*, *Opponent's shot · open table*, *Balls rolling*, *You win*, *Practice*...) | seated | always; selecting it explains the state (balls left per group) |
| *Mode: 1v1 ›* Solo practice / *Mode: Solo practice ›* 1v1 | owner | before the first shot |
| *New game* | owner | after the first shot, balls still |
| *Re-rack* | seated (practice) | after a shot, balls still |
| *Rematch (re-rack)* | seated (1v1) | the game is won |
| *Sit*, *Leave table*, *Pick up board* | as for every table | |

Notices say what happened once the balls stop on every client: what was
potted, fouls ("Foul by your opponent: Scratch. Ball in hand: ..."), the group
assignment ("You are solids."), whose shot it is, the winner and why.

## Rules (8-ball, simplified)

- Rack: the 1 on the foot spot, the 8 in the middle, one solid and one stripe
  in the back corners, the rest shuffled from a server seed. White breaks the
  first rack; a rematch alternates the breaker. The cue ball starts on the head
  spot (no ball in hand on the break).
- After the break the table is open. The first shot that pots balls of one
  group only, without a foul, gives the shooter that group (a mixed pot leaves
  the table open).
- The shooter continues while potting a ball of their group (any ball on the
  break or on an open table); otherwise the turn passes. Potting an opponent's
  ball as well does not end the turn.
- Fouls (the turn passes, the opponent gets ball in hand **anywhere** on the
  cloth): scratch (the cue ball pocketed), no ball hit, the first ball hit is
  not one of your group (on an open table: the 8 first), no ball potted and no
  ball touching a cushion after the first contact. A scratch on the break
  gives ball in hand **behind the head string** only. Balls potted on a foul
  stay down.
- The 8: potted on the break it comes back to the foot spot (the game goes
  on). Potted legally once your group is cleared, you win; potted earlier, or
  on a foul while you were on the 8, you lose.
- Practice (solo): no fouls and no groups; a scratch puts the cue ball in hand;
  potting every ball clears the table; *Re-rack* any time between shots.

The rules are in `shared/casino_pool.lua` (`P.shoot`, `P.place`, `P.rerack`),
the server handler in `server/modules/casino_pool.lua` (validation, seeds,
the clock), the presentation in `client/core/casino_pool.lua`.

## Physics

Deterministic, server-authoritative, in the pure shared file (no randomness,
no clock). Units are real metres and seconds: 2.54 x 1.27 m between the
cushion noses, 57.15 mm balls.

- Balls roll in straight lines with a constant deceleration (`DECEL`
  0.75 m/s^2, rolling and sliding losses together) between events. The cue
  ball leaves at 0.3 to 5.5 m/s (power 0..1).
- Cushions reflect the normal part of the velocity with restitution 0.78. A
  ball centre crossing a cushion line within 8.5 cm of a corner or 4.6 cm of
  the middle of a long rail drops into that pocket; anywhere else the cushion
  sends it back, so no ball can leave the cloth.
- Ball contacts are equal-mass collisions with restitution 0.95. When the
  struck balls touch others (a frozen cluster, the rack), every contact of the
  cluster is resolved at once (Poisson restitution: an inelastic compression
  solve, then 0.95 of each contact's impulse back), so the break spreads the
  rack instead of passing the blow down one chain like a Newton's cradle.
  Momentum is conserved and energy only lost.
- Event driven: cushion crossings are solved exactly (quadratic); contacts by
  conservative advancement on the quartic gap function (a lower bound built
  from its negative Taylor terms never steps past a contact and becomes a
  Newton step near one).
- Each event starts new segments on a 0.1 mm / 0.1 mm/s / 0.1 ms grid, so the
  server continues from exactly what the wire carries.

### On the wire

`game.shot` = `{n, at, dur, yaw, power, by, segs, drops}`: `at` is the server
time of the strike (the request time + `P.LEAD` 250 ms, so every client sees
it from the start), `dur` the time until the last ball stops or drops.
`segs` holds one string per ball: 15-character records `t x y vx vy` (3
base64url characters each). A client evaluates a ball at server time `T` from
the last record with `t <= (T - at)/1000` with `P.motion` (straight line,
constant deceleration). `drops` lists pocketed balls (ball, pocket, time);
they sink into their pocket in 320 ms, then the object balls line up in the
ball return in `game.potted` order. `game.pos` holds the rest positions (6
characters per ball, `!!!!!!` when off the cloth).

A full-power break is ~45 segments, under 1 KB; the public board entry stays
around 1.5 KB with a nesting depth of 6 (limits ~3 KB and 7).

### Bounds

The server simulates a shot synchronously inside the request handler (the
176 server allows 1 s per handler call). The work is bounded by construction:
at most 320 events, 170 segments, 40,000 contact-search iterations and 20 s of
motion; reaching a cap stops every ball where it is (nothing is lost).
`tools/test-casino-pool.py` measures the worst of 180 breaks at about 1 M VM
instructions (~7 ms in desktop Lua) and derives the bound the caps impose
(~23 M instructions, ~0.2 s).

On the client, `pieceTargets` evaluates 16 balls, the cue and the rack: about
1.3 k VM instructions per animated frame, ~2 k for a cold table; a ball
decodes at most one record per frame (binary search on a jump), at most 3
fresh decodes per frame (a ball still waiting keeps last frame's spot; the
strike comes 250 ms after the snapshot), unchanged targets are handed back as
the same tables, and the shot time never runs backwards when a snapshot
re-anchors the server clock. Peak per resume in the e2e test: 4,000 (budget
~10 k).

## Models

`resources/assets/models/open77_casino_pool` (built by
`tools/build-casino-pool-props.py`, see its README): the table (with a
mesh-less collider `pool_table_collider` covering the body up to the rail),
the cue, the rack and 16 balls; 20 props per placed table (`PROP_ESTIMATE`).
Hidden props (the cue between shots, a ball in hand) park inside the closed
spine of the base (`P.PARK`).

## Validation

```sh
python3 tools/test-casino-pool.py          # physics + rules
python3 tools/test-casino-pool-server.py   # validation, replay, ball in hand, size
python3 tools/test-casino-pool-client.py   # playback, aim/charge/shoot, budget
python3 tools/test-table-menu.py           # ALT rows and notices
python3 tools/test-casino-e2e.py pool      # real server + client through JSON
python3 tools/build-casino-pool-props.py --lab <dop-tests lab> --work ~/.cache/casino-pool-build
python3 tools/test-table-colliders.py
```

Not verified in game yet: the look of the emission and the cloth under the
game's lighting, whether the ALT ray reports the table props, the feel of the
power swing and the deceleration, and the crosshair picking from the player's
own camera at shallow angles.
