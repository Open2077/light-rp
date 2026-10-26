-- Real SQL, inventory, economy, housing, authoring and interaction modules.
-- Native movement is a controllable promise: assert isolation and rollback
-- separately from in-game streaming. Runner: tools/test-housing.py.
dofile("shared/config.lua");dofile("shared/items.lua");dofile("shared/events.lua")
local noop=function()end
local time,sequence=1800000000,0
local chars,positions,threads,events,commands={},{},{},{},{}
local admin=3
for id=1,3 do
    chars[id]={identifier="housing-test-"..id,key="default",status="active"}
    positions[id]={x=10,y=20,z=30,yaw=90,bucket=0}
end
json={encode=function(v)return json_encode(v)end,decode=function(v)return json_decode(v)end}
GetUnixTime=function()return time+0.503 end -- host clock includes fractional seconds
GetPlayers=function()local t={};for id in pairs(chars)do t[#t+1]=id end;return t end
GetPlayerName=function(id)return chars[id] and "Citizen "..id end
GetPlayerIdentifier=function(id)return chars[id] and chars[id].identifier end
GetPlayerRoutingBucket=function(id)return positions[id].bucket end
GetPlayersInBucket=function(bucket)local t={};for id,p in pairs(positions) do if chars[id] and p.bucket==bucket then t[#t+1]=id end end;return t end
SetPlayerRoutingBucket=function(id,bucket)positions[id].bucket=bucket end
GetCurrentResourceName=function()return "op77_lightrp" end
CreateThread=function(fn)threads[#threads+1]=coroutine.create(fn)end
Wait=function()coroutine.yield("wait")end
RegisterNetEvent=noop;AddEventHandler=function(name,fn)events[name]=fn end
TriggerClientEvent=noop
local Db={ready=true,schema=function(q)assert(sql_run(q))end,run=sql_run,read=sql_read,transaction=sql_transaction}
Db.query=function(q,v)local ok,rows=Db.read(q,v);return ok and rows or {} end
Db.single=function(q,v)return Db.query(q,v)[1]end
LightRP={db=Db,characters={get=function(id)return chars[id]end,displayName=function(id)return "Citizen "..id end,switching={}},staff={allowed=function(id)return id==admin end},admin={handlers={}},
    module=function(n,t)LightRP[n]=t;return t end,action=noop,command=function(n,_,fn)commands[n]=fn end,
    log=function(fmt,...)print(string.format(fmt,...))end,state=noop,stateProvider=noop,eachModule=noop,notice=noop,result=noop,nowMs=function()return time*1000 end}
local travelFailure,holdTravel=false,false
Open77={players={position=function(id)return positions[id]end,positions=function()return positions end,getLifeState=function()return {phase="alive"}end},vehicles={getPlayerSeat=function()return nil end}}
Open77.players.teleport=function(id,point,opts)
    local old=positions[id].bucket;positions[id].bucket=opts.bucket
    return {await=function()
        if holdTravel then coroutine.yield("travel") end
        if travelFailure then positions[id].bucket=old;return nil,"stream_timeout" end
        positions[id]={x=point.x,y=point.y,z=point.z,yaw=opts.heading,bucket=opts.bucket}
        return {success=true}
    end}
end
local function step(co)local ok,why=coroutine.resume(co);assert(ok,why);return why end
local function lastTravel()local co=threads[#threads];step(co);return co end
dofile("server/core/interact.lua")
dofile("server/modules/inventory.lua");dofile("server/modules/economy.lua")
local Inv,Money=LightRP.inventory,LightRP.money
for id,c in pairs(chars)do Inv.onCharacterLoaded(id,c);Money.onCharacterLoaded(id,c);assert(Money.addBank(id,200000,"test","Housing test"))end
Db.schema([[CREATE TABLE lightrp_characters (identifier VARCHAR(128),character_key VARCHAR(64),first_name VARCHAR(48),last_name VARCHAR(48),status VARCHAR(16))]])
for id,c in pairs(chars)do assert(Db.run("INSERT INTO lightrp_characters VALUES (?,?,'Test',?,'active')",{c.identifier,c.key,tostring(id)}))end
dofile("server/config/housing.lua");dofile("server/modules/housing_store.lua");dofile("server/modules/housing.lua");dofile("server/modules/housing_admin.lua")
local H,S,C=LightRP.housing,LightRP.housingStore,LightRpHousing
local expiryLoop=threads[#threads];step(expiryLoop)
H.onDatabaseReady();assert(H.available())
local function intent()sequence=sequence+1;return "test:"..sequence end
local function call(id,action,p)
    p=p or {};p.action=action;p.mutation=p.mutation or intent()
    if p.id and p.revision==nil then local row=S.properties[tonumber(p.id)] or S.templates[p.id];p.revision=row and row.revision end
    return H.handle(id,p)
end
local function succeeds(id,action,p)local result,why=call(id,action,p);assert(result,action..": "..tostring(why));return result end
local function deny(id,action,p)local result=call(id,action,p);assert(not result,action.." should be denied")end
local function at(id,point,bucket)positions[id]={x=point.x,y=point.y,z=point.z,yaw=point.heading or 90,bucket=bucket or 0}end
local function row(id)return S.properties[id]end
local function lease(id)return S.contracts[row(id).contract_id]end
local function count(tableName)return tonumber(Db.single("SELECT COUNT(*) AS n FROM "..tableName).n)end
deny(1,"admin.template.create",{label="Forbidden",slots=40,weight=100})
local req={label="Apartment A",slots=40,weight=150,mutation=intent()}
local templateId=succeeds(admin,"admin.template.create",req).id
assert(succeeds(admin,"admin.template.create",req).id==templateId and count("lightrp_housing_templates")==1,"idempotent creation")
local spawn={x=1000,y=2000,z=100,heading=180}
for i,point in ipairs({"spawn","exit","stash","wardrobe"})do at(admin,{x=spawn.x+i,y=spawn.y,z=spawn.z});succeeds(admin,"admin.template.capture",{id=templateId,point=point})end
local t=S.templates[templateId];assert(S.templateReady(t))
at(admin,{x=0,y=0,z=0});deny(admin,"admin.template.capture",{id=templateId,point="stash"})
local exterior={x=10,y=20,z=30,heading=90};at(admin,exterior)
local definition={label="Home one",templateId=templateId,kind="apartment",price=50000,rent=1000,rentDays=7,enabled=true}
local h1=succeeds(admin,"admin.property.create",definition).id
local other=S.clone(definition);other.mutation=intent();other.label="Home two"
local h2=succeeds(admin,"admin.property.create",other).id
assert(h1~=h2)
deny(admin,"admin.template.delete",{id=templateId})
-- Atomic ownership and money: fail after the contract insert and verify SQL rollback.
local balance=Money.get(1).bank
sql_fail_after=1;deny(1,"buy",{id=h1});sql_fail_after=nil
assert(Money.get(1).bank==balance and row(h1).contract_id==nil and count("lightrp_housing_contracts")==0)
at(1,{x=500,y=0,z=0});deny(1,"buy",{id=h1});at(1,exterior)
local oldRevision=row(h1).revision
succeeds(1,"buy",{id=h1});assert(Money.get(1).bank==balance-50000)
deny(1,"buy",{id=h1,revision=oldRevision});deny(2,"buy",{id=h1})
assert(count("lightrp_housing_contracts")==1 and count("lightrp_housing_audit")>0)
-- Second resident uses the same interior but a different routing bucket.
succeeds(2,"rent",{id=h2})
deny(2,"enter",{id=h1})
succeeds(1,"enter",{id=h1});lastTravel();succeeds(2,"enter",{id=h2});lastTravel()
assert(H.sessions[1].phase=="inside" and positions[1].bucket~=positions[2].bucket and positions[1].x==positions[2].x)
assert(H.savedPosition(1,positions[1]).x==exterior.x and H.isBusy(1))
deny(admin,"admin.template.capture",{id=templateId,point="spawn"})
-- Stashes isolate tenants even at identical XYZ and verify proximity every transfer.
at(1,t.data.points.stash,C.bucketBase+h1);at(2,t.data.points.stash,C.bucketBase+h2)
succeeds(1,"stash",{id=h1});succeeds(2,"stash",{id=h2})
local firstLease=lease(h1).id;local box1="housing:"..firstLease;local box2="housing:"..lease(h2).id
assert(Inv.addItem(box1,"water",5,nil,1));assert(Inv.addItem(box2,"water",2,nil,1))
assert(not Inv.move(2,box1,1,Inv.playerId(2),10,1),"other instance cannot steal")
assert(Inv.move(1,box1,1,Inv.playerId(1),10,1));assert(Inv.count(box1,"water")==4)
at(1,{x=5000,y=0,z=0},C.bucketBase+h1);assert(not Inv.move(1,box1,1,Inv.playerId(1),11,1))
at(1,t.data.points.stash,C.bucketBase+h1)
-- Grant/revoke keys, verified character identity, visitors get no stash rights.
deny(1,"key.add",{id=h1,player=admin,identifier="forged",character="default"})
succeeds(1,"key.add",{id=h1,player=admin,identifier=chars[admin].identifier,character=chars[admin].key})
succeeds(admin,"enter",{id=h1});lastTravel();at(admin,t.data.points.stash,C.bucketBase+h1)
succeeds(admin,"stash",{id=h1});assert(Inv.move(admin,box1,1,Inv.playerId(admin),10,1))
succeeds(1,"key.remove",{id=h1,identifier=chars[admin].identifier,character=chars[admin].key})
assert(not Inv.move(admin,box1,1,Inv.playerId(admin),11,1),"revocation closes existing stash access")
assert(not H.hasKey(admin,lease(h1)))
-- Exit checks, forced recovery and promised movement fail safely without losing ownership.
at(1,{x=spawn.x+20,y=spawn.y,z=spawn.z},C.bucketBase+h1)
deny(1,"leave");assert(H.leave(1,true));lastTravel();assert(not H.sessions[1] and positions[1].bucket==0)
assert(H.leave(admin,true));lastTravel()
travelFailure=true;succeeds(1,"enter",{id=h1});lastTravel();assert(H.sessions[1].phase=="recovery" and H.savedPosition(1).x==10)
travelFailure=false;assert(H.leave(1,true));lastTravel()
holdTravel=true;succeeds(1,"enter",{id=h1});local co=lastTravel();assert(coroutine.status(co)=="suspended")
deny(1,"sell",{id=h1});holdTravel=false;step(co);assert(H.sessions[1].phase=="inside")
assert(H.leave(1,true));lastTravel()
-- Rent renewal and expiry are durable; expired keys stop working before the sweep.
local rentBalance=Money.get(2).bank;local oldExpiry=lease(h2).data.expires
succeeds(2,"renew",{id=h2});assert(lease(h2).data.expires==oldExpiry+7*86400 and Money.get(2).bank==rentBalance-1000)
assert(S.load());assert(lease(h2).data.expires==oldExpiry+7*86400 and H.hasKey(2,lease(h2)))
time=lease(h2).data.expires+1
assert(not H.hasKey(2,lease(h2)));deny(2,"stash",{id=h2})
step(expiryLoop);lastTravel();assert(row(h2).contract_id==nil and positions[2].bucket==0)
-- New tenants never inherit storage; old belongings remain recoverable, withdrawal only.
local saleBalance=Money.get(1).bank
succeeds(1,"sell",{id=h1});assert(Money.get(1).bank==saleBalance+25000)
succeeds(2,"buy",{id=h1});assert(lease(h1).id~=firstLease)
succeeds(1,"recover",{contract=firstLease});assert(Inv.count(box1,"water")==3)
assert(Inv.move(1,box1,1,Inv.playerId(1),11,1));assert(not Inv.move(1,Inv.playerId(1),11,box1,2,1),"cannot deposit into archived contract")
deny(2,"recover",{contract=firstLease})
-- Admin assignment is free and supports a persisted character, never arbitrary account strings.
deny(admin,"admin.assign",{id=h2,identifier="missing",character="default"})
local b=Money.get(admin).bank
succeeds(admin,"admin.assign",{id=h2,identifier=chars[1].identifier,character=chars[1].key})
assert(lease(h2).data.mode=="assigned" and Money.get(admin).bank==b)
deny(admin,"admin.property.delete",{id=h2})
local reason=string.rep("Detailed administrative reason ",4)
succeeds(admin,"admin.revoke",{id=h2,reason=reason})
succeeds(admin,"admin.property.delete",{id=h2});assert(row(h2).deleted)
deny(1,"admin.property.delete",{id=h1})
-- Disconnect while inside persists the exterior, preview gets a separate instance.
succeeds(2,"enter",{id=h1});lastTravel();assert(chars[2].lastKnown.x==10)
H.onDisconnected(2);assert(not H.sessions[2] and chars[2].lastKnown.x==10);at(2,exterior)
succeeds(admin,"admin.template.preview",{id=templateId});lastTravel();assert(H.sessions[admin].preview)
assert(H.leave(admin,true));lastTravel();assert(positions[admin].bucket==0)
-- Release/delete/restart preserve recovery and soft-deleted template references.
succeeds(admin,"admin.revoke",{id=h1,reason="Retiring test dwelling"})
succeeds(admin,"admin.property.delete",{id=h1});succeeds(admin,"admin.template.delete",{id=templateId})
assert(S.load());assert(S.templates[templateId].deleted and row(h1).deleted)
succeeds(1,"recover",{contract=firstLease});assert(Inv.count(box1,"water")==2)
-- Damaged persisted ownership fails closed and never silently fabricates vacant homes.
local raw=Db.single("SELECT definition FROM lightrp_housing_contracts WHERE id=?",{firstLease}).definition
assert(Db.run("UPDATE lightrp_housing_contracts SET definition='invalid json' WHERE id=?",{firstLease}))
assert(not S.load() and not H.available());deny(1,"browse")
assert(Db.run("UPDATE lightrp_housing_contracts SET definition=? WHERE id=?",{raw,firstLease}));assert(S.load())
-- Large catalogues use bounded replies and only the nearest exterior markers.
local actualProperties,actualTemplates=S.properties,S.templates
local cityPoints
TriggerClientEvent=function(name,_,p)if name==LightRpEvents.net.interactions then cityPoints=p end end
S.properties={};S.templates={}
for i=1,1000 do
    local id="interior-"..i
    S.templates[id]={id=id,revision=1,deleted=false,data={label=string.rep("家",79).."x",points={spawn=spawn,exit=spawn,stash=spawn,wardrobe=spawn},slots=40,weight=100}}
    S.properties[i]={id=i,revision=1,deleted=false,data={label=string.format("Unit %04d ",i)..string.rep("家",65),entrance={x=i*20,y=0,z=0},templateId=id,kind="apartment",price=1000,rent=100,rentDays=7,enabled=true}}
end
at(admin,{x=0,y=0,z=0})
H.refreshPoints();LightRP.sendInteractions(admin)
assert(#cityPoints==32 and #json_ascii_encode(cityPoints)<48*1024,"1000 dwellings cannot overflow interaction packets")
local firstPage=succeeds(admin,"browse",{admin=true,view="properties",page=1})
local lastPage=succeeds(admin,"browse",{admin=true,view="properties",page=100})
assert(#firstPage.properties==10 and firstPage.pages.properties.pages==100 and firstPage.counts.properties==1000)
assert(firstPage.properties[1].id==1 and lastPage.properties[10].id==1000,"pagination reaches every record")
assert(#json_ascii_encode(firstPage)<48*1024)
local detail=succeeds(admin,"browse",{admin=true,view="property",id=999});local found=false
for _,v in ipairs(detail.properties)do if v.id==999 then found=true end end
assert(found,"a selected property remains readable beyond the first page")
local search=succeeds(admin,"browse",{admin=true,view="properties",search="Unit 0999"});assert(#search.properties==1 and search.properties[1].id==999)
local interiors=succeeds(admin,"browse",{admin=true,view="templates",page=100});assert(#interiors.templates==10 and #json_ascii_encode(interiors)<48*1024)
-- Several units sharing a doorway produce one usable entrance.
for _,v in pairs(S.properties)do v.data.entrance=exterior end
H.refreshPoints();LightRP.sendInteractions(admin);assert(#cityPoints==1,"one building marker for a shared door")
S.properties,S.templates=actualProperties,actualTemplates;H.refreshPoints()
print("Housing MySQL integration passed: authoring, ACL, buy/rent, rollback, instances, storage, keys, expiry, recovery and reload.")
