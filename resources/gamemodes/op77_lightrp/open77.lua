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
    "open77_tabletop_extra >=1.0.0",
    "open77_casino_slots >=1.0.0",
    "open77_casino_blackjack >=1.0.0",
    "open77_casino_fortune >=1.0.0",
    "open77_casino_pool >=1.0.0",
    "open77_chat >=0.5.0",
    "open77_notifications >=1.0.0",
    "open77_vehicles >=0.1.0",
    "open77_voice >=0.1.0",
    "open77_contextmenu >=1.3.0",
    "open77_animations >=1.0.0",
    "open77_icons >=1.0.0",
    "open77_weapons >=0.2.0",
    "open77_chimera >=1.0.0", -- the raid boss (server/modules/mission_chimera.lua)
    "open77_maneki >=1.0.0",  -- the Maneki-neko collectible's visual host (client/core/maneki.lua)
}

-- Downloaded by clients: never put credentials in shared/.
shared_script "shared/events.lua"
shared_script "shared/notice.lua"         -- another resource's notice in the page (exports notice / Notice)
shared_script "shared/safezones.lua"
shared_script "shared/mission_defs.lua"   -- authored missions: format + validation (editor, engine, page)
shared_script "shared/config.lua"
shared_script "shared/tutorial.lua"
shared_script "shared/items.lua"
shared_script "shared/board_games.lua"
shared_script "shared/board_games_rules.lua"
shared_script "shared/tabletop_extra.lua"
shared_script "shared/tabletop_extra_rules.lua"
shared_script "shared/casino_slots.lua"
shared_script "shared/casino_blackjack.lua"
shared_script "shared/casino_fortune.lua"
shared_script "shared/casino_pool.lua"
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
server_script "server/modules/zone_loading.lua" -- loading cover over zone changes (op77_loadscreen)
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
server_script "server/modules/tabletop_extra.lua"
server_script "server/modules/casino_slots.lua"
server_script "server/modules/casino_blackjack.lua"
server_script "server/modules/casino_fortune.lua"
server_script "server/modules/casino_pool.lua"
server_script "server/modules/board_games.lua"
server_script "server/modules/armament_store.lua"
server_script "server/modules/armament.lua"
server_script "server/modules/grenades.lua"
server_script "server/modules/hotbar.lua"
server_script "server/modules/tcg.lua"            -- Cyberpunk TCG (op77_tcg): sealed product as inventory items
server_script "server/modules/economy.lua"
server_script "server/config/economy.lua"         -- economy rules (docs/economy-balance.md)
server_script "server/modules/mission_pay.lua"    -- what a mission / gig pays: crew pot, cooldown, daily cap
server_script "server/modules/economy_sinks.lua"  -- hospital bill, fitting-room fee
server_script "server/modules/work_activity.lua"  -- paychecks only for active players (moved, worked, served)
server_script "server/modules/jobs.lua"
server_script "server/config/missions.lua"
server_script "server/modules/parties.lua"
server_script "server/modules/missions.lua"
server_script "server/modules/mission_chimera.lua"
server_script "server/modules/mission_engine.lua"  -- runtime of the authored missions
server_script "server/modules/mission_editor.lua"  -- storage + staff editor protocol (/lightrp.missions)
server_script "server/modules/mission_repay.lua"   -- /lightrp.missions.repay: stored missions to the new payout scale
server_script "server/config/fixers.lua"
server_script "server/modules/fixers.lua"          -- fixer gigs: offers by Neural-Link text, crews, meet point
server_script "server/config/world_bosses.lua"
server_script "server/modules/world_bosses.lua"    -- world bosses: open-world events from editor missions, shares by contribution
server_script "server/config/announce.lua"
server_script "server/modules/announce.lua"        -- staff voice announcements (/lightrp.broadcast): server-wide or within a radius
server_script "server/config/job_runs.lua"
server_script "server/config/delivery.lua"
server_script "server/modules/job_runs.lua"
server_script "server/config/job_work.lua"
server_script "server/modules/job_work.lua"
server_script "server/modules/tutorial.lua"
server_script "server/modules/tutorial_practice.lua"
server_script "server/modules/chat.lua"
server_script "server/modules/bubbles.lua"
server_script "server/modules/vehicles.lua"
server_script "server/modules/keys.lua"
server_script "server/modules/fuel.lua"
server_script "server/modules/rental.lua"
server_script "server/modules/wardrobe.lua"
server_script "server/modules/clothing.lua"
server_script "server/modules/consumables.lua"
server_script "server/modules/refueling.lua"
server_script "server/modules/medical_store.lua"
server_script "server/modules/medical.lua"
server_script "server/config/garages.lua"
server_script "server/config/vehicle_kit.lua"      -- Auto Studio rims + body kit catalogue (tools/build_vehicle_kit.py)
server_script "server/config/vehicle_kit_trims.lua" -- stock names each curated trim adds to the kit's hide lists
server_script "server/modules/garages.lua"
server_script "server/config/vehicle_customization.lua"
server_script "server/modules/vehicle_customization.lua"
server_script "server/config/dealerships.lua"
server_script "server/modules/dealerships.lua"
server_script "server/modules/showroom.lua"
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
server_script "server/modules/board_games_admin.lua" -- staff: placed tables list / go to / remove (/admin, /lightrp.tables)
server_script "server/config/maneki.lua"
server_script "server/modules/maneki.lua"          -- Maneki-neko collectibles: streamed near players, E or a shot, staff tool (/lightrp.maneki)
server_script "server/modules/housing_starter.lua"
server_script "server/modules/ui.lua"
server_script "server/modules/camera.lua"
server_script "server/config/cyberware.lua"
server_script "server/modules/cyberware.lua"
server_script "server/modules/cyberware_active.lua"  -- Berserk, Pain Editor, Second Heart, Kiroshi scan / crew mark
server_script "server/modules/cyberware_iconics.lua" -- iconic implants: drops from world bosses and the Chimera on Critical
server_script "server/modules/ripperdoc.lua"
server_script "server/modules/pose_ghost.lua"       -- held poses are non-solid to other players (no push out of an emote/seat)
server_script "server/config/activities.lua"
server_script "server/modules/activities.lua"      -- activity providers' contract: ownership, return, stats (exports)
server_script "server/modules/activity_queue.lua"  -- the queue panel: one queue per player (core, providers, mission boards), leave
server_script "server/modules/activity_pay.lua"    -- eddies for activity results (PvP ranked, PvE), caps and anti-farm
server_script "server/modules/activities_hub.lua"  -- The Crossing: terminals, contracts board, first-day pointer
server_script "server/config/halloffame.lua"
server_script "server/modules/halloffame.lua"     -- The Crossing: the Hall of Fame board and its boards
server_script "server/config/guide.lua"
server_script "server/modules/guide.lua"           -- Johnny at The Crossing: the FAQ dialogue (content in server/config/guide.lua)
server_script "server/config/guide_dialogue.lua"
server_script "server/modules/guide_dialogue.lua"  -- talking to Johnny: choices over the FAQ, GPS and panels (content in server/config/guide_dialogue.lua)
server_script "server/config/dogtown.lua"
server_script "server/modules/dogtown.lua"         -- Dogtown PvP zone: combat scopes, tags, cash bags, stats (/lightrp.dogtown)
server_script "server/modules/pvp_marks.lua"       -- who is in a PvP fight (Dogtown, PvP/chase activities): their nameplates hidden
server_script "server/config/events_board.lua"
server_script "server/modules/events_board_fonts.lua" -- the board page's fonts (design system, base64)
server_script "server/modules/events_board_page.lua"  -- the board page: HTML, CSS, JS
server_script "server/modules/events_board.lua"    -- The Crossing: the events board TV, its page and data over http.serve (/lightrp.board)
server_script "server/modules/recap.lua"           -- the end-of-match recap: activities, missions, world bosses (F1 > Last match)
server_script "server/config/titles.lua"
server_script "server/modules/titles.lua"          -- prestige titles: closed catalogue, earned per character, one shown by the name
server_script "server/config/dailies.lua"
server_script "server/modules/dailies.lua"         -- daily / weekly contracts told by the fixers (docs/dailies-titles.md)
server_script "server/modules/job_crew.lua"        -- jobs worked together: +15 % crew bonus, Big Contract premium
server_script "server/main.lua"

-- Client: core first, then modules.
client_script "client/core/state_json.lua"   -- native-first JSON for an oversized state key (ui.lua)
client_script "client/core/ui.lua"
client_script "client/core/control_claims.lua"
client_script "client/core/freecam_motion.lua" -- the flight step of the free camera and of the tables' free view
client_script "client/core/tabletop_extra.lua"
client_script "client/core/casino_slots.lua"
client_script "client/core/casino_blackjack.lua"
client_script "client/core/casino_fortune.lua"
client_script "client/core/casino_pool.lua"
client_script "client/core/board_games.lua"
client_script "client/core/table_menu.lua" -- the ALT menu of every table: management rows and notices (after board_games and the casino adapters)
client_script "client/core/table_bar.lua" -- the game view's bottom bar, per game (after table_menu)
client_script "client/core/safezones.lua"
client_script "client/core/vanilla_safe_areas.lua" -- the game's own safe areas stay off
client_script "client/core/safezone_tile.lua" -- the green tile by the voice plate (web/safezone/)
client_script "client/core/support.lua"
client_script "client/core/creator.lua"
client_script "client/core/tutorial_voice.lua"
client_script "client/core/tutorial.lua"
client_script "client/core/tutorial_context.lua"
client_script "client/core/weapon_hud.lua"
client_script "client/core/hud.lua"
client_script "client/core/map_icons.lua"
client_script "client/core/interact.lua"
client_script "client/core/weapon_wheel.lua"
client_script "client/core/map_places.lua"
client_script "client/core/homes.lua"
client_script "client/core/vehicle_gps.lua"
client_script "client/core/activities.lua"     -- Neural-Link app "Gigs & Arena", contract GPS
client_script "client/core/halloffame.lua"     -- ALT + click on the Hall of Fame board
client_script "client/core/events_board.lua"   -- the events board's page on the TV's screen at The Crossing
client_script "client/core/recap.lua"          -- the end-of-match recap, opened once back in the city
client_script "client/core/cyberware.lua"
client_script "client/core/wardrobe.lua"
client_script "client/core/keys.lua"
client_script "client/core/movement.lua"
client_script "client/core/camera.lua"
client_script "client/core/freecam.lua"
client_script "client/core/talkers.lua"
client_script "client/core/announce.lua"       -- the announcement halo's voice level (server/modules/announce.lua)
client_script "client/core/inventory.lua"
client_script "client/core/tcg.lua"               -- closes the inventory when the TCG page takes the mouse
client_script "client/core/armament.lua"
client_script "client/core/grenades.lua"
client_script "client/core/hotbar.lua"
client_script "client/core/branding.lua"
client_script "client/core/actions.lua"
client_script "client/core/activity_hud.lua"   -- shared in-match HUD of the activity providers (exports ActivityHud*)
client_script "client/core/medical.lua"
client_script "client/core/consumables.lua"
client_script "client/core/refueling.lua"
client_script "client/core/animations.lua"
client_script "client/core/job_runs.lua"
client_script "client/core/job_work.lua"
client_script "client/core/raid.lua"
client_script "client/core/mission_editor.lua"
client_script "client/core/mission_run.lua"
client_script "client/core/vehicle_context.lua"
client_script "client/core/crew.lua"            -- crews: ALT + click on players, invite keys (server/modules/parties.lua)
client_script "client/core/queue.lua"           -- the queue panel's leave key (server/modules/activity_queue.lua)
client_script "client/core/vehicle_customization.lua"
client_script "client/core/guide.lua"           -- the guide NPC: page relay with the player's keys, ALT + click on him
client_script "client/core/pvp_marks.lua"      -- nameplates (op77_playermarks) hidden in PvP
client_script "client/core/dogtown.lua"        -- Dogtown PvP zone: map pins, district probe for the staff survey
client_script "client/core/maneki.lua"         -- Maneki-neko collectibles: local props, E prompt, shot detection
client_script "client/core/maneki_editor.lua"  -- the staff placement tool for the cats
client_script "client/main.lua"

-- The global WebUI. Created by the client (web_ui_auto_create false) so the
-- surface has the layer, size and fps the framework wants.
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

-- Pause menu branding: the server logo beside the OPEN//77 mark (client/core/branding.lua sets the accent).
pause_menu_logo "assets/logo.png"
files { "assets/logo.png", "assets/audio/cloudy-day.mp3", "assets/audio/raid_*.wav", "assets/audio/raid_ost.mp3", "assets/audio/board-games/*.wav" }

permissions {
    -- both sides
    "network.events",
    "local.events",
    -- server
    "world.vehicles",
    "world.vehicles.appearance", -- Auto Studio factory trims: setAppearance to a curated variant, and its rollback (a restatement needs no grant)
    "world.props",          -- networked jerrycan, cleaned up with the action
    "state.write",          -- vehicle keys live in state bags
    "players.life.read",
    "players.life.ghost",          -- pose_ghost: a held pose is non-solid to other players
    "players.life.kill",
    "players.life.revive",
    "players.life.respawn",
    "players.teleport",
    "players.damage.apply",
    "world.effects",        -- the raid's strikes: replicated explosions in the arena bucket
    "world.explosions",     -- ... that hurt the operators standing in them
    "combat.config",        -- pre-hit, server-authoritative safezone policy
    "combat.scope.control", -- Dogtown: PvP grants for the players inside (global friendly fire stays off)
    "players.stats.read",
    "players.stats.apply",         -- cyberware passives: health/stamina maxima and regeneration
    "players.life.falldamage",     -- cyberware: Fortified Ankles
    "players.cyberware.define",    -- cyberware: Reinforced Tendons, Gorilla Arms (durable implants)
    "players.cyberware.read",
    "players.cyberware.manage",
    "players.dash.define",         -- cyberware: Neofiber (Dash / Air Dash)
    "players.dash.manage",
    "players.dash.read",
    "players.abilities.define",    -- cyberware: Kinetic Impact Frame (Ground Slam)
    "players.abilities.manage",
    "players.abilities.read",
    "players.reflex.define",       -- cyberware: Sandevistan (reflex overdrive)
    "players.reflex.manage",
    "players.reflex.read",
    "players.animations.read",
    "players.animations.control",
    "database.access",
    "acl.read",
    "players.disconnect",
    "players.access",
    "voice.manage",        -- staff announcements: one admin voice channel per speaker
    "http.serve",          -- the events board's page and data (server/modules/events_board.lua; server config httpHandlers)
    -- client
    "voice.client",        -- guided setup through the trusted preference owner
    "network.client",      -- local player ID + authenticated account for animation state/preferences
    "input.actions",
    "session.menus",        -- Open77.session.isMenuOpen: table keys (and the free camera) ignore input under a menu
    "webui.keep_input",     -- the F1 menu takes the keyboard while the player keeps walking
    "world.npcs",           -- rental desks, blackjack croupiers (create, setAIEnabled, remove) are NPCs
    "world.markers",        -- native 3D markers at rental desks and the raid's strike telegraphs
    "world.debug",          -- staff-only draft boundary preview, authored missions' perimeter walls, board-game axis/square lines
    "world.query",          -- mission editor aimRay; board placement and pointer projection
    "ui.vanilla.map",       -- map blips on the interaction points
    "vehicles.read",        -- closest vehicle / seat for the L key
    "players.controls",     -- walk modes (Open77.movement.setWalkMode)
    "players.read",         -- free camera: on foot or in a vehicle (Open77.players.isInVehicle)
    "camera.script",        -- arrival cinematic, including complete local body
    "players.local.visibility", -- Auto Studio: hide the player's own avatar from the orbit camera (this screen only)
    "player.freeze",        -- creator owns/releases only its local freeze claim
    "world.environment",    -- noon/sun only in the private creation bucket
    "audio.play",           -- local, quiet creation soundtrack
    "screen.read",          -- wait for native loading before revealing the scene (and the raid's arena)
    "player.appearance.read", -- observe native editor lifetime before restoring the cinematic
    "ui.vanilla.hud",
    "camera.style",         -- the dynamic shoulder camera by default, /camchange (client/core/camera.lua)
    "player.weapons.read", -- read-only magazine and reload HUD snapshots
    "player.aim.read",      -- Maneki-neko: a shot is the trigger held with a weapon drawn (client/core/maneki.lua)
    "pause_menu.customize", -- accent + logo of the pause menu
    "map.control",          -- title + accent of the native map
}
