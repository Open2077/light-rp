-- Jobs and gangs. A character holds one job and one gang, each with a grade.
-- Grades are 0-based; grade 0 is the entry level. `salary` is paid to the bank
-- every jobs.paycheckMinutes (0 = no paycheck). Other modules read
-- LightRP.jobs.get(playerId) / LightRP.jobs.gang(playerId) and gate on
-- LightRP.jobs.has(playerId, "sanitation", 1). Shared: labels are public.
--
-- `guide` is the job guide the page shows once a player takes the job (after the
-- job center closes) and again from the player menu (F1 → My job → Job guide):
-- pages of { title, body, demo, tips }. `demo` names an animated picture drawn by
-- the page (ui/src/features/jobs/guideDemos.tsx): courier-route, courier-dispatch,
-- courier-hud, courier-pickup, courier-dropoff, courier-pay, work-cycle,
-- work-collect, work-trunk, work-process, work-sell, paycheck, run-desk,
-- rooftop-lift, rooftop-clean, run-report, run-cancel. `tips` are short lines
-- under the text.
-- Paychecks are a small bonus on top of the work itself (≈ 6 % of an active
-- worker's income); service jobs without a work loop sit higher. See
-- docs/economy-balance.md.
LightRpJobs = {
    unemployed = {
        label = "Unemployed", tag = "CIVILIAN",
        grades = { [0] = { label = "Citizen", salary = 0 } },
    },
    sanitation = {
        label = "Sanitation", tag = "CITY SERVICES",
        recruitment = {
            image = "img/jobs/sanitation.webp", icon = "trash-2", environment = "Street level",
            headline = "A cleaner city. One block at a time.",
            description = "Collect bags of waste, sort them into recyclable materials and sell your stock. Work whenever you like; use a vehicle trunk when your bag is full.",
            steps = { "Collect weighted trash bags", "Sort waste into recyclables", "Sell your finished materials" },
        },
        guide = {
            { title = "Welcome to Sanitation", demo = "work-cycle",
              body = "You keep the streets clean and get paid for what you recover. The work runs in three stages: collect trash bags, sort them into recyclables, sell the recyclables. No shift, no work order: work whenever you like, as long as you like.",
              tips = { "Your items stay in your bag between sessions.", "Each stage has its own place on the map." } },
            { title = "1 · Collect trash bags", demo = "work-collect",
              body = "Go to a waste collection point: F1 → My job → Collection point GPS sets the route. At the marker, press E and stay still while the bar fills. A trash bag lands in your bag, and the next one starts on its own until your bag is full.",
              tips = { "Moving or pressing Escape stops the work; what you collected stays yours.", "A trash bag weighs several kilos: watch your bag's weight." } },
            { title = "Carry more with a vehicle", demo = "work-trunk",
              body = "Your bag fills fast. Park a vehicle next to the site, hold ALT while looking at it and open the Trunk: drag your trash bags into it, collect again, then drive the whole load to the next stage.",
              tips = { "Lock your car (L) when you walk away from it." } },
            { title = "2 · Sort into recyclables", demo = "work-process",
              body = "Take your trash bags to the processing site (F1 → My job → Processing GPS). Press E: each bag is sorted into recyclables, one after the other, while you stay at the point.",
              tips = { "Bags in a trunk must go back into your bag first." } },
            { title = "3 · Sell to the buyer", demo = "work-sell",
              body = "The buyer takes your recyclables at a fixed price per unit (F1 → My job → Buyer GPS). Press E: the money goes straight to your bank account.",
              tips = { "All the recyclables in your bag are sold at once: leave in a trunk what you want to keep." } },
            { title = "Your paycheck", demo = "paycheck",
              body = "On top of what you sell, the city pays you a salary into your bank account at regular intervals while you are in town. It grows with your grade.",
              tips = { "Find this guide again: F1 → My job → Job guide." } },
        },
        grades = {
            [0] = { label = "Trainee", salary = 100 },
            [1] = { label = "Collector", salary = 150 },
            [2] = { label = "Driver", salary = 200 },
            [3] = { label = "Supervisor", salary = 275 },
        },
    },
    scrapper = {
        label = "Scrapper", tag = "SALVAGE & RECYCLING",
        recruitment = {
            image = "img/jobs/scrapper.webp", icon = "hammer", environment = "Industrial yards",
            headline = "Find value in what the city leaves behind.",
            description = "Collect scrap, process it into reusable parts and sell them at the depot. No work order: gather at your own pace and transport loads in your trunk.",
            steps = { "Collect scrap until your bag is full", "Process it into salvaged parts", "Sell parts at the depot" },
        },
        guide = {
            { title = "Welcome to the scrapyards", demo = "work-cycle",
              body = "You turn what the city throws away into parts people pay for. Three stages: collect scrap, process it into salvaged parts, sell the parts at the depot. No shift and no work order: you work at your own pace.",
              tips = { "Your items stay in your bag between sessions.", "Each stage has its own place on the map." } },
            { title = "1 · Collect scrap", demo = "work-collect",
              body = "Go to a scrap collection point: F1 → My job → Collection point GPS sets the route. At the marker, press E and stay still while the bar fills. Scrap goes into your bag, and collecting continues on its own until your bag is full.",
              tips = { "Moving or pressing Escape stops the work; what you collected stays yours.", "Scrap is heavy: watch your bag's weight." } },
            { title = "Carry more with a vehicle", demo = "work-trunk",
              body = "Park a vehicle next to the yard, hold ALT while looking at it and open the Trunk: move your scrap into it, collect again, then drive the whole load to the workshop.",
              tips = { "Lock your car (L) when you walk away from it." } },
            { title = "2 · Process into parts", demo = "work-process",
              body = "At the processing workshop (F1 → My job → Processing GPS), press E: your scrap is turned into salvaged parts while you stay at the bench.",
              tips = { "Scrap in a trunk must go back into your bag first." } },
            { title = "3 · Sell at the depot", demo = "work-sell",
              body = "The depot buys salvaged parts at a fixed price per unit (F1 → My job → Buyer GPS). Press E: the money goes straight to your bank account.",
              tips = { "Every part in your bag is sold at once: leave in a trunk what you want to keep." } },
            { title = "Your paycheck", demo = "paycheck",
              body = "On top of what you sell, you receive a salary into your bank account at regular intervals while you are in town. It grows with your grade.",
              tips = { "Find this guide again: F1 → My job → Job guide." } },
        },
        grades = {
            [0] = { label = "Salvage hand", salary = 110 },
            [1] = { label = "Scrapper", salary = 160 },
            [2] = { label = "Salvage specialist", salary = 225 },
        },
    },
    -- No longer offered by the job centers (the courier replaced it); kept for the
    -- characters who hold it.
    ac_cleaner = {
        label = "AC Cleaner", tag = "ROOFTOP MAINTENANCE",
        recruitment = {
            image = "img/jobs/ac-cleaner.webp", icon = "fan", environment = "Up on the rooftops",
            headline = "Keep Night City cool. Above the noise.",
            description = "Head up to the rooftops and service air-conditioning units. Clear the dust, clean the cooling equipment and move on to the next building.",
            steps = { "Reach the rooftop", "Clean the AC equipment", "Move to the next building" },
        },
        guide = {
            { title = "Collect a work order", demo = "run-desk",
              body = "Rooftop maintenance works by work orders. Collect one at a Job Center desk: press E at the clerk, then Start a run. Your route appears on the GPS and in the work order card on the right of your screen.",
              tips = { "One work order at a time." } },
            { title = "Reach the rooftop", demo = "rooftop-lift",
              body = "Use the marked service access at the foot of the building: press E and you are taken up. No climbing needed. The service exit on the roof brings you back down at any time.",
              tips = {} },
            { title = "Clean the units", demo = "rooftop-clean",
              body = "At each yellow marker, press E and stay still while the bar fills. The next unit is set on your GPS as soon as one is done.",
              tips = { "Moving or Escape stops the action; the route keeps your progress." } },
            { title = "Report and get paid", demo = "run-report",
              body = "Once every unit is clean, return your report to dispatch: the full pay lands in your bank account. An unfinished order pays nothing.",
              tips = { "F1 → My job shows your run and can abandon it." } },
        },
        grades = {
            [0] = { label = "Maintenance trainee", salary = 110 },
            [1] = { label = "AC technician", salary = 160 },
            [2] = { label = "Senior technician", salary = 225 },
        },
    },
    -- Courier: random food / parcel runs from restaurants to megabuildings, paid by
    -- distance (server/config/delivery.lua). Replaced AC Cleaner at the job centers.
    delivery = {
        label = "Courier", tag = "FOOD & PARCEL DELIVERY",
        recruitment = {
            image = "img/jobs/delivery.webp", icon = "package", environment = "All over the city",
            headline = "Hot food, cold streets. Deliver before it cools.",
            description = "Collect orders at restaurants and depots, then deliver them to apartments and megabuildings. Every route is different; the longer it is, the more it pays. A vehicle helps.",
            steps = { "Collect the orders at their pickup points", "Deliver each one to its address", "Get paid by the distance covered" },
        },
        guide = {
            { title = "Welcome, Courier", demo = "courier-route",
              body = "Restaurants and depots hand you orders; you bring them to apartments and megabuildings. Every run is drawn at random: a few orders, a pickup point for each, then an address for each. The longer the route, the more it pays.",
              tips = { "One run at a time.", "A vehicle makes the long runs much faster." } },
            { title = "Get a run", demo = "courier-dispatch",
              body = "Wherever you are, open the player menu (F1) → My job → Start a run. Dispatch draws your route on the spot and tells you the number of orders, the distance and the pay before you set off. A Job Center desk can hand you one too.",
              tips = { "The pay is fixed when the run is drawn." } },
            { title = "Follow your work order", demo = "courier-hud",
              body = "The work order card on the right of your screen shows the next stop, the orders you carry, the distance and the pay. The GPS leads you to a yellow marker on the ground.",
              tips = { "Lost the route? F1 → My job → GPS to my next stop.", "The card also lists /job gps and /job cancel." } },
            { title = "Pick up the orders", demo = "courier-pickup",
              body = "At a pickup point, stand in the marker, press E and stay still while the bar fills: the order goes into your bag. Then the GPS moves on to the next pickup. Each order weighs 1 kg: keep some room in your bag.",
              tips = { "A full bag is refused before the bar starts: make room and press E again." } },
            { title = "Deliver them", demo = "courier-dropoff",
              body = "Once every order is collected, the GPS takes you from address to address. At each one, press E to hand one order over. The last delivery completes the run and pays you.",
              tips = { "An order you no longer carry cannot be delivered." } },
            { title = "Paid by distance", demo = "courier-pay",
              body = "Your pay is a base, plus an amount per stop, plus an amount per kilometre of route, counted from where you took the run. It lands in your bank account at the last delivery, on top of your regular paycheck.",
              tips = { "Short city runs are quick money; long ones across districts pay the most." } },
            { title = "If plans change", demo = "run-cancel",
              body = "You can abandon a run at any time: F1 → My job → Abandon this run. It pays nothing, and the orders still in your bag are taken back. Dying, changing job or leaving the run unfinished for too long ends it the same way.",
              tips = { "Find this guide again: F1 → My job → Job guide." } },
        },
        grades = {
            [0] = { label = "Runner", salary = 110 },
            [1] = { label = "Courier", salary = 160 },
            [2] = { label = "Dispatcher", salary = 240 },
        },
    },
    mechanic = {
        label = "Rust & Chrome Garage", tag = "MECHANIC",
        grades = {
            [0] = { label = "Apprentice", salary = 200 },
            [1] = { label = "Mechanic", salary = 275 },
            [2] = { label = "Chief mechanic", salary = 350 },
            [3] = { label = "Owner", salary = 450 },
        },
    },
    taxi = {
        label = "Delamain Partner", tag = "TAXI",
        grades = {
            [0] = { label = "Driver", salary = 200 },
            [1] = { label = "Senior driver", salary = 275 },
        },
    },
    trauma = {
        label = "Street Medic", tag = "MEDIC",
        grades = {
            [0] = { label = "Volunteer", salary = 225 },
            [1] = { label = "Medic", salary = 325 },
            [2] = { label = "Chief medic", salary = 425 },
        },
    },
    ncpd = {
        label = "NCPD", tag = "NCPD",
        grades = {
            [0] = { label = "Cadet", salary = 250 },
            [1] = { label = "Officer", salary = 325 },
            [2] = { label = "Sergeant", salary = 400 },
            [3] = { label = "Lieutenant", salary = 500 },
        },
    },
}

LightRpGangs = {
    none = { label = "No gang", tag = "—", color = "#8A8F9C", grades = { [0] = { label = "—" } } },
    valentinos = {
        label = "Valentinos", tag = "VALENTINOS", color = "#D9A441",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
    tyger_claws = {
        label = "Tyger Claws", tag = "TYGER CLAWS", color = "#E23C7A",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
    maelstrom = {
        label = "Maelstrom", tag = "MAELSTROM", color = "#FF2E3C",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
    sixth_street = {
        label = "6th Street", tag = "6TH STREET", color = "#3E8FD8",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
    animals = {
        label = "Animals", tag = "ANIMALS", color = "#B86B2E",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
    voodoo_boys = {
        label = "Voodoo Boys", tag = "VOODOO BOYS", color = "#35D07F",
        grades = { [0] = { label = "Recruit" }, [1] = { label = "Member" }, [2] = { label = "Lieutenant" }, [3] = { label = "Boss" } },
    },
}
