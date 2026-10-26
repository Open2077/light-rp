-- op77_neuralink: the Neural-Link, the implant that replaces smartphones in
-- Night City. A holographic interface (Sword Art Online menu language) with a
-- phone line per character, contacts, direct and group messages, incoming and
-- outgoing voice calls (native voice channels, blue holocall eyes) and an app
-- registry other resources can extend.
--
-- Server: lines, persistence, message fan-out, the call state machine and
--         Screamsheet, the players' social feed.
-- Client: the WebUI surface, input focus, the call HUD feed and the app registry.
-- Page:   web/ is built from E:/Open77/LightRP/neuralink-ui (npm run build).
-- Contract between page and client: PROTOCOL.md.
resource "op77_neuralink"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

dependencies {
    "open77_voice >=0.1.0",
}

shared_script "shared/config.lua"

server_script "server/store.lua"
server_script "server/lines.lua"
server_script "server/messages.lua"
server_script "server/calls.lua"
server_script "server/social.lua"
server_script "server/main.lua"

client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }
files { "audio/*.wav" }

permissions {
    -- both sides
    "network.events",
    "local.events",          -- op77_lightrp:characterReady / characterChanged (host-wide)
    -- server
    "database.access",
    "voice.manage",
    "players.holocall.control",
    "audio.network",
    -- client
    "input.actions",
    "voice.client",          -- talker levels during a call
    "network.client",        -- local player ID
    "audio.play",            -- interface sounds and ringtone preview
    "world.query",           -- the district a scream is posted from (Open77.world.district)
}
