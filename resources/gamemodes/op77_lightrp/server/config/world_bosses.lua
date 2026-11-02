-- World bosses (server/modules/world_bosses.lua): authored missions tagged "World boss"
-- in the mission editor appear at random in the city. No board, no tag, no instance:
-- the boss and its guards spawn in the open (bucket 0) and anybody can fight. Entering
-- the zone (the mission's perimeter, plus `zoneMargin`) shows the common objective and
-- your share; the reward pool is split by contribution (damage dealt to the boss and its
-- guards, plus a few points per kill), and under the mission's minimum share you get
-- nothing: arriving for the last shot or standing around does not pay.
LightRpWorldBosses = {
    enabled = true,

    schedule = {
        -- the first one this long after the server start, then a random wait between
        -- `minMinutes` and `maxMinutes` after the previous one ended
        firstDelayMinutes = 20,
        minMinutes = 45,
        maxMinutes = 90,
        -- not with fewer players online than this
        minPlayers = 3,
    },

    -- How far past the perimeter a player still counts as in the zone (HUD, targets).
    zoneMargin = 40.0,
    -- Contribution: every point of damage counts 1, every kill adds `killPoints` (a kill
    -- of the boss adds `bossKillPoints`: the last shot is worth little on purpose).
    killPoints = 150,
    bossKillPoints = 150,
    -- Reputation for every rewarded fighter.
    reputation = 150,
    -- The guards still standing when the boss falls leave after this.
    cleanupSeconds = 45,
    -- How long the end (BOSS DOWN / GOT AWAY, your pay) stays on the zone's HUD.
    resultSeconds = 10,
    -- Enemies past the zone (perimeter + zoneMargin + this) are sent back to their post.
    leashMetres = 15,
    -- The boss's spawn: if no boss stands after this, the event is called off.
    spawnTimeoutSeconds = 45,
    -- Reinforcements (the mission's non-start spawn points) at these fractions of the
    -- boss's health.
    reinforcements = { 0.66, 0.33 },

    -- Map blip of the event (op77_map3d), and the city-wide announcement.
    blip = { color = "#FF3B48", pulse = true, edge = true, label = "WORLD BOSS: {title}" },
    announce = { title = "WORLD BOSS", body = "{boss} spotted in {location}. Every fighter in the zone gets a share of {reward}." },
}
