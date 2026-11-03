# Native roulette props

This resource preloads 3 original native models plus one collider entity
(7 CR2W entity/mesh files) and six native textures. It contains no
vanilla-path overrides or gameplay code. The gameplay resource creates the
visual hosts with `kind="prop"`, `physics="none"`, `collision=false`, using
depot paths `open77\assets\op77_lightrp\tabletop_extra\<name>.ent`.
All source coordinates are metres. The client applies its common 0.65 scale;
the archive geometry itself remains unscaled.

Style: Night City high-roller casino. Gunmetal and black-chrome bodies, a
smoked-glass ball track, carbon weave, a dark textured composite instead of
felt, thin neon accents (a cyan rim ring and table line, a magenta underglow)
and etched numerals in an original stroke typeface drawn with Pillow.

## Roulette

- `roulette_table`: a full casino table. Origin is the wheel centre XY at the
  wheel datum Z=0 (unchanged). The wheel bowl (inner wall R=0.326, chrome
  deflector apron, ball track from R=0.372 Z=0.051 to R=0.400 Z=0.063, back
  wall R=0.403, rim Z=0.091 with a cyan inlay, outer R=0.45) sits in a table
  top at Z=0.020 that runs from X=-0.56 (round wheel end) to X=2.10, Y=+-0.56.
  The printed layout spans X 0.555..1.905, Y -0.265..0.265 at Z=0.0215
  (players on -Y, zero next to the wheel), the chip rack X 0.62..1.22,
  Y 0.30..0.44. Rail cushion, slab, carbon skirt, a waisted gunmetal pedestal
  and a plinth reach the floor at Z=-1.23 (0.80 m in game).
- `roulette_wheel`: independent rotor, radius 0.325 m: 37 coloured pockets
  (floor Z=0.0095, R 0.245..0.292) with chrome frets, the number ring
  (R 0.292..0.322, Z=0.030, an unwrapped strip texture), a brushed cone with
  turbine ribs and a gold hairline, and a chrome turret (four arms, tip
  Z=0.1835). Origin centre XY at Z=0.
- `roulette_ball`: pearl sphere, radius 0.015 m (was 0.009; about 2 cm in
  game), faintly emissive so it reads in a dark room. Origin at its centre.
  Settled centre: radius 0.27 m, Z=0.025 (unchanged). On the track: radius
  0.388 m, Z=0.074 (against the back wall).
- `roulette_table_collider`: mesh-less collider entity (two static boxes, the
  slab and pedestal footprint from the floor to Z=0.10), built by
  `tools/collision_props.py`; see `tools/COLLISION.md`.

Pocket index 0 (number 0) is centred on local +Y. Indices increase clockwise
when viewed from above. For clockwise angle `a`, a ball centre is
`{x=r*sin(a),y=r*cos(a),z}`. Native yaw uses the opposite sign.
The European order is:
`0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26`.
The client's ball path (`client/core/tabletop_extra.lua`, `PATH_R`/`PATH_Z`)
follows these surfaces: track, apron, number ring, pocket.

Textures (all original, `sources/*.png`, cooked flipped vertically, FLIP_V):
`roulette_layout` 2048x1024 and its emission mask `roulette_layout_glow`,
`roulette_ring` (4096x128 number strip, also its own emission mask), and the
tiling `brushed`, `carbon` and `composite`. Emission uses the native
`metal_base` parameters `Emissive`/`EmissiveEV`/`EmissiveColor`; the EV values
are in `tools/wheel_tables_art.py` (`EV`) and recorded in the manifest.

## Build and verification

`python3 tools/build-tabletop-extra-props.py --lab <dop-tests> --work <dir>`
imports `tools/build-board-game-props.py` as a read-only library and
`tools/wheel_tables_art.py` for the art kit, checks the authored geometry
(pocket colours, ball clearances, track contact), renders the preview images,
deserializes schemas, imports GLB buffers, round-trips every cooked file, packs
the archive and finishes with `verify` (bindings, UVs, emission parameters,
collider entity, texture bytes, hashes). `--preview-only` only renders
`sources/preview_roulette*.png` (offline numpy renderer
`tools/wheel_tables_preview.py`, an approximation of the engine look);
`--verify-only` re-checks an existing work directory.

Changing a preload requires a restart and a fresh game launch. Binary
validation establishes cooked data and references; the emissive look,
materials, texture orientation and the collider still require a live client
check.
