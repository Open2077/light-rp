# Inventory grenades

Nine counted inventory items are projected through the finite consumable-charge API:

| Item ID | Native record |
|---|---|
| `grenade_frag` | `Items.GrenadeFragRegular` |
| `grenade_emp` | `Items.GrenadeEMPRegular` |
| `grenade_incendiary` | `Items.GrenadeIncendiaryRegular` |
| `grenade_biohazard` | `Items.GrenadeBiohazardRegular` |
| `grenade_cutting` | `Items.GrenadeCuttingRegular` |
| `grenade_recon` | `Items.GrenadeReconRegular` |
| `grenade_smoke` | `Items.GrenadeSmokeRegular` |
| `grenade_flashbang` | `Items.GrenadeFlashRegular` |
| `grenade_ozobs_nose` | `Items.GrenadeOzobsNose` |

## Using grenades

Select an item in your pockets and press **Select grenade**. Selection preserves
the inventory count and equips its native throw slot. Use the game's throw
control to throw it; fresh native consumable-charge readbacks remove the spent units from
the inventory. The last throw clears the selection automatically. The middle equipment column shows the selected type and owned
count, with **Unequip grenade** and **Synchronize grenades** controls. Native
weapon wheels and quick-slot cycling stay blocked. Safezone grenade input claims
compose with the inventory's readiness/stock claims.

Grenades weigh 0.4 kg and stack to ten per slot. Total stock is limited to 999
per type. Unequip before transferring, removing or adding selected stock.
Grenades can move between slots without changing their total quantity. Ground
piles and temporary trunks are excluded; unequipped stock uses durable storage.
Staff can grant, for example, `/lightrp.giveitem me grenade_frag 3`.

## Durable ownership and native projection

`shared/grenades.lua` defines the nine verified records and local item art.
`server/modules/grenades.lua` stores selected item/revision in
`lightrp_grenades`, with idempotent selection receipts in
`lightrp_grenade_operations`. Quantities remain in the ordinary inventory JSON.
`Inv.commitDrafts` commits observed consumption and grenade state together;
a failed transaction leaves the authoritative cache untouched.

The module shares the weapon controller's authenticated native completion queue,
player/incarnation checks and timeout quarantine. Only one writer runs at a time.
Before a selection, switch or resync it reconciles the previous projection.
It then configures only the `grenade` kit with the selected record, exact owned
`count`, explicit `capacity`, `equipped` status and `recharge=false`, using
`Open77.consumables.configure`. Its typed completion must verify the charge count,
equipment, managed state and regeneration policy. Healing charges are untouched. Queue acceptance alone is not success.
A repeated selection reconciles then replaces usable charges; it does not refill spent inventory stock. A partial failure can be retried without crediting or refunding items.

The reserved `onConsumableUsed` event for `kind="grenade"` marks the projection
dirty. The inventory is reconciled from complete, fresh, correlated
`Open77.consumables.snapshot(...,"grenade")` replies every 500 ms;
the event's `remaining` value is not applied directly. Duplicate or
old reports trigger no second deduction when the native quantity is unchanged.
Only decreases consume inventory. An unexplained native increase blocks throwing
until an explicit synchronization resets native stock to the inventory count.

Native explosions already replicate and enter existing damage/safezone/blast
policies. This module never spawns a second explosion or reapplies damage.
The circular status HUD includes a small selected-grenade count beside the
weapon/vital group. Player-facing text is English.

## Failure and lifecycle behavior

A native timeout quarantines all equipment writes for that incarnation until a
late authenticated completion or reconnect. Death/character replacement retires
old queue jobs; the new body projects the saved selection and current inventory.
An unavailable snapshot or failed consumption transaction blocks further throws
until synchronization succeeds. Owner-reported native counts retain the same
anti-cheat and crash-before-report limitations as weapon ammo; they are not an
independent proof of each throw. Live grenade effect/animation/other-player blast
checks remain necessary on the game client.

## Verification

`tools/test-grenades.py` loads the actual inventory, weapon queue and grenade
modules with asynchronous native and SQL boundaries. It covers exact counts,
selection replay, constant gadget membership while charges fall, regeneration
disabled, item Use, multiple notifications, partial native writes, SQL rollback/recovery,
switch/unequip, transfer guards, unexpected native increases and timeout
quarantine. `tools/test-grenades-client.py` verifies input/readiness/stock claims,
safezone composition and reference-only client forwarding.

## Diagnosis of non-consuming grenades (2026-10-26)

The original controller observed `weapons.requestGadgets` inventory quantities.
That was the wrong model for Cyberpunk 2.x: grenade use spends a rechargeable
charge pool, while a gadget stack can stay at five indefinitely. The official
blast relay already listens to `onConsumableUsed` for this reason. The regression
test now keeps the gadget stack at five while charges fall from five to four,
and checks that the RP inventory follows the charge decrease.

An isolated loopback probe against the installed VPS binary verified the
`Open77.consumables` namespace and its configure/snapshot/get/setCount/recharge
methods. The installed official owner relay is version 0.2.0 and handles the
`consumable` completion operation. The MCP index still marks these signatures
main-only/unpublished for build 156, so the controller detects actual capability
and fails closed on an incompatible server/client. It does not fall back to
unlimited legacy gadget stocks. Client and server need compatible consumable
support; an old client reports an explicit upgrade error.

## Remaining firearm catalogue expansion

The firearm controller still holds one pistol ammo pool. Enabling the full
catalogue requires separate handgun/SMG, rifle/LMG/precision, shotgun and sniper
pools verified against live ammo records, plus a migration of the existing stock.
Melee skips ammo readback entirely; thrown knives retain native return behavior.
Heavy/temporary weapons need equip/drop checks. Coronation, Sihil and Boar Carver
remain unresolved in the current reference. Catalogue presence is not a native
grant allowlist.
