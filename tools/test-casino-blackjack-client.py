#!/usr/bin/env python3
"""Blackjack native-prop adapter on the real board-game client, SDK mocks and strict budgets.

Reuses the mock host of tools/test-board-games-client.py (per-resume instruction
hook at BOARD_BUDGET, one native spawn per resume). Proves: the props exist in
the cooked package, the deal timeline follows the server clock, cards flip
through authored poses, the hole card is a back until revealed, chips move to
the rack / pay out, and a worst-case table stays inside the budget.
"""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'tools/test-board-games-client.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
lua = namespace['lua']
assets=json.loads((ROOT/'resources/assets/models/open77_casino_blackjack/asset-manifest.json').read_text())
lua.globals().availableModels=lua.table_from({model['name']: True for model in assets['models'] + assets.get('colliders', [])})
lua.execute(r'''
LightRpBoardGames={};LightRpItems={}
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:find('open77\\assets\\op77_lightrp\\casino_blackjack\\',1,true)==1,options.model)
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
function countProps() local n=0;for _,p in pairs(nativeProps) do if not p.name:find('_collider$') then n=n+1 end end;return n end
function countNamed(pattern) local n=0;for _,p in pairs(nativeProps) do if p.name:find(pattern) then n=n+1 end end;return n end
function findProp(name) for id,p in pairs(nativeProps) do if p.name==name then return p,id end end end
''')
for name in ['shared/casino_blackjack.lua', 'shared/tabletop_extra_rules.lua', 'client/core/tabletop_extra.lua',
             'client/core/casino_blackjack.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(), name=name)
lua.execute(r'''
local B,E,C=LightRpBlackjack,LightRpTabletopExtraClient,LightRpBoardGamesClient
C.bind(page);C.start();step();step()
assert(E.supports('blackjack') and E.supports('roulette'))
local real=B.shuffle
local function stack(list) B.shuffle=function() local s={} for i,v in ipairs(list) do s[i]=v end for i=#list+1,312 do s[i]='2C' end return s end end
local now=1700000000000
local function act(s,seat,a,p) p=p or {};p.nowMs=p.nowMs or now;return assert(B.act(s,seat,a,p)) end
-- white T,K=20 (me) ; black 9,7=16 ; dealer 6 up, Q hole -> draws 3H = 19
stack({'TS','9D','6D','KH','7C','QH','3H'})
local s=B.new('duel',1,now)
s=act(s,'white','bet',{amount=125,inventory='me'});s=act(s,'black','bet',{amount=30,inventory='other'})
local bj={id=201,kind='blackjack',owned=true,position={x=0,y=0,z=0},rotation=0,
 players={white=7,black=9},actor=nil,ready=true,mode='duel',revision=1,serverNow=now,game=B.view(s)}
events['lightrp:boardGames:state']({boards={bj}});step()
waitUntil(function() return findProp('blackjack_table') and countNamed('^bj_chips_')==4 end,'table and both bet stacks')
assert(C.isActive() and E.seat(bj)=='white' and bj.game.hands.white.bet==125)
assert(findProp('bj_chips_100_1') and findProp('bj_chips_25_1') and findProp('bj_chips_25_1'),'125 = 100 + 25 stacks')
-- The game view opens behind the local player's seat (white: 54 degrees).
assert(focus and camera and frozen and view.view=='seat' and #view.views==5 and view.views[5].key=='free' and cameraSpec.lookAt)
assert(math.abs(cameraSpec.position.x-1.65*math.sin(math.rad(54))*.65)<1e-6 and cameraSpec.position.y<0,'the seat camera stands behind white')
-- Bets open: my betting circle is marked (a faint ring of 12 lines).
waitUntil(function() return marks()==12 end,'my betting circle marked')
-- Bar operations (tools/test-table-menu.py) reach the server; a click never wagers.
local before=#requests
assert(E.command(bj,'bet',{amount=25}))
assert(#requests==before+1 and last().action=='game' and last().operation=='bet' and last().data.amount==25)
assert(not E.command(bj,'splitAll',{}) and #requests==before+1,'unknown operation forwarded')
-- A click on the player's betting circle selects it (outlined); elsewhere, nothing.
local a=math.rad(54)
local function at(x,y) forcedRay={origin={x=x*.65,y=y*.65,z=3},direction={x=0,y=0,z=-1}};pointer({x=.5,y=.6});step() end
at(.80*math.sin(-a),-.80*math.cos(a));pointer({x=.5,y=.6,pressed=true});step();pointer({x=.5,y=.6,released=true});step()
assert(E.selection(bj)==nil and #requests==before+1,'another seat\'s circle is not mine')
at(.80*math.sin(a),-.80*math.cos(a));step();assert(#batches['boardGames:preview'].lines==12,'the hovered circle is outlined')
pointer({x=.5,y=.6,pressed=true});step();pointer({x=.5,y=.6,released=true});step()
assert(E.selection(bj) and E.selection(bj).key=='circle' and #requests==before+1,'a click selects my circle and wagers nothing')
forcedRay=nil

-- The deal: server timestamps drive every card; staggered from the shoe.
now=now+1000 -- a new snapshot stamp: the client re-anchors its server clock
s=act(s,'white','deal',{inventory='me',seed=1});local t0=s.dealtAt
assert(s._hole=='QH' and t0==now)
bj.game=B.view(s);bj.revision=2;bj.serverNow=now;E.observe(bj)
local T=E.pieceTargets(bj)
local first=T['bj-white-c1'];assert(first.piece.model:find('bj_card_back',1,true) and first.piece.snap)
assert(math.abs(first.position.x-.70)<1e-9 and math.abs(first.position.y+.15)<1e-9,'first card leaves the shoe mouth')
assert(T['bj-d-c2'].piece.model:find('bj_card_back',1,true),'hole card waits in the shoe')
local hole=T['bj-d-c2'].position;assert(math.abs(hole.x-.70)<1e-9 and math.abs(hole.y-.03)<1e-9,'undealt cards hide inside the shoe')
clock=clock+B.SLIDE/2;T=E.pieceTargets(bj)
local mid=T['bj-white-c1'].position;assert(mid.x<.70 and mid.x>.0 and mid.z>1.35+.02,'card slides and arcs')
clock=clock+B.SLIDE/2+10;T=E.pieceTargets(bj)
assert(T['bj-white-c1'].piece.model:find('bj_card_turn',1,true),'flip passes through the half-turned pose')
clock=clock+B.FLIP;T=E.pieceTargets(bj)
assert(T['bj-white-c1'].piece.model:find('bj_card_ts',1,true),'face-up after the flip')
local slot=T['bj-white-c1'];assert(math.abs(slot.piece.yaw-54)<1e-9 and math.abs(slot.position.z-(1.35+.001))<1e-9)
-- Clients that received the snapshot at different times agree at one server time.
local late={id=202,kind='blackjack',position=bj.position,players=bj.players,game=bj.game,serverNow=now+B.SLIDE+B.FLIP+10}
E.observe(late);local L=E.pieceTargets(late)
assert(L['bj-white-c1'].piece.model==T['bj-white-c1'].piece.model and math.abs(L['bj-white-c1'].position.x-T['bj-white-c1'].position.x)<1e-9)
-- The deal on the real renderer: every card becomes a native prop.
waitUntil(function() clock=math.max(clock,0);return countNamed('^bj_card_')==6 end,'six dealt cards as native props')
local settled=t0+5*B.DEAL_GAP+B.SLIDE+B.FLIP
-- The cards have settled but the dealer still pauses: no decision yet.
bj.serverNow=settled;bj.revision=3;events['lightrp:boardGames:state']({boards={bj}})
waitUntil(function() local t=E.serverTime(bj);return t>=settled and t<s.actAt end,'pause after the deal')
assert(marks()==0,'no betting circle once the cards are dealt')
local legal=B.legal(bj.game,'white',E.serverTime(bj))
assert(not legal.stand and not legal.hit,'no decision during the pause after the deal')
local deadline=s.actAt
bj.serverNow=deadline;bj.revision=31;events['lightrp:boardGames:state']({boards={bj}})
waitUntil(function() return findProp('bj_card_kh') and findProp('bj_card_6d') and findProp('bj_card_7c') end,'face-up native cards')
assert(not findProp('bj_card_qh') and findProp('bj_card_back'),'the hole card stays a generic back')
legal=B.legal(bj.game,'white',E.serverTime(bj))
assert(bj.game.dealer.cards[2].c==nil and legal.stand and legal.hit and legal.double)
before=#requests;assert(E.command(bj,'stand',{}) and last().operation=='stand' and #requests==before+1)

-- Stand, black stands: the dealer reveals the hole card and draws on the server clock.
s=act(s,'white','stand',{inventory='me',nowMs=deadline});s=act(s,'black','stand',{inventory='other',nowMs=deadline})
assert(s.phase=='result' and s.dealer.total==19 and s.hands.white.result=='win' and s.hands.black.result=='lose')
bj.game=B.view(s);bj.revision=4;bj.serverNow=deadline;events['lightrp:boardGames:state']({boards={bj}})
local reveal=s.dealer.cards[2].f
waitUntil(function() return findProp('bj_card_qh') end,'hole card flips face-up')
waitUntil(function() return findProp('bj_card_3h') end,'dealer draw')
-- Chips: the losing stack slides to the dealer rack and vanishes; the winner is paid beside the bet.
waitUntil(function() return countNamed('^bj_chips_100_1$')==2 end,'winnings stack slides out beside the bet')
assert(E.serverTime(bj)>=s.resultAt+B.CHIP_STAGGER,'no payout before the reveal ends')
T=E.pieceTargets(bj)
assert(T['bj-white-w1'] and T['bj-white-w1'].piece.model:find('bj_chips_100_1',1,true),'125 winnings beside the bet')
clock=clock+(s.resultAt+4*B.CHIP_STAGGER+B.CHIPS)-E.serverTime(bj);T=E.pieceTargets(bj)
assert(not T['bj-black-b1'],'lost chips are gone into the rack')
local w=T['bj-white-w1'].position;assert(math.abs(w.z-(1.35+.0005))<1e-9,'chips rest just off the felt')
-- Before the next round the cards sweep into the discard tray.
clock=clock+(s.nextAt-B.SWEEP+300)-E.serverTime(bj);T=E.pieceTargets(bj)
local sweeping=T['bj-white-c1'].position;assert(sweeping.x<0,'cards travel to the discard tray at -X')
clock=clock+(s.nextAt-50)-E.serverTime(bj);T=E.pieceTargets(bj);assert(not T['bj-white-c1'] and not T['bj-d-c1'] and not T['bj-white-w1'] and not T['bj-black-c1'],'the sweep ends inside B.SWEEP')
waitUntil(function() return countNamed('^bj_')==0 end,'felt cleared before the next round')

-- Worst case: four 7-card hands with bet and payout stacks plus a 7-card dealer, animating.
local function hand(seat,stake)
 local cards={};for k=1,7 do cards[k]={c=({'2S','3H','4D','5C','6S','7H','8D'})[k],t=now+k*100} end
 return {bet=stake,stake=stake,cards=cards,total=35,done=true,result='win',payout=stake*2,betAt=now}
end
local worst=B.view(B.new('duel',1,now));worst.phase='result';worst.resultAt=now+5000;worst.nextAt=now+12000
worst.hands={white=hand('white',3125),black=hand('black',3125),white2=hand('white2',3125),black2=hand('black2',3125)}
for _,h in pairs(worst.hands) do h.total=20 end
worst.dealer={cards={},total=22};for k=1,7 do worst.dealer.cards[k]={c='9C',t=now+k*300} end

-- Stacking: overlapping cards never share a height (two surfaces at one depth
-- z-fight in game). Each card lies a card thickness plus a gap above the
-- previous one of its hand; the landed x/y are the table's layout.
local CARD_T,STEP=.0016,.0016+.0008
local function settle(id,serverNow,game)
 local b={id=id,kind='blackjack',position=bj.position,players=bj.players,game=game,serverNow=serverNow};E.observe(b)
 local R;for _=1,10 do R=E.pieceTargets(b) end;return R
end
local S=settle(298,worst.resultAt-100,worst)
for _,seat in ipairs({'d','white','black','white2','black2'}) do
 for k=2,7 do
  local a,b=S['bj-'..seat..'-c'..(k-1)],S['bj-'..seat..'-c'..k];assert(a and b,seat..k)
  assert(b.position.z-a.position.z>=STEP-1e-9,'card '..k..' of '..seat..' lies above card '..(k-1))
 end
 assert(math.abs(S['bj-'..seat..'-c1'].position.z-(1.35+.001))<1e-9,'the first card of a hand just off the felt')
end
for seat,deg in pairs({white=54,black=18,white2=-18,black2=-54}) do
 local a=math.rad(deg);local ux,uy,tx,ty=math.sin(a),-math.cos(a),math.cos(a),math.sin(a)
 for k=1,7 do local r,p=.55-(k-1)*.012,S['bj-'..seat..'-c'..k].position
  assert(math.abs(p.x-(r*ux+(k-1)*.032*tx))<1e-9 and math.abs(p.y-(r*uy+(k-1)*.032*ty))<1e-9,'landed x/y unchanged') end
end
for k=1,7 do local p=S['bj-d-c'..k].position;assert(math.abs(p.x-(-.07+(k-1)*.075))<1e-9 and math.abs(p.y+.24)<1e-9,'dealer row unchanged') end
for _,seat in ipairs(B.SEATS) do assert(math.abs(S['bj-'..seat..'-b1'].position.z-(1.35+.0005))<1e-9) end
-- In flight a card stays above the felt and above the cards it lands on, and
-- the half-turned pose stands at its own (stacked) height.
local single=B.view(B.new('duel',1,now));single.phase='playing'
single.hands={white={bet=25,stake=25,total=20,betAt=now,cards={}}};single.dealer={cards={},total=0}
for k=1,4 do single.hands.white.cards[k]={c='5S',t=now+k*1000} end
local slot3=S['bj-white-c3'].position
for i,p in ipairs({.02,.1,.3,.5,.7,.9,.98}) do
 local F=settle(280+i,now+3000+math.floor(B.SLIDE*p),single)
 local c3,c2=F['bj-white-c3'],F['bj-white-c2']
 assert(c3.piece.model:find('bj_card_back',1,true) and c3.position.z>=slot3.z-1e-9 and c3.position.z>c2.position.z+CARD_T,'card 3 in flight over card 2 at '..p)
 assert(c3.position.z>1.35+CARD_T)
end
local F=settle(288,now+3000+B.SLIDE+10,single)
assert(F['bj-white-c3'].piece.model:find('bj_card_turn',1,true) and math.abs(F['bj-white-c3'].position.z-slot3.z)<1e-9,'flip pose at the stacked height')
-- The sweep: every swept card heads for its own layer of the tray, later seats above.
local sweepAt=worst.nextAt-B.SWEEP
local W=settle(289,sweepAt+3*250+100,worst)
local heights,order={},{}
for _,seat in ipairs({'d','white','black','white2','black2'}) do
 for k=1,7 do local c=W['bj-'..seat..'-c'..k]
  if c and math.abs(c.position.x+.70)<1e-9 then assert(not c.piece.snap);order[#order+1]=c.position.z
   assert(not heights[c.position.z],'two swept cards share a height');heights[c.position.z]=true end
 end
end
assert(#order>=14,'cards of several seats in the tray at once '..#order)
for i=2,#order do assert(order[i]>order[i-1],'later collected cards land higher') end
-- The bet and the winnings leave over the rail side by side, never into one spot.
local bet,win=W['bj-black2-b1'],W['bj-black2-w1'];assert(bet and win)
assert(math.sqrt((bet.position.x-win.position.x)^2+(bet.position.y-win.position.y)^2)>.06+.06,'swept bet and winnings apart')
bj.game=worst;bj.revision=5;bj.serverNow=worst.resultAt+4*B.CHIP_STAGGER+100; -- every payout stack in flight
events['lightrp:boardGames:state']({boards={bj}})
-- Count on a separate board id so the renderer below starts from a cold cache.
local probe={id=299,kind='blackjack',position=bj.position,players=bj.players,game=worst,serverNow=bj.serverNow}
local function measure(fn) local n=0;debug.sethook(function() n=n+1 end,'',1);fn();debug.sethook();return n end
local targets,first=0,0
-- A cold table is built over consecutive ticks (bounded rebuild per call).
local cold=measure(function() for _ in pairs(E.pieceTargets(probe)) do first=first+1 end end)
local second=measure(function() E.pieceTargets(probe) end)
-- The number of calls a cold build needs depends on pairs() order: call until
-- the count stops growing (each call stays bounded, measured below).
for _=1,10 do
 local n=0;for _ in pairs(E.pieceTargets(probe)) do n=n+1 end
 if n==targets then break end;targets=n
end
local warm=measure(function() E.pieceTargets(probe) end)
assert(first>0 and first<targets and targets==4*7+7+4*3+4*3,'worst case target count '..first..'/'..targets)
assert(cold<3500 and second<3500 and warm<2500,'pieceTargets cost cold '..cold..'/'..second..' warm '..warm)
print('worst-case pieceTargets: cold '..cold..' + '..second..' instructions (next tick), steady tick '..warm)
waitUntil(function() return countProps()==1+targets end,'every worst-case prop')
-- Payout slides, then the sweep of every card and chip, all inside the budget.
for i=1,120 do step() end
waitUntil(function() return countProps()==1 end,'worst-case felt swept')
print('worst-case props per table: '..(1+targets)..' (table + '..targets..' moving)')
escape();assert(not C.isActive())
handlers.onClientResourceStop('test');for i=1,20 do step() end
assert(next(nativeProps)==nil and next(batches)==nil)
B.shuffle=real
print('blackjack client: native props, server-clock deal, flip poses, hidden hole card, chips, cleanup: OK; peak '..peakInstructions)
''')
