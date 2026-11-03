-- op77_chase: NCPD chases as Light RP activities, both in their own routing buckets
-- (4300000+), both queued from the Crossing (Light RP's hub) or a command:
--
--   chase.1v1     NCPD Chase - cop against runner, 1v1, by car or on foot, best of two
--                 rounds with swapped roles, Elo ladder (/chase). Port of Pursuit's rules.
--   chase.wanted  Most Wanted - one runner against 2-7 cops in waves, rising heat,
--                 roadblocks, a late extraction point; everyone runs once (/wanted).
--   chase.pve     NCPD Escape - one player or a crew, every human a runner, against NCPD
--                 bots scaled to the runners (/escape). Public, no switch.
--
-- Staff bot mode (Light RP's /lightrp.bots): one queued player starts a 1v1 or a Most
-- Wanted and bots (Open77 NPCs at the wheel of the match cars, or on foot) play the
-- missing roles; nothing is rated or recorded (server/bots.lua).
--
-- Light RP hands players over with activityEnter and takes them back with
-- activityLeave. The overlay is Light RP's own activity HUD (client exports
-- ActivityHudShow / Push / Clear, drawn in Light RP's design): this resource ships no
-- page, so it stays reload_policy "local" (Light RP returns a stopped provider's players).
resource "op77_chase"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

dependencies {
    "op77_lightrp >=0.2.0",           -- the activity contract (exports + host-wide events), the activity HUD
    "open77_notifications >=1.0.0",   -- Open77.notifications.send (server), show (client fallback)
}
-- op77_map3d is optional (runner's dot hidden from cops, extraction / sighting blips);
-- load it before this resource when present.

shared_script "shared/config.lua"

-- Load order is manifest order: pure modules first, the wiring last.
server_script "server/rules.lua"
server_script "server/elo.lua"
server_script "server/queue.lua"
server_script "server/core.lua"
server_script "server/world.lua"
server_script "server/bots.lua"
server_script "server/match.lua"
server_script "server/ranked.lua"
server_script "server/wanted_rules.lua"
server_script "server/wanted_lobby.lua"
server_script "server/wanted.lua"
server_script "server/pve.lua"
server_script "server/recap.lua" -- the board each result carries for Light RP's end-of-match recap
server_script "server/main.lua"
server_script "server/wanted_main.lua"
server_script "server/pve_main.lua"

client_script "client/view.lua"
client_script "client/main.lua"

permissions {
    "network.events",        -- op77_chase:hud / :queue / :feed to clients, :hudFeed back, command replies
    "local.events",          -- Light RP's host-wide activity events
    "players.life.read",     -- down = round lost; respawn before going home
    "players.life.respawn",  -- a player who went down is respawned on his next mark
    "players.life.freeze",   -- held on their marks during the countdown (cops until dispatch)
    "players.teleport",      -- placement on the marks, inside the match bucket
    "world.vehicles",        -- match cars and Most Wanted roadblocks, created in the match bucket and removed after; bot drivers (vehicles.ai)
    "world.npcs",            -- bots: NCPD cops and runners (npcs.create / tasks / presence / remove), in the match bucket
    "database.access",       -- op77_chase_ratings / op77_chase_matches (1v1 Elo)
}
