# Light RP vehicle kit: the content packs

The Auto Studio (`op77_lightrp`) draws its rims, body kits, liveries, stickers, performance
stages, engine sounds and plates from the seven content packs committed next to this folder.
Each pack is a resource whose `preload_mod` ZIP the launcher mounts before the game starts,
plus the script that declares the content to the server. Every pack is original content: no
game file is copied into a ZIP, and game data is only named by path or record.

They need the **Open77 release that brings the vehicle customization natives** (server and
client). On an older server the declaring scripts skip themselves, and the studio greys the
categories ("…is not installed on this server yet.").

| Resource | What it adds | Revision | ZIP |
| --- | --- | --- | --- |
| `lightrp_vk_rims` | 18 original rims in 6 finishes (108 models), fitted to the dealer cars and the other vanilla player cars | `f721d6538465` | 5.1 MiB |
| `lightrp_vk_body` | 30 body kit parts: wings, lips, canards, skirts, diffusers, hoods, roofs | `ed9c4dea033d` | 0.6 MiB |
| `lightrp_vk_liveries` | pack liveries on 21 bodies (the 11 dealer cars and 10 more) | `062aaf1f63a2` | 7.4 MiB |
| `lightrp_vehicle_original_stickers` | 235 original stickers, on every player body | `c63f2be126d8` | 8.7 MiB |
| `lightrp_vehicle_stickers` | 43 stickers, the first set | `d8ade1ca81c2` | 56 KiB |
| `lightrp_vehicle_stages` | Stage 1 to 3 records and engine sounds per model | `cab15fe6bcfe` | 60 KiB |
| `open77_vehicle_plates` | the custom plate text | `d4412f3b864f` | 0.6 MiB |

Window tint needs no pack here: `open77_vehicle_tint` ships with the Open77 server
distribution.

The ZIP name carries the revision, a hash of the pack's inputs. A rebuilt pack gets a new name,
so a stale copy in a player's cache can never shadow it.

## Turning them on

1. **Loaders.** The liveries, stickers and stages packs depend on `tweakxl >=1.12.0`, and the
   plates on ArchiveXL 1.28.0. ArchiveXL is committed here (`resources/assets/loaders/archivexl`);
   TweakXL is the Open77 `tweakxl` loader resource, published in
   [open77-resources](https://github.com/Open2077/open77-resources) under `libraries/`. TweakXL
   is executable content, so the world must stay `requiredMods.unsecured = true`.
2. **`server.jsonc`.** Add the packs to `resources.load` (it is an allowlist: a resource missing
   from it never starts and logs nothing), before `op77_lightrp`, and start the three opt-in
   packs (`auto_start false`) at boot:

   ```jsonc
   "load": [ …, "tweakxl", "lightrp_vk_rims", "lightrp_vk_body", "lightrp_vk_liveries",
             "lightrp_vehicle_original_stickers", "lightrp_vehicle_stickers",
             "lightrp_vehicle_stages", "open77_vehicle_plates", …, "op77_lightrp", … ],
   "startup": { "commands": [ …, "ensure lightrp_vk_rims", "ensure lightrp_vk_body",
                              "ensure open77_vehicle_plates" ] },
   ```

   This repository's own `server.jsonc` does not list them yet: they wait for the Open77
   release, so that players do not download them for categories their client cannot draw.
3. **Players reconnect** after a pack is added or changed. The launcher mounts `preload_mod`
   content before the game starts (`reload_policy 'reconnect'`). A client without the pack sees
   the category greyed, or a warning after a preview.
4. **Read the server log** at start: `auto studio: N kit parts registered` (48 = 18 rims + 30
   body parts).

The resource names are load-bearing. `KIT.rims.pack`, `KIT.body.pack` and `stages.resource` in
`shared/vehicle_customization.lua` must match them, the server and every client check
`GetResourceState(<name>) == "running"`, and each pack's internal paths contain its name. Do not
rename a pack; rebuild it under the new name instead.

## Rebuilding a pack, or making your own

The packs are built by the Open77 vehicle kit pipeline, published in
[Open2077/open77-resources](https://github.com/Open2077/open77-resources) under
`tools/vehicle-kit`. It turns a JSON spec into a ready-to-copy resource folder like the ones
here. How a pack works, its rules and its limits are in
[Vehicle customization content packs](https://open2077.net/docs/vehicle-customization-packs).

The studio's catalogue is generated from the **same** fit tables as the rims and body packs. A
pack and a catalogue built from different tables put parts in the wrong place, so regenerate
both together:

```text
python resources/gamemodes/op77_lightrp/tools/build_vehicle_kit.py \
    --rims <vehicle-kit>/specs/lightrp-rims-fit.json \
    --body <vehicle-kit>/specs/lightrp-bodykit-fit.json \
    --body-spec <vehicle-kit>/specs/lightrp-bodykit.json

python resources/gamemodes/op77_lightrp/tools/build_vehicle_kit_player_rims.py \
    --rims <vehicle-kit>/specs/lightrp-rims-fit-player.json
```

The first writes `server/config/vehicle_kit.lua` (the dealer cars); the second writes
`server/config/vehicle_kit_player_rims.lua` (every other vanilla `Vehicle.*_player*` record,
reusing the same rims). Each header records the sha256 of the tables it was built from. Quest
variants (`Vehicle.q<digits>_*`) are left out of customization: the tables never name them and
the generator refuses one that does.

The sticker and livery coverage table (`server/config/vehicle_decals.lua`) is regenerated from
the same sticker and livery builds:

```text
python resources/gamemodes/op77_lightrp/tools/build_vehicle_decals.py \
    --stickers resources/assets/models/lightrp_vehicle_original_stickers/catalogue.json \
    --liveries resources/assets/models/lightrp_vk_liveries/profiles.json
```

The full two-client checklist is in
`resources/gamemodes/op77_lightrp/docs/vehicle-customization.md`, "Lab checklist".
