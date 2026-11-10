resource "open77_chat"
version "0.7.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

client_script "client/ui.lua"
client_script "client/main.lua"
server_script "server/main.lua"

-- the chat is a NativeUI document (the Light RP look)
files { "ui/chat.rml", "ui/chat.rcss", "ui/fonts/*" }

permissions { "network.events", "local.events", "clipboard.write" }
