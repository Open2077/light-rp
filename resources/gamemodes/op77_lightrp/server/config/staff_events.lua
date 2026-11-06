-- Staff events (server/modules/staff_events.lua, /admin > Events, /lightrp.event): the staff
-- launch world bosses, cyberpsychos and gang attacks where they want, and event nights that
-- chain them. Every event runs on the world boss engine (server/modules/world_bosses.lua):
-- the open world (bucket 0), the zone HUD, shares by contribution, the leash, the map pin and
-- the end notices. With pay on, an event pays and counts exactly like a world boss (the pool
-- of server/config/economy.lua worldBosses and the daily cap of world_bosses.lua dailyPaid,
-- shared with them); with pay off it is for fun: no money, no reputation, nothing counts for
-- dailies, titles or iconic drops. Paying needs command.worldboss.start
-- (server/config/support.lua eventsPay), the rest command.lightrp.events.
LightRpStaffEvents = {
    enabled = true,

    -- An event made "here", on a player or at a spot is a circle of this radius (metres)
    -- around the point: the zone that shows the HUD, and the leash of the enemies.
    radius = { default = 50, min = 25, max = 150 },
    -- The time limit a staff can pick (minutes); then the boss gets away.
    minutes = { default = 15, min = 5, max = 60 },

    -- Levels multiply the enemies' health, damage and numbers on top of the event's own
    -- (a world boss of the catalogue: its first difficulty; the boss itself stays one).
    levels = {
        { id = "normal", label = "Normal", blurb = "As designed.", health = 1, damage = 1, count = 1 },
        { id = "hard", label = "Hard", blurb = "Tougher, harder hitting, more of them.", health = 1.6, damage = 1.25, count = 1.5 },
        { id = "brutal", label = "Brutal", blurb = "For a full crew in its best kit.", health = 2.5, damage = 1.6, count = 2 },
    },

    -- A cyberpsycho on the loose: one psycho (the game's Psycho Squad records,
    -- shared/mission_defs.lua psycho = true), health x `health` (x the level), hunting
    -- whoever enters its zone. `names`: the handle the HUD shows when the staff gives none.
    psycho = {
        title = "Cyberpsycho sighting", health = 12, reward = 12000, minShare = 5, alertRange = 45,
        names = { "Static", "Red Line", "Overclock", "Glitch", "Chrome Saint", "Hollow", "Burnout",
            "Ghost Wire", "Razorback", "Zero Day", "Mantis", "Feedback", "Hotwire", "Killswitch" },
        words = { tag = "CYBERPSYCHO", zone = "CYBERPSYCHO ZONE", down = "CYBERPSYCHO DOWN", away = "CYBERPSYCHO ESCAPED" },
        look = { icon = "skull", color = "#FF2E3C", label = "CYBERPSYCHO: {boss}" },
        announce = { title = "CYBERPSYCHO SIGHTING",
            body = "A cyberpsycho, {boss}, is loose in {location}. NCPD is overwhelmed: every fighter in the zone gets a share of up to {reward}.",
            bodyNoPay = "A cyberpsycho, {boss}, is loose in {location}. NCPD is overwhelmed: take it down. A staff event: no pay, just the glory." },
    },

    -- A gang attack: a warlord (health x `health`) and its squad on the point, and two
    -- waves of reinforcements from the edge of the zone (`waveRing` x the radius) at 66 %
    -- and 33 % of the warlord's health (world_bosses.lua reinforcements). Counts are at
    -- the Normal level; the level multiplies them (12 at most per group).
    gang = {
        health = 15, reward = 20000, minShare = 5, guardRing = 8, waveRing = 0.8, alertRange = 35,
        words = { tag = "GANG ATTACK", zone = "GANG ATTACK ZONE", down = "WARLORD DOWN", away = "THE GANG HELD ITS GROUND" },
        look = { icon = "swords", color = "#FFB000", label = "GANG ATTACK: {boss}" },
        announce = { title = "GANG ATTACK",
            body = "{boss} and their crew are taking over {location}. Every fighter in the zone gets a share of up to {reward}.",
            bodyNoPay = "{boss} and their crew are taking over {location}. Push them out. A staff event: no pay, just the glory." },
        crews = {
            { id = "sixthstreet", label = "6th Street", warlord = "sixthstreet_shotgun", title = "6th Street warlord",
                squad = { { "sixthstreet", 3 }, { "sixthstreet_sniper", 1 } }, waves = { { "sixthstreet", 4 }, { "sixthstreet_shotgun", 3 } } },
            { id = "valentinos", label = "Valentinos", warlord = "valentinos", title = "Valentinos jefe",
                squad = { { "valentinos", 4 } }, waves = { { "valentinos", 4 }, { "valentinos", 3 } } },
            { id = "tygerclaws", label = "Tyger Claws", warlord = "tygerclaws", title = "Tyger Claws oyabun",
                squad = { { "tygerclaws", 4 } }, waves = { { "tygerclaws", 4 }, { "tygerclaws", 3 } } },
            { id = "maelstrom", label = "Maelstrom", warlord = "maelstrom", title = "Maelstrom chromehead",
                squad = { { "maelstrom", 4 } }, waves = { { "maelstrom", 4 }, { "maelstrom", 3 } } },
            { id = "voodooboys", label = "Voodoo Boys", warlord = "voodooboys_sidewinder", title = "Voodoo Boys enforcer",
                squad = { { "voodooboys", 3 } }, waves = { { "voodooboys", 4 }, { "voodooboys_sidewinder", 2 } } },
            { id = "wraiths", label = "Wraiths", warlord = "wraiths_gunner", title = "Wraiths raid boss",
                squad = { { "wraiths", 3 } }, waves = { { "wraiths", 4 }, { "wraiths_gunner", 3 } } },
            { id = "militech", label = "Militech", warlord = "militech_shotgun", title = "Militech commander",
                squad = { { "militech", 3 } }, waves = { { "militech", 4 }, { "militech_shotgun", 2 } } },
        },
    },

    -- Event nights: presets that chain events, announced to the whole city. `breakSeconds`
    -- between two rounds, `introSeconds` from the announcement to the first round.
    nights = {
        introSeconds = 30, breakSeconds = 60, maxRounds = 8,
        presets = {
            { id = "psycho_night", label = "Psycho Night", rounds = 5, min = 2,
                blurb = "Cyberpsychos one after another, each in another spot, harder every round. With two spots or more, the last round lets two loose at once." },
            { id = "boss_rush", label = "Boss Rush", rounds = 4, min = 1,
                blurb = "The world bosses of the catalogue back to back, each at its own place." },
            -- Gang War: one round, `rounds` gangs at once (one saved spot each, at most maxLive).
            { id = "gang_war", label = "Gang War", rounds = 3, min = 2,
                blurb = "Several gangs hit several saved spots at the same time: the city picks its fights." },
            { id = "siege", label = "Siege", rounds = 3, min = 2,
                blurb = "Gang after gang hits the same place, each harder; a cyberpsycho leads the last one." },
        },
        announce = { title = "EVENT NIGHT", start = "{name} starts in {seconds} s. {blurb}",
            next = "{name}: round {round} of {rounds} in {seconds} s.", over = "{name} is over: {won} of {played} fight(s) won." },
    },

    -- Saved spots: named points the staff prepare (noclip there, save) and launch at later.
    spots = { max = 80 },
}
