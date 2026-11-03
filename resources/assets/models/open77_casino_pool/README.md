# Native pool props

This resource preloads 19 original native models (38 CR2W mesh/entity files),
one collider entity and six native textures for the LightRP pool table. It
contains no vanilla-path overrides or gameplay code. The gameplay resource
(`op77_lightrp/client/core/casino_pool.lua`) creates the visual props with
`kind="prop"`, `physics="none"`, `collision=false`, using depot paths
`open77\assets\op77_lightrp\casino_pool\<name>.ent`.

Every model is authored at 1/0.65 of its real size, so the client's common
0.65 prop scale shows it full size. Real dimensions come from
`op77_lightrp/shared/casino_pool.lua` (the build script reads them with lupa):
2.54 x 1.27 m between the cushion noses, 57.15 mm balls, the cloth at
`P.BED` = 0.76 m.

## Look

A Night City 9 ft table: carbon rail tops and body panels, black chrome lips,
a thin cyan light line under the rail, a magenta one round the floor plinth.
The midnight-teal cloth carries a faint hex print and a small `NC//8` emblem;
the head string, the spots and the foot spot ring glow softly (the cloth's own
emissive map). Chrome pocket irons open towards the cloth over dark liners,
18 diamond sights are tiny cyan lights, the base is a closed black chrome
spine on two tapered pedestals, and the foot end apron has a lit ball-return
channel behind a chrome frame. The cue: blue tip, chrome ferrule and joint, a
carbon shaft, a glowing magenta ring at the joint, a carbon wrap, a cyan ring
on the black chrome butt. Balls: glossy, the number on a top cap (readable
from above at any yaw: the prop API turns props about Z only), stripes as an
equatorial band, a thin glowing equator on the cue ball, a magenta ring round
the 8's number. Original art, no trademarks.

Materials are `engine\materials\metal_base.remt` instances; emission uses
`Emissive`/`EmissiveEV`/`EmissiveColor` (EVs in `MATERIALS` in the build
script, see `tools/wheel_tables_art.py`). Design renders (not shipped):
`sources/preview_pool_{hero,player,top,return,balls,cue,cue_tip}.png` and the
sheet `sources/preview_pool.png`.

## Models

- `pool_table`: origin on the floor under the centre of the cloth, +X towards
  the foot (the rack and the ball return). Rail top at `P.BED + 0.044`, outer
  edge 0.16 m beyond the noses. Pockets: corner holes centred 22 mm out on the
  diagonal (radius 60 mm), side holes 38 mm out (56 mm); the physics mouths
  (`P.CORNER`, `P.SIDE`) sit inside the drawn openings. Ball return: centres
  at `P.TRAY` (x, first y, z of the channel floor, step).
- `pool_ball_<0..15>`: origin at the ball's centre (0 = the cue ball).
- `pool_cue`: the tip at the origin on the cue's axis, the butt towards -X and
  4 degrees up, 1.47 m long.
- `pool_rack`: the triangle round 15 racked balls, origin at the apex ball's
  centre on the cloth (z=0), rows towards +X.
- `pool_table_collider.ent` (no mesh): one static box over the table body up
  to the rail, 0.65 scale baked in; the players stand all round to shoot. See
  `tools/COLLISION.md`.

Hidden props park inside the closed spine (`P.PARK`): the build asserts the
whole cue fits there.

```sh
python3 tools/build-casino-pool-props.py --lab <dop-tests lab> --work ~/.cache/casino-pool-build
python3 tools/build-casino-pool-props.py --preview-only
python3 tools/build-casino-pool-props.py --verify-only --work ~/.cache/casino-pool-build
```
