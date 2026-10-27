# Native roulette, dominoes and card-tower props

This resource preloads 47 original native models (94 CR2W mesh/entity files) and
eight native textures. It contains no vanilla-path overrides or gameplay code.
The gameplay resource creates the authored visual hosts with `kind="prop"`,
`physics="none"`, `collision=false`, using depot paths
`open77\assets\op77_lightrp\tabletop_extra\<name>.ent`.
All source coordinates are metres. The client applies its common 0.65 scale;
the archive geometry itself remains unscaled.

## Roulette

- `roulette_table`: circular wooden base, banked race, green felt and brass rim,
  radius 0.42 m. Origin is centre XY, playing datum Z=0; underside Z=-0.045.
- `roulette_wheel`: independent rotor, radius 0.32 m, with 37 colored pockets,
  accurate numbered annulus, brass dividers, turned spindle and four handles.
  Origin centre XY at Z=0. Pocket floor Z=0.016; highest spindle Z=0.114.
- `roulette_ball`: smooth white sphere, diameter 0.018 m, origin at its centre.
  Its settled centre is radius 0.27 m, Z=0.025 relative to the wheel datum.

Pocket index 0 (number 0) is centred on local +Y. Indices increase clockwise
when viewed from above. For clockwise angle `a`, a ball centre is
`{x=0.27*sin(a),y=0.27*cos(a),z=0.025}`. Native yaw uses the opposite sign.
The European order is:
`0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26`.
Numbers are baked into an original 1024² atlas with explicit mesh UVs; they are
part of the prop, not a UI overlay.

## Dominoes

`dominos_board` is a 1.0×0.75 m wooden tray with an inset woven green carpet at
Z=0.001. The origin is the centre of its top, underside Z=-0.028.
`domino_A_B`, for every `0 <= A <= B <= 6`, supplies the complete 28-tile
double-six set. Tiles are 0.026×0.052×0.008 m with bevels, a fine central inlay
and real dark pip geometry. Origins are centred XY at the base, Z=0. Half A
points towards local -Y; half B towards +Y. The long axis is Y. A native yaw of
90° lays the tile horizontally in the board's X direction.

## Card tower

`cardtower_board` is a flat 1.0×0.75 m wooden board, top Z=0, underside Z=-0.025.
`playing_card` and the explicit alias `playing_card_flat` are a 0.088 m long-X,
0.063 m wide-Y, 0.0005 m thick card, centred on XYZ=0. Front and back have
separate explicit UVs: an original ace-of-spades face and red diamond-pattern
back. These are original drawings without a commercial deck design.

The client API supports yaw rather than arbitrary prop pitch. Authored poses
therefore provide the actual tilt in the mesh:

- `playing_card_lean_left`: origin at its bottom short-edge centre; apex
  `{x=0.026,y=0,z=sqrt(0.088²-0.026²)}` = Z≈0.0840714 m.
- `playing_card_lean_right`: the mirrored slope, apex X=-0.026; origin identical.
- `playing_card_lean_left_fall_1` through `_fall_5`, and the corresponding right
  variants: slopes 58.25°, 43.69°, 29.12°, 14.56°, 0° above the horizontal.
  The initial lean is 72.81°. Every falling pose keeps the same foot origin.
  At fall 5 the centre is at local X=+0.044 for left, X=-0.044 for right.
  Switching to the centred flat alias requires this final centre offset.

A native yaw rotates the complete authored pose in the tabletop XY plane.
The server owns stability/collapse; these visual models do not simulate physics.

## Build and verification

Run `python3 tools/build-tabletop-extra-props.py`; override `--lab` or `--work`
as needed. It imports the existing board-prop cooker as a read-only library,
generates original geometry/artwork, deserializes schemas, imports GLB buffers,
round-trips every cooked file and packs the archive using local WolvenKit.
Only this new resource and the isolated work directory receive outputs.
The source PNGs, model dimensions, texture metadata and binary hashes are
recorded in `sources/` and `asset-manifest.json`. Textures include original wood,
woven felt, roulette labels and card artwork; vertex colors are opaque white.
No external font binary, proprietary geometry or toolchain is packaged.

Changing a preload requires a restart and a fresh game launch. Binary validation
establishes cooked data and references; materials, texture orientation, async
creation and animation still require a live client check.
