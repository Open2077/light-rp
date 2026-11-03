#!/usr/bin/env python3
"""Real extra rules + native-prop controller, with SDK mocks and strict budgets."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
# Share only the mock host, not another test's scenarios or assertions.
source = (ROOT/'tools/test-board-games-client.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
lua = namespace['lua']
assets=json.loads((ROOT/'resources/assets/models/open77_tabletop_extra/asset-manifest.json').read_text())
lua.globals().layoutManifest=lua.table_from(assets['layout'])
lua.globals().availableModels=lua.table_from({model['name']: True for model in assets['models'] + assets.get('colliders', [])})
lua.execute(r'''
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\tabletop_extra\\',1,true)==1)
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
''')
for name in ['shared/tabletop_extra_rules.lua', 'client/core/tabletop_extra.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(), name=name)
lua.execute(r'''
local R,E,C=LightRpTabletopExtraRules,LightRpTabletopExtraClient,LightRpBoardGamesClient
C.bind(page);C.start();step();step()
assert(E.supports('roulette') and not E.supports('dominoes') and not E.supports('cardtower') and not E.supports('chess'))
local now=1700000000000
local roulette={id=101,kind='roulette',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=7,black=9},actor=7,ready=true,mode='duel',revision=1,serverNow=now,game=assert(R.new('roulette','duel'))}
events['lightrp:boardGames:state']({boards={roulette}});step()
waitUntil(function()return countProps()==3 end,'roulette table, wheel and ball native props')
assert(C.isActive() and findProp('roulette_table') and findProp('roulette_wheel') and findProp('roulette_ball'))
local before=#requests
-- Bets come from the ALT menu (tools/test-table-menu.py) through Extra.command.
assert(E.command(roulette,'bet',{bet='red',amount=25}))
assert(#requests==before+1 and last().action=='game' and last().operation=='bet' and last().data.amount==25 and last().revision==1)
assert(not E.command(roulette,'teleport',{}) and #requests==before+1,'unknown operations never reach the server')
-- The game view opens overhead on the wheel and the layout.
assert(focus and camera and frozen and cameraSpec.rotation and view.view=='top' and #view.views==5 and view.views[5].key=='free' and view.views[2].key=='layout')
-- Bets open: the whole layout is marked as its grid, 31 faint lines, built once.
waitUntil(function() return marks()==31 end,'roulette layout marked')
for _,l in ipairs(batches['boardGames:marks'].lines) do assert(l.color=='#d8ecff5c' and math.abs(l.a.z-(E.rouletteLayout.z+.002)*.65)<1e-9) end
-- Cursor picking on the printed layout (straight down on a cell): a click
-- selects the bet, outlined on the table; it never wagers by itself.
local L=E.rouletteLayout
local function at(x,y) forcedRay={origin={x=x*.65,y=y*.65,z=3},direction={x=0,y=0,z=-1}};pointer({x=.4,y=.6});step();step() end
local function pick(x,y) at(x,y);pointer({x=.4,y=.6,pressed=true});step();pointer({x=.4,y=.6,released=true});step();step() end
local function sel() local s=E.selection(roulette);return s and s.key end
local dz,ev=L.top-3*L.cell,L.top-3*L.cell-L.band
at(L.gx0+5.5*L.cell,L.top-1.5*L.cell);assert(outlines()==4 and sel()==nil,'the hovered cell is outlined')
pick(L.gx0+5.5*L.cell,L.top-1.5*L.cell);assert(sel()=='number:17' and E.selection(roulette).label=='17' and outlines()==4)
assert(#requests==before+1,'a click selects, the bar bets')
at(L.gx0+.5*L.cell,L.top-.5*L.cell);assert(outlines()==8,'selection and hover')
pick(L.gx0+11.5*L.cell,L.top-.5*L.cell);assert(sel()=='number:36')
pick(L.gx0+.5*L.cell,L.top-2.5*L.cell);assert(sel()=='number:1')
pick(L.gx0-.05,L.top-1.5*L.cell);assert(sel()=='number:0' and E.selection(roulette).label=='Zero')
pick(L.gx0+6*L.cell,dz-L.band/2);assert(sel()=='dozen2')
pick(L.gx0+5*L.cell,ev-L.band/2);assert(sel()=='red' and E.roulettePays('red')=='1:1')
pick(L.gx0+11*L.cell,ev-L.band/2);assert(sel()=='high')
pick(.2,0);assert(sel()=='high','a click on the wheel keeps the selection')
-- Every cell of the layout maps to a bet the server accepts.
for col=0,11 do for row=0,2 do
 local key=E.rouletteCell(L.gx0+(col+.5)*L.cell,L.top-(row+.5)*L.cell)
 assert(key=='number:'..(col*3+3-row) and R.roulettePayout(key,col*3+3-row,1)==36)
end end
-- The layout matches the cooked asset (tools/build-tabletop-extra-props.py).
local layout=layoutManifest
assert(math.abs(L.gx0-(layout.x0+.025+L.zeroW))<1e-9 and math.abs(L.top-(layout.y1-.025))<1e-9 and math.abs(L.z-layout.z)<1e-6)
assert(L.gx0+12*L.cell<=layout.x1 and ev-L.band>=layout.y0)
forcedRay=nil
-- A still wheel holds its targets until the next snapshot; a spin animates.
local _,hold=E.pieceTargets(roulette);assert(hold==math.huge,'a still roulette needs no per-frame targets')
roulette.game=assert(R.act(roulette.game,'white','spin',{outcome=17,seedAngle=41,nowMs=now}))
roulette.revision=2;roulette.serverNow=now+1
E.observe(roulette)
local a,spinHold=E.pieceTargets(roulette);assert(spinHold==nil,'a spinning wheel is recomputed every frame')
clock=clock+4000;local b=E.pieceTargets(roulette)
assert(a['roulette-wheel'].piece.yaw~=b['roulette-wheel'].piece.yaw)
-- Mid-spin the ball still rides the ball track (the cooked bowl's TRACK_R/Z).
assert(math.abs(math.sqrt(b['roulette-ball'].position.x^2+b['roulette-ball'].position.y^2)-.388)<1e-9 and math.abs(b['roulette-ball'].position.z-.074)<1e-9)
local spin=roulette.game.spin
local function radius(t) return math.sqrt(t['roulette-ball'].position.x^2+t['roulette-ball'].position.y^2) end
local function ballAngle(t) return math.deg(math.atan(t['roulette-ball'].position.x,t['roulette-ball'].position.y)) end
-- The drop: the radius only shrinks, and the ball stays above the bowl's surfaces.
local lastR=1
for ms=4100,6100,100 do
 clock=clock+100;local t=E.pieceTargets(roulette);local r,z=radius(t),t['roulette-ball'].position.z
 assert(r<=lastR+1e-9 and r>=.27-1e-9,'ball radius '..r);lastR=r
 -- Bowl apron (.330,.033)-(.372,.051), track to (.400,.063), number ring Z=.030 (ball radius .015).
 local surface=r>=.372 and .051+(r-.372)/.028*.012 or r>=.33 and .033+(r-.33)/.042*.018 or r>=.292 and .030 or nil
 if surface then assert(z>=surface+.015*.92-1e-9,('ball sinks into the bowl at r=%.3f z=%.3f'):format(r,z)) end
end
-- Landed (t>.76): the ball sits in its pocket and turns with the rotor.
clock=clock+300;local landed=E.pieceTargets(roulette)
assert(math.abs(radius(landed)-.27)<1e-9)
local pocketAngle=(spin.ballTo-spin.wheelTo)%360
assert(math.abs(((ballAngle(landed)+landed['roulette-wheel'].piece.yaw-pocketAngle)+180)%360-180)<1e-6,'ball rides its pocket')
clock=clock+1601;local settled,settledHold=E.pieceTargets(roulette);assert(settledHold==math.huge,'a landed ball holds')
assert(math.abs(settled['roulette-wheel'].piece.yaw+spin.wheelTo)<1e-8)
assert(math.abs(settled['roulette-ball'].position.x-.27*math.sin(math.rad(spin.ballTo)))<1e-8)
-- Different local arrival times produce the same state at the same server time.
local joined={id=104,kind='roulette',position=roulette.position,players=roulette.players,game=roulette.game,serverNow=now+8002}
E.observe(joined);local observed=E.pieceTargets(joined)
assert(math.abs(observed['roulette-ball'].position.x-settled['roulette-ball'].position.x)<1e-8)
roulette.game=assert(R.act(roulette.game,'white','settle',{nowMs=now+8001}))
roulette.game=assert(R.act(roulette.game,'white','nextRound',{}))
local retained=E.pieceTargets(roulette)
assert(math.abs(retained['roulette-wheel'].piece.yaw+spin.wheelTo)<1e-8,'wheel angle survives the next betting round')
-- The wheel spinning closes the bets: no marks.
local spinning={};for k,v in pairs(roulette.game) do spinning[k]=v end;spinning.phase='spinning'
roulette.game=spinning;roulette.revision=9;events['lightrp:boardGames:state']({boards={roulette}})
waitUntil(function() return marks()==0 end,'no marks while the wheel spins')
escape();assert(not C.isActive() and not focus and not camera and E.selection(roulette)==nil,'leaving clears the selection')
handlers.onClientResourceStop('test');for i=1,20 do step()end
assert(next(nativeProps)==nil and next(batches)==nil)
print('extra tabletop client: native props, game view, roulette layout picking, roulette clock/outcome, cleanup: OK; peak '..peakInstructions)
''')
