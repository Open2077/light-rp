-- op77_chase_hud: the NCPD Chase overlay (op77_chase). A transparent WebUI surface on the
-- hud layer, top centre: role, clock, round and score, the arrest / escape meter, and the
-- round and match result cards; a one-line strip while queued. It draws what the server
-- sends and nothing else: no key, no input, no part of Light RP's own HUD.
resource "op77_chase_hud"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    "network.events",   -- op77_chase:hud / op77_chase:queue from the server
}
