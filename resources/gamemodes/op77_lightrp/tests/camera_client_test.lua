-- Camera: the dynamic shoulder default, /camchange (cycle, sides, reset, memory) and /cinematic.
dofile("shared/events.lua");dofile("shared/config.lua")
local E=LightRpEvents
local threads,net,notices={}, {}, {}
local function step(n) for _=1,n or 1 do
    for _,t in ipairs(threads) do if coroutine.status(t)~="dead" then local ok,why=coroutine.resume(t);assert(ok,why) end end end end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
RegisterNetEvent=function(name,fn) net[name]=fn end
LightRpUi={characterReady=false,send=function(name,p) if name==E.page.notice then notices[#notices+1]=p end;return true end,log=function() end}
local kvp,config,perspective,cinematic,shakes={}, nil, "first", false, 0
Open77={
    kvp={get=function(k,d) local v=kvp[k];if v==nil then return d end;return v end,set=function(k,v) kvp[k]=v;return true end,delete=function(k) kvp[k]=nil;return true end},
    camera={configureThirdPerson=function(o)
            if o.style then config={style=o.style,shoulder=o.shoulder or "right",transition=o.transition}
            elseif config then for k,v in pairs(o) do config[k]=v end else return false,"camera_style_not_owned" end
            return true end,
        resetThirdPerson=function() config=nil;return true end,
        shakeThirdPerson=function() shakes=shakes+1;return true end},
    perspective={set=function(m) perspective=m;return true end},
    hud={setCinematic=function(on) cinematic=on;return true end},
}
local function load() threads={};dofile("client/core/camera.lua") end
local function last() return notices[#notices] end
load()

-- nothing is claimed before the character is in the world; then the shoulder style and third person, once
step(3);assert(config==nil)
LightRpUi.characterReady=true;step(2)
assert(config and config.style=="shoulder" and config.shoulder=="right","dynamic shoulder by default")
assert(perspective=="third","the session starts in third person")
-- once: F7 back to first person is the player's choice
perspective="first";step(5);assert(perspective=="first")

-- /camchange cycles, switches to third person and is remembered
net[E.net.cameraChange]("")
assert(config.style=="centered" and perspective=="third" and kvp["camera:style"]=="centered")
net[E.net.cameraChange]("classic");assert(config.style=="classic")
net[E.net.cameraChange]("shoulder");net[E.net.cameraChange]("left")
assert(config.shoulder=="left" and kvp["camera:shoulder"]=="left")
net[E.net.cameraChange]("shake");assert(shakes==1)
net[E.net.cameraChange]("nope");assert(last().kind=="error")

-- the choice survives a reload (same machine, same server)
config=nil;load();step(2)
assert(config.style=="shoulder" and config.shoulder=="left","remembered style and shoulder")

-- reset releases it, and stays released
net[E.net.cameraChange]("reset");assert(config==nil and kvp["camera:style"]=="none")
config=nil;perspective="first";load();step(3);assert(config==nil,"a released style is not claimed again")
assert(perspective=="third","third person at the start even without a style")
net[E.net.cameraChange]("left");assert(last().kind=="error","no side without a style")

-- /cinematic toggles; a screen that borrows the claim gives the player's back
net[E.net.cameraCinematic]("");assert(cinematic==true and LightRpCamera.cinematic)
cinematic=false -- the vehicle workshop releasing its own use of the claim
LightRpCamera.restoreCinematic();assert(cinematic==true,"the player's cinematic comes back")
net[E.net.cameraCinematic]("off");assert(cinematic==false)
LightRpCamera.restoreCinematic();assert(cinematic==false)
print("PASS: camera (shoulder default, camchange cycle/sides/shake/reset, memory, cinematic + restore)")
