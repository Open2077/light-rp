-- Pool (8-ball): item, kind, a pure deterministic 2D shot simulation and the
-- rules. No randomness and no clock here: the server passes the rack seed and
-- the time. A shot is simulated once, on the server, into motion segments
-- (constant deceleration between events); every client evaluates the balls
-- analytically from those segments and the server clock.
--
-- Units: metres, seconds. The table frame has its origin at the centre of the
-- playing surface, +X towards the foot (the rack), -X towards the head string.
-- The client maps it to board-local unscaled metres (x/0.65, see
-- client/core/casino_pool.lua and tools/build-casino-pool-props.py).
LightRpBoardGames.pool={item="pool_table",label="Pool Table",title="Pool",size=1,floor=0}
LightRpItems.pool_table={label="Pool Table",description="Use to place the table. E: play; target menu: pick up your table.",weight=12,stack=1,icon="package",category="misc"}

LightRpPool={}
local P=LightRpPool
-- 9 ft table: 2.54 x 1.27 m between the cushion noses, 57.15 mm balls.
P.L,P.W=2.54,1.27
P.R=.028575
P.X,P.Y=P.L/2-P.R,P.W/2-P.R       -- limits of a ball centre (cushion lines)
-- Pocket mouths, measured on the cushion lines: a ball centre crossing a
-- line within CORNER of a corner, or within SIDE of the middle of a long
-- rail, drops; anywhere else the cushion sends it back.
P.CORNER,P.SIDE=.085,.046
P.HEAD_X,P.FOOT_X=-P.L/4,P.L/4    -- head string, foot spot
P.DECEL=.75                       -- rolling + sliding loss, m/s^2
P.BALL_E,P.RAIL_E=.95,.78         -- restitution: ball-ball, cushion (normal part)
P.MIN_SPEED,P.MAX_SPEED=.3,5.5    -- cue ball speed at power 0 / 1, m/s
P.LEAD=250                        -- ms from the request to the strike on every client
P.DROP=320                        -- ms a pocketed ball takes to sink (client animation)
-- Hard bounds of one simulation (tools/test-casino-pool.py proves them).
P.MAX_EVENTS=320                  -- velocity changes (collisions, cushions, pockets)
P.MAX_SEGMENTS=170                -- recorded segments, 15 chars each on the wire
P.MAX_WORK=40000                  -- contact-search iterations
P.MAX_TIME=20                     -- s of simulated motion
P.RACK_GAP=.0004                  -- between racked balls: never two contacts at once
P.TOUCH=.0015                     -- balls closer than this share a collision (a cluster)
-- Pocket centres (for the client's drop animation): 1..4 corners
-- (-x-y, +x-y, +x+y, -x+y), 5/6 the side pockets (-y, +y).
P.POCKETS={{-P.L/2-.022,-P.W/2-.022},{P.L/2+.022,-P.W/2-.022},{P.L/2+.022,P.W/2+.022},{-P.L/2-.022,P.W/2+.022},{0,-P.W/2-.038},{0,P.W/2+.038}}
P.SEATS={"white","black"}
-- Model layout (real metres, shared with tools/build-casino-pool-props.py):
-- the playing surface above the floor, and the ball return on the foot end
-- apron where pocketed object balls line up (ball centres, pocket order).
P.BED=.76
P.TRAY={x=P.L/2+.105,y0=-.43,z=P.BED-.155,step=2*P.R+.0015}
-- Hidden props (the cue between shots, a ball in hand) park inside the closed
-- spine of the base: x of the cue's tip, z of both.
P.PARK={cueX=.73,z=.30}

-- Wire encoding --------------------------------------------------------------
-- Positions, velocities and times travel as integers in 1/UNIT (0.1 mm,
-- 0.1 mm/s, 0.1 ms), packed as 3 base64url characters each (signed values
-- offset by OFF). Strings cost no event nesting depth and stay compact.
P.UNIT=10000
local UNIT=P.UNIT
local ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local OFF=131072
local CH,DIGIT={},{}
for i=1,64 do CH[i-1]=ALPHA:sub(i,i);DIGIT[ALPHA:byte(i)]=i-1 end
P.ALPHA,P.DIGIT,P.OFF=ALPHA,DIGIT,OFF
P.REC=15                          -- segment record: t x y vx vy
P.NONE="!!!!!!"                   -- a pocketed ball in the position string
local floor,sqrt,abs=math.floor,math.sqrt,math.abs
local function enc3(v)
 v=floor(v+.5)+OFF
 if v<0 then v=0 elseif v>262143 then v=262143 end
 return CH[floor(v/4096)]..CH[floor(v/64)%64]..CH[v%64]
end
P.enc3=enc3
-- Signed integer at byte position i of s.
function P.dec3(s,i)
 local a,b,c=s:byte(i,i+2)
 return DIGIT[a]*4096+DIGIT[b]*64+DIGIT[c]-OFF
end
function P.ballChar(i) return CH[i-1] end           -- ball index 1..16 (cue, 1..15)
function P.ballIndex(c) local d=DIGIT[c:byte()];return d and d+1 end
local function q(v) return floor(v*UNIT+.5)/UNIT end
P.quantize=q

-- 16 balls: index 1 is the cue ball, index i>1 is ball number i-1.
function P.encodePositions(balls)
 local out={}
 for i=1,16 do
  local b=balls[i]
  out[i]=b and (enc3(b[1]*UNIT)..enc3(b[2]*UNIT)) or P.NONE
 end
 return table.concat(out)
end
function P.decodePositions(s)
 local balls={}
 local ok=type(s)=="string" and #s>=96
 local D=DIGIT
 for i=1,16 do
  local a,b,c,d,e,f
  if ok then a,b,c,d,e,f=s:byte(i*6-5,i*6) end
  if a and D[a] then balls[i]={(D[a]*4096+D[b]*64+D[c]-OFF)/UNIT,(D[d]*4096+D[e]*64+D[f]-OFF)/UNIT} else balls[i]=false end
 end
 return balls
end

-- Motion --------------------------------------------------------------------
-- Position and velocity d seconds into a segment (start x,y, velocity vx,vy):
-- straight line, constant deceleration until it stops.
local A=P.DECEL
function P.motion(x,y,vx,vy,d)
 if vx==0 and vy==0 then return x,y,0,0 end
 local s=sqrt(vx*vx+vy*vy);local ts=s/A
 if d<0 then d=0 end
 if d>=ts then local k=.5*s*ts;return x+vx/s*k,y+vy/s*k,0,0 end
 local k=s*d-.5*A*d*d;local v=(s-A*d)/s
 return x+vx/s*k,y+vy/s*k,vx*v,vy*v
end
-- Segment record r (1-based) of a ball's string: t (s), x, y, vx, vy.
-- One string.byte call: the client decodes records inside its frame budget.
function P.record(s,r)
 local i=(r-1)*15+1
 local a,b,c,d,e,f,g,h,k,l,m,n,o,p,q=s:byte(i,i+14)
 local D=DIGIT
 return (D[a]*4096+D[b]*64+D[c]-OFF)/UNIT,(D[d]*4096+D[e]*64+D[f]-OFF)/UNIT,(D[g]*4096+D[h]*64+D[k]-OFF)/UNIT,
  (D[l]*4096+D[m]*64+D[n]-OFF)/UNIT,(D[o]*4096+D[p]*64+D[q]-OFF)/UNIT
end
function P.records(s) return floor(#(s or "")/P.REC) end

-- The simulation -----------------------------------------------------------
-- balls: 16 entries {x,y} or false; yaw radians; speed m/s.
-- Event driven: the earliest of every cushion crossing (exact: quadratic) and
-- every ball contact (conservative advancement on the quartic gap function,
-- below) is processed, the balls involved get a new segment, repeat. Each new
-- segment starts on the quantized grid, so what the server continues from is
-- exactly what the wire carries.
function P.simulate(balls,yaw,speed)
 local N=16
 local X,Y,R,D=P.X,P.Y,P.R,2*P.R
 local D2=D*D
 local EPSF=2*D*1e-6      -- gap of a micron, in |d|^2-D^2 units
 local MINSTEP=.0005
 local x0,y0,t0,vx,vy,sp,ux,uy,alive={},{},{},{},{},{},{},{},{}
 local segs={}
 for i=1,N do
  local b=balls[i]
  alive[i]=b and true or false
  x0[i],y0[i]=b and b[1] or 0,b and b[2] or 0
  t0[i],vx[i],vy[i],sp[i],ux[i],uy[i]=0,0,0,0,0,0
  segs[i]={}
 end
 local nseg,events,work=0,0,0
 local partner={}          -- the pair that just collided is not searched again
 local firstHit,rail=nil,false
 local pocketed,order={},{}
 local capped=nil
 local function posAt(i,t)
  local s=sp[i];if s==0 then return x0[i],y0[i] end
  local d=t-t0[i];local ts=s/A
  if d>ts then d=ts elseif d<0 then d=0 end
  local k=s*d-.5*A*d*d
  return x0[i]+ux[i]*k,y0[i]+uy[i]*k
 end
 local function speedAt(i,t)
  local s=sp[i];if s==0 then return 0 end
  local d=t-t0[i];if d<0 then d=0 end
  local v=s-A*d;return v>0 and v or 0
 end
 local function rebase(i,T,px,py,nvx,nvy)
  local Tq=q(T)
  x0[i],y0[i],t0[i]=q(px),q(py),Tq
  nvx,nvy=q(nvx),q(nvy)
  local s=sqrt(nvx*nvx+nvy*nvy)
  if s<.002 then nvx,nvy,s=0,0,0 end
  vx[i],vy[i],sp[i]=nvx,nvy,s
  if s>0 then ux[i],uy[i]=nvx/s,nvy/s else ux[i],uy[i]=0,0 end
  local list=segs[i];list[#list+1]={Tq,x0[i],y0[i],nvx,nvy};nseg=nseg+1
  for j=1,N do if partner[j]==i then partner[j]=nil end end
  partner[i]=nil
 end
 -- First cushion line crossing of ball i at or after `now`.
 local function cushion(i,now)
  local s=sp[i];local smax=s*s/(2*A)
  local d=now-t0[i];if d<0 then d=0 end
  local cur=s*d-.5*A*d*d
  local best,axis
  for a=1,2 do
   local u=a==1 and ux[i] or uy[i]
   if u~=0 then
    local line=(a==1 and X or Y)*(u>0 and 1 or -1)
    local need=(line-(a==1 and x0[i] or y0[i]))/u
    local t
    if need<=cur then t=now
    elseif need<=smax then t=t0[i]+(s-sqrt(math.max(0,s*s-2*A*need)))/A end
    if t and (not best or t<best) then best,axis=t,a end
   end
  end
  return best,axis
 end
 -- First contact of balls i and j after t, before limit. f(h)=|d(t+h)|^2-D^2
 -- is a quartic while neither ball stops: f0+f1 h+f2 h^2+f3 h^3+f4 h^4 with
 -- f4>=0. Only negative terms can bring it down, so on [0,H] f(h) >=
 -- f0-h*K(H), K=max(0,-f1)+max(0,-f2)H+max(0,-f3)H^2: stepping h=f0/K never
 -- passes a contact, and near one it is a Newton step. A pair that is
 -- touching and separating first moves on to where f could fall back.
 local function contact(i,j,t,limit)
  for _=1,40 do
   work=work+1
   local si,sj=speedAt(i,t),speedAt(j,t)
   if si==0 and sj==0 then return nil end
   local xi,yi=posAt(i,t);local xj,yj=posAt(j,t)
   local dx,dy=xj-xi,yj-yi
   local wx,wy=ux[j]*sj-ux[i]*si,uy[j]*sj-uy[i]*si
   local rx,ry=0,0
   if si>0 then rx,ry=.5*A*ux[i],.5*A*uy[i] end
   if sj>0 then rx,ry=rx-.5*A*ux[j],ry-.5*A*uy[j] end
   local pe=limit
   if si>0 then local e=t0[i]+sp[i]/A;if e>t and e<pe then pe=e end end
   if sj>0 then local e=t0[j]+sp[j]/A;if e>t and e<pe then pe=e end end
   local H=pe-t
   local f0=dx*dx+dy*dy-D2
   local f1=2*(dx*wx+dy*wy)
   local f2=wx*wx+wy*wy+2*(dx*rx+dy*ry)
   local f3=2*(wx*rx+wy*ry)
   local n2=f2<0 and -f2 or 0
   local n3=f3<0 and -f3 or 0
   local h
   if f0<=EPSF then
    if f1<0 then return t end
    local K=n2+n3*H
    h=K>0 and f1/(2*K) or H
    if h<MINSTEP then h=MINSTEP end
   else
    if sqrt(f0+D2)-D>(si*si+sj*sj)/(2*A) then return nil end
    local n1=f1<0 and -f1 or 0
    local K=n1+n2*H+n3*H*H
    if K<=0 then h=H else
     h=f0/K
     if h<H then
      local H2=2*h;local h2=f0/(n1+n2*H2+n3*H2*H2)
      if h2>H2 then h2=H2 end
      if h2>h then h=h2 end
     end
    end
   end
   if h>=H then t=pe else t=t+h end
   if t>=limit then return nil end
  end
  return t,true -- not settled within the iteration budget: look again then
 end
 local function freeze(T)
  for i=1,N do if alive[i] and speedAt(i,T)>0 then local px,py=posAt(i,T);rebase(i,T,px,py,0,0) end end
 end
 -- The strike.
 rebase(1,0,x0[1],y0[1],math.cos(yaw)*speed,math.sin(yaw)*speed)
 local now=0
 local cx,cy,rem={},{},{}
 while true do
  if events>=P.MAX_EVENTS or nseg>=P.MAX_SEGMENTS-N or work>=P.MAX_WORK then capped=events>=P.MAX_EVENTS and "events" or nseg>=P.MAX_SEGMENTS-N and "segments" or "work";freeze(now);break end
  local best,kind,bi,bj,ba=P.MAX_TIME,nil
  local moving=false
  for i=1,N do
   if alive[i] then
    cx[i],cy[i]=posAt(i,now)
    local v=speedAt(i,now);rem[i]=v*v/(2*A)
    if v>0 then
     moving=true
     local t,a=cushion(i,now)
     if t and t<best then best,kind,bi,ba=t,"rail",i,a end
    end
   end
  end
  if not moving then break end
  for i=1,N-1 do if alive[i] then
   for j=i+1,N do if alive[j] and (rem[i]>0 or rem[j]>0) and partner[i]~=j and partner[j]~=i then
    local dx,dy=cx[j]-cx[i],cy[j]-cy[i]
    local gap=sqrt(dx*dx+dy*dy)-D
    if gap<=rem[i]+rem[j] then
     local t,again=contact(i,j,now,best)
     if t and t<best then best,kind,bi,bj=t,again and "check" or "ball",i,j end
    end
   end end
  end end
  if not kind then
   -- Nothing happens before MAX_TIME: stop whatever still moves then.
   local late=false
   for i=1,N do if alive[i] and sp[i]>0 and t0[i]+sp[i]/A>P.MAX_TIME then late=true end end
   if late then capped="time";freeze(P.MAX_TIME) end
   break
  end
  now=best
  if kind=="rail" then
   events=events+1
   local i=bi
   local px,py=posAt(i,now)
   local v=speedAt(i,now)
   local nvx,nvy=ux[i]*v,uy[i]*v
   local pocket
   if ba==1 then
    px=nvx>0 and X or -X
    if abs(py)>Y-P.CORNER then pocket=px>0 and (py>0 and 3 or 2) or (py>0 and 4 or 1) end
   else
    py=nvy>0 and Y or -Y
    if abs(px)>X-P.CORNER then pocket=px>0 and (py>0 and 3 or 2) or (py>0 and 4 or 1)
    elseif abs(px)<P.SIDE then pocket=py>0 and 6 or 5 end
   end
   if firstHit then rail=true end
   if pocket then
    rebase(i,now,px,py,nvx,nvy)
    alive[i]=false;pocketed[i]={k=pocket,t=t0[i]};order[#order+1]=i
   elseif ba==1 then rebase(i,now,px,py,-nvx*P.RAIL_E,nvy)
   else rebase(i,now,px,py,nvx,-nvy*P.RAIL_E) end
  elseif kind=="ball" then
   events=events+1
   local i,j=bi,bj
   if not firstHit and (i==1 or j==1) then firstHit=i==1 and j or i end
   -- Every ball touching the pair (a frozen cluster, the rack) takes part:
   -- the impulses of all its contacts are resolved together (below), so a
   -- break spreads the rack instead of passing the cue ball's momentum down
   -- one chain like a Newton's cradle.
   local members,inside={i,j},{[i]=true,[j]=true}
   local k=1
   while k<=#members do
    local a=members[k];k=k+1
    local ax,ay=posAt(a,now)
    for b=1,N do if alive[b] and not inside[b] then
     local bx,by=posAt(b,now)
     if (bx-ax)^2+(by-ay)^2<=(D+P.TOUCH)^2 then inside[b]=true;members[#members+1]=b end
    end end
   end
   local px,py,pvx,pvy={},{},{},{}
   for _,m in ipairs(members) do
    px[m],py[m]=posAt(m,now);local s=speedAt(m,now);pvx[m],pvy[m]=ux[m]*s,uy[m]*s
   end
   -- Contacts (pairs within TOUCH) and how many each ball has.
   local ca,cb,cnx,cny,share={},{},{},{},{}
   local count={}
   for x=1,#members-1 do for y=x+1,#members do
    local a,b=members[x],members[y]
    local dx,dy=px[b]-px[a],py[b]-py[a];local l=sqrt(dx*dx+dy*dy)
    if l<=D+P.TOUCH then
     if l<1e-9 then dx,dy,l=1,0,1 end
     ca[#ca+1],cb[#cb+1],cnx[#cnx+1],cny[#cny+1]=a,b,dx/l,dy/l
     count[a]=(count[a] or 0)+1;count[b]=(count[b] or 0)+1
    end
   end end
   for c=1,#ca do local na,nb=count[ca[c]],count[cb[c]];share[c]=1/(na>nb and na or nb) end
   -- Poisson restitution, all contacts at once: a compression phase finds
   -- the impulses that stop every approach (Jacobi accumulated impulses,
   -- never pulling, each shared by the busier of its two balls and applied to
   -- both), then each contact gets BALL_E times its compression impulse back.
   -- A lone pair is the textbook collision; a cluster shares the blow (the
   -- rack spreads); momentum is conserved and energy only lost.
   local J={}
   for c=1,#ca do J[c]=0 end
   for _=1,150 do
    work=work+#ca
    local dvx,dvy,moved={},{},0
    for c=1,#ca do
     local a,b=ca[c],cb[c]
     local rel=(pvx[a]-pvx[b])*cnx[c]+(pvy[a]-pvy[b])*cny[c]
     local nj=J[c]+rel/2*share[c];if nj<0 then nj=0 end
     local dj=nj-J[c];J[c]=nj
     if dj~=0 then
      if abs(dj)>moved then moved=abs(dj) end
      dvx[a]=(dvx[a] or 0)-dj*cnx[c];dvy[a]=(dvy[a] or 0)-dj*cny[c]
      dvx[b]=(dvx[b] or 0)+dj*cnx[c];dvy[b]=(dvy[b] or 0)+dj*cny[c]
     end
    end
    for m,v in pairs(dvx) do pvx[m]=pvx[m]+v;pvy[m]=pvy[m]+dvy[m] end
    if moved<1e-6 then break end
   end
   for c=1,#ca do
    local a,b,dj=ca[c],cb[c],P.BALL_E*J[c]
    pvx[a],pvy[a]=pvx[a]-dj*cnx[c],pvy[a]-dj*cny[c]
    pvx[b],pvy[b]=pvx[b]+dj*cnx[c],pvy[b]+dj*cny[c]
   end
   for _,m in ipairs(members) do
    local s=speedAt(m,now)
    if m==i or m==j or abs(pvx[m]-ux[m]*s)+abs(pvy[m]-uy[m]*s)>5e-4 then rebase(m,now,px[m],py[m],pvx[m],pvy[m]) end
   end
   -- The pair is not searched again until one of them changes course.
   partner[i],partner[j]=j,i
  end
  -- "check": nothing changes, the search resumes from here.
 end
 -- Rest positions and timing.
 local final,stop={},0
 for i=1,N do
  if alive[i] then
   local s=sp[i];local e=t0[i]+(s>0 and s/A or 0)
   if e>stop then stop=e end
   local px,py=posAt(i,math.huge)
   final[i]={q(px),q(py)}
  else
   final[i]=false
   if pocketed[i] then local e=pocketed[i].t+P.DROP/1000;if e>stop then stop=e end end
  end
 end
 return {segs=segs,final=final,pocketed=pocketed,order=order,firstHit=firstHit,rail=rail,
  duration=stop,events=events,segments=nseg,work=work,capped=capped}
end

-- Segments to the wire: one string per ball (15-char records t x y vx vy).
function P.encodeSegments(list)
 local out={}
 for k,s in ipairs(list) do out[k]=enc3(s[1]*UNIT)..enc3(s[2]*UNIT)..enc3(s[3]*UNIT)..enc3(s[4]*UNIT)..enc3(s[5]*UNIT) end
 return table.concat(out)
end
-- Drops: per pocketed ball, ball char, pocket digit, time (t in 0.1 ms).
function P.encodeDrops(r)
 local out={}
 for _,i in ipairs(r.order) do local p=r.pocketed[i];out[#out+1]=CH[i-1]..CH[p.k]..enc3(p.t*UNIT) end
 return table.concat(out)
end
function P.decodeDrops(s)
 local list={}
 for at=1,#(s or "")-4,5 do
  list[#list+1]={ball=DIGIT[s:byte(at)]+1,pocket=DIGIT[s:byte(at+1)],t=P.dec3(s,at+2)/UNIT}
 end
 return list
end

-- The rack ---------------------------------------------------------------------
-- Apex (the 1) on the foot spot, rows towards the foot rail, the 8 in the
-- middle, one solid and one stripe in the back corners, the rest shuffled by
-- the server seed (Park-Miller). Racked balls keep RACK_GAP between them.
function P.rack(seed)
 local state=floor(tonumber(seed) or 1)%2147483647
 if state<=0 then state=state+2147483646 end
 local function rnd(n) state=(state*16807)%2147483647;return floor(state%n)+1 end
 local solids,stripes={2,3,4,5,6,7},{9,10,11,12,13,14,15}
 local corner1=table.remove(solids,rnd(#solids))
 local corner2=table.remove(stripes,rnd(#stripes))
 if rnd(2)==2 then corner1,corner2=corner2,corner1 end
 local rest={}
 for _,n in ipairs(solids) do rest[#rest+1]=n end
 for _,n in ipairs(stripes) do rest[#rest+1]=n end
 for i=#rest,2,-1 do local j=rnd(i);rest[i],rest[j]=rest[j],rest[i] end
 local d=2*P.R+P.RACK_GAP;local dx=d*sqrt(3)/2
 local balls={}
 balls[1]={q(P.HEAD_X),0}
 local k=0
 for row=0,4 do
  for j=0,row do
   local num
   if row==0 then num=1
   elseif row==2 and j==1 then num=8
   elseif row==4 and j==0 then num=corner1
   elseif row==4 and j==4 then num=corner2
   else k=k+1;num=rest[k] end
   balls[num+1]={q(P.FOOT_X+row*dx),q((j-row/2)*d)}
  end
 end
 return balls
end

-- The rules --------------------------------------------------------------------
local function copy(t)
 if type(t)~="table" then return t end
 local n={} for k,v in pairs(t) do n[k]=copy(v) end return n
end
P.copy=copy
local function finite(n) return type(n)=="number" and n==n and abs(n)<9007199254740991 end
local function other(seat) return seat=="white" and "black" or "white" end
P.other=other
function P.group(i)
 local n=i-1
 if n>=1 and n<=7 then return "solids" elseif n>=9 and n<=15 then return "stripes" end
end
function P.groupOf(s,seat)
 if not s.solids then return nil end
 return s.solids==seat and "solids" or "stripes"
end
local function left(balls,group)
 local n=0
 for i=2,16 do if balls[i] and P.group(i)==group then n=n+1 end end
 return n
end
P.left=left
function P.new(mode,seed)
 local s={kind="pool",mode=mode=="solo" and "solo" or "duel",status="playing",ply=0,captured={},objects={},
  rack=1,breaker="white",turn="white",phase="break",potted=""}
 s.pos=P.encodePositions(P.rack(seed))
 return s
end
-- The shot in flight: until shot.at+shot.dur (server ms) nobody may act.
function P.busy(s,now)
 local shot=type(s)=="table" and s.shot
 return type(shot)=="table" and finite(now) and now<(tonumber(shot.at) or 0)+(tonumber(shot.dur) or 0)
end
function P.endsAt(s)
 local shot=s.shot;if type(shot)~="table" then return 0 end
 return (tonumber(shot.at) or 0)+(tonumber(shot.dur) or 0)
end
local function ready(s,seat,now)
 if type(s)~="table" or s.kind~="pool" then return nil,"Invalid pool table." end
 if not finite(now) then return nil,"The server must provide the time." end
 if s.status~="playing" then return nil,"The game is over: re-rack to play again." end
 if seat~=s.turn then return nil,"It is not your shot." end
 if P.busy(s,now) then return nil,"Wait for the balls to stop." end
 return true
end
-- The foot spot for a re-spotted 8 (or the nearest free point behind it).
local function spot(balls)
 local D=2*P.R
 for k=0,400 do
  for _,sign in ipairs({1,-1}) do
   local x=P.FOOT_X+sign*k*.001
   if x<=P.X then
    local free=true
    for i=1,16 do local b=balls[i];if b and (b[1]-x)^2+b[2]^2<D*D then free=false;break end end
    if free then return {q(x),0} end
   end
  end
 end
 return {q(P.FOOT_X),0}
end
-- p.yaw degrees (table frame), p.power 0..1, p.nowMs.
function P.shoot(s,seat,p)
 p=p or {}
 local ok,why=ready(s,seat,p.nowMs);if not ok then return nil,why end
 if s.inHand then return nil,"Place the cue ball first." end
 local yaw,power=p.yaw,p.power
 if not finite(yaw) or abs(yaw)>720 then return nil,"Invalid aim." end
 if not finite(power) or power<0 or power>1 then return nil,"Invalid power." end
 yaw=(floor(yaw*100+.5)/100)%360;power=floor(power*1000+.5)/1000
 local balls=P.decodePositions(s.pos)
 if not balls[1] then return nil,"Place the cue ball first." end
 local r=P.simulate(balls,math.rad(yaw),P.MIN_SPEED+(P.MAX_SPEED-P.MIN_SPEED)*power)
 local n=copy(s);n.ply=s.ply+1
 local encoded={}
 for i=1,16 do encoded[i]=P.encodeSegments(r.segs[i]) end
 n.shot={n=n.ply,at=p.nowMs+P.LEAD,dur=math.ceil(r.duration*1000),yaw=yaw,power=power,by=seat,segs=encoded,drops=P.encodeDrops(r)}
 local final=r.final
 local isBreak=s.phase=="break"
 local scratch=r.pocketed[1]~=nil
 local eight=r.pocketed[9]~=nil
 local potted={}
 for _,i in ipairs(r.order) do if i>1 then potted[#potted+1]=i end end
 local last={n=n.ply,by=seat,scratch=scratch or nil}
 n.inHand=nil
 if s.mode=="solo" then
  -- Practice: no fouls, the cue ball comes back in hand after a scratch.
  local chars={};for _,i in ipairs(potted) do chars[#chars+1]=CH[i-1] end
  n.potted=(s.potted or "")..table.concat(chars)
  last.potted=table.concat(chars)
  if scratch then n.inHand="table" end
  n.turn="white";n.phase="practice"
  local any=false;for i=2,16 do if final[i] then any=true end end
  if not any then last.cleared=true end
  n.pos=P.encodePositions(final);n.last=last
  return n
 end
 local mine=P.groupOf(s,seat)
 local onEight=mine~=nil and left(balls,mine)==0
 local foul
 if scratch then foul="scratch"
 elseif not r.firstHit then foul="no_contact"
 elseif not isBreak then
  local first=r.firstHit
  if mine then
   if onEight then if first~=9 then foul="wrong_first" end
   elseif P.group(first)~=mine then foul="wrong_first" end
  elseif first==9 then foul="wrong_first" end
  if not foul and #potted==0 and not r.rail then foul="no_rail" end
 end
 local won,reason
 if eight then
  if isBreak then
   final[9]=spot(final)                    -- the 8 on the break comes back
   for k=#potted,1,-1 do if potted[k]==9 then table.remove(potted,k) end end
   last.respot=true
  elseif onEight and not foul then won,reason=seat,"eight"
  else won,reason=other(seat),onEight and "eight_foul" or "eight_early" end
 end
 local chars={};for _,i in ipairs(potted) do chars[#chars+1]=CH[i-1] end
 n.potted=(s.potted or "")..table.concat(chars)
 last.potted=table.concat(chars);last.foul=foul
 -- An open table is claimed by a clean shot that pots one group only.
 if not isBreak and not foul and not won and not s.solids and #potted>0 then
  local g
  for _,i in ipairs(potted) do local gi=P.group(i);if gi then if g and g~=gi then g="mixed" else g=g or gi end end end
  if g=="solids" then n.solids=seat;last.assigned=seat elseif g=="stripes" then n.solids=other(seat);last.assigned=seat end
 end
 local group=P.groupOf(n,seat)
 local kept=false
 if not foul and not won then
  for _,i in ipairs(potted) do
   local gi=P.group(i)
   if isBreak or (gi and (group==nil or gi==group)) then kept=true end
  end
 end
 last.kept=kept or nil
 n.pos=P.encodePositions(final)
 if won then
  n.status="won";n.winner=won;n.phase="over";n.turn=won;last.won=won;last.reason=reason
 else
  n.turn=kept and seat or other(seat)
  n.phase=n.solids and "play" or "open"
  if foul then n.inHand=(isBreak and scratch) and "kitchen" or "table" end
 end
 n.last=last
 return n
end
-- Ball in hand: x,y in 1/UNIT metres (the wire's integers).
function P.place(s,seat,p)
 p=p or {}
 local ok,why=ready(s,seat,p.nowMs);if not ok then return nil,why end
 if not s.inHand then return nil,"The cue ball is not in hand." end
 local x,y=p.x,p.y
 if not finite(x) or not finite(y) or x~=floor(x) or y~=floor(y) then return nil,"Invalid position." end
 x,y=x/UNIT,y/UNIT
 if abs(x)>P.X or abs(y)>P.Y then return nil,"Place the cue ball on the table." end
 if s.inHand=="kitchen" and x>P.HEAD_X then return nil,"Place the cue ball behind the head string." end
 local balls=P.decodePositions(s.pos)
 local D=2*P.R
 for i=2,16 do local b=balls[i];if b and (b[1]-x)^2+(b[2]-y)^2<D*D then return nil,"Another ball is in the way." end end
 local n=copy(s)
 balls[1]={x,y};n.pos=P.encodePositions(balls);n.inHand=nil
 return n
end
-- A new rack: practice at any time between shots, a duel once it is won.
function P.rerack(s,seat,p)
 p=p or {}
 if type(s)~="table" or s.kind~="pool" then return nil,"Invalid pool table." end
 if not finite(p.nowMs) then return nil,"The server must provide the time." end
 if P.busy(s,p.nowMs) then return nil,"Wait for the balls to stop." end
 if s.mode~="solo" and s.status~="won" then return nil,"Finish the game first (or the owner starts a new one)." end
 local n=P.new(s.mode,p.seed)
 n.ply=(s.ply or 0)+1;n.rack=(s.rack or 1)+1
 if s.mode~="solo" then n.breaker=other(s.breaker or "white");n.turn=n.breaker end
 return n
end
function P.view(s) return s end
