-- Persistent unconscious state and paid, timed assistance. Native life remains
-- authoritative; the page can request actions, never choose health or deadlines.
local M,C,Db,Inv=LightRP.medical,LightRpMedicalConfig,LightRP.db,LightRP.inventory
local NET="op77_lightrp:medical"
local function now()return LightRP.nowMs()end
local function unix()return Open77.time.unix()end
local function id(value)local n=tonumber(value);return n and n%1==0 and n>0 and n or nil end
local function character(player)return LightRP.characters.get(player)end
local function inventory(player)return player and Inv.player(player)end
local function life(player)return player and Open77.players.getLifeState(player)end
local function validCharacter(player)
 local c=character(player);return c and c.status=="active"and c
end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<10000000 end
local function fresh(player)
 if not id(player)then return nil end
 local r=Open77.players.get(player)
 if not r or not r.position or type(r.ageMs)~="number"or r.ageMs>C.maxPositionAgeMs or not finite(r.position.x)or not finite(r.position.y)or not finite(r.position.z)or not finite(r.bucket)then return nil end
 return {x=r.position.x,y=r.position.y,z=r.position.z,bucket=r.bucket}
end
local function distance(a,b)
 if not a or not b then return math.huge end
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z;return math.sqrt(x*x+y*y+z*z)
end
local function kitCount(inv)
 local n=0;for _,item in pairs(inv and inv.items or{})do if item.name==C.kit then n=n+item.count end end;return n
end
local function notify(player,body,kind)if player then LightRP.notice(player,{kind=kind or"info",title="Medical assistance",body=body,durationMs=6000})end end
local function subject(player)
 local s=M.subjects[player];local inv=inventory(player)
 return s and inv==s.inventory and character(player)==s.character and s or nil
end
function M.isDowned(player)return subject(player)~=nil end
function M.isBusy(player)return M.treatments[player]~=nil or M.isDowned(player)end
function M.handlesDeath(player)return M.subjects[player]~=nil end
function M.view(player)
 local s=subject(player);local a=M.treatments[player]
 local r=s and s.record
 local pending=r and r.attempt and M.attempts[r.attempt]
 local native=life(player)
 local releasable=r and(r.status=="downed"or(r.status=="reviving"and pending and pending.phase=="uncertain"and native and native.phase=="dead"))
 return {downed=s~=nil,persisted=r~=nil,phase=r and r.status or s and"saving"or"healthy",
  remainingMs=r and math.max(0,math.ceil((r.since+C.giveUpDelayMs/1000-unix())*1000))or C.giveUpDelayMs,
  canGiveUp=releasable and not s.patientTreatment and unix()>=r.since+C.giveUpDelayMs/1000 or false,
  treatment=a and{token=a.token,phase=a.phase,remainingMs=math.max(0,(a.startedAt or now())+C.treatmentMs-now()),durationMs=C.treatmentMs,patient=a.patientName}or nil,
  receiving=s and s.patientTreatment and true or false,error=s and s.error}
end
function M.push(player)if id(player)then TriggerClientEvent(NET,player,{kind="state",state=M.view(player)})end end
local function stopPlayback(a)if a.playbackId and id(a.actor)then pcall(Open77.animations.stop,a.actor,a.playbackId);a.playbackId=nil end end
local function releaseTreatment(a,message)
 if M.treatments[a.actor]~=a then return end
 M.treatments[a.actor]=nil
 local s=subject(a.patient);if s and s.patientTreatment==a then s.patientTreatment=nil;M.push(a.patient)end
 stopPlayback(a)
 TriggerClientEvent(NET,a.actor,{kind="treatment",phase="finished",token=a.token})
 M.push(a.actor);if message then notify(a.actor,message)end
end
function M.cancel(player,reason)
 local a=M.treatments[player]
 if a and(a.phase=="preparing"or a.phase=="playing")then releaseTreatment(a,reason or"Treatment interrupted. Your kit was kept.")end
 for actor,other in pairs(M.treatments)do
  if other.patient==player and(other.phase=="preparing"or other.phase=="playing")then releaseTreatment(other,"The patient is no longer available. Your kit was kept.")end
 end
end
local function exempt(player,l)
 if not validCharacter(player)then return true end
 if l.cause=="script"and not C.downedScriptWeapons[l.weapon]then return true end
 if LightRP.tutorial and LightRP.tutorial.deathPoint and LightRP.tutorial.deathPoint(player)then return true end
 if LightRP.missions and LightRP.missions.handlesDeath and LightRP.missions.handlesDeath(player)then return true end
 if LightRP.activities and LightRP.activities.owns(player)then return true end
 return false
end
local function attach(player)
 local inv=inventory(player);if not inv or not validCharacter(player)then return end
 local r,why=M.load(inv)
 if why then M.subjects[player]={inventory=inv,character=character(player),error=why};M.push(player);return end
 if r then
  M.subjects[player]={inventory=inv,character=character(player),record=r,needsPlacement=true}
  if r.attempt then
   local a=M.readAttempt(r.attempt)
   if a and a.status=="dispatching"then a.phase="resume";a.recovered=true;a.patient=player;M.attempts[a.id]=a end
  end
 end
 M.push(player)
end
local function capture(player,l)
 if subject(player)then return end
 local inv=inventory(player);if not inv then return end
 local s={inventory=inv,character=character(player)};M.subjects[player]=s;M.push(player)
 local old,why=M.load(inv)
 if old then s.record=old;return end
 local p=l.position or fresh(player);local token=M.uuid()
 if why or not p or not token then s.error="Medical persistence is unavailable. Waiting for synchronization.";return end
 local r={token=token,revision=1,status="downed",since=unix(),position={x=p.x,y=p.y,z=p.z},bucket=l.bucket or p.bucket or 0,heading=l.yaw or 0}
 local ok=Db.transaction({{query="INSERT INTO lightrp_medical_deaths (inventory_id,token,revision,status,definition) VALUES (?,?,?,?,?)",values={inv.id,token,1,r.status,json.encode(r)}}})
 if subject(player)~=s then return end
 if ok then M.records[inv.id]=r;s.record=r;s.error=nil else M.records[inv.id]=nil;s.error="Medical persistence is unavailable. Waiting for synchronization."end
 M.push(player)
end
function M.spawnPoint(player)
 local s=subject(player);local r=s and s.record
 if not r then return nil end
 if r.status=="hospital"then
  M.restoring[player]="hospital"
  return LightRpConfig.spawn.hospital
 end
 M.restoring[player]="downed"
 return {name="medical",position=M.clone(r.position),bucket=r.bucket,heading=r.heading or 0}
end
local function applyRecord(invId,r)
 M.records[invId]=r
 for _,raw in ipairs(GetPlayers())do
  local player=id(raw);local inv=inventory(player)
  if inv and inv.id==invId and validCharacter(player)then
   local current=subject(player)
   if not current then
    current={inventory=inv,character=character(player),needsPlacement=true};M.subjects[player]=current
   elseif not current.record then
    local native=life(player);current.needsPlacement=not native or native.phase~="dead"
   end
   if not current.record or current.record.token==r.token then
    current.record=r;current.error=nil
    if r.status=="hospital"then current.needsPlacement=true end
   end
  end
 end
end
local function currentPatient(a)
 local s=subject(a.patient)
 return s and s.record and s.record.token==a.deathToken and s.inventory.id==a.patientInventory and s or nil
end
local function treatmentValid(a)
 local s=currentPatient(a);local inv=inventory(a.actor)
 if not s or s.patientTreatment~=a or s.record.status~="downed"or inv~=a.inventory or character(a.actor)~=a.character or not validCharacter(a.actor)or M.isDowned(a.actor)then return false end
 local actorLife,patientLife=life(a.actor),life(a.patient)
 if not actorLife or actorLife.phase~="alive"or not patientLife or patientLife.phase~="dead"then return false end
 local ap,pp=fresh(a.actor),fresh(a.patient)
 if not ap or not pp or ap.bucket~=pp.bucket or distance(ap,pp)>C.range or distance(ap,a.origin)>C.movementTolerance or distance(pp,a.patientOrigin)>C.patientMovementTolerance then return false end
 if kitCount(inv)<1 then return false end
 local seat=Open77.vehicles.getPlayerSeat(a.actor);if seat and seat.vehicleId then return false end
 if a.playbackId then local playback=Open77.animations.current(a.actor);if not playback or playback.playbackId~=a.playbackId then return false end end
 return true
end
function M.begin(player)
 if M.isBusy(player)or not validCharacter(player)then return false,"You cannot provide assistance right now."end
 if LightRP.consumables and LightRP.consumables.isActive(player)then return false,"Finish your current action first."end
 local inv=inventory(player);local ap=fresh(player);local l=life(player)
 if not inv or kitCount(inv)<1 or not ap or not l or l.phase~="alive"then return false,"You need a trauma kit and must be standing near the patient."end
 local seat=Open77.vehicles.getPlayerSeat(player)
 if seat and seat.vehicleId then return false,"Leave your vehicle before treating a patient."end
 local playback=Open77.animations.current(player);if playback and playback.active then return false,"Finish your current action first."end
 local nearest,nearestDistance
 for patient,s in pairs(M.subjects)do
  local pp=fresh(patient);local pl=life(patient)
  if patient~=player and subject(patient)==s and s.record and s.record.status=="downed"and not s.patientTreatment and pp and pp.bucket==ap.bucket and pl and pl.phase=="dead"then
   local d=distance(ap,pp);if d<=C.range and(not nearestDistance or d<nearestDistance)then nearest,nearestDistance=patient,d end
  end
 end
 if not nearest then return false,"No unconscious patient is close enough. Move within 2.5 metres."end
 local s=subject(nearest);local token=M.uuid();if not token then return false,"Medical persistence is unavailable."end
 if subject(nearest)~=s or s.patientTreatment or s.record.status~="downed"then return false,"Someone is already helping this patient."end
 local a={token=token,actor=player,patient=nearest,inventory=inv,character=character(player),origin=ap,patientOrigin=fresh(nearest),
  patientInventory=s.inventory.id,deathToken=s.record.token,phase="preparing",expires=now()+7000,patientName=LightRP.characters.displayName(nearest)}
 M.treatments[player]=a;s.patientTreatment=a
 TriggerClientEvent(NET,player,{kind="treatment",phase="prepare",token=token,durationMs=C.treatmentMs,patient=a.patientName})
 M.push(player);M.push(nearest);return true
end
local function takeKit(draft)
 for slot=1,draft.slots do local item=draft.items[slot];if item and item.name==C.kit then
  local taken={name=item.name,count=1,metadata=M.clone(item.metadata)};item.count=item.count-1;if item.count==0 then draft.items[slot]=nil end;return taken
 end end
end
local function refund(player,receipt)
 local inv=inventory(player);if not inv or inv.id~=receipt.actorInventory then return false end
 return Inv.transaction(player,function(current)
  local latest=M.readAttempt(receipt.id)
  if not latest then return false end
  if latest.status=="refunded"then return true end
  if latest.status~="failed"then return false end
  local draft=Inv.draft(current);local slot
  for n=1,draft.slots do if not draft.items[n]then slot=n;break end end
  if not slot then draft.slots=draft.slots+1;slot=draft.slots end
  draft.items[slot]=M.clone(receipt.kit)
  M.internal[current.id]=true
  local called,ok=pcall(Inv.commitDrafts,{{current,draft}},{{query="UPDATE lightrp_medical_attempts SET status='refunded' WHERE id=? AND status='failed'",values={receipt.id}}})
  M.internal[current.id]=nil
  return called and ok==true
 end)
end
local function failAttempt(a,reason)
 local s=currentPatient(a)
 local queries={{query="UPDATE lightrp_medical_attempts SET status='failed' WHERE id=? AND status='dispatching'",values={a.id}}}
 local stored=s and s.record or M.records[a.patientInventory]
 if not stored then stored=M.load({id=a.patientInventory})end
 local r=stored and stored.token==a.deathToken and M.clone(stored)or nil
 if r then r.status="downed";r.revision=r.revision+1;r.attempt=nil;M.appendWrite(queries,a.patientInventory,r)end
 local ok=Db.transaction(queries)
 if not ok then a.phase="failure_pending";a.failure=reason;return end
 if r then applyRecord(a.patientInventory,r)end
 if not s and r then
  for player,other in pairs(M.subjects)do
   if subject(player)==other and other.inventory.id==a.patientInventory and other.record and other.record.token==a.deathToken then s=other;a.patient=player;break end
  end
 end
 if s then
  s.record=r;s.patientTreatment=nil;M.records[a.patientInventory]=r
  local currentLife=life(a.patient)
  if currentLife and(currentLife.phase=="alive"or currentLife.phase=="recovering")and not s.needsPlacement and not M.restoring[a.patient]then
   if M.removeRecord(a.patientInventory,a.deathToken)then M.subjects[a.patient]=nil end
  end
  M.push(a.patient)
 end
 a.status="failed";a.phase="refund_pending"
 local actor=id(a.actor)
 if actor and inventory(actor)and inventory(actor).id==a.actorInventory and refund(actor,a)then M.attempts[a.id]=nil;notify(actor,"Treatment could not be applied. Your trauma kit was returned.")end
 if actor and M.treatments[actor]==a then releaseTreatment(a)end
end
local function confirmAttempt(a)
 local s=currentPatient(a)
 if not s then return false end
 local ok=M.removeRecord(a.patientInventory,a.deathToken,{{query="UPDATE lightrp_medical_attempts SET status='complete' WHERE id=? AND status='dispatching'",values={a.id}}})
 if not ok then a.phase="finalize_pending";return false end
 M.subjects[a.patient]=nil;M.restoring[a.patient]=nil;M.attempts[a.id]=nil
 if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end
 M.push(a.patient);notify(a.patient,"You have been stabilized. Rest and seek further medical care.","success")
 if a.actor and inventory(a.actor)and inventory(a.actor).id==a.actorInventory then notify(a.actor,"Patient stabilized. One trauma kit was used.","success")end
 return true
end
local function dispatchPositionValid(a)
 if a.recovered or a.dispatchedAt then return true end
 if character(a.actor)~=a.character or inventory(a.actor)~=a.inventory or M.isDowned(a.actor)then return false end
 local actorLife=life(a.actor);local ap,pp=fresh(a.actor),fresh(a.patient)
 local seat=Open77.vehicles.getPlayerSeat(a.actor);if seat and seat.vehicleId then return false end
 return actorLife and actorLife.phase=="alive"and ap and pp and ap.bucket==pp.bucket
  and distance(ap,pp)<=C.range and distance(ap,a.origin)<=C.movementTolerance and distance(pp,a.patientOrigin)<=C.patientMovementTolerance
end
local function dispatch(a)
 local s=currentPatient(a);local pl=life(a.patient)
 if s and a.recovered and(s.needsPlacement or M.restoring[a.patient])then a.phase="resume";return end
 if not s or s.needsPlacement or M.restoring[a.patient]then
  -- No native request has been sent. Undo the durable reservation even when
  -- the patient left during the escrow SQL await; refund can queue offline.
  failAttempt(a,"The patient disconnected before revival was dispatched.")
  if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end
  return
 end
 if not pl or pl.phase~="dead"then
  if pl and(pl.phase=="alive"or pl.phase=="recovering")then
   if a.dispatchedAt then confirmAttempt(a)else failAttempt(a,"The patient recovered before treatment was applied.")end
  end
  return
 end
 if not dispatchPositionValid(a)then
  failAttempt(a,"Treatment was interrupted before revival was applied.")
  if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end
  return
 end
 if not Open77.ready.isReady(a.patient)then
  a.phase="resume"
  if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end
  return
 end
 local accepted,ok,why=pcall(Open77.players.revive,a.patient,{health=C.reviveHealth,graceMs=C.reviveGraceMs})
 if not accepted or ok~=true then
  failAttempt(a,tostring(why or ok));if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end;return
 end
 a.phase="awaiting";a.dispatchedAt=now()
 if a.actor and M.treatments[a.actor]==a then releaseTreatment(a)end
 M.push(a.patient)
end
local function commitTreatment(a)
 if a.phase~="playing"or not treatmentValid(a)then releaseTreatment(a,"Treatment interrupted. Your kit was kept.");return end
 a.phase="committing"
 local called,saved,why=pcall(Inv.transaction,a.actor,function(inv)
  if not treatmentValid(a)then return false,"The patient or kit changed."end
  local s=currentPatient(a);local draft=Inv.draft(inv);local kit=takeKit(draft)
  if not kit then return false,"Your trauma kit is unavailable."end
  local r=M.clone(s.record);r.status="reviving";r.revision=r.revision+1;r.attempt=a.token
  local receipt={id=a.token,actor=a.actor,actorInventory=inv.id,patientInventory=a.patientInventory,deathToken=a.deathToken,kit=kit,status="dispatching"}
  local writes=M.appendWrite({},a.patientInventory,r)
  writes[#writes+1]={query=[[INSERT INTO lightrp_medical_attempts (id,actor_inventory,patient_inventory,death_token,status,definition)
   VALUES (CASE WHEN ROW_COUNT()=1 THEN ? ELSE NULL END,?,?,?,'dispatching',?)]],values={receipt.id,inv.id,a.patientInventory,a.deathToken,json.encode(receipt)}}
  M.internal[inv.id]=true
  local invoked,ok,error=pcall(Inv.commitDrafts,{{inv,draft}},writes,function()applyRecord(a.patientInventory,r);s.record=r end)
  M.internal[inv.id]=nil
  if not invoked or not ok then return false,error or "Medical escrow failed."end
  a.id,a.actorInventory,a.kit,a.status=receipt.id,receipt.actorInventory,kit,"dispatching";a.escrowedAt=now();M.attempts[a.id]=a
  return true
 end)
 if not called or not saved then a.phase="playing";releaseTreatment(a,"Treatment could not be recorded. Your kit was kept.");return end
 stopPlayback(a);a.phase="dispatching";M.push(a.actor)
 -- Inventory and receipt are committed. Revalidate identity after the SQL yield.
 if character(a.actor)~=a.character or inventory(a.actor)~=a.inventory then failAttempt(a,"The helper disconnected before revival was dispatched.");return end
 dispatch(a)
end
local function startPlayback(player,p)
 local a=M.treatments[player]
 if not a or a.phase~="preparing"or p.token~=a.token then return end
 if now()>a.expires or not treatmentValid(a)then releaseTreatment(a,"Treatment could not start. Your kit was kept.");return end
 local playback,why=Open77.animations.play(player,C.animation.profile,{clip=C.animation.clip,loop=true,durationMs=C.treatmentMs+C.handoffMs+3000})
 if not playback then releaseTreatment(a,"Treatment animation is unavailable. Your kit was kept.");return end
 a.playbackId=playback.playbackId;a.phase="playing";a.startedAt=now()+C.handoffMs
 a.expires=a.startedAt+C.treatmentMs+3000
 TriggerClientEvent(NET,player,{kind="treatment",phase="play",token=a.token,durationMs=C.treatmentMs,delayMs=C.handoffMs,patient=a.patientName})
 M.push(a.patient)
end
local function hospital(player)
 local s=subject(player);local r=s and s.record;local pl=life(player)
 if not r or s.patientTreatment or not pl or pl.phase~="dead"or not M.view(player).canGiveUp then return false,"Wait until your current treatment has finished and hospital transfer is unlocked."end
 if unix()<r.since+C.giveUpDelayMs/1000 then return false,"You must wait before giving up."end
 local nextRecord=M.clone(r);nextRecord.status="hospital";nextRecord.revision=r.revision+1
 local writes=M.appendWrite({},s.inventory.id,nextRecord)
 if r.attempt then writes[#writes+1]={query="UPDATE lightrp_medical_attempts SET status='superseded' WHERE id=? AND status='dispatching'",values={r.attempt}}end
 local ok=Db.transaction(writes)
 if not ok then return false,"Hospital transfer could not be recorded."end
 if subject(player)~=s then return false,"Character changed."end
 s.record=nextRecord;applyRecord(s.inventory.id,nextRecord);M.restoring[player]="hospital"
 local point=LightRpConfig.spawn.hospital
 local accepted,why=Open77.players.respawn(player,{position=point.position,heading=point.heading or 0,bucket=point.bucket or 0,health=LightRpConfig.spawn.health,graceMs=LightRpConfig.spawn.graceMs})
 if not accepted then
  nextRecord.status=r.status;nextRecord.revision=nextRecord.revision+1
  local rollback=M.appendWrite({},s.inventory.id,nextRecord)
  if r.attempt then rollback[#rollback+1]={query="UPDATE lightrp_medical_attempts SET status='dispatching' WHERE id=? AND status='superseded'",values={r.attempt}}end
  if Db.transaction(rollback)then M.restoring[player]=nil;s.record=nextRecord;M.records[s.inventory.id]=nextRecord end
  return false,"Hospital transfer was refused: "..tostring(why)
 end
 if r.attempt then M.attempts[r.attempt]=nil end
 M.push(player);return true
end
RegisterNetEvent(NET,function(p)
 local player=id(source)
 if not player or type(p)~="table"or type(p.operation)~="string"then return end
 if p.operation=="ready"then startPlayback(player,p);return end
 if p.operation=="cancel"then local a=M.treatments[player];if a and p.token==a.token then M.cancel(player)end;return end
 if p.operation=="state"then M.push(player);return end
 local at=now();if M.lastRequest[player]and at-M.lastRequest[player]<500 then return end;M.lastRequest[player]=at
 if p.operation=="giveup"then local ok,why=hospital(player);if not ok then notify(player,why,"warning")end;M.push(player)end
end)
Inv.onUse(C.kit,function(player)
 local ok,why=M.begin(player)
 if not ok then notify(player,why,"warning");return false end
 return "keep"
end)
-- Protect the one reserved kit during the timed action, without locking the
-- entire inventory. Committing/refund writes use the same inventory mutex.
function M.prepare(changes)
 for _,change in ipairs(changes)do
  local inv,draft=change[1],change[2]
  if not M.internal[inv.id]then
   local reserved=0
   for _,a in pairs(M.treatments)do if a.inventory==inv and(a.phase=="preparing"or a.phase=="playing")then reserved=reserved+1 end end
   if kitCount(draft)<reserved then return false,"A trauma kit is reserved for ongoing treatment."end
  end
 end
 return true
end
local prepare=LightRP.armament and LightRP.armament.prepare
if prepare then LightRP.armament.prepare=function(changes)local ok,why=M.prepare(changes);if not ok then return false,why end;return prepare(changes)end end
function M.onLifeState(player,phase)
 if phase=="dead"then
  M.cancel(player,"Treatment interrupted because someone became incapacitated. Your kit was kept.")
  if M.restoring[player]=="downed"then
   local currentLife=life(player)
   if currentLife and currentLife.weapon=="medical:restore"then
    M.restoring[player]=nil;local s=subject(player);if s then s.needsPlacement=false end
   end
   M.push(player);return
  end
  local l=life(player);if l and not exempt(player,l)then capture(player,l)end
 elseif phase=="recovering"or phase=="alive"then
  local s=subject(player)
  if not s or not s.record then return end
  if s.needsPlacement and not M.restoring[player]then return end
  if M.restoring[player]=="downed"then
   SetTimeout(0,function()
    if subject(player)~=s or not Open77.ready.isReady(player)then return end
    local l=life(player);if l and(l.phase=="alive"or l.phase=="recovering")then
     local ok,why=Open77.players.kill(player,{cause="script",weapon="medical:restore"})
     if not ok then s.error="Restoring unconscious state: "..tostring(why);M.push(player)end
    end
   end)
  elseif s.record.status=="hospital"then
   if M.removeRecord(s.inventory.id,s.record.token)then M.subjects[player]=nil;M.restoring[player]=nil;M.push(player)end
  elseif s.record.status~="reviving"then
   -- An authorized staff/native revive also settles the saved unconscious state.
   if M.removeRecord(s.inventory.id,s.record.token)then M.subjects[player]=nil;M.push(player)end
  end
 end
end
function M.onCharacterLoaded(player)
 M.cancel(player)
 local old=M.treatments[player];if old then M.treatments[player]=nil;stopPlayback(old)end
 M.subjects[player]=nil;M.restoring[player]=nil
 attach(player)
 local inv=inventory(player)
 if inv then
  local ok,rows=Db.read("SELECT definition FROM lightrp_medical_attempts WHERE actor_inventory=? AND status='failed'",{inv.id})
  if ok then for _,row in ipairs(rows)do local decoded,a=pcall(json.decode,row.definition);if decoded and type(a)=="table"then refund(player,a)end end end
 end
end
function M.onDisconnected(player)
 M.cancel(player)
 local old=M.treatments[player];if old then M.treatments[player]=nil;stopPlayback(old)end
 M.subjects[player]=nil;M.restoring[player]=nil;M.lastRequest[player]=nil
end
function M.onUiReady(player)
 local s=subject(player)
 if s and s.needsPlacement and not M.restoring[player]and Open77.ready.isReady(player)and LightRP.spawn and LightRP.spawn.restoreMedical then LightRP.spawn.restoreMedical(player)end
 M.push(player)
end
M.onGameplayReady=M.onUiReady
M.onReady=M.onUiReady
function M.onDatabaseReady()
 for _,player in ipairs(GetPlayers())do local n=id(player);if n then M.onCharacterLoaded(n)end end
 LightRP.log("medical ready: persistent unconscious state, %ds give-up lock, trauma kit assistance",C.giveUpDelayMs/1000)
end
LightRP.module("medical",M)
AddEventHandler("open77:playerDamaged",function(victim,_,amount)if(tonumber(amount)or 0)>0 then local player=id(victim);if player then M.cancel(player,"Treatment interrupted by damage. Your kit was kept.")end end end)
local damageHandle=Open77.combat.onDamage(function(event)if type(event)=="table"and id(event.attacker)and M.isDowned(id(event.attacker))then return false end end)
AddEventHandler("onResourceStop",function(name)
 if name~=GetCurrentResourceName()then return end
 for _,a in pairs(M.treatments)do if a.phase=="preparing"or a.phase=="playing"then releaseTreatment(a)end end
 if damageHandle then Open77.combat.offDamage(damageHandle)end
end)
CreateThread(function()
 while true do
  Wait(250)
  for actor,a in pairs(M.treatments)do
   if a.phase=="preparing"then if now()>a.expires or not treatmentValid(a)then releaseTreatment(a,"Treatment interrupted. Your kit was kept.")end
   elseif a.phase=="playing"then
    if not treatmentValid(a)then releaseTreatment(a,"Treatment interrupted. Your kit was kept.")
    elseif now()>=a.startedAt+C.treatmentMs then commitTreatment(a)end
   end
  end
  for attemptId,a in pairs(M.attempts)do
   if a.phase=="resume"then
    local s=currentPatient(a);local l=life(a.patient)
    if not a.recovered and(not s or(a.escrowedAt and now()-a.escrowedAt>C.confirmationTimeoutMs))then failAttempt(a,"The patient was unavailable before revival was dispatched.")
    elseif s and not M.restoring[a.patient]and l and l.phase=="dead"then dispatch(a)end
   elseif a.phase=="awaiting"or a.phase=="finalize_pending"or a.phase=="uncertain"then
    local s=currentPatient(a);local l=life(a.patient)
    if s and l and(l.phase=="alive"or l.phase=="recovering")then confirmAttempt(a)
    elseif s and a.phase~="uncertain"and a.dispatchedAt and now()-a.dispatchedAt>C.confirmationTimeoutMs then
     a.phase="uncertain";s.error="Recovery is awaiting confirmation. Reconnect if your body remains unresponsive.";M.push(a.patient)
     if a.actor then notify(a.actor,"Recovery has not been confirmed. The reserved kit will not be charged twice.","warning")end
    end
   elseif a.phase=="failure_pending"then failAttempt(a,a.failure)
   elseif a.phase=="refund_pending"then
    for _,player in ipairs(GetPlayers())do local n=id(player);local inv=inventory(n);if inv and inv.id==a.actorInventory and refund(n,a)then M.attempts[attemptId]=nil;break end end
   end
  end
  for player,s in pairs(M.subjects)do
   if subject(player)==s then
    if not s.record then local l=life(player);if l and l.phase=="dead"and not exempt(player,l)then M.subjects[player]=nil;capture(player,l)end end
    if s.needsPlacement and not M.restoring[player]and Open77.ready.isReady(player)and LightRP.spawn and LightRP.spawn.restoreMedical then LightRP.spawn.restoreMedical(player)end
    M.push(player)
   end
  end
 end
end)
