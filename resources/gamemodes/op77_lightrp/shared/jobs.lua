-- Jobs and gangs. A character holds one job and one gang, each with a grade.
-- Grades are 0-based; grade 0 is the entry level. `salary` is paid to the bank
-- every jobs.paycheckMinutes (0 = no paycheck). Other modules read
-- LightRP.jobs.get(playerId) / LightRP.jobs.gang(playerId) and gate on
-- LightRP.jobs.has(playerId, "sanitation", 1). Shared: labels are public.
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
        grades = {
            [0] = { label = "Trainee", salary = 40 },
            [1] = { label = "Collector", salary = 60 },
            [2] = { label = "Driver", salary = 80 },
            [3] = { label = "Supervisor", salary = 110 },
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
        grades = {
            [0] = { label = "Salvage hand", salary = 45 },
            [1] = { label = "Scrapper", salary = 65 },
            [2] = { label = "Salvage specialist", salary = 90 },
        },
    },
    ac_cleaner = {
        label = "AC Cleaner", tag = "ROOFTOP MAINTENANCE",
        recruitment = {
            image = "img/jobs/ac-cleaner.webp", icon = "fan", environment = "Up on the rooftops",
            headline = "Keep Night City cool. Above the noise.",
            description = "Head up to the rooftops and service air-conditioning units. Clear the dust, clean the cooling equipment and move on to the next building.",
            steps = { "Reach the rooftop", "Clean the AC equipment", "Move to the next building" },
        },
        grades = {
            [0] = { label = "Maintenance trainee", salary = 50 },
            [1] = { label = "AC technician", salary = 75 },
            [2] = { label = "Senior technician", salary = 100 },
        },
    },
    -- Legacy roles remain valid for existing characters and staff assignments.
    -- They are no longer offered by public job centers.
    delivery = {
        label = "Night Courier", tag = "COURIER",
        grades = {
            [0] = { label = "Runner", salary = 45 },
            [1] = { label = "Courier", salary = 65 },
            [2] = { label = "Dispatcher", salary = 95 },
        },
    },
    mechanic = {
        label = "Rust & Chrome Garage", tag = "MECHANIC",
        grades = {
            [0] = { label = "Apprentice", salary = 50 },
            [1] = { label = "Mechanic", salary = 75 },
            [2] = { label = "Chief mechanic", salary = 105 },
            [3] = { label = "Owner", salary = 140 },
        },
    },
    taxi = {
        label = "Delamain Partner", tag = "TAXI",
        grades = {
            [0] = { label = "Driver", salary = 50 },
            [1] = { label = "Senior driver", salary = 70 },
        },
    },
    trauma = {
        label = "Street Medic", tag = "MEDIC",
        grades = {
            [0] = { label = "Volunteer", salary = 55 },
            [1] = { label = "Medic", salary = 85 },
            [2] = { label = "Chief medic", salary = 120 },
        },
    },
    ncpd = {
        label = "NCPD", tag = "NCPD",
        grades = {
            [0] = { label = "Cadet", salary = 60 },
            [1] = { label = "Officer", salary = 90 },
            [2] = { label = "Sergeant", salary = 120 },
            [3] = { label = "Lieutenant", salary = 150 },
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
