-- Reusable stationary RP actions. Workspots own their authored props and the
-- temporary third-person camera; never overwrite the player's F7 preference.
-- The server chooses the action, duration and effects, never the UI or metadata.
LightRpConsumableProfiles = {
    bottle = { profile = "bottle", clip = "stand__rh_bottle__01__drink__01", durationMs = 6500, label = "Drinking", icon = "droplet" },
    can = { profile = "drink", clip = "stand__rh_can__01__drink__01", durationMs = 5500, label = "Drinking", icon = "cup-soda" },
    meal = { profile = "takeout", clip = "stand__2h_chinesetakeout__01__eat__01", durationMs = 8000, label = "Eating", icon = "utensils" },
    snack = { profile = "takeout", clip = "stand__2h_chinesetakeout__01__eat__02", durationMs = 5500, label = "Eating", icon = "utensils" },
    smoke = { profile = "smoke", clip = "stand__rh_cigarette__01__smoke__01", durationMs = 12000, label = "Smoking", icon = "cigarette" },
}

local items = {
    water = "bottle", electrolyte = "bottle", juice = "bottle",
    soda = "can", coffee = "can", energydrink = "can",
    burrito = "meal", synthmeat = "meal", noodles = "meal", dumplings = "meal", pizza = "meal",
    apple = "snack", candy = "snack", onigiri = "snack", proteinbar = "snack", cigarettes = "smoke",
}
for name, profile in pairs(items) do LightRpItems[name].consumeAction = profile end
