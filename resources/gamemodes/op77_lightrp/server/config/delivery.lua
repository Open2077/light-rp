-- Courier (job `delivery`): each work order is drawn at random when it is
-- collected at the employment office: a number of orders, a pickup point per
-- order (restaurants, depots), then a drop-off per order (megabuildings,
-- apartments). The pay follows the route's length.
--
-- TEST POINTS ONLY: the locations below are placeholders around City Center,
-- Kabuki and Northside, a few metres off existing interaction points, to try the
-- loop. Replace `pickups` and `dropoffs` with the real locations; nothing else
-- needs to change. A point is { id (unique), name (shown on the GPS and the HUD),
-- position = { x, y, z } (on the ground, reachable on foot) }.
LightRpDelivery = {
    orders = { min = 2, max = 3 },   -- orders per run: as many pickups, then as many drop-offs
    pickupMs = 4500,                 -- the progress bar at a pickup (collecting the order)
    dropoffMs = 3500,                -- the progress bar at a drop-off (handing it over)
    item = "delivery_order",         -- what the courier carries between the two (shared/items.lua)
    lifetimeMs = 45 * 60000,         -- an unfinished run expires after this
    -- Pay = base + perStop × stops + perKm × route length (straight lines from the
    -- office through every stop, in km), rounded, within [min, max].
    pay = { base = 40, perStop = 20, perKm = 90, min = 80, max = 900 },

    pickups = {
        { id = "test_noodles", name = "Noodle bar (test)",       position = { x = -662.5, y = -378.4, z = 9.19 } },
        { id = "test_burger",  name = "Burger stand (test)",     position = { x = -640.0, y = -388.0, z = 8.19 } },
        { id = "test_fuel",    name = "Station kiosk (test)",    position = { x = -605.8, y = -715.0, z = 8.72 } },
    },
    dropoffs = {
        { id = "test_plaza",    name = "City Center plaza (test)",   position = { x = -625.6, y = -391.6, z = 8.19 } },
        { id = "test_deck",     name = "Market deck (test)",         position = { x = -671.1, y = -382.6, z = 9.16 } },
        { id = "test_alley",    name = "Back alley block (test)",    position = { x = -1070.9, y = -108.4, z = 7.48 } },
        { id = "test_kabuki",   name = "Kabuki megabuilding (test)", position = { x = -713.8, y = 886.1, z = 32.67 } },
        { id = "test_northside", name = "Northside block (test)",    position = { x = -783.0, y = 765.2, z = 22.46 } },
    },
}
