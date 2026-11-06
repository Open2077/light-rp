-- Generated from the NCWE Studio export of the world project "Open77 - Casino"
-- (ncwe-export.json). The package is preloaded as the required mod "casino-assets": the
-- launcher installs it before Cyberpunk starts. Changing it needs a dedicated-server
-- restart, then a fresh game launch.
resource "casino"
version "1.3.0"
auto_start true

dependency "archivexl >=1.28.0"
preload_mod "dist/casino.zip"

server_script "server/main.lua"
