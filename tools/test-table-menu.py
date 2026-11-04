#!/usr/bin/env python3
"""Table management and play controls: the ALT target menu
(client/core/table_menu.lua: status, Sit, the owner's mode / New game, Pick up,
Leave) and the game view's bottom bar (client/core/table_bar.lua: status,
chip, target, buttons per game and state), that every row and button sends the
right request, the notices, and the cost of building a menu or a bar.

Real shared rules, real casino adapters, the real board client and the real
open77_contextmenu row validation (ContextMenuRegistry.dynamicRows), on the
mock host of tools/test-board-games-client.py."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
RES = ROOT/'resources/gamemodes/op77_lightrp'
source = (ROOT/'tools/test-board-games-client.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
exec(source.split("for name in ['shared/board_game_models.lua'")[0], namespace)
lua = namespace['lua']
lua.execute(r'''
LightRpEvents.net={state='state'}
LightRpItems={}
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 nativeProps[id]={id=id,name=options.model:match('([^\\]+)%.ent$'),model=options.model,
  position={x=options.position.x,y=options.position.y,z=options.position.z},yaw=options.yaw,rendered=true,failed=false,backend='raw_entity'}
 createdProps=createdProps+1;return id
end
registered=nil
function Open77.exports.call(resource,name,definition)
 assert(resource=='open77_contextmenu','unexpected export '..tostring(resource))
 if name=='setTargetingEnabled' or name=='close' then return {await=function() return true end} end -- the game view
 assert(name=='register','unexpected export '..tostring(name))
 registered=definition
 return {await=function() return 'token-1' end}
end
''')
for name in ['shared/board_games.lua', 'shared/board_games_rules.lua', 'shared/tabletop_extra.lua', 'shared/tabletop_extra_rules.lua',
             'shared/casino_slots.lua', 'shared/casino_blackjack.lua', 'shared/casino_fortune.lua', 'shared/casino_pool.lua',
             'client/core/tabletop_extra.lua', 'client/core/casino_slots.lua', 'client/core/casino_blackjack.lua',
             'client/core/casino_fortune.lua', 'client/core/casino_pool.lua', 'client/core/board_games.lua', 'client/core/table_menu.lua', 'client/core/table_bar.lua']:
    lua.execute((RES/name).read_text(), name=name)
lua.execute((ROOT/'resources/system/open77_contextmenu/client/registry.lua').read_text(), name='registry.lua')
lua.execute(r'''
local C,E,M,BAR=LightRpBoardGamesClient,LightRpTabletopExtraClient,LightRpTableMenu,LightRpTableBar
local R,S,B,F=LightRpTabletopExtraRules,LightRpCasinoSlots,LightRpBlackjack,LightRpCasinoFortune
C.bind(page);C.start();step();step()
-- One registration, dynamic rows: valid for the real registry, on the props
-- and surfaces of a table, within the 3 m menu reach.
handlers.onClientResourceStart('test');step();step()
assert(registered and registered.id=='tables.menu' and registered.rows=='tableMenuRows' and registered.onSelect=='tableMenuSelect' and registered.distance==3)
local types={};for _,t in ipairs(registered.types) do types[t]=true end
assert(types.prop and types.world and not types.player and not types.vehicle)
assert(ContextMenuRegistry.new(function() return true end).register('op77_lightrp',1,registered),'the definition passes the real registry')
events.state({money={cash=100000}})
local now=1700000000000
local peak=0
local function measured(fn,...)
 local n=0;debug.sethook(function() n=n+1 end,'',1)
 local a,b=fn(...)
 debug.sethook();peak=math.max(peak,n);return a,b
end
local MODELS={chess='chess_board',roulette='roulette_table',slots='slot_cabinet',blackjack='blackjack_table',fortune='fortune_stand',pool='pool_table'}
local function base(board)
 for id,p in pairs(nativeProps) do
  if p.name==MODELS[board.kind] and math.abs(p.position.x-board.position.x)<1e-6 then return id end
 end
end
local function ctx(board,surface)
 if surface then return {target={kind='world',networked=false},position={x=board.position.x+.3,y=board.position.y,z=board.position.z+.5},hasSurface=true,playerDistance=1} end
 return {target={kind='prop',networked=false,propId=assert(base(board),'table base prop')},position=board.position,hasSurface=true,playerDistance=1}
end
-- The menu as the page would receive it: validated by the real registry.
function menu(board,surface)
 invokingResource='open77_contextmenu'
 local answer=measured(exportCallbacks.tableMenuRows,ctx(board,surface))
 invokingResource=nil
 local listed=assert(ContextMenuRegistry.dynamicRows(answer,24),'rows refused by open77_contextmenu')
 local rows={};for i,row in ipairs(listed.rows) do rows[row.key]=row;rows[i]=row end
 rows.title=listed.title;return rows
end
function pick(board,key)
 local c=ctx(board);c.action={key=key}
 invokingResource='open77_contextmenu'
 local ok=measured(exportCallbacks.tableMenuSelect,c)
 invokingResource=nil
 return ok
end
local function keys(rows) local out={};for _,row in ipairs(rows) do out[#out+1]=row.key end;return table.concat(out,',') end
local function show(board) events['lightrp:boardGames:state']({boards={board}});step() end
local function rendered(board) waitUntil(function() return C.isRendered(board) and base(board)~=nil end,board.kind..' rendered') end
local function seatedAt(board) waitUntil(function() return C.seated()==board end,'seated at '..board.kind) end
local id=500
local function fresh(kind,game,extra)
 id=id+1;clock=clock+3100
 local b={id=id,kind=kind,owned=false,position={x=0,y=0,z=0},rotation=0,players={},revision=1,mode='duel',serverNow=now,game=game}
 for k,v in pairs(extra or {}) do b[k]=v end
 return b
end

-- A forged caller, a far player or another dialog gets nothing.
local chess=fresh('chess',LightRPBoardRules.new('chess'),{owned=true})
show(chess);rendered(chess)
assert(#exportCallbacks.tableMenuRows(ctx(chess)).rows==0,'only open77_contextmenu may ask')
Open77.character.state().position.x=4.5;assert(#menu(chess)==0,'out of the table reach');Open77.character.state().position.x=0
LightRpUi.dialogs.inventory=true;assert(#menu(chess)==0,'another dialog is open');LightRpUi.dialogs.inventory=nil

-- The bar as the page receives it (board_games.lua adds the views and Leave).
local barPeak=0
function bar(board)
 local n=0;debug.sethook(function() n=n+1 end,'',1)
 local m=BAR.model(board)
 debug.sethook();barPeak=math.max(barPeak,n)
 local out={model=m}
 for i,a in ipairs(m.actions) do out[a.key]=a;out[i]=a end
 return out
end
local function akeys(b) local out={};for _,a in ipairs(b) do out[#out+1]=a.key..(a.enabled and '' or '-') end;return table.concat(out,',') end
local function act(key) pageHandlers['lightrp:boardGames:action']({key=key}) end
local function chip(amount) pageHandlers['lightrp:boardGames:chip']({amount=amount}) end

-- Chess, standing: the status, Sit (a seat is free), the owner's mode and,
-- within 2 m, Pick up.
local rows=menu(chess)
assert(rows.title=='Chess' and keys(rows)=='status,sit,mode.solo,mode.teams,pickup',keys(rows))
assert(rows.status.label=='New game · 1v1' and rows.sit.label=='Sit' and rows.pickup.label=='Pick up board' and rows['mode.solo'].submenu.label=='Mode: 1v1')
assert(keys(menu(chess,true))==keys(rows),'a click on the surface of the table finds it too')
Open77.character.state().position.x=2.5;assert(keys(menu(chess))=='status,sit,mode.solo,mode.teams','Pick up needs 2 m');Open77.character.state().position.x=0
assert(pick(chess,'sit') and last().action=='join' and last().boardId==chess.id)
assert(pick(chess,'mode.solo') and last().action=='mode' and last().mode=='solo','the owner configures without sitting')
assert(pick(chess,'pickup') and last().action=='pickup' and last().boardId==chess.id)
local count=#requests;assert(not pick(chess,'reset') and #requests==count,'a row the menu does not offer never runs')
chess.owned=false;chess.players={white=9,black=10};show(chess);assert(keys(menu(chess))=='status','a full guest table: the status only')
chess.owned=false;chess.mode='solo';chess.players={};show(chess);assert(keys(menu(chess))=='status','solo is the owner\'s')
-- Seated: the game view. The menu keeps a Leave row (the page holds the cursor,
-- so the menu cannot open there; it is a fallback); play is on the bar.
chess.owned=true;chess.mode='duel';chess.players={white=7,black=9};chess.ready=true;chess.actor=7;chess.revision=2;show(chess);seatedAt(chess)
assert(focus and view.active and view.kind=='chess')
-- Escape leaves (the page holds the keyboard and consumes it); the seating notice says so.
local told=false;for _,n in ipairs(notices) do if n:find('Escape leaves',1,true) and not n:find('Backspace',1,true) then told=true end end
assert(told and keyboard and consumedKeys[1]=='escape','the seating notice names Escape, the page consumes it')
assert(view.views[#view.views].key=='free','the camera cycle ends with the free view')
rows=menu(chess);assert(keys(rows)=='status,leave,mode.solo,mode.teams,pickup' and rows.status.label=='Your turn',keys(rows))
local b=bar(chess)
assert(b.model.status=='Your turn' and b.model.tone=='turn' and b.model.detail=='You play White · 1v1' and akeys(b)=='mode' and b.mode.label=='Mode: 1v1')
act('mode');assert(last().action=='mode' and last().mode=='solo' and last().boardId==chess.id)
-- After the first move: New game instead of the mode; never for a guest.
chess.game=assert(LightRPBoardRules.move(chess.game,7,5,5,5));chess.actor=9;chess.revision=3;show(chess)
b=bar(chess);assert(b.model.status=='Black to move' and akeys(b)=='reset' and b.reset.label=='New game')
count=#requests;act('mode');assert(#requests==count,'the mode locks once the game started')
act('reset');assert(last().action=='reset')
rows=menu(chess);assert(keys(rows)=='status,leave,reset,pickup',keys(rows))
chess.owned=false;chess.revision=4;show(chess);assert(akeys(bar(chess))=='' and keys(menu(chess))=='status,leave')
-- Notices: the turn comes back, the game ends.
chess.game=assert(LightRPBoardRules.move(chess.game,2,5,4,5));chess.actor=7;chess.revision=5;show(chess)
assert(lastNotice=='Your turn.','turn notice: '..tostring(lastNotice))
chess.game.status='won';chess.game.winner='white';chess.actor=nil;chess.revision=6;show(chess)
assert(lastNotice=='You win.' and bar(chess).model.status=='You win' and bar(chess).model.tone=='result')
assert(pick(chess,'leave') and last().action=='leave' and not C.isActive() and not focus,'Leave table')

-- Roulette: chip, a target picked on the layout, Bet, Spin; spinning; result and Next round.
local roulette=fresh('roulette',R.new('roulette','duel'),{players={white=7},ready=true})
show(roulette);rendered(roulette);seatedAt(roulette)
assert(keys(menu(roulette))=='status,leave' and menu(roulette).status.label=='Bets open','casino tables: status and Leave only')
b=bar(roulette)
assert(b.model.status=='Place your bets' and b.model.chip.value==10 and b.model.chip.min==R.MIN_BET and b.model.chip.max==R.MAX_BET and R.MAX_BET==100 and b.model.hint:find('layout',1,true))
assert(akeys(b)=='bet-,spin' and b.bet.label=='Bet €$ 10' and b.bet.primary,akeys(b))
count=#requests;act('bet');assert(#requests==count,'no target, no bet')
chip(100);assert(bar(roulette).model.chip.value==100 and #requests==count,'a chip is a local choice')
chip(0);chip(2.5);chip(101);assert(bar(roulette).model.chip.value==100,'invalid chips are refused (above the 100 table limit too)')
local L=E.rouletteLayout
-- A click on 17 (cursor straight down on the layout) selects it.
forcedRay={origin={x=(L.gx0+5.5*L.cell)*.65,y=(L.top-1.5*L.cell)*.65,z=3},direction={x=0,y=0,z=-1}}
pointer({x=.5,y=.5,pressed=true});step();pointer({x=.5,y=.5,released=true});step();forcedRay=nil
b=bar(roulette);assert(b.model.target=='17 · pays 35:1' and b.bet.label=='Bet €$ 100 on 17' and b.bet.enabled and view.target=='17 · pays 35:1',akeys(b))
act('bet');assert(last().action=='game' and last().operation=='bet' and last().data.bet=='number:17' and last().data.amount==100 and last().revision==roulette.revision)
E.select(roulette,'red','Red');act('bet');assert(last().data.bet=='red' and bar(roulette).model.target=='Red · pays 1:1')
E.select(roulette,'dozen2','2nd 12');assert(bar(roulette).model.target=='2nd 12 · pays 2:1')
-- Cash bounds the bets.
events.state({money={cash=60}});assert(not bar(roulette).bet.enabled,'nothing above the cash');count=#requests;act('bet');assert(#requests==count)
events.state({money={cash=100000}})
-- The server takes the bet: a notice confirms it.
roulette.game=assert(R.act(roulette.game,'white','bet',{bet='red',amount=100}));roulette.game.yourStake=100;roulette.revision=2;show(roulette)
assert(lastNotice=='€$ 100 on Red · your bets €$ 100.' and bar(roulette).model.status=='Your bets €$ 100',lastNotice)
act('spin');assert(last().operation=='spin')
roulette.game=assert(R.act(roulette.game,'white','spin',{outcome=17,seedAngle=0,nowMs=E.serverTime(roulette)}));roulette.revision=3;show(roulette)
b=bar(roulette);assert(akeys(b)=='' and b.model.status=='Wheel spinning' and b.model.countdownMs and b.model.countdownMs>7000 and not b.model.chip,'bets close while it spins')
roulette.game=assert(R.act(roulette.game,'white','settle',{nowMs=roulette.game.spin.endsAt}));roulette.revision=4;show(roulette)
assert(lastNotice=='17 Black. No win.',lastNotice)
b=bar(roulette);assert(akeys(b)=='next' and b.model.status=='17 Black' and b.model.detail=='No win' and b.next.label=='Next round')
act('next');assert(last().operation=='nextRound')
escape();assert(E.selection(roulette)==nil)

-- Slot machine: the bet, Pull with its amount; watchers only watch.
local slots=fresh('slots',S.new('duel'),{players={white=7,black=9},ready=true,actor=7})
show(slots);rendered(slots);seatedAt(slots)
b=bar(slots)
assert(b.model.status=='Ready' and b.model.chip.label=='Bet' and b.model.chip.min==S.MIN_BET and b.model.chip.max==S.MAX_BET and akeys(b)=='pull' and b.pull.label=='Pull €$ 10',akeys(b))
act('pull');assert(last().operation=='pull' and last().data.bet==10)
chip(101);assert(LightRpCasinoSlotsClient.bet()==10,'above the 100 machine limit')
chip(50);assert(LightRpCasinoSlotsClient.bet()==50 and bar(slots).pull.label=='Pull €$ 50','the lever pulls with the bar bet')
local presets=bar(slots).model.chip.presets;assert(presets[1]==S.MIN_BET and presets[#presets]<=S.MAX_BET)
events.state({money={cash=20}});assert(not bar(slots).pull.enabled,'no pull above the cash');events.state({money={cash=100000}})
slots.actor=9;slots.revision=2;show(slots);b=bar(slots);assert(akeys(b)=='' and b.model.detail=='Another player is at the lever','the watcher seat cannot pull')
slots.actor=7;slots.revision=3;show(slots)
local function stopOf(r,name) for i,s in ipairs(S.REELS[r]) do if s==name then return i-1 end end end
local start=E.serverTime(slots)
slots.game=assert(S.act(slots.game,'white','pull',{bet=10,stops={stopOf(1,'seven'),stopOf(2,'seven'),stopOf(3,'seven')},nowMs=start}))
slots.revision=4;slots.serverNow=start;show(slots)
b=bar(slots);assert(b.model.status=='Reels spinning' and not b.pull.enabled,'no pull while the reels spin')
local before=#notices
for i=1,30 do step() end;assert(#notices==before,'the outcome is not spoiled before the reels stop')
waitUntil(function() return lastNotice=='Three Sevens · €$ 2,000.' end,'the win notice when the reels stop')
b=bar(slots);assert(b.model.status=='Won €$ 2,000' and b.model.tone=='result' and b.pull.enabled)
escape()

-- Blackjack: the chip within the hand limits, Bet / Add, Deal now, Hit/Stand/Double with the totals.
local bj=fresh('blackjack',B.view(B.new('duel',7,now)),{players={white=7},ready=true})
show(bj);rendered(bj);seatedAt(bj)
b=bar(bj)
assert(b.model.status=='Place a bet' and b.model.chip.min==B.MIN_BET and b.model.chip.max==B.MAX_BET and akeys(b)=='bet,deal-' and b.bet.label=='Bet €$ 10',akeys(b))
chip(50);act('bet');assert(last().operation=='bet' and last().data.amount==50)
local s=assert(B.act(B.new('duel',7,now),'white','bet',{amount=490,inventory='me',nowMs=now}))
bj.game=B.view(s);bj.revision=2;show(bj)
b=bar(bj);assert(akeys(b)=='bet-,deal' and b.bet.label=='Add €$ 50' and b.model.status=='Your bet €$ 490' and b.model.countdownMs,akeys(b))
chip(10);assert(bar(bj).bet.enabled,'490 + 10 is within the 500 limit')
act('deal');assert(last().operation=='deal')
-- A fixed hand, notices included: the turn notice at actAt, the result at resultAt.
local fixed=B.view(B.new('duel',1,now));fixed.phase='playing';fixed.round=9;fixed.seatTurn='white';fixed.actAt=now+2000;fixed.turnEndsAt=now+30000
fixed.hands={white={bet=50,stake=50,cards={{c='TS',t=now-3000},{c='9D',t=now-2000}},total=19}}
fixed.dealer={cards={{c='6H',t=now-2500},{h=true,t=now-1500}},total=6}
bj.game=fixed;bj.revision=5;bj.serverNow=now;show(bj)
b=bar(bj);assert(akeys(b)=='hit-,stand-,double-' and not b.model.tone,'no decision while the dealer hands over: '..akeys(b))
waitUntil(function() return lastNotice:find('Your turn: 19 vs dealer 6',1,true) end,'turn notice once the dealer hands over')
b=bar(bj);assert(akeys(b)=='hit,stand,double' and b.model.status=='Hand 19 · Dealer 6' and b.model.tone=='turn' and b.double.label=='Double €$ 50',akeys(b))
act('hit');assert(last().operation=='hit');act('stand');assert(last().operation=='stand');act('double');assert(last().operation=='double')
events.state({money={cash=10}});assert(not bar(bj).double.enabled,'no double above the cash');events.state({money={cash=100000}})
local done=B.view(B.new('duel',1,now));done.phase='result';done.round=9;done.resultAt=E.serverTime(bj)+1000;done.nextAt=done.resultAt+6500
done.hands={white={bet=50,stake=50,cards=fixed.hands.white.cards,total=19,result='win',payout=100,done=true}}
done.dealer={cards={{c='6H',t=now-2500},{c='KC',t=now-1500},{c='2D',t=now}},total=18}
bj.game=done;bj.revision=6;show(bj)
assert(bar(bj).model.status=='Dealer plays','the result waits for the reveal')
waitUntil(function() return lastNotice=='Win · €$ 100 returned.' end,'result notice')
b=bar(bj);assert(b.model.status=='Win' and b.model.detail=='€$ 100 returned' and akeys(b)=='')
escape()

-- Fortune wheel: chip, a spot picked on the felt, Bet, Spin; a result notice with the winnings.
local g=F.new()
local wheel=fresh('fortune',F.view(g,'me'),{players={white=7},ready=true})
show(wheel);rendered(wheel);seatedAt(wheel)
b=bar(wheel);assert(b.model.status=='Place your bets' and akeys(b)=='bet-,spin' and b.model.hint=='Click a spot on the felt',akeys(b))
E.select(wheel,'eye',F.LABEL.eye)
b=bar(wheel);assert(b.bet.label=='Bet €$ 10 on '..F.LABEL.eye and b.model.target==F.LABEL.eye..' · pays 40 to 1',b.model.target)
act('bet');assert(last().operation=='bet' and last().data.spot=='eye' and last().data.amount==10)
chip(50);assert(LightRpCasinoFortuneClient.chip()==50 and bar(wheel).bet.label:find('€$ 50',1,true))
act('spin');assert(last().operation=='spin')
g=assert(F.bet(g,{inventory='me',seat='white',spot='20',amount=50,roundKey='k'}))
wheel.game=F.view(g,'me');wheel.revision=2;show(wheel);assert(bar(wheel).model.status=='Your bets €$ 50')
local spun=assert(F.spin(g,{outcome=13,laps=2,nowMs=E.serverTime(wheel),roundKey='k'}))
wheel.game=F.view(spun,'me');wheel.revision=3;show(wheel)
b=bar(wheel);assert(akeys(b)=='' and b.model.status=='Wheel spinning' and b.model.countdownMs)
local settled=assert(F.settle(spun,spun.spin.endsAt))
wheel.game=F.view(settled,'me');wheel.revision=4;show(wheel)
assert(lastNotice=='20x wins. You won €$ 1,050.',lastNotice)
b=bar(wheel);assert(b.model.status=='20x wins' and b.model.detail=='You won €$ 1,050' and akeys(b)=='bet,spin',akeys(b))
escape()

-- Pool: Sit and the owner's mode from the menu; on the bar the mode before
-- the break, New game after it, Re-rack in practice, a rematch once won; each
-- shot's outcome as a notice when the balls stop.
local P,PC=LightRpPool,LightRpPoolClient
local pool=fresh('pool',P.new('duel',3),{owned=true})
show(pool);rendered(pool)
rows=menu(pool);assert(rows.title=='Pool' and keys(rows)=='status,sit,mode.solo,pickup' and rows['mode.solo'].label=='Solo practice',keys(rows))
pool.players={white=7,black=9};pool.ready=true;pool.actor=7;pool.revision=2;show(pool);seatedAt(pool)
assert(lastNotice:find('hold the left button to charge',1,true),'seating explains the shot: '..tostring(lastNotice))
b=bar(pool)
assert(akeys(b)=='mode' and b.model.status=='Your shot · break' and b.model.tone=='turn' and b.mode.label=='Mode: 1v1' and b.model.hint:find('release',1,true),akeys(b))
act('mode');assert(last().action=='mode' and last().mode=='solo' and last().boardId==pool.id)
-- The break, in flight: the status only; then New game for the owner.
local start=E.serverTime(pool)
local n=assert(P.shoot(pool.game,'white',{yaw=0,power=1,nowMs=start}))
pool.game=n;pool.revision=3;pool.serverNow=start;pool.actor=n.turn=='white' and 7 or 9;show(pool)
b=bar(pool);assert(akeys(b)=='' and b.model.status=='Balls rolling',akeys(b))
before=#notices
for i=1,10 do step() end;assert(#notices==before,'the outcome waits for the balls to stop')
waitUntil(function() return #notices>before end,'shot outcome notice')
assert(lastNotice==PC.result(pool) and (lastNotice:find('shot',1,true) or lastNotice:find('Shoot again',1,true) or lastNotice:find('Foul',1,true)),lastNotice)
b=bar(pool);assert(akeys(b)=='reset' and b.reset.label=='New game',akeys(b))
act('reset');assert(last().action=='reset')
pool.owned=false;pool.revision=4;show(pool);assert(akeys(bar(pool))=='','a guest: no buttons')
-- A foul notice from the opponent's side: ball in hand for me.
local foul=P.copy(n);foul.last={n=n.ply+1,by='black',foul='scratch',scratch=true};foul.turn='white';foul.inHand='table'
foul.shot=P.copy(n.shot);foul.shot.n=n.ply+1;foul.shot.at=E.serverTime(pool);foul.shot.dur=200;foul.ply=n.ply+1
pool.game=foul;pool.actor=7;pool.revision=5;show(pool)
waitUntil(function() return lastNotice:find('Foul by your opponent: Scratch.',1,true) end,'foul notice')
waitUntil(function() return not PC.busy(pool) end,'balls at rest')
assert(lastNotice:find('Ball in hand',1,true) and bar(pool).model.status:find('ball in hand',1,true) and bar(pool).model.hint:find('place the cue ball',1,true),lastNotice)
-- Won: a rematch re-racks (any seated player).
local won=P.copy(foul);won.status='won';won.winner='white';won.phase='over';won.inHand=nil;won.shot.at=E.serverTime(pool)-10000
won.last={n=foul.ply,by='black',potted=P.ballChar(9),won='white',reason='eight_early'}
pool.game=won;pool.actor=nil;pool.revision=6;show(pool)
b=bar(pool);assert(akeys(b)=='rerack' and b.model.status=='You win' and b.rerack.label=='Rematch',akeys(b))
act('rerack');assert(last().action=='game' and last().operation=='rerack')
escape()
-- Practice: the owner alone; Re-rack after the first shot.
local solo=fresh('pool',P.new('solo',4),{owned=true,mode='solo',players={white=7},ready=true,actor=7})
show(solo);rendered(solo);seatedAt(solo)
b=bar(solo);assert(akeys(b)=='mode' and b.model.status=='Practice' and b.mode.label=='Mode: Practice',akeys(b))
local shot=assert(P.shoot(solo.game,'white',{yaw=0,power=.6,nowMs=E.serverTime(solo)-60000}))
solo.game=shot;solo.revision=2;show(solo)
b=bar(solo);assert(akeys(b)=='rerack,reset' and b.rerack.label=='Re-rack',akeys(b))
act('rerack');assert(last().operation=='rerack')
-- The page payload stays small (a busy bar is a few hundred bytes).
local function size(t) local n=0;for k,v in pairs(t) do n=n+#tostring(k)+(type(v)=='table' and size(v) or #tostring(v)) end;return n end
assert(size(view)<1500,'bar payload '..size(view))
escape()
-- ALT target resolution, per game: the base prop, the collider (a solid
-- box, what the context ray really hits), a piece, a surface next to it;
-- for blackjack also the dealer NPC (it stands behind the table, in the ray
-- of a click on the far half of the felt). A passer-by NPC is never a table.
-- Every ALT click near a table is traced (menu_target), at most every 1.5 s.
local function lastTrace() for i=#diagnostics,1,-1 do local d=diagnostics[i];if d.event=='trace' and d.reason=='menu_target' then return d end end end
local function resolve(c)
 invokingResource='open77_contextmenu'
 local board,how=M.boardFor(c)
 local answer=exportCallbacks.tableMenuRows(c)
 invokingResource=nil
 return board,how,answer
end
local function prop(board,suffix)
 local name=MODELS[board.kind] and MODELS[board.kind]..(suffix or '')
 for id,p in pairs(nativeProps) do if (suffix=='piece' and p.name~=MODELS[board.kind] and not p.name:find('_collider',1,true)) or p.name==name then return id end end
end
MODELS.checkers='checkers_board';MODELS.connect4='connect4_board'
local GAMES={chess=function() return LightRPBoardRules.new('chess') end,checkers=function() return LightRPBoardRules.new('checkers') end,
 connect4=function() return LightRPBoardRules.new('connect4') end,roulette=function() return R.new('roulette','duel') end,
 slots=function() return S.new('duel') end,blackjack=function() return B.view(B.new('duel',7,now)) end,
 fortune=function() return F.view(F.new('duel',5,now),'me') end,pool=function() return P.new('duel',3) end}
local resolved={}
for _,kind in ipairs({'chess','checkers','connect4','roulette','slots','blackjack','fortune','pool'}) do
 local t=fresh(kind,GAMES[kind](),{npc=kind=='blackjack' and 4242 or nil})
 show(t);waitUntil(function() return C.isRendered(t) and prop(t)~=nil and prop(t,'_collider')~=nil end,kind..' rendered with its collider')
 for _=1,30 do step() end
 local function check(c,via,label)
  clock=clock+1600
  local board,how,answer=resolve(c)
  assert(board==t and how==via,kind..' '..label..': '..tostring(how))
  assert(#answer.rows>0 and answer.title==(LightRpBoardGames[kind].title),kind..' '..label..' has rows')
  local d=lastTrace();assert(d and d.details:find('via='..via,1,true) and d.details:find('board='..kind..':'..t.id,1,true),kind..' '..label..' traced: '..tostring(d and d.details))
 end
 check({target={kind='prop',networked=false,propId=prop(t)},position=t.position,hasSurface=true,playerDistance=1},'prop','base')
 check({target={kind='prop',networked=false,propId=prop(t,'_collider')},position=t.position,hasSurface=true,playerDistance=1},'prop','collider')
 if prop(t,'piece') then check({target={kind='prop',networked=false,propId=prop(t,'piece')},position=t.position,hasSurface=true,playerDistance=1},'prop','piece') end
 check({target={kind='world',networked=false},position={x=.3,y=.2,z=.6},hasSurface=true,playerDistance=1},'surface','surface')
 check({target={kind='object',networked=false,engineEntity='99'},position={x=-.2,y=.1,z=.6},hasSurface=true,playerDistance=1},'surface','unknown object')
 local npc={kind='npc',networked=true,npcId=4242,record='Character.sts_wat_kab_07_croupiers'}
 if kind=='blackjack' then
  check({target=npc,position={x=0,y=.47,z=1.1},hasSurface=true,playerDistance=1.5},'dealer','dealer NPC')
  -- Before its id reaches the client: an NPC hit on the dealer side still finds the table.
  check({target={kind='npc',networked=true,npcId=777},position={x=0,y=.47,z=1.1},hasSurface=true,playerDistance=1.5},'surface','dealer NPC, id unknown')
 else
  clock=clock+1600
  local board,how,answer=resolve({target={kind='npc',networked=true,npcId=4242},position={x=0,y=.47,z=1.1},hasSurface=true,playerDistance=1.5})
  assert(board==nil and how=='no_table' and #answer.rows==0,kind..': a passer-by NPC is not the table')
  assert(lastTrace().details:find('kind=npc',1,true) and lastTrace().details:find('board=none',1,true),'a miss near a table is traced too')
 end
 resolved[#resolved+1]=kind
end
-- The registration includes NPCs (the dealer), still within the real registry.
local types={};for _,t in ipairs(registered.types) do types[t]=true end
local registry=ContextMenuRegistry.new(function() return true end)
assert(types.npc and registry.register('op77_lightrp',1,registered))
-- The real registry offers the table menu on the dealer: before, its types
-- left NPCs out, so an ALT click that hit the croupier listed nothing.
assert(#registry.candidates({target={kind='npc',networked=true,npcId=4242},playerDistance=1.5})==1,'the table menu is a candidate on the dealer NPC')
assert(#registry.candidates({target={kind='npc',networked=true,npcId=4242},playerDistance=3.5})==0,'within the 3 m menu reach')
-- The trace is rate-limited and stays silent far from every table.
local traces=0;for _,d in ipairs(diagnostics) do if d.reason=='menu_target' then traces=traces+1 end end
invokingResource='open77_contextmenu';exportCallbacks.tableMenuRows({target={kind='world'},position={x=0,y=0,z=0},hasSurface=true});invokingResource=nil
local after=0;for _,d in ipairs(diagnostics) do if d.reason=='menu_target' then after=after+1 end end
assert(after==traces,'at most one target trace per 1.5 s')
Open77.character.state().position.x=30;clock=clock+1600
invokingResource='open77_contextmenu';exportCallbacks.tableMenuRows({target={kind='world'},position={x=30,y=0,z=0},hasSurface=true});invokingResource=nil
after=0;for _,d in ipairs(diagnostics) do if d.reason=='menu_target' then after=after+1 end end
assert(after==traces,'no trace far from every table');Open77.character.state().position.x=0
assert(peak<5000,'a menu costs '..peak..' instructions')
assert(barPeak<3000,'a bar costs '..barPeak..' instructions')
print('table menu and bar: management rows (status, sit, mode, new game, leave, pick up), bar per game and state (chess, roulette, slots, blackjack, fortune, pool) and their requests, chip limits, cash limits, notices, ALT target resolution per game ('..table.concat(resolved,', ')..': base, collider, piece, surface, dealer NPC, passer-by NPC, traced): OK; peak '..peak..' instructions per menu, '..barPeak..' per bar')
''')