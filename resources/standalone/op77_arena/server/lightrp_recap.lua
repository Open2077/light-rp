-- op77_arena: the end-of-match recap for Light RP (op77_lightrp server/modules/recap.lua).
-- Each result the adapter sends (lightrp.lua) carries `recap`, the whole scoreboard of
-- the round or match it closes -- every participant, the engine's bots included and
-- marked -- so every player of one match sees the same board:
--
--   FFA / Blade   one round (the board clears every round): placement, kills, deaths,
--                 assists, damage dealt and taken, headshot kills, score, time in it
--   PvE           the round, the players on one side and the bots on the other, the
--                 team kill count as the sides' scores
--   Team / Duel   the whole match: each participant's sums over its rounds (sampled
--                 by H.sample before a round clears the board, plus the last round
--                 still on it), each round's winner, the round score
--
-- Damage is what scoring.lua credits: player gunfire on a bot is credited by bots.lua
-- (E6: no onNpcDamaged for server-owned bots), so bot damage counts both ways.
-- Headshots are headshot KILLS (scoring.lua counts them at the kill).
local DM = Deathmatch
local H = ArenaHost

ArenaRecap = {}
local AR = ArenaRecap
AR.acc = setmetatable({}, { __mode = "k" }) -- arena match -> { id, roundId, round, rows, totals, rounds }
local matchSeq = 0

local FIELDS = { "kills", "deaths", "assists", "damage", "damageTaken", "headshots", "score" }
local SIDES = { "Team A", "Team B" }

local function now() return DM.nowMs() end
local function int(value) value = tonumber(value); if value == nil or value ~= value then return 0 end return math.floor(value + 0.5) end

local function boardRows(instance)
    local ok, rows = pcall(DM.scoring.rows, instance)
    return ok and type(rows) == "table" and rows or {}
end

local function participant(row, extra)
    local out = { id = row.id, name = row.name, bot = (row.bot == true or (tonumber(row.id) or 0) < 0) or nil }
    for _, field in ipairs(FIELDS) do out[field] = int(row[field]) end
    if row.id and row.id > 0 and row.active == false then out.left = true end
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

-- Time in this round or match: from the entry (players) or the row's join (bots).
local function inMatchMs(instance, row, fromMs, t)
    local entry = row.id and row.id > 0 and H.entered[row.id] or nil
    local start = fromMs or 0
    if entry and entry.instanceId == instance.id then start = math.max(start, tonumber(entry.atMs) or start) end
    return math.max(0, t - start)
end

-- One FFA round (Blade Night, Arena Night too).
function AR.ffa(instance, winnerId)
    local round = instance.round
    if round == nil then return nil end
    local t = now()
    local from = tonumber(round.startedAtMs) or t
    local rows = {}
    for _, row in ipairs(boardRows(instance)) do
        if #rows >= 40 then break end
        rows[#rows + 1] = participant(row, { placement = row.rank, inMatchMs = inMatchMs(instance, row, from, t) })
    end
    local lines = { { label = "Round", value = tostring(round.number or 1) } }
    if winnerId ~= nil then
        for _, row in ipairs(rows) do if row.id == winnerId then lines[#lines + 1] = { label = "Winner", value = tostring(row.name or "?") } end end
    end
    if H.night ~= nil and instance.ruleset ~= "blade" then lines[#lines + 1] = { label = "Event", value = "Arena Night" } end
    return { matchId = "arena:" .. tostring(round.id or (instance.id .. ":" .. tostring(round.number))),
        durationMs = math.max(0, t - from), detail = "Round " .. tostring(round.number or 1), rows = rows, lines = lines,
        columns = { "placement", "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score" } }
end

-- PvE: players (side 1) against the engine's bots (side 2).
function AR.pve(instance, playerKills, botKills, won)
    local round = instance.round
    if round == nil then return nil end
    local t = now()
    local from = tonumber(round.startedAtMs) or t
    local rows = {}
    for _, row in ipairs(boardRows(instance)) do
        if #rows >= 40 then break end
        local bot = row.bot == true or (tonumber(row.id) or 0) < 0
        rows[#rows + 1] = participant(row, { side = bot and 2 or 1, inMatchMs = inMatchMs(instance, row, from, t) })
    end
    return { matchId = "arena:" .. tostring(round.id or (instance.id .. ":" .. tostring(round.number))),
        durationMs = math.max(0, t - from), detail = "Round " .. tostring(round.number or 1),
        sides = { { id = 1, label = "Operators", score = int(playerKills) }, { id = 2, label = "Bots", score = int(botKills) } },
        winnerSide = won and 1 or 2, rows = rows,
        lines = { { label = "Kills", value = string.format("%d - %d", int(playerKills), int(botKills)) } },
        columns = { "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score" } }
end

-- Team Arena and duels: every round's board is summed before the next one clears it.
local function accOf(match)
    local acc = AR.acc[match]
    if acc == nil then
        matchSeq = matchSeq + 1
        acc = { id = matchSeq, roundId = nil, round = nil, rows = {}, totals = {}, names = {}, rounds = {} }
        AR.acc[match] = acc
    end
    return acc
end

local function fold(acc)
    for id, row in pairs(acc.rows) do
        local total = acc.totals[id] or { id = id }
        for _, field in ipairs(FIELDS) do total[field] = (total[field] or 0) + (row[field] or 0) end
        total.name, total.bot, total.team, total.active = row.name, row.bot, row.team, row.active
        acc.totals[id] = total
    end
    if acc.round ~= nil then
        acc.rounds[#acc.rounds + 1] = { number = acc.round.number, winner = acc.round.winnerSide }
    end
    acc.rows = {}
end

-- Called by H.sample on the adapter's tick (and before a report).
function AR.sample(instance)
    local match, round = instance.match, instance.round
    if match == nil or round == nil or round.id == nil then return end
    local acc = accOf(match)
    if acc.roundId ~= round.id then
        if acc.roundId ~= nil then fold(acc) end
        acc.roundId, acc.round = round.id, round
    end
    for _, row in ipairs(boardRows(instance)) do
        if row.id ~= nil then
            local copy = { name = row.name, bot = row.bot, team = row.team, active = row.active }
            for _, field in ipairs(FIELDS) do copy[field] = tonumber(row[field]) or 0 end
            acc.rows[row.id] = copy
        end
    end
end

function AR.match(instance)
    local match = instance.match
    if match == nil then return nil end
    AR.sample(instance)
    local acc = accOf(match)
    local t = now()
    local sums = {}
    for id, total in pairs(acc.totals) do sums[id] = total end
    -- the round still on the board
    for id, row in pairs(acc.rows) do
        local total = { id = id }
        local done = acc.totals[id]
        for _, field in ipairs(FIELDS) do total[field] = (done and done[field] or 0) + (row[field] or 0) end
        total.name, total.bot, total.team, total.active = row.name, row.bot, row.team, row.active
        sums[id] = total
    end
    local rows = {}
    for id, total in pairs(sums) do
        local side = (match.sides and match.sides[id]) or (H.entered[id] and H.entered[id].side) or total.team
        side = tonumber(side)
        if side ~= 1 and side ~= 2 then side = nil end
        rows[#rows + 1] = participant(total, { side = side, inMatchMs = inMatchMs(instance, total, nil, t) })
    end
    table.sort(rows, function(a, b) return (a.score or 0) > (b.score or 0) or ((a.score or 0) == (b.score or 0) and a.id > b.id) end)
    while #rows > 40 do table.remove(rows) end
    local result = match.result or {}
    local wins = result.wins or match.wins or { 0, 0 }
    local lines = { { label = "Rounds", value = string.format("%d - %d", int(wins[1]), int(wins[2])) } }
    local history = {}
    for _, r in ipairs(acc.rounds) do history[#history + 1] = r end
    local current = acc.round
    if current ~= nil and (history[#history] == nil or history[#history].number ~= current.number) and current.state ~= "active" then
        history[#history + 1] = { number = current.number, winner = current.winnerSide }
    end
    for _, r in ipairs(history) do
        if #lines >= 8 then break end
        local winner = tonumber(r.winner)
        lines[#lines + 1] = { label = "Round " .. tostring(r.number or "?"),
            value = (winner == 1 or winner == 2) and SIDES[winner] or "Draw" }
    end
    local started = tonumber(match.startedAtMs)
    if started == nil then
        for _, id in ipairs(DM.instances.humans(instance)) do
            local entry = H.entered[id]
            if entry and entry.instanceId == instance.id then started = math.min(started or math.huge, tonumber(entry.atMs) or t) end
        end
    end
    return { matchId = string.format("arena:%s:m%d", tostring(instance.id), acc.id),
        durationMs = math.max(0, t - (started or t)), detail = tostring(instance.format or "") .. (result.reason == "best_of" and "" or (" · " .. tostring(result.reason or "playing"))),
        sides = { { id = 1, label = SIDES[1], score = int(wins[1]) }, { id = 2, label = SIDES[2], score = int(wins[2]) } },
        winnerSide = tonumber(result.winnerSide) or nil, rows = rows, lines = lines,
        columns = { "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score" } }
end
