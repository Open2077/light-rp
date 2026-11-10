-- op77_actionbubble settings, shared by the server relay and the clients.
ActionBubbleConfig = {
    -- How long a bubble stays when the caller gives no duration (seconds), and
    -- the longest a caller may ask for. `duration = 0` keeps a bubble until it
    -- is hidden (only for local bubbles and server bubbles).
    duration = 5.0,
    maxDuration = 120.0,

    -- Text: longer lines are cut (UTF-8 safe) and control characters dropped.
    maxText = 96,
    maxAuthor = 40,

    -- Drawn up to this far from the camera (metres). A caller may lower or
    -- raise it within [minDistance, maxDistanceCap].
    maxDistance = 25.0,
    minDistance = 2.0,
    maxDistanceCap = 80.0,

    -- Network relay: who receives a replicated bubble when the caller names no
    -- target list (metres around the anchor), and the largest range allowed.
    range = 20.0,
    maxRange = 60.0,

    -- Bubbles a client may relay (show + update), per window: beyond, refused.
    rate = { count = 6, window = 10.0 },
    -- Bubbles of one player live at once (relayed): a new one ends the oldest.
    perSender = 3,
    -- Bubbles stacked on one target (a character, a vehicle, a spot) on a
    -- screen: a new one sends the oldest away.
    perTarget = 3,
    -- Client-relayed bubbles must anchor on the sender's own character, a
    -- vehicle or point this close to them (metres).
    clientReach = 12.0,
    -- Clients may relay bubbles at all (false: only the server replicates).
    allowClientNetwork = true,

    -- Anchor offsets (world axes, metres) when the caller gives none.
    offsets = {
        player = { x = 0.0, y = 0.0, z = 1.55 },  -- the upper chest / collar
        vehicle = { x = 0.0, y = 0.0, z = 1.25 },
        entity = { x = 0.0, y = 0.0, z = 1.0 },
        position = { x = 0.0, y = 0.0, z = 0.0 },
    },

    -- At most this many bubbles live on one client; the oldest goes first.
    -- (The platform allows 32 anchors per resource.)
    maxBubbles = 24,

    -- NativeUI draws over every WebUI page: the bubbles step aside while another
    -- interface holds the cursor (an inventory, a menu, the phone). Client side.
    hideUnderMenus = true,

    -- Kinds: the label on the card and its accent. `action` is the default.
    kinds = {
        action = { label = "ACTION", accent = "#FFCC00" },
        state  = { label = "STATE",  accent = "#2EE6E0" },
        speech = { label = "SAYS",   accent = "#EBE7E2" },
        alert  = { label = "ALERT",  accent = "#FF3340" },
        system = { label = "SYSTEM", accent = "#9B8CFF" },
    },
}
