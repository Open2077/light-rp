# Slot machine

Item `slot_machine` (Slot Machine). No shop sells it yet; staff can grant it with `/lightrp.giveitem me slot_machine 1`. Use the item to
place the cabinet (same placement controls as the board games), press E near it
to sit down. The first player seated (White) plays; anyone else who joins watches.
Hold ALT and click the machine for its menu (*Sit*, *Pick up board* for the
owner, *Leave table*; see board-games.md); pickup is refused while the reels
spin.

## Playing

There is no panel. Seated in the first seat, hold ALT on the machine: *Bet:
€$ 10 ›* picks the bet (10, 50, 100, 500 or 1,000, within your cash; the
server accepts 1 to 1,000) and *Pull (€$ 10)* pulls; or aim at the lever on the
right of the cabinet (it is outlined) and click, which pulls with the same bet.
The status row shows *Ready*, *Reels spinning* or the last result, and selecting
it recalls the paytable. Watchers only get the status and *Leave table*. The pull debits the stake from
cash, the server picks the three reel stops (`math.random`), stores the payout
claim and the new state in one SQL transaction. Every client then plays the same
server-clock timeline: the lever goes down and springs back (0.6 s), the reels
spin and stop one by one at 1.8 s, 2.4 s and 3.0 s with a small overshoot, the
top lamp blinks and up to four coins drop into the tray on a win. Winnings are
paid into cash when the last reel stops (`lightrp_roulette_claims`, the shared
casino claim table, `available_at` = stop time); a disconnected or restarted
player is paid on the next claim pass. The result notice ("Three Sevens · €$ 2,000.",
"No win.") comes only when the last reel stops, never before.

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
  `tools/build-casino-slots-props.py` (see its README). Look: a Night City
  black chrome cabinet between two fins with cyan neon edges, a curved topper
  screen, a lit paytable screen above the reels, a slanted console with
  glowing buttons, a chrome lever with a glowing knob and a lit coin tray.
  Neon, screens and reel strips use the material's emissive channel. Preview
  renders: `sources/preview_slots_*.png` (`--preview`). The pack also cooks
  `slot_cabinet_collider.ent` (player collision, `tools/COLLISION.md`).

Tests: `python3 tools/test-casino-slots.py`, `tools/test-casino-slots-server.py`,
`tools/test-casino-slots-client.py`.

Not covered by the native light API: the board renderer creates `kind="prop"`
hosts only, so the win lamp is a lit/unlit mesh pair rather than a real light.
