local E=LightRpEvents
local active,actionId,playbackId
LightRpItemWork={isActive=function() return active~=nil or playbackId~=nil end}
local function clear()
    active,playbackId=nil,nil
    local id=actionId; actionId=nil
    if id then LightRpActions.cancel(id) end
end
RegisterNetEvent(E.net.workCycle,function(p)
    if type(p)~="table" then return end
    if p.cancel then clear(); return end
    if type(p.token)~="string" or type(p.durationMs)~="number" then return end
    local sameAnimation=playbackId and playbackId==p.playbackId
    clear(); active=p.token; playbackId=p.playbackId
    local token=p.token
    CreateThread(function()
        -- Stationary workspots own temporary third person. Let native mounting
        -- start before the WebUI takes keyboard focus; keep the workspot alive
        -- across batches instead of remounting / flipping the camera each time.
        if p.playbackId and not sameAnimation then Wait(900) end
        if active~=token then return end
        local id,why=LightRpActions.progress({label=p.label,description=p.description,icon=p.icon,durationMs=p.durationMs,cancellable=true},function(result)
            if active~=token then return end
            active,actionId=nil,nil
            if result.status~="success" then
                LightRpUi.log("item work interrupted: %s",tostring(result.reason))
                if playbackId then Open77.animations.cancel(playbackId) end
                playbackId=nil
            end
            TriggerServerEvent(E.net.workFinish,{token=token,status=result.status})
        end)
        actionId=id
        if not id then
            LightRpUi.log("item work progress unavailable: %s",tostring(why))
            active,playbackId=nil,nil; TriggerServerEvent(E.net.workFinish,{token=token,status="cancelled"})
        end
    end)
end)
AddEventHandler("onAnimationPlaybackFailed",function(_,id,reason)
    if not playbackId or playbackId~=id then return end
    local token=active
    LightRpUi.log("item work animation failed: %s",tostring(reason))
    clear()
    if token then TriggerServerEvent(E.net.workFinish,{token=token,status="cancelled"}) end
end)
RegisterNetEvent(E.net.workGps,function(p)
    if type(p)~="table" or type(p.position)~="table" or type(p.id)~="string" then return end
    local blip=LightRpInteract.setLocal("work.gps",{position=p.position,radius=p.radius,prompt=p.label,
        blip={icon=p.icon,sprite="objective",title=p.label,routable=true,description="Press E to work. Escape stops the loop."}},function()
        if not LightRpUi.promptActive and not LightRpUi.menuOpen and not LightRpActions.isActive() then TriggerServerEvent(E.net.interact,p.id) end
    end)
    if blip then LightRpInteract.trackBlip(blip) end
end)
AddEventHandler("onClientResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    if playbackId then Open77.animations.cancel(playbackId) end
    clear(); LightRpInteract.setLocal("work.gps",nil)
end)
