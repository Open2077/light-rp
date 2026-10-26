# Grenades as inventory items — integration design

The wiki index supplies nine grenade types with verified Open77 gadget records:

| Item ID | Native gadget record |
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

These are catalogue entries; the grenade runtime module is not implemented by
this import. This design uses the documented Stable 156 API rather than treating
grenades as pistols or implementing a second explosion simulation.

## Inventory and selection

A grenade is a counted inventory item, using `stack=10` (a proposed RP limit),
its English label and `img/items/grenade_*.png`. It does not use a weapon UUID,
weapon slot 1/4, a loaded magazine or an ammunition box. Its native destination
is `EquipmentArea.QuickSlot`. Keep the complete count in the durable inventory
and persist selected item type, projection generation and mutation receipts.

`Use` in inventory chooses the grenade type. The existing native weapon wheel
stays blocked; add a `SwitchItem` claim owned by grenade inventory to prevent
native quick-slot cycling. The `Grenade` action remains usable for throwing,
except while synchronizing or when a safezone blocks it. Combine those claims
through `LightRpControlClaims` so one feature cannot release another's block.

## Native projection queue

The server APIs require `network.events` and the `open77_weapons` resource:

```lua
Open77.weapons.giveGadget(playerId, record, count, { equip = true })
Open77.weapons.takeGadget(playerId, record) -- remove the local presentation stack
Open77.weapons.requestGadgets(playerId)
```

`giveGadget` is additive, not an exact setter. Never call it on every inventory
open, poll or retry. First reconcile the old selected stack, remove its native
presentation, then grant the exact committed count and request a readback.
Await `open77:weapons:completed(playerId, requestId, operation, accepted, reason,
result)` for each dependent step. Queue acceptance is not success. Correlate
player, request, operation, inventory and incarnation. Reuse/factor the armament
projection queue and its timeout quarantine rather than creating a competing
native writer. A failed projection does not refund or mint inventory items.

## Consumption, moves and persistence

The official resource emits reserved `onGadgetConsumed(playerId, record,
remaining[, tweakDbId])` after native consumption and suppresses the reports
caused by its own `takeGadget` operations. Use that event to mark the selected
stack dirty and request a fresh correlated gadget snapshot. Reconcile a lower
native count with the durable inventory in one `Inv.transaction` /
`Inv.commitDrafts` transaction, together with the projection receipt/revision.
A native count increase never creates inventory items.

The consumption event has no inventory mutation nonce. Do not decrement the
inventory once per callback or apply an old `remaining=0` blindly after a new
equip: duplicates and delayed reports can otherwise destroy items. A fresh
queued readback gives the current native quantity; repeated observations of the
same quantity make no additional deduction. Reject old incarnation results.
Native owner observations retain the same authority limitations as weapon ammo.

Before switching grenade types, dropping, trading, storing or disconnecting,
settle observable consumption. While projection is pending, reject movements of
the selected grenade stock. After a settled unequip, transfers use the ordinary
inventory transaction. Allow moving slots in the same inventory if total owned
quantity is unchanged. Reconnection restores the selected type from persistent
intent and inventory quantity, not by granting the last cached native amount.

## Damage and HUD

Native grenade explosions already replicate and enter the damage arbiter.
Do not call `Open77.effects.explosion` for the same throw; that would duplicate
damage. Preserve safezone protection and the official blast relay. An
`onPlayerExplosion` owner report alone is not an ownership or damage verdict.

Extend the RP HUD with the selected grenade label and one remaining count.
Unknown/stale native counts remain unavailable. Hide its selection during
creation/death and when no grenade is selected. Keep all player-facing text in
English, alongside the existing weapon magazine HUD.

## Required integration checks

Test count-preserving equip/re-equip and inventory opens; one throw consumes
one item; duplicate/old reports do not double-consume; moving/equipping while
busy is refused; SQL rollback preserves items; timeouts quarantine projections;
death/reconnect invalidate old jobs; safezones block throws; two clients see a
single explosion. Native timing, perk interactions and smoke/recon effects need
in-game checks on Stable 156.

## Expanding firearms and melee from the catalogue

The current controller stores one pistol ammo budget. Expanding its allowlist
alone would incorrectly feed every gun pistol ammo and reject melee weapons
because they have no magazine. Introduce separate durable ammunition pools for
handgun/SMG, rifle/LMG/precision, shotgun and sniper families, verified against
live native ammo records. Migrate the existing integer to the handgun pool.
Enable dual only for native-supported pistol pairs. Melee needs no ammo budget
or magazine readback; thrown knives retain their native return behavior and
must not be consumed like grenades. Heavy machine guns and temporary/quest
weapons require separate equip/drop capability checks. Three unresolved wiki
records remain disabled until a live TweakDB lookup validates them.
