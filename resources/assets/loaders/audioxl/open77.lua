-- AudioXL: plays custom sounds through the game's Wwise engine. The BT-7274 Titan's voice, footsteps, weapons and
-- abilities are AudioXL sounds (bt7274_2.zip carries their rows and samples under red4ext/plugins/AudioXL/sounds).
--
-- Upstream: https://www.nexusmods.com/cyberpunk2077/mods/33442 (file 169662, AudioXL 0.9.1 for game 2.5, by
-- DigitalVixen). The zip is that release, untouched (sha256
-- 9ef927604e412f24449812ef19316f25abbd28d0cf593a47b3f2357ce985aee6) and game-root-relative
-- (red4ext/plugins/AudioXL/..., r6/scripts/AudioXL/..., r6/storages/RedscriptConfigFramework/...).
--
-- LICENSE.md ships inside the package. AudioXL is NOT freely redistributable: its licence forbids hosting or
-- bundling it. Light RP ships it under the author's authorization (stated by the Open77 owner, 2026-11-05); a
-- server without that authorization must not load this resource.
--
-- A loader is a shared dependency, not world content: any resource that needs it declares
-- `dependency "audioxl >=0.9.1"` (op77_lightrp_titans does) and this package rides along as the required mod
-- "audioxl-assets".
--
-- It is EXECUTABLE content. A server only boots with it when
-- `requiredMods.unsecured` is true; every list badges that server and players
-- confirm the risk before joining. Bump the version here and swap the zip in
-- dist/ together -- the manifest version is what dependents pin against.
resource "audioxl"
version "0.9.1"
auto_start true

preload_mod "dist/AudioXL-0.9.1.zip"

server_script "server/main.lua"

client_script "client/marker.lua"
