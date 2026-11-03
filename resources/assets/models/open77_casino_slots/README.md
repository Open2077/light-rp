# Native slot machine props

This resource preloads 13 original native models (26 CR2W mesh/entity files),
one collider entity and nine native textures. It contains no vanilla-path
overrides or gameplay code. The gameplay resource (`op77_lightrp`,
`client/core/casino_slots.lua`) creates the authored visual hosts with
`kind="prop"`, `physics="none"`, `collision=false`, using depot paths
`open77\assets\op77_lightrp\casino_slots\<name>.ent`.
All source coordinates are metres. The client applies its common 0.65 scale;
the archive geometry itself remains unscaled. The front faces local -Y and the
lever is on the player's right (+X). Every model shares the cabinet origin
(floor centre, `floor=0`) unless noted, so poses are placed at `{0,0,0}`.

## Look

A premium Night City stepper cabinet at true proportions: 1.02 x 1.08 x 3.15 m
authored, i.e. 0.66 m wide (crown), 0.70 m deep with the button deck and 2.05 m
to the top of the candle lamp in game. It shares the casino set's material kit
(`tools/wheel_tables_art.py`: brushed gunmetal, black chrome, carbon twill,
smoked glass, dark composite) with the roulette, Fortune Wheel and blackjack
tables.

From the floor up: a dark toe recess and a brushed gunmetal kick plate; satin
black lacquer side panels with rolled black-chrome edges and raised brushed
inserts, their front edges following the topper curve; a lacquer lower door
with a chamfered belly glass (series emblem) and a lock; a chrome payout bowl
under a chute canopy; a slanted carbon button deck with a padded armrest, four
keycaps (CASH OUT, BET -, BET +, MAX BET) on black-chrome bezels and a domed
SPIN button in a chrome ring; a gunmetal band with a ticket printer and a
player-card reader (amber-lit slot, small display); a smoked-glass reel door
with a black-chrome bezel, a gold pinstripe, payline chevrons, the payline
printed on the glass and mullions between the reels; a framed paytable display
between two perforated speaker grilles; a concave attract screen recessed in a
black-chrome surround; an overhanging crown; a candle lamp. The lever is a
turned chrome rod with a gold ferrule and a weighted garnet knob on an axle
sleeve, mounted on a gunmetal hub with six bolts on the right panel.

Light is restrained and purposeful: one thin cyan line per side panel (deck to
topper), a magenta downlight under the crown lip, the spin ring, the card slot,
the payline, the screens and the backlit reels. Emissive keys use metal_base's
`Emissive` / `EmissiveEV` / `EmissiveColor`; screens and reels emit their own
artwork so dark backgrounds stay dark. The EVs live in `MATERIALS` at the top of
the build script and are recorded in `asset-manifest.json` (`emission`).

Artwork is original, drawn with Pillow in the wheel kit's stroke typeface (no
font files, no trademarks): the reel symbol atlas (printed enamel symbols on a
pearl band), the attract screen (title, tick dial, skyline linework, three
sevens), the paytable (one reel window per line, pays read from the shared
rules), the belly emblem, the deck legends / card display / spin disc, and the
perforated grille. PNG sources are in `sources/`, together with design renders
`preview_slots_{hero,player,reels,lever,base}.png` from the shared software
preview renderer (`tools/wheel_tables_preview.py`; not shipped in the archive).

## Models

- `slot_cabinet` (the placed base): a closed core x ±0.44, y -0.40..0.42,
  z 0.035..2.85 with only the reel hole in its front skin, side panels to
  x ±0.50, deck to y -0.652 (top 1.30..1.35), crown to y -0.556 and z 2.975.
  Behind the hole a dark, inward-facing reel bay (x ±0.34, y -0.40..-0.30,
  z 0.49..2.83) hides the strips everywhere but in the window
  (x ±0.31, z 1.549..1.771).
- `slot_strip_1..3`: flat symbol strips facing -Y, 0.20 m wide, 15 entries of
  0.085 m: the last stop, the 12 stops in spin order, then the first two again.
  Entry `i` is centred at local `z=-i*0.085`; origin at entry 0. Placed at
  `{reelX, -0.365, 1.66 + j*0.085}`, entry `j` sits on the payline; `j` in
  `[1,13)` always covers the window and stays inside the bay, and `j` and `j+12`
  look identical, so a spinning strip wraps without a visible jump.
- `slot_lever_0..5`: the lever at 0, 17, 34, 51, 68 and 85 degrees, pivot
  `{0.56,-0.04,1.64}`, length 0.50, pulled towards the player. The inactive
  poses park at `{-0.30,0.34,0}`, fully inside the core and behind the reel bay.
- `slot_lamp_off`, `slot_lamp_on`: candle lamp on the crown (base at
  `{0,-0.36,2.962}`), unlit / lit. The other one parks at `{0,0.40,-0.45}`
  inside the core.
- `slot_coin`: a 54 mm gold coin, origin at its centre (not the cabinet origin).
  Coins park inside the core at `{x,0.2,0.4}`, fall from the chute mouth
  `{0,-0.425,1.06}` and rest in the bowl at `{x,-0.47,0.94}` (1 mm above its
  floor).
- `slot_cabinet_collider.ent` (no mesh): one static box
  `(-0.50,-0.42,0)..(0.50,0.42,2.85)` (0.65 x 0.55 x 1.85 m in game), 0.65 scale
  baked in; the lever side (+X beyond the panel), deck, bowl and crown lip stay
  open. See `tools/COLLISION.md`.

The reel order, symbols and layout are recorded in `asset-manifest.json`
(`reels`, `symbols`, `layout`) and must match
`op77_lightrp/shared/casino_slots.lua` and `client/core/casino_slots.lua`; the
`colliders` list names the collider entity. The 3.0 remodel changed these
layout values (client adapter updated in the same commit): `paylineZ`
1.33 -> 1.66, `stripY` -0.33 -> -0.365, `leverPivot` {0.55,0,1.35} ->
{0.56,-0.04,1.64}, `leverLength` 0.45 -> 0.50, `leverPark` {-0.14,0.16,0} ->
{-0.30,0.34,0}, `lampPark` {0,0.15,-0.32} -> {0,0.40,-0.45}, `chuteY/chuteZ`
-0.37/0.73 -> -0.425/1.06, `trayY/trayZ` -0.44/0.574 -> -0.47/0.94. `pitch`,
`reelX`, `reelWidth`, `leverAngles` and `coinPark` are unchanged.

## Build and verification

Run `python3 tools/build-casino-slots-props.py --lab <dop-tests> --work <dir>`.
It imports the existing board-prop cooker as a read-only library, reads the reel
strips and pays from the shared rules (lupa), generates geometry and artwork,
deserializes schemas, imports GLB buffers, round-trips every cooked file and
packs the archive with the local WolvenKit CLI. It then verifies the cooked
files, hashes, package index, UV ranges, the emissive channels after the round
trip, the collider entity, the true-scale proportions, that every parked pose is
hidden inside the closed core, that every strip position covers the window from
inside the bay, and the z-fighting / hole checks of `tools/mesh_checks.py`: no
two material groups overlap within 1 mm in one plane (either facing; touching
faces are left out or sunk), surfaces of two materials facing the same way stay
at least 3 mm apart with the moving parts at rest, and from nine viewpoints the
first surface on every ray faces the viewer.
`--verify-only` repeats the checks against an existing work directory;
`--check-geometry` runs only the layout and geometry checks; `--preview` writes
the preview renders (texture sources are only rewritten by a cook).

Changing a preload requires a restart and a fresh game launch. Binary validation
establishes cooked data and references; materials, emissive strength, texture
orientation and the in-game look still require a live client check.
