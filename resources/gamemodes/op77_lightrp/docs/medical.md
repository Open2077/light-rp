# Medical assistance and unconscious characters

Normal combat, fall and environmental deaths become an RP unconscious state.
The native canonical phase remains `dead`; the game API has no separate
`downed` enum on the supported build. The character stays where they fell.
After **90 seconds**, the player may choose **Give up and go to hospital** and
confirm the transfer. There is no automatic ten-second hospital respawn while
medical owns this injury. The delay and rescue settings are in
`shared/medical.lua`.

A living player with a **Trauma Stabilization Kit** (`trauma_kit`) can use it
from inventory or a quick slot near an unconscious patient. The server chooses
the nearest eligible patient within **2.5 metres**, in the same routing bucket,
and starts **8 seconds** of stabilization after the inventory/gameplay handoff.
The helper kneels using the documented `examine` animation. Movement, damage,
leaving range, changing character, entering a vehicle/another action or losing
the patient cancels treatment without consuming the kit. One helper owns a
patient at a time. The reserved kit cannot be transferred away during treatment.

A confirmed rescue revives at the same place with **35% health** and **5 seconds
of damage grace**, consuming one kit. The existing MaxDoc and first-aid items
retain their living-patient healing behavior; they do not become self-revival
items. Kits are not granted automatically. Existing staff inventory commands
can grant one for testing:

```text
/lightrp.giveitem me trauma_kit 1
```

## Hospital bill

Waking up at the hospital after **Give up and go to hospital** costs
`LightRpEconomy.hospital.bill` (€$ 300, `server/config/economy.lua`), taken from the
bank first, then from cash, and only what is there: a balance never goes below
zero and the rest is written off. The confirmation on the unconscious screen
shows the bill before the player commits; a notice and the ledger
(`lightrp_transactions`, kind `hospital`) show what was paid.

There is no bill on a rescue with a kit, inside a mission or an activity, during
the first day guide, for the character's first `graceMinutes` (120) of play, nor
on the platform's fallback hospital respawn of a script death. A transfer the
platform refuses bills nothing. `bill = 0` disables it. Code:
`server/modules/economy_sinks.lua`, called from `hospital()` in `medical.lua`.

## Persistence and reconnects

`lightrp_medical_deaths` stores the character's death token, original wall-clock
timestamp, position, bucket, heading and transition revision. Refreshing the
page, reconnecting or selecting the same injured character does not restart the
90-second timer or heal them. Saved medical placement uses the existing streamed
join-spawn transaction, then restores canonical dead once the saved body has
recovered. Its scheduler records that join placement so a later gameplay-ready
event cannot spawn the injured character a second time.

Scripted placement deaths from creation, joining, administrative moves and the
existing tutorial hall retain their original lifecycle. Creator code is not
changed. An authorized external revive can settle a normal unconscious record.
The hospital location remains `LightRpConfig.spawn.hospital`.

## Kit escrow and native confirmation

After the server's full treatment timer, kit removal, a `dispatching` treatment
receipt and the patient's `reviving` record commit in the same inventory SQL
transaction. A revision CAS and a NOT NULL guard receipt abort stale writes;
a changed patient cannot consume a kit from an obsolete snapshot.
`lightrp_medical_attempts` holds real escrow IDs and `guard:*` transition receipts.

After that SQL await the server rechecks actor/patient identity, life, freshness,
position, range, routing bucket and readiness before invoking
`Open77.players.revive`. It does not require another kit after escrow. An
explicit native refusal or a known cancellation before native dispatch records
a failed receipt, returns the kit exactly once, and restores the injury record.
If the helper disconnected, the refund waits for their inventory to load again.
A full inventory receives a recovery slot rather than losing the refunded item.

Native acceptance is not treated as confirmed presentation. The server waits
for canonical `recovering`/`alive` before completing the receipt and clearing the
saved injury. A delayed/uncertain native result retains the paid receipt and
cannot charge a second kit. A late confirmation settles it; reconnect can resume
the paid recovery for the same character. If an uncertain request has returned
to canonical dead, the patient can eventually abandon after the normal delay;
that supersedes the receipt and does not mint a refund for an ambiguous result.

## Client presentation

The English unconscious overlay shows the server deadline, active assistance,
recovery synchronization and deliberate hospital confirmation. Cursor-only
WebUI focus keeps voice keys available. Medical action blocks use the shared
control-claim aggregator, so leaving medical state cannot release grenade or
safezone restrictions. Helpers use the existing cancellable progress interface;
its completion is presentation, not permission to revive or consume an item.

No undocumented native death-screen selector is used. The build exposes HUD
component visibility but no dedicated death-screen component. The RP WebUI
provides the overlay while native life controls the body. Actual animation,
death presentation and two-client rescue should be checked in game.

## Code and checks

- `shared/medical.lua`: policy and the trauma item.
- `server/modules/medical_store.lua`: durable injury and escrow storage.
- `server/modules/medical.lua`: timers, eligibility, treatment, refunds, native confirmation.
- `server/main.lua`: medical priority in join/character placement and death respawn.
- `client/core/medical.lua`: input ownership and inventory/progress handoff.
- `ui/src/features/medical/Medical.tsx`: English unconscious overlay.

`python3 tools/test-medical.py` loads actual inventory, medical and Spawn code
against deterministic SQL and native boundaries. It covers the original death
hold, give-up delay, one-kit rescue, movement/routing/freshness and exclusivity,
escrow rollback and CAS conflicts, helper/patient disconnect during SQL,
readiness changes, explicit refund, offline replay, saved-death restoration,
late confirmation and uncertain outcomes. `tools/test-medical-client.py` checks
handoff/cancellation, cursor-only focus, input claim composition and the narrow
page request bridge. These checks do not simulate REDengine visuals.
