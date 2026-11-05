-- Native APIs are mocked here; the in-game capture is the visual proof.
dofile("shared/events.lua"); dofile("shared/config.lua")
LightRpConfig.characters.arrivalScene.autoStart = true
LightRpConfig.characters.arrivalScene.bench = "furniture.bench.outdoor"
local threads, events, net, page, sent, requests = {}, {}, {}, {}, {}, {}
local now, opened, loading, frozen, hud, chat = 0, false, false, false, true, true
local inWorkspot = true
local standAt, lastCreate = nil, nil
local cameras, props, sounds, nextId, transforms = {}, {}, {}, 0, {}
local function id(set) nextId=nextId+1; set[nextId]=true; return nextId end
CreateThread = function(fn) threads[#threads+1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerServerEvent = function(_, value) requests[#requests+1]=value.operation; return true end
LightRpUi = { send=function(_,value) sent[#sent+1]=value end, log=function() end,
    setMenuOpen=function() end, setPromptFocus=function() end }
exports = { open77_chat = { isEnabled=function() return chat end, setEnabled=function(_,v) chat=v end } }
Open77 = {
    time={monotonic=function() return now end},
    appearance={isOpen=function() return opened end},
    screen={isLoading=function() return loading end},
    animations={current=function(entity) assert(entity==0); return inWorkspot and "sit_chair_lean180__2h_on_lap__01__long__01" or nil end},
    character={setFrozen=function(v) frozen=v; return true end,
        state=function() return {grounded=true,inWorkspot=inWorkspot,yaw=90,position=standAt or LightRpConfig.characters.arrivalScene.position} end},
    hud={setVisible=function(_,v) hud=v; return true end},
    props={create=function(d) assert(d.model=="furniture.bench.outdoor"); return id(props) end, remove=function(i) props[i]=nil end},
    audio={
        play2D=function(asset,o) assert(asset:match('cloudy%-day.mp3$') and o.volume>=0 and o.volume<=.12 and o.loop); return id(sounds) end,
        destroy=function(i) sounds[i]=nil end,
        setVolume=function(i,v) assert(sounds[i] and v>=0 and v<=0.12); sounds[i]=v end,
    },
    camera={
        create=function(d) assert(d.thirdPersonBody and d.position.z<d.lookAt.z); lastCreate=d; return id(cameras) end,
        activate=function() return true, {await=function() return true end} end,
        destroy=function(i) cameras[i]=nil end,
        setTransform=function(i,d) assert(cameras[i]); transforms[#transforms+1]=d end,
        lookAt=function(i) assert(cameras[i]) end,
    },
}
dofile("client/core/creator.lua")
local C = LightRpCreator
C.bind({on=function(_,name,fn) page[name]=fn end})
local function tick(dt) now=now+(dt or .1); local ok,why=coroutine.resume(threads[1]); assert(ok,why) end
local function relay(phase) net[LightRpEvents.net.creator]({phase=phase}) end
C.sync({status="draft",key="default",appearanceTracked=true})
tick(); tick(4); assert(#requests==0,"native body selection is never skipped")
C.sync({status="draft",key="default",appearanceTracked=true,bodyFamily="female"})
tick(4); assert(requests[#requests]=="start")
relay("preparing"); relay("placed"); loading=true; tick(2); assert(requests[#requests]=="start")
loading=false; tick(); assert(requests[#requests]=="seat")
relay("seated"); tick(1.2)
assert(sent[#sent].phase=="ready" and frozen and not hud and not chat)
assert(next(cameras) and next(props) and next(sounds))
tick(); tick(); assert(#transforms>0)
page[LightRpEvents.page.creator]({shot="background",muted=true,reducedMotion=true})
tick(2); local last=transforms[#transforms].position; tick(1)
assert(last.x==transforms[#transforms].position.x and last.z==transforms[#transforms].position.z,"reduced motion holds the frame")
local _,volume=next(sounds); assert(volume==0,"mute does not depend on CEF autoplay")
C.editor(true); assert(not next(cameras) and not next(props) and not next(sounds) and not frozen and hud and not chat)
relay("seated"); assert(not next(cameras),"late server reply cannot steal the native editor camera")
C.editor(false); tick(4); assert(requests[#requests]=="start")
relay("placed"); tick(1); relay("seated"); tick(1.2)
assert(next(cameras))
C.sync({status="active",key="default"}); assert(not next(cameras) and not frozen and chat and hud)
C.sync({status="draft",key="slot2",appearanceTracked=false}); tick(4)
relay("placed"); tick(1); relay("seated"); tick(1.2)
events.onClientResourceStop("op77_lightrp")
assert(not next(cameras) and not next(props) and not next(sounds) and not frozen and hud and chat)
relay("placement"); assert(C.isPlacing())
net[LightRpEvents.net.creator .. ":preview"]({position={x=0,y=0,z=0},heading=0,
    shot={x=-1.5,y=3.6,z=.4,aimX=0,aimZ=1.2,fov=48}})
tick(1); assert(next(cameras) and next(sounds) and not hud and not chat, "author preview survives the tick")
relay("placement"); assert(not next(cameras) and not next(sounds) and hud and chat, "walk restores the camera and HUD")
relay("placement_closed"); assert(not C.isPlacing())
relay("placed"); tick(1); inWorkspot=false; relay("seated"); tick(2)
assert(not next(cameras), "the native pose is waited for a moment")
tick(1.5); tick(); assert(next(cameras) and sent[#sent].phase=="ready", "seated by the server without the native pose: shown anyway")
-- off the seat during the scene: the seat is asked again, the scene stays on screen
tick(2.5); tick(1); tick(3.2)
assert(next(cameras) and sent[#sent].phase=="ready", "a lost seat keeps the scene on screen")
assert(requests[#requests]=="seat", "a lost seat asks the seat again")
inWorkspot=true

local function fresh(key, body)
    C.sync({status="active",key="old"}); C.sync({status="draft",key=key,bodyFamily=body,appearanceTracked=true})
    assert(not next(cameras))
end
-- the server refuses the scene: shown where the body stands, framed on the body
standAt={x=100,y=200,z=5}
fresh("slot3","male"); tick(4); assert(requests[#requests]=="start")
net[LightRpEvents.net.creator]({phase="error",error="occupied"}); tick(); tick()
assert(next(cameras) and sent[#sent].phase=="ready", "a server error shows the scene anyway")
assert(math.abs(lastCreate.lookAt.x-100)<3 and math.abs(lastCreate.lookAt.y-200)<3, "framed on the body, not the bench")
-- the server never answers the start (readiness gate): shown after the deadline
fresh("slot4","female"); tick(4); tick(4); tick(1.5); assert(not next(cameras) and sent[#sent].phase~="ready")
tick(4); tick(2); tick(); tick(); assert(next(cameras) and sent[#sent].phase=="ready", "no answer to the start: shown anyway")
-- the arrival never settles (streamed respawn lost): shown after the deadline
fresh("slot5","female"); tick(4); relay("preparing"); tick(19); assert(not next(cameras))
tick(2); tick(); tick(); assert(next(cameras) and sent[#sent].phase=="ready", "a stuck arrival is shown anyway")
-- the body record never reaches the client: shown after the deadline, no start asked
fresh("slot6",nil); local n=#requests; tick(); tick(16); tick(); tick()
assert(next(cameras) and sent[#sent].phase=="ready" and #requests==n, "a draft without its body still sees the scene")
-- the camera itself refused: the cover goes anyway (the game's own view)
local create=Open77.camera.create; Open77.camera.create=function() return nil, "camera_busy" end
fresh("slot7","male"); net[LightRpEvents.net.creator]({phase="error"}); tick(); tick()
assert(not next(cameras) and sent[#sent].phase=="ready", "no camera at all: never a black screen")
Open77.camera.create=create
print("PASS: native handoff, loading gate, low-angle camera, movement controls, audio/mute, cleanup, slot change, resource stop and the scene always shown (pose, refusal, silence, stuck arrival, missing body, camera refused)")
