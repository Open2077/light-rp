-- open77_lobby_cubes, server side: the lobby has its own sky.
--
-- Whoever stands in the lobby's box (zone.lua) is moved to the lobby's routing bucket, whose clock is held at night
-- under a clear sky; the city keeps its own time and weather. Leaving the box gives the player their bucket back.
-- This is the server's own way of giving a place its sky (open77_weather holds one environment per bucket; the
-- character creator of op77_lightrp does the same): a client forcing its clock would fight the shared one.
--
-- Only players of the bucket the city lives in are taken: someone in a private bucket (character creation, a match)
-- is left alone. The lobby's players see each other and nobody from outside, which the box hides anyway.

local Config = {
    bucket = 620000,                         -- the lobby's routing bucket
    cityBucket = 0,                          -- the bucket players are taken from and given back to
    time = { hour = 0, minute = 0, second = 0 },
    weather = 'sunny',
    enter = 4.0,                             -- metres round the box within which one is in the lobby
    leave = 30.0,                            -- metres round the box beyond which one has left it
    intervalMs = 1000,
}

local Zone = Open77LobbyZone
local taken, ready, stopped = {}, false, false

local function log(text) print('[lobby] ' .. text) end

local function within(p, margin)
    return p ~= nil and p.x >= Zone.min.x - margin and p.x <= Zone.max.x + margin
        and p.y >= Zone.min.y - margin and p.y <= Zone.max.y + margin
        and p.z >= Zone.min.z - margin and p.z <= Zone.max.z + margin
end

-- The night of the lobby's bucket. Tried again until the weather resource answers.
local function claim()
    if type(Open77.environment) ~= 'table' or type(Open77.environment.setTime) ~= 'function' then return false, 'environment_unavailable' end
    for _, call in ipairs({
        function() return Open77.environment.setTime(Config.time.hour, Config.time.minute, Config.time.second, Config.bucket) end,
        function() return Open77.environment.setTimeFrozen(true, Config.bucket) end,
        function() return Open77.environment.setWeather(Config.weather, 0, Config.bucket) end,
        function() return Open77.environment.setWeatherFrozen(true, Config.bucket) end,
    }) do
        local ok, reason = call()
        if not ok then return false, reason end
    end
    return true
end

local function release()
    for player, previous in pairs(taken) do
        if GetPlayerRoutingBucket(player) == Config.bucket then SetPlayerRoutingBucket(player, previous) end
    end
    taken = {}
    if ready then Open77.environment.clearBucket(Config.bucket) end
    ready = false
end

local function pass()
    if not ready then
        local ok, reason = claim()
        if not ok then return reason end
        ready = true
        log(('night %02d:%02d and %s weather in bucket %d'):format(Config.time.hour, Config.time.minute, Config.weather, Config.bucket))
    end
    local here = {}
    for _, player in ipairs(GetPlayers()) do
        player = tonumber(player)
        here[player] = true
        local bucket, position = GetPlayerRoutingBucket(player), Open77.players.position(player)
        if bucket == Config.cityBucket and within(position, Config.enter) then
            taken[player] = bucket
            SetPlayerRoutingBucket(player, Config.bucket)
        elseif bucket == Config.bucket and position ~= nil and not within(position, Config.leave) then
            SetPlayerRoutingBucket(player, taken[player] or Config.cityBucket)
            taken[player] = nil
        elseif bucket ~= Config.bucket then
            taken[player] = nil              -- moved elsewhere by another resource
        end
    end
    for player in pairs(taken) do if not here[player] then taken[player] = nil end end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    release()
end)

CreateThread(function()
    local told = nil
    while not stopped do
        local problem = pass()
        if problem ~= told then
            told = problem
            if problem then log('the lobby\'s sky is not set yet: ' .. tostring(problem)) end
        end
        Wait(Config.intervalMs)
    end
end)
