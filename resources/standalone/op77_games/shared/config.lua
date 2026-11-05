-- op77_games settings. Shared: every client downloads this, nothing secret here.
-- A game's own rules live in its file under server/modes/.
GamesConfig = {
    core = "op77_lightrp",

    -- Our routing buckets. City 0, arena 41xxxxx, race 42xxxxx, chase 43xxxxx, turf 44xxxxx.
    buckets = { first = 4500000, last = 4599999 },

    -- Every cap off: Light RP puts RP weapons aside, freezes needs, refuses RP items
    -- and vehicles while a player is ours.
    caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },

    -- The temporary kit of each game (hunters only in prop hunt), a mission's kit handed by
    -- Light RP: the id of one of its kits (LightRpRaid.loadouts in its server/config/missions.lua:
    -- assault, breacher, marksman, gunner, tech), or false for the kit missions preselect, the
    -- first of that list. Gun game hands its own ladder, red light and the props nothing.
    kits = { tdm = false, control = false, ctf = false, prophunt = false },

    -- Owner decision: only the hosting menu's friendly path and the panel reach these
    -- games, none of them is ranked. Results carry `unranked`, so the core records and
    -- pays nothing and the recap still shows.
    unranked = true,

    tickMs = 100,
    hudMs = 250,     -- HUD sends, at most this often per match, on change only
    statusMs = 2000, -- the activity status, at most this often unless something changed

    lobby = {
        windowSeconds = 15,    -- the join window once the minimum is waiting
        fullWindowSeconds = 3, -- what is left of it when the lobby fills
        gatherSeconds = 8,     -- a Light RP match: the wait for its last member
        launchedKeepMs = 60000, -- a late join for a match that started is refused this long
    },

    match = {
        placeTimeoutMs = 25000, -- a body that has not landed by then is sent back
        placeRetryMs = 1000,
        countdownMs = 5000,     -- frozen on the spawn, weapons drawn, before GO
        endMs = 6000,           -- the result card, in the bucket, before the way back
        lastHitMs = 5000,       -- a death with no killer goes to whoever hurt the victim this recently
        respawnRetryMs = 500,
        respawnTries = 5,
        settleMs = 500,         -- after a move, how long rules leave that body alone
    },

    bounds = {
        graceSeconds = 5,
        sampleMs = 200,
        samples = 4,   -- consecutive readable samples outside, on top of the grace
    },

    scopes = {
        perResource = 8, -- the platform's limit (MaximumCombatScopesPerOwner)
        maxPlayers = 32, -- the platform's limit (MaximumCombatScopePlayers)
        syncMs = 500,
        retryMs = 2000,
        tellAfterMs = 5000,  -- a refusal this old is told to the match
        giveUpMs = 15000,    -- a refusal this old cancels the match: no fight nobody can win
        refreshMs = 15000,   -- rebuild anyway, to heal a removal we could not see
    },

    -- The last resort: the city, when Light RP cannot take a player back.
    fallback = { x = -756.581, y = 777.257, z = 22.454, heading = 52.6, bucket = 0 },
    teleportTimeoutMs = 20000,

    strays = {
        sweepMs = 5000,        -- every so often, who is in our buckets without a match
        graceMs = 20000,       -- the core's way back gets this long before we act
        orphanMs = 3000,       -- a member the core no longer calls ours, for this long, is taken out
        coreStoppedMs = 2000,  -- the core teleports its players as it stops: then we check
    },

    -- Light RP's own sounds, copied here because a resource only plays files it ships.
    sounds = {
        red = { file = "audio/red.wav", ms = 1300, volume = 0.8 },     -- raid_wave.wav
        green = { file = "audio/green.wav", ms = 1000, volume = 0.7 }, -- raid_ready.wav
        hit = { file = "audio/hit.wav", ms = 400, volume = 0.6 },      -- raid_tick.wav
    },
}
