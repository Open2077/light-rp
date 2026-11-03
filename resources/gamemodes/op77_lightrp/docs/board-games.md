# Board games

Three inventory items: `chess_board` (Chess Board), `checkers_board` (Checkers
Board) and `connect4_board` (Connect Four Board). No shop sells them yet (a games
shop needs an NPC placed in game); staff grant them with
`/lightrp.giveitem me <item> 1`. The casino tables (`roulette_table`,
`slot_machine`, `blackjack_table`, `fortune_wheel`) and the pool table
(`pool_table`, see `casino-pool.md`) are granted the same way.
All item labels, controls, status messages and errors are in English.

Use an item to place its board. The inventory closes first, then placement
runs in free mode (no cursor): the preview stands where the crosshair hits the
world within 3.5 m (a floor-standing table on the floor, a board on the
surface), the Left/Right arrow keys turn it, Page Up/Down adjust its height,
and E confirms. Backspace or Escape cancels. A notice lists the keys. Placement
must be within 4 metres. There is no per-character or server-wide placement
count limit; nearby props stream as needed.

**There is no table panel and no table HUD.** Everything happens in the world
(free mode) and in the ALT target menu:

- **Crosshair + left click** plays on the board itself. The character is not
  frozen, mouse-look, movement and the game HUD stay. The aimed square, column
  or table element and the selection are outlined on the table, and a small
  cross marks where the screen centre meets a chess or checkers board.
  Chess and checkers: click a piece, then its destination, or hold the button
  on a piece and release it over another square. Connect Four: aim at a column
  and click. The server receives a move only on release. While ALT is held (or
  the target menu is open) and while chat or another page types, clicks and
  table keys stay inert.
- **Hold ALT and click the table** (its base, its collider, a piece, or the
  surface right under it) for a menu titled with the game's name that lists
  only what makes sense for you right now (`client/core/table_menu.lua`):
  *Sit* when a seat is free for you, *Leave table* when seated, *Pick up board*
  for the owner within 2 m. Seated on a board game: a status row (*Your turn*,
  *Black to move*, *You win*... selecting it explains the mode, the players and
  the controls), and for the owner *Mode: 1v1 ›* (Solo vs AI, 1v1, 2v2) before
  the first move, then *New game*. The casino rows are in each casino document.
- **E** near a table also sits down (the interaction prompt). It stays because
  it is how every other Light RP object is used and needs no aiming; the ALT
  menu offers the same *Sit* so the table's menu is complete.
- **Notices** say what the panel used to show: how to play when you sit, your
  turn, the result, each confirmed bet and payout, refusals from the server
  ("It is not your turn", "Not enough cash for this bet"...). Timed reveals
  (reels, the dealer's hand) are announced when every client shows them.

Backspace or the menu's *Leave table* leaves the seat. Nearby interaction
prompts stay hidden while seated.

The owner chooses Solo vs AI, 1v1 or 2v2 before the first move. Teams share a
colour; full turns alternate White 1, Black 1, White 2, Black 2. All four
players must be present in 2v2. A checkers capture sequence remains with the
same player until finished. Solo reserves White for the owner and Black for the
AI. Connect Four uses Red and Yellow for these sides. The owner's *New game*
resets the game and reopens the lobby.

Walking away leaves the table: beyond 3.5 m a notice warns, and after 1.5 s out
of range (or at once beyond 5 m) the client leaves with a notice. The server
releases any seat beyond 5 m on its 2 s check and tells the player why; moves
are refused beyond 4 m. *Pick up board* returns a board to its owner's
inventory, even after reconnecting, and unseats everyone at it.

The menu is one `open77_contextmenu` registration with **dynamic rows**
(`rows="tableMenuRows"`, open77_contextmenu 1.3.0): at each ALT click the menu
asks LightRP for this table's rows, built from the snapshot the client already
holds (seat, phase, turn, owner, legal moves, last known cash), and on
selection asks again and runs the row only if it is still offered. A static
registration per action would not fit: the menu allows 32 actions per resource
and Light RP already uses 23 for vehicles, crew, cyberware, the guide and the
Hall of Fame. Every row sends a request the server already validates
(`lightrp:boardGames:request` join/leave/mode/reset/pickup, and the tabletop
`game` operations through `LightRpTabletopExtraClient.command`); nothing about
the rules or the money changed. A menu costs about 1,400 VM instructions to
build (`tools/test-table-menu.py`).

Chess supports castling, en passant, checkmate/stalemate, repetition, insufficient
material and promotion. The mouse interface promotes to a queen automatically;
the rules API also supports underpromotion. Checkers uses international 10x10
rules with mandatory maximum captures, multiple captures and flying kings.
Connect Four checks horizontal, vertical and diagonal wins and full-board draws.
The AI uses bounded tactical search and only server-validated legal moves.

The server validates distance, routing bucket, seats, active player and revision.
It broadcasts snapshots; clients interpolate movement. The engine has no tween:
the client moves props with `setTransform`, and only the props that are not yet
at their goal, every frame (a still table costs nothing). Goals are recomputed
when a snapshot arrives; a casino adapter's time-driven targets declare how long
they hold (`animatingUntil` / `stillUntil`, see `client/core/tabletop_extra.lua`)
and are recomputed every frame only while a timeline runs. Six original synthesized
WAV effects cover moves, captures, disc drops and wins. Spatial audio plays once
per new move sequence within 14 metres; initial sync and mode changes are silent.

`lightrp_board_games` persists positions, modes, game states and ownership by
character inventory ID. Seats are released on disconnect and restart. Placement
and recovery commit the board and inventory item in one SQL transaction. Without
a ready database, placement is disabled. Delayed AI jobs carry a revision/token
and are cancelled when the game is reset or removed.

Engine build 156 lacks native gizmos, so placement uses a custom axis manipulator.
Boards and every piece are genuine native props backed by cooked `.mesh` assets
and `.ent` visual hosts. The `open77_board_games` asset resource preloads their
archive before the game boots. Each client projects the authoritative snapshots
into its own local props, including the placement preview. Stable prop handles
move with native transforms; captures retain their handles and promotions replace
only the affected piece. Creation is staggered so it does not block input.
`debugDraw` is used only for the placement axes, the aim cross and the
selection outlines. Props are non-solid
decorations; game movement and captures remain server-authoritative.
All models use a uniform 0.65 visual and interaction scale. The art is an
original Night City set (`tools/board-game-art.py`, version 2.0.0 of the pack):
carbon and brushed-gunmetal boards with chrome bevels, raised lacquer tiles on
an etched neon grid and a neon channel (cyan for chess, amber for checkers);
White pieces are pearl and chrome with cyan accents, Black pieces onyx and
gunmetal with magenta accents; checker kings carry a raised neon crown;
Connect Four is a gunmetal frame with red and yellow machined discs. There is
no emissive shader: the glow is bright paint, texture bands and bevel
highlights. The crosshair picking heights (`PIECE_HEIGHTS` in
`client/core/board_games.lua`) follow the cooked piece heights; the pack test
fails if they drift. Each board base also ships a mesh-less collider entity
(`<base>_collider.ent`, see `tools/COLLISION.md`).

When the asset archive changes, fully close the game and reconnect through the
launcher to install and mount it. Reconnecting from within a running game cannot
mount a new archive. Missing or failed models are reported explicitly rather
than replaced by marker shapes. See the asset resource's README for editable
geometry, cooked-file checks and coordinate conventions.

Validation:

```sh
python3 tools/generate-board-game-models.py
python3 tools/generate-board-game-sounds.py
python3 tools/build-board-game-props.py --lab <dop-tests lab> --work ~/.cache/board-game-props
python3 tools/test-board-game-props.py --build ~/.cache/board-game-props
python3 resources/assets/models/open77_board_games/sources/preview.py
python3 tools/test-board-games.py
python3 tools/test-board-games-server.py
python3 tools/test-board-games-client.py
python3 tools/test-table-menu.py
python3 tools/test-casino-e2e.py
```

`resources/gamemodes/op77_lightrp/tests/context_rows_test.lua` covers the
dynamic rows of open77_contextmenu and `ui/tests/context-submenus.browser.cjs`
its page (title and row tokens). Crosshair picking from the player's own camera
(first and third person), whether the ALT ray reports the table props (it hits
the cooked colliders; the menu falls back to the nearest table under a surface
hit), audio and native rendering still need an in-game check with actual clients.

## Roulette

Additional native props are delivered by `open77_tabletop_extra` (3 props with original textures). The launcher must download the new preload package before reconnecting. All item labels and controls are English.

- `roulette_table`: European single-zero wheel and a separately animated ball. Place whole-dollar RP cash bets, then spin. The server chooses the outcome, closes betting during the eight-second spin and stores winnings atomically. Straight numbers return 36 times the stake, dozens 3 times and even-chance bets 2 times; returns include the original stake. Zero loses outside bets. Pending winnings and refunds belong to the character inventory and survive disconnections and restarts. Resetting or retrieving a table refunds unspun stakes; both are blocked during a spin.

The roulette is a full casino table in the Night City high-roller style: a black-chrome bowl with a smoked-glass ball track and chrome deflectors, a rotor with frets, an etched number ring, a brushed cone and a chrome turret, a dark composite layout printed with 0-36, the dozens and the even chances under thin cyan lines, a chip rack, a rail and a sculpted pedestal. The board position is still the wheel centre: the table runs 2.1 m along +X (1.37 m in game) and stands 1.23 m below the wheel datum (0.80 m in game), so aim at the floor while placing: the preview stands its plinth on the aimed surface (PgUp/PgDn adjust). The ball (3 cm, 2 cm in game, faintly luminous) rides the ball track for the first half of the spin, drops over the deflectors and the number ring, then lands in its pocket and turns with the rotor. A collider entity `roulette_table_collider` follows `tools/COLLISION.md`. Preview renders: `resources/assets/models/open77_tabletop_extra/sources/preview_roulette*.png`.

The table shares placement, free mode, distance leave and owner-only retrieval through the ALT menu with the board games. Seated, hold ALT on the table: *Chip: €$ 10 ›* (10, 50, 100, 500, 1,000, within your cash) picks the amount, *Bet €$ 10 ›* lists Red, Black, Even, Odd, 1-18, 19-36, 1-12, 13-24, 25-36 and Zero, and *Spin* spins; while the wheel turns only the status and *Leave table* remain; then the status shows the result (*Result: 17 Black*) with *Next round*. Each accepted bet and the result with your winnings arrive as notices. Straight numbers 1-36 are not in the menu (the menu shows at most 24 rows and one folder level); the server still accepts them. There is no numerical placement limit. Ordinary distance and overlap checks still apply.

Admin item command:

```text
/lightrp.giveitem me roulette_table 1
```

Validation: `tools/test-tabletop-extra.py`, `tools/test-tabletop-extra-client.py`, `tools/test-tabletop-extra-server.py`, `tools/build-tabletop-extra-props.py --verify-only`, and `tools/test-table-menu.py`. Server tests cover atomic cash debits, failed storage, exactly-once payouts after restarts, offline refunds and recycled player IDs.
