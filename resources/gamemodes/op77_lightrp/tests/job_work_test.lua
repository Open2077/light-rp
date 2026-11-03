-- Real inventory, economy and production modules; transactional SQL boundary.
-- This test never connects to a live database.
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
local noop=function() end
local function clone(v) if type(v)~="table" then return v end local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local encoded,serial={},0
json={encode=function(v) serial=serial+1;encoded[tostring(serial)]=clone(v);return tostring(serial) end,decode=function(k) return clone(encoded[k] or {}) end}
local now,fail,yieldDb,life,seat,locked=1000,false,false,"alive",nil,false
local char={identifier="item-worker",key="default",status="active",job="unemployed"}
local position={x=0,y=0,z=0,bucket=0}
local state={inventories={},wallets={},migrations={},ledger={}}
local db={ready=true,schema=noop,query=function() return {} end}
function db.read(sql,p)
    if sql:find("lightrp_inventories",1,true) then local v=state.inventories[p[1]];return true,v and {clone(v)} or {} end
    if sql:find("lightrp_cash_migrations",1,true) then local v=state.migrations[p[1]];return true,v and {clone(v)} or {} end
    if sql:find("lightrp_wallets",1,true) then
        for _,w in pairs(state.wallets) do if w.identifier==p[1] and w.character_key==p[2] then return true,{clone(w)} end end
        return true,{}
    end
    error("unmodelled read: "..sql)
end
function db.single(sql,p)
    if sql:find("SELECT 1",1,true) then return state.wallets[p[1]] and {x=1} end
    local _,rows=db.read(sql,p);return rows[1]
end
local function apply(s,sql,p)
    if sql:find("INSERT INTO lightrp_inventories",1,true) then s.inventories[p[1]]={items=p[6],slots=p[4],max_weight=p[5]}
    elseif sql:find("INSERT INTO lightrp_cash_migrations",1,true) then s.migrations[p[1]]={account_number=p[1],inventory_id=p[2]}
    elseif sql:find("INSERT INTO lightrp_wallets",1,true) then s.wallets[p[1]]={account_number=p[1],identifier=p[2],character_key=p[3],owner_name=p[4],cash=p[5],bank=p[6]}
    elseif sql:find("SET cash = 0",1,true) then s.wallets[p[1]].cash=0
    elseif sql:find("SET bank = ?",1,true) then s.wallets[p[2]].bank=p[1]
    elseif sql:find("INSERT INTO lightrp_transactions",1,true) then s.ledger[#s.ledger+1]=clone(p)
    else error("unmodelled write: "..sql) end
end
function db.run(sql,p) if fail then return false end;apply(state,sql,p);return true,1 end
function db.transaction(writes)
    local draft=clone(state)
    for _,q in ipairs(writes) do apply(draft,q.query,q.values) end
    if yieldDb then coroutine.yield("sql") end
    if fail then return false,"database_error" end
    state=draft;return true
end
local events,threads,points,notices={},{},{},{}
local last,completed
local animation,animationSerial,failAnimation=nil,0,false
LightRP={db=db,module=function(n,v) LightRP[n]=v;return v end,log=noop,command=noop,action=noop,state=noop,stateProvider=noop,result=noop,
    eachModule=function(hook) if hook=="onJobWorkCompleted" then completed=(completed or 0)+1 end end,
    notice=function(_,n) assert(type(n.kind)=="string");notices[#notices+1]=n.body end,
    interaction=function(id,p) points[id]=p end,removeInteraction=noop,dialog=noop,nowMs=function() return now end,
    characters={get=function() return char end,displayName=function() return "Worker" end,switching={}},
    nearInteraction=function(_,d,slack) return (position.bucket or 0)==(d.bucket or 0) and (position.x-d.position.x)^2+(position.y-d.position.y)^2+(position.z-d.position.z)^2<=(d.radius+slack)^2 end,
    jobRuns={snapshot=function() return {active=false} end}}
Open77={players={position=function() return position end,positions=function() return {[1]=position} end,getLifeState=function() return {phase=life} end},
    vehicles={getPlayerSeat=function() return seat end,get=function() return {bucket=position.bucket,position=position} end,isLocked=function() return locked end},
    animations={current=function() return animation end,
        play=function(_,profile,options)
            if failAnimation then return nil,"native_unavailable" end
            assert(options.loop and options.clip);animationSerial=animationSerial+1
            animation={active=true,playbackId="work:"..animationSerial,profile=profile,clip=options.clip};return animation
        end,
        stop=function(_,id) if animation and animation.playbackId==id then animation=nil end end}}
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=noop;CreateThread=function(f) threads[#threads+1]=f end;Wait=function() coroutine.yield("wait") end
GetPlayers=function() return {1} end;GetPlayerName=function() return "Worker" end
TriggerClientEvent=function(e,_,p) if e==LightRpEvents.net.workCycle then last=p end end
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
local I,M=LightRP.inventory,LightRP.money
I.onCharacterLoaded(1,char);M.onCharacterLoaded(1,char)
dofile("server/config/economy.lua");dofile("server/config/job_work.lua");dofile("server/modules/job_work.lua")
local W,C=LightRP.jobWork,LightRpJobWork
local a=I.player(1)
local function gotoPoint(job,kind)
    now=now+600
    for _,p in ipairs(C.jobs[job].points) do if p.kind==kind then position=clone(p.position);position.bucket=0;return "work."..job.."."..p.id end end
end
-- the job is held by the worker (a Job Center hire); the tests below work as that job
LightRP.jobs={get=function() return {name=char.job} end}
do
    char.job="unemployed"
    local ok,why=W.begin(1,gotoPoint("scrapper","collect"))
    assert(not ok and why:find("Job Center"),"no job, no work")
    assert(not W.locate(1,"sanitation"),"no GPS for a job you do not hold")
    -- the points are registered by the module's start thread: run it to its first wait
    local co=coroutine.create(threads[#threads]);coroutine.resume(co);coroutine.resume(co)
    assert(points["work.scrapper.workshop"].jobs[1]=="scrapper","a work point is listed to its job only")
    for id,p in pairs(points) do if id:find("^work%.tutorial%.") then assert(p.jobs==nil,"practice sites stay the guide's") end end
end
local function begin(job,kind) char.job=job;local id=gotoPoint(job,kind);assert(W.begin(1,id));return clone(last) end
local function finish()
    local token=last.token;now=now+last.durationMs+5
    assert(W.complete(1,{token=token,status="success",count=999999,total=999999}))
    assert(not W.complete(1,{token=token,status="success"}),"completion token is single use")
end
local function reset()
    W.cancel(1);a.items={};a.slots=30;a.maxWeight=40;life="alive";seat=nil;position.bucket=0;db.ready=true
end
local function count(name) return I.count(a.id,name) end
local function slot(inv,name) for k,v in pairs(inv.items) do if v.name==name then return k end end end
-- Unemployed players use every stage, and work repeats without input.
reset();begin("scrapper","collect");local loopPlayback=animation.playbackId;local starts=animationSerial
for _=1,10 do finish() end
assert(not W.isActive(1) and count("scrap")==40 and I.weightOf(a)==40,"auto-stop at the exact weight limit")
assert(not animation and animationSerial==starts,"one continuous animation until the full bag stops it")
assert(not W.begin(1,gotoPoint("scrapper","collect")),"full bag cannot start another animation")
assert(notices[#notices]:find("trunk"),"capacity failure explains vehicle storage")
-- Use actual cross-inventory transfer / access checks. Trunk capacity is real.
local trunk={id="vehicle:owned-test",kind="trunk",vehicleId=77,label="Work car",slots=20,maxWeight=80,items={},viewers={},persistent=true}
I.registry[trunk.id]=trunk
locked=true;assert(not I.move(1,a.id,slot(a,"scrap"),trunk.id,1,40),"locked trunk denies loading")
locked=false;assert(I.move(1,a.id,slot(a,"scrap"),trunk.id,1,40));assert(count("scrap")==0 and I.count(trunk.id,"scrap")==40)
begin("scrapper","collect");for _=1,10 do finish() end
assert(I.move(1,a.id,slot(a,"scrap"),trunk.id,2,40));assert(I.weightOf(trunk)==80)
begin("scrapper","collect");finish();W.cancel(1)
assert(not I.move(1,a.id,slot(a,"scrap"),trunk.id,3,4),"full trunk cannot swallow extra cargo")
-- Processing consumes only carried raw items, never magically reads a trunk.
reset();assert(not W.begin(1,gotoPoint("scrapper","process")))
assert(I.move(1,trunk.id,1,a.id,1,40))
begin("scrapper","process");for _=1,10 do finish() end
assert(not W.isActive(1) and count("scrap")==0 and count("salvaged_parts")==10 and I.weightOf(a)==20)
local bank=M.get(1).bank;begin("scrapper","sell");finish()
assert(count("salvaged_parts")==0 and M.get(1).bank==bank+10*C.jobs.scrapper.price and #state.ledger>0 and not W.isActive(1))
assert(not W.begin(1,gotoPoint("scrapper","sell")),"no reward without goods")
-- Sanitation is the same item pipeline with independent goods and prices.
reset();begin("sanitation","collect");for _=1,10 do finish() end
assert(count("trashbag")==10 and not W.isActive(1))
begin("sanitation","process");for _=1,10 do finish() end
assert(count("trashbag")==0 and count("recyclables")==10)
bank=M.get(1).bank;begin("sanitation","sell");finish();assert(M.get(1).bank==bank+10*C.jobs.sanitation.price and count("recyclables")==0)
-- Each grade adds LightRpEconomy.jobs.gradeBonus to the sale price (grade 2: +20 %).
LightRP.jobs={get=function() return {name=char.job,grade=2} end}
reset();begin("sanitation","collect");for _=1,10 do finish() end
begin("sanitation","process");for _=1,10 do finish() end
bank=M.get(1).bank;begin("sanitation","sell");finish()
local graded=math.floor(C.jobs.sanitation.price*(1+2*LightRpEconomy.jobs.gradeBonus)+0.5)
assert(graded>C.jobs.sanitation.price and M.get(1).bank==bank+10*graded,"a higher grade sells for more")
LightRP.jobs={get=function() return {name=char.job} end}
-- Slot pressure, freed input slots, exact post-recipe weight, unique metadata.
reset();a.slots=1;assert(I.addItem(a.id,"trashbag",2))
local before=a.items;assert(not I.produce(1,{{name="trashbag",count=1}},{{name="recyclables",count=1}}) and a.items==before,"output needs a slot when input stack remains")
assert(I.produce(1,{{name="trashbag",count=2}},{{name="recyclables",count=2}}) and count("recyclables")==2,"fully consumed input frees its slot")
reset();a.maxWeight=4;assert(I.addItem(a.id,"trashbag",1));assert(I.produce(1,{{name="trashbag",count=1}},{{name="recyclables",count=1}}),"net weight permits processing a full bag")
reset();assert(I.addItem(a.id,"scrap",4,{serial="unique"}));assert(not W.begin(1,gotoPoint("scrapper","process")),"custom metadata is not consumed")
a.items={[1]={name="scrap",count=4,metadata={}}};assert(I.produce(1,{{name="scrap",count=4}},{{name="salvaged_parts",count=1}}));assert(count("scrap")==0,"empty metadata uses the same plain-item rule")
-- Leave/death/vehicle/bucket/early/forged/duplicate events cannot reward.
reset();local w=begin("scrapper","collect")
assert(not W.complete(1,{token="forged",status="success"}));assert(not W.complete(1,{token=w.token,status="success"}) and count("scrap")==0)
begin("scrapper","collect");position.x=position.x+20;W.tick();assert(not W.isActive(1))
begin("scrapper","collect");life="dead";W.onLifeState(1,life);assert(not W.isActive(1));life="alive"
begin("scrapper","collect");position.bucket=9;W.tick();assert(not W.isActive(1))
begin("scrapper","collect");seat={};W.tick();assert(not W.isActive(1));seat=nil
local point=gotoPoint("scrapper","collect");db.ready=false;assert(not W.begin(1,point));db.ready=true
LightRP.characters.switching[1]=true;assert(not W.begin(1,gotoPoint("scrapper","collect")));LightRP.characters.switching[1]=nil
-- Capacity changes mid-animation and cancellation keep committed goods.
reset();begin("scrapper","collect");assert(I.addItem(a.id,"trashbag",10));w=clone(last);now=now+w.durationMs
assert(not W.complete(1,{token=w.token,status="success"}) and count("scrap")==0 and count("trashbag")==10)
reset();begin("scrapper","collect");finish();w=clone(last);assert(not W.complete(1,{token=w.token,status="cancelled"}) and count("scrap")==4)
-- Failed SQL is all-or-nothing for collection, conversion and sale.
for _,kind in ipairs({"collect","process","sell"}) do
    reset();if kind=="process" then assert(I.addItem(a.id,"scrap",4)) elseif kind=="sell" then assert(I.addItem(a.id,"salvaged_parts",3)) end
    begin("scrapper",kind);before=a.items;bank=M.get(1).bank;w=clone(last);now=now+w.durationMs;fail=true
    assert(not W.complete(1,{token=w.token,status="success"}) and a.items==before and M.get(1).bank==bank and not a.busy)
    fail=false;begin("scrapper",kind);finish();W.cancel(1)
end
-- While SQL yields, inventory mutations/replays are refused; stop means no next batch.
reset();w=begin("scrapper","collect");now=now+w.durationMs;yieldDb=true
local co=coroutine.create(function() assert(W.complete(1,{token=w.token,status="success"})) end)
assert(coroutine.resume(co));assert(W.isBusy(1) and a.busy)
assert(not I.addItem(a.id,"water",1));assert(not I.produce(1,{},{{name="scrap",count=4}}));assert(not W.complete(1,{token=w.token,status="success"}))
assert(W.cancel(1));assert(coroutine.resume(co));yieldDb=false
assert(coroutine.status(co)=="dead" and count("scrap")==4 and not W.isActive(1) and not a.busy)
-- A post-commit hook can yield: the consumed nil token is never a valid token.
reset();w=begin("scrapper","collect");now=now+w.durationMs
local oldHook=LightRP.eachModule
LightRP.eachModule=function(name) if name=="onJobWorkCompleted" then coroutine.yield("tutorial") end end
co=coroutine.create(function() assert(W.complete(1,{token=w.token,status="success"})) end)
assert(coroutine.resume(co));assert(count("scrap")==4)
assert(not W.complete(1,{status="success"}) and count("scrap")==4,"missing token cannot replay while a hook yields")
assert(coroutine.resume(co));LightRP.eachModule=oldHook;W.cancel(1)
-- Disconnect during a captured commit does not re-arm a loop or a new identity.
reset();w=begin("scrapper","collect");now=now+w.durationMs;yieldDb=true
co=coroutine.create(function() W.complete(1,{token=w.token,status="success"}) end)
assert(coroutine.resume(co));W.onDisconnected(1);I.onDisconnected(1);M.onDisconnected(1)
assert(coroutine.resume(co));yieldDb=false;assert(not W.isActive(1))
I.onCharacterLoaded(1,char);M.onCharacterLoaded(1,char);a=I.player(1)
assert(count("scrap")==4,"completed SQL batch persists after reconnect")
assert(W.preview("scrapper").price==C.jobs.scrapper.price and W.preview("sanitation").collectWeight==4)
-- Animation failure/interruption never turns into a silent timed reward.
reset();failAnimation=true;assert(not W.begin(1,gotoPoint("scrapper","collect")));assert(not W.isActive(1));failAnimation=false
animation={active=true,playbackId="other-resource"};assert(not W.begin(1,gotoPoint("scrapper","collect")));assert(animation.playbackId=="other-resource");animation=nil
w=begin("scrapper","collect");animation=nil;now=now+w.durationMs
assert(not W.complete(1,{token=w.token,status="success"}) and count("scrap")==0)
begin("sanitation","collect");animation=nil;W.tick();assert(not W.isActive(1))
begin("scrapper","collect");animation={active=true,playbackId="replacement"};W.tick()
assert(not W.isActive(1) and animation.playbackId=="replacement","stop only the owned playback");animation=nil
-- The first day guide's practice activity: its own bucket, open only for the guide's stage, one batch per press, real items and a real sale.
reset();local practice=C.jobs.tutorial;local allowed={}
LightRP.tutorial={allowsWork=function(_,kind) return allowed[kind]==true end}
local function hallPoint(kind) local id=gotoPoint("tutorial",kind);position.bucket=practice.bucket;return id end
LightRP.eachModule=function(hook) if hook=="onJobWorkCompleted" then completed=(completed or 0)+1 end end
local refused,why=W.begin(1,hallPoint("collect"));assert(not refused and why:find("first day guide"),"closed outside the guide's step")
allowed.collect=true;position.bucket=0;now=now+600;assert(not W.begin(1,"work.tutorial.crates"),"the hall's sites do not answer from the city's bucket")
local bankBefore=M.get(1).bank;completed=0
assert(W.begin(1,hallPoint("collect")));finish()
assert(not W.isActive(1) and not animation and count(practice.raw)==1 and completed==1,"one batch, then the loop ends and the guide is told")
allowed.process=true;assert(W.begin(1,hallPoint("process")));finish()
assert(not W.isActive(1) and count(practice.raw)==0 and count(practice.product)==1 and completed==2)
assert(not W.begin(1,hallPoint("sell")),"the sale waits for its step")
allowed.sell=true;assert(W.begin(1,hallPoint("sell")));finish()
assert(count(practice.product)==0 and M.get(1).bank==bankBefore+practice.price and completed==3,"the sale pays the bank and tells the guide")
LightRP.tutorial=nil;assert(not W.begin(1,hallPoint("collect")),"without the guide the practice sites stay closed")
position.bucket=0
print("PASS: practice activity gate/bucket/single batch, free collection/processing/sales, weight/slots, real trunk transfers/locks, both chains, atomic SQL rollback/retry, no replay/early/range/life/seat/bucket exploit, in-flight inventory locks/cancel/disconnect persistence")
