-- op77_fireworks: staff fireworks shows and server-wide announcements for Light RP,
-- including the opening-night macro over The Crossing (the Westbrook esplanade).
-- Ported from base/resources/examples/rp_fireworks (MIT, see LICENSE).
--
-- Server only. Every shell is fired by the server (Open77.effects.create with a
-- ttl, or Open77.effects.play for the shells carrying the boom), so every player
-- sees the same show at the same moment; there is no client code.
-- Usage, exports and the effect budget: README.md. Settings: server/config.lua.
resource "op77_fireworks"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

dependencies {
    "open77_effects >=0.2.0",        -- projects the shells on every client
    "open77_notifications >=1.0.0",  -- renders the announcement banner
    "open77_chat >=0.5.0",           -- renders the announcement row in chat
}

-- world.effects  : Open77.effects.create / Open77.effects.play (every shell of every show)
-- network.events : the command's answer (open77:command:result) and Open77.notifications.*
permissions { "world.effects", "network.events" }

server_script "server/config.lua"
server_script "server/plan.lua"
server_script "server/main.lua"
