-- ArchiveXL: loads .xl extensions (streaming blocks, sector patches, resource patches, dynamic appearances).
--
-- ArchiveXL 1.28.0 by psiberx, the first official release for Cyberpunk 2.5
-- (https://github.com/psiberx/cp2077-archive-xl/releases/tag/v1.28.0; MIT, LICENSE and
-- THIRD_PARTY_LICENSES ship inside the package). It replaces the Open77 build
-- (1.27.5-open77.x) used until then. The zip is the GitHub release asset, untouched, and is
-- game-root-relative (red4ext/plugins/..., r6/...).
--
-- A loader is a shared dependency, not world content: any resource whose assets
-- need it declares `dependency "archivexl >=1.28.0"` (NCWE worlds for 2.5) and this package
-- rides along as the required mod "archivexl-assets". RED4ext plugins initialise before the
-- depot mounts archives, so there is no ordering to manage between loader and world.
--
-- It is EXECUTABLE content. A server only boots with it when
-- `requiredMods.unsecured` is true; every list badges that server and players
-- confirm the risk before joining. Bump the version here and swap the zip in
-- dist/ together -- the manifest version is what dependents pin against.
resource "archivexl"
version "1.28.0"
auto_start true

preload_mod "dist/ArchiveXL-1.28.0.zip"

server_script "server/main.lua"
client_script "client/marker.lua"
