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

-- A start with players already in the world: the host restarts a resource that a runtime
-- error stopped (a Lua memory quota at ~90 players, 2026-11-07), or a staff `ensure`.
-- Nobody connects again, so the players present are adopted as if they had just joined:
-- character, inventory, wallet (onConnected -> characters.load -> onCharacterLoaded), then
-- once those had time to load, their page and the in-world hooks. `spawn` is left out:
-- they are standing somewhere already and must not be moved. A few players per pass.
function LightRP.adoptConnectedPlayers()
    if type(GetPlayers) ~= "function" then return end
    local present = GetPlayers()
    if #present == 0 then return end
    LightRP.log("adopting %d connected player(s) after a restart", #present)
    for index, raw in ipairs(present) do
        local id = tonumber(raw)
        if id and id > 0 then LightRP.eachModule("onConnected", id, GetPlayerName(id)) end
        if index % 4 == 0 then Wait(0) end
    end
    Wait(5000)
    for index, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and id > 0 then
            LightRP.eachModuleExcept("spawn", "onUiReady", id)
            LightRP.eachModuleExcept("spawn", "onReady", id)
            LightRP.eachModuleExcept("spawn", "onGameplayReady", id)
            -- ... and the spawn module learns they already stand somewhere (Spawn.onAdopted:
            -- their position is saved again, server/modules/characters.lua samplePosition).
            LightRP.eachModule("onAdopted", id)
        end
        if index % 4 == 0 then Wait(0) end
    end
    LightRP.log("adopted %d player(s)", #present)
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
        -- Every module loads its rows here, and several register interaction points one by one
        -- (the authored mission boards...). Each registration sent the whole list (~36 KB) to
        -- every connected player: with two players reconnecting during a restart the resume ran
        -- out of instructions ("Open77 instruction quota exceeded", LightRP Testing 2026-11-06
        -- 00:48) and every module after it never loaded (Maneki-neko, parkour...). One list for
        -- the whole chain, sent at its end.
        if type(LightRP.batchInteractions) == "function" then
            local okBatch, why = pcall(LightRP.batchInteractions, function() LightRP.eachModule("onDatabaseReady") end)
            if not okBatch then LightRP.log("database-ready hooks failed: %s", tostring(why)) end
        else
            LightRP.eachModule("onDatabaseReady")
        end
        LightRP.adoptConnectedPlayers()
    else
        LightRP.log("persistence disabled: %s", tostring(err))
    end
end)
