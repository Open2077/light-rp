-- Public production points. Each cycle grants real inventory items only after
-- server time, life, ownership, position, inputs and capacity are checked again.
local C, E, Inv, Db = LightRpJobWork, LightRpEvents, LightRP.inventory, LightRP.db
local Work = LightRP.module("jobWork", {})
local points, sessions, lastBegin, serial = {}, {}, {}, 0
for job, definition in pairs(C.jobs) do
    for _, point in ipairs(definition.points) do
        point.job, point.definition = job, definition
        points["work." .. job .. "." .. point.id] = point
    end
end
local function notify(id, text, kind)
    LightRP.notice(id, {kind=kind or "info",title="Item work",body=text,durationMs=7000})
end
local reasons = {
    too_heavy="Your bag cannot carry another batch. Store items in an unlocked vehicle trunk, then return and press E.",
    no_room="Your inventory slots are full. Store items in your vehicle trunk, then return and press E.",
    not_enough="No complete batch left to process. Collect more materials or take them out of your trunk.",
    no_stock="No processed goods in your bag. Process your materials or take the finished goods out of your trunk.",
    busy="Your inventory is busy. Wait for the current transfer, then press E again.",
    no_inventory="Your inventory is not ready. Please retry.",
    database_unavailable="Storage is unavailable. Please retry when it is back online.",
}
local function explain(reason) return reasons[reason] or "The batch could not be saved. No items or payment were changed. Please retry." end
local function valid(id, point, session)
    local char, life = LightRP.characters.get(id), Open77.players.getLifeState(id)
    if not char or char.status~="active" or not char.identifier or not life or life.phase~="alive" then return false end
    if session and (sessions[id]~=session or char~=session.character or Inv.player(id)~=session.inventory) then return false end
    if (LightRP.characters.switching or {})[id] then return false end
    if Open77.vehicles.getPlayerSeat(id) then return false end
    if session and session.playbackId then
        local animation=Open77.animations.current(id)
        if not animation or not animation.active or animation.playbackId~=session.playbackId then return false end
    end
    return LightRP.nearInteraction(id,{position=point.position,radius=C.range,bucket=point.definition.bucket or 0},0.4)
end
-- A practice site (definition.tutorial) only works for the step of the first
-- day guide that asks for it: it is a lesson, not an income.
local function open(id, point)
    if not point.definition.tutorial then return true end
    return LightRP.tutorial ~= nil and LightRP.tutorial.allowsWork ~= nil and LightRP.tutorial.allowsWork(id, point.kind) == true
end
local function push(id) LightRP.state(id,"jobWork") end
-- Real work needs the job (a Job Center hires you); practice sites are the guide's.
local function employed(id,job,definition)
    return definition.tutorial or LightRP.jobs.get(id).name==job
end
local function hireText(job)
    local def=LightRpJobs and LightRpJobs[job]
    return "This is "..(def and def.label or job).." work. Get hired at a Job Center first (briefcase on the map)."
end
function Work.isBusy(id) return sessions[id] and sessions[id].committing==true or false end
function Work.isActive(id) return sessions[id]~=nil end
function Work.preview(job)
    local d=C.jobs[job]; if not d then return nil end
    return {raw=LightRpItems[d.raw].label,product=LightRpItems[d.product].label,rawItem=d.raw,productItem=d.product,
        collectCount=d.collected,collectWeight=d.collected*LightRpItems[d.raw].weight,
        inputCount=d.input,outputCount=d.produced,price=d.price}
end
function Work.firstPoint(job)
    local d=C.jobs[job]; if not d then return nil end
    for _,p in ipairs(d.points) do if p.kind=="collect" then return p,"work."..job.."."..p.id end end
end
function Work.snapshot(id)
    local s=sessions[id]; if not s then return {active=false} end
    return {active=true,job=s.point.job,kind=s.point.kind,label=s.point.label,icon=s.point.definition.icon,
        busy=s.committing==true,cycles=s.cycles,weight=Inv.weightOf(s.inventory),maxWeight=s.inventory.maxWeight,
        raw=LightRpItems[s.point.definition.raw].label,product=LightRpItems[s.point.definition.product].label,
        rawCount=Inv.plainCount(s.inventory,s.point.definition.raw),productCount=Inv.plainCount(s.inventory,s.point.definition.product),
        earned=s.earned}
end
LightRP.stateProvider("jobWork",Work.snapshot)
local function stopAnimation(id,s)
    local playback=s.playbackId; s.playbackId=nil
    if playback then pcall(Open77.animations.stop,id,playback) end
end
local function finishSession(id,s,message,kind)
    if sessions[id]~=s then return end
    sessions[id]=nil
    stopAnimation(id,s)
    TriggerClientEvent(E.net.workCycle,id,{cancel=true})
    push(id)
    if message then notify(id,message,kind) end
end
function Work.cancel(id,message)
    local s=sessions[id]; if not s then return false end
    if s.committing then
        s.cancelled=true -- the already-authorized atomic write must finish
        stopAnimation(id,s)
        TriggerClientEvent(E.net.workCycle,id,{cancel=true})
    else finishSession(id,s,message or "Work stopped. All completed batches stay in your inventory.") end
    return true
end
local function batch(s)
    local d,inv=s.point.definition,s.inventory
    if not Db.ready then return nil,"database_unavailable" end
    if not inv then return nil,"no_inventory" end
    if inv.busy then return nil,"busy" end
    if s.point.kind=="sell" then
        local count=Inv.plainCount(inv,d.product)
        if count<1 then return nil,"no_stock" end
        return {count=count,total=count*d.price,duration=d.sellMs}
    end
    local inputs=s.point.kind=="process" and {{name=d.raw,count=d.input}} or {}
    local outputs={{name=s.point.kind=="process" and d.product or d.raw,count=s.point.kind=="process" and d.produced or d.collected}}
    local ok,why=Inv.canProduce(inv,inputs,outputs)
    if not ok then return nil,why end
    return {inputs=inputs,outputs=outputs,duration=s.point.kind=="process" and d.processMs or d.collectMs}
end
local function nextCycle(id,s)
    if s.cancelled or not valid(id,s.point,s) then return finishSession(id,s,"Work stopped. Your completed batches are safe.") end
    local b,why=batch(s)
    if not b then return finishSession(id,s,explain(why),(why=="too_heavy" or why=="no_room") and "warning" or "info") end
    serial=serial+1
    s.token=tostring(LightRP.nowMs())..":"..serial
    s.at,s.batch=LightRP.nowMs(),b
    local description=s.point.kind=="sell" and ("Sell "..b.count.." × "..LightRpItems[s.point.definition.product].label.." for "..LightRP.money.format(b.total))
        or string.format("Repeats automatically · %.1f / %.1f kg",Inv.weightOf(s.inventory),s.inventory.maxWeight)
    TriggerClientEvent(E.net.workCycle,id,{token=s.token,label=s.point.label,icon=s.point.definition.icon,durationMs=b.duration,description=description,playbackId=s.playbackId})
    push(id)
end
function Work.begin(id,pointId)
    local p=points[pointId]
    if not p then return false,"Unknown work point." end
    local now=LightRP.nowMs()
    if now-(lastBegin[id] or -1000)<500 then return false,"Please wait a moment." end
    lastBegin[id]=now
    if sessions[id] then return false,"You are already working. Escape stops the current activity." end
    if not open(id,p) then return false,"This practice site belongs to the first day guide. Follow your current objective." end
    if not employed(id,p.job,p.definition) then return false,hireText(p.job) end
    if not valid(id,p) then return false,"Stand on foot at the work point with an active, living character." end
    if LightRP.jobRuns and LightRP.jobRuns.snapshot(id).active then return false,"Finish or cancel your current work order first (F1 → My job)." end
    local s={point=p,character=LightRP.characters.get(id),inventory=Inv.player(id),cycles=0,earned=0}
    local b,why=batch(s)
    if not b then return false,explain(why) end
    local current=Open77.animations.current(id)
    if current and current.active then return false,"Stop your current animation before working." end
    local animation=p.definition.animations[p.kind]
    local called,playback=pcall(Open77.animations.play,id,animation.profile,{clip=animation.clip,loop=true})
    if not called or not playback or not playback.playbackId then return false,"The work animation could not start. Please retry." end
    s.playbackId=playback.playbackId
    sessions[id]=s
    nextCycle(id,s)
    return true
end
function Work.complete(id,payload)
    local s=sessions[id]
    if not s or s.committing or type(payload)~="table" or type(payload.token)~="string" or payload.token~=s.token then return false end
    local b=s.batch
    s.token=nil -- consume once before yielding to SQL
    local elapsed=LightRP.nowMs()-s.at
    if payload.status~="success" or not valid(id,s.point,s) or elapsed<b.duration or elapsed>b.duration+15000 then
        finishSession(id,s,"Work stopped. All completed batches stay in your inventory.")
        return false
    end
    s.committing=true; push(id)
    local called,ok,why=pcall(function()
        if not Db.ready then return false,"database_unavailable" end
        if s.point.kind=="sell" then
            return Inv.trade(id,"sell",{{name=s.point.definition.product,count=b.count}},"bank",b.total,s.point.label)
        end
        return Inv.produce(id,b.inputs,b.outputs)
    end)
    s.committing=false
    if sessions[id]~=s then return called and ok==true end -- disconnected; never target a new player in the same slot
    if not called or not ok then
        if not called then LightRP.log("item work settlement error: %s",tostring(ok)) end
        finishSession(id,s,explain(called and why or "database_error"),"warning"); return false
    end
    s.cycles=s.cycles+1
    if s.point.kind=="sell" then
        s.earned=b.total
        finishSession(id,s,string.format("Sold %d × %s. %s deposited in your bank.",b.count,LightRpItems[s.point.definition.product].label,LightRP.money.format(b.total)),"money")
        LightRP.eachModule("onJobWorkCompleted",id,s.point.job,s.point.kind)
    elseif s.point.definition.once then
        -- A practice site: one batch is the lesson, the loop does not repeat.
        local job,kind=s.point.job,s.point.kind
        finishSession(id,s,kind=="process" and "Processed. The finished goods are in your inventory." or "Collected. The load is in your inventory.")
        LightRP.eachModule("onJobWorkCompleted",id,job,kind)
    else
        -- A tutorial callback may acquire a camera/UI. Cancellation during a
        -- commit is remembered and prevents issuing another batch.
        LightRP.eachModule("onJobWorkCompleted",id,s.point.job,s.point.kind)
        if sessions[id]==s then nextCycle(id,s) end
    end
    return true
end
function Work.locate(id,job,kind)
    local d=C.jobs[job]; if not d then return false,"Unknown activity." end
    if not employed(id,job,d) then return false,hireText(job) end
    kind=kind or "collect"
    local nearest,distance,pointId
    local position=Open77.players.position(id); if not position then return false,"Your character is not ready." end
    for _,p in ipairs(d.points) do if p.kind==kind then
        local length=(position.x-p.position.x)^2+(position.y-p.position.y)^2+(position.z-p.position.z)^2
        if not distance or length<distance then nearest,distance,pointId=p,length,"work."..job.."."..p.id end
    end end
    if not nearest then return false,"Unknown work stage." end
    TriggerClientEvent(E.net.workGps,id,{id=pointId,position=nearest.position,label=nearest.label,icon=d.icon,radius=C.range})
    return true,"GPS set. Press E at the point to work."
end
function Work.onInteract(id,point)
    if not points[point] then return end
    local ok,why=Work.begin(id,point); if not ok then notify(id,why,"warning") end
end
RegisterNetEvent(E.net.workFinish,function(payload) Work.complete(source,payload) end)
LightRP.action("jobs.locate",function(id,payload)
    local ok,message=Work.locate(id,payload.job,payload.stage); LightRP.result(id,ok,message,"jobs.locate")
end)
LightRP.command("work",{usage="/work <sanitation|scrapper> [collect|process|sell] | /work stop"},function(id,args)
    if args[1]=="stop" then Work.cancel(id); return true,"Work stopped. Completed items are kept." end
    return Work.locate(id,args[1],args[2])
end)
function Work.onLifeState(id,phase) if phase~="alive" then Work.cancel(id) end end
function Work.onCharacterSwitched(id) Work.cancel(id) end
-- a new job: the old job's work stops and its GPS point goes
function Work.onJobChanged(id)
    Work.cancel(id,"Your job changed. Work stopped; completed batches stay in your inventory.")
    TriggerClientEvent(E.net.workGps,id,{clear=true})
end
function Work.onDisconnected(id)
    local s=sessions[id]; sessions[id],lastBegin[id]=nil,nil
    if s then stopAnimation(id,s) end
end
function Work.onGameplayReady(id) push(id) end
function Work.tick()
    for id,s in pairs(sessions) do
        if not s.committing and (not valid(id,s.point,s) or LightRP.nowMs()-s.at>s.batch.duration+15000) then
            finishSession(id,s,"Work stopped. Stay at the point while a batch is being prepared.","warning")
        end
    end
end
CreateThread(function()
    Wait(750)
    for id,p in pairs(points) do
        local icon=p.kind=="sell" and "banknote" or p.kind=="process" and "hammer" or p.definition.icon
        LightRP.interaction(id,{position=p.position,radius=C.range,bucket=p.definition.bucket or 0,label=p.label,key="E",ring=false,
            jobs=not p.definition.tutorial and {p.job} or nil,
            prompt=p.kind=="sell" and ("Sell "..LightRpItems[p.definition.product].label) or (p.label.." · E to work"),
            marker={shape="cylinder",radius=.6,height=.4,color={r=255,g=204,b=0,a=150},maxDistance=35},
            blip={icon=icon,sprite="tech",title=p.label,routable=true,description=p.kind=="sell" and (LightRP.money.format(p.definition.price).." per "..LightRpItems[p.definition.product].label) or (p.definition.tutorial and "First day guide · practice site" or "Your job · your own pace · items, weight and vehicle trunks")}})
    end
    while true do Wait(250); Work.tick() end
end)
