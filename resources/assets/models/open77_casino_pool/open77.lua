-- Original pool table, cue, rack and balls. No vanilla overrides.
resource "open77_casino_pool"
version "1.0.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "reconnect"
preload_mod "dist/open77_casino_pool.zip"
server_script "server/main.lua"
client_script "client/main.lua"
