resource 'open77_lobby_cubes'
version '0.2.0'
auto_start true

-- zone.lua and cubes.json are written by the map's generator (tools/gen.py of the lobby project).
shared_script 'zone.lua'
server_script 'server.lua'
client_script 'client.lua'
files { 'cubes.json' }

permissions {
    'world.markers', 'world.props',     -- client: the moving halos / cubes
    'world.environment',                -- server: night and clear sky in the lobby's bucket
}
