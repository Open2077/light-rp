#!/usr/bin/env python3
"""Pure-Lua regressions for the Fortune Wheel: layout, payouts, house edge,
round state, private stakes and the spin geometry. Every outcome's final pose
must show that segment under the flapper (and its medallion for the 40x)."""
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('LightRpBoardGames={};LightRpItems={}')
lua.execute((GAME/'shared/casino_fortune.lua').read_text())
lua.execute(r'''
local F=LightRpCasinoFortune
assert(LightRpBoardGames.fortune.item=='fortune_wheel' and LightRpItems.fortune_wheel.label=='Fortune Wheel')
-- Classic big-six proportions with a two-fold symmetric face.
local counts={}
for i=0,F.SEGMENTS-1 do local s=F.layout[i];counts[s]=(counts[s] or 0)+1 end
assert(counts['1']==24 and counts['2']==14 and counts['5']==8 and counts['10']==4 and counts['20']==2 and counts.eye==1 and counts.star==1)
assert(F.layout[0]=='eye' and F.layout[27]=='star')
for i=0,F.SEGMENTS-1 do
 local a,b=F.layout[i],F.layout[(i+27)%54]
 assert(a==b or (a=='eye' and b=='star') or (a=='star' and b=='eye'),'face is not two-fold symmetric at '..i)
 assert(F.layout[i]~=F.layout[(i+1)%54],'two equal neighbours at '..i)
end
-- Every spot has a house edge (expected gross return per 1 staked below 1).
edges={}
for _,spot in ipairs(F.SPOTS) do
 local total=0;for i=0,F.SEGMENTS-1 do total=total+F.payout(spot,i,1) end
 local edge=1-total/F.SEGMENTS;assert(edge>0.1 and edge<0.25,spot);edges[spot]=edge
end
assert(F.payout('20',13,10)==210 and F.payout('20',12,10)==0 and F.payout('eye',0,3)==123 and F.payout('star',0,3)==0)
assert(not F.payout('3',1,1) and not F.payout('1',54,1) and not F.payout('1',1,0) and not F.payout('1',1,1.5))
-- Rounds: bets accumulate privately, closed while spinning, reopen after.
local now=1790000000000
local s=F.new()
local function ok(n,e) assert(n,e);return n end
s=ok(F.bet(s,{inventory='invA',seat='white',spot='2',amount=10,roundKey='k1'}))
s=ok(F.bet(s,{inventory='invA',seat='white',spot='2',amount=5,roundKey='other'}))
s=ok(F.bet(s,{inventory='invB',seat='black',spot='eye',amount=7,roundKey='other'}))
assert(s._roundKey=='k1' and #s._money==2 and s._money[1].amount==15 and s.pot['2']==15 and s.pot.eye==7)
for _,p in ipairs({{spot='3',amount=1},{spot='1',amount=0},{spot='1',amount=1001},{spot='1',amount=2.5},{spot='1',amount=0/0},{spot={},amount=1}}) do
 p.inventory='invA';p.roundKey='k';assert(not F.bet(s,p))
end
local big=F.new();for i=1,5 do big=ok(F.bet(big,{inventory='x',spot='1',amount=1000,roundKey='k'})) end
assert(not F.bet(big,{inventory='x',spot='2',amount=1,roundKey='k'}),'per-round cap')
local many=F.new();for i=1,F.MAX_ENTRIES do many=ok(F.bet(many,{inventory='i'..i,spot='1',amount=1,roundKey='k'})) end
assert(not F.bet(many,{inventory='new',spot='1',amount=1,roundKey='k'}),'entry cap')
assert(F.bet(many,{inventory='i1',spot='1',amount=1,roundKey='k'}),'existing entries still accumulate')
assert(F.stakes(s).invA==15 and F.stakes(s).invB==7)
local spun,totals=F.spin(s,{outcome=0,laps=2,nowMs=now,roundKey='zz'});assert(spun,totals)
assert(spun.phase=='spinning' and spun._roundKey=='k1' and totals.invB==287 and totals.invA==0)
assert(next(F.stakes(spun))==nil,'no refund once the spin is committed')
assert(not F.bet(spun,{inventory='invA',spot='1',amount=1,roundKey='k'}) and not F.spin(spun,{outcome=1,laps=2,nowMs=now,roundKey='k'}))
assert(not F.settle(spun,spun.spin.endsAt-1))
local done=ok(F.settle(spun,spun.spin.endsAt))
assert(done.phase=='result' and done.result.spot=='eye' and done.result.multiplier==40 and done.recent[1]==0)
local pv=F.view(done,'invB');assert(pv.yourWin==287 and pv.yourStake==7 and pv.yourBets.eye==7 and not pv._money and not pv._roundKey)
assert(F.view(done,'nobody').yourStake==0 and F.view(done,'nobody').yourWin==0)
-- The next bet opens a new round with a new key; the rest pose is kept.
local nextRound=ok(F.bet(done,{inventory='invA',spot='1',amount=1,roundKey='k2'}))
assert(nextRound.round==2 and nextRound.phase=='betting' and nextRound._roundKey=='k2' and #nextRound._money==1 and not nextRound.spin and nextRound.rest==done.rest)
-- Recent results stay bounded.
local r=F.new();for i=1,20 do r=ok(F.spin(r,{outcome=i%54,laps=2,nowMs=now,roundKey='r'..i}));r=ok(F.settle(r,r.spin.endsAt)) end
assert(#r.recent==F.RECENT and r.recent[1]==20 and r.round==20)
assert(not F.plan(0,54,2,now) and not F.plan(0,1,0,now) and not F.plan(0,1,2,-1) and not F.plan(.5,1,2,now))
-- Geometry: from every rest and for every outcome, the final pose shows that
-- segment under the flapper; pegs pass one by one and the rotor never backs up.
for rest=0,53,7 do for outcome=0,53 do for laps=2,3 do
 local spin=F.plan(rest,outcome,laps,now)
 local final=F.progress(spin,now+spin.spinMs)
 assert(F.topSegment(final)==outcome and F.topSegment(spin.to)==outcome)
 assert(math.floor(final+.5)==spin.to and spin.to-rest>=54*laps and spin.to-rest<54*(laps+1))
 -- Pose p of 27 is the face turned p steps; with two-fold symmetry the face at
 -- rotation r looks like pose r%27, and segment (-r)%54's label sits on top.
 local pose=F.poseIndex(final);assert(F.layout[(-pose)%54]==F.layout[outcome] or F.layout[outcome]=='eye' or F.layout[outcome]=='star')
 -- The medallion of the eye is at r steps clockwise from the top: on top iff eye wins.
 local eyeAngle=(spin.to*360/54)%360;assert((eyeAngle<1e-9)==(outcome==0))
 local starAngle=((spin.to+27)*360/54)%360;assert((starAngle<1e-9)==(outcome==27))
 local last,lastSince=spin.from,nil
 for ms=0,spin.spinMs,97 do
  local pos,speed=F.progress(spin,now+ms);assert(pos>=last-1e-9 and speed>=0);last=pos
 end
 local p,_=F.progress(spin,now+spin.duration);assert(p==final)
end end end
-- Peg timing: zero right at a crossing, growing until the next one.
local spin=F.plan(0,10,2,now)
assert(F.sincePeg(spin,now)==nil)
local travel=spin.to-F.STOP_OFFSET-spin.from
local crossT=spin.spinMs*(1-math.sqrt(1-(40.5)/travel))
assert(math.abs(F.sincePeg(spin,now+crossT+1)-1)<1e-6 and F.sincePeg(spin,now+crossT+30)>29)
local _,v0=F.progress(spin,now+1);assert(v0>.02 and v0<.05,'starts fast: '..v0)
local lastCross=spin.spinMs*(1-math.sqrt(1-(spin.to-.5-spin.from)/travel))
assert(spin.spinMs-lastCross<400,'the last peg clacks just before the stop')
print(('Fortune rules: 54-segment layout, payouts, rounds, caps and every outcome pose passed; house edge %%: 1x %.1f 2x %.1f 5x %.1f 10x %.1f 20x %.1f 40x %.1f'):format(
 edges['1']*100,edges['2']*100,edges['5']*100,edges['10']*100,edges['20']*100,edges.eye*100))
''')
