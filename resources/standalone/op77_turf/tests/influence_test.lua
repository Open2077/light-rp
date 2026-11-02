-- op77_turf weekly influence: memory + database (a fake MySQL bridge), week rollover,
-- sorting, the no-database fallback.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test influence_test.lua
local logs, realPrint = {}, print
print = function(...) logs[#logs + 1] = table.concat({ ... }, " ") end

_G.CreateThread = function(fn) fn() end
_G.Wait = function() end
dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/influence.lua")
local K, R = TurfInfluence, TurfRules

local MONDAY = 1793577600
local WEEK = R.weekIndex(MONDAY)

-- A fake bridge: schema statements, a per-week table, transactions.
local db
local function fakeMySQL(opts)
    opts = opts or {}
    db = { ddl = {}, rows = {}, wars = {}, tx = 0 }
    _G.MySQL = {
        update = { await = function(sql, values)
            if opts.failSchema then error("Access denied") end
            if sql:find("CREATE TABLE") then db.ddl[#db.ddl + 1] = sql return 0 end
            return 1
        end },
        query = { await = function(sql, values)
            assert(sql:find("FROM op77_turf_influence WHERE week_index = %?"))
            local out = {}
            for gang, r in pairs(db.rows[values[1]] or {}) do
                out[#out + 1] = { gang = gang, points = r.points, wars = r.wars, wins = r.wins, captures = r.captures }
            end
            return out
        end },
        transaction = { await = function(queries)
            db.tx = db.tx + 1
            for _, q in ipairs(queries) do
                if q.query:find("INSERT INTO op77_turf_influence") then
                    assert(q.query:find("ON DUPLICATE KEY UPDATE points = points %+ VALUES%(points%)"), "additive upsert")
                    local v = q.values
                    db.rows[v[1]] = db.rows[v[1]] or {}
                    local r = db.rows[v[1]][v[2]] or { points = 0, wars = 0, wins = 0, captures = 0 }
                    r.points, r.wars, r.wins, r.captures = r.points + v[3], r.wars + v[4], r.wins + v[5], r.captures + v[6]
                    db.rows[v[1]][v[2]] = r
                elseif q.query:find("INSERT INTO op77_turf_wars") then
                    db.wars[#db.wars + 1] = q.values
                else error("unexpected query " .. q.query) end
            end
            return true
        end },
    }
end

-- ---------------------------------------------------------------- with a database
fakeMySQL()
db.rows[WEEK] = { maelstrom = { points = 7, wars = 1, wins = 0, captures = 2 } }
K.refresh(MONDAY + 3600)
assert(K.db == true and #db.ddl == 2, "two tables created on first use")
assert(db.ddl[1]:find("op77_turf_influence") and db.ddl[1]:find("PRIMARY KEY %(week_index, gang%)"))
assert(db.ddl[2]:find("op77_turf_wars"))
assert(K.week == WEEK and K.rows.maelstrom.points == 7, "the week's rows loaded from the database")

K.record({ valentinos = { points = 20, wars = 1, wins = 1, captures = 6 }, maelstrom = { points = 3, wars = 1, wins = 0, captures = 1 } },
    { site = "kabuki", gangA = "valentinos", gangB = "maelstrom", scoreA = 900, scoreB = 410, winner = 1, fighters = 9,
      durationS = 420, counted = true }, MONDAY + 7200)
assert(K.rows.valentinos.points == 20 and K.rows.maelstrom.points == 10, "memory first")
assert(db.tx == 1 and db.rows[WEEK].valentinos.points == 20 and db.rows[WEEK].maelstrom.points == 10, "then one transaction")
local war = db.wars[1]
assert(war[1] == WEEK and war[2] == "kabuki" and war[3] == "valentinos" and war[7] == 1 and war[10] == 1)

local list = K.list()
assert(list[1].gang == "valentinos" and list[1].label == "Valentinos" and list[1].color == "#D9A441" and list[2].gang == "maelstrom")
local points, rank = K.of("maelstrom")
assert(points == 10 and rank == 2)
assert(K.of("animals") == nil and K.of(nil) == nil)
assert(K.describe(6):find("1%. Valentinos 20 %(1 war, 1 won%)") and not K.describe(6):find("not saved"))

-- ties: points, then wins, then name
K.rows.animals = { points = 10, wars = 2, wins = 1, captures = 0 }
list = K.list()
assert(list[2].gang == "animals" and list[3].gang == "maelstrom", "10 = 10: more wins first")

-- a void / uncounted war still logs its row, with no influence
K.record({}, { site = "badlands", gangA = nil, gangB = nil, scoreA = 0, scoreB = 0, winner = 0, fighters = 2,
    durationS = 30, counted = false }, MONDAY + 9000)
assert(db.tx == 2 and #db.wars == 2 and db.wars[2][10] == 0)

-- the week turns: memory starts from zero, the database keeps the old week
K.refresh(MONDAY + 7 * 86400 + 60)
assert(K.week == WEEK + 1 and next(K.rows) == nil and K.describe():find("No gang"))
assert(db.rows[WEEK].valentinos.points == 20)
K.record({ animals = { points = 2, wars = 1, wins = 0, captures = 0 } }, nil, MONDAY + 7 * 86400 + 120)
assert(db.rows[WEEK + 1].animals.points == 2 and K.rows.animals.points == 2)

-- a restart mid-week reloads the week from the database
K.week, K.rows, K.loadedWeek = nil, {}, nil
K.refresh(MONDAY + 7 * 86400 + 600)
assert(K.rows.animals.points == 2, "reloaded")

-- ---------------------------------------------------------------- without a database
_G.MySQL = nil
K.db, K.week, K.rows, K.loadedWeek = nil, nil, {}, nil
K.refresh(MONDAY)
assert(K.db == false and K.dbReason == "no database bridge")
K.record({ voodoo_boys = { points = 10, wars = 1, wins = 1, captures = 0 } }, { site = "kabuki", scoreA = 1, scoreB = 0,
    winner = 1, fighters = 2, durationS = 200, counted = true }, MONDAY + 60)
assert(K.rows.voodoo_boys.points == 10 and K.describe():find("not saved"), "memory only, and it says so")

fakeMySQL({ failSchema = true })
K.db, K.week, K.rows, K.loadedWeek = nil, nil, {}, nil
K.refresh(MONDAY)
assert(K.db == false and K.dbReason:find("Access denied"), "a database that refuses: memory only")

realPrint("PASS influence_test: schema, week load, record (memory + one transaction), sorting, ranks, week rollover, reload, no-database fallback")
