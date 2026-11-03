# Native roulette props

This resource preloads 3 original native models (6 CR2W mesh/entity files) and
six native textures. It contains no vanilla-path overrides or gameplay code.
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

## Build and verification

Run `python3 tools/build-tabletop-extra-props.py`; override `--lab` or `--work`
as needed. It imports the existing board-prop cooker as a read-only library,
generates original geometry/artwork, deserializes schemas, imports GLB buffers,
round-trips every cooked file and packs the archive using local WolvenKit.
Only this new resource and the isolated work directory receive outputs.
The source PNGs, model dimensions, texture metadata and binary hashes are
recorded in `sources/` and `asset-manifest.json`. Textures include original wood,
felt and roulette labels; vertex colors are opaque white.
No external font binary, proprietary geometry or toolchain is packaged.

Changing a preload requires a restart and a fresh game launch. Binary validation
establishes cooked data and references; materials, texture orientation, async
creation and animation still require a live client check.
