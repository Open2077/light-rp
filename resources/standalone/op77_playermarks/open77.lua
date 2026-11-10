-- op77_playermarks: a nameplate above every other player's head in the Light RP
-- design (chamfered HUD chip, yellow accent, Chakra Petch), so a player tells people
-- from the city's NPCs at a glance; while that player talks on voice, its voice
-- bars light up and move with their level.
--
-- Client: a client with the plugin's native nameplate drawer (Open77.nameplates.style)
--         gets the Light RP look as a theme and draws the plates itself, glued to the body
--         and hidden behind walls; this resource only sets each player's label and hides
--         the ones it must (Open77.nameplates.set). A client without it (or config
--         native = false) draws them in a NativeUI document: the players around
--         (Open77.players.nearby), one Open77.anchors anchor on each body (projected every
--         frame by the plugin, read back to move the plate), the talkers
--         (Open77.voice.talkers). A player op77_map3d hides (a chase runner) gets no
--         plate either way.
-- UI:     ui/playermarks.rml + .rcss (NativeUI; no browser page since 0.3.0).
resource "op77_playermarks"
version "0.3.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a NativeUI document and its anchors: reconnect rather than live reload.
reload_policy "reconnect"

shared_script "shared/config.lua"

client_script "client/view.lua"
client_script "client/main.lua"

files {
    "ui/playermarks.rml",
    "ui/playermarks.rcss",
}

permissions {
    "network.client",   -- the local player id
    "voice.client",     -- who is talking around, and how loud (the document)
    "ui.nameplates",    -- the native drawer: theme, render, each player's label and visibility
    "input.actions",    -- the document steps aside while a menu holds the cursor (Open77.input.isCaptured)
}
