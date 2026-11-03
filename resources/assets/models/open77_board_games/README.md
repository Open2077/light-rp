# Native tabletop props

This data-only resource preloads original cooked RED4 `.mesh` assets and `.ent`
visual hosts for chess, checkers and Connect Four: 21 models (three boards,
twelve chess pieces, four checker pieces, two Connect Four discs), seven
textures and three mesh-less collider entities. The ZIP contains exactly one
archive, `archive/pc/mod/0_open77_board_games.archive`, with 52 namespaced CR2W
files (42 mesh/entity files, 7 `.xbm` textures, 3 collider `.ent`). No vanilla
path, engine executable, gameplay script, font, logo or donor geometry is shipped.

The depot namespace is the gameplay resource's namespace:
`open77\assets\op77_lightrp\board_games\<name>.ent` and `.mesh`.
Use the authored `.ent` as `model`, `kind="prop"`, `physics="none"`,
`collision=false` in `Open77.props.create`. The visual host is a plain
`entEntity` with one `entMeshComponent`.

## Art direction (version 2.0.0)

Night City high-end, all original and generated from code
(`tools/board-game-art.py`):

- **Boards**: carbon-weave frame top with chrome 45-degree bevels, a brushed
  gunmetal side with an inlaid neon groove and a recessed foot. The field is a
  grid of raised lacquer tiles (2 mm bevels down to an etched neon grid with
  bright nodes): smoked gunmetal light squares, deep blue-black dark squares
  with a faint "holographic" inner outline. A neon channel rings the field
  (chess: cyan, checkers: amber). Home-side chevrons: cyan on White's edge
  (+Y), magenta on Black's (-Y). Square colours keep the game's parity (dark
  when row+col is odd). No coordinates are printed: the layout is abstract.
- **Chess**: White = pearl lacquer with chrome trim and cyan accents; Black =
  onyx composite with gunmetal trim and magenta accents. Every piece stands on
  a machined puck with a chrome chamfer and a neon groove. Pawn: drone head with
  a neon equator. Rook: octagonal tower, castellated crown, neon floor showing
  through the crenels. Knight: lofted squircle neck and head, chrome crest,
  swept ears, neon visor. Bishop: tall ovoid mitre pierced by a tilted neon
  slash. Queen: flared cup with eight chrome tines and an orb. King: tallest,
  banded crown and a chamfered chrome cross with neon inlay.
- **Checkers**: thick machined discs (chrome chamfers, glowing side groove,
  neon inlay ring, shallow dish). Kings are a double stack with a raised neon
  crown emblem.
- **Connect Four**: two brushed-gunmetal grid plates with chrome-lipped
  apertures, a thin cyan ring and rivets, column chevrons on top and amber
  safety hatching below, an open top slot, pillars with neon strips, chrome
  caps and feet. Discs are red (White side) and yellow (Black side) machined
  discs with chrome chamfers and a bright inlay ring on both faces.

There is no guaranteed emissive shader, so the "neon" parts are bright,
saturated nonmetal paint and the glow is faked with texture bands and bevel
highlights. All materials use `engine\materials\metal_base.remt`
(BaseColor, BaseColorScale, RoughnessScale, MetalnessScale), either with a pack
texture or `engine\textures\editor\white.xbm` and a colour scale. The material
table is in `tools/board-game-art.py` and copied into `asset-manifest.json`.

## Conventions the client relies on

Unchanged from earlier versions: chess/checkers squares span ±0.5 m with a
1.12 m outer frame, bottom at Z=-0.036 (frame top Z=0.0115, tile tops
Z=0.0035; the client puts pieces at Z=0.004). Piece origins are the centre of
the base; knights look towards +Y. Connect Four is vertical in XZ with its front
towards -Y; slot centres are `x=(column-4)*0.14`, `z=(6.5-row)*0.14+0.04`,
`y=0`; discs are 0.104 m wide and 0.027 m thick and slide between the plates.
The runtime applies a uniform 0.65 scale; cooked units are unscaled metres.

Piece heights (metres before scale) are recorded in the manifest
(`pieceHeights`) and must equal `PIECE_HEIGHTS` in
`client/core/board_games.lua`, which sizes the crosshair picking boxes:
pawn 0.086, rook 0.097, knight 0.114, bishop 0.124, queen 0.139, king 0.152.
Checker men are 0.015 and kings 0.032 high (the client's inline values).

## Textures

`cy_chess_top`, `cy_checkers_top`, `cy_connect4_face` (1024²) and `cy_pearl`,
`cy_onyx`, `cy_brushed`, `cy_carbon` (256²), RGBA with full mip chains, cooked
as gamma `.xbm`. The upright source PNGs are written to `sources/`; the cooked
bytes are flipped vertically (`FLIP_V`, the engine samples rows bottom-up).
Board tops use planar UVs over x, y in [-0.56, 0.56] with +Y at the top of the
image; lathed pieces use cylindrical UVs; Connect Four plates map x in
[-0.56, 0.56], z in [-0.08, 1.04].

## Colliders

`chess_board_collider.ent`, `checkers_board_collider.ent` and
`connect4_board_collider.ent` each hold one static `entColliderComponent`
(World Static) built with `tools/collision_props.py`, scale 0.65 baked in. The
boxes (board-local metres, before scale) are in the manifest's `colliders`:
the board footprint for chess/checkers, the upright frame plus both feet for
Connect Four. See `tools/COLLISION.md` for how the client creates them.

## Building

```sh
python3 tools/build-board-game-props.py --lab <dop-tests lab> --work <build dir>
python3 tools/test-board-game-props.py --build <build dir>
python3 resources/assets/models/open77_board_games/sources/preview.py
```

The build needs WolvenKit 9.1 CLI and .NET from the lab, plus NumPy and Pillow.
It starts from a clean `--work` tree, cooks every model, texture and collider,
round-trips all CR2W files to JSON, packs the archive and ends with the same
checks as the test (package hashes, archive index, material values, texture
mips and FLIP_V against the sources, collider structures, piece heights against
the client). `asset-manifest.json` records model bounds, triangle counts,
materials, cooked file hashes and package hashes.

Triangle budget: pieces 1,000-2,400 triangles, boards 840 (chess) and 1,200
(checkers), the Connect Four frame 19,700 and each disc 1,280. A full chess set
(33 props) is about 62,000 triangles, a full checkers board 43,000 and a full
Connect Four grid 73,000. Every material chunk stays under 16-bit vertex indices.

`sources/cyber-*-preview.png` are offline renders by `sources/preview.py`, a
small NumPy rasterizer using the shipped faces, UVs, smooth-normal rule,
textures and material values under a dim bar-like light rig (key light with
shadows, cyan/magenta rims, no emissive term). They are review images, not
in-game captures.

An updated preload requires a server restart and a fresh game launch. Offline
checks establish the cooked archive and references; actual lighting, material
response, asynchronous prop creation and the colliders still need an in-game test.
