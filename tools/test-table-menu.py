#!/usr/bin/env python3
"""The ALT target menu of every table (client/core/table_menu.lua): which rows
each game shows in which state, that selecting a row sends the right request,
the notices that replace the old panel, and the cost of building a menu.

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
 assert(resource=='open77_contextmenu' and name=='register','unexpected export '..tostring(name))
 registered=definition
 return {await=function() return 'token-1' end}
end
''')
for name in ['shared/board_games.lua', 'shared/board_games_rules.lua', 'shared/tabletop_extra.lua', 'shared/tabletop_extra_rules.lua',
             'shared/casino_slots.lua', 'shared/casino_blackjack.lua', 'shared/casino_fortune.lua', 'shared/casino_pool.lua',
             'client/core/tabletop_extra.lua', 'client/core/casino_slots.lua', 'client/core/casino_blackjack.lua',
             'client/core/casino_fortune.lua', 'client/core/casino_pool.lua', 'client/core/board_games.lua', 'client/core/table_menu.lua']:
    lua.execute((RES/name).read_text(), name=name)
lua.execute((ROOT/'resources/system/open77_contextmenu/client/registry.lua').read_text(), name='registry.lua')
lua.execute(r'''
local C,E,M=LightRpBoardGamesClient,LightRpTabletopExtraClient,LightRpTableMenu
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

-- Chess, standing: Sit (a seat is free) and, for the owner within 2 m, Pick up.
local rows=menu(chess)
assert(rows.title=='Chess' and keys(rows)=='sit,pickup',keys(rows))
assert(rows.sit.label=='Sit' and rows.pickup.label=='Pick up board')
assert(keys(menu(chess,true))=='sit,pickup','a click on the surface of the table finds it too')
Open77.character.state().position.x=2.5;assert(keys(menu(chess))=='sit','Pick up needs 2 m');Open77.character.state().position.x=0
assert(pick(chess,'sit') and last().action=='join' and last().boardId==chess.id)
assert(pick(chess,'pickup') and last().action=='pickup' and last().boardId==chess.id)
local count=#requests;assert(not pick(chess,'reset') and #requests==count,'a row the menu does not offer never runs')
chess.players={white=9,black=10};show(chess);assert(keys(menu(chess))=='pickup','a full table offers no seat')
chess.owned=false;chess.mode='solo';chess.players={};show(chess);assert(keys(menu(chess))=='','solo is the owner\'s')
-- Seated, owner, before the first move: the status, the game mode, Leave.
chess.owned=true;chess.mode='duel';chess.players={white=7,black=9};chess.ready=true;chess.actor=7;chess.revision=2;show(chess);seatedAt(chess)
assert(lastNotice:find('You play White',1,true) and lastNotice:find('ALT',1,true),'seating explains the controls')
rows=menu(chess)
assert(keys(rows)=='status,mode.solo,mode.teams,leave,pickup',keys(rows))
assert(rows.status.label=='Your turn' and rows['mode.solo'].submenu.label=='Mode: 1v1' and rows['mode.solo'].label=='Solo vs AI' and rows['mode.teams'].label=='2v2')
assert(pick(chess,'mode.solo') and last().action=='mode' and last().mode=='solo' and last().boardId==chess.id)
assert(pick(chess,'status') and lastNotice:find('1v1 · 2/2 players · you play White',1,true))
-- After the first move: New game instead of the mode; never for a guest.
chess.game=assert(LightRPBoardRules.move(chess.game,7,5,5,5));chess.actor=9;chess.revision=3;show(chess)
rows=menu(chess);assert(keys(rows)=='status,reset,leave,pickup' and rows.status.label=='Black to move' and rows.reset.label=='New game',keys(rows))
count=#requests;assert(not pick(chess,'mode.solo') and #requests==count,'the mode locks once the game started')
assert(pick(chess,'reset') and last().action=='reset')
chess.owned=false;chess.revision=4;show(chess);assert(keys(menu(chess))=='status,leave')
-- Notices: the turn comes back, the game ends.
chess.game=assert(LightRPBoardRules.move(chess.game,2,5,4,5));chess.actor=7;chess.revision=5;show(chess)
assert(lastNotice=='Your turn.','turn notice: '..tostring(lastNotice))
chess.game.status='won';chess.game.winner='white';chess.actor=nil;chess.revision=6;show(chess)
assert(lastNotice=='You win.' and menu(chess).status.label=='You win')
assert(pick(chess,'leave') and last().action=='leave' and not C.isActive(),'Leave table')

-- Roulette: chip, bet targets, Spin; spinning; result and Next round.
local roulette=fresh('roulette',R.new('roulette','duel'),{players={white=7},ready=true})
show(roulette);rendered(roulette);seatedAt(roulette)
rows=menu(roulette)
assert(rows.title=='Roulette' and keys(rows)=='status,chip.50,chip.100,chip.500,chip.1000,bet.red,bet.black,bet.even,bet.odd,bet.low,bet.high,bet.dozen1,bet.dozen2,bet.dozen3,bet.number:0,spin,leave',keys(rows))
assert(rows.status.label=='Place your bets' and rows['chip.50'].submenu.label=='Chip: €$ 10' and rows['chip.1000'].label=='€$ 1,000')
assert(rows['bet.red'].submenu.label=='Bet €$ 10' and rows['bet.number:0'].label=='Zero' and rows['bet.dozen2'].label=='13-24' and rows['bet.red'].description=='Pays 1 to 1')
count=#requests;assert(pick(roulette,'chip.100') and #requests==count and lastNotice=='Chip: €$ 100','a chip is a local choice')
rows=menu(roulette);assert(rows['bet.red'].submenu.label=='Bet €$ 100' and rows['chip.10'] and not rows['chip.100'])
assert(pick(roulette,'bet.red') and last().action=='game' and last().operation=='bet' and last().data.bet=='red' and last().data.amount==100 and last().revision==roulette.revision)
assert(pick(roulette,'bet.number:0') and last().data.bet=='number:0')
-- Cash bounds the chips and the bets.
events.state({money={cash=60}});rows=menu(roulette)
assert(rows['chip.10'] and rows['chip.50'] and not rows['chip.500'] and not rows['bet.red'],'nothing above the cash: '..keys(rows))
events.state({money={cash=100000}})
-- The server takes the bet: a notice confirms it.
roulette.game=assert(R.act(roulette.game,'white','bet',{bet='red',amount=100}));roulette.game.yourStake=100;roulette.revision=2;show(roulette)
assert(lastNotice=='€$ 100 on Red · your bets €$ 100.' and menu(roulette).status.label=='Your bets: €$ 100',lastNotice)
assert(pick(roulette,'status') and lastNotice=='€$ 100 on Red')
assert(pick(roulette,'spin') and last().operation=='spin')
roulette.game=assert(R.act(roulette.game,'white','spin',{outcome=17,seedAngle=0,nowMs=now}));roulette.revision=3;show(roulette)
assert(keys(menu(roulette))=='status,leave' and menu(roulette).status.label=='Wheel spinning','bets close while it spins')
roulette.game=assert(R.act(roulette.game,'white','settle',{nowMs=now+8000}));roulette.revision=4;show(roulette)
assert(lastNotice=='17 Black. No win.',lastNotice)
rows=menu(roulette);assert(keys(rows)=='status,next,leave' and rows.status.label=='Result: 17 Black' and rows.next.label=='Next round')
assert(pick(roulette,'next') and last().operation=='nextRound')
edge('BACKSPACE')

-- Slot machine: the bet, Pull with its amount; watchers only watch.
local slots=fresh('slots',S.new('duel'),{players={white=7,black=9},ready=true,actor=7})
show(slots);rendered(slots);seatedAt(slots)
rows=menu(slots)
assert(rows.title=='Slot Machine' and keys(rows)=='status,bet.50,bet.100,bet.500,bet.1000,pull,leave' and rows.pull.label=='Pull (€$ 10)' and rows['bet.50'].submenu.label=='Bet: €$ 10',keys(rows))
assert(pick(slots,'pull') and last().operation=='pull' and last().data.bet==10)
assert(pick(slots,'bet.500') and LightRpCasinoSlotsClient.bet()==500 and menu(slots).pull.label=='Pull (€$ 500)','the lever pulls with the menu bet')
events.state({money={cash=200}});assert(not menu(slots).pull and not menu(slots)['bet.1000'],'no pull above the cash');events.state({money={cash=100000}})
slots.actor=9;slots.revision=2;show(slots);assert(keys(menu(slots))=='status,leave','the watcher seat cannot pull')
slots.actor=7;slots.revision=3;show(slots)
local function stopOf(r,name) for i,s in ipairs(S.REELS[r]) do if s==name then return i-1 end end end
local start=E.serverTime(slots)
slots.game=assert(S.act(slots.game,'white','pull',{bet=10,stops={stopOf(1,'seven'),stopOf(2,'seven'),stopOf(3,'seven')},nowMs=start}))
slots.revision=4;slots.serverNow=start;show(slots)
assert(keys(menu(slots))=='status,bet.10,bet.50,bet.100,bet.1000,leave' and menu(slots).status.label=='Reels spinning','no pull while the reels spin')
local before=#notices
for i=1,30 do step() end;assert(#notices==before,'the outcome is not spoiled before the reels stop')
waitUntil(function() return lastNotice=='Three Sevens · €$ 2,000.' end,'the win notice when the reels stop')
assert(menu(slots).status.label=='Last: €$ 2,000' and menu(slots).pull)
edge('BACKSPACE')

-- Blackjack: bet presets within the hand limits, Deal now, Hit/Stand/Double with the total.
local bj=fresh('blackjack',B.view(B.new('duel',7,now)),{players={white=7},ready=true})
show(bj);rendered(bj);seatedAt(bj)
rows=menu(bj)
assert(rows.title=='Blackjack' and keys(rows)=='status,bet.10,bet.50,bet.100,bet.500,bet.1000,leave' and rows['bet.10'].submenu.label=='Bet',keys(rows))
assert(pick(bj,'bet.50') and last().operation=='bet' and last().data.amount==50)
local s=assert(B.act(B.new('duel',7,now),'white','bet',{amount=4990,inventory='me',nowMs=now}))
bj.game=B.view(s);bj.revision=2;show(bj)
rows=menu(bj);assert(keys(rows)=='status,bet.10,deal,leave' and rows['bet.10'].submenu.label=='Add to bet' and rows.status.label=='Your bet: €$ 4,990',keys(rows))
assert(pick(bj,'deal') and last().operation=='deal')
s=assert(B.act(B.new('duel',7,now),'white','bet',{amount=50,inventory='me',nowMs=now}))
s=assert(B.act(s,'white','deal',{inventory='me',nowMs=now,seed=7}))
if s.phase=='playing' then
 bj.game=B.view(s);bj.revision=3;bj.serverNow=now;show(bj)
 assert(not menu(bj).hit,'no decision while the cards are dealt')
 bj.serverNow=s.actAt+10;bj.revision=4;show(bj)
 local total,soft=B.total(s.hands.white.cards)
 local shown=(soft and total<21) and 'soft '..total or tostring(total)
 rows=menu(bj)
 assert(keys(rows)=='status,hit,stand,double,leave' and rows.hit.label=='Hit ('..shown..')' and rows.stand.label=='Stand ('..shown..')' and rows.double.label=='Double (€$ 50)',keys(rows))
 assert(rows.status.label:find('Hand '..shown,1,true))
 assert(pick(bj,'hit') and last().operation=='hit');assert(pick(bj,'stand') and last().operation=='stand');assert(pick(bj,'double') and last().operation=='double')
 events.state({money={cash=10}});assert(not menu(bj).double,'no double above the cash');events.state({money={cash=100000}})
 s=assert(B.act(s,'white','stand',{inventory='me',nowMs=s.actAt+10}))
else
 print('note: seed 7 dealt a dealer natural; playing rows covered by the fixed hand below')
end
-- A fixed hand, notices included: the turn notice at actAt, the result at resultAt.
local fixed=B.view(B.new('duel',1,now));fixed.phase='playing';fixed.round=9;fixed.seatTurn='white';fixed.actAt=now+2000;fixed.turnEndsAt=now+30000
fixed.hands={white={bet=50,stake=50,cards={{c='TS',t=now-3000},{c='9D',t=now-2000}},total=19}}
fixed.dealer={cards={{c='6H',t=now-2500},{h=true,t=now-1500}},total=6}
bj.game=fixed;bj.revision=5;bj.serverNow=now;show(bj)
waitUntil(function() return lastNotice:find('Your turn: 19 vs dealer 6',1,true) end,'turn notice once the dealer hands over')
rows=menu(bj);assert(rows.hit.label=='Hit (19)' and rows.status.label=='Hand 19 · Dealer 6' and rows.double)
local done=B.view(B.new('duel',1,now));done.phase='result';done.round=9;done.resultAt=E.serverTime(bj)+1000;done.nextAt=done.resultAt+6500
done.hands={white={bet=50,stake=50,cards=fixed.hands.white.cards,total=19,result='win',payout=100,done=true}}
done.dealer={cards={{c='6H',t=now-2500},{c='KC',t=now-1500},{c='2D',t=now}},total=18}
bj.game=done;bj.revision=6;show(bj)
assert(menu(bj).status.label=='Dealer plays','the result waits for the reveal')
waitUntil(function() return lastNotice=='Win · €$ 100 returned.' end,'result notice')
assert(menu(bj).status.label=='Win · €$ 100' and keys(menu(bj))=='status,leave')
edge('BACKSPACE')

-- Fortune wheel: chip, spot bets, Spin; a result notice with the winnings.
local g=F.new()
local wheel=fresh('fortune',F.view(g,'me'),{players={white=7},ready=true})
show(wheel);rendered(wheel);seatedAt(wheel)
rows=menu(wheel)
assert(rows.title=='Fortune Wheel' and keys(rows)=='status,chip.50,chip.100,chip.500,chip.1000,bet.1,bet.2,bet.5,bet.10,bet.20,bet.eye,bet.star,spin,leave',keys(rows))
assert(rows['bet.eye'].label=='Neon Eye 40x' and rows['bet.eye'].submenu.label=='Bet €$ 10' and rows['bet.20'].description=='Pays 20 to 1')
assert(pick(wheel,'bet.eye') and last().operation=='bet' and last().data.spot=='eye' and last().data.amount==10)
assert(pick(wheel,'chip.50') and LightRpCasinoFortuneClient.chip()==50 and menu(wheel)['bet.5'].submenu.label=='Bet €$ 50')
assert(pick(wheel,'spin') and last().operation=='spin')
g=assert(F.bet(g,{inventory='me',seat='white',spot='20',amount=50,roundKey='k'}))
wheel.game=F.view(g,'me');wheel.revision=2;show(wheel);assert(menu(wheel).status.label=='Your bets: €$ 50')
local spun=assert(F.spin(g,{outcome=13,laps=2,nowMs=now,roundKey='k'}))
wheel.game=F.view(spun,'me');wheel.revision=3;show(wheel)
assert(keys(menu(wheel))=='status,leave' and menu(wheel).status.label=='Wheel spinning')
local settled=assert(F.settle(spun,spun.spin.endsAt))
wheel.game=F.view(settled,'me');wheel.revision=4;show(wheel)
assert(lastNotice=='20x wins. You won €$ 1,050.',lastNotice)
rows=menu(wheel);assert(rows.status.label=='Result: 20x · €$ 1,050' and rows.spin and rows['bet.20'],keys(rows))
edge('BACKSPACE')

-- Pool: Sit, the owner's mode before the break, New game after it, Re-rack in
-- practice, a rematch once won; each shot's outcome as a notice when the balls stop.
local P,PC=LightRpPool,LightRpPoolClient
local pool=fresh('pool',P.new('duel',3),{owned=true})
show(pool);rendered(pool)
rows=menu(pool);assert(rows.title=='Pool' and keys(rows)=='sit,pickup',keys(rows))
pool.players={white=7,black=9};pool.ready=true;pool.actor=7;pool.revision=2;show(pool);seatedAt(pool)
assert(lastNotice:find('hold the left button to charge',1,true),'seating explains the shot: '..tostring(lastNotice))
rows=menu(pool)
assert(keys(rows)=='status,mode.solo,leave,pickup' and rows.status.label=='Your shot · break' and rows['mode.solo'].label=='Solo practice' and rows['mode.solo'].submenu.label=='Mode: 1v1',keys(rows))
assert(pick(pool,'mode.solo') and last().action=='mode' and last().mode=='solo' and last().boardId==pool.id)
assert(pick(pool,'status') and lastNotice:find('open',1,true) and lastNotice:find('charge',1,true),lastNotice)
-- The break, in flight: only the status (balls rolling) and Leave; then New game for the owner.
local start=E.serverTime(pool)
local n=assert(P.shoot(pool.game,'white',{yaw=0,power=1,nowMs=start}))
pool.game=n;pool.revision=3;pool.serverNow=start;pool.actor=n.turn=='white' and 7 or 9;show(pool)
rows=menu(pool);assert(keys(rows)=='status,leave,pickup' and rows.status.label=='Balls rolling',keys(rows))
before=#notices
for i=1,10 do step() end;assert(#notices==before,'the outcome waits for the balls to stop')
waitUntil(function() return #notices>before end,'shot outcome notice')
assert(lastNotice==PC.result(pool) and (lastNotice:find('shot',1,true) or lastNotice:find('Shoot again',1,true) or lastNotice:find('Foul',1,true)),lastNotice)
rows=menu(pool);assert(keys(rows)=='status,reset,leave,pickup' and rows.reset.label=='New game',keys(rows))
assert(pick(pool,'reset') and last().action=='reset')
pool.owned=false;pool.revision=4;show(pool);assert(keys(menu(pool))=='status,leave','a guest: status and Leave')
-- A foul notice from the opponent's side: ball in hand for me.
local foul=P.copy(n);foul.last={n=n.ply+1,by='black',foul='scratch',scratch=true};foul.turn='white';foul.inHand='table'
foul.shot=P.copy(n.shot);foul.shot.n=n.ply+1;foul.shot.at=E.serverTime(pool);foul.shot.dur=200;foul.ply=n.ply+1
pool.game=foul;pool.actor=7;pool.revision=5;show(pool)
waitUntil(function() return lastNotice:find('Foul by your opponent: Scratch.',1,true) end,'foul notice')
assert(lastNotice:find('Ball in hand',1,true) and menu(pool).status.label:find('ball in hand',1,true),lastNotice)
-- Won: a rematch re-racks (any seated player).
local won=P.copy(foul);won.status='won';won.winner='white';won.phase='over';won.inHand=nil;won.shot.at=E.serverTime(pool)-10000
won.last={n=foul.ply,by='black',potted=P.ballChar(9),won='white',reason='eight_early'}
pool.game=won;pool.actor=nil;pool.revision=6;show(pool)
rows=menu(pool);assert(keys(rows)=='status,rerack,leave' and rows.status.label=='You win' and rows.rerack.label=='Rematch (re-rack)',keys(rows))
assert(pick(pool,'rerack') and last().action=='game' and last().operation=='rerack')
edge('BACKSPACE')
-- Practice: the owner alone; Re-rack after the first shot.
local solo=fresh('pool',P.new('solo',4),{owned=true,mode='solo',players={white=7},ready=true,actor=7})
show(solo);rendered(solo);seatedAt(solo)
rows=menu(solo);assert(keys(rows)=='status,mode.duel,leave,pickup' and rows.status.label=='Practice' and rows['mode.duel'].label=='1v1',keys(rows))
local shot=assert(P.shoot(solo.game,'white',{yaw=0,power=.6,nowMs=E.serverTime(solo)-60000}))
solo.game=shot;solo.revision=2;show(solo)
rows=menu(solo);assert(keys(rows)=='status,rerack,reset,leave,pickup' and rows.rerack.label=='Re-rack',keys(rows))
assert(pick(solo,'rerack') and last().operation=='rerack')
edge('BACKSPACE')
assert(peak<5000,'a menu costs '..peak..' instructions')
print('table menu: board games (sit, mode, new game, leave, pick up), roulette, slots, blackjack, fortune, pool rows per state and their requests, notices, cash limits: OK; peak '..peak..' instructions per menu')
''')
