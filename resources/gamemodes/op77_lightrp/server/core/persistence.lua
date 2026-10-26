-- The owner MySQL bridge, wrapped once. Modules declare their tables here and
-- read/write through LightRP.db; without a configured database the framework
-- still runs and every module keeps session-only memory.
local Db = { ready = false, pending = {} }
LightRP.db = Db

function Db.available()
    return type(MySQL) == "table" and type(MySQL.update) == "table" and type(MySQL.update.await) == "function"
end

-- Queue a CREATE TABLE (or any DDL) to run once the bridge answers.
function Db.schema(sql)
    Db.pending[#Db.pending + 1] = sql
    if Db.ready then Db.run(sql) end
end

function Db.run(sql, params)
    if not Db.ready then return false, "database_unavailable" end
    local ok, result = pcall(function() return MySQL.update.await(sql, params) end)
    if not ok then LightRP.log("db update failed: %s", tostring(result)) return false, result end
    return true, result
end

function Db.single(sql, params)
    if not Db.ready then return nil end
    local ok, row = pcall(function() return MySQL.single.await(sql, params) end)
    if not ok then LightRP.log("db single failed: %s", tostring(row)) return nil end
    return row
end

-- A commerce checkout is one transaction: items, balance and receipt must
-- commit together. Never fall back to a sequence of independent writes.
function Db.transaction(queries)
    if not Db.ready then return false, "database_unavailable" end
    if type(MySQL.transaction) ~= "table" or type(MySQL.transaction.await) ~= "function" then
        return false, "transaction_unavailable"
    end
    local ok, committed, reason = pcall(MySQL.transaction.await, queries)
    if not ok or committed ~= true then
        LightRP.log("db transaction refused: %s", tostring(ok and reason or committed))
        return false, "database_error"
    end
    return true
end

function Db.query(sql, params)
    if not Db.ready then return {} end
    local ok, rows = pcall(function() return MySQL.query.await(sql, params) end)
    if not ok then LightRP.log("db query failed: %s", tostring(rows)) return {} end
    return rows or {}
end

-- Unlike query(), this distinguishes an empty result from an unavailable DB.
-- Ownership must never be interpreted as an empty garage after a failed read.
function Db.read(sql, params)
    if not Db.ready then return false, "database_unavailable" end
    local ok, rows = pcall(function() return MySQL.query.await(sql, params) end)
    if not ok or type(rows) ~= "table" then
        LightRP.log("db read failed: %s", tostring(rows))
        return false, "database_error"
    end
    return true, rows
end

CreateThread(function()
    if not Db.available() then
        LightRP.log("no database bridge: everything is kept for this session only")
        return
    end
    local ok, err = pcall(function()
        for _, sql in ipairs(Db.pending) do MySQL.update.await(sql) end
    end)
    if ok then
        Db.ready = true
        LightRP.log("persistence ready (%d table(s))", #Db.pending)
        LightRP.eachModule("onDatabaseReady")
    else
        LightRP.log("persistence disabled: %s", tostring(err))
    end
end)
