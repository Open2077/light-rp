# Blackjack table

A placeable casino table (`blackjack_table`, kind `blackjack`) built on the
tabletop-extra plug-in contract. Up to four players sit at seats 1–4
(`white`, `black`, `white2`, `black2`, dealt in that order from the dealer's
left).

## Rules

- Six-deck shoe, shuffled on the server from a server seed
  (`LightRpBlackjack.shuffle`, Park–Miller), reshuffled at the next round once
  fewer than 78 cards remain (cut card).
- Bets 5–5,000 whole RP dollars per hand. The first bet starts a 15 s
  countdown; any bettor may press **Deal now**.
- Dealer stands on all 17s (soft 17 included), peeks under a ten or an ace:
  a dealer natural ends the round at once (a player natural pushes).
- Blackjack pays 3 to 2 (rounded down to whole dollars). Double on any first
  two cards (one card, stake doubled). No split, no insurance. 21 stands
  automatically.
- Turns in seat order, 25 s each; an idle hand stands automatically
  (`due`/`settle`, run by the 2 s board loop). The round resolves even if
  everyone leaves.

## Pacing

The table is paced like a real one. Every moment is a server timestamp in
the public state (`dealtAt`, card `t`/`f`, `actAt`, `turnEndsAt`, `revealAt`,
`resultAt`, `nextAt`), so every client shows the same thing at the same time.
The constants live in `shared/casino_blackjack.lua`:

| Moment | Constant | Value |
| --- | --- | --- |
| Betting countdown after the first bet | `BET_WINDOW` | 15 s |
| Between two cards of the opening deal | `DEAL_GAP` | 0.8 s |
| Card slide from the shoe / flip | `SLIDE` / `FLIP` | 0.6 s / 0.35 s |
| Pause after the deal, before the first turn | `DEAL_PAUSE` | 1 s |
| Turn timer | `TURN` | 25 s |
| Pause after the last decision, before the hole card turns | `REVEAL_PAUSE` | 1 s |
| Hole card face-up, before the first dealer draw | `DRAW_PAUSE` | 0.7 s |
| Between two dealer draws (each card rests ~0.25 s) | `DRAW_GAP` | 1.2 s |
| Last dealer card face-up, before the result | `SETTLE_PAUSE` | 0.5 s |
| Chips to the rack / payout, staggered per seat | `CHIPS` / `CHIP_STAGGER` | 0.8 s / 0.3 s |
| Result on the felt, then the sweep | `RESULT` − `SWEEP` | 4.5 s |
| Sweep into the discard tray, then the next round | `SWEEP` | 2 s |

A one-player round therefore reads: cards out over ~4 s, a 1 s pause, the
player's decisions, a 1 s pause, the hole card, one dealer card a second or so
apart, the result and chips, 4.5 s of result, the sweep. The timed steps
(countdown, idle turn, next round) run on the 2 s board loop, so they may
start up to 2 s after their timestamp; everything they produce is stamped
with the moment they actually run.

## Money

Stakes are debited in the same transaction as the board write (`X.stake`).
When the last hand is played the server reveals the hole card, plays the
dealer and inserts one claim per character inventory, available at
`resultAt` (the last dealer card settled plus `SETTLE_PAUSE`, i.e. exactly
when the reveal ends on every client), paid once by `X.claim`.
Resetting or picking up the table before the result refunds every open stake
(bets and doubles) as claims in the same transaction. A seat taken over by
another character cannot bet into or play the absent owner's hand.

## Privacy

The shoe, the dealer's hole card and stake owners are `_` keys, stripped from
every client view. The hole card is `{h=true,t=...}` until it is revealed.
Worst-case public game state (four 7-card hands, 8-card dealer) is ~2 KB.

## Presentation

Every moving thing is a native prop animated from server timestamps
(`Extra.serverTime`): cards wait inside the shoe, slide out (0.6 s, staggered
0.8 s on the opening deal), flip through an authored half-turned pose, and
sweep into the discard tray seat by seat 2 s before the next round. Chip stacks (up to
three denomination columns per stack) slide in from the player's edge on a
bet, to the dealer's rack on a loss (at once on a bust), and a winnings stack
slides out from the rack at the reveal. Worst case 59 moving props per table.
Cameras: overhead (`top`), the player's seat (`white`), the dealer side
(`black`) and a fixed three-quarter view (`orbit`).

## The dealer

Every placed table has a croupier NPC standing on the dealer side (behind the
shoe, the chip rack and the wooden apron), facing the players
(`server/modules/casino_blackjack.lua`, settings `LightRpBlackjack.DEALER`).
The stand point is board-local `(0, 0.72)` unscaled metres, transformed by the
table's position, rotation and the 0.65 model scale exactly like the client's
`Extra.world`; the body faces `rotation + 180°` and stands in the table's
routing bucket, on the floor under the table origin.

- **Lifecycle**: the tabletop-extra contract gained optional `placed(b)` /
  `removed(b)` hooks, called by `server/modules/board_games.lua` after a
  placement commit, for every table loaded from `lightrp_board_games` at start
  (so a server restart restores the dealers), and after a pickup commit. The
  NPC itself is created by a 250 ms dealer tick (never inside a transaction),
  retried every 10 s up to 6 times if the platform refuses; the table works
  without it. It is removed on pickup and on resource stop (the framework also
  clears every NPC this resource owns at start and stop, so a hot reload
  never leaves a double).
- **Record**: tried in order until `Open77.npcs.create` accepts one:
  `Character.sts_wat_kab_07_croupiers` (the base-game Kabuki gambling-den
  croupier; the record id is derived from its catalogued template
  `sts_wat_kab_07_croupiers.ent` and still has to be confirmed in game), then
  the suited crowd faces the rental desks already spawn
  (`mws_hey_07_zetatech_executive`, `sts_hey_rey_06_receptionist`). The
  server log names the accepted record. Game characters only, no real-person
  likeness.
- **Behaviour**: like the other service NPCs: invulnerable, `aiMode = tasks`,
  combat, perception and voice off, native AI off (`setAIEnabled(false)`), so
  the body stands still behind the table and never walks into players.
- **Dealing gesture**: `Open77.npcs.tasks.playAnimation` exists, but a server
  NPC runs tasks only while its AI is on. While cards leave the shoe (the
  opening deal, a hit, the hole card and the dealer's draws, read from the card
  timestamps) the dealer tick queues the clip
  `stand_table_lean0__2h_on_table__01__describe_front__01` (base game, both
  hands over a table, looping until the cards have settled), switches the AI on
  for that window, then off again and puts the body back on its mark
  (`setTransform`). The clip is a raw clip, not a workspot profile, so the
  generic device may not load its animset (the devkit says such a clip then
  simply does not play). Set `LightRpBlackjack.DEALER.gesture = nil` to turn
  the gesture off if the AI toggle misbehaves in game.

Tests: `tools/test-casino-blackjack.py`, `tools/test-casino-blackjack-server.py`,
`tools/test-casino-blackjack-client.py`. Assets:
`tools/build-casino-blackjack-props.py` (resource `open77_casino_blackjack`).
