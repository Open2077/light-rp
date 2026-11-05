-- Codeware: the redscript/RTTI library the BT-7274 Titan needs. BT7274Keys.reds imports it for its key events
-- (KeyInputEvent), and the Titan controller spawns BT, its stand-in target and other players' Titans through its
-- DynamicEntitySystem.
--
-- Upstream: https://github.com/psiberx/cp2077-codeware (MIT; LICENSE and
-- THIRD_PARTY_LICENSES ship inside the package). The zip is the official 1.21.2
-- release (psiberx/cp2077-codeware, tag v1.21.2, asset Codeware-1.21.2.zip,
-- sha256 269b65b8b97d26ea85d4516f5eb34c01a19dc85e299be57fb4f764e16c164dd2),
-- untouched, and is game-root-relative (red4ext/plugins/Codeware/...).
--
-- A loader is a shared dependency, not world content: any resource that needs it
-- declares `dependency "codeware >=1.21.2"` (op77_lightrp_titans does) and this package
-- rides along as the required mod "codeware-assets". The launcher compiles a world's
-- scripts only against what it installs, so a script that imports Codeware is refused
-- (UNRESOLVED_IMPORT) unless this loader is selected too, even where a player installed
-- Codeware by hand.
--
-- It is EXECUTABLE content. A server only boots with it when
-- `requiredMods.unsecured` is true; every list badges that server and players
-- confirm the risk before joining. Bump the version here and swap the zip in
-- dist/ together -- the manifest version is what dependents pin against.
resource "codeware"
version "1.21.2"
auto_start true

preload_mod "dist/Codeware-1.21.2.zip"

server_script "server/main.lua"

client_script "client/marker.lua"
