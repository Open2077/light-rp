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
        -- The 3D side of an opening: the pack in the hand, the 12 cards dealt on the table / fanned in the hand for
        -- everyone around, the opener's camera on them. Off: the opening happens on the opener's screen only.
        physical = false,
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

    -- Duels at a TCG table (shared/table.lua: the tables, the mats, the zones). A collector challenges a player nearby
    -- with one of their decks; both walk to the table, sit down and the game is set up on their playmats.
    duel = {
        challengeRadius = 15.0,  -- the players you can challenge
        challengeMs = 60000,     -- an unanswered challenge expires
        seatMs = 180000,         -- both players must sit down within (else the table is freed)
        sitReach = 2.2,          -- how close to your chair the sit prompt appears
        chooseMs = 25000,        -- the d20 winner picks who goes first (default: they do)
        mulliganMs = 60000,      -- each player keeps or mulligans (default: keep)
        lendStarters = true,     -- the shop lends the two official starter decks to everyone
        -- The game's clock per step (ms): rolling a Gig, the main phase, a React step, picking stolen Gigs. When it
        -- runs out the smallest die is rolled, the React step passes, the best Gigs are stolen, the turn ends.
        stepMs = { roll = 30000, main = 150000, react = 30000, steal = 30000, prompt = 45000 },
        -- Tests and showcases: an idle player's turn is played by the house instead of just ending.
        houseForIdle = false,
        -- Sit with a held sequence that stands the player up at the seat's stand point (needs a runtime whose sequences
        -- hold at a workspot chair; the looped animation is the default).
        sitSequence = false,
        -- Sitting at the table: the first profile the runtime plays wins (hands on the table, then the plain chair).
        sit = {
            { profile = "amb_d7c499_sit_chair_table_keybo", clip = "sit_chair_table_keyboard__2h_on_keyboard__01__shuffle__02" },
            { profile = "chair", clip = "sit_chair_lean180__2h_on_lap__01__long__01" },
        },
    },

    -- New collectors receive a starter gift once. Off on Light RP: its starting inventory carries the 3
    -- boosters (op77_lightrp shared/config.lua inventory.starting); `starterNote` is what the welcome
    -- guide announces instead.
    starter = {},
    starterNote = 3,

    -- A gamemode that owns characters and an inventory (LightRP). When it runs, each character is its own collector
    -- (exports characterIdentity, events <framework>:characterReady / :characterChanged), and sealed product lives
    -- in its inventory as items (exports tcgSealed / tcgTakeSealed / tcgGiveSealed); using a booster or a display
    -- item calls exports.op77_tcg:useSealed. Absent or nil: accounts and the binder's own sealed shelf.
    framework = "op77_lightrp",

    -- Opening sealed product in front of others: the opener plays `animation` (both hands in front, the pack
    -- between them) for as long as the pack is in their hands, and an action bubble (op77_actionbubble, the same
    -- bubble as LightRP's /me) shows over them to the players within `range` metres. false turns either off.
    openingAct = {
        animation = { profile = "tablet2", clip = "stand__2h_tablet__02__use_tablet__01", maxMs = 90000 },
        bubble = { range = 20, duration = 6, booster = "Opens a %s booster", box = "Cuts open a booster display" },
    },

    -- The binder opens with this chat command (no key: a gamemode adds its own entry, LightRP its F1 menu),
    -- or from another resource with TriggerEvent("op77_tcg:openBinder", tab).
    command = "tcgbinder",

    -- The NEON DECK welcome (client/welcome.lua, web/welcome.js): a short guide the page shows once per collector
    -- (per character with a framework) when they walk up to the vendor; "seen" is kept in tcg.db (tcg_seen).
    -- Reopen it with /tcgwelcome or the "How NEON DECK works" button of the private rooms panel.
    welcome = {
        enabled = true,
        -- The NEON DECK clerk behind the checkout counter (op77_lightrp server/config/shops.lua, tcgshop_neon_deck).
        anchor = { x = -814.12, y = 933.52, z = 12.14 },
        radius = 4.5,        -- metres on the ground, around the clerk
        height = 2.5,        -- and at most this far above / below (the private rooms are 8 m under the shop)
        checkMs = 500,       -- how often the client looks (one distance test, nothing per frame)
        settleMs = 1500,     -- the player stays this long in range before it opens (not just walking past)
        command = "tcgwelcome",
        -- How the binder opens, as the guide words it. LightRP: the F1 player menu, entry "TCG binder".
        -- nil: only the chat command (/tcgbinder).
        binder = { key = "F1", menu = "player menu", entry = "TCG binder" },
    },
}
