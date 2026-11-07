local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- Inventory owns every grenade; native gadgets are an exact, disposable projection.
local W,Inv,Db,C=LightRP.armament,LightRP.inventory,LightRP.db,LightRpGrenades.items
local G={states={},internal={}}
LightRP.grenades=G
local NET="op77_lightrp:grenades"
local lastRequest={}
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_grenades (
 inventory_id VARCHAR(96) PRIMARY KEY, revision INT NOT NULL DEFAULT 0, selected_item VARCHAR(64) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_grenade_operations (
 inventory_id VARCHAR(96) NOT NULL, mutation VARCHAR(96) NOT NULL, operation VARCHAR(16) NOT NULL,
 PRIMARY KEY(inventory_id,mutation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
local function count(inv,name)
 local n=0;for _,item in pairs(inv and inv.items or {})do if item.name==name then n=n+item.count end end;return n
end
local function load(inv)
 if G.states[inv.id]then return G.states[inv.id]end
 local ok,rows=Db.read("SELECT revision,selected_item FROM lightrp_grenades WHERE inventory_id=?",{inv.id})
 if not ok then return nil,"Grenade storage is unavailable."end
 local s=rows[1]and{revision=tonumber(rows[1].revision),selected=rows[1].selected_item~="" and rows[1].selected_item or nil}or{revision=0}
 if not W.integer(s.revision,0,2147483646)or(s.selected and not C[s.selected])then return nil,"Stored grenade selection is invalid."end
 G.states[inv.id]=s;return s
end
local function save(inv,s,mutation,operation,changes)
 local queries={{query="INSERT INTO lightrp_grenades (inventory_id,revision,selected_item) VALUES (?,?,?) ON DUPLICATE KEY UPDATE revision=VALUES(revision),selected_item=VALUES(selected_item)",values={inv.id,s.revision,s.selected or ""}}}
 if mutation then queries[#queries+1]={query="INSERT INTO lightrp_grenade_operations (inventory_id,mutation,operation) VALUES (?,?,?)",values={inv.id,mutation,operation}}end
 G.internal[inv.id]=true
 local called,ok,why=pcall(Inv.commitDrafts,changes or {},queries,function()G.states[inv.id]=s end)
 G.internal[inv.id]=nil
 return called and ok==true,called and why or "Grenade transaction failed."
end
local function runtime(player)
 local rt=W.runtime[player]
 return W.current(rt)and rt or nil
end
function G.view(player)
 local rt=runtime(player);local inv=Inv.player(player);local s=inv and G.states[inv.id];local g=rt and rt.grenade
 return {ready=g and g.ready==true and not rt.quarantine or false,busy=rt and rt.busy==true and not rt.observing or false,
 revision=s and s.revision or 0,selected=s and s.selected,label=s and s.selected and C[s.selected].label,
 count=s and s.selected and count(inv,s.selected)or 0,error=g and g.error or rt and rt.quarantine and "Equipment synchronization timed out. Wait for completion or reconnect." or nil}
end
function G.push(player)TriggerClientEvent(NET,player,{kind="state",state=G.view(player)})end
-- Cyberpunk 2.x throws spend a rechargeable charge pool. Gadget inventory
-- membership is not a throw counter and can remain constant across every use.
local function chargeCount(state,record)
 if type(state)~="table"or state.kind~="grenade"or state.record~=record then return nil end
 if not W.integer(state.count,0,999)or not W.integer(state.capacity,1,999)or state.count>state.capacity then return nil end
 return state.count
end
local function supported()
 local api=Open77.consumables
 return type(api)=="table"and type(api.configure)=="function"and type(api.snapshot)=="function"
end
local function reconcile(rt,allowReset)
 local g=rt.grenade
 if not g or not g.projected then return true end
 local state,why=W.nativeConsumable(rt,"snapshot","grenade")
 if not state then return false,why end
 local remaining=chargeCount(state,C[g.projected].record)
 if remaining==nil then return false,"Native grenade charges are unavailable. Synchronize before throwing."end
 if (state.recharge~=false or state.managed~=true)and not allowReset then
  return false,"Finite grenade charge control was lost. Synchronize before throwing."
 end
 if remaining>g.quantity then
  if allowReset then return true end
  return false,"Native grenade stock exceeds inventory. Synchronize before throwing."
 end
 local spent=g.quantity-remaining
 if spent>0 then
  local ok,error=Inv.transaction(rt.player,function(inv)
   if not W.current(rt)then return false,"Character changed."end
   if count(inv,g.projected)<spent then return false,"Grenade ownership changed."end
   local draft=Inv.draft(inv);local removing=spent
   for slot=draft.slots,1,-1 do
    local item=draft.items[slot]
    if item and item.name==g.projected and removing>0 then local n=math.min(removing,item.count);item.count=item.count-n;removing=removing-n;if item.count==0 then draft.items[slot]=nil end end
   end
   local s=G.states[inv.id];local nextState={revision=s.revision+1,selected=count(draft,s.selected)>0 and s.selected or nil}
   return save(inv,nextState,nil,"consume",{{inv,draft}})
  end)
  if not ok then return false,error end
  LightRP.log("grenade charges player=%d item=%s spent=%d stock=%d",rt.player,g.projected,spent,count(Inv.player(rt.player),g.projected))
 end
 g.quantity=remaining;g.dirty=false
 if remaining==0 and not G.states[rt.inventory].selected then g.projected=nil end
 return true
end
local function project(rt)
 local inv=Inv.player(rt.player);local s=G.states[inv.id];local g=rt.grenade
 local n=s.selected and count(inv,s.selected)or 0
 if not W.integer(n,0,999)then return false,"Grenade stock must be at most 999."end
 local record=s.selected and C[s.selected].record or C.grenade_frag.record
 g.projected=nil -- partial native writes are pending projection, never spent stock
 local state,why=W.nativeConsumable(rt,"configure","grenade",{
  record=record,count=n,capacity=math.max(1,n),equipped=n>0,recharge=false,
 })
 if not state then
  if why=="consumables_unavailable_on_this_client"or why=="unsupported_operation"then
   return false,"Finite grenade charges require a compatible Open77 client. Update the client before using grenades."
  end
  return false,why
 end
 if chargeCount(state,record)~=n or state.equipped~=(n>0)or state.recharge~=false or state.managed~=true then
  return false,"Finite grenade charges could not be verified. No inventory items were refunded."
 end
 g.projected=s.selected;g.quantity=n
 LightRP.log("grenade kit player=%d item=%s charges=%d capacity=%d recharge=false verified",rt.player,tostring(s.selected or "none"),n,state.capacity)
 return true
end
function G.start(player,operation,item,mutation,request)
 local rt=runtime(player)
 if not rt then return false,"Character inventory is not ready."end
 if rt.busy or rt.quarantine then return false,"Equipment synchronization is in progress or awaiting a delayed request."end
 local life=Open77.players.getLifeState(player)
 if not life or life.phase~="alive"then return false,"Your character must be alive."end
 rt.grenade=rt.grenade or {ready=false}
 local g=rt.grenade
 if not supported()then
  g.ready=false;g.error="Finite grenade charges are unavailable on this server. Grenades remain disabled.";G.push(player)
  return false,g.error
 end
 rt.busy=true;rt.observing=operation=="observe"
 if not rt.observing then g.ready=false;g.error=nil;W.push(player);G.push(player)end
 CreateThread(function()
  Wait(0) -- generic Inv.use must release its mutex before reconciliation
  local called,ok,why=pcall(function()
   local inv=Inv.player(player);local s,error=load(inv);if not s then return false,error end
   local settled,failure=reconcile(rt,operation~="observe");if not settled then return false,failure end
   if operation=="observe"then return true end
   if operation=="equip"or operation=="unequip"then
    local saved,reason=Inv.transaction(player,function(currentInv)
     if not W.current(rt)then return false,"Character changed."end
     local read,prior=Db.read("SELECT operation FROM lightrp_grenade_operations WHERE inventory_id=? AND mutation=?",{currentInv.id,mutation})
     if not read then return false,"Grenade storage is unavailable."end
     if prior[1]then return prior[1].operation==operation,"Request key already used."end
     if operation=="equip"and(not C[item]or count(currentInv,item)<1)then return false,"This grenade is not in your inventory."end
     local currentState=G.states[currentInv.id]
     return save(currentInv,{revision=currentState.revision+1,selected=operation=="equip"and currentState.selected~=item and item or nil},mutation,operation)
    end)
    if not saved then return false,reason end
   end
   return project(rt)
  end)
  if not W.current(rt)then return end
  rt.busy=false;rt.observing=false;g.ready=called and ok==true
  if g.ready then g.error=nil else g.error=tostring(called and why or ok)end
  W.push(player);G.push(player)
  if request then TriggerClientEvent(NET,player,{kind="response",request=request,ok=g.ready,error=g.error,state=G.view(player)})end
 end)
 return true
end
-- Equipped grenade stock cannot leave its inventory before a settled unequip.
local prepare=W.prepare
W.prepare=function(changes)
 for _,change in ipairs(changes)do
  local inv,draft=change[1],change[2]
  for name in pairs(C)do
   local before,after=count(inv,name),count(draft,name)
   if after>999 then return false,"Grenade stock is limited to 999 per type."end
   if after>0 and not inv.persistent then return false,"Grenades require durable storage."end
   if before~=after and not G.internal[inv.id]then
    local s,why=load(inv);if not s then return false,why end
    if s.selected==name then return false,"Unequip the grenade before changing its inventory stock."end
    for _,rt in pairs(W.runtime)do if rt.inventory==inv.id and rt.busy and rt.grenade then return false,"Equipment synchronization is in progress."end end
   end
  end
 end
 return prepare(changes)
end
for name in pairs(C)do
 local itemName=name
 Inv.onUse(name,function(player)
  local id=W.uuid();if not id then return false end
  local ok,why=G.start(player,"equip",itemName,"use:"..id)
  if not ok then LightRP.notice(player,{kind="error",title="Grenades",body=why});return false end
  return "keep"
 end)
end
RegisterNetEvent(NET,function(p)
 local player=tonumber(source)
 if not player or player<=0 or type(p)~="table"or type(p.request)~="string"or #p.request>96 then return end
 if p.operation=="state"then G.push(player);return end
 local at=Open77.time.monotonic();if lastRequest[player]and at-lastRequest[player]<.15 then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Please wait before the next grenade request."});return end;lastRequest[player]=at
 if p.operation~="sync"and p.operation~="unequip"then return end
 if type(p.mutation)~="string"or #p.mutation<8 or #p.mutation>96 or not p.mutation:match("^[%w:_%-]+$")then return end
 -- an activity's own kit owns the native slots (server/modules/activities.lua): no RP projection over it
 if p.operation=="sync"and LightRP.activities and LightRP.activities.current(player)and not LightRP.activities.allows(player,"rpWeapons")then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Your grenades stay put away during this activity."});return end
 local ok,why=G.start(player,p.operation,nil,p.mutation,p.request)
 if not ok then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error=why})end
end)
AddEventHandler("onConsumableUsed",function(player,kind,record)
 if kind~="grenade"then return end
 local rt=runtime(tonumber(player));local g=rt and rt.grenade
 if g and g.projected and C[g.projected].record==record then g.dirty=true end
end)
LightRP.module("grenades",{onDisconnected=function(player)lastRequest[player]=nil end,onUiReady=function(player)G.push(player)end,
 onLifeState=function(player)G.push(player)end,onCharacterLoaded=function(player)G.push(player)end,
 onDatabaseReady=function()LightRP.log("grenades ready: 9 finite charge kits; gadget stack sizes are not throw counts")end})
CreateThread(function()
 lightrpEvery(500, function()
  for _,id in ipairs(GetPlayers())do
   local player=tonumber(id);local rt=runtime(player)
   -- an activity's own kit owns the native slots: no RP grenade projection over it
   -- not before the player is in the world: a request during the loading screen times out and
   -- quarantined the whole equipment (lab 2026-11-05)
   if rt and not rt.busy and not rt.quarantine and W.inWorld and W.inWorld(player) and not(LightRP.activities and LightRP.activities.current(player)and not LightRP.activities.allows(player,"rpWeapons"))then
    if not rt.grenade then G.start(player,"sync")
    elseif rt.grenade.ready and rt.grenade.projected then G.start(player,"observe")end
   end
  end
  
 end, "grenades:200")
end)
