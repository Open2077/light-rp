# Native blackjack props

This resource preloads 81 original native models (162 CR2W mesh/entity files),
one collider entity and three native textures for the LightRP blackjack table.
It contains no vanilla-path overrides or gameplay code. The gameplay resource
(`op77_lightrp/client/core/casino_blackjack.lua`) creates the visual props with
`kind="prop"`, `physics="none"`, `collision=false`, using depot paths
`open77\assets\op77_lightrp\casino_blackjack\<name>.ent`.
All source coordinates are metres; the client applies its common 0.65 scale.

## Look

A high-end Night City table: a dark composite top (fine twill, vignette) whose
print glows, a padded black leather armrest on a polished chrome lip, a magenta
light line under the rail, a black chrome skirt and faceted pedestal on a lit
floor ring. The print: glowing cyan betting circles with tick marks and gold
seat numbers, corner-bracket card boxes, "BLACKJACK PAYS 3 TO 2", "DEALER
STANDS ON ALL 17S", "DOUBLE ON ANY FIRST TWO CARDS" and the table limits (read
from the shared rules), all in `tools/casino_art.py`'s original HUD typeface.

Materials are `engine\materials\metal_base.remt` instances; the top print and
the neon lines also set `Emissive`/`EmissiveEV`/`EmissiveColor` (the print is
its own emissive map, so the dark composite barely glows). EVs live in
`MATERIALS` in the build script (`EMISSIVE=False` cooks without emission).
Design renders (not shipped): `sources/preview_blackjack_{hero,player,dealer,side,cards,chips}.png`.

## Models

- `blackjack_table`: free-standing semicircular table. Origin is the floor
  under the centre of the arc; top at Z=1.35, top radius 1.00, rail to 1.12.
  Players sit around the arc (-Y); the croupier stands at +Y and nothing of the
  table reaches past the apron at y=0.26. On the dealer's edge: card shoe on
  the dealer's left (+X, smoked wedge x .60..80, y -.10..16, mouth at y=-.145,
  chrome rails, cyan light facing the dealer), discard tray on the dealer's
  right (-X, x -.79..-.61), chip rack in front of the dealer (y 0..0.13, six
  channels of layered chip rolls). The print (2048x1024 atlas) has four betting
  circles at radius 0.80, angles 54/18/-18/-54 degrees from -Y towards +X
  (seats 1..4 = white, black, white2, black2) and card boxes at radius 0.55.
- `bj_card_<rank><suit>` x52 (ranks `a 2..9 t j q k`, suits `s h d c`):
  a flat face-up card 0.100 x 0.130 x 0.0016 lying on Z=0, face on top, back
  underneath. `bj_card_back`: the same card face-down (no identity).
  `bj_card_turn`: the generic half-turned pose, tilted 70 degrees on its long
  axis with the back showing and a blank face, resting on Z=0. A flip is
  back -> turn -> face, swapped by model name (yaw-only props).
- `bj_chips_<denomination>_<count>`: chip stacks of layered machined discs
  (chamfered edges, edge inserts that alternate per chip, a textured top with a
  colour ring and the value), radius 0.030, 0.0052 per chip, origin at the
  bottom centre. Denominations and counts: 1 (1-4), 5 (1-4), 25 (1-3),
  100 (1-4), 500 (1), 1000 (1-10): a greedy split of any amount never needs
  more of a denomination.
- `blackjack_table_collider.ent` (no mesh): three static boxes covering the
  rail arc and the apron, nothing past y=0.26 (the croupier's spot) and only a
  few centimetres past the rail at the arc's corners; 0.65 scale baked in. See
  `tools/COLLISION.md`.

All card faces share one original 2048x1024 atlas (13 ranks x 4 suits, back in
row 5): ivory faces, jumbo HUD rank indices with vector suit shapes, ace rings,
original double-ended geometric court figures (J blade, Q orb, K sceptre), and
a black back with a magenta/cyan circuit pattern and a hexagon emblem. The
chips have their own atlas. No casino or card-maker trademarks.

## Build and verification

Run `python3 tools/build-casino-blackjack-props.py --lab <dop-tests lab> --work <dir>`.
It imports the existing board-prop cooker as a read-only library, generates the
geometry and artwork, deserializes schemas, imports GLB buffers, round-trips
every cooked file, packs the archive and ends with its own `verify` (counts,
RDAR index, hashes, material paths, emissive channels, atlas UV bounds,
card/chip/table bounds, the collider entity and the clear dealer side).
`--verify-only` re-runs the checks on an existing work directory; `--art-only`
only rewrites `sources/*.png`; `--preview` also writes the preview renders.
Changing a preload requires a restart and a fresh game launch. Binary validation
does not prove the in-game look: texture orientation, emissive strength,
materials and async creation still need a live client check.
