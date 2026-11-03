-- Pool presentation: 16 balls, the cue and the rack as native props. Nothing
-- here decides anything: the server simulates each shot into motion segments
-- (shared/casino_pool.lua) and every client evaluates them analytically at the
-- projected server time, so all players see the same balls at the same time.
--
-- Game view: the seated player whose shot it is aims with the cursor (the
-- cue turns about the cue ball towards the cursor's point on the cloth, a
-- guide line shows the path and the first ball it meets), holds the left
-- button to charge (the cue draws back; the power swings 0..1..0 every 1.6 s,
-- shown on the bar) and releases to shoot; a release on the bar cancels.
-- Ball in hand: the cue ball follows the cursor on the cloth, a click places
-- it. Re-rack, mode and New game are bar buttons (client/core/table_bar.lua).
-- Coordinates: P works in table metres (real size, origin at the centre of
-- the cloth); props are board-local unscaled metres, i.e. table metres / 0.65.
local Extra=LightRpTabletopExtraClient
local P=LightRpPool
local PC={}
LightRpPoolClient=PC
local DEPOT="open77\\assets\\op77_lightrp\\casino_pool\\"
local SCALE=Extra.SCALE
local K=1/SCALE
local UNIT=P.UNIT
local BALL_Z=(P.BED+P.R)*K
local CUE_GAP=.012         -- tip to ball at rest (m)
local PULL=.20             -- full charge draws the cue back this far (m)
local CHARGE_MS=1600       -- 0 -> full power; then back down (ping-pong)
local STRIKE_MS=110        -- the cue's thrust before the cue ball leaves
local PARK={x=0,y=0,z=P.PARK.z*K}                 -- inside the base's spine, out of sight
local PARK_CUE={x=P.PARK.cueX*K,y=0,z=P.PARK.z*K}  -- the whole cue fits in the spine from here
local function asset(name) return DEPOT..name..".ent" end
local BALLS={}
for i=1,16 do BALLS[i]=asset("pool_ball_"..(i-1)) end
local CUE,RACK=asset("pool_cue"),asset("pool_rack")
local floor,sqrt,abs=math.floor,math.sqrt,math.abs
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- Local interaction state (one seated table at a time).
local aim={}               -- boardId -> {x,y} aim point on the cloth (table metres)
local charge               -- {id,start}
local strike               -- {id,yaw,power,at(local ms),revision}
local sent                 -- {id,revision,at}: a request in flight
local function chargePower(now)
    if not charge then return 0 end
    local t=((now or GetGameTimer())-charge.start)/CHARGE_MS
    t=t%2;if t>1 then t=2-t end
    return clamp(t,.02,1)
end
PC.chargePower=chargePower

-- Snapshot decoding, cached by the strings themselves.
local decoded={}            -- boardId -> {pos=string,balls=...,shotKey,drops,cursor,...}
local function cacheFor(board)
    local g=board.game
    local c=decoded[board.id]
    if not c then c={};decoded[board.id]=c end
    if c.pos~=g.pos then c.pos=g.pos;c.balls=P.decodePositions(g.pos) end
    c.lx=c.lx or {};c.ly=c.ly or {}
    local shot=type(g.shot)=="table" and g.shot or nil
    local key=shot and (tostring(shot.n)..":"..tostring(shot.at)) or nil
    if c.shotKey~=key then
        c.shotKey=key;c.rec={};c.drop={};c.tau=nil
        if shot then for _,d in ipairs(P.decodeDrops(shot.drops)) do c.drop[d.ball]=d end end
    end
    return c,shot
end
-- Record index of a ball's string at shot time tau: the last one started.
local function seek(s,n,tau)
    if n==1 or P.dec3(s,P.REC+1)/UNIT>tau then return 1 end -- before its second record (a shot's start)
    local lo,hi=2,n
    while lo<hi do
        local mid=floor((lo+hi+1)/2)
        if P.dec3(s,(mid-1)*P.REC+1)/UNIT<=tau then lo=mid else hi=mid-1 end
    end
    return lo
end
local function load(c,s,i,r,n)
    local rec={r=r,P.record(s,r)}
    rec.next=r<n and P.dec3(s,r*P.REC+1)/UNIT or math.huge
    c.rec[i]=rec
    return rec
end
-- Ball i at shot time tau (s): x,y (table metres) or nil (not on the cloth),
-- plus the drop progress 0..1 into pocket `pocket`. Each ball keeps its
-- current record: a frame usually decodes nothing; a jump (late join) costs a
-- binary search, never a walk through every record.
-- Fresh decodes per frame: a break's first frame would otherwise decode every
-- ball at once. A ball still waiting keeps last frame's spot (the shot starts
-- P.LEAD ms after the snapshot: everything is decoded before anything moves).
local LOADS=3
local loads=0
local function ballAt(c,shot,i,tau)
    local s=shot.segs and shot.segs[i]
    if type(s)~="string" or #s<P.REC then return nil end
    local n=floor(#s/P.REC)
    local rec=c.rec[i]
    local stale=not rec or (tau<rec[1] and rec.r>1) or tau>=rec.next
    if stale and loads<=0 and c.lx[i] then return c.lx[i],c.ly[i] end
    if not rec or (tau<rec[1] and rec.r>1) then loads=loads-1;rec=load(c,s,i,seek(s,n,tau),n)
    elseif tau>=rec.next then
        loads=loads-1;rec=load(c,s,i,rec.r+1,n)
        if tau>=rec.next then rec=load(c,s,i,seek(s,n,tau),n) end
    end
    local drop=c.drop[i]
    if drop and tau>=drop.t then
        local dx,dy=P.motion(rec[2],rec[3],rec[4],rec[5],drop.t-rec[1])
        return dx,dy,clamp((tau-drop.t)*1000/P.DROP,0,1),drop.pocket
    end
    local x,y=P.motion(rec[2],rec[3],rec[4],rec[5],tau-rec[1])
    return x,y
end
local function traySlot(g,i)
    local at=type(g.potted)=="string" and g.potted:find(P.ballChar(i),1,true)
    if not at then return nil end
    local T=P.TRAY
    return T.x*K,(T.y0+(at-1)*T.step)*K,(T.z+P.R)*K
end

-- Who may do what, from the local snapshot.
local function seated(board) return Extra.seat(board)~=nil end
local function myShot(board)
    local g=board.game
    return seated(board) and g.status=="playing" and board.ready~=false and tonumber(board.actor)==me()
end
function PC.busy(board) return P.busy(board.game,Extra.serverTime(board)) end
local function waiting(board) return sent and sent.id==board.id and sent.revision==board.revision and GetGameTimer()-sent.at<3000 end
function PC.canShoot(board)
    return myShot(board) and not board.game.inHand and not PC.busy(board) and not waiting(board)
end
function PC.placing(board)
    return myShot(board) and board.game.inHand~=nil and not PC.busy(board) and not waiting(board)
end
-- The cue ball's spot while in hand: the aim point, clamped to the legal
-- area; nil while it overlaps another ball.
local function ghost(board,c)
    local a=aim[board.id];if not a then return nil end
    local g=board.game
    local x,y=clamp(a.x,-P.X,P.X),clamp(a.y,-P.Y,P.Y)
    if g.inHand=="kitchen" and x>P.HEAD_X then x=P.HEAD_X end
    local D=2*P.R
    for i=2,16 do local b=c.balls[i];if b and (b[1]-x)^2+(b[2]-y)^2<D*D then return nil end end
    return x,y
end
local function cueBallRest(board,c)
    local b=c.balls[1];if b then return b[1],b[2] end
end
-- Aim yaw (deg, table frame) from the cue ball to the aim point.
local function aimYaw(board,c)
    local cx,cy=cueBallRest(board,c);local a=aim[board.id]
    if not cx or not a then return nil end
    local dx,dy=a.x-cx,a.y-cy
    if dx*dx+dy*dy<1e-6 then return nil end
    return math.deg(math.atan(dy,dx))
end
PC.aimYaw=function(board) return aimYaw(board,cacheFor(board)) end

-- Targets are memoized per table: a prop whose pose did not change hands back
-- the very same table, which costs no allocation here and no comparison in
-- the renderer (client/core/board_games.lua refreshGoals skips it by identity).
local memo={}
local function put(result,key,model,x,y,z,yaw)
    yaw=yaw or 0
    local t=memo[key]
    if t then
        local p=t.position
        if p.x==x and p.y==y and p.z==z and t.piece.yaw==yaw and t.piece.model==model then result[key]=t;return end
    end
    t={piece={id=key,kind="pool",side="neutral",model=model,yaw=yaw,snap=true},position={x=x,y=y,z=z}}
    memo[key]=t;result[key]=t
end
-- The cue: its tip at (x,y) table metres pointing along yaw (the mesh's tip is
-- its origin, the butt towards -X and up).
local function cueAt(result,x,y,yaw,back)
    local a=math.rad(yaw);local d=P.R+CUE_GAP+(back or 0)
    put(result,"cue",CUE,(x-math.cos(a)*d)*K,(y-math.sin(a)*d)*K,BALL_Z,yaw)
end
local function pieceTargets(board,result)
    local g=board.game
    if type(g)~="table" or type(g.pos)~="string" then Extra.stillUntil(board,math.huge);return end
    local c,shot=cacheFor(board)
    c.memo=c.memo or {};memo=c.memo
    local now=Extra.serverTime(board)
    local endsAt=P.endsAt(g)
    local flying=shot and now<endsAt
    local live=false
    -- Balls.
    loads=LOADS
    local tau=flying and (now-(tonumber(shot.at) or 0))/1000 or nil
    -- A new snapshot re-anchors the server clock, a little backwards at times:
    -- a shot's time never runs back (the balls pause for a frame instead).
    if tau then
        if c.tau and tau<c.tau and c.tau-tau<.3 then tau=c.tau end
        c.tau=tau
    end
    for i=1,16 do
        local key="ball"..(i-1)
        local x,y,drop,pocket
        if flying then
            x,y,drop,pocket=ballAt(c,shot,i,tau)
            if not x then local b=c.balls[i];if b then x,y=b[1],b[2] end end
        else
            local b=c.balls[i];if b then x,y=b[1],b[2] end
        end
        if x and not drop then c.lx[i],c.ly[i]=x,y end
        if drop and drop<1 then
            local pc=P.POCKETS[pocket]
            local e=drop*drop
            put(result,key,BALLS[i],(x+(pc[1]-x)*e)*K,(y+(pc[2]-y)*e)*K,BALL_Z-2.4*P.R*K*e,0)
        elseif x and not drop then
            if i==1 and not flying and PC.placing(board) then
                local gx,gy=ghost(board,c);if gx then x,y=gx,gy end
                live=true
            end
            put(result,key,BALLS[i],x*K,y*K,BALL_Z,0)
        else
            local tx,ty,tz=traySlot(g,i)
            if i==1 and not flying and PC.placing(board) then
                local gx,gy=ghost(board,c)
                live=true
                if gx then put(result,key,BALLS[1],gx*K,gy*K,BALL_Z,0) else put(result,key,BALLS[1],PARK.x,PARK.y,PARK.z,0) end
            elseif tx then put(result,key,BALLS[i],tx,ty,tz,0)
            else put(result,key,BALLS[i],PARK.x,PARK.y,PARK.z,0) end
        end
    end
    -- The cue.
    local local_=GetGameTimer()
    local cx,cy=cueBallRest(board,c)
    if flying and shot.segs and type(shot.segs[1])=="string" and #shot.segs[1]>=P.REC then
        local _,sx,sy=P.record(shot.segs[1],1)
        local t=now-(tonumber(shot.at) or 0)
        local yaw=tonumber(shot.yaw) or 0
        local back=PULL*(tonumber(shot.power) or 0)
        if t<0 then cueAt(result,sx,sy,yaw,back*clamp(-t/STRIKE_MS,0,1)-CUE_GAP)
        elseif t<700 then cueAt(result,sx,sy,yaw,-CUE_GAP-.03*clamp(t/120,0,1))
        else put(result,"cue",CUE,PARK_CUE.x,PARK_CUE.y,PARK_CUE.z,0) end
    elseif strike and strike.id==board.id and strike.revision==board.revision and local_-strike.at<3000 then
        -- Sent: the thrust plays at once; the shot state takes over on arrival.
        local yaw=strike.yaw
        local p=clamp((local_-strike.at)/STRIKE_MS,0,1)
        if cx then cueAt(result,cx,cy,yaw,PULL*strike.power*(1-p)-CUE_GAP*p) end
        live=true
    elseif cx and PC.canShoot(board) then
        local yaw=aimYaw(board,c) or tonumber(g.shot and g.shot.yaw) or 0
        cueAt(result,cx,cy,yaw,charge and charge.id==board.id and PULL*chargePower(local_) or 0)
        live=true
    elseif cx and g.status=="playing" and not g.inHand then
        -- Waiting for the shooter: the cue rests behind the cue ball.
        cueAt(result,cx,cy,tonumber(g.shot and g.shot.yaw) or 0,.06)
    else
        put(result,"cue",CUE,PARK_CUE.x,PARK_CUE.y,PARK_CUE.z,0)
    end
    -- The rack frames the balls until the break.
    if g.phase=="break" and not flying then put(result,"rack",RACK,P.FOOT_X*K,0,P.BED*K,0) end
    if flying then Extra.animatingUntil(board,endsAt) end
    if live then Extra.animatingUntil(board,now+1000) end
    if not flying and not live then Extra.stillUntil(board,math.huge) end
end

-- The cursor on the cloth: the aim point (every frame, active table only),
-- and the guide: the cue ball's path to the first ball or cushion it meets,
-- the ghost ball there and where that object ball would go.
local GUIDE,OBJECT,HAND="#38f2ffd0","#ff3cc8c0","#38f2ff90"
local function toTable(board,p)
    local a=math.rad(board.rotation or 0);local dx,dy=p.x-board.position.x,p.y-board.position.y
    return dx*math.cos(a)+dy*math.sin(a),-dx*math.sin(a)+dy*math.cos(a)
end
local function worldAt(board,x,y) return Extra.world(board,x*K,y*K,BALL_Z) end
local function circle(board,line,x,y,r,color)
    local px,py=x+r,y
    for k=1,10 do
        local a=k*math.pi/5;local qx,qy=x+r*math.cos(a),y+r*math.sin(a)
        line(worldAt(board,px,py),worldAt(board,qx,qy),color);px,py=qx,qy
    end
end
local function aimAt(board,x,y,line)
    local ray=x and y and Open77.camera.screenRay(x,y,15)
    local planeZ=board.position.z+(P.BED+P.R)
    if ray and abs(ray.direction.z)>.001 then
        local t=(planeZ-ray.origin.z)/ray.direction.z
        if t>0 and t<15 then
            local tx,ty=toTable(board,{x=ray.origin.x+ray.direction.x*t,y=ray.origin.y+ray.direction.y*t})
            aim[board.id]={x=tx,y=ty}
        end
    end
    if not line then return end
    local c=cacheFor(board)
    if PC.placing(board) then
        local gx,gy=ghost(board,c)
        if gx then circle(board,line,gx,gy,P.R*1.15,HAND) end
        return
    end
    if not PC.canShoot(board) then return end
    local cx,cy=cueBallRest(board,c);local yaw=aimYaw(board,c)
    if not cx or not yaw then return end
    local ux,uy=math.cos(math.rad(yaw)),math.sin(math.rad(yaw))
    -- Cushion: where the centre line meets the rail lines.
    local best=8
    if ux>0 then best=math.min(best,(P.X-cx)/ux) elseif ux<0 then best=math.min(best,(-P.X-cx)/ux) end
    if uy>0 then best=math.min(best,(P.Y-cy)/uy) elseif uy<0 then best=math.min(best,(-P.Y-cy)/uy) end
    local hit
    local D=2*P.R
    for i=2,16 do
        local b=c.balls[i]
        if b then
            local ox,oy=b[1]-cx,b[2]-cy
            local along=ox*ux+oy*uy
            if along>0 then
                local side=ox*ox+oy*oy-along*along
                if side<D*D then
                    local t=along-sqrt(D*D-side)
                    if t<best then best,hit=t,i end
                end
            end
        end
    end
    if best<0 then best=0 end
    local gx,gy=cx+ux*best,cy+uy*best
    line(worldAt(board,cx,cy),worldAt(board,gx,gy),GUIDE)
    circle(board,line,gx,gy,P.R,GUIDE)
    if hit then
        local b=c.balls[hit];local nx,ny=b[1]-gx,b[2]-gy;local l=sqrt(nx*nx+ny*ny)
        if l>1e-6 then line(worldAt(board,b[1],b[2]),worldAt(board,b[1]+nx/l*.25,b[2]+ny/l*.25),OBJECT) end
    end
end

local notified=-100000
local function hint(text)
    if GetGameTimer()-notified<4000 then return end
    notified=GetGameTimer()
    LightRpBoardGamesClient.notice(text,"Pool")
end
function PC.charging(board) return charge~=nil and charge.id==board.id end
local function pointer(board,event)
    if event.cancelled then charge=nil;return true end
    if event.x and event.y then aimAt(board,event.x,event.y) end -- the click's own point on the cloth
    if event.pressed then
        if PC.placing(board) then
            local c=cacheFor(board);local gx,gy=ghost(board,c)
            if not gx then hint("Another ball is in the way: aim at a free spot to place the cue ball.");return true end
            if Extra.command(board,"place",{x=floor(gx*UNIT+.5),y=floor(gy*UNIT+.5)}) then sent={id=board.id,revision=board.revision,at=GetGameTimer()} end
            return true
        end
        if PC.canShoot(board) then charge={id=board.id,start=GetGameTimer()}
        elseif board.game.status~="playing" then hint("Game over: Rematch or New game from the bar.")
        elseif PC.busy(board) then hint("Wait for the balls to stop.")
        elseif seated(board) and not myShot(board) then hint(board.ready==false and "Waiting for an opponent to sit." or "It is your opponent's shot.") end
        return true
    end
    if event.released and charge and charge.id==board.id then
        local power=chargePower();charge=nil
        local c=cacheFor(board);local yaw=aimYaw(board,c)
        if PC.canShoot(board) and yaw then
            power=floor(power*1000+.5)/1000
            if Extra.command(board,"shoot",{yaw=floor(yaw*100+.5)/100,power=power}) then
                strike={id=board.id,yaw=yaw,power=power,at=GetGameTimer(),revision=board.revision}
                sent={id=board.id,revision=board.revision,at=GetGameTimer()}
            end
        end
    end
    return true
end

-- Status and result text (the bar status and the notices).
local FOULS={scratch="Scratch",no_contact="No ball hit",wrong_first="Wrong ball first",no_rail="No rail after contact"}
local function names(chars)
    local out={}
    for k=1,#(chars or "") do local i=P.ballIndex(chars:sub(k,k));if i then out[#out+1]=tostring(i-1) end end
    return table.concat(out,", ")
end
PC.names=names
function PC.group(board,seat) local g=P.groupOf(board.game,seat);return g end
function PC.status(board)
    local g=board.game;local seat=Extra.seat(board)
    if PC.busy(board) then return "Balls rolling" end
    if g.mode=="solo" then return g.inHand and "Practice · ball in hand" or "Practice" end
    if g.status=="won" then return g.winner==seat and "You win" or "Opponent wins" end
    if board.ready==false then return "Waiting for an opponent" end
    local group=P.groupOf(g,seat)
    local mine=g.turn==seat
    local text=mine and (g.inHand and "Your shot · ball in hand" or "Your shot") or "Opponent's shot"
    if group then text=text.." · "..group elseif g.phase=="break" then text=text.." · break" else text=text.." · open table" end
    return text
end
function PC.describe(board)
    local g=board.game;local seat=Extra.seat(board)
    local balls=P.decodePositions(g.pos)
    if g.mode=="solo" then
        local left=0;for i=2,16 do if balls[i] then left=left+1 end end
        return ("Practice: %d balls on the table. Aim with the cursor, hold the left button to charge, release to shoot."):format(left)
    end
    local group=P.groupOf(g,seat)
    local text=PC.status(board)..". "
    if group then
        local mine=P.left(balls,group);local theirs=P.left(balls,group=="solids" and "stripes" or "solids")
        text=text..(mine==0 and "You are on the 8. " or ("You have %d %s left, your opponent %d. "):format(mine,group,theirs))
    else text=text.."The table is open: the first clean pot claims a group. " end
    return text.."Aim with the cursor, hold the left button to charge, release to shoot."
end
function PC.result(board)
    local g=board.game;local last=type(g.last)=="table" and g.last or nil
    if not last then return nil end
    local seat=Extra.seat(board)
    local you=last.by==seat
    local potted=names(last.potted)
    if g.mode=="solo" then
        local parts={potted~="" and ("Potted "..potted..".") or "No ball potted."}
        if last.scratch then parts[#parts+1]="Scratch: click the cloth to place the cue ball." end
        if last.cleared then parts[#parts+1]="Table cleared! Re-rack from the bar." end
        return table.concat(parts," ")
    end
    local parts={}
    if potted~="" then parts[#parts+1]=(you and "You potted " or "Opponent potted ")..potted.."." end
    if last.respot then parts[#parts+1]="The 8 is back on the foot spot." end
    if last.won then
        local REASONS={eight="the 8 is down",eight_early="the 8 went down too early",eight_foul="foul on the 8"}
        parts[#parts+1]=(last.won==seat and "You win" or "Opponent wins").." ("..(REASONS[last.reason] or "game over").."). Rematch from the bar."
        return table.concat(parts," ")
    end
    if last.foul then
        parts[#parts+1]=("Foul%s: %s."):format(you and " by you" or " by your opponent",FOULS[last.foul] or last.foul)
        parts[#parts+1]=g.turn==seat and "Ball in hand: click the cloth to place the cue ball." or "Your opponent has ball in hand."
    end
    if last.assigned then
        local group=P.groupOf(g,seat)
        if group then parts[#parts+1]="You are "..group.."." end
    end
    if not last.foul then
        if g.turn==seat then parts[#parts+1]=you and "Shoot again." or "Your shot." else parts[#parts+1]="Opponent's shot." end
    end
    return table.concat(parts," ")
end

-- Clickable now: the cue ball when it is your shot (aim anywhere, the cue
-- turns about it), the legal area while the cue ball is in hand (behind the
-- head string after a scratch on the break).
local function markKey(board)
    if PC.canShoot(board) then return "shoot" end
    if PC.placing(board) then return "hand:"..tostring(board.game.inHand) end
end
local function marks(board,line)
    local c=cacheFor(board)
    if PC.canShoot(board) then
        local cx,cy=cueBallRest(board,c)
        if cx then circle(board,line,cx,cy,P.R*1.8) end
        return
    end
    local x1=board.game.inHand=="kitchen" and P.HEAD_X or P.X
    local z=P.BED*K+.004
    local function at(x,y) return Extra.world(board,x*K,y*K,z) end
    local a,b,d,e=at(-P.X,-P.Y),at(x1,-P.Y),at(x1,P.Y),at(-P.X,P.Y)
    line(a,b);line(b,d);line(d,e);line(e,a)
end
Extra.register("pool",{
    operations={shoot=true,place=true,rerack=true},
    turnOnly=true,
    boardModel=function() return asset("pool_table") end,
    pieceTargets=pieceTargets,
    pointer=pointer,
    aim=aimAt,
    markKey=markKey,
    marks=marks,
    -- Board-local unscaled metres: the cloth is at P.BED/0.65, the table
    -- runs along X (head at -X, the rack at +X), the bar never covers it.
    views={{key="top",label="Overhead"},{key="head",label="Head end"},{key="side",label="Side rail"},{key="orbit",label="Orbit"}},
    orbit={x=0,y=0,z=P.BED*K,radius=3.2,height=2.0},
    camera=function(board,view)
        local w,z=Extra.world,P.BED*K
        if view=="head" then return {position=w(board,-3.3,0,z+1.45),lookAt=w(board,.25,0,z),fov=50} end
        if view=="side" then return {position=w(board,0,-2.75,z+1.9),lookAt=w(board,0,-.1,z),fov=52} end
        return {position=w(board,0,-.015,z+3.6),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
    end,
})
