-- op77_ripperdoc: the ripperdoc clinic interface. A full-screen holographic paperdoll in the
-- LightRP DA (yellow & black) built from the game's own ripperdoc art (paperdoll videos, system
-- overlays, cyberware icons) and UI sounds: twelve body systems around the body, a camera dive
-- into each system's close-up, the installed implants, the clinic's stock and the surgery.
--
-- UI only for now (preview for validation): the page shows a demo catalogue and fakes the
-- installation locally; the installation system comes later and will feed `open`.
--
-- Server: exports open(playerId, payload) / close(playerId); "op77_ripperdoc:closed" (host
--         event, playerId) when the patient leaves the interface.
-- Client: the WebUI surface, input focus, the interface sounds (Play2DSound, one handle per slot).
-- Page:   web/ is built from E:/Open77/LightRP/ripperdoc-ui (npm run build). Contract: PROTOCOL.md.
-- Who opens it on LightRP: op77_lightrp/server/modules/ripperdoc.lua, once a player lies in a
-- ripperdoc chair (op77_scenes).
resource "op77_ripperdoc"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

server_script "server/main.lua"
client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }
files { "web/media/sfx/*.mp3" }

permissions {
    -- both sides
    "network.events",
    -- server: op77_ripperdoc:closed / op77_ripperdoc:action to the clinic's owner (host events)
    "local.events",
    -- client
    "audio.play",            -- the interface sounds (the page names them, Lua plays them)
}
