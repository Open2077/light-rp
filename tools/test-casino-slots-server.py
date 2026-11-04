#!/usr/bin/env python3
"""Slot machine controller: atomic stakes, server stops, exactly-once timed claims.

Reuses the durable-commit harness of tools/test-tabletop-extra-server.py (board,
inventory and claim rows commit together; the real inventory mutex) and loads
the real board_games, tabletop_extra and casino_slots modules.
"""
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
# Share only the harness, not the roulette scenarios.
source=(ROOT/'tools/test-tabletop-extra-server.py').read_text()
namespace={'__file__':str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(source.split('SOURCES=')[0],namespace)
HARNESS=namespace['HARNESS']+r'''
LightRpItems={}
-- The server picks stops with math.random(0,11); tests queue the next stops.
queuedStops={}
local realRandom=math.random
math.random=function(a,b)
 if a==0 and b==11 and #queuedStops>0 then return table.remove(queuedStops,1) end
 return realRandom(a,b)
end
function nextStops(a,b,c) queuedStops={a,b,c} end
function stopOf(r,name) for i,s in ipairs(LightRpCasinoSlots.REELS[r]) do if s==name then return i-1 end end end
function win(name) nextStops(stopOf(1,name),stopOf(2,name),stopOf(3,name)) end
function lose() nextStops(stopOf(1,'bar'),stopOf(2,'bar'),stopOf(3,'bell')) end
function setCash(player,n) for slot,v in pairs(inventories[player].items) do if v.name=='cash' then inventories[player].items[slot]=nil end end;inventories[player].items[2]={name='cash',count=n} end
function claims() local n=0;for _ in pairs(dbClaims) do n=n+1 end;return n end
'''
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'shared/casino_slots.lua',
         GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/casino_slots.lua',GAME/'server/modules/board_games.lua']
def environment():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(HARNESS)
    for path in SOURCES:
        lua.execute(path.read_text())
    lua.execute('modules.board_games.onDatabaseReady()')
    return lua


def scenario(name,script):
    lua=environment()
    lua.execute(script)
    print(name+': passed')
    return lua


scenario('slot stake is debited atomically; invalid bets and insufficient cash change nothing',r'''
local id=place('slots',1);action(1,id,'join')
assert(board(id).game.kind=='slots' and board(id).game.phase=='idle')
for _,bet in ipairs({0,-1,1.5,101,1001,'abc',0/0}) do
 local before=commits;game(1,id,'pull',{bet=bet});assert(cash(1)==1000 and commits==before and board(id).game.round==0)
end
local revision=board(id).revision
failDB=true;win('seven');game(1,id,'pull',{bet=10});failDB=false
assert(cash(1)==1000 and board(id).revision==revision and board(id).game.phase=='idle' and claims()==0)
throwDB=true;win('seven');game(1,id,'pull',{bet=10});throwDB=false
assert(cash(1)==1000 and not inventories[1].busy and claims()==0)
setCash(1,4);win('seven');game(1,id,'pull',{bet=5})
assert(cash(1)==4 and board(id).game.round==0 and notices[1]:find('Not enough cash',1,true))
setCash(1,1000);lose();game(1,id,'pull',{bet=25})
local state=board(id).game
assert(cash(1)==975 and state.phase=='spinning' and state.round==1 and state.spin.gross==0 and claims()==0)
assert(state._inventory==nil and dbBoards[id].data.game._inventory=='inv1' and state.yours==true)
assert(state.spin.endsAt-state.spin.at==3000 and state.spin.at>1790000000000)
-- one ledger line for the pull, in its own commit; the failed pulls wrote none
assert(#dbLedger==1 and #ledgerShown==1)
local line=dbLedger[1]
assert(line.inventory=='inv1' and line.game=='Slots' and line.staked==25 and line.returned==0 and line.net==-25 and line.unsettled==25)
''')

scenario('slot win: server stops, payout claim available when the reels stop, paid exactly once',r'''
local id=place('slots',1);action(1,id,'join');action(2,id,'join')
win('seven');game(1,id,'pull',{bet=5})
local state=board(id).game;local spin=state.spin
assert(cash(1)==995 and unpaid('inv1')==1000 and spin.gross==1000)
assert(#dbLedger==1 and dbLedger[1].staked==5 and dbLedger[1].returned==1000 and dbLedger[1].net==995)
assert(spin.stops[1]==stopOf(1,'seven') and spin.stops[3]==stopOf(3,'seven'))
local row;for _,r in pairs(dbClaims) do row=r end
assert(row.available_at==spin.endsAt and row.round_key:find(id,1,true)==1)
assert(board(id,2).game.yours==false and board(id,1).game.yours==true)
wall=spin.endsAt-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==995)
wall=spin.endsAt;failDB=true;LightRP.tabletopExtra.claim(1);failDB=false;assert(cash(1)==995 and unpaid('inv1')==1000)
inventories[5]=inventories[1]
duringCommit=function() LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5) end
LightRP.tabletopExtra.claim(1);assert(cash(1)==1995 and unpaid('inv1')==0)
LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5);assert(cash(1)==1995)
-- The board loop settles once the reels have stopped.
assert(step(2000));state=board(id).game
assert(state.phase=='idle' and state.last.gross==1000 and state.last.label=='Three Sevens')
assert(#dbLedger==1,'the payout writes no second line')
for _,m in ipairs(cashMoves) do assert(m.label and m.label.silent==true and m.label.kind=='casino') end
-- The jackpot is 200x the bet: at the 100 maximum it pays 20,000 (it was 200,000 at 1,000).
win('seven');game(1,id,'pull',{bet=100});state=board(id).game
assert(state.spin.gross==20000 and cash(1)==1895 and dbLedger[2].net==19900)
''')

scenario('slot: no double pull, replayed and reentrant packets never charge twice, watchers cannot pull',r'''
local id=place('slots',1);action(1,id,'join');action(2,id,'join')
lose();game(2,id,'pull',{bet=10});assert(cash(2)==1000 and board(id).game.round==0 and notices[2]:find('Only the player',1,true))
local revision=board(id).revision
local packet={revision=revision,operation='pull',data={bet=10}}
lose();duringCommit=function() lose();action(1,id,'game',{revision=revision,operation='pull',data={bet=10}}) end
action(1,id,'game',packet);assert(cash(1)==990 and board(id).game.round==1)
-- Replay of the same revision is refused; a fresh pull during the spin too.
lose();action(1,id,'game',{revision=revision,operation='pull',data={bet=10}});assert(cash(1)==990)
lose();game(1,id,'pull',{bet=10});assert(cash(1)==990 and board(id).game.round==1 and notices[1]:find('still spinning',1,true))
-- After the reels stop (even before the 2 s settlement) the next pull works.
wall=board(id).game.spin.endsAt;lose();game(1,id,'pull',{bet=10})
assert(cash(1)==980 and board(id).game.round==2 and board(id).game.spin.from[1]==stopOf(1,'bar'))
local unknown=commits;game(1,id,'spin',{});assert(commits==unknown)
''')

scenario('slot pickup/reset wait for the reels; a resolved pull needs no refund and still pays once',r'''
local id=place('slots',1);action(1,id,'join')
win('diamond');game(1,id,'pull',{bet=3})
assert(cash(1)==997 and unpaid('inv1')==300)
local revision=board(id).revision
action(1,id,'reset');assert(board(id).revision==revision and notices[1]:find('Wait for the reels',1,true))
action(1,id,'pickup');assert(board(id) and itemCount(1,'slot_machine')==0)
-- Reels stopped, settlement not run yet: pickup is allowed and adds no refund.
wall=board(id).game.spin.endsAt
local before=claims();action(1,id,'pickup')
assert(not board(id) and itemCount(1,'slot_machine')==1 and claims()==before and unpaid('inv1')==300)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1297)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1297 and unpaid('inv1')==0)
-- Reset after a settled spin starts a fresh machine without touching money.
inventories[1].items={[2]={name='cash',count=cash(1)}} -- the harness places from slot 1
id=place('slots',1);action(1,id,'join');lose();game(1,id,'pull',{bet=7});assert(board(id).game.spin,notices[1])
wall=board(id).game.spin.endsAt;assert(step(2000));assert(board(id).game.phase=='idle')
action(1,id,'reset');assert(board(id).game.round==0 and board(id).game.phase=='idle' and cash(1)==1290)
''')

lua=scenario('slot spin survives a restart and its claim pays when the reels stop',r'''
testId=place('slots',1);action(1,testId,'join');win('bell');game(1,testId,'pull',{bet=2})
testEnd=board(testId).game.spin.endsAt;assert(unpaid('inv1')==36 and cash(1)==998)
tasks={};events={};handlers={};modules={}
''')
for path in SOURCES[-3:]:
    lua.execute(path.read_text())
lua.execute(r'''
modules.board_games.onDatabaseReady()
assert(board(testId).game.phase=='spinning' and unpaid('inv1')==36)
wall=testEnd-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==998)
wall=testEnd;LightRP.tabletopExtra.claim(1);assert(cash(1)==1034 and unpaid('inv1')==0)
assert(step(2000));assert(board(testId).game.phase=='idle' and board(testId).game.last.gross==36)
''')
print('slot durable restart: passed')

scenario('slot public view stays small and private',r'''
local id=place('slots',1);action(1,id,'join')
for i=1,40 do lose();wall=wall+5000;game(1,id,'pull',{bet=1}) end
local b;for _,entry in ipairs(list(1)) do if entry.id==id then b=entry end end
local function size(t) local n=0;if type(t)=='table' then for k,v in pairs(t) do n=n+#tostring(k)+size(v)+4 end else n=#tostring(t) end;return n end
assert(b.game.round==40 and size(b.game)<900,'public slot state grew: '..size(b.game))
local function private(t) for k,v in pairs(t) do if type(k)=='string' and k:sub(1,1)=='_' then return true end;if type(v)=='table' and private(v) then return true end end end
assert(not private(b.game))
''')
print('Slot machine server: all money, persistence and view scenarios passed')
