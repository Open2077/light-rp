-- op77_tcg configuration (shared by server and client). Every value has a safe default; a server overrides
-- what it needs here. Coordinates are game space (metres, X east, Y north, Z up; yaw 0 faces +Y).
TcgConfig = {
    -- Sealed products. Both boosters draw from the same set; they differ by their wrapper.
    products = {
        wnc = { label = "Welcome to Night City", kind = "booster", cards = 12, pack = "cyberpunktcg\\cards\\boosters\\welcome_to_night_city\\booster_pack.ent", art = "img/ui/booster_wnc.webp" },
        beta = { label = "Beta Edition", kind = "booster", cards = 12, pack = "cyberpunktcg\\cards\\boosters\\beta\\booster_pack.ent", art = "img/ui/booster_beta.webp" },
        box = { label = "Booster Display (24 packs)", kind = "box", contains = "wnc", count = 24, model = "cyberpunktcg\\assets\\boxes\\retail_display\\booster_box.ent", art = "img/ui/box_retail.webp" },
    },

    -- Pack composition (the original set's rules): 9 Common, 2 Uncommon, 1 premium slot.
    pack = { commons = 9, uncommons = 2, premium = { { tier = 3, weight = 80 }, { tier = 4, weight = 18 }, { tier = 5, weight = 2 } } },

    -- Dust: what a duplicate recycles into, and what printing an edition costs, per tier.
    -- Tier 6 (Secret) never comes out of a booster: it is printed only, from Dust+.
    dust = { recycle = { 5, 10, 25, 60, 150, 400 }, print = { 40, 80, 200, 500, 1600 }, secretDustPlus = 3, dustPlusFromTop = 1 },

    -- Card physics in the world: the source meshes are modelled at about 6x a real card (39.6 x 55.2 cm).
    scale = { card = 0.16, pack = 0.17, box = 0.21, display = 1.0 },

    -- Opening a pack in the world.
    opening = {
        nearRadius = 40.0,       -- players who see it (same routing bucket)
        maxAnchorGap = 4.0,      -- the opener's anchor must be this close to where the server sees them
        cooldownMs = 4000,       -- between two openings by the same player
        tableReach = 0.75,       -- metres in front of the opener where cards are laid
        tableSearch = { up = 0.6, down = 1.4 },   -- a surface between 0.6 m above and 1.4 m below the hands
        dealMs = 520,            -- one card dealt every
        premiumPauseMs = 1300,   -- the suspense before the premium card
        lingerMs = 30000,        -- cards stay on the table that long
    },

    -- Showing a card to nearby players, placing one on a surface.
    show = { durationMs = 9000, radius = 20.0 },
    place = { maxPerPlayer = 8, lifetimeMs = 30 * 60 * 1000, maxDistance = 3.0 },
    trade = { maxDistance = 4.0, offerMs = 60000 },

    -- Shops. Standalone: none by default; admins place them with /tcg.shop (stored in the database).
    -- A shop sells products, recycles duplicates and prints editions for Dust.
    shops = {},
    shopRadius = 2.2,

    -- Money. Without an economy the shop gives one free booster every freeEveryMs per player.
    -- With one, set resource/charge to an export `charge(playerId, amount, reason) -> boolean`.
    economy = { resource = nil, charge = nil, prices = { wnc = 450, beta = 650, box = 9500 }, freeEveryMs = 20 * 60 * 1000 },

    -- New collectors receive a starter gift once.
    starter = { wnc = 3 },

    -- Keys (rebindable in the game's key settings, Open77 RegisterKeyMapping).
    keys = { binder = "F9", interact = "E" },
}
