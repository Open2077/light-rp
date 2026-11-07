# Vehicle customization / Auto Studio

The sources of this work:

- Paint landed from `feat/vehicle-customization` (`3fa7f22`).
- Lights, trim and the per-model support table come from `vc/a-lightrp-phase1`
  (campaign plan `PLAN-vehicle-custom.md`, phase 1).
- The complete studio (plan §3.10) comes from `vc/a3-studio-full`: livery, rims, body
  kit, neon, plate, performance stages and per-category camera framing.
- Window tint comes from `feat/auto-studio-full` on top of the native
  `Open77.vehicles.setWindowTint` (base `feat/vehicle-customization`, W1, 2026-11-06).
  The category is **open** since `ba146785` (2026-11-07), once the tinted glass rendered
  in game: see [Windows](#windows).
- Wave 2 (neon animation, lamp colors, engine sound, stickers and the tag) comes from
  `lr/studio-extras` (campaign plan `PLAN-vehicle-custom-wave2.md`, "Auto Studio"). It
  was written against the shared contract of the wave 2 natives before any build had
  them: see [Wave 2 categories](#wave-2-categories).

The phase-1 API mapping was checked with the Open77 Devkit MCP for
**2.50.0+op77.156**. The phase-2 natives (`listPaintProfiles`, `setPaintProfile`,
`setNeon`, `clearNeon`, `registerParts`, `listParts`, `setParts`, `setWheels`,
`setPlate`, `setWindowTint`, `getVisual`, `respawnAs`, client
`customizationAvailable`) are those of the phase-2 platform build
(`feat/vehicle-customization`). The devkit catalogue does not list them yet, so every
one of them is **feature-detected**. A server or client without a native greys its
category with a reason and never fails.

The wave 2 natives (`setNeonAnimation`, `getNeonAnimation`, `setLightColors`,
`getLightColors`, `listEngineSounds`, `setEngineSound`, `getEngineSound`,
`listStickers`, `setStickers`, `getStickers`, `getDecalBudget`, `setTag`) are
feature-detected the same way. The five categories also need the garage's category
registry, `Garage.registerCustomizationCategory`, which `server/modules/garages.lua`
does not have yet: see [The garage's category registry](#the-garages-category-registry).

The platform side (every native, the FiveM aliases, packs and engine limits) is
documented in the Open77 wiki, `wiki/vehicle-customization.md`.

## Status in game

Every category below was checked in the lab on **two clients** on 2026-11-07: A owns and
buys, B watches (campaign ledger `PLAN-vehicle-custom.md` §10, results in
[Wave 1 lab results](#wave-1-lab-results) and [Wave 2 lab results](#wave-2-lab-results)).
The one-client checks of 2026-11-05 and 2026-11-06 (frame-by-frame fits, the 12-decal
livery fix, the Caliburn) are in the ledger.

| Category | Seen on two clients |
| --- | --- |
| Body paint | Bought; replaces a bought livery on A and B (the car is rebuilt, 1 to 3 s without its parts) |
| Livery (factory and pack) | Factory scheme and the pack's taxi previewed, taxi bought; seen by B; back after a server restart, an impound and a redelivery |
| Rims | Deep Dish 8 black previewed and bought; on the four wheels for B, nothing of the factory rim showing; back on A and B after a server restart, an impound, a redelivery and a stream-in; Factory rims gives the stock wheels back |
| Body kit | GT wing, then Street wing alone, then a lip, for B; wing + lip bought for 7,000; back after a restart. See the delivery height note below |
| Neon | Cyan, then red, for B; `#101010` refused; No neon then closing gives the bought red back on A and B |
| Lights | Red, cyan and Factory lights previewed at night; the headlights change colour for B, glow and beam; cyan bought; back after closing the studio, a stream-out, and a server restart with an impound and a redelivery. Needs the Open77 client with `1ee95687`: older clients keep white headlights whatever the hue |
| Plate | Reserved and banned plates refused, a plate already on another car refused; bought; B reads it within 9 m; back after a restart, rewritten when B comes within 9 m after a stream-in |
| Windows | Limo bought in the studio for 1,500; seen by B and changed live; kept through a restart, an impound, a reconnect, a stream-out and the distance proxy. Needs the Open77 client with `b9f21aa3` and `15013360`, and the tint pack `75b3fcbb2b6e` |
| Performance | B taking the wheel closes A's studio; Stage 1 rebuilds the car with its whole look on A and B; a second change within 10 min is refused; back after a restart |
| Driver change | B drives A's car, then A drives it: the whole look stays on both clients. B, who holds no key, was also put at the wheel with the staff command `vehicle.warp` and drove off: the variant, the headlight tint, the taxi livery and the sticker stayed on A and B |
| Trim | `archer_hella__basic_poor_2` previewed and bought; B sees the variant with the paint, kit, rims, neon and headlight tint put back; kept through a stream-out and back, the body coming back directly in the variant; Factory trim bought: the factory front is back on A and B. Bought again, then a server restart, both clients joining late and a redelivery from the garage: A and B see the variant with the whole look |
| Wave 2 (neon animation, lamp colors, engine sound, stickers, tag) | Rows 12, 14-18, 20 on the current build, 21, and 22 on the Hella; see [Wave 2 lab results](#wave-2-lab-results). The neon animation needs the Open77 client fix `a0999cf9`, and stickers need `843f8cc4`. Tag waits for the `setTag` native |

**Delivery height.** A car that the garage puts on a bay sits at the bay's height, and
nobody simulates it until someone drives it. On Bay 01 the Hella's root is at z = 11.20, while
driven it rests at 11.38 on a floor at 11.015. So a delivered car shows its tyres about 18 cm
into the floor, and a front lip (offset −0.666 m from `Base`) sits under the floor until the car
is driven. Measured on 2026-11-07: lip at z = 10.97, invisible; after a 5 m drive, lip at 11.55,
red and visible on A and B. This is not a kit fault. The fix (bay heights at the rest height, or
`Open77.world.groundZ` plus a measured rest height per model) changes every garage delivery and
is for the owner to decide (`PLAN-vehicle-custom.md` §10).

**The Hella's side skirts.** The side skirts in the table were bought on the Hella with
the first, 8-part catalogue, where `skirt_side` had a Hella fit. The 30-part kit keeps the id
`skirt_side` but gives the Hella no fit for it, nor for `skirt_blade`, `skirt_rocker` or the
rear louvers `louver_rear` (the 8-part catalogue had no rear louvers at all). So the studio
no longer offers side skirts or rear louvers on the Hella. From the code, not seen in game: a
Hella stored with those skirts comes out of the garage with the rest of its look, and the
skirts stay stored as a dormant choice (`restorable` in `server/modules/garages.lua` keeps
only the parts `Open77.vehicles.listParts` gives for the record).

**Lab commands are not part of this repository.** The in-game checks used a lab
harness that lives outside the repository. No lab command is a feature of Light RP,
and none is documented here. Players reach the studio only through the bays and the
garage, as described below.

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

- the vehicle header, which shows the plate (or `#id`) and ` · STAGE n`. `n` is the stage the
  car runs: a stage kept dormant because its records are offline does not show until the car
  runs it again;
- the category navigation: a two-column grid once more than four categories are offered,
  and three columns of labels without icons when more than ten are offered on a screen
  under 700 px tall. A sub-panel (Animation under Neon, Lamp colors under Lights) is not
  a row of the navigation but a tab at the top of its parent's editor;
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
exception**: a stage is fitted on purchase and never previewed. **Engine sound**
previews only on request (**Hear it on the car**), since each change rebuilds the car.

| Category | Editor | Natives (server) | Price (`server/config/vehicle_customization.lua`) |
| --- | --- | --- | --- |
| Body paint | Primary / Secondary, 12 presets, picker, HEX, **Factory finish** | `setPaint`, `resetPaint` | **2,500 €$** (owner, 2026-11-05) |
| Livery | **Plain paint** + the model's factory two-tone schemes ("Scheme N") + the liveries a pack registered (their own label), each with a main/secondary swatch | `listPaintProfiles`, `setPaintProfile` | 4,000 €$, provisional |
| Rims | **Factory rims** + the rims that fit this record, then the finish | `listParts`, `setWheels` | 6,000 €$ per set, provisional |
| Body kit | One row per group (Wing, Rear louvers, Front lip, Canards, Side skirts, Rear diffuser, Hood, Roof, Front protection): **None** + the parts that fit, then the finish | `listParts`, `setParts` | 3,500 €$ **per group changed**, provisional |
| Neon | 8 presets, picker, HEX, brightness Low / Medium / High, **No neon** | `setNeon`, `clearNeon` | 5,000 €$, provisional |
| Neon › Animation (wave 2) | A tab of Neon: **Static**, Pulse, Breathe, Strobe, Chase, Rainbow (speed Slow / Medium / Fast; Chase takes a second color), Follows speed, Flash on braking | `setNeonAnimation` (`getNeonAnimation`) | 2,500 €$, provisional |
| Lights | 12 saturated presets, picker, HEX, **Factory lights** | `setHeadlightColor`, `clearLightsHue` (restore: `setLightsHue`) | 500 €$, provisional |
| Lights › Lamp colors (wave 2) | A tab of Lights: Brake lights, Reverse lights, Blinkers, Interior, each factory, one of 10 presets or the picker | `setLightColors` (`getLightColors`) | 1,500 €$ for any number of groups, provisional |
| Trim | **Factory trim** + the variants curated for the model | `setAppearance` (`getAppearance` to skip restatements) | 2,500 €$, provisional |
| Plate | Plate number field + plate visual; the server answers availability | `setPlate` when the server has it; stored by Light RP, mirrored in the `lightrpPlate` state bag | 2,500 €$, provisional |
| Stickers (wave 2) | **No stickers** + the stickers that fit, by group, with the decal meter | `listStickers`, `setStickers`, `getStickers`, `getDecalBudget` | 1,500 €$ **per sticker added**, provisional |
| Tag (wave 2) | Listed only with `setTag`: **No tag**, text (1 to 12 characters), font, color, spot | `setTag` | 2,000 €$, provisional |
| Windows | **Factory glass**, Light smoke, Dark smoke, Limo (side and rear glass; the windshield stays clear) | `setWindowTint` (levels 1-3, nil = factory) | 1,500 €$, provisional |
| Performance | Stock / Stage 1 / Stage 2 / Stage 3, each with its price | `respawnAs` onto `Vehicle.<dealer record>_o77sN` | per model and stage, provisional; going down costs 1,000 €$ |
| Engine sound (wave 2) | **Factory sound** + the sounds that fit; **Hear it on the car** | `listEngineSounds`, `setEngineSound` (`getEngineSound`), `setEngineHold` | 6,000 €$, provisional |

#### Body paint

Pure black is a real colour, distinct from **Factory finish**. Both channels are one
job, and resetting a custom finish to factory paint is also a paint job. Generic
paint **replaces a livery**: the server clears the profile, and the page moves the
livery draft back to Plain paint.

#### Livery

A livery is one of the record's TwinTone profiles, listed by
`listPaintProfiles(vehicleId)`: the factory ones first, in the order the engine gives
them, then the ones a running resource registered with `registerPaintProfiles`.

- **Labels.** A factory profile has no name, so it is labelled "Scheme N", counting
  factory profiles only. A pack profile keeps the `label` its resource registered.
- **Pack liveries.** The Light RP livery pack is `lightrp_vk_liveries`, built in the
  Open77 repository (`scripts/vehicle-kit/liveries`: 12 designs on the 11 dealer
  models that take a TwinTone template, 132 records) and not committed here. It
  needs TweakXL on every client. It registers its profiles at start; when it stops,
  its profiles leave the list, and a car wearing one keeps the choice dormant.
- **12-decal cap.** A livery template with more than 12 `customDecals` crashes the
  client that spawns the car. The pack builder folds stripes into doors and refuses a
  template above 12; do not hand-edit its YAML past that.
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
- A client whose game lacks the livery pack cannot draw a pack livery: its
  `customizationAvailable().skipped` lists `profile:<id>:not_for_model`. The pack
  resource is server-only, so the client cannot grey the option beforehand; after a
  livery preview the studio warns instead (see "Client warnings").

#### Rims

The rims are the 18 original rims of the vehicle kit (E1 then E1e), 6 finishes each:
108 models in the pack `lightrp_vk_rims`. They are offered only on records that have a
fit: 14 dealer records, including the Merrimac's middle axle and the Apollo, and the
staff-only Rayfield Caliburn (15 records). The Kusanagi is excluded because its hubless
front ring leaves no room for a spoked rim. The Caliburn's fit (2026-11-06) is an offline
estimate that has not been seen in game.

- The fit is per wheel (B2) and per trim (`fit.appearances`): see
  [The vehicle kit catalogue](#the-vehicle-kit-catalogue).
- The request names a rim and a finish that this vehicle's offer lists, and the server
  calls `setWheels(id, { rim = "op77_lightrp:<rim>", variant })`.
- **Factory rims** calls `setWheels(id, nil)`.
- The native keeps one rim set per car.

#### Body kit

The body kit is the 30 parts of E2 (then E2b), in 9 groups, with 82 variant models
in the pack `lightrp_vk_body` and 251 fits on 14 records, all in the `Base` slot. The
Thrax takes all 9 groups, the Merrimac 3; the Hella takes 25 parts in 7 groups (no
rear louvers, no side skirts). The staff-only Caliburn (added 2026-11-06, offline
estimate, not seen in game) takes 13 parts in 6 groups: seven wings, which hide its
active rear wing and stand in its housing, the louvers on the engine glass, two lips,
the street diffuser, the hood vents and the roof scoop.

Parts on an opening panel follow it (contract section 5, "Carried parts"): the wings
except `wing_roof` and the rear louvers name the trunk lid's slot as their `carrier`,
the hood scoop and vents the hood's, so a wing rises with the trunk lid instead of
staying in mid-air. On a car where the fit table's `evidence.lid` finds no lid under
the part (the Bandit's, Quartz's, Semimaru's or Caliburn's wings, the Thrax's louvers), the fit
says `carrier = false` and the part stays on the body.

| Group | Parts |
| --- | --- |
| Wing | `wing_street`, `wing_gt`, `wing_duck`, `wing_rally`, `wing_lip`, `wing_low`, `wing_dual`, `wing_drift`, `wing_bat`, `wing_roof` |
| Rear louvers | `louver_rear` |
| Front lip | `lip_splitter`, `lip_race`, `lip_street` |
| Canards | `canard_dive`, `canard_fin` |
| Side skirts | `skirt_side`, `skirt_blade`, `skirt_rocker` |
| Rear diffuser | `diffuser_street`, `diffuser_race` |
| Hood | `hood_scoop`, `hood_vents` |
| Roof | `roof_rack`, `roof_bars`, `roof_tray`, `roof_lightbar`, `roof_scoop` |
| Front protection | `bull_bar`, `tow_strap` |

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
- **What shows is the headlights**, lamp glow and beam, at full saturation. The engine
  keeps the hue in the template but does not tint the headlights from it: on 2026-11-07,
  before the client fix, a red hue left the Hella's headlights white for both clients
  (front lamp `242,237,232` against `241,235,228` stock). The Open77 client sets the
  headlight colour itself since `1ee95687`. Measured for B after the fix, around the lamps:
  red `216,91,118`, cyan `128,197,198`, stock `228,209,179`. Brake, reverse, blinker and
  interior lamps are the [Lamp colors](#lamp-colors) tab.

#### Trim

A trim is an entity appearance variant from the model's curated list in
`shared/vehicle_customization.lua` `trims[catalogKey]`, measured for 11 models.

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
  puts the text on the car like any preview; closing without buying restores the
  stored plate.
- **Rendering.** `renderPlate` in `server/modules/garages.lua` sets the `lightrpPlate`
  state bag (read by the menus) and calls `Open77.vehicles.setPlate(id, plate)` when the
  server has that native. It runs on preview, purchase, rollback and retrieval;
  `respawnAs` carries the plate with the rest of the look and the state bag. A
  server without `setPlate` keeps the data side only, and the car shows its factory
  plate. Every Light RP plate (7 characters, `A-Z0-9`) passes the native's own rule
  (`A-Z`, `0-9`, space and `-`, 1 to 10 characters).
- **What a client needs.** The text is drawn by the plate pack (`open77_vehicle_plates`,
  an ArchiveXL patch) and a script that ships with the Open77 client. A client without
  the pack, or a model the pack does not cover, shows the factory plate.
- **The 9 m rebuild.** The engine only builds the plate's text widget when the car is
  born within about 10 m of the camera. A car born further away is rebuilt once by the
  client when it comes within 9 m, empty and stopped; it vanishes for about 0.4 s. A
  car that is moving or occupied keeps a blank plate until then. This is the Open77
  client's behaviour (base `e13ceac4`), seen on one client with four cars.

#### Windows

**Open** since `ba146785` (`windows.enabled = true` in `shared/vehicle_customization.lua`).
Factory glass, Light smoke, Dark smoke and Limo (native levels 1 to 3) on the side and
rear glass; the windshield is never tinted. 1,500 €$ provisional, for any level or for
going back to factory glass. Ledger kind `vehicle_tint`, field `visual.tint` in the
confirmed-property mask.

**What it needs.** The tinted glass renders only with an Open77 client that switches the
glass by a resource load followed by an appearance refresh (`b9f21aa3`), and that switches
it again when the car comes back from the distance proxy (`15013360`). The tint pack
`open77_vehicle_tint` must be revision `75b3fcbb2b6e` or later: its `client.lua` makes the
pack visible to the client's resource state, which the studio checks. An older client
shows factory glass; an older pack greys the row "Window tinting is not installed on this
server yet." The cause and the measurements are in base `docs/research/vehicles-api.md`,
"W1 résolu".

**Proven on 2026-11-07, two clients.** On the Hella: free Limo preview, Apply tint charged
1,500 from the bank, `visual.tint = 3`. B saw each level change live. The level came back
after a server restart with an impound and a redelivery, after a reconnect, after a
stream-out of 450 m, and through the distance proxy. Measured glass luminance on B: factory
46.8, Limo 40.8.

**Greying.** The two bikes have no window (`support`); the row is greyed when
`open77_vehicle_tint` is not running or not visible; a server can close the category again
with `windows.enabled = false`, which greys it "Coming soon." and refuses any request. The
client warns `not_covered` when its game has no tinted glass for the car.

#### Performance

Stages 1 to 3 are the TweakXL records `Vehicle.<dealer record>_o77s1..3` of the stage
resource (E5). The server asks for them through its export:
`Open77.exports.callSync("lightrp_vehicle_stages", "stageRecord", base, stage)`. A
client record name is never used.

**TweakXL 1.12.0 or later.** The stage resource declares `dependency 'tweakxl >=1.12.0'`.
Without a 1.12 loader in `resources.load` it does not start, and Performance is greyed
"Performance tuning is not installed on this server yet." A client whose game did not
load the records greys the stages itself (see below). TweakXL is executable content:
the world must stay `requiredMods.unsecured = true`.

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

#### Wave 2 categories

Five categories of the wave 2 plan (`PLAN-vehicle-custom-wave2.md`, "Auto Studio"),
written against the shared contract before any build had their natives. **Four of them
were seen in game on two clients on 2026-11-07**: neon animation, lamp colors, engine
sound and stickers (see [Status in game](#status-in-game) and
[Wave 2 lab results](#wave-2-lab-results)). The tag waits for the `setTag` native, which no
build has. Each one is a `getProperties` field (`neonAnimation`,
`lightColors`, `engineSound`, `stickers`, `tag`) read and written by its own natives.
The contract names the keys but not their table, so the module reads them from
`visual` or from the top level, and writes a copy where its source keeps it.

They go through the same preview, purchase and persistence flow as the others, with
one condition: the garage must have its category registry (see
[The garage's category registry](#the-garages-category-registry)). Without it, an
autosave during a preview would store the preview, so the five rows are greyed "This
studio cannot store it on your vehicle yet." even when the natives exist.

#### Neon animation

A tab of the Neon editor, bought on its own (ledger kind `vehicle_neon_anim`).

- **Modes.** Static, or one of seven: Pulse, Breathe, Strobe, Chase and Rainbow take a
  speed (Slow 2.4 s, Medium 1.2 s, Fast 0.6 s per cycle); Follows speed and Flash on
  braking run on a 1 s cycle. Chase takes a second color from the neon presets. The
  cycle comes from the speed step, never from the client.
- **It runs on the neon.** A preview needs a neon shown on the car, a purchase a neon
  bought ("Buy a neon kit first: the animation runs on it.").
- **Emergency looks are refused:** a strobe on a red or blue neon, and a chase
  alternating red and blue. Strobe never runs faster than 3 Hz (`strobeMinPeriodMs`).
  The neon editor checks the reverse: a red neon under a strobe the car shows or the
  owner bought is refused too.

#### Lamp colors

A tab of the Lights editor, bought on its own (ledger kind `vehicle_lamps`).

- **Groups.** Brake lights, Reverse lights, Blinkers and Interior, each factory or one
  color (10 presets or the picker). One purchase covers any number of groups, and
  putting every group back to factory is a change too.
- **Refused, as emergency looks:** blue brake lights, red or blue blinkers ("Blinkers
  cannot be red: it reads as an emergency vehicle."). The swatches are disabled and the
  server refuses them.
- **Visibility.** Brake lights and blinkers must keep an HSV value of 0.35 at least.
- **What counts as red or blue.** A hue of 340-20° is red and 195-255° is blue, only
  from an HSV saturation of 0.35: a pale pink is not red. The ranges are
  `emergency` in `shared/vehicle_customization.lua`, mirrored in the page.

#### Engine sound

Ledger kind `vehicle_engine_sound`.

- **Choices.** **Factory sound** + the sounds `listEngineSounds(vehicleId)` gives for
  the model. With none, the row is greyed "No other engine sound fits this model."
- **Every change rebuilds the car**, like a stage: the platform respawns it on
  `Vehicle.<base>_o77a<k>`, or `Vehicle.<base>_o77s<n>a<k>` with a stage. So choosing
  a sound sends nothing. **Hear it on the car** previews it (the status line reads
  "PREVIEW ON REQUEST", then "REBUILDING…"), at most once per 4 s
  (`engineSound.previewCooldownMs`). `engineSound.preview = false` sells it without a
  preview, like Performance.
- **Hearing it.** After a successful preview or purchase, the studio keeps the empty
  car's engine running (`setEngineHold`, `engineSound.listen`); closing the studio stops
  it (`setEngine(id, false)`). A refused hold is logged `auto studio: engine hold refused
  on <id>`.
- **During the rebuild.** As for a stage, the client camera tolerates the car vanishing
  for 8 s and re-anchors on it.
- **With a stage.** Fitting a stage keeps the sound: the garage puts it back after
  `respawnAs` (registry patch).

#### Stickers

Ledger kind `vehicle_stickers`.

- **Choices.** **No stickers** + the stickers `listStickers(vehicleId)` gives for the
  car, grouped by their `group`. Each sticker takes `decals` of the decal budget (1 when
  absent), goes on once, and the car takes 12 stickers at most (`stickers.maxPerCar`).
- **The decal budget is shared with the livery**: 12 decals at most on one car, livery
  included (13 crashed every client that saw the car, see
  [Livery](#livery)). `getDecalBudget(vehicleId)` gives `used` and `maximum`; the module
  subtracts the stickers the car wears to get what the livery leaves. The meter shows
  that plus the chosen stickers; above the maximum, the page previews nothing ("Too many
  decals: 15 of 12. Remove a sticker.") and the server refuses too.
- **Some liveries leave no room.** Measured on the Hella on 2026-11-07: the pack's racing
  livery uses the 12 decals by itself, so any sticker on it is refused ("Too many decals: 13
  of 12"); the taxi livery uses 11, so `st.hella.6th_street_01` still fits (12 of 12) and a
  bigger sticker on top is refused.
- **A livery preview moves the meter.** Every response carries the budget the car shows
  now. A livery and stickers are never bought while the other is previewed ("Apply or
  undo your livery preview first: stickers share its decal budget.").
- **Price per sticker added.** A change that only removes stickers costs one sticker.
- **Theme packs.** Open77's original sticker pack (`lightrp_vehicle_original_stickers`,
  built by `scripts/vehicle-kit/stickers` in the Open77 repository) registers one group
  per theme: `Original: Race`, `Original: Graffiti`, `Original: Circuit`,
  `Original: Wave and sun`, `Original: Pinstripe`. Each is its own section of the
  page, with no change to Light RP. A theme's set takes 2 to 9 decals, so two themes on
  one car can pass 12: the meter and the server refuse it, as above. Seen in game on
  2026-11-07, on the Hella, two clients: the Race set with a 6th Street sticker made 12
  decals on A and B, and adding the Graffiti set was refused ("Too many decals: 18 of 12").
  The Circuit, Wave and sun and Pinstripe themes were not shown in game. The owner kept
  the five themes on 2026-11-07.

#### Tag

The stretch goal W2.5 (ledger kind `vehicle_tag`).

- **Listed only when the server has `setTag`**: without it there is no row, not even
  greyed (`capability = "setTag"` in `shared/vehicle_customization.lua`).
- **Text.** 1 to 12 characters of `A-Z a-z 0-9 space - . ! ? # &`; runs of spaces are
  folded. The plate's banned and reserved words apply ("This tag is not allowed.",
  "This tag is reserved for city services.").
- **Font** (Marker, Block, Script), **spot** (Left door, Right door, Hood, Trunk) and 8
  colors. The font and spot ids are guesses until the native lands.
- **No getter.** The contract has no `getTag`: the module reads the `tag` field of
  `getProperties`.

### Prices

The server-only `server/config/vehicle_customization.lua` owns every tariff, in one
table, `LightRpCustomizationPricing`. Every price except paint is **provisional, for
the owner to confirm**, and `docs/economy-balance.md` §18 explains the choices. The
module refuses to load without a valid price for every sold category and every stage.

Stickers are priced per sticker added; every other wave 2 category is one price per
change.

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
| neonAnimation | 35° | 6 m | 0.45 / 0 m | on |
| lightColors | -60° (rear three-quarter) | 5.5 m | 1.2 / 0.6 m | off |
| engineSound | 60° | 5 m | 0.9 / 0.5 m | off |
| stickers | 0° (right side) | 6 m | 1.4 / 0.7 m | on |
| tag | 0° (right side) | 5.5 m | 1.3 / 0.7 m | on |

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
If the studio kept the engine running for an engine sound, it stops it.

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
| Windows | `vehicle_tint` |
| Plate | `vehicle_plate` |
| Performance | `vehicle_stage` |
| Neon animation | `vehicle_neon_anim` |
| Lamp colors | `vehicle_lamps` |
| Stickers | `vehicle_stickers` |
| Tag | `vehicle_tag` |
| Engine sound | `vehicle_engine_sound` |

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
| `windows` | `visual.tint` |
| `rims` | `visual.wheels` (`{ rim = "op77_lightrp:<rim>", variant }`) and that rim's entry in `visual.parts` |
| `body` | `visual.parts["op77_lightrp:<part>"]` |
| `plate` | `lightrp.plate` (Light RP's own field, never sent to `setProperties`) |
| `performance` | `lightrp.stage` (same) |
| `neonAnimation`, `lightColors`, `engineSound`, `stickers`, `tag` (wave 2) | The field of the same name, in `visual` or at the top level, wherever `getProperties` keeps it. Declared through the [category registry](#the-garages-category-registry) |

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
when the owner buys that category again. A wave 2 choice a server build cannot put on
the car (its setter is missing) is kept the same way, in `row.dormantExtra`.

### The garage's category registry

The wave 2 categories are not written into `server/modules/garages.lua`: the studio
declares them at load with `Garage.registerCustomizationCategory(id, spec)`.
**That function is not in the garage yet.** It is a patch to
`server/modules/garages.lua`, delivered with the wave 2 report for that module's owner
to land. Until then the five wave 2 rows stay greyed and nothing changes for the other
categories.

| `spec` field | Role |
| --- | --- |
| `owns(to, from)` | Copies the category's fields from `from` into `to`: what a capture keeps of the confirmed look |
| `receipt = { kind, label }` | The ledger kind (VARCHAR 24) and the receipt label prefix |
| `respawns` | Applying it rebuilds the car: it is applied after the stage, and again after a stage purchase |
| `available()` | False when this server build cannot put it on a car: a stored value stays dormant |
| `apply(vehicleId, change)` | Puts a validated change on the car, for a preview or a purchase |
| `restore(vehicleId, state)` | Puts the confirmed value back (rollback, close, retrieval) |
| `unchanged(change, saved)` | True, with a message, when the purchase would change nothing |

What the patch does in the garage:

- `OWNS`, `UNCHANGED` and `RECEIPTS` gain the registered ids. A capture during a
  preview therefore writes the confirmed value, never the preview.
- `applyChange` applies a registered change. Its performance branch puts the
  respawning ones (the engine sound) back after `applyStage`.
- `applyLook` restores them at close and on a rollback: the others before the plate,
  the respawning ones after the stage.
- `applyStage` compares records without the engine sound suffix (`_o77a<k>`), so a
  car whose sound rides its stage record is not rebuilt for nothing.
- At retrieval, `restorable` leaves `record` out of the table when the stored look has
  an engine sound. `setProperties` then composes `<stage record>a<k>` from the sound;
  named beside the plain stage record, the sound would be refused
  (`engine_sound_mismatch` on the natives branch) and the car delivered without its
  visual. The stored record is never sent: an autosave during a sound preview may hold
  the previewed one.
- `restorable` parks the values whose `available()` is false in `row.dormantExtra` and
  logs `garage: <owned id> keeps studio choices this server build cannot put on it dormant`.
  Every capture writes them back until a purchase of that category replaces them.

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
| Lights | `support` (Bandit, Apollo: no tintable lights, E0.1) |
| Performance | No stage price for the model; `lightrp_vehicle_stages` not running (no TweakXL 1.12 loader); no stage record; no native. See [Performance](#performance) |
| Windows | `windows.enabled` set to false by the server ("Coming soon"); the model has no window (`support`: Apollo, Kusanagi); `open77_vehicle_tint` not running, or a pack older than `75b3fcbb2b6e` that the client cannot see; no native |
| Neon › Animation | No native; the garage has no category registry |
| Lamp colors | No native; no registry |
| Engine sound | `listEngineSounds` gives nothing for the car; no native; no registry |
| Stickers | `listStickers` gives nothing for the car; the decal budget cannot be read; no native; no registry |
| Tag | Not listed at all without `setTag`; no registry |

Two tables in `shared/vehicle_customization.lua` are keyed by the Light RP catalogue
key (`hella`, `kusanagi`, …):

- `support = { [catalogKey] = { category = false } }` greys a category for a model
  (the Bandit's and the Apollo's lights, the two bikes' windows). A model or category absent from the table is
  allowed. The server refuses any request for a greyed category.
- `trims = { [catalogKey] = { { id, label }, ... } }`: no entry hides the Trim row.

**No category registry.** While `server/modules/garages.lua` has no
`Garage.registerCustomizationCategory`, the server logs at start
`auto studio: this garage has no category registry; neon animation, lamp colors, engine sound, stickers and tag are greyed`.
With the natives present, the five rows are then greyed "This studio cannot store it
on your vehicle yet."

**Client greying.** On open, each client also greys what **its own game** cannot show:

- rims, body kit and windows when the pack resource is not running for it
  ("Your game has not loaded this workshop's parts. Reconnect…");
- livery when `customizationAvailable` reports no TwinTone;
- performance stages whose record its game does not know.

**Client warnings.** After a rims, body-kit, window tint or livery answer, the client reads
`customizationAvailable(vehicleId).skipped`. It waits 1.5 s, then polls until 6 s,
once `appliedRev ≥ rev`. A skipped `attach:rims.*`, `attach:op77_lightrp:*`, `tint:*` or
`profile:*` entry shows a warning in the editor (a `tint:*:pending_mesh` entry is the
client still waiting for the glass meshes: it is polled again):

| Skip reason | Warning |
| --- | --- |
| `model_not_registered` | "These parts are invisible in your game: its parts pack is missing…" |
| `slot_absent` | "This part has no mount point on this vehicle in your game." |
| `not_covered` (window tint) | "Your game shows no tint on this vehicle: its window tint pack is missing…" |
| `not_for_model` (livery) | "This livery cannot be shown in your game: its livery pack is missing or out of date…" |
| anything else | "Part of this look could not be shown in your game." |

The server stays authoritative throughout: client checks only grey and warn.

**Validation.** Every mutation validates the source player, the active character, life
state, bucket, garage proximity, ownership, a stationary and empty vehicle, and the
session token. Each session accepts ordered requests and replays only the previous
response. These are refused:

- client-supplied native or record names;
- unknown categories, categories not offered, and greyed categories;
- ids outside this vehicle's offer (trim, livery profile, rim and finish, body part
  and finish, neon step, stage, animation mode and speed, lamp group, engine sound,
  sticker, tag font and spot).

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
- **Body parts.** `{ kind = "part", slot = "Base", carrier?, label, variants, fit = {
  [record] = { offset, rotation?, scale?, hide?, carrier? } } }`. The offsets stay
  measured from `Base`; `carrier` only moves the part with its panel. Wings (except
  `wing_roof`) and rear louvers carry `carriers.trunk`, hood parts `carriers.hood`:
  the `carriers` table at the top of the generated file, set from `CARRIER_SLOTS` in
  the generator (`trunk_a`, `hood_a`). Which slot really follows a lid is not measured
  in game yet: if `trunk_a` stays put, swap it there for `doorTrunk` in one line. A fit
  says `carrier = false` where `evidence.lid` finds no lid under the part. A server
  that predates carriers refuses the key (`invalid_part:<id>.carrier`); the module logs
  it once and registers the kit without any carrier, every part on `Base` as before.
- **Trims.** A curated trim is another appearance whose stock rims have other component
  names and often another depth. `server/config/vehicle_kit_trims.lua` (E1b, E1c)
  holds them; a rim's record fit carries them as `fit.appearances`, which the platform
  resolves from the car's current appearance. A body part merges its trims' extra hide
  names into the record fit.

**Budgets, checked by the tests.** The fullest kit on one car is 232 JSON values and at
most 3,812 bytes of `open77.visual` (caps 256 and 4,096, on the Thrax; a carried part
costs one value more). The largest
`registerParts` call is 1,558 values (marshaller cap 4,096). The largest studio
category sent to a client is 405 values (client event cap 1,024).

**Why categories travel as JSON text.** The page message carries `categoriesJson`,
one JSON text per category, and the client decodes it. A Lua table nested 10 levels
deep broke the client's event depth cap of 8 and was dropped with only
`dropped malformed network event payload` (fixed `1160bbe6`). The whole tree as one
text then broke `json.decode`'s former 1,024-value cap (fixed `816ebe10`; base
`4b70192b` has since raised that cap to 65,536). The module still logs any category
above `JSON_VALUES = 1000`, the old cap, which a client built before `4b70192b` still
enforces.

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

**Installing the packs.** The models ship in pack resources that are **not
committed** here: `lightrp_vk_rims`, `lightrp_vk_body` and `lightrp_vehicle_stages`.
`resources/assets/models/lightrp_vehicle_kit/README.md` gives the lead's install
steps: where to copy them, `.gitignore`, `server.jsonc` load and `ensure` entries,
and the TweakXL ≥ 1.12.0 requirement. The livery pack (`lightrp_vk_liveries`), the
plate pack (`open77_vehicle_plates`) and the tint pack (`open77_vehicle_tint`) are
built in the Open77 repository under `scripts/vehicle-kit` and installed the same way.
Every pack is a `preload_mod`: a new revision needs a server restart, and players
must relaunch through the launcher. A client whose game mounted an older archive sees
the car stock (`model_not_registered` in its `skipped` list).

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

All mutation APIs below are **server-side**. By design, runtime visual replication
covers current viewers, late joins and streaming back in; all three were seen on two
clients on 2026-11-07 (see [Status in game](#status-in-game)).

| Category | Native APIs | Notes | Status |
| --- | --- | --- | --- |
| Body paint | `setPaint`, `resetPaint`, `getPaint` | Primary/secondary RGB, separate applied flag; clears a livery | Implemented |
| Livery | `listPaintProfiles`, `setPaintProfile`, `getVisual` (pack: `registerPaintProfiles`) | TwinTone profiles of the record, factory and pack; `invalid_profile` refused; at most 12 decals per template | Implemented (phase 2) |
| Rims | `registerParts`, `listParts`, `setWheels`, `getVisual` | One rim set; B2 per-wheel fits; key `rims.<slot>` | Implemented (phase 2) |
| Body kit | `registerParts`, `listParts`, `setParts`, `getVisual` | Slot `Base`, `carrier` for lid parts; ≤ 16 attachments; exclusivity in Light RP | Implemented (phase 2); carriers not seen in game |
| Neon | `setNeon`, `clearNeon`, `getVisual` | Colour, intensity 0–5000, radius | Implemented (phase 2) |
| Light tint | `setHeadlightColor`, `clearLightsHue`, `setLightsHue`, `getLightsHue` | One hue in 0..1, shown on the headlights by the client since `1ee95687` | Implemented |
| Trim | `getAppearance`, `setAppearance` | Curated names, `world.vehicles.appearance` | Implemented |
| Performance | `respawnAs` (+ the stage resource's `stageRecord` export) | Same id; refuses `vehicle_occupied` / `invalid_record`; the stage resource needs TweakXL ≥ 1.12.0 | Implemented (phase 2) |
| Plate text | `setPlate` | Normalized text on the plate pack's screen; state bag `lightrpPlate` for menus; blank on a car born more than ~10 m from the camera until the 9 m rebuild | Implemented |
| Window tint | `setWindowTint`, `getWindowTint`, `getVisual().tint` | Levels 1-3 on side and rear glass; nil = factory. The tinted glass renders with the Open77 client fixes `b9f21aa3` and `15013360` and the pack `75b3fcbb2b6e` (base `docs/research/vehicles-api.md`, "W1 résolu") | Implemented, sold since `ba146785` |
| Neon animation | `setNeonAnimation`, `getNeonAnimation` | Mode, `periodMs` 250-10000, `color2` for a chase | Implemented (wave 2); seen on two clients on 2026-11-07, with the Open77 client fix `a0999cf9` |
| Lamp colors | `setLightColors`, `getLightColors` | Groups `brake`, `reverse`, `blinkers`, `interior`; nil = factory | Implemented (wave 2); seen on two clients on 2026-11-07 |
| Engine sound | `listEngineSounds`, `setEngineSound`, `getEngineSound`; `setEngineHold` (op77.147) | Rebuilds the car on `_o77a<k>` / `_o77s<n>a<k>` | Implemented (wave 2); seen on two clients on 2026-11-07 |
| Stickers | `listStickers`, `setStickers`, `getStickers`, `getDecalBudget` | 12 decals at most on a car, livery included | Implemented (wave 2); seen on two clients on 2026-11-07, with the Open77 client fix `843f8cc4` |
| Tag | `setTag` (no getter: `getProperties().tag`) | Stretch goal W2.5 | Wave 2 contract; not in any build checked |
| Durable restoration | `getProperties`, `setProperties` | Version-1 visual is complete: unknown keys are refused | Through the garage |
| Client checks | `customizationAvailable` (client, `vehicles.read`), `Open77.data.vehicle` | Greying and skip warnings only | Feature-detected |

The manifest declares `world.vehicles` and `world.vehicles.appearance` (a change needs
both), `vehicles.read` and `camera.script`. The client only relays page requests and
reads its own game; every vehicle write is server-side.

## Adding a category

1. Register its ID, label and description in `shared/vehicle_customization.lua`, and
   its price in `server/config/vehicle_customization.lua`. The module refuses to load
   without a valid price for every sold category. `parent` makes it a tab of another
   category's editor; `capability` hides the row entirely on a server without that
   native.
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

   Once the [category registry](#the-garages-category-registry) has landed, a category
   whose value is one `getProperties` field can skip this step: declare it with
   `Garage.registerCustomizationCategory`, as the wave 2 categories do (`EXTRA` in
   `server/modules/vehicle_customization.lua`).
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
  - **`tests/vehicle_customization_wave2_test.lua`:** the five wave 2 categories
    against a mock of the contract natives.
    - On any garage: greying without the natives, and without the registry.
    - With the registry: neon animation (emergency looks, the neon it runs on); lamp
      colors (refused groups, a DB failure rolls back); engine sound (the rebuild
      cooldown, the engine hold, the stop at close, a stage keeps the sound); stickers
      (per-sticker price, the decal budget with a livery, the two purchase guards);
      the tag; park + restart + retrieve; a build without the natives keeps the values
      dormant and gives them back later; 60 stickers still fit the event caps.
    - Against a garage without the registry it checks the greying, then prints a
      `SKIP` line. Set `LIGHTRP_GARAGES=<path to a patched garages.lua>` to run the
      whole flow. The runner runs it with the keys at the top level and, when that
      run is complete, again with them in `visual` (`LIGHTRP_WAVE2_KEYS`).
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
  - **Wave 2:** thirteen top-level categories, the Neon and Lights tabs; animation
    modes, speed and second color; lamp colors without the emergency looks; the engine
    sound heard on request only; stickers within the budget the server reports (a
    livery preview fills it, nothing is previewed above it); the tag (spaces folded, a
    character outside the set never sent); the three layouts again.

  Screenshots go to the ignored `ui/artifacts/vehicle-customization-*.png`.
- Run `pwsh -File scripts/check-lua.ps1 -Path <file>` from the Open77 repository on
  each changed Lua file. Lua files carry no BOM.

## Lab checklist (two clients)

**Setup.** The lead installs the packs (README above) with TweakXL ≥ 1.12.0, and the
server log shows `auto studio: 48 kit parts registered` (18 rims + 30 body parts).
Client **A** owns an Archer Hella, which has every category: 5 trims, 25 of the 30
body parts (7 groups) and split-axle rims. A
Thorton Merrimac and a Brennan Apollo are also owned, by A or B. Client **B** stands
within 20 m of Bay 01. Both clients connected after the packs were added.

| # | Steps | Expected |
| --- | --- | --- |
| 1 | A parks the Hella at Bay 01, steps out, presses E | 10 categories in a 2-column grid, Windows included (greyed only on the two bikes, or without the tint pack); the camera frames per category (rims low and close, plate from behind) |
| 2 | A previews Deep Dish 8 black, then Factory rims | B sees the rims on all four wheels, the back pair flush with its tyres (its offset differs from the front), no stock rim showing through; Factory rims gives the stock wheels back on both clients |
| 3 | A buys a rim set; parks; the server restarts; A retrieves | Wallet −6,000, ledger `vehicle_rims`; same rims on A and B, also after B streams the car out and back in (> 35 m) |
| 4 | Same with the Merrimac, then the Apollo | Merrimac: six wheels including the middle axle; Apollo: front and back rims on the bike slots. Kusanagi: Rims greyed "No rim fits this model yet." |
| 5 | Body kit on the Hella: GT wing, then Street wing, then a lip | One wing at a time on both clients; the price reads 7,000 for wing + lip; buy; ledger `vehicle_bodykit` |
| 6 | Neon: Cyan Medium, then a custom `#101010`, then Red High; buy; then No neon and close | B sees cyan, then red under the car; `#101010` is flagged and never shown; closing after No neon puts the bought red back |
| 7 | Livery: Scheme 1 if the Hella lists one (otherwise test on a model that does), then a pack livery (`lightrp_vk_liveries` running) by its label | Two-tone, then the pack livery, on B; the paint editor shows Factory finish; buy; park, restart, retrieve: the livery comes back; then buy a body paint: the livery goes away on both clients |
| 8 | Plate: type `ab 12` (refused locally), `NCPD001` (reserved), `SH1T123` (not allowed), a free one; register it | Server messages as listed; "This plate is available." then purchase; the header, garage list and ALT info show it; B reads the text on the Hella's plate once within 9 m of it; B tries the same plate on his car: "already registered" |
| 9 | Performance: B gets into the Hella while A has the studio open; then A reopens it with the car empty and fits Stage 1 | B entering closes A's session (occupied car); then the car is rebuilt in place with the same keys and look on both clients; the header reads STAGE 1; driving shows the stage's top speed (E5 table); a second change within 10 min is refused with the minutes left |
| 10 | Park, restart the server, retrieve; stop `lightrp_vehicle_stages`, retrieve again | Stage 1 comes back. With the stages resource stopped, the car spawns stock and the stage stays stored; Performance greyed "…not installed on this server yet." |
| 11 | A client without the rims pack: B stays connected while the lead first starts `lightrp_vk_rims` (no reconnect), or B's download of it failed | B's studio greys Rims "Your game has not loaded this workshop's parts…"; note what B sees on A's car (stock wheels, or bare hubs if the hide applies without the part); if B's pack resource runs but its models are missing, B's own rim preview shows "…parts pack is missing…" |
| 12 | During any preview, A presses Escape / dies / drives off | The confirmed look of every category comes back on both clients; no ledger entry |
| 13 | Read the server and client logs | No `part … not registered`, no `customization rollback pending`; client `red4ext/logs/open77-*.log` has no `attach:` skip for the Hella; `TweakXL-*.log` reads `LightRP\open77-lightrp-stages.yaml` |

**Wave 2 (rows 14-22).** These need a server build with the wave 2 natives,
`server/modules/garages.lua` with the [category registry](#the-garages-category-registry),
and the sticker and engine sound packs installed. The server log must not show
`this garage has no category registry`.

| # | Steps | Expected |
| --- | --- | --- |
| 14 | A opens the studio on the Hella | 13 rows (12 without `setTag`); Neon and Lights show the tabs Animation and Lamp colors; no wave 2 row greyed |
| 15 | With a cyan neon bought: Animation Pulse Medium, then Chase with Amber; then a red neon preview with Strobe; buy Pulse | B sees the pulse, then the chase; the red strobe is refused "A red or blue strobe reads as an emergency light…"; ledger `vehicle_neon_anim`, 2,500 €$ |
| 16 | Lamp colors: the red Blinkers and blue Brake lights swatches; Reverse cyan, Interior purple; buy; A drives off and reverses near B | Both swatches disabled; ledger `vehicle_lamps`, 1,500 €$; B sees the cyan reverse lights and factory brake lights |
| 17 | Engine sound: pick one, **Hear it on the car**; again within 4 s; buy; close; later fit a stage | The car vanishes briefly and comes back running, with the new note for A and B; the second try reads "The car is still being rebuilt…"; ledger `vehicle_engine_sound`, 6,000 €$; closing stops the engine; after the stage the sound is still there |
| 18 | Stickers: add two; then preview a livery with many decals; add a 3-decal sticker; buy two | The meter follows; over 12 the page refuses "Too many decals: … Remove a sticker."; 3,000 €$ for two, ledger `vehicle_stickers`; B sees them; no client crashes |
| 19 | Tag (if listed): `Night Owl`, Marker, Left door; then a reserved word such as `NCPD` | Painted on the left door for B; the reserved word is refused |
| 20 | Park, restart, retrieve; then run a server build without the wave 2 natives and retrieve; then back | Every wave 2 choice comes back; on the older build the car comes out without them, the rows are greyed and the log reads `garage: … keeps studio choices this server build cannot put on it dormant`; back on the full build they return |
| 21 | During any wave 2 preview: wait for an autosave, then Escape | The SQL row (`lightrp_owned_vehicles.properties`) holds the confirmed values, never the preview; Escape gives the confirmed look back on both clients, no ledger entry |
| 22 | With `lightrp_vehicle_original_stickers` installed (both clients relaunched after it, since TweakXL makes its records at game start): on the Thrax, add the Race set, then the Pinstripe set | One section per theme; Race (9) shows on A and B; adding Pinstripe (9) is refused "Too many decals: 18 of 12…" and by the server (`decal_budget_exceeded`); no client crashes. Then park, restart, retrieve: the Race set comes back on both clients |

Fill `support`, the rim and body fits, and the stage values from these
measurements: which records render rims and parts where expected, and which stages
drive as tabled.

### Wave 1 lab results

These were measured on 2026-11-07 in the lab server, with two clients (A owns and
buys, B watches from the bay) and a new Hella delivered at Bay 01.

| # | Result |
| --- | --- |
| 2 | Deep Dish 8 black on the four wheels for B, nothing of the factory rim showing; Factory rims gives the stock wheels back on A and B |
| 3 | Deep Dish 8 black bought by A ("Rims purchased and saved to your vehicle."), seen by B on the four wheels. After a server restart, the late join of both clients, an impound and a redelivery, the four rims are bound and rendered on A and B, with the kit, neon, plate and windows. B then went 450 m away and came back: the four rims, the kit and the plate were back after about 24 s |
| 4 | Seen by B: a rim set on the Merrimac sits on its six wheels, the middle axle included; on the Apollo it sits on the front and back wheels. The Kusanagi was not run |
| 5 | GT wing, then Street wing alone (one wing at a time for B), then the race lip; wing + lip read 7,000 and were bought (`vehicle_bodykit`) |
| 6 | Cyan Medium shows under the car for B; `#101010` is refused; Red High bought for 5,000 (`vehicle_neon`); No neon then Escape gives the bought red back on A and B |
| 7 | Scheme 1, then the taxi livery of the pack, seen by B; the taxi livery was bought; it came back after a server restart, an impound and a redelivery; buying a body paint removes it on both clients |
| 8 | `NCPD001`, a banned word and a too-short plate are refused with their messages; `VCB0707` was bought; B reads it on the plate within 9 m; the same plate on another car is refused "already registered" |
| 9 | B getting into the Hella closes A's studio. With the car empty, Stage 1 rebuilds it in place with its whole look on A and B; a second change is refused "Come back in 10 min" |
| 10 | With `lightrp_vehicle_stages` left out of the server and a restart, the Hella with Stage 1 is delivered stock; the stage stays stored, Performance and Engine sound are greyed, and the header shows no stage. Before the fix of 2026-11-07 (`fittedStage` in `server/modules/vehicle_customization.lua`) the header still read STAGE 1. With the stages back and a restart, the car comes back on its stage 1 record |
| 11 | B's game without `LightRPVehicleKitRims.archive`, the rims pack resource running: B's Rims row stays open, and B's own rim preview shows "These parts are invisible in your game: its parts pack is missing. Reconnect to download it." A's Hella, which wears bought rims, first stood on bare hubs for B: the factory rims were hidden and the new ones could not be drawn. Since the Open77 client fix `b2920336`, B sees the factory rims until it can draw the parts, and A still sees the four bought rims. The greyed case (the pack resource not running on B) was not run on two clients |
| 12 | Driving off during a preview gives the bought look back on both clients, with no ledger entry |
| 13 | No `not registered` part, no `rollback pending`, no `attach:` skip for the Hella in the server and client logs |
| Restart | After a server restart and the late join of both clients, the Hella comes back with stage 1, paint, kit, neon, plate and windows, on A and B |
| Stream-in | B goes 450 m away and back: kit, neon, windows and paint come back; the plate is written again once B is within 9 m |
| Driver change | B drives the car, then A does: the look stays the same on both clients |
| P3.11 | A launcher started from an install without the vehicle packs: see below |

Rows 4, 10 and 11 and the older-build part of row 20 were run on 2026-11-07 between 08:10
and 08:45, on new Hellas, a Merrimac and an Apollo given to A and B. Row 10 is also covered by
`tests/vehicle_customization_kit_test.lua`.

**Launcher (P3.11).** The 14 files of the vehicle packs (body kit, rims, liveries,
stickers, original stickers, stages and engine sounds, plates, window tint) were taken
out of the game folder. A launcher 2.50.0+op77.201, on its "Local development" source
with a master on 127.0.0.1:8090, was given `open77://connect?endpoint=127.0.0.1:11855`.
It listed the 25 required packages (52.4 MB, none reviewed), asked for consent,
downloaded them from the server and wrote
`world '127.0.0.1:11855': projected 14 file(s), removed 0, kept 60 in place.` The 14
files were byte-identical to the ones taken out. It then started the game, which joined
the world in 18 s; ArchiveXL loaded the plate and tint `.xl` files and TweakXL read the
five Light RP YAML files. The launcher signs in with the player's real account, which
was new on this server, so that client stopped at the Light RP character creator. The
look of the Hella was then checked with the two lab clients on these same projected
files: B saw the two-tone paint, the wing, the red neon, the tinted windows and the plate; A then bought
the rims of row 3 on these files.

### Wave 2 lab results

These were measured on 2026-11-07 in the lab server, with two clients (A drives, B
watches) and the Hella.

| # | Result |
| --- | --- |
| 12 | Escape during a neon animation preview gives the bought Pulse back on A and B, with no ledger entry and no pause menu |
| 14 | 12 rows: Tag is absent while the server has no `setTag` native. At that run Windows read "Unavailable": the tint pack had no client script, so the client never saw it running. Fixed in pack `75b3fcbb2b6e`; Windows is open since `ba146785` (see [Windows](#windows)) |
| 15 | B sees Pulse and Chase in step with A, on the server clock. The red strobe is refused with the right text. Pulse was bought for 2,500 (`vehicle_neon_anim`). The animated neon went dark until the Open77 client fix `a0999cf9`; after it, Pulse, Chase, Rainbow and Speed are visible on both clients |
| 16 | Red blinkers, blue brake lights and a too-dark brake colour are refused. The purchase cost 1,500 (`vehicle_lamps`). While A reverses, B sees the Hella's two reverse lamps in cyan, next to the bought orange brake lamps |
| 17 | The preview rebuild keeps the look on both clients, and the 4 s message is right. Sound s01 was bought for 6,000 (`vehicle_engine_sound`). Closing the studio stops the engine the preview kept running, on A and B, and gives the bought sound back. A stage change from 3 to 2 keeps the sound and the whole look on both clients |
| 18, 22 | 6th Street (5) + Race (7) = 12 decals, shown on A and B. Adding Graffiti is refused "Too many decals: 18 of 12"; a duplicate gets "Each sticker goes on once"; a Caliburn theme on the Hella gets "does not fit this vehicle". One added sticker cost 1,500 (`vehicle_stickers`). No client crashed |
| 20 | After a server restart and a late join of both clients, every wave 2 choice comes back. On the older server build 2.50.0+op77.177, the Hella comes out without the choices that build cannot put on a car; the log reads `garage: <owned id> keeps studio choices this server build cannot put on it dormant`, and the studio greys every row but Body paint, Lights, Trim and Plate. Back on the full build, everything returns within 26 s of the delivery |
| 21 | An autosave during a preview stores the bought values (neon Pulse, sound s01), never the preview. Escape gives the bought look back on both clients, with no ledger entry. Only the `record` field of the stored properties can carry a previewed sound; the garage never reads it back (`restorable` rebuilds the record from the base model and the stage, then puts the bought sound on) |

Other results:

- **Studio limit.** The studio session closed 5 min after opening, even during an edit.
  It now counts idle time; this was fixed on 2026-11-07 and proven in game.
- **Stream-in.** After a stream-in, lamp colors and stickers wait for the paint to
  settle. On a 30 fps client this takes about 2 to 3 s. A client running at a few
  frames per second (a background window) takes about 20 s.
- **Ten studio cycles.** Ten open, paint, five rim sets, close cycles in a row: no
  crash, no marker burst, 61 accepted requests.
- **Stickers far from the camera.** A client that moved about 160 m away from the
  Hella with 12 stickers crashed twice. The Open77 client now changes a car's decals
  only within 40 m of the camera; with that fix, six round trips of 160 m to 1 km
  crashed nothing and the stickers came back each time. An approaching car shows its
  stickers from about 40 m on.

## Open questions for the owner

- **Prices.** The livery (4,000), rims (6,000 per set) and body kit (3,500 per group)
  prices are provisional, and so are neon (5,000), plate (2,500), lights (500) and
  trim (2,500). The stage prices are E5's proposal: 10/15/20 % of the dealer price,
  weighted by the engine actually delivered. The 1,000 €$ removal fee and the 10 min
  cooldown are also provisional. See `docs/economy-balance.md` §18.
- **Plate format.** Seven characters A-Z/0-9 is a placeholder; a pattern such as
  `NC` + 5 or 3 letters + 4 digits, or a vanity length, is the owner's call. The
  banned and reserved lists also need the owner's extension.
- **Windows.** Sold at 1,500 €$ since 2026-11-07, for any level or for going back to
  factory glass. The price and the three labels (Light smoke, Dark smoke, Limo) are the
  owner's to confirm.
- **Labels.** The factory livery schemes are "Scheme N" because factory profiles have
  no name; pack liveries carry their pack's labels. The rim names come from E1
  (Classic 10, Lattice, Deep Dish 8, …); the body groups are Wing, Rear louvers,
  Front lip, Canards, Side skirts, Rear diffuser, Hood, Roof and Front protection; the
  13 finishes are Chrome, Black chrome, Black, Matte black, White, Red, Yellow, Gold,
  Bronze, Gunmetal, Carbon, Aluminium and Steel. All are the owner's to rename.
- **Wave 2 prices.** Neon animation 2,500, lamp colors 1,500 for any number of
  groups, engine sound 6,000, stickers 1,500 per sticker added, tag 2,000: all
  provisional (`docs/economy-balance.md` §18).
- **Wave 2 rules and labels.** The animation names and speeds (2.4 / 1.2 / 0.6 s),
  the 3 Hz strobe cap, the emergency hue ranges (red 340-20°, blue 195-255°, from
  saturation 0.35), the brake and blinker floor (HSV value 0.35), the free engine
  sound preview (once per 4 s, engine kept running), and the tag (12 characters, its
  character set, fonts, spots and colors) are all placeholders.
