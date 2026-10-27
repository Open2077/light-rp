#!/usr/bin/env python3
"""Pure-Lua regressions for roulette, hidden-hand dominoes and card supports."""
from pathlib import Path
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/shared/tabletop_extra_rules.lua').read_text())
lua.execute('''
local R=LightRpTabletopExtraRules
local function act(s,seat,action,p) local n,e=R.act(s,seat,action,p);assert(n,e);return n end
local function reject(s,seat,action,p) local n=R.act(s,seat,action,p);assert(not n,'illegal '..action..' accepted') end
local now=1790000000000
-- Every outcome has one pocket; kinematics end the ball over that pocket.
local seen={}
for _,number in ipairs(R.rouletteOrder) do assert(not seen[number]);seen[number]=true end
for number=0,36 do
 assert(seen[number]);local s=R.new('roulette')
 s=act(s,'white','bet',{bet=number,amount=10});s=act(s,'black','bet',{bet='red',amount=5})
 local before=s;s=act(s,'white','spin',{outcome=number,nowMs=now,seedAngle=83.4})
 assert(before.phase=='betting' and s.phase=='spinning' and s.spin.duration==8000)
 local index;for i,n in ipairs(R.rouletteOrder) do if n==number then index=i-1 end end
 local delta=(s.spin.ballTo-s.spin.wheelTo-index*360/37)%360;assert(math.min(delta,360-delta)<1e-6)
 reject(s,'white','bet',{bet='odd',amount=1});reject(s,'white','spin',{outcome=0,nowMs=now})
 reject(s,'white','settle',{nowMs=now+7999});reject(s,'white','nextRound',{})
 s=act(s,'white','settle',{nowMs=now+8000});assert(s.phase=='result' and s.result.outcome==number and s.result.payouts[1].gross==360)
 assert(R.totalPayout(s,'white',number)==360)
 reject(s,'white','settle',{nowMs=now+9000})
 s=act(s,'white','nextRound',{});assert(s.phase=='betting' and s.round==2 and #s.bets==0 and not s.spin)
end
assert(R.roulettePayout(0,0,1)==36 and R.roulettePayout('number:17',17,2)==72)
for _,bet in ipairs({'red','black','even','odd','low','high','dozen1','dozen2','dozen3'}) do assert(R.roulettePayout(bet,0,5)==0) end
assert(R.roulettePayout('red',1,5)==10 and R.roulettePayout('black',2,5)==10)
assert(R.roulettePayout('even',2,5)==10 and R.roulettePayout('odd',1,5)==10)
assert(R.roulettePayout('low',18,5)==10 and R.roulettePayout('high',19,5)==10)
assert(R.roulettePayout('dozen1',12,5)==15 and R.roulettePayout('dozen2',13,5)==15 and R.roulettePayout('dozen3',36,5)==15)
local s=R.new('roulette')
for _,p in ipairs({{bet=37,amount=1},{bet='invalid',amount=1},{bet='red',amount=0},{bet='red',amount=1.5},{bet='red',amount=0/0}}) do reject(s,'white','bet',p) end
reject(s,'white','spin',{outcome=37,nowMs=now});reject(s,'white','spin',{outcome=1,nowMs=-1})
s._money={['secret-inventory']={amount=5}};s._owners={white='secret-owner'}
local public=R.view(s,'white');assert(not public._money and not public._owners)
-- Double-six set has exactly 28 unique tiles, with deterministic private shuffle.
for _,mode in ipairs({'duel','solo','teams'}) do
 s=R.new('dominoes',mode,777);local duplicate=R.new('dominoes',mode,777);local ids={};local count=0
 for seat,hand in pairs(s.hands) do assert(#hand==7)
  for i,tile in ipairs(hand) do assert(not ids[tile.id] and tile.a>=0 and tile.b<=6 and tile.a<=tile.b);ids[tile.id]=true;count=count+1;assert(tile.id==duplicate.hands[seat][i].id) end
 end
 for _,tile in ipairs(s.drawPile) do assert(not ids[tile.id]);ids[tile.id]=true;count=count+1 end
 assert(count==28 and #s.drawPile==(mode=='teams' and 0 or 14))
 local viewer=s.seats[1];public=R.view(s,viewer)
 assert(#public.hand==7 and not public.drawPile and public.drawCount==#s.drawPile and #public.objects==0)
 for seat,hand in pairs(public.hands) do if seat~=viewer then for _,tile in ipairs(hand) do assert(tile.hidden and not tile.id and not tile.a and not tile.b) end end end
 assert(#R.view(s,nil).hand==0)
 local actor=s.seatTurn;local moves=R.legalMoves(s);local first=moves[1]
 reject(s,actor=='white' and 'black' or 'white','play',first)
 reject(s,actor,'play',{tileId='forged-tile',['end']='left'})
 reject(s,actor,'draw',{})
 local before=s;s=act(s,actor,'play',first);assert(#before.hands[actor]==7 and #s.hands[actor]==6 and #s.objects==1)
 local index;for i,seat in ipairs(s.seats) do if seat==actor then index=i end end
 assert(s.seatTurn==s.seats[index%#s.seats+1])
end
-- End matching works in either direction, including doubles.
s=R.new('dominoes','duel',1);s.seatTurn='white';s.turn='white';s.hands.white={{id='a',a=1,b=3},{id='b',a=3,b=3},{id='c',a=0,b=1}};s.hands.black={{id='d',a=2,b=3},{id='e',a=0,b=6}};s.drawPile={}
s=act(s,'white','play',{tileId='a',['end']='right'});assert(s.left==1 and s.right==3)
reject(s,'black','play',{tileId='e',['end']='right'})
s=act(s,'black','play',{tileId='d',['end']='right'});assert(s.left==1 and s.right==2)
s=act(s,'white','play',{tileId='c',['end']='left'});assert(s.left==0 and s.right==2)
-- Drawing keeps the actor until a legal tile can be played; passing needs an empty pile.
s=R.new('dominoes','duel',1);s.seatTurn='white';s.turn='white';s.chain={{id='z',a=6,b=6,left=6,right=6}};s.left=6;s.right=6;s.hands.white={{id='a',a=0,b=1}};s.hands.black={{id='b',a=2,b=2}};s.drawPile={{id='c',a=1,b=6}}
reject(s,'white','pass',{});s=act(s,'white','draw',{});assert(s.seatTurn=='white' and #s.hands.white==2)
reject(s,'white','pass',{});s=act(s,'white','play',{tileId='c',['end']='right'});assert(s.seatTurn=='black')
s=R.new('dominoes','teams',1);s.seatTurn='white';s.turn='white';s.chain={{id='z',a=6,b=6,left=6,right=6}};s.left=6;s.right=6;s.drawPile={}
s.hands={white={{id='a',a=0,b=0}},black={{id='b',a=2,b=2}},white2={{id='c',a=0,b=1}},black2={{id='d',a=3,b=3}}}
for _,seat in ipairs({'white','black','white2','black2'}) do assert(s.seatTurn==seat);s=act(s,seat,'pass',{}) end
assert(s.status=='won' and s.winner=='white' and s.totals.white==1 and s.totals.black==10)
-- Cooperative domino AI finishes real seeded games without leaking private hands.
local worst,resumes=0,0
for _,mode in ipairs({'solo','teams'}) do
 s=R.new('dominoes',mode,1541)
 local turns=0
 while s.status=='playing' do
  local result,move;local co=coroutine.create(function() result,move=R.aiMove(s,function() coroutine.yield() end) end)
  while coroutine.status(co)~='dead' do
   local spent=0;debug.sethook(co,function() spent=spent+100;if spent>25000 then error('domino AI resume budget '..spent) end end,'',100)
   local ok,e=coroutine.resume(co);debug.sethook(co);assert(ok,e);worst=math.max(worst,spent);resumes=resumes+1
  end
  assert(result,move);assert(R.act(s,s.seatTurn,move.action,move.payload));s=result;turns=turns+1;assert(turns<100)
 end
 assert(s.status=='won' or s.status=='draw')
end
-- Two base A-frames and a roof form a supported floor; a new frame rests on it.
s=R.new('cardtower');local function place(game,x,y,level,orientation,yaw) return act(game,'white','place',{x=x,y=y,level=level,orientation=orientation,yaw=yaw or 0,nowMs=now}) end
s=place(s,-.032,0,0,'frame');assert(s.status=='playing' and #s.objects==2 and s.remaining==50)
assert(s.objects[1].pose=='lean-left' and math.abs(s.objects[1].x+.058)<1e-9)
s=place(s,.032,0,0,'frame');s=place(s,0,0,1,'flat');assert(s.status=='playing' and #s.objects==5 and #s.structures[3].supports==2)
s=place(s,0,0,1,'frame');assert(s.status=='playing' and #s.structures[4].supports==1 and s.height>R.cardDimensions.frameHeight)
local stable=s
s=place(s,.25,.2,2,'flat');assert(s.status=='collapsed' and s.collapse.startedAt==now and s.collapse.gravity==9.81)
assert(stable.status=='playing' and not stable.collapse and #stable.objects==7)
for _,o in ipairs(s.objects) do assert(s.collapse.objects[o.id] and s.collapse.objects[o.id].vx) end
reject(s,'white','place',{x=0,y=0,orientation='frame'})
-- Unsupported roofs, overlapping frames, isolated leaning cards and off-centre loads fall.
s=place(R.new('cardtower'),0,0,1,'flat');assert(s.status=='collapsed')
s=place(R.new('cardtower'),0,0,0,'frame');s=place(s,0,0,0,'frame');assert(s.status=='collapsed')
s=place(R.new('cardtower'),0,0,0,'lean-left');assert(s.status=='collapsed')
s=place(R.new('cardtower'),-.032,0,0,'frame');s=place(s,.032,0,0,'frame');s=place(s,.06,0,1,'flat');assert(s.status=='collapsed')
-- Overlapping roof cards form real layers, allowing a multi-storey house.
s=R.new('cardtower');for _,x in ipairs({-.064,0,.064}) do s=place(s,x,0,0,'frame') end
s=place(s,-.032,0,1,'flat');s=place(s,.032,0,1,'flat');assert(s.status=='playing')
s=place(s,-.032,0,1,'frame');s=place(s,.032,0,1,'frame');s=place(s,0,0,2,'flat')
assert(s.status=='playing' and s.height>R.cardDimensions.frameHeight*2)
-- The support solver and bounds rotate with the structure.
s=place(R.new('cardtower'),0,-.032,0,'frame',90);s=place(s,0,.032,0,'frame',90);s=place(s,0,0,1,'flat',90);assert(s.status=='playing')
reject(R.new('cardtower'),'white','place',{x=.49,y=0,level=0,orientation='frame'})
reject(R.new('cardtower'),'white','place',{x=0/0,y=0,level=0,orientation='frame'})
print('Extra tabletop rules: roulette37 outcomes/payouts, domino secrecy/teams/AI, card support/collapse passed; AI worst '..worst..' instructions across '..resumes..' resumes')
''')
