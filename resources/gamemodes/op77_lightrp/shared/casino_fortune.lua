-- Fortune Wheel (a "big six" money wheel): item, kind and pure rules.
-- No randomness and no wallet access here: the server picks the segment and
-- moves money; clients only animate the deterministic spin geometry.
LightRpBoardGames.fortune={item="fortune_wheel",label="Fortune Wheel",title="Fortune Wheel",size=1}
LightRpItems.fortune_wheel={label="Fortune Wheel",description="Use to place the money wheel. E: play; target menu: pick up your wheel.",weight=5,stack=1,icon="package",category="misc"}

LightRpCasinoFortune={}
local F=LightRpCasinoFortune
F.SEGMENTS=54
-- The face has two-fold symmetry: half a turn shows the same artwork, so the
-- client needs only 27 authored pose meshes. The two 40x segments sit half a
-- turn apart and are told apart by their own orbiting medallion props.
F.POSES=27
local HALF={'S','1','2','1','5','1','2','1','10','1','2','5','1','20','1','2','1','5','2','1','10','1','2','5','1','2','1'}
F.SPOTS={'1','2','5','10','20','eye','star'}
F.MULTIPLIER={['1']=1,['2']=2,['5']=5,['10']=10,['20']=20,eye=40,star=40}
F.LABEL={['1']='1x',['2']='2x',['5']='5x',['10']='10x',['20']='20x',eye='Neon Eye 40x',star='Starburst 40x'}
F.layout={}
for i=0,F.SEGMENTS-1 do
 local spot=HALF[i%27+1]
 if spot=='S' then spot=i==0 and 'eye' or 'star' end
 F.layout[i]=spot
end
F.MIN_BET=1
F.MAX_BET=1000          -- per placed bet
F.MAX_ROUND=5000        -- per character per round
F.MAX_ENTRIES=32        -- distinct (character, spot) stakes per round
F.SPIN_MS=8200          -- motion: fast start, long deceleration
F.DURATION=9000         -- motion + the flapper's settle; claims open at the end
F.RECENT=8

local function copy(t)
 if type(t)~='table' then return t end
 local n={} for k,v in pairs(t) do n[k]=copy(v) end return n
end
F.copy=copy
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<9007199254740991 end
local function integer(n,min,max) return finite(n) and n==math.floor(n) and n>=min and n<=max end
F.integer=integer
function F.validSpot(spot) return type(spot)=='string' and F.MULTIPLIER[spot]~=nil end
-- Gross return of one stake: multiplier x stake plus the stake back, or 0.
function F.payout(spot,segment,amount)
 if not F.validSpot(spot) or not integer(segment,0,F.SEGMENTS-1) or not integer(amount,1,2147483647) then return nil,'Invalid wheel bet.' end
 if F.layout[segment]~=spot then return 0 end
 return amount*(F.MULTIPLIER[spot]+1)
end
-- Rotation is counted in whole segment steps, clockwise as seen from the
-- front. At rotation r the segment under the flapper (top) is (-r) mod 54.
function F.topSegment(r) return (-math.floor(r+.5))%F.SEGMENTS end
function F.poseIndex(r) return math.floor(r+.5)%F.POSES end
-- Deterministic plan from the server's outcome: whole laps plus the exact
-- remainder that brings `outcome` under the flapper. The rotor stops a little
-- short of the segment centre (STOP_OFFSET), just past the last peg, the way
-- a flapper catches a real wheel; rounding still lands on `to`.
F.STOP_OFFSET=.35
function F.plan(rest,outcome,laps,now)
 if not integer(rest,0,F.SEGMENTS-1) or not integer(outcome,0,F.SEGMENTS-1) or not integer(laps,1,6) or not finite(now) or now<0 then
  return nil,'The server must provide the spin outcome and time.'
 end
 local to=rest+F.SEGMENTS*laps+((-outcome-rest)%F.SEGMENTS)
 return {startedAt=now,spinMs=F.SPIN_MS,duration=F.DURATION,endsAt=now+F.DURATION,from=rest,to=to,outcome=outcome}
end
-- Rotation (fractional steps) and speed (steps per ms) at server time `now`.
-- Constant friction: fastest at the start, a long linear deceleration.
function F.progress(spin,now)
 local from=spin.from;local travel=spin.to-F.STOP_OFFSET-from
 local t=(now-spin.startedAt)/spin.spinMs
 if t<=0 then return from,0,0 end
 if t>=1 then return from+travel,0,1 end
 local k=1-t
 return from+travel*(1-k*k),2*travel*k/spin.spinMs,t
end
-- Milliseconds since the last peg passed the flapper (pegs sit on the
-- half-steps), inverted exactly from the easing; nil before the first one.
function F.sincePeg(spin,now)
 local pos,_,t=F.progress(spin,now)
 if t<=0 then return nil end
 local crossing=math.floor(pos-.5)+.5
 if crossing<spin.from then return nil end
 local travel=spin.to-F.STOP_OFFSET-spin.from
 local left=(travel-(crossing-spin.from))/travel
 local at=spin.startedAt+spin.spinMs*(1-math.sqrt(math.max(0,left)))
 return now-at
end

function F.new(mode)
 return {kind='fortune',mode=mode or 'duel',turn='white',status='playing',ply=0,
  round=1,phase='betting',rest=0,pot={},recent={},_money={}}
end
-- Start a fresh round from a finished one (bets and the old spin cleared).
local function fresh(s)
 local n=copy(s)
 if n.phase=='result' then n.round=n.round+1;n.phase='betting';n.pot={};n._money={};n.spin=nil;n.result=nil;n._roundKey=nil end
 return n
end
-- p={inventory,seat,spot,amount,roundKey}; private stakes stay in _money.
function F.bet(s,p)
 if type(s)~='table' or s.kind~='fortune' or s.status~='playing' then return nil,'This table is not ready.' end
 if s.phase=='spinning' then return nil,'Bets are closed while the wheel spins.' end
 if type(p)~='table' or type(p.inventory)~='string' or type(p.roundKey)~='string' then return nil,'Invalid wheel bet.' end
 if not F.validSpot(p.spot) then return nil,'Choose a multiplier to bet on.' end
 if not integer(p.amount,F.MIN_BET,F.MAX_BET) then return nil,('Bet between %d and %d whole RP dollars.'):format(F.MIN_BET,F.MAX_BET) end
 local n=fresh(s)
 local mine,entry=0,nil
 for _,m in ipairs(n._money) do
  if m.inventory==p.inventory then mine=mine+m.amount;if m.spot==p.spot then entry=m end end
 end
 if mine+p.amount>F.MAX_ROUND then return nil,('Your stakes are limited to %d per spin.'):format(F.MAX_ROUND) end
 if not entry and #n._money>=F.MAX_ENTRIES then return nil,'This table has reached its bet limit for this spin.' end
 if entry then entry.amount=entry.amount+p.amount
 else n._money[#n._money+1]={inventory=p.inventory,seat=p.seat,spot=p.spot,amount=p.amount} end
 n.pot[p.spot]=(n.pot[p.spot] or 0)+p.amount
 n._roundKey=n._roundKey or p.roundKey
 n.ply=n.ply+1
 return n
end
-- p={outcome,laps,nowMs,roundKey}. Answers the state and the gross return
-- per inventory, written as claims in the same transaction as the spin.
function F.spin(s,p)
 if type(s)~='table' or s.kind~='fortune' or s.status~='playing' then return nil,'This table is not ready.' end
 if s.phase=='spinning' then return nil,'The wheel is already spinning.' end
 if type(p)~='table' or type(p.roundKey)~='string' then return nil,'Invalid spin.' end
 local n=fresh(s)
 local spin,why=F.plan(n.rest,p.outcome,p.laps,p.nowMs)
 if not spin then return nil,why end
 n.phase='spinning';n.spin=spin;n._roundKey=n._roundKey or p.roundKey;n.ply=n.ply+1
 local totals={}
 for _,m in ipairs(n._money) do totals[m.inventory]=(totals[m.inventory] or 0)+F.payout(m.spot,spin.outcome,m.amount) end
 return n,totals
end
function F.settle(s,now)
 if type(s)~='table' or s.phase~='spinning' or type(s.spin)~='table' then return nil,'The wheel is not spinning.' end
 if not finite(now) or now<s.spin.endsAt then return nil,'The wheel is still spinning.' end
 local n=copy(s);local segment=n.spin.outcome;local spot=F.layout[segment]
 n.phase='result';n.rest=n.spin.to%F.SEGMENTS
 n.result={segment=segment,spot=spot,multiplier=F.MULTIPLIER[spot],round=n.round}
 local recent={segment}
 for i=1,math.min(#(n.recent or {}),F.RECENT-1) do recent[#recent+1]=n.recent[i] end
 n.recent=recent;n.ply=n.ply+1
 return n
end
-- Total stake per inventory still on the table (refunded on pickup/reset).
function F.stakes(s)
 local sums={}
 if type(s)~='table' or s.phase~='betting' then return sums end
 for _,m in ipairs(s._money or {}) do sums[m.inventory]=(sums[m.inventory] or 0)+m.amount end
 return sums
end
-- Public view: private keys removed, the viewer's own stakes/winnings added.
function F.view(s,inventory)
 local n={}
 for k,v in pairs(s) do if not(type(k)=='string' and k:sub(1,1)=='_') then n[k]=copy(v) end end
 local mine,stake,won={},0,0
 for _,m in ipairs(s._money or {}) do if inventory and m.inventory==inventory then
  mine[m.spot]=(mine[m.spot] or 0)+m.amount;stake=stake+m.amount
  if s.result then won=won+F.payout(m.spot,s.result.segment,m.amount) end
 end end
 n.yourBets=mine;n.yourStake=stake;n.yourWin=s.result and won or nil
 n.minBet=F.MIN_BET;n.maxBet=F.MAX_BET
 return n
end
