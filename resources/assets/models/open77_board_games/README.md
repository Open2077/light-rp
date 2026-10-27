# Native tabletop props

This data-only resource preloads original cooked RED4 `.mesh` assets and `.ent`
visual hosts. It includes 21 models: three boards, twelve chess pieces, four
checker pieces and two Connect Four discs. The ZIP contains exactly one archive,
`archive/pc/mod/0_open77_board_games.archive`, with 46 namespaced CR2W files (42 mesh/entity files and four textures).
No vanilla path, engine executable, gameplay script, or donor geometry is shipped.

The depot namespace is intentionally the gameplay resource's namespace:
`open77\assets\op77_lightrp\board_games\<name>.ent` and `.mesh`.
Use the authored `.ent` as `model`, `kind="prop"`, `physics="none"`,
`collision=false` in `Open77.props.create`. Open77 build 156 supports raw entity
paths directly; no alias registration or native client patch is needed.
The visual host is a plain `entEntity` with one `entMeshComponent`.

All coordinates match the tabletop game's previous geometry: chess and checker
boards span ±0.5 m playable space, with a 1.12 m frame. Piece origins are the
centre of their base. Connect Four is vertical in XZ with its front towards -Y;
slot centres are `x=(column-4)*0.14`, `z=(6.5-row)*0.14+0.04`, `y=0`.
Its frame has front and back surfaces and fully lined 24-sided apertures.
Round pieces use 24 radial segments with crease-preserving smooth normals.
The carved silhouettes include turned bases, spherical pawn heads, a beveled
horse profile with correct concave cap triangulation, a seven-point queen crown,
a tall king cross and grooved checker rims. Chess and checker pieces use nearly
white ivory-stained wood and near-black ebony wood, without gold accents.

Version 1.1.0 includes four original procedural wood-grain textures, each 256²
RGBA with nine mip levels, cooked as native `.xbm` files. Their editable PNG
sources are in `sources/`: `wood_ivory`, `wood_ebony`, `wood_natural`, and
`wood_grain`. Materials reference these shipped textures through the inspected
engine `metal_base.remt`, with metalness zero and roughness 0.67. Boards use warm
light/dark wood, and Connect Four uses blue/red/yellow stained wood. Grain UVs
follow the top or side projection so turned-piece sides retain vertical grain.
The runtime applies its uniform 0.65 scale; cooked source units remain unchanged.
`COLOR_0` and `COLOR_1` are explicitly white to avoid black cooked meshes.

Rebuild with `python3 tools/build-board-game-props.py`. The default toolchain is
read from the local `dop-tests` lab; override `--lab` if it lives elsewhere.
Outputs remain isolated under `--work` (default `/tmp/board-game-props/build`).
The original geometry is generated from the repository's procedural source;
WolvenKit deserializes the mesh schema, imports each GLB, round-trips all CR2W
files to JSON and packs the archive. `asset-manifest.json` records model bounds,
triangle counts, material colors, cooked file hashes and package hashes.
Only this resource directory is deployed, never the external toolchain/build.

An updated preload requires a server restart and fresh game launch. Offline
binary checks establish the cooked archive and references; actual lighting,
materials, asynchronous prop creation and cleanup still require an in-game test.

`sources/carved-chess-preview.png` is an offline geometry/material review image,
not an in-game capture. From this resource directory, recreate it with `python3 sources/preview.py`
(optional NumPy and Pillow required).
