# Vehicle rental UI and image bank

The rental desk uses the same quiet charcoal/yellow UI as the inventory: a photo
catalogue, search, category filters and price/name sorting, with a separate
reservation summary. Selecting a card does not spend money. The explicit confirm
button sends `rental.rent`; the server still decides stock, price, proximity,
character/life state, funds and vehicle delivery. The browser never deducts money.
Failed delivery retains the existing server refund behaviour.

Cash and bank balances stay visible, with an exact shortage message. The browser
locks submission while waiting, ignores stale/unrelated action results, displays
server errors in the summary and releases focus on closing. A timeout asks the
player to reopen the desk to check the authoritative rental state, not resubmit
blindly. The current rental view displays the remaining time and requires an
explicit confirmation before returning/removing the vehicle (no fee refund).

## Configuration

The agency stock, prices, spawn position and duration remain in `shared/config.lua`.
The default desk still offers its same five vehicles for the same prices and
30-minute duration. Semimaru's category is corrected from `Bikes` to `Sport`.
No vehicles or artificial performance stats are added to the live desk.

## Local image bank

18 vehicle screenshots are stored in `ui/public/img/vehicles/`, copied by Vite to
`web/img/vehicles/`. No external image request is made by the in-game page. The
mapping and individual source URLs are recorded in
`ui/src/features/rental/vehicle-images.json`.

Covered keys: `hella`, `bandit`, `quartz`, `cortes`, `colby`, `galena`, `maimai`,
`hozuki`, `thrax`, `supron`, `columbus`, `merrimac`, `semimaru`, `kusanagi`,
`apollo`, `type66`, `shion`, `caliburn`.

Sources: [VULKK vehicle catalogue](https://vulkk.com/2024/02/02/cyberpunk-2077-vehicles-complete-catalog-and-guide/),
downloaded 2026-09-20. Screenshot credit: VULKK. Game/vehicle designs: CD PROJEKT RED.
These are existing in-game photos, **not AI generations**, and are not claimed as
original LightRP artwork or relicensed under the code licence. Check the image
owners' terms/permissions for any subsequent redistribution. The UI keeps a
source credit and notes that paint/appearance can vary from the rented vehicle.

The current catalogue keys use this bank automatically. To override an image for
one agency (or a custom vehicle), supply a local path on its stock entry:

```lua
stock = {
    { key = "hella", price = 120, image = "img/vehicles/my-hella.webp" },
}
```

An `image` field on the corresponding `vehicles.catalog` entry is also supported;
the agency's override wins. Place the file in `ui/public/img/vehicles/`, rebuild
the UI, then reload the resource/server. Supported names: lowercase letters,
digits, hyphens/underscores, and `.jpg`, `.jpeg`, `.png` or `.webp`. Remote URLs,
path traversal and other directories are rejected by the UI. Unknown vehicles or
missing images use a neutral car glyph and “Preview unavailable”.

## Verification

Browser preview: `http://127.0.0.1:5177/?registered=1&dialog=rental`.
Add `&rental=1` to inspect an active rental. Mock-only; no game money is used.

From `ui/`:

```text
npm run build
node --experimental-strip-types --test tests/rental-model.test.ts
node tests/rental.browser.cjs
```

Browser tests use Playwright (`PLAYWRIGHT_MODULE` may point to an existing install).
They cover search/sort, affordability, stale replies, booking/return, focus/CEF
Escape, empty Lua tables, missing images, all 18 local assets and four resolutions.
Server tests: `pwsh -File tests/run-lua.ps1 -Test rental_test.lua` from the resource.
