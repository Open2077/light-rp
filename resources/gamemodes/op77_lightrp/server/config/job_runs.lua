-- Work orders: AC Cleaner's fixed route below, and the courier's routes drawn at
-- random for each order (`generator`, server/config/delivery.lua). Sanitation/Scrapper: see job_work.lua.
-- AC Cleaner uses TEMPORARY TEST POINTS, pending final locations.
-- These markers represent loads / machinery; they do not modify map props.
-- Server-owned routes. Coordinates are not accepted from the client.
-- Each run ends at its configured depot / dispatch; only a complete route earns its reward.
local depot = { x = -645.578979, y = -412.519470, z = 8.196312 }
local function work(label, x, y, z, duration)
    return { kind = "work", label = label, position = { x = x, y = y, z = z }, durationMs = duration or 6500 }
end
LightRpJobRuns = {
    range = 2.6, lifetimeMs = 90 * 60000, cooldownMs = 15000,
    -- How long a run survives its worker being out of the public world (a loading
    -- screen, a fitting room, an interior) before it ends.
    awayGraceMs = 90000,
    -- Service access is deliberately independent of employment: cancelling or
    -- reconnecting on a roof must NEVER remove the way back down.
    lifts = {
        market = { ground = { x = -667.14, y = -382.61, z = 9.16 },
            roof = { x = -676, y = -384, z = 16.4054 }, heading = 180 },
    },
    routes = {
        ac_cleaner = {
            label = "Rooftop maintenance", reward = 260, estimate = "5–8 min", icon = "fan",
            description = "Use the marked service access, clean the rooftop cooling units, then return your maintenance report.",
            steps = {}, -- Temporary test deck below; replace with the real HVAC locations.
        },
        delivery = {
            generator = "delivery", label = "Delivery run", icon = "package",
            -- Dispatch sends the route anywhere in the city: the player menu (F1 →
            -- My job → Start a run) collects it without visiting a job center.
            remoteDispatch = true,
            estimate = "Random route · paid by distance",
            description = "Collect each order at its pickup point, then deliver them one by one. The route is drawn when you collect it; the pay follows its length.",
            steps = {}, -- drawn per order
        },
    },
}
local lift = LightRpJobRuns.lifts.market
LightRpJobRuns.routes.ac_cleaner.steps = {
    { kind = "lift", label = "Service access · Market deck", position = lift.ground, destination = lift.roof, heading = 180 },
    work("AC unit · Remove the dust", lift.roof.x, lift.roof.y, lift.roof.z, 7500),
    work("AC unit · Flush the condenser", lift.roof.x, lift.roof.y, lift.roof.z, 8500),
    work("AC unit · Inspect the cooling fan", lift.roof.x, lift.roof.y, lift.roof.z, 6000),
    { kind = "lift", label = "Service exit · Street level", position = lift.roof, destination = lift.ground, heading = 0 },
    { kind = "return", label = "Submit the maintenance report", position = depot, durationMs = 3000 },
}
