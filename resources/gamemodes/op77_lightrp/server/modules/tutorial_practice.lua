-- Temporary, keyed training objects in one private bucket per participant.
-- The map is preloaded world geometry; only these network objects are instanced.
local P = LightRP.module("tutorialPractice", {})
local C, scenes = LightRpTutorialConfig, {}
function P.bucket(player) return C.practice.bucketBase+player end
function P.clear(player,disconnected)
    local s = scenes[player]
    if not s then return true end
    -- Restore only our own claim. A character switch/admin move may already
    -- have put the player elsewhere. Keep the scene if a return is refused.
    if not disconnected and GetPlayerRoutingBucket(player)==s.bucket then
        if not SetPlayerRoutingBucket(player,C.lobby.bucket) then
            return false,"The shared hall is not ready. Use /tutorial to return."
        end
        LightRP.log("tutorial practice: player %d returned from bucket %d to shared hall %d",player,s.bucket,C.lobby.bucket)
    end
    scenes[player] = nil
    if s.vehicle then
        if LightRP.keys then LightRP.keys.clear(s.vehicle) end
        Open77.vehicles.remove(s.vehicle)
    end
    if s.prop then Open77.props.remove(s.prop) end
    if s.environment then Open77.environment.clearBucket(s.bucket) end
    return true
end
function P.get(player) return scenes[player] end
local function enter(player,s)
    -- Join/resume from the city is placed by tutorial.spawnPoint / relocate.
    -- In the hall the bucket changes in place, without killing or teleporting.
    local life=Open77.players.getLifeState(player)
    if GetPlayerRoutingBucket(player)==C.lobby.bucket and life and life.phase=="alive" then
        if not SetPlayerRoutingBucket(player,s.bucket) then return nil,"The private practice area is not ready. Please retry." end
        LightRP.log("tutorial practice: player %d entered private bucket %d",player,s.bucket)
    end
    return s
end
local function environment(s)
    local env=Open77.environment
    local shared=env.getState(C.lobby.bucket) or env.getState()
    if not shared then return false end
    s.environment=true
    for _,call in ipairs({
        function() return env.setTime(shared.hour,shared.minute,shared.second,s.bucket) end,
        function() return env.setTimeRate(shared.rate,s.bucket) end,
        function() return env.setTimeFrozen(shared.timeFrozen,s.bucket) end,
        function() return env.setWeather(shared.weather,0,s.bucket) end,
        function() return env.setWeatherFrozen(shared.weatherFrozen,s.bucket) end,
    }) do if not call() then return false end end
    return true
end
function P.ensure(player,step)
    local s = scenes[player]
    if s and s.vehicle and s.prop and Open77.vehicles.get(s.vehicle) and Open77.props.get(s.prop) then return enter(player,s) end
    local cleared,why=P.clear(player)
    if not cleared then return nil,why end
    local bucket=P.bucket(player)
    for _,occupant in ipairs(GetPlayersInBucket(bucket)) do
        if tonumber(occupant)~=player then return nil,"The private practice area is occupied. Please retry." end
    end
    local a=C.practice.position
    local position={x=a.x,y=a.y,z=a.z}
    local propPosition={x=position.x+2.6,y=position.y-2.2,z=position.z}
    s={bucket=bucket,position=position,propPosition=propPosition};scenes[player]=s
    local function fail(message) P.clear(player); return nil,message end
    if not environment(s) then return fail("The practice environment is not ready. Please retry.") end
    local prop=Open77.props.create({model=C.practice.prop,position=propPosition,bucket=bucket,physics="static",collision=true})
    if not prop then return fail("The practice crate is not ready. Please retry.") end
    s.prop=prop
    local vehicle=Open77.vehicles.create({record=C.practice.vehicle,position=position,yaw=0,bucket=bucket})
    if not vehicle then return fail("The practice car is not ready. Please retry.") end
    s.vehicle=vehicle
    local keys=LightRP.keys and LightRP.keys.give(vehicle,player,{label="First day · practice car"})
    local locked=keys and LightRP.keys.lock(vehicle,step~="vehicle_open" and step~="vehicle_close")
    if not locked then return fail("The practice keys are not ready. Please retry.") end
    Open77.vehicles.setEngine(vehicle,false)
    if step=="vehicle_close" then Open77.vehicles.setDoorOpen(vehicle,4,true) end
    local entered,reason=enter(player,s)
    if not entered then return fail(reason) end
    return entered
end
function P.onDisconnected(player) P.clear(player,true) end
function P.onCharacterLoaded(player) P.clear(player) end
AddEventHandler("onResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    for player in pairs(scenes) do
        local ok,why=P.clear(player)
        if not ok then LightRP.log("tutorial practice cleanup for %d: %s",player,why) end
    end
end)
