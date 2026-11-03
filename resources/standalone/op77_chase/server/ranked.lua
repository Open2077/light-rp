-- op77_chase ranked + results: after a match, on this resource's own thread,
--   1. the Elo of both characters (op77_chase_ratings, in Light RP's database; in memory
--      when the database is off, and the replies say so);
--   2. one "op77_lightrp:activity:result" per player still connected: placement, rounds
--      won, stats, reputation. No cash, no items: Light RP owns reputation and its caps.
ChaseRanked = { ratings = {}, db = nil, dbReason = "not probed", daily = {} }
local K = ChaseRanked

local function log(fmt, ...) print(("[op77_chase] " .. fmt):format(...)) end

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS op77_chase_ratings (
        character_id  VARCHAR(160) NOT NULL PRIMARY KEY,
        identifier    VARCHAR(96)  NOT NULL,
        name          VARCHAR(64)  NOT NULL DEFAULT '',
        rating        INT NOT NULL,
        matches       INT NOT NULL DEFAULT 0,
        wins          INT NOT NULL DEFAULT 0,
        losses        INT NOT NULL DEFAULT 0,
        draws         INT NOT NULL DEFAULT 0,
        forfeits      INT NOT NULL DEFAULT 0,
        busts         INT NOT NULL DEFAULT 0,
        escapes       INT NOT NULL DEFAULT 0,
        peak_rating   INT NOT NULL,
        last_match_at DATETIME NULL,
        KEY idx_op77_chase_ratings_rating (rating),
        KEY idx_op77_chase_ratings_identifier (identifier)
    ) ENGINE=InnoDB]],
    [[CREATE TABLE IF NOT EXISTS op77_chase_matches (
        id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        match_id      BIGINT NOT NULL,
        played_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        mode          VARCHAR(16) NOT NULL,
        rounds        VARCHAR(255) NOT NULL DEFAULT '',
        outcome       VARCHAR(32) NOT NULL,
        drawn         TINYINT(1) NOT NULL DEFAULT 0,
        forfeit       TINYINT(1) NOT NULL DEFAULT 0,
        a_character   VARCHAR(160) NOT NULL,
        a_score       INT NOT NULL,
        a_before      INT NOT NULL,
        a_after       INT NOT NULL,
        b_character   VARCHAR(160) NOT NULL,
        b_score       INT NOT NULL,
        b_before      INT NOT NULL,
        b_after       INT NOT NULL,
        KEY idx_op77_chase_matches_a (a_character),
        KEY idx_op77_chase_matches_b (b_character)
    ) ENGINE=InnoDB]],
}

function K.characterId(m)
    if type(m.identifier) ~= "string" or m.identifier == "" then return nil end
    return m.identifier .. "#" .. tostring(m.characterKey or "default")
end

-- ---------------------------------------------------------------- database (own thread only)

local function dbAvailable()
    return type(MySQL) == "table" and type(MySQL.update) == "table" and type(MySQL.update.await) == "function"
end

function K.ensureSchema()
    if K.db ~= nil then return K.db end
    if not dbAvailable() then
        K.db, K.dbReason = false, "no database bridge"
        log("ranked: no database - ratings are kept in memory for this run only")
        return false
    end
    local ok, err = pcall(function() for _, sql in ipairs(SCHEMA) do MySQL.update.await(sql) end end)
    if not ok then
        K.db, K.dbReason = false, tostring(err)
        log("ranked: database unavailable (%s) - ratings are kept in memory for this run only", K.dbReason)
        return false
    end
    K.db, K.dbReason = true, "ready"
    return true
end

local function load(characterId, name, t)
    local record = K.ratings[characterId]
    if record == nil then
        record = ChaseElo.blank(t)
        K.ratings[characterId] = record
    end
    if name and name ~= "" then record.name = name end
    if record.loaded or not K.ensureSchema() then record.loaded = true; return record end
    local ok, row = pcall(MySQL.single.await,
        "SELECT rating, matches, wins, losses, draws, forfeits, busts, escapes, peak_rating FROM op77_chase_ratings WHERE character_id = ? LIMIT 1",
        { characterId })
    if not ok then log("ranked: load failed for %s: %s", characterId, tostring(row)) return record end
    if type(row) == "table" then
        for _, key in ipairs({ "rating", "matches", "wins", "losses", "draws", "forfeits", "busts", "escapes" }) do
            record[key] = math.floor(tonumber(row[key]) or record[key] or 0)
        end
        record.peak = math.floor(tonumber(row.peak_rating) or record.rating)
    end
    record.loaded = true
    return record
end

local function persist(rows, matchRow)
    if not K.db or type(MySQL.transaction) ~= "table" or type(MySQL.transaction.await) ~= "function" then return false end
    local queries = {}
    for _, r in ipairs(rows) do
        queries[#queries + 1] = { query = [[INSERT INTO op77_chase_ratings
            (character_id, identifier, name, rating, matches, wins, losses, draws, forfeits, busts, escapes, peak_rating, last_match_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE name = VALUES(name), rating = VALUES(rating), matches = VALUES(matches),
                wins = VALUES(wins), losses = VALUES(losses), draws = VALUES(draws), forfeits = VALUES(forfeits),
                busts = VALUES(busts), escapes = VALUES(escapes),
                peak_rating = GREATEST(peak_rating, VALUES(peak_rating)), last_match_at = CURRENT_TIMESTAMP]],
            values = { r.characterId, r.identifier, (r.record.name or ""):sub(1, 64), r.record.rating, r.record.matches,
                r.record.wins, r.record.losses, r.record.draws, r.record.forfeits, r.record.busts or 0, r.record.escapes or 0,
                r.record.peak } }
    end
    queries[#queries + 1] = { query = [[INSERT INTO op77_chase_matches
        (match_id, mode, rounds, outcome, drawn, forfeit, a_character, a_score, a_before, a_after, b_character, b_score, b_before, b_after)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        values = { matchRow.matchId, matchRow.mode, matchRow.rounds:sub(1, 255), matchRow.outcome, matchRow.drawn and 1 or 0,
            matchRow.forfeit and 1 or 0, matchRow.a, matchRow.aScore, matchRow.aBefore, matchRow.aAfter,
            matchRow.b, matchRow.bScore, matchRow.bBefore, matchRow.bAfter } }
    local ok, committed, reason = pcall(MySQL.transaction.await, queries)
    if not ok or committed ~= true then
        log("ranked: match %s not saved: %s", tostring(matchRow.matchId), tostring(ok and reason or committed))
        return false
    end
    return true
end

-- ---------------------------------------------------------------- pure parts (tested)

-- Per member: rounds won/lost, busts made as cop, escapes made as runner, rounds per role.
function K.tally(match, id)
    local s = { roundsWon = 0, roundsLost = 0, busts = 0, escapes = 0, copRounds = 0, runnerRounds = 0, timeMs = 0 }
    for _, round in ipairs(match.rounds or {}) do
        local role = round.roles and round.roles[id]
        if role == "cop" then s.copRounds = s.copRounds + 1 elseif role == "runner" then s.runnerRounds = s.runnerRounds + 1 end
        if round.outcome ~= "opponent_left" then
            if round.winner == id then
                s.roundsWon = s.roundsWon + 1
                if round.outcome == "runner_busted" then s.busts = s.busts + 1 end
                if round.outcome == "runner_escaped" then s.escapes = s.escapes + 1 end
            elseif round.winner ~= nil then
                s.roundsLost = s.roundsLost + 1
            end
        end
        s.timeMs = s.timeMs + (round.durationMs or 0)
    end
    return s
end

-- Played = at least one round reached its active phase (a forfeit before that is not rated).
function K.played(match)
    return (match.played or 0) > 0
end

local function dayOf()
    if type(Open77) == "table" and type(Open77.time) == "table" and type(Open77.time.unix) == "function" then
        local ok, unix = pcall(Open77.time.unix)
        if ok and tonumber(unix) then return math.floor(tonumber(unix) / 86400) end
    end
    return 0
end

-- Reputation for one member: by result, zero for a leaver, and only the first
-- `perOpponentPerDay` matches against the same character in a day pay anything.
function K.reputation(match, m, day)
    local rep = ChaseConfig.reputation
    if match.void or not K.played(match) or match.hasBots then return 0 end
    if match.leaver == m.id then return rep.leaver or 0 end
    local other
    for _, o in ipairs(match.members) do if o.id ~= m.id then other = o end end
    local key = ("%d|%s|%s"):format(day or 0, tostring(K.characterId(m) or m.id), tostring(other and (K.characterId(other) or other.id)))
    local count = (K.daily[key] or 0) + 1
    K.daily[key] = count
    if count > (rep.perOpponentPerDay or 3) then return 0 end
    if match.outcome == "opponent_left" then return match.champion == m.id and (rep.forfeitWin or 0) or 0 end
    if match.drawn then return rep.draw or 0 end
    return match.champion == m.id and (rep.win or 0) or (rep.loss or 0)
end

function K.buildResult(match, m, elo, day)
    local s = K.tally(match, m.id)
    local won = match.champion ~= nil and match.champion == m.id
    s.mode = match.mode
    s.forfeit = match.outcome == "opponent_left" or nil
    if elo then s.elo, s.eloDelta = elo.after, elo.delta end
    return {
        placement = (won or match.drawn) and 1 or 2,
        score = s.roundsWon,
        won = won,
        stats = s,
        reputation = K.reputation(match, m, day),
        recap = ChaseRecap and ChaseRecap.safe("ranked", match) or nil, -- Light RP's end-of-match recap (recap.lua)
    }
end

-- ---------------------------------------------------------------- after a match

function K.onFinished(match)
    if match.void then return end
    if match.hasBots then
        -- Against a bot (staff bot mode): no rating, nothing saved, nothing earned. The player's
        -- result is marked test, so Light RP never records it even if bot mode was turned off
        -- meanwhile.
        for _, m in ipairs(match.members) do
            if not m.gone and not m.bot then
                local result = K.buildResult(match, m, nil, 0)
                result.reputation, result.test = 0, true
                ChaseCore.result(m.id, result)
            end
        end
        return
    end
    CreateThread(function()
        local t = ChaseElo.settings(ChaseConfig.ranked)
        local elo = {}
        local a, b = match.members[1], match.members[2]
        local idA, idB = a and K.characterId(a), b and K.characterId(b)
        local rated = t.enabled and a and b and idA and idB and a.identifier ~= b.identifier
            and (K.played(match) or t.rateUnplayedForfeit)
        if rated then
            local ok, err = pcall(function()
                local ra, rb = load(idA, a.name, t), load(idB, b.name, t)
                local scoreA = match.drawn and 0.5 or (match.champion == a.id and 1.0 or 0.0)
                local beforeA, beforeB = ra.rating, rb.rating
                local dA, dB = ChaseElo.rate(ra, rb, scoreA, t)
                local forfeit = match.outcome == "opponent_left"
                ChaseElo.apply(ra, dA, scoreA, forfeit)
                ChaseElo.apply(rb, dB, 1.0 - scoreA, forfeit)
                local ta, tb = K.tally(match, a.id), K.tally(match, b.id)
                ra.busts, ra.escapes = (ra.busts or 0) + ta.busts, (ra.escapes or 0) + ta.escapes
                rb.busts, rb.escapes = (rb.busts or 0) + tb.busts, (rb.escapes or 0) + tb.escapes
                elo[a.id] = { before = beforeA, after = ra.rating, delta = dA }
                elo[b.id] = { before = beforeB, after = rb.rating, delta = dB }
                local rounds = {}
                for _, r in ipairs(match.rounds) do rounds[#rounds + 1] = ("%s:%s"):format(tostring(r.winnerRole or "-"), r.outcome) end
                persist({
                    { characterId = idA, identifier = a.identifier, record = ra },
                    { characterId = idB, identifier = b.identifier, record = rb },
                }, { matchId = match.id, mode = match.mode, rounds = table.concat(rounds, ","), outcome = tostring(match.outcome),
                    drawn = match.drawn, forfeit = forfeit, a = idA, aScore = match.score[a.id] or 0, aBefore = beforeA, aAfter = ra.rating,
                    b = idB, bScore = match.score[b.id] or 0, bBefore = beforeB, bAfter = rb.rating })
            end)
            if not ok then log("ranked: match %d not rated: %s", match.id, tostring(err)) end
        end
        local day = dayOf()
        for _, m in ipairs(match.members) do
            if not m.gone then
                local result = K.buildResult(match, m, elo[m.id], day)
                ChaseCore.result(m.id, result)
                local e = elo[m.id]
                if e then
                    ChaseWorld.notify(m.id, "info", ("Chase rating %d (%s%d)%s"):format(e.after, e.delta >= 0 and "+" or "", e.delta,
                        K.db and "" or " - not saved: no database"), 6000)
                end
            end
        end
    end)
end

-- Own thread only (reads the database).
function K.top(n)
    local t = ChaseElo.settings(ChaseConfig.ranked)
    n = math.max(1, math.min(t.leaderboardSize, tonumber(n) or t.leaderboardSize))
    if K.ensureSchema() then
        local ok, rows = pcall(MySQL.query.await,
            ("SELECT name, rating, wins, losses, draws FROM op77_chase_ratings ORDER BY rating DESC LIMIT %d"):format(n), {})
        if ok and type(rows) == "table" then return rows, true end
    end
    local rows = {}
    for _, r in pairs(K.ratings) do rows[#rows + 1] = { name = r.name or "?", rating = r.rating, wins = r.wins, losses = r.losses, draws = r.draws } end
    table.sort(rows, function(x, y) return x.rating > y.rating end)
    while #rows > n do table.remove(rows) end
    return rows, false
end

function K.recordOf(m)
    local id = K.characterId(m)
    if not id then return nil end
    return load(id, m.name, ChaseElo.settings(ChaseConfig.ranked))
end

Chase.onFinished = K.onFinished
