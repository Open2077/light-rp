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
    -- Contribution: every point of damage counts 1; a kill adds killShare of the
    -- target's max health, in full only when the killer dealt at least killAssist of it
    -- (less in proportion): a last shot on someone else's work is worth next to nothing.
    killShare = 0.25,
    killAssist = 0.10,
    -- Reputation for every rewarded fighter.
    reputation = 150,
    -- Pay per character and UTC day (owner decision 2026-11-04, docs/economy-balance.md
    -- §16): once a character has been paid for this many world bosses since 00:00 UTC,
    -- their share and the reputation above stop until the next day. The fight stays open
    -- to them (they score, help, see the HUD) and they are told so; they no longer count
    -- among the paid fighters (the pool follows the others). Their share still qualifies
    -- for what is not pay (daily contracts, titles, iconic rolls). 0 turns the cap off.
    dailyPaid = 2,
    -- The guards still standing when the boss falls leave after this.
    cleanupSeconds = 45,
    -- How long the end (BOSS DOWN / GOT AWAY, your pay) stays on the zone's HUD.
    resultSeconds = 10,
    -- With many fighters the minimum share drops to this fraction of an equal share
    -- (30 fighters: 0.25 * 100 / 30 = 0.8 %), never above the mission's minimum.
    fairShareFraction = 0.25,
    -- The leash. An enemy this far past the PERIMETER (the zoneMargin does not count)
    -- stops fighting (combat and perception off: it neither shoots nor chases) and runs
    -- back to its post; it fights again once back inside the perimeter. One still out after
    -- `leashTeleportSeconds` (stuck, or dragged by the physics) is put back on its post.
    -- Nobody can pull the event across the city, and running away works.
    leashMetres = 20,
    leashTeleportSeconds = 30,
    -- The boss's spawn: if no boss stands after this, the event is called off.
    spawnTimeoutSeconds = 45,
    -- Reinforcements (the mission's non-start spawn points) at these fractions of the
    -- boss's health.
    reinforcements = { 0.66, 0.33 },

    -- Map blip of the event (op77_map3d), and the city-wide announcement.
    blip = { color = "#FF3B48", pulse = true, edge = true, label = "WORLD BOSS: {title}" },
    -- {reward}: the most the pool can reach with every player online fighting
    -- (server/config/economy.lua worldBosses); the pool follows the fighters paid.
    announce = { title = "WORLD BOSS", body = "{boss} spotted in {location}. Every fighter in the zone gets a share of up to {reward}." },
}
