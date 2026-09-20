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
        label = "NC Sanitation", tag = "SANITATION",
        grades = {
            [0] = { label = "Trainee", salary = 40 },
            [1] = { label = "Collector", salary = 60 },
            [2] = { label = "Driver", salary = 80 },
            [3] = { label = "Supervisor", salary = 110 },
        },
    },
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
