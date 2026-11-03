-- Original cooked tabletop meshes and visual entity hosts; no native overrides.
resource "open77_board_games"
version "2.0.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "reconnect"
preload_mod "dist/open77_board_games.zip"
server_script "server/main.lua"
client_script "client/main.lua"
