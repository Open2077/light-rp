#!/usr/bin/env python3
"""Authoritative controller and atomic RP-money regressions (Python + lupa).

The harness commits staged board, inventory and claim rows together. It mirrors
Inv.transaction's real shared-inventory mutex, including reentrant requests and
failures, and reloads the real modules against the same durable rows.
"""
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
HARNESS=r'''
function clone(t) if type(t)~='table' then return t end local n={} for k,v in pairs(t) do n[k]=clone(v) end return n end
wall=1790000000000;clock=0;logs={};notices={};events={};handlers={};modules={};uses={};tasks={}
dbBoards={};dbClaims={};dbInventories={};inventories={};positions={};life={}
failDB=false;throwDB=false;readFailure=false;cashFull=false;commits=0
for i=1,5 do
 inventories[i]={id='inv'..i,persistent=true,slots=10,kind='player',items={[1]={name='roulette_board',count=1},[2]={name='cash',count=1000}}}
 positions[i]={x=0,y=0,z=0,bucket=0};life[i]={phase='alive'}
end
LightRpBoardGames={chess={item='chess_board'},checkers={item='checkers_board'},connect4={item='connect4_board'},roulette={item='roulette_board'}}
LightRP={inventory={},db={ready=true}}
local I,Db=LightRP.inventory,LightRP.db
function I.player(id) return inventories[id] end
function I.draft(inv) return {slots=inv.slots,items=clone(inv.items)} end
function I.canHold() return true end
function I.onUse(item,fn) uses[item]=fn end
function I.cashOf(inv) local n=0;for _,v in pairs(inv.items) do if v.name=='cash' then n=n+v.count end end;return n end
function I.adjustCash(draft,delta)
 local after=I.cashOf(draft)+delta
 if after<0 then return false,'insufficient_funds' end
 if cashFull and delta>0 then return false,'inventory_full' end
 for slot,v in pairs(draft.items) do if v.name=='cash' then draft.items[slot]=nil end end
 if after>0 then for i=1,draft.slots do if not draft.items[i] then draft.items[i]={name='cash',count=after};return true end end;return false,'inventory_full' end
 return true
end
function I.releaseBusy(inv) inv.busy=nil end
function I.transaction(player,fn)
 local inv=I.player(player);if not inv then return false,'no_inventory' end
 if inv.busy then return false,'busy' end
 inv.busy=true
 local result=table.pack(pcall(fn,inv));I.releaseBusy(inv)
 if not result[1] then error(result[2]) end
 return table.unpack(result,2,result.n)
end
function I.commitDrafts(changes,queries,after)
 commits=commits+1
 local nextBoards,nextClaims,nextInventories=clone(dbBoards),clone(dbClaims),clone(dbInventories)
 for _,q in ipairs(queries or {}) do local sql,v=q.query,q.values
  if sql:find('INSERT INTO lightrp_board_games',1,true) then nextBoards[v[1]]={id=v[1],owner_inventory=v[2],data=clone(v[3])}
  elseif sql:find('DELETE FROM lightrp_board_games',1,true) then nextBoards[v[1]]=nil
  elseif sql:find('INSERT INTO lightrp_roulette_claims',1,true) then
   local key=v[1]..'|'..v[2];if nextClaims[key] then return false,'duplicate_claim' end
   nextClaims[key]={round_key=v[1],inventory_id=v[2],amount=v[3],available_at=v[4],paid=0}
  elseif sql:find('UPDATE lightrp_roulette_claims SET paid=1',1,true) then
   local row=nextClaims[v[1]..'|'..v[2]];if row and row.paid==0 then row.paid=1 end
  else error('unhandled transaction query: '..sql) end
 end
 for _,c in ipairs(changes) do nextInventories[c[1].id]=clone(c[2].items) end
 if duringCommit then local fn=duringCommit;duringCommit=nil;fn() end
 if throwDB then error('injected SQL transaction exception') end
 if failDB then return false,'injected_db_failure' end
 dbBoards,dbClaims,dbInventories=nextBoards,nextClaims,nextInventories
 if crashAfterCommit then error('simulated process crash after durable commit') end
 for _,c in ipairs(changes) do c[1].items=c[2].items end
 if after then after() end
 return true
end
function Db.schema() end
function Db.read(sql,values)
 if readFailure then return false,{} end
 if sql:find('FROM lightrp_board_games',1,true) then local out={};for _,row in pairs(dbBoards) do out[#out+1]=clone(row) end;return true,out end
 if sql:find('FROM lightrp_roulette_claims',1,true) then
  local out={};for _,row in pairs(dbClaims) do if row.inventory_id==values[1] and row.paid==0 and row.available_at<=values[2] then out[#out+1]=clone(row) end end
  table.sort(out,function(a,b) return a.available_at<b.available_at end)
  while #out>30 do table.remove(out) end
  return true,out
 end
 error('unhandled read query '..sql)
end
function LightRP.notice(id,p) notices[id]=p.body end
function LightRP.log(format,...) logs[#logs+1]=string.format(format,...) end
function LightRP.nowMs() return clock end
function LightRP.module(name,module) modules[name]=module end
Open77={players={},time={unix=function() return wall/1000 end}}
function Open77.players.position(id) return positions[id] end
function Open77.players.getLifeState(id) return life[id] end
function GetPlayers() return {'1','2','3','4','5'} end
-- Reassemble numbered state parts the way the client does.
function TriggerClientEvent(name,id,data)
 local part=clone(data);local previous=events[id]
 if type(part)=='table' and part.parts and part.part>1 and previous and previous.seq==part.seq then
  for _,b in ipairs(part.boards) do previous.boards[#previous.boards+1]=b end
 else events[id]=part end
end
function RegisterNetEvent(name,fn) handlers[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function Wait(ms) return coroutine.yield(ms) end
local function resumeTask(t)
 local ok,delay=coroutine.resume(t.co);assert(ok,delay)
 t.delay=delay
 return coroutine.status(t.co)~='dead'
end
function CreateThread(fn) local t={co=coroutine.create(fn)};if resumeTask(t) then tasks[#tasks+1]=t end end
function step(delay)
 for i,t in ipairs(tasks) do if t.delay==delay then table.remove(tasks,i);if resumeTask(t) then tasks[#tasks+1]=t end;return true end end;return false
end
function drainAI()
 local count=0
 while true do local found=false
  for i,t in ipairs(tasks) do if t.delay==450 or t.delay==0 then table.remove(tasks,i);if resumeTask(t) then tasks[#tasks+1]=t end;found=true;break end end
  if not found then return count end
  count=count+1;assert(count<3000,'unbounded scheduled AI')
 end
end
json={encode=function(t) return clone(t) end,decode=function(t) return clone(t) end}
function request(id,p) source=id;clock=clock+200;wall=wall+200;handlers['lightrp:boardGames:request'](p) end
function list(id) request(id,{action='sync'});return events[id].boards end
function board(id,player) for _,b in ipairs(list(player or 1)) do if b.id==id then return b end end end
function action(player,id,a,p) p=p or {};p.action=a;p.boardId=id;request(player,p) end
function game(player,id,operation,data)
 local b=assert(board(id,player));action(player,id,'game',{revision=b.revision,operation=operation,data=data or {}})
end
function cash(id) return I.cashOf(inventories[id]) end
function itemCount(player,name) local n=0;for _,v in pairs(inventories[player].items) do if v.name==name then n=n+v.count end end;return n end
function place(kind,player,x,y)
 local spec=LightRpBoardGames[kind];inventories[player].items[1]={name=spec.item,count=1}
 positions[player].x=x or 0;positions[player].y=y or 0
 uses[spec.item](player);request(player,{action='place',kind=kind,position={x=x or 0,y=y or 0,z=0}})
 local id
 for key,row in pairs(dbBoards) do if row.owner_inventory==inventories[player].id and row.data.kind==kind and row.data.position.x==(x or 0) and row.data.position.y==(y or 0) then id=key end end
 return assert(id,'placement failed')
end
function unpaid(inventory)
 local n=0;for _,row in pairs(dbClaims) do if row.inventory_id==inventory and row.paid==0 then n=n+row.amount end end;return n
end
function fixedOutcome(number)
 local real=math.random
 math.random=function(a,b) if a==0 and b==36 then return number end;if a==nil then return .25 end;return real(a,b) end
end
'''
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/board_games.lua']
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


scenario('roulette atomic debit / server outcome / timed exactly-once claims',r'''
local id=place('roulette',1);action(1,id,'join');action(2,id,'join')
local initial=cash(1);local revision=board(id).revision
failDB=true;game(1,id,'bet',{bet=0,amount=10});failDB=false
assert(cash(1)==initial and board(id).revision==revision and #board(id).game.bets==0)
throwDB=true;game(1,id,'bet',{bet=0,amount=10});throwDB=false
assert(cash(1)==initial and not inventories[1].busy)
game(1,id,'bet',{bet=0,amount=initial+1});assert(cash(1)==initial)
game(1,id,'bet',{bet=0,amount=10});assert(cash(1)==initial-10 and board(id).game.yourStake==10)
assert(not board(id).game._money and not board(id).game._roundKey)
assert(dbBoards[id].data.game._money[1].inventory=='inv1')
fixedOutcome(0);revision=board(id).revision
failDB=true;game(1,id,'spin',{outcome=36});failDB=false
assert(board(id).revision==revision and board(id).game.phase=='betting' and unpaid('inv1')==0)
game(1,id,'spin',{outcome=36,nowMs=0,seedAngle=0})
local state=board(id).game;assert(state.spin.outcome==0 and state.spin.startedAt>1790000000000 and state.spin.seedAngle==90)
assert(unpaid('inv1')==360 and cash(1)==initial-10)
local ends=state.spin.endsAt;wall=ends-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==initial-10)
wall=ends;failDB=true;LightRP.tabletopExtra.claim(1);failDB=false
assert(cash(1)==initial-10 and unpaid('inv1')==360)
throwDB=true;LightRP.tabletopExtra.claim(1);throwDB=false;assert(cash(1)==initial-10 and not inventories[1].busy)
-- Same inventory mutex and per-player payment guard reject reentrant claims.
inventories[5]=inventories[1]
duringCommit=function() LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5) end
LightRP.tabletopExtra.claim(1);assert(cash(1)==initial+350 and unpaid('inv1')==0)
LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(5);assert(cash(1)==initial+350)
assert(step(2000));assert(board(id).game.phase=='result')
game(1,id,'nextRound',{});assert(board(id).game.phase=='betting' and #board(id).game.bets==0)
''')

scenario('roulette refunds bind durable character inventories and commit atomically',r'''
local id=place('roulette',1);action(1,id,'join');action(2,id,'join')
game(1,id,'bet',{bet='red',amount=25});game(2,id,'bet',{bet=4,amount=40})
assert(cash(1)==975 and cash(2)==960)
local old=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='replacement-character',persistent=true,slots=10,items={[2]={name='cash',count=700}}}
action(2,id,'join');assert(board(id,2).game.yourStake==0)
local revision=board(id).revision
failDB=true;action(1,id,'reset');failDB=false
assert(board(id).revision==revision and unpaid('inv1')==0 and unpaid('inv2')==0)
action(1,id,'reset');assert(board(id).game.phase=='betting' and #board(id).game.bets==0)
assert(unpaid('inv1')==25 and unpaid('inv2')==40 and unpaid('replacement-character')==0)
LightRP.tabletopExtra.claim(2);assert(cash(2)==700 and unpaid('inv2')==40)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1000)
inventories[3]=old;LightRP.tabletopExtra.claim(3);assert(cash(3)==1000 and unpaid('inv2')==0)
-- Picking the table up refunds open bets in the same delete/item transaction.
action(1,id,'join');game(1,id,'bet',{bet='black',amount=15});assert(cash(1)==985)
failDB=true;action(1,id,'pickup');failDB=false
assert(board(id) and itemCount(1,'roulette_board')==0 and unpaid('inv1')==0)
action(1,id,'pickup');assert(not board(id) and itemCount(1,'roulette_board')==1 and unpaid('inv1')==15)
LightRP.tabletopExtra.claim(1);assert(cash(1)==1000)
''')

scenario('roulette spinning blocks reset and pickup even with no wagers',r'''
local id=place('roulette',1);action(1,id,'join');fixedOutcome(12);game(1,id,'spin',{})
local revision=board(id).revision
assert(board(id).game.phase=='spinning')
action(1,id,'reset');assert(board(id).revision==revision and board(id).game.phase=='spinning','empty-stake spin reset was allowed')
action(1,id,'pickup');assert(board(id) and itemCount(1,'roulette_board')==0,'empty-stake spinning board was picked up')
''')


lua=scenario('roulette claims survive failed storage, full inventories and settlement exceptions',r''' 
local id=place('roulette',1);action(1,id,'join');game(1,id,'bet',{bet=7,amount=10});fixedOutcome(7);game(1,id,'spin',{})
local ends=board(id).game.spin.endsAt;wall=ends
local errors=#logs;readFailure=true;LightRP.tabletopExtra.claim(1);readFailure=false
assert(cash(1)==990 and unpaid('inv1')==360 and #logs>errors)
wall=wall+11000;errors=#logs;cashFull=true;LightRP.tabletopExtra.claim(1);cashFull=false
assert(cash(1)==990 and unpaid('inv1')==360 and #logs>errors)
wall=wall+11000;errors=#logs;throwDB=true;assert(step(2000));throwDB=false
assert(board(id).game.phase=='spinning' and #logs>errors,'settlement exception was not logged/released')
assert(step(2000));assert(board(id).game.phase=='result','maintenance did not recover after SQL exception')
LightRP.tabletopExtra.claim(1);assert(cash(1)==1350 and unpaid('inv1')==0)
''')

lua=scenario('roulette pending durable claims prepared before process restart',r''' 
testId=place('roulette',1);action(1,testId,'join');game(1,testId,'bet',{bet=0,amount=12});fixedOutcome(0);game(1,testId,'spin',{})
testEnd=board(testId).game.spin.endsAt;assert(unpaid('inv1')==432 and cash(1)==988)
tasks={};events={};handlers={};modules={}
''')
for path in SOURCES[-2:]:
    lua.execute(path.read_text())
lua.execute(r''' 
modules.board_games.onDatabaseReady()
assert(board(testId).game.phase=='spinning' and next(board(testId).players)==nil and unpaid('inv1')==432)
wall=testEnd-1;LightRP.tabletopExtra.claim(1);assert(cash(1)==988)
-- Simulate a process crash after BOTH inventory and paid marker are durable,
-- before the old process publishes its in-memory inventory update.
wall=testEnd;crashAfterCommit=true;LightRP.tabletopExtra.claim(1);crashAfterCommit=false
assert(cash(1)==988 and unpaid('inv1')==0)
inventories[1].items=clone(dbInventories.inv1);assert(cash(1)==1420)
tasks={};modules={}
''')
lua.execute(SOURCES[-2].read_text())
lua.execute("LightRP.tabletopExtra.claim(1);assert(cash(1)==1420 and unpaid('inv1')==0)")
print('roulette durable restart / crash exactly-once payout: passed')

scenario('placement has no old per-owner-three or global-sixty-four cap',r''' 
local ids={}
for i=1,70 do local id=place('roulette',1,i*2,0);assert(not ids[id]);ids[id]=true end
local total=0;for _ in pairs(dbBoards) do total=total+1 end;assert(total==70 and #list(1)==70)
''')
scenario('roulette money RPC rejects replay, bad bets and reentrant double charging',r''' 
local id=place('roulette',1);action(1,id,'join')
for _,data in ipairs({{bet='invalid',amount=10},{bet='red',amount=-1},{bet='red',amount=1.5},{bet='red',amount=1000001},{bet={forged=true},amount=10}}) do
 local before=commits;game(1,id,'bet',data);assert(cash(1)==1000 and commits==before)
end
local revision=board(id).revision
local packet={revision=revision,operation='bet',data={bet='red',amount=10}}
duringCommit=function() action(1,id,'game',clone(packet)) end
action(1,id,'game',clone(packet));assert(cash(1)==990 and #board(id).game.bets==1)
action(1,id,'game',clone(packet));assert(cash(1)==990 and #board(id).game.bets==1)
game(1,id,'nextRound',{});assert(cash(1)==990 and board(id).game.phase=='betting')
''')

scenario('roulette winning claims cannot follow a recycled seat to another character',r''' 
local id=place('roulette',1);action(1,id,'join');action(2,id,'join')
game(1,id,'bet',{bet='red',amount=10});game(2,id,'bet',{bet=0,amount=7})
local original=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='new-character',persistent=true,slots=10,items={[2]={name='cash',count=700}}};action(2,id,'join')
game(2,id,'bet',{bet='black',amount=5});fixedOutcome(0);game(1,id,'spin',{})
assert(unpaid('inv2')==252 and unpaid('new-character')==0 and unpaid('inv1')==0)
wall=board(id).game.spin.endsAt;LightRP.tabletopExtra.claim(2);assert(cash(2)==695 and unpaid('inv2')==252)
inventories[3]=original;LightRP.tabletopExtra.claim(3);assert(cash(3)==1245 and unpaid('inv2')==0)
assert(step(2000));assert(board(id).game.phase=='result')
action(1,id,'pickup');assert(not board(id) and unpaid('inv1')==0 and unpaid('new-character')==0)
LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(2);assert(cash(1)==990 and cash(2)==695)
''')

print('Extra tabletop server: all money, persistence and uncapped-placement scenarios passed')
