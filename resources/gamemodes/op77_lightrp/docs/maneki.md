# Maneki-neko collectibles

Lucky cats hidden by the staff around Night City. A player finds them by looking:
there is no blip, no marker, no list and no hint. Each character finds each cat once.

| Piece | Where |
|---|---|
| Rules and rewards | `server/config/maneki.lua` (`LightRpManeki`) |
| Storage, streaming, collecting, staff desk, `/lightrp.maneki` | `server/modules/maneki.lua` |
| Local props, E prompt, shot detection | `client/core/maneki.lua` |
| Staff placement tool | `client/core/maneki_editor.lua`, page `ui/src/features/maneki/ManekiTool.tsx` |
| Staff desk menu | `ui/src/features/support/ManekiTools.tsx` + `SupportDesk.tsx` |
| Visual host (the game's own cat) | resource `open77_maneki`, built by `tools/build-maneki-props.py` |
| Tests | `tests/maneki_test.lua` (server), `tests/maneki_client_test.lua` (client) |

## The model

The game's waving cat, `base\environment\decoration\misc\sculptures\chinese_sculpture_small\chinese_sculpture_small_c.mesh`
(9 × 12 × 16 cm, the one on Japantown shop counters). On 2.31 a prop cannot take a mesh
at runtime, so `open77_maneki` ships one authored entity,
`open77\assets\op77_lightrp\maneki\maneki_neko.ent`, that binds that vanilla mesh. The
archive holds the `.ent` only: no game asset is copied. The cat looks along its own −Y,
so its face points at yaw + 180°.

## What a player sees

- The server sends each player the cats **their character has not found**, within
  `streamRadius` (140 m) of the player's server-side position, nearest first, at most
  `maxStreamed` (40). A player never receives the whole list, and never a found cat.
- Each streamed cat is a **client-local prop** (`Open77.props.create` on the client):
  nobody else sees it, it has no collision, and it disappears for that player alone.
- **E:** a private prompt "Take the Maneki-neko" at 1.8 m (`LightRpInteract.setLocal`).
  The server accepts within `takeRadius` (4 m, its own position feed).
- **A shot:** while the trigger is held with a weapon drawn (`Open77.character.aimState`,
  permission `player.aim.read`; older clients: the left mouse button), the camera ray is
  tested against a sphere around every cat within 85 m. A static `aimRay` shorter than the
  cat's distance means a wall is in between: no shot. The server accepts within
  `shotRange` (90 m) and refuses when its weapon cache says no weapon is in hand.
- The server only accepts a cat it streamed to that player (no blind collection by id),
  writes the find with `INSERT IGNORE` (a find is paid once even across sessions), then
  pays: `reward.cash` per find, `milestones` at 10 / 25 / 50, the **Lucky Cat** title
  (`server/config/titles.lua`, group Collections) for the whole set once at least
  `completeMin` (10) cats exist. Money goes to the bank, ledger kind `collectible`.
- The F1 menu shows **Maneki-neko found / total** (state key `maneki`), never where.
- A find plays a small burst (`neon.loot_drop`, `sparks.burst.small` for a shot) and the
  game's money jingle (`ui_jingle_achiev` for the whole set).

## Staff

ACL (`server/config/support.lua`): `command.lightrp.maneki` lists and visits,
`command.lightrp.manekiedit` places, removes and resets one's own collection
(moderators and operators have both through `command.lightrp.*`; helpers have neither).

**Staff desk** (`/lightrp.admin` > Maneki-neko): the list (newest or nearest, search by
id / district / author), find counts, "Go to this cat" and "Remove this cat" (reason +
confirmation, written to `lightrp_staff_audit`), "Reset my own collection" for testing,
and **Placement tool**, which closes the menu and starts the in-world tool:

| Key | |
|---|---|
| aim | a ghost cat sits on the surface under the crosshair, facing you |
| LEFT CLICK | hide a cat there (floors, shelves, ledges; refused on steep surfaces, within 0.6 m of another cat, or further than 80 m from you) |
| ← / → | turn 15° |
| ↑ / ↓ | size: game size (16 cm), ×1.5, ×2, ×3 |
| DELETE | remove the aimed cat |
| BACKSPACE | leave the tool |

While the tool runs, the server streams every cat around (found ones included) and each
gets a marker (gold: not found by you, green: found). Attack, melee and grenades are
claimed so a click never fires. Every placement and removal is audited.

**Chat:** `/lightrp.maneki [page | near]`, `tool`, `tp <id>`, `delete <id>`,
`here [size]` (at your feet), `reset`.

## Storage

- `lightrp_maneki_spots` (id, position, yaw, scale, bucket, district, placed_by,
  created_at, deleted_at). A removal is a soft delete: past finds keep their row.
- `lightrp_maneki_finds` (identifier, character_key, spot_id, method take/shot, found_at).
  The totals count only live cats.
- Without a database the cats placed live for the session only.

## Limits

- 600 cats (`maxSpots`); a client is sent at most 40 at once (one plain net event stays
  under the 1,024-value cap: 40 × 13 values).
- A new or changed `open77_maneki` archive needs players to restart the game once.
