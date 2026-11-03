-- Daily and weekly contracts (server/modules/dailies.lua), shown to players as
-- "Dailies". Server only: nothing here is downloaded. The content, the reasons, the
-- measurements behind every number and the abuse rules are in docs/dailies-titles.md;
-- every number below can be tuned without touching code.
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

    -- Contracts that need other people (`social = true` below). They are handed out
    -- only while at least `minAccounts` different accounts are online, so a quiet
    -- server never shows one that cannot be done; the slot's solo contract stands in.
    -- A contract already started keeps going if the city empties. `partnerOncePerWeek`:
    -- the same other account can complete a given social contract with you once per
    -- ISO week (two friends cannot farm one contract together every day).
    social = { minAccounts = 4, partnerOncePerWeek = true },

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
    -- that get it. `social`: needs other citizens (see `social` above). A contract
    -- whose source is missing is never drawn (dailies.lua). Every number is argued
    -- with its arithmetic in docs/dailies-titles.md §8.
    contracts = {
        -- ── Street ──────────────────────────────────────────────────────────
        { id = "lucky_number", slot = "street", fixer = "ledger", title = "Ledger's Lucky Number",
          brief = "My accountant believes in luck. I believe in clean numbers. Land your bank balance on 777 with a real payment: a purchase, a fill-up, a wage. Shuffling your own money between pocket and bank is not a transaction, it is a nervous habit. Naturally, my payment will ruin it.",
          goal = "Make your bank balance end in 777 through a payment (deposits, withdrawals and transfers don't count).", target = 1,
          ignoreKinds = { "deposit", "withdraw", "transfer_out", "transfer_in", "refund" } },
        { id = "eat_together", slot = "street", social = true, fixer = "okoro", title = "Nobody Eats Alone",
          brief = "You eat noodles over the sink like a gonk. Find somebody, sit down, and eat AT THE SAME TIME. Count to three if you have to. Mama's orders.",
          goal = "Finish a meal within 15 m of another citizen who finishes theirs within 8 s of you.", target = 1,
          range = 15.0, windowSeconds = 8 },
        { id = "housewarming", slot = "street", social = true, fixer = "okoro", title = "Housewarming",
          brief = "Got a place and nobody's ever seen it? A home without guests is a box with a lock. Invite someone in, put a drink in their hand, and don't let them leave before they finish it.",
          goal = "In a home you hold the key to, hand a guest a drink; they drink it before they leave.", target = 1 },
        { id = "running_on_fumes", slot = "street", fixer = "nix", title = "Running on Fumes",
          brief = "real ones don't fill up til the light's blinking. bring her in under 10%. jerrycan doesn't count, that's cheating lol",
          goal = "Refuel at a pump a car that was under 10 %, up to at least 50 %.", target = 1,
          below = 0.10, upTo = 0.50 },
        { id = "ride_along", slot = "street", social = true, fixer = "okoro", title = "Ride Along",
          brief = "A million cars in this city and every one of them has one gonk in it. Share a ride. Driver, passenger, Job Center to the Crossing or as far. Talk about something.",
          goal = "Ride 1.2 km in the same vehicle as another citizen.", target = 1200, unit = "m" },
        { id = "street_performer", slot = "street", social = true, fixer = "nix", title = "Street Performer",
          brief = "the crossing needs culture. pick an emote, hold it a full minute, and somebody has to watch. if ur audience walks off u start over",
          goal = "At The Crossing, hold one animation for 60 s with another citizen within 15 m.", target = 60, unit = "s",
          audience = 15.0 },
        { id = "the_tour", slot = "street", social = true, fixer = "okoro", title = "The Tour",
          brief = "There's a fresh face at the Crossing with eyes like a lost cat. Show them the city: the Crossing to the Afterlife, together, no ditching. Be nice, they'll remember.",
          goal = "Travel 750 m within 15 m of a citizen in their first 2 hours in the city.", target = 750, unit = "m",
          range = 15.0 },
        { id = "nightcap", slot = "street", fixer = "okoro", title = "Nightcap",
          brief = "You won something? Good. Now come drink to it like a person, not alone in a queue screen. Any bar, before the adrenaline wears off. Ten minutes.",
          goal = "Win a paid activity (a time trial alone does not count), then have a drink at a bar within 10 minutes.", target = 1,
          minutes = 10, range = 25.0 },

        -- ── Action ──────────────────────────────────────────────────────────
        { id = "clean_invoice", slot = "action", fixer = "ledger", title = "Clean Invoice",
          brief = "Respawns are billed. Every one of them, to me. Put the Chimera down without anybody on your team going down, and my invoice stays clean.",
          goal = "Kill the Chimera, any difficulty, with nobody on the team going down in the fight.", target = 1 },
        { id = "lose_them", slot = "action", fixer = "nix", title = "Lose Them, Don't Wait",
          brief = "anyone can sit out the clock. boring. i want u at the extraction with the whole NCPD on ur tail. three stars minimum or it didnt happen",
          goal = "In NCPD Escape, reach the extraction (not the clock) with 3 or more stars on you.", target = 1,
          minStars = 3 },
        { id = "leg_day", slot = "action", fixer = "nix", title = "Leg Day",
          brief = "cars r for cowards. NCPD Escape ON FOOT. alleys, stairs, fences. get away and send me ur heart rate",
          goal = "In NCPD Escape, pick On foot and get away (extraction or clock).", target = 1 },
        { id = "five_streak", slot = "action", fixer = "nix", title = "Five Without a Dirt Nap",
          brief = "5 kills in a row in the arena without dying. bots count. ur ego doesn't",
          goal = "Get a 5-kill streak in a paid PvE arena match.", target = 1, streak = 5 },
        { id = "support_act", slot = "action", fixer = "okoro", title = "Support Act",
          brief = "Everybody wants the kill. Today you soften them up and let somebody else take the credit. Your crew, or the hired guns from the terminal. Humility, choom.",
          goal = "Win a paid PvE arena match with more assists than kills.", target = 1 },

        -- ── Shift ───────────────────────────────────────────────────────────
        { id = "full_truck", slot = "shift", jobs = { "sanitation", "scrapper" }, fixer = "okoro", title = "Full Truck",
          brief = "One bagful at a time is how you get a bad back, choom. Process it, go back for a second load, and sell it all in one go.",
          goal = "Sell at least 11 goods in one sale (one bagful of pickups makes 10).", target = 1, count = 11 },
        { id = "full_round", slot = "shift", jobs = { "sanitation", "scrapper" }, fixer = "okoro", title = "The Full Round",
          brief = "A real round: both pickups, then the buyer. Not the same corner twice because it's closer. The city doesn't clean itself one block at a time.",
          goal = "Collect at both collection sites, then sell, with no sale in between.", target = 3,
          points = { sanitation = { "collection_west", "collection_center" }, scrapper = { "salvage_south", "salvage_north" } } },
        { id = "two_wheels", slot = "shift", jobs = { "delivery" }, fixer = "nix", title = "Two Wheels",
          brief = "cars get stuck. bikes don't. do a whole route on two wheels, rent one if u have to. kusanagi gang",
          goal = "Do a whole delivery run driving only a bike.", target = 1 },
        { id = "fragile", slot = "shift", jobs = { "delivery" }, fixer = "ledger", title = "Fragile",
          brief = "Today's cargo is porcelain. Corporate porcelain. One route, and the car arrives with no more than five percent damage. Drive like you're being audited.",
          goal = "Drive a whole delivery run in one car losing at most 5 % of its health.", target = 1, maxLoss = 0.05 },
        { id = "water_break", slot = "shift", jobs = { "ac_cleaner" }, fixer = "okoro", title = "Water Break",
          brief = "It's an oven up there and you go up with nothing to drink? Take a bottle. Halfway through the units, you stop and you drink it. On the roof. The tenants can sweat six more seconds.",
          goal = "On a rooftop route, drink something between the first and the last AC unit.", target = 1 },
        { id = "on_call", slot = "shift", jobs = { "trauma" }, social = true, fixer = "okoro", title = "On Call",
          brief = "Somebody's bleeding out tonight. Be there before Trauma Team. One patient, stabilized.",
          goal = "Stabilize another citizen.", target = 1 },
        { id = "fare_paid", slot = "shift", jobs = { "taxi" }, social = true, fixer = "ledger", title = "Fare Paid",
          brief = "A ride is a service. A service is invoiced. Drive a citizen from the Job Center to the Crossing, or as far, let them out, and collect a fare that at least covers the fuel. Tips encouraged.",
          goal = "Drive a passenger 1.2 km, then receive at least €$ 6 from them within 3 minutes.", target = 1,
          metres = 1200, fare = 6, windowSeconds = 180 },
        { id = "roadside", slot = "shift", jobs = { "mechanic" }, social = true, dispatch = true, fixer = "okoro", title = "Roadside Assistance",
          brief = "Some fool's tank light came on and they kept driving. Grab a jerrycan and go save their evening before they're pushing it.",
          goal = "Pour a jerrycan into another citizen's car that is on its reserve or ran dry.", target = 1, minutes = 30 },
        { id = "pit_crew", slot = "shift", jobs = { "mechanic" }, social = true, fixer = "ledger", title = "Pit Crew",
          brief = "Full service is a luxury product. Fill a customer's tank at the pump while they stand there and watch, then invoice them. The fuel at cost is the floor, not the price.",
          goal = "Fill another citizen's car at a pump while they stay within 15 m, then get paid at least the fuel's price.", target = 1,
          range = 15.0, windowSeconds = 180 },

        -- ── Crew ────────────────────────────────────────────────────────────
        { id = "convoy", slot = "crew", fixer = "nix", title = "Convoy",
          brief = "two cars, one vibe. drive ur own rides side by side, close enough to yell at each other. job center to the crossing and back. no passengers, no ditching",
          goal = "Drive your own car within 40 m of a crewmate driving theirs, for 2.4 km.", target = 2400, unit = "m",
          range = 40.0 },
        { id = "back_to_back", slot = "crew", fixer = "ledger", title = "Back to Back",
          brief = "Two operators, one arena, one result. Win it together, and both of you contribute. I don't pay passengers.",
          goal = "Win a paid PvE arena match with a crewmate, at least one kill each.", target = 1,
          windowSeconds = 120, sameRunSeconds = 30 },
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
          goal = "Escape an NCPD Escape match as a crew, every crewmate in it escaping.", target = 1,
          windowSeconds = 240, sameRunSeconds = 30 },

        -- ── Weekly ──────────────────────────────────────────────────────────
        { id = "two_vs_machine", slot = "weekly", social = true, fixer = "ledger", title = "Two Against the Machine",
          brief = "The Chimera on Hard, with exactly two operators from the first shot to the last. The budget doesn't allow a third.",
          goal = "Kill the Chimera on Hard with exactly two operators in the fight.", target = 1 },
        { id = "all_the_way", slot = "weekly", social = true, fixer = "ledger", title = "All the Way",
          brief = "I don't pay for blowouts. Win a ranked duel that goes to the deciding round.",
          goal = "Win a paid ranked duel in its deciding round.", target = 1 },
        { id = "lions_share", slot = "weekly", social = true, fixer = "ledger", title = "Lion's Share",
          brief = "When the big one goes down, I want your name at the top of the invoice.",
          goal = "Be the top contributor of a world boss that goes down.", target = 1 },
        { id = "both_sides", slot = "weekly", social = true, fixer = "nix", title = "Both Sides of the Law",
          brief = "most wanted. bust somebody as a cop AND get away as the runner. same match. be a hypocrite",
          goal = "In one paid Most Wanted match, make an arrest and get away (extraction or survival).", target = 1 },
        { id = "good_samaritan", slot = "weekly", social = true, fixer = "okoro", title = "Good Samaritan",
          brief = "Three strangers this week. Not your crew. Somebody you don't know, bleeding on a street you don't live on. Mama covers the kits.",
          goal = "Stabilize 3 different citizens outside your crew.", target = 3 },
        { id = "one_man_army", slot = "weekly", fixer = "ledger", title = "One-Man Army",
          brief = "The raid is priced for four operators. If you take it alone, you keep the difference and I keep my opinion of you. Standard, no help, no witnesses.",
          goal = "Kill the Chimera alone: one operator in the fight from start to finish.", target = 1 },
        { id = "walk_of_shame", slot = "weekly", fixer = "nix", title = "Walk of Shame",
          brief = "ignore the fuel light. ALL the way. let her die at least a km from the pump, then walk ur jerrycan back like a gonk. character building",
          goal = "Run your own car dry at least 1 km from the fuel station, then bring it back with a jerrycan.", target = 2,
          minMetres = 1000 },
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
