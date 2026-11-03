#!/usr/bin/env python3
"""Engine-independent regression tests; requires Python lupa."""
from pathlib import Path
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((Path(__file__).resolve().parents[1] / 'resources/gamemodes/op77_lightrp/shared/board_games_rules.lua').read_text())
lua.execute('''
local R=LightRPBoardRules
local function move(s,...) local n,e=R.move(s,...) assert(n,e) return n end
local function reject(s,...) local n=R.move(s,...) assert(not n,'illegal move accepted') end
local function empty(kind)
 local s=R.new(kind) for r=1,s.size do for c=1,s.size do s.board[r][c]=false end end return s
end
local function p(id,side,kind) return {id=id,side=side,kind=kind} end
local s=R.new('chess') assert(s.board[8][5].kind=='king')
reject(s,7,5,4,5) reject(s,2,5,3,5) reject(s,7,5,6.5,5)
local n=move(s,7,5,5,5) assert(s.board[7][5] and not s.board[5][5]); assert(n.turn=='black')
-- Fool's mate, then frozen terminal state.
s=R.new('chess') s=move(s,7,6,6,6) s=move(s,2,5,4,5) s=move(s,7,7,5,7) s=move(s,1,4,5,8)
assert(s.status=='won' and s.winner=='black' and s.check) reject(s,7,1,6,1)
-- En passant is removed after the immediately following ply.
s=R.new('chess') s=move(s,7,5,5,5) s=move(s,2,1,3,1) s=move(s,5,5,4,5) s=move(s,2,4,4,4) s=move(s,4,5,3,4)
assert(not s.board[4][4] and #s.captured==1)
-- Castling moves both pieces and rejects castling through attack.
s=empty('chess'); s.board[8][5]=p(1,'white','king'); s.board[8][8]=p(2,'white','rook'); s.board[1][5]=p(3,'black','king')
n=move(s,8,5,8,7); assert(n.board[8][6].kind=='rook' and not n.board[8][8])
s.board[1][6]=p(4,'black','rook'); reject(s,8,5,8,7)
-- Underpromotion and king safety.
s=empty('chess'); s.board[8][5]=p(1,'white','king'); s.board[1][8]=p(2,'black','king'); s.board[2][1]=p(3,'white','pawn')
n=move(s,2,1,1,1,'knight'); assert(n.board[1][1].kind=='knight')
s.board[7][5]=p(4,'white','rook'); s.board[1][5]=p(5,'black','rook'); reject(s,7,5,7,4)
-- Threefold repetition and insufficient mating material.
s=R.new('chess')
for cycle=1,2 do s=move(s,8,7,6,6); s=move(s,1,7,3,6); s=move(s,6,6,8,7); s=move(s,3,6,1,7) end
assert(s.status=='draw')
s=empty('chess'); s.board[8][5]=p(1,'white','king'); s.board[1][5]=p(2,'black','king'); s=move(s,8,5,8,4); assert(s.status=='draw')
-- Checkers opening, compulsory capture, backwards capture, longest sequence.
s=R.new('checkers'); assert(s.size==10 and s.board[10][1]); s=move(s,7,2,6,1); assert(s.turn=='black')
s=empty('checkers'); s.board[6][3]=p(1,'white','man'); s.board[5][4]=p(2,'black','man'); s.board[3][6]=p(3,'black','man'); s.board[7][4]=p(4,'black','man')
reject(s,6,3,8,5); reject(s,6,3,5,2)
n=move(s,6,3,4,5); assert(n.turn=='white' and n.chain.remaining==1 and #n.captured==0 and n.board[5][4])
n=move(n,4,5,2,7); assert(n.turn=='black' and not n.chain and #n.captured==2)
-- Flying king, capture landing choice, and promotion only at completed turn.
s=empty('checkers'); s.board[8][1]=p(1,'white','king'); s.board[6][3]=p(2,'black','man'); s.board[1][2]=p(3,'black','man')
n=move(s,8,1,3,6); assert(#n.captured==1 and n.board[3][6].kind=='king')
s=empty('checkers'); s.board[2][1]=p(1,'white','man'); s.board[9][2]=p(2,'black','man'); n=move(s,2,1,1,2); assert(n.board[1][2].kind=='king')
-- Captured checker remains an obstruction during a sequence.
s=empty('checkers'); s.board[5][4]=p(1,'white','king'); s.board[4][5]=p(2,'black','man'); s.board[6][3]=p(3,'black','man')
n=move(s,5,4,3,6); assert(not n.chain and #n.captured==1)
''')
lua.execute('''
local R=LightRPBoardRules
local function move(s,...) local n,e=R.move(s,...) assert(n,e) return n end
local function drop(s,c) return move(s,0,c,1,c) end
local function reject(s,...) local n=R.move(s,...) assert(not n) end
local s=R.new('connect4');assert(s.rows==6 and s.cols==7 and s.size==7 and #s.board==6)
local n=drop(s,4);assert(n.board[6][4].side=='white' and not s.board[6][4] and n.lastMove.toRow==6)
s=n;s=drop(s,4);assert(s.board[5][4].side=='black')
reject(s,0,0,0,0);reject(s,0,0,0,8);reject(s,0,0,0,2.5)
s=R.new('connect4');for i=1,6 do s=drop(s,1) end;reject(s,0,0,0,1);assert(#R.legalMoves(s)==6)
-- Four directions and terminal state freezing.
for _,d in ipairs({{0,1},{1,0},{1,1},{1,-1}}) do
 s=R.new('connect4');local col=d[2]==-1 and 5 or 2;local row=6-d[1]*3
 for i=1,3 do local r,c=row+d[1]*i,col+d[2]*i;s.board[r][c]={id=i,kind='disc',side='white'} end
 -- Fill support under the target cell so the tested drop lands at row.
 for r=row+1,6 do if not s.board[r][col] then s.board[r][col]={id=10+r,kind='disc',side='black'} end end
 s=drop(s,col);assert(s.status=='won' and s.winner=='white');reject(s,0,0,0,7)
end
-- Full grid without a four-in-a-row resolves to draw.
s=R.new('connect4')
for r=1,6 do for c=1,7 do s.board[r][c]={id=r*7+c,kind='disc',side=(math.floor((c-1)/2)+r)%2==0 and 'white' or 'black'} end end
s.turn=s.board[1][1].side;s.board[1][1]=false;s=drop(s,1);assert(s.status=='draw')
-- AI takes a winning column, then blocks a unique opponent immediate win.
s=R.new('connect4');for _,c in ipairs({1,7,2,7,3,6}) do s=drop(s,c) end
local ai,m=R.aiMove(s);assert(ai.status=='won' and ai.winner=='white' and m.toCol==4)
s=R.new('connect4');for _,c in ipairs({7,1,7,2,6,3}) do s=drop(s,c) end
ai,m=R.aiMove(s);assert(m.toCol==4 and ai.turn=='black')
-- Legal enumeration includes every initial chess move and all underpromotions.
s=R.new('chess');assert(#R.legalMoves(s)==20)
for i=1,4 do local before=s;ai,m=R.aiMove(s);assert(ai and m);local replay=move(s,m.fromRow,m.fromCol,m.toRow,m.toCol,m.promotion);assert(replay.turn==ai.turn and before.ply==i-1);s=ai end
s=R.new('chess');for r=1,8 do for c=1,8 do s.board[r][c]=false end end
s.board[8][5]={id=1,side='white',kind='king'};s.board[1][8]={id=2,side='black',kind='king'};s.board[2][1]={id=3,side='white',kind='pawn'}
local promotions=0;for _,m in ipairs(R.legalMoves(s)) do if m.fromRow==2 and m.fromCol==1 then assert(m.promotion);promotions=promotions+1 end end;assert(promotions==4)
-- AI capture sequences remain legal and finish their forced chain step by step.
s=R.new('checkers');for r=1,10 do for c=1,10 do s.board[r][c]=false end end
s.board[6][3]={id=1,side='white',kind='man'};s.board[5][4]={id=2,side='black',kind='man'};s.board[3][6]={id=3,side='black',kind='man'}
assert(#R.legalMoves(s)==1);ai,m=R.aiMove(s);assert(ai.chain and ai.turn=='white' and m.toRow==4 and m.toCol==5)
ai,m=R.aiMove(ai);assert(not ai.chain and #ai.captured==2 and ai.status=='won')
assert(#R.legalMoves(ai)==0);local no,why=R.aiMove(ai);assert(not no and type(why)=='string')
''')
lua.execute('''
local R=LightRPBoardRules
local metrics={}
local function budgeted(label,fn)
 local returns;local resumes,worst=0,0
 local co=coroutine.create(function() returns={fn(function() coroutine.yield(0) end)} end)
 while coroutine.status(co)~='dead' do
  local spent=0
  debug.sethook(co,function() spent=spent+100;if spent>25000 then error(label..': instruction budget exceeded '..spent) end end,'',100)
  local ok,why=coroutine.resume(co);debug.sethook(co);assert(ok,why)
  resumes=resumes+1;worst=math.max(worst,spent);assert(resumes<5000,'unbounded search')
 end
 metrics[#metrics+1]=label..'='..worst..'/'..resumes
 return table.unpack(returns)
end
local function clean(t)
 if type(t)~='table' then assert(type(t)~='function','search callback leaked into saved game');return end
 assert(t._cooperate==nil)
 for _,v in pairs(t) do clean(v) end
end
local function ai(label,s)
 local n,m=budgeted(label,function(yieldFn) return R.aiMove(s,yieldFn) end)
 assert(n,m);assert(m);assert(R.move(s,m.fromRow,m.fromCol,m.toRow,m.toCol,m.promotion));clean(n);clean(s)
 return n,m
end
for _,kind in ipairs({'chess','checkers','connect4'}) do
 local s=R.new(kind)
 local list=budgeted(kind..'-legal',function(yieldFn) return R.legalMoves(s,yieldFn) end)
 assert(#list>0)
 local n=ai(kind..'-white',s)
 assert(s.ply==0 and s.turn=='white')
 ai(kind..'-black',n)
end
-- Promotion enumeration, terminal validation, and long histories also cooperate.
local s=R.new('chess')
for r=1,8 do for c=1,8 do s.board[r][c]=false end end
s.board[8][5]={id=1,side='white',kind='king'};s.board[1][8]={id=2,side='black',kind='king'};s.board[2][1]={id=3,side='white',kind='pawn'}
s.positions={};for i=1,100 do s.positions['historical-position-'..i]=1 end
local list=budgeted('all-promotions',function(yieldFn) return R.legalMoves(s,yieldFn) end)
local count=0;for _,m in ipairs(list) do if m.fromRow==2 then count=count+1 end end;assert(count==4)
ai('promotion-history',s);assert(s.board[2][1].kind=='pawn' and not s.board[2][1].moved)
-- Branching must not mutate an earlier state's rook flags or captured pieces.
s=R.new('chess');for r=1,8 do for c=1,8 do s.board[r][c]=false end end
s.board[8][5]={id=1,side='white',kind='king'};s.board[1][8]={id=2,side='black',kind='king'};s.board[5][1]={id=3,side='white',kind='rook'};s.board[4][1]={id=4,side='black',kind='queen'}
ai('capture-snapshot',s);assert(not s.board[4][1].capturedBy and not s.board[5][1].moved)
-- A cooperative AI still wins and blocks Connect Four, rather than timing out.
for _,columns in ipairs({{1,7,2,7,3,6},{7,1,7,2,6,3}}) do
 s=R.new('connect4');for _,c in ipairs(columns) do s=assert(R.move(s,0,c,1,c)) end
 local _,m=ai('connect4-tactical',s);assert(m.toCol==4)
end
-- Multiple mandatory checker jumps retain legality through every yielded search.
s=R.new('checkers');for r=1,10 do for c=1,10 do s.board[r][c]=false end end
s.board[6][3]={id=1,side='white',kind='man'};s.board[5][4]={id=2,side='black',kind='man'};s.board[3][6]={id=3,side='black',kind='man'}
local n=ai('chain-first',s);assert(n.chain and s.board[5][4].capturedBy==nil)
n=ai('chain-final',n);assert(n.status=='won' and #n.captured==2 and s.board[5][4].capturedBy==nil)
print('AI strict instruction budget (worst instructions/resumes): '..table.concat(metrics,', '))
''')
print('board games rules: chess, checkers, Connect Four and cooperative AI scenarios passed')
