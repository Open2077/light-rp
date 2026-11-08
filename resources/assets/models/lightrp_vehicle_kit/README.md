# Light RP vehicle kit: where the packs go (placeholder)

**Nothing built is committed here.** The Auto Studio code (`op77_lightrp`) is complete
and degrades cleanly without the packs: rims, body kit and performance stay greyed
("…is not installed on this server yet.") until the lead installs the resources
below; pack liveries simply do not appear in the Livery list without theirs. The studio's catalogue (`server/config/vehicle_kit.lua`) is already generated
from the same fit tables; it is Lua only and names the models as `asset:<pack>/<model>`.

| Resource | Built by (Open77 repo) | Built copy (git-ignored, in the Open77 checkout that built it) | Manifest facts |
| --- | --- | --- | --- |
| `lightrp_vk_rims` | E1, `scripts/vehicle-kit/build-pack.ps1` | `artifacts/vehicle-kit/lightrp_vk_rims/resource/lightrp_vk_rims/` | `auto_start false`, `client_script register.lua`, `preload_mod dist/LightRPVehicleKitRims_f721d6538465.zip`, `props.register` |
| `lightrp_vk_body` | E2, same script | `artifacts/vehicle-kit/lightrp_vk_body/resource/lightrp_vk_body/` | `auto_start false`, `preload_mod dist/LightRPVehicleKitBody_ed9c4dea033d.zip`, `props.register` |
| `lightrp_vk_liveries` | E3, `scripts/vehicle-kit/liveries/build-liveries.ps1` | `artifacts/vehicle-kit/liveries/resource/lightrp_vk_liveries/` | `auto_start true`, `dependency 'tweakxl >=1.12.0'`, `preload_mod dist/LightRPVehicleLiveries_062aaf1f63a2.zip`, `world.vehicles` + `world.vehicles.appearance`; its server script calls `registerPaintProfiles` |
| `lightrp_vehicle_original_stickers` | W2.4, `scripts/vehicle-kit/stickers/build-original-stickers.ps1` | `artifacts/vehicle-kit/original-stickers/resource/lightrp_vehicle_original_stickers/` | `auto_start true`, `dependency 'tweakxl >=1.12.0'`, `preload_mod dist/Open77LightRPOriginalStickers_c63f2be126d8.zip`; its server script calls `registerStickers` (five themes on every vanilla player body a theme fits, trims included) |
| `lightrp_vehicle_stages` | E5, `scripts/vehicle-kit/stages/build-stages.ps1` | `artifacts/vehicle-kit/stages/resource/lightrp_vehicle_stages/` | `auto_start true`, `dependency 'tweakxl >=1.12.0'`, `preload_mod dist/LightRPVehicleStages_ce7fa4c98a7e.zip`, exports `stageRecord` / `stageOf` |

Revisions: rims `f721d6538465` and body `ed9c4dea033d` are the packs checked frame by frame
in game, liveries `490d5fb1f73b` the pack seen without a crash (all on one client,
2026-11-06). Liveries `062aaf1f63a2` (21 bodies, the 11 dealer cars and 10 more) and the
original stickers `c63f2be126d8` on every player body were built offline only (2026-11-08,
the content of `98ed7f188e77` and `57df1c007bfd` under new depot prefixes), not seen in game. The stage revision was not re-checked in this pass.

The resource names are load-bearing: `KIT.rims.pack`, `KIT.body.pack` and
`stages.resource` in `shared/vehicle_customization.lua` must match them, and the
server and every client check `GetResourceState(<name>) == "running"`.

**Decal coverage table.** `server/config/vehicle_decals.lua` says which sticker sets and how
many pack liveries each catalogue key gets, and which covered vanilla bodies the catalogue
does not sell. The studio offers stickers and liveries from the natives only; the table lets a
covered model whose sticker pack is stopped read "Stickers are not installed on this server
yet." Regenerate it with the packs, from the same build:

```text
python resources/gamemodes/op77_lightrp/tools/build_vehicle_decals.py \
    --stickers <built>/lightrp_vehicle_original_stickers/catalogue.json \
    --liveries <built>/lightrp_vk_liveries/profiles.json
```

Its header records the sha256 of both inputs and the pack revisions.

## Lead steps (combining the packs)

1. **Rebuild the packs from the merged fit tables** if E1/E2 changed after the
   revisions above, then regenerate the studio catalogue from the **same** files:

   ```text
   python resources/gamemodes/op77_lightrp/tools/build_vehicle_kit.py \
       --rims <open77>/scripts/vehicle-kit/specs/lightrp-rims-fit.json \
       --body <open77>/scripts/vehicle-kit/specs/lightrp-bodykit-fit.json \
       --body-spec <open77>/scripts/vehicle-kit/specs/lightrp-bodykit.json
   ```

   The catalogue header records the sha256 of both fit tables: a pack and a
   catalogue built from different tables put parts in the wrong place.
2. **Copy each resource folder** next to the others in `resources/assets/models/`:
   `resources/assets/models/lightrp_vk_rims/`, `…/lightrp_vk_body/`,
   `…/lightrp_vk_liveries/`, `…/lightrp_vehicle_stages/` (same depth as `open77_maneki`,
   whose resolution is proven).
   This `lightrp_vehicle_kit/` folder only holds this note.
3. **Decide how they are versioned.** To track them like the other asset resources
   (`open77_maneki` commits its `dist/*.zip`), add to the repository `.gitignore`:

   ```gitignore
   !resources/assets/models/lightrp_vk_rims/
   !resources/assets/models/lightrp_vk_rims/**
   !resources/assets/models/lightrp_vk_body/
   !resources/assets/models/lightrp_vk_body/**
   !resources/assets/models/lightrp_vk_liveries/
   !resources/assets/models/lightrp_vk_liveries/**
   !resources/assets/models/lightrp_vehicle_stages/
   !resources/assets/models/lightrp_vehicle_stages/**
   ```

   Otherwise ship them by overlay on the host, as for the RP scripts.
4. **TweakXL ≥ 1.12.0.** The stages and liveries resources depend on `tweakxl >=1.12.0`. The Open77
   loader (`resources/assets/loaders/tweakxl`) is **1.12.0** on base
   `feat/vehicle-customization` (`b9af09d2`) and still **1.11.4** on base `main` as of
   2026-11-06. Without a 1.12.0 loader the stages resource does not start and Performance
   stays greyed. Use the 1.12.0 loader (E0.8 measured with it) and add `"tweakxl"` to
   `resources.load`.
   TweakXL is executable content: the world must stay `requiredMods.unsecured = true`.
5. **`server.jsonc`** (not edited by this branch): add the four names to
   `resources.load`, **before** `"op77_lightrp"`, and ensure the two opt-in packs at start:

   ```jsonc
   "load": [ …, "tweakxl", "lightrp_vk_rims", "lightrp_vk_body", "lightrp_vk_liveries", "lightrp_vehicle_stages", …, "op77_lightrp", … ],
   "startup": { "commands": [ …, "ensure lightrp_vk_rims", "ensure lightrp_vk_body" ] },
   ```

   Order is not functional (the studio checks the packs each time it opens and parts
   are registered by id), but listing them first keeps the log readable.
6. **Players must reconnect** after the packs are added: `preload_mod` content is
   projected by the launcher before the game starts (`reload_policy 'reconnect'`). A
   client without it sees the category greyed with "Your game has not loaded this
   workshop's parts…" or a warning after a preview.
7. Read the server log at start: `auto studio: N kit parts registered` (48 = 18 rims + 30
   body parts, since E1e and E2b). `…rims without per-wheel fits (server predates them)` means the server
   build lacks B2 per-wheel lists: the Merrimac middle axle and the Apollo lose their rims.

The full checklist, two clients, is in
`resources/gamemodes/op77_lightrp/docs/vehicle-customization.md`, "Lab checklist".
