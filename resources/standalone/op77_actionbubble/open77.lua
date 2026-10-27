-- op77_actionbubble: roleplay action bubbles. A short line such as
-- "*Opens the trunk*" or "*Unlocks the vehicle*" pinned in the world: on a
-- character (it follows the body, with an offset), a vehicle, an entity or a
-- fixed position, for a set time, drawn as an animated 3D hologram card with a
-- leader line to its anchor.
--
-- Any resource triggers one, from the client (local only, or relayed by the
-- server to the players around) or from the server (to the players around the
-- anchor, a list, or everyone). The API is in README.md.
--
-- Server: the relay (validation, rate limit, who receives a bubble).
-- Client: the bubbles, their anchors (Open77.anchors, projected every frame by
--         the plugin and pushed to the page), lifetimes.
-- Page:   web/ (plain HTML/CSS/JS, no build step).
resource "op77_actionbubble"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

shared_script "shared/config.lua"
shared_script "shared/bubble.lua"

server_script "server/main.lua"

client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    -- both sides: the client asks the relay, the relay fans out
    "network.events",
    -- server: where a vehicle anchor is (range of a replicated bubble, reach of a
    -- client's); every server Open77.vehicles call requires it, read-only use here
    "world.vehicles",
    -- client
    "network.client",   -- the local player id (ids of the bubbles it relays)
    "vehicles.read",    -- a vehicle anchor resolves to the vehicle's entity
}
