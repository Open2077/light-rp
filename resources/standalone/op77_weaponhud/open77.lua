-- op77_weaponhud: a holographic weapon HUD floating at the bottom left while a weapon is drawn
-- (name, class and type, the magazine in seven-segment digits, the reserve, a magazine bar
-- that empties shot by shot, low-ammo and RELOAD warnings, the reload), in the LightRP
-- black-and-yellow style, the mirror of op77_speedometer. It replaces the game's ammo
-- counter, and LightRP's own weapon readout stands down while it runs
-- (op77_weaponhud:state). Configuration: shared/config.lua; API: README.md.
--
-- Client: reads the drawn weapon, drives the NativeUI document (client/ui.lua), exports.
-- Server: runtime configuration for everyone or one player.
-- HUD:    ui/weaponhud.rml + .rcss, drawn by NativeUI (Open77.ui, no browser).
resource "op77_weaponhud"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a NativeUI document: reconnect rather than live reload.
reload_policy "reconnect"

shared_script "shared/config.lua"
shared_script "shared/weaponhud.lua"

server_script "server/main.lua"

client_script "client/catalogue.lua"
client_script "client/ui.lua"
client_script "client/main.lua"

files {
    "ui/*.rml",
    "ui/*.rcss",
    "ui/fonts/*",
}

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
