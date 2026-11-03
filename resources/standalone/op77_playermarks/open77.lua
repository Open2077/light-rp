-- op77_playermarks: a small yellow dot above every other player's head, so a
-- player tells people from the city's NPCs at a glance; while that player talks
-- on voice, radio waves pulse out of the dot with their voice level.
--
-- Client: the players around (Open77.players.nearby), one Open77.anchors anchor
--         on each body (projected every frame by the plugin, pushed to the page),
--         the talkers (Open77.voice.talkers). A player op77_map3d hides (a chase
--         runner) gets no dot either.
-- Page:   web/ (plain HTML/CSS/JS, no build step).
resource "op77_playermarks"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

shared_script "shared/config.lua"

client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    "network.client",   -- the local player id
    "voice.client",     -- who is talking around, and how loud
}
