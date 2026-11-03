-- Prestige titles (server/modules/titles.lua). Server only. One title is shown
-- next to the character's name: RP chat, crew frame, Hall of Fame, and whatever
-- else reads LightRP.titles.shown(playerId). Rules: docs/dailies-titles.md §6.
--
-- A title: id (stable: stored), label (what others see), rarity, group (the
-- page's sections), how (how to earn it, shown while locked) and ONE source:
--   tier = n                      reputation tier n or above (missions.lua)
--   clear = { point, difficulty }  that mission cleared at least once
--   counter = name, count = n      a counter of paid activity results reaches n
--   board = key                    rank 1 of that Hall of Fame board, held live
--   feat = name                    awarded by a hook (raid report, world boss, contracts)
--   grantOnly = true               only through LightRP.titles.grant (Dogtown, staff)
-- `requires`: an activity id, a mission point, "worldboss" or "dogtown"; while it
-- is missing the title is hidden, unless already earned.
LightRpTitles = {
    enabled = true,

    rarities = {
        common = { label = "Common", color = "#C9D1DC" },
        rare = { label = "Rare", color = "#3FA9FF" },
        epic = { label = "Epic", color = "#B36BFF" },
        legendary = { label = "Legendary", color = "#FFCC00" },
        live = { label = "Live", color = "#FF3FB4" },
    },
    groups = {
        { id = "reputation", label = "Reputation" },
        { id = "raids", label = "Raids" },
        { id = "feats", label = "Feats" },
        { id = "pvp", label = "PvP" },
        { id = "contracts", label = "Contracts" },
        { id = "hall", label = "Hall of Fame" },
        { id = "dogtown", label = "Dogtown" },
    },

    catalogue = {
        { id = "merc", label = "Merc", rarity = "common", group = "reputation", how = "Reach reputation tier II.", tier = 2 },
        { id = "operator", label = "Operator", rarity = "rare", group = "reputation", how = "Reach reputation tier III.", tier = 3 },
        { id = "edgerunner", label = "Edgerunner", rarity = "epic", group = "reputation", how = "Reach reputation tier IV.", tier = 4 },
        { id = "legend", label = "Legend", rarity = "legendary", group = "reputation", how = "Reach reputation tier V.", tier = 5 },

        { id = "chimera_standard", label = "Chimera Breaker", rarity = "common", group = "raids", requires = "chimera_raid",
          how = "Clear the Chimera raid on Standard.", clear = { point = "chimera_raid", difficulty = "standard" } },
        { id = "chimera_hard", label = "Core Cracker", rarity = "rare", group = "raids", requires = "chimera_raid",
          how = "Clear the Chimera raid on Hard.", clear = { point = "chimera_raid", difficulty = "hard" } },
        { id = "chimera_critical", label = "Chimera Critical", rarity = "epic", group = "raids", requires = "chimera_raid",
          how = "Clear the Chimera raid on Critical.", clear = { point = "chimera_raid", difficulty = "critical" } },
        { id = "blackout", label = "Blackout", rarity = "epic", group = "raids", requires = "sector04_blackout",
          how = "Clear Sector 04 Blackout on Critical.", clear = { point = "sector04_blackout", difficulty = "critical" } },

        { id = "overclock_denied", label = "Overclock Denied", rarity = "rare", group = "feats", requires = "chimera_raid",
          how = "Kill the Chimera on Hard or Critical before its core overclocks.", feat = "overclock_denied" },
        { id = "two_man_army", label = "Two-Man Army", rarity = "epic", group = "feats", requires = "chimera_raid",
          how = "Kill the Chimera on Hard or Critical with exactly two operators.", feat = "two_man_army" },
        { id = "flawless", label = "Flawless", rarity = "legendary", group = "feats", requires = "chimera_raid",
          how = "Kill the Chimera on Critical without a single operator going down in the fight.", feat = "flawless" },
        { id = "boss_killer", label = "Boss Killer", rarity = "rare", group = "feats", requires = "worldboss",
          how = "Land the killing blow on a world boss.", feat = "boss_killer" },
        { id = "lions_share", label = "Lion's Share", rarity = "epic", group = "feats", requires = "worldboss",
          how = "Be the top contributor of a world boss that goes down.", feat = "lions_share" },

        { id = "duelist", label = "Duelist", rarity = "rare", group = "pvp", requires = "arena.duel",
          how = "Win 10 paid ranked duels.", counter = "duel_wins", count = 10 },
        { id = "sudden_death", label = "Sudden Death", rarity = "epic", group = "pvp", requires = "arena.duel",
          how = "Win 5 paid ranked duels in their deciding round.", counter = "duel_deciders", count = 5 },
        { id = "street_racer", label = "Street Racer", rarity = "rare", group = "pvp", requires = "race.grid",
          how = "Win 10 paid grid races against at least 2 other real drivers.", counter = "grid_wins", count = 10 },
        { id = "getaway_driver", label = "Getaway Driver", rarity = "rare", group = "pvp", requires = "chase.wanted",
          how = "Make 10 extractions in paid Most Wanted matches.", counter = "wanted_extractions", count = 10 },
        { id = "long_arm", label = "Long Arm of the Law", rarity = "rare", group = "pvp", requires = "chase.wanted",
          how = "Make 10 arrests in paid Most Wanted matches.", counter = "wanted_arrests", count = 10 },
        { id = "ghost", label = "Ghost", rarity = "epic", group = "pvp", requires = "chase.pve",
          how = "Shake the NCPD off 10 times in NCPD Escape.", counter = "pve_shakes", count = 10 },

        { id = "streak_7", label = "Seven Days Straight", rarity = "rare", group = "contracts",
          how = "Claim a contract 7 UTC days in a row.", feat = "streak_7" },
        { id = "streak_30", label = "Clockwork", rarity = "epic", group = "contracts",
          how = "Claim a contract 30 UTC days in a row.", feat = "streak_30" },
        { id = "okoro_favourite", label = "Okoro's Favourite", rarity = "rare", group = "contracts",
          how = "Claim 30 contracts.", feat = "okoro_favourite" },
        { id = "lucky_seven", label = "Lucky Seven", rarity = "rare", group = "contracts",
          how = "Complete Ledger's Lucky Number 3 times.", feat = "lucky_seven" },
        { id = "crowd_pleaser", label = "Crowd Pleaser", rarity = "rare", group = "contracts",
          how = "Complete Street Performer 3 times.", feat = "crowd_pleaser" },
        { id = "fumes_connoisseur", label = "Fumes Connoisseur", rarity = "rare", group = "contracts",
          how = "Complete Running on Fumes 3 times.", feat = "fumes_connoisseur" },

        { id = "top_gun", label = "Top Gun", rarity = "live", group = "hall", how = "Hold rank 1 of the PvP kills board.", board = "pvp.kills" },
        { id = "champion", label = "Champion", rarity = "live", group = "hall", how = "Hold rank 1 of the PvP wins board.", board = "pvp.wins" },
        { id = "track_record", label = "Track Record", rarity = "live", group = "hall", how = "Hold rank 1 of the time trial board.", board = "races.race.trial" },
        { id = "raid_lead", label = "Raid Lead", rarity = "live", group = "hall", how = "Hold rank 1 of the raids board.", board = "missions.raids" },
        { id = "eddie_baron", label = "Eddie Baron", rarity = "live", group = "hall", how = "Hold rank 1 of the richest board.", board = "wealth.richest" },

        { id = "dogtown_king", label = "King of Dogtown", rarity = "legendary", group = "dogtown", requires = "dogtown",
          how = "Awarded by Dogtown each week; it lasts until the end of the following week.", grantOnly = true },
    },
}
