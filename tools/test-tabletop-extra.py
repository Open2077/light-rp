#!/usr/bin/env python3
"""Pure-Lua regressions for roulette outcomes, payouts and private state."""
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
local public=R.view(s);assert(not public._money and not public._owners)
print('Extra tabletop rules: roulette 37 outcomes, payouts and private state passed')
''')
