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
assert(C.isActive() and view.extra.kind=='roulette' and findProp('roulette_table') and findProp('roulette_wheel') and findProp('roulette_ball'))
local before=#requests
pageHandlers['lightrp:tabletop:action']({operation='bet',data={bet='red',amount=25}})
assert(#requests==before+1 and last().action=='game' and last().operation=='bet' and last().data.amount==25)
-- A mouse click cannot silently wager any RP money.
pageHandlers['lightrp:boardGames:pointer']({x=.5,y=.5,pressed=true})
pageHandlers['lightrp:boardGames:pointer']({x=.5,y=.5,released=true});step()
assert(#requests==before+1)
-- Free mode: a panel-only table opens its betting panel on a click, never wagers.
assert(view.free and not view.panel and not focus)
keys.mouse1=true;step();keys.mouse1=false;step()
assert(view.panel and focus and #requests==before+1,'a click opens the betting panel')
pageHandlers['lightrp:boardGames:panel']({open=false});assert(not view.panel and not focus)
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
pageHandlers['lightrp:boardGames:leave']({});assert(not C.isActive())
handlers.onClientResourceStop('test');for i=1,20 do step()end
assert(next(nativeProps)==nil and next(batches)==nil and cinematic~=true)
print('extra tabletop client: native props, roulette clock/outcome, cleanup: OK; peak '..peakInstructions)
''')
