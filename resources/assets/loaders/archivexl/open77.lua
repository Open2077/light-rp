-- ArchiveXL: loads .xl extensions (streaming blocks, sector patches, resource patches, dynamic appearances).
--
-- ArchiveXL 1.28.0 + Open77 (open77.2): psiberx's first release for Cyberpunk 2.5 with the
-- world-streaming fixes of the Open77 fork (https://github.com/Open2077/archive-xl, branch
-- open77/1.28; MIT, LICENSE and THIRD_PARTY_LICENSES ship inside the package). The official
-- 1.28.0 crashes the game on a deleted cooked placement (psiberx/cp2077-archive-xl#36) and
-- cannot remove a game mesh's cooked collision: NCWE worlds need this build. The zip is the
-- official release asset with the fork's ArchiveXL.dll (and OPEN77.md), game-root-relative.
-- open77.2 (2026-11-14) also fixes a crash when a car is removed while an .app patch (our plate
-- pack) still merges into its appearance (ArchiveXL.dll+0xF7342 in the Stable crash reports).
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

preload_mod "dist/ArchiveXL-1.28.0-open77.2.zip"

server_script "server/main.lua"
client_script "client/marker.lua"
