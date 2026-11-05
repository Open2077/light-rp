-- op77_games: minigames for Light RP, as activities of the Light RP activity contract
-- (op77_lightrp). Each match runs in its own routing bucket (4500000-4599999), nothing is
-- paid or recorded, the end of a match is Light RP's recap. A new game is one file in
-- server/modes/ (the contract is at the top of server/engine.lua), its server_script line
-- below, its maps in shared/maps/.
--
-- Server: activity adapter, engine (instances, exits, clock), combat (scopes, arbiter,
--         weapons), lobby (queues), modes.
-- Client: Light RP's activity HUD and sounds. No page of its own.
resource "op77_games"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local" -- Light RP returns the players of a stopped provider

-- No hard dependency on op77_lightrp: when the core stops this resource keeps running,
-- closes its matches and registers again when the core returns. Load it after op77_lightrp.
dependencies {
    "open77_weapons >=0.1.0", -- the weapon relay the loadouts are issued through
    "open77_props >=0.1.0",   -- the client projection of the props a prop hunt wears
}

shared_script "shared/config.lua"
shared_script "shared/maps/tdm.lua"
shared_script "shared/maps/redlight.lua"
shared_script "shared/maps/gungame.lua"
shared_script "shared/maps/control.lua"
shared_script "shared/maps/ctf.lua"
shared_script "shared/maps/prophunt.lua"

server_script "server/activity.lua"
server_script "server/engine.lua"
server_script "server/combat.lua"
server_script "server/lobby.lua"
server_script "server/modes/tdm.lua"
server_script "server/modes/redlight.lua"
server_script "server/modes/gungame.lua"
server_script "server/modes/control.lua"
server_script "server/modes/ctf.lua"
server_script "server/modes/prophunt.lua"
server_script "server/main.lua"

client_script "client/objectives.lua"
client_script "client/prophunt.lua"
client_script "client/main.lua"

files { "audio/*.wav" }

permissions {
    -- both sides
    "network.events",       -- HUD and cues to the player, "ready" to the server, the weapon relay
    -- server
    "player.weapons.read",  -- Open77.weapons.get: a late removal touches only what we gave
    "players.life.read",    -- life phase before every move, Open77.players.get
    "players.life.respawn", -- a dead player back on a spawn, in the match's bucket
    "players.life.freeze",  -- held on the spawn until GO
    "players.life.kill",    -- out of bounds past the grace
    "players.teleport",     -- the living into and around a match; the fallback return
    "players.stats.read",   -- Open77.players.getHealth (either spelling, depending on the build)
    "players.damage.read",
    "players.stats.apply",  -- Open77.players.setHealth: full health at the start
    "players.damage.apply",
    "players.dash.define",  -- gun game: its dash, a session grant (live setting DASH_gungame)
    "players.dash.manage",
    "players.dash.read",
    "players.screenfx",     -- Open77.effects.screen: the flinch of the one sent back on red
    "combat.config",        -- the damage arbiter (onDamage) and sides (setTeam)
    "combat.scope.control", -- Open77.combat.createScope/removeScope: PvP inside one match only
    "world.props",          -- prop hunt: the object a prop wears (create, attach, remove)
    "world.effects",        -- prop hunt: sparks where a prop is hit
    "players.life.visibility", -- prop hunt: the hidden body
    "audio.network",        -- prop hunt: the whistle, heard in the match's bucket
    -- client
    "players.local.visibility", -- prop hunt: the body on its own screen (looked up, newer than the devkit)
    "perspective.policy",   -- prop hunt: third person locked for a prop, first for a hunter
    "input.actions",        -- prop hunt: its keys, a prop's attack blocked
    "ui.vanilla.hud",       -- prop hunt: no scanner in the round
    "audio.play",           -- Open77.audio.play2D: Light RP's sounds
    "world.markers",        -- control's ring, CTF's bases and flags, for one match's players only
    "ui.vanilla.map",       -- the same objectives as map pins
}
