-- Exercise the real server scene lifecycle, including delayed teleports and
-- hostile/out-of-order requests. Run from the gamemode directory with Lua 5.4.
dofile("shared/events.lua")
dofile("shared/config.lua")
LightRpConfig.characters.arrivalScene.autoStart = true
local handlers, events, threads, replies, calls = {}, {}, {}, {}, {}
local now, bucket, ready, position, animation, nextId = 1000, 17, true, nil, nil, 1
local c = { key = "slot2", status = "draft", bodyFamily = "female" }
local envFailure, occupied, cleared, stopCount = false, false, {}, 0
local life, landing, failRespawn = {phase="alive"}, nil, false
LightRP = {
    db = { ready = true }, characters = { get = function() return c end },
    module = function(name, value) LightRP[name] = value; return value end,
    nowMs = function() return now end, log = function() end,
}
GetCurrentResourceName = function() return "op77_lightrp" end
RegisterNetEvent = function(name, fn) handlers[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
TriggerClientEvent = function(_, _, value) replies[#replies+1] = value end
GetPlayerRoutingBucket = function() return bucket end
SetPlayerRoutingBucket = function(_, value) bucket = value; return true end
GetPlayersInBucket = function() return occupied and {99} or {} end
CreateThread = function(fn) threads[#threads+1] = coroutine.create(fn) end
Wait = function(ms) now=now+ms; coroutine.yield() end
local function environment(_, _, _, b)
    if envFailure then return nil, "environment_unavailable" end
    calls[#calls+1] = { bucket = b }; return {}
end
Open77 = {
    ready = { isReady = function() return ready end },
    environment = {
        setTime = environment,
        setTimeFrozen = function(_, b) assert(b == 610001); return {} end,
        setWeather = function(preset, _, b) assert(preset == "sunny" and b == 610001); return {} end,
        setWeatherFrozen = function(_, b) assert(b == 610001); return {} end,
        clearBucket = function(b) cleared[#cleared+1] = b end,
    },
    players = {
        position = function() return position end,
        getLifeState = function() return life end,
        kill = function(_, options) assert(options.weapon=="lightrp:creator_arrival"); life={phase="dead"}; return true end,
        respawn = function(_, options)
            if failRespawn then return false, "placement_failed" end
            assert(options.bucket == 610001 and options.heading == LightRpConfig.characters.arrivalScene.heading)
            assert(options.position.y>LightRpConfig.characters.arrivalScene.position.y, "arrive in front of the bench collider")
            bucket, landing, life = options.bucket, options.position, {phase="respawnpending"}
            return true
        end,
    },
    animations = {
        current = function() return animation end,
        playAt = function(_, profile, p, heading, options)
            assert(profile == "chair" and options.loop and p == LightRpConfig.characters.arrivalScene.position)
            animation = { playbackId = nextId }; nextId = nextId+1; return animation
        end,
        stop = function(_, id) assert(animation and animation.playbackId == id); animation = nil; stopCount = stopCount+1 end,
    },
}
dofile("server/modules/creator.lua")
local function send(op) source = 1; now = now+300; handlers[LightRpEvents.net.creator]({operation=op}) end
local function resume() local ok, why = coroutine.resume(threads[#threads]); assert(ok, why) end
local function land() position=landing; life={phase="alive"}; resume() end
c.status = "active"; send("start"); assert(#threads == 0)
c.status = "draft"; c.bodyFamily = nil; send("start"); assert(#threads == 0, "native body required")
c.bodyFamily = "female"; ready = false; send("start"); assert(#threads == 0)
ready = true; occupied = true; send("start"); assert(replies[#replies].phase == "error" and bucket == 17)
occupied = false; envFailure = true; send("start"); assert(replies[#replies].phase == "error" and bucket == 17)
envFailure = false; send("start"); assert(replies[#replies].phase == "preparing")
send("start"); assert(#threads == 1, "duplicate start cannot duplicate placement")
send("seat"); assert(not animation, "cannot seat before placement")
resume(); assert(bucket == 610001 and LightRP.creator.isPreparing(1)); resume()
assert(replies[#replies].phase == "preparing", "wait for native streamed respawn")
land(); assert(replies[#replies].phase == "placed" and not LightRP.creator.isPreparing(1))
position = {x=0,y=0,z=0}; send("seat"); assert(not animation, "client cannot spoof a distant seat")
position = LightRpConfig.characters.arrivalScene.position
send("seat"); assert(animation and nextId == 2)
send("seat"); assert(nextId == 2, "duplicate seat does not restart an idle animation")
send("pause"); assert(not animation and bucket == 610001, "native editor keeps private daylight")
send("seat"); assert(not animation, "late seat request cannot interrupt native editor")
send("start"); send("seat"); assert(nextId == 3)
LightRP.creator.stop(1); assert(bucket == 17 and not animation and replies[#replies].phase == "closed")
assert(cleared[#cleared] == 610001 and stopCount == 2)
send("start"); resume(); LightRP.creator.stop(1); local count = #replies; resume()
assert(#replies == count and bucket == 17, "late teleport completion cannot resurrect the scene")
send("start"); resume(); land(); send("seat")
events.onResourceStop("op77_lightrp"); assert(bucket == 17 and not animation)
failRespawn=true; send("start"); resume(); assert(replies[#replies].phase=="error" and bucket==17)
failRespawn=false; send("start"); resume(); now=now+31000; resume()
assert(replies[#replies].phase=="error" and bucket==17,"streaming timeout restores private environment")
print("PASS: creator isolation, native/readiness gates, retries, duplicate/range validation, editor pause/resume, cleanup and late placement")
