-- Replicated server snapshots, local smooth presentation. No client move is authoritative.
-- E (or the ALT menu's Sit) seats the player and opens the GAME VIEW: a
-- scripted camera framing the table (per-game views, cycled from the bar;
-- orbit with right-drag and the wheel where it makes sense), the character
-- frozen, the gameplay HUD hidden and the mouse cursor shown. The cursor
-- picks on the table through Open77.camera.screenRay: squares and pieces,
-- Connect Four columns, roulette cells, fortune spots, the blackjack circle,
-- the slot lever, the pool cloth. On the table (debugDraw): what can be
-- clicked right now is marked faintly (THREADS.marks), the hovered target
-- amber, the selection cyan. A compact bar at the bottom of the page
-- (ui/src/features/board-games/TableBar.tsx) holds the status, the chip and
-- the contextual buttons, built per game by client/core/table_bar.lua.
-- The last view of the cycle, "Free", plays from the player's own character:
-- no scripted camera, the character walks and looks around, the HUD stays,
-- no page cursor; the crosshair (screen centre) aims at the table, the left
-- mouse button acts and the hover and marks are drawn as in the other views.
-- The bar stays as an overlay; FREE_CURSOR_KEY (H) takes the cursor for the
-- bar (and cursor picking) and gives it back.
-- Leaving (Escape, the bar's Leave, walking away) restores everything. The
-- ALT target menu (client/core/table_menu.lua) only manages tables (Sit,
-- Pick up, the owner's mode and New game).
--
-- Placement (an inventory item): the preview (a "ghost" of the table) and
-- the page cursor with the bar in its placement mode. Press or drag on the
-- world to move the preview where the cursor ray meets the ground or a
-- surface (within reach); the arrow keys (or the bar's buttons) turn it,
-- PgUp/PgDn (or the buttons) raise or lower it; E or Place puts it there,
-- Escape or Cancel cancels. Every exit is traced (place_confirm, place_end,
-- place_not_ready, ...) into the server log.
--
-- Escape: the plugin turns Escape into the pause menu (open77:pauseKey). While
-- seated or placing, the page takes the keyboard with gameplay input kept
-- (page:setFocus(true,cursor,true), webui.keep_input) and consumes Escape
-- (page:setConsumedKeys{"escape",...}): the page receives the key (TableBar.tsx
-- leaves or cancels) and the pause menu does not open. A client without
-- consumed keys keeps the page cursor-only; Escape then reaches
-- open77:pauseKey, which still leaves the table, and the pause menu opens as
-- well. The keys the table uses (E, H, arrows, PgUp/PgDn) are read twice:
-- physically (Open77.input.isDown) and from the page, which holds the
-- keyboard and forwards them (lightrp:boardGames:key); a press counts once.
local Ui = LightRpUi
local NET = "lightrp:boardGames:request"
local VIEW, POINTER = "lightrp:boardGames:view", "lightrp:boardGames:pointer"
local Client = { boards = {} }
LightRpBoardGamesClient = Client
local active, draft, pointer, previous, started, lastView = nil, nil, nil, {}, false, -100000
local pointerDown = false
local pointerEvents={}
-- "keyboard": the page holds the keyboard (keep-input) and consumes Escape;
-- "cursor": cursor only (Escape reaches the pause menu); nil: no focus taken.
local focusMode,focusCheckAt,escapeWarned=nil,0,false
local ESCAPE_KEYS={"escape"}
-- Placing: the page also takes the arrows and PgUp/PgDn from the game.
local PLACE_KEYS={"escape","left","right","pageup","pagedown"}
local FREE_CURSOR_KEY="H" -- free on foot: E interacts, T chats, F/G/X/Y/B belong to actions
-- Keys forwarded by the page: held ones expire unless the OS repeat refreshes
-- them (a lost keyup never sticks), presses are queued for the input resume.
local TABLE_KEYS={E=true,H=true,LEFT=true,RIGHT=true,PAGEUP=true,PAGEDOWN=true}
local HELD_KEYS={LEFT=true,RIGHT=true,PAGEUP=true,PAGEDOWN=true}
local PAGE_HOLD_MS,PRESS_DEDUPE_MS=1200,250
local pageHeld,pagePressed,lastPress={},{},{}
local SCALE=.65
-- Leaving by distance: beyond LEAVE_RADIUS for LEAVE_GRACE_MS (a step back
-- does not kick), or at once beyond LEAVE_HARD_RADIUS, the server's own seat
-- radius (server/modules/board_games.lua SEAT_RADIUS releases it every 2 s).
local LEAVE_RADIUS,LEAVE_HARD_RADIUS,LEAVE_GRACE_MS=3.5,5,1500
local VIEW_MS=200 -- the bar is refreshed at most this often (and at once on changes)
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
-- Tables render up to FAR_RADIUS metres away, nearest first, while their
-- props fit PROP_BUDGET (the client quota is 256 props per resource; the rest
-- is headroom for the placement ghost and new pieces). Three levels of detail
-- (renderAllowed[id]): "full" within RENDER_RADIUS (pieces and the solid
-- collider), "far" beyond it (pieces, no collider: nobody walks into a table
-- 100 m away), "base" when the pieces no longer fit (the table alone, 1 prop).
-- The meshes are cooked LODMode AlwaysVisible, so a far table is drawn.
local RENDER_RADIUS,FAR_RADIUS,PROP_BUDGET=40,150,220
local PROP_ESTIMATE={chess=34,checkers=42,connect4=44,roulette=4,slots=17,blackjack=61,fortune=46,pool=20}
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
local function notice(text,title)
    Ui.send(LightRpEvents.page.notice, { kind = "info", title = title or "Board Games", body = text })
end
Client.notice=notice
local function titleOf(kind)
    local spec=LightRpBoardGames and LightRpBoardGames[kind]
    return spec and spec.title
end
Client.request=request
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
-- The bar model (client/core/table_bar.lua) plus what every table shares:
-- the camera views, the walk-away warning, Leave. Sent on changes and at most
-- every VIEW_MS while seated (countdowns, timed reveals, the pool charge).
local placementView
local function sendView(force)
    local now=GetGameTimer()
    if not force and now-lastView<VIEW_MS then return end
    lastView=now
    local board=active and Client.boards[active.id]
    if not board then
        if draft and not active and placementView then Ui.send(VIEW,placementView());return end
        Ui.send(VIEW,{active=false});return
    end
    local Bar=LightRpTableBar
    local payload=Bar and guarded("table bar "..tostring(board.kind),Bar.model,board) or {}
    payload.active=true;payload.kind=board.kind;payload.boardId=board.id
    payload.title=payload.title or titleOf(board.kind) or "Table"
    payload.view=active.cameraView;payload.views=active.views
    payload.orbit=active.cameraView=="orbit" or nil
    payload.camera=active.camera~=nil
    -- Free: on the character; the bar is an overlay until the cursor key.
    if active.cameraView=="free" then payload.free={cursor=active.freeCursor==true,key=FREE_CURSOR_KEY} end
    payload.leaving=active.farSince and math.max(0,LEAVE_GRACE_MS-(now-active.farSince)) or nil
    Ui.send(VIEW,payload)
end
-- The page cursor: placement, the scripted views (and a refused camera, which
-- plays from the game camera with the cursor), Free only after the cursor key.
local function wantsCursor()
    if active then return active.cameraView~="free" or active.freeCursor==true end
    return draft~=nil
end
-- The voice plate and the gameplay HUD step aside in the scripted views (the
-- page hides its own HUD while the bar is active, except in Free). Seated or
-- placing, the page takes the keyboard with gameplay input kept, to receive
-- Escape without the pause menu (see the header).
local function applyFocus()
    local seated=active~=nil
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:boardGames",seated and active.cameraView~="free")
    local page=Ui.page
    if not page then focusMode=nil;return end
    if not seated and not draft then return end
    local cursor=wantsCursor()
    local keys=(draft and not seated) and PLACE_KEYS or ESCAPE_KEYS
    local consumed=type(page.setConsumedKeys)=="function" and page:setConsumedKeys(keys)==true
    if consumed and page:setFocus(true,cursor,true)==true then focusMode="keyboard";return end
    if consumed then page:setConsumedKeys({}) end
    page:setFocus(false,cursor);focusMode=cursor and "cursor" or nil
    if not escapeWarned then
        escapeWarned=true
        Ui.log("board games: Escape cannot be consumed on this client (it also opens the pause menu)")
    end
end
local function releaseFocus(seated)
    local page=Ui.page
    if page then
        if focusMode=="keyboard" and type(page.setConsumedKeys)=="function" then page:setConsumedKeys({}) end
        if seated or focusMode then page:setFocus(false,false) end
    end
    focusMode=nil;pageHeld={};pagePressed={}
end
-- Whether the input is ours (then nobody else is typing): our page holds the
-- keyboard or the cursor.
local function ownKeyboard()
    local page=Ui.page
    return focusMode~=nil and page~=nil and type(page.hasFocus)=="function" and page:hasFocus()==true
end
-- The page holding the cursor makes the target menu inert anyway (the cursor
-- is "captured"); disabling it closes a menu left open and keeps its focus
-- requests from racing ours.
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
                if generation==contextGeneration and active then applyFocus() end
            end
            -- Serialize rapid enter/leave changes: an old disable request must
            -- never finish after the final enable request and keep targeting locked.
            if generation==contextGeneration then break end
        end
        contextWorker=false
    end)
end
-- Seated or placing: the E prompts step aside, attacks do not fire on the
-- table click.
local function takeInput()
    Ui.setMenuOpen(false)
    Ui.dialogs.boardGames=true
    Ui.promptActive=true
    if LightRpControlClaims then
        for _,action in ipairs({"Attack","Melee","Grenade"}) do
            LightRpControlClaims.set("boardGames",action,true)
        end
    end
end
local function releaseInput()
    Ui.dialogs.boardGames=nil
    Ui.promptActive=false
    if LightRpControlClaims then
        for _,action in ipairs({"Attack","Melee","Grenade"}) do
            LightRpControlClaims.set("boardGames",action,false)
        end
    end
end
local function exitView(old)
    if old.cinematic then Open77.hud.setCinematic(false) end
    if old.camera then Open77.camera.destroy(old.camera) end
    if old.frozen then Open77.character.setFrozen(false) end
    if old.rotationFrozen then Open77.players.freezeRotation(false) end
    TriggerEvent("open-voice:setHudBlocked","op77_lightrp:boardGames",false)
    releaseFocus(true)
    disableContext(false)
end
-- The mouse that moves the page cursor must not turn the view as well
-- (gameplay input is kept): placing, and in Free while the cursor is out.
local function freezeLook(holder,value)
    local players=Open77.players
    if not players or type(players.freezeRotation)~="function" or (holder.rotationFrozen==true)==value then return end
    if value then holder.rotationFrozen=players.freezeRotation(true)==true
    else players.freezeRotation(false);holder.rotationFrozen=nil end
end
local lastDiagnostic=-10000
local function stop(notify,reason,details)
    local old,placing=active,draft
    reason=tostring(reason or "unspecified"):sub(1,64)
    if old or draft or pendingPlacement then
        details=tostring(details or ""):sub(1,180)
        Ui.log("board games stop: %s board=%s %s",reason,tostring(old and old.id or "placement"),details)
        if GetGameTimer()-lastDiagnostic>=2000 then
            lastDiagnostic=GetGameTimer()
            request("diagnostic",{event="stop",reason=reason,boardId=old and old.id,details=details})
        end
    end
    -- Every way out of a placement is traced (the stop diagnostic above is rate-limited).
    if placing then trace("place_end",nil,"kind=%s reason=%s %s",placing.kind,reason,tostring(details or "")) end
    if not placing and pendingPlacement then trace("place_end",nil,"kind=%s reason=%s pending handoff",pendingPlacement.kind,reason) end
    pendingPlacement=nil
    active,draft,pointer=nil,nil,nil
    if placing then freezeLook(placing,false) end
    if clearGhost then clearGhost() end
    pointerDown=false;pointerEvents={}
    if tags.draft then for _,tag in ipairs(tags.draft) do Open77.debugDraw.clear(tag) end;tags.draft=nil end
    if Client.clearMarks then Client.clearMarks() end
    if old then exitView(old) else releaseFocus(false) end
    if old and notify then request("leave",{boardId=old.id}) end
    -- A snapshot sent before the server processed the leave still seats us:
    -- do not reopen this table until the server agrees or 3 s pass.
    if old then leftBoards[tostring(old.id)]=GetGameTimer()+3000 end
    if LightRpTabletopExtraClient then LightRpTabletopExtraClient.setActive(nil) end
    releaseInput()
    sendView(true)
end
function Client.isActive() return active~=nil or draft~=nil end
-- The table the local player is seated at (nil while placing or standing).
function Client.seated() return active and Client.boards[active.id] end
function Client.leave(reason) if active then stop(true,reason or "menu_leave");return true end;return false end
function Client.member(board) return member(board) end
function Client.isReady(board) return isReady(board) end
function Client.isActor(board) return isActor(board) end
-- Camera views ------------------------------------------------------------------
-- Board games here; casino tables answer through their adapter (views, camera,
-- orbit in client/core/tabletop_extra.lua). The first view is the default.
local BOARD_VIEWS={{key="top",label="Overhead"},{key="white",label="White side"},{key="black",label="Black side"},{key="orbit",label="Orbit"}}
local CONNECT4_VIEWS={{key="front",label="Front"},{key="low",label="Low front"},{key="orbit",label="Orbit"}}
-- Every table ends its cycle with the free view.
local FREE_VIEW={key="free",label="Free"}
local withFree={}
local function viewsOf(board)
    local adapter=extra(board)
    local base=adapter and adapter.views(board) or board.kind=="connect4" and CONNECT4_VIEWS or BOARD_VIEWS
    local list=withFree[base]
    if not list then
        list={};for i,entry in ipairs(base) do list[i]=entry end
        list[#list+1]=FREE_VIEW;withFree[base]=list
    end
    return list
end
-- Orbit focus and default distance, board-local unscaled metres.
local function orbitOf(board)
    local adapter=extra(board)
    if adapter then return adapter.orbit(board) end
    return {x=0,y=0,z=board.kind=="connect4" and .47 or 0,radius=1.8,height=1.2}
end
local function cameraPose(board,view)
    if view=="orbit" then
        local o=orbitOf(board)
        local angle=math.rad(active and active.orbitAngle or -90)
        local radius=o.radius*(active and active.orbitZoom or 1)
        local height=o.height*(active and active.orbitLift or 1)*(active and active.orbitZoom or 1)
        return {position=world(board,o.x+math.cos(angle)*radius,o.y+math.sin(angle)*radius,o.z+height),
            lookAt=world(board,o.x,o.y,o.z),fov=52}
    end
    local adapter=extra(board)
    if adapter then local pose=adapter.camera(board,view);if pose then return pose end end
    if board.kind=="connect4" then
        if view=="low" then return {position=world(board,0,-1.65,.7),lookAt=world(board,0,0,.47),fov=52} end
        return {position=world(board,0,-1.45,1.45),lookAt=world(board,0,0,.47),fov=52}
    end
    if view=="white" or view=="black" then
        local side=view=="white" and 1 or -1
        return {position=world(board,0,side*1.65,1.0),lookAt=world(board,0,0,0),fov=52}
    end
    return {position=world(board,0,-.015,1.85),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
end
applyCamera=function()
    if not active or not active.camera then return false end
    local board=Client.boards[active.id];if not board then return false end
    local pose=cameraPose(board,active.cameraView)
    local ok=Open77.camera.setTransform(active.camera,{position=pose.position,rotation=pose.rotation,fov=pose.fov})
    if ok and pose.lookAt then ok=Open77.camera.lookAt(active.camera,pose.lookAt) end
    return ok==true
end
-- The scripted camera, the frozen character and the hidden HUD. A refused
-- camera (another script holds one) keeps the cursor and the bar over the
-- game camera: picking works through whatever camera renders.
local function enterCamera(board,view)
    if active.camera then active.cameraView=view;return applyCamera() end
    active.cameraView=view
    local registry=Open77.camera.cameras()
    if not registry or registry.held then return false,"camera_held" end
    -- thirdPersonBody: the game renders the player's full body (the head
    -- shows in the shot), as the other scripted cameras of this resource do.
    -- A client that refuses the option still gets the view, without it.
    local options={}
    for key,value in pairs(cameraPose(board,view)) do options[key]=value end
    options.thirdPersonBody=true
    local camera,why=Open77.camera.create(options)
    if not camera and tostring(why):lower():find("thirdpersonbody",1,true) then
        trace("camera_option_refused",board.id,"thirdPersonBody: %s",tostring(why))
        options.thirdPersonBody=nil
        camera,why=Open77.camera.create(options)
    end
    if not camera then return false,"camera_create "..tostring(why) end
    local activated,reason=Open77.camera.activate(camera,{blendMs=250})
    if not activated then Open77.camera.destroy(camera);return false,"camera_activate "..tostring(reason) end
    active.camera=camera;active.cameraGraceUntil=GetGameTimer()+1200
    return true
end
-- What the character and the HUD do in the current view: a scripted view
-- freezes the character (a fixed view of a walking body makes no sense) and
-- its rotation (the mouse moves the cursor) and hides the HUD; Free gives
-- everything back, but the look while the cursor is out.
local function present(board)
    local scripted=active.cameraView~="free"
    if scripted~=(active.frozen==true) then
        if scripted then
            local frozen,why=Open77.character.setFrozen(true)
            active.frozen=frozen==true
            if not active.frozen then trace("freeze_refused",board.id,"%s",tostring(why)) end
        else Open77.character.setFrozen(false);active.frozen=nil end
    end
    freezeLook(active,scripted or active.freeCursor==true)
    if scripted~=(active.cinematic==true) then
        if scripted then active.cinematic=Open77.hud.setCinematic(true,.01)==true
        else Open77.hud.setCinematic(false);active.cinematic=nil end
    end
end
-- Free: back on the character. The crosshair is the pointer.
local function enterFree(board)
    if active.camera then Open77.camera.destroy(active.camera);active.camera=nil end
    active.cameraView="free";active.freeCursor=nil;active.foreignCamera=nil;active.foreignCameraSince=nil
    pointer={x=.5,y=.5}
    present(board);applyFocus()
    local page=Ui.page
    trace("view_free",board.id,"focus=%s hasFocus=%s captured=%s",tostring(focusMode),
        tostring(page and type(page.hasFocus)=="function" and page:hasFocus()),tostring(Open77.input.isCaptured()))
end
-- Free: the cursor key takes the page cursor for the bar (and cursor picking)
-- and gives it back; the look is frozen while the cursor is out.
local function toggleFreeCursor(board)
    if not active or active.cameraView~="free" then return end
    active.freeCursor=not active.freeCursor or nil
    active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;pointerDown=false
    pointer=not active.freeCursor and {x=.5,y=.5} or nil
    present(board);applyFocus()
    sendView(true)
end
-- Choosing Free is remembered on this machine (Open77.kvp): every table
-- opens in Free until a scripted view is chosen again.
local VIEW_PREFERENCE="boardGames:view"
local function rememberFree(free)
    if type(Open77.kvp)~="table" then return end
    if free then pcall(Open77.kvp.set,VIEW_PREFERENCE,"free") else pcall(Open77.kvp.delete,VIEW_PREFERENCE) end
end
local function prefersFree()
    if type(Open77.kvp)~="table" or type(Open77.kvp.get)~="function" then return false end
    local ok,value=pcall(Open77.kvp.get,VIEW_PREFERENCE)
    return ok and value=="free"
end
local function setView(board,view)
    local valid=false
    for _,entry in ipairs(active.views) do if entry.key==view then valid=true end end
    if not valid then return false end
    active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;active.orbitDrag=nil;pointerDown=false
    rememberFree(view=="free")
    if view=="free" then
        if active.cameraView~="free" then enterFree(board) end
        sendView(true)
        return true
    end
    local fromFree=active.cameraView=="free"
    local ok,why=enterCamera(board,view)
    if not ok and why then trace("camera_refused",board.id,"view=%s %s",view,tostring(why)) end
    if fromFree then active.freeCursor=nil;pointer=nil;present(board);applyFocus() end
    sendView(true)
    return ok
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
    local views=viewsOf(board)
    local free=false
    if prefersFree() then for _,entry in ipairs(views) do if entry.key=="free" then free=true end end end
    active={id=board.id,revision=board.revision,views=views,cameraView=views[1].key,orbitAngle=-90,orbitZoom=1,orbitLift=1}
    takeInput()
    if LightRpTabletopExtraClient then LightRpTabletopExtraClient.setActive(extra(board) and board or nil) end
    local ok,why=true,nil
    if free then enterFree(board) else ok,why=enterCamera(board,active.cameraView) end
    if not ok then
        trace("camera_refused",board.id,"view=%s %s",active.cameraView,tostring(why))
        notice("The table camera is unavailable: play from your own view.",titleOf(board.kind))
    end
    present(board)
    applyFocus()
    disableContext(true)
    trace("view_open",board.id,"kind=%s rev=%s view=%s camera=%s",board.kind,tostring(board.revision),active.cameraView,tostring(ok==true))
    if LightRpTableMenu then guarded("table menu seated",LightRpTableMenu.seated,board) end
    sendView(true)
end
local function cursor()
    if pointer and pointer.x and pointer.y then return pointer end
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
end
-- One page pointer event (normalized cursor, button edges). The bar and the
-- page's other surfaces send {blocked=true}: a press there is never a table click.
local function pointerAction(board,event)
    local adapter=extra(board)
    if event.blocked then
        if adapter then adapter.pointer(board,{x=pointer and pointer.x or .5,y=pointer and pointer.y or .5,cancelled=true,released=true}) end
        active.drag=nil;active.clickDestination=nil;active.dropPressed=nil;active.orbitDrag=nil;pointerDown=false;return
    end
    pointer={x=event.x,y=event.y}
    -- Orbit: the right button turns the view (the wheel zooms, see bind).
    if event.rightPressed and active.cameraView=="orbit" then active.orbitDrag={x=event.x,y=event.y} end
    if event.rightReleased then active.orbitDrag=nil end
    if active.orbitDrag then
        local old=active.orbitDrag
        active.orbitAngle=(active.orbitAngle+(event.x-old.x)*250)%360
        active.orbitLift=math.max(.3,math.min(2.4,active.orbitLift+(event.y-old.y)*2))
        active.orbitDrag={x=event.x,y=event.y};applyCamera()
    end
    if event.rightPressed or event.rightReleased then return end
    if adapter then
        local before=adapter.selection(board)
        adapter.pointer(board,event)
        if adapter.selection(board)~=before then sendView(true) end
        return
    end
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
    end
    if active.drag and math.abs(event.x-active.drag.screenX)+math.abs(event.y-active.drag.screenY)>.006 then active.drag.moved=true end
    -- Free: the crosshair stays at the screen centre; a drag is the aim leaving the square.
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
local TABLE_COLLIDERS={slot_cabinet=true,blackjack_table=true,roulette_table=true,fortune_stand=true,pool_table=true,chess_board=true,checkers_board=true,connect4_board=true}
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
    if not cache.colliderTried and renderAllowed[id]=="full" then -- once per cache, even if a snapshot interrupted the pass above
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
    -- Seen from far with the quota full: the table alone.
    if renderAllowed[id]=="base" then
        if not cache.base then cache.base=true;trace("render_base",id,"kind=%s",board.kind) end
        return
    end
    cache.base=nil
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
        if not aliveBoard(board) or renderCaches[id]~=cache or renderAllowed[id]=="base" then return end
    end end
    local count=0;for _ in pairs(cache.pieces) do count=count+1 end
    if not cache.initialized then trace("render_done",id,"kind=%s pieces=%d",board.kind,count) end
    cache.count=count;cache.initialized=true
end
-- The table a native prop belongs to: its base, its collider or one of its
-- pieces (the ALT menu's target). One table lookup, cheap enough for every pick.
function Client.isRendered(board) return board~=nil and renderCaches[tostring(board.id)]~=nil end
function Client.boardOfProp(propId)
    if type(propId)~="string" and type(propId)~="number" then return nil end
    local record=ownedProps[tostring(propId)]
    if not record or record.ghost or not record.boardId then return nil end
    if not renderCaches[record.boardId] then return nil end
    return Client.boards[tonumber(record.boardId) or record.boardId]
end
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
-- Clickable targets ("marks") ------------------------------------------------------
-- Everything the seated player can click right now is outlined faintly on the
-- table: chess/checkers pieces with a legal move and, once one is selected,
-- its destinations; Connect Four's open columns; the casino adapters' own
-- (adapter.markKey/marks: the roulette layout, the fortune spots, the
-- blackjack circle, the slot lever, the pool cue ball or ball-in-hand area).
-- Nothing is marked when it is not the player's turn or the phase forbids it.
-- The hovered target (amber) and the selection (cyan) stay in the preview.
-- A dedicated thread (THREADS.marks) does the work only when the marks' key
-- changes: legal moves through the shared rules (yielding every
-- LEGAL_EVERY board reads: at most ~3.7k instructions per resume over random
-- chess and checkers games; a busy chess position takes 100-280 frames, so
-- the pieces' marks follow a move by one to a few seconds), geometry in
-- slices of MARK_SLICE lines; a still table only re-sends the same batch
-- before its ttl runs out.
local MARK_TAG,MARK_COLOR="boardGames:marks","#d8ecff5c"
local SELECT_COLOR="#38f2ffff"
local MARK_TTL,MARK_REFRESH_MS,MARK_SLICE,LEGAL_EVERY=2.5,1000,12,24
local legal={}          -- {boardId,revision,ready,from={[row*16+col]={[row*16+col]=true}}}
local markEpoch=0
function Client.clearMarks()
    markEpoch=markEpoch+1
    if tags.marks then Open77.debugDraw.clear(MARK_TAG);tags.marks=nil end
end
local function picksPieces(board) return board.kind=="chess" or board.kind=="checkers" end
-- What is markable now, as a string (nil: nothing). Cheap: runs every frame.
local function markKey(board)
    local adapter=extra(board)
    if adapter then
        local key=adapter.markKey(board)
        return key and ("x%s:%s:%s"):format(tostring(board.id),tostring(board.revision),key) or nil
    end
    if not canMove(board) then return nil end
    if board.kind=="connect4" then return ("c%s:%s"):format(tostring(board.id),tostring(board.revision)) end
    if not picksPieces(board) or legal.boardId~=board.id or legal.revision~=board.revision or not legal.ready then return nil end
    local sel=active and active.selected
    return ("b%s:%s:%s"):format(tostring(board.id),tostring(board.revision),sel and (sel.row*16+sel.col) or "-")
end
-- The snapshot as the rules expect it (numeric rows, numeric `taken` keys
-- after JSON), without the repetition history: a move list needs none.
local function analysisState(game,pause)
    local rows,cols=tonumber(game.rows or game.size) or 8,tonumber(game.cols or game.size) or 8
    local s={kind=game.kind,size=game.size,rows=rows,cols=cols,turn=game.turn,status=game.status,
        ply=game.ply,halfmove=game.halfmove,captured={},board={}}
    if type(game.enPassant)=="table" then s.enPassant={row=tonumber(game.enPassant.row),col=tonumber(game.enPassant.col)} end
    if type(game.chain)=="table" then
        local taken={}
        for id,value in pairs(game.chain.taken or {}) do taken[tonumber(id) or id]=value end
        s.chain={row=tonumber(game.chain.row),col=tonumber(game.chain.col),remaining=tonumber(game.chain.remaining),taken=taken}
    end
    local source=game.board or {}
    for r=1,rows do
        local line=source[r] or source[tostring(r)] or {}
        local row={}
        for c=1,cols do
            local p=line[c];if p==nil then p=line[tostring(c)] end
            row[c]=type(p)=="table" and p or false
        end
        s.board[r]=row
        if r%3==0 then pause() end
    end
    return s
end
-- Legal moves of this snapshot, from the marks thread (it yields inside).
local function computeLegal(board,pause)
    local mine={boardId=board.id,revision=board.revision,ready=false}
    legal=mine
    local Rules=LightRPBoardRules
    if not Rules or type(Rules.legalMoves)~="function" then return end
    local moves=Rules.legalMoves(analysisState(board.game,pause),pause,LEGAL_EVERY)
    if legal~=mine then return end
    local from={}
    for index,m in ipairs(moves) do
        local key=m.fromRow*16+m.fromCol
        local list=from[key];if not list then list={};from[key]=list end
        list[m.toRow*16+m.toCol]=true
        if index%40==0 then pause() end
    end
    mine.from=from;mine.ready=true
end
-- The marks of one key; `line` yields every MARK_SLICE lines.
local function buildMarks(board,line)
    local adapter=extra(board)
    if adapter then adapter.marks(board,line);return end
    if board.kind=="connect4" then
        for col=1,7 do
            local top=board.game.board[1]
            if top and not top[col] then
                local x=(col-4)*.14
                local a,b=world(board,x-.06,-.035,.04),world(board,x+.06,-.035,.04)
                local c,d=world(board,x+.06,-.035,.88),world(board,x-.06,-.035,.88)
                line(a,b);line(b,c);line(c,d);line(d,a)
            end
        end
        return
    end
    local n=board.kind=="checkers" and 10 or 8
    local half=.5/n
    local function square(key,r,color)
        local row,col=math.floor(key/16),key%16
        local p=positionOf(board,row,col)
        local a,b=world(board,p.x-r,p.y-r,.008),world(board,p.x+r,p.y-r,.008)
        local c,d=world(board,p.x+r,p.y+r,.008),world(board,p.x-r,p.y+r,.008)
        line(a,b,color);line(b,c,color);line(c,d,color);line(d,a,color)
    end
    local from=legal.from or {}
    for key in pairs(from) do square(key,half*.82) end
    local sel=active and active.selected
    local targets=sel and from[sel.row*16+sel.col]
    if targets then for key in pairs(targets) do square(key,half*.38) end end
end
-- What a lower level of detail no longer draws goes first in every render
-- pass, before anything nearer is created, so the quota is never overrun on
-- the way; removals are sliced (seven tables shedding at once is ~230 props).
local SHED_SLICE=24
local function shedDetail(generation)
    local removed=0
    local function slice()
        removed=removed+1
        if removed>=SHED_SLICE then Wait(0);beats.render=GetGameTimer();removed=0 end
    end
    local ids={};for id in pairs(renderCaches) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do
        if generations.render~=generation then return end
        local cache,mode=renderCaches[id],renderAllowed[id]
        if cache and mode and mode~="full" and cache.collider then
            removeProp(cache.collider);cache.collider=nil;cache.colliderTried=nil;slice()
        end
        cache,mode=renderCaches[id],renderAllowed[id]
        if cache and mode=="base" and next(cache.pieces)~=nil then
            cache.initialized=false;cache.moving={};cache.goals={};cache.targets=nil;cache.count=0
            local keys={};for key in pairs(cache.pieces) do keys[#keys+1]=key end
            for _,key in ipairs(keys) do
                if renderCaches[id]~=cache or renderAllowed[id]~="base" then break end
                removeProp(cache.pieces[key]);cache.pieces[key]=nil;slice()
            end
            for _,tag in ipairs(tags[id] or {}) do Open77.debugDraw.clear(tag) end
            tags[id]=nil
        end
    end
end
local THREADS={}
function THREADS.render(generation)
    while rendererRunning and generations.render==generation do
        beats.render=GetGameTimer()
        Wait(0)
        shedDetail(generation)
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
function THREADS.marks(generation)
    local sentKey,geometry,sentAt,epoch=nil,nil,-100000,markEpoch
    local function beat() Wait(0);beats.marks=GetGameTimer() end
    while rendererRunning and generations.marks==generation do
        beat()
        if epoch~=markEpoch then epoch,sentKey,geometry=markEpoch,nil,nil end
        local board=active and Client.boards[active.id]
        if board and not extra(board) and picksPieces(board) and canMove(board)
            and (legal.boardId~=board.id or legal.revision~=board.revision) then
            computeLegal(board,beat)
            board=active and Client.boards[active.id]
        end
        local key=board and markKey(board) or nil
        local now=GetGameTimer()
        if key~=sentKey then
            if key then
                local built={lines={},triangles={},ttl=MARK_TTL,maxDistance=18,thickness=1.5}
                local lines=built.lines
                local function line(a,b,color)
                    if #lines>=512 then return end
                    lines[#lines+1]={a=a,b=b,color=color or MARK_COLOR}
                    if #lines%MARK_SLICE==0 then beat() end
                end
                buildMarks(board,line)
                -- Still current after the slices (a click or a snapshot may have changed it)?
                local current=active and Client.boards[active.id]
                if epoch==markEpoch and current and markKey(current)==key then
                    geometry=#lines>0 and built or nil
                    if geometry and Open77.debugDraw.set(MARK_TAG,geometry) then tags.marks={MARK_TAG}
                    elseif tags.marks then Open77.debugDraw.clear(MARK_TAG);tags.marks=nil end
                    sentKey,sentAt=key,GetGameTimer()
                end
            else
                if tags.marks then Open77.debugDraw.clear(MARK_TAG);tags.marks=nil end
                sentKey,geometry=nil,nil
            end
        elseif geometry and now-sentAt>=MARK_REFRESH_MS then
            sentAt=now
            if Open77.debugDraw.set(MARK_TAG,geometry) then tags.marks={MARK_TAG} end
        end
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
    spawnThread("render");spawnThread("animate");spawnThread("validate");spawnThread("marks")
end
-- The held piece follows the cursor from the main loop's
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
        -- Casino tables outline what the cursor points at and the selection.
        local p=cursor()
        adapter.aim(board,p and p.x,p and p.y,line)
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
        local sel=active.selected
        for index,cell in ipairs({sel or {},{row=row,col=col}}) do if cell.row and cell.col and (index==1 or not sel or sel.row~=row or sel.col~=col) then
            local p=positionOf(board,cell.row,cell.col)
            local r=board.kind=="connect4" and .067 or .5/(board.kind=="checkers" and 10 or 8)
            local color=index==1 and SELECT_COLOR or nil -- the selection cyan, the hovered cell amber
            local corners={{-r,-r},{r,-r},{r,r},{-r,r}}
            for i,c in ipairs(corners) do local q=corners[i%4+1]
                if board.kind=="connect4" then
                    line(world(board,p.x+c[1],-.03,p.z+c[2]),world(board,p.x+q[1],-.03,p.z+q[2]),color)
                else line(world(board,p.x+c[1],p.y+c[2],.009),world(board,p.x+q[1],p.y+q[2],.009),color) end
            end
        end end
    end
    local ok,why=Open77.debugDraw.set("boardGames:preview",geometry)
    if ok then tags.preview={"boardGames:preview"}
    elseif not Client.drawWarning then Client.drawWarning=true;notice("3D rendering unavailable: "..tostring(why)) end
end
-- Placement ----------------------------------------------------------------------
-- The page cursor and the bar in its placement mode (see the header). The
-- preview follows the cursor ray onto the ground or a surface while the left
-- button is held (a click moves it there), within PLACE_REACH of the
-- character (the server accepts 4 m).
local PLACE_REACH,PLACE_RAY=3.5,12
local ROTATE_STEP,HEIGHT_STEP,HEIGHT_MIN,HEIGHT_MAX=15,.05,-1,1.5
local PLACE_WAIT_TRACE_MS=10000
-- The preview's origin above a hit point: floor-standing tables declare how
-- high their origin sits above the floor (unscaled metres, `floor` in their
-- shared spec); boards rest on the surface.
local function placementZ(kind,z)
    local spec=LightRpBoardGames and LightRpBoardGames[kind]
    if spec and type(spec.floor)=="number" then return z+spec.floor*SCALE end
    return z+.015
end
local function placementHeight(height)
    draft.height=math.max(HEIGHT_MIN,math.min(HEIGHT_MAX,height))
    draft.position.z=placementZ(draft.kind,draft.surfaceZ)+draft.height
    draft.viewDirty=true
end
-- Whether the preview rendered. The validate thread marks it; on E, one scan
-- of the props list for this handle only: never the whole validation in the
-- input resume (several casino tables nearby are hundreds of props).
local function ghostReady()
    local ghost=ghostProp
    if not ghost or not ghost.handle then return false,"no_preview" end
    if ghost.ready then return true end
    local rows,why=Open77.props.list()
    if type(rows)~="table" then return false,"props_list "..tostring(why) end
    local id=tostring(ghost.handle)
    for _,row in ipairs(rows) do
        if tostring(row.id)==id then
            local backend=tostring(row.backend or ""):lower()
            if row.failed or backend:find("placeholder",1,true) or backend:find("marker",1,true)
                or backend:find("fallback",1,true) or backend:find("cube",1,true) then return false,"failed "..backend end
            if row.rendered==true then ghost.ready=true;ghost.backend=row.backend;return true end
            return false,"loading"
        end
    end
    return false,"not_listed"
end
placementView=function()
    local d=draft
    local ready=ghostProp~=nil and ghostProp.ready==true
    d.shownReady=ready
    local status,tone="Drag it where it goes","turn"
    if not ready then status,tone="Loading the model…",nil
    elseif d.far then status,tone="Too far: bring it closer","warn" end
    return {active=true,placing=true,mode="placement",kind=d.kind,title="Place: "..(titleOf(d.kind) or "Table"),
        status=status,tone=tone,
        detail=("Turn %d° · Height %+.2f m"):format(math.floor(d.rotation+.5)%360,d.height),
        hint="Press or drag on the ground to move it",
        actions={
            {key="place.left",label="Left",title="Turn left",keycap="←",enabled=true},
            {key="place.right",label="Right",title="Turn right",keycap="→",enabled=true},
            {key="place.up",label="Up",title="Raise",keycap="PgUp",enabled=true},
            {key="place.down",label="Down",title="Lower",keycap="PgDn",enabled=true},
            {key="place.confirm",label="Place",title="Place it here",keycap="E",enabled=ready,primary=true}},
        views={}}
end
local function confirmPlacement(via)
    if not draft then return end
    local ready,why=ghostReady()
    if ready then
        local placed=draft
        trace("place_confirm",nil,"kind=%s pos=%.1f,%.1f,%.1f rot=%.0f via=%s",placed.kind,placed.position.x,placed.position.y,placed.position.z,placed.rotation,tostring(via))
        request("place",{kind=placed.kind,position=placed.position,rotation=placed.rotation})
        draft=nil;clearGhost();pointerDown=false;pointer=nil;pointerEvents={}
        freezeLook(placed,false);releaseInput();releaseFocus(false);sendView(true)
    else
        trace("place_not_ready",nil,"kind=%s via=%s why=%s age=%sms",draft.kind,tostring(via),tostring(why),
            tostring(ghostProp and GetGameTimer()-ghostProp.created))
        notice("The table model is still loading. Wait a moment before placing it.")
        draft.viewDirty=true
    end
end
-- A bar button while placing.
local function placementAction(key)
    if not draft then return false end
    if key=="place.left" or key=="place.right" then
        draft.rotation=(draft.rotation+(key=="place.left" and -ROTATE_STEP or ROTATE_STEP))%360;draft.viewDirty=true
    elseif key=="place.up" or key=="place.down" then placementHeight(draft.height+(key=="place.up" and HEIGHT_STEP or -HEIGHT_STEP))
    elseif key=="place.confirm" then confirmPlacement("bar")
    else return false end
    return true
end
-- The page pointer while placing: a press (or a drag) moves the preview.
local function placementPointer(events)
    for _,event in ipairs(events) do
        if event.blocked then pointerDown=false
        else
            pointer={x=event.x,y=event.y};draft.aim=true
            if event.pressed then pointerDown=true;draft.moveNow=true end
            if event.released then pointerDown=false end
        end
    end
end
local function aimPlacement()
    if not pointer or not draft.aim or not (pointerDown or draft.moveNow) then return end
    draft.aim,draft.moveNow=nil,nil
    local hit=Open77.camera.screenRaycast(pointer.x,pointer.y,PLACE_RAY,{static=true,dynamic=true})
    if not hit or not hit.hit or type(hit.position)~="table" then return end
    local state=Open77.character.state()
    local me=state and state.position
    local far=me and ((hit.position.x-me.x)^2+(hit.position.y-me.y)^2>PLACE_REACH^2 or math.abs(hit.position.z-me.z)>2.5)
    if (far==true)~=(draft.far==true) then draft.far=far or nil;draft.viewDirty=true end
    if far then return end
    draft.position.x,draft.position.y=hit.position.x,hit.position.y
    draft.surfaceZ=hit.position.z
    placementHeight(draft.height)
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
    -- It starts where the crosshair meets the world (or just ahead).
    local hit=Open77.camera.screenRaycast(.5,.5,PLACE_REACH,{static=true,dynamic=true})
    local pos=hit and hit.hit and hit.position or {x=state.position.x,y=state.position.y+1,z=state.position.z}
    draft={kind=kind,position={x=pos.x,y=pos.y,z=placementZ(kind,pos.z)},surfaceZ=pos.z,rotation=0,height=0,
        traceAt=GetGameTimer()+PLACE_WAIT_TRACE_MS,viewDirty=true}
    local prop,why=createProp(draft,nil,draft.position,true)
    if not prop then trace("place_ghost_failed",nil,"kind=%s %s",kind,tostring(why));draft=nil;unavailable(why);return end
    ghostProp=prop
    pointer=nil;pointerDown=false;pointerEvents={}
    takeInput()
    freezeLook(draft,true)
    applyFocus() -- the cursor and the keyboard with gameplay kept: Escape cancels without the pause menu
    local page=Ui.page
    trace("place_ghost",nil,"kind=%s model=%s focus=%s hasFocus=%s captured=%s",kind,tostring(prop.name),tostring(focusMode),
        tostring(page and type(page.hasFocus)=="function" and page:hasFocus()),tostring(Open77.input.isCaptured()))
    sendView(true)
    notice("Drag on the ground to move it. Arrows: turn · PgUp/PgDn: height · E: place · Escape: cancel.",
        titleOf(kind))
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
    page:on(LightRpEvents.page.ready,function() request("sync");if active then sendView(true) end end)
    page:on(POINTER,function(p)
        if not Client.isActive() or type(p)~="table" then return end
        if draft and not draft.seenPointer then draft.seenPointer=true;trace("place_input",nil,"source=pointer kind=%s",draft.kind) end
        if p.blocked or p.cancelled then
            pointerEvents[#pointerEvents+1]={blocked=true};return
        end
        if type(p.x)~="number" or type(p.y)~="number" or p.x~=p.x or p.y~=p.y or p.x<0 or p.x>1 or p.y<0 or p.y>1 then return end
        local event={x=p.x,y=p.y,pressed=p.pressed==true or nil,released=p.released==true or nil,
            rightPressed=p.rightPressed==true or nil,rightReleased=p.rightReleased==true or nil}
        -- Moves between two edges only matter for their last position.
        local last=pointerEvents[#pointerEvents]
        if last and not last.blocked and not (last.pressed or last.released or last.rightPressed or last.rightReleased)
            and not (event.pressed or event.released or event.rightPressed or event.rightReleased) then
            pointerEvents[#pointerEvents]=event;return
        end
        if #pointerEvents>=32 then pointerEvents={};if active then active.drag=nil;active.clickDestination=nil end end
        pointerEvents[#pointerEvents+1]=event
    end)
    page:on("lightrp:boardGames:camera",function(p)
        local board=active and Client.boards[active.id]
        if not board or type(p)~="table" then return end
        if type(p.view)=="string" then setView(board,p.view)
        elseif p.cycle then
            local index=1
            for i,entry in ipairs(active.views) do if entry.key==active.cameraView then index=i end end
            setView(board,active.views[index%#active.views+1].key)
        end
        if type(p.zoom)=="number" and p.zoom==p.zoom and active.cameraView=="orbit" then
            active.orbitZoom=math.max(.55,math.min(1.7,active.orbitZoom+(p.zoom>0 and .08 or -.08)));applyCamera()
        end
    end)
    -- A bar button: the bar model is rebuilt from the current state and only a
    -- button it offers, enabled, runs (a stale click after a phase change is dropped).
    page:on("lightrp:boardGames:action",function(p)
        if draft and not active then
            if type(p)=="table" and type(p.key)=="string" and placementAction(p.key) and draft then sendView(true) end
            return
        end
        local board=active and Client.boards[active.id]
        if not board or type(p)~="table" or type(p.key)~="string" then return end
        local Bar=LightRpTableBar
        if Bar then guarded("table bar action",Bar.run,board,p.key) end
        sendView(true)
    end)
    page:on("lightrp:boardGames:chip",function(p)
        local board=active and Client.boards[active.id]
        if not board or type(p)~="table" then return end
        local Bar=LightRpTableBar
        if Bar then guarded("table bar chip",Bar.setChip,board,p.amount) end
        sendView(true)
    end)
    -- The bar's Leave (Cancel while placing), or Escape on the page.
    page:on("lightrp:boardGames:leave",function(p)
        local escape=type(p)=="table" and p.key=="escape"
        if active then stop(true,escape and "key_escape" or "ui_leave")
        elseif draft then stop(true,escape and "key_escape" or "ui_cancel") end
    end)
    -- The table keys, forwarded by the page while it holds the keyboard
    -- (TableBar.tsx): {key, down, repeat}. Read with the physical keys.
    page:on("lightrp:boardGames:key",function(p)
        if not Client.isActive() or type(p)~="table" or type(p.key)~="string" then return end
        local name=p.key:upper()
        if not TABLE_KEYS[name] then return end
        if draft and not draft.seenPage then draft.seenPage=true;trace("place_input",nil,"source=page key=%s kind=%s",name,draft.kind) end
        if p.down==true then
            if HELD_KEYS[name] then pageHeld[name]=GetGameTimer()+PAGE_HOLD_MS end
            if p["repeat"]~=true then pagePressed[name]=true end
        else pageHeld[name]=nil end
    end)
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
    if active then active.viewDirty=true end -- the bar follows on the next render resume
    if LightRpTableMenu then guarded("table notices",LightRpTableMenu.observe,nextBoards) end
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
end
local function cameraKey(id)
    if type(id)=="number" then
        if id~=id then return end
        return id%1==0 and string.format("%.0f",id) or tostring(id)
    end
    if type(id)=="string" and id~="" then return id end
end
-- Another script took the camera over (a cutscene, a death cam): the game
-- view cannot continue. In-flight registry snapshots are not proof of that.
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
    return false
end
function Client.start()
    if started then return end;started=true
    startRenderer()
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
                -- The table keys stay inert while chat or another page types,
                -- or the pause menu is open. Our own page holding the keyboard
                -- (or the cursor) is not someone typing.
                -- Live on 176, our own page holding the keyboard also reports a
                -- "menu" open, which made every placement key inert: neither
                -- counts as typing while the keyboard is ours.
                local own=ownKeyboard()
                local menu=Client.isActive() and not own and Open77.session~=nil and type(Open77.session.isMenuOpen)=="function" and Open77.session.isMenuOpen()==true
                local typing=(Client.isActive() and Open77.input.isCaptured()==true and not own) or menu
                if Client.isActive() then
                    for _,k in ipairs({"E",FREE_CURSOR_KEY,"LEFT","RIGHT","PAGEUP","PAGEDOWN","mouse1"}) do
                        keys[k]=not typing and Open77.input.isDown(k)==true
                    end
                end
                -- Chat (or another page) took the keyboard and gave it back to
                -- the game: take it again so Escape stays ours.
                if focusMode and Client.isActive() and now>=focusCheckAt then
                    focusCheckAt=now+500
                    local page=Ui.page
                    if page and type(page.hasFocus)=="function" and page:hasFocus()~=true and not menu
                        and Open77.input.isCaptured()~=true then applyFocus() end
                end
                local events=pointerEvents;pointerEvents={}
                local pagePresses=pagePressed;pagePressed={}
                -- A press: the physical edge or the page's keydown, once per stroke.
                local function pressed(k)
                    local edge=(keys[k] and not previous[k]) or (not typing and pagePresses[k])
                    if not edge or (lastPress[k] and now-lastPress[k]<PRESS_DEDUPE_MS) then return false end
                    lastPress[k]=now;return true
                end
                local function held(k) return keys[k] or (not typing and pageHeld[k]~=nil and pageHeld[k]>now) end
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
                if draft then
                    if not draft.seenKeys and (keys.E or keys.LEFT or keys.RIGHT or keys.PAGEUP or keys.PAGEDOWN) then
                        draft.seenKeys=true;trace("place_input",nil,"source=keys kind=%s",draft.kind)
                    end
                    placementPointer(events)
                    local lift=(held("PAGEUP") and 1 or 0)-(held("PAGEDOWN") and 1 or 0)
                    if lift~=0 then placementHeight(draft.height+lift*dt*.0003) end
                    local turn=(held("RIGHT") and 1 or 0)-(held("LEFT") and 1 or 0)
                    if turn~=0 then draft.rotation=(draft.rotation+turn*dt*.06)%360;draft.viewDirty=true end
                    aimPlacement()
                    if pressed("E") then confirmPlacement("key") end
                    -- Never silent: what the placement is waiting for, every 10 s.
                    if draft and now>=draft.traceAt then
                        draft.traceAt=now+PLACE_WAIT_TRACE_MS
                        local page=Ui.page
                        trace("place_wait",nil,"kind=%s ready=%s focus=%s hasFocus=%s captured=%s typing=%s menuOpen=%s pointer=%s page=%s keys=%s",
                            draft.kind,tostring(ghostProp and ghostProp.ready),tostring(focusMode),
                            tostring(page and type(page.hasFocus)=="function" and page:hasFocus()),tostring(Open77.input.isCaptured()),
                            tostring(typing),tostring(Open77.session~=nil and type(Open77.session.isMenuOpen)=="function" and Open77.session.isMenuOpen()),
                            tostring(draft.seenPointer==true),tostring(draft.seenPage==true),tostring(draft.seenKeys==true))
                    end
                elseif active then
                    local board=Client.boards[active.id]
                    local far=board and state and state.position and distance(state.position,board.position)
                    if far and far>LEAVE_RADIUS then
                        if not active.farSince then
                            active.farSince=now
                            notice("Too far from the table: step back or you leave your seat.")
                        end
                    elseif active.farSince then active.farSince=nil end
                    if not board then stop(true,"board_unavailable")
                    elseif far and (far>LEAVE_HARD_RADIUS or (active.farSince and now-active.farSince>=LEAVE_GRACE_MS)) then
                        notice("You walked away from the table and left your seat.")
                        stop(true,"distance",("%.1f m"):format(far))
                    elseif active.camera and cameraSwitched(active,Open77.camera.cameras(),now) then
                        local registry=Open77.camera.cameras()
                        stop(true,"camera_switched","expected="..tostring(active.camera).." actual="..tostring(registry and registry.activeCamera))
                    else
                        if active.farSince then active.viewDirty=true end -- the bar counts down
                        if active.cameraView=="free" and pressed(FREE_CURSOR_KEY) then toggleFreeCursor(board) end
                        for _,event in ipairs(events) do if active then pointerAction(board,event) end end
                        -- Free, crosshair: the screen centre is the pointer and the left button acts.
                        if active and active.cameraView=="free" and not active.freeCursor then
                            local down=keys.mouse1==true
                            local edge=down and not previous.mouse1 and "pressed" or (previous.mouse1 and not down) and "released" or nil
                            pointer={x=.5,y=.5}
                            if edge or down then pointerAction(board,{x=.5,y=.5,crosshair=true,pressed=edge=="pressed" or nil,released=edge=="released" or nil}) end
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
                        if d<FAR_RADIUS then near[#near+1]={board=board,d=d} end
                    end
                    table.sort(near,function(a,b)
                        if active and a.board.id==active.id then return true end
                        if active and b.board.id==active.id then return false end
                        return a.d<b.d
                    end)
                end
                -- Nearest first (the active table always), within the per-resource
                -- client prop quota (256): a blackjack table alone is up to 60 props.
                -- A table whose pieces no longer fit keeps its base; one whose base
                -- does not fit either is not drawn.
                renderCandidates={}
                local props=0
                for _,entry in ipairs(near) do
                    local id=tostring(entry.board.id);local cache=renderCaches[id]
                    local close=entry.d<RENDER_RADIUS or (active~=nil and active.id==entry.board.id)
                    local pieces=PROP_ESTIMATE[entry.board.kind] or 45
                    if cache and cache.initialized and cache.count then pieces=cache.count end
                    local mode,cost=close and "full" or "far",1+pieces+(close and 1 or 0)
                    if #renderCandidates>0 and props+cost>PROP_BUDGET then mode,cost="base",1 end
                    if #renderCandidates==0 or props+cost<=PROP_BUDGET then
                        props=props+cost;renderCandidates[#renderCandidates+1]=entry;allowed[id]=mode
                    end
                end
                renderAllowed=allowed
                for id in pairs(renderCaches) do if not allowed[id] then clearGeometry(id) end end
                moveHeldPiece()
                watchThreads()
                renderPreview()
                if active then sendView(active.viewDirty==true);if active then active.viewDirty=nil end
                elseif draft then
                    if ghostProp and (ghostProp.ready==true)~=(draft.shownReady==true) then draft.viewDirty=true end
                    if draft.viewDirty and GetGameTimer()-lastView>=VIEW_MS then draft.viewDirty=nil;sendView(true) end
                end
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
-- Escape that reached the pause key (a client without consumed keys, see the
-- header): leave all the same; the pause menu opens as well.
AddEventHandler("open77:pauseKey",function()
    if active or draft then stop(true,"key_escape_pause") end
end)
AddEventHandler("onClientResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    rendererRunning=false;renderAllowed={};renderCandidates={}
    stop(false,"resource_stop");clearSounds(true)
    for id in pairs(renderCaches) do clearGeometry(id) end
    for id in pairs(tags) do clearGeometry(id) end
    for id in pairs(Client.boards) do LightRpInteract.setLocal("boardGames."..id,nil) end
end)
