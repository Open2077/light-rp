LightRpTutorialVoice = {}
local V=LightRpTutorialVoice
local active,generation,state,observed,lastDevice=false,0,nil,0,nil
local rangeKey="F11"
local function call(op,value)
    if not Open77.voice or type(Open77.voice.setup)~="function" then
        return nil,"Update your Open77 client to use guided voice setup. You can skip this part and use Settings > Voice."
    end
    return Open77.voice.setup(op,value)
end
local function publish(value,why,clearError)
    if type(value)=="table" then
        if value.inputDevice~=lastDevice then observed=0;lastDevice=value.inputDevice end
        if value.testing and (tonumber(value.level) or 0)>.025 then observed=observed+1 end
        value.signalDetected=observed>=2
        value.rangeKey=rangeKey
    end
    LightRpUi.send(LightRpEvents.page.tutorial,{voice=type(value)=="table" and value or nil,voiceError=why and tostring(why) or clearError and "" or nil})
end
function V.stop()
    active=false; generation=generation+1;observed=0;lastDevice=nil
    call("end")
end
function V.sync(nextState)
    state=nextState
    if active and (not state or not state.active or state.step~="voice") then V.stop() end
end
function V.handle(value)
    if value.action=="end" then V.stop(); return end
    if not state or not state.active or state.step~="voice" then return end
    local op=value.action
    if op=="begin" then
        generation=generation+1; local token=generation
        local rangePromise=Open77.exports.call("open-voice","getState")
        if rangePromise then local range=rangePromise:await(); if type(range)=="table" and type(range.cycleKey)=="string" then rangeKey=range.cycleKey end end
        local result,why=call("begin")
        if token~=generation then return end
        active=result~=nil; publish(result,why,true); return
    end
    if op=="skip" or op=="configured" then
        V.stop()
        TriggerServerEvent(LightRpEvents.net.tutorial,{operation=op=="skip" and "voice-skip" or "voice-configured",key=state.key,revision=state.revision})
        return
    end
    if not active then publish(nil,"Voice setup is not ready. Retry or skip this part."); return end
    if op=="complete" then
        if observed<2 then publish(nil,"No microphone signal detected yet. You can keep testing or skip voice setup."); return end
        local checkpoint={operation="voice-done",key=state.key,revision=state.revision}
        local result,why=call("complete")
        if result then active=false;generation=generation+1;TriggerServerEvent(LightRpEvents.net.tutorial,checkpoint) else publish(nil,why) end
    elseif op=="set" or op=="test" or op=="refresh" then
        if op=="set" and value.name=="InputDevice" then observed=0 end
        local result,why=call(op,op=="set" and {name=value.name,value=value.value} or value.value)
        if active then publish(result,why,true) end
    end
end
CreateThread(function()
    while true do
        Wait(250)
        if active then
            local token=generation
            local result,why=call("status")
            if token==generation and active then publish(result,why) end
        end
    end
end)
AddEventHandler("onClientResourceStop",function(name)
    if name==GetCurrentResourceName() then V.stop() end
end)
