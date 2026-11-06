dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/tutorial.lua"); dofile("shared/items.lua")
dofile("server/config/shops.lua"); dofile("server/config/job_work.lua")
local C=LightRpTutorialConfig; local L=C.lobby
local rows,chars,events,commands,providers={},{},{},{},{}
local time,failWrite,changedDuringWrite=0,false,nil
local function hall(contact) local q=C.contacts[contact].position;return {x=q.x,y=q.y,z=q.z,bucket=L.bucket} end
local p=hall("guide")
local life="alive"
local c={identifier="account",key="default",status="active"}; chars[1]=c
local function clone(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
local function rowkey(a,b) return a.."#"..b end
local Db={ready=true,schema=function() end}
function Db.run(sql,args)
 if failWrite then return false end
 if sql:find("INSERT") then local k=rowkey(args[1],args[2]);rows[k]=rows[k] or {step=args[3],status="active",revision=1};return true,1 end
 local r=rows[rowkey(args[3],args[4])]
 if not r or r.revision~=args[5] then return true,0 end
 r.step,r.status,r.revision=args[1],args[2],r.revision+1
 if changedDuringWrite then local fn=changedDuringWrite;changedDuringWrite=nil;fn() end
 return true,1
end
function Db.read(_,args) local r=rows[rowkey(args[1],args[2])];return true,r and {clone(r)} or {} end
local job="unemployed"
local runActive=false
local placed,refusePlace,refuseBucket={},false,false
local T
local props,cars,serial={}, {},100
LightRP={db=Db,module=function(name,v) LightRP[name]=v;if name=="tutorial" then T=v end;return v end,characters={get=function(id) return chars[id] end},
 state=function() end,stateProvider=function(k,fn) providers[k]=fn end,log=function() end,
 nowMs=function() return time end,notice=function(_,n) _G.TUTO_NOTICE=n end,result=function() end,
 jobs={get=function() return {name=job} end},jobRuns={preview=function(name) if name=="ac_cleaner" then return {} end end,snapshot=function() return {active=runActive} end},
 jobWork={preview=function(name) if name=="sanitation" then return {} end end,
  firstPoint=function(name) if name=="sanitation" then return {position={x=10,y=20,z=30},label="Collect waste"},"work.sanitation.collection_west" end end},
 command=function(name,_,fn) commands[name]=fn end,
 -- The framework's placement: the player is where the point says, in its bucket.
 spawn={place=function(_,point)
  if refusePlace then return false,"transition_in_progress" end
  placed[#placed+1]=point.name;p={x=point.position.x,y=point.position.y,z=point.position.z,bucket=point.bucket};return true end},
 nearInteraction=function(_,d,slack)
  if d.bucket~=nil and (p.bucket or 0)~=d.bucket then return false end
  return (p.x-d.position.x)^2+(p.y-d.position.y)^2+(p.z-d.position.z)^2<=(d.radius+slack)^2 end}
Open77={players={position=function() return p end,getLifeState=function() return {phase=life} end}}
GetPlayerRoutingBucket=function() return p and p.bucket or 0 end
SetPlayerRoutingBucket=function(_,bucket) if p and not refuseBucket then p.bucket=bucket;return true end;return false end
GetPlayersInBucket=function(bucket) return p and p.bucket==bucket and {1} or {} end
-- the square's camera tour, sent after each way out of the hall (client/core/arrival_tour.lua)
local tours={}
TriggerClientEvent=function(name,target,payload) if name==LightRpEvents.net.arrivalTour then tours[#tours+1]={target=target,payload=payload} end end
local noop=function() return true end
Open77.environment={getState=function()return {hour=0,minute=0,second=0,rate=8,timeFrozen=true,weather="sunny",weatherFrozen=true}end,
 setTime=noop,setTimeRate=noop,setTimeFrozen=noop,setWeather=noop,setWeatherFrozen=noop,clearBucket=noop}
AddEventHandler=function()end
GetCurrentResourceName=function()return "op77_lightrp"end
Open77.props={create=function(d) serial=serial+1;local id=tostring(serial);props[id]=d;return id end,get=function(id)return props[id]end,remove=function(id)props[id]=nil;return true end}
Open77.vehicles={create=function(d)serial=serial+1;cars[serial]=d;return serial end,get=function(id)return cars[id]end,remove=function(id)cars[id]=nil;return true end,
 setEngine=function()return true end,setDoorOpen=function(id,_,value)cars[id].trunk=value;return true end}
LightRP.keys={give=function()return true end,lock=function(id,value)cars[id].locked=value;return true end,clear=function()end}
dofile("server/modules/tutorial_practice.lua")
RegisterNetEvent=function(e,fn) events[e]=fn end
GetPlayers=function() return {1} end
CreateThread=function() end
-- op77_neuralink's export: the first day's implant step asks it
local implant=false
local closed=0
exports={op77_neuralink={isInstalled=function(_,id) return implant end,closeInterface=function(_,id) closed=closed+1 end,
 -- an export may not wait for a database write: a skip must never install through one
 install=function() error("export_yielded") end}}
-- A skip asks op77_neuralink with an event; its answer comes back later (neuralink_bridge).
local installs,timers=0,{}
TriggerEvent=function(name,id) if name=="op77_neuralink:requestInstall" then installs=installs+1 end end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
local function expire() local due=timers;timers={};for _,fn in ipairs(due) do fn() end end
dofile("server/modules/tutorial.lua")
local function state() return providers.tutorial(1) end
local function action(operation,extra)
 time=time+400;source=1
 local s=state();local v={operation=operation,key=s.key,revision=s.revision}
 for k,val in pairs(extra or {}) do v[k]=val end
 events[LightRpEvents.net.tutorial](v)
end
local function talk(step,contact,nextStep)
 assert(state().step==step,"expected "..step.." got "..tostring(state().step))
 assert(state().objective.kind=="talk" and state().contact==C.contacts[contact].name)
 p=hall("guide");if contact=="guide" then p.x=p.x+60 end
 action("talk");assert(state().dialogue==nil,step..": talking needs real proximity")
 p=hall(contact);action("talk");assert(state().dialogue==step and #state().lines>=3 and state().camera,step..": conversation opens with its shot")
 action("next");assert(state().step==nextStep,step.." moves on to "..nextStep.." got "..state().step)
end

-- Configuration: the steps are a chain, every stop of the hall exists.
for i,step in ipairs(C.order) do assert(C.steps[step],"unknown step "..step) end
local spot;for _,s in ipairs(LightRpShops.locations) do if s.id==L.shop then spot=s end end
assert(spot and spot.bucket==L.bucket,"the hall has its shop, in its bucket")
local practice=LightRpJobWork.jobs[L.work]
assert(practice and practice.tutorial and practice.once and practice.bucket==L.bucket and #practice.points==3,"the hall has its practice activity, in its bucket")
assert(LightRpItems[practice.raw] and LightRpItems[practice.product],"the practice items exist")
for _,d in ipairs(LightRpConfig.jobs.centers) do assert(d.bucket==nil,"no job is chosen in the hall") end
local function site(kind) for _,q in ipairs(practice.points) do if q.kind==kind then return q,"work."..L.work.."."..q.id end end end

T.onCharacterLoaded(1,c);assert(not state().active,"existing characters are not forced into a new tutorial")
assert(T.spawnPoint(1)==nil,"no guide, no say in where one wakes up")
assert(T.startFor(1,c,true));assert(state().step=="intro" and T.arrivalPending(1))
assert(#placed==0,"a first arrival is placed by the spawn module, once")
local wake=T.spawnPoint(1);assert(wake and wake.bucket==L.bucket and wake.position==L.arrival.position,"a hall step wakes up at the hall's door")
assert(T.deathPoint(1).bucket==L.bucket,"dying in the hall comes back to its door")
assert(state().opening and state().opening.place,"the opening scene carries its texts")
life="recovering";action("intro");assert(state().step=="intro","local arrival cannot bypass server recovery")
life="alive";p.bucket=0;action("intro");assert(state().step=="intro","the destination bucket must settle")
p.bucket=L.bucket;local saved=p;p=nil;action("intro");assert(state().step=="intro","missing server position keeps the checkpoint")
p=saved;life="dead";action("intro");assert(state().step=="intro","intro completion never revives or skips death")
life="alive";action("intro");assert(state().step=="meet","retry succeeds once the same arrival is ready")
action("intro",{revision=1});assert(state().step=="meet","a duplicated acknowledgement cannot advance twice")
p.bucket=0;action("talk");assert(state().dialogue==nil,"the hall's contacts only answer in the hall's bucket")
p.bucket=L.bucket;life="dead";action("talk");assert(state().dialogue==nil)
life="alive";action("talk");assert(state().dialogue=="meet")
action("next",{key="other"});assert(state().step=="meet","late packets cannot target another slot")
action("next");assert(state().step=="neuralink","the implant comes right after Mara")
assert(state().todo and #state().todo==3 and state().todo[1].key=="F2","the card tells to press F2")
T.onInventoryOpened(1);action("finish");assert(state().step=="neuralink","nothing else moves the implant step")
commands.tutorial(1,{"pause"});assert(state().active and state().step=="neuralink","no pause without a Neural-Link")
T.onNeuralinkInstalled(1);assert(state().step=="neuralink","the event alone is not enough: the implant must really be there")
assert(closed==0,"the phone stays open while the implant is missing")
implant=true;T.onNeuralinkInstalled(1);assert(state().step=="voice","an installed implant moves on")
assert(closed==1,"the phone is put away for the voice step")
T.onNeuralinkInstalled(1);assert(state().step=="voice","a second installation does not skip a step")
assert(closed==1,"a later installation leaves the phone alone")
action("finish");assert(state().step=="voice","voice is optional but cannot complete the entire guide")
action("voice-configured");assert(state().step=="dress","already configured keeps the guide moving")
assert(state().objective and state().objective.interaction=="wardrobe.lobby_fitting","the hall's fitting room is the destination")
T.onDressed(1,false,{"trousers"});assert(state().step=="dress","a look saved in underwear does not count")
assert(TUTO_NOTICE and TUTO_NOTICE.body:find("no trousers"),"a look saved without trousers says what is missing")
action("finish");assert(state().step=="dress","the browser cannot dress the player")
T.onDressed(1,true);assert(state().step=="identity","clothes on: the guide moves on")
T.onDressed(1,true);assert(state().step=="identity","a later saved look does not skip a step")
action("finish");assert(state().step=="identity","browser cannot skip authoritative objectives")
T.onItemUsed(1,"water");assert(state().step=="identity")
action("identity");assert(state().step=="inventory")
assert(not T.allowsWork(1,"collect"),"the practice sites are closed outside their steps")
T.onInventoryOpened(1);assert(state().step=="shop")
assert(state().objective.interaction=="shop."..L.shop and state().objective.position==spot.position,"the shop step points at the hall's real vendor")
T.onItemUsed(1,"water");assert(state().step=="shop","drinking early does not skip the purchase")
T.onShopCheckout(1,"sell",L.shop);assert(state().step=="shop","selling is not the lesson")
T.onShopCheckout(1,"buy",L.shop);assert(state().step=="drink","a settled purchase moves on")
T.onShopCheckout(1,"buy",L.shop);assert(state().step=="drink","duplicate hooks do not advance twice")
T.onItemUsed(1,"burrito");assert(state().step=="drink")
failWrite=true;T.onItemUsed(1,"water");assert(state().step=="drink","failed persistence does not claim progress")
failWrite=false;T.onItemUsed(1,"water");assert(state().step=="bank")
talk("bank","banker","garage");refuseBucket=true;talk("garage","mechanic","context_prop")
assert(state().practiceError and not state().practice and p.bucket==L.bucket,"failed entry offers recovery without advancing the exercise")
refuseBucket=false;action("practice-retry")
local practiceScene=state().practice;assert(practiceScene and props[practiceScene.prop] and cars[practiceScene.vehicle].locked)
local private=C.practice.bucketBase+1
assert(p.bucket==private and practiceScene.bucket==private and props[practiceScene.prop].bucket==private and cars[practiceScene.vehicle].bucket==private,"the participant and both training objects share only their private bucket")
assert(T.spawnPoint(1).bucket==private and T.deathPoint(1).bucket==private,"reconnect and respawn stay in the private lesson")
action("next");assert(state().step=="context_prop","a browser next cannot fake an Alt exercise")
action("practice-prop",{prop="999"});assert(state().step=="context_prop","wrong target rejected")
p={x=practiceScene.propPosition.x,y=practiceScene.propPosition.y,z=practiceScene.propPosition.z,bucket=0}
action("practice-prop",{prop=practiceScene.prop});assert(state().step=="context_prop","wrong bucket rejected")
p.bucket=L.bucket;action("practice-prop",{prop=practiceScene.prop});assert(state().step=="context_prop","the shared hall cannot complete a private exercise")
p.bucket=private;life="dead";action("practice-prop",{prop=practiceScene.prop});assert(state().step=="context_prop")
life="alive";p.x=p.x+20;action("practice-prop",{prop=practiceScene.prop});assert(state().step=="context_prop","distance enforced")
p.x=p.x-20;action("practice-prop",{prop=practiceScene.prop});assert(state().step=="vehicle_unlock")
T.onVehicleContextAction(1,999,"unlock");assert(state().step=="vehicle_unlock","someone else's car cannot advance")
T.onVehicleContextAction(1,practiceScene.vehicle,"open_5");assert(state().step=="vehicle_unlock","actions stay ordered")
T.onVehicleContextAction(1,practiceScene.vehicle,"unlock");assert(state().step=="vehicle_open")
-- Reconnection rebuilds the exact checkpoint without demanding a now-hidden unlock step.
LightRP.tutorialPractice.onDisconnected(1);T.onDisconnected(1);T.onCharacterLoaded(1,c);T.onGameplayReady(1)
practiceScene=state().practice;assert(practiceScene and not cars[practiceScene.vehicle].locked)
T.onVehicleContextAction(1,practiceScene.vehicle,"open_5");assert(state().step=="vehicle_close")
LightRP.tutorialPractice.clear(1);T.onGameplayReady(1);practiceScene=state().practice
assert(cars[practiceScene.vehicle].trunk,"resuming the close checkpoint rebuilds an open trunk")
T.onVehicleContextAction(1,practiceScene.vehicle,"close_5");assert(state().step=="station")
assert(p.bucket==L.bucket,"closing the trunk returns to the shared hall before the next objective")
assert(not next(cars) and not next(props),"the lesson returns temporary props, vehicle and keys")
talk("station","attendant","collect")

-- Pausing in the hall opens the door: nobody is left locked in.
placed={};p=hall("attendant");action("pause")
assert(state().status=="paused" and placed[1]==LightRpConfig.spawn.afterTutorial.name and p.bucket==0,"continuing alone leaves the hall for the city")
assert(#tours>=1 and tours[#tours].target==1 and tours[#tours].payload.center.x==(LightRpTutorialConfig.arrivalTour.center or LightRpConfig.spawn.afterTutorial.position).x,"out on the square: the camera tour is asked for")
T.onDisconnected(1);T.onCharacterLoaded(1,c);assert(state().status=="paused" and state().step=="collect")
assert(T.spawnPoint(1)==nil and T.deathPoint(1)==nil,"a paused guide does not decide where one wakes up")
assert(not T.allowsWork(1,"collect"),"a paused guide closes the practice sites")
c.position={x=L.origin.x,y=L.origin.y,z=L.origin.z};assert(T.spawnPoint(1).bucket==0,"saved inside the hall without a hall step: the city")
c.position=nil
placed={};action("resume");assert(state().active and state().step=="collect","resume preserves checkpoint")
assert(placed[1]==L.arrival.name and p.bucket==L.bucket,"resuming a hall step goes back to the hall")

-- The practice activity: three sites, each open for its stage, one settled batch each. No job is involved.
local point,id=site("collect")
assert(state().objective.interaction==id and state().objective.position==point.position,"the collect step points at the practice crates")
assert(T.allowsWork(1,"collect") and not T.allowsWork(1,"process") and not T.allowsWork(1,"sell"),"only the stage being learnt is open")
job="sanitation";T.onJobWorkCompleted(1,"sanitation","collect");assert(state().step=="collect","city work is not the lesson")
T.onJobWorkCompleted(1,L.work,"process");assert(state().step=="collect","a stage cannot be skipped")
T.onJobWorkCompleted(1,L.work,"collect");assert(state().step=="process")
point,id=site("process");assert(state().objective.interaction==id)
assert(T.allowsWork(1,"collect") and T.allowsWork(1,"process") and not T.allowsWork(1,"sell"),"a lost crate can be collected again")
T.onJobWorkCompleted(1,L.work,"collect");assert(state().step=="process","collecting again does not move on")
T.onJobWorkCompleted(1,L.work,"process");assert(state().step=="sell")
point,id=site("sell");assert(state().objective.interaction==id and state().contact==C.contacts.guide.name)
T.onJobWorkCompleted(1,L.work,"sell");assert(state().step=="depart","the sale ends the practice")
assert(not T.allowsWork(1,"collect"),"the practice is not an income once learnt")

-- Leaving: the checkpoint, then the door to the city.
local granted,movedIn={},0
LightRP.housing={starter={grant=function(pl) granted[#granted+1]=pl; return {id=7} end,moveIn=function() movedIn=movedIn+1; return {id=7} end}}
p=hall("guide");action("talk");placed={};refusePlace=true;action("next")
assert(state().step=="outro" and #placed==0,"a refused placement keeps the earned checkpoint")
assert(granted[1]==1 and movedIn==0,"the starter studio is given, the newcomer is not taken inside it")
refusePlace=false;assert(commands.tutorial(1,{}));assert(placed[1]==LightRpConfig.spawn.afterTutorial.name and p.bucket==0,"/tutorial retries the way to the city")
assert(math.abs(p.x-LightRpConfig.spawn.afterTutorial.position.x)<0.01 and math.abs(p.y-LightRpConfig.spawn.afterTutorial.position.y)<0.01,"the city point after the guide")
LightRP.housing=nil
assert(T.spawnPoint(1)==nil,"the city step wakes up by the usual rules")
assert(state().where=="city" and #state().lines==3 and state().objective==nil,"the last word is a message, in the city")
action("pause");action("resume");assert(state().step=="outro","the checkpoint survives a pause")
action("finish");assert(state().status=="done")
T.onDisconnected(1);T.onCharacterLoaded(1,c);assert(state().status=="done","completion survives reconnect")
placed={};action("resume");assert(state().step=="meet" and not T.arrivalPending(1) and placed[1]==L.arrival.name,"a replay is asked for: it goes back to the hall, without the opening scene")

-- /tutorial restart: an existing character plays the whole day again, opening included.
placed={};assert(commands.tutorial(1,{"restart"}));assert(state().active and state().step=="intro" and T.arrivalPending(1) and placed[1]==L.arrival.name and p.bucket==L.bucket,"restart goes back to the first step, at the hall's door")
rows={};T.onDisconnected(1);T.onCharacterLoaded(1,c);assert(not state().active);placed={}
assert(commands.tutorial(1,{"restart"}));assert(state().step=="intro" and placed[1]==L.arrival.name,"restart also starts a character that never had the guide")
refusePlace=true;local ok=commands.tutorial(1,{"restart"});refusePlace=false;assert(not ok and state().step=="intro","a refused placement says so and keeps the step")
-- Pausing/restarting a restored private checkpoint also releases its bucket.
rows={[rowkey("account","default")]={step="vehicle_close",status="active",revision=20}}
T.onCharacterLoaded(1,c);p=hall("mechanic");T.onGameplayReady(1)
assert(p.bucket==private and state().practice)
failWrite=true;action("pause");assert(p.bucket==private and state().active,"a failed checkpoint write cannot move the player or discard practice")
failWrite=false;action("pause");assert(p.bucket==0 and not next(cars) and not next(props),"pausing leaves the private lesson and follows the normal city exit")
action("resume");assert(p.bucket==private and state().practice and cars[state().practice.vehicle].trunk,"resuming rebuilds the saved private checkpoint")
assert(commands.tutorial(1,{"restart"}));assert(p.bucket==L.bucket and state().step=="intro" and not next(cars),"restarting returns to the shared intro")
-- Skipping the first day, right after the creator: implant, studio, done.
local function freshArrival()
 rows={};implant=false;installs=0;T.onDisconnected(1);T.onCharacterLoaded(1,c)
 assert(T.startFor(1,c,true) and state().step=="intro")
 local a=L.arrival.position;p={x=a.x,y=a.y,z=a.z,bucket=L.bucket};life="alive"
end
freshArrival();timers={}
life="dying";action("skip");assert(state().active and state().step=="intro" and installs==0,"no skip while not on one's feet")
life="alive";local saved=p;p=nil;action("skip");p=saved;assert(state().active and installs==0,"no skip while the server has no position")
action("skip");assert(installs==1 and state().active and state().step=="intro","no implant yet: it is asked for, the guide waits")
action("skip");assert(installs==1,"a second click while waiting does not ask twice")
T.onImplantFailed(1,"no_line");assert(state().active and state().step=="intro" and not implant,"a failed implant keeps the guide, nothing is half done")
expire();assert(state().active,"the late timer of an answered request does nothing")
action("skip");assert(installs==2,"after a failure the skip can be asked again")
expire();assert(state().active and state().step=="intro","no answer: the wait ends, the guide stays")
T.onImplantFitted(1);assert(state().active,"an implant nobody waits for any more does not skip")
local studio,movedIn={},0
LightRP.housing={starter={grant=function(pl) studio[#studio+1]=pl;return {id=7} end,moveIn=function() movedIn=movedIn+1;p={x=1,y=2,z=3,bucket=900};return {id=7} end}}
placed={};action("skip");assert(installs==3 and state().active,"asked once more")
T.onImplantFitted(1);assert(state().active,"the announcement alone is not enough: the implant must really be there")
action("skip");assert(installs==4,"the stale wait was released")
implant=true;T.onImplantFitted(1)
assert(state().status=="done" and not state().active,"the implant fitted, the skip ends the guide")
assert(studio[1]==1 and movedIn==0 and placed[1]==LightRpConfig.spawn.afterTutorial.name and p.bucket==0,"like the guide's end: the studio is given, the newcomer goes to the city point after the guide")
assert(math.abs(p.x-LightRpConfig.spawn.afterTutorial.position.x)<0.01 and math.abs(p.y-LightRpConfig.spawn.afterTutorial.position.y)<0.01,"the same point as the guide's end")
T.onImplantFitted(1);assert(#studio==1 and #placed==1,"a duplicate answer does nothing")
assert(T.spawnPoint(1)==nil and T.deathPoint(1)==nil and not T.allowsWork(1,"collect"),"a skipped guide decides nothing")
T.onDisconnected(1);T.onCharacterLoaded(1,c);assert(state().status=="done","the skip survives reconnect")
action("skip");assert(installs==4 and state().status=="done","a skip packet without a guide does nothing")
placed={};action("resume");assert(state().active and state().step=="meet" and placed[1]==L.arrival.name,"Mara is still there afterwards")
-- Without a city point after the guide, the skip (like the guide's end) wakes them inside the studio.
local cityPoint=LightRpConfig.spawn.afterTutorial;LightRpConfig.spawn.afterTutorial=nil
freshArrival();implant=true;studio,movedIn={},0
placed={};action("skip");assert(state().status=="done" and movedIn==1 and #studio==0 and #placed==0,"no city point: the newcomer wakes up in the studio")
LightRpConfig.spawn.afterTutorial=cityPoint
-- No studio (housing off): from the hall the door opens on the city; an installed implant leaves at once.
freshArrival();implant=true;LightRP.housing=nil
placed={};action("skip");assert(state().status=="done" and installs==0,"an implant in place is not asked for again")
assert(placed[1]==LightRpConfig.spawn.afterTutorial.name and p.bucket==0,"without a studio the city's arrival")
-- From the private Alt lesson: its car and crate are returned.
rows={[rowkey("account","default")]={step="vehicle_open",status="active",revision=30}}
T.onCharacterLoaded(1,c);p=hall("mechanic");T.onGameplayReady(1);assert(p.bucket==private and state().practice and next(cars))
placed={};action("skip");assert(state().status=="done" and not next(cars) and not next(props) and p.bucket==0,"a skip leaves the private lesson clean")
-- /tutorial skip does the same; a refused way out keeps the checkpoint and is retried by the command.
freshArrival();refusePlace=true;local ok,said=commands.tutorial(1,{"skip"})
assert(ok and said:find("Neural%-Link") and installs==1 and state().active,"the command says it is fitting the implant")
implant=true;T.onImplantFitted(1);refusePlace=false
assert(state().status=="done" and p.bucket==L.bucket,"a refused placement keeps the player in the hall, the guide done")
ok,said=commands.tutorial(1,{"skip"});assert(ok and p.bucket==0 and placed[#placed]==LightRpConfig.spawn.afterTutorial.name,"/tutorial skip retries the door")
freshArrival();ok=commands.tutorial(1,{"skip"});implant=true;T.onImplantFitted(1);assert(ok and state().status=="done","/tutorial skip from the arrival")
-- A player who leaves while the implant is fitted takes the wait with them.
freshArrival();action("skip");T.onDisconnected(1);T.onCharacterLoaded(1,c);implant=true;T.onImplantFitted(1)
assert(state().active and state().step=="intro","a reconnect does not inherit an old skip")

-- Checkpoints of the earlier guide (steps that no longer exist) still load.
for old,new in pairs({employment="collect",shift="outro",whatever="meet"}) do
 rows={[rowkey("account","default")]={step=old,status="active",revision=4}};T.onDisconnected(1);T.onCharacterLoaded(1,c)
 assert(state().active and state().step==new,"a legacy "..old.." checkpoint resumes at "..new)
 placed={};assert(commands.tutorial(1,{"restart"}) and state().step=="intro","and can be restarted")
end
changedDuringWrite=function() chars[1]={identifier="account",key="slot2",status="active"};T.onCharacterLoaded(1,chars[1]) end
action("pause");assert(not state().active,"a yielded old save cannot take over the next character")
Db.ready=false;T.onCharacterLoaded(1,chars[1]);assert(T.startFor(1,chars[1]),"no-DB mode never leaves a permanent loading lock")
print("PASS: hall configuration, lifecycle, bucket/proximity/life gates, real action hooks (inventory, purchase, drink, practice collect/process/sell), hall <-> city placement, persistence, pause/resume, skip (implant, studio, city fallback, private lesson), duplicates, slot races, legacy accounts")
