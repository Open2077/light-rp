# Blackjack table

A placeable casino table (`blackjack_table`, kind `blackjack`) built on the
tabletop-extra plug-in contract. Up to four players sit at seats 1–4
(`white`, `black`, `white2`, `black2`, dealt in that order from the dealer's
left).

## Rules

- Six-deck shoe, shuffled on the server from a server seed
  (`LightRpBlackjack.shuffle`, Park–Miller), reshuffled at the next round once
  fewer than 78 cards remain (cut card).
- Bets 5–5,000 whole RP dollars per hand. The first bet starts a 10 s
  countdown; any bettor may press **Deal now**.
- Dealer stands on all 17s (soft 17 included), peeks under a ten or an ace:
  a dealer natural ends the round at once (a player natural pushes).
- Blackjack pays 3 to 2 (rounded down to whole dollars). Double on any first
  two cards (one card, stake doubled). No split, no insurance. 21 stands
  automatically.
- Turns in seat order, 20 s each; an idle hand stands automatically
  (`due`/`settle`, run by the 2 s board loop). The round resolves even if
  everyone leaves.

## Money

Stakes are debited in the same transaction as the board write (`X.stake`).
When the last hand is played the server reveals the hole card, plays the
dealer and inserts one claim per character inventory, available at
`resultAt` (the end of the reveal animation), paid once by `X.claim`.
Resetting or picking up the table before the result refunds every open stake
(bets and doubles) as claims in the same transaction. A seat taken over by
another character cannot bet into or play the absent owner's hand.

## Privacy

The shoe, the dealer's hole card and stake owners are `_` keys, stripped from
every client view. The hole card is `{h=true,t=...}` until it is revealed.
Worst-case public game state (four 7-card hands, 8-card dealer) is ~2 KB.

## Presentation

Every moving thing is a native prop animated from server timestamps
(`Extra.serverTime`): cards wait inside the shoe, slide out (0.5 s, staggered
0.45 s on the opening deal), flip through an authored half-turned pose, and
sweep into the discard tray 1.5 s before the next round. Chip stacks (up to
three denomination columns per stack) slide in from the player's edge on a
bet, to the dealer's rack on a loss (at once on a bust), and a winnings stack
slides out from the rack at the reveal. Worst case 59 moving props per table.
Cameras: overhead (`top`), the player's seat (`white`), the dealer side
(`black`) and a fixed three-quarter view (`orbit`).

Tests: `tools/test-casino-blackjack.py`, `tools/test-casino-blackjack-server.py`,
`tools/test-casino-blackjack-client.py`. Assets:
`tools/build-casino-blackjack-props.py` (resource `open77_casino_blackjack`).
