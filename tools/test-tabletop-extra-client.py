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
lua.globals().availableModels=lua.table_from({model['name']: True for model in assets['models']})
lua.execute(r'''
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\tabletop_extra\\',1,true)==1)
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop' and options.scale==.65)
 assert(options.collision==false and options.physics=='none')
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
 local count=0;for _ in pairs(nativeProps)do count=count+1 end;return count
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
assert(math.abs(math.sqrt(b['roulette-ball'].position.x^2+b['roulette-ball'].position.y^2)-.27)<1e-9)
clock=clock+4001;local settled,settledHold=E.pieceTargets(roulette);assert(settledHold==math.huge,'a landed ball holds')
local spin=roulette.game.spin
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
