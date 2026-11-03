-- Presentation adapters only. Bets, shuffles, placements and outcomes remain on
-- the server. These adapters use raw authored native prop templates, never draws.
-- Casino tables plug in with Extra.register(kind,{
--   boardModel=function(board) return depotPath end,     -- the placed base prop
--   pieceTargets=function(board,result) end,              -- Extra.put(...) each moving prop
--   camera=function(board,view) return pose end,          -- optional; default table views
--   view=function(board) return {extra=...,text=...} end, -- optional; default board.game
--   pointer=function(board,event) return handled end,     -- optional; default: panel only
--   aim=function(board,x,y,line) end,                     -- optional; outline what x,y points at
--   operations={name=true,...},                           -- page actions forwarded to the server
--   turnOnly=true,                                        -- optional; only the actor may act
-- })
-- The renderer moves only props whose target changed, every frame, and calls
-- pieceTargets again only when a new snapshot arrives or the targets expire.
-- pieceTargets says how long its result holds, in server time:
--   Extra.animatingUntil(board,t) -- targets change every frame until t
--   Extra.stillUntil(board,t)     -- targets hold until t (math.huge: next snapshot)
-- Several calls combine (the earliest wins). An adapter that declares nothing
-- is recomputed every frame, the safe default for a time-driven table.
-- pieceTargets runs inside the 176 client's ~10k instruction budget per
-- resume: keep it to a few dozen props, no searches.
-- event.x/y are the cursor in panel mode and the screen centre (crosshair)
-- in free mode; Open77.camera.screenRay(event.x,event.y) works for both.
local Extra={}
LightRpTabletopExtraClient=Extra
local SCALE=.65
Extra.SCALE=SCALE
local NET="lightrp:boardGames:request"
local games={}
local boards,clocks={},{}
local activeId
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
function Extra.setActive(id)
    if type(id)=="table" then Extra.observe(id);id=id.id end
    activeId=id
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
-- Whether a click at this table means something on the table itself (free
-- mode aims with the crosshair); panel-only tables open their panel instead.
function Extra.aimable(board)
    local adapter=games[board.kind]
    return adapter~=nil and adapter.pointer~=nil
end
-- Outline what the screen point aims at: adapter.aim calls line(a,b) with
-- world points. Cheap: it runs every frame for the active table.
function Extra.aim(board,x,y,line)
    local adapter=games[board.kind]
    if adapter and adapter.aim then adapter.aim(board,x,y,line) end
end
function Extra.camera(board,view)
    local adapter=games[board.kind]
    if adapter.camera then local pose=adapter.camera(board,view);if pose then return pose end end
    local side=view=="black" and -1 or 1
    if view=="white" or view=="black" then
        return {position=world(board,0,side*1.65,.85),lookAt=world(board,0,0,0),fov=52}
    end
    if view=="top" then
        return {position=world(board,0,-.015,1.85),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
    end
end
function Extra.view(board)
    Extra.observe(board)
    local adapter=games[board.kind]
    if adapter.view then return adapter.view(board) end
    return {extra=board.game}
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
    if not adapter then return false end
    if event.rightPressed or event.rightReleased then return false end
    if adapter.pointer then return adapter.pointer(board,event) end
    return true -- money is wagered explicitly in the panel
end
function Extra.bind(page)
    page:on("lightrp:tabletop:action",function(payload)
        local board=activeId and boards[activeId]
        if not board or type(payload)~="table" then
            trace("action_refused",board,"page action %s without an active table (active=%s)",tostring(type(payload)=="table" and payload.operation),tostring(activeId))
            return
        end
        command(board,payload.operation,payload.data)
    end)
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
    camera=function(board,view)
        local world=Extra.world
        if view=="top" then
            return {position=world(board,.78,-.01,2.05),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
        elseif view=="white" then -- the betting layout, from the players' side
            return {position=world(board,1.0,-1.55,1.05),lookAt=world(board,.85,0,0),fov=50}
        elseif view=="black" then -- close on the wheel to follow the ball
            return {position=world(board,-.10,-.80,.70),lookAt=world(board,0,.02,.03),fov=44}
        end
    end,
    view=function(board)
        return {extra=board.game,text="Choose a bet and amount. The server settles the roulette result."}
    end,
})
