-- op77_playermarks settings (client side).
PlayerMarksConfig = {
    enabled = true,
    -- Players within this many metres get a dot (the anchor stops reporting past it).
    radius = 35.0,
    -- At most this many dots (the plugin allows 32 anchors per resource).
    max = 24,
    -- Metres above the body's origin (the feet): just over the head.
    height = 2.12,
    -- How often the list of players around is read, and the talkers.
    refreshMs = 500,
    talkMs = 100,
    -- A voice level under this is silence (capture noise).
    talkThreshold = 0.02,
    -- The page: dot colour, and how the dot shrinks with distance.
    color = "#FCEE0A",
    page = { nearScale = 1.0, farScale = 0.55, fadeFrom = 0.8 },
}
