# Vehicle look persistence audit

Asked by the owner on 2026-11-06: "make sure the vehicle's appearance is saved, tied to the
vehicle's ownership on Light RP, that after a reboot it stays, and that all players in
multiplayer see the right appearance — make sure it is clean."

This audit covers branch `lr/persistence-audit`, cut from `feat/auto-studio-full` at `bc29f61a`.
The base (Open77) code was read at `wt-vehicle-custom`, commit `e2d656c6`.

Unless stated otherwise:

- Light RP line numbers are in `server/modules/garages.lua` on this branch.
- Base server paths are relative to `server/src/`.
- Base client paths are relative to `client/src/`.

## Running the tests

Run from `resources/gamemodes/op77_lightrp` with either command:

```powershell
pwsh -File tests\run-lua.ps1 -LuaDll <path to lua54.dll> -Test vehicle_persistence_audit_test.lua
uv run -q --no-project --with lupa python <runner using lupa.lua54> . tests/vehicle_persistence_audit_test.lua
```

The test uses the real `garages.lua` and `inventory.lua`. Everything else is a deterministic fake:

- the database, which records every write and whether it was a payment transaction;
- `LightRP.money`;
- `Open77.vehicles`.

The `Open77.vehicles` fake copies the server rules this audit depends on:

| Rule | Server source |
|---|---|
| `setPaint` and `resetPaint` always clear a TwinTone profile | `VehicleAuthorityService.cs:556`, `:570` |
| a colour sent to `setProperties` is a repaint | `LuaResourceRuntime.Vehicles.cs:1669-1682` |
| restating the current profile is exempt from validation | |
| a bag publish happens only when the choices change | `VehicleCustomizationService.cs:112` |
| the visual is planned first and committed last | `LuaResourceRuntime.Vehicles.cs:1609-1636` |
| unknown keys are refused by name, the first one of each table, before anything is applied | `LuaResourceRuntime.Vehicles.cs:1466-1501`, `:1600-1603` |

Other suites that cover garage and studio persistence, all green on this branch:

- `garages_test`
- `customization_payment_test`
- `vehicle_customization_kit_test`
- `vehicle_customization_categories_test`
- `dealerships_test`
- `vehicle_access_test`
- `rental_test`
- `refueling_test`

## Verdicts

| # | Path | Verdict | Evidence |
|---|---|---|---|
| 1 | A purchase is written at once, in the payment transaction, keyed by the row id | **proven by test** | audit §1; `garages.lua:854-883`; `economy.lua:442-490` |
| 1b | Previews are never durable (autosave, another purchase, close, disconnect) | **proven by test** (fixes A and C) | audit §2, §3, §10; `garages.lua:153-158`, `:199`, `:857` |
| 2a | Store, then retrieve | **proven by test** | audit §4 |
| 2b | Left out at a restart: impounded free, then recovered | **proven by test** | audit §5; `garages.lua:346-355` |
| 2c | Staff tow, lost, destroyed (insurance) | **proven by test** | audit §5; `garages.lua:1138-1176`, `:274-290`, `:1334-1355` |
| 2d | Two characters on one account; character switch | **proven by test** | audit §6; `garages.lua:28-33`, `:657` |
| 2e | Transfer or sale | **no such feature**; the look follows the row | audit §8 |
| 3a | Restart: `properties` reloaded and re-applied at spawn | **proven by test** | audit §4, §5; `garages.lua:320-335`, `:1002-1048` |
| 3b | Order of operations, and a respawn after the bag was set | **proven by test** for Light RP; **proven by code reading** for the platform | audit §4; base `VehicleAuthorityService.Customization.cs:51-85` |
| 4a | The `open77.visual` bag is published on spawn and on every change | **proven by code reading** (and in the fake) | base `VehicleCustomizationService.cs:103-141` |
| 4b | A late joiner and a stream-in get the current look | **proven by code reading** | base `ServerApplication.cs:2730-2750`, `:3190-3207`, `:3547-3556` |
| 4c | The client re-applies after a rebuild, a respawn or an appearance change | **proven by code reading** | base `VehicleVisuals.cpp:842-888`; `VehicleReplication.cpp:1620-1636` |
| 4d | The client re-applies generic paint after collision damage (the black car) | **GAP (NATIVES)** | see "The black car" |
| 5a | A property the build cannot wear (pack stopped, part dropped, profile not offered) | **proven by test** (fix B) | audit §7, §9; `garages.lua:907-947`, `:539-554` |
| 5b | A property this build does not know (written by a newer build) | **proven by test** (fix D) | audit §11; `garages.lua:177-191`, `:949-974` |
| 5c | `setProperties` fails at spawn | **proven by test** | audit §7; `garages.lua:1015-1027` |
| 5d | The database write fails | **proven by test** | audit §7; `customization_payment_test` |
| 5e | The model is gone from the build, or the row is corrupt | **proven by test** | audit §7; `garages.lua:322-328` |

The "audit §n" references are the numbered sections of `tests/vehicle_persistence_audit_test.lua`.

## Ownership model

- One row per owned car in `lightrp_owned_vehicles` (`garages.lua:15-26`):
  - `id` is a UUID;
  - `identifier` and `character_key` say who owns it;
  - `record` is the **base** record;
  - `properties` is the whole look, as JSON.
- Ownership compares `identifier#character_key` (`garages.lua:28-33`). It is checked:
  - before a studio lease (`:657`);
  - before a retrieve, and again after it (`:997`, `:1040`);
  - by every studio action (`:628`).
- Every `properties` write is `WHERE id = ?` (`:212`, `:870-872`). No write ever changes the
  owner columns (audit §1, line 327).
- The performance stage lives in `properties.lightrp.stage`, and the record is derived from it at
  spawn (`:505-509`). The `record` column never moves.
- Network ids are never stored. A car that is out is linked to its row by an entity state tag
  (`:294-301`), which lets a resource restart sweep it (`:336-345`).

## Where each category lives

| Category | Stored in `properties` | Put back at spawn | Put back when the studio closes | Seen by other players through |
|---|---|---|---|---|
| Paint primary/secondary | `paint.applied`, `paint.primary`, `paint.secondary` | `setProperties`; the colours are sent only when `applied` is true (`:911-918`) | `applyPaint`, skipped when the car already wears it (`:581-601`) | `VehicleCreate` flags and colours (`ServerApplication.cs:3547-3556`) and vehicle updates |
| Lights hue | `paint.lightsHue` | `setProperties`; a complete table states it | `applyPaint` | `VehicleVisualState`, replayed after every create (`ServerApplication.cs:3190-3207`) |
| Trim (factory variant) | `appearance` | `create { appearance }` (`:1007`) | `applyTrim` (`:604-609`) | `VehicleCreate` appearance and `VehicleVisualState` |
| Livery (TwinTone or pack) | `visual.profile`; buying one also sets `paint.applied = false` (`:149`) | `setProperties` visual, committed last | `applyVisual` (`:539-554`) | the `open77.visual` bag (`profile`, dormant while its pack is stopped) |
| Neon | `visual.neon` | `setProperties` visual | `applyVisual` | the bag |
| Rims | `visual.parts[<rim>]` and `visual.wheels` | `setProperties` visual | `applyVisual` | the bag (render) |
| Body kit | `visual.parts[<part>]` | `setProperties` visual | `applyVisual`, Light RP's own parts only | the bag (render) |
| Plate text | `lightrp.plate` and `visual.plate` (kept equal by fix C) | `setProperties` `visual.plate`, then `renderPlate` (`:1032`) | `renderPlate` (`:490-500`) | the bag `plate` and the entity state `lightrpPlate` |
| Window tint | `visual.tint` | `setProperties` visual | `applyVisual` | the bag |
| Performance stage | `lightrp.stage`; `record` is the stage record | the car is created on `stageRecord(row, stage)` (`:1002`) | `applyStage`, which calls `respawnAs` (`:517-524`) | `VehicleCreate` record (sent again on a respawn) and the performance state |

## 1. Buying in the Auto Studio

**Verdict: proven by test.**

### What a purchase writes

`Garage.customize(commit = true)` (`:830-899`) proceeds in this order:

1. It applies the change to the car (`applyChange`).
2. It reads `getProperties`.
3. It masks every **other** category back to its confirmed value: `maskConfirmed(props, edit.saved, category)` (`:857`).
4. It adds the Light RP-only fields (`STORED`: plate and stage) from the lease (`:858`).
5. It wakes the dormant choices, then puts back the keys this build does not know (`:859-864`).
6. It hands one SQL `UPDATE ... properties ... WHERE id` to `LightRP.money.exchange` (`:870-883`).

### One transaction

`LightRP.money.exchange` runs three writes in **one** `Db.transaction` (`economy.lua:442-490`):

- the debit;
- the properties `UPDATE`;
- the ledger receipt.

The confirmed look in memory (`edit.saved`, `row.props`) is updated only in the transaction's
commit callback (`:876-883`). A failed transaction rolls back the category on the car (`:888-893`).

### When it is written

Immediately, not at the next autosave. Audit §1 buys all ten categories. For each one it asserts:

- exactly one properties write;
- the write is a payment transaction, keyed by the row id;
- `identifier` and `character_key` are unchanged.

It also asserts ten ledger receipts.

### Previews are never durable

The lease keeps `saved` and `shown` (`:663-666`). Three paths could persist a look, and none of them
persists a preview:

- **Autosave and removal recovery.** `capture` masks every category with `edit.saved` while a lease
  is open (`:199`).
- **A purchase.** It persists only its own category (`:857`).
- **Close.** It puts `saved` back on the car, then captures (`:677-693`). A failed restore keeps the
  lease open and retries; it never persists (`:684-688`).

Audit §2 tests this with six categories previewed at once. Audit §10 covers the plate preview (fix C).

## 2. Garage paths

**Verdict: proven by test.**

### Store

`capture`, then `state = stored`, `persist`, then remove the car (`:1102-1134`). A persist failure
leaves the car out and the row unchanged.

### Retrieve

The order of operations is given in section 3. Audit §4 checks the result:

- the car is created on the stage record, wearing its trim;
- `setProperties` runs exactly once, and the car is not respawned;
- one bag publish;
- the exact stored look;
- the bag holds the profile and `lightrpPlate`.

### Server restart with the car out

On load (`:346-355`), every `out` row is impounded:

- reason `restart`, free;
- reason `destroyed` if it was a wreck, which runs the insurance repair.

Recovery (`:1187-1208`) releases the car in SQL (with the fee in a transaction), then retrieves it.
Audit §5 checks the look matches after a reboot.

### Staff tow, lost, destroyed

- **Staff tow:** `/lightrp.impound` → `Garage.towLive` → `tow` (`:1138-1176`, `:1210-1220`) captures,
  then persists.
- **Lost:** `onVehicleRemoved` → `vanished` (`:1334-1355`).
- **Destroyed:** `insuranceRepair` zeroes only health and damage (`:274-285`). Appearance, paint and
  visual are untouched.

Audit §5 checks all three.

### Two characters, character switch

Ownership is per character (`:28-33`). The other character cannot lease the car or list it, and an
autosave while the other character plays leaves the look unchanged (audit §6).

### Transfer or sale

Neither exists. The look is a property of the row, so a future transfer only has to rewrite the
owner columns. Audit §8 changes `identifier` and shows that the new owner gets the same car, plate
included.

## 3. Restart and order of operations

**Verdict: proven by test.**

### Reload

`SELECT *` builds `rows[id]` with `row.props = json.decode(properties)` (`:320-335`). An unreadable
row is quarantined (`row.invalid`) and never overwritten (audit §7).

### Spawn order (`retrieve`, `:976-1067`)

1. `create { record = stageRecord(row, stage), appearance = props.appearance }` (`:1002-1009`).
   - Body and trim come first, so parts are resolved against the right appearance.
   - No respawn is ever needed at retrieval.
2. `restorable(row, record)` (`:907-947`):
   - drops `lightrp`;
   - sets `record` to the spawned record;
   - removes the colour channels from a factory paint (sending them would repaint the car);
   - moves parts and profiles this server cannot offer to `row.dormant`.
3. `applyKnown`, then a single `setProperties` (`:1013-1031`). The platform applies in this order:
   - it validates unknown keys, the record and the whole visual plan before changing anything
     (base `LuaResourceRuntime.Vehicles.cs:1600-1636`);
   - it writes paint, health and damage in one revision (`:1663-1704`);
   - it commits the visual **last**, so a repaint cannot clear the stored livery (`:1609-1613`).
4. `renderPlate`, fuel, engine off, lock, trunk, keys (`:1032-1044`).
5. `capture`, then `state = out`, then `persist` (`:1045-1048`).

### A respawn after the bag was set

At retrieval this never happens: the stage record is used at create. In the studio, a stage
purchase calls `respawnAs` (`:517-524`; audit §1 line 339). On the platform side, `Respawn`
(base `VehicleAuthorityService.Customization.cs:51-85`):

- keeps the same `ServerVehicle`, so the same id, colours and visual;
- calls `Reresolve`, which republishes only when the render moved (`VehicleCustomizationService.cs:184-195`);
- raises `TransformChanged`, which sends `VehicleCreate` again (with record, colours and appearance)
  to every viewer.

The client treats the new engine entity as a new projection and re-applies the whole bag
(`VehicleVisuals.cpp:842-859`).

## 4. Multiplayer

**Verdict: proven by code reading, except the black car (a gap).**

### The bag

- The key is `open77.visual` (`VehicleCustomizationService.cs:38`).
- `Publish` increments the revision and writes the bag (`:129-141`).
- A change that does not move the choices publishes nothing (`:112`).
- Generic paint clears a TwinTone profile:
  - `PaintWritten` (`:216-220`);
  - always on `SetPaint` and `ResetPaint` (`VehicleAuthorityService.cs:556`, `:570`);
  - on `update` only when the paint really changed (`:534`).
- Fix A exists because of the always-clearing rule: a blind re-paint at studio close made every
  viewer see the livery drop and come back.

### Late joiner and stream-in

When a car enters a player's interest (`ServerApplication.cs:2730-2750`), the server sends:

- `VehicleCreate`, which carries flags (`PaintApplied`), colours, record and appearance (`:3547-3556`);
- the lights hue (`VehicleVisualState`), when the car has one (`:3190-3207`; `NeedsVisualReplay`,
  `VehicleAuthorityService.Visual.cs:145`);
- the state bag values (`OnStateBagEntityEntered`, `:2743`), which include `open77.visual` and
  `lightrpPlate`.

A late joiner goes through the same interest entry.

### Client re-apply

- **New engine entity (stream-in, rebuild, respawn):** the client drops what it had applied and
  re-applies everything: components, plate, tint, parts and props (`VehicleVisuals.cpp:842-859`, `:880-888`).
- **Appearance change:** a burst re-apply of components, plate and tint (`:862-878`).
- **Generic paint:**
  - painted cars are watched twice a second through a "paint visual stamp" (`VehicleReplication.cpp:2077-2103`);
  - the stamp hashes every enabled mesh component, its render proxy, its mesh handle and its mesh
    appearance (`api/Vehicles.cpp:4832-4888`);
  - a stamp change marks the paint unsynchronised and re-applies it three times.

### The black car

**Report:** mount, then drive with collisions, then dismount. One client saw the car fully black.
A livery followed by plain paint fixed it.

**Facts:**

- The client code records a measured case (2026-11-05, lab 11850, release 177) that matches this
  symptom (`VehicleReplication.cpp:1622-1630`):
  - after a live appearance change, generic paint never became visible again;
  - every application still reported ok;
  - the cause is that "the persistent vvc effect loop stays bound to the replaced mesh components";
  - the remedy is `NotePaintAppearanceChanged`, which restarts the shader loop. It is armed for 5 s
    after an appearance change (`:1631-1632`).
- The stamp watch restarts the loop **only inside that window**: `now < replica.paintRestartUntil`
  (`:2091`). Outside it, a new render representation only re-issues `SetPaint`, three times
  (`:2093-2100`).
- The stamp skips disabled components (`api/Vehicles.cpp:4852`). Disabling or replacing a mesh
  component therefore changes the stamp.
- Switching the paint template rebuilds the body when the car is empty and stopped
  (`VehicleReplication.cpp:2268-2296`): "the new one applies from scratch".
- The workaround that fixed the report (a livery, then plain paint) is two template switches, so
  two fresh bodies.
- The server's canonical paint was right throughout: the other client showed it.

**Inferences:**

- Collision damage replaced or disabled body mesh components long after any appearance change.
- The stamp then changed outside the 5 s window, `SetPaint` was re-issued, and the vvc effect loop
  stayed bound to the old components: the same failure as the measured case.

**Hypotheses, unverified:**

- The black is the body material's look when the vvc effect no longer drives it.
- Mounting and dismounting matter only because an occupied or moving car is never rebuilt
  (`:2278-2280`).

**Owner and fix:** NATIVES, client, `client/src/network/VehicleReplication.cpp:2086-2092`.

- On an `Ok` stamp change of a painted car **outside** the window, restart the effect loop as well:
  call `Api::Vehicles::NotePaintAppearanceChanged`, rate-limited to once every 5 s per replica.
- Alternatively, when the car is empty and stopped, request the same rebuild as a template switch.
- Expose a counter (`paintLoopRestarts`) in the `vehicle.network` readout, so the lab can prove it.

**What a server could do: not implemented, not recommended.** A staff command could force a fresh
body on every viewer:

1. On an empty, stopped car, call `resetPaint`.
2. Wait about 1.5 s.
3. Call `setPaint` with the stored colours.
4. Put the livery back, because `setPaint` clears it.

Its limits:

- It works only when the car has no lights hue and no livery. Otherwise `paintWanted` stays true,
  and no rebuild happens.
- It blinks the car for **every** viewer to repair one client.
- The server cannot detect the broken client in the first place.

The client fix is the right one.

## 5. Failure handling

**Verdict: proven by test.**

### A visual this build refuses

The car is delivered without its visual. The whole visual goes dormant, autosave and store keep it
stored, and it is worn again once accepted (`:1018-1025`; audit §7). This holds for every field,
including ones the build does not know (audit §11).

### `setProperties` refused outright

Nothing is delivered and nothing is written (`:1026`, `:1051-1065`; audit §7).

### Model removed from the build

`create` refuses: no delivery, and the look is kept (audit §7).

### Kit part dropped from the catalogue

The car wears everything else, the part stays stored as dormant, and it comes back once the part
is listed again (`:927-944`; audit §7).

### Pack livery stopped while the car is out

The platform republishes without it. The choice stays dormant on the platform side
(`VehicleCustomizationService.cs:244-254`). Light RP's studio close keeps it dormant on the row
instead of refusing (fix B; audit §9).

### Unknown keys

These are properties written by a newer build, read after a rollback. They are skipped at spawn,
logged, and kept by autosave, purchase and parking (fix D; audit §11).

### SQL down

- **Autosave** retries and never writes partially (audit §7).
- **Purchase** follows the transaction rules in section 1 (`customization_payment_test`).

### Corrupt row

Quarantined. It is never reset or overwritten (`:322-328`; audit §7).

## Fixes in this branch

| Commit | Fix | Test |
|---|---|---|
| `1ee7ceb1` | **A.** A studio close, rollback or restore writes only what moved. `applyPaint(…, restore)` skips `setPaint`/`resetPaint` when the car already wears that paint, and skips the hue when it is the same (`:581-601`). Before this fix, every close made every viewer see the livery drop and come back, two bag publishes. | audit §3 |
| `ff27d37e` | **B.** A livery that is no longer offered (its pack stopped mid-session) goes dormant when the look is restored, instead of refusing (`:529-554`). Before this fix the close failed with `invalid_profile` and **the lease was never released**: the car stayed locked in the studio. | audit §9 |
| `a978a7e1` | **C.** A plate preview never reaches `properties.visual.plate`. The platform's copy follows the registered plate (`:134-144`). Before this fix, an autosave during a plate preview stored the unpaid plate in `visual.plate`. Every viewer then saw it at the next spawn, until `renderPlate` corrected it. | audit §10 |
| `cda4162b` | **D.** A property this build does not know is skipped at spawn and kept stored (`applyKnown`, `keepUnsupported`, `wake`, `:166-191`, `:949-974`, `:1013-1031`). Before this fix, the delivery was refused with `unsupported_property:<key>`. `ignoreUnsupported` is not used because its list names only the first unknown key of each table, so the others would be lost at the next autosave. | audit §11 |

## Gaps

| # | Gap | Owner | Exact fix |
|---|---|---|---|
| G1 | **The black car.** Collision damage outside the post-appearance window leaves generic paint unbound | NATIVES (`client/src/network/VehicleReplication.cpp`) | See "The black car" above |
| G2 | Sound records do not derive their base record. The suffix regex is `_o77s\d+$` (base `VehicleVisual.cs:247`, `:259`). A car on `Vehicle.x_o77s2a3` or `Vehicle.x_o77a3` would find no kit fit and no TwinTone list, so its whole visual would be refused or go dormant. | NATIVES (`server/src/Open77.Server.Core/Vehicles/VehicleVisual.cs`) | Strip `_o77s<n>a<k>`, `_o77a<k>` and `_o77s<n>`. A matching regex, `_o77(?:s(?<stage>[0-9]+)(?:a(?<sound>[0-9]+))?\|a(?<only>[0-9]+))\z`, is uncommitted in `wt-vc-lights` (`vc/wave2-natives`) at the time of writing. Check it at merge with a test on all three forms. |
| G3 | **The wave-2 categories cannot persist yet.** STUDIO's uncommitted code feature-detects `Garage.registerCustomizationCategory(name, { owns, receipt, respawns, available, apply, restore, unchanged })` and greys all five wave-2 categories when it is absent. `garages.lua` refuses any category missing from `OWNS` (`:834`). | AUDIT (`garages.lua`), once STUDIO commits the interface | Add the registry to `garages.lua`. The details are below the table. |
| G4 | **Engine sound against stages.** `stageRecord(row, stage)` returns `_o77s<n>`, and `applyStage` compares records exactly (`:518`). A car fitted with a sound would be respawned onto the record without it at every studio close. It would also need a second respawn at every retrieve. | STUDIO (resolver), PACKS (`stageRecord` export), AUDIT (`garages.lua`) | Change the resolver to `(base, stage, sound)`. The PACKS export answers `Vehicle.<base>_o77s<n>a<k>` or `_o77a<k>`. `garages.lua` passes the stored sound to `stageRecord` at retrieve and in `applyLook`, and keeps the exact record comparison in `applyStage`. |
| G5 | The repo's customization test runner does not run this audit | lead (`tools/test-vehicle-customization.py`) | Snippet below |
| G6 | `setProperties(…, { ignoreUnsupported = true })` names only the first unknown key of each table (base `LuaResourceRuntime.Vehicles.cs:1466-1501`, `:1741`). A caller that trusts the list loses the others. | NATIVES (`LuaResourceRuntime.Vehicles.cs`) or the lead (`docs/research/vehicles-api.md`) | Return every unknown key, or document the limit. Light RP no longer depends on it (fix D). |

### What the G3 registry must do

- A registered `owns` joins `OWNS`, so it is masked on autosave and on another purchase.
- `unchanged` and `receipt` join `UNCHANGED` and `RECEIPTS`.
- `apply` handles previews.
- `restore` runs in `applyLook` **after** `applyStage` when `respawns` is set, so the engine sound
  survives a stage change.
- `available() == false` keeps the stored value dormant.
- `restorable` passes the wave-2 keys through untouched. Fix D already keeps them when the platform
  does not know them.
- Test: extend audit §1, §2 and §11 with one wave-2 category.

## Snippets for files the lead merges

### `tools/test-vehicle-customization.py` (G5)

Append:

```python

LuaRuntime(unpack_returned_tuples=True).execute((root / 'tests/vehicle_persistence_audit_test.lua').read_text())
```

### `docs/research/vehicles-api.md` (base), under `setProperties`

```markdown
**Unknown keys (measured from the code, 2026-11-06).** `setProperties` refuses a key it does not
know by name, `unsupported_property:<key>` or `<table>.<key>` (tables: top level, `paint`,
`damage`, `visual`), BEFORE it reads the vehicle or applies anything: a caller can strip that key
and call again. With `{ ignoreUnsupported = true }` the third return value lists only the FIRST
unknown key of each table (alphabetical), not all of them. Light RP's garage relies on the
refusal-before-change order to keep keys written by a newer build across a rollback
(`garages.lua` `applyKnown`).
```

### `docs/vehicle-visual-contract.md` (base), record naming (§6)

```markdown
`BaseRecord` strips every Open77 record suffix: `_o77s<n>` (stage), `_o77s<n>a<k>` (stage and
engine sound) and `_o77a<k>` (engine sound on the factory stage). Kit fits and TwinTone lists are
looked up on the base record, so a car never loses its look by changing stage or sound.
```

### `docs/vehicle-visual-contract.md` (base), client paint

```markdown
Generic paint is driven by a persistent vvc effect loop bound to the body's mesh components. Any
replacement of those components (appearance change, rebuild, collision damage) must restart the
loop, not only re-issue SetPaint: re-issuing alone reports ok and leaves the body unpainted (black).
```

### `PLAN-vehicle-custom-wave2.md`, AUDIT row status

```markdown
AUDIT (2026-11-06): base categories proven persistent (park, restart, impound, character switch,
late join/stream-in by code reading); fixes A-D on `lr/persistence-audit`. Open: G1 black car
(NATIVES client), G2 sound-suffix BaseRecord (NATIVES), G3 garage category registry for the wave-2
categories (AUDIT, after STUDIO commits its interface), G4 stage+sound resolver.
```

## In-game test plan (two clients)

This is for the lead. It runs on the local Light RP lab (see `docs/personal-vehicles-validation.md`
for the stack).

### Setup

- **Client A** is the owner, with staff rights.
- **Client B** is the observer, on a second account.
- Read client state with the debug bridge, from the `base` repo:
  `.\scripts\debug-bridge.ps1 -ProcessId <pid> -Command '<cmd>'`, or `open77_cmd` through MCP.
- `vehicle.list` gives the network id `<id>`.
- `vehicle.customization <id>` prints `record=`, `streamed=`, the bag revision (`rev=`), the revision the client applied (`applied=`), `profile=` and `plate=`.
- `vehicle.network <id>` prints the paint readout: `canonicalPaint`, `paintSynchronized`,
  `paintLastStatus`, `paintStamp`, `paintNative={…}`, `canonicalDetached`, `observedDetached`.
- After each step, screenshot both clients from the same side of the car. Compare the paint
  colour, livery, neon colour and glow, rims, wing and lip, plate text, tint darkness and trim.

### Steps

1. **Grant and retrieve.**
   - A runs `/lightrp.givevehicle me hella`. Expected: `Personal vehicle granted: …`.
   - At a Public Garage, A runs `/garage` and retrieves the car.
   - B stands 10–20 m away.
   - Expected: both show the factory Hella, and `vehicle.customization <id>` gives the same `rev`
     on A and B.
2. **Buy each category.** A parks on Auto Studio // Bay 01 and steps out, then buys in this order:
   1. paint `#FFCC00`/`#101820`;
   2. lights (green);
   3. a trim;
   4. rims (a black variant);
   5. a body kit wing;
   6. neon (red, intensity 1200);
   7. tint 2;
   8. plate `ABC1234`;
   9. stage 2;
   10. a TwinTone livery.

   After **each** purchase:
   - B's screenshot matches A's;
   - `vehicle.customization <id>` gives the same `rev` on both, with `applied` equal to `rev`;
   - read-only SQL on the lab DB returns the category:
     `SELECT JSON_EXTRACT(properties, '$.visual'), JSON_EXTRACT(properties, '$.paint'), JSON_EXTRACT(properties, '$.lightrp') FROM lightrp_owned_vehicles WHERE id = '<uuid>'`.

   The stage step is a visible rebuild on B, with every other category kept. `record=` ends in `_o77s2` on both clients.
3. **Preview, then close without buying.** Preview a green neon and a different rim, then close.
   - B sees the preview, then the confirmed look.
   - B **never** sees the livery drop (fix A).
   - The SQL row is unchanged.
4. **Park and retrieve.** Expected: the same look on both, and the server log shows no
   `kept dormant` line.
5. **Restart with the car out.**
   - Stop the server while the car is outside, then start it.
   - Expected server log line:
     `garage: N ownership record(s) loaded, 1 left outside towed to the impound (… removed from the world)`.
   - A reconnects, sees the impound notice, and recovers the car at a garage for free.
   - Expected: the look is identical on A and B, the plate reads `ABC1234`, and it is on stage 2.
6. **Late joiner.**
   - B disconnects.
   - A buys a new neon colour.
   - B reconnects and walks to the car.
   - Expected: B shows the new neon at first sight, with the same `rev` as A.
7. **Stream-in.**
   - B travels more than 1 km away, until `vehicle.customization <id>` on B shows `streamed=no`.
   - A buys a different rim and a different livery.
   - B comes back.
   - Expected: B shows both at stream-in, with no factory flash longer than one frame burst, and the
     same `rev` as A.
8. **The black car (G1).**
   - Repaint to generic paint first: plain paint, no livery.
   - Run `vehicle.network <id>` on A and B and note `paintStamp`.
   - A mounts, drives into walls until a part detaches (`canonicalDetached` ≠ 0), stops, and
     dismounts.
   - Run `vehicle.network <id>` again on both, and take screenshots.
   - **Today:** expect a changed `paintStamp`, `paintSynchronized=yes`, and possibly a black body
     on one client.
   - **After the G1 fix:** the body shows the paint within about 1 s, and the restart counter
     incremented.
   - Record which client failed, and whether that client was the driver.
9. **Pack livery stopped (fix B).**
   - Fit a pack livery.
   - On the server console, run `stop <livery pack resource>`.
   - Expected: both clients fall back to factory paint.
   - Open and close the studio. Expected server log line:
     `garage: <uuid> cannot wear its livery <id> on this server right now; kept dormant`.
     The studio closes.
   - Run `start <livery pack resource>`, then park and retrieve. The livery is back on both clients.
10. **Rollback safety (fix D).** This is an offline-proven path and is optional in game.
    - Retrieve a row whose JSON was given an extra top-level key by hand (lab DB only), for example
      `"neonAnimation": {"mode": "pulse"}`.
    - Expected server log line:
      `garage: <uuid> keeps stored properties this server build does not know: neonAnimation`.
    - The car is delivered, and after an autosave the key is still in the row.

**Pass condition:** every screenshot pair matches, every `rev` pair matches, and every SQL read
shows the bought category after the purchase and after the restart. Step 8 is expected to fail
until G1 lands.

## Risks

**Facts:**

- All findings of this audit come from code reading and offline tests. **Nothing here was run in
  game**: no client, no server, no database.
- Fixes A–D are proven only against the fake. The fake copies the server rules listed under
  "Running the tests", but it is not the server.
- The wave-2 interfaces of STUDIO and NATIVES were read **uncommitted** in their worktrees, and
  may change.

**Inferences:**

- The late-join and stream-in paths are correct for the current categories, because they share
  the create, state-bag and hue replay used by the base campaign's tests.
- The black car is the vvc-loop binding failure outside the restart window.

**Hypotheses:**

- The exact black colour comes from the material's state without the effect.
- Collision deformation, not only part detachment, replaces mesh components.
- Fix D's strip-and-retry costs at most one call per unknown key. Each refusal happens before any
  change: a fact for the current platform, a hypothesis for any future one.
