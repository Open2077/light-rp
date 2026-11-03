-- Daily and weekly contracts (server/modules/dailies.lua). Server only: nothing
-- here is downloaded. The content, the reasons and the abuse rules are in
-- docs/dailies-titles.md; every number below can be tuned without touching code.
--
-- A day is a UTC day (reset 00:00 UTC), a week starts Monday 00:00 UTC.
-- Street, Action, Crew and the weekly contract are the same for the whole server
-- (drawn from the day / week number); Shift is the same for everyone in a job.
-- Progress and rewards are per ACCOUNT (the Master identity), like the mission cap.
LightRpDailies = {
    enabled = true,

    -- What each slot pays (bank, ledger kind `contract`).
    rewards = { street = 250, action = 400, shift = 250, crew = 300, weekly = 3000 },
    -- Most an account can be paid by daily + crew contracts of one UTC day.
    dailyBudget = 1200,
    -- A finished contract can still be claimed this many days after its own day.
    claimGraceDays = 1,
    -- Free swaps per day (street, action or shift; never crew or weekly).
    swapsPerDay = 1,
    -- How often positions, seats and animations are sampled (seconds).
    sampleSeconds = 5,
    -- A player moving faster than this between two samples teleported: the stretch is not counted.
    maxSpeed = 70,
    -- Progress is written to the database at most this often per account (a finish
    -- or a claim is written at once).
    saveSeconds = 30,

    fixers = {
        okoro = { name = "Mama Okoro", tagline = "Heywood. Pays on time, remembers who doesn't." },
        ledger = { name = "Silas \"Ledger\" Varga", tagline = "Corpo leftovers, sold by the pound." },
        nix = { name = "Nix Delacroix", tagline = "Pacifica runner. Fast money, faster exits." },
    },

    -- The Crossing (LightRpActivities.hub) is where Street Performer and Album Cover play.
    hubRadius = 40.0,

    -- Every contract: id (stable: it is stored), slot, fixer, title, brief (the
    -- fixer's message), goal (what the server checks, shown under it), target and
    -- unit (the progress bar), and its own numbers. `jobs` (shift only): the jobs
    -- that get it. A contract whose source is missing is never drawn (dailies.lua).
    contracts = {
        -- ── Street ──────────────────────────────────────────────────────────
        { id = "lucky_number", slot = "street", fixer = "ledger", title = "Ledger's Lucky Number",
          brief = "My accountant believes in luck. I believe in clean numbers. End a bank transaction on a balance ending in 777. Naturally, my payment will ruin it.",
          goal = "Make your bank balance end in 777.", target = 1 },
        { id = "eat_together", slot = "street", fixer = "okoro", title = "Nobody Eats Alone",
          brief = "You eat noodles over the sink like a gonk. Find somebody, sit down, eat together. Mama's orders.",
          goal = "Finish a meal within 10 m of another citizen who finishes one within 2 minutes.", target = 1,
          range = 10.0, windowSeconds = 120 },
        { id = "housewarming", slot = "street", fixer = "okoro", title = "Housewarming",
          brief = "Got a place and nobody's ever seen it? A home without guests is a box with a lock. Invite someone in. Three minutes. Offer them a drink, I don't care.",
          goal = "Spend 3 minutes in a home with another citizen, one of you holding the key.", target = 180, unit = "s" },
        { id = "running_on_fumes", slot = "street", fixer = "nix", title = "Running on Fumes",
          brief = "real ones don't fill up til the light's blinking. bring her in under 10%. jerrycan doesn't count, that's cheating lol",
          goal = "Refuel at a pump a car that was under 10 %, up to at least 50 %.", target = 1,
          below = 0.10, upTo = 0.50 },
        { id = "ride_along", slot = "street", fixer = "okoro", title = "Ride Along",
          brief = "A million cars in this city and every one of them has one gonk in it. Share a ride. Driver, passenger, a kilometre and a half. Talk about something.",
          goal = "Ride 1.5 km in the same vehicle as another citizen.", target = 1500, unit = "m" },
        { id = "street_performer", slot = "street", fixer = "nix", title = "Street Performer",
          brief = "the crossing needs culture. pick an emote, hold it a full minute, and somebody has to watch. if ur audience walks off u start over",
          goal = "At The Crossing, hold one animation for 60 s with another citizen within 12 m.", target = 60, unit = "s",
          audience = 12.0 },
        { id = "the_tour", slot = "street", fixer = "okoro", title = "The Tour",
          brief = "There's a fresh face at the Crossing with eyes like a lost cat. Show them the city. A kilometre, together, no ditching. Be nice, they'll remember.",
          goal = "Travel 1 km within 30 m of a citizen with under 5 hours in the city.", target = 1000, unit = "m",
          range = 30.0, newcomerHours = 5 },

        -- ── Action ──────────────────────────────────────────────────────────
        { id = "before_overclock", slot = "action", fixer = "ledger", title = "Before the Overclock",
          brief = "The Chimera's core overclocks if you dawdle. I do not pay overtime. Put it down before it heats up.",
          goal = "Kill the Chimera, any difficulty, before its core overclocks.", target = 1 },
        { id = "lose_them", slot = "action", fixer = "nix", title = "Lose Them, Don't Wait",
          brief = "anyone can hide til the timer runs out. boring. i want u to SHAKE them. actually lose the cops",
          goal = "Escape NCPD Escape by shaking the police off (not on the clock, not by extraction).", target = 1 },
        { id = "run_it_back", slot = "action", fixer = "ledger", title = "Run It Back",
          brief = "Set a time on any time trial. Then beat it. The first run is the invoice, the second is the payment. And don't sandbag the first one. I'll know.",
          goal = "Finish a time trial twice today, the second run at least 1 s faster than the first.", target = 1,
          marginMs = 1000 },
        { id = "billable_hours", slot = "action", fixer = "ledger", title = "Billable Hours",
          brief = "Clients pay for results, not for hours. Finish any job with half the clock still on it.",
          goal = "Complete a mission with at least half of its time limit left.", target = 1 },
        { id = "answer_phone", slot = "action", fixer = "okoro", title = "Answer the Phone",
          brief = "When a fixer texts, you answer. Even Ledger. Even Nix, god help you. Finish one gig today.",
          goal = "Complete a fixer gig.", target = 1 },
        { id = "five_streak", slot = "action", fixer = "nix", title = "Five Without a Dirt Nap",
          brief = "5 kills in a row in the arena without dying. bots count. ur ego doesn't",
          goal = "Get a 5-kill streak in a paid PvE arena match.", target = 1, streak = 5 },

        -- ── Shift ───────────────────────────────────────────────────────────
        { id = "full_truck", slot = "shift", jobs = { "sanitation", "scrapper" }, fixer = "okoro", title = "Full Truck",
          brief = "One bag at a time is how you get a bad back, choom. Load the trunk and sell twenty in one go.",
          goal = "Sell at least 20 goods in a single sale.", target = 1, count = 20 },
        { id = "full_round", slot = "shift", jobs = { "sanitation", "scrapper" }, fixer = "okoro", title = "The Full Round",
          brief = "A real round: both pickups, then the buyer, inside thirty minutes. The city doesn't clean itself one block at a time.",
          goal = "Collect at both collection sites, then sell, within 30 minutes.", target = 1, minutes = 30,
          points = { sanitation = { "collection_west", "collection_center" }, scrapper = { "salvage_south", "salvage_north" } } },
        { id = "still_hot", slot = "shift", jobs = { "delivery" }, fixer = "nix", title = "Still Hot",
          brief = "food's gotta land HOT. beat dispatch's clock or the customer leaves 1 star and i cry",
          goal = "Finish a delivery run within 3 min + 1.5 min per km of its route.", target = 1,
          baseMinutes = 3, perKmMinutes = 1.5 },
        { id = "fragile", slot = "shift", jobs = { "delivery" }, fixer = "ledger", title = "Fragile",
          brief = "Today's cargo is porcelain. Corporate porcelain. One route, and the car arrives with no more than five percent damage. Drive like you're being audited.",
          goal = "Drive a whole delivery run in one car losing at most 5 % of its health.", target = 1, maxLoss = 0.05 },
        { id = "heat_wave", slot = "shift", jobs = { "ac_cleaner" }, fixer = "okoro", title = "Heat Wave",
          brief = "It's an oven up there and the tenants are melting. One rooftop route, under five minutes. Move.",
          goal = "Finish a rooftop maintenance route in under 5 minutes.", target = 1, minutes = 5 },
        { id = "on_call", slot = "shift", jobs = { "trauma" }, fixer = "okoro", title = "On Call",
          brief = "Somebody's bleeding out tonight. Be there before Trauma Team. One patient, stabilized.",
          goal = "Stabilize another citizen.", target = 1 },
        { id = "fare_paid", slot = "shift", jobs = { "taxi" }, fixer = "ledger", title = "Fare Paid",
          brief = "A ride is a service. A service is invoiced. Drive a citizen two kilometres, let them out, and collect the fare. At least twenty. Tips encouraged.",
          goal = "Drive a passenger 2 km, then receive at least €$ 20 from them within 3 minutes.", target = 1,
          metres = 2000, fare = 20, windowSeconds = 180 },
        { id = "roadside", slot = "shift", jobs = { "mechanic" }, fixer = "okoro", title = "Roadside Assistance",
          brief = "Some fool ran dry on the highway again. Grab a jerrycan and go save their evening.",
          goal = "Pour a jerrycan into another citizen's car that ran dry in the last 20 minutes.", target = 1, minutes = 20 },
        { id = "clock_in", slot = "shift", jobs = { "unemployed" }, fixer = "okoro", title = "Clock In",
          brief = "No job? Mama knows people. Job Center, City Center. Get hired and finish your first shift. Then we talk.",
          goal = "Get hired at the Job Center and finish a first batch or work order.", target = 2 },

        -- ── Crew ────────────────────────────────────────────────────────────
        { id = "convoy", slot = "crew", fixer = "nix", title = "Convoy",
          brief = "two cars, one vibe. drive ur own rides side by side for 3 km. no passengers, no ditching",
          goal = "Drive your own car within 40 m of a crewmate driving theirs, for 3 km.", target = 3000, unit = "m",
          range = 40.0 },
        { id = "back_to_back", slot = "crew", fixer = "ledger", title = "Back to Back",
          brief = "Two operators, one arena, one result. Win it together, and both of you contribute. I don't pay passengers.",
          goal = "Win a paid PvE arena match with a crewmate, at least one kill each.", target = 1, windowSeconds = 120 },
        { id = "bar_crawl", slot = "crew", fixer = "okoro", title = "Bar Crawl",
          brief = "Three bars, one night, same crew. Drink something at each. Different districts, choom, I want you to see the city.",
          goal = "Drink with a crewmate at 3 bars in 3 districts within an hour.", target = 3,
          range = 25.0, togetherSeconds = 600, minutes = 60 },
        { id = "album_cover", slot = "crew", fixer = "nix", title = "Album Cover",
          brief = "crew pic at the crossing. everybody strike a pose at the same time, 10 seconds, nobody blinks",
          goal = "At The Crossing, everyone in the crew there plays an animation within 6 m of each other for 10 s.", target = 1,
          range = 6.0, seconds = 10 },
        { id = "nobody_left_behind", slot = "crew", fixer = "nix", title = "Nobody Left Behind",
          brief = "NCPD Escape as a crew. EVERYONE gets out or nobody gets paid. go",
          goal = "Escape an NCPD Escape match as a crew, every crewmate in it escaping.", target = 1, windowSeconds = 120 },

        -- ── Weekly ──────────────────────────────────────────────────────────
        { id = "two_vs_machine", slot = "weekly", fixer = "ledger", title = "Two Against the Machine",
          brief = "The Chimera at Hard or above, with exactly two operators. The budget doesn't allow a third.",
          goal = "Kill the Chimera on Hard or Critical with exactly two operators.", target = 1 },
        { id = "all_the_way", slot = "weekly", fixer = "ledger", title = "All the Way",
          brief = "I don't pay for blowouts. Win a ranked duel that goes to the deciding round.",
          goal = "Win a paid ranked duel in its deciding round.", target = 1 },
        { id = "lions_share", slot = "weekly", fixer = "ledger", title = "Lion's Share",
          brief = "When the big one goes down, I want your name at the top of the invoice.",
          goal = "Be the top contributor of a world boss that goes down.", target = 1 },
        { id = "both_sides", slot = "weekly", fixer = "nix", title = "Both Sides of the Law",
          brief = "most wanted. bust somebody as a cop AND get away as the runner. same match. be a hypocrite",
          goal = "In one paid Most Wanted match, make an arrest and get away (extraction or survival).", target = 1 },
        { id = "good_samaritan", slot = "weekly", fixer = "okoro", title = "Good Samaritan",
          brief = "Three strangers this week. Not your crew. Somebody you don't know, bleeding on a street you don't live on. Mama covers the kits.",
          goal = "Stabilize 3 different citizens outside your crew.", target = 3 },
    },

    -- Titles earned through contracts (server/config/titles.lua holds the catalogue).
    titleRules = {
        streaks = { { days = 7, title = "streak_7" }, { days = 30, title = "streak_30" } },
        claims = { { count = 30, title = "okoro_favourite" } },
        repeats = { lucky_number = { count = 3, title = "lucky_seven" },
                    street_performer = { count = 3, title = "crowd_pleaser" },
                    running_on_fumes = { count = 3, title = "fumes_connoisseur" } },
    },
}
