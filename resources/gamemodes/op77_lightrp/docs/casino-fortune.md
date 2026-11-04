# Fortune Wheel

A big-six money wheel: a 1.3 m vertical wheel on a stand (0.85 m in game) with
a steel flapper at the top and a betting table in front. Night City high-roller
style: a black-chrome drum with an illuminated rim of warm lamps and a thin cyan
ring, smoked-glass segments with crisp multiplier numerals, a waisted gunmetal
counter whose composite top carries seven neon-edged betting tiles matching
the wheel's colours, and a lit marquee. Item
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

A winning bet returns multiplier x stake + stake. Bets: 1 to 100 per bet,
at most 500 per character per spin (owner decision 2026-11-04,
economy-balance.md §16), 32 distinct stakes per spin. The 2x/5x
counts differ from the classic 15/7 because the symmetric face needs even
counts; that is what lets 27 pose meshes show all 54 positions.

## Flow and authority

`shared/casino_fortune.lua` holds the layout, payouts and the deterministic
spin plan; `server/modules/casino_fortune.lua` picks the segment
(`math.random(0,53)`) and the laps (2-3), debits stakes through `X.stake`, and
writes every winner's durable claim in the same transaction as the spin (with
one transaction-log line per bettor: kind `casino`, *Fortune Wheel table*, amount
= returns − stakes of the spin; the chips themselves write no line), with
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
4,700 instructions per resume. Sitting opens the game view (board-games.md)
on the whole wheel above the betting felt (views *Wheel*, *Betting felt*,
*Pointer*, *Free*; Escape leaves). Except while the wheel spins, the seven
spots are marked faintly as clickable. Click a spot on the felt (1x, 2x, 5x, 10x, 20x, Neon Eye 40x,
Starburst 40x) to select it: it is outlined in cyan and the bar shows
*20x · pays 20 to 1*; set the chip with − / + and press *Bet €$ 10 on 20x*
(within 500 per round and your cash), then *Spin* (also after a result: it
starts the next round). A click only selects; money moves on *Bet*. While the
wheel turns the bar shows a countdown and no buttons; then *20x wins* and what
you won. Each accepted bet and the result arrive as notices.

Look: original art from `tools/build-casino-fortune-props.py` (shared kit
`tools/wheel_tables_art.py`: an original stroke typeface drawn with Pillow,
carbon/brushed/composite textures, emissive `metal_base` materials). Preview
renders (`--preview-only`) live in the asset's `sources/preview_fortune*.png`.
A collider entity `fortune_stand_collider` (counter, tower, drum; the space in
front of the counter is free) follows `tools/COLLISION.md`.

Validation: `tools/test-casino-fortune.py`, `tools/test-casino-fortune-server.py`,
`tools/test-casino-fortune-client.py` (spot picking), `tools/test-table-menu.py` (the
bar), `tools/test-casino-e2e.py fortune`, `tools/build-casino-fortune-props.py`.
