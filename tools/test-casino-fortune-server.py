#!/usr/bin/env python3
"""Fortune Wheel controller and atomic RP-money regressions (Python + lupa).

Reuses the durable board/inventory/claim harness of
tools/test-tabletop-extra-server.py (staged commits, the real inventory mutex,
restart against the same durable rows) with the real fortune modules loaded.
"""
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
source=(ROOT/'tools/test-tabletop-extra-server.py').read_text()
namespace={'__file__':str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(source.split('SOURCES=')[0],namespace)
HARNESS=namespace['HARNESS']+r'''
LightRpItems={}
function fixedSpin(segment,laps)
 local real=math.random
 math.random=function(a,b) if a==0 and b==53 then return segment end;if a==2 and b==3 then return laps or 2 end;return real(a,b) end
end
function publicSize(id,player) return #json_encode(board(id,player).game) end
'''
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'shared/casino_fortune.lua',
 GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/casino_fortune.lua',GAME/'server/modules/board_games.lua']
SERVER=SOURCES[3:]


def environment():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(HARNESS)
    import json
    def encode(table):
        def plain(v):
            if hasattr(v,'items'):
                keys=list(v.keys())
                if keys and all(isinstance(k,int) for k in keys):return [plain(v[i]) for i in sorted(keys)]
                return {str(k):plain(x) for k,x in v.items()}
            return v
        return json.dumps(plain(table),separators=(',',':'))
    lua.globals().json_encode=encode
    for path in SOURCES:
        lua.execute(path.read_text())
    lua.execute('modules.board_games.onDatabaseReady()')
    return lua


def scenario(name,script):
    lua=environment()
    lua.execute(script)
    print(name+': passed')
    return lua


scenario('fortune stakes, insufficient cash, closed bets and a timed exactly-once payout',r'''
local id=place('fortune',1);action(1,id,'join');action(2,id,'join')
assert(itemCount(1,'fortune_wheel')==0 and board(id).kind=='fortune')
local revision=board(id).revision
failDB=true;game(1,id,'bet',{spot='20',amount=10});failDB=false
assert(cash(1)==1000 and board(id).revision==revision and next(board(id).game.pot)==nil)
throwDB=true;game(1,id,'bet',{spot='20',amount=10});throwDB=false
assert(cash(1)==1000 and not inventories[1].busy)
inventories[2].items[2].count=5;game(2,id,'bet',{spot='1',amount=6});assert(cash(2)==5 and notices[2]=='Not enough cash for this bet.')
for _,data in ipairs({{spot='3',amount=10},{spot='1',amount=0},{spot='1',amount=1.5},{spot='1',amount=101},{spot='1',amount=1001},{spot={x=1},amount=5},{amount=5}}) do
 local before=commits;game(1,id,'bet',data);assert(cash(1)==1000 and commits==before)
end
game(1,id,'bet',{spot='20',amount=10});game(1,id,'bet',{spot='20',amount=5});game(2,id,'bet',{spot='eye',amount=5})
assert(cash(1)==985 and cash(2)==0)
local g=board(id,1).game
assert(g.pot['20']==15 and g.pot.eye==5 and g.yourStake==15 and g.yourBets['20']==15 and not g._money and not g._roundKey)
assert(board(id,2).game.yourBets.eye==5 and dbBoards[id].data.game._money[1].inventory=='inv1')
-- Client-provided outcomes are ignored: the server picks segment 13 (20x).
fixedSpin(13,3);revision=board(id).revision
failDB=true;game(1,id,'spin',{outcome=0});failDB=false
assert(board(id).revision==revision and board(id).game.phase=='betting' and unpaid('inv1')==0)
game(2,id,'spin',{outcome=0,laps=6})
local state=board(id).game;assert(state.phase=='spinning' and state.spin.outcome==13 and state.spin.to-state.spin.from>=162)
assert(state.spin.startedAt>1790000000000 and state.spin.endsAt==state.spin.startedAt+9000)
assert(unpaid('inv1')==315 and unpaid('inv2')==0 and cash(1)==985)
-- one net ledger line per character for the spin (economy-balance.md section 16)
local by={};for _,l in ipairs(dbLedger) do by[l.inventory]=l end
assert(#dbLedger==2 and #ledgerShown==2 and by.inv1.game=='Fortune Wheel')
assert(by.inv1.staked==15 and by.inv1.returned==315 and by.inv1.net==300 and by.inv2.staked==5 and by.inv2.net==-5)
assert(publicSize(id,1)<700,'public view '..publicSize(id,1))
-- Bets are closed while spinning, and pickup/reset are refused.
game(1,id,'bet',{spot='1',amount=5});assert(cash(1)==985 and notices[1]=='Bets are closed while the wheel spins.')
game(2,id,'spin',{});assert(board(id).game.spin.startedAt==state.spin.startedAt)
action(1,id,'reset');assert(board(id).game.phase=='spinning')
action(1,id,'pickup');assert(board(id) and itemCount(1,'fortune_wheel')==0)
-- Claims open at the end of the spin, and are paid exactly once.
local ends=state.spin.endsAt;wall=ends-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==985)
assert(step(2000));assert(board(id).game.phase=='spinning','settled before the end')
wall=ends;failDB=true;LightRP.tabletopExtra.claim(1);failDB=false;assert(cash(1)==985 and unpaid('inv1')==315)
inventories[5]=inventories[1]
duringCommit=function() LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5) end
LightRP.tabletopExtra.claim(1);assert(cash(1)==1300 and unpaid('inv1')==0)
LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5);assert(cash(1)==1300)
assert(step(2000));g=board(id,1).game
assert(g.phase=='result' and g.result.segment==13 and g.result.spot=='20' and g.yourWin==315 and g.recent[1]==13 and g.rest==(state.spin.to%54))
assert(board(id,2).game.yourWin==0)
-- A bet after the result opens the next round with its own claim key.
game(2,id,'bet',{spot='1',amount=1});assert(cash(2)==0 and board(id).game.phase=='result')
inventories[2].items[2]={name='cash',count=100};game(2,id,'bet',{spot='1',amount=4})
g=board(id,2).game;assert(g.round==2 and g.phase=='betting' and g.pot['1']==4 and g.pot['20']==nil and g.yourStake==4)
fixedSpin(1,2);game(1,id,'spin',{});assert(unpaid('inv2')==8)
wall=board(id).game.spin.endsAt;LightRP.tabletopExtra.claim(2);assert(cash(2)==104)
assert(#dbLedger==3 and dbLedger[3].inventory=='inv2' and dbLedger[3].staked==4 and dbLedger[3].net==4,'payouts add no line')
for _,m in ipairs(cashMoves) do assert(m.label and m.label.silent==true and m.label.kind=='casino') end
''')

scenario('fortune refunds open bets on pickup and reset, never twice, bound to characters',r'''
local id=place('fortune',1);action(1,id,'join');action(2,id,'join')
game(1,id,'bet',{spot='1',amount=25});game(2,id,'bet',{spot='5',amount=40})
assert(cash(1)==975 and cash(2)==960)
local old=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='replacement-character',persistent=true,slots=10,items={[2]={name='cash',count=700}}}
action(2,id,'join');assert(board(id,2).game.yourStake==0 and next(board(id,2).game.yourBets)==nil)
local revision=board(id).revision
failDB=true;action(1,id,'reset');failDB=false
assert(board(id).revision==revision and unpaid('inv1')==0 and unpaid('inv2')==0)
action(1,id,'reset');assert(board(id).game.phase=='betting' and next(board(id).game.pot)==nil)
assert(unpaid('inv1')==25 and unpaid('inv2')==40 and unpaid('replacement-character')==0)
action(1,id,'reset');assert(unpaid('inv1')==25,'refund repeated')
LightRP.tabletopExtra.claim(2);assert(cash(2)==700 and unpaid('inv2')==40)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1000)
inventories[3]=old;LightRP.tabletopExtra.claim(3);assert(cash(3)==1000 and unpaid('inv2')==0)
action(1,id,'join');game(1,id,'bet',{spot='star',amount=15});assert(cash(1)==985)
failDB=true;action(1,id,'pickup');failDB=false
assert(board(id) and itemCount(1,'fortune_wheel')==0 and unpaid('inv1')==0)
action(1,id,'pickup');assert(not board(id) and itemCount(1,'fortune_wheel')==1 and unpaid('inv1')==15)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1000)
''')

scenario('fortune result phase: pickup pays nothing back, settled stakes are gone',r'''
local id=place('fortune',1);action(1,id,'join');game(1,id,'bet',{spot='10',amount=20});fixedSpin(2,2);game(1,id,'spin',{})
assert(unpaid('inv1')==0);wall=board(id).game.spin.endsAt;assert(step(2000));assert(board(id).game.phase=='result')
action(1,id,'pickup');assert(not board(id) and unpaid('inv1')==0 and cash(1)==980)
''')

scenario('fortune per-round cap and recycled seats keep winnings with the character',r'''
local id=place('fortune',1);action(1,id,'join');action(2,id,'join')
inventories[1].items[2].count=9000
game(1,id,'bet',{spot='1',amount=101});assert(cash(1)==9000,'100 per placed bet')
for i=1,5 do game(1,id,'bet',{spot='1',amount=100}) end
game(1,id,'bet',{spot='2',amount=1});assert(cash(1)==8500 and notices[1]:find('limited',1,true))
game(2,id,'bet',{spot='eye',amount=7})
local original=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='new-character',persistent=true,slots=10,items={[2]={name='cash',count=700}}};action(2,id,'join')
game(2,id,'bet',{spot='2',amount=5});fixedSpin(0,2);game(1,id,'spin',{})
assert(unpaid('inv2')==287 and unpaid('new-character')==0 and unpaid('inv1')==0)
wall=board(id).game.spin.endsAt;LightRP.tabletopExtra.claim(2);assert(cash(2)==695 and unpaid('inv2')==287)
inventories[3]=original;LightRP.tabletopExtra.claim(3);assert(cash(3)==1280 and unpaid('inv2')==0)
''')

lua=scenario('fortune claims prepared before a process restart are paid once',r'''
testId=place('fortune',1);action(1,testId,'join');game(1,testId,'bet',{spot='star',amount=12});fixedSpin(27,2);game(1,testId,'spin',{})
testEnd=board(testId).game.spin.endsAt;assert(unpaid('inv1')==492 and cash(1)==988)
tasks={};events={};handlers={};modules={}
''')
for path in SERVER:
    lua.execute(path.read_text())
lua.execute(r'''
modules.board_games.onDatabaseReady()
assert(board(testId).game.phase=='spinning' and next(board(testId).players)==nil and unpaid('inv1')==492)
wall=testEnd-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==988)
wall=testEnd;crashAfterCommit=true;LightRP.tabletopExtra.claim(1);crashAfterCommit=false
assert(cash(1)==988 and unpaid('inv1')==0)
inventories[1].items=clone(dbInventories.inv1);assert(cash(1)==1480)
assert(step(2000));assert(board(testId).game.phase=='result' and board(testId).game.result.spot=='star')
tasks={};modules={}
''')
lua.execute(SERVER[0].read_text())
lua.execute("LightRP.tabletopExtra.claim(1);assert(cash(1)==1480 and unpaid('inv1')==0)")
print('fortune durable restart / crash exactly-once payout: passed')

scenario('fortune money RPC rejects replays and reentrant double charging',r'''
local id=place('fortune',1);action(1,id,'join')
local packet={revision=board(id).revision,operation='bet',data={spot='5',amount=10}}
duringCommit=function() action(1,id,'game',clone(packet)) end
action(1,id,'game',clone(packet));assert(cash(1)==990 and board(id).game.pot['5']==10)
action(1,id,'game',clone(packet));assert(cash(1)==990 and board(id).game.pot['5']==10)
game(1,id,'nextRound',{});assert(notices[1]=='Unknown wheel action.')
''')

scenario('fortune public view stays small with a full table',r'''
local id=place('fortune',1)
for p=1,4 do positions[p].x=0;action(p,id,'join') end
for p=1,2 do inventories[p].items[2].count=100000;for _,spot in ipairs(LightRpCasinoFortune.SPOTS) do game(p,id,'bet',{spot=spot,amount=70}) end end
for r=1,9 do fixedSpin(r,2);game(1,id,'spin',{});wall=board(id).game.spin.endsAt;assert(step(2000))
 for _,spot in ipairs(LightRpCasinoFortune.SPOTS) do game(1,id,'bet',{spot=spot,amount=99}) end end
fixedSpin(0,3);game(1,id,'spin',{})
local size=publicSize(id,1);assert(size<900,'public view '..size)
print('  public view bytes with bets, spin and result: '..size)
''')

print('Fortune server: stakes, limits, closed bets, payouts, refunds, restart and recycled seats passed')
