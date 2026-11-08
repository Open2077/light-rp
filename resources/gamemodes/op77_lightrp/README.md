# op77_lightrp

The Light Roleplay framework of **Open//77 Official Roleplay**, in a single package: server,
client and a global React + TypeScript WebUI dressed in the Open//77 RP design system
(yellow on black, chamfers, monospace readouts, mechanical motion).

```
op77_lightrp/
├── open77.lua                 manifest: scripts, dependencies, permissions, WebUI page
├── shared/
│   ├── events.lua             every event name (mirror of ui/src/bridge/protocol.ts)
│   └── config.lua             spawn, places, chat, needs, voice, vehicles, keys (downloaded by clients)
├── server/
│   ├── core/framework.lua     LightRP: modules, actions, commands, page state, notices
│   ├── core/persistence.lua   LightRP.db: the MySQL bridge, schemas, running without a database
│   ├── modules/characters.lua characters (name, position, play time), /register
│   ├── modules/needs.lua      hunger / thirst
│   ├── modules/chat.lua       RP speech by distance, /me /do /try /roll /w /s /ooc /pm /who /rules /help
│   ├── modules/vehicles.lua   one civilian vehicle per player, /car /cars /dv
│   ├── modules/staff.lua      ACL, /lightrp.*, /report, the page's staff actions
│   ├── modules/ui.lua         the `server` state key, periodic broadcast
│   └── main.lua               arrival (last position) and waking up at the hospital
├── client/
│   ├── core/ui.lua            the WebUI surface, the bridge, focus, network relays
│   ├── core/hud.lua           samples vitals / vehicle / voice / clock → page
│   └── main.lua               creation, F5 key (rebindable)
└── web/                       the built page (do not edit: `npm run build` in ../../../ui)
```

## RP staff desk and reports

`/admin` (or `/lightrp.admin`) opens **the** server admin menu, compact in the RageUI
style and in the LIGHT/RP look. It brings together the platform tools (`open77_admin`:
noclip, vehicles, weather, mass actions…) and the LightRP ones (missions, world
bosses, gigs, items, content): reports, players, personal tools, teleport,
vehicles, items and weapons, world, missions and events, places and content,
server, history. Each entry only shows up if the ACL allows it. You can still
move freely while browsing the menu.
`/report`, `/reports` or **F1 → Reports & support** give players
a private, persistent ticket, with an assigned admin, replies, statuses,
notifications and the option to reopen it. Internal notes stay
staff-only. `/adminfull` keeps the official technical console.

[Flow, permissions, storage, limits and tests](docs/admin-support.md).

**Mission editor** (`/lightrp.missions`, ACL `command.lightrp.missions`): create Elimination or Survival (waves) missions in game,
with a perimeter (warning, then death outside the zone), enemy spawn points, trigger checkpoints, waves, difficulties and instant testing.
Missions saved before the balancing pass move to the new pay scale with `/lightrp.missions.repay` (preview) then
`/lightrp.missions.repay apply` (staff). See [docs/mission-editor.md](docs/mission-editor.md).

**Map editor** (`/lightrp.maps`, ACL `command.lightrp.maps`): create in game the maps for the `op77_games` games, with the mission editor's
build mode: pick a game, see its maps, create, duplicate, rename, enable or disable, delete, open. What a map
requires comes from the `schema` each game declares next to its rules; the core stores (`lightrp_game_maps`) and validates. An incomplete draft
can be saved but is never enabled, and a game offers only 8 maps: the ninth is refused. No restart needed: lobbies follow along, and a match
in progress keeps its map. See [docs/map-editor.md](docs/map-editor.md).

## Character creation and arrival scene

### Placing the scene

Staff command: `/lightrp.scene` (ACL `command.lightrp.scene`). It hides
the creation wizard, frees the controls and reserves a private bucket at noon,
in sunny weather. Nothing moves you automatically: walk to the chosen spot.

- `/lightrp.scene sit`: sitting pose at the current position and facing.
- `/lightrp.scene walk`: stand up to change spots; F7 switches the perspective.
- `/lightrp.scene move 0 0 0.05`: raise the anchor by 5 cm (world axes X/Y/Z,
  values between -1 and 1 m). The pose is replayed after each adjustment.
- `/lightrp.scene turn 15`: add 15 degrees to the heading.
- `/lightrp.scene preview 3.6 -1.5 0.4 1.2 48`: camera preview in front of the
  character (distance, side offset, camera height, aim height, FOV).
  Hides the HUD and plays the music at low volume; `walk` restores the view.
- `/lightrp.scene save`: save the pose anchor and its heading to
  the KVP `creator.placement.draft`, with a readable copy in the server log.
- `/lightrp.scene stop`: finish tuning and restore the previous bucket.

What you save is only a draft: copy the approved values into
`characters.arrivalScene.position/heading` in `shared/config.lua`. `autoStart`
starts the scene at the end of the native body selection. The approved bench is the one
already in the set: `bench = false` avoids spawning a second bench in the same spot.

The flow offers identity, an optional origin/backstory, an appearance
review, then confirmation. Each step has a shot in `shots`, in
coordinates relative to the character (X right, Y forward, Z height). Shots
blend smoothly into each other; the **Still camera** button and the system
reduced-motion preference remove camera movement. **Cloudy Day** plays locally
at `musicVolume = 0.12`, with a mute button.

The scene has its own isolated bucket, sunny at noon, released when you leave. The arrival
loads the district through the respawn transaction before sitting the character down;
`approachOffset` puts the feet on the sidewalk, outside the bench collider.
The screen stays covered until the native pose is shown. A loading or
camera failure gives a retry button. The native editor
then hands control back to the scene; confirming the character releases the camera, music,
HUD and freeze before the player spawns. Appearance changes
are still handled and saved by `open77_appearance`.

The manifest must keep `player.appearance.read`: the scene waits for the
editor to really close, including after a cancel, before taking back
the camera and focus. Saved drafts resume at the right step
after reconnecting; a confirmed character goes straight into the city.

## First day: tutorial in the arrival hall

After the character is confirmed, **Your first day** plays in the arrival
hall: the white city of the `lobby` map resource, outside Night
City, in its own routing bucket (620000). The `open77_lobby_cubes` package
keeps it at night with a clear sky. A tracking shot travels up the avenue, then Mara, the
guide, waits in the square. Dialogue is text only; the music stays
local and quiet.

The flow teaches the real mechanics, in this order. The new voice and Alt
chapters are described in the [integration guide](docs/first-day-interactions-voice.md).

1. Walk to Mara and talk to her: life in the city and the RP rules.
2. Install the **Neural-Link** (F2, the Kiroshi sequence from `op77_neuralink`): required;
   the step waits for the implant and puts the phone away at the end.
3. Set up voice: devices, keyboard/mouse push-to-talk or voice activation,
   then a local test. "Already set up" and "Skip" stay available.
4. **Get dressed**: the newcomer arrives in underwear. The fitting room at the
   back of the hall shop (`wardrobes.spots.lobby_fitting`) opens the wardrobe;
   the step waits for a saved outfit with a top and a bottom
   (`open77:presentation:committed`, `Wardrobe.dressed`), and completes on its own if the
   character is already dressed. Like any wardrobe in a shared place (city or
   hall), the fitting room is **private**: the player changes in their own bucket
   (`wardrobes.privateBucketBase` + their id, same time and same weather) and comes back when it
   closes; in a home, which is already private, nothing moves.
5. Open the player menu and check **Identity** (identity, bank account).
6. Open the inventory.
7. Go to the hall shop and **buy** a drink: a real cart, a
   real payment (`onShopCheckout`, emitted by `server/modules/shops.lua`).
8. Drink: the step waits for the action to really finish, validated on the server.
9. Talk to the banker (account, cash, transfers, `/pay`) then to the mechanic.
10. Practice **Alt + left click**: inspect a crate, unlock your training
   car, open then close the trunk with the real context menu.
11. Talk to the gas station attendant (fuel, jerrycan).
12. Training activity at the job fair: **collect** a crate,
   **process** it at the workbench, **sell** the parts to Juno. This is the
   free activities module (`job_work`) with a `tutorial` job: real items,
   real payment into the bank, one batch per press. Each site only opens
   for the guide step that asks for it (`Tutorial.allowsWork`): it is not
   an income. No job is chosen in the hall.
13. Go back to Mara: she opens the door, the character gets their starter
   studio in Kabuki (its door is on the map) and arrives at the
   `spawn.afterTutorial` point (`shared/config.lua`), a Westbrook plaza about
   115 m from that door, in the city bucket. Mara wraps up with a
   message. Without `spawn.afterTutorial`, they wake up directly in the studio.

**Skipping the first day.** As soon as you arrive, the opening screen offers **Skip
the tutorial**. After that, the objective card always shows **Press F1 to
skip the tutorial**: while the guide is running, the player menu (F1) has a
**Skip the tutorial** entry, right under **First day guide** (which offers it too), and
`/tutorial skip` does the same. A confirmation always comes before the skip. The server installs
the Neural-Link if it is missing (event `op77_neuralink:requestInstall`; the implant
is still required in the city), marks the guide as finished, then does exactly what
the normal ending does (step 13): starter studio given, arrival at the
`spawn.afterTutorial` point. Skipping the hall changing room can leave the character in
the creator's clothes: the wardrobe in the studio, a few steps away, dresses them. A player
already in the city stays where they are. Only the training pay is not earned;
the starting money and bag come from character creation.

**F1 → First day guide** lets you pause, resume or revisit the
flow. `/tutorial` resumes at the last objective, `/tutorial pause` lets you
play freely, `/tutorial skip` skips the first day and `/tutorial restart`
replays the whole first day, opening scene included, for an existing character. The keys shown follow the rebound shortcuts.

Presentation (`LightRpTutorialConfig.reveal`, `ui/src/features/tutorial/`):

- **Show the way**: at each new destination more than 12 m away, after
  the "Step complete" banner, the camera rises behind the player, flies over
  the route (gold chevrons drawn on the ground, `debugDraw`, light up as it passes), lands on
  the place, then fades back (~5.6 s). The player is frozen during the flight and
  released as soon as it returns. Cinema bars, place name, direction, distance and hall
  map on screen. `SPACE` skips (`lightrp.tutorial.skip`), `G` replays the flight
  at any time (`lightrp.tutorial.way`): two RegisterKeyMapping. Never on
  top of a menu, a dialogue, the free camera or while in a vehicle.
- **Find the objective** (`client/core/tutorial_guide.lua`, `GuidePointer.tsx`):
  a gold ring on the ground and a column of light above the objective (two
  markers `ring` + `cylinder`, created once per objective, never updated);
  on screen, a marker pinned to the objective (page anchor `tutorial.guide`) with
  its name and distance, or, when it is off screen, an arrow on a ring around the center
  of the screen; the same direction in the objective card. Everything clears at once on
  conversation, step change, death, loading, pause, the end,
  character change and resource stop; a failed marker is
  recreated (3 tries); the flight path expires on its own in 1 s if it is no longer redrawn.
  Before (2026-11-06, "the balls stay"): an arrow and 5 spheres moved by
  `markers.update` every frame (an update during loading restarts the spawn),
  radii below the 0.1 m minimum refused one time out of two, and gaps in the
  id list that left spheres in the world.
- **Interface examples**: a line can be `{ text, demo }`; the demo
  plays above the dialogue (vehicle gauge with the needle dropping into
  reserve, pump steps, key and beeps, rental, ID card, cash
  and bank, transfer, vehicle menu, hall map, collect/process/sell).
  A step can have `demo`: a mini animation in the objective card
  (F1 key then Identity, inventory, cart, drinking, activities). These are
  images of the real screens: they send no action.
- Lines type out on screen; `SPACE`/`Enter` shows the whole
  line, then moves to the next one.

Who is where: the guide decides where you wake up while a hall step is in
progress (`Tutorial.spawnPoint` / `deathPoint`, read by `server/main.lua`): on
connection and after a death, the character comes back to the hall door. Pausing the
guide in the hall takes you back to the city (nobody gets locked in there);
resuming a hall step takes you back there; revisiting a finished guide starts again from the hall
without the opening scene. A character saved in the hall with no hall
step in progress wakes up in the city. Citizens created earlier are not forced to
do the tutorial.

The `lightrp_tutorial` table stores the checkpoint per account and character, with
a revision to refuse stale answers and duplicates. Progress
comes from the hooks `onInventoryOpened`, `onShopCheckout`, `onItemUsed` and
`onJobWorkCompleted`; messages from the
browser can create neither jobs, nor items, nor money. Talking to a contact
requires being alive, close to them and in the hall bucket. Pausing,
changing character, death and resource stop release the camera,
sound and controls.

Configuration: `shared/tutorial.lua` holds the hall (`lobby`: origin,
bucket, arrival point, box), the contacts (name, role, position, heading,
NPC records tried in order), the order and text of the steps, the opening
shot and the volume. Positions are in meters from the center of the
square, as the map generator places them: if the hall moves, only
`origin` changes, along with the two entries that depend on it (`lobby_market` in
`server/config/shops.lua`, the `tutorial` job in
`server/config/job_work.lua`) and the box in `open77_lobby_cubes/zone.lua`. The bucket must
be the same in `shared/tutorial.lua`, those two entries and
`open77_lobby_cubes/server.lua`. `enabled = false` turns the guide off and brings back the
initial briefing. The system reduced-motion preference turns off the
tracking shot.

Dedicated tests: `tests/tutorial_test.lua`, `tests/tutorial_client_test.lua`,
`tests/hospital_respawn_test.lua` (waking up in the hall, placement with a bucket)
and `ui/tests/tutorial.browser.cjs`. Still to check in game: the NPC poses
on their tiles, the camera shots, the full route and the move from the hall
to the city.

## Interaction kit: progress and QTEs

Map points now use the SVGs from the standalone package
`open77_icons`: dedicated icons per activity, yellow accent, groups kept
and specific route objectives. [LightRP catalog and integration](docs/map-blips.md).

The same yellow bar with no background panel is used to eat, drink, smoke, refuel
and work. Any new timed action goes through `LightRpActions.progress`
or the `ActionProgress` export. The kit also keeps the ring, key hold
and QTEs through `ActionHold`, `ActionSkillCheck`, `ActionCancel`, `ActionIsActive`
and `ActionResult`. [Contracts, Lua examples, options and tests](docs/action-ui.md).

Browser preview: `http://127.0.0.1:5177/?registered=1&actions=1` (Vite).
In game, staff: `/lightrp.uitest progress|circle|hold|timing|sequence|cancel`.
The demos give no reward; future jobs must validate their actions on the server.

## Job Center and free activities

Three public jobs: **Sanitation**, **Scrapper**, **Courier** (delivery, which replaced AC Cleaner). The office uses three
illustrated tilted panels that grow on hover or keyboard focus.
**Sanitation/Scrapper**: harvest → process → sell, with no clock-in
and no required job. E starts the loop at the point; Esc stops it. Items
have a weight and go through the real inventory and storage. The office offers
GPS to the three steps and optional hiring. `/work sanitation|scrapper
[collect|process|sell]`, `/work stop`.

The points, recipes, durations and prices of the free activities are in
`server/config/job_work.lua`. **Courier** runs on work orders
(`/job start|status|gps|cancel`, or "Start a run" at the office): each time you take a
run, the server draws 2 to 3 orders, one pickup point per order, then
one drop-off point per order; each order really goes into the bag
(`delivery_order`, 1 kg) and the pay, paid into the bank at the last delivery, follows the
length of the route. Points (test ones for now), number of orders, durations and
pay scale: `server/config/delivery.lua`. AC Cleaner is no longer offered at the office; players who
already have it keep their route (`server/config/job_runs.lua`). Target income: 3,000 to
5,000 €$/h at grade 0; each job grade adds 10% to sales and runs
(`server/config/economy.lua` → `jobs.gradeBonus`), and the grade pay (every 30 min,
`shared/jobs.lua`) stays a small bonus. **Pay only goes to active players**
(`server/modules/work_activity.lua`, `economy.lua` → `paychecks`): in the last 30
minutes, a job task (a job_work batch, a work order accepted or paid), a
patient stabilized with the kit, a transfer received of at least 50 €$, or 75 m traveled in the city
(positions sampled by the server every 20 s, teleports and returns from activities
excluded). An inactive player gets nothing and is warned once. Full pay scale:
[docs/economy-balance.md](docs/economy-balance.md).

After hiring, when the office closes, a **job guide** opens: a
guided window, page by page, with animated visuals (the `guide` pages in
`shared/jobs.lua`). It reopens from **F1 → My job**, which also lets you start a
run anywhere (Courier), point the GPS at the next step, abandon the
run, or set the GPS to the three steps of the free activities.
[Configuration, security, how it works and tests](docs/jobs.md) · [Artwork prompts](docs/job-art-prompts.md).

## Vehicle rental

Photo catalog with search, categories and sorting, a summary before payment,
cash/bank choice and confirmed return. Local bank of **18 images** of the catalog
vehicles. [Configuration, image sources and tests](docs/vehicle-rental.md).
Preview: `http://127.0.0.1:5177/?registered=1&dialog=rental`.

## NPC shops

Illustrated yellow/black catalog, search and categories, multi-item cart,
buying/selling back, quantities, cash/bank and bag capacity. First food vendor
in City Center: `(-667.559082, -378.390808, 9.193733)`, yaw `-125.597023`, interaction **E**.

The NPCs share a **template** (`street_food`) defined in `server/config/shops.lua`:
changing the template updates every linked shop. Atomic purchases/sales
(money, inventory and receipt in a single transaction), double-payment protection and validation
on the server; a database is required. [Configuration and API](docs/shops.md).
Browser preview: `http://127.0.0.1:5177/?registered=1&dialog=shop`.

## Framework architecture

### Voice range

**F11** cycles whisper / normal / shout. The `open-voice` package shows a
yellow 3D circle for **3 seconds**, at the radius confirmed by the server
(**3 / 20 / 40 m**). It follows the player and disappears on its own, with no new
WebUI. [Configuration and validation](docs/voice-range.md).

RP catalog: **30 items, including 18 illustrated consumables** (9 foods, 6 drinks,
3 healing items), with effects, weight and stacks configurable in `shared/items.lua`.
[Catalog and adding items](docs/item-catalogue.md) · Preview:
`http://127.0.0.1:5177/?registered=1&items=1`.

**One page, one state.** The server publishes the player's state by keys (`server`, `character`,
`needs`, `vehicles`, `staff`, `locations`, `online`), each module providing its own through
`LightRP.stateProvider(key, fn)`. `LightRP.state(playerId, keys)` pushes the key to the client, which
relays it to the page (`lightrp:ui:state`); the page merges the patch into its store (zustand).

**Actions validated on the server.** The page emits `lightrp:ui:action { type, ... }`, the client
forwards it as is (`op77_lightrp:action`), and the server dispatches it to `LightRP.action(type, fn)`.
The answer comes back through `LightRP.result(playerId, ok, text)` and shows as a toast. Staff
actions check the same ACL permission as the matching command.

**The client decides nothing.** It creates the surface, samples the HUD ten times per second,
takes focus when the menu or the identity dialog is open, and relays.

### Writing a module

```lua
-- server/modules/bank.lua
local Bank = LightRP.module("bank", {})
LightRP.db.schema([[CREATE TABLE IF NOT EXISTS lightrp_bank (...)]])
LightRP.stateProvider("bank", function(playerId) return { balance = Bank.balance(playerId) } end)
LightRP.action("bank.withdraw", function(playerId, payload) ... LightRP.result(playerId, true, "Withdrawal done.") end)
LightRP.command("bank", { usage = "/bank" }, function(source) LightRP.openMenu(source, "bank") return true, "Bank opened." end)
function Bank.onConnected(playerId) ... end   -- also onDisconnected, onReady, onGameplayReady, onLifeState, onDatabaseReady, onUiReady
```

Add the `server_script` line in `open77.lua`, the key in `UiState` (`protocol.ts`) and
the tab in `features/menu/Menu.tsx`.

## Character creation and persistent identity

An account (Master identity, `GetPlayerIdentifier`) owns up to `characters.maxSlots` characters,
each under a `character_key` (`default`, `slot2`, `slot3`). The same key is used by `open77_appearance`
(body and face, table `open77_characters` + `open77_player_appearances`) and by `open77_wardrobe`
(outfits, `open77_character_presentation`): the framework never stores the appearance itself; it
reads those tables and listens to the host events `open77:appearance:characterCreated` and
`open77:appearance:saved` to keep `body_family`, `appearance_rev`, `appearance_at` up to date.

Tables: `lightrp_accounts` (account → active slot) and `lightrp_characters` (identity details, status
`draft`/`active`/`archived`, position, needs, playtime). An old v1 table (one
character per account) is renamed `lightrp_characters_v1` on first start.

**The workflow**, driven by `character.step`, which the server computes (`identity` → `appearance` →
`confirm` → `done`):

1. First connection: `open77_appearance` holds the preparation gate and opens the native editor
   before the world; the body is validated and saved by it (`characterCreated`).
2. In the world, the "New character" wizard (a dialog with focus) asks for identity details:
   first name, last name, date of birth (2077 calendar, configurable minimum age), origin, backstory
   → action `character.identity`.
3. "Body and face" step: buttons *Female body* / *Male body* / *Hairdresser*. The client
   closes the page and asks the appearance package for the mirror (`open77:appearance:requestOpen`). The
   save comes back through `saved` and the server pushes the revision.
4. "Confirmation" step: summary, *Wardrobe* (`/wardrobe` through the command bus) and *Enter
   Night City* → `character.finish`: status `active`, active slot, placement at the arrival point
   (`onCharacterActivated`).

After that, the **Character** tab of the menu: edit identity details, reopen mirror / hairdresser /
wardrobe, manage slots (*Play* → `character.select` triggers
`open77:appearance:setCharacter` and puts the player back at that character's last position;
*New* → `character.new` opens a draft; *×* → `character.archive`). The module hooks
`onCharacterActivated(playerId, character)` and `onCharacterSwitched(playerId, character)` are
available to other modules.

Without a database, the appearance step is skipped (`appearanceTracked = false`) and everything only lasts
for the session.

### First spawn briefing

When the character becomes active for the first time (`character.finish`), the server pushes `character.welcomePending = true` (column `lightrp_accounts.welcome_seen_at` NULL, once per account). The page shows `features/welcome/WelcomeModal`: an image of Night City (`web/img/night-city.jpg`), English text that explains Light Roleplay, and an OK button locked for `welcome.readSeconds` (config, 15 s). The click sends the `welcome.ack` action, which timestamps the column, and the modal never shows again. The Help tab ("Welcome briefing" button) replays it with no delay.

All player-facing text (page, notices, command replies, config labels) is in English.

## Money and bank (`server/modules/economy.lua`)

Cash is the **`cash` / Eurodollars** item: 1 unit = €$1, **0 kg**, transferable, divisible, storable and tradable like any other item. Only the money in your pockets can be spent; the HUD counts it straight from the inventory. The `XXX-XXX` bank account stays separate in `lightrp_wallets.bank`. Old balances are converted only once, with a backup before conversion in `lightrp_cash_migrations` and an atomic transaction. New characters get `economy.startingCash` as an item and `startingBank` in the bank. See [docs/cash-inventory.md](docs/cash-inventory.md) for migration, persistence and tests.

API for other modules (jobs, shops, rent): `LightRP.money.addCash/removeCash/addBank/removeBank(playerId, amount, kind, note, counterparty)`, `deposit/withdraw`, `transfer(playerId, "XXX-XXX", amount, note)`, `pay(playerId, targetId, amount)` (hand to hand, `economy.payRange`), `creditAccount(number, …)` (works offline), `findAccount`, `format`. Hook `onMoneyChanged(playerId, wallet, delta, balance, kind)`. Balances never go below zero; a `busy` flag per wallet prevents two interleaved operations.

Page: `money` state (`cash`, `bank { number, balance }`, `history`), actions `money.deposit|withdraw|transfer|pay` (ready for the future ATM page). Commands: `/money`, `/bank`, `/pay <id> <amount>`, `/transfer <account> <amount> [note]`, `/deposit`, `/withdraw` (as long as `economy.counterCommands` is on), staff `/lightrp.givemoney`, `/lightrp.takemoney`, `/lightrp.account`.

### Balancing and recurring costs (`server/config/economy.lua`)

The target curve, its measurements and the before/after table for each price are in
[docs/economy-balance.md](docs/economy-balance.md). Prices stay with their
features; `server/config/economy.lua` holds the cross-cutting rules:

- **Missions and gigs** (`server/modules/mission_pay.lua`): the pay for a difficulty is
  the share of **each** operator at the minimum crew size. Above that, the pot grows as
  crew^0.7 and is split. A full payout at the same mission point is only paid again
  to the same character after 60 min, and an account gets 6 full payouts per UTC day;
  beyond that, 25%. Cap of 250 €$ per minute of duration. Operators see the expected
  pay at launch and the reason for any reduction at the end. Tables
  `lightrp_mission_payout_cooldowns` and `lightrp_mission_payout_daily`.
- **Hospital**: 300 €$ after *Give up and go to hospital*, bank first, then cash, never
  going below zero (the rest is written off). Free after a rescue with the kit, in a mission, in an
  activity, during the first day and during the character's first 120 minutes of play.
- **Fitting room**: 50 €$ per visit to a city fitting room that saves an
  outfit; free in a home, the arrival hall, the wizard and for newcomers, and waived if the player
  can't pay.
- **Activities** (`server/modules/activity_pay.lua`, `economy.lua` → `activities`): a
  ranked PvP result pays 70 €$ per minute played × (0.75 + 0.5 × result), the result
  going from 1 (win, first place) to 0 (last place, loss), multiplied by the
  share of the full lobby actually present (players seen by the server in the same
  activity and the same bucket, per account; never a number from the provider). An average
  player earns roughly a job's rate, a good player a fifth more. PvE
  pays 40 / 50 / 60 €$ per minute depending on difficulty, half on a loss. Nothing for an
  unranked result (bots, `result.unranked`, staff bot mode, `test`), leaving or
  forfeiting, being AFK (no progression stats), a match shorter than the mode's
  minimum, or a match where all the real players are in the same crew. The same accounts
  are only paid together 3 to 5 times per hour, and an account earns at most
  12,000 €$ PvP and 6,000 €$ PvE per UTC day (table `lightrp_activity_pay_daily`).
  Each payout goes through the bank (`activity_pvp` / `activity_pve`) with a notice
  "+€$ N — reason".
- **Cars** (`server/config/dealerships.lua`): starter cars 4,000 – 6,500 €$, decent ones
  12,000 – 16,000 (≈ 3 h of mixed play), high end 80,000 – 100,000 (≈ 20 – 25 h).
  The full pace per profile (regular, grinder, PvP, PvE) is in §7 of the pay scale.
- Impound (`server/config/garages.lua`), fuel (4 €$/L, `shared/config.lua`) and
  food (`server/config/shops.lua`) prices are raised. No existing balance is changed.

## Player menu (F1)

RageUI-style list menu (design system: Menus / RageMenu, ported to `ui/src/design/components/RageMenu.tsx` with `o77-rage*` classes): one column, one highlighted row, arrows to move, Enter to go down, Backspace / Esc to go back up, F1 to close. `features/menu/PlayerMenu.tsx` builds the tree from the server state on every render and keeps a `{ key, index }` stack. First submenu: **Identity** (citizen ID, first name, last name, date of birth, origin, bank account, playtime, status). The Lua client takes only the keyboard (`setFocus(true, false)`); the menu only opens with an active character and outside the briefing. There is no longer a "terminal" menu, nor spawn or deposit commands for players: vehicles through `/lightrp.car` and `/lightrp.dv` (staff), money through the upcoming ATM.

## Free camera (`client/core/freecam.lua`, page `features/freecam/`)

The view detaches from the character and flies around them to look at a scene from another angle. The body stays where it is, whole and in third person (`thirdPersonBody`), whatever the starting perspective: it is a camera, not a noclip. It opens from the player menu (**Free camera** row) or with its key (F5 by default); on foot only, never during an action, a dialog, character creation or a tutorial camera.

- **Radius**: the camera stays within `freecam.radius` meters of the character (25 by default, 100 at most) and never goes more than `freecam.below` meters below their feet. It slides along the limit; the banner gauge turns orange, then red.
- **Keys**: all go through `RegisterKeyMapping` (`Config.freecam.keys`), so they can be changed in Pause > Settings > Key Bindings. Forward / back / left / right follow the keyboard layout (WASD, ZQSD on AZERTY), Space / C go up and down, Shift speeds up, Ctrl slows down, mouse wheel = speed, Ctrl + wheel = zoom, R goes back behind the character, H hides the key hints, Backspace or the opening key exits.
- **Smoothness**: speed, rotation and zoom are smoothed (`freecam.smoothing`), entering and leaving fade over `blendMs`. When started from third person, the shot begins exactly where the view was.
- **Shared flight**: the flight step (look, speed, movement, spherical leash and floor) lives in `client/core/freecam_motion.lua`, reused by the *Free* view of the tables (`docs/board-games.md`) with the same keys.
- **Key hints**: a passive banner at the bottom of the screen, drawn from the actual keys, with distance / radius, speed and focal length. Chat, pause or the F1 menu freeze the shot without closing it.
- **Automatic close**: death, getting into a vehicle, a dialog opening, the character moved more than `freecam.leash` meters, the engine taking the view back, resource stop. The character's locks are given back one by one (no `resetControls`, which would also drop the walk mode).

Platform limits: the camera has no collision (it goes through walls within the radius) and the world stays loaded around the body, not around the camera. Tests: `tests/freecam_client_test.lua`, `ui/tests/freecam.browser.cjs`.

## Proximity interactions and vehicle rental

**Interactions** (`server/core/interact.lua`, `client/core/interact.lua`): a module declares a point with `LightRP.interaction(id, { position, radius, label, prompt, key })`. Each client receives the list (`op77_lightrp:interactions`). If `marker` is set, it creates a native 3D marker through `Open77.markers`; otherwise it keeps the legacy ground circle, unless `ring = false`. The shared WebUI anchor shows "E · Rent a vehicle" above the point only when the player is within the radius. E (key `lightrp.interact`, rebindable) sends the id to the server, which rechecks the distance from its own position, then calls `onInteract(playerId, id)` on the modules. `LightRP.dialog(playerId, kind, payload)` opens a page window (`lightrp:ui:dialog`).

Rental agencies now use a **translucent yellow 3D cylinder, with an upward gradient**, with no circle on top. `shared/config.lua` → `rentals.marker` sets `shape`, `radius`, `height`, `color` (RGBA 0–255), `minDistance` / `maxDistance`, `groundOffset` (meters), plus `scale`, `rotation`, `style` and `visible` if needed. The visual radius doesn't change `rentals.interactRadius`: the NPC, the E key, the blip and the server validation stay independent of the marker. Handles are deleted when the list is replaced; the platform also cleans them up on disconnect or resource stop. You need an Open77 client with the API **and the 3D marker archive**, plus the `world.markers` permission (already declared). On an old client, a diagnostic is logged without blocking the rental or bringing back the circle.

**Rental** (`server/modules/rental.lua`, page `features/rental/RentalDialog.tsx`): agencies are in `config.rentals.spots` (NPC through `Open77.npcs.create`, candidates tried in order; stock = keys of `vehicles.catalog` with prices; `parking` = spawn point to record with `/pos`). A player can only have one rental at a time; they pay in cash or by bank through `LightRP.money`, the vehicle appears in the parking lot for `durationMinutes`, then is taken back (notice); it can be returned at any agency ("Return vehicle" button), and it is cleaned up on disconnect or character change. History in `lightrp_rentals`. Staff: `/lightrp.rentals`. Page state `rental.active` (HUD chip with the countdown), actions `rental.rent { spot, key, pay }` and `rental.return`.

## Vehicle keys (`server/modules/keys.lua`, `client/core/keys.lua`)

A key lets you lock / unlock explicitly: **a locked vehicle is closed to everyone, owner included**. Both operations go through `Open77.vehicles.setLockedForAll` to remove individual exceptions. A key is an entry in the registry `LightRP.keys.ledger[vehicleId].holders[identifier#slot]`, tied to the character, not the session. Reconnecting, changing character or sharing keys never unlocks the car. Replication through state bags: `Open77.state.entity("vehicle", id).keys = { label, owner, holders }` and `Open77.state.player(id).vehicleKeys = { [vehicleId] = label }` (read by the client to know whether it can press L).

API: `LightRP.keys.give(vehicleId, playerId, { label, owner })`, `take`, `clear`, `has`, `holders`, `lock(vehicleId, locked)`, `toggle(playerId, vehicleId)` (validated: key, same bucket, distance `vehicleKeys.range` or sitting inside, short horn). Hook `onVehicleLockChanged`. Key L (`lightrp.vehiclelock`, rebindable): the occupied vehicle, otherwise the closest one. Keys disappear with the vehicle (`onVehicleRemoved`). Staff: `/lightrp.givekeys`, `/lightrp.takekeys`. The rental delivers the car locked, with the key in the renter's pocket: press L to get in.

## Alt + click vehicle menu

Key holders get a main menu limited to four entries: lock, **Trunk & hood**, **Vehicle controls** and condition. The first submenu has the trunk/hood openers and the inventory of the targeted trunk; the second has engine stop, the lights and the horn. Side doors, their general controls and the windows are removed, including from the list of actions the server accepts. The choices follow the current state; motorcycles don't show trunk/hood. Back, left arrow, Backspace or right click goes back up to the main menu; Esc closes everything. The contextmenu package stays generic, with no default action.

Each request is rechecked on the server (keys, active and living character, proximity, bucket, driver / occupants, speed, anti-spam). Unlocking is still required to open a trunk or a hood. Settings: `shared/config.lua` → `vehicleContext`. Details, API and tests: [docs/vehicle-context.md](docs/vehicle-context.md).

## Inventory (`shared/items.lua`, `server/modules/inventory.lua`, page `features/inventory/`)

ox_inventory model: grids of slots with a maximum weight, stacks of identical items (same `name` + same `metadata`, up to the template's `stack`), every move validated on the server. Kinds: `player:<identifier>#<slot>` (persistent, loaded with the character, starting items in `config.inventory.starting`), `trunk:<vehicleId>` (session, a nearby vehicle in the same bucket, which must be unlocked, even with the keys), `drop:<n>` (session, a pile on the ground with an E "Pick up" interaction point, expires after `drop.ttlMinutes`), `stash:<id>` (persistent, points from `config.inventory.stashes`). Table `lightrp_inventories` (items as JSON).

Locking immediately removes the trunk from the inventory of everyone using it, without closing their pockets or moving any items. Transfers already in progress are rechecked on the server and refused if the trunk has become locked, too far away or in another bucket. Stale subscriptions are removed before anything is published. I near a locked vehicle opens only the pockets and explains that the trunk must be unlocked first. Isolated tests: `pwsh -NoProfile -File tests/run-lua.ps1 -Test vehicle_access_test.lua` from the resource (no game needed).

Templates in `shared/items.lua`: `label`, `description`, `weight` (kg), `stack`, `icon` (a Lucide name the page knows, fallback `package`), `category`, `use = { consume, food, drink, health, notice }`. Another module can hook in with `LightRP.inventory.onUse(name, fn)`. API: `addItem(invId, name, count, metadata)`, `removeItem`, `count`, `canHold`, `move`, `use`, `drop`, `give`, `open(playerId, invId?)`, `playerId(playerId)`; hook `onItemUsed`. Page actions: `inventory.open|close|move|use|drop|give`. Key I (`lightrp.inventory`). Staff: `/lightrp.giveitem <id|me> <item> [n]`, `/lightrp.items`.

Page: two airy grids (pockets on the left, trunk / pile / storage in the middle) and an item sheet on the right. With no storage nearby, a drop zone replaces the second grid. A click selects; a move of more than 6 px starts drag and drop. The sheet shows the description, unit / total weight, quantity (1 / half / all), use, transfer, split, give to the nearest player and drop. The Give / Drop buttons ask for confirmation; dropping by drag and drop stays instant. The server always checks ownership, proximity, weight, metadata and quantities. A trunk item can't be dragged to the ground by mistakenly aiming at a player slot: you have to take the item first.

Search per panel without renumbering the slots, right click for quick actions, arrows to move around the grid, 1–5 to select the first slots, Shift + drag for half a stack. Esc first closes a confirmation / a context menu / a drag, then the inventory, even from a text field. Tab stays inside the window. Actions wait for the server (no optimistic change and no double send while waiting); fresh snapshots arrive through `lightrp:ui:inventory` for everyone looking at the changed inventory. An update or a focus loss cancels drags that have gone stale. Scrolling grids, explicit empty and error states, short transitions that respect `prefers-reduced-motion`.

UI tests: `ui/tests/inventory.browser.cjs` against the Vite server. The mock bridge checks the actions actually emitted, the server answers, quantities, focus, drag cancels, empty Lua tables, 720p / 1080p / 1440p / ultrawide resolutions and HUD alerts. Install Playwright in the test environment (or provide `PLAYWRIGHT_MODULE`), then run `node tests/inventory.browser.cjs` from `ui`. `UI_URL` and `BROWSER_CHANNEL` let you change the server and the browser; by default, Vite on `127.0.0.1:5177` and Edge.

The HUD and the inventory keep the server's yellow / black identity: the design system `--accent` for main actions, selections, health / stamina gauges and navigation cues. Clean typography, translucent black backgrounds, no big plate behind the needs. Alerts and the other needs keep their semantic colors.

**I opens and closes the inventory**. The close shortcut comes from `Open77.input.keyFor`: it follows any rebinding in the settings. Once the keyboard is captured, the page closes on the release of a new press, without reacting to the initial release or to key repeats; the letter can still be typed in the search. The client applies a short debounce when focus returns to avoid an immediate reopen. Esc stays available from text fields. Helper tests: `node --experimental-strip-types --test tests/inventory-model.test.ts` (Node 22.6+).

## What the player sees

- Bottom-left HUD: main health bar and four separate gauges (armor, stamina, hunger, thirst),
  with no big plate and no repeated name / logo. The gauges move smoothly, health changes
  are shown briefly, and alerts only appear below critical thresholds.
  A soft shadow keeps the labels readable over the world. The HUD fades out while the inventory is open.
  Voice and the vehicle gauge stay in their usual places.
- On first connection, a [four-step wizard](docs/character-creation.md)
  walks through identity, the optional backstory, appearance and the summary. Black/yellow design,
  going back without losing what you typed, server validation and keyboard navigation.
  Until the identity is filled in, only `/ooc` works in chat.
- **F1** opens the player menu (identity, information and help); **I** opens the inventory.
- Normal chat is in-game speech at 20 m, under the character's name.

| Command | Effect |
|---|---|
| `/register <First> <Last>` | Creates or renames the character. |
| `/w` · `/s` · `/ooc` | Whisper (4 m) · shout (45 m) · out of character (global). |
| `/me` · `/do` · `/try` · `/roll [max]` | Action · scene · attempt (50%) · dice. |
| `/pm <id> <text>` | Private message. |
| `/car <model>` · `/cars` · `/dv` | Call · open the garage · return. |
| `/who` · `/rules` · `/help` · `/report <text>` | Who's online · rules · help · report to staff. |

Staff (`command.lightrp.<name>` in `acl.jsonc`): `/lightrp.tp <id|me> <place|x y z>`,
`/lightrp.bring <id>`, `/lightrp.goto <id>`, `/lightrp.heal <id|me>`, `/lightrp.announce <text>`,
`/lightrp.setname <id> <First> <Last>`, `/lightrp.car <model>`, `/lightrp.status`.

## Persistence

### Personal vehicles and dealership

**Night City Motors** (the `cardealer` map) offers a catalog of vehicles to
buy (cash or bank): **E** at the salesperson, at the showroom front desk. The
vehicle you buy comes out right away in the delivery bay, locked, keys in hand, and
a marker with a GPS route leads to it; if the bay is taken or another personal
vehicle is already out, it waits in the garage and the GPS leads to the garage. Four
display cars (locked, frozen) sit on the podiums. The **Public Garage** lets you take out
and store personal cars; they can still be recovered after a reboot or an
admin deletion. **No starter car is given.**
**Impound**: a vehicle left out during a restart, or gone from the world
(destroyed, deleted, bug), goes to the impound; from any garage, the
owner can send their own vehicle there (stolen, lost, stuck), which removes it from the world
wherever it is. You get it back at any public garage (Impound tab),
for a fee that depends on the reason (`impound.fees` in `server/config/garages.lua`:
free after a restart for an intact vehicle, 400 €$ for a wreck (destroyed,
exploded or at 0 health, whoever did it; insurance repairs it), 150 €$ for
a vehicle gone with no trace of a wreck (deleted, cleaned up, bug), 250 €$ at the
owner's request, 500 €$ after a removal by staff). A wreck can't be stored in
the garage. Staff: `/lightrp.givevehicle <id|me> <model> [garage]`,
`/lightrp.impound` next to the vehicle (or with its network id).
SQL is required for these features; they shut down on a storage
error. See [configuration, API and guarantees](docs/personal-vehicles.md).

Tables `lightrp_characters` (Master identity, account, first/last name, last position, hunger, thirst,
playtime) and `lightrp_reports`. Without a configured database, the framework starts and says so in the
log; everything then only lasts for the session.

## Crews (`server/modules/parties.lua`, `client/core/crew.lua`, page `features/crew/`)

The **crew** is the only way to group up: missions, the Chimera raid, activities (arena, races,
chases, turf) and fixer gigs. The server is the authority; the crew lives in memory (a
restart disbands it). Settings in `server/config/missions.lua`, `party` block:
`maxSize` (8), `inviteSeconds` (60), `nearby` (15 m, the "Nearby" list in the panels),
`inviteRange` (300 m, range of an invite), `farRange` (250 m, beyond that a member is
marked FAR), `refreshMs` (2 s, refresh rate of the members' state).

- **Invite**: **Alt + click** on a player › *Invite to crew* (`open77_contextmenu`, "Crew"
  group, 15 m), or `/crew invite <id>`, or the *Invite* button in the panels. Only the leader
  invites; the player must be in the same instance and less than 300 m away. The first invite creates
  a one-person crew that stays **solo** until someone accepts.
- **Reply**: an on-screen invite above the crew frame, **Y** to accept / **N** to decline
  (rebindable keys, "Light RP: accept crew invite" and "Light RP: decline crew invite";
  the invite shows the actual key), clickable buttons when the cursor is visible, or
  **F1 › Crew**, the *Crew* tab of the Activities panel, `/crew accept` · `/crew decline`.
  During the raid ready check, if both actions share the same key, the raid
  takes it. To join another crew, you have to leave yours (a one-person crew
  still waiting for replies clears itself).
- **Manage**: Alt + click › *Make crew leader* / *Kick from crew* (leader only) and, on
  yourself, *Leave crew*; or `/crew lead <id>`, `/crew kick <id>`, `/crew leave`, and the
  same buttons in F1 › Crew and the *Crew* tab. If the leader leaves, command passes to the
  longest-standing member; a crew down to one person disbands.
- **Commands**: `/crew` (status), `/crew invite <id> · accept · decline · leave · kick <id> ·
  lead <id> · matchmaking on|off`; `/party` is an alias.
- **HUD frame** at the bottom left, above the weapon and the gauges: leader's crown, YOU,
  DOWN / DEAD, MISSION / BOARD / ACTIVITY (what the member is busy with), FAR. Eight rows at 1080p,
  five on a short screen (≤ 800 px tall), the rest in F1 › Crew; your own row always
  stays visible. During a mission, the same frame shows each
  operator's health and armor (matchmaking strangers grayed out). Notices shift to the right of the frame
  when the two touch.

**Missions and the Chimera raid.** The **leader tags the crew in** on the board (**E**); a member
can't sign up alone ("Your crew leader tags the crew in. Leave the crew to go solo.").
The **matchmaking** switch (**M** key on the board, F1 › Crew, *Crew* tab,
`/crew matchmaking on|off`, leader only) is **off by default**:

- off: private board, nobody else gets in; the countdown starts as soon as the crew
  reaches the difficulty's minimum; below that, sign-up is refused with what to do
  next (invite, or open matchmaking);
- on: the crew joins the fullest open board that still has room, and solo players in
  matchmaking fill it up; the countdown starts at the maximum, or the host launches (**R**) once the
  minimum is reached.

A solo player follows the same rule: with matchmaking off, they only enter a difficulty
that can be played alone; with it on, they join open boards. The board points out nearby open
boards. Leaving the crew removes the player from the board the crew signed them up for; joining one
cancels their solo sign-up; turning matchmaking off closes the crew's board, or removes the crew
from a shared board. The queue chip shows FILLING (open) or CREW ONLY.

**A member below the difficulty is never refused** (owner's decision, 2026-11-03).
The leader chooses, and only their tier (plus the "finish the previous one" ladder) limits that choice;
a member whose tier or clears don't unlock the difficulty is signed up and launched with the
crew, plays the full difficulty and gets the full pay, but their reputation is that of the
highest difficulty unlocked for them (`Missions.rewardBasis`): a Street carried into Critical
earns 100, not 450. They read it once, in a "STREET CRED" notice ("Critical is above your
street cred: you play it, you earn the Standard reward (+100 reputation)."), the leader sees the
list of reduced rewards in the sign-up reply, the end notice says which one
paid, and the member's board shows the locked difficulty "WITH THE CREW +100 REP". A
solo player, and a matchmaking stranger (signed up for themselves), are still bound by the tier.

**Activities.** The leader joins (*Join with the crew*): each eligible member is queued
with the same `options` and the same `options.squad = { id, leader, members }`; an
ineligible member stays out, with the reason in a notice. A member doesn't launch an activity alone;
`/leave` takes them out of the queue, and if the leader cancels, the members queued with them leave too.
In PvE, the member gets the leader's difficulty (`options.difficulty`) even above their
tier: they play it and their result counts at the highest difficulty their tier unlocks
(same rule as missions, stated once in a notice).

**Fixer gigs.** Offers only go to a crew's leader (or to solo players); when the leader
accepts, free members who have a Neural-Link implant join the gig with them.

## Fixer gigs (`server/modules/fixers.lua`, `server/config/fixers.lua`)

Fictional fixers (server side: Mama Okoro, Silas "Ledger" Varga, Nix Delacroix) randomly send,
by Neural-Link SMS, a "gig" drawn from the catalog: the editor missions marked
**Fixer gig** (`/lightrp.missions` › mission › Fixer gig: switch, fixer, brief). A fixer
mission has **no board** in the city: you can't sign up for it, you receive it.

- **Offer**: job card (maximum pay per operator, duration), *Take the job* / *Pass* buttons (3 min).
- **Brief** once accepted: the objective (the fixer's brief, otherwise the description), the
  meet point (= board position in the editor) with *Pin the meet point* (waypoint on the
  map), *Share the job* (a contact or a number receives the offer and can *Join the crew*),
  *Go now* (the leader launches with whoever is there, at least the difficulty's minimum) and *Bail*.
- **Meet**: when the whole crew is at the point (20 m), a 10 s countdown, then the
  mission starts like a normal mission (kit, instance). If not everyone is there after 20 min:
  launch with whoever is there if that's enough, otherwise the job falls through.
- **Crew**: when a crew's leader accepts, their free members (with an implant) join the
  gig; automatic offers don't go to members of a crew they don't lead.
- **End**: each operator is paid (`gig` to the bank) according to the mission rules
  (shared pot, 60 min cooldown, daily cap, see "Balancing") +
  reputation; the fixer sends a message with the amount actually paid.
  Reputation follows each player's tier: a crewmate invited below the difficulty's tier
  gets the reputation of the highest difficulty their tier unlocks (`docs/pve-progression.md`); they
  read it once in a "STREET CRED" notice when joining the gig.
- Offers only draw difficulties unlocked at the player's reputation tier
  (Standard at tier I, Hard at II, Critical at III).
- "GIG" HUD chip (`fixerGig` state): players at the point, meet clock, countdown.
- Automatic dispatch: one pass per minute, 8% chance per eligible player (implant, in the city,
  free, 2 min after arriving), 20 min between two offers, 6 open gigs at most.
- Staff: `/fixers.offer <id> [missionId] [difficulty]`, `/fixers.list`, `/fixers.cancel <gig>`,
  `/fixers.dispatch on|off|now`.
- Gigs live in memory: a restart cancels them (their buttons answer "Expired").

## Activities and The Crossing (`server/modules/activities.lua`, `activities_hub.lua`)

Arena, races, chases and events are separate **provider resources**
(`op77_arena`, `op77_race`, `op77_chase`, `op77_fireworks`…) that run their own instances.
Light RP is their **core**: it owns the player during the activity, captures their return
point, puts their RP weapons aside, freezes hunger and thirst, refuses RP items, RP vehicles,
housing and work orders according to the activity's `caps`, applies neither unconsciousness nor
hospital, never saves the instance position and brings the player back at the end. The
results become stats and leaderboards, **never items**; ranked results
pay eddies (`server/modules/activity_pay.lua`, see "Balancing") and only
**PvE** activities also give reputation (see "PvE progression" below).

### The contract (`op77_lightrp` server exports)

All synchronous: they never yield and don't write to the database (an export that waits
fails on the caller's side with `export_yielded`). A provider only acts on its own
activities (`GetInvokingResource`).

| Export | Role |
|---|---|
| `activityRegister(def)` → `true` \| `false, reason` | `def = { id, resource, label, kind, description, minPlayers, maxPlayers, caps }`. `id` prefixed by the provider (`arena.ffa`, `race.trial`, `chase.1v1`), `kind` ∈ `pvp`, `race`, `chase`, `event`, `caps = { rpWeapons, rpItems, needs, vehicles }` (all `false` by default). Registering again replaces. Optional: `modes = { { id, label } }` and `modeKey` (choices offered by the panel, returned in `options[modeKey]`; an unknown choice is refused before it reaches the provider; without `modes`, the config's `joinChoices` can provide some — car or on foot for `chase.1v1`). Also optional: `pve = true` (players against bots, the only source of reputation; without the flag, the config's `pve.activities` list can mark the id, and `pve = false` wins) and `difficulties = { "standard", "hard", "critical" }` (the ones the provider really plays; without them, Standard only). `botFill = true`: the provider can fill with bots (`options.fill`, `options.match.bots`) — without it, the panel never offers bots; a mode opts out with `modes = { { id, label, botFill = false } }`. |
| `activityCheck(id, activityId, opts)` → `true` \| `false, reason` | Eligibility only, in this order: active character, alive and not downed, neither in a mission nor in another activity, not in the first day, not in a home, not in a vehicle, not hurt in the last 60 s, and in the shared city (bucket 0). With `opts.difficulty` on a PvE activity: also the reputation tier it requires — for a crew member, their leader's (a member below the difficulty gets through, for their own tier's reward). The reason is an English sentence shown to the player. |
| `activityEnter(id, activityId, opts)` | Rechecks, records ownership, captures `{ x, y, z, heading, bucket }`, puts RP weapons away if `caps.rpWeapons` is false. The provider then moves the player into its bucket. PvE: the difficulty played is `opts.difficulty`, otherwise the one chosen in the panel (the leader's for a member queued with them), otherwise the first one offered; refused above the tier of a solo player or a leader. A crew member below the tier is **never refused** if their leader can choose that difficulty: they play it in full, their result counts at the highest difficulty their tier unlocks, and they read it once in a notice. |
| `activityLeave(id, activityId, opts)` | Releases. `opts.returnPlayer` (true by default): return to the captured point, bucket included, getting out of the vehicle; a dead player respawns there (never left dead), then gets a full heal and their RP weapons back, on Light RP's thread. |
| `activityOwner(id)` | The activity id, `"missions"` during a mission, otherwise `nil`. |
| `activityPlayer(id)` | `{ name, identifier, characterKey, gang = { id, label, grade, gradeLabel, tag, color } \| nil, job = { id, label, grade, gradeLabel, tag } }` — `nil` without an active character; `gang` is `nil` with no affiliation, `job.id` is `unemployed` with no job. The gang and job are read from `server/modules/jobs.lua` (same views as the `gang` / `job` state bags). `job.onDuty` stays absent: Light RP has no clock-in. |
| `activityKit(id, activityId, kit, opts)` → `true, hand` \| `false, reason` | A temporary mission kit for a player this activity owns, handed out by the same code as missions (`server/modules/activity_kits.lua`): `kit` nil for the one missions preselect, the id of a kit from `LightRpRaid.loadouts`, or `{ primary, secondary, reserve, label, names }`. The outcome arrives on `op77_lightrp:activity:kit`. While the kit is active, the regular armament is hidden and the wheel lists and draws the kit. Full contract: header of `activities.lua`. |
| `activityKitTake(id, activityId, opts)` → `true` \| `false, reason` | Takes the kit back during the activity. The core also takes it back on its own at every exit, then gives the RP weapons back the same way as after a mission. The character's own weapons are never touched. |
| `notice(id, notice)` → `true` \| `false, reason` | A message to the player in Light RP's notice (its page, its design): **a provider never shows an interface of its own** (rule of 2026-11-02); it goes through this and only falls back to `open77_notifications` when Light RP is absent. `notice = { kind, title, body, durationMs, source }` cleaned by `shared/notice.lua`: `kind` ∈ `info`, `success`, `warning`, `error` (`danger` read as `warning`, anything else → `info`), title 48 chars, text 280 (required; `text` or `message` accepted), duration 2 to 20 s (6 s by default). One player only, never `-1`. Reasons: `Invalid player.`, `invalid_notice`, `empty_notice`. What the core already says (sign-up reply "Request sent to …", leaving the queue, MATCH FOUND, queue panel) is not repeated by the provider. |

Server events, `TriggerEvent` / `AddEventHandler` only (never `RegisterNetEvent`:
a client can't raise them):

- provider → core `op77_lightrp:activity:result (id, activityId, result)` with
  `result = { placement, score, won, stats = { kills, deaths, timeMs, courseId, courseRevision… }, reputation, difficulty }`.
  One result per entry every 15 s, and only one up to 10 min after leaving. `reputation`
  only counts for a PvE activity (see below); elsewhere it is ignored.
  An **unranked** result records nothing — no stats (so no row in the Hall of
  Fame), no leaderboard, no reputation, no pay: staff bot mode, unranked entry (friendly
  match, PvP filled with bots), `result.test = true`, `result.unranked = true` from the
  provider, or a PvP result carrying `stats.bots` / `stats.vsAi`. The core then marks it
  `result.unranked = true` and `result.ranked = false` (see *Lobby* below). The eddies for an accepted result are
  computed by `server/modules/activity_pay.lua` (see *Balancing*), from
  `stats.durationMs` / `timeMs` / `seconds`, `quit`, `forfeit`, `bots`, `dnfReason`, the
  entry's difficulty and the mode's progression stats.
- provider → core `op77_lightrp:activity:status (activityId, { phase, players, queued, joinable, detail })`,
  on every change (sends close together are batched before they reach players).
- core → provider `op77_lightrp:activity:join (id, activityId, options)`: the player asked for it
  from the panel (`activityCheck` already passed). `options` holds the panel choice
  (`options.mode`, `options.course`…), `options.from` and, for a crew, `options.squad = { id, leader, members }`
  (the same for each member queued by the leader; see *Crews*).
  For a PvE activity with difficulties: `options.difficulty` (the leader's, already checked against their
  tier) and `options.scaling = { enemies, health, damage, ai }`, which the provider turns into bots.
  Always `options.ranked`; depending on the case, `options.fill = { allies, enemies }` and
  `options.match = { id, ranked, friendly, format, players, teams, side, bots }` (see *Lobby*).
- core → provider `op77_lightrp:activity:leaveRequest (id, activityId)`: the player wants to
  leave (panel, F1, `/leave`) — even if they are only in the queue. Without an `activityLeave` from the
  provider within 15 s, the core releases the player and brings them back itself (`dropped`, reason `timeout`).
- core → provider `op77_lightrp:activity:dropped (id, activityId, reason)`: `disconnect`,
  `character`, `provider_stopped`, `timeout` or `core_stopped`. Ownership is already released.
- core → all `op77_lightrp:activity:ready ()`: Light RP has just started, and providers
  register again (on top of their own `onResourceStart` listener).
- `op77_lightrp:announce (text, { title, durationMs })` — or a table `{ body, title, durationMs }`,
  the `op77_fireworks` shape: an announcement broadcast the same way as `/lightrp.announce`
  (chat + notice). Cleaned text, 2 to 200 characters, title 40, duration 3 to 30 s, one per second.

When a provider stops, its activities are forgotten and its players brought back; on a
reload, whatever the new VM has already registered again is kept.

Buckets: arena `4100000–4199999`, race `4200000–4299999`, chase `4300000–4399999`, games `4500000–4599999`
(city 0, hall 620000, practice 700000+id, fitting rooms 710000+id, homes 1000000+id, missions
3000000+n). Fuel ignores vehicles in these buckets; keys and impound only apply
to RP system vehicles (personal, rental, `/car`), never to those an activity creates.

### Inside Light RP

`LightRP.activities.owns(id)`, `owner(id)`, `allows(id, cap)` and `savedPosition(id, repli)`
are the one-line hooks placed in `server/main.lua` (no RP respawn),
`medical.lua` (no unconsciousness), `armament.lua` (RP weapons put away; the damage gate lets
the activity's weapons through), `needs.lua` (hunger and thirst frozen), `characters.lua` (saved
position = return point), `inventory.lua` (use, give, drop — so consumables,
grenades and the quick bar), `grenades.lua`, `cyberware.lua` (Mantis blades), `rental.lua`,
`garages.lua`, `vehicles.lua` (`/car`), `keys.lua`, `fuel.lua`, `housing.lua`, `job_runs.lua`,
`job_work.lua` and `fixers.lua`. **Missions** are an internal provider: an operator in a
mission is refused by `activityCheck`, and disconnecting during a mission saves the
board's point, plus the arena coordinates.

### Stats, leaderboards, reputation

Tables `lightrp_activity_stats` (per account + character + activity, and per course
`courseId@revision` for races: matches, wins, kills, deaths, best score, best
time, best place, reputation) and `lightrp_activity_rep_daily` (reputation granted per
account and per UTC day).

**Only PvE activities give reputation.** PvP, races, chases and events
record matches, wins and leaderboards at 0 reputation, whatever the result asks for. A
PvE result is worth its difficulty's reputation (`pve.difficulties`: Standard 30, Hard 60,
Critical 100) × the activity weight (`pve.activities`: `arena.pve` 1.0, `race.pve` 0.5,
`turf.pve` 1.2, `chase.pve` 0.6): in full for a win that specifies nothing, otherwise
`min(reputation, that cap)`. The difficulty counted is the entry's, lowered to the highest
one the player's tier unlocks. The total stays under `reputation.dailyCap` (500) per account
and per day; with `grantTo = "missions"` it adds to the missions' street reputation.
`reputation.pvpGrants = true` restores the old rule (all kinds, capped at
`maxPerResult` = 50). Leaderboards: top 5 per activity, by best time for races, by
wins otherwise. Without a database, everything only lasts for the session.

### What the player sees

- **The Crossing**, the Westbrook plaza where newcomers arrive: two terminals (yellow
  marker, **E**) — *The Crossing* opens the Activities panel, *Contracts* lists the city's mission
  boards with a GPS route to each one (the boards themselves don't
  change). An "Activities" pin on the map (`op77_map3d`, Missions category).
- **Activities panel** (`ui/src/features/activities/`): the list (status, players, queue), the
  details (mode choice when there is one, PVE badge and difficulty choice — locked ones
  say which tier unlocks them —, Join / Leave / Cancel, the reason for a refusal),
  your record and the leaderboard; *Contracts* and *Crew* tabs (invites, members, mission
  matchmaking, players within 15 m). Status banner at the top: in an activity, waiting, in a
  mission, or why not.
- **F1 → Activities** (opens the panel, plus direct *Leave …* / *Cancel …*) and **F1 → Crew**
  (accept or decline an invite, members, hand over leadership, kick, matchmaking,
  leave).
- **Neural-Link → Gigs & Arena** (`client/core/activities.lua`): opens the same panel anywhere.
- At the end of the first day (finished or skipped): a notice pointing to The Crossing, and a
  route if the player is far from it. Mara's voice lines don't change.
- Panel footer: reputation tier ("Street cred") and today's PvE reputation.
- Commands: `/leave` (leave the activity or its queue), `/activity [list · join <id> [mode|difficulty] · leave]`.
  Staff: `/lightrp.activities` (activities, owners, queues, operators in a mission) and
  `/lightrp.survey [label]` (position and heading, in the config format).

### Lobby: bots, ranked queue, friendly match (`server/config/activities.lua` → `lobby`)

Bots are a **panel choice**, no longer a command. An activity only offers them if it
is listed in `lobby.activities` **and** its provider has declared `botFill = true` (a mode can
opt out); an activity missing from the list is joined as before (ranked, without bots or
friendly match). Chases (`op77_chase`) are not in it: real players or the game's NCPD only.

- **PvE, "Fill empty slots with bots"** (`allies = true`): allied bots fill the crew
  up to `seats` places (by default `maxPlayers`) — 6 seats and a crew of 4 give 2 allies.
  The provider gets them in `options.fill.allies`; they take no difficulty
  multiplier. **Always ranked**: reputation, pay and Hall of Fame as usual.
- **PvP, "Play with bots"** (`bots = true`): the core forms a match with bots right away
  (`options.match`, `bots` per side). **Unranked.**
- **Ranked queue** (`queue = true`: `arena.duel`, `arena.teams`, `race.grid`, `race.foot`): a
  PvP request without bots becomes a ticket in the core's queue. A crew stays whole, on the same
  side, and counts toward the team size (`teams`, `teamSize`, one size per mode possible); a
  crew that is too large is refused. Matching by **cyberware bracket**: the rank unlocked by
  street cred (`cyberware.lua` → `gating.byRank`, the highest member for a crew), mapped to a
  bracket by `matchmaking.brackets`. First the same bracket or the next one, then the gap widens
  with the wait of the longest-waiting player (`matchmaking.widen`: 2 brackets at 60 s, 3 at 80 s, everyone at
  100 s); races ignore brackets (`brackets = false`) and wait `gatherMs` (15 s)
  for other players once the minimum is reached. The panel shows the timer, found / required,
  *Near your rank* or *All ranks*, and *Cancel*. After `fillAfterMs` (2 min), the leader is
  offered *Fill with bots* (unranked match) or *Keep waiting*. `turf.war` keeps its
  provider's queue (one war at a time); the bot offer applies there too.
- **Friendly match** (`friendly = true`): the crew leader opens *Friendly match*; the core splits
  the crew by street cred (*Auto-balance*), the leader moves players (arrows or click; a full
  side swaps), puts bots in the empty seats if the mode allows it, then *Start*. Members
  see the split without being able to change it. Always **unranked**.

**What counts.** The core alone decides: `options.ranked` on every `join`,
`A.isRanked(entry | match | player)` and the `activityRanked(id)` export. An unranked result
(friendly match, PvP with bots, staff bot mode, `test`, the provider's `unranked`, `stats.bots` /
`stats.vsAi` in PvP — never a PvE with allies) is marked `result.unranked = true`,
`result.ranked = false` in `A.result` and stops there: no stats (so no
Hall of Fame row, since its activity rows come from `lightrp_activity_stats`), no leaderboard, no reputation, and
`activity_pay.lua` is not called (it also refuses `result.unranked` on its own). A ranked
result carries `result.ranked = true`.

The panel sends the `activities.lobby` action (`fill`, `friendly`, `move`, `balance`, `bots`,
`cancel`, `start`). A ticket expires after 15 min, and a formed match that hasn't started after 2 min.
`/lightrp.bots on|off` (staff) is still available to test alone: nothing is recorded.

### Game rooms (`server/modules/activity_rooms.lua`, `ui/src/features/rooms/`)

A player hosts a match at the **rooms NPC** in The Crossing (terminal
`kind = "rooms"`, *Jackie Welles*, with its own `host` and its own pin), or with `/room`
from anywhere: they pick the game, the map, the team size, a public or private room (a
5-character code); others join; the host launches. A game with no enabled map doesn't show up. **A room is a friendly match without a crew**:
same shape as setting up a friendly, same launch (`A.launchFriendly`, so `startMatch`
with `friendly = true`). The match, the recap and the return are the core's, and nothing is
recorded (no stats, no Hall of Fame, no pay, no reputation). Everything lives in memory.

- **What can be hosted**: `rooms = true` in `lobby.activities`, a registered activity, a friendly match
  possible, a shape with no fixed `teamSize`. The menu only shows the intersection of `rooms.games` and
  the `activities` list: a missing provider disappears. Without `modes` (`race.grid`,
  `race.foot`), the provider rotates its courses.
- **Sides**: `teams = n` gives `n` sides of at most `size` players, chosen by the host between
  `ceil(min / n)` and `floor(max / n)`; otherwise everyone goes in a single list of at most `size`. A
  player who joins goes to the smallest side. No bench and no bots. *Prop hunt* has no sides:
  the provider draws its hunters each round.
- **End of a room**: if the host leaves, control passes to the next member, and the last one closes it. A
  disconnect, a character change, another activity or a mission (checked every 5 s)
  takes the player out. So does `/leave`. Ten minutes without any change (`rooms.idleMs`) close the room,
  as do the provider stopping (`A.roomsForget`) and the launch itself. `rooms.maxRooms` (24)
  caps the number of rooms on the server, private ones included.
- **Launch**: host only; each member goes through `A.check` again, and a single refused member blocks
  the whole launch. You need at least two players and no empty side.
- **Action** `activities.rooms` (`create`, `join`, `leave`, `kick`, `move`, `settings`, `start`,
  `open`, `close`): input is treated as hostile, and everything is looked up on the server. A kicked player can't come back
  to that room. A private room can only be found by its code. The page spaces its actions
  260 ms apart (limit of 250 ms per type).
- **State**: `rooms` key, pushed only on change (batched over `rooms.pushMs`), to members,
  and to open menus for a public room. Labels and maps stay in `activities`.

Preview without the game: `npm run dev` then `?registered=1&dialog=rooms` (`&room=host|member|private`).
Tests: `lua tests/activity_rooms_test.lua`, `tests/rooms-model.test.ts`.

### Setting up The Crossing (in game)

The terminal positions are plausible offsets from the arrival point
(`server/config/activities.lua`, `hub.terminals`, marked `-- survey in game`). On site:
`/lightrp.survey board`, paste the line into the terminal's `position = { ... }`, and do the same for
`contracts` and `rooms` (the rooms NPC, still at its default offset), then `ensure op77_lightrp`. The safe zone can't come from the config
(these are audited records in the database): **/admin → Safe zones**, new zone centered
on the plaza (`-756.6, 777.3`), radius about 30 m, *blockShoot*, *blockMelee* and
*blockGrenades* checked, then publish.

## Dogtown, open PvP zone (`server/modules/dogtown.lua`, `server/config/dogtown.lua`, `client/core/dogtown.lua`, page `features/dogtown/`)

In the shared city (bucket 0), Dogtown is a danger zone: past the walls, anyone
carrying the **stake** can kill anyone else who carries it too, and a death costs a share of the cash
they carry — never the bank. Members of the same squad don't hurt each other. **Everywhere else, nothing
changes**: global friendly fire stays off (platform default), safe zones
stay safe (including those placed in Dogtown), missions and activities keep their buckets
and their rules. The rules are the owner's (2026-11-03); all the numbers are in
`server/config/dogtown.lua`, commented, and the guide (Johnny) quotes them from that config.

### How PvP is granted

- Global friendly fire is never turned on. Every 500 ms (`sweepMs`), each player is marked
  inside or outside (flat polygon, any height: roofs and stadium included), and
  **qualified** players get a combat scope (`Open77.combat.createScope`) in bucket 0.
  Qualified = active character, bucket 0, no activity and no mission, alive or recovering, zone
  turned on, **stake in pocket**, **and** inside the polygon or combat-tagged. A position older than
  2.5 s (`positionMaxAgeMs`) keeps the last answer.
- **Squads**: members of a `LightRP.parties` squad share a combat team
  (`Open77.combat.setTeam`, `teamBase` + the squad number): the platform refuses hits
  between them. The team follows every squad change (`onPartyChanged`); when leaving the
  scope, the player goes back to having no team, unless they moved to another bucket or an
  activity, which then manages its own. The referee also refuses hits between teammates while an
  update goes through.
- **Combat tag**: a hit between two players in the zone tags both of them for 20 s
  (`combatTagMs`), renewed on every hit. A tagged player who leaves can still be attacked until
  the tag runs out.
- The damage referee (`Open77.combat.onDamage`) only ever **refuses**: it closes the gap between
  two sweeps when one of the two no longer qualifies. Safe zones, the armament gate and
  activities refuse as before (the first refusal wins).
- Platform limits: 32 players per scope, 8 scopes per resource (`maxScopes`), 64 on
  the whole server, shared with the other resources. Beyond 32 qualified players, the
  group is split by position (west to east) and two players from different groups
  can't hurt each other.
- Requirements: the permissions `combat.scope.control`, `combat.config` (teams),
  `players.teleport` (escort) and `world.vehicles` (escort car), declared in
  `open77.lua`, and **the database** — without it, safe zones are unavailable
  and their referee refuses all PvP, and money doesn't move (`database_unavailable`).

### The stake

- You need `stake.minCash` (€$ 1,000) **in your pocket** to fight; the bank doesn't count. Below
  that, inside the zone: no PvP (you can't shoot or be hit), a notice with **the missing
  amount**, and the tile turns yellow with a countdown.
- After `stake.graceMs` (10 s), if you are still inside and still below the stake: you are teleported to the
  **nearest exit** (`exits`, points outside the polygon, flat distance; with no usable
  exit, the hospital). On foot (`dismount`), except a driver alone in their car: the
  car is placed 4 m next to them (`Open77.vehicles.setTransform`). A passenger leaves the
  vehicle to the others. A refused teleport is retried 3 s later.
- Same thing after a death: picked up inside below the stake → notice, delay, escort. Getting back
  above the stake (ATM, transfer) stops the countdown.
- The four exits shipped are **to be surveyed in game** (`-- survey in game`, estimated `z`):
  `/lightrp.dogtown survey exit [name]` prints the line (refused inside the polygon). An exit
  inside the polygon is ignored and reported at startup.

### Death, bag, bonus

- Death follows the **normal medical flow** (unconsciousness, trauma kit, transfer to the hospital,
  outside Dogtown). **No hospital bill** after a death in a Dogtown fight
  (`waiveHospitalBill`, the `dogtown` exemption in `economy_sinks.lua`): the zone has already taken its share
  and the bank stays out of the game. The waiver lasts until 15 s after getting back on your feet (at most
  30 min after the death).
- A kill counts when both players share a scope, or when the killer hit the victim
  in the last 20 seconds; the victim must be in bucket 0, and neither of them in an activity.
- **Loss**: `loot.share` (10%) of the cash carried, at least `loot.min` (€$ 100), at most
  `loot.max` (€$ 750), never more than what is carried.
- **Bag** (`loot.mode = "bag"`): a sealed bag (nothing can be put in it) drops where the victim
  fell, with the loss **plus a server bonus** of `loot.bonus` (25% of the loss): newly minted
  money (`Inv.dropCash`, `mint` option), paid by nobody. The bag is **reserved for the killer
  and their squad** for `loot.reserveMs` (15 s; the squad at pickup time), then
  anyone can take it, victim included: the killer gets first pick, after that it's
  Dogtown. It is an inventory ground pile, in memory only: lost on restart and
  after `LightRpConfig.inventory.drop.ttlMinutes`.
- **Bonus cap**: `loot.bonusDailyCap` (€$ 3,000) per **account** (all its characters) and
  per UTC day, kill bonuses and bounties included. Table `lightrp_dogtown_bonus_daily`
  (identifier, day, total), write cache reread once a day, like
  `activity_pay.lua`. The bonus counts when the bag is placed, even if someone else picks it up. Log:
  `dogtown bonus: +N minted into a cash bag for <account> (killer …, victim …)`.
- `"transfer"`: the loss goes into the killer's pocket and the bonus is paid alongside it (entry
  `dogtown_bonus`). A bag that can't be placed falls back to the transfer.

### Anti-gank, bounties

- Killer's squad with `antiGank.crewSize` (4) or more members **in the zone** (inside, or
  tagged outside; the stake is not required to count): the loss is multiplied by
  `antiGank.lossFactor` (0.5), after the minimum and the cap — the bag and its bonus shrink
  with it.
- Victim from a squad with more members in the zone than the killer's: bonus × (1 +
  `antiGank.underdogBonus`), so × 1.5, still within the cap.
- **Bounty**: `bounty.streak` (5) counted kills in a row in the zone without dying → an
  `op77_map3d` pin (`addBlip(-1, …)`, pulsing red reticle, "BOUNTY · Name") that follows the target
  every `bounty.refreshMs` (3 s) on everyone's map. Removed on death (whatever
  the cause), when leaving the zone (outside and no longer tagged: the streak ends), on
  disconnect, on character change, when the zone or the resource stops. Whoever
  takes them down (counted kill) gets `bounty.perKill` (€$ 250) per kill in the streak, at most
  `bounty.max` (€$ 1,500), **in cash** (entry `dogtown_bounty`), within their cap. Log:
  `dogtown bounty: +N to <account> (…)`.

### Anti-farm, combat logging

- **Blocked pairs**: same account (`lootSameAccount`), same squad (`lootCrewmates`), or the same
  killer on the same victim within 10 min (`pairCooldownMs`, per character and in that
  direction: a rematch is still possible). **Nothing at all**: no kill, no death, no loss, no bag, no
  bonus. Each refusal is explained to both players.
- **Combat logging** (`combatLog`): a tagged player who disconnects in the zone drops
  a death bag (same loss, **no bonus**) at their last position, reserved for their
  last attacker's squad; log `combat log by …`. Nothing if they were already downed (the kill
  counts) or died less than one tag ago. New framework hook `onDisconnecting`,
  called before `onDisconnected` while the inventory and the wallet are still loaded (it can
  wait).
- **Everything goes through `LightRP.money`**: `dogtown_loss` for the victim, `dogtown_loot` for whoever
  picks it up (the note names the bonus), `dogtown_bonus` (transfer), `dogtown_bounty`. Picking up
  your own bag stays an `inventory` entry. Shared files touched: `inventory.lua`
  (sealed piles, `mint`, `reserve`, reason `reserved`), `economy.lua` (labels),
  `economy_sinks.lua` (exemption), `framework.lua` (`onDisconnecting`). When the
  resource stops, scopes, teams, bounty pins and pending bags are removed.

### Stats, Hall of Fame

Table `lightrp_dogtown_stats` (account + character + week, week 0 holding the all-time total):
counted kills, deaths, best streak (`best_streak`, a column added by a migration at startup
on an older table), eddies picked up (positive `dogtown_loot` and `dogtown_bonus`; a
bounty is not loot). UTC weeks, starting Monday 00:00. F1 leaderboard: the top 5 killers
of the week (`stats.leaderboardSize`), reread every 60 s. **Hall of Fame**
(`halloffame.lua`, PvP tab): `dogtown.kills` (lifetime kills, with K/D and best streak) and
`dogtown.streak` (best streaks, not in the overview); `hallOfFame = false` removes them.
**No reputation.** Without a database, everything lives in memory for the session.

### What the player sees

- **At the entrance**: a red banner "DOGTOWN — NO LAW · ANYONE CAN KILL YOU", the cash carried and
  what a killer would take from it (plus the bonus); without the stake, "NO STAKE · YOU CAN'T FIGHT
  HERE" and the missing amount. A chat line (stake, cash carried) at most every 2 min
  (`entryChatMs`).
- **Top-left tile** while the player is inside or tagged: combat tag, money at stake,
  current streak, "BOUNTY · ON EVERYONE'S MAP"; without the stake, a yellow "€$ X missing" tile and
  "ESCORTED OUT IN N S".
- **F1 → Dogtown**: the rules with their numbers from the config (stake, loss, bonus and cap with the
  bonus earned today, squads, bounty, fair play), your record (week, total, best
  streak, current streak or bounty), the top killers of the week.
- **Guide (Johnny)**: the "Dogtown PvP" topic (stake, death and bag, bonus, squads, bounty,
  anti-farm, disconnecting, hospital) and the city's PvP answers follow `enabled` in the
  config, not the `/lightrp.dogtown` switch.
- **3D map (`op77_map3d`, M key) and minimap**: the zone itself, the server polygon
  laid over the ground, roads and buildings: translucent red fill with diagonal
  hatching, solid red border, a "DOGTOWN · DANGER ZONE" label readable at
  city scale; on the minimap, the line under the map shows that name while you are inside. The red
  skull stays in the center. Settings in `area` of `server/config/dogtown.lua` (colors,
  opacity, `hatch` or `solid` pattern, border thickness, label position, minimap,
  pulse; `area = false` only shows the pin). The zone follows `/lightrp.dogtown on|off`
  (removed when off) and `survey apply|reset` (redrawn for everyone); the server sends
  at most 150 points (a longer survey drops its least significant vertices first). The
  bounties add their moving pin to it.
- **Game map**: the Dogtown gate sprite (danger sign as a fallback), nothing more.
  The platform only places pins there (`Open77.blips`: sprite, title, visibility
  distance) and `Open77.map` gives neither a world-to-screen projection nor a zoom distance: no
  polygon, circle or layer is possible on the native map (checked in
  `wiki/data/api.json`).

### Staff: `/lightrp.dogtown`

ACL `command.lightrp.dogtown` (covered by `command.lightrp.*`).

| Subcommand | Effect |
|---|---|
| `status` | State, players inside (including those below the stake), tagged players, scopes, bounties, polygon source, exits, stake, loss, bonus, cap, reserve. |
| `on` · `off` | Turns the zone on or off until the next restart (`enabled` sets the default). `off` removes scopes, teams, tags, streaks and bounties. |
| `survey add` · `undo` · `clear` | Adds a point at your position (with the district the engine sees), removes the last one, clears the draft. |
| `survey list` | Writes the draft in the `polygon` format to the server log. |
| `survey apply` · `reset` | The draft becomes the zone for the session; back to the config polygon. The zone drawn on the 3D map follows. |
| `survey test` | Inside or outside here, and the engine's district. |
| `survey passage` | `{ x, y, z, heading }` line for one end of a passage. |
| `survey exit [name]` | An exit line for `exits` (outside only; stand on the road, with your back to Dogtown). |

Each client also reports the district borders the engine crosses; a disagreement
with the polygon is logged (`logDistrictMismatch`). It is a survey aid, never a
source of authorization: the server doesn't know about districts.

### Setup (in game)

The shipped polygon (30 points) is derived from the volumes of the `ep1_dogtown` district in the
`op77_map3d` data: it hugs the outside of the walls, so it is a bit wide, and each point is marked
`-- survey in game`. Walk along the walls with `/lightrp.dogtown survey add` at each corner,
`survey apply` to try it, `survey list`, then paste the lines into `polygon`. Next, survey the
exits with `survey exit` (one per gate or main road) and paste them into `exits`, then
`ensure op77_lightrp`.

**Phantom Liberty.** Dogtown belongs to the expansion, which the launcher requires. On a save
where the expansion never started, the district gates can stay closed; Open77 disables
the border teleport, but actual access still has to be checked in game. If the gates stay closed,
`passages` adds **E** points (outside → inside and back, exit refused while tagged,
entry refused without the stake), surveyed with `survey passage`.

## PvE progression: reputation tiers, difficulties, cyberware

Full proposal and owner decisions (2026-11-03): `docs/pve-progression.md`.
Tiers, names, high-end prices, PvE weights and the 500-per-day cap are approved as
proposed. In short:

- **Five tiers** of street reputation (`server/config/missions.lua`, `reputation`): I Street
  (0), II Merc (500), III Operator (1,500), IV Edgerunner (4,000), V Legend (10,000). Missions,
  the Chimera raid and gigs give 100 / 220 / 450 per difficulty; PvE activities 30 / 60 / 100
  × weight, 500 per day; PvP nothing. A "STREET CRED" notice announces each tier;
  `/missions.rep <id>` shows points, tier and the next threshold.
- **Difficulties**: Hard requires tier II, Critical tier III (`difficultyTiers`), on top of
  the "finish the previous difficulty" ladder at the same point (`requireClear`, kept). The
  check applies to a crew's leader and to a solo player, on mission boards and the
  raid, for fixer offers and for PvE activities (`activityCheck` / `activityEnter` /
  panel). **A crew member below the difficulty chosen by their leader is never refused**:
  they play the full difficulty and earn the reputation of the highest difficulty they have unlocked
  (see *Crews*).
- **Cyberware** (`server/config/cyberware.lua`, `gating`): ranks I–II open to everyone, III at
  tier II, IV at III, V at IV, V+ at V (an implant's `repTier` field wins). The server
  refuses the install before any payment; removal is still possible, an implant already installed stays active
  and `lightrp.cyberware <id> give` ignores the tier. The clinic shows locked implants
  (`REP III` badge, "Street cred" line, `LOCKED` button); the `op77_ripperdoc/web` bundle must
  be rebuilt from `ripperdoc-ui` to show them.
- **High end**: rank V — Iron Lungs Mk.2 (+80 max stamina), Adrenaline Booster Mk.2
  (+15 stamina/s), Bioplastic Blood Vessels (+3 health/s); rank V+ — Neofiber Actuators Mk.3
  (`apex` dash), Aegis Dermal Plating (+100 armor), Rara Avis (+100 max health), Zetatech Apogee
  (`apex` overdrive, 11 s).
- **Ranked PvP**: `activeInPvp` (true by default, owner's decision: cyberware stays
  active in ranked PvP). When `false`, session abilities (dash, overdrive, slam) and passive
  stats are suspended in a non-PvE activity and given back on exit (module hook
  `onActivityChanged`); durable legs and arms stay.
- **Cosmetic PvP titles**: wanted later, not built.

### Hall of Fame (`server/modules/halloffame.lua`, page `features/halloffame/`)

A real server prop (by default the arcade cabinet `electronics.arcade`, collision on) about
4 m to the left of the *The Crossing* terminal, facing the arrival point, plus an
**E** point in front of it: no ground marker, a floating trophy icon (with the distance)
and a pin on the map (`board.blip`). **ALT + click** on the prop (`open77_contextmenu`,
models with collision only) or **E** opens the
`halloffame` dialog of the Light RP page: tabs *Overview* (podiums), *PvP*, *Races*, *PvE*,
*Missions*, *Wealth*; a top-3 podium, ranks 4 to 10, and the player's row highlighted or "YOU #N"
under each board. Character names only, never an account identifier.

- Sources: `lightrp_activity_stats` (PvP / PvE wins and kills, best times on each race's
  current course), `lightrp_mission_rep` and `lightrp_mission_clears`
  (contracts, heists and the Chimera raid, ranked by difficulty), `lightrp_wallets` + the inventory
  `cash` item (wealth, turned off by `showWealth = false`). Without a database: the results of
  the session (`LightRP.activities.memoryRows`), and the page says so.
- Server cache: rebuilt every 5 min; the REFRESH button works at most once per 30 s
  per player (10 s minimum for the whole server). Opening the panel only reads the cache.
- Extension: `LightRP.hallOfFame.registerBoard(key, { tab, title, unit, provider })` (example at
  the top of the module).
- Staff: `/lightrp.halloffame place` (stand in front of the spot, facing where the screen should
  look: the panel is placed 0.8 m behind you, the E point follows, and the config line is
  shown), `where` (position, model, scale, rotation and config line), `refresh`. Paste
  the line into `server/config/halloffame.lua` (`board`).
- Choosing the prop in game (staff): `/lightrp.halloffame model` lists the numbered candidates from
  `board.models` (alias, scale, yaw offset, label; `*` = currently placed);
  `model <n|alias> [scale|-] [rotation]` replaces the prop right away (the new one first:
  a refused model leaves the old one standing; the E point, the icon and ALT + click follow) and
  keeps the choice in kvp (`halloffame.board.model`), which takes priority over `board.model` at
  startup; `model reset` goes back to the config default. The rotation is added to the line's
  offset ("-": use the line's scale). The orphan sweep recognizes all the
  candidates.
- Exclusions (`exclude` in `server/config/halloffame.lua`): staff and test characters
  appear on **no** board, including those added by `registerBoard` (a single filter
  in `HoF.refresh`, after all providers, before ranking: everyone else
  moves up). An excluded player doesn't see a "YOU #N". Rows carry the Open77 account
  (`GetPlayerIdentifier`, the same `userId` as the principals in `acl.jsonc`) and the
  character key (`<account>#<key>`).
  - Staff (`staff = true`): Light RP's own test (`LightRP.staff.isStaff`, the
    `LightRpConfig.staffPermissions` in the ACL). The ACL only answers for an online player
    (a resource can't read `acl.jsonc`): each staff account seen online is remembered
    in the resource's kvp store (`data/`, kept across restarts) and stays excluded
    while offline; a remembered account seen online again without the rights is forgotten. **Limit**: a
    staff member never seen online since this version is unknown — put their `userId` in
    `staffAccounts`. An ACL that doesn't answer (no `acl.read`) forgets nobody.
  - Tests (`tests = true`): `characters` (`<account>#<key>`), `accounts` (`<account>`, all of its
    characters), plus the list from the command `/lightrp.halloffame exclude <playerId [account]
    | account#key | account>`, `include <…>` (removes from the list; on an account, also forgets
    a remembered staff member), `excluded` (status). Kept in kvp; each change triggers a
    rebuild of the boards.

## Housing

Instanced apartments and houses, buying/renting, persistent keys, storage per
contract and admin assignment. **F1 → My homes** or `/housing` for
players; **/admin → Housing** or `/housingadmin` to create templates, capture
points and add/delete homes. SQL is required.
See the [housing guide](docs/housing.md) for the full flow and the guarantees.

## Activity HUD (`client/core/activity_hud.lua`, page `features/activityhud/`)

The shared HUD for activities (arena, race, chase, turf war…): a provider
resource describes its state, and Light RP draws it in its own design. It is a pure overlay, with no focus,
no input and no keys. Only one HUD at a time: a newer `Show` replaces the old one, whichever
resource sends it. **Client** exports (always wrap them in `pcall`; the call throws if
`op77_lightrp` is stopped):

```lua
local ok, why = exports.op77_lightrp:ActivityHudShow(hud)      -- replaces the whole state
exports.op77_lightrp:ActivityHudPush("feed", { text = "Vi took the zone", tone = "success" })
exports.op77_lightrp:ActivityHudPush("banner", { title = "FINAL LAP", text = "...", tone = "accent", durationMs = 2500 })
exports.op77_lightrp:ActivityHudPush("result", { title = "Street Race", placement = 2, subtitle = "Watson Loop",
    lines = { { label = "Time", value = "3:02.48" } }, durationMs = 9000 })
exports.op77_lightrp:ActivityHudClear()
exports.op77_lightrp:Notice({ kind = "warning", title = "NCPD Chase", body = "Crash! Engine stalled." })
```

`Notice` is the client-side notice, with the same rules as the server `notice` export (`shared/notice.lua`,
same rate limit as the HUD): it is a provider's fallback when its HUD isn't shown.

Each call returns `true` or `false, reason` (`invalid_hud`, `invalid_kind`, `invalid_payload`,
`not_owner`, `rate_limited`, `ui_unavailable`). Everything is validated and bounded on the Lua side; an
invalid field is ignored, never passed on as is.

| `hud` field | Content | Limits |
| --- | --- | --- |
| `activity` | free identifier (`race.grid`) | 48 chars, `[%w_%-.:]` |
| `title`, `subtitle` | activity name, place or mode | 48 / 80 chars, default title "Activity" |
| `phase` | `lobby` · `countdown` · `running` · `ended` | any other value → `running` |
| `timer` | `{ remainingMs, label, countUp }` | 0 to 24 h, label 16 chars |
| `countdown` | ms before the start (`countdown` phase) | ≤ 60 s; **≤ 10 is read as seconds** |
| `objective` | one line under the banner | 120 chars |
| `stats` | `{ { label, value } }` | 4 at most, 24 chars each |
| `progress` | `{ { id, label, value 0..1, tone } }` | 3 at most |
| `teams` | `{ { name, color, score, self } }` | 4 at most; `color` = `#rgb`/`#rrggbb` or a tone |
| `scoreboard` | `{ columns = {...}, rows = { { name, values, self, team } } }` | 4 columns, 16 rows, only one `self` |
| `hints` | `{ { key, label } }` | 4 at most |

- **Relative times**: `timer.remainingMs` and `countdown` are valid at the moment they are sent; the page
  counts down on its own. A `countUp` only advances in the `running` phase (a final time stays frozen). Don't
  resend the HUD every frame: on each state change is enough (30 calls/s at most).
- A `countdown` in milliseconds that drops to 10 or less would be read as seconds: send `0`.
- `countdown` missing in the `countdown` phase: "GET READY". Above 5 s, a "STARTS IN" chip;
  the last 5 seconds in big digits, then "GO".
- Tones: `accent` (yellow, reserved for the player and big moments), `danger`, `info`, `success`.
- A row's `team`: index (1..4) or the name of a team from `teams`.
- Pushes: `feed` (5 lines at most, cleared after ~5 s), `banner` (0.8 to 10 s, 3 s by default),
  `result` (title or `placement` 1..999 / short text like "DNF", 2 to 30 s, 8 s by default,
  6 lines at most).
- **Ownership**: `Push` and `Clear` are refused (`not_owner`) when the HUD on screen belongs to
  another resource. A `Clear` from the owner lets the result card and the last
  banner run out their time.
- **End of life**: the HUD disappears when the owning resource stops or restarts, and
  on a character change.

On screen: a banner at the top center (phase, title, clock, two teams on either side or
team chips below, objective), a panel on the right in place of the work order (stats, bars,
leaderboard centered on the player, shortcuts), a feed at the top right near the minimap (top
left below 1600 px), and the countdown, banners and result card in the center. During a match
(any phase except `lobby`), the hunger/thirst dials, their alert and the work order fade out
(needs are frozen in activities); health, armor, energy, chat, voice and notifications stay.
In `lobby` next to a work order, the order keeps its place and the shortcuts move up under the
banner. The HUD hides when the F1 menu or a dialog box is open.

Preview without the game: `npm run dev` then `?registered=1&activity=race` (`trial`, `arena`, `turf`,
`lobby`, `countdown`, `result`, `editor`, `demo` for a full race). Tests:
`tests/activity_hud_client_test.lua`.

## WebUI

Source in `ui/` at the project root (Vite, React 18, strict TypeScript, zustand,
lucide-react). `npm run build` type-checks, then writes `web/` (app.js, app.css, index.html,
self-hosted fonts). `npm run dev` serves the page in a browser with a mock bridge:
`?menu=1&view=vehicles&staff=1&registered=1&vehicle=1` to force a state.

The design system is ported in `ui/src/design`: `tokens.css` (kit tokens), `components/`
(Button, Panel, Badge, SectionHeader, HazardStripe, Keycap, StatusChip, VitalBar, MicIndicator,
Notification, Input, Toggle, Tabs, ListRow, Modal). No external resources: fonts and icons
are bundled, and the WebUI host only serves the resource's files.

After a server change: `ensure op77_lightrp` in the console. After a change to the
page or the client, players have to reconnect (`reload_policy "reconnect"`).
