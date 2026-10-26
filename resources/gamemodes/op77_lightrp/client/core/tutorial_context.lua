local function eligible(ctx)
    if GetInvokingResource()~="open77_contextmenu" then return false end
    local s=LightRpTutorial.state()
    return s and s.active and s.step=="context_prop" and s.practice and type(ctx)=="table"
        and type(ctx.target)=="table" and ctx.target.kind=="prop" and ctx.target.propId==s.practice.prop
end
exports("tutorialPropAvailable",eligible)
exports("tutorialPropSelect",function(ctx)
    if not eligible(ctx) then return false end
    return LightRpTutorial.send("practice-prop",{prop=ctx.target.propId})
end)
local function publishKey()
    local keyPromise=Open77.exports.call("open77_contextmenu","getActivationKey")
    if keyPromise then
        local key=keyPromise:await()
        if type(key)=="string" then LightRpTutorial.contextKey=key;LightRpTutorial.publish() end
    end
end
AddEventHandler("open77:keybinds:changed",publishKey)
AddEventHandler("onClientResourceStart",function(name)
    if name~=GetCurrentResourceName() and name~="open77_contextmenu" then return end
    publishKey()
    local p,why=Open77.exports.call("open77_contextmenu","registerProps",{
        id="tutorial.inspect",label="Inspect practice crate",icon="info",networked=true,distance=4,
        canInteract="tutorialPropAvailable",onSelect="tutorialPropSelect",
    })
    if p then local token;token,why=p:await();if token then return end end
    LightRpUi.log("tutorial context unavailable: %s",tostring(why))
end)
