local expireFlags, expireFlag = LightRP.expireFlags or function() end, LightRP.expireFlag or function() end -- framework.lua
-- The scene owns an isolated bucket and its environment, never the shared city.
-- Clients request only lifecycle changes: the server selects every world value.
local Config = LightRpConfig.characters.arrivalScene
local Creator = LightRP.module("creator", {})
local EVENT = LightRpEvents.net.creator
local sessions, requests = {}, {}
local function near(a, b, radius)
    return a and (a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2 <= radius*radius
end
local function approach()
    local o, a, p = Config.approachOffset, math.rad(Config.heading), Config.position
    return { x=p.x+math.cos(a)*o.x-math.sin(a)*o.y,
        y=p.y+math.sin(a)*o.x+math.cos(a)*o.y, z=p.z+o.z }
end
function Creator.isPreparing(player) return sessions[player] and sessions[player].preparing == true end

local function reply(player, phase, reason)
    TriggerClientEvent(EVENT, player, { phase = phase, error = reason })
end

function Creator.stop(player, disconnected)
    local s = sessions[player]
    if not s then return end
    sessions[player] = nil -- retire before any callbacks or delayed teleport reply
    if s.playback then Open77.animations.stop(player, s.playback) end
    if not disconnected and GetPlayerRoutingBucket(player) == s.bucket then
        SetPlayerRoutingBucket(player, s.previousBucket)
    end
    Open77.environment.clearBucket(s.bucket)
    if not disconnected then reply(player, "closed") end
end

local function fail(player, session, reason)
    if sessions[player] ~= session then return end
    Creator.stop(player)
    LightRP.log("creator for %d: %s", player, tostring(reason))
    reply(player, "error", "The arrival scene could not start. Retry when the world is ready.")
end

local function begin(player, c)
    local s = sessions[player]
    if s then
        if s.key ~= c.key then Creator.stop(player); s = nil
        elseif s.preparing then return
        else
            s.paused = false
            if near(Open77.players.position(player), Config.position, 2) then reply(player, "placed"); return end
            Creator.stop(player); s = nil
        end
    end
    local bucket = Config.bucketBase + player
    if #GetPlayersInBucket(bucket) > 0 then return reply(player, "error", "The arrival scene is occupied. Please retry.") end
    s = { key = c.key, bucket = bucket, previousBucket = GetPlayerRoutingBucket(player), preparing = true }
    sessions[player] = s
    local env, reason = Open77.environment.setTime(12, 0, 0, bucket)
    if not env then return fail(player, s, reason) end
    for _, call in ipairs({
        function() return Open77.environment.setTimeFrozen(true, bucket) end,
        function() return Open77.environment.setWeather("sunny", 0, bucket) end,
        function() return Open77.environment.setWeatherFrozen(true, bucket) end,
    }) do
        local ok, why = call()
        if not ok then return fail(player, s, why) end
    end
    reply(player, "preparing")
    CreateThread(function()
        -- Long-distance relocation needs the streamed respawn transaction on
        -- the deployed client. A raw travel to an unloaded floor fell forever.
        -- Land in front of the bench: its collider pushes standing bodies away.
        local p, life = approach(), Open77.players.getLifeState(player)
        if not life then return fail(player, s, "player_not_found") end
        if life.phase ~= "dead" then
            local killed, why = Open77.players.kill(player, { cause="script", weapon="lightrp:creator_arrival" })
            if not killed then return fail(player, s, why) end
        end
        local placed, why = Open77.players.respawn(player, {
            position=p, heading=Config.heading, bucket=bucket,
            health=LightRpConfig.spawn.health, graceMs=LightRpConfig.spawn.graceMs,
        })
        if not placed then return fail(player, s, why) end
        local started = LightRP.nowMs()
        while sessions[player] == s and LightRP.nowMs()-started < 30000 do
            Wait(100)
            if sessions[player] ~= s then return end
            life = Open77.players.getLifeState(player)
            if life and life.phase == "alive"
                and GetPlayerRoutingBucket(player) == bucket and near(Open77.players.position(player), p, 1.5) then
                s.preparing = false
                if not s.paused then reply(player, "placed") end
                return
            end
        end
        if sessions[player] == s then fail(player, s, "arrival_timeout") end
    end)
end

RegisterNetEvent(EVENT, function(payload)
    local player = tonumber(source)
    if not player or type(payload) ~= "table" then return end
    local c = LightRP.characters.get(player)
    if not c or c.status == "active" then return end
    if Config.autoStart == false or (LightRP.creatorPlacement and LightRP.creatorPlacement.has(player)) then return end
    local now = LightRP.nowMs()
    if now - (requests[player] or -10000) < 250 then return end
    requests[player] = now
    if payload.operation == "pause" then
        local s = sessions[player]
        if s then
            s.paused = true
            if s.playback then Open77.animations.stop(player, s.playback); s.playback = nil end
        end
        return
    end
    -- Never jump over the initial native body creator or its gameplay gate.
    if LightRP.db.ready and not c.bodyFamily then return end
    if Open77.ready and not Open77.ready.isReady(player) then return end
    if payload.operation == "start" then begin(player, c)
    elseif payload.operation == "seat" then
        local s = sessions[player]
        if not s or s.preparing or s.paused or s.key ~= c.key then return end
        local position = Open77.players.position(player)
        local p = Config.position
        if not near(position, p, 2) then return end
        if not s.playback or not Open77.animations.current(player) then
            local animation, why = Open77.animations.playAt(player, "chair", p, Config.heading, {
                loop = true, clip = "sit_chair_lean180__2h_on_lap__01__long__01",
            })
            if not animation then return fail(player, s, why) end
            s.playback = animation.playbackId
        end
        reply(player, "seated")
    end
end)

function Creator.onDisconnected(player) Creator.stop(player, true); requests[player] = nil end
function Creator.onCharacterSwitched(player) Creator.stop(player) end
function Creator.onCharacterActivated(player) Creator.stop(player) end
AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    local ids = {}; for player in pairs(sessions) do ids[#ids+1] = player end
    for _, player in ipairs(ids) do Creator.stop(player) end
end)

-- Stale flags left by tasks the instruction quota killed (framework.lua expireFlags).
expireFlags("creator.preparing", sessions, nil, "preparing")
