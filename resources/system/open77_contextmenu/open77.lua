resource "open77_contextmenu"
version "1.4.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "reconnect"
client_scripts { "shared/config.lua", "client/registry.lua", "client/ui.lua", "client/main.lua" }
-- The menu is a NativeUI document (since 1.4.0; it was a WebUI page before), in the Light RP look.
files { "ui/contextmenu.rml", "ui/contextmenu.rcss", "ui/fonts/*" }
permissions { "world.query", "input.actions", "players.controls", "local.events" }
