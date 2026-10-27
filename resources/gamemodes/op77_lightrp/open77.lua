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
    "open77_board_games >=1.1.0",
    "open77_chat >=0.5.0",
    "open77_notifications >=1.0.0",
    "open77_vehicles >=0.1.0",
    "open77_voice >=0.1.0",
    "open77_contextmenu >=1.2.0",
    "open77_animations >=1.0.0",
    "open77_icons >=1.0.0",
    "open77_weapons >=0.2.0",
}

-- Downloaded by clients: never put credentials in shared/.
shared_script "shared/events.lua"
shared_script "shared/safezones.lua"
shared_script "shared/config.lua"
shared_script "shared/tutorial.lua"
shared_script "shared/items.lua"
shared_script "shared/board_games.lua"
shared_script "shared/board_games_rules.lua"
shared_script "shared/medical.lua"
shared_script "shared/armament.lua"
shared_script "shared/grenades.lua"
shared_script "shared/consumables.lua"
shared_script "shared/fuel.lua"
shared_script "shared/jobs.lua"
shared_script "shared/vehicle_context.lua"
shared_script "shared/vehicle_customization.lua"

-- Server: core first, then modules (each registers itself with LightRP.module).
server_script "server/core/framework.lua"
server_script "server/core/persistence.lua"
server_script "server/modules/safezones_store.lua"
server_script "server/modules/safezones.lua"
server_script "server/modules/safezones_admin.lua"
server_script "server/core/interact.lua"
server_script "server/modules/characters.lua"
server_script "server/modules/neuralink_bridge.lua"
server_script "server/modules/creator.lua"
server_script "server/modules/creator_placement.lua"
server_script "server/modules/needs.lua"
server_script "server/modules/inventory.lua"
server_script "server/modules/board_games.lua"
server_script "server/modules/armament_store.lua"
server_script "server/modules/armament.lua"
server_script "server/modules/grenades.lua"
server_script "server/modules/hotbar.lua"
server_script "server/modules/economy.lua"
server_script "server/modules/jobs.lua"
server_script "server/config/job_runs.lua"
server_script "server/modules/job_runs.lua"
server_script "server/config/job_work.lua"
server_script "server/modules/job_work.lua"
server_script "server/modules/tutorial.lua"
server_script "server/modules/tutorial_practice.lua"
server_script "server/modules/chat.lua"
server_script "server/modules/vehicles.lua"
server_script "server/modules/keys.lua"
server_script "server/modules/fuel.lua"
server_script "server/modules/rental.lua"
server_script "server/modules/wardrobe.lua"
server_script "server/modules/consumables.lua"
server_script "server/modules/refueling.lua"
server_script "server/modules/medical_store.lua"
server_script "server/modules/medical.lua"
server_script "server/config/garages.lua"
server_script "server/modules/garages.lua"
server_script "server/config/vehicle_customization.lua"
server_script "server/modules/vehicle_customization.lua"
server_script "server/config/dealerships.lua"
server_script "server/modules/dealerships.lua"
server_script "server/config/shops.lua"
server_script "server/modules/shops.lua"
server_script "server/modules/vehicle_context.lua"
server_script "server/modules/staff.lua"
server_script "server/config/support.lua"
server_script "server/modules/support.lua"
server_script "server/modules/admin.lua"
server_script "server/config/housing.lua"
server_script "server/modules/housing_store.lua"
server_script "server/modules/housing.lua"
server_script "server/modules/housing_admin.lua"
server_script "server/modules/housing_starter.lua"
server_script "server/modules/ui.lua"
server_script "server/main.lua"

-- Client: core first, then modules.
client_script "client/core/ui.lua"
client_script "client/core/control_claims.lua"
client_script "client/core/board_games.lua"
client_script "client/core/safezones.lua"
client_script "client/core/support.lua"
client_script "client/core/creator.lua"
client_script "client/core/tutorial_voice.lua"
client_script "client/core/tutorial.lua"
client_script "client/core/tutorial_context.lua"
client_script "client/core/weapon_hud.lua"
client_script "client/core/hud.lua"
client_script "client/core/interact.lua"
client_script "client/core/homes.lua"
client_script "client/core/keys.lua"
client_script "client/core/movement.lua"
client_script "client/core/freecam.lua"
client_script "client/core/talkers.lua"
client_script "client/core/inventory.lua"
client_script "client/core/armament.lua"
client_script "client/core/grenades.lua"
client_script "client/core/hotbar.lua"
client_script "client/core/branding.lua"
client_script "client/core/actions.lua"
client_script "client/core/medical.lua"
client_script "client/core/consumables.lua"
client_script "client/core/refueling.lua"
client_script "client/core/animations.lua"
client_script "client/core/job_runs.lua"
client_script "client/core/job_work.lua"
client_script "client/core/vehicle_context.lua"
client_script "client/core/vehicle_customization.lua"
client_script "client/main.lua"

-- The global WebUI. Created by the client (web_ui_auto_create false) so the
-- surface has the layer, size and fps the framework wants.
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

-- Pause menu branding: the server logo beside the OPEN//77 mark (client/core/branding.lua sets the accent).
pause_menu_logo "assets/logo.png"
files { "assets/logo.png", "assets/audio/cloudy-day.mp3", "assets/audio/board-games/*.wav" }

permissions {
    -- both sides
    "network.events",
    "local.events",
    -- server
    "world.vehicles",
    "world.props",          -- networked jerrycan, cleaned up with the action
    "state.write",          -- vehicle keys live in state bags
    "players.life.read",
    "players.life.kill",
    "players.life.revive",
    "players.life.respawn",
    "players.teleport",
    "players.damage.apply",
    "combat.config",        -- pre-hit, server-authoritative safezone policy
    "players.stats.read",
    "players.animations.read",
    "players.animations.control",
    "database.access",
    "acl.read",
    "players.disconnect",
    "players.access",
    -- client
    "voice.client",        -- guided setup through the trusted preference owner
    "network.client",      -- local player ID + authenticated account for animation state/preferences
    "input.actions",
    "webui.keep_input",     -- the F1 menu takes the keyboard while the player keeps walking
    "world.npcs",           -- rental desks are NPCs
    "world.markers",        -- native 3D markers at rental desks
    "world.debug",          -- staff-only draft boundary preview
    "world.query",          -- board placement and pointer projection
    "ui.vanilla.map",       -- map blips on the interaction points
    "vehicles.read",        -- closest vehicle / seat for the L key
    "players.controls",     -- walk modes (Open77.movement.setWalkMode)
    "players.read",         -- free camera: on foot or in a vehicle (Open77.players.isInVehicle)
    "camera.script",        -- arrival cinematic, including complete local body
    "player.freeze",        -- creator owns/releases only its local freeze claim
    "world.environment",    -- noon/sun only in the private creation bucket
    "audio.play",           -- local, quiet creation soundtrack
    "screen.read",          -- wait for native loading before revealing the scene
    "player.appearance.read", -- observe native editor lifetime before restoring the cinematic
    "ui.vanilla.hud",
    "player.weapons.read", -- read-only magazine and reload HUD snapshots
    "pause_menu.customize", -- accent + logo of the pause menu
    "map.control",          -- title + accent of the native map
}
