-- op77_turf: Turf War, a Light RP activity (turf.war, kind pvp), and Gang Sweep
-- (turf.pve, kind event), its public PvE variant against an NPC gang. An instanced king of
-- the hill between the two most represented gangs of the queue, in a copy of a real
-- district: hold the capture zones, out-score the rival crew. Everyone else signs on
-- as a mercenary. Engine-native kits, nothing persists, no cash, no items: results
-- become reputation through Light RP, and a weekly gang influence table
-- (op77_turf_influence) says who holds the city.
--
-- Server: activity adapter (core.lua), rules (rules.lua), war lifecycle (war.lua),
--         natives (world.lua), NPC bots (bots.lua: staff bot mode, the sweep's gang),
--         weekly influence + exports (influence.lua), wiring.
-- Client: Light RP's shared activity HUD (op77_lightrp client exports), zone markers,
--         op77_map3d zone blips, the kit key.
resource "op77_turf"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- No WebUI surface of its own: a live reload is safe. Light RP returns the fighters of
-- a stopped provider itself.
reload_policy "local"

-- No hard dependency on op77_lightrp: when the core stops this resource keeps running,
-- voids the war and registers again when the core returns. Load it after op77_lightrp
-- (and op77_map3d, op77_loadscreen, which are optional).
dependencies {
    "open77_notifications >=1.0.0",   -- Open77.notifications.send
    "open77_weapons >=0.2.0",         -- Open77.weapons: the war kits
}

shared_script "shared/config.lua"

-- Load order is manifest order: pure modules first, the wiring last.
server_script "server/rules.lua"
server_script "server/core.lua"
server_script "server/world.lua"
server_script "server/bots.lua"
server_script "server/influence.lua"
server_script "server/war.lua"
server_script "server/main.lua"

client_script "client/hud.lua"
client_script "client/main.lua"

permissions {
    -- server
    "network.events",        -- war state to the fighters, notifications, Open77.weapons (kits)
    "local.events",          -- Light RP's host-wide activity events, announcements
    "players.life.read",     -- life phases (deaths, respawns), Open77.players.get (survey heading)
    "players.life.respawn",  -- fallen fighters back at their spawn or a held zone
    "players.life.freeze",   -- fighters held on their spawn during the countdown
    "players.teleport",      -- placement inside the war bucket, out-of-bounds return
    "combat.config",         -- Open77.combat.setTeam (no friendly fire), onDamage/offDamage (war arbiter)
    "combat.scope.control",  -- Open77.combat.createScope/removeScope: PvP between the fighters only
    "database.access",       -- op77_turf_influence / op77_turf_wars (weekly gang influence)
    "world.npcs",            -- Open77.npcs: the bots of staff bot mode and the Gang Sweep's NPC gang
    "players.stats.apply",   -- Open77.players.damage: a bot's checked, clamped hit on a fighter
    -- client
    "world.markers",         -- zone rings and beacons
    "input.actions",         -- the rebindable kit key (RegisterKeyMapping, input.keyFor)
}
