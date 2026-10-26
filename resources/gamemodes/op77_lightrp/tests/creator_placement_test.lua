dofile("shared/events.lua")
dofile("shared/config.lua")
local command, sample, handlers, sent = nil, nil, {}, {}
local now, acl, ready, bucket = 0, true, true, 17
local at, animation, saved = {x=1,y=2,z=3}, nil, nil
LightRP = {
    module = function(name, t) LightRP[name]=t; return t end,
    creator = { stop=function() end },
    command = function(_, opts, fn) assert(opts.restricted); command=fn end,
    nowMs = function() return now end,
    reply = function(_, _, ok, text) sent[#sent+1]={ok=ok,text=text} end,
    log = function() end,
}
RegisterNetEvent = function(_, fn) sample=fn end
AddEventHandler = function(n, fn) handlers[n]=fn end
GetCurrentResourceName = function() return "op77_lightrp" end
GetPlayerRoutingBucket = function() return bucket end
SetPlayerRoutingBucket = function(_, b) bucket=b; return true end
GetPlayersInBucket = function() return {} end
local nonce
TriggerClientEvent = function(event, _, value)
    if event:match(":sample$") then nonce=value end
end
Open77 = {
    acl={isAllowed=function() return acl end}, ready={isReady=function() return ready end},
    environment={setTime=function() return true end,setTimeFrozen=function() return true end,
        setWeather=function() return true end,setWeatherFrozen=function() return true end, clearBucket=function() end},
    players={position=function() return at end},
    animations={
        current=function() return animation end,
        stop=function(_, id) assert(id==animation.playbackId); animation=nil; return true end,
        playAt=function(_, profile, p, yaw, opts)
            assert(profile=="chair" and opts.loop and opts.clip)
            animation={playbackId=now}; at={x=p.x,y=p.y,z=p.z}; return animation
        end,
    },
    kvp={set=function(key, value) assert(key=="creator.placement.draft"); saved=value; return true end},
}
dofile("server/modules/creator_placement.lua")
local function run(...) now=now+1000; return command(1,{...}) end
source=1
acl=false; assert(not run()); assert(not LightRP.creatorPlacement.has(1))
acl=true; ready=false; assert(not run())
ready=true; assert(run()); assert(bucket==620001 and LightRP.creatorPlacement.has(1))
assert(not run("save")); assert(run("sit"))
sample(nonce+1,{position=at,yaw=30,grounded=true}); assert(not animation)
sample(nonce,{position=at,yaw=0/0,grounded=true}); assert(not animation)
assert(run("sit")); sample(nonce,{position=at,yaw=30,grounded=false}); assert(not animation)
assert(run("sit")); sample(nonce,{position=at,yaw=30,grounded=true}); assert(animation)
assert(run("move","0","0","0.05")); assert(math.abs(at.z-3.05)<.00001)
assert(not run("move","0","0","100")); assert(not run("turn","nan"))
assert(run("turn","15")); assert(run("save")); assert(saved:find("heading = 45.000000",1,true))
assert(run("preview", "3.6", "-1.5", ".4", "1.2", "48"))
assert(not run("preview", "1000")); assert(not run("preview", "nan"))
assert(run("walk")); assert(not animation); assert(not run("save"))
assert(run("sit")); assert(run("stop")); assert(bucket==17)
sample(nonce,{position=at,yaw=30,grounded=true}); assert(not animation)
assert(run()); handlers.onResourceStop("op77_lightrp"); assert(bucket==17)
print("creator placement: ACL, sampling, nudge, save and cleanup OK")
