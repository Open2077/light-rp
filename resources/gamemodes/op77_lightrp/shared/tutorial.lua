-- The first day happens in the arrival hall: the white city of the map resource
-- `lobby`, cut off from Night City in its own routing bucket (the package
-- `open77_lobby_cubes` holds that bucket's night sky). Every stop uses the real
-- systems: the player menu, the inventory, a real shop checkout, and a practice
-- activity (collect, process, sell) that works like the city's free activities.
-- No job is chosen in the hall: that is the character's own story, in the city.
-- Positions are metres from the middle of the hall's square (`origin`), as the
-- map's generator lays them out (E:\Open77\Maps\lobby\tools\gen.py, POINTS).
local origin = { x = 6724.0, y = 2417.0, z = 400.0 }
local function at(x, y, z) return { x = origin.x + x, y = origin.y + y, z = origin.z + (z or 0.03) } end

LightRpTutorialConfig = {
    enabled = true,
    introSeconds = 7,
    music = "assets/audio/cloudy-day.mp3", musicVolume = 0.075,

    lobby = {
        origin = origin,
        bucket = 620000,         -- must match Config.bucket of open77_lobby_cubes/server.lua
        arrival = { name = "arrival_hall", label = "Arrival Hall", position = at(0, -101, 0.12), heading = 0.0 },
        -- The hall's box, to tell whether a saved position lies inside it.
        min = { x = origin.x - 190, y = origin.y - 220, z = origin.z - 5 },
        max = { x = origin.x + 190, y = origin.y + 170, z = origin.z + 135 },
        shop = "lobby_market",   -- LightRpShops.locations id
        work = "tutorial",       -- LightRpJobWork.jobs id: the practice activity of the job fair
    },

    -- The people of the hall. yaw 0 faces +Y (north), 90 faces west. One body per
    -- contact; `records` are tried in order until the platform accepts one.
    contacts = {
        guide = { name = "Mara", role = "ARRIVAL HALL / YOUR GUIDE", position = at(0, -14), yaw = 180,
            records = { "Character.sts_hey_rey_06_receptionist", "Character.mws_thenerves_driver_01" } },
        banker = { name = "Idris", role = "NIGHT CITY BANK", position = at(0, 27.3), yaw = 180,
            records = { "Character.mws_hey_07_zetatech_executive", "Character.kab_victim_male_rich_corpo" } },
        mechanic = { name = "Rook", role = "GARAGE / RENT-A-RIDE", position = at(-33, 0), yaw = -90,
            records = { "Character.ma_std_rcr_slacker_01", "Character.mws_thenerves_driver_02" } },
        attendant = { name = "Pim", role = "FUEL STATION", position = at(-26, -78), yaw = -90,
            records = { "Character.mws_thenerves_driver_02", "Character.ma_std_rcr_slacker_02" } },
        foreman = { name = "Juno", role = "JOB FAIR / PRACTICE BUYER", position = at(30, -78), yaw = 90,
            records = { "Character.kab_victim_male_rich_corpo", "Character.mws_thenerves_crowd_01" } },
    },
    radius = 2.7,                -- metres round a contact within which one talks

    -- The opening shot: from behind the newcomer, up the avenue to the monument.
    opening = {
        from = at(0, -106, 6.2), to = at(0, -98.5, 3.1), lookAt = at(0, 0, 13), fov = 52,
        eyebrow = "LIGHT/RP · CHAPTER 02", title = { "Your first", "day." },
        subtitle = "A name. A guide. A place to learn the city before you live in it.",
        place = "ARRIVAL HALL / OUTSIDE NIGHT CITY",
    },
    dialogueFov = 46,

    -- Each new destination is shown before it is walked: the camera rises behind
    -- the player, follows the route and settles on the place, then hands the
    -- view back. Both keys are mappings (Pause > Settings > Key bindings).
    reveal = {
        enabled = true,
        minDistance = 12,        -- closer than this, the beacon and the pointer are enough
        delay = 1.4,             -- seconds after the step changes: the "done" banner reads first
        flySeconds = 4.2, holdSeconds = 1.4, blendMs = 550, returnMs = 800,
        -- the chevrons drawn on the ground during the flight (debugDraw, no markers)
        route = { spacing = 3.0, max = 40 },
        skip = { id = "lightrp.tutorial.skip", name = "Light RP: skip the first day camera", key = "SPACE" },
        way = { id = "lightrp.tutorial.way", name = "Light RP: first day, show me the way", key = "G" },
        -- "Press F1 to skip" did not work for players (F1 is the player menu): skipping the first
        -- day has its own key, which opens the "Skip the first day?" confirmation (clickable).
        quit = { id = "lightrp.tutorial.quit", name = "Light RP: skip the first day guide", key = "F6" },
    },

    total = 15,
    -- Reserved private buckets for the Alt lesson only; the rest of the hall is shared.
    practice = { position = at(-23, -12, 0.15), prop = "crate.small", vehicle = "Vehicle.v_standard2_archer_hella_player", bucketBase = 700000 },
    -- In order. `where`: "lobby" steps happen in the hall's bucket, "city" steps
    -- in Night City. `kind`:
    --   talk      walk to `contact`, press E, read `lines`, the last button moves on
    --   menu / inventory / drink / shop   done by the real action
    --   practice  one batch at a site of the practice activity (`stage`)
    --   neuralink the player installs their implant (op77_neuralink, F2); mandatory
    --   dress     the player saves a look with a top and a bottom at `wardrobe` (a
    --             LightRpConfig.wardrobes spot, private fitting room); passed when dressed already
    -- `todo`: what the objective card lists, in order; `key` names a binding of
    -- LightRpConfig.keys (menu, inventory, interact) shown as a key cap.
    -- `place` / `direction`: the destination as the reveal camera titles it.
    -- `demo`: an example of the UI the step uses, played in the objective card.
    -- A line is a string or { text, demo }: the demo plays beside the dialogue
    -- (ui/src/features/tutorial/demos.tsx lists them).
    order = { "intro", "meet", "neuralink", "voice", "dress", "identity", "inventory", "shop", "drink", "bank", "garage", "context_prop", "vehicle_unlock", "vehicle_open", "vehicle_close", "station", "collect", "process", "sell", "depart", "outro" },
    steps = {
        intro = { index = 1, where = "lobby", kind = "intro", title = "Your first day",
            hint = "A new name and a quiet place to start. Night City can wait a few minutes." },
        meet = { index = 1, place = "Mara, your guide", direction = "Up the avenue, on the square", todo = { { text = "Follow the arrow up the avenue to Mara" }, { key = "interact", text = "Talk to her" } },
            where = "lobby", kind = "talk", contact = "guide", prompt = "Talk to Mara", action = "Show me around",
            title = "Meet your guide", hint = "Mara is waiting on the square, up the avenue. Walk over and introduce yourself.",
            line = "Over here, newcomer. Nobody should start their first day alone.",
            lines = {
                "Hey, new face. I'm Mara. This hall is not the city yet: nothing here can hurt you, and nobody is in a hurry. Take the time to learn.",
                { text = "Out there, people live their own stories. Talk in character, give others room to play, and use /ooc when it is you talking. No random attacks. Need staff? /report.", demo = "rules" },
                { text = "First thing: your Neural-Link. Nobody in Night City lives without one: calls, messages, the Screamsheet, your whole life runs through it. Then your voice, some clothes on your back, your citizen card, your bag, shops and money, Alt on real objects and a car, and your first payday.", demo = "tour" },
            } },
        neuralink = { index = 2, where = "lobby", kind = "neuralink", title = "Your Neural-Link",
            todo = { { key = "F2", text = "Open your Neural-Link" }, { text = "Install the Kiroshi implant" }, { text = "Wait until it says NEURAL-LINK ONLINE" } },
            hint = "Press F2: no implant is detected yet. Choose Install Kiroshi Neural-Link and let the installation run to the end.",
            line = "Press F2. Your optic nerve is empty for now: the Kiroshi installer does the rest, it takes a few seconds." },
        voice = { index = 3, where = "lobby", kind = "voice", title = "Find your voice",
            hint = "Choose your microphone, decide how to speak, and listen to a local test. Already set up or prefer text? You can skip this part.",
            line = "Being heard starts with being comfortable. Voice is your choice." },
        dress = { index = 4, where = "lobby", kind = "dress", wardrobe = "lobby_fitting", place = "Fitting room", direction = "In the boutique, east of the square",
            prompt = "Open the wardrobe", title = "Dress for the city",
            todo = { { text = "Follow the arrow into the boutique" }, { key = "interact", text = "Open the wardrobe" }, { text = "Put on a top and trousers, then save your look" } },
            hint = "Walk into the boutique east of the square, open the wardrobe in the back corner, put on a top and trousers and save. The fitting room is private: nobody sees you changing.",
            line = "Nobody walks into Night City in their underwear. The boutique has a fitting room: pick something you like, it's on the house." },
        context_prop = { index = 10, where = "lobby", kind = "context", place = "Interaction practice", direction = "Beside the garage", demo = "context",
            title = "Alt opens the world", hint = "Walk to the practice crate. Hold Alt, left-click the crate, then choose Inspect practice crate while still holding Alt.",
            todo = { { text = "Stand near the marked crate" }, { key = "context", text = "Keep holding it; left-click the crate" }, { text = "Click Inspect practice crate in the menu" } },
            line = "Keep Alt held while choosing. Releasing it or pressing Escape closes the menu. Objects, cars and people offer different actions." },
        vehicle_unlock = { index = 11, where = "lobby", kind = "context", place = "Practice car", direction = "Beside the crate", demo = "context",
            title = "Your keys, your car", hint = "You have temporary keys. Hold Alt, click the practice car, then choose Unlock vehicle.",
            todo = { { text = "Walk beside the marked practice car" }, { key = "context", text = "Hold and left-click the car" }, { text = "Choose Unlock vehicle" } },
            line = "Options depend on the target, your keys and the vehicle's state. If an option is missing, get closer and check the lock." },
        vehicle_open = { index = 11, where = "lobby", kind = "context", place = "Practice car", demo = "context",
            title = "Explore the submenus", hint = "Open the car's Alt menu again. Choose Trunk & hood, then Open trunk. Watch the real trunk lift.",
            todo = { { key = "context", text = "Hold and click the car again" }, { text = "Open Trunk & hood → Open trunk" }, { text = "Keep the car parked and stay outside" } },
            line = "Back or right-click returns one level. Access trunk inventory is a separate option for storing items; Open trunk moves the lid." },
        vehicle_close = { index = 11, where = "lobby", kind = "context", place = "Practice car", demo = "context",
            title = "Leave it as you found it", hint = "Use Alt → Trunk & hood → Close trunk. The car and its temporary keys are returned when the exercise ends.",
            todo = { { key = "context", text = "Hold and click the car" }, { text = "Choose Trunk & hood → Close trunk" } },
            line = "Vehicle controls also contains lights, engine and horn. Some controls require an unlocked, parked car or the driver's seat." },
        identity = { index = 5, demo = "menu", todo = { { key = "menu", text = "Open the player menu" }, { text = "Select Identity" } },
            where = "lobby", kind = "menu", title = "A name in the city",
            hint = "Open the player menu and select Identity. Your citizen record and bank details live there.",
            line = "Keep your own name out of it. Out there, you're the person on that card." },
        inventory = { index = 6, demo = "inventory", todo = { { key = "menu", text = "Close the player menu" }, { key = "inventory", text = "Open your inventory" } },
            where = "lobby", kind = "inventory", title = "Travel light",
            hint = "Close the player menu and open your inventory. Your starter bag contains food and water.",
            line = "Check your pockets before you head out. The city won't remind you to eat." },
        shop = { index = 7, place = "Market stall", direction = "East of the square", demo = "shop", todo = { { text = "Follow the arrow to the vendor" }, { key = "interact", text = "Open the shop" }, { text = "Add a drink, pick cash or bank, confirm" } },
            where = "lobby", kind = "shop", prompt = "Browse shop", title = "Your first purchase",
            hint = "Walk to the shop east of the square, talk to the vendor and buy a drink: pick it, choose cash or bank, confirm.",
            line = "Shops sell and buy back. Every vendor in the city works like this one. Get yourself something to drink." },
        drink = { index = 7, demo = "drink", todo = { { key = "inventory", text = "Open your inventory" }, { text = "Use a drink and stay still until it is finished" } },
            where = "lobby", kind = "drink", title = "Take a breath",
            hint = "Open your inventory and use a drink. Stay still until the drinking action finishes.",
            line = "Hunger and thirst drop with time: keep an eye on them, the city won't." },
        bank = { index = 8, place = "Night City Bank", direction = "North of the square", todo = { { text = "Follow the arrow to the bank" }, { key = "interact", text = "Talk to Idris" } },
            where = "lobby", kind = "talk", contact = "banker", prompt = "Talk to the banker", action = "Understood",
            title = "Your money", hint = "Walk to the bank north of the square and talk to the banker.",
            line = "Cash in your pocket, the rest on your account. Idris will tell you how it works.",
            lines = {
                { text = "Welcome to Night City Bank. Your account was opened when you arrived: its number is on your citizen card, in the player menu under Identity.", demo = "card" },
                { text = "You carry cash and you own a bank balance. Shops take both. Paychecks land on the account; cash is what you hand to people with /pay when they stand next to you.", demo = "money" },
                { text = "Transfers go from account to account with that number. Keep it handy, and never give it to someone you would not trust with your wallet.", demo = "transfer" },
            } },
        garage = { index = 9, place = "Garage · Rent-a-Ride", direction = "West of the square", todo = { { text = "Follow the arrow to the garage" }, { key = "interact", text = "Talk to Rook" } },
            where = "lobby", kind = "talk", contact = "mechanic", prompt = "Talk to the mechanic", action = "Got it",
            title = "Wheels", hint = "Walk to the garage west of the square and talk to the mechanic.",
            line = "Night City is big. Rook knows how to get you moving.",
            lines = {
                { text = "No car yet? Rent-a-Ride desks rent by the half hour: walk up, pick a model, pay, and it is parked beside the desk. Return it at any desk.", demo = "rental" },
                { text = "Your key locks and unlocks from a few metres: one horn bip locks, two unlock. A locked car keeps everyone out of the seats and the trunk.", demo = "keys" },
                { text = "Later you can buy your own at a dealership and store it in a garage. Hold Alt and left-click a vehicle you have keys for: its trunk, hood, engine and lights are in that menu. Let's try it on a crate and a practice car beside the garage.", demo = "vehicle" },
            } },
        station = { index = 12, place = "Fuel station", direction = "South-west, down the avenue", todo = { { text = "Follow the arrow to the fuel station" }, { key = "interact", text = "Talk to Pim" } },
            where = "lobby", kind = "talk", contact = "attendant", prompt = "Talk to the attendant", action = "Good to know",
            title = "Fuel", hint = "Walk to the fuel station south-west, down the avenue, and talk to the attendant.",
            line = "A dry tank stops the engine wherever you are. Pim will explain.",
            lines = {
                { text = "Every vehicle burns fuel while its engine runs: the gauge is on your dashboard, and it turns amber when you are on the reserve.", demo = "gauge" },
                { text = "At a station, park by a pump, switch the engine off, get out and use the pump. You pay by the litre.", demo = "pump" },
                { text = "A jerrycan from a station fits in your bag or your trunk: it saves you when the tank is empty far from everything.", demo = "jerrycan" },
            } },
        collect = { index = 13, place = "Job fair · supply crates", direction = "South-east, down the avenue", demo = "collect", todo = { { text = "Follow the arrow to the supply crates" }, { key = "interact", text = "Start collecting" }, { text = "Stay still until the crate is yours" } },
            where = "lobby", kind = "practice", stage = "collect", title = "Earn it: collect",
            hint = "Walk to the job fair south-east, down the avenue. At the supply crates, press E and stay still until the crate is yours.",
            line = "Most honest work here is the same three moves: collect, process, sell. Try them once, on the house." },
        process = { index = 13, place = "Workbench", direction = "One stand further east", demo = "process", todo = { { text = "Follow the arrow to the workbench" }, { key = "interact", text = "Process the crate" }, { text = "Stay still until the parts are ready" } },
            where = "lobby", kind = "practice", stage = "process", title = "Earn it: process",
            hint = "Carry the crate to the workbench, one stand further east, and press E: one crate becomes sorted parts. Loads have weight; out there a trunk carries more.",
            line = "Raw loads are worth nothing. Processed goods are what a buyer pays for." },
        sell = { index = 13, place = "Juno, the buyer", direction = "In the middle of the fair", demo = "sell", todo = { { text = "Follow the arrow to Juno, the buyer" }, { key = "interact", text = "Sell your parts" } },
            where = "lobby", kind = "practice", stage = "sell", title = "Earn it: sell",
            hint = "Bring the parts to Juno, the buyer in the middle of the fair, and press E. The payment lands on your bank account.",
            line = "Sell everything you made. That is a payday: small, but yours." },
        depart = { index = 14, place = "Mara, your guide", direction = "Back on the square", todo = { { text = "Follow the arrow back to Mara" }, { key = "interact", text = "Talk to her to leave for Night City" } },
            where = "lobby", kind = "talk", contact = "guide", prompt = "Talk to Mara", action = "Take me home",
            title = "Ready when you are", hint = "Go back to Mara on the square. She opens the way to Night City.",
            line = "You have a name, a bag, an account and you know how to earn. Come and see me when you are ready to leave.",
            lines = {
                { text = "There you go: a name, money, wheels to rent, and a way to earn. In the city, sanitation and scrap work exactly like the practice you just did; the job center hands out the rest.", demo = "work" },
                "Which job you take is your story, not mine: the job center, the shops, the rental desk and the wardrobe are marked on your map out there. Respect the people you meet.",
                "One last thing: Night City Housing gave you a free starter studio in Kabuki Studios, a short walk from where you arrive; its door is on your map. This door takes you into the city. You can come back to this guide any time with /tutorial. Ready?",
            } },
        -- The guide leaves the newcomer at The Crossing (spawn.afterTutorial, Westbrook), not inside
        -- the studio: the studio is given and its door marked on the map, a short walk away.
        outro = { index = 15, where = "city", kind = "outro", action = "See you around, Mara", title = "The rest is your story",
            hint = "Your studio's door is on your map, a short walk away. Find a job, explore or meet your neighbours.",
            lines = {
                { text = "Welcome to Night City. This is The Crossing, in Westbrook. Your practice pay is on your account; check it in the player menu.", demo = "payday" },
                "Your free studio is in Kabuki Studios, about 115 m from here: its door is on your map. Inside, the storage and the wardrobe are yours and your key holders'; F1, My homes, manages the lock and the keys.",
                "Questions about the city? Johnny, on this esplanade, knows the jobs, the cars and the money. The job center is on your map. I'll be in the hall for the next newcomers. See you around.",
            } },
    },
}
