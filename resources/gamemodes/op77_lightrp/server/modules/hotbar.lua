-- Quick slots are the actual first inventory row, never a second item store.
local Inv=LightRP.inventory
local H={}
LightRP.hotbar=H
local NET="op77_lightrp:hotbar"
local lastUse={}
local function eligible(player)
 local c=LightRP.characters.get(player)
 local life=Open77.players.getLifeState(player)
 return c and c.status=="active"and not(LightRP.characters.switching and LightRP.characters.switching[player])and life and life.phase=="alive"
end
function H.snapshot(player,snap)
 local inv=Inv.player(player)
 if not inv then return {ready=false,revision=0,items={}}end
 snap=snap or Inv.snapshot(inv)
 local items={};for _,item in ipairs(snap.items)do if item.slot>=1 and item.slot<=5 then items[#items+1]=item end end
 return {ready=eligible(player)==true,inventoryId=inv.id,revision=inv.revision or 0,items=items}
end
function H.push(player,snap)TriggerClientEvent(NET,player,{kind="state",state=H.snapshot(player,snap)})end
function H.inventoryChanged(inv,snap)
 if inv.kind~="player"then return end
 for _,id in ipairs(GetPlayers())do local player=tonumber(id);if Inv.player(player)==inv then H.push(player,snap)end end
end
function H.use(player,p)
 local inv=Inv.player(player)
 if not inv or not eligible(player)then return false,"Quick slots are unavailable right now."end
 if type(p)~="table"or type(p.slot)~="number"or p.slot%1~=0 or p.slot<1 or p.slot>5 then return false,"Invalid quick slot."end
 if p.inventoryId~=inv.id or p.revision~=(inv.revision or 0)then H.push(player);return false,"Your inventory changed. Try again with the updated quick slot."end
 local at=LightRP.nowMs()
 if lastUse[player]and at-lastUse[player]<200 then return false,"Please wait before using another quick slot."end
 lastUse[player]=at
 local item=inv.items[p.slot]
 if not item then return false,"This quick slot is empty."end
 -- Inv.use is the same locked/life-checked route as the inventory dialog:
 -- weapon draw, grenade selection, timed food/heal and custom item handlers.
 local label=(LightRpItems[item.name]or{}).label or item.name
 local ok,reason=Inv.use(player,p.slot)
 H.push(player)
 local messages={activity="Your quick slots are put away during this activity.",not_usable="This item cannot be used from a quick slot.",busy="Another inventory action is in progress.",use_refused="This item cannot be used right now.",not_alive="You must be conscious to use quick slots.",use_failed="The item could not be used.",empty_slot="This quick slot is empty."}
 return ok,ok and label or messages[reason]or tostring(reason)
end
RegisterNetEvent(NET,function(p)
 local player=tonumber(source)
 if not player or player<=0 or type(p)~="table"then return end
 if p.operation=="state"then H.push(player);return end
 if p.operation~="use"or type(p.request)~="string"or #p.request>96 then return end
 local ok,text=H.use(player,p)
 TriggerClientEvent(NET,player,{kind="response",request=p.request,slot=p.slot,ok=ok==true,text=text})
end)
LightRP.module("hotbar",{
 onCharacterLoaded=function(player)H.push(player)end,onCharacterActivated=function(player)H.push(player)end,
 onGameplayReady=function(player)H.push(player)end,onUiReady=function(player)H.push(player)end,
 onLifeState=function(player)H.push(player)end,
 onDatabaseReady=function()for _,player in ipairs(GetPlayers())do H.push(tonumber(player))end end,
 onDisconnected=function(player)lastUse[player]=nil end,
})
