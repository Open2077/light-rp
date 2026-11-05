-- Capture the Flag: two teams, bring the enemy flag home while yours is there. Walk over the enemy
-- flag to take it, over your dropped flag to send it home, into your base with the enemy flag,
-- yours at home, to score. Three captures win. A dropped flag goes home by itself after 20 s, at
-- once when it falls out of the play area or on its own stand. A tie at the bell plays 90 s of
-- overtime: the next capture wins. A spawn shields for 2 s; a hit dealt or a grab ends it.
--
-- Everything reads bodies on the server: no client says anything here. The source's flag and pole
-- models are empty in the live settings and its placements were never checked, so a flag is a
-- marker (client/objectives.lua). No model, no fireworks.
local Config = GamesConfig
local E = GamesEngine

local CTF = {
    captureLimit = 3,
    seconds = 600,
    respawnMs = 5000,
    flagRadius = 2.5,    -- m, horizontal: reach to take or return a flag
    flagReach = 3,       -- m, vertical tolerance of that reach
    captureRadius = 4,   -- m, around your own base, to score
    returnSeconds = 20,  -- a dropped flag goes home by itself
    overtime = 90,       -- s of sudden death on a tie
    overtimeMarginMs = 1000, -- decided this long before the bell: the engine closes on it
    spawnShield = 2,     -- s of protection after a spawn
    boundsMargin = 15,   -- m, the play area always covers both bases by this much
}

GamesCtf = { rules = CTF }
local G = GamesCtf

local LABELS = { "Red", "Blue" }
local COLORS = { "danger", "info" }
local RINGS = { { r = 255, g = 70, b = 70, a = 200 }, { r = 70, g = 170, b = 255, a = 200 } }

local function baseOf(map, side) return side == 1 and map.redBase or map.blueBase end

-- ---------------------------------------------------------------- rules --

function G.within(at, pos, radius)
    return E.flat(at, pos) <= radius and math.abs(at.z - pos.z) <= CTF.flagReach
end

function G.home(map, side)
    local base = baseOf(map, side)
    return { state = "base", pos = { x = base.x, y = base.y, z = base.z } }
end

function G.area(map)
    local reach = 0
    for side = 1, 2 do reach = math.max(reach, E.distance(baseOf(map, side), map.centre)) end
    return math.max(map.radius, reach + CTF.boundsMargin)
end

function G.inBounds(map, at) return E.distance(at, map.centre) <= map.radius end

-- Where a flag let go at `at` ends: "home" when it must go back at once (out of the play area, or
-- on its own stand), else "dropped".
function G.landing(map, side, at)
    if not G.inBounds(map, at) or G.within(at, baseOf(map, side), CTF.captureRadius) then return "home" end
    return "dropped"
end

function G.expired(flag, t)
    return flag.state == "dropped" and t - flag.droppedAt >= CTF.returnSeconds * 1000
end

-- A team's own spawn list: only the spots nearer its base than the enemy's. The live data lists
-- spots on the wrong base (School: a blue one 1.2 m from the red flag). Empty: the base.
function G.teamSpots(map, side)
    local list = map[side == 1 and "redSpawns" or "blueSpawns"]
    local own, enemy = baseOf(map, side), baseOf(map, 3 - side)
    local spots = {}
    for _, spot in ipairs(type(list) == "table" and list or {}) do
        if E.flat(spot, own) < E.flat(spot, enemy) then spots[#spots + 1] = spot end
    end
    return spots
end

for _, map in ipairs(GamesMaps.ctf) do map.radius = G.area(map) end

-- ---------------------------------------------------------------- moves --

local function goHome(match, side, text)
    match.ctf.flags[side] = G.home(match.map, side)
    E.feed(match, text, COLORS[side])
end

-- The flag this player carries falls where `at` says: a death reads the body, a departure has
-- only the last reading (flag.pos follows the carrier every tick).
local function dropFlag(match, id, at)
    for side = 1, 2 do
        local flag = match.ctf.flags[side]
        if flag.state == "carried" and flag.carrier == id then
            local where = at or flag.pos
            if G.landing(match.map, side, where) == "home" then
                goHome(match, side, ("%s flag returned"):format(LABELS[side]))
            else
                match.ctf.flags[side] = { state = "dropped", pos = { x = where.x, y = where.y, z = where.z }, droppedAt = E.now() }
                E.feed(match, ("%s flag dropped"):format(LABELS[side]), COLORS[side])
            end
            return true
        end
    end
    return false
end

local function take(match, p, side, at)
    match.ctf.flags[side] = { state = "carried", carrier = p.id, pos = { x = at.x, y = at.y, z = at.z } }
    p.ctf.shieldUntil = nil
    E.feed(match, ("%s took the %s flag"):format(p.name, LABELS[side]:lower()), COLORS[side])
    E.banner(match, "FLAG TAKEN", ("%s has the %s flag."):format(p.name, LABELS[side]:lower()), COLORS[side], 2000)
    E.cue(match, "hit")
end

local function rescue(match, p)
    p.ctf.returns = p.ctf.returns + 1
    goHome(match, p.side, ("%s returned the %s flag"):format(p.name, LABELS[p.side]:lower()))
end

local function capture(match, p)
    local ctf, enemy = match.ctf, 3 - p.side
    ctf.flags[enemy] = G.home(match.map, enemy)
    ctf.score[p.side] = ctf.score[p.side] + 1
    p.ctf.captures = p.ctf.captures + 1
    E.feed(match, ("%s captured the %s flag!"):format(p.name, LABELS[enemy]:lower()), COLORS[p.side])
    E.banner(match, "CAPTURED", ("%s %d - %d %s"):format(LABELS[1], ctf.score[1], ctf.score[2], LABELS[2]), COLORS[p.side], 2500)
    E.cue(match, "green")
    if ctf.score[p.side] >= CTF.captureLimit or ctf.overtime then E.finish(match, "captures") end
end

-- A dying body (its death not in yet) acts on nothing. Unknown: it does not act.
local function standing(id)
    local ok, life = pcall(Open77.players.getLifeState, id)
    return ok and type(life) == "table" and tostring(life.phase or ""):gsub("_", "") == "alive"
end

local function judge(match, p, at)
    local flags, map = match.ctf.flags, match.map
    local own, enemy = flags[p.side], flags[3 - p.side]
    if enemy.state == "carried" and enemy.carrier == p.id then enemy.pos = { x = at.x, y = at.y, z = at.z } end
    local atBase = G.within(at, baseOf(map, p.side), CTF.captureRadius)
    local rescuing = own.state == "dropped" and G.within(at, own.pos, CTF.flagRadius)
    local taking = enemy.state ~= "carried" and G.within(at, enemy.pos, CTF.flagRadius)
    local scoring = enemy.state == "carried" and enemy.carrier == p.id and atBase
    if not (rescuing or taking or scoring) or not standing(p.id) then return end
    if rescuing then rescue(match, p) end
    if taking then take(match, p, 3 - p.side, at) end
    -- Scoring needs our own flag home (it may just have come back).
    if (scoring or taking) and atBase and flags[p.side].state == "base" then capture(match, p) end
end

local function step(match, t)
    local ctf = match.ctf
    for side = 1, 2 do
        if G.expired(ctf.flags[side], t) then goHome(match, side, ("%s flag returned home"):format(LABELS[side])) end
    end
    for _, p in ipairs(E.members(match)) do
        if p.alive and t >= p.holdUntil then
            local at = E.read(p.id)
            if at then judge(match, p, at) end
            if match.phase ~= "running" then return end
        end
    end
    if not ctf.overtime and match.endsAt - t < CTF.overtimeMarginMs and ctf.score[1] == ctf.score[2] then
        ctf.overtime = true
        match.endsAt = match.endsAt + CTF.overtime * 1000
        E.feed(match, "Overtime: the next capture wins", "danger")
        E.banner(match, "OVERTIME", "The next capture wins.", "danger", 2500)
    end
end

-- ---------------------------------------------------------------- what players see --

local function objective(match, p)
    local flags = match.ctf.flags
    local own, enemy = flags[p.side], flags[3 - p.side]
    if enemy.state == "carried" and enemy.carrier == p.id then
        return own.state == "base" and "Bring the flag to your base" or "Your flag must be home"
    end
    if own.state == "dropped" then return "Return your flag" end
    if own.state == "carried" then return "Stop their carrier" end
    if enemy.state == "carried" then return "Cover your carrier" end
    return "Bring the enemy flag home"
end

-- A carried flag rides over its carrier, rounded to the metre: one send per metre walked.
local function shownAt(flag)
    if flag.state == "carried" then
        return { x = math.floor(flag.pos.x + 0.5), y = math.floor(flag.pos.y + 0.5), z = math.floor(flag.pos.z + 0.5) + 2.2 }
    end
    return { x = flag.pos.x, y = flag.pos.y, z = flag.pos.z + 0.6 }
end

local function world(match)
    local out = { markers = {}, blips = {} }
    for side = 1, 2 do
        local base, flag = baseOf(match.map, side), match.ctf.flags[side]
        local at = shownAt(flag)
        out.markers["base" .. side] = { position = { x = base.x, y = base.y, z = base.z - 0.9 }, shape = "ring",
            radius = CTF.captureRadius, height = 1, color = RINGS[side] }
        out.markers["flag" .. side] = { position = at, shape = "diamond", radius = 0.35, height = 0.8, color = RINGS[side] }
        out.blips["flag" .. side] = { position = at, title = LABELS[side] .. " flag" }
    end
    return out
end

local function statusOf(flag)
    if flag.state == "base" then return "Home" end
    if flag.state == "carried" then return "Taken" end
    return "Dropped"
end

E.mode({
    id = "games.ctf", key = "ctf", label = "Capture the Flag", kind = "pvp",
    description = "Two teams, two flags. Bring the enemy flag home while yours is there. Three captures win.",
    minPlayers = 2, maxPlayers = 16,
    maps = GamesMaps.ctf,
    pvp = true, teams = 2,
    seconds = CTF.seconds, respawnMs = CTF.respawnMs,
    weapons = {
        { record = "Items.Preset_Ajax_Default", slot = 1, reserve = 240 },
        { record = "Items.Preset_Lexington_Default", slot = 2, reserve = 180 },
    },

    setup = function(match)
        match.ctf = { score = { 0, 0 }, flags = { G.home(match.map, 1), G.home(match.map, 2) },
            spots = { G.teamSpots(match.map, 1), G.teamSpots(match.map, 2) } }
        for _, p in pairs(match.players) do p.ctf = { captures = 0, returns = 0 } end
    end,

    -- Every spawn opens the shield, counted from the end of the landing. The team's own spot
    -- farthest from living enemies, else its base.
    spawnFor = function(match, p)
        p.ctf.shieldUntil = E.now() + Config.match.settleMs + CTF.spawnShield * 1000
        local spots = match.ctf.spots[p.side]
        if #spots == 0 then return baseOf(match.map, p.side), 3.0 end
        local enemies = {}
        for _, other in pairs(match.players) do
            local at = other.alive and other.side ~= p.side and E.read(other.id) or nil
            if at then enemies[#enemies + 1] = at end
        end
        local best, bestGap
        for _, spot in ipairs(spots) do
            local gap = math.huge
            for _, at in ipairs(enemies) do gap = math.min(gap, E.distance(at, spot)) end
            if best == nil or gap > bestGap then best, bestGap = spot, gap end
        end
        return best, 1.5
    end,

    tick = step,

    damage = function(_, _, attacker, victim)
        if (victim.ctf.shieldUntil or 0) > E.now() then return false end
        attacker.ctf.shieldUntil = nil -- a protected player who fights gives it up
    end,

    killed = function(match, victim)
        local read = E.read(victim.id)
        dropFlag(match, victim.id, read)
    end,

    left = function(match, p)
        if match.phase == "running" then dropFlag(match, p.id, nil) end
    end,

    hud = function(match, p, view)
        local ctf = match.ctf
        view.teams = {
            { name = LABELS[1], color = COLORS[1], score = ctf.score[1], self = p.side == 1 },
            { name = LABELS[2], color = COLORS[2], score = ctf.score[2], self = p.side == 2 },
        }
        view.objective = objective(match, p)
        view.stats = {
            { label = "Your flag", value = statusOf(ctf.flags[p.side]) },
            { label = "Their flag", value = statusOf(ctf.flags[3 - p.side]) },
            { label = "Captures", value = tostring(p.ctf.captures) },
            { label = "Kills", value = tostring(p.kills) },
        }
        if ctf.overtime and view.timer then view.timer.label = "OVERTIME" end
        view.world = world(match)
    end,

    results = function(match, reason)
        local ctf = match.ctf
        local winner
        if reason == "forfeit" then
            for _, p in pairs(match.players) do winner = p.side end
        elseif ctf.score[1] ~= ctf.score[2] then
            winner = ctf.score[1] > ctf.score[2] and 1 or 2
        end
        local ranking = {}
        for _, p in pairs(match.roster) do
            p.won = winner ~= nil and p.side == winner
            p.score = p.ctf.captures
            p.placement = winner and (p.won and 1 or 2) or nil
            p.row = { outcome = winner and (p.won and "won" or "lost") or nil, captures = p.ctf.captures, points = p.ctf.returns }
            ranking[#ranking + 1] = p
        end
        -- Who carried it: captures, returns, then kills.
        table.sort(ranking, function(a, b)
            if (a.won == true) ~= (b.won == true) then return a.won == true end
            if a.ctf.captures ~= b.ctf.captures then return a.ctf.captures > b.ctf.captures end
            if a.ctf.returns ~= b.ctf.returns then return a.ctf.returns > b.ctf.returns end
            if a.kills ~= b.kills then return a.kills > b.kills end
            return a.id < b.id
        end)
        return {
            ranking = ranking, winnerSide = winner,
            sides = { { id = 1, label = LABELS[1], score = ctf.score[1] }, { id = 2, label = LABELS[2], score = ctf.score[2] } },
            lines = {
                { label = "Winner", value = winner and LABELS[winner] or "Draw" },
                { label = "Captures to win", value = tostring(CTF.captureLimit) },
            },
            columns = { "captures", "points", "kills", "deaths" },
        }
    end,
})
