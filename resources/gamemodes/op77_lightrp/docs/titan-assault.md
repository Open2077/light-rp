# Titan Assault

A PvE mission for 2 to 4 pilots (one with the staff test start). The crew is dropped in the open desert of Rattlesnake
Creek (Badlands) already seated in a BT-7274 Titan, holding the fists. Nothing spawns and nothing moves until every pilot
has picked a class on the LightRP page. Then ten waves of hostiles come in from all around, and kills charge the core.

- Point `titan_assault`, type `ASSAULT`, two difficulties, both 2 to 4 pilots and 25 minutes, repeat rules of
  `server/config/economy.lua` as for any board mission:
  - `standard`: tier 1, 3 000 per head (the Chimera's Standard pay), five times the base hostiles;
  - `hard`: tier 2 (reputation), 4 500 per head, ten times the base hostiles.
- Script `server/modules/mission_titan.lua`, client `client/core/titan_mission.lua`, page
  `ui/src/features/missions/TitanMissionHud.tsx` (+ `titan.css`), tuning `LightRpTitanAssault` and the point in
  `server/config/missions.lua`.
- It builds on the Titan service `op77_lightrp_titans` (the fork of Open77's `open77_titans` in this repository). The
  service is a **soft dependency**: nothing in the manifest requires it, and the mission is on the board only while it
  runs (below). Production does not run it yet.
- Read `docs/pve-missions-and-chimera-raid.md` first: this mission follows its section 5.

## On the board only while the service runs

`mission_titan.lua` checks `GetResourceState("op77_lightrp_titans")` (running or starting) at load, on `onResourceStart`
and `onResourceStop`, and once on its first tick (the Hall of Fame loads after it):

| Service | Point | Hall of Fame board |
|---|---|---|
| running | `Missions.addPoint` (board, blip, marker) | `missions.assaults` "TITAN ASSAULT" registered |
| not running | `Missions.removePoint` | board unregistered |
| stops under a run | the run fails ("The Titan service stopped."), then the point is withdrawn | |

The point is defined in `LightRpMissions.points` like the other two (the script reads it back from there). The board
stands 5 m east-south-east of the Sector 04 Blackout board (the one board in the city), z carried over from it: a spot
to check in game. The arena is the open desert of Rattlesnake Creek, about 130 m north of the road by the abandoned fuel
station (that Badlands fast-travel terminal is at `(-1121.2, -5584.0, 92.3)`): scrub and cacti, no road, no building. The
arena centre is `(-1121, -5450, 86.2)` and the four start spots were measured in game on 2026-11-04 by standing V on each:
`(-1108, -5450, 87.0)`, `(-1121, -5436, 85.1)`, `(-1134, -5450, 86.1)`, `(-1121, -5463, 86.6)` (ground heights 86.87,
84.93, 85.97 and 86.41).

The type is new (`ASSAULT`) rather than `RAID`: the Hall of Fame's raid board is titled "CHIMERA RAID" and ranks the
`RAID` type. `server/config/halloffame.lua` `knownTypes` classifies `titan_assault` for clears whose point is gone;
`HoF.clearsProvider` (exposed by `halloffame.lua`) ranks them, and the script registers the board.
Daily contracts, titles and the iconic-implant drops stay Chimera-only (they name `chimera_raid`).

## The run

`Missions.launch` teleports the crew asynchronously and calls `onStart` while they are still travelling, so the Titans
cannot be spawned in `onStart` (the Titan service gives a Titan the owner's current bucket).

| Phase | What happens | Ends when |
|---|---|---|
| `arrive` | each client reports `op77_lightrp:titan:arrived` once its loading screen is gone and its body has stood 2 s within 80 m of the arena. The server believes it only if the player's fresh position is in the run's bucket and within 90 m of the arena, then calls `spawn(id, { xo16 = 0, railgun = 0, predator = 0, sword = 0, fist = 1 }, { piloted = true, hold = true })`. A refused call is tried again every 2 s, 5 times. | every pilot has a Titan; or 120 s, and whoever has none is told and sent home (`Missions.dismiss`); the last one out fails the run |
| `pick` | everyone held, no hostile. Each new Titan first gets the stand-by class, `setClass(id, { id = "standby", label = "BT-7274", weapon = "fist", abilities = all false, speed = 1 })`, once: the spawn's loadout does not switch the weapon, and the Titan's own default is the XO-16. The page lists the five classes (cards: label, weapon, ultimate, abilities; keys 1-5 or a click; READY or Enter). | everyone is ready, or 60 s: a pilot who picked nothing gets Vanguard |
| `starting` | each Titan gets `setClass(id, spec)`, then `setHold(id, false)`. A refused call is tried again (2 s, 8 times, then the pilot is sent home). In the happy path this takes no time at all. | every standing pilot wears its class and is free |
| `countdown` | banner "WAVE 1", 5 s | 5 s |
| `wave` n | hostiles drop in (below) | the wave is fully dead |
| `intermission` | banner "WAVE n+1", 8 s | 8 s |
| `victory` | wave 10 is dead; banner, 8 s | `Missions.complete` |
| `wipe` | every pilot is down at the same time; banner, 6 s | `Missions.fail` |

Trace of one run (the test's run A: two pilots launched from the board, everything killed as fast as the test
allows; simulated time, printed by `tests/titan_mission_test.lua`; `starting` is instant when the service answers):

```
  +   0.0s  arrive       wave 0  hostiles 0   kills 0
  +   5.5s  pick         wave 0  hostiles 0   kills 0
  +  65.5s  countdown    wave 0  hostiles 0   kills 0     (pilot 1 ready, pilot 2 timed out at 60 s: Vanguard)
  +  70.5s  wave         wave 1  hostiles 4   kills 0
  + 114.5s  intermission wave 1  hostiles 0   kills 2     (the test spends simulated time on hit admission inside this wave)
  + 122.5s  wave         wave 2  hostiles 6   kills 2
  ...
  + 212.5s  wave         wave 10 hostiles 22  kills 106
  + 216.5s  victory      wave 10 hostiles 0   kills 128
  + 224.5s  ended        (paid 3 000 each, home)
```

### Waves

`size(n, p) = 4 + 2 (n - 1) + max(0, p - 2) (1 + floor(n / 3))` with p the pilots at the wave's start (a solo test run has
no extra term), **times the difficulty's `enemyScale`: 5 on `standard`, 10 on `hard`**. The table is the base:

| Pilots | Waves 1 to 10 (base) | Total (base) |
|---|---|---|
| 1 or 2 | 4, 6, 8, 10, 12, 14, 16, 18, 20, 22 | 130 |
| 3 | 5, 7, 10, 12, 14, 17, 19, 21, 24, 26 | 155 |
| 4 | 6, 8, 12, 14, 16, 20, 22, 24, 28, 30 | 180 |

At most `maxAlive` (16) times the same scale are alive at once, 80 on `standard` and 160 on `hard`; the rest of the wave
comes in as others die. Two pilots on `standard` meet 20 hostiles in wave 1 and 110 in wave 10 (650 in the run), on `hard`
40 and 220 (1 300). The owner chose these scales on 2026-11-04 with the 25 minutes and the ten waves kept, to be tuned
again after play; nothing measured the client with that many hostiles alive.

Hostiles are the Chimera reinforcement records (`Character.max_border_guards`, `..._shotgun`, templates
`gang_valentinos_ranged_01`, `hostile_female_ranged_lab`), created `mortal`, `aiMode` native, combat group
`op77_lightrp_titan_assault`, `acquirePlayers`, `authoritativePlayerHits`, **`hitPricing = "resource"`**, and sent at the
nearest standing pilot with an attack task. The settings are a copy of `mission_chimera.lua`'s `spawnAdd`, not a shared
helper: the two differ in the group, the pricing and the placement, and nothing common is left worth touching a module
whose test passes as it is. A record the engine refuses is tried again next time; ten batches in a row without one
hostile created call the run off ("The hostiles could not be deployed.").

**Where they drop.** The server picks candidate points on a ring of 90 to 140 m around the standing pilots' centroid,
each at least 80 m (`ring.clear`, on the ground plane) from every standing pilot and every Titan of the run at its last
accepted pose (`getState(id).position`; eight draws, then the point is skipped),
and asks one pilot's client (rotating) for the ground (`op77_lightrp:titan:probe`). `Open77.world.raycast` cannot answer: it
traces the `Static` and `Dynamic` collision groups only, and the open ground of the Badlands is `Terrain`
(Open77 `client/src/api/WorldQuery.cpp`; the first live run's three probes all came back empty and buried the wave). So
the client asks the Titan resource's `ground(points, reach)` client export: the controller's own trace (its `FPF.ground`),
straight down from 40 m above to 40 m below in `Static` and in `Terrain`, four points a frame. The terrain is the ground;
a static hit up to 0.6 m above it (a slab, a flat rock) is stood on; higher (a Joshua tree, a boulder, a roof) refuses the
point; no terrain at all (the city) keeps the static ground. The server takes a height only within 40 m of the hint, for
the request in flight, from the pilot it asked. A point without ground is skipped. After 3 missing or empty answers in a
row the batch drops on the pilots' own height instead (logged), and one more empty answer repeats that. When the answer
comes back the points are checked again against where the pilots and Titans are then: one they came within 80 m of is
dropped.

**Hostiles under the ground or hanging in the air.** During a wave, every `sink.everyMs` (3 s) the server asks one pilot's
client (rotating) for the ground under `sink.max` (16) living hostiles at a time, going round all of them, with the spawn
probe's own request (`{ id, points, kind = "check", reach }`, its own id, answered through the same event; `reach` = `sink.reach`,
200 m above and under each, where the spawn probe looks 40 m). Put on its ground (`spawnLift` above, `Open77.npcs.setTransform`,
which also hands its simulation over again) and logged with its record, distance, place and age:
- one more than `sink.depth` (1.0 m) under it (the adopted bodies sat at most 0.7 m under their probed point, after a 5 m walk);
- one more than `sink.above` (4 m) over it and within `sink.still` (1 m) of where the previous check of it found it: a thrown
  body that came to rest in the air and stood up. Every full-power throw of the owner's run of 2026-11-04 ended "landed" 70 to
  140 m up (the Titan resource's carry takes a body that stops moving for landed, wherever it is); a body still in flight
  moves between two checks and is left.

Each cleared wave logs how many were measured, the deepest under and the highest over the ground, and how many were moved.
The spawn points of a live run were measured on the ground (2026-11-04: no probe failed, every adopted body within 1.1 m of
its point), yet hostiles were found 1.4 and 1.9 m under it, 12 and 50 s after they came; why is still open.

**The last hostiles are marked.** While a wave has fewer than `marks.below` (10) hostiles left, alive and still to come,
the server sends every pilot where each living one is (its own NPC position, a dead one left out) every `marks.everyMs`
(250 ms); the first list after that stops is empty. The client hangs a red Open77 arrow marker 2.6 m above each, visible
to 500 m (depth-tested: terrain hides it), moves it with each list and removes the arrows of the hostiles no longer listed,
and every arrow when the run ends.

## Classes

Sent to the Titan service as `setClass(id, spec)`, spec = `{ id, label, weapon, perks, abilities, speed, harm }` (every
ability named, `true` or `false`). The picker adds `weaponLabel`, `core` and `ultimate`.

`harm` is the run's `LightRpTitanAssault.incoming` for its difficulty (`standard` 24, `hard` 36): the damage the Titan takes
while it wears the class, as a multiple of what its controller would take. The fork's controller scales the hits a frame
gathered before turning them into points (`FPF.health`, its mission seam); the service bounds it to 0.1 .. 50 (`invalid_harm`).
`regen` is the run's `shieldRegen` (`standard` 2.5, `hard` 3): how many times slower the shield comes back, the wait after a
hit (the controller's 6 s, less with the armor perk) and the refill (2 s) both; the seam stretches them for its own call of
the health frame only; bounds 0.25 .. 10 (`invalid_regen`). At 1 and 1 a solo pilot never went down; at 5 the shield still
never let a hit through to the hull, and the owner then finished STANDARD solo with several classes at 12 (owner's play,
2026-11-04), so `incoming` was doubled the same day (the service's bound went from 20 to 50 with it). None of the values is
measured: they are the first thing to tune after play.

| id | Label | Weapon | Abilities | Perks on top of the service's defaults | Speed | Core |
|---|---|---|---|---|---|---|
| vanguard | Vanguard | xo16 | missiles, vortex, jets, core | xoammo 2, xodamage 2, xoreload 2 | 1.0 | Burst Core |
| ronin | Ronin | sword | dash, smoke, core | airdash 1, dashregen 3, dashcap 2, dashdist 2, skate 3, sworddamage 2, swordspeed 2, swordreach 2 | 1.2 | Sword Core |
| northstar | Northstar | rail | jets, flight, designator (Barrage), core | jumpgauge 1, jumpcharge 2, jumpcap 2, railcap 2, railcharge 2, raildamage 2, flight 1, designator 1 | 1.0 | Burst Core |
| legion | Legion | pred | sentry, vortex, smoke, core | sentry 1, hull 3, armor 3, blastres 3, predcap 2, predspin 2, preddamage 2 | 0.85 | Burst Core |
| brawler | Brawler | fist | jets, dash, vortex (Arc Field), core | fistdamage 2, fistarmor 2, fiststun 2, vortexthrow 2 | 1.0 | Berserker Core |

**Ultimates.** Each class's core is its ultimate, and the picker says what it does: the card's `ultimate` line (one line,
accent coloured, a flame, above the ability chips), and once under the list the rule that holds for all of them, "Ultimate (Y):
charged by 15 kills; kills while it runs do not charge it." A charge is 75 points and every hostile of the run is a grunt
worth 5 (`LightRpTitanAssault.ranks`, below), so a charge takes 15 kills.

| Class | `ultimate` |
|---|---|
| vanguard | BURST CORE · 7.5 s: unlimited ammo, the XO-16 fires 3x faster. |
| ronin | SWORD CORE · 7.5 s: swings 3x faster, +2 m reach, the Arc Wave recharges 3x faster, one more dash. |
| northstar | FLIGHT STRIKE · BT rises and fires rockets for 6 s. |
| legion | BURST CORE · 7.5 s: unlimited ammo, the Predator fires 3x faster. |
| brawler | BERSERKER CORE · 7.5 s: punches hit 3x harder and send enemies flying (bosses stand), a shockwave on every punch, half the damage taken. |

The Berserker Core's punches are `Attacks.BT7274_Fist_Core`, whose record carries `times = 3` (see "Hits and kills"): each one
is priced three fist blows. While a core burns, BT's weapon in the hologram glows (see "BT's weapon in the weapon hologram").

In the Titan's controller (the fork's seam, `FPC.missionCore`), while a class is set: the core holds one charge (`FPF.coreMax`
is the shot's cost; the mod's own ceiling of two charges chained one burst into the next); BURST CORE fires the XO-16 and the
Predator 3 times as fast (`FPC.perk.core.rate`, the mod's 1.35) with no rounds used and no reload, as the mod does; SWORD CORE
swings 3 times as fast (`FPC.sword.core.rate`, the mod's 1.3), its +2 m reach and Arc Wave as the mod has them; BERSERKER CORE
launches whoever a landed blow meets (a ragdoll and a push of 420 away from BT, 0.55 of it upwards) instead of the blow's
stagger, never a boss, its shock blast unchanged. The hostiles are created with `behavior.vehicleContactEnabled`: Open77 keeps
a platform NPC's ragdoll component under its damage barrier only for that opt-in or a carry (`NpcLedgerLife::KeepsContactRagdoll`),
and without it the launch did nothing (owner's play, 2026-11-04); a car can knock them down too. The fork's bridge leaves the
controller's ragdoll out on Open77 bodies but for the carried one and, now, the NPC the launch names (`FPF.ragdollAsked`). Kills while a core burns add nothing (the mod's own gate on a burning core,
and Flight Strike's immunity). The core fills from the server's kill credits alone: the controller's own reading of a killing
blow, a vehicle blown up or a turret broken is off in a class, so one kill is one credit. Without a class the mod's values are back. So that three times the rounds count, the Titan
resource takes up to 60 rounds a second on one NPC (`limits.npcRoundGap = 1/60`, 20 before); each pilot's `hits.perSecond`
(240) still bounds the total.

**Arc Field** (the fork's controller seam, `FPC.arcField`). A class whose weapon is the fists turns the vortex shield into an
electric field around BT (the picker shows the class's `labels.vortex`, the ability tile ARC FIELD). While V is held (the shield's
own charge: about 3.9 s up, about 3 s to refill with the default perks) it pulses every 0.4 s: an EMP burst on BT and a
spiralling wave of electric effects on four rings (4, 8, 12 and 16 m, 10 effects each, 0.06 s apart). Each pulse lands the
fists' blast (`Attacks.BT7274_Fist_Blast`, priced `blast` 25 like Berserker's shock blast) on every person within 16 m and
knocks them down electrocuted (a boss is not); it catches rounds from every side, and letting go throws them back as the
shield does. Without a class, or with another weapon, the vortex shield is the controller's own.

**Barrage** (the fork's controller seam, `FPC.barrage`). The mod's TARGET DESIGNATOR works only on foot: its key does nothing
while V drives. A class with the designator (its lock and its perk) calls rockets down with that key (G) instead, while V
pilots: the foe under the crosshair (the designator's pick, 150 m) is marked as the mod marks it (the game's tag, Flight
Strike's first pick), or with nobody there the point the guns aim at; 2 s later 8 rockets come down on it, one every 0.18 s,
from 70 m up and 25 m out round it, the first at the marked foe and the rest within 5 m of where it stands then. They fly and
blow up as Flight Strike's rockets (`Attacks.BT7274_FlightRocket` / `_FlightBlast`, priced `blast` 25 for the class ability
`flight`: a class with the designator and no Flight Strike would land unpaid ones), with a trail of their own and a second,
bigger explosion (`v_chimera_rocket_explosion`). A new call waits 16 s from the last; the tile is BARRAGE (active until the
last rocket leaves, then the wait). Without a class the key is the mod's designator. The pilot's `hits.perSecond` budget
(240) bounds what one barrage can take off a crowd.

A class may rename abilities in the picker with `labels` (`{ vortex = "Arc Field" }` for Brawler, `{ designator = "Barrage" }` for
Northstar); the picker's chip reads the label, else the ability's own name. The names on the HUD are the Titan's: its controller
turns a fists class's vortex into the ARC FIELD and a designator class's designator into the BARRAGE.

Melee and looking are never locked. The class is kept for the Titan's life and re-applied to a new Titan after a respawn.

**Keys** (the mod's Mod Settings keys, `BT7274Keys.reds`, handled in the fork's controller seam). LightRP's quick items take
the number keys, so a Burst Core key still on the mod's default `5` is moved to `Y` (checked every 2 s: a Mod Settings save
writes the stored keys back); a key the player chose is left alone. `Y` is also Flight Strike's default, and Flight Strike
spends the core: while the two share a key, a class with Flight Strike (its lock and its `flight` perk: Northstar) takes the
press as the flight strike, every other class as its core.

## HUD while piloting

The Titan's data is on LightRP's own HUD while a pilot is aboard. The Titan's page (`op77_lightrp_titans/ui/hud.html`) no longer
draws the hull, the weapon, the abilities or the core: it keeps the eject / leave notice, the carry's prompt and the control
hints (bottom right). The mod's PROTOCOLS are off in the fork (`P.protocols159 = false` in its controller seam, the owner's
decision of 2026-11-04): no lamp, no cut of the hits BT takes, no FULL LINK EMP or voice line.

`client/core/hud.lua` asks the Titan client export `hudState()` every 100 ms (only while the resource runs, under `pcall`). It
answers the table the Titan's HUD module built last (`controller/open77_titan_hud.lua`, five times a second), or `nil` when the
pilot is on foot, the controller shows no HUD (paused game, cut scene) or this client has no controller. With a table the view
carries three more fields; without one it carries none of them and the HUD is the player's own:

| View field | Content | Shown by |
|---|---|---|
| `titan` | `name`, `className`, `held`, `hull = { value, max, low, doomed, doomedText }`, `shield` (0..100), `flash` (counts BT's hits) | `PlayerVitals`: the health dial is BT's hull (the DOOMED pool when the hull is gone), the armor dial its shield; a chip `BT-7274 · VANGUARD` (plus STAND BY while held, the DOOMED sentence in its place when doomed); the hull dial flashes red on a hit. Energy, food and water stay the pilot's |
| `weapon` | with `op77_weaponhud` running: `{ active = false, externalTop }` as on foot (BT's weapon is in the hologram, below). Without it: `{ active, titan = true, hands = { { hand = "right", label, magazine, capacity, melee, reloading } } }`, no reserve | `WeaponStatus`, only in the second case: BT's weapon, `BT` for the hand letter; a melee weapon reads MELEE instead of a magazine |
| `titanKit` | `abilities`: the cells the class may use, in the Titan's order, each `{ id, name, key, state, fill, count, left, tone }`, plus any cell no class can lock (the broadsword's `spin`: SPIN SLASH on R, its three charges, a circular-arrow icon); `core = { share, state, key, need, name, ability }` (`name` and `ability` only when the core is another ability's, see below) | `TitanAbilityBar` |

`TitanAbilityBar` (`ui/src/features/hud/`) has the quick items' tiles, place and breakpoints, and is always shown while piloting:
a tile per ability (key, charges or the seconds it still needs, a charge bar, ready / active / empty, the vortex's tone) then
a CORE tile (its share with the shot's cost marked, READY as the hazard stripe, ACTIVE while the burst burns). The core tile
shows the name and the icon the Titan sends: `core.name` (absent: `Core`) and `core.ability`, the id of the ability whose icon it
takes in place of the flame (absent: `core`), so a class whose Flight Strike takes the core key (Northstar) reads FLIGHT STRIKE
with the flight icon. A held Titan dims it. `hud.lua` also sets `LightRpHud.titanActive`, which `hotbar.lua` reads: no quick-item
peek while piloting (TAB is the
Titan's shoulder key; the quick-use keys still work). The dev preview is `?titanhud=1|held|low|doomed|melee|reload|ready|active`
(`&hit=1` lands a hit every three seconds).

**BT's weapon in the weapon hologram.** `op77_weaponhud` (the standalone holographic weapon HUD, bottom left; `Hud.externalWeaponHud`
while it runs) shows the weapon of V's hand, and BT's is not one: its snapshot has nothing drawn while V pilots. So `hud.lua`
hands BT's weapon to it through the client export `exports.op77_weaponhud:setExternal(state)` (under `pcall`, and only while
`GetResourceState("op77_weaponhud")` is `running` and it announced itself), and the hologram shows it in place of the snapshot,
with the same unfold, digits, shot flicker, reload sweep and low / NO AMMO states, no reserve (`---`). LightRP's own dial stays
down: the view's `weapon` is `{ active = false, externalTop }` as for any weapon the hologram shows, so the crew frame keeps
clear of it. The state, from the Titan's `weapon` section (`id`, `name`, `melee`, `ammo`, `capacity`, `reload`):

| Titan weapon (`id`) | `key` | `name` | `class` (badge) | `type` | Shown |
|---|---|---|---|---|---|
| XO-16 (`xo16`) | `titan:xo16` | `XO-16` | `TITAN` | `RIFLE` | magazine and capacity |
| Predator Cannon (`pred`) | `titan:pred` | `PREDATOR` | `TITAN` | `CANNON` | magazine and capacity |
| Railgun (`rail`) | `titan:rail` | `RAILGUN` | `TITAN` | `CHARGE RIFLE` | magazine and capacity |
| Broadsword (`sword`) | `titan:sword` | `BROADSWORD` | `BLADE` | `SWORD` | MELEE, BLADE |
| Fists (`fist`) | `titan:fist` | `FISTS` | `BLUNT` | `FISTS` | MELEE, BLUNT |

`name` is whatever the Titan reports, so the table shows what its controller names them today; `reloading` is true while the
Titan reports a reload. A weapon the table does not know keeps `class = "TITAN"` and has no type. The melee weapons carry their
blade or blunt class instead of TITAN because the hologram's melee label reads it. While a Burst, Sword or Berserker core burns
(`hudState().core.state == "active"` and `core.ability ~= "flight"`: Northstar's FLIGHT STRIKE boosts no weapon) the state
carries `boost = true` and the hologram's readout glows (a pulsing glow on the digits, the cells and the frame, a CSS animation
on its page); it is absent otherwise, and part of the signature, so it is sent again when it flips. The state is sent when it
changes (the signature of its fields), not every 100 ms, and again when `op77_weaponhud` announces itself (it lost what it
held); a Titan without a weapon section, or the pilot leaving the Titan, sends `setExternal(nil)`, which makes the hologram
sample V's own weapon again (it folds away when nothing is drawn). `op77_weaponhud` also drops it when LightRP stops. If
`op77_weaponhud` is not running, has stood down (`enabled = false`), refuses the call or fails (an older build without the
export is asked again every 2 s only), BT's weapon is on LightRP's own dial as described in the table above.

## Hits and kills (server-authoritative)

The hostiles are `hitPricing = "resource"`: the platform prices nothing and no client relays a shot. **The pilot's own Titan
reports each blow its weapons land on a hostile** (the Titan service, `op77_lightrp_titans`): the controller resolves the
body it hit to the platform's NPC id (`Open77.npcs.all`, never a player, a car or a Titan), the service authenticates the
sender against its live Titan, id and epoch and its hit budget, and **only a Titan whose accepted frames say `pilot` and that
is not held** reports anything (`not_piloting`, `held` are counted as ignored). It raises the host event
`onTitanNpcHit(owner, titanId, npcId, info)` with `info = { record, kind, point, titan = { x, y, z }, at }` (`titan` the
Titan's latest accepted pose, the service's own; a round on one NPC is reported at most once per 50 ms). The service does
not own the NPC and never touches it: this script does. It admits a report only if, in this order:

1. the owner is a member of a running Titan Assault instance (`not_member`);
2. the phase is `wave` (`phase`);
3. the owner has a live Titan of this run (`no_titan`) and the report names it (`wrong_titan`), and the pilot is not down
   (`down`);
4. the report is a table (`invalid`) whose **attack record** is one of the Titan's own (`hits.records`, else `no_price`):
   what a blow is comes from the record, never from the report's `kind`;
5. the NPC id (a whole number, as text or number) is one of this instance's hostiles (`not_enemy`), alive (`not_alive`) and in
   the instance's bucket (`wrong_bucket`);
6. the NPC is within 150 m of `info.titan` (`too_far`; without a pose, of the owner's fresh position in the bucket, else
   `no_position`);
7. the pilot's class fires that record: the record's weapon is the class weapon (`wrong_weapon`: Legion fires no XO-16
   round) and its ability is one the class may use (`locked`: the Ronin fires no missile);
8. the blow has a price (`no_price`) and the owner's per-second token budget allows it (`budget`).

Then `Open77.npcs.applyDamage(npc, amount, "player:<owner>", "titan")`, `amount` = the **percent of the NPC's maximum health
the server's record of the owner's class weapon and the record's kind are worth** (`LightRpTitanAssault.hits`), and
`lastHit[npc] = { owner, at }` is recorded:

| Kind (from the record) | Records | Price | Hits for a 100 hp grunt |
|---|---|---|---|
| `round` | `XO16_Hit` (xo16), `Pred_Hit` (pred), `Rail_1..4` (rail) | `perHit[weapon]`: xo16 4, pred 6, rail 100 | 25, 17, 1 |
| `melee` | `Punch` (any class), `Fist`, `Fist_Heavy`, `Fist_Charged` (fist); `Fist_Core` (fist, `times = 3`) | `perHit.fist` 45; `Fist_Core` 3 times that, 135 | 3; 1 |
| `blade` | `Sword`, `Sword_Charged`, `Sword_Core`, `ArcWave` (sword) | `perHit.sword` 60 | 2 |
| `blast` | `Missile`, `MissileBlast` (missiles), `FlightRocket`, `FlightBlast` (flight), `Pound_Mid`, `Pound_Edge` (jets), `Fist_Blast` (fist) | `blast[weapon]`, 25 for every class | 4 |
| `other` | `Gas` (missiles), `Smoke` (smoke), `Vortex`, `Vortex_x2..x64` (vortex) | `other` 4 | 25 |

Records are `Attacks.BT7274_<name>`. `Eject` and the controller's fallback `Attacks.ExplosionSmall` price nothing. A record may
carry `times` (a number from 1 to 10, checked when the script loads): its price multiple, applied to the kind's price before the
per-second budget (`Fist_Core` only: the Berserker Core's punches pay three punches).
The XO-16 fires 12 to 17 rounds a second (`XO16.rate` 12, up to 1.4x with the spin-up), so 25 hits are a grunt in about two
seconds of sustained fire; the Predator (15 to 20 a second) takes about one. Budget: 240 % per pilot per second, refilled
continuously, so a burst never exceeds it. The class is the one `setClass` applied to the Titan; a report before that is
`no_class`. Nothing a client sends changes a price.

**Kills and core charge come from `onNpcDied(npcId, source, cause)` only**, for this instance's hostiles. The source
`player:<member>` (the server applied the lethal damage as that pilot) counts for that member. The source `native` is the
platform's word for a death the simulating client resolved itself, a missile's area attack: it deliberately names no
attacker, and the script never credits the simulator. It counts for the pilot whose admitted blow landed on **that same
hostile within the last 5 s** (`hits.nativeCreditSeconds`). A missile's own explosion can kill before the Titan's report of
that blast reaches the server: a native death with no such blow waits **`hits.nativeGraceSeconds` (1.5 s)**, with the
hostile's last canonical place, for the first report of a pilot of the run on that hostile that passes every check above
(range from that place, record, class, price, budget; nothing is applied to the dead hostile), and credits that pilot;
after the grace it credits nobody. Any other source credits nobody. A credited kill is counted for the member (report and
HUD) and the script calls `creditKill(member, rank)`. The rank is by what the NPC was created from
(`LightRpTitanAssault.ranks`: every hostile record is a `grunt`, and anything not listed counts as one; the controller's
grunt is 5 points, a charge 75, so a charge takes 15 kills; its rare 7 and heavy 10 are not used by this mission). A lethal hit
credits nothing by itself; a death by another hand, by a player outside the run or of an NPC that is not the run's credits
nothing. The controller adds its own values (grunt 5, rare 7, heavy 10) under its own rules (BURST CORE level 1, the core's
cap, no charge while a core burns).

Hostiles' hits on pilots take the platform's victim path (`onNpcPlayerHit`) or the legacy relay
(`op77_lightrp:titan:npcHit`): `mission_engine.lua` falls back to `LightRP.titanEnemyHit`, which checks the NPC is the
run's. **A pilot aboard takes nothing there** (`getState(id).mode == "pilot"`, refusal `aboard`): a blow on V aboard is
BT's, which the controller takes into the Titan's shield and hull (the author's `FPF.hitSeen`) when the pilot's own client
ran the hit; one another client ran is lost (see "Known gap" below). Otherwise (V on foot) it
hands over to `Engine.applyNpcHit` (member, bucket, 150 m, 40 per hit, 120 per second). Before this rule the first live
run's hostiles shot the hidden pilot's body to death through `applyNpcHit`, which removed the Titan and wiped the crew.

## Pilots going down

A pilot is down when their body dies (`onLifeState`) or their Titan is lost (`onTitanRemoved`, any reason but their own
`remove` and the service stopping). In a wave: banner, counted in `report.downs`, back after 12 s; before the first wave
after 3 s and free. The respawn is `Open77.players.respawn` at the start spot farthest from the other standing pilots,
in the run's bucket; once alive, `spawn(id, fists, { piloted = true })` (not held) then `setClass` with the same class.
**Everyone down at the same time is a wipe**: the hostiles are cleared and the run fails after 6 s. A pilot who leaves
(`/mission leave`, disconnect) loses their Titan; the run goes on without them.

## End

`onEnd`: `setHold(id, false)` and `remove(id)` for every Titan, every hostile removed, every client told
(`phase = "ended"`, `result`). `inst.report = { waves, kills, downs, operators, killsBy }` (`waves`: cleared, `operators`: at
the countdown, `killsBy`: kills per member id). The run sets `inst.loadout = true`: the armament stands aside for the run
(the Titans' weapons are not the character's) and the character's own weapons come back after it.

## Staff test start

`/titan.assault [playerId] [difficulty]` (restricted): launches the assault for that player (the caller by default; the
console needs an id) **and their crew**, on `standard` unless a difficulty id is given (`hard`; any case), through
`Missions.launchNow`: no board, the crew minimum waived, the run marked `test` (no pay,
nothing unlocked, not on the clears). It refuses while the service is not running, for a crew of more than 4, and when a
pilot is already on a mission or not in the city (launchNow's own words). The command needs the `command.titan.assault`
permission: `acl.jsonc` is not changed here (the other mission staff commands, `/missions.launch` and `/raid.skip`, have no grant
in it either).

## Network

| Event | Direction | Payload |
|---|---|---|
| `op77_lightrp:titan` | server to member | the state (phase, operators, class and ready flags, `classes` in the pick, timers, wave, hostiles, kills, `enemyIds` for the relay filter) + `announce`; `phase = "ended"` with `result` at the end |
| `op77_lightrp:titan:hello` | client to server | on resource start, asks for the state |
| `op77_lightrp:titan:arrived` | client to server | none (position and bucket checked) |
| `onTitanNpcHit` (host event) | Titan service to this script | `owner, titanId, npcId, info`, see above (replaces the old client relay `op77_lightrp:titan:hit`, removed) |
| `op77_lightrp:titan:npcHit` | client to server | `victim, npc, epoch, amount` (legacy relay of a hostile's hit on a pilot) |
| `op77_lightrp:titan:probe` | server to one pilot | `{ id, points = { { x, y, z } ... } }` |
| `op77_lightrp:titan:ground` | client to server | `requestId, indices, heights` |
| `op77_lightrp:titan:marks` | server to every pilot | `{ { id, x, y, z } ... }`, the living hostiles by id; `{}` takes the arrows down |
| page action `titan.class` / `titan.ready` | page to server | `{ id }` of a class / none |
| page event `lightrp:ui:titan` | client to page | the state without `enemyIds` |

## What the script needs from the Titan service

Server exports (`exports.op77_lightrp_titans:<name>`), each answering a value or `nil` / `false` and a reason:
`spawn(playerId, overrides, { piloted, hold })` (Titan id), `setHold(playerId, held)`, `setClass(playerId, spec)`,
`creditKill(playerId, rank)`, `getState(playerId)` (its `mode`), `remove(playerId)` (a Titan already gone is fine).
Events: `onTitanCreated(owner, id)`, `onTitanNpcHit(owner, titanId, npcId, info)` and `onTitanRemoved(owner, id, reason)`.
The service removes a Titan on its owner's bucket change, death, disconnect and resource stop. Client exports:
`ground(points, reach)`, up to 32 points, each answered `{ static = z | false, terrain = z | false }`, or `nil` and
`controller_unavailable` when the Titan controller does not run on that client; and `hudState()`, the table above, or `nil`.

## Tests

- `tests/titan_mission_test.lua`: the board and Hall of Fame board following the service; arrival (report from outside the
  bucket and from far away ignored), the held spawn with retries; the picker (bad picks, ready needs a pick, change before
  ready, the 60 s default); class spec and release order; waves for 2, 3 and 4 pilots with the alive cap (at scale 1); the
  difficulties and their scales on the waves and the cap; the ring clear of every pilot, drawn and again at the answer; the
  ground probe (wrong prober, wrong request, absurd heights, timeout, fallback); every report refusal (not member, wrong phase, no or
  another Titan, a pilot down, not an enemy, dead NPC, other bucket, out of range, no price, budget), pricing by class and
  kind (a `Fist_Core` blow priced three fist blows, still inside the budget), the applied source and cause, the NPC id as text
  or number; the picker's cards carrying each class's `ultimate`; kills and core credit from `onNpcDied` (`player:<id>`, always
  a grunt; `native` only after a recent admitted blow on that NPC, never for the simulator, never after 5 s; no credit otherwise);
  respawn with the class; wipe; victory and payout; the staff start and its difficulty; a pilot sent home; the service
  stopping; no hostile creatable.
- The fork's `tests/controller.test.lua`: Burst Core's key moved from 5 to Y (and a chosen key left alone), and the shared Y
  key going to the flight strike or the core by class.
- `tests/titan_mission_client_test.lua`: the arrival report, no relay of the pilot's own shots, the hostile-on-pilot relay,
  the ground probe.
- `tests/titan_hud_test.lua`: the Titan over the HUD sample (`view.titan`, BT's weapon and melee hand, the allowed cells and the
  core, mangled and missing sections, the on-foot fallback, a missing, stopped or failing resource), BT's weapon handed to
  `op77_weaponhud` (`setExternal`: each weapon's badge and type, `boost` while a Burst, Sword or Berserker core burns and not
  for the flight strike, sent on change only, cleared on leaving or without a weapon section, the page's dial down meanwhile,
  back on the dial when the hologram is stopped, has stood down, refuses or fails)
  and the hotbar standing down while piloting. The fork's `tests/client.test.lua` holds the export's own contract (the table
  the HUD module built last, `nil` when not piloting or without a controller). `op77_weaponhud`'s own
  `tests/weaponhud_test.lua` runs the real `hud.lua` against its client: BT's weapon through the hologram's show / data /
  hide flow, its shots, melee, `boost` through to the page's data, the clear and the owner's stop.
- `tests/halloffame_test.lua`: `HoF.clearsProvider` and the ASSAULT type.
- Suites around it: `raid_test`, `missions_test`, `mission_pay_test`, `dailies_flow_missions_test`, `titles_test`, `guide_test`.
- Run with `tests/run-lua.ps1 -Test <file>` (needs a `lua54.dll` next to the server; there is none in the repository), or
  from `resources/gamemodes/op77_lightrp` with Python's `lupa` (`from lupa.lua54 import LuaRuntime`, `loadfile("tests/<file>")()`).

## Live checks

Confirmed on 2026-11-04, one pilot (`/titan.assault`, local server, Rattlesnake Creek):

- The arrival, the held spawn seated in BT, the stand-by class (the fists, no ability shown), the 60 s default to Vanguard,
  the release and the countdown.
- The damage path: the controller's `npc_hit` reports (XO-16, missiles) are admitted and priced, hostiles die, and kills
  and core charge are credited (wave 1: 4 kills, core 14 %; wave 3: 10 kills, core 38 %).
- The hostiles target the seated pilot, and the pilot's own health stays at 100 through wave 7 (after the `aboard` rule;
  before it, V was shot dead and the crew wiped). BT's shield was seen once at 98 % in wave 2; nothing counts the blows
  BT takes, so how much of the hostiles' fire reaches it is not measured.
- Hostiles under the ground (2026-11-04 18:40-18:42, STANDARD): wave 1 measured the ground under 339 living hostiles, the
  deepest 0.09 m under it; in wave 2 one (`gang_valentinos_ranged_01`) was 1.9 m under the ground at (-1217, -5506) 50 s after it
  came, and was put back. When it got there is unknown: no earlier reading of that one hostile was logged (the wave 1 summary
  is of other hostiles, and the checks take at most 16 of the living ones each). Why is still open.
- NPC throws (Brawler, same run): 16 grabbed and thrown, no crash (the fork's `FPF.later` queue in place of `DelayEvent`).
- The ground probe through the Titan's export: requested heights follow the terrain (84.2 to 90.8 m), and the bodies the
  engine adopted 5 m later stand 0.2 to 0.6 m below them. Before it, all three probes of a wave came back empty and the
  wave was buried at the pilots' height.

Still to check:

- **Known gap, by reading the code**: a blow reaches BT only on the client whose game ran the hit (Open77's
  `DamageSystem.ProcessPipeline` wrap in `Open77TitanEvents.reds` queues it for that client's own controller; the
  hostiles' native damage on players is withheld by `authoritativePlayerHits`). A hostile another pilot's client
  simulates therefore never hurts this pilot's BT, and the `aboard` rule drops its report. Closing it needs a Titan
  service call that applies a number of points to BT (the `hit` export prices only records that carry a share of health,
  `FPF.bossShare`), dispatched from `titanEnemyHit` when the reporting authority is not the victim.
- More than one pilot otherwise: the native-death credit of a missile kill on an NPC the shooter does not simulate, the
  wave ring around several pilots, and a wipe with two crews down.
- The controller's slice: from wave 4 (10+ hostiles) its frame parts hit Open77's script time limit about once every few
  seconds (`... budget exceeded (time limit)` in the client log); nothing visibly broke.
- Whether a missile's native death ever beats the Titan's `blast` report by more than the 1.5 s grace.
- Disembarking during a wave: V on foot takes the hostiles' damage through `applyNpcHit`; nothing above proves it.
- The board position (z carried over from the Sector 04 board) and the four start spots' headings (all 0).
- `inst.loadout = true` hands the weapon slots to the script for the run; check the weapon wheel and a clean return of the
  character's weapons.
- The native "Action impossible" message shown on firing: cause unconfirmed (probably a LightRP control claim on `Attack`);
  it has not blocked a shot so far.
- The Titan HUD on the live client: the ability bar's keys (`core.key` is empty when the control hints are off), the bar and
  the vitals against the minimap, the voice plate and the crew frame at 1080p and below, TAB while piloting (the weapon wheel
  shares it), the hit flash and the DOOMED sentence, and the Titan's page with only its notice, prompt, lamps and hints.
