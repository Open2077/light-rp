#!/usr/bin/env python3
"""Slot machine client adapter on the real native-prop controller, with SDK mocks
and the strict per-resume instruction budget of tools/test-board-games-client.py."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
# Share only the mock host, not another test's scenarios or assertions.
source=(ROOT/'tools/test-board-games-client.py').read_text()
namespace={'__file__':str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0],namespace)
lua=namespace['lua']
assets=json.loads((ROOT/'resources/assets/models/open77_casino_slots/asset-manifest.json').read_text())
lua.globals().availableModels=lua.table_from({model['name']:True for model in assets['models']+assets.get('colliders',[])})
lua.globals().assetLayout=lua.table_from({k:(lua.table_from(v) if isinstance(v,list) else v) for k,v in assets['layout'].items()})
lua.execute(r'''
LightRpBoardGames={};LightRpItems={}
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\casino_slots\\',1,true)==1)
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 if options.model:find('_collider.ent',1,true) then -- tools/test-table-colliders.py
  assert(options.collision==true and options.physics=='static' and options.scale==1)
 else assert(options.scale==.65 and options.collision==false and options.physics=='none') end
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local name=options.model:match('([^\\]+)%.ent$')
 assert(availableModels[name],'native asset missing from the cooked package: '..tostring(name))
 nativeProps[id]={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=true,failed=false,backend='raw_entity'}
 createdProps=createdProps+1;return id
end
function findProp(name) for id,p in pairs(nativeProps) do if p.name==name then return p,id end end end
function countProps() local n=0;for _ in pairs(nativeProps) do n=n+1 end;return n end
function near(a,b) return math.abs(a-b)<1e-6 end
''')
for name in ['shared/tabletop_extra_rules.lua','shared/casino_slots.lua','client/core/tabletop_extra.lua','client/core/casino_slots.lua','client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(),name=name)
lua.execute(r'''
local S,E,C,L=LightRpCasinoSlots,LightRpTabletopExtraClient,LightRpBoardGamesClient,LightRpCasinoSlotsLayout
local K=.65
-- The client layout is the cooked layout.
for key,value in pairs(assetLayout) do
 if type(value)=='number' then assert(near(L[key],value),key)
 else for i=1,#value do assert(near(L[key][i],value[i]),key..i) end end
end
C.bind(page);C.start();step();step()
assert(E.supports('slots'))
local now=1700000000000
local machine={id=201,kind='slots',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=7,black=9},actor=7,ready=true,mode='duel',revision=1,serverNow=now,game=S.new('duel')}
events['lightrp:boardGames:state']({boards={machine}});step()
waitUntil(function() return countProps()==17 end,'cabinet, its collider, 3 strips, 6 lever poses, 2 lamps, 4 coins')
assert(C.isActive())
-- The crosshair aims at the lever (outlined) and a click pulls with the bet
-- chosen in the ALT menu (LightRpCasinoSlotsClient.setBet, tools/test-table-menu.py).
local Slots=LightRpCasinoSlotsClient
assert(Slots.bet()==10 and not Slots.setBet(0) and not Slots.setBet(1001) and not Slots.setBet(2.5) and Slots.setBet(25) and Slots.bet()==25)
local freeBefore=#requests
forcedRay={origin={x=.55*K,y=-2,z=1.6*K},direction={x=0,y=1,z=0}};step()
assert(batches['boardGames:preview'] and #batches['boardGames:preview'].lines==4,'the aimed lever is outlined')
keys.mouse1=true;step();keys.mouse1=false;step()
assert(#requests==freeBefore+1 and last().action=='game' and last().operation=='pull' and last().data.bet==25 and last().revision==1,'a crosshair click on the lever pulls')
forcedRay={origin={x=0,y=-2,z=1.4*K},direction={x=0,y=1,z=0}};step()
assert(batches['boardGames:preview']==nil,'no outline off the lever')
keys.mouse1=true;step();keys.mouse1=false;step();assert(#requests==freeBefore+1,'a click beside the lever never wagers')
forcedRay=nil
local function z(name) return findProp(name).position.z/K end
local function at(name,x,y,zz) local p=findProp(name).position;return near(p.x/K,x) and near(p.y/K,y) and near(p.z/K,zz) end
local park=L.leverPark
assert(at('slot_lever_0',0,0,0))
for i=1,5 do assert(at('slot_lever_'..i,park[1],park[2],park[3]),'inactive lever poses are parked') end
assert(at('slot_lamp_off',0,0,0) and at('slot_lamp_on',L.lampPark[1],L.lampPark[2],L.lampPark[3]))
for r=1,3 do assert(at('slot_strip_'..r,L.reelX[r],L.stripY,L.paylineZ+L.pitch)) end
local before=#requests
assert(E.command(machine,'pull',{bet=10}) and #requests==before+1 and last().data.bet==10)
assert(not E.command(machine,'settle',{}) and #requests==before+1,'unknown operations stay local')
-- The server pulls: three sevens, timestamped on the server clock.
local function stopOf(r,name) for i,s in ipairs(S.REELS[r]) do if s==name then return i-1 end end end
local stops={stopOf(1,'seven'),stopOf(2,'seven'),stopOf(3,'seven')}
machine=assert(machine);machine.game=assert(S.act(machine.game,'white','pull',{bet=10,stops=stops,nowMs=now}))
machine.revision=2;machine.serverNow=now+1 -- each snapshot carries a newer server stamp
events['lightrp:boardGames:state']({boards={machine}})
local start=clock
local function advance(ms) while clock-start<ms do step() end end
-- Lever: fully pulled pose in place around 250 ms, others parked.
advance(260)
assert(at('slot_lever_5',0,0,0) and at('slot_lever_0',park[1],park[2],park[3]),'lever pulled')
advance(700);assert(at('slot_lever_0',0,0,0) and at('slot_lever_5',park[1],park[2],park[3]),'lever sprang back')
-- Reels spin (strip positions change every few steps and stay in the wrap range).
local seen={}
for i=1,10 do step();local v=z('slot_strip_3');seen[#seen+1]=v
 local j=(v-L.paylineZ)/L.pitch;assert(j>=1-1e-9 and j<S.STOPS+1,'strip outside the wrap range')
end
local moving=0;for i=2,#seen do if math.abs(seen[i]-seen[i-1])>1e-6 then moving=moving+1 end end
assert(moving==#seen-1,'reel 3 must move on every frame ('..moving..'/'..(#seen-1)..')')
-- Staggered stops on the server's stops: reel 1 at 1.8 s, reel 2 at 2.4 s, reel 3 at 3.0 s.
advance(1850);assert(near(z('slot_strip_1'),L.paylineZ+(stops[1]+1)*L.pitch),'reel 1 landed')
local reel3=E.pieceTargets(machine)['slot-reel-3'].position.z
assert(not near(reel3,L.paylineZ+(stops[3]+1)*L.pitch),'reel 3 must still spin at 1.85 s')
advance(2450);assert(near(z('slot_strip_2'),L.paylineZ+(stops[2]+1)*L.pitch),'reel 2 landed')
advance(3050)
for r=1,3 do assert(near(z('slot_strip_'..r),L.paylineZ+(stops[r]+1)*L.pitch),'reel '..r..' on the server stop') end
-- Win feedback: lamp lit (blinking), then four coins (x200) fall into the tray.
advance(3100);assert(at('slot_lamp_on',0,0,0),'win lamp lit')
advance(3220) -- coin 1 falls from 150 ms after the win, coin 2 from 290 ms: check between
local falling=0
for _,p in pairs(nativeProps) do if p.name=='slot_coin' and not near(p.position.y/K,L.coinPark[2]) then
 falling=falling+1;assert(p.position.z/K>=L.trayZ-1e-9 and p.position.z/K<=L.chuteZ+1e-9 and p.position.y/K<=L.chuteY+1e-9)
end end
assert(falling==1,'the first coin is dropping from the chute')
advance(5600)
local inTray=0
for _,p in pairs(nativeProps) do if p.name=='slot_coin' and near(p.position.z/K,L.trayZ) and near(p.position.y/K,L.trayY) then inTray=inTray+1 end end
assert(inTray==4,'coins in the tray: '..inTray)
assert(at('slot_lamp_on',0,0,0),'steady lamp after the blink')
-- Same server time, different local arrival: identical poses on every client.
local saved=clock
-- Fresh boards measured at the same server time (now+1500):
local A={id=301,kind='slots',position=machine.position,players=machine.players,game=machine.game,serverNow=now+500}
local B={id=302,kind='slots',position=machine.position,players=machine.players,game=machine.game,serverNow=now+1200}
clock=saved;E.observe(A);clock=saved+700;E.observe(B);clock=saved+1000
local ta,tb=E.pieceTargets(A),E.pieceTargets(B)
for key,target in pairs(ta) do
 local other=tb[key];assert(near(target.position.z,other.position.z) and near(target.position.y,other.position.y),'clients disagree on '..key)
end
-- Settled state on the server keeps the reels where they landed.
machine.game=assert(S.act(machine.game,'white','settle',{nowMs=now+3000}));machine.revision=3;machine.serverNow=now+60000
events['lightrp:boardGames:state']({boards={machine}});step();step()
for r=1,3 do assert(near(z('slot_strip_'..r),L.paylineZ+(stops[r]+1)*L.pitch)) end
-- A still machine costs nothing per frame: no target computation, no transform.
for i=1,10 do step() end
local calls,original=0,E.pieceTargets
E.pieceTargets=function(...) calls=calls+1;return original(...) end
local idle=movedProps
for i=1,20 do step() end
E.pieceTargets=original
assert(calls==0 and movedProps==idle,'still machine: '..calls..' target calls, '..(movedProps-idle)..' transforms')
-- Every reel timeline lands exactly and stays within the wrap range for every stop pair.
for from=0,S.STOPS-1 do for to=0,S.STOPS-1 do
 local spin={from={from,from,from},stops={to,to,to}}
 for r=1,3 do
  for t=0,3200,40 do local j=L.reelIndex(spin,r,t);assert(j>=1 and j<S.STOPS+1) end
  assert(L.reelIndex(spin,r,S.TIMING.stops[r])==to+1)
 end
end end
edge('BACKSPACE');assert(not C.isActive())
handlers.onClientResourceStop('test');for i=1,20 do step() end
assert(next(nativeProps)==nil and next(batches)==nil)
print('slot machine client: 16 native props + collider, lever poses, server-clock reels on the server stops, lamp and coins, cleanup: OK; peak '..peakInstructions..' (budget '..BOARD_BUDGET..')')
''')
