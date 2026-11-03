local C, E = LightRpTutorialConfig, LightRpEvents
local Tutorial = {}
LightRpTutorial = Tutorial
local state, camera, sound, frozen, hud, chat, started, targetKey, blip
local phase, introFinished, previousKey = "idle", false, nil
local introRequestAt, introRetryUntil
local waitingAt, reduced = 0, false
local function now() return Open77.time.monotonic() end
local function live()
    local c=Open77.character.state()
    return c and c.alive and c.grounded and not Open77.screen.isLoading()
end
local function send(operation,extra)
    if not state then return end
    local payload={operation=operation,key=state.key,revision=state.revision}
    for k,v in pairs(extra or {}) do if k~="operation" and k~="key" and k~="revision" then payload[k]=v end end
    return TriggerServerEvent(E.net.tutorial,payload)
end
Tutorial.send=send
function Tutorial.state() return state end
local R=C.reveal or {}
function Tutorial.publish()
    local keys={}
    for _,name in ipairs({"menu","inventory","interact","lock"}) do
        local key=LightRpConfig.keys[name]
        keys[name]=Open77.input.keyFor(key.id) or key.key
    end
    for _,name in ipairs({"skip","way"}) do
        if R[name] then keys[name]=Open77.input.keyFor(R[name].id) or R[name].key end
    end
    keys.context=Tutorial.contextKey or "ALT"
    LightRpUi.send(E.page.tutorial,{phase=phase,keys=keys})
end
-- The view goes back to the player; the body, the HUD and the voice are theirs again.
local function releaseScene()
    if sound then Open77.audio.destroy(sound); sound=nil end
    if frozen then Open77.character.setFrozen(false); frozen=false end
    if hud then if LightRpHud then LightRpHud.restoreVanilla() else Open77.hud.setVisible("all", true) end; hud=false end
    if chat~=nil then pcall(function() exports.open77_chat:setEnabled(chat) end); chat=nil end
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:tutorial",false)
    started=nil
end
local reveal
local function clearRouteDots()
    for _,dot in ipairs(reveal and reveal.dots or {}) do if dot.id then pcall(Open77.markers.remove,dot.id) end end
end
local function clearCamera()
    if camera then Open77.camera.destroy(camera); camera=nil end
    if reveal then clearRouteDots(); reveal=nil; LightRpUi.send(E.page.tutorial,{reveal=false}) end
    releaseScene()
end
local function phaseTo(value)
    if phase==value then return end
    phase=value; Tutorial.publish()
end
-- Finishing the shot is not the server's acknowledgement. Placement can still
-- be recovering when the local puppet is already alive. Retry the same guarded
-- checkpoint, without replaying the camera or holding the player's body.
local function finishIntro()
    clearCamera()
    introFinished, introRequestAt, introRetryUntil = true, nil, now()+30
    phaseTo("confirming")
end
local function confirmIntro()
    if now()>=introRetryUntil then phaseTo("intro_retry"); return end
    phaseTo("confirming")
    if not introRequestAt or now()-introRequestAt>=1 then
        introRequestAt=now(); send("intro")
    end
end
-- Where to go, in the world: a gold arrow bobbing over the objective (the
-- platform's arrow points down) and a few dots leading from the player towards
-- it, lit one after the other. Dots have no front: nothing can point the wrong way.
local lead={dots={}}
local sentDistance
local LEAD={height=2.5,dots=5,first=2.2,spacing=1.5,hideWithin=7.0,
    color={r=255,g=214,b=70,a=235},dotColor={r=255,g=214,b=70,a=200}}
local function clearLead()
    if lead.arrow then pcall(Open77.markers.remove,lead.arrow) end
    for _,id in ipairs(lead.dots) do pcall(Open77.markers.remove,id) end
    lead={dots={}}
end
local function publishDistance(metres)
    if sentDistance==metres then return end
    sentDistance=metres; LightRpUi.send(E.page.tutorial,{distance=metres or false})
end
local function updateLead()
    local objective=state and state.active and state.objective
    local markers=type(Open77.markers)=="table" and type(Open77.markers.create)=="function" and Open77.markers
    if not objective or camera or not markers or not live() then
        if lead.arrow or #lead.dots>0 then clearLead() end
        publishDistance(nil); return
    end
    local t,p,o=now(),Open77.character.state().position,objective.position
    local dx,dy=o.x-p.x,o.y-p.y
    local distance=math.sqrt(dx*dx+dy*dy)
    publishDistance(math.floor(distance+0.5))
    local top={x=o.x,y=o.y,z=o.z+LEAD.height+0.22*math.sin(t*3.2)}
    if lead.target~=objective then clearLead(); lead.target=objective end
    if not lead.arrow then
        lead.arrow=markers.create({shape="arrow",position=top,radius=0.42,height=1.0,color=LEAD.color,maxDistance=400})
    else markers.update(lead.arrow,{position=top,rotation={x=0,y=0,z=(t*70)%360}}) end
    local wanted=distance>LEAD.hideWithin and LEAD.dots or 0
    for i=#lead.dots,wanted+1,-1 do pcall(markers.remove,lead.dots[i]); lead.dots[i]=nil end
    if wanted==0 then return end
    local ux,uy=dx/distance,dy/distance
    for i=1,wanted do
        local along=LEAD.first+(i-1)*LEAD.spacing
        -- A wave runs from the player to the objective: each dot swells in turn.
        local pulse=math.max(0,math.sin(t*4.5-i*0.9))
        local radius=0.07+0.07*pulse
        local position={x=p.x+ux*along,y=p.y+uy*along,z=p.z+0.95+0.05*pulse}
        if not lead.dots[i] then
            lead.dots[i]=markers.create({shape="sphere",position=position,radius=radius,height=radius*2,color=LEAD.dotColor,maxDistance=40})
        else markers.update(lead.dots[i],{position=position,radius=radius,height=radius*2}) end
    end
end
local function clearTarget()
    if LightRpInteract then LightRpInteract.setLocal("tutorial.current",nil) end
    blip,targetKey=nil,nil
    clearLead(); publishDistance(nil)
end
local function updateTarget()
    local objective=state and state.active and state.objective
    local key=objective and (state.key..":"..state.step)
    if key==targetKey then return end
    clearTarget(); targetKey=key
    if not objective then return end
    local atContact=objective.kind=="talk"
    blip=LightRpInteract.setLocal("tutorial.current",{
        position=objective.position,radius=objective.radius,prompt=objective.label,
        passive=objective.kind=="context",
        marker=objective.kind~="context" and {shape="cylinder",radius=.5,height=.28,color={r=255,g=218,b=70,a=130},maxDistance=35} or nil,
        blip={icon=atContact and "message-circle" or "briefcase-business",sprite="objective",title=objective.label,
            description=state.hint,routable=true},
    },function()
        if LightRpUi.promptActive or LightRpUi.menuOpen or camera or not live() then return end
        -- A contact of the arrival hall talks; every other objective is a real
        -- point of the framework (shop, job desk, work site): press it for them.
        if state.step=="intro" then return end
        if objective.kind=="talk" then send("talk")
        elseif objective.interaction then TriggerServerEvent(E.net.interact,objective.interaction) end
    end)
    if blip and phase~="opening" then LightRpInteract.trackBlip(blip) end
end
-- The way to a new destination, shown before it is walked (C.reveal): the
-- camera rises behind the player, flies over the route while gold dots light
-- the ground towards the place, settles on it and blends back to the player.
-- Skip key: back at once. Way key: the same flight again.
local wanted,wantedAt,manual,previousStep
local function vec(x,y,z) return {x=x,y=y,z=z} end
local function mix(a,b,t) return vec(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t) end
local function clampTo(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function smoother(t) t=clampTo(t,0,1); return t*t*t*(t*(t*6-15)+10) end
-- Catmull-Rom between b and c; the flight is k1 -> k2 -> k3 with doubled ends.
local function spline(a,b,c,d,t)
    local t2,t3=t*t,t*t*t
    local function axis(p0,p1,p2,p3) return 0.5*(2*p1+(p2-p0)*t+(2*p0-5*p1+4*p2-p3)*t2+(3*p1-p0-3*p2+p3)*t3) end
    return vec(axis(a.x,b.x,c.x,d.x),axis(a.y,b.y,c.y,d.y),axis(a.z,b.z,c.z,d.z))
end
local function flight(k,u)
    if u<0.5 then return spline(k[1],k[1],k[2],k[3],u*2) end
    return spline(k[1],k[2],k[3],k[3],(u-0.5)*2)
end
local function horizontal(a,b) return math.sqrt((b.x-a.x)^2+(b.y-a.y)^2) end
-- Nothing else may own the player: a prompt, a menu, a dialog, the free camera, a car.
local function revealBlocked()
    local Ui=LightRpUi
    if Ui.promptActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode or Ui.creationActive then return true end
    for _,open in pairs(Ui.dialogs or {}) do if open then return true end end
    if LightRpFreecam and LightRpFreecam.isActive() then return true end
    local players=Open77.players
    return players~=nil and type(players.isInVehicle)=="function" and players.isInVehicle()==true
end
local function startReveal()
    local o,p=state.objective.position,Open77.character.state().position
    local distance=horizontal(p,o)
    local fx,fy=(o.x-p.x)/distance,(o.y-p.y)/distance
    local sx,sy=-fy,fx
    local view=type(Open77.camera.view)=="function" and Open77.camera.view() or nil
    local k1=view and view.position or vec(p.x-fx*3.5,p.y-fy*3.5,p.z+2.2)
    local side,rise=clampTo(distance*0.2,4,18),clampTo(distance*0.35,8,30)
    local k2=vec(p.x+(o.x-p.x)*0.45+sx*side,p.y+(o.y-p.y)*0.45+sy*side,math.max(p.z,o.z)+rise)
    local back=clampTo(distance*0.12,5,9)
    local k3=vec(o.x-fx*back+sx*2.5,o.y-fy*back+sy*2.5,o.z+3.2)
    local target=vec(o.x,o.y,o.z+1.4)
    local forward=view and view.forward
    local look=forward and vec(k1.x+forward.x*8,k1.y+forward.y*8,k1.z+forward.z*8) or vec(p.x,p.y,p.z+1.5)
    local fov=view and tonumber(view.fov) or 60
    local id,why=Open77.camera.create({position=reduced and k3 or k1,lookAt=reduced and target or look,fov=fov,thirdPersonBody=true})
    if not id then LightRpUi.log("tutorial reveal camera: %s",tostring(why)); return false end
    if not Open77.camera.activate(id,{blendMs=R.blendMs or 550}) then Open77.camera.destroy(id); return false end
    camera=id
    frozen=Open77.character.setFrozen(true)==true
    hud=Open77.hud.setVisible("all",false)==true
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:tutorial",true)
    -- The dots, from the player's feet to the place, each lit as the camera passes over it.
    local spacing=(R.dots and R.dots.spacing) or 3.0
    local count=math.min((R.dots and R.dots.max) or 40,math.floor(distance/spacing))
    local dots={}
    for i=1,count do
        local at=i/(count+1)
        dots[i]={at=at,position=vec(p.x+(o.x-p.x)*at,p.y+(o.y-p.y)*at,p.z+(o.z-p.z)*at+0.18)}
    end
    reveal={started=now(),phase="fly",keys={k1,k2,k3},look=look,target=target,fov=fov,dots=dots,
        fly=R.flySeconds or 4.2,hold=R.holdSeconds or 1.4}
    phaseTo("reveal")
    LightRpUi.send(E.page.tutorial,{reveal={name=state.place or state.objective.label,direction=state.direction,
        distance=math.floor(distance+0.5),index=state.index,total=state.total,durationMs=math.floor((reveal.fly+reveal.hold)*1000)}})
    return true
end
-- Back to the player: the body is free at once, the view blends home.
local function endReveal()
    if not reveal or reveal.phase=="return" then return end
    clearRouteDots(); reveal.dots={}
    local released=camera and type(Open77.camera.deactivate)=="function" and Open77.camera.deactivate({blendMs=R.returnMs or 800})
    releaseScene()
    LightRpUi.send(E.page.tutorial,{reveal=false})
    if not released then clearCamera(); phaseTo("idle"); return end
    reveal.phase,reveal.until_="return",now()+(R.returnMs or 800)/1000+0.1
end
local function updateReveal()
    local r,t=reveal,now()-reveal.started
    if r.phase=="return" then
        if now()>=r.until_ then clearCamera(); phaseTo("idle") end
        return
    end
    if t>=r.fly+r.hold then return endReveal() end
    local u=reduced and 1 or smoother(t/r.fly)
    if not reduced then
        Open77.camera.setTransform(camera,{position=flight(r.keys,u),fov=r.fov+(50-r.fov)*u})
        Open77.camera.lookAt(camera,mix(r.look,r.target,smoother(t/(r.fly*0.4))))
    end
    local lit=reduced and 1 or smoother(t/(r.fly*0.85))
    for i,dot in ipairs(r.dots) do
        if lit>=dot.at then
            local radius=0.16+0.05*math.sin(t*5-i*0.45)
            if not dot.id then
                dot.id=Open77.markers.create({shape="sphere",position=dot.position,radius=radius,height=radius*2,color=LEAD.dotColor,maxDistance=300})
            else Open77.markers.update(dot.id,{radius=radius,height=radius*2}) end
        end
    end
end
function Tutorial.cinematic() return camera~=nil end
-- Asks for the flight to the current destination; the main loop starts it when nothing else owns the player.
local function wantReveal(byKey)
    if camera then return end
    if not (R.enabled and state and state.active and state.objective and state.step~="intro") then return end
    wanted,wantedAt,manual=state.key..":"..state.step,now(),byKey==true
end
local function tryReveal()
    if wanted~=state.key..":"..state.step or not state.objective or now()-wantedAt>12 then wanted=nil; return end
    if (not manual and now()-wantedAt<(R.delay or 1.4)) or revealBlocked() then return end
    wanted=nil
    local d=horizontal(Open77.character.state().position,state.objective.position)
    if d<(manual and 3 or R.minDistance or 12) or d>(R.maxDistance or 200) then return end
    startReveal()
end

-- The opening travels C.opening; a conversation uses the shot the server
-- computed for the contact being talked to (state.camera).
local function takeCamera(opening)
    local shot=C.opening
    local talk=not opening and state and state.camera
    if not opening and not talk then return false end
    local id,why=Open77.camera.create({position=talk and talk.position or (reduced and shot.to or shot.from),
        lookAt=talk and talk.lookAt or shot.lookAt,fov=talk and talk.fov or shot.fov,thirdPersonBody=true})
    if not id then LightRpUi.log("tutorial camera: %s",tostring(why)); return false end
    camera=id
    local ok=Open77.camera.activate(camera,{blendMs=650})
    if not ok then clearCamera(); return false end
    frozen=Open77.character.setFrozen(true)==true
    hud=Open77.hud.setVisible("all",false)==true
    local called,enabled=pcall(function() return exports.open77_chat:isEnabled() end)
    if called and type(enabled)=="boolean" then
        chat=enabled; pcall(function() exports.open77_chat:setEnabled(false) end)
    end
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:tutorial",true)
    sound=Open77.audio.play2D(C.music,{volume=C.musicVolume,loop=true})
    started=now()
    return true
end
function Tutorial.bind(page)
    page:on(E.page.tutorial,function(value)
        if type(value)~="table" then return end
        if type(value.reducedMotion)=="boolean" then reduced=value.reducedMotion end
        if value.operation=="voice" then LightRpTutorialVoice.handle(value); return end
        if value.operation=="gps" then if blip then LightRpInteract.trackBlip(blip) end; return end
        if value.operation=="way" then wantReveal(true); return end
        if value.operation=="options" then LightRpUi.send(E.page.tutorial,{options=true}); return end
        -- F1 > Skip the tutorial: the page asks for confirmation before the server is told.
        if value.operation=="skip-ask" then LightRpUi.send(E.page.tutorial,{skipAsk=true}); return end
        if value.operation=="intro" then
            if state and state.active and state.step=="intro" then finishIntro() end
            return
        end
        if value.operation then send(value.operation) end
    end)
    if type(RegisterKeyMapping)~="function" then return end
    local pressed={
        skip=function() if reveal then endReveal() end end,
        way=function() if not camera then wantReveal(true) end end,
    }
    for name,fn in pairs(pressed) do
        local key=R[name]
        if key then
            local ok,effective=RegisterKeyMapping(key.id,key.name,key.key,fn)
            if not ok then LightRpUi.log("tutorial %s key mapping failed: %s",name,tostring(effective)) end
        end
    end
    AddEventHandler("open77:keybinds:changed",function() Tutorial.publish() end)
end
RegisterNetEvent(E.net.state,function(patch)
    if type(patch)~="table" then return end
    if patch.character and patch.character.status~="active" then
        state=nil; previousKey=nil; clearCamera(); clearTarget(); phaseTo("idle")
        if LightRpTutorialVoice then LightRpTutorialVoice.sync(nil) end
    end
    if not patch.tutorial then return end
    state=patch.tutorial
    if LightRpTutorialVoice then LightRpTutorialVoice.sync(state) end
    local key=state.active and (state.key..":"..state.step..":"..tostring(state.dialogue)..":"..tostring(state.revision)) or nil
    if key~=previousKey then
        previousKey=key; clearCamera(); introFinished=false; introRequestAt=nil; introRetryUntil=nil; waitingAt=now()
        phaseTo(state.active and state.step=="intro" and "waiting" or "idle")
    end
    -- A new destination, during play (not the one found on joining): show the way.
    local step=state.active and (state.key..":"..state.step) or nil
    if step~=previousStep then
        if previousStep and step and not state.dialogue then wantReveal(false) else wanted=nil end
        previousStep=step
    elseif state.dialogue then wanted=nil end
    updateTarget()
end)
CreateThread(function()
    while true do
        Wait(camera and 0 or 150)
        if state and state.active then
            if not live() then
                clearCamera(); phaseTo("waiting")
            elseif state.step=="intro" then
                if introFinished then confirmIntro()
                elseif not camera then
                    local p=Open77.character.state().position; local a=C.lobby.arrival.position
                    if (p.x-a.x)^2+(p.y-a.y)^2+(p.z-a.z)^2<100 then
                        if takeCamera(true) then phaseTo("opening") else finishIntro() end
                    elseif now()-waitingAt>30 then
                        -- Not at the hall's door (a refused placement): no scene, the guide goes on.
                        finishIntro()
                    end
                elseif started then
                    local t=math.min(1,(now()-started)/C.introSeconds)
                    local eased=t*t*(3-2*t); local a,b=C.opening.from,C.opening.to
                    if not reduced then
                        Open77.camera.setTransform(camera,{position={x=a.x+(b.x-a.x)*eased,y=a.y+(b.y-a.y)*eased,z=a.z+(b.z-a.z)*eased}})
                        Open77.camera.lookAt(camera,C.opening.lookAt)
                    end
                    if t>=1 then finishIntro();confirmIntro() end
                end
            elseif reveal then updateReveal()
            elseif state.dialogue then
                if not camera then takeCamera(false);phaseTo("conversation") end
            elseif camera then clearCamera();phaseTo("idle")
            elseif wanted then tryReveal()
            elseif phase=="waiting" then phaseTo("idle") end
        elseif camera then clearCamera();phaseTo("idle") end
    end
end)
CreateThread(function()
    while true do
        local guided=state and state.active and state.objective
        Wait(guided and 0 or 300)
        updateLead()
    end
end)
AddEventHandler("onClientResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    state=nil;clearCamera();clearTarget()
end)
