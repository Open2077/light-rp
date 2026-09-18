-- Light Roleplay starter gamemode for OPEN//77.
--
-- Server-authoritative and deliberately small: a registered character name,
-- proximity IC chat with /me /do /ooc /try /roll, one civilian vehicle per
-- player, hospital respawn, saved last position, and a handful of ACL-gated
-- staff commands. Everything else (admin console, chat surface, voice, doors,
-- wardrobe, animations) comes from the official system resources listed in
-- server.jsonc. Read README.md before changing the permissions below.
resource "lightrp"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

dependencies {
    "open77_chat >=0.5.0",
    "open77_notifications >=1.0.0",
    "open77_vehicles >=0.1.0",
}

-- shared/config.lua is downloaded by clients: never put credentials in it.
shared_script "shared/config.lua"

server_script "server/persistence.lua"
server_script "server/chat.lua"
server_script "server/main.lua"

permissions {
    "network.events",       -- chat lines, command results, gameplayReady
    "local.events",         -- the cancellable chatMessage veto
    "world.vehicles",       -- /car and /dv
    "players.life.read",
    "players.life.kill",    -- the kill+respawn placement transaction
    "players.life.respawn",
    "players.life.revive",
    "players.teleport",     -- staff /lightrp.tp, bring, goto
    "players.damage.apply", -- staff /lightrp.heal
    "database.access",      -- characters, positions, reports (optional at runtime)
}
