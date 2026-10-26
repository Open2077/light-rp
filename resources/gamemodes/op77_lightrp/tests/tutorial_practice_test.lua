dofile("shared/tutorial.lua")
local C=LightRpTutorialConfig
local positions={[1]={x=1,y=2,z=3,bucket=C.lobby.bucket},[2]={x=1,y=2,z=3,bucket=C.lobby.bucket}}
local props,cars,keys,skies,events={}, {}, {}, {}, {}
local serial,failVehicle,failProp,failKeys,failEnvironment,failMove=0,false,false,false,false,false
local life="alive"
local shared={hour=0,minute=17,second=4,rate=8,timeFrozen=true,weather="sunny",weatherFrozen=true}
LightRP={module=function(_,value)return value end,log=function()end,
 keys={give=function(id,player)keys[id]=player;return not failKeys end,lock=function(id,value)cars[id].locked=value;return true end,clear=function(id)keys[id]=nil end}}
GetCurrentResourceName=function()return "op77_lightrp"end
AddEventHandler=function(name,fn)events[name]=fn end
GetPlayerRoutingBucket=function(player)return positions[player] and positions[player].bucket or 0 end
SetPlayerRoutingBucket=function(player,bucket)
 if failMove or not positions[player] then return false end
 positions[player].bucket=bucket;return true
end
GetPlayersInBucket=function(bucket)local ids={};for id,p in pairs(positions) do if p.bucket==bucket then ids[#ids+1]=id end end;return ids end
local function create(set,def)serial=serial+1;set[serial]=def;return serial end
Open77={players={getLifeState=function()return {phase=life}end},
 props={create=function(d)if failProp then return nil end;return create(props,d)end,get=function(id)return props[id]end,remove=function(id)props[id]=nil end},
 vehicles={create=function(d)if failVehicle then return nil end;return create(cars,d)end,get=function(id)return cars[id]end,remove=function(id)cars[id]=nil end,
 setEngine=function(id,value)cars[id].engine=value end,setDoorOpen=function(id,door,value)assert(door==4);cars[id].trunk=value end},
 environment={getState=function()return shared end,clearBucket=function(bucket)skies[bucket]=nil end,
 setTime=function(h,m,s,bucket)skies[bucket]={hour=h,minute=m,second=s};return not failEnvironment end}}
for method,field in pairs({setTimeRate="rate",setTimeFrozen="timeFrozen",setWeatherFrozen="weatherFrozen"}) do
 Open77.environment[method]=function(value,bucket)skies[bucket][field]=value;return true end
end
Open77.environment.setWeather=function(value,_,bucket)skies[bucket].weather=value;return true end
local module=LightRP.module
LightRP.module=function(name,value)LightRP[name]=value;return module(name,value)end
dofile("server/modules/tutorial_practice.lua")
local P=LightRP.tutorialPractice
local a,b=P.ensure(1,"context_prop"),P.ensure(2,"context_prop")
assert(a and b and a.bucket~=b.bucket and a.bucket~=C.lobby.bucket)
assert(positions[1].bucket==a.bucket and positions[2].bucket==b.bucket)
assert(cars[a.vehicle].bucket==a.bucket and props[a.prop].bucket==a.bucket and keys[a.vehicle]==1)
assert(cars[b.vehicle].bucket==b.bucket and props[b.prop].bucket==b.bucket and keys[b.vehicle]==2)
assert(a.position.x==b.position.x and a.position.y==b.position.y,"private participants can use the same physical bay")
assert(positions[1].x==1 and positions[1].y==2 and positions[1].z==3,"bucket entry does not teleport or respawn")
for key,value in pairs(shared) do assert(skies[a.bucket][key]==value,"the hall's environment is preserved: "..key)end
assert(P.ensure(1,"vehicle_unlock")==a,"one instance survives the whole interaction sequence")
assert(P.clear(1));assert(positions[1].bucket==C.lobby.bucket and not cars[a.vehicle] and not props[a.prop] and not keys[a.vehicle] and not skies[a.bucket])
assert(P.get(2)==b and cars[b.vehicle] and positions[2].bucket==b.bucket,"one player's cleanup leaves the other untouched")
-- Interrupted checkpoints rebuild the correct action, while the city spawn remains owned by the tutorial.
positions[1].bucket=0;a=assert(P.ensure(1,"vehicle_close"))
assert(positions[1].bucket==0 and cars[a.vehicle].trunk and not cars[a.vehicle].locked,"resume prepares the scene without moving an unplaced player")
positions[1].bucket=C.lobby.bucket;assert(P.ensure(1,"vehicle_close"));assert(positions[1].bucket==a.bucket)
failMove=true;assert(not P.clear(1));assert(P.get(1)==a and cars[a.vehicle],"failed return retains its owned scene for recovery")
failMove=false;assert(P.clear(1))
-- Failures leave no objects, keys or environment override, and no false private claim.
for _,failure in ipairs({"vehicle","prop","keys","environment","move"}) do
 failVehicle=failure=="vehicle";failProp=failure=="prop";failKeys=failure=="keys";failEnvironment=failure=="environment";failMove=failure=="move"
 assert(not P.ensure(1,"context_prop"),failure)
 assert(not P.get(1) and positions[1].bucket==C.lobby.bucket and not skies[P.bucket(1)],failure.." rolls back")
 for id in pairs(cars) do assert(id==b.vehicle)end
 for id in pairs(props) do assert(id==b.prop)end
 for id in pairs(keys) do assert(id==b.vehicle)end
end
failVehicle,failProp,failKeys,failEnvironment,failMove=false,false,false,false,false
positions[3]={bucket=P.bucket(1)};assert(not P.ensure(1,"context_prop"),"never reuse another resource's occupied bucket");positions[3]=nil
a=assert(P.ensure(1,"context_prop"));positions[1].bucket=610001;P.onCharacterLoaded(1)
assert(positions[1].bucket==610001 and not P.get(1),"a character switch never overwrites the creator's new bucket")
positions[1].bucket=C.lobby.bucket;a=assert(P.ensure(1,"context_prop"));positions[1]=nil;P.onDisconnected(1)
assert(not P.get(1) and not skies[a.bucket] and P.get(2)==b,"disconnect clears only that participant")
events.onResourceStop("another_resource");assert(P.get(2)==b)
events.onResourceStop("op77_lightrp");assert(positions[2].bucket==C.lobby.bucket and not next(cars) and not next(props) and not next(keys) and not next(skies))
print("PASS: two-player private practice buckets, matching object visibility, unchanged position, shared-hall return, environment inheritance, reconnect checkpoints, failure rollback, character/disconnect/resource cleanup")
