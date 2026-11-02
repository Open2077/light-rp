-- op77_chase: NCPD Chase, a Light RP activity. Cop against runner, 1v1, by car or on
-- foot, best of two rounds with swapped roles. Port of the Pursuit gamemode's rules onto
-- Light RP's activity contract: players queue from the Crossing (or /chase), Light RP
-- hands them over with activityEnter, the chase runs in its own routing bucket
-- (4300000+), and activityLeave brings them back where they were.
--
-- Server only. The overlay is op77_chase_hud (a WebUI surface needs reload_policy
-- "reconnect"; this one stays "local" so a fix reloads without reconnecting anyone:
-- Light RP returns the players of a stopped provider itself).
resource "op77_chase"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

dependencies {
    "op77_lightrp >=0.2.0",           -- the activity contract (exports + host-wide events)
    "open77_notifications >=1.0.0",   -- Open77.notifications.send
}

shared_script "shared/config.lua"

-- Load order is manifest order: pure modules first, the wiring last.
server_script "server/rules.lua"
server_script "server/elo.lua"
server_script "server/queue.lua"
server_script "server/core.lua"
server_script "server/world.lua"
server_script "server/match.lua"
server_script "server/ranked.lua"
server_script "server/main.lua"

permissions {
    "network.events",        -- the overlay (op77_chase:hud / op77_chase:queue), command replies
    "local.events",          -- Light RP's host-wide activity events
    "players.life.read",     -- down = round lost; respawn before going home
    "players.life.respawn",  -- a player who went down is respawned on his next mark
    "players.life.freeze",   -- both held on their marks during the countdown
    "players.teleport",      -- placement on the marks, inside the match bucket
    "world.vehicles",        -- the two match cars, created in the match bucket and removed after
    "database.access",       -- op77_chase_ratings / op77_chase_matches (Elo)
}
