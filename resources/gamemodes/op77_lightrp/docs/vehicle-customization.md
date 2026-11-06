# Vehicle customization / Auto Studio

The sources of this work:

- Paint landed from `feat/vehicle-customization` (`3fa7f22`).
- Lights, trim and the per-model support table come from `vc/a-lightrp-phase1`
  (campaign plan `PLAN-vehicle-custom.md`, phase 1).
- The complete studio (plan §3.10) comes from `vc/a3-studio-full`: livery, rims, body
  kit, neon, plate, performance stages and per-category camera framing.
- Window tint comes from `feat/auto-studio-full` on top of the native
  `Open77.vehicles.setWindowTint` (base `feat/vehicle-customization`, W1, 2026-11-06).

The phase-1 API mapping was checked with the Open77 Devkit MCP for
**2.50.0+op77.156**. The phase-2 natives (`listPaintProfiles`, `setPaintProfile`,
`setNeon`, `clearNeon`, `registerParts`, `listParts`, `setParts`, `setWheels`,
`getVisual`, `respawnAs`, client `customizationAvailable`) are those of the phase-2
platform build (`wt-vehicle-custom`). The devkit catalogue does not list them yet, so
every one of them is **feature-detected**. A server or client without a native greys
its category with a reason and never fails.

## Player flow

Two world access points use **E**, in bucket 0:

- Auto Studio // Bay 01: marker `(-1031.373364, -1702.693726, 11.015274)`, bay centre
  `(-1034.573364, -1702.693726)`.
- Auto Studio // Bay 02: marker `(-1029.170703, -1709.572754, 11.015274)`, bay centre
  `(-1025.970703, -1709.572754)`.

Each marker stands 3.2 m beside its bay, like a public garage point, so a parked car
never sits inside the marker's lit cylinder. Park your owned vehicle on the bay
(within 6 m of the marker), step out, and approach the marker.
The server selects the nearest vehicle owned by the active character; the same
stationary/empty, proximity and persistence rules apply. The first bay carries
the shared Auto Studio map marker, whose description lists every category. The
locations are in the shared customization config.

The garage shortcut is also available.

1. Retrieve an owned vehicle at a Public Garage.
2. Leave it stationary in the garage area and step out.
3. Reopen the garage, select the car and choose **Customize vehicle**.

All occupants must be out. Rentals, staff-spawned cars and other characters'
vehicles are not eligible.

The page keeps the original full-height left panel:

- the vehicle header, which shows the plate (or `#id`) and ` · STAGE n`;
- the category navigation: a two-column grid once more than four categories are offered;
- the category editor;
- the payment footer.

The game vehicle stays visible to the right, with the camera controls at the bottom
of the remaining viewport.

### Categories

The server sends the category rows for the vehicle being edited; see
[Per-model availability](#per-model-availability). Each category keeps its own draft,
and the car shows every current preview at once. **Apply** pays for the selected
category only. A valid change previews automatically: presets and pickers at once,
typed values after a short delay. Rapid clicks coalesce to the latest selection
while a request is pending, so there is no Preview button. **Performance is the
exception**: a stage is fitted on purchase and never previewed.

| Category | Editor | Natives (server) | Price (`server/config/vehicle_customization.lua`) |
| --- | --- | --- | --- |
| Body paint | Primary / Secondary, 12 presets, picker, HEX, **Factory finish** | `setPaint`, `resetPaint` | **2,500 €$** (owner, 2026-11-05) |
| Livery | **Plain paint** + the model's factory two-tone schemes ("Scheme N", main/secondary swatch) | `listPaintProfiles`, `setPaintProfile` | 4,000 €$, provisional |
| Rims | **Factory rims** + the rims that fit this record, then the finish | `listParts`, `setWheels` | 6,000 €$ per set, provisional |
| Body kit | One row per group (Wing, Rear louvers, Front lip, Canards, Side skirts, Rear diffuser, Hood, Roof, Front protection): **None** + the parts that fit, then the finish | `listParts`, `setParts` | 3,500 €$ **per group changed**, provisional |
| Neon | 8 presets, picker, HEX, brightness Low / Medium / High, **No neon** | `setNeon`, `clearNeon` | 5,000 €$, provisional |
| Lights | 12 saturated presets, picker, HEX, **Factory lights** | `setHeadlightColor`, `clearLightsHue` (restore: `setLightsHue`) | 500 €$, provisional |
| Trim | **Factory trim** + the variants curated for the model | `setAppearance` (`getAppearance` to skip restatements) | 2,500 €$, provisional |
| Plate | Plate number field + plate visual; the server answers availability | none; stored by Light RP, `lightrpPlate` state bag | 2,500 €$, provisional |
| Windows | **Closed: greyed "Coming soon"** (`windows.enabled = false`). Built and tested: Factory glass, Light smoke, Dark smoke, Limo (side and rear glass; the windshield stays clear) | `setWindowTint` (levels 1-3, nil = factory) | 1,500 €$, provisional, not sold while closed |
| Performance | Stock / Stage 1 / Stage 2 / Stage 3, each with its price | `respawnAs` onto `Vehicle.<dealer record>_o77sN` | per model and stage, provisional; going down costs 1,000 €$ |

#### Body paint

Pure black is a real colour, distinct from **Factory finish**. Both channels are one
job, and resetting a custom finish to factory paint is also a paint job. Generic
paint **replaces a livery**: the server clears the profile, and the page moves the
livery draft back to Plain paint.

#### Livery

A livery is one of the record's TwinTone profiles, listed by
`listPaintProfiles(vehicleId)` in the order the engine gives them, labelled "Scheme N".

- The server accepts only an id listed for this vehicle.
- Applying a scheme first puts the car back on its factory paint layer, keeping the
  lights hue, then sets the profile. The page moves the paint draft to Factory finish.
- **Plain paint** clears the profile.
- Paint and livery are **linked**: a purchase or a rollback of one writes both. Buying
  paint while a scheme is previewed drops the scheme, and closing restores the
  confirmed pair.
- A model with no profile is greyed "This model has no factory two-tone scheme."
- A client whose `customizationAvailable` reports `twintone = false` greys it locally:
  "Your game reports no two-tone scheme on this vehicle."

#### Rims

The rims are the 8 original rims of the vehicle kit (E1), 3 finishes each. They are
offered only on records that have a fit: 14 dealer records, including the Merrimac's
middle axle and the Apollo. The Kusanagi is excluded because its hubless front ring
leaves no room for a spoked rim.

- The fit is per wheel (B2): see [The vehicle kit catalogue](#the-vehicle-kit-catalogue).
- The request names a rim and a finish that this vehicle's offer lists, and the server
  calls `setWheels(id, { rim = "op77_lightrp:<rim>", variant })`.
- **Factory rims** calls `setWheels(id, nil)`.
- The native keeps one rim set per car.

#### Body kit

The body kit is the 8 parts of E2, with 75 fits on 16 models, all in the `Base` slot.

| Group | Parts |
| --- | --- |
| Wing | `wing_street`, `wing_gt`, `wing_duck`, `wing_rally` |
| Front lip | `lip_splitter` |
| Side skirts | `skirt_side` |
| Roof | `roof_rack` |
| Push bar | `bull_bar` |

**One part per group.** The native only refuses `conflicting_parts` when the catalogue
declares a conflict, and this catalogue declares none. The exclusivity is therefore
the studio's: the validator turns `{ [group] = { part, variant } }` into a complete
map that sets every other part of each offered group to `false` (removed). Picking a
second wing replaces the first, and **None** removes the group's part.

The price is 3,500 €$ times the number of groups that differ from the confirmed
kit, with a minimum of one: for example, a new wing and a lip cost 7,000 €$. Only
Light RP's own parts (`op77_lightrp:*`) are touched. Parts that another resource put
on the car stay.

#### Neon

Neon is the 8 presets of `shared/vehicle_customization.lua` `neon.colors`, a custom
colour and three brightness steps (`intensities`: 300 / 600 / 1200; the native's
default is 600; radius 3 m).

- A colour under 20 % HSV value lights nothing visible. The page flags it and never
  previews it, and the server refuses it ("This color is too dark to light anything.").
- **No neon** calls `clearNeon`.
- The confirmed view maps the stored intensity back to the nearest step.

#### Lights

The engine stores **one hue** (0..1) for the car's own lights, in the same visual
template as the paint (`paint.lightsHue`). `#800000` and `#FF0000` light the car
identically, and a grey has no hue: the native would read it as red.

- The page flags and never previews a colour under 25 % HSV saturation
  (`lightsMinSaturation`), and the server refuses it too.
- Equality is the hue the engine actually stored, read back with `getLightsHue`, so
  the same hue at another brightness is refused as unchanged.
- **Factory lights** clears the tint and is a lights job.
- The Bandit and the Apollo have `customizeLights = false` (E0.1), so `support` greys
  their Lights row.

#### Trim

A trim is an entity appearance variant from the model's curated list in
`shared/vehicle_customization.lua` `trims[catalogKey]`, measured for 12 models.

- The server accepts only an id listed for **that vehicle's** catalogue key, and
  applies the name from the table, never a client string.
- **Factory trim** goes back to the record's own variant (`setAppearance(id, nil)`).
- A model without entries does not show the row.

#### Plate

Only the data side is complete here. The plate is validated, unique, paid, persisted,
and shown in the studio header, the garage list and the ALT vehicle info
(`Archer Hella · Plate ABC1234 · Locked · …`).

- **Format.** The provisional format is in `plate`: exactly 7 characters, `A-Z` and `0-9`,
  upper-cased with spaces removed. The page checks it before any request.
- **Words.** Banned and reserved words come from `server/config/vehicle_customization.lua`
  `LightRpCustomizationPlates`, which is server only and never sent to a client.
  - A word matches anywhere in the plate as written, and in its leet reading
    (`0=O 1=I 3=E 4=A 5=S 7=T 8=B 9=G`).
  - A word that contains digits (`1488`, `SS88`) matches as written only, so
    `XIABB12` is allowed.
  - Reserved service names answer "This plate is reserved for city services.";
    banned words answer "This plate is not allowed.".
- **Uniqueness.** A plate is unique across **every owned vehicle on the server**: all
  rows are loaded at start. A plate being written is held until its SQL transaction
  ends.
- **Preview.** A preview is an availability check ("This plate is available.") and
  sets the `lightrpPlate` state bag on the car.
- **Rendering.** Nothing renders the text on the car yet: there is no native for it
  (contract section 7 reserves `visual.plate`). Rendering is behind one function,
  `renderPlate` in `server/modules/garages.lua`, marked `LEAD:`. Swap it there; it
  runs on retrieval and after `respawnAs` too.

#### Windows

There is no native, so the category is listed greyed **"Coming soon"** (`soon = true`).
It stays selectable: the editor shows the reason and nothing can be bought. Its price
entry is 0 and is not read.

#### Performance

Stages 1 to 3 are the TweakXL records `Vehicle.<dealer record>_o77s1..3` of the stage
resource (E5). The server asks for them through its export:
`Open77.exports.callSync("lightrp_vehicle_stages", "stageRecord", base, stage)`. A
client record name is never used.

**Fitting a stage.** A purchase calls `respawnAs(id, record)`, which keeps the same
id, the same place, the keys and the look. It runs only on an empty car at the
studio, so `vehicle_occupied` answers "Everyone must step out of the vehicle first."

**Pricing.** An upgrade pays every stage between the fitted one and the target, so
stock to Stage 3 on a Hella is 2,500 + 3,500 + 5,000 = 11,000 €$. Going down, or back
to stock, costs `performanceRemoval` (1,000 €$) and refunds nothing.

**Cooldown.** A vehicle can be tuned once per 10 minutes (`stages.cooldownMs`).

**Persistence.** The stage is stored in the row (`lightrp.stage`), and retrieval
spawns the stage record. If the stage record is missing on the server (resource
stopped, TweakXL absent), retrieval spawns the dealer record and the stage stays
stored.

**What the server greys:**

| Condition | Reason shown |
| --- | --- |
| No `respawnAs` on the server build | "This server build has no support for it yet." |
| The model has no stage prices | "No performance stage exists for this model." |
| The stage resource is not running | "Performance tuning is not installed on this server yet." |
| No stage record resolves | "No performance stage exists for this model." |

**What each client greys.** Each client checks the stage records in its own game with
`Open77.data.vehicle(record)`:

- a stage its game does not know is disabled, marked "· not in your game";
- with none left, the row is greyed "Your game has not loaded the performance stages
  (TweakXL)…".

**During the fit.** For 8 s the studio camera tolerates the car vanishing while it
is rebuilt, and re-anchors on it wherever the engine puts it.

### Prices

The server-only `server/config/vehicle_customization.lua` owns every tariff, in one
table, `LightRpCustomizationPricing`. Every price except paint is **provisional, for
the owner to confirm**, and `docs/economy-balance.md` §18 explains the choices. The
module refuses to load without a valid price for every sold category and every stage.

The page shows the quote and the balances. Insufficient funds and an unchanged
selection disable the purchase, and client prices are ignored. No payment is sent
automatically or retried on a timeout.

### Camera

The camera orbits the stationary car automatically. Pause/resume, step left or right
and zoom are local controls. The radius is limited to 4–10 m; the default shot is
6.5 m radius, 2.1 m height, 55° FOV, at 10°/s.

Each category change sends the client a framing request (`command = "preset"`). The
client eases to that category's shot over 700 ms, the short way round, relative to
the car's heading. Angles: 90 = in front, -90 = behind, 0 = right side.

| Preset | Angle | Radius | Height / target | Orbit |
| --- | --- | --- | --- | --- |
| default (paint, livery, trim, performance) | 35° | 6.5 m | 2.1 / 0.7 m | on |
| windows | 20° | 5.8 m | 1.5 / 0.95 m | on |
| rims | 15° | 4.2 m | 0.75 / 0.35 m | off |
| neon | 35° | 6 m | 0.45 / 0 m | on |
| lights | 90° (front) | 5.5 m | 1.1 / 0.6 m | off |
| plate | -90° (rear) | 4.2 m | 1 / 0.5 m | off |
| body | -55° | 6.5 m | 2.4 / 0.8 m | on |

A manual move cancels the blend, and the page's orbit button follows the preset's
orbit state. All values are in `shared/vehicle_customization.lua` `camera.presets`.

### End of session

These events release the session and restore the most recently saved look of
**every** category:

- Escape or Close;
- death, removal or movement;
- a character change, or leaving the garage or workshop;
- the five-minute expiry, or a disconnect.

Saving before closing keeps what was bought, and previews of other categories are
dropped. A save that is already committing when the client leaves is allowed to finish
for the original owned vehicle. Its server response is not routed to a replacement
session.

## Persistence and failure behavior

There is no second vehicle database and no new schema. The garage owns the lease, the
current network ID, the durable ownership UUID and the last confirmed look.

**How a purchase commits.** Every purchase passes the canonical `getProperties`
snapshot to `LightRP.money.exchange`. Three writes then commit in **one SQL
transaction** before success is acknowledged:

- the wallet or inventory cash debit;
- the existing `lightrp_owned_vehicles.properties` UPDATE;
- the ledger receipt.

**Ledger kinds:**

| Category | Ledger kind |
| --- | --- |
| Body paint | `vehicle_paint` |
| Lights | `vehicle_lights` |
| Trim | `vehicle_trim` |
| Livery | `vehicle_livery` |
| Rims | `vehicle_rims` |
| Body kit | `vehicle_bodykit` |
| Neon | `vehicle_neon` |
| Plate | `vehicle_plate` |
| Performance | `vehicle_stage` |

**Guarantees.**

- Duplicate request replay and a confirmed-value check per category prevent double charges.
- A failed transaction leaves both the original money and the confirmed look.
- Retrieval creates the car on the stored stage record with the saved `appearance`,
  then calls `setProperties` with the stored visual. Network IDs are never persisted.

### The confirmed-property mask

The lease (`row.edit` in `server/modules/garages.lua`) keeps two looks: `saved`, what
the SQL row holds, and `shown`, what the car wears. The `OWNS` table maps each
category to the fields it owns:

| Category | Fields |
| --- | --- |
| `paint` | `paint.applied`, `paint.primary`, `paint.secondary` |
| `lights` | `paint.lightsHue` |
| `trim` | `appearance` |
| `livery` | `visual.profile` |
| `neon` | `visual.neon` |
| `rims` | `visual.wheels` (`{ rim = "op77_lightrp:<rim>", variant }`) and that rim's entry in `visual.parts` |
| `body` | `visual.parts["op77_lightrp:<part>"]` |
| `plate` | `lightrp.plate` (Light RP's own field, never sent to `setProperties`) |
| `performance` | `lightrp.stage` (same) |

**What a capture writes.** Previews are authoritative, so other viewers see them.
While a lease is open, every property capture (periodic autosave, removal recovery,
close, disconnect) replaces **all** owned fields with the confirmed ones. A purchase
replaces all of them **except the category being bought** and its linked one (paint
and livery).

**Stored categories.** Plate and performance are `STORED`: the purchased value comes
from the lease, not from the car.

**Rollback.**

- A failed preview or purchase returns only its own category to the confirmed value;
  other previews stay.
- If native restoration fails, the lease stays locked and the garage worker retries
  rather than saving the preview.
- DB errors or insufficient funds restore the confirmed value and never acknowledge a
  successful purchase.
- Damage is captured independently: customization never repairs the vehicle.

**Dormant choices.** A stored visual choice the car cannot wear right now is kept
**dormant** in the row and comes back when it can. Examples: a part `listParts` no
longer lists for the record (catalogue change, refused registration), a livery the
record no longer offers, or a server without the visual natives. It is only dropped
when the owner buys that category again.

### Per-model availability

The server builds the offer per vehicle, and every category is listed. A category
this vehicle, this server or its packs cannot do is greyed, with its reason
(`unsupported` in `shared/vehicle_customization.lua`). Greyed rows stay selectable,
and their editor shows the reason.

| Category | Greyed when |
| --- | --- |
| Livery | No TwinTone profile; no native |
| Rims | No fit for the record; `lightrp_vk_rims` not running; no native |
| Body kit | No fitting part; `lightrp_vk_body` not running; no native |
| Neon | No native |
| Performance | See [Performance](#performance) |
| Windows | `windows.enabled` is false (the shipped value: "Coming soon"); the model has no window (`support`: Apollo, Kusanagi); `open77_vehicle_tint` not running; no native |

Two tables in `shared/vehicle_customization.lua` are keyed by the Light RP catalogue
key (`hella`, `kusanagi`, …):

- `support = { [catalogKey] = { category = false } }` greys a category for a model
  (the Bandit's and the Apollo's lights, the two bikes' windows). A model or category absent from the table is
  allowed. The server refuses any request for a greyed category.
- `trims = { [catalogKey] = { { id, label }, ... } }`: no entry hides the Trim row.

**Client greying.** On open, each client also greys what **its own game** cannot show:

- rims, body kit and windows when the pack resource is not running for it
  ("Your game has not loaded this workshop's parts. Reconnect…");
- livery when `customizationAvailable` reports no TwinTone;
- performance stages whose record its game does not know.

**Client warnings.** After a rims, body-kit or window tint answer, the client reads
`customizationAvailable(vehicleId).skipped`. It waits 1.5 s, then polls until 6 s,
once `appliedRev ≥ rev`. A skipped `attach:rims.*`, `attach:op77_lightrp:*` or
`tint:*` entry shows a warning in the editor (a `tint:*:pending_mesh` entry is the
client still waiting for the glass meshes: it is polled again):

| Skip reason | Warning |
| --- | --- |
| `model_not_registered` | "These parts are invisible in your game: its parts pack is missing…" |
| `slot_absent` | "This part has no mount point on this vehicle in your game." |
| `not_covered` (window tint) | "Your game shows no tint on this vehicle: its window tint pack is missing…" |
| anything else | "Part of this look could not be shown in your game." |

The server stays authoritative throughout: client checks only grey and warn.

**Validation.** Every mutation validates the source player, the active character, life
state, bucket, garage proximity, ownership, a stationary and empty vehicle, and the
session token. Each session accepts ordered requests and replays only the previous
response. These are refused:

- client-supplied native or record names;
- unknown categories, categories not offered, and greyed categories;
- ids outside this vehicle's offer (trim, livery profile, rim and finish, body part
  and finish, neon step, stage).

**Request pacing.** The server accepts one new preview per 200 ms, across all
categories, and the UI spaces queued previews by 230 ms. Garage operations and
character switching wait for the active customization lease.

## The vehicle kit catalogue

`server/config/vehicle_kit.lua` is **generated**: do not edit it. It is built by
`tools/build_vehicle_kit.py` from the fit tables of the Open77 repository
(`scripts/vehicle-kit/specs/lightrp-rims-fit.json` from E1,
`lightrp-bodykit-fit.json` and `lightrp-bodykit.json` from E2). Its header records
both sha256 hashes; the pack resources must be built from the same files. Every
offset is an **offline estimate** from mesh data until it is seen in game.

At start, `op77_lightrp` registers each part with **one `registerParts` call per
part**. A call is atomic, and the Lua-to-JSON marshaller caps the size of one call.
The ids are local; the platform namespaces them as `op77_lightrp:<id>`.

- **Rims.** `{ kind = "rim", label, variants = { finish = "asset:lightrp_vk_rims/<model>" },
  fit = rimFit }`. `rimFit[record]` holds `offset`, `scale` and `hide` (the stock
  wheel meshes), plus a B2 `wheels` list when the axles differ. A `wheels` list
  replaces the default slots, and each entry inherits the fit-level values and lists
  only what differs.
- **Body parts.** `{ kind = "part", slot = "Base", label, variants, fit = { [record] =
  { offset, rotation?, scale?, hide? } } }`. Keep `Base` for now: see the
  `evidence.lid` note in E2's `scripts/vehicle-kit/docs/bodykit.md`.

**Legacy fallback.** A server whose fits predate per-wheel lists refuses `wheels`.
Such a rim is registered again without them, so the records on default slots keep it,
while the Merrimac (middle axle) and the Apollo (bike slots) lose it. The log says
`auto studio: N kit parts registered, M rims without per-wheel fits (server predates them)`.
A part that is refused outright is logged as `auto studio: part <id> not registered (<reason>)`.

The rim fit of one model, the Archer Hella (the back axle sits 0.143 m further in):

```lua
["Vehicle.v_standard2_archer_hella_player"] = {
    offset = { -0.1001, 0, 0 },
    scale = { 0.9611, 0.9611, 0.9611 },
    wheels = {
        { slot = "wheel_front_left" },
        { slot = "wheel_front_right" },
        { slot = "wheel_back_left", offset = { -0.143, 0, 0 } },
        { slot = "wheel_back_right", offset = { -0.143, 0, 0 } },
    },
    hide = { "wheel_01_bl_a", "wheel_01_br_a", "wheel_01_fl_a", "wheel_01_fr_a" },
},
```

**Installing the packs.** The models ship in three pack resources that are **not
committed** here: `lightrp_vk_rims`, `lightrp_vk_body` and `lightrp_vehicle_stages`.
`resources/assets/models/lightrp_vehicle_kit/README.md` gives the lead's install
steps: where to copy them, `.gitignore`, `server.jsonc` load and `ensure` entries,
and the TweakXL ≥ 1.12.0 requirement.

## Clean presentation

The existing freecam uses the same `Open77.camera` definition/view/cleanup API. Auto
Studio also takes the documented `Open77.hud.setCinematic(true, 0.01)` claim
(`ui.vanilla.hud`, available since op77.78). It masks the native HUD and minimap,
the resource interfaces that are not focused (voice, chat history, watermark) and the
world labels. The minimum 1 % bars keep the original full-height menu framing, and
the focused workshop WebUI stays usable. Releasing with `setCinematic(false)` keeps
ordinary HUD hide claims and the claims of other resources.

The workshop and the RP HUD share one WebUI. A session-correlated
`customizationActive` store flag therefore hides the gameplay-interface wrapper
(HUD, notices, prompts and other page overlays) without unmounting those features or
losing their state.

- **Lifetime.** The flag is set when the camera prepares. It clears on close, refusal,
  death, movement, removal or resource stop.
- **Stale events.** A stale close event cannot unhide the HUD beneath a newer workshop
  session.
- **Feedback.** Payment feedback stays visible inside the workshop.

## Native capability map

All mutation APIs below are **server-side**. Runtime visual replication covers
current viewers, late joins and streaming back in.

| Category | Native APIs | Notes | Status |
| --- | --- | --- | --- |
| Body paint | `setPaint`, `resetPaint`, `getPaint` | Primary/secondary RGB, separate applied flag; clears a livery | Implemented |
| Livery | `listPaintProfiles`, `setPaintProfile`, `getVisual` | TwinTone profiles of the record; `invalid_profile` refused | Implemented (phase 2) |
| Rims | `registerParts`, `listParts`, `setWheels`, `getVisual` | One rim set; B2 per-wheel fits; key `rims.<slot>` | Implemented (phase 2) |
| Body kit | `registerParts`, `listParts`, `setParts`, `getVisual` | Slot `Base`; ≤ 16 attachments; exclusivity in Light RP | Implemented (phase 2) |
| Neon | `setNeon`, `clearNeon`, `getVisual` | Colour, intensity 0–5000, radius | Implemented (phase 2) |
| Light tint | `setHeadlightColor`, `clearLightsHue`, `setLightsHue`, `getLightsHue` | One hue in 0..1 | Implemented |
| Trim | `getAppearance`, `setAppearance` | Curated names, `world.vehicles.appearance` | Implemented |
| Performance | `respawnAs` (+ the stage resource's `stageRecord` export) | Same id; refuses `vehicle_occupied` / `invalid_record` | Implemented (phase 2) |
| Plate text | `setPlate` | Normalized text on the car's own plates; state bag `lightrpPlate` for menus | Implemented |
| Window tint | `setWindowTint`, `getWindowTint`, `getVisual().tint` | Levels 1-3 on side and rear glass; nil = factory. The switch is proven in game, the tinted glass is not: ArchiveXL leaves the pack materials unresolved, so the glass renders as factory (base `docs/research/vehicles-api.md`, "W1 — teinte en jeu") | Closed until it renders |
| Durable restoration | `getProperties`, `setProperties` | Version-1 visual is complete: unknown keys are refused | Through the garage |
| Client checks | `customizationAvailable` (client, `vehicles.read`), `Open77.data.vehicle` | Greying and skip warnings only | Feature-detected |

The manifest declares `world.vehicles` and `world.vehicles.appearance` (a change needs
both), `vehicles.read` and `camera.script`. The client only relays page requests and
reads its own game; every vehicle write is server-side.

## Adding a category

1. Register its ID, label and description in `shared/vehicle_customization.lua`, and
   its price in `server/config/vehicle_customization.lua`. The module refuses to load
   without a valid price for every sold category.
2. Add a strict validator in `server/modules/vehicle_customization.lua`
   (`validators`) that returns a trusted change `{ category = id, ... }`. Add an `OFFER`
   entry when availability depends on the model, a native or a pack, and extend
   `quote` if the price is not flat. Never dispatch a native named by the client.
3. In `server/modules/garages.lua`, add:
   - the fields it owns to `OWNS`;
   - `STORED` if Light RP stores it;
   - `LINKED` if it overwrites another category;
   - its apply step to `applyChange`;
   - its restore to `applyLook`;
   - its unchanged check to `UNCHANGED`;
   - its ledger kind (VARCHAR 24) to `RECEIPTS`.
4. Add its editor in `ui/src/features/customization/VehicleCustomization.tsx`:
   `KNOWN`, `keyOf`, `validOf`, `payload`, `draftsOf`, `TEXT`, `ICONS`, and
   `previewable` if it cannot be previewed. Send its confirmed value in `view()`.
   Unknown editor IDs stay locked, so no speculative category reaches players.
5. Add tests on the model of `tests/vehicle_customization_kit_test.lua`:
   - preview autosave isolation;
   - close and disconnect rollback;
   - a purchase of another category during its preview;
   - removal or disconnect during SQL;
   - retrieval after a restart.

## Verification

- Run `uv run --no-project --with lupa python tools/test-vehicle-customization.py` from
  the repository root. It runs the real garage, inventory, customization RPC and camera
  scripts against deterministic SQL and native boundaries.
  - **Payment and phase-1 suites:** atomic cash/bank purchase, server pricing, unchanged
    and insufficient-funds guards, failed transactions, duplicate requests, disconnect
    during SQL.
  - **`tests/vehicle_customization_categories_test.lua`:** lights, trim, mixed sessions,
    park + restart + retrieve, `support = false` and unknown models.
  - **`tests/vehicle_customization_kit_test.lua`:**
    - the offer order;
    - the catalogue contract (ids, limits, keys `registerParts` accepts, wheels lists,
      body groups);
    - livery (linked paint, rollback);
    - rims (finish, factory rims, other-model ids refused);
    - body kit (one part per group, priced per group changed, foreign parts kept);
    - neon (presets, dark colours refused, removal);
    - plates (format, banned and reserved words, leet, the `X1488XX` / `XIABB12` cases,
      uniqueness, a plate held during SQL);
    - performance (sum of stages, removal fee, cooldown, occupied car, record absent on
      the server, no preview);
    - persistence through a reboot;
    - dormant rims while the pack is off;
    - stage records offline at retrieval;
    - greying when natives or packs are missing;
    - the legacy registration without B2.
  - **`tests/vehicle_customization_client_test.lua`:** relaying without any client
    vehicle write, local greying (pack, TwinTone, stage records), presets, the respawn
    grace and skip warnings.
- Run `npm run build --prefix ui`. Then restore `web/safezone`, which is hand-written:
  vite's `emptyOutDir` deletes it, so run
  `git checkout -- resources/gamemodes/op77_lightrp/web/safezone`.
- Run the browser test:
  `PLAYWRIGHT_MODULE=/path/to/playwright CHROMIUM_PATH=/path/to/chrome node ui/tests/customization.browser.cjs`.
  - **Phase-1 checks:** paint, lights and trim flows, then layouts.
  - **Full studio:**
    - ten categories in the compact grid;
    - Windows and Trim greyed yet selectable with their reason;
    - framing presets per category;
    - rims and finish with a client warning;
    - body groups (a second wing replaces the first, two groups cost 7,000);
    - neon presets, brightness and the dark-colour refusal;
    - plate normalisation, format and availability;
    - stages without preview, the missing-record stage disabled, the removal fee;
    - the linked livery and paint;
    - the camera state;
    - layouts at 1920x1080, 1280x720 and 800x600 with nothing widening the panel.

  Screenshots go to the ignored `ui/artifacts/vehicle-customization-*.png`.
- Run `pwsh -File scripts/check-lua.ps1 -Path <file>` from the Open77 repository on
  each changed Lua file. Lua files carry no BOM.

## Lab checklist (two clients)

**Setup.** The lead installs the packs (README above) with TweakXL ≥ 1.12.0, and the
server log shows `auto studio: 16 kit parts registered`. Client **A** owns an Archer
Hella, which has every category: 5 trims, all 8 body parts and split-axle rims. A
Thorton Merrimac and a Brennan Apollo are also owned, by A or B. Client **B** stands
within 20 m of Bay 01. Both clients connected after the packs were added.

| # | Steps | Expected |
| --- | --- | --- |
| 1 | A parks the Hella at Bay 01, steps out, presses E | 10 categories in a 2-column grid; Windows greyed "Coming soon", selectable, nothing to buy; the camera frames per category (rims low and close, plate from behind) |
| 2 | A previews Deep Dish 8 black, then Factory rims | B sees the rims on all four wheels, the back pair flush with its tyres (its offset differs from the front), no stock rim showing through; Factory rims gives the stock wheels back on both clients |
| 3 | A buys a rim set; parks; the server restarts; A retrieves | Wallet −6,000, ledger `vehicle_rims`; same rims on A and B, also after B streams the car out and back in (> 35 m) |
| 4 | Same with the Merrimac, then the Apollo | Merrimac: six wheels including the middle axle; Apollo: front and back rims on the bike slots. Kusanagi: Rims greyed "No rim fits this model yet." |
| 5 | Body kit on the Hella: GT wing, then Street wing, then a lip | One wing at a time on both clients; the price reads 7,000 for wing + lip; buy; ledger `vehicle_bodykit` |
| 6 | Neon: Cyan Medium, then a custom `#101010`, then Red High; buy; then No neon and close | B sees cyan, then red under the car; `#101010` is flagged and never shown; closing after No neon puts the bought red back |
| 7 | Livery: Scheme 1 if the Hella lists one (otherwise test on a model that does) | Two-tone on B; the paint editor shows Factory finish; buy; then buy a body paint: the scheme goes away on both clients |
| 8 | Plate: type `ab 12` (refused locally), `NCPD001` (reserved), `SH1T123` (not allowed), a free one; register it | Server messages as listed; "This plate is available." then purchase; the header, garage list and ALT info show it; B tries the same plate on his car: "already registered" |
| 9 | Performance: B gets into the Hella while A has the studio open; then A reopens it with the car empty and fits Stage 1 | B entering closes A's session (occupied car); then the car is rebuilt in place with the same keys and look on both clients; the header reads STAGE 1; driving shows the stage's top speed (E5 table); a second change within 10 min is refused with the minutes left |
| 10 | Park, restart the server, retrieve; stop `lightrp_vehicle_stages`, retrieve again | Stage 1 comes back. With the stages resource stopped, the car spawns stock and the stage stays stored; Performance greyed "…not installed on this server yet." |
| 11 | A client without the rims pack: B stays connected while the lead first starts `lightrp_vk_rims` (no reconnect), or B's download of it failed | B's studio greys Rims "Your game has not loaded this workshop's parts…"; note what B sees on A's car (stock wheels, or bare hubs if the hide applies without the part); if B's pack resource runs but its models are missing, B's own rim preview shows "…parts pack is missing…" |
| 12 | During any preview, A presses Escape / dies / drives off | The confirmed look of every category comes back on both clients; no ledger entry |
| 13 | Read the server and client logs | No `part … not registered`, no `customization rollback pending`; client `red4ext/logs/open77-*.log` has no `attach:` skip for the Hella; `TweakXL-*.log` reads `LightRP\open77-lightrp-stages.yaml` |

Fill `support`, the rim and body fits, and the stage values from these
measurements: which records render rims and parts where expected, and which stages
drive as tabled.

## Open questions for the owner

- **Prices.** The livery (4,000), rims (6,000 per set) and body kit (3,500 per group)
  prices are provisional, and so are neon (5,000), plate (2,500), lights (500) and
  trim (2,500). The stage prices are E5's proposal: 10/15/20 % of the dealer price,
  weighted by the engine actually delivered. The 1,000 €$ removal fee and the 10 min
  cooldown are also provisional. See `docs/economy-balance.md` §18.
- **Plate format.** Seven characters A-Z/0-9 is a placeholder; a pattern such as
  `NC` + 5 or 3 letters + 4 digits, or a vanity length, is the owner's call. The
  banned and reserved lists also need the owner's extension.
- **Labels.** The livery schemes are "Scheme N" because profiles have no name; the
  rim names come from E1 (Classic 10, Lattice, Deep Dish 8, …); the body groups are
  Wing / Front lip / Side skirts / Roof / Push bar; the finishes are Chrome, Black,
  White, Bronze, Gunmetal, Carbon, Aluminium and Steel. All are the owner's to rename.
