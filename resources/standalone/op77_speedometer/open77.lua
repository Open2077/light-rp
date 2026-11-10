-- op77_speedometer: a holographic speedometer floating at the bottom right of the screen
-- while the player drives (speed in segment digits, gear, RPM strip, speed bar, handbrake,
-- ABS, traction, lights, engine and fuel), in the LightRP black-and-yellow style. It
-- replaces the game's speedometer, and LightRP's own vehicle cluster stands down while it
-- runs (op77_speedometer:state). Configuration: shared/config.lua; API: README.md.
--
-- Client: reads the seat and the car, drives the NativeUI document (client/ui.lua), exports.
-- Server: runtime configuration for everyone or one player.
-- HUD:    ui/speedometer.rml + .rcss, drawn by NativeUI (Open77.ui, no browser).
resource "op77_speedometer"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a NativeUI document: reconnect rather than live reload.
reload_policy "reconnect"

shared_script "shared/config.lua"
shared_script "shared/speedo.lua"

server_script "server/main.lua"

client_script "client/ui.lua"
client_script "client/main.lua"

files {
    "ui/*.rml",
    "ui/*.rcss",
    "ui/fonts/*",
}

permissions {
    -- both sides: runtime configuration from the server; the fuel state bag
    "network.events",
    -- client
    "local.events",      -- op77_speedometer:state to the gamemode
    "vehicles.read",     -- the seat and the car (speed, gear, rpm, flags, damage)
    "input.actions",     -- handbrake keys, menus holding the cursor (isCaptured)
    "ui.vanilla.hud",    -- the game's own speedometer is hidden
}
