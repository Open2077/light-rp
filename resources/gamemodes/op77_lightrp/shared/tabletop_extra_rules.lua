-- Pure authoritative tabletop rules. Money debits/payouts belong to the server
-- controller; roulette here computes gross returns and never changes a wallet.
LightRpTabletopExtraRules = {}
local R=LightRpTabletopExtraRules
local SEATS={'white','black','white2','black2'}
local function copy(t,work)
 if type(t)~='table' then return t end
 local n={} for k,v in pairs(t) do if work then work() end;n[k]=copy(v,work) end return n
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<9007199254740991 end
local function integer(n,min,max) return finite(n) and n==math.floor(n) and n>=min and n<=max end
local function seatOK(seat) for _,s in ipairs(SEATS) do if seat==s then return true end end return false end
-- Keep the explicit branches: Lua's and/or idiom must not return boolean true.
local function sideOf(seat) if seat=='white' or seat=='white2' then return 'white' end return 'black' end
local function rng(seed)
 local value=integer(seed,1,2147483646) and seed or math.random(1,2147483646)
 return function(max) value=(value*48271)%2147483647;return value%max+1 end
end
local function workFor(yieldFn)
 if not yieldFn then return nil end
 local count=0;return function() count=count+1;if count>=32 then count=0;yieldFn() end end
end
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
local function dominoMoves(s,seat,work)
 local moves={};for _,tile in ipairs(s.hands[seat] or {}) do
  if work then work() end
  if #s.chain==0 then moves[#moves+1]={tileId=tile.id,['end']='right'}
  else
   if tile.a==s.left or tile.b==s.left then moves[#moves+1]={tileId=tile.id,['end']='left'} end
   if tile.a==s.right or tile.b==s.right then moves[#moves+1]={tileId=tile.id,['end']='right'} end
  end
 end return moves
end
local function handTotal(hand) local sum=0;for _,tile in ipairs(hand) do sum=sum+tile.a+tile.b end return sum end
local function dominoNext(s)
 for i,seat in ipairs(s.seats) do if seat==s.seatTurn then s.seatTurn=s.seats[i%#s.seats+1];break end end
 s.turn=sideOf(s.seatTurn)
end
local function dominoObjects(s)
 s.objects={}
 for i,tile in ipairs(s.chain) do
  -- Compact connected serpentine line; all 28 tiles fit on the tabletop.
  local row=math.floor((i-1)/11);local col=(i-1)%11
  if row%2==1 then col=10-col end
  local yaw=tile.left==tile.a and -90 or 90
  if row%2==1 then yaw=yaw+180 end
  s.objects[#s.objects+1]={id='placed:'..tile.id,tileId=tile.id,kind='domino',a=tile.a,b=tile.b,
   x=(col-5)*.052,y=(row-1)*.052,z=.004,yaw=yaw,zone='placed',left=tile.left,right=tile.right}
 end
end
local function dominoBlocked(s)
 local totals={white=0,black=0}
 for seat,hand in pairs(s.hands) do local side=sideOf(seat);totals[side]=totals[side]+handTotal(hand) end
 s.totals=totals
 if totals.white==totals.black then s.status='draw' else s.status='won';s.winner=totals.white<totals.black and 'white' or 'black' end
 s.reason='blocked'
end
local function domino(s,seat,action,p)
 if seat~=s.seatTurn then return nil,'It is not your turn.' end
 if action=='play' then
  local ending=p['end'] or p.edge or 'right'
  if ending~='left' and ending~='right' then return nil,'Choose the left or right end.' end
  local index,tile
  for i,value in ipairs(s.hands[seat]) do if value.id==p.tileId then index=i;tile=value;break end end
  if not tile then return nil,'That tile is not in your hand.' end
  local left,right=tile.a,tile.b
  if #s.chain>0 then
   local value=ending=='left' and s.left or s.right
   if tile.a~=value and tile.b~=value then return nil,'The tile does not match that end.' end
   if (ending=='left' and tile.a==value) or (ending=='right' and tile.b==value) then left,right=right,left end
  end
  local n=copy(s);table.remove(n.hands[seat],index)
  local placed={id=tile.id,a=tile.a,b=tile.b,left=left,right=right,seat=seat}
  if ending=='left' then table.insert(n.chain,1,placed) else n.chain[#n.chain+1]=placed end
  n.left=n.chain[1].left;n.right=n.chain[#n.chain].right;n.passes=0;n.ply=n.ply+1;n.lastAction='play'
  dominoObjects(n)
  if #n.hands[seat]==0 then n.status='won';n.winner=sideOf(seat);n.winnerSeat=seat;n.reason='empty-hand'
  else dominoNext(n) end
  return n
 elseif action=='draw' then
  if #dominoMoves(s,seat)>0 then return nil,'Play a matching tile before drawing.' end
  if #s.drawPile==0 then return nil,'The draw pile is empty. Pass instead.' end
  local n=copy(s);local tile=table.remove(n.drawPile);n.hands[seat][#n.hands[seat]+1]=tile
  n.ply=n.ply+1;n.lastAction='draw';return n
 elseif action=='pass' then
  if #dominoMoves(s,seat)>0 then return nil,'A matching tile must be played.' end
  if #s.drawPile>0 then return nil,'Draw before passing.' end
  local n=copy(s);n.passes=n.passes+1;n.ply=n.ply+1;n.lastAction='pass'
  if n.passes>=#n.seats then dominoBlocked(n) else dominoNext(n) end
  return n
 end
 return nil,'Unknown domino action.'
end
local CARD_LENGTH,CARD_WIDTH,GAP,THICK=.088,.063,.052,.0005
local H=math.sqrt(CARD_LENGTH^2-(GAP/2)^2)
R.cardDimensions={length=CARD_LENGTH,width=CARD_WIDTH,thickness=THICK,frameGap=GAP,frameHeight=H,levelHeight=H+THICK}
local function axes(yaw) local a=math.rad(yaw);return math.cos(a),math.sin(a),-math.sin(a),math.cos(a) end
local function localXY(x,y,base) local ux,uy,vx,vy=axes(base.yaw);local dx,dy=x-base.x,y-base.y;return dx*ux+dy*uy,dx*vx+dy*vy end
local function within(x,y,structure,halfX,halfY)
 local a,b=localXY(x,y,structure);return math.abs(a)<=halfX+1e-6 and math.abs(b)<=halfY+1e-6
end
local function angleClose(a,b) local d=(a-b)%180;return math.min(d,180-d)<3 end
local function onBoard(o,halfX,halfY)
 local ux,uy,vx,vy=axes(o.yaw)
 for _,a in ipairs({-halfX,halfX}) do for _,b in ipairs({-halfY,halfY}) do
  if math.abs(o.x+ux*a+vx*b)>.5 or math.abs(o.y+uy*a+vy*b)>.375 then return false end
 end end return true
end
local function supportsFor(s,o)
 if o.level==0 then return {} end
 if o.kind=='frame' then
  local ux,uy,vx,vy=axes(o.yaw)
  for _,roof in ipairs(s.structures) do if roof.kind=='roof' and roof.level==o.level then
   local fits=true
   for _,a in ipairs({-GAP/2,GAP/2}) do for _,b in ipairs({-CARD_WIDTH/2,CARD_WIDTH/2}) do
    if not within(o.x+ux*a+vx*b,o.y+uy*a+vy*b,roof,CARD_LENGTH/2,CARD_WIDTH/2) then fits=false end
   end end
   if fits then return {roof.id} end
  end end
  return nil
 end
 local peaks={}
 for _,frame in ipairs(s.structures) do
  if frame.kind=='frame' and frame.level==o.level-1 and angleClose(frame.yaw,o.yaw) and within(frame.x,frame.y,o,CARD_LENGTH/2-.004,CARD_WIDTH/2) then peaks[#peaks+1]=frame end
 end
 for i=1,#peaks do for j=i+1,#peaks do
  local a,b=peaks[i],peaks[j];local ax,ay=localXY(a.x,a.y,o);local bx,by=localXY(b.x,b.y,o)
  if math.abs(ax-bx)>=.035 and math.abs(ay-by)<=.008 and math.min(ax,bx)<=-.004 and math.max(ax,bx)>=.004 then return {a.id,b.id} end
 end end
 return nil
end
local function overlaps(s,o)
 -- Roof cards may overlap like real paper; their individual layer heights are
 -- offset below. Crossing A-frames still collide and collapse the structure.
 if o.kind=='roof' then return false end
 local hx=o.kind=='frame' and GAP/2 or CARD_LENGTH/2
 for _,existing in ipairs(s.structures) do if existing.kind==o.kind and existing.level==o.level then
  -- Separating-axis rectangle test; touching edges are allowed.
  local ehx=existing.kind=='frame' and GAP/2 or CARD_LENGTH/2
  local ux,uy,vx,vy=axes(o.yaw);local ex,ey,fx,fy=axes(existing.yaw)
  local separated=false
  for _,axis in ipairs({{ux,uy},{vx,vy},{ex,ey},{fx,fy}}) do
   local nx,ny=axis[1],axis[2]
   local distance=math.abs((o.x-existing.x)*nx+(o.y-existing.y)*ny)
   local radius=hx*math.abs(ux*nx+uy*ny)+CARD_WIDTH/2*math.abs(vx*nx+vy*ny)+ehx*math.abs(ex*nx+ey*ny)+CARD_WIDTH/2*math.abs(fx*nx+fy*ny)
   if distance>=radius-.00001 then separated=true;break end
  end
  if not separated then return true end
 end end return false
end
local function stableGraph(structures)
 local byId,load={},{}
 for _,o in ipairs(structures) do
  byId[o.id]=o;local mass=o.kind=='frame' and 2 or 1;load[o.id]={mass=mass,x=o.x*mass,y=o.y*mass}
 end
 -- Newer supports always point to older structures; walk backwards to carry
 -- both the weight and centre of mass of every upper floor to its supports.
 for i=#structures,1,-1 do local o=structures[i];local force=load[o.id];local x,y=force.x/force.mass,force.y/force.mass
  if o.kind=='frame' then
   if not within(x,y,o,GAP/2,CARD_WIDTH/2) then return false end
  elseif o.level>0 then
   local a,b=byId[o.supports[1]],byId[o.supports[2]]
   if not a or not b then return false end
   local ax,ay=localXY(a.x,a.y,o);local bx,by=localXY(b.x,b.y,o);local cx,cy=localXY(x,y,o)
   if cx<math.min(ax,bx)-1e-6 or cx>math.max(ax,bx)+1e-6 or math.abs(cy-(ay+by)/2)>CARD_WIDTH/2 then return false end
  end
  if #o.supports==1 then
   local dest=load[o.supports[1]];if not dest then return false end
   dest.mass=dest.mass+force.mass;dest.x=dest.x+x*force.mass;dest.y=dest.y+y*force.mass
  elseif #o.supports==2 then
   local a,b=byId[o.supports[1]],byId[o.supports[2]];local dx,dy=b.x-a.x,b.y-a.y
   local t=((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy)
   for index,id in ipairs(o.supports) do local point=byId[id];local dest=load[id];local mass=force.mass*(index==1 and 1-t or t)
    dest.mass=dest.mass+mass;dest.x=dest.x+point.x*mass;dest.y=dest.y+point.y*mass
   end
  end
 end
 return true
end
local function collapse(s,now)
 s.status='collapsed';s.collapse={startedAt=now,t0=now,seed=s.ply*7919,gravity=9.81,objects={}}
 local random=rng(s.collapse.seed)
 for _,o in ipairs(s.objects) do
  s.collapse.objects[o.id]={x=o.x,y=o.y,z=o.z,vx=(random(201)-101)/500,vy=(random(201)-101)/500,vz=.025+random(30)/1000,angularVelocity=(random(361)-181)}
 end
 return s
end
local function cardtower(s,seat,action,p)
 if action~='place' then return nil,'Unknown card tower action.' end
 local orientation=p.orientation or 'frame';if orientation=='pair' then orientation='frame' end
 if orientation~='frame' and orientation~='flat' and orientation~='lean-left' and orientation~='lean-right' then return nil,'Choose an A-frame or a flat roof.' end
 if not finite(p.x) or not finite(p.y) or not integer(p.level or 0,0,52) or not finite(p.yaw or 0) then return nil,'Invalid card placement.' end
 local o={id='support:'..tostring(s.ply+1),kind=orientation=='flat' and 'roof' or 'frame',x=p.x,y=p.y,level=p.level or 0,yaw=((p.yaw or 0)+180)%360-180,seat=seat,supports={}}
 local cost=orientation=='frame' and 2 or 1
 if s.remaining<cost then return nil,'There are not enough cards left.' end
 if not onBoard(o,o.kind=='frame' and GAP/2 or CARD_LENGTH/2,CARD_WIDTH/2) then return nil,'Keep the cards on the tabletop.' end
 local supports=supportsFor(s,o);local stable=supports~=nil and not overlaps(s,o) and (orientation=='frame' or orientation=='flat')
 o.supports=supports or {}
 o.baseZ=o.level*(H+THICK)
 if o.kind=='frame' and #o.supports==1 then
  for _,structure in ipairs(s.structures) do if structure.id==o.supports[1] then o.baseZ=structure.surfaceZ end end
 end
 o.surfaceZ=o.kind=='frame' and o.baseZ+H or o.baseZ
 if o.kind=='roof' then
  local z=o.level==0 and 0 or o.baseZ-THICK
  for _,structure in ipairs(s.structures) do
   for _,id in ipairs(o.supports) do if structure.id==id then z=math.max(z,structure.surfaceZ) end end
   if structure.kind=='roof' and structure.level==o.level and within(o.x,o.y,structure,CARD_LENGTH,CARD_WIDTH) then z=math.max(z,structure.surfaceZ) end
  end
  o.surfaceZ=z+THICK
 end
 local n=copy(s);n.ply=n.ply+1;n.remaining=n.remaining-cost;n.structures[#n.structures+1]=o;n.turn=sideOf(seat)
 local ux,uy=axes(o.yaw);local base=o.baseZ
 local function card(pose,x,y,z)
  n.cardSerial=n.cardSerial+1
  n.objects[#n.objects+1]={id='card:'..n.cardSerial,kind='playing_card',pose=pose,orientation=pose,x=x,y=y,z=z,yaw=o.yaw,level=o.level,support=o.id,seat=seat}
 end
 if orientation=='frame' then card('lean-left',o.x-ux*GAP/2,o.y-uy*GAP/2,base);card('lean-right',o.x+ux*GAP/2,o.y+uy*GAP/2,base)
 elseif orientation=='flat' then card('flat',o.x,o.y,o.surfaceZ-THICK/2)
 else card(orientation,o.x,o.y,base) end
 if not stable or not stableGraph(n.structures) then return collapse(n,finite(p.nowMs or p.nowUnixMs) and (p.nowMs or p.nowUnixMs) or 0) end
 n.height=math.max(n.height or 0,o.surfaceZ)
 return n
end
function R.new(kind,mode,seed)
 if kind~='roulette' and kind~='dominoes' and kind~='cardtower' then return nil,'Unknown tabletop game.' end
 local s={kind=kind,mode=mode or 'duel',turn='white',status='playing',ply=0,captured={},objects={}}
 if kind=='roulette' then s.round=1;s.phase='betting';s.bets={};s.betSerial=0
 elseif kind=='cardtower' then s.structures={};s.remaining=52;s.cardSerial=0;s.height=0
 else
  s.seats=mode=='teams' and copy(SEATS) or {'white','black'};s.hands={};s.drawPile={};s.chain={};s.passes=0
  local tiles={};for a=0,6 do for b=a,6 do tiles[#tiles+1]={id='d'..a..'_'..b,a=a,b=b} end end
  local random=rng(seed);for i=#tiles,2,-1 do local j=random(i);tiles[i],tiles[j]=tiles[j],tiles[i] end
  for _,seat in ipairs(s.seats) do s.hands[seat]={};for _=1,7 do s.hands[seat][#s.hands[seat]+1]=table.remove(tiles) end end
  s.drawPile=tiles
  local highest,best=-1,s.seats[1]
  for _,seat in ipairs(s.seats) do for _,tile in ipairs(s.hands[seat]) do if tile.a==tile.b and tile.a>highest then highest=tile.a;best=seat end end end
  s.seatTurn=best;s.turn=sideOf(best)
 end
 return s
end
function R.act(s,seat,action,payload)
 if type(s)~='table' or s.status~='playing' then return nil,'This game has ended. Start a new game.' end
 if not seatOK(seat) or type(action)~='string' or (payload~=nil and type(payload)~='table') then return nil,'Invalid game action.' end
 local p=payload or {}
 if s.kind=='roulette' then return roulette(s,seat,action,p)
 elseif s.kind=='dominoes' then return domino(s,seat,action,p)
 elseif s.kind=='cardtower' then return cardtower(s,seat,action,p) end
 return nil,'Unknown tabletop game.'
end
function R.legalMoves(s,seat,yieldFn)
 if type(s)~='table' or s.kind~='dominoes' or s.status~='playing' then return {} end
 return dominoMoves(s,seat or s.seatTurn,workFor(yieldFn))
end
function R.aiMove(s,yieldFn)
 if type(s)~='table' or s.kind~='dominoes' or s.status~='playing' then return nil,'No domino AI move is available.' end
 local work=workFor(yieldFn);local moves=dominoMoves(s,s.seatTurn,work);local best,score
 for _,move in ipairs(moves) do
  if work then work() end
  local tile;for _,t in ipairs(s.hands[s.seatTurn]) do if t.id==move.tileId then tile=t;break end end
  local value=tile.a+tile.b+(tile.a==tile.b and 3 or 0)
  if not score or value>score then score=value;best=move end
 end
 local action,payload='play',best
 if not best then action=#s.drawPile>0 and 'draw' or 'pass';payload={} end
 -- Copy in small slices before applying an otherwise tiny action. State is at
 -- most 28 tiles, so the authoritative action itself has a fixed small bound.
 local analysis=copy(s,work)
 if yieldFn then yieldFn() end
 local n,why=R.act(analysis,s.seatTurn,action,payload)
 if not n then return nil,why end
 return n,{action=action,operation=action,payload=payload,data=payload}
end
local function stripPrivate(t)
 if type(t)~='table' then return end
 for k,v in pairs(t) do if type(k)=='string' and k:sub(1,1)=='_' then t[k]=nil else stripPrivate(v) end end
end
function R.view(s,seat)
 local n=copy(s);stripPrivate(n);n.rouletteOwners=nil
 if s.kind=='dominoes' then
  n.hand=copy(s.hands[seat] or {});n.drawCount=#s.drawPile;n.drawPile=nil
  n.handCounts={}
  for id,hand in pairs(s.hands) do
   n.handCounts[id]=#hand
   if id~=seat then n.hands[id]={};for i=1,#hand do n.hands[id][i]={hidden=true} end end
  end
 end
 return n
end
