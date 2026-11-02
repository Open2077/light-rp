-- Replicated server snapshots, local smooth presentation. No client move is authoritative.
local Ui = LightRpUi
local NET = "lightrp:boardGames:request"
local VIEW, POINTER = "lightrp:boardGames:view", "lightrp:boardGames:pointer"
local Client = { boards = {} }
LightRpBoardGamesClient = Client
local active, draft, pointer, previous, started, lastView = nil, nil, nil, {}, false, 0
local pointerDown = false
local pointerEvents={}
local SCALE=.65
local CAMERA_VIEWS={"top","white","black","orbit"}
local dragPose
local applyCamera
local pendingPlacement
local tags = {}
local clearGhost
local failedBoards={}
local ASSET_HELP="Close the game and rejoin through the launcher to install the board-game assets."
local sounds, soundSequences = {}, {}
local SOUND_NAMES={['chess-move']=true,['chess-capture']=true,['checkers-move']=true,
    ['checkers-capture']=true,['connect4-drop']=true,['game-win']=true}
local function request(action, payload)
    payload = payload or {}; payload.action = action
    return TriggerServerEvent(NET, payload)
end
local function notice(text)
    Ui.send(LightRpEvents.page.notice, { kind = "info", title = "Board Games", body = text })
end
local function me()
    local state = Open77.network.status()
    return state and tonumber(state.playerId)
end
local function member(board)
    local id = me()
    for _, slot in ipairs({"white", "black", "white2", "black2"}) do
        if id and tonumber((board.players or {})[slot]) == id then return slot:find("white",1,true) and "white" or "black" end
    end
end
local function isReady(board)
    if board.ready~=nil then return board.ready==true end
    return board.players.white~=nil and (board.mode=="solo" or board.players.black~=nil)
end
local function isActor(board)
    if board.actor~=nil then return tonumber(board.actor)==me() end
    return member(board)==board.game.turn
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function clearSounds(all)
    local now=GetGameTimer()
    for id,expires in pairs(sounds) do
        if all or expires<=now then Open77.audio.destroy(id);sounds[id]=nil end
    end
end
local function boardSound(board)
    local seq=tonumber(board.moveSequence)
    local old=soundSequences[board.id]
    soundSequences[board.id]=seq
    if not seq or old==nil or seq<=old or not SOUND_NAMES[board.lastSound] then return end
    local char=Open77.character.state()
    if not char or not char.position or distance(char.position,board.position)>14 then return end
    if not Open77.audio or type(Open77.audio.play3D)~="function" then return end
    clearSounds(false)
    local count=0;for _ in pairs(sounds) do count=count+1 end
    if count>=8 then clearSounds(true) end
    local sound,why=Open77.audio.play3D("assets/audio/board-games/"..board.lastSound..".wav",board.position,
        {volume=.45,maxDistance=14,loop=false})
    if sound then sounds[sound]=GetGameTimer()+3000
    elseif not Client.soundWarning then Client.soundWarning=true;Ui.log("board game sound unavailable: %s",tostring(why)) end
end
local function world(board, x,y,z)
    local angle = math.rad(board.rotation or 0)
    local c,s = math.cos(angle),math.sin(angle)
    return { x=board.position.x+(x*c-y*s)*SCALE, y=board.position.y+(x*s+y*c)*SCALE, z=board.position.z+(z or 0)*SCALE }
end
local function localXY(board,p)
    local a = math.rad(board.rotation or 0)
    local dx,dy=p.x-board.position.x,p.y-board.position.y
    return (dx*math.cos(a)+dy*math.sin(a))/SCALE,(-dx*math.sin(a)+dy*math.cos(a))/SCALE
end
local function extra(board)
    local adapter=LightRpTabletopExtraClient
    return adapter and board and adapter.supports(board.kind) and adapter or nil
end
local function sendView(force)
    if not force and GetGameTimer()-lastView < 120 then return end
    lastView=GetGameTimer()
    local board=active and Client.boards[active.id]
    local payload={active=active~=nil or draft~=nil,placing=draft~=nil,
        boardId=board and board.id,kind=draft and draft.kind or board and board.kind,
        turn=board and board.game.turn,ply=board and (board.game.ply or 0),
        canConfigure=board and (board.game.ply or 0)==0 and not board.game.chain,status=board and board.game.status,winner=board and board.game.winner,
        cameraView=active and active.cameraView,cameraViews=CAMERA_VIEWS,scale=SCALE,
        side=board and member(board),mode=board and (board.mode or "duel"),owned=board and board.owned,
        actor=board and board.actor,isActor=board and isActor(board),ready=board and isReady(board),
        players=board and board.players,playerCount=board and (function()
            local count=0;for _,id in pairs(board.players or {}) do if id then count=count+1 end end;return count
        end)(),selected=active and active.selected,axis=draft and draft.axis,
        text=draft and "Mouse: position • hold click: move • X/Y/Z: axis • Q/D: rotate • PgUp/PgDn: height • E: place • Backspace: cancel"
            or (board and board.kind=="connect4" and "Click a column to drop a disc • Backspace: leave • Target your board to pick it up"
                or "Drag a piece or click its start and destination • Backspace: leave • Target your board to pick it up")}
    local adapter=extra(board)
    if LightRpTabletopExtraClient then LightRpTabletopExtraClient.setActive(adapter and board.id or nil) end
    if adapter then for key,value in pairs(adapter.view(board)) do payload[key]=value end end
    Ui.send(VIEW,payload)
end
local contextBlocked,contextGeneration,contextWorker=false,0,false
local function disableContext(value)
    contextBlocked=value==true;contextGeneration=contextGeneration+1
    if contextWorker then return end
    contextWorker=true
    CreateThread(function()
        Wait(0)
        while true do
            local generation,wanted=contextGeneration,contextBlocked
            local pending,why=Open77.exports.call("open77_contextmenu","setTargetingEnabled",not wanted)
            local ok
            if pending then ok,why=pending:await() end
            if ok~=true then Ui.log("board games context claim failed: %s",tostring(why)) end
            if wanted and generation==contextGeneration and ok==true then
                local closing=Open77.exports.call("open77_contextmenu","close")
                if closing then closing:await() end
                if generation==contextGeneration and Client.isActive() and Ui.page then Ui.page:setFocus(false,true) end
            end
            -- Serialize rapid enter/leave changes: an old disable request must
            -- never finish after the final enable request and keep target locked.
            if generation==contextGeneration then break end
        end
        contextWorker=false
    end)
end
local function takeInput()
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:boardGames",true)
    Ui.setMenuOpen(false)
    Ui.dialogs.boardGames=true
    Ui.promptActive=true
    if Ui.page then Ui.page:setFocus(false,true) end
    disableContext(true)
    if LightRpControlClaims then
        for _,action in ipairs({"Attack","Melee","Grenade"}) do
            LightRpControlClaims.set("boardGames",action,true)
        end
    end
end
local function releaseInput()
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:boardGames",false)
    Ui.dialogs.boardGames=nil
    Ui.promptActive=false
    if Ui.page then Ui.page:setFocus(false,false) end
    disableContext(false)
    if LightRpControlClaims then
        for _,action in ipairs({"Attack","Melee","Grenade"}) do
            LightRpControlClaims.set("boardGames",action,false)
        end
    end
end
local lastDiagnostic=-10000
local function stop(notify,reason,details)
    local old=active
    if old or draft or pendingPlacement then
        reason=tostring(reason or "unspecified"):sub(1,64)
        details=tostring(details or ""):sub(1,180)
        Ui.log("board games stop: %s board=%s %s",reason,tostring(old and old.id or "placement"),details)
        if GetGameTimer()-lastDiagnostic>=2000 then
            lastDiagnostic=GetGameTimer()
            request("diagnostic",{event="stop",reason=reason,boardId=old and old.id,details=details})
        end
    end
    pendingPlacement=nil
    active,draft,pointer=nil,nil,nil
    if clearGhost then clearGhost() end
    pointerDown=false;pointerEvents={}
    if old and old.cinematic then Open77.hud.setCinematic(false) end
    if tags.draft then for _,tag in ipairs(tags.draft) do Open77.debugDraw.clear(tag) end;tags.draft=nil end
    if old and old.camera then Open77.camera.destroy(old.camera) end
    if old and old.frozen then Open77.character.setFrozen(false) end
    if old and notify then request("leave",{boardId=old.id}) end
    releaseInput();sendView(true)
end
function Client.isActive() return active~=nil or draft~=nil end
local function cameraPose(board,view)
    local adapter=extra(board)
    if adapter then local pose=adapter.camera(board,view);if pose then return pose end end
    if view=="orbit" then
        local angle=math.rad(active and active.orbitAngle or -90)
        local radius=active and active.orbitRadius or 1.8
        local height=active and active.orbitHeight or 1.2
        return {position=world(board,math.cos(angle)*radius,math.sin(angle)*radius,height),
            lookAt=world(board,0,0,board.kind=="connect4" and .47 or 0),fov=52}
    end
    if view=="white" or view=="black" then
        local side=view=="white" and 1 or -1
        if board.kind=="connect4" then side=-side end
        return {position=world(board,0,side*1.65,board.kind=="connect4" and .7 or 1.0),
            lookAt=world(board,0,0,board.kind=="connect4" and .47 or 0),fov=52}
    end
    if board.kind=="connect4" then
        return {position=world(board,0,-1.45,1.45),lookAt=world(board,0,0,.47),fov=52}
    end
    return {position=world(board,0,-.015,1.85),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
end
applyCamera=function()
    if not active then return false end
    local board=Client.boards[active.id];if not board then return false end
    local pose=cameraPose(board,active.cameraView)
    local ok=Open77.camera.setTransform(active.camera,{position=pose.position,rotation=pose.rotation,fov=pose.fov})
    if ok and pose.lookAt then ok=Open77.camera.lookAt(active.camera,pose.lookAt) end
    return ok==true
end
local function startView(board)
    if failedBoards[tostring(board.id)] then notice(ASSET_HELP);request("leave",{boardId=board.id});return end
    if active and active.id==board.id then return end
    if Client.isActive() then stop(true,"switch_board") end
    local registry=Open77.camera.cameras()
    if not Ui.characterReady or Ui.creationActive or Ui.actionFocus or Ui.supportMode or not Ui.page
        or Ui.promptActive or not registry or registry.held then request("leave",{boardId=board.id});return end
    local view=board.kind=="connect4" and "white" or "top"
    local camera,why=Open77.camera.create(cameraPose(board,view))
    if not camera then notice("Camera unavailable: "..tostring(why));request("leave",{boardId=board.id});return end
    if not Open77.camera.activate(camera,{blendMs=250}) then Open77.camera.destroy(camera);request("leave",{boardId=board.id});return end
    if not Open77.character.setFrozen(true) then Open77.camera.destroy(camera);request("leave",{boardId=board.id});return end
    active={id=board.id,camera=camera,cameraView=view,frozen=true,revision=board.revision,
        orbitAngle=-90,orbitRadius=1.8,orbitHeight=1.2,cameraGraceUntil=GetGameTimer()+1200}
    takeInput()
    local hidden,reason=Open77.hud.setCinematic(true,.01)
    if not hidden then notice("The game HUD could not be hidden: "..tostring(reason));stop(true,"hud_unavailable",reason);return end
    active.cinematic=true
    sendView(true)
end
local function cursor()
    if pointer and pointer.x and pointer.y then return pointer end
    local p=Open77.input.cursor()
    if p and p.inBounds then return p end
end
local function planePoint(board)
    local p=cursor();if not p then return end
    local ray=Open77.camera.screenRay(p.x,p.y,15)
    if not ray or math.abs(ray.direction.z)<.001 then return end
    local t=(board.position.z-ray.origin.z)/ray.direction.z
    if t<=0 or t>15 then return end
    return {x=ray.origin.x+ray.direction.x*t,y=ray.origin.y+ray.direction.y*t,z=board.position.z}
end
local function square(board,ignorePiece)
    if board.kind=="connect4" then
        local p=cursor();if not p then return end
        local ray=Open77.camera.screenRay(p.x,p.y,15);if not ray then return end
        local angle=math.rad(board.rotation or 0)
        local nx,ny=-math.sin(angle),math.cos(angle)
        local denominator=ray.direction.x*nx+ray.direction.y*ny
        if math.abs(denominator)<.001 then return end
        local t=((board.position.x-ray.origin.x)*nx+(board.position.y-ray.origin.y)*ny)/denominator
        if t<=0 or t>15 then return end
        local point={x=ray.origin.x+ray.direction.x*t,y=ray.origin.y+ray.direction.y*t,z=ray.origin.z+ray.direction.z*t}
        local x=localXY(board,point)
        local z=(point.z-board.position.z)/SCALE
        if x<-.49 or x>=.49 or z<.04 or z>=.88 then return end
        return 6-math.floor((z-.04)/.14),math.floor((x+.49)/.14)+1
    end
    -- Pick the visible body of a tall piece before falling back to the board
    -- plane. Side views otherwise project a queen's head onto the next square.
    local mouse=cursor()
    local ray=mouse and Open77.camera.screenRay(mouse.x,mouse.y,15)
    local closest,hitRow,hitCol=15,nil,nil
    local heights={pawn=.079,rook=.089,knight=.104,bishop=.108,queen=.111,king=.124,man=.014}
    if ray then
        local n=board.kind=="checkers" and 10 or 8
        for r,line in pairs(board.game.board) do for c,piece in pairs(line) do
            if type(piece)=="table" and tostring(piece.id)~=ignorePiece then
                local center=world(board,(tonumber(c)-.5)/n-.5,(tonumber(r)-.5)/n-.5,.004)
                local radius=(board.kind=="checkers" and .035 or .037)*SCALE
                local height=(board.kind=="checkers" and piece.kind=="king" and .032 or heights[piece.kind] or .1)*SCALE
                local low,high={x=center.x-radius,y=center.y-radius,z=center.z},{x=center.x+radius,y=center.y+radius,z=center.z+height}
                local enter,leave=0,15
                for _,axis in ipairs({"x","y","z"}) do
                    local d,o=ray.direction[axis],ray.origin[axis]
                    if math.abs(d)<.000001 then
                        if o<low[axis] or o>high[axis] then leave=-1;break end
                    else
                        local a,b=(low[axis]-o)/d,(high[axis]-o)/d
                        if a>b then a,b=b,a end
                        enter=math.max(enter,a);leave=math.min(leave,b)
                    end
                end
                if leave>=enter and enter<closest then closest,hitRow,hitCol=enter,tonumber(r),tonumber(c) end
            end
        end end
    end
    if hitRow then return hitRow,hitCol end
    local p=planePoint(board);if not p then return end
    local x,y=localXY(board,p)
    if x<-.5 or x>=.5 or y<-.5 or y>=.5 then return end
    local n=board.kind=="checkers" and 10 or 8
    return math.floor((y+.5)*n)+1,math.floor((x+.5)*n)+1
end
local function canMove(board)
    return member(board)==board.game.turn and isReady(board) and isActor(board) and board.game.status=="playing"
end
local function submitMove(board,fromRow,fromCol,toRow,toCol,pieceId)
    if not canMove(board) then return end
    request("move",{boardId=board.id,fromRow=fromRow,fromCol=fromCol,toRow=toRow,toCol=toCol,revision=board.revision,promotion="queen"})
    active.selected=nil
    if pieceId then active.pendingMove={pieceId=pieceId,row=toRow,col=toCol,revision=board.revision,expires=GetGameTimer()+1200} end
    sendView(true)
end
local function pointerAction(board,event)
    pointer={x=event.x,y=event.y}
    if event.blocked then
        local adapter=extra(board);if adapter then adapter.pointer(board,event) end
        active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;active.orbitDrag=nil;pointerDown=false;return
    end
    if event.rightPressed and active.cameraView=="orbit" then active.orbitDrag={x=event.x,y=event.y} end
    if event.rightReleased then active.orbitDrag=nil end
    if active.orbitDrag then
        local old=active.orbitDrag
        active.orbitAngle=(active.orbitAngle+(event.x-old.x)*250)%360
        active.orbitHeight=math.max(.4,math.min(2.8,active.orbitHeight+(event.y-old.y)*2))
        active.orbitDrag={x=event.x,y=event.y};applyCamera()
    end
    local adapter=extra(board)
    if adapter and adapter.pointer(board,event) then return end
    if not canMove(board) then active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;return end
    if event.pressed then
        pointerDown=true
        local row,col=square(board)
        if board.kind=="connect4" then active.dropPressed=row and {row=row,col=col} or nil;return end
        local piece=row and board.game.board[row][col]
        if type(piece)=="table" and piece.side==member(board) then
            active.selected={row=row,col=col}
            local n=board.kind=="checkers" and 10 or 8
            local center=world(board,(col-.5)/n-.5,(row-.5)/n-.5,.004)
            local grab=planePoint(board)
            active.drag={pieceId=tostring(piece.id),row=row,col=col,revision=board.revision,
                screenX=event.x,screenY=event.y,offsetX=grab and center.x-grab.x or 0,offsetY=grab and center.y-grab.y or 0}
            active.clickDestination=nil
        elseif row and active.selected then
            active.clickDestination={row=row,col=col,fromRow=active.selected.row,fromCol=active.selected.col,revision=board.revision}
        end
        sendView(true)
    end
    if active.drag and math.abs(event.x-active.drag.screenX)+math.abs(event.y-active.drag.screenY)>.006 then active.drag.moved=true end
    if event.released then
        pointerDown=false
        local drag=active.drag
        local row,col
        if drag then
            if not drag.moved then row,col=drag.row,drag.col
            else
                local point=planePoint(board)
                if point then
                    point.x=point.x+drag.offsetX;point.y=point.y+drag.offsetY
                    local x,y=localXY(board,point)
                    local n=board.kind=="checkers" and 10 or 8
                    if x>=-.5 and x<.5 and y>=-.5 and y<.5 then row,col=math.floor((y+.5)*n)+1,math.floor((x+.5)*n)+1 end
                end
            end
        else row,col=square(board) end
        if board.kind=="connect4" then
            local pressed=active.dropPressed
            if row and pressed and col==pressed.col then submitMove(board,0,0,row,col) end
            active.dropPressed=nil
        elseif drag then
            if drag.revision==board.revision and row and (row~=drag.row or col~=drag.col) then
                submitMove(board,drag.row,drag.col,row,col,drag.pieceId)
            end
        elseif active.clickDestination then
            local to=active.clickDestination
            if to.revision==board.revision and row==to.row and col==to.col then
                local piece=board.game.board[to.fromRow][to.fromCol]
                if type(piece)=="table" then submitMove(board,to.fromRow,to.fromCol,row,col,tostring(piece.id)) end
            end
        end
        active.drag=nil;active.clickDestination=nil
    end
end
local function positionOf(board,row,col)
    if board.kind=="connect4" then return {x=(col-4)*.14,y=0,z=(6.5-row)*.14+.04} end
    local n=board.kind=="checkers" and 10 or 8
    return {x=(col-.5)/n-.5,y=(row-.5)/n-.5,z=.004}
end
dragPose=function(board,pieceId)
    if not active or active.id~=board.id then return end
    if active.drag and active.drag.moved and active.drag.pieceId==pieceId and pointerDown and canMove(board) then
        local p=planePoint(board)
        if p then p.x=p.x+active.drag.offsetX;p.y=p.y+active.drag.offsetY;p.z=board.position.z+.004*SCALE;return p,true end
    end
    local pending=active.pendingMove
    if pending and pending.pieceId==pieceId and pending.revision==board.revision and GetGameTimer()<pending.expires then
        local p=positionOf(board,pending.row,pending.col)
        return world(board,p.x,p.y,p.z),false
    end
end
local function pieceTargets(board)
    local adapter=extra(board);if adapter then return adapter.pieceTargets(board) end
    local result={}
    for row,line in pairs(board.game.board or {}) do
        for col,p in pairs(line) do
            if type(p)=="table" then result[tostring(p.id)]={piece=p,position=positionOf(board,tonumber(row),tonumber(col))} end
        end
    end
    local counts={white=0,black=0}
    for _,p in ipairs(board.game.captured or {}) do
        if type(p)=="table" and p.id then
            local side=p.capturedBy or (p.side=="white" and "black" or "white");counts[side]=(counts[side] or 0)+1
            local i=counts[side]-1
            result[tostring(p.id)]={piece=p,position={x=-.45+(i%10)*.1,y=(side=="white" and .64 or -.64)+math.floor(i/10)*(side=="white" and .09 or -.09),z=.004}}
        end
    end
    return result
end
-- Each observer creates resource-owned native props from the authoritative board
-- snapshots. The game state travels over the network; these props never do.
local renderCaches,renderCandidates,renderAllowed={},{},{}
local rendererRunning=false
local ownedProps={}
local ghostProp
local DEPOT="open77\\assets\\op77_lightrp\\board_games\\"
local function removeProp(record)
    if record and record.handle then
        ownedProps[tostring(record.handle)]=nil
        Open77.props.remove(record.handle)
        record.handle=nil
    end
end
clearGhost=function()
    removeProp(ghostProp);ghostProp=nil
end
local function clearGeometry(id)
    if id=="draft" then clearGhost();return end
    local cache=renderCaches[id]
    if cache then
        removeProp(cache.board)
        for _,piece in pairs(cache.pieces) do removeProp(piece) end
        renderCaches[id]=nil
    end
    for _,tag in ipairs(tags[id] or {}) do Open77.debugDraw.clear(tag) end
    tags[id]=nil
end
local function modelName(board,piece)
    local adapter=extra(board);if adapter then return adapter.model(board,piece) end
    if not piece then return board.kind.."_board" end
    return board.kind.."_"..piece.side.."_"..piece.kind
end
local function unavailable(reason)
    notice(ASSET_HELP.." "..tostring(reason or ""))
end
local function failBoard(id,reason)
    if not failedBoards[id] then
        failedBoards[id]=true;unavailable(reason)
        request("diagnostic",{event="render",reason="board_failed",boardId=id,details=tostring(reason or ""):sub(1,180)})
    end
    clearGeometry(id)
    if active and tostring(active.id)==id then stop(true,"model_unavailable",reason) end
end
local function propYaw(board,piece)
    return ((board.rotation or 0)+(piece and tonumber(piece.yaw) or 0)+(piece and piece.kind=="knight" and piece.side=="white" and 180 or 0))%360
end
local function createProp(board,piece,position,isGhost)
    if not Open77.props or type(Open77.props.create)~="function" then return nil,"native props are unavailable" end
    local name=modelName(board,piece)
    local handle,why=Open77.props.create({model=name:sub(-4)==".ent" and name or DEPOT..name..".ent",kind="prop",position=position,
        yaw=propYaw(board,piece),scale=SCALE,physics="none",collision=false,visible=true})
    if not handle then return nil,why end
    local record={handle=handle,name=name,position={x=position.x,y=position.y,z=position.z},yaw=propYaw(board,piece),
        created=GetGameTimer(),boardId=not isGhost and tostring(board.id) or nil,ghost=isGhost,ready=false}
    ownedProps[tostring(handle)]=record
    return record
end
local function transformProp(record,position,yaw)
    if not record or not record.handle then return false end
    local ok,why=Open77.props.setTransform(record.handle,{position=position,yaw=yaw or record.yaw})
    if ok then
        record.position={x=position.x,y=position.y,z=position.z};record.yaw=yaw or record.yaw
        return true
    end
    -- Raw entity templates load asynchronously. Retain the original handle while
    -- they stream in; changing model or transform must never substitute a cube.
    if GetGameTimer()-record.created<3000 then return true end
    if record.ghost then unavailable(why);stop(false,"preview_transform_failed",why) else failBoard(record.boardId,why) end
    return false
end
local function validateProps()
    if next(ownedProps)==nil then return end
    local rows,why=Open77.props.list()
    if type(rows)~="table" then
        if ghostProp then unavailable(why);stop(false,"props_unavailable",why) end
        for id in pairs(renderCaches) do failBoard(id,why) end
        return
    end
    local byId={}
    for _,row in ipairs(rows) do byId[tostring(row.id)]=row end
    local failures={}
    for id,record in pairs(ownedProps) do
        local row=byId[id]
        local backend=row and tostring(row.backend or ""):lower() or ""
        local fallback=backend:find("marker",1,true) or backend:find("fallback",1,true)
            or backend:find("placeholder",1,true) or backend:find("cube",1,true)
        if row and row.rendered==true and not row.failed and not fallback then record.ready=true end
        if (row and (row.failed==true or fallback)) or (GetGameTimer()-record.created>3000 and not record.ready) then
            failures[#failures+1]={record=record,why=row and (row.error or row.backend) or "model did not load"}
        end
    end
    for _,failure in ipairs(failures) do
        local record=failure.record
        if record.handle then
            if record.ghost then unavailable(failure.why);stop(false,"preview_model_failed",failure.why)
            else failBoard(record.boardId,failure.why) end
        end
    end
end
local function aliveBoard(board)
    local current=Client.boards[board.id]
    return rendererRunning and renderAllowed[tostring(board.id)] and current and current.revision==board.revision
end
local function ensureBoard(board)
    local id=tostring(board.id)
    if failedBoards[id] then return end
    local cache=renderCaches[id]
    if cache and cache.kind~=board.kind then clearGeometry(id);cache=nil end
    if not cache then
        local prop,why=createProp(board,nil,board.position,false)
        if not prop then failBoard(id,why);return end
        cache={kind=board.kind,board=prop,pieces={},initialized=false}
        renderCaches[id]=cache
        Wait(0) -- one native create per resume, including a full initial board
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end
    if distance(cache.board.position,board.position)>.00001 or cache.board.yaw~=(board.rotation or 0) then
        if not transformProp(cache.board,board.position,board.rotation or 0) then return end
        Wait(0)
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end
    local targets=pieceTargets(board)
    for key,piece in pairs(cache.pieces) do
        local target=targets[key]
        if not target or piece.name~=modelName(board,target.piece) then
            removeProp(piece);cache.pieces[key]=nil -- promotion/reset replaces only that native prop
        end
    end
    for key,target in pairs(targets) do if not cache.pieces[key] then
        local p=world(board,target.position.x,target.position.y,target.position.z)
        if board.kind=="connect4" and cache.initialized then p.z=board.position.z+1.05*SCALE end
        local prop,why=createProp(board,target.piece,p,false)
        if not prop then failBoard(id,why);return end
        cache.pieces[key]=prop
        Wait(0)
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end end
    cache.initialized=true
end
local function pickupBoard(context)
    if GetInvokingResource()~="open77_contextmenu" or Client.isActive() or pendingPlacement then return end
    if not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode or Ui.promptActive then return end
    if type(context)~="table" or type(context.target)~="table" then return end
    local target=context.target
    if target.kind~="prop" or target.networked~=false or (type(target.propId)~="string" and type(target.propId)~="number") then return end
    local record=ownedProps[tostring(target.propId)]
    if not record or record.ghost or not record.boardId then return end
    local cache=renderCaches[record.boardId]
    local board=Client.boards[tonumber(record.boardId) or record.boardId]
    if not cache or cache.board~=record or not board or not board.owned then return end
    local character=Open77.character.state()
    if not character or character.alive~=true or character.attached~=true or not character.position
        or distance(character.position,board.position)>2 then return end
    return board
end
exports("boardGamesCanPickup",function(context) return pickupBoard(context)~=nil end)
exports("boardGamesPickup",function(context)
    local board=pickupBoard(context);if not board then return false end
    return request("pickup",{boardId=board.id})==true
end)
local function registerPickup()
    CreateThread(function()
        Wait(0)
        local pending,why=Open77.exports.call("open77_contextmenu","registerProps",{
            id="boardGames.pickup",label="Pick up board",icon="package",networked=false,distance=2,
            canInteract="boardGamesCanPickup",onSelect="boardGamesPickup",
        })
        local token
        if pending then token,why=pending:await() end
        if not token then Ui.log("board games target registration failed: %s",tostring(why)) end
    end)
end
AddEventHandler("onClientResourceStart",function(name)
    if name==GetCurrentResourceName() or name=="open77_contextmenu" then
        registerPickup()
        if name=="open77_contextmenu" then disableContext(Client.isActive()) end
    end
end)
-- Temporary render diagnostics: the client log never reaches the server, so a
-- board that stays invisible is reported only when the summary changes.
local lastRenderReport,lastRenderSummary=-10000,nil
local function renderReport(nearCount,state)
    local now=GetGameTimer()
    if now-lastRenderReport<5000 then return end
    local known,caches,pieces,failed=0,0,0,0
    for _ in pairs(Client.boards) do known=known+1 end
    for _,cache in pairs(renderCaches) do caches=caches+1;for _ in pairs(cache.pieces) do pieces=pieces+1 end end
    for _ in pairs(failedBoards) do failed=failed+1 end
    local rows,why=Open77.props.list()
    local total,rendered,broken,backend,err=0,0,0,"",""
    if type(rows)=="table" then
        for _,row in ipairs(rows) do
            total=total+1
            if row.rendered==true then rendered=rendered+1 end
            if row.failed==true then broken=broken+1;err=tostring(row.error or err) end
            backend=tostring(row.backend or backend)
        end
    else err="list:"..tostring(why) end
    local pos=state and state.position
    local summary=string.format("known=%d near=%d caches=%d pieces=%d failedBoards=%d props=%d rendered=%d failed=%d backend=%s err=%s pos=%s",
        known,nearCount,caches,pieces,failed,total,rendered,broken,backend,err,
        pos and string.format("%.0f,%.0f,%.0f",pos.x or 0,pos.y or 0,pos.z or 0) or "nil")
    if summary==lastRenderSummary then return end
    lastRenderReport=now;lastRenderSummary=summary
    request("diagnostic",{event="render",reason="render_summary",details=summary:sub(1,180)})
end
local function startRenderer()
    rendererRunning=true
    CreateThread(function()
        while rendererRunning do
            Wait(0)
            for _,entry in ipairs(renderCandidates) do
                if aliveBoard(entry.board) then ensureBoard(entry.board) end
            end
            Wait(100)
        end
    end)
    CreateThread(function()
        local previousTime=GetGameTimer()
        while rendererRunning do
            Wait(16)
            local now=GetGameTimer();local dt=math.min(100,math.max(1,now-previousTime));previousTime=now
            local amount=1-math.exp(-dt/100)
            local changes=0
            for id,cache in pairs(renderCaches) do
                local board=Client.boards[tonumber(id) or id]
                if board and renderAllowed[id] then
                    local targets=pieceTargets(board)
                    for key,piece in pairs(cache.pieces) do
                        local target=targets[key]
                        if target then
                            local override,direct=dragPose(board,key)
                            local p=override or world(board,target.position.x,target.position.y,target.position.z)
                            local from=piece.position
                            local yaw=propYaw(board,target.piece)
                            if distance(p,from)>.00002 or piece.yaw~=yaw then
                                local gain=direct and 1 or amount
                                local nextPosition={x=from.x+(p.x-from.x)*gain,y=from.y+(p.y-from.y)*gain,z=from.z+(p.z-from.z)*gain}
                                if not transformProp(piece,nextPosition,yaw) then break end
                                changes=changes+1
                                if changes%4==0 then
                                    Wait(0)
                                    if renderCaches[id]~=cache or not renderAllowed[id] then break end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    CreateThread(function()
        while rendererRunning do
            Wait(250)
            if rendererRunning then validateProps() end
        end
    end)
end
local function renderPreview()
    local board=draft or (active and Client.boards[active.id])
    if not board then
        if tags.preview then Open77.debugDraw.clear("boardGames:preview");tags.preview=nil end
        return
    end
    if extra(board) and not draft then
        if tags.preview then Open77.debugDraw.clear("boardGames:preview");tags.preview=nil end
        return
    end
    local geometry={lines={},triangles={},ttl=.4,maxDistance=18,thickness=2}
    local function line(a,b,color) geometry.lines[#geometry.lines+1]={a=a,b=b,color=color or "#ffcc00ff"} end
    if draft then
        if ghostProp and (distance(ghostProp.position,board.position)>.00001 or ghostProp.yaw~=(board.rotation or 0)) then
            if not transformProp(ghostProp,board.position,board.rotation or 0) then return end
        end
        line(board.position,world(board,.7,0,0),"#ff5555ff")
        line(board.position,world(board,0,.7,0),"#55ff55ff")
        line(board.position,world(board,0,0,.5),"#5599ffff")
    else
        local row,col=square(board)
        for _,cell in ipairs({active.selected or {},{row=row,col=col}}) do if cell.row and cell.col then
            local p=positionOf(board,cell.row,cell.col)
            local r=board.kind=="connect4" and .067 or .5/(board.kind=="checkers" and 10 or 8)
            local corners={{-r,-r},{r,-r},{r,r},{-r,r}}
            for i,c in ipairs(corners) do local q=corners[i%4+1]
                if board.kind=="connect4" then
                    line(world(board,p.x+c[1],-.03,p.z+c[2]),world(board,p.x+q[1],-.03,p.z+q[2]))
                else line(world(board,p.x+c[1],p.y+c[2],.009),world(board,p.x+q[1],p.y+q[2],.009)) end
            end
        end end
    end
    local ok,why=Open77.debugDraw.set("boardGames:preview",geometry)
    if ok then tags.preview={"boardGames:preview"}
    elseif not Client.drawWarning then Client.drawWarning=true;notice("3D rendering unavailable: "..tostring(why)) end
end
local function confirmPlacement()
    if not draft then return end
    validateProps()
    if draft and ghostProp and ghostProp.ready then
        request("place",{kind=draft.kind,position=draft.position,rotation=draft.rotation})
        draft=nil;clearGhost();pointerEvents={};pointerDown=false;releaseInput();sendView(true)
    elseif draft then notice("The board model is still loading. Wait a moment before placing it.") end
end
local function placementUnavailable(allowInventory)
    if not Ui.page or not Ui.characterReady or Ui.creationActive or Ui.actionFocus or Ui.supportMode then return true end
    for name,open in pairs(Ui.dialogs or {}) do
        if open and name~="boardGames" and (name~="inventory" or not allowInventory) then return true end
    end
    return false
end
local function placeDraft(kind)
    local state=Open77.character.state()
    if not state or not state.position or not state.alive or not state.attached then
        notice("You cannot place a board while your character is unavailable.");return
    end
    local hit=Open77.camera.screenRaycast(.5,.5,3,{static=true,dynamic=true})
    local pos=hit and hit.hit and hit.position or {x=state.position.x,y=state.position.y+1,z=state.position.z}
    -- Start within reach even when the camera ray hits geometry below the map.
    -- The height axis remains free so players can lower the preview afterwards.
    local initialZ=math.max(pos.z+.015,state.position.z+.35)
    draft={kind=kind,position={x=pos.x,y=pos.y,z=initialZ},rotation=0,axis="xy",height=0}
    local prop,why=createProp(draft,nil,draft.position,true)
    if not prop then draft=nil;unavailable(why);return end
    ghostProp=prop
    takeInput();sendView(true)
end
local function beginPlacement(p)
    if type(p)~="table" or (p.kind~="chess" and p.kind~="checkers" and p.kind~="connect4" and not extra(p)) then return end
    if placementUnavailable(true) or (Ui.promptActive and not Ui.dialogs.inventory and not Client.isActive()) then
        notice("Close the current dialog before placing your board.");return
    end
    if Client.isActive() then stop(true,"switch_to_placement") end
    Ui.setMenuOpen(false)
    if Ui.dialogs.inventory then
        -- React closes the inventory asynchronously. Its cleanup releases focus
        -- separately from dialogState; wait for BOTH before claiming the cursor.
        pendingPlacement={kind=p.kind,deadline=GetGameTimer()+2500}
        Ui.send(LightRpEvents.page.dialogClose,{kind="inventory"})
        return
    end
    placeDraft(p.kind)
end
local function finishPlacementHandoff()
    local pending=pendingPlacement;if not pending then return end
    if placementUnavailable(true) then
        pendingPlacement=nil;notice("Board placement cancelled because another dialog opened.");return
    end
    if GetGameTimer()>pending.deadline then
        pendingPlacement=nil;notice("The inventory did not close. Close it and use your board again.");return
    end
    if Ui.dialogs.inventory or Ui.promptActive or Ui.menuOpen then return end
    pendingPlacement=nil
    placeDraft(pending.kind)
end
function Client.bind(page)
    if LightRpTabletopExtraClient then LightRpTabletopExtraClient.bind(page) end
    page:on(POINTER,function(p)
        if not Client.isActive() or type(p)~="table" then return end
        if p.blocked or p.cancelled then
            pointerEvents[#pointerEvents+1]={blocked=true,x=pointer and pointer.x or .5,y=pointer and pointer.y or .5};return
        end
        if type(p.x)~="number" or type(p.y)~="number" or p.x~=p.x or p.y~=p.y or p.x<0 or p.x>1 or p.y<0 or p.y>1 then return end
        if #pointerEvents>=32 then pointerEvents={};if active then active.drag=nil;active.clickDestination=nil end end
        pointerEvents[#pointerEvents+1]=p
    end)
    page:on("lightrp:boardGames:camera",function(p)
        if not active or type(p)~="table" then return end
        if p.view then
            local valid=false;for _,view in ipairs(CAMERA_VIEWS) do if p.view==view then valid=true end end
            if not valid then return end
            active.cameraView=p.view;active.drag=nil;active.clickDestination=nil;active.orbitDrag=nil
        end
        if type(p.zoom)=="number" and p.zoom==p.zoom then active.orbitRadius=math.max(1,math.min(3,active.orbitRadius+p.zoom*.15)) end
        if not applyCamera() then notice("This camera view is unavailable.") end
        sendView(true)
    end)
    page:on("lightrp:boardGames:leave",function() if Client.isActive() then stop(true,"ui_leave") end end)
    page:on("lightrp:boardGames:confirm",confirmPlacement)
    page:on("lightrp:boardGames:mode",function(p)
        local board=active and Client.boards[active.id]
        if not board or not board.owned or (board.game.ply or 0)>0 or board.game.chain or type(p)~="table" then return end
        if p.mode~="solo" and p.mode~="duel" and p.mode~="teams" then return end
        request("mode",{boardId=board.id,mode=p.mode})
    end)
    page:on("lightrp:boardGames:reset",function()
        local board=active and Client.boards[active.id]
        if board and board.owned then request("reset",{boardId=board.id}) end
    end)
    page:on(LightRpEvents.page.ready,function() request("sync") end)
end
RegisterNetEvent("lightrp:boardGames:place",beginPlacement)
local applyState
local assembling
-- The server splits the state into numbered parts; apply only a complete set,
-- and drop a partial set as soon as a newer sequence starts.
local function assemble(payload)
    if type(payload)~="table" or type(payload.parts)~="number" or payload.parts<=1 then return payload end
    if not assembling or assembling.seq~=payload.seq then assembling={seq=payload.seq,parts=payload.parts,received={},count=0} end
    if type(payload.part)~="number" or assembling.received[payload.part] then return end
    assembling.received[payload.part]=type(payload.boards)=="table" and payload.boards or {}
    assembling.count=assembling.count+1
    if assembling.count<assembling.parts then return end
    local all={}
    for index=1,assembling.parts do for _,board in ipairs(assembling.received[index] or {}) do all[#all+1]=board end end
    assembling=nil
    return {boards=all}
end
RegisterNetEvent("lightrp:boardGames:state",function(part)
    local payload=assemble(part)
    if payload==nil then return end
    local ok,why=pcall(applyState,payload)
    if not ok then request("diagnostic",{event="render",reason="state_error",details=tostring(why):sub(1,180)}) end
end)
local lastStateTrace
applyState=function(payload)
    local listed,keyed,firstKey=0,0,nil
    if type(payload)=="table" and type(payload.boards)=="table" then
        for _ in ipairs(payload.boards) do listed=listed+1 end
        for k in pairs(payload.boards) do keyed=keyed+1;firstKey=firstKey or k end
    end
    local trace=("payload=%s boards=%s ipairs=%d pairs=%d firstKey=%s(%s)"):format(type(payload),type(payload)=="table" and type(payload.boards) or "-",
        listed,keyed,tostring(firstKey),type(firstKey))
    if trace~=lastStateTrace then
        lastStateTrace=trace
        request("diagnostic",{event="render",reason="state_received",details=trace})
    end
    if type(payload)~="table" or type(payload.boards)~="table" then return end
    local nextBoards={}
    for _,board in ipairs(payload.boards) do
        if type(board)=="table" and board.id and board.position and board.game then
            nextBoards[board.id]=board
            local adapter=extra(board);if adapter then adapter.observe(board) end
            boardSound(board)
            if not Client.boards[board.id] then
                LightRpInteract.setLocal("boardGames."..board.id,{position=board.position,radius=1.8,
                    prompt=(board.kind=="chess" and "Chess" or board.kind=="connect4" and "Connect Four" or board.kind=="roulette" and "Roulette" or "Checkers").." — Play"},function()
                    if not Client.isActive() then request("join",{boardId=board.id}) end
                end)
            end
        end
    end
    for id in pairs(Client.boards) do if not nextBoards[id] then
        LightRpInteract.setLocal("boardGames."..id,nil);clearGeometry(tostring(id));soundSequences[id]=nil
    end end
    Client.boards=nextBoards
    if active and nextBoards[active.id] and active.revision~=nextBoards[active.id].revision then
        active.selected=nil;active.drag=nil;active.clickDestination=nil;active.pendingMove=nil;active.dropPressed=nil;active.revision=nextBoards[active.id].revision
    end
    if active and not nextBoards[active.id] then stop(false,"board_removed")
    elseif active and not member(nextBoards[active.id]) then stop(false,"seat_removed") end
    if not draft then for _,board in pairs(nextBoards) do if member(board) then startView(board);break end end end
    sendView(true)
end
local function cameraKey(id)
    if type(id)=="number" then
        if id~=id then return end
        return id%1==0 and string.format("%.0f",id) or tostring(id)
    end
    if type(id)=="string" and id~="" then return id end
end
local function cameraSwitched(session,registry,now)
    if now<(session.cameraGraceUntil or 0) then return false end
    local actual=type(registry)=="table" and cameraKey(registry.activeCamera)
    local expected=cameraKey(session.camera)
    if actual and expected and actual~=expected and registry.held==true then
        if session.foreignCamera~=actual then
            session.foreignCamera=actual;session.foreignCameraSince=now
        end
        return now-(session.foreignCameraSince or now)>750
    end
    session.foreignCamera=nil;session.foreignCameraSince=nil
    return false -- nil/in-flight camera snapshots are not proof of a new owner
end
function Client.start()
    if started then return end;started=true
    startRenderer()
    registerPickup()
    CreateThread(function()
        -- Do not spend the activation pass on network/state work. The host's
        -- instruction meter spans script files; scheduled work starts after commit.
        Wait(0)
        request("sync")
        local last=GetGameTimer()
        while true do
            Wait(Client.isActive() and 16 or 50)
            local now=GetGameTimer();local dt=math.min(150,math.max(1,now-last));last=now
            local ok,why=pcall(function()
                local state=Open77.character.state()
                clearSounds(false)
                finishPlacementHandoff()
                local keys={}
                for _,k in ipairs({"E","BACKSPACE","ESC","Q","D","PAGEUP","PAGEDOWN","X","Y","Z","mouse1"}) do keys[k]=Open77.input.isDown(k)==true end
                local function pressed(k) return keys[k] and not previous[k] end
                local events=pointerEvents;pointerEvents={}
                if draft then
                    for _,event in ipairs(events) do
                        if event.blocked then pointerDown=false
                        else
                            pointer={x=event.x,y=event.y}
                            if event.pressed then pointerDown=true end
                            if event.released then pointerDown=false end
                        end
                    end
                end
                if Client.isActive() then
                    local why
                    if state and state.alive==false then why="character_dead"
                    elseif state and state.attached==false then why="character_detached"
                    elseif not Ui.characterReady then why="character_not_ready"
                    elseif Ui.creationActive then why="creator_open"
                    elseif Ui.menuOpen then why="menu_open"
                    elseif Ui.actionFocus then why="action_focus"
                    elseif Ui.supportMode then why="support_open"
                    elseif not state then
                        if active then
                            active.missingStateSince=active.missingStateSince or now
                            if now-active.missingStateSince>750 then why="character_unavailable" end
                        else why="character_unavailable" end
                    elseif active then active.missingStateSince=nil end
                    if why then stop(true,why) end
                end
                if Client.isActive() and (pressed("BACKSPACE") or pressed("ESC")) then
                    stop(true,pressed("BACKSPACE") and "key_backspace" or "key_escape")
                end
                if draft then
                    for _,axis in ipairs({"X","Y","Z"}) do if pressed(axis) then draft.axis=draft.axis==axis:lower() and "xy" or axis:lower() end end
                    local change=((keys.PAGEUP and 1 or 0)-(keys.PAGEDOWN and 1 or 0))*dt*.0003
                    draft.height=draft.height+change;draft.position.z=draft.position.z+change
                    draft.rotation=(draft.rotation+((keys.D and 1 or 0)-(keys.Q and 1 or 0))*dt*.06)%360
                    local point=planePoint(draft)
                    if point and (keys.mouse1 or pointerDown) then
                        if draft.axis=="xy" or draft.axis=="x" then draft.position.x=point.x end
                        if draft.axis=="xy" or draft.axis=="y" then draft.position.y=point.y end
                        if draft.axis=="z" and pointer and draft.lastY then draft.position.z=draft.position.z+(draft.lastY-pointer.y)*2 end
                    end
                    if pointer then draft.lastY=pointer.y end
                    if pressed("E") then confirmPlacement() end
                elseif active then
                    local board=Client.boards[active.id]
                    local registry=Open77.camera.cameras()
                    if not board then stop(true,"board_unavailable")
                    elseif state and state.position and distance(state.position,board.position)>4 then stop(true,"distance")
                    elseif cameraSwitched(active,registry,now) then
                        stop(true,"camera_switched","expected="..tostring(active.camera).." actual="..tostring(registry and registry.activeCamera).." held="..tostring(registry and registry.held))
                    else
                        for _,event in ipairs(events) do if active then pointerAction(board,event) end end
                    end
                end
                previous=keys
                local near,allowed={},{}
                if state and state.position then
                    for _,board in pairs(Client.boards) do
                        local d=distance(state.position,board.position)
                        if d<14 then near[#near+1]={board=board,d=d} end
                    end
                    table.sort(near,function(a,b)
                        if active and a.board.id==active.id then return true end
                        if active and b.board.id==active.id then return false end
                        return a.d<b.d
                    end)
                end
                renderCandidates={}
                for i=1,math.min(3,#near) do
                    renderCandidates[i]=near[i];allowed[tostring(near[i].board.id)]=true
                end
                renderAllowed=allowed
                renderReport(#near,state)
                for id in pairs(renderCaches) do if not allowed[id] then clearGeometry(id) end end
                renderPreview()
                if Client.isActive() then sendView(false) end
            end)
            if not ok then
                Ui.log("board games client: %s",tostring(why))
                if why~=Client.lastLoopError then
                    Client.lastLoopError=why
                    request("diagnostic",{event="render",reason="loop_error",details=tostring(why):sub(1,180)})
                end
                if Client.isActive() then stop(true,"client_error",tostring(why)) end
            end
        end
    end)
end
AddEventHandler("onClientResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    rendererRunning=false;renderAllowed={};renderCandidates={}
    stop(false,"resource_stop");clearSounds(true)
    for id in pairs(renderCaches) do clearGeometry(id) end
    for id in pairs(tags) do clearGeometry(id) end
    for id in pairs(Client.boards) do LightRpInteract.setLocal("boardGames."..id,nil) end
end)
