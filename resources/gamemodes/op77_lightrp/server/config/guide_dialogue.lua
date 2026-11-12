-- Talking to Johnny (server/modules/guide_dialogue.lua): a game dialogue over the
-- FAQ of server/config/guide.lua. Johnny says a line, the player picks one of a few
-- choices, Johnny answers, more choices. Server-only, English, edited without a
-- page rebuild. docs/guide-dialogue.md restates the same tree, for review.
--
-- A node: `say` (Johnny's lines; one page holds up to `pageLines` lines and about
-- `pageChars` characters, the rest pages) and `choices`. `variants` instead of
-- `say`: one set of lines picked at random each time (the opening). `requires` on
-- a node hides every choice that leads to it.
--
-- A choice is { "What the player says", <where it leads> } with one of:
--   to = "<node>"       a node of this file
--   faq = "<question>"  a question of server/config/guide.lua, answered in the
--                       dialogue: its `say`, then its answer, paged; its actions and
--                       follow-ups become the next choices
--   topic = "<topic>"   a topic of the FAQ: Johnny's line, then its questions
--   gps = "<kind>"      a GPS route to the nearest place of that kind (the FAQ's
--                       targets, plus dogtown and ripperdoc from the module)
--   open = "<what>"     activities | contracts | crew (the activities panel and its
--                       tab), halloffame, jobguide, housing, support, animations,
--                       tutorial, briefing, faq (with id = "<question>": the FAQ
--                       panel at that answer), search (the FAQ panel, search box)
-- and an optional `requires` (the same rules as the FAQ). A choice whose target is
-- hidden (a gated question, a GPS kind with no place) is not offered. The page adds
-- "Back." and "That's all." to every node.
--
-- Placeholders are the FAQ's ({cfg:...}, {money:...}, {key:...}, {v:...}...): an
-- answer follows the config. Johnny is the game's character, a rockerboy engram:
-- short, cocky, never the actor. No staff command, no emoji.
LightRpGuideDialogue = {
    enabled = true,
    root = "hello",
    pageLines = 3,   -- lines on screen at once
    pageChars = 300, -- characters on screen at once (a longer single line gets a page of its own)
    -- The "Open the Hall of Fame" choice works this far from Johnny (the board stands
    -- a few metres away from him at The Crossing), or anywhere the board's own ALT +
    -- click reaches.
    panelRange = 12.0,
    -- Ripperdoc clinics for "Mark the nearest clinic": { id, name, position = { x, y, z } },
    -- city bucket. Empty: the choice is hidden. The game's 14 ripperdocs, each on the
    -- operating chair of its clinic (the same points as shared/config.lua mapPlaces); `chair`
    -- is the op77_scenes spot, so the clinic interface shows the clinic's name.
    clinics = {
        { id = "ripperdoc_135", name = "Ripperdoc // Watson 1", chair = "surgical_chair_a@-1686_2377_19", position = { x = -1686.06, y = 2377.41, z = 18.78 } },
        { id = "ripperdoc_138", name = "Ripperdoc // Watson 2", chair = "surgical_chair_a@-1240_1940_8", position = { x = -1239.71, y = 1939.65, z = 8.49 } },
        { id = "ripperdoc_142", name = "Ripperdoc // Watson 3", chair = "surgical_chair_a@-1089_2149_14", position = { x = -1089.05, y = 2149.03, z = 13.76 } },
        { id = "ripperdoc_151", name = "Ripperdoc // Westbrook 1", chair = "surgical_chair_a_mirrored@-716_869_12", position = { x = -716.10, y = 869.44, z = 12.40 } },
        { id = "ripperdoc_155", name = "Ripperdoc // Westbrook 2", chair = "surgical_chair_b@-578_793_25", position = { x = -577.68, y = 792.85, z = 25.42 } },
        { id = "ripperdoc_158", name = "Ripperdoc // Westbrook 3", chair = "surgical_chair_a_mirrored@-40_-49_8", position = { x = -39.69, y = -48.56, z = 7.62 } },
        { id = "ripperdoc_164", name = "Ripperdoc // Watson 4", chair = "surgical_chair_a@-1546_1235_12", position = { x = -1546.49, y = 1234.96, z = 11.92 } },
        { id = "ripperdoc_169", name = "Ripperdoc // Watson 5", chair = "surgical_chair_a@-1039_1446_1", position = { x = -1039.37, y = 1445.65, z = 0.91 } },
        { id = "ripperdoc_174", name = "Ripperdoc // City Center", chair = "surgical_chair_a_mirrored@-2415_392_12", position = { x = -2414.56, y = 391.81, z = 12.28 } },
        { id = "ripperdoc_186", name = "Ripperdoc // Heywood", chair = "surgical_chair_a_mirrored@-2358_-927_13", position = { x = -2358.18, y = -927.02, z = 12.70 } },
        { id = "ripperdoc_191", name = "Ripperdoc // Santo Domingo 1", chair = "surgical_chair_a_mirrored@-1069_-1271_12", position = { x = -1069.50, y = -1271.36, z = 11.89 } },
        { id = "ripperdoc_199", name = "Ripperdoc // Pacifica", chair = "surgical_chair_a_mirrored@-2624_-2467_17", position = { x = -2624.16, y = -2467.47, z = 17.30 } },
        { id = "ripperdoc_212", name = "Ripperdoc // Santo Domingo 2", chair = "surgical_chair_b@587_-2178_43", position = { x = 586.52, y = -2178.49, z = 42.95 } },
        { id = "ripperdoc_219", name = "Ripperdoc // Badlands", chair = "surgical_chair_a_mirrored@3440_-387_136", position = { x = 3439.99, y = -387.25, z = 136.03 } },
    },

    -- Said when the player picks "That's all." (one at random).
    farewell = {
        "Don't die out there. Or do. Keeps things interesting.",
        "See you around, choom. I'll be here. Not like I've got a choice.",
        "Go on. The city's not gonna burn itself down.",
    },

    nodes = {
        -- -------------------------------------------------------------------
        hello = {
            variants = {
                { "Well, look who wandered in. Johnny Silverhand. Rockerboy, legend, and apparently the welcome committee.",
                  "New in town? Ask. I've got nothing but time." },
                { "Name's Johnny Silverhand. Don't ask why a dead rockerboy's haunting a plaza in Westbrook.",
                  "Ask me about the city instead. Jobs, wheels, eddies, trouble." },
                { "You again? Or someone new. Hard to tell, you all have the same lost look.",
                  "Go on. Ask me something." },
            },
            choices = {
                { "What do I do first?", to = "first" },
                { "How do I make money?", to = "money" },
                { "Where's the action?", to = "action" },
                { "I need wheels.", to = "wheels" },
                { "Tell me about chrome.", to = "chrome" },
                { "Crew stuff.", to = "crew" },
                { "Something else…", to = "other" },
            },
        },

        -- -------------------------------------------------------------------
        -- What do I do first?
        first = {
            say = {
                "Rule one in Night City: have a plan. Rule two: have eddies. You've got {money:config.economy.startingCash} on you and {money:config.economy.startingBank} in the bank.",
                "Your free studio's in **{v:starterDoor}**. Get a job at the **{v:jobCenter}**, keep yourself fed, and come back here when you want trouble.",
            },
            choices = {
                { "Mark my studio.", gps = "starter" },
                { "Mark the Job Center.", gps = "jobcenter" },
                { "Where am I, exactly?", to = "where" },
                { "Show me my keys.", to = "keys" },
                { "Any rules?", faq = "start.rules" },
            },
        },
        where = {
            say = {
                "**{v:hub}**, Westbrook. Fancy neighbourhood. Don't let it fool you.",
                "Newcomers land here when their first day ends. Smasher runs the activities, over by the parking. Yeah. Him. The Job Center, the rentals and the garage are over in City Center.",
            },
            choices = {
                { "Show me the activities.", open = "activities" },
                { "What was that first day guide?", faq = "start.tutorial" },
                { "Who are you, anyway?", faq = "help.johnny" },
            },
        },
        keys = {
            say = {
                "{key:menu} opens your menu. {key:neuralink}'s your Neural-Link: messages, fixers, apps. {key:interact} works whatever's in front of you.",
                "{key:inventory} for your bag. Hold {key:context} and click a person, a car, or me. Light RP's keys rebind in Pause → Settings → Key bindings, and I always say yours.",
            },
            choices = {
                { "Write them all down for me.", open = "faq", id = "controls.keys" },
                { "What's in the menu?", faq = "controls.f1" },
                { "What does the Neural-Link do?", faq = "controls.neuralink" },
                { "How do I walk instead of run?", faq = "controls.walk" },
                { "Camera?", faq = "controls.camera" },
            },
        },

        -- -------------------------------------------------------------------
        -- How do I make money?
        money = {
            say = {
                "Honest work or dirty work. Both pay. One pays better.",
                { requires = "config:economy.paychecks.requireActivity",
                  "A **job** pays every {cfg:config.jobs.paycheckMinutes} minutes while you're actually doing something, plus what the work brings in. **Missions** pay the most, if you bring a crew." },
                { requires = "not:config:economy.paychecks.requireActivity",
                  "A **job** pays every {cfg:config.jobs.paycheckMinutes} minutes, plus what the work brings in. **Missions** pay the most, if you bring a crew." },
                { requires = "activityPayouts", "And the matches here at {v:hub} pay by the minute." },
            },
            choices = {
                { "Get me a job.", to = "job" },
                { "Tell me about missions.", to = "missions" },
                { "Cash or bank?", to = "cash" },
                { "How do I pay someone?", faq = "money.pay" },
                { "What does stuff cost?", faq = "money.spend" },
                { "What are these Dailies?", faq = "money.dailies" },
            },
        },
        job = {
            say = {
                "A job. Corporate slavery with a paycheck. Still, eddies are eddies.",
                "Go to the **{v:jobCenter}** and press {key:interact} at the clerk. On offer: {v:jobCenterJobs}. Everyone starts at the bottom.",
            },
            choices = {
                { "Mark the Job Center.", gps = "jobcenter" },
                { "What's each job like?", to = "jobs" },
                { "What's the pay?", faq = "jobs.pay" },
                { "Open my job guide.", open = "jobguide" },
                { "How do I quit?", faq = "jobs.quit" },
            },
        },
        jobs = {
            say = {
                "**Sanitation**: haul trash, sort it, sell it. **Scrapper**: the same with scrap. Both at your own pace.",
                "**Courier**: grab orders, drive them across town, get paid by stops and distance at the last drop.",
            },
            choices = {
                { "Tell me about Sanitation.", faq = "jobs.sanitation" },
                { "Tell me about Scrapper.", faq = "jobs.scrapper" },
                { "Tell me about Courier runs.", faq = "jobs.courier" },
                { "Mark the Job Center.", gps = "jobcenter" },
            },
        },
        cash = {
            say = {
                "**Cash** sits in your pocket. Only pocket cash pays: not your trunk, not the floor.",
                "**Bank**: one account per character. Paychecks, sales, runs and missions land there. Shops take either. Chrome and homes, bank only.",
                "No ATMs yet, so you can't move eddies between the two yourself. Stone age, I know.",
            },
            choices = {
                { "How do I check my balance?", faq = "money.check" },
                { "How do I pay someone?", faq = "money.pay" },
                { "Every way to earn?", faq = "money.earn" },
            },
        },

        -- -------------------------------------------------------------------
        -- Where's the action?
        action = {
            say = {
                "Wanna blow off some steam? Right here, choom. Smasher runs arena fights, races, chases and turf wars at {v:hub}. Don't ask me how that chromed bastard got the job.",
                { requires = "activity:*", "On right now: {v:activities}." },
                { requires = "dogtown", "Bigger money? Mission boards, all over the city. And if you're feeling lucky, Dogtown." },
                { requires = "not:dogtown", "Bigger money? Mission boards, all over the city." },
            },
            choices = {
                { "Show me the activities.", open = "activities" },
                { "Do they pay?", faq = "activities.pay_rebalance" },
                { "Do they pay?", faq = "activities.rewards" },
                { "Tell me about missions.", to = "missions" },
                { "Dogtown?", to = "dogtown" },
                { "Open the Hall of Fame.", open = "halloffame", requires = "halloffame" },
            },
        },
        missions = {
            say = {
                "Now we're talking. Real work, real money, real lead flying.",
                "Walk up to a mission board, press {key:interact}, pick a difficulty, tag in. You fight NPCs in your crew's own instance, with a kit they hand you.",
                { requires = { "pveTiers", "config:missions.reputation.requireTier" }, "The hard stuff wants street cred: {v:difficultyTiers}." },
            },
            choices = {
                { "Show me the contracts.", open = "contracts" },
                { "What do they pay?", faq = "missions.rewards" },
                { "Street cred?", faq = "missions.tiers_gate" },
                { "Street cred?", faq = "missions.reputation" },
                { "Who are the fixers?", faq = "missions.fixers" },
                { "What if I die?", faq = "missions.death" },
                { "The Chimera Protocol?", faq = "missions.chimera" },
            },
        },
        dogtown = {
            requires = "dogtown",
            say = {
                "Dogtown. No law past the walls. Bring cash, bring friends, bring a plan for leaving.",
                "You need **{money:dogtown.stake.minCash}**, cash plus bank, to fight in there. Die and you drop **{pct:dogtown.loot.share}** of it, {money:dogtown.loot.min} to {money:dogtown.loot.max}, in a bag for your killer.",
            },
            choices = {
                { "Mark Dogtown.", gps = "dogtown" },
                { "What's in it for me?", faq = "dogtown.bonus" },
                { "Crews in there?", faq = "dogtown.crews" },
                { "Bounties?", faq = "dogtown.bounty" },
                { "Give me the fine print.", faq = "dogtown.what" },
            },
        },

        -- -------------------------------------------------------------------
        -- I need wheels.
        wheels = {
            say = {
                "Wheels. You'll want some. This city's too big and too mean to walk.",
                "Rent one at **{v:rental}**: {v:rentalRange} for {cfg:config.rentals.durationMinutes} minutes. Or buy your own at **{v:dealership}**, {v:carRange}. No free starter car.",
            },
            choices = {
                { "Mark the rental desk.", gps = "rental" },
                { "Mark the dealership.", gps = "dealership" },
                { "What's for sale?", faq = "vehicles.prices" },
                { "Fuel?", to = "fuel" },
                { "Where do I keep it?", to = "garage" },
            },
        },
        fuel = {
            say = {
                "{money:config.fuel.pricePerLitre} a litre. Park by a pump, kill the engine, get out, press {key:interact} at the pump, then at the car.",
                "Run dry and the engine dies until someone brings fuel. A jerrycan saves the walk.",
            },
            choices = {
                { "Mark a fuel station.", gps = "fuel" },
                { "Jerrycan?", faq = "vehicles.jerrycan" },
                { "Step by step.", faq = "vehicles.fuel" },
            },
        },
        garage = {
            say = {
                "Park it at **{v:garage}**: press {key:interact} or type `/garage`, car stopped and empty. Up to {cfg:garages.maxOwned} cars per character.",
                "Wrecked it, lost it, can't find it? It's at the **{v:impound}**. Getting it back: {v:impoundRange}.",
            },
            choices = {
                { "Mark the garage.", gps = "garage" },
                { "Impound prices?", faq = "vehicles.impound" },
                { "Keys and locks?", faq = "vehicles.lock" },
                { "Can I paint it?", faq = "vehicles.paint" },
            },
        },

        -- -------------------------------------------------------------------
        -- Tell me about chrome.
        chrome = {
            say = {
                "Chrome. Careful, choom. I know a thing or two about losing yourself to it.",
                "Find a ripperdoc's operating chair, press {key:interact} to lie down, and the clinic opens. {v:cyberwareCount} implants, {v:cyberwareRange}, straight out of your bank.",
                { requires = "not:config:dialogue.clinics.1", "Clinics aren't on the map. Keep your eyes open for the chairs." },
            },
            choices = {
                { "Mark the nearest clinic.", gps = "ripperdoc" },
                { "What's on the menu?", faq = "cyberware.price" },
                { "Sandevistan or Berserk?", faq = "cyberware.os" },
                { "How do I use them?", faq = "cyberware.use" },
                { "Any limits?", to = "limits" },
            },
        },
        limits = {
            say = {
                { requires = { "pveTiers", "config:cyberware.gating.enabled" },
                  "Every implant has a rank, and the good ranks want street cred. You earn that in PvE: missions, raids, gigs." },
                { requires = "config:cyberware.capacity.enabled",
                  "Your body has a capacity too. Every implant takes points, more cred means more room, and even at the top the best chrome won't all fit. Pick a build." },
                { requires = { "not:config:cyberware.capacity.enabled", { any = { "not:pveTiers", "not:config:cyberware.gating.enabled" } } },
                  "None. If your bank can pay, it fits." },
            },
            choices = {
                { "Which rank needs what?", faq = "cyberware.tiers" },
                { "How many points do I get?", faq = "cyberware.capacity" },
                { "Swapping and taking them out?", faq = "cyberware.install" },
                { "Iconic implants?", faq = "cyberware.iconics" },
            },
        },

        -- -------------------------------------------------------------------
        -- Crew stuff.
        crew = {
            say = {
                "Nobody makes it alone in this city. Not even me. Especially not me.",
                "Hold {key:context}, click a player, **Invite to crew**. Up to {cfg:missions.party.maxSize} of you. The leader tags the whole crew into missions and queues it for activities.",
            },
            choices = {
                { "How do I accept an invite?", faq = "crews.accept" },
                { "What can the leader do?", faq = "crews.leader" },
                { "Matchmaking?", faq = "crews.matchmaking" },
                { "What's that list at the bottom left?", faq = "crews.frame" },
                { "How do I leave?", faq = "crews.leave" },
            },
        },

        -- -------------------------------------------------------------------
        -- Something else…: the rest of the FAQ, topic by topic, and the search.
        other = {
            say = { "Shoot. Can't be weirder than the last guy's question." },
            choices = {
                { "Got a place for me to crash?", topic = "housing" },
                { "Food, health, getting shot.", topic = "health" },
                { "Guns.", topic = "weapons" },
                { "Clothes.", topic = "appearance" },
                { "Controls, chat, my bag…", to = "more" },
                { "Let me type it.", open = "search" },
            },
        },
        more = {
            say = { "The small stuff. Fine. Somebody's gotta know it." },
            choices = {
                { "Controls and menus.", topic = "controls" },
                { "Chat and voice.", topic = "chat" },
                { "My inventory.", topic = "inventory" },
                { "Animations.", topic = "animations" },
                { "I need the staff.", topic = "help" },
                { "Let me type it.", open = "search" },
            },
        },
    },
}
