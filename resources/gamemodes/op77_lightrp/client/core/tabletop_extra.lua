-- Presentation adapters only. Bets, shuffles, placements and outcomes remain on
-- the server. These adapters use raw authored native prop templates, never draws.
local Extra={}
LightRpTabletopExtraClient=Extra
local SCALE=.65
local DEPOT="open77\\assets\\op77_lightrp\\tabletop_extra\\"
local NET="lightrp:boardGames:request"
local boards,clocks={},{}
local activeId
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
local function seat(board)
    local id=me()
    for name,player in pairs(board.players or {}) do if id and tonumber(player)==id then return name end end
end
local function world(board,x,y,z)
    local a=math.rad(board.rotation or 0);local c,s=math.cos(a),math.sin(a)
    return {x=board.position.x+(x*c-y*s)*SCALE,y=board.position.y+(x*s+y*c)*SCALE,z=board.position.z+(z or 0)*SCALE}
end
function Extra.supports(kind) return kind=="roulette" end
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
local function serverTime(board)
    Extra.observe(board)
    local clock=clocks[board.id]
    if clock then return clock.stamp+math.max(0,GetGameTimer()-clock.received) end
    return GetGameTimer()
end
local function asset(name) return DEPOT..name..".ent" end
function Extra.model(board,piece)
    if piece and type(piece.model)=="string" then return piece.model end
    if not piece then
        return asset("roulette_table")
    end
    return asset(piece.kind)
end
local function put(result,id,kind,model,x,y,z,yaw,metadata)
    local piece={id=id,kind=kind,side="neutral",model=asset(model),yaw=yaw or 0}
    if metadata then for key,value in pairs(metadata) do piece[key]=value end end
    result[tostring(id)]={piece=piece,position={x=x or 0,y=y or 0,z=z or 0}}
end
local function rouletteTargets(board,result)
    local spin=board.game.spin
    local wheel,ball,t=tonumber(board.game.lastWheelAngle) or 0,tonumber(board.game.lastBallAngle) or 0,0
    if type(spin)=="table" then
        local started=tonumber(spin.startedAt or spin.t0) or serverTime(board)
        t=clamp((serverTime(board)-started)/(tonumber(spin.duration) or 8000),0,1)
        local ease=1-(1-t)^4
        wheel=(tonumber(spin.wheelFrom) or 0)+((tonumber(spin.wheelTo) or 0)-(tonumber(spin.wheelFrom) or 0))*ease
        local ballEase=1-(1-t)^5
        ball=(tonumber(spin.ballFrom) or 0)+((tonumber(spin.ballTo) or 0)-(tonumber(spin.ballFrom) or 0))*ballEase
    end
    local a=math.rad(ball)
    put(result,"roulette-wheel","roulette_wheel","roulette_wheel",0,0,0,-wheel)
    put(result,"roulette-ball","roulette_ball","roulette_ball",.27*math.sin(a),.27*math.cos(a),.025+.006*math.sin(t*math.pi)^2,0)
end
function Extra.pieceTargets(board)
    Extra.observe(board)
    local result={}
    rouletteTargets(board,result)
    return result
end
function Extra.camera(board,view)
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
    return {extra=board.game,text="Choose a bet and amount. The server settles the roulette result."}
end
local OPERATIONS={roulette={bet=true,spin=true,nextRound=true}}
local function command(board,operation,data)
    if not board or not Extra.supports(board.kind) or not seat(board) or not OPERATIONS[board.kind][operation] then return false end
    if type(data)~="table" then data={} end
    return TriggerServerEvent(NET,{action="game",boardId=board.id,revision=board.revision,operation=operation,data=data})==true
end
function Extra.pointer(board,event)
    if not Extra.supports(board.kind) then return false end
    if event.rightPressed or event.rightReleased then return false end
    return true -- money is wagered explicitly in the panel
end
function Extra.bind(page)
    page:on("lightrp:tabletop:action",function(payload)
        local board=activeId and boards[activeId]
        if not board or type(payload)~="table" then return end
        command(board,payload.operation,payload.data)
    end)
end
