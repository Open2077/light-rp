# open77_maneki

Preload pack for the LightRP Maneki-neko collectible (`op77_lightrp`,
`server/modules/maneki.lua` + `client/core/maneki.lua`, docs `docs/maneki.md`).

- `dist/open77_maneki.zip` holds `archive/pc/mod/0_open77_maneki.archive`, which holds
  one entity: `open77\assets\op77_lightrp\maneki\maneki_neko.ent`.
- That entity binds the game's own waving cat,
  `base\environment\decoration\misc\sculptures\chinese_sculpture_small\chinese_sculpture_small_c.mesh`
  (9 × 12 × 16 cm). No game mesh or texture is redistributed.
- Rebuild: `python tools/build-maneki-props.py` (WolvenKit CLI 8.19). It round-trips the
  archive and writes `asset-manifest.json` with the archive and ZIP hashes.
- A new or changed archive needs players to restart the game once.
