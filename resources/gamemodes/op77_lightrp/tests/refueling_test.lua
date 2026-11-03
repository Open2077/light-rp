dofile("shared/config.lua"); dofile("shared/events.lua"); dofile("shared/items.lua"); dofile("shared/fuel.lua")
local C,E,M=LightRpConfig.fuel,LightRpEvents.net,LightRpFuelModel
local function clone(t) local o={}; for k,v in pairs(t) do o[k]=type(v)=="table" and clone(v) or v end; return o end
local groups=M.clusters(C.stations,35,4)
assert(#groups==1 and #groups[1].pumps==12,"12 supplied pumps -> exactly one station")
local other=clone(C.stations); other[#other+1]={id="remote",position={x=100,y=200,z=8}}
other[#other+1]={id="overpass",position={x=-595,y=-710,z=18}}
assert(#M.clusters(other,35,4)==3,"distant pumps and different floors stay separate")
local chain={}; for i=1,8 do chain[i]={id=tostring(i),position={x=i*20,y=0,z=0}} end
assert(#M.clusters(chain,35,4)==4,"nearby chains cannot merge half the city")
local reverse={}; for i=#C.stations,1,-1 do reverse[#reverse+1]=C.stations[i] end
assert(M.clusters(reverse,35,4)[1].id==groups[1].id,"stable despite config ordering")
local noop=function() end
local time,engine,seated,alive,failPay,failDb,failState=10000,false,false,true,false,false,false
local anim,position,vehicle,level,characters,wallet,events,actions,threads,messages,interactions,props
events,actions,threads,messages,interactions,props={},{},{},{},{},{}
local function pos() return clone(position) end
json={encode=function() return "{}" end}
LightRP={db={ready=true,schema=noop,read=function() return true,{} end,single=function() return nil end,run=function() return true end,transaction=function() return not failDb end},
    command=noop,log=noop,notice=noop,eachModule=noop,state=noop,nowMs=function() return time end,
    action=function(k,v) actions[k]=v end,result=noop,dialog=noop,
    module=function(k,v) LightRP[k]=v; return v end,interaction=function(k,v) interactions[k]=v end,
    characters={get=function(player) return characters[player] end,displayName=function() return "Test" end},
    fuel={labelOf=function() return "Test Car" end,info=function() return {litres=level,capacity=60} end,
        add=function(_,n) if failState then return 0 end; level=level+n; return n end,set=function(_,n) level=n; return n end},
    money={get=function() return wallet end,format=tostring,removeCash=function(_,n) if failPay then return false,"insufficient_funds" end; wallet.cash=wallet.cash-n; return true end,
        exchange=function(_,pay,delta,write,commit) if failDb or failPay then return false,"database_error" end; wallet[pay]=wallet[pay]+delta; commit(); return true end}}
LightRP.money.removeBank=function(_,n) if failPay then return false end; wallet.bank=wallet.bank-n; return true end
Open77={players={position=pos,getLifeState=function() return {phase=alive and "alive" or "dead"} end},vehicles={
    flags={destroyed=16},get=function(id) return vehicle and id==vehicle.id and clone(vehicle) or nil end,
    getPlayerSeat=function() return seated and {vehicleId=9} or nil end,getDriver=function() return 0 end,
    isEngineOn=function() return engine end,all=function() return vehicle and {clone(vehicle)} or {} end,
    closest=function() return vehicle and {id=vehicle.id} end},
    animations={current=function() return anim end,play=function(_,profile,opts) anim={active=true,playbackId="anim:"..time,profile=profile}; return anim end,
        stop=function(_,id) if anim and anim.playbackId==id then anim=nil end end},
    props={create=function() props.can=true; return "can" end,attach=function() return true end,remove=function(id) props[id]=nil end}}
GetPlayerName=function() return "Player" end; GetCurrentResourceName=function() return "op77_lightrp" end
RegisterNetEvent=function(k,fn) events[k]=fn end; AddEventHandler=noop
TriggerClientEvent=function(k,player,data) messages[#messages+1]={event=k,player=player,data=data} end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end; Wait=coroutine.yield
dofile("server/modules/inventory.lua"); dofile("server/modules/refueling.lua")
local R,Inv=LightRP.refueling,LightRP.inventory
for _,t in ipairs(threads) do assert(coroutine.resume(t)) end
for _,t in ipairs(threads) do assert(coroutine.resume(t)) end
local count,blips=0,0; for _,d in pairs(interactions) do count=count+1; if d.blip then blips=blips+1;
    assert(d.blip.position.x==groups[1].position.x and d.blip.icon=="fuel" and d.blip.routable==false) end end
assert(count==12 and blips==1,"only one centred map blip; twelve real pump interactions")
local function setup()
    R.cancel(1); R.cancel(2); time=time+100000; engine,seated,alive,failPay,failDb,failState=false,false,true,false,false,false
    position=clone(C.stations[1].position); position.bucket=0
    vehicle={id=9,x=position.x+2,y=position.y,z=position.z,bucket=0,speed=0,flags=0}; level=10; anim=nil
    wallet={cash=500,bank=500}; characters={[1]={status="active",identifier="test1",key="default"},[2]={status="active",identifier="test2",key="default"}}
    Inv.onCharacterActivated(1,characters[1]); Inv.player(1).items={}
end
local function event(k,data,player) source=player or 1; events[k](data) end
local function last(phase)
    for i=#messages,1,-1 do if messages[i].event==E.fuel and messages[i].data.phase==phase then return messages[i].data end end
    error("missing phase "..phase)
end
local function begin(player)
    actions["fuel.buy"](player or 1,{spot="pump01",vehicle=9,litres=10,pay="cash"})
    return R.isActive(player or 1) and last("prepare").token
end
local function play(token)
    event(E.fuelReady,{token=token}); assert(last("approach").token==token)
    event(E.fuelReady,{token=token}); assert(last("play").token==token)
end
local function complete(token,ms) time=time+(ms or 9500); event(E.fuelFinish,{token=token,status="success"}) end
setup(); seated=true; assert(not begin(),"cannot refuel from a seat")
setup(); engine=true; assert(not begin(),"engine must be off")
setup(); vehicle.speed=1; assert(not begin(),"moving car refused")
setup(); position.bucket=3; assert(not begin(),"bucket isolation")
setup(); local token=begin(); assert(token); assert(not begin(2),"pump/vehicle exclusive")
event(E.fuelReady,{token=token},2); assert(not anim,"ticket bound to player")
play(token); assert(level==10 and wallet.cash==500,"not instant, no early payment")
complete(token,400); assert(level==10 and wallet.cash==500 and not R.isActive(1),"early completion refused")
setup(); token=begin(); play(token); complete(token); assert(level==20 and wallet.cash==500-10*C.pricePerLitre and not anim,"one complete fill, one payment")
complete(token); assert(level==20 and wallet.cash==500-10*C.pricePerLitre,"replay cannot double grant")
setup(); token=begin(); play(token); engine=true; complete(token); assert(level==10 and wallet.cash==500,"engine restart cancels")
setup(); token=begin(); play(token); vehicle.x=vehicle.x+2; complete(token); assert(level==10 and wallet.cash==500,"moved vehicle cancels")
setup(); token=begin(); play(token); position.x=position.x+2; complete(token); assert(level==10 and wallet.cash==500,"walking away cancels")
setup(); token=begin(); play(token); alive=false; complete(token); assert(level==10 and wallet.cash==500,"death cancels")
setup(); token=begin(); play(token); event(E.fuelFinish,{token=token,status="cancelled"}); assert(not R.isActive(1) and not anim and wallet.cash==500)
setup(); token=begin(); play(token); failPay=true; complete(token); assert(level==10 and wallet.cash==500,"failed payment rolls back fuel")
setup(); token=begin(); play(token); failState=true; complete(token); assert(wallet.cash==500,"failed tank write cannot charge")
setup(); token=begin(); play(token); R.onDisconnected(1); assert(not R.isActive(1) and not anim and wallet.cash==500)
setup(); actions["fuel.jerrycan"](1,{spot="pump01",pay="bank"}); token=last("prepare").token
event(E.fuelReady,{token=token}); assert(props.can and Inv.count(Inv.playerId(1),"jerrycan")==0)
complete(token,18000); assert(not props.can and Inv.count(Inv.playerId(1),"jerrycan")==1 and wallet.bank==500-C.jerrycan.deposit-C.jerrycan.litres*C.pricePerLitre,"paid can atomic checkout")
setup(); local attach=Open77.props.attach; local attempts=0
Open77.props.attach=function(_,binding)
    attempts=attempts+1
    if binding.firstPerson then return nil,"invalid_attachment" end
    return true
end
actions["fuel.jerrycan"](1,{spot="pump01",pay="bank"}); token=last("prepare").token
event(E.fuelReady,{token=token}); assert(attempts==2 and R.isActive(1),"older host retries only the optional firstPerson field")
event(E.fuelFinish,{token=token,status="cancelled"}); assert(not props.can and wallet.bank==500)
setup(); attempts=0; Open77.props.attach=function() attempts=attempts+1; return nil,"permission_denied:world.props" end
actions["fuel.jerrycan"](1,{spot="pump01",pay="bank"}); token=last("prepare").token
event(E.fuelReady,{token=token}); assert(attempts==1 and not R.isActive(1) and not props.can and wallet.bank==500,"real attachment failure is not retried or charged")
Open77.props.attach=attach
setup(); local inv=Inv.player(1); inv.items[1]={name="jerrycan",count=1}; level=55
assert(Inv.use(1,1)); token=last("prepare").token; event(E.fuelReady,{token=token}); complete(token,6000)
assert(level==60 and inv.items[1].metadata.fuelLitres==15 and wallet.cash==500,"partial pour keeps remaining litres")
level=40; assert(Inv.use(1,1)); token=last("prepare").token; event(E.fuelReady,{token=token}); complete(token,16000)
assert(level==55 and inv.items[1].name=="jerrycan_empty","empty can is retained")
setup(); inv=Inv.player(1); inv.items[1]={name="jerrycan_empty",count=2}
actions["fuel.jerrycan"](1,{spot="pump01",pay="cash"}); token=last("prepare").token; event(E.fuelReady,{token=token}); failDb=true; complete(token,18000)
assert(Inv.count(inv.id,"jerrycan_empty")==2 and Inv.count(inv.id,"jerrycan")==0 and wallet.cash==500,"failed DB keeps empty cans and money")
setup(); inv=Inv.player(1); inv.items[1]={name="jerrycan",count=1}
assert(Inv.use(1,1)); token=last("prepare").token; event(E.fuelReady,{token=token}); inv.items[1]={name="jerrycan",count=1}; complete(token,22000)
assert(level==10 and inv.items[1].name=="jerrycan","replaced item cannot be consumed")
for _,path in ipairs({"server/modules/fuel.lua","client/core/refueling.lua","client/core/interact.lua"}) do assert(loadfile(path)) end
print("PASS refueling: clusters, authority, locks, timings, cancellation, payment, cans, partial pours and rollback")
