-- Authoritative prices in whole eddies. Public stock deliberately excludes the
-- staff-only models. No starter car, automatic purchase or free vehicle grant.
LightRpDealerships = {
    enabled = true, range = 3.0, sessionMs = 180000,
    locations = {
        {
            id = "citycenter", name = "City Motors", subtitle = "Your next chapter starts here.", bucket = 0,
            position = { x = -640.0, y = -377.0, z = 8.19 }, garage = "citycenter",
            stock = {
                { key = "maimai", price = 4000, description = "A small footprint. A big city. Your first set of keys." },
                { key = "galena", price = 6500, description = "A practical everyday ride for getting your life in Night City started." },
                { key = "apollo", price = 5000, description = "Two wheels, a clear road and a little room to explore." },
                { key = "hella", price = 10000, description = "An understated daily driver, ready for the next shift." },
                { key = "colby", price = 12000, description = "An honest workhorse for the days that ask a little more." },
                { key = "quartz", price = 16000, description = "Compact proportions with a sharper attitude." },
                { key = "hozuki", price = 19000, description = "A clean silhouette with room for your everyday plans." },
                { key = "supron", price = 14000, description = "Keep your business moving, one trip at a time." },
                { key = "columbus", price = 22000, description = "A dependable companion for work across the city." },
                { key = "cortes", price = 28000, description = "Make your next arrival a little more composed." },
                { key = "thrax", price = 42000, description = "A commanding presence for the city's wider avenues." },
                { key = "bandit", price = 35000, description = "Street character, without blending into the crowd." },
                { key = "merrimac", price = 32000, description = "A substantial ride for wherever the working day takes you." },
                { key = "semimaru", price = 60000, description = "For the moments when the journey matters as much as the destination." },
                { key = "kusanagi", price = 45000, description = "An unmistakable shape. A different way to see Night City." },
            },
        },
    },
}
