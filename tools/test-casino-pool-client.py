#!/usr/bin/env python3
"""Pool native-prop adapter on the real board-game client, SDK mocks and strict budgets.

Reuses the mock host of tools/test-board-games-client.py (per-resume instruction
hook at BOARD_BUDGET, one native spawn per resume). Proves: every prop exists in
the cooked package; the balls follow the server's segments analytically at the
projected server time (a late client agrees); the cue turns about the cue ball
with the crosshair, draws back while the button is held and the release sends
the shot (ALT cancels it); ball in hand follows the crosshair and a click
places it; pocketed balls drop then line up in the ball return; the worst
frame stays inside the budget.
"""
from pathlib import Path
import json, math
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'tools/test-board-games-client.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
lua = namespace['lua']
assets = json.loads((ROOT/'resources/assets/models/open77_casino_pool/asset-manifest.json').read_text())
lua.globals().availableModels = lua.table_from({m['name']: True for m in assets['models'] + assets.get('colliders', [])})
lua.execute(r'''
LightRpBoardGames={};LightRpItems={}
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\casino_pool\\',1,true)==1,options.model)
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 if options.model:find('_collider.ent',1,true) then assert(options.scale==1 and options.collision==true and options.physics=='static')
 else assert(options.scale==.65 and options.collision==false and options.physics=='none') end
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local name=options.model:match('([^\\]+)%.ent$')
 assert(availableModels[name],'native asset missing from the cooked package: '..tostring(name))
 nativeProps[id]={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=true,failed=false,backend='raw_entity'}
 createdProps=createdProps+1;return id
end
function countProps() local n=0;for _,p in pairs(nativeProps) do if not p.name:find('_collider$') then n=n+1 end end;return n end
function findProp(name) for id,p in pairs(nativeProps) do if p.name==name then return p,id end end end
-- The crosshair straight down on a point of the cloth (world = table metres here).
function aimCloth(x,y) forcedRay={origin={x=x,y=y,z=3},direction={x=0,y=0,z=-1}} end
''')
for name in ['shared/casino_pool.lua', 'client/core/tabletop_extra.lua', 'client/core/casino_pool.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(), name=name)
lua.execute(r'''
local P,E,C,PC=LightRpPool,LightRpTabletopExtraClient,LightRpBoardGamesClient,LightRpPoolClient
C.bind(page);C.start();step();step()
assert(E.supports('pool') and E.aimable({kind='pool'}))
local K=1/.65
local BALL_Z=(P.BED+P.R)*K
local function near(a,b,tol) return math.abs(a-b)<(tol or 1e-6) end
local now=1700000000000
local g=P.new('duel',3)
local pool={id=301,kind='pool',owned=true,position={x=0,y=0,z=0},rotation=0,players={white=7,black=9},actor=7,ready=true,
 mode='duel',revision=1,serverNow=now,game=g}
events['lightrp:boardGames:state']({boards={pool}});step()
waitUntil(function() return countProps()==1+16+1+1 and findProp('pool_table_collider') end,'table, 16 balls, cue, rack and collider')
assert(C.isActive() and E.seat(pool)=='white')
-- The rack: every ball where the rules put it, on the cloth.
local rack=P.decodePositions(g.pos)
local T=E.pieceTargets(pool)
for i=1,16 do
 local t=T['ball'..(i-1)];assert(t and t.piece.model:find('pool_ball_'..(i-1)..'.ent',1,true) and t.piece.snap)
 assert(near(t.position.x,rack[i][1]*K) and near(t.position.y,rack[i][2]*K) and near(t.position.z,BALL_Z),'ball '..(i-1))
end
assert(T.rack and near(T.rack.position.x,P.FOOT_X*K),'the rack frames the balls before the break')

-- Aiming: the cue turns about the cue ball towards the crosshair.
local cx,cy=rack[1][1],rack[1][2]
aimCloth(.5,.2);for i=1,4 do step() end
local yaw=math.deg(math.atan(.2-cy,.5-cx))
T=E.pieceTargets(pool)
assert(near(T.cue.piece.yaw,yaw,1e-6),'cue yaw '..T.cue.piece.yaw..' vs '..yaw)
local cue=findProp('pool_cue')
waitUntil(function() local p=findProp('pool_cue');return near(p.yaw,yaw,1e-6) end,'cue prop follows the aim')
local d=math.sqrt((cue.position.x-cx)^2+(cue.position.y-cy)^2)
assert(near(d,P.R+.012,1e-4),'tip just behind the cue ball, '..d)
local guide=batches['boardGames:preview'];assert(guide and #guide.lines>=11,'a guide line and the ghost ball')
local first=guide.lines[1];assert(near(first.a.x,cx,1e-6) and near(first.a.y,cy,1e-6),'the guide starts at the cue ball')
-- Charging draws the cue back; the release sends the shot with the aim and the power.
local before=#requests
keys.mouse1=true;step()
for i=1,10 do step() end
local pulled=findProp('pool_cue');local back=math.sqrt((pulled.position.x-cx)^2+(pulled.position.y-cy)^2)
assert(back>P.R+.012+.05,'the cue draws back while charging: '..back)
keys.mouse1=false;step()
assert(#requests==before+1 and last().action=='game' and last().operation=='shoot' and last().revision==1)
local sent=last().data
assert(near(sent.yaw,math.floor(yaw*100+.5)/100,1e-9) and sent.power>.2 and sent.power<=1,'yaw '..sent.yaw..' power '..sent.power)
-- No second shot while that one is on its way.
keys.mouse1=true;step();keys.mouse1=false;step();assert(#requests==before+1,'one request per revision')
-- ALT during a charge cancels it (a release while ALT borrows the button).
pool.revision=2;events['lightrp:boardGames:state']({boards={pool}});step()
keys.mouse1=true;step();step();keys.ALT=true;step();keys.mouse1=false;step();keys.ALT=false;step()
assert(#requests==before+1,'ALT cancelled the charge: no shot')

-- The shot: balls follow the segments at the projected server time.
local n=assert(P.shoot(g,'white',{yaw=sent.yaw,power=1,nowMs=now}))
pool.game=n;pool.revision=3;pool.serverNow=now;pool.actor=nil
events['lightrp:boardGames:state']({boards={pool}});step()
local at=n.shot.at
local function expected(i,ts)
 local s=n.shot.segs[i];local recs=P.records(s)
 local b=P.decodePositions(n.pos)
 if recs==0 then return b[i] and b[i][1],b[i] and b[i][2] end
 local tau=(ts-at)/1000;local k=1
 for j=1,recs do if P.record(s,j)<=tau then k=j end end
 local t0,x0,y0,vx,vy=P.record(s,k)
 return P.motion(x0,y0,vx,vy,tau-t0)
end
local drops={};for _,dd in ipairs(P.decodeDrops(n.shot.drops)) do drops[dd.ball]=dd end
local base=E.serverTime(pool)
for _,ms in ipairs({0,120,400,900,1500,2500}) do
 clock=clock+((at+ms)-E.serverTime(pool))
 T=E.pieceTargets(pool)
 for i=1,16 do
  local dd=drops[i]
  if not dd or (at+ms)/1 < at+dd.t*1000 then
   local x,y=expected(i,at+ms)
   assert(near(T['ball'..(i-1)].position.x,x*K,1e-9) and near(T['ball'..(i-1)].position.y,y*K,1e-9),('ball %d at +%d ms'):format(i-1,ms))
  end
 end
end
assert(not T.rack,'the rack is gone once the break is played')
-- A client that receives the same snapshot later agrees at one server time.
local late={id=302,kind='pool',position=pool.position,rotation=0,players=pool.players,game=n,serverNow=at+900,revision=3}
E.observe(late);local L=E.pieceTargets(late)
clock=clock+((at+900)-E.serverTime(pool));T=E.pieceTargets(pool)
for i=1,16 do assert(near(L['ball'..(i-1)].position.x,T['ball'..(i-1)].position.x,1e-9) and near(L['ball'..(i-1)].position.y,T['ball'..(i-1)].position.y,1e-9),'late client ball '..(i-1)) end
-- A re-anchored clock that runs a little back never moves the balls backwards.
pool.serverNow=at+800;pool.revision=31;E.observe(pool)
local back=E.pieceTargets(pool)
for i=1,16 do assert(near(back['ball'..(i-1)].position.x,T['ball'..(i-1)].position.x,1e-9),'no step back: ball '..(i-1)) end
-- Pocketed balls drop into their pocket, then line up in the ball return.
for i,dd in pairs(drops) do
 clock=clock+((at+dd.t*1000+P.DROP/2)-E.serverTime(pool));T=E.pieceTargets(pool)
 assert(T['ball'..(i-1)].position.z<BALL_Z-.01,'ball '..(i-1)..' sinks')
end
-- After the shot: rest positions from the state, the cue waits for the next shooter.
clock=clock+((P.endsAt(n)+50)-E.serverTime(pool))
T=E.pieceTargets(pool)
local rest=P.decodePositions(n.pos)
for i=1,16 do
 local t=T['ball'..(i-1)].position
 if rest[i] then assert(near(t.x,rest[i][1]*K,1e-9) and near(t.y,rest[i][2]*K,1e-9) and near(t.z,BALL_Z),'rest '..(i-1))
 elseif i>1 and n.potted:find(P.ballChar(i),1,true) then
  local k=n.potted:find(P.ballChar(i),1,true)
  assert(near(t.x,P.TRAY.x*K,1e-9) and near(t.y,(P.TRAY.y0+(k-1)*P.TRAY.step)*K,1e-9),'ball '..(i-1)..' in the return')
 end
end
waitUntil(function()
 for i=1,16 do local b=rest[i];if b then local p=findProp('pool_ball_'..(i-1));if not near(p.position.x,b[1],1e-6) then return false end end end
 return true end,'props at rest where the server stopped them')
print('shot: '..P.records(table.concat({n.shot.segs[1]}))..' cue ball segments, '..#P.decodeDrops(n.shot.drops)..' pocketed, rest positions matched')

-- The opponent's shot: no aiming, the cue rests behind the cue ball, a click only explains.
n.shot.at=now-100000;pool.game=n;pool.actor=9;pool.revision=4;pool.serverNow=now;events['lightrp:boardGames:state']({boards={pool}});step()
if n.turn~='white' or n.inHand then
 before=#requests;local hints=#notices
 keys.mouse1=true;step();keys.mouse1=false;step()
 assert(#requests==before and lastNotice=="It is your opponent's shot.",'no request out of turn: '..tostring(lastNotice))
end

-- Ball in hand: the cue ball follows the crosshair on a free spot; a click places it.
local hand=P.copy(n);hand.inHand='table';hand.turn='white';hand.status='playing'
local balls=P.decodePositions(hand.pos);balls[1]=false;hand.pos=P.encodePositions(balls)
hand.shot.at=now-100000
pool.game=hand;pool.actor=7;pool.revision=5;pool.serverNow=now;events['lightrp:boardGames:state']({boards={pool}});step()
-- A free spot: the head of the table away from every ball.
local fx,fy=-1.0,-.45
for i=2,16 do local b=balls[i];if b then assert((b[1]-fx)^2+(b[2]-fy)^2>(2*P.R)^2,'test spot is free') end end
aimCloth(fx,fy);for i=1,3 do step() end
T=E.pieceTargets(pool)
assert(near(T.ball0.position.x,fx*K,1e-9) and near(T.ball0.position.y,fy*K,1e-9),'the cue ball follows the crosshair')
assert(near(T.cue.position.z,P.PARK.z*K) and near(T.cue.position.x,P.PARK.cueX*K),'no cue while placing: parked in the spine')
before=#requests;click()
assert(#requests==before+1 and last().operation=='place' and last().data.x==math.floor(fx*P.UNIT+.5) and last().data.y==math.floor(fy*P.UNIT+.5))
-- On another ball, the click is refused locally with a hint.
local ob;for i=2,16 do if balls[i] then ob=balls[i];break end end
pool.revision=6;events['lightrp:boardGames:state']({boards={pool}});step()
aimCloth(ob[1],ob[2]);for i=1,3 do step() end
clock=clock+5000 -- hints are rate limited (4 s)
before=#requests;click();assert(#requests==before and lastNotice and lastNotice:find('in the way',1,true),'a ball in the way: '..tostring(lastNotice))

-- Budget: the worst frame (every ball moving, a late join from the first segment).
local probe={id=399,kind='pool',position=pool.position,rotation=0,players=pool.players,game=n,serverNow=at+40,revision=3}
local function measure(fn) local c=0;debug.sethook(function() c=c+1 end,'',1);fn();debug.sethook();return c end
E.observe(probe)
local cold=measure(function() E.pieceTargets(probe) end)
probe.serverNow=at+2500;E.observe(probe)
local jump=measure(function() E.pieceTargets(probe) end)
local warm=measure(function() E.pieceTargets(probe) end)
assert(cold<5000 and jump<5000 and warm<4000,'pieceTargets cost cold '..cold..' jump '..jump..' warm '..warm)
print(('pieceTargets: %d instructions cold, %d after a 2.5 s jump, %d per animated frame'):format(cold,jump,warm))
C.leave('test');assert(not C.isActive())
handlers.onClientResourceStop('test');for i=1,20 do step() end
assert(next(nativeProps)==nil)
assert(peakInstructions<5000,'peak '..peakInstructions)
print('pool client: cooked props, analytic shot playback, late join, drops and ball return, aim/charge/shoot, ALT cancel, ball in hand: OK; peak '..peakInstructions..' (budget '..BOARD_BUDGET..')')
''')
