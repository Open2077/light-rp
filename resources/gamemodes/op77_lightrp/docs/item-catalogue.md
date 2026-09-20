# RP item catalogue

`shared/items.lua` is the authoritative template catalogue: 30 items, including
18 illustrated food, drink and medical consumables. Existing identifiers stay
unchanged; saved inventories need no migration. New characters start with only
5 bottles of water and 5 burritos, configured in `shared/config.lua` under
`inventory.starting`. The grant happens once when their inventory is created;
existing inventories are not replaced or refilled. No shop or job reward is added.

## Illustrated consumables

Values are restored **per unit**, capped by the corresponding needs/health system.
Health items work on living characters; they do not revive dead characters.

| ID | Name | kg | Stack | Food | Hydration | Health |
|---|---|---:|---:|---:|---:|---:|
| `burrito` | Burrito | 0.40 | 10 | 35 | — | — |
| `synthmeat` | Synth-Meat Skewer | 0.30 | 10 | 25 | — | — |
| `apple` | Apple | 0.20 | 20 | 12 | 5 | — |
| `candy` | Candy Bar | 0.10 | 20 | 8 | — | — |
| `noodles` | Street Ramen | 0.50 | 8 | 40 | 5 | — |
| `dumplings` | Dumpling Box | 0.35 | 8 | 30 | — | — |
| `pizza` | Synth-Pepperoni Slice | 0.30 | 10 | 28 | — | — |
| `onigiri` | Onigiri | 0.15 | 15 | 18 | — | — |
| `proteinbar` | Protein Ration | 0.12 | 20 | 22 | — | — |
| `water` | Bottle of Water | 0.50 | 10 | — | 30 | — |
| `soda` | NiCola | 0.40 | 10 | 5 | 20 | — |
| `coffee` | Synth-Coffee | 0.30 | 8 | — | 18 | — |
| `energydrink` | Volt Energy | 0.35 | 10 | 4 | 22 | — |
| `electrolyte` | Electrolyte Mix | 0.50 | 10 | — | 40 | — |
| `juice` | Citrus Blend | 0.25 | 12 | 6 | 25 | — |
| `bandage` | Bandage | 0.20 | 10 | — | — | 25 |
| `medkit` | MaxDoc inhaler | 0.60 | 5 | — | — | 70 |
| `firstaid` | Field First Aid Kit | 1.00 | 3 | — | — | 45 |

Coffee/energy drinks currently restore needs only: no unstated stamina buff,
status effect or addiction mechanic. These are configurable RP items and newly
generated illustrations, not extracted vanilla game assets or canonical balance.

The other 12 existing items keep their vector icons: `cigarettes`, `lighter`,
`phone`, `idcard`, `watch`, `wrench`, `repairkit`, `battery`, `scrap`, `documents`,
`keycard`, `trashbag`. Tool-specific gameplay is not added by this catalogue.

## Adding an item

Add its template to `shared/items.lua`. Place a transparent PNG/WebP in
`ui/public/img/items/`, then set `image = "img/items/your_item.png"` in the template.
Names use lowercase ASCII letters, digits, hyphens or underscores. Retain `icon`
as a fallback for missing artwork. Rebuild with `npm run build` in `ui/`.

Vite copies assets to `web/img/items/`, included by the resource's `web/**`
manifest rule. No external image host or CDN is required. The inventory uses the
same image in slots, detail view and drag previews. Arbitrary remote paths and
metadata image overrides are not loaded. Displayed effects come from the server
template; the client never decides item grants, quantities or applied effects.

The built-in image generator was used for all 18 PNGs; see the exact
[prompt set](item-art-prompts.md). Original alpha channels are preserved.

## Try it

Browser-only visual preview (does not grant items):
`http://127.0.0.1:5177/?registered=1&items=1`

In game, an authorized staff member can use existing commands:

```text
/lightrp.items
/lightrp.giveitem me noodles 2
/lightrp.giveitem me firstaid 1
```

These require their normal `command.lightrp.*` ACL permissions. Press **I** to
open the inventory and select an item to see its image, effects and actions.
Restart the resource/server and reconnect after updating the built package.

## Tests

From the LightRP root:

```powershell
pwsh -File resources/gamemodes/op77_lightrp/tests/run-lua.ps1 -Test items_test.lua
```

From `ui/`, with Vite running and Playwright available via `PLAYWRIGHT_MODULE`:

```text
node tests/items.browser.cjs
node tests/inventory.browser.cjs
```

Checks: template counts, packaged images, actual transparency, stack splitting,
server consumption/effects/death checks, metadata isolation, responsive art bounds,
missing-asset fallback, and the existing inventory interaction regressions.
