-- Authoritative prices in whole eddies. Public stock deliberately excludes the
-- staff-only models. No starter car, automatic purchase or free vehicle grant.
-- Price bands (docs/economy-balance.md, 2026-11): a first car within the first
-- hours (4,000-6,500), a decent one in about 3-4 h of mixed play (12,000-16,000),
-- the best ones in about 20-30 h (80,000-100,000).
--
-- A location sells `stock` and files the vehicle under `garage` (a public
-- garage, server/config/garages.lua). Optional:
--   clerk = true            a sales clerk (crowd NPC, AI off) at `position`, facing `heading`
--   delivery = { name, position, heading }
--                           the vehicle bought there is driven out to this bay at
--                           once (locked, keys handed over, GPS to it); when the bay
--                           is taken or the buyer already has a personal vehicle
--                           out, it waits at `garage` and the GPS points there.
local publicStock = {
    { key = "maimai", price = 10000, description = "A small footprint. A big city. Your first set of keys." },
    { key = "galena", price = 16000, description = "A practical everyday ride for getting your life in Night City started." },
    { key = "apollo", price = 12500, description = "Two wheels, a clear road and a little room to explore." },
    { key = "hella", price = 30000, description = "An understated daily driver, ready for the next shift." },
    { key = "colby", price = 35000, description = "An honest workhorse for the days that ask a little more." },
    { key = "quartz", price = 47500, description = "Compact proportions with a sharper attitude." },
    { key = "hozuki", price = 60000, description = "A clean silhouette with room for your everyday plans." },
    { key = "supron", price = 40000, description = "Keep your business moving, one trip at a time." },
    { key = "columbus", price = 75000, description = "A dependable companion for work across the city." },
    { key = "cortes", price = 95000, description = "Make your next arrival a little more composed." },
    { key = "thrax", price = 155000, description = "A commanding presence for the city's wider avenues." },
    { key = "bandit", price = 130000, description = "Street character, without blending into the crowd." },
    { key = "merrimac", price = 115000, description = "A substantial ride for wherever the working day takes you." },
    { key = "semimaru", price = 250000, description = "For the moments when the journey matters as much as the destination." },
    { key = "kusanagi", price = 200000, description = "An unmistakable shape. A different way to see Night City." },
}
LightRpDealerships = {
    enabled = true, range = 3.0, sessionMs = 180000,
    locations = {
        {
            -- The showroom of the map resource `cardealer`: the clerk stands at the
            -- reception, facing the entrance (north; the hall is turned -4 degrees).
            id = "ncmotors", name = "Night City Motors", subtitle = "Drive it home today.", bucket = 0,
            position = { x = -288.450867, y = -1877.942139, z = 9.0 }, heading = -4.0, clerk = true,
            garage = "kabuki",
            delivery = { name = "Night City Motors // Delivery bay",
                position = { x = -290.010284, y = -1913.319824, z = 8.571625 }, heading = 169.623779 },
            stock = publicStock,
        },
    },
    -- Demonstration cars (server/modules/showroom.lua): parked, locked, frozen and
    -- indestructible, put back if they ever disappear. Nobody drives them. `key`
    -- is a catalogue key (LightRpConfig.vehicles.catalog); `yaw` in degrees, 0
    -- faces north (+Y), counter-clockwise.
    displays = {
        -- Night City Motors (map resource `cardealer`): the four podiums of the
        -- showroom (floor z 9, podium top 9.22; the hall is turned -4 degrees,
        -- entrance to the north). Each pair faces the central aisle.
        { id = "ncmotors_podium1", key = "semimaru", position = { x = -291.74, y = -1867.49, z = 9.25 }, yaw = -34, bucket = 0 },
        { id = "ncmotors_podium2", key = "cortes",   position = { x = -282.96, y = -1868.10, z = 9.25 }, yaw = 26,  bucket = 0 },
        { id = "ncmotors_podium3", key = "quartz",   position = { x = -292.22, y = -1874.37, z = 9.25 }, yaw = -34, bucket = 0 },
        { id = "ncmotors_podium4", key = "thrax",    position = { x = -283.45, y = -1874.98, z = 9.25 }, yaw = 26,  bucket = 0 },
    },
}
