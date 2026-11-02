-- Slot machine presentation (LightRpTabletopExtraClient adapter). The server picks
-- the stops and timestamps the pull; every client plays the same timeline from
-- the server clock. Props turn about Z only, so:
--   * reels are vertical symbol strips sliding behind the bezel window
--     (strip entries: last symbol, the 12 stops, then the first two again, so
--     the strip wraps by exactly 12 pitches without a visible jump);
--   * the lever is six authored pose meshes; the active one stands at the
--     origin and the others are parked inside the cabinet;
--   * the top lamp is a lit/unlit pair swapped the same way.
-- Geometry constants match tools/build-casino-slots-props.py (asset-manifest
-- "layout"; the client test asserts they agree).
local Extra=LightRpTabletopExtraClient
local S=LightRpCasinoSlots
local DEPOT="open77\\assets\\op77_lightrp\\casino_slots\\"
local L={
 paylineZ=1.33,pitch=.085,stripY=-.33,reelX={-.22,0,.22},reelWidth=.20,
 leverAngles={0,17,34,51,68,85},leverPivot={.55,0,1.35},leverLength=.45,
 leverPark={-.14,.16,0},lampPark={0,.15,-.32},
 chuteY=-.37,chuteZ=.73,trayY=-.44,trayZ=.574,coinPark={0,.2,.4},
}
LightRpCasinoSlotsLayout=L
local N=S.STOPS
local T=S.TIMING
local floor=math.floor
local MODELS={cabinet=DEPOT.."slot_cabinet.ent",strip={},lever={},lampOn=DEPOT.."slot_lamp_on.ent",lampOff=DEPOT.."slot_lamp_off.ent",coin=DEPOT.."slot_coin.ent"}
for r=1,3 do MODELS.strip[r]=DEPOT.."slot_strip_"..r..".ent" end
for i=1,#L.leverAngles do MODELS.lever[i]=DEPOT.."slot_lever_"..(i-1)..".ent" end
local SNAP={snap=true}
local COIN_X={-.06,.03,-.01,.07}
local COIN_YAW={0,47,113,160}
-- Strip index on the payline for a continuous position, wrapped into [1,N+1).
local function wrap(j) return j-floor((j-1)/N)*N end
-- Lever angle (degrees) t ms after the pull: down 0-220 ms, hold, spring back by 600 ms.
local function leverAngle(t)
 local max=L.leverAngles[#L.leverAngles]
 if t<0 or t>=T.lever then return 0 end
 if t<220 then local u=t/220;return max*u*u end
 if t<300 then return max end
 local u=(t-300)/(T.lever-300);return max*(1-u)*(1-u)
end
-- Payline position of reel r at time t ms after the pull (continuous strip index).
local function reelIndex(spin,r,t)
 local from=(tonumber(spin.from and spin.from[r]) or 0)+1
 local to=(tonumber(spin.stops[r]) or 0)+1
 local stop=T.stops[r]
 if t<=T.reelStart then return from end
 if t>=stop then return to end
 local over=.25
 local main=stop-T.settle-T.reelStart
 local travel=(from-to)%N+N*r+over -- symbols moved downward, overshoot included
 local s=t-T.reelStart
 if s>=main then -- settle back from the overshoot
  local u=(s-main)/T.settle;u=u*u*(3-2*u)
  return wrap(to-over*(1-u))
 end
 -- Velocity ramps up over 10 %, holds, ramps down over the last 40 %.
 local u,a,b=s/main,.1,.4
 local d
 if u<a then d=u*u/(2*a)
 elseif u<1-b then d=a/2+(u-a)
 else local v=1-u;d=1-a/2-b/2-v*v/(2*b) end
 return wrap(from-travel*d/(1-a/2-b/2))
end
L.reelIndex=reelIndex;L.leverAngle=leverAngle
local function coinCount(spin)
 local bet=tonumber(spin.bet) or 0;local gross=tonumber(spin.gross) or 0
 if gross<=0 or bet<=0 then return 0 end
 local m=gross/bet
 return m>=50 and 4 or m>=10 and 3 or m>=2 and 2 or 1
end
local selectedBet=10
local function pullLever(board)
 return Extra.command(board,"pull",{bet=selectedBet})
end
-- Closest distance between the pointer ray and the lever arm (board-local metres).
local function onLever(board,event)
 local ray=Open77.camera.screenRay(event.x,event.y,15)
 if type(ray)~="table" or type(ray.origin)~="table" or type(ray.direction)~="table" then return false end
 local p=L.leverPivot
 local a=Extra.world(board,p[1],p[2],p[3])
 local b=Extra.world(board,p[1],p[2],p[3]+L.leverLength)
 local o,d=ray.origin,ray.direction
 local ux,uy,uz=b.x-a.x,b.y-a.y,b.z-a.z
 local wx,wy,wz=o.x-a.x,o.y-a.y,o.z-a.z
 local A=d.x*d.x+d.y*d.y+d.z*d.z;local B=d.x*ux+d.y*uy+d.z*uz;local C=ux*ux+uy*uy+uz*uz
 local D=d.x*wx+d.y*wy+d.z*wz;local E=ux*wx+uy*wy+uz*wz
 local den=A*C-B*B
 local tc=den>1e-12 and (A*E-B*D)/den or E/C
 local sc
 tc=math.max(0,math.min(1,tc));sc=math.max(0,(B*tc-D)/A)
 local dx,dy,dz=wx+sc*d.x-tc*ux,wy+sc*d.y-tc*uy,wz+sc*d.z-tc*uz
 return math.sqrt(dx*dx+dy*dy+dz*dz)<=.09*Extra.SCALE
end
Extra.register("slots",{
 operations={pull=true},
 turnOnly=true,
 boardModel=function() return MODELS.cabinet end,
 pieceTargets=function(board,result)
  local game=board.game
  local spin=type(game.spin)=="table" and type(game.spin.stops)=="table" and game.spin or nil
  local stops=game.stops or {0,0,0}
  local t=spin and Extra.serverTime(board)-(tonumber(spin.at) or 0) or math.huge
  local put=Extra.put
  for r=1,3 do
   local j=spin and reelIndex(spin,r,t) or (tonumber(stops[r]) or 0)+1
   put(result,"slot-reel-"..r,"slot_reel",MODELS.strip[r],L.reelX[r],L.stripY,L.paylineZ+j*L.pitch,0,SNAP)
  end
  local angle=spin and leverAngle(t) or 0
  local active=floor(angle/L.leverAngles[2]+.5)+1
  local park=L.leverPark
  for i=1,#MODELS.lever do
   if i==active then put(result,"slot-lever-"..i,"slot_lever",MODELS.lever[i],0,0,0,0,SNAP)
   else put(result,"slot-lever-"..i,"slot_lever",MODELS.lever[i],park[1],park[2],park[3],0,SNAP) end
  end
  local after=spin and t-S.DURATION or -1
  local coins=after>=0 and coinCount(spin) or 0
  local lit=coins>0 and (after>=2400 or floor(after/200)%2==0)
  local lp=L.lampPark
  if lit then
   put(result,"slot-lamp-on","slot_lamp",MODELS.lampOn,0,0,0,0,SNAP)
   put(result,"slot-lamp-off","slot_lamp",MODELS.lampOff,lp[1],lp[2],lp[3],0,SNAP)
  else
   put(result,"slot-lamp-on","slot_lamp",MODELS.lampOn,lp[1],lp[2],lp[3],0,SNAP)
   put(result,"slot-lamp-off","slot_lamp",MODELS.lampOff,0,0,0,0,SNAP)
  end
  -- Winnings: up to four coins drop from the chute into the tray, one every 140 ms.
  local cp=L.coinPark
  for i=1,4 do
   local x,y,z=COIN_X[i],cp[2],cp[3]
   local u=i<=coins and (after-150-(i-1)*140)/380 or -1
   if u>=0 then
    x=COIN_X[i]*(u<1 and u or 1)
    if u<1 then y=L.chuteY+(L.trayY-L.chuteY)*u;z=L.chuteZ+(L.trayZ-L.chuteZ)*u*u
    elseif u<1.4 then y=L.trayY;z=L.trayZ+.03*math.sin((u-1)/.4*math.pi)
    else y=L.trayY;z=L.trayZ end
   end
   put(result,"slot-coin-"..i,"slot_coin",MODELS.coin,x,y,z,COIN_YAW[i],SNAP)
  end
 end,
 -- Toolbar labels are the shared ones: "Overhead" = raised front view of the
 -- whole machine, "White side" = the player's seat at the reels, "Black side" =
 -- three-quarter view of the lever. Orbit keeps the shared orbit camera.
 camera=function(board,view)
  local w=Extra.world
  if view=="top" then return {position=w(board,.15,-2.9,2.2),lookAt=w(board,.06,0,1.4),fov=52} end
  if view=="white" then return {position=w(board,0,-1.25,1.36),lookAt=w(board,0,0,1.3),fov=52} end
  if view=="black" then return {position=w(board,1.7,-1.55,1.7),lookAt=w(board,.2,0,1.25),fov=52} end
 end,
 view=function(board)
  local game=board.game
  local extra={}
  for k,v in pairs(game) do extra[k]=v end
  extra.seat=Extra.seat(board)
  local spin=type(game.spin)=="table" and game.spin or nil
  local stopped=not spin or Extra.serverTime(board)>=(tonumber(spin.endsAt) or 0)
  extra.spinning=not stopped
  extra.spin=nil
  if not stopped then extra.stops=nil;extra.last=nil end -- never spoil the outcome in the panel
  if spin and stopped then
   local multiplier,label,symbols=S.evaluate(spin.stops)
   extra.result={bet=spin.bet,gross=spin.gross,multiplier=multiplier,label=label,symbols=symbols,round=spin.round}
  end
  extra.paytable={three=S.THREE,twoCherries=S.TWO_CHERRIES,mixedFruit=S.MIXED_FRUIT,oneCherry=S.ONE_CHERRY,minBet=S.MIN_BET,maxBet=S.MAX_BET}
  return {extra=extra,text="Set your bet, then pull the lever (click it) or press Pull. Backspace: leave."}
 end,
 pointer=function(board,event)
  if event.pressed and not event.blocked and onLever(board,event) then pullLever(board) end
  return true -- the panel or the lever; a stray click never wagers
 end,
})
-- The page reports the chosen bet so a click on the lever can pull with it.
local bind=Extra.bind
function Extra.bind(page)
 bind(page)
 page:on("lightrp:slots:bet",function(payload)
  local amount=type(payload)=="table" and tonumber(payload.amount)
  if amount and amount==floor(amount) and amount>=S.MIN_BET and amount<=S.MAX_BET then selectedBet=amount end
 end)
end
