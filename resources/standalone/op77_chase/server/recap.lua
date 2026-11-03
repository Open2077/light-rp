-- op77_chase: the board each result carries for Light RP's end-of-match recap
-- (op77_lightrp server/modules/recap.lua). Bots (negative ids) are marked.
--
--   Chase 1v1  both drivers: rounds won, busts made as cop, escapes made as runner,
--              time in the rounds; each round as a line (who won it, how)
--   NCPD Escape  the runners (players): escaped / busted / left and how long they
--              lasted; the NCPD units as a line (the cop cars are not players)
--   Most Wanted  the table: placement, points, arrests (busts), extractions and
--              survivals (escapes), time as the runner
--
-- No damage column: chase damage is cars ramming cars, not a fight's number.
ChaseRecap = {}
local CR = ChaseRecap

local function int(value) value = tonumber(value); if value == nil or value ~= value then return 0 end return math.floor(value + 0.5) end
local function idOf(match) return tostring(match.id) .. "@" .. tostring(match.createdAtMs or 0) end
local function botOf(m) return (m.bot == true or (tonumber(m.id) or 0) < 0) or nil end

local ROUND_OUTCOMES = { runner_escaped = "escaped", runner_busted = "busted", opponent_left = "opponent left", time_expired = "time" }

function CR.ranked(match)
    local rows, names = {}, {}
    for _, m in ipairs(match.members or {}) do
        local s = ChaseRanked.tally(match, m.id)
        names[m.id] = m.name
        local won = match.champion ~= nil and match.champion == m.id
        rows[#rows + 1] = { id = m.id, name = m.name, bot = botOf(m), left = (m.gone == true or match.leaver == m.id) or nil,
            placement = (won or match.drawn) and 1 or 2, roundsWon = s.roundsWon, busts = s.busts, escapes = s.escapes,
            timeMs = s.timeMs, inMatchMs = s.timeMs }
    end
    local lines = {}
    for i, round in ipairs(match.rounds or {}) do
        if #lines >= 7 then break end
        local who = round.winner and names[round.winner] or nil
        lines[#lines + 1] = { label = "Round " .. tostring(round.index or i),
            value = (ROUND_OUTCOMES[round.outcome] or tostring(round.outcome or "?")) .. (who and (" · " .. tostring(who)) or "") }
    end
    if match.drawn then lines[#lines + 1] = { label = "Result", value = "Draw" } end
    return { matchId = "chase:" .. idOf(match), detail = "Chase 1v1", rows = rows, lines = lines,
        columns = { "placement", "roundsWon", "busts", "escapes", "timeMs" } }
end

function CR.pve(match)
    local rows, runners = {}, 0
    for _, m in ipairs(match.members or {}) do
        if not botOf(m) then
            runners = runners + 1
            rows[#rows + 1] = { id = m.id, name = m.name, outcome = m.outcome, left = m.outcome == "left" or nil,
                placement = m.outcome == "escaped" and 1 or (m.outcome ~= nil and 2 or nil),
                timeMs = m.seconds and m.seconds * 1000 or nil, inMatchMs = m.seconds and m.seconds * 1000 or nil,
                escapes = m.outcome == "escaped" and 1 or nil }
        end
    end
    local now = type(Open77) == "table" and Open77.time and type(Open77.time.monotonic) == "function" and math.floor(Open77.time.monotonic() * 1000) or nil
    return { matchId = "chase-pve:" .. idOf(match), detail = "NCPD Escape", rows = rows,
        durationMs = (now and match.startedAtMs) and math.max(0, now - match.startedAtMs) or nil,
        lines = { { label = "NCPD units", value = tostring(int(match.copCount)) }, { label = "Runners", value = tostring(runners) } },
        columns = { "timeMs" } }
end

function CR.wanted(match)
    local ids = {}
    for _, m in ipairs(match.members or {}) do ids[#ids + 1] = m.id end
    local table_ = match.standings or WantedRules.standings(match, ids)
    local byId = {}
    for _, m in ipairs(match.members or {}) do byId[m.id] = m end
    local rows = {}
    for _, row in ipairs(table_) do
        local m = byId[row.id] or {}
        local s = row.stats or WantedRules.stats(match, row.id)
        rows[#rows + 1] = { id = row.id, name = m.name, bot = botOf(m), left = (m.forfeit == true or m.gone == true) or nil,
            placement = row.placement, points = int(s.points), busts = int(s.arrests),
            escapes = int(s.extractions) + int(s.survivals), timeMs = int(s.runnerMs) }
    end
    return { matchId = "chase-wanted:" .. idOf(match), detail = "Most Wanted",
        rows = rows, lines = { { label = "Rounds", value = tostring(int(match.played)) } },
        columns = { "placement", "points", "busts", "escapes", "timeMs" } }
end

-- Never lets a recap failure touch a result.
function CR.safe(kind, match)
    local fn = CR[kind]
    if type(fn) ~= "function" then return nil end
    local ok, recap = pcall(fn, match)
    if ok then return recap end
    print("[chase] recap " .. tostring(kind) .. " failed: " .. tostring(recap))
    return nil
end
