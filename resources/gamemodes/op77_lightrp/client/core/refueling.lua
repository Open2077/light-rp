local E, C = LightRpEvents, LightRpConfig.fuel
local active
LightRpRefueling = {isActive=function() return active~=nil end}
RegisterNetEvent(E.net.fuelSnapshot,function(p)
    if LightRpUi.dialogs.fuel then LightRpUi.send("lightrp:ui:fuel:snapshot",p) end
end)
local function finish(a,status)
    if active~=a or a.sent then return end
    a.sent=true
    TriggerServerEvent(E.net.fuelFinish,{token=a.token,status=status})
    if status~="success" and a.playbackId then Open77.animations.cancel(a.playbackId) end
end
local function clear(a)
    if active~=a then return end
    active=nil
    LightRpInteract.setLocal("fuel.current",nil)
    LightRpUi.send("lightrp:ui:fuel:state",{phase="finished"})
    if a.actionId then LightRpActions.cancel(a.actionId) end
end
RegisterNetEvent(E.net.fuel,function(p)
    if type(p)~="table" or type(p.token)~="string" then return end
    if p.phase=="finished" then if active and active.token==p.token then clear(active) end; return end
    if p.phase=="prepare" then
        if active then
            if active.token~=p.token then TriggerServerEvent(E.net.fuelFinish,{token=p.token,status="cancelled"}) end
            return
        end
        local a={token=p.token,expires=GetGameTimer()+8000}; active=a
        CreateThread(function()
            if not LightRpUi.ready or not LightRpUi.characterReady or LightRpActions.isActive() then finish(a,"cancelled"); return end
            LightRpUi.send(E.page.dialogClose,{kind="fuel"})
            LightRpUi.send(E.page.dialogClose,{kind="inventory"})
            local deadline=GetGameTimer()+2500
            while active==a and (LightRpUi.dialogs.fuel or LightRpUi.dialogs.inventory or LightRpUi.promptActive) and GetGameTimer()<deadline do Wait(50) end
            if active~=a or a.sent then return end
            if LightRpUi.menuOpen or LightRpUi.promptActive then finish(a,"cancelled"); return end
            for _, open in pairs(LightRpUi.dialogs) do if open then finish(a,"cancelled"); return end end
            TriggerServerEvent(E.net.fuelReady,{token=a.token})
        end)
        return
    end
    local a=active
    if not a or a.token~=p.token or a.sent then return end
    if p.phase=="approach" then
        a.expires=GetGameTimer()+p.expiresMs+2000
        local key=LightRpConfig.keys.animationStop
        p.cancelKey=Open77.input.keyFor(key.id) or key.key
        LightRpUi.send("lightrp:ui:fuel:state",p)
        LightRpInteract.setLocal("fuel.current",{position=p.position,radius=C.vehicleUseRange,prompt="Start refuelling · Engine off"},function()
            if a.sent or LightRpUi.promptActive or LightRpUi.menuOpen then return end
            local t=GetGameTimer(); if a.pressed and t-a.pressed<700 then return end; a.pressed=t
            TriggerServerEvent(E.net.fuelReady,{token=a.token})
        end)
        return
    end
    if p.phase~="play" or a.playbackId then return end
    a.playbackId=p.playbackId; a.expires=GetGameTimer()+p.durationMs+14000
    LightRpInteract.setLocal("fuel.current",nil)
    LightRpUi.send("lightrp:ui:fuel:state",{phase="finished"})
    CreateThread(function()
        Wait(900)
        if active~=a or a.sent then return end
        -- Input stays with the game so the camera turns (as eating, 2026-11-03); the server
        -- cancels if the player walks off (0.8 m from where they started) or the car moves.
        a.actionId=LightRpActions.progress({label=p.label,description=string.format("%s · %.1f L · Stay still",p.itemLabel,p.litres),
            durationMs=p.durationMs,icon="fuel",cancellable=true,allowMovement=true},function(result) finish(a,result.status) end)
        if not a.actionId then finish(a,"cancelled") end
    end)
end)
function LightRpRefueling.cancel()
    if active then finish(active,"cancelled") end
end
AddEventHandler("onAnimationPlaybackFailed",function(_,id)
    if active and active.playbackId==id then finish(active,"cancelled") end
end)
CreateThread(function()
    while true do
        Wait(200)
        local a=active
        if a and (not LightRpUi.characterReady or GetGameTimer()>a.expires) then finish(a,"cancelled"); clear(a) end
    end
end)
AddEventHandler("onClientResourceStop",function(name)
    if name~=GetCurrentResourceName() or not active then return end
    local a=active; finish(a,"cancelled"); clear(a)
end)
