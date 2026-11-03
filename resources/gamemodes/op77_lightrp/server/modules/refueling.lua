-- Server-owned pump reservations and timed service. A client can request or
-- cancel a ticket; it cannot choose its duration, cost, effect or finish early.
local C, E, F, M = LightRpConfig.fuel, LightRpEvents.net, LightRP.fuel, LightRpFuelModel
if not C.enabled then return end
local R = LightRP.module("refueling", {})
local pumps, sessions, pumpLocks, vehicleLocks, sequence = {}, {}, {}, {}, 0
local refreshed = {}
local now = LightRP.nowMs
local function failure(player, text, action) LightRP.result(player, false, text, action or "fuel.buy") end
local function foot(player)
    local c, p, life = LightRP.characters.get(player), Open77.players.position(player), Open77.players.getLifeState(player)
    if not c or c.status ~= "active" or not p or not life or life.phase ~= "alive" then return nil, "Your character must be alive and ready." end
    if (p.bucket or 0) ~= 0 then return nil, "Fuel stations are only available in the city." end
    if Open77.vehicles.getPlayerSeat(player) then return nil, "Step out of the vehicle first." end
    return p
end
local function parked(id)
    local v = Open77.vehicles.get(id)
    if not v or (v.bucket or 0) ~= 0 then return nil, "That vehicle is no longer here." end
    local flags = type(Open77.vehicles.flags)=="table" and Open77.vehicles.flags or {}
    if flags.destroyed and ((v.flags or 0) & flags.destroyed) ~= 0 then return nil, "This vehicle is destroyed." end
    if math.abs(tonumber(v.speed) or 0) > C.parkedSpeed then return nil, "Park the vehicle before refuelling." end
    if Open77.vehicles.isEngineOn(id) then return nil, "Switch off the engine first (ALT → Vehicle → Engine)." end
    if (tonumber(Open77.vehicles.getDriver(id)) or 0)>0 then return nil, "The driver must step out first." end
    return v
end
local function position(v) return {x=v.x,y=v.y,z=v.z} end
local function nearPump(player, pump)
    local p, why = foot(player)
    if not p then return nil, why end
    if not pump or M.distance(p,pump.position) > C.interactRadius + 0.4 then return nil, "Walk up to the pump." end
    return p
end
local function valid(player, a)
    local p, why = foot(player)
    if not p then return nil, why end
    if LightRP.characters.get(player) ~= a.character then return nil, "Character changed." end
    if a.pump and M.distance(p,a.pump.position) > C.pumpRange + 1 then return nil, "You moved too far from the pump." end
    if a.vehicle then
        local v; v, why = parked(a.vehicle)
        if not v then return nil, why end
        if M.distance(position(v),a.vehiclePosition) > 0.75 then return nil, "The vehicle moved." end
        if a.pump and M.distance(position(v),a.pump.position) > C.pumpRange then return nil, "The vehicle is too far from the pump." end
        if a.phase ~= "approach" and not (a.phase=="prepare" and a.kind=="vehicle") and M.distance(p,position(v)) > C.vehicleUseRange then return nil, "Stand beside the vehicle." end
        local info = F.info(a.vehicle)
        if not info or math.abs(info.litres-a.before) > 0.11 then return nil, "The tank changed. Start a new fill." end
    elseif M.distance(p,a.pump.position) > C.interactRadius + 0.4 then return nil, "Stay beside the pump." end
    if a.origin and M.distance(p,a.origin) > 0.8 then return nil, "You moved away while refuelling." end
    if a.inventory and (LightRP.inventory.player(player) ~= a.inventory or a.inventory.items[a.slot] ~= a.item
        or a.item.name ~= a.itemName or a.item.count < 1) then return nil, "The jerrycan was moved or changed." end
    if a.playbackId then
        local playing = Open77.animations.current(player)
        if not playing or not playing.active or playing.playbackId ~= a.playbackId then return nil, "The animation was interrupted." end
    end
    return p
end
local function send(player, a, phase, extra)
    local data = extra or {}; data.token, data.phase = a.token, phase
    TriggerClientEvent(E.fuel,player,data)
end
local function clear(player,a,ok,why,silent)
    if sessions[player] ~= a then return end
    sessions[player] = nil
    LightRP.log("fuel service player=%s kind=%s litres=%.1f ok=%s reason=%s",tostring(player),a.kind,a.litres,tostring(ok==true),why or "cancelled")
    if a.pump then pumpLocks[a.pump.id] = nil end
    if a.vehicle then vehicleLocks[a.vehicle] = nil end
    if a.playbackId then pcall(Open77.animations.stop,player,a.playbackId) end
    if a.prop then pcall(Open77.props.remove,a.prop) end
    send(player,a,"finished",{ok=ok==true})
    if not silent then LightRP.notice(player,{kind=ok and "success" or "info",title=ok and "Refuelling complete" or "Refuelling stopped",
        body=why or "Nothing was charged or consumed.",durationMs=5500}) end
end
local function busy(player,pump,vehicle)
    if sessions[player] or (LightRP.consumables and LightRP.consumables.isActive(player)) then return "Finish your current action first." end
    local anim = Open77.animations.current(player)
    if anim and anim.active then return "Stop your animation first." end
    if pump and pumpLocks[pump.id] then return "This pump is in use. Use another pump." end
    if vehicle and vehicleLocks[vehicle] then return "Someone is already refuelling this vehicle." end
end
local function reserve(player,a)
    if not LightRP.db.ready then return false,"The database is unavailable. Please try again later." end
    local why = busy(player,a.pump,a.vehicle)
    if why then return false,why end
    sequence=sequence+1
    a.token=tostring(now())..":"..sequence; a.character=LightRP.characters.get(player)
    a.phase="prepare"; a.expires=now()+7000
    sessions[player]=a
    LightRP.log("fuel reserved player=%s kind=%s pump=%s vehicle=%s litres=%.1f",tostring(player),a.kind,a.pump and a.pump.id or "can",tostring(a.vehicle),a.litres)
    if a.pump then pumpLocks[a.pump.id]=player end
    if a.vehicle then vehicleLocks[a.vehicle]=player end
    send(player,a,"prepare",{kind=a.kind})
    return true
end
local function candidates(pump)
    local found={}
    for _, v in ipairs(Open77.vehicles.all() or {}) do
        if (v.bucket or 0)==0 and v.x and M.distance(position(v),pump.position)<=C.pumpRange then
            local info=F.info(v.id)
            if info then
                local _, reason=parked(v.id)
                found[#found+1]={id=v.id,label=F.labelOf(v.record),litres=info.litres,capacity=info.capacity,
                    moving=math.abs(v.speed or 0)>C.parkedSpeed,engineOn=Open77.vehicles.isEngineOn(v.id)==true,
                    unavailable=vehicleLocks[v.id] and "Already being refuelled" or reason,distance=M.distance(position(v),pump.position)}
            end
        end
    end
    table.sort(found,function(a,b) return a.distance<b.distance or (a.distance==b.distance and a.id<b.id) end)
    return found
end
local function payload(player,pump)
    local inv,w=LightRP.inventory,LightRP.money.get(player)
    local id=inv.playerId(player); local vehicles=candidates(pump)
    local refill=math.ceil(C.jerrycan.litres*C.pricePerLitre)
    return {spot={id=pump.id,name=pump.name,pump=pump.number,pumps=pump.count},pricePerLitre=C.pricePerLitre,
        pumpRange=C.pumpRange,litresPerSecond=C.litresPerSecond,minimumFillMs=C.minimumFillMs,
        vehicles=vehicles,vehicle=vehicles[1],busy=pumpLocks[pump.id]~=nil,
        jerrycan={litres=C.jerrycan.litres,refillPrice=refill,buyPrice=refill+C.jerrycan.deposit,
            empty=id and inv.count(id,"jerrycan_empty") or 0,full=id and inv.count(id,"jerrycan") or 0},
        money={currency=LightRpConfig.economy.currency,cash=w and w.cash or 0,bank=w and w.bank or 0}}
end
CreateThread(function()
    Wait(800)
    local groups=M.clusters(C.stations,C.clusterRadius,C.clusterHeight)
    for _, group in ipairs(groups) do
        for i, entry in ipairs(group.pumps) do
            local pump={}; for k,v in pairs(entry) do pump[k]=v end
            pump.number,pump.count=i,#group.pumps; pumps[pump.id]=pump
            LightRP.interaction("fuel."..pump.id,{position=pump.position,radius=C.interactRadius,bucket=0,
                label=pump.name,prompt="Use fuel pump · "..i,key="E",promptHeight=1.0,ring=false,marker=C.marker,
                blip=i==1 and C.blip and {icon=C.blip.icon,color=C.blip.color,size=C.blip.size,
                    sprite=C.blip.sprite,title=C.blip.title,description=#group.pumps.." pumps · "..C.blip.description,
                    -- A station is a POI, not an active GPS destination.
                    position=group.position,routable=false} or nil})
        end
    end
    LightRP.log("fuel: %d pumps grouped into %d station blip(s)",#C.stations,#groups)
end)
function R.onInteract(player,id)
    local pump=pumps[id:match("^fuel%.(.+)$")]
    if not pump then return end
    if sessions[player] then return failure(player,"Finish or cancel your current fill first.","fuel.open") end
    local p,why=nearPump(player,pump)
    if not p then return failure(player,why,"fuel.open") end
    LightRP.dialog(player,"fuel",payload(player,pump))
end
local function refresh(player,data)
    if type(data)~="table" or (refreshed[player] and now()-refreshed[player]<2000) then return end
    refreshed[player]=now()
    local pump=pumps[tostring(data.spot or "")]
    if pump and not sessions[player] and nearPump(player,pump) then
        local p=payload(player,pump); p.kind="fuel"; TriggerClientEvent(E.fuelSnapshot,player,p)
    end
end
LightRP.action("fuel.refresh",refresh)
RegisterNetEvent(E.fuelRefresh,function(data) refresh(source,data) end)
LightRP.action("fuel.buy",function(player,data)
    local pump=pumps[tostring(data.spot or "")]
    local p,why=nearPump(player,pump); if not p then return failure(player,why) end
    local id=tonumber(data.vehicle); if not id then return failure(player,"Choose a vehicle at the pump.") end
    local v; v,why=parked(id); if not v then return failure(player,why) end
    if M.distance(position(v),pump.position)>C.pumpRange then return failure(player,"Park beside this pump.") end
    local info=F.info(id); local litres=tonumber(data.litres)
    if not info or not litres or litres~=litres or litres==math.huge or litres<1 then return failure(player,"Choose a valid fuel amount.") end
    litres=math.min(math.floor(litres),math.floor(info.capacity-info.litres))
    if litres<1 then return failure(player,"The tank is full.") end
    local pay=data.pay=="bank" and "bank" or "cash"
    local price=math.ceil(litres*C.pricePerLitre); local w=LightRP.money.get(player)
    if not w or w[pay]<price then return failure(player,"Not enough money in the selected account.") end
    local ok; ok,why=reserve(player,{kind="vehicle",pump=pump,vehicle=id,vehiclePosition=position(v),before=info.litres,
        litres=litres,price=price,pay=pay,durationMs=math.max(C.minimumFillMs,math.ceil(litres/C.litresPerSecond*1000)),label=F.labelOf(v.record)})
    if not ok then failure(player,why) end
end)
LightRP.action("fuel.jerrycan",function(player,data)
    local pump=pumps[tostring(data.spot or "")]; local p,why=nearPump(player,pump)
    if not p then return failure(player,why,"fuel.jerrycan") end
    local inv=LightRP.inventory.player(player); if not inv then return end
    local slot,item
    for n=1,inv.slots do if inv.items[n] and inv.items[n].name=="jerrycan_empty" then slot,item=n,inv.items[n]; break end end
    local price=math.ceil(C.jerrycan.litres*C.pricePerLitre)+(item and 0 or C.jerrycan.deposit)
    local pay=data.pay=="bank" and "bank" or "cash"; local w=LightRP.money.get(player)
    if not w or w[pay]<price then return failure(player,"Not enough money in the selected account.","fuel.jerrycan") end
    local ok; ok,why=reserve(player,{kind="can",pump=pump,inventory=item and inv or nil,slot=slot,item=item,itemName=item and item.name,
        price=price,pay=pay,litres=C.jerrycan.litres,durationMs=math.ceil(C.jerrycan.litres/C.litresPerSecond*1000),label="Jerrycan"})
    if not ok then failure(player,why,"fuel.jerrycan") end
end)
function R.beginCan(player,inv,slot,item)
    local p,why=foot(player); if not p then return false,why end
    local v=Open77.vehicles.closest(player,{radius=C.jerrycan.range})
    local id=type(v)=="table" and (v.id or v.vehicleId)
    if not id then return false,"Stand beside a vehicle to pour fuel." end
    v,why=parked(id); if not v then return false,why end
    local info=F.info(id); local remaining=math.min(C.jerrycan.litres,tonumber((item.metadata or {}).fuelLitres) or C.jerrycan.litres)
    local litres=math.floor(math.min(remaining,info.capacity-info.litres)*10+0.001)/10
    if litres<0.1 then return false,"The tank is already full." end
    return reserve(player,{kind="pour",inventory=inv,slot=slot,item=item,itemName=item.name,vehicle=id,vehiclePosition=position(v),
        before=info.litres,litres=litres,remaining=remaining-litres,price=0,durationMs=math.max(C.minimumFillMs,math.ceil(litres*1000)),label=F.labelOf(v.record)})
end
RegisterNetEvent(E.fuelReady,function(data)
    local player=source; local a=sessions[player]
    if not a or type(data)~="table" or data.token~=a.token or (a.phase~="prepare" and a.phase~="approach") then return end
    local preparing=a.phase=="prepare"
    -- Pump vehicle sessions allow walking to the car before requiring proximity.
    if preparing and a.kind=="vehicle" then a.phase="approach" end
    local p,why=valid(player,a)
    if not p or now()>a.expires then return clear(player,a,false,why) end
    if preparing and a.kind=="vehicle" then
        a.expires=now()+C.approachTimeoutMs
        send(player,a,"approach",{position=a.vehiclePosition,label=a.label,expiresMs=C.approachTimeoutMs})
        return
    end
    if a.vehicle and M.distance(p,a.vehiclePosition)>C.vehicleUseRange then return failure(player,"Stand beside the vehicle, then press E.") end
    local current=Open77.animations.current(player)
    if current and current.active then return clear(player,a,false,"Stop your other animation first. Nothing was charged.") end
    a.phase="starting"; a.origin=p
    local options={clip=C.animation.clip,loop=true,durationMs=a.durationMs+12000}
    local target=a.vehiclePosition or a.pump.position
    local yaw=math.deg(math.atan(-(target.x-p.x),target.y-p.y))
    local called,playback
    if type(Open77.animations.playAt)=="function" then
        called,playback=pcall(Open77.animations.playAt,player,C.animation.profile,{x=p.x,y=p.y,z=p.z},yaw,options)
    else
        called,playback=pcall(Open77.animations.play,player,C.animation.profile,options)
    end
    if not called or not playback then return clear(player,a,false,"The animation could not start. Nothing was charged.") end
    a.playbackId=playback.playbackId; a.phase="playing"; a.startedAt=now(); a.expires=now()+a.durationMs+12000
    if a.kind~="vehicle" then
        local prop,propError=Open77.props.create({model="container.gas_can",position={x=p.x,y=p.y,z=p.z},bucket=0,scale={x=0.65,y=0.65,z=0.65},ttlMs=a.durationMs+15000})
        if not prop then
            LightRP.log("fuel prop create refused: %s",tostring(propError))
            return clear(player,a,false,"The jerrycan could not be prepared. Nothing was charged.")
        end
        a.prop=prop
        local binding={parentType="player",parentId=player,bone="RightHand",
            offset={x=0,y=0,z=-0.12},rotation={x=0,y=75,z=0},firstPerson="hide"}
        local attached,attachError=Open77.props.attach(prop,binding)
        -- The September 19 server predates the optional first-person placement
        -- field. Retry only that schema rejection with the base attachment.
        if not attached and attachError=="invalid_attachment" then
            binding.firstPerson=nil
            attached,attachError=Open77.props.attach(prop,binding)
        end
        if not attached then
            LightRP.log("fuel prop attachment refused: %s",tostring(attachError))
            return clear(player,a,false,"The jerrycan could not be prepared. Nothing was charged.")
        end
    end
    send(player,a,"play",{playbackId=a.playbackId,durationMs=a.durationMs,litres=a.litres,price=a.price,
        label=a.kind=="can" and "Filling jerrycan" or a.kind=="pour" and "Pouring fuel" or "Refuelling vehicle",itemLabel=a.label})
end)
RegisterNetEvent(E.fuelFinish,function(data)
    local player=source; local a=sessions[player]
    if not a or type(data)~="table" or data.token~=a.token or a.phase=="committing" then return end
    if data.status~="success" then return clear(player,a,false) end
    local p,why=valid(player,a)
    if a.phase~="playing" or now()-a.startedAt<a.durationMs or now()>a.expires or not p then return clear(player,a,false,why) end
    a.phase="committing" -- duplicates/cancellation cannot race a yielding DB call
    local called,ok,reason=pcall(function()
        if a.kind~="vehicle" then return LightRP.inventory.completeFuelCan(player,a) end
        -- Grant only after the whole physical action. On a rejected payment,
        -- remove this fill again; never charge for a refused state-bag write.
        local added=F.add(a.vehicle,a.litres)
        if math.abs(added-a.litres)>0.05 then return false,"The tank could not be filled." end
        local paid,err=(a.pay=="bank" and LightRP.money.removeBank or LightRP.money.removeCash)(player,a.price,"fuel",a.litres.." L",a.pump.name)
        if not paid then
            local info=F.info(a.vehicle)
            if info then F.set(a.vehicle,math.max(0,info.litres-added)) end
            return false,LightRP.money.explain and LightRP.money.explain(err) or "Payment refused."
        end
        return true
    end)
    if not called then LightRP.log("fuel settlement failed: %s",tostring(ok)) end
    if called and ok==true and a.vehicle then
        -- contracts (dailies.lua): kind "vehicle" = pump, "pour" = jerrycan into a car
        local info=F.info(a.vehicle)
        LightRP.eachModule("onRefuelled",player,{kind=a.kind,vehicle=a.vehicle,litres=a.litres,
            before=info and math.max(0,info.litres-a.litres) or a.before or 0,capacity=info and info.capacity or 0})
    end
    clear(player,a,called and ok==true,called and ok and string.format("%.1f L · %s%s",a.litres,LightRP.money.format(a.price),
        a.kind=="pour" and (a.remaining>0 and " · Fuel remains in your can." or " · Empty can kept.") or "") or (reason or "Could not complete this fill."))
end)
function R.isActive(player) return sessions[player]~=nil end
function R.canCommit(player,a) return sessions[player]==a and a.phase=="committing" and valid(player,a)~=nil end
function R.cancel(player)
    local a=sessions[player]; if a and a.phase~="committing" then clear(player,a,false,nil,true) end
end
function R.onDisconnected(player) R.cancel(player); refreshed[player]=nil end
R.onCharacterLoaded=R.cancel; R.onCharacterActivated=R.cancel
AddEventHandler("open77:playerDamaged",function(player,_,amount)
    local a=sessions[tonumber(player)]; if a and a.phase~="committing" and (tonumber(amount) or 0)>0 then clear(tonumber(player),a,false,"Refuelling interrupted by damage. Nothing was charged.") end
end)
CreateThread(function()
    while true do
        Wait(200)
        for player,a in pairs(sessions) do
            if a.phase~="committing" then
                local p,why=valid(player,a)
                if not p or now()>a.expires then clear(player,a,false,why or "The pump reservation expired. Nothing was charged.") end
            end
        end
    end
end)
AddEventHandler("onResourceStop",function(name)
    if name==GetCurrentResourceName() then for player,a in pairs(sessions) do clear(player,a,false,nil,true) end end
end)
