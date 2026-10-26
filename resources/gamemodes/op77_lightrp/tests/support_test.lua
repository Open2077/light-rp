-- Real modules + real MySQL transactions, via tools/test-support.py.
GetUnixTime=os.time
os=nil -- The real resource sandbox exposes its clock, not Lua's os library.
local people={}
for id=1,5 do people[id]={identifier="test-account-"..id,key="default",status="active",firstName="Citizen",lastName=tostring(id)} end
local acl={ [3]={all=true},[4]={reports=true,view=true},[5]={view=true} }
local now,sequence=100000,0
local events,commands,providers,schemas={},{},{},{}
LightRP={characters={},staff={},db={ready=true},jobs={},money={},admin=nil}
LightRP.db.schema=function(sql) assert(sql_run(sql));schemas[#schemas+1]=sql end
LightRP.db.run=sql_run;LightRP.db.read=sql_read;LightRP.db.transaction=sql_transaction
LightRP.module=function(name,t)LightRP[name]=t;return t end
LightRP.nowMs=function() return now end
LightRP.log=function(...) end
LightRP.command=function(name,opts,fn) commands[name]=fn end
LightRP.stateProvider=function(name,fn) providers[name]=fn end
LightRP.characters.get=function(id)return people[id] end
LightRP.characters.displayName=function(id)return "Citizen "..id end
LightRP.characters.adminRename=function(id,first,last)people[id].firstName=first;people[id].lastName=last;return true end
GetPlayers=function()local t={};for id in pairs(people) do t[#t+1]=id end;return t end
GetPlayerName=function(id)return people[id] and "Account "..id end
LightRP.staff.allowed=function(id,permission)
 local a=acl[id];if not a then return false end;if a.all then return true end
 for key,value in pairs(LightRpSupportConfig.permissions) do if value==permission then return a[key]==true end end
 return false
end
LightRP.notice=function(id,value)events[#events+1]={player=id,value=value} end
LightRP.chat={system=function()end};LightRP.staff.announce=function()return true end
LightRP.staff.heal=function(id) people[id].healed=(people[id].healed or 0)+1;return true end
LightRP.staff.moveTo=function(id,p,h,cb)cb(true) end
LightRP.buildState=function()return {needs={food=95,drink=80}} end
LightRP.jobs.get=function()return {name="unemployed",label="Unemployed",grade=0,gradeLabel="Citizen"} end
LightRP.jobs.gang=function()return {name="none",label="None",grade=0,gradeLabel="None"} end
LightRP.jobs.setJob=function()return true end;LightRP.jobs.setGang=LightRP.jobs.setJob
LightRP.money.get=function()return {cash=12,bank=1500,number="111-222"}end
LightRP.money.addBank=function(id,n)people[id].credit=(people[id].credit or 0)+n;return true end
Open77={players={position=function()return {x=1,y=2,z=3,bucket=0} end,getLifeState=function()return {phase="alive"} end}}
RegisterNetEvent=function()end
TriggerClientEvent=function(name,id,p)events[#events+1]={event=name,player=id,payload=p};return true end
exports=function()end;GetInvokingResource=function()return "open77_admin" end
Wait=function()end
dofile("shared/events.lua");dofile("shared/jobs.lua");dofile("server/config/support.lua")
assert(sql_run([[CREATE TABLE lightrp_reports (id BIGINT PRIMARY KEY,identifier VARCHAR(64),reporter VARCHAR(96),message VARCHAR(512),created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,handled TINYINT)]]))
assert(sql_run([[INSERT INTO lightrp_reports VALUES (1,'test-account-1','Old citizen','An older report that must remain available',CURRENT_TIMESTAMP,1)]]))
dofile("server/modules/support.lua");dofile("server/modules/admin.lua")
local S=LightRP.support
S.onDatabaseReady();S.onDatabaseReady()
local old=assert(S.list(1,{scope="player",filter="all"}));assert(#old.tickets==1 and old.tickets[1].status=="resolved","legacy reports migrate exactly once")
local function intent()sequence=sequence+1;return "test-request:"..sequence end
local create={subject="Cannot leave the lift",body="I entered the elevator and I am now stuck near the door.",category="bug",mutation=intent()}
local case=assert(S.create(1,create));local id=case.ticketId
assert(S.create(1,create).ticketId==id,"retry creates no second ticket")
assert(not S.create(1,{subject="Another issue",body="Details that are long enough.",category="help",mutation=intent()}),"create cooldown")
assert(not S.detail(2,{ticket=id,scope="player"}),"another account cannot read a ticket")
assert(not S.detail(2,{ticket=id,scope="staff"}),"forged staff scope cannot read")
assert(not S.list(5,{scope="staff"}),"opening admin is not a reports grant")
local function detail(who,staff) return assert(S.detail(who,{ticket=id,scope=staff and "staff" or "player"})) end
local function mutate(who,action,body,extra)
 local staff=who==3 or who==4;local d=detail(who,staff)
 local p={ticket=id,scope=staff and "staff" or "player",revision=d.ticket.revision,mutation=intent(),action=action,body=body}
 for k,v in pairs(extra or {})do p[k]=v end
 return S.mutate(who,p),p
end
local initial=detail(3,true).ticket.revision
assert(mutate(3,"claim"));assert(detail(1).ticket.assignee=="Account 3")
assert(not S.mutate(4,{ticket=id,scope="staff",revision=initial,mutation=intent(),action="claim"}),"stale competing claim rejected")
assert(not mutate(4,"claim"),"another admin cannot steal a claimed ticket")
assert(not mutate(4,"resolve","Not my assigned case"),"only assignee or supervisor resolves")
assert(mutate(3,"note","This is a private staff-only note."))
local private=detail(3,true);local public=detail(1)
assert(#private.messages==#public.messages+1 and not public.ticket.owner and not public.ticket.position,"no internal timeline or identity/location leak")
for _,m in ipairs(public.messages)do assert(not m.internal and not m.body:find("private staff")) end
assert(not mutate(1,"note","forged internal note"),"player cannot write staff note")
local waiting=assert(mutate(3,"waiting","Which floor were you on?"));assert(detail(1).ticket.status=="waiting_player")
local reply,p=mutate(1,"reply","Floor two, the controls do not respond.")
assert(reply and detail(3,true).ticket.status=="in_progress")
local count=#detail(3,true).messages
assert(S.mutate(1,p));assert(#detail(3,true).messages==count,"reply retry is idempotent")
local realTransaction=LightRP.db.transaction
LightRP.db.transaction=function() return false end
local revision=detail(3,true).ticket.revision
assert(not mutate(3,"resolve","A resolution that should fail to commit."))
assert(detail(3,true).ticket.revision==revision,"failed write does not advance status")
LightRP.db.transaction=realTransaction
assert(mutate(3,"assign",nil,{assignee=4}));assert(detail(1).ticket.assignee=="Account 4")
assert(mutate(4,"resolve","Moved safely outside the elevator. Please retry now."));assert(detail(1).ticket.status=="resolved")
assert(not mutate(1,"reply","Reply on a closed case"))
assert(mutate(1,"reopen","The same issue occurred again after entering the lift."));assert(detail(1).ticket.status=="open")
assert(mutate(1,"close","I found a way out, thank you."));assert(detail(1).ticket.status=="closed")
assert(S.read(1,{ticket=id,revision=detail(1).ticket.revision,scope="player"}))
local own=S.list(1,{scope="player",filter="all"});for _,t in ipairs(own.tickets)do if t.id==id then assert(not t.unread)end end
assert(not S.read(1,{ticket=id,revision=99999,scope="player"}),"cannot acknowledge future messages")
assert(mutate(3,"reopen","Investigate the repeat incident."))
people[1]=nil;S.onDisconnected(1)
assert(mutate(3,"reply","We can continue when you reconnect."));assert(not detail(3,true).ticket.reporterOnline)
people[1]={identifier="test-account-1",key="second-character",status="active"}
assert(detail(1).messages[#detail(1).messages].body=="We can continue when you reconnect.","account owns history across reconnect and character slots")
-- Reload the module to prove persistence, not just in-memory state.
dofile("server/modules/support.lua");S=LightRP.support;assert(detail(1).ticket.id==id and detail(1).ticket.status=="open")
for i=1,55 do assert(mutate(3,"note","History pagination note number "..i)) end
local recent=detail(3,true);assert(#recent.messages==50 and recent.hasOlder)
local older=assert(S.detail(3,{ticket=id,scope="staff",before=recent.messages[1].id}));assert(#older.messages>0 and older.messages[#older.messages].id<recent.messages[1].id)
assert(#detail(1).messages<20,"private pagination never exposes notes")
local A=LightRP.admin
-- Revocation while a yielding database query is running must suppress the response.
local realRead=LightRP.db.read
LightRP.db.read=function(sql,values)
 local ok,result=realRead(sql,values)
 if sql:find("SUM(status='open')",1,true) then acl[4].reports=false end
 return ok,result
end
assert(not S.list(4,{scope="staff"}),"revoked reports ACL cannot leak a list after summary query")
LightRP.db.read=realRead;acl[4].reports=true

-- Active quota applies to creates AND reopened cases, across character slots.
for i=1,2 do now=now+60001;assert(S.create(1,{subject="Quota case "..i,body="Another issue with sufficient context.",category="help",mutation=intent()})) end
now=now+60001
assert(not S.create(1,{subject="Fourth active case",body="This case exceeds the allowed active quota.",category="help",mutation=intent()}),"active report quota")
local legacy=assert(S.detail(1,{scope="player",ticket=old.tickets[1].id}))
assert(not S.mutate(1,{ticket=legacy.ticket.id,scope="player",revision=legacy.ticket.revision,action="reopen",body="Attempting to reopen a fourth case.",mutation=intent()}),"reopen uses the same quota")

-- Two player sessions on one account share a lock even while SQL yields.
local payload={subject="Concurrent support",body="An account with two sessions opening support.",category="help",mutation=intent()}
local held=false
LightRP.db.read=function(sql,values)
 if not held then held=true;coroutine.yield() end
 return realRead(sql,values)
end
local opening=coroutine.create(function()assert(S.create(2,payload))end)
assert(coroutine.resume(opening));assert(coroutine.status(opening)=="suspended")
local otherAccount=people[5].identifier;people[5].identifier=people[2].identifier
local second,why=S.create(5,payload);assert(not second and why:find("being saved",1,true))
people[5].identifier=otherAccount;LightRP.db.read=realRead
assert(coroutine.resume(opening));assert(coroutine.status(opening)=="dead")
assert(S.create(2,payload),"lock released and retry finds the saved case")
LightRP.db.read=function()error("simulated storage exception")end
assert(not pcall(function()S.create(5,payload)end))
LightRP.db.read=realRead
assert(S.create(5,payload),"storage exception releases the owner lock")
assert(not A.overview(1),"player cannot read admin roster")
assert(#A.overview(3).players==5)
assert(not A.player(3,{target=1,account="someone-else",character="default"}),"recycled player ID/character rejected")
local action={target=1,account="test-account-1",character="second-character",action="credit",wallet="bank",amount=25,reason="Compensation after test incident",confirmed=true,mutation=intent()}
assert(not A.action(1,action));assert(not A.action(4,action),"report handler cannot grant money")
assert(A.action(3,action).accepted and people[1].credit==25)
assert(A.action(3,action).accepted and people[1].credit==25,"money retry does not duplicate grant")
action.mutation=intent();action.amount=-1;assert(not A.action(3,action).accepted and people[1].credit==25)
assert(#A.audit(3,{}).entries>=2 and not A.audit(4,{}),"durable audit is permission-gated")
Open77.players.kick=function(target,reason)
 assert(target==2 and #reason<=127 and utf8.len(reason) and not reason:find("[%c]"),"kick reason respects the native UTF-8 byte limit")
 return true
end
assert(A.action(3,{target=2,account="test-account-2",character="default",action="kick",reason=string.rep("é",130).."\nContext",confirmed=true,mutation=intent()}).accepted)
local raw=assert(sql_read("SELECT COUNT(*) AS n FROM lightrp_support_messages"))
print("PASS: real MySQL migration/reload, ownership, live ACL revocation, notes privacy, stale claims, assignment, offline replies, receipts, lifecycle, rollback, quotas across concurrent sessions, pagination, RP roster, durable audit and idempotent money")
