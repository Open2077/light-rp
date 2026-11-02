-- Courier (job `delivery`): each work order is drawn at random when it is
-- collected at the employment office: a number of orders, a pickup point per
-- order (restaurants, depots), then a drop-off per order (megabuildings,
-- apartments). The pay follows the route's length.
--
-- Locations given by the server owner (2026-10-29). A point is { id (unique), name
-- (shown on the GPS and the HUD), position = { x, y, z } (on the ground, reachable
-- on foot) }; names can be changed freely, ids are what runs in progress refer to.
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
        { id = "charter_hill_depot",  name = "Charter Hill depot",  position = { x = -103.268875, y = 215.001312, z = 14.742729 } },
        { id = "charter_hill_market", name = "Charter Hill market", position = { x = -198.342453, y = 132.630508, z = 14.664162 } },
        { id = "downtown_food_stand", name = "Downtown food stand", position = { x = -679.844360, y = -370.317505, z = 8.614265 } },
        { id = "coastview_depot",     name = "Coastview depot",     position = { x = -1822.422852, y = -1972.984253, z = 52.500000 } },
    },
    dropoffs = {
        { id = "h10_mid",             name = "Megabuilding H10 // Mid floor",   position = { x = -1395.902344, y = 1286.751465, z = 119.082413 } },
        { id = "h10_lower",           name = "Megabuilding H10 // Lower floor", position = { x = -1391.615723, y = 1300.340454, z = 115.082382 } },
        { id = "h10_upper",           name = "Megabuilding H10 // Upper floor", position = { x = -1414.874512, y = 1252.311768, z = 123.082397 } },
        { id = "charter_hill_apts",   name = "Charter Hill apartments",         position = { x = -393.496185, y = 104.165359, z = 22.133102 } },
        { id = "wellsprings_home",    name = "Wellsprings residence",           position = { x = -2084.058838, y = -1137.153809, z = 36.972992 } },
        { id = "vista_del_rey_block", name = "Vista del Rey block",             position = { x = -537.433105, y = -1436.147583, z = 6.876602 } },
    },
}
