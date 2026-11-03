#!/usr/bin/env python3
"""Blackjack controller + RP-money regressions on the real board/tabletop modules.

Reuses the mock host of tools/test-tabletop-extra-server.py (atomic commits of
board rows, inventories and claims), loads the real blackjack rules and server
handler, and drives four seated players through stacked shoes.
"""
from pathlib import Path
import json
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
source=(ROOT/'tools/test-tabletop-extra-server.py').read_text()
namespace={'__file__':str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(source.split('SOURCES=')[0],namespace)
HARNESS=namespace['HARNESS']
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'shared/casino_blackjack.lua',
         GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/casino_blackjack.lua',GAME/'server/modules/board_games.lua']
EXTRA=r'''
B=LightRpBlackjack
realShuffle=B.shuffle
function stack(list) B.shuffle=function() local s={} for i,v in ipairs(list) do s[i]=v end for i=#list+1,312 do s[i]='2C' end return s end end
function seated(id) local ids={} for p=1,4 do action(p,id,'join') end return ids end
function view(id,player) return board(id,player).game end
-- Walk every public table a client receives: no private key, ever.
function private(t,path)
 if type(t)~='table' then return end
 for k,v in pairs(t) do
  if type(k)=='string' and k:sub(1,1)=='_' then return (path or '')..'.'..k end
  local found=private(v,(path or '')..'.'..tostring(k));if found then return found end
 end
end
function totalUnpaid() local n=0;for _,row in pairs(dbClaims) do if row.paid==0 then n=n+row.amount end end;return n end
function claimRows() local n=0;for _ in pairs(dbClaims) do n=n+1 end;return n end
function untilPhase(id,phase) for i=1,40 do if view(id).phase==phase then return end;wall=wall+1000;step(2000) end error('phase '..phase..' never reached') end
'''
def environment():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpItems={}')
    lua.execute(HARNESS)
    for path in SOURCES:
        lua.execute(path.read_text())
    lua.execute(EXTRA)
    lua.execute('modules.board_games.onDatabaseReady()')
    return lua
def scenario(name,script):
    lua=environment();lua.execute(script);print(name+': passed');return lua
def pyvalue(v):
    if hasattr(v,'items'):
        d={k:pyvalue(x) for k,x in v.items()}
        if d and all(isinstance(k,int) for k in d): return [d[i] for i in sorted(d)]
        return {str(k):x for k,x in d.items()}
    return v

scenario('stakes: whole-dollar limits, insufficient cash, atomic debit, four seats',r'''
local id=place('blackjack',1);seated(id)
local b=board(id);assert(b.players.white==1 and b.players.black==2 and b.players.white2==3 and b.players.black2==4,'four seats')
action(5,id,'join');assert(notices[5]:find('All seats'))
for _,amount in ipairs({4,7.5,-5,5001,'x'}) do local before=commits;game(1,id,'bet',{amount=amount});assert(cash(1)==1000 and commits==before) end
game(2,id,'bet',{amount=1001});assert(cash(2)==1000 and notices[2]:find('Not enough cash'),notices[2])
failDB=true;game(1,id,'bet',{amount=25});failDB=false;assert(cash(1)==1000 and next(view(id).hands)==nil)
game(1,id,'bet',{amount=25});assert(cash(1)==975 and view(id).hands.white.bet==25 and view(id).closesAt)
game(1,id,'bet',{amount=5});assert(cash(1)==970 and view(id).hands.white.bet==30)
game(1,id,'bet',{amount=4971});assert(cash(1)==970 and view(id).hands.white.bet==30,'hand max 5000')
assert(dbBoards[id].data.game.hands.white._inv=='inv1' and dbBoards[id].data.game._roundKey)
assert(not private(view(id)),private(view(id)))
''')

scenario('turns: seat order, wrong seat and wrong owner rejected, hole card never public',r'''
stack({'TS','9D','5C','7H','6D','KH','8C','2S','9S','QH','4D','3S','TD','KC'})
local id=place('blackjack',1);seated(id)
for p=1,4 do game(p,id,'bet',{amount=10}) end
game(3,id,'deal',{});local g=view(id)
assert(g.phase=='playing' and g.seatTurn=='white' and g.dealer.cards[2].h and not g.dealer.cards[2].c)
-- QH is the hole card and appears nowhere else on the table.
for p=1,5 do local v=view(id,p);assert(not private(v),private(v));assert(v.dealer.cards[2].c==nil) end
assert(dbBoards[id].data.game._hole=='QH')
wall=g.actAt
local revision=board(id).revision
game(2,id,'hit',{});assert(board(id).revision==revision and notices[2]:find('not your turn'),notices[2])
game(2,id,'stand',{});game(2,id,'double',{});assert(board(id).revision==revision and cash(2)==990)
game(1,id,'stand',{});assert(view(id).seatTurn=='black')
-- A replacement character in a seat cannot play the absent owner's hand.
local owner=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='other-character',persistent=true,slots=10,items={[2]={name='cash',count=500}}}
action(2,id,'join');assert(board(id).players.black==2)
revision=board(id).revision;game(2,id,'hit',{});assert(board(id).revision==revision and notices[2]:find('another player'),notices[2])
game(2,id,'double',{});assert(cash(2)==500 and board(id).revision==revision)
inventories[2]=owner
game(2,id,'double',{});assert(cash(2)==980 and view(id).hands.black.doubled and view(id).seatTurn=='white2')
for _,p in ipairs({3,4}) do wall=math.max(wall,view(id).animEnd or 0);game(p,id,'stand',{}) end
g=view(id);assert(g.phase=='result' and g.dealer.cards[2].c=='QH' and g.dealer.cards[2].f)
for p=1,5 do assert(not private(view(id,p))) end
''')

scenario('payouts: durable claims at the reveal end, paid exactly once, nothing more next round',r'''
-- white T,K=20 ; black 9,9=18 ; white2 A,K natural ; black2 5,7=12 ; dealer 6 up, T hole -> draws 2C=18
stack({'TS','9D','AH','5C','6D','KH','9C','KC','7H','TD'})
local id=place('blackjack',1);seated(id)
for p,amount in ipairs({100,50,20,30}) do game(p,id,'bet',{amount=amount}) end
assert(cash(1)==900 and cash(2)==950 and cash(3)==980 and cash(4)==970)
game(1,id,'deal',{});wall=view(id).actAt
game(1,id,'stand',{});game(2,id,'stand',{})
local before=commits;failDB=true;game(4,id,'stand',{});failDB=false
assert(view(id).phase=='playing' and claimRows()==0,'failed settlement leaves no claims')
game(4,id,'stand',{})
local g=view(id);assert(g.phase=='result' and g.dealer.total==18)
assert(g.hands.white.result=='win' and g.hands.black.result=='push' and g.hands.white2.result=='blackjack' and g.hands.black2.result=='lose')
assert(unpaid('inv1')==200 and unpaid('inv2')==50 and unpaid('inv3')==50 and unpaid('inv4')==0)
wall=g.resultAt-1;for p=1,4 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==900 and cash(3)==980,'paid before the reveal ended')
wall=g.resultAt;for p=1,4 do LightRP.tabletopExtra.claim(p) end
assert(cash(1)==1100 and cash(2)==1000 and cash(3)==1030 and cash(4)==970)
for p=1,4 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==1100 and cash(3)==1030 and totalUnpaid()==0)
local rows=claimRows()
wall=g.nextAt;assert(step(2000));g=view(id);assert(g.phase=='betting' and g.round==2 and next(g.hands)==nil)
assert(claimRows()==rows and totalUnpaid()==0)
''')

scenario('refunds: reset and pickup before the result return every open stake once',r'''
stack({'5S','9D','6H','8C','KD','2D','3H','4S'})
local id=place('blackjack',1);seated(id)
game(1,id,'bet',{amount=50});game(2,id,'bet',{amount=30})
game(1,id,'deal',{});wall=view(id).actAt;game(1,id,'double',{})
assert(cash(1)==900 and cash(2)==970 and view(id).phase=='playing')
local revision=board(id).revision
failDB=true;action(1,id,'reset');failDB=false;assert(board(id).revision==revision and claimRows()==0)
action(1,id,'reset');assert(view(id).phase=='betting' and next(view(id).hands)==nil)
assert(unpaid('inv1')==100 and unpaid('inv2')==30)
for p=1,2 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==1000 and cash(2)==1000 and totalUnpaid()==0)
-- Pickup during betting refunds in the same delete/item transaction.
seated(id);game(3,id,'bet',{amount=40});assert(cash(3)==960)
action(1,id,'pickup');assert(not board(id) and itemCount(1,'blackjack_table')==1 and unpaid('inv3')==40)
LightRP.tabletopExtra.claim(3);assert(cash(3)==1000)
-- A settled round refunds nothing on pickup: its claims already exist.
stack({'TS','6D','KH','TC'})
-- (player 4 owns it: the harness places a table into slot 1, where 1's cash now sits)
id=place('blackjack',4);action(4,id,'join');game(4,id,'bet',{amount=10});game(4,id,'deal',{});wall=view(id).actAt
game(4,id,'stand',{});assert(view(id).phase=='result' and unpaid('inv4')==20)
action(4,id,'pickup');assert(not board(id) and unpaid('inv4')==20)
''')

scenario('timers: betting countdown deals, idle turns stand, the round resolves unattended',r'''
stack({'TS','9D','6D','KH','6C','TC'})
local id=place('blackjack',1);seated(id)
game(1,id,'bet',{amount=10});game(2,id,'bet',{amount=10})
local g=view(id);wall=g.closesAt-1;step(2000);assert(view(id).phase=='betting')
wall=g.closesAt;step(2000);g=view(id);assert(g.phase=='playing' and g.seatTurn=='white')
wall=g.turnEndsAt-1;step(2000);assert(view(id).seatTurn=='white')
wall=g.turnEndsAt;step(2000);g=view(id);assert(g.seatTurn=='black' and g.hands.white.timedOut and g.hands.white.done)
-- Everyone walks away: the timeout still finishes the hand and pays.
for p=1,4 do modules.board_games.onDisconnected(p) end
wall=g.turnEndsAt;step(2000);g=view(id,5);assert(g.phase=='result')
assert(unpaid('inv1')==20 and unpaid('inv2')==0)
''')

lua=scenario('public view stays small at the worst case (four 7-card hands, 8-card dealer)',r'''
local twos={'2S','2H','2D','2C'};local threes={'3S','3H','3D','3C'}
local list={}
local function add(c) list[#list+1]=c end
for pass=1,2 do for p=1,4 do add(twos[p]) end;add(pass==1 and '2D' or '3D') end
for p=1,4 do for _,c in ipairs({'2S','2H','2D','3S','3H'}) do add(c) end end
stack(list)
worstId=place('blackjack',1);seated(worstId)
for p=1,4 do inventories[p].items[2]={name='cash',count=100000};game(p,worstId,'bet',{amount=4999}) end
game(1,worstId,'deal',{});wall=view(worstId).actAt
for p=1,4 do for i=1,5 do wall=math.max(wall,view(worstId).animEnd or 0);game(p,worstId,'hit',{}) end;game(p,worstId,'stand',{}) end
local g=view(worstId);assert(g.phase=='result' and #g.dealer.cards==8)
for p=1,4 do assert(#g.hands[LightRpBlackjack.SEATS[p]].cards==7) end
''')
entry=next(b for b in lua.eval('list(1)').values() if b['id']==lua.eval('worstId'))
size=len(json.dumps(pyvalue(entry),separators=(',',':')))
game=len(json.dumps(pyvalue(entry['game']),separators=(',',':')))
assert size<3000,size
print(f'public view size: board entry {size} bytes, game {game} bytes (limit ~3 KB)')
print('Blackjack server: all money, turn, privacy, timer and size scenarios passed')
