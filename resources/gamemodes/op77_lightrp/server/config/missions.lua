-- Missions (The Division style): mission points in the city, a board per
-- difficulty where players tag in alone or with their squad, matchmaking that
-- fills the lobby, a countdown once it is full (or when the host launches with
-- the minimum), then the mission runs in its own routing bucket.
--
-- The positions here are TEST points near the Little China public garage; the
-- real points come from the server team.
LightRpMissions = {
    enabled = true,
    -- Reputation: points earned by finishing missions, and the tier each
    -- threshold opens (tier 1 from the start).
    reputation = { tiers = { 0, 500, 1500 } },
    -- Tagging happens at the point; a squad member must be this close to it
    -- for the leader to tag them along. Wandering past `leash` untags you.
    tagRadius = 6.0,
    groupRadius = 30.0,
    leash = 60.0,
    -- Seconds between full (or the host's launch) and the start, and how
    -- often a player may tag / untag (per player).
    countdown = 15,
    hostCountdown = 10,
    tagCooldownMs = 1500,
    -- One routing bucket per running mission: base + instance number.
    bucketBase = 3000000,
    -- What a finished mission pays out in reputation, per difficulty.
    reputationGain = { standard = 100, hard = 220, critical = 450 },
    -- Squads (parties).
    -- `nearby`: the players listed to invite at a mission point; `inviteRange`:
    -- how far an invite by command reaches.
    party = { maxSize = 8, inviteSeconds = 60, nearby = 15.0, inviteRange = 300.0 },
    -- Ground marker of a mission point.
    marker = { shape = "cylinder", radius = 1.2, height = 0.7,
        color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 60, groundOffset = 0.05 },
    points = {
        {
            id = "sector04_blackout",
            title = "Sector 04 Blackout",
            type = "HEIST",
            location = "SECTOR 04 // SUBSTATION C",
            description = "Cut district power and hit the depository inside the dark window. Pick the tier, then tag in on its board.",
            position = { x = -637.6, y = -386.2, z = 8.19 },
            -- where the operators arrive in the instance (one spot each, in turn)
            start = {
                { x = -637.6, y = -386.2, z = 8.19, heading = 143.6 },
                { x = -636.4, y = -386.9, z = 8.19, heading = 143.6 },
                { x = -638.8, y = -385.5, z = 8.19, heading = 143.6 },
                { x = -635.2, y = -387.6, z = 8.19, heading = 143.6 },
            },
            difficulties = {
                { id = "standard", label = "STANDARD", blurb = "Reduced security. Grid stays half-lit.",
                  payout = 12000, minutes = 25, min = 2, max = 4, tier = 1 },
                { id = "hard", label = "HARD", blurb = "Full security roster. Shorter dark window.",
                  payout = 22500, minutes = 30, min = 4, max = 6, tier = 2 },
                { id = "critical", label = "CRITICAL", blurb = "Corporate response team on standby. No respawns.",
                  payout = 40000, minutes = 45, min = 6, max = 8, tier = 3 },
            },
        },
    },
}
