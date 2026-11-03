# Native Fortune Wheel props

This resource preloads 42 original native models plus one collider entity
(85 CR2W mesh/entity files) and ten native textures for the `fortune` casino
table of `op77_lightrp`. It contains no vanilla-path overrides or gameplay
code. The gameplay resource creates the props with `kind="prop"`,
`physics="none"`, `collision=false` from
`open77\assets\op77_lightrp\casino_fortune\<name>.ent`. Coordinates are
unscaled metres; the client applies its common 0.65 scale. Board-local -Y is
the player side, +Z is up. Every coordinate the client uses is unchanged by
the Night City restyle.

## Models

- `fortune_stand`: the placed base. Floor plinth with a magenta underglow; a
  waisted gunmetal betting counter (rail cushion, black-chrome slab with a cyan
  line, composite top, felt artwork at Z=1.252 with seven betting tiles at
  X=-0.6..0.6 step 0.2, Y=-0.68); a tapered tower with chrome fins; the drum
  centred at (0, *, 2.15): a closed cavity (R=0.70, back Y=0.25) where the
  inactive poses park, the inward lip at R=0.665, a black-chrome bezel with 52
  warm lamps (the illuminated rim) and a cyan ring, outer R=0.82, carbon back;
  the static chrome hub cap, the flapper bracket and a smoked-glass marquee.
- `fortune_disc_00` .. `fortune_disc_26`: rotor pose meshes, origin at the hub,
  face in the local XZ plane at Y=0 facing -Y, radius 0.66, 54 chrome pegs on
  the segment boundaries (R=0.625, standing out to Y=-0.06). Pose `p` is the
  face turned `p` segments (6.667 degrees each) clockwise as seen from the
  front. The artwork has two-fold symmetry, so pose `r % 27` shows rotation
  `r`, and segment `(-r) mod 54` sits under the flapper.
- `fortune_blur_0`, `fortune_blur_1`: radial-blur rotors for high speed (the
  second is turned 1.5 segments so alternating them shimmers).
- `fortune_flapper_0..3`: satin-steel flapper with a gold tip and a cyan
  inlay, turned -6, 0, 4.5 and 9 degrees about its hinge (origin); positive
  swings the tip toward +X. Hinge at (0, 0.042, 2.89) board-local.
- `fortune_eye`, `fortune_star`: rotation-invariant 40x medallions (radius
  0.026, front face at Y=-0.006, chrome bezel) that orbit at R=0.42 in front of
  the rotor.
- `fortune_chips_1..6`: chip stacks of 1, 2, 3, 5, 8 and 12 striped chips,
  origin at the stack's bottom centre.
- `fortune_stand_collider`: mesh-less collider entity (three static boxes:
  counter, tower, drum; the space in front of the counter stays free), built by
  `tools/collision_props.py`; see `tools/COLLISION.md`.

Artwork is original (`sources/*.png`), drawn with Pillow and an original
stroke typeface (`tools/wheel_tables_art.py`), mapped with explicit UVs and
cooked flipped vertically (FLIP_V). The rotor face uses a 1024x2048 half
texture (segments 27..53 reuse 0..26 through the half-turn symmetry) with a
512x1024 emission mask; the felt has its own mask; the marquee, medallions and
blur discs are their own emission masks. `brushed`, `carbon` and `composite`
tile. Emission uses the native `metal_base` parameters
`Emissive`/`EmissiveEV`/`EmissiveColor`; EV values live in `EV` of the art kit
and in the manifest.

## Build and verification

`python3 tools/build-casino-fortune-props.py --lab <dop-tests> --work <dir>`
imports `tools/build-board-game-props.py` as a read-only library, generates the
geometry and artwork, checks the authored poses (top segment, pegs either side
of the flapper, flapper direction, parked poses inside the cavity), renders
`sources/preview_fortune*.png` (`tools/wheel_tables_preview.py`, an offline
approximation of the engine look), deserializes schemas, imports GLB buffers,
round-trips every cooked file, packs the archive and finishes with `verify`
(bindings, UVs, emission parameters, collider entity, texture bytes, hashes).
`--preview-only` only renders; `--verify-only` re-checks an existing work
directory. Dimensions, texture metadata and hashes are recorded in
`asset-manifest.json`.

Changing a preload requires a restart and a fresh game launch. Binary checks
establish cooked data and references; the emissive look, materials, texture
orientation, the collider and the animation still require a live client check.
