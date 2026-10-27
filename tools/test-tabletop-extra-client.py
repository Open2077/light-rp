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
assert(E.supports('roulette') and E.supports('dominoes') and E.supports('cardtower') and not E.supports('chess'))
local now=1700000000000
local roulette={id=101,kind='roulette',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=7,black=9},actor=7,ready=true,mode='duel',revision=1,serverNow=now,game=assert(R.new('roulette','duel',17))}
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
roulette.game=assert(R.act(roulette.game,'white','spin',{outcome=17,seedAngle=41,nowMs=now}))
roulette.revision=2;roulette.serverNow=now+1
E.observe(roulette)
local a=E.pieceTargets(roulette);clock=clock+4000;local b=E.pieceTargets(roulette)
assert(a['roulette-wheel'].piece.yaw~=b['roulette-wheel'].piece.yaw)
assert(math.abs(math.sqrt(b['roulette-ball'].position.x^2+b['roulette-ball'].position.y^2)-.27)<1e-9)
clock=clock+4001;local settled=E.pieceTargets(roulette)
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
-- Domino hands come from the redacted server view, never from another hand.
local dominoState=assert(R.new('dominoes','duel',37));local ownSeat=dominoState.seatTurn
local players={white=9,black=9};players[ownSeat]=7
local domino={id=102,kind='dominoes',owned=true,position={x=0,y=0,z=0},rotation=0,
 players=players,actor=7,ready=true,mode='duel',revision=1,serverNow=now+9000,game=R.view(dominoState,ownSeat)}
events['lightrp:boardGames:state']({boards={domino}});step()
waitUntil(function()return countProps()==8 end,'domino board and own seven tiles')
assert(findProp('dominos_board') and #view.extra.hand==7)
local hand=domino.game.hand;local targets=E.pieceTargets(domino);local first=hand[1]
assert(targets['domino-'..first.id].piece.inHand)
local count=0;for _ in pairs(targets)do count=count+1 end;assert(count==7,'opponent hand tiles must not be rendered')
local pointer=pageHandlers['lightrp:boardGames:pointer']
-- Select one visible hand tile, then choose the right chain end.
local hx=targets['domino-'..first.id].position.x
local hy=targets['domino-'..first.id].position.y
local cursorX,cursorY=hx+.5,hy+.5
before=#requests
pointer({x=cursorX,y=cursorY,pressed=true});pointer({x=cursorX,y=cursorY,released=true});step()
assert(#requests==before and E.view(domino).selectedTile==first.id)
pointer({x=.7,y=.5,pressed=true});pointer({x=.7,y=.5,released=true});step()
assert(last().operation=='play' and last().data.tileId==first.id and last().data['end']=='right')
local played=assert(R.act(dominoState,ownSeat,'play',{tileId=first.id,['end']='right'}))
local visible=R.view(played,ownSeat)
local oldPiece=targets['domino-'..first.id]
domino.game=visible;domino.revision=2;local newTargets=E.pieceTargets(domino)
assert(newTargets['domino-'..first.id] and not newTargets['domino-'..first.id].piece.inHand)
assert(oldPiece.piece.model==newTargets['domino-'..first.id].piece.model,'playing a tile retains its native model identity')
domino.actor=9;before=#requests
pageHandlers['lightrp:tabletop:action']({operation='draw',data={}});assert(#requests==before,'wrong actor cannot play for the team')
pageHandlers['lightrp:boardGames:leave']({})
-- Cards use authored leaning templates, not undocumented prop rotations.
local towerState=assert(R.new('cardtower','duel',5))
towerState=assert(R.act(towerState,'white','place',{x=0,y=0,level=0,yaw=0,orientation='frame',nowMs=now+10000}))
local tower={id=103,kind='cardtower',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=9,black=7},actor=9,ready=true,mode='duel',revision=1,serverNow=now+10000,game=towerState}
events['lightrp:boardGames:state']({boards={tower}});step()
waitUntil(function()return countProps()==3 end,'native card table and A-frame')
assert(findProp('cardtower_board') and findProp('playing_card_lean_left') and findProp('playing_card_lean_right'))
pageHandlers['lightrp:tabletop:action']({operation='configure',data={level=1,yaw=90,orientation='flat'}})
before=#requests
pointer({x=.65,y=.6,pressed=true});pointer({x=.65,y=.6,released=true});step()
assert(#requests==before+1 and last().operation=='place' and last().data.level==1 and last().data.yaw==90 and last().data.orientation=='flat','cooperative black player must place cards even when actor points at white')
-- Unsupported crossing frames collapse from the server's saved motion state.
local collapseTime=now+11000
tower.game=assert(R.act(towerState,'black','place',{x=0,y=0,level=0,yaw=0,orientation='frame',nowMs=collapseTime}))
assert(tower.game.status=='collapsed')
tower.serverNow=collapseTime;tower.revision=2;tower.actor=0;E.observe(tower)
local upright=E.pieceTargets(tower);clock=clock+350;local falling=E.pieceTargets(tower)
local any=false
for id,p in pairs(falling)do
 if p.piece.model:find('_fall_',1,true) then any=true;assert(p.piece.model~=upright[id].piece.model)end
 assert(p.position.z>=.001)
end
assert(any,'collapse must choose a pre-authored falling angle')
clock=clock+1000;local fallen=E.pieceTargets(tower)
for _,p in pairs(fallen)do assert(p.piece.model:find('_fall_5',1,true))end
pageHandlers['lightrp:tabletop:action']({operation='place',data={x=0,y=0}})
assert(#requests==before+1,'collapsed board or AI actor must reject more placement input')
handlers.onClientResourceStop('test');for i=1,20 do step()end
assert(next(nativeProps)==nil and next(batches)==nil and cinematic==false)
print('extra tabletop client: native props, roulette clock/outcome, redacted domino hand/actions, card placement/collapse, cleanup: OK; peak '..peakInstructions)
''')
