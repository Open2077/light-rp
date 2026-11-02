-- op77_weaponhud: a holographic weapon HUD floating at the bottom left while a weapon is drawn
-- (name, class and type, the magazine in seven-segment digits, the reserve, a magazine bar
-- that empties shot by shot, low-ammo and RELOAD warnings, the reload), in the LightRP
-- black-and-yellow style, the mirror of op77_speedometer. It replaces the game's ammo
-- counter, and LightRP's own weapon readout stands down while it runs
-- (op77_weaponhud:state). Configuration: shared/config.lua; API: README.md.
--
-- Client: reads the drawn weapon, feeds the page, exports.
-- Server: runtime configuration for everyone or one player.
-- Page:   web/ (plain HTML/CSS/JS, no build step).
resource "op77_weaponhud"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

shared_script "shared/config.lua"
shared_script "shared/weaponhud.lua"

server_script "server/main.lua"

client_script "client/catalogue.lua"
client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    -- both sides: runtime configuration from the server
    "network.events",
    -- client
    "local.events",         -- op77_weaponhud:state to the gamemode, :inset / :labels from it
    "player.weapons.read",  -- Open77.weapons.snapshot (magazine, capacity, reserve, reload flag)
    "players.read",         -- Open77.players.isReloading / isInVehicle
    "input.actions",        -- menus holding the cursor (isCaptured)
    "ui.vanilla.hud",       -- the game's own weapon HUD is hidden
}
