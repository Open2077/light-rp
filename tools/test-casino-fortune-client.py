#!/usr/bin/env python3
"""Fortune Wheel client: real shared rules + adapter + native-prop controller,
with the SDK mocks and strict per-resume budget of tools/test-board-games-client.py.
Proves the props, the pose chosen from the server clock, flapper kicks at each
peg, the exact final pose, chip stacks and the instruction peak."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'tools/test-board-games-client.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
lua = namespace['lua']
assets=json.loads((ROOT/'resources/assets/models/open77_casino_fortune/asset-manifest.json').read_text())
lua.globals().availableModels=lua.table_from({model['name']: True for model in assets['models'] + assets.get('colliders', [])})
lua.execute(r'''
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\casino_fortune\\',1,true)==1)
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 -- The table base gets a solid, mesh-less collider at scale 1; everything else stays non-solid.
 if options.model:find('_collider.ent',1,true) then assert(options.scale==1 and options.collision==true and options.physics=='static')
 else assert(options.scale==.65 and options.collision==false and options.physics=='none') end
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local name=options.model:match('([^\\]+)%.ent$')
 assert(availableModels[name],'native asset missing from the cooked package: '..tostring(name))
 nativeProps[id]={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=true,failed=false,backend='raw_entity'}
 createdProps=createdProps+1;return id
end
function findProp(name)
 for id,p in pairs(nativeProps)do if p.name==name then return p,id end end
end
function countProps()
 local count=0;for _,p in pairs(nativeProps)do if not p.name:find('_collider$') then count=count+1 end end;return count
end
LightRpBoardGames={};LightRpItems={}
''')
for name in ['shared/casino_fortune.lua', 'client/core/tabletop_extra.lua', 'client/core/casino_fortune.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(), name=name)
lua.execute(r'''
local F,E,C=LightRpCasinoFortune,LightRpTabletopExtraClient,LightRpBoardGamesClient
local S=.65
local WY,WZ,PARK=.10,2.15,.195
C.bind(page);C.start();step();step()
assert(E.supports('fortune') and not E.supports('chess'))
local now=1700000000000
local g=F.new()
g=assert(F.bet(g,{inventory='a',spot='20',amount=40,roundKey='k'}))
g=assert(F.bet(g,{inventory='b',spot='1',amount=3,roundKey='k'}))
local wheel={id=201,kind='fortune',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=7},actor=7,ready=true,mode='duel',revision=1,serverNow=now,game=F.view(g,'a')}
events['lightrp:boardGames:state']({boards={wheel}});step()
local expected=1+27+2+2+4+2
waitUntil(function()return countProps()==expected end,'stand, 27 rotor poses, 2 blur, 2 medallions, 4 flappers, 2 chip stacks')
assert(C.isActive() and findProp('fortune_stand'))
local function near(a,b,tol) return math.abs(a-b)<(tol or 1e-6) end
local function at(name,y) local p=assert(findProp(name),name);return near(p.position.y,y*S,1e-4) end
-- At rest: pose 0 in the drum, all other poses parked behind it.
for i=0,26 do assert(at(('fortune_disc_%02d'):format(i),i==0 and WY or PARK),i) end
assert(at('fortune_blur_0',PARK) and at('fortune_blur_1',PARK) and at('fortune_flapper_1',.042) and at('fortune_flapper_3',.235))
local eye=findProp('fortune_eye');assert(near(eye.position.x,0,1e-4) and near(eye.position.z,(WZ+.42)*S,1e-4),'eye medallion on top of the rest pose')
assert(findProp('fortune_chips_2') and findProp('fortune_chips_1'),'stacks for 40 and 3')
assert(near(findProp('fortune_chips_2').position.x,.2*S,1e-4),'20x stack on its spot')
-- The game view opens on the whole wheel above the felt.
assert(focus and camera and frozen and view.view=='wheel' and #view.views==3 and cameraSpec.lookAt)
-- Bets: a click on a felt spot selects it, the bar (tools/test-table-menu.py)
-- bets its chip on the selection.
local Fortune=LightRpCasinoFortuneClient
assert(Fortune.chip()==10 and not Fortune.setChip(0) and not Fortune.setChip(1001) and Fortune.setChip(25) and Fortune.chip()==25)
local before=#requests
assert(E.command(wheel,'bet',{spot='5',amount=25}) and #requests==before+1 and last().action=='game' and last().operation=='bet' and last().data.spot=='5')
assert(not E.command(wheel,'steal',{}) and #requests==before+1)
-- The cursor outlines the hovered spot; a click selects it (outlined too) and wagers nothing.
forcedRay={origin={x=.2*S,y=-.68*S,z=3},direction={x=0,y=0,z=-1}};pointer({x=.6,y=.7});step()
assert(batches['boardGames:preview'] and #batches['boardGames:preview'].lines==4,'hovered spot outlined')
pointer({x=.6,y=.7,pressed=true});step();pointer({x=.6,y=.7,released=true});for i=1,4 do step() end
assert(#requests==before+1 and E.selection(wheel).key=='20' and E.selection(wheel).label==F.LABEL['20'],'a click selects the 20x spot')
forcedRay={origin={x=.2*S,y=0,z=3},direction={x=0,y=0,z=-1}};pointer({x=.6,y=.2});step()
assert(#batches['boardGames:preview'].lines==4,'the selection stays outlined')
pointer({x=.6,y=.2,pressed=true});step();pointer({x=.6,y=.2,released=true});step();forcedRay=nil
assert(#requests==before+1 and E.selection(wheel).key=='20','a click off the spots changes nothing')
-- The server spins: segment 13 (20x), two laps, from rest 0.
local spun=assert(F.spin(g,{outcome=13,laps=2,nowMs=now+1000,roundKey='k'}))
wheel.game=F.view(spun,'a');wheel.revision=2;wheel.serverNow=now+1000
local origin=clock
events['lightrp:boardGames:state']({boards={wheel}});step()
local spin=wheel.game.spin
local function serverAt(ms) clock=origin+ms;return E.pieceTargets(wheel) end
local function active(t,prefix)
 local found
 for key,v in pairs(t) do if key:find(prefix,1,true)==1 and near(v.position.y,key:find('flapper',1,true) and .042 or WY,1e-9) then assert(not found,'two active '..prefix);found=key end end
 return found
end
-- Fast start: the blur discs stand in, every crisp pose is parked, medallions hide.
local t=serverAt(300);assert(active(t,'fw-blur-') and not active(t,'fw-fortune_disc_'))
assert(near(t['fw-eye'].position.y,.235) and t['fw-blur-0'].piece.snap==true)
local flaps={};for ms=300,1500,45 do flaps[active(serverAt(ms),'fw-flapper-')]=true end
assert(flaps['fw-flapper-3'] and flaps['fw-flapper-0'],'the flapper chatters at speed')
-- Slow phase: the crisp pose follows the server clock exactly, with the medallion.
for _,ms in ipairs({4000,5500,6800,7600,8100}) do
 t=serverAt(ms);local pos=F.progress(spin,now+1000+ms);local r=math.floor(pos+.5)
 assert(not active(t,'fw-blur-'),ms)
 assert(active(t,'fw-fortune_disc_')==('fw-fortune_disc_%02d'):format(r%27),ms)
 local a=math.rad(r*360/54);assert(near(t['fw-eye'].position.x,.42*math.sin(a)) and near(t['fw-star'].position.z,WZ-.42*math.cos(a)))
end
-- Each peg crossing kicks the flapper right, then it swings back and rests.
local travel=spin.to-F.STOP_OFFSET-spin.from
local function crossing(k) return spin.spinMs*(1-math.sqrt(1-(k+.5)/travel)) end
local c=crossing(math.floor(F.progress(spin,now+1000+7000)-spin.from))
assert(active(serverAt(c+20),'fw-flapper-')=='fw-flapper-3')
assert(active(serverAt(c+75),'fw-flapper-')=='fw-flapper-2')
assert(active(serverAt(c+130),'fw-flapper-')=='fw-flapper-0')
local gap=crossing(math.floor(F.progress(spin,now+1000+7000)-spin.from)+1)-c;assert(gap>200)
assert(active(serverAt(c+190),'fw-flapper-')=='fw-flapper-1')
local disc=active(serverAt(c-5),'fw-fortune_disc_');assert(active(serverAt(c+5),'fw-fortune_disc_')~=disc,'the rotor steps as the peg passes')
-- Landing: the final pose puts segment 13 under the flapper; stacks resolve.
clock=origin+spin.spinMs+700;for i=1,8 do step() end
local final=('fortune_disc_%02d'):format(spin.to%27)
assert(F.topSegment(spin.to)==13 and at(final,WY))
for i=0,26 do local n=('fortune_disc_%02d'):format(i);if n~=final then assert(at(n,PARK),n) end end
assert(at('fortune_flapper_1',.042),'the flapper rests after the settle')
assert(not findProp('fortune_chips_1'),'the losing 1x stack was swept away')
local payouts=0;for _,p in pairs(nativeProps) do if p.name=='fortune_chips_4' then payouts=payouts+1;assert(near(p.position.y,-.84*S,1e-4) and near(p.position.z,1.252*S,1e-4)) end end
assert(payouts==1 and findProp('fortune_chips_2'),'the winning stake stays and its 40x21=840 payout rose beside it')
-- Different local arrival times produce the same pose at the same server time.
local joined={id=202,kind='fortune',position=wheel.position,players=wheel.players,game=wheel.game,serverNow=now+1000+5000}
E.observe(joined);local mid=E.pieceTargets(joined)
local same=serverAt(5000)
assert(active(mid,'fw-fortune_disc_')==active(same,'fw-fortune_disc_') and near(mid['fw-eye'].position.x,same['fw-eye'].position.x))
-- Settled: the rest pose survives into the next betting round.
local settled=assert(F.settle(spun,spin.endsAt))
local nextRound=assert(F.bet(settled,{inventory='a',spot='2',amount=1,roundKey='k2'}))
wheel.game=F.view(nextRound,'a');wheel.revision=3;wheel.serverNow=now+20000
t=E.pieceTargets(wheel);assert(active(t,'fw-fortune_disc_')=='fw-'..final and t['fw-chips-2'] and not t['fw-payout'])
-- Worst case for the budget: every spot staked, sweeping and paying at once.
local full=F.new();for _,spot in ipairs(F.SPOTS) do full=assert(F.bet(full,{inventory='a',spot=spot,amount=600,roundKey='f'})) end
full=assert(F.spin(full,{outcome=0,laps=3,nowMs=now+30000,roundKey='f'}))
wheel.game=F.view(full,'a');wheel.revision=4;wheel.serverNow=now+30000;origin=clock
events['lightrp:boardGames:state']({boards={wheel}})
for i=1,40 do step() end
clock=origin+full.spin.spinMs;for i=1,6 do step() end
assert(countProps()==1+35+7+1,'all seven stacks plus the payout: '..countProps())
for i=1,20 do step() end
edge('BACKSPACE');assert(not C.isActive())
handlers.onClientResourceStop('test');for i=1,20 do step()end
assert(next(nativeProps)==nil and next(batches)==nil)
print('fortune client: 38-44 native props per table, server-clock poses, flapper kicks, exact landing, chips, cleanup: OK; peak '..peakInstructions..' of '..BOARD_BUDGET)
''')
