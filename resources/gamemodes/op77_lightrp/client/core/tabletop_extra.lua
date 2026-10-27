-- Presentation adapters only. Bets, shuffles, placements and outcomes remain on
-- the server. These adapters use raw authored native prop templates, never draws.
local Extra={}
LightRpTabletopExtraClient=Extra
local SCALE=.65
local DEPOT="open77\\assets\\op77_lightrp\\tabletop_extra\\"
local NET="lightrp:boardGames:request"
local boards,clocks={},{}
local activeId,selectedTile
local cardPlacement={level=0,yaw=0,orientation="frame"}
local press
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e12 end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
local function seat(board)
    local id=me()
    for name,player in pairs(board.players or {}) do if id and tonumber(player)==id then return name end end
end
local function playerTurn(board)
    if not seat(board) or board.ready==false then return false end
    if board.kind=="cardtower" then return board.game.status=="playing" end
    if board.actor~=nil then return tonumber(board.actor)==me() end
    return board.game.seatTurn==nil or board.game.seatTurn==seat(board)
end
local function world(board,x,y,z)
    local a=math.rad(board.rotation or 0);local c,s=math.cos(a),math.sin(a)
    return {x=board.position.x+(x*c-y*s)*SCALE,y=board.position.y+(x*s+y*c)*SCALE,z=board.position.z+(z or 0)*SCALE}
end
local function point(board,event)
    local ray=Open77.camera.screenRay(event.x,event.y,15)
    if not ray or not ray.direction or math.abs(ray.direction.z)<.00001 then return end
    local t=(board.position.z-ray.origin.z)/ray.direction.z
    if t<=0 or t>15 then return end
    local dx=(ray.origin.x+ray.direction.x*t-board.position.x)/SCALE
    local dy=(ray.origin.y+ray.direction.y*t-board.position.y)/SCALE
    local a=math.rad(board.rotation or 0);local c,s=math.cos(a),math.sin(a)
    return dx*c+dy*s,-dx*s+dy*c
end
function Extra.supports(kind) return kind=="roulette" or kind=="dominoes" or kind=="cardtower" end
function Extra.observe(board)
    if not board or not Extra.supports(board.kind) then return end
    boards[board.id]=board
    local stamp=tonumber(board.serverNow)
    local clock=clocks[board.id]
    if stamp and (not clock or stamp~=clock.stamp) then clocks[board.id]={stamp=stamp,received=GetGameTimer()} end
end
function Extra.setActive(id)
    if type(id)=="table" then Extra.observe(id);id=id.id end
    if id~=activeId then activeId=id;selectedTile=nil;press=nil end
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
        return asset(board.kind=="roulette" and "roulette_table" or board.kind=="dominoes" and "dominos_board" or "cardtower_board")
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
local function dominoModel(a,b)
    a,b=tonumber(a) or 0,tonumber(b) or 0
    return string.format("domino_%d_%d",math.min(a,b),math.max(a,b)),a>b and 180 or 0
end
local function handPosition(index,count)
    local spacing=math.min(.052,.8/math.max(1,count))
    return (index-(count+1)/2)*spacing,.48,.004
end
local function dominoTargets(board,result)
    local game=board.game
    for _,obj in ipairs(game.objects or {}) do
        local a,b=obj.a or obj.left or 0,obj.b or obj.right or 0
        local model,flip=dominoModel(a,b)
        put(result,"domino-"..tostring(obj.tileId or obj.id),"domino",model,obj.x,obj.y,obj.z or .004,(obj.yaw or 0)+flip,{tileId=obj.tileId or obj.id,a=a,b=b})
    end
    local hand=game.hand or {}
    for index,tile in ipairs(hand) do
        local model,flip=dominoModel(tile.a,tile.b)
        local x,y,z=handPosition(index,#hand)
        if tostring(selectedTile)==tostring(tile.id) then z=z+.012 end
        put(result,"domino-"..tostring(tile.id),"domino",model,x,y,z,flip,{tileId=tile.id,a=tile.a,b=tile.b,inHand=true})
    end
end
local function collapsePose(board,obj)
    local collapse=board.game.collapse
    local pose=obj.pose or obj.orientation or "flat"
    local model=pose=="lean-left" and "playing_card_lean_left" or pose=="lean-right" and "playing_card_lean_right" or "playing_card_flat"
    local x,y,z,yaw=obj.x or 0,obj.y or 0,obj.z or 0,obj.yaw or 0
    if type(collapse)~="table" then return x,y,z,yaw,model end
    local state=(collapse.objects or {})[tostring(obj.id)] or (collapse.objects or {})[obj.id] or obj
    local elapsed=clamp((serverTime(board)-(tonumber(collapse.startedAt or collapse.t0) or serverTime(board)))/1000,0,3)
    local gravity=tonumber(collapse.gravity) or 9.81
    local z0,vz=tonumber(state.z) or z,tonumber(state.vz) or 0
    local vx,vy=tonumber(state.vx) or 0,tonumber(state.vy) or 0
    local floor=.001
    local impact=(vz+math.sqrt(math.max(0,vz*vz+2*gravity*math.max(0,z0-floor))))/gravity
    local travel=math.min(elapsed,impact)+math.min(math.max(0,elapsed-impact),.6)*.25
    x=(tonumber(state.x) or x)+vx*travel;y=(tonumber(state.y) or y)+vy*travel
    z=math.max(floor,z0+vz*elapsed-.5*gravity*elapsed*elapsed)
    if elapsed>impact then
        local after=elapsed-impact
        z=math.max(floor,floor+math.abs(vz-gravity*impact)*.15*after-.5*gravity*after*after)
    end
    yaw=yaw+(tonumber(state.angularVelocity) or 0)*math.min(elapsed,.9)
    if pose=="lean-left" or pose=="lean-right" then
        local step=math.min(5,math.floor(clamp(elapsed/.6,0,1)*5+.00001))
        if step>0 then model=model.."_fall_"..step end
    end
    return x,y,z,yaw,model
end
local function cardTargets(board,result)
    for _,obj in ipairs(board.game.objects or {}) do
        local x,y,z,yaw,model=collapsePose(board,obj)
        put(result,"card-"..tostring(obj.id),"playing_card",model,x,y,z,yaw,{pose=obj.pose or obj.orientation})
    end
end
function Extra.pieceTargets(board)
    Extra.observe(board)
    local result={}
    if board.kind=="roulette" then rouletteTargets(board,result)
    elseif board.kind=="dominoes" then dominoTargets(board,result)
    elseif board.kind=="cardtower" then cardTargets(board,result) end
    return result
end
function Extra.camera(board,view)
    local side=view=="black" and -1 or 1
    if view=="white" or view=="black" then
        return {position=world(board,0,side*1.65,board.kind=="cardtower" and 1.1 or .85),lookAt=world(board,0,0,board.kind=="cardtower" and .12 or 0),fov=52}
    end
    if view=="top" then
        return {position=world(board,0,-.015,1.85),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
    end
end
function Extra.view(board)
    Extra.observe(board)
    return {extra=board.game,selectedTile=selectedTile,cardPlacement=cardPlacement,
        text=board.kind=="dominoes" and "Choose a domino, then click the left or right end of the chain."
            or board.kind=="cardtower" and "Choose a frame or roof, then click the table to place it."
            or "Choose a bet and amount. The server settles the roulette result."}
end
local OPERATIONS={roulette={bet=true,spin=true,nextRound=true},dominoes={play=true,draw=true,pass=true},cardtower={place=true}}
local function command(board,operation,data)
    if not board or not Extra.supports(board.kind) or not seat(board) or not OPERATIONS[board.kind][operation] then return false end
    if board.kind~="roulette" and not playerTurn(board) then return false end
    if type(data)~="table" then data={} end
    return TriggerServerEvent(NET,{action="game",boardId=board.id,revision=board.revision,operation=operation,data=data})==true
end
function Extra.pointer(board,event)
    if not Extra.supports(board.kind) then return false end
    Extra.observe(board)
    if event.blocked or event.cancelled then press=nil;return true end
    if event.rightPressed or event.rightReleased then return false end
    if not finite(event.x) or not finite(event.y) then return true end
    if board.kind=="roulette" then return true end -- money is wagered explicitly in the panel
    local x,y=point(board,event)
    if event.pressed then
        press=nil
        if x and y then press={boardId=board.id,x=x,y=y} end
    end
    if not event.released then return true end
    local down=press;press=nil
    if not down or down.boardId~=board.id or not x or not y or math.abs(down.x-x)+math.abs(down.y-y)>.12 then return true end
    if board.kind=="dominoes" then
        local hand=board.game.hand or {}
        for index,tile in ipairs(hand) do
            local hx,hy=handPosition(index,#hand)
            if math.abs(x-hx)<.022 and math.abs(y-hy)<.035 then selectedTile=tile.id;return true end
        end
        if selectedTile and playerTurn(board) and math.abs(x)<.53 and math.abs(y)<.4 then
            command(board,"play",{tileId=selectedTile,["end"]=x<0 and "left" or "right"})
        end
    elseif board.kind=="cardtower" and playerTurn(board) and math.abs(x)<.48 and math.abs(y)<.34 then
        command(board,"place",{x=x,y=y,level=cardPlacement.level,yaw=cardPlacement.yaw,orientation=cardPlacement.orientation})
    end
    return true
end
function Extra.bind(page)
    page:on("lightrp:tabletop:action",function(payload)
        local board=activeId and boards[activeId]
        if not board or type(payload)~="table" then return end
        if payload.operation=="configure" then
            local data=type(payload.data)=="table" and payload.data or {}
            if finite(data.level) then cardPlacement.level=math.floor(clamp(data.level,0,52)) end
            if finite(data.yaw) then cardPlacement.yaw=data.yaw%360 end
            if data.orientation=="frame" or data.orientation=="flat" then cardPlacement.orientation=data.orientation end
            if data.selectedTile~=nil then selectedTile=data.selectedTile end
            return
        end
        command(board,payload.operation,payload.data)
    end)
end
