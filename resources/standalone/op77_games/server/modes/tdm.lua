-- Team Deathmatch: two teams, respawns, every kill scores one for the killer's team. First
-- team to the limit wins, else the most kills at the bell; a tie is a draw. Each team starts
-- on its own side of the map, later respawns land away from the enemy.
local E = GamesEngine

local TDM = {
    killLimit = 30, -- up to 6 players; +5 for every player past 6, up to maxLimit
    maxLimit = 50,
    seconds = 600,
    respawnMs = 4000,
    protectMs = 2000,
}

GamesTdm = { rules = TDM }

function GamesTdm.limitFor(count)
    return math.min(TDM.maxLimit, TDM.killLimit + 5 * math.max(0, count - 6))
end

-- The map's spawns in two sides: the two farthest apart anchor them, every other one joins
-- the nearer anchor.
function GamesTdm.sides(spawns)
    local a, b, best = spawns[1], spawns[2], -1
    for i = 1, #spawns do
        for j = i + 1, #spawns do
            local gap = E.distance(spawns[i], spawns[j])
            if gap > best then a, b, best = spawns[i], spawns[j], gap end
        end
    end
    local out = { {}, {} }
    for _, spawn in ipairs(spawns) do
        local side = E.distance(spawn, a) <= E.distance(spawn, b) and 1 or 2
        if spawn == b then side = 2 end
        out[side][#out[side] + 1] = spawn
    end
    return out
end

local LABELS = { "Team A", "Team B" }
local COLORS = { "info", "danger" }

local function sideName(side) return LABELS[side] or "Team" end

E.mode({
    id = "games.tdm", key = "tdm", label = "Team Deathmatch", kind = "pvp",
    description = "Two teams, issued weapons, respawns. First team to the kill limit wins.",
    minPlayers = 2, maxPlayers = 16,
    -- Team sides come from how the spawns lie (GamesTdm.sides): at least two.
    schema = {
        points = { { key = "centre", label = "Play area centre", color = "#ffcc00" } },
        lists = { { key = "spawns", label = "Spawn", color = "#3ddc84", min = 2, max = 32 } },
        numbers = { { key = "radius", label = "Play area radius", min = 10, max = 400, default = 70, unit = "m" } },
        area = { centre = "centre", radius = "radius", holds = { "spawns" } },
    },
    pvp = true, teams = 2,
    seconds = TDM.seconds, respawnMs = TDM.respawnMs, protectMs = TDM.protectMs,
    kit = true,

    setup = function(match)
        local count = 0
        for _ in pairs(match.players) do count = count + 1 end
        match.tdm = { limit = GamesTdm.limitFor(count), score = { 0, 0 }, spawns = GamesTdm.sides(match.map.spawns), next = { 0, 0 } }
    end,

    -- The start: each team on its own side, round robin. Later: the engine's choice.
    spawnFor = function(match, p)
        if match.phase == "running" then return nil end
        local tdm = match.tdm
        local list = tdm.spawns[p.side]
        if #list == 0 then return nil end
        tdm.next[p.side] = tdm.next[p.side] + 1
        return list[(tdm.next[p.side] - 1) % #list + 1], 2.0
    end,

    killed = function(match, _, killer)
        if killer == nil then return end
        local tdm = match.tdm
        tdm.score[killer.side] = tdm.score[killer.side] + 1
        if tdm.score[killer.side] >= tdm.limit then E.finish(match, "limit") end
    end,

    hud = function(match, p, view)
        local tdm = match.tdm
        view.teams = {
            { name = LABELS[1], color = COLORS[1], score = tdm.score[1], self = p.side == 1 },
            { name = LABELS[2], color = COLORS[2], score = tdm.score[2], self = p.side == 2 },
        }
        view.objective = ("First team to %d kills"):format(tdm.limit)
        view.stats = { { label = "Kills", value = tostring(p.kills) }, { label = "Deaths", value = tostring(p.deaths) } }
    end,

    results = function(match, reason)
        local tdm = match.tdm
        local winner
        if reason == "forfeit" then
            for _, p in pairs(match.players) do winner = p.side end
        elseif tdm.score[1] ~= tdm.score[2] then
            winner = tdm.score[1] > tdm.score[2] and 1 or 2
        end
        local ranking = {}
        for _, p in pairs(match.roster) do
            p.won = winner ~= nil and p.side == winner
            p.score = p.kills
            p.placement = winner and (p.won and 1 or 2) or nil
            p.row = { outcome = winner and (p.won and "won" or "lost") or nil }
            ranking[#ranking + 1] = p
        end
        table.sort(ranking, function(a, b)
            if (a.won == true) ~= (b.won == true) then return a.won == true end
            if a.kills ~= b.kills then return a.kills > b.kills end
            if a.deaths ~= b.deaths then return a.deaths < b.deaths end
            return a.id < b.id
        end)
        return {
            ranking = ranking, winnerSide = winner,
            sides = { { id = 1, label = LABELS[1], score = tdm.score[1] }, { id = 2, label = LABELS[2], score = tdm.score[2] } },
            lines = {
                { label = "Winner", value = winner and sideName(winner) or "Draw" },
                { label = "Kill limit", value = tostring(tdm.limit) },
            },
            columns = { "kills", "deaths" },
        }
    end,
})
