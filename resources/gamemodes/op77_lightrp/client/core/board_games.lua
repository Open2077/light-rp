-- Replicated server snapshots, local smooth presentation. No client move is authoritative.
-- Seated players play in FREE mode by default: no scripted camera, the
-- character keeps walking and looking around, the HUD stays. The crosshair
-- (screen centre) aims at the table and the left mouse button acts; the aimed
-- cell and the selection are outlined on the table itself. PANEL_KEY opens the
-- panel with a cursor (bets, Hit/Stand, game setup, and the optional scripted
-- camera views, the former default). Walking away from the table leaves it.
local Ui = LightRpUi
local NET = "lightrp:boardGames:request"
local VIEW, POINTER = "lightrp:boardGames:view", "lightrp:boardGames:pointer"
local Client = { boards = {} }
LightRpBoardGamesClient = Client
local active, draft, pointer, previous, started, lastView = nil, nil, nil, {}, false, 0
local pointerDown = false
local pointerEvents={}
local SCALE=.65
local CAMERA_VIEWS={"free","top","white","black","orbit"}
local PANEL_KEY="H" -- free in Light RP and its providers; E interacts, T chats, G/X belong to actions
-- Leaving by distance: beyond LEAVE_RADIUS for LEAVE_GRACE_MS (a step back
-- does not kick), or at once beyond LEAVE_HARD_RADIUS, the server's own seat
-- radius (server/modules/board_games.lua SEAT_RADIUS releases it every 2 s).
local LEAVE_RADIUS,LEAVE_HARD_RADIUS,LEAVE_GRACE_MS=3.5,5,1500
local dragPose
local applyCamera
local pendingPlacement
local tags = {}
local clearGhost
-- A board whose props do not render is hidden, then retried: heavy packs
-- (the blackjack table is 60 props from a 3 MB archive) can stream slowly.
local failedBoards,notifiedBoards={},{}
local leftBoards={}
-- Renderer thread heartbeats (see watchThreads): ensureBoard beats per created
-- prop, because a pass over many tables legitimately takes several seconds.
local beats,generations,threadErrors={},{},{}
local LOAD_GRACE_MS,RETRY_MS=15000,20000
-- Tables render up to RENDER_RADIUS metres away, nearest first, while their
-- props fit PROP_BUDGET (the client quota is 256 props per resource; the rest
-- is headroom for the placement ghost and new pieces).
local RENDER_RADIUS,PROP_BUDGET=40,220
local PROP_ESTIMATE={chess=34,checkers=42,connect4=44,roulette=4,slots=17,blackjack=61,fortune=46}
local ASSET_HELP="Close the game and rejoin through the launcher to install the board-game assets."
local sounds, soundSequences = {}, {}
local SOUND_NAMES={['chess-move']=true,['chess-capture']=true,['checkers-move']=true,
    ['checkers-capture']=true,['connect4-drop']=true,['game-win']=true}
local function request(action, payload)
    payload = payload or {}; payload.action = action
    return TriggerServerEvent(NET, payload)
end
-- Client traces land in the server log (the client log never reaches it).
local function trace(reason,boardId,format,...)
    local ok,details=pcall(string.format,format or "",...)
    request("diagnostic",{event="trace",reason=reason,boardId=boardId,details=(ok and details or tostring(format)):sub(1,180)})
end
Client.trace=trace
local function guarded(name,fn,...)
    local ok,result,second=pcall(fn,...)
    if ok then return result,second end
    local message=tostring(result)
    if threadErrors[message]==nil then threadErrors[message]=true;trace("thread_error",nil,"%s: %s",name,message) end
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
        panel=draft~=nil or (active~=nil and active.panel==true),free=active~=nil and active.camera==nil,panelKey=PANEL_KEY,
        leaving=active and active.farSince and math.max(0,LEAVE_GRACE_MS-(GetGameTimer()-active.farSince)) or nil,
        side=board and member(board),mode=board and (board.mode or "duel"),owned=board and board.owned,
        actor=board and board.actor,isActor=board and isActor(board),ready=board and isReady(board),
        players=board and board.players,playerCount=board and (function()
            local count=0;for _,id in pairs(board.players or {}) do if id then count=count+1 end end;return count
        end)(),selected=active and active.selected,axis=draft and draft.axis,
        text=draft and "Mouse: position • hold click: move • X/Y/Z: axis • Q/D: rotate • PgUp/PgDn: height • E: place • Backspace: cancel"
            or (board and board.kind=="connect4" and "Aim at a column and click to drop a disc • "..PANEL_KEY..": panel • Backspace: leave"
                or "Aim at a piece, click it, then click its destination (or hold and drag) • "..PANEL_KEY..": panel • Backspace: leave")}
    local adapter=extra(board)
    if LightRpTabletopExtraClient then LightRpTabletopExtraClient.setActive(adapter and board.id or nil) end
    if adapter then for key,value in pairs(adapter.view(board)) do payload[key]=value end end
    Ui.send(VIEW,payload)
end
-- The page takes the cursor only for placement and the open panel; free mode
-- leaves mouse-look, movement and the HUD to the game.
local function wantsCursor() return draft~=nil or (active~=nil and active.panel==true) end
local function applyFocus()
    local cursor=wantsCursor()
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:boardGames",cursor)
    if Ui.page then Ui.page:setFocus(false,cursor) end
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
                if generation==contextGeneration and Client.isActive() then applyFocus() end
            end
            -- Serialize rapid enter/leave changes: an old disable request must
            -- never finish after the final enable request and keep target locked.
            if generation==contextGeneration then break end
        end
        contextWorker=false
    end)
end
local function takeInput()
    Ui.setMenuOpen(false)
    Ui.dialogs.boardGames=true
    Ui.promptActive=true
    applyFocus()
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
    -- A snapshot sent before the server processed the leave still seats us:
    -- do not reopen this table until the server agrees or 3 s pass.
    if old then leftBoards[tostring(old.id)]=GetGameTimer()+3000 end
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
-- Optional scripted camera views (the former default): the panel keeps the
-- cursor while one is active, and closing the panel returns to free mode.
local function exitCamera()
    if not active then return end
    if active.cinematic then Open77.hud.setCinematic(false);active.cinematic=nil end
    if active.camera then Open77.camera.destroy(active.camera);active.camera=nil end
    if active.frozen then Open77.character.setFrozen(false);active.frozen=nil end
    active.cameraView="free";active.orbitDrag=nil;active.foreignCamera=nil;active.foreignCameraSince=nil
end
local function enterCamera(board,view)
    if active.camera then active.cameraView=view;return applyCamera() end
    local registry=Open77.camera.cameras()
    if not registry or registry.held then return false,"camera_held" end
    local camera,why=Open77.camera.create(cameraPose(board,view))
    if not camera then return false,"camera_create "..tostring(why) end
    local activated,reason=Open77.camera.activate(camera,{blendMs=250})
    if not activated then Open77.camera.destroy(camera);return false,"camera_activate "..tostring(reason) end
    active.camera=camera;active.cameraView=view;active.cameraGraceUntil=GetGameTimer()+1200
    -- A fixed view of a walking character makes no sense: freeze it, or give up.
    local frozen,frozenWhy=Open77.character.setFrozen(true)
    if not frozen then exitCamera();return false,"freeze "..tostring(frozenWhy) end
    active.frozen=true
    local hidden=Open77.hud.setCinematic(true,.01)
    active.cinematic=hidden==true
    return true
end
local function setPanel(open)
    if not active then return end
    open=open==true
    if not open and active.camera then exitCamera() end
    if active.panel~=open then
        active.panel=open
        active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;active.orbitDrag=nil;pointerDown=false
        pointer=not open and {x=.5,y=.5} or nil
        applyFocus()
    end
    sendView(true)
end
local function startView(board)
    if failedBoards[tostring(board.id)] then notice(ASSET_HELP);request("leave",{boardId=board.id});return end
    if active and active.id==board.id then return end
    if Client.isActive() then stop(true,"switch_board") end
    -- Every refusal is reported: a silent leave looks like "E does nothing".
    if not Ui.characterReady or Ui.creationActive or Ui.actionFocus or Ui.supportMode or not Ui.page or Ui.promptActive then
        request("diagnostic",{event="render",reason="view_refused",boardId=board.id,details=("ready=%s creation=%s action=%s support=%s page=%s prompt=%s"):format(
            tostring(Ui.characterReady),tostring(Ui.creationActive),tostring(Ui.actionFocus),tostring(Ui.supportMode),tostring(Ui.page~=nil),tostring(Ui.promptActive))})
        request("leave",{boardId=board.id})
        return
    end
    active={id=board.id,cameraView="free",panel=false,revision=board.revision,orbitAngle=-90,orbitRadius=1.8,orbitHeight=1.2}
    pointer={x=.5,y=.5}
    takeInput()
    trace("view_open",board.id,"kind=%s rev=%s view=free",board.kind,tostring(board.revision))
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
local PIECE_HEIGHTS={pawn=.086,rook=.097,knight=.114,bishop=.124,queen=.139,king=.152}
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
    -- The ray is moved into the board's unscaled frame once, so each piece is a
    -- local axis-aligned box tested without tables: the 176 client allows only
    -- about 10k instructions per resume, and this runs every frame.
    local mouse=cursor()
    local ray=mouse and Open77.camera.screenRay(mouse.x,mouse.y,15)
    local closest,hitRow,hitCol=15,nil,nil
    if ray then
        local a=math.rad(board.rotation or 0);local c,s=math.cos(a),math.sin(a)
        local dx,dy=ray.origin.x-board.position.x,ray.origin.y-board.position.y
        local ox,oy,oz=(dx*c+dy*s)/SCALE,(-dx*s+dy*c)/SCALE,(ray.origin.z-board.position.z)/SCALE
        local vx,vy,vz=(ray.direction.x*c+ray.direction.y*s)/SCALE,(-ray.direction.x*s+ray.direction.y*c)/SCALE,ray.direction.z/SCALE
        local checkers=board.kind=="checkers"
        local n=checkers and 10 or 8
        local radius=checkers and .035 or .037
        for r,line in pairs(board.game.board) do for col,piece in pairs(line) do
            if type(piece)=="table" and (ignorePiece==nil or tostring(piece.id)~=ignorePiece) then
                local height=checkers and (piece.kind=="king" and .032 or .014) or PIECE_HEIGHTS[piece.kind] or .1
                local cx,cy=(tonumber(col)-.5)/n-.5,(tonumber(r)-.5)/n-.5
                local enter,leave=0,15
                local lo,hi,o,d
                for axis=1,3 do
                    if axis==1 then lo,hi,o,d=cx-radius,cx+radius,ox,vx
                    elseif axis==2 then lo,hi,o,d=cy-radius,cy+radius,oy,vy
                    else lo,hi,o,d=.004,.004+height,oz,vz end
                    if math.abs(d)<.000001 then
                        if o<lo or o>hi then leave=-1;break end
                    else
                        local t1,t2=(lo-o)/d,(hi-o)/d
                        if t1>t2 then t1,t2=t2,t1 end
                        if t1>enter then enter=t1 end
                        if t2<leave then leave=t2 end
                        if leave<enter then break end
                    end
                end
                if leave>=enter and enter<closest then closest,hitRow,hitCol=enter,tonumber(r),tonumber(col) end
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
    -- A panel-only table (bets from the panel) opens its panel on a free-mode click.
    if adapter and event.crosshair and event.pressed and not adapter.aimable(board) then setPanel(true);return end
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
    -- The crosshair stays at the screen centre: a drag is the aim leaving the square.
    if event.crosshair and active.drag and not active.drag.moved then
        local point=planePoint(board)
        if point then
            local x,y=localXY(board,point)
            local n=board.kind=="checkers" and 10 or 8
            if math.floor((y+.5)*n)+1~=active.drag.row or math.floor((x+.5)*n)+1~=active.drag.col then active.drag.moved=true end
        end
    end
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
    return result,math.huge -- a board game changes only with a new snapshot
end
-- Each observer creates resource-owned native props from the authoritative board
-- snapshots. The game state travels over the network; these props never do.
local renderCaches,renderCandidates,renderAllowed={},{},{}
local rendererRunning=false
local ownedProps={}
local ghostProp
local DEPOT="open77\\assets\\op77_lightrp\\board_games\\"
-- Player collision (tools/COLLISION.md). A visual prop is never solid: a base
-- listed here has a cooked `<base>_collider.ent` beside it (static boxes, the
-- 0.65 scale baked in), created as its own prop at scale 1 once the table is
-- placed. The placement ghost and the pieces never get one. Add a base name
-- here only after its pack build ships the collider entity.
local TABLE_COLLIDERS={slot_cabinet=true,blackjack_table=true,roulette_table=true,fortune_stand=true,chess_board=true,checkers_board=true,connect4_board=true}
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
        removeProp(cache.board);removeProp(cache.collider)
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
        failedBoards[id]=GetGameTimer()
        if not notifiedBoards[id] then notifiedBoards[id]=true;unavailable(reason) end
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
local function colliderModel(board)
    local name=modelName(board,nil)
    local path=name:sub(-4)==".ent" and name or DEPOT..name..".ent"
    local base=path:match("([^\\]+)%.ent$")
    if base and TABLE_COLLIDERS[base] then return path:sub(1,-5).."_collider.ent" end
end
-- Solid, invisible to the eye (no mesh), never validated as a render: a missing
-- or failed collider only leaves the table walk-through, as before.
local function createCollider(board,model)
    local yaw=propYaw(board,nil)
    local handle,why=Open77.props.create({model=model,kind="prop",position=board.position,yaw=yaw,
        scale=1,physics="static",collision=true,visible=true})
    if not handle then trace("collider_create_failed",tostring(board.id),"%s %s",model,tostring(why));return nil end
    local record={handle=handle,name=model,position={x=board.position.x,y=board.position.y,z=board.position.z},yaw=yaw,
        created=GetGameTimer(),boardId=tostring(board.id),collider=true,ready=true}
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
    if GetGameTimer()-record.created<LOAD_GRACE_MS then return true end
    if record.ghost then unavailable(why);stop(false,"preview_transform_failed",why) else failBoard(record.boardId,why) end
    return false
end
local function validateProps(yieldFn)
    if next(ownedProps)==nil then return end
    local rows,why=Open77.props.list()
    if type(rows)~="table" then
        if ghostProp then unavailable(why);stop(false,"props_unavailable",why) end
        for id in pairs(renderCaches) do failBoard(id,why) end
        return
    end
    -- From its own thread, yield in slices: three nearby boards are ~100 props.
    -- Ids are snapshotted because other threads add props while this one waits.
    local byId={}
    for index,row in ipairs(rows) do
        byId[tostring(row.id)]=row
        if yieldFn and index%40==0 then yieldFn() end
    end
    local ids={};for id in pairs(ownedProps) do ids[#ids+1]=id end
    local failures={}
    for index,id in ipairs(ids) do
        local record,row=ownedProps[id],byId[id]
        -- A ready prop is re-checked only when its back-end changes (e.g. to a
        -- placeholder), which keeps the common path to a few instructions.
        if record and not record.collider and not (record.ready and row and not row.failed and row.backend==record.backend) then
            record.backend=row and row.backend
            local backend=row and tostring(row.backend or ""):lower() or ""
            local fallback=backend:find("marker",1,true) or backend:find("fallback",1,true)
                or backend:find("placeholder",1,true) or backend:find("cube",1,true)
            if row and row.rendered==true and not row.failed and not fallback then record.ready=true end
            if (row and (row.failed==true or fallback)) or (GetGameTimer()-record.created>LOAD_GRACE_MS and not record.ready) then
                failures[#failures+1]={record=record,why=row and (row.error or row.backend) or "model did not load"}
            end
        end
        if yieldFn and index%25==0 then yieldFn() end
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
-- Whether the cached targets were computed from this very snapshot.
local function fresh(cache,board)
    return cache.snapshot==board and cache.snapshotGame==board.game and cache.snapshotRevision==board.revision
end
local function ensureBoard(board)
    local id=tostring(board.id)
    local failedAt=failedBoards[id]
    if failedAt then
        if GetGameTimer()-failedAt<RETRY_MS then return end
        failedBoards[id]=nil
    end
    local cache=renderCaches[id]
    if cache and cache.kind~=board.kind then clearGeometry(id);cache=nil end
    if not cache then
        local prop,why=createProp(board,nil,board.position,false)
        if not prop then trace("render_create_failed",id,"kind=%s base %s",board.kind,tostring(why));failBoard(id,why);return end
        trace("render_start",id,"kind=%s model=%s",board.kind,tostring(prop.name))
        -- moving: keys of props not yet at their goal (the only ones animate touches);
        -- goals: last world targets; snapshot/holdUntil: when to recompute them.
        cache={kind=board.kind,board=prop,pieces={},initialized=false,moving={},goals={},holdUntil=0}
        renderCaches[id]=cache
        Wait(0);beats.render=GetGameTimer() -- one native create per resume, including a full initial board
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end
    if not cache.colliderTried then -- once per cache, even if a snapshot interrupted the pass above
        cache.colliderTried=true
        local model=colliderModel(board)
        if model then
            cache.collider=createCollider(board,model)
            Wait(0);beats.render=GetGameTimer() -- a failed create is a native call too
            if not aliveBoard(board) or renderCaches[id]~=cache then return end
        end
    end
    if distance(cache.board.position,board.position)>.00001 or cache.board.yaw~=(board.rotation or 0) then
        if not transformProp(cache.board,board.position,board.rotation or 0) then return end
        local collider=cache.collider
        if collider and collider.handle and Open77.props.setTransform(collider.handle,{position=board.position,yaw=propYaw(board,nil)}) then
            collider.position={x=board.position.x,y=board.position.y,z=board.position.z};collider.yaw=propYaw(board,nil)
        end
        Wait(0);beats.render=GetGameTimer()
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end
    -- Targets can cost several thousand instructions (chess, casino tables):
    -- compute them guarded, then yield before diffing so that several nearby
    -- tables never add up to one resume beyond the 176 client budget.
    -- Once the animation thread keeps this snapshot's targets, reuse them: a
    -- still table then costs no target computation at all.
    local targets=cache.initialized and fresh(cache,board) and cache.targets
        or guarded("render targets "..tostring(board.kind),pieceTargets,board)
    if not targets then return end
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
        if not prop then trace("render_create_failed",id,"kind=%s piece=%s %s",board.kind,tostring(key),tostring(why));failBoard(id,why);return end
        cache.pieces[key]=prop;cache.moving[key]=true -- e.g. a new disc starts above the grid
        Wait(0);beats.render=GetGameTimer()
        if not aliveBoard(board) or renderCaches[id]~=cache then return end
    end end
    if not cache.initialized then
        local count=0;for _ in pairs(cache.pieces) do count=count+1 end
        trace("render_done",id,"kind=%s pieces=%d",board.kind,count)
    end
    cache.initialized=true
end
local function pickupBoard(context)
    if GetInvokingResource()~="open77_contextmenu" or Client.isActive() or pendingPlacement then return end
    if not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode or Ui.promptActive then return end
    if type(context)~="table" or type(context.target)~="table" then return end
    local target=context.target
    if target.kind~="prop" or target.networked~=false or (type(target.propId)~="string" and type(target.propId)~="number") then return end
    local record=ownedProps[tostring(target.propId)]
    if record and record.collider then local cache=renderCaches[record.boardId];record=cache and cache.board end
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
-- A coroutine that exceeds the 176 client budget dies without a trace. Each
-- renderer thread beats every pass; the main loop restarts a silent one
-- (generation tokens retire the old one) and reports it. Work that does not
-- yield runs under pcall so an error names its line instead of killing the
-- thread.
-- Smooth motion without an engine tween: every frame, only the props that are
-- not yet at their goal get a native transform. Goals are recomputed only when
-- a new snapshot arrives or the adapter's declared hold expires (board games:
-- never in between; casino timelines: every frame while one runs), and a
-- recompute marks just the props whose target changed. A static table costs
-- nothing per frame.
local SETTLED=.0004       -- metres: closer than this, a prop lands exactly on its goal
local MOVE_SLICE=24       -- prop steps per resume (~100-130 instructions each, harness-measured)
-- Returns how many targets it had to compare (the work done).
local function refreshGoals(board,cache,targets,hold,now)
    local goals,moving,last=cache.goals,cache.moving,cache.targets
    local a=math.rad(board.rotation or 0);local c,s=math.cos(a)*SCALE,math.sin(a)*SCALE
    local bx,by,bz=board.position.x,board.position.y,board.position.z
    -- An adapter may hand back the very same target tables (blackjack reuses
    -- its still groups): those cannot have changed while the table stays put.
    if cache.frameX~=bx or cache.frameY~=by or cache.frameZ~=bz or cache.frameA~=a then
        last={};cache.frameX,cache.frameY,cache.frameZ,cache.frameA=bx,by,bz,a
    end
    last=last or {}
    local compared=0
    for key,target in pairs(targets) do
        if last[key]~=target or not goals[key] then
            compared=compared+1
            local p,piece=target.position,target.piece
            local goal=goals[key]
            local yaw=propYaw(board,piece)
            local x,y,z=bx+p.x*c-p.y*s,by+p.x*s+p.y*c,bz+p.z*SCALE
            local snap=piece.snap==true
            if not goal or goal.x~=x or goal.y~=y or goal.z~=z or goal.yaw~=yaw or goal.snap~=snap then
                goals[key]={x=x,y=y,z=z,yaw=yaw,snap=snap};moving[key]=true
            end
        end
    end
    for key in pairs(goals) do if not targets[key] then goals[key]=nil end end
    cache.snapshot,cache.snapshotGame,cache.snapshotRevision=board,board.game,board.revision
    cache.targets=targets;cache.holdUntil=hold or now
    return compared
end
-- Moves one prop a step towards its goal; true once it has landed.
local function stepProp(board,cache,key,amount,seated)
    local piece=cache.pieces[key]
    if not piece then return true end -- ensureBoard marks a prop moving when it creates it
    local override,direct
    if seated then override,direct=dragPose(board,key) end
    if direct then return false end -- the held piece follows the cursor from the main loop
    local goal=override or cache.goals[key]
    if not goal then return true end
    local yaw=override and piece.yaw or goal.yaw
    local from=piece.position
    local dx,dy,dz=goal.x-from.x,goal.y-from.y,goal.z-from.z
    local landed=goal.snap or dx*dx+dy*dy+dz*dz<SETTLED*SETTLED
    if landed then
        if dx~=0 or dy~=0 or dz~=0 or piece.yaw~=yaw then transformProp(piece,{x=goal.x,y=goal.y,z=goal.z},yaw) end
        return override==nil
    end
    transformProp(piece,{x=from.x+dx*amount,y=from.y+dy*amount,z=from.z+dz*amount},yaw)
    return false
end
-- One protected call per slice of moving props (keys[from..to]).
local function stepProps(board,cache,keys,from,to,amount,seated)
    local moving=cache.moving
    for index=from,to do
        local key=keys[index]
        if stepProp(board,cache,key,amount,seated) then moving[key]=nil end
    end
end
local THREADS={}
function THREADS.render(generation)
    while rendererRunning and generations.render==generation do
        beats.render=GetGameTimer()
        Wait(0)
        for _,entry in ipairs(renderCandidates) do
            if generations.render~=generation then return end
            if aliveBoard(entry.board) then ensureBoard(entry.board) end
            Wait(0);beats.render=GetGameTimer()
        end
        Wait(100)
    end
end
function THREADS.animate(generation)
    local previousTime=GetGameTimer()
    local turn,yielded,pending=0,false,nil
    while rendererRunning and generations.animate==generation do
        -- One pass per frame. A pass that ended on a yield (new targets just
        -- computed) continues straight into the next frame's work.
        if not yielded then Wait(0) end
        yielded=false
        beats.animate=GetGameTimer()
        local now=GetGameTimer();local dt=math.min(100,math.max(1,now-previousTime));previousTime=now
        local amount=1-math.exp(-dt/90)
        -- 0. Goals from the targets computed at the end of the last pass; two
        -- compared targets cost about one prop step.
        local moved=0
        if pending then
            local job=pending;pending=nil
            if renderCaches[job.id]==job.cache and Client.boards[job.key]==job.board then
                local compared=guarded("animate goals "..tostring(job.board.kind),refreshGoals,job.board,job.cache,job.targets,job.hold,job.now)
                moved=math.floor((compared or 0)/2)
                if moved>=MOVE_SLICE then Wait(0);beats.animate=GetGameTimer();moved=0 end
            end
        end
        -- Snapshot the ids: other threads clear caches while this one yields.
        local ids={};for id in pairs(renderCaches) do ids[#ids+1]=id end
        -- 1. Every moving prop of every table, every frame (sliced if many).
        for _,id in ipairs(ids) do
            local cache=renderCaches[id]
            local board=cache and renderAllowed[id] and Client.boards[tonumber(id) or id]
            if board and cache.initialized then
                if active and active.id==board.id then
                    if active.drag then cache.moving[active.drag.pieceId]=true end
                    if active.pendingMove then cache.moving[active.pendingMove.pieceId]=true end
                end
                if next(cache.moving)~=nil then
                    local seated=active~=nil and active.id==board.id
                    local keys={};for key in pairs(cache.moving) do keys[#keys+1]=key end
                    local from=1
                    while from<=#keys do
                        if moved>=MOVE_SLICE then Wait(0);beats.animate=GetGameTimer();moved=0 end
                        if renderCaches[id]~=cache or not renderAllowed[id] then break end
                        local to=math.min(#keys,from+MOVE_SLICE-moved-1)
                        guarded("animate "..tostring(board.kind),stepProps,board,cache,keys,from,to,amount,seated)
                        moved=moved+to-from+1;from=to+1
                    end
                end
            end
        end
        -- 2. Targets for at most one table per frame (round robin), only when
        -- its snapshot changed or its declared hold expired. Goals follow at
        -- the start of the next pass, in their own share of the budget.
        now=GetGameTimer()
        for index=1,#ids do
            local id=ids[(turn+index-1)%#ids+1]
            local cache=renderCaches[id]
            local key=tonumber(id) or id
            local board=cache and renderAllowed[id] and Client.boards[key]
            if board and cache.initialized and (not fresh(cache,board) or now>=cache.holdUntil) then
                turn=turn+index
                if moved>8 then Wait(0);beats.animate=GetGameTimer() end
                if renderCaches[id]==cache and Client.boards[key]==board then
                    local targets,hold=guarded("animate targets "..tostring(board.kind),pieceTargets,board)
                    if targets then pending={id=id,key=key,cache=cache,board=board,targets=targets,hold=hold,now=now} end
                    Wait(0);yielded=true
                end
                break
            end
        end
    end
end
function THREADS.validate(generation)
    while rendererRunning and generations.validate==generation do
        beats.validate=GetGameTimer()
        Wait(250)
        if rendererRunning then validateProps(function() Wait(0) end) end
    end
end
local function spawnThread(name)
    generations[name]=(generations[name] or 0)+1;beats[name]=GetGameTimer()
    local generation=generations[name]
    CreateThread(function() THREADS[name](generation) end)
end
local function watchThreads()
    if not rendererRunning then return end
    local now=GetGameTimer()
    for name in pairs(THREADS) do
        if now-(beats[name] or now)>15000 then
            trace("thread_stalled",nil,"%s silent for %d ms, restarting",name,now-beats[name])
            spawnThread(name)
        end
    end
end
local function startRenderer()
    rendererRunning=true
    spawnThread("render");spawnThread("animate");spawnThread("validate")
end
-- The held piece follows the cursor (or the crosshair) from the main loop's
-- render resume, right after the input that moved it; the animation thread
-- leaves it alone while it is held.
local function moveHeldPiece()
    local drag=active and active.drag
    if not drag or not drag.moved or not pointerDown then return end
    local board=Client.boards[active.id];local cache=board and renderCaches[tostring(board.id)]
    local piece=cache and cache.pieces[drag.pieceId]
    if not piece then return end
    local p,direct=dragPose(board,drag.pieceId)
    if p and direct then transformProp(piece,p,piece.yaw) end
end
local function renderPreview()
    local board=draft or (active and Client.boards[active.id])
    if not board then
        if tags.preview then Open77.debugDraw.clear("boardGames:preview");tags.preview=nil end
        return
    end
    local geometry={lines={},triangles={},ttl=.4,maxDistance=18,thickness=2}
    local function line(a,b,color) geometry.lines[#geometry.lines+1]={a=a,b=b,color=color or "#ffcc00ff"} end
    local adapter=not draft and extra(board)
    if adapter then
        -- Casino tables outline what the crosshair or the cursor points at.
        local p=cursor()
        if p then adapter.aim(board,p.x,p.y,line) end
        if #geometry.lines==0 then
            if tags.preview then Open77.debugDraw.clear("boardGames:preview");tags.preview=nil end
            return
        end
    elseif draft then
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
        trace("place_confirm",nil,"kind=%s pos=%.1f,%.1f,%.1f",draft.kind,draft.position.x,draft.position.y,draft.position.z)
        request("place",{kind=draft.kind,position=draft.position,rotation=draft.rotation})
        draft=nil;clearGhost();pointerEvents={};pointerDown=false;releaseInput();sendView(true)
    elseif draft then
        trace("place_not_ready",nil,"kind=%s ghost=%s age=%sms",draft.kind,tostring(ghostProp~=nil),
            tostring(ghostProp and GetGameTimer()-ghostProp.created))
        notice("The board model is still loading. Wait a moment before placing it.")
    end
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
        trace("place_refused",nil,"kind=%s character unavailable",kind)
        notice("You cannot place a board while your character is unavailable.");return
    end
    local hit=Open77.camera.screenRaycast(.5,.5,3,{static=true,dynamic=true})
    local pos=hit and hit.hit and hit.position or {x=state.position.x,y=state.position.y+1,z=state.position.z}
    -- Start within reach even when the camera ray hits geometry below the map.
    -- The height axis remains free so players can lower the preview afterwards.
    local initialZ=math.max(pos.z+.015,state.position.z+.35)
    -- Floor-standing tables declare how high their origin sits above the floor
    -- (unscaled metres, `floor` in their shared spec): start the preview there.
    local spec=LightRpBoardGames and LightRpBoardGames[kind]
    if spec and type(spec.floor)=="number" then initialZ=pos.z+spec.floor*SCALE end
    draft={kind=kind,position={x=pos.x,y=pos.y,z=initialZ},rotation=0,axis="xy",height=0}
    local prop,why=createProp(draft,nil,draft.position,true)
    if not prop then trace("place_ghost_failed",nil,"kind=%s %s",kind,tostring(why));draft=nil;unavailable(why);return end
    trace("place_ghost",nil,"kind=%s model=%s",kind,tostring(prop.name))
    ghostProp=prop
    takeInput();sendView(true)
end
local function beginPlacement(p)
    if type(p)~="table" or (p.kind~="chess" and p.kind~="checkers" and p.kind~="connect4" and not extra(p)) then
        trace("place_unknown",nil,"kind=%s",tostring(type(p)=="table" and p.kind));return
    end
    trace("place_begin",nil,"kind=%s inventory=%s prompt=%s active=%s",p.kind,tostring(Ui.dialogs.inventory),tostring(Ui.promptActive),tostring(Client.isActive()))
    if placementUnavailable(true) or (Ui.promptActive and not Ui.dialogs.inventory and not Client.isActive()) then
        local open={};for name,isOpen in pairs(Ui.dialogs or {}) do if isOpen then open[#open+1]=name end end
        trace("place_refused",nil,"ready=%s creation=%s action=%s support=%s prompt=%s dialogs=%s",tostring(Ui.characterReady),tostring(Ui.creationActive),
            tostring(Ui.actionFocus),tostring(Ui.supportMode),tostring(Ui.promptActive),table.concat(open,","))
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
        trace("place_cancelled",nil,"kind=%s another dialog opened",pending.kind)
        pendingPlacement=nil;notice("Board placement cancelled because another dialog opened.");return
    end
    if GetGameTimer()>pending.deadline then
        trace("place_cancelled",nil,"kind=%s inventory did not close inventory=%s prompt=%s menu=%s",pending.kind,
            tostring(Ui.dialogs.inventory),tostring(Ui.promptActive),tostring(Ui.menuOpen))
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
        local board=active and Client.boards[active.id]
        if not board or type(p)~="table" then return end
        if p.view then
            local valid=false;for _,view in ipairs(CAMERA_VIEWS) do if p.view==view then valid=true end end
            if not valid then return end
            active.drag=nil;active.clickDestination=nil;active.orbitDrag=nil
            if p.view=="free" then exitCamera()
            else
                -- A scripted view needs the cursor to point: it opens the panel.
                local ok,why=enterCamera(board,p.view)
                if ok then
                    if not active.panel then active.panel=true;applyFocus() end
                else
                    notice("This camera view is unavailable.")
                    if why then trace("camera_refused",board.id,"view=%s %s",p.view,tostring(why)) end
                end
            end
        end
        if type(p.zoom)=="number" and p.zoom==p.zoom and active.camera then
            active.orbitRadius=math.max(1,math.min(3,active.orbitRadius+p.zoom*.15));applyCamera()
        end
        sendView(true)
    end)
    page:on("lightrp:boardGames:panel",function(p)
        if active and type(p)=="table" then setPanel(p.open==true) end
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
    if not assembling or assembling.seq~=payload.seq then
        if assembling and assembling.count<assembling.parts then
            local missing={}
            for index=1,assembling.parts do if not assembling.received[index] then missing[#missing+1]=tostring(index) end end
            trace("state_parts_lost",nil,"seq=%s got=%d/%d missing=%s",tostring(assembling.seq),assembling.count,assembling.parts,table.concat(missing,","))
        end
        assembling={seq=payload.seq,parts=payload.parts,received={},count=0}
    end
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
applyState=function(payload)
    if type(payload)~="table" or type(payload.boards)~="table" then return end
    local nextBoards={}
    for _,board in ipairs(payload.boards) do
        -- Games deeper than the 176 event codec allows arrive as JSON text.
        if type(board)=="table" and board.game==nil and type(board.gameJson)=="string" then
            local game,why=Open77.json.decode(board.gameJson)
            if type(game)=="table" then board.game=game;board.gameJson=nil
            else trace("state_decode_failed",board.id,"%s",tostring(why)) end
        end
        if type(board)=="table" and board.id and board.position and board.game then
            nextBoards[board.id]=board
            local adapter=extra(board);if adapter then adapter.observe(board) end
            boardSound(board)
            if not Client.boards[board.id] then
                LightRpInteract.setLocal("boardGames."..board.id,{position=board.position,radius=1.8,
                    prompt=((LightRpBoardGames and LightRpBoardGames[board.kind] or {}).title or "Table").." — Play"},function()
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
        local b=nextBoards[active.id]
        trace("state",b.id,"kind=%s rev=%s->%s phase=%s ready=%s actor=%s serverNow=%s",b.kind,tostring(active.revision),tostring(b.revision),
            tostring(b.game and b.game.phase),tostring(b.ready),tostring(b.actor),tostring(b.serverNow))
        active.selected=nil;active.drag=nil;active.clickDestination=nil;active.pendingMove=nil;active.dropPressed=nil;active.revision=nextBoards[active.id].revision
    end
    if active and not nextBoards[active.id] then stop(false,"board_removed")
    elseif active and not member(nextBoards[active.id]) then stop(false,"seat_removed") end
    if not draft then
        local now=GetGameTimer()
        for _,board in pairs(nextBoards) do
            local id=tostring(board.id)
            if leftBoards[id] and (now>leftBoards[id] or not member(board)) then leftBoards[id]=nil end
            if member(board) and not leftBoards[id] then startView(board);break end
        end
    end
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
                -- Free mode leaves the keyboard and mouse to the game: while chat
                -- or another page types, or the pause menu is open, the table
                -- keys and clicks stay inert.
                local typing=active~=nil and not wantsCursor() and (Open77.input.isCaptured()==true
                    or (Open77.session~=nil and type(Open77.session.isMenuOpen)=="function" and Open77.session.isMenuOpen()==true))
                for _,k in ipairs({"E","BACKSPACE","ESC","Q","D","PAGEUP","PAGEDOWN","X","Y","Z","mouse1",PANEL_KEY}) do
                    keys[k]=not typing and Open77.input.isDown(k)==true
                end
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
                if Client.isActive() and pressed("BACKSPACE") then stop(true,"key_backspace")
                elseif draft and pressed("ESC") then stop(true,"key_escape")
                elseif active and active.panel and pressed("ESC") then setPanel(false) end
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
                    local registry=active.camera and Open77.camera.cameras()
                    local far=board and state and state.position and distance(state.position,board.position)
                    if far and far>LEAVE_RADIUS then
                        if not active.farSince then active.farSince=now;sendView(true) end
                    elseif active.farSince then active.farSince=nil;sendView(true) end
                    if not board then stop(true,"board_unavailable")
                    elseif far and (far>LEAVE_HARD_RADIUS or (active.farSince and now-active.farSince>=LEAVE_GRACE_MS)) then
                        notice("You walked away from the table and left your seat.")
                        stop(true,"distance",("%.1f m"):format(far))
                    elseif active.camera and cameraSwitched(active,registry,now) then
                        stop(true,"camera_switched","expected="..tostring(active.camera).." actual="..tostring(registry and registry.activeCamera).." held="..tostring(registry and registry.held))
                    else
                        if pressed(PANEL_KEY) then setPanel(not active.panel) end
                        for _,event in ipairs(events) do if active then pointerAction(board,event) end end
                        -- Free mode: the crosshair is the pointer and the left button acts.
                        if active and not active.panel then
                            local edge=pressed("mouse1") and "pressed" or (previous.mouse1 and not keys.mouse1) and "released" or nil
                            if edge or keys.mouse1 then pointerAction(board,{x=.5,y=.5,crosshair=true,pressed=edge=="pressed",released=edge=="released"}) end
                            if active and not active.panel then pointer={x=.5,y=.5} end
                        end
                    end
                end
                previous=keys
            end)
            -- The 176 client allows about 10k instructions per resume: input and
            -- actions above, streaming and the preview below, in separate resumes.
            if ok then Wait(0) end
            if ok then ok,why=pcall(function()
                local state=Open77.character.state()
                local near,allowed={},{}
                if state and state.position then
                    for _,board in pairs(Client.boards) do
                        local d=distance(state.position,board.position)
                        if d<RENDER_RADIUS then near[#near+1]={board=board,d=d} end
                    end
                    table.sort(near,function(a,b)
                        if active and a.board.id==active.id then return true end
                        if active and b.board.id==active.id then return false end
                        return a.d<b.d
                    end)
                end
                -- Nearest first (the active table always), within the per-resource
                -- client prop quota (256): a blackjack table alone is up to 60 props.
                renderCandidates={}
                local props=0
                for _,entry in ipairs(near) do
                    local id=tostring(entry.board.id);local cache=renderCaches[id]
                    local cost=PROP_ESTIMATE[entry.board.kind] or 45
                    if cache then cost=cache.collider and 2 or 1;for _ in pairs(cache.pieces) do cost=cost+1 end end
                    if #renderCandidates>0 and props+cost>PROP_BUDGET then break end
                    props=props+cost;renderCandidates[#renderCandidates+1]=entry;allowed[id]=true
                end
                renderAllowed=allowed
                for id in pairs(renderCaches) do if not allowed[id] then clearGeometry(id) end end
                moveHeldPiece()
                watchThreads()
                renderPreview()
                if Client.isActive() then sendView(false) end
            end) end
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
