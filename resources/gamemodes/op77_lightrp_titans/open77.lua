resource "op77_lightrp_titans"
version "1.0.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

-- Shared executable loaders (TweakXL, and the Open77 fork of ArchiveXL) this resource depends on. Both ride along as
-- required mods through the launcher preflight, so a server that loads op77_lightrp_titans must set requiredMods.unsecured.
-- The versions are the exact numeric loader versions published under resources/assets/loaders.
dependency "tweakxl >=1.12.0"
dependency "archivexl >=1.28.0"

-- controller/ (the author's controller, the bridge modules and their environment) is committed here, generated once by
-- Open77's scripts/titans/prepare_bt7274_package.py at Open77 commit c050d430a and maintained by hand since: there is no port
-- pipeline in this repository, so a fix to the controller is made in controller/*.lua itself. It is loaded by client.lua with
-- require. This resource must NEVER run on the same server as Open77's own open77_titans: both drive the game-side system
-- Open77TitanEvents (r6/scripts/open77_titans/Open77TitanEvents.reds), which has one owner per game.
--
-- catalog.lua (the controller's generated dictionaries) and loadout.lua (the perk ids and their levels) must come
-- first: shared.lua refuses to load without Open77TitanLoadout, and both halves refuse to start without
-- Open77TitanCatalog. Script entries are listed one by one; a glob that matches nothing would refuse the whole
-- session's set.
shared_script "catalog.lua"
shared_script "loadout.lua"
shared_script "shared.lua"
server_script "server.lua"
client_script "client.lua"

-- The generated controller and its modules are published for `require` (they run in this resource only), with the gameplay HUD
-- renderer and its font metrics; ui/ is the transparent HUD page it draws on: the canvas (hud.js) for what belongs to a point of
-- the picture, and the DOM panels (hud_panel.js, styled by hud.css) for the notices, the carry's prompt, the PROTOCOLS lamps and the
-- control hints (LightRP's own HUD shows the hull, the weapon, the abilities and the core, from the `hudState` client export). The
-- page's policy is strict: a font or a script is loaded only when it is listed in web_files.
files { "controller/*.lua", "render.lua", "ui/hud_font.lua" }
web_files {
    "ui/hud.html", "ui/hud.css", "ui/hud.js", "ui/hud_panel.js", "ui/hud_font.js",
    "ui/chakra-petch-500-latin.woff2", "ui/chakra-petch-600-latin.woff2",
    "ui/share-tech-mono-400-latin.woff2", "ui/OFL.txt",
}

-- network.events            frames, requests and the server's bridge messages
-- rtti.native               the controller's engine access (Open77.rtti) and the carry native (client; privileged,
--                           granted only to this reviewed resource in the lab server)
-- scheduler.dedicated       the controller's own frame time: the resource reserves its slice with
--                           Open77.scheduler.reserve and runs the controller from one SetTick per frame
-- players.life.read         dead/alive and V's current visibility before it is hidden
-- players.life.visibility   hide V's network body for other clients while piloting
-- players.local.visibility  hide the local avatar (third-person double) while piloting
-- world.npcs                carry an NPC and read its canonical place (server)
-- npcs.foreign              ... also one another resource created: a grab takes whatever NPC is in reach
-- world.vehicles            carry a vehicle and read its canonical state (server)
-- npcs.read                 resolve the body the controller grabbed to its replicated identity: an NPC's id and readiness
--                           (Open77.npcs.all, the server-owned set, no world query) (client)
-- vehicles.read             ... a vehicle's identity and readiness (client)
-- screen.capture            the display size the HUD draws in (Open77.screen.surface; nothing is captured)
-- players.stats.apply       Titan blows on players (Open77.players.damage under PvP rules)
-- input.actions             the player's two actions: rebindable keys `titans.bring` / `titans.cooldown`
permissions {
    "network.events", "rtti.native", "scheduler.dedicated",
    "players.life.read", "players.life.visibility", "players.local.visibility",
    "world.npcs", "npcs.foreign", "world.vehicles",
    "npcs.read", "vehicles.read", "players.stats.apply",
    "screen.capture", "input.actions"
}
