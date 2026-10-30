-- op77_scenes -- the LightRP edition of the platform's open77_scenes: synchronized
-- RP scenes on the world's furniture (first: lie down on a ripperdoc's surgical
-- chair -- sit down, seated loops, get up), seen the same by every player in the
-- bucket, late joiners included. Same server half; the prompt is LightRP's own "E"
-- (op77_lightrp export InteractSetLocal, the shops' keycap) instead of
-- open77_interactions, and /scene /standup are staff only. Do NOT load it next to
-- open77_scenes: both would claim the same chairs. README.md.
resource "op77_scenes"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

-- The client half owns E points in op77_lightrp's VM; a live swap would leave
-- them pointing at a VM that no longer exists.
reload_policy "local"

dependency "open77_animations >=1.0.0"
dependency "op77_lightrp >=0.2.0"

shared_script "shared/scenes.lua"
server_script "server/spots-generated.lua"
server_script "server/core.lua"
server_script "server/main.lua"
client_script "client/main.lua"

permissions {
    -- Both halves: spots / state / refused to one client; start / stand / idle / sync from it.
    "network.events",
    -- Server: Open77.animations.sequenceAt / stopAt for the scenes this resource starts.
    "players.animations.control",
    -- Server: Open77.animations.current -- a player already in an animation is refused.
    "players.animations.read",
    -- Server: the life half of Open77.players.get (alive, dead).
    "players.life.read",
    -- Server: the seat half of Open77.players.get (inVehicle).
    "world.vehicles",
    -- Server: Open77.players.setHeading -- the waiting body turns to where the get-up ends.
    "players.teleport",
    -- Client: Open77.input.registerKeyMapping for the get-up and change-pose keys.
    "input.actions",
    -- Client: Open77.hud.notify for hints and refusals.
    "ui.vanilla.hud",
}
