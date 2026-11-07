local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
local expireFlags, expireFlag = LightRP.expireFlags or function() end, LightRP.expireFlag or function() end -- framework.lua
-- RP ownership is durable; the client's native loadout is a replaceable projection.
local W,C,Db,Inv=LightRP.armament,LightRpArmament,LightRP.db,LightRP.inventory
local NET="op77_lightrp:armament"
local epochs,lastRequest,hashes={},{},{}
local now=function() return Open77.time.monotonic() end
local drain -- defined with the request queue, used by every busy spell's end
-- Players whose world and body exist (open77:session:gameplayReady). A native request sent during
-- the loading screen times out (10 s) and quarantined the weapons (lab 2026-11-05): nothing native
-- goes out before, the synchronization waits for onGameplayReady.
local inWorld={}
function W.inWorld(player) return inWorld[tonumber(player) or player]==true end
-- One trace per player request (select / equip / holster ...): when the weapon was in hand,
-- when everything settled, every native round trip and its time. One log line at the end.
local function traceStart(rt,operation)
    if rt then rt.trace={operation=operation,t0=now(),calls=0,nativeMs=0,ops={}} end
end
local function traceMark(rt,key)
    local tr=rt and rt.trace
    if tr and not tr[key] then tr[key]=math.floor((now()-tr.t0)*1000+0.5) end
end
local function traceEnd(rt,result,why)
    local tr=rt and rt.trace
    if not tr then return end
    rt.trace=nil
    LightRP.log("armament: trace %s player %d: %s, in hand %s ms, done %d ms, db until %s ms, %d native (%d ms) %s%s",
        tr.operation,rt.player,result and "ok" or "failed",tostring(tr.drawn or "-"),math.floor((now()-tr.t0)*1000+0.5),tostring(tr.tx or "-"),
        tr.calls,math.floor(tr.nativeMs+0.5),table.concat(tr.ops," "),why and (" · "..tostring(why)) or "")
end
local function alive(player)
    local c=LightRP.characters.get(player)
    local life=Open77.players.getLifeState(player)
    return c and c.status=="active" and life and life.phase=="alive"
end
local function current(rt)
    return rt and W.runtime[rt.player]==rt and Inv.player(rt.player) and Inv.player(rt.player).id==rt.inventory
end
W.current=current
-- Rounds of one ammunition type in an inventory (or a draft): the only stock.
local function rounds(inv,kind)
    local spec=C.ammo[kind];local n=0
    if not spec then return 0 end
    for _,item in pairs(inv and inv.items or {}) do if item.name==spec.item then n=n+item.count end end
    return n
end
W.rounds=rounds
local function takeRounds(draft,kind,count)
    local name=C.ammo[kind].item;local removing=count
    for slot=draft.slots,1,-1 do
        local item=draft.items[slot]
        if removing>0 and item and item.name==name then
            local n=math.min(removing,item.count);item.count=item.count-n;removing=removing-n
            if item.count==0 then draft.items[slot]=nil end
        end
    end
    return count-removing
end
local function handState(rt,s,hand)
    local id=s and s[hand];local inv=Inv.player(rt.player)
    local item=id and inv and W.find(inv,id)
    if not item then return nil end
    local spec=C.weapons[item.name];local observed=rt.observed and rt.observed[hand]
    return {instanceId=id,name=item.name,label=spec.label,record=spec.record,nativeSlot=hand=="right" and 1 or 4,
        ammo=spec.ammo,class=spec.class,dual=spec.dual==true,
        magazine=observed and observed.magazine,capacity=observed and observed.capacity}
end
-- Every serialized weapon in the pockets, for the weapon wheel: handguns first,
-- then by class and name, with the rounds of its ammunition type in the pockets.
local CLASS_ORDER = { pistol = 1, revolver = 2, smg = 3, shotgun = 4, rifle = 5, lmg = 6, precision = 7, sniper = 8 }
local function arsenal(inv, s)
    local list = {}
    for slot, item in pairs(inv and inv.items or {}) do
        local spec = C.weapons[item.name]
        local id = spec and type(item.metadata) == "table" and item.metadata.instanceId
        if id then
            local template = LightRpItems[item.name] or {}
            list[#list + 1] = { slot = slot, instanceId = id, name = item.name, label = spec.label, class = spec.class,
                ammo = spec.ammo, ammoLabel = C.ammo[spec.ammo] and C.ammo[spec.ammo].label, rounds = rounds(inv, spec.ammo),
                image = template.image, dual = spec.dual == true,
                hand = s and (s.right == id and "right" or s.left == id and "left") or nil }
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = CLASS_ORDER[a.class] or 9, CLASS_ORDER[b.class] or 9
        if ca ~= cb then return ca < cb end
        if a.label ~= b.label then return a.label < b.label end
        return a.instanceId < b.instanceId
    end)
    while #list > 15 do table.remove(list) end
    return list
end
W.arsenal = arsenal
-- A mission that hands out its own loadout (an authored mission's kit, the raid) or drawn
-- Mantis Blades own the native slots: the armament stands aside, and its client must not
-- gate the attack on an RP weapon state it is not maintaining. After a death in a mission
-- the state stayed "not ready" (synchronize returns early while standing aside) and the
-- kit could not fire (2026-11-02).
function W.standsAside(player)
    return (LightRP.missions and LightRP.missions.handlesLoadout and LightRP.missions.handlesLoadout(player))
        or (LightRP.cyberware and LightRP.cyberware.handlesLoadout and LightRP.cyberware.handlesLoadout(player))
        -- an activity without caps.rpWeapons hands out its own (server/modules/activities.lua)
        or (LightRP.activities and not LightRP.activities.allows(player, "rpWeapons"))
        -- a temporary kit, whatever the activity's caps (server/modules/activity_kits.lua)
        or (LightRP.activities and LightRP.activities.handlesLoadout and LightRP.activities.handlesLoadout(player))
        or false
end
-- Who handed this player a kit, a mission or an activity: both answer kitOf and drawKit.
local function kitSource(player)
    for _,source in ipairs({LightRP.missions or false,LightRP.activities or false}) do
        local kit=source and source.kitOf and source.kitOf(player)
        if kit then return source,kit end
    end
end
-- With a kit, the wheel lists its weapons (instanceId "kit:<slot>"), drawn back by the
-- source's drawKit. A kit of one weapon lists one.
local function kitArsenal(player)
    local source,kit=kitSource(player)
    if not kit then return nil end
    local names=type(kit.names)=="table" and kit.names or {}
    local scope=source==LightRP.activities and "match" or nil
    local list={{slot=1,instanceId="kit:1",name="kit",label=names[1] or tostring(kit.primary),class="kit",kit=true,kitScope=scope}}
    if kit.secondary then list[2]={slot=2,instanceId="kit:2",name="kit",label=names[2] or tostring(kit.secondary),class="kit",kit=true,kitScope=scope} end
    return list
end
function W.view(player)
    local rt=W.runtime[player];local inv=Inv.player(player)
    if not rt or not inv or not current(rt) then return {ready=false,busy=false,revision=0,ammo={pistol={remaining=0,label="Pistol rounds"}},error="Your character inventory is not ready."} end
    local s=W.states[inv.id]
    local stock={};for kind,spec in pairs(C.ammo) do stock[kind]={remaining=rounds(inv,kind),label=spec.label,item=spec.item} end
    return {inventoryId=inv.id,generation=rt.epoch,ready=Db.ready and rt.ready==true,busy=rt.busy==true and not rt.observing,revision=s and s.revision or 0,
        right=handState(rt,s,"right"),left=handState(rt,s,"left"),
        ammo=stock,error=rt.error,holstered=rt.holstered==true,arsenal=kitArsenal(player) or arsenal(inv,s),standAside=W.standsAside(player)==true}
end
function W.push(player)
    local rt=W.runtime[player]
    if rt and not current(rt) then return end
    TriggerClientEvent(NET,player,{kind="state",state=W.view(player)})
    if LightRP.grenades then LightRP.grenades.push(player) end
end
-- A request the platform itself timed out (completed with request_timeout) never completes
-- later: the platform forgets it and ignores the client's late answer. Waiting for a
-- completion left the player quarantined until a reconnect ("NOT EQUIPPED: A timed-out
-- native request is quarantined", 2026-11-04, a slow client). Such a quarantine is lifted
-- after RECOVER_DELAY s and a full synchronization (a fresh snapshot, then the projection)
-- reconciles whatever the client did apply. At most RECOVER_MAX in RECOVER_WINDOW s; past
-- that the quarantine stays until a reconnect, as before. A request still unanswered keeps
-- waiting for its completion.
local RECOVER_DELAY,RECOVER_MAX,RECOVER_WINDOW,RECOVER_SLOW=3,3,120,30
local SYNC_RETRIES,SYNC_RETRY_MS=3,1500
function W.recover(rt)
    local job=rt and rt.quarantine
    if not job or not job.final or rt.recovering or not current(rt) then return false end
    local t,recent=now(),{}
    for _,at in ipairs(rt.recoveries or {}) do if t-at<RECOVER_WINDOW then recent[#recent+1]=at end end
    rt.recoveries=recent
    -- past RECOVER_MAX in the window it keeps trying, slower (it used to wait for a reconnect:
    -- weapons dead for the whole session)
    local delay=RECOVER_DELAY
    if #recent>=RECOVER_MAX then
        delay=RECOVER_SLOW
        LightRP.log("armament: player %d quarantined again after %d recoveries in %d s: next try in %d s",rt.player,#recent,RECOVER_WINDOW,delay)
    end
    recent[#recent+1]=t
    rt.recovering=true
    CreateThread(function()
        Wait(delay*1000)
        -- the request's own thread may still be closing (busy): give it a moment
        local waited=0
        while current(rt) and rt.busy and waited<10000 do Wait(250);waited=waited+250 end
        rt.recovering=false
        if not current(rt) or rt.quarantine~=job then return end
        for key,pending in pairs(W.pending) do if pending==job then W.pending[key]=nil end end
        rt.quarantine=nil;rt.ready=false;rt.error="Resynchronizing your equipment after a timed-out request."
        LightRP.log("armament: player %d %s request timed out on the platform: quarantine lifted, resynchronizing",rt.player,tostring(job.operation))
        W.push(rt.player)
        if not W.synchronize(rt.player) then rt.error="Your equipment will resynchronize when you can hold a weapon again.";W.push(rt.player) end
    end)
    return true
end
-- A native request is sent (issue) then awaited (settle). Requests to one player run in order on
-- the client, so a known sequence (remove, assign, setAmmo) can be sent at once and awaited once:
-- each round trip costs ~200 ms even on a local server (measured 2026-11-05).
local function issue(rt,api,method,operation,...)
    if not current(rt) or not alive(rt.player) then return nil,"Your character changed or is not alive." end
    local fn=api and api[method]
    if type(fn)~="function" then return nil,"The required weapon API is unavailable on this server." end
    local t0=now()
    local called,id,reason=pcall(fn,rt.player,...)
    if not called or not id then return nil,tostring(reason or id or "Weapon request refused.") end
    local key=tostring(rt.player)..":"..tostring(id)
    local job={runtime=rt,operation=operation,deadline=now()+12,key=key,method=method,t0=t0}
    W.pending[key]=job
    return job
end
local function settle(rt,job)
    local key,method,t0=job.key,job.method,job.t0
    while current(rt) and not job.done and now()<job.deadline do Wait(25) end
    if not current(rt) then W.pending[key]=nil;return nil,"Your character incarnation changed." end
    if not job.done or (job.accepted~=true and job.reason=="request_timeout") then
        job.timedOut=true;rt.quarantine=job
        -- the platform already answered request_timeout: final, nothing more will come
        if job.done then job.final=true;W.recover(rt) end
        return nil,"A weapon request timed out and may still complete. Synchronization is quarantined until a late completion or a new character incarnation."
    end
    W.pending[key]=nil
    local tr=rt.trace
    if tr then local ms=(now()-t0)*1000;tr.calls=tr.calls+1;tr.nativeMs=tr.nativeMs+ms;tr.ops[#tr.ops+1]=method.."="..math.floor(ms+0.5) end
    if job.accepted~=true then return nil,tostring(job.reason or "Native weapon request refused.") end
    return job.result or {}
end
local function nativeUsing(rt,api,method,operation,...)
    local job,err=issue(rt,api,method,operation,...)
    if not job then return nil,err end
    return settle(rt,job)
end
local function native(rt,method,operation,...) return nativeUsing(rt,Open77.weapons,method,operation,...) end
W.native = native
function W.nativeConsumable(rt,method,...) return nativeUsing(rt,Open77.consumables,method,"consumable",...) end
AddEventHandler("open77:weapons:completed",function(player,id,operation,accepted,reason,result)
    local key=tostring(player)..":"..tostring(id)
    local job=W.pending[key]
    if not job or job.runtime.player~=tonumber(player) or job.operation~=operation or not current(job.runtime) then return end
    job.done,job.accepted,job.reason,job.result=true,accepted,reason,result
    if job.timedOut and reason~="request_timeout" then
        W.pending[key]=nil;job.runtime.quarantine=nil
        job.runtime.ready=false;job.runtime.error="The delayed native request settled. Synchronize to reconcile your equipment.";W.push(job.runtime.player)
    elseif job.timedOut and job.runtime.quarantine==job then
        -- the platform's own timeout reached after ours: final as well
        job.final=true;W.recover(job.runtime)
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
    local spec=right and C.weapons[right.name];local other=left and C.weapons[left.name]
    if spec and not C.ammo[spec.ammo] then return nil,"This firearm has no known ammunition type." end
    if other and other.ammo~=spec.ammo then return nil,"These two weapons do not use the same ammunition." end
    return {right=spec,left=other,state=s,ammo=spec and spec.ammo}
end
local function saveState(rt,nextState,operation,mutation,changes)
    local writes={W.stateWrite(rt.inventory,nextState)}
    if mutation then writes[#writes+1]={query="INSERT INTO lightrp_armament_operations (inventory_id,mutation,operation,revision) VALUES (?,?,?,?)",values={rt.inventory,mutation,operation,nextState.revision}} end
    local ok,why=Inv.commitDrafts(changes or {},writes,function() W.states[rt.inventory]=nextState end)
    return ok,why
end
-- `rt.baseline` is what the native pool holds if nothing was fired: {kind, rounds}
-- (rounds projected) and `held` (rounds of that type in the pockets at that time).
-- A lower native total is spent ammunition: it leaves the inventory, in a transaction.
-- A higher one was never granted: firing stops until a synchronization resets it.
local function consume(rt,total,resetting)
    if not current(rt) then return false,"Character changed." end
    local base=rt.baseline
    if not base then return true end
    if total>base.rounds then
        -- a synchronization replaces the pool with the pockets: nothing was spent
        if resetting then return true end
        return false,"Native ammunition exceeds the rounds in your inventory. Synchronize to reset it."
    end
    local spent=base.rounds-total
    if spent==0 then return true end
    local removed=0
    local ok,why=Inv.transaction(rt.player,function(inv)
        if not current(rt) or inv.id~=rt.inventory then return false,"Character changed." end
        local draft=Inv.draft(inv)
        removed=takeRounds(draft,base.kind,math.min(spent,rounds(inv,base.kind)))
        if removed==0 then return true end
        return Inv.commitDrafts({{inv,draft}},{})
    end)
    if not ok then return false,why or "Spent rounds could not be removed from your inventory." end
    base.rounds=total;base.held=math.max(0,base.held-removed)
    LightRP.log("armament: player %d fired %d %s round(s), %d left in the inventory",rt.player,spent,base.kind,rounds(Inv.player(rt.player),base.kind))
    return true
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
    if total then return consume(rt,total,true) end
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
        local ok,err=consume(rt,total);if not ok then return false,err or "Spent rounds could not be recorded." end
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
-- magazine capacity per native record, learned from snapshots (it never changes for a record)
local capacityOf={}
-- After the weapon is set: when it was in hand, the projection baseline, the verification
-- snapshot and, for holstered hands, the holster.
local function finishProjection(rt,d,balance,held)
    if not rt.holstered then traceMark(rt,"drawn") end
    rt.baseline={kind=d.ammo,rounds=balance,held=held}
    local snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
    local verified,verificationError=readback(rt,rowsOf(snapshot))
    if verified then rt.projectedRecords={[1]=d.right.record};if d.left then rt.projectedRecords[4]=d.left.record end end
    -- a character coming into the world (connect, respawn) gets its loadout back in
    -- the holster, never in its hands; so does a pocket refresh of holstered hands
    if verified and rt.holstered then
        local holstered,why=native(rt,"holster","holster")
        if not holstered then LightRP.log("armament: holster after projection refused for %d: %s",rt.player,tostring(why)) end
    end
    return verified,verificationError
end
local function project(rt)
    local d,why=desired(rt)
    if not d then
        -- no valid loadout: no native weapon may stay in hand (a mission kit left over, a
        -- stale projection). The kit once stayed after a mission because of this return.
        local cleared=native(rt,"clear","clear")
        if cleared then rt.observed={};rt.allowedHashes={};rt.projectedRecords=nil;rt.baseline=nil end
        return false,why
    end
    -- the snapshot a mutation took a moment ago (beginMutation's preflight) still describes the
    -- slots: only the database changed since. One round trip saved on every weapon switch.
    local rows
    if rt.freshRows and rt.freshAt and now()-rt.freshAt<1.5 then rows=rt.freshRows end
    rt.freshRows,rt.freshAt=nil,nil
    if not rows then
        local snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
        rows=rowsOf(snapshot)
    end
    local settled,settleError=settleExisting(rt,rows)
    if not settled then return false,settleError end
    local migrated,migrateError=W.migrateLegacy(rt);if not migrated then return false,migrateError end
    -- From here until verified completion all native writes are pending
    -- projection, not gameplay. A retry may restore only the rounds in the pockets.
    rt.projectedRecords=nil;rt.baseline=nil
    if not d.right then
        rt.baseline=nil
        local cleared,reason=native(rt,"clear","clear");if not cleared then return false,reason end
        for _,row in ipairs(cleared.slots or {}) do if row.accepted==false then return false,"Native weapon removal was only partially completed." end end
        rt.observed={};rt.allowedHashes={};return true
    end
    -- An old native item may remain after unequip. Try reuse first and create
    -- presentation inventory only after a definitive weapon_not_owned refusal.
    -- the dual-wield policy only changes with a left-hand pistol: not sent again when it is the same
    if rt.dualAllowed~=(d.left~=nil) then
        local policy,policyError=native(rt,"setDualWieldAllowed","setDualWieldAllowed",d.left~=nil)
        if not policy then return false,policyError end
        rt.dualAllowed=d.left~=nil
    end
    -- A single weapon whose capacity and assign mode are known: removes, assign and the ammunition
    -- with the draw go out at once and are awaited once. Any refusal falls back to the sequential
    -- path below from a fresh snapshot (and this runtime stops pipelining).
    -- a record this incarnation never assigned is not in the native inventory yet (the plain assign
    -- answers weapon_not_owned at every first switch): its presentation item is created at once
    local mode=rt.assignMode and rt.assignMode[d.right.record]
    if mode==nil then mode=true end
    local cap=capacityOf[d.right.record]
    if not d.left and cap and mode~=nil and not rt.noPipeline then
        local held=rounds(Inv.player(rt.player),d.ammo)
        local balance=math.min(held,C.maxAmmo)
        local magR=math.min(cap,balance)
        local drawAtOnce=not rt.holstered
        local jobs,failed={},nil
        local function add(accept,method,operation,...)
            if failed then return end
            local job,err=issue(rt,Open77.weapons,method,operation,...)
            if not job then failed=err;return end
            jobs[#jobs+1]={job=job,accept=accept}
        end
        for slot=6,1,-1 do
            local row=rows[slot]
            if not empty(row) and slot~=1 then
                add(function(why) return why=="weapon_slot_empty" end,"remove","remove",slot)
            end
        end
        if empty(rows[1]) or rows[1].record~=d.right.record then
            add(nil,"assign","assign",d.right.record,1,{active=false,addToInventory=mode})
        end
        add(nil,"setAmmo","setAmmo",1,{magazine=magR,reserve=balance-magR,activate=drawAtOnce or nil})
        local last
        for _,j in ipairs(jobs) do
            local res,why=settle(rt,j.job)
            if res then last=res elseif not (j.accept and j.accept(why)) then failed=failed or why end
        end
        if not failed then
            if drawAtOnce and not (type(last)=="table" and last.drawn==true) then
                local active,activeError=native(rt,"setActive","setActive",1);if not active then return false,activeError end
            end
            return finishProjection(rt,d,balance,held)
        end
        if not current(rt) then return false,failed end
        LightRP.log("armament: player %d pipelined switch refused (%s): sequential",rt.player,tostring(failed))
        rt.noPipeline=true
        local snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
        rows=rowsOf(snapshot)
    end
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
            local added=false
            local assigned,reason=native(rt,"assign","assign",entry.spec.record,entry.slot,{active=false,addToInventory=false})
            if not assigned and reason=="weapon_not_owned" then added=true;assigned,reason=native(rt,"assign","assign",entry.spec.record,entry.slot,{active=false,addToInventory=true}) end
            if not assigned then return false,reason end
            rt.assignMode=rt.assignMode or {};rt.assignMode[entry.spec.record]=added
        end
    end
    -- a single weapon whose magazine capacity is already known needs no snapshot here
    local r,l
    if not d.left and capacityOf[d.right.record] then
        r={capacity=capacityOf[d.right.record]}
    else
        local snapshot,err=native(rt,"requestSnapshot","snapshot");if not snapshot then return false,err end
        local prepared=rowsOf(snapshot)
        r,l=ammo(prepared[1]),d.left and ammo(prepared[4]) or nil
        if r and W.integer(r.capacity,1,100000) then capacityOf[d.right.record]=r.capacity end
        if l and (prepared[1].ammo.tweakDbId~=prepared[4].ammo.tweakDbId or prepared[1].ammo.record~=prepared[4].ammo.record) then return false,"These pistols do not share compatible native ammunition." end
    end
    if not r or (d.left and not l) then return false,"Native pistol capacity could not be read. No ammunition was created." end
    local held=rounds(Inv.player(rt.player),d.ammo)
    local balance=math.min(held,C.maxAmmo)
    if l and balance<2*(r.capacity+l.capacity) then return false,"Dual wield needs at least "..(2*(r.capacity+l.capacity)).." "..C.ammo[d.ammo].label:lower().." in your pockets on this build. Unpack more boxes or unequip the left pistol." end
    local magR=math.min(r.capacity,balance)
    local magL=l and math.min(l.capacity,balance-magR) or 0
    -- Reset both magazine projections first. Each following operation expresses
    -- an exact remaining pool; no hand's shared reserve is added twice.
    -- (a single weapon has no shared reserve to reset: its exact pool is set at once, and drawn in
    -- the same request when it goes to the hands)
    local changed,reason
    if l then
        changed,reason=native(rt,"setAmmo","setAmmo",1,{magazine=0,reserve=0})
        if not changed then return false,reason end
        changed,reason=native(rt,"setAmmo","setAmmo",4,{magazine=0,reserve=0});if not changed then return false,reason end
    end
    local drawAtOnce=not l and not rt.holstered
    changed,reason=native(rt,"setAmmo","setAmmo",1,{magazine=magR,reserve=balance-magR,activate=drawAtOnce or nil})
    if not changed then return false,reason end
    if l then changed,reason=native(rt,"setAmmo","setAmmo",4,{magazine=magL,reserve=balance-magR-magL});if not changed then return false,reason end end
    if not (drawAtOnce and type(changed)=="table" and changed.drawn==true) then
        local active,activeError=native(rt,"setActive","setActive",1);if not active then return false,activeError end
    end
    return finishProjection(rt,d,balance,held)
end
-- Characters from before rounds were items kept a hidden pistol stock (s.ammo).
-- It moves into the pockets as loose rounds, in one transaction with the state; what
-- does not fit stays recorded and moves at the next synchronization.
function W.migrateLegacy(rt)
    local s=W.states[rt.inventory]
    if not s or not s.ammo or s.ammo<=0 then return true end
    local moved=0
    local ok,why=Inv.transaction(rt.player,function(inv)
        if not current(rt) or inv.id~=rt.inventory then return false,"Character changed." end
        local state=W.states[inv.id];local draft=Inv.draft(inv);local loose=C.ammo.pistol.item
        local n=state.ammo
        while n>0 and not Inv.canHold(draft,loose,n) do n=math.floor(n/2) end
        if n==0 then return true end
        Inv.place(draft,loose,n);moved=n
        local nextState=W.clone(state);nextState.ammo=state.ammo-n;nextState.revision=state.revision+1
        return saveState(rt,nextState,"migrate",nil,{{inv,draft}})
    end)
    if not ok then return false,why or "The previous ammunition stock could not be moved into your inventory." end
    if moved>0 then
        LightRP.log("armament: player %d legacy stock -> %d pistol round item(s), %d left to move",rt.player,moved,W.states[rt.inventory].ammo)
        LightRP.notice(rt.player,{kind="info",title="Ammunition",body=string.format("%d pistol rounds from your previous stock are now in your pockets.",moved)})
    end
    return true
end
-- A mission that hands out its own loadout (the raid) owns the native slots
-- while it runs: no RP projection over it, no RP gate on its damage.
local function missionLoadout(player)
    -- drawn Mantis Blades own the arm slot the same way (server/modules/cyberware.lua)
    return W.standsAside(player)
end
function W.synchronize(player,onlyObserve)
    if missionLoadout(player) then
        -- the mission's kit owns the native slots now: the projection made before it is
        -- not ours to reconcile. Kept, it made the return refuse ("could not be
        -- reconciled") and the kit stayed in hand after the mission (2026-11-02).
        local rt=W.runtime[player]
        if rt then rt.projectedRecords=nil;rt.baseline=nil end
        return true
    end
    local rt=W.runtime[player]
    if not current(rt) then return false,"Your character is not ready." end
    if not inWorld[player] then return true end -- onGameplayReady synchronizes
    if rt.busy then return false,"Weapon synchronization is already in progress." end
    if rt.quarantine then return false,"An ambiguous native request is quarantined. Wait for its completion or reconnect." end
    if not alive(player) then return false,"Your character must be alive to synchronize weapons." end
    rt.busy=true;rt.observing=onlyObserve==true
    if not onlyObserve then rt.ready=false;rt.error=nil;W.push(player) end
    CreateThread(function()
        local ok,result,why=pcall(function()
            if onlyObserve then
                local snap,error=native(rt,"requestSnapshot","snapshot");if not snap then return false,error end
                local observed,why=readback(rt,rowsOf(snap))
                if not observed then return false,why end
                -- rounds bought, given, dropped or unpacked since the projection, or a
                -- partial projection running low while more rounds wait in the pockets
                local base=rt.baseline
                local held=base and rounds(Inv.player(player),base.kind)
                if base and (held~=base.held or (held>base.rounds and base.rounds<C.maxAmmo/2)) then
                    rt.observing=false
                    return project(rt)
                end
                return true
            end
            return project(rt)
        end)
        if not current(rt) then return end
        rt.busy=false;rt.observing=false
        rt.ready=ok and result==true
        if rt.ready then rt.error=nil;rt.syncRetries=nil else rt.error=tostring(ok and why or result) end
        -- A synchronization the engine refused or left unanswered once (weapon not drawn
        -- yet, a slow client) is tried again by itself: players had to press again until
        -- it went through ("quand il spam il arrive a sortir", 2026-11-04). SYNC_RETRIES
        -- in a row, SYNC_RETRY_MS apart; a quarantine has its own recovery (W.recover).
        -- player_unavailable (the body is not there yet: loading screen, respawn) keeps trying every
        -- 2 s for up to 2 min without using up the retries
        local unavailable=not rt.ready and tostring(rt.error):find("player_unavailable",1,true)~=nil
        if unavailable then rt.unavailableSince=rt.unavailableSince or now() else rt.unavailableSince=nil end
        if unavailable and not onlyObserve and not rt.quarantine and now()-rt.unavailableSince<120 then
            CreateThread(function()
                Wait(2000)
                if current(rt) and not rt.ready and not rt.busy and not rt.quarantine and alive(rt.player) then W.synchronize(rt.player) end
            end)
        elseif not rt.ready and not onlyObserve and not rt.quarantine and (rt.syncRetries or 0)<SYNC_RETRIES then
            rt.syncRetries=(rt.syncRetries or 0)+1
            local attempt=rt.syncRetries
            CreateThread(function()
                Wait(SYNC_RETRY_MS*attempt)
                if current(rt) and not rt.ready and not rt.busy and not rt.quarantine and alive(rt.player) then
                    LightRP.log("armament: player %d synchronization retry %d (%s)",rt.player,attempt,tostring(rt.error))
                    W.synchronize(rt.player)
                end
            end)
        end
        -- A low-reserve dual cannot keep firing while its ambiguous native
        -- reload is reconciled. Durable intent remains; the player may unequip.
        if not rt.ready then rt.observed=rt.observed or {} end
        if not onlyObserve then traceEnd(rt,rt.ready,rt.error) end
        W.push(player)
        drain(rt)
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
        -- dual wield is a handgun thing: rifles, shotguns and SMGs hold the right hand alone
        local spec=C.weapons[item.name]
        if p.hand=="left" and not spec.dual then return false,"Only a pistol or a revolver goes in the left hand." end
        local partner=nextState[p.hand=="right" and "left" or "right"];local partnerItem=partner and W.find(inv,partner)
        if partnerItem and partner~=p.instanceId and not (spec.dual and C.weapons[partnerItem.name].dual) then
            return false,p.hand=="right" and "This weapon needs both hands. Unequip the left-hand pistol first." or "Your right-hand weapon needs both hands."
        end
        if nextState[p.hand=="right" and "left" or "right"]==p.instanceId then return false,"One firearm cannot occupy both hands." end
        local other=nextState[p.hand=="right" and "left" or "right"]
        local otherItem=other and W.find(inv,other)
        if otherItem and C.weapons[otherItem.name].record==C.weapons[item.name].record then return false,"Two identical pistol models are not supported by this tested projection yet." end
        nextState[p.hand]=p.instanceId
        rt.holstered=false
    elseif p.operation=="select" then
        if missionLoadout(player) then return false,"Your mission loadout is in your hands." end
        if p.unarmed==true then
            nextState.right,nextState.left=nil,nil
        else
            local item=type(p.instanceId)=="string" and W.find(inv,p.instanceId)
            if not item then return false,"That weapon is no longer in your pockets." end
            local spec=C.weapons[item.name]
            if nextState.left==p.instanceId then nextState.left=nil end
            -- a handgun keeps its left-hand partner; anything else holds the right hand alone
            local partner=nextState.left and W.find(inv,nextState.left)
            local partnerSpec=partner and C.weapons[partner.name]
            if not (spec.dual and partnerSpec and partnerSpec.dual and partnerSpec.record~=spec.record) then nextState.left=nil end
            nextState.right=p.instanceId
            rt.holstered=false
        end
    elseif p.operation=="unequip" then
        if p.hand~="right" and p.hand~="left" then return false,"Choose a hand." end
        if p.instanceId and nextState[p.hand]~=p.instanceId then return false,"The equipped firearm changed." end
        nextState[p.hand]=nil
        if p.hand=="right" then nextState.left=nil end
    elseif p.operation=="ammo" then
        local slot=tonumber(p.slot);local item=slot and inv.items[slot]
        local box=item and C.boxes[item.name]
        if not box or item.count<1 then return false,"That ammunition box is no longer available." end
        local loose=C.ammo[box.ammo].item
        local draft=Inv.draft(inv);draft.items[slot].count=draft.items[slot].count-1
        if draft.items[slot].count==0 then draft.items[slot]=nil end
        local fits,why=Inv.canHold(draft,loose,box.rounds)
        if not fits then return false,why=="too_heavy" and "Your pockets are too heavy for these rounds. The box was kept." or "No room in your pockets for these rounds. The box was kept." end
        Inv.place(draft,loose,box.rounds)
        changes={{inv,draft}}
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
    -- the 2 s observe pass only reads: a request landing during it (a wheel pick) runs
    -- right after it instead of being refused as "in progress"
    if current(rt) and rt.busy and rt.observing then
        CreateThread(function()
            local deadline=now()+2
            while current(rt) and rt.busy and rt.observing and now()<deadline do Wait(25) end
            local ok,why=beginMutation(player,p,callback)
            if not ok then
                if callback then callback(false,why) else LightRP.notice(player,{kind="error",title="Equipment",body=why}) end
            end
        end)
        return true
    end
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
                local rows=rowsOf(snapshot)
                local ok,reason=settleExisting(rt,rows);if not ok then return false,reason end
                rt.freshRows,rt.freshAt=rows,now()
            end
            settled=true
            if not current(rt) then return false,"Character changed." end
            if payload.baseRevision==beforeRevision then payload.baseRevision=W.states[rt.inventory].revision end
            local ok,error=Inv.transaction(player,function(inv) return apply(player,payload,inv,true) end)
            traceMark(rt,"tx")
            return ok,error,"validated"
        end)
        if not current(rt) then return end
        rt.busy=false
        if not called or not success then
            rt.ready=called and settled and wasReady and not rt.quarantine or false
            rt.error=tostring(called and why or success)
            W.push(player)
            if callback then callback(false,rt.error) else LightRP.notice(player,{kind="error",title="Equipment",body=rt.error}) end
            drain(rt)
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
    local rt={player=player,inventory=inv.id,epoch=epochs[player],ready=false,busy=false,observed={},holstered=true}
    W.runtime[player]=rt
    local s,why=W.load(inv)
    if not s then rt.error=why;W.push(player);return end
    rt.ready=false;W.push(player)
    -- Clear a previous/native single-player loadout even when this RP
    -- character owns no equipped firearm. No projection is implicitly trusted.
    -- Not before the player is in the world: onGameplayReady synchronizes then.
    if alive(player) and inWorld[player] then W.synchronize(player) end
end
function W.enterWorld(player,why)
    local first=not inWorld[player]
    inWorld[player]=true
    if first then LightRP.log("armament: player %d in the world (%s): weapons synchronize",player,tostring(why)) end
    attach(player)
    local rt=W.runtime[player]
    if rt and first and not rt.busy and alive(player) then W.synchronize(player) end
end
local function retire(player,reason)
    local rt=W.runtime[player]
    if rt then rt.ready=false;rt.error=reason;rt.busy=false;W.push(player) end
    W.runtime[player]=nil
    for key,job in pairs(W.pending) do if job.runtime.player==player then W.pending[key]=nil end end
end
LightRP.module("armament",{
    -- a resource restart: the players connected already are in the world (gameplayReady will not come again)
    onDatabaseReady=function() W.loaded=true;LightRP.log("armament ready: serialized firearms, rounds as inventory items per ammunition type, native projection queue enabled");for _,id in ipairs(GetPlayers()) do inWorld[tonumber(id)]=true;attach(tonumber(id)) end end,
    onCharacterLoaded=function(player) retire(player,"Character changed.");attach(player) end,
    onCharacterActivated=function(player) retire(player,"Character changed.");attach(player) end,
    onGameplayReady=function(player) W.enterWorld(player,"gameplay ready") end,
    onDisconnected=function(player) retire(player,"Disconnected.");lastRequest[player]=nil;inWorld[player]=nil end,
    onLifeState=function(player,phase)
        if phase~="alive" then
            retire(player,"Weapon projection waits for a living character.")
        else attach(player) end
    end,
    -- the platform's readiness gate opened (onPlayerReady: incarnated, past the continue screen): the
    -- second proof, should gameplayReady not reach us. NOT the page's ui ready: it comes during the
    -- loading screen on a slow loader (Testing 2026-11-05, 2 min load: snapshots timed out, queue_full)
    onReady=function(player) W.enterWorld(player,"player ready") end,
    onUiReady=function(player) attach(player);W.push(player) end,
})
-- Puts away whatever is in the hands without changing the loadout: drawn Mantis Blades
-- (sheathed), a pocket firearm, the bare fists. B and the wheel's top slot. With the
-- projection not ready (fists out before any weapon state, a quarantine) the native
-- holster still runs: lowering the fists never needs the armament.
function W.holster(player)
    local cyber = LightRP.cyberware
    if cyber and type(cyber.sheatheBlades) == "function" and cyber.sheatheBlades(player) then return true end
    attach(player)
    local rt=W.runtime[player]
    if not current(rt) or rt.quarantine then
        local ok, done, why = pcall(Open77.weapons.holster, player)
        if not ok then return false, tostring(done) end
        if done == false then return false, tostring(why) end
        return true
    end
    if rt.busy then rt.queued={operation="holster",request="queued:holster"};return true end
    rt.busy=true;W.push(player)
    traceStart(rt,"holster")
    CreateThread(function()
        local result,why=native(rt,"holster","holster")
        if current(rt) then rt.busy=false;rt.error=result and nil or why;if result then rt.holstered=true end;traceEnd(rt,result,why);W.push(player);drain(rt) end
    end)
    return true
end
local lastHolster={}
RegisterNetEvent("op77_lightrp:armament:holster",function()
    local player=tonumber(source)
    if not player or player<=0 then return end
    local at=now()
    if lastHolster[player] and at-lastHolster[player]<.25 then return end
    lastHolster[player]=at
    W.holster(player)
end)

-- A wheel pick or a holster landing while the equipment is busy (an observe pass, a projection,
-- a holster) waits for it instead of being refused; a newer one replaces it (latest wins).
-- Refusals here were the "sometimes nothing happens" of the wheel (2026-11-05).
drain=function(rt)
    if not current(rt) or rt.busy or not rt.queued then return end
    local q=rt.queued;rt.queued=nil
    local s=W.states[rt.inventory]
    if s then q.baseRevision=s.revision end -- a selection states the whole intent: the newest revision
    lastRequest[rt.player]=nil
    CreateThread(function() W.request(rt.player,q) end)
end
W.drain=drain
-- The weapon already equipped, drawn again (after a holster, from the wheel): one native round trip.
local function fastDraw(player,p)
    local rt=W.runtime[player];local inv=Inv.player(player);local s=inv and W.states[inv.id]
    if not current(rt) or rt.busy or not rt.ready or rt.quarantine or not s or s.right~=p.instanceId then return false end
    if not (rt.projectedRecords and rt.projectedRecords[1]) or missionLoadout(player) or not alive(player) then return false end
    rt.busy=true;W.push(player)
    traceStart(rt,"draw")
    CreateThread(function()
        local active,why=native(rt,"setActive","setActive",1)
        if not current(rt) then return end
        rt.busy=false
        if active then
            rt.holstered=false;traceMark(rt,"drawn");traceEnd(rt,true)
            TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=true,data={state=W.view(player)}})
            W.push(player);drain(rt)
        else
            -- the slot no longer holds it (a death, a native reset): the full projection puts it back
            traceEnd(rt,false,why)
            rt.holstered=false
            local ok,error=W.synchronize(player)
            TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=ok==true,error=error,data={state=W.view(player)}})
        end
    end)
    return true
end
function W.request(player,p)
    if not player or player<=0 or type(p)~="table" or type(p.request)~="string" or #p.request>96 or #p.request==0 then return end
    local operation=p.operation
    if type(operation)~="string" then return end
    -- "state" only reads (the wheel asks for it when it opens) and a wheel pick waits in the
    -- latest-wins queue: neither counts against the spacing (a quick pick right after opening
    -- the wheel was refused, 2026-11-05)
    local picking=operation=="select" or operation=="holster"
    if operation~="state" and not picking then
        local at=now()
        if lastRequest[player] and at-lastRequest[player]<.15 then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Please wait before the next equipment request."});return end
        lastRequest[player]=at
    end
    attach(player)
    local rt=W.runtime[player]
    local ok,error=true,nil
    local pick=(operation=="select" and not (type(p.instanceId)=="string" and p.instanceId:match("^kit:"))) or operation=="holster"
    if pick and current(rt) and rt.busy then
        local replaced=rt.queued~=nil
        rt.queued=p
        TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=true,queued=true,data={state=W.view(player)}})
        if not replaced then LightRP.log("armament: player %d %s queued behind a busy equipment",player,operation) end
        return
    end
    if operation=="state" then
        W.push(player)
    elseif operation=="sync" then ok,error=W.synchronize(player)
    elseif operation=="holster" then
        ok,error=W.holster(player)
    elseif operation=="select" and p.unarmed==true and not missionLoadout(player) then
        -- empty hands: the weapon goes back in its holster and stays equipped, so the wheel draws
        -- it again in one round trip (it used to unequip it and clear the native slots)
        ok,error=W.holster(player)
    elseif operation=="select" and type(p.instanceId)=="string" and fastDraw(player,p) then
        return
    elseif operation=="select" and type(p.instanceId)=="string" and p.instanceId:match("^kit:[12]$") then
        -- a kit weapon from the wheel: a mission's or an activity's
        local source=kitSource(player)
        if not source then ok,error=false,"No mission kit."
        else ok,error=source.drawKit(player,tonumber(p.instanceId:sub(5))) end
    elseif operation=="equip" or operation=="unequip" or operation=="ammo" or operation=="select" then
        traceStart(rt,operation)
        ok,error=beginMutation(player,p,function(accepted,why)
            if not current(rt) then return end
            if not accepted then traceEnd(rt,false,why) end
            TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=accepted,error=why,data={state=W.view(player)}})
        end)
        if ok then return end -- final reply is sent only after the intent/box transaction settles
        traceEnd(rt,false,error)
    else ok,error=false,"Unknown equipment operation." end
    if rt and not current(rt) then return end
    TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=ok==true,error=error,data={state=W.view(player)}})
end
RegisterNetEvent(NET,function(p) W.request(tonumber(source),p) end)

-- Staff and lab: drive a player's weapon from the console, the same path as the wheel.
--   /lightrp.armtest <id> next      the next pocket weapon (cycles)
--   /lightrp.armtest <id> <n>       the n-th pocket weapon of the wheel
--   /lightrp.armtest <id> unarmed | holster | state
-- Each request logs an "armament: trace" line (time to hand, native round trips).
local armtestNext={}
local armtest
LightRP.command("lightrp.armtest",{restricted=true,usage="/lightrp.armtest <id> <next|n|unarmed|holster|state>"},function(source,args)
    local ok,text=armtest(source,args)
    LightRP.log("armtest: %s",tostring(text or (ok and "ok" or "usage")))
    return ok,text
end)
armtest=function(source,args)
    local player=tonumber(args[1]);local what=tostring(args[2] or "state")
    if not player then return false end
    attach(player)
    local rt=W.runtime[player];local inv=Inv.player(player);local s=inv and W.states[inv.id]
    if not current(rt) or not s then return false,"No armament runtime for that player." end
    local list=W.view(player).arsenal or {}
    if what=="state" then
        local names={}
        for i,a in ipairs(list) do names[#names+1]=("%d:%s%s"):format(i,tostring(a.label or a.name),a.instanceId==s.right and "*" or "") end
        return true,("ready=%s busy=%s holstered=%s queued=%s · %s"):format(tostring(rt.ready),tostring(rt.busy),tostring(rt.holstered),tostring(rt.queued and rt.queued.operation or "-"),table.concat(names," "))
    end
    local p={request="armtest:"..tostring(now()),mutation="armtest:"..tostring(W.uuid()),baseRevision=s.revision}
    if what=="die" then
        local at=Open77.players.position(player)
        local killed,why=Open77.players.kill(player,{cause="script",weapon="lightrp:armtest"})
        if not killed then return false,"kill refused: "..tostring(why) end
        CreateThread(function()
            Wait(3000)
            local ok,err=Open77.players.respawn(player,{position={x=at.x,y=at.y,z=at.z},heading=0,bucket=at.bucket or 0,health=1.0,graceMs=3000})
            LightRP.log("armtest: respawn %s %s",tostring(ok),tostring(err or ""))
        end)
        return true,"killed "..player..", respawn in 3 s"
    end
    if what=="holster" then p.operation="holster"
    elseif what=="unarmed" then p.operation="select";p.unarmed=true
    else
        local n=tonumber(what)
        if what=="next" then n=((armtestNext[player] or 0)%math.max(1,#list))+1;armtestNext[player]=n end
        local a=n and list[n]
        if not a then return false,"No pocket weapon #"..tostring(what).." ("..#list.." in the pockets)." end
        p.operation="select";p.instanceId=a.instanceId
    end
    lastRequest[player]=nil
    W.request(player,p)
    return true,("%s sent to %d"):format(p.operation..(p.instanceId and (" "..p.instanceId) or (p.unarmed and " unarmed" or "")),player)
end
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
    local instance=item.metadata and item.metadata.instanceId
    local equipped=instance and (s.right==instance or s.left==instance)
    local operation=equipped and "unequip" or "equip"
    local ok,why=beginMutation(player,{operation=operation,hand=(s.left==instance and "left" or "right"),slot=slot,instanceId=instance,baseRevision=s.revision,mutation=operation..":"..mutation})
    if ok then return "keep" end
    LightRP.notice(player,{kind="error",title="Equipment",body=why});return false
end) end
CreateThread(function()
    lightrpEvery(2000, function()
        for player,rt in pairs(W.runtime) do
            local s=W.states[rt.inventory]
            if current(rt) and s and s.right and rt.ready and not rt.busy and alive(player) then W.synchronize(player,true) end
        end
        
    end, "armament:970")
end)
-- This gate authorizes known RP firearm damage; it does not count shots. The
-- native cache remains client-reported and is never used to mint ammunition.
-- Every refusal is logged once per attacker and reason every REFUSAL_LOG_S: a refused hit
-- shows as an invincible target (Dogtown, 2026-11-04) and said nothing about why.
local REFUSAL_LOG_S=10
local refusalLoggedAt={}
local function refuse(player,why,hash)
    local key=tostring(player)..":"..why
    local t=now()
    if not refusalLoggedAt[key] or t-refusalLoggedAt[key]>=REFUSAL_LOG_S then
        refusalLoggedAt[key]=t
        LightRP.log("armament: hit by player %d refused (%s, weapon %s)",player,why,hash~="" and hash or "?")
    end
    return false
end
W.refusalLoggedAt=refusalLoggedAt
local function damageGate(event)
    if type(event)~="table" or event.source=="vehicle" then return nil end
    local player=tonumber(event.attacker)
    if not player or player<=0 then return nil end
    if missionLoadout(player) then return nil end
    local rt=W.runtime[player]
    local hash=tostring(event.weaponTdbId or ""):lower()
    local managed=hashes[hash]
    if not managed and event.attackKind~="ranged" then return nil end
    if not rt then return refuse(player,"no armament runtime",hash) end
    local s=W.states[rt.inventory]
    if not s or not s.right then return refuse(player,"no Light RP firearm equipped",hash) end
    if not rt.baseline or rt.baseline.rounds<=0 then return refuse(player,"no rounds",hash) end
    if not rt.allowedHashes or not rt.allowedHashes[hash] then return refuse(player,managed and "not the equipped firearm" or "not a Light RP firearm",hash) end
    -- The firearm of the last projection still fires while a synchronization runs (a
    -- wheel select, the automatic retry): refusing then made the target look invincible
    -- for the seconds a sync takes. Not ready AND not syncing (a failed sync, a
    -- quarantine) still refuses.
    if not rt.ready and not rt.busy then return refuse(player,rt.quarantine and "quarantined" or "equipment not synchronized",hash) end
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

-- Stale flags left by tasks the instruction quota killed (framework.lua expireFlags).
expireFlags("armament.busy", W.runtime, nil, "busy")
