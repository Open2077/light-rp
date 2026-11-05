-- Maneki-neko collectible (server/modules/maneki.lua, docs/maneki.md). Server only.
--
-- Lucky cats hidden by the staff around Night City. No blip, no marker, no hint:
-- a player sees one only when the server streams it to them (within streamRadius),
-- and takes it with E or by shooting it. Each character finds each cat once.
LightRpManeki = {
    enabled = true,

    -- The visual host built by tools/build-maneki-props.py (resource open77_maneki).
    model = "open77\\assets\\op77_lightrp\\maneki\\maneki_neko.ent",
    -- Unscaled size of the game's cat (chinese_sculpture_small_c.mesh): 9 x 12 x 16 cm.
    height = 0.16,

    -- Streaming: the server sends a player the cats they have not found, within
    -- streamRadius of their position (server feed), at most maxStreamed, nearest first.
    streamRadius = 140,
    maxStreamed = 40,
    scanMs = 2000,

    -- Collecting. The server re-checks with its own position feed (a few metres of lag).
    takeRadius = 4.0,      -- E: the client prompt shows at 1.8 m
    shotRange = 90,        -- a shot: distance from the shooter to the cat
    collectCooldownMs = 400,

    -- Rewards: every find, then the milestones (found count), then the title for the
    -- whole set (only once at least completeMin cats exist, so 3 test cats give no title).
    reward = { cash = 250 },
    -- A milestone pays `cash` to the bank and puts `items` (Cyberpunk TCG sealed product, op77_tcg) in the
    -- character's inventory. A full inventory gets the items' NEON DECK price in the bank instead.
    milestones = {
        { count = 5, cash = 0, items = { { name = "tcg_booster_wnc", count = 1 } } },
        { count = 10, cash = 2500, items = { { name = "tcg_booster_wnc", count = 2 } } },
        { count = 25, cash = 7500, items = { { name = "tcg_booster_beta", count = 2 } } },
        { count = 50, cash = 20000, items = { { name = "tcg_display_wnc", count = 1 } } },
        { count = 100, cash = 40000, items = { { name = "tcg_display_wnc", count = 1 }, { name = "tcg_booster_beta", count = 3 } } },
    },
    completeTitle = "lucky_cat",
    completeMin = 10,

    -- Staff placement tool (/lightrp.admin > Maneki-neko, /lightrp.maneki place).
    scales = { 1, 1.5, 2, 3 },  -- the sizes the tool cycles through (1 = the game's 16 cm cat)
    placeMaxDistance = 80,      -- a placed cat is at most this far from the staff member
    maxSpots = 600,
}
