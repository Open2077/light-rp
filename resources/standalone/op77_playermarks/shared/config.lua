-- op77_playermarks settings (client side).
PlayerMarksConfig = {
    enabled = true,
    -- Players within this many metres get a dot (the anchor stops reporting past it).
    radius = 35.0,
    -- At most this many dots (the plugin allows 32 anchors per resource).
    max = 24,
    -- Metres above the body's origin (the feet): the plate's pin, just over the head
    -- (2.12 floated a hand's width too high in game).
    height = 1.92,
    -- A name longer than this many bytes is cut.
    nameMax = 24,
    -- How often the list of players around is read, and the talkers.
    refreshMs = 500,
    talkMs = 100,
    -- A voice level under this is silence (capture noise).
    talkThreshold = 0.02,
    -- The page: how the plate shrinks with distance and where it starts to fade
    -- (fractions of radius).
    page = { nearScale = 1.0, farScale = 0.6, fadeFrom = 0.75 },
}
