-- Raid client: strike telegraphs (native markers + effects), the intro's shots and beats, music and cleanup.
dofile("shared/events.lua");dofile("shared/config.lua")
local E=LightRpEvents
local clock,threads,timers,net,events={},{},{},{},{}
clock.ms=0
local function step(n) for _=1,n or 1 do clock.ms=clock.ms+16
    for i=#timers,1,-1 do local t=timers[i] if clock.ms>=t.at then table.remove(timers,i);t.fn() end end
    for _,thread in ipairs(threads) do if coroutine.status(thread)~="dead" then local ok,why=coroutine.resume(thread);assert(ok,why) end end end end
local function seconds(s) step(math.ceil(s*1000/16)) end
GetGameTimer=function() return clock.ms end
GetCurrentResourceName=function() return "op77_lightrp" end
AddEventHandler=function(name,fn) events[name]=fn end
RegisterNetEvent=function(name,fn) net[name]=fn end
TriggerEvent=function() end
local toServer={}
TriggerServerEvent=function(name) toServer[#toServer+1]=name end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
SetTimeout=function(ms,fn) timers[#timers+1]={at=clock.ms+ms,fn=fn} end
RegisterKeyMapping=function() return true end
local page={}
LightRpUi={log=function() end,send=function(name,payload) page[#page+1]={name=name,payload=payload};return true end}
local markers,nextId,vfx,sounds,cam,shakes={},0,{},{},nil,{}
local frozen,hud=false,true
screenLoading=true
local function id() nextId=nextId+1;return tostring(nextId) end
Open77={
    time={monotonic=function() return clock.ms/1000 end},
    markers={create=function(o) local h=id();markers[h]={shape=o.shape,radius=o.radius,height=o.height,color=o.color,position=o.position};return h end,
        update=function(h,p) assert(markers[h],"update of a removed marker");assert(p.color==nil,"no colour animation");for k,v in pairs(p) do markers[h][k]=v end;return true end,
        remove=function(h) markers[h]=nil;return true end},
    vfx={play=function(name,o) local h=id();vfx[h]={name=name,position=o.position,duration=o.duration}
        if (o.duration or 0)>0 then SetTimeout(o.duration*1000,function() vfx[h]=nil end) end;return h end,stop=function(h) vfx[h]=nil;return true end},
    audio={play2D=function(file,o) local h=id();sounds[h]={file=file,volume=o.volume,loop=o.loop};return h end,
        setVolume=function(h,v) if sounds[h] then sounds[h].volume=v end;return true end,destroy=function(h) sounds[h]=nil;return true end},
    camera={create=function(o) cam={position=o.position,fov=o.fov,held=false};return 7 end,
        activate=function() cam.held=true;return true end,deactivate=function() cam.held=false;return true end,
        destroy=function() cam=nil;return true end,
        setTransform=function(_,pose) cam.position,cam.fov=pose.position,pose.fov;return true end,
        lookAt=function(_,p) cam.look=p;return true end,
        shake=function(_,preset,amp) shakes[#shakes+1]={preset=preset,amp=amp};return true end},
    character={state=function() return {alive=true,attached=true,position={x=-2045,y=-2405,z=-7.4}} end,
        setFrozen=function(v) frozen=v;return true end},
    hud={setVisible=function(_,v) hud=v;return true end},
    -- the game's sliders (Settings > Sound): master 5, music 50, SFX 100, one meta row as the bridge sends it
    settings={request=function(group) assert(group=="/audio/volume");return true end,
        values=function() return {{name="MasterVolume",type="meta",options={"Master"}},{name="MasterVolume",type="Int",value=5,min=0,max=100},
            {name="MusicVolume",type="Int",value=50,min=0,max=100},{name="SfxVolume",type="Int",value=100,min=0,max=100}} end},
    session={isPauseMenuOpen=function() return false end},
    screen={isLoading=function() return screenLoading end},
}
dofile("client/core/raid.lua")
local function count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
local function send(p) net[E.net.raid](p) end

-- Loud sounds were the complaint: the raid follows the game's sliders (master 5 here),
-- and its first sound waits for them to be read.
send({phase="ready",sound="raid_alarm"})
assert(count(sounds)==0,"the first sound waits for the sliders")
seconds(1.6)
local alarm for _,s in pairs(sounds) do alarm=s end
-- loading: nothing is reported until the loading screen is gone and the body has stood 3 s in the arena
local function loadedReports() local n=0 for _,e in ipairs(toServer) do if e==E.net.raidLoaded then n=n+1 end end return n end
send({phase="ready",loaded=false,arena={x=-2044.4,y=-2406.2,z=-7.4}})
seconds(5)
assert(loadedReports()==0,"still loading: no report")
screenLoading=false
seconds(2)
assert(loadedReports()==0,"settling")
seconds(1.5)
assert(loadedReports()==1,"loaded reported after 3 s in the arena")
send({phase="ready",loaded=true,arena={x=-2044.4,y=-2406.2,z=-7.4}})
seconds(3)
assert(loadedReports()==1,"no more reports once the server agreed")
assert(alarm and math.abs(alarm.volume-0.64*math.sqrt(0.05))<1e-6,"alarm x sqrt(master x SFX): "..tostring(alarm and alarm.volume))

-- A barrage: three markers per spot over the game's missile indicator; the ring closes, the wall rises, all gone at impact.
local boss={x=-2046.99,y=-2406.78,z=-7.37}
send({phase="fight",strikes={{x=-2040,y=-2400,z=-7.4,radius=4.5,delayMs=2200,kind="barrage"},{x=-2050,y=-2410,z=-7.4,radius=4.5,delayMs=2200,kind="barrage"}}})
assert(count(markers)==6,"three markers per spot")
local rings,walls=0,0
for _,m in pairs(markers) do
    if m.shape=="ring" then rings=rings+1 elseif m.shape=="cylinder" then walls=walls+1 end
    assert(m.color.r==255 and m.color.g<60,"barrage is red")
    assert(math.abs(m.position.z-(-7.35))<0.01,"just above the ground")
end
assert(rings==4 and walls==2)
local indicator=0 for _,v in pairs(vfx) do if v.name:find("q114_missile_barage_indicator",1,true) then indicator=indicator+1 end end
assert(indicator==2,"the game's indicator under every spot")
seconds(1.2)
local closing,wall
for _,m in pairs(markers) do
    if m.shape=="ring" and m.radius<4.5 then closing=m end
    if m.shape=="cylinder" then wall=m end
end
assert(closing and closing.radius>0.3 and closing.radius<4.4,"the inner ring closes in")
assert(wall.height>0.05,"the wall rises")
seconds(1.1)
assert(count(markers)==0,"gone when the blast lands")

-- The purge is cyan, charges with the EMP and discharges outward before it goes.
send({phase="fight",strikes={{x=boss.x,y=boss.y,z=boss.z,radius=7.5,delayMs=1600,kind="purge"}}})
local emp=false for _,v in pairs(vfx) do if v.name=="electric.emp.big" then emp=true end end
assert(emp and count(markers)==3)
for _,m in pairs(markers) do assert(m.color.g>200 and m.color.r<60,"purge is cyan") end
seconds(1.7)
local snapped
for _,m in pairs(markers) do if m.shape=="ring" then snapped=m end end
assert(count(markers)==2 and snapped and snapped.radius<7.5*1.3,"discharging: edge dropped, ring snapping out")
seconds(0.4)
assert(count(markers)==0)

-- The intro: the music starts with it; cuts, shakes and the game's effects on the timeline; the view comes back.
send({phase="intro",sound="raid_alarm",music={file="assets/audio/raid_ost.mp3",volume=0.35},
    intro={boss=boss,arena={x=-2044.4,y=-2406.2,z=-7.4},entry={x=-1965.8,y=-2503.4,z=28.8},durationMs=12000,difficulty="STANDARD",operators=1}})
local music for _,s in pairs(sounds) do if s.loop then music=s end end
local level=0.35*math.sqrt(0.05*0.5)
assert(music and math.abs(music.volume-level)<1e-6,"music from the first shot, x sqrt(master x music): "..tostring(music and music.volume))
step(10)
assert(math.abs(music.volume-level)<1e-6,"the fade loop keeps the game's mix")
assert(cam and cam.held and frozen and hud==false)
step(2)
local first=cam.position
-- the operator stands next to the machine: the shots are built from the arena entrance instead
local fx,fy=first.x-boss.x,first.y-boss.y
assert(math.sqrt(fx*fx+fy*fy)>15,"the approach starts away from the machine")
seconds(12*0.2)
local close=cam.position
assert(math.sqrt((close.x-boss.x)^2+(close.y-boss.y)^2)<8 and cam.fov<=30,"close-up after the cut")
seconds(12*0.18)
local names={}
for _,v in pairs(vfx) do names[v.name]=true end
assert(names["cyber.emp_blast"] and names["sparks.burst.large"],"the wake-up effects")
local landing=false for n in pairs(names) do if n:find("smasher_land",1,true) then landing=true end end
assert(landing,"the landing effect at its feet")
assert(#shakes>=2 and shakes[1].preset=="explosion")
seconds(12*0.65)
assert(not cam or not cam.held,"the view is back")
assert(not frozen and hud==true)

-- hits on the Chimera are relayed (once per frame), hits on anything else are not
local function hits() local n=0 for _,e in ipairs(toServer) do if e==E.net.raidHit then n=n+1 end end return n end
send({phase="fight",bossId="77"})
events["open77:npcHit"]("77");events["open77:npcHit"]("77")
assert(hits()==1,"one hit per frame")
step(3);events["open77:npcHit"]("77");assert(hits()==2)
step(3);events["open77:npcHit"]("12");assert(hits()==2,"another NPC is not the boss")

-- The end fades the music out; stopping the resource releases everything.
send({phase="fight",strikes={{x=-2040,y=-2400,z=-7.4,radius=4.5,delayMs=2200,kind="barrage"}}})
send({phase="ended",result="victory"})
seconds(1)
local still=false for _,s in pairs(sounds) do if s.loop then still=true end end
assert(not still,"music faded out")
events.onClientResourceStop("op77_lightrp")
assert(count(markers)==0 and count(vfx)==0)
print("PASS: raid client (barrage/purge telegraphs, intro shots and beats, music, cleanup)")
