# Fortune Wheel

A big-six money wheel: a 1.3 m vertical wheel on a stand (0.85 m in game) with
a leather flapper at the top and a betting table in front. Item
`fortune_wheel` (staff: `/lightrp.giveitem me fortune_wheel 1`); kind `fortune`. Players seated
at the table bet whole RP dollars on a multiplier; any seated player may spin.

## Rules

54 segments, two-fold symmetric face:

| Spot | Segments | Pays | House edge |
|---|---|---|---|
| 1x | 24 | 1 to 1 | 11.1% |
| 2x | 14 | 2 to 1 | 22.2% |
| 5x | 8 | 5 to 1 | 11.1% |
| 10x | 4 | 10 to 1 | 18.5% |
| 20x | 2 | 20 to 1 | 22.2% |
| Neon Eye | 1 | 40 to 1 | 24.1% |
| Starburst | 1 | 40 to 1 | 24.1% |

A winning bet returns multiplier x stake + stake. Bets: 1 to 1,000 per bet,
at most 5,000 per character per spin, 32 distinct stakes per spin. The 2x/5x
counts differ from the classic 15/7 because the symmetric face needs even
counts; that is what lets 27 pose meshes show all 54 positions.

## Flow and authority

`shared/casino_fortune.lua` holds the layout, payouts and the deterministic
spin plan; `server/modules/casino_fortune.lua` picks the segment
(`math.random(0,53)`) and the laps (2-3), debits stakes through `X.stake`, and
writes every winner's durable claim in the same transaction as the spin, with
`available_at` = end of the spin (9 s: 8.2 s motion with linear deceleration,
then the flapper settles). Bets are closed while spinning; pickup and reset
are refused during a spin and refund open bets otherwise. The next bet or spin
after a result starts a new round. The public view carries per-spot totals,
the viewer's own stakes/winnings and the last 8 results (about 400 bytes).

## Presentation

The prop API only moves props and turns them about Z, so the rotor is 27 pose
meshes (snap-swapped, the inactive ones parked inside the drum), two blur
discs above ~22 segments/s, two orbiting 40x medallions, four flapper poses
kicked at each peg crossing (timed exactly from the easing), and one chip stack
per staked spot; at the stop, losing stacks are swept and the payout rises
next to the winning spot. 38-44 props per table; the measured client peak is
4,700 instructions per resume. Clicking a felt spot selects it in the panel
(it never wagers). Camera views: default = wheel and table, white = felt,
black = flapper close-up.

Validation: `tools/test-casino-fortune.py`, `tools/test-casino-fortune-server.py`,
`tools/test-casino-fortune-client.py`, `tools/build-casino-fortune-props.py`.
