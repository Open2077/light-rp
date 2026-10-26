-- RP ownership is durable; the client's native loadout is a replaceable projection.
local W,C,Db,Inv=LightRP.armament,LightRpArmament,LightRP.db,LightRP.inventory
local NET="op77_lightrp:armament"
local epochs,lastRequest,hashes={},{},{}
local now=function() return Open77.time.monotonic() end
local function alive(player)
    local c=LightRP.characters.get(player)
    local life=Open77.players.getLifeState(player)
    return c and c.status=="active" and life and life.phase=="alive"
end
local function current(rt)
    return rt and W.runtime[rt.player]==rt and Inv.player(rt.player) and Inv.player(rt.player).id==rt.inventory
end
W.current=current
local function handState(rt,s,hand)
    local id=s and s[hand];local inv=Inv.player(rt.player)
    local item=id and inv and W.find(inv,id)
    if not item then return nil end
    local spec=C.weapons[item.name];local observed=rt.observed and rt.observed[hand]
    return {instanceId=id,name=item.name,label=spec.label,record=spec.record,nativeSlot=hand=="right" and 1 or 4,
        magazine=observed and observed.magazine,capacity=observed and observed.capacity}
end
function W.view(player)
    local rt=W.runtime[player];local inv=Inv.player(player)
    if not rt or not inv or not current(rt) then return {ready=false,busy=false,revision=0,ammo={pistol={remaining=0,label="Pistol rounds · total"}},error="Your character inventory is not ready."} end
    local s=W.states[inv.id]
    return {inventoryId=inv.id,generation=rt.epoch,ready=Db.ready and rt.ready==true,busy=rt.busy==true and not rt.observing,revision=s and s.revision or 0,
        right=handState(rt,s,"right"),left=handState(rt,s,"left"),
        ammo={pistol={remaining=s and s.ammo or 0,label="Pistol rounds · total"}},error=rt.error}
end
function W.push(player)
    local rt=W.runtime[player]
    if rt and not current(rt) then return end
    TriggerClientEvent(NET,player,{kind="state",state=W.view(player)})
    if LightRP.grenades then LightRP.grenades.push(player) end
end
local function native(rt,method,operation,...)
    if not current(rt) or not alive(rt.player) then return nil,"Your character changed or is not alive." end
    local fn=Open77.weapons and Open77.weapons[method]
    if type(fn)~="function" then return nil,"The required weapon API is unavailable on this server." end
    local called,id,reason=pcall(fn,rt.player,...)
    if not called or not id then return nil,tostring(reason or id or "Weapon request refused.") end
    local key=tostring(rt.player)..":"..tostring(id)
    local job={runtime=rt,operation=operation,deadline=now()+12}
    W.pending[key]=job
    while current(rt) and not job.done and now()<job.deadline do Wait(25) end
    if not current(rt) then W.pending[key]=nil;return nil,"Your character incarnation changed." end
    if not job.done or (job.accepted~=true and job.reason=="request_timeout") then
        job.timedOut=true;rt.quarantine=job
        return nil,"A weapon request timed out and may still complete. Synchronization is quarantined until a late completion or a new character incarnation."
    end
    W.pending[key]=nil
    if job.accepted~=true then return nil,tostring(job.reason or "Native weapon request refused.") end
    return job.result or {}
end
W.native = native
AddEventHandler("open77:weapons:completed",function(player,id,operation,accepted,reason,result)
    local key=tostring(player)..":"..tostring(id)
    local job=W.pending[key]
    if not job or job.runtime.player~=tonumber(player) or job.operation~=operation or not current(job.runtime) then return end
    job.done,job.accepted,job.reason,job.result=true,accepted,reason,result
    if job.timedOut and reason~="request_timeout" then
        W.pending[key]=nil;job.runtime.quarantine=nil
        job.runtime.ready=false;job.runtime.error="The delayed native request settled. Synchronize to reconcile your equipment.";W.push(job.runtime.player)
    end
end)
local function rowsOf(result)
    if type(result)~="table" then return {} end
    local rows={}
    for _,row in ipairs(result.slots or result) do if type(row)=="table" and tonumber(row.slot) then rows[tonumber(row.slot)]=row end end
    return rows
end
local function ammo(row)
    local a=row and row.ammo
    if type(a)~="table" or not W.integer(a.total,0,1000000) or not W.integer(a.magazine,0,10000) or not W.integer(a.capacity,1,10000) or a.magazine>a.capacity then return nil end
    return a
end
local function empty(row)
    return not row or row.equipped==false or row.tweakDbId=="" or row.tweakDbId=="0x0000000000000000"
end
local function desired(rt)
    local inv=Inv.player(rt.player);local s=W.states[rt.inventory]
    if not inv or not s then return nil,"Your weapon inventory is unavailable." end
    local right=s.right and W.find(inv,s.right);local left=s.left and W.find(inv,s.left)
    if (s.right and not right) or (s.left and not left) then return nil,"An equipped firearm is missing from its inventory. Unequip it before synchronizing." end
    return {right=right and C.weapons[right.name],left=left and C.weapons[left.name],state=s}
end
local function saveState(rt,nextState,operation,mutation,changes)
    local writes={W.stateWrite(rt.inventory,nextState)}
    if mutation then writes[#writes+1]={query="INSERT INTO lightrp_armament_operations (inventory_id,mutation,operation,revision) VALUES (?,?,?,?)",values={rt.inventory,mutation,operation,nextState.revision}} end
    local ok,why=Inv.commitDrafts(changes or {},writes,function() W.states[rt.inventory]=nextState end)
    return ok,why
end
local function lowerBudget(rt,total)
    if not current(rt) then return false,"Character changed." end
    return Inv.transaction(rt.player,function(inv)
        if not current(rt) or inv.id~=rt.inventory then return false,"Character changed." end
        local s=W.states[inv.id]
        if total>=s.ammo then return true end
        local nextState=W.clone(s);nextState.ammo=total;nextState.revision=s.revision+1
        return saveState(rt,nextState,"observe")
    end)
end
local function settleExisting(rt,rows)
    if not rt.projectedRecords then return true end
    local total
    for slot,record in pairs(rt.projectedRecords) do
        local row=rows[slot]
        local a=ammo(row)
        if empty(row) or row.record~=record or not a then return false,"The previous native projection could not be reconciled. No ammunition was refunded." end
        total=math.min(total or a.total,a.total)
    end
    if total then return lowerBudget(rt,total) end
    return true
end
local function readback(rt,rows)
    local d,why=desired(rt);if not d then return false,why end
    local observed,total,allowedHashes={},nil,{}
    for _,entry in ipairs({{hand="right",slot=1,spec=d.right},{hand="left",slot=4,spec=d.left}}) do
        if entry.spec then
            local row=rows[entry.slot]
            if empty(row) or row.record~=entry.spec.record then return false,"The native weapon does not match the authorized loadout." end
            local a=ammo(row)
            if not a then return false,"Native ammunition is unavailable. No rounds were refunded." end
            local hash=tostring(row.tweakDbId):lower()
            hashes[hash]=true;allowedHashes[hash]=true
            observed[entry.hand]={magazine=a.magazine,capacity=a.capacity,reserve=a.reserve,total=a.total}
            total=math.min(total or a.total,a.total)
        end
    end
    if total then
        local ok,err=lowerBudget(rt,total);if not ok then return false,err or "Ammunition storage refused the observation." end
        if total>W.states[rt.inventory].ammo then return false,"Native ammunition exceeds the authorized stock. Synchronize to reset it." end
    end
    rt.observed=observed
    rt.allowedHashes=allowedHashes
    if d.left then
        local r,l=observed.right,observed.left
        if not r or not l or not W.integer(r.reserve,0,1000000) or r.reserve<r.capacity+l.capacity then
            return false,"Dual wield is paused at low reserve on this client build. Add ammunition or unequip the left pistol, then synchronize."
        end
    end
    return true
end
local function project(rt)
    local d,why=desired(rt);if not d then return false,why end
    local snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
    local rows=rowsOf(snapshot)
    local settled,settleError=settleExisting(rt,rows)
    if not settled then return false,settleError end
    -- From here until verified completion all native writes are pending
    -- projection, not gameplay. A retry may restore only this settled budget.
    rt.projectedRecords=nil
    if not d.right then
        local cleared,reason=native(rt,"clear","clear");if not cleared then return false,reason end
        for _,row in ipairs(cleared.slots or {}) do if row.accepted==false then return false,"Native weapon removal was only partially completed." end end
        rt.observed={};rt.allowedHashes={};return true
    end
    -- An old native item may remain after unequip. Try reuse first and create
    -- presentation inventory only after a definitive weapon_not_owned refusal.
    local policy,policyError=native(rt,"setDualWieldAllowed","setDualWieldAllowed",d.left~=nil)
    if not policy then return false,policyError end
    for slot=6,1,-1 do
        local spec=slot==1 and d.right or slot==4 and d.left or nil
        local row=rows[slot]
        if not empty(row) and (not spec or row.record~=spec.record) then
            local removed,reason=native(rt,"remove","remove",slot)
            if not removed and reason~="weapon_slot_empty" then return false,reason end
            rows[slot]=nil
        end
    end
    for _,entry in ipairs({{slot=1,spec=d.right},{slot=4,spec=d.left}}) do
        if entry.spec and (empty(rows[entry.slot]) or rows[entry.slot].record~=entry.spec.record) then
            local assigned,reason=native(rt,"assign","assign",entry.spec.record,entry.slot,{active=false,addToInventory=false})
            if not assigned and reason=="weapon_not_owned" then assigned,reason=native(rt,"assign","assign",entry.spec.record,entry.slot,{active=false,addToInventory=true}) end
            if not assigned then return false,reason end
        end
    end
    snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
    local prepared=rowsOf(snapshot)
    local r,l=ammo(prepared[1]),d.left and ammo(prepared[4]) or nil
    if not r or (d.left and not l) then return false,"Native pistol capacity could not be read. No ammunition was created." end
    if l and (prepared[1].ammo.tweakDbId~=prepared[4].ammo.tweakDbId or prepared[1].ammo.record~=prepared[4].ammo.record) then return false,"These pistols do not share compatible native ammunition." end
    local balance=W.states[rt.inventory].ammo
    if l and balance<2*(r.capacity+l.capacity) then return false,"Dual wield needs at least "..(2*(r.capacity+l.capacity)).." total rounds on this build. Open more boxes or unequip the left pistol." end
    local magR=math.min(r.capacity,balance)
    local magL=l and math.min(l.capacity,balance-magR) or 0
    -- Reset both magazine projections first. Each following operation expresses
    -- an exact remaining pool; no hand's shared reserve is added twice.
    local changed,reason=native(rt,"setAmmo","setAmmo",1,{magazine=0,reserve=0})
    if not changed then return false,reason end
    if l then changed,reason=native(rt,"setAmmo","setAmmo",4,{magazine=0,reserve=0});if not changed then return false,reason end end
    changed,reason=native(rt,"setAmmo","setAmmo",1,{magazine=magR,reserve=balance-magR})
    if not changed then return false,reason end
    if l then changed,reason=native(rt,"setAmmo","setAmmo",4,{magazine=magL,reserve=balance-magR-magL});if not changed then return false,reason end end
    local active,activeError=native(rt,"setActive","setActive",1);if not active then return false,activeError end
    snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
    local verified,verificationError=readback(rt,rowsOf(snapshot))
    if verified then rt.projectedRecords={[1]=d.right.record};if d.left then rt.projectedRecords[4]=d.left.record end end
    return verified,verificationError
end
function W.synchronize(player,onlyObserve)
    local rt=W.runtime[player]
    if not current(rt) then return false,"Your character is not ready." end
    if rt.busy then return false,"Weapon synchronization is already in progress." end
    if rt.quarantine then return false,"An ambiguous native request is quarantined. Wait for its completion or reconnect." end
    if not alive(player) then return false,"Your character must be alive to synchronize weapons." end
    rt.busy=true;rt.observing=onlyObserve==true
    if not onlyObserve then rt.ready=false;rt.error=nil;W.push(player) end
    CreateThread(function()
        local ok,result,why=pcall(function()
            if onlyObserve then
                local snap,error=native(rt,"requestSnapshot","snapshot");if not snap then return false,error end
                return readback(rt,rowsOf(snap))
            end
            return project(rt)
        end)
        if not current(rt) then return end
        rt.busy=false;rt.observing=false
        rt.ready=ok and result==true
        if rt.ready then rt.error=nil else rt.error=tostring(ok and why or result) end
        -- A low-reserve dual cannot keep firing while its ambiguous native
        -- reload is reconciled. Durable intent remains; the player may unequip.
        if not rt.ready then rt.observed=rt.observed or {} end
        W.push(player)
    end)
    return true
end
local function requestKey(p)
    return type(p.mutation)=="string" and #p.mutation>=8 and #p.mutation<=96 and p.mutation:match("^[%w:_%-]+$") and p.mutation or nil
end
local function apply(player,p,inv,reserved)
    local rt=W.runtime[player]
    if not current(rt) or rt.inventory~=inv.id then return false,"Your character changed." end
    if rt.busy and not reserved then return false,"Weapon synchronization is in progress." end
    if not alive(player) then return false,"Your character must be alive." end
    local s,error=W.load(inv);if not s then return false,error end
    local mutation=requestKey(p);if not mutation then return false,"Invalid armament request key." end
    local ok,previous=Db.read("SELECT operation FROM lightrp_armament_operations WHERE inventory_id=? AND mutation=?",{inv.id,mutation})
    if not ok then return false,"Armament storage is unavailable." end
    if previous[1] then
        if previous[1].operation==p.operation then return true end
        return false,"This request key was used for another operation."
    end
    if not W.integer(p.baseRevision,0,2147483646) or p.baseRevision~=s.revision then return false,"Your equipment changed. Refresh before retrying." end
    local nextState=W.clone(s);local changes={}
    if p.operation=="equip" then
        if p.hand~="right" and p.hand~="left" then return false,"Choose a hand." end
        local item=inv.items[tonumber(p.slot)]
        if not item or not C.weapons[item.name] or not item.metadata or item.metadata.instanceId~=p.instanceId then return false,"That firearm slot or serial changed." end
        if p.hand=="left" and not nextState.right then return false,"Equip a right-hand pistol first." end
        if nextState[p.hand=="right" and "left" or "right"]==p.instanceId then return false,"One firearm cannot occupy both hands." end
        local other=nextState[p.hand=="right" and "left" or "right"]
        local otherItem=other and W.find(inv,other)
        if otherItem and C.weapons[otherItem.name].record==C.weapons[item.name].record then return false,"Two identical pistol models are not supported by this tested projection yet." end
        nextState[p.hand]=p.instanceId
    elseif p.operation=="unequip" then
        if p.hand~="right" and p.hand~="left" then return false,"Choose a hand." end
        if p.instanceId and nextState[p.hand]~=p.instanceId then return false,"The equipped firearm changed." end
        nextState[p.hand]=nil
        if p.hand=="right" then nextState.left=nil end
    elseif p.operation=="ammo" then
        local slot=tonumber(p.slot);local item=slot and inv.items[slot]
        local box=item and C.boxes[item.name]
        if not box or item.count<1 then return false,"That ammunition box is no longer available." end
        if nextState.ammo+box.rounds>C.maxAmmo then return false,"This character's ammunition stock is full. The box was kept." end
        local draft=Inv.draft(inv);draft.items[slot].count=draft.items[slot].count-1
        if draft.items[slot].count==0 then draft.items[slot]=nil end
        changes={{inv,draft}};nextState.ammo=nextState.ammo+box.rounds
    else return false,"Unknown armament mutation." end
    nextState.revision=s.revision+1
    local saved,why=saveState(rt,nextState,p.operation,mutation,changes)
    if not saved then return false,why or "Armament storage refused the change." end
    rt.error=nil;rt.ready=not nextState.right
    return true
end
-- Native reads never hold the general inventory mutex. Settle the old native
-- pool before granting a box or changing intent, otherwise clicking Sync/equip
-- between shot and poll could restore already-spent rounds.
local function beginMutation(player,p,callback)
    local rt=W.runtime[player]
    if not current(rt) or rt.busy then return false,"Weapon synchronization is in progress or the character is unavailable." end
    if rt.quarantine then return false,"A timed-out native request is quarantined until completion or reconnect." end
    if not alive(player) then return false,"Your character must be alive." end
    local wasReady=rt.ready
    local settled=not rt.projectedRecords
    local beforeRevision=W.states[rt.inventory] and W.states[rt.inventory].revision
    local payload=W.clone(p)
    rt.busy=true;W.push(player)
    CreateThread(function()
        local called,success,why=pcall(function()
            if rt.projectedRecords then
                local snapshot,error=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,error end
                local ok,reason=settleExisting(rt,rowsOf(snapshot));if not ok then return false,reason end
            end
            settled=true
            if not current(rt) then return false,"Character changed." end
            if payload.baseRevision==beforeRevision then payload.baseRevision=W.states[rt.inventory].revision end
            local ok,error=Inv.transaction(player,function(inv) return apply(player,payload,inv,true) end)
            return ok,error,"validated"
        end)
        if not current(rt) then return end
        rt.busy=false
        if not called or not success then
            rt.ready=called and settled and wasReady and not rt.quarantine or false
            rt.error=tostring(called and why or success)
            W.push(player)
            if callback then callback(false,rt.error) else LightRP.notice(player,{kind="error",title="Equipment",body=rt.error}) end
            return
        end
        -- Preflight settled the previous projection before this transaction.
        -- Its old native total must not subtract a newly credited ammo box a
        -- second time when the fresh projection begins.
        rt.projectedRecords=nil
        W.push(player);W.synchronize(player)
        if callback then callback(true) end
    end)
    return true
end
W.beginMutation=beginMutation
local function attach(player)
    local inv=Inv.player(player)
    if not inv or not inv.persistent or inv.kind~="player" then return end
    local prior=W.runtime[player]
    if prior and current(prior) then return end
    epochs[player]=(epochs[player] or 0)+1
    local rt={player=player,inventory=inv.id,epoch=epochs[player],ready=false,busy=false,observed={}}
    W.runtime[player]=rt
    local s,why=W.load(inv)
    if not s then rt.error=why;W.push(player);return end
    rt.ready=false;W.push(player)
    -- Clear a previous/native single-player loadout even when this RP
    -- character owns no equipped firearm. No projection is implicitly trusted.
    if alive(player) then W.synchronize(player) end
end
local function retire(player,reason)
    local rt=W.runtime[player]
    if rt then rt.ready=false;rt.error=reason;rt.busy=false;W.push(player) end
    W.runtime[player]=nil
    for key,job in pairs(W.pending) do if job.runtime.player==player then W.pending[key]=nil end end
end
LightRP.module("armament",{
    onDatabaseReady=function() W.loaded=true;LightRP.log("armament ready: serialized firearms, 30-round boxes and native projection queue enabled");for _,id in ipairs(GetPlayers()) do attach(tonumber(id)) end end,
    onCharacterLoaded=function(player) retire(player,"Character changed.");attach(player) end,
    onCharacterActivated=function(player) retire(player,"Character changed.");attach(player) end,
    onGameplayReady=function(player) attach(player);local rt=W.runtime[player];if rt and not rt.busy and alive(player) then W.synchronize(player) end end,
    onDisconnected=function(player) retire(player,"Disconnected.");lastRequest[player]=nil end,
    onLifeState=function(player,phase)
        if phase~="alive" then
            retire(player,"Weapon projection waits for a living character.")
        else attach(player) end
    end,
    onUiReady=function(player) attach(player);W.push(player) end,
})
RegisterNetEvent(NET,function(p)
    local player=tonumber(source)
    if not player or player<=0 or type(p)~="table" or type(p.request)~="string" or #p.request>96 or #p.request==0 then return end
    local operation=p.operation
    if type(operation)~="string" then return end
    local at=now()
    if lastRequest[player] and at-lastRequest[player]<.15 then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Please wait before the next equipment request."});return end
    lastRequest[player]=at
    attach(player)
    local rt=W.runtime[player]
    local ok,error=true,nil
    if operation=="state" then
        W.push(player)
    elseif operation=="sync" then ok,error=W.synchronize(player)
    elseif operation=="holster" then
        if not current(rt) or rt.busy or rt.quarantine then ok,error=false,"Your weapon projection is not ready."
        else
            rt.busy=true;W.push(player)
            CreateThread(function()
                local result,why=native(rt,"holster","holster")
                if current(rt) then rt.busy=false;rt.error=result and nil or why;W.push(player) end
            end)
        end
    elseif operation=="equip" or operation=="unequip" or operation=="ammo" then
        ok,error=beginMutation(player,p,function(accepted,why)
            if not current(rt) then return end
            TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=accepted,error=why,data={state=W.view(player)}})
        end)
        if ok then return end -- final reply is sent only after the intent/box transaction settles
    else ok,error=false,"Unknown equipment operation." end
    if rt and not current(rt) then return end
    TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=ok==true,error=error,data={state=W.view(player)}})
end)
-- Generic item use routes to the same transaction, already under Inv.use's lock.
for name in pairs(C.boxes) do Inv.onUse(name,function(player,item)
    attach(player);local inv=Inv.player(player);local slot
    for k,v in pairs(inv and inv.items or {}) do if v==item then slot=k;break end end
    local s=inv and W.states[inv.id]
    local mutation=W.uuid()
    if not slot or not s or not mutation then return false end
    local ok,why=beginMutation(player,{operation="ammo",slot=slot,baseRevision=s.revision,mutation="box:"..mutation})
    if ok then return "keep" end
    LightRP.notice(player,{kind="error",title="Ammunition",body=why});return false
end) end
for name in pairs(C.weapons) do Inv.onUse(name,function(player,item)
    attach(player);local inv=Inv.player(player);local slot
    for k,v in pairs(inv and inv.items or {}) do if v==item then slot=k;break end end
    local s=inv and W.states[inv.id];local mutation=W.uuid()
    if not slot or not s or not mutation then return false end
    local ok,why=beginMutation(player,{operation="equip",hand=(s.left== (item.metadata and item.metadata.instanceId) and "left" or "right"),slot=slot,instanceId=item.metadata and item.metadata.instanceId,baseRevision=s.revision,mutation="equip:"..mutation})
    if ok then return "keep" end
    LightRP.notice(player,{kind="error",title="Equipment",body=why});return false
end) end
CreateThread(function()
    while true do
        for player,rt in pairs(W.runtime) do
            local s=W.states[rt.inventory]
            if current(rt) and s and s.right and rt.ready and not rt.busy and alive(player) then W.synchronize(player,true) end
        end
        Wait(2000)
    end
end)
-- This gate authorizes known RP firearm damage; it does not count shots. The
-- native cache remains client-reported and is never used to mint ammunition.
local function damageGate(event)
    if type(event)~="table" or event.source=="vehicle" then return nil end
    local player=tonumber(event.attacker)
    if not player or player<=0 then return nil end
    local rt=W.runtime[player]
    local hash=tostring(event.weaponTdbId or ""):lower()
    local managed=hashes[hash]
    if not managed and event.attackKind~="ranged" then return nil end
    if not rt then return false end
    local s=W.states[rt.inventory]
    if not s or not s.right then return false end
    if (rt.busy and not rt.observing) or not rt.ready or s.ammo<=0 then return false end
    if not rt.allowedHashes or not rt.allowedHashes[hash] then return false end
    return nil
end
W.damageGate=damageGate
local arbiter
if Open77.combat and Open77.combat.onDamage then
    arbiter=Open77.combat.onDamage(function(event)
        local ok,result=pcall(damageGate,event)
        if not ok then return false end
        return result
    end)
end
AddEventHandler("onResourceStop",function(name)
    if name==GetCurrentResourceName() and arbiter and Open77.combat.offDamage then Open77.combat.offDamage(arbiter) end
end)
