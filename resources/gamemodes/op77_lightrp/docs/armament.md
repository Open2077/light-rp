# Inventory weapons and ammo — RP prototype

## Items

`shared/armament.lua` describes 22 serialized weapons (`LightRpArmament.weapons`), each with its native record, its class and its ammo type.

| Type (`ammo`) | Item (1 = 1 round) | Native pool | Classes | Box |
|---|---|---|---|---|
| `pistol` | `ammo_pistol` "Handgun rounds" | `Ammo.HandgunAmmo` | pistols, revolvers, SMGs | `ammo_pistol_box` ×30 |
| `rifle` | `ammo_rifle` "Rifle rounds" | `Ammo.RifleAmmo` | assault rifles, LMGs, precision rifles | `ammo_rifle_box` ×30 |
| `shotgun` | `ammo_shotgun` "Shotgun shells" | `Ammo.ShotgunAmmo` | shotguns | `ammo_shotgun_box` ×12 |
| `sniper` | `ammo_sniper` "Sniper rounds" | `Ammo.SniperRifleAmmo` | sniper rifles | `ammo_sniper_box` ×10 |

**Where the native pools come from.** They are measurements recorded in the `open77_cordon` config:
- SMGs fire handgun ammo;
- a precision rifle (Achilles) fires rifle ammo, not sniper ammo.

One RP type maps to one native pool: two weapons of the same type always share their rounds.

**Hands.** Only pistols and revolvers (`dual`) go in the left hand, with another handgun in the right. Other weapons hold the right hand on their own: equipping a rifle with a pistol in the left hand is refused.

The `pistol` and `ammo_pistol` keys keep their original names: some characters already own them.

No weapon or ammo is given automatically on connect.

To get them:
- the Gun Store (see [shops](shops.md));
- a staff inventory grant.

A native `/weapon.give` grant does not create an owned weapon in the RP inventory.

## Ammo = inventory items

`LightRpArmament.ammo` declares the ammo types, and each weapon states its own (`ammo = "pistol"`).

**Equip or sync.** The server projects into the native pool exactly the rounds of that type found in the pockets.
- The projected maximum is 600 rounds; the rest waits in the pockets and refills the pool as it drops.
- The server remembers this baseline: `rt.baseline`.

**Observation every 2 s.**
- **Native total below the baseline:** these are shots. The matching rounds are removed from the inventory in a transaction.
- **Native total above it:** a native pickup or cheating. It is never credited: shooting is blocked and damage refused until a sync, which resets the pool to the pocket count.
- **The pockets changed some other way** (purchase, gift, deposit, unpacking): the server re-projects without waiting for an unequip.

**Two hands.** Two equipped weapons must use the same ammo type.

**Old hidden stock.** The old hidden stock (`lightrp_armament.definition.ammo`, from the time when opening a box credited a counter) is converted once into `ammo_pistol` in the pockets.
- The conversion happens at sync, in the same transaction as the state.
- Whatever does not fit stays recorded and goes through at the next sync.

## Use

Native selection (`WeaponWheel`, `NextWeapon`) is blocked by the inventory
module for the whole session, regardless of safezones. Shooting and
reloading stay available under their usual rules. The server calls
`assign`/`setActive` are still allowed. Select an item to equip it,
then **Use weapon** to draw it again after **Holster weapons**; remove the
reference with **Unequip this hand**. Player-facing labels are in English.

From the inventory, equip the Lexington or the Nue in the right hand, then optionally
the other model in the left. The native slots used are **1 and 4**.
A weapon cannot occupy both hands; two instances of the same model
are not supported by this prototype. Holstering (visual only) keeps
the equipment; unequipping removes its reference and lets you transfer the item.
Unequipping the right hand also removes the left reference.

Unpacking a box removes the box and adds 30 `ammo_pistol` in a single transaction; if the pockets are full, the box stays.
- The displayed stock is the rounds of that type in the pockets, magazines included. It is not multiplied by the number of weapons.
- Rounds can be given, sold and deposited like any item.
- Transferring a weapon transfers no rounds.

Weapons that are equipped or syncing cannot be sold,
given, deleted or transferred. Ground piles and temporary containers
are not allowed destinations for weapons: use another
persistent inventory after unequipping. Moves within the same grid
keep the identity by UUID, regardless of the slot number.

## Dual wield: prototype restriction

The Lexington/Nue pair is offered for testing, not certified by a full
in-game test in this delivery. Both hands have their own magazines and
share one reserve. The `.156` engine still documents an inconsistent
split during dual reloads with a low reserve.

So before enabling dual, the module requires a total stock of at least twice the sum of
both pistols' native capacities. During observation, if the reserve
drops below the sum of the capacities, the projection goes into error and
shooting is suspended: add boxes, or unequip the left hand, then
sync. The module never adds rounds to work around this bug.
This guard reduces exposure but does not fix the engine between two reads.

## Authority and limits

The RP inventory and its SQL ledger decide ownership. Templates and
native records come from a server allowlist. Page requests
name a slot, a UUID and a revision, never an arbitrary `Items.*` record,
a chosen capacity or a number of rounds to grant.

The `lightrp_weapon_instances` tables and their audits take part in the same
transaction as the inventory JSON. A UUID cannot be recreated under
another owner. Equipment changes and box credits live in
`lightrp_armament`, with idempotent receipts in `lightrp_armament_operations`.
The same request key does not consume a second box.

The native engine stays projected on the owner's client: snapshots,
completions and round counts are its observations. The module can only
**reduce** its budget based on an observed native total; it never creates any from
a client report. The stock granted by boxes is checked by SQL, but
the consumption of each round is not proof independent of the client.
Missed shots and shots fired at nothing make it impossible to replace this with a damage count.

Before a mutation or a resync, the last known native pool is
read again and reconciled, so that a click between a shot and the poll does not refund
rounds that are already observable. Routine reads happen every two seconds,
without blocking shooting during a read-only check. Their results cannot
increase the stock. Shots not reported before a crash/leave remain an
authority limit of the engine; this version does not promise a tamper-proof
per-round economy against a modified client.

The server arbiter refuses ranged damage without an equipped RP weapon, hashes
that do not match the projected hands, shooting during a native mutation,
a projection that is not ready, or zero stock. It comes on top of the safezone arbiter:
it does not replace their protection. Vehicle hits and attacks
unrelated to the managed weapons keep their own separate policies.

## Sync and recovery

Native operations are ordered: dual policy, reuse/assignment,
normalizing both magazines, activation, then a check snapshot.
A queue ID is not a successful equip. Replies are correlated
by player, request ID, operation and incarnation. A failed transaction is
returned as a failure; a successful credit then comes before the native projection.

A timeout can leave a native operation in flight. The module quarantines that
incarnation and refuses to stack a new projection on top of it.
A late, authenticated completion lifts the quarantine but requires an
explicit resync; with no reply, reconnect/replace the character.
Death and a character switch drop the jobs of the old generation.
Old confirmations do not apply to the new body.

Startup reuses native items already owned when possible; it only
creates a presentation item after a final `weapon_not_owned` refusal. Removing
a native slot does not delete its local native item. The RP ledger must
never rebuild ownership from these local items.

## Wheel speed and reliability (2026-11-05)

Measured on a local server (runtime 193) with `/lightrp.armtest`. Each native request costs about 200 ms round trip,
even locally: the client runs it inside a REDscript frame.

| Action | Before | After |
|---|---|---|
| Draw the equipped weapon again (after holstering) | the whole projection, 2 to 4 s | `setActive(1)` alone: 130 to 330 ms |
| Bare hands / HOLSTER | unequip + `clear`, then re-project everything | `holster` alone: 130 to 270 ms, the weapon stays equipped |
| Switch weapon | about 10 requests in series, plus waiting for the observation pass | snapshot first, then `assign` and `setAmmo` (with `activate`) sent together: about 1.0 s until the weapon is in hand |
| First switch to a weapon since startup | same | sequential once (reading the magazine capacity), about 1.8 s |

**What changed in `server/modules/armament.lua`:**
- `issue` / `settle`: a native request is sent, then awaited. The client runs a player's requests in order, so a known sequence goes out in one go.
- The snapshot taken by `beginMutation` is reused by `project` (`rt.freshRows`, valid for 1.5 s).
- The two-hand rule is only sent again when it changes (`rt.dualAllowed`).
- The magazine capacity is cached per record (`capacityOf`). The assignment mode is remembered per incarnation (`rt.assignMode`); for a record never assigned before, the presentation item is created right away.
- A single weapon: the magazine is set directly, without a reset to zero, and the weapon is drawn in the same request (`setAmmo{activate=true}`). If the result does not say `drawn`, a `setActive` follows.
- The weapon is assigned over the old one in slot 1, without `remove`.
- If the batched path is refused, the server falls back to the sequential path from a fresh snapshot, and that incarnation stops batching (`rt.noPipeline`).

**No more refusals:**
- A wheel choice or a holster that arrives during an operation waits in a queue: the latest request wins (`rt.queued`, `drain`).
- `state` no longer counts toward the 150 ms spacing, and neither does a choice, since the queue handles it.
- The client no longer spaces out `state`, `select` or `holster`.

**Nothing native during the loading screen:**
- Weapon sync and the grenade loop wait for `W.inWorld` (gameplayReady, or the LightRP page being ready).
- Before, a "consumable" request sent 5 s after connecting would time out, and three retries put the equipment in quarantine until reconnect.
- `player_unavailable` is retried every 2 s for 2 min, without using up attempts.
- A quarantine no longer waits for a reconnect: after 3 retries in 120 s, the next one happens every 30 s.

**Diagnostics:**
- Each request writes a line `armament: trace <op> player N: ok, in hand X ms, done Y ms, db until Z ms, n native (...)`.
- Staff command `/lightrp.armtest <id> <next|n|unarmed|holster|state|die>`: it takes the same path as the wheel (`die` kills, then respawns in place).
- Lab bench: `E:/Open77/tmp/lrp-weapons/armbench.ps1`.

**Checked in game (Jack Test client, lab server 193):**
- real wheel (TAB, mouse, click), HOLSTER then draw again;
- 9 choices 120 ms apart: the last one wins;
- death and respawn: weapon holstered, then drawn again in 330 ms;
- shots followed by an immediate switch: 6 rounds deducted, and the inventory equals the magazine plus the game's reserve.

## Weapon HUD

The native `weapon` component is hidden; the RP HUD built into the status area at the bottom left shows
the weapons actually drawn, the magazine/capacity of each hand and a single
shared reserve. The **RELOADING** and **EMPTY** states are in English. A holstered
weapon, a dead character, an inventory change or a stale read
removes the panel. The crosshair is still handled by the game.

The counters are read-only local native snapshots, requested at
most every 200 ms with a single read in flight. Only a successful
completion publishes a full panel; unknown values stay `—` and are
never shown as zero. These reads do not change the SQL stock.

## Extended catalog and images

The [full wiki catalog](weapon-catalogue.md) lists 198 entries with
local images and 195 matching Open77 records. The [grenades and weapon family
extension plan](grenades-inventory-design.md) describes how they are integrated
as counted items (nine types integrated) and the migrations needed for the other weapons.

## Code and verification

- `shared/armament.lua`: public catalog and item templates.
- `server/modules/armament_store.lua`: UUID registry and preparation of
  inventory mutations; no owner cache is changed before the commit.
- `server/modules/armament.lua`: state, stock, requests, native queue and arbiter.
- `inventory.lua`: deep clone of metadata, `prepare` hook, shared transaction.
- `client/core/armament.lua` and the inventory UI feature: display and requests.

`python3 tools/test-armament.py` loads the real inventory/armament modules
with in-memory SQL and simulated native completions. The checks cover
UUIDs, drafts, rollback, boxes/replay, asynchronous equips, transfer
bans, dual shared stock, shots before Sync, credits during an equip,
timeout, fake responder and incarnation change. They do not simulate
REDengine: confirm in game the rendering, capacities, animations, reloading
and native refusals on build `.156` with its updated official resource.

Network contract: `op77_lightrp:armament`, operations `state`, `equip`, `unequip`,
`holster`, `ammo`, `sync`. Replies carry `{kind:'response',request,ok,data:{state},error}`
and states are pushed via `{kind:'state',state}`. The page bridge is
`lightrp:ui:armament`. Mutations require a revision and an idempotency key.
