-- Presentation adapters only. Bets, shuffles, placements and outcomes remain on
-- the server. These adapters use raw authored native prop templates, never draws.
-- Casino tables plug in with Extra.register(kind,{
--   boardModel=function(board) return depotPath end,     -- the placed base prop
--   pieceTargets=function(board,result) end,              -- Extra.put(...) each moving prop
--   views={{key=,label=},...},                            -- optional camera views, the first is the default
--   camera=function(board,view) return pose end,          -- optional; {position,lookAt|rotation,fov}
--   orbit={x=,y=,z=,radius=,height=},                     -- optional focus of an "orbit" view (local metres)
--   pointer=function(board,event) end,                    -- optional; the page cursor on the table
--   aim=function(board,x,y,line) end,                     -- optional; outline the hovered target and the selection
--   operations={name=true,...},                           -- requests Extra.command forwards to the server
--   turnOnly=true,                                        -- optional; only the actor may act
-- })
-- In the game view the page owns the cursor: event.x/y are the normalized
-- cursor (Open77.camera.screenRay(event.x,event.y) is the picking ray),
-- event.pressed/released the left button, event.cancelled a press that ended
-- on the bar. aim's x,y are nil while the cursor is off the table. A pointer
-- that picks a betting target calls Extra.select(board,key,label): the bar
-- (client/core/table_bar.lua) bets the chip on Extra.selection(board).
-- The renderer moves only props whose target changed, every frame, and calls
-- pieceTargets again only when a new snapshot arrives or the targets expire.
-- pieceTargets says how long its result holds, in server time:
--   Extra.animatingUntil(board,t) -- targets change every frame until t
--   Extra.stillUntil(board,t)     -- targets hold until t (math.huge: next snapshot)
-- Several calls combine (the earliest wins). An adapter that declares nothing
-- is recomputed every frame, the safe default for a time-driven table.
-- pieceTargets runs inside the 176 client's ~10k instruction budget per
-- resume: keep it to a few dozen props, no searches.
local Extra={}
LightRpTabletopExtraClient=Extra
local SCALE=.65
Extra.SCALE=SCALE
local NET="lightrp:boardGames:request"
local games={}
local boards,clocks={},{}
local activeId,selected
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
Extra.clamp=clamp
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
local function seat(board)
    local id=me()
    for name,player in pairs(board.players or {}) do if id and tonumber(player)==id then return name end end
end
Extra.seat=seat
-- Board-local unscaled metres to world space (the client applies SCALE).
function Extra.world(board,x,y,z)
    local a=math.rad(board.rotation or 0);local c,s=math.cos(a),math.sin(a)
    return {x=board.position.x+(x*c-y*s)*SCALE,y=board.position.y+(x*s+y*c)*SCALE,z=board.position.z+(z or 0)*SCALE}
end
local world=Extra.world
function Extra.register(kind,adapter) games[kind]=adapter end
function Extra.supports(kind) return games[kind]~=nil end
function Extra.observe(board)
    if not board or not Extra.supports(board.kind) then return end
    boards[board.id]=board
    local stamp=tonumber(board.serverNow)
    local clock=clocks[board.id]
    if stamp and (not clock or stamp~=clock.stamp) then clocks[board.id]={stamp=stamp,received=GetGameTimer()} end
end
-- The server clock projected forward from the last snapshot, so every client
-- animates a timed event (spin, pull, deal) to the same pose at the same time.
function Extra.serverTime(board)
    Extra.observe(board)
    local clock=clocks[board.id]
    if clock then return clock.stamp+math.max(0,GetGameTimer()-clock.received) end
    return GetGameTimer()
end
function Extra.asset(depot,name) return depot..name..".ent" end
function Extra.model(board,piece)
    if piece and type(piece.model)=="string" then return piece.model end
    return games[board.kind].boardModel(board)
end
-- One moving prop: `model` is a full depot path; x,y,z are board-local metres.
-- metadata.snap=true moves it straight to the target each frame (no smoothing):
-- use it for server-clock timelines and for pose variants swapped by parking
-- the inactive ones out of sight (the prop API turns props about Z only, so a
-- lever, a flipped card or a vertical wheel is a set of authored pose meshes).
function Extra.put(result,id,kind,model,x,y,z,yaw,metadata)
    local piece={id=id,kind=kind,side="neutral",model=model,yaw=yaw or 0}
    if metadata then for key,value in pairs(metadata) do piece[key]=value end end
    result[tostring(id)]={piece=piece,position={x=x or 0,y=y or 0,z=z or 0}}
end
-- Declared lifetime of the targets being computed (server ms), see the header.
local holdDeclared,holdUntil,holdNow=false,math.huge,0
function Extra.stillUntil(_,t)
    holdDeclared=true
    t=tonumber(t) or math.huge
    if t<holdUntil then holdUntil=t end
end
function Extra.animatingUntil(_,t)
    holdDeclared=true
    t=tonumber(t)
    if t and t>holdNow and holdNow<holdUntil then holdUntil=holdNow end
end
-- Returns the targets and the local GetGameTimer() time until which they hold
-- (nil: recompute next frame).
function Extra.pieceTargets(board)
    Extra.observe(board)
    local result={}
    holdDeclared,holdUntil,holdNow=false,math.huge,Extra.serverTime(board)
    games[board.kind].pieceTargets(board,result)
    if not holdDeclared or holdUntil<=holdNow then return result,nil end
    if holdUntil==math.huge then return result,math.huge end
    return result,GetGameTimer()+(holdUntil-holdNow)
end
-- The table of the game view (nil when standing); its selection is cleared
-- when the view closes or moves to another table.
function Extra.setActive(board)
    local id=board and board.id
    if id~=activeId then selected=nil end
    activeId=id
end
-- The betting target picked on the table: {key=,label=,data=} or nil.
function Extra.select(board,key,label,data)
    if not board or board.id~=activeId then return end
    if key==nil then selected=nil;return end
    if selected and selected.key==key then return end
    selected={key=key,label=label or tostring(key),data=data}
end
function Extra.selection(board)
    if board and board.id==activeId then return selected end
end
-- Outline what the cursor points at: adapter.aim calls line(a,b) with world
-- points. Cheap: it runs every frame for the active table.
function Extra.aim(board,x,y,line)
    local adapter=games[board.kind]
    if adapter and adapter.aim then adapter.aim(board,x,y,line) end
end
-- Camera views: the adapter's, else overhead / players' side / orbit.
local DEFAULT_VIEWS={{key="top",label="Overhead"},{key="side",label="Players' side"},{key="orbit",label="Orbit"}}
function Extra.views(board)
    local adapter=games[board.kind]
    return adapter.views or DEFAULT_VIEWS
end
function Extra.orbit(board)
    local adapter=games[board.kind]
    return adapter.orbit or {x=0,y=0,z=0,radius=1.8,height=1.2}
end
function Extra.camera(board,view)
    local adapter=games[board.kind]
    if adapter.camera then local pose=adapter.camera(board,view);if pose then return pose end end
    if view=="side" then return {position=world(board,0,-1.65,.85),lookAt=world(board,0,0,0),fov=52} end
    return {position=world(board,0,-.015,1.85),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
end
-- A screen point on a horizontal plane of the table (local height z), in
-- board-local unscaled metres: x,y or nil.
function Extra.onPlane(board,sx,sy,z)
    if sx==nil or sy==nil then return end
    local ray=Open77.camera.screenRay(sx,sy,15)
    if type(ray)~="table" or type(ray.origin)~="table" or type(ray.direction)~="table" or math.abs(ray.direction.z)<.001 then return end
    local t=(board.position.z+z*SCALE-ray.origin.z)/ray.direction.z
    if t<=0 then return end
    local a=math.rad(board.rotation or 0)
    local dx,dy=ray.origin.x+ray.direction.x*t-board.position.x,ray.origin.y+ray.direction.y*t-board.position.y
    return (dx*math.cos(a)+dy*math.sin(a))/SCALE,(-dx*math.sin(a)+dy*math.cos(a))/SCALE
end
-- Outline a local rectangle at height z.
function Extra.box(board,line,x0,y0,x1,y1,z,color)
    local a,b,c,d=world(board,x0,y0,z),world(board,x1,y0,z),world(board,x1,y1,z),world(board,x0,y1,z)
    line(a,b,color);line(b,c,color);line(c,d,color);line(d,a,color)
end
local function trace(reason,board,format,...)
    local client=LightRpBoardGamesClient
    if client and client.trace then client.trace(reason,board and board.id,format,...) end
end
local function command(board,operation,data)
    local adapter=board and games[board.kind]
    local why=not adapter and "unknown table" or not seat(board) and "not seated" or not (adapter.operations or {})[operation] and "unknown operation"
        or adapter.turnOnly and board.actor~=nil and tonumber(board.actor)~=me() and "not your turn" or nil
    if why then trace("action_refused",board,"kind=%s op=%s: %s",tostring(board and board.kind),tostring(operation),why);return false end
    if type(data)~="table" then data={} end
    trace("action",board,"kind=%s op=%s rev=%s phase=%s",board.kind,operation,tostring(board.revision),tostring(board.game and board.game.phase))
    return TriggerServerEvent(NET,{action="game",boardId=board.id,revision=board.revision,operation=operation,data=data})==true
end
Extra.command=command
function Extra.pointer(board,event)
    local adapter=games[board.kind]
    if adapter and adapter.pointer then adapter.pointer(board,event) end
    return true -- casino tables never fall through to the board-game moves
end

-- Roulette -------------------------------------------------------------------
-- Board-local unscaled metres; these match tools/build-tabletop-extra-props.py
-- (the wheel datum Z=0 is the board position, the table stands to the floor).
local ROULETTE="open77\\assets\\op77_lightrp\\tabletop_extra\\"
local POCKET_R,POCKET_Z=.27,.025       -- settled ball centre (unchanged)
-- The ball's path (radius, centre height) from the ball track over the
-- deflector apron and the number ring down into a pocket.
local PATH_R={.388,.372,.330,.322,.296,.283,.27}
local PATH_Z={.074,.068,.050,.047,.047,.042,.025}
local DROP_T,LAND_T=.52,.76            -- spin fractions: leaves the track, lands in its pocket
-- The printed betting layout (tools/build-tabletop-extra-props.py LAYOUT,
-- CELL, ZERO_W, DOZEN_H, GRID_X0, GRID_Y1): 12 columns of 3 numbers from
-- GRID_X0 along +X, the zero before them, then the dozens and the six even
-- chances towards the players (-Y).
local LAYOUT={z=.0215,gx0=.68,top=.24,cell=.10,zeroW=.10,band=.09}
Extra.rouletteLayout=LAYOUT
local EVEN={{"low","1-18"},{"even","Even"},{"red","Red"},{"black","Black"},{"odd","Odd"},{"high","19-36"}}
local DOZENS={{"dozen1","1st 12"},{"dozen2","2nd 12"},{"dozen3","3rd 12"}}
local PAYS={}
-- The cell under a board-local point: bet key, label, rectangle.
local function rouletteCell(x,y)
    if x==nil then return end
    local L=LAYOUT
    local gx0,top,cell=L.gx0,L.top,L.cell
    local dz=top-3*cell;local ev=dz-L.band
    local right=gx0+12*cell
    if y<=top and y>dz then
        if x>=gx0 and x<right then
            local col=math.floor((x-gx0)/cell);local row=math.floor((top-y)/cell)
            local n=col*3+(3-row)
            local x0,y1=gx0+col*cell,top-row*cell
            return "number:"..n,tostring(n),x0,y1-cell,x0+cell,y1
        elseif x>=gx0-L.zeroW and x<gx0 then
            return "number:0","Zero",gx0-L.zeroW,dz,gx0,top
        end
    elseif y<=dz and y>ev and x>=gx0 and x<right then
        local i=math.floor((x-gx0)/(4*cell))
        return DOZENS[i+1][1],DOZENS[i+1][2],gx0+i*4*cell,ev,gx0+(i+1)*4*cell,dz
    elseif y<=ev and y>ev-L.band and x>=gx0 and x<right then
        local i=math.floor((x-gx0)/(2*cell))
        return EVEN[i+1][1],EVEN[i+1][2],gx0+i*2*cell,ev-L.band,gx0+(i+1)*2*cell,ev
    end
end
Extra.rouletteCell=rouletteCell
for _,bet in ipairs(EVEN) do PAYS[bet[1]]="1:1" end
for _,bet in ipairs(DOZENS) do PAYS[bet[1]]="2:1" end
function Extra.roulettePays(bet) return PAYS[bet] or "35:1" end
local function smooth(x) x=clamp(x,0,1);return x*x*(3-2*x) end
-- Ball centre at fraction s (0..1) of the drop path.
local function dropPoint(s)
    local f=smooth(s)*(#PATH_R-1);local i=math.min(#PATH_R-1,math.floor(f)+1);local k=f-(i-1)
    return PATH_R[i]+(PATH_R[i+1]-PATH_R[i])*k,PATH_Z[i]+(PATH_Z[i+1]-PATH_Z[i])*k
end
Extra.register("roulette",{
    operations={bet=true,spin=true,nextRound=true},
    boardModel=function() return Extra.asset(ROULETTE,"roulette_table") end,
    pieceTargets=function(board,result)
        local spin=board.game.spin
        local wheel,ball=tonumber(board.game.lastWheelAngle) or 0,tonumber(board.game.lastBallAngle) or 0
        local r,z,t=POCKET_R,POCKET_Z,1
        if type(spin)=="table" then
            local now=Extra.serverTime(board)
            local started=tonumber(spin.startedAt or spin.t0) or now
            t=clamp((now-started)/(tonumber(spin.duration) or 8000),0,1)
            local wheelFrom,wheelTo=tonumber(spin.wheelFrom) or 0,tonumber(spin.wheelTo) or 0
            local ballFrom,ballTo=tonumber(spin.ballFrom) or 0,tonumber(spin.ballTo) or 0
            local function wheelAt(u) return wheelFrom+(wheelTo-wheelFrom)*(1-(1-u)^2) end
            wheel=wheelAt(t)
            -- Once in its pocket the ball rides the rotor; before that it runs
            -- the other way round the track and slows to meet that pocket.
            local pocket=ballTo-wheelTo
            if t>=LAND_T then
                ball=wheel+pocket
                local s=(t-LAND_T)/(1-LAND_T)
                z=POCKET_Z+.005*math.abs(math.sin(s*math.pi*4))*math.max(0,1-s*3)
            else
                local u=t/LAND_T
                ball=ballFrom+(wheelAt(LAND_T)+pocket-ballFrom)*(1-(1-u)^3)
                if t<DROP_T then r,z=PATH_R[1],PATH_Z[1]
                else
                    local s=(t-DROP_T)/(LAND_T-DROP_T)
                    r,z=dropPoint(s)
                    z=z+.012*math.abs(math.sin(s*math.pi*3))*(1-s)
                end
            end
        end
        if type(spin)=="table" and t<1 then Extra.animatingUntil(board,(tonumber(spin.startedAt or spin.t0) or 0)+(tonumber(spin.duration) or 8000))
        else Extra.stillUntil(board,math.huge) end
        local a=math.rad(ball)
        Extra.put(result,"roulette-wheel","roulette_wheel",Extra.asset(ROULETTE,"roulette_wheel"),0,0,0,-wheel)
        Extra.put(result,"roulette-ball","roulette_ball",Extra.asset(ROULETTE,"roulette_ball"),r*math.sin(a),r*math.cos(a),z,0)
    end,
    -- The table runs along +X from the wheel; players stand on the -Y side.
    views={{key="top",label="Overhead"},{key="layout",label="Layout"},{key="wheel",label="Wheel"},{key="orbit",label="Orbit"}},
    orbit={x=.95,y=0,z=0,radius=2.1,height=1.3},
    camera=function(board,view)
        if view=="layout" then -- the betting layout, from the players' side
            return {position=world(board,1.15,-1.45,1.05),lookAt=world(board,1.15,-.05,0),fov=50}
        elseif view=="wheel" then -- close on the wheel to follow the ball
            return {position=world(board,-.10,-.80,.70),lookAt=world(board,0,.02,.03),fov=44}
        end
        return {position=world(board,.78,-.01,2.05),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
    end,
    -- A click on a layout cell selects that bet; the bar places the chip on it.
    pointer=function(board,event)
        if not event.pressed then return end
        local x,y=Extra.onPlane(board,event.x,event.y,LAYOUT.z)
        local bet,label,x0,y0,x1,y1=rouletteCell(x,y)
        if bet then Extra.select(board,bet,label,{x0,y0,x1,y1}) end
    end,
    aim=function(board,sx,sy,line)
        local z=LAYOUT.z+.004
        local sel=Extra.selection(board)
        if sel and sel.data then local r=sel.data;Extra.box(board,line,r[1],r[2],r[3],r[4],z,"#38f2ffff") end
        local bet,_,x0,y0,x1,y1=rouletteCell(Extra.onPlane(board,sx,sy,LAYOUT.z))
        if bet and not (sel and sel.key==bet) then Extra.box(board,line,x0,y0,x1,y1,z) end
    end,
})
