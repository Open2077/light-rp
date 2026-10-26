# NPC shops

Walk up to the vendor and press **E**. Browse illustrated items, search, filter by
category and build a basket. The checkout shows quantities, total, cash/bank and
inventory weight after the transaction. Nothing changes until **Confirm purchase**
or **Confirm sale**. Escape closes the shop and releases input. The voice overlay
is suppressed only while shopping and respects other HUD visibility claims.

The first vendor is **Corner Market / City Center**, at
`(-667.559082, -378.390808, 9.193733)`, yaw `-125.597023` (the supplied quaternion
is retained in configuration; the native NPC creation API receives the equivalent
yaw). It sells 15 foods/drinks using the existing inventory illustrations and
uses the native `food` blip (`ServicePointFoodVariant`). Invalid/missing icons
fall back to a neutral `objective` blip, never a vehicle icon.

## Templates and locations

All configuration is **server-only**, in `server/config/shops.lua`.

- `templates` owns the catalogue, display text and allowed payment methods.
- `locations` owns NPC placement and references a template **by ID**.
- No copy of the catalogue is stored on an NPC. Every checkout reads the current
  template. Adding a second location with `template = "street_food"` shares the
  same items/prices automatically.
- Editing the file takes effect after restarting the server/resource and
  reconnecting (the resource uses `reload_policy "reconnect"`). For a live change
  from another server module in this gamemode, use `LightRP.shops.setTemplate`.

```lua
-- Another template, e.g. a medical supplier:
LightRpShops.templates.clinic = {
    label = "Street Clinic",
    subtitle = "Be ready for your next shift.",
    payments = { "cash", "bank" },
    items = {
        { name = "bandage", buy = 25, sell = 5 },
        { name = "firstaid", buy = 120 }, -- buy only
    },
}

-- Add a location in LightRpShops.locations, substituting your own coordinates:
-- { id = "clinic_west", template = "clinic", name = "Clinic / West",
--   position = { x = ..., y = ..., z = ... }, yaw = 90, bucket = 0,
--   npc = { record = "Character.mws_thenerves_driver_01" },
--   blip = { sprite = "meds", description = "Medical supplies" } }
```

`name` must exist in `shared/items.lua`. Labels, weights, stack limits, effects and
images come from that item registry. All prices are **positive whole eddies**:

| Field | Meaning |
| --- | --- |
| `buy` | Unit price paid by the player |
| `sell` | Unit price received by the player |
| omitted price | This direction is unavailable |

A template refuses duplicate/unknown item names, invalid prices, empty payment
methods and a resale price higher than its own purchase price. Balance prices
across **different templates** yourself: arbitrage between two traders can be
intentional. Shops have **unlimited supplies**; there is no finite-stock or vendor
budget simulation. Up to 100 offers/template, 12 distinct basket lines and 20
units/item by default (basket limits configured globally).

The sale view starts with owned, accepted items. Only items with no custom
metadata (or empty metadata) can be sold. Personalised documents, custom labels,
unique equipment and similar items are never silently sold as ordinary goods.

## Live template updates

```lua
local ok, reason = LightRP.shops.setTemplate("street_food", {
    label = "Night City Market",
    subtitle = "Today's essentials.",
    payments = { "cash", "bank" },
    items = {
        { name = "water", buy = 8, sell = 2 },
        { name = "burrito", buy = 18, sell = 5 },
    },
})
```

This **replaces the complete template** in memory. Every linked NPC uses it
immediately; active viewers receive the revised catalogue and clear their old
baskets. Checkouts containing an older revision are refused with updated prices
for review. An already-started checkout settles at the prices accepted before
the update. Runtime edits are not written back to the config file.

`LightRP.shops.open(playerId, locationId)` opens an existing location only after
all proximity, bucket, character, life and database checks; it is not a remote
shop bypass. `setTemplate` and `open` are internal server-module APIs, not public
client exports. NPCs are created by the native server API, invulnerable and with
AI/perception/combat disabled. A failed NPC spawn closes that shop and logs why.

## Checkout safety and persistence

The browser sends a session, sequential request number, catalogue revision,
direction, payment method and `{name, count}` lines. It never sets prices, totals,
inventory IDs, receiving players or metadata.

The server revalidates active character, life, bucket, distance (2.5 m + 0.5 m
network tolerance), session, allowed offers, integer quantities, money, slots and
weight. A basket succeeds **in full or not at all**. Wallet and inventory remain
locked across yielding database calls; using, giving, dropping or moving items
cannot interleave with a checkout. Character switching is also blocked during
settlement. Sessions are cleared on disconnect/death/character change and close
when the player leaves the vendor or after 3 minutes of inactivity.

`LightRP.db.transaction` uses `MySQL.transaction.await` to commit all three writes:

1. Wallet balance.
2. Complete inventory snapshot.
3. Receipt in `lightrp_transactions` (`shop_buy` / `shop_sell`, trader, item counts,
   payment method, signed amount and balance after).

Caches change only after success. The normal economy HUD/history and inventory
receive the committed state. Replaying the last acknowledged request returns its
receipt without charging again; older/out-of-order requests close the session.
Shop balances and inventory capacity refresh while browsing when their server
state changes. An unanswered checkout stays blocked in the UI rather than being
automatically repeated. Close/reopen to check the outcome.

**A working database and transaction bridge are required.** Shops deliberately
refuse trading in session-only/offline mode. Existing tables are reused: no schema
migration or new permissions are needed.

## Validation and preview

From the resource folder:

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -Test shops_test.lua
```

From `E:/Open77/LightRP/ui`:

```powershell
node --test tests/shop-model.test.ts
node tests/shop.browser.cjs
npm run build
```

For browser tests, point `PLAYWRIGHT_MODULE` at an installed Playwright module if
needed; `UI_URL` defaults to `http://127.0.0.1:5177`. With Vite running, the visual,
interactive preview is `http://127.0.0.1:5177/?registered=1&dialog=shop`.
Preview trades use mock money/items only. Lua tests exercise the real three modules
with mocked SQL/native boundaries; browser tests use the real React page and
simulated bridge. In-game NPC appearance/placement and real database integration
are left for the user's game tests.
