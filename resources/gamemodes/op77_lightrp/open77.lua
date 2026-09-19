-- op77_lightrp: the Light Roleplay framework of Open//77 Official Roleplay.
--
-- One package, three sides:
--   server/  core (module registry, actions, commands, persistence) + modules
--   client/  core (the single WebUI surface, HUD sampling, keys) + modules
--   web/     the built React/TypeScript page (source in ../../../ui, `npm run build`)
-- Read README.md before touching the permissions.
resource "op77_lightrp"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
-- The page owns WebUI surfaces: a live reload would leave a stale surface.
reload_policy "reconnect"

dependencies {
    "open77_chat >=0.5.0",
    "open77_notifications >=1.0.0",
    "open77_vehicles >=0.1.0",
    "open77_voice >=0.1.0",
}

-- Downloaded by clients: never put credentials in shared/.
shared_script "shared/events.lua"
shared_script "shared/config.lua"

-- Server: core first, then modules (each registers itself with LightRP.module).
server_script "server/core/framework.lua"
server_script "server/core/persistence.lua"
server_script "server/core/interact.lua"
server_script "server/modules/characters.lua"
server_script "server/modules/needs.lua"
server_script "server/modules/economy.lua"
server_script "server/modules/chat.lua"
server_script "server/modules/vehicles.lua"
server_script "server/modules/keys.lua"
server_script "server/modules/rental.lua"
server_script "server/modules/wardrobe.lua"
server_script "server/modules/staff.lua"
server_script "server/modules/ui.lua"
server_script "server/main.lua"

-- Client: core first, then modules.
client_script "client/core/ui.lua"
client_script "client/core/hud.lua"
client_script "client/core/interact.lua"
client_script "client/core/keys.lua"
client_script "client/main.lua"

-- The global WebUI. Created by the client (web_ui_auto_create false) so the
-- surface has the layer, size and fps the framework wants.
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
    -- both sides
    "network.events",
    "local.events",
    -- server
    "world.vehicles",
    "state.write",          -- vehicle keys live in state bags
    "players.life.read",
    "players.life.kill",
    "players.life.revive",
    "players.life.respawn",
    "players.teleport",
    "players.damage.apply",
    "players.stats.read",
    "database.access",
    "acl.read",
    -- client
    "input.actions",
    "webui.keep_input",     -- the F1 menu takes the keyboard while the player keeps walking
    "world.npcs",           -- rental desks are NPCs
    "world.markers",        -- native 3D markers at rental desks
    "ui.vanilla.map",       -- map blips on the interaction points
    "vehicles.read",        -- closest vehicle / seat for the L key
    "ui.vanilla.hud",
}
