# Native Fortune Wheel props

This resource preloads 42 original native models (84 CR2W mesh/entity files)
and nine native textures for the `fortune` casino table of `op77_lightrp`. It
contains no vanilla-path overrides or gameplay code. The gameplay resource
creates the props with `kind="prop"`, `physics="none"`, `collision=false`
from `open77\assets\op77_lightrp\casino_fortune\<name>.ent`. Coordinates are
unscaled metres; the client applies its common 0.65 scale. Board-local -Y is
the player side, +Z is up.

## Models

- `fortune_stand`: the placed base. Floor plinth, betting table (felt top at
  Z=1.252, seven betting spots at X=-0.6..0.6 step 0.2, Y=-0.68), wheel
  pedestal, drum housing centred at (0, *, 2.15) with an inward lip at
  R=0.665, marquee bulbs, static chrome hub cap, flapper bracket and sign.
- `fortune_disc_00` .. `fortune_disc_26`: rotor pose meshes, origin at the hub,
  face in the local XZ plane at Y=0 facing -Y, radius 0.66, 54 chrome pegs on
  the segment boundaries (R=0.625, standing out to Y=-0.06). Pose `p` is the
  face turned `p` segments (6.667 degrees each) clockwise as seen from the
  front. The artwork has two-fold symmetry, so pose `r % 27` shows rotation
  `r`, and segment `(-r) mod 54` sits under the flapper.
- `fortune_blur_0`, `fortune_blur_1`: radial-blur rotors for high speed (the
  second is turned 1.5 segments so alternating them shimmers).
- `fortune_flapper_0..3`: leather flapper turned -6, 0, 4.5 and 9 degrees about
  its hinge (origin); positive swings the tip toward +X. Hinge at
  (0, 0.042, 2.89) board-local.
- `fortune_eye`, `fortune_star`: rotation-invariant 40x medallions (radius
  0.026, front face at Y=-0.006) that orbit at R=0.42 in front of the rotor.
- `fortune_chips_1..6`: chip stacks of 1, 2, 3, 5, 8 and 12 chips, origin at
  the stack's bottom centre.

Rotor, blur, felt, marquee and medallion artwork are original Pillow drawings
(`sources/*.png`) mapped with explicit UVs. The rotor face uses a 1024x2048
half texture: segments 27..53 reuse 0..26 through the half-turn symmetry.
Wood textures come from the board-game cooker. Vertex colours are opaque white.

## Build and verification

`python3 tools/build-casino-fortune-props.py --lab <dop-tests> --work <dir>`
imports `tools/build-board-game-props.py` as a read-only library, generates the
geometry and artwork, checks the authored poses (top segment, pegs either side
of the flapper, flapper direction), deserializes schemas, imports GLB buffers,
round-trips every cooked file, packs the archive and finishes with `verify`.
`--verify-only` re-checks an existing work directory. Dimensions, texture
metadata and hashes are recorded in `asset-manifest.json`.

Changing a preload requires a restart and a fresh game launch. Binary checks
establish cooked data and references; materials, texture orientation and the
look of the animation still require a live client check.
