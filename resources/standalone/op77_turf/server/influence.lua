-- op77_turf weekly gang influence: who holds the city this week.
--
-- Two tables in Light RP's database, under this resource's own prefix, created on first
-- use and only ever touched from this resource's own threads:
--   op77_turf_influence (week_index, gang) -> points, wars, wins, captures
--   op77_turf_wars      one row per finished war (site, gangs, scores, winner, counted)
-- The current week lives in memory too, so the synchronous exports below never touch
-- the database (a synchronous export may not yield):
--   exports.op77_turf:influence()      -> { { gang, label, color, points, wars, wins, captures }, ... } (points desc), weekIndex
--   exports.op77_turf:influenceOf(gang) -> points, rank (nil when the gang has none this week)
-- Without a database the table lives in memory for the run and the replies say so.
TurfInfluence = { week = nil, rows = {}, db = nil, dbReason = "not probed", loadedWeek = nil }
local K = TurfInfluence
local R = TurfRules

local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS op77_turf_influence (
        week_index INT NOT NULL,
        gang       VARCHAR(32) NOT NULL,
        points     INT NOT NULL DEFAULT 0,
        wars       INT NOT NULL DEFAULT 0,
        wins       INT NOT NULL DEFAULT 0,
        captures   INT NOT NULL DEFAULT 0,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (week_index, gang),
        KEY idx_op77_turf_influence_points (week_index, points)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS op77_turf_wars (
        id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        week_index INT NOT NULL,
        played_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        site       VARCHAR(32) NOT NULL,
        gang_a     VARCHAR(32) NULL,
        gang_b     VARCHAR(32) NULL,
        score_a    INT NOT NULL,
        score_b    INT NOT NULL,
        winner     TINYINT NOT NULL,
        fighters   INT NOT NULL,
        duration_s INT NOT NULL,
        counted    TINYINT(1) NOT NULL DEFAULT 0,
        KEY idx_op77_turf_wars_week (week_index)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function dbAvailable()
    return type(MySQL) == "table" and type(MySQL.update) == "table" and type(MySQL.update.await) == "function"
end

-- Own thread only.
function K.ensureSchema()
    if K.db ~= nil then return K.db end
    if not dbAvailable() then
        K.db, K.dbReason = false, "no database bridge"
        log("influence: no database - kept in memory for this run only")
        return false
    end
    local ok, err = pcall(function() for _, sql in ipairs(SCHEMA) do MySQL.update.await(sql) end end)
    if not ok then
        K.db, K.dbReason = false, tostring(err)
        log("influence: database unavailable (%s) - kept in memory for this run only", K.dbReason)
        return false
    end
    K.db, K.dbReason = true, "ready"
    return true
end

-- Own thread only: the week's rows from the database replace the memory copy (the
-- writes are additive upserts, so the database is the truth once it answers).
function K.load(week)
    K.week = week
    if not K.ensureSchema() then K.loadedWeek = week return false end
    local ok, rows = pcall(MySQL.query.await,
        "SELECT gang, points, wars, wins, captures FROM op77_turf_influence WHERE week_index = ?", { week })
    if not ok or type(rows) ~= "table" then
        log("influence: week %d not loaded: %s", week, tostring(rows))
        return false
    end
    if K.week ~= week then return false end
    local fresh = {}
    for _, row in ipairs(rows) do
        local gang = R.gangKey(row.gang)
        if gang then
            fresh[gang] = { points = math.floor(tonumber(row.points) or 0), wars = math.floor(tonumber(row.wars) or 0),
                wins = math.floor(tonumber(row.wins) or 0), captures = math.floor(tonumber(row.captures) or 0) }
        end
    end
    K.rows, K.loadedWeek = fresh, week
    return true
end

-- Called once a minute (own thread): a new week starts from zero.
function K.refresh(unix)
    local week = R.weekIndex(unix)
    if K.week ~= week then
        K.week, K.rows = week, {}
        K.load(week)
    elseif K.loadedWeek ~= week then
        K.load(week)
    end
end

-- A counted war's influence: memory now (the scoreboard shows it at once), the
-- database on a thread of this resource. `deltas` = TurfRules.influence(...).
function K.record(deltas, warRow, unix)
    local week = R.weekIndex(unix)
    if K.week ~= week then K.week, K.rows = week, {} end
    for gang, d in pairs(deltas or {}) do
        local row = K.rows[gang] or { points = 0, wars = 0, wins = 0, captures = 0 }
        row.points, row.wars = row.points + d.points, row.wars + d.wars
        row.wins, row.captures = row.wins + d.wins, row.captures + d.captures
        K.rows[gang] = row
    end
    CreateThread(function()
        if not K.ensureSchema() then return end
        local queries = {}
        for gang, d in pairs(deltas or {}) do
            queries[#queries + 1] = { query = [[INSERT INTO op77_turf_influence (week_index, gang, points, wars, wins, captures)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE points = points + VALUES(points), wars = wars + VALUES(wars),
                    wins = wins + VALUES(wins), captures = captures + VALUES(captures)]],
                values = { week, gang, d.points, d.wars, d.wins, d.captures } }
        end
        if warRow then
            queries[#queries + 1] = { query = [[INSERT INTO op77_turf_wars
                (week_index, site, gang_a, gang_b, score_a, score_b, winner, fighters, duration_s, counted)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                values = { week, warRow.site, warRow.gangA, warRow.gangB, warRow.scoreA, warRow.scoreB, warRow.winner,
                    warRow.fighters, warRow.durationS, warRow.counted and 1 or 0 } }
        end
        if #queries == 0 then return end
        local ok, committed, reason
        if type(MySQL.transaction) == "table" and type(MySQL.transaction.await) == "function" then
            ok, committed, reason = pcall(MySQL.transaction.await, queries)
        else
            ok = pcall(function() for _, q in ipairs(queries) do MySQL.update.await(q.query, q.values) end end)
            committed = ok
        end
        if not ok or committed ~= true then
            log("influence: war of week %d not saved: %s", week, tostring(ok and reason or committed))
        end
    end)
end

-- Synchronous: the week's table, points first (ties: wins, then name).
function K.list(gangs)
    local out = {}
    for gang, row in pairs(K.rows) do
        local info = R.gangInfo(gang, nil, gangs or TurfConfig.gangs)
        out[#out + 1] = { gang = gang, label = info.label, color = info.color, points = row.points, wars = row.wars,
            wins = row.wins, captures = row.captures }
    end
    table.sort(out, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        if a.wins ~= b.wins then return a.wins > b.wins end
        return a.gang < b.gang
    end)
    return out
end

function K.of(gang)
    gang = R.gangKey(gang)
    if not gang or not K.rows[gang] then return nil end
    for rank, row in ipairs(K.list()) do
        if row.gang == gang then return row.points, rank end
    end
    return nil
end

-- One line per gang for chat.
function K.describe(limit)
    local list = K.list()
    if #list == 0 then return "No gang has fought a turf war this week." end
    local parts = {}
    for i, row in ipairs(list) do
        if i > (limit or 6) then break end
        parts[#parts + 1] = ("%d. %s %d (%d war%s, %d won)"):format(i, row.label, row.points, row.wars,
            row.wars == 1 and "" or "s", row.wins)
    end
    return "Who holds the city this week" .. (K.db == false and " (not saved: no database)" or "") .. ": " .. table.concat(parts, " | ")
end
