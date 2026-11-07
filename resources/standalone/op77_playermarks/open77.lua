-- op77_playermarks: a nameplate above every other player's head in the Light RP
-- design (chamfered HUD chip, yellow accent, Chakra Petch), so a player tells people
-- from the city's NPCs at a glance; while that player talks on voice, its voice
-- bars light up and move with their level.
--
-- Client: a client with the plugin's native nameplate drawer (Open77.nameplates.style)
--         gets the Light RP look as a theme and draws the plates itself, glued to the body
--         and hidden behind walls; this resource only sets each player's label and hides
--         the ones it must (Open77.nameplates.set). An older client keeps the page: the
--         players around (Open77.players.nearby), one Open77.anchors anchor on each body
--         (projected every frame by the plugin, pushed to the page), the talkers
--         (Open77.voice.talkers). A player op77_map3d hides (a chase runner) gets no
--         plate either way.
-- Page:   web/ (plain HTML/CSS/JS, no build step), older clients only.
resource "op77_playermarks"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface on older clients: a live reload would leave a stale one.
reload_policy "reconnect"

shared_script "shared/config.lua"

client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    "network.client",   -- the local player id
    "voice.client",     -- who is talking around, and how loud (the page)
    "ui.nameplates",    -- the native drawer: theme, render, each player's label and visibility
}
