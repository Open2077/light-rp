-- op77_games server: wires the contract (core events), the client, the tick.
local Config = GamesConfig
local A = GamesActivity
local E = GamesEngine
local L = GamesLobby
local Maps = GamesMapStore

local function log(text) print("[games] " .. tostring(text)) end
local playerIdOf = E.playerId

local statusDirty = true
E.hooks.changed = function() statusDirty = true end

local function pushStatus(force)
    local t = E.now()
    for _, def in ipairs(A.list) do A.status(def.id, L.statusOf(def, t), force, t) end
end

-- ---------------------------------------------------------------- the core --

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    local def = A.definition(activityId)
    local ok, why = L.join(id, def, options)
    if not ok then A.notice(id, "error", def.label, why) end
    statusDirty = true
end)

-- Answered at once: the core gives us 15 s, then returns them itself. A queued player is
-- the core's to answer; an owned player with no match here is released anyway.
AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    local match = E.matchOf(id)
    if match and match.def.id == activityId then
        E.remove(id, "left")
        return
    end
    L.leave(id)
    if A.owner(id) == activityId then A.leave(id, activityId, { returnPlayer = true }) end
    statusDirty = true
end)

-- The core already released them: never activityLeave here.
AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = playerIdOf(playerId)
    if id == nil or not A.mine(activityId) then return end
    E.dropped(id, reason)
    L.leave(id)
    statusDirty = true
end)

-- Schemas first (the core validates and imports with them), then the maps, then the choices.
local function registerNow()
    if not Maps.offer() then return end
    local synced = Maps.syncAll()
    if A.register() then pushStatus(true) end
    if not synced then A.registered = false end
end

-- Retries every 3 s until the core accepts, and again whenever the core restarts (it
-- forgets its providers). One path, so a restart never registers twice.
local nextRegisterAt = 0
AddEventHandler("op77_lightrp:activity:ready", function()
    A.registered = false
    nextRegisterAt = 0
end)

-- Staff changed a game's maps (or the core can answer at last). Nothing arrives with the signal.
-- A failed pull goes through the retry above. Before the first registration there is no choice
-- to update: registerNow pulls for itself.
AddEventHandler("op77_lightrp:gamemaps:changed", function(activityId)
    if activityId ~= nil and not A.mine(activityId) then return end
    if not A.registered then return end
    local list = activityId and { A.definition(activityId) } or A.list
    for _, def in ipairs(list) do
        local ok, changed = Maps.sync(def)
        if not ok or (changed and not A.registerOne(def)) then
            A.registered = false
            nextRegisterAt = 0
        end
    end
    statusDirty = true
end)

AddEventHandler("onResourceStart", function(name)
    if name == Config.core then
        A.registered = false
        nextRegisterAt = E.now() + 500
    elseif name == GetCurrentResourceName() then
        log(("ready: %d games, buckets %d-%d"):format(#A.list, Config.buckets.first, Config.buckets.last))
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == Config.core then
        log("core stopped: closing every match")
        A.registered = false
        A.forgetStatus()
        E.coreStopped()
        L.clear()
        statusDirty = true
    elseif name == GetCurrentResourceName() then
        E.shutdown()
    end
end)

-- ---------------------------------------------------------------- players --

local function died(id, killer)
    id = playerIdOf(id)
    if id then E.onDeath(id, killer) end
end
AddEventHandler("open77:playerKilled", died)
AddEventHandler("open77:playerDied", function(playerId, context)
    local killer = 0
    if type(context) == "string" then
        killer = tonumber(context:match('"killer"%s*:%s*(%-?%d+)')) or 0
    elseif type(context) == "table" then
        killer = tonumber(context.killer) or 0
    end
    died(playerId, killer)
end)

AddEventHandler("onPlayerDisconnected", function(value)
    local id = playerIdOf(value)
    if id == nil then return end
    E.remove(id, "disconnect")
    L.leave(id)
    statusDirty = true
end)

-- The one thing a client may say: "tell me my HUD". It gets its own state or nothing, at
-- most once a second. No game event ever comes from a client: the server sees bodies.
local asked = {}
RegisterNetEvent("op77_games:ready", function()
    local id = playerIdOf(source)
    if id == nil then return end
    local t = E.now()
    if t < (asked[id] or 0) then return end
    asked[id] = t + 1000
    E.resend(id)
end)

-- ---------------------------------------------------------------- the tick --

CreateThread(function()
    local statusAt = 0
    while not E.stopped do
        local t = E.now()
        if not A.registered and t >= nextRegisterAt then
            registerNow()
            if not A.registered then nextRegisterAt = t + 3000 end
        end
        local ok, err = pcall(E.tick, t)
        if not ok then log("engine tick failed: " .. tostring(err)) end
        ok, err = pcall(L.tick, t)
        if not ok then log("lobby tick failed: " .. tostring(err)) end
        if A.registered and (statusDirty or t - statusAt >= Config.statusMs) then
            statusDirty, statusAt = false, t
            pushStatus(false)
        end
        Wait(Config.tickMs)
    end
end)
