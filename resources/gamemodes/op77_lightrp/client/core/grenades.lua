local NET,PAGE="op77_lightrp:grenades","lightrp:ui:grenades"
local Ui=LightRpUi
LightRpGrenadesClient={}
local cached,sequence={ready=false,count=0},0
-- Whether the page shows the grenade chip (Grenades.tsx GrenadeStatus: ready, selected, count > 0).
function LightRpGrenadesClient.chipShown() return cached.ready==true and cached.selected~=nil and cached.selected~=false and (tonumber(cached.count) or 0)>0 end
local function controls(release)
 if not LightRpControlClaims then return end
 LightRpControlClaims.set("grenade-inventory","SwitchItem",not release)
 LightRpControlClaims.set("grenade-inventory","Grenade",not release and (not cached.ready or cached.busy or not cached.selected or cached.count<=0))
end
RegisterNetEvent(NET,function(p)
 if type(p)~="table"then return end
 if type(p.state)=="table"then cached=p.state;controls(false)end
 Ui.send(PAGE,p)
end)
function LightRpGrenadesClient.bind(page)
 controls(false)
 page:on(LightRpEvents.page.ready,function()Ui.send(PAGE,{kind="state",state=cached});TriggerServerEvent(NET,{operation="state",request="state"})end)
 page:on(PAGE,function(p)
  if type(p)~="table"or(p.operation~="state"and p.operation~="sync"and p.operation~="unequip")then return end
  sequence=sequence+1
  TriggerServerEvent(NET,{operation=p.operation,request=tostring(p.request or sequence),mutation=tostring(p.mutation or ("grenade:"..GetGameTimer()..":"..sequence))})
 end)
end
AddEventHandler("onClientResourceStop",function(name)if name==GetCurrentResourceName()then controls(true)end end)
