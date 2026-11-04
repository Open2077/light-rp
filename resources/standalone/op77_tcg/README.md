# op77_tcg — Cyberpunk TCG collection

A standalone Open77 resource: collect the 320 editions (151 cards) of the Cyberpunk Trading Card Game. It needs no
gamemode, and any server can load it.

## What players do

- **Sealed product.** Players get Welcome to Night City and Beta Edition boosters (12 cards each), plus Booster
  Displays of 24 packs (you cut the shrink-wrap). New collectors receive 3 starter packs. Sealed product is shown in
  the binder's **Sealed** tab.
- **Opening a pack, for real.** The opener holds the 3D booster in the right hand, and everyone within 40 m sees it.
  - On the opener's screen, a drag across the top tears the pack, with the sound played in 3D for the people around.
  - The opener then reveals the cards one by one with Space or a click. At the same pace, the real 3D cards are
    dealt on the table in front of them: four columns by three rows, with the premium card alone in front. The cards
    slide out of the hand.
  - With no table, the cards fan out in the hand.
  - The rare slot comes last, after a suspense shake. It gets a rarity banner and burst on screen, and a flash of
    the rarity's colour on the table (Epic and above).
  - The cards stay on the table for 30 s, then go into the binder. They are written to the database before the first
    reveal, so a crash never loses or duplicates a card.
- **The binder** (F9, `/binder`). It is a ring album with 3x3 sleeved pages, page turns, plastic gloss and finish
  effects:
  - holographic foil from the set's own spectrum map, following the mouse;
  - golden sheen on premium cards and brushed metal on metal cards;
  - a hue-shifted holo on Secret cards.

  Missing cards show as numbered silhouettes. You can filter by rarity, finish, owned, missing or duplicates, and
  search by name. Completion counts both editions and base cards.
- **A card in your hands.** Inspecting a card tilts it in 3D and shows its set number, finish, copies and
  population (how many were pulled on this server). From there you can:
  - **show it in hand:** a 3D card in the right hand, with its name over your head for the people around;
  - **lay it on the table:** a real card on the surface in front of you, picked up from the binder, 8 at most per
    player for 30 min;
  - **give it** to a collector next to you, who accepts or declines.
- **TCG shops.** A counter with the card printer, the recycler, the card loader and a collection shelf. Admins place
  shops with `/tcg.shop here [label] [yaw]`. Standing at the counter, F9 opens the **Shop** tab:
  - Buy sealed product. Without an economy, the shop gives one free pack every 20 minutes. With one, set
    `economy.resource` and `economy.charge`.
  - Recycle duplicates into Dust. One copy always stays in the binder, and top-tier cards also give Dust+.
  - Print a missing edition for Dust. Secret cards cost Dust+.

## Rarity

The pack rules are those of the original set: **9 Common, 2 Uncommon, 1 premium slot**. The premium slot is a Rare
80% of the time, an Epic 18%, and a top-tier card (Nova Rare, Iconic Legend or Iconic Other) 2%. A top-tier pull
prefers an edition you do not have yet. A base card never appears twice in the same pack.

| Tier | Editions | Recycle | Print |
|---|---|---|---|
| Common | 61 | 5 Dust | 40 Dust |
| Uncommon | 37 | 10 | 80 |
| Rare | 51 | 25 | 200 |
| Epic | 29 | 60 | 500 |
| Nova Rare / Iconic | 134 | 150 + 1 Dust+ | 1600 |
| Secret (never in packs) | 8 | 400 + 1 Dust+ | 3 Dust+ |

There are four finishes: sleeved, foil, premium and metal. Each edition has its own 3D card.

## Admin (ACL `command.tcg.*`)

| Command | Effect |
|---|---|
| `/tcg.give <playerId> <wnc\|beta\|box> [count]` | Gives sealed product. |
| `/tcg.card <playerId> <editionId>` | Gives an edition. Ids are in `shared/catalogue.lua`. |
| `/tcg.dust <playerId> <amount>` | Adds or removes Dust. |
| `/tcg.shop here [label] [yaw] \| remove <id> \| list` | Manages shops, which are stored in the database. |

## Exports (server)

```lua
exports.op77_tcg:giveBooster(playerId, "wnc", 2)   -- mission loot, rewards
exports.op77_tcg:giveCard(playerId, "a0b083a4f")
local c = exports.op77_tcg:getCollection(playerId)  -- { dust, dustPlus, sealed, editions, cards, totalEditions, totalCards }
```

## Data

`data/tcg.db` (SQLite) holds the profiles (Dust, Dust+, the free-pack clock), sealed product, cards per durable
player identifier, the server population, the pull log and the shops.

## Assets

The 3D cards, boosters, boxes, machines and shelves come from the **Cyberpunk TCG Collectibles** mod
(Nexus 34654, v1.1). Its archives are repacked into four preload packages under 256 MiB each, the server's limit:
`dist/op77_tcg_1..4.zip`, about 580 MiB in total. Players download them once, on their first connection.

The zips are not in git. Rebuild them, along with the catalogue and the images:

```powershell
pwsh tools/build-assets.ps1 -ModZip "<path>\Cyberpunk TCG Collectibles 34654 1.1 ....zip"
```

The source meshes are about 6 times the size of a real card, so the resource scales them to real size (63 x 88 mm):
`TcgConfig.scale`.

Card art and the TCG brand belong to CD PROJEKT and WeirdCo. Before distributing the 3D assets to players, check the
mod's distribution permissions on Nexus.

## Tests

`python tools/test_server.py` (needs `lupa`) runs the real server script against stubbed natives and an in-memory
SQLite database. It covers the starter packs, an opening (persisted before it is shown, the witnesses, the reveal
relay), a shop, recycling, printing, the free-pack cooldown, a display box, a trade, showing, placing and picking up
a card, and the exports.

`web/index.html` also runs in a plain browser as a preview with a demo collection: `?tab=sealed`, `?tab=shop&shop=1`,
`?open=1&reveal=12`.
