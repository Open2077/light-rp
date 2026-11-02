local NET,PAGE="op77_lightrp:hotbar","lightrp:ui:hotbar"
local Ui=LightRpUi
local H={}
LightRpHotbar=H
local cached={ready=false,revision=0,items={}}
local held,untilTime,lastUse,sequence=false,0,-1000,0
local lastPublished
local showKey,slotKeys="TAB",{"1","2","3","4","5"}
local function allowed(checkBusy)
 if Ui.loadingScreen and Ui.loadingScreen()then return false end
 if not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.promptActive or Ui.actionFocus or Ui.supportMode=="menu"or Ui.supportMode=="form"then return false end
 for _,open in pairs(Ui.dialogs or {})do if open then return false end end
 if checkBusy~=false then
  if LightRpMedical and LightRpMedical.isActive()then return false end
  if LightRpActions and LightRpActions.isActive()then return false end
  if LightRpConsumables and LightRpConsumables.isActive()then return false end
  if LightRpRefueling and LightRpRefueling.isActive()then return false end
 end
 local c=Open77.character.state()
 return c and c.alive and c.attached and cached.ready
end
local function publish(force)
 local eligible=allowed(false)
 if not eligible then held=false;untilTime=0 end
 -- TAB also opens the weapon wheel: the quick slots stay out of its way
 local wheel=LightRpWeaponWheel and LightRpWeaponWheel.open
 local visible=eligible and not wheel and(held or GetGameTimer()<untilTime)or false
 local stamp=table.concat({tostring(cached.inventoryId),tostring(cached.revision),tostring(cached.ready),tostring(visible),showKey,table.concat(slotKeys,",")},":")
 if stamp==lastPublished and not force then return end
 lastPublished=stamp
 Ui.send(PAGE,{kind="state",state=cached,visible=visible,showKey=showKey,slotKeys=slotKeys})
end
function H.use(slot)
 if not allowed()then return end
 local at=GetGameTimer();if at-lastUse<220 then return end;lastUse=at
 untilTime=at+2500;sequence=sequence+1
 local request="hotbar:"..at..":"..sequence
 publish();Ui.send(PAGE,{kind="activate",slot=slot,request=request})
 local ok,why=TriggerServerEvent(NET,{operation="use",slot=slot,inventoryId=cached.inventoryId,revision=cached.revision,request=request})
 if ok==false then Ui.send(PAGE,{kind="response",request=request,slot=slot,ok=false,text=tostring(why)})end
end
RegisterNetEvent(NET,function(p)
 if type(p)~="table"then return end
 if p.kind=="state"and type(p.state)=="table"then cached=p.state;publish()
 else Ui.send(PAGE,p)end
end)
function H.bind(page)
 page:on(LightRpEvents.page.ready,function()publish(true);TriggerServerEvent(NET,{operation="state"})end)
 local key=LightRpConfig.keys.hotbar
 local ok,effective=RegisterKeyMapping({id=key.id,name=key.name,key=key.key,hold=true,consume=true,
  -- the wheel shares TAB and wins when it can open (bound after the hotbar, it fires second)
  onPressed=function()if allowed(false)and not(LightRpWeaponWheel and LightRpWeaponWheel.allowed and LightRpWeaponWheel.key==showKey and LightRpWeaponWheel.allowed())then held=true;publish()end end,
  onReleased=function()held=false;publish()end})
 if ok then showKey=effective else Ui.log("hotbar show mapping refused: %s",tostring(effective))end
 for slot=1,5 do
  local index=slot
  local installed,binding=RegisterKeyMapping({id="lightrp.hotbar.slot"..slot,name="Light RP: quick slot "..slot,key=tostring(slot),consume=true,onPressed=function()H.use(index)end})
  if installed then slotKeys[slot]=binding else Ui.log("hotbar slot %d mapping refused: %s",slot,tostring(binding))end
 end
 CreateThread(function()while true do publish();Wait(100)end end)
end
