# Physical cash

`cash` is a normal inventory item: **one unit = €$1, weight = 0 kg**, stack limit
1,000,000,000. It can be split, merged, dragged, given, dropped and stored. It is
not consumable. Its image is `img/items/cash.png` (source in `ui/public/img/items/`).
The exact value remains available in the details; large grid amounts use compact
notation. The quantity field supports a full 10-digit stack.

## Single source of truth

Cash lives exclusively in `lightrp_inventories.items`. `Money.get(id).cash` is a
projection of the active character's pocket inventory, not another balance.
Cash in a trunk, ground pile or stash cannot pay a shop, rental or fuel bill.
Bank balances remain in `lightrp_wallets.bank`.

- Existing `LightRP.money.addCash/removeCash`, `/pay`, staff grants and money UI
  continue to work, now by adding/removing the item.
- Deposits remove pocket items and credit the bank in one SQL transaction.
  Withdrawals do the reverse. A full inventory refuses the withdrawal without
  charging the bank. Cash can still enter an overweight inventory (zero weight).
- Shops, paid jerrycans and vehicle purchases commit items/ownership/payment and
  receipts together. Spending the last cash pile can free a slot for a purchase.
- Inventory moves use detached drafts and one transaction for both persistent
  inventories plus cash ledger entries. Notifications follow the commit. Failures
  keep original contents; per-inventory locks cover awaited SQL and disconnects.
- Plain bank-only transfers retain the pre-existing bank implementation.
- Storage follows its existing lifecycle: personal-vehicle trunks and stashes
  persist; temporary vehicle trunks and ground piles remain session-only. Ground
  piles still expire per `inventory.drop.ttlMinutes`; cash does not override this.

Do not write `wallet.cash`, the legacy SQL cash column, or inventory tables from
other modules. Use `LightRP.money.*` or the inventory API. Do not sell the `cash`
template as a commodity: `Inv.trade` explicitly refuses it.

## Existing characters / migration

The inventory module loads **before** economy. Each active character is migrated
on their next load. New wallets go through the same one-time path so starting
cash is delivered exactly once, independently of the 5 water / 5 burrito grant.

One transaction:

1. Inserts `lightrp_cash_migrations`, keyed uniquely by account number, containing
   the old cash amount, inventory ID, complete pre-migration item JSON and slots.
2. Persists the inventory including the converted cash.
3. Sets the legacy `lightrp_wallets.cash` column to zero.

An already migrated account never receives its old money again. A failed read or
write blocks money operations instead of treating failure as an empty wallet.
For an existing full inventory only, migration adds enough recovery slots to keep
both its items and cash; the enlarged slot count survives reconnects. Subsequent
withdrawals/rewards do not expand capacity.

Back up wallets, inventories and transactions before deployment. Keep the
migration table: it is both the recovery record and the idempotency guard. Never
delete it or simply roll back to the old economy code after conversion. Rollback
requires stopping all writers and reconciling current pocket cash into balances;
restoring an old snapshot after players have traded would lose those trades.
Only one server process should own/write a given LightRP database.

## Validation

- `tests/cash_test.lua`: real Lua modules with transactional SQL model; migration,
  snapshot backup, rollback/retry, full inventory, new character, reconnect,
  cash/bank conversion, buy/sell, external payments, storage, gifts, splits,
  ground pickup, invalid amounts, concurrent requests and in-flight disconnect.
- Regression suites: shops, dealerships, garages, job runs, items, refueling.
- `ui/tests/cash.browser.cjs`: real React UI; artwork loading, exact/compact values,
  zero-weight label, 10-digit transfer payload and 720p/1080p/1440p layouts.
- `npm run build` produces the WebUI distributed with the gamemode.

Artwork generated with the built-in image_gen tool using the `imagegen` skill;
the final prompt is in [item-art-prompts.md](item-art-prompts.md#cash--2026-09-24).

### Local verification, 2026-09-24

Build, the nine targeted Lua suites and the browser cash scenario passed.
Pre-deployment backup (2 wallets, 2 inventories, 60 ledger rows) was saved and
read back at `data/backups/cash-before-migration-20260924-flat.clixml` (untracked).
The local MySQL migration table was created successfully; the connecting
character was migrated once with its existing zero balance. The other offline
character's 4 eddies remain untouched until their next load.

Live validation followed the repository's `open77-testing` skill, but **did not
reach gameplay**. Connection failed independently of the cash code during client
resource activation: `open77_wardrobe_ui` reports
`invalid_web_file:web/icons/f/Items.Proficiency_CasualShoes_07_basic_01_Crafting.webp`.
The cached path is exactly 260 characters (path-limit hypothesis, not proven).
Further inspection confirmed a concurrent `wardrobe_images_patch.py` process
rewriting the source icons, with source/cache hashes differing and a later server
restart failing on an icon held open by that process. This is external work;
no wardrobe/client-loader changes or interference with that writer were made.
Do not describe the cash flow as end-to-end game-tested until that blocker clears.

Follow-up at 01:14 local time: the wardrobe blocker was isolated to Windows
MAX_PATH with an MSVC native filesystem probe (source/cache bytes now match).
The installed wardrobe package's 3,580 icons were backed up, renamed to short
deterministic filenames and remapped without modifying image bytes. After
restarting LightRP, the unchanged client activated all resources, completed a
new pristine bootstrap, and entered the rendered world with the LightRP HUD.
This validates reconnection and resource activation, not a complete live cash
transfer/deposit/withdrawal scenario; the cash flow coverage above remains
automated Lua and browser coverage.

The broader Lua sweep also exposes two unrelated existing fixture mismatches:
`creator_bridge_test.lua` does not recognize the animation voice-HUD blocker;
`rental_test.lua` expects a stock count different from the current rental fixture.
Neither production subsystem was changed to accommodate those old assertions.
