resource "open-voice"
version "0.3.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "reconnect"

dependency "open77_voice >=0.2.0"

server_scripts {
    "server/config.lua",
    "server/main.lua",
}
client_script "client/range_preview.lua"
client_script "client/ui.lua"
client_script "client/main.lua"

-- the HUD is a NativeUI document (the Light RP hologram plate)
files { "ui/voice.rml", "ui/voice.rcss", "ui/fonts/*" }

-- open77_voice remains the sole PTT/VAD/audio driver. This companion owns
-- only server-authoritative reach presets, its F11 request edge, HUD and range ring.
permissions { "voice.manage", "voice.client", "input.actions", "network.events" }
