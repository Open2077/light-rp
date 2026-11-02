# Native slot machine props

This resource preloads 13 original native models (26 CR2W mesh/entity files) and
three native textures. It contains no vanilla-path overrides or gameplay code.
The gameplay resource (`op77_lightrp`, `client/core/casino_slots.lua`) creates
the authored visual hosts with `kind="prop"`, `physics="none"`, `collision=false`,
using depot paths `open77\assets\op77_lightrp\casino_slots\<name>.ent`.
All source coordinates are metres. The client applies its common 0.65 scale;
the archive geometry itself remains unscaled. The front faces local -Y and the
lever is on the player's right (+X). Every model shares the cabinet origin
(floor centre) unless noted, so poses are placed at `{0,0,0}`.

## Models

- `slot_cabinet` (the placed base): plinth, closed body 0.92 x 0.72 x 2.52 m
  (about 0.6 x 0.47 x 1.64 m in game), chrome bezel with a 0.62 x 0.22 m reel
  window and dividers, payline marks, button deck, belly paytable panel, coin
  chute and tray, marquee artwork, neon trims, top cap, lamp base and the lever
  hub. Behind the window a dark, inward-facing reel bay (x ±0.34, y -0.36..-0.24,
  z 0.15..2.51) hides the strips everywhere but in the window.
- `slot_strip_1..3`: flat symbol strips facing -Y, 0.20 m wide, 15 entries of
  0.085 m: the last stop, the 12 stops in spin order, then the first two again.
  Entry `i` is centred at local `z=-i*0.085`; origin at entry 0. Placed at
  `{reelX, -0.33, 1.33 + j*0.085}`, entry `j` sits on the payline; `j` in
  `[1,13)` always covers the window and stays inside the bay, and `j` and `j+12`
  look identical, so a spinning strip wraps without a visible jump.
- `slot_lever_0..5`: the lever arm and red knob at 0, 17, 34, 51, 68 and 85
  degrees, pivot `{0.55,0,1.35}`, pulled towards the player. The inactive poses
  park at `{-0.14,0.16,0}`, fully inside the cabinet and outside the reel bay.
- `slot_lamp_off`, `slot_lamp_on`: top dome lamp, unlit / lit colours. The other
  one parks at `{0,0.15,-0.32}` inside the cabinet.
- `slot_coin`: a 54 mm gold coin, origin at its centre (not the cabinet origin).
  Coins park inside the cabinet at `{x,0.2,0.4}` and rest in the tray at z 0.574.

The reel order, symbols and layout are recorded in `asset-manifest.json`
(`reels`, `symbols`, `layout`) and must match
`op77_lightrp/shared/casino_slots.lua` and `client/core/casino_slots.lua`.
Artwork (symbol atlas, marquee, belly paytable) is original, drawn with Pillow;
the PNG sources are in `sources/`.

## Build and verification

Run `python3 tools/build-casino-slots-props.py --lab <dop-tests> --work <dir>`.
It imports the existing board-prop cooker as a read-only library, reads the reel
strips from the shared rules (lupa), generates geometry and artwork, deserializes
schemas, imports GLB buffers, round-trips every cooked file and packs the archive
with the local WolvenKit CLI. It then verifies the cooked files, hashes, package
index, UV ranges, that every parked pose is hidden inside the closed cabinet and
that every strip position covers the window from inside the bay.
`--verify-only` repeats the checks against an existing work directory.

Changing a preload requires a restart and a fresh game launch. Binary validation
establishes cooked data and references; materials, texture orientation and the
in-game look still require a live client check.
