# Board games

Three inventory items are sold at the market:

| Item ID | Display name | Buy / sell |
| --- | --- | --- |
| `chess_board` | Chess Board | 250 / 60 |
| `checkers_board` | Checkers Board | 150 / 35 |
| `connect4_board` | Connect Four Board | 200 / 50 |

Staff can grant them with `/lightrp.giveitem me <item> 1`.
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

Chess and checkers use an overhead camera with click-to-move or drag-and-drop.
Camera controls also offer both player sides and an orbit view with right-drag
rotation and scroll zoom. Left-drag moves the selected prop visually; the server
receives the move only on release. Native and custom HUDs and nearby interaction
prompts are hidden during play and restored on exit.
Connect Four uses a camera facing its upright grid: click a column to drop a
disc. Backspace or Escape leaves the seat. The target menu's Pick up board action
returns it to its owner's inventory, even after reconnecting, and closes all seated players' views.

Chess supports castling, en passant, checkmate/stalemate, repetition, insufficient
material and promotion. The mouse interface promotes to a queen automatically;
the rules API also supports underpromotion. Checkers uses international 10x10
rules with mandatory maximum captures, multiple captures and flying kings.
Connect Four checks horizontal, vertical and diagonal wins and full-board draws.
The AI uses bounded tactical search and only server-validated legal moves.

The server validates distance, routing bucket, seats, active player and revision.
It broadcasts snapshots; clients interpolate movement. Six original synthesized
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
`BOARD_GAMES_WEB_DIR`. Final camera, picking, audio and native rendering still
need an in-game check with actual clients.
