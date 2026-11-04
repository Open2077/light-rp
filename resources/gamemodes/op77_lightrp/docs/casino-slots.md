# Slot machine

Item `slot_machine` (Slot Machine). No shop sells it yet; staff can grant it with `/lightrp.giveitem me slot_machine 1`. Use the item to
place the cabinet (same placement controls as the board games), press E near it
to sit down. The first player seated (White) plays; anyone else who joins watches.
Hold ALT and click the machine for its menu (status, *Sit*, *Pick up board*
for the owner; see board-games.md); pickup is refused while the reels spin.

## Playing

Sitting opens the game view (board-games.md) on the reels (views *Reels*,
*Cabinet*, *Lever*, *Free*; Escape leaves). The lever is marked faintly as
clickable when you are at it and the reels are at rest. Seated in the first seat, set the bet on the bar with − /
+ (1, 5, 10, 25, 50, 100; the server accepts 1 to 100, owner decision 2026-11-04,
economy-balance.md §16) and
press *Pull €$ 10*, or point the cursor at the lever on the right of the
cabinet (it is outlined) and click, which pulls with the same bet. The lever is
an action, not a betting spot: a click on it pulls at once. The bar status
shows *Ready*, *Reels spinning* or the last result (*Won €$ 2,000*, *No win*);
*Pull* is disabled while the reels spin or above your cash. Watchers see the
status and *Another player is at the lever*. The pull debits the stake from
cash, the server picks the three reel stops (`math.random`), stores the payout
claim and the new state in one SQL transaction. Every client then plays the same
server-clock timeline: the lever goes down and springs back (0.6 s), the reels
spin and stop one by one at 1.8 s, 2.4 s and 3.0 s with a small overshoot, the
top lamp blinks and up to four coins drop into the tray on a win. Winnings are
paid into cash when the last reel stops (`lightrp_roulette_claims`, the shared
casino claim table, `available_at` = stop time); a disconnected or restarted
player is paid on the next claim pass. The result notice ("Three Sevens · €$ 2,000.",
"No win.") comes only when the last reel stops, never before. The pull writes one
line to the player's transaction log (`lightrp_transactions`, kind `casino`, counterparty
*Slots table*, amount = return − stake, note *Slots: staked €$ 10, returned €$ 0*) in the
same transaction; neither the stake nor the payout writes a line of its own.

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

Every return is a multiple of the bet: there is no fixed jackpot. Three Sevens
(one pull in 1,728) pays 200 × the bet, so **20,000** at the 100 maximum (it was
200,000 at the former 1,000 maximum).

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
  `tools/build-casino-slots-props.py` (see its README). Look: a premium Night
  City stepper cabinet at true proportions (0.66 m wide, 2.05 m to the lamp in
  game), in the casino set's materials: satin black lacquer side panels with
  black-chrome edges and brushed inserts, a gunmetal kick plate, a lower door
  with a belly glass, a chrome payout bowl, a carbon button deck with keycaps
  and a domed spin button, a ticket printer and a card reader, a smoked-glass
  reel door behind a black-chrome bezel, a paytable display between speaker
  grilles, a concave attract screen under an overhanging crown and a candle
  lamp; a chrome lever with a weighted knob on a bolted hub. Light is limited
  to thin accent lines, the spin ring, the card slot, the payline, the screens
  and the backlit reels. The verify step checks the geometry for coplanar
  overlaps between materials (the old cabinet's flickering plinth line) and for
  holes (`tools/mesh_checks.py`). Preview renders: `sources/preview_slots_*.png`
  (`--preview`). The pack also cooks `slot_cabinet_collider.ent` (player
  collision, `tools/COLLISION.md`). The remodel moved the reel window, lever,
  lamp, chute and tray (the layout table in `client/core/casino_slots.lua`
  follows the cooked `layout`; the README lists the old and new values).

Tests: `python3 tools/test-casino-slots.py`, `tools/test-casino-slots-server.py`,
`tools/test-casino-slots-client.py`.

Not covered by the native light API: the board renderer creates `kind="prop"`
hosts only, so the win lamp is a lit/unlit mesh pair rather than a real light.
