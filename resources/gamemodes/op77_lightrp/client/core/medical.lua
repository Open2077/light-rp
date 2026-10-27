-- Medical presentation owns no health, item or timeout decisions.
local Ui,E=LightRpUi,LightRpEvents
local NET,PAGE="op77_lightrp:medical","lightrp:ui:medical"
local Medical={downed=false}
LightRpMedical=Medical
local cached,active={downed=false},nil
local function cancel(a)
 if active~=a or a.sent then return end
 a.sent=true;TriggerServerEvent(NET,{operation="cancel",token=a.token})
end
local function clear(a)
 if active~=a then return end
 active=nil
 if a.actionId and LightRpActions then LightRpActions.cancel(a.actionId)end
end
local function controls(release)
 if not LightRpControlClaims then return end
 local blocked=not release and Medical.downed
 for _,action in ipairs({"Movement","Attack","Melee","Grenade","Consumable","Reload","WeaponWheel","NextWeapon","SwitchItem","Sprint","Jump","Hub","FastTravel"})do
  LightRpControlClaims.set("medical",action,blocked)
 end
end
function Medical.isDowned()return Medical.downed end
function Medical.isActive()return Medical.downed or active~=nil end
local function publish()
 Ui.send(PAGE,{kind="state",state=cached})
 controls(false)
 if Medical.downed and Ui.page then Ui.page:setFocus(false,true)end -- cursor only; voice keys remain available
end
RegisterNetEvent(NET,function(p)
 if type(p)~="table"then return end
 if p.kind=="state"and type(p.state)=="table"then
  local wasDown=Medical.downed;cached=p.state;Medical.downed=cached.downed==true
  if Medical.downed and not wasDown then
   if active then local a=active;cancel(a);clear(a)end
   Ui.setMenuOpen(false)
   if Ui.supportMode then Ui.setSupportInput("closed")end
   Ui.send(E.page.dialogClose,{})
  elseif wasDown and not Medical.downed and Ui.page then Ui.page:setFocus(false,false)end
  publish();return
 end
 if p.kind~="treatment"or type(p.token)~="string"then return end
 if p.phase=="finished"then if active and active.token==p.token then clear(active)end;return end
 if p.phase=="prepare"then
  if active or Medical.downed then TriggerServerEvent(NET,{operation="cancel",token=p.token});return end
  local a={token=p.token};active=a
  CreateThread(function()
   if not Ui.ready or not Ui.characterReady or not LightRpActions or LightRpActions.isActive()then cancel(a);return end
   Ui.send(E.page.dialogClose,{kind="inventory"})
   local deadline=GetGameTimer()+2500
   while active==a and(Ui.dialogs.inventory or Ui.promptActive)and GetGameTimer()<deadline do Wait(50)end
   if active~=a or a.sent then return end
   if Ui.dialogs.inventory or Ui.promptActive or Ui.menuOpen then cancel(a);return end
   for _,open in pairs(Ui.dialogs)do if open then cancel(a);return end end
   TriggerServerEvent(NET,{operation="ready",token=a.token})
  end)
 elseif p.phase=="play"then
  local a=active
  if not a or a.token~=p.token or a.actionId or a.sent then return end
  CreateThread(function()
   Wait(tonumber(p.delayMs)or 900)
   if active~=a or a.sent then return end
   local actionId=LightRpActions.progress({label="Stabilizing patient",description=(p.patient or"Patient").." · Remain close and still",
    durationMs=p.durationMs,icon="briefcase-medical",cancellable=true,allowMovement=true},function(result)if result.status~="success"then cancel(a)end end)
   a.actionId=actionId
   if not actionId then cancel(a)end
  end)
 end
end)
function Medical.bind(page)
 page:on(PAGE,function(p)
  if type(p)~="table"or(p.operation~="giveup"and p.operation~="state")then return end
  TriggerServerEvent(NET,{operation=p.operation})
 end)
 page:on(E.page.ready,function()publish();TriggerServerEvent(NET,{operation="state"})end)
end
AddEventHandler("onClientResourceStop",function(name)
 if name~=GetCurrentResourceName()then return end
 if active then local a=active;cancel(a);clear(a)end
 controls(true)
 if Medical.downed and Ui.page then Ui.page:setFocus(false,false)end
end)
