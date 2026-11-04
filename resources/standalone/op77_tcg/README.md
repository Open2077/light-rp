# op77_tcg — Cyberpunk TCG collection

A standalone Open77 resource: collect the 320 editions (151 cards) of the Cyberpunk Trading Card Game. It needs no
gamemode, and any server can load it.

## What players do

- **Sealed product.** Players get Welcome to Night City and Beta Edition boosters (12 cards each), plus Booster
  Displays of 24 packs. New collectors receive 3 starter packs. Sealed product is shown in the binder's **Sealed**
  tab. A display is opened for real: run the blade along the line (or click / Space) to cut its shrink-wrap, the two
  halves of plastic fall away and the 24 packs come out onto the shelf; pick one to open it at once.
- **Opening a pack, for real.** The opener holds the 3D booster in the right hand, and everyone within 40 m sees it.
  - On the opener's screen, the pack follows the mouse (foil shine, tilt). A swipe along the dashed line under the
    crimp tears it little by little: the strip lifts, light leaks through, the wrapper crackles. Let go and the tear
    stays where it got; a click or Space tears it in one go. The rip is also played in 3D for the people around.
  - The 12 cards slide out of the pack face down. Each click or Space flips the next card and sends the previous one
    to its slot in the tray at the bottom of the screen (with NEW / rarity marks). A counter shows the progress.
    Uncommon and better cards chime and spark; Rare gets a banner, Epic and above a flash.
  - The rare slot comes last: the hidden card glows in its rarity's colour and you **hold** to reveal it. The glow,
    the rays and a ring charge up; letting go cools it down. Then a flash, a shake, a burst, the rarity banner, and a
    rain of gold for Nova Rare / Iconic and Secret.
  - The pack summary shows the hit in large, the other 11 cards, and the new / duplicate counts. "Reveal all" skips.
  - Sounds of the opening are made by the page (WebAudio), no asset needed.
  - Optional (`TcgConfig.opening.physical`, off by default): at the same pace, the real 3D cards are dealt on the
    table in front of the opener for everyone around (four columns by three rows, the premium card alone in front),
    or fan out in the hand, with the pack in the hand and an over-the-shoulder camera for the opener.
  - The cards stay on the table for 30 s, then go into the binder. They are written to the database before the first
    reveal, so a crash never loses or duplicates a card.
- **The binder** (`/tcgbinder`; in LightRP also the F1 menu, "TCG binder"). It is a ring album with 3x3 sleeved pages, page turns, plastic gloss and finish
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
  shops with `/tcg.shop here [label] [yaw]`. Standing at the counter, `/tcgbinder` opens the **Shop** tab:
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
exports.op77_tcg:useSealed(playerId, "box")         -- a gamemode's inventory item: open it on the player's screen
```

## With a gamemode (LightRP)

`TcgConfig.framework` names a gamemode resource (`op77_lightrp` by default). When it runs:

- **Each character is a collector**, with its own binder, Dust and starter packs. The resource asks the gamemode's
  `characterIdentity(playerId)` export, and rebinds on its `<framework>:characterReady` and `:characterChanged`
  events. A player has no collection until a character is loaded.
- **Sealed product lives in the gamemode's inventory.** In LightRP these are the items `tcg_booster_wnc`,
  `tcg_booster_beta` and `tcg_display_wnc`, sold by the NEON DECK vendor in Kabuki. The resource reads them with
  `tcgSealed(playerId)`. It takes and gives them with `tcgTakeSealed` / `tcgGiveSealed` through
  `Open77.exports.call`, because those writes reach the database and must not run as a synchronous export.
- **Using an item** calls `useSealed`, and the player's screen opens it for real: a booster tears in the hands, and
  a display has its shrink-wrap cut. The item is taken only when the pack is torn or the wrap is cut. If a display
  does not fit the bag (24 boosters), it stays sealed, and the page puts its plastic back.
- **The binder's Sealed tab shows the inventory.** The TCG counter keeps its printer and recycler, and points to the
  vendor for sealed product.
- **The page raises the local client event `op77_tcg:focus`** whenever it takes the mouse. LightRP closes its
  inventory on it.

Without the gamemode (or with `framework = nil`), collections are per account, and the binder keeps its own sealed
shelf.

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

The binder and the opening show the official renders of cyberpunktcg.com (733 x 1024) rather than the in-game
textures. `tools/fetch_official.py <resource> <work dir>` downloads the English printings from the NetDeck card API
behind that site and matches each edition to its printing by comparing pictures (the mod's art variants are
different printings). It writes `web/img/cards/<id>.webp` and a `report.json`.

The source meshes are about 6 times the size of a real card, so the resource scales them to real size (63 x 88 mm):
`TcgConfig.scale`.

Card art and the TCG brand belong to CD PROJEKT and WeirdCo. Before distributing the 3D assets to players, check the
mod's distribution permissions on Nexus.

## Tests

`python tools/test_server.py` (needs `lupa`) runs the real server script against stubbed natives and an in-memory
SQLite database. It covers the starter packs, an opening (persisted before it is shown, the witnesses, the reveal
relay), a shop, recycling, printing, the free-pack cooldown, a display box, a trade, showing, placing and picking up
a card, and the exports. `python tools/test_framework.py` runs the same script with a fake gamemode: character
collectors, starter items, `useSealed`, an opening and a display through the inventory, the no-room refund, the
counter deferring to the vendor, and a character switch.

`web/index.html` also runs in a plain browser as a preview with a demo collection: `?tab=sealed`, `?tab=shop&shop=1`,
`?open=1&reveal=12`.
