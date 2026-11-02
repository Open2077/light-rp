# Slot machine

Item `slot_machine` (Slot Machine). No shop sells it yet; staff can grant it with `/lightrp.giveitem me slot_machine 1`. Use the item to
place the cabinet (same placement controls as the board games), press E near it
to sit down. The first player seated (White) plays; anyone else who joins watches.
Pick the machine up from the target menu; pickup and New game are refused while
the reels spin.

## Playing

Choose a bet of 1 to 1,000 whole RP dollars in the panel, then click the lever
on the right of the cabinet or press **Pull**. The pull debits the stake from
cash, the server picks the three reel stops (`math.random`), stores the payout
claim and the new state in one SQL transaction. Every client then plays the same
server-clock timeline: the lever goes down and springs back (0.6 s), the reels
spin and stop one by one at 1.8 s, 2.4 s and 3.0 s with a small overshoot, the
top lamp blinks and up to four coins drop into the tray on a win. Winnings are
paid into cash when the last reel stops (`lightrp_roulette_claims`, the shared
casino claim table, `available_at` = stop time); a disconnected or restarted
player is paid on the next claim pass. The panel shows the result only once the
reels have stopped.

## Reels and paytable

Three reels of 12 stops, one payline (middle row). Returns include the stake.

| Line | Pays |
| --- | --- |
| 3 Seven | ×200 |
| 3 Diamond | ×100 |
| 3 Chip | ×50 |
| 3 Bar | ×30 |
| 3 Bell | ×18 |
| 3 Cherry / 3 Grape | ×10 |
| 3 Lemon | ×8 |
| Cherry, Cherry (reels 1–2) | ×4 |
| Any cherry/lemon/grape on all reels | ×2 |
| Cherry on reel 1 | ×1 (stake back) |

Return to player is exactly 1632/1728 = **94.4 %**, hit rate 33.8 %
(`tools/test-casino-slots.py` enumerates all 1,728 outcomes). Strips, symbols and
the paytable live in `shared/casino_slots.lua`; the cooked strip meshes are
checked against them.

## Implementation

- `shared/casino_slots.lua`: item, kind, strips, paytable, timing, pure
  `pull`/`settle` state machine (no randomness).
- `server/modules/casino_slots.lua`: `LightRP.tabletopExtra` handler. The
  public view carries only the current spin (≈0.5 KB); the puller's inventory
  is private (`_inventory`).
- `client/core/casino_slots.lua`: adapter. 16 props per machine: cabinet,
  3 symbol strips sliding vertically behind the window (wrapping by 12 pitches),
  6 lever pose meshes, lit/unlit lamp, 4 coins. Inactive poses are parked inside
  the closed cabinet with `snap=true`. Peak client cost in the budget test is
  about 2,000 instructions per resume.
- UI: `ui/src/features/board-games/extra/SlotsControls.tsx`.
- Assets: `resources/assets/models/open77_casino_slots`, built by
  `tools/build-casino-slots-props.py` (see its README).

Tests: `python3 tools/test-casino-slots.py`, `tools/test-casino-slots-server.py`,
`tools/test-casino-slots-client.py`.

Not covered by the native light API: the board renderer creates `kind="prop"`
hosts only, so the win lamp is a lit/unlit mesh pair rather than a real light.
