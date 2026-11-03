-- Pure authoritative tabletop rules. Money debits/payouts belong to the server
-- controller; roulette here computes gross returns and never changes a wallet.
LightRpTabletopExtraRules = {}
local R=LightRpTabletopExtraRules
local SEATS={'white','black','white2','black2'}
local function copy(t)
 if type(t)~='table' then return t end
 local n={} for k,v in pairs(t) do n[k]=copy(v) end return n
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<9007199254740991 end
local function integer(n,min,max) return finite(n) and n==math.floor(n) and n>=min and n<=max end
local function seatOK(seat) for _,s in ipairs(SEATS) do if seat==s then return true end end return false end
R.rouletteOrder={0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26}
local red={ [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,[14]=true,[16]=true,[18]=true,[19]=true,[21]=true,[23]=true,[25]=true,[27]=true,[30]=true,[32]=true,[34]=true,[36]=true }
local function normalizeBet(bet)
 if type(bet)=='string' then
  local straight=bet:match('^number:(%d+)$') or bet:match('^(%d+)$')
  if straight then bet=tonumber(straight) end
 end
 if integer(bet,0,36) then return bet end
 if bet=='red' or bet=='black' or bet=='even' or bet=='odd' or bet=='low' or bet=='high' or bet=='dozen1' or bet=='dozen2' or bet=='dozen3' then return bet end
 return nil
end
function R.roulettePayout(bet,outcome,amount)
 bet=normalizeBet(bet)
 if bet==nil or not integer(outcome,0,36) or not integer(amount,1,2147483647) then return nil,'Invalid roulette bet.' end
 if type(bet)=='number' then return outcome==bet and amount*36 or 0 end
 if outcome==0 then return 0 end
 local wins=(bet=='red' and red[outcome]) or (bet=='black' and not red[outcome]) or
  (bet=='even' and outcome%2==0) or (bet=='odd' and outcome%2==1) or
  (bet=='low' and outcome<=18) or (bet=='high' and outcome>=19)
 if bet:sub(1,5)=='dozen' then
  local dozen=tonumber(bet:sub(6));return math.floor((outcome-1)/12)+1==dozen and amount*3 or 0
 end
 return wins and amount*2 or 0
end
function R.totalPayout(s,seat,outcome)
 if type(s)~='table' or s.kind~='roulette' or not integer(outcome,0,36) then return nil,'Invalid roulette result.' end
 local total=0
 for _,bet in ipairs(s.bets or {}) do if bet.seat==seat then local amount,why=R.roulettePayout(bet.bet,outcome,bet.amount);if not amount then return nil,why end;total=total+amount end end
 return total
end
local function roulette(s,seat,action,p)
 local now=p.nowMs or p.nowUnixMs
 if action=='bet' then
  if s.phase~='betting' then return nil,'Bets are closed.' end
  local bet=normalizeBet(p.bet)
  if bet==nil or not integer(p.amount,1,2147483647) then return nil,'Choose a valid bet and a positive whole amount.' end
  local n=copy(s);n.betSerial=(n.betSerial or 0)+1
  n.bets[#n.bets+1]={id=tostring(n.round)..':'..n.betSerial,seat=seat,bet=bet,amount=p.amount}
  n.ply=n.ply+1;return n
 elseif action=='spin' then
  if s.phase~='betting' then return nil,'The wheel is not ready.' end
  if not integer(p.outcome,0,36) or not finite(now) or now<0 then return nil,'The server must provide the spin outcome and time.' end
  local angle=p.seedAngle or 0
  if not finite(angle) then return nil,'Invalid spin angle.' end
  local index=0;for i,value in ipairs(R.rouletteOrder) do if value==p.outcome then index=i-1;break end end
  local wheelFrom=s.lastWheelAngle or 0;local ballFrom=s.lastBallAngle or 0
  local wheelTo=wheelFrom+360*5+(angle%360)
  -- Clockwise angles measured from +Y; the ball ends over the correct pocket
  -- after adding the wheel's own final rotation.
  local target=(wheelTo+index*360/37)%360
  local ballTo=ballFrom-360*9-((ballFrom-target)%360)
  local n=copy(s);n.phase='spinning';n.ply=n.ply+1
  n.spin={startedAt=now,duration=8000,endsAt=now+8000,outcome=p.outcome,seedAngle=angle,
   wheelFrom=wheelFrom,wheelTo=wheelTo,ballFrom=ballFrom,ballTo=ballTo,radius=.27,ballZ=.025}
  return n
 elseif action=='settle' then
  if s.phase~='spinning' or not finite(now) or now<s.spin.endsAt then return nil,'The wheel is still spinning.' end
  local n=copy(s);n.phase='result';n.lastWheelAngle=n.spin.wheelTo;n.lastBallAngle=n.spin.ballTo
  n.result={outcome=n.spin.outcome,color=n.spin.outcome==0 and 'green' or red[n.spin.outcome] and 'red' or 'black',payouts={},round=n.round}
  for _,bet in ipairs(n.bets) do
   n.result.payouts[#n.result.payouts+1]={id=bet.id,seat=bet.seat,bet=bet.bet,amount=bet.amount,gross=R.roulettePayout(bet.bet,n.spin.outcome,bet.amount)}
  end
  n.ply=n.ply+1;return n
 elseif action=='nextRound' then
  if s.phase~='result' then return nil,'Settle this round first.' end
  local n=copy(s);n.round=n.round+1;n.phase='betting';n.bets={};n.spin=nil;n.result=nil;n.ply=n.ply+1;return n
 end
 return nil,'Unknown roulette action.'
end
function R.new(kind,mode)
 if kind~='roulette' then return nil,'Unknown tabletop game.' end
 return {kind=kind,mode=mode or 'duel',turn='white',status='playing',ply=0,captured={},objects={},
  round=1,phase='betting',bets={},betSerial=0}
end
function R.act(s,seat,action,payload)
 if type(s)~='table' or s.status~='playing' then return nil,'This game has ended. Start a new game.' end
 if not seatOK(seat) or type(action)~='string' or (payload~=nil and type(payload)~='table') then return nil,'Invalid game action.' end
 local p=payload or {}
 if s.kind=='roulette' then return roulette(s,seat,action,p) end
 return nil,'Unknown tabletop game.'
end
local function stripPrivate(t)
 if type(t)~='table' then return end
 for k,v in pairs(t) do if type(k)=='string' and k:sub(1,1)=='_' then t[k]=nil else stripPrivate(v) end end
end
function R.view(s)
 local n=copy(s);stripPrivate(n);n.rouletteOwners=nil
 return n
end
