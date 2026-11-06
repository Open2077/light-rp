-- op77_race: street races, rooftop races and time trials for Light RP, as activities of
-- the Light RP activity contract (op77_lightrp). Freeroam's race engine without
-- Freeroam: admission and return go through Light RP, each race runs in its own
-- routing bucket (4200000+), cars are loaners removed at the end, nothing is handed
-- out (no implants, no weapons; only the parkour race lends double jump and dash, for
-- the race) and results earn proposed reputation, never money.
--
-- Server: activity adapter, instances (engine), queues (lobby), courses, best times,
--         staff course editor, commands.
-- Client: the race drawn by Light RP's activity HUD (op77_lightrp client exports
--         ActivityHud*), checkpoint markers, op77_map3d blip + GPS, sounds,
--         rebindable keys, editor preview. No page of its own: /race opens Light RP's
--         Activities panel.
resource "op77_race"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
-- Key mappings and native markers are registered once per client session.
reload_policy "reconnect"

-- No hard dependency on op77_lightrp: when the core stops this resource keeps running,
-- sends its racers back itself and registers again when the core returns. Load it
-- after op77_lightrp (and op77_map3d, op77_loadscreen, which are optional).
dependency "open77_notifications >=1.0.0"

shared_script "shared/config.lua"
shared_script "shared/race.lua"

server_script "server/builtin_courses.lua"
server_script "server/courses.lua"
server_script "server/records.lua"
server_script "server/activity.lua"
server_script "server/engine.lua"
server_script "server/bots.lua"
server_script "server/parkour.lua"
server_script "server/lobby.lua"
server_script "server/editor.lua"
server_script "server/main.lua"

client_script "client/markers.lua"
client_script "client/main.lua"

permissions {
    -- both sides
    "network.events",       -- state and queue to the racer, keys to the server, notifications
    -- server
    "world.vehicles",       -- loaner cars: create, hold (flags), seat, forced exit, remove;
                            --   bot cars: Open77.vehicles.ai (attachDriver, followRoute...)
    "world.npcs",           -- bot drivers and runners (staff bot mode): create, tasks, remove
    "world.effects",        -- server: checkpoint firework (Open77.effects.play); client: sfx / vfx
    "players.teleport",     -- runners to the start line / last checkpoint; fallback return
    "players.life.read",    -- life state (death in a race, readiness)
    "players.life.respawn", -- a dead racer back at the last checkpoint
    "players.life.freeze",  -- runners held on the line until GO
    "players.stats.read",   -- Open77.players.getHealth (god mode before the race)
    "players.stats.apply",  -- Open77.players.setGodMode (gated by either of these two,
    "players.damage.apply", --   depending on the build)
    "players.dash.define",  -- parkour race: its dash (a session grant)
    "players.dash.manage",
    "players.dash.read",
    "players.cyberware.define",    -- parkour race: its double jump (legs, a temporary lease)
    "players.cyberware.read",
    "players.cyberware.temporary", -- never players.cyberware.manage: nothing owned can change
    "filesystem.read",      -- data/courses, data/records.json
    "filesystem.write",
    -- client
    "world.markers",        -- checkpoint chevrons / rings, editor preview
    "input.actions",        -- rebindable keys (RegisterKeyMapping, input.keyFor)
}
