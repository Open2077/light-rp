-- Generated from the NCWE Studio export of the world project "Open77 - Place Casino"
-- (ncwe-export.json): the square in front of the casino. The package is preloaded as a
-- required mod: the launcher installs it before Cyberpunk starts. Changing it needs a
-- dedicated-server restart, then a fresh game launch.
resource "place_casino"
version "1.0.0"
auto_start true

dependency "archivexl >=1.28.0"
preload_mod "dist/place_casino.zip"

server_script "server/main.lua"
