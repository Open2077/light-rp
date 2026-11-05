# Light RP vehicle kit: where the packs go (placeholder)

**Nothing built is committed here.** The Auto Studio code (`op77_lightrp`) is complete
and degrades cleanly without the packs: rims, body kit and performance stay greyed
("…is not installed on this server yet.") until the lead installs the three resources
below. The studio's catalogue (`server/config/vehicle_kit.lua`) is already generated
from the same fit tables; it is Lua only and names the models as `asset:<pack>/<model>`.

| Resource | Built by | Built copy (git-ignored, per worktree) | Manifest facts |
| --- | --- | --- | --- |
| `lightrp_vk_rims` | E1, `scripts/vehicle-kit/build-pack.ps1` (Open77 repo, branch `vc/e1-rims`) | `C:\Games\cyberm\wt-vc-e1\artifacts\vehicle-kit\lightrp_vk_rims\resource\lightrp_vk_rims\` | `auto_start false`, `client_script register.lua`, `preload_mod dist/LightRPVehicleKitRims_71f872a21fa7.zip`, `props.register` |
| `lightrp_vk_body` | E2, same script (branch `vc/e2-bodykit`) | `C:\Games\cyberm\wt-vc-e2\artifacts\vehicle-kit\lightrp_vk_body\resource\lightrp_vk_body\` | `auto_start false`, `preload_mod dist/LightRPVehicleKitBody_c774256c18e1.zip`, `props.register` |
| `lightrp_vehicle_stages` | E5, `scripts/vehicle-kit/stages/build-stages.ps1` (branch `vc/e5-stages`) | `C:\Games\cyberm\wt-vc-e5\artifacts\vehicle-kit\stages\resource\lightrp_vehicle_stages\` | `auto_start true`, `dependency 'tweakxl >=1.12.0'`, `preload_mod dist/LightRPVehicleStages_ce7fa4c98a7e.zip`, exports `stageRecord` / `stageOf` |

The resource names are load-bearing: `KIT.rims.pack`, `KIT.body.pack` and
`stages.resource` in `shared/vehicle_customization.lua` must match them, and the
server and every client check `GetResourceState(<name>) == "running"`.

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
   `…/lightrp_vehicle_stages/` (same depth as `open77_maneki`, whose resolution is proven).
   This `lightrp_vehicle_kit/` folder only holds this note.
3. **Decide how they are versioned.** To track them like the other asset resources
   (`open77_maneki` commits its `dist/*.zip`), add to the repository `.gitignore`:

   ```gitignore
   !resources/assets/models/lightrp_vk_rims/
   !resources/assets/models/lightrp_vk_rims/**
   !resources/assets/models/lightrp_vk_body/
   !resources/assets/models/lightrp_vk_body/**
   !resources/assets/models/lightrp_vehicle_stages/
   !resources/assets/models/lightrp_vehicle_stages/**
   ```

   Otherwise ship them by overlay on the host, as for the RP scripts.
4. **TweakXL ≥ 1.12.0.** The stages resource depends on `tweakxl >=1.12.0`, but the only
   loader in the Open77 tree (`resources/assets/loaders/tweakxl`) is **1.11.4**. Without a
   1.12.0 loader the stages resource does not start and Performance stays greyed. Either
   bump the loader (E0.8 measured with 1.12.0) and add `"tweakxl"` to `resources.load`, or
   rebuild the stages with the dependency the loader satisfies after checking the YAML on it.
   TweakXL is executable content: the world must stay `requiredMods.unsecured = true`.
5. **`server.jsonc`** (not edited by this branch): add the three names to
   `resources.load`, **before** `"op77_lightrp"`, and ensure the two opt-in packs at start:

   ```jsonc
   "load": [ …, "tweakxl", "lightrp_vk_rims", "lightrp_vk_body", "lightrp_vehicle_stages", …, "op77_lightrp", … ],
   "startup": { "commands": [ …, "ensure lightrp_vk_rims", "ensure lightrp_vk_body" ] },
   ```

   Order is not functional (the studio checks the packs each time it opens and parts
   are registered by id), but listing them first keeps the log readable.
6. **Players must reconnect** after the packs are added: `preload_mod` content is
   projected by the launcher before the game starts (`reload_policy 'reconnect'`). A
   client without it sees the category greyed with "Your game has not loaded this
   workshop's parts…" or a warning after a preview.
7. Read the server log at start: `auto studio: N kit parts registered` (16 = 8 rims + 8
   body parts). `…rims without per-wheel fits (server predates them)` means the server
   build lacks B2 per-wheel lists: the Merrimac middle axle and the Apollo lose their rims.

The full checklist, two clients, is in
`resources/gamemodes/op77_lightrp/docs/vehicle-customization.md`, "Lab checklist".
