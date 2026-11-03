# Board games

Three inventory items: `chess_board` (Chess Board), `checkers_board` (Checkers
Board) and `connect4_board` (Connect Four Board). No shop sells them yet (a games
shop needs an NPC placed in game); staff grant them with
`/lightrp.giveitem me <item> 1`. The casino tables (`roulette_table`,
`slot_machine`, `blackjack_table`, `fortune_wheel`) and the pool table
(`pool_table`, see `casino-pool.md`) are granted the same way.
All item labels, controls, status messages and errors are in English.

Use an item to place its board. The inventory closes first, then placement
runs without a cursor: the preview stands where the crosshair hits the
world within 3.5 m (a floor-standing table on the floor, a board on the
surface), the Left/Right arrow keys turn it, Page Up/Down adjust its height,
and E confirms. Backspace or Escape cancels. A notice lists the keys. Placement
must be within 4 metres. There is no per-character or server-wide placement
count limit; nearby props stream as needed.

**Sitting opens the game view.** E near a table (the interaction prompt) or
*Sit* in the table's ALT menu takes a seat, and the client
(`client/core/board_games.lua`) then:

- activates a **scripted camera** framing the table (per game, see below),
  freezes the character, hides the game HUD (cinematic, letterbox 1 %) and the
  page's gameplay HUD and voice plate, and gives the page the **mouse cursor**
  (keyboard stays with the game). The ALT target menu is disabled while the
  page holds the cursor;
- lets the cursor **pick on the table** through `Open77.camera.screenRay`:
  chess and checkers squares and pieces (tall pieces by their bodies, so a side
  view picks the piece, not the square behind it), Connect Four columns,
  roulette layout cells, fortune spots, your blackjack betting circle, the slot
  lever, the pool cloth. The hovered target is outlined on the table in amber,
  the selection in cyan (`Open77.debugDraw`);
- shows a compact **bar centred at the bottom of the screen**
  (`ui/src/features/board-games/TableBar.tsx`, model built per game by
  `client/core/table_bar.lua`): the game's title, a short status (whose turn,
  the phase, a countdown, your hand total), the chip amount (− / value / +,
  stepping through 1, 5, 10, 25, 50, 100... within the game's limits), the
  target picked on the table, the buttons that make sense right now (Bet,
  Spin, Pull, Deal now, Hit, Stand, Double, Next round, Re-rack, Rematch, the
  owner's Mode and New game), the camera switch and Leave. Buttons that do not
  apply are not shown; buttons that apply but cannot be used yet are disabled.
  It never covers the middle of the screen.

Chess and checkers: click a piece, then its destination, or press on a piece
and release it over another square (the held piece follows the cursor).
Connect Four: click a column (the drop is sent on release over the same
column). The server receives a move only on release; a press or release over
the bar is never a table click. Promotion is always to a queen.

Camera views (the camera button cycles them; the first is the default):
chess and checkers *Overhead*, *White side*, *Black side*, *Orbit*; Connect
Four *Front*, *Low front*, *Orbit*. In an orbit view the right button turns
the camera and the wheel zooms. If another script holds the camera when you
sit, you keep the cursor and the bar over the game camera (a notice says so);
if another script takes the camera over while you play (a cutscene), the
table view closes.

Backspace, the bar's *Leave* or walking away (see below) leaves the seat and
restores the camera, the character, the cursor and the HUD. Escape stays with
the game's pause menu. Nearby interaction prompts stay hidden while seated.

**The ALT menu manages tables.** Hold ALT and click a table (its base, its
collider, a piece, or the surface right under it) for a menu titled with the
game's name (`client/core/table_menu.lua`): a status row (*White to move ·
1v1*, *Bets open*, *Hand in play*...; selecting it repeats it as a notice),
*Sit* when a seat is free for you, for the owner *Mode: 1v1 ›* (Solo vs AI,
1v1, 2v2; pool: Solo practice, 1v1) before the first move then *New game*,
and *Pick up board* within 2 m. The owner can configure a table without
sitting. Seated players use the bar (the menu cannot open while the page holds
the cursor); its *Leave table* row remains only as a fallback.

**Notices** complement the bar: how to play when you sit, your turn, the
result, each confirmed bet and payout, refusals from the server ("It is not
your turn", "Not enough cash for this bet"...). Timed reveals (reels, the
dealer's hand) are announced when every client shows them.

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

The owner is the **character** that placed the table (its inventory ID,
`player:<account>#<slot>`), not the account or the session. The ALT row
*Pick up board* only appears for that character (`owned` in the snapshot), and
the server refuses everyone else, including the same player on another
character slot, with *Only the character who placed this table can pick it
up.* *Mode* and *New game* (which can refund stakes) are owner-only too. No
other path removes a table: placement tickets are bound to the inventory that
used the item, and staff go through the desk below.

### Staff management

`/admin` > **Placed tables** (and `/lightrp.tables` in chat) lists every placed
table: ID, kind, owner character name and inventory ID, online state,
position, instance, placement time (from the ID) and revision, seated players,
phase, and the open stakes a removal would refund (*Resolving: …* while a spin
or a dealt round settles). Rows are flat and paginated (15 per page in the
desk, 10 per chat page) so hundreds of tables never make one large or deeply
nested event. Sort by newest or nearest; search by ID, kind or owner.

- **Go to table** teleports the staff member with `LightRP.staff.moveTo`
  (`Open77.players.teleport`, or a respawn when dead) to a point beyond the
  players' edge of the table (about 1.2–1.6 m from its origin, outside the
  collider), facing it. From a private instance to a city table it lands in
  instance 0; a table inside another private instance (housing) is refused.
- **Remove table** is `LightRP.boardGames.remove`: pickup without the owner.
  It takes the same busy lock (refused while a move or payout saves), refunds
  open stakes with `LightRP.tabletopExtra.refunds` (refused, nothing changed,
  while a roulette/wheel spin or the slot reels resolve: retry once settled;
  a running blackjack round is refunded like a pickup), runs the `removed`
  hook (blackjack dealer NPC), deletes the row and the refund claims in one
  transaction, and unseats players with a notice. With *Give the item back*,
  the item goes into the owner's loaded character inventory in that same
  transaction; if the character is offline, full or busy, the row stays as
  `{returnPending=true,kind}` and the item is delivered when that character is
  next loaded (retried every 30 s while online, with a notice to free a
  slot). Other characters of the same account never receive it.

Every action needs a reason and a confirmation in the desk (commands record
`Chat command /lightrp.tables …`), is written to `lightrp_staff_audit` before
it runs and completed with its outcome, and is logged. Permissions:
`command.lightrp.tables` (list, go to) and `command.lightrp.tabledelete`
(remove), see `docs/admin-support.md`. Tests: `tools/test-tables-admin.py`.

The menu is one `open77_contextmenu` registration with **dynamic rows**
(`rows="tableMenuRows"`, open77_contextmenu 1.3.0): at each ALT click the menu
asks LightRP for this table's rows, built from the snapshot the client already
holds, and on selection asks again and runs the row only if it is still
offered. The bar works the same way: a click sends `lightrp:boardGames:action
{key}` and the client rebuilds the bar from the current state and runs the
button only if it is still offered and enabled, so a click that crosses a
phase change is dropped. Every row and button sends a request the server
already validates (`lightrp:boardGames:request` join/leave/mode/reset/pickup,
and the tabletop `game` operations through `LightRpTabletopExtraClient.command`);
nothing about the rules or the money changed. A menu costs about 750 VM
instructions to build and a bar about 800 (`tools/test-table-menu.py`); the bar
is sent to the page at most every 200 ms while seated (a few hundred bytes).

Page protocol (`lightrp:boardGames:*`): Lua sends `view` (active, kind,
title, status, tone, detail, hint, countdownMs, chip, target, actions, views,
view, orbit, camera, leaving); the page sends `pointer` (normalized cursor and
button edges, or `blocked` over the bar), `camera` (`cycle`, `view`, `zoom`),
`action`, `chip`, `leave`.

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
highlights. The cursor picking heights (`PIECE_HEIGHTS` in
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
npm --prefix ui run build && PLAYWRIGHT_MODULE=<playwright> BROWSER_CHANNEL=chromium node ui/tests/board-games.browser.cjs
```

`resources/gamemodes/op77_lightrp/tests/context_rows_test.lua` covers the
dynamic rows of open77_contextmenu and `ui/tests/context-submenus.browser.cjs`
its page (title and row tokens); `ui/tests/board-games.browser.cjs` covers the
bar for every game (buttons, chip, camera, Leave, pointer forwarding, the
hidden HUD, its size at 1280×720 and 1920×1080). Still to check in game with
actual clients: the camera framings, cursor picking through the real
`screenRay` of each view, the ALT ray on the table props (it hits the cooked
colliders; the menu falls back to the nearest table under a surface hit),
audio and native rendering.

## Roulette

Additional native props are delivered by `open77_tabletop_extra` (3 props with original textures). The launcher must download the new preload package before reconnecting. All item labels and controls are English.

- `roulette_table`: European single-zero wheel and a separately animated ball. Place whole-dollar RP cash bets, then spin. The server chooses the outcome, closes betting during the eight-second spin and stores winnings atomically. Straight numbers return 36 times the stake, dozens 3 times and even-chance bets 2 times; returns include the original stake. Zero loses outside bets. Pending winnings and refunds belong to the character inventory and survive disconnections and restarts. Resetting or retrieving a table refunds unspun stakes; both are blocked during a spin.

The roulette is a full casino table in the Night City high-roller style: a black-chrome bowl with a smoked-glass ball track and chrome deflectors, a rotor with frets, an etched number ring, a brushed cone and a chrome turret, a dark composite layout printed with 0-36, the dozens and the even chances under thin cyan lines, a chip rack, a rail and a sculpted pedestal. The board position is still the wheel centre: the table runs 2.1 m along +X (1.37 m in game) and stands 1.23 m below the wheel datum (0.80 m in game), so aim at the floor while placing: the preview stands its plinth on the aimed surface (PgUp/PgDn adjust). The ball (3 cm, 2 cm in game, faintly luminous) rides the ball track for the first half of the spin, drops over the deflectors and the number ring, then lands in its pocket and turns with the rotor. A collider entity `roulette_table_collider` follows `tools/COLLISION.md`. Preview renders: `resources/assets/models/open77_tabletop_extra/sources/preview_roulette*.png`.

The table shares placement, the game view, distance leave and owner-only retrieval with the board games. Seated, the camera opens *Overhead* (wheel and layout; also *Layout* from the players' side, *Wheel* close on the ball, *Orbit*). Click any cell of the printed layout (a straight number 0-36, a dozen or an even chance) to select it (outlined in cyan; the bar shows *17 · pays 35:1*), set the chip with − / + and press *Bet €$ 25 on 17*; repeat for more bets, then *Spin*. While the wheel turns the bar shows the countdown and no buttons; then the result (*17 Black*, *You win €$ 900*) with *Next round*. Each accepted bet and the result with your winnings arrive as notices. A click only selects: money moves only on *Bet*. The server has no bet withdrawal, so there is no *Clear*. There is no numerical placement limit. Ordinary distance and overlap checks still apply.

Admin item command:

```text
/lightrp.giveitem me roulette_table 1
```

Validation: `tools/test-tabletop-extra.py`, `tools/test-tabletop-extra-client.py` (layout picking, matched against the cooked layout), `tools/test-tabletop-extra-server.py`, `tools/build-tabletop-extra-props.py --verify-only`, `tools/test-table-menu.py` (the bar) and `tools/test-casino-e2e.py roulette`. Server tests cover atomic cash debits, failed storage, exactly-once payouts after restarts, offline refunds and recycled player IDs.
