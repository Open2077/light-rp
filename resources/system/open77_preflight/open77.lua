-- open77_preflight: the server check every server ships with.
--
-- When a player presses Join in the OPEN//77 launcher, the launcher asks this server
-- "may this player come in?" before it starts the game (wiki/connection-preflight.md).
-- This resource is the default answer: a welcome screen on the server's page, proper
-- pages for the door list's refusals (Warden bans and the whitelist), and optional
-- steps switched on in config.lua -- rules to accept, a linked Discord account, a
-- whitelist application form, a maintenance mode, a "server full" waiting screen.
--
-- It owns nothing of its own: bans and the whitelist are the server's door list
-- (access.json), the one Warden and the console edit. Other resources reach the same
-- list through this resource's exports (see README.md).
--
-- A server.jsonc that does not name "preflight.resource" uses this resource. To hand
-- preflight to a resource of your own, name it there; this one then keeps its exports
-- and stays out of the way.
resource "open77_preflight"
version "1.1.0"
open77_version ">=0.0.1"
auto_start true
reload_policy "local"

-- Manifest order is load order: the settings, the rules memory, the flow, the exports.
server_script "config.lua"
server_script "server/store.lua"
server_script "server/main.lua"
server_script "server/exports.lua"

-- Comment only. It lets resources that have client scripts depend on this one.
client_script "client/marker.lua"

-- players.preflight:  own the launcher's server check (Open77.preflight).
-- players.access:     read and edit the door list (Open77.access) and hear onAccessChanged.
-- players.disconnect: the `kick` export removes a player who is already in game.
permissions { "players.preflight", "players.access", "players.disconnect" }

-- Images a launcher may fetch at /preflight/v1/assets/<path> (png, jpeg, webp). They are
-- public. Put yours in ui/custom/ and reference them from a screen as
-- src="asset:ui/custom/logo.png" (config.lua's ui section).
preflight_files { "ui/custom/*.png", "ui/custom/*.jpg", "ui/custom/*.jpeg", "ui/custom/*.webp" }
