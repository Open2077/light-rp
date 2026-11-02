# Native blackjack props

This resource preloads 81 original native models (162 CR2W mesh/entity files)
and seven native textures for the LightRP blackjack table. It contains no
vanilla-path overrides or gameplay code. The gameplay resource
(`op77_lightrp/client/core/casino_blackjack.lua`) creates them with
`kind="prop"`, `physics="none"`, `collision=false`, using depot paths
`open77\assets\op77_lightrp\casino_blackjack\<name>.ent`.
All source coordinates are metres; the client applies its common 0.65 scale.

## Models

- `blackjack_table`: free-standing semicircular table. Origin is the floor
  under the centre of the felt arc; felt top at Z=1.35, felt radius 1.00,
  padded rail to 1.12. Players sit around the arc (-Y), the dealer at +Y.
  Baked in: card shoe on the dealer's left (+X, body x .60..80, y -.10..16,
  mouth at y=-.145), discard tray on the dealer's right (-X), chip rack in
  front of the dealer (y 0..0.13), pedestal with a neon kick strip.
  The felt print (2048x1024 atlas) has four betting circles at radius 0.80,
  angles 54/18/-18/-54 degrees from -Y towards +X (seats 1..4 = white, black,
  white2, black2), card boxes at radius 0.55, "BLACKJACK PAYS 3 TO 2" and
  "DEALER STANDS ON SOFT 17" arcs and the table limits.
- `bj_card_<rank><suit>` x52 (ranks `a 2..9 t j q k`, suits `s h d c`):
  a flat face-up card 0.100 x 0.130 x 0.0016 lying on Z=0, face on top, back
  underneath. `bj_card_back`: the same card face-down (no identity).
  `bj_card_turn`: the generic half-turned pose, tilted 70 degrees on its long
  axis with the back showing and a blank face, resting on Z=0. A flip is
  back -> turn -> face, swapped by model name (yaw-only props).
- `bj_chips_<denomination>_<count>`: chip stacks, radius 0.030, 0.0052 per
  chip, origin at the bottom centre. Denominations and counts: 1 (1-4),
  5 (1-4), 25 (1-3), 100 (1-4), 500 (1), 1000 (1-10): a greedy split of
  any amount never needs more of a denomination. Tops use a chip atlas.

All card faces share one original 2048x1024 atlas (13 ranks x 4 suits, back
in row 5); the felt and chips have their own atlases. Artwork is drawn with
Pillow from DejaVu glyphs: original pips, court cards and back, no casino or
card-maker trademarks.

## Build and verification

Run `python3 tools/build-casino-blackjack-props.py --lab <dop-tests lab> --work <dir>`.
It imports the existing board-prop cooker as a read-only library, generates the
geometry and artwork, deserializes schemas, imports GLB buffers, round-trips
every cooked file, packs the archive and ends with its own `verify` (counts,
RDAR index, hashes, material paths, atlas UV bounds, card/chip/table bounds).
`--verify-only` re-runs the checks on an existing work directory; `--art-only`
only rewrites `sources/*.png`. Changing a preload requires a restart and a
fresh game launch. Binary validation does not prove the in-game look: texture
orientation, materials and async creation still need a live client check.
