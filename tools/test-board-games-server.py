#!/usr/bin/env python3
"""Board lifecycle/authorization regression tests with a deterministic engine harness."""
from pathlib import Path
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
function clone(t) if type(t)~='table' then return t end local n={} for k,v in pairs(t) do n[k]=clone(v) end return n end
handlers={}; uses={}; events={}; notices={}; clock=0; fail=false; throwing=false; commits=0
inventories={}; positions={}; life={}; modules={}; dbrows={}
for i=1,4 do inventories[i]={id='inv'..i,persistent=true,slots=10,items={[1]={name='chess_board',count=1}}};positions[i]={x=0,y=0,z=0,bucket=0};life[i]={phase='alive'} end
LightRpBoardGames={chess={item='chess_board'},checkers={item='checkers_board'},connect4={item='connect4_board'}}
LightRP={inventory={},db={}}
local I=LightRP.inventory
function I.player(id) return inventories[id] end
function I.draft(inv) return clone(inv) end
function I.canHold() return true end
function I.onUse(item,fn) uses[item]=fn end
function I.commitDrafts(changes,queries,after)
 commits=commits+1
 if duringCommit then local fn=duringCommit;duringCommit=nil;fn() end
 if throwing then error('db failure') end
 if fail then return false,'db_failure' end
 for _,c in ipairs(changes) do c[1].items=c[2].items end
 savedQueries=clone(queries);after();return true
end
function LightRP.db.schema() end
function LightRP.db.read() if readFailure then return false,{} end return true,dbrows end
function LightRP.notice(id,p) notices[id]=p.body end
logs={}
function LightRP.log(format,...) logs[#logs+1]=string.format(format,...) end
function LightRP.nowMs() return clock end
function LightRP.module(name,m) modules[name]=m end
Open77={players={},time={unix=function() return 424242 end}}
function Open77.players.position(id) return positions[id] end
function Open77.players.getLifeState(id) return life[id] end
function GetPlayers() return {'1','2','3','4'} end
function TriggerClientEvent(name,id,data) events[id]=clone(data) end
function RegisterNetEvent(name,fn) handlers[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
tasks={};maxResumeInstructions=0;aiResumeCount=0
function Wait(ms) return coroutine.yield(ms) end
local function resumeChecked(co)
 local spent=0
 debug.sethook(co,function()
  spent=spent+100
  if spent>25000 then error('strict server resume budget exceeded: '..spent) end
 end,'',100)
 local ok,value=coroutine.resume(co)
 debug.sethook(co)
 maxResumeInstructions=math.max(maxResumeInstructions,spent)
 aiResumeCount=aiResumeCount+1
 assert(ok,value)
 return value
end
function CreateThread(fn)
 local co=coroutine.create(fn);local delay=resumeChecked(co)
 if coroutine.status(co)~='dead' then tasks[#tasks+1]={co=co,delay=delay} end
end
function stepAI()
 for i,t in ipairs(tasks) do if t.delay==450 or t.delay==0 then
  table.remove(tasks,i);t.delay=resumeChecked(t.co)
  if coroutine.status(t.co)~='dead' then tasks[#tasks+1]=t end
  return true
 end end return false
end
function drainAI()
 for i,t in ipairs(tasks) do if t.delay==450 or t.delay==0 then
  table.remove(tasks,i)
  local count=0
  repeat
   t.delay=resumeChecked(t.co);count=count+1;assert(count<10000,'unbounded AI search')
  until coroutine.status(t.co)=='dead' or t.delay~=0
  if coroutine.status(t.co)~='dead' then tasks[#tasks+1]=t end
  return true
 end end return false
end
json={encode=function(v) return v end,decode=function(v) return v end}
function request(id,p) source=id;clock=clock+200;handlers['lightrp:boardGames:request'](p) end
function count(id,item) local n=0 for _,v in pairs(inventories[id].items) do if v.name==item then n=n+v.count end end return n end
function boards(id) request(id,{action='sync'}); return events[id].boards end
''')
lua.execute((root/'resources/gamemodes/op77_lightrp/shared/board_games_rules.lua').read_text())
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute('''
modules.board_games.onDatabaseReady()
-- Placement requires inventory use ticket; rejected placement retains item.
request(1,{action='place',kind='chess',position={x=0,y=0,z=0}}); assert(#boards(1)==0 and count(1,'chess_board')==1)
uses.chess_board(1);fail=true
request(1,{action='place',kind='chess',position={x=0,y=0,z=0}}); assert(#boards(1)==0 and count(1,'chess_board')==1)
fail=false;request(1,{action='place',kind='chess',position={x=0,y=0,z=0}})
local b=boards(1)[1];assert(b and count(1,'chess_board')==0)
local id=b.id
request(1,{action='place',kind='chess',position={x=3,y=0,z=0}});assert(#boards(1)==1)
-- Ownership, proximity, routing bucket on pickup.
request(2,{action='pickup',boardId=id});assert(#boards(1)==1 and count(2,'chess_board')==1)
positions[1].bucket=1;request(1,{action='pickup',boardId=id});positions[1].bucket=0;assert(#boards(1)==1)
positions[1].x=10;request(1,{action='pickup',boardId=id});positions[1].x=0;assert(#boards(1)==1)
-- Seat authorization, replay revision and transaction failures preserve game.
request(1,{action='join',boardId=id});request(2,{action='join',boardId=id});request(3,{action='join',boardId=id})
assert(boards(1)[1].players.black==2)
local move={action='move',boardId=id,revision=0,fromRow=7,fromCol=5,toRow=5,toCol=5}
request(3,move);assert(boards(1)[1].revision==0)
positions[2].bucket=1;request(1,move);positions[2].bucket=0;assert(boards(1)[1].revision==0)
fail=true;request(1,move);fail=false;assert(boards(1)[1].revision==0)
throwing=true;request(1,move);throwing=false;assert(not inventories[1].busy)
-- Reentrant request during commit cannot duplicate a move.
duringCommit=function() request(1,move) end
local before=commits;request(1,move);assert(commits==before+1 and boards(1)[1].revision==1)
request(1,move);assert(boards(1)[1].revision==1)
local black={action='move',boardId=id,revision=0,fromRow=2,fromCol=5,toRow=4,toCol=5}
request(2,black);assert(boards(1)[1].revision==1)
black.revision=1;request(2,black);assert(boards(1)[1].revision==2)
-- Pickup atomically restores item; database refusal leaves board and item unchanged.
fail=true;request(1,{action='pickup',boardId=id});fail=false;assert(#boards(1)==1 and count(1,'chess_board')==0)
request(1,{action='pickup',boardId=id});assert(#boards(1)==0 and count(1,'chess_board')==1)
request(1,{action='pickup',boardId=id});assert(count(1,'chess_board')==1)
-- Ticket expires and cannot be used for a different character inventory.
uses.chess_board(1);clock=clock+120001;request(1,{action='place',kind='chess',position={x=0,y=0,z=0}});assert(#boards(1)==0)
uses.chess_board(1);inventories[1].id='different';request(1,{action='place',kind='chess',position={x=0,y=0,z=0}});assert(#boards(1)==0)
''')
# Reload the actual module to simulate an engine restart (new private board/session tables).
lua.execute("""
dbrows={{id='restored',owner_inventory='inv1',data={kind='chess',bucket=0,position={x=0,y=0,z=0},rotation=0,revision=7,game=LightRPBoardRules.new('chess'),owner=99,players={white=99,black=98}}}}
inventories[1].id='old-character';inventories[2].id='inv1';inventories[2].items={};
""")
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute("""
modules.board_games.onDatabaseReady()
local b=boards(2)[1]; assert(b.id=='restored' and b.owner==nil and b.owned==true and next(b.players)==nil and b.revision==7)
assert(boards(1)[1].owned==false)
request(1,{action='pickup',boardId='restored'}); assert(#boards(2)==1)
request(2,{action='pickup',boardId='restored'}); assert(#boards(2)==0 and count(2,'chess_board')==1)
""")
# Same-second restart identifiers and independent-player concurrent placement.
lua.execute("""
originalTime=Open77.time.unix;Open77.time.unix=function() return 424242 end
inventories[1].id='inv1';inventories[2].id='inv2'
for i=1,2 do inventories[i].items={[1]={name='chess_board',count=1}} end
dbrows={{id='424242:1',owner_inventory='inv3',data={kind='chess',bucket=0,position={x=3,y=0,z=0},rotation=0,revision=0,game=LightRPBoardRules.new('chess')}}}
""")
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute("""
modules.board_games.onDatabaseReady()
uses.chess_board(1);uses.chess_board(2)
local placement={action='place',kind='chess',position={x=0,y=0,z=0}}
duringCommit=function() request(2,placement) end
local before=commits
request(1,placement)
assert(commits==before+1 and #boards(1)==2 and count(1,'chess_board')==0 and count(2,'chess_board')==1)
local found={};for _,b in ipairs(boards(1)) do found[b.id]=b end
assert(found['424242:1'] and found['424242:1'].position.x==3 and found['424242:2'] and found['424242:2'].position.x==0)
-- Retry at the occupied point still fails proximity; a free point succeeds without reusing item.
request(2,placement);assert(#boards(1)==2 and count(2,'chess_board')==1)
placement.position.x=-3;request(2,placement);assert(#boards(1)==3 and count(2,'chess_board')==0)
-- An exception also releases the global placement lock for a subsequent player.
request(1,{action='pickup',boardId='424242:2'});uses.chess_board(1)
throwing=true;request(1,{action='place',kind='chess',position={x=0,y=0,z=0}});throwing=false
assert(count(1,'chess_board')==1)
request(1,{action='place',kind='chess',position={x=0,y=0,z=0}});assert(count(1,'chess_board')==0 and #boards(1)==3)
Open77.time.unix=originalTime
-- Restore an available counted item for the failed-read assertion below.
inventories[2].items={[1]={name='chess_board',count=1}}
""")
# A failed startup read leaves inventory use and placement disabled, with no consumption.
lua.execute('readFailure=true')
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute("""
modules.board_games.onDatabaseReady()
assert(uses.chess_board(2)==false)
local before=commits
request(2,{action='place',kind='chess',position={x=0,y=0,z=0}})
assert(#boards(2)==0 and count(2,'chess_board')==1 and commits==before)
""")
# Exercise modes with fresh private server tables and an explicit coroutine scheduler.
lua.execute("""
readFailure=false;dbrows={};tasks={};fail=false;throwing=false
for i=1,4 do inventories[i].id='inv'..i;inventories[i].items={[1]={name='connect4_board',count=1}};positions[i]={x=0,y=0,z=0,bucket=0} end
""")
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute("""
modules.board_games.onDatabaseReady()
uses.connect4_board(1);request(1,{action='place',kind='connect4',position={x=0,y=0,z=0}})
local b=boards(1)[1];testBoardId=b.id;assert(b.kind=='connect4' and count(1,'connect4_board')==0)
function action(id,a,fields) local p=fields or {};p.action=a;p.boardId=testBoardId;request(id,p) end
function board() return boards(1)[1] end
function drop(id,c) action(id,'move',{revision=board().revision,fromRow=0,fromCol=c,toRow=1,toCol=c}) end
-- Duel accepts two players; mode changes and reset require ownership.
action(1,'join');action(2,'join');action(3,'join');assert(board().players.black==2 and not board().players.white2)
action(2,'mode',{mode='teams'});assert(board().mode=='duel')
action(2,'reset');assert(board().revision==0)
action(1,'mode',{mode='teams'});assert(board().mode=='teams' and board().players.white==1 and not board().ready)
action(2,'join');action(3,'join');assert(not board().ready and not board().actor)
drop(1,1);assert(board().game.ply==0)
action(4,'join');assert(board().ready and board().actor==1 and board().players.white2==3 and board().players.black2==4)
-- Teams alternate actors white1,black1,white2,black2, then return to white1.
for _,step in ipairs({{1,1,2},{2,2,3},{3,3,4},{4,4,1}}) do drop(step[1],step[2]);assert(board().actor==step[3]) end
assert(board().moveSequence==4 and board().lastSound=='connect4-drop')
local revision=board().revision;action(1,'mode',{mode='solo'});assert(board().mode=='teams' and board().revision==revision)
action(1,'reset');assert(board().mode=='teams' and board().game.ply==0 and not board().ready)
action(1,'mode',{mode='solo'});assert(board().ready and board().actor==1 and not board().players.black)
action(2,'join');assert(not board().players.black)
-- Only the human owner can play white; black is exclusively AI.
drop(2,2);assert(board().game.ply==0)
drop(1,4);assert(board().game.ply==1 and board().actor==0)
drop(1,3);drop(2,3);assert(board().game.ply==1)
assert(drainAI());assert(board().game.ply==2 and board().actor==1 and board().revision==revision+4)
-- Failed AI commit preserves board/revision and releases its lock.
drop(1,3);local before=board();fail=true;assert(drainAI());fail=false
assert(board().revision==before.revision and board().game.ply==3)
-- Any subsequent request retries the AI turn; accepted AI result is legal.
action(2,'join');assert(drainAI());assert(board().game.ply==4 and board().actor==1)
-- Reset cancels an old AI callback even if a new game reaches black's turn first.
drop(1,2);assert(board().actor==0)
action(1,'reset');assert(board().game.ply==0 and board().actor==1)
assert(savedQueries[1].values[3].mode=='solo')
drop(1,5);local current=board().revision
assert(drainAI());assert(board().revision==current and board().game.ply==1)
assert(drainAI());assert(board().revision==current+1 and board().game.ply==2)
-- Pending delayed AI must not mutate a picked-up board or consume another item.
drop(1,2);assert(board().actor==0)
action(1,'pickup');assert(#boards(1)==0 and count(1,'connect4_board')==1)
assert(drainAI());assert(#boards(1)==0 and count(1,'connect4_board')==1)
""")
# Forced checker capture chains retain the team actor until the complete turn ends.
lua.execute("""
local game=LightRPBoardRules.new('checkers')
for r=1,10 do for c=1,10 do game.board[r][c]=false end end
game.board[6][3]={id=1,side='white',kind='man'};game.board[5][4]={id=2,side='black',kind='man'};game.board[3][6]={id=3,side='black',kind='man'};game.board[1][2]={id=4,side='black',kind='man'}
dbrows={{id='teams-restored',owner_inventory='inv1',data={kind='checkers',bucket=0,position={x=0,y=0,z=0},rotation=0,revision=3,mode='teams',game=game}},
{id='solo-restored',owner_inventory='inv2',data={kind='connect4',bucket=0,position={x=3,y=0,z=0},rotation=0,revision=9,mode='solo',game=LightRPBoardRules.new('connect4')}}}
tasks={}
""")
lua.execute((root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text())
lua.execute("""
modules.board_games.onDatabaseReady()
local found={};for _,b in ipairs(boards(1)) do found[b.id]=b end
assert(found['teams-restored'].mode=='teams' and found['solo-restored'].mode=='solo')
assert(next(found['teams-restored'].players)==nil and not found['solo-restored'].ready)
testBoardId='teams-restored'
function board() for _,b in ipairs(boards(1)) do if b.id==testBoardId then return b end end end
for i=1,4 do action(i,'join') end
assert(board().ready and board().actor==1)
action(1,'move',{revision=3,fromRow=6,fromCol=3,toRow=4,toCol=5})
assert(board().game.chain and board().game.ply==0 and board().actor==1)
action(3,'move',{revision=4,fromRow=4,fromCol=5,toRow=2,toCol=7});assert(board().revision==4)
action(1,'move',{revision=4,fromRow=4,fromCol=5,toRow=2,toCol=7})
assert(not board().game.chain and board().game.ply==1 and board().actor==2 and board().lastSound=='checkers-capture')
""")
# Run the real AI for all three solo games under the strict per-resume scheduler.
server_source = (root/'resources/gamemodes/op77_lightrp/server/modules/board_games.lua').read_text()
for kind in ('chess', 'checkers', 'connect4'):
    lua.globals().testKind = kind
    lua.execute("""
readFailure=false;tasks={};dbrows={};fail=false;throwing=false
inventories[1].items={[1]={name=LightRpBoardGames[testKind].item,count=1}}
""")
    lua.execute(server_source)
    lua.execute("""
modules.board_games.onDatabaseReady()
local item=LightRpBoardGames[testKind].item
uses[item](1);request(1,{action='place',kind=testKind,position={x=0,y=0,z=0}})
testBoardId=boards(1)[1].id
function board() return boards(1)[1] end
action(1,'join');action(1,'mode',{mode='solo'})
function humanMove()
 local m=LightRPBoardRules.legalMoves(board().game)[1];assert(m)
 action(1,'move',{revision=board().revision,fromRow=m.fromRow,fromCol=m.fromCol,toRow=m.toRow,toCol=m.toCol,promotion=m.promotion})
end
local errors=#logs
humanMove();local previous=board().revision
assert(stepAI(),'AI was not scheduled');assert(board().game.ply==1,'AI search must yield before committing')
assert(drainAI());assert(board().revision==previous+1 and board().game.ply==2 and #logs==errors)
-- Reset is available during expensive analysis, and cancels every old search slice.
humanMove();assert(stepAI());local beforeReset=board().revision
action(1,'reset');assert(board().revision==beforeReset+1 and board().game.ply==0)
assert(drainAI());assert(board().game.ply==0 and #logs==errors)
-- Pickup during search also succeeds immediately and prevents the old result committing.
humanMove();assert(stepAI());action(1,'pickup');assert(#boards(1)==0 and count(1,item)==1)
assert(drainAI());assert(#boards(1)==0 and count(1,item)==1 and #logs==errors)
""")
# A complete black checker chain schedules and saves each forced step, without changing actor.
lua.execute("""
local game=LightRPBoardRules.new('checkers');for r=1,10 do for c=1,10 do game.board[r][c]=false end end
game.turn='black';game.board[5][4]={id=1,side='black',kind='man'};game.board[6][5]={id=2,side='white',kind='man'};game.board[8][7]={id=3,side='white',kind='man'};game.board[10][1]={id=4,side='white',kind='man'}
dbrows={{id='solo-chain',owner_inventory='inv1',data={kind='checkers',mode='solo',bucket=0,position={x=0,y=0,z=0},rotation=0,revision=0,game=game}}};tasks={}
""")
lua.execute(server_source)
lua.execute("""
modules.board_games.onDatabaseReady();testBoardId='solo-chain';action(1,'join');assert(board().actor==0)
assert(drainAI());assert(board().game.chain and board().actor==0 and board().revision==1)
assert(drainAI());assert(not board().game.chain and board().actor==1 and board().revision==2 and #board().game.captured==2)
-- The server journal records the exact failure, not only a generic player notice.
local real=LightRPBoardRules.aiMove
LightRPBoardRules.aiMove=function() error('precise AI diagnostic probe') end
local errors=#logs;humanMove();local revision=board().revision
assert(drainAI());assert(board().revision==revision and #logs==errors+1 and logs[#logs]:find('precise AI diagnostic probe',1,true))
LightRPBoardRules.aiMove=real
print('AI server strict scheduler: worst '..maxResumeInstructions..' instructions/resume across '..aiResumeCount..' resumes')
assert(maxResumeInstructions<=25000)
""")
lua.execute("""
-- Stop telemetry is bounded, sanitized and independent from gameplay throttling.
local handle=handlers['lightrp:boardGames:request'];source=4;clock=clock+3000
local prior=#logs
handle({action='diagnostic',event='stop',reason='client_error',boardId='solo-chain',details='line 258'..string.char(10)..'probe'})
assert(#logs==prior+1 and not logs[#logs]:find(string.char(10),1,true))
handle({action='diagnostic',event='stop',reason='ui_leave'});assert(#logs==prior+1)
events[4]=nil;handle({action='sync'});assert(events[4] and events[4].boards,'diagnostics consumed the gameplay rate budget')
clock=clock+3000;handle({action='diagnostic',event='stop',reason=string.rep('x',65)});assert(#logs==prior+1)
""")
lua.execute("dbrows={};tasks={};inventories[1].items={[1]={name='chess_board',count=70}}")
lua.execute(server_source)
lua.execute("""
modules.board_games.onDatabaseReady()
for i=1,70 do
 positions[1].x=i*2;positions[1].y=0;positions[1].z=0;positions[1].bucket=0
 assert(uses.chess_board(1)=='keep')
 request(1,{action='place',kind='chess',position={x=i*2,y=0,z=0}})
end
assert(#boards(1)==70,'placement count limits must remain removed')
""")
print('board games server: lifecycle, ownership, replay, transactions, restart, teams, cooperative AI, diagnostics and 70 unlimited placements passed')
