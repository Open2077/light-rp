# Board games

Three inventory items: `chess_board` (Chess Board), `checkers_board` (Checkers
Board) and `connect4_board` (Connect Four Board). No shop sells them yet (a games
shop needs an NPC placed in game); staff grant them with
`/lightrp.giveitem me <item> 1`. The casino tables (`roulette_table`,
`slot_machine`, `blackjack_table`, `fortune_wheel`) are granted the same way.
All item labels, controls, status messages and errors are in English.

Use an item to place its board. The inventory closes before placement takes the
cursor. Hold the mouse to move it, use X/Y/Z to constrain
an axis, Q/D to rotate, Page Up/Down to adjust height, and E to confirm.
Backspace or Escape cancels. Placement must be within 4 metres. There is no
per-character or server-wide placement count limit; nearby props stream as needed.

Press E near a board to join. The owner can choose Solo vs AI, 1v1 or 2v2 before
the first move. Teams share a colour; full turns alternate White 1, Black 1,
White 2, Black 2. All four players must be present in 2v2. A checkers capture
sequence remains with the same player until finished. Solo reserves White for
the owner and Black for the AI. Connect Four uses Red and Yellow for these sides.
The owner can select New game to reset the game and reopen the lobby.

Seated players play in **free mode**: no scripted camera, the character is not
frozen, mouse-look, movement and the HUD stay. The crosshair (screen centre)
aims at the table and the left mouse button acts; the aimed square, column or
table element and the current selection are outlined on the table itself.
Chess and checkers: click a piece, then its destination, or hold the button on
a piece and release it over another square. Connect Four: aim at a column and
click. The server receives a move only on release.

**H** opens the panel and gives the page the cursor: game setup, New game,
casino bets and actions (Hit, Stand, amounts), and the camera toolbar. The
toolbar's scripted views (Overhead, both sides, Orbit with right-drag rotation
and scroll zoom) are the former default and stay available: picking one freezes
the character, hides the HUD and keeps the cursor; **Free**, H or Escape returns
to free mode. While chat or another page types, the table keys stay inert.
Backspace (or the panel's Leave table button) leaves the seat. Nearby
interaction prompts stay hidden while seated.

Casino tables work the same way: aim at the slot machine's lever and click to
pull (with the bet chosen in the panel), aim at a Fortune Wheel felt spot and
click to pick it; at roulette and blackjack, which bet from the panel only, a
click on the table opens the panel.

Walking away leaves the table: beyond 3.5 m the HUD warns, and after 1.5 s out
of range (or at once beyond 5 m) the client leaves with a notice. The server
releases any seat beyond 5 m on its 2 s check and tells the player why; moves
are refused beyond 4 m. The target menu's Pick up board action returns a board
to its owner's inventory, even after reconnecting, and closes all seated
players' views.

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
`debugDraw` is used only for axis and square-selection lines. Props are non-solid
decorations; game movement and captures remain server-authoritative.
All models use a uniform 0.65 visual and interaction scale. Original wood-grain
textures give the pieces a matte wooden finish: ivory-white and ebony-black for
chess/checkers, with stained blue, red and yellow wood for Connect Four.

When the asset archive changes, fully close the game and reconnect through the
launcher to install and mount it. Reconnecting from within a running game cannot
mount a new archive. Missing or failed models are reported explicitly rather
than replaced by marker shapes. See the asset resource's README for editable
geometry, cooked-file checks and coordinate conventions.

Validation:

```sh
python3 tools/generate-board-game-models.py
python3 tools/generate-board-game-sounds.py
python3 tools/build-board-game-props.py
python3 tools/test-board-game-props.py --build /tmp/board-game-props/build
python3 tools/test-board-games.py
python3 tools/test-board-games-server.py
python3 tools/test-board-games-client.py
npm --prefix ui run build
node ui/tests/board-games.browser.cjs
```

The browser test accepts `PLAYWRIGHT_MODULE`, `CHROMIUM_PATH` and optional
`BOARD_GAMES_WEB_DIR`. Crosshair picking from the player's own camera (first
and third person), the scripted views, audio and native rendering still need an
in-game check with actual clients.

## Roulette

Additional native props are delivered by `open77_tabletop_extra` (3 props with original textures). The launcher must download the new preload package before reconnecting. All item labels and controls are English.

- `roulette_table`: European single-zero wheel and a separately animated ball. Place whole-dollar RP cash bets, then spin. The server chooses the outcome, closes betting during the eight-second spin and stores winnings atomically. Straight numbers return 36 times the stake, dozens 3 times and even-chance bets 2 times; returns include the original stake. Zero loses outside bets. Pending winnings and refunds belong to the character inventory and survive disconnections and restarts. Resetting or retrieving a table refunds unspun stakes; both are blocked during a spin.

The table shares placement, free mode and the optional camera views, distance leave and owner-only retrieval through the target menu with the board games. There is no numerical placement limit. Ordinary distance and overlap checks still apply.

Admin item command:

```text
/lightrp.giveitem me roulette_table 1
```

Validation: `tools/test-tabletop-extra.py`, `tools/test-tabletop-extra-client.py`, `tools/test-tabletop-extra-server.py`, `tools/build-tabletop-extra-props.py --verify-only`, and `ui/tests/board-games.browser.cjs`. Server tests cover atomic cash debits, failed storage, exactly-once payouts after restarts, offline refunds and recycled player IDs.
