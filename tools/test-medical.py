"""Actual inventory + medical + Spawn code with deterministic SQL/life boundaries."""
from pathlib import Path
import runpy
ns=runpy.run_path(str(Path(__file__).with_name('test-armament.py')))
lua=ns['lua']
lua.execute('''
dofile("shared/medical.lua")
local noop=function()end
characters={ [1]={identifier="test",key="default",status="active"},[2]={identifier="patient",key="default",status="active"},[3]={identifier="helper",key="default",status="active"} }
LightRP.characters.get=function(p)return characters[tonumber(p)]end
LightRP.characters.displayName=function(p)return "Player "..p end
LightRP.characters.isRegistered=function(p)return characters[p]and characters[p].status=="active"end
LightRP.chat={system=noop};LightRP.tutorial=nil;LightRP.housing=nil
GetPlayers=function()return{1,2,3}end
local db=LightRP.db;local oldRead,oldTransaction,oldRun=db.read,db.transaction,db.run
medicalRows={};medicalReceipts={};inventoryRows={}
local function copy(v)return W.clone(v)end
local function rememberInventory(q,v,rows)
 if q:find("INSERT INTO lightrp_inventories",1,true)then rows[v[1]]={items=v[6],slots=v[4],max_weight=v[5]}end
end
inventoryRows[inv.id]={items=json.encode(inv.items),slots=inv.slots,max_weight=inv.maxWeight}
function db.read(q,v)
 if q:find("FROM lightrp_medical_deaths",1,true)then local r=medicalRows[v[1]];return true,r and{copy(r)}or{}end
 if q:find("FROM lightrp_medical_attempts WHERE actor_inventory",1,true)then
  local out={};for _,r in pairs(medicalReceipts)do if r.actor_inventory==v[1]and r.status=="failed"then out[#out+1]={definition=r.definition}end end;return true,out
 end
 if q:find("FROM lightrp_medical_attempts WHERE id",1,true)then local r=medicalReceipts[v[1]];return true,r and{{status=r.status,definition=r.definition}}or{}end
 if q:find("FROM lightrp_inventories WHERE id",1,true)then local r=inventoryRows[v[1]];return true,r and{copy(r)}or{}end
 return oldRead(q,v)
end
function db.run(q,v)
 if failSql then return false,"database_error"end
 rememberInventory(q,v,inventoryRows);return oldRun(q,v)
end
function db.transaction(queries)
 local escrow=false
 for _,q in ipairs(queries)do if q.query:find("INSERT INTO lightrp_medical_attempts",1,true)and q.query:find("'dispatching'",1,true)then escrow=true end end
 if escrow and staleMedicalCas then
  staleMedicalCas=false
  for _,r in pairs(medicalRows)do local decoded=json.decode(r.definition);r.revision=r.revision+1;decoded.revision=r.revision;r.definition=json.encode(decoded)end
 end
 local deaths,receipts,inventories=copy(medicalRows),copy(medicalReceipts),copy(inventoryRows)
 local affected=0
 for _,q in ipairs(queries)do
  local s,v=q.query,q.values
  if s:find("INSERT INTO lightrp_medical_deaths",1,true)then
   if deaths[v[1]]then return false,"duplicate"end
   deaths[v[1]]={token=v[2],revision=v[3],status=v[4],definition=v[5]};affected=1
  elseif s:find("UPDATE lightrp_medical_deaths",1,true)then
   local r=deaths[v[4]];affected=r and r.token==v[5]and r.revision==v[6]and 1 or 0
   if affected==1 then r.revision,r.status,r.definition=v[1],v[2],v[3]end
  elseif s:find("INSERT INTO lightrp_medical_attempts",1,true)then
   if affected~=1 or receipts[v[1]]then return false,"receipt_conflict"end
   receipts[v[1]]={actor_inventory=v[2],patient_inventory=v[3],death_token=v[4],status=s:find("'guard'",1,true)and"guard"or"dispatching",definition=v[5]};affected=1
  elseif s:find("UPDATE lightrp_medical_attempts",1,true)then
   local status=s:match("SET status='([^']+)'");local expected=s:match("AND status='([^']+)'")
   local r=receipts[v[1]];affected=r and(not expected or r.status==expected)and 1 or 0
   if affected==1 then r.status=status end
  elseif s:find("DELETE FROM lightrp_medical_deaths",1,true)then
   local r=deaths[v[1]];if r and r.token==v[2]then deaths[v[1]]=nil;affected=1 else affected=0 end
  end
  rememberInventory(s,v,inventories)
 end
 local ok,why=oldTransaction(queries);if not ok then return false,why end
 medicalRows,medicalReceipts,inventoryRows=deaths,receipts,inventories
 if escrow and afterMedicalEscrow then local callback=afterMedicalEscrow;afterMedicalEscrow=nil;callback()end
 return true
end
positions={ [1]={x=0,y=0,z=0,bucket=0},[2]={x=1,y=0,z=0,bucket=0},[3]={x=1.5,y=0,z=0,bucket=0} }
lives={};for p=1,3 do lives[p]={phase="alive",cause="unknown",revision=1,bucket=0,position=positions[p]}end
ready=true;seated=false;animation={};animationSequence=0;reviveCalls=0;respawnCalls=0;nativeReject=false;nativeHang=false;disconnectBeforeReject=false
Open77.time.unix=function()return 1700000000+clock/1000 end
Open77.ready={isReady=function()return ready end}
Open77.players.getLifeState=function(p)return lives[tonumber(p)]end
Open77.players.get=function(p)local point=positions[p];return point and{position={x=point.x,y=point.y,z=point.z},bucket=point.bucket,ageMs=point.stale and 5000 or 0,ready=ready}end
Open77.players.position=function(p)return positions[p]end
Open77.vehicles.getPlayerSeat=function()return seated and{vehicleId=5}or nil end
Open77.animations={current=function(p)return animation[p]end,
 play=function(p,profile,options)assert(profile=="examine");animationSequence=animationSequence+1;animation[p]={active=true,playbackId="medical:"..animationSequence};return animation[p]end,
 stop=function(p,playback)if animation[p]and animation[p].playbackId==playback then animation[p]=nil end;return true end}
function SetTimeout(ms,fn)CreateThread(function()Wait(ms);fn()end)end
function emitLife(p,phase)
 local l=lives[p];l.phase=phase;l.revision=l.revision+1;l.position=positions[p];l.bucket=positions[p].bucket
 if hooks.medical then hooks.medical.onLifeState(p,phase)end
 if hooks.spawn then hooks.spawn.onLifeState(p,phase)end
end
Open77.players.kill=function(p,options)lives[p].cause=options.cause;lives[p].weapon=options.weapon;emitLife(p,"dead");return true end
Open77.players.respawn=function(p,options)
 respawnCalls=respawnCalls+1;positions[p]={x=options.position.x,y=options.position.y,z=options.position.z,bucket=options.bucket or 0}
 emitLife(p,"respawnpending");local revision=lives[p].revision
 SetTimeout(50,function()if lives[p].phase~="respawnpending"or lives[p].revision~=revision then return end;emitLife(p,"recovering");local r=lives[p].revision;SetTimeout(100,function()if lives[p].phase=="recovering"and lives[p].revision==r then emitLife(p,"alive")end end)end)
 return true
end
Open77.players.revive=function(p,options)
 reviveCalls=reviveCalls+1;assert(options.health==.35 and options.graceMs==5000)
 if disconnectBeforeReject then hooks.medical.onDisconnected(1);Inv.onDisconnected(1);return false,"invalid_argument"end
 if nativeReject then return false,"invalid_argument"end
 emitLife(p,"revivepending");local revision=lives[p].revision
 if not nativeHang then SetTimeout(75,function()if lives[p].phase=="revivepending"and lives[p].revision==revision then emitLife(p,"recovering");local r=lives[p].revision;SetTimeout(100,function()if lives[p].phase=="recovering"and lives[p].revision==r then emitLife(p,"alive")end end)end end)end
 return true
end
Inv.onCharacterLoaded(2,characters[2]);Inv.onCharacterLoaded(3,characters[3])
dofile("server/modules/medical_store.lua");dofile("server/modules/medical.lua");dofile("server/main.lua")
M=LightRP.medical;hooks.medical.onDatabaseReady();tick(300)
function down(p,cause,weapon)
 lives[p].cause=cause or"firearm";lives[p].weapon=weapon or"test:weapon";emitLife(p,"dead");tick(50)
 assert(M.isDowned(p)and medicalRows[Inv.player(p).id])
end
function medicalRequest(player,p)source=player;net["op77_lightrp:medical"](p)end
function begin(player)
 local slot;for k,item in pairs(Inv.player(player).items)do if item.name=="trauma_kit"then slot=k;break end end
 assert(slot and Inv.use(player,slot));local a=M.treatments[player];assert(a)
 medicalRequest(player,{operation="ready",token=a.token});return a
end
assert(Inv.addItem(inv.id,"trauma_kit",3));assert(Inv.addItem(Inv.player(3).id,"trauma_kit",1))
-- Real deaths stay on the ground rather than taking the old ten-second respawn.
down(2,"script","lightrp:needs");local since=M.subjects[2].record.since;local originalRespawns=respawnCalls
medicalRequest(2,{operation="giveup"});tick(11000)
assert(respawnCalls==originalRespawns and lives[2].phase=="dead"and not M.view(2).canGiveUp)
-- Infrastructure script deaths remain excluded; stale/out-of-bucket/seated helpers are refused.
lives[3].cause="script";lives[3].weapon="lightrp:join_spawn";emitLife(3,"dead");assert(not M.isDowned(3));emitLife(3,"alive")
positions[1].stale=true;assert(not M.begin(1));positions[1].stale=nil
positions[1].bucket=8;assert(not M.begin(1));positions[1].bucket=0
seated=true;assert(not M.begin(1));seated=false
-- Completed stationary assistance applies one revive and escrows exactly one kit.
local a=begin(1);assert(not M.begin(3),"one helper owns the patient")
local countBefore=Inv.count(inv.id,"trauma_kit");assert(not Inv.removeItem(inv.id,"trauma_kit",countBefore),"reserved kit cannot be transferred away")
tick(10000)
assert(lives[2].phase=="alive"and not M.isDowned(2)and Inv.count(inv.id,"trauma_kit")==countBefore-1 and reviveCalls==1)
assert(not medicalRows[Inv.player(2).id]and medicalReceipts[a.token].status=="complete")
-- Movement or damaged treatment does not consume a kit.
down(2);a=begin(1);countBefore=Inv.count(inv.id,"trauma_kit");positions[1].x=4;tick(500)
assert(not M.treatments[1]and Inv.count(inv.id,"trauma_kit")==countBefore and reviveCalls==1);positions[1].x=0
a=begin(1);for _,fn in ipairs(events["open77:playerDamaged"])do fn(1,0,5)end;tick(300)
assert(not M.treatments[1]and Inv.count(inv.id,"trauma_kit")==countBefore)
a=begin(1);seated=true;tick(300);seated=false
assert(not M.treatments[1]and Inv.count(inv.id,"trauma_kit")==countBefore)
-- Definitive native refusal refunds the escrow once.
nativeReject=true;a=begin(1);tick(10000)
assert(Inv.count(inv.id,"trauma_kit")==countBefore and medicalReceipts[a.token].status=="refunded"and M.view(2).phase=="downed")
nativeReject=false
-- Failed escrow SQL keeps both kit and native life unchanged.
failSql=true;local beforeCalls=reviveCalls;a=begin(1);tick(10000);failSql=false
assert(Inv.count(inv.id,"trauma_kit")==countBefore and reviveCalls==beforeCalls and not medicalReceipts[a.token])
-- A concurrent medical revision causes the CAS guard to abort the whole escrow.
staleMedicalCas=true;a=begin(1);tick(10000)
assert(Inv.count(inv.id,"trauma_kit")==countBefore and reviveCalls==beforeCalls and not medicalReceipts[a.token])
M.records={};hooks.medical.onCharacterLoaded(2);hooks.medical.onUiReady(2);tick(700)
-- Actor movement/bucket change during escrow SQL is rechecked before native dispatch.
afterMedicalEscrow=function()positions[1].x=10;positions[1].bucket=5 end
a=begin(1);tick(10000)
assert(Inv.count(inv.id,"trauma_kit")==countBefore and reviveCalls==beforeCalls and medicalReceipts[a.token].status=="refunded")
positions[1].x=0;positions[1].bucket=0
-- Readiness dropping during escrow waits safely, then retries or refunds on movement.
afterMedicalEscrow=function()ready=false end
a=begin(1);tick(10000)
assert(M.attempts[a.token].phase=="resume"and reviveCalls==beforeCalls)
positions[1].x=10;ready=true;tick(700)
assert(Inv.count(inv.id,"trauma_kit")==countBefore and medicalReceipts[a.token].status=="refunded"and reviveCalls==beforeCalls)
positions[1].x=0
-- Reconnect keeps the original clock and restores the corpse through Spawn.
local patientInv=Inv.player(2).id;since=M.subjects[2].record.since
hooks.medical.onDisconnected(2);Inv.onDisconnected(2);M.records={}
lives[2].phase="alive";Inv.onCharacterLoaded(2,characters[2]);hooks.medical.onCharacterLoaded(2)
emitLife(2,"alive");assert(M.isDowned(2),"initial alive does not clear saved injury")
hooks.medical.onUiReady(2);tick(1200)
assert(M.isDowned(2)and lives[2].phase=="dead"and M.subjects[2].record.since==since)
local spawned=respawnCalls;hooks.spawn.onGameplayReady(2);tick(300);assert(respawnCalls==spawned,"no second join spawn heals the corpse")
-- Expiry unlocks deliberate hospital transfer, not automatic abandonment.
tick(95000);assert(M.view(2).canGiveUp and lives[2].phase=="dead")
medicalRequest(2,{operation="giveup"});tick(800)
assert(not M.isDowned(2)and lives[2].phase=="alive"and not medicalRows[patientInv])
assert(math.abs(positions[2].x-LightRpConfig.spawn.hospital.position.x)<.01)
-- Native rejection after helper disconnect queues an idempotent recovery refund.
positions[2]={x=1,y=0,z=0,bucket=0};down(2);a=begin(1);countBefore=Inv.count(inv.id,"trauma_kit")
disconnectBeforeReject=true;tick(10000);disconnectBeforeReject=false
assert(not Inv.player(1)and medicalReceipts[a.token].status=="failed")
Inv.onCharacterLoaded(1,characters[1]);inv=Inv.player(1);hooks.medical.onCharacterLoaded(1)
assert(Inv.count(inv.id,"trauma_kit")==countBefore and medicalReceipts[a.token].status=="refunded")
hooks.medical.onCharacterLoaded(1);assert(Inv.count(inv.id,"trauma_kit")==countBefore,"refund cannot replay")
-- Patient departure during the escrow SQL yield does not strand dispatching.
positions[2]={x=1,y=0,z=0,bucket=0};countBefore=Inv.count(inv.id,"trauma_kit");beforeCalls=reviveCalls
local oldSince=M.subjects[2].record.since
afterMedicalEscrow=function()hooks.medical.onDisconnected(2);Inv.onDisconnected(2)end
a=begin(1);tick(10000)
assert(reviveCalls==beforeCalls and Inv.count(inv.id,"trauma_kit")==countBefore)
assert(medicalReceipts[a.token].status=="refunded"and medicalRows[patientInv].status=="downed")
Inv.onCharacterLoaded(2,characters[2]);hooks.medical.onCharacterLoaded(2);hooks.medical.onUiReady(2);tick(800)
assert(M.subjects[2].record.since==oldSince and lives[2].phase=="dead")
-- An uncertain native result retains escrow, refuses free retries, and accepts a late canonical confirmation.
nativeHang=true;a=begin(1);countBefore=Inv.count(inv.id,"trauma_kit");tick(10000);tick(22000)
assert(Inv.count(inv.id,"trauma_kit")==countBefore-1 and M.attempts[a.token].phase=="uncertain")
assert(not M.begin(3)and medicalReceipts[a.token].status=="dispatching")
emitLife(2,"recovering");tick(400);emitLife(2,"alive");nativeHang=false
assert(not M.isDowned(2)and medicalReceipts[a.token].status=="complete")
-- If the native returns to dead after an uncertain request, the patient may eventually abandon without minting a kit refund.
positions[2]={x=1,y=0,z=0,bucket=0};down(2);nativeHang=true;a=begin(1);countBefore=Inv.count(inv.id,"trauma_kit");tick(33000)
emitLife(2,"dead");tick(95000);assert(M.view(2).canGiveUp)
medicalRequest(2,{operation="giveup"});tick(800);nativeHang=false
assert(not M.isDowned(2)and medicalReceipts[a.token].status=="superseded"and Inv.count(inv.id,"trauma_kit")==countBefore-1)
print("PASS: real-death hold, 90s lock, kit reservation/escrow, timed revive, movement cancellation, definitive refusal/refund, saved-death reconnect, hospital transfer, offline refund idempotency")
''')
