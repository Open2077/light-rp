-- Presentation adapters only. Bets, shuffles, placements and outcomes remain on
-- the server. These adapters use raw authored native prop templates, never draws.
-- Casino tables plug in with Extra.register(kind,{
--   boardModel=function(board) return depotPath end,     -- the placed base prop
--   pieceTargets=function(board,result) end,              -- Extra.put(...) each moving prop
--   camera=function(board,view) return pose end,          -- optional; default table views
--   view=function(board) return {extra=...,text=...} end, -- optional; default board.game
--   pointer=function(board,event) return handled end,     -- optional; default: panel only
--   operations={name=true,...},                           -- page actions forwarded to the server
--   turnOnly=true,                                        -- optional; only the actor may act
-- })
-- pieceTargets runs every animation tick inside the 176 client's ~10k
-- instruction budget per resume: keep it to a few dozen props, no searches.
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
function Extra.pieceTargets(board)
    Extra.observe(board)
    local result={}
    games[board.kind].pieceTargets(board,result)
    return result
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
local function command(board,operation,data)
    local adapter=board and games[board.kind]
    if not adapter or not seat(board) or not (adapter.operations or {})[operation] then return false end
    if adapter.turnOnly and board.actor~=nil and tonumber(board.actor)~=me() then return false end
    if type(data)~="table" then data={} end
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
        if not board or type(payload)~="table" then return end
        command(board,payload.operation,payload.data)
    end)
end

-- Roulette -------------------------------------------------------------------
local ROULETTE="open77\\assets\\op77_lightrp\\tabletop_extra\\"
Extra.register("roulette",{
    operations={bet=true,spin=true,nextRound=true},
    boardModel=function() return Extra.asset(ROULETTE,"roulette_table") end,
    pieceTargets=function(board,result)
        local spin=board.game.spin
        local wheel,ball,t=tonumber(board.game.lastWheelAngle) or 0,tonumber(board.game.lastBallAngle) or 0,0
        if type(spin)=="table" then
            local now=Extra.serverTime(board)
            local started=tonumber(spin.startedAt or spin.t0) or now
            t=clamp((now-started)/(tonumber(spin.duration) or 8000),0,1)
            local ease=1-(1-t)^4
            wheel=(tonumber(spin.wheelFrom) or 0)+((tonumber(spin.wheelTo) or 0)-(tonumber(spin.wheelFrom) or 0))*ease
            local ballEase=1-(1-t)^5
            ball=(tonumber(spin.ballFrom) or 0)+((tonumber(spin.ballTo) or 0)-(tonumber(spin.ballFrom) or 0))*ballEase
        end
        local a=math.rad(ball)
        Extra.put(result,"roulette-wheel","roulette_wheel",Extra.asset(ROULETTE,"roulette_wheel"),0,0,0,-wheel)
        Extra.put(result,"roulette-ball","roulette_ball",Extra.asset(ROULETTE,"roulette_ball"),.27*math.sin(a),.27*math.cos(a),.025+.006*math.sin(t*math.pi)^2,0)
    end,
    view=function(board)
        return {extra=board.game,text="Choose a bet and amount. The server settles the roulette result."}
    end,
})
