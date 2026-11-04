-- The Maneki-neko collectible's visual host: one entity over the game's own lucky cat
-- (chinese_sculpture_small_c.mesh). No game mesh is copied and nothing vanilla is
-- overridden. Built by tools/build-maneki-props.py; gameplay lives in op77_lightrp.
resource "open77_maneki"
version "1.0.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "reconnect"
preload_mod "dist/open77_maneki.zip"
server_script "server/main.lua"
client_script "client/main.lua"
