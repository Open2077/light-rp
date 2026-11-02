-- op77_arena: Light RP's arena activities -- Combat Zone (drop-in FFA), Blade Night
-- (melee FFA), duels (/duel <id>, best of three) and Team Arena (2v2 / 3v3) -- plus a
-- staff-run Arena Night. The Deathmatch PvP engine as Freeroam ships it (dist
-- 2.50.0+op77.177), hosted as a provider of Light RP's activity contract: Light RP
-- admits the player (activityCheck / activityEnter), the fight runs in the arena
-- buckets (4100000+), and activityLeave brings them back where they were.
--
-- The match HUD is Light RP's own (op77_lightrp client exports ActivityHud*): no page
-- here. reload_policy "local": Light RP returns the players of a stopped provider.
resource "op77_arena"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

dependencies {
    "op77_lightrp >=0.2.0",     -- the activity contract (exports, host-wide events, HUD)
    "open77_weapons >=0.1.0",   -- the weapon relay the arena loadouts are issued through
}

-- Engine first (kept close to upstream), then the Light RP edition's overrides.
shared_script "shared/config.lua"
shared_script "shared/kabuki.lua"
shared_script "shared/wire.lua"
shared_script "shared/lightrp.lua"

-- Engine load order (see server/main.lua), then the contract and the adapter.
server_script "server/instances.lua"
server_script "server/bounds.lua"
server_script "server/loadout.lua"
server_script "server/scoring.lua"
server_script "server/bots.lua"
server_script "server/round.lua"
server_script "server/arena.lua"
server_script "server/rating.lua"
server_script "server/ranked.lua"
server_script "server/main.lua"
server_script "server/core.lua"
server_script "server/lightrp.lua"

client_script "client/bounds.lua"
client_script "client/hud.lua"

permissions {
    "network.events",       -- engine state/notices/feed, command replies, weapon relay requests
    "local.events",         -- Light RP's host-wide activity events; client notice fallback
    "players.life.read",    -- life phase before every move; standing a downed player up
    "players.life.kill",    -- engine primitive, only for a body stuck "recovering" inside the arena
    "players.life.respawn", -- the dead respawn on their mark (and where they lie, before going home)
    "players.teleport",     -- the living are moved into and around the arena
    "players.damage.read",  -- health before a round starts
    "players.damage.apply", -- full health at each round start
    "players.stats.apply",  -- engine: bot hits on players (bots are off by default)
    "players.reflex.read",  -- engine: Overdrive readout in the Blade Night state (read only)
    "combat.config",        -- the instance damage gate (onDamage) and team assignment
    "world.npcs",           -- engine bots (off by default; staff /dm.bot)
    "database.access",      -- op77_arena_career / _rounds / _rating
    "player.travel",        -- client: the arena wall (small clamp corrections)
}
