-- op77_loadscreen: the LightRP loading screen, twice.
--   * Joining the server: `loadscreen` below. The Open77 shell mounts web/connect.html
--     from this resource's verified files while the world streams, before any
--     resource Lua runs, and feeds it the loading progress (FiveM-style loadscreen).
--   * In game: client/main.lua keeps web/index.html ready and covers zone changes
--     (teleports, instances, interiors) asked by the server, and every native
--     loading screen of the game. See README.md.
resource "op77_loadscreen"
version "1.0.1"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

server_script "server/main.lua"

client_script "client/cover.lua"
client_script "client/main.lua"

loadscreen "web/connect.html"
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    "network.events",  -- both sides: cover / release from the server
    "screen.read",     -- client: follow the game's own loading screen
    "webui.modal",     -- client: the cover sits above the HUD and menus
    "ui.vanilla.hud",  -- client: the vanilla HUD is hidden while the cover is up
}
