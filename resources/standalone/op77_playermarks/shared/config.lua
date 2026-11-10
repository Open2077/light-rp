-- op77_playermarks settings (client side).
PlayerMarksConfig = {
    enabled = true,
    -- Draw with the plugin's own nameplate drawer when the client has it (Open77.nameplates.style):
    -- glued to the body, hidden behind walls. false draws the same plates with the NativeUI
    -- document (ui/playermarks.rml) on every client, as a client without that drawer always
    -- does (no occlusion there).
    native = true,
    -- Players within this many metres get a plate (the anchor stops reporting past it; the
    -- native theme's maxDistance).
    radius = 35.0,
    -- At most this many plates in the document (the plugin allows 32 anchors per resource).
    -- The native drawer has no such cap.
    max = 24,
    -- Metres above the body's origin (the feet): the plate's pin, just over the head
    -- (2.12 floated a hand's width too high in game). The native drawer anchors at 1.92 itself
    -- (lower when crouched): the theme's offset is the difference.
    height = 1.92,
    -- A name longer than this many bytes is cut (the [id] in front is not counted).
    nameMax = 24,
    -- The player's session id in front of the name, "[12] Archer Hella", so staff and players
    -- read it at a glance (owner 2026-11-06).
    showId = true,
    -- How often the list of players around is read, and the talkers (the document's; the
    -- native drawer reads the voice levels itself).
    refreshMs = 500,
    talkMs = 100,
    -- A voice level under this is silence (capture noise). Document only.
    talkThreshold = 0.02,
    -- How the plate shrinks with distance and where it starts to fade (fractions of radius);
    -- the document and the native theme both use it.
    page = { nearScale = 1.0, farScale = 0.6, fadeFrom = 0.75 },
    -- Document only: NativeUI draws over every WebUI page, so the plates step aside while
    -- another interface holds the cursor (an inventory, a menu, the phone).
    hideUnderMenus = true,
}
